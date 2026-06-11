# Notification and Activity Timeline Plan

## Purpose

This plan prepares a non-destructive design for in-site notifications and an activity timeline. It does not apply SQL, change DB/RPC/RLS, deploy Edge Functions, send email, or send Discord messages.

The first MVP should focus on site-internal notifications. Email notifications can be added later because Custom SMTP is available, but mail delivery should remain a separate gate.

## Current Data Flow

- Session creation and editing use `create_session_post` / `update_session_post`.
- Session comments and participation applications use `create_application_comment`.
- GM application status changes use `set_application_status`.
- Session detail comment display uses `get_public_session_comments`.
- The global header is rendered from `assets/js/main.js`; logged-in mypage behavior currently augments ACCOUNT/logout from `assets/js/mypageAuthClient.js`.
- Public display identity is based on `profiles.display_name` through public-facing views/RPCs. Raw auth identifiers and email values should not be exposed.

## MVP Scope

The recommended MVP is a private `user_notifications` table plus read/mark-read RPCs:

- Notify the owner/GM when a logged-in user comments or applies to their session.
- Do not notify a GM about their own comment/application.
- Store unread/read state with `read_at`.
- Show a bell icon in the site header for logged-in users.
- Show an unread count badge.
- Open a compact notification list from the bell.
- Clicking a notification opens the related session detail page.
- Mark one notification as read and optionally mark all as read.

The notification text should avoid raw internal identifiers. UI links may use the existing session detail route, but docs, logs, and QA notes must not record concrete ids or full URLs.

## Activity Timeline Scope

The timeline is related but not identical to private notifications. The safer design is a separate `activity_events` table:

- `user_notifications` is private and recipient-specific.
- `activity_events` is a feed of events with explicit `visibility`.
- Public events can be shown to anyone.
- Authenticated-only events can be shown only to logged-in users.
- Private notification state should not be inferred from the public timeline.

This separation avoids accidentally exposing another user's private notifications through a public timeline.

## DB Design Candidate

### `user_notifications`

Candidate fields:

- `id`
- `recipient_user_id`
- `actor_user_id`
- `session_id`
- `notification_type`
- `title`
- `body`
- `target_path`
- `metadata`
- `read_at`
- `created_at`

Recommended notification types for MVP:

- `session_comment`
- `session_application`
- `application_status_changed`

Future types:

- `session_created`
- `session_updated`
- `session_comment_updated`

### `activity_events`

Candidate fields:

- `id`
- `actor_user_id`
- `session_id`
- `event_type`
- `visibility`
- `title`
- `body`
- `target_path`
- `metadata`
- `created_at`

Recommended visibility values:

- `public`
- `authenticated`
- `private`

For MVP, timeline writes can be limited to session creation and public comments/applications after a separate review. Private notification delivery should not depend on public timeline visibility.

## RLS and RPC Policy

Notification rows must be recipient-only:

- A recipient can read their own notifications.
- A recipient can mark their own notifications read.
- Other users cannot read or mutate them.
- Admin access can be considered for operational diagnostics, but should not be required for MVP UI.

The safer first implementation is RPC-first:

- No direct table mutation grants to web clients.
- Do not add a direct table update policy for mark-read; use RPCs so users cannot alter notification text or targets.
- `get_my_notifications(...)`
- `get_my_unread_notification_count()`
- `mark_my_notification_read(...)`
- `mark_all_my_notifications_read()`
- Internal helper `create_session_owner_notification(...)` is called from existing RPCs later, not directly by clients.

Timeline reads should go through a filtered RPC such as `get_activity_timeline(...)` so public/authenticated visibility is enforced in one place.

All `security definer` functions should pin `search_path = public`, following the current project convention.

## Frontend Integration Plan

### Header Bell

Add a logged-in-only notification bell near ACCOUNT/logout:

- Reuse the existing header area rendered by `main.js`.
- Let the auth-aware mypage/client-side code hydrate count and list when a Supabase session exists.
- If unauthenticated, show no bell or a disabled zero state.
- Keep the bell independent from Discord notifications.

Implementation status:

