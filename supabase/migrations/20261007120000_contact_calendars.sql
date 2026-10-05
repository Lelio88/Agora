-- =============================================================================
-- Agendas de proches : l'agenda qu'un utilisateur tient pour quelqu'un d'autre
-- (ses repos, son anniversaire…), pour lui seul.
--
-- Choix non évidents :
--   - un agenda de proche est un agenda personnel ordinaire (natif ou importé
--     par lien iCal), marqué `contact`. Il est toujours `invisible` pour les
--     groupes (contrainte), et le marquage ne s'enlève pas (aucun droit de
--     mise à jour sur la colonne) : rendre visibles les repos de Léa les
--     ferait passer pour les créneaux pris de son propriétaire ;
--   - private.resolve_group_agenda rend à chacun SES rdv en détail, quelle que
--     soit leur visibilité : sans le filtre ajouté ici, l'agenda d'un proche
--     apparaîtrait dans la vue du groupe comme les créneaux pris de son
--     propriétaire, et « Trouver un créneau » (app, /dispo, assistant) le
--     croirait occupé. Seule la partie « agendas personnels » change ;
--   - delete_calendar ne compte pas les agendas de proches : « le dernier
--     agenda natif » est celui de l'utilisateur lui-même ;
--   - add_ics_calendar gagne `p_contact` : le planning d'un ami s'importe
--     comme un autre lien iCal (relu par le worker), dans un agenda de proche.
--
-- Invariants (supabase/tests/contact_calendars_test.sql) : un agenda de
-- proche est personnel, invisible, et absent de toute vue de groupe.
-- =============================================================================

alter table public.calendars add column contact boolean not null default false;
alter table public.calendars add constraint calendars_contact_is_private
  -- « is not distinct from » : une visibilité nulle (« hérite du groupe »)
  -- ferait valoir `= 'invisible'` NULL, qu'une contrainte laisse passer.
  check (not contact or (owner_id is not null and visibility is not distinct from 'invisible'));
grant insert (contact) on public.calendars to authenticated;

