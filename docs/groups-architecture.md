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
  lieu, « invisible » absent. Les rdv de l'utilisateur lui reviennent en détail.

## Dans l'app (`app/lib/src/features/groups/`)

- **Accueil à deux onglets** (Agenda, Groupes) dans une `IndexedStack` : changer d'onglet garde
  la page de l'agenda. Chaque onglet a son bouton flottant, avec son propre `heroTag` (deux
  boutons au tag par défaut dans la même page cassent toute transition).
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
  fenêtre d'invitation **réutilise** la dernière invitation valable de l'utilisateur plutôt que
  d'en créer une à chaque ouverture (chaque code actif ouvre le groupe) ; elle se désactive d'un
  geste. L'ouverture directe de l'app Android par le lien viendra avec le domaine (App Links).
- **Agenda superposé** : les créneaux de `group_agenda`, une couleur par membre (son rang
  d'arrivée dans la palette, stable d'un écran à l'autre), « occupé » plus pâle et sans titre,
  des pastilles pour masquer un membre (filtre local à l'écran). Tuiles en lecture seule : on
  modifie ses rdv depuis son agenda. Un appui ouvre la fiche du créneau (membre, titre ou
  « occupé », horaire, lieu).
- **Pas de temps réel** pour l'agenda d'un groupe : les rdv des autres membres ne sont pas
  lisibles en direct (la RLS les cache), seule la RPC les résout. Il se relit à l'ouverture, au
  changement de plage, après chaque action, et par le bouton « actualiser ».
- **Membres** : son propre partage (réglable), puis chaque membre avec rôle et partage, et les
  actions que son rôle permet (propriétaire : admin, transmettre, exclure un membre ; admin :
  exclure un membre ; membre : rien). Le serveur revérifie tout.
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
  proposés au groupe (`created_by` passe à `null`) ; les admins les gèrent.
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
- **Pas encore** : un rdv de groupe accepté ne rend pas « occupé » dans les autres groupes (la
  résolution de visibilité ne lit que les agendas personnels). Le changer toucherait
  `private.resolve_group_agenda` : décision de vie privée en attente.

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
  tuile estompée et barrée, sans disparaître. « Mes agendas » liste les agendas de mes groupes
  (sous le nom actuel du groupe) avec la même case « afficher ».
- **Couplage** : l'écran du groupe (feature groupes) n'importe rien de la feature agenda ; il ouvre
  ses écrans par nom de route et relit son agenda au retour. La fiche lit membres et rôle par
  l'application de la feature groupes.

## Créneaux communs

« Trouver un créneau » (barre de l'agenda du groupe, route `groups/:groupId/slots`,
`FindSlotsScreen`) : les plages où tous les membres choisis sont libres.

- **Calcul dans l'app** (`domain/free_slots.dart`, fonction pure `findFreeSlots`), à partir de
  `group_agenda` : il ne voit rien de plus que l'agenda superposé. « Occupé » et détail = pris ;
  « invisible » = aucun créneau, donc **paraît libre** — l'écran nomme les membres qui ne
  partagent rien. Mes propres rdv comptent (le serveur me les rend en détail).
- **Un rdv du groupe prend le créneau pour tous.** Une journée entière ne prend rien par défaut
  (anniversaire, jour férié) ; un interrupteur la compte sur toute la journée.
- **Réglages** : durée (30 min à 3 h), période (7, 14, 30 jours), fenêtre horaire quotidienne
  (9 h–22 h par défaut ; une fenêtre qui passerait minuit est vide), week-ends, membres requis.
  Calcul en heure locale, jour par jour (18 h reste 18 h un jour de changement d'heure) ; jamais
  dans le passé (au plus tôt le quart d'heure suivant) ; 50 créneaux au plus.
- **Proposer** : un appui ouvre l'éditeur d'un rdv du groupe (route `groups/:groupId/events/new`
  avec `start` et `end`), début et fin repris tels quels ; au retour, la liste se relit.

## Fichiers

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20260922000000_group_management.sql` | `join_group` (partage), `invite_preview`, `set_member_role`, `transfer_group` |
| `supabase/tests/group_management_test.sql` · `groups_test.sql` | aperçu, partage à l'arrivée, rôles, exclusion, transmission ; inscription, invitations, droits |
| `supabase/migrations/20260922030000_group_lifecycle.sql` · `tests/group_lifecycle_test.sql` | groupe vide supprimé, propriétaire disparu remplacé (compte effacé par la cascade) |
| `supabase/migrations/20260922020000_group_events.sql` · `tests/group_events_test.sql` | réponses aux rdv de groupe, `respond_to_event`, `my_agenda` avec ma réponse ; qui propose, qui modifie, qui répond, réponses qui suivent l'instance |
| `app/lib/src/features/calendar/presentation/group_event_screen.dart` · `group_event_editor_page.dart` | fiche d'un rdv de groupe (réponses), proposition d'un rdv |
| `app/lib/src/features/groups/domain/free_slots.dart` · `presentation/find_slots_screen.dart` | calcul des créneaux communs (pur, testé seul), écran de recherche |
| `app/lib/src/features/groups/domain/` | `MyGroup`, `GroupMember`, `GroupRole`, `ShareLevel`, `GroupInvite`, `InvitePreview`, `GroupAgendaItem`, contrat du dépôt |
| `app/lib/src/features/groups/data/supabase_groups_repository.dart` | PostgREST : jointures `group_members`→`groups`/`profiles`, RPC |
| `app/lib/src/features/groups/application/groups_providers.dart` | providers, `GroupsService`, `PendingInvite`, `looksLikeInviteCode` |
| `app/lib/src/features/groups/presentation/` | liste, éditeur, « Rejoindre », agenda du groupe, membres, invitation, `GroupKeys` |
| `app/lib/src/common_widgets/agenda_view.dart` | vues kalender, barre, `VisibleRangeFollower` (partagés avec l'agenda perso) |
