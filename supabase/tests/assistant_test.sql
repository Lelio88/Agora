-- Assistants IA (serveur MCP du worker) : le jeton d'un assistant ne vaut que
-- pour /mcp, et le worker n'agit au nom d'un membre que par bascule de rôle.
--   - agora_worker peut endosser `authenticated` sans en hériter les droits ;
--   - PostgREST refuse tout jeton porteur de `client_id` (pré-requête) ;
--   - le temps réel (tables publiées) ne montre rien à un tel jeton ;
--   - le membre, lui, garde toutes ses lectures, comme le worker les siennes.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, raw_user_meta_data) values
  ('a5500000-0000-0000-0000-000000000001', 'lea@test.local', '{"display_name":"Léa"}');

insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, created_by)
select 'a5500000-0000-0000-0000-0000000000e1', c.id, 'Piscine',
       '2026-10-06 16:00+00', '2026-10-06 17:00+00', 'Europe/Paris', 'FREQ=WEEKLY', c.owner_id
from public.calendars c where c.owner_id = 'a5500000-0000-0000-0000-000000000001';
insert into public.series_expansions (series_id) values ('a5500000-0000-0000-0000-0000000000e1');

-- Bascule de rôle du worker ---------------------------------------------------------------
select ok(pg_has_role('agora_worker', 'authenticated', 'SET'),
  'le worker peut endosser authenticated, le temps d''une transaction');
select ok(not pg_has_role('agora_worker', 'authenticated', 'USAGE'),
  'sans en hériter les droits : hors bascule, il ne lit toujours pas les titres');

-- Pré-requête de PostgREST ------------------------------------------------------------
select ok(
  (select 'pgrst.db_pre_request=private.refuse_assistant_tokens' = any(s.setconfig)
     from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
    where r.rolname = 'authenticator' and s.setdatabase = 0),
  'PostgREST appelle la garde avant chaque requête');
select ok(not has_function_privilege('anon', 'private.refuse_assistant_tokens()', 'execute'),
  'anon n''a rien, pas même la garde');
select ok(has_function_privilege('authenticated', 'private.refuse_assistant_tokens()', 'execute'),
  'authenticated passe par la garde');
select ok(has_function_privilege('service_role', 'private.refuse_assistant_tokens()', 'execute'),
  'service_role aussi');

set local role authenticated;
set local request.jwt.claims = '{"sub":"a5500000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$select private.refuse_assistant_tokens()$$,
  'une session de l''application passe');
select is((select count(*)::int from public.events), 1, 'le membre lit son rdv');
select is((select count(*)::int from public.calendars), 1, 'et son agenda');
select is((select count(*)::int from public.series_expansions), 1, 'et le signal de dépliage');

set local request.jwt.claims = '{"sub":"a5500000-0000-0000-0000-000000000001","role":"authenticated","client_id":"c1000000-0000-0000-0000-000000000001"}';
select throws_ok($$select private.refuse_assistant_tokens()$$, 'PGRST', null,
  'un jeton d''assistant est refusé par PostgREST');

-- Temps réel : les tables publiées ne montrent rien au jeton d'un assistant ------------------
select is((select count(*)::int from public.events), 0, 'temps réel : aucun rdv pour un jeton d''assistant');
select is((select count(*)::int from public.calendars), 0, 'ni aucun agenda');
select is((select count(*)::int from public.series_expansions), 0, 'ni aucun signal de dépliage');

-- Le worker garde ses lectures ----------------------------------------------------------------
reset role;
-- Pour appeler pgTAP sous ce rôle ; annulé avec la transaction du test.
grant usage on schema extensions to agora_worker;
set local role agora_worker;
select is(
  (select count(*)::int from public.events where id = 'a5500000-0000-0000-0000-0000000000e1'),
  1, 'le worker lit toujours les horaires : les politiques restrictives ne visent que authenticated');

select * from finish();
rollback;
