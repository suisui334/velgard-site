# Community Membership Access Control Plan

## Purpose

This plan prepares a community membership approval model for wider public
exposure.

The site may allow public signup, but a newly signed-up user should remain
unable to use major interactive features until approved. This is not an invite
code design. The first target is approval-only access control, with a limited
`membership_approver` authority that can approve or reject new users without
receiving full admin power.

This is a non-destructive design step only. It does not run SQL Editor, apply
SQL, change DB/RPC/RLS, change Supabase Dashboard settings, deploy Edge
Functions, send mail, send Discord messages, or record credentials or concrete
identifiers.

## Adopted Direction

- Public signup can remain available.
- New accounts start as `pending`.
- Pending users can log in and complete their profile/application information.
- Pending users cannot create sessions, comment/apply, manage PCs/templates,
  use Discord sync, or use notification/TIMELINE features.
- Approval is separate from admin.
- `membership_approver` can approve/reject pending users only.
- Admin remains responsible for granting/removing approver authority and for
  strong account actions such as blocking or forced status changes.
- Frontend hiding is only a convenience; DB/RPC gates must enforce the rule.

## Membership Statuses

| Status | Meaning | Intended Access |
| --- | --- | --- |
| `pending` | Registered but not approved | Login, mypage basics, profile/application text only |
| `approved` | Normal community member | Normal member features |
| `rejected` | Application rejected | Login to see rejection guidance; no community actions |
| `revoked` | Former member or suspended access | Login to see access-ended guidance; no community actions |
| `blocked` | Re-entry denied | Login may show blocked guidance; no community actions |

## Authority Model

| Authority | Source | Intended Scope |
| --- | --- | --- |
| `admin` | Existing role model | Full management, role grants, blocked/revoked handling |
| `membership_approver` | Existing role model extension | Pending list, approve pending, reject pending, decision notes |
| `gm` | Existing role model | Existing GM/session ownership behavior only |
| `member` | Derived from `membership_status='approved'` | Normal approved-user access |

MVP recommendation: make `membership_status` the source of truth for member
access. Treat `member` as a derived permission helper rather than a separately
granted role unless a later DB review decides to mirror approved users into a
role table transactionally.

## Proposed Data Model

### `community_memberships`

One row per profile.

Candidate columns:

- `profile_id uuid primary key references public.profiles(id)`
- `status text not null default 'pending'`
- `applicant_note text`
- `approver_note text`
- `decided_by uuid references public.profiles(id)`
- `decided_at timestamptz`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Constraints:

- `status in ('pending', 'approved', 'rejected', 'revoked', 'blocked')`
- Applicant/approver notes should have length limits.
- No email, auth token, URL, project identifier, or secret should be stored.

RLS:

- User can read their own membership row.
- User can update only their own applicant-facing fields while `pending`.
- `membership_approver` can read pending rows and approve/reject pending rows
  through RPC only, not by direct table write.
- Admin can read and manage all statuses through admin-only RPCs.
- No anon table access.

### `community_membership_events`

Append-only decision/audit log.

Candidate columns:

- `id uuid primary key`
- `profile_id uuid not null references public.profiles(id)`
- `actor_profile_id uuid references public.profiles(id)`
- `from_status text`
- `to_status text not null`
- `event_type text not null`
- `note text`
- `created_at timestamptz not null default now()`

RLS:

- Admin can read all.
- `membership_approver` can read decision events for pending approval workflow
  if needed.
- The target user can read their own outcome history if the UI needs it.
- Direct insert/update/delete from web client roles should be denied; RPCs
  append rows.

### `profiles` / `public_profiles`

Do not expose membership status through `public_profiles`.

Pending users may need a short self-introduction or participation reason. Prefer
placing this in `community_memberships.applicant_note` rather than widening
`public_profiles`.

## Helper/RPC Proposal

### Shared Helpers

- `is_approved_member(target_profile_id uuid default auth.uid())`
- `is_membership_approver()`
- `get_my_membership_status()`

Helper requirements:

- `security definer` with reviewed `search_path`.
- No anon execute for private helpers.
- Do not return email, concrete auth identifiers, tokens, or secret values.

### Pending User RPCs

Allowed while pending:

- `get_my_membership_status()`
- `update_my_membership_application(p_applicant_note text)`
- Existing account basics if kept:
  - `update_display_name(new_display_name text)`
  - `get_my_profile_contact()`
  - `update_my_discord_id(new_discord_id text)`

Recommended hold until approved:

- Avatar upload/metadata update, because it creates public media moderation
  exposure.
- Template management.
- PC management.
- Notifications/TIMELINE reads.

### Membership Approver RPCs

Minimal approver scope:

- `list_pending_membership_requests(p_limit integer default 50)`
- `approve_pending_membership(target_profile_id uuid, decision_note text)`
- `reject_pending_membership(target_profile_id uuid, decision_note text)`

Approver constraints:

- Can act only on `pending`.
- Cannot approve/reject self unless explicitly allowed later; default deny.
- Cannot grant `admin`, `gm`, `membership_approver`, or any role.
- Cannot unblock, revoke, restore, or force-change non-pending statuses.
- Cannot access secrets, auth emails, tokens, or Dashboard settings.

### Admin-Only RPCs

Admin-only scope:

- Grant/revoke `membership_approver`.
- Force status change.
- Move users to `revoked` or `blocked`.
- Restore from `blocked` or `revoked`.
- Review membership event logs.

## RPCs That Need Approved-Member Gates

The following web-client reachable flows should require `approved` unless the
caller is admin or an explicitly allowed operational role.

### Session Post Lifecycle

- `create_session_post`
- `update_session_post`
- `delete_session_post`
- Discord create/update/delete check and record RPCs that can be reached by the
  web client

Reason: pending users must not create, edit, delete, close, or trigger sync for
session posts.

### Comments / Applications

- `create_application_comment`
- `update_application_comment`
- `delete_application_comment_and_maybe_cancel`
- `cancel_my_session_application`

Reason: initial comments can act as participation applications, so pending users
must not comment/apply.

### GM/Application Management

- `set_application_status`
- `get_gm_session_application_history`
- `get_gm_session_accepted_contacts`

Recommended rule: require approved membership and existing GM/admin ownership
rules. Admin may bypass membership status only if the account itself is not
blocked/revoked by policy.

### Player Characters

- `get_my_player_characters`
- `create_player_character`
- `update_player_character`
- `set_default_player_character`
- `deactivate_player_character`

Reason: pending users should not build operational PC data before approval.

### Templates

- `get_my_template_presets`
- `create_template_preset`
- `update_template_preset`
- `deactivate_template_preset`

Reason: pending users should not use template management.

### Notifications / TIMELINE

- `get_my_unread_notification_count`
- `get_my_notifications`
- `mark_my_notification_read`
- `mark_all_my_notifications_read`
- `get_activity_timeline`

Recommended rule:

- Pending logged-in users should be treated like unauthenticated users for
  TIMELINE visibility, or receive no rows.
- Private notifications should not be available until approved.

### Profile / Avatar

Pending allowed:

- Display name/contact/application text needed for approval.

Pending denied or deferred:

- `update_my_avatar_path`
- `clear_my_avatar_path`
- Storage upload/remove for `avatars`

Reason: avatar moderation is a separate public-content concern.

## Screens and Frontend Behavior

### Pending

Mypage should show a clear waiting state.

Example meaning: "Your community membership is waiting for approval. Please
complete your profile information and wait for review."

Visible:

- Account overview.
- Display name.
- Discord contact field.
- Participation reason/self-introduction field.
- Logout/password reset/account basics.

Hidden or disabled:

- Session post create/edit.
- Comment/application forms.
- PC management.
- Template management.
- Notifications/TIMELINE.
- Discord sync controls.

### Approved

Normal current member UI.

### Rejected

Example meaning: "Your community membership request was not approved. Contact
an administrator if you need follow-up."

Keep messaging intentionally brief and avoid exposing internal decision details.

