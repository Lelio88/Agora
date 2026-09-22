//go:build integration

package ics

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Exige la pile Supabase locale (supabase start) : AGORA_TEST_DATABASE_URL
// pour le rôle du worker, AGORA_TEST_ADMIN_URL (postgres) pour les
// fixtures.
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

const (
	testUserID     = "1c5e0000-0000-0000-0000-00000000e001"
	testCalendarID = "1c5e0000-0000-0000-0000-00000000e002"
)

// installFeed crée un compte et un agenda iCal pointant vers url.
func installFeed(t *testing.T, admin *pgxpool.Pool, url string) {
	t.Helper()
	ctx := context.Background()
	_, _ = admin.Exec(ctx, `delete from auth.users where id = $1`, testUserID)
	_, err := admin.Exec(ctx, `insert into auth.users (id, email, raw_user_meta_data)
		values ($1, 'ics.worker@test.local', '{"display_name":"Iris"}')`, testUserID)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}
	t.Cleanup(func() { _, _ = admin.Exec(ctx, `delete from auth.users where id = $1`, testUserID) })
	_, err = admin.Exec(ctx, `insert into public.calendars (id, owner_id, kind, name)
		values ($1, $2, 'ics', 'Boulot')`, testCalendarID, testUserID)
	if err != nil {
		t.Fatalf("insert calendar: %v", err)
	}
	if _, err := admin.Exec(ctx, `insert into private.calendar_feeds (calendar_id, url) values ($1, $2)`,
		testCalendarID, url); err != nil {
		t.Fatalf("insert feed: %v", err)
	}
}

const integrationFeed = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:yoga@x
DTSTART;TZID=Europe/Paris:20261006T180000
DTEND;TZID=Europe/Paris:20261006T190000
RRULE:FREQ=WEEKLY
EXDATE;TZID=Europe/Paris:20261013T180000
SUMMARY:Yoga
END:VEVENT
BEGIN:VEVENT
UID:yoga@x
RECURRENCE-ID;TZID=Europe/Paris:20261020T180000
DTSTART;TZID=Europe/Paris:20261020T200000
DTEND;TZID=Europe/Paris:20261020T210000
SUMMARY:Yoga (décalé)
END:VEVENT
BEGIN:VEVENT
UID:kine@x
DTSTART:20261007T080000Z
DTEND:20261007T090000Z
SUMMARY:Kiné
END:VEVENT
END:VCALENDAR
`

// Chaîne complète : un serveur TLS sert le flux, le service le relit et la
// base l'applique ; la relecture suivante reçoit un 304.
func TestSyncEndToEnd(t *testing.T) {
	worker, admin := openPools(t)
	ctx := context.Background()
	requests := 0
	server, fetcher := newTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		requests++
		if r.Header.Get("If-None-Match") == `"v1"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"v1"`)
		_, _ = io.WriteString(w, integrationFeed)
	})
	installFeed(t, admin, server.URL+secretPath)
	store := NewPgStore(worker)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	service := NewService(store, fetcher, func() time.Time { return testNow }, logger)

	if err := service.SyncDue(ctx); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	var rows, moved int
	var exdates []time.Time
	err := admin.QueryRow(ctx, `
		select count(*),
		       count(*) filter (where series_id is not null),
		       (select exdates from public.events where calendar_id = $1 and source_uid = 'yoga@x'
		        and recurrence_id is null)
		from public.events where calendar_id = $1`, testCalendarID).Scan(&rows, &moved, &exdates)
	if err != nil {
		t.Fatal(err)
	}
	if rows != 3 || moved != 1 || len(exdates) != 1 || !exdates[0].Equal(utc("2026-10-13T16:00:00Z")) {
		t.Errorf("rows = %d, moved = %d, exdates = %v; want 3, 1, [13/10 16:00 UTC]", rows, moved, exdates)
	}

	// Rendre le flux dû de nouveau : la relecture est conditionnelle.
	if _, err := admin.Exec(ctx, `update private.calendar_feeds set next_sync_at = now()
		where calendar_id = $1`, testCalendarID); err != nil {
		t.Fatal(err)
	}
	if err := service.SyncDue(ctx); err != nil {
		t.Fatalf("second SyncDue() error = %v", err)
	}
	var syncedAt *time.Time
	var syncError *string
	if err := admin.QueryRow(ctx, `select last_synced_at, sync_error from public.calendars where id = $1`,
		testCalendarID).Scan(&syncedAt, &syncError); err != nil {
		t.Fatal(err)
	}
	if requests != 2 || syncedAt == nil || syncError != nil {
		t.Errorf("requests = %d, synced at %v, error %v; want a second, conditional read", requests, syncedAt, syncError)
	}
}

func TestPgStoreRecordsAFailure(t *testing.T) {
	worker, admin := openPools(t)
	ctx := context.Background()
	installFeed(t, admin, "https://calendar.example.com"+secretPath)
	store := NewPgStore(worker)

	if err := store.RecordFailure(ctx, testCalendarID, FailureNotFound); err != nil {
		t.Fatalf("RecordFailure() error = %v", err)
	}
	var syncError string
	var failures int
	err := admin.QueryRow(ctx, `select c.sync_error, f.failure_count from public.calendars c
		join private.calendar_feeds f on f.calendar_id = c.id where c.id = $1`, testCalendarID).
		Scan(&syncError, &failures)
	if err != nil {
		t.Fatal(err)
	}
	if syncError != string(FailureNotFound) || failures != 1 {
		t.Errorf("sync_error = %q, failures = %d", syncError, failures)
	}
}

// Une ligne que la base refuse (ici un titre trop long, que la lecture
// aurait dû tronquer) est un contenu rejeté, pas une panne de la base.
func TestPgStoreReportsARejectedFeed(t *testing.T) {
	worker, admin := openPools(t)
	installFeed(t, admin, "https://calendar.example.com"+secretPath)
	start := utc("2026-10-06T09:00:00Z")
	events := []Event{{
		UID: "long@x", Title: strings.Repeat("x", 300), StartsAt: start, EndsAt: start,
		Timezone: "UTC", Exdates: []time.Time{},
	}}

	err := NewPgStore(worker).Apply(context.Background(), testCalendarID, events, "", "")
	if !errors.Is(err, ErrRejectedFeed) {
		t.Errorf("Apply() error = %v, want ErrRejectedFeed", err)
	}
}
