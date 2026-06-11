-- 061_activity_events_instrument_session_events_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Wire the existing player comment/application entry point to the shared activity timeline.
-- - Keep private owner notifications and public/authenticated activity timeline events separate.
-- - Preserve frontend arguments and return value for create_application_comment(text, text).
--
-- Scope:
-- - Replace public.create_application_comment(text, text) only.
-- - Preserve existing comment/application behavior, owner notification instrumentation,
--   PC snapshot behavior, grants, and return shape.
-- - Add public.record_activity_event(...) calls for PL-side events only:
--   - session_comment
--   - session_application
-- - Keep GM/admin management comments as private owner-notification behavior only.
--
-- Deliberately not included in this draft:
-- - create_session_post activity instrumentation. That RPC is larger and should be
--   reviewed in a separate focused draft before replacing it again.
-- - GM/admin management comment activity. Management comments can exist on
--   non-public sessions, so they should not be exposed in the shared timeline
--   until a stricter visibility design is reviewed.
-- - session edit, approval/rejection, close mark, delete, Discord, email, or repair events.
-- - Any full URL, real user id, email, token, project ref, Discord id, or secret recording.
--
-- Activity visibility policy:
-- - PL comment/application events are stored with authenticated visibility.
-- - The activity body is a short generic summary, not the raw comment/application text.
-- - The target path stays relative: session-detail.html?id=<session id>.
--
-- Failure policy:
-- - PL-side activity insertion is part of the same RPC transaction.
-- - If activity instrumentation fails, the PL comment/application RPC fails and rolls back.
-- - This matches the notification MVP policy so instrumentation problems are visible
--   during QA instead of silently losing timeline events.

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
  v_activity_type text := 'session_comment';
  v_activity_title text := 'Session comment';
  v_activity_body text := 'A comment was posted.';
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

    -- Intentionally do not create a shared activity row for GM/admin
    -- management comments. They may occur on non-public sessions.
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
    v_activity_type := 'session_application';
    v_activity_title := 'Session application';
    v_activity_body := 'A participation application was posted.';
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
    v_activity_type := 'session_application';
    v_activity_title := 'Session application';
    v_activity_body := 'A participation application was posted.';
  else
    v_notification_type := 'session_comment';
    v_notification_title := 'Session comment received';
    v_activity_type := 'session_comment';
    v_activity_title := 'Session comment';
    v_activity_body := 'A comment was posted.';
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

  perform public.record_activity_event(
    v_actor_id,
    v_activity_type,
    v_target_session_id,
    'authenticated',
    v_activity_title,
    v_activity_body,
    'session-detail.html?id=' || v_target_session_id,
    jsonb_build_object(
      'source', 'create_application_comment',
      'event', v_activity_type
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
