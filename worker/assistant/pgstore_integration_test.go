//go:build integration

package assistant

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
// fixtures. C'est la vraie preuve de la bascule : connecté en agora_worker,
// le stockage lit et écrit comme le membre, règle de visibilité comprise.

const (
	itAda    = "a551a000-0000-0000-0000-0000000000a1"
	itBen    = "a551a000-0000-0000-0000-0000000000b2"
	itCleo   = "a551a000-0000-0000-0000-0000000000c3"
	itGroup  = "a551a000-0000-0000-0000-0000000000d4"
	itOthers = "a551a000-0000-0000-0000-0000000000e5"
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

// installGroup : Ada et Ben dans « Potes » (Ben ne partage que « occupé »),
// Cléo seule dans un autre groupe ; Ben a un rdv perso demain.
func installGroup(t *testing.T, admin *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	cleanup := func() {
		_, _ = admin.Exec(ctx, `delete from public.groups where id in ($1, $2)`, itGroup, itOthers)
		_, _ = admin.Exec(ctx, `delete from auth.users where id in ($1, $2, $3)`, itAda, itBen, itCleo)
	}
	cleanup()
	t.Cleanup(cleanup)
	exec(t, admin, `insert into auth.users (id, email, raw_user_meta_data) values
		($1, 'ada.assistant@test.local', '{"display_name":"Ada"}'),
		($2, 'ben.assistant@test.local', '{"display_name":"Ben"}'),
		($3, 'cleo.assistant@test.local', '{"display_name":"Cléo"}')`, itAda, itBen, itCleo)
	exec(t, admin, `insert into public.groups (id, name) values ($1, 'Potes'), ($2, 'Autres')`, itGroup, itOthers)
	exec(t, admin, `insert into public.calendars (owner_id, group_id, name) values (null, $1, 'Potes'), (null, $2, 'Autres')`, itGroup, itOthers)
	exec(t, admin, `insert into public.group_members (group_id, user_id, role, share_level) values
		($1, $2, 'owner', 'details'), ($1, $3, 'member', 'busy'), ($4, $5, 'owner', 'details')`,
		itGroup, itAda, itBen, itOthers, itCleo)
	exec(t, admin, `insert into public.events (calendar_id, title, location, starts_at, ends_at)
		select id, 'Kiné', 'Cabinet', now() + interval '1 day', now() + interval '1 day 1 hour'
		from public.calendars where owner_id = $1 order by created_at limit 1`, itBen)
}

func TestPgStoreActsAsTheMember(t *testing.T) {
	worker, admin := openPools(t)
	installGroup(t, admin)
	store := NewPgStore(worker)
	ctx := context.Background()
	from, to := time.Now(), time.Now().Add(72*time.Hour)

	profile, err := store.Profile(ctx, itAda)
	if err != nil || profile.Timezone == "" {
		t.Fatalf("Profile = %+v, %v", profile, err)
	}

	groups, err := store.Groups(ctx, itAda)
	if err != nil || len(groups) != 1 || groups[0].Name != "Potes" || len(groups[0].Members) != 2 {
		t.Fatalf("Groups = %+v, %v : Ada ne voit que son groupe, avec ses deux membres", groups, err)
	}

	calendars, err := store.Calendars(ctx, itAda)
	if err != nil {
		t.Fatal(err)
	}
	var personal, group string
	for _, c := range calendars {
		switch {
		case c.Personal && c.Native:
			personal = c.ID
		case c.GroupID == itGroup:
			group = c.ID
		case c.GroupID == itOthers:
			t.Fatalf("Ada voit l'agenda d'un groupe dont elle n'est pas membre : %+v", c)
		}
	}
	if personal == "" || group == "" {
		t.Fatalf("Calendars = %+v", calendars)
	}

	agenda, err := store.GroupAgenda(ctx, itAda, itGroup, from, to)
	if err != nil || len(agenda) != 1 {
		t.Fatalf("GroupAgenda = %+v, %v", agenda, err)
	}
	if kine := agenda[0]; kine.Level != "busy" || kine.Title != "" || kine.Location != "" || kine.EventID != "" {
		t.Fatalf("le rdv de Ben, qui ne partage que « occupé », sort avec son détail : %+v", kine)
	}
	if _, err := store.GroupAgenda(ctx, itAda, itOthers, from, to); !errors.Is(err, ErrNotMember) {
		t.Fatalf("hors du groupe : err = %v", err)
	}

	start := time.Now().Add(48 * time.Hour).Truncate(time.Minute)
	mine, err := store.CreateEvent(ctx, itAda, Draft{CalendarID: personal, Title: "Dentiste",
		Start: start, End: start.Add(time.Hour), Timezone: "Europe/Paris"})
	if err != nil || mine == "" {
		t.Fatalf("CreateEvent (perso) = %q, %v", mine, err)
	}
	proposed, err := store.CreateEvent(ctx, itAda, Draft{CalendarID: group, Title: "Resto", Location: "Chez Max",
		Start: start, End: start.Add(2 * time.Hour), Timezone: "Europe/Paris"})
	if err != nil {
		t.Fatalf("CreateEvent (groupe) : %v", err)
	}
	var createdBy string
	if err := admin.QueryRow(ctx, `select created_by::text from public.events where id = $1`, proposed).Scan(&createdBy); err != nil || createdBy != itAda {
		t.Fatalf("créé par %q, %v : le rdv doit porter Ada comme créatrice (claims)", createdBy, err)
	}
	if _, err := store.CreateEvent(ctx, itCleo, Draft{CalendarID: group, Title: "Intrus",
		Start: start, End: start.Add(time.Hour), Timezone: "Europe/Paris"}); !errors.Is(err, ErrForbidden) {
		t.Fatalf("Cléo écrit dans l'agenda d'un groupe qui n'est pas le sien : err = %v", err)
	}

	entries, err := store.MyAgenda(ctx, itAda, from, to)
	if err != nil || len(entries) != 2 {
		t.Fatalf("MyAgenda = %+v, %v : le rdv perso et la proposition", entries, err)
	}
	if err := store.Respond(ctx, itBen, proposed, nil, "yes"); err != nil {
		t.Fatalf("Respond : %v", err)
	}
	if err := store.Respond(ctx, itCleo, proposed, nil, "yes"); !errors.Is(err, ErrEventNotFound) {
		t.Fatalf("Cléo répond à un rdv d'un autre groupe : err = %v", err)
	}

	var role string
	if err := worker.QueryRow(ctx, `select current_user`).Scan(&role); err != nil || role != "agora_worker" {
		t.Fatalf("après les transactions, la connexion est %q, %v : la bascule doit rester locale", role, err)
	}
	if _, err := store.Profile(ctx, ""); !errors.Is(err, errNoUser) {
		t.Fatalf("sans membre : err = %v", err)
	}
}
