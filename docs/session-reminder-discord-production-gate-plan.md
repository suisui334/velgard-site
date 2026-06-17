# Session Reminder Discord Production Gate Plan

Status: Gate 5 planning only.

This document records the production-send design for session start reminder Discord notifications after the Gate 4.5 runtime dry-run. No Discord request, Discord dry-run send, `@everyone` send, secret/Webhook change, Edge deploy, production implementation, claim/finalize call, SQL apply, DB/RPC/RLS change, UI change, or `updates.json` change was performed.

## Current Baseline

Completed before Gate 5:

- Gate 1: DB/RPC design SQL draft.
- Gate 1.5: SQL apply candidate and Gate 2 checklist.
- Gate 2: SQL apply and SELECT confirmation by user.
- Gate 3.1: `session-post` reminder settings UI.
- Gate 4: dry-run-only `dispatch-session-reminders` Edge Function source.
- Gate 4.5: deployed `dispatch-session-reminders` and confirmed runtime `dry_run:true`.

Gate 4.5 sanitized runtime result:

- HTTP status: `200`
- `ok`: `true`
- `dry_run`: `true`
- `count`: `0`
- `items`: present
- `preview_rpc_only`: `true`
- `db_write`: `false`
- `discord_send`: `false`
- `production_enabled`: `false`
- `session_reminder_logs` count after dry-run: `0`

## Existing Discord Send Patterns

### Session Post Discord Sync

Reference:

- `supabase/functions/sync-session-post-to-discord/index.ts`
- `assets/js/discordSyncClient.js`

Observed pattern:

- Browser calls the Edge Function through `client.functions.invoke`.
- The Edge Function validates a user auth header and GM/admin permissions.
- The Webhook URL is read from env name `DISCORD_SESSION_POST_WEBHOOK_URL`.
- The Webhook URL is validated as HTTPS Discord / Discordapp webhook path.
- Create requests call Webhook with `wait=true`, so a message id/channel id can be read from the response.
- The payload includes `flags: 4` for Discord embed suppression.
- The payload includes `allowed_mentions.parse`.
- `@everyone` is only enabled when the caller explicitly selects `discord_mention_mode = "everyone"` for create.
- Dry-run previews redact concrete session URL values and expose only boolean/status payload facts.

Useful production-send details for reminders:

- Use `flags: 4` for OGP / link preview suppression.
- Use `wait=true` when the reminder needs to store a provider message id.
- Use `allowed_mentions.parse = ["everyone"]` only for the shortage reminder.
- Use `allowed_mentions.parse = []` for GM reminder.
- Do not return or record raw Webhook URL, channel id, message id, session URL, or full message body in docs.

### Admin Cap Announcement Dispatcher

Reference:

- `supabase/functions/dispatch-admin-cap-announcements/index.ts`
- `docs/discord-cap-announcement-plan.md`

Observed pattern:

- Dry-run default performs no DB mutation and no Discord request.
- Production send requires an env flag: `ADMIN_CAP_ANNOUNCEMENT_REAL_SEND_ENABLED`.
- Production send also requires a dispatch token header checked against `ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN`.
- Target channel keys map to env names, for example `DISCORD_WEBHOOK_CAP_ANNOUNCEMENT`.
- Production flow claims rows, sends Discord, then finalizes rows.
- 429 / 5xx failures can become retryable scheduled status in that feature.
- Response reports status/counts and redacted identifiers.

Useful production-send details for reminders:

- Add a separate real-send env flag before any production reminder send.
- Add a dispatch token gate before any scheduled or manual `dry_run:false` invocation.
- Keep channel key to env-name mapping in code, not in DB or public JS.
- Keep retry/failed behavior explicit and conservative.

### Session Reminder Dry-run Dispatcher

Reference:

- `supabase/functions/dispatch-session-reminders/index.ts`
- `docs/session-reminder-edge-dry-run-result.md`
- `docs/session-reminder-edge-runtime-dry-run-result.md`

Current behavior:

- Uses only `preview_due_session_reminders`.
- Does not call `claim_due_session_reminders`.
- Does not call `finalize_session_reminder`.
- Does not send Discord.
- Does not write `session_reminder_logs`.
- `dry_run:false` returns production disabled behavior.
- Runtime dry-run has been deployed and confirmed with `count=0`.

## Destination Policy

### Shortage Reminder

Initial product direction:

- Send to the existing Discord notification channel.
- Include `@everyone`.
- Keep production send behind an independent approval gate.
- Do not record Webhook URL, channel id, project ref, token, message id, Discord URL, or other raw identifiers in docs.

Implementation recommendation:

- Prefer a dedicated reminder env name even if it points to the same existing Discord channel.
- Candidate env name: `DISCORD_SESSION_REMINDER_WEBHOOK_URL`.
- Candidate real-send flag: `SESSION_REMINDER_REAL_SEND_ENABLED`.
- Candidate dispatch token env: `SESSION_REMINDER_DISPATCH_TOKEN`.
- Reusing `DISCORD_SESSION_POST_WEBHOOK_URL` is possible but should require explicit approval because reminder behavior includes scheduled `@everyone`, while session-post sync is immediate create/update/delete behavior.

Why a dedicated env name is safer:

- Separates scheduled reminder send from immediate session post sync.
- Makes it possible to disable reminders without disabling normal session Discord sync.
- Makes audits easier when checking which function can send `@everyone`.
- Allows later channel split without DB or UI changes.

Manual pre-send checks:

- Confirm the destination channel in the Discord UI, without recording channel id or URL in docs.
- Confirm the Webhook belongs to that channel.
- Confirm `@everyone` is approved for the shortage reminder.
- Confirm candidate count and target reminder type before `dry_run:false`.
- Confirm the response will record counts/status only, not raw payloads.

### GM Confirmed Reminder

Initial product direction:

- Do not implement GM DM or direct mention in the first production send gate.
- Send to the existing Discord notification channel with GM display name.
- Keep GM individual mention/profile Discord contact as a later privacy and routing gate.

Gate 6.1 update:

- Product direction changed to GM本人へのDiscord user mention.
- GM confirmed reminder still must not use `@everyone`.
- Production payload should use `allowed_mentions.parse=[]` plus `allowed_mentions.users=[gm_discord_user_id]`.
- Dry-run preview and docs must mask the mention, for example `<@GM>`.
- Current reminder RPCs do not return `gm_discord_user_id`, so Gate 6.1 is blocked until SQL/RPC returns a safe, validated GM Discord id.

Gate 6.2 follow-up:

- The safe source is drafted as `public.sessions.gm_user_id -> public.profiles.id -> public.profiles.discord_handle`.
- The draft returns `gm_discord_user_id` only when the stored value matches `^[0-9]{17,20}$`.
- Missing or invalid values return `null`, so the Edge Function can fall back to no mention.
- The draft keeps preview/claim RPCs service-role-only and does not expose Discord ids through public/browser RPCs.
- SQL apply is still not performed.

Gate 6.3 follow-up:

- The Gate 6.2 draft was reviewed and promoted to an apply candidate:
  `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`.
- The apply candidate keeps `gm_discord_user_id text` in both preview and
  claim RPC return definitions.
- The snowflake-like filter remains `^[0-9]{17,20}$`.
- Browser roles remain revoked; execute remains service-role-only.
- SQL apply is still not performed.

Gate 6.4 follow-up:

- The first apply attempt failed near `union`, was rolled back, and left the
  prior RPCs intact.
- A corrected no-UNION version was applied successfully by the user.
- `gm_discord_user_id` is now present in both preview and claim return
  definitions.
- service-role-only execution remains in place and anon/authenticated execute
  remains false.
- `session_reminder_logs_count=0`; preview, claim, and finalize were not run.
- No real Discord ID was recorded.

Gate 6.5 follow-up:

- `dispatch-session-reminders` source now implements GM-only Discord user
  mention support.
