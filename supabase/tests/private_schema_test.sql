-- Schéma private : défense en profondeur.
-- PostgREST ne l'expose pas, mais `authenticated` y a USAGE (les helpers RLS
-- y vivent) : chaque table y porte donc le RLS, sans politique, pour qu'un
-- GRANT ajouté par mégarde n'ouvre rien. Les fonctions SECURITY DEFINER, qui
-- appartiennent au propriétaire des tables, n'en sont pas gênées : le bot
-- Discord reste couvert par discord_test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'private'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity),
  null::text[],
  'toute table du schéma private a le RLS activé'
);

select * from finish();
rollback;
