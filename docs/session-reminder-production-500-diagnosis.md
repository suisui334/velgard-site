# Session Reminder Production 500 Diagnosis

Status: Gate 11D diagnosis and source hardening completed. No send was
performed.

## Scope

Gate 11D investigated the HTTP `500` returned by the Gate 11C limited
`gm_confirmed` production attempt.

This gate did not enable real send, did not call `dry_run:false`, did not send
Discord, did not execute claim/finalize, did not write DB rows, did not deploy
the Edge Function, and did not change SQL, DB structure, secrets, cron, UI, or
`updates.json`.

## Logs Count

SELECT-only count:

- `session_reminder_logs` count after Gate 11C and during Gate 11D: `0`

No row values, session ids, user ids, Discord ids, message ids, session URLs,
Webhook URLs, token values, or message bodies were recorded.

Interpretation:

- Because the logs count remains `0`, the successful production
  claim/finalize path did not complete.
- The failure was either before a claim row was created or inside the claim RPC
  path before a log row was persisted.

## Edge Logs / Response Diagnosis

The local Supabase CLI available in this workspace does not expose a
`functions logs` subcommand. Gate 11D therefore did not retrieve provider-side
Edge logs through the CLI, and no Dashboard output or secret-bearing logs were
copied into docs.

The Gate 11C sanitized response had HTTP `500` and `ok:false`, but the deployed
function response did not yet include a safe `stage` field. That means the
exact runtime stage could not be distinguished from the recorded response
alone.

Code-path inference from the deployed source and logs count:

- auth/token gate likely passed, because the response was not the production
  disabled or authorization rejection path.
- real-send env gate likely passed for the single attempt, because the response
  was not the production disabled rejection path.
- no reminder log row was created, so successful claim/finalize did not happen.
- likely remaining pre-send failure areas are `webhook_config` or `claim_rpc`.

## Source Hardening

Updated:

- `supabase/functions/dispatch-session-reminders/index.ts`

Changes:

- Added a safe `stage` field to error responses.
- Added stage values for:
  - `request_validation`
  - `service_client_config`
  - `production_gate`
  - `production_auth`
  - `webhook_config`
  - `preview_rpc`
  - `claim_rpc`
- Changed expected preview/claim RPC failures to HTTP `502` with stage values.
- Changed webhook configuration failure to HTTP `502` with stage
  `webhook_config`.
- Kept production-disabled behavior as HTTP `403` with stage `production_gate`.
- Kept auth/token rejection as HTTP `401` with stage `production_auth`.

The response still does not include Webhook URLs, token values, raw Discord
IDs, Discord message ids, session ids, session URLs, or message bodies.

## Verification

- `deno check --no-lock supabase/functions/dispatch-session-reminders/index.ts`:
  passed
- `dry_run:true` path remains on `preview_due_session_reminders`.
- production path remains the only path that can call
  `claim_due_session_reminders`, Discord Webhook `fetch`, and
  `finalize_session_reminder`.
- No `console.*` logging was added.
- No direct Supabase table write was added.

## Not Performed

- `SESSION_REMINDER_REAL_SEND_ENABLED` enablement
- production `dry_run:false` invocation
- Discord send
- Discord dry-run send
- `@everyone` send
- shortage send
- claim/finalize runtime execution
- `session_reminder_logs` write
- Edge deploy
- SQL Editor execution
- SQL apply
- DB/RPC/RLS structure change
- secret/Webhook setting or change
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change

## Next Gate Candidate

Recommended next gate:

- Gate 11E: deploy the stage-aware dispatcher and run production-disabled
  checks only.

After that, use a separate explicit gate to re-run the limited `gm_confirmed`
production attempt only if the operator approves it. If it fails again, record
the safe `stage` value and stop without retrying.

## Gate 11E Runtime Follow-up

Result doc:

- `docs/session-reminder-stage-aware-runtime-result.md`

Sanitized result:

- deployed only `dispatch-session-reminders`
- initial local Docker-based deploy path was unavailable because Docker was not
  running
- deploy succeeded via Supabase API bundling
- `dry_run:true`: HTTP `200`, `ok:true`, `production_enabled:false`,
  `db_write:false`, `discord_send:false`
- `dry_run:false`: HTTP `403`, `production_not_enabled`, stage
  `production_gate`
- `session_reminder_logs` count before/after: `0` / `0`

No real send flag was enabled, no Discord send occurred, no successful
claim/finalize path ran, and no reminder log rows were created.
