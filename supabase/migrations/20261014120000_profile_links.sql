-- =============================================================================
-- Lien de profil : un membre partage un lien (ou son QR code) ; qui l'ouvre,
-- connecté, reçoit un proche garni d'une COPIE figée de ses rdv à venir.
--
-- Choix non évidents :
--   - la visibilité vit sur le PARTAGE, pas sur le calendrier : chaque lien a
--     son nom (« Pour Marie ») et son niveau (détails ou occupé), comme un
--     groupe a son `share_level`. Un lien « invisible » n'aurait pas de sens :
--     on le supprime. Le réglage des agendas et des rdv reste un plafond :
--     le plus restrictif des quatre (lien, agenda, rdv, rdv maître d'une
--     série) gagne, comme dans `private.resolve_group_agenda` ;
--   - c'est un SECOND chemin de sortie pour les rdv d'autrui. Il ne sert
--     qu'à `import_profile`, qui copie une fois puis ne relit rien en direct :
--     le propriétaire ne reprend rien après coup, mais ne livre jamais plus
--     que le niveau du lien à l'instant de la copie ;
--   - à « détails », le titre et le lieu passent, jamais la description
--     (comme l'agenda de groupe) ; à « occupé », le titre devient « Occupé »
--     et le lieu disparaît. Un rdv invisible ne sort pas, et une séance
--     invisible d'une série devient un trou (`exdates`), sinon elle
--     réapparaîtrait à l'horaire normal ;
--   - une série est copiée comme série : la ligne maîtresse, ses séances
--     modifiées, et le worker déplie. Les rdv copiés portent
--     `source_uid = 'profil:<id d'origine>'` : c'est ce qui permet de
--     rafraîchir la copie sans toucher aux rdv que le destinataire a ajoutés
--     lui-même à ce proche ;
--   - un second scan du même profil rend le même proche (index unique
--     `calendars_contact_user_once`) et refait la copie. Si ce proche est un
--     agenda iCal, la synchro l'écraserait : refus (`contact_not_native`) ;
--   - la révocation d'un lien ne reprend rien de ce qui a été copié, pas plus
--     que la suppression du compte du propriétaire : la copie est à son
--     destinataire, comme ce qu'il a noté lui-même ;
--   - un code inconnu ou supprimé n'est pas une exception mais un retour nul
--     (l'app en fait l'erreur) : une exception annulerait la transaction, et
--     avec elle la trace de l'échec qui sert à limiter le débit. Dix échecs en
--     une heure ferment ces fonctions à la personne (`rate_limited`) : sans
--     cela, un balayage des 32^8 codes depuis des comptes jetables serait
--     possible. Les réussites ne comptent pas ;
--   - le titre « Occupé » est écrit dans la langue de celui qui ouvre le lien
--     (`profiles.locale`) au moment de la copie ;
--   - 20 liens au plus par membre, pour borner la table ; une copie de plus de
--     2000 rdv est refusée (`profile_too_large`), pour borner le travail de
--     celui qui ouvre le lien.
--
-- Invariants (supabase/tests/profile_link_test.sql) : jamais plus que le niveau
-- du lien ni que la visibilité de l'agenda et du rdv ; pas de description ;
-- pas de rdv invisible, pas de proche de l'expéditeur ; le rafraîchissement
-- laisse les rdv propres du destinataire.
-- =============================================================================

create table public.profile_links (
  code text primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  label text not null check (char_length(label) between 1 and 60),
  share_level public.visibility not null check (share_level <> 'invisible'),
  created_at timestamptz not null default now()
);
create index profile_links_owner on public.profile_links (owner_id);

-- Fermée par défaut : on lit et on supprime ses liens ; on en crée par RPC.
revoke all on public.profile_links from anon, authenticated;
grant select, delete on public.profile_links to authenticated;
grant all on public.profile_links to service_role;
alter table public.profile_links enable row level security;
create policy "profile_links: propriétaire lit" on public.profile_links
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "profile_links: propriétaire révoque" on public.profile_links
  for delete to authenticated using (owner_id = (select auth.uid()));

-- Les échecs d'ouverture d'un lien, pour limiter le débit. Jamais lue par
-- l'app : RLS sans politique, comme toute table de `private`.
create table private.profile_link_attempts (
  user_id uuid not null references public.profiles (id) on delete cascade,
  failed_at timestamptz not null default now()
);
create index profile_link_attempts_user on private.profile_link_attempts (user_id, failed_at);
alter table private.profile_link_attempts enable row level security;
revoke all on private.profile_link_attempts from public, anon, authenticated;
grant all on private.profile_link_attempts to service_role;

-- Refuse la personne qui a déjà échoué dix fois dans l'heure.
create function private.check_profile_link_rate()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if (select count(*) from private.profile_link_attempts a
      where a.user_id = auth.uid() and a.failed_at > now() - interval '1 hour') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
end;
$$;

-- Note un échec, et oublie ceux de plus d'un jour.
create function private.note_profile_link_failure()
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  delete from private.profile_link_attempts a
  where a.user_id = auth.uid() and a.failed_at < now() - interval '1 day';
  insert into private.profile_link_attempts (user_id) values (auth.uid());
end;
$$;

revoke execute on function private.check_profile_link_rate(), private.note_profile_link_failure()
  from public, anon, authenticated, service_role;

-- Crée un lien et rend son code.
create function public.create_profile_link(p_label text, p_share_level public.visibility)
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
  -- Deux créations simultanées ne doivent pas dépasser la limite.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 2));
  if (select count(*) from public.profile_links l where l.owner_id = auth.uid()) >= 20 then
    raise exception 'too_many_links' using errcode = 'P0001';
  end if;
  for v_try in 1..3 loop
    begin
      insert into public.profile_links (code, label, share_level)
      values (private.random_invite_code(), v_label, p_share_level)
      returning code into v_code;
      return v_code;
    exception when unique_violation then
      null; -- code déjà pris (une chance sur 10^12) : on en tire un autre
    end;
  end loop;
  raise exception 'code_unavailable' using errcode = 'P0001';
