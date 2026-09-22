package ics

import (
	"errors"
	"strings"
	"testing"
	"time"
)

// Lignes que le décodeur de go-ical ne sait pas lire sans paniquer : un
// flux hostile ne doit jamais arrêter le worker.
func TestParseSurvivesLinesThatCrashTheDecoder(t *testing.T) {
	tests := []struct {
		name string
		line string
	}{
		{name: "parameter without colon", line: "SUMMARY;LANGUAGE=fr"},
		{name: "garbage after a quoted parameter", line: `DTSTART;TZID="Europe/Paris"x:20261006T100000`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body := feed("", "UID:a@x\nDTSTART:20261006T090000Z\n"+tt.line)
			_, err := Parse(body, testNow)
			if !errors.Is(err, FailureNotCalendar) {
				t.Errorf("Parse() error = %v, want %v", err, FailureNotCalendar)
			}
		})
	}
}

// Le décodeur construit une valeur de paramètre octet par octet : un
// paramètre de quelques Mio prendrait des heures. Il est refusé avant.
func TestParseRefusesAnOverlongParameterQuickly(t *testing.T) {
	tests := []struct {
		name  string
		param string
	}{
		{name: "plain", param: "X-P=" + strings.Repeat("a", maxBodyBytes/2)},
		{name: "quoted, with colons inside", param: `X-P="http:` + strings.Repeat("a:", maxBodyBytes/4) + `"`},
		{name: "folded over many lines", param: "X-P=" + strings.Repeat("a\r\n ", 200_000)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body := feed("", "UID:a@x\nDTSTART:20261006T090000Z\nSUMMARY;"+tt.param+":Titre")
			started := time.Now()
			_, err := Parse(body, testNow)
			if !errors.Is(err, FailureNotCalendar) {
				t.Errorf("Parse() error = %v, want %v", err, FailureNotCalendar)
			}
			if took := time.Since(started); took > 2*time.Second {
				t.Errorf("Parse() took %v", took)
			}
		})
	}
}

func TestParseAcceptsUsualParameters(t *testing.T) {
	events := mustParse(t, feed("", `
UID:a@x
DTSTART;TZID="Europe/Paris";VALUE=DATE-TIME:20261006T100000
SUMMARY;LANGUAGE=fr;ALTREP="https://example.com/a:b":Réunion`))

	if len(events) != 1 || events[0].Title != "Réunion" {
		t.Errorf("events = %+v", events)
	}
}

func TestWithinDecoderLimitsFollowsFoldedLines(t *testing.T) {
	// BEGIN plié sur deux lignes : le décodeur le lit comme un BEGIN.
	folded := strings.Repeat("BEG\r\n IN:X\r\n", maxNesting+1)
	if withinDecoderLimits([]byte(folded)) {
		t.Error("a folded BEGIN escaped the nesting limit")
	}
	balanced := strings.Repeat("BEGIN:X\r\nEND:X\r\n", 100)
	if !withinDecoderLimits([]byte(balanced)) {
		t.Error("siblings are not nesting")
	}
}

func TestParseIgnoresDatesOutOfRange(t *testing.T) {
	events := mustParse(t, feed("", `
UID:s@x
DTSTART:20261006T090000Z
RRULE:FREQ=WEEKLY
EXDATE:00000101T000000Z
SUMMARY:Série`, `
UID:s@x
RECURRENCE-ID:00000101T000000Z
DTSTART:20261007T090000Z
SUMMARY:Occurrence impossible`))

	rows := byUID(events, "s@x")
	if len(rows) != 1 || len(rows[0].Exdates) != 0 {
		t.Errorf("rows = %+v, want the series alone (the database refuses year 0)", rows)
	}
}
