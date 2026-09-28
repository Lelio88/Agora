package discord

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"testing"
	"time"
)

// fakeStore rend des réponses fixées et note ce qu'on lui demande.
type fakeStore struct {
	accounts     map[string]Account
	channels     map[string]Group
	linkErr      error
	linked       []string
	unlinkName   string
	unlinkErr    error
	groupAgenda  []AgendaItem
	groupErr     error
	agendaCalls  []string
	members      []Member
	personal     []PersonalItem
	recaps       []Recap
	recapAgenda  []AgendaItem
	reminders    []Reminder
	failAccounts bool
}

func (f *fakeStore) Account(_ context.Context, id string) (Account, bool, error) {
	if f.failAccounts {
		return Account{}, false, errors.New("base injoignable")
	}
	a, ok := f.accounts[id]
	return a, ok, nil
}

func (f *fakeStore) LinkChannel(_ context.Context, code, _, channel, _, _ string) (string, error) {
	if f.linkErr != nil {
		return "", f.linkErr
	}
	f.linked = append(f.linked, code+"@"+channel)
	return "Potes", nil
}

func (f *fakeStore) UnlinkChannel(context.Context, string, string) (string, bool, error) {
	if f.unlinkErr != nil {
		return "", false, f.unlinkErr
	}
	return f.unlinkName, f.unlinkName != "", nil
}

func (f *fakeStore) ChannelGroup(_ context.Context, channel string) (Group, bool, error) {
	g, ok := f.channels[channel]
	return g, ok, nil
}

func (f *fakeStore) GroupAgenda(_ context.Context, group, user string, _, _ time.Time) ([]AgendaItem, error) {
	f.agendaCalls = append(f.agendaCalls, group+"/"+user)
	return f.groupAgenda, f.groupErr
}

func (f *fakeStore) GroupMembers(context.Context, string, string) ([]Member, error) {
	return f.members, f.groupErr
}

func (f *fakeStore) PersonalAgenda(context.Context, string, time.Time, time.Time) ([]PersonalItem, error) {
	return f.personal, nil
}

func (f *fakeStore) ClaimRecaps(context.Context) ([]Recap, error) { return f.recaps, nil }

func (f *fakeStore) RecapAgenda(context.Context, string, time.Time, time.Time) ([]AgendaItem, error) {
	return f.recapAgenda, nil
}

func (f *fakeStore) ClaimReminders(context.Context) ([]Reminder, error) { return f.reminders, nil }

func silent() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

// Lundi 5 octobre 2026, 10 h à Paris.
var monday = time.Date(2026, 10, 5, 10, 0, 0, 0, paris)

func newTestBot(store *fakeStore) *Bot {
	return NewBot(store, func() time.Time { return monday }, silent())
}

const manage = "16"

func linkedStore() *fakeStore {
	return &fakeStore{
		accounts: map[string]Account{"ada": {UserID: "u-ada", Timezone: "Europe/Paris", Locale: "fr"}},
		channels: map[string]Group{"salon": {ID: "g-potes", Name: "Potes"}},
	}
}

func TestLinkRequiresAChannelAndTheRightToManageIt(t *testing.T) {
	tests := []struct {
		name string
		in   Interaction
	}{
		{name: "in a direct message", in: Interaction{Command: "relier", UserID: "ada", Locale: "fr", Permissions: manage}},
		{name: "without manage channels", in: Interaction{Command: "relier", UserID: "ada", GuildID: "1", ChannelID: "salon", Locale: "fr", Permissions: "0"}},
		{name: "with unreadable permissions", in: Interaction{Command: "relier", UserID: "ada", GuildID: "1", ChannelID: "salon", Locale: "fr", Permissions: "abc"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := linkedStore()
			newTestBot(store).link(context.Background(), tt.in)
			if len(store.linked) != 0 {
				t.Fatalf("le salon n'aurait pas dû être relié : %v", store.linked)
			}
		})
	}
}

