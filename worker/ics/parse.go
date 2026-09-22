package ics

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/emersion/go-ical"
	"github.com/teambition/rrule-go"
)

// Bornes d'un flux lu. Les longueurs sont celles des contraintes de
// public.events.
const (
	maxEvents           = 5000
	maxComponents       = 20000
	maxTitleRunes       = 200
	maxLocationRunes    = 300
	maxDescriptionRunes = 5000
	maxRuleLength       = 500
	maxUIDBytes         = 255
	maxExdates          = 1000
	untitled            = "—"
)

// ruleBudget borne le temps passé à vérifier les règles de répétition d'un
// flux : une règle impossible (« chaque 30 février ») fait tourner rrule-go
// jusqu'à l'an 9999, environ 0,1 s. Variable pour les tests.
var ruleBudget = 3 * time.Second

// rulePattern est la contrainte de la base sur events.rrule.
var rulePattern = regexp.MustCompile(`(^|;)FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(;|$)`)

// component est un VEVENT lu, avant tri.
type component struct {
	uid          string
	recurrenceID time.Time // zéro : ligne maîtresse ou rdv ponctuel
	cancelled    bool
	sequence     int
	start, end   time.Time
	allDay       bool
	zone         string
	rule         string
	exdates      []time.Time
	title        string
	description  string
	location     string
}

// Parse lit un flux et rend les lignes à appliquer : les rdv qui finissent
// au plus un an avant now, et toutes les séries encore actives à cette date.
//
// Tri des composants :
//   - un UID en double garde la version de plus grand SEQUENCE ;
//   - une occurrence annulée (STATUS:CANCELLED + RECURRENCE-ID) devient une
//     date exclue de sa série ; un rdv ou une série annulés disparaissent ;
//   - une occurrence modifiée sans série connue est ignorée ;
//   - une règle infra-journalière, trop longue ou invalide est abandonnée :
//     le rdv garde sa première occurrence. RDATE est ignoré.
//
// L'erreur est FailureNotCalendar (illisible) ou FailureTooManyEvents.
// Une panique pendant la lecture (le décodeur de go-ical en lève sur
// certaines lignes mal formées) devient FailureNotCalendar : un flux hostile
// ne doit pas arrêter le worker, dépliage des séries compris.
func Parse(body []byte, now time.Time) (events []Event, err error) {
	defer func() {
		if recover() != nil {
			events, err = nil, FailureNotCalendar
		}
	}()
	body = bytes.TrimPrefix(body, []byte("\xef\xbb\xbf"))
	if !withinDecoderLimits(body) {
		return nil, FailureNotCalendar
	}
	cal, err := ical.NewDecoder(bytes.NewReader(body)).Decode()
	if err != nil {
		return nil, FailureNotCalendar
	}
	vevents := cal.Events()
	if len(vevents) > maxComponents {
		return nil, FailureTooManyEvents
	}
	z := zones{fallback: time.UTC}
	if name := cal.Props.Get("X-WR-TIMEZONE"); name != nil {
		if loc, ok := resolveZone(name.Value); ok {
			z.fallback = loc
		}
	}
	masters, overrides := z.group(vevents)
	p := parser{from: now.AddDate(-1, 0, 0), deadline: time.Now().Add(ruleBudget)}
	events, err = p.selectRows(masters, overrides)
	if err != nil {
		return nil, err
	}
	if len(events) > maxEvents {
		return nil, FailureTooManyEvents
	}
	return events, nil
}

// zones résout les dates d'un flux ; fallback sert aux heures « flottantes »
// (sans fuseau) et aux TZID inconnus.
type zones struct {
	fallback *time.Location
}

