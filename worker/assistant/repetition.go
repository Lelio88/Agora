package assistant

// Répétition d'un rdv créé ou proposé par un assistant : une série en une
// seule ligne (RRULE et exceptions), que le worker déplie comme toute série.
//
// Choix non évidents :
//   - seul le sous-ensemble que l'éditeur de l'app relit est écrit (FREQ,
//     INTERVAL, BYDAY, UNTIL ou COUNT), dans l'ordre de RecurrenceRule.toRRule :
//     une série créée ici s'ouvre dans l'app comme une série saisie à la main ;
//   - la fin est obligatoire et la dernière séance tombe au plus un an après
//     la première (heure murale) : une consigne injectée ne remplit pas un
//     agenda pour des années, et une série se supprime d'un geste dans l'app ;
//   - une séance sautée se donne par sa date ; l'instant exclu est celui que
//     recurrence.Expand calcule pour ce jour (fuseau de la série, changement
//     d'heure compris), le seul que le worker reconnaîtra à son tour ;
//   - le début doit être la première séance (un des jours choisis) : sinon la
//     règle ferait commencer la série plus tard que ce qui a été demandé.
//
// Invariant : une série compte pour une seule écriture dans le plafond.

import (
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/Lelio88/agora/worker/recurrence"
)

// seriesSpanYears borne une série : sa dernière séance au plus tard un an
// (heure murale) après la première.
const seriesSpanYears = 1

// RepetitionInput fait d'un rdv une série.
type RepetitionInput struct {
	Frequence  string   `json:"frequence" jsonschema:"quotidienne, hebdomadaire, mensuelle ou annuelle"`
	Intervalle int      `json:"intervalle,omitempty" jsonschema:"une séance toutes les N périodes (défaut 1 ; 2 = une semaine sur deux)"`
	Jours      []string `json:"jours,omitempty" jsonschema:"hebdomadaire seulement : lundi … dimanche (défaut : le jour du début, qui doit en faire partie)"`
	JusquAu    string   `json:"jusqu_au,omitempty" jsonschema:"date de la dernière séance possible, comprise (2027-01-04) ; ou bien nombre"`
	Nombre     int      `json:"nombre,omitempty" jsonschema:"nombre de séances, sautées comprises ; ou bien jusqu_au"`
	Sauf       []string `json:"sauf,omitempty" jsonschema:"dates des séances sautées (vacances, jours fériés)"`
}

// RepetitionOutput résume la série créée.
type RepetitionOutput struct {
	Seances  int    `json:"seances"`
	Premiere string `json:"premiere"`
	Derniere string `json:"derniere"`
}

// series est une répétition vérifiée, prête à écrire.
type series struct {
	rule     string
	exdates  []time.Time
	sessions []recurrence.Occurrence
}

var frequencies = map[string]string{
	"quotidienne": "DAILY", "hebdomadaire": "WEEKLY", "mensuelle": "MONTHLY", "annuelle": "YEARLY",
}

// dayCodes suit l'ordre de l'app : du lundi au dimanche.
var dayCodes = []struct{ name, code string }{
	{"lundi", "MO"}, {"mardi", "TU"}, {"mercredi", "WE"}, {"jeudi", "TH"},
	{"vendredi", "FR"}, {"samedi", "SA"}, {"dimanche", "SU"},
}

// buildSeries vérifie rep pour un rdv de start à end, et rend sa règle, ses
// exceptions et ses séances. Sans répétition, rend nil.
func buildSeries(rep *RepetitionInput, start, end time.Time, allDay bool, loc *time.Location) (*series, error) {
	if rep == nil {
		return nil, nil
	}
	// Une journée entière se déplie en UTC (minuit UTC, comme l'app la range).
	wall := loc
	if allDay {
		wall = time.UTC
	}
	limit := start.In(wall).AddDate(seriesSpanYears, 0, 0)
	rule, err := ruleOf(*rep, start, limit, wall)
	if err != nil {
		return nil, err
	}
	candidates, err := recurrence.Expand(
		recurrence.Series{Start: start, End: end, AllDay: allDay, Timezone: loc.String(), RRule: rule},
		recurrence.Window{From: start, To: limit.Add(time.Second)})
	if err != nil {
		return nil, fmt.Errorf("expand repetition: %w", err)
	}
	if len(candidates) == 0 || !candidates[0].Start.Equal(start) {
		return nil, refuse("Le début du rdv doit être la première séance : un des jours choisis.")
	}
	if rep.Nombre > len(candidates) {
		return nil, refuse("Une série dure au plus un an : %d séances dépassent cette limite.", rep.Nombre)
	}
	exdates, err := skippedSessions(rep.Sauf, candidates, wall)
	if err != nil {
		return nil, err
	}
	sessions := slices.DeleteFunc(candidates, func(o recurrence.Occurrence) bool {
		return slices.ContainsFunc(exdates, o.Start.Equal)
	})
	if len(sessions) == 0 {
		return nil, refuse("Toutes les séances seraient sautées : il ne resterait rien à créer.")
	}
	return &series{rule: rule, exdates: exdates, sessions: sessions}, nil
}

