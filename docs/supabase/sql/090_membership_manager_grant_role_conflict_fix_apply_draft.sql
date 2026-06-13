-- 090_membership_manager_grant_role_conflict_fix_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Fix a likely grant_membership_manager runtime definition issue where the
--   returned column name `role` can collide with an unqualified role reference
--   around duplicate-safe user_roles insertion.
-- - Keep the existing signature, return shape, admin-only guard, target guard,
--   profile guard, and authenticated-only EXECUTE surface.
--
-- Scope:
-- - Replace only public.grant_membership_manager(uuid).
-- - Do not change tables, RLS policies, direct grants, public_profiles,
--   membership status semantics, or UI.
--
-- Safety:
-- - This draft does not include concrete user ids, email addresses,
--   management_key values, URLs, JWTs, tokens, project refs, Webhook values,
--   API keys, or secrets.

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
  on conflict do nothing;

  return query
  select
    p_target_member_key,
    'membership_approver'::text,
    v_status::text;
end;
$$;

comment on function public.grant_membership_manager(uuid) is
  'Admin-only helper to grant the limited membership_approver role to an approved non-admin user. Uses conflict-safe insertion without an ambiguous role conflict target.';

revoke all on function public.grant_membership_manager(uuid) from public;
revoke all on function public.grant_membership_manager(uuid) from anon;
revoke all on function public.grant_membership_manager(uuid) from authenticated;

grant execute on function public.grant_membership_manager(uuid) to authenticated;
