package assistant

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
)

const (
	ada   = "a0000000-0000-0000-0000-0000000000a1"
	ben   = "a0000000-0000-0000-0000-0000000000b2"
	potes = "a0000000-0000-0000-0000-0000000000c3"
)

var paris = mustLoad("Europe/Paris")

func mustLoad(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic(err)
	}
	return loc
}

// Lundi 5 octobre 2026, 10 h à Paris.
var monday = time.Date(2026, 10, 5, 10, 0, 0, 0, paris)

// fakeStore est un Store en mémoire : il enregistre ce qu'on lui demande.
type fakeStore struct {
	timezone    string
	groups      []Group
	calendars   []Calendar
	agenda      []Entry
	groupAgenda []GroupEntry
	err         error

	agendaFrom, agendaTo time.Time
	drafts               []Draft
	responses            []string
}

func (f *fakeStore) Profile(context.Context, string) (Profile, error) {
	return Profile{Timezone: f.timezone}, nil
}

func (f *fakeStore) Groups(context.Context, string) ([]Group, error) { return f.groups, nil }

func (f *fakeStore) Calendars(context.Context, string) ([]Calendar, error) {
	return f.calendars, nil
}

func (f *fakeStore) MyAgenda(_ context.Context, _ string, from, to time.Time) ([]Entry, error) {
	f.agendaFrom, f.agendaTo = from, to
	return f.agenda, f.err
}

func (f *fakeStore) GroupAgenda(_ context.Context, _, _ string, from, to time.Time) ([]GroupEntry, error) {
	f.agendaFrom, f.agendaTo = from, to
	return f.groupAgenda, f.err
}

func (f *fakeStore) CreateEvent(_ context.Context, _ string, d Draft) (string, error) {
	if f.err != nil {
		return "", f.err
	}
	f.drafts = append(f.drafts, d)
	return "e0000000-0000-0000-0000-000000000001", nil
}

func (f *fakeStore) Respond(_ context.Context, _, eventID string, occurrence *time.Time, status string) error {
	if f.err != nil {
		return f.err
	}
	at := ""
	if occurrence != nil {
		at = "@" + occurrence.UTC().Format(time.RFC3339)
	}
	f.responses = append(f.responses, eventID+at+"="+status)
	return nil
}

func newFake() *fakeStore {
	return &fakeStore{
		timezone: "Europe/Paris",
		groups: []Group{{
			ID: potes, Name: "Potes", MyRole: "owner", MyShare: "details",
			Members: []Member{{UserID: ada, Name: "Ada", Role: "owner"}, {UserID: ben, Name: "Ben", Role: "member"}},
		}},
		calendars: []Calendar{
			{ID: "cal-ics", Name: "Boulot", Personal: true, Native: false, CreatedAt: monday.Add(-72 * time.Hour)},
			{ID: "cal-perso", Name: "Agenda", Personal: true, Native: true, CreatedAt: monday.Add(-48 * time.Hour)},
			{ID: "cal-potes", Name: "Potes", GroupID: potes, Native: true, CreatedAt: monday.Add(-24 * time.Hour)},
		},
	}
}

func newTestToolbox(store Store) *toolbox {
	return newToolbox(store, func() time.Time { return monday })
}

func isRefusal(err error) bool {
	var r refusal
	return errors.As(err, &r)
}

func TestFindGroup(t *testing.T) {
	groups := []Group{{ID: "g1", Name: "Potes"}, {ID: "g2", Name: "Escalade"}, {ID: "g3", Name: "escalade"}}
	tests := []struct {
		name    string
		ref     string
		want    string
		refused string
	}{
		{name: "by_id", ref: "g2", want: "g2"},
		{name: "by_exact_name_ignoring_case", ref: "potes", want: "g1"},
		{name: "unknown_lists_the_groups", ref: "Rando", refused: "« Potes »"},
		{name: "ambiguous_asks_for_the_id", ref: "ESCALADE", refused: "identifiant"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := findGroup(groups, tt.ref)
			if tt.refused != "" {
				if !isRefusal(err) || !strings.Contains(err.Error(), tt.refused) {
					t.Fatalf("findGroup(%q) err = %v, attendu un refus contenant %q", tt.ref, err, tt.refused)
				}
				return
			}
			if err != nil || got.ID != tt.want {
				t.Fatalf("findGroup(%q) = %q, %v ; attendu %q", tt.ref, got.ID, err, tt.want)
			}
		})
	}
	if _, err := findGroup(nil, "Potes"); !isRefusal(err) {
		t.Fatalf("sans groupe : err = %v", err)
	}
}

