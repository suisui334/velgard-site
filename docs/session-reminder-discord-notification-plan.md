# Session Reminder Discord Notification Plan

Status: Phase R-01 planning only.

This document records the existing structure survey and a minimum implementation plan for optional Discord reminders before a session starts. No implementation, SQL apply, DB change, Edge Function deploy, Discord dry run, Discord production send, or secret change was performed in this phase.

## Goals

Add optional per-session Discord reminders that can be configured when creating or editing a session request.

### Shortage reminder

Purpose: notify the public Discord channel with `@everyone` when a session is close to its start time and the participant count is still below the minimum.

Candidate settings:

- enabled: true or false
- hours before start: 1, 2, or 3

Candidate condition:

- The configured time before the session start has arrived.
- applicant count plus approved count is below `player_min`.
- The same reminder has not already been sent.
- The session is not canceled, deleted, closed, finished, hidden, draft, or otherwise unsuitable for recruitment.

Candidate message copy:

```text
@everyone
■依頼書【依頼書タイトル】［依頼書URL(OGP画像なし)］
本日X時より開催予定です。最低人数に後X人足りていません。ご都合よろしければ参加いかがでしょうか。
```

Notes:

- `X` is calculated from the session start time.
- `後X人` is calculated from `player_min - count`.
- The session URL should be shown without an OGP image preview.
- Any production `@everyone` send must be a separate gate.

### GM reminder

Purpose: remind the GM shortly before a session when the participant count has reached the minimum.

Candidate settings:

- enabled: true or false
- minutes before start: 30 or 60

Candidate condition:

- The configured time before the session start has arrived.
- applicant count plus approved count is at least `player_min`.
- The same reminder has not already been sent.
- The session is not canceled, deleted, closed, finished, hidden, or draft.

Destination options are still open because the current public session structure does not expose a stable GM Discord mention target to the browser.

## Existing Structure Survey

### Session data

Relevant client files:

- `assets/js/renderSessionPost.js`
- `assets/js/sessionData.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/discordSyncClient.js`

Relevant SQL draft docs:

- `docs/supabase/sql/015_session_posting_rpc_draft.sql`
- `docs/supabase/sql/017_update_session_post_rpc_draft.sql`
- `docs/supabase/sql/018_delete_session_post_rpc_draft.sql`
- `docs/supabase/sql/008_comment_management_rpc_draft.sql`
- `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql`
- `docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql`

Current session fields used by the public UI include:

- `id`
- `title`
- `date`
- `start_time`
- `end_time`
- `end_at`
- `application_deadline`
- `session_type`
- `session_tool`
- `player_min`
- `player_max`
- `summary`
- `visibility`
- `status`
- `gm_user_id`
- `gm_name`
- Discord sync metadata

`renderSessionPost.js` builds session payloads for:

- `create_session_post`
- `update_session_post`

The form already has the natural anchor points for reminder settings:

- session start datetime
- session player min and max
- visibility and status
- existing Discord notification field for creation

Existing future sessions should be configurable through the edit flow because the managed edit form reuses the same session form and calls `update_session_post`.

### Start time and URL

The create/update form stores the start datetime as `p_start_at`, then derives:

- `p_session_date`
- `p_start_time`
- `p_end_time`
- `p_end_at`
- `p_application_deadline`

The existing Discord sync Edge Function already builds an absolute public session-detail URL from the public site base and the session id. The reminder feature should reuse the same URL-building approach, but it must not record raw IDs or private URLs in docs.

### Session status and visibility

Observed status values include:

- `draft`
- `tentative`
- `recruiting`
- `full`
- `closed`
- `finished`
- `canceled`

The create form starts from `draft`, `tentative`, or `recruiting`. The update flow and Discord sync docs include the broader set.

For reminder eligibility, the conservative first version should allow only public active recruitment-like sessions. A reasonable first candidate is:

- include: `tentative`, `recruiting`
- exclude: `draft`, `closed`, `finished`, `canceled`, hidden or non-public sessions

Whether `full` should be eligible for GM reminder is an open question. It is safer to exclude it in Gate 1 until the product meaning of `full` is fixed for reminders.

### Application counts

Relevant code:

- `assets/js/sessionDetailApplicationComments.js`

Existing application statuses include:

- `pending`
- `accepted`
- `waitlisted`
- `rejected`
- `canceled`

Existing count handling distinguishes:

- `accepted_count`
- `pending_count`
- `waitlisted_count`

The current count RPC is:

- `get_public_session_application_counts(target_session_id)`

The SQL draft counts distinct users by status. Rejected and canceled applications are not counted for active participation.

The product phrase "申請人数 + 承認人数" needs a definition before implementation. The safest default is:

- approved count: `accepted`
- applicant count: `pending`
- waitlisted: open question, excluded unless the product owner explicitly includes it

### Existing Discord session sync

Relevant files:

- `assets/js/discordSyncClient.js`
- `supabase/functions/sync-session-post-to-discord/index.ts`

Current behavior:

- Session create can trigger immediate Discord create sync for public non-draft sessions.
- Session update can trigger Discord update sync when a Discord message reference already exists.
- Session delete or cancel can trigger delete-like sync depending on state.
- `discord_mention_mode` supports `none` or `everyone` for initial create.
- The edit flow intentionally resets or hides the immediate mention mode.

Important existing implementation details:

- The Edge Function defaults to dry-run unless production send is explicitly requested by the caller path.
- Production send uses a webhook and records Discord metadata through RPC.
- The webhook payload uses suppress-embed behavior for session URLs.
- `allowed_mentions` is explicitly restricted and only includes `everyone` when intended.
- Dry-run previews redact sensitive URL details.

For reminders, do not reuse the immediate `discord_mention_mode` field. Reminder settings are a new per-session scheduling feature, not an immediate post-sync option.

### Existing scheduled Edge Function pattern

Relevant files:

- `supabase/functions/dispatch-admin-cap-announcements/index.ts`
- `docs/discord-cap-announcement-plan.md`
- `docs/supabase/sql/050_admin_discord_announcements_schema_apply_draft.sql`
- `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql`
- `docs/supabase/sql/057_admin_cap_announcements_cron_apply_draft.sql`

Useful existing pattern:

- scheduled rows
- claim RPC
- lock token
- processing status
- finalize RPC
- attempt count and retry timing
- dry-run first
- production send guarded by a dedicated enable flag and dispatch token
- separate cron gate

The session reminder feature should follow this scheduled-dispatch pattern instead of being attached to the browser-driven session-post Discord sync.

### GM Discord contact

Relevant docs:

- `docs/supabase-discord-id-contact-plan.md`
- `docs/supabase-discord-id-gm-contact-ui-result.md`
- `docs/supabase/sql/014_discord_id_profile_contact_draft.sql`
- `docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql`

Current known shape:

- Sessions store GM identity through `gm_user_id` and `gm_name`.
- Profile contact work introduced a Discord contact field on profile data.
- Public profile exposure intentionally avoids private contact fields.
- Existing GM contact RPCs are aimed at showing accepted player contact info to the GM or admin.

There is no confirmed existing browser-safe field for directly mentioning the GM in Discord. For the first design, GM reminder destination must be chosen explicitly.

Candidate GM reminder destinations:

- dedicated reminder channel with GM display name only
- existing session sync channel with GM display name only
- optional session-level GM mention field, with strict validation and no public exposure
- server-side lookup from profile contact for the session GM, with no browser exposure

The lowest-risk first implementation is a channel message with GM display name only. Direct GM mention can be a later gate after contact ownership, privacy, and mention format are approved.

## Recommended Minimum Implementation

### DB settings

Add nullable or defaulted reminder settings to the session record. Candidate column names should be aligned with existing DB naming during Gate 1.

Candidate settings:

- `shortage_reminder_enabled`
- `shortage_reminder_hours_before`
- `gm_reminder_enabled`
- `gm_reminder_minutes_before`

Recommended constraints:

- `shortage_reminder_hours_before` is one of 1, 2, 3 when enabled.
- `gm_reminder_minutes_before` is one of 30, 60 when enabled.
- disabled settings may keep the offset null.
- existing rows default to disabled.

This avoids changing existing future sessions until a GM edits and enables reminders.

### Reminder logs

