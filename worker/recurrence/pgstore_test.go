package recurrence

import (
	"testing"
	"time"
)

func TestSameOccurrences(t *testing.T) {
	paris, err := time.LoadLocation("Europe/Paris")
	if err != nil {
		t.Fatal(err)
	}
	a := Occurrence{Start: utc("2026-10-13T16:00:00Z"), End: utc("2026-10-13T17:00:00Z")}
	b := Occurrence{Start: utc("2026-10-20T16:00:00Z"), End: utc("2026-10-20T17:00:00Z")}
	aInParis := Occurrence{Start: a.Start.In(paris), End: a.End.In(paris)}
	aLonger := Occurrence{Start: a.Start, End: a.End.Add(time.Hour)}

	tests := []struct {
		name string
		x, y []Occurrence
		want bool
	}{
		{name: "both_empty", want: true},
		{name: "same_order", x: []Occurrence{a, b}, y: []Occurrence{a, b}, want: true},
		{name: "other_order", x: []Occurrence{a, b}, y: []Occurrence{b, a}, want: true},
		{name: "other_time_zone", x: []Occurrence{a}, y: []Occurrence{aInParis}, want: true},
		{name: "one_missing", x: []Occurrence{a, b}, y: []Occurrence{a}, want: false},
		{name: "other_start", x: []Occurrence{a}, y: []Occurrence{b}, want: false},
		{name: "other_end", x: []Occurrence{a}, y: []Occurrence{aLonger}, want: false},
		{name: "cleared", x: []Occurrence{a}, y: nil, want: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := sameOccurrences(tt.x, tt.y); got != tt.want {
				t.Errorf("sameOccurrences() = %v, want %v", got, tt.want)
			}
		})
	}
}
