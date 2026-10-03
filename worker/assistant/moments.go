package assistant

import (
	"fmt"
	"strings"
	"time"

	"github.com/Lelio88/agora/worker/slots"
)

// Dates et heures échangées avec l'assistant : ISO 8601. Une heure sans
// décalage se lit dans le fuseau du profil (heure murale), une date seule
// désigne un jour de calendrier. Les dates rendues sont dans ce même fuseau,
// avec leur décalage ; une journée entière se rend en date seule, fin
// comprise (le stockage garde une fin exclue, à minuit UTC).

// maxRange est la plage la plus longue qu'un outil lit (règle des RPC).
const maxRange = 93 * 24 * time.Hour

const (
	dateLayout = "2006-01-02"
	// defaultSpan est la plage lue quand l'assistant n'en donne pas.
	defaultSpan = 7 * 24 * time.Hour
)

var wallLayouts = []string{"2006-01-02T15:04:05", "2006-01-02T15:04", "2006-01-02 15:04:05", "2006-01-02 15:04"}

// parseMoment lit une date, une heure murale ou un instant avec décalage.
// dateOnly dit si l'assistant n'a donné qu'un jour.
func parseMoment(s string, loc *time.Location) (t time.Time, dateOnly bool, err error) {
	s = strings.TrimSpace(s)
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, false, nil
	}
	for _, layout := range wallLayouts {
		if t, err := time.ParseInLocation(layout, s, loc); err == nil {
			return t, false, nil
		}
	}
	if t, err := time.ParseInLocation(dateLayout, s, loc); err == nil {
		return t, true, nil
	}
	return time.Time{}, false, refuse("« %s » n'est pas une date ISO 8601 (2026-10-09, 2026-10-09T18:30 ou 2026-10-09T18:30:00+02:00).", s)
}

// parseRange lit [du, au[ : une date seule pour « au » compte en entier.
// Sans « du », la plage part de minuit aujourd'hui ; sans « au », elle dure
// une semaine.
func parseRange(du, au string, now time.Time, loc *time.Location) (time.Time, time.Time, error) {
	from := startOfDay(now.In(loc))
	if strings.TrimSpace(du) != "" {
		t, _, err := parseMoment(du, loc)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
		from = t
	}
	to := from.Add(defaultSpan)
	if strings.TrimSpace(au) != "" {
		t, dateOnly, err := parseMoment(au, loc)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
		to = t
		if dateOnly {
			to = time.Date(t.Year(), t.Month(), t.Day()+1, 0, 0, 0, 0, loc)
		}
	}
	if !to.After(from) {
		return time.Time{}, time.Time{}, refuse("La fin de la plage doit suivre son début.")
	}
	if to.Sub(from) > maxRange {
		return time.Time{}, time.Time{}, refuse("Une plage dure au plus 93 jours : découpe la demande.")
	}
	return from, to, nil
}

func startOfDay(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
}

// formatStart et formatEnd rendent les bornes d'un rdv pour l'assistant.
func formatStart(t time.Time, allDay bool, loc *time.Location) string {
	if allDay {
		return slots.CalendarDate(t, loc).Format(dateLayout)
	}
	return t.In(loc).Format(time.RFC3339)
}

func formatEnd(t time.Time, allDay bool, loc *time.Location) string {
	if allDay {
		// Fin exclue au stockage, comprise pour l'assistant.
		d := slots.CalendarDate(t, loc)
		return time.Date(d.Year(), d.Month(), d.Day()-1, 0, 0, 0, 0, loc).Format(dateLayout)
	}
	return t.In(loc).Format(time.RFC3339)
}

// eventBounds lit les bornes d'un rdv à créer, comme l'éditeur de l'app :
// une journée entière va de minuit UTC du premier jour à minuit UTC du
// lendemain du dernier (fin exclue) ; un rdv à l'heure exige sa fin.
func eventBounds(debut, fin string, allDay bool, loc *time.Location) (time.Time, time.Time, error) {
	start, _, err := parseMoment(debut, loc)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	if allDay {
		last := start
		if strings.TrimSpace(fin) != "" {
			if last, _, err = parseMoment(fin, loc); err != nil {
				return time.Time{}, time.Time{}, err
			}
		}
		first := time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, time.UTC)
		end := time.Date(last.Year(), last.Month(), last.Day()+1, 0, 0, 0, 0, time.UTC)
		if !end.After(first) {
			return time.Time{}, time.Time{}, refuse("Le dernier jour ne peut pas précéder le premier.")
		}
		return first, end, nil
	}
	if strings.TrimSpace(fin) == "" {
		return time.Time{}, time.Time{}, refuse("Donne l'heure de fin du rdv (ou journee_entiere).")
	}
	end, _, err := parseMoment(fin, loc)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	if !end.After(start) {
		return time.Time{}, time.Time{}, refuse("La fin du rdv doit suivre son début.")
	}
	return start.UTC(), end.UTC(), nil
}

// parseClock lit « 18 », « 18:30 » ou « 24:00 » en durée depuis minuit.
func parseClock(s string, fallback time.Duration) (time.Duration, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return fallback, nil
	}
	var h, m int
	if _, err := fmt.Sscanf(s, "%d:%d", &h, &m); err != nil {
		if _, err := fmt.Sscanf(s, "%d", &h); err != nil {
			return 0, refuse("« %s » n'est pas une heure (18:30).", s)
		}
	}
	if h < 0 || m < 0 || m > 59 || h > 24 || (h == 24 && m > 0) {
		return 0, refuse("« %s » n'est pas une heure (18:30).", s)
	}
	return time.Duration(h)*time.Hour + time.Duration(m)*time.Minute, nil
}

var weekdayNames = map[string]time.Weekday{
	"lundi": time.Monday, "mardi": time.Tuesday, "mercredi": time.Wednesday, "jeudi": time.Thursday,
	"vendredi": time.Friday, "samedi": time.Saturday, "dimanche": time.Sunday,
}

// parseWeekdays lit les jours voulus ; aucun veut dire tous.
func parseWeekdays(names []string) (map[time.Weekday]bool, error) {
	days := map[time.Weekday]bool{}
	if len(names) == 0 {
		for d := time.Sunday; d <= time.Saturday; d++ {
			days[d] = true
		}
		return days, nil
	}
	for _, n := range names {
		d, ok := weekdayNames[strings.ToLower(strings.TrimSpace(n))]
		if !ok {
			return nil, refuse("« %s » n'est pas un jour (lundi … dimanche).", n)
		}
		days[d] = true
	}
	return days, nil
}
