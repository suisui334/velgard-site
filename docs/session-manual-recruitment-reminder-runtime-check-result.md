# Session Manual Recruitment Reminder Runtime Check Result

Status: Gate MR-05 deploy/runtime check blocked before deploy.

## Scope

Target Edge Function:

- `send-session-recruitment-reminder`

MR-05 intended to deploy the Function and confirm:

- `dry_run:true` runtime preview
- production-disabled `dry_run:false` rejection
- no Discord send
- no DB write
- no manual recruitment log count increase

## Completed

Local static check:

- `deno check --no-lock supabase/functions/send-session-recruitment-reminder/index.ts`
  passed

Deploy command attempted for only:

- `send-session-recruitment-reminder`

## Blocker

Deploy did not complete because the Supabase CLI could not find a linked
project ref.

Recorded safe error category:

- `LegacyProjectNotLinkedError`

No project ref value, Function URL, JWT, token, Webhook URL, Discord id, message
id, or concrete runtime URL is recorded.

## Not Performed

Because deploy did not complete, the following were not performed:

- Edge deploy success
- runtime `dry_run:true`
- runtime `dry_run:false`
- Discord send
- claim/finalize runtime execution
- DB write
- log count before/after runtime confirmation
- secret change
- SQL/DB change
- UI change
- cron change
- `updates.json` change

## Next Gate

Retry MR-05 after one of the following is available in the execution context:

- a linked Supabase project for this working tree, or
- an explicit `--project-ref` value supplied outside docs/reporting, plus
  authenticated GM/admin invocation context for `dry_run:true`.

The retry should again deploy only `send-session-recruitment-reminder`, then
run `dry_run:true` and production-disabled `dry_run:false` without enabling
real send.

## MR-04.5 Retry Note

After MR-04.5, production-disabled retry checks should verify the
manual-specific real-send flag:

- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED`

The automatic session reminder flag must not enable this Function:

- `SESSION_REMINDER_REAL_SEND_ENABLED`

Expected production-disabled behavior remains: if the manual-specific flag is
unset or not `true`, `dry_run:false` is rejected before claim, before DB write,
and before Discord send.

## MR-05 Retry Result

Status: deploy succeeded; production-disabled runtime gate confirmed; GM/admin
dry-run preview remains blocked by unavailable authenticated test JWT.

Completed:

- `deno check --no-lock supabase/functions/send-session-recruitment-reminder/index.ts`
  passed.
- Deployed only `send-session-recruitment-reminder`.
- Deploy used an explicit project ref because the working tree was not linked.
  The project ref value was not recorded.
- Runtime `dry_run:false` was invoked with the manual-specific real-send flag
  not enabled.
- Response was HTTP `403` with `production_not_enabled`.
- This confirms the manual send path is rejected before claim when
  `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED` is unset / not `true`.

Blocked / limited:

- GM/admin test sign-in using configured local test account env values returned
  HTTP `400`; no user JWT was obtained.
- Therefore runtime `dry_run:true` with GM/admin JWT was not completed.
- `can_send` / `blocked_reason` were not confirmed at runtime.
- Direct authenticated REST count for
  `session_manual_recruitment_reminder_logs` was not available, consistent with
  direct table access being closed.

Not performed:

- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED=true`
- Discord send
- claim/finalize runtime execution
- DB write
- SQL/DB change
- UI implementation
- secret change
- cron change
- `updates.json` change

No Function URL, project ref, JWT, token, Webhook URL, Discord id, message id,
concrete session id, full session URL, or full Discord message body was
recorded.

Next retry needs a valid GM/admin authenticated JWT and a target session id
provided or made available outside docs/reporting.

## MR-05.5 Authenticated Dry-Run Attempt

Status: blocked before runtime dry-run because a valid GM/admin authenticated
JWT was not available in this execution context.

Authentication checks:

- Local test account password-grant attempts for configured admin / GM accounts
  returned HTTP `400` with safe error code `captcha_failed`.
- No access token was obtained.
- Chrome was opened to the public `mypage.html`; the page was not already
  logged in.
