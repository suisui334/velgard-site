-- ============================================================
-- Velgard Supabase M-12B reviewed draft
-- 014_discord_id_profile_contact_draft.sql
--
-- DRAFT ONLY:
--   Do not run this SQL until the M-12B execution review is complete.
--   Do not paste Project URL, API keys, service role keys, DB passwords,
--   direct connection strings, JWT secrets, tokens, real emails, real user IDs,
--   real application IDs, real comment IDs, or real Discord IDs here.
--   This draft adds a private player contact column and narrow RPCs.
-- ============================================================

-- Purpose:
--   Let a signed-in player save their own Discord contact value, and let the
--   target session GM or an admin read only accepted participants' contact
--   values for one session.
--
-- Naming:
--   Store the value in profiles.discord_handle, not profiles.discord_user_id
--   or profiles.discord_name. The existing discord_user_id column is constrained
--   to a numeric snowflake, and discord_name is treated as an existing
--   compatibility / legacy-oriented column. This feature needs a flexible
--   player-entered contact value. UI text may still say "Discord ID"; the DB
--   column and RPC return name document that the stored value is a contact
--   handle/string, not necessarily a numeric user id.
--
-- Adopted RPC names:
--   get_my_profile_contact()
--   update_my_discord_id(new_discord_id text)
--   get_gm_session_accepted_contacts(target_session_id text)
--
-- Return columns:
--   display_name text
--   discord_handle text
--
-- Values intentionally not returned:
--   user_id, email, application_id, comment_id, role, discord_user_id,
--   discord_name, discord_id aliases, tokens, keys, secrets.

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- 0-1. Confirm current profiles contact-related columns.
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'id',
    'display_name',
    'discord_user_id',
    'discord_name',
    'discord_id',
    'discord_handle',
    'created_at',
    'updated_at'
  )
order by ordinal_position;

-- 0-2. Confirm existing Discord-related constraints.
select
  conname,
  contype,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.profiles'::regclass
  and (
    conname ilike '%discord%'
    or pg_catalog.pg_get_constraintdef(oid) ilike '%discord%'
  )
order by conname;

-- 0-3. Confirm public_profiles exposes only public display columns.
select
  table_name,
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

-- 0-4. Confirm helper functions exist and pin search_path.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('is_admin', 'is_session_gm')
order by p.proname, p.oid::regprocedure::text;

-- 0-5. Confirm accepted status exists.
select
  'session_applications_status_check' as check_name,
  conname,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.session_applications'::regclass
  and conname = 'session_applications_status_check';

-- 0-6. Review direct table grants. This feature should not require broad
-- direct profile SELECT/UPDATE grants for anon/authenticated clients.
select
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in ('profiles', 'public_profiles', 'session_applications')
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

-- 0-7. Review function name collisions.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_my_profile_contact',
    'update_my_discord_id',
    'get_gm_session_accepted_contacts'
  )
order by p.proname, p.oid::regprocedure::text;

-- Stop before applying if:
--   - public_profiles exposes any Discord/contact column,
--   - profiles.discord_handle already exists with a different reviewed purpose,
--   - profiles.discord_id exists and creates ambiguity with the reviewed
--     discord_handle plan,
--   - the team decides to reuse discord_name instead of adding discord_handle,
--   - is_admin() or is_session_gm(text) is missing or unexpected,
--   - session_applications.status does not include accepted,
--   - any of the three contact RPC names already exists with a different
--     reviewed contract,
--   - broad direct grants expose profiles contact fields to anon or normal PLs,
--   - review requires real IDs, emails, keys, tokens, secrets, or Discord IDs
--     in docs or chat.

-- ============================================================
-- 1. Apply draft
-- ============================================================

-- Run this apply section only after the preflight checks pass.
-- SQL Editor usually runs with owner/editor privileges; do not use SQL Editor
-- results to infer anon/authenticated/GM behavior. Verify auth-context behavior
-- through reviewed clients or the smoke test.

begin;

alter table public.profiles
  add column if not exists discord_handle text;

