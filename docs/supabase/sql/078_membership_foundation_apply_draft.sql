-- 078_membership_foundation_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Prepare the foundation for community membership approval.
-- - Backfill existing users as approved.
-- - Create pending membership rows for future signups.
-- - Add helper RPCs for membership checks without adding approved gates yet.
--
-- Scope:
-- - Add public.community_memberships.
-- - Extend the existing role model to allow membership_approver.
-- - Add public.is_approved_member().
-- - Add public.is_membership_approver().
-- - Add public.get_my_membership_status().
-- - Add a separate auth.users insert trigger for membership rows.
--
-- Out of scope:
-- - Approved-member gates for the 34 candidate RPCs.
-- - Approve/reject UI.
-- - Approve/reject RPCs.
-- - Dedicated community_membership_events audit log table.
-- - Admin role-management RPCs.
-- - Invite codes.
-- - Before User Created hooks.
-- - Email hash deny lists.
-- - Discord, mail, Edge Function, or Storage changes.
--
-- Safety notes:
-- - This draft does not replace public.handle_new_auth_user_profile().
-- - This draft adds a separate membership trigger so the existing profile
--   creation path remains intact.
-- - Membership status is kept out of public.public_profiles.
-- - No real email, user id, session id, full URL, project ref, token, key, or
--   secret is recorded.

begin;

-- 1. Membership table. The primary key points at auth.users so membership row
-- creation does not depend on auth-profile trigger ordering.
create table if not exists public.community_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'pending',
  approved_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  rejected_at timestamptz,
  rejected_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  blocked_at timestamptz,
  blocked_by uuid references public.profiles(id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_memberships_status_check check (
    status in ('pending', 'approved', 'rejected', 'revoked', 'blocked')
  ),
  constraint community_memberships_review_note_length_check check (
    review_note is null or char_length(review_note) <= 1000
  )
);

comment on table public.community_memberships is
  'Private community membership approval state. Do not expose through public_profiles.';

comment on column public.community_memberships.review_note is
  'Short non-secret review note. Do not store emails, tokens, full URLs, or private credentials.';

create index if not exists community_memberships_status_created_idx
  on public.community_memberships(status, created_at desc);

create index if not exists community_memberships_updated_idx
  on public.community_memberships(updated_at desc);

drop trigger if exists community_memberships_set_updated_at on public.community_memberships;
create trigger community_memberships_set_updated_at
before update on public.community_memberships
for each row execute function public.set_updated_at();

alter table public.community_memberships enable row level security;

revoke all on table public.community_memberships from public;
revoke all on table public.community_memberships from anon;
revoke all on table public.community_memberships from authenticated;

-- 2. Extend the existing role storage to allow the limited approver role.
alter table public.user_roles
  drop constraint if exists user_roles_role_check;

alter table public.user_roles
  add constraint user_roles_role_check check (
    role in ('player', 'gm', 'admin', 'membership_approver')
  );

-- Keep the existing role helper behavior and extend the accepted role list.
create or replace function public.has_role(role_name text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    role_name in ('player', 'gm', 'admin', 'membership_approver')
    and auth.uid() is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role = role_name
    );
$$;

revoke all on function public.has_role(text) from public;
grant execute on function public.has_role(text) to authenticated;

-- 3. Membership helpers.
create or replace function public.is_membership_approver()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      public.is_admin()
      or public.has_role('membership_approver')
    );
$$;

create or replace function public.is_approved_member()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.community_memberships cm
      where cm.user_id = auth.uid()
        and cm.status = 'approved'
    );
$$;

create or replace function public.get_my_membership_status()
returns table (
  status text,
  review_note text,
  approved_at timestamptz,
  rejected_at timestamptz,
  revoked_at timestamptz,
  blocked_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    coalesce(cm.status, 'pending') as status,
    cm.review_note,
    cm.approved_at,
    cm.rejected_at,
    cm.revoked_at,
    cm.blocked_at,
    cm.created_at,
    cm.updated_at
  from (select auth.uid() as current_user_id) current_user
  left join public.community_memberships cm
    on cm.user_id = current_user.current_user_id
  where current_user.current_user_id is not null;
$$;

revoke all on function public.is_membership_approver() from public;
revoke all on function public.is_approved_member() from public;
revoke all on function public.get_my_membership_status() from public;

grant execute on function public.is_membership_approver() to authenticated;
grant execute on function public.is_approved_member() to authenticated;
grant execute on function public.get_my_membership_status() to authenticated;

-- 4. RLS policies are defined after the helper they reference exists.
drop policy if exists community_memberships_select_own on public.community_memberships;
drop policy if exists community_memberships_select_admin_approver on public.community_memberships;

create policy community_memberships_select_own
on public.community_memberships
for select
to authenticated
using (user_id = auth.uid());

create policy community_memberships_select_admin_approver
on public.community_memberships
for select
to authenticated
using (public.is_membership_approver());

-- 5. Backfill existing auth users as approved.
insert into public.community_memberships (
  user_id,
  status,
  approved_at,
  review_note
)
select
  au.id,
  'approved',
  now(),
  'Initial approved backfill before the community membership approval gate.'
from auth.users au
where not exists (
  select 1
  from public.community_memberships cm
  where cm.user_id = au.id
)
on conflict (user_id) do nothing;

-- 6. Future auth users start pending through a separate trigger.
create or replace function public.handle_new_auth_user_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.community_memberships (
    user_id,
    status
  )
  values (
    new.id,
    'pending'
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_auth_user_membership() from public;

drop trigger if exists on_auth_user_created_create_membership on auth.users;

create trigger on_auth_user_created_create_membership
after insert on auth.users
for each row execute function public.handle_new_auth_user_membership();

commit;
