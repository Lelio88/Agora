-- Gestion d'un groupe : aperçu d'une invitation, partage choisi à l'arrivée,
-- rôles (le propriétaire nomme les admins), exclusion, transmission du groupe.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, email, raw_user_meta_data) values
  ('0a000000-0000-0000-0000-00000000000a', 'olga@test.local', '{"display_name":"Olga"}'),
  ('0b000000-0000-0000-0000-00000000000b', 'paul.g@test.local', '{"display_name":"Paul"}'),
  ('0c000000-0000-0000-0000-00000000000c', 'quentin@test.local', '{"display_name":"Quentin"}'),
  ('0d000000-0000-0000-0000-00000000000d', 'rita@test.local', '{"display_name":"Rita"}');

-- Un rdv de Paul, pour vérifier ce que le groupe en voit.
insert into public.events (calendar_id, title, starts_at, ends_at, created_by)
select c.id, 'Kiné', '2026-10-07 08:00+00', '2026-10-07 09:00+00', c.owner_id
from public.calendars c where c.owner_id = '0b000000-0000-0000-0000-00000000000b';

set local role authenticated;
set local request.jwt.claims = '{"sub":"0a000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select set_config('agora_test.group', public.create_group('Coloc')::text, true);
select set_config('agora_test.code',
  public.create_invite(current_setting('agora_test.group')::uuid), true);

-- Aperçu avant de rejoindre ----------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"0d000000-0000-0000-0000-00000000000d","role":"authenticated"}';
select ok(
  (select name = 'Coloc' and member_count = 1 and not is_member
   from public.invite_preview(lower(current_setting('agora_test.code')))),
  'un invité voit le nom du groupe et sa taille avant de rejoindre');
select throws_ok($$select * from public.invite_preview('ZZZZZZZZ')$$,
  'P0002', 'invite_invalid', 'un code inconnu ne révèle rien');

-- Rejoindre en choisissant son partage ------------------------------------------------------------
set local request.jwt.claims = '{"sub":"0b000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('agora_test.code'), 'invisible')$$,
  'Paul rejoint en ne partageant rien');
set local request.jwt.claims = '{"sub":"0c000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('agora_test.code'), 'details')$$,
  'Quentin rejoint en partageant les détails');
select is(
  (select array_agg(share_level::text order by user_id) from public.group_members
   where group_id = current_setting('agora_test.group')::uuid
     and user_id in ('0b000000-0000-0000-0000-00000000000b', '0c000000-0000-0000-0000-00000000000c')),
  array['invisible', 'details'], 'chacun entre avec le partage qu''il a choisi');

set local request.jwt.claims = '{"sub":"0a000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select is(
  (select count(*)::int from public.group_agenda(current_setting('agora_test.group')::uuid,
     '2026-10-05', '2026-10-12') where user_id = '0b000000-0000-0000-0000-00000000000b'),
  0, 'rien de Paul n''apparaît dans le groupe : il a choisi de ne rien partager');

-- Rôles --------------------------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"0c000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select throws_ok($$
  select public.set_member_role(current_setting('agora_test.group')::uuid,
    '0b000000-0000-0000-0000-00000000000b', 'admin')$$,
  '42501', 'not_group_owner', 'un simple membre ne nomme pas d''admin');

set local request.jwt.claims = '{"sub":"0a000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select lives_ok($$
  select public.set_member_role(current_setting('agora_test.group')::uuid,
    '0b000000-0000-0000-0000-00000000000b', 'admin')$$,
  'la propriétaire nomme Paul admin');
select throws_ok($$
  select public.set_member_role(current_setting('agora_test.group')::uuid,
    '0b000000-0000-0000-0000-00000000000b', 'owner')$$,
  '22023', 'invalid_role', 'on ne devient pas propriétaire par set_member_role');
select throws_ok($$
  select public.set_member_role(current_setting('agora_test.group')::uuid,
    '0a000000-0000-0000-0000-00000000000a', 'member')$$,
  '22023', 'invalid_member', 'la propriétaire ne se rétrograde pas elle-même');
select throws_ok($$
  select public.set_member_role(current_setting('agora_test.group')::uuid,
    '0d000000-0000-0000-0000-00000000000d', 'admin')$$,
  '22023', 'invalid_member', 'on ne nomme admin qu''un membre du groupe');

-- Exclusion par un admin ------------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"0b000000-0000-0000-0000-00000000000b","role":"authenticated"}';
delete from public.group_members
where group_id = current_setting('agora_test.group')::uuid
  and user_id = '0c000000-0000-0000-0000-00000000000c';
select is(
  (select count(*)::int from public.group_members where group_id = current_setting('agora_test.group')::uuid),
  2, 'un admin exclut un simple membre');

-- Transmission ------------------------------------------------------------------------------------------
select throws_ok($$
  select public.transfer_group(current_setting('agora_test.group')::uuid,
    '0b000000-0000-0000-0000-00000000000b')$$,
  '42501', 'not_group_owner', 'un admin ne s''approprie pas le groupe');

set local request.jwt.claims = '{"sub":"0a000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select throws_ok($$
  select public.transfer_group(current_setting('agora_test.group')::uuid,
    '0d000000-0000-0000-0000-00000000000d')$$,
  '22023', 'invalid_member', 'on ne transmet qu''à un membre du groupe');
select lives_ok($$
  select public.transfer_group(current_setting('agora_test.group')::uuid,
    '0b000000-0000-0000-0000-00000000000b')$$,
  'la propriétaire transmet le groupe à Paul');
select is(
  (select array_agg(role::text order by user_id) from public.group_members
   where group_id = current_setting('agora_test.group')::uuid),
  array['admin', 'owner'], 'Olga devient admin, Paul propriétaire');

select lives_ok($$
  delete from public.group_members
  where group_id = current_setting('agora_test.group')::uuid
    and user_id = '0a000000-0000-0000-0000-00000000000a'$$,
  'l''ancienne propriétaire peut maintenant quitter le groupe');
select is(
  (select count(*)::int from public.group_members
   where group_id = current_setting('agora_test.group')::uuid),
  0, 'hors du groupe, Olga n''en voit plus les membres');

set local request.jwt.claims = '{"sub":"0b000000-0000-0000-0000-00000000000b","role":"authenticated"}';
delete from public.group_members
where group_id = current_setting('agora_test.group')::uuid
  and user_id = '0b000000-0000-0000-0000-00000000000b';
select is(
  (select role::text from public.group_members
   where group_id = current_setting('agora_test.group')::uuid
     and user_id = '0b000000-0000-0000-0000-00000000000b'),
  'owner', 'le propriétaire ne quitte pas sans transmettre');
select is(
  (select count(*)::int from public.group_members where group_id = current_setting('agora_test.group')::uuid),
  1, 'Paul reste seul, propriétaire');

select * from finish();
rollback;