Use a separate reminder log table instead of storing only `sent_at` columns on `sessions`.

Rationale:

- reminder type can grow
- retry and failed status need history
- production send should be idempotent
- dry-run must not write
- a unique key can prevent duplicate sends

Candidate log concepts:

- `session_id`
- `reminder_type`
- `scheduled_start_at`
- `offset_minutes`
- `due_at`
- `status`
- `attempt_count`
- `next_attempt_at`
- `locked_at`
- `lock_token`
- `posted_at`
- `delivery_error_code`
- provider message reference, stored but never written to docs

Candidate reminder types:

- `shortage_everyone`
- `gm_start_confirm`

Recommended first uniqueness:

- one successful send per `session_id` and `reminder_type`

If start time or offset changes after a send, resending should require a later explicit reset flow. That avoids accidental repeated `@everyone`.

### RPC plan

Gate 1 should draft server-side RPCs instead of adding client-side direct writes.

Candidate RPC responsibilities:

- save reminder settings through existing create/update session RPCs or a dedicated session settings RPC
- claim due reminders for an Edge Function
- finalize a reminder after send or failure
- optionally return dry-run candidates without changing state

The claim RPC should calculate eligibility server-side:

- active public session
- configured reminder due
- not already sent
- player minimum present and greater than zero
- application counts joined or calculated from `session_applications`
- shortage or GM threshold condition satisfied

The finalize RPC should record:

- posted
- failed
- skipped
- retry timing

Browser clients should not receive private Discord contact fields or provider message references.

### UI plan

Add a new session-post fieldset for "開始前リマインド" in a later UI gate.

Candidate controls:

- shortage reminder enabled checkbox
- shortage timing select: 1 hour, 2 hours, 3 hours before start
- GM reminder enabled checkbox
- GM timing select: 30 minutes or 60 minutes before start
- short warning that `@everyone` production send is separately gated

Connection points:

- create form payload
- edit form fill
- update form payload
- managed session select fields

Do not reuse the existing immediate Discord notification field. It has different timing, permission, and production-send semantics.

Cache-bust targets for the UI gate:

- `session-post.html`
- `assets/js/main.js`
- `assets/js/renderSessionPost.js`
- any touched helper module

### Edge Function and schedule plan

Create a separate scheduled dispatcher in a later gate, for example `dispatch-session-reminders`.

Recommended behavior:

- dry-run defaults to true
- dry-run returns candidate counts and sanitized message facts only
- dry-run performs no DB write
- dry-run performs no Discord request
- production send requires a dedicated real-send enable flag
- production send requires a dispatch token or equivalent secret gate
- production send uses claim/finalize RPCs
- production send uses suppress-embed Discord payload flags for session URLs
- production `@everyone` is allowed only for the shortage reminder type

The dispatcher should not be invoked from the browser form submission path. It should be scheduled or manually invoked by an admin gate.

### Discord message plan

Shortage reminder:

- channel: existing or new session reminder channel, to be decided
- mention: `@everyone`
- allowed mentions: only `everyone`
- embed suppression: enabled
- URL: public session detail URL
- count: `player_min - applicant_count - approved_count`

GM reminder:

- first recommended channel: dedicated reminder channel or existing sync channel
- first recommended destination: GM display name only, no personal Discord mention
- later option: server-side GM mention if profile contact ownership is approved
- embed suppression: enabled if a URL is included

The production message preview should not be pasted into docs with real IDs, URLs, or provider references.

### OGP image suppression

The existing Discord sync Edge Function already uses suppress-embed behavior for session URLs. The reminder dispatcher should use the same payload approach. The result should be recorded as boolean/status values in QA, not as a raw Discord payload with real URLs.

## Existing Sessions

Existing future sessions should not be bulk-enabled. Initial support can be:

- default disabled for all existing sessions
- GM or manager edits a future session
- settings are saved through the normal update gate
- scheduled dispatcher picks it up later

No destructive migration is required for existing data.

## Gate 1 SQL Draft Result

Gate 1 produced the DB/RPC design draft only:

- `docs/sql-drafts/session-reminder-notifications-draft.sql`

