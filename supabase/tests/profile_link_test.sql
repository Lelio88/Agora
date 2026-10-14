-- Lien de profil : Léa crée des liens, chacun avec son nom et son niveau
-- (détails ou occupé) ; qui l'ouvre, connecté, reçoit un proche garni d'une
-- COPIE figée de ses rdv à venir. Le niveau du lien est plafonné par la
-- visibilité du calendrier et du rdv (le plus restrictif gagne) ; un rdv
-- invisible ne sort jamais, pas même comme trou dans une série.
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a9000000-0000-0000-0000-0000000000a9', 'lea@test.local', '{"display_name":"Léa"}'),
  ('b9000000-0000-0000-0000-0000000000b9', 'marie@test.local', '{"display_name":"Marie"}'),
  ('c9000000-0000-0000-0000-0000000000c9', 'tom@test.local', '{"display_name":"Tom"}'),
  ('d9000000-0000-0000-0000-0000000000d9', 'dan@test.local', '{"display_name":"Dan"}');

update public.profiles set locale = 'en' where id = 'c9000000-0000-0000-0000-0000000000c9';

-- Les agendas de Léa : un sans réglage, un « occupé », un invisible, et un proche.
insert into public.calendars (id, owner_id, name, visibility, contact) values
  ('c1000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-0000000000a9', 'Perso', null, false),
  ('c1000000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-0000000000a9', 'Travail', 'busy', false),
  ('c1000000-0000-0000-0000-000000000003', 'a9000000-0000-0000-0000-0000000000a9', 'Secret', 'invisible', false),
  ('c1000000-0000-0000-0000-000000000004', 'a9000000-0000-0000-0000-0000000000a9', 'Maman', 'invisible', true);

insert into public.events (id, calendar_id, title, description, location, starts_at, ends_at, visibility) values
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   'Dentiste', 'carte vitale', 'Rue X', now() + interval '3 days', now() + interval '3 days 1 hour', null),
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001',
   'Médecin', 'ordonnance', 'Cabinet Y', now() + interval '4 days', now() + interval '4 days 1 hour', 'busy'),
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002',
   'Réunion', null, 'Salle Z', now() + interval '5 days', now() + interval '5 days 1 hour', null),
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000003',
   'Caché', null, null, now() + interval '6 days', now() + interval '6 days 1 hour', null),
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001',
   'Passé', null, null, now() - interval '40 days', now() - interval '40 days' + interval '1 hour', null),
  ('e1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000004',
   'Anniversaire de Maman', null, null, now() + interval '7 days', now() + interval '7 days 1 hour', null),
  ('e1000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001',
   'Perso invisible', null, null, now() + interval '8 days', now() + interval '8 days 1 hour', 'invisible');

-- Une série hebdomadaire : une séance déplacée, une séance invisible, une séance sautée.
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, rrule, exdates, timezone) values
  ('e2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   'Cours', 'Salle 4',
   date_trunc('day', now()) + interval '2 days 10 hours', date_trunc('day', now()) + interval '2 days 11 hours',
   'FREQ=WEEKLY', array[date_trunc('day', now()) + interval '23 days 10 hours'], 'Europe/Paris');
insert into public.events (id, calendar_id, series_id, recurrence_id, title, location,
                           starts_at, ends_at, visibility) values
  ('e2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001',
   'e2000000-0000-0000-0000-000000000001', date_trunc('day', now()) + interval '9 days 10 hours',
   'Cours déplacé', 'Salle 9',
   date_trunc('day', now()) + interval '9 days 14 hours', date_trunc('day', now()) + interval '9 days 15 hours', null),
  ('e2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001',
   'e2000000-0000-0000-0000-000000000001', date_trunc('day', now()) + interval '16 days 10 hours',
   'Cours caché', null,
   date_trunc('day', now()) + interval '16 days 10 hours', date_trunc('day', now()) + interval '16 days 11 hours',
   'invisible');

