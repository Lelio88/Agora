package ics

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PgStore implémente Store sous le rôle agora_worker, qui n'atteint le
// schéma private que par les quatre fonctions private.ics_* : il ne lit ni
// n'écrit aucune table de flux directement.
type PgStore struct {
	pool *pgxpool.Pool
}

// NewPgStore construit le stockage sur un pool connecté en agora_worker.
func NewPgStore(pool *pgxpool.Pool) *PgStore {
	return &PgStore{pool: pool}
}

// DueFeeds prend les flux dus (private.ics_due_feeds).
func (s *PgStore) DueFeeds(ctx context.Context, limit int) ([]Feed, error) {
	rows, err := s.pool.Query(ctx, `
		select calendar_id::text, url, coalesce(etag, ''), coalesce(last_modified, '')
		from private.ics_due_feeds($1)`, limit)
	if err != nil {
		return nil, fmt.Errorf("query due feeds: %w", err)
	}
	feeds, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Feed, error) {
		var f Feed
		err := row.Scan(&f.CalendarID, &f.URL, &f.ETag, &f.LastModified)
		return f, err
	})
	if err != nil {
		return nil, fmt.Errorf("collect due feeds: %w", err)
	}
	return feeds, nil
}

// Apply applique un flux lu (private.ics_apply).
func (s *PgStore) Apply(ctx context.Context, calendarID string, events []Event, etag, lastModified string) error {
	if events == nil {
		events = []Event{}
	}
	payload, err := json.Marshal(events)
	if err != nil {
		return fmt.Errorf("encode events: %w", err)
	}
	_, err = s.pool.Exec(ctx,
		`select private.ics_apply($1::uuid, $2::jsonb, nullif($3, ''), nullif($4, ''))`,
		calendarID, string(payload), etag, lastModified)
	if rejectedData(err) {
		return fmt.Errorf("apply events: %w", ErrRejectedFeed)
	}
	if err != nil {
		return fmt.Errorf("apply events: %w", err)
	}
	return nil
}

// rejectedData dit si Postgres a refusé le contenu du flux lui-même
// (donnée invalide, contrainte, doublon dans une même commande) : le relire
// dans 10 minutes n'y changerait rien.
func rejectedData(err error) bool {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || len(pgErr.Code) < 2 {
		return false
	}
	switch pgErr.Code[:2] {
	case "21", "22", "23": // cardinalité, donnée invalide, contrainte
		return true
	}
	return false
}

// RecordUnchanged note un flux inchangé (private.ics_record_unchanged).
func (s *PgStore) RecordUnchanged(ctx context.Context, calendarID string) error {
	if _, err := s.pool.Exec(ctx, `select private.ics_record_unchanged($1::uuid)`, calendarID); err != nil {
		return fmt.Errorf("record unchanged: %w", err)
	}
	return nil
}

// RecordFailure note un échec (private.ics_record_failure).
func (s *PgStore) RecordFailure(ctx context.Context, calendarID string, failure Failure) error {
	_, err := s.pool.Exec(ctx, `select private.ics_record_failure($1::uuid, $2)`,
		calendarID, string(failure))
	if err != nil {
		return fmt.Errorf("record failure: %w", err)
	}
	return nil
}