- The source validates `gm_discord_user_id` again with `^[0-9]{17,20}$`.
- Dry-run previews mask the mention as `<@GM>`.
- Runtime responses expose only `gm_mention_available` /
  `gm_mention_used`, not the raw ID.
- Edge deploy and runtime invocation are still not performed.

Implementation recommendation:

- Use the same reminder Webhook env as shortage unless a separate GM reminder channel is explicitly chosen.
- Keep `allowed_mentions.parse = []`.
- Use `gm_display_name` from the server-side preview/claim result.
- Do not include raw `gm_user_id`, email, Discord user id, or profile contact fields.

Implementation recommendation after Gate 6.1:

- Extend `preview_due_session_reminders` and `claim_due_session_reminders` with a safe GM Discord id field before changing Edge send code.
- Use the GM id only for `gm_confirmed`, only after validating it as a Discord snowflake-like value.
- Fall back to GM display-name-only, no-mention delivery if the GM id is missing or invalid.
- Do not expose the actual id in runtime responses, docs, or final reports.

Gate 8 destination decision:

- Use the existing Discord notification channel for both reminder types in the
  first production version.
- Use a dedicated session-reminder Webhook/env boundary even if it points to the
  existing notification channel.
- Keep a separate GM-only channel or Discord DM route as a later extension.
- GM user mention is now supported through the service-role reminder RPC result
  field `gm_discord_user_id`.
- Gate 6.2 draft: `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`.
- Gate 6.3 apply candidate:
  `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`.

## Discord Payload Policy

### Shortage Reminder Payload

Planned content shape:

```text
@everyone
■依頼書【依頼書タイトル】［依頼書URL(OGP画像なし)］
本日X時より開催予定です。最低人数に後X人足りていません。ご都合よろしければ参加いかがでしょうか。
```

Payload rules:

- Include `@everyone` in content only for `reminder_type = shortage`.
- Set `allowed_mentions.parse = ["everyone"]` only for `reminder_type = shortage`.
- Set `flags: 4` to suppress embeds.
- Use `wait=true` when posting so the Discord message id can be captured for finalize.
- Truncate content to Discord limits, following the existing session sync pattern.
- Do not paste full runtime message previews into docs.

OGP / suppress embeds notes:

- Square brackets around a URL are not a reliable embed suppression mechanism by themselves.
- Existing session sync uses Discord payload `flags: 4` and has documented manual QA for suppressed session-detail links.
- Reminder production should reuse that `flags: 4` policy.
- Dry-run/reporting should record boolean facts such as `suppress_embeds=true`, not raw URLs.

### GM Confirmed Reminder Payload

Initial content concept:

```text
■依頼書【依頼書タイトル】
本日X時より開催予定です。最低人数を満たしています。開催準備をご確認ください。
```

GM display name may be included as display text only, for example a GM-facing prefix. It must not expose raw user id, email, Discord id, or profile contact internals.

Payload rules:

- Do not include `@everyone`.
- Set `allowed_mentions.parse = []`.
- Use `flags: 4` if a session URL is included.
- Use `wait=true` if the provider message id is needed for finalize.
- Keep exact wording open until the production implementation gate.

Gate 6.1 payload update:

- Desired first line is a GM user mention such as `<@GM_DISCORD_ID>` in production content.
- The actual id must come from a service-role reminder RPC result, not from public data or docs.
- `allowed_mentions` should be `{ "parse": [], "users": ["GM_DISCORD_ID"] }` when the id is present.
- If the id is missing, content should omit the mention and use `allowed_mentions.parse=[]`.
- Dry-run `message_preview` should mask the mention as `<@GM>` or equivalent.
- This payload update is blocked until the preview/claim RPC result includes the safe GM Discord id.
- Gate 6.2 created a draft to add that return field, but production Edge code must wait until the SQL apply gate is completed.
- Gate 6.3 created the reviewed apply candidate, but production Edge code must
  still wait until the SQL apply gate is completed.
- Gate 6.4 completed the SQL apply, and Gate 6.5 updated source only. Deploy
  and runtime verification remain later gates.

