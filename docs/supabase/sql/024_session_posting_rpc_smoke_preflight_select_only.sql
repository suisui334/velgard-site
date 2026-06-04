-- 024_session_posting_rpc_smoke_preflight_select_only.sql
-- M-14D-15B select-only preflight for session posting RPC smoke tests.
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
expected_session_columns(column_sort, column_name, expected_note) as (
  values
    (1, 'id', 'public session id'),
    (2, 'title', 'session title'),
    (3, 'date', 'start date'),
    (4, 'start_time', 'start time'),
    (5, 'end_time', 'same-day end time fallback'),
    (6, 'end_at', 'full end timestamp'),
    (7, 'gm_name', 'display GM name'),
    (8, 'status', 'posting status'),
    (9, 'session_type', 'posting type'),
    (10, 'application_deadline', 'application deadline'),
    (11, 'player_min', 'minimum players'),
    (12, 'player_max', 'maximum players'),
    (13, 'summary', 'public summary'),
    (14, 'visibility', 'visibility'),
    (15, 'created_at', 'created timestamp'),
    (16, 'updated_at', 'updated timestamp'),
    (17, 'discord_sync_status', 'Discord sync status metadata'),
    (18, 'discord_last_action', 'Discord sync action metadata'),
    (19, 'discord_sync_requested_at', 'Discord sync request timestamp'),
    (20, 'discord_synced_at', 'Discord sync completion timestamp'),
    (21, 'discord_sync_error', 'Discord sync error summary')
),
expected_session_fk_tables(table_sort, table_name) as (
  values
    (1, 'session_applications'),
    (2, 'session_comments')
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
    (2, 'session_applications'),
    (3, 'session_comments'),
    (4, 'profiles'),
    (5, 'user_roles')
),
roles as (
  select
    to_regrole('authenticated') as authenticated_role,
    to_regrole('anon') as anon_role
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
      'status allowed values',
      'draft / tentative / recruiting / full / closed / finished / canceled',
      exists (
        select 1
        from session_check_constraints scc
        where scc.definition ilike '%status%'
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
      ), 'not found'),
      'Catalog check only; review constraint definition if status handling changes.'
    ),
    (
      2,
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
      'Catalog check only; public draft guard is also checked in RPC/UI smoke tests.'
    ),
    (
      3,
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
      'DB value remains session_type; UI may display this as session type.'
    )
),
session_fk_matches as (
  select
    e.table_sort,
    e.table_name,
    con.conname,
    con.confdeltype,
    case con.confdeltype
      when 'a' then 'NO ACTION'
      when 'r' then 'RESTRICT'
      when 'c' then 'CASCADE'
      when 'n' then 'SET NULL'
      when 'd' then 'SET DEFAULT'
      else con.confdeltype::text
    end as on_delete_action
  from expected_session_fk_tables e
  left join pg_catalog.pg_constraint con
    on con.contype = 'f'
   and con.conrelid = to_regclass('public.' || e.table_name)
   and con.confrelid = to_regclass('public.sessions')
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
user_roles_table as (
  select
    to_regclass('public.user_roles') as table_regclass
),
checks as (
  select
    (10 + s.function_sort)::integer as sort_order,
    '01_rpc_existence'::text as section,
    (s.function_name || ' exists')::text as check_name,
    'function exists in public schema'::text as expected,
    case when s.function_count > 0 then 'ok' else 'missing' end::text as status,
    (s.function_count::text || ' function(s); ' || s.signature_summary)::text as result_value,
    ('Result type: ' || s.result_summary)::text as notes
  from target_rpc_summary s

  union all
  select
    (20 + s.function_sort)::integer,
    '02_rpc_security_definer',
    (s.function_name || ' security_definer'),
    'all matching functions are security definer',
    case
      when s.function_count = 0 then 'missing'
      when s.all_security_definer then 'ok'
      else 'review'
    end,
    s.all_security_definer::text,
    s.signature_summary
  from target_rpc_summary s

  union all
  select
    (30 + s.function_sort)::integer,
    '03_rpc_search_path',
    (s.function_name || ' search_path'),
    'search_path is explicitly configured',
    case
      when s.function_count = 0 then 'missing'
      when s.all_have_search_path then 'ok'
      else 'review'
    end,
    s.all_have_search_path::text,
    s.signature_summary
  from target_rpc_summary s

  union all
  select
    (40 + p.function_sort)::integer,
    '04_rpc_authenticated_execute',
    (p.function_name || ' authenticated execute'),
    'authenticated can execute',
    case when p.authenticated_execute then 'ok' else 'review' end,
    p.authenticated_execute::text,
    'ACL-based catalog check.'
  from target_rpc_privileges p

  union all
  select
    (50 + p.function_sort)::integer,
    '05_rpc_anon_execute',
    (p.function_name || ' anon execute'),
    'anon cannot execute',
    case when p.anon_execute then 'review' else 'ok' end,
    p.anon_execute::text,
    'ACL-based catalog check.'
  from target_rpc_privileges p

  union all
  select
    (60 + p.function_sort)::integer,
    '06_rpc_public_execute',
    (p.function_name || ' public execute'),
    'PUBLIC cannot execute',
    case when p.public_execute then 'review' else 'ok' end,
    p.public_execute::text,
    'ACL-based catalog check; PUBLIC means the database pseudo-role.'
  from target_rpc_privileges p

  union all
  select
    70,
    '07_sessions_table',
    'sessions table exists',
    'public.sessions exists',
    case when table_regclass is not null then 'ok' else 'missing' end,
    coalesce(table_regclass::text, 'not found'),
    'Catalog table existence only.'
  from sessions_table

  union all
  select
    (80 + c.column_sort)::integer,
    '08_sessions_columns',
    ('sessions.' || c.column_name),
    c.expected_note,
    case when sc.column_name is not null then 'ok' else 'missing' end,
    coalesce(sc.udt_name || ', nullable=' || sc.is_nullable, 'not found'),
    'Column metadata only; no row values are selected.'
  from expected_session_columns c
  left join session_columns sc
    on sc.column_name = c.column_name

  union all
  select
    (120 + cc.check_sort)::integer,
    '09_sessions_check_constraints',
    cc.check_name,
    cc.expected_text,
    case when cc.is_ok then 'ok' else 'review' end,
    cc.result_value,
    cc.notes
  from constraint_checks cc

  union all
  select
    (130 + f.table_sort)::integer,
    '10_related_fk_on_delete',
    (f.table_name || ' -> sessions'),
    'FK exists and ON DELETE CASCADE',
    case
      when bool_or(f.conname is not null and f.confdeltype = 'c') then 'ok'
      when bool_or(f.conname is not null) then 'review'
      else 'missing'
    end,
    coalesce(
      string_agg(
        f.conname || ':' || f.on_delete_action,
        ' | ' order by f.conname
      ) filter (where f.conname is not null),
      'not found'
    ),
    'Expected related rows to follow DB constraint behavior when a session is physically removed.'
  from session_fk_matches f
  group by f.table_sort, f.table_name

  union all
  select
    (140 + h.helper_sort)::integer,
    '11_role_helpers',
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
    150,
    '12_user_roles_table',
    'user_roles table exists',
    'public.user_roles exists if app roles are table-backed',
    case when table_regclass is not null then 'ok' else 'review' end,
    coalesce(table_regclass::text, 'not found'),
    'admin remains an application role; this does not imply server-level privileges.'
  from user_roles_table

  union all
  select
    (160 + r.table_sort)::integer,
    '13_rls_enabled',
    (r.table_name || ' rls enabled'),
    'RLS enabled where required by existing design',
    case
      when not r.table_exists then 'missing'
      when r.relrowsecurity then 'ok'
      else 'review'
    end,
    case
      when not r.table_exists then 'not found'
      else 'relrowsecurity=' || r.relrowsecurity::text
    end,
    ('relforcerowsecurity=' || coalesce(r.relforcerowsecurity::text, 'n/a'))
  from rls_summary r

  union all
  select
    (170 + p.table_sort)::integer,
    '14_policy_summary',
    (p.table_name || ' policy summary'),
    'existing policies are visible for review',
    case
      when p.policy_count > 0 then 'info'
      else 'none'
    end,
    (
      'policy_count=' || p.policy_count::text
      || ', commands=' || p.commands_summary
      || ', roles=' || p.roles_summary
    ),
    'Policy names and expressions are not expanded here to keep the result compact.'
  from policy_summary p

  union all
  select
    190,
    '15_static_json_scope',
    'static JSON source handling',
    'manual frontend/docs check',
    'info',
    'not a DB catalog item',
    'Static JSON-origin sessions are outside DB RPC targets; verify via frontend merge and browser QA.'
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
