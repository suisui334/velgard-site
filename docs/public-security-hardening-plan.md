# Public Security Hardening Plan

## Purpose

This document is a non-destructive pre-public security inventory for gradually widening the site beyond the current trusted group.

This batch did not run SQL Editor, change DB/RPC/RLS, apply SQL, deploy Edge Functions, send mail, send Discord messages, change Supabase Dashboard settings, or record credentials/internal concrete values.

## Current Assumptions

- The site is currently operated for a small trusted group.
- Wider public access should assume malicious users, automated signup attempts, spam comments, and scraping.
- Most application writes are intended to go through RPCs rather than direct frontend table mutation.
- Avatar Storage is intentionally public-read because avatars are public profile assets, but object mutation should remain owner-path-only.
- Notification rows are private recipient data.
- Activity TIMELINE rows are shared events with explicit visibility and must not leak draft/private/management-only context.
- Discord sync is a separate high-risk integration and should remain behind explicit gates.

## Inventory Snapshot

Frontend/static review:

- No Supabase JS direct `.insert/.update/.delete/.upsert` table mutation path was found in the current `assets/js` scan.
- Existing frontend DB writes appear to be routed through RPCs.
- Existing frontend direct table access includes read/query paths for display or ownership checks; these still rely on RLS/RPC boundaries and should be audited with 066.
- Avatar upload/remove uses Supabase Storage for the `avatars` bucket and metadata RPCs for profile updates.
- Notification bell and TIMELINE use read/mark-read/timeline RPCs rather than direct notification/activity table mutation.

Known high-risk areas:

- Auth email endpoints can be abused for signup and password-reset email sending.
- Comment/application RPCs need anti-spam throttling before public traffic.
- Public profile and activity surfaces must stay minimal.
- Discord sync must not expose webhook details, duplicate posts, or uncontrolled mentions.

## 066 SELECT-Only Audit

Prepared:

- `docs/supabase/sql/066_public_security_audit_select_only.sql`

Scope:

- Public schema RLS enabled status.
- anon/authenticated table privilege summary.
- Key table direct write grant checks.
- anon/authenticated executable RPC exposure.
- internal helper RPC exposure.
- security definer search path checks.
- Storage bucket and avatar policy shape.
- public profile column exposure.
- notification/activity policy summaries.
- Discord sync RPC exposure.
- Auth user confirmation counts.
- Static comment/application spam guard patterns.
- TIMELINE visibility and management-comment skip patterns.

Safety:

- SELECT-only.
- Returns counts, booleans, names, signatures, and status notes.
- Does not return row contents, contact values, concrete account identifiers, concrete session/activity/notification identifiers, full external addresses, project identifiers, or credential values.
- SQL Editor execution is a separate gate.

### 066 Result Summary

`066` was run once by the user in Supabase SQL Editor as a SELECT-only gate.
No DB/RPC/RLS changes, SQL apply, Dashboard changes, Edge deploy, mail sending,
Discord sending, or credential recording were performed.

Confirmed OK:

- Public base tables have RLS enabled.
- anon/authenticated roles have no direct public table write grants.
- Key tables for sessions, notifications/activity, profiles, and roles have no direct web-client write grants.
- Internal notification/activity helper functions are not directly executable by anon or authenticated web-client roles.
- Discord sync RPCs are not anon-executable.
- `public_profiles` remains minimal by column-name review.
- notification/activity policies are present.
- avatars bucket and owner-path Storage policy shape match the current MVP.

Review items:

- `security_definer_search_path`: `security_definer=55`, `missing_search_path=38`.
- `rpc_anon_exposure_summary`: `anon_executable=5`, `anon_non_read_named=2`.
- `comment_application_spam_guards_static`: length guard present, cooldown and URL-count guards missing by static pattern.
- `timeline_activity_visibility_static`: authenticated activity pattern present; the management-skip detector needs a more precise check.
- Auth/mail abuse controls still require Dashboard and provider review outside SQL.

### 067 Review Detail Audit

Prepared:

- `docs/supabase/sql/067_public_security_review_details_select_only.sql`

Scope:

- List `security definer` functions that do not pin `search_path=public`, returning function signatures and booleans only.
- List anon-executable RPCs with read-name/helper/security-definer/search-path flags.
- Detail `create_application_comment(text,text)` anti-spam guard patterns.
- Re-check whether GM/admin management comments can enter shared TIMELINE activity, using the post-064/065 static patterns.
- Include an explicit Dashboard-only gate note for CAPTCHA, Auth rate limits, signup/reset abuse controls, and Resend bounce/suppression checks.

Safety:

- SELECT-only.
- Does not return function bodies or row contents.
- Does not return concrete user, session, activity, notification, email, project, URL, token, key, or secret values.
- SQL Editor execution remains the next independent gate.

### 067 Result Summary

`067` was run once by the user in Supabase SQL Editor as a SELECT-only detail
gate. No DB/RPC/RLS changes, SQL apply, Dashboard changes, Edge deploy, mail
sending, Discord sending, or credential recording were performed.

Confirmed OK or low-risk:

- Public table RLS, direct table write grants, key table write grants, internal helper direct execute, Discord anon exposure, public profile column shape, avatar Storage, and notification/TIMELINE policy checks remained OK from 066.
- `activity_events` contains authenticated PL activity rows.
- Management-like activity heuristic returned zero.
- `get_activity_timeline(integer)` and `get_public_session_comments(text)` are anon-readable RPCs that are easier to justify as public/read surfaces.

P0 candidate:

- `rls_auto_enable()` and `set_updated_at()` were anon-executable non-read-named RPCs.
- They should not be directly callable by web-client roles before wider public exposure.

P1 follow-up:

- `get_public_session_application_counts(text)` is read-like, but needs `search_path=public` cleanup.
- 38 security definer functions do not currently report `search_path=public`.
- Comment/application cooldown and URL-count guards are still missing.
- Auth/signup/reset abuse hardening needs Dashboard/provider review for CAPTCHA, Auth rate limits, and Resend bounce/suppression handling.

### 068/069 Unsafe Anon RPC Revoke Draft

Prepared:

- `docs/supabase/sql/068_public_security_revoke_unsafe_anon_rpc_apply_draft.sql`
- `docs/supabase/sql/069_public_security_revoke_unsafe_anon_rpc_post_apply_select_only.sql`

Scope:

- `068` revokes direct EXECUTE on `public.rls_auto_enable()` and `public.set_updated_at()` from `public`, `anon`, and `authenticated`.
- `068` does not change function bodies, triggers, tables, RLS policies, Storage policies, or read RPCs.
- `069` confirms the target functions still exist, web-client EXECUTE is closed, and `set_updated_at()` remains referenced by triggers by count only.

Safety:

- `068` is an apply draft and is not executed in this batch.
- `069` is SELECT-only and is not executed in this batch.
- No concrete account/contact/internal identifiers, full external addresses, project identifiers, or credential values are recorded.

### 068/069 Apply Result

`068` was run once by the user in Supabase SQL Editor and applied successfully.
`069` was then run once as a SELECT-only confirmation and returned OK.

Confirmed:

- The scope was limited to `rls_auto_enable()` and `set_updated_at()`.
- Both target functions still exist.
- Direct EXECUTE from `public`, `anon`, and `authenticated` is closed for both target functions.
- `set_updated_at()` trigger references remain, so internal trigger usage is preserved while direct web-client execution is no longer exposed.
- `post_apply_ready_for_public_security_qa=true`.

Conclusion:

- The unsafe anon RPC exposure identified as a P0 candidate in `067` is treated as resolved.
- No additional SQL Editor execution, DB/RPC/RLS changes, Dashboard changes, Edge deploy, mail sending, Discord sending, or credential recording were performed in this recording step.
- Remaining public-readiness follow-up moves to P1 items: Auth CAPTCHA/rate-limit/password-reset abuse controls, comment/application spam guards, and security definer `search_path=public` cleanup.

### 072 Security Definer Search Path Inventory

Prepared:

- `docs/security-definer-search-path-audit.md`
- `docs/supabase/sql/072_security_definer_search_path_inventory_select_only.sql`
- `docs/supabase/sql/073_security_definer_search_path_exact_select_only.sql`

Scope:

- Non-destructive classification of security definer functions that do not
  report `search_path=public`.