## Production Flow

Recommended flow:

1. Edge Function receives POST.
2. Request must include `dry_run:false`.
3. Function checks production real-send env flag.
4. Function checks dispatch token header.
5. Function creates a service-role Supabase client.
6. Function calls `claim_due_session_reminders(p_now, p_limit)`.
7. Function sends Discord only for claimed rows.
8. Success calls `finalize_session_reminder(log_id, lock_token, "sent", message_id, null)`.
9. Failure calls `finalize_session_reminder(log_id, lock_token, "failed", null, error_summary)`.
10. Intentional non-send calls `finalize_session_reminder(log_id, lock_token, "skipped", null, reason)`.
11. Response returns safe counts/status only.

Important details:

- `lock_token` from claim must be required by finalize.
- `claim_due_session_reminders` inserts `session_reminder_logs` rows with status `claimed`.
- `unique(session_id, reminder_type)` prevents duplicate production sends in the first version.
- If a reminder has already been claimed/sent/failed/skipped, preview/claim should not return it again under the first design.
- Start time or offset edits after a sent reminder do not automatically resend.
- A future reset or log invalidation feature is required if manual resend is needed.
- Dry-run remains preview-only and never calls claim/finalize.

## Failure, Retry, And Reset Policy

First production version recommendation:

- Treat failed sends as terminal until reviewed.
- Do not auto-retry `@everyone`.
- Return only generalized failure codes.
- Truncate and sanitize `error_message`.
- Do not store raw Discord response bodies.
- Do not expose provider message ids in docs or browser UI.

Alternative later extension:

- Retry transient failures such as 429 or 5xx for GM reminders first.
- Keep shortage `@everyone` retry behind separate approval.
- Add a manual reset/invalidate flow for a specific `session_id + reminder_type`.
- Add SELECT-only reporting for reminder log status without exposing raw ids.

## Production Enable Conditions

Production send must remain disabled until all conditions are true:

- Reminder destination Webhook/env is decided.
- Webhook/secret has been set in the approved secret gate.
- `@everyone` production send is explicitly approved for shortage reminders.
- GM destination policy is decided.
- `flags: 4` / suppress embeds policy is confirmed for reminder payloads.
- claim/finalize production code is implemented and checked.
- `dry_run:false` remains rejected while production flag is off.
- A nonzero candidate is confirmed by dry-run, or a safe test target is prepared.
- The expected target count is known before send.
- Rollback/stop procedure is documented.
- Reporting format is limited to counts/status and redacted references.

## Production Implementation Checks

Before deploy of production code:

- `deno check --no-lock supabase/functions/dispatch-session-reminders/index.ts`
- Search for unexpected `fetch(` paths.
- Confirm `fetch(` is only the Discord Webhook send path.
- Confirm Webhook URL is read only from env.
- Confirm no Webhook URL or token literal appears in source.
- Confirm `dry_run:true` still uses preview only.
- Confirm `dry_run:false` requires real-send flag and dispatch token.
- Confirm `claim_due_session_reminders` is only used in production branch.
- Confirm `finalize_session_reminder` is only used after claim.
- Confirm `allowed_mentions.parse = ["everyone"]` only for shortage.
- Confirm GM reminder uses `allowed_mentions.parse = []`.
- Confirm payload uses `flags: 4`.
- Confirm response excludes raw message ids, channel ids, session URLs, and message body.

Runtime checks before first production send:

- `dry_run:true` still returns safe preview response.
- `dry_run:false` without flag/token is rejected.
- logs count does not change in dry-run.
- nonzero candidate count is understood before any send.
- message preview is reviewed without pasting full real values into docs.

## Next Gate Split

### Gate 6: Production Send Code, No Deploy

Scope:

- Implement Discord send code in `dispatch-session-reminders`.
- Implement claim/finalize production branch.
- Add real-send flag and dispatch token checks.
- Add Webhook env mapping without setting secrets.
- Keep production disabled by default.
- Run `deno check`.
- Do not deploy.
- Do not send Discord.
- Do not call claim/finalize runtime.

