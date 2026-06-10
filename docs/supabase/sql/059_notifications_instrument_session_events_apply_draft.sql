-- 059_notifications_instrument_session_events_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Wire the existing comment/application entry point to in-site notifications.
-- - Notify the session owner/GM when another user comments or applies.
-- - Keep frontend arguments and return value for create_application_comment(text, text).
--
-- Scope:
-- - Replace public.create_application_comment(text, text) only.
-- - Preserve existing comment/application behavior, PC snapshot behavior, grants, and return shape.
-- - Call the internal helper public.create_session_owner_notification(...).
--
-- Out of scope:
-- - SQL Editor execution in this preparation step.
-- - PL-facing approval/rejection notification from set_application_status.
-- - Email notification, Discord notification, Edge Function deploy, or activity timeline UI.
-- - Any full URL, real user id, email, token, project ref, Discord id, or secret recording.
--
-- Failure policy:
-- - Notification insertion is part of the same RPC transaction.
-- - If notification instrumentation fails, the comment/application RPC fails and rolls back.
-- - This is intentional for MVP so notification plumbing problems are visible during QA
--   instead of silently losing owner notifications.

begin;

create or replace function public.create_application_comment(
  target_session_id text,
  comment_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
  v_comment_body text;
  v_new_comment_id uuid;
  v_existing_status text;
  v_default_character_id uuid;
  v_default_pc_name text;
  v_is_management_comment boolean := false;
  v_notification_type text := 'session_comment';
  v_notification_title text := 'Session comment received';
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

  if length(v_comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  v_is_management_comment :=
    public.is_admin() or public.is_session_gm(v_target_session_id);

  if not v_is_management_comment
    and not public.can_apply_to_session(v_target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  if not v_is_management_comment then
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
    v_comment_body,
    not v_is_management_comment
  )
  returning id into v_new_comment_id;

  if v_is_management_comment then
    perform public.create_session_owner_notification(
      v_target_session_id,
      v_actor_id,
      'session_comment',
      v_notification_title,
      left(v_comment_body, 300),
      'session-detail.html?id=' || v_target_session_id,
      jsonb_build_object(
        'source', 'create_application_comment',
        'event', 'management_comment'
      )
    );

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

    v_notification_type := 'session_application';
    v_notification_title := 'Session application received';
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

    v_notification_type := 'session_application';
    v_notification_title := 'Session application received';
  else
    v_notification_type := 'session_comment';
    v_notification_title := 'Session comment received';
  end if;

  perform public.create_session_owner_notification(
    v_target_session_id,
    v_actor_id,
    v_notification_type,
    v_notification_title,
    left(v_comment_body, 300),
    'session-detail.html?id=' || v_target_session_id,
    jsonb_build_object(
      'source', 'create_application_comment',
      'event', v_notification_type
    )
  );

  return v_new_comment_id;
end;
$$;

revoke all on function public.create_application_comment(text, text) from public;
revoke all on function public.create_application_comment(text, text) from anon;
revoke all on function public.create_application_comment(text, text) from authenticated;

grant execute on function public.create_application_comment(text, text) to authenticated;

notify pgrst, 'reload schema';

commit;