### Revoked

Example meaning: "Community access for this account is currently stopped."

### Blocked

Example meaning: "This account cannot use community features."

Do not expose internal moderation metadata.

### Membership Approver UI

Candidate location:

- mypage admin/operations area, visible only to `membership_approver` or admin.

MVP list fields:

- Display name.
- Optional Discord contact value if voluntarily entered.
- Applicant note.
- Signup/profile created time in a human-readable form.
- Approve/reject controls.
- Short decision note field.

Do not show:

- Email.
- Auth ids.
- Full internal ids.
- Tokens.
- Project identifiers.

## Implementation Order

1. SELECT-only inventory gate.
   - Confirm current role table shape, `has_role`, profiles columns, direct
     grants, and the active signatures for RPCs listed above.
2. Schema/helper apply draft gate.
   - Add `community_memberships`, event log, helper functions, and RLS.
   - Backfill existing trusted users as `approved` only after a separate review.
3. Approval RPC apply draft gate.
   - Add pending list, approve, reject, and self-status/profile application RPCs.
4. Interaction guard apply draft gate.
   - Add approved-member checks to session, comment/application, PC, template,
     notification, TIMELINE, and Discord-related RPCs in small batches.
5. Frontend gate.
   - Mypage status panels, approver UI, pending/rejected/revoked/blocked
     messaging, hidden/disabled controls.
6. QA gate.
   - New signup stays pending.
   - Pending can update allowed profile/application fields.
   - Pending cannot use prohibited RPCs even if calling UI is bypassed.
   - Approver can approve/reject pending only.
   - Approved user can use normal features.
   - Rejected/revoked/blocked users remain gated.
   - Admin-only operations remain admin-only.

## Suggested SELECT-Only Diagnostic Gate

Before any apply draft, prepare a SELECT-only diagnostic such as
`074_membership_access_control_inventory_select_only.sql` to confirm:

- Existing `profiles` columns.
- Existing roles table and role values.
- `has_role(text)` behavior and grants.
- Current `public_profiles` columns.
- Active RPC signatures for the approved-gate list.
- Existing anon/authenticated execute grants for those RPCs.
- Current avatar Storage policies.
- Current notification/TIMELINE RPC grants.

The diagnostic should return only `check_name / status / result_value / note`
and must not return concrete user ids, emails, full URLs, tokens, project refs,
or secret values.

Prepared gate:

- `docs/supabase/sql/074_membership_access_control_inventory_select_only.sql`
- The user ran 074 once as SELECT-only.
- 074 showed no existing membership table, no membership-status-like column on
  `profiles`, no role-like column on `profiles`, and no membership/role-like
  exposure through `public_profiles`.
- Existing role storage is present through `user_roles`, and `has_role(text)` /
  `is_admin()` exist, so adding `membership_approver` to the existing role
  mechanism looks feasible.
- The auth profile trigger exists and has external EXECUTE closed.
- Target table RLS is enabled.
- 34 RPCs are approved-gate candidates.
- Pending-allowed candidates are `get_my_profile_contact()`,
  `update_display_name(text)`, and `update_my_discord_id(text)`.
- Direct write grants returned `direct_write_grants=2`, so details must be
  checked before schema/helper draft work.

Prepared follow-up gate:

- `docs/supabase/sql/075_membership_direct_write_grants_detail_select_only.sql`
- The user ran 075 once as SELECT-only.
- 075 reported `direct_write_grants=26`, with 24 Storage grants classified as
  expected exceptions.
- The two app-table review grants were direct `TRUNCATE` privileges on
  `public.player_characters` for `anon` and `authenticated`.
- `player_characters` is a core app table, and web-client `TRUNCATE` access is
  not needed for the player-character workflow.

Prepared revoke gate:

- `docs/supabase/sql/076_revoke_player_characters_truncate_apply_draft.sql`
- `docs/supabase/sql/077_revoke_player_characters_truncate_post_apply_select_only.sql`
- The user ran 076 once in their SQL Editor and the apply succeeded.
- The user ran 077 once as SELECT-only and all checks were OK.
- `public.player_characters` exists.
- Direct `TRUNCATE` grants for `public`, `anon`, and `authenticated` are all
  closed.