-- Vue d'un groupe : à l'identique de 20260922040000_cross_group_busy.sql, hors agendas de proches.
create or replace function private.resolve_group_agenda(
  p_group_id uuid,
  p_viewer uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_personal_cap public.visibility
)
returns table (
  event_id uuid,
  user_id uuid,
  is_group_event boolean,
  level public.visibility,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language sql stable security definer set search_path = '' as $$
  with personal as (
    select e.id, c.owner_id, false as is_group_event, e.title, e.location,
           e.starts_at, e.ends_at, e.all_day, e.rrule,
           case
             when c.owner_id = p_viewer then 'details'::public.visibility
             else greatest(
               gm.share_level,
               coalesce(c.visibility, 'details'),
               coalesce(e.visibility, 'details'),
               p_personal_cap
             )
           end as level
    from public.group_members gm
    join public.calendars c on c.owner_id = gm.user_id
    join public.events e on e.calendar_id = c.id
    where gm.group_id = p_group_id
      -- L'agenda d'un proche parle de quelqu'un d'autre : il ne sort jamais
      -- vers un groupe, pas même vers son propriétaire (ses créneaux pris).
      and not c.contact
  ),
  shared as (
    select e.id, null::uuid, true, e.title, e.location,
           e.starts_at, e.ends_at, e.all_day, e.rrule,
           'details'::public.visibility
    from public.calendars c
    join public.events e on e.calendar_id = c.id
    where c.group_id = p_group_id
  ),
  candidates as (
    select * from personal
    union all
    select * from shared
  ),
  -- Réponses « présent » des membres d'ici aux rdv d'autres groupes.
  committed as (
    select e.id, gm.user_id as owner_id, e.title, e.location, e.starts_at,
           e.ends_at, e.all_day, e.rrule, r.occurrence_start,
           case
             when gm.user_id = p_viewer then 'details'::public.visibility
             else greatest(
               gm.share_level,
               'busy'::public.visibility,
               coalesce(c.visibility, 'details'),
               coalesce(e.visibility, 'details'),
               p_personal_cap
             )
           end as level
    from public.group_members gm
    join public.event_responses r on r.user_id = gm.user_id and r.status = 'yes'
    join public.events e on e.id = r.event_id
    join public.calendars c on c.id = e.calendar_id
    where gm.group_id = p_group_id
      and c.group_id <> p_group_id
  ),
  instances as (
    select cd.id, cd.owner_id, cd.is_group_event, cd.level, cd.title,
           cd.location, cd.starts_at, cd.ends_at, cd.all_day
    from candidates cd
    where cd.rrule is null
    union all
    select cd.id, cd.owner_id, cd.is_group_event, cd.level, cd.title,
           cd.location, o.starts_at, o.ends_at, cd.all_day
    from candidates cd
    join public.event_occurrences o on o.event_id = cd.id
    where cd.rrule is not null
    union all
    select cm.id, cm.owner_id, false, cm.level, cm.title,
           cm.location, cm.starts_at, cm.ends_at, cm.all_day
    from committed cm
    where cm.rrule is null and cm.occurrence_start is null
    union all
    select cm.id, cm.owner_id, false, cm.level, cm.title,
           cm.location, o.starts_at, o.ends_at, cm.all_day
    from committed cm
    join public.event_occurrences o
      on o.event_id = cm.id and o.starts_at = cm.occurrence_start
    where cm.rrule is not null
  )
  select
    case when i.level = 'details' then i.id end,
    i.owner_id,
    i.is_group_event,
    i.level,
    case when i.level = 'details' then i.title end,
    case when i.level = 'details' then i.location end,
    i.starts_at,
    i.ends_at,
    i.all_day
  from instances i
  where i.level <> 'invisible'
    and i.starts_at < p_to
    -- chevauchement de [from, to[, rdv de durée nulle compris
    and (i.ends_at > p_from or i.starts_at >= p_from)
  order by i.starts_at, i.owner_id nulls first;
$$;

create or replace function public.delete_calendar(p_calendar_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_calendar public.calendars;
begin
  select * into v_calendar from public.calendars c
  where c.id = p_calendar_id and c.owner_id = auth.uid();
  if not found then
    raise exception 'calendar_not_found' using errcode = 'P0002';
  end if;
  if v_calendar.kind = 'native' and not v_calendar.contact then
    perform 1 from public.calendars c
    where c.owner_id = auth.uid() and c.kind = 'native' and not c.contact
    order by c.id
    for update;
    if (select count(*) from public.calendars c
        where c.owner_id = auth.uid() and c.kind = 'native' and not c.contact) <= 1 then
      raise exception 'last_native_calendar' using errcode = 'P0001';
    end if;
  end if;
  delete from public.calendars c where c.id = p_calendar_id;
end;
$$;

drop function public.add_ics_calendar(text, text, text);

create function public.add_ics_calendar(
  p_name text,
  p_url text,
  p_color text default null,
  p_contact boolean default false
)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_url text := btrim(p_url);
  v_calendar_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  -- webcal:// est le même flux servi en https.
  if v_url ~* '^webcal://' then
    v_url := 'https://' || substr(v_url, 10);
  end if;
  if v_url !~* '^https://[^/\s@]+(/\S*)?$' or char_length(v_url) > 2048 then
    raise exception 'invalid_feed_url' using errcode = '22023';
  end if;
  if (select count(*) from public.calendars c
      where c.owner_id = auth.uid() and c.kind = 'ics') >= 10 then
    raise exception 'too_many_feeds' using errcode = '54000';
  end if;
  insert into public.calendars (owner_id, kind, name, color, visibility, contact)
  values (auth.uid(), 'ics', btrim(p_name), p_color,
          case when coalesce(p_contact, false) then 'invisible'::public.visibility end,
          coalesce(p_contact, false))
  returning id into v_calendar_id;
  insert into private.calendar_feeds (calendar_id, url) values (v_calendar_id, v_url);
  return v_calendar_id;
end;
$$;

revoke execute on function public.add_ics_calendar(text, text, text, boolean) from public, anon;
grant execute on function public.add_ics_calendar(text, text, text, boolean) to authenticated;
