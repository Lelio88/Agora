# Groupes — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §2-3. Elle décrit la vie d'un groupe (créer,
inviter, rejoindre, rôles, quitter), son agenda superposé dans l'app, et ses rdv avec les réponses
des membres.

## En base

Migrations : `20260921120000_core_schema.sql` (tables, RLS, `create_group`, `create_invite`,
`group_agenda`, `resolve_group_agenda`), `20260922000000_group_management.sql` (le reste),
`20260922030000_group_lifecycle.sql` (ni vide ni sans propriétaire).

| Notion | Représentation |
|---|---|
| Groupe | `groups` (nom, description) + son agenda partagé (`calendars.group_id`) |
| Appartenance | `group_members (group_id, user_id, role, share_level)` |
| Rôle | `owner` (un seul), `admin`, `member` |
| Partage | `share_level` : `details`, `busy` ou `invisible` — plafond de ce que le groupe voit de l'agenda perso du membre |
| Invitation | `group_invites (code, expires_at, max_uses, uses, created_by)` ; code de 8 caractères sans ambiguïté, 7 jours |

- **Rejoindre** : `join_group(code, p_share_level)` crée l'appartenance **avec le partage
  choisi**, dans la même transaction : un réglage posé après coup laisserait voir « occupé »
  (le défaut) à qui voulait ne rien partager. Déjà membre : rien ne change.
- **Avant de rejoindre** : `invite_preview(code)` rend nom, taille du groupe et « déjà membre ».
  Le code est le secret : un code inconnu, expiré ou épuisé répond la même erreur
  (`invite_invalid`) que `join_group`, sans dire lequel.
