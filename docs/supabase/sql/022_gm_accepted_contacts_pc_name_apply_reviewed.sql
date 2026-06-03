-- 022_gm_accepted_contacts_pc_name_apply_reviewed.sql
-- M-15G reviewed APPLY for GM accepted participant contacts with PC names.
--
-- Use this reviewed APPLY file in SQL Editor.
-- Do not paste the full draft file when applying this step.
--
-- Scope:
-- - Recreate public.get_gm_session_accepted_contacts(text) because return columns change.
-- - Keep existing columns display_name and discord_handle.
-- - Add discord_mention, pc_name, and pc_name_missing.
-- - Use session_applications.pc_name_snapshot as the PC name source.
-- - Return accepted applications only.
-- - Exclude the session GM from accepted participant rows.
-- - Do not return internal IDs, email, tokens, or raw invalid Discord values.

begin;

drop function if exists public.get_gm_session_accepted_contacts(text);

create function public.get_gm_session_accepted_contacts(
  target_session_id text
)
returns table (
  display_name text,
  discord_handle text,
  discord_mention text,
  pc_name text,
  pc_name_missing boolean
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  if not exists (
    select 1
    from public.sessions as s
    where s.id = v_target_session_id
  ) then
    raise exception 'session not found';
  end if;

  if not (
    public.is_admin()
    or public.is_session_gm(v_target_session_id)
  ) then
    raise exception 'not allowed';
  end if;

  return query
  with accepted_rows as (
    select
      coalesce(nullif(trim(p.display_name), ''), '名前未設定')::text as display_name,
      nullif(trim(p.discord_handle), '') as raw_discord_handle,
      nullif(trim(sa.pc_name_snapshot), '') as snapshot_pc_name,
      sa.updated_at,
      sa.created_at
    from public.session_applications as sa
    join public.sessions as s
      on s.id = sa.session_id
    join public.profiles as p
      on p.id = sa.user_id
    where sa.session_id = v_target_session_id
      and sa.status = 'accepted'
      and (
        s.gm_user_id is null
        or sa.user_id <> s.gm_user_id
      )
  ),
  normalized_rows as (
    select
      ar.display_name,
      case
        when ar.raw_discord_handle ~ '^[0-9]{17,20}$'
          then ar.raw_discord_handle::text
        else null::text
      end as safe_discord_handle,
      coalesce(ar.snapshot_pc_name, 'PC名未登録')::text as safe_pc_name,
      (ar.snapshot_pc_name is null)::boolean as safe_pc_name_missing,
      ar.updated_at,
      ar.created_at
    from accepted_rows as ar
  )
  select
    nr.display_name,
    nr.safe_discord_handle as discord_handle,
    case
      when nr.safe_discord_handle is not null
        then ('<@' || nr.safe_discord_handle || '>')::text
      else '登録されていません'::text
    end as discord_mention,
    nr.safe_pc_name as pc_name,
    nr.safe_pc_name_missing as pc_name_missing
  from normalized_rows as nr
  order by
    nr.display_name asc nulls last,
    nr.updated_at desc nulls last,
    nr.created_at desc nulls last;
end;
$$;

revoke execute on function public.get_gm_session_accepted_contacts(text) from public;
revoke execute on function public.get_gm_session_accepted_contacts(text) from anon;
revoke execute on function public.get_gm_session_accepted_contacts(text) from authenticated;

grant execute on function public.get_gm_session_accepted_contacts(text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- POST-APPLY CHECKS
-- ============================================================

with target_function as (
  select
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    p.proconfig as function_config,
    pg_catalog.pg_get_function_result(p.oid) as result_type
  from pg_catalog.pg_proc as p
  join pg_catalog.pg_namespace as n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_gm_session_accepted_contacts'
    and p.oid::regprocedure::text = 'get_gm_session_accepted_contacts(text)'
)
select
  'get_gm_session_accepted_contacts_function' as check_name,
  count(*) as function_count,
  min(signature) as signature,
  bool_and(security_definer) as all_security_definer,
  bool_and(coalesce(function_config::text, '') like '%search_path%') as has_search_path_config,
  min(result_type) as result_type,
  bool_and(
    result_type like '%display_name text%'
    and result_type like '%discord_handle text%'
    and result_type like '%discord_mention text%'
    and result_type like '%pc_name text%'
    and result_type like '%pc_name_missing boolean%'
  ) as result_type_has_expected_columns
from target_function;

with expected_grants(grantee, expected_execute) as (
  values
    ('authenticated', true),
    ('anon', false),
    ('public', false)
),
actual_grants as (
  select
    lower(rp.grantee) as grantee,
    true as actual_execute
  from information_schema.routine_privileges as rp
  where rp.routine_schema = 'public'
    and rp.routine_name = 'get_gm_session_accepted_contacts'
    and rp.privilege_type = 'EXECUTE'
)
select
  eg.grantee,
  eg.expected_execute,
  coalesce(ag.actual_execute, false) as actual_execute,
  coalesce(ag.actual_execute, false) = eg.expected_execute as ok
from expected_grants as eg
left join actual_grants as ag
  on ag.grantee = eg.grantee
order by eg.grantee;
