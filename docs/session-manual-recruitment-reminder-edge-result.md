# Session Manual Recruitment Reminder Edge Result

Status: Gate MR-04 Edge Function source implemented, deploy not performed.

Added Edge Function source:

- `supabase/functions/send-session-recruitment-reminder/index.ts`

No Edge deploy, runtime invocation, Discord send, SQL execution, DB/RPC/RLS
change, secret change, cron change, UI change, or `updates.json` change was
performed.

## Request Shape

The function accepts HTTP `POST` JSON:

```json
{
  "session_id": "session key",
  "dry_run": true
}
```

`dry_run` defaults to `true` unless explicitly set to `false`.

## Dry-Run Path

Dry-run uses the caller's authenticated Supabase JWT and calls only:

- `preview_manual_recruitment_reminder(p_session_id text)`

Dry-run does not:

- claim a log row
- call finalize
- write to DB
- send Discord
- read or expose Webhook values

The dry-run response is status/count oriented and includes safe eligibility
fields such as `can_send`, `blocked_reason`, player counts, cooldown state, and
delivery-shape markers. It does not include Webhook URL, token, Discord message
id, raw user id, email, or secret values.

## Production Path

Production path is implemented but not deployed or executed in MR-04.

Production send requires:

- authenticated caller JWT
- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED=true`
- configured Discord Webhook env

The production path performs these steps in order:

1. Rejects before claim if real send is not enabled.
2. Validates Discord Webhook configuration before claim.
3. Calls `claim_manual_recruitment_reminder(p_session_id text)` with the caller
   JWT so the DB can enforce GM/admin authorization using `auth.uid()`.
4. Sends Discord only after claim succeeds.
5. Calls `finalize_manual_recruitment_reminder(...)` with a service-role client.
6. Records `sent` on success or `failed` on send failure.

Discord message ids may be stored by the finalize RPC, but the function response
uses only a `discord_message_reference` marker and does not return message id
values.

## Discord Payload

Manual recruitment reminders use:

- `@everyone`
- `allowed_mentions.parse=["everyone"]`
- `flags: 4` for suppress embeds / OGP card suppression
- absolute `session-detail` URL from `PUBLIC_SITE_BASE_URL`

The Webhook env lookup prefers:

- `DISCORD_SESSION_RECRUITMENT_REMINDER_WEBHOOK_URL`

and falls back to:

- `DISCORD_SESSION_REMINDER_WEBHOOK_URL`

Webhook values are not recorded.

## Local Static Check

- `deno check --no-lock supabase/functions/send-session-recruitment-reminder/index.ts`
  passed

## Not Tested In MR-04

- Edge deploy
- runtime dry-run
- authenticated browser invocation
- production send
- Discord delivery
- claim/finalize execution
- DB write
- UI integration from `session-detail`

## Next Gate

Recommended next gates:

1. MR-05: deploy `send-session-recruitment-reminder` and confirm dry-run /
   production-disabled runtime behavior.
2. MR-06: UI integration from `session-detail` with dry-run/disabled send
   handling.
3. MR-07: explicit `@everyone` limited production send test.

## Gate MR-05 Deploy Attempt

MR-05 local static check passed:

- `deno check --no-lock supabase/functions/send-session-recruitment-reminder/index.ts`

Deploy was attempted for `send-session-recruitment-reminder` only, but did not
complete because the Supabase CLI could not find a linked project ref. The safe
error category was recorded as `LegacyProjectNotLinkedError`.

No project ref value, Function URL, JWT, token, Webhook URL, Discord id, message
id, or concrete runtime URL was recorded.

Because deploy did not complete, MR-05 did not run runtime `dry_run:true`,
runtime `dry_run:false`, Discord send, claim/finalize, DB write, secret change,
SQL/DB change, UI change, cron change, or `updates.json` change.

Result details:

- `docs/session-manual-recruitment-reminder-runtime-check-result.md`

## Gate MR-04.5 Real-Send Flag Separation

MR-04.5 updates the source so manual recruitment reminders no longer share the
automatic session reminder real-send flag.

Manual recruitment production send is now gated by:

- `SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED=true`

The automatic scheduler flag remains separate:

- `SESSION_REMINDER_REAL_SEND_ENABLED`

This means enabling automatic session reminders does not allow manual
recruitment `@everyone` sends. If the manual-specific flag is unset or not
`true`, `dry_run:false` is rejected before claim, before DB write, and before
Discord send.

MR-04.5 did not deploy, invoke runtime, send Discord, change secrets, execute
SQL, change DB/RPC/RLS, implement UI, change cron, or change `updates.json`.

## Gate MR-05 Retry Runtime Result

MR-05 retry deployed only:

- `send-session-recruitment-reminder`

Result:

- deploy succeeded
- production-disabled runtime check returned HTTP `403` /
  `production_not_enabled`
- manual-specific real-send flag was not enabled
- Discord send did not occur
- claim/finalize did not execute

Limited / blocked:

- configured GM/admin test account sign-in returned HTTP `400`, so runtime
  `dry_run:true` with GM/admin JWT was not completed
- direct authenticated table count for
  `session_manual_recruitment_reminder_logs` was not available

No project ref, Function URL, JWT, token, Webhook URL, Discord id, message id,
concrete session id, full session URL, or full Discord message body was
recorded.

## Gate MR-05.5 Authenticated Dry-Run Attempt

MR-05.5 attempted to obtain an authenticated GM/admin runtime context for
`send-session-recruitment-reminder` dry-run confirmation.

Result:

- configured admin / GM password-grant checks returned HTTP `400` /
  `captcha_failed`
- Chrome public `mypage.html` was not already logged in
- no GM/admin JWT was available
- runtime `dry_run:true` was not invoked
- `can_send` / `blocked_reason` remain `not_tested`
- direct anon count for `session_manual_recruitment_reminder_logs` returned
  HTTP `401`, so direct count was unavailable

No `dry_run:false`, Discord send, claim/finalize, DB write, SQL/DB change,
secret change, UI implementation, cron change, or `updates.json` change was
performed.

No Function URL, JWT, token, Webhook URL, Discord id, message id, concrete
session id, full session URL, email address, password, or full Discord message
body was recorded.
