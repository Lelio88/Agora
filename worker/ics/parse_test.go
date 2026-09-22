package ics

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"
	_ "time/tzdata"
)

// now des tests : les rdv qui finissent avant le 22/09/2025 sortent de la
// fenêtre.
var testNow = time.Date(2026, 9, 22, 12, 0, 0, 0, time.UTC)

func utc(s string) time.Time {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		panic(err)
	}
	return t
}

// feed enveloppe des VEVENT dans un VCALENDAR, lignes en CRLF comme la RFC.
func feed(header string, events ...string) []byte {
	body := "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Test//EN\n" + header
	for _, e := range events {
		body += "BEGIN:VEVENT\n" + strings.TrimSpace(e) + "\nEND:VEVENT\n"
	}
	body += "END:VCALENDAR\n"
	return []byte(strings.ReplaceAll(body, "\n", "\r\n"))
}

func mustParse(t *testing.T, body []byte) []Event {
	t.Helper()
	events, err := Parse(body, testNow)
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	return events
}

func byUID(events []Event, uid string) []Event {
	var out []Event
	for _, e := range events {
		if e.UID == uid {
			out = append(out, e)
		}
	}
	return out
}

func TestParseTimedEventInItsZone(t *testing.T) {
	events := mustParse(t, feed("", `
UID:r1@x
DTSTART;TZID=Europe/Paris:20261006T100000
DTEND;TZID=Europe/Paris:20261006T113000
SUMMARY:Réunion\, équipe
LOCATION:Salle 2
DESCRIPTION:Ordre du jour :\n1. budget\; 2. planning`))

	if len(events) != 1 {
		t.Fatalf("got %d events, want 1", len(events))
	}
	e := events[0]
	if !e.StartsAt.Equal(utc("2026-10-06T08:00:00Z")) || !e.EndsAt.Equal(utc("2026-10-06T09:30:00Z")) {
		t.Errorf("slot = %v → %v, want 08:00 → 09:30 UTC", e.StartsAt, e.EndsAt)
	}
	if e.Timezone != "Europe/Paris" || e.AllDay {
		t.Errorf("timezone = %q, allDay = %v", e.Timezone, e.AllDay)
	}
	if e.Title != "Réunion, équipe" {
		t.Errorf("title = %q: an escaped comma must not cut the text", e.Title)
	}
	if e.Location == nil || *e.Location != "Salle 2" {
		t.Errorf("location = %v", e.Location)
	}
	if e.Description == nil || *e.Description != "Ordre du jour :\n1. budget; 2. planning" {
		t.Errorf("description = %q", *e.Description)
	}
	if e.RRule != nil || e.RecurrenceID != nil {
		t.Errorf("a single event has no rule nor recurrence id")
	}
}

func TestParseAllDayEventIsACalendarDate(t *testing.T) {
	events := mustParse(t, feed("", `
UID:day@x
DTSTART;VALUE=DATE:20261010
SUMMARY:Anniversaire`, `
UID:trip@x
DTSTART;VALUE=DATE:20261012
DTEND;VALUE=DATE:20261015
SUMMARY:Voyage`))

	day := byUID(events, "day@x")[0]
	if !day.AllDay || !day.StartsAt.Equal(utc("2026-10-10T00:00:00Z")) || !day.EndsAt.Equal(utc("2026-10-11T00:00:00Z")) {
		t.Errorf("one day = %+v, want 10/10 → 11/10 at midnight UTC", day)
	}
	trip := byUID(events, "trip@x")[0]
	if !trip.EndsAt.Equal(utc("2026-10-15T00:00:00Z")) || trip.Timezone != "UTC" {
		t.Errorf("trip ends %v in %q, want 15/10 (exclusive) in UTC", trip.EndsAt, trip.Timezone)
	}
}

func TestParseSeriesWithExceptions(t *testing.T) {
	events := mustParse(t, feed("", `
UID:yoga@x
DTSTART;TZID=Europe/Paris:20261006T180000
DTEND;TZID=Europe/Paris:20261006T190000
RRULE:FREQ=WEEKLY;BYDAY=TU
EXDATE;TZID=Europe/Paris:20261013T180000
SUMMARY:Yoga`, `
UID:yoga@x
RECURRENCE-ID;TZID=Europe/Paris:20261020T180000
DTSTART;TZID=Europe/Paris:20261020T200000
DTEND;TZID=Europe/Paris:20261020T210000
SUMMARY:Yoga (décalé)`, `
UID:yoga@x
RECURRENCE-ID;TZID=Europe/Paris:20261027T180000
DTSTART;TZID=Europe/Paris:20261027T180000
DTEND;TZID=Europe/Paris:20261027T190000
STATUS:CANCELLED
SUMMARY:Yoga`, `
UID:orphan@x
RECURRENCE-ID:20261020T160000Z
DTSTART:20261020T180000Z
SUMMARY:Sans série`))

	if got := byUID(events, "orphan@x"); len(got) != 0 {
		t.Errorf("an occurrence without its series is kept: %+v", got)
	}
	yoga := byUID(events, "yoga@x")
	if len(yoga) != 2 {
		t.Fatalf("got %d rows for the series, want the master and one moved occurrence", len(yoga))
	}
	master, moved := yoga[0], yoga[1]
	if master.RRule == nil || *master.RRule != "FREQ=WEEKLY;BYDAY=TU" {
		t.Errorf("rule = %v", master.RRule)
	}
	wantExdates := []time.Time{utc("2026-10-13T16:00:00Z"), utc("2026-10-27T17:00:00Z")}
	if fmt.Sprint(master.Exdates) != fmt.Sprint(wantExdates) {
		t.Errorf("exdates = %v, want %v (EXDATE, then the cancelled occurrence)", master.Exdates, wantExdates)
	}
	if moved.RecurrenceID == nil || !moved.RecurrenceID.Equal(utc("2026-10-20T16:00:00Z")) {
		t.Errorf("moved occurrence slot = %v, want 20/10 16:00 UTC", moved.RecurrenceID)
	}
	if !moved.StartsAt.Equal(utc("2026-10-20T18:00:00Z")) || moved.RRule != nil {
		t.Errorf("moved occurrence = %+v", moved)
	}
}

