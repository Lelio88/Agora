-- =============================================================================
-- Bot Discord : un salon relié à un groupe, et le contrat du worker.
--
-- Un admin du groupe crée dans l'app un code de liaison (10 minutes, usage
-- unique) ; quelqu'un qui peut gérer le salon tape /relier <code> ; le
-- worker appelle private.discord_link_channel. Un salon sert un seul groupe,
-- un groupe publie dans un seul salon.
--
-- Le compte Discord d'une personne se lit dans auth.identities (fournisseur
-- « discord », relié par linkIdentity dans l'app) : aucune table en double.
--
-- Le worker n'a aucun droit direct sur ces tables : il passe par les
-- fonctions private.discord_*, SECURITY DEFINER, accordées au seul rôle
-- agora_worker.
--
-- Choix non évidents :
--   - /agenda et /dispo répondent au seul demandeur : le worker lit l'agenda
--     du groupe EN SON NOM (resolve_group_agenda, lecteur = lui, plafond
--     'details'), exactement ce que l'app lui montrerait, et seulement s'il
--     est membre ;
--   - le récap public, lui, n'a pas de lecteur : plafond 'busy' pour les
--     rdv personnels, les rdv du groupe restent en détail (§3 de
--     docs/architecture.md) ;
--   - les rappels ne portent que sur les rdv du groupe, jamais sur un rdv
--     personnel ; un journal (discord_reminders_sent) empêche tout doublon ;
--   - un récap ou un rappel est « réclamé » (marqué envoyé) avant l'envoi :
--     une panne de Discord en perd un plutôt que d'en publier deux ;
--   - un récap en retard de plus de six heures n'est plus envoyé : le
--     worker redémarré ou un réglage changé le soir ne publie pas celui du
--     matin ;
--   - le fuseau et la langue des publications sont ceux de la personne qui
--     a relié le salon, figés à la liaison.
--
-- Invariant : resolve_group_agenda reste le seul chemin par lequel un rdv
-- personnel atteint quelqu'un d'autre que son propriétaire.
-- =============================================================================

create type public.discord_recap as enum ('off', 'daily', 'weekly');

