-- 085_membership_management_delegation_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Prepare delegated community membership management without granting admin.
-- - Allow admin to grant/revoke the limited membership_approver role.
-- - Allow admin or approved membership_approver users to manage normal member
--   review status across pending / approved / rejected.
--
-- Scope:
-- - public.list_membership_review_users(text, integer)
-- - public.set_member_review_status(uuid, text, text)
-- - public.grant_membership_manager(uuid)
-- - public.revoke_membership_manager(uuid)
-- - Add a private community_memberships.management_key action key so the
--   management UI does not need raw auth user ids.
--
-- Out of scope:
-- - SQL Editor execution by Codex.
-- - Approved gates for the remaining RPC categories.
-- - Revoked / blocked force management.
-- - Admin role grant/revoke.
-- - Membership management UI implementation.
-- - Email, invite code, Auth hooks, Edge Functions, Discord, Storage, or
--   Dashboard changes.
--
-- Safety notes:
-- - This draft does not expose email.
-- - This draft does not add membership state to public_profiles.
-- - This draft does not open direct table grants on community_memberships.
-- - The member_key returned by the list RPC is for RPC actions only and must
--   not be rendered or logged by the UI. It is not auth.users.id.
-- - No real email, user id, session id, full URL, project ref, token, key, or
--   secret is recorded.

begin;

alter table public.community_memberships
  add column if not exists management_key uuid;

alter table public.community_memberships
  alter column management_key set default gen_random_uuid();

update public.community_memberships cm
set management_key = gen_random_uuid()
where cm.management_key is null;

alter table public.community_memberships
  alter column management_key set not null;

create unique index if not exists community_memberships_management_key_key
  on public.community_memberships(management_key);

comment on column public.community_memberships.management_key is
  'Opaque management action key for membership UI RPC calls. Do not display or log.';

