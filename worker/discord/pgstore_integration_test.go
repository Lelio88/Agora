//go:build integration

package discord

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Exige la pile Supabase locale (supabase start) : AGORA_TEST_DATABASE_URL
// pour le rôle du worker, AGORA_TEST_ADMIN_URL (postgres) pour les
// fixtures. Vérifie que le rôle agora_worker atteint bien chaque fonction
// private.discord_* et que les refus SQL deviennent les erreurs du paquet.

const (
	adaID   = "d15c0000-0000-0000-0000-0000000000a1"
	benID   = "d15c0000-0000-0000-0000-0000000000b2"
	groupID = "d15c0000-0000-0000-0000-0000000000c3"
)

func openPools(t *testing.T) (worker, admin *pgxpool.Pool) {
	t.Helper()
	workerURL, adminURL := os.Getenv("AGORA_TEST_DATABASE_URL"), os.Getenv("AGORA_TEST_ADMIN_URL")
	if workerURL == "" || adminURL == "" {
		t.Fatal("AGORA_TEST_DATABASE_URL and AGORA_TEST_ADMIN_URL are required")
	}
	ctx := context.Background()
	worker, err := pgxpool.New(ctx, workerURL)
	if err != nil {
		t.Fatalf("connect as worker: %v", err)
	}
	t.Cleanup(worker.Close)
	admin, err = pgxpool.New(ctx, adminURL)
	if err != nil {
		t.Fatalf("connect as admin: %v", err)
	}
	t.Cleanup(admin.Close)
	return worker, admin
}

func exec(t *testing.T, admin *pgxpool.Pool, sql string, args ...any) {
	t.Helper()
	if _, err := admin.Exec(context.Background(), sql, args...); err != nil {
		t.Fatalf("%s: %v", sql, err)
	}
}

// installGroup crée Ada (propriétaire, Discord relié) et Ben (membre, non
// relié), le groupe, son agenda et un rdv personnel de Ben.
func installGroup(t *testing.T, admin *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	cleanup := func() {
		_, _ = admin.Exec(ctx, `delete from public.groups where id = $1`, groupID)
		_, _ = admin.Exec(ctx, `delete from auth.users where id in ($1, $2)`, adaID, benID)
	}
	cleanup()
	t.Cleanup(cleanup)
	exec(t, admin, `insert into auth.users (id, email, raw_user_meta_data) values
		($1, 'ada.discord@test.local', '{"display_name":"Ada"}'),
		($2, 'ben.discord@test.local', '{"display_name":"Ben"}')`, adaID, benID)
	exec(t, admin, `insert into auth.identities (provider_id, user_id, identity_data, provider)
		values ('777000000000000001', $1, '{"sub":"777000000000000001"}', 'discord')`, adaID)
	exec(t, admin, `insert into public.groups (id, name) values ($1, 'Potes')`, groupID)
	exec(t, admin, `insert into public.group_members (group_id, user_id, role, share_level) values
		($1, $2, 'owner', 'details'), ($1, $3, 'member', 'details')`, groupID, adaID, benID)
	// L'inscription donne déjà un agenda à chacun : le rdv va dans l'un d'eux.
	exec(t, admin, `insert into public.events (calendar_id, title, location, starts_at, ends_at)
		select id, 'Kiné', 'Cabinet', now() + interval '1 hour', now() + interval '2 hours'
		from public.calendars where owner_id = $1 order by created_at limit 1`, benID)
	exec(t, admin, `insert into private.discord_link_codes (code, group_id, created_by)
		values ('DISCORD1', $1, $2)`, groupID, adaID)
}

func TestPgStoreLinksReadsAndCapsTheRecap(t *testing.T) {
	worker, admin := openPools(t)
	installGroup(t, admin)
	store := NewPgStore(worker)
	ctx := context.Background()

	account, ok, err := store.Account(ctx, "777000000000000001")
	if err != nil || !ok || account.UserID != adaID {
		t.Fatalf("Account = %+v, %v, %v", account, ok, err)
	}

	if _, err := store.LinkChannel(ctx, "DISCORD1", "1", "555", "général", "999"); !errors.Is(err, ErrNotLinked) {
		t.Fatalf("un compte non relié : err = %v", err)
	}
	name, err := store.LinkChannel(ctx, "discord1", "1", "555", "général", "777000000000000001")
	if err != nil || name != "Potes" {
		t.Fatalf("LinkChannel = %q, %v", name, err)
	}
	if _, err := store.LinkChannel(ctx, "DISCORD1", "1", "555", "général", "777000000000000001"); !errors.Is(err, ErrCodeInvalid) {
		t.Fatalf("un code déjà servi : err = %v", err)
	}

	group, ok, err := store.ChannelGroup(ctx, "555")
	if err != nil || !ok || group.ID != groupID {
		t.Fatalf("ChannelGroup = %+v, %v, %v", group, ok, err)
	}

	from, to := time.Now(), time.Now().Add(24*time.Hour)
	items, err := store.GroupAgenda(ctx, groupID, adaID, from, to)
	if err != nil || len(items) != 1 || items[0].Title != "Kiné" || items[0].DisplayName != "Ben" {
		t.Fatalf("GroupAgenda = %+v, %v", items, err)
	}
	recap, err := store.RecapAgenda(ctx, groupID, from, to)
	if err != nil || len(recap) != 1 || recap[0].Title != "" || recap[0].Level != "busy" {
		t.Fatalf("RecapAgenda = %+v, %v : un rdv personnel doit y être « occupé »", recap, err)
	}
	if _, err := store.GroupAgenda(ctx, groupID, "d15c0000-0000-0000-0000-0000000000ff", from, to); !errors.Is(err, ErrNotMember) {
		t.Fatalf("hors du groupe : err = %v", err)
	}

	members, err := store.GroupMembers(ctx, groupID, adaID)
	if err != nil || len(members) != 2 {
		t.Fatalf("GroupMembers = %+v, %v", members, err)
	}
	if _, err := store.PersonalAgenda(ctx, benID, from, to); err != nil {
		t.Fatalf("PersonalAgenda : %v", err)
	}
	if _, err := store.ClaimRecaps(ctx); err != nil {
		t.Fatalf("ClaimRecaps : %v", err)
	}
	if _, err := store.ClaimReminders(ctx); err != nil {
		t.Fatalf("ClaimReminders : %v", err)
	}

	if _, _, err := store.UnlinkChannel(ctx, "555", "999"); !errors.Is(err, ErrNotLinked) {
		t.Fatalf("délier sans compte relié : err = %v", err)
	}
	gone, ok, err := store.UnlinkChannel(ctx, "555", "777000000000000001")
	if err != nil || !ok || gone != "Potes" {
		t.Fatalf("UnlinkChannel = %q, %v, %v", gone, ok, err)
	}
}
