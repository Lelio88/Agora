# Agenda perso — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §2 et §7. Elle décrit les séries de rdv, leur
dépliage par le worker, les agendas de chacun et l'agenda dans l'app.

## Séries et exceptions (base)

Migrations : `20260921185718_agenda_series.sql`, `20260921194052_replace_occurrence.sql`,
`20260921220100_update_series.sql`.

| Notion | Représentation |
|---|---|
| Rdv ponctuel | une ligne `events`, `rrule` nul |
| Série | la ligne **maîtresse** : `rrule` non nul, `series_id` nul. Jamais affichée telle quelle |
| Occurrence dépliée | une ligne `event_occurrences (event_id = série, starts_at, ends_at)`, écrite par le worker seul |
| Occurrence **modifiée** | une ligne `events` à part : `series_id` → la maîtresse, `recurrence_id` = créneau d'origine remplacé, `rrule` nul |
| Occurrence **supprimée** | son créneau d'origine dans `events.exdates` de la maîtresse |

- **Invariants** (contraintes et triggers) : une exception a toujours un créneau d'origine et
  jamais de `rrule` ; un créneau ne se remplace qu'une fois (index unique partiel
  `(series_id, recurrence_id)`) ; une exception se rattache à une série existante **du même
  agenda**, que l'appelant **a le droit de modifier** (`private.check_event_series`) : sinon un
  simple membre d'un agenda de groupe effacerait les occurrences de la série d'un autre.
- **Changer l'horaire d'une série** (début, fin, règle, fuseau, journée entière) **efface ses
  exceptions** : leurs créneaux d'origine ne correspondent plus à rien
  (`private.reset_series_exceptions`). Changer son texte les garde. Une série redevenue
  ponctuelle perd ses occurrences dépliées.
- **Une occurrence modifiée masque aussitôt l'occurrence dépliée** de son créneau
  (`private.hide_replaced_occurrence`), sans attendre le worker : l'agenda n'affiche jamais les
  deux.
- **Verrou de série** (`private.lock_series(uuid)`, verrou consultatif de transaction) : le
  worker le prend **avant** de relire une série ; `replace_occurrence`, `delete_occurrence` et
  `hide_replaced_occurrence` le prennent avant d'effacer une occurrence dépliée. Sans lui, le
  worker qui venait de lire la série réécrirait l'occurrence qu'on vient de remplacer (doublon).
  La clé (`hashtextextended(id::text, 0)`) est un contrat partagé avec `lockSeriesQuery` côté Go.
- **`public.my_agenda(from, to)`** (SECURITY INVOKER, plage ≤ 93 jours) renvoie les instances
  affichables : ponctuels, occurrences modifiées, occurrences dépliées ; chaque ligne porte
  `series_id` et `original_start` (nuls pour un ponctuel ; `event_id = series_id` pour une
  occurrence dépliée).