func TestParseRange(t *testing.T) {
	tests := []struct {
		name     string
		du, au   string
		from, to time.Time
		refused  bool
	}{
		{name: "defaults_to_a_week_from_midnight", from: time.Date(2026, 10, 5, 0, 0, 0, 0, paris), to: time.Date(2026, 10, 12, 0, 0, 0, 0, paris)},
		{name: "a_date_only_end_counts_whole", du: "2026-10-09", au: "2026-10-09",
			from: time.Date(2026, 10, 9, 0, 0, 0, 0, paris), to: time.Date(2026, 10, 10, 0, 0, 0, 0, paris)},
		{name: "wall_time_is_read_in_the_profile_zone", du: "2026-10-09T18:30", au: "2026-10-09T20:00",
			from: time.Date(2026, 10, 9, 18, 30, 0, 0, paris), to: time.Date(2026, 10, 9, 20, 0, 0, 0, paris)},
		{name: "an_offset_wins", du: "2026-10-09T18:30:00Z", au: "2026-10-09T20:00:00Z",
			from: time.Date(2026, 10, 9, 18, 30, 0, 0, time.UTC), to: time.Date(2026, 10, 9, 20, 0, 0, 0, time.UTC)},
		{name: "more_than_93_days_is_refused", du: "2026-10-01", au: "2027-03-01", refused: true},
		{name: "an_end_before_the_start_is_refused", du: "2026-10-09", au: "2026-10-08T12:00", refused: true},
		{name: "not_a_date_is_refused", du: "jeudi", refused: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			from, to, err := parseRange(tt.du, tt.au, monday, paris)
			if tt.refused {
				if !isRefusal(err) {
					t.Fatalf("err = %v, attendu un refus", err)
				}
				return
			}
			if err != nil || !from.Equal(tt.from) || !to.Equal(tt.to) {
				t.Fatalf("parseRange = %v, %v, %v ; attendu %v, %v", from, to, err, tt.from, tt.to)
			}
		})
	}
}

func TestEventBounds(t *testing.T) {
	tests := []struct {
		name       string
		debut, fin string
		allDay     bool
		start, end time.Time
		refused    bool
	}{
		{name: "timed_in_the_profile_zone", debut: "2026-10-09T20:00", fin: "2026-10-09T22:30",
			start: time.Date(2026, 10, 9, 18, 0, 0, 0, time.UTC), end: time.Date(2026, 10, 9, 20, 30, 0, 0, time.UTC)},
		{name: "a_single_all_day_ends_at_next_utc_midnight", debut: "2026-10-09", allDay: true,
			start: time.Date(2026, 10, 9, 0, 0, 0, 0, time.UTC), end: time.Date(2026, 10, 10, 0, 0, 0, 0, time.UTC)},
		{name: "an_all_day_span_includes_its_last_day", debut: "2026-10-09", fin: "2026-10-11", allDay: true,
			start: time.Date(2026, 10, 9, 0, 0, 0, 0, time.UTC), end: time.Date(2026, 10, 12, 0, 0, 0, 0, time.UTC)},
		{name: "a_timed_event_needs_its_end", debut: "2026-10-09T20:00", refused: true},
		{name: "an_end_before_the_start_is_refused", debut: "2026-10-09T20:00", fin: "2026-10-09T19:00", refused: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			start, end, err := eventBounds(tt.debut, tt.fin, tt.allDay, paris)
			if tt.refused {
				if !isRefusal(err) {
					t.Fatalf("err = %v, attendu un refus", err)
				}
				return
			}
			if err != nil || !start.Equal(tt.start) || !end.Equal(tt.end) {
				t.Fatalf("eventBounds = %v, %v, %v ; attendu %v, %v", start, end, err, tt.start, tt.end)
			}
		})
	}
}