func TestParseAllDaySeriesMatchesOccurrencesByDate(t *testing.T) {
	events := mustParse(t, feed("", `
UID:bin@x
DTSTART;VALUE=DATE:20261005
RRULE:FREQ=WEEKLY
EXDATE;VALUE=DATE:20261012
SUMMARY:Poubelles`, `
UID:bin@x
RECURRENCE-ID;TZID=Europe/Paris:20261019T000000
DTSTART;VALUE=DATE:20261020
SUMMARY:Poubelles (mardi)`))

	rows := byUID(events, "bin@x")
	if len(rows) != 2 {
		t.Fatalf("got %d rows, want 2", len(rows))
	}
	if fmt.Sprint(rows[0].Exdates) != fmt.Sprint([]time.Time{utc("2026-10-12T00:00:00Z")}) {
		t.Errorf("exdates = %v", rows[0].Exdates)
	}
	if !rows[1].RecurrenceID.Equal(utc("2026-10-19T00:00:00Z")) {
		t.Errorf("slot = %v, want the date 19/10 at midnight UTC, whatever the zone written", rows[1].RecurrenceID)
	}
}

func TestParseKeepsOneYearBackAndAllTheFuture(t *testing.T) {
	events := mustParse(t, feed("", `
UID:old@x
DTSTART:20240110T090000Z
SUMMARY:Trop ancien`, `
UID:recent@x
DTSTART:20251201T090000Z
SUMMARY:Il y a dix mois`, `
UID:far@x
DTSTART:20400101T090000Z
SUMMARY:Dans longtemps`, `
UID:forever@x
DTSTART:20200106T090000Z
RRULE:FREQ=WEEKLY
SUMMARY:Toujours`, `
UID:ended@x
DTSTART:20200106T090000Z
RRULE:FREQ=WEEKLY;UNTIL=20240101T000000Z
SUMMARY:Finie`, `
UID:counted@x
DTSTART:20200106T090000Z
RRULE:FREQ=DAILY;COUNT=3
SUMMARY:Trois fois`))

	var got []string
	for _, e := range events {
		got = append(got, e.UID)
	}
	if want := "[far@x forever@x recent@x]"; fmt.Sprint(got) != want {
		t.Errorf("kept %v, want %v", got, want)
	}
}

func TestParseCancelledAndDuplicates(t *testing.T) {
	events := mustParse(t, feed("", `
UID:gone@x
DTSTART:20261006T090000Z
STATUS:CANCELLED
SUMMARY:Annulé`, `
UID:dup@x
SEQUENCE:2
DTSTART:20261007T090000Z
SUMMARY:Version 2`, `
UID:dup@x
SEQUENCE:1
DTSTART:20261007T100000Z
SUMMARY:Version 1`))

	if len(byUID(events, "gone@x")) != 0 {
		t.Error("a cancelled event is kept")
	}
	dup := byUID(events, "dup@x")
	if len(dup) != 1 || dup[0].Title != "Version 2" {
		t.Errorf("duplicates = %+v, want only the highest SEQUENCE", dup)
	}
}

func TestParseTimeZones(t *testing.T) {
	events := mustParse(t, feed("X-WR-TIMEZONE:America/New_York\n", `
UID:outlook@x
DTSTART;TZID=Romance Standard Time:20261006T100000
SUMMARY:Outlook`, `
UID:mozilla@x
DTSTART;TZID=/mozilla.org/20050126_1/Europe/Paris:20261006T100000
SUMMARY:Ancien Thunderbird`, `
UID:unknown@x
DTSTART;TZID=Heure de Mars:20261006T100000
SUMMARY:Fuseau inconnu`, `
UID:floating@x
DTSTART:20261006T100000
SUMMARY:Heure flottante`))

	for uid, want := range map[string]struct {
		start string
		zone  string
	}{
		"outlook@x":  {"2026-10-06T08:00:00Z", "Europe/Paris"},
		"mozilla@x":  {"2026-10-06T08:00:00Z", "Europe/Paris"},
		"unknown@x":  {"2026-10-06T14:00:00Z", "America/New_York"},
		"floating@x": {"2026-10-06T14:00:00Z", "America/New_York"},
	} {
		e := byUID(events, uid)[0]
		if !e.StartsAt.Equal(utc(want.start)) || e.Timezone != want.zone {
			t.Errorf("%s: %v in %q, want %s in %q", uid, e.StartsAt, e.Timezone, want.start, want.zone)
		}
	}
}