- **Modifier toute la série depuis une occurrence** : `public.update_series(série, créneau de
  l'occurrence, …)` (SECURITY INVOKER : RLS et droits par colonne s'appliquent) **décale** la
  série d'autant que l'occurrence — écart de jours, lu dans le fuseau de la série (en UTC pour
  une journée entière), et nouvelle heure **locale** de l'occurrence ; la durée est celle de
  l'occurrence modifiée. Sans changement de date ni d'heure, l'horaire et donc les exceptions
  restent intacts. Avec `p_follow_weekdays`, les jours d'un BYDAY simple suivent le même écart
  (`private.shift_weekdays`, triés du lundi au dimanche ; une règle à jour ordinal « 2TU » n'est
  jamais réécrite) : l'écart se compte dans le fuseau de la série, pas celui de l'appareil. Ne
  jamais réécrire la ligne maîtresse avec les dates d'une occurrence : la série sauterait à
  cette date et perdrait ses exceptions.
- **Une occurrence modifiée porte la règle de sa série** dans `my_agenda` (sa propre ligne n'en a
  pas) : l'app en bâtit ses brouillons, et une règle vide transformerait la série en rdv unique.
- **`public.replace_occurrence(...)`** remplace une occurrence (RPC plutôt qu'un upsert : Postgres
  refuse un index unique **partiel** comme cible d'`ON CONFLICT`, erreur `42P10`).
  **`public.delete_occurrence(série, créneau)`** ajoute le créneau aux `exdates`, efface un
  remplaçant éventuel et l'occurrence dépliée.
- **Notification** : tout changement d'une série (`events_notify_recurrence`) fait `pg_notify`
  sur `agora_recurrence` avec l'identifiant de la série, jamais de contenu.
- **Temps réel** : seules `events` et `series_expansions` sont dans `supabase_realtime`. Realtime
  n'applique **pas** la RLS aux suppressions : un `DELETE` part vers tous les abonnés avec la clé
  primaire de la ligne. `event_occurrences` n'est donc jamais publiée (sa clé porte l'horaire, et
  le worker réécrit les occurrences à chaque dépliage), aucune table publiée n'est en
  `REPLICA IDENTITY FULL`, et les deux tables publiées ne laissent fuir qu'un identifiant opaque.
- **`series_expansions`** : une ligne par série, horodatée par le worker quand un dépliage a
  réellement changé ses occurrences ; lisible par qui lit la série. C'est le signal qui fait
  relire l'agenda une fois la série dépliée, chez le créateur comme chez les membres du groupe.

## Les agendas de chacun

Migration : `20260921220000_calendar_management.sql`.

- **Plusieurs agendas natifs par personne**, chacun avec nom, couleur (`#RRGGBB`, palette de
  l'app) et **masquage pour les groupes** (`calendars.visibility` : selon le groupe, occupé,
  invisible — il entre dans la règle du « plus restrictif », §3 de l'architecture). L'agenda par
  défaut, où se créent les rdv, est le plus ancien où l'on peut écrire.
- **Ranger un rdv dans un autre agenda** : `calendar_id` est modifiable ; la RLS
  (`can_edit_event` sur l'ancienne ligne **et** la nouvelle) exige un agenda natif où l'on écrit.
  Une série emmène ses occurrences modifiées (`private.follow_series_calendar`) ; une occurrence
  seule ne change pas d'agenda (`check_event_series` : `invalid_series`), d'où l'app qui ne
  propose alors que « toute la série ». **Seul le créateur** d'un rdv le change d'agenda
  (`private.check_event_move`, sinon `event_not_found`) : sur la ligne d'arrivée, la RLS accepte
  tout agenda dont on est propriétaire sans regarder le créateur, et un admin de groupe aurait
  pu sortir le rdv d'un membre vers son agenda personnel, hors de portée du créateur.
- **Supprimer un agenda** : `public.delete_calendar(id)`, ses rdv partent en cascade. Le DELETE
  direct est retiré : la RPC refuse le **dernier agenda natif** (`last_native_calendar`), en
  verrouillant les agendas de la personne avant de compter (deux suppressions simultanées ne
  vident pas le compte). Une contrainte ou un trigger aurait aussi bloqué la cascade de la
  suppression du compte.
- **Agendas de proches** (`20261007120000_contact_calendars.sql`, test
  `contact_calendars_test.sql`) : l'agenda qu'on tient pour quelqu'un d'autre — ses repos, son
  anniversaire —, natif ou importé par lien iCal (`add_ics_calendar(…, p_contact => true)` : le
  planning d'un ami en roulement ; il compte dans les dix liens iCal par personne, qui bornent
  la charge du worker). Marqué `calendars.contact`, il est **à soi seul** : toujours
  `invisible` (contrainte, qui dit `is not distinct from` — une visibilité nulle passerait sinon),
  marquage non modifiable (aucun droit d'`UPDATE` sur la colonne), jamais l'agenda par défaut
  (app et `creer_rdv`), jamais compté comme « dernier agenda natif ». Surtout,
  `private.resolve_group_agenda` l'écarte **même pour son propriétaire** : elle rend à chacun ses
  propres rdv en détail quelle que soit leur visibilité, et les repos de Léa seraient sinon
  devenus les créneaux pris d'Ana dans la vue du groupe, « Trouver un créneau », `/dispo` et
  l'assistant. `my_agenda` les rend, et l'assistant les reçoit marqués `proche`. Pas de lien avec
  un compte Agora : rattacher par adresse révélerait qu'une adresse est inscrite.
- **Proches dans l'app** : l'onglet Social les liste (`ContactsSection`) sous « À venir » — les
  dates à retenir des 31 prochains jours (`upcomingAnniversariesProvider`). Trois sortes de rdv
  d'un proche se reconnaissent à leur forme (`contact_agenda.dart`), sans marquage de plus en
  base : une **date à retenir** est une journée entière répétée chaque année, des **horaires de
  travail** un rdv horaire répété chaque semaine, un **congé** une journée (ou une période)
  entière qui n'est pas une date à retenir. « Ajouter un proche » crée l'agenda
  (`createCalendar` rend son identifiant) puis ouvre sa page (`/contacts/:calendarId`,
  `ContactScreen`) : ce qui y est noté en ce moment (`contactMoment`), ses rdv à venir, et
  quatre raccourcis. Anniversaire, Horaires de travail et Congé ouvrent un **formulaire court**
  (`ContactEventEditor`) : un titre et une date ; les jours, les heures (une fin avant le début
  finit le lendemain), le lieu, le premier et le dernier jour ; une période. Les **repos ne se
  notent pas** : un jour sans horaires de travail, quand le proche en a d'autres jours, est un
  repos (`ContactMoment.isRestDay`), et un congé l'emporte sur les horaires des jours qu'il
  couvre (`withoutWorkOnDaysOff`, sur la page seulement : l'agenda montre ce qui est noté). Un
  rdv reconnu s'ouvre dans son formulaire court d'où qu'on l'ouvre (`event_actions.dart`) et se
  modifie en entier, sans la question de portée — sauf s'il porte plus que le formulaire ne
  montre (`contactFormFor` : des notes, un rythme, une règle avancée), qui garde l'éditeur
  complet. « Ajouter » ouvre l'éditeur complet. « Importer son planning » ouvre l'import iCal en
  mode proche : le planning importé est un agenda de proche à part, en lecture seule (sa page
  n'a ni raccourci ni ajout). Ces lectures passent par `agendaProvider`, pas l'agenda visible :
  masquer un proche de sa vue ne fait pas oublier son anniversaire. L'éditeur de rdv n'offre
  pas de réglage de visibilité dans l'agenda d'un proche.
- **Proche relié à un membre** (`20261008120000_contact_member.sql`, test
  `contact_member_test.sql`) : `calendars.contact_user_id` désigne un co-membre de groupe. Il se
  pose depuis la page du proche (« Relier », parmi `coMembersProvider` moins les membres déjà
  reliés) ou depuis la liste des membres d'un groupe (« Ajouter à mes proches » :
  `create_member_contact` rend le proche existant ou en crée un à son nom). Relié, le proche
  prend le nom du membre et le suit **en base** (trigger sur `profiles`) tant qu'ils partagent un
  groupe : l'app, l'assistant et la liste des proches lisent le même `calendars.name`, et
  l'éditeur d'agenda ne laisse pas le changer à la main. Sa page montre ce que ce membre partage
  dans les groupes communs, sept jours (`ContactSharedAgenda`, `memberAgendaProvider` :
  `group_agenda()` groupe par groupe, réunis par `memberSharedAgenda`). Le lien n'appartient
  qu'au propriétaire (RLS des agendas) : le membre n'en sait rien. Il ne change rien à la vie
  privée des rdv du proche, toujours hors des vues de groupe.
- **Masquer un agenda dans SA vue** : `public.calendar_preferences (user_id, calendar_id,
  hidden)`, une ligne par personne et par agenda (prête pour les agendas de groupe). C'est de
  l'**affichage**, pas de la vie privée : rien ne change pour les groupes. L'app filtre
  localement (`visibleAgendaProvider`), sans relire les rdv. Le droit `update (calendar_id)` sur
  la table existe pour l'upsert de PostgREST, qui réécrit toutes les colonnes envoyées ; la RLS
  garde la ligne sur un agenda lisible.

## Le worker déplie (Go, `worker/recurrence/`)

- **Seule implémentation des RRULE du projet** (`teambition/rrule-go`). `Expand` est pure : elle
  déplie dans le fuseau de la série (18 h à Paris reste 18 h après le changement d'heure ; testé
  au passage du 25 octobre 2026), en UTC pour une journée entière, saute `exdates` et créneaux
  remplacés, et tronque à `MaxOccurrences` (2000) une règle aberrante.
- **Fenêtre glissante** : un an en arrière, deux ans en avant, autour de l'instant du dépliage.
  Un dépliage complet toutes les 6 heures la fait avancer.
- **Service** : `Refresh(série)` passe à `Store.UpdateOccurrences` un calcul (`Compute`) :
  série disparue ou redevenue ponctuelle → aucune occurrence ; règle invalide → erreur, et les
  précédentes restent. `RefreshAll` continue après l'échec d'une série et remonte tous les
  échecs ; `Run` traite les notifications (uuid vérifié par regex, le reste ignoré), les
  demandes de dépliage complet et le tick périodique.
- **Écoute** : `database.Listen` (partagée avec l'import iCal) tient une connexion dédiée
  (jamais une du pool) en `LISTEN agora_recurrence`, se reconnecte avec repli exponentiel
  (1 s → 1 min) ; l'abonnement du dépliage **demande un dépliage complet à chaque
  (re)connexion** : les notifications émises pendant une coupure sont perdues.
- **Écriture** : `UpdateOccurrences` prend le verrou de la série, relit la série, calcule et
  remplace ses occurrences dans **une seule transaction** (ni les RPC d'exception ni une seconde
  instance du worker ne s'intercalent), par un `INSERT … FROM unnest(...)` : Postgres refuse
  `COPY` sur une table protégée par RLS. Des occurrences identiques à celles en base ne sont pas
  réécrites ; sinon la série est signalée dans `series_expansions` (sauf si elle a disparu
  entre-temps).
- **Rôle `agora_worker`** : `SELECT` sur les **seules colonnes d'horaire** de `events` (jamais
  titre, lieu ni description), `SELECT/INSERT/DELETE` sur `event_occurrences`,
  `SELECT/INSERT/UPDATE` sur `series_expansions`, rien d'autre (ni profils, ni schéma
  `private`). Créé `NOLOGIN` par la migration ; le mot de passe est posé par `supabase/seed.sql`
  en local et par le déploiement en prod (coffre). Configuration : `AGORA_DATABASE_URL` (obligatoire, jamais journalisée en clair).
- **Base de fuseaux embarquée** (`time/tzdata`) : l'image Docker minimale n'en a pas.

## L'agenda dans l'app (`app/lib/src/features/calendar/`)

- **kalender** (MIT, 0.31) dessine les vues jour, semaine, mois et planning (**paginé** : la
  variante continue publie sa plage totale comme plage visible, ce qui rendait le chargement
  impossible à borner). Sur téléphone (moins de 600 px), la semaine devient **trois jours
  glissants** qui commencent aujourd'hui (`MultiDayViewConfiguration.custom`, plage alignée sur
  le jour) : `week(numberOfDays: 3)` ne fait que raccourcir une semaine paginée au lundi, et ne
  montrait jamais jeudi–dimanche. Toutes les vues se calent sur aujourd'hui quand on y arrive
  depuis une plage qui le contient (`keepTodayInView`) : kalender reprenait le début de la plage
  quittée, et un 1er du mois, le mois et le planning ouvraient le mois précédent.
- **Barre d'agenda** (`AgendaToolbar`, partagée avec l'agenda d'un groupe) : le nom de la
  période affichée (`agendaPeriodLabel` : « 5 – 11 octobre 2026 », « 28 sept. – 4 oct. 2026 »,
  « Octobre 2026 » ; la grille d'un mois, qui déborde sur ses voisins, porte le nom du mois de
  son milieu), la navigation et le choix de la vue. Sous 840 px (téléphone), **une seule ligne**
  de la hauteur d'une barre de titre — la période à gauche, puis aujourd'hui, précédent,
  suivant, le menu des vues et les actions de l'écran — et l'onglet Agenda n'a pas d'autre barre
  de titre : la grille garde sa hauteur. Au-delà, les vues en segments à gauche, « ‹ Aujourd'hui
  › » au centre (`NavigationToolbar`), les actions à droite, la période dessous. Sous 600 px, la
  « semaine » s'appelle « 3 jours » (`agendaViewLabel`), et la vue mois abrège les jours
  (« lun. », `agendaComponents`).
- **Vue mois d'un téléphone** (moins de 600 px, agenda perso) : une **pastille** par rdv (barre de
  la couleur de son agenda, sans texte) et, dessous, la liste du jour choisi ; toucher un jour le
  choisit au lieu de créer un rdv. Des titres tronqués à trois lettres ne se lisaient pas. Une
  ligne du mois ne fait qu'une soixantaine de dp : le numéro du jour y passe à 28 dp, sans la
  zone tactile de 48 dp qu'un bouton garde même désactivé, sinon une seule pastille tenait et la
  suivante devenait « +1 ». Ces thèmes enveloppent l'agenda en permanence (vides hors du mois
  d'un téléphone) : les poser seulement à l'entrée dans la vue recréait kalender, dont les
  écouteurs visaient alors un widget détaché.
- **Un appui sur un de mes rdv ouvre sa fiche de lecture** (`event_sheet.dart`) : quand, où (avec
  « Y aller »), répétition, agenda, ce qu'en voient les groupes (« Pour toi seul » pour un
  proche), puis Modifier et Supprimer, qui passent par `event_actions.dart`. Le planning importé
  d'un proche s'y lit seulement ; un autre rdv importé ouvre la fiche qui règle sa visibilité.
  Un rdv de proche porte une petite silhouette sur sa tuile.
- **Tests d'écran** : le robot annonce un écran de taille nulle, donc la mise en page de
  téléphone ; `pumpApp(screenSize: …)` pose un vrai écran (semaine complète au-delà de 600 px).
  Sans écran posé, la surface fait 800 × 800 px : sous la barre d'agenda, c'est ce qui laisse à
  la grille horaire la place de construire les tuiles de 10 h et 18 h que les parcours touchent.
- **Glisser-déposer et étirement** (`onEventChanged`) sur les rdv d'un agenda où l'on écrit :
  appui long sur téléphone, glisser direct à la souris. Pour une occurrence, la question
  « déplacer cette occurrence ou toute la série » ; annulation ou échec remettent la tuile en
  place (`_syncEvents(force: true)`). Pas de création par glisser : un appui sur un créneau ouvre
  déjà l'éditeur. kalender part du **bord** de la tuile saisie pour calculer la case d'arrivée.
- **Resynchronisation** : les instances ne sont repoussées dans kalender que si la liste ou les
  agendas ont changé (identité) — une reconstruction en plein glisser ne remet pas la tuile en
  place.
- **Plage chargée** : le mois de la page visible ± un mois, rechargée quand la page en sort ;
  une plage visible de plus de 62 jours est ignorée. Le rechargement est différé à la fin de
  l'image (`addPostFrameCallback`) : kalender publie sa plage visible pendant sa construction.
- **`agendaProvider(range)`** (famille autoDispose) lit `my_agenda` ; il est invalidé par le flux
  temps réel **et** par `CalendarService` après chaque action réussie — l'utilisateur voit sa
  modification même sans Realtime (pile locale allégée, coupure). Le canal s'abonne à `events`
  et `series_expansions`, **exactement** les tables publiées : un abonnement à une table hors
  publication fait échouer tout le canal.
- **`EditTarget`** porte la portée d'une modification ou suppression : `occurrence` (une
  occurrence d'une série → `replace_occurrence` / `delete_occurrence`) ou `series` (toute la
  série → `update_series`, ou le rdv ponctuel lui-même). Le dialogue de portée n'est posé que
  pour une instance de série.
- **Toute la série, côté app** (`CalendarService.seriesDraft`) : ce que l'utilisateur a changé
  dans les dates s'applique en **écart au créneau d'origine** de l'occurrence (pas à sa place
  actuelle, qui peut déjà être décalée). Si l'utilisateur n'a pas touché aux jours de
  répétition (`weekdaysUntouched`), l'app demande au serveur de les faire suivre : un rdv du
  mardi glissé au mercredi se répète le mercredi. L'app ne compte aucun écart de jours elle-même
  (le fuseau de l'appareil peut différer de celui de la série).
- **`RecurrenceRule`** couvre le sous-ensemble éditable (fréquence, intervalle, jours, fin par
  date ou nombre). L'éditeur en expose les jours et le rythme d'une répétition hebdomadaire
  (une semaine sur 1 à 4) et la date de fin (incluse : jusqu'à 23 h 59 locales ce jour-là) ;
  sans jour coché, la règle n'a pas de `BYDAY` et suit le jour du rdv. Une règle importée hors de ce sous-ensemble se lit `null`, s'affiche « règle
  avancée » et repart **telle quelle** (`EventDraft.rawRule`) : l'app ne réécrit jamais une
  RRULE qu'elle ne sait pas représenter.
- **Dates** : l'éditeur saisit en heure locale de l'appareil et stocke en UTC. Une journée
  entière est une **date de calendrier** : stockée de minuit UTC à minuit UTC (fin exclue), elle
  se lit sur ses composants UTC (`AgendaItem.localStart`/`localEnd`), **jamais** par
  `toLocal()`, qui la reculerait d'un jour dans un fuseau négatif ; kalender la reçoit en
  minuit local. L'éditeur montre le dernier jour **inclus** et rajoute un jour à
  l'enregistrement. Le fuseau de répétition d'une série est celui du profil.
- **Tuiles** : les journées entières vivent dans l'en-tête de kalender (vues jour et semaine),
  qui reçoit les mêmes `TileComponents` que le corps — sinon elles s'affichent sans titre.
- **Rdv de groupe dans l'agenda perso** : ils y figurent (agendas de mes groupes, lisibles par la
  RLS), ne se déplacent pas, et ouvrent leur fiche au lieu de l'éditeur ; ma réponse (`my_response`
  de `my_agenda`) marque la tuile — absent : estompée et barrée. Détail :
  [`groups-architecture.md`](./groups-architecture.md) « Rdv de groupe et réponses ».
