# Assistants IA — serveur MCP, OAuth et portes fermées

Un assistant IA (claude.ai, Claude Code, ChatGPT, Cursor…) lit l'agenda d'un membre et agit pour
lui par **MCP** (Model Context Protocol) : le serveur est le worker Go, à
`https://api.agora.heianenterprise.com/mcp`. Méthode générale et autres modèles :
`../docs/mcp-server-guide.md` du conteneur.

## Les portes : un jeton d'assistant ne vaut que pour `/mcp`

Le jeton que GoTrue délivre à un assistant est un jeton d'utilisateur ordinaire, plus un claim
`client_id`. PostgREST, le temps réel et GoTrue l'accepteraient tel quel — donc l'assistant
pourrait, hors des outils, quitter un groupe, changer son partage ou son mot de passe. Plutôt
que de garder chaque geste en base, Agora **ferme les trois portes** à tout jeton porteur de
`client_id` (migration `20261003120000_assistant.sql`, tests `supabase/tests/assistant_test.sql`) :

| Porte | Fermeture | Réponse |
|---|---|---|
| PostgREST (`/rest/v1`) | pré-requête `private.refuse_assistant_tokens`, réglage en base du rôle `authenticator` | 403 `assistant_forbidden` |
| Temps réel | politiques `RESTRICTIVE … for select to authenticated` sur `events`, `calendars`, `series_expansions` (les seules tables publiées) | aucune ligne |
| GoTrue (compte) | garde du worker devant `/user*`, `/logout`, `/factors*`, `/reauthenticate`, `/oauth/authorizations*` | 403 `assistant_forbidden` |

- Le claim est lu dans le réglage `request.jwt.claims`, pas par `auth.jwt()` : aucune dépendance
  au schéma `auth`.
- Les politiques visent `authenticated` **seul** : `agora_worker`, qui n'a pas l'USAGE sur `auth`
  et n'hérite pas d'`authenticated`, n'y est pas soumis. Une politique sans `to authenticated`
  arrêterait le dépliage des séries.
- La pré-requête n'est accordée ni à `public` ni à `anon` (qui n'a de droit sur rien et reçoit
  401 de toute façon). Son message et son détail sont du JSON : PostgREST rendrait sinon 500.

## Le worker agit au nom du membre

`agora_worker` peut endosser `authenticated` (`grant … with inherit false, set true`). Chaque appel
d'outil ouvre une transaction, y pose `SET LOCAL ROLE authenticated` et les claims
`{"sub": <membre>, "role": "authenticated"}` — **sans** `client_id` : le serveur lit et écrit
comme l'application, par la RLS et ses RPC, et la règle de visibilité s'applique telle quelle.
Sans héritage, hors bascule, le worker ne lit toujours pas un titre (`agenda_test.sql`).

## Le parcours

