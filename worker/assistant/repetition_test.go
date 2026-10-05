package assistant

import (
	"context"
	"slices"
	"testing"
	"time"
)

// Le TD du lundi, de 8 h à 10 h, du 5 octobre 2026 au 4 janvier 2027, sauf
// pendant les vacances de la Toussaint et le lundi banalisé : la série
// enjambe le passage à l'heure d'hiver (25 octobre).
func TestCreateEventMakesAWeeklySeries(t *testing.T) {
	store := newFake()
	out, err := newTestToolbox(store).createEvent(context.Background(), ada, CreateInput{
		Titre: "NF19 — TD", Debut: "2026-10-05T08:00", Fin: "2026-10-05T10:00",
		Repetition: &RepetitionInput{
			Frequence: "hebdomadaire", Jours: []string{"Lundi"}, JusquAu: "2027-01-04",
			Sauf: []string{"2026-10-26", "2026-11-30", "2026-11-30"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(store.drafts) != 1 {
		t.Fatalf("%d écritures : une série est une seule ligne", len(store.drafts))
	}
	d := store.drafts[0]
	if d.RRule != "FREQ=WEEKLY;BYDAY=MO;UNTIL=20270104T225959Z" {
		t.Fatalf("règle = %q : jusqu'à la fin du 4 janvier à Paris, dans l'ordre de l'app", d.RRule)
	}
	// Les séances sautées sont des instants : 8 h à Paris, en heure d'hiver.
	want := []time.Time{
		time.Date(2026, 10, 26, 7, 0, 0, 0, time.UTC),
		time.Date(2026, 11, 30, 7, 0, 0, 0, time.UTC),
	}
	if !slices.EqualFunc(d.Exdates, want, time.Time.Equal) {
		t.Fatalf("exceptions = %v ; attendu %v (dédoublonnées, à l'heure du cours)", d.Exdates, want)
	}
	if !d.Start.Equal(time.Date(2026, 10, 5, 6, 0, 0, 0, time.UTC)) {
		t.Fatalf("début de la série = %v", d.Start)
	}
	// 14 lundis du 5 octobre au 4 janvier, moins les deux sautés.
	rep := out.Repetition
	if rep == nil || rep.Seances != 12 ||
		rep.Premiere != "2026-10-05T08:00:00+02:00" || rep.Derniere != "2027-01-04T08:00:00+01:00" {
		t.Fatalf("répétition rendue = %+v", rep)
	}
}

func TestCreateEventWithoutRepetitionStaysSingle(t *testing.T) {
	store := newFake()
	out, err := newTestToolbox(store).createEvent(context.Background(), ada, CreateInput{
		Titre: "Dentiste", Debut: "2026-10-09T09:00", Fin: "2026-10-09T09:30"})
	if err != nil {
		t.Fatal(err)
	}
	if d := store.drafts[0]; d.RRule != "" || d.Exdates != nil || out.Repetition != nil {
		t.Fatalf("brouillon %+v, sortie %+v : un rdv ponctuel n'a ni règle ni exceptions", d, out)
	}
}

func TestRepetitionRules(t *testing.T) {
	tests := []struct {
		name     string
		debut    string
		fin      string
		allDay   bool
		rep      RepetitionInput
		rule     string
		seances  int
		premiere string
		derniere string
		exdates  []time.Time
	}{
		{
			name: "every_other_week_on_the_start_weekday", debut: "2026-10-05T14:00", fin: "2026-10-05T16:00",
			rep:  RepetitionInput{Frequence: "hebdomadaire", Intervalle: 2, JusquAu: "2026-11-30"},
			rule: "FREQ=WEEKLY;INTERVAL=2;UNTIL=20261130T225959Z", seances: 5,
			premiere: "2026-10-05T14:00:00+02:00", derniere: "2026-11-30T14:00:00+01:00",
		},
		{
			name: "two_weekdays_in_the_app_order", debut: "2026-10-06T10:00", fin: "2026-10-06T11:00",
			rep:  RepetitionInput{Frequence: "Hebdomadaire", Jours: []string{"mercredi", "mardi"}, Nombre: 4},
			rule: "FREQ=WEEKLY;BYDAY=TU,WE;COUNT=4", seances: 4,
			premiere: "2026-10-06T10:00:00+02:00", derniere: "2026-10-14T10:00:00+02:00",
		},
		{
			name: "monthly_by_count", debut: "2026-10-09T18:00", fin: "2026-10-09T19:00",
			rep:  RepetitionInput{Frequence: "mensuelle", Nombre: 3},
			rule: "FREQ=MONTHLY;COUNT=3", seances: 3,
			premiere: "2026-10-09T18:00:00+02:00", derniere: "2026-12-09T18:00:00+01:00",
		},
		{
			name: "all_day_series_skip_in_utc", debut: "2026-10-05", allDay: true,
			rep:  RepetitionInput{Frequence: "quotidienne", Nombre: 3, Sauf: []string{"2026-10-06"}},
			rule: "FREQ=DAILY;COUNT=3", seances: 2, premiere: "2026-10-05", derniere: "2026-10-07",
			exdates: []time.Time{time.Date(2026, 10, 6, 0, 0, 0, 0, time.UTC)},
		},
		{
			name: "up_to_one_year_exactly", debut: "2026-10-05T08:00", fin: "2026-10-05T09:00",
			rep:  RepetitionInput{Frequence: "annuelle", JusquAu: "2027-10-05"},
			rule: "FREQ=YEARLY;UNTIL=20271005T215959Z", seances: 2,
			premiere: "2026-10-05T08:00:00+02:00", derniere: "2027-10-05T08:00:00+02:00",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newFake()
			rep := tt.rep
			out, err := newTestToolbox(store).createEvent(context.Background(), ada, CreateInput{
				Titre: "X", Debut: tt.debut, Fin: tt.fin, JourneeEntiere: tt.allDay, Repetition: &rep})
			if err != nil {
				t.Fatal(err)
			}
			d := store.drafts[0]
			if d.RRule != tt.rule || !slices.EqualFunc(d.Exdates, tt.exdates, time.Time.Equal) {
				t.Fatalf("règle %q, exceptions %v ; attendu %q, %v", d.RRule, d.Exdates, tt.rule, tt.exdates)
			}
			got := out.Repetition
			if got == nil || got.Seances != tt.seances || got.Premiere != tt.premiere || got.Derniere != tt.derniere {
				t.Fatalf("répétition rendue = %+v", got)
			}
		})
	}
}

func TestRepetitionRefusals(t *testing.T) {
	weekly := func(edit func(*RepetitionInput)) *RepetitionInput {
		rep := RepetitionInput{Frequence: "hebdomadaire", JusquAu: "2026-12-14"}
		edit(&rep)
		return &rep
	}
	tests := []struct {
		name string
		rep  *RepetitionInput
	}{
		{name: "without_an_end", rep: weekly(func(r *RepetitionInput) { r.JusquAu = "" })},
		{name: "with_two_ends", rep: weekly(func(r *RepetitionInput) { r.Nombre = 3 })},
		{name: "ending_more_than_a_year_later", rep: weekly(func(r *RepetitionInput) { r.JusquAu = "2027-10-06" })},
		{name: "counting_past_a_year", rep: &RepetitionInput{Frequence: "quotidienne", Nombre: 400}},
		{name: "ending_before_it_starts", rep: weekly(func(r *RepetitionInput) { r.JusquAu = "2026-10-04" })},
		{name: "an_unknown_frequency", rep: weekly(func(r *RepetitionInput) { r.Frequence = "bimensuelle" })},
		{name: "a_negative_interval", rep: weekly(func(r *RepetitionInput) { r.Intervalle = -1 })},
		{name: "a_negative_count", rep: &RepetitionInput{Frequence: "quotidienne", Nombre: -2}},
		{name: "days_on_a_monthly_rule", rep: &RepetitionInput{Frequence: "mensuelle", Nombre: 3, Jours: []string{"lundi"}}},
		{name: "an_unknown_day", rep: weekly(func(r *RepetitionInput) { r.Jours = []string{"lun"} })},
		{name: "a_start_off_the_chosen_days", rep: weekly(func(r *RepetitionInput) { r.Jours = []string{"mardi"} })},
		{name: "a_skipped_date_that_is_no_session", rep: weekly(func(r *RepetitionInput) { r.Sauf = []string{"2026-10-27"} })},
		{name: "a_skipped_date_that_is_no_date", rep: weekly(func(r *RepetitionInput) { r.Sauf = []string{"30/11"} })},
		{name: "every_session_skipped", rep: &RepetitionInput{Frequence: "quotidienne", Nombre: 1, Sauf: []string{"2026-10-05"}}},
	}
	store := newFake()
	tools := newTestToolbox(store)
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := tools.createEvent(context.Background(), ada, CreateInput{
				Titre: "X", Debut: "2026-10-05T08:00", Fin: "2026-10-05T10:00", Repetition: tt.rep})
			if !isRefusal(err) {
				t.Fatalf("err = %v, attendu un refus", err)
			}
		})
	}
	if len(store.drafts) != 0 {
		t.Fatalf("%d écritures : un refus n'écrit rien", len(store.drafts))
	}
}