No SQL was executed or applied. No DB, RPC, RLS, Edge Function, Discord, UI, HTML, CSS, JS, data, or `updates.json` change was made.

The draft proposes these session setting columns on `public.sessions`:

- `shortage_reminder_enabled`
- `shortage_reminder_hours_before`
- `gm_reminder_enabled`
- `gm_reminder_minutes_before`

The draft proposes `public.session_reminder_logs` for duplicate prevention and production send result recording. The first version uses `unique(session_id, reminder_type)` so a sent or claimed reminder is not automatically resent after start time or timing edits. If resend becomes necessary, a later explicit reset or log invalidation gate is required.

The draft proposes these RPC boundaries:

- `preview_due_session_reminders(p_now, p_limit)` for write-free dry-run preview.
- `claim_due_session_reminders(p_now, p_limit)` for production claim and duplicate prevention.
- `finalize_session_reminder(p_log_id, p_status, p_discord_message_id, p_error_message)` for production result recording.

The first SQL draft keeps dry-run write-free. Production send is the only path that writes reminder logs.

Count policy in the draft:

- `pending_count`: distinct `session_applications.user_id` rows with status `pending`.
- `accepted_count`: distinct rows with status `accepted`.
- `waitlisted_count`: returned for visibility, but not counted in the first threshold decision.
- `total_for_minimum`: `pending_count + accepted_count`.

Reason for initially excluding `waitlisted`: the current UI and count RPC distinguish waitlisted from pending/accepted, and the product phrase can be satisfied conservatively with pending plus accepted. Including waitlisted later is a one-line eligibility change, but including it too early could overstate readiness.

Session eligibility in the draft:

- shortage reminder: `visibility = public`, future start, `player_min > 0`, status `tentative` or `recruiting`, before application deadline when a deadline exists, and `pending + accepted < player_min`.
- GM confirmed reminder: `visibility = public`, future start, `player_min > 0`, status `tentative`, `recruiting`, or `full`, and `pending + accepted >= player_min`.
- excluded by default: `draft`, `closed`, `finished`, `canceled`, hidden/private sessions, sessions without start time, sessions without positive minimum players, already-started sessions, and sessions already present in `session_reminder_logs`.

GM reminder destination in the draft remains the initial low-risk option: an existing Discord notification channel with GM display name, not direct GM mention or DM. GM individual mention remains a later privacy and routing gate.

Next Gate 2 must review before any apply:

- Whether settings belong on `public.sessions` or a separate settings table.
- Whether to use a dedicated `update_session_reminder_settings` RPC first, rather than changing `create_session_post` / `update_session_post` signatures immediately.
- Whether `service_role`-only RPC grants match the planned Edge Function invocation route.
- Whether `full` status should stay included for GM confirmed reminders.
- Whether application-deadline skipping for shortage reminders is correct.
- Whether a failed production send should be terminal in the first version or retryable.
- Whether the `rollback;` ending should remain for review safety or be removed in a final apply draft.

## Gate 1.5 SQL Apply Candidate Result

Gate 1.5 reviewed the Gate 1 draft and prepared an apply candidate plus Gate 2 checklist only. No SQL was executed or applied.

Apply candidate:

- `docs/sql-drafts/session-reminder-notifications-apply-candidate.sql`

Gate 2 checklist:

- `docs/session-reminder-sql-apply-checklist.md`

Main adjustments from the Gate 1 draft:

- Added an explicit `APPLY CANDIDATE ONLY` header and `commit;`-based apply shape instead of the draft-only `rollback;` ending.
- Kept the file under `docs/sql-drafts/`; no `supabase/migrations/` file was created.
- Added a dedicated `update_session_reminder_settings` RPC so the first apply does not change `create_session_post` / `update_session_post` signatures or create PostgREST overload ambiguity.
- Added service-role checks inside preview/claim/finalize RPCs, matching the existing scheduled-dispatch boundary pattern.
- Added `lock_token` to `session_reminder_logs` and to claim/finalize, so finalize requires both `log_id` and `lock_token`.
- Renamed the returned threshold field to `count_for_minimum` to make the `pending + accepted` rule explicit.
- Kept `waitlisted_count` in preview/claim returns but outside `count_for_minimum`.
- Kept shortage reminders limited to `tentative` / `recruiting`, and GM confirmed reminders eligible for `tentative` / `recruiting` / `full`.
- Added SELECT-only post-apply checks for columns, constraints, table existence, RLS, direct table privileges, RPC existence, RPC privileges, session count, default enabled counts, and reminder log count.