- Added a shared header notification bell module.
- Runtime Supabase config is loaded on every HTML page so the shared header can detect an authenticated session outside mypage as well.
- The bell is shown only when a Supabase session exists.
- Unread count is loaded through `get_my_unread_notification_count()`.
- The dropdown list is loaded through `get_my_notifications(...)`.
- Individual read state uses `mark_my_notification_read(...)`.
- Bulk read state uses `mark_all_my_notifications_read()`.
- No direct frontend write to `user_notifications` was added.
- No real notification id, user id, session id, email, full URL, project ref, token, or secret was recorded.

### Notification List

The first UI can be a lightweight dropdown or mypage details section:

- Show unread first.
- Show recent notifications with title, short body, created time, and link.
- Provide "mark as read" and "mark all as read".
- Avoid displaying raw ids, emails, tokens, or full external URLs.

### Timeline Page

Future page candidate:

- `timeline.html` or a mypage subsection.
- Public mode can show only public activity.
- Logged-in mode can include authenticated-only activity.
- Private notifications should remain in the notification UI, not mixed into public timeline rows.

## Existing RPC Instrumentation Plan

Do not patch existing comment/application/session RPCs in the first schema apply unless the live definitions have been reviewed immediately before apply.

Suggested later instrumentation:

- `create_application_comment`
  - Insert comment/application as today.
  - Call `create_session_owner_notification(...)`.
  - Optionally call `record_activity_event(...)`.
- `set_application_status`
  - Notify the applicant when status changes, if desired in a later phase.
- `create_session_post`
  - Record a public or authenticated activity event.
- `update_session_post`
  - Record an activity event only if useful; avoid noisy updates at first.

## Email Notification Future

Email notification should remain a later explicit gate:

- Custom SMTP is available through Resend.
- Do not send email during notification schema/frontend MVP.
- Add per-user notification preferences before enabling mail.
- Email content must not include private identifiers or secrets.
- Rate limiting and unsubscribe/preference UX should be considered before launch.

## SQL Drafts

Prepared candidates:

- `docs/supabase/sql/057_notifications_schema_apply_draft.sql`
- `docs/supabase/sql/058_notifications_post_apply_select_only.sql`
- `docs/supabase/sql/059_notifications_instrument_session_events_apply_draft.sql`
- `docs/supabase/sql/060_notifications_instrument_post_apply_select_only.sql`

`057` was applied once by the user in Supabase SQL Editor after a separate approval gate.

`058` was run once as the post-apply SELECT-only confirmation and returned OK for the notification/timeline foundation.

Post-apply confirmation summary:

- `user_notifications` table exists.
- `user_notifications` RLS is enabled.
- Notification policies and constraints are OK.
- `activity_events` table exists.
- `activity_events` RLS is enabled.
- Activity policies and constraints are OK.
- Notification list/count/mark-read RPCs exist.
- Timeline/activity helper and read RPCs exist.
- Security definer functions have `search_path=public`.
- Notification RPCs are executable by authenticated users and not by anon.
- Internal helper RPCs are not directly executable by web client roles.
- Timeline read RPC is executable by anon/authenticated and filters visibility internally.
- `post_apply_ready_for_notification_frontend_design=true`.

No real user id, email, token, project ref, full URL, secret, or internal identifier value was recorded.

## QA Checklist

After an approved apply and frontend implementation:

- A comment/application on an owned session creates one notification for the owner.
- A user's own comment/application does not notify themselves.
- Unread count increments.
- Bell opens recent notification list.
- Notification click opens the related session detail page.
- Mark-read updates the count.
- Other users cannot read the notification.
- Public timeline does not expose private notification contents.
- Email and Discord sending remain untouched unless later gates explicitly enable them.
- Header bell UI appears for logged-in users and stays hidden for anonymous users.
- Empty notification state shows a compact "no notifications" message.
- Notification list click opens the relative target path returned by the RPC.
- Real notification generation and mark-read QA remain a later gate.

## Notification Generation QA Status

Attempted next-gate preparation found that real notification generation is not ready yet:

- The notification schema, list/count/read RPCs, and header bell frontend are in place.
- The internal helper `create_session_owner_notification(...)` exists in the SQL draft/apply result.
- Static repository review still shows the helper is planned to be called from existing comment/application RPCs later.
- No applied replacement draft was found that wires `create_application_comment` or application-status flows to the notification helper.
- Therefore, posting a real comment/application would not be expected to create an in-site notification yet.
- Additional comment/application QA was stopped before creating new test activity.

Next required gate:

