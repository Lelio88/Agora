package recurrence

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"time"
)

// Compute calcule les occurrences d'une série à partir de sa ligne
// maîtresse ; found est faux si elle n'existe plus ou ne se répète plus.
type Compute func(series Series, found bool) ([]Occurrence, error)

// Store est le port de persistance du dépliage (implémenté par PgStore).
type Store interface {
	// ListSeriesIDs liste toutes les séries à déplier.
	ListSeriesIDs(ctx context.Context) ([]string, error)
	// UpdateOccurrences lit une série, en calcule les occurrences par
	// compute et les écrit, d'un seul tenant : sous le verrou de la série,
	// que prennent aussi les RPC qui remplacent ou suppriment une
	// occurrence. Sans cela, une exception posée entre la lecture et
	// l'écriture verrait son occurrence ressuscitée. Une erreur de compute
	// laisse les occurrences en place.
	UpdateOccurrences(ctx context.Context, seriesID string, compute Compute) error
}

// Fenêtre glissante dépliée : un an en arrière pour parcourir le passé, deux
// ans en avant. Le dépliage complet périodique la fait avancer.
const (
	pastHorizonYears   = 1
	futureHorizonYears = 2
)

var uuidPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// Service déplie les séries et tient event_occurrences à jour.
//
// Invariant : Run traite une série à la fois. Deux remplacements concurrents
// d'une même série se marcheraient dessus (le verrou consultatif de PgStore
// protège en plus contre plusieurs instances du worker).
type Service struct {
	store  Store
	now    func() time.Time
	logger *slog.Logger
	window func(now time.Time) Window
}

// NewService construit le service ; now est time.Now en production.
func NewService(store Store, now func() time.Time, logger *slog.Logger) *Service {
	return &Service{store: store, now: now, logger: logger, window: defaultWindow}
}

func defaultWindow(now time.Time) Window {
	return Window{From: now.AddDate(-pastHorizonYears, 0, 0), To: now.AddDate(futureHorizonYears, 0, 0)}
}

// Refresh redéplie une série. Une série disparue (ou redevenue ponctuelle)
// perd ses occurrences ; une règle invalide laisse les précédentes en place.
func (s *Service) Refresh(ctx context.Context, seriesID string) error {
	err := s.store.UpdateOccurrences(ctx, seriesID, func(series Series, found bool) ([]Occurrence, error) {
		if !found {
			return nil, nil
		}
		occurrences, err := Expand(series, s.window(s.now()))
		if errors.Is(err, ErrTooManyOccurrences) {
			s.logger.Warn("series truncated", "series", seriesID, "kept", len(occurrences))
			return occurrences, nil
		}
		return occurrences, err
	})
	if err != nil {
		return fmt.Errorf("refresh series %s: %w", seriesID, err)
	}
	return nil
}

// RefreshAll redéplie toutes les séries ; l'échec de l'une n'arrête pas les
// autres, et tous les échecs sont renvoyés ensemble.
func (s *Service) RefreshAll(ctx context.Context) error {
	ids, err := s.store.ListSeriesIDs(ctx)
	if err != nil {
		return fmt.Errorf("list series: %w", err)
	}
	var failures []error
	for _, id := range ids {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if err := s.Refresh(ctx, id); err != nil {
			failures = append(failures, err)
		}
	}
	return errors.Join(failures...)
}

// Run traite les séries notifiées, les demandes de dépliage complet (au
// démarrage et à chaque reconnexion de l'écoute) et un dépliage complet
// périodique, jusqu'à l'annulation de ctx.
func (s *Service) Run(ctx context.Context, notifications <-chan string, refreshAll <-chan struct{}, every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case id := <-notifications:
			if !uuidPattern.MatchString(id) {
				s.logger.Warn("ignored malformed notification", "payload_length", len(id))
				continue
			}
			if err := s.Refresh(ctx, id); err != nil {
				s.logger.Error("refresh series failed", "series", id, "err", err)
			}
		case <-refreshAll:
			s.refreshAllAndLog(ctx)
		case <-ticker.C:
			s.refreshAllAndLog(ctx)
		}
	}
}

func (s *Service) refreshAllAndLog(ctx context.Context) {
	started := s.now()
	if err := s.RefreshAll(ctx); err != nil {
		s.logger.Error("refresh all series failed", "err", err)
		return
	}
	s.logger.Info("all series refreshed", "took", s.now().Sub(started))
}