- **Actions partagées** (`event_actions.dart`) : ouvrir l'éditeur, poser la question de portée,
  appeler le service et afficher l'issue (un message remplace le précédent) — pour l'agenda comme
  pour la fiche d'un rdv de groupe.
- **Visibilité** d'un rdv ou d'un agenda pour les groupes : hérite, occupé ou invisible — jamais
  « détails » (contrainte serveur : ils ne peuvent que restreindre). `VisibilityField` sert aux
  deux éditeurs.
- **« Agendas affichés »** (`shown_calendars_sheet.dart`, bouton de la barre d'agenda) : une case
  par agenda — les miens, ceux des proches, ceux des groupes sous leur nom actuel — pour le
  montrer ou le masquer dans sa vue ; la feuille rappelle que rien ne change pour les groupes.
- **« Mes agendas »** (`CalendarsScreen`, onglet Moi) : mes agendas à moi (ni proches ni
  groupes), ce qu'en voient les groupes, création, import et modification
  (`CalendarEditorScreen`, qui renvoie un résultat comme l'éditeur de rdv ; les actions sont
  partagées avec l'onglet Social dans `calendars_actions.dart`). La suppression
  annonce le nombre de rdv perdus (une série compte pour un) ; le dernier agenda natif n'a pas
  de bouton de suppression. Les tuiles prennent la couleur de leur agenda, texte clair ou
  foncé selon la luminance. L'éditeur de rdv propose l'agenda à partir de deux agendas.

## Fichiers

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20260921185718_agenda_series.sql` | séries, exceptions, `my_agenda`, `delete_occurrence`, notification, temps réel, `series_expansions`, rôle du worker |
| `supabase/migrations/20260921194052_replace_occurrence.sql` | `replace_occurrence` |
| `supabase/migrations/20260921220000_calendar_management.sql` | agendas multiples : déplacement entre agendas, `delete_calendar`, `calendar_preferences` |
| `supabase/migrations/20260921220100_update_series.sql` | `update_series` ; `my_agenda` (règle de la série sur une occurrence modifiée) |
| `supabase/migrations/20261007120000_contact_calendars.sql` · `20261008120000_contact_member.sql` | agendas de proches ; lien d'un proche à un co-membre (`link_contact`, `create_member_contact`, nom suivi) |
| `supabase/tests/agenda_test.sql` | tests pgTAP : lecture, exceptions, triggers, agenda de groupe, publication temps réel, droits du worker |
| `supabase/tests/calendars_test.sql` · `series_move_test.sql` | agendas multiples ; décalage d'une série (fuseau, heure d'été, journée entière) |
| `worker/recurrence/expand.go` · `service.go` · `pgstore.go` | dépliage, orchestration, Postgres |
| `worker/recurrence/pgstore_integration_test.go` · `worker/internal/database/listen_integration_test.go` | tests taggés `integration` contre la pile locale |
| `app/lib/src/features/calendar/domain/` | `AgendaItem`, `EventDraft`, `RecurrenceRule`, `EventVisibility`, `UserCalendar`, contrats des dépôts |
| `app/lib/src/features/calendar/application/` | `agendaProvider`, `visibleAgendaProvider`, `CalendarService`, `EditTarget`, `calendarsProvider`, `CalendarsService` |
| `app/lib/src/features/calendar/data/` | dépôts Supabase de l'agenda et des agendas, `guardPostgrest` (traduction des erreurs) |
| `app/lib/src/features/calendar/presentation/` | `CalendarScreen` (kalender, glisser-déposer), `EventEditorScreen`, `ContactEventEditor` (formulaires courts d'un proche), `CalendarsScreen`, `CalendarEditorScreen`, dialogue de portée, `CalendarKeys` |
