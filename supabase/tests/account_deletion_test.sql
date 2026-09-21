-- Suppression de compte : données personnelles effacées, groupes transmis
-- (admin le plus ancien, sinon membre le plus ancien), groupe vide supprimé.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, raw_user_meta_data) values
  ('d0000000-0000-0000-0000-000000000001', 'dora@test.local', '{"display_name":"Dora"}'),
  ('a0000000-0000-0000-0000-00000000000a', 'ada@test.local',  '{"display_name":"Ada"}'),
  ('b0000000-0000-0000-0000-00000000000b', 'max@test.local',  '{"display_name":"Max"}'),
  ('c0000000-0000-0000-0000-00000000000c', 'olga@test.local', '{"display_name":"Olga"}'),
  ('e0000000-0000-0000-0000-00000000000e', 'pia@test.local',  '{"display_name":"Pia"}');

insert into public.groups (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Vers un admin'),
  ('20000000-0000-0000-0000-000000000002', 'Vers un membre'),
  ('30000000-0000-0000-0000-000000000003', 'Solo'),
  ('40000000-0000-0000-0000-000000000004', 'Chez Ada');

insert into public.group_members (group_id, user_id, role, joined_at) values
  -- Max est plus ancien, mais un admin passe avant un simple membre.
  ('10000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'owner',  '2025-12-01'),
  ('10000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b', 'member', '2026-01-01'),
  ('10000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', 'admin',  '2026-02-01'),
  -- Sans admin : le membre le plus ancien hérite.
  ('20000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 'owner',  '2025-12-01'),
  ('20000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-00000000000c', 'member', '2026-03-01'),
  ('20000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-00000000000e', 'member', '2026-02-01'),
  ('30000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'owner',  '2025-12-01'),
  ('40000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-00000000000a', 'owner',  '2025-12-01'),
  ('40000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000001', 'member', '2026-01-01');

insert into public.calendars (id, owner_id, group_id, name) values
  ('c3000000-0000-0000-0000-000000000003', null, '30000000-0000-0000-0000-000000000003', 'Solo'),
  ('c4000000-0000-0000-0000-000000000004', null, '40000000-0000-0000-0000-000000000004', 'Chez Ada');

insert into public.events (calendar_id, title, starts_at, ends_at, created_by)
select id, 'Rdv perso de Dora', now(), now() + interval '1 hour', owner_id
from public.calendars where owner_id = 'd0000000-0000-0000-0000-000000000001';

insert into public.events (id, calendar_id, title, starts_at, ends_at, created_by) values
  ('e4000000-0000-0000-0000-000000000004', 'c4000000-0000-0000-0000-000000000004',
   'Pique-nique proposé par Dora', now(), now() + interval '2 hours',
   'd0000000-0000-0000-0000-000000000001');

-- Droits ------------------------------------------------------------------------
set local role anon;
select throws_ok($$select public.delete_my_account()$$, '42501', null,
  'anon n''appelle pas delete_my_account');

-- Dora supprime son compte -------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"d0000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$select public.delete_my_account()$$, 'la suppression réussit');
select throws_ok($$select public.delete_my_account()$$, '42501', 'not_authenticated',
  'un compte déjà supprimé ne peut plus rien supprimer');

reset role;
select is(
  (select count(*)::int from auth.users where id = 'd0000000-0000-0000-0000-000000000001'),
  0, 'le compte d''authentification est supprimé');

select is(
  (select count(*)::int from public.profiles where id = 'd0000000-0000-0000-0000-000000000001'),
  0, 'le profil est supprimé');

select is(
  (select count(*)::int from public.events where title = 'Rdv perso de Dora'),
  0, 'les agendas et rdv personnels sont supprimés');

select is(
  (select user_id from public.group_members
   where group_id = '10000000-0000-0000-0000-000000000001' and role = 'owner'),
  'a0000000-0000-0000-0000-00000000000a'::uuid,
  'un groupe passe à l''admin, même plus récent qu''un membre');

select is(
  (select user_id from public.group_members
   where group_id = '20000000-0000-0000-0000-000000000002' and role = 'owner'),
  'e0000000-0000-0000-0000-00000000000e'::uuid,
  'sans admin, le membre le plus ancien hérite du groupe');

select is(
  (select role::text from public.group_members
   where group_id = '10000000-0000-0000-0000-000000000001'
     and user_id = 'b0000000-0000-0000-0000-00000000000b'),
  'member', 'les autres membres gardent leur rôle');

select is(
  (select count(*)::int from public.groups where id = '30000000-0000-0000-0000-000000000003')
  + (select count(*)::int from public.calendars where id = 'c3000000-0000-0000-0000-000000000003'),
  0, 'un groupe sans autre membre disparaît avec son agenda');

select is(
  (select created_by from public.events where id = 'e4000000-0000-0000-0000-000000000004'),
  null, 'un rdv de groupe proposé par la personne reste, sans auteur');

select is(
  (select count(*)::int from public.group_members
   where group_id = '40000000-0000-0000-0000-000000000004'),
  1, 'la personne quitte les groupes dont elle était membre');

select * from finish();
rollback;
