-- Temps de trajet : le mode préféré et l'affichage dans l'agenda
-- (travel_settings), et le mode choisi pour un rdv (event_travel_modes),
-- à soi seul, sur un rdv qu'on voit ; oublié en quittant le groupe du rdv,
-- effacé avec le compte.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a7000000-0000-0000-0000-0000000000a7', 'ana@test.local', '{"display_name":"Ana"}'),
  ('b7000000-0000-0000-0000-0000000000b7', 'ben@test.local', '{"display_name":"Ben"}');
insert into public.groups (id, name) values ('70000000-0000-0000-0000-000000000007', 'Coloc');
insert into public.group_members (group_id, user_id, role, share_level) values
  ('70000000-0000-0000-0000-000000000007', 'b7000000-0000-0000-0000-0000000000b7', 'owner', 'details'),
  ('70000000-0000-0000-0000-000000000007', 'a7000000-0000-0000-0000-0000000000a7', 'member', 'details');
insert into public.calendars (id, owner_id, group_id, name) values
  ('c7000000-0000-0000-0000-000000000007', null, '70000000-0000-0000-0000-000000000007', 'Coloc');

-- Un rdv perso d'Ana, un rdv perso de Ben, un rdv du groupe.
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, created_by)
select 'e7000000-0000-0000-0000-0000000000a7', id, 'Dentiste', '3 place Royale, Reims',
       now(), now() + interval '1 hour', owner_id
from public.calendars where owner_id = 'a7000000-0000-0000-0000-0000000000a7';
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, created_by)
select 'e7000000-0000-0000-0000-0000000000b7', id, 'Kiné', 'Gare de Reims',
       now(), now() + interval '1 hour', owner_id
from public.calendars where owner_id = 'b7000000-0000-0000-0000-0000000000b7';
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, created_by) values
  ('e7000000-0000-0000-0000-000000000007', 'c7000000-0000-0000-0000-000000000007', 'Ciné',
   'Cinéma Opéra, Reims', now(), now() + interval '2 hours', 'b7000000-0000-0000-0000-0000000000b7');
insert into public.travel_settings (user_id, home_address, home_lon, home_lat) values
  ('a7000000-0000-0000-0000-0000000000a7', 'Place Drouet d''Erlon 51100 Reims', 4.026938, 49.255543);

-- Ana règle ses trajets -------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-0000000000a7","role":"authenticated"}';

select lives_ok(
  $$update public.travel_settings set travel_mode = 'walk', show_in_agenda = false$$,
  'Ana choisit la marche et masque les trajets de son agenda');
select throws_ok(
  $$update public.travel_settings set travel_mode = 'bike'$$,
  '23514', null, 'un mode inconnu est refusé');

select lives_ok(
  $$insert into public.event_travel_modes (event_id, mode)
    values ('e7000000-0000-0000-0000-0000000000a7', 'car')$$,
  'Ana choisit la voiture pour son rdv');
-- La forme de l'upsert de PostgREST (on_conflict=user_id,event_id).
select lives_ok(
  $$insert into public.event_travel_modes (event_id, mode)
    values ('e7000000-0000-0000-0000-0000000000a7', 'none')
    on conflict (user_id, event_id) do update
      set event_id = excluded.event_id, mode = excluded.mode$$,
  'puis aucun trajet, en renvoyant son choix');
select is(
  (select mode from public.event_travel_modes
   where event_id = 'e7000000-0000-0000-0000-0000000000a7'),
  'none', 'le dernier choix l''emporte');
select lives_ok(
  $$insert into public.event_travel_modes (event_id, mode)
    values ('e7000000-0000-0000-0000-000000000007', 'walk')$$,
  'Ana choisit la marche pour le rdv du groupe');
select throws_ok(
  $$insert into public.event_travel_modes (event_id, mode)
    values ('e7000000-0000-0000-0000-0000000000b7', 'car')$$,
  '42501', null, 'pas de choix sur un rdv qu''Ana ne voit pas (le rdv perso de Ben)');

-- Ben ------------------------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select is((select count(*)::int from public.event_travel_modes), 0,
  'Ben ne voit pas les choix d''Ana, même sur le rdv de leur groupe');

-- Ana quitte le groupe, puis supprime son compte ------------------------------------------------
reset role;
delete from public.group_members
where group_id = '70000000-0000-0000-0000-000000000007'
  and user_id = 'a7000000-0000-0000-0000-0000000000a7';
select is(
  (select array_agg(event_id::text) from public.event_travel_modes),
  array['e7000000-0000-0000-0000-0000000000a7'],
  'quitter le groupe oublie le choix fait pour son rdv, pas les autres');
select ok(
  not has_table_privilege('agora_worker', 'public.event_travel_modes', 'select'),
  'le worker ne lit pas les choix de trajet');

set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-0000000000a7","role":"authenticated"}';
select public.delete_my_account();
reset role;
select is((select count(*)::int from public.event_travel_modes), 0,
  'les choix d''Ana partent avec son compte');

select * from finish();
rollback;
