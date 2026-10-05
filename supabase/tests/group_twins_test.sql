-- Jumelage d'un groupe avec un groupe d'une autre app (Arpente) : droits, format du code
-- distant, invitation sans échéance, défaire, cascade.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (id, email, raw_user_meta_data) values
  ('a1000000-0000-0000-0000-0000000000a1', 'olga@test.local', '{"display_name":"Olga"}'),
  ('a2000000-0000-0000-0000-0000000000a2', 'adam@test.local', '{"display_name":"Adam"}'),
  ('a3000000-0000-0000-0000-0000000000a3', 'mia@test.local',  '{"display_name":"Mia"}'),
  ('a4000000-0000-0000-0000-0000000000a4', 'tom@test.local',  '{"display_name":"Tom"}'),
  ('a5000000-0000-0000-0000-0000000000a5', 'zoe@test.local',  '{"display_name":"Zoé"}');

-- Olga crée le groupe ; Adam (admin) et Mia (membre) le rejoignent ---------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
select set_config('agora_test.group', public.create_group('Sortie Caen')::text, true);
select set_config('agora_test.code',
  public.create_invite(current_setting('agora_test.group')::uuid), true);

set local request.jwt.claims = '{"sub":"a2000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'));
set local request.jwt.claims = '{"sub":"a3000000-0000-0000-0000-0000000000a3","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'));

set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
select public.set_member_role(current_setting('agora_test.group')::uuid,
  'a2000000-0000-0000-0000-0000000000a2', 'admin');

-- Qui peut jumeler ----------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"a3000000-0000-0000-0000-0000000000a3","role":"authenticated"}';
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente')$$,
  '42501', 'not_group_admin', 'un simple membre ne jumelle pas le groupe');

set local request.jwt.claims = '{"sub":"a4000000-0000-0000-0000-0000000000a4","role":"authenticated"}';
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente')$$,
  '42501', 'not_group_admin', 'un inconnu ne jumelle pas le groupe');

-- Adam lance le jumelage depuis Agora : jumeau en attente, sans code distant -------------------
set local request.jwt.claims = '{"sub":"a2000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
select set_config('agora_test.twin',
  public.twin_group(current_setting('agora_test.group')::uuid, 'arpente'), true);

select matches(current_setting('agora_test.twin'), '^[A-HJ-NP-Z2-9]{8}$',
  'le jumelage rend un code d''invitation au format habituel');
select ok(
  (select remote_code is null from public.group_twins
   where group_id = current_setting('agora_test.group')::uuid and app = 'arpente'),
  'lancé depuis Agora, le jumeau attend le code du groupe Arpente');
select ok(
  (select expires_at is null from public.group_invites where code = current_setting('agora_test.twin')),
  'l''invitation du jumeau n''a pas d''échéance');
select is(
  public.twin_group(current_setting('agora_test.group')::uuid, 'arpente'),
  current_setting('agora_test.twin'),
  'relancer le jumelage reprend la même invitation');
select is(
  (select array[count(*)::int, (count(*) filter (where expires_at > now()))::int]
   from public.group_invites where created_by = 'a2000000-0000-0000-0000-0000000000a2'),
  array[1, 0],
  'la fenêtre d''invitation (échéance future) ne voit pas l''invitation du jumeau');

-- La réponse d'Arpente complète le jumeau ; le code distant est contrôlé ------------------------
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
select is(
  public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', ' abc234 '),
  current_setting('agora_test.twin'),
  'compléter le jumeau garde son invitation');
select is(
  (select remote_code from public.group_twins
   where group_id = current_setting('agora_test.group')::uuid and app = 'arpente'),
  'ABC234', 'le code Arpente est rangé en majuscules, sans espaces');
select is(
  public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'ABC234'),
  current_setting('agora_test.twin'),
  'la même réponse rejouée ne change rien');
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'XYZ789')$$,
  '23505', 'twin_exists', 'un jumeau complet ne change pas de groupe Arpente sans être défait');
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'ABC10')$$,
  '22023', 'invalid_twin_code', 'un code Arpente de mauvaise longueur est refusé');
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'ABC0EF')$$,
  '22023', 'invalid_twin_code', 'un code Arpente hors alphabet (0) est refusé');
select throws_ok(
  $$insert into public.group_twins (group_id, app, invite_code)
    values (current_setting('agora_test.group')::uuid, 'arpente', current_setting('agora_test.code'))$$,
  '42501', null, 'on n''écrit un jumeau que par twin_group');

-- Tom arrive d'Arpente avec l'invitation du jumeau ----------------------------------------------
set local request.jwt.claims = '{"sub":"a4000000-0000-0000-0000-0000000000a4","role":"authenticated"}';
select is(
  (select count(*)::int from public.group_twins where group_id = current_setting('agora_test.group')::uuid),
  0, 'un non-membre ne voit pas le jumeau');
select is(
  (select name from public.invite_preview(current_setting('agora_test.twin'))),
  'Sortie Caen', 'l''invitation du jumeau ouvre l''aperçu du groupe');
select is(
  public.join_group(current_setting('agora_test.twin'), 'invisible'),
  current_setting('agora_test.group')::uuid,
  'l''invitation du jumeau fait rejoindre le groupe, avec le partage choisi');
select is(
  (select remote_code from public.group_twins where group_id = current_setting('agora_test.group')::uuid),
  'ABC234', 'devenu membre, Tom voit le code du groupe Arpente jumeau');

-- Une invitation ordinaire échue reste refusée -------------------------------------------------
reset role;
update public.group_invites set expires_at = now() - interval '1 minute'
where code = current_setting('agora_test.code');
set local role authenticated;
set local request.jwt.claims = '{"sub":"a5000000-0000-0000-0000-0000000000a5","role":"authenticated"}';
select throws_ok(
  $$select public.join_group(current_setting('agora_test.code'))$$,
  'P0002', 'invite_invalid', 'une invitation ordinaire échue reste refusée');
select throws_ok(
  $$select * from public.invite_preview(current_setting('agora_test.code'))$$,
  'P0002', 'invite_invalid', 'son aperçu aussi');

-- Défaire : supprimer l'invitation du jumeau ----------------------------------------------------
set local request.jwt.claims = '{"sub":"a3000000-0000-0000-0000-0000000000a3","role":"authenticated"}';
delete from public.group_invites where code = current_setting('agora_test.twin');
select is(
  (select count(*)::int from public.group_twins where group_id = current_setting('agora_test.group')::uuid),
  1, 'un simple membre ne défait pas le jumelage');

set local request.jwt.claims = '{"sub":"a2000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
delete from public.group_invites where code = current_setting('agora_test.twin');
select is(
  (select count(*)::int from public.group_twins where group_id = current_setting('agora_test.group')::uuid),
  0, 'supprimer l''invitation du jumeau défait le jumelage');

set local request.jwt.claims = '{"sub":"a5000000-0000-0000-0000-0000000000a5","role":"authenticated"}';
select throws_ok(
  $$select public.join_group(current_setting('agora_test.twin'))$$,
  'P0002', 'invite_invalid', 'défait, le jumelage n''ouvre plus le groupe');

-- Droits d'appel et cascade -------------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.twin_group(uuid, public.twin_app, text)', 'execute'),
  'anon n''appelle pas twin_group');

set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'XYZ789');
delete from public.groups where id = current_setting('agora_test.group')::uuid;
reset role;
select is(
  (select count(*)::int from public.group_twins where group_id = current_setting('agora_test.group')::uuid),
  0, 'supprimer le groupe emporte son jumeau');

select * from finish();
rollback;