func TestMyAgendaGivesReferencesNamesAndResponses(t *testing.T) {
	store := newFake()
	origin := time.Date(2026, 10, 6, 16, 0, 0, 0, time.UTC)
	store.agenda = []Entry{
		{EventID: "e1", SeriesID: "e1", OriginalStart: &origin, CalendarID: "cal-potes", Title: "Foot",
			Start: origin, End: origin.Add(time.Hour), Rrule: "FREQ=WEEKLY", MyResponse: "yes"},
		{EventID: "e2", CalendarID: "cal-perso", Title: "Dentiste",
			Start: time.Date(2026, 10, 7, 8, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 7, 9, 0, 0, 0, time.UTC)},
		{EventID: "e3", CalendarID: "cal-perso", Title: "Congés", AllDay: true,
			Start: time.Date(2026, 10, 8, 0, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 10, 0, 0, 0, 0, time.UTC)},
	}
	out, err := newTestToolbox(store).myAgenda(context.Background(), ada, RangeInput{})
	if err != nil {
		t.Fatal(err)
	}
	foot, dentiste, conges := out.Rdv[0], out.Rdv[1], out.Rdv[2]
	if foot.Rdv != "e1@2026-10-06T16:00:00Z" || foot.Groupe != "Potes" || foot.MaReponse != "present" || !foot.Recurrent {
		t.Fatalf("occurrence de série = %+v", foot)
	}
	if foot.Debut != "2026-10-06T18:00:00+02:00" {
		t.Fatalf("heure rendue dans le fuseau du profil : %q", foot.Debut)
	}
	if dentiste.Rdv != "e2" || dentiste.Agenda != "Agenda" || dentiste.Groupe != "" {
		t.Fatalf("rdv ponctuel = %+v", dentiste)
	}
	if conges.Debut != "2026-10-08" || conges.Fin != "2026-10-09" || !conges.JourneeEntiere {
		t.Fatalf("journée entière, fin comprise = %+v", conges)
	}
	if out.Fuseau != "Europe/Paris" || out.Tronque {
		t.Fatalf("fuseau %q, tronqué %v", out.Fuseau, out.Tronque)
	}
}

func TestMyAgendaIsCapped(t *testing.T) {
	store := newFake()
	for i := 0; i < maxRows+5; i++ {
		store.agenda = append(store.agenda, Entry{EventID: "e", CalendarID: "cal-perso", Start: monday, End: monday})
	}
	out, err := newTestToolbox(store).myAgenda(context.Background(), ada, RangeInput{})
	if err != nil || len(out.Rdv) != maxRows || !out.Tronque {
		t.Fatalf("%d lignes, tronqué %v, %v", len(out.Rdv), out.Tronque, err)
	}
}

func TestGroupAgendaShowsWhatTheAppShows(t *testing.T) {
	store := newFake()
	store.groupAgenda = []GroupEntry{
		{UserID: ben, Level: "busy", Start: monday, End: monday.Add(time.Hour)},
		{IsGroupEvent: true, Level: "details", Title: "Match", Location: "Stade", Start: monday, End: monday.Add(2 * time.Hour)},
	}
	out, err := newTestToolbox(store).groupAgenda(context.Background(), ada, GroupRangeInput{Groupe: "potes"})
	if err != nil {
		t.Fatal(err)
	}
	busy, match := out.Creneaux[0], out.Creneaux[1]
	if busy.Membre != "Ben" || busy.Niveau != "occupe" || busy.Titre != "" {
		t.Fatalf("créneau occupé = %+v", busy)
	}
	if !match.RdvDuGroupe || match.Niveau != "detail" || match.Titre != "Match" || match.Membre != "" {
		t.Fatalf("rdv du groupe = %+v", match)
	}
}

func TestStoreRefusalsReachTheAssistantReadable(t *testing.T) {
	store := newFake()
	store.err = ErrNotMember
	_, err := newTestToolbox(store).groupAgenda(context.Background(), ada, GroupRangeInput{Groupe: "Potes"})
	if !isRefusal(err) || !strings.Contains(err.Error(), "pas membre") {
		t.Fatalf("err = %v", err)
	}
	store.err = errors.New("connexion perdue")
	_, err = newTestToolbox(store).groupAgenda(context.Background(), ada, GroupRangeInput{Groupe: "Potes"})
	if err == nil || isRefusal(err) {
		t.Fatalf("une panne n'est pas un refus rédigé : %v", err)
	}
}

