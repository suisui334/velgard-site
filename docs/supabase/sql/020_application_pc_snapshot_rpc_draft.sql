-- 020_application_pc_snapshot_rpc_draft.sql
-- M-15F draft for application-time PC snapshot connection.
--
-- DRAFT ONLY. DO NOT RUN UNTIL A REVIEWED APPLY STEP IS REQUESTED.
-- This file intentionally documents CREATE/REPLACE and privilege statements
-- for review. It is not a SELECT-only preflight file.
--
-- Do not paste Project URL, API keys, service role keys, DB passwords,
-- connection strings, JWT secrets, tokens, real emails, real user IDs,
-- real Discord IDs, or other secrets into this file.

-- ============================================================
-- REVIEW SUMMARY
-- ============================================================
--
-- Scope:
-- - Replace public.create_application_comment(text, text) only.
-- - Keep the frontend RPC payload unchanged:
--     target_session_id text
--     comment_body text
-- - Do not add user name, Discord user ID, PC name, or character ID inputs to
--   the application comment form.
-- - The application comment body remains free text. It is not parsed for
--   identity/contact data.
--
-- Data sources:
-- - User name: public.profiles.display_name
-- - Discord user ID: public.profiles.discord_handle
-- - PC name: caller's active default row in public.player_characters
--
-- Snapshot behavior:
-- - New PL application:
--     selected_character_id = caller's default PC id, or null
--     pc_name_snapshot = caller's default PC name, or null
-- - Reapply from canceled:
--     refresh selected_character_id / pc_name_snapshot from the current default
--     PC at the time of reapplication.
-- - Existing pending / accepted / rejected / waitlisted application:
--     append the comment and keep the existing application status/snapshot.
-- - Comment edit:
--     handled by update_application_comment and must not change PC snapshot.
-- - No default PC:
--     application remains allowed and both snapshot columns stay null.
--
-- GM comments:
-- - GM comments are allowed as comments.
-- - GM comments are not participant applications.
-- - GM comments are inserted with session_comments.is_application = false.
-- - GM comments do not create or update a session_applications row.
-- - GM comments do not write selected_character_id / pc_name_snapshot.
--
-- Later work:
-- - M-15G: GM accepted participant list/contact/template data should include
--   pc_name_snapshot without returning raw user_id/email/internal IDs.
-- - M-15H: Template variable UI should connect
--   {{session_title}}, {{approved_call_list}}, and {{approved_pc_names}}.
-- - Future multiple-PC selection should use a dedicated application PC
--   selection UI/RPC, separate from the free-text comment body.
--
-- M-15F preflight result reviewed:
-- - The revised 020 select-only preflight ran successfully.
-- - player_characters, selected_character_id, pc_name_snapshot, and the
--   existing create_application_comment(text, text) entry point exist.
-- - session_applications.status allows pending / accepted / rejected /
--   waitlisted / canceled, so the pending and canceled paths below fit the DB
--   constraint.
-- - Main RPCs and helpers are security definer; authenticated EXECUTE is
--   present and anon/public EXECUTE did not appear in the reviewed result.
-- - table_privileges may show REFERENCES / TRIGGER / TRUNCATE privilege rows
--   in catalog output, but frontend mutation must still go through RPCs.

-- Stop before applying if:
-- - public.player_characters is missing.
-- - public.session_applications.selected_character_id is missing.
-- - public.session_applications.pc_name_snapshot is missing.
-- - public.session_comments.is_application is missing.
-- - public.create_application_comment(text, text) has an unexpected contract.
-- - public.can_apply_to_session(text) or public.is_session_gm(text) is missing.
-- - Current frontend depends on GM comments creating application rows.
-- - Review requires raw user IDs, emails, tokens, keys, secrets, or real
--   Discord IDs in docs/chat.

-- ============================================================
-- APPLY DRAFT
-- ============================================================

begin;

create or replace function public.create_application_comment(
  target_session_id text,
  comment_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
  v_comment_body text;
  v_new_comment_id uuid;
  v_existing_status text;
  v_default_character_id uuid;
  v_default_pc_name text;
  v_is_session_owner boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');
  v_comment_body := nullif(trim(coalesce(comment_body, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  if v_comment_body is null then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  -- Keep the existing open-session gate. The current frontend also limits the
  -- comment form to statuses where application comments are accepted.
  if not public.can_apply_to_session(v_target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  v_is_session_owner := public.is_session_gm(v_target_session_id);

  if not v_is_session_owner then
    select
      pc.id,
      pc.pc_name
    into
      v_default_character_id,
      v_default_pc_name
    from public.player_characters as pc
    where pc.owner_user_id = v_actor_id
      and pc.is_active = true
      and pc.is_default = true
    order by
      pc.updated_at desc nulls last,
      pc.created_at desc nulls last
    limit 1;
  end if;

  select sa.status
  into v_existing_status
  from public.session_applications as sa
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
  for update;

  insert into public.session_comments (
    session_id,
    user_id,
    body,
    is_application
  )
  values (
    v_target_session_id,
    v_actor_id,
    comment_body,
    not v_is_session_owner
  )
  returning id into v_new_comment_id;

  if v_is_session_owner then
    -- GM comments are not applications and must not be counted as participant
    -- rows. Existing frontend cleanup that calls cancel_my_session_application
    -- after a GM comment can remain; with this replacement there may simply be
    -- no application row to cancel.
    return v_new_comment_id;
  end if;

  if v_existing_status is null then
    insert into public.session_applications (
      session_id,
      user_id,
      comment_id,
      status,
      selected_character_id,
      pc_name_snapshot
    )
    values (
      v_target_session_id,
      v_actor_id,
      v_new_comment_id,
      'pending',
      v_default_character_id,
      v_default_pc_name
    );
  elsif v_existing_status = 'canceled' then
    update public.session_applications
    set
      comment_id = v_new_comment_id,
      status = 'pending',
      canceled_at = null,
      selected_character_id = v_default_character_id,
      pc_name_snapshot = v_default_pc_name,
      updated_at = now()
    where session_id = v_target_session_id
      and user_id = v_actor_id;
  else
    -- pending / accepted / rejected / waitlisted rows keep their existing
    -- status and PC snapshot. This preserves GM review state and avoids
    -- rewriting the participation PC merely because a comment was appended.
    null;
  end if;

  return v_new_comment_id;
end;
$$;

revoke all on function public.create_application_comment(text, text) from public;
revoke all on function public.create_application_comment(text, text) from anon;
revoke all on function public.create_application_comment(text, text) from authenticated;

grant execute on function public.create_application_comment(text, text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- POST-APPLY CHECK DRAFT
-- ============================================================

select
  p.oid::regprocedure as signature,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.proconfig as function_config
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_application_comment'
order by p.oid::regprocedure::text;

select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'create_application_comment'
order by routine_name, grantee, privilege_type;

-- Manual/auth-context checks for a later reviewed apply:
-- - PL with active default PC creates a pending application and snapshots the
--   default PC id/name.
-- - PL without default PC can still apply; selected_character_id and
--   pc_name_snapshot are null.
-- - Reapply from canceled refreshes the snapshot from the current default PC.
-- - Comment edit does not alter selected_character_id or pc_name_snapshot.
-- - GM comment creates a visible comment with is_application = false and does
--   not create/update session_applications.
-- - Pending / accepted / rejected / waitlisted existing rows keep their
--   current snapshot when an extra comment is appended.
-- - Returned values and frontend output do not expose user_id, email,
--   owner_user_id, selected_character_id, token, key, or secrets.