-- Une séance déplacée dans le passé : son créneau d'origine doit devenir un trou.
insert into public.events (id, calendar_id, series_id, recurrence_id, title,
                           starts_at, ends_at) values
  ('e2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001',
   'e2000000-0000-0000-0000-000000000001', date_trunc('day', now()) + interval '30 days 10 hours',
   'Cours rattrapé', now() - interval '3 days', now() - interval '3 days' + interval '1 hour');

-- Éva a trop de rdv pour une copie.
insert into auth.users (id, email, raw_user_meta_data) values
  ('e9000000-0000-0000-0000-0000000000e9', 'eva@test.local', '{"display_name":"Éva"}');
insert into public.calendars (id, owner_id, name) values
  ('c1000000-0000-0000-0000-00000000000e', 'e9000000-0000-0000-0000-0000000000e9', 'Tout');
insert into public.events (calendar_id, title, starts_at, ends_at)
  select 'c1000000-0000-0000-0000-00000000000e', 'rdv ' || g,
         now() + (g || ' hours')::interval, now() + (g || ' hours')::interval + interval '30 minutes'
  from generate_series(1, 2001) g;
insert into public.profile_links (code, owner_id, label, share_level) values
  ('EVA23456', 'e9000000-0000-0000-0000-0000000000e9', 'Pour Marie', 'busy');

-- Dan a déjà un proche iCal relié à Léa ; il ne peut pas recevoir de copie.
insert into public.calendars (id, owner_id, kind, name, visibility, contact, contact_user_id) values
  ('c1000000-0000-0000-0000-000000000009', 'd9000000-0000-0000-0000-0000000000d9',
   'ics', 'Léa (iCal)', 'invisible', true, 'a9000000-0000-0000-0000-0000000000a9');

-- Léa crée ses liens ----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-0000000000a9","role":"authenticated"}';

select set_config('agora_test.marie_code', public.create_profile_link('Pour Marie', 'details'), true);
select set_config('agora_test.tom_code', public.create_profile_link('Pour Tom', 'busy'), true);
select set_config('agora_test.dan_code', public.create_profile_link('Pour Dan', 'details'), true);
select matches(current_setting('agora_test.marie_code'), '^[A-HJ-NP-Z2-9]{8}$',
  'un lien de profil porte un code de 8 caractères');
select is((select count(*)::int from public.profile_links), 3, 'Léa lit ses trois liens');
select is(
  (select share_level::text from public.profile_links
   where code = current_setting('agora_test.tom_code')),
  'busy', 'chaque lien garde son niveau');
select throws_ok($$select public.create_profile_link('Pour Zoé', 'invisible')$$,
  '22023', 'invalid_share_level', 'un lien invisible n''a pas de sens');
select throws_ok($$select public.create_profile_link('   ', 'busy')$$,
  '22023', 'invalid_label', 'un lien a un nom');
select lives_ok(
  $$select public.create_profile_link('Lien ' || g, 'busy') from generate_series(1, 17) g$$,
  'Léa monte jusqu''à vingt liens');
select throws_ok($$select public.create_profile_link('Un de trop', 'busy')$$,
  'P0001', 'too_many_links', 'au-delà de vingt liens, refus');
select throws_ok(
  $$update public.profile_links set share_level = 'details'
    where code = current_setting('agora_test.tom_code')$$,
  '42501', null, 'le niveau d''un lien ne se change pas en direct');
select throws_ok(
  $$insert into public.profile_links (code, label, share_level) values ('AAAAAAAA', 'x', 'details')$$,
  '42501', null, 'pas de création directe d''un lien');

-- Léa ne peut pas importer son propre profil -----------------------------------------------------
select throws_ok(
  $$select public.import_profile(current_setting('agora_test.marie_code'))$$,
  'P0001', 'own_profile', 'on n''importe pas son propre profil');

-- Marie ouvre son lien --------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-0000000000b9","role":"authenticated"}';

select is((select count(*)::int from public.profile_links), 0, 'Marie ne lit aucun lien de Léa');
select is(public.profile_link_preview(current_setting('agora_test.marie_code')), 'Léa',
  'l''aperçu donne le nom de Léa');