func TestFreeSlots(t *testing.T) {
	tests := []struct {
		name    string
		in      SlotsInput
		agenda  []GroupEntry
		want    string
		refused bool
	}{
		{
			name: "everyone_free_in_the_evening_window",
			in:   SlotsInput{Groupe: "Potes", DureeMinutes: 60, Du: "2026-10-06", Au: "2026-10-06", HeureDebut: "18:00", HeureFin: "22:00"},
			want: "2026-10-06T18:00:00+02:00/2026-10-06T22:00:00+02:00",
		},
		{
			name: "a_busy_member_takes_the_slot",
			in:   SlotsInput{Groupe: "Potes", DureeMinutes: 60, Du: "2026-10-06", Au: "2026-10-06", HeureDebut: "18:00", HeureFin: "22:00"},
			agenda: []GroupEntry{{UserID: ben, Level: "busy",
				Start: time.Date(2026, 10, 6, 18, 0, 0, 0, paris), End: time.Date(2026, 10, 6, 20, 0, 0, 0, paris)}},
			want: "2026-10-06T20:00:00+02:00/2026-10-06T22:00:00+02:00",
		},
		{
			name: "an_unrequired_member_does_not_count",
			in: SlotsInput{Groupe: "Potes", DureeMinutes: 60, Du: "2026-10-06", Au: "2026-10-06",
				HeureDebut: "18:00", HeureFin: "22:00", Membres: []string{"ada"}},
			agenda: []GroupEntry{{UserID: ben, Level: "busy",
				Start: time.Date(2026, 10, 6, 18, 0, 0, 0, paris), End: time.Date(2026, 10, 6, 20, 0, 0, 0, paris)}},
			want: "2026-10-06T18:00:00+02:00/2026-10-06T22:00:00+02:00",
		},
		{
			name: "the_past_is_never_offered",
			in:   SlotsInput{Groupe: "Potes", DureeMinutes: 30, Du: "2026-10-05", Au: "2026-10-05", HeureDebut: "08:00", HeureFin: "11:00"},
			want: "2026-10-05T10:00:00+02:00/2026-10-05T11:00:00+02:00",
		},
		{name: "duration_out_of_bounds", in: SlotsInput{Groupe: "Potes", DureeMinutes: 5}, refused: true},
		{name: "unknown_member", in: SlotsInput{Groupe: "Potes", DureeMinutes: 60, Membres: []string{"Zoé"}}, refused: true},
		{name: "unknown_weekday", in: SlotsInput{Groupe: "Potes", DureeMinutes: 60, Jours: []string{"funday"}}, refused: true},
		{name: "window_across_midnight", in: SlotsInput{Groupe: "Potes", DureeMinutes: 60, HeureDebut: "22:00", HeureFin: "02:00"}, refused: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newFake()
			store.groupAgenda = tt.agenda
			out, err := newTestToolbox(store).freeSlots(context.Background(), ada, tt.in)
			if tt.refused {
				if !isRefusal(err) {
					t.Fatalf("err = %v, attendu un refus", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			got := make([]string, len(out.Creneaux))
			for i, s := range out.Creneaux {
				got[i] = s.Debut + "/" + s.Fin
			}
			if strings.Join(got, ", ") != tt.want {
				t.Fatalf("créneaux = %v, attendu %s", got, tt.want)
			}
		})
	}
}

func TestCreateEvent(t *testing.T) {
	store := newFake()
	tools := newTestToolbox(store)
	out, err := tools.createEvent(context.Background(), ada, CreateInput{
		Titre: "  Dentiste ", Debut: "2026-10-09T09:00", Fin: "2026-10-09T09:30", Lieu: "Cabinet"})
	if err != nil {
		t.Fatal(err)
	}
	d := store.drafts[0]
	if d.CalendarID != "cal-perso" || d.Title != "Dentiste" || d.Timezone != "Europe/Paris" || d.AllDay {
		t.Fatalf("brouillon = %+v : l'agenda natif le plus ancien, titre nettoyé, fuseau du profil", d)
	}
	if !d.Start.Equal(time.Date(2026, 10, 9, 7, 0, 0, 0, time.UTC)) || out.Agenda != "Agenda" || out.Debut != "2026-10-09T09:00:00+02:00" {
		t.Fatalf("début %v, sortie %+v", d.Start, out)
	}

	tests := []struct {
		name string
		in   CreateInput
	}{
		{name: "an_imported_calendar_is_read_only", in: CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true, Agenda: "boulot"}},
		{name: "an_unknown_calendar", in: CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true, Agenda: "Rando"}},
		{name: "an_empty_title", in: CreateInput{Titre: "  ", Debut: "2026-10-09", JourneeEntiere: true}},
		{name: "a_too_long_place", in: CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true, Lieu: strings.Repeat("a", maxLocation+1)}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := tools.createEvent(context.Background(), ada, tt.in); !isRefusal(err) {
				t.Fatalf("err = %v, attendu un refus", err)
			}
		})
	}
	if len(store.drafts) != 1 {
		t.Fatalf("%d écritures : un refus n'écrit rien", len(store.drafts))
	}
}

