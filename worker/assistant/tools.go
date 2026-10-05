package assistant

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/Lelio88/agora/worker/slots"
)

// Les outils : chacun appelle ce que l'application appelle déjà (Store), et
// ne décide rien qu'il ne puisse justifier. « L'outil ne devine pas » : un
// groupe, un agenda ou un membre se désigne par son identifiant ou son nom
// exact ; ambigu ou inconnu, la demande est refusée avec les choix possibles.

const (
	// maxRows borne une lecture : un agenda entier noierait le contexte de
	// l'assistant.
	maxRows = 300
	// maxWritesPerHour plafonne les écritures d'un membre par assistant : une
	// injection de consignes ne doit pas pouvoir inonder un groupe.
	maxWritesPerHour = 20
	// maxProposalsPerHour plafonne plus bas ce que tout le groupe voit (et que
	// Discord rappelle) : c'est là qu'une injection publierait des données.
	maxProposalsPerHour = 5
	maxTitle            = 200
	maxLocation         = 300
	maxDescription      = 5000
	minSlotMinutes      = 15
	maxSlotMinutes      = 24 * 60
	defaultDayStart     = 9 * time.Hour
	defaultDayEnd       = 22 * time.Hour
)

// refusal est un refus rendu tel quel à l'assistant (l'outil échoue avec ce
// message) : jamais une erreur interne, qui pourrait contenir autre chose.
type refusal struct{ msg string }

func (r refusal) Error() string { return r.msg }

func refuse(format string, args ...any) error {
	return refusal{msg: fmt.Sprintf(format, args...)}
}

// storeRefusal traduit un refus de la base en message pour l'assistant.
func storeRefusal(err error) error {
	switch {
	case errors.Is(err, ErrNotMember):
		return refuse("Tu n'es pas membre de ce groupe.")
	case errors.Is(err, ErrInvalidRange):
		return refuse("Une plage dure au plus 93 jours, et sa fin suit son début.")
	case errors.Is(err, ErrEventNotFound):
		return refuse("Rdv introuvable, ou hors de tes groupes : reprends sa référence dans mon_agenda.")
	case errors.Is(err, ErrInvalidOccurrence):
		return refuse("Cette occurrence n'appartient pas à la série : reprends la référence dans mon_agenda.")
	case errors.Is(err, ErrForbidden):
		return refuse("Ce geste n'est pas permis dans cet agenda.")
	case errors.Is(err, ErrInvalidValue):
		return refuse("Une valeur est refusée (titre de 1 à 200 caractères, lieu ≤ 300, description ≤ 5000).")
	}
	return err
}

// writeLimiter compte les écritures de chaque membre sur l'heure glissante.
// En mémoire : le worker tourne en un seul exemplaire.
type writeLimiter struct {
	mu   sync.Mutex
	now  func() time.Time
	max  int
	hits map[string][]time.Time
}

func newWriteLimiter(now func() time.Time, max int) *writeLimiter {
	return &writeLimiter{now: now, max: max, hits: map[string][]time.Time{}}
}

func (l *writeLimiter) allow(userID string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	recent := l.hits[userID][:0]
	for _, t := range l.hits[userID] {
		if now.Sub(t) < time.Hour {
			recent = append(recent, t)
		}
	}
	if len(recent) >= l.max {
		l.hits[userID] = recent
		return false
	}
	l.hits[userID] = append(recent, now)
	return true
}

// toolbox porte les outils et leurs dépendances.
type toolbox struct {
	store     Store
	now       func() time.Time
	limiter   *writeLimiter
	proposals *writeLimiter
}

func newToolbox(store Store, now func() time.Time) *toolbox {
	return &toolbox{
		store: store, now: now,
		limiter:   newWriteLimiter(now, maxWritesPerHour),
		proposals: newWriteLimiter(now, maxProposalsPerHour),
	}
}

