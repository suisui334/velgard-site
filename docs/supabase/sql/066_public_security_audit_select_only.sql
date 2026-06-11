-- 066_public_security_audit_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Pre-public security audit for Auth abuse, direct table privileges, RPC exposure,
--   RLS coverage, Storage/avatar policy shape, notification/timeline visibility,
--   and Discord sync helper exposure.
-- - Return counts, booleans, table/function names, and status notes only.
-- - Do not return real user ids, emails, session ids, activity ids, notification ids,
--   avatar object paths, full URLs, project refs, tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
public_base_tables as (
  select
    c.oid,
    n.nspname,
    c.relname,
    c.relrowsecurity,
    c.relforcerowsecurity
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
),
table_privileges as (
  select
    t.relname,
    t.relrowsecurity,
    coalesce(pg_catalog.has_table_privilege((select anon_role from role_refs), t.oid, 'SELECT'), false) as anon_select,
    coalesce(pg_catalog.has_table_privilege((select anon_role from role_refs), t.oid, 'INSERT'), false) as anon_insert,
    coalesce(pg_catalog.has_table_privilege((select anon_role from role_refs), t.oid, 'UPDATE'), false) as anon_update,
    coalesce(pg_catalog.has_table_privilege((select anon_role from role_refs), t.oid, 'DELETE'), false) as anon_delete,
    coalesce(pg_catalog.has_table_privilege((select authenticated_role from role_refs), t.oid, 'SELECT'), false) as authenticated_select,
    coalesce(pg_catalog.has_table_privilege((select authenticated_role from role_refs), t.oid, 'INSERT'), false) as authenticated_insert,
    coalesce(pg_catalog.has_table_privilege((select authenticated_role from role_refs), t.oid, 'UPDATE'), false) as authenticated_update,
    coalesce(pg_catalog.has_table_privilege((select authenticated_role from role_refs), t.oid, 'DELETE'), false) as authenticated_delete
  from public_base_tables t
),
table_summary as (
  select
    count(*) as table_count,
    count(*) filter (where not relrowsecurity) as rls_disabled_count,
    string_agg(relname, ', ' order by relname) filter (where not relrowsecurity) as rls_disabled_tables,
    count(*) filter (where anon_insert or anon_update or anon_delete) as anon_write_table_count,
    string_agg(relname, ', ' order by relname) filter (where anon_insert or anon_update or anon_delete) as anon_write_tables,
    count(*) filter (where authenticated_insert or authenticated_update or authenticated_delete) as authenticated_write_table_count,
    string_agg(relname, ', ' order by relname) filter (where authenticated_insert or authenticated_update or authenticated_delete) as authenticated_write_tables
  from table_privileges
),
key_table_privileges as (
  select
    count(*) filter (
      where relname in ('sessions', 'session_comments', 'session_applications')
        and (anon_insert or anon_update or anon_delete or authenticated_insert or authenticated_update or authenticated_delete)
    ) as session_write_grant_count,
    count(*) filter (
      where relname in ('user_notifications', 'activity_events')
        and (anon_insert or anon_update or anon_delete or authenticated_insert or authenticated_update or authenticated_delete)
    ) as notification_activity_write_grant_count,
    count(*) filter (
      where relname in ('profiles', 'user_roles')
        and (anon_insert or anon_update or anon_delete or authenticated_insert or authenticated_update or authenticated_delete)
    ) as profile_role_write_grant_count,
    string_agg(relname, ', ' order by relname) filter (
      where relname in (
        'sessions',
        'session_comments',
        'session_applications',
        'user_notifications',
        'activity_events',
        'profiles',
        'user_roles'
      )
      and (anon_insert or anon_update or anon_delete or authenticated_insert or authenticated_update or authenticated_delete)
    ) as key_tables_with_write_grants
  from table_privileges
),
policy_summary as (
  select
    schemaname,
    tablename,
    count(*) as policy_count,
    string_agg(policyname, ', ' order by policyname) as policy_names
  from pg_catalog.pg_policies
  where schemaname in ('public', 'storage')
  group by schemaname, tablename
),
notification_policy_summary as (
  select
    count(*) filter (where tablename = 'user_notifications') as user_notification_policy_count,
    max(policy_names) filter (where tablename = 'user_notifications') as user_notification_policy_names,
    count(*) filter (where tablename = 'activity_events') as activity_policy_count,
    max(policy_names) filter (where tablename = 'activity_events') as activity_policy_names
  from policy_summary
  where schemaname = 'public'
),
routine_rows as (
  select
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    p.prosecdef,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_catalog.pg_get_functiondef(p.oid) as function_def
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
),
routine_privileges as (
  select
    r.*,
    coalesce(pg_catalog.has_function_privilege((select anon_role from role_refs), r.oid, 'EXECUTE'), false) as anon_execute,
    coalesce(pg_catalog.has_function_privilege((select authenticated_role from role_refs), r.oid, 'EXECUTE'), false) as authenticated_execute
  from routine_rows r
),
security_definer_summary as (
  select
    count(*) filter (where prosecdef) as security_definer_count,
    count(*) filter (where prosecdef and function_config not ilike '%search_path=public%') as missing_search_path_count,
    string_agg(signature, '; ' order by signature) filter (where prosecdef and function_config not ilike '%search_path=public%') as missing_search_path_signatures
  from routine_privileges
),
rpc_exposure_summary as (
  select
    count(*) filter (where anon_execute) as anon_executable_count,
    count(*) filter (where authenticated_execute) as authenticated_executable_count,
    count(*) filter (
      where anon_execute
        and proname !~ '^(get_|is_)'
    ) as anon_non_read_named_rpc_count,
    string_agg(signature, '; ' order by signature) filter (
      where anon_execute
        and proname !~ '^(get_|is_)'
    ) as anon_non_read_named_rpc_signatures,
    count(*) filter (
      where authenticated_execute
        and proname in (
          'create_session_owner_notification',
          'record_activity_event'
        )
    ) as authenticated_internal_helper_execute_count,
    count(*) filter (
      where anon_execute
        and proname in (
          'create_session_owner_notification',
          'record_activity_event'
        )
    ) as anon_internal_helper_execute_count
  from routine_privileges
),
discord_rpc_summary as (
  select
    count(*) filter (where proname like '%discord%') as discord_rpc_count,
    count(*) filter (where proname like '%discord%' and anon_execute) as discord_anon_execute_count,
    count(*) filter (
      where proname like '%discord%'
        and authenticated_execute
        and proname ~ '^(check_|record_)'
    ) as discord_authenticated_helper_execute_count,
    string_agg(signature, '; ' order by signature) filter (where proname like '%discord%' and anon_execute) as discord_anon_execute_signatures
  from routine_privileges
),
comment_rpc_patterns as (
  select
    count(*) filter (where signature = 'create_application_comment(text,text)') as comment_rpc_count,
    coalesce(bool_or(function_def ilike '%char_length%' or function_def ilike '%length(%') filter (where signature = 'create_application_comment(text,text)'), false) as has_length_guard_pattern,
    coalesce(bool_or(function_def ilike '%http%' or function_def ilike '%url%') filter (where signature = 'create_application_comment(text,text)'), false) as has_url_guard_pattern,
    coalesce(bool_or(function_def ilike '%cooldown%' or function_def ilike '%rate%' or function_def ilike '%interval%') filter (where signature = 'create_application_comment(text,text)'), false) as has_cooldown_pattern,
    coalesce(bool_or(function_def ilike '%activity_events%' and function_def ilike '%authenticated%') filter (where signature = 'create_application_comment(text,text)'), false) as has_authenticated_activity_pattern,
    coalesce(bool_or(function_def ilike '%GM/admin management comments do not create shared activity rows%') filter (where signature = 'create_application_comment(text,text)'), false) as has_management_activity_skip_pattern
  from routine_rows
),
public_profiles_columns as (
  select
    count(*) as column_count,
    string_agg(column_name, ', ' order by ordinal_position) as column_names,
    count(*) filter (
      where column_name ilike '%email%'
         or column_name ilike '%token%'
         or column_name ilike '%secret%'
         or column_name ilike '%discord%'
    ) as risky_public_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
),
storage_bucket_summary as (
  select
    count(*) as bucket_count,
    count(*) filter (where id = 'avatars') as avatars_bucket_count,
    coalesce(bool_or(id = 'avatars' and public is true), false) as avatars_public_read,
    coalesce(bool_or(id = 'avatars' and file_size_limit <= 1048576), false) as avatars_size_limit_ready,
    coalesce(bool_or(id = 'avatars' and allowed_mime_types @> array['image/png', 'image/jpeg', 'image/webp']), false) as avatars_mime_types_ready,
    string_agg(id || ':public=' || public::text, ', ' order by id) as bucket_public_summary
  from storage.buckets
),
storage_policy_summary as (
  select
    count(*) filter (where policyname = 'avatars_public_read') as avatars_public_read_policy_count,
    count(*) filter (where policyname = 'avatars_owner_insert') as avatars_owner_insert_policy_count,
    count(*) filter (where policyname = 'avatars_owner_update') as avatars_owner_update_policy_count,
    count(*) filter (where policyname = 'avatars_owner_delete') as avatars_owner_delete_policy_count,
    string_agg(policyname, ', ' order by policyname) filter (where tablename = 'objects') as storage_object_policy_names
  from pg_catalog.pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
),
auth_user_counts as (
  select
    count(*) as auth_user_count,
    count(*) filter (where email_confirmed_at is null) as unconfirmed_user_count,
    count(*) filter (where email_confirmed_at is not null) as confirmed_user_count
  from auth.users
),
output_rows as (
  select
    10 as sort_order,
    'public_tables_rls_enabled'::text as check_name,
    case when rls_disabled_count = 0 then 'ok' else 'review' end as status,
    concat('tables=', table_count, ',rls_disabled=', rls_disabled_count) as result_value,
    coalesce('RLS disabled tables: ' || rls_disabled_tables, 'All public base tables have RLS enabled.') as note
  from table_summary

  union all
  select
    20,
    'anon_direct_table_write_grants',
    case when anon_write_table_count = 0 then 'ok' else 'review' end,
    anon_write_table_count::text,
    coalesce('anon write grants: ' || anon_write_tables, 'anon has no direct public table write grants.')
  from table_summary

  union all
  select
    30,
    'authenticated_direct_table_write_grants',
    case when authenticated_write_table_count = 0 then 'ok' else 'review' end,
    authenticated_write_table_count::text,
    coalesce('authenticated write grants: ' || authenticated_write_tables, 'authenticated has no direct public table write grants.')
  from table_summary

  union all
  select
    40,
    'key_tables_direct_write_grants',
    case
      when session_write_grant_count = 0
       and notification_activity_write_grant_count = 0
       and profile_role_write_grant_count = 0
      then 'ok' else 'review'
    end,
    concat(
      'sessions=', session_write_grant_count,
      ',notification_activity=', notification_activity_write_grant_count,
      ',profile_role=', profile_role_write_grant_count
    ),
    coalesce('Key tables with direct write grants: ' || key_tables_with_write_grants, 'Key tables have no direct web-client write grants.')
  from key_table_privileges

  union all
  select
    50,
    'security_definer_search_path',
    case when missing_search_path_count = 0 then 'ok' else 'review' end,
    concat('security_definer=', security_definer_count, ',missing_search_path=', missing_search_path_count),
    coalesce('Missing search_path signatures: ' || missing_search_path_signatures, 'All security definer functions pin search_path=public.')
  from security_definer_summary

  union all
  select
    60,
    'rpc_anon_exposure_summary',
    case when anon_non_read_named_rpc_count = 0 then 'ok' else 'review' end,
    concat('anon_executable=', anon_executable_count, ',anon_non_read_named=', anon_non_read_named_rpc_count),
    coalesce('Review anon executable signatures: ' || anon_non_read_named_rpc_signatures, 'anon executable RPCs look read/check named only by this heuristic.')
  from rpc_exposure_summary

  union all
  select
    70,
    'internal_helper_direct_execute',
    case when authenticated_internal_helper_execute_count = 0 and anon_internal_helper_execute_count = 0 then 'ok' else 'review' end,
    concat('authenticated=', authenticated_internal_helper_execute_count, ',anon=', anon_internal_helper_execute_count),
    'Internal notification/activity helpers should not be directly executable by web-client roles.'
  from rpc_exposure_summary

  union all
  select
    80,
    'discord_sync_rpc_exposure',
    case when discord_anon_execute_count = 0 then 'ok' else 'review' end,
    concat(
      'discord_rpc=', discord_rpc_count,
      ',anon_execute=', discord_anon_execute_count,
      ',authenticated_check_record=', discord_authenticated_helper_execute_count
    ),
    coalesce('Discord anon executable signatures: ' || discord_anon_execute_signatures, 'Discord sync RPCs are not anon-executable.')
  from discord_rpc_summary

  union all
  select
    90,
    'public_profiles_minimal_columns',
    case when risky_public_column_count = 0 then 'ok' else 'review' end,
    concat('columns=', column_count, ',risky_named_columns=', risky_public_column_count),
    'Columns: ' || coalesce(column_names, '(none)')
  from public_profiles_columns

  union all
  select
    100,
    'notification_activity_policies',
    case when user_notification_policy_count > 0 and activity_policy_count > 0 then 'ok' else 'review' end,
    concat('notifications=', user_notification_policy_count, ',activity=', activity_policy_count),
    concat(
      'notification policies=', coalesce(user_notification_policy_names, '(none)'),
      '; activity policies=', coalesce(activity_policy_names, '(none)')
    )
  from notification_policy_summary

  union all
  select
    110,
    'avatars_bucket_and_limits',
    case
      when avatars_bucket_count = 1
       and avatars_public_read
       and avatars_size_limit_ready
       and avatars_mime_types_ready
      then 'ok' else 'review'
    end,
    concat(
      'bucket=', avatars_bucket_count,
      ',public_read=', avatars_public_read,
      ',size_limit=', avatars_size_limit_ready,
      ',mime=', avatars_mime_types_ready
    ),
    coalesce(bucket_public_summary, '(no storage buckets visible)')
  from storage_bucket_summary

  union all
  select
    120,
    'avatars_storage_policies',
    case
      when avatars_public_read_policy_count = 1
       and avatars_owner_insert_policy_count = 1
       and avatars_owner_update_policy_count = 1
       and avatars_owner_delete_policy_count = 1
      then 'ok' else 'review'
    end,
    concat(
      'read=', avatars_public_read_policy_count,
      ',insert=', avatars_owner_insert_policy_count,
      ',update=', avatars_owner_update_policy_count,
      ',delete=', avatars_owner_delete_policy_count
    ),
    'Storage object policies: ' || coalesce(storage_object_policy_names, '(none)')
  from storage_policy_summary

  union all
  select
    130,
    'auth_user_confirmation_counts',
    'info',
    concat('total=', auth_user_count, ',confirmed=', confirmed_user_count, ',unconfirmed=', unconfirmed_user_count),
    'Counts only. Use Dashboard gates for Auth rate limits, CAPTCHA, invite/approval mode, and mail provider settings.'
  from auth_user_counts

  union all
  select
    140,
    'comment_application_spam_guards_static',
    case when has_length_guard_pattern and has_cooldown_pattern and has_url_guard_pattern then 'ok' else 'review' end,
    concat(
      'rpc=', comment_rpc_count,
      ',length=', has_length_guard_pattern,
      ',cooldown=', has_cooldown_pattern,
      ',url=', has_url_guard_pattern
    ),
    'Static pattern check only. Missing cooldown/URL-count guards should be reviewed before broader public release.'
  from comment_rpc_patterns

  union all
  select
    150,
    'timeline_activity_visibility_static',
    case when has_authenticated_activity_pattern and has_management_activity_skip_pattern then 'ok' else 'review' end,
    concat(
      'authenticated_activity=', has_authenticated_activity_pattern,
      ',management_skip=', has_management_activity_skip_pattern
    ),
    'Shared TIMELINE should keep PL comment/application activity login-visible and skip GM/admin management comments.'
  from comment_rpc_patterns

  union all
  select
    160,
    'public_security_audit_next_step',
    'review',
    'manual_triage_required',
    'Review any review rows, then prioritize P0/P1 hardening gates before wider public release.'
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
