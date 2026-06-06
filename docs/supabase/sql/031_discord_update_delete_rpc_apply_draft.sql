-- 031_discord_update_delete_rpc_apply_draft.sql
-- M-14E-17 draft for Discord update/delete sync RPCs.
--
-- DO NOT RUN UNTIL REVIEWED.
-- NOT EXECUTED.
-- DO NOT PASTE INTO SUPABASE SQL EDITOR YET.
--
-- This is an APPLY draft for review only.
-- It must be reviewed in an independent SQL/RPC apply gate before use.
--
-- This draft intentionally does not alter table columns.
-- It assumes public.sessions already has Discord sync columns and that
-- create-only sync RPCs from 030 are already applied.
--
-- Confirmed CHECK values:
-- - discord_sync_status: failed / not_requested / pending / posted / skipped
-- - discord_last_action: close / create / delete / resync / update
--
-- Values used below:
-- - update success: discord_sync_status = posted, discord_last_action = update
-- - update failure: discord_sync_status = failed, discord_last_action = update
-- - delete failure: discord_sync_status = failed, discord_last_action = delete
--
-- Safety notes:
-- - No INSERT statements.
-- - No table DELETE statements.
-- - No DROP TABLE, DROP COLUMN, TRUNCATE, or CASCADE.
-- - UPDATE appears only inside dedicated RPC function bodies.
-- - This draft does not replace create sync RPCs.
-- - Existing update_session_post and delete_session_post responsibilities remain separate.
-- - External post identifiers and URLs are not returned by these RPCs.
-- - Do not write credential values, auth tokens, project identifiers, row data, or external target values here.

begin;

-- ============================================================
-- 1. Pre-send update guard
-- ============================================================
--
-- Purpose:
-- - Confirm caller is owner GM or admin.
-- - Confirm an existing Discord post identifier is present.
-- - Return only generalized readiness information.
--
-- This guard does not call Discord and does not update DB state.

create or replace function public.check_discord_session_post_update_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_update boolean,
  discord_sync_status text,
  discord_last_action text,
  has_external_post_identifier boolean
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

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is null then
    raise exception 'discord_post_reference_required' using errcode = '22023';
  end if;

  session_id := v_session_id;
  can_update := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_external_post_identifier := true;
  return next;
end;
$$;

-- ============================================================
-- 2. Post-update success record
-- ============================================================
--
-- Purpose:
-- - Record update success after Discord message edit succeeds.
-- - Do not expose or return external identifiers.

create or replace function public.record_discord_session_post_update_success(
  p_session_id text
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  discord_synced_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
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

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is null then
    raise exception 'discord_post_reference_required' using errcode = '22023';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'posted',
    discord_last_action = 'update',
    discord_synced_at = now(),
    discord_sync_error = null,
    updated_at = now()
  where s.id = v_session_id
    and nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null
  returning s.discord_synced_at
    into v_synced_at;

  if not found then
    raise exception 'discord_update_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'posted';
  discord_last_action := 'update';
  discord_synced_at := v_synced_at;
  return next;
end;
$$;

-- ============================================================
-- 3. Post-update failure record
-- ============================================================
--
-- Purpose:
-- - Record a generalized failure after Discord message edit fails.
-- - Keep the session row and application state intact.

create or replace function public.record_discord_session_post_update_failure(
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
    v_error_code := 'discord_update_failed';
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
    discord_last_action = 'update',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
  returning s.updated_at
    into v_updated_at;

  if not found then
    raise exception 'discord_update_failure_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'update';
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================
-- 4. Pre-delete guard
-- ============================================================
--
-- Purpose:
-- - Confirm caller is owner GM or admin.
-- - Tell Edge Function whether Discord delete should happen first.
-- - Do not delete DB rows here.

create or replace function public.check_discord_session_post_delete_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_delete boolean,
  needs_discord_delete boolean,
  discord_sync_status text,
  discord_last_action text,
  has_external_post_identifier boolean
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

  session_id := v_session_id;
  can_delete := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_external_post_identifier := nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null;
  needs_discord_delete := has_external_post_identifier;
  return next;
end;
$$;

-- ============================================================
-- 5. Delete failure record
-- ============================================================
--
-- Purpose:
-- - Record a generalized failure if Discord delete or DB delete orchestration fails.
-- - If DB delete succeeds, the sessions row is gone and no success state is retained.

create or replace function public.record_discord_session_post_delete_failure(
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
    v_error_code := 'discord_delete_failed';
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
    discord_last_action = 'delete',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
  returning s.updated_at
    into v_updated_at;

  if not found then
    raise exception 'discord_delete_failure_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'delete';
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================
-- 6. Privileges
-- ============================================================

revoke execute on function public.check_discord_session_post_update_ready(text) from public;
revoke execute on function public.check_discord_session_post_update_ready(text) from anon;
grant execute on function public.check_discord_session_post_update_ready(text) to authenticated;

revoke execute on function public.record_discord_session_post_update_success(text) from public;
revoke execute on function public.record_discord_session_post_update_success(text) from anon;
grant execute on function public.record_discord_session_post_update_success(text) to authenticated;

revoke execute on function public.record_discord_session_post_update_failure(text, text) from public;
revoke execute on function public.record_discord_session_post_update_failure(text, text) from anon;
grant execute on function public.record_discord_session_post_update_failure(text, text) to authenticated;

revoke execute on function public.check_discord_session_post_delete_ready(text) from public;
revoke execute on function public.check_discord_session_post_delete_ready(text) from anon;
grant execute on function public.check_discord_session_post_delete_ready(text) to authenticated;

revoke execute on function public.record_discord_session_post_delete_failure(text, text) from public;
revoke execute on function public.record_discord_session_post_delete_failure(text, text) from anon;
grant execute on function public.record_discord_session_post_delete_failure(text, text) to authenticated;

commit;

-- ============================================================
-- 7. Post-apply verification candidates
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
    'check_discord_session_post_update_ready',
    'record_discord_session_post_update_success',
    'record_discord_session_post_update_failure',
    'check_discord_session_post_delete_ready',
    'record_discord_session_post_delete_failure'
  )
order by p.proname, p.oid::regprocedure::text;