- Prepare and review a DB/RPC apply draft that instruments the relevant comment/application RPCs.
- Confirm it only creates owner/GM recipient notifications in the intended cases.
- Apply and SELECT-only confirm that instrumentation before re-running real notification generation QA.

## Comment/Application Instrumentation Draft

Prepared next-step drafts:

- `059_notifications_instrument_session_events_apply_draft.sql`
- `060_notifications_instrument_post_apply_select_only.sql`

The 059 draft replaces only `public.create_application_comment(text, text)`.
It preserves the existing frontend RPC contract, return value, PC snapshot behavior, comment validation, application creation/reapply behavior, and authenticated-only grant.

Instrumentation policy:

- When another user comments on a session, call `create_session_owner_notification(...)` with `session_comment`.
- When another user creates or reopens a participation application, call `create_session_owner_notification(...)` with `session_application`.
- Management comments by the owner/GM call the same helper, but the helper skips self-notifications when actor and owner match.
- Admin management comments on another owner's session can notify that owner.
- PL-facing approval/rejection notifications from `set_application_status` remain a future gate.
- `activity_events` writes are not added in this draft; the timeline feed remains separate follow-up work.

Failure policy:

- Notification creation is part of the same RPC transaction.
- If notification insertion fails, the comment/application RPC should fail and roll back.
- This intentionally favors visible QA failure over silently losing owner notifications during the MVP rollout.

Security policy:

- The arbitrary-recipient helper remains internal and is not directly executable by web client roles.
- Web clients still call only the existing comment/application RPC.
- No direct frontend mutation grant is added to `user_notifications`.
- Notification target paths remain relative in-site paths, not full external URLs.

060 confirmation should verify:

- `create_application_comment(text,text)` exists once.
- It remains `security definer` with `search_path=public`.
- authenticated can execute it and anon cannot.
- It calls `create_session_owner_notification(...)`.
- It includes `session_comment` and `session_application` notification paths.
- The helper remains unavailable for direct web-client execution.
- `post_apply_ready_for_notification_generation_qa=true`.

This preparation does not execute SQL, apply DB/RPC/RLS changes, send email, send Discord messages, or deploy Edge Functions.

## Comment/Application Instrumentation Apply Confirmation

The comment/application notification instrumentation was applied and confirmed after a separate SQL Editor gate:

- `059_notifications_instrument_session_events_apply_draft.sql` was run once by the user in Supabase SQL Editor.
- Apply succeeded.
- `060_notifications_instrument_post_apply_select_only.sql` was run once as a SELECT-only confirmation.
- SELECT-only confirmation returned OK.
- `create_application_comment(text,text)` signature is preserved.
- The RPC remains `security definer`.
- The RPC has `search_path=public`.
- authenticated can execute the RPC.
- anon cannot execute the RPC.
- The RPC calls `create_session_owner_notification(...)`.
- Both `session_application` and `session_comment` notification paths are present.
- Notification targets use a relative in-site target path.
- The actor is passed to the helper so self-notifications can be skipped.
- The helper remains unavailable for direct web-client execution.
- Application status notifications remain a future gate.
- `post_apply_ready_for_notification_generation_qa=true`.

No additional SQL Editor execution, DB/RPC/RLS change beyond the approved 059 apply, Edge Function deploy, email sending, Discord sending, Supabase Dashboard change, secret/API key/token recording, or real notification generation QA was performed in this documentation step.

Next gate:

- Run real comment/application notification generation QA.
- Confirm owner/GM unread count, notification list display, notification click navigation, individual read, mark-all-read, and cross-user isolation.
- Do not record real user ids, notification ids, session ids, emails, JWTs, tokens, project refs, or full URLs.

## Notification Generation QA Confirmation

The user manually performed the real notification generation QA after instrumentation apply.

Confirmed:

- A different user posted a comment/application on a session owned by another GM/owner.
- A notification was generated for the GM/owner side.
- The GM/owner header notification bell showed an unread count.
- The notification list showed the relevant notification.
- The notification text was understandable as a comment/application notification for the target session.
- Clicking the notification opened the related session detail page.
- Individual mark-read worked.
- Mark-all-read worked.
- The unread count decreased or disappeared after read actions.
- Logged-out state did not expose a working notification bell.
- The notification dropdown did not significantly break at smartphone width.

Result:

- The notification bell MVP is considered successful through real notification generation, notification listing, detail navigation, and read-state handling.
- The activity timeline page remains unimplemented and is left for a later task.

No SQL Editor execution, DB/RPC/RLS additional change, Edge Function deploy, email sending, Discord sending, Supabase Dashboard change, secret/API key/token recording, or new code change was performed in this documentation step.

No real user id, notification id, session id, email, JWT, token, project ref, or full URL was recorded.

## Activity Timeline Frontend MVP

The GM/PL shared update timeline frontend MVP has been implemented.

Implemented scope:

- Added `timeline.html` as a dedicated update timeline page.
- Added `assets/js/renderTimeline.js`.
- Added `TIMELINE` to the shared header/footer navigation.
- The page reads `get_activity_timeline(...)` and renders the returned activity events newest first.
- The page displays event type, session title or event title, short body text, actor display name when available, update time, visibility label, and a relative in-site link to the related session detail target.
- Empty, loading, and read-error states are handled.
- Unknown event types fall back to a generic update label instead of breaking the page.
- Notification read state is not changed from the timeline page; notification bell and timeline remain separate surfaces.

Safety and privacy:

- This batch did not execute SQL Editor, change DB/RPC/RLS, deploy Edge Functions, send email, or send Discord messages.
- Frontend code reads the existing timeline RPC only.
- No frontend direct `.insert/.update/.delete/.upsert` DB write path was added.
- Timeline target paths are normalized as relative in-site paths before being used.
- No real user id, notification id, session id, full URL, project ref, JWT, token, or email was recorded.

Current instrumentation note:

- The database/RPC foundation for `activity_events` and `get_activity_timeline(...)` is applied.
- Comment/application notification generation is connected to `user_notifications`.
- Activity event writes for comment/application/session create/edit/approval flows are still future scope unless another existing RPC already calls `record_activity_event(...)`.
- Because of that, the timeline page may legitimately show an empty state until activity instrumentation is connected.

Future gates:

- Add activity instrumentation for comment, application, session create/update, approval/rejection, and other public or authenticated events as needed.
- Confirm timeline rendering with real activity data after instrumentation exists.
- Consider pagination or filtering only after the MVP feed is proven useful.

## Activity Timeline Public QA

Public-site QA was performed for the timeline frontend MVP after `a353dcf`.

Confirmed on the deployed site:

- The shared navigation includes `TIMELINE`.
- The collapsed navigation can open and navigate to the timeline page.
- `timeline.html` opens normally.
- The deployed page references the timeline cache-busted shared `main.js`.
- The page heading and timeline shell render normally.
- With no activity rows returned, the empty state displays naturally.
- No main render error was shown.
- The page did not produce body-level horizontal overflow in the checked browser width.
- The existing account link and notification bell shell were not broken by the timeline page.

Current data result:

- `activityCardCount=0` during QA.
- Because there were no returned activity cards, card ordering, detail-link navigation from a real activity row, and unknown-event rendering could not be confirmed with live data.
- Static implementation still includes a fallback label for unknown event types and relative target-path normalization.

Auth-state note:

- A dedicated logged-out browser profile was not available from Codex without changing browser auth state.
- The public page itself rendered without an authenticated-only requirement.
- Logged-in-specific private data was not inspected, and no token, user id, session id, project ref, or full URL was recorded.

Remaining timeline tasks:

- Connect activity instrumentation for comment/application/session create/edit/approval events if real timeline rows are needed.
- Re-run public QA after activity rows exist, including real-card newest-first ordering and detail-link navigation.
- Perform a user-side smartphone-width check if needed, because Codex Browser did not expose viewport resizing for this public QA pass.

## Activity Event Instrumentation Preparation

Prepared non-destructive SQL drafts for comment/application activity timeline generation.

Apply-before-review follow-up:

- The first 061 draft was blocked because GM/admin management comments also wrote `authenticated` activity rows.
- Management comments can occur on non-public or draft sessions, so recording them in the shared activity timeline could expose that an internal session/comment existed.
- The draft was revised so the MVP records only PL-side comments/applications as activity rows.
- GM/admin management comments keep the existing owner notification behavior but do not create shared activity rows.

Created:

- `docs/supabase/sql/061_activity_events_instrument_session_events_apply_draft.sql`
- `docs/supabase/sql/062_activity_events_instrument_post_apply_select_only.sql`

