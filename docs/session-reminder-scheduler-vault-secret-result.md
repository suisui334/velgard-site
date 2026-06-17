# Session Reminder Scheduler Vault Secret Prep Result

Status: Gate 12F.1 scheduler Vault secrets configured and Edge dispatch token
synchronized. No secret value was displayed or recorded.

## Scope

Gate 12D prepares the Vault secret boundary required before applying the
session reminder scheduler SQL.

This gate did not:

- run SQL
- apply SQL
- create cron
- invoke the Edge Function
- enable real send
- send Discord
- write DB rows
- change Edge Function secrets
- change Supabase Vault values
- deploy Edge Functions
- change UI / HTML / CSS / browser JS
- change `updates.json`

## Existing Pattern Reviewed

The existing admin-cap announcement scheduler uses this pattern:

- Supabase `pg_cron` starts the periodic job.
- Supabase `pg_net` calls the deployed Edge Function.
- The cron command reads Function URL, invoke JWT, and dispatch token from
  Supabase Vault secret names.
- SQL/docs record only secret names and boolean/count style checks.
- Webhook URL, JWT, project URL, dispatch token, Discord IDs, message IDs, and
  response bodies are not written into docs or cron SQL.
- If required Vault secrets are missing, the apply SQL stops before cron job
  creation.

Gate 12D applies the same boundary to `dispatch-session-reminders`.

## Required Vault Secret Names

The scheduler SQL draft and checklist use exactly these Vault secret names:

- `SESSION_REMINDER_FUNCTION_URL`
- `SESSION_REMINDER_INVOKE_JWT`
- `SESSION_REMINDER_DISPATCH_TOKEN`

No raw value is recorded.

## Secret Mapping

`SESSION_REMINDER_FUNCTION_URL`

- Purpose: full deployed invoke URL for `dispatch-session-reminders`.
- Storage boundary: Supabase Vault only.
- Do not inline the URL in scheduler SQL, docs, reports, or chat.

`SESSION_REMINDER_INVOKE_JWT`

- Purpose: JWT accepted by Supabase Edge Function platform verification.
- Storage boundary: Supabase Vault only.
- Do not record the JWT body/value.
- Do not use or document a publishable key as a substitute without a separate
  approval gate.

`SESSION_REMINDER_DISPATCH_TOKEN`

- Purpose: request authorization token sent as `x-dispatch-token`.
- Storage boundary: Supabase Vault for cron and Edge Function secret/env for
  the dispatcher.
- The Vault value must match the Edge Function secret/env value of the same
  name.
- If the dispatch token is rotated, rotate both sides in the same explicit
  secret gate and record only that rotation happened, not the value.

## Alignment With Scheduler SQL

Confirmed by file review:

- `docs/sql-drafts/session-reminder-scheduler-draft.sql` checks the same three
  Vault secret names before scheduling.
- The draft reads the Function URL from `SESSION_REMINDER_FUNCTION_URL`.
- The draft uses `SESSION_REMINDER_INVOKE_JWT` for both `Authorization` and
  `apikey` headers.
- The draft uses `SESSION_REMINDER_DISPATCH_TOKEN` for `x-dispatch-token`.
- The draft payload remains `dry_run:false` and `limit:1`.
- The draft does not reference `DISCORD_SESSION_REMINDER_WEBHOOK_URL`; the
  Webhook remains an Edge Function secret/env responsibility.
- The draft does not set or require
  `SESSION_REMINDER_REAL_SEND_ENABLED=true`.

Actual Vault existence was not queried in this gate. Existence should be
confirmed in the later approved apply/preflight gate using SELECT-only,
value-redacted checks.

## Preparation Procedure For Later Gate

Before scheduler SQL apply:

1. Confirm the deployed Function URL for `dispatch-session-reminders`.
2. Store that URL in Vault as `SESSION_REMINDER_FUNCTION_URL`.
3. Store a valid Edge invoke JWT in Vault as `SESSION_REMINDER_INVOKE_JWT`.
4. Confirm the current Edge Function secret/env
   `SESSION_REMINDER_DISPATCH_TOKEN` exists.