- Direct `INSERT`, `UPDATE`, and `DELETE` grants are also 0.
- Storage expected exceptions were intentionally out of scope and were not
  changed.
- `post_apply_ready_for_membership_schema_design=true`.
- The unnecessary `public.player_characters` TRUNCATE grants found by 075 are
  resolved, so the next gate can return to membership schema/helper design.

Prepared foundation gate:

- `docs/supabase/sql/078_membership_foundation_apply_draft.sql`
- `docs/supabase/sql/079_membership_foundation_post_apply_select_only.sql`
- The first 078 SQL Editor apply attempt stopped with a syntax error before a
  successful apply was confirmed.
- The user did not rerun 078 after the error.
- The error was caused by `current_user` being used as a table alias inside
  `get_my_membership_status()`. The corrected draft now uses `auth_context`
  instead.
- `docs/supabase/sql/080_membership_foundation_failed_apply_state_select_only.sql`
  was prepared to inspect whether the failed attempt left any partial
  membership objects before deciding the next apply gate.
- 080 was run once as SELECT-only and showed no partial membership foundation
  objects from the failed 078 attempt.
- The corrected 078 was then run once in the user's SQL Editor and the apply
  succeeded.
- 079 was run once as SELECT-only after the corrected 078 apply, and all checks
  were OK.
- The foundation keeps membership state in a new private
  `community_memberships` table instead of adding it to `profiles`, so
  `public_profiles` stays free of membership/role status.
- Existing auth users are backfilled as `approved`.
- Future auth users get a separate membership trigger row with `pending`
  status; the existing profile creation trigger is not replaced.
- The existing `user_roles` model is extended to allow
  `membership_approver`, with helper RPCs for approved-member and approver
  checks.
- `community_memberships` exists, RLS is enabled, expected columns and status /
  review-note constraints are present, own-status and admin/approver read
  policies exist, and web-role direct table grants remain closed.
- Existing auth users have membership rows and missing membership count is 0.
- The separate auth trigger for future `pending` rows exists.
- `is_approved_member()`, `is_membership_approver()`, and
  `get_my_membership_status()` exist, are security definer functions with
  `search_path=public`, and are executable only by authenticated web clients.
- The auth trigger function is not directly executable by web roles.
- `post_apply_ready_for_membership_gate_design=true`.
- Approve/reject RPCs, approver UI, and approved gates for the 34 candidate
  RPCs remain separate later gates.
- A dedicated membership event log table is also deferred; the foundation keeps
  only current status and a bounded review note.
- The next gate is approved-member gate design or membership approver RPC
  design.

Mypage status display gate:

- Added a low-risk frontend display for the signed-in user's own membership
  status on `mypage.html`.
- The display calls `get_my_membership_status()` and shows Japanese guidance
  for `pending`, `approved`, `rejected`, `revoked`, and `blocked`.
- The display does not expose concrete user ids, emails, URLs, tokens, project
  identifiers, or role internals.
- This is guidance only. The 34 approved-member RPC gates, approve/reject RPCs,
  and membership approver UI remain separate later gates.
- No SQL Editor execution, SQL apply, DB/RPC/RLS change, Dashboard change, Edge
  deploy, mail sending, Discord sending, or credential recording was performed.

Approval RPC apply confirmation:

- `docs/supabase/sql/081_membership_approval_rpc_apply_draft.sql`
- `docs/supabase/sql/082_membership_approval_rpc_post_apply_select_only.sql`
- The user ran 081 once in their SQL Editor and the apply succeeded.
- The user ran 082 once as SELECT-only after the 081 apply, and all checks were
  OK.
- The pending-list, approve, and reject RPCs exist.
- All three RPCs are security definer functions with `search_path=public`.
- The three RPCs are executable by `authenticated` only, and are not executable
  by `anon` or `public`.