// group lit les VEVENT et les range : lignes maîtresses (et rdv ponctuels)
// par UID, occurrences modifiées par UID puis créneau d'origine. Un doublon
// garde la version de plus grand SEQUENCE, la dernière à égalité.
func (z zones) group(vevents []ical.Event) (map[string]*component, map[string]map[int64]*component) {
	masters := map[string]*component{}
	overrides := map[string]map[int64]*component{}
	for _, ev := range vevents {
		c, ok := z.read(ev)
		if !ok {
			continue
		}
		if c.recurrenceID.IsZero() {
			if current, found := masters[c.uid]; !found || c.sequence >= current.sequence {
				masters[c.uid] = c
			}
			continue
		}
		byStart := overrides[c.uid]
		if byStart == nil {
			byStart = map[int64]*component{}
			overrides[c.uid] = byStart
		}
		// Le créneau exact n'est connu qu'avec la série (journée entière) :
		// on range ici par l'instant lu, la série le normalise ensuite.
		key := c.recurrenceID.UnixNano()
		if current, found := byStart[key]; !found || c.sequence >= current.sequence {
			byStart[key] = c
		}
	}
	return masters, overrides
}

// read lit un VEVENT ; ok est faux s'il est inutilisable (sans DTSTART ou
// avec une date illisible).
func (z zones) read(ev ical.Event) (*component, bool) {
	props := ev.Props
	startProp := props.Get(ical.PropDateTimeStart)
	if startProp == nil {
		return nil, false
	}
	start, loc, allDay, err := z.parse(startProp.Value, startProp.Params)
	if err != nil || !inRange(start) {
		return nil, false
	}
	c := &component{
		start:       start,
		allDay:      allDay,
		zone:        "UTC",
		title:       singleLine(text(props, ical.PropSummary)),
		description: text(props, ical.PropDescription),
		location:    singleLine(text(props, ical.PropLocation)),
		cancelled:   strings.EqualFold(strings.TrimSpace(value(props, ical.PropStatus)), "CANCELLED"),
	}
	if !allDay {
		c.zone = zoneName(loc)
	}
	c.end = z.end(props, c)
	if !inRange(c.end) {
		return nil, false
	}
	if seq, err := strconv.Atoi(strings.TrimSpace(value(props, ical.PropSequence))); err == nil {
		c.sequence = seq
	}
	if rid := props.Get(ical.PropRecurrenceID); rid != nil {
		t, _, _, err := z.parse(rid.Value, rid.Params)
		if err != nil || !inRange(t) {
			return nil, false
		}
		c.recurrenceID = t
	} else {
		c.rule = readRule(props, c.start)
		c.exdates = z.exdates(props)
	}
	c.uid = uid(props, startProp.Value, c.title)
	return c, true
}

// end calcule la fin : DTEND, sinon DURATION, sinon la RFC (un jour pour
// une journée entière, une durée nulle sinon). Une fin antérieure au début
// est ramenée au début (au lendemain pour une journée entière).
func (z zones) end(props ical.Props, c *component) time.Time {
	var end time.Time
	if p := props.Get(ical.PropDateTimeEnd); p != nil {
		if t, _, _, err := z.parse(p.Value, p.Params); err == nil {
			end = t
		}
	} else if p := props.Get(ical.PropDuration); p != nil {
		if d, err := p.Duration(); err == nil && d >= 0 {
			end = c.start.Add(d)
		}
	}
	if c.allDay {
		end = calendarDay(end)
		if !end.After(c.start) {
			end = c.start.AddDate(0, 0, 1)
		}
		return end
	}
	if end.Before(c.start) {
		return c.start
	}
	return end
}

// parse lit une valeur DATE ou DATE-TIME. Une DATE est une date de
// calendrier, rendue à minuit UTC (convention de l'app pour une journée
// entière). loc est le fuseau d'une DATE-TIME.
func (z zones) parse(raw string, params ical.Params) (t time.Time, loc *time.Location, isDate bool, err error) {
	raw = strings.ToUpper(strings.TrimSpace(raw))
	if strings.EqualFold(params.Get(ical.ParamValue), string(ical.ValueDate)) || len(raw) == len("20060102") {
		t, err = time.ParseInLocation("20060102", raw, time.UTC)
		return t, time.UTC, true, err
	}
	if strings.HasSuffix(raw, "Z") {
		t, err = time.ParseInLocation("20060102T150405Z", raw, time.UTC)
		return t, time.UTC, false, err
	}
	loc = z.fallback
	if tzid := params.Get(ical.ParamTimezoneID); tzid != "" {
		if resolved, ok := resolveZone(tzid); ok {
			loc = resolved
		}
	}
	t, err = time.ParseInLocation("20060102T150405", raw, loc)
	return t, loc, false, err
}