5. Store the same dispatch token in Vault as
   `SESSION_REMINDER_DISPATCH_TOKEN`.
6. Confirm `SESSION_REMINDER_REAL_SEND_ENABLED` is not enabled for the
   production-disabled scheduler apply gate.
7. Run only value-redacted Vault presence checks.
8. If any required Vault secret is missing, stop before cron creation.

Do not paste raw values into SQL, docs, terminal reports, issue comments, or
chat.

## SELECT-Only Presence Check Policy

The checklist in `docs/session-reminder-scheduler-sql-checklist.md` contains a
value-redacted Vault presence check.

Expected reporting style:

- `vault_secret_presence: ok`
- `required_secret_count=3`
- no raw secret values
- no Function URL
- no JWT
- no dispatch token

If the count is not `3`, record missing secret names only and stop before
cron creation.

## Real-Send Boundary

Scheduler Vault prep does not enable real send.

Real send remains controlled by the Edge Function secret/env:

- `SESSION_REMINDER_REAL_SEND_ENABLED`

This value must remain disabled until a later explicit production send gate.
Creating Vault secrets or a cron job must not be treated as approval to send
Discord messages.

## Next Gate

Recommended next gate:

- Gate 12E: scheduler SQL apply under explicit approval while real send remains
  disabled.

Gate 12E should stop if required Vault secrets are missing, and it should not
send Discord or enable real send.

## Gate 12F.1 Vault Setup Result

Gate 12F.1 set the scheduler Vault secrets required by
`docs/sql-drafts/session-reminder-scheduler-draft.sql`.

Configured Vault secret names:

- `SESSION_REMINDER_FUNCTION_URL`
- `SESSION_REMINDER_INVOKE_JWT`
- `SESSION_REMINDER_DISPATCH_TOKEN`

Configuration source and boundary:

- `SESSION_REMINDER_FUNCTION_URL` was derived from the existing admin-cap
  scheduler Function URL by replacing only the Edge Function path with
  `dispatch-session-reminders`.
- `SESSION_REMINDER_INVOKE_JWT` reused the existing admin-cap scheduler invoke
  JWT source inside Vault, without printing or recording the value.
- `SESSION_REMINDER_DISPATCH_TOKEN` was regenerated as a new strong random
  value.
- The regenerated dispatch token was set to both:
  - Edge Function secret/env `SESSION_REMINDER_DISPATCH_TOKEN`
  - DB Vault secret `SESSION_REMINDER_DISPATCH_TOKEN`

Real-send boundary:

- `SESSION_REMINDER_REAL_SEND_ENABLED` was explicitly kept false on the Edge
  Function secret/env side.
- It was not enabled.

Value-redacted confirmation:

- required Vault secret count: `3/3`
- Function URL points to `dispatch-session-reminders`: true
- invoke JWT shape check: true
- dispatch token presence/shape check: true
- Edge secret names present:
  - `SESSION_REMINDER_DISPATCH_TOKEN`
  - `SESSION_REMINDER_REAL_SEND_ENABLED`
- `SESSION_REMINDER_REAL_SEND_ENABLED` was set false, not enabled
- cron job `dispatch-session-reminders-every-minute` count: `0`
- `session_reminder_logs` count: `1`

Not performed:

- scheduler SQL apply
- cron creation
- runtime invocation
- Discord send
- `@everyone` send
- real-send enablement
- Edge deploy
- DB/RPC/RLS structure change
- UI / HTML / CSS / browser JS change
- `updates.json` change
- secret value, Function URL, JWT, dispatch token, Webhook URL, project ref,
  Discord ID, session id, or message id recording

Next gate recommendation:

- Gate 12F retry: apply the scheduler SQL under explicit approval while real
  send remains disabled, then run the SELECT-only scheduler confirmation.
