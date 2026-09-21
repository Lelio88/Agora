-- Profil : langue et fuseau pris à l'inscription, fuseau validé à la
-- modification, langue recopiée dans les métadonnées lues par les e-mails.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-000000000001', 'ann@test.local',
   '{"display_name":"Ann","locale":"en","timezone":"America/New_York"}'),
  ('b0000000-0000-0000-0000-000000000002', 'ben@test.local',
   '{"display_name":"Ben","locale":"de","timezone":"Mars/Olympus"}'),
  ('c0000000-0000-0000-0000-000000000003', 'cy@test.local',
   '{"display_name":"Cy","timezone":"EST5EDT"}');

-- Inscription -------------------------------------------------------------------
select ok(
  (select locale = 'en' and timezone = 'America/New_York' from public.profiles
   where id = 'a0000000-0000-0000-0000-000000000001'),
  'la langue et le fuseau fournis à l''inscription arrivent dans le profil');

select ok(
  (select locale = 'fr' and timezone = 'Europe/Paris' from public.profiles
   where id = 'b0000000-0000-0000-0000-000000000002'),
  'une langue non prise en charge et un fuseau inconnu retombent sur fr et Europe/Paris');

select is(
  (select timezone from public.profiles where id = 'c0000000-0000-0000-0000-000000000003'),
  'Europe/Paris', 'un fuseau Postgres hors du format IANA ne fait pas échouer l''inscription');

-- Ann modifie son profil -----------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$update public.profiles set timezone = 'Asia/Tokyo'
    where id = 'a0000000-0000-0000-0000-000000000001'$$,
  'un fuseau IANA connu est accepté');

select throws_ok(
  $$update public.profiles set timezone = 'Mars/Olympus'
    where id = 'a0000000-0000-0000-0000-000000000001'$$,
  '22023', 'invalid_timezone', 'un fuseau inconnu est refusé');

select lives_ok(
  $$update public.profiles set locale = 'fr', display_name = 'Annie'
    where id = 'a0000000-0000-0000-0000-000000000001'$$,
  'on change sa langue et son nom');

select throws_ok(
  $$update public.profiles set created_at = now()
    where id = 'a0000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'les colonnes hors profil éditable restent fermées');

update public.profiles set display_name = 'Piraté'
where id = 'b0000000-0000-0000-0000-000000000002';

-- Vérifications côté serveur --------------------------------------------------------
reset role;
select is(
  (select raw_user_meta_data ->> 'locale' from auth.users
   where id = 'a0000000-0000-0000-0000-000000000001'),
  'fr', 'la langue du profil est recopiée pour les gabarits d''e-mail');

select is(
  (select display_name from public.profiles where id = 'b0000000-0000-0000-0000-000000000002'),
  'Ben', 'on ne modifie pas le profil d''un autre');

select * from finish();
rollback;
