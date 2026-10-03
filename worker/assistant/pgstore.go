package assistant

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// statementTimeout est celui que PostgREST pose à authenticated : SET ROLE
// ne l'hérite pas, le worker le pose donc lui-même.
const statementTimeout = "8s"

// PgStore implémente Store sous le rôle agora_worker, qui endosse
// `authenticated` le temps de chaque transaction (grant … with inherit false,
// set true) : SET LOCAL ROLE, puis les claims {sub, role} dans
// request.jwt.claims. La RLS, les GRANT par colonne et les RPC s'appliquent
// alors exactement comme pour l'application.
//
// Invariants :
//   - jamais de requête sans identifiant de membre : sans `sub`, deux
//     déclencheurs (check_event_series, check_event_move) prendraient l'appel
//     pour le serveur ;
//   - les claims ne portent PAS client_id : les politiques qui ferment le
//     temps réel aux jetons d'assistant ne visent pas le worker, qui lit
//     comme l'app ;
//   - rôle et claims sont locaux à la transaction : la connexion rendue au
//     pool redevient agora_worker.
type PgStore struct {
	pool *pgxpool.Pool
}

// NewPgStore construit le stockage sur un pool connecté en agora_worker.
func NewPgStore(pool *pgxpool.Pool) *PgStore {
	return &PgStore{pool: pool}
}

var errNoUser = errors.New("assistant: aucun membre désigné")

// asUser exécute fn au nom du membre, dans une transaction.
func (s *PgStore) asUser(ctx context.Context, userID string, fn func(pgx.Tx) error) error {
	if !isUUID(userID) {
		return errNoUser
	}
	claims, err := json.Marshal(map[string]string{"sub": userID, "role": "authenticated"})
	if err != nil {
		return fmt.Errorf("claims: %w", err)
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }() // sans effet après Commit
	if _, err := tx.Exec(ctx, "set local role authenticated"); err != nil {
		return fmt.Errorf("set role: %w", err)
	}
	if _, err := tx.Exec(ctx, `select set_config('request.jwt.claims', $1, true),
		set_config('statement_timeout', $2, true)`, string(claims), statementTimeout); err != nil {
		return fmt.Errorf("set claims: %w", err)
	}
	if err := fn(tx); err != nil {
		return refusalOf(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit: %w", refusalOf(err))
	}
	return nil
}

// refusalOf traduit les refus nommés des fonctions SQL et ceux des droits.
func refusalOf(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return err
	}
	switch {
	case pgErr.Message == "not_a_member":
		return ErrNotMember
	case pgErr.Message == "invalid_range":
		return ErrInvalidRange
	case pgErr.Message == "event_not_found":
		return ErrEventNotFound
	case pgErr.Message == "invalid_occurrence":
		return ErrInvalidOccurrence
	case pgErr.Code == "42501":
		return ErrForbidden
	case pgErr.Code == "23514" || pgErr.Code == "22001":
		return ErrInvalidValue
	}
	return err
}

// Profile lit le fuseau du membre.
func (s *PgStore) Profile(ctx context.Context, userID string) (Profile, error) {
	var p Profile
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select timezone from public.profiles where id = $1::uuid`, userID).Scan(&p.Timezone)
	})
	if err != nil {
		return Profile{}, fmt.Errorf("profile: %w", err)
	}
	return p, nil
}

// Groups lit ses groupes comme l'app (group_members + groups), puis leurs
// membres et leurs noms, que la RLS ouvre aux membres d'un même groupe.
func (s *PgStore) Groups(ctx context.Context, userID string) ([]Group, error) {
	var groups []Group
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select g.id::text, g.name, coalesce(g.description, ''),
				gm.role::text, gm.share_level::text
			from public.group_members gm join public.groups g on g.id = gm.group_id
			where gm.user_id = $1::uuid
			order by gm.joined_at`, userID)
		if err != nil {
			return err
		}
		groups, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (Group, error) {
			var g Group
			err := row.Scan(&g.ID, &g.Name, &g.Description, &g.MyRole, &g.MyShare)
			return g, err
		})
		if err != nil || len(groups) == 0 {
			return err
		}
		return s.fillMembers(ctx, tx, groups)
	})
	if err != nil {
		return nil, fmt.Errorf("groups: %w", err)
	}
	return groups, nil
}

