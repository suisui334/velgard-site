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

Post-apply confirmation:

- The user ran `085_membership_management_delegation_apply_draft.sql` once in
  SQL Editor and the apply succeeded.
- The user then ran
  `086_membership_management_delegation_post_apply_select_only.sql` once as a
  SELECT-only confirmation, and all checks returned `status=ok`.
- `post_apply_ready_for_membership_management_delegation_qa=true`.
- The four management RPCs exist:
  `list_membership_review_users`, `set_member_review_status`,
  `grant_membership_manager`, and `revoke_membership_manager`.
- All four RPCs are `security definer` with `search_path=public`.
- EXECUTE grants are limited to `authenticated`; `anon` and `public` are not
  executable.
- Admin / approved membership manager guards, admin-only manager-role
  grant/revoke, self-action guard, target-admin guard, and non-admin
  manager-target guard all confirmed OK.
- Normal management is limited to `pending`, `approved`, and `rejected`;
  `revoked`, `blocked`, `rejected -> pending`, and `approved -> pending` remain
  outside normal management.
- `management_key` column, unique index, list return, and mutation lookup were
  confirmed OK, with no raw `user_id` column returned.
- Email surface, direct `community_memberships` write grants, and
  `public_profiles` membership/role/management-key exposure all confirmed OK.
- At the post-apply confirmation point, the frontend membership management UI
  was still not implemented. The later UI implementation gate is recorded
  below, and functional QA remains a separate gate.
- No concrete user id, email, management key value, token, JWT, full URL,
  project identifier, or secret is recorded.

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

Implemented in the membership management UI gate:

- The previous pending-only mypage approval panel was replaced with a broader
  membership-management panel.
- The panel is loaded from `list_membership_review_users`; users who cannot call
  the RPC fail closed and do not see the panel.
- The panel is intended only for admin or approved `membership_approver` users.
- It shows display name, optional Discord handle, current membership status,
  review note, and timestamps needed for review.
- Do not display email, raw user id, internal membership id, tokens, or full
  URLs.
- The opaque action key returned as `member_key` is held only in JS memory for
  RPC calls. It is not rendered as visible text or DOM data attributes, and no
  concrete key value is recorded.
- Pending rows show approve/reject actions.
- Approved rows show reject action.
- Rejected rows show approve action.
- Admin-only controls can grant/revoke `membership_approver` when the RPC marks
  the action as allowed.
- All status or role changes require a short confirmation dialog.
- Errors should be short Japanese messages without SQL detail or identifiers.
- The UI groups rows by `pending`, `approved`, and `rejected`; `revoked` and
  `blocked` are not shown as normal management targets.
- The cache-bust for `mypage.html` was updated for the modified CSS/JS.
- This gate did not run SQL Editor, SQL apply, DB/RPC/RLS mutation, Edge deploy,
  Discord operation, direct Supabase writes, or secret changes.
- Functional QA for admin, membership manager, normal approved user, and action
  outcomes remains a separate gate.

## QA Plan

Run after the implemented UI is available on the target environment:

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

## Manager Grant Failure Diagnosis

Current investigation after `c16a036 Add membership management UI`:

- Admin-side UI showed a generic failure when trying to grant the
  membership-manager role to an already-approved user.
- SQL Editor execution, SQL apply, DB/RPC/RLS mutation, and repeated live grant
  attempts were not performed in this investigation.
- Static review found that the frontend calls `grant_membership_manager` and
  `revoke_membership_manager` with `p_target_member_key`, matching the 085 SQL
  draft's argument name.
- `list_membership_review_users` returns `member_key`, and the UI normalizes it
  into an internal `memberKey` property for RPC calls. The key is not rendered
  as visible text or DOM data attributes.
- No frontend-side raw user id, email, token, or management-key value exposure
  was found in the changed UI path.
- A remaining repo-visible mismatch is that `grant_membership_manager` requires
  the target to have a corresponding `profiles` row before it can add
  `user_roles`, while the list RPC can expose manager-role actions based on
  membership status without explicitly checking profile existence.
- The role table prerequisites also need live confirmation: `user_roles` should
  have duplicate-safe `(user_id, role)` uniqueness and a role constraint that
  allows `membership_approver`.
- Added
  `docs/supabase/sql/087_membership_manager_grant_diagnostics_select_only.sql`
  to confirm these runtime prerequisites without returning concrete ids,
  emails, management-key values, tokens, or full URLs.
- Next gate: run 087 once as SELECT-only. If it reports missing profile rows or
  a role-storage prerequisite problem, prepare a narrow apply draft before any
  DB change. If 087 is all OK, inspect the exact UI actor/target condition
  without recording identifiers.

087 result and next narrowing:

- The user ran the revised 087 SELECT-only diagnostic once.
- `grant_membership_manager` signature, security, static guards, and
  management-key target lookup were OK.
- `list_membership_review_users` management-key surface was OK.
- `user_roles` duplicate-safe key, primary key, and `membership_approver` role
  allowance were OK.
- Approved memberships without profile rows were `0`, and approved normal
  memberships without profile rows were `0`.
- Existing approved membership managers were `0` in the diagnostic result.
- `public_profiles` risky columns were `0`.
- Therefore the first suspected causes, profile-row absence, role constraint
  absence, and `(user_id, role)` uniqueness absence, are not the likely cause.
- Static frontend review still found the UI using the expected
  `p_target_member_key` RPC argument and keeping `member_key` internal to JS.
- The remaining likely causes are actor/target guard behavior at the moment of
  operation or the UI's overly generic error handling.
- The UI now maps safe RPC error codes to short Japanese categories without
  showing SQL details, raw ids, email, tokens, or concrete management keys.

Additional narrowing after `5950771 Classify membership manager grant errors`:

- A later UI retry still showed the generic fallback:
  `会員管理権限を変更できませんでした。一覧を更新してから再度お試しください。`
- That message is the final fallback branch of
  `getMembershipManagerRoleErrorMessage`; it is reached after
  `grant_membership_manager` / `revoke_membership_manager` returns an error
  that is not classified by the current code map.
- The grant RPC returns `TABLE(member_key uuid, role text,
  membership_status text)`, but the current JS does not depend on the returned
  data shape. It only checks `error` and then reloads the list, so an array vs.
  single-object mismatch is not the likely cause.
- The list RPC returns `member_key`, and the UI still normalizes it to internal
  `memberKey`; no `management_key` value is rendered or stored in DOM
  attributes.
- The frontend still calls `grant_membership_manager` with
  `p_target_member_key`, matching the applied RPC argument name.
- The UI error classifier now also inspects safe `error.message` text and
  common database SQLSTATE categories, without displaying SQL details or
  concrete identifiers. This should split future failures into admin/target
  guard, approved-normal-user requirement, duplicate role state, or DB/RPC
  definition review.
- Created
  `docs/supabase/sql/088_membership_manager_grant_actor_target_select_only.sql`
  for the next diagnostic gate. It is SELECT-only and checks actor/target guard
  structure, eligible target counts, `user_roles` insert prerequisites,
  duplicate-safe role storage, RLS/owner runtime surface, direct write grants,
  and `public_profiles` exposure without returning raw ids, email, concrete
  management keys, tokens, or full URLs.
- If the new UI classification still does not identify the failing guard, run
  088 once as a separate SQL Editor SELECT-only gate before preparing any
  DB/RPC apply draft.

Schema-cache narrowing after the UI showed the RPC definition message:

- The UI message `会員管理RPCの定義確認が必要です。` comes from the DB/RPC
  definition bucket, not from empty `member_key`, empty RPC return data, or list
  reload failure.
- Static review again found `grant_membership_manager` /
  `revoke_membership_manager` calls passing `p_target_member_key: row.memberKey`.
- The applied SQL signatures remain
  `grant_membership_manager(p_target_member_key uuid)` and
  `revoke_membership_manager(p_target_member_key uuid)`, with return shape
  `TABLE(member_key uuid, role text, membership_status text)`.
- Because 086 confirmed the RPC definitions while the browser-side call still
  reaches the definition bucket, PostgREST schema-cache/function-lookup
  mismatch is now a likely cause.
- The UI classifier now separates `PGRST202`, schema-cache, and function lookup
  messages into `会員管理RPCのschema cache更新が必要な可能性があります。`.
- Created
  `docs/supabase/sql/089_membership_manager_rpc_schema_cache_reload_manual_gate.sql`
  as a separate manual gate containing only `notify pgrst, 'reload schema';`.
  It has not been run.
- Next safe order: retry once with the new UI classification. If the message is
  schema-cache related, run 089 once in a separate SQL Editor gate, then retry
  the manager grant. If the message remains definition-related, inspect 088
  results before drafting any DB/RPC change.

Public delivery and RPC-definition follow-up:

- Public `mypage.html` was checked with a no-cache request and is serving the
  expected `mypageAuthClient.js` cache-bust from `5a78a2b`.
- The delivered public JS contains both the schema-cache message and the older
  RPC-definition message, by design. Therefore seeing
  `会員管理RPCの定義確認が必要です。` is not proof of old JS delivery.
- Because the public JS is current and the old message is still the active
  branch, the likely bucket is now an actual DB/RPC definition/runtime issue
  rather than stale GitHub Pages delivery.
- Static review found a likely PL/pgSQL ambiguity surface in
  `grant_membership_manager`: the function returns a column named `role` and
  also uses `ON CONFLICT (user_id, role)` during `user_roles` insertion.