select is(public.profile_link_preview('ZZZZZZZZ'), null,
  'un code inconnu ne montre rien');

select set_config('agora_test.proche',
  public.import_profile(current_setting('agora_test.marie_code'))::text, true);
select ok(
  (select contact and kind = 'native' and visibility = 'invisible' and name = 'Léa'
     and owner_id = 'b9000000-0000-0000-0000-0000000000b9'
     and contact_user_id = 'a9000000-0000-0000-0000-0000000000a9'
   from public.calendars where id = current_setting('agora_test.proche')::uuid),
  'le proche est à Marie, invisible, au nom de Léa, et la désigne');

select is(
  (select array_agg(title order by title) from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid),
  array['Cours', 'Cours déplacé', 'Dentiste', 'Occupé', 'Occupé'],
  'Marie reçoit la série, la séance déplacée, le dentiste et deux plages occupées');
select is(
  (select location from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid and title = 'Dentiste'),
  'Rue X', 'au niveau détails, le titre et le lieu passent');
select is(
  (select count(*)::int from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid and description is not null),
  0, 'la description ne passe jamais');
select is(
  (select count(*)::int from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid
     and title = 'Occupé' and location is null),
  2, 'un rdv « occupé » (le sien, ou celui d''un agenda « occupé ») perd titre et lieu');
select is(
  (select count(*)::int from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid
     and title in ('Caché', 'Passé', 'Perso invisible', 'Anniversaire de Maman', 'Cours caché')),
  0, 'ni invisible, ni passé, ni proche de Léa ne sort');

select ok(
  (select m.rrule = 'FREQ=WEEKLY' and m.location = 'Salle 4'
     and m.exdates @> array[date_trunc('day', now()) + interval '23 days 10 hours',
                            date_trunc('day', now()) + interval '16 days 10 hours']
     and m.exdates @> array[date_trunc('day', now()) + interval '30 days 10 hours']
     and cardinality(m.exdates) = 3
   from public.events m
   where m.calendar_id = current_setting('agora_test.proche')::uuid and m.title = 'Cours'),
  'la série garde sa règle et sa séance sautée ; séance invisible ou déplacée dans le passé : un trou');
select ok(
  (select x.series_id = m.id
     and x.recurrence_id = date_trunc('day', now()) + interval '9 days 10 hours'
   from public.events x
   join public.events m on m.calendar_id = x.calendar_id and m.title = 'Cours'
   where x.calendar_id = current_setting('agora_test.proche')::uuid and x.title = 'Cours déplacé'),
  'la séance déplacée se rattache à la série copiée');

select throws_ok($$select public.import_profile('EVA23456')$$,
  'P0001', 'profile_too_large', 'une copie de plus de 2000 rdv est refusée');
select is(
  (select count(*)::int from public.calendars where contact_user_id = 'e9000000-0000-0000-0000-0000000000e9'),
  0, 'et rien n''est créé');

-- Tom a un lien « occupé » : tout est plafonné ------------------------------------------------------
set local request.jwt.claims = '{"sub":"c9000000-0000-0000-0000-0000000000c9","role":"authenticated"}';
select set_config('agora_test.tom_proche',
  public.import_profile(current_setting('agora_test.tom_code'))::text, true);
select ok(
  (select count(*) > 0 and bool_and(title = 'Busy' and location is null and description is null)
   from public.events where calendar_id = current_setting('agora_test.tom_proche')::uuid),
  'avec un lien « occupé », tout n''est qu''une plage occupée, titrée dans la langue de Tom');

-- Dan a déjà un proche iCal relié à Léa ------------------------------------------------------------
set local request.jwt.claims = '{"sub":"d9000000-0000-0000-0000-0000000000d9","role":"authenticated"}';
select throws_ok(
  $$select public.import_profile(current_setting('agora_test.dan_code'))$$,
  'P0001', 'contact_not_native', 'un proche iCal ne reçoit pas de copie');

