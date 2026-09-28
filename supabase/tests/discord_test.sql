-- Bot Discord : liaison d'un salon, lectures du worker, récaps et rappels.
-- La règle vérifiée ici : le demandeur ne lit que ce que l'app lui
-- montrerait ; une publication dans un salon plafonne les rdv personnels à
-- « occupé » ; un rappel ne porte que sur un rdv du groupe.
begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

-- Fixtures (en postgres) ------------------------------------------------------
-- Ada (propriétaire des Potes, Discord relié), Ben (membre, Discord relié),
-- Cyd (hors du groupe, Discord relié), Dan (membre, pas de Discord).
insert into auth.users (id, email, raw_user_meta_data) values
  ('d1000000-0000-0000-0000-000000000001', 'ada@test.local', '{"display_name":"Ada"}'),
  ('d1000000-0000-0000-0000-000000000002', 'ben@test.local', '{"display_name":"Ben"}'),
  ('d1000000-0000-0000-0000-000000000003', 'cyd@test.local', '{"display_name":"Cyd"}'),
  ('d1000000-0000-0000-0000-000000000004', 'dan@test.local', '{"display_name":"Dan"}');

insert into auth.identities (provider_id, user_id, identity_data, provider) values
  ('900000000000000001', 'd1000000-0000-0000-0000-000000000001', '{"sub":"900000000000000001"}', 'discord'),
  ('900000000000000002', 'd1000000-0000-0000-0000-000000000002', '{"sub":"900000000000000002"}', 'discord'),
  ('900000000000000003', 'd1000000-0000-0000-0000-000000000003', '{"sub":"900000000000000003"}', 'discord');

insert into public.groups (id, name) values
  ('d2000000-0000-0000-0000-000000000001', 'Potes'),
  ('d2000000-0000-0000-0000-000000000002', 'Club');

insert into public.group_members (group_id, user_id, role, share_level) values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'owner', 'details'),
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002', 'member', 'details'),
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000004', 'member', 'details'),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'owner', 'details');

insert into public.calendars (id, owner_id, group_id, name) values
  ('d3000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002', null, 'Perso de Ben'),
  ('d3000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', null, 'Masqué de Ben'),
  ('d3000000-0000-0000-0000-000000000003', null, 'd2000000-0000-0000-0000-000000000001', 'Potes');

insert into public.calendar_preferences (user_id, calendar_id, hidden) values
  ('d1000000-0000-0000-0000-000000000002', 'd3000000-0000-0000-0000-000000000002', true);

insert into public.events (id, calendar_id, title, location, starts_at, ends_at) values
  ('d4000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001', 'Kiné', 'Cabinet',
   now() + interval '30 minutes', now() + interval '90 minutes'),
  ('d4000000-0000-0000-0000-000000000002', 'd3000000-0000-0000-0000-000000000002', 'Caché', null,
   now() + interval '2 hours', now() + interval '3 hours'),
  ('d4000000-0000-0000-0000-000000000003', 'd3000000-0000-0000-0000-000000000003', 'Resto', 'Chez Paul',
   now() + interval '40 minutes', now() + interval '3 hours'),
  ('d4000000-0000-0000-0000-000000000004', 'd3000000-0000-0000-0000-000000000003', 'Rando', null,
   now() + interval '3 days', now() + interval '3 days 4 hours');

-- Le code de liaison, dans l'app ------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.create_discord_link_code('d2000000-0000-0000-0000-000000000001')$$,
  '42501', 'not_group_admin', 'un simple membre ne crée pas de code de liaison');
select throws_ok($$select * from private.discord_user('900000000000000002')$$, '42501', null,
  'un utilisateur n''appelle pas les fonctions du worker');

set local request.jwt.claims = '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('agora_test.old_code',
  public.create_discord_link_code('d2000000-0000-0000-0000-000000000001'), true);
select set_config('agora_test.code',
  public.create_discord_link_code('d2000000-0000-0000-0000-000000000001'), true);

-- Relier le salon, par le worker --------------------------------------------------
reset role;
grant usage on schema extensions to agora_worker;
set local role agora_worker;

select is((select user_id from private.discord_user('900000000000000002')),
  'd1000000-0000-0000-0000-000000000002'::uuid, 'un compte Discord relié désigne son compte Agora');
select is((select count(*)::int from private.discord_user('999')), 0,
  'un compte Discord non relié ne désigne personne');

select throws_ok(
  format($$select private.discord_link_channel(%L, '1', '10', 'général', '999')$$, current_setting('agora_test.code')),
  '42501', 'discord_not_linked', 'relier un salon demande un compte Discord relié');
select throws_ok(
  format($$select private.discord_link_channel(%L, '1', '10', 'général', '900000000000000002')$$, current_setting('agora_test.code')),
  '42501', 'not_group_admin', 'un code qui fuit ne suffit pas : il faut être admin du groupe');
select throws_ok(
  format($$select private.discord_link_channel(%L, '1', '10', 'général', '900000000000000001')$$, current_setting('agora_test.old_code')),
  'P0002', 'link_code_invalid', 'un nouveau code remplace le précédent');
select is(
  private.discord_link_channel(lower(current_setting('agora_test.code')), '1', '10', 'général', '900000000000000001'),
  'Potes', 'l''admin relie le salon avec le code');
select throws_ok(
  format($$select private.discord_link_channel(%L, '1', '10', 'général', '900000000000000001')$$, current_setting('agora_test.code')),
  'P0002', 'link_code_invalid', 'un code ne sert qu''une fois');
