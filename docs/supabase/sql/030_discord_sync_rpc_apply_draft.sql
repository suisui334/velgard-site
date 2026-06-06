-- 030_discord_sync_rpc_apply_draft.sql
-- M-14E-16 draft for Discord sync state RPCs.
--
-- DO NOT RUN UNTIL REVIEWED.
-- This is an APPLY draft, not an executed migration.
-- Do not paste into Supabase SQL Editor until:
-- - The RPC apply review gate is complete.
-- - Function names, return shapes, and Edge Function call order are reviewed.
-- - The user explicitly approves SQL apply.
--
-- This draft intentionally does not alter table columns.
-- It assumes public.sessions already has:
-- - discord_message_id
-- - discord_channel_id
-- - discord_thread_id
-- - discord_post_url
-- - discord_sync_status
-- - discord_last_action
-- - discord_sync_requested_at
-- - discord_synced_at
-- - discord_sync_error
--
-- Confirmed CHECK values:
-- - discord_sync_status: failed / not_requested / pending / posted / skipped
-- - discord_last_action: close / create / delete / resync / update
--
-- Values used below:
-- - create success: discord_sync_status = posted, discord_last_action = create
-- - create failure: discord_sync_status = failed, discord_last_action = create
-- - no non-CHECK status/action values are used.
--
-- M-14E-16I review note:
-- - CHECK expansion SELECT-only was run once without error by the user.
-- - Keep this draft non-executable until the RPC apply review gate is complete.
--
-- Safety notes:
-- - No INSERT statements.
-- - No DELETE statements.
-- - No DROP TABLE, DROP COLUMN, TRUNCATE, or CASCADE.
-- - UPDATE appears only inside dedicated RPC function bodies.
-- - External post identifiers and URLs are stored but not returned by these RPCs.
-- - Keep credential values, auth tokens, external targets, row data, and project identifiers out of review notes.

begin;

-- ============================================================
-- 1. Pre-send create guard
-- ============================================================
--
-- Purpose:
-- - Confirm the caller is the owner GM or admin.
-- - Reject create if an external post identifier already exists.
-- - Return only generalized readiness information.
--
-- This guard does not send to Discord and does not update DB state.
-- It is a best-effort pre-send check. The success-record RPC below still
-- performs the final conditional DB-side check.

create or replace function public.check_discord_session_post_create_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_send boolean,
  discord_sync_status text,
  discord_last_action text,
  has_existing_post boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_existing record;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id,
    s.discord_sync_status,
    s.discord_last_action
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      public.has_role('gm')
      and v_existing.gm_user_id = v_actor
    )
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    raise exception 'discord_create_already_synced' using errcode = '23505';
  end if;

  session_id := v_session_id;
  can_send := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_existing_post := false;
  return next;
end;
$$;

-- ============================================================
-- 2. Post-send create success record
-- ============================================================
--
-- Purpose:
-- - Record external post metadata only after Discord send succeeds.
-- - Refuse to overwrite an existing external post identifier.
-- - Return only sanitized DB update status.