- Internal guards allow only admin users or already-approved
  `membership_approver` users to act.
- Approve/reject RPCs prevent self approval or self rejection.
- State transitions are limited to `pending -> approved` and
  `pending -> rejected`.
- `review_note` keeps a length guard.
- The RPCs do not reference or return email values.
- Direct table grants on `community_memberships` remain closed.
- `public_profiles` still does not expose membership or role state.
- `post_apply_ready_for_membership_approval_rpc_qa=true`.
- The 34 approved-member gates, approver UI, role grant/revoke RPCs, forced
  status changes, invite codes, Auth email hooks, email hash deny lists,
  Discord, Edge, mail, Storage, and Dashboard changes remain out of scope.
- The next gate is approval RPC functional QA. No concrete user ids, emails,
  full URLs, tokens, project identifiers, or secrets are recorded.

Approval RPC functional QA planning:

- `docs/membership-approval-rpc-qa-plan.md` records the non-destructive QA
  plan for the applied pending-list, approve, and reject RPCs.
- The temporary-console QA idea was superseded by a mypage UI approach.
- Mypage now has a `会員承認` panel that uses the pending-list, approve, and
  reject RPCs.
- The panel is shown only when the pending-list RPC succeeds for admin or an
  approved `membership_approver`; other users fail closed and do not see it.
- Required accounts are admin, normal approved user, one disposable pending
  user for approval, and one disposable pending user for rejection.
- New pending QA user creation may send signup/confirmation mail, so it remains
  a separate gate if no disposable pending users already exist.
- `membership_approver` path QA is deferred unless a separate reviewed gate
  safely grants that role to a dedicated approved test account.
- The QA plan records status-level results only and forbids recording concrete
  user ids, emails, full URLs, tokens, project identifiers, or secrets.
- This UI gate still does not add the 34 approved-member gates, revoked/blocked
  management, forced status changes, or membership approver role-grant UI.

Approval UI/RPC functional QA result:

- The user completed functional QA through the mypage approval UI.
- Admin could see the `会員承認` panel and the disposable pending users prepared
  for approve/reject QA.
- The UI did not display email values or concrete user ids.
- Admin approval through the UI succeeded, and the approved QA user's mypage
  status displayed `approved` / 承認済み.
- Admin rejection through the UI succeeded, and the rejected QA user's mypage
  status displayed `rejected` / 承認されていない.
- The rejected QA user and a normal approved non-admin user did not see the
  approval panel.
- The membership approval UI/RPC functional QA is treated as successful.
- The 34 approved-member gates, revoked/blocked operations, forced status
  changes, and membership approver role-grant UI remain separate later gates.
- No concrete user id, email, full URL, token, project identifier, or secret is
  recorded.

Unapproved member frontend restriction:

- Added a frontend-only display restriction for users whose membership status
  is not `approved`.
- `pending`, `rejected`, `revoked`, and `blocked` users see only minimal mypage
  account information and membership guidance.
- The minimal mypage surface keeps display name, Discord ID, membership status,
  and account password change available as account-maintenance functions.
- Avatar settings, PC management, template management, schedule/application
  history, notification bell, TIMELINE, calendar, session detail, comments,
  applications, and session-post forms are hidden or replaced with approval
  guidance for unapproved signed-in users.
- Public world, regulation, gallery, terms, and similar public-information
  pages remain available.
- This is a UX and normal-operation restriction only. Direct URL access and raw
  RPC calls must still be closed by the later approved-member DB/RPC gates.
- The 34 approved-member RPC gates remain the required server-side follow-up.
- No SQL Editor execution, SQL apply, DB/RPC/RLS change, Dashboard change, Edge
  deploy, mail sending, Discord sending, or credential recording was performed.
- Static checks and local HTTP display checks were used; live operation QA for
  pending/rejected users is deferred.
- No concrete user id, email, session id, full URL, token, project identifier,
  or secret is recorded.

Comment/application approved-member RPC gate draft:

- `docs/supabase/sql/083_membership_gate_comment_application_apply_draft.sql`
  is an unexecuted apply draft.
