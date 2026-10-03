package slots

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

// Mêmes cas que free_slots_test.dart : les deux implémentations doivent
// rendre les mêmes créneaux.

var paris = mustLoad("Europe/Paris")

func mustLoad(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic(err)
	}
	return loc
}

// Lundi 5 octobre 2026, heure de Paris.
func day(d int, hm ...int) time.Time {
	h, m := 0, 0
	if len(hm) > 0 {
		h = hm[0]
	}
	if len(hm) > 1 {
		m = hm[1]
	}
	return time.Date(2026, 10, d, h, m, 0, 0, paris)
}

func busy(user string, start, end time.Time) Item {
	return Item{UserID: user, Start: start.UTC(), End: end.UTC()}
}

func allDay(user string, start, end time.Time) Item {
	return Item{
		UserID: user, AllDay: true,
		Start: time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, time.UTC),
		End:   time.Date(end.Year(), end.Month(), end.Day(), 0, 0, 0, 0, time.UTC),
	}
}

func everyDay() map[time.Weekday]bool {
	days := map[time.Weekday]bool{}
	for d := time.Sunday; d <= time.Saturday; d++ {
		days[d] = true
	}
	return days
}

// Lundi 5 → mercredi 7 octobre, de 18 h à 22 h, une heure au moins.
func evenings() Search {
	return Search{
		Location: paris,
		From:     day(5),
		To:       day(8),
		Duration: time.Hour,
		DayStart: 18 * time.Hour,
		DayEnd:   22 * time.Hour,
		Weekdays: everyDay(),
		Members:  map[string]bool{"a": true, "b": true},
	}
}

func show(slots []Slot) string {
	parts := make([]string, 0, len(slots))
	for _, s := range slots {
		parts = append(parts, fmt.Sprintf("%d %s-%s", s.Start.Day(), s.Start.Format("15:04"), s.End.Format("15:04")))
	}
	return strings.Join(parts, ", ")
}

func TestFind(t *testing.T) {
	tests := []struct {
		name   string
		search func() Search
		agenda []Item
		want   string
	}{
		{
			name:   "an empty agenda leaves every evening free",
			search: evenings,
			want:   "5 18:00-22:00, 6 18:00-22:00, 7 18:00-22:00",
		},
		{
			name:   "anyone busy takes the slot away, overlaps merged",
			search: evenings,
			agenda: []Item{
				busy("a", day(5, 18), day(5, 19)),
				busy("b", day(5, 18, 30), day(5, 20)),
				busy("a", day(6, 20), day(6, 23)),
			},
			want: "5 20:00-22:00, 6 18:00-20:00, 7 18:00-22:00",
		},
		{
			name: "a gap shorter than the duration is not a slot",
			search: func() Search {
				s := evenings()
				s.Duration = 2 * time.Hour
				return s
			},
			agenda: []Item{busy("a", day(5, 19), day(5, 20, 30))},
			want:   "6 18:00-22:00, 7 18:00-22:00",
		},
		{
			name: "only the chosen members count",
			search: func() Search {
				s := evenings()
				s.Members = map[string]bool{"a": true}
				return s
			},
			agenda: []Item{busy("b", day(5, 18), day(5, 22))},
			want:   "5 18:00-22:00, 6 18:00-22:00, 7 18:00-22:00",
		},
		{
			name:   "an event of the group takes the slot for everyone",
			search: evenings,
			agenda: []Item{{IsGroupEvent: true,
				Start: day(7, 18).UTC(), End: day(7, 21).UTC()}},
			want: "5 18:00-22:00, 6 18:00-22:00, 7 21:00-22:00",
		},
		{
			name:   "all-day events leave the day free by default",
			search: evenings,
			agenda: []Item{allDay("a", day(6), day(7))},
			want:   "5 18:00-22:00, 6 18:00-22:00, 7 18:00-22:00",
		},
		{
			name: "all-day events take the day when asked",
			search: func() Search {
				s := evenings()
				s.AllDayBlocks = true
				return s
			},
			agenda: []Item{allDay("a", day(6), day(7))},
			want:   "5 18:00-22:00, 7 18:00-22:00",
		},
		{
			name: "days outside the chosen weekdays are skipped",
			search: func() Search {
				s := evenings()
				s.Weekdays = map[time.Weekday]bool{time.Monday: true, time.Wednesday: true}
				return s
			},
			want: "5 18:00-22:00, 7 18:00-22:00",
		},
		{
			name: "a window crossing midnight is not supported: it is empty",
			search: func() Search {
				s := evenings()
				s.DayStart, s.DayEnd = 22*time.Hour, 2*time.Hour
				return s
			},
			want: "",
		},
		{
			name: "the past is never offered",
			search: func() Search {
				s := evenings()
				s.From, s.To = day(5, 19, 10), day(6)
				s.Duration = 30 * time.Minute
				return s
			},
			want: "5 19:15-22:00",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := show(Find(tt.search(), tt.agenda)); got != tt.want {
				t.Fatalf("créneaux = %q, attendu %q", got, tt.want)
			}
		})
	}
}

func TestFindIsCapped(t *testing.T) {
	s := evenings()
	s.From, s.To = day(1), time.Date(2027, 3, 1, 0, 0, 0, 0, paris)
	if got := len(Find(s, nil)); got != Max {
		t.Fatalf("%d créneaux, attendu le plafond %d", got, Max)
	}
}

func TestFindKeepsWallClockAcrossDST(t *testing.T) {
	// Passage à l'heure d'hiver le dimanche 25 octobre 2026 : 18 h reste 18 h.
	s := evenings()
	s.From, s.To = day(25), day(26)
	if got := show(Find(s, nil)); got != "25 18:00-22:00" {
		t.Fatalf("créneaux = %q", got)
	}
}