- Categorize functions into high-priority web surfaces, additional-confirmation
  candidates, trigger/internal functions, and low-priority or historical
  candidates.
- Return function signatures, owner role names, search_path flags, EXECUTE
  exposure, trigger-reference counts, and broad object-reference hints only.

Decision:

- The user ran 072 once as SELECT-only. It reported `security_definer=55`,
  `search_path_public=17`, `needs_review=38`, `missing_any_search_path=0`,
  `p0=0`, `p1=36`, `p2=2`, `high_web=35`,
  `additional_confirmation=1`, `trigger_internal=1`, and `low=1`.
- Because `missing_any_search_path=0`, the remaining review is not a complete
  missing-search-path emergency. It is a review of functions whose configured
  path is not exactly `public`.
- The user then ran 073 once as SELECT-only. It confirmed `security_definer=55`,
  `search_path_public=17`, `needs_review=38`, `missing_any_search_path=0`,
  and `p0=0`.
- No function used `$user` or `pg_temp` in its configured search_path.
- 37 review rows were `search_path=""` safe empty-path candidates. This is a
  strict setting when function bodies use schema-qualified references and is
  not treated as a dangerous path.
- The P1 web-facing rows were safe empty-path candidates, so a broad
  search_path apply is not needed.
- The only manual-review row was `rls_auto_enable()` with `search_path=pg_catalog`;
  direct EXECUTE is closed for web-client roles and service role, and trigger
  references are 0, so it remains low-priority historical/supporting cleanup.
- `handle_new_auth_user_profile()` remains trigger/internal, safe-empty-path
  candidate, and externally closed.
- The search_path P1 item is considered complete/hold: no P0, no dangerous
  path, and no bulk cleanup needed.

Safety:

- SQL Editor execution, SQL apply, DB/RPC/RLS changes, Dashboard changes, Edge
  deploy, mail sending, Discord sending, and credential recording are not
  performed in this preparation step.
- No concrete user id, email, session id, activity id, notification id, full
  URL, project identifier, token, key, or secret value is recorded.

## Priority List

### P0: Must Fix Before Wider Public Release

- Add CAPTCHA to signup and password-reset request flows, preferably Cloudflare Turnstile or equivalent.
- Review Supabase Auth rate limits for signup and password-reset email sending.
- Decide whether public signup should remain open, become invite-code gated, or require admin approval before write privileges.
- Add frontend submit debouncing/disabled states for signup and password-reset forms to reduce accidental repeated sends.
- Add comment/application RPC cooldowns per user and per session.
- Add URL-count and excessive-length guardrails for comments/applications.
- Run 066 SELECT-only audit and review any `review` rows before broader publication.
- Verify anon has no direct table mutation privileges and no non-read RPCs beyond intentionally public read/check functions.
- Revoke web-client EXECUTE from non-read helper/trigger RPCs such as `rls_auto_enable()` and `set_updated_at()`. Done for the 067 P0 targets by the 068/069 gate.
- Verify internal helper RPCs for notifications/activity are not executable by web client roles.
- Verify private notifications are recipient-only and GM/admin management comments do not enter shared TIMELINE.
- Keep Discord `@everyone`, dry-run, deploy, and real-send operations as explicit gates.

### P1: Should Fix Before Small Public Expansion

- Add display name moderation rules: length, control-character rejection, impersonation guidance, and admin rename path.
- Decide handling for unconfirmed mail accounts: read-only, blocked from posting, or cleanup review.
- Add community membership approval gates before comment/application posting and other interactive writes.
- Clean up security definer functions that do not pin `search_path=public`.
- Review and repair `get_public_session_application_counts(text)` search_path while preserving its read-only public surface.
- Add admin-facing moderation tools for comments/applications: hide, delete, or lock comment posting on a session.
- Add rate monitoring for Resend bounce/suppression and Supabase Auth email activity.
- Add admin documentation for responding to spam users and inappropriate avatars.
- Add a safe avatar moderation policy: report/remove workflow and old-object cleanup plan.
- Review public profile columns any time profile fields are added.
- Add periodic SELECT-only security audit procedure using 066 or follow-up diagnostics.

### P2: Improve After Initial Public Use