- `docs/supabase/sql/084_membership_gate_comment_application_post_apply_select_only.sql`
  is an unexecuted post-apply SELECT-only confirmation SQL.
- This is the first DB/RPC-side approved-member gate after the frontend
  restriction.
- The draft is limited to the external comment/application RPC surface:
  `create_application_comment(text,text)`,
  `cancel_my_session_application(text)`,
  `update_application_comment(uuid,text)`, and
  `delete_application_comment_and_maybe_cancel(uuid)`.
- Each target RPC keeps its existing signature and return shape, stays
  `security definer` with `search_path=public`, keeps authenticated EXECUTE,
  keeps anon/public EXECUTE closed, and adds an internal
  `is_approved_member()` check.
- Non-approved statuses (`pending`, `rejected`, `revoked`, `blocked`) are
  rejected with a short generic Japanese message.
- Existing behavior is intended to remain intact: comment/application creation,
  reapplication, withdrawal, edit/delete permissions, spam guards, owner
  notifications, TIMELINE activity, PC snapshot, and GM/admin management
  comment TIMELINE skip.
- The remaining approved-member gates for session post, player characters,
  templates, notifications, TIMELINE, avatar, Discord sync, and GM/admin
  application operations remain separate later gates.
- No SQL Editor execution, SQL apply, DB/RPC/RLS change, Dashboard change, Edge
  deploy, mail sending, Discord sending, or credential recording was performed.
- No concrete user id, email, session id, full URL, token, project identifier,
  or secret is recorded.

Comment/application approved-member RPC gate apply confirmation:

- The user ran
  `docs/supabase/sql/083_membership_gate_comment_application_apply_draft.sql`
  once in their SQL Editor and the apply succeeded.
- The user ran
  `docs/supabase/sql/084_membership_gate_comment_application_post_apply_select_only.sql`
  once as SELECT-only after the 083 apply, and all checks returned `ok`.
- `post_apply_ready_for_comment_application_membership_gate_qa=true`.
- The gate is confirmed on the four comment/application RPCs only:
  `create_application_comment(text,text)`,
  `cancel_my_session_application(text)`,
  `update_application_comment(uuid,text)`, and
  `delete_application_comment_and_maybe_cancel(uuid)`.
- Existing signatures, return shapes, `security definer`, `search_path=public`,
  authenticated-only EXECUTE, anon denial, and public denial were preserved.
- `create_application_comment(text,text)` kept its existing length guard, URL
  count guard, same-user/same-session 60-second cooldown, owner notification
  generation, TIMELINE activity generation, PC snapshot handling, and GM/admin
  management comment TIMELINE skip.
- Application withdrawal, comment edit, comment delete, and maybe-cancel
  behavior kept their existing permission boundaries.
- Web-role direct table write grants on `session_comments` and
  `session_applications` remain closed.
- `public_profiles` still does not expose membership or role state.
- The next gate is functional QA with approved and unapproved users.
- No SQL Editor execution, SQL apply, DB/RPC/RLS change, Dashboard change, Edge
  deploy, mail sending, Discord sending, or credential recording was performed
  by Codex in this documentation step.
- No concrete user id, email, session id, full URL, token, project identifier,
  or secret is recorded.

Comment/application approved-member RPC gate QA planning:

- Added `docs/comment-application-approved-gate-qa-plan.md`.
- The QA execution itself is treated as a separate explicit gate because it can
  create, edit, delete, or cancel real comment/application records.
- Required assets before execution are one approved normal user, one unapproved
  test user, and one safe QA session detail page that will not require Discord,
  Edge, dry_run=false, or broad production-data changes.
- Approved-user success paths should use the session detail UI where possible.
- Unapproved-user frontend checks can use direct page navigation, but the
  DB/RPC rejection proof needs an explicit minimal RPC probe because the
  frontend intentionally hides comment/application controls for unapproved
  users.
- The plan records the target RPCs, pass/fail result template, stop conditions,
  and no-real-value recording rule.
