package recurrence

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PgStore implémente Store sur Postgres, sous le rôle agora_worker : lecture
// des colonnes d'horaire de public.events, écriture de
// public.event_occurrences et du signal public.series_expansions, rien
// d'autre.
type PgStore struct {
	pool *pgxpool.Pool
}

// NewPgStore construit le stockage sur un pool connecté en agora_worker.
func NewPgStore(pool *pgxpool.Pool) *PgStore {
	return &PgStore{pool: pool}
}

const loadSeriesQuery = `
select e.starts_at, e.ends_at, e.all_day, e.timezone, e.rrule, e.exdates,
       coalesce(array(select x.recurrence_id from public.events x where x.series_id = e.id),
                '{}'::timestamptz[])
from public.events e
where e.id = $1 and e.rrule is not null and e.series_id is null`

// lockSeriesQuery prend le verrou d'une série pour la transaction. La clé
// est un contrat partagé avec la base : private.lock_series(uuid) calcule
// la même, et replace_occurrence, delete_occurrence et le trigger
// hide_replaced_occurrence la prennent avant de toucher aux occurrences.
const lockSeriesQuery = `select pg_advisory_xact_lock(hashtextextended($1::uuid::text, 0))`

// ListSeriesIDs liste les lignes maîtresses de toutes les séries.
func (s *PgStore) ListSeriesIDs(ctx context.Context) ([]string, error) {
	rows, err := s.pool.Query(ctx,
		`select e.id::text from public.events e where e.rrule is not null and e.series_id is null`)
	if err != nil {
		return nil, fmt.Errorf("query series ids: %w", err)
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, fmt.Errorf("collect series ids: %w", err)
	}
	return ids, nil
}

// UpdateOccurrences lit la série, calcule ses occurrences et les écrit dans
// une seule transaction, sous le verrou de la série pris AVANT la lecture :
// une exception posée pendant le calcul attend la fin de l'écriture, ou
// l'écriture attend qu'elle soit validée et la relit.
//
// Des occurrences identiques à celles en base ne sont pas réécrites : le
// dépliage complet des 6 heures ne touche alors que les séries dont la
// fenêtre a réellement bougé. Quand elles changent, la série est signalée
// dans series_expansions, que l'app écoute en temps réel pour relire
// l'agenda (event_occurrences n'est pas publiée, voir la migration).
func (s *PgStore) UpdateOccurrences(ctx context.Context, seriesID string, compute Compute) error {
	var id pgtype.UUID
	if err := id.Scan(seriesID); err != nil {
		return fmt.Errorf("parse series id: %w", err)
	}
	return pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, lockSeriesQuery, id); err != nil {
			return fmt.Errorf("lock series: %w", err)
		}
		series, found, err := loadSeries(ctx, tx, id, seriesID)
		if err != nil {
			return err
		}
		occurrences, err := compute(series, found)
		if err != nil {
			return err
		}
		current, err := loadOccurrences(ctx, tx, id)
		if err != nil {
			return err
		}
		if sameOccurrences(current, occurrences) {
			return nil
		}
		if _, err := tx.Exec(ctx, `delete from public.event_occurrences where event_id = $1`, id); err != nil {
			return fmt.Errorf("delete occurrences: %w", err)
		}
		if err := insertOccurrences(ctx, tx, id, occurrences); err != nil {
			return err
		}
		// Pas de signal pour une série disparue : la suppression du rdv
		// suffit à l'app, et la clé étrangère refuserait la ligne.
		_, err = tx.Exec(ctx, `
			insert into public.series_expansions (series_id, expanded_at)
			select $1, now() where exists (select 1 from public.events e where e.id = $1)
			on conflict (series_id) do update set expanded_at = excluded.expanded_at`, id)
		if err != nil {
			return fmt.Errorf("signal expansion: %w", err)
		}
		return nil
	})
}

