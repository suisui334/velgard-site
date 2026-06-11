-- 074_membership_access_control_inventory_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Inventory current DB/RPC/profile/role state before designing community
--   membership approval controls.
-- - Help decide whether membership status should live on profiles or in a
--   separate table.
-- - Help decide how a membership_approver role can fit existing role design.
--
-- Safety:
-- - SELECT-only.
-- - Do not return concrete user ids, emails, session ids, activity ids,
--   notification ids, full URLs, project refs, tokens, keys, or secrets.
-- - Do not return function bodies.

with target_rpcs(rpc_name, category, membership_gate) as (
  values
    ('create_session_post', 'approved_gate_required_session_post', 'approved_required'),
    ('update_session_post', 'approved_gate_required_session_post', 'approved_required'),
    ('delete_session_post', 'approved_gate_required_session_post', 'approved_required'),
    ('create_application_comment', 'approved_gate_required_comment_application', 'approved_required'),
    ('update_application_comment', 'approved_gate_required_comment_application', 'approved_required'),
    ('delete_application_comment_and_maybe_cancel', 'approved_gate_required_comment_application', 'approved_required'),
    ('cancel_my_session_application', 'approved_gate_required_comment_application', 'approved_required'),
    ('set_application_status', 'approved_gate_required_gm_application', 'approved_required'),
    ('get_gm_session_application_history', 'approved_gate_required_gm_application', 'approved_required'),
    ('get_gm_session_accepted_contacts', 'approved_gate_required_gm_application', 'approved_required'),
    ('get_my_player_characters', 'approved_gate_required_player_character', 'approved_required'),
    ('create_player_character', 'approved_gate_required_player_character', 'approved_required'),
    ('update_player_character', 'approved_gate_required_player_character', 'approved_required'),
    ('set_default_player_character', 'approved_gate_required_player_character', 'approved_required'),
    ('deactivate_player_character', 'approved_gate_required_player_character', 'approved_required'),
    ('get_my_template_presets', 'approved_gate_required_template', 'approved_required'),
    ('create_template_preset', 'approved_gate_required_template', 'approved_required'),
    ('update_template_preset', 'approved_gate_required_template', 'approved_required'),
    ('deactivate_template_preset', 'approved_gate_required_template', 'approved_required'),
    ('update_my_avatar_path', 'approved_gate_required_avatar', 'approved_required'),
    ('clear_my_avatar_path', 'approved_gate_required_avatar', 'approved_required'),
    ('get_my_unread_notification_count', 'approved_gate_required_notification', 'approved_required'),
    ('get_my_notifications', 'approved_gate_required_notification', 'approved_required'),
    ('mark_my_notification_read', 'approved_gate_required_notification', 'approved_required'),
    ('mark_all_my_notifications_read', 'approved_gate_required_notification', 'approved_required'),
    ('get_activity_timeline', 'approved_gate_required_timeline', 'approved_required_or_public_read_review'),
    ('check_discord_session_post_create_ready', 'approved_gate_required_discord_sync', 'approved_required'),
    ('record_discord_session_post_create_success', 'approved_gate_required_discord_sync', 'approved_required'),
    ('record_discord_session_post_create_failure', 'approved_gate_required_discord_sync', 'approved_required'),
    ('check_discord_session_post_update_ready', 'approved_gate_required_discord_sync', 'approved_required'),
    ('record_discord_session_post_update_success', 'approved_gate_required_discord_sync', 'approved_required'),
    ('record_discord_session_post_update_failure', 'approved_gate_required_discord_sync', 'approved_required'),
    ('check_discord_session_post_delete_ready', 'approved_gate_required_discord_sync', 'approved_required'),
    ('record_discord_session_post_delete_failure', 'approved_gate_required_discord_sync', 'approved_required'),
    ('update_display_name', 'pending_allowed_profile_candidate', 'pending_allowed_candidate'),
    ('get_my_profile_contact', 'pending_allowed_profile_candidate', 'pending_allowed_candidate'),
    ('update_my_discord_id', 'pending_allowed_profile_candidate', 'pending_allowed_candidate'),
    ('has_role', 'existing_authority_helper', 'review_helper'),
    ('is_admin', 'existing_authority_helper', 'review_helper'),
    ('is_session_gm', 'existing_authority_helper', 'review_helper'),
    ('handle_new_auth_user_profile', 'auth_profile_trigger', 'trigger_internal')
),
role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
profile_columns as (
  select
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'profiles'
),
profile_column_summary as (
  select
    count(*) as column_count,
    count(*) filter (where column_name in ('membership_status', 'status', 'member_status', 'approval_status')) as membership_status_like_columns,
    count(*) filter (where column_name in ('role', 'roles', 'user_role')) as role_like_columns,
    count(*) filter (where column_name in ('display_name', 'discord_name', 'discord_user_id', 'avatar_path', 'avatar_updated_at')) as known_profile_columns
  from profile_columns
),
public_profile_columns as (
  select
    c.column_name
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'public_profiles'
),
membership_tables as (
  select
    t.table_name
  from information_schema.tables t
  where t.table_schema = 'public'
    and t.table_name in (
      'community_memberships',
      'community_membership_events',
      'membership_requests',
      'membership_approvals',
      'user_memberships'
    )
),
role_tables as (
  select
    t.table_name
  from information_schema.tables t
  where t.table_schema = 'public'
    and (
      t.table_name in ('user_roles', 'profile_roles', 'roles')
      or t.table_name ilike '%role%'
    )
),
role_columns as (
  select
    c.table_name,
    c.column_name,
    c.data_type
  from information_schema.columns c
  join role_tables rt
    on rt.table_name = c.table_name
  where c.table_schema = 'public'
),
role_value_checks as (
  select
    to_regclass('public.user_roles') is not null as has_user_roles,
    to_regclass('public.profile_roles') is not null as has_profile_roles,
    to_regclass('public.roles') is not null as has_roles_table,
    case
      when to_regclass('public.user_roles') is not null then true
      when to_regclass('public.profile_roles') is not null then true
      when to_regclass('public.roles') is not null then true
      else false
    end as has_role_storage
),
function_rows as (
  select
    n.nspname as schema_name,
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    p.proacl,
    p.proowner,
    lower(coalesce(pg_catalog.pg_get_function_result(p.oid), '')) as result_type
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
),
function_privileges as (
  select
    fr.*,
    exists (
      select 1
      from aclexplode(coalesce(fr.proacl, acldefault('f', fr.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_execute,
    coalesce(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select anon_role from role_refs), fr.oid, 'EXECUTE')
      end,
      false
    ) as anon_execute,
    coalesce(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select authenticated_role from role_refs), fr.oid, 'EXECUTE')
      end,
      false
    ) as authenticated_execute,
    fr.function_config ilike '%search_path=%' as has_search_path,
    fr.function_config ilike '%search_path=public%' as has_search_path_public
  from function_rows fr
),
target_rpc_matches as (
  select
    tr.rpc_name,
    tr.category,
    tr.membership_gate,
    fp.signature,
    fp.security_definer,
    fp.has_search_path,
    fp.has_search_path_public,
    fp.public_execute,
    fp.anon_execute,
    fp.authenticated_execute
  from target_rpcs tr
  left join function_privileges fp
    on fp.proname = tr.rpc_name
),
target_rpc_summary as (
  select
    category,
    membership_gate,
    count(distinct rpc_name) as expected_rpc_count,
    count(signature) as signature_count,
    count(*) filter (where authenticated_execute) as authenticated_execute_count,
    count(*) filter (where anon_execute) as anon_execute_count,
    count(*) filter (where public_execute) as public_execute_count,
    count(*) filter (where security_definer) as security_definer_count
  from target_rpc_matches
  group by category, membership_gate
),
auth_profile_trigger as (
  select
    t.tgname as trigger_name,
    n.nspname as table_schema,
    c.relname as table_name,
    fp.signature,
    fp.security_definer,
    fp.has_search_path,
    fp.has_search_path_public,
    fp.public_execute,
    fp.anon_execute,
    fp.authenticated_execute
  from pg_catalog.pg_trigger t
  join pg_catalog.pg_class c
    on c.oid = t.tgrelid
  join pg_catalog.pg_namespace n
    on n.oid = c.relnamespace
  join function_privileges fp
    on fp.oid = t.tgfoid
  where not t.tgisinternal
    and fp.proname = 'handle_new_auth_user_profile'
),
rls_tables as (
  select
    schemaname,
    tablename,
    rowsecurity
  from pg_catalog.pg_tables
  where schemaname = 'public'
    and tablename in (
      'profiles',
      'user_roles',
      'profile_roles',
      'sessions',
      'session_comments',
      'session_applications',
      'player_characters',
      'template_presets',
      'user_notifications',
      'activity_events'
    )
),
policy_counts as (
  select
    schemaname,
    tablename,
    count(*) as policy_count,
    count(*) filter (where roles::text ilike '%anon%') as anon_policy_count,
    count(*) filter (where roles::text ilike '%authenticated%') as authenticated_policy_count
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in (
      'profiles',
      'user_roles',
      'profile_roles',
      'sessions',
      'session_comments',
      'session_applications',
      'player_characters',
      'template_presets',
      'user_notifications',
      'activity_events'
    )
  group by schemaname, tablename
),
direct_write_grants as (
  select
    table_name,
    grantee,
    count(*) as write_grant_count
  from information_schema.table_privileges
  where table_schema = 'public'
    and grantee in ('anon', 'authenticated')
    and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    and table_name in (
      'profiles',
      'user_roles',
      'profile_roles',
      'sessions',
      'session_comments',
      'session_applications',
      'player_characters',
      'template_presets',
      'user_notifications',
      'activity_events'
    )
  group by table_name, grantee
),
summary_rows as (
  select
    10 as sort_order,
    'membership_schema_current_state'::text as check_name,
    case
      when (select count(*) from membership_tables) = 0 then 'info'
      else 'review'
    end as status,
    concat(
      'membership_tables=', (select count(*) from membership_tables),
      ',profile_status_like_columns=', (select membership_status_like_columns from profile_column_summary),
      ',profile_role_like_columns=', (select role_like_columns from profile_column_summary)
    ) as result_value,
    'Use this to decide whether membership state should be added to profiles or kept in a separate community_memberships table.'::text as note

  union all
  select
    20,
    'profile_columns_summary',
    case
      when (select membership_status_like_columns from profile_column_summary) = 0 then 'info'
      else 'review'
    end,
    concat(
      'columns=', column_count,
      ',known_profile_columns=', known_profile_columns,
      ',membership_status_like=', membership_status_like_columns,
      ',role_like=', role_like_columns
    ),
    'Column-count summary only. Full row data and concrete user identifiers are not returned.'
  from profile_column_summary

  union all
  select
    30,
    'public_profiles_membership_exposure',
    case
      when count(*) filter (where column_name ilike '%membership%' or column_name ilike '%role%' or column_name ilike '%status%') = 0 then 'ok'
      else 'review'
    end,
    concat(
      'columns=', count(*),
      ',membership_or_role_like=', count(*) filter (where column_name ilike '%membership%' or column_name ilike '%role%' or column_name ilike '%status%')
    ),
    'public_profiles should not expose membership state unless a later gate explicitly approves that surface.'
  from public_profile_columns

  union all
  select
    40,
    'role_model_current_state',
    case when has_role_storage then 'ok' else 'review' end,
    concat(
      'user_roles=', has_user_roles,
      ',profile_roles=', has_profile_roles,
      ',roles_table=', has_roles_table,
      ',role_tables=', (select count(*) from role_tables),
      ',role_columns=', (select count(*) from role_columns)
    ),
    'Shows whether existing role storage can likely add membership_approver without a new role system.'
  from role_value_checks

  union all
  select
    50,
    'approver_role_feasibility',
    case
      when (select count(*) from function_privileges where proname = 'has_role') > 0
       and (select has_role_storage from role_value_checks)
      then 'ok'
      else 'review'
    end,
    concat(
      'has_role_rpc=', (select count(*) from function_privileges where proname = 'has_role'),
      ',is_admin_rpc=', (select count(*) from function_privileges where proname = 'is_admin'),
      ',role_storage=', (select has_role_storage from role_value_checks)
    ),
    'membership_approver should be added only through reviewed role storage and admin-only grant/revoke RPCs.'

  union all
  select
    60,
    'auth_profile_trigger_state',
    case when count(*) > 0 then 'ok' else 'review' end,
    concat(
      'trigger_refs=', count(*),
      ',security_definer=', count(*) filter (where security_definer),
      ',search_path_public=', count(*) filter (where has_search_path_public),
      ',anon_execute=', count(*) filter (where anon_execute),
      ',authenticated_execute=', count(*) filter (where authenticated_execute)
    ),
    'Used to decide where pending membership rows should be created during signup/profile provisioning.'
  from auth_profile_trigger

  union all
  select
    70,
    'rls_policy_current_summary',
    case
      when count(*) filter (where not rowsecurity) = 0 then 'ok'
      else 'review'
    end,
    concat(
      'tables=', count(*),
      ',rls_disabled=', count(*) filter (where not rowsecurity),
      ',policies=', coalesce((select sum(policy_count) from policy_counts), 0)
    ),
    'Count-only RLS/policy summary for tables that membership gates may touch.'
  from rls_tables

  union all
  select
    80,
    'direct_write_grants_current_summary',
    case when coalesce(sum(write_grant_count), 0) = 0 then 'ok' else 'review' end,
    concat('direct_write_grants=', coalesce(sum(write_grant_count), 0)),
    'Approved-member gating should remain RPC-mediated; direct table writes by web roles should stay closed.'
  from direct_write_grants
),
target_summary_rows as (
  select
    200 + row_number() over (order by category, membership_gate) as sort_order,
    category || '_summary' as check_name,
    case
      when membership_gate = 'approved_required' and signature_count > 0 then 'review'
      when membership_gate = 'pending_allowed_candidate' and signature_count > 0 then 'info'
      when membership_gate = 'trigger_internal' and signature_count > 0 then 'info'
      else 'review'
    end as status,
    concat(
      'expected_rpc=', expected_rpc_count,
      ',signatures=', signature_count,
      ',authenticated_execute=', authenticated_execute_count,
      ',anon_execute=', anon_execute_count,
      ',public_execute=', public_execute_count,
      ',security_definer=', security_definer_count
    ) as result_value,
    case
      when membership_gate = 'approved_required' then 'Candidate RPC group that should receive approved-member server-side gates before public expansion.'
      when membership_gate = 'pending_allowed_candidate' then 'Candidate RPC group to keep available for pending users if needed for review profile completion.'
      when membership_gate = 'approved_required_or_public_read_review' then 'Timeline read requires a visibility decision for pending users.'
      else 'Existing helper or trigger group; review before wiring membership helpers.'
    end as note
  from target_rpc_summary
),
membership_decision_rows as (
  select
    150 as sort_order,
    'approved_gate_required_rpc_summary'::text as check_name,
    'review'::text as status,
    concat(
      'candidate_rpc=', count(distinct rpc_name),
      ',signatures=', count(signature),
      ',authenticated_execute=', count(*) filter (where authenticated_execute),
      ',anon_execute=', count(*) filter (where anon_execute)
    ) as result_value,
    'Summary of existing web-client RPCs that should be reviewed for server-side approved-member gates.'::text as note
  from target_rpc_matches
  where membership_gate in ('approved_required', 'approved_required_or_public_read_review')

  union all
  select
    160,
    'pending_allowed_rpc_candidates',
    'info',
    concat(
      'candidate_rpc=', count(distinct rpc_name),
      ',signatures=', count(signature),
      ',authenticated_execute=', count(*) filter (where authenticated_execute),
      ',anon_execute=', count(*) filter (where anon_execute)
    ),
    'Profile/account basics that may remain available while pending if needed for membership review.'
  from target_rpc_matches
  where membership_gate = 'pending_allowed_candidate'

  union all
  select
    170,
    'admin_only_membership_rpc_candidates',
    'info',
    'planned=grant_approver,revoke_approver,force_status,block_restore,event_log_review',
    'Admin-only membership operations should be created in later apply drafts and should not be delegated to membership_approver.'

  union all
  select
    180,
    'frontend_membership_gate_touchpoints',
    'info',
    'mypage,session-post,session-detail,notifications,timeline,discord-sync,templates,player-characters',
    'Frontend should hide or explain unavailable features, but DB/RPC gates must remain the real enforcement.'
),
target_detail_rows as (
  select
    1000 + row_number() over (order by category, rpc_name, signature) as sort_order,
    'membership_inventory_rpc_' || lpad(row_number() over (order by category, rpc_name, signature)::text, 3, '0') as check_name,
    case
      when signature is null then 'review'
      when membership_gate = 'approved_required' and authenticated_execute then 'review'
      when membership_gate = 'pending_allowed_candidate' then 'info'
      else 'info'
    end as status,
    coalesce(signature, rpc_name || '(not_found)') as result_value,
    concat(
      'category=', category,
      ',gate=', membership_gate,
      ',security_definer=', coalesce(security_definer::text, 'n/a'),
      ',search_path_public=', coalesce(has_search_path_public::text, 'n/a'),
      ',public_execute=', coalesce(public_execute::text, 'n/a'),
      ',anon_execute=', coalesce(anon_execute::text, 'n/a'),
      ',authenticated_execute=', coalesce(authenticated_execute::text, 'n/a')
    ) as note
  from target_rpc_matches
),
next_step_rows as (
  select
    9000 as sort_order,
    'membership_access_inventory_next_step'::text as check_name,
    'review'::text as status,
    case
      when (select count(*) from membership_tables) = 0 then 'prepare_schema_helper_draft_after_review'
      else 'review_existing_membership_schema_before_new_draft'
    end as result_value,
    'Next gate should record this inventory, decide profiles-column versus separate-table membership state, then draft the smallest schema/helper apply.'::text as note
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note from summary_rows
  union all
  select sort_order, check_name, status, result_value, note from membership_decision_rows
  union all
  select sort_order, check_name, status, result_value, note from target_summary_rows
  union all
  select sort_order, check_name, status, result_value, note from target_detail_rows
  union all
  select sort_order, check_name, status, result_value, note from next_step_rows
) as rows
order by sort_order, check_name;
