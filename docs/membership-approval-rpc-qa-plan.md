# Membership Approval RPC QA Plan

## Purpose

This plan prepares the functional QA gate for the membership approval RPCs
added by `081_membership_approval_rpc_apply_draft.sql`.

This is a non-destructive planning step. It does not run SQL Editor, apply SQL,
change DB/RPC/RLS, call the live RPCs, create signup traffic, send mail, deploy
Edge Functions, send Discord messages, or record concrete account identifiers.

The original temporary-console QA idea is superseded. Functional QA should now
use the mypage approval UI so the tested path matches the intended operation
surface.

## Current State

- Membership foundation is applied.
- Existing users were backfilled as `approved`.
- Future signups create `pending` membership rows.
- `mypage.html` displays the signed-in user's own membership status.
- The pending-list, approve, and reject RPCs are applied and confirmed by the
  SELECT-only 082 check.
- Mypage has a membership approval panel that uses the pending-list, approve,
  and reject RPCs.
- The 34 approved-member gates are not implemented yet.

## RPCs Under QA

- `get_pending_community_members(integer)`
- `approve_community_member(uuid,text)`
- `reject_community_member(uuid,text)`

Expected properties:

- Callable by `authenticated` only.
- Not callable by `anon` or `public`.
- Internally limited to admin users or already-approved `membership_approver`
  users.
- Approve/reject deny self-action.
- Approve supports only `pending -> approved`.
- Reject supports only `pending -> rejected`.
- Email values are not returned or referenced.
- `community_memberships` direct table grants remain closed.

## Required Accounts

Use only accounts that are safe for QA.

- Admin account: performs the primary pending list, approval, and rejection QA.
- Normal approved account: verifies that non-admin, non-approver users cannot
  call pending-list or approval RPCs.
- Pending approval QA account: a disposable account intended to be approved.
- Pending rejection QA account: a disposable account intended to remain
  rejected after the test.
- Membership approver account: optional and deferred unless a separate reviewed
  gate safely grants the role.

Do not use real applicants for rejection QA. The current MVP has no public
restore or force-status RPC, so a rejected QA account should be treated as a
throwaway test account unless a later admin-only recovery gate is approved.

## Pending QA User Preparation

Preferred order:

1. Use existing disposable pending QA users if they are already available.
2. If no pending QA users exist, stop and run a separate signup-preparation gate.
3. Create at most the required QA accounts in that later gate:
   - one pending account for approval,
   - one pending account for rejection.

Creating new pending QA users may send signup and confirmation email, so it is
not part of this planning gate.

## UI Call Method

Functional QA should use the mypage UI rather than a temporary console.

Recommended method:

- Open the public site in the browser.
- Log in as the test actor for the current case.
- Open `mypage.html`.
- For admin or an approved `membership_approver`, use the `会員承認` panel.
- Use only the displayed approval UI buttons and review-note fields.
- Do not paste concrete `user_id`, email, session token, JWT, full URL, project
  ref, or raw RPC result rows into docs or chat.

Temporary DevTools calls are now a fallback only if the UI itself fails to load
and a separate debug gate approves that fallback.

The QA should not update `community_memberships` directly. All state changes
must go through the reviewed RPCs.

## Test Cases

### 1. Admin Can List Pending Members

Steps:

- Log in as admin.
- Open mypage and confirm the `会員承認` panel is visible.
- Confirm pending QA candidates are returned when available.
- Confirm no email field is returned.
- Confirm output is not copied into docs/chat.

Pass condition:

- Admin can retrieve the pending list.
- The list contains only minimal display/review information needed for
  approval work.
- Email values are absent.

Stop condition:

- The list exposes email or unnecessary private fields.
- The call requires direct table access.

### 2. Admin Can Approve One Pending User

Steps:

- Use the dedicated pending approval QA account.
- Admin presses the row's `承認` button in the `会員承認` panel.
- Log in as the approved QA user.
- Open mypage.
- Confirm the membership status display shows `approved`.

Pass condition:

- The pending account becomes approved through RPC only.
- Mypage reflects the approved status.

Aftercare:

- The approved QA account may remain approved if it is a disposable test
  account.

### 3. Admin Can Reject One Pending User

Steps:

- Use the dedicated pending rejection QA account.
- Admin presses the row's `却下` button in the `会員承認` panel.
- Log in as the rejected QA user.
- Open mypage.
- Confirm the membership status display shows `rejected`.

Pass condition:

- The pending account becomes rejected through RPC only.
- Mypage reflects the rejected status.

Aftercare:

- Do not use a real applicant.
- Leave the disposable rejected account as rejected unless a later reviewed
  admin-only recovery gate is created.

### 4. Normal Approved User Is Denied

Steps:

- Log in as a normal approved user without admin or `membership_approver`.
- Open mypage.
- Confirm the `会員承認` panel is not displayed.

Pass condition:

- No pending list or approval action is exposed.

### 5. Self Approval/Rejection Is Denied

Steps:

- If the UI ever shows a row that represents the acting user, confirm the row
  controls are disabled.
- Do not record the id.

Pass condition:

- Self-action is not available through the UI. The RPC-level self-action guard
  remains confirmed by the 082 SELECT-only check and should be functionally
  tested only in a separate debug gate if needed.

### 6. Non-Pending Approval/Rejection Is Denied

Steps:

- After the approval case, try to approve the same already-approved disposable
  QA account again only if it still appears in the UI.
- In normal operation, the approved row should disappear from the pending list.

Pass condition:

- Non-pending rows are not available in the approval UI. RPC-level non-pending
  denial remains guarded by the applied function and can be separately tested if
  a safe debug gate is opened.

### 7. Direct Table Grant Is Not Used

Steps:

- Do not run direct table writes.
- Keep QA restricted to the reviewed RPC surface.
- If direct write access appears necessary, stop and open a separate review
  gate instead.

Pass condition:

- All approval/rejection behavior is verified through RPC calls only.

## Membership Approver Role QA

Defer by default.

Reason:

- This gate does not include role grant/revoke UI or admin-only role management
  RPCs.
- Testing `membership_approver` requires a safe way to grant and later remove
  that role without giving admin power or using ad hoc table writes.

Only run membership-approver-path QA if a separate reviewed gate provisions a
dedicated approved approver test account.

## Logging And Documentation Rules

Record only status-level outcomes:

- pending list success/failure,
- email not returned,
- approve success/failure,
- reject success/failure,
- mypage status display result,
- authorization denial result,
- self-action denial result,
- non-pending denial result.

Do not record:

- concrete user ids,
- concrete email addresses,
- auth session data,
- JWT or tokens,
- full URLs,
- project refs,
- secrets or API keys,
- raw pending-list output.

## Cleanup And Rollback Policy

- Approved disposable QA accounts may remain approved.
- Rejected disposable QA accounts should remain rejected unless a later reviewed
  recovery gate is created.
- Do not use SQL Editor direct updates for cleanup.
- Do not add a one-off rollback SQL unless a separate apply draft and review
  gate is created.
- If QA accidentally targets a real account, stop and open a separate incident
  review gate before attempting any status change.

## Recommended Execution Order

1. Confirm disposable pending QA accounts exist.
2. Admin pending-list QA.
3. Admin approve QA.
4. Approved QA user mypage status check.
5. Admin reject QA.
6. Rejected QA user mypage status check.
7. Normal approved user UI-hidden QA.
8. Pending user UI-hidden QA.
9. Smartphone-width layout check.
10. Document status-only results.

## Next Gate

Run the functional QA once the required disposable pending users are ready.
If pending QA users are not ready, the next gate should prepare them without
recording concrete email, user id, token, full URL, or project ref values.