func TestASeriesCountsAsOneWrite(t *testing.T) {
	store := newFake()
	tools := newTestToolbox(store)
	series := CreateInput{Titre: "X", Debut: "2026-10-05T08:00", Fin: "2026-10-05T10:00",
		Repetition: &RepetitionInput{Frequence: "quotidienne", Nombre: 90}}
	if _, err := tools.createEvent(context.Background(), ada, series); err != nil {
		t.Fatal(err)
	}
	single := CreateInput{Titre: "X", Debut: "2026-10-09", JourneeEntiere: true}
	for i := 1; i < maxWritesPerHour; i++ {
		if _, err := tools.createEvent(context.Background(), ada, single); err != nil {
			t.Fatalf("écriture %d : %v", i+1, err)
		}
	}
	if _, err := tools.createEvent(context.Background(), ada, single); !isRefusal(err) {
		t.Fatalf("21e écriture : err = %v, attendu le plafond", err)
	}
}

func TestProposeEventMakesAGroupSeries(t *testing.T) {
	store := newFake()
	tools := newTestToolbox(store)
	in := ProposeInput{Groupe: "Potes", Titre: "Escalade", Debut: "2026-10-07T19:00", Fin: "2026-10-07T21:00",
		Repetition: &RepetitionInput{Frequence: "hebdomadaire", Nombre: 10}}
	out, err := tools.proposeEvent(context.Background(), ada, in)
	if err != nil {
		t.Fatal(err)
	}
	if d := store.drafts[0]; d.CalendarID != "cal-potes" || d.RRule != "FREQ=WEEKLY;COUNT=10" ||
		out.Repetition == nil || out.Repetition.Seances != 10 {
		t.Fatalf("brouillon %+v, sortie %+v", d, out)
	}
	// Une série proposée compte pour une proposition : le plafond du groupe
	// tient toujours.
	for i := 1; i < maxProposalsPerHour; i++ {
		if _, err := tools.proposeEvent(context.Background(), ada, in); err != nil {
			t.Fatalf("proposition %d : %v", i+1, err)
		}
	}
	if _, err := tools.proposeEvent(context.Background(), ada, in); !isRefusal(err) {
		t.Fatalf("6e proposition : err = %v, attendu le plafond", err)
	}
	in.Repetition = &RepetitionInput{Frequence: "hebdomadaire"}
	if _, err := newTestToolbox(newFake()).proposeEvent(context.Background(), ada, in); !isRefusal(err) {
		t.Fatalf("une série de groupe sans fin : err = %v", err)
	}
}
