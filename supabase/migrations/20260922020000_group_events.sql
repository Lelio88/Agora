-- =============================================================================
-- Rdv de groupe : réponses présent / peut-être / absent.
--
-- Un rdv de groupe est un rdv de l'agenda du groupe (calendars.group_id) :
-- tout membre en propose (private.can_add_event), le créateur et les admins
-- le modifient (private.can_edit_event) — rien de neuf ici. Ce qui s'ajoute :
--   - event_responses : une réponse par personne et par instance. Une série
--     se répond occurrence par occurrence (occurrence_start = créneau
--     d'origine) ; un rdv ponctuel ou une occurrence modifiée (ligne à part)
--     sans créneau ;
--   - respond_to_event : seule écriture, qui vérifie l'appartenance au
--     groupe et que le créneau est bien une occurrence ;
--   - my_agenda rend ma réponse avec chaque instance.
--
-- Choix non évidents :
--   - les réponses suivent une occurrence qui devient un rdv à part, dans
--     les deux sens : replace_occurrence supprime puis recrée la ligne à
--     chaque nouvelle modification, et la cascade les aurait effacées ;
--   - changer l'horaire ou la règle d'une série efface les réponses de ses
--     occurrences (les créneaux ont bougé), comme ses exceptions ; changer
--     l'heure d'un rdv ponctuel les garde ;
--   - quitter un groupe efface ses réponses aux rdv de ce groupe : les
--     autres ne verraient plus qu'un nom disparu.
--
-- Invariant : une réponse n'est lisible que des membres du groupe du rdv.
-- =============================================================================

create type public.response_status as enum ('yes', 'maybe', 'no');

create table public.event_responses (
  event_id uuid not null references public.events (id) on delete cascade,
  -- Créneau d'origine d'une occurrence de série ; null pour un rdv ponctuel
  -- ou une occurrence modifiée.
  occurrence_start timestamptz,
  user_id uuid not null references public.profiles (id) on delete cascade,
  status public.response_status not null,
  updated_at timestamptz not null default now()
);
-- NULLS NOT DISTINCT : une seule réponse par personne à un rdv ponctuel.
create unique index event_responses_key on public.event_responses
  (event_id, occurrence_start, user_id) nulls not distinct;
create index event_responses_user_id_idx on public.event_responses (user_id);

alter table public.event_responses enable row level security;

create policy "event_responses: membres du groupe du rdv" on public.event_responses
  for select to authenticated
  using (exists (
    select 1 from public.events e
    join public.calendars c on c.id = e.calendar_id
    where e.id = event_id and c.group_id is not null and private.is_group_member(c.group_id)
  ));

grant select on public.event_responses to authenticated;

-- -----------------------------------------------------------------------------

-- Répond (ou retire sa réponse, p_status null) à une instance d'un rdv de
-- groupe dont on est membre.
create function public.respond_to_event(
  p_event_id uuid,
  p_occurrence_start timestamptz,
  p_status public.response_status
)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_group_id uuid;
  v_rrule text;
begin
  select c.group_id, e.rrule into v_group_id, v_rrule
  from public.events e
  join public.calendars c on c.id = e.calendar_id
  where e.id = p_event_id;
  if v_group_id is null or not private.is_group_member(v_group_id) then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  if (v_rrule is null) <> (p_occurrence_start is null)
     or (v_rrule is not null and not exists (
       select 1 from public.event_occurrences o
       where o.event_id = p_event_id and o.starts_at = p_occurrence_start)) then
    raise exception 'invalid_occurrence' using errcode = '22023';
  end if;
  if p_status is null then
    delete from public.event_responses r
    where r.event_id = p_event_id
      and r.occurrence_start is not distinct from p_occurrence_start
      and r.user_id = auth.uid();
    return;
  end if;
  insert into public.event_responses (event_id, occurrence_start, user_id, status)
  values (p_event_id, p_occurrence_start, auth.uid(), p_status)
  on conflict (event_id, occurrence_start, user_id)
  do update set status = excluded.status, updated_at = now();
end;
$$;

-- Une occurrence devient un rdv à part : ses réponses la suivent.
create function private.carry_occurrence_responses()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.event_responses (event_id, occurrence_start, user_id, status, updated_at)
  select new.id, null, r.user_id, r.status, r.updated_at
  from public.event_responses r
  where r.event_id = new.series_id and r.occurrence_start = new.recurrence_id
  on conflict do nothing;
  delete from public.event_responses r
  where r.event_id = new.series_id and r.occurrence_start = new.recurrence_id;
  return null;
end;
$$;

create trigger events_carry_occurrence_responses
  after insert on public.events
  for each row when (new.series_id is not null)
  execute function private.carry_occurrence_responses();

-- Un rdv à part disparaît (nouvelle modification de l'occurrence, horaire de
-- la série changé) : ses réponses reviennent à leur créneau, tant que la
-- série existe (dans une suppression en cascade, elle n'existe déjà plus).
create function private.return_occurrence_responses()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.events e where e.id = old.series_id) then
    insert into public.event_responses (event_id, occurrence_start, user_id, status, updated_at)
    select old.series_id, old.recurrence_id, r.user_id, r.status, r.updated_at
    from public.event_responses r
    where r.event_id = old.id and r.occurrence_start is null
    on conflict do nothing;
  end if;
  return old;
end;
$$;

create trigger events_return_occurrence_responses
  before delete on public.events
  for each row when (old.series_id is not null)
  execute function private.return_occurrence_responses();

-- Les créneaux d'une série ont bougé : les réponses de ses occurrences ne
-- valent plus. Une règle ajoutée ou retirée efface toutes les réponses.
create function private.reset_event_responses()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.rrule is distinct from old.rrule then
    delete from public.event_responses r where r.event_id = new.id;
  elsif new.rrule is not null
        and (new.starts_at is distinct from old.starts_at
             or new.timezone is distinct from old.timezone
             or new.all_day is distinct from old.all_day) then
    delete from public.event_responses r
    where r.event_id = new.id and r.occurrence_start is not null;
  end if;
  return null;
end;
$$;

create trigger events_reset_event_responses
  after update of starts_at, timezone, all_day, rrule on public.events
  for each row execute function private.reset_event_responses();

-- Quitter un groupe (ou en être exclu) efface ses réponses à ses rdv.
create function private.forget_member_responses()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.event_responses r
  using public.events e, public.calendars c
  where r.user_id = old.user_id and r.event_id = e.id
    and e.calendar_id = c.id and c.group_id = old.group_id;
  return null;
end;
$$;

create trigger group_members_forget_responses
  after delete on public.group_members
  for each row execute function private.forget_member_responses();

-- -----------------------------------------------------------------------------
-- my_agenda rend ma réponse avec chaque instance (null hors d'un groupe, ou
-- sans réponse). Nouvelle colonne : la fonction est recréée.
-- -----------------------------------------------------------------------------

drop function public.my_agenda(timestamptz, timestamptz);

create function public.my_agenda(p_from timestamptz, p_to timestamptz)
returns table (
  event_id uuid,
  series_id uuid,
  original_start timestamptz,
  calendar_id uuid,
  title text,
  location text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean,
  timezone text,
  rrule text,
  visibility public.visibility,
  my_response public.response_status
)
language plpgsql stable security invoker set search_path = '' as $$
begin
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select e.id, e.series_id, e.recurrence_id, e.calendar_id, e.title, e.location,
           e.description, e.starts_at, e.ends_at, e.all_day, e.timezone,
           coalesce(e.rrule, m.rrule), e.visibility, r.status
    from public.events e
    left join public.events m on m.id = e.series_id
    left join public.event_responses r
      on r.event_id = e.id and r.occurrence_start is null and r.user_id = auth.uid()
    where e.rrule is null
      and e.starts_at < p_to and (e.ends_at > p_from or e.starts_at >= p_from)
    union all
    select e.id, e.id, o.starts_at, e.calendar_id, e.title, e.location,
           e.description, o.starts_at, o.ends_at, e.all_day, e.timezone, e.rrule,
           e.visibility, r.status
    from public.event_occurrences o
    join public.events e on e.id = o.event_id
    left join public.event_responses r
      on r.event_id = e.id and r.occurrence_start = o.starts_at and r.user_id = auth.uid()
    where o.starts_at < p_to and (o.ends_at > p_from or o.starts_at >= p_from)
    order by 8;
end;
$$;

revoke execute on function public.my_agenda(timestamptz, timestamptz),
  public.respond_to_event(uuid, timestamptz, public.response_status)
  from public, anon;
grant execute on function public.my_agenda(timestamptz, timestamptz),
  public.respond_to_event(uuid, timestamptz, public.response_status)
  to authenticated;
revoke execute on function private.carry_occurrence_responses(),
  private.return_occurrence_responses(), private.reset_event_responses(),
  private.forget_member_responses()
  from public, anon, authenticated;