create or replace function public.list_membership_review_users(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  member_key uuid,
  display_name text,
  discord_handle text,
  status text,
  review_note text,
  created_at timestamptz,
  updated_at timestamptz,
  reviewed_at timestamptz,
  is_membership_manager boolean,
  is_admin_user boolean,
  can_manage_status boolean,
  can_manage_manager_role boolean
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_filter_status text := nullif(trim(coalesce(p_status, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_is_admin boolean := public.is_admin();
  v_is_approved_manager boolean :=
    public.is_membership_approver()
    and public.has_role('membership_approver')
    and public.is_approved_member();
begin
  if v_actor_id is null or not (v_is_admin or v_is_approved_manager) then
    raise exception '会員管理権限がありません。'
      using errcode = '42501';
  end if;

  if v_filter_status is not null
     and v_filter_status not in ('pending', 'approved', 'rejected') then
    raise exception '指定できない会員状態です。'
      using errcode = '22023';
  end if;

  return query
  select
    cm.management_key as member_key,
    coalesce(nullif(trim(p.display_name), ''), 'ユーザー名未設定')::text as display_name,
    nullif(trim(p.discord_handle), '')::text as discord_handle,
    cm.status,
    cm.review_note,
    cm.created_at,
    cm.updated_at,
    case
      when cm.status = 'approved' then cm.approved_at
      when cm.status = 'rejected' then cm.rejected_at
      else null
    end as reviewed_at,
    exists (
      select 1
      from public.user_roles ur_manager
      where ur_manager.user_id = cm.user_id
        and ur_manager.role = 'membership_approver'
    ) as is_membership_manager,
    exists (
      select 1
      from public.user_roles ur_admin
      where ur_admin.user_id = cm.user_id
        and ur_admin.role = 'admin'
    ) as is_admin_user,
    (
      cm.user_id <> v_actor_id
      and cm.status in ('pending', 'approved', 'rejected')
      and not exists (
        select 1
        from public.user_roles ur_admin_guard
        where ur_admin_guard.user_id = cm.user_id
          and ur_admin_guard.role = 'admin'
      )
      and (
        v_is_admin
        or not exists (
          select 1
          from public.user_roles ur_manager_guard
          where ur_manager_guard.user_id = cm.user_id
            and ur_manager_guard.role = 'membership_approver'
        )
      )
    ) as can_manage_status,
    (
      v_is_admin
      and cm.user_id <> v_actor_id
      and cm.status = 'approved'
      and not exists (
        select 1
        from public.user_roles ur_admin_guard
        where ur_admin_guard.user_id = cm.user_id
          and ur_admin_guard.role = 'admin'
      )
    ) as can_manage_manager_role
  from public.community_memberships cm
  left join public.profiles p
    on p.id = cm.user_id
  where cm.status in ('pending', 'approved', 'rejected')
    and (v_filter_status is null or cm.status = v_filter_status)
  order by
    case cm.status
      when 'pending' then 1
      when 'rejected' then 2
      when 'approved' then 3
      else 9
    end,
    cm.updated_at desc,
    cm.created_at asc,
    cm.user_id asc
  limit v_limit;
end;
$$;

comment on function public.list_membership_review_users(text, integer) is
  'List normal membership review users for admin or approved membership managers. Does not return email; member_key is for RPC actions only.';

create or replace function public.set_member_review_status(
  p_target_member_key uuid,
  p_new_status text,
  p_review_note text
)
returns table (
  member_key uuid,
  status text,
  review_note text,
  approved_at timestamptz,
  rejected_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_new_status text := nullif(trim(coalesce(p_new_status, '')), '');
  v_review_note text := nullif(trim(coalesce(p_review_note, '')), '');
  v_target_user_id uuid;
  v_current_status text;
  v_is_admin boolean := public.is_admin();
  v_is_approved_manager boolean :=
    public.is_membership_approver()
    and public.has_role('membership_approver')
    and public.is_approved_member();
begin
  if v_actor_id is null or not (v_is_admin or v_is_approved_manager) then
    raise exception '会員管理権限がありません。'
      using errcode = '42501';
  end if;

  if p_target_member_key is null then
    raise exception 'この会員状態は変更できません。'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = v_actor_id) then
    raise exception '会員管理権限がありません。'
      using errcode = '42501';
  end if;

  if v_new_status is null
     or v_new_status not in ('pending', 'approved', 'rejected') then
    raise exception '指定できない会員状態です。'
      using errcode = '22023';
  end if;

  if v_review_note is not null and char_length(v_review_note) > 1000 then
    raise exception 'メモは1000文字以内で入力してください。'
      using errcode = '22023';
  end if;

  select cm.user_id, cm.status
  into v_target_user_id, v_current_status
  from public.community_memberships cm
  where cm.management_key = p_target_member_key
  for update;

  if v_target_user_id is null or v_current_status is null then
    raise exception '対象の会員状態を確認できません。'
      using errcode = '22023';
  end if;

  if v_target_user_id = v_actor_id then
    raise exception 'この会員状態は変更できません。'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.user_roles ur_admin
    where ur_admin.user_id = v_target_user_id
      and ur_admin.role = 'admin'
  ) then
    raise exception '管理者の会員状態はこの画面では変更できません。'
      using errcode = '42501';
  end if;

  if not v_is_admin and exists (
    select 1
    from public.user_roles ur_manager
    where ur_manager.user_id = v_target_user_id
      and ur_manager.role = 'membership_approver'
  ) then
    raise exception 'この会員状態は変更できません。'
      using errcode = '42501';
  end if;

  if v_current_status in ('revoked', 'blocked') then
    raise exception 'この会員状態は変更できません。'
      using errcode = '42501';
  end if;

  if not (
    (v_current_status = 'pending' and v_new_status in ('approved', 'rejected'))
    or (v_current_status = 'rejected' and v_new_status = 'approved')
    or (v_current_status = 'approved' and v_new_status = 'rejected')
    or (v_current_status = v_new_status)
  ) then
    raise exception 'この会員状態は変更できません。'
      using errcode = '22023';
  end if;

  return query
  update public.community_memberships cm
  set
    status = v_new_status,
    approved_at = case
      when v_new_status = 'approved' and v_current_status <> 'approved' then now()
      when v_new_status = 'approved' then cm.approved_at
      else null
    end,
    approved_by = case
      when v_new_status = 'approved' and v_current_status <> 'approved' then v_actor_id
      when v_new_status = 'approved' then cm.approved_by
      else null
    end,
    rejected_at = case
      when v_new_status = 'rejected' and v_current_status <> 'rejected' then now()
      when v_new_status = 'rejected' then cm.rejected_at
      else null
    end,
    rejected_by = case
      when v_new_status = 'rejected' and v_current_status <> 'rejected' then v_actor_id
      when v_new_status = 'rejected' then cm.rejected_by
      else null
    end,
    review_note = v_review_note
  where cm.management_key = p_target_member_key
  returning
    cm.management_key as member_key,
    cm.status,
    cm.review_note,
    cm.approved_at,
    cm.rejected_at,
    cm.updated_at;
end;
$$;

comment on function public.set_member_review_status(uuid, text, text) is
  'Switch normal membership review status among pending, approved, and rejected. Admin targets, self actions, revoked, and blocked are excluded.';

create or replace function public.grant_membership_manager(p_target_member_key uuid)
returns table (
  member_key uuid,
  role text,
  membership_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_user_id uuid;
  v_status text;
begin
  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception '会員管理権限がありません。'
      using errcode = '42501';
  end if;

  if p_target_member_key is null then
    raise exception 'この権限は変更できません。'
      using errcode = '42501';
  end if;

  select cm.user_id, cm.status
  into v_target_user_id, v_status
  from public.community_memberships cm
  where cm.management_key = p_target_member_key;

  if v_target_user_id is null or v_status is null then
    raise exception '対象の会員状態を確認できません。'
      using errcode = '22023';
  end if;

  if v_target_user_id = v_actor_id then
    raise exception 'この権限は変更できません。'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.user_roles ur_admin
    where ur_admin.user_id = v_target_user_id
      and ur_admin.role = 'admin'
  ) then
    raise exception '管理者の権限はこの画面では変更できません。'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = v_target_user_id) then
    raise exception '対象の会員状態を確認できません。'
      using errcode = '22023';
  end if;

  if v_status is distinct from 'approved' then
    raise exception '承認済みユーザーのみ委任できます。'
      using errcode = '22023';
  end if;

  insert into public.user_roles (user_id, role)
  values (v_target_user_id, 'membership_approver')
  on conflict (user_id, role) do nothing;

  return query
  select
    p_target_member_key as member_key,
    'membership_approver'::text as role,
    v_status as membership_status;
end;
$$;

comment on function public.grant_membership_manager(uuid) is
  'Admin-only helper to grant the limited membership_approver role to an approved non-admin user.';

create or replace function public.revoke_membership_manager(p_target_member_key uuid)
returns table (
  member_key uuid,
  role text,
  membership_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_user_id uuid;
  v_status text;
begin
  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception '会員管理権限がありません。'
      using errcode = '42501';
  end if;

  if p_target_member_key is null then
    raise exception 'この権限は変更できません。'
      using errcode = '42501';
  end if;

  select cm.user_id, cm.status
  into v_target_user_id, v_status
  from public.community_memberships cm
  where cm.management_key = p_target_member_key;

  if v_target_user_id is null or v_status is null then
    raise exception '対象の会員状態を確認できません。'
      using errcode = '22023';
  end if;

  if v_target_user_id = v_actor_id then
    raise exception 'この権限は変更できません。'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.user_roles ur_admin
    where ur_admin.user_id = v_target_user_id
      and ur_admin.role = 'admin'
  ) then
    raise exception '管理者の権限はこの画面では変更できません。'
      using errcode = '42501';
  end if;

  delete from public.user_roles ur
  where ur.user_id = v_target_user_id
    and ur.role = 'membership_approver';

  return query
  select
    p_target_member_key as member_key,
    'membership_approver'::text as role,
    coalesce(v_status, 'unknown')::text as membership_status;
end;
$$;

comment on function public.revoke_membership_manager(uuid) is
  'Admin-only helper to revoke the limited membership_approver role from a non-admin user.';

revoke all on function public.list_membership_review_users(text, integer) from public;
revoke all on function public.list_membership_review_users(text, integer) from anon;
revoke all on function public.list_membership_review_users(text, integer) from authenticated;

revoke all on function public.set_member_review_status(uuid, text, text) from public;
revoke all on function public.set_member_review_status(uuid, text, text) from anon;
revoke all on function public.set_member_review_status(uuid, text, text) from authenticated;

revoke all on function public.grant_membership_manager(uuid) from public;
revoke all on function public.grant_membership_manager(uuid) from anon;
revoke all on function public.grant_membership_manager(uuid) from authenticated;

revoke all on function public.revoke_membership_manager(uuid) from public;
revoke all on function public.revoke_membership_manager(uuid) from anon;
revoke all on function public.revoke_membership_manager(uuid) from authenticated;

grant execute on function public.list_membership_review_users(text, integer) to authenticated;
grant execute on function public.set_member_review_status(uuid, text, text) to authenticated;
grant execute on function public.grant_membership_manager(uuid) to authenticated;
grant execute on function public.revoke_membership_manager(uuid) to authenticated;

commit;
