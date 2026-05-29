-- Supabase Step 11 RLS smoke test grant fix draft
-- Purpose:
--   Fix missing table privileges found by Auth-context smoke test.
--
-- DRAFT ONLY:
--   Do not run against production.
--   Review before executing in the Supabase SQL Editor.
--   Do not paste Project URL, API keys, passwords, service role keys, DB passwords,
--   real emails, real Discord IDs, webhook URLs, or bot tokens into this file.
--
-- Notes:
--   RLS policies still restrict row visibility after these table privileges are granted.
--   Do not grant direct SELECT on session_comments here.
--   Public comment display should continue to use get_public_session_comments().

-- 1. Grant minimal table SELECT privileges needed by the Data API.
grant select on table public.sessions to anon, authenticated;
grant select on table public.session_applications to authenticated;

-- 2. Verify table privileges.
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in ('sessions', 'session_applications', 'session_comments')
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

-- 3. Verify RLS is still enabled on the affected tables.
select
  schemaname,
  tablename,
  rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public'
  and tablename in ('sessions', 'session_applications', 'session_comments')
order by tablename;

-- 4. Verify relevant RLS policies still exist.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in ('sessions', 'session_applications')
order by tablename, policyname;

