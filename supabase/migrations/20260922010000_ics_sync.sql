-- =============================================================================
-- Import iCal : contrat entre la base et le worker qui relit les flux.
--
-- Le worker n'a AUCUN droit d'écriture direct sur les agendas : il passe
-- par quatre fonctions SECURITY DEFINER (schéma private) —
--   ics_due_feeds      prend les flux à relire (avec un bail) et leur URL ;
--   ics_apply          applique un flux lu, en une transaction ;
--   ics_record_unchanged note un flux inchangé (304) ;
--   ics_record_failure note un échec, par un CODE connu (jamais le texte
--                      d'une erreur réseau, qui peut contenir l'URL ou une
--                      adresse interne), et repousse la relecture.
--
-- Choix non évidents :
--   - relecture toutes les 30 minutes ; après un échec, 5 min × 2^(n-1),
--     24 h au plus ; un bail de 10 minutes empêche deux instances du worker
--     de relire le même flux ;
--   - ics_apply n'écrit JAMAIS events.visibility (un rdv importé masqué le
--     reste) et ne réécrit pas un rdv inchangé ;
--   - reset_series_exceptions vide les exceptions d'une série dont l'horaire
--     change ; pour un flux, ses EXDATE font foi : elles sont reposées par
--     une seconde mise à jour, qui ne touche pas l'horaire ;
--   - une occurrence modifiée (RECURRENCE-ID) est rattachée à sa série du
--     même flux ; sans série connue, elle est ignorée ;
--   - un nouveau flux, ou « Synchroniser maintenant », réveille le worker
--     (NOTIFY agora_ics, avec l'id de l'agenda : jamais l'URL) ;
--   - calendars est publiée en temps réel (sous RLS, comme events) : l'app
--     voit l'état de synchro (last_synced_at, sync_error) changer sans
--     relire la liste. La table des flux, elle, n'est jamais publiée.
--
-- Invariants : l'URL d'un flux ne sort que vers le worker ; un rdv importé
-- ne s'écrit que par ics_apply.
-- =============================================================================

-- Une exception d'un agenda iCal ne vient que du serveur (aucun utilisateur
-- n'écrit dans un tel agenda : private.can_add_event exige un agenda natif).
-- Le contrôle « l'appelant peut modifier la série » ne s'y applique donc pas
-- — il échouerait toujours, l'agenda n'étant modifiable par personne.
create or replace function private.check_event_series()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.series_id is not null and not exists (
    select 1 from public.events m
    join public.calendars c on c.id = m.calendar_id
    where m.id = new.series_id and m.rrule is not null
      and m.series_id is null and m.calendar_id = new.calendar_id
      and (auth.uid() is null or c.kind = 'ics'
           or private.can_edit_event(m.calendar_id, m.created_by))
  ) then
    raise exception 'invalid_series' using errcode = '22023';
  end if;
  return new;
end;
$$;

alter table private.calendar_feeds
  add column next_sync_at timestamptz not null default now(),
  add column last_attempt_at timestamptz;

create index calendar_feeds_next_sync_at_idx on private.calendar_feeds (next_sync_at);

-- Réveille le worker à l'arrivée d'un flux.
create function private.notify_new_feed()
returns trigger language plpgsql set search_path = '' as $$
begin
  perform pg_notify('agora_ics', new.calendar_id::text);
  return null;
end;
$$;

create trigger calendar_feeds_notify
  after insert on private.calendar_feeds
  for each row execute function private.notify_new_feed();

-- Flux à relire, pris pour 10 minutes.
create function private.ics_due_feeds(p_limit integer)
returns table (calendar_id uuid, url text, etag text, last_modified text)
language sql volatile security definer set search_path = '' as $$
  update private.calendar_feeds f
  set next_sync_at = now() + interval '10 minutes',
      last_attempt_at = now()
  where f.calendar_id in (
    select d.calendar_id from private.calendar_feeds d
    where d.next_sync_at <= now()
    order by d.next_sync_at
    limit greatest(p_limit, 0)
    for update skip locked
  )
  returning f.calendar_id, f.url, f.etag, f.last_modified;
$$;

-- Lignes d'un flux lu : [{uid, recurrence_id, title, description, location,
-- starts_at, ends_at, all_day, timezone, rrule, exdates}], déjà normalisé et
-- tronqué par le worker. Une fonction plutôt qu'une table temporaire : rien
-- ne survit à l'appel, rien ne se heurte d'un appel à l'autre.
create function private.ics_rows(p_events jsonb)
returns table (uid text, recurrence_id timestamptz, title text, description text,
  location text, starts_at timestamptz, ends_at timestamptz, all_day boolean,
  timezone text, rrule text, exdates timestamptz[])