create or replace function public.record_discord_session_post_create_success(
  p_session_id text,
  p_discord_message_id text,
  p_discord_channel_id text default null,
  p_discord_thread_id text default null,
  p_discord_post_url text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  discord_synced_at timestamptz,
  has_external_post_identifier boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_message_id text;
  v_channel_id text;
  v_thread_id text;
  v_post_url text;
  v_existing record;
  v_synced_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_message_id := nullif(btrim(coalesce(p_discord_message_id, '')), '');
  if v_message_id is null then
    raise exception 'discord_message_id_required' using errcode = '22023';
  end if;
  if v_message_id ~ '[\r\n]' or length(v_message_id) > 120 then
    raise exception 'invalid_discord_message_id' using errcode = '22023';
  end if;

  v_channel_id := nullif(btrim(coalesce(p_discord_channel_id, '')), '');
  if v_channel_id is not null and (v_channel_id ~ '[\r\n]' or length(v_channel_id) > 120) then
    raise exception 'invalid_discord_channel_id' using errcode = '22023';
  end if;

  v_thread_id := nullif(btrim(coalesce(p_discord_thread_id, '')), '');
  if v_thread_id is not null and (v_thread_id ~ '[\r\n]' or length(v_thread_id) > 120) then
    raise exception 'invalid_discord_thread_id' using errcode = '22023';
  end if;

  v_post_url := nullif(btrim(coalesce(p_discord_post_url, '')), '');
  if v_post_url is not null and (v_post_url ~ '[\r\n]' or length(v_post_url) > 500) then
    raise exception 'invalid_discord_post_url' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      public.has_role('gm')
      and v_existing.gm_user_id = v_actor
    )
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    raise exception 'discord_create_already_synced' using errcode = '23505';
  end if;

  update public.sessions as s
  set
    discord_message_id = v_message_id,
    discord_channel_id = v_channel_id,
    discord_thread_id = v_thread_id,
    discord_post_url = v_post_url,
    discord_sync_status = 'posted',
    discord_last_action = 'create',
    discord_synced_at = now(),
    discord_sync_error = null,
    updated_at = now()
  where s.id = v_session_id
    and nullif(btrim(coalesce(s.discord_message_id, '')), '') is null
  returning s.discord_synced_at
    into v_synced_at;

  if not found then
    raise exception 'discord_create_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'posted';
  discord_last_action := 'create';
  discord_synced_at := v_synced_at;
  has_external_post_identifier := true;
  return next;
end;
$$;

-- ============================================================
-- 3. Post-send create failure record
-- ============================================================
--
-- Purpose:
-- - Record a generalized failure after a Discord send attempt fails.
-- - Never store raw external response bodies, credential values, or external targets.
-- - Keep the failure string short and generic.

create or replace function public.record_discord_session_post_create_failure(
  p_session_id text,
  p_error_code text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_error_code text;
  v_existing record;
  v_updated_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_error_code := nullif(btrim(coalesce(p_error_code, '')), '');
  if v_error_code is null then
    v_error_code := 'discord_send_failed';
  end if;
  if v_error_code ~ '[\r\n]' then
    raise exception 'invalid_error_code' using errcode = '22023';
  end if;
  v_error_code := left(v_error_code, 120);

  select
    s.id,
    s.gm_user_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      public.has_role('gm')
      and v_existing.gm_user_id = v_actor
    )
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'failed',
    discord_last_action = 'create',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
  returning s.updated_at
    into v_updated_at;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'create';
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================
-- 4. Privileges
-- ============================================================

revoke execute on function public.check_discord_session_post_create_ready(text) from public;
revoke execute on function public.check_discord_session_post_create_ready(text) from anon;
grant execute on function public.check_discord_session_post_create_ready(text) to authenticated;

revoke execute on function public.record_discord_session_post_create_success(text, text, text, text, text) from public;
revoke execute on function public.record_discord_session_post_create_success(text, text, text, text, text) from anon;
grant execute on function public.record_discord_session_post_create_success(text, text, text, text, text) to authenticated;

revoke execute on function public.record_discord_session_post_create_failure(text, text) from public;
revoke execute on function public.record_discord_session_post_create_failure(text, text) from anon;
grant execute on function public.record_discord_session_post_create_failure(text, text) to authenticated;

commit;

-- ============================================================
-- 5. Post-apply verification candidates
-- ============================================================
-- These SELECT statements are included for future review only.
-- Do not treat this draft as approved for execution yet.

select
  p.proname as function_name,
  p.oid::regprocedure::text as signature,
  p.prosecdef as security_definer,
  exists (
    select 1
    from unnest(coalesce(p.proconfig, array[]::text[])) cfg
    where cfg like 'search_path=%'
  ) as has_search_path
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'check_discord_session_post_create_ready',
    'record_discord_session_post_create_success',
    'record_discord_session_post_create_failure'
  )
order by p.proname, p.oid::regprocedure::text;