-- Rafraîchir : le même proche, la copie refaite, les rdv de Marie intacts -------------------------
reset role;
insert into public.events (calendar_id, title, starts_at, ends_at) values
  (current_setting('agora_test.proche')::uuid, 'Anniversaire de Léa',
   now() + interval '30 days', now() + interval '30 days 1 hour');
insert into public.events (calendar_id, title, starts_at, ends_at) values
  ('c1000000-0000-0000-0000-000000000001', 'Nouveau',
   now() + interval '10 days', now() + interval '10 days 1 hour');
delete from public.events where id = 'e1000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-0000000000b9","role":"authenticated"}';

select is(public.import_profile(current_setting('agora_test.marie_code'))::text,
  current_setting('agora_test.proche'), 'un second scan rend le même proche');
select is(
  (select array_agg(title order by title) from public.events
   where calendar_id = current_setting('agora_test.proche')::uuid),
  array['Anniversaire de Léa', 'Cours', 'Cours déplacé', 'Nouveau', 'Occupé', 'Occupé'],
  'la copie est refaite sans doublon, et le rdv de Marie reste');

-- Révoquer ne reprend rien, mais ferme le lien ----------------------------------------------------
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-0000000000a9","role":"authenticated"}';
delete from public.profile_links where code = current_setting('agora_test.marie_code');
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-0000000000b9","role":"authenticated"}';
select is(public.import_profile(current_setting('agora_test.marie_code')), null,
  'un lien supprimé ne s''ouvre plus');
select ok(
  exists (select 1 from public.events
          where calendar_id = current_setting('agora_test.proche')::uuid and title = 'Nouveau'),
  'la copie déjà faite reste chez Marie');

-- Dix échecs dans l'heure ferment l'ouverture des liens à Marie, même pour un lien valable ---------
select lives_ok(
  $$select public.profile_link_preview('ZZZZZZ2' || g) from generate_series(2, 9) g$$,
  'des essais au hasard (les deux premiers échecs étaient plus haut)');
select throws_ok(
  $$select public.import_profile(current_setting('agora_test.tom_code'))$$,
  'P0001', 'rate_limited', 'après dix échecs, même un lien valable est refusé');
set local request.jwt.claims = '{"sub":"c9000000-0000-0000-0000-0000000000c9","role":"authenticated"}';
select is(public.profile_link_preview(current_setting('agora_test.tom_code')), 'Léa',
  'les autres membres ne sont pas touchés');

-- Suppression du compte de Léa --------------------------------------------------------------------
reset role;
delete from auth.users where id = 'a9000000-0000-0000-0000-0000000000a9';
select is(
  (select count(*)::int from public.profile_links
   where owner_id = 'a9000000-0000-0000-0000-0000000000a9'),
  0, 'les liens de Léa disparaissent avec son compte');
select ok(
  (select contact_user_id is null from public.calendars
   where id = current_setting('agora_test.proche')::uuid),
  'le proche de Marie reste, sans lien vers un compte');

-- Droits ------------------------------------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.create_profile_link(text, public.visibility)', 'execute')
  and not has_function_privilege('anon', 'public.profile_link_preview(text)', 'execute')
  and not has_function_privilege('anon', 'public.import_profile(text)', 'execute')
  and not has_function_privilege('authenticated',
    'private.copy_profile_events(uuid, public.visibility, uuid)', 'execute'),
  'anon n''ouvre aucun lien de profil, et la copie n''est pas appelable en direct');
select ok(
  not has_table_privilege('authenticated', 'private.profile_link_attempts', 'select')
  and not has_function_privilege('authenticated', 'private.check_profile_link_rate()', 'execute'),
  'les échecs d''ouverture ne se lisent pas, la limite ne s''appelle pas en direct');
select is(
  (select string_agg(privilege_type, ',' order by privilege_type)
   from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'profile_links' and grantee = 'authenticated'),
  'DELETE,SELECT',
  'profile_links se lit et se supprime ; les RPC sont sa seule écriture');

select * from finish();
rollback;