- No browser storage, raw JWT, password, email address, token, or session value
  was recorded.

Runtime dry-run:

- `send-session-recruitment-reminder` `dry_run:true` with GM/admin JWT was not
  invoked.
- No target session id was used.
- `can_send` / `blocked_reason` were not confirmed.
- participant count fields were not confirmed.

Log count:

- Direct anon REST count for
  `session_manual_recruitment_reminder_logs` returned HTTP `401`.
- Count was not available through direct table access.
- No DB write path was executed, so no manual recruitment reminder log could be
  created by this attempt.

Not performed:

- `dry_run:false`
- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED=true`
- Discord send
- claim/finalize runtime execution
- DB write
- SQL/DB change
- UI implementation
- secret change
- cron change
- `updates.json` change

Next retry requires a valid GM/admin authenticated browser session or JWT and a
target session id provided outside docs/reporting.

## MR-06 Runtime Scope

MR-06 implemented the browser UI integration only.

No runtime `dry_run:true` with GM/admin JWT was performed in this gate, because
the authenticated runtime blocker from MR-05.5 remained unresolved.

No `dry_run:false`, real-send flag enablement, Discord send, claim/finalize, DB
write, SQL/DB change, secret change, cron change, or `updates.json` change was
performed.

## MR-06.5 Browser Runtime Scope

MR-06.5 attempted browser QA, but Chrome was not logged in as GM/admin.

Observed:

- public `mypage.html` showed logged-out state
- a public `session-detail` candidate in logged-out state showed no management
  panel
- manual recruitment reminder UI was not visible in logged-out state

Not run:

- authenticated `dry_run:true`
- `dry_run:false`
- claim/finalize
- Discord send
- DB write
- log count mutation

No JWT, token, Webhook URL, Discord id, message id, concrete session id, full
session URL, or Discord message body was recorded.

## MR-07 Deferred Production Runtime Boundary

MR-07 production send testing is deferred because this is not yet the timing
where the GM/admin wants to send an actual recruitment reminder.

Recorded state:

- User-side GM/admin browser QA has confirmed the manual recruitment reminder
  UI and send button are visible.
- The send button was not clicked.
- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED=true` was not set.
- No production request was made.
- No Discord send occurred.
- No manual recruitment reminder log or cooldown was created by this gate.

When the send timing arrives, the next production gate should:

- limit the test to one target session
- enable the manual recruitment real-send flag only for the test window
- press the button once
- verify status/count only
- confirm one Discord post, OGP suppression, clickable absolute URL, log growth,
  `sent` status, cooldown, and resend prevention
- avoid recording Webhook, token, JWT, Discord id, message id, concrete session
  id, full URL, or message body values

Not run:

- `dry_run:false`
- claim/finalize
- Discord send
- DB write
- SQL/DB change
- Edge deploy
- secret change
- cron change
- `updates.json` change

## MR-06.6 User Browser QA Runtime Boundary

MR-06.6 records the user-side authenticated browser QA result only.

Confirmed by user-side browser:

- The browser was logged in as GM/admin.
- The target `session-detail` page showed the manual recruitment reminder UI.
- The `参加者募集中リマインドを送る` button was visible.

Not run in this gate:

- button click
- `dry_run:false`
- claim/finalize
- Discord send
- DB write
- manual recruitment reminder log mutation
- real-send flag enablement

No JWT, token, Webhook URL, Discord id, message id, concrete session id, full
session URL, or Discord message body was recorded.

## MR-06.5 Retry Browser Runtime Scope

MR-06.5 retry still did not obtain a logged-in GM/admin browser context.

Observed:

- public `mypage.html` showed logged-out state
- a public `session-detail` candidate in logged-out state showed no management
  panel
- manual recruitment reminder UI and send button were not present in logged-out
  state

Not run:

- authenticated `dry_run:true`
- `dry_run:false`
- claim/finalize
- Discord send
- DB write
- log count mutation

No JWT, token, Webhook URL, Discord id, message id, concrete session id, full
session URL, or Discord message body was recorded.
