# Session Reminder Scheduler Apply Result

Status: Gate 12F stopped before scheduler SQL apply because required Vault
secrets were missing. No cron job was created.

## Scope

Gate 12F was intended to apply
`docs/sql-drafts/session-reminder-scheduler-draft.sql` and then run the
SELECT-only scheduler confirmation.

The apply was not executed because the required Vault precheck failed before
cron creation.

## Pre-Apply Review

Reviewed apply draft:

- `docs/sql-drafts/session-reminder-scheduler-draft.sql`

Expected scheduler shape:

- mechanism: Supabase `pg_cron` + `pg_net`
- cron job: `dispatch-session-reminders-every-minute`
- cadence: every minute
- payload: `dry_run:false`, `limit:1`
- Function target: `dispatch-session-reminders`
- Function URL, invoke JWT, and dispatch token must be read from Vault
- real send remains controlled by Edge Function env
  `SESSION_REMINDER_REAL_SEND_ENABLED`

## Vault Precheck Result

SELECT-only Vault presence check result:

- admin scheduled-post Vault secret comparison: `3/3`
- session reminder required Vault secrets: `0/3`

Missing or empty required Vault secret names:

- `SESSION_REMINDER_DISPATCH_TOKEN`
- `SESSION_REMINDER_FUNCTION_URL`
- `SESSION_REMINDER_INVOKE_JWT`

Only secret names and counts were recorded. No Vault secret value, Function URL,
JWT, dispatch token, Webhook URL, project ref, Discord ID, session id, or
message id was recorded.

## Apply Result

Scheduler SQL apply result:

- not run
- stopped before cron creation
- stopped before `cron.schedule`
- stopped before any production dispatcher invocation

Cron SELECT result after the stop:

- `dispatch-session-reminders-every-minute` count: `0`

Reminder log count after the stop:

- `session_reminder_logs` count: `1`

This matches the pre-existing manual GM reminder send record and did not
increase during Gate 12F.

## Safety Result

Confirmed not performed:

- SQL apply
- cron creation
- Edge deploy
- runtime invocation
- production `dry_run:false`
- claim/finalize runtime execution
- Discord send
- `@everyone` send
- shortage send
- real-send enablement
- DB/RPC/RLS structure change
- UI / HTML / CSS / browser JS change
- secret value readout or value recording
- `updates.json` change

## Next Gate

Recommended next gate:

- Gate 12F.1: set or confirm the three required scheduler Vault secrets, using
  names only in docs and never recording values.

After the Vault secret setup succeeds:

- retry Gate 12F scheduler SQL apply under explicit approval
- keep `SESSION_REMINDER_REAL_SEND_ENABLED` disabled
- run the SELECT-only scheduler confirmation separately from the apply body

## Gate 12F.1 Follow-up

Gate 12F.1 resolved the Vault prerequisite blocker:

- required Vault secret count after setup: `3/3`
- `SESSION_REMINDER_DISPATCH_TOKEN` was regenerated and synchronized between
  Edge Function secret/env and DB Vault
- `SESSION_REMINDER_REAL_SEND_ENABLED` was kept false
- cron job count remained `0`
- `session_reminder_logs` count remained `1`

The scheduler SQL has still not been applied in this result doc. The next
step remains a separate Gate 12F retry for scheduler SQL apply and SELECT-only
confirmation.

## Gate 12F Retry Apply Result

The scheduler SQL was applied after Gate 12F.1 resolved the Vault prerequisite.

User-side apply result:

- `cron.schedule` result job id: `2`

SELECT-only confirmation:

- required Vault secret count: `3/3`
- cron job count: `1`
- cron job id: `2`
- job name: `dispatch-session-reminders-every-minute`
- schedule: `* * * * *`
- job active: true
- payload marker `dry_run:false`: true
- payload marker `limit:1`: true
- Vault reference markers for Function URL, invoke JWT, and dispatch token:
  true
- `session_reminder_logs` count: `1`

Production-disabled observation:

- recent cron run status: `succeeded`
- recent cron run count observed: `3`
- recent pg_net responses included HTTP `403`
- `403` rows included a production-disabled marker
- no sent-count success marker was observed
- response bodies were not recorded

Safety result:

- real send remained disabled
- Discord send did not occur
- `@everyone` send did not occur
- reminder logs did not increase
- no raw Function URL, JWT, token, Webhook URL, project ref, Discord ID,
  session id, message id, request headers, or response body was recorded
