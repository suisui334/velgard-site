-- 058_notifications_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm notification/timeline preparation after a separately approved 057 apply gate.
-- - Return boolean/status style results only.
-- - Do not return real user ids, emails, tokens, full URLs, project refs, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
table_rows as (
  select
    n.nspname as schema_name,
    c.relname as table_name,
    c.relrowsecurity as rls_enabled
  from pg_class c
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('user_notifications', 'activity_events')
    and c.relkind = 'r'
),
column_summary as (
  select
    table_name,
    count(*) filter (where column_name = 'id') as id_count,
    count(*) filter (where column_name = 'recipient_user_id') as recipient_user_id_count,
    count(*) filter (where column_name = 'actor_user_id') as actor_user_id_count,
    count(*) filter (where column_name = 'session_id') as session_id_count,
    count(*) filter (where column_name in ('notification_type', 'event_type')) as type_count,
    count(*) filter (where column_name = 'visibility') as visibility_count,
    count(*) filter (where column_name = 'title') as title_count,
    count(*) filter (where column_name = 'body') as body_count,
    count(*) filter (where column_name = 'target_path') as target_path_count,
    count(*) filter (where column_name = 'metadata') as metadata_count,
    count(*) filter (where column_name = 'read_at') as read_at_count,
    count(*) filter (where column_name = 'created_at') as created_at_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name in ('user_notifications', 'activity_events')
  group by table_name
),
constraint_summary as (
  select
    rel.relname as table_name,
    count(*) filter (where con.conname ilike '%type_check%') as type_check_count,
    count(*) filter (where con.conname ilike '%visibility_check%') as visibility_check_count,
    count(*) filter (where con.conname ilike '%target_path_check%') as target_path_check_count,
    count(*) filter (where con.conname ilike '%metadata_object_check%') as metadata_object_check_count
  from pg_constraint con
  join pg_class rel
    on rel.oid = con.conrelid
  join pg_namespace nsp
    on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname in ('user_notifications', 'activity_events')
  group by rel.relname
),
policy_summary as (
  select
    tablename as table_name,
    count(*) filter (where policyname = 'user_notifications_select_own_or_admin') as notification_select_policy_count,
    count(*) filter (where policyname = 'user_notifications_update_own_or_admin') as notification_update_policy_count,
    count(*) filter (where policyname = 'activity_events_select_visible') as activity_select_policy_count
  from pg_policies
  where schemaname = 'public'
    and tablename in ('user_notifications', 'activity_events')
  group by tablename
),
function_rows as (
  select
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) as identity_args,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'get_my_unread_notification_count',
      'get_my_notifications',
      'mark_my_notification_read',
      'mark_all_my_notifications_read',
      'create_session_owner_notification',
      'record_activity_event',
      'get_activity_timeline'
    )
),
function_privileges as (
  select
    fr.proname,
    has_function_privilege((select authenticated_role from role_refs), fr.oid, 'EXECUTE') as authenticated_execute,
    has_function_privilege((select anon_role from role_refs), fr.oid, 'EXECUTE') as anon_execute
  from function_rows fr
),
function_summary as (
  select
    count(*) filter (where proname = 'get_my_unread_notification_count') as unread_count_rpc_count,
    count(*) filter (where proname = 'get_my_notifications') as list_rpc_count,
    count(*) filter (where proname = 'mark_my_notification_read') as mark_one_rpc_count,
    count(*) filter (where proname = 'mark_all_my_notifications_read') as mark_all_rpc_count,
    count(*) filter (where proname = 'create_session_owner_notification') as owner_helper_count,
    count(*) filter (where proname = 'record_activity_event') as activity_helper_count,
    count(*) filter (where proname = 'get_activity_timeline') as timeline_rpc_count,
    bool_and(security_definer) as all_security_definer,
    bool_and(function_config ilike '%search_path=public%') as all_search_path_public
  from function_rows
),
privilege_summary as (
  select
    bool_and(authenticated_execute) filter (
      where proname in (
        'get_my_unread_notification_count',
        'get_my_notifications',
        'mark_my_notification_read',
        'mark_all_my_notifications_read'
      )
    ) as notification_rpcs_authenticated_execute,
    bool_or(anon_execute) filter (
      where proname in (
        'get_my_unread_notification_count',
        'get_my_notifications',
        'mark_my_notification_read',
        'mark_all_my_notifications_read'
      )
    ) as notification_rpcs_anon_execute,
    bool_or(authenticated_execute) filter (
      where proname in ('create_session_owner_notification', 'record_activity_event')
    ) as helpers_authenticated_execute,
    bool_or(anon_execute) filter (
      where proname in ('create_session_owner_notification', 'record_activity_event')
    ) as helpers_anon_execute,
    bool_or(authenticated_execute) filter (where proname = 'get_activity_timeline') as timeline_authenticated_execute,
    bool_or(anon_execute) filter (where proname = 'get_activity_timeline') as timeline_anon_execute
  from function_privileges
),
output_rows as (
  select
    10 as sort_order,
    'user_notifications_table_exists'::text as check_name,
    case when exists (select 1 from table_rows where table_name = 'user_notifications') then 'ok' else 'missing' end as status,
    (select count(*)::text from table_rows where table_name = 'user_notifications') as result_value,
    'Private recipient notification table should exist.'::text as note

  union all
  select
    20,
    'user_notifications_columns',
    case
      when coalesce(cs.id_count, 0) = 1
       and coalesce(cs.recipient_user_id_count, 0) = 1
       and coalesce(cs.actor_user_id_count, 0) = 1
       and coalesce(cs.session_id_count, 0) = 1
       and coalesce(cs.type_count, 0) = 1
       and coalesce(cs.title_count, 0) = 1
       and coalesce(cs.target_path_count, 0) = 1
       and coalesce(cs.metadata_count, 0) = 1
       and coalesce(cs.read_at_count, 0) = 1
       and coalesce(cs.created_at_count, 0) = 1
      then 'ok' else 'review'
    end,
    concat(
      'recipient=', coalesce(cs.recipient_user_id_count, 0),
      ',actor=', coalesce(cs.actor_user_id_count, 0),
      ',session=', coalesce(cs.session_id_count, 0),
      ',type=', coalesce(cs.type_count, 0),
      ',read_at=', coalesce(cs.read_at_count, 0)
    ),
    'Notification table should include recipient, actor, session, type, target, read state, and created time.'
  from column_summary cs
  where cs.table_name = 'user_notifications'

  union all
  select
    30,
    'user_notifications_rls_enabled',
    case when tr.rls_enabled then 'ok' else 'review' end,
    coalesce(tr.rls_enabled, false)::text,
    'Private notification table should have RLS enabled.'
  from table_rows tr
  where tr.table_name = 'user_notifications'

  union all
  select
    40,
    'user_notifications_policies_present',
    case
      when coalesce(ps.notification_select_policy_count, 0) = 1
       and coalesce(ps.notification_update_policy_count, 0) = 0
      then 'ok' else 'review'
    end,
    concat(
      'select=', coalesce(ps.notification_select_policy_count, 0),
      ',update=', coalesce(ps.notification_update_policy_count, 0)
    ),
    'Notification direct select is recipient/admin scoped; mark-read should use RPCs rather than direct table update grants.'
  from policy_summary ps
  where ps.table_name = 'user_notifications'

  union all
  select
    50,
    'user_notifications_constraints',
    case
      when coalesce(cs.type_check_count, 0) >= 1
       and coalesce(cs.target_path_check_count, 0) >= 1
       and coalesce(cs.metadata_object_check_count, 0) >= 1
      then 'ok' else 'review'
    end,
    concat(
      'type=', coalesce(cs.type_check_count, 0),
      ',target=', coalesce(cs.target_path_check_count, 0),
      ',metadata=', coalesce(cs.metadata_object_check_count, 0)
    ),
    'Notification constraints should limit event types, relative targets, and metadata shape.'
  from constraint_summary cs
  where cs.table_name = 'user_notifications'

  union all
  select
    60,
    'activity_events_table_exists',
    case when exists (select 1 from table_rows where table_name = 'activity_events') then 'ok' else 'missing' end,
    (select count(*)::text from table_rows where table_name = 'activity_events'),
    'Separate activity timeline table should exist.'

  union all
  select
    70,
    'activity_events_columns',
    case
      when coalesce(cs.id_count, 0) = 1
       and coalesce(cs.actor_user_id_count, 0) = 1
       and coalesce(cs.session_id_count, 0) = 1
       and coalesce(cs.type_count, 0) = 1
       and coalesce(cs.visibility_count, 0) = 1
       and coalesce(cs.title_count, 0) = 1
       and coalesce(cs.target_path_count, 0) = 1
       and coalesce(cs.metadata_count, 0) = 1
       and coalesce(cs.created_at_count, 0) = 1
      then 'ok' else 'review'
    end,
    concat(
      'actor=', coalesce(cs.actor_user_id_count, 0),
      ',session=', coalesce(cs.session_id_count, 0),
      ',type=', coalesce(cs.type_count, 0),
      ',visibility=', coalesce(cs.visibility_count, 0)
    ),
    'Activity events should include actor, session, event type, visibility, target, and created time.'
  from column_summary cs
  where cs.table_name = 'activity_events'

  union all
  select
    80,
    'activity_events_rls_enabled',
    case when tr.rls_enabled then 'ok' else 'review' end,
    coalesce(tr.rls_enabled, false)::text,
    'Timeline source table should have RLS enabled.'
  from table_rows tr
  where tr.table_name = 'activity_events'

  union all
  select
    90,
    'activity_events_policies_present',
    case when coalesce(ps.activity_select_policy_count, 0) = 1 then 'ok' else 'review' end,
    coalesce(ps.activity_select_policy_count, 0)::text,
    'Activity timeline should have visibility-scoped select policy.'
  from policy_summary ps
  where ps.table_name = 'activity_events'

  union all
  select
    100,
    'activity_events_constraints',
    case
      when coalesce(cs.type_check_count, 0) >= 1
       and coalesce(cs.visibility_check_count, 0) >= 1
       and coalesce(cs.target_path_check_count, 0) >= 1
       and coalesce(cs.metadata_object_check_count, 0) >= 1
      then 'ok' else 'review'
    end,
    concat(
      'type=', coalesce(cs.type_check_count, 0),
      ',visibility=', coalesce(cs.visibility_check_count, 0),
      ',target=', coalesce(cs.target_path_check_count, 0),
      ',metadata=', coalesce(cs.metadata_object_check_count, 0)
    ),
    'Activity constraints should limit event types, visibility, relative targets, and metadata shape.'
  from constraint_summary cs
  where cs.table_name = 'activity_events'

  union all
  select
    110,
    'notification_rpcs_exist',
    case
      when fs.unread_count_rpc_count = 1
       and fs.list_rpc_count = 1
       and fs.mark_one_rpc_count = 1
       and fs.mark_all_rpc_count = 1
      then 'ok' else 'review'
    end,
    concat(
      'count=', fs.unread_count_rpc_count,
      ',list=', fs.list_rpc_count,
      ',mark_one=', fs.mark_one_rpc_count,
      ',mark_all=', fs.mark_all_rpc_count
    ),
    'Current-user notification read/mark-read RPCs should exist.'
  from function_summary fs

  union all
  select
    120,
    'timeline_and_helper_rpcs_exist',
    case
      when fs.owner_helper_count = 1
       and fs.activity_helper_count = 1
       and fs.timeline_rpc_count = 1
      then 'ok' else 'review'
    end,
    concat(
      'owner_helper=', fs.owner_helper_count,
      ',activity_helper=', fs.activity_helper_count,
      ',timeline=', fs.timeline_rpc_count
    ),
    'Internal helper RPCs and the public timeline read RPC should exist.'
  from function_summary fs

  union all
  select
    130,
    'notification_rpc_security',
    case when fs.all_security_definer and fs.all_search_path_public then 'ok' else 'review' end,
    concat(
      'security_definer=', coalesce(fs.all_security_definer, false),
      ',search_path_public=', coalesce(fs.all_search_path_public, false)
    ),
    'Notification/timeline RPCs should be security definer with search_path=public.'
  from function_summary fs

  union all
  select
    140,
    'notification_rpc_privileges',
    case
      when coalesce(ps.notification_rpcs_authenticated_execute, false)
       and not coalesce(ps.notification_rpcs_anon_execute, false)
      then 'ok' else 'review'
    end,
    concat(
      'authenticated=', coalesce(ps.notification_rpcs_authenticated_execute, false),
      ',anon=', coalesce(ps.notification_rpcs_anon_execute, false)
    ),
    'Notification RPCs should be executable by authenticated users, not anon.'
  from privilege_summary ps

  union all
  select
    150,
    'internal_helper_privileges',
    case
      when not coalesce(ps.helpers_authenticated_execute, false)
       and not coalesce(ps.helpers_anon_execute, false)
      then 'ok' else 'review'
    end,
    concat(
      'authenticated=', coalesce(ps.helpers_authenticated_execute, false),
      ',anon=', coalesce(ps.helpers_anon_execute, false)
    ),
    'Internal helper RPCs should not be directly executable by web client roles.'
  from privilege_summary ps

  union all
  select
    160,
    'timeline_rpc_privileges',
    case
      when coalesce(ps.timeline_authenticated_execute, false)
       and coalesce(ps.timeline_anon_execute, false)
      then 'ok' else 'review'
    end,
    concat(
      'authenticated=', coalesce(ps.timeline_authenticated_execute, false),
      ',anon=', coalesce(ps.timeline_anon_execute, false)
    ),
    'Timeline read RPC may be executable by anon/authenticated because it filters visibility internally.'
  from privilege_summary ps

  union all
  select
    170,
    'post_apply_ready_for_notification_frontend_design',
    case
      when exists (select 1 from table_rows where table_name = 'user_notifications')
       and exists (select 1 from table_rows where table_name = 'activity_events')
       and coalesce(fs.unread_count_rpc_count, 0) = 1
       and coalesce(fs.list_rpc_count, 0) = 1
       and coalesce(fs.mark_one_rpc_count, 0) = 1
       and coalesce(fs.mark_all_rpc_count, 0) = 1
       and coalesce(ps.notification_rpcs_authenticated_execute, false)
       and not coalesce(ps.notification_rpcs_anon_execute, false)
      then 'ok' else 'review'
    end,
    concat(
      'notification_table=', exists (select 1 from table_rows where table_name = 'user_notifications'),
      ',activity_table=', exists (select 1 from table_rows where table_name = 'activity_events'),
      ',notification_rpcs_authenticated=', coalesce(ps.notification_rpcs_authenticated_execute, false)
    ),
    'If ok, the next gate can design or implement the frontend bell/list and RPC instrumentation review.'
  from function_summary fs
  cross join privilege_summary ps
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order, check_name;
