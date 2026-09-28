package discord

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"strconv"
	"time"
)

// Bot porte les commandes : /relier, /delier, /agenda, /dispo. Chaque
// réponse est éphémère (Handler) et ne montre au demandeur que ce que l'app
// lui montrerait : les lectures passent par Store, donc par
// private.resolve_group_agenda à son nom.
type Bot struct {
	store  Store
	now    func() time.Time
	logger *slog.Logger
}

// NewBot construit le bot.
func NewBot(store Store, now func() time.Time, logger *slog.Logger) *Bot {
	if now == nil {
		now = time.Now
	}
	return &Bot{store: store, now: now, logger: logger}
}

// Commands rend les commandes à monter sur le Handler, par nom.
func (b *Bot) Commands() map[string]CommandFunc {
	return map[string]CommandFunc{
		"relier": b.link,
		"delier": b.unlink,
		"agenda": b.agenda,
		"dispo":  b.free,
	}
}

const (
	// Rang des droits Discord « administrateur » et « gérer les salons ».
	bitAdministrator  = 3
	bitManageChannels = 4

	defaultAgendaDays = 7
	maxAgendaDays     = 31
	defaultFreeDays   = 7
	maxFreeDays       = 14
	maxFreeShown      = 15
)

// canManageChannels relit les droits que Discord a calculés : la commande
// n'est proposée qu'à qui peut gérer le salon, mais un serveur peut
// modifier ce réglage — le worker ne s'y fie donc pas.
func canManageChannels(permissions string) bool {
	bits, ok := new(big.Int).SetString(permissions, 10)
	if !ok {
		return false
	}
	return bits.Bit(bitAdministrator) == 1 || bits.Bit(bitManageChannels) == 1
}

func (b *Bot) failed(in Interaction, err error) Reply {
	b.logger.Error("discord command", "command", in.Command, "err", err)
	return Reply{Content: Text(in.Locale,
		"Agora n'a pas pu répondre. Réessaie dans un instant.",
		"Agora could not answer. Try again in a moment.")}
}

func notLinked(locale string) Reply {
	return Reply{Content: Text(locale,
		"Ton compte Discord n'est pas relié à Agora. Dans l'app : Profil → Discord → Relier.",
		"Your Discord account is not linked to Agora. In the app: Profile → Discord → Link.")}
}

func (b *Bot) link(ctx context.Context, in Interaction) Reply {
	if in.GuildID == "" {
		return Reply{Content: Text(in.Locale,
			"Tape cette commande dans le salon à relier.",
			"Type this command in the channel to link.")}
	}
	if !canManageChannels(in.Permissions) {
		return Reply{Content: Text(in.Locale,
			"Il faut pouvoir gérer ce salon pour le relier.",
			"You need to be able to manage this channel to link it.")}
	}
	name, err := b.store.LinkChannel(ctx, in.Options["code"], in.GuildID, in.ChannelID, in.ChannelName, in.UserID)
	switch {
	case errors.Is(err, ErrNotLinked):
		return notLinked(in.Locale)
	case errors.Is(err, ErrCodeInvalid):
		return Reply{Content: Text(in.Locale,
			"Ce code est inconnu, expiré ou déjà utilisé. Crée-en un nouveau dans l'app.",
			"This code is unknown, expired or already used. Create a new one in the app.")}
	case errors.Is(err, ErrNotAdmin):
		return Reply{Content: Text(in.Locale,
			"Seul un admin du groupe peut y relier un salon.",
			"Only an admin of the group can link a channel to it.")}
	case errors.Is(err, ErrChannelTaken):
		return Reply{Content: Text(in.Locale,
			"Ce salon est déjà relié à un autre groupe. Tape d'abord /delier.",
			"This channel is already linked to another group. Type /unlink first.")}
	case err != nil:
		return b.failed(in, err)
	}
	return Reply{Content: Text(in.Locale,
		fmt.Sprintf("Salon relié au groupe « %s ». Les réglages des récaps et rappels sont dans l'app.", plain(name)),
		fmt.Sprintf("Channel linked to the group \"%s\". Recaps and reminders are set in the app.", plain(name)))}
}

