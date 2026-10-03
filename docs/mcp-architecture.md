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