// location lit le fuseau du profil ; un nom inconnu retombe sur Paris,
// comme à l'inscription.
func (t *toolbox) location(ctx context.Context, userID string) (*time.Location, error) {
	p, err := t.store.Profile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if loc, err := time.LoadLocation(p.Timezone); err == nil {
		return loc, nil
	}
	return time.LoadLocation("Europe/Paris")
}

// --- mes_groupes ---------------------------------------------------------------------------

type GroupsInput struct{}

type MemberOut struct {
	ID   string `json:"id"`
	Nom  string `json:"nom"`
	Role string `json:"role" jsonschema:"owner, admin ou member"`
}

type GroupOut struct {
	ID          string      `json:"id"`
	Nom         string      `json:"nom"`
	Description string      `json:"description,omitempty"`
	MonRole     string      `json:"mon_role"`
	MonPartage  string      `json:"mon_partage" jsonschema:"ce que les autres voient de mon agenda : details, busy ou invisible"`
	Membres     []MemberOut `json:"membres"`
}

type GroupsOutput struct {
	Groupes []GroupOut `json:"groupes"`
}

func (t *toolbox) groups(ctx context.Context, userID string, _ GroupsInput) (GroupsOutput, error) {
	groups, err := t.store.Groups(ctx, userID)
	if err != nil {
		return GroupsOutput{}, err
	}
	out := GroupsOutput{Groupes: make([]GroupOut, 0, len(groups))}
	for _, g := range groups {
		members := make([]MemberOut, 0, len(g.Members))
		for _, m := range g.Members {
			members = append(members, MemberOut{ID: m.UserID, Nom: m.Name, Role: m.Role})
		}
		out.Groupes = append(out.Groupes, GroupOut{
			ID: g.ID, Nom: g.Name, Description: g.Description,
			MonRole: g.MyRole, MonPartage: g.MyShare, Membres: members,
		})
	}
	return out, nil
}

// findGroup désigne un groupe par identifiant ou par nom exact (casse ignorée).
func findGroup(groups []Group, ref string) (Group, error) {
	ref = strings.TrimSpace(ref)
	names := make([]string, 0, len(groups))
	for _, g := range groups {
		if g.ID == ref {
			return g, nil
		}
		names = append(names, "« "+g.Name+" »")
	}
	var found []Group
	for _, g := range groups {
		if strings.EqualFold(g.Name, ref) {
			found = append(found, g)
		}
	}
	switch {
	case len(groups) == 0:
		return Group{}, refuse("Tu n'es membre d'aucun groupe.")
	case len(found) == 1:
		return found[0], nil
	case len(found) > 1:
		ids := make([]string, len(found))
		for i, g := range found {
			ids[i] = g.ID
		}
		return Group{}, refuse("Plusieurs groupes s'appellent « %s » : désigne-le par son identifiant (%s).", ref, strings.Join(ids, ", "))
	}
	return Group{}, refuse("Aucun groupe « %s ». Tes groupes : %s.", ref, strings.Join(names, ", "))
}

// --- mon_agenda ------------------------------------------------------------------------------

type RangeInput struct {
	Du string `json:"du,omitempty" jsonschema:"début de la plage, ISO 8601 (défaut : aujourd'hui)"`
	Au string `json:"au,omitempty" jsonschema:"fin de la plage, ISO 8601 ; une date seule compte en entier (défaut : une semaine)"`
}

type EntryOut struct {
	Rdv            string `json:"rdv" jsonschema:"référence à passer à repondre_au_rdv"`
	Titre          string `json:"titre"`
	Lieu           string `json:"lieu,omitempty"`
	Description    string `json:"description,omitempty"`
	Debut          string `json:"debut"`
	Fin            string `json:"fin" jsonschema:"comprise pour une journée entière"`
	JourneeEntiere bool   `json:"journee_entiere"`
	Agenda         string `json:"agenda"`
	Proche         string `json:"proche,omitempty" jsonschema:"présent si le rdv est dans l'agenda d'un proche (ses repos, son anniversaire) : ce n'est jamais une indisponibilité du membre"`
	Groupe         string `json:"groupe,omitempty" jsonschema:"présent si c'est un rdv de ce groupe"`
	Recurrent      bool   `json:"recurrent"`
	MaReponse      string `json:"ma_reponse,omitempty" jsonschema:"present, peut_etre ou absent, pour un rdv de groupe"`
}

