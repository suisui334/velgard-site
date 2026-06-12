-- 081_membership_approval_rpc_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Add the minimum RPC surface for community membership approval.
-- - Allow admin or approved membership_approver users to list pending members.
-- - Allow admin or approved membership_approver users to approve/reject pending
--   members only.
--
-- Scope:
-- - public.get_pending_community_members(integer)
-- - public.approve_community_member(uuid, text)
-- - public.reject_community_member(uuid, text)
--
-- Out of scope:
-- - The 34 approved-member gates.
-- - Approver UI.
-- - Role grant/revoke RPCs.
-- - Forced status changes for approved/revoked/blocked users.
-- - Invite codes.
-- - Before User Created hooks.
-- - Send Email hooks or Auth email locking.
-- - Email hash deny lists.
-- - Discord, mail, Edge Function, Storage, or Dashboard changes.
--
-- Safety notes:
-- - This draft does not expose email.
-- - This draft does not add membership state to public_profiles.
-- - This draft does not open direct table grants on community_memberships.
-- - No real email, user id, session id, full URL, project ref, token, key, or
--   secret is recorded.

begin;

create or replace function public.get_pending_community_members(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  discord_handle text,
  status text,
  review_note text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_is_admin boolean := public.is_admin();
  v_is_approved_approver boolean :=
    public.is_membership_approver()
    and public.has_role('membership_approver')
    and public.is_approved_member();
begin
  if v_actor_id is null or not (v_is_admin or v_is_approved_approver) then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  return query
  select
    cm.user_id,
    coalesce(nullif(trim(p.display_name), ''), 'display_name_not_set')::text as display_name,
    nullif(trim(p.discord_handle), '')::text as discord_handle,
    cm.status,
    cm.review_note,
    cm.created_at,
    cm.updated_at
  from public.community_memberships cm
  left join public.profiles p
    on p.id = cm.user_id
  where cm.status = 'pending'
  order by cm.created_at asc, cm.user_id asc
  limit v_limit;
end;
$$;

comment on function public.get_pending_community_members(integer) is
  'List pending community memberships for admin or approved membership approvers. Does not return email.';

create or replace function public.approve_community_member(
  p_target_user_id uuid,
  p_review_note text
)
returns table (
  user_id uuid,
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
  v_review_note text := nullif(trim(coalesce(p_review_note, '')), '');
  v_is_admin boolean := public.is_admin();
  v_is_approved_approver boolean :=
    public.is_membership_approver()
    and public.has_role('membership_approver')
    and public.is_approved_member();
begin
  if v_actor_id is null or not (v_is_admin or v_is_approved_approver) then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if p_target_user_id is null or p_target_user_id = v_actor_id then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = v_actor_id) then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if v_review_note is not null and char_length(v_review_note) > 1000 then
    raise exception 'review_note_too_long'
      using errcode = '22023';
  end if;

  return query
  update public.community_memberships cm
  set
    status = 'approved',
    approved_at = now(),
    approved_by = v_actor_id,
    rejected_at = null,
    rejected_by = null,
    revoked_at = null,
    revoked_by = null,
    blocked_at = null,
    blocked_by = null,
    review_note = v_review_note
  where cm.user_id = p_target_user_id
    and cm.status = 'pending'
  returning
    cm.user_id,
    cm.status,
    cm.review_note,
    cm.approved_at,
    cm.rejected_at,
    cm.updated_at;

  if not found then
    raise exception 'membership_not_pending'
      using errcode = '22023';
  end if;
end;
$$;

comment on function public.approve_community_member(uuid, text) is
  'Approve a pending community membership. Limited to admin or approved membership approvers.';

create or replace function public.reject_community_member(
  p_target_user_id uuid,
  p_review_note text
)
returns table (
  user_id uuid,
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
  v_review_note text := nullif(trim(coalesce(p_review_note, '')), '');
  v_is_admin boolean := public.is_admin();
  v_is_approved_approver boolean :=
    public.is_membership_approver()
    and public.has_role('membership_approver')
    and public.is_approved_member();
begin
  if v_actor_id is null or not (v_is_admin or v_is_approved_approver) then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if p_target_user_id is null or p_target_user_id = v_actor_id then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = v_actor_id) then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;

  if v_review_note is not null and char_length(v_review_note) > 1000 then
    raise exception 'review_note_too_long'
      using errcode = '22023';
  end if;

  return query
  update public.community_memberships cm
  set
    status = 'rejected',
    approved_at = null,
    approved_by = null,
    rejected_at = now(),
    rejected_by = v_actor_id,
    revoked_at = null,
    revoked_by = null,
    blocked_at = null,
    blocked_by = null,
    review_note = v_review_note
  where cm.user_id = p_target_user_id
    and cm.status = 'pending'
  returning
    cm.user_id,
    cm.status,
    cm.review_note,
    cm.approved_at,
    cm.rejected_at,
    cm.updated_at;

  if not found then
    raise exception 'membership_not_pending'
      using errcode = '22023';
  end if;
end;
$$;

comment on function public.reject_community_member(uuid, text) is
  'Reject a pending community membership. Limited to admin or approved membership approvers.';

revoke all on function public.get_pending_community_members(integer) from public;
revoke all on function public.get_pending_community_members(integer) from anon;
revoke all on function public.get_pending_community_members(integer) from authenticated;

revoke all on function public.approve_community_member(uuid, text) from public;
revoke all on function public.approve_community_member(uuid, text) from anon;
revoke all on function public.approve_community_member(uuid, text) from authenticated;

revoke all on function public.reject_community_member(uuid, text) from public;
revoke all on function public.reject_community_member(uuid, text) from anon;
revoke all on function public.reject_community_member(uuid, text) from authenticated;

grant execute on function public.get_pending_community_members(integer) to authenticated;
grant execute on function public.approve_community_member(uuid, text) to authenticated;
grant execute on function public.reject_community_member(uuid, text) to authenticated;

commit;
