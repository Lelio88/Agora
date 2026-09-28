package discord

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PgStore implémente Store sous le rôle agora_worker, qui n'atteint le bot
// que par les fonctions private.discord_* : aucune lecture directe de table.
type PgStore struct {
	pool *pgxpool.Pool
}

// NewPgStore construit le stockage sur un pool connecté en agora_worker.
func NewPgStore(pool *pgxpool.Pool) *PgStore {
	return &PgStore{pool: pool}
}

// refusals traduit les refus nommés des fonctions SQL.
var refusals = map[string]error{
	"discord_not_linked": ErrNotLinked,
	"link_code_invalid":  ErrCodeInvalid,
	"not_group_admin":    ErrNotAdmin,
	"channel_taken":      ErrChannelTaken,
	"not_a_member":       ErrNotMember,
}

func refusal(err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		if known, ok := refusals[pgErr.Message]; ok {
			return known
		}
	}
	return err
}

// Account lit private.discord_user.
func (s *PgStore) Account(ctx context.Context, discordID string) (Account, bool, error) {
	var a Account
	err := s.pool.QueryRow(ctx,
		`select user_id::text, timezone, locale from private.discord_user($1)`, discordID).
		Scan(&a.UserID, &a.Timezone, &a.Locale)
	if errors.Is(err, pgx.ErrNoRows) {
		return Account{}, false, nil
	}
	if err != nil {
		return Account{}, false, fmt.Errorf("discord user: %w", err)
	}
	return a, true, nil
}

// LinkChannel appelle private.discord_link_channel.
func (s *PgStore) LinkChannel(ctx context.Context, code, guildID, channelID, channelName, discordID string) (string, error) {
	var name string
	err := s.pool.QueryRow(ctx, `select private.discord_link_channel($1, $2, $3, $4, $5)`,
		code, guildID, channelID, channelName, discordID).Scan(&name)
	if err != nil {
		return "", fmt.Errorf("link channel: %w", refusal(err))
	}
	return name, nil
}

// UnlinkChannel appelle private.discord_unlink_channel.
func (s *PgStore) UnlinkChannel(ctx context.Context, channelID, discordID string) (string, bool, error) {
	var name *string
	err := s.pool.QueryRow(ctx, `select private.discord_unlink_channel($1, $2)`, channelID, discordID).Scan(&name)
	if err != nil {
		return "", false, fmt.Errorf("unlink channel: %w", refusal(err))
	}
	if name == nil {
		return "", false, nil
	}
	return *name, true, nil
}

// ChannelGroup lit private.discord_channel_group.
func (s *PgStore) ChannelGroup(ctx context.Context, channelID string) (Group, bool, error) {
	var g Group
	err := s.pool.QueryRow(ctx,
		`select group_id::text, name from private.discord_channel_group($1)`, channelID).
		Scan(&g.ID, &g.Name)
	if errors.Is(err, pgx.ErrNoRows) {
		return Group{}, false, nil
	}
	if err != nil {
		return Group{}, false, fmt.Errorf("channel group: %w", err)
	}
	return g, true, nil
}

const agendaColumns = `coalesce(user_id::text, ''), coalesce(display_name, ''), is_group_event,
	level::text, coalesce(title, ''), coalesce(location, ''), starts_at, ends_at, all_day`

func scanAgenda(row pgx.CollectableRow) (AgendaItem, error) {
	var a AgendaItem
	err := row.Scan(&a.UserID, &a.DisplayName, &a.IsGroupEvent, &a.Level,
		&a.Title, &a.Location, &a.Start, &a.End, &a.AllDay)
	return a, err
}

// GroupAgenda lit private.discord_group_agenda.
func (s *PgStore) GroupAgenda(ctx context.Context, groupID, userID string, from, to time.Time) ([]AgendaItem, error) {
	rows, err := s.pool.Query(ctx, `select `+agendaColumns+`
		from private.discord_group_agenda($1::uuid, $2::uuid, $3, $4)`, groupID, userID, from, to)
	if err != nil {
		return nil, fmt.Errorf("group agenda: %w", refusal(err))
	}
	items, err := pgx.CollectRows(rows, scanAgenda)
	if err != nil {
		return nil, fmt.Errorf("group agenda: %w", refusal(err))
	}
	return items, nil
}