type AgendaOutput struct {
	Fuseau  string     `json:"fuseau"`
	Rdv     []EntryOut `json:"rdv"`
	Tronque bool       `json:"tronque" jsonschema:"vrai si la liste a été coupée : resserre la plage"`
}

var responseLabels = map[string]string{"yes": "present", "maybe": "peut_etre", "no": "absent"}

func (t *toolbox) myAgenda(ctx context.Context, userID string, in RangeInput) (AgendaOutput, error) {
	loc, err := t.location(ctx, userID)
	if err != nil {
		return AgendaOutput{}, err
	}
	from, to, err := parseRange(in.Du, in.Au, t.now(), loc)
	if err != nil {
		return AgendaOutput{}, err
	}
	entries, err := t.store.MyAgenda(ctx, userID, from, to)
	if err != nil {
		return AgendaOutput{}, storeRefusal(err)
	}
	calendars, groupNames, err := t.calendarNames(ctx, userID)
	if err != nil {
		return AgendaOutput{}, err
	}
	out := AgendaOutput{Fuseau: loc.String(), Rdv: []EntryOut{}}
	for _, e := range entries {
		if len(out.Rdv) == maxRows {
			out.Tronque = true
			break
		}
		cal := calendars[e.CalendarID]
		out.Rdv = append(out.Rdv, EntryOut{
			Rdv: reference(e), Titre: e.Title, Lieu: e.Location, Description: e.Description,
			Debut: formatStart(e.Start, e.AllDay, loc), Fin: formatEnd(e.End, e.AllDay, loc),
			JourneeEntiere: e.AllDay, Agenda: cal.Name, Proche: contactName(cal), Groupe: groupNames[cal.GroupID],
			Recurrent: e.SeriesID != "", MaReponse: responseLabels[e.MyResponse],
		})
	}
	return out, nil
}

// contactName rend le nom du proche quand l'agenda est celui d'un proche.
func contactName(c Calendar) string {
	if c.Contact {
		return c.Name
	}
	return ""
}

// calendarNames indexe les agendas lisibles, et nomme les groupes.
func (t *toolbox) calendarNames(ctx context.Context, userID string) (map[string]Calendar, map[string]string, error) {
	calendars, err := t.store.Calendars(ctx, userID)
	if err != nil {
		return nil, nil, err
	}
	groups, err := t.store.Groups(ctx, userID)
	if err != nil {
		return nil, nil, err
	}
	byID := make(map[string]Calendar, len(calendars))
	for _, c := range calendars {
		byID[c.ID] = c
	}
	names := make(map[string]string, len(groups))
	for _, g := range groups {
		names[g.ID] = g.Name
	}
	return byID, names, nil
}

// reference désigne un rdv pour repondre_au_rdv : l'identifiant, et pour une
// occurrence dépliée d'une série, son créneau d'origine (règle d'agenda_item.dart).
func reference(e Entry) string {
	if e.SeriesID != "" && e.EventID == e.SeriesID && e.OriginalStart != nil {
		return e.EventID + "@" + e.OriginalStart.UTC().Format(time.RFC3339)
	}
	return e.EventID
}

// --- agenda_du_groupe -----------------------------------------------------------------------

type GroupRangeInput struct {
	Groupe string `json:"groupe" jsonschema:"identifiant ou nom exact du groupe"`
	Du     string `json:"du,omitempty" jsonschema:"début de la plage, ISO 8601 (défaut : aujourd'hui)"`
	Au     string `json:"au,omitempty" jsonschema:"fin de la plage, ISO 8601 ; une date seule compte en entier (défaut : une semaine)"`
}

