// Package slots cherche les créneaux libres communs d'un groupe : /dispo du
// bot Discord et l'outil creneaux_communs du serveur MCP.
//
// Portage de app/lib/src/features/groups/domain/free_slots.dart, qui fait
// foi. Les deux implémentations passent les mêmes cas de test ; toute
// évolution de l'une se reporte dans l'autre.
//
// Rappel des règles : un rdv du groupe prend le créneau pour tout le monde ;
// une journée entière ne prend rien sauf AllDayBlocks ; tout se calcule en
// heure murale du fuseau (18 h reste 18 h un jour de changement d'heure) ;
// un créneau ne commence jamais avant le quart d'heure qui suit From.
//
// Le calcul est pur : il ne lit que ce que l'appelant a déjà obtenu par la
// règle de visibilité (group_agenda) — un rdv « invisible » n'y est pas, donc
// son propriétaire paraît libre.
package slots

import (
	"sort"
	"time"
)

// Item est une ligne de l'agenda du groupe, réduite à ce que le calcul lit.
type Item struct {
	// UserID est vide pour un rdv du groupe.
	UserID       string
	IsGroupEvent bool
	Start        time.Time
	End          time.Time
	AllDay       bool
}

// Max borne le nombre de créneaux rendus.
const Max = 50

const quarter = 15 * time.Minute

// Search décrit ce que l'on cherche.
type Search struct {
	// Location est le fuseau du demandeur : jours et fenêtre s'y lisent.
	Location *time.Location
	// From et To bornent la période [From, To[.
	From, To time.Time
	// Duration est la durée minimale d'un créneau.
	Duration time.Duration
	// DayStart et DayEnd, depuis minuit : fenêtre quotidienne [DayStart,
	// DayEnd[. Une fenêtre qui passe minuit est vide.
	DayStart, DayEnd time.Duration
	Weekdays         map[time.Weekday]bool
	// Members sont les membres dont on veut la présence.
	Members      map[string]bool
	AllDayBlocks bool
}

// Slot est une plage libre pour tous, dans le fuseau de la recherche.
type Slot struct {
	Start, End time.Time
}

// Find rend les plages libres, dans l'ordre, au plus Max.
func Find(search Search, agenda []Item) []Slot {
	if search.DayEnd <= search.DayStart {
		return nil
	}
	loc := search.Location
	busy := busyIntervals(search, agenda)
	earliest := nextQuarter(search.From.In(loc))
	to := search.To.In(loc)
	from := search.From.In(loc)
	var slots []Slot
	for d := time.Date(from.Year(), from.Month(), from.Day(), 0, 0, 0, 0, loc); d.Before(to) && len(slots) < Max; d = time.Date(d.Year(), d.Month(), d.Day()+1, 0, 0, 0, 0, loc) {
		if !search.Weekdays[d.Weekday()] {
			continue
		}
		start, end := at(d, search.DayStart), at(d, search.DayEnd)
		if start.Before(earliest) {
			start = earliest
		}
		if end.After(to) {
			end = to
		}
		for _, free := range subtract(start, end, busy) {
			if free.End.Sub(free.Start) >= search.Duration {
				slots = append(slots, free)
			}
			if len(slots) == Max {
				break
			}
		}
	}
	return slots
}

// at rend l'heure offset du jour d, en heure murale (jamais une addition de
// durée, fausse un jour de changement d'heure).
func at(d time.Time, offset time.Duration) time.Time {
	minutes := int(offset / time.Minute)
	return time.Date(d.Year(), d.Month(), d.Day(), minutes/60, minutes%60, 0, 0, d.Location())
}

func nextQuarter(t time.Time) time.Time {
	floor := time.Date(t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute()-t.Minute()%15, 0, 0, t.Location())
	if floor.Before(t) {
		return floor.Add(quarter)
	}
	return floor
}

// localBounds rend début et fin dans le fuseau. Une journée entière se lit
// sur ses composants UTC (une date de calendrier), jamais par conversion.
func localBounds(item Item, loc *time.Location) (time.Time, time.Time) {
	if item.AllDay {
		return CalendarDate(item.Start, loc), CalendarDate(item.End, loc)
	}
	return item.Start.In(loc), item.End.In(loc)
}

// CalendarDate rend, dans loc, la date de calendrier d'une journée entière :
// elle se lit sur ses composants UTC, jamais par conversion de fuseau.
func CalendarDate(t time.Time, loc *time.Location) time.Time {
	u := t.UTC()
	return time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, loc)
}

// busyIntervals rend les intervalles pris, triés et fusionnés.
func busyIntervals(search Search, agenda []Item) []Slot {
	intervals := make([]Slot, 0, len(agenda))
	for _, item := range agenda {
		if !item.IsGroupEvent && !search.Members[item.UserID] {
			continue
		}
		if item.AllDay && !search.AllDayBlocks {
			continue
		}
		start, end := localBounds(item, search.Location)
		intervals = append(intervals, Slot{start, end})
	}
	sort.Slice(intervals, func(i, j int) bool { return intervals[i].Start.Before(intervals[j].Start) })
	merged := make([]Slot, 0, len(intervals))
	for _, interval := range intervals {
		if n := len(merged); n > 0 && !interval.Start.After(merged[n-1].End) {
			if interval.End.After(merged[n-1].End) {
				merged[n-1].End = interval.End
			}
			continue
		}
		merged = append(merged, interval)
	}
	return merged
}

// subtract rend [start, end[ privé des intervalles busy (triés, fusionnés).
func subtract(start, end time.Time, busy []Slot) []Slot {
	var free []Slot
	cursor := start
	for _, interval := range busy {
		if !interval.End.After(cursor) {
			continue
		}
		if !interval.Start.Before(end) {
			break
		}
		if interval.Start.After(cursor) {
			free = append(free, Slot{cursor, interval.Start})
		}
		cursor = interval.End
		if !cursor.Before(end) {
			return free
		}
	}
	if cursor.Before(end) {
		free = append(free, Slot{cursor, end})
	}
	return free
}
