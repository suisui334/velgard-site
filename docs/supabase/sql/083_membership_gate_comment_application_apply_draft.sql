-- 083_membership_gate_comment_application_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Add the first server-side approved-member gate to comment/application RPCs.
-- - Block pending/rejected/revoked/blocked users from direct RPC calls even if
--   frontend controls are hidden.
-- - Keep existing signatures, return shapes, grants, notification/activity
--   instrumentation, spam guards, PC snapshot behavior, and comment/application
--   permissions.
--
-- Scope:
-- - public.create_application_comment(text, text)
-- - public.cancel_my_session_application(text)
-- - public.update_application_comment(uuid, text)
-- - public.delete_application_comment_and_maybe_cancel(uuid)
--
-- Not included:
-- - SQL Editor execution by Codex.
-- - The remaining approved-member RPC gates.
-- - Session post, player character, template, notification, TIMELINE, avatar,
--   Discord, revoked/blocked management, or membership approver role changes.
-- - RLS policy changes, table definition changes, direct table grants, or
--   public_profiles exposure changes.
-- - Any concrete user id, email, session id, full URL, token, project ref, or
--   secret recording.

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
  v_activity_event_id uuid;
  v_url_match_count integer := 0;
  v_recent_comment_exists boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_approved_member() then
    raise exception '承認済みアカウントのみ利用できます。';
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

  select count(*)::integer
  into v_url_match_count
  from regexp_matches(v_comment_body, concat('https?', '://', '|www\.'), 'gi') as m;

  if v_url_match_count > 2 then
    raise exception '本文に含められるURLは2件までです。';
  end if;

  v_is_management_comment :=
    public.is_admin() or public.is_session_gm(v_target_session_id);

  if not v_is_management_comment
    and not public.can_apply_to_session(v_target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  if not v_is_management_comment then
    select exists (
      select 1
      from public.session_comments as sc
      where sc.session_id = v_target_session_id
        and sc.user_id = v_actor_id
        and sc.deleted_at is null
        and sc.created_at >= now() - interval '60 seconds'
    )
    into v_recent_comment_exists;

    if v_recent_comment_exists then
      raise exception '短時間に連続して投稿することはできません。少し待ってから再度お試しください。';
    end if;

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

    -- Shared timeline intentionally excludes GM/admin management comments.
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

  insert into public.activity_events (
    actor_user_id,
    event_type,
    session_id,
    visibility,
    title,
    body,
    target_path,
    metadata
  )
  values (
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
  )
  returning id into v_activity_event_id;

  if v_activity_event_id is null then
    raise exception 'activity event was not created';
  end if;

  return v_new_comment_id;
end;
$$;

create or replace function public.cancel_my_session_application(
  target_session_id text
)
returns table (
  session_id text,
  application_status text,
  canceled_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
  v_session_exists boolean := false;
  v_current_status text;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_approved_member() then
    raise exception '承認済みアカウントのみ利用できます。';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  select exists (
    select 1
    from public.sessions as s
    where s.id = v_target_session_id
  )
  into v_session_exists;

  if not v_session_exists then
    raise exception 'session or application not found';
  end if;

  select sa.status
  into v_current_status
  from public.session_applications as sa
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
  for update;

  if v_current_status is null then
    raise exception 'session or application not found';
  end if;

  if v_current_status = 'canceled' then
    return query
    select
      sa.session_id,
      sa.status as application_status,
      sa.canceled_at,
      sa.updated_at
    from public.session_applications as sa
    where sa.session_id = v_target_session_id
      and sa.user_id = v_actor_id;

    return;
  end if;

  if v_current_status not in ('pending', 'waitlisted', 'accepted') then
    raise exception 'application is not withdrawable';
  end if;

  return query
  update public.session_applications as sa
  set
    status = 'canceled',
    canceled_at = now(),
    updated_at = now()
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
    and sa.status in ('pending', 'waitlisted', 'accepted')
  returning
    sa.session_id,
    sa.status as application_status,
    sa.canceled_at,
    sa.updated_at;

  if not found then
    raise exception 'application not found or cannot be withdrawn';
  end if;
end;
$$;

create or replace function public.update_application_comment(
  target_comment_id uuid,
  comment_body text
)
returns table (
  comment_id uuid,
  session_id text,
  edited_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_approved_member() then
    raise exception '承認済みアカウントのみ利用できます。';
  end if;

  if target_comment_id is null then
    raise exception 'comment id is required';
  end if;

  if comment_body is null or length(trim(comment_body)) = 0 then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  return query
  update public.session_comments as c
  set
    body = comment_body,
    edited_at = now(),
    edited_by = v_actor_id,
    updated_at = now()
  where c.id = target_comment_id
    and c.deleted_at is null
    and (
      c.user_id = v_actor_id
      or public.is_session_gm(c.session_id)
      or public.is_admin()
    )
  returning
    c.id,
    c.session_id,
    c.edited_at;

  if not found then
    raise exception 'comment not found or not editable';
  end if;
end;
$$;

create or replace function public.delete_application_comment_and_maybe_cancel(
  target_comment_id uuid
)
returns table (
  deleted_comment_id uuid,
  affected_session_id text,
  application_status text,
  application_canceled boolean,
  active_application_comment_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_session_id text;
  v_comment_user_id uuid;
  v_is_application boolean := false;
  v_active_count integer := 0;
  v_cancel_update_count integer := 0;
  v_application_status text;
  v_can_manage boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_approved_member() then
    raise exception '承認済みアカウントのみ利用できます。';
  end if;

  if target_comment_id is null then
    raise exception 'comment id is required';
  end if;

  select
    c.session_id,
    c.user_id,
    c.is_application
  into
    v_session_id,
    v_comment_user_id,
    v_is_application
  from public.session_comments as c
  where c.id = target_comment_id
    and c.deleted_at is null;

  if v_session_id is null or v_comment_user_id is null then
    raise exception 'comment not found or already deleted';
  end if;

  v_can_manage :=
    v_comment_user_id = v_actor_id
    or public.is_session_gm(v_session_id)
    or public.is_admin();

  if not v_can_manage then
    raise exception 'comment not deletable';
  end if;

  update public.session_comments as c
  set
    deleted_at = now(),
    deleted_by = v_actor_id,
    updated_at = now()
  where c.id = target_comment_id
    and c.deleted_at is null;

  if not found then
    raise exception 'comment not found or already deleted';
  end if;

  select count(*)
  into v_active_count
  from public.session_comments as c
  where c.session_id = v_session_id
    and c.user_id = v_comment_user_id
    and c.is_application = true
    and c.deleted_at is null;

  if v_is_application and v_active_count = 0 then
    update public.session_applications as sa
    set
      status = 'canceled',
      canceled_at = coalesce(sa.canceled_at, now()),
      updated_at = now()
    where sa.session_id = v_session_id
      and sa.user_id = v_comment_user_id
      and sa.status in ('pending', 'accepted', 'rejected', 'waitlisted')
    returning sa.status
    into v_application_status;

    get diagnostics v_cancel_update_count = row_count;
  end if;

  if v_application_status is null then
    select sa.status
    into v_application_status
    from public.session_applications as sa
    where sa.session_id = v_session_id
      and sa.user_id = v_comment_user_id;
  end if;

  return query
  select
    target_comment_id,
    v_session_id,
    v_application_status,
    v_cancel_update_count > 0,
    v_active_count;
end;
$$;

revoke all on function public.create_application_comment(text, text) from public;
revoke all on function public.create_application_comment(text, text) from anon;
revoke all on function public.create_application_comment(text, text) from authenticated;
grant execute on function public.create_application_comment(text, text) to authenticated;

revoke all on function public.cancel_my_session_application(text) from public;
revoke all on function public.cancel_my_session_application(text) from anon;
revoke all on function public.cancel_my_session_application(text) from authenticated;
grant execute on function public.cancel_my_session_application(text) to authenticated;

revoke all on function public.update_application_comment(uuid, text) from public;
revoke all on function public.update_application_comment(uuid, text) from anon;
revoke all on function public.update_application_comment(uuid, text) from authenticated;
grant execute on function public.update_application_comment(uuid, text) to authenticated;

revoke all on function public.delete_application_comment_and_maybe_cancel(uuid) from public;
revoke all on function public.delete_application_comment_and_maybe_cancel(uuid) from anon;
revoke all on function public.delete_application_comment_and_maybe_cancel(uuid) from authenticated;
grant execute on function public.delete_application_comment_and_maybe_cancel(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
