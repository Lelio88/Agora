// Package recurrence déplie les rdv récurrents d'Agora : à partir de la ligne
// maîtresse d'une série (RRULE, fuseau, exceptions), il calcule les
// occurrences d'une fenêtre glissante et les écrit dans event_occurrences.
//
// C'est la SEULE implémentation des RRULE du projet : l'app, les agendas de
// groupe et plus tard /dispo lisent tous ce dépliage, pour qu'ils ne
// divergent jamais.
//
// Choix non évidents :
//   - le dépliage se fait dans le fuseau de la série : un rdv hebdomadaire à
//     18 h à Paris reste à 18 h après le changement d'heure ;
//   - un rdv « journée entière » se déplie en UTC, quel que soit son fuseau :
//     l'app le stocke à minuit UTC et l'affiche par sa date ;
//   - une série sans fin est bornée par la fenêtre, et par MaxOccurrences
//     pour qu'une règle aberrante ne remplisse pas la base.
//
// Invariant : Expand est pure (aucune E/S) ; tout accès à la base passe par
// Store.
package recurrence

import (
	"errors"
	"fmt"
	"time"

	"github.com/teambition/rrule-go"
)

// MaxOccurrences borne le nombre d'occurrences dépliées par série.
const MaxOccurrences = 2000

// ErrTooManyOccurrences signale une série tronquée à MaxOccurrences.
var ErrTooManyOccurrences = errors.New("recurrence: too many occurrences, truncated")

// Series est la ligne maîtresse d'une série, telle que la lit le worker.
type Series struct {
	ID       string
	Start    time.Time
	End      time.Time
	AllDay   bool
	Timezone string
	// RRule suit la RFC 5545, sans le préfixe « RRULE: ».
	RRule string
	// Exdates sont les créneaux d'origine des occurrences supprimées.
	Exdates []time.Time
	// ReplacedSlots sont les créneaux d'origine des occurrences modifiées :
	// ces occurrences vivent comme des rdv à part.
	ReplacedSlots []time.Time
}

// Occurrence est une instance dépliée d'une série.
type Occurrence struct {
	Start time.Time
	End   time.Time
}

// Window est l'intervalle [From, To[ des débuts d'occurrences à déplier.
type Window struct {
	From time.Time
	To   time.Time
}

// Expand déplie series sur window. En cas de dépassement de MaxOccurrences,
// renvoie les premières occurrences ET ErrTooManyOccurrences.
func Expand(series Series, window Window) ([]Occurrence, error) {
	location := time.UTC
	if !series.AllDay {
		loc, err := time.LoadLocation(series.Timezone)
		if err != nil {
			return nil, fmt.Errorf("load time zone %q: %w", series.Timezone, err)
		}
		location = loc
	}
	option, err := rrule.StrToROption(series.RRule)
	if err != nil {
		return nil, fmt.Errorf("parse rule %q: %w", series.RRule, err)
	}
	option.Dtstart = series.Start.In(location)
	rule, err := rrule.NewRRule(*option)
	if err != nil {
		return nil, fmt.Errorf("build rule %q: %w", series.RRule, err)
	}

	skipped := instantSet(series.Exdates, series.ReplacedSlots)
	duration := series.End.Sub(series.Start)
	occurrences := make([]Occurrence, 0)
	next := rule.Iterator()
	for start, ok := next(); ok && start.Before(window.To); start, ok = next() {
		if start.Before(window.From) {
			continue
		}
		if _, skip := skipped[start.UnixMicro()]; skip {
			continue
		}
		if len(occurrences) == MaxOccurrences {
			return occurrences, ErrTooManyOccurrences
		}
		occurrences = append(occurrences, Occurrence{Start: start.UTC(), End: start.Add(duration).UTC()})
	}
	return occurrences, nil
}

// instantSet indexe des instants à la microseconde, la précision de
// timestamptz : deux écritures d'un même instant se reconnaissent toujours.
func instantSet(lists ...[]time.Time) map[int64]struct{} {
	set := make(map[int64]struct{})
	for _, list := range lists {
		for _, instant := range list {
			set[instant.UnixMicro()] = struct{}{}
		}
	}
	return set
}
