# Groupes — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §2-3. Elle décrit la vie d'un groupe (créer,
inviter, rejoindre, rôles, quitter) et son agenda superposé dans l'app.

## En base

Migrations : `20260921120000_core_schema.sql` (tables, RLS, `create_group`, `create_invite`,
`group_agenda`, `resolve_group_agenda`), `20260922000000_group_management.sql` (le reste).

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
  simultanées se sérialisent. **Invariant : un seul propriétaire.**
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

## Fichiers

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20260922000000_group_management.sql` | `join_group` (partage), `invite_preview`, `set_member_role`, `transfer_group` |
| `supabase/tests/group_management_test.sql` · `groups_test.sql` | aperçu, partage à l'arrivée, rôles, exclusion, transmission ; inscription, invitations, droits |
| `app/lib/src/features/groups/domain/` | `MyGroup`, `GroupMember`, `GroupRole`, `ShareLevel`, `GroupInvite`, `InvitePreview`, `GroupAgendaItem`, contrat du dépôt |
| `app/lib/src/features/groups/data/supabase_groups_repository.dart` | PostgREST : jointures `group_members`→`groups`/`profiles`, RPC |
| `app/lib/src/features/groups/application/groups_providers.dart` | providers, `GroupsService`, `PendingInvite`, `looksLikeInviteCode` |
| `app/lib/src/features/groups/presentation/` | liste, éditeur, « Rejoindre », agenda du groupe, membres, invitation, `GroupKeys` |
| `app/lib/src/common_widgets/agenda_view.dart` | vues kalender, barre, `VisibleRangeFollower` (partagés avec l'agenda perso) |