- Add activity/timeline filters and anti-noise controls if comments become frequent.
- Add per-user notification preferences before any email notification expansion.
- Add session-level comment lock/cooldown overrides for GM/admin.
- Add abuse telemetry dashboards with counts only, no private row dumps.
- Add bounce/suppression maintenance checklist for mail provider operations.
- Add automated stale avatar object cleanup after delete/replace once safe operational controls exist.
- Add Discord resync/repair UI only after duplicate-post and permission boundaries are re-reviewed.

### P3: Future Expansion

- Invite-code issuance and admin approval workflow.
- Trust tiers for new users.
- Full audit log viewer for admin-only operational diagnostics.
- Report/appeal flow for comments, profiles, and avatars.
- Fine-grained TIMELINE visibility model for GM/admin-only operational events.
- Email notifications using existing Custom SMTP after preference/rate-limit design.

## Area Notes

### Auth And Mail Abuse

Risks:

- Bulk signup emails.
- Bulk password-reset emails.
- Sending to nonexistent addresses causing bounce/suppression.
- Mail provider quota exhaustion.

Initial hardening:

- CAPTCHA on signup and reset request forms, with Cloudflare Turnstile as the first candidate.
- UI-side cooldown and disabled submit state for signup/reset request forms.
- Dashboard rate-limit review in a separate settings gate.
- Mail-provider bounce/suppression review procedure for the current Custom SMTP provider.
- Consider invite/admin approval before opening signup broadly.

Planning status:

- `docs/auth-abuse-protection-plan.md` defines the non-destructive rollout sequence.
- Dashboard changes, CAPTCHA secret entry, frontend CAPTCHA implementation, QA, and rate-limit changes are separate gates.
- The current MVP recommendation is CAPTCHA on signup and password reset first; login CAPTCHA remains optional until abuse patterns justify the extra friction.
- Password reset repeat-submit protection should avoid storing submitted emails in browser storage and should remain secondary to Supabase-side CAPTCHA/rate limits.
- Current Supabase Auth Rate Limits were reviewed without saving changes. The email-send limit is 30 emails/h, so signup/password-reset abuse can still consume the hourly mail budget.
- Next candidate remains CAPTCHA introduction, especially for signup and password reset.

### Registration Spam

Risks:

- Bulk account creation.
- Abusive display names.
- Unconfirmed accounts posting.
- Community outsiders signing up and immediately using write features.

Initial hardening:

- Confirmed-mail requirement before posting/commenting.
- Display name validation and admin rename/disable path.
- Community membership approval gate before public interactions.

Membership approval status:

- `docs/community-membership-access-control-plan.md` records the non-destructive
  approval-control design.
- `docs/supabase/sql/074_membership_access_control_inventory_select_only.sql`
  was run once as the first inventory diagnostic.
- `docs/supabase/sql/075_membership_direct_write_grants_detail_select_only.sql`
  was run once as a follow-up diagnostic.
- `docs/supabase/sql/076_revoke_player_characters_truncate_apply_draft.sql`
  and `docs/supabase/sql/077_revoke_player_characters_truncate_post_apply_select_only.sql`
  were run once by the user as the narrow cleanup apply and SELECT-only
  confirmation gate.
- Invite codes are not adopted for the first gate.
- New accounts should start as `pending`; only `approved` members can use major
  interactive features.
- Pending users may log in and update account/profile/application information
  needed for review, but should not create sessions, comment/apply, manage PCs
  or templates, use Discord sync, or use notifications/TIMELINE.
- `membership_approver` is designed as a limited authority separate from
  `admin`; it can approve or reject pending users only.
- Granting/removing `membership_approver`, blocking/unblocking users, forced
  status changes, and strong moderation remain admin-only.
- The gate must be enforced in DB/RPC helpers, not only by hiding frontend
  buttons.
- 074 confirmed that membership state is not implemented yet, `user_roles`
  exists, `has_role(text)` / `is_admin()` exist, and `membership_approver`
  appears feasible through the existing role mechanism.
- 074 reported 34 approved-gate candidate RPCs and three pending-allowed profile
  RPC candidates.
