-- 025_discord_sync_preflight_select_only.sql
-- M-14E-2 select-only preflight for Discord sync DB metadata.
-- Single result-set version for Supabase SQL Editor review.
--
-- Catalog inspection only. This file must not change schema, data, or
-- privileges. Keep actual row values and credential values out of this file
-- and out of pasted review notes.

with
target_rpcs(function_sort, function_name) as (
  values
    (1, 'create_session_post'),
    (2, 'update_session_post'),
    (3, 'delete_session_post')
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
    (14, 'gm_name', 'display GM name')
),
expected_discord_columns(column_sort, check_label, exact_column_name, similar_pattern, expected_note, missing_status) as (
  values
    (1, 'discord_sync_status', 'discord_sync_status', '%discord%sync%status%', 'sync status metadata', 'missing'),
    (2, 'discord_last_action', 'discord_last_action', '%discord%last%action%', 'last requested sync action', 'missing'),
    (3, 'discord_sync_requested_at', 'discord_sync_requested_at', '%discord%sync%requested%', 'sync requested timestamp', 'missing'),
    (4, 'discord_synced_at', 'discord_synced_at', '%discord%synced%at%', 'sync completion timestamp', 'missing'),
    (5, 'discord_sync_error', 'discord_sync_error', '%discord%sync%error%', 'short sync error summary', 'missing'),
    (6, 'discord_message_id equivalent', 'discord_message_id', '%discord%message%id%', 'external post identifier for update/close/delete/resync', 'missing'),
    (7, 'discord_channel_id equivalent', 'discord_channel_id', '%discord%channel%id%', 'external destination channel identifier', 'missing'),
    (8, 'discord_thread_id equivalent', 'discord_thread_id', '%discord%thread%id%', 'external destination thread identifier', 'missing'),
    (9, 'discord_post_url equivalent', 'discord_post_url', '%discord%post%url%', 'public post URL if stored', 'info')
),
expected_helpers(helper_sort, helper_label, signature_text, helper_purpose) as (
  values
    (1, 'has_role', 'public.has_role(text)', 'role helper'),
    (2, 'is_admin', 'public.is_admin()', 'admin helper'),
    (3, 'is_session_gm', 'public.is_session_gm(text)', 'session GM helper')
),
rls_tables(table_sort, table_name) as (
  values
    (1, 'sessions'),
    (2, 'user_roles')
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
    c.column_default
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'sessions'
),
discord_column_matches as (
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
  from expected_discord_columns e
  left join session_columns sc
    on sc.column_name = e.exact_column_name
    or sc.column_name ilike e.similar_pattern
  group by e.column_sort, e.check_label, e.exact_column_name, e.expected_note, e.missing_status
),
required_state_column_summary as (
  select
    count(*) filter (where d.match_count > 0) as present_count,
    count(*) as expected_count,
    coalesce(
      string_agg(d.check_label, ', ' order by d.column_sort) filter (where d.match_count = 0),
      'none'
    ) as missing_labels
  from discord_column_matches d
  where d.column_sort between 1 and 5
),
identifier_column_summary as (
  select
    bool_or(d.column_sort = 6 and d.match_count > 0) as has_message_identifier,
    coalesce(
      string_agg(d.check_label, ', ' order by d.column_sort) filter (where d.column_sort in (6, 7, 8) and d.match_count = 0),
      'none'
    ) as missing_identifier_labels
  from discord_column_matches d
  where d.column_sort in (6, 7, 8)
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
      'not_requested / pending / posted / failed / skipped',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%discord_sync_status%'
          and scc.definition ilike '%not_requested%'
          and scc.definition ilike '%pending%'
          and scc.definition ilike '%posted%'
          and scc.definition ilike '%failed%'
          and scc.definition ilike '%skipped%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%discord_sync_status%'
      ), 'not found'),
      'Catalog check only; values should support request, success, failure, and skipped states.'
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
      'Catalog check only; action values should align with Edge Function design.'
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
          and scc.definition ilike '%tentative%'
          and scc.definition ilike '%recruiting%'
          and scc.definition ilike '%full%'
          and scc.definition ilike '%closed%'
          and scc.definition ilike '%finished%'
          and scc.definition ilike '%canceled%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%status%'
          and definition not ilike '%discord_sync_status%'
      ), 'not found'),
      'Posting status controls whether a session is eligible for external sync.'
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
      'Visibility controls whether a session should be posted or skipped.'
    ),
    (
      5,
      'session_type allowed values',
      'one-shot / campaign / special / other',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%session_type%'
          and scc.definition ilike '%one-shot%'
          and scc.definition ilike '%campaign%'
          and scc.definition ilike '%special%'
          and scc.definition ilike '%other%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%session_type%'
      ), 'not found'),
      'Session type is used when building public post text.'
    ),
    (
      6,
      'public draft guard',
      'handled by RPC/UI or an explicit DB constraint',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%visibility%'
          and scc.definition ilike '%status%'
          and scc.definition ilike '%draft%'
          and scc.definition ilike '%public%'
      ),
      coalesce((
        select string_agg(conname, ' | ' order by conname)
        from session_check_constraints
        where definition ilike '%visibility%'
          and definition ilike '%status%'
      ), 'not found'),
      'Info checkpoint: if no DB constraint exists, keep RPC/UI smoke coverage.'
    )
),
target_rpc_matches as (
  select
    tr.function_sort,
    tr.function_name,
    p.oid,
    p.oid::regprocedure::text as signature,
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
    p.proname
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
rls_summary as (
  select
    rt.table_sort,
    rt.table_name,
    c.relrowsecurity,
    c.relforcerowsecurity,
    c.oid is not null as table_exists
  from rls_tables rt
  left join pg_catalog.pg_class c
    on c.oid = to_regclass('public.' || rt.table_name)
),
policy_summary as (
  select
    rt.table_sort,
    rt.table_name,
    count(p.policyname) as policy_count,
    coalesce(string_agg(distinct p.cmd, ', ' order by p.cmd), 'none') as commands_summary,
    coalesce(string_agg(distinct array_to_string(p.roles, ','), ', ' order by array_to_string(p.roles, ',')), 'none') as roles_summary
  from rls_tables rt
  left join pg_catalog.pg_policies p
    on p.schemaname = 'public'
   and p.tablename = rt.table_name
  group by rt.table_sort, rt.table_name
),
checks as (
  select
    10::integer as sort_order,
    '01_sessions_table'::text as section,
    'sessions table exists'::text as check_name,
    'public.sessions exists'::text as expected,
    case when table_regclass is not null then 'ok' else 'missing' end::text as status,
    coalesce(table_regclass::text, 'not found')::text as result_value,
    'Catalog table existence only.'::text as notes
  from sessions_table

  union all
  select
    (20 + c.column_sort)::integer,
    '02_sessions_core_columns',
    ('sessions.' || c.column_name),
    c.expected_note,
    case when sc.column_name is not null then 'ok' else 'missing' end,
    coalesce(sc.udt_name || ', nullable=' || sc.is_nullable, 'not found'),
    'Column metadata only; no row values are selected.'
  from expected_core_columns c
  left join session_columns sc
    on sc.column_name = c.column_name

  union all
  select
    (50 + d.column_sort)::integer,
    '03_discord_sync_columns',
    d.check_label,
    d.expected_note,
    case
      when d.match_count > 0 then 'ok'
      else d.missing_status
    end,
    d.match_summary,
    case
      when d.has_exact_column then 'Exact column found.'
      when d.match_count > 0 then 'Similar column name found; review naming before implementation.'
      else 'No matching column found.'
    end
  from discord_column_matches d

  union all
  select
    70,
    '04_state_column_summary',
    'baseline state columns',
    'sync status/action/request/completion/error columns exist',
    case when present_count = expected_count then 'ok' else 'missing' end,
    present_count::text || '/' || expected_count::text || ' present',
    'Missing: ' || missing_labels
  from required_state_column_summary

  union all
  select
    71,
    '04_state_column_summary',
    'message identifier readiness',
    'external post identifier exists for update/close/delete/resync',
    case when has_message_identifier then 'ok' else 'missing' end,
    'has_message_identifier=' || has_message_identifier::text,
    'Missing identifier candidates: ' || missing_identifier_labels
  from identifier_column_summary

  union all
  select
    (80 + cc.check_sort)::integer,
    '05_check_constraints',
    cc.check_name,
    cc.expected_text,
    case
      when cc.check_sort = 6 then 'info'
      when cc.is_ok then 'ok'
      else 'missing'
    end,
    cc.result_value,
    cc.notes
  from constraint_checks cc

  union all
  select
    (100 + r.table_sort)::integer,
    '06_rls_enabled',
    (r.table_name || ' rls enabled'),
    'RLS enabled where required by existing design',
    case
      when not r.table_exists then 'missing'
      when r.relrowsecurity then 'ok'
      else 'check'
    end,
    case
      when not r.table_exists then 'not found'
      else 'relrowsecurity=' || r.relrowsecurity::text
    end,
    'relforcerowsecurity=' || coalesce(r.relforcerowsecurity::text, 'n/a')
  from rls_summary r

  union all
  select
    (110 + p.table_sort)::integer,
    '07_policy_summary',
    (p.table_name || ' policy summary'),
    'existing policies are visible for review',
    case when p.policy_count > 0 then 'info' else 'none' end,
    (
      'policy_count=' || p.policy_count::text
      || ', commands=' || p.commands_summary
      || ', roles=' || p.roles_summary
    ),
    'Policy expressions are not expanded here to keep the result compact.'
  from policy_summary p

  union all
  select
    (130 + s.function_sort)::integer,
    '08_rpc_existence',
    (s.function_name || ' exists'),
    'function exists in public schema',
    case when s.function_count > 0 then 'ok' else 'missing' end,
    s.function_count::text || ' function(s); ' || s.signature_summary,
    'Result type: ' || s.result_summary
  from target_rpc_summary s

  union all
  select
    (140 + s.function_sort)::integer,
    '09_rpc_security_definer',
    (s.function_name || ' security_definer'),
    'all matching functions are security definer',
    case
      when s.function_count = 0 then 'missing'
      when s.all_security_definer then 'ok'
      else 'check'
    end,
    s.all_security_definer::text,
    s.signature_summary
  from target_rpc_summary s

  union all
  select
    (150 + s.function_sort)::integer,
    '10_rpc_search_path',
    (s.function_name || ' search_path'),
    'search_path is explicitly configured',
    case
      when s.function_count = 0 then 'missing'
      when s.all_have_search_path then 'ok'
      else 'check'
    end,
    s.all_have_search_path::text,
    s.signature_summary
  from target_rpc_summary s

  union all
  select
    (160 + p.function_sort)::integer,
    '11_rpc_authenticated_execute',
    (p.function_name || ' authenticated execute'),
    'authenticated can execute',
    case when p.authenticated_execute then 'ok' else 'check' end,
    p.authenticated_execute::text,
    'ACL-based catalog check.'
  from target_rpc_privileges p

  union all
  select
    (170 + p.function_sort)::integer,
    '12_rpc_anon_execute',
    (p.function_name || ' anon execute'),
    'anon cannot execute',
    case when p.anon_execute then 'check' else 'ok' end,
    p.anon_execute::text,
    'ACL-based catalog check.'
  from target_rpc_privileges p

  union all
  select
    (180 + p.function_sort)::integer,
    '13_rpc_public_execute',
    (p.function_name || ' public execute'),
    'PUBLIC cannot execute',
    case when p.public_execute then 'check' else 'ok' end,
    p.public_execute::text,
    'ACL-based catalog check; PUBLIC means the database pseudo-role.'
  from target_rpc_privileges p

  union all
  select
    190,
    '14_sync_related_rpc_scan',
    'public functions with discord/sync/resync in name',
    'review whether sync-state or resync RPC already exists',
    case when function_count > 0 then 'info' else 'missing' end,
    function_count::text || ' function(s)',
    signatures
  from sync_related_function_summary

  union all
  select
    191,
    '14_sync_related_rpc_scan',
    'resync-specific public functions',
    'review whether a resync RPC already exists',
    case when function_count > 0 then 'info' else 'missing' end,
    function_count::text || ' function(s)',
    signatures
  from resync_function_summary

  union all
  select
    (200 + h.helper_sort)::integer,
    '15_role_helpers',
    h.helper_label,
    h.helper_purpose || ' exists',
    case when h.resolved_signature is not null then 'ok' else 'missing' end,
    coalesce(h.resolved_signature::text, 'not found'),
    (
      'security_definer=' || coalesce(h.security_definer::text, 'n/a')
      || ', search_path=' || coalesce(h.has_search_path_config::text, 'n/a')
    )
  from helper_security h

  union all
  select
    210,
    '16_user_roles_table',
    'user_roles table exists',
    'public.user_roles exists if app roles are table-backed',
    case when table_regclass is not null then 'ok' else 'check' end,
    coalesce(table_regclass::text, 'not found'),
    'admin remains an application role and is separate from server-side elevated DB access.'
  from user_roles_table

  union all
  select
    220,
    '17_edge_function_db_update_checkpoint',
    'server-side DB update path',
    'implementation must choose a safe server-side write path',
    'info',
    'design checkpoint only',
    'Confirm in later phases whether Edge Function updates sessions directly or calls a reviewed RPC; no DB change in this preflight.'

  union all
  select
    230,
    '18_static_json_scope',
    'static JSON source handling',
    'manual frontend/docs check',
    'info',
    'not a DB catalog item',
    'Static JSON-origin sessions are outside DB RPC and Discord sync targets; verify via frontend merge and browser QA.'

  union all
  select
    240,
    '19_initial_readiness_judgment',
    'existing sync columns enough for first implementation',
    'state columns plus external post identifier should exist',
    case
      when r.present_count = r.expected_count and i.has_message_identifier then 'ok'
      when r.present_count = r.expected_count and not i.has_message_identifier then 'missing'
      else 'missing'
    end,
    (
      'state_columns=' || r.present_count::text || '/' || r.expected_count::text
      || ', has_message_identifier=' || i.has_message_identifier::text
    ),
    case
      when r.present_count = r.expected_count and i.has_message_identifier
        then 'Existing columns may be enough to proceed to Edge Function draft, pending manual review.'
      when r.present_count = r.expected_count and not i.has_message_identifier
        then 'State columns exist, but update/close/delete/resync likely need an external post identifier column before implementation.'
      else 'Baseline state columns are missing; review DB column draft need before implementation.'
    end
  from required_state_column_summary r
  cross join identifier_column_summary i
)
select
  sort_order,
  section,
  check_name,
  expected,
  status,
  result_value,
  notes
from checks
order by sort_order, section, check_name;

