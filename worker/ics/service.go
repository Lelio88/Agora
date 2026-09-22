package ics

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"
)

// Store est le port de persistance de la relecture (implémenté par
// PgStore, sur les fonctions private.ics_* de la base).
type Store interface {
	// DueFeeds prend au plus limit flux dus, avec un bail : un flux pris
	// n'est pas repris avant son échéance.
	DueFeeds(ctx context.Context, limit int) ([]Feed, error)
	// Apply remplace le contenu d'un agenda par un flux lu, en une
	// transaction.
	Apply(ctx context.Context, calendarID string, events []Event, etag, lastModified string) error
	// RecordUnchanged note un flux inchangé.
	RecordUnchanged(ctx context.Context, calendarID string) error
	// RecordFailure note un échec et repousse la relecture.
	RecordFailure(ctx context.Context, calendarID string, failure Failure) error
}

// ErrRejectedFeed signale un flux lu que la base refuse (donnée que la
// lecture n'a pas su borner) : il est noté comme illisible plutôt que
// relu en boucle.
var ErrRejectedFeed = errors.New("ics: feed rejected by the database")

// Fetcher télécharge un flux (implémenté par HTTPFetcher). L'erreur est une
// Failure, ou celle de ctx.
type Fetcher interface {
	Fetch(ctx context.Context, feed Feed) (Result, error)
}

// batchSize : flux pris à la fois. Relus un par un, 20 s au plus chacun,
// ils tiennent largement dans le bail de 10 minutes de la base.
const batchSize = 10

// Service relit les flux dus.
//
// Invariant : les flux se relisent un à la fois ; un échec ne bloque pas
// les suivants. Un échec d'écriture en base n'est pas noté (le bail expire
// et le flux sera repris), sauf un contenu refusé (ErrRejectedFeed), noté
// illisible.
type Service struct {
	store   Store
	fetcher Fetcher
	now     func() time.Time
	logger  *slog.Logger
}

// NewService construit le service ; now est time.Now en production.
func NewService(store Store, fetcher Fetcher, now func() time.Time, logger *slog.Logger) *Service {
	return &Service{store: store, fetcher: fetcher, now: now, logger: logger}
}

// SyncDue relit tous les flux dus, par lots.
func (s *Service) SyncDue(ctx context.Context) error {
	for {
		feeds, err := s.store.DueFeeds(ctx, batchSize)
		if err != nil {
			return fmt.Errorf("take due feeds: %w", err)
		}
		for _, feed := range feeds {
			if err := s.Sync(ctx, feed); err != nil {
				if ctx.Err() != nil {
					return ctx.Err()
				}
				s.logger.Error("feed sync failed", "calendar", feed, "err", err)
			}
		}
		if len(feeds) < batchSize {
			return nil
		}
	}
}

// Sync relit un flux. Rend une erreur quand la base n'a rien pu noter ;
// un flux injoignable ou illisible est un échec noté, pas une erreur.
func (s *Service) Sync(ctx context.Context, feed Feed) error {
	result, err := s.fetcher.Fetch(ctx, feed)
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil {
		return s.fail(ctx, feed, err)
	}
	if result.NotModified {
		if err := s.store.RecordUnchanged(ctx, feed.CalendarID); err != nil {
			return fmt.Errorf("record unchanged: %w", err)
		}
		return nil
	}
	events, err := Parse(result.Body, s.now())
	if err != nil {
		return s.fail(ctx, feed, err)
	}
	err = s.store.Apply(ctx, feed.CalendarID, events, result.ETag, result.LastModified)
	if errors.Is(err, ErrRejectedFeed) {
		return s.fail(ctx, feed, FailureNotCalendar)
	}
	if err != nil {
		return fmt.Errorf("apply feed: %w", err)
	}
	s.logger.Info("feed synced", "calendar", feed, "events", len(events))
	return nil
}

// fail note un échec. Une erreur qui n'est pas une Failure (ce qui ne
// devrait pas arriver) est notée « injoignable », sans son texte.
func (s *Service) fail(ctx context.Context, feed Feed, err error) error {
	var failure Failure
	if !errors.As(err, &failure) {
		failure = FailureUnreachable
	}
	s.logger.Warn("feed sync failed", "calendar", feed, "reason", string(failure))
	if err := s.store.RecordFailure(ctx, feed.CalendarID, failure); err != nil {
		return fmt.Errorf("record failure: %w", err)
	}
	return nil
}

// Run relit les flux dus à chaque réveil (nouveau flux, « Synchroniser
// maintenant », reconnexion de l'écoute) et toutes les every, jusqu'à
// l'annulation de ctx.
func (s *Service) Run(ctx context.Context, wake <-chan struct{}, every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-wake:
		case <-ticker.C:
		}
		if err := s.SyncDue(ctx); err != nil && ctx.Err() == nil {
			s.logger.Error("feed sync round failed", "err", err)
		}
	}
}
