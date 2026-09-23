-- =============================================================================
-- Ne promettre que ce qui arrivera : un rdv ne « reste au groupe » que si le
-- groupe lui survit.
--
-- Le trigger keep_group_alive supprime un groupe qui perd son dernier membre,
-- avec son agenda et ses rdv. Partir d'un groupe où l'on est seul n'y laisse
-- donc rien — alors que la version précédente de ces fonctions l'annonçait
-- quand même, et proposait d'effacer ce qui allait disparaître de toute façon.
-- Constaté en production, sur un compte de vérification seul dans son groupe.
--
-- Les deux fonctions ne retiennent donc que les rdv des groupes où il reste
-- QUELQU'UN D'AUTRE. Elles restent alignées l'une sur l'autre : la case à
-- cocher efface exactement ce que la liste annonce.
-- =============================================================================

create or replace function public.my_proposed_group_events()
returns table (
  event_id uuid,
  title text,
  starts_at timestamptz,
  group_id uuid,
  group_name text
)
language sql stable security invoker set search_path = '' as $$
  select e.id, e.title, e.starts_at, g.id, g.name
  from public.events e
  join public.calendars c on c.id = e.calendar_id
  join public.groups g on g.id = c.group_id
  where e.created_by = (select auth.uid())
    and e.series_id is null
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = g.id and gm.user_id <> (select auth.uid())
    )
  order by e.starts_at;
$$;

create or replace function public.delete_my_proposed_group_events()
returns integer
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_deleted integer;
begin
  with mine as (
    select e.id
    from public.events e
    join public.calendars c on c.id = e.calendar_id
    where c.group_id is not null
      and e.created_by = (select auth.uid())
      and e.series_id is null
      and exists (
        select 1 from public.group_members gm
        where gm.group_id = c.group_id and gm.user_id <> (select auth.uid())
      )
  )
  delete from public.events e using mine where e.id = mine.id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;