create table public.discord_channels (
  group_id uuid primary key references public.groups (id) on delete cascade,
  guild_id text not null check (guild_id ~ '^[0-9]{1,20}$'),
  channel_id text not null unique check (channel_id ~ '^[0-9]{1,20}$'),
  -- Nom du salon à la liaison, pour l'afficher dans l'app (Discord ne le
  -- renvoie qu'avec l'interaction ; un renommage ultérieur n'est pas suivi).
  channel_name text not null default '' check (char_length(channel_name) <= 100),
  linked_by uuid references public.profiles (id) on delete set null,
  linked_at timestamptz not null default now(),
  timezone text not null default 'Europe/Paris'
    check (timezone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+){0,2}$'),
  locale text not null default 'fr' check (locale in ('fr', 'en')),
  recap public.discord_recap not null default 'weekly',
  -- 1 = lundi … 7 = dimanche (ISO), pour un récap hebdomadaire.
  recap_weekday smallint not null default 1 check (recap_weekday between 1 and 7),
  recap_hour smallint not null default 8 check (recap_hour between 0 and 23),
  last_recap_at timestamptz,
  -- null : pas de rappel.
  reminder_minutes integer check (reminder_minutes in (15, 60, 1440))
);

create table private.discord_link_codes (
  code text primary key,
  group_id uuid not null references public.groups (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '10 minutes'
);
create index discord_link_codes_group_id_idx on private.discord_link_codes (group_id);

create table private.discord_reminders_sent (
  event_id uuid not null references public.events (id) on delete cascade,
  starts_at timestamptz not null,
  primary key (event_id, starts_at)
);

-- -----------------------------------------------------------------------------
-- Côté app : voir le salon relié, le régler, le délier
-- -----------------------------------------------------------------------------

alter table public.discord_channels enable row level security;

create policy "discord_channels: lisibles des membres" on public.discord_channels
  for select to authenticated using (private.is_group_member(group_id));
create policy "discord_channels: réglés par les admins" on public.discord_channels
  for update to authenticated
  using (private.is_group_admin(group_id))
  with check (private.is_group_admin(group_id));
create policy "discord_channels: déliés par les admins" on public.discord_channels
  for delete to authenticated using (private.is_group_admin(group_id));

revoke all on public.discord_channels from anon, authenticated;
grant select, delete on public.discord_channels to authenticated;
grant update (recap, recap_weekday, recap_hour, reminder_minutes)
  on public.discord_channels to authenticated;

-- Crée le code que l'on tapera dans le salon. Un nouveau code remplace les
-- précédents du groupe : un seul est valable à la fois.
create function public.create_discord_link_code(p_group_id uuid)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_code text;
begin
  if not private.is_group_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = '42501';
  end if;
  delete from private.discord_link_codes c where c.group_id = p_group_id;
  insert into private.discord_link_codes (code, group_id, created_by)
  values (private.random_invite_code(), p_group_id, auth.uid())
  returning code into v_code;
  return v_code;
end;
$$;

-- -----------------------------------------------------------------------------
-- Côté worker
-- -----------------------------------------------------------------------------

-- Le compte Agora relié à un identifiant Discord, avec de quoi lui répondre
-- dans sa langue et à son heure. Aucune ligne : compte non relié.
create function private.discord_user(p_discord_id text)
returns table (user_id uuid, timezone text, locale text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.timezone, p.locale
  from auth.identities i
  join public.profiles p on p.id = i.user_id
  where i.provider = 'discord' and i.provider_id = p_discord_id;
$$;

-- /relier : relie le salon au groupe du code. Celui qui tape la commande
-- doit avoir relié son compte et être admin du groupe : un code qui fuit ne
-- suffit pas.
create function private.discord_link_channel(
  p_code text,
  p_guild_id text,
  p_channel_id text,
  p_channel_name text,
  p_discord_id text
)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_user uuid;
  v_code private.discord_link_codes;
  v_profile public.profiles;
  v_name text;
begin
  select u.user_id into v_user from private.discord_user(p_discord_id) u;
  if v_user is null then
    raise exception 'discord_not_linked' using errcode = '42501';
  end if;
  select * into v_code from private.discord_link_codes c
  where c.code = upper(btrim(p_code))
  for update;
  if not found or v_code.expires_at <= now() then
    raise exception 'link_code_invalid' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.group_members gm
    where gm.group_id = v_code.group_id and gm.user_id = v_user
      and gm.role in ('owner', 'admin')
  ) then
    raise exception 'not_group_admin' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.discord_channels dc
    where dc.channel_id = p_channel_id and dc.group_id <> v_code.group_id
  ) then
    raise exception 'channel_taken' using errcode = '23505';
  end if;
  select * into v_profile from public.profiles p where p.id = v_user;
  insert into public.discord_channels
    (group_id, guild_id, channel_id, channel_name, linked_by, timezone, locale)
  values (v_code.group_id, p_guild_id, p_channel_id, left(coalesce(p_channel_name, ''), 100),
          v_user, v_profile.timezone, v_profile.locale)
  on conflict (group_id) do update set
    guild_id = excluded.guild_id,
    channel_id = excluded.channel_id,
    channel_name = excluded.channel_name,
    linked_by = excluded.linked_by,
    linked_at = now(),
    timezone = excluded.timezone,
    locale = excluded.locale,
    last_recap_at = null;
  delete from private.discord_link_codes c where c.code = v_code.code;
  select g.name into v_name from public.groups g where g.id = v_code.group_id;
  return v_name;
end;
$$;

-- /delier : mêmes exigences que /relier. Discord ne la propose qu'à qui
-- peut gérer le salon (le worker le revérifie), et la base exige en plus un
-- compte relié d'admin du groupe : un modérateur du serveur étranger au
-- groupe ne coupe pas ses publications (il peut retirer le bot du serveur).
-- Rend le nom du groupe délié, ou null si le salon n'était pas relié.
create function private.discord_unlink_channel(p_channel_id text, p_discord_id text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_user uuid;
  v_group uuid;
  v_name text;
begin
  select dc.group_id into v_group from public.discord_channels dc
  where dc.channel_id = p_channel_id
  for update;
  if not found then
    return null;
  end if;
  select u.user_id into v_user from private.discord_user(p_discord_id) u;
  if v_user is null then
    raise exception 'discord_not_linked' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.group_members gm
    where gm.group_id = v_group and gm.user_id = v_user
      and gm.role in ('owner', 'admin')
  ) then
    raise exception 'not_group_admin' using errcode = '42501';
  end if;
  delete from public.discord_channels dc where dc.group_id = v_group;
  select g.name into v_name from public.groups g where g.id = v_group;
  return v_name;
end;
$$;

-- Le groupe relié à un salon. Aucune ligne : salon non relié.
create function private.discord_channel_group(p_channel_id text)
returns table (group_id uuid, name text)
language sql stable security definer set search_path = '' as $$
  select g.id, g.name
  from public.discord_channels dc
  join public.groups g on g.id = dc.group_id
  where dc.channel_id = p_channel_id;
$$;

-- /agenda et /dispo dans un salon relié : l'agenda du groupe vu par le
-- demandeur, comme dans l'app. Il doit être membre.
create function private.discord_group_agenda(
  p_group_id uuid,
  p_user_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  user_id uuid,
  display_name text,
  is_group_event boolean,
  level public.visibility,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = p_user_id
  ) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select a.user_id, p.display_name, a.is_group_event, a.level, a.title,
           a.location, a.starts_at, a.ends_at, a.all_day
    from private.resolve_group_agenda(p_group_id, p_user_id, p_from, p_to, 'details') a
    left join public.profiles p on p.id = a.user_id;
end;
$$;

-- Les membres d'un groupe, pour /dispo. Le demandeur doit en être.
create function private.discord_group_members(p_group_id uuid, p_user_id uuid)
returns table (user_id uuid, display_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = p_user_id
  ) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  return query
    select gm.user_id, p.display_name
    from public.group_members gm
    join public.profiles p on p.id = gm.user_id
    where gm.group_id = p_group_id
    order by p.display_name;
end;
$$;

-- /agenda hors d'un salon relié : l'agenda de la personne elle-même, ce que
-- my_agenda lui rendrait (ses agendas et ceux de ses groupes), moins les
-- agendas qu'elle a masqués.
create function private.discord_personal_agenda(
  p_user_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  title text,
  location text,
  group_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    with readable as (
      select c.id, g.name as group_name
      from public.calendars c
      left join public.groups g on g.id = c.group_id
      where (c.owner_id = p_user_id
             or exists (select 1 from public.group_members gm
                        where gm.group_id = c.group_id and gm.user_id = p_user_id))
        and not exists (select 1 from public.calendar_preferences cp
                        where cp.calendar_id = c.id and cp.user_id = p_user_id
                          and cp.hidden)
    ),
    instances as (
      select e.title, e.location, r.group_name, e.starts_at, e.ends_at, e.all_day
      from readable r
      join public.events e on e.calendar_id = r.id
      where e.rrule is null
      union all
      select e.title, e.location, r.group_name, o.starts_at, o.ends_at, e.all_day
      from readable r
      join public.events e on e.calendar_id = r.id
      join public.event_occurrences o on o.event_id = e.id
      where e.rrule is not null
    )
    select i.title, i.location, i.group_name, i.starts_at, i.ends_at, i.all_day
    from instances i
    where i.starts_at < p_to and (i.ends_at > p_from or i.starts_at >= p_from)
    order by i.starts_at;
end;
$$;

-- Réclame les récaps dus : les marque envoyés et les rend. Dû = le jour (et
-- pour un hebdomadaire, le jour de la semaine) est venu, l'heure est passée
-- depuis moins de six heures, et ce créneau n'a pas déjà été publié.
create function private.discord_claim_recaps()
returns table (
  group_id uuid,
  group_name text,
  channel_id text,
  timezone text,
  locale text,
  recap public.discord_recap,
  slot timestamptz
)
language plpgsql volatile security definer set search_path = '' as $$
begin
  return query
    with slots as (
      select dc.group_id,
             (date_trunc('day', now() at time zone dc.timezone)
                + make_interval(hours => dc.recap_hour)) at time zone dc.timezone as slot
      from public.discord_channels dc
      where dc.recap <> 'off'
        and (dc.recap = 'daily'
             or extract(isodow from now() at time zone dc.timezone) = dc.recap_weekday)
    ),
    claimed as (
      update public.discord_channels dc
      set last_recap_at = s.slot
      from slots s
      where dc.group_id = s.group_id
        and now() >= s.slot and now() < s.slot + interval '6 hours'
        and (dc.last_recap_at is null or dc.last_recap_at < s.slot)
      returning dc.group_id, dc.channel_id, dc.timezone, dc.locale, dc.recap, s.slot
    )
    select c.group_id, g.name, c.channel_id, c.timezone, c.locale, c.recap, c.slot
    from claimed c
    join public.groups g on g.id = c.group_id;
end;
$$;

-- Ce qu'un récap public publie : pas de lecteur, rdv personnels plafonnés à
-- « occupé ». Au plus huit jours.
create function private.discord_recap_agenda(
  p_group_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  user_id uuid,
  display_name text,
  is_group_event boolean,
  level public.visibility,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_to <= p_from or p_to - p_from > interval '8 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select a.user_id, p.display_name, a.is_group_event, a.level, a.title,
           a.location, a.starts_at, a.ends_at, a.all_day
    from private.resolve_group_agenda(p_group_id, null, p_from, p_to, 'busy') a
    left join public.profiles p on p.id = a.user_id;
end;
$$;

-- Réclame les rappels dus : les rdv DU GROUPE (jamais un rdv personnel) qui
-- commencent dans le délai choisi et n'ont pas encore été rappelés. Une
-- journée entière n'a pas d'heure à rappeler.
create function private.discord_claim_reminders()
returns table (
  channel_id text,
  timezone text,
  locale text,
  group_name text,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql volatile security definer set search_path = '' as $$
begin
  delete from private.discord_reminders_sent s where s.starts_at < now() - interval '2 days';
  return query
    with instances as (
      select dc.group_id, e.id as event_id, e.title, e.location,
             e.starts_at, e.ends_at, dc.reminder_minutes
      from public.discord_channels dc
      join public.calendars c on c.group_id = dc.group_id
      join public.events e on e.calendar_id = c.id
      where dc.reminder_minutes is not null and e.rrule is null and not e.all_day
      union all
      select dc.group_id, e.id, e.title, e.location,
             o.starts_at, o.ends_at, dc.reminder_minutes
      from public.discord_channels dc
      join public.calendars c on c.group_id = dc.group_id
      join public.events e on e.calendar_id = c.id
      join public.event_occurrences o on o.event_id = e.id
      where dc.reminder_minutes is not null and e.rrule is not null and not e.all_day
    ),
    due as (
      select * from instances i
      where i.starts_at > now()
        and i.starts_at <= now() + make_interval(mins => i.reminder_minutes)
    ),
    claimed as (
      insert into private.discord_reminders_sent as rs (event_id, starts_at)
      select d.event_id, d.starts_at from due d
      on conflict do nothing
      returning rs.event_id, rs.starts_at
    )
    select dc.channel_id, dc.timezone, dc.locale, g.name, d.title, d.location,
           d.starts_at, d.ends_at
    from due d
    join claimed cl on cl.event_id = d.event_id and cl.starts_at = d.starts_at
    join public.discord_channels dc on dc.group_id = d.group_id
    join public.groups g on g.id = d.group_id
    order by d.starts_at;
end;
$$;

-- -----------------------------------------------------------------------------
-- Droits
-- -----------------------------------------------------------------------------

revoke execute on function public.create_discord_link_code(uuid),
  private.discord_user(text),
  private.discord_link_channel(text, text, text, text, text),
  private.discord_unlink_channel(text, text),
  private.discord_channel_group(text),
  private.discord_group_agenda(uuid, uuid, timestamptz, timestamptz),
  private.discord_group_members(uuid, uuid),
  private.discord_personal_agenda(uuid, timestamptz, timestamptz),
  private.discord_claim_recaps(),
  private.discord_recap_agenda(uuid, timestamptz, timestamptz),
  private.discord_claim_reminders()
  from public, anon, authenticated;

grant execute on function public.create_discord_link_code(uuid) to authenticated;

grant execute on function private.discord_user(text),
  private.discord_link_channel(text, text, text, text, text),
  private.discord_unlink_channel(text, text),
  private.discord_channel_group(text),
  private.discord_group_agenda(uuid, uuid, timestamptz, timestamptz),
  private.discord_group_members(uuid, uuid),
  private.discord_personal_agenda(uuid, timestamptz, timestamptz),
  private.discord_claim_recaps(),
  private.discord_recap_agenda(uuid, timestamptz, timestamptz),
  private.discord_claim_reminders()
  to agora_worker;
