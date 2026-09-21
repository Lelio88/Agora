package recurrence

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sync"
	"testing"
	"time"
)

const seriesA = "aaaaaaaa-0000-0000-0000-000000000001"
const seriesB = "bbbbbbbb-0000-0000-0000-000000000002"

// fakeStore garde séries et occurrences en mémoire ; loadErr fait échouer
// la lecture d'une série donnée.
type fakeStore struct {
	mu          sync.Mutex
	series      map[string]Series
	occurrences map[string][]Occurrence
	loadErr     map[string]error
	replaced    []string
}

func newFakeStore(series ...Series) *fakeStore {
	store := &fakeStore{
		series:      map[string]Series{},
		occurrences: map[string][]Occurrence{},
		loadErr:     map[string]error{},
	}
	for _, s := range series {
		store.series[s.ID] = s
	}
	return store
}

func (f *fakeStore) ListSeriesIDs(_ context.Context) ([]string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	ids := make([]string, 0, len(f.series)+len(f.loadErr))
	for id := range f.loadErr {
		ids = append(ids, id)
	}
	for id := range f.series {
		ids = append(ids, id)
	}
	return ids, nil
}

// UpdateOccurrences imite PgStore : lecture, calcul et écriture d'un seul
// tenant (sous le mutex), rien d'écrit si la lecture ou le calcul échoue.
func (f *fakeStore) UpdateOccurrences(_ context.Context, id string, compute Compute) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := f.loadErr[id]; err != nil {
		return err
	}
	series, found := f.series[id]
	occurrences, err := compute(series, found)
	if err != nil {
		return err
	}
	f.occurrences[id] = occurrences
	f.replaced = append(f.replaced, id)
	return nil
}

func (f *fakeStore) occurrencesOf(id string) []Occurrence {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.occurrences[id]
}

func weekly(id string) Series {
	return Series{
		ID:       id,
		Start:    utc("2026-10-13T16:00:00Z"),
		End:      utc("2026-10-13T17:00:00Z"),
		Timezone: "Europe/Paris",
		RRule:    "FREQ=WEEKLY",
	}
}

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func newTestService(store Store) *Service {
	now := func() time.Time { return utc("2026-10-12T00:00:00Z") }
	return NewService(store, now, discardLogger())
}

func TestRefreshWritesTheExpandedOccurrences(t *testing.T) {
	store := newFakeStore(weekly(seriesA))

	if err := newTestService(store).Refresh(context.Background(), seriesA); err != nil {
		t.Fatalf("Refresh() error = %v", err)
	}

	got := store.occurrencesOf(seriesA)
	if len(got) == 0 || !got[0].Start.Equal(utc("2026-10-13T16:00:00Z")) {
		t.Errorf("occurrences = %v, want the series expanded from 13 October", got)
	}
}

func TestRefreshClearsASeriesThatNoLongerExists(t *testing.T) {
	store := newFakeStore()
	store.occurrences[seriesA] = []Occurrence{{Start: utc("2026-10-13T16:00:00Z")}}

	if err := newTestService(store).Refresh(context.Background(), seriesA); err != nil {
		t.Fatalf("Refresh() error = %v", err)
	}

	if got := store.occurrencesOf(seriesA); len(got) != 0 {
		t.Errorf("occurrences = %v, want none", got)
	}
}

func TestRefreshKeepsOccurrencesWhenTheRuleIsInvalid(t *testing.T) {
	broken := weekly(seriesA)
	broken.RRule = "FREQ=NEVER"
	store := newFakeStore(broken)
	previous := []Occurrence{{Start: utc("2026-10-13T16:00:00Z")}}
	store.occurrences[seriesA] = previous

	err := newTestService(store).Refresh(context.Background(), seriesA)

	if err == nil {
		t.Fatal("Refresh() error = nil, want an error")
	}
	if got := store.occurrencesOf(seriesA); len(got) != len(previous) {
		t.Errorf("occurrences = %v, want the previous ones untouched", got)
	}
}

func TestRefreshWritesTheFirstOccurrencesOfAnEndlessSeries(t *testing.T) {
	daily := weekly(seriesA)
	daily.Start = utc("2026-01-01T00:00:00Z")
	daily.End = utc("2026-01-01T00:30:00Z")
	daily.Timezone = "UTC"
	daily.RRule = "FREQ=DAILY;INTERVAL=1"
	store := newFakeStore(daily)
	service := NewService(store, func() time.Time { return utc("2026-01-01T00:00:00Z") },
		discardLogger())
	service.window = func(time.Time) Window {
		return Window{From: utc("2026-01-01T00:00:00Z"), To: utc("2100-01-01T00:00:00Z")}
	}

	if err := service.Refresh(context.Background(), seriesA); err != nil {
		t.Fatalf("Refresh() error = %v, a capped series is not a failure", err)
	}

	if got := store.occurrencesOf(seriesA); len(got) != MaxOccurrences {
		t.Errorf("len = %d, want %d", len(got), MaxOccurrences)
	}
}

func TestRefreshAllContinuesAfterAFailingSeries(t *testing.T) {
	store := newFakeStore(weekly(seriesA))
	store.loadErr[seriesB] = errors.New("boom")

	err := newTestService(store).RefreshAll(context.Background())

	if err == nil {
		t.Error("RefreshAll() error = nil, want the failure of series B reported")
	}
	if len(store.occurrencesOf(seriesA)) == 0 {
		t.Error("series A was not refreshed after series B failed")
	}
}

func TestRunRefreshesNotifiedSeriesAndIgnoresGarbage(t *testing.T) {
	store := newFakeStore(weekly(seriesA))
	service := newTestService(store)
	ctx, cancel := context.WithCancel(context.Background())
	notifications := make(chan string)
	done := make(chan struct{})
	go func() {
		service.Run(ctx, notifications, make(chan struct{}), time.Hour)
		close(done)
	}()

	notifications <- "not-a-uuid'; drop table events; --"
	notifications <- seriesA
	notifications <- seriesA // synchronise : la précédente est traitée
	cancel()
	<-done

	store.mu.Lock()
	defer store.mu.Unlock()
	for _, id := range store.replaced {
		if id != seriesA {
			t.Errorf("replaced occurrences of %q, want only valid series ids", id)
		}
	}
	if len(store.replaced) == 0 {
		t.Error("the notified series was never refreshed")
	}
}
