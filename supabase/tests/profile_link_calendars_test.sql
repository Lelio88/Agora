-- Lien de profil : le choix des agendas partagés. Chaque lien porte sa liste
-- (« Travail » sans « Loisirs ») ; un ancien lien, sans liste, partage tout.
-- Un agenda supprimé ne rend jamais un lien plus bavard.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a7000000-0000-0000-0000-0000000000a7', 'lea@test.local', '{"display_name":"Léa"}'),
  ('b7000000-0000-0000-0000-0000000000b7', 'max@test.local', '{"display_name":"Max"}'),
  ('c7000000-0000-0000-0000-0000000000c7', 'nox@test.local', '{"display_name":"Nox"}');

insert into public.calendars (id, owner_id, name, visibility, contact) values
  ('c7100000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-0000000000a7', 'Travail', null, false),
  ('c7100000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-0000000000a7', 'Loisirs', null, false),
  ('c7100000-0000-0000-0000-000000000003', 'a7000000-0000-0000-0000-0000000000a7', 'Maman', 'invisible', true),
  ('c7100000-0000-0000-0000-000000000009', 'b7000000-0000-0000-0000-0000000000b7', 'Celui de Max', null, false);
insert into public.events (calendar_id, title, starts_at, ends_at) values
  ('c7100000-0000-0000-0000-000000000001', 'Réunion', now() + interval '2 days', now() + interval '2 days 1 hour'),
  ('c7100000-0000-0000-0000-000000000002', 'Escalade', now() + interval '3 days', now() + interval '3 days 1 hour');

-- Léa crée un lien « Travail seul » et un ancien lien (sans liste) ------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-0000000000a7","role":"authenticated"}';

select set_config('agora_test.work',
  public.create_profile_link('Travail seul', 'details',
    array['c7100000-0000-0000-0000-000000000001']::uuid[]), true);
select set_config('agora_test.legacy', public.create_profile_link('Tout', 'details'), true);

select is(
  (select calendar_ids from public.profile_links where code = current_setting('agora_test.work')),
  array['c7100000-0000-0000-0000-000000000001']::uuid[],
  'le lien garde la liste des agendas choisis');
select is(
  (select calendar_ids from public.profile_links where code = current_setting('agora_test.legacy')),
  null::uuid[], 'sans liste, le lien partage tous les agendas (comme avant)');

select throws_ok(
  $$select public.create_profile_link('Rien', 'busy', array[]::uuid[])$$,
  '22023', 'invalid_calendars', 'une liste vide ne partage rien : refusée');
select throws_ok(
  $$select public.create_profile_link('Celui de Max', 'busy',
      array['c7100000-0000-0000-0000-000000000009']::uuid[])$$,
  '22023', 'invalid_calendars', 'l''agenda d''un autre ne se partage pas');
select throws_ok(
  $$select public.create_profile_link('Maman', 'busy',
      array['c7100000-0000-0000-0000-000000000003']::uuid[])$$,
  '22023', 'invalid_calendars', 'l''agenda d''un proche ne se partage pas');
select throws_ok(
  $$select public.create_profile_link('Fantôme', 'busy',
      array['c7100000-0000-0000-0000-0000000000ff']::uuid[])$$,
  '22023', 'invalid_calendars', 'un agenda inconnu non plus');

-- Max ouvre le lien « Travail seul » -------------------------------------------------------------
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select set_config('agora_test.max',
  public.import_profile(current_setting('agora_test.work'))::text, true);
select is(
  (select array_agg(title order by title) from public.events
   where calendar_id = current_setting('agora_test.max')::uuid),
  array['Réunion'], 'Max ne reçoit que l''agenda Travail');

-- Nox ouvre l'ancien lien --------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"c7000000-0000-0000-0000-0000000000c7","role":"authenticated"}';
select set_config('agora_test.nox',
  public.import_profile(current_setting('agora_test.legacy'))::text, true);
select is(
  (select array_agg(title order by title) from public.events
   where calendar_id = current_setting('agora_test.nox')::uuid),
  array['Escalade', 'Réunion'], 'un ancien lien partage tout, sauf les proches');

-- L'agenda Travail est supprimé : le lien ne bascule pas sur « tout » -------------------------------
reset role;
delete from public.calendars where id = 'c7100000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select is(
  public.import_profile(current_setting('agora_test.work'))::text,
  current_setting('agora_test.max'), 'rouvrir le lien rend le même proche');
select is(
  (select count(*)::int from public.events
   where calendar_id = current_setting('agora_test.max')::uuid),
  0, 'l''agenda supprimé, le lien ne partage rien de plus : la copie se vide');

-- Droits ------------------------------------------------------------------------------------------
select is((select count(*)::int from public.profile_links), 0,
  'Max ne lit ni les liens ni les listes de Léa');
select ok(
  not has_function_privilege('anon', 'public.create_profile_link(text, public.visibility, uuid[])', 'execute'),
  'anon ne crée aucun lien');

select * from finish();
rollback;