func (s *PgStore) fillMembers(ctx context.Context, tx pgx.Tx, groups []Group) error {
	ids := make([]string, len(groups))
	index := make(map[string]int, len(groups))
	for i, g := range groups {
		ids[i] = g.ID
		index[g.ID] = i
	}
	rows, err := tx.Query(ctx, `select gm.group_id::text, gm.user_id::text, p.display_name, gm.role::text
		from public.group_members gm join public.profiles p on p.id = gm.user_id
		where gm.group_id = any($1::uuid[])
		order by gm.joined_at`, ids)
	if err != nil {
		return err
	}
	_, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (struct{}, error) {
		var groupID string
		var m Member
		if err := row.Scan(&groupID, &m.UserID, &m.Name, &m.Role); err != nil {
			return struct{}{}, err
		}
		g := &groups[index[groupID]]
		g.Members = append(g.Members, m)
		return struct{}{}, nil
	})
	return err
}

// Calendars lit ses agendas et ceux de ses groupes (pas ceux des autres
// membres, que la RLS ouvrirait pour l'affichage superposé).
func (s *PgStore) Calendars(ctx context.Context, userID string) ([]Calendar, error) {
	var calendars []Calendar
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select c.id::text, c.name, coalesce(c.group_id::text, ''),
				c.owner_id is not distinct from $1::uuid, c.kind = 'native', c.created_at
			from public.calendars c
			where c.owner_id = $1::uuid
			   or c.group_id in (select group_id from public.group_members where user_id = $1::uuid)
			order by c.created_at`, userID)
		if err != nil {
			return err
		}
		calendars, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (Calendar, error) {
			var c Calendar
			err := row.Scan(&c.ID, &c.Name, &c.GroupID, &c.Personal, &c.Native, &c.CreatedAt)
			return c, err
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("calendars: %w", err)
	}
	return calendars, nil
}

// MyAgenda lit public.my_agenda.
func (s *PgStore) MyAgenda(ctx context.Context, userID string, from, to time.Time) ([]Entry, error) {
	var entries []Entry
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select event_id::text, coalesce(series_id::text, ''), original_start,
				calendar_id::text, title, coalesce(location, ''), coalesce(description, ''),
				starts_at, ends_at, all_day, coalesce(rrule, ''), coalesce(my_response::text, '')
			from public.my_agenda($1, $2)
			order by starts_at`, from, to)
		if err != nil {
			return err
		}
		entries, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (Entry, error) {
			var e Entry
			err := row.Scan(&e.EventID, &e.SeriesID, &e.OriginalStart, &e.CalendarID, &e.Title,
				&e.Location, &e.Description, &e.Start, &e.End, &e.AllDay, &e.Rrule, &e.MyResponse)
			return e, err
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("my agenda: %w", err)
	}
	return entries, nil
}

// GroupAgenda lit public.group_agenda : le seul chemin de sortie du détail
// d'un rdv d'autrui (private.resolve_group_agenda, lecteur = le membre).
func (s *PgStore) GroupAgenda(ctx context.Context, userID, groupID string, from, to time.Time) ([]GroupEntry, error) {
	var entries []GroupEntry
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select coalesce(event_id::text, ''), coalesce(user_id::text, ''),
				is_group_event, level::text, coalesce(title, ''), coalesce(location, ''),
				starts_at, ends_at, all_day
			from public.group_agenda($1::uuid, $2, $3)
			order by starts_at`, groupID, from, to)
		if err != nil {
			return err
		}
		entries, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (GroupEntry, error) {
			var e GroupEntry
			err := row.Scan(&e.EventID, &e.UserID, &e.IsGroupEvent, &e.Level, &e.Title, &e.Location,
				&e.Start, &e.End, &e.AllDay)
			return e, err
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("group agenda: %w", err)
	}
	return entries, nil
}

// CreateEvent insère le rdv comme l'app : INSERT sous la RLS (can_add_event).
func (s *PgStore) CreateEvent(ctx context.Context, userID string, d Draft) (string, error) {
	var id string
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `insert into public.events
				(calendar_id, title, location, description, starts_at, ends_at, all_day, timezone)
			values ($1::uuid, $2, nullif($3, ''), nullif($4, ''), $5, $6, $7, $8)
			returning id::text`,
			d.CalendarID, d.Title, d.Location, d.Description, d.Start, d.End, d.AllDay, d.Timezone).Scan(&id)
	})
	if err != nil {
		return "", fmt.Errorf("create event: %w", err)
	}
	return id, nil
}

// Respond appelle public.respond_to_event.
func (s *PgStore) Respond(ctx context.Context, userID, eventID string, occurrence *time.Time, status string) error {
	err := s.asUser(ctx, userID, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `select public.respond_to_event($1::uuid, $2,
				nullif($3, '')::public.response_status)`, eventID, occurrence, status)
		return err
	})
	if err != nil {
		return fmt.Errorf("respond: %w", err)
	}
	return nil
}
