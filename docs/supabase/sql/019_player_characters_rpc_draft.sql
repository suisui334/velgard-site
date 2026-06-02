-- 019_player_characters_rpc_draft.sql
-- M-15B PC名登録・参加申請PC紐付け SQL草案
--
-- DRAFT ONLY:
-- - SQL Editorではまだ実行しない。
-- - DB構造変更、RPC作成/置換、GRANT/REVOKEは今回行わない。
-- - フロントUI実装、参加申請UI変更、テンプレート保存機能実装は今回行わない。
-- - 実メール、実user_id、実PC名、実Discord ID、Project URL、API key、
--   service_role key、token、secret類をこのファイルに書かない。
--
-- Preflight:
-- - 実行前確認には select-only の以下を使う。
--   docs/supabase/sql/019_player_characters_preflight_select_only.sql
--
-- Product direction:
-- - player_characters でPC名を管理する。
-- - session_applications に selected_character_id / pc_name_snapshot を持たせる。
-- - 初期実装では本人のdefault PCを参加申請時に自動採用する。
-- - 後続で参加申請時PC選択へ拡張する。
-- - テンプレート出力では pc_name_snapshot を正とする。

-- ============================================================
-- SECTION 1: REVIEW NOTES
-- ============================================================

-- Review before any apply step:
-- - public.profiles.id is the site profile primary key and references auth.users.
-- - public.session_applications has session_id, user_id, status, comment_id.
-- - public.session_applications has one row per session/user.
-- - Existing create_application_comment behavior is still the application entry point.
-- - GM comments are not participant applications and must not become accepted rows.
-- - get_gm_session_accepted_contacts currently returns display_name / discord_handle only.
-- - Frontend must be updated before a returned column contract changes.
--
-- Stop and revise if:
-- - player_characters already exists with a different contract.
-- - session_applications already has selected_character_id or pc_name_snapshot
--   with a different purpose.
-- - PC names need to be public to anon users.
-- - Applying a contact RPC change would break current JS assertions.
-- - The team decides application-time PC selection is required before default PC.

-- ============================================================
-- SECTION 2: SCHEMA DRAFT
-- DO NOT RUN UNTIL PREFLIGHT RESULT IS REVIEWED.
-- ============================================================

create table public.player_characters (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  pc_name text not null,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_characters_pc_name_not_blank check (length(trim(pc_name)) > 0),
  constraint player_characters_pc_name_length_check check (char_length(pc_name) <= 40),
  constraint player_characters_pc_name_single_line_check check (
    position(chr(10) in pc_name) = 0
    and position(chr(13) in pc_name) = 0
  )
);

create index player_characters_owner_idx
on public.player_characters(owner_user_id);

create index player_characters_owner_active_idx
on public.player_characters(owner_user_id, is_active);

create unique index player_characters_one_default_per_owner_idx
on public.player_characters(owner_user_id)
where is_default = true and is_active = true;

create trigger player_characters_set_updated_at
before update on public.player_characters
for each row execute function public.set_updated_at();

alter table public.player_characters enable row level security;

create policy "player_characters_select_own"
on public.player_characters
for select
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid());

create policy "player_characters_admin_select"
on public.player_characters
for select
to authenticated
using (public.is_admin());

alter table public.session_applications
  add column selected_character_id uuid null references public.player_characters(id) on delete set null,
  add column pc_name_snapshot text null;

alter table public.session_applications
  add constraint session_applications_pc_name_snapshot_length_check
  check (pc_name_snapshot is null or char_length(pc_name_snapshot) <= 40);

alter table public.session_applications
  add constraint session_applications_pc_name_snapshot_single_line_check
  check (
    pc_name_snapshot is null
    or (
      position(chr(10) in pc_name_snapshot) = 0
      and position(chr(13) in pc_name_snapshot) = 0
    )
  );

create index session_applications_selected_character_idx
on public.session_applications(selected_character_id);

create index session_applications_session_pc_snapshot_idx
on public.session_applications(session_id, pc_name_snapshot);

-- ============================================================
-- SECTION 3: PLAYER CHARACTER RPC DRAFT
-- DO NOT RUN UNTIL SCHEMA DRAFT IS REVIEWED.
-- ============================================================

create or replace function public.get_my_player_characters()
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.owner_user_id = auth.uid()
  order by
    pc.is_active desc,
    pc.is_default desc,
    pc.updated_at desc,
    pc.created_at desc;
end;
$$;