func TestProposeEventGoesToTheGroupCalendar(t *testing.T) {
	store := newFake()
	out, err := newTestToolbox(store).proposeEvent(context.Background(), ada, ProposeInput{
		Groupe: "Potes", Titre: "Resto", Debut: "2026-10-09T20:00", Fin: "2026-10-09T22:00"})
	if err != nil {
		t.Fatal(err)
	}
	if store.drafts[0].CalendarID != "cal-potes" || out.Groupe != "Potes" {
		t.Fatalf("brouillon %+v, sortie %+v", store.drafts[0], out)
	}
	store.calendars = store.calendars[:2]
	if _, err := newTestToolbox(store).proposeEvent(context.Background(), ada, ProposeInput{
		Groupe: "Potes", Titre: "Resto", Debut: "2026-10-09T20:00", Fin: "2026-10-09T22:00"}); !isRefusal(err) {
		t.Fatalf("un groupe sans agenda : err = %v", err)
	}
}

func TestWritesAreCappedPerMember(t *testing.T) {
	store := newFake()
	now := monday
	tools := newToolbox(store, func() time.Time { return now })
	in := CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true}
	for i := 0; i < maxWritesPerHour; i++ {
		if _, err := tools.createEvent(context.Background(), ada, in); err != nil {
			t.Fatalf("écriture %d : %v", i, err)
		}
	}
	if _, err := tools.createEvent(context.Background(), ada, in); !isRefusal(err) {
		t.Fatalf("au-delà du plafond : err = %v", err)
	}
	if _, err := tools.createEvent(context.Background(), ben, in); err != nil {
		t.Fatalf("le plafond est par membre : %v", err)
	}
	now = now.Add(time.Hour)
	if _, err := tools.createEvent(context.Background(), ada, in); err != nil {
		t.Fatalf("une heure plus tard : %v", err)
	}
}

func TestRespond(t *testing.T) {
	tests := []struct {
		name    string
		in      RespondInput
		want    string
		refused bool
	}{
		{name: "present", in: RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1", Reponse: "present"}, want: "e0000000-0000-0000-0000-0000000000e1=yes"},
		{name: "an_occurrence_of_a_series", in: RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1@2026-10-06T16:00:00Z", Reponse: "peut_etre"},
			want: "e0000000-0000-0000-0000-0000000000e1@2026-10-06T16:00:00Z=maybe"},
		{name: "withdraw", in: RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1", Reponse: "aucune"}, want: "e0000000-0000-0000-0000-0000000000e1="},
		{name: "unknown_answer", in: RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1", Reponse: "oui"}, refused: true},
		{name: "not_a_reference", in: RespondInput{Rdv: "le match", Reponse: "present"}, refused: true},
		{name: "a_bad_occurrence", in: RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1@mardi", Reponse: "present"}, refused: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newFake()
			_, err := newTestToolbox(store).respond(context.Background(), ada, tt.in)
			if tt.refused {
				if !isRefusal(err) || len(store.responses) != 0 {
					t.Fatalf("err = %v, réponses %v : attendu un refus sans écriture", err, store.responses)
				}
				return
			}
			if err != nil || len(store.responses) != 1 || store.responses[0] != tt.want {
				t.Fatalf("réponses = %v, %v ; attendu %s", store.responses, err, tt.want)
			}
		})
	}
	store := newFake()
	store.err = ErrEventNotFound
	_, err := newTestToolbox(store).respond(context.Background(), ada, RespondInput{Rdv: "e0000000-0000-0000-0000-0000000000e1", Reponse: "absent"})
	if !isRefusal(err) || !strings.Contains(err.Error(), "introuvable") {
		t.Fatalf("rdv introuvable : err = %v", err)
	}
}

func TestGroupProposalsHaveTheirOwnLowerCap(t *testing.T) {
	store := newFake()
	tools := newTestToolbox(store)
	in := ProposeInput{Groupe: "Potes", Titre: "Resto", Debut: "2026-10-09", JourneeEntiere: true}
	for i := 0; i < maxProposalsPerHour; i++ {
		if _, err := tools.proposeEvent(context.Background(), ada, in); err != nil {
			t.Fatalf("proposition %d : %v", i, err)
		}
	}
	if _, err := tools.proposeEvent(context.Background(), ada, in); !isRefusal(err) {
		t.Fatalf("au-delà du plafond des propositions : err = %v", err)
	}
	if _, err := tools.createEvent(context.Background(), ada, CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true}); err != nil {
		t.Fatalf("le rdv perso garde son propre plafond : %v", err)
	}
}