type GroupEntryOut struct {
	Membre         string `json:"membre,omitempty" jsonschema:"absent pour un rdv du groupe"`
	RdvDuGroupe    bool   `json:"rdv_du_groupe"`
	Niveau         string `json:"niveau" jsonschema:"detail (titre et lieu visibles) ou occupe (créneau pris, sans détail)"`
	Titre          string `json:"titre,omitempty"`
	Lieu           string `json:"lieu,omitempty"`
	Debut          string `json:"debut"`
	Fin            string `json:"fin"`
	JourneeEntiere bool   `json:"journee_entiere"`
}

type GroupAgendaOutput struct {
	Groupe   string          `json:"groupe"`
	Fuseau   string          `json:"fuseau"`
	Creneaux []GroupEntryOut `json:"creneaux"`
	Tronque  bool            `json:"tronque"`
}

func (t *toolbox) groupAgenda(ctx context.Context, userID string, in GroupRangeInput) (GroupAgendaOutput, error) {
	loc, group, err := t.locationAndGroup(ctx, userID, in.Groupe)
	if err != nil {
		return GroupAgendaOutput{}, err
	}
	from, to, err := parseRange(in.Du, in.Au, t.now(), loc)
	if err != nil {
		return GroupAgendaOutput{}, err
	}
	entries, err := t.store.GroupAgenda(ctx, userID, group.ID, from, to)
	if err != nil {
		return GroupAgendaOutput{}, storeRefusal(err)
	}
	names := make(map[string]string, len(group.Members))
	for _, m := range group.Members {
		names[m.UserID] = m.Name
	}
	out := GroupAgendaOutput{Groupe: group.Name, Fuseau: loc.String(), Creneaux: []GroupEntryOut{}}
	for _, e := range entries {
		if len(out.Creneaux) == maxRows {
			out.Tronque = true
			break
		}
		level := "occupe"
		if e.Level == "details" {
			level = "detail"
		}
		out.Creneaux = append(out.Creneaux, GroupEntryOut{
			Membre: names[e.UserID], RdvDuGroupe: e.IsGroupEvent, Niveau: level,
			Titre: e.Title, Lieu: e.Location,
			Debut: formatStart(e.Start, e.AllDay, loc), Fin: formatEnd(e.End, e.AllDay, loc),
			JourneeEntiere: e.AllDay,
		})
	}
	return out, nil
}

func (t *toolbox) locationAndGroup(ctx context.Context, userID, ref string) (*time.Location, Group, error) {
	loc, err := t.location(ctx, userID)
	if err != nil {
		return nil, Group{}, err
	}
	groups, err := t.store.Groups(ctx, userID)
	if err != nil {
		return nil, Group{}, err
	}
	group, err := findGroup(groups, ref)
	return loc, group, err
}

// --- creneaux_communs -----------------------------------------------------------------------

type SlotsInput struct {
	Groupe           string   `json:"groupe" jsonschema:"identifiant ou nom exact du groupe"`
	DureeMinutes     int      `json:"duree_minutes" jsonschema:"durée minimale du créneau, de 15 à 1440 minutes"`
	Du               string   `json:"du,omitempty" jsonschema:"début de la recherche, ISO 8601 (défaut : maintenant)"`
	Au               string   `json:"au,omitempty" jsonschema:"fin de la recherche, ISO 8601 ; une date seule compte en entier (défaut : une semaine)"`
	HeureDebut       string   `json:"heure_debut,omitempty" jsonschema:"début de la fenêtre quotidienne, 18:30 (défaut : 09:00)"`
	HeureFin         string   `json:"heure_fin,omitempty" jsonschema:"fin de la fenêtre quotidienne, 22:00 (défaut : 22:00)"`
	Jours            []string `json:"jours,omitempty" jsonschema:"jours voulus, de lundi à dimanche (défaut : tous)"`
	Membres          []string `json:"membres,omitempty" jsonschema:"membres dont la présence est requise, identifiant ou nom exact (défaut : tous)"`
	JourneesBloquent bool     `json:"journees_bloquent,omitempty" jsonschema:"une journée entière prend-elle la journée ? (défaut : non)"`
}