- **Rôles** : le propriétaire seul nomme ou retire des admins (`set_member_role`) et transmet le
  groupe (`transfer_group` : l'ancien propriétaire devient admin). Les deux verrouillent la
  ligne du groupe, comme `delete_my_account` : transmission et suppression de compte
  simultanées se sérialisent.
- **Un groupe ne reste ni vide ni sans propriétaire** (trigger `private.keep_group_alive`, après
  toute sortie d'un membre) : sans membre, il est supprimé avec son agenda et ses rdv ; sans
  propriétaire, il revient à l'admin le plus ancien, sinon au membre le plus ancien. C'est le
  filet d'un compte effacé hors de `delete_my_account` (interface d'administration de
  Supabase, qui passe par la cascade) ; les chemins ordinaires n'y touchent pas. **Invariant :
  un groupe existant a au moins un membre, et exactement un propriétaire.**
- **Par RLS directe** (pas de RPC) : renommer (admins), supprimer le groupe (propriétaire),
  régler son propre partage, quitter (sauf le propriétaire, qui transmet d'abord), exclure un
  simple membre (admins), révoquer une invitation (son auteur ou un admin), inviter (tout
  membre, `create_invite`).
- **Agenda du groupe** : `group_agenda(groupe, de, à)` (membre obligatoire, ≤ 93 jours) passe par
  `private.resolve_group_agenda`, seule sortie des rdv d'autrui (§3 de l'architecture) : niveau
  effectif = le plus restrictif de `share_level`, agenda et rdv ; « occupé » sans titre ni
  lieu, « invisible » absent. Les rdv de l'utilisateur lui reviennent en détail. Un rdv d'un
  autre groupe où un membre a répondu « présent » y figure en « occupé »
  (`20260922040000_cross_group_busy.sql`).

## Dans l'app (`app/lib/src/features/groups/`)

- **Accueil à trois onglets** (Agenda, Social, Moi) dans une `IndexedStack` : changer d'onglet
  garde la page de l'agenda. Les groupes vivent dans l'onglet Social (`GroupsSection`, sous les
  proches) ; son bouton « Ajouter » crée un groupe ou ouvre « Rejoindre » (`createGroup`,
  `joinGroupWithCode`). Chaque onglet a son bouton flottant, avec son propre `heroTag` (deux
  boutons au tag par défaut dans la même page cassent toute transition). Chaque groupe reçoit
  une couleur de la palette tirée de son identifiant (`paletteHexFor`, stable d'un lancement à
  l'autre).
- **Routes** sous l'accueil : `/groups/:groupId`, `/join` (taper le code), `/join/:code` (lien).
  Imbriquées, elles gardent l'accueil dessous : le retour y ramène, même ouvertes par un lien.
- **Invitation en attente** : un lien `/join/CODE` ouvert **déconnecté** est retenu
  (`PendingInvite`) le temps de la connexion ou de l'inscription ; `authRedirect(pendingInvite:)`
  ramène ensuite à `/join/CODE` — depuis l'accueil ou un écran de compte seulement, jamais depuis
  un autre écran. L'écran « Rejoindre » consomme l'invitation. Seul un code plausible
  (`inviteCodeInLocation`) est retenu. Une session périmée au chargement (compte disparu) perd
  l'invitation : on rouvre le lien.
- **Rejoindre** : aperçu du groupe, puis choix explicite du partage — « occupé » présélectionné,
  jamais imposé — envoyé avec l'adhésion.
- **Lien d'invitation** : `https://<site>/#/join/CODE`, l'adresse venant du build
  (`AGORA_WEB_URL`, `lib/src/config/web_links.dart`). Sans elle, seul le code est proposé. La
  fenêtre d'invitation (Membres → Inviter) **réutilise** la dernière invitation valable de
  l'utilisateur plutôt que d'en créer une à chaque ouverture (chaque code actif ouvre le
  groupe) ; elle se désactive d'un geste. Sur Android, « Partager » ouvre la feuille de partage
  du téléphone (`Sharer`, adossé à share_plus) avec le lien, ou le code sans adresse web ; sur
  le web, où share_plus retomberait sur un lien e-mail, seuls les boutons Copier restent.
  « Rejoindre » met le code en capitales et colle le presse-papiers : d'un lien reçu, il ne
  garde que le code.
- **Le lien ouvre l'app Android** (App Link) quand elle est installée. Android ne filtre pas sur
  le fragment : le filtre `autoVerify` du manifeste vise la racine `/` du site, et le routeur
  convertit `/#/join/CODE` en `/join/CODE` (`inviteRouteFromAppLink`, avant la règle de
  session : une invitation ouverte déconnecté est retenue comme sur le web). Android vérifie le
  domaine par `web/.well-known/assetlinks.json`, qui porte l'empreinte SHA-256 de la clé de
  signature Play (lue par l'API Play, `generatedApks`) et celle de la clé d'envoi. Une clé qui
  change impose de mettre ce fichier à jour, sinon le lien retombe dans le navigateur.
- **Agenda superposé** : les créneaux de `group_agenda`, une couleur par membre (son rang
  d'arrivée dans la palette, stable d'un écran à l'autre), « occupé » plus pâle et sans titre,
  des pastilles pour masquer un membre (filtre local à l'écran). Tuiles en lecture seule : on
  modifie ses rdv depuis son agenda. Un appui ouvre la fiche du créneau (membre, titre ou
  « occupé », horaire, lieu).
- **Pas de temps réel** pour l'agenda d'un groupe : les rdv des autres membres ne sont pas
  lisibles en direct (la RLS les cache), seule la RPC les résout. Il se relit à l'ouverture, au
  changement de plage, après chaque action, et par le bouton « actualiser ».
- **En tête de la page du groupe**, deux puces : « Je partage : … » (son propre partage, le
  réglage de vie privée qui compte ; un appui ouvre le choix, appliqué aussitôt) et « Trouver un
  créneau ». La barre de titre ne garde que Membres et le menu.
- **Membres** : « Inviter » en tête, puis chaque membre avec rôle et partage, et les actions
  que son rôle permet (propriétaire : admin, transmettre, exclure un membre ; admin : exclure un
  membre ; membre : rien). Le serveur revérifie tout. À côté, pour chacun et quel que soit son
  rôle, un bouton **proche** : « Ajouter à mes proches » (`create_member_contact`, un proche relié
  à ce membre et à son nom), ou la page du proche s'il l'est déjà (la ligne dit alors « dans tes
  proches »). Le lien n'est qu'à soi — voir
  [`calendar-architecture.md`](./calendar-architecture.md) §Les agendas de chacun (« Proche relié
  à un membre »).
- **Actualiser reste un bouton** de la barre d'agenda : tirer vers le bas ne convient pas à une
  grille horaire (il faudrait d'abord remonter à minuit) ni à la vue mois, qui ne défile pas.
- **Dans l'onglet Social**, chaque groupe montre son prochain rdv des 31 prochains jours
  (`nextGroupEventsProvider`, une seule lecture de `my_agenda` pour tous), sinon son rôle et son
  partage.
- **Renommer** (`renameGroup`) n'envoie que le nom : une colonne absente d'un PATCH PostgREST
  n'est pas touchée, alors qu'une description `null` envoyée l'effacerait.
- **Barre d'agenda** : chaque écran donne ses propres clés (`AgendaToolbarKeys`) — l'agenda
  perso reste monté sous l'écran d'un groupe, deux barres coexistent.
- **Quitter / supprimer** depuis le menu du groupe ; le propriétaire est invité à transmettre
  d'abord. Après coup, retour à l'écran précédent (ou à l'accueil, ouvert par un lien).

## Rdv de groupe et réponses

Migration : `20260922020000_group_events.sql`. Un rdv de groupe est un rdv de l'agenda du groupe
(`calendars.group_id`) : les règles des rdv s'appliquent telles quelles (séries, exceptions,
dépliage par le worker).

- **Proposer** : tout membre (`private.can_add_event`). **Modifier, supprimer** : son créateur et
  les admins, propriétaire compris (`private.can_edit_event`). Un compte supprimé laisse ses rdv
  proposés au groupe (`created_by` passe à `null`) ; les admins les gèrent. L'app annonce ces rdv
  au moment de supprimer le compte et propose de les effacer d'abord
  ([`auth-architecture.md`](./auth-architecture.md)).
- **Répondre** : présent / peut-être / absent (`public.response_status`), par
  `respond_to_event(rdv, créneau, réponse)` — seule écriture de `event_responses`, qui vérifie
  l'appartenance au groupe ; `null` retire la réponse. Une **série se répond occurrence par
  occurrence** (le créneau d'origine, qui doit être une occurrence dépliée) ; un rdv ponctuel ou
  une occurrence modifiée (ligne à part) sans créneau (`invalid_occurrence` sinon).
- **Lire** : les réponses d'un rdv ne sont lisibles que des membres de son groupe (RLS) ;
  `my_agenda` rend ma réponse avec chaque instance (`my_response`).
- **Les réponses suivent l'instance** (triggers) : une occurrence qui devient un rdv à part les
  emporte, et les rend à son créneau si elle disparaît (sans quoi `replace_occurrence`, qui
  supprime puis recrée la ligne à chaque modification, les effacerait) ; changer l'horaire ou la
  règle d'une série efface celles de ses occurrences, comme ses exceptions ; changer l'heure d'un
  rdv ponctuel les garde ; quitter le groupe efface les siennes.
- **Occupé ailleurs** : répondre « présent » rend occupé dans ses autres groupes, par
  `private.resolve_group_agenda` (§3 de l'architecture) — « occupé » au plus pour les autres,
  rien là où l'on ne partage rien ; « peut-être » et « absent » ne prennent pas le créneau.

Dans l'app (feature **agenda**, car ce sont des rdv : éditeur, portée, service) :

- **Proposer** depuis l'agenda du groupe : bouton « Proposer un rdv » ou appui sur un créneau
  libre → route `groups/:groupId/events/new` → `GroupEventEditorPage` (l'éditeur, rangé d'office
  dans l'agenda du groupe, sans réglage de visibilité : tous les membres le voient en détail).
- **Fiche** (`GroupEventScreen`, route `groups/:groupId/events/:eventId?start=`) : ce qu'est le
  rdv, qui l'a proposé, ma réponse (trois boutons ; rappuyer retire), les réponses par catégorie
  et les membres sans réponse ; modifier et supprimer pour le créateur et les admins. `start`
  désigne l'occurrence d'une série ; pour le reste il est ignoré. Ouverte depuis l'agenda du groupe
  comme depuis l'agenda perso.
- **Agenda perso** : les rdv de mes groupes y figurent (la RLS les rend lisibles), non
  déplaçables ; un appui ouvre leur fiche. Présent ou peut-être : une icône sur la tuile ; absent :
  tuile estompée et barrée, sans disparaître. « Agendas affichés » (barre de l'agenda) liste les
  agendas de mes groupes (sous le nom actuel du groupe) avec la même case « afficher ».
- **Couplage** : l'écran du groupe (feature groupes) n'importe rien de la feature agenda ; il ouvre
  ses écrans par nom de route et relit son agenda au retour. La fiche lit membres et rôle par
  l'application de la feature groupes.

## Créneaux communs

**Partage « Tout » et assistants IA** : sous ce niveau, à l'écran Rejoindre comme dans les
membres du groupe, l'app précise que les membres voient titres et lieux **y compris par
l'assistant IA qu'ils ont branché** (`shareDetailsAssistantHint`) : l'assistant voit ce que l'app
montre au membre ([`mcp-architecture.md`](./mcp-architecture.md)).

« Trouver un créneau » (puce en tête de la page du groupe, route `groups/:groupId/slots`,
`FindSlotsScreen`) : les plages où tous les membres choisis sont libres.

- **Calcul dans l'app** (`domain/free_slots.dart`, fonction pure `findFreeSlots`) ; le worker
  en porte la traduction (`worker/slots/`) pour `/dispo` et l'outil MCP `creneaux_communs`. À partir de
  `group_agenda` : il ne voit rien de plus que l'agenda superposé. « Occupé » et détail = pris ;
  « invisible » = aucun créneau, donc **paraît libre** — l'écran nomme les membres qui ne
  partagent rien. Mes propres rdv comptent (le serveur me les rend en détail), comme les rdv
  d'autres groupes où un membre a répondu « présent ».
- **Un rdv du groupe prend le créneau pour tous.** Une journée entière ne prend rien par défaut
  (anniversaire, jour férié) ; un interrupteur la compte sur toute la journée.
- **Réglages** : durée (30 min à 3 h), période (7, 14, 30 jours), fenêtre horaire quotidienne
  (9 h–22 h par défaut ; une fenêtre qui passerait minuit est vide), week-ends, membres requis.
  Calcul en heure locale, jour par jour (18 h reste 18 h un jour de changement d'heure) ; jamais
  dans le passé (au plus tôt le quart d'heure suivant) ; 50 créneaux au plus.
- **Proposer** : un appui ouvre l'éditeur d'un rdv du groupe (route `groups/:groupId/events/new`
  avec `start` et `end`), début et fin repris tels quels ; au retour, la liste se relit.

## Jumelage avec une autre app

Migrations : `20261005120000_group_twins.sql`, `20261009120000_twin_dewdrop.sql` ; tests :
`supabase/tests/group_twins_test.sql`, `group_twins_dewdrop_test.sql`. Un groupe Agora peut avoir
un **jumeau** par app — dans Arpente (guide de visite) et dans DewDrop (pensées entre proches) :
un groupe de l'autre app dont ses membres voient le code (« Ce groupe existe aussi dans
Arpente — Rejoindre »), et inversement. **Rejoindre un cercle DewDrop est une demande** que son
créateur accepte ou refuse : le bouton dit « Demander à rejoindre » (`TwinApp.joinIsRequest`).
Les apps ne se parlent jamais : elles s'ouvrent l'une l'autre par des liens préremplis, et la
personne valide dans l'app d'arrivée. Le protocole commun (adresses, paramètres, règles de
sécurité) est dans `docs/liens-inter-apps.md` du dépôt méta.

- **En base** : `group_twins (group_id, app, invite_code, remote_code)`, un jumeau par groupe et
  par app. `invite_code` est une invitation ordinaire **sans échéance** (`expires_at` nul) : qui
  arrive de l'autre app passe par `join_group`, donc par le choix du partage. `remote_code` nul
  = jumeau en attente de la réponse de l'autre app. Seuls les membres le lisent ; on ne l'écrit
  que par `twin_group(groupe, app, code_distant?)` (admins), qui crée le jumeau et son
  invitation ou le complète, et rend le code à donner. Le format du code distant suit l'app
  (`private.twin_code_valid` : Arpente 6 caractères, DewDrop 8), dans la contrainte de la table
  comme dans `twin_group`. **Un jumeau complet ne change pas de groupe distant**
  (`twin_exists`) : un lien forgé ne doit pas rediriger les membres en silence ; pour en
  changer, on défait d'abord. **Défaire = supprimer l'invitation** (son auteur ou un admin, RLS
  existante) : le jumeau part en cascade, et le code donné à l'autre app n'ouvre plus rien.
- **Le prix d'une invitation permanente** : un membre parti ou exclu qui a noté son code peut
  revenir tant que le jumelage tient. Défaire puis rejumeler change le code ; c'est le geste à
  faire après une exclusion qui compte.
- **La fenêtre « Inviter » ignore l'invitation du jumeau** : elle ne reprend que les invitations
  à échéance future, et `create_invite` refuse toujours plus de 30 jours.
- **Liens** (`domain/twin.dart`, pur ; une entrée de `TwinApp` par app) : reçus sur
  `#/twin?de=…&code=…&nom=…&etat=…` (demande) ou `…&pour=…` (réponse) ; envoyés vers la page
  `jumeler.html#…` de l'autre app (`TwinApp.twinPage`), les paramètres dans le **fragment** (un
  code est un secret : une requête finirait dans les journaux de GitHub Pages). Un lien reçu
  n'est jamais gardé tel quel : seuls l'app (liste fermée) et un code validé par son format en
  sont tirés ; le bouton « Rejoindre » reconstruit l'adresse depuis la base fixe de l'app.
- **Lancé depuis Agora** (menu du groupe → Jumelage, admins ; une section par app) :
  `twin_group` sans code distant, puis la demande s'ouvre dans l'autre app avec un jeton neuf.
  La réponse n'est acceptée que si elle répond à une demande partie **de cet appareil**
  (`TwinRequests`, en mémoire : même jeton, même invitation) — sinon un membre qui connaît une
  invitation du groupe pourrait faire rattacher un groupe distant à lui. Une app fermée
  entre-temps fait relancer, ce qui reprend la même invitation.
- **Lancé depuis l'autre app** : l'écran `/twin` propose un nouveau groupe (nommé comme le
  jumeau) ou un groupe que l'on gère, jumelle, puis ouvre la réponse dans l'autre app. Si elle
  ne s'ouvre pas, le jumeau reste enregistré ici et l'écran le dit.
- **Routage** : l'App Link de la racine suit aussi `#/twin` (`appLinkRoute`) ; ouvert déconnecté,
  le lien est retenu (`PendingTwin`) comme une invitation, après elle.
- **Hors des assistants IA et de Discord** : aucun outil ne lit les jumeaux ni leurs codes.

## Fichiers

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20260922000000_group_management.sql` | `join_group` (partage), `invite_preview`, `set_member_role`, `transfer_group` |
| `supabase/tests/group_management_test.sql` · `groups_test.sql` | aperçu, partage à l'arrivée, rôles, exclusion, transmission ; inscription, invitations, droits |
| `supabase/migrations/20260922030000_group_lifecycle.sql` · `tests/group_lifecycle_test.sql` | groupe vide supprimé, propriétaire disparu remplacé (compte effacé par la cascade) |
| `supabase/migrations/20260922040000_cross_group_busy.sql` · `tests/cross_group_busy_test.sql` | « présent » à un rdv d'un autre groupe = « occupé » ici |
| `supabase/migrations/20260922020000_group_events.sql` · `tests/group_events_test.sql` | réponses aux rdv de groupe, `respond_to_event`, `my_agenda` avec ma réponse ; qui propose, qui modifie, qui répond, réponses qui suivent l'instance |
| `app/lib/src/features/calendar/presentation/group_event_screen.dart` · `group_event_editor_page.dart` | fiche d'un rdv de groupe (réponses), proposition d'un rdv |
| `app/lib/src/features/groups/domain/free_slots.dart` · `presentation/find_slots_screen.dart` | calcul des créneaux communs (pur, testé seul), écran de recherche |
| `app/lib/src/features/groups/domain/` | `MyGroup`, `GroupMember`, `GroupRole`, `ShareLevel`, `GroupInvite`, `InvitePreview`, `GroupAgendaItem`, contrat du dépôt |
| `app/lib/src/features/groups/data/supabase_groups_repository.dart` | PostgREST : jointures `group_members`→`groups`/`profiles`, RPC |
| `app/lib/src/features/groups/application/groups_providers.dart` | providers, `GroupsService`, `PendingInvite`, `looksLikeInviteCode` |
| `app/lib/src/features/groups/presentation/` | liste, éditeur, « Rejoindre », agenda du groupe, membres, invitation, `GroupKeys` |
| `supabase/migrations/20261005120000_group_twins.sql` · `tests/group_twins_test.sql` | jumeau d'un groupe, invitation sans échéance, `twin_group`, défaire par l'invitation |
| `app/lib/src/features/groups/domain/twin.dart` · `application/twin_providers.dart` | protocole des liens (pur), `TwinService`, `TwinRequests`, `PendingTwin` |
| `app/lib/src/features/groups/presentation/twin_group_screen.dart` · `twin_sheet.dart` | écran `/twin` (demande, réponse), bandeau « Rejoindre aussi », feuille des admins |
| `app/lib/src/common_widgets/agenda_view.dart` | vues kalender, barre, `VisibleRangeFollower` (partagés avec l'agenda perso) |