- Prepared
  `docs/supabase/sql/090_membership_manager_grant_role_conflict_fix_apply_draft.sql`
  to replace only `grant_membership_manager(uuid)` while preserving the
  signature, return shape, admin-only guard, target guards, and
  authenticated-only EXECUTE surface.
- The 090 draft changes the duplicate-safe insert to `ON CONFLICT DO NOTHING`
  and uses positional `RETURN QUERY` output to avoid role-name ambiguity.
- Prepared
  `docs/supabase/sql/091_membership_manager_grant_role_conflict_fix_post_apply_select_only.sql`
  to confirm the replacement without returning concrete identifiers.
- 089 schema-cache reload remains unexecuted and should not be used before the
  090/091 apply-before review decides whether the RPC-definition fix is the
  right next gate.

090/091 apply-before review:

- Reviewed from baseline `0884019 Prepare membership manager grant definition fix`.
- `090_membership_manager_grant_role_conflict_fix_apply_draft.sql` keeps the
  `DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED` note.
- 090 is limited to replacing `grant_membership_manager(uuid)`; it does not
  change `list_membership_review_users`, `set_member_review_status`, or
  `revoke_membership_manager`.
- The RPC signature remains `grant_membership_manager(p_target_member_key uuid)`
  and the return shape remains `TABLE(member_key uuid, role text,
  membership_status text)`.
- The review found no raw `user_id`, email, token, concrete management key, or
  full URL return surface in the revised RPC.
- `security definer`, `set search_path = public`, authenticated-only EXECUTE,
  and anon/public EXECUTE closure are preserved.
- Admin-only authorization, management-key target lookup, approved-user
  requirement, profile-row requirement, self-action guard, target-admin guard,
  and the `membership_approver`-only role insertion are preserved.
- The draft removes `ON CONFLICT (user_id, role)` and uses
  `ON CONFLICT DO NOTHING` to avoid conflict-target name ambiguity in the
  returning function.
- Because broad `ON CONFLICT DO NOTHING` can hide other unique/exclusion
  conflicts, 091 was strengthened to confirm `user_roles` has no unexpected
  non-primary unique/exclusion index surface before treating the apply as ready.
- `091_membership_manager_grant_role_conflict_fix_post_apply_select_only.sql`
  remains SELECT-only and checks signature, return shape, security/search_path,
  EXECUTE surface, conflict handling, direct write grants, and
  `public_profiles` exposure.
- Review result: no blocker found. `090` can be run once in SQL Editor, followed
  by one SELECT-only run of `091`.
- 089 schema-cache reload remains unexecuted and is not the next step while the
  090 definition fix gate is being tried.

090/091 apply confirmation:

- The user ran `090_membership_manager_grant_role_conflict_fix_apply_draft.sql`
  once in SQL Editor; apply succeeded.
- The user then ran
  `091_membership_manager_grant_role_conflict_fix_post_apply_select_only.sql`
  once as SELECT-only; all checks returned `status=ok`.
- `post_apply_ready_for_membership_manager_grant_qa=ok`.
- The applied fix was limited to `grant_membership_manager(uuid)`.
- The `grant_membership_manager` signature and return shape were preserved.
- `security definer`, `search_path=public`, authenticated-only EXECUTE, and
  anon/public EXECUTE closure were confirmed.
- Admin guard, management-key lookup, self guard, target-admin guard,
  approved-user guard, and profile-row guard were confirmed.
- The `user_roles` insert scope remained limited to the intended role grant.
- `ON CONFLICT DO NOTHING` was confirmed, and the previous
  `ON CONFLICT (user_id, role)` target was absent.
- Positional `RETURN QUERY` output was confirmed.
- `user_roles` conflict indexes were primary-only, with
  `non_primary_conflict_indexes=0`.
- Direct write grants were absent, and `public_profiles` still does not expose
  membership, role, management-key, email, or raw user-id surfaces.
- 089 schema-cache reload remains unexecuted and is no longer the immediate
  next step for this issue.
- Next gate: retry the admin UI path once by granting membership-manager
  authority to an approved normal user, then confirm the list refresh and
  manager-role display state.
- No concrete user id, email, management key value, token, JWT, full URL,
  project identifier, or secret is recorded.

## Stop Conditions

Stop before apply or implementation if:

- Existing membership status semantics are unclear.
- The role boundary would let membership managers grant admin or demote admins.
- The UI would need to display email or raw identifiers.
- The design would require `public_profiles` membership/role exposure.
- Direct table grants would be needed.
- SQL Editor execution, DB/RPC/RLS mutation, Edge deploy, Discord operation, or
  secret changes become necessary in the current gate.
