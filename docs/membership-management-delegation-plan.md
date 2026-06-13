# Membership Management Delegation Plan

This document prepares the next community-membership management gate. It is
non-destructive: no SQL Editor execution, SQL apply, DB/RPC/RLS mutation,
Dashboard change, Edge deploy, Discord operation, or secret change is performed
in this planning batch.

## Current State

- Membership state lives in `public.community_memberships`.
- Supported statuses are `pending`, `approved`, `rejected`, `revoked`, and
  `blocked`.
- Existing users were backfilled as `approved`; new signups start as `pending`.
- `public_profiles` does not expose membership or role state.
- `is_approved_member()`, `is_membership_approver()`, and
  `get_my_membership_status()` are already applied.
- Existing approval RPCs only cover pending users:
  `get_pending_community_members(integer)`,
  `approve_community_member(uuid,text)`, and
  `reject_community_member(uuid,text)`.
- The current mypage approval panel is therefore pending-only.

## Needed Change

Operations should no longer depend on admin alone:

- Admin remains the master role.
- A delegated `membership_approver` / membership manager role may handle normal
  approval and rejection operations without receiving admin authority.
- Approved users may be switched to rejected.
- Rejected users may be approved again.
- Pending users may be approved or rejected.
- Revoked and blocked states remain outside normal delegated management.

## SQL Drafts

Prepared but not executed:

- `docs/supabase/sql/085_membership_management_delegation_apply_draft.sql`
- `docs/supabase/sql/086_membership_management_delegation_post_apply_select_only.sql`

The 085 draft adds four RPCs:

- `list_membership_review_users(text, integer)`
- `set_member_review_status(uuid, text, text)`
- `grant_membership_manager(uuid)`
- `revoke_membership_manager(uuid)`

The draft keeps existing pending-only RPCs intact for compatibility.

Apply-before review update:

- Initial review found that the first 085 draft used `community_memberships.user_id`
  as the management action key. That would have returned raw auth user ids to the
  management UI, so the draft was corrected before apply.
- Revised 085 adds an opaque private `community_memberships.management_key` and
  uses it as `member_key` for management RPC calls.
- Revised 086 checks that `management_key` exists, the list RPC returns that
  opaque key, mutation RPCs resolve targets through that key, and no RPC return
  type exposes a `user_id` column.
- The same review narrowed normal status transitions to
  `pending -> approved`, `pending -> rejected`, `rejected -> approved`, and
  `approved -> rejected`; `rejected -> pending` is no longer included.
- Non-admin membership managers are also blocked from changing users who already
  hold `membership_approver`, preventing an indirect manager-role revocation.
- No SQL Editor execution or SQL apply has been performed after these draft
  fixes. The next gate is a fresh apply-before review of the revised 085/086.

Second apply-before review:

- Revised 085 was reviewed again from baseline
  `b2f95e0 Revise membership delegation apply draft`.
- `management_key` generation, backfill, default, NOT NULL, and unique-index
  setup are present and scoped to `community_memberships`.
- `list_membership_review_users` returns the opaque `member_key` plus display
  data needed by the management UI; it does not return raw auth user ids, email,
  or tokens.
- `set_member_review_status`, `grant_membership_manager`, and
  `revoke_membership_manager` accept the opaque member key and resolve the raw
  user id internally.
- Admin remains the only role that can grant or revoke `membership_approver`.
- Approved `membership_approver` users can manage normal review status only;
  they cannot change admin targets, themselves, or other membership managers.
- Allowed transitions remain `pending -> approved`, `pending -> rejected`,
  `rejected -> approved`, and `approved -> rejected`; `rejected -> pending`,
  `approved -> pending`, `revoked`, and `blocked` are outside normal management.
- 086 was strengthened during review so the public profile exposure check also
  catches management-key surface columns.
- Review result: no remaining blocker was found. 085 can proceed to a separate
  SQL Editor gate for one-time execution, followed by 086 SELECT-only
  confirmation.

## Authorization Rules

- `list_membership_review_users` and `set_member_review_status` are available
  only to admin or approved users with the `membership_approver` role.
- `grant_membership_manager` and `revoke_membership_manager` are admin-only.
- Membership managers cannot grant roles, grant admin, or modify admin users.
- Membership managers cannot change another membership manager's status unless
  the actor is admin.
- Self approval, self rejection, and self manager-role changes are blocked.
- Manager role grant requires the target to be approved and non-admin.
- Manager role revoke can remove the delegated role from a non-admin target.

## Status Transitions

Allowed in 085:

- `pending -> approved`
- `pending -> rejected`
- `rejected -> approved`
- `approved -> rejected`

Not allowed in 085:

- `approved -> pending`
- `rejected -> pending`
- Any normal management transition from `revoked` or `blocked`
- Any status change for admin users

`approved -> pending` and `rejected -> pending` are intentionally not included
because they are not needed for the current operation model and could confuse
review state. If a review-reopen operation becomes necessary later, it should be
designed as a separate gate.

## UI Plan

After 085 is applied and 086 confirms all checks:

- Replace or extend the current mypage approval panel with a broader
  membership-management panel.
- Show the panel only to admin or approved `membership_approver` users.
- Show display name, Discord handle if present, current status, and short
  status notes.
- Do not display email, raw user id, internal membership id, tokens, or full
  URLs.
- Use an internal action key returned by RPC only for button calls; do not
  render or log it.
- Pending rows show approve/reject actions.
- Approved rows show reject action.
- Rejected rows show approve action.
- Admin-only controls can grant/revoke `membership_approver`.
- All status or role changes require a short confirmation dialog.
- Errors should be short Japanese messages without SQL detail or identifiers.

## QA Plan

Run only after the SQL apply and UI gate are separately approved:

- Admin can see the management panel.
- Approved `membership_approver` can see the management panel.
- Normal approved users cannot see the panel.
- Pending users can be approved and rejected.
- Approved users can be switched to rejected.
- Rejected users can be approved again.
- Membership manager cannot modify admin users.
- Membership manager cannot modify another membership manager's status.
- Membership manager cannot grant or revoke membership manager authority.
- Admin can grant and revoke membership manager authority for approved
  non-admin users.
- Self status changes and self manager-role changes are rejected.
- `public_profiles` still does not expose membership or role state.
- No raw ids, email addresses, tokens, or full URLs are displayed or recorded.

## Stop Conditions

Stop before apply or implementation if:

- Existing membership status semantics are unclear.
- The role boundary would let membership managers grant admin or demote admins.
- The UI would need to display email or raw identifiers.
- The design would require `public_profiles` membership/role exposure.
- Direct table grants would be needed.
- SQL Editor execution, DB/RPC/RLS mutation, Edge deploy, Discord operation, or
  secret changes become necessary in the current gate.