061 scope:

- Replaces only `public.create_application_comment(text,text)`.
- Preserves the existing frontend payload and return value.
- Preserves the existing owner notification helper call added in the notification instrumentation batch.
- Adds `public.record_activity_event(...)` calls for PL-side events only:
  - `session_comment`
  - `session_application`
- Stores comment/application activity with `authenticated` visibility.
- Uses a relative target path in the same `session-detail.html?id=...` form expected by the timeline UI.
- Uses short generic activity bodies instead of storing raw long comment/application text in the shared activity feed.
- Keeps activity generation in the same RPC transaction as the comment/application write, matching the notification MVP failure policy.

062 scope:

- SELECT-only post-apply confirmation SQL.
- Confirms the target RPC still has the expected signature, security definer, `search_path=public`, authenticated execute, anon non-execute, owner notification helper call, activity helper call, event types, relative target path, authenticated visibility, generic body strings, and actor handoff.
- Confirms `record_activity_event(...)` exists, uses `search_path=public`, and is not directly executable by anon/authenticated web clients.
- Leaves session create/update/status/delete activity instrumentation as future scope.

Design notes:

- Activity rows are shared timeline events, not private notifications.
- Self-actions may create activity rows even though private self-notifications are skipped by the owner notification helper.
- Comment/application activity is treated as login-visible because comment and application context can contain player-specific information.
- GM/admin management comments are not included in the MVP timeline feed. They should stay out of shared activity until a stricter visibility model for internal GM operations is reviewed.
- Session creation activity is not included in 061. `create_session_post(...)` is a larger RPC and should be instrumented in a separate focused apply draft after its current live signature/body are reviewed.

Safety:

- SQL Editor execution, SQL apply, DB/RPC/RLS changes, Edge Function deploy, email sending, Discord sending, Supabase Dashboard changes, and secret/API key/token recording were not performed.
- No real user id, activity id, notification id, session id, email, JWT, token, project ref, or full URL was recorded.

Next gate:

- Review `061_activity_events_instrument_session_events_apply_draft.sql` before any SQL Editor execution.
- If approved and applied, run 062 once as a SELECT-only confirmation gate.
- Then perform real comment/application activity generation QA and re-run timeline public QA with real activity rows.

## Activity Event Instrumentation Apply Confirmation

The activity instrumentation apply gate has completed.

Applied by the user in their Supabase SQL Editor:

- `docs/supabase/sql/061_activity_events_instrument_session_events_apply_draft.sql`
- Executed once.
- Apply succeeded.

SELECT-only confirmation:

- `docs/supabase/sql/062_activity_events_instrument_post_apply_select_only.sql`
- Executed after the 061 apply.
- Confirmation completed successfully.

Confirmed results:

- `create_application_comment(text,text)` signature is preserved.
- `security definer` is preserved.
- `search_path=public` is confirmed.
- authenticated can execute the RPC.
- anon cannot execute the RPC.
- Existing owner notification helper call remains present.
- Activity helper call is present for PL-side events.
- `session_application` activity type is present.
- `session_comment` activity type is present.
- Target path remains relative.
- Activity visibility is `authenticated`.
- Activity body uses generic text and does not store the raw comment body.
- GM/admin management comments do not create shared activity rows.
- `record_activity_event(...)` helper exists.
- Activity helper is not directly executable by web client roles.
- `post_apply_ready_for_activity_generation_qa=true`.

Safety:

- Codex did not run SQL Editor.
- No additional SQL Editor execution, DB/RPC/RLS change, Edge Function deploy, email sending, Discord sending, Supabase Dashboard change, or secret/API key/token recording was performed in this recording step.
- No real user id, session id, activity id, notification id, email, JWT, token, project ref, or full URL was recorded.

Next gate:

- Perform real comment/application posting QA and confirm `timeline.html` shows activity rows.
- Confirm activity cards render newest-first and link to the related session detail page.

## Timeline Display / Notification Read History Triage

User-side QA after 061 found that a PL-side comment/application could be posted, but the TIMELINE page still did not show an activity card. The same QA flow also found that notification content disappeared from the bell panel after read-state changes, while the desired behavior is to clear only the unread badge and keep recent notifications as history.

Findings:

- `create_application_comment(text,text)` still contains the PL-side `record_activity_event(...)` call according to the applied 061/062 documentation.
- PL comment/application activity uses `authenticated` visibility, so logged-out TIMELINE views should not be expected to show those rows.
- `get_activity_timeline(...)` is designed to return `authenticated` rows only when the request has a logged-in auth context.
- The TIMELINE frontend was updated to wait for Supabase auth bootstrap before calling `get_activity_timeline(...)`, reducing the chance that a logged-in browser renders as anonymous during initial page load.
- `get_my_notifications(integer, boolean)` is designed to return read and unread notifications when `p_unread_only=false`.
- The notification bell frontend now keeps a local notification history cache during read-state changes, renders read items with a distinct class, and continues requesting `p_unread_only=false`.

Created:

- `docs/supabase/sql/063_notification_timeline_display_diagnostics_select_only.sql`

063 scope:

- SELECT-only diagnostics.
- Returns counts and boolean/status checks only.
- Checks whether `activity_events` rows exist after real PL comment/application actions.
- Checks whether relevant rows use `authenticated` visibility, safe relative target paths, generic bodies, and comment/application event types.
- Checks whether `get_activity_timeline(...)` still has the authenticated visibility branch and frontend-compatible return shape.
- Checks whether `get_my_notifications(...)` supports read notification history.
- Does not return activity ids, notification ids, session ids, titles, bodies, user ids, emails, tokens, project refs, or full URLs.

Interpretation for the next gate:

- If `activity_events_authenticated_pl_count=0`, the activity row was not created and the next fix should focus on RPC instrumentation.
- If activity rows exist and `get_activity_timeline_authenticated_visibility_branch=true`, the next verification should focus on logged-in TIMELINE rendering and session context.
- If notification history support is OK, read-history behavior should remain a frontend/UI concern rather than an RPC change.

Safety:

- SQL Editor execution, SQL apply, DB/RPC/RLS changes, Edge Function deploy, email sending, Discord sending, Supabase Dashboard changes, and secret/API key/token recording were not performed.
- No real user id, activity id, notification id, session id, email, JWT, token, project ref, or full URL was recorded.

Next gate:

- Run 063 once as a SELECT-only SQL Editor confirmation gate.
- Re-run logged-in TIMELINE QA after the frontend cache-bust is public.
- Confirm notification bell read-state behavior with an existing notification history.

## 063 Diagnosis and Activity Generation Fix Draft

The 063 SELECT-only diagnostics were run once by the user after the timeline/read-history triage.

063 results:

- `activity_events_total_count=0`.
- `activity_events_authenticated_pl_count=0`.
- `activity_events_visibility_counts=public=0,authenticated=0,private=0`.
- `activity_events_type_counts=comment=0,application=0`.
- `diagnosis_next_step=activity_missing`.
- `get_activity_timeline(...)` exists and keeps the expected security/search_path/return-shape patterns.
- `create_application_comment(...)` still had the static activity-generation pattern expected from the prior draft.
- The GM/admin management-comment activity skip pattern remained OK.
- Notification history support was confirmed separately: read-state counts were present as `total=2,unread=0,read=2`, so the notification list can retain read history.

Conclusion:

- TIMELINE non-display is primarily an activity-generation issue, not a TIMELINE frontend rendering issue.
- The previous helper-call pattern was statically present, but real PL comment/application QA still produced no `activity_events` rows.
- The next fix should make PL-side activity generation explicit inside `create_application_comment(text,text)` and verify that an activity row is produced before returning success.

Prepared next drafts:

- `docs/supabase/sql/064_activity_events_generation_fix_apply_draft.sql`
- `docs/supabase/sql/065_activity_events_generation_fix_post_apply_select_only.sql`

064 scope:

- Replaces only `public.create_application_comment(text,text)`.
- Keeps existing comment/application behavior, PC snapshot behavior, owner notification helper call, validation, authenticated-only frontend contract, and return shape.
- Keeps GM/admin management comments out of shared activity.
- Writes PL-side comment/application activity through the concrete `activity_events` path inside the same transaction.
- Keeps activity visibility as `authenticated`.
- Keeps target paths relative.
- Keeps activity bodies generic and does not store raw comment text.
- Treats activity generation failure as a visible RPC failure so timeline instrumentation cannot silently drop rows during QA.

065 scope:

- SELECT-only.
- Confirms the RPC signature/security/search_path/execute privileges.
- Confirms owner notifications remain connected.
- Confirms the concrete activity path, completion guard, event types, relative target path, authenticated visibility, generic body text, and management-comment skip.
- Confirms real activity counts after a later apply and QA without returning row contents or identifiers.

Safety:

- SQL Editor execution, SQL apply, DB/RPC/RLS changes, Edge Function deploy, email sending, Discord sending, Supabase Dashboard changes, and secret/API key/token recording were not performed in this preparation step.
- No real user id, session id, activity id, notification id, email, JWT, token, full URL, project ref, or internal id value was recorded.

Next gate:

- Review `064_activity_events_generation_fix_apply_draft.sql` before any SQL Editor execution.
- If approved, run 064 once in a separate SQL apply gate, then run 065 once as a SELECT-only confirmation gate.
- After confirmation, re-run real PL comment/application TIMELINE display QA.

## Activity Generation Fix Apply Confirmation

The 064 activity generation fix apply gate has completed.

Applied by the user in their Supabase SQL Editor:

- `docs/supabase/sql/064_activity_events_generation_fix_apply_draft.sql`
- Executed once.
- Apply succeeded.

SELECT-only confirmation:

- `docs/supabase/sql/065_activity_events_generation_fix_post_apply_select_only.sql`
- Executed after the 064 apply.
- Confirmation completed successfully.

Confirmed results:

- `create_application_comment(text,text)` signature is preserved.
- `security definer` is OK.
- `search_path=public` is OK.
- authenticated can execute the RPC.
- anon cannot execute the RPC.
- Existing owner notification helper call remains present.
- PL comment/application branches include activity generation.
- Activity completion guard and failure guard are present.
- Activity types cover application and comment events.
- Target path remains relative.
- Activity visibility is `authenticated`.
- Activity body uses generic text and does not store the raw comment body.
- GM/admin management comments do not create shared activity rows.
- The old dependency on the internal activity helper is removed for this RPC path.
- Real activity count checks are still `review` before the next real QA because no new PL comment/application activity was generated in this confirmation step.
- `post_apply_ready_for_activity_generation_qa=true`.

Safety:

- Codex did not run SQL Editor.
- No additional SQL Editor execution, DB/RPC/RLS change, Edge Function deploy, email sending, Discord sending, Supabase Dashboard change, or secret/API key/token recording was performed in this recording step.
- No real user id, session id, activity id, notification id, email, JWT, token, project ref, or full URL was recorded.

Next gate:

- Perform real PL comment/application posting QA.
- Confirm `timeline.html` shows the new activity card.
- Confirm newest-first ordering and detail-link navigation with real activity rows.

## Activity Timeline Generation QA

The post-064 TIMELINE generation QA was performed by the user.

Context:

- The 064 apply and 065 SELECT-only confirmation were completed before this QA.
- `post_apply_ready_for_activity_generation_qa=true`.
- The first check used an admin/management-side user comment.
- That did not show a TIMELINE card.
- This is expected behavior because GM/admin management comments intentionally do not create shared `activity_events` rows.

Confirmed:

- A later QA used a test player who was not the GM/owner.
- That player posted a PL comment.
- The TIMELINE page displayed a card for the PL-side activity.
- PL comment/application-side activity generation and TIMELINE display are therefore considered successful for the MVP path.

Still pending or not recorded in this QA note:

- Long comment body exposure check on the rendered TIMELINE card.
- Detail-link navigation from the TIMELINE card.
- Newest-first ordering with multiple real activity rows.
- Smartphone-width TIMELINE display with real activity cards.

Future scope:

- `create_session_post(...)` and other session create/edit/status activity instrumentation remain separate future gates.
- GM/admin management comment activity remains intentionally excluded until a stricter shared-timeline visibility design is reviewed.

Safety:

- Codex did not run SQL Editor.
- No additional DB/RPC/RLS change, Edge Function deploy, email sending, Discord sending, Supabase Dashboard change, or secret/API key/token recording was performed in this recording step.
- No real URL, user id, session id, activity id, notification id, email, JWT, token, or project ref was recorded.

## Non-Goals for This Batch

- SQL Editor execution.
- DB/RPC/RLS mutation.
- Edge Function deploy.
- Email sending.
- Discord sending.
- Activity timeline page implementation.
- Any recording of real email, user id, token, project ref, secret, or full external URL.