func TestLinkTranslatesEachRefusal(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want string
	}{
		{name: "account not linked", err: ErrNotLinked, want: "Profil → Discord"},
		{name: "code invalid", err: ErrCodeInvalid, want: "inconnu, expiré"},
		{name: "not an admin", err: ErrNotAdmin, want: "Seul un admin"},
		{name: "channel taken", err: ErrChannelTaken, want: "/delier"},
		{name: "unexpected failure", err: errors.New("panne"), want: "n'a pas pu répondre"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := linkedStore()
			store.linkErr = tt.err
			in := Interaction{Command: "relier", UserID: "ada", GuildID: "1", ChannelID: "salon",
				Locale: "fr", Permissions: manage, Options: map[string]string{"code": "ABC"}}
			got := newTestBot(store).link(context.Background(), in).Content
			if !strings.Contains(got, tt.want) {
				t.Fatalf("réponse = %q, attendu %q", got, tt.want)
			}
		})
	}
}

func TestLinkAcceptsAnAdministrator(t *testing.T) {
	store := linkedStore()
	in := Interaction{Command: "relier", UserID: "ada", GuildID: "1", ChannelID: "salon",
		Locale: "en-US", Permissions: "8", Options: map[string]string{"code": "ABC"}}
	got := newTestBot(store).link(context.Background(), in).Content
	if len(store.linked) != 1 || !strings.Contains(got, `"Potes"`) {
		t.Fatalf("liaison = %v, réponse %q", store.linked, got)
	}
}

func TestAgendaInALinkedChannelReadsAsTheRequester(t *testing.T) {
	store := linkedStore()
	store.groupAgenda = []AgendaItem{
		{UserID: "u-ben", DisplayName: "Ben", Level: "busy",
			Start: time.Date(2026, 10, 5, 16, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 5, 17, 0, 0, 0, time.UTC)},
		{IsGroupEvent: true, Level: "details", Title: "Resto", Location: "Chez Paul",
			Start: time.Date(2026, 10, 6, 17, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 6, 20, 0, 0, 0, time.UTC)},
	}
	in := Interaction{Command: "agenda", UserID: "ada", GuildID: "1", ChannelID: "salon", Locale: "fr"}
	got := newTestBot(store).agenda(context.Background(), in).Content

	if len(store.agendaCalls) != 1 || store.agendaCalls[0] != "g-potes/u-ada" {
		t.Fatalf("lecture = %v, attendu au nom de u-ada", store.agendaCalls)
	}
	for _, want := range []string{"**lun. 5 oct.**", "18:00–19:00 · Ben : occupé", "rdv du groupe : Resto (Chez Paul)"} {
		if !strings.Contains(got, want) {
			t.Errorf("réponse sans %q :\n%s", want, got)
		}
	}
}

func TestAgendaTellsANonMemberWhichGroupTheChannelServes(t *testing.T) {
	store := linkedStore()
	store.groupErr = ErrNotMember
	in := Interaction{Command: "agenda", UserID: "ada", GuildID: "1", ChannelID: "salon", Locale: "fr"}
	got := newTestBot(store).agenda(context.Background(), in).Content
	if !strings.Contains(got, "dont tu n'es pas membre") {
		t.Fatalf("réponse = %q", got)
	}
}

func TestAgendaOutsideALinkedChannelShowsTheRequestersOwn(t *testing.T) {
	store := linkedStore()
	store.personal = []PersonalItem{{Title: "Kiné", GroupName: "",
		Start: time.Date(2026, 10, 5, 12, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 5, 13, 0, 0, 0, time.UTC)}}
	in := Interaction{Command: "agenda", UserID: "ada", Locale: "fr"}
	got := newTestBot(store).agenda(context.Background(), in).Content
	if len(store.agendaCalls) != 0 || !strings.Contains(got, "Ton agenda") || !strings.Contains(got, "14:00–15:00 · Kiné") {
		t.Fatalf("réponse = %q", got)
	}
}

func TestAgendaAsksToLinkAnUnknownAccount(t *testing.T) {
	got := newTestBot(linkedStore()).agenda(context.Background(),
		Interaction{Command: "agenda", UserID: "inconnu", Locale: "en"}).Content
	if !strings.Contains(got, "Profile → Discord") {
		t.Fatalf("réponse = %q", got)
	}
}