- This planning step does not run the functional QA or call the target RPCs.
- No concrete user id, email, session id, application id, comment id, full URL,
  token, project identifier, or secret is recorded.

Comment/application approved-member RPC gate functional QA result:

- The user completed functional QA for the four comment/application RPCs after
  the 083 apply and 084 SELECT-only all-OK confirmation.
- `qa_executed=true`.
- Approved-user outcomes:
  `approved_create_comment=pass`,
  `approved_cancel_application=pass`,
  `approved_update_comment=pass`, and
  `approved_delete_comment=pass`.
- Unapproved-user outcomes:
  `unapproved_create_comment_rejected=pass`,
  `unapproved_cancel_application_rejected=pass`,
  `unapproved_update_comment_rejected=pass`, and
  `unapproved_delete_comment_rejected=pass`.
- Rejection returned a short Japanese error without exposing internal details.
- GM/admin management comments and existing display behavior were not broken.
- The existing 60-second cooldown, URL maximum 2 guard, length guard,
  notification generation, TIMELINE activity, PC snapshot handling, and
  management-comment skip behavior remained intact.
- There are no unconfirmed items for this first comment/application
  approved-member gate.
- No concrete user id, email, session id, application id, comment id, Discord
  message id, full post URL, token, project identifier, or secret is recorded.

Prelaunch main-flow inventory:

- Added `docs/prelaunch-main-flow-qa-plan.md` as a non-destructive inventory of
  session post, session detail, application/comment, GM/admin, mypage, calendar,
  TIMELINE, and Discord sync surfaces after the first approved-member RPC gate.
- The inventory separates static checks from later live QA gates that can create
  records, edit/delete session posts, or touch Discord sync.
- It records the current actor split for anonymous, approved, unapproved,
  session owner, and admin users.
- Anonymous and unapproved users are intentionally blocked from `calendar`,
  `session-detail`, `timeline`, and `session-post` by the approved-member gate.
  The earlier read-only anonymous browsing expectation was a documentation
  interpretation error and is not a required fix.
- No concrete user id, email, session id, application id, comment id, Discord
  message id, full post URL, token, project identifier, Webhook URL, or secret
  is recorded.

Prelaunch public-site live QA:

- Anonymous public-site checks were run in an in-app browser context.
- `calendar`, `session-detail`, `session-post`, and `timeline` all rendered the
  approved-member gate and did not render their main community operation
  surfaces.
- `mypage` rendered the anonymous account access surface, and no notification
  panel was open.
- No UUID-like or JWT-like text was detected in the checked anonymous page
  bodies.
- Approved, unapproved, owner/GM, and admin live-operation QA was not run in
  this pass because safe authenticated sessions were not available in the
  in-app browser context and the relevant operations can mutate live data or
  touch Discord sync.
- Those authenticated and mutation-capable checks remain explicit later gates.
- No concrete user id, email, session id, application id, comment id, full URL,
  token, project identifier, Discord identifier, Webhook URL, or secret is
  recorded.

Authenticated main-flow QA gate:

- `docs/authenticated-main-flow-qa-plan.md` records the next live QA gate for
  approved, unapproved, owner/GM, and admin actors.
- The user completed the authenticated main-flow QA on their side.
- `qa_executed=true`.
- Approved normal users could view `calendar`, `session-detail`, and `mypage`,
  and the application/comment area displayed naturally.
- Unapproved, pending, or rejected-equivalent users saw the approved-member gate
  and could not browse session content, apply, or comment.
- Owner/GM users saw the GM/admin management area, management links, and close
  control for their own session context.
- Admin users saw admin-oriented controls.
- A normal user could not edit, delete, or close another user's session.
- Final owner/GM edit/delete/close execution, public/non-draft
  create/edit/delete, and any Discord sync operation were not executed and
  remain explicit later gates.
- No concrete user id, email, session id, application id, comment id, full URL,
  token, project identifier, Discord identifier, Webhook URL, or secret is
  recorded.

Membership management delegation preparation:

- Added `docs/membership-management-delegation-plan.md`.
- Added `docs/supabase/sql/085_membership_management_delegation_apply_draft.sql`.
- Added `docs/supabase/sql/086_membership_management_delegation_post_apply_select_only.sql`.
- 085 is an unapplied SQL draft and must not be run without a separate SQL
  Editor approval gate.
- 086 is the post-apply SELECT-only confirmation SQL for that future gate.
- The design keeps admin as the master role while letting approved
  `membership_approver` users manage normal membership review states.
- New management scope is limited to normal users in `pending`, `approved`, and
  `rejected`.
- Allowed status transitions are `pending -> approved`,
  `pending -> rejected`, `rejected -> approved`, and `approved -> rejected`.
- `approved -> pending`, `rejected -> pending`, revoked/blocked management, and
  admin-target status changes remain out of scope.
- Admin-only manager-role RPCs are drafted for granting and revoking the
  limited `membership_approver` role for approved non-admin users.
- The existing pending-only RPCs and mypage UI remain unchanged until 085 is
  applied and 086 confirms the result.
- The next gate is 085 apply-before-final-review, followed by SQL Editor apply,
  086 SELECT-only confirmation, and then a separate UI implementation gate.
- No SQL Editor execution, SQL apply, DB/RPC/RLS mutation, Dashboard change,
  Edge deploy, Discord operation, or secret recording was performed.
- No concrete user id, email, session id, full URL, token, project identifier,
  or secret is recorded.

085/086 apply-before review follow-up:

- The apply-before review found that the original 085 draft would have returned
  raw auth user ids as `member_key` from the membership review list RPC.
- Because raw user ids must not be shown, logged, or passed through the UI
  surface, 085 was revised before apply to add and use an opaque private
  `community_memberships.management_key` action key.
- 086 was revised to confirm the `management_key` column/index, management-key
  lookup in mutation RPCs, and absence of `user_id` columns in the new RPC return
  types.
- The same review narrowed status transitions by removing `rejected -> pending`
  and added a non-admin guard so membership managers cannot change another
  membership manager's status.
- 085 remains unapplied. The next gate is a fresh apply-before review of the
  revised 085/086 before any SQL Editor execution.

Revised 085/086 apply-before re-review:

- Re-reviewed the revised membership management delegation SQL from baseline
  `b2f95e0 Revise membership delegation apply draft`.
- `management_key` is used as the opaque UI/RPC action key instead of raw
  `user_id`, with generation, backfill, default, NOT NULL, and unique-index
  coverage in the 085 draft.
- The four RPCs keep `security definer`, `set search_path = public`, and
  authenticated-only EXECUTE, with internal admin / approved
  `membership_approver` guards.
- Admin remains the only role that can grant or revoke `membership_approver`.
- Non-admin membership managers cannot change admins, themselves, or other
  membership managers.
- Normal status changes are limited to `pending -> approved`,
  `pending -> rejected`, `rejected -> approved`, and `approved -> rejected`;
  `rejected -> pending`, `approved -> pending`, `revoked`, and `blocked` remain
  outside normal management.
- 086 was strengthened so `public_profiles` exposure checks include
  management-key surface columns.
- Re-review result: no remaining blocker was found. 085 can proceed to a
  separate SQL Editor gate for one-time execution, followed by 086 SELECT-only
  confirmation.

## Open Questions For Later Gates

- Whether existing trusted accounts are all backfilled to `approved` in one
  reviewed apply, or whether admins review them manually.
- Whether avatar upload is allowed while pending after moderation rules exist.
- Whether approved status should also mirror into an explicit `member` role.
- Whether membership approver accounts must themselves be `approved` in addition
  to holding the role.
- Whether rejected users can update applicant notes and re-request review.
- Whether pending users can read public comments or only static public pages.

## Non-Goals For This Gate

- No SQL Editor execution.
- No SQL apply.
- No DB/RPC/RLS change.
- No Supabase Dashboard change.
- No Edge deploy.
- No mail or Discord sending.
- No credential, token, concrete user id, concrete email, full URL, session id,
  or project identifier recording.
