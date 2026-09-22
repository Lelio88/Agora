-- =============================================================================
-- update_series : modifier « toute la série » depuis une de ses occurrences.
--
-- Pourquoi une RPC : l'app ne connaît que l'occurrence touchée, pas la
-- ligne maîtresse. Réécrire la série avec les dates de cette occurrence
-- la ferait commencer là (les occurrences précédentes disparaissaient, et
-- le « nouvel horaire » effaçait toutes les exceptions). Ici, la série se
-- DÉCALE d'autant que l'occurrence :
--   - de jours : écart entre la date de l'occurrence et sa nouvelle date,
--     lues dans le fuseau de la série (en UTC pour une journée entière) ;
--   - d'heure : la nouvelle heure LOCALE de l'occurrence devient celle de
--     la série (18 h reste 18 h de part et d'autre du changement d'heure) ;
--   - la durée est celle de l'occurrence modifiée.
-- Une modification sans changement de date ni d'heure laisse l'horaire, et
-- donc les exceptions, intacts.
--
-- Le même fichier redéfinit my_agenda (voir plus bas).
--
-- Jours de répétition : avec p_follow_weekdays, les jours BYDAY de la règle
-- sont décalés du même écart de jours, compté ICI, dans le fuseau de la
-- série (l'app, dans le fuseau de l'appareil, pouvait compter autrement
-- près de minuit). C'est l'app qui sait si l'utilisateur a changé les jours
-- lui-même, auquel cas elle ne demande pas ce décalage. Une règle avancée
-- (jour ordinal, « 2TU ») n'est jamais réécrite.
--
-- Invariants : SECURITY INVOKER, la RLS et les droits par colonne décident
-- de ce qu'on peut modifier ; une série illisible ou non modifiable répond
-- event_not_found.
-- =============================================================================

create function public.update_series(
  p_series_id uuid,
  p_occurrence_start timestamptz,
  p_calendar_id uuid,
  p_title text,
  p_location text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_all_day boolean,
  p_rrule text,
  p_visibility public.visibility,
  p_follow_weekdays boolean
)
returns void language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_series public.events;
  v_shift integer;
  v_master_day date;
  v_start timestamptz;
begin
  if p_ends_at < p_starts_at then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  select * into v_series from public.events e
  where e.id = p_series_id and e.rrule is not null and e.series_id is null;
  if not found then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;

  -- Écart en jours entre l'occurrence et sa nouvelle place, chaque date lue
  -- dans le repère de son propre mode (fuseau de la série, ou UTC).
  v_shift := private.calendar_day(p_starts_at, p_all_day, v_series.timezone)
           - private.calendar_day(p_occurrence_start, v_series.all_day, v_series.timezone);
  v_master_day := private.calendar_day(v_series.starts_at, v_series.all_day, v_series.timezone)
                + v_shift;
  v_start := case
    when p_all_day then v_master_day::timestamp at time zone 'UTC'
    else (v_master_day + (p_starts_at at time zone v_series.timezone)::time)
           at time zone v_series.timezone
  end;
  if p_follow_weekdays and v_shift <> 0 then
    p_rrule := private.shift_weekdays(p_rrule, v_shift);
  end if;

  update public.events e set
    calendar_id = p_calendar_id,
    title = btrim(p_title),
    location = nullif(btrim(p_location), ''),
    description = nullif(btrim(p_description), ''),
    starts_at = v_start,
    ends_at = v_start + (p_ends_at - p_starts_at),
    all_day = p_all_day,
    rrule = p_rrule,
    visibility = p_visibility
  where e.id = p_series_id;
  if not found then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- Décale de p_days les jours d'un BYDAY simple (« TU,TH ») et les trie du
-- lundi au dimanche, comme l'app les écrit. Une règle sans BYDAY, ou dont un
-- jour porte un rang (« 2TU »), revient telle quelle.
create function private.shift_weekdays(p_rrule text, p_days integer)
returns text language plpgsql immutable set search_path = '' as $$
declare
  v_week constant text[] := array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  v_days text;
  v_shifted text;
begin
  v_days := substring(p_rrule from '(?:^|;)BYDAY=([A-Z,]+)(?:;|$)');
  if v_days is null
     or exists (select 1 from unnest(string_to_array(v_days, ',')) d where not d = any (v_week)) then
    return p_rrule;
  end if;
  select string_agg(v_week[idx + 1], ',' order by idx) into v_shifted
  from (
    select distinct ((array_position(v_week, d) - 1 + p_days) % 7 + 7) % 7 as idx
    from unnest(string_to_array(v_days, ',')) d
  ) shifted;
  return regexp_replace(p_rrule, '((?:^|;)BYDAY=)[A-Z,]+', '\1' || v_shifted);
end;
$$;

-- Date de calendrier d'un instant : dans le fuseau donné, ou en UTC pour
-- une journée entière (stockée de minuit UTC à minuit UTC).
create function private.calendar_day(p_at timestamptz, p_all_day boolean, p_timezone text)
returns date language sql stable set search_path = '' as $$
  select case when p_all_day then (p_at at time zone 'UTC')::date
              else (p_at at time zone p_timezone)::date end;
$$;

-- -----------------------------------------------------------------------------
-- my_agenda : une occurrence modifiée porte la règle de SA SÉRIE. Sa propre
-- ligne n'a pas de rrule ; l'app, qui bâtit ses brouillons depuis ce que
-- renvoie my_agenda, transformait sinon toute la série en rdv unique en la
-- modifiant (ou la déplaçant) depuis une occurrence déjà modifiée.
-- -----------------------------------------------------------------------------

create or replace function public.my_agenda(p_from timestamptz, p_to timestamptz)
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
  visibility public.visibility
)
language plpgsql stable security invoker set search_path = '' as $$
begin
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select e.id, e.series_id, e.recurrence_id, e.calendar_id, e.title, e.location,
           e.description, e.starts_at, e.ends_at, e.all_day, e.timezone,
           coalesce(e.rrule, m.rrule), e.visibility
    from public.events e
    left join public.events m on m.id = e.series_id
    where e.rrule is null
      and e.starts_at < p_to and (e.ends_at > p_from or e.starts_at >= p_from)
    union all
    select e.id, e.id, o.starts_at, e.calendar_id, e.title, e.location,
           e.description, o.starts_at, o.ends_at, e.all_day, e.timezone, e.rrule, e.visibility
    from public.event_occurrences o
    join public.events e on e.id = o.event_id
    where o.starts_at < p_to and (o.ends_at > p_from or o.starts_at >= p_from)
    order by 8;
end;
$$;

revoke execute on function public.update_series(
  uuid, timestamptz, uuid, text, text, text, timestamptz, timestamptz, boolean, text,
  public.visibility, boolean
) from public, anon;
grant execute on function public.update_series(
  uuid, timestamptz, uuid, text, text, text, timestamptz, timestamptz, boolean, text,
  public.visibility, boolean
) to authenticated;
revoke execute on function private.shift_weekdays(text, integer) from public, anon;
grant execute on function private.shift_weekdays(text, integer) to authenticated;
-- update_series est SECURITY INVOKER : l'appelant doit pouvoir l'exécuter.
revoke execute on function private.calendar_day(timestamptz, boolean, text) from public, anon;
grant execute on function private.calendar_day(timestamptz, boolean, text) to authenticated;