type SlotOut struct {
	Debut        string `json:"debut"`
	Fin          string `json:"fin"`
	DureeMinutes int    `json:"duree_minutes"`
}

type SlotsOutput struct {
	Groupe   string    `json:"groupe"`
	Fuseau   string    `json:"fuseau"`
	Creneaux []SlotOut `json:"creneaux"`
	Tronque  bool      `json:"tronque"`
	Note     string    `json:"note"`
}

func (t *toolbox) freeSlots(ctx context.Context, userID string, in SlotsInput) (SlotsOutput, error) {
	if in.DureeMinutes < minSlotMinutes || in.DureeMinutes > maxSlotMinutes {
		return SlotsOutput{}, refuse("duree_minutes va de %d à %d.", minSlotMinutes, maxSlotMinutes)
	}
	loc, group, err := t.locationAndGroup(ctx, userID, in.Groupe)
	if err != nil {
		return SlotsOutput{}, err
	}
	search, err := buildSearch(in, group, t.now().In(loc), loc)
	if err != nil {
		return SlotsOutput{}, err
	}
	// Depuis minuit du premier jour : un rdv commencé avant prend encore le créneau.
	agenda, err := t.store.GroupAgenda(ctx, userID, group.ID, startOfDay(search.From), search.To)
	if err != nil {
		return SlotsOutput{}, storeRefusal(err)
	}
	items := make([]slots.Item, len(agenda))
	for i, e := range agenda {
		items[i] = slots.Item{UserID: e.UserID, IsGroupEvent: e.IsGroupEvent, Start: e.Start, End: e.End, AllDay: e.AllDay}
	}
	free := slots.Find(search, items)
	out := SlotsOutput{
		Groupe: group.Name, Fuseau: loc.String(), Creneaux: make([]SlotOut, 0, len(free)),
		Tronque: len(free) == slots.Max,
		Note:    "Un membre qui ne partage rien avec le groupe paraît libre.",
	}
	for _, s := range free {
		out.Creneaux = append(out.Creneaux, SlotOut{
			Debut: s.Start.Format(time.RFC3339), Fin: s.End.Format(time.RFC3339),
			DureeMinutes: int(s.End.Sub(s.Start) / time.Minute),
		})
	}
	return out, nil
}

func buildSearch(in SlotsInput, group Group, now time.Time, loc *time.Location) (slots.Search, error) {
	from, to, err := parseRange(in.Du, in.Au, now, loc)
	if err != nil {
		return slots.Search{}, err
	}
	if strings.TrimSpace(in.Du) == "" || from.Before(now) {
		from = now // jamais le passé
	}
	if !to.After(from) {
		return slots.Search{}, refuse("La plage de recherche est déjà passée.")
	}
	dayStart, err := parseClock(in.HeureDebut, defaultDayStart)
	if err != nil {
		return slots.Search{}, err
	}
	dayEnd, err := parseClock(in.HeureFin, defaultDayEnd)
	if err != nil {
		return slots.Search{}, err
	}
	if dayEnd <= dayStart {
		return slots.Search{}, refuse("La fenêtre quotidienne ne passe pas minuit : heure_fin suit heure_debut.")
	}
	weekdays, err := parseWeekdays(in.Jours)
	if err != nil {
		return slots.Search{}, err
	}
	members, err := requiredMembers(group, in.Membres)
	if err != nil {
		return slots.Search{}, err
	}
	return slots.Search{
		Location: loc, From: from, To: to,
		Duration: time.Duration(in.DureeMinutes) * time.Minute,
		DayStart: dayStart, DayEnd: dayEnd, Weekdays: weekdays,
		Members: members, AllDayBlocks: in.JourneesBloquent,
	}, nil
}

