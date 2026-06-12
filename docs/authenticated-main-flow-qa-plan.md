# Authenticated Main Flow QA Gate

## Purpose

This gate prepares the authenticated-user public-site QA that remains after the
anonymous public-site QA.

Codex did not run this live QA because no safe authenticated approved,
unapproved, owner/GM, or admin browser session was available in the current
tool context. The steps below are intended for user-side manual QA with known
safe accounts.

This gate does not run SQL Editor, apply SQL, change DB/RPC/RLS, deploy Edge
Functions, run `dry_run=false`, perform Discord operations, change
secret/Webhook settings, or add Supabase direct writes.

## Baseline

- Latest baseline commit: `b9a0c60 Record prelaunch main flow QA`.
- Anonymous public-site QA is complete:
  - `calendar` gate: `pass`
  - `session-detail` gate: `pass`
  - `session-post` gate: `pass`
  - `timeline` gate: `pass`
  - anonymous `mypage` login surface: `pass`
- The first comment/application DB/RPC approved-member gate is complete:
  083 applied, 084 checked, and functional QA passed.

## Required Test Accounts

Use only safe accounts whose concrete ids, emails, tokens, and URLs will not be
recorded.

| Actor | Needed | Notes |
| --- | --- | --- |
| Approved normal user | Required | For read and low-risk comment/application checks. |
| Unapproved/pending/rejected user | Required | For approved-gate display and rejected operation checks. |
| Owner/GM user | Required for owner QA | Must own exactly the safe target session being checked. |
| Admin user | Required for admin QA | Use only for view/control presence checks unless a separate mutation gate exists. |

If any account is unavailable, record that actor as `not_tested` with the
reason. Do not create new accounts during this gate unless a separate signup QA
gate is explicitly opened.

## Safe Target Session

Before live QA, choose one safe target session.

Requirements:

- The target is known to be safe for QA.
- It is not a broad production-critical session.
- It does not require Discord posting/editing/deleting to inspect.
- It can tolerate at most one test comment/application if the approved-user
  operation check is performed.

If no safe target session exists, stop before creating or modifying data and
record `safe_target_session_available=false`.

## Stop Conditions

Stop immediately before any step that would require:

- SQL Editor execution, SQL apply, or DB/RPC/RLS change.
- Edge Function deploy.
- `dry_run=false`.
- Discord create/update/delete or existing Discord post mutation.
- Secret/Webhook change.
- Recording concrete user id, email, session id, application id, comment id,
  Discord message/channel id, full post URL, JWT, token, project identifier, or
  Webhook URL.
- Broad live-data pollution or unclear cleanup ownership.

For public/non-draft session create, edit, delete, or close operations, stop
before clicking the final action if the operation may trigger Discord sync.

## QA Matrix

Record results as `pass`, `fail`, `not_tested`, or `blocked`.

| Actor / Flow | Expected | Result |
| --- | --- | --- |
| approved calendar view | Calendar main UI is visible. | `pass` |
| approved session-detail view | Session detail main UI is visible. | `pass` |
| approved mypage view | Mypage remains usable and visually stable. | `pass` |
| approved participation/comment surface | Application/comment area is shown naturally. | `pass` |
| unapproved calendar view | Approved-member gate is shown; calendar main UI is hidden. | `pass` |
| unapproved session-detail view | Approved-member gate is shown; detail/comment/application UI is hidden. | `pass` |
| unapproved session-post view | Approved-member gate is shown; post form is hidden. | `pass` |
| unapproved mypage | Minimal account/status surface is shown. | `pass` |
| owner GM/admin panel | Owner/GM management area is shown. | `pass` |
| owner edit/management controls | Owner/GM sees eligible own-session management controls. | `pass` |
| owner close button | Owner/GM sees the close control. | `pass` |
| owner dangerous action final click | Stop before final mutation unless a Discord-safe mutation gate is open. | `not_run` |
| admin management controls | Admin can see expected management controls. | `pass` |
| normal user other-session controls | No edit/delete/close controls for another user's session. | `pass` |
| raw value exposure | No raw ids, email, tokens, full post URLs, or Discord ids shown. | `pass` |

## User-Side Manual Steps

### 1. Approved Normal User

1. Log in as an approved normal user.
2. Open `calendar`.
3. Confirm the calendar main UI appears.
4. Open one safe `session-detail`.
5. Confirm session details and normal comment/application surfaces appear.
6. If a safe target session exists, submit at most one test
   application/comment.