Gate 2 should run only after explicit approval. If any SQL Editor error occurs, stop and do not rerun blindly. Gate 2 must still avoid Edge deploy, Discord dry-run, Discord production send, secret changes, UI changes, and raw identifier disclosure.

## Gate 2 Apply Result And Gate 3 UI Blocker

Gate 2 SQL apply was completed by the user and recorded in:

- `docs/session-reminder-sql-apply-result.md`

Reported status summary:

- session reminder columns: `4 / expected 4`
- session reminder constraints: `2 / expected 2`
- `session_reminder_logs`: exists
- log constraints: `6 / expected 6`
- log RLS: `enabled`
- direct anon/authenticated log table privileges: `false` for reported checks
- reminder RPCs: `4`
- default enabled rows: `0`
- reminder log count: `0`
- preview RPC: `not_run`

Gate 3 UI implementation was then reviewed but stopped before code changes.

Blocker record:

- `docs/session-reminder-ui-result.md`

Reason:

- `assets/js/renderSessionPost.js` uses `MANAGE_SESSION_SELECT` for the edit/manage fetch path.
- The current `MANAGE_SESSION_SELECT` does not include:
  - `shortage_reminder_enabled`
  - `shortage_reminder_hours_before`
  - `gm_reminder_enabled`
  - `gm_reminder_minutes_before`
- The instruction for Gate 3 required stopping if the existing session retrieval result did not already include these fields.
- UI implementation would risk losing existing reminder settings on edit if it rendered disabled defaults without restoring current values.

No UI, JS, HTML, CSS, SQL, RPC, RLS, Edge Function, Discord, or secret change was performed in Gate 3.

Recommended next gate:

- Update the session-post managed edit retrieval contract to include the four reminder setting columns, or define a dedicated session retrieval RPC that returns them.
- Then retry the UI implementation and add the `update_session_reminder_settings` call after existing session save success.

## Gate 3.1 UI Implementation Result

Gate 3.1 resolved the Gate 3 blocker and implemented the frontend reminder settings UI.

Result docs:

- `docs/session-reminder-ui-implementation-result.md`

Implemented:

- Added the four reminder setting columns to `assets/js/renderSessionPost.js` `MANAGE_SESSION_SELECT`.
- Added the `開始前Discordリマインド` optional setting section to the `session-post` create/edit form.
- Added checkbox/select controls for:
  - shortage reminder: `shortage_reminder_enabled`, `shortage_reminder_hours_before`
  - GM reminder: `gm_reminder_enabled`, `gm_reminder_minutes_before`
- Added a post-save `update_session_reminder_settings` RPC call after the existing `create_session_post` / `update_session_post` save succeeds.
- Preserved existing `create_session_post` and `update_session_post` signatures.
- Updated frontend cache-bust to `20260618-session-reminder-settings-ui`.

Not performed:

- SQL apply
- DB/RPC/RLS change
- authenticated create/edit DB write QA
- Edge Function deploy
- Discord dry-run or production send
- secret/Webhook change

Recommended next gate:

- Gate 4: Edge Function / scheduled dispatcher dry-run.

## Gate 4 Edge Dispatcher Dry-run Result

Gate 4 added a dry-run-only Edge Function draft:

- `supabase/functions/dispatch-session-reminders/index.ts`

Result docs:

- `docs/session-reminder-edge-dry-run-result.md`

Implemented:

- HTTP POST dry-run input handling for `dry_run`, optional `now`, and `limit`.
- Safe default where omitted `dry_run` is treated as dry-run.
- `dry_run: false` returns `production_not_enabled`.
- Service-role Supabase client creation through env names only.
- `preview_due_session_reminders` RPC call.
- Reminder candidate normalization.
- Message preview construction for shortage and GM-confirmed reminders.
- Response safety metadata showing no DB write, no Discord send, and production disabled.

Not implemented:

- Edge deploy
- cron setup
- Discord request
- claim RPC
- finalize RPC
- `session_reminder_logs` write
- production send enablement
- Webhook/secret change

The dry-run response may contain message preview and session URL values at runtime. Docs and reports should not paste real message previews, real session URLs, raw identifiers, Discord identifiers, Webhook URLs, or provider message IDs.

Recommended next gate:

- Gate 4.5: approved safe runtime dry-run invocation, or Gate 5 planning for the production send gate.

## Gate 4.5 Edge Runtime Dry-run Result

Gate 4.5 deployed and invoked the dry-run dispatcher after explicit approval for this independent deploy gate.

Result docs:

- `docs/session-reminder-edge-runtime-dry-run-result.md`

Deploy scope:

- deployed only `dispatch-session-reminders`
- did not deploy any other Edge Function
- did not configure cron
- did not change secrets or Webhooks

Runtime dry-run:

- request body shape: `{ "dry_run": true, "limit": 20 }`
- HTTP status: `200`
- response `ok`: `true`
- response `dry_run`: `true`
- response `count`: `0`
- response `items`: present
- safety `preview_rpc_only`: `true`
- safety `db_write`: `false`
- safety `discord_send`: `false`
- safety `production_enabled`: `false`

DB write check:

- `session_reminder_logs` count after dry-run: `0`
- Gate 2 had reported the same count after apply, so dry-run did not increase logs.

Still not performed:

- Discord dry-run send
- Discord production send
- claim RPC
- finalize RPC
- `session_reminder_logs` write
- cron / scheduled invocation
- channel/Webhook/secret selection

The zero runtime count means there was no due session reminder candidate at the invocation time. Real session ids, session URLs, message preview contents, project ref, runtime URL, Webhook URL, token, Discord identifier, and provider message id were not recorded.

Recommended next gate:

- Gate 5: production send gate planning and implementation design.

Gate 5 must separately decide the Discord destination, `@everyone` production approval, GM reminder destination, suppress-embed payload, claim/finalize flow, retry behavior, and sanitized reporting format.

## Gate 5 Discord Production Gate Planning

Gate 5 documented the Discord production-send design only.

Result docs:

- `docs/session-reminder-discord-production-gate-plan.md`

Surveyed existing patterns:

- session-post Discord sync uses env `DISCORD_SESSION_POST_WEBHOOK_URL`, Webhook `wait=true`, payload `flags: 4`, and explicit `allowed_mentions.parse`.
- admin cap announcement dispatch uses a real-send env flag, dispatch token gate, target-channel env mapping, claim/finalize flow, and sanitized result reporting.
- current `dispatch-session-reminders` remains preview-only and production-disabled.

Production direction:

- shortage reminder initially targets the existing Discord notification channel, but a dedicated env name such as `DISCORD_SESSION_REMINDER_WEBHOOK_URL` is the safer implementation boundary even if it points to the same channel.
- shortage `@everyone` requires explicit production approval and `allowed_mentions.parse=["everyone"]`.
- GM confirmed reminder starts as a channel message with GM display name only, no direct GM mention or DM.
- OGP/image preview suppression should reuse Discord payload `flags: 4`; square brackets around a URL are not enough as the primary suppression mechanism.
- production send should use `claim_due_session_reminders` and `finalize_session_reminder` with `lock_token`.
- first version should not auto-retry `@everyone`; reset/resend remains a future gate.

Next gate split:

- Gate 6: production send code implementation, no deploy.
- Gate 7: deploy and production-disabled runtime check.
- Gate 8: secret/destination setup planning or approved setting.
- Gate 9: limited production send test.
- Gate 10: final shortage `@everyone` production operation.

Gate 5 did not perform Discord send, Discord dry-run send, Webhook/secret change, Edge deploy, production implementation, claim/finalize call, DB write, SQL apply, UI change, or `updates.json` change.

## Gate 6 Production Code Result

Gate 6 implemented the production-gated source path only.

Result docs:

- `docs/session-reminder-production-code-result.md`

Implemented in `supabase/functions/dispatch-session-reminders/index.ts`:

- real-send env gate: `SESSION_REMINDER_REAL_SEND_ENABLED`
- dispatch token gate: `SESSION_REMINDER_DISPATCH_TOKEN` via `x-dispatch-token`
- reminder Webhook env: `DISCORD_SESSION_REMINDER_WEBHOOK_URL`
- production `claim_due_session_reminders` helper
- production Discord Webhook send helper
- production `finalize_session_reminder` helper
- `flags: 4` suppress embeds payload
- shortage-only `allowed_mentions.parse=["everyone"]`
- GM reminder channel message with GM display name only

Preserved:

- `dry_run:true` path still uses `preview_due_session_reminders` only.
- dry-run path still does not call claim/finalize.
- dry-run path still does not send Discord.
- dry-run path still does not write DB.

Not performed:

- Edge deploy
- runtime invocation
- Discord send
- Webhook/secret change
- claim/finalize runtime execution
- `session_reminder_logs` write
- SQL/DB/RPC/RLS change
- UI/HTML/CSS/browser JS change
- `updates.json` change

Recommended next gate:

- Gate 7: deploy the updated Function and confirm production remains disabled.

## Gate 6.1 GM Mention Review

Gate 6.1 reviewed the updated requirement that `gm_confirmed` should mention the GM's Discord user directly.

Updated policy:

- shortage reminder remains the only reminder type that can use `@everyone`
- shortage payload keeps `allowed_mentions.parse=["everyone"]`
- GM confirmed reminder should use a single GM Discord user mention
- GM confirmed payload should use `allowed_mentions.parse=[]` and `allowed_mentions.users=[gm_discord_user_id]`
- if a GM Discord id is missing or invalid, GM confirmed falls back to no mention and GM display-name text
- dry-run preview and docs must mask the mention as `<@GM>` or equivalent

Investigation result:

- `preview_due_session_reminders` currently returns `gm_display_name` but no GM Discord user id
- `claim_due_session_reminders` currently returns `gm_display_name` but no GM Discord user id
- `dispatch-session-reminders` row types have no GM Discord id field
- existing `profiles.discord_handle` / `get_my_profile_contact()` / `update_my_discord_id(text)` / `get_gm_session_accepted_contacts(text)` flows are useful precedents, but do not provide a safe dispatcher delivery field for the session GM

Blocker:

- implementing GM mention now would require a SQL/RPC contract change
- no Edge Function code change was made in Gate 6.1
- no SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge deploy, runtime invocation, Discord send, claim/finalize execution, DB write, Webhook/secret change, or `updates.json` change was performed

Next Gate recorded from Gate 6.1:

- Gate 6.2: draft SQL/RPC update to add a safe GM Discord id field to `preview_due_session_reminders` and `claim_due_session_reminders`

## Gate 6.2 GM Discord ID SQL/RPC Draft

Gate 6.2 created the SQL/RPC draft for the GM mention source.