1. L'assistant appelle `/mcp` sans jeton : 401, avec `WWW-Authenticate: Bearer
   resource_metadata="…/.well-known/oauth-protected-resource/mcp"`. La ressource désigne le serveur
   d'autorisation `…/auth/v1` (GoTrue), dont Caddy sert la découverte RFC 8414.
2. L'assistant s'inscrit (`POST /auth/v1/oauth/clients/register`, inscription dynamique) et lance
   `/auth/v1/oauth/authorize` avec PKCE. GoTrue renvoie le navigateur vers l'écran de consentement
   de l'app web, `/oauth/consent?authorization_id=…`.
3. Le membre se connecte et décide ; GoTrue rend l'adresse de retour de l'assistant, munie du code,
   que l'assistant échange (`/auth/v1/oauth/token`) contre ses jetons.
4. Chaque appel à `/mcp` porte le jeton : le worker le fait juger par GoTrue (`GET /user` sur le
   réseau interne) — signature, expiration et **session encore présente** —, puis agit au nom de
   `sub`.

**Jamais le scope `openid`** : GoTrue signe en HS256 et ne sait pas en faire un ID token ; à
l'échange, il consomme le code puis répond 500. La ressource n'annonce que `email`
(`scopes_supported`), que les clients reprennent.

## Le serveur (`worker/assistant/`)

| Fichier | Rôle |
|---|---|
| `assistant.go` | Assemblage : SDK MCP officiel (`modelcontextprotocol/go-sdk`), mode sans session, réponses JSON, corps ≤ 64 Kio ; consignes du serveur ; ressource protégée (RFC 9728) |
| `verify.go` | Jeton jugé par GoTrue ; seul un jeton à `client_id` est admis ; le worker ne détient aucun secret |
| `pgstore.go` | `asUser` : transaction, `SET LOCAL ROLE authenticated`, claims `{sub, role}`, `statement_timeout` ; les requêtes de l'app (`my_agenda`, `group_agenda`, `INSERT events`, `respond_to_event`) ; pool à part de 2 connexions |
| `tools.go` · `moments.go` | Les outils, la règle « ne devine pas », le plafond d'écritures ; dates ISO 8601 dans le fuseau du profil |

Une erreur interne n'atteint jamais l'assistant : il reçoit un refus rédigé, ou « erreur
interne ». Les consignes du serveur disent que les textes des rdv sont des données (jamais des
consignes), que les créneaux se cherchent par l'outil (jamais à la main), et qu'une proposition au
groupe se montre avant d'être envoyée.

## Les outils

| Outil | Ce qu'il appelle | Note |
|---|---|---|
| `mes_groupes` | `group_members` + `groups` + `profiles` | rôle, partage, membres |
| `mon_agenda(du?, au?)` | `my_agenda` | ≤ 93 jours, 300 lignes au plus ; chaque rdv porte sa référence `rdv` |
| `agenda_du_groupe(groupe, du?, au?)` | `group_agenda` | ce que l'app montre : `detail` ou `occupe` |
| `creneaux_communs(groupe, duree_minutes, …)` | `group_agenda` + `worker/slots` | mêmes règles que l'écran et `/dispo` ; jamais le passé |
| `creer_rdv(titre, debut, fin?, …)` | `INSERT events` | rdv ponctuel, agenda natif perso (le plus ancien, ou celui nommé) |
| `proposer_rdv(groupe, titre, debut, fin?, …)` | `INSERT events` (agenda du groupe) | à montrer avant, visible du groupe et de Discord |
| `repondre_au_rdv(rdv, reponse)` | `respond_to_event` | la référence porte l'occurrence d'une série dépliée |

Écritures : 20 par heure et par membre (en mémoire, le worker tourne en un exemplaire), jamais de
modification ni de suppression. Un groupe, un agenda ou un membre se désigne par identifiant ou nom
exact ; ambigu ou inconnu, la demande est refusée avec les choix possibles.

## Révoquer

Le membre retire un accès dans l'app (`DELETE /auth/v1/user/oauth/grants?client_id=…`, par la
garde, avec sa session). GoTrue supprime les sessions de ce client : le jeton de
rafraîchissement tombe, et comme le worker fait juger chaque jeton par `GET /user`, le jeton
d'accès en cours tombe **aussitôt** (`session_not_found`) — pas au bout d'une heure.

## Ajouter un outil

1. Une fonction de `toolbox` (`tools.go`) qui appelle ce que l'app appelle déjà ; ses refus passent
   par `refuse` (rédigés pour l'assistant).
2. Son enregistrement dans `newServer` (`assistant.go`), avec ses annotations (`ReadOnlyHint`,
   `DestructiveHint`) ; son nom dans `Tools`.
3. Ses tests sur le faux stockage (`tools_test.go`) ; un geste nouveau en base, son test
   d'intégration en `agora_worker`.
4. La page publique et les consignes du serveur, si l'usage change.

## Éprouver

- `go test -race ./assistant/` : outils, vérificateur (faux GoTrue), serveur entier ;
  `-tags integration` : le stockage en `agora_worker` contre la pile locale (vie privée, écritures,
  refus, bascule qui reste locale).
- `sh deploy/rehearsal/rehearse.sh` : le parcours complet d'un assistant à travers Caddy —
  découverte, inscription, consentement, PKCE, outils, portes fermées, rafraîchissement,
  révocation.