// exdates lit les EXDATE (plusieurs propriétés, chacune une liste).
func (z zones) exdates(props ical.Props) []time.Time {
	var out []time.Time
	for _, p := range props.Values(ical.PropExceptionDates) {
		for raw := range strings.SplitSeq(p.Value, ",") {
			if t, _, _, err := z.parse(raw, p.Params); err == nil && inRange(t) {
				out = append(out, t)
			}
		}
	}
	return out
}

// readRule rend la RRULE si la base et le worker savent la déplier depuis
// start, "" sinon.
func readRule(props ical.Props, start time.Time) string {
	rule := strings.ToUpper(strings.TrimSpace(value(props, ical.PropRecurrenceRule)))
	rule = strings.TrimPrefix(rule, "RRULE:")
	if rule == "" || len(rule) > maxRuleLength || !rulePattern.MatchString(rule) {
		return ""
	}
	option, err := rrule.StrToROption(rule)
	if err != nil {
		return ""
	}
	option.Dtstart = start
	if _, err := rrule.NewRRule(*option); err != nil {
		return ""
	}
	return rule
}

// parser choisit les lignes à garder.
type parser struct {
	from     time.Time
	deadline time.Time
}

// selectRows applique annulations et fenêtre, et rend les lignes triées (UID,
// puis occurrence).
func (p parser) selectRows(masters map[string]*component, overrides map[string]map[int64]*component) ([]Event, error) {
	var events []Event
	for id, m := range masters {
		if m.cancelled {
			continue
		}
		kept, err := p.overridesOf(m, overrides[id])
		if err != nil {
			return nil, err
		}
		reaches, err := p.reaches(m)
		if err != nil {
			return nil, err
		}
		if !reaches {
			continue
		}
		events = append(events, p.row(m, nil))
		events = append(events, kept...)
	}
	slices.SortFunc(events, func(a, b Event) int {
		if c := strings.Compare(a.UID, b.UID); c != 0 {
			return c
		}
		return compareOptionalTime(a.RecurrenceID, b.RecurrenceID)
	})
	return events, nil
}

// overridesOf rattache ses occurrences modifiées à une série : une
// annulation devient une date exclue, une modification une ligne. Une
// journée entière se repère par sa date, quel que soit le fuseau écrit.
func (p parser) overridesOf(m *component, found map[int64]*component) ([]Event, error) {
	if m.rule == "" || len(found) == 0 {
		return nil, nil
	}
	var rows []Event
	seen := map[int64]bool{}
	for _, o := range found {
		slot := o.recurrenceID.UTC()
		if m.allDay {
			slot = calendarDay(o.recurrenceID)
		}
		if seen[slot.UnixNano()] {
			continue
		}
		seen[slot.UnixNano()] = true
		if o.cancelled {
			m.exdates = append(m.exdates, slot)
			continue
		}
		if o.end.Before(p.from) {
			continue
		}
		rows = append(rows, p.row(o, &slot))
	}
	return rows, nil
}

// reaches dit si un rdv, ou une occurrence d'une série, finit après le
// début de la fenêtre. Pour une série, rrule-go cherche la première
// occurrence utile, sous le budget de temps du flux.
func (p parser) reaches(c *component) (bool, error) {
	threshold := p.from.Add(-c.end.Sub(c.start))
	if c.rule == "" {
		return !c.start.Before(threshold), nil
	}
	if !time.Now().Before(p.deadline) {
		return false, FailureTooManyEvents
	}
	option, err := rrule.StrToROption(c.rule)
	if err != nil {
		return false, nil
	}
	option.Dtstart = c.start
	rule, err := rrule.NewRRule(*option)
	if err != nil {
		return false, nil
	}
	return !rule.After(threshold, true).IsZero(), nil
}

