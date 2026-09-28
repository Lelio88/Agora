package discord

import (
	"context"
	"errors"
	"time"
)

// Refus de la base, traduits en messages pour le demandeur. Aucun ne porte
// de détail : le code SQL suffit à choisir la phrase.
var (
	// ErrNotLinked : le compte Discord n'est relié à aucun compte Agora.
	ErrNotLinked = errors.New("discord: compte non relié")
	// ErrCodeInvalid : code de liaison inconnu, expiré ou déjà utilisé.
	ErrCodeInvalid = errors.New("discord: code de liaison invalide")
	// ErrNotAdmin : il faut être admin du groupe pour y relier un salon.
	ErrNotAdmin = errors.New("discord: pas admin du groupe")
	// ErrChannelTaken : le salon est déjà relié à un autre groupe.
	ErrChannelTaken = errors.New("discord: salon déjà relié")
	// ErrNotMember : le demandeur n'est pas membre du groupe du salon.
	ErrNotMember = errors.New("discord: pas membre du groupe")
)

// Account est le compte Agora d'un demandeur.
type Account struct {
	UserID   string
	Timezone string
	Locale   string
}

// Group est le groupe relié à un salon.
type Group struct {
	ID   string
	Name string
}

// AgendaItem est un créneau de l'agenda d'un groupe, APRÈS la règle de vie
// privée (private.resolve_group_agenda) : Title et Location sont vides à un
// niveau autre que « details ».
type AgendaItem struct {
	// UserID est vide pour un rdv du groupe.
	UserID       string
	DisplayName  string
	IsGroupEvent bool
	Level        string
	Title        string
	Location     string
	Start        time.Time
	End          time.Time
	AllDay       bool
}

// PersonalItem est un rdv de l'agenda du demandeur lui-même.
type PersonalItem struct {
	Title    string
	Location string
	// GroupName est vide pour un rdv d'un agenda personnel.
	GroupName string
	Start     time.Time
	End       time.Time
	AllDay    bool
}

// Member est un membre du groupe, pour /dispo.
type Member struct {
	UserID      string
	DisplayName string
}

// Recap est un récap réclamé : il est déjà marqué publié.
type Recap struct {
	GroupID   string
	GroupName string
	ChannelID string
	Timezone  string
	Locale    string
	// Kind vaut « daily » ou « weekly ».
	Kind string
	Slot time.Time
}

// Reminder est un rappel réclamé d'un rdv du groupe.
type Reminder struct {
	ChannelID string
	Timezone  string
	Locale    string
	GroupName string
	Title     string
	Location  string
	Start     time.Time
	End       time.Time
}

// Store est le contrat du bot avec la base : les fonctions private.discord_*,
// seules accessibles au rôle agora_worker.
type Store interface {
	// Account rend le compte relié à un identifiant Discord ; ok est faux
	// pour un compte non relié.
	Account(ctx context.Context, discordID string) (account Account, ok bool, err error)
	// LinkChannel relie un salon au groupe du code et rend le nom du groupe.
	LinkChannel(ctx context.Context, code, guildID, channelID, channelName, discordID string) (string, error)
	// UnlinkChannel délie un salon, pour un admin relié du groupe
	// (ErrNotLinked, ErrNotAdmin) ; ok est faux s'il n'était pas relié.
	UnlinkChannel(ctx context.Context, channelID, discordID string) (groupName string, ok bool, err error)
	// ChannelGroup rend le groupe d'un salon ; ok est faux s'il n'est pas relié.
	ChannelGroup(ctx context.Context, channelID string) (group Group, ok bool, err error)
	// GroupAgenda lit l'agenda du groupe au nom d'un membre (ErrNotMember).
	GroupAgenda(ctx context.Context, groupID, userID string, from, to time.Time) ([]AgendaItem, error)
	// GroupMembers liste les membres, pour un membre (ErrNotMember).
	GroupMembers(ctx context.Context, groupID, userID string) ([]Member, error)
	// PersonalAgenda lit l'agenda d'une personne.
	PersonalAgenda(ctx context.Context, userID string, from, to time.Time) ([]PersonalItem, error)
	// ClaimRecaps réclame les récaps dus.
	ClaimRecaps(ctx context.Context) ([]Recap, error)
	// RecapAgenda lit ce qu'un récap public publie (rdv perso « occupé »).
	RecapAgenda(ctx context.Context, groupID string, from, to time.Time) ([]AgendaItem, error)
	// ClaimReminders réclame les rappels dus.
	ClaimReminders(ctx context.Context) ([]Reminder, error)
}
