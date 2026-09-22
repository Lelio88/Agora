-- =============================================================================
-- Un groupe ne reste jamais ni vide ni sans propriétaire.
--
-- delete_my_account transmet ou supprime les groupes de la personne avant
-- d'effacer son compte. Mais un compte peut disparaître autrement : par
-- l'interface d'administration de Supabase, qui supprime auth.users et
-- laisse la cascade effacer ses appartenances. Le groupe restait alors vide
-- (avec son agenda et ses rdv, pour toujours), ou sans propriétaire (plus
-- personne pour nommer un admin ni supprimer le groupe).
--
-- Ce trigger est le filet de sécurité, sur toute sortie d'un membre :
--   - plus aucun membre : le groupe est supprimé (agenda, rdv, réponses en
--     cascade) ;
--   - plus de propriétaire : le groupe revient, comme dans
--     delete_my_account, à l'admin le plus ancien, sinon au membre le plus
--     ancien.
-- Sans effet sur les chemins ordinaires : exclure un membre ou quitter
-- laisse le propriétaire, delete_my_account a déjà transmis, et un groupe
-- supprimé n'existe plus quand la cascade retire ses membres.
--
-- Invariant : un groupe existant a au moins un membre, et exactement un
-- propriétaire.
-- =============================================================================

create function private.keep_group_alive()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_heir uuid;
begin
  -- Verrou du groupe, comme delete_my_account et transfer_group : deux
  -- départs simultanés se sérialisent. Un groupe déjà supprimé (cascade)
  -- n'est plus là : rien à faire.
  perform 1 from public.groups g where g.id = old.group_id for update;
  if not found then
    return null;
  end if;
  if not exists (select 1 from public.group_members gm where gm.group_id = old.group_id) then
    delete from public.groups g where g.id = old.group_id;
    return null;
  end if;
  if exists (select 1 from public.group_members gm
             where gm.group_id = old.group_id and gm.role = 'owner') then
    return null;
  end if;
  select gm.user_id into v_heir
  from public.group_members gm
  where gm.group_id = old.group_id
  order by (gm.role = 'admin') desc, gm.joined_at, gm.user_id
  limit 1;
  update public.group_members gm set role = 'owner'
  where gm.group_id = old.group_id and gm.user_id = v_heir;
  return null;
end;
$$;

create trigger group_members_keep_group_alive
  after delete on public.group_members
  for each row execute function private.keep_group_alive();

revoke execute on function private.keep_group_alive() from public, anon, authenticated;
