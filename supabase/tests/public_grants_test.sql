-- Droits du schéma public : rien à anon ; à authenticated, ni TRUNCATE (qui
-- échappe à la RLS), ni TRIGGER, ni REFERENCES. La base accorde par défaut tous
-- les droits sur une table neuve (pg_default_acl de Supabase) : une migration
-- qui oublie de révoquer se voit ici — c'est arrivé à event_responses.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is(
  (select array_agg(distinct table_name::text order by table_name::text)
   from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon'),
  null::text[],
  'anon n''a aucun droit sur les tables de public');

select is(
  (select array_agg(distinct table_name::text order by table_name::text)
   from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'authenticated'
     and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES')),
  null::text[],
  'authenticated n''a ni TRUNCATE, ni TRIGGER, ni REFERENCES');

select is(
  (select array_agg(p.proname::text order by p.proname::text)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  null::text[],
  'anon n''appelle aucune fonction de public');

select is(
  (select string_agg(privilege_type, ',' order by privilege_type)
   from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'event_responses' and grantee = 'authenticated'),
  'SELECT',
  'event_responses se lit seulement : respond_to_event est sa seule écriture');

select * from finish();
rollback;