create or replace function public.create_player_character(
  p_pc_name text,
  p_is_default boolean default false
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_pc_name text;
  v_make_default boolean;
  v_has_active boolean := false;
  v_character_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_pc_name := nullif(trim(coalesce(p_pc_name, '')), '');
  if v_pc_name is null then
    raise exception 'pc_name_required' using errcode = '22023';
  end if;
  if char_length(v_pc_name) > 40 then
    raise exception 'pc_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_pc_name) > 0 or position(chr(13) in v_pc_name) > 0 then
    raise exception 'pc_name_invalid' using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.player_characters as pc
    where pc.owner_user_id = v_actor
      and pc.is_active = true
  )
  into v_has_active;

  v_make_default := coalesce(p_is_default, false) or not v_has_active;

  if v_make_default then
    update public.player_characters as pc
    set is_default = false
    where pc.owner_user_id = v_actor
      and pc.is_active = true;
  end if;

  insert into public.player_characters (
    owner_user_id,
    pc_name,
    is_default,
    is_active
  )
  values (
    v_actor,
    v_pc_name,
    v_make_default,
    true
  )
  returning id into v_character_id;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = v_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

create or replace function public.update_player_character(
  p_character_id uuid,
  p_pc_name text,
  p_is_default boolean default false,
  p_is_active boolean default true
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_pc_name text;
  v_make_default boolean := coalesce(p_is_default, false);
  v_is_active boolean := coalesce(p_is_active, true);
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_pc_name := nullif(trim(coalesce(p_pc_name, '')), '');
  if p_character_id is null or v_pc_name is null then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;
  if char_length(v_pc_name) > 40 then
    raise exception 'pc_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_pc_name) > 0 or position(chr(13) in v_pc_name) > 0 then
    raise exception 'pc_name_invalid' using errcode = '22023';
  end if;

  if v_make_default and v_is_active then
    update public.player_characters as pc
    set is_default = false
    where pc.owner_user_id = v_actor
      and pc.id <> p_character_id
      and pc.is_active = true;
  end if;

  update public.player_characters as pc
  set
    pc_name = v_pc_name,
    is_default = case when v_is_active then v_make_default else false end,
    is_active = v_is_active,
    updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;

  if not found then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

create or replace function public.set_default_player_character(
  p_character_id uuid
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_character_id is null then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.player_characters as pc
    where pc.id = p_character_id
      and pc.owner_user_id = v_actor
      and pc.is_active = true
  ) then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  update public.player_characters as pc
  set is_default = false,
      updated_at = now()
  where pc.owner_user_id = v_actor
    and pc.is_active = true;

  update public.player_characters as pc
  set is_default = true,
      updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor
    and pc.is_active = true;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

create or replace function public.deactivate_player_character(
  p_character_id uuid
)
returns table (
  character_id uuid,
  pc_name text,
  is_default boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  update public.player_characters as pc
  set
    is_default = false,
    is_active = false,
    updated_at = now()
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;

  if not found then
    raise exception 'character_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    pc.id as character_id,
    pc.pc_name,
    pc.is_default,
    pc.is_active,
    pc.created_at,
    pc.updated_at
  from public.player_characters as pc
  where pc.id = p_character_id
    and pc.owner_user_id = v_actor;
end;
$$;

-- Physical deletion is not recommended for the initial feature because
-- session_applications.pc_name_snapshot must remain stable for past sessions.
-- If the UI says "削除", it should call deactivate_player_character.

-- ============================================================
-- SECTION 4: APPLICATION LINK DRAFT
-- DO NOT RUN UNTIL APPLICATION FLOW REVIEW IS COMPLETE.
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
  v_default_character_id uuid;
  v_default_pc_name text;
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

  if not public.can_apply_to_session(target_session_id) then
    raise exception 'session is not open for applications';
  end if;

  select pc.id, pc.pc_name
  into v_default_character_id, v_default_pc_name
  from public.player_characters as pc
  where pc.owner_user_id = auth.uid()
    and pc.is_active = true
    and pc.is_default = true
  order by pc.updated_at desc, pc.created_at desc
  limit 1;

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
      status,
      selected_character_id,
      pc_name_snapshot
    )
    values (
      target_session_id,
      auth.uid(),
      new_comment_id,
      'pending',
      v_default_character_id,
      v_default_pc_name
    );
  elsif existing_status = 'canceled' then
    update public.session_applications
    set
      comment_id = new_comment_id,
      status = 'pending',
      canceled_at = null,
      selected_character_id = v_default_character_id,
      pc_name_snapshot = v_default_pc_name,
      updated_at = now()
    where session_id = target_session_id
      and user_id = auth.uid();
  else
    null;
  end if;

  return new_comment_id;
end;
$$;

create or replace function public.update_my_application_character(
  target_session_id text,
  target_character_id uuid
)
returns table (
  session_id text,
  application_status text,
  pc_name_snapshot text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_session_id text := nullif(trim(coalesce(target_session_id, '')), '');
  v_pc_name text;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if v_target_session_id is null then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if target_character_id is not null then
    select pc.pc_name
    into v_pc_name
    from public.player_characters as pc
    where pc.id = target_character_id
      and pc.owner_user_id = v_actor
      and pc.is_active = true;

    if v_pc_name is null then
      raise exception 'character_not_found' using errcode = 'P0002';
    end if;
  end if;

  return query
  update public.session_applications as sa
  set
    selected_character_id = target_character_id,
    pc_name_snapshot = v_pc_name,
    updated_at = now()
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor
    and sa.status in ('pending', 'waitlisted', 'accepted')
  returning
    sa.session_id,
    sa.status as application_status,
    sa.pc_name_snapshot,
    sa.updated_at;

  if not found then
    raise exception 'application_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- Review note:
-- - The create_application_comment replacement above must be reviewed against
--   GM comment handling. Current frontend cancels GM's own application row after
--   GM comment submission; the snapshot update must not make GM a participant.
-- - Existing PL withdraw / reapply behavior should keep working. Reapply should
--   refresh pc_name_snapshot from the current default PC.

-- ============================================================
-- SECTION 5: GM / TEMPLATE DATA DRAFT
-- DO NOT RUN UNTIL FRONTEND CONTRACT IS REVIEWED.
-- ============================================================

create or replace function public.get_gm_session_approved_template_data(
  target_session_id text
)
returns table (
  session_title text,
  display_name text,
  discord_handle text,
  pc_name_snapshot text
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
    s.title::text as session_title,
    coalesce(nullif(trim(p.display_name), ''), '名前未設定')::text as display_name,
    p.discord_handle::text as discord_handle,
    sa.pc_name_snapshot::text as pc_name_snapshot
  from public.session_applications as sa
  join public.sessions as s
    on s.id = sa.session_id
  join public.profiles as p
    on p.id = sa.user_id
  where sa.session_id = v_target_session_id
    and sa.status = 'accepted'
    and not (
      s.gm_user_id is not null
      and sa.user_id = s.gm_user_id
    )
  order by
    p.display_name asc nulls last,
    sa.updated_at desc nulls last,
    sa.created_at desc nulls last;
end;
$$;

-- This separate template RPC avoids changing the current
-- get_gm_session_accepted_contacts return columns before the frontend is ready.
-- A later M-15F step may either connect to this RPC or replace the existing
-- contact RPC after JS assertions and UI text are updated.

-- ============================================================
-- SECTION 6: PRIVILEGE DRAFT
-- DO NOT RUN UNTIL ALL ROUTINE CONTRACTS ARE FINAL.
-- ============================================================

revoke all on function public.get_my_player_characters() from public;
revoke all on function public.get_my_player_characters() from anon;
revoke all on function public.get_my_player_characters() from authenticated;

revoke all on function public.create_player_character(text, boolean) from public;
revoke all on function public.create_player_character(text, boolean) from anon;
revoke all on function public.create_player_character(text, boolean) from authenticated;

revoke all on function public.update_player_character(uuid, text, boolean, boolean) from public;
revoke all on function public.update_player_character(uuid, text, boolean, boolean) from anon;
revoke all on function public.update_player_character(uuid, text, boolean, boolean) from authenticated;

revoke all on function public.set_default_player_character(uuid) from public;
revoke all on function public.set_default_player_character(uuid) from anon;
revoke all on function public.set_default_player_character(uuid) from authenticated;

revoke all on function public.deactivate_player_character(uuid) from public;
revoke all on function public.deactivate_player_character(uuid) from anon;
revoke all on function public.deactivate_player_character(uuid) from authenticated;

revoke all on function public.update_my_application_character(text, uuid) from public;
revoke all on function public.update_my_application_character(text, uuid) from anon;
revoke all on function public.update_my_application_character(text, uuid) from authenticated;

revoke all on function public.get_gm_session_approved_template_data(text) from public;
revoke all on function public.get_gm_session_approved_template_data(text) from anon;
revoke all on function public.get_gm_session_approved_template_data(text) from authenticated;

grant execute on function public.get_my_player_characters() to authenticated;
grant execute on function public.create_player_character(text, boolean) to authenticated;
grant execute on function public.update_player_character(uuid, text, boolean, boolean) to authenticated;
grant execute on function public.set_default_player_character(uuid) to authenticated;
grant execute on function public.deactivate_player_character(uuid) to authenticated;
grant execute on function public.update_my_application_character(text, uuid) to authenticated;
grant execute on function public.get_gm_session_approved_template_data(text) to authenticated;

notify pgrst, 'reload schema';

-- ============================================================
-- SECTION 7: POST-APPLY CHECK DRAFT
-- RUN ONLY AFTER A REVIEWED APPLY STEP IN A LATER TASK.
-- ============================================================

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'player_characters'
order by ordinal_position;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_applications'
  and column_name in ('selected_character_id', 'pc_name_snapshot')
order by ordinal_position;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'set_default_player_character',
    'deactivate_player_character',
    'update_my_application_character',
    'get_gm_session_approved_template_data'
  )
order by p.proname, p.oid::regprocedure::text;

-- Expected later:
-- - player_characters exists and is protected by RLS.
-- - session_applications has selected_character_id and pc_name_snapshot.
-- - PC management RPCs are authenticated only.
-- - Template data RPC returns no user_id, email, application_id, comment_id,
--   character_id, owner_user_id, token, key, or secret values.
-- - Existing get_gm_session_accepted_contacts remains compatible until frontend
--   is explicitly updated.
