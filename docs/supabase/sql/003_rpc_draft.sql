-- ============================================================
-- Velgard Supabase Free Prototype
-- 003_rpc_draft.sql
--
-- DRAFT ONLY:
-- - RPC草案。まだ本番サイトへ接続しない。
-- - 002_rls_grants_draft.sql のhelper functions作成後に段階実行する想定。
-- - security definer関数は search_path 固定、入力検証、grant/revoke を必須とする。
-- ============================================================

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
  new_comment_id uuid;
  existing_status text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if target_session_id is null or length(trim(target_session_id)) = 0 then
    raise exception 'session id is required';
  end if;

  if comment_body is null or length(trim(comment_body)) = 0 then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  -- can_apply_to_session() allows only explicitly open states.
  -- full / closed / finished / canceled / draft are rejected.
  if not public.can_apply_to_session(target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  select sa.status
  into existing_status
  from public.session_applications sa
  where sa.session_id = target_session_id
    and sa.user_id = auth.uid();

  insert into public.session_comments (
    session_id,
    user_id,
    body,
    is_application
  )
  values (
    target_session_id,
    auth.uid(),
    comment_body,
    true
  )
  returning id into new_comment_id;

  if existing_status is null then
    insert into public.session_applications (
      session_id,
      user_id,
      comment_id,
      status
    )
    values (
      target_session_id,
      auth.uid(),
      new_comment_id,
      'pending'
    );
  elsif existing_status = 'canceled' then
    update public.session_applications
    set
      comment_id = new_comment_id,
      status = 'pending',
      canceled_at = null,
      updated_at = now()
    where session_id = target_session_id
      and user_id = auth.uid();
  else
    -- pending / accepted / rejected / waitlisted の既存申請は勝手に状態変更しない。
    -- コメントは追記として保存し、参加人数は増やさない。
    null;
  end if;

  return new_comment_id;
end;
$$;

create or replace function public.edit_comment(
  target_comment_id uuid,
  comment_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if comment_body is null or length(trim(comment_body)) = 0 then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  update public.session_comments
  set
    body = comment_body,
    edited_at = now(),
    updated_at = now()
  where id = target_comment_id
    and user_id = auth.uid()
    and deleted_at is null;

  get diagnostics affected_count = row_count;

  if affected_count = 0 then
    raise exception 'comment not found or not editable';
  end if;
end;
$$;

create or replace function public.cancel_application(
  target_session_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.session_applications
  set
    status = 'canceled',
    canceled_at = now(),
    updated_at = now()
  where session_id = target_session_id
    and user_id = auth.uid()
    and status in ('pending', 'rejected', 'waitlisted');

  get diagnostics affected_count = row_count;

  if affected_count = 0 then
    raise exception 'application not found or cannot be canceled';
  end if;
end;
$$;

create or replace function public.set_application_status(
  target_application_id uuid,
  new_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_session_id text;
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if new_status not in ('pending', 'accepted', 'rejected', 'waitlisted', 'canceled') then
    raise exception 'invalid application status';
  end if;

  select sa.session_id
  into target_session_id
  from public.session_applications sa
  where sa.id = target_application_id;

  if target_session_id is null then
    raise exception 'application not found';
  end if;

  if not public.is_session_gm(target_session_id) then
    raise exception 'not allowed';
  end if;

  update public.session_applications
  set
    status = new_status,
    canceled_at = case when new_status = 'canceled' then now() else null end,
    updated_at = now()
  where id = target_application_id;

  get diagnostics affected_count = row_count;

  if affected_count = 0 then
    raise exception 'application status was not updated';
  end if;
end;
$$;

create or replace function public.close_session(
  target_session_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_session_gm(target_session_id) then
    raise exception 'not allowed';
  end if;

  update public.sessions
  set
    status = 'closed',
    updated_at = now()
  where id = target_session_id
    and status in ('tentative', 'recruiting', 'full');

  get diagnostics affected_count = row_count;

  if affected_count = 0 then
    raise exception 'session not found or cannot be closed';
  end if;
end;
$$;

-- Functions are not protected by RLS. Keep execution grants explicit.
revoke all on function public.create_application_comment(text, text) from public;
revoke all on function public.edit_comment(uuid, text) from public;
revoke all on function public.cancel_application(text) from public;
revoke all on function public.set_application_status(uuid, text) from public;
revoke all on function public.close_session(text) from public;

grant execute on function public.create_application_comment(text, text) to authenticated;
grant execute on function public.edit_comment(uuid, text) to authenticated;
grant execute on function public.cancel_application(text) to authenticated;
grant execute on function public.set_application_status(uuid, text) to authenticated;
grant execute on function public.close_session(text) to authenticated;

-- 後回し候補:
-- reopen_session(target_session_id text)
-- 解除運用、Discord同期、pending申請の扱いを決めてから作る。