- 074 also reported `direct_write_grants=2`; 075 clarified the wider direct
  write surface as 26 grants, with 24 Storage expected exceptions and two
  app-table review grants.
- The two review grants are `TRUNCATE` on `public.player_characters` for
  `anon` and `authenticated`; 076 revoked the unnecessary direct TRUNCATE
  exposure.
- 077 confirmed `public.player_characters` exists, direct TRUNCATE grants for
  `public`, `anon`, and `authenticated` are 0, direct INSERT/UPDATE/DELETE
  grants are 0, and `post_apply_ready_for_membership_schema_design=true`.
- Storage expected exceptions were intentionally out of scope and were not
  changed.
- The 075 player-character TRUNCATE finding is resolved, so the next gate can
  return to membership schema/helper design.
- `docs/supabase/sql/078_membership_foundation_apply_draft.sql` and
  `docs/supabase/sql/079_membership_foundation_post_apply_select_only.sql` are
  prepared. The first 078 SQL Editor apply attempt stopped with a syntax error
  and was not rerun.
- 078 keeps membership state in a private `community_memberships` table,
  backfills existing users as `approved`, creates `pending` rows for future
  signups through a separate auth trigger, and adds helper RPCs for approved
  member and membership approver checks.
- 078 does not add the 34 approved gates, approve/reject RPCs, approver UI,
  invite codes, email deny lists, Discord, Edge, mail, or Dashboard changes.
- The 078 syntax error was caused by using `current_user` as a table alias in
  `get_my_membership_status()`. The draft was corrected to use `auth_context`.
- `docs/supabase/sql/080_membership_foundation_failed_apply_state_select_only.sql`
  was prepared to check for partial objects from the failed attempt before
  another apply gate.
- 080 was run once as SELECT-only and showed no partial membership foundation
  objects from the failed attempt.
- The corrected 078 was run once in the user's SQL Editor and the apply
  succeeded.
- 079 was run once as SELECT-only after the corrected 078 apply, and all checks
  were OK.
- `community_memberships` exists with RLS enabled, required columns, status and
  review-note constraints, own-status and admin/approver read policies, and
  closed web-role direct table grants.
- Existing auth users were backfilled as `approved`, missing membership count is
  0, and the future-signup `pending` trigger exists.
- Membership helper RPCs exist, use security definer with `search_path=public`,
  are authenticated-only for web execution, and the auth trigger function is not
  directly executable by web roles.
- `public_profiles` does not expose membership or role state.
- `post_apply_ready_for_membership_gate_design=true`.
- The next gate is approved-member gate design or membership approver RPC
  design.
- `docs/supabase/sql/081_membership_approval_rpc_apply_draft.sql` was run once
  in the user's SQL Editor and the apply succeeded.
- `docs/supabase/sql/082_membership_approval_rpc_post_apply_select_only.sql`
  was run once as SELECT-only after the 081 apply, and all checks were OK.
- 081 is limited to pending-list, approve, and reject RPCs. It does not add the
  34 approved gates, approver UI, forced status changes, role management RPCs,
  invite codes, Auth email hooks, email hash deny lists, Discord, Edge, mail,
  Storage, or Dashboard changes.
- The intended authority split remains: admin can approve/reject pending users,
  and `membership_approver` can approve/reject pending users only when the
  approver account is itself approved.
- The pending-list, approve, and reject RPCs exist, are security definer
  functions with `search_path=public`, are executable by `authenticated` only,
  and are not executable by `anon` or `public`.
- The RPCs keep internal admin/approved-approver guards, self-action denial,
  pending-only transitions, `review_note` length guard, no email
  reference/return, closed direct grants on `community_memberships`, and no
  membership/role exposure through `public_profiles`.
- `post_apply_ready_for_membership_approval_rpc_qa=true`.
- The next gate is approval RPC functional QA.
- `docs/membership-approval-rpc-qa-plan.md` prepares that functional QA around
  the mypage approval UI instead of temporary console calls. It requires
  disposable pending QA accounts, avoids SQL Editor and direct table writes,
  defers membership-approver-path QA until role provisioning has its own
  reviewed gate, and records only status-level results.
- The UI gate adds pending-list, approve, and reject operation surfaces only; it
  does not add approved-member gates, revoked/blocked management, forced status
  changes, or role-grant UI.
