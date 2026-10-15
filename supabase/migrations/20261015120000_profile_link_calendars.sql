-- =============================================================================
-- Lien de profil : choisir QUELS agendas il partage. « Travail » oui,
-- « Loisirs » non : chaque lien (donc chaque QR code) porte sa propre liste.
--
-- Choix non évidents :
--   - `calendar_ids` nul veut dire « tous les agendas » : c'est le sens des
--     liens créés avant cette migration, qui ne changent pas. Un lien neuf
--     de l'app porte toujours une liste explicite, jamais nulle ;
--   - la liste est un tableau et non une table de liaison : un agenda
--     supprimé laisse son identifiant dans le tableau, où il ne désigne plus
--     rien. Avec une table de liaison en cascade, un lien dont le dernier
--     agenda disparaît se retrouverait sans ligne, donc indiscernable d'un
--     lien « tous les agendas » : il partagerait soudain tout. Ici, il ne
--     partage plus rien ;
--   - un agenda ajouté après coup n'est jamais partagé tout seul ;
--   - à la création, chaque identifiant doit être un agenda du créateur qui
--     n'est pas un proche (`invalid_calendars` sinon, sans dire lequel) ;
--   - les autres plafonds ne changent pas : l'agenda choisi reste plafonné
--     par sa visibilité, et un agenda invisible ne sort jamais.
--
-- Invariants (supabase/tests/profile_link_calendars_test.sql) : jamais plus
-- d'agendas que ceux de la liste ; une liste vide ou étrangère est refusée ;
-- un agenda supprimé ne rend pas le lien plus bavard.
-- =============================================================================

alter table public.profile_links
  add column calendar_ids uuid[]
    check (calendar_ids is null or cardinality(calendar_ids) between 1 and 100);

-- Le nouveau paramètre est facultatif (nul : tous les agendas) : une app
-- plus ancienne, qui n'envoie que le nom et le niveau, continue de marcher.
drop function public.create_profile_link(text, public.visibility);
create function public.create_profile_link(
  p_label text,
  p_share_level public.visibility,
  p_calendar_ids uuid[] default null
)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_label text := btrim(coalesce(p_label, ''));
  v_code text;
  v_try integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_share_level is null or p_share_level = 'invisible' then
    raise exception 'invalid_share_level' using errcode = '22023';
  end if;
  if char_length(v_label) not between 1 and 60 then
    raise exception 'invalid_label' using errcode = '22023';
  end if;
  if p_calendar_ids is not null and (
       cardinality(p_calendar_ids) not between 1 and 100
       or array_position(p_calendar_ids, null) is not null
       or (select count(distinct c.id) from public.calendars c
           where c.id = any (p_calendar_ids)
             and c.owner_id = auth.uid() and not c.contact)
          <> (select count(distinct i) from unnest(p_calendar_ids) i)
     ) then
    raise exception 'invalid_calendars' using errcode = '22023';
  end if;
  -- Deux créations simultanées ne doivent pas dépasser la limite.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 2));
  if (select count(*) from public.profile_links l where l.owner_id = auth.uid()) >= 20 then
    raise exception 'too_many_links' using errcode = 'P0001';
  end if;
  for v_try in 1..3 loop
    begin
      insert into public.profile_links (code, label, share_level, calendar_ids)
      values (private.random_invite_code(), v_label, p_share_level, p_calendar_ids)
      returning code into v_code;
      return v_code;
    exception when unique_violation then
      null; -- code déjà pris (une chance sur 10^12) : on en tire un autre
    end;
  end loop;
  raise exception 'code_unavailable' using errcode = 'P0001';
end;
$$;

revoke execute on function public.create_profile_link(text, public.visibility, uuid[])
  from public, anon;
grant execute on function public.create_profile_link(text, public.visibility, uuid[])
  to authenticated;

-- La copie ne lit que les agendas de la liste (nul : tous, comme avant).
drop function private.copy_profile_events(uuid, public.visibility, uuid);
create function private.copy_profile_events(
  p_owner uuid, p_level public.visibility, p_calendar_id uuid, p_calendar_ids uuid[]
)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  -- Le titre d'une plage occupée, dans la langue de celui qui reçoit la copie.
  v_busy text := coalesce(
    (select case p.locale when 'en' then 'Busy' else 'Occupé' end
     from public.profiles p where p.id = auth.uid()),
    'Occupé');
