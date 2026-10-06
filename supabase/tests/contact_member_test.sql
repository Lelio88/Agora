-- Proche relié à un membre : l'agenda d'un proche peut désigner un co-membre
-- de groupe. Le lien est au propriétaire seul, ne se pose que vers quelqu'un
-- avec qui il partage un groupe, et le nom du proche suit celui du membre
-- tant qu'ils en partagent un.
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a8000000-0000-0000-0000-0000000000a8', 'ana@test.local', '{"display_name":"Ana"}'),
  ('b8000000-0000-0000-0000-0000000000b8', 'ben@test.local', '{"display_name":"Ben"}'),
  ('c8000000-0000-0000-0000-0000000000c8', 'cleo@test.local', '{"display_name":"Cléo"}'),
  ('d8000000-0000-0000-0000-0000000000d8', 'dan@test.local', '{"display_name":"Dan"}');
insert into public.groups (id, name) values ('80000000-0000-0000-0000-000000000008', 'Famille');
insert into public.group_members (group_id, user_id, role, share_level) values
  ('80000000-0000-0000-0000-000000000008', 'a8000000-0000-0000-0000-0000000000a8', 'owner', 'details'),
  ('80000000-0000-0000-0000-000000000008', 'b8000000-0000-0000-0000-0000000000b8', 'member', 'details'),
  ('80000000-0000-0000-0000-000000000008', 'd8000000-0000-0000-0000-0000000000d8', 'member', 'busy');

-- Ana ajoute Ben, membre de sa famille, à ses proches -------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a8000000-0000-0000-0000-0000000000a8","role":"authenticated"}';

select set_config('agora_test.ben',
  public.create_member_contact('b8000000-0000-0000-0000-0000000000b8')::text, true);
select ok(
  (select contact and kind = 'native' and visibility = 'invisible' and name = 'Ben'
     and owner_id = 'a8000000-0000-0000-0000-0000000000a8'
     and contact_user_id = 'b8000000-0000-0000-0000-0000000000b8'
   from public.calendars where id = current_setting('agora_test.ben')::uuid),
  'le proche créé depuis un membre porte son nom, reste invisible, et le désigne');
select is(
  public.create_member_contact('b8000000-0000-0000-0000-0000000000b8')::text,
  current_setting('agora_test.ben'),
  'l''ajouter de nouveau rend le même proche');
select throws_ok(
  $$select public.create_member_contact('c8000000-0000-0000-0000-0000000000c8')$$,
  'P0001', 'not_a_co_member', 'Cléo ne partage aucun groupe avec Ana : pas de lien');
select throws_ok(
  $$select public.create_member_contact('a8000000-0000-0000-0000-0000000000a8')$$,
  'P0001', 'not_a_co_member', 'Ana n''est pas son propre proche');

-- Relier un proche existant ---------------------------------------------------------------------
insert into public.calendars (name, visibility, contact) values ('Tonton', 'invisible', true);
select set_config('agora_test.tonton',
  (select id::text from public.calendars where contact and name = 'Tonton'), true);
select lives_ok(
  $$select public.link_contact(current_setting('agora_test.tonton')::uuid,
      'd8000000-0000-0000-0000-0000000000d8')$$,
  'Ana relie son proche « Tonton » à Dan');
select is(
  (select name from public.calendars where id = current_setting('agora_test.tonton')::uuid),
  'Dan', 'relié, le proche prend le nom du membre');
select throws_ok(
  $$select public.link_contact(current_setting('agora_test.tonton')::uuid,
      'b8000000-0000-0000-0000-0000000000b8')$$,
  'P0001', 'contact_already_linked', 'un membre n''est le proche que d''un seul agenda');
select throws_ok(
  $$select public.link_contact(current_setting('agora_test.tonton')::uuid,
      'c8000000-0000-0000-0000-0000000000c8')$$,
  'P0001', 'not_a_co_member', 'on ne relie qu''un co-membre');
select throws_ok(
  $$select public.link_contact((select c.id from public.calendars c
      where c.owner_id = 'a8000000-0000-0000-0000-0000000000a8' and not c.contact),
      'd8000000-0000-0000-0000-0000000000d8')$$,
  'P0002', 'calendar_not_found', 'seul l''agenda d''un proche se relie');

-- Le lien ne s'écrit que par les RPC ------------------------------------------------------------
select throws_ok(
  $$update public.calendars set contact_user_id = 'c8000000-0000-0000-0000-0000000000c8'
    where id = current_setting('agora_test.tonton')::uuid$$,
  '42501', null, 'pas d''écriture directe du lien');
select throws_ok(
  $$insert into public.calendars (name, visibility, contact, contact_user_id)
    values ('Cléo', 'invisible', true, 'c8000000-0000-0000-0000-0000000000c8')$$,
  '42501', null, 'pas de création directe d''un proche relié');

-- Ben ne sait pas qu'il est le proche d'Ana -----------------------------------------------------
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-0000000000b8","role":"authenticated"}';
select is(
  (select count(*)::int from public.calendars
   where contact_user_id = 'b8000000-0000-0000-0000-0000000000b8'),
  0, 'le membre ne voit pas qu''il est le proche de quelqu''un');

-- Le nom suit le profil, tant qu'ils partagent un groupe ----------------------------------------
update public.profiles set display_name = 'Benoît'
  where id = 'b8000000-0000-0000-0000-0000000000b8';
reset role;
select is(
  (select name from public.calendars where id = current_setting('agora_test.ben')::uuid),
  'Benoît', 'Ben se renomme : son proche chez Ana suit');
delete from public.group_members
  where user_id = 'b8000000-0000-0000-0000-0000000000b8';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-0000000000b8","role":"authenticated"}';
update public.profiles set display_name = 'Ben M.'
  where id = 'b8000000-0000-0000-0000-0000000000b8';
reset role;
select is(
  (select name from public.calendars where id = current_setting('agora_test.ben')::uuid),
  'Benoît', 'hors de tout groupe commun, son nouveau nom ne parvient plus à Ana');

-- Délier, puis la suppression du compte du membre -----------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a8000000-0000-0000-0000-0000000000a8","role":"authenticated"}';
select lives_ok(
  $$select public.link_contact(current_setting('agora_test.tonton')::uuid, null)$$,
  'Ana délie Tonton');
select ok(
  (select contact_user_id is null and name = 'Dan' from public.calendars
   where id = current_setting('agora_test.tonton')::uuid),
  'délié, le proche garde son dernier nom');
reset role;
delete from auth.users where id = 'b8000000-0000-0000-0000-0000000000b8';
select ok(
  (select contact_user_id is null and name = 'Benoît' from public.calendars
   where id = current_setting('agora_test.ben')::uuid),
  'le compte du membre supprimé, le proche d''Ana reste, sans lien');

-- Droits ----------------------------------------------------------------------------------------
select throws_ok(
  $$update public.calendars set contact_user_id = 'd8000000-0000-0000-0000-0000000000d8'
    where owner_id = 'a8000000-0000-0000-0000-0000000000a8' and not contact$$,
  '23514', null, 'seul l''agenda d''un proche désigne un membre');
select ok(
  not has_function_privilege('anon', 'public.link_contact(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.create_member_contact(uuid)', 'execute'),
  'anon ne relie rien');

select * from finish();
rollback;