// requiredMembers désigne les membres requis ; aucun veut dire tous.
func requiredMembers(group Group, refs []string) (map[string]bool, error) {
	members := map[string]bool{}
	if len(refs) == 0 {
		for _, m := range group.Members {
			members[m.UserID] = true
		}
		return members, nil
	}
	names := make([]string, 0, len(group.Members))
	for _, m := range group.Members {
		names = append(names, "« "+m.Name+" »")
	}
	sort.Strings(names)
	for _, ref := range refs {
		ref = strings.TrimSpace(ref)
		var found []Member
		for _, m := range group.Members {
			if m.UserID == ref || strings.EqualFold(m.Name, ref) {
				found = append(found, m)
			}
		}
		switch len(found) {
		case 1:
			members[found[0].UserID] = true
		case 0:
			return nil, refuse("Aucun membre « %s » dans « %s ». Membres : %s.", ref, group.Name, strings.Join(names, ", "))
		default:
			return nil, refuse("Plusieurs membres s'appellent « %s » : désigne-les par identifiant (mes_groupes).", ref)
		}
	}
	return members, nil
}

// --- creer_rdv et proposer_rdv ------------------------------------------------------------

type CreateInput struct {
	Titre          string           `json:"titre" jsonschema:"1 à 200 caractères"`
	Debut          string           `json:"debut" jsonschema:"ISO 8601 ; une date seule pour une journée entière"`
	Fin            string           `json:"fin,omitempty" jsonschema:"ISO 8601 ; obligatoire sauf journée entière (dernier jour compris)"`
	JourneeEntiere bool             `json:"journee_entiere,omitempty"`
	Lieu           string           `json:"lieu,omitempty" jsonschema:"au plus 300 caractères"`
	Description    string           `json:"description,omitempty" jsonschema:"au plus 5000 caractères"`
	Agenda         string           `json:"agenda,omitempty" jsonschema:"nom exact d'un de mes agendas (défaut : le premier)"`
	Repetition     *RepetitionInput `json:"repetition,omitempty" jsonschema:"fait du rdv une série (le début est la première séance) ; fin obligatoire, au plus un an"`
}

type ProposeInput struct {
	Groupe         string           `json:"groupe" jsonschema:"identifiant ou nom exact du groupe"`
	Titre          string           `json:"titre" jsonschema:"1 à 200 caractères"`
	Debut          string           `json:"debut" jsonschema:"ISO 8601 ; une date seule pour une journée entière"`
	Fin            string           `json:"fin,omitempty" jsonschema:"ISO 8601 ; obligatoire sauf journée entière (dernier jour compris)"`
	JourneeEntiere bool             `json:"journee_entiere,omitempty"`
	Lieu           string           `json:"lieu,omitempty" jsonschema:"au plus 300 caractères"`
	Description    string           `json:"description,omitempty" jsonschema:"au plus 5000 caractères"`
	Repetition     *RepetitionInput `json:"repetition,omitempty" jsonschema:"fait du rdv une série (le début est la première séance) ; fin obligatoire, au plus un an"`
}

type CreatedOutput struct {
	Rdv            string            `json:"rdv"`
	Titre          string            `json:"titre"`
	Debut          string            `json:"debut"`
	Fin            string            `json:"fin"`
	JourneeEntiere bool              `json:"journee_entiere"`
	Agenda         string            `json:"agenda"`
	Groupe         string            `json:"groupe,omitempty"`
	Repetition     *RepetitionOutput `json:"repetition,omitempty"`
}

type eventText struct{ title, location, description string }

func checkText(title, location, description string) (eventText, error) {
	text := eventText{strings.TrimSpace(title), strings.TrimSpace(location), strings.TrimSpace(description)}
	switch {
	case text.title == "" || len([]rune(text.title)) > maxTitle:
		return text, refuse("Le titre compte de 1 à %d caractères.", maxTitle)
	case len([]rune(text.location)) > maxLocation:
		return text, refuse("Le lieu compte au plus %d caractères.", maxLocation)
	case len([]rune(text.description)) > maxDescription:
		return text, refuse("La description compte au plus %d caractères.", maxDescription)
	}
	return text, nil
}

