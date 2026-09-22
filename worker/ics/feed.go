// Package ics relit les agendas importés par lien iCal : il télécharge
// chaque flux dû, le lit et le confie à la base, qui l'applique en une
// transaction (private.ics_apply).
//
// Choix non évidents :
//   - l'URL d'un flux est un secret (elle donne accès à tout l'agenda
//     d'origine) : elle ne figure dans aucun journal ni aucune erreur. Feed
//     ne s'affiche que par son agenda, et un échec n'est qu'un code connu
//     (Failure), jamais le texte d'une erreur réseau, qui contient l'URL ;
//   - le SSRF se contrôle sur l'adresse RÉSOLUE, au moment de chaque
//     connexion (redirections comprises) : un nom qui résout vers le réseau
//     interne, ou qui change de réponse entre deux résolutions, est refusé ;
//   - la lecture est bornée partout (taille, nombre de rdv, longueur des
//     textes, temps passé sur les règles de répétition) : un flux est une
//     donnée hostile.
//
// Invariants : la base est la seule à écrire les rdv importés (ics_apply) ;
// ce paquet n'écrit jamais events.visibility.
package ics

import (
	"fmt"
	"log/slog"
	"time"
)

// Channel est le canal NOTIFY qui réveille la relecture : nouveau flux, ou
// « Synchroniser maintenant ». La charge utile (l'agenda) est indicative :
// la relecture prend tous les flux dus.
const Channel = "agora_ics"

// Feed est un flux à relire.
type Feed struct {
	CalendarID   string
	URL          string
	ETag         string
	LastModified string
}

// String, Format et LogValue n'exposent que l'agenda : un Feed imprimé (quel
// que soit le verbe, %#v compris) ou journalisé par mégarde ne livre pas son
// URL.
func (f Feed) String() string { return "feed(" + f.CalendarID + ")" }

// Format sert tous les verbes de fmt.
func (f Feed) Format(s fmt.State, _ rune) { _, _ = s.Write([]byte(f.String())) }

// LogValue sert slog.
func (f Feed) LogValue() slog.Value { return slog.StringValue(f.CalendarID) }

// Failure est l'échec d'une relecture, par un code que la base connaît
// (private.ics_record_failure) et que l'app traduit.
type Failure string

const (
	FailureUnreachable    Failure = "unreachable"
	FailureTimeout        Failure = "timeout"
	FailureNotFound       Failure = "not_found"
	FailureForbidden      Failure = "forbidden"
	FailureHTTP           Failure = "http_error"
	FailureTooLarge       Failure = "too_large"
	FailureNotCalendar    Failure = "not_calendar"
	FailureBlockedAddress Failure = "blocked_address"
	FailureTooManyEvents  Failure = "too_many_events"
)

func (f Failure) Error() string { return "ics: " + string(f) }

// Event est une ligne du flux, au format attendu par private.ics_rows :
// textes déjà tronqués, instants en UTC.
type Event struct {
	UID          string      `json:"uid"`
	RecurrenceID *time.Time  `json:"recurrence_id"`
	Title        string      `json:"title"`
	Description  *string     `json:"description"`
	Location     *string     `json:"location"`
	StartsAt     time.Time   `json:"starts_at"`
	EndsAt       time.Time   `json:"ends_at"`
	AllDay       bool        `json:"all_day"`
	Timezone     string      `json:"timezone"`
	RRule        *string     `json:"rrule"`
	Exdates      []time.Time `json:"exdates"`
}