select is((select name from private.discord_channel_group('10')), 'Potes',
  'le salon désigne son groupe');
reset role;
select is((select channel_name from public.discord_channels where channel_id = '10'), 'général',
  'le nom du salon est gardé pour l''app');
set local role agora_worker;

reset role;
insert into private.discord_link_codes (code, group_id, created_by)
  values ('CLUBCODE', 'd2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003');
insert into private.discord_link_codes (code, group_id, created_by, expires_at)
  values ('EXPIRED1', 'd2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003',
          now() - interval '1 second');
set local role agora_worker;
select throws_ok($$select private.discord_link_channel('CLUBCODE', '1', '10', 'général', '900000000000000003')$$,
  '23505', 'channel_taken', 'un salon ne sert qu''un groupe');
select throws_ok($$select private.discord_link_channel('EXPIRED1', '1', '11', 'général', '900000000000000003')$$,
  'P0002', 'link_code_invalid', 'un code expiré ne relie rien');

-- Délier : mêmes exigences que relier -------------------------------------------
select throws_ok($$select private.discord_unlink_channel('10', '999')$$,
  '42501', 'discord_not_linked', 'délier demande un compte Discord relié');
select throws_ok($$select private.discord_unlink_channel('10', '900000000000000003')$$,
  '42501', 'not_group_admin', 'un modérateur étranger au groupe ne délie pas le salon');
select is(private.discord_unlink_channel('99', '900000000000000001'), null,
  'délier un salon qui n''est relié à rien ne rend rien');

-- Lire au nom du demandeur -----------------------------------------------------
select throws_ok(
  $$select * from private.discord_group_agenda('d2000000-0000-0000-0000-000000000001',
      'd1000000-0000-0000-0000-000000000003', now(), now() + interval '7 days')$$,
  '42501', 'not_a_member', 'hors du groupe, pas d''agenda');
select is(
  (select title from private.discord_group_agenda('d2000000-0000-0000-0000-000000000001',
      'd1000000-0000-0000-0000-000000000001', now(), now() + interval '7 days')
   where display_name = 'Ben' and not is_group_event and starts_at < now() + interval '1 hour'),
  'Kiné', 'un membre voit ce que l''app lui montrerait (Ben partage le détail)');
select is(
  (select count(*)::int from private.discord_group_members('d2000000-0000-0000-0000-000000000001',
      'd1000000-0000-0000-0000-000000000001')),
  3, 'les membres du groupe, pour /dispo');

select is(
  (select array_agg(title order by starts_at) from private.discord_personal_agenda(
      'd1000000-0000-0000-0000-000000000002', now(), now() + interval '7 days')),
  array['Kiné', 'Resto', 'Rando'], 'l''agenda perso : ses agendas et ceux du groupe, moins les masqués');

-- Publier dans le salon : plafonné à « occupé » ---------------------------------
select is(
  (select level::text from private.discord_recap_agenda('d2000000-0000-0000-0000-000000000001',
      now(), now() + interval '7 days') where display_name = 'Ben' and starts_at < now() + interval '1 hour'),
  'busy', 'un récap public plafonne un rdv personnel à « occupé »');
select is(
  (select count(*)::int from private.discord_recap_agenda('d2000000-0000-0000-0000-000000000001',
      now(), now() + interval '7 days') where title = 'Kiné' or location = 'Cabinet'),
  0, 'ni titre ni lieu d''un rdv personnel dans un récap');
select is(
  (select title from private.discord_recap_agenda('d2000000-0000-0000-0000-000000000001',
      now(), now() + interval '1 day') where is_group_event),
  'Resto', 'un rdv du groupe reste en détail dans un récap');

-- Récaps et rappels -------------------------------------------------------------
reset role;
update public.discord_channels
  set recap = 'daily', timezone = 'UTC',
      recap_hour = extract(hour from now() at time zone 'UTC')::smallint,
      reminder_minutes = 60
  where group_id = 'd2000000-0000-0000-0000-000000000001';
set local role agora_worker;

select is((select count(*)::int from private.discord_claim_recaps()), 1,
  'un récap dû est réclamé');
select is((select count(*)::int from private.discord_claim_recaps()), 0,
  'un récap réclamé ne l''est pas deux fois');

select is((select array_agg(title) from private.discord_claim_reminders()), array['Resto'],
  'un rappel ne porte que sur un rdv du groupe, dans le délai');
select is((select count(*)::int from private.discord_claim_reminders()), 0,
  'un rdv n''est rappelé qu''une fois');

-- Réglages dans l'app ------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"d1000000-0000-0000-0000-000000000004","role":"authenticated"}';
select is((select channel_id from public.discord_channels), '10',
  'un membre voit le salon relié à son groupe');
update public.discord_channels set recap = 'off';
select is((select recap::text from public.discord_channels), 'daily',
  'un simple membre ne change pas les réglages');
select throws_ok($$update public.discord_channels set channel_id = '99'$$, '42501', null,
  'personne ne change le salon depuis l''app');

set local request.jwt.claims = '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}';
update public.discord_channels set recap = 'off';
select is((select recap::text from public.discord_channels), 'off',
  'un admin règle le récap');
delete from public.discord_channels;
select is((select count(*)::int from public.discord_channels), 0,
  'un admin délie le salon');

select * from finish();
rollback;
