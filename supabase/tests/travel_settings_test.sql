-- Domicile (travel_settings) : une ligne par personne, lisible et modifiable
-- par elle seule — ni ses co-membres, ni anon, ni le worker — et effacée avec
-- le compte.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a9000000-0000-0000-0000-0000000000a9', 'ana@test.local', '{"display_name":"Ana"}'),
  ('b9000000-0000-0000-0000-0000000000b9', 'ben@test.local', '{"display_name":"Ben"}');
insert into public.groups (id, name) values ('90000000-0000-0000-0000-000000000009', 'Coloc');
insert into public.group_members (group_id, user_id, role, share_level) values
  ('90000000-0000-0000-0000-000000000009', 'a9000000-0000-0000-0000-0000000000a9', 'owner', 'details'),
  ('90000000-0000-0000-0000-000000000009', 'b9000000-0000-0000-0000-0000000000b9', 'member', 'details');

-- Ana pose son domicile -------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-0000000000a9","role":"authenticated"}';

select lives_ok(
  $$insert into public.travel_settings (home_address, home_lon, home_lat)
    values ('1 Place de l''Hôtel de Ville 51100 Reims', 4.031847, 49.257517)$$,
  'Ana enregistre son domicile');
-- La forme de l'upsert de PostgREST (on_conflict=user_id).
select lives_ok(
  $$insert into public.travel_settings (home_address, home_lon, home_lat)
    values ('Place Drouet d''Erlon 51100 Reims', 4.026938, 49.255543)
    on conflict (user_id) do update set home_address = excluded.home_address,
      home_lon = excluded.home_lon, home_lat = excluded.home_lat$$,
  'elle le remplace en le renvoyant');
select is(
  (select home_address from public.travel_settings),
  'Place Drouet d''Erlon 51100 Reims', 'elle relit son domicile, une seule ligne');
select throws_ok(
  $$insert into public.travel_settings (home_address, home_lon, home_lat)
    values ('   ', 4.0, 49.0)
    on conflict (user_id) do update set home_address = excluded.home_address$$,
  '23514', null, 'une adresse vide est refusée');
select throws_ok(
  $$update public.travel_settings set home_lat = 91$$,
  '23514', null, 'une latitude hors de [-90, 90] est refusée');

-- Ben, co-membre d'Ana ------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-0000000000b9","role":"authenticated"}';

select is(
  (select count(*)::int from public.travel_settings), 0,
  'Ben ne voit pas le domicile d''Ana, bien qu''ils partagent un groupe');
update public.travel_settings set home_address = 'Piraté'
where user_id = 'a9000000-0000-0000-0000-0000000000a9';
select throws_ok(
  $$insert into public.travel_settings (user_id, home_address, home_lon, home_lat)
    values ('a9000000-0000-0000-0000-0000000000a9', 'Piraté', 0, 0)$$,
  '42501', null, 'Ben ne pose pas de domicile au nom d''Ana');
select lives_ok(
  $$insert into public.travel_settings (home_address, home_lon, home_lat)
    values ('12 Rue de Vesle 51100 Reims', 4.02, 49.25)$$,
  'Ben pose le sien');

-- anon ----------------------------------------------------------------------------------------
set local role anon;
select throws_ok($$select * from public.travel_settings$$, '42501', null,
  'anon ne lit aucun domicile');

-- Vérifications côté serveur --------------------------------------------------------------------
reset role;
select is(
  (select home_address from public.travel_settings
   where user_id = 'a9000000-0000-0000-0000-0000000000a9'),
  'Place Drouet d''Erlon 51100 Reims', 'la mise à jour de Ben n''a pas touché Ana');
select ok(
  not has_table_privilege('agora_worker', 'public.travel_settings', 'select'),
  'le worker ne lit pas les domiciles : Discord et les assistants n''y ont pas accès');

-- Ben supprime son compte, Ana efface son domicile ----------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-0000000000b9","role":"authenticated"}';
select public.delete_my_account();
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-0000000000a9","role":"authenticated"}';
select lives_ok($$delete from public.travel_settings$$, 'Ana efface son domicile');

reset role;
select is((select count(*)::int from public.travel_settings), 0,
  'le domicile de Ben part avec son compte, celui d''Ana est effacé');

select * from finish();
rollback;