alter table public.profiles
  drop constraint if exists profiles_discord_handle_text;

alter table public.profiles
  add constraint profiles_discord_handle_text
  check (
    discord_handle is null
    or (
      char_length(discord_handle) <= 100
      and length(trim(discord_handle)) > 0
      and position(chr(10) in discord_handle) = 0
      and position(chr(13) in discord_handle) = 0
    )
  );

comment on column public.profiles.discord_handle is
  'Private Discord contact handle entered by the profile owner. Not exposed via public_profiles.';

create or replace function public.get_my_profile_contact()
returns table (
  display_name text,
  discord_handle text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  return query
  select
    coalesce(nullif(trim(p.display_name), ''), '名前未設定')::text as display_name,
    p.discord_handle::text as discord_handle
  from public.profiles as p
  where p.id = auth.uid();

  if not found then
    return query
    select
      '名前未設定'::text as display_name,
      null::text as discord_handle;
  end if;
end;
$$;

create or replace function public.update_my_discord_id(
  new_discord_id text
)
returns table (
  display_name text,
  discord_handle text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_discord_id text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  clean_discord_id := nullif(trim(coalesce(new_discord_id, '')), '');

  if clean_discord_id is not null and char_length(clean_discord_id) > 100 then
    raise exception 'discord id is too long';
  end if;

  if clean_discord_id is not null
     and (
       position(chr(10) in clean_discord_id) > 0
       or position(chr(13) in clean_discord_id) > 0
     ) then
    raise exception 'discord id cannot contain line breaks';
  end if;

  return query
  insert into public.profiles as p (
    id,
    display_name,
    discord_handle
  )
  values (
    auth.uid(),
    '名前未設定',
    clean_discord_id
  )
  on conflict (id) do update
  set
    discord_handle = excluded.discord_handle,
    updated_at = now()
  where p.id = auth.uid()
  returning
    coalesce(nullif(trim(p.display_name), ''), '名前未設定')::text as display_name,
    p.discord_handle::text as discord_handle;
end;
$$;

create or replace function public.get_gm_session_accepted_contacts(
  target_session_id text
)
returns table (
  display_name text,
  discord_handle text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  if not (
    public.is_admin()
    or public.is_session_gm(v_target_session_id)
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    coalesce(nullif(trim(p.display_name), ''), '名前未設定')::text as display_name,
    p.discord_handle::text as discord_handle
  from public.session_applications as sa
  join public.profiles as p
    on p.id = sa.user_id
  where sa.session_id = v_target_session_id
    and sa.status = 'accepted'
  order by
    p.display_name asc nulls last,
    sa.updated_at desc nulls last,
    sa.created_at desc nulls last;
end;
$$;

revoke all on function public.get_my_profile_contact() from public;
revoke all on function public.get_my_profile_contact() from anon;
revoke all on function public.get_my_profile_contact() from authenticated;

revoke all on function public.update_my_discord_id(text) from public;
revoke all on function public.update_my_discord_id(text) from anon;
revoke all on function public.update_my_discord_id(text) from authenticated;

revoke all on function public.get_gm_session_accepted_contacts(text) from public;
revoke all on function public.get_gm_session_accepted_contacts(text) from anon;
revoke all on function public.get_gm_session_accepted_contacts(text) from authenticated;

grant execute on function public.get_my_profile_contact() to authenticated;
grant execute on function public.update_my_discord_id(text) to authenticated;
grant execute on function public.get_gm_session_accepted_contacts(text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- 2. Post-apply verification checks
-- ============================================================

-- Verify private column and constraint. Do not paste stored Discord values into
-- docs; keep result records to schema/contract and aggregate counts only.
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name = 'discord_handle';

select
  conname,
  contype,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.profiles'::regclass
  and conname = 'profiles_discord_handle_text';

-- Verify public_profiles still exposes only public display columns.
select
  table_name,
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

-- Verify function contract and security mode.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_my_profile_contact',
    'update_my_discord_id',
    'get_gm_session_accepted_contacts'
  )
order by p.proname, p.oid::regprocedure::text;

-- Verify execute grants.
-- Expected client grantee:
--   authenticated
-- Expected absent:
--   anon, PUBLIC/public
-- Owner or administrative roles may also appear and are not a client-side broad grant.
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'get_my_profile_contact',
    'update_my_discord_id',
    'get_gm_session_accepted_contacts'
  )
order by routine_name, grantee, privilege_type;

-- Verify declared return columns without executing contact RPCs in SQL Editor.
select
  r.routine_name,
  p.parameter_name,
  p.data_type,
  p.ordinal_position
from information_schema.routines r
join information_schema.parameters p
  on p.specific_schema = r.specific_schema
 and p.specific_name = r.specific_name
where r.specific_schema = 'public'
  and r.routine_name in (
    'get_my_profile_contact',
    'update_my_discord_id',
    'get_gm_session_accepted_contacts'
  )
  and p.parameter_mode = 'OUT'
order by r.routine_name, p.ordinal_position;

-- Safe aggregate only. Do not record real Discord values.
select
  count(*) filter (where discord_handle is not null) as profiles_with_discord_handle_count
from public.profiles;

-- Manual / smoke-test behavior checks to run only with reviewed auth-context clients:
--   - anon cannot execute any of the three contact RPCs.
--   - normal PL can read only their own display_name / discord_handle via get_my_profile_contact().
--   - normal PL can update only their own Discord contact via update_my_discord_id().
--   - blank input is stored as null / unregistered.
--   - input longer than 100 characters is rejected.
--   - line breaks are rejected.
--   - normal PL cannot read other participants' contacts.
--   - target session GM can read accepted participants' display_name / discord_handle only.
--   - other GM cannot read contacts for a session they do not own.
--   - admin can read accepted participants' contacts.
--   - pending / waitlisted / canceled / rejected participants are not returned by
--     get_gm_session_accepted_contacts().
--   - returned rows include only display_name and discord_handle.
--   - returned rows do not include user_id, email, application_id, comment_id,
--     roles, discord_user_id, discord_name, discord_id aliases, tokens, keys,
--     or secrets.

-- ============================================================
-- 3. Rollback draft
-- ============================================================

-- Use only if this draft was applied and must be fully removed before real
-- Discord contact values are stored. If the column contains production contact
-- data, do not drop it without an explicit data retention decision.
--
-- begin;
--
-- revoke all on function public.get_my_profile_contact() from public;
-- revoke all on function public.get_my_profile_contact() from anon;
-- revoke all on function public.get_my_profile_contact() from authenticated;
-- drop function if exists public.get_my_profile_contact();
--
-- revoke all on function public.update_my_discord_id(text) from public;
-- revoke all on function public.update_my_discord_id(text) from anon;
-- revoke all on function public.update_my_discord_id(text) from authenticated;
-- drop function if exists public.update_my_discord_id(text);
--
-- revoke all on function public.get_gm_session_accepted_contacts(text) from public;
-- revoke all on function public.get_gm_session_accepted_contacts(text) from anon;
-- revoke all on function public.get_gm_session_accepted_contacts(text) from authenticated;
-- drop function if exists public.get_gm_session_accepted_contacts(text);
--
-- alter table public.profiles
--   drop constraint if exists profiles_discord_handle_text;
--
-- alter table public.profiles
--   drop column if exists discord_handle;
--
-- notify pgrst, 'reload schema';
--
-- commit;

-- ============================================================
-- 4. Out of scope for this draft
-- ============================================================

-- - Running this SQL in Supabase SQL Editor.
-- - Changing DB data.
-- - Calling the contact RPCs from Codex.
-- - Production mypage UI implementation.
-- - Production GM contact display or copy implementation.
-- - Exposing Discord contact values via public_profiles, public comments,
--   public JSON, anon, or normal PL views.
-- - Migrating/deleting existing discord_user_id or discord_name data.
-- - updates.json changes.
-- - Secrets, real Project URL/key values, emails, tokens, real internal IDs,
--   or real Discord IDs.
