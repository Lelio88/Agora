-- =============================================================================
-- Rdv semblables : recopier une modification sur les rdv ponctuels qui
-- reviennent sans être une série (un emploi du temps saisi séance par séance,
-- chacune avec son sujet).
--
-- Un rdv est SEMBLABLE au rdv ouvert s'il est ponctuel comme lui, dans le
-- même agenda, de même titre, de même nature (journée entière ou non), au
-- même jour de la semaine et à la même heure locale (dans le fuseau du rdv
-- ouvert, en UTC pour une journée entière : 8 h reste 8 h de part et d'autre
-- du changement d'heure), et commence à partir de lui.
--
-- Choix non évidents :
--   - c'est l'app qui dit QUELS champs recopier (p_fields) : ceux que
--     l'utilisateur a changés, qu'elle lui montre sous la case. La base ne
--     recopie que ceux-là, jamais la date ni l'heure : chaque séance garde son
--     horaire, et sa description si elle n'est pas nommée ;
--   - les semblables se cherchent sur le rdv ouvert TEL QU'IL EST ENREGISTRÉ :
--     l'app appelle update_similar_events AVANT d'enregistrer le rdv lui-même
--     (renommé d'abord, il n'aurait plus de semblables). Si ce second
--     enregistrement échoue, les semblables sont déjà à jour ; le refaire
--     converge ;
--   - seulement dans un agenda natif dont on est propriétaire : dans un
--     agenda de groupe, les semblables seraient aussi les rdv des autres
--     membres, que leurs rappels Discord annoncent.
--
-- Invariants (supabase/tests/similar_events_test.sql) : SECURITY INVOKER, la
-- RLS et les droits par colonne décident de ce qu'on lit et modifie ; un rdv
-- ouvert illisible, ou qui n'est pas ponctuel, répond event_not_found ; un
-- champ hors de la liste répond invalid_fields.
--
-- Exemple :
--   select public.count_similar_events('…');                      -- 11
--   select public.update_similar_events('…', array['location'],
--     '<agenda>', 'NF19 — TD', '12 rue Marie Curie, 10300 Troyes', null, null);
-- =============================================================================

create function private.similar_event_ids(p_event_id uuid)
returns setof uuid language sql stable security invoker set search_path = '' as $$
  select e.id
  from public.events ref
  join public.calendars c on c.id = ref.calendar_id
  cross join lateral (
    select case when ref.all_day then 'UTC' else ref.timezone end as tz
  ) z
  join public.events e on e.calendar_id = ref.calendar_id
  where ref.id = p_event_id
    and c.kind = 'native' and c.owner_id = (select auth.uid())
    and ref.rrule is null and ref.series_id is null
    and e.id <> ref.id
    and e.rrule is null and e.series_id is null
    and e.title = ref.title
    and e.all_day = ref.all_day
    and e.starts_at >= ref.starts_at
    and extract(isodow from e.starts_at at time zone z.tz)
      = extract(isodow from ref.starts_at at time zone z.tz)
    and (e.starts_at at time zone z.tz)::time = (ref.starts_at at time zone z.tz)::time;
$$;

-- Nombre de semblables du rdv ouvert : l'app ne montre la case qu'au-dessus
-- de zéro, et en dit le nombre.
create function public.count_similar_events(p_event_id uuid)
returns integer language sql stable security invoker set search_path = '' as $$
  select count(*)::integer from private.similar_event_ids(p_event_id);
$$;

-- Recopie sur les semblables du rdv p_event_id les seuls champs nommés dans
-- p_fields ('calendar', 'title', 'location', 'description', 'visibility'),
-- avec les valeurs passées ; renvoie le nombre de rdv modifiés.
create function public.update_similar_events(
  p_event_id uuid,
  p_fields text[],
  p_calendar_id uuid,
  p_title text,
  p_location text,
  p_description text,
  p_visibility public.visibility
)
returns integer language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_count integer;
begin
  if p_fields is null
     or not p_fields <@ array['calendar', 'title', 'location', 'description', 'visibility'] then
    raise exception 'invalid_fields' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.events e
    where e.id = p_event_id and e.rrule is null and e.series_id is null
  ) then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  if cardinality(p_fields) = 0 then
    return 0;
  end if;

  update public.events e set
    calendar_id = case when 'calendar' = any (p_fields) then p_calendar_id else e.calendar_id end,
    title = case when 'title' = any (p_fields) then btrim(p_title) else e.title end,
    location = case when 'location' = any (p_fields)
                    then nullif(btrim(p_location), '') else e.location end,
    description = case when 'description' = any (p_fields)
                       then nullif(btrim(p_description), '') else e.description end,
    visibility = case when 'visibility' = any (p_fields) then p_visibility else e.visibility end
  where e.id in (select private.similar_event_ids(p_event_id));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.count_similar_events(uuid) from public, anon;
grant execute on function public.count_similar_events(uuid) to authenticated;
revoke execute on function public.update_similar_events(
  uuid, text[], uuid, text, text, text, public.visibility
) from public, anon;
grant execute on function public.update_similar_events(
  uuid, text[], uuid, text, text, text, public.visibility
) to authenticated;
-- Les deux RPC sont SECURITY INVOKER : l'appelant doit pouvoir l'exécuter.
revoke execute on function private.similar_event_ids(uuid) from public, anon;
grant execute on function private.similar_event_ids(uuid) to authenticated;
