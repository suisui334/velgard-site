# Comment/Application Approved Gate QA Plan

## Purpose

This plan prepares the functional QA gate for the first DB/RPC-side membership
approved gate added by
`083_membership_gate_comment_application_apply_draft.sql`.

This planning step does not execute QA, create or edit live records, call RPCs,
run SQL Editor, apply SQL, change DB/RPC/RLS, deploy Edge Functions, run
Discord operations, or record concrete identifiers.

## Current State

- Latest baseline commit for this planning step is
  `8cbd053 Record comment application approved gate apply`.
- The user ran 083 once in SQL Editor and the apply succeeded.
- The user ran 084 once as SELECT-only after the apply, and all checks returned
  `ok`.
- `post_apply_ready_for_comment_application_membership_gate_qa=true`.
- Frontend unapproved-user hiding is already implemented, but the 083 gate is
  the first server-side protection for direct RPC calls in this area.

## RPCs Under QA

- `create_application_comment(text,text)`
- `cancel_my_session_application(text)`
- `update_application_comment(uuid,text)`
- `delete_application_comment_and_maybe_cancel(uuid)`

The implemented gate is intentionally limited to these four
comment/application RPCs. Session post, player character, template,
notification, TIMELINE, avatar, Discord sync, and remaining GM/admin gates are
outside this QA.

## Required QA Assets

Before executing the functional QA gate, confirm all of the following without
recording concrete IDs, email addresses, tokens, full URLs, or internal object
identifiers:

- One approved normal user that can safely perform comment/application actions.
- One unapproved test user, preferably `pending`; a previously rejected
  disposable test user can also be used for rejection-path checks.
- One safe QA session post whose detail page can be used for a minimal comment
  and application workflow.
- The QA session must not require Discord posting, Discord editing, Edge
  Function calls, or dry-run transitions for this test.
- The QA session should be safe to leave with one test comment/application
  history entry, or the cleanup path must be explicitly included in the gate.
- The GM/admin management-comment area should be viewable by a safe GM/admin
  account if management display regression is checked in the same gate.

If any of these assets cannot be confirmed, stop before live QA and prepare a
separate test-data setup gate.

## Recommended QA Method

Use the public site UI where the UI exposes the operation, and use an explicit
minimal RPC probe only where the frontend intentionally hides controls.

- Approved happy path: use `session-detail.html` UI.
- Unapproved frontend check: use direct page navigation and confirm the
  approved-gate guidance is shown instead of comment/application controls.
- Unapproved RPC-layer check: because the frontend hides the controls, use a
  separately approved minimal RPC probe in the logged-in unapproved browser
  context. The probe must call only the target RPCs, avoid printing payload
  IDs, avoid printing tokens, and record only boolean/status outcomes.

Do not run the RPC probe during this planning step.

## Approved User QA

Target: approved normal user.

1. Open the QA session detail page.
2. Submit one normal application/comment through the UI.
3. Confirm the operation succeeds and the comment appears in the list.
4. Confirm notification and TIMELINE side effects are not visibly broken.
5. Edit the user's own comment through the UI.
6. Confirm the edit succeeds and the list refreshes normally.
7. Delete the user's own comment through the UI.
8. Confirm deletion succeeds and existing permission behavior is preserved.
9. If the current application status allows it and cleanup is safe, test
   withdrawing the user's own application.

Pass conditions:

- Approved user can create a comment/application.
- Approved user can edit and delete an owned eligible comment.
- Approved user can withdraw an owned eligible application when the UI and
  current status allow it.
- No raw IDs, email addresses, tokens, or full URLs are displayed or recorded.

## Unapproved User QA

Target: `pending`, `rejected`, `revoked`, or `blocked` test user. Prefer
`pending` first, with `rejected` as an additional confidence check if already
available.

1. Log in as the unapproved test user.
2. Open the QA session detail page directly.
3. Confirm the normal comment/application controls are not shown.
4. In the explicit QA gate only, run the minimal RPC probe against the four
   target RPCs.
5. Confirm each target operation is rejected with the short Japanese approved
   member error.
6. Record only `accepted=false` / `rejected=true` style outcomes and a short
   safe error category.

Pass conditions:

- `create_application_comment(text,text)` rejects the unapproved user.
- `cancel_my_session_application(text)` rejects the unapproved user.
- `update_application_comment(uuid,text)` rejects the unapproved user.
- `delete_application_comment_and_maybe_cancel(uuid)` rejects the unapproved
  user.
- The rejection message is short, Japanese, and does not expose internal
  details.

## Regression Checks

During the explicit QA gate, confirm these within the smallest reasonable
scope:

- Session detail display still loads.
- Comment list display still loads.
- GM/admin management comment display is not visibly broken.
- `create_application_comment(text,text)` still preserves:
  - length guard,
  - URL maximum 2 guard,
  - same-user/same-session 60-second cooldown,
  - owner notification generation,
  - TIMELINE activity generation,
  - PC snapshot handling,
  - GM/admin management comment TIMELINE skip.
- `session_comments` and `session_applications` still have no web-role direct
  table write path in the tested UI/RPC flow.
- `public_profiles` does not expose membership or role state in visible UI.

## Cooldown And Spam Guard Handling

Do not create unnecessary repeated comments.

- If cooldown is tested, create exactly one immediate second post attempt from
  the same approved user and same session.
- Record only whether the cooldown rejection occurred.
- If URL count is tested, use non-sensitive placeholder URLs and avoid
  recording the full strings.
- URL two-count success and three-count rejection can be left to the existing
  spam-guard QA unless this gate explicitly needs a regression recheck.

## Stop Conditions

Stop before or during QA if any of the following happens:

- SQL Editor execution is needed.
- DB/RPC/RLS changes or SQL apply are needed.
- Edge Function deploy is needed.
- dry_run=false or Discord operations are needed.
- secret, Webhook, token, JWT, full Supabase URL, project ref, Discord message
  ID, channel ID, full post URL, concrete user ID, concrete session ID,
  application ID, or comment ID would be displayed or recorded.
- Approved or unapproved test-user status cannot be confirmed safely.
- The QA session appears to touch broad production data or real applicant data.
- The UI path requires more than one minimal test comment/application without a
  cleanup plan.

## Result Recording Template

Record results in `docs/task-backlog.md` and, if useful, this plan file without
concrete identifiers.

Use this shape:

- `qa_executed=true|false`
- `approved_create_comment=pass|fail|not_tested`
- `approved_cancel_application=pass|fail|not_tested`
- `approved_update_comment=pass|fail|not_tested`
- `approved_delete_comment=pass|fail|not_tested`
- `unapproved_create_comment_rejected=pass|fail|not_tested`
- `unapproved_cancel_application_rejected=pass|fail|not_tested`
- `unapproved_update_comment_rejected=pass|fail|not_tested`
- `unapproved_delete_comment_rejected=pass|fail|not_tested`
- `short_japanese_error=pass|fail|not_tested`
- `session_detail_display=pass|fail|not_tested`
- `comment_list_display=pass|fail|not_tested`
- `gm_admin_display=pass|fail|not_tested`
- `spam_guard_regression=pass|fail|not_tested`
- `notification_timeline_regression=pass|fail|not_tested`
- `pc_snapshot_regression=pass|fail|not_tested`
- `public_profiles_membership_exposure=none|review|not_tested`
- `dangerous_operations_performed=false`
- `real_values_recorded=false`

## Next Gate

The next gate is explicit functional QA execution. It should start only after a
human confirms the approved test user, unapproved test user, and safe QA session
are available.

## Functional QA Result

Status: completed successfully.

The user confirmed the functional QA results after the 083 apply and 084
SELECT-only confirmation.

Result summary:

- `qa_executed=true`
- `approved_create_comment=pass`
- `approved_cancel_application=pass`
- `approved_update_comment=pass`
- `approved_delete_comment=pass`
- `unapproved_create_comment_rejected=pass`
- `unapproved_cancel_application_rejected=pass`
- `unapproved_update_comment_rejected=pass`
- `unapproved_delete_comment_rejected=pass`
- `short_japanese_error=pass`
- `session_detail_display=pass`
- `comment_list_display=pass`
- `gm_admin_display=pass`
- `spam_guard_regression=pass`
- `notification_timeline_regression=pass`
- `pc_snapshot_regression=pass`
- `public_profiles_membership_exposure=none`
- `dangerous_operations_performed=false`
- `real_values_recorded=false`

Confirmed details:

- Approved users can perform the expected comment/application operations through
  the target RPC paths.
- Unapproved, pending, and rejected-equivalent users are rejected by the target
  RPC paths.
- Rejections use a short Japanese error message and do not expose internal
  details.
- The confirmed RPCs are:
  `create_application_comment(text,text)`,
  `cancel_my_session_application(text)`,
  `update_application_comment(uuid,text)`, and
  `delete_application_comment_and_maybe_cancel(uuid)`.
- GM/admin management comments and existing display behavior were not broken.
- Existing 60-second cooldown, URL maximum 2 guard, length guard, owner
  notifications, TIMELINE activity, PC snapshot handling, and GM/admin
  management comment skip behavior remained intact.

No concrete user id, email, session id, application id, comment id, Discord
message id, full post URL, JWT, token, project identifier, Webhook URL, or
secret is recorded.
