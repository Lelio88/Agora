-- =============================================================================
-- replace_occurrence : modifier une seule occurrence d'une série, en une
-- transaction.
--
-- Pourquoi une RPC : l'app faisait un upsert sur (series_id, recurrence_id),
-- mais cette clé est un index unique PARTIEL (where series_id is not null),
-- que Postgres refuse comme cible d'ON CONFLICT (42P10). Ici : suppression
-- d'un remplaçant précédent du même créneau, puis insertion du nouveau. Les
-- triggers de cohérence des séries s'appliquent à l'insertion.
--
-- Invariants : seul qui peut modifier la série (private.can_edit_event) peut
-- en remplacer une occurrence ; le verrou de la série est pris avant toute
-- lecture, pour que le worker ne ressuscite pas l'occurrence remplacée.
-- =============================================================================

create function public.replace_occurrence(
  p_series_id uuid,
  p_original_start timestamptz,
  p_title text,
  p_location text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_all_day boolean,
  p_visibility public.visibility
)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_series public.events;
  v_id uuid;
begin
  -- Avant toute lecture : le worker ne doit pas redéplier la série entre
  -- ce remplacement et sa validation (private.lock_series).
  perform private.lock_series(p_series_id);
  select * into v_series from public.events e
  where e.id = p_series_id and e.rrule is not null and e.series_id is null;
  if not found or not private.can_edit_event(v_series.calendar_id, v_series.created_by) then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  delete from public.events e
  where e.series_id = p_series_id and e.recurrence_id = p_original_start;
  insert into public.events (
    series_id, recurrence_id, calendar_id, title, location, description,
    starts_at, ends_at, all_day, timezone, visibility, created_by
  ) values (
    p_series_id, p_original_start, v_series.calendar_id, btrim(p_title),
    nullif(btrim(p_location), ''), nullif(btrim(p_description), ''),
    p_starts_at, p_ends_at, p_all_day, v_series.timezone, p_visibility, auth.uid()
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.replace_occurrence(
  uuid, timestamptz, text, text, text, timestamptz, timestamptz, boolean, public.visibility
) from public, anon;
grant execute on function public.replace_occurrence(
  uuid, timestamptz, text, text, text, timestamptz, timestamptz, boolean, public.visibility
) to authenticated;
