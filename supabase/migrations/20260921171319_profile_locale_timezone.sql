-- =============================================================================
-- Profil : langue et fuseau pris à l'inscription, fuseau validé, langue
-- recopiée dans les métadonnées d'authentification.
--
-- Pourquoi recopier la langue : les gabarits d'e-mail de GoTrue ne voient que
-- auth.users.raw_user_meta_data (.Data), pas public.profiles. Sans cette
-- copie, qui passe l'app en anglais recevrait encore ses codes en français.
--
-- Invariants :
--   - profiles.timezone est un fuseau que Postgres sait convertir (sinon les
--     récurrences et les récaps décaleraient les heures) ;
--   - une valeur de métadonnées invalide à l'inscription retombe sur les
--     valeurs par défaut, sans jamais faire échouer la création du compte.
-- =============================================================================

-- Un fuseau valide respecte le format de la contrainte profiles.timezone ET
-- existe dans la base de fuseaux de Postgres. Les deux sont nécessaires :
-- « EST5EDT » est connu de Postgres mais hors du format IANA de la contrainte.
create function private.is_valid_timezone(p_timezone text)
returns boolean language sql stable set search_path = '' as $$
  select p_timezone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+){0,2}$'
     and exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone);
$$;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_locale text := case when meta ->> 'locale' in ('fr', 'en') then meta ->> 'locale' else 'fr' end;
  v_timezone text := case
    when private.is_valid_timezone(meta ->> 'timezone') then meta ->> 'timezone'
    else 'Europe/Paris'
  end;
begin
  insert into public.profiles (id, display_name, avatar_url, locale, timezone)
  values (
    new.id,
    left(coalesce(
      nullif(btrim(meta ->> 'display_name'), ''),
      nullif(btrim(meta ->> 'full_name'), ''),
      nullif(btrim(meta -> 'custom_claims' ->> 'global_name'), ''),
      nullif(btrim(meta ->> 'name'), ''),
      'Membre'
    ), 60),
    nullif(meta ->> 'avatar_url', ''),
    v_locale,
    v_timezone
  );
  insert into public.calendars (owner_id, name) values (new.id, 'Agenda');
  return new;
end;
$$;

create function private.check_profile_timezone()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not private.is_valid_timezone(new.timezone) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger profiles_check_timezone
  before update of timezone on public.profiles
  for each row execute function private.check_profile_timezone();

create function private.sync_profile_locale()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update auth.users u
  set raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb)
                           || jsonb_build_object('locale', new.locale)
  where u.id = new.id;
  return new;
end;
$$;

create trigger profiles_sync_locale
  after update of locale on public.profiles
  for each row
  when (old.locale is distinct from new.locale)
  execute function private.sync_profile_locale();

-- Postgres accorde EXECUTE à PUBLIC sur toute nouvelle fonction.
revoke execute on function private.is_valid_timezone(text),
  private.check_profile_timezone(), private.sync_profile_locale()
  from public, anon;
-- Appelée par le trigger de validation, qui s'exécute avec les droits du client.
grant execute on function private.is_valid_timezone(text) to authenticated;