end;
$$;

revoke execute on function public.create_profile_link(text, public.visibility) from public, anon;
grant execute on function public.create_profile_link(text, public.visibility) to authenticated;

-- Le nom de la personne derrière un lien, pour l'écran de confirmation ;
-- nul si le lien est inconnu ou supprimé.
create function public.profile_link_preview(p_code text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  perform private.check_profile_link_rate();
  select p.display_name into v_name
  from public.profile_links l join public.profiles p on p.id = l.owner_id
  where l.code = upper(btrim(p_code));
  if not found then
    perform private.note_profile_link_failure();
    return null;
  end if;
  return v_name;
end;
$$;

revoke execute on function public.profile_link_preview(text) from public, anon;
grant execute on function public.profile_link_preview(text) to authenticated;

-- Refait la copie des rdv de p_owner dans le proche p_calendar_id, au niveau
-- p_level. N'efface que les rdv déjà copiés (`source_uid` « profil: »).
create function private.copy_profile_events(
  p_owner uuid, p_level public.visibility, p_calendar_id uuid
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
    and e.ends_at >= now()
    and greatest(p_level, c.visibility, m.visibility, e.visibility) <> 'invisible';

  -- Une copie énorme bloquerait la base : on la refuse (tout est annulé).
  if (select count(*) from public.events e
      where e.calendar_id = p_calendar_id and e.source_uid like 'profil:%') > 2000 then
    raise exception 'profile_too_large' using errcode = 'P0001';
  end if;
end;
$$;

revoke execute on function private.copy_profile_events(uuid, public.visibility, uuid)
  from public, anon, authenticated, service_role;

-- Ouvre un lien : rend le proche (créé, ou rafraîchi s'il existe déjà), ou
-- null si le lien est inconnu ou supprimé.
create function public.import_profile(p_code text)
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
  perform private.copy_profile_events(v_link.owner_id, v_link.share_level, v_calendar_id);
  return v_calendar_id;
end;
$$;

revoke execute on function public.import_profile(text) from public, anon;
grant execute on function public.import_profile(text) to authenticated;