func (t *toolbox) createEvent(ctx context.Context, userID string, in CreateInput) (CreatedOutput, error) {
	text, err := checkText(in.Titre, in.Lieu, in.Description)
	if err != nil {
		return CreatedOutput{}, err
	}
	loc, err := t.location(ctx, userID)
	if err != nil {
		return CreatedOutput{}, err
	}
	start, end, err := eventBounds(in.Debut, in.Fin, in.JourneeEntiere, loc)
	if err != nil {
		return CreatedOutput{}, err
	}
	plan, err := buildSeries(in.Repetition, start, end, in.JourneeEntiere, loc)
	if err != nil {
		return CreatedOutput{}, err
	}
	calendars, err := t.store.Calendars(ctx, userID)
	if err != nil {
		return CreatedOutput{}, err
	}
	cal, err := personalCalendar(calendars, in.Agenda)
	if err != nil {
		return CreatedOutput{}, err
	}
	return t.write(ctx, userID, cal, "", text, start, end, in.JourneeEntiere, loc, plan)
}

func (t *toolbox) proposeEvent(ctx context.Context, userID string, in ProposeInput) (CreatedOutput, error) {
	text, err := checkText(in.Titre, in.Lieu, in.Description)
	if err != nil {
		return CreatedOutput{}, err
	}
	loc, group, err := t.locationAndGroup(ctx, userID, in.Groupe)
	if err != nil {
		return CreatedOutput{}, err
	}
	start, end, err := eventBounds(in.Debut, in.Fin, in.JourneeEntiere, loc)
	if err != nil {
		return CreatedOutput{}, err
	}
	// Vérifiée avant le plafond : une répétition refusée ne coûte pas une
	// proposition.
	plan, err := buildSeries(in.Repetition, start, end, in.JourneeEntiere, loc)
	if err != nil {
		return CreatedOutput{}, err
	}
	calendars, err := t.store.Calendars(ctx, userID)
	if err != nil {
		return CreatedOutput{}, err
	}
	for _, c := range calendars {
		if c.GroupID != group.ID {
			continue
		}
		if !t.proposals.allow(userID) {
			return CreatedOutput{}, refuse("Plafond atteint : %d propositions au groupe par heure. Réessaie plus tard.", maxProposalsPerHour)
		}
		return t.write(ctx, userID, c, group.Name, text, start, end, in.JourneeEntiere, loc, plan)
	}
	return CreatedOutput{}, refuse("Le groupe « %s » n'a pas d'agenda.", group.Name)
}

// write insère le rdv, ou la série quand plan est posé : une écriture dans
// le plafond dans les deux cas.
func (t *toolbox) write(ctx context.Context, userID string, cal Calendar, groupName string, text eventText,
	start, end time.Time, allDay bool, loc *time.Location, plan *series) (CreatedOutput, error) {
	if !t.limiter.allow(userID) {
		return CreatedOutput{}, refuse("Plafond atteint : %d écritures par heure. Réessaie plus tard.", maxWritesPerHour)
	}
	draft := Draft{
		CalendarID: cal.ID, Title: text.title, Location: text.location, Description: text.description,
		Start: start, End: end, AllDay: allDay, Timezone: loc.String(),
	}
	if plan != nil {
		draft.RRule, draft.Exdates = plan.rule, plan.exdates
	}
	id, err := t.store.CreateEvent(ctx, userID, draft)
	if err != nil {
		return CreatedOutput{}, storeRefusal(err)
	}
	return CreatedOutput{
		Rdv: id, Titre: text.title,
		Debut: formatStart(start, allDay, loc), Fin: formatEnd(end, allDay, loc),
		JourneeEntiere: allDay, Agenda: cal.Name, Groupe: groupName,
		Repetition: plan.output(allDay, loc),
	}, nil
}

