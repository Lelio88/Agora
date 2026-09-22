//go:build integration

package recurrence

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Exige la pile Supabase locale (supabase start) et AGORA_TEST_DATABASE_URL
// pour le rôle du worker, par exemple :
// postgresql://agora_worker:agora-worker-local@127.0.0.1:55322/postgres
// Les fixtures s'écrivent en postgres via AGORA_TEST_ADMIN_URL.
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

func TestPgStoreRoundTrip(t *testing.T) {
	worker, admin := openPools(t)
	ctx := context.Background()
	installFixtures(t, admin)
	const userID = "f0000000-0000-0000-0000-00000000f001"
	const seriesID = "f0000000-0000-0000-0000-00000000f002"

	// Un bloc DO : plusieurs commandes, deux paramètres typés une seule fois.
	_, err := admin.Exec(ctx, `
		select private_test_fixtures($1::uuid, $2::uuid)`, userID, seriesID)
	if err != nil {
		t.Fatalf("fixtures: %v", err)
	}
	t.Cleanup(func() { _, _ = admin.Exec(ctx, `delete from auth.users where id = $1`, userID) })

	store := NewPgStore(worker)
	window := Window{From: utc("2026-10-12T00:00:00Z"), To: utc("2026-11-10T00:00:00Z")}
	var occurrences []Occurrence
	err = store.UpdateOccurrences(ctx, seriesID, func(series Series, found bool) ([]Occurrence, error) {
		if !found {
			t.Fatal("the series was not found")
		}
		if series.RRule != "FREQ=WEEKLY" || series.Timezone != "Europe/Paris" {
			t.Errorf("series = %+v", series)
		}
		if len(series.Exdates) != 1 || len(series.ReplacedSlots) != 1 {
			t.Errorf("exdates = %v, replaced = %v, want one each", series.Exdates, series.ReplacedSlots)
		}
		occurrences, err = Expand(series, window)
		return occurrences, err
	})
	if err != nil {
		t.Fatalf("UpdateOccurrences() error = %v", err)
	}

	var count int
	if err := admin.QueryRow(ctx, `select count(*) from public.event_occurrences where event_id = $1`, seriesID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	// 13/10, 3/11 : le 20/10 est supprimé, le 27/10 remplacé.
	if count != 2 {
		t.Errorf("stored occurrences = %d, want 2", count)
	}

	signaled := expandedAt(t, admin, seriesID)
	if signaled.IsZero() {
		t.Fatal("series_expansions has no signal after a change")
	}
	if err := store.UpdateOccurrences(ctx, seriesID, fixed(occurrences)); err != nil {
		t.Fatalf("UpdateOccurrences(same) error = %v", err)
	}
	if again := expandedAt(t, admin, seriesID); !again.Equal(signaled) {
		t.Errorf("unchanged occurrences re-signaled the series: %v then %v", signaled, again)
	}

	ids, err := store.ListSeriesIDs(ctx)
	if err != nil {
		t.Fatalf("ListSeriesIDs() error = %v", err)
	}
	if !contains(ids, seriesID) {
		t.Errorf("ListSeriesIDs() = %v, want it to contain the series", ids)
	}

	if err := store.UpdateOccurrences(ctx, seriesID, fixed(nil)); err != nil {
		t.Fatalf("UpdateOccurrences(nil) error = %v", err)
	}
	if err := admin.QueryRow(ctx, `select count(*) from public.event_occurrences where event_id = $1`, seriesID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Errorf("occurrences after clearing = %d, want 0", count)
	}
	if cleared := expandedAt(t, admin, seriesID); !cleared.After(signaled) {
		t.Errorf("clearing the occurrences did not re-signal the series: %v then %v", signaled, cleared)
	}

	// Une série disparue : rien à signaler, et surtout pas d'erreur de clé
	// étrangère sur series_expansions.
	const ghostID = "f0000000-0000-0000-0000-00000000f0ff"
	if err := store.UpdateOccurrences(ctx, ghostID, func(_ Series, found bool) ([]Occurrence, error) {
		if found {
			t.Error("a missing series was found")
		}
		return nil, nil
	}); err != nil {
		t.Errorf("UpdateOccurrences(ghost) error = %v", err)
	}
}

// expandedAt lit le signal de dépliage d'une série ; zéro s'il n'y en a pas.
func expandedAt(t *testing.T, admin *pgxpool.Pool, seriesID string) time.Time {
	t.Helper()
	var at time.Time
	err := admin.QueryRow(context.Background(),
		`select coalesce(max(expanded_at), 'epoch') from public.series_expansions where series_id = $1`,
		seriesID).Scan(&at)
	if err != nil {
		t.Fatal(err)
	}
	if at.Equal(time.Unix(0, 0)) {
		return time.Time{}
	}
	return at
}

// replace_occurrence prend le verrou de la série : le worker, qui le prend
// avant de relire la série, attend la validation et relit l'exception.
// Sans ce verrou, il réécrirait l'occurrence que le remplacement vient
// d'effacer (doublon dans l'agenda).
func TestPgStoreWaitsForAPendingReplacement(t *testing.T) {
	worker, admin := openPools(t)
	ctx := context.Background()
	installFixtures(t, admin)
	const userID = "f0000000-0000-0000-0000-00000000f011"
	const seriesID = "f0000000-0000-0000-0000-00000000f012"
	if _, err := admin.Exec(ctx, `select private_test_fixtures($1::uuid, $2::uuid)`, userID, seriesID); err != nil {
		t.Fatalf("fixtures: %v", err)
	}
	t.Cleanup(func() { _, _ = admin.Exec(ctx, `delete from auth.users where id = $1`, userID) })

	store := NewPgStore(worker)
	window := Window{From: utc("2026-10-12T00:00:00Z"), To: utc("2026-11-10T00:00:00Z")}
	expand := func(series Series, found bool) ([]Occurrence, error) {
		if !found {
			return nil, nil
		}
		return Expand(series, window)
	}
	if err := store.UpdateOccurrences(ctx, seriesID, expand); err != nil {
		t.Fatalf("first expansion: %v", err)
	}

	// La propriétaire remplace l'occurrence du 3 novembre (18 h à Paris),
	// transaction encore ouverte.
	tx, err := admin.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	claims := `{"sub":"` + userID + `","role":"authenticated"}`
	if _, err := tx.Exec(ctx, `select set_config('request.jwt.claims', $1, true)`, claims); err != nil {
		t.Fatal(err)
	}
	if _, err := tx.Exec(ctx, `
		select public.replace_occurrence($1, '2026-11-03 17:00+00', 'Déplacée', null, null,
		  '2026-11-03 19:00+00', '2026-11-03 20:00+00', false, null)`, seriesID); err != nil {
		t.Fatalf("replace_occurrence: %v", err)
	}

	done := make(chan error, 1)
	go func() { done <- store.UpdateOccurrences(ctx, seriesID, expand) }()
	select {
	case err := <-done:
		t.Fatalf("the worker did not wait for the pending replacement (err = %v)", err)
	case <-time.After(500 * time.Millisecond):
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatalf("UpdateOccurrences() error = %v", err)
	}

	var ghosts int
	err = admin.QueryRow(ctx, `select count(*) from public.event_occurrences
		where event_id = $1 and starts_at = '2026-11-03 17:00+00'`, seriesID).Scan(&ghosts)
	if err != nil {
		t.Fatal(err)
	}
	if ghosts != 0 {
		t.Error("the replaced occurrence came back after the worker's expansion")
	}
}

// fixed renvoie un calcul qui ignore la série et rend occurrences.
func fixed(occurrences []Occurrence) Compute {
	return func(Series, bool) ([]Occurrence, error) { return occurrences, nil }
}

func contains(list []string, want string) bool {
	for _, item := range list {
		if item == want {
			return true
		}
	}
	return false
}

// installFixtures crée (le temps du test) une fonction qui pose un compte,
// une série hebdomadaire avec une occurrence supprimée et une déplacée.
func installFixtures(t *testing.T, admin *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	_, err := admin.Exec(ctx, `
		create or replace function private_test_fixtures(p_user uuid, p_series uuid)
		returns void language plpgsql as $$
		begin
			delete from auth.users where id = p_user;
			insert into auth.users (id, email, raw_user_meta_data)
			values (p_user, 'pgstore@test.local', '{"display_name":"PgStore"}');
			insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, exdates)
			select p_series, c.id, 'Série', '2026-10-13 16:00+00', '2026-10-13 17:00+00', 'Europe/Paris',
			       'FREQ=WEEKLY', array['2026-10-20 16:00+00'::timestamptz]
			from public.calendars c where c.owner_id = p_user;
			insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
			select p_series, '2026-10-27 17:00+00', calendar_id, 'Déplacée',
			       '2026-10-27 19:00+00', '2026-10-27 20:00+00'
			from public.events where id = p_series;
		end $$`)
	if err != nil {
		t.Fatalf("install fixtures: %v", err)
	}
	t.Cleanup(func() { _, _ = admin.Exec(ctx, `drop function if exists private_test_fixtures(uuid, uuid)`) })
}
