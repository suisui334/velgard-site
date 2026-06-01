-- 017_update_session_post_preflight_select_only.sql
-- M-14D-8c select-only preflight for the session post update RPC draft.
-- Paste this whole file into SQL Editor before reviewing the main draft.
-- This file is read-only catalog inspection. It must not change schema, data, or privileges.

select
  to_regrole('anon') as anon_role,
  to_regrole('authenticated') as authenticated_role;

select
  to_regprocedure('public.has_role(text)') as has_role_fn,
  to_regprocedure('public.is_admin()') as is_admin_fn,
  to_regprocedure('public.is_session_gm(text)') as is_session_gm_fn;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_role', 'is_admin', 'is_session_gm')
order by p.proname, p.oid::regprocedure::text;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
order by ordinal_position;

with expected_columns(column_name) as (
  values
    ('id'),
    ('title'),
    ('date'),
    ('start_time'),
    ('end_time'),
    ('end_at'),
    ('gm_user_id'),
    ('gm_name'),
    ('status'),
    ('session_type'),
    ('application_deadline'),
    ('player_min'),
    ('player_max'),
    ('summary'),
    ('visibility'),
    ('updated_at'),
    ('discord_sync_status'),
    ('discord_sync_error'),
    ('discord_message_id'),
    ('discord_last_action'),
    ('discord_sync_requested_at'),
    ('discord_synced_at')
)
select
  e.column_name as expected_column,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  case when c.column_name is null then false else true end as exists_in_sessions
from expected_columns e
left join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name = 'sessions'
 and c.column_name = e.column_name
order by e.column_name;

select
  conname,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = to_regclass('public.sessions')
  and (
    conname in (
      'sessions_session_type_check',
      'sessions_discord_sync_status_check',
      'sessions_discord_last_action_check',
      'sessions_discord_sync_error_length_check'
    )
    or pg_get_constraintdef(oid) ilike '%visibility%'
    or pg_get_constraintdef(oid) ilike '%status%'
    or pg_get_constraintdef(oid) ilike '%session_type%'
  )
order by conname;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_session_post'
order by p.oid::regprocedure::text;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post'
order by p.oid::regprocedure::text;

select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'has_role',
    'is_admin',
    'is_session_gm',
    'create_session_post',
    'update_session_post'
  )
  and grantee in ('anon', 'authenticated')
order by routine_name, grantee, privilege_type;