// personalCalendar choisit l'agenda perso : celui nommé, sinon le plus ancien
// agenda natif (celui que crée l'inscription). Un agenda importé (iCal) est
// en lecture seule. L'agenda d'un proche se vise par son nom, jamais d'office :
// un rdv du membre n'y a pas sa place.
func personalCalendar(calendars []Calendar, name string) (Calendar, error) {
	var mine []Calendar
	for _, c := range calendars {
		if c.Personal {
			mine = append(mine, c)
		}
	}
	sort.SliceStable(mine, func(i, j int) bool { return mine[i].CreatedAt.Before(mine[j].CreatedAt) })
	name = strings.TrimSpace(name)
	if name == "" {
		for _, c := range mine {
			if c.Native && !c.Contact {
				return c, nil
			}
		}
		return Calendar{}, refuse("Tu n'as aucun agenda où écrire.")
	}
	names := make([]string, 0, len(mine))
	var found []Calendar
	for _, c := range mine {
		names = append(names, "« "+c.Name+" »")
		if strings.EqualFold(c.Name, name) {
			found = append(found, c)
		}
	}
	switch {
	case len(found) == 0:
		return Calendar{}, refuse("Aucun agenda « %s ». Tes agendas : %s.", name, strings.Join(names, ", "))
	case len(found) > 1:
		return Calendar{}, refuse("Plusieurs agendas s'appellent « %s » : renomme-en un dans l'app.", name)
	case !found[0].Native:
		return Calendar{}, refuse("« %s » est importé d'un lien iCal : il est en lecture seule.", found[0].Name)
	}
	return found[0], nil
}

// --- repondre_au_rdv -----------------------------------------------------------------------

type RespondInput struct {
	Rdv     string `json:"rdv" jsonschema:"référence du rdv, telle que rendue par mon_agenda"`
	Reponse string `json:"reponse" jsonschema:"present, peut_etre, absent, ou aucune pour retirer sa réponse"`
}

type RespondOutput struct {
	Rdv     string `json:"rdv"`
	Reponse string `json:"reponse"`
}

var responseCodes = map[string]string{"present": "yes", "peut_etre": "maybe", "absent": "no", "aucune": ""}

func (t *toolbox) respond(ctx context.Context, userID string, in RespondInput) (RespondOutput, error) {
	status, ok := responseCodes[strings.ToLower(strings.TrimSpace(in.Reponse))]
	if !ok {
		return RespondOutput{}, refuse("reponse vaut present, peut_etre, absent ou aucune.")
	}
	eventID, occurrence, err := parseReference(in.Rdv)
	if err != nil {
		return RespondOutput{}, err
	}
	if !t.limiter.allow(userID) {
		return RespondOutput{}, refuse("Plafond atteint : %d écritures par heure. Réessaie plus tard.", maxWritesPerHour)
	}
	if err := t.store.Respond(ctx, userID, eventID, occurrence, status); err != nil {
		return RespondOutput{}, storeRefusal(err)
	}
	return RespondOutput{Rdv: in.Rdv, Reponse: strings.ToLower(strings.TrimSpace(in.Reponse))}, nil
}

func parseReference(ref string) (string, *time.Time, error) {
	ref = strings.TrimSpace(ref)
	id, at, hasOccurrence := strings.Cut(ref, "@")
	if !isUUID(id) {
		return "", nil, refuse("« %s » n'est pas une référence de rdv : reprends-la dans mon_agenda.", ref)
	}
	if !hasOccurrence {
		return id, nil, nil
	}
	occurrence, err := time.Parse(time.RFC3339, at)
	if err != nil {
		return "", nil, refuse("« %s » n'est pas une référence de rdv : reprends-la dans mon_agenda.", ref)
	}
	return id, &occurrence, nil
}

// isUUID vérifie la forme 8-4-4-4-12 en hexadécimal.
func isUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, r := range s {
		switch {
		case i == 8 || i == 13 || i == 18 || i == 23:
			if r != '-' {
				return false
			}
		case !strings.ContainsRune("0123456789abcdefABCDEF", r):
			return false
		}
	}
	return true
}
