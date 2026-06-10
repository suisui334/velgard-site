-- 057_notifications_schema_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Prepare private in-site notifications for session comments/applications.
-- - Prepare a separate activity timeline table for public/authenticated feed use.
-- - Keep private notification visibility separate from timeline visibility.
--
-- Scope:
-- - public.user_notifications
-- - public.activity_events
-- - RPCs for listing/counting/marking the current user's notifications
-- - helper RPCs that later session/comment/application RPCs can call
--
-- Out of scope in this draft:
-- - Replacing existing comment/application/session RPCs
-- - Frontend bell/list UI
-- - Email sending
-- - Discord sending
-- - Any secret, token, real user id, real email, full URL, or project ref recording

begin;

-- 1. Private recipient notifications.
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  session_id text references public.sessions(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text,
  target_path text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint user_notifications_type_check check (
    notification_type in (
      'session_comment',
      'session_application',
      'session_comment_updated',
      'application_status_changed',
      'session_created',
      'session_updated'
    )
  ),
  constraint user_notifications_title_not_blank check (length(trim(title)) > 0),
  constraint user_notifications_title_length_check check (length(title) <= 160),
  constraint user_notifications_body_length_check check (body is null or length(body) <= 1000),
  constraint user_notifications_target_path_check check (
    target_path is null
    or (
      char_length(target_path) <= 300
      and target_path !~* '^[a-z][a-z0-9+.-]*://'
      and position('..' in target_path) = 0
    )
  ),
  constraint user_notifications_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

comment on table public.user_notifications is
  'Private in-site notifications. Rows are recipient-scoped and must not be used as a public activity feed.';

comment on column public.user_notifications.target_path is
  'Relative in-site navigation target only. Do not store full external URLs or secrets.';

comment on column public.user_notifications.metadata is
  'Small non-secret metadata object. Do not store raw auth tokens, emails, full URLs, or Discord identifiers.';

create index if not exists user_notifications_recipient_created_idx
  on public.user_notifications(recipient_user_id, created_at desc);

create index if not exists user_notifications_recipient_unread_idx
  on public.user_notifications(recipient_user_id, read_at)
  where read_at is null;

create index if not exists user_notifications_session_idx
  on public.user_notifications(session_id);

create index if not exists user_notifications_actor_idx
  on public.user_notifications(actor_user_id);

alter table public.user_notifications enable row level security;

drop policy if exists user_notifications_select_own_or_admin on public.user_notifications;
drop policy if exists user_notifications_update_own_or_admin on public.user_notifications;

create policy user_notifications_select_own_or_admin
on public.user_notifications
for select
to authenticated
using (
  auth.uid() = recipient_user_id
  or public.is_admin()
);

revoke all on table public.user_notifications from anon;
revoke all on table public.user_notifications from authenticated;

-- 2. Activity timeline. This is intentionally separate from private notifications.
create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  session_id text references public.sessions(id) on delete set null,
  event_type text not null,
  visibility text not null default 'public',
  title text not null,
  body text,
  target_path text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint activity_events_type_check check (
    event_type in (
      'session_created',
      'session_updated',
      'session_comment',
      'session_application',
      'application_status_changed'
    )
  ),
  constraint activity_events_visibility_check check (
    visibility in ('public', 'authenticated', 'private')
  ),
  constraint activity_events_title_not_blank check (length(trim(title)) > 0),
  constraint activity_events_title_length_check check (length(title) <= 160),
  constraint activity_events_body_length_check check (body is null or length(body) <= 1000),
  constraint activity_events_target_path_check check (
    target_path is null
    or (
      char_length(target_path) <= 300
      and target_path !~* '^[a-z][a-z0-9+.-]*://'
      and position('..' in target_path) = 0
    )
  ),
  constraint activity_events_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

comment on table public.activity_events is
  'Public/authenticated activity timeline source. Private notification state is kept in user_notifications.';

comment on column public.activity_events.visibility is
  'public can be shown to anyone; authenticated requires login; private is reserved for future admin or recipient-scoped views.';

create index if not exists activity_events_created_idx
  on public.activity_events(created_at desc);

create index if not exists activity_events_visibility_created_idx
  on public.activity_events(visibility, created_at desc);

create index if not exists activity_events_session_idx
  on public.activity_events(session_id);

create index if not exists activity_events_actor_idx
  on public.activity_events(actor_user_id);

alter table public.activity_events enable row level security;

drop policy if exists activity_events_select_visible on public.activity_events;

create policy activity_events_select_visible
on public.activity_events
for select
to anon, authenticated
using (
  visibility = 'public'
  or (visibility = 'authenticated' and auth.uid() is not null)
  or (visibility = 'private' and public.is_admin())
);

revoke all on table public.activity_events from anon;
revoke all on table public.activity_events from authenticated;

-- 3. Current-user notification read RPCs.
create or replace function public.get_my_unread_notification_count()
returns integer
language sql
security definer
stable
set search_path = public
as $$
  select case
    when auth.uid() is null then 0
    else (
      select count(*)::integer
      from public.user_notifications un
      where un.recipient_user_id = auth.uid()
        and un.read_at is null
    )
  end;
$$;

create or replace function public.get_my_notifications(
  p_limit integer default 20,
  p_unread_only boolean default false
)
returns table (
  notification_id uuid,
  notification_type text,
  title text,
  body text,
  target_path text,
  is_read boolean,
  created_at timestamptz,
  actor_display_name text,
  session_title text
)
language sql
security definer
stable
set search_path = public
as $$
  select
    un.id as notification_id,
    un.notification_type,
    un.title,
    un.body,
    un.target_path,
    un.read_at is not null as is_read,
    un.created_at,
    actor.display_name as actor_display_name,
    s.title as session_title
  from public.user_notifications un
  left join public.public_profiles actor
    on actor.id = un.actor_user_id
  left join public.sessions s
    on s.id = un.session_id
  where auth.uid() is not null
    and un.recipient_user_id = auth.uid()
    and (not coalesce(p_unread_only, false) or un.read_at is null)
  order by un.created_at desc, un.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

create or replace function public.mark_my_notification_read(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.user_notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and recipient_user_id = auth.uid();

  get diagnostics affected_count = row_count;
  return affected_count > 0;
end;
$$;

create or replace function public.mark_all_my_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.user_notifications
  set read_at = coalesce(read_at, now())
  where recipient_user_id = auth.uid()
    and read_at is null;

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

revoke all on function public.get_my_unread_notification_count() from public;
revoke all on function public.get_my_notifications(integer, boolean) from public;
revoke all on function public.mark_my_notification_read(uuid) from public;
revoke all on function public.mark_all_my_notifications_read() from public;

grant execute on function public.get_my_unread_notification_count() to authenticated;
grant execute on function public.get_my_notifications(integer, boolean) to authenticated;
grant execute on function public.mark_my_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_my_notifications_read() to authenticated;

-- 4. Internal helper for later comment/application RPC instrumentation.
create or replace function public.create_session_owner_notification(
  p_session_id text,
  p_actor_user_id uuid,
  p_notification_type text,
  p_title text,
  p_body text default null,
  p_target_path text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_recipient uuid;
  created_notification_id uuid;
  normalized_target_path text;
begin
  select s.gm_user_id
  into target_recipient
  from public.sessions s
  where s.id = p_session_id;

  if target_recipient is null then
    return null;
  end if;

  if p_actor_user_id is not null and target_recipient = p_actor_user_id then
    return null;
  end if;

  normalized_target_path := coalesce(
    nullif(trim(p_target_path), ''),
    'session-detail.html?id=' || p_session_id
  );

  insert into public.user_notifications (
    recipient_user_id,
    actor_user_id,
    session_id,
    notification_type,
    title,
    body,
    target_path,
    metadata
  )
  values (
    target_recipient,
    p_actor_user_id,
    p_session_id,
    p_notification_type,
    p_title,
    p_body,
    normalized_target_path,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into created_notification_id;

  return created_notification_id;
end;
$$;

revoke all on function public.create_session_owner_notification(text, uuid, text, text, text, text, jsonb) from public;

-- 5. Timeline helper and read RPC.
create or replace function public.record_activity_event(
  p_actor_user_id uuid,
  p_event_type text,
  p_session_id text,
  p_visibility text,
  p_title text,
  p_body text default null,
  p_target_path text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  created_event_id uuid;
  normalized_target_path text;
begin
  normalized_target_path := coalesce(
    nullif(trim(p_target_path), ''),
    case when p_session_id is null then null else 'session-detail.html?id=' || p_session_id end
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
    p_actor_user_id,
    p_event_type,
    p_session_id,
    coalesce(nullif(trim(p_visibility), ''), 'public'),
    p_title,
    p_body,
    normalized_target_path,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into created_event_id;

  return created_event_id;
end;
$$;

create or replace function public.get_activity_timeline(
  p_limit integer default 50
)
returns table (
  event_id uuid,
  event_type text,
  visibility text,
  title text,
  body text,
  target_path text,
  created_at timestamptz,
  actor_display_name text,
  session_title text
)
language sql
security definer
stable
set search_path = public
as $$
  select
    ae.id as event_id,
    ae.event_type,
    ae.visibility,
    ae.title,
    ae.body,
    ae.target_path,
    ae.created_at,
    actor.display_name as actor_display_name,
    s.title as session_title
  from public.activity_events ae
  left join public.public_profiles actor
    on actor.id = ae.actor_user_id
  left join public.sessions s
    on s.id = ae.session_id
  where ae.visibility = 'public'
     or (ae.visibility = 'authenticated' and auth.uid() is not null)
     or (ae.visibility = 'private' and public.is_admin())
  order by ae.created_at desc, ae.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.record_activity_event(uuid, text, text, text, text, text, text, jsonb) from public;
revoke all on function public.get_activity_timeline(integer) from public;

grant execute on function public.get_activity_timeline(integer) to anon, authenticated;

commit;
