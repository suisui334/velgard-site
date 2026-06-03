-- 020_application_pc_snapshot_apply_reviewed.sql
-- M-15F reviewed APPLY for application-time PC snapshots.
--
-- Use this reviewed APPLY file in SQL Editor.
-- Do not paste the full draft file when applying this step.
--
-- Scope:
-- - Replace public.create_application_comment(text, text) only.
-- - Keep the frontend RPC arguments unchanged.
-- - Keep application comment text as free text.
-- - Do not ask players to type PC names or Discord user IDs in comments.
-- - Store the caller's active default PC on new PL application and reapply.
-- - Allow application without a registered PC.
-- - Treat GM management comments as comments, not as applications.

begin;

create or replace function public.create_application_comment(
  target_session_id text,
  comment_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
  v_comment_body text;
  v_new_comment_id uuid;
  v_existing_status text;
  v_default_character_id uuid;
  v_default_pc_name text;
  v_is_management_comment boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');
  v_comment_body := nullif(trim(coalesce(comment_body, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  if v_comment_body is null then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  v_is_management_comment := public.is_session_gm(v_target_session_id);

  if not v_is_management_comment
    and not public.can_apply_to_session(v_target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  if not v_is_management_comment then
    select
      pc.id,
      pc.pc_name
    into
      v_default_character_id,
      v_default_pc_name
    from public.player_characters as pc
    where pc.owner_user_id = v_actor_id
      and pc.is_active = true
      and pc.is_default = true
    order by
      pc.updated_at desc nulls last,
      pc.created_at desc nulls last
    limit 1;
  end if;

  select sa.status
  into v_existing_status
  from public.session_applications as sa
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
  for update;

  insert into public.session_comments (
    session_id,
    user_id,
    body,
    is_application
  )
  values (
    v_target_session_id,
    v_actor_id,
    comment_body,
    not v_is_management_comment
  )
  returning id into v_new_comment_id;

  if v_is_management_comment then
    return v_new_comment_id;
  end if;

  if v_existing_status is null then
    insert into public.session_applications (
      session_id,
      user_id,
      comment_id,
      status,
      selected_character_id,
      pc_name_snapshot
    )
    values (
      v_target_session_id,
      v_actor_id,
      v_new_comment_id,
      'pending',
      v_default_character_id,
      v_default_pc_name
    );
  elsif v_existing_status = 'canceled' then
    update public.session_applications
    set
      comment_id = v_new_comment_id,
      status = 'pending',
      canceled_at = null,
      selected_character_id = v_default_character_id,
      pc_name_snapshot = v_default_pc_name,
      updated_at = now()
    where session_id = v_target_session_id
      and user_id = v_actor_id;
  else
    null;
  end if;

  return v_new_comment_id;
end;
$$;

revoke execute on function public.create_application_comment(text, text) from public;
revoke execute on function public.create_application_comment(text, text) from anon;
grant execute on function public.create_application_comment(text, text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- POST-APPLY CHECKS
-- ============================================================

with target_function as (
  select
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    p.proconfig as function_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_application_comment'
    and p.oid::regprocedure::text = 'create_application_comment(text,text)'
)
select
  'create_application_comment_function' as check_name,
  count(*) as function_count,
  min(signature) as signature,
  bool_and(security_definer) as all_security_definer,
  min(function_config::text) as function_config
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
  from information_schema.routine_privileges rp
  where rp.routine_schema = 'public'
    and rp.routine_name = 'create_application_comment'
    and rp.privilege_type = 'EXECUTE'
)
select
  eg.grantee,
  eg.expected_execute,
  coalesce(ag.actual_execute, false) as actual_execute,
  coalesce(ag.actual_execute, false) = eg.expected_execute as ok
from expected_grants eg
left join actual_grants ag
  on ag.grantee = eg.grantee
order by eg.grantee;

select
  c.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'session_applications'
  and c.column_name in ('selected_character_id', 'pc_name_snapshot')
order by c.column_name;