// row construit la ligne d'un composant ; recurrenceID est le créneau
// d'origine d'une occurrence modifiée.
func (p parser) row(c *component, recurrenceID *time.Time) Event {
	e := Event{
		UID:          c.uid,
		RecurrenceID: recurrenceID,
		Title:        truncate(c.title, maxTitleRunes),
		Description:  optional(truncate(c.description, maxDescriptionRunes)),
		Location:     optional(truncate(c.location, maxLocationRunes)),
		StartsAt:     c.start.UTC(),
		EndsAt:       c.end.UTC(),
		AllDay:       c.allDay,
		Timezone:     c.zone,
		Exdates:      []time.Time{},
	}
	if e.Title == "" {
		e.Title = untitled
	}
	if recurrenceID == nil && c.rule != "" {
		rule := c.rule
		e.RRule = &rule
		e.Exdates = p.exdates(c)
	}
	return e
}

// exdates normalise les dates exclues d'une série : créneaux de la
// fenêtre seulement, sans doublon, triés, bornés.
func (p parser) exdates(c *component) []time.Time {
	out := []time.Time{}
	seen := map[int64]bool{}
	for _, t := range c.exdates {
		t = t.UTC()
		if c.allDay {
			t = calendarDay(t)
		}
		if t.Before(p.from.AddDate(0, 0, -7)) || seen[t.UnixNano()] {
			continue
		}
		seen[t.UnixNano()] = true
		out = append(out, t)
	}
	slices.SortFunc(out, func(a, b time.Time) int { return a.Compare(b) })
	if len(out) > maxExdates {
		out = out[:maxExdates]
	}
	return out
}

// calendarDay rend la date d'un instant, dans le fuseau où il a été lu, à
// minuit UTC.
func calendarDay(t time.Time) time.Time {
	if t.IsZero() {
		return t
	}
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// inRange écarte les dates que JSON ou la base refuseraient.
func inRange(t time.Time) bool {
	return t.Year() >= 1900 && t.Year() <= 3000
}

func compareOptionalTime(a, b *time.Time) int {
	switch {
	case a == nil && b == nil:
		return 0
	case a == nil:
		return -1
	case b == nil:
		return 1
	}
	return a.Compare(*b)
}

// uid rend l'UID du flux, ou en fabrique un stable pour un VEVENT qui n'en
// a pas. Un UID trop long est remplacé par son empreinte.
func uid(props ical.Props, rawStart, title string) string {
	id := clean(value(props, ical.PropUID))
	if id == "" {
		sum := sha256.Sum256([]byte(rawStart + "\x00" + title))
		return "agora-generated-" + hex.EncodeToString(sum[:16])
	}
	if len(id) > maxUIDBytes {
		sum := sha256.Sum256([]byte(id))
		return "sha256-" + hex.EncodeToString(sum[:])
	}
	return id
}

func value(props ical.Props, name string) string {
	if p := props.Get(name); p != nil {
		return p.Value
	}
	return ""
}

// text lit un texte iCal. Plus tolérant que Prop.Text de go-ical, qui
// coupe à la première virgule non échappée et refuse un échappement
// inconnu : les flux réels en sont pleins.
func text(props ical.Props, name string) string {
	raw := value(props, name)
	var b strings.Builder
	for i := 0; i < len(raw); i++ {
		c := raw[i]
		if c != '\\' || i == len(raw)-1 {
			b.WriteByte(c)
			continue
		}
		i++
		switch raw[i] {
		case 'n', 'N':
			b.WriteByte('\n')
		default:
			b.WriteByte(raw[i])
		}
	}
	return clean(b.String())
}

// clean rend un texte UTF-8 valide, sans caractère de contrôle (sauf saut
// de ligne et tabulation) : Postgres refuse le caractère nul.
func clean(s string) string {
	s = strings.ToValidUTF8(s, "�")
	s = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\t' || !unicode.IsControl(r) {
			return r
		}
		return -1
	}, s)
	return strings.TrimSpace(s)
}

func singleLine(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func truncate(s string, maxRunes int) string {
	if utf8.RuneCountInString(s) <= maxRunes {
		return s
	}
	runes := []rune(s)
	return strings.TrimSpace(string(runes[:maxRunes-1])) + "…"
}

func optional(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