Gate 6 result:

- `docs/session-reminder-production-code-result.md`
- production-gated code was implemented in source
- `deno check --no-lock supabase/functions/dispatch-session-reminders/index.ts`: passed
- no Edge deploy, runtime invocation, Discord send, claim/finalize runtime call, DB write, secret/Webhook change, or `updates.json` change was performed

### Gate 7: Deploy And Production Disabled Check

Scope:

- Deploy only `dispatch-session-reminders`.
- Confirm `dry_run:true` still works.
- Confirm `dry_run:false` is rejected while production flag/dispatch token is absent or disabled.
- Confirm no Discord send.
- Confirm `session_reminder_logs` does not grow.

Gate 7 result:

- `docs/session-reminder-edge-production-disabled-result.md`
- deployed only `dispatch-session-reminders`
- `dry_run:true`: HTTP `200`, `ok:true`, `count:0`
- `production_enabled:false`
- `dry_run:false`: HTTP `403` production-disabled rejection
- `session_reminder_logs` count before/after: `0` / `0`
- no Discord send, DB write, claim/finalize success path, Webhook/secret
  change, SQL apply, cron setup, or UI change
- raw Discord IDs, Webhook URLs, provider message IDs, project refs, and real
  session URLs were not recorded

### Gate 8: Secret / Destination Boundary Planning

Scope:

- Decide reminder destination policy.
- Decide dedicated reminder env/secret boundary.
- Do not set or change secrets.
- Do not deploy.
- Do not invoke runtime.
- Do not send Discord.
- Do not enable real send.

Gate 8 result:

- `docs/session-reminder-discord-secret-boundary-plan.md`
- shortage reminders use the existing Discord notification channel for the
  first production version
- shortage reminders use a dedicated reminder Webhook/env boundary:
  `DISCORD_SESSION_REMINDER_WEBHOOK_URL`
- shortage remains the only reminder type allowed to use `@everyone`
- GM reminders use the same notification channel for the first production
  version
- GM reminders use GM user mention when a valid `gm_discord_user_id` exists
- GM reminders use `allowed_mentions.parse=[]` and
  `allowed_mentions.users=[GM_ID]`
- GM reminders never use `@everyone`
- `SESSION_REMINDER_DISPATCH_TOKEN` gates production dispatch calls
- `SESSION_REMINDER_REAL_SEND_ENABLED` must remain disabled until a later send
  gate
- no secret/Webhook setting, Edge deploy, runtime invocation, Discord send, DB
  write, SQL apply, cron setup, or UI change was performed

### Gate 9: Secret Setting Only, Real Send Disabled

Scope:

- Set or confirm `DISCORD_SESSION_REMINDER_WEBHOOK_URL`.
- Set or confirm `SESSION_REMINDER_DISPATCH_TOKEN`.
- Keep `SESSION_REMINDER_REAL_SEND_ENABLED` disabled.
- Do not send Discord.
- Do not call claim/finalize.
- Do not write DB.
- Do not record secret values.

Gate 9 attempt result:

- `docs/session-reminder-secret-setup-result.md`
- blocked before secret changes because the actual Webhook URL value for
  `DISCORD_SESSION_REMINDER_WEBHOOK_URL` was not available to Codex
- Supabase secret listing confirmed useful secret names/metadata but did not
  expose a usable raw Webhook URL for copying
- `SESSION_REMINDER_DISPATCH_TOKEN` was not set partially
- `SESSION_REMINDER_REAL_SEND_ENABLED` remained disabled / not enabled
- no Discord send, Edge deploy, runtime invocation, claim/finalize, DB write,
  SQL apply, cron setup, or UI change was performed

Gate 9 retry result:

- `DISCORD_SESSION_REMINDER_WEBHOOK_URL` was set through clipboard input without
  recording the value
- `SESSION_REMINDER_DISPATCH_TOKEN` was generated locally and set without
  recording the value
- `SESSION_REMINDER_REAL_SEND_ENABLED` was not enabled
- name-only confirmation showed the two target secrets present and real-send
  flag absent / not enabled
