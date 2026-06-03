-- 022_gm_accepted_contacts_pc_name_rpc_draft.sql
-- M-15G draft for adding PC names to GM accepted participant contacts.
--
-- DRAFT ONLY. DO NOT RUN UNTIL A REVIEWED APPLY STEP IS REQUESTED.
-- This file may require a reviewed drop/recreate strategy because PostgreSQL
-- does not allow changing a function's table return type with a simple
-- create-or-replace operation.
--
-- Do not paste Project URL, API keys, service role keys, DB passwords,
-- connection strings, JWT secrets, tokens, real emails, real user IDs,
-- real Discord IDs, selected_character_id values, application IDs, PC names,
-- or other secrets into this file.

-- ============================================================
-- REVIEW SUMMARY
-- ============================================================
--
-- Existing contract:
-- - public.get_gm_session_accepted_contacts(target_session_id text)
-- - Current return columns are display_name text and discord_handle text.
-- - Current frontend allow-list accepts only display_name / discord_handle.
--
-- M-15G direction:
-- - Keep the RPC name and input signature target_session_id text.
-- - Add PC/contact presentation columns only when frontend allow-list and UI
--   are updated in the same rollout.
-- - Keep existing columns display_name and discord_handle for compatibility.
-- - Treat pc_name_snapshot as the source of truth for the participant PC name.
-- - Do not return user_id, email, application_id, comment_id,
--   selected_character_id, owner_user_id, role, token, key, or secrets.
--
-- Proposed return columns:
-- - display_name text
-- - discord_handle text
-- - discord_mention text
-- - pc_name text
-- - pc_name_missing boolean
--
-- Discord handling:
-- - profiles.discord_handle is stored as a Discord user ID string.
-- - If it is 17 to 20 digits, return it as discord_handle and return
--   <@ID> as discord_mention.
-- - If it is missing or invalid, return null as discord_handle and
--   登録されていません as discord_mention.
-- - Do not return raw invalid Discord values.
--
-- PC name handling:
-- - If session_applications.pc_name_snapshot has a non-blank value, return it.
-- - Otherwise return PC名未登録 and pc_name_missing = true.
-- - player_characters.pc_name is reference data only; template and GM display
--   should use pc_name_snapshot.
--
-- GM/admin and GM-owner exclusion:
-- - Only the target session GM or admin can call this RPC successfully.
-- - Only session_applications.status = accepted rows are returned.
-- - The session GM's own application row is excluded inside the RPC, without
--   returning any internal IDs.
-- - GM/admin management comments are not applications and should not appear in
--   session_applications after M-15F.
--
-- Stop before applying if:
-- - M-15G preflight has not confirmed the current return columns.
-- - Frontend GM_CONTACT_FIELD_NAMES still allows only display_name /
--   discord_handle.
-- - A reviewed APPLY strategy for return type change has not been chosen.
-- - Review requires real internal IDs, emails, Discord IDs, PC names, tokens,
--   keys, or secrets in docs/chat.

-- ============================================================
-- APPLY DRAFT
-- ============================================================

begin;

-- Return type changes need a reviewed APPLY strategy. The final APPLY may need
-- to drop the old function before creating the new table-return shape.
drop function if exists public.get_gm_session_accepted_contacts(text);

create function public.get_gm_session_accepted_contacts(
  target_session_id text
)
returns table (
  display_name text,
  discord_handle text,
  discord_mention text,
  pc_name text,
  pc_name_missing boolean
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

  if not exists (
    select 1
    from public.sessions s
    where s.id = v_target_session_id
  ) then
    raise exception 'session not found';
  end if;

  if not (
    public.is_admin()
    or public.is_session_gm(v_target_session_id)
  ) then
    raise exception 'not allowed';
  end if;

  return query
  with accepted_rows as (
    select
      p.display_name,
      nullif(trim(p.discord_handle), '') as raw_discord_handle,
      nullif(trim(sa.pc_name_snapshot), '') as snapshot_pc_name,
      sa.updated_at,
      sa.created_at
    from public.session_applications as sa
    join public.sessions as s
      on s.id = sa.session_id
    join public.profiles as p
      on p.id = sa.user_id
    where sa.session_id = v_target_session_id
      and sa.status = 'accepted'
      and (
        s.gm_user_id is null
        or sa.user_id <> s.gm_user_id
      )
  ),
  normalized_rows as (
    select
      coalesce(nullif(trim(ar.display_name), ''), '名前未設定')::text as display_name,
      case
        when ar.raw_discord_handle ~ '^[0-9]{17,20}$'
          then ar.raw_discord_handle::text
        else null::text
      end as safe_discord_handle,
      coalesce(ar.snapshot_pc_name, 'PC名未登録')::text as safe_pc_name,
      (ar.snapshot_pc_name is null)::boolean as safe_pc_name_missing,
      ar.updated_at,
      ar.created_at
    from accepted_rows ar
  )
  select
    nr.display_name,
    nr.safe_discord_handle as discord_handle,
    case
      when nr.safe_discord_handle is not null
        then ('<@' || nr.safe_discord_handle || '>')::text
      else '登録されていません'::text
    end as discord_mention,
    nr.safe_pc_name as pc_name,
    nr.safe_pc_name_missing as pc_name_missing
  from normalized_rows nr
  order by
    nr.display_name asc nulls last,
    nr.updated_at desc nulls last,
    nr.created_at desc nulls last;
end;
$$;

revoke all on function public.get_gm_session_accepted_contacts(text) from public;
revoke all on function public.get_gm_session_accepted_contacts(text) from anon;
revoke all on function public.get_gm_session_accepted_contacts(text) from authenticated;

grant execute on function public.get_gm_session_accepted_contacts(text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- POST-APPLY CHECK DRAFT
-- ============================================================

select
  p.oid::regprocedure::text as signature,
  p.prosecdef as security_definer,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_gm_session_accepted_contacts'
order by p.oid::regprocedure::text;

select
  p.parameter_name,
  p.data_type,
  p.ordinal_position
from information_schema.routines r
join information_schema.parameters p
  on p.specific_schema = r.specific_schema
 and p.specific_name = r.specific_name
where r.specific_schema = 'public'
  and r.routine_name = 'get_gm_session_accepted_contacts'
  and p.parameter_mode = 'OUT'
order by p.ordinal_position;

select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'get_gm_session_accepted_contacts'
order by routine_name, grantee, privilege_type;