func (b *Bot) unlink(ctx context.Context, in Interaction) Reply {
	if in.GuildID == "" || !canManageChannels(in.Permissions) {
		return Reply{Content: Text(in.Locale,
			"Il faut pouvoir gérer ce salon pour le délier.",
			"You need to be able to manage this channel to unlink it.")}
	}
	name, ok, err := b.store.UnlinkChannel(ctx, in.ChannelID, in.UserID)
	switch {
	case errors.Is(err, ErrNotLinked):
		return notLinked(in.Locale)
	case errors.Is(err, ErrNotAdmin):
		return Reply{Content: Text(in.Locale,
			"Seul un admin du groupe peut délier ce salon.",
			"Only an admin of the group can unlink this channel.")}
	case err != nil:
		return b.failed(in, err)
	}
	if !ok {
		return Reply{Content: Text(in.Locale, "Ce salon n'est relié à aucun groupe.",
			"This channel is not linked to any group.")}
	}
	return Reply{Content: Text(in.Locale,
		fmt.Sprintf("Salon délié du groupe « %s ».", plain(name)),
		fmt.Sprintf("Channel unlinked from the group \"%s\".", plain(name)))}
}

// intOption lit une option entière, bornée, avec sa valeur par défaut.
func intOption(in Interaction, name string, fallback, low, high int) int {
	raw, ok := in.Options[name]
	if !ok {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return min(max(v, low), high)
}

// channelGroup rend le groupe du salon, s'il y en a un.
func (b *Bot) channelGroup(ctx context.Context, in Interaction) (Group, bool, error) {
	if in.GuildID == "" {
		return Group{}, false, nil
	}
	return b.store.ChannelGroup(ctx, in.ChannelID)
}

func (b *Bot) agenda(ctx context.Context, in Interaction) Reply {
	account, ok, err := b.store.Account(ctx, in.UserID)
	if err != nil {
		return b.failed(in, err)
	}
	if !ok {
		return notLinked(in.Locale)
	}
	loc := location(account.Timezone)
	days := intOption(in, "jours", defaultAgendaDays, 1, maxAgendaDays)
	now := b.now().In(loc)
	to := time.Date(now.Year(), now.Month(), now.Day()+days, 0, 0, 0, 0, loc)

	group, inGroup, err := b.channelGroup(ctx, in)
	if err != nil {
		return b.failed(in, err)
	}
	if inGroup {
		items, err := b.store.GroupAgenda(ctx, group.ID, account.UserID, now, to)
		if errors.Is(err, ErrNotMember) {
			return notMember(in.Locale, group.Name)
		}
		if err != nil {
			return b.failed(in, err)
		}
		header := Text(in.Locale,
			fmt.Sprintf("Agenda du groupe « %s », %d jours :", plain(group.Name), days),
			fmt.Sprintf("Agenda of the group \"%s\", %d days:", plain(group.Name), days))
		if len(items) == 0 {
			return Reply{Content: header + "\n" + nothing(in.Locale)}
		}
		return Reply{Content: lines(header, agendaLines(items, loc, in.Locale), in.Locale)}
	}

	items, err := b.store.PersonalAgenda(ctx, account.UserID, now, to)
	if err != nil {
		return b.failed(in, err)
	}
	header := Text(in.Locale,
		fmt.Sprintf("Ton agenda, %d jours :", days),
		fmt.Sprintf("Your agenda, %d days:", days))
	if len(items) == 0 {
		return Reply{Content: header + "\n" + nothing(in.Locale)}
	}
	return Reply{Content: lines(header, personalLines(items, loc, in.Locale), in.Locale)}
}

func nothing(locale string) string {
	return Text(locale, "Rien de prévu.", "Nothing planned.")
}

func notMember(locale, group string) Reply {
	return Reply{Content: Text(locale,
		fmt.Sprintf("Ce salon est relié au groupe « %s », dont tu n'es pas membre.", plain(group)),
		fmt.Sprintf("This channel is linked to the group \"%s\", which you are not a member of.", plain(group)))}
}

func (b *Bot) free(ctx context.Context, in Interaction) Reply {
	group, inGroup, err := b.channelGroup(ctx, in)
	if err != nil {
		return b.failed(in, err)
	}
	if !inGroup {
		return Reply{Content: Text(in.Locale,
			"Cette commande se tape dans un salon relié à un groupe.",
			"Type this command in a channel linked to a group.")}
	}
	account, ok, err := b.store.Account(ctx, in.UserID)
	if err != nil {
		return b.failed(in, err)
	}
	if !ok {
		return notLinked(in.Locale)
	}
	members, err := b.store.GroupMembers(ctx, group.ID, account.UserID)
	if errors.Is(err, ErrNotMember) {
		return notMember(in.Locale, group.Name)
	}
	if err != nil {
		return b.failed(in, err)
	}

	loc := location(account.Timezone)
	now := b.now().In(loc)
	days := intOption(in, "jours", defaultFreeDays, 1, maxFreeDays)
	search := SlotSearch{
		Location: loc,
		From:     now,
		To:       time.Date(now.Year(), now.Month(), now.Day()+days, 0, 0, 0, 0, loc),
		Duration: time.Duration(intOption(in, "duree", 60, 15, 24*60)) * time.Minute,
		DayStart: time.Duration(intOption(in, "debut", 9, 0, 23)) * time.Hour,
		DayEnd:   time.Duration(intOption(in, "fin", 22, 1, 24)) * time.Hour,
		Weekdays: everyWeekday(in.Options["weekend"] != "false"),
		Members:  make(map[string]bool, len(members)),
	}
	for _, m := range members {
		search.Members[m.UserID] = true
	}
	// Depuis minuit : un rdv commencé avant « maintenant » prend encore le créneau.
	dayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	agenda, err := b.store.GroupAgenda(ctx, group.ID, account.UserID, dayStart, search.To)
	if err != nil {
		return b.failed(in, err)
	}

	slots := FindFreeSlots(search, agenda)
	header := Text(in.Locale,
		fmt.Sprintf("Créneaux libres pour tout le groupe « %s » (%d min au moins) :", plain(group.Name), search.Duration/time.Minute),
		fmt.Sprintf("Free slots for the whole group \"%s\" (at least %d min):", plain(group.Name), search.Duration/time.Minute))
	if len(slots) == 0 {
		return Reply{Content: header + "\n" + Text(in.Locale, "Aucun sur cette période.", "None in this period.")}
	}
	body := make([]string, 0, maxFreeShown+1)
	for i, s := range slots {
		if i == maxFreeShown {
			body = append(body, Text(in.Locale,
				fmt.Sprintf("… et %d autres, dans l'app.", len(slots)-i),
				fmt.Sprintf("… and %d more, in the app.", len(slots)-i)))
			break
		}
		body = append(body, "• "+dayLabel(s.Start, in.Locale)+" "+hours(s.Start, s.End, false, in.Locale))
	}
	body = append(body, Text(in.Locale,
		"_Un membre qui ne partage rien avec le groupe paraît libre._",
		"_A member who shares nothing with the group looks free._"))
	return Reply{Content: lines(header, body, in.Locale)}
}

func everyWeekday(weekends bool) map[time.Weekday]bool {
	days := map[time.Weekday]bool{}
	for d := time.Sunday; d <= time.Saturday; d++ {
		if weekends || (d != time.Saturday && d != time.Sunday) {
			days[d] = true
		}
	}
	return days
}