- no Discord send, Edge deploy, runtime invocation, claim/finalize, DB write,
  SQL apply, cron setup, or UI change was performed

### Gate 10: Deploy / Runtime Secret Presence Check, Production Still Rejected

Scope:

- Deploy only `dispatch-session-reminders` if needed for runtime confirmation.
- Confirm `dry_run:true` still works.
- Confirm `dry_run:false` still rejects while real send is disabled.
- Confirm secret presence alone does not enable production.
- Confirm no Discord send.
- Confirm `session_reminder_logs` does not grow.

Gate 10 result:

- `docs/session-reminder-secret-runtime-check-result.md`
- `DISCORD_SESSION_REMINDER_WEBHOOK_URL`: present
- `SESSION_REMINDER_DISPATCH_TOKEN`: present
- `SESSION_REMINDER_REAL_SEND_ENABLED`: not present / not enabled
- Edge deploy was not performed because there was no code change after the
  previous deploy
- `dry_run:true`: HTTP `200`, `ok:true`, `production_enabled:false`
- `dry_run:false`: HTTP `403`, production disabled rejection
- `session_reminder_logs` count before/after: `0` / `0`
- no Discord send, claim/finalize success path, DB write, secret/Webhook
  change, SQL apply, cron setup, or UI change was performed

### Gate 11: Limited Production Send Test

Scope:

- Explicitly enable real send for the test gate only.
- Use a safe target and expected count of `1`.
- Prefer `gm_confirmed` first because it does not use `@everyone`.
- If shortage must be tested, require explicit `@everyone` approval even for
  one item.
- Use claim/finalize.
- Stop on first failure.
- Record only counts/status and redacted references.

Gate 11 preflight result:

- `docs/session-reminder-limited-production-send-result.md`
- stopped before production send because `dry_run:true` returned `count=0`
  instead of exactly one `gm_confirmed` candidate
- shortage item present: `false`
- message preview contained `@everyone`: `false`
- raw Discord ID pattern in response: not observed
- `session_reminder_logs` count before/after: `0` / `0`
- `SESSION_REMINDER_REAL_SEND_ENABLED` was not enabled
- production `dry_run:false` with dispatch token was not called
- no Discord send, claim/finalize success path, DB write, Edge deploy, SQL
  apply, cron setup, or UI change was performed

Gate 11A candidate check result:

- `docs/session-reminder-gm-confirmed-candidate-check.md`
- current `dry_run:true` returned `count=0`
- SELECT-only aggregate found `gm_reminder_enabled=true` sessions: `0`
- due-window GM reminder candidates: `0`
- logs count before/after: `0` / `0`
- no real send enablement, production invocation, Discord send, claim/finalize,
  DB write, Edge deploy, SQL apply, cron setup, or UI change was performed

Next preparation:

- enable GM reminder settings on one suitable existing or test session through
  an approved UI/RPC path, then retry the candidate check before any production
  send.

Gate 11B retry candidate check:

- `dry_run:true` with the JST 20:00 override returned HTTP `200`.
- `ok:true`.
- `count:1`.
- reminder type: `gm_confirmed`.
- shortage item present: `false`.
- message preview contained `@everyone`: `false`.
- raw Discord ID pattern in response: not observed.
- `session_reminder_logs` count before/after: `0` / `0`.
- no real send enablement, production invocation, Discord send, claim/finalize,
  DB write, Edge deploy, SQL apply, cron setup, or UI change was performed.

Gate 11C limited production attempt:

- preflight immediately before send again returned exactly one safe
  `gm_confirmed` candidate.
- `SESSION_REMINDER_DISPATCH_TOKEN` was regenerated for the gate.
- `SESSION_REMINDER_REAL_SEND_ENABLED` was temporarily enabled.
- one production invocation was made with `dry_run:false`, `limit:1`, the same
  JST 20:00 override, and the dispatch token header.
