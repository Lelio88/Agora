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

- **kalender** (MIT, 0.31) dessine les vues jour, semaine (3 jours sur téléphone), mois et
  planning (**paginé** : la variante continue publie sa plage totale comme plage visible, ce qui
  rendait le chargement impossible à borner).
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
  date ou nombre). Une règle importée hors de ce sous-ensemble se lit `null`, s'affiche « règle
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
- **« Mes agendas »** (`CalendarsScreen`, bouton de la barre d'agenda) : liste des agendas
  personnels avec leur masquage, case d'affichage, création et modification
  (`CalendarEditorScreen`, qui renvoie un résultat comme l'éditeur de rdv). La suppression
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
| `supabase/tests/agenda_test.sql` | tests pgTAP : lecture, exceptions, triggers, agenda de groupe, publication temps réel, droits du worker |
| `supabase/tests/calendars_test.sql` · `series_move_test.sql` | agendas multiples ; décalage d'une série (fuseau, heure d'été, journée entière) |
| `worker/recurrence/expand.go` · `service.go` · `pgstore.go` | dépliage, orchestration, Postgres |
| `worker/recurrence/pgstore_integration_test.go` · `worker/internal/database/listen_integration_test.go` | tests taggés `integration` contre la pile locale |
| `app/lib/src/features/calendar/domain/` | `AgendaItem`, `EventDraft`, `RecurrenceRule`, `EventVisibility`, `UserCalendar`, contrats des dépôts |
| `app/lib/src/features/calendar/application/` | `agendaProvider`, `visibleAgendaProvider`, `CalendarService`, `EditTarget`, `calendarsProvider`, `CalendarsService` |
| `app/lib/src/features/calendar/data/` | dépôts Supabase de l'agenda et des agendas, `guardPostgrest` (traduction des erreurs) |
| `app/lib/src/features/calendar/presentation/` | `CalendarScreen` (kalender, glisser-déposer), `EventEditorScreen`, `CalendarsScreen`, `CalendarEditorScreen`, dialogue de portée, `CalendarKeys` |
