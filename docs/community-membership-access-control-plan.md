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
