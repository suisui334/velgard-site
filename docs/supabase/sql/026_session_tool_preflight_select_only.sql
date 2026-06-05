-- 026_session_tool_preflight_select_only.sql
-- M-14E-15B select-only preflight for adding session_tool.
-- Single result-set version for Supabase SQL Editor review.
--
-- Catalog inspection only. This file must not alter schema, data, or
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
session_tool_column_candidates(candidate_sort, column_name, expected_note) as (
  values
    (1, 'session_tool', 'preferred internal column name for display label 開催場所'),
    (2, 'play_location', 'alternative name; may be confused with physical place'),
    (3, 'venue', 'alternative name; physical venue nuance is stronger'),
    (4, 'session_place', 'alternative name; close to Japanese label but less precise')
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
tables_to_check(table_sort, table_name) as (
  values
    (1, 'sessions'),
    (2, 'session_posts')
),
table_presence as (
  select
    t.table_sort,
    t.table_name,
    to_regclass('public.' || t.table_name) as table_regclass
  from tables_to_check t
),
session_columns as (
  select
    c.table_name,
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
session_tool_candidate_matches as (
  select
    e.candidate_sort,
    e.column_name,
    e.expected_note,
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default
  from session_tool_column_candidates e
  left join session_columns c
    on c.column_name = e.column_name
),
public_related_columns as (
  select
    c.table_schema,
    c.table_name,
    c.column_name,
    c.udt_name,
    c.is_nullable
  from information_schema.columns c
  where c.table_schema = 'public'
    and (
      c.column_name ilike '%session%tool%'
      or c.column_name ilike '%tool%'
      or c.column_name ilike '%venue%'
      or c.column_name ilike '%place%'
      or c.column_name ilike '%location%'
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
        800
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
session_tool_constraint_summary as (
  select
    count(*) as match_count,
    coalesce(
      string_agg(conname, ' | ' order by conname),
      'not found'
    ) as constraint_names
  from session_check_constraints
  where definition ilike '%session_tool%'
     or definition ilike '%play_location%'
     or definition ilike '%venue%'
     or definition ilike '%session_place%'
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
    coalesce(string_agg(m.arguments_text, ' | ' order by m.signature), 'not found') as arguments_summary,
    coalesce(string_agg(m.result_type, ' | ' order by m.signature), 'not found') as result_summary,
    coalesce(bool_and(m.security_definer) filter (where m.oid is not null), false) as all_security_definer,
    coalesce(bool_and(m.has_search_path_config) filter (where m.oid is not null), false) as all_have_search_path,
    coalesce(bool_or(m.arguments_text ilike '%session_tool%') filter (where m.oid is not null), false) as has_session_tool_argument,
    coalesce(bool_or(m.result_type ilike '%session_tool%') filter (where m.oid is not null), false) as has_session_tool_result
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
public_session_function_scan as (
  select
    p.oid::regprocedure::text as signature,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments_text,
    pg_catalog.pg_get_function_result(p.oid) as result_type
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (
      p.proname ilike '%session%post%'
      or p.proname ilike '%session%detail%'
      or p.proname ilike '%session%list%'
      or pg_catalog.pg_get_function_arguments(p.oid) ilike '%session_tool%'
      or pg_catalog.pg_get_function_result(p.oid) ilike '%session_tool%'
      or pg_catalog.pg_get_function_arguments(p.oid) ilike '%venue%'
      or pg_catalog.pg_get_function_result(p.oid) ilike '%venue%'
    )
),
public_session_function_summary as (
  select
    count(*) as function_count,
    coalesce(
      left(
        string_agg(signature, ' | ' order by signature),
        900
      ),
      'not found'
    ) as signature_summary,
    count(*) filter (
      where arguments_text ilike '%session_tool%'
         or result_type ilike '%session_tool%'
    ) as session_tool_related_count
  from public_session_function_scan
),
helper_matches as (
  select
    eh.helper_sort,
    eh.helper_label,
    eh.signature_text,
    eh.helper_purpose,
    to_regprocedure(eh.signature_text) as helper_regprocedure
  from expected_helpers eh
),
session_rls as (
  select
    c.relrowsecurity,
    c.relforcerowsecurity
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'sessions'
),
session_policy_summary as (
  select
    count(*) as policy_count,
    coalesce(
      left(
        string_agg(policyname || ':' || cmd || ':' || array_to_string(roles, '+'), ' | ' order by policyname),
        800
      ),
      'not found'
    ) as policy_summary
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename = 'sessions'
),
results as (
  select
    10 as sort_order,
    '01_table' as section,
    'public.sessions exists' as check_name,
    'public.sessions should be the canonical session posting table' as expected,
    case when table_regclass is not null then 'ok' else 'missing' end as status,
    coalesce(table_regclass::text, 'not found') as result_value,
    'If missing, stop and re-check the session posting schema history.' as notes
  from table_presence
  where table_name = 'sessions'

  union all

  select
    11,
    '01_table',
    'public.session_posts exists',
    'info only; current design expects public.sessions',
    case when table_regclass is not null then 'check' else 'info' end,
    coalesce(table_regclass::text, 'not found'),
    'If this exists, review whether session_tool belongs there or in public.sessions.'
  from table_presence
  where table_name = 'session_posts'

  union all

  select
    20,
    '02_core_columns',
    'sessions core column coverage',
    'core session posting columns are present',
    case when present_count = expected_count then 'ok' else 'check' end,
    present_count::text || '/' || expected_count::text || ' present; missing=' || missing_columns,
    'Confirms this preflight is looking at the expected table shape.'
  from core_column_summary

  union all

  select
    30 + candidate_sort,
    '03_session_tool_columns',
    'sessions.' || column_name,
    expected_note,
    case
      when column_name = 'session_tool' and udt_name is not null then 'ok'
      when column_name = 'session_tool' and udt_name is null then 'pending_add'
      when udt_name is not null then 'check'
      else 'info'
    end,
    case
      when udt_name is null then 'not found'
      else udt_name || ', nullable=' || is_nullable
    end,
    case
      when column_name = 'session_tool' then 'Preferred DB column. If not found, later draft can add nullable text.'
      else 'Alternative naming candidate only; avoid mixing meanings unless already used.'
    end
  from session_tool_candidate_matches

  union all

  select
    40,
    '03_session_tool_columns',
    'public similar columns',
    'surface any existing tool/location/place/venue-like columns',
    case when match_count = 0 then 'none' else 'info' end,
    match_summary,
    'Catalog names only; do not paste row data or user-entered values.'
  from public_related_column_summary

  union all

  select
    50,
    '04_constraints',
    'session_tool related CHECK constraints',
    'initial design prefers free text; fixed value CHECK is not required yet',
    case when match_count = 0 then 'none' else 'check' end,
    constraint_names,
    'If a related CHECK already exists, review whether it conflicts with free-input UI.'
  from session_tool_constraint_summary

  union all

  select
    60 + function_sort,
    '05_rpc_presence',
    function_name || ' signature',
    'target RPC should exist in public schema',
    case when function_count > 0 then 'ok' else 'missing' end,
    signature_summary,
    'Review overload count before adding arguments; PostgREST can be sensitive to overlapping defaults.'
  from target_rpc_summary

  union all

  select
    70 + function_sort,
    '05_rpc_presence',
    function_name || ' session_tool IO',
    'after implementation, create/update and any read RPC should expose session_tool as needed',
    case
      when function_name = 'delete_session_post' then 'info'
      when has_session_tool_argument or has_session_tool_result then 'ok'
      else 'pending_change'
    end,
    'argument=' || has_session_tool_argument::text || ', result=' || has_session_tool_result::text,
    'Before apply, decide whether to replace existing signatures or add a new compatible RPC.'
  from target_rpc_summary

  union all

  select
    80 + function_sort,
    '06_rpc_security',
    function_name || ' security',
    'security_definer=true and search_path configured',
    case
      when function_count = 0 then 'missing'
      when all_security_definer and all_have_search_path then 'ok'
      else 'check'
    end,
    'security_definer=' || all_security_definer::text || ', search_path=' || all_have_search_path::text,
    'Keep the existing security posture when replacing RPC definitions.'
  from target_rpc_summary

  union all

  select
    90 + p.function_sort,
    '07_rpc_execute',
    p.function_name || ' EXECUTE grants',
    'authenticated=true, anon=false, public=false',
    case
      when p.authenticated_execute and not p.anon_execute and not p.public_execute then 'ok'
      else 'check'
    end,
    'authenticated=' || p.authenticated_execute::text
      || ', anon=' || p.anon_execute::text
      || ', public=' || p.public_execute::text,
    'Keep anon and public from executing session posting management RPCs.'
  from target_rpc_privileges p

  union all

  select
    110,
    '08_related_rpc_scan',
    'public session-related function scan',
    'find read/detail/list RPCs and any existing session_tool IO',
    case when function_count > 0 then 'info' else 'none' end,
    function_count::text || ' function(s); session_tool_related=' || session_tool_related_count::text || '; ' || signature_summary,
    'If detail/list uses direct table select instead of RPC, frontend and RLS reads still need review.'
  from public_session_function_summary

  union all

  select
    120 + helper_sort,
    '09_helpers',
    helper_label,
    signature_text || ' should exist',
    case when helper_regprocedure is not null then 'ok' else 'missing' end,
    coalesce(helper_regprocedure::text, 'not found'),
    helper_purpose || '; admin remains an app role, not a server-side credential.'
  from helper_matches

  union all

  select
    140,
    '10_rls_policy',
    'sessions RLS enabled',
    'sessions should keep RLS enabled',
    case when coalesce(relrowsecurity, false) then 'ok' else 'check' end,
    'relrowsecurity=' || coalesce(relrowsecurity::text, 'not found')
      || ', relforcerowsecurity=' || coalesce(relforcerowsecurity::text, 'not found'),
    'Adding a nullable text column should not weaken row ownership rules.'
  from session_rls

  union all

  select
    141,
    '10_rls_policy',
    'sessions policy summary',
    'policy names and commands only',
    'info',
    policy_count::text || ' policy/policies; ' || policy_summary,
    'Expression details are intentionally not expanded in this preflight.'
  from session_policy_summary

  union all

  select
    160,
    '11_design_candidate',
    'session_tool column design',
    'nullable text, no fixed-value CHECK in first implementation',
    'info',
    'session_tool text null; RPC trims blank to null; UI displays 未定 when blank',
    'This is a design checkpoint only; no schema change is performed by this file.'

  union all

  select
    170,
    '11_design_candidate',
    'RPC compatibility direction',
    'avoid ambiguous overloads with default arguments',
    'info',
    'review drop/recreate existing signatures vs. new RPC after preflight result',
    'Past end_at work replaced the single create_session_post signature to avoid overload ambiguity.'

  union all

  select
    180,
    '11_design_candidate',
    'Discord post format dependency',
    'new format uses 開催場所【session_tool or 未定】',
    'info',
    'Edge Function preview and send format should read the same normalized value',
    'Do not include site detail URL or internal identifiers in Discord text.'
)
select
  sort_order,
  section,
  check_name,
  expected,
  status,
  result_value,
  notes
from results
order by sort_order, section, check_name;