language sql immutable set search_path = '' as $$
  select x.uid, x.recurrence_id, x.title, x.description, x.location, x.starts_at,
         x.ends_at, coalesce(x.all_day, false), coalesce(x.timezone, 'UTC'),
         x.rrule, coalesce(x.exdates, '{}')
  from jsonb_to_recordset(p_events) as x(
    uid text, recurrence_id timestamptz, title text, description text, location text,
    starts_at timestamptz, ends_at timestamptz, all_day boolean, timezone text,
    rrule text, exdates timestamptz[]
  );
$$;

-- Applique un flux lu (voir private.ics_rows).
create function private.ics_apply(
  p_calendar_id uuid,
  p_events jsonb,
  p_etag text,
  p_last_modified text
)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.calendars c where c.id = p_calendar_id and c.kind = 'ics'
  ) then
    raise exception 'calendar_not_found' using errcode = 'P0002';
  end if;

  -- 1. Rdv ponctuels et lignes maîtresses des séries.
  insert into public.events as e (calendar_id, source_uid, recurrence_id, title, description,
    location, starts_at, ends_at, all_day, timezone, rrule, exdates)
  select p_calendar_id, i.uid, null, i.title, i.description, i.location, i.starts_at,
         i.ends_at, i.all_day, i.timezone, i.rrule, i.exdates
  from private.ics_rows(p_events) i
  where i.recurrence_id is null
  on conflict (calendar_id, source_uid, recurrence_id) where source_uid is not null
  do update set title = excluded.title, description = excluded.description,
    location = excluded.location, starts_at = excluded.starts_at, ends_at = excluded.ends_at,
    all_day = excluded.all_day, timezone = excluded.timezone, rrule = excluded.rrule,
    exdates = excluded.exdates
  where (e.title, e.description, e.location, e.starts_at, e.ends_at, e.all_day, e.timezone,
         e.rrule, e.exdates)
    is distinct from (excluded.title, excluded.description, excluded.location,
         excluded.starts_at, excluded.ends_at, excluded.all_day, excluded.timezone,
         excluded.rrule, excluded.exdates);

  -- 2. Les EXDATE du flux font foi, même si l'horaire vient de changer.
  update public.events e set exdates = i.exdates
  from private.ics_rows(p_events) i
  where e.calendar_id = p_calendar_id and e.source_uid = i.uid
    and e.recurrence_id is null and i.recurrence_id is null
    and e.exdates is distinct from i.exdates;

  -- 3. Occurrences modifiées, rattachées à leur série du même flux.
  insert into public.events as e (calendar_id, source_uid, series_id, recurrence_id, title,
    description, location, starts_at, ends_at, all_day, timezone)
  select p_calendar_id, i.uid, m.id, i.recurrence_id, i.title, i.description, i.location,
         i.starts_at, i.ends_at, i.all_day, m.timezone
  from private.ics_rows(p_events) i
  join public.events m on m.calendar_id = p_calendar_id and m.source_uid = i.uid
    and m.recurrence_id is null and m.rrule is not null
  where i.recurrence_id is not null
  on conflict (calendar_id, source_uid, recurrence_id) where source_uid is not null
  do update set title = excluded.title, description = excluded.description,
    location = excluded.location, starts_at = excluded.starts_at, ends_at = excluded.ends_at,
    all_day = excluded.all_day
  where (e.title, e.description, e.location, e.starts_at, e.ends_at, e.all_day)
    is distinct from (excluded.title, excluded.description, excluded.location,
         excluded.starts_at, excluded.ends_at, excluded.all_day);

  -- 4. Ce qui a quitté le flux quitte l'agenda.
  delete from public.events e
  where e.calendar_id = p_calendar_id
    and not exists (
      select 1 from private.ics_rows(p_events) i
      where i.uid = e.source_uid and i.recurrence_id is not distinct from e.recurrence_id
    );

  update public.calendars c set last_synced_at = now(), sync_error = null
  where c.id = p_calendar_id;
  update private.calendar_feeds f
  set etag = p_etag, last_modified = p_last_modified, failure_count = 0,
      next_sync_at = now() + interval '30 minutes'
  where f.calendar_id = p_calendar_id;
