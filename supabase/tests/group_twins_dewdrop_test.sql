-- Jumelage avec DewDrop : un groupe peut avoir un jumeau par app (Arpente ET DewDrop), et le
-- format du code distant suit l'app (DewDrop : 8 caractères, Arpente : toujours 6).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, raw_user_meta_data) values
  ('b1000000-0000-0000-0000-0000000000b1', 'lea@test.local', '{"display_name":"Léa"}'),
  ('b2000000-0000-0000-0000-0000000000b2', 'noe@test.local', '{"display_name":"Noé"}');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-0000-0000-0000000000b1","role":"authenticated"}';
select set_config('agora_test.group', public.create_group('Les copains')::text, true);

-- Lancé depuis Agora : jumeau DewDrop en attente ---------------------------------------------
select set_config('agora_test.dewdrop',
  public.twin_group(current_setting('agora_test.group')::uuid, 'dewdrop'), true);
select matches(current_setting('agora_test.dewdrop'), '^[A-HJ-NP-Z2-9]{8}$',
  'jumeler avec DewDrop rend une invitation au format habituel');
select ok(
  (select remote_code is null from public.group_twins
   where group_id = current_setting('agora_test.group')::uuid and app = 'dewdrop'),
  'lancé depuis Agora, le jumeau DewDrop attend le code du cercle');

-- Le code d'un cercle DewDrop a 8 caractères -------------------------------------------------
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'dewdrop', 'ABC234')$$,
  '22023', 'invalid_twin_code', 'un code DewDrop de 6 caractères est refusé');
select is(
  public.twin_group(current_setting('agora_test.group')::uuid, 'dewdrop', ' abcd2345 '),
  current_setting('agora_test.dewdrop'),
  'la réponse de DewDrop complète le jumeau et garde son invitation');
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'dewdrop', 'WXYZ6789')$$,
  '23505', 'twin_exists', 'un jumeau DewDrop complet ne change pas de cercle sans être défait');

-- Arpente garde son format, et les deux jumeaux coexistent -----------------------------------
select throws_ok(
  $$select public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'ABCD2345')$$,
  '22023', 'invalid_twin_code', 'un code Arpente reste à 6 caractères');
select isnt(
  public.twin_group(current_setting('agora_test.group')::uuid, 'arpente', 'ABC234'),
  current_setting('agora_test.dewdrop'),
  'chaque jumeau reçoit sa propre invitation');
select is(
  (select array_agg(app::text order by app::text) from public.group_twins
   where group_id = current_setting('agora_test.group')::uuid),
  array['arpente', 'dewdrop'],
  'un groupe a un jumeau dans chaque app');

-- La contrainte de la table tient aussi hors de twin_group -----------------------------------
reset role;
select throws_ok(
  $$update public.group_twins set remote_code = 'ABC234'
    where group_id = current_setting('agora_test.group')::uuid and app = 'dewdrop'$$,
  '23514', null, 'la table refuse un code DewDrop de 6 caractères');

select * from finish();
rollback;