7. Confirm the operation succeeds without exposing raw ids or secret values.
8. Do not create, edit, delete, or close session posts in this actor check.

### 2. Unapproved / Pending / Rejected User

1. Log in as an unapproved, pending, or rejected-equivalent user.
2. Open `mypage`.
3. Confirm only the minimal account/status surface appears.
4. Open `calendar`, `session-detail`, `session-post`, and `timeline`.
5. Confirm each community operation surface is replaced by approved-member
   guidance.
6. Confirm comment/application UI is not exposed.
7. If an RPC rejection probe is needed, perform it only in a separate minimal
   gate and record only the boolean outcome and short Japanese error category.

### 3. Owner / GM

1. Log in as the owner/GM of the safe target session.
2. Open that session detail.
3. Confirm owner/GM management controls appear where expected.
4. Confirm edit/delete/close controls are visible only for eligible own-session
   contexts.
5. Stop before final edit/delete/close execution unless a Discord-safe mutation
   QA gate has been explicitly opened.

### 4. Admin

1. Log in as an admin account.
2. Open `mypage`.
3. Confirm the membership approval/admin surface is available.
4. Open the safe target session detail.
5. Confirm admin/GM management surfaces appear as expected.
6. Do not approve/reject, edit, delete, close, or sync anything unless the
   relevant mutation gate is explicitly open.

### 5. Normal User Negative Control

1. Log in as an approved normal user who is not the owner/GM of the safe target
   session.
2. Open that session detail.
3. Confirm edit/delete/close controls for the other user's session do not
   appear.

## Result Template

Copy this section into the result gate and replace values only with booleans or
status words. Do not paste concrete ids, emails, tokens, full URLs, or Discord
identifiers.

```text
qa_executed=true/false
safe_target_session_available=true/false
approved_calendar_view=pass/fail/not_tested
approved_session_detail_view=pass/fail/not_tested
approved_comment_or_application=pass/fail/not_tested
unapproved_mypage_minimal=pass/fail/not_tested
unapproved_calendar_gate=pass/fail/not_tested
unapproved_session_detail_gate=pass/fail/not_tested
unapproved_session_post_gate=pass/fail/not_tested
unapproved_timeline_gate=pass/fail/not_tested
owner_controls_visible=pass/fail/not_tested
owner_mutation_executed=false
admin_controls_visible=pass/fail/not_tested
normal_user_other_session_management_hidden=pass/fail/not_tested
discord_operation_executed=false
raw_value_exposure=none/found/not_tested
not_tested_reason=...
```

## Current Gate Result

User-side QA result:

- `qa_executed=true`
- `safe_authenticated_session_available=true`
- `approved_calendar_view=pass`
- `approved_session_detail_view=pass`
- `approved_mypage_view=pass`
- `approved_application_comment_surface=pass`
- `unapproved_mypage_minimal=pass`
- `unapproved_calendar_gate=pass`
- `unapproved_session_detail_gate=pass`
- `unapproved_session_post_gate=pass`
- `unapproved_timeline_gate=pass`
- `unapproved_application_comment_blocked=pass`
- `owner_gm_management_panel=pass`
- `owner_edit_management_controls=pass`
- `owner_close_button_visible=pass`
- `owner_mutation_executed=false`
- `admin_controls_visible=pass`
- `normal_user_other_session_management_hidden=pass`
- `discord_operation_executed=false`
- `raw_value_exposure=none`

Confirmed:

- Approved normal users can view `calendar`, `session-detail`, and `mypage`.
- Approved normal users see the application/comment area naturally.
- Unapproved, pending, or rejected-equivalent users see the approved-member gate
  and cannot view or operate session/application/comment surfaces.
- Owner/GM users see the GM/admin management area, management links, and close
  control for their own session context.
- Admin users see admin-oriented controls.
- A normal user cannot edit, delete, or close another user's session.

Stopped:

- Live create/edit/delete/close operations that would mutate data or may touch
  Discord sync were not executed in this QA result.
- Public/non-draft session creation, edit, delete, close, and Discord sync
  remain separate explicit gates.

No concrete user id, email, session id, application id, comment id, Discord
message id, full post URL, token, JWT, project identifier, Webhook URL, API key,
or secret is recorded.
