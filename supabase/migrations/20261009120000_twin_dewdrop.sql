-- =============================================================================
-- Jumelage avec DewDrop : la troisième app du protocole commun
-- (docs/liens-inter-apps.md du dépôt méta) après Arpente.
--
-- Un groupe Agora peut avoir un jumeau par app : un dans Arpente, un dans
-- DewDrop, chacun avec sa propre invitation sans échéance. Le code d'un cercle
-- DewDrop a 8 caractères (Arpente : 6) ; il ne fait qu'envoyer une demande
-- d'adhésion au créateur du cercle, mais Agora le range comme les autres.
--
-- Choix non évidents :
--   - la contrainte compare app::text, pas l'énuméré : une valeur ajoutée par
--     ALTER TYPE ... ADD VALUE ne peut pas servir dans la transaction qui l'a
--     ajoutée (« unsafe use of new value »), et la migration en est une ;
--   - twin_group est redéfinie à l'identique de 20261005120000_group_twins.sql
--     hormis le format du code distant, qui suit désormais l'app.
--
-- Invariants (supabase/tests/group_twins_dewdrop_test.sql) : un code DewDrop a
-- 8 caractères, un code Arpente toujours 6 ; un jumeau par groupe et par app.
-- =============================================================================

alter type public.twin_app add value if not exists 'dewdrop';

-- Le format d'un code de groupe de l'autre app.
create function private.twin_code_valid(p_app text, p_code text)
returns boolean language sql immutable set search_path = '' as $$
  select case p_app
    when 'arpente' then p_code ~ '^[A-HJ-NP-Z2-9]{6}$'
    when 'dewdrop' then p_code ~ '^[A-HJ-NP-Z2-9]{8}$'
    else false
  end;
$$;

revoke execute on function private.twin_code_valid(text, text) from public, anon;
grant execute on function private.twin_code_valid(text, text) to authenticated, service_role;

alter table public.group_twins drop constraint group_twins_remote_code_format;
alter table public.group_twins add constraint group_twins_remote_code_format check (
  remote_code is null or private.twin_code_valid(app::text, remote_code)
);

create or replace function public.twin_group(
  p_group_id uuid,
  p_app public.twin_app,
  p_remote_code text default null
)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_remote text := nullif(upper(btrim(p_remote_code)), '');
  v_code text;
  v_current text;
begin
  if not private.is_group_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = '42501';
  end if;
  perform 1 from public.groups g where g.id = p_group_id for update;
  if v_remote is not null and not private.twin_code_valid(p_app::text, v_remote) then
    raise exception 'invalid_twin_code' using errcode = '22023';
  end if;
  select gt.invite_code, gt.remote_code into v_code, v_current
  from public.group_twins gt
  where gt.group_id = p_group_id and gt.app = p_app;
  if not found then
    v_code := private.random_invite_code();
    insert into public.group_invites (code, group_id, expires_at) values (v_code, p_group_id, null);
    insert into public.group_twins (group_id, app, invite_code, remote_code)
    values (p_group_id, p_app, v_code, v_remote);
  elsif v_remote is not null and v_current is not null and v_current <> v_remote then
    raise exception 'twin_exists' using errcode = '23505';
  elsif v_remote is not null and v_current is null then
    update public.group_twins gt set remote_code = v_remote
    where gt.group_id = p_group_id and gt.app = p_app;
  end if;
  return v_code;
end;
$$;

revoke execute on function public.twin_group(uuid, public.twin_app, text) from public, anon;
grant execute on function public.twin_group(uuid, public.twin_app, text) to authenticated;