// GroupMembers lit private.discord_group_members.
func (s *PgStore) GroupMembers(ctx context.Context, groupID, userID string) ([]Member, error) {
	rows, err := s.pool.Query(ctx, `select user_id::text, display_name
		from private.discord_group_members($1::uuid, $2::uuid)`, groupID, userID)
	if err != nil {
		return nil, fmt.Errorf("group members: %w", refusal(err))
	}
	members, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Member, error) {
		var m Member
		err := row.Scan(&m.UserID, &m.DisplayName)
		return m, err
	})
	if err != nil {
		return nil, fmt.Errorf("group members: %w", refusal(err))
	}
	return members, nil
}

// PersonalAgenda lit private.discord_personal_agenda.
func (s *PgStore) PersonalAgenda(ctx context.Context, userID string, from, to time.Time) ([]PersonalItem, error) {
	rows, err := s.pool.Query(ctx, `select title, coalesce(location, ''), coalesce(group_name, ''),
		starts_at, ends_at, all_day
		from private.discord_personal_agenda($1::uuid, $2, $3)`, userID, from, to)
	if err != nil {
		return nil, fmt.Errorf("personal agenda: %w", err)
	}
	items, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (PersonalItem, error) {
		var p PersonalItem
		err := row.Scan(&p.Title, &p.Location, &p.GroupName, &p.Start, &p.End, &p.AllDay)
		return p, err
	})
	if err != nil {
		return nil, fmt.Errorf("personal agenda: %w", err)
	}
	return items, nil
}

// ClaimRecaps appelle private.discord_claim_recaps.
func (s *PgStore) ClaimRecaps(ctx context.Context) ([]Recap, error) {
	rows, err := s.pool.Query(ctx, `select group_id::text, group_name, channel_id, timezone,
		locale, recap::text, slot from private.discord_claim_recaps()`)
	if err != nil {
		return nil, fmt.Errorf("claim recaps: %w", err)
	}
	recaps, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Recap, error) {
		var r Recap
		err := row.Scan(&r.GroupID, &r.GroupName, &r.ChannelID, &r.Timezone, &r.Locale, &r.Kind, &r.Slot)
		return r, err
	})
	if err != nil {
		return nil, fmt.Errorf("claim recaps: %w", err)
	}
	return recaps, nil
}

// RecapAgenda lit private.discord_recap_agenda.
func (s *PgStore) RecapAgenda(ctx context.Context, groupID string, from, to time.Time) ([]AgendaItem, error) {
	rows, err := s.pool.Query(ctx, `select `+agendaColumns+`
		from private.discord_recap_agenda($1::uuid, $2, $3)`, groupID, from, to)
	if err != nil {
		return nil, fmt.Errorf("recap agenda: %w", err)
	}
	items, err := pgx.CollectRows(rows, scanAgenda)
	if err != nil {
		return nil, fmt.Errorf("recap agenda: %w", err)
	}
	return items, nil
}

// ClaimReminders appelle private.discord_claim_reminders.
func (s *PgStore) ClaimReminders(ctx context.Context) ([]Reminder, error) {
	rows, err := s.pool.Query(ctx, `select channel_id, timezone, locale, group_name, title,
		coalesce(location, ''), starts_at, ends_at from private.discord_claim_reminders()`)
	if err != nil {
		return nil, fmt.Errorf("claim reminders: %w", err)
	}
	reminders, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Reminder, error) {
		var r Reminder
		err := row.Scan(&r.ChannelID, &r.Timezone, &r.Locale, &r.GroupName, &r.Title,
			&r.Location, &r.Start, &r.End)
		return r, err
	})
	if err != nil {
		return nil, fmt.Errorf("claim reminders: %w", err)
	}
	return reminders, nil
}
