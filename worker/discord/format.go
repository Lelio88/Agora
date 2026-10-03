package discord

import (
	"fmt"
	"strings"
	"time"

	"github.com/Lelio88/agora/worker/slots"
)

// Mise en forme des messages du bot : dates dans la langue et le fuseau du
// lecteur, texte libre neutralisé, longueur bornée.

// maxContent reste sous la limite de 2 000 caractères d'un message Discord.
const maxContent = 1900

var (
	frDays   = [...]string{"dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."}
	frMonths = [...]string{"janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."}
)

// dayLabel rend « lun. 5 oct. » ou « Mon 5 Oct ».
func dayLabel(t time.Time, locale string) string {
	if isFrench(locale) {
		return fmt.Sprintf("%s %d %s", frDays[t.Weekday()], t.Day(), frMonths[t.Month()-1])
	}
	return t.Format("Mon 2 Jan")
}

// hours rend « 18:00–20:00 », ou « journée » / « all day ».
func hours(start, end time.Time, allDay bool, locale string) string {
	if allDay {
		return Text(locale, "journée", "all day")
	}
	return start.Format("15:04") + "–" + end.Format("15:04")
}

func isFrench(locale string) bool {
	return len(locale) >= 2 && locale[:2] == "fr"
}

// location rend le fuseau IANA, Paris à défaut (un profil porte toujours
// un fuseau validé ; le défaut ne protège que d'une valeur inattendue).
func location(name string) *time.Location {
	if loc, err := time.LoadLocation(name); err == nil {
		return loc
	}
	if loc, err := time.LoadLocation("Europe/Paris"); err == nil {
		return loc
	}
	return time.UTC
}

// markdown liste les caractères que Discord interprète.
var markdown = strings.NewReplacer(
	`\`, `\\`, "*", `\*`, "_", `\_`, "~", `\~`, "`", "\\`",
	"|", `\|`, ">", `\>`, "[", `\[`, "]", `\]`, "#", `\#`,
)

// plain neutralise un texte libre (titre, lieu, nom) : ni mise en forme, ni
// lien masqué, ni saut de ligne. Les mentions, elles, sont coupées par
// allowed_mentions.
func plain(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	return markdown.Replace(s)
}

// lines assemble un message, coupé proprement s'il dépasse la limite.
func lines(header string, body []string, locale string) string {
	var b strings.Builder
	b.WriteString(header)
	for i, line := range body {
		if b.Len()+len(line)+1 > maxContent {
			fmt.Fprintf(&b, "\n%s", Text(locale,
				fmt.Sprintf("… et %d autres.", len(body)-i),
				fmt.Sprintf("… and %d more.", len(body)-i)))
			break
		}
		b.WriteString("\n")
		b.WriteString(line)
	}
	return b.String()
}

// localDay rend le jour de calendrier d'un créneau dans loc (une journée
// entière se lit sur sa date UTC).
func localDay(start time.Time, allDay bool, loc *time.Location) time.Time {
	if allDay {
		return slots.CalendarDate(start, loc)
	}
	s := start.In(loc)
	return time.Date(s.Year(), s.Month(), s.Day(), 0, 0, 0, 0, loc)
}

// agendaLines présente l'agenda d'un groupe, jour par jour. Un créneau
// « occupé » ne montre que la personne et l'heure.
func agendaLines(items []AgendaItem, loc *time.Location, locale string) []string {
	var out []string
	var current time.Time
	for _, item := range items {
		d := localDay(item.Start, item.AllDay, loc)
		if !d.Equal(current) {
			current = d
			out = append(out, "**"+dayLabel(d, locale)+"**")
		}
		out = append(out, "• "+hours(item.Start.In(loc), item.End.In(loc), item.AllDay, locale)+" · "+describe(item, locale))
	}
	return out
}

func describe(item AgendaItem, locale string) string {
	what := Text(locale, "occupé", "busy")
	if item.Level == "details" && item.Title != "" {
		what = plain(item.Title)
		if item.Location != "" {
			what += " (" + plain(item.Location) + ")"
		}
	}
	if item.IsGroupEvent {
		return Text(locale, "rdv du groupe : ", "group event: ") + what
	}
	return plain(item.DisplayName) + " : " + what
}

// personalLines présente l'agenda d'une personne, jour par jour.
func personalLines(items []PersonalItem, loc *time.Location, locale string) []string {
	var out []string
	var current time.Time
	for _, item := range items {
		d := localDay(item.Start, item.AllDay, loc)
		if !d.Equal(current) {
			current = d
			out = append(out, "**"+dayLabel(d, locale)+"**")
		}
		line := "• " + hours(item.Start.In(loc), item.End.In(loc), item.AllDay, locale) + " · " + plain(item.Title)
		if item.Location != "" {
			line += " (" + plain(item.Location) + ")"
		}
		if item.GroupName != "" {
			line += " — " + plain(item.GroupName)
		}
		out = append(out, line)
	}
	return out
}