Created:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`
- `docs/session-reminder-gm-discord-id-sql-checklist.md`
- `docs/session-reminder-gm-discord-id-result.md`

Source decision:

- `public.sessions.gm_user_id` identifies the session GM
- `public.profiles.discord_handle` is the existing Discord user ID registration field
- the draft joins `public.sessions.gm_user_id` to `public.profiles.id`
- the draft returns `gm_discord_user_id` only when `profiles.discord_handle` matches `^[0-9]{17,20}$`
- missing, empty, or invalid values return `null`

RPC changes drafted:

- add `gm_discord_user_id text` to `preview_due_session_reminders`
- add `gm_discord_user_id text` to `claim_due_session_reminders`
- keep both RPCs `security definer`
- keep both RPCs `service_role`-only
- do not expose Discord IDs through browser/public RPCs

Not performed in Gate 6.2:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge deploy
- runtime invocation
- Discord send
- DB write
- Webhook/secret change

Next Gates recorded from Gate 6.2:

- Gate 6.3: GM Discord ID RPC apply candidate review
- Gate 6.4: SQL apply independent approval
- Gate 6.5: Edge Function GM mention implementation, no deploy

## Gate 6.3 GM Discord ID RPC Apply Candidate Review

Gate 6.3 reviewed the Gate 6.2 SQL/RPC draft and created the apply
candidate.

Created:

- `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`

Updated:

- `docs/session-reminder-gm-discord-id-sql-checklist.md`
- `docs/session-reminder-gm-discord-id-result.md`
- `docs/session-reminder-gm-mention-result.md`
- `docs/session-reminder-discord-production-gate-plan.md`

Review result:

- the apply candidate keeps `gm_discord_user_id text` in both
  `preview_due_session_reminders` and `claim_due_session_reminders`
- `gm_discord_user_id` is populated only from
  `public.profiles.discord_handle` values matching `^[0-9]{17,20}$`
- missing or invalid values return `null`
- `preview_due_session_reminders` and `claim_due_session_reminders` remain
  service-role-only
- browser/public RPCs still do not expose Discord user IDs
- post-apply verification remains SELECT-only

Still not performed:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge deploy
- runtime invocation
- Discord send
- DB write
- Webhook/secret change

Next Gate recorded from Gate 6.3:

- Gate 6.4: SQL apply independent approval and SELECT-only confirmation.

## Open Questions

1. Should `waitlisted` stay excluded from the first threshold decision?
2. Should shortage reminders be skipped after `application_deadline` has passed?
3. Should sessions with status `full` stay eligible for GM reminder?
4. What is the approved destination for GM reminders?
5. Which SQL/RPC field should carry the validated GM Discord user id for GM mention?
6. If a session start time or reminder offset changes after a reminder was already sent, should a second send be allowed?
7. Which channel key should receive shortage reminders?
8. Which channel key should receive GM reminders?
9. Should failed sends retry automatically, and if so how many times?
10. Should reminder settings be editable only by the GM, or also by managers/admins?

## Implementation Gates

### Gate 1: DB/RPC design SQL draft

Create SQL draft files only. Do not apply.

Scope:

- session reminder setting columns or settings table
- reminder log table
- constraints and indexes
- RLS policy draft
- create/update RPC parameter draft
- claim/finalize RPC draft
- SELECT-only verification draft
- rollback SQL draft

No SQL Editor execution or apply in this gate.

### Gate 2: SQL apply and SELECT confirmation

User-approved independent gate.

Scope:

- apply SQL once
- if errors occur, stop and document before retrying
- SELECT-only confirmation
- no production Discord send
- no browser UI changes unless already merged in a separate gate

### Gate 3: UI implementation

Scope:

- add session-post create/edit reminder controls
- update form fill and payload mapping
- update RPC calls after DB/RPC exists
- allow existing future sessions to enable settings through edit
- no Discord send
- no Edge deploy

### Gate 4: Edge Function and scheduled dry-run

Scope:

- implement dispatcher
- implement due candidate extraction
- generate sanitized message preview
- dry-run only
- no DB write
- no Discord request
- no cron production schedule

### Gate 5: Discord production send gate

Scope:

- shortage `@everyone`
- GM reminder selected destination
- suppress embeds for session URLs
- claim/finalize logs
- duplicate prevention
- retry or failed status handling
- production enable flag and token gate

Production posting, editing, and deletion must remain separately approved.

## Rollback Plan

For UI or client issues:

- remove reminder fields from the form
- remove payload additions
- restore previous cache-bust values or bump to a rollback cache-bust
- confirm static pages still load

For DB/RPC issues:

- stop dispatcher first if present
- roll back the specific columns, table, RPCs, or policies using a reviewed rollback SQL gate
- preserve logs if needed for audit, or document any cleanup separately
- do not mix cleanup apply with unrelated fixes

For Edge/Discord issues:

- disable the real-send gate
- stop cron or scheduled invocation
- avoid repeated sends while investigating
- record only status and sanitized facts in docs
- re-run public-only checks after rollback

Do not solve reminder failures by changing unrelated world-template data, auth rules, or secret settings.

## Safety Notes

This phase intentionally did not perform:

- implementation changes
- SQL creation beyond planning text
- SQL Editor execution
- SQL apply
- DB/RPC/RLS changes
- Edge Function deploy
- Discord dry-run or production send
- secret or webhook changes
- direct Supabase writes
- UI changes
- `updates.json` changes

Any future step that can write data, change permissions, deploy functions, or send Discord messages must be an independent gate.