func TestAgendaSurvivesAStoreFailure(t *testing.T) {
	store := linkedStore()
	store.failAccounts = true
	got := newTestBot(store).agenda(context.Background(), Interaction{Command: "agenda", UserID: "ada", Locale: "fr"}).Content
	if !strings.Contains(got, "n'a pas pu répondre") || strings.Contains(got, "base injoignable") {
		t.Fatalf("réponse = %q : ni silence ni détail interne", got)
	}
}

func TestFreeListsSlotsForEveryMember(t *testing.T) {
	store := linkedStore()
	store.members = []Member{{UserID: "u-ada"}, {UserID: "u-ben"}}
	// Ben est pris toute la soirée du lundi.
	store.groupAgenda = []AgendaItem{{UserID: "u-ben", Level: "busy",
		Start: time.Date(2026, 10, 5, 16, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 5, 20, 0, 0, 0, time.UTC)}}
	in := Interaction{Command: "dispo", UserID: "ada", GuildID: "1", ChannelID: "salon", Locale: "fr",
		Options: map[string]string{"duree": "60", "jours": "1", "debut": "18", "fin": "22"}}
	got := newTestBot(store).free(context.Background(), in).Content
	if !strings.Contains(got, "Aucun sur cette période") {
		t.Fatalf("réponse = %q", got)
	}

	in.Options["jours"] = "2"
	got = newTestBot(store).free(context.Background(), in).Content
	if !strings.Contains(got, "mar. 6 oct. 18:00–22:00") || strings.Contains(got, "lun. 5 oct.") {
		t.Fatalf("réponse = %q", got)
	}
}

func TestFreeNeedsALinkedChannel(t *testing.T) {
	got := newTestBot(linkedStore()).free(context.Background(),
		Interaction{Command: "dispo", UserID: "ada", Locale: "fr"}).Content
	if !strings.Contains(got, "salon relié") {
		t.Fatalf("réponse = %q", got)
	}
}

func TestUnlinkRequiresTheRightToManageTheChannel(t *testing.T) {
	store := linkedStore()
	store.unlinkName = "Potes"
	bot := newTestBot(store)
	denied := bot.unlink(context.Background(), Interaction{Command: "delier", GuildID: "1", ChannelID: "salon", Locale: "fr", Permissions: "0"})
	done := bot.unlink(context.Background(), Interaction{Command: "delier", GuildID: "1", ChannelID: "salon", Locale: "fr", Permissions: manage})
	if !strings.Contains(denied.Content, "Il faut pouvoir gérer") || !strings.Contains(done.Content, "délié") {
		t.Fatalf("refus = %q, succès = %q", denied.Content, done.Content)
	}
}

func TestUnlinkIsRefusedToWhoIsNotAnAdminOfTheGroup(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want string
	}{
		{name: "account not linked", err: ErrNotLinked, want: "Profil → Discord"},
		{name: "not an admin", err: ErrNotAdmin, want: "Seul un admin du groupe peut délier"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := linkedStore()
			store.unlinkErr = tt.err
			got := newTestBot(store).unlink(context.Background(), Interaction{Command: "delier",
				UserID: "cyd", GuildID: "1", ChannelID: "salon", Locale: "fr", Permissions: manage}).Content
			if !strings.Contains(got, tt.want) {
				t.Fatalf("réponse = %q, attendu %q", got, tt.want)
			}
		})
	}
}

func TestPlainNeutralisesFreeText(t *testing.T) {
	got := plain("**gras** [lien](https://x.y)\n@everyone")
	if strings.Contains(got, "\n") || strings.Contains(got, "**") || strings.Contains(got, "[lien]") {
		t.Fatalf("texte non neutralisé : %q", got)
	}
}

func TestLinesStaysUnderDiscordsLimit(t *testing.T) {
	body := make([]string, 200)
	for i := range body {
		body[i] = strings.Repeat("x", 40)
	}
	got := lines("en-tête", body, "fr")
	if len(got) > 2000 || !strings.Contains(got, "autres.") {
		t.Fatalf("longueur %d, fin %q", len(got), got[len(got)-30:])
	}
}