// ruleOf écrit la RRULE de rep, fin comprise.
func ruleOf(rep RepetitionInput, start, limit time.Time, wall *time.Location) (string, error) {
	freq, ok := frequencies[strings.ToLower(strings.TrimSpace(rep.Frequence))]
	if !ok {
		return "", refuse("Fréquence inconnue « %s » : quotidienne, hebdomadaire, mensuelle ou annuelle.", rep.Frequence)
	}
	parts := []string{"FREQ=" + freq}
	switch {
	case rep.Intervalle < 0:
		return "", refuse("L'intervalle compte au moins 1.")
	case rep.Intervalle > 1:
		parts = append(parts, fmt.Sprintf("INTERVAL=%d", rep.Intervalle))
	}
	days, err := byDay(rep.Jours, freq)
	if err != nil {
		return "", err
	}
	if days != "" {
		parts = append(parts, "BYDAY="+days)
	}
	end, err := endOf(rep, start, limit, wall)
	if err != nil {
		return "", err
	}
	return strings.Join(append(parts, end), ";"), nil
}

// byDay rend la partie BYDAY, jours dans l'ordre de l'app.
func byDay(jours []string, freq string) (string, error) {
	if len(jours) == 0 {
		return "", nil
	}
	if freq != "WEEKLY" {
		return "", refuse("Les jours ne valent que pour une répétition hebdomadaire.")
	}
	chosen := map[string]bool{}
	for _, j := range jours {
		name := strings.ToLower(strings.TrimSpace(j))
		if !slices.ContainsFunc(dayCodes, func(d struct{ name, code string }) bool { return d.name == name }) {
			return "", refuse("Jour inconnu « %s » : lundi, mardi, mercredi, jeudi, vendredi, samedi ou dimanche.", j)
		}
		chosen[name] = true
	}
	var codes []string
	for _, d := range dayCodes {
		if chosen[d.name] {
			codes = append(codes, d.code)
		}
	}
	return strings.Join(codes, ","), nil
}

// endOf rend la fin de la règle : UNTIL (fin du jour donné, heure murale)
// ou COUNT.
func endOf(rep RepetitionInput, start, limit time.Time, wall *time.Location) (string, error) {
	jusquAu := strings.TrimSpace(rep.JusquAu)
	switch {
	case jusquAu != "" && rep.Nombre != 0:
		return "", refuse("Donne jusqu_au ou nombre, pas les deux.")
	case rep.Nombre < 0:
		return "", refuse("Le nombre de séances compte au moins 1.")
	case rep.Nombre > 0:
		return fmt.Sprintf("COUNT=%d", rep.Nombre), nil
	case jusquAu == "":
		return "", refuse("Donne la fin de la répétition : jusqu_au (une date) ou nombre (de séances).")
	}
	t, _, err := parseMoment(jusquAu, wall)
	if err != nil {
		return "", err
	}
	day := t.In(wall)
	until := time.Date(day.Year(), day.Month(), day.Day(), 23, 59, 59, 0, wall)
	if until.Before(start) {
		return "", refuse("La date de fin de la répétition précède son début.")
	}
	if dayAfter(until, limit) {
		return "", refuse("Une série dure au plus un an : sa dernière séance doit tomber au plus tard le %s.",
			limit.Format(dateLayout))
	}
	return "UNTIL=" + until.UTC().Format("20060102T150405Z"), nil
}

// dayAfter dit si le jour de a suit celui de b (même fuseau).
func dayAfter(a, b time.Time) bool {
	ay, am, ad := a.Date()
	by, bm, bd := b.Date()
	return time.Date(ay, am, ad, 0, 0, 0, 0, time.UTC).After(time.Date(by, bm, bd, 0, 0, 0, 0, time.UTC))
}

// skippedSessions rend les instants des séances sautées, triés et sans
// doublon : chaque date doit être celle d'une séance.
func skippedSessions(sauf []string, candidates []recurrence.Occurrence, wall *time.Location) ([]time.Time, error) {
	var instants []time.Time
	for _, s := range sauf {
		t, _, err := parseMoment(s, wall)
		if err != nil {
			return nil, err
		}
		day := t.In(wall)
		i := slices.IndexFunc(candidates, func(o recurrence.Occurrence) bool {
			y, m, d := o.Start.In(wall).Date()
			return y == day.Year() && m == day.Month() && d == day.Day()
		})
		if i < 0 {
			return nil, refuse("Le %s n'est pas une séance de la série : rien à sauter ce jour-là.", day.Format(dateLayout))
		}
		if !slices.ContainsFunc(instants, candidates[i].Start.Equal) {
			instants = append(instants, candidates[i].Start)
		}
	}
	slices.SortFunc(instants, time.Time.Compare)
	return instants, nil
}

// output résume la série pour l'assistant.
func (s *series) output(allDay bool, loc *time.Location) *RepetitionOutput {
	if s == nil {
		return nil
	}
	return &RepetitionOutput{
		Seances:  len(s.sessions),
		Premiere: formatStart(s.sessions[0].Start, allDay, loc),
		Derniere: formatStart(s.sessions[len(s.sessions)-1].Start, allDay, loc),
	}
}