begin
  delete from public.events e
  where e.calendar_id = p_calendar_id and e.source_uid like 'profil:%';

  -- Rdv ponctuels et lignes maîtresses (une série entière, même ancienne :
  -- le worker n'en dépliera que ce qui reste à venir).
  insert into public.events (calendar_id, source_uid, title, location, starts_at, ends_at,
                             all_day, timezone, rrule, exdates, created_by)
  select p_calendar_id, 'profil:' || e.id,
         case when greatest(p_level, c.visibility, e.visibility) = 'details'
              then e.title else v_busy end,
         case when greatest(p_level, c.visibility, e.visibility) = 'details'
              then e.location end,
         e.starts_at, e.ends_at, e.all_day, e.timezone, e.rrule,
         -- Une séance invisible, ou déplacée dans le passé, devient un trou :
         -- sinon son créneau d'origine reviendrait comme une plage occupée.
         array(
           select distinct u from unnest(
             e.exdates || coalesce((
               select array_agg(x.recurrence_id)
               from public.events x
               where x.series_id = e.id
                 and (greatest(p_level, c.visibility, e.visibility, x.visibility) = 'invisible'
                      or x.ends_at < now())
             ), '{}')
           ) u
         ),
         auth.uid()
  from public.events e
  join public.calendars c on c.id = e.calendar_id
  where c.owner_id = p_owner and not c.contact
    and (p_calendar_ids is null or c.id = any (p_calendar_ids))
    and e.series_id is null
    and greatest(p_level, c.visibility, e.visibility) <> 'invisible'
    and (e.rrule is not null or e.ends_at >= now());

  -- Séances modifiées d'une série copiée.
  insert into public.events (calendar_id, source_uid, series_id, recurrence_id, title, location,
                             starts_at, ends_at, all_day, timezone, created_by)
  select p_calendar_id, 'profil:' || e.id, copy.id, e.recurrence_id,
         case when greatest(p_level, c.visibility, m.visibility, e.visibility) = 'details'
              then e.title else v_busy end,
         case when greatest(p_level, c.visibility, m.visibility, e.visibility) = 'details'
              then e.location end,
         e.starts_at, e.ends_at, e.all_day, e.timezone, auth.uid()
  from public.events e
  join public.events m on m.id = e.series_id
  join public.calendars c on c.id = e.calendar_id
  join public.events copy
    on copy.calendar_id = p_calendar_id and copy.source_uid = 'profil:' || m.id
  where c.owner_id = p_owner and not c.contact
    and (p_calendar_ids is null or c.id = any (p_calendar_ids))
    and e.ends_at >= now()
    and greatest(p_level, c.visibility, m.visibility, e.visibility) <> 'invisible';

  -- Une copie énorme bloquerait la base : on la refuse (tout est annulé).
  if (select count(*) from public.events e
      where e.calendar_id = p_calendar_id and e.source_uid like 'profil:%') > 2000 then
    raise exception 'profile_too_large' using errcode = 'P0001';
  end if;
end;
$$;

revoke execute on function private.copy_profile_events(uuid, public.visibility, uuid, uuid[])
  from public, anon, authenticated, service_role;

-- Même fonction qu'avant, qui transmet la liste du lien à la copie.
create or replace function public.import_profile(p_code text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_link public.profile_links;
  v_calendar_id uuid;
  v_kind public.calendar_kind;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  perform private.check_profile_link_rate();
  select * into v_link from public.profile_links l where l.code = upper(btrim(p_code));
  if not found then
    perform private.note_profile_link_failure();
    return null;
  end if;
  if v_link.owner_id = auth.uid() then
    raise exception 'own_profile' using errcode = 'P0001';
  end if;

  select c.id, c.kind into v_calendar_id, v_kind from public.calendars c
  where c.owner_id = auth.uid() and c.contact_user_id = v_link.owner_id;
  if not found then
    begin
      insert into public.calendars (owner_id, kind, name, visibility, contact, contact_user_id)
      select auth.uid(), 'native', p.display_name, 'invisible', true, v_link.owner_id
      from public.profiles p where p.id = v_link.owner_id
      returning id, kind into v_calendar_id, v_kind;
    exception when unique_violation then
      -- Deux ouvertures simultanées : l'autre a créé le proche.
      select c.id, c.kind into v_calendar_id, v_kind from public.calendars c
      where c.owner_id = auth.uid() and c.contact_user_id = v_link.owner_id;
    end;
  end if;
  if v_kind <> 'native' then
    raise exception 'contact_not_native' using errcode = 'P0001';
  end if;

  -- Deux appuis simultanés ne doivent pas copier deux fois.
  perform pg_advisory_xact_lock(hashtextextended(v_calendar_id::text, 1));
  perform private.copy_profile_events(
    v_link.owner_id, v_link.share_level, v_calendar_id, v_link.calendar_ids);
  return v_calendar_id;
end;
$$;