// loadSeries lit une série et les créneaux de ses occurrences modifiées ;
// found est faux si elle n'existe plus ou ne se répète plus.
func loadSeries(ctx context.Context, tx pgx.Tx, id pgtype.UUID, seriesID string) (Series, bool, error) {
	series := Series{ID: seriesID}
	var rule string
	err := tx.QueryRow(ctx, loadSeriesQuery, id).Scan(
		&series.Start, &series.End, &series.AllDay, &series.Timezone,
		&rule, &series.Exdates, &series.ReplacedSlots,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Series{}, false, nil
	}
	if err != nil {
		return Series{}, false, fmt.Errorf("query series: %w", err)
	}
	series.RRule = rule
	return series, true, nil
}

func loadOccurrences(ctx context.Context, tx pgx.Tx, id pgtype.UUID) ([]Occurrence, error) {
	rows, err := tx.Query(ctx,
		`select starts_at, ends_at from public.event_occurrences where event_id = $1`, id)
	if err != nil {
		return nil, fmt.Errorf("query occurrences: %w", err)
	}
	current, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Occurrence, error) {
		var o Occurrence
		err := row.Scan(&o.Start, &o.End)
		return o, err
	})
	if err != nil {
		return nil, fmt.Errorf("collect occurrences: %w", err)
	}
	return current, nil
}

// sameOccurrences compare deux ensembles d'occurrences, sans tenir compte de
// l'ordre ni du fuseau des time.Time (la base les rend en UTC).
func sameOccurrences(a, b []Occurrence) bool {
	if len(a) != len(b) {
		return false
	}
	ends := make(map[int64]int64, len(a))
	for _, o := range a {
		ends[o.Start.UnixNano()] = o.End.UnixNano()
	}
	for _, o := range b {
		end, ok := ends[o.Start.UnixNano()]
		if !ok || end != o.End.UnixNano() {
			return false
		}
	}
	return true
}

// insertOccurrences écrit les occurrences en un seul INSERT à partir de deux
// tableaux : COPY serait plus rapide, mais Postgres le refuse sur une table
// protégée par RLS.
func insertOccurrences(ctx context.Context, tx pgx.Tx, id pgtype.UUID, occurrences []Occurrence) error {
	if len(occurrences) == 0 {
		return nil
	}
	starts := make([]time.Time, len(occurrences))
	ends := make([]time.Time, len(occurrences))
	for i, o := range occurrences {
		starts[i] = o.Start
		ends[i] = o.End
	}
	_, err := tx.Exec(ctx, `
		insert into public.event_occurrences (event_id, starts_at, ends_at)
		select $1, s, e from unnest($2::timestamptz[], $3::timestamptz[]) as u(s, e)`,
		id, starts, ends)
	if err != nil {
		return fmt.Errorf("insert occurrences: %w", err)
	}
	return nil
}

// Channel est le canal NOTIFY sur lequel la base signale une série à
// redéplier (trigger events_notify_recurrence).
const Channel = "agora_recurrence"

const (
	listenInitialBackoff = time.Second
	listenMaxBackoff     = time.Minute
)

// Listen écoute Channel sur une connexion dédiée (jamais une connexion du
// pool : un LISTEN resterait actif après sa restitution) et pousse chaque
// identifiant reçu dans notifications. onConnected est appelé à chaque
// (re)connexion : les notifications émises pendant la coupure sont perdues,
// il faut alors tout redéplier. Rend la main à l'annulation de ctx.
func Listen(ctx context.Context, databaseURL string, notifications chan<- string, onConnected func(), logger *slog.Logger) {
	backoff := listenInitialBackoff
	for ctx.Err() == nil {
		err := listenOnce(ctx, databaseURL, notifications, func() {
			backoff = listenInitialBackoff
			onConnected()
		})
		if ctx.Err() != nil {
			return
		}
		logger.Warn("listener disconnected", "err", err, "retry_in", backoff)
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, listenMaxBackoff)
	}
}

func listenOnce(ctx context.Context, databaseURL string, notifications chan<- string, onConnected func()) error {
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	defer conn.Close(context.WithoutCancel(ctx))
	if _, err := conn.Exec(ctx, "listen "+pgx.Identifier{Channel}.Sanitize()); err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	onConnected()
	for {
		notification, err := conn.WaitForNotification(ctx)
		if err != nil {
			return fmt.Errorf("wait for notification: %w", err)
		}
		select {
		case notifications <- notification.Payload:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}