- The user completed mypage approval UI/RPC functional QA.
- Admin could view pending users, approve one disposable pending user, and
  reject one disposable pending user through the UI.
- The UI did not show email values or concrete user ids.
- Approved/rejected membership status displays were confirmed from the target
  users' mypage views.
- Rejected users and normal approved non-admin users did not see the approval
  panel.
- The approval UI/RPC path is treated as successful.
- The 34 approved-member gates, revoked/blocked operations, force-status
  administration, and membership approver role-grant UI remain separate later
  public-hardening gates.
- A frontend-only unapproved-member display restriction was added after the UI
  QA.
- `pending`, `rejected`, `revoked`, and `blocked` users are guided to minimal
  mypage account maintenance and do not receive normal UI access to calendar,
  session detail, session-post forms, comments/applications, notification bell,
  TIMELINE, avatar settings, PC management, template management, or application
  history.
- Public information pages remain available.
- This is not a security boundary. It closes normal UI paths, while direct RPC
  and URL enforcement remains a later approved-member gate.
- Static checks and local HTTP display checks were performed; live operation QA
  was skipped for this frontend-only step.

### Comment/Application Spam

Risks:

- Repeated comments/applications.
- Long text and many links.
- Notification bell and TIMELINE spam.

Initial hardening:

- RPC-level cooldown per user/session.
- Body length and URL-count limits.
- Optional session-level lock or GM/admin moderation action.
- Keep notification/activity generation transactional so failures are visible during QA.

Preparation status:

- `067` classified comment/application spam guards as a public-readiness review item: existing length guard was present, while cooldown and URL-count guards were missing.
- `070_comment_application_spam_guard_apply_draft.sql` was later run once by the user in SQL Editor and applied successfully.
- The first `071_comment_application_spam_guard_post_apply_select_only.sql` post-apply check confirmed the RPC, signature, privileges, cooldown, length guard, notifications, activity generation, PC snapshot handling, and management-comment TIMELINE skip, but reported `create_application_comment_url_count_guard=review` because the regex-pattern detector did not match the applied function text.
- The URL guard implementation itself still has the counter, `regexp_matches(v_comment_body, ...)`, `> 2` threshold, and safe error branch, so this was treated as a SELECT-only detection mismatch rather than a DB/RPC fix.
- The revised `071_comment_application_spam_guard_post_apply_select_only.sql` was rerun once as SELECT-only and returned all OK.
- The confirmed OK items include `create_application_comment(text,text)` existence/signature, `security definer`, `search_path=public`, authenticated-only EXECUTE, anon denial, existing length guard, URL counter, URL `> 2` threshold, URL error branch, same-user/same-session PL comment/application 60-second cooldown, PL-branch cooldown scope, owner notification preservation, TIMELINE activity generation preservation, GM/admin management activity skip preservation, and PC snapshot preservation.
- `post_apply_ready_for_comment_spam_guard_qa=true`.
- The 070 draft is limited to `public.create_application_comment(text,text)`.
- Planned guards:
  - same user and same session PL comment/application cooldown for 60 seconds;
  - maximum two URL-like tokens per submitted body.
- Existing owner notification generation, PL activity generation, PC snapshot handling, and GM/admin management-comment shared TIMELINE skip are confirmed preserved by the revised 071 check.
- Real QA after the 070 apply confirmed that a test PL account can post one normal comment to a test session, same-PL/same-session repeat posting within 60 seconds is blocked, a body with three URL-like tokens is blocked, and a body with two URL-like tokens is accepted.
- Refreshing the session detail page after posted comments showed no comment-display regression.
- The expected operating pattern of one character-sheet URL plus one supplemental URL remains allowed.
- The comment/application spam guard is considered ready for operation, and this public-readiness P1 item is complete.
- No real user id, email, session id, activity id, notification id, full URL, token, key, project identifier, or secret value is recorded.

### RLS/RPC

Risks:

- Direct table mutation grants to anon/authenticated.
- Helper RPCs directly executable by web clients.
- security definer functions without search path.
- Public profile view leaking fields.

Initial hardening:

- Run 066.
- Review every `review` row.
- Treat direct table mutation grants and missing search path as P0 unless there is a documented reason.
- Keep helper RPCs internal.

### Storage / Avatars

Risks:

- Inappropriate images.
- Cross-user object overwrite.
- Large or unsupported file upload.
- Old avatar objects left behind.

Initial hardening:

- Keep public read for avatars but owner-path-only mutation.
- Keep MIME and size limits.
- Add moderation/removal procedure.
- Plan safe stale-object cleanup later.

### Discord Sync

Risks:

- Accidental `@everyone`.
- Duplicate posts.
- Existing post edits/deletes by unauthorized users.
- Webhook or post identifiers exposed.

Initial hardening:

- Keep every deploy, dry-run, and real-send as a separate gate.
- Keep mention mode explicit and create-only.
- Keep allowed mentions restricted.
- Keep sync RPC permission checks owner/admin based.
- Never record webhook values or concrete Discord identifiers in docs.

### TIMELINE And Notifications

Risks:

- Draft/private/management activity leaking into shared TIMELINE.
- Private recipient notifications visible to others.
- Logged-out TIMELINE showing too much.

Initial hardening:

- Keep notifications recipient-scoped.
- Keep PL comment/application activity `authenticated`.
- Keep GM/admin management comments out of shared TIMELINE.
- Review any new activity event type before enabling it.

## Recommended Next Gates

1. Keep security definer search_path checks as a per-RPC review requirement when future functions are changed.
2. Prepare a SELECT-only membership inventory diagnostic before any membership schema/apply draft.
3. Prepare moderation UI plan for comments, profiles, and avatars.

## Auth CAPTCHA Frontend Gate

Status: Supabase-side CAPTCHA enforcement is enabled and the frontend integration
has been added as a follow-up gate.

Notes:

- Supabase Attack Protection CAPTCHA was enabled with Cloudflare Turnstile in a
  separate Dashboard gate.
- The Turnstile secret key remains Dashboard-only and is not recorded.
- The frontend now has a runtime `turnstileSiteKey` field for the public site
  key, but the concrete value is not recorded in docs.
- Login, signup, and password-reset request forms pass a Turnstile
  `captchaToken` to Supabase Auth.
- Missing site-key or incomplete CAPTCHA blocks Auth requests before they reach
  Supabase.
- Live signup/password-reset/login QA is still a separate gate because it sends
  Auth traffic and mail.

Security impact:

- This addresses the next Auth/mail abuse mitigation after the unsafe anon RPC
  exposure was closed.
- Rate-limit settings still remain unchanged.
- Password-reset local cooldown and server-side comment/application spam guards
  remain separate follow-up tasks.

Follow-up status:

- The public Turnstile site key has been configured in runtime config without
  recording the concrete value in docs.
- The Turnstile secret key remains Supabase Dashboard-only.
- Runtime config cache-bust for mypage was updated.
- The password-reset flow was verified on the public site after Turnstile
  integration: CAPTCHA display/success, one reset request, reset mail delivery,
  new-password form return, password update, and login with the new password all
  succeeded.
- The signup flow was verified on the public site after Turnstile integration:
  CAPTCHA display/success, one signup request, confirmation mail delivery,
  confirmation return to mypage, logout, and re-login with the new QA account all
  succeeded.
- Login, password-reset, and signup QA are all confirmed, so the Turnstile Auth
  abuse-protection MVP is complete.
- No concrete email, password, recovery/confirmation token, JWT/session token,
  full URL, concrete Turnstile site key, or Turnstile secret key value is
  recorded.

## Membership Approved Gate Follow-Up

Status: frontend restriction is implemented; the first DB/RPC gate is applied
and functional QA is confirmed.

Notes:

- Unapproved users now receive frontend approval guidance for normal UI flows,
  including calendar, session detail, session post, TIMELINE, notification, PC,
  template, and avatar surfaces.
- Frontend hiding is only a normal-operation/UX guard. Raw RPC calls still need
  server-side approved-member checks.
- `083_membership_gate_comment_application_apply_draft.sql` prepares the first
  narrow server-side gate for comment/application RPCs only.
- `084_membership_gate_comment_application_post_apply_select_only.sql` prepares
  the post-apply SELECT-only confirmation.