- sanitized HTTP status: `500`.
- `ok:false`.
- `sent_count`: not present / not `1`.
- `claimed_count`: not present.
- `failed_count`: not present.
- `skipped_count`: not present.
- raw Discord ID pattern in sanitized response: not observed.
- Discord provider message id: not recorded.
- no retry was performed.
- `SESSION_REMINDER_REAL_SEND_ENABLED` was immediately disabled again.
- post-disable `dry_run:false` returned HTTP `403` with production disabled
  rejection.
- post-disable claimed/sent positive counts: `false` / `false`.
- `session_reminder_logs` count before/after: `0` / `0`.

Gate 11C did not confirm a successful send. Because logs remained `0`, the
successful claim/finalize path did not complete. Before any further production
send attempt, run a send-free Gate 11D diagnosis for the HTTP `500` production
path failure. Record only safe status/counts and do not expose Webhook, token,
Discord ID, message id, session id, session URL, or message body values.

Gate 11D production HTTP `500` diagnosis:

- result doc: `docs/session-reminder-production-500-diagnosis.md`
- `session_reminder_logs` count remained `0`
- provider-side Edge logs were not copied into docs; the local CLI available in
  this workspace did not expose a function logs subcommand
- the Gate 11C deployed response did not yet include a safe `stage` field, so
  the exact runtime stage could not be read from the recorded response
- code-path inference: real-send and token gates likely passed; successful
  claim/finalize did not complete; likely remaining pre-send failure areas are
  `webhook_config` or `claim_rpc`
- prepared source hardening in
  `supabase/functions/dispatch-session-reminders/index.ts`
- new safe error stages include `production_gate`, `production_auth`,
  `webhook_config`, `preview_rpc`, and `claim_rpc`
- expected webhook configuration and claim RPC failures now map to HTTP `502`
  with a safe stage after the next deploy
- no Edge deploy, production invocation, Discord send, claim/finalize runtime
  execution, DB write, SQL/DB structure change, secret change, cron setup, UI
  change, or `updates.json` change was performed

Next gate before any resend:

- deploy the stage-aware dispatcher and run production-disabled checks only.
  Do not re-run production send until the stage-aware deployment has been
  verified and a separate explicit send gate is approved.

Gate 11E stage-aware runtime result:

- result doc: `docs/session-reminder-stage-aware-runtime-result.md`
- deployed only `dispatch-session-reminders`
- initial local Docker-based deploy path was unavailable because Docker was not
  running
- deploy succeeded via Supabase API bundling
- `dry_run:true`: HTTP `200`, `ok:true`, `count:1`,
  `production_enabled:false`, `db_write:false`, `discord_send:false`
- `dry_run:false`: HTTP `403`, `production_not_enabled`, stage
  `production_gate`
- positive claimed/sent counts: `false` / `false`
- `session_reminder_logs` count before/after: `0` / `0`
- no real-send enablement, production send retry, Discord send, successful
  claim/finalize path, DB write, SQL/DB change, secret change, cron setup, UI
  change, or `updates.json` change was performed

Next gate before any `gm_confirmed` retry:

- Gate 11F: limited `gm_confirmed` production retry with the stage-aware
  dispatcher, only after explicit approval. If it fails, record the safe
  `stage` and stop without repeating the production send.

Gate 11F stage-aware `gm_confirmed` production retry:

- preflight `dry_run:true`: HTTP `200`, `ok:true`, `count:1`, reminder type
  `gm_confirmed`
- shortage item present: `false`
- message preview contained `@everyone`: `false`
- raw Discord ID pattern in response: not observed
- logs count before: `0`
- regenerated dispatch token for the gate
- temporarily enabled real send
- production invocation count: `1`
- production retry HTTP status: `502`
- error code: `db_claim_failed`
- stage: `claim_rpc`
- `sent_count`: not present / not `1`
- `claimed_count`: not present
- `failed_count`: not present
- `skipped_count`: not present
- result count: `0`
- no retry was performed
- real send was disabled immediately after the retry
- post-disable `dry_run:false`: HTTP `403`, `production_not_enabled`, stage
  `production_gate`
