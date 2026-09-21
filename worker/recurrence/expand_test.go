package recurrence

import (
	"errors"
	"testing"
	"time"
)

func utc(value string) time.Time {
	t, err := time.Parse(time.RFC3339, value)
	if err != nil {
		panic(err)
	}
	return t
}

func starts(occurrences []Occurrence) []time.Time {
	out := make([]time.Time, len(occurrences))
	for i, o := range occurrences {
		out[i] = o.Start.UTC()
	}
	return out
}

func TestExpand(t *testing.T) {
	// Mardi 18 h à Paris : 16 h UTC en heure d'été, 17 h UTC après le
	// passage à l'heure d'hiver du 25 octobre 2026.
	weeklyParis := Series{
		Start:    utc("2026-10-13T16:00:00Z"),
		End:      utc("2026-10-13T17:00:00Z"),
		Timezone: "Europe/Paris",
		RRule:    "FREQ=WEEKLY",
	}
	threeWeeks := Window{From: utc("2026-10-12T00:00:00Z"), To: utc("2026-11-02T00:00:00Z")}

	tests := []struct {
		name   string
		series Series
		window Window
		want   []time.Time
	}{
		{
			name:   "keeps the local hour across a DST change",
			series: weeklyParis,
			window: threeWeeks,
			want: []time.Time{
				utc("2026-10-13T16:00:00Z"), utc("2026-10-20T16:00:00Z"), utc("2026-10-27T17:00:00Z"),
			},
		},
		{
			name: "skips deleted occurrences",
			series: func() Series {
				s := weeklyParis
				s.Exdates = []time.Time{utc("2026-10-20T16:00:00Z")}
				return s
			}(),
			window: threeWeeks,
			want:   []time.Time{utc("2026-10-13T16:00:00Z"), utc("2026-10-27T17:00:00Z")},
		},
		{
			name: "skips slots replaced by a modified occurrence",
			series: func() Series {
				s := weeklyParis
				s.ReplacedSlots = []time.Time{utc("2026-10-13T16:00:00Z")}
				return s
			}(),
			window: threeWeeks,
			want:   []time.Time{utc("2026-10-20T16:00:00Z"), utc("2026-10-27T17:00:00Z")},
		},
		{
			name: "stops after COUNT occurrences",
			series: func() Series {
				s := weeklyParis
				s.RRule = "FREQ=DAILY;COUNT=2"
				return s
			}(),
			window: threeWeeks,
			want:   []time.Time{utc("2026-10-13T16:00:00Z"), utc("2026-10-14T16:00:00Z")},
		},
		{
			name: "stops at UNTIL",
			series: func() Series {
				s := weeklyParis
				s.RRule = "FREQ=WEEKLY;UNTIL=20261021T000000Z"
				return s
			}(),
			window: threeWeeks,
			want:   []time.Time{utc("2026-10-13T16:00:00Z"), utc("2026-10-20T16:00:00Z")},
		},
		{
			name: "only keeps occurrences inside the window",
			series: Series{
				Start:    utc("2020-01-07T09:00:00Z"),
				End:      utc("2020-01-07T10:00:00Z"),
				Timezone: "UTC",
				RRule:    "FREQ=WEEKLY",
			},
			window: Window{From: utc("2026-10-12T00:00:00Z"), To: utc("2026-10-20T00:00:00Z")},
			want:   []time.Time{utc("2026-10-13T09:00:00Z")},
		},
		{
			name: "expands all-day events in UTC, whatever the time zone",
			series: Series{
				Start:    utc("2026-03-15T00:00:00Z"),
				End:      utc("2026-03-16T00:00:00Z"),
				AllDay:   true,
				Timezone: "America/Montreal",
				RRule:    "FREQ=YEARLY",
			},
			window: Window{From: utc("2027-01-01T00:00:00Z"), To: utc("2027-12-31T00:00:00Z")},
			want:   []time.Time{utc("2027-03-15T00:00:00Z")},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := Expand(tt.series, tt.window)
			if err != nil {
				t.Fatalf("Expand() error = %v", err)
			}
			gotStarts := starts(got)
			if len(gotStarts) != len(tt.want) {
				t.Fatalf("Expand() = %v, want %v", gotStarts, tt.want)
			}
			for i := range tt.want {
				if !gotStarts[i].Equal(tt.want[i]) {
					t.Errorf("occurrence %d starts at %v, want %v", i, gotStarts[i], tt.want[i])
				}
			}
		})
	}
}

func TestExpandKeepsTheSeriesDuration(t *testing.T) {
	series := Series{
		Start:    utc("2026-10-13T16:00:00Z"),
		End:      utc("2026-10-13T17:30:00Z"),
		Timezone: "UTC",
		RRule:    "FREQ=DAILY;COUNT=1",
	}

	got, err := Expand(series, Window{From: utc("2026-10-01T00:00:00Z"), To: utc("2026-11-01T00:00:00Z")})

	if err != nil || len(got) != 1 {
		t.Fatalf("Expand() = %v, %v", got, err)
	}
	if d := got[0].End.Sub(got[0].Start); d != 90*time.Minute {
		t.Errorf("duration = %v, want 1h30", d)
	}
}

func TestExpandCapsEndlessSeries(t *testing.T) {
	series := Series{
		Start:    utc("2026-01-01T00:00:00Z"),
		End:      utc("2026-01-01T00:30:00Z"),
		Timezone: "UTC",
		RRule:    "FREQ=DAILY",
	}

	got, err := Expand(series, Window{From: utc("2026-01-01T00:00:00Z"), To: utc("2100-01-01T00:00:00Z")})

	if !errors.Is(err, ErrTooManyOccurrences) {
		t.Fatalf("error = %v, want ErrTooManyOccurrences", err)
	}
	if len(got) != MaxOccurrences {
		t.Errorf("len = %d, want the %d first occurrences", len(got), MaxOccurrences)
	}
}

func TestExpandRejectsInvalidInput(t *testing.T) {
	window := Window{From: utc("2026-01-01T00:00:00Z"), To: utc("2027-01-01T00:00:00Z")}
	tests := []struct {
		name   string
		series Series
	}{
		{name: "malformed rule", series: Series{Start: window.From, End: window.From, Timezone: "UTC", RRule: "FREQ=NEVER"}},
		{name: "unknown time zone", series: Series{Start: window.From, End: window.From, Timezone: "Mars/Olympus", RRule: "FREQ=DAILY"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := Expand(tt.series, window); err == nil {
				t.Error("Expand() error = nil, want an error")
			}
		})
	}
}
