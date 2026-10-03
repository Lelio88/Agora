package assistant

import (
	"context"
	"errors"
	"time"
)

// Store est ce que les outils lisent et écrivent, toujours AU NOM d'un membre :
// l'implémentation (PgStore) passe par la RLS et les RPC de l'application,
// jamais par un accès privilégié. Un outil ne voit donc que ce que l'app
// montrerait à ce membre.
type Store interface {
	// Profile lit le fuseau du membre.
	Profile(ctx context.Context, userID string) (Profile, error)
	// Groups liste ses groupes, avec leurs membres.
	Groups(ctx context.Context, userID string) ([]Group, error)
	// Calendars liste ses agendas et ceux de ses groupes.
	Calendars(ctx context.Context, userID string) ([]Calendar, error)
	// MyAgenda lit public.my_agenda sur [from, to[.
	MyAgenda(ctx context.Context, userID string, from, to time.Time) ([]Entry, error)
	// GroupAgenda lit public.group_agenda : la règle de visibilité s'applique.
	GroupAgenda(ctx context.Context, userID, groupID string, from, to time.Time) ([]GroupEntry, error)
	// CreateEvent insère un rdv ponctuel et rend son identifiant.
	CreateEvent(ctx context.Context, userID string, draft Draft) (string, error)
	// Respond appelle public.respond_to_event ; status vide efface la réponse.
	Respond(ctx context.Context, userID, eventID string, occurrence *time.Time, status string) error
}

// Refus nommés des fonctions SQL, traduits par PgStore.
var (
	ErrNotMember         = errors.New("assistant: pas membre du groupe")
	ErrInvalidRange      = errors.New("assistant: plage invalide")
	ErrEventNotFound     = errors.New("assistant: rdv introuvable")
	ErrInvalidOccurrence = errors.New("assistant: occurrence invalide")
	ErrForbidden         = errors.New("assistant: geste refusé par les droits")
	ErrInvalidValue      = errors.New("assistant: valeur refusée par la base")
)

// Profile porte ce que les outils lisent du profil.
type Profile struct {
	Timezone string
}

// Member est un membre d'un groupe.
type Member struct {
	UserID string
	Name   string
	Role   string
}

// Group est un groupe du membre, avec son rôle et son partage.
type Group struct {
	ID          string
	Name        string
	Description string
	MyRole      string
	MyShare     string
	Members     []Member
}

// Calendar est un agenda que le membre peut lire : le sien (Personal), ou
// celui d'un de ses groupes (GroupID).
type Calendar struct {
	ID        string
	Name      string
	GroupID   string
	Personal  bool
	Native    bool
	CreatedAt time.Time
}

// Entry est une ligne de public.my_agenda.
type Entry struct {
	EventID       string
	SeriesID      string
	OriginalStart *time.Time
	CalendarID    string
	Title         string
	Location      string
	Description   string
	Start         time.Time
	End           time.Time
	AllDay        bool
	Rrule         string
	MyResponse    string
}

// GroupEntry est une ligne de public.group_agenda, déjà masquée par la règle
// de visibilité : un créneau « busy » n'a ni titre, ni lieu, ni identifiant.
type GroupEntry struct {
	EventID      string
	UserID       string
	IsGroupEvent bool
	Level        string
	Title        string
	Location     string
	Start        time.Time
	End          time.Time
	AllDay       bool
}

// Draft est un rdv ponctuel à créer.
type Draft struct {
	CalendarID  string
	Title       string
	Location    string
	Description string
	Start       time.Time
	End         time.Time
	AllDay      bool
	Timezone    string
}