- The draft covers only `create_application_comment(text,text)`,
  `cancel_my_session_application(text)`,
  `update_application_comment(uuid,text)`, and
  `delete_application_comment_and_maybe_cancel(uuid)`.
- The rest of the approved-member gate list remains intentionally out of this
  draft and should be handled through smaller later gates.
- The user ran 083 once in SQL Editor and the apply succeeded.
- The user ran 084 once as SELECT-only after the apply, and every check returned
  `ok`.
- `post_apply_ready_for_comment_application_membership_gate_qa=true`.
- Existing signatures, return shapes, security definer mode,
  `search_path=public`, authenticated-only EXECUTE, existing
  comment/application guards, owner notifications, TIMELINE activity, PC
  snapshot handling, and management-comment TIMELINE skip were confirmed.
- Direct table write grants on comment/application tables remain closed, and
  `public_profiles` still does not expose membership or role state.
- `docs/comment-application-approved-gate-qa-plan.md` records the
  approved/unapproved functional QA gate.
- Functional QA confirmed that approved users can perform the target
  comment/application operations and that unapproved, pending, or
  rejected-equivalent users are rejected by the four target RPCs.
- The rejection path returns a short Japanese error without exposing internal
  details.
- GM/admin management comments, existing display behavior, 60-second cooldown,
  URL maximum 2 guard, length guard, notifications, TIMELINE activity, PC
  snapshot handling, and management-comment skip behavior remained intact.
- No unchecked item remains for this first comment/application approved-member
  gate.
- No additional SQL Editor execution, SQL apply, DB/RPC/RLS mutation, Dashboard
  change, Edge deploy, mail sending, Discord sending, or secret recording was
  performed by Codex in the documentation step.
- No concrete user id, email, session id, full URL, token, project identifier,
  or secret is recorded.

## Prelaunch Main Flow Inventory

Status: non-destructive inventory prepared.

Notes:

- `docs/prelaunch-main-flow-qa-plan.md` records the main public-site flow
  inventory after the membership frontend restrictions and the first
  comment/application approved-member RPC gate.
- The inventory covers unauthenticated visitors, approved users, unapproved
  users, session owners, and admins.
- Static review confirms that normal UI no longer loads static session JSON
  fixtures unless an explicit development URL flag is present.
- Static review confirms that the inspected `public_profiles` frontend path
  selects `display_name` only, and recent SQL checks already confirmed no
  membership/role exposure.
- Discord sync wiring remains present for session create/update/delete, so live
  session-post QA must be split from Discord-safe QA gates.
- Anonymous and unapproved users are intentionally blocked from `calendar` and
  `session-detail` by the approved-member gate; this is the correct access
  control behavior, not a launch-policy mismatch.
- Live QA for session-post create/update/delete, owner close/delete, broader
  admin management, approved-user calendar visual state, mypage empty/status
  state, authenticated unapproved gate display, and Discord sync remains
  separated into explicit later gates.
- A first public-site anonymous live check was run in the in-app browser:
  `calendar`, `session-detail`, `session-post`, and `timeline` rendered the
  approved-member gate and did not render their main community operation
  surfaces.
- Anonymous `mypage` rendered the account access surface, and no notification
  panel was open.
- No UUID-like or JWT-like text was detected in the checked anonymous page
  bodies.
- Approved, unapproved, owner/GM, and admin live-operation QA remains separated
  because safe authenticated sessions were not available in the in-app browser
  context and those flows can mutate live data or touch Discord sync.
- No SQL Editor execution, SQL apply, DB/RPC/RLS mutation, Dashboard change,
  Edge deploy, dry_run=false, Discord operation, mail sending, or secret
  recording was performed in this inventory step.
- No concrete user id, email, session id, application id, comment id, Discord
  message/channel id, full post URL, token, project identifier, Webhook URL, or
  secret is recorded.

## Non-Goals In This Batch

- SQL Editor execution.
- DB/RPC/RLS mutation.
- SQL apply.
- Edge Function deploy.
- Email sending.
- Discord sending.
- Supabase Dashboard changes.
- Recording concrete account/contact/internal identifiers, full external addresses, project identifiers, or credential values.
