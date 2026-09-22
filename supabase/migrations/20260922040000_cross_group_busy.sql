-- =============================================================================
-- Un rdv de groupe auquel on a répondu « présent » rend occupé ailleurs.
--
-- Jusqu'ici, l'agenda d'un groupe ne montrait d'un membre que ses agendas
-- personnels. Un rdv pris dans un autre groupe (le match du club, la soirée
-- des potes) le laissait libre, et « Trouver un créneau » le proposait.
-- private.resolve_group_agenda ajoute donc, pour chaque membre, les
-- instances des rdv d'AUTRES groupes auxquels il a répondu « présent » :
--   - un rdv ponctuel ou une occurrence modifiée : la réponse sans créneau ;
--   - une occurrence de série : celle-là seule (occurrence_start), telle que
--     le worker l'a dépliée.
--
-- Choix non évidents :
--   - jamais plus que « occupé » pour les autres : le détail appartient à
--     l'autre groupe, dont ce groupe-ci n'est pas forcément membre, même si
--     la personne y partage le détail de ses agendas ;
--   - dans la limite de ce que la personne partage ICI (share_level) : rien
--     si elle y est invisible ; les niveaux de l'agenda et du rdv, plus
--     restrictifs, l'emportent aussi, comme pour un rdv personnel ;
--   - elle-même voit le détail de ses engagements (elle est de l'autre
--     groupe) ; une publication Discord reste plafonnée par p_personal_cap ;
--   - « peut-être » et « absent » ne prennent pas le créneau ;
--   - les rdv du groupe regardé ne sont pas repris : ils y figurent déjà.
--
-- Invariant (inchangé) : cette fonction reste le seul chemin par lequel un
-- rdv atteint quelqu'un qui n'est pas de son agenda.
-- =============================================================================

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