func TestParseDropsRulesItCannotExpand(t *testing.T) {
	events := mustParse(t, feed("", `
UID:hourly@x
DTSTART:20261006T090000Z
RRULE:FREQ=HOURLY
SUMMARY:Toutes les heures`, `
UID:broken@x
DTSTART:20261006T090000Z
RRULE:FREQ=WEEKLY;BYDAY=XX
SUMMARY:Règle invalide`))

	for _, e := range events {
		if e.RRule != nil {
			t.Errorf("%s keeps the rule %q", e.UID, *e.RRule)
		}
	}
	if len(events) != 2 {
		t.Errorf("got %d events, want both kept as single events", len(events))
	}
}

func TestParseCleansTexts(t *testing.T) {
	long := strings.Repeat("é", 250)
	events := mustParse(t, feed("", `
UID:empty@x
DTSTART:20261006T090000Z`, `
UID:long@x
DTSTART:20261006T090000Z
SUMMARY:`+long+`
LOCATION:Rue\, du\nPort`, "UID:nul@x\nDTSTART:20261006T090000Z\nSUMMARY:A\x00B\x07C"))

	if got := byUID(events, "empty@x")[0].Title; got != "—" {
		t.Errorf("empty title = %q, want —", got)
	}
	longRow := byUID(events, "long@x")[0]
	if n := len([]rune(longRow.Title)); n != maxTitleRunes {
		t.Errorf("title has %d characters, want %d", n, maxTitleRunes)
	}
	if *longRow.Location != "Rue, du Port" {
		t.Errorf("location = %q, want one line", *longRow.Location)
	}
	if got := byUID(events, "nul@x")[0].Title; got != "ABC" {
		t.Errorf("title = %q, want control characters removed", got)
	}
}

func TestParseGeneratesAStableUID(t *testing.T) {
	body := feed("", "DTSTART:20261006T090000Z\nSUMMARY:Sans UID")
	first, second := mustParse(t, body), mustParse(t, body)
	if len(first) != 1 || first[0].UID == "" || first[0].UID != second[0].UID {
		t.Errorf("uids = %v / %v, want one stable generated uid", first, second)
	}
}

func TestParseRejects(t *testing.T) {
	many := make([]string, maxEvents+1)
	for i := range many {
		many[i] = fmt.Sprintf("UID:%d@x\nDTSTART:20261006T090000Z", i)
	}
	tests := []struct {
		name string
		body []byte
		want Failure
	}{
		{name: "html page", body: []byte("<!doctype html><html></html>"), want: FailureNotCalendar},
		{name: "not a calendar", body: []byte("BEGIN:VCARD\r\nEND:VCARD\r\n"), want: FailureNotCalendar},
		{name: "deep nesting", body: []byte(strings.Repeat("BEGIN:X\r\n", 50)), want: FailureNotCalendar},
		{name: "too many events", body: feed("", many...), want: FailureTooManyEvents},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Parse(tt.body, testNow)
			if !errors.Is(err, tt.want) {
				t.Errorf("Parse() error = %v, want %v", err, tt.want)
			}
		})
	}
}

func TestParseStopsWhenRulesTakeTooLong(t *testing.T) {
	saved := ruleBudget
	ruleBudget = 0
	t.Cleanup(func() { ruleBudget = saved })

	_, err := Parse(feed("", "UID:s@x\nDTSTART:20261006T090000Z\nRRULE:FREQ=DAILY"), testNow)
	if !errors.Is(err, FailureTooManyEvents) {
		t.Errorf("Parse() error = %v, want %v", err, FailureTooManyEvents)
	}
}

func TestParseAcceptsAByteOrderMark(t *testing.T) {
	body := append([]byte("\xef\xbb\xbf"), feed("", "UID:a@x\nDTSTART:20261006T090000Z")...)
	if events := mustParse(t, body); len(events) != 1 {
		t.Errorf("got %d events, want 1", len(events))
	}
}

func TestEventJSONMatchesTheDatabaseContract(t *testing.T) {
	events := mustParse(t, feed("", "UID:a@x\nDTSTART:20261006T090000Z\nSUMMARY:A"))
	raw, err := json.Marshal(events[0])
	if err != nil {
		t.Fatal(err)
	}
	want := `{"uid":"a@x","recurrence_id":null,"title":"A","description":null,"location":null,` +
		`"starts_at":"2026-10-06T09:00:00Z","ends_at":"2026-10-06T09:00:00Z","all_day":false,` +
		`"timezone":"UTC","rrule":null,"exdates":[]}`
	if string(raw) != want {
		t.Errorf("json = %s\nwant   %s", raw, want)
	}
}
