-- =============================================================================
-- Assistants IA : le serveur MCP du worker agit au nom d'un membre, et le jeton
-- d'un assistant ne vaut que pour /mcp.
--
-- Un assistant (claude.ai, Claude Code, ChatGPT…) obtient son jeton du serveur
-- OAuth de GoTrue. Ce jeton est un jeton d'utilisateur ordinaire, plus un claim
-- `client_id` : PostgREST, le temps réel et GoTrue l'accepteraient tel quel.
-- On le borne donc à /mcp, où le worker n'offre que quelques outils :
--
--   1. le worker peut endosser `authenticated` le temps d'une transaction
--      (SET LOCAL ROLE + claims {sub}) : ses outils passent par la RLS et les
--      RPC de l'application, exactement comme elle. Sans héritage : sa
--      politique « le worker lit tout » sur events lui ouvrirait sinon les
--      titres hors bascule ;
--   2. PostgREST refuse tout jeton porteur de `client_id`, par une fonction de
--      pré-requête (réglage en base du rôle authenticator, valable en local
--      comme en prod) ;
--   3. le temps réel aussi : une politique RESTRICTIVE, réservée à
--      `authenticated`, masque les trois tables publiées à un tel jeton.
--      Le worker, qui pose des claims SANS client_id, lit comme l'application.
--      La troisième porte, celle des routes de compte de GoTrue, est la garde
--      du worker (worker/authgate/guard.go).
--
-- Choix non évidents :
--   - le claim est lu dans le réglage request.jwt.claims, pas par auth.jwt() :
--     aucune dépendance au schéma auth ;
--   - les politiques visent `authenticated` seul : agora_worker, qui n'a pas
--     l'USAGE sur auth et n'hérite pas d'authenticated, n'y est pas soumis ;
--   - la pré-requête n'est accordée ni à anon (qui n'a de droit sur rien et
--     reçoit 401 de toute façon) ni à public. Message et détail de l'erreur
--     sont du JSON : PostgREST rendrait sinon 500 au lieu de 403.
--
-- Invariants (supabase/tests/assistant_test.sql) : le worker endosse sans
-- hériter ; un jeton d'assistant ne lit rien par PostgREST ni par le temps
-- réel ; une session de l'application, et le worker, gardent leurs lectures.
-- =============================================================================

-- 1. Bascule de rôle du worker ---------------------------------------------------------------
grant authenticated to agora_worker with inherit false, set true;

-- 2. Pré-requête de PostgREST ----------------------------------------------------------------
create function private.refuse_assistant_tokens()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if nullif(current_setting('request.jwt.claims', true), '')::jsonb ? 'client_id' then
    raise sqlstate 'PGRST' using
      message = '{"code":"assistant_forbidden","message":"assistant tokens are only valid for /mcp","details":null,"hint":null}',
      detail = '{"status":403,"headers":{}}';
  end if;
end;
$$;

revoke execute on function private.refuse_assistant_tokens() from public, anon;
grant execute on function private.refuse_assistant_tokens() to authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'private.refuse_assistant_tokens';
notify pgrst, 'reload config';

-- 3. Temps réel : rien pour le jeton d'un assistant -----------------------------------------
create policy "events: pas de jeton d'assistant" on public.events
  as restrictive for select to authenticated
  using ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'client_id') is null);
create policy "calendars: pas de jeton d'assistant" on public.calendars
  as restrictive for select to authenticated
  using ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'client_id') is null);
create policy "series_expansions: pas de jeton d'assistant" on public.series_expansions
  as restrictive for select to authenticated
  using ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'client_id') is null);