- positive claimed/sent counts after re-disable: `false` / `false`
- logs count after: `0`

Gate 11F did not confirm a successful send. Because logs remained `0` and the
stage-aware response reported `claim_rpc`, do not attempt another production
send until `claim_due_session_reminders` has been reviewed with SQL/RPC and
SELECT-only checks.

Next gate before any production retry:

- Gate 11G: diagnose `claim_due_session_reminders` failure with no Discord
  send, no real-send enablement, no claim/finalize runtime execution, and no DB
  write.

Gate 11H / Gate 11I claim-fix retry result:

- the claim RPC fix SQL was applied by the user before Gate 11I
- SELECT-only apply result:
  - claim RPC exists: `true`
  - security definer: `true`
  - `service_role` execute: `true`
  - `anon` / `authenticated` execute: `false`
  - return columns: `18`
  - `gm_discord_user_id text`: `true`
  - logs constraints: `OK`
  - `session_reminder_logs` count: `0`
- Gate 11I preflight `dry_run:true`: HTTP `200`, `ok:true`, `count:1`,
  reminder type `gm_confirmed`
- shortage item present: `false`
- message preview contained `@everyone`: `false`
- raw Discord ID pattern in response: not observed
- regenerated dispatch token for the gate
- temporarily enabled real send
- production invocation count: `1`
- production retry HTTP status: `200`
- `ok:true`
- `claimed_count:1`
- `sent_count:1`
- `failed_count:0`
- `skipped_count:0`
- result count: `1`
- result type: `gm_confirmed`
- result status: `sent`
- no retry was performed
- real send was disabled immediately after the retry
- post-disable `dry_run:false`: HTTP `403`, `production_not_enabled`, stage
  `production_gate`
- positive claimed/sent counts after re-disable: `false` / `false`
- logs count before/after: `0` / `1`

Gate 11I confirmed one `gm_confirmed` production send without `@everyone`.
No shortage send, multiple-item send, cron setup, Edge deploy, SQL/DB structure
change, UI change, `updates.json` change, or secret/token/Webhook/Discord
ID/message id/message body recording was performed.

Next gate:

- Gate 12 planning or a separate shortage `@everyone` approval gate. Require a
  fresh target-count check, destination confirmation, and explicit `@everyone`
  approval before any shortage production operation.

### Gate 12: Shortage `@everyone` Production Operation

Scope:

- Final independent approval gate.
- Confirm target count immediately before send.
- Confirm destination channel manually.
- Send with `@everyone` only for shortage reminders.
- Confirm finalize status counts.
- Confirm no duplicate sends.
- Confirm logs and Discord result using sanitized reporting only.

## Rollback / Stop Procedure

If production reminder sending misbehaves:

- Disable real-send env flag first.
- Stop cron/scheduled invocation if configured.
- Do not rerun production blindly.
- Check `session_reminder_logs` by SELECT-only count/status.
- Do not delete or mutate logs without a separate SQL gate.
- If a send succeeded but finalize failed, stop and manually investigate before resend.
- If a send failed after claim, keep the failed/skipped log until an explicit reset plan exists.
- Do not change world-template data, session settings, or Discord secrets to hide an ops failure.

## Not Performed In Gate 5

- Discord send
- Discord dry-run send
- `@everyone` send
- Webhook/secret change
- Edge deploy
- production send implementation
- claim RPC call
- finalize RPC call
- `session_reminder_logs` write
- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- UI / HTML / CSS / JS change
- `updates.json` change

## Limited / Open

- Exact reminder Webhook secret value: `not_recorded`, to be set/confirmed in a
  later secret gate.
- `SESSION_REMINDER_REAL_SEND_ENABLED`: remains disabled until a later send
  gate.
- GM reminder exact wording: mostly implemented, but final production wording
  can still be checked before first send.
- GM Discord DM route: future gate.
- Retry behavior for failed shortage `@everyone`: future gate.
- Nonzero runtime candidate preview: `limited`, latest runtime checks returned
  `0`.
