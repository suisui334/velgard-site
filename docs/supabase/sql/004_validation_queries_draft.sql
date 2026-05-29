-- Supabase Step 4-4 validation queries draft
-- Purpose:
--   Validate created objects, RLS flags, public-facing columns, and function privileges
--   after running 001_core_schema_draft.sql, 002_rls_grants_draft.sql, and
--   003_rpc_draft.sql in a prototype Supabase project.
--
-- Important:
--   This file is SELECT-only by design.
--   Do not add DROP / DELETE / TRUNCATE / INSERT / UPDATE / ALTER / CREATE here.
--   Do not paste Project URL, API keys, service role keys, JWT secrets, DB passwords,
--   Discord bot tokens, webhook URLs, real emails, or real Discord IDs into this file.

-- 1. Core table existence.
select
  'core_table_exists' as check_name,
  expected.table_name,
  case when actual.table_name is not null then 'ok' else 'missing' end as result
from (
  values
    ('profiles'),
    ('user_roles'),
    ('sessions'),
    ('session_comments'),
    ('session_applications')
) as expected(table_name)
left join information_schema.tables as actual
  on actual.table_schema = 'public'
 and actual.table_name = expected.table_name
order by expected.table_name;

-- 2. RLS is enabled on all core tables.
select
  'rls_enabled' as check_name,
  c.relname as table_name,
  case when c.relrowsecurity then 'ok' else 'ng' end as result
from pg_catalog.pg_class as c
join pg_catalog.pg_namespace as n
  on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'profiles',
    'user_roles',
    'sessions',
    'session_comments',
    'session_applications'
  )
order by c.relname;

-- 3. Public-facing views exist.
select
  'view_exists' as check_name,
  expected.view_name,
  case when actual.table_name is not null then 'ok' else 'missing' end as result
from (
  values
    ('public_profiles'),
    ('session_application_counts')
) as expected(view_name)
left join information_schema.views as actual
  on actual.table_schema = 'public'
 and actual.table_name = expected.view_name
order by expected.view_name;

-- 4. public_profiles exposes only minimum public profile columns.
select
  'public_profiles_columns' as check_name,
  column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

select
  'public_profiles_no_discord_user_id' as check_name,
  case
    when not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'public_profiles'
        and column_name = 'discord_user_id'
    )
    then 'ok'
    else 'ng'
  end as result;

-- 5. Expected helper/RPC functions exist.
select
  'function_exists' as check_name,
  expected.routine_name,
  case when actual.routine_name is not null then 'ok' else 'missing' end as result
from (
  values
    ('has_role'),
    ('is_admin'),
    ('is_session_gm'),
    ('can_apply_to_session'),
    ('get_public_session_application_counts'),
    ('get_public_session_comments'),
    ('create_application_comment'),
    ('edit_comment'),
    ('cancel_application'),
    ('set_application_status'),
    ('close_session')
) as expected(routine_name)
left join information_schema.routines as actual
  on actual.specific_schema = 'public'
 and actual.routine_name = expected.routine_name
order by expected.routine_name;

-- 6. Public comment display RPC must not expose internal user_id or discord_user_id.
select
  'public_comment_rpc_no_internal_columns' as check_name,
  case
    when not exists (
      select 1
      from pg_catalog.pg_proc as p
      join pg_catalog.pg_namespace as n
        on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_public_session_comments'
        and (
          array_to_string(coalesce(p.proargnames, array[]::text[]), ',') like '%user_id%'
          or array_to_string(coalesce(p.proargnames, array[]::text[]), ',') like '%discord_user_id%'
        )
    )
    then 'ok'
    else 'review'
  end as result;

-- 7. can_apply_to_session should allow recruiting/tentative and not allow full.
select
  'can_apply_status_definition' as check_name,
  case
    when pg_catalog.pg_get_functiondef('public.can_apply_to_session(text)'::regprocedure) like '%''recruiting''%'
     and pg_catalog.pg_get_functiondef('public.can_apply_to_session(text)'::regprocedure) like '%''tentative''%'
     and pg_catalog.pg_get_functiondef('public.can_apply_to_session(text)'::regprocedure) not like '%''full''%'
    then 'ok'
    else 'review'
  end as result;

-- 8. List RLS policies for manual review.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  permissive
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles',
    'user_roles',
    'sessions',
    'session_comments',
    'session_applications'
  )
order by tablename, policyname;

-- 9. Table grants for anon/authenticated manual review.
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in (
    'profiles',
    'user_roles',
    'sessions',
    'session_comments',
    'session_applications',
    'public_profiles',
    'session_application_counts'
  )
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

-- 10. Function execute privileges for anon/authenticated manual review.
select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'has_role',
    'is_admin',
    'is_session_gm',
    'can_apply_to_session',
    'get_public_session_application_counts',
    'get_public_session_comments',
    'create_application_comment',
    'edit_comment',
    'cancel_application',
    'set_application_status',
    'close_session'
  )
  and grantee in ('anon', 'authenticated', 'public')
order by routine_name, grantee, privilege_type;

-- 11. Optional status sanity check after test sessions are inserted.
-- This returns no rows until sessions exist. It is safe to run before seed data.
select
  id,
  status,
  visibility,
  public.can_apply_to_session(id) as can_apply
from public.sessions
where status in ('tentative', 'recruiting', 'full', 'closed', 'finished', 'canceled', 'draft')
order by date, id;