end;
$$;

-- Flux inchangé depuis la dernière lecture (304).
create function private.ics_record_unchanged(p_calendar_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  update public.calendars c set last_synced_at = now(), sync_error = null
  where c.id = p_calendar_id;
  update private.calendar_feeds f
  set failure_count = 0, next_sync_at = now() + interval '30 minutes'
  where f.calendar_id = p_calendar_id;
end;
$$;

-- Échec d'une relecture : un code connu, affiché dans l'app, et un délai
-- qui s'allonge.
create function private.ics_record_failure(p_calendar_id uuid, p_error text)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_error not in ('unreachable', 'timeout', 'not_found', 'forbidden', 'http_error',
                     'too_large', 'not_calendar', 'blocked_address', 'too_many_events') then
    raise exception 'invalid_sync_error' using errcode = '22023';
  end if;
  update public.calendars c set sync_error = p_error where c.id = p_calendar_id;
  update private.calendar_feeds f
  set failure_count = f.failure_count + 1,
      next_sync_at = now() + least(
        interval '5 minutes' * power(2, least(f.failure_count, 10)),
        interval '24 hours'
      )
  where f.calendar_id = p_calendar_id;
end;
$$;

-- « Synchroniser maintenant » : le propriétaire rend son flux dû tout de
-- suite. Sans effet si une relecture a été tentée dans la dernière minute.
create function public.sync_calendar_now(p_calendar_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_last timestamptz;
begin
  select f.last_attempt_at into v_last
  from private.calendar_feeds f
  join public.calendars c on c.id = f.calendar_id
  where f.calendar_id = p_calendar_id and c.owner_id = auth.uid();
  if not found then
    raise exception 'calendar_not_found' using errcode = 'P0002';
  end if;
  if v_last is not null and v_last > now() - interval '1 minute' then
    return;
  end if;
  update private.calendar_feeds f set next_sync_at = now() where f.calendar_id = p_calendar_id;
  perform pg_notify('agora_ics', p_calendar_id::text);
end;
$$;

revoke execute on function private.notify_new_feed(), private.ics_rows(jsonb),
  private.ics_due_feeds(integer),
  private.ics_apply(uuid, jsonb, text, text),
  private.ics_record_unchanged(uuid),
  private.ics_record_failure(uuid, text),
  public.sync_calendar_now(uuid)
  from public, anon, authenticated;
grant execute on function public.sync_calendar_now(uuid) to authenticated;

alter publication supabase_realtime add table public.calendars;

-- Le worker n'atteint le schéma private que par ces quatre fonctions.
grant usage on schema private to agora_worker;
grant execute on function private.ics_due_feeds(integer),
  private.ics_apply(uuid, jsonb, text, text),
  private.ics_record_unchanged(uuid),
  private.ics_record_failure(uuid, text)
  to agora_worker;
