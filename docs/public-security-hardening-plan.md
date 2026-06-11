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
  is prepared as a follow-up diagnostic and is not executed yet.
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
- 074 also reported `direct_write_grants=2`; details must be checked with 075
  before schema/helper draft work.
- This planning step created no SQL apply draft and performed no DB/RPC/RLS or
  Dashboard change.
- The next gate is a one-time SELECT-only 075 SQL Editor run, then deciding
  whether direct write grants need a separate revoke review or can be treated as
  expected exceptions.

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

## Non-Goals In This Batch

- SQL Editor execution.
- DB/RPC/RLS mutation.
- SQL apply.
- Edge Function deploy.
- Email sending.
- Discord sending.
- Supabase Dashboard changes.
- Recording concrete account/contact/internal identifiers, full external addresses, project identifiers, or credential values.
