package ics

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"testing"
	"time"
)

const secretURL = "https://calendar.example.com" + secretPath

// fakeStore rejoue des lots de flux et enregistre ce que le service écrit.
type fakeStore struct {
	batches   [][]Feed
	dueCalls  int
	applied   map[string][]Event
	etags     map[string]string
	unchanged []string
	failures  map[string]Failure
	applyErr  error
}

func newFakeStore(batches ...[]Feed) *fakeStore {
	return &fakeStore{batches: batches, applied: map[string][]Event{}, etags: map[string]string{},
		failures: map[string]Failure{}}
}

func (s *fakeStore) DueFeeds(context.Context, int) ([]Feed, error) {
	s.dueCalls++
	if len(s.batches) == 0 {
		return nil, nil
	}
	batch := s.batches[0]
	s.batches = s.batches[1:]
	return batch, nil
}

func (s *fakeStore) Apply(_ context.Context, id string, events []Event, etag, _ string) error {
	if s.applyErr != nil {
		return s.applyErr
	}
	s.applied[id] = events
	s.etags[id] = etag
	return nil
}

func (s *fakeStore) RecordUnchanged(_ context.Context, id string) error {
	s.unchanged = append(s.unchanged, id)
	return nil
}

func (s *fakeStore) RecordFailure(_ context.Context, id string, failure Failure) error {
	s.failures[id] = failure
	return nil
}

// fakeFetcher rend, par agenda, une réponse ou une erreur.
type fakeFetcher struct {
	results map[string]Result
	errs    map[string]error
}

func (f fakeFetcher) Fetch(_ context.Context, feed Feed) (Result, error) {
	if err, ok := f.errs[feed.CalendarID]; ok {
		return Result{}, err
	}
	return f.results[feed.CalendarID], nil
}

func newTestService(store Store, fetcher Fetcher) (*Service, *bytes.Buffer) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	return NewService(store, fetcher, func() time.Time { return testNow }, logger), &logs
}

func TestSyncAppliesAFeed(t *testing.T) {
	store := newFakeStore([]Feed{{CalendarID: "cal-1", URL: secretURL}})
	fetcher := fakeFetcher{results: map[string]Result{"cal-1": {
		Body: feed("", "UID:a@x\nDTSTART:20261006T090000Z\nSUMMARY:A"), ETag: `"v1"`,
	}}}
	service, logs := newTestService(store, fetcher)

	if err := service.SyncDue(context.Background()); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	if got := store.applied["cal-1"]; len(got) != 1 || got[0].UID != "a@x" || store.etags["cal-1"] != `"v1"` {
		t.Errorf("applied = %+v, etag %q", got, store.etags["cal-1"])
	}
	assertNoSecret(t, logs)
}

func TestSyncRecordsWhatHappened(t *testing.T) {
	store := newFakeStore([]Feed{
		{CalendarID: "same", URL: secretURL},
		{CalendarID: "gone", URL: secretURL},
		{CalendarID: "html", URL: secretURL},
		{CalendarID: "odd", URL: secretURL},
	})
	fetcher := fakeFetcher{
		results: map[string]Result{
			"same": {NotModified: true},
			"html": {Body: []byte("<html>")},
		},
		errs: map[string]error{
			"gone": FailureNotFound,
			"odd":  fmt.Errorf("dial %s: refused", secretURL),
		},
	}
	service, logs := newTestService(store, fetcher)

	if err := service.SyncDue(context.Background()); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	if fmt.Sprint(store.unchanged) != "[same]" {
		t.Errorf("unchanged = %v", store.unchanged)
	}
	want := map[string]Failure{"gone": FailureNotFound, "html": FailureNotCalendar, "odd": FailureUnreachable}
	if fmt.Sprint(store.failures) != fmt.Sprint(want) {
		t.Errorf("failures = %v, want %v", store.failures, want)
	}
	if len(store.applied) != 0 {
		t.Errorf("a failed feed was applied: %v", store.applied)
	}
	assertNoSecret(t, logs)
}

func TestSyncDueDrainsEveryBatch(t *testing.T) {
	full := make([]Feed, batchSize)
	for i := range full {
		full[i] = Feed{CalendarID: fmt.Sprintf("cal-%d", i)}
	}
	store := newFakeStore(full, []Feed{{CalendarID: "last"}})
	service, _ := newTestService(store, fakeFetcher{results: map[string]Result{}})

	if err := service.SyncDue(context.Background()); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	if store.dueCalls != 2 {
		t.Errorf("DueFeeds called %d times, want 2 (a full batch, then a partial one)", store.dueCalls)
	}
}

func TestSyncDueContinuesAfterAStoreError(t *testing.T) {
	store := newFakeStore([]Feed{{CalendarID: "a"}, {CalendarID: "b"}})
	store.applyErr = errors.New("connection reset")
	body := feed("", "UID:a@x\nDTSTART:20261006T090000Z")
	fetcher := fakeFetcher{results: map[string]Result{"a": {Body: body}, "b": {Body: body}}}
	service, logs := newTestService(store, fetcher)

	if err := service.SyncDue(context.Background()); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	if n := strings.Count(logs.String(), "feed sync failed"); n != 2 {
		t.Errorf("logged %d failures, want both feeds tried", n)
	}
	if len(store.failures) != 0 {
		t.Errorf("a database error was recorded as a feed failure: %v", store.failures)
	}
}

func TestSyncRecordsAFeedTheDatabaseRejects(t *testing.T) {
	store := newFakeStore([]Feed{{CalendarID: "odd", URL: secretURL}})
	store.applyErr = fmt.Errorf("apply events: %w", ErrRejectedFeed)
	body := feed("", "UID:a@x\nDTSTART:20261006T090000Z")
	service, _ := newTestService(store, fakeFetcher{results: map[string]Result{"odd": {Body: body}}})

	if err := service.SyncDue(context.Background()); err != nil {
		t.Fatalf("SyncDue() error = %v", err)
	}
	if store.failures["odd"] != FailureNotCalendar {
		t.Errorf("failures = %v, want the feed marked unreadable, not retried every 10 minutes", store.failures)
	}
}

func TestSyncRecordsNothingOnShutdown(t *testing.T) {
	store := newFakeStore()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	service, _ := newTestService(store, fakeFetcher{errs: map[string]error{"a": context.Canceled}})

	if err := service.Sync(ctx, Feed{CalendarID: "a"}); !errors.Is(err, context.Canceled) {
		t.Errorf("Sync() error = %v, want context.Canceled", err)
	}
	if len(store.failures) != 0 {
		t.Errorf("shutdown recorded as a feed failure: %v", store.failures)
	}
}

func TestFeedNeverPrintsItsURL(t *testing.T) {
	f := Feed{CalendarID: "cal-1", URL: secretURL, ETag: "x"}
	for _, verb := range []string{"%v", "%+v", "%#v", "%s", "%q"} {
		if out := fmt.Sprintf(verb, f); strings.Contains(out, secretPath) {
			t.Errorf("%s prints the URL: %s", verb, out)
		}
	}
}

func assertNoSecret(t *testing.T, logs *bytes.Buffer) {
	t.Helper()
	if strings.Contains(logs.String(), secretPath) {
		t.Errorf("the logs reveal a feed URL:\n%s", logs)
	}
}
