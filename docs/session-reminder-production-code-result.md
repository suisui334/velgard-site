# Session Reminder Production Code Result

Status: Gate 6 production send code implemented, not deployed.

## Scope

Gate 6 updated the source for:

- `supabase/functions/dispatch-session-reminders/index.ts`

This gate did not deploy the Edge Function and did not invoke runtime. The currently deployed Function remains the Gate 4.5 dry-run-confirmed deployment until a later deploy gate.

## Implemented Production Path

The Function now has separate branches:

- `dry_run:true`: preview-only path.
- `dry_run:false`: production-gated path.

Production path requirements:

- `SESSION_REMINDER_REAL_SEND_ENABLED` must be exactly `true`.
- `SESSION_REMINDER_DISPATCH_TOKEN` must be configured and match the `x-dispatch-token` request header.
- `DISCORD_SESSION_REMINDER_WEBHOOK_URL` must be configured and validate as an HTTPS Discord Webhook URL.
- Supabase service role env values must be available.

If these gates fail, production processing is rejected before claim/send/finalize.

## RPC Use

Dry-run path:

- uses `preview_due_session_reminders`
- does not call claim/finalize
- does not send Discord
- does not write DB

Production path:

- calls `claim_due_session_reminders`
- sends Discord only for claimed rows
- calls `finalize_session_reminder` after each send attempt
- keeps `lock_token` from claim and passes it to finalize

No direct Supabase `.insert/.update/.delete/.upsert` calls were added.

## Discord Payload

Shortage reminder:

- includes `@everyone`
- uses `allowed_mentions.parse=["everyone"]`
- uses `flags: 4` for suppress embeds
- posts with `wait=true` so a message id can be read for finalize

GM confirmed reminder:

- does not include `@everyone`
- uses `allowed_mentions.parse=[]`
- uses `flags: 4`
- sends a channel message with GM display name only
- does not implement GM DM or Discord mention

The Webhook URL is read from env only. No Webhook URL, channel id, message id, Discord id, token, or secret value was written to source or docs.

## Response Shape

Production response is designed as safe counts/status:

- `dry_run:false`
- `production_enabled:true`
- `claimed_count`
- `sent_count`
- `failed_count`
- `skipped_count`
- `results`

Each result includes reminder type, status, title, error summary, and a redacted message-reference status. It does not return raw Discord message ids.

## Verification

Static verification:

- `deno check --no-lock supabase/functions/dispatch-session-reminders/index.ts`: passed
- `preview_due_session_reminders` remains in the dry-run helper.
- `claim_due_session_reminders` is used in the production claim helper.
- `finalize_session_reminder` is used in the production finalize helper.
- Discord `fetch(` exists only in the production send helper.
- `allowed_mentions.parse=["everyone"]` is returned only for `shortage`.
- `flags: 4` is included in Discord payload.
- No direct Supabase write helpers were added.
- No `console.*` was added.

## Not Performed

- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- Webhook/secret setting or change
- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- claim RPC runtime execution
- finalize RPC runtime execution
- `session_reminder_logs` write
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change

## Limited / Not Tested

- runtime dry-run after the production-source change: `not_tested`, because deploy is a later gate
- `dry_run:false` rejection in deployed runtime: `not_tested`
- Discord production send: `not_tested`
- claim/finalize runtime behavior: `not_tested`
- nonzero reminder candidate behavior: `limited`, Gate 4.5 returned `0` items

## Next Gate Candidate

Recommended next gate:

- Gate 7: deploy `dispatch-session-reminders` and confirm production remains disabled.

Gate 7 should deploy only this Function, confirm `dry_run:true` still works, confirm `dry_run:false` is rejected without the production gates, confirm no Discord send, and confirm `session_reminder_logs` does not grow.

## Gate 6.1 GM Mention Review

Gate 6.1 changed the desired product policy for `gm_confirmed`: it should mention the GM's Discord user directly, not only include the GM display name.

Review result:

- current `preview_due_session_reminders` returns `gm_display_name` but no GM Discord user id
- current `claim_due_session_reminders` returns `gm_display_name` but no GM Discord user id
- current Edge Function row types likewise have no GM Discord id field
- existing Discord ID/contact flows are useful precedents but do not provide a safe dispatcher delivery field for the session GM

Because the required value is missing from the reminder RPC contract, Gate 6.1 stopped before code changes. The Gate 6 production source remains not deployed.

Follow-up:

- Gate 6.2 should draft a SQL/RPC update that adds a safe GM Discord user id field to the reminder preview/claim result.
- After that update, Edge code can add `<@id>` for `gm_confirmed`, `allowed_mentions.parse=[]`, and `allowed_mentions.users=[id]`.
- Dry-run previews and docs must mask the mention as `<@GM>` or equivalent and never record the actual Discord id.
