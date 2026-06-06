-- 029_discord_sync_check_values_select_only.sql
-- M-14E-16 SQL draft for Discord sync CHECK values.
-- SELECT-only preflight. Do not use this file to change schema, data, or privileges.
-- Paste into Supabase SQL Editor only after a separate execution review.
--
-- Goals:
-- - Read exact CHECK definitions for discord_sync_status and discord_last_action.
-- - Reconfirm Discord sync columns and basic function signatures.
-- - Keep output in one result table.
-- - Do not include row data, credential values, external post identifiers, or project identifiers.
-- - Keep labels ASCII-only to reduce paste and encoding risk.

with
target_columns(column_sort, column_name, expected_note) as (
  values
    (1, 'discord_message_id', 'external post identifier'),
    (2, 'discord_channel_id', 'destination channel identifier'),
    (3, 'discord_thread_id', 'destination thread identifier'),
    (4, 'discord_post_url', 'external post URL'),
    (5, 'discord_sync_status', 'sync status'),
    (6, 'discord_last_action', 'last sync action'),
    (7, 'discord_sync_requested_at', 'sync request timestamp'),
    (8, 'discord_synced_at', 'last successful sync timestamp'),
    (9, 'discord_sync_error', 'generalized sync error')
),
target_rpcs(function_sort, function_name) as (
  values
    (1, 'create_session_post'),
    (2, 'update_session_post'),
    (3, 'delete_session_post')
),
roles as (
  select
    to_regrole('authenticated') as authenticated_role,
    to_regrole('anon') as anon_role
),
sessions_table as (
  select to_regclass('public.sessions') as table_regclass
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
target_column_matches as (
  select
    t.column_sort,
    t.column_name,
    t.expected_note,
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default
  from target_columns t
  left join session_columns c
    on c.column_name = t.column_name
),
target_column_summary as (
  select
    count(*) filter (where udt_name is not null) as present_count,
    count(*) as expected_count,
    coalesce(
      string_agg(column_name, ', ' order by column_sort) filter (where udt_name is null),
      'none'
    ) as missing_columns
  from target_column_matches
),
sync_related_columns as (
  select
    c.column_name,
    c.udt_name,
    c.is_nullable,
    c.column_default
  from session_columns c
  where c.column_name ilike 'discord_%'
     or c.column_name ilike '%sync%'
),
sync_related_column_summary as (
  select
    count(*) as column_count,
    coalesce(
      left(
        string_agg(
          column_name
          || ':' || udt_name
          || ', nullable=' || is_nullable
          || ', default=' || coalesce(column_default, 'NULL'),
          ' | ' order by column_name
        ),
        1600
      ),
      'not found'
    ) as column_summary
  from sync_related_columns
),
session_check_constraints as (
  select
    con.oid,
    con.conname,
    pg_catalog.pg_get_constraintdef(con.oid) as definition
  from pg_catalog.pg_constraint con
  where con.conrelid = to_regclass('public.sessions')
    and con.contype = 'c'
),
focused_check_constraints as (
  select
    conname,
    definition
  from session_check_constraints
  where definition ilike '%discord_sync_status%'
     or definition ilike '%discord_last_action%'
     or definition ilike '%status%'
     or definition ilike '%visibility%'
),
focused_check_summary as (
  select
    count(*) as constraint_count,
    coalesce(
      left(
        string_agg(conname || ': ' || definition, ' | ' order by conname),
        2400
      ),
      'not found'
    ) as constraint_summary
  from focused_check_constraints
),
rpc_catalog as (
  select
    tr.function_sort,
    tr.function_name,
    p.oid,
    p.proacl,
    p.proowner,
    p.prosecdef,
    p.proconfig,
    pg_catalog.pg_get_function_identity_arguments(p.oid) as identity_arguments
  from target_rpcs tr
  left join pg_catalog.pg_proc p
    on p.proname = tr.function_name
  left join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
   and n.nspname = 'public'
  where n.nspname = 'public'
     or p.oid is null
),
rpc_summary as (
  select
    function_name,
    count(oid) as function_count,
    coalesce(
      string_agg(
        function_name || '(' || coalesce(identity_arguments, '') || ')',
        ' | ' order by identity_arguments
      ) filter (where oid is not null),
      'not found'
    ) as signature_summary,
    bool_and(prosecdef) filter (where oid is not null) as all_security_definer,
    bool_or(
      exists (
        select 1
        from unnest(coalesce(proconfig, array[]::text[])) cfg
        where cfg like 'search_path=%'
      )
    ) filter (where oid is not null) as has_search_path
  from rpc_catalog
  group by function_name
),
rpc_acl as (
  select
    r.function_name,
    r.oid,
    acl.grantee,
    acl.privilege_type
  from rpc_catalog r
  join lateral pg_catalog.aclexplode(coalesce(r.proacl, pg_catalog.acldefault('f', r.proowner))) acl
    on true
  where r.oid is not null
),
execute_summary as (
  select
    r.function_name,
    coalesce(bool_or(a.grantee = roles.authenticated_role and a.privilege_type = 'EXECUTE'), false) as authenticated_execute,
    coalesce(bool_or(a.grantee = roles.anon_role and a.privilege_type = 'EXECUTE'), false) as anon_execute,
    coalesce(bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE'), false) as public_execute
  from rpc_catalog r
  cross join roles
  left join rpc_acl a
    on a.function_name = r.function_name
   and a.oid = r.oid
  group by r.function_name
),
rls_summary as (
  select
    c.relname,
    c.relrowsecurity,
    c.relforcerowsecurity
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('sessions', 'user_roles')
),
policy_summary as (
  select
    schemaname,
    tablename,
    count(*) as policy_count,
    coalesce(string_agg(policyname, ' | ' order by policyname), 'none') as policy_names
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in ('sessions', 'user_roles')
  group by schemaname, tablename
),
rows as (
  select
    10 as sort_order,
    'table' as section,
    'public.sessions exists' as check_name,
    'public.sessions is present' as expected,
    case when table_regclass is not null then 'ok' else 'missing' end as status,
    coalesce(table_regclass::text, 'not found') as result_value,
    'Catalog check only.' as notes
  from sessions_table

  union all

  select
    20 + column_sort,
    'columns',
    column_name,
    expected_note,
    case when udt_name is not null then 'ok' else 'missing' end,
    case
      when udt_name is not null then
        coalesce(udt_name, data_type)
        || ', nullable=' || is_nullable
        || ', default=' || coalesce(column_default, 'NULL')
      else 'not found'
    end,
    'No row values are returned.'
  from target_column_matches

  union all

  select
    40,
    'columns',
    'sync column summary',
    'all target Discord sync columns are present if possible',
    case when present_count = expected_count then 'ok' else 'check' end,
    present_count::text || '/' || expected_count::text || ' present',
    'missing=' || missing_columns
  from target_column_summary

  union all

  select
    50,
    'columns',
    'all sync-like session columns',
    'review existing Discord/sync columns',
    'info',
    column_count::text || ' column(s)',
    column_summary
  from sync_related_column_summary

  union all

  select
    60,
    'check_constraints',
    'focused CHECK definitions',
    'exact allowed values for sync status/action and related public states',
    case when constraint_count > 0 then 'info' else 'missing' end,
    constraint_count::text || ' constraint(s)',
    constraint_summary
  from focused_check_summary

  union all

  select
    70 + row_number() over (order by conname)::integer,
    'check_constraints',
    conname,
    'read exact CHECK definition before implementation',
    'info',
    left(definition, 1400),
    'Use this to align Edge Function/RPC status and action values.'
  from focused_check_constraints

  union all

  select
    120 + row_number() over (order by function_name)::integer,
    'rpc',
    function_name || ' signature',
    'existing RPC signature is visible',
    case when function_count > 0 then 'ok' else 'missing' end,
    signature_summary,
    'Function body is not returned.'
  from rpc_summary

  union all

  select
    150 + row_number() over (order by function_name)::integer,
    'rpc',
    function_name || ' security/search_path',
    'security_definer=true and search_path configured',
    case
      when all_security_definer is true and has_search_path is true then 'ok'
      else 'check'
    end,
    'security_definer=' || coalesce(all_security_definer::text, 'null')
      || ', search_path=' || coalesce(has_search_path::text, 'null'),
    'Keep dedicated sync RPC consistent with existing RPCs.'
  from rpc_summary

  union all

  select
    180 + row_number() over (order by function_name)::integer,
    'rpc',
    function_name || ' EXECUTE',
    'authenticated=true, anon=false, public=false',
    case
      when authenticated_execute is true
       and anon_execute is false
       and public_execute is false
      then 'ok'
      else 'check'
    end,
    'authenticated=' || authenticated_execute::text
      || ', anon=' || anon_execute::text
      || ', public=' || public_execute::text,
    'Privilege summary only.'
  from execute_summary

  union all

  select
    220 + row_number() over (order by relname)::integer,
    'rls',
    relname || ' RLS',
    'RLS enabled state remains visible',
    case when relrowsecurity then 'ok' else 'check' end,
    'rls=' || relrowsecurity::text || ', force_rls=' || relforcerowsecurity::text,
    'Catalog check only.'
  from rls_summary

  union all

  select
    240 + row_number() over (order by tablename)::integer,
    'policy',
    tablename || ' policy summary',
    'policy names only',
    'info',
    policy_count::text || ' policy(s)',
    left(policy_names, 1000)
  from policy_summary
)
select
  sort_order,
  section,
  check_name,
  expected,
  status,
  result_value,
  notes
from rows
order by sort_order;
