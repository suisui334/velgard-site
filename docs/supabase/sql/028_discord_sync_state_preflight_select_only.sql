-- 028_discord_sync_state_preflight_select_only.sql
-- M-14E-16A select-only preflight for Discord sync DB state.
-- Single result-set version for Supabase SQL Editor review.
--
-- Catalog inspection only. This file must not alter schema, data, or
-- privileges. Keep actual row values, credential values, external post
-- identifiers, and project identifiers out of this file and out of pasted
-- review notes.
-- Keep result labels and SQL string literals ASCII-only to reduce paste and
-- encoding risk.

with
target_rpcs(function_sort, function_name) as (
  values
    (1, 'create_session_post'),
    (2, 'update_session_post'),
    (3, 'delete_session_post')
),
expected_sync_columns(column_sort, check_label, exact_column_name, similar_pattern, expected_note, missing_status) as (
  values
    (1, 'discord_message_id', 'discord_message_id', '%discord%message%id%', 'external post identifier for create double-post prevention and later update/delete', 'missing'),
    (2, 'discord_channel_id', 'discord_channel_id', '%discord%channel%id%', 'stored destination channel identifier if available', 'info'),
    (3, 'discord_thread_id', 'discord_thread_id', '%discord%thread%id%', 'stored destination thread identifier if available', 'info'),
    (4, 'discord_post_url', 'discord_post_url', '%discord%post%url%', 'stored external post URL if available', 'info'),
    (5, 'discord_sync_status', 'discord_sync_status', '%discord%sync%status%', 'sync state such as not synced, synced, failed, pending, or skipped', 'missing'),
    (6, 'discord_last_action', 'discord_last_action', '%discord%last%action%', 'last sync action such as create, update, close, delete, or resync', 'missing'),
    (7, 'discord_sync_requested_at', 'discord_sync_requested_at', '%discord%sync%requested%at%', 'timestamp for requested sync if used', 'info'),
    (8, 'discord_synced_at', 'discord_synced_at', '%discord%synced%at%', 'timestamp for last successful sync', 'missing'),
    (9, 'discord_sync_error', 'discord_sync_error', '%discord%sync%error%', 'generalized sync error summary', 'info'),
    (10, 'discord_last_synced_at candidate', 'discord_last_synced_at', '%discord%synced%at%', 'alternative last synced timestamp name; existing discord_synced_at may be enough', 'info'),
    (11, 'discord_sync_error_at candidate', 'discord_sync_error_at', '%discord%sync%error%at%', 'timestamp for last sync error if separate tracking is needed', 'info'),
    (12, 'discord_sync_attempted_at candidate', 'discord_sync_attempted_at', '%discord%sync%attempt%', 'timestamp for last sync attempt if separate tracking is needed', 'info'),
    (13, 'discord_webhook_kind candidate', 'discord_webhook_kind', '%discord%webhook%kind%', 'target kind for test or production webhook if needed', 'info'),
    (14, 'discord_target_kind candidate', 'discord_target_kind', '%discord%target%kind%', 'target kind for single channel or future routing if needed', 'info')
),
expected_core_columns(column_sort, column_name, expected_note) as (
  values
    (1, 'id', 'public session id'),
    (2, 'title', 'session title'),
    (3, 'summary', 'public summary'),
    (4, 'status', 'posting status'),
    (5, 'visibility', 'visibility'),
    (6, 'session_type', 'posting type'),
    (7, 'date', 'start date'),
    (8, 'start_time', 'start time'),
    (9, 'end_time', 'same-day end time fallback'),
    (10, 'end_at', 'full end timestamp'),
    (11, 'application_deadline', 'application deadline'),
    (12, 'player_min', 'minimum players'),
    (13, 'player_max', 'maximum players'),
    (14, 'gm_name', 'display GM name'),
    (15, 'session_tool', 'session tool display value')
),
expected_helpers(helper_sort, helper_label, signature_text, helper_purpose) as (
  values
    (1, 'has_role', 'public.has_role(text)', 'role helper'),
    (2, 'is_admin', 'public.is_admin()', 'admin helper'),
    (3, 'is_session_gm', 'public.is_session_gm(text)', 'session GM helper')
),
roles as (
  select
    to_regrole('authenticated') as authenticated_role,
    to_regrole('anon') as anon_role
),
sessions_table as (
  select
    to_regclass('public.sessions') as table_regclass
),
session_columns as (
  select
    c.column_name,
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default,
    c.ordinal_position
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'sessions'
),
core_column_matches as (
  select
    e.column_sort,
    e.column_name,
    e.expected_note,
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default
  from expected_core_columns e
  left join session_columns c
    on c.column_name = e.column_name
),
core_column_summary as (
  select
    count(*) filter (where c.udt_name is not null) as present_count,
    count(*) as expected_count,
    coalesce(
      string_agg(c.column_name, ', ' order by c.column_sort) filter (where c.udt_name is null),
      'none'
    ) as missing_columns
  from core_column_matches c
),
sync_column_matches as (
  select
    e.column_sort,
    e.check_label,
    e.exact_column_name,
    e.expected_note,
    e.missing_status,
    bool_or(sc.column_name = e.exact_column_name) as has_exact_column,
    count(sc.column_name) filter (
      where sc.column_name = e.exact_column_name
         or sc.column_name ilike e.similar_pattern
    ) as match_count,
    coalesce(
      string_agg(
        sc.column_name || ':' || sc.udt_name || ', nullable=' || sc.is_nullable,
        ' | ' order by sc.column_name
      ) filter (
        where sc.column_name = e.exact_column_name
           or sc.column_name ilike e.similar_pattern
      ),
      'not found'
    ) as match_summary
  from expected_sync_columns e
  left join session_columns sc
    on sc.column_name = e.exact_column_name
    or sc.column_name ilike e.similar_pattern
  group by e.column_sort, e.check_label, e.exact_column_name, e.expected_note, e.missing_status
),
required_sync_summary as (
  select
    count(*) filter (where d.match_count > 0) as present_count,
    count(*) as expected_count,
    coalesce(
      string_agg(d.check_label, ', ' order by d.column_sort) filter (where d.match_count = 0),
      'none'
    ) as missing_labels
  from sync_column_matches d
  where d.column_sort in (1, 5, 6, 8)
),
optional_sync_summary as (
  select
    count(*) filter (where d.match_count > 0) as present_count,
    count(*) as expected_count,
    coalesce(
      string_agg(d.check_label, ', ' order by d.column_sort) filter (where d.match_count = 0),
      'none'
    ) as missing_labels
  from sync_column_matches d
  where d.column_sort not in (1, 5, 6, 8)
),
public_related_columns as (
  select
    c.table_name,
    c.column_name,
    c.udt_name,
    c.is_nullable
  from information_schema.columns c
  where c.table_schema = 'public'
    and (
      c.column_name ilike '%discord%'
      or c.column_name ilike '%sync%'
      or c.column_name ilike '%message%id%'
      or c.column_name ilike '%webhook%'
      or c.column_name ilike '%target%kind%'
    )
),
public_related_column_summary as (
  select
    count(*) as match_count,
    coalesce(
      left(
        string_agg(
          table_name || '.' || column_name || ':' || udt_name || ', nullable=' || is_nullable,
          ' | ' order by table_name, column_name
        ),
        1200
      ),
      'not found'
    ) as match_summary
  from public_related_columns
),
session_check_constraints as (
  select
    con.conname,
    pg_catalog.pg_get_constraintdef(con.oid) as definition
  from pg_catalog.pg_constraint con
  where con.conrelid = to_regclass('public.sessions')
    and con.contype = 'c'
),
constraint_checks(check_sort, check_name, expected_text, is_ok, result_value, notes) as (
  values
    (
      1,
      'discord_sync_status allowed values',
      'state values suitable for not synced, synced, failed, pending, or skipped',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%discord_sync_status%'
          and scc.definition ilike '%failed%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%discord_sync_status%'
      ), 'not found'),
      'Map exact application state labels after reviewing existing allowed values.'
    ),
    (
      2,
      'discord_last_action allowed values',
      'create / update / close / delete / resync',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%discord_last_action%'
          and scc.definition ilike '%create%'
          and scc.definition ilike '%update%'
          and scc.definition ilike '%close%'
          and scc.definition ilike '%delete%'
          and scc.definition ilike '%resync%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%discord_last_action%'
      ), 'not found'),
      'Action values should align with Edge Function actions.'
    ),
    (
      3,
      'posting status allowed values',
      'draft / tentative / recruiting / full / closed / finished / canceled',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%status%'
          and scc.definition not ilike '%discord_sync_status%'
          and scc.definition ilike '%draft%'
          and scc.definition ilike '%recruiting%'
          and scc.definition ilike '%canceled%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%status%'
          and definition not ilike '%discord_sync_status%'
      ), 'not found'),
      'Posting status controls sync eligibility.'
    ),
    (
      4,
      'visibility allowed values',
      'public / private / hidden',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%visibility%'
          and scc.definition ilike '%public%'
          and scc.definition ilike '%private%'
          and scc.definition ilike '%hidden%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%visibility%'
      ), 'not found'),
      'Visibility controls sync eligibility and skip behavior.'
    )
),
target_rpc_matches as (
  select
    tr.function_sort,
    tr.function_name,
    p.oid,
    p.oid::regprocedure::text as signature,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments_text,
    pg_catalog.pg_get_function_result(p.oid) as result_type,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config,
    p.proacl,
    p.proowner
  from target_rpcs tr
  left join pg_catalog.pg_proc p
    on p.proname = tr.function_name
  left join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
   and n.nspname = 'public'
  where p.oid is null
     or n.nspname = 'public'
),
target_rpc_summary as (
  select
    tr.function_sort,
    tr.function_name,
    count(m.oid) as function_count,
    coalesce(string_agg(m.signature, ' | ' order by m.signature), 'not found') as signature_summary,
    coalesce(string_agg(m.result_type, ' | ' order by m.signature), 'not found') as result_summary,
    coalesce(bool_and(m.security_definer) filter (where m.oid is not null), false) as all_security_definer,
    coalesce(bool_and(m.has_search_path_config) filter (where m.oid is not null), false) as all_have_search_path
  from target_rpcs tr
  left join target_rpc_matches m
    on m.function_sort = tr.function_sort
   and m.oid is not null
  group by tr.function_sort, tr.function_name
),
target_rpc_acl as (
  select
    m.function_sort,
    m.function_name,
    m.oid,
    acl.grantee,
    acl.privilege_type
  from target_rpc_matches m
  join lateral pg_catalog.aclexplode(coalesce(m.proacl, pg_catalog.acldefault('f', m.proowner))) acl
    on true
  where m.oid is not null
),
target_rpc_privileges as (
  select
    tr.function_sort,
    tr.function_name,
    coalesce(bool_or(a.grantee = r.authenticated_role and a.privilege_type = 'EXECUTE'), false) as authenticated_execute,
    coalesce(bool_or(a.grantee = r.anon_role and a.privilege_type = 'EXECUTE'), false) as anon_execute,
    coalesce(bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE'), false) as public_execute
  from target_rpcs tr
  cross join roles r
  left join target_rpc_acl a
    on a.function_sort = tr.function_sort
  group by tr.function_sort, tr.function_name
),
sync_related_functions as (
  select
    p.oid::regprocedure::text as signature,
    p.proname,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (
      p.proname ilike '%discord%'
      or p.proname ilike '%sync%'
      or p.proname ilike '%resync%'
    )
),
sync_related_function_summary as (
  select
    count(*) as function_count,
    coalesce(string_agg(signature, ' | ' order by signature), 'not found') as signatures
  from sync_related_functions
),
resync_function_summary as (
  select
    count(*) as function_count,
    coalesce(string_agg(signature, ' | ' order by signature), 'not found') as signatures
  from sync_related_functions
  where proname ilike '%resync%'
),
expected_helper_matches as (
  select
    eh.helper_sort,
    eh.helper_label,
    eh.signature_text,
    eh.helper_purpose,
    to_regprocedure(eh.signature_text) as resolved_signature
  from expected_helpers eh
),
helper_security as (
  select
    ehm.helper_sort,
    ehm.helper_label,
    ehm.signature_text,
    ehm.helper_purpose,
    ehm.resolved_signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config
  from expected_helper_matches ehm
  left join pg_catalog.pg_proc p
    on p.oid = ehm.resolved_signature
),
user_roles_table as (
  select
    to_regclass('public.user_roles') as table_regclass
),
rls_tables(table_sort, table_name) as (
  values
    (1, 'sessions'),
    (2, 'user_roles')
),
rls_summary as (
  select
    rt.table_sort,
    rt.table_name,
    c.relrowsecurity,
    c.relforcerowsecurity
  from rls_tables rt
  left join pg_catalog.pg_class c
    on c.oid = to_regclass('public.' || rt.table_name)
  left join pg_catalog.pg_namespace n
    on n.oid = c.relnamespace
   and n.nspname = 'public'
),
policy_summary as (
  select
    schemaname,
    tablename,
    count(*) as policy_count,
    coalesce(
      string_agg(
        policyname || ':' || cmd || ':' || array_to_string(roles, '+'),
        ' | ' order by policyname
      ),
      'not found'
    ) as policies
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in ('sessions', 'user_roles')
  group by schemaname, tablename
),
readiness as (
  select
    exists (select 1 from sync_column_matches where exact_column_name = 'discord_message_id' and match_count > 0) as has_message_id,
    exists (select 1 from sync_column_matches where exact_column_name = 'discord_sync_status' and match_count > 0) as has_sync_status,
    exists (select 1 from sync_column_matches where exact_column_name = 'discord_last_action' and match_count > 0) as has_last_action,
    exists (select 1 from sync_column_matches where exact_column_name = 'discord_synced_at' and match_count > 0) as has_synced_at
)
select
  10::integer as sort_order,
  '01_table'::text as section,
  'public.sessions exists'::text as check_name,
  'sessions table exists'::text as expected,
  case when st.table_regclass is not null then 'ok' else 'missing' end::text as status,
  coalesce(st.table_regclass::text, 'not found')::text as result_value,
  'Target table for session posting and Discord sync state.'::text as notes
from sessions_table st

union all

select
  (20 + c.column_sort)::integer,
  '02_core_columns',
  ('sessions core column ' || c.column_name),
  c.expected_note,
  case when c.udt_name is not null then 'ok' else 'missing' end,
  coalesce(c.udt_name || ', nullable=' || c.is_nullable, 'not found'),
  'Core column check; no row data is selected.'
from core_column_matches c

union all

select
  40,
  '02_core_columns',
  'core column summary',
  'expected core columns are present',
  case when c.present_count = c.expected_count then 'ok' else 'missing' end,
  (c.present_count::text || '/' || c.expected_count::text || ' present'),
  ('missing=' || c.missing_columns)
from core_column_summary c

union all

select
  (60 + d.column_sort)::integer,
  '03_sync_columns',
  d.check_label,
  d.expected_note,
  case
    when d.match_count > 0 then 'ok'
    else d.missing_status
  end,
  d.match_summary,
  case
    when d.has_exact_column then 'Exact column found.'
    when d.match_count > 0 then 'Similar column found; review name before coding.'
    else 'Column not found in catalog result.'
  end
from sync_column_matches d

union all

select
  90,
  '03_sync_columns',
  'required sync column summary',
  'message id, sync status, last action, synced timestamp',
  case when r.present_count = r.expected_count then 'ok' else 'missing' end,
  (r.present_count::text || '/' || r.expected_count::text || ' present'),
  ('missing=' || r.missing_labels)
from required_sync_summary r

union all

select
  91,
  '03_sync_columns',
  'optional sync column summary',
  'channel/thread/post url/error/attempt/target metadata candidates',
  'info',
  (o.present_count::text || '/' || o.expected_count::text || ' present'),
  ('missing=' || o.missing_labels)
from optional_sync_summary o

union all

select
  92,
  '03_sync_columns',
  'public related discord columns',
  'summary of public catalog columns matching sync-related names',
  'info',
  pr.match_count::text,
  pr.match_summary
from public_related_column_summary pr

union all

select
  (110 + cc.check_sort)::integer,
  '04_constraints',
  cc.check_name,
  cc.expected_text,
  case when cc.is_ok then 'ok' else 'check' end,
  cc.result_value,
  cc.notes
from constraint_checks cc

union all

select
  (140 + r.function_sort)::integer,
  '05_rpc_presence',
  r.function_name,
  'target session posting RPC exists',
  case when r.function_count > 0 then 'ok' else 'missing' end,
  r.signature_summary,
  ('result=' || r.result_summary)
from target_rpc_summary r

union all

select
  (150 + r.function_sort)::integer,
  '06_rpc_security',
  (r.function_name || ' security_definer'),
  'security_definer true',
  case when r.function_count > 0 and r.all_security_definer then 'ok' else 'check' end,
  r.all_security_definer::text,
  'Review before adding DB update behavior.'
from target_rpc_summary r

union all

select
  (160 + r.function_sort)::integer,
  '06_rpc_security',
  (r.function_name || ' search_path'),
  'search_path explicitly configured',
  case when r.function_count > 0 and r.all_have_search_path then 'ok' else 'check' end,
  r.all_have_search_path::text,
  'Search path should remain explicit for security-definer functions.'
from target_rpc_summary r

union all

select
  (170 + p.function_sort)::integer,
  '07_rpc_execute',
  (p.function_name || ' authenticated execute'),
  'authenticated can execute',
  case when p.authenticated_execute then 'ok' else 'check' end,
  p.authenticated_execute::text,
  'Authenticated GM/admin flows depend on this permission.'
from target_rpc_privileges p

union all

select
  (180 + p.function_sort)::integer,
  '07_rpc_execute',
  (p.function_name || ' anon execute'),
  'anon cannot execute',
  case when p.anon_execute then 'check' else 'ok' end,
  p.anon_execute::text,
  'Anon should not execute management RPCs.'
from target_rpc_privileges p

union all

select
  (190 + p.function_sort)::integer,
  '07_rpc_execute',
  (p.function_name || ' public execute'),
  'PUBLIC cannot execute',
  case when p.public_execute then 'check' else 'ok' end,
  p.public_execute::text,
  'PUBLIC should not execute management RPCs.'
from target_rpc_privileges p

union all

select
  210,
  '08_sync_functions',
  'public functions with discord/sync/resync in name',
  'scan for existing sync helpers',
  'info',
  s.function_count::text,
  s.signatures
from sync_related_function_summary s

union all

select
  211,
  '08_sync_functions',
  'resync-specific public functions',
  'resync helper may not exist yet',
  case when s.function_count > 0 then 'ok' else 'missing' end,
  s.function_count::text,
  s.signatures
from resync_function_summary s

union all

select
  (230 + h.helper_sort)::integer,
  '09_helpers',
  h.helper_label,
  h.signature_text,
  case when h.resolved_signature is not null then 'ok' else 'missing' end,
  coalesce(h.resolved_signature::text, 'not found'),
  h.helper_purpose
from helper_security h

union all

select
  240,
  '09_helpers',
  'public.user_roles',
  'user_roles table exists',
  case when u.table_regclass is not null then 'ok' else 'missing' end,
  coalesce(u.table_regclass::text, 'not found'),
  'Admin is an application role concept; do not confuse with service role.'
from user_roles_table u

union all

select
  (260 + r.table_sort)::integer,
  '10_rls',
  (r.table_name || ' RLS enabled'),
  'RLS enabled',
  case when r.relrowsecurity then 'ok' else 'check' end,
  ('rls=' || coalesce(r.relrowsecurity::text, 'null') || ', force_rls=' || coalesce(r.relforcerowsecurity::text, 'null')),
  'RLS should remain enabled.'
from rls_summary r

union all

select
  (280 + row_number() over (order by p.tablename))::integer,
  '11_policy_summary',
  (p.tablename || ' policy summary'),
  'policy names and commands only',
  'info',
  p.policy_count::text,
  p.policies
from policy_summary p

union all

select
  310,
  '12_readiness',
  'create double-post prevention readiness',
  'message identifier exists before enabling production create',
  case when r.has_message_id then 'ok' else 'missing' end,
  ('has_message_id=' || r.has_message_id::text),
  'If an external post identifier already exists, action=create should be rejected or routed to update/resync.'
from readiness r

union all

select
  311,
  '12_readiness',
  'sync state update readiness',
  'sync status, last action, and synced timestamp exist',
  case when r.has_sync_status and r.has_last_action and r.has_synced_at then 'ok' else 'missing' end,
  (
    'has_sync_status=' || r.has_sync_status::text ||
    ', has_last_action=' || r.has_last_action::text ||
    ', has_synced_at=' || r.has_synced_at::text
  ),
  'DB update should happen only after Discord send success.'
from readiness r

union all

select
  312,
  '12_readiness',
  'Discord success but DB update failure handling',
  'must separate Discord send result from DB update result',
  'info',
  'manual review required',
  'If Discord send succeeds but DB update fails, rerunning create risks duplicate posts; design repair/resync flow.'

union all

select
  313,
  '12_readiness',
  'production channel switch gate',
  'do not switch production until DB update and double-post prevention are ready',
  'info',
  'gate remains closed',
  'Production channel switch should wait for DB update linkage, identifier storage, double-post prevention, and reviewed runbook.'

order by sort_order, section, check_name;
