-- Un groupe ne reste jamais ni vide ni sans propriétaire, même quand un
-- compte disparaît hors de delete_my_account (suppression par l'admin de
-- Supabase, qui passe par la cascade).
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, raw_user_meta_data) values
  ('9a000000-0000-0000-0000-000000000001', 'solo@test.local', '{"display_name":"Solo"}'),
  ('9a000000-0000-0000-0000-000000000002', 'olive@test.local', '{"display_name":"Olive"}'),
  ('9a000000-0000-0000-0000-000000000003', 'adam@test.local', '{"display_name":"Adam"}'),
  ('9a000000-0000-0000-0000-000000000004', 'bea@test.local', '{"display_name":"Béa"}'),
  ('9a000000-0000-0000-0000-000000000005', 'carl@test.local', '{"display_name":"Carl"}');

set local role authenticated;
-- Solo, seul dans son groupe, avec un rdv du groupe.
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('agora_test.solo', public.create_group('Solitude')::text, true);
insert into public.events (calendar_id, title, starts_at, ends_at)
select c.id, 'Balade', '2026-10-10 10:00+00', '2026-10-10 12:00+00'
from public.calendars c where c.group_id = current_setting('agora_test.solo')::uuid;

-- Olive possède « Coloc » ; Béa y arrive avant Adam, qu'Olive nomme admin.
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000002","role":"authenticated"}';
select set_config('agora_test.coloc', public.create_group('Coloc')::text, true);
select set_config('agora_test.code', public.create_invite(current_setting('agora_test.coloc')::uuid), true);
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000004","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'), 'busy');
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000003","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'), 'busy');
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.set_member_role(current_setting('agora_test.coloc')::uuid,
  '9a000000-0000-0000-0000-000000000003', 'admin');

-- Adam possède « Club », où Carl n'est que membre.
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000003","role":"authenticated"}';
select set_config('agora_test.club', public.create_group('Club')::text, true);
select set_config('agora_test.code2', public.create_invite(current_setting('agora_test.club')::uuid), true);
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000005","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code2'), 'busy');
reset role;

-- Un groupe qui perd son dernier membre disparaît --------------------------------------------------
delete from auth.users where id = '9a000000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.groups where id = current_setting('agora_test.solo')::uuid), 0,
  'le compte de Solo supprimé par l''admin, son groupe vide disparaît');
select is((select count(*)::int from public.events where title = 'Balade'), 0,
  'avec son agenda et ses rdv');

-- Un groupe qui perd son propriétaire est transmis ------------------------------------------------
delete from auth.users where id = '9a000000-0000-0000-0000-000000000002';
select is(
  (select user_id::text from public.group_members
   where group_id = current_setting('agora_test.coloc')::uuid and role = 'owner'),
  '9a000000-0000-0000-0000-000000000003',
  'Olive partie, « Coloc » revient à son admin Adam, pas à Béa arrivée avant lui');
select is(
  (select count(*)::int from public.group_members
   where group_id = current_setting('agora_test.coloc')::uuid and role = 'owner'), 1,
  'un seul propriétaire');

delete from auth.users where id = '9a000000-0000-0000-0000-000000000003';
select is(
  (select user_id::text from public.group_members
   where group_id = current_setting('agora_test.coloc')::uuid and role = 'owner'),
  '9a000000-0000-0000-0000-000000000004',
  'sans admin, le membre le plus ancien hérite');
select is(
  (select user_id::text from public.group_members
   where group_id = current_setting('agora_test.club')::uuid and role = 'owner'),
  '9a000000-0000-0000-0000-000000000005',
  'Adam avait aussi « Club » : Carl en hérite');

-- Rien ne change pour une exclusion ou une suppression de groupe ordinaires --------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"9a000000-0000-0000-0000-000000000005","role":"authenticated"}';
select lives_ok($$delete from public.groups where id = current_setting('agora_test.club')::uuid$$,
  'le propriétaire supprime son groupe comme avant');
reset role;
select is((select count(*)::int from public.groups where id = current_setting('agora_test.club')::uuid), 0,
  'et il n''existe plus');

select * from finish();
rollback;
