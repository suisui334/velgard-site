# Session Reminder Scheduler Operation Plan

Status: Gate 12B planning completed.

## Scope

Gate 12B defines the operation policy for shortage `@everyone` reminders and
the scheduler/cron design for session reminders after the successful manual
`gm_confirmed` production send.

This is docs-only. No Discord send, real-send enablement, production
`dry_run:false`, claim/finalize execution, DB write, SQL apply, Edge deploy,
cron setup, secret change, UI change, or `updates.json` change was performed.

## Current State

Reached:

- one manual `gm_confirmed` production send succeeded
- `claimed_count:1`
- `sent_count:1`
- `failed_count:0`
- `skipped_count:0`
- `session_reminder_logs` count moved `0` -> `1`
- real send was disabled again after the manual send

Not reached:

- shortage reminder send
- `@everyone` send
- cron/scheduler auto execution
- reset/retry tooling for reminder logs

Current operation mode:

- manual dispatcher invocation only
- cron/scheduled invocation is not configured
- real send is expected to remain disabled unless a later explicit gate enables
  it for a bounded operation

## Shortage Reminder Policy

The shortage reminder is the only reminder type allowed to use `@everyone`.

Policy:

- keep shortage production sending behind the final independent approval gate
- require a fresh `dry_run:true` target-count check immediately before send
- require destination confirmation immediately before send
- require explicit `@everyone` approval immediately before send
- send only when the reminder type is `shortage`
- do not send shortage if the candidate count is `0`
- do not create a test send by forcing data into an unsafe state
- do not mix shortage send and GM reminder send in the same approval gate
- stop if any non-shortage item appears in a shortage-only operation
- stop if the candidate count is higher than the approved count
- record only status/counts and safe stages

Condition model:

- shortage reminder is only for sessions below minimum attendance
- the count basis remains the existing reminder RPC rule:
  pending + accepted counts toward the minimum
- waitlisted users are not counted for the initial minimum check unless a
  later SQL/design gate changes the rule
- canceled/deleted/past/already-started sessions remain outside the target set
  through the RPC filters

`@everyone` handling:

- `@everyone` appears only in shortage payload content
- `allowed_mentions.parse=["everyone"]` is used only for shortage
- GM reminders must continue using the GM user mention path and must not use
  `@everyone`
- shortage production is never bundled with cron setup or secret changes

If shortage candidates are `0`:

- do not enable real send
- do not run production `dry_run:false`
- do not mutate session data merely to manufacture an `@everyone` target
- record the zero-candidate result and stop

## Scheduler / Cron Design

Preferred mechanism:

- Supabase `pg_cron` + `pg_net`, matching the existing admin-cap announcement
  cron approach
- cron calls the deployed `dispatch-session-reminders` Edge Function
- the Function continues to own the reminder selection, claim, Discord send,
  and finalize flow

Cadence recommendation:

- every minute is the preferred cadence
- reason: reminder windows are tied to 30/60 minute and 1/2/3 hour offsets,
  and the dispatcher/claim log already prevents duplicates
- alternative: every 5 minutes if operational noise is a concern, accepting up
  to roughly 5 minutes of scheduling delay

Cron payload:

```json
{
  "dry_run": false,
  "limit": 1
}
```

Operational meaning:

- `limit:1` keeps each cron tick to one send attempt
- duplicate prevention is handled by `session_reminder_logs`
- repeated cron ticks should skip already-claimed/sent reminder types because
  of the `(session_id, reminder_type)` unique constraint
- if no due reminders exist, the dispatcher returns zero work

Authorization:

- cron must include the dispatch token header expected by the Edge Function
- token value must come from a secret/Vault reference, not inline SQL text
- docs and SQL review must record only secret names and boolean presence
- never paste token, Webhook URL, project ref, JWT, or provider ids into docs

Real-send flag:

- scheduler production operation requires real send to be enabled
- real send must not be enabled merely by creating cron SQL
- the first scheduler deployment should keep production disabled and confirm
  rejection behavior
- only after a separate approval gate should scheduler run with real send
  enabled

Webhook:

- cron does not need the Webhook URL directly
- the Edge Function reads `DISCORD_SESSION_REMINDER_WEBHOOK_URL`
- Webhook URL value stays in Edge Function secrets and is not recorded in docs

Function URL:

- cron should read the Function URL from Vault/secret or equivalent safe
  indirection
- do not inline Function URL if it exposes project-specific details in SQL
  review output

## Manual vs Automatic Operation

Manual dispatcher operation:

- suitable for one-off controlled tests
- operator checks `dry_run:true`
- operator explicitly toggles real send
- operator invokes production once
- operator disables real send immediately after
- records status/counts

Automatic scheduler operation:

- suitable only after cron apply/review gates
- cron invokes dispatcher on a fixed cadence
- real send remains an environment-level operational switch
- dispatcher claim/finalize and logs provide duplicate prevention
- operator monitors counts/statuses instead of manually selecting each send

Do not mix:

- cron setup with first shortage `@everyone` send
- real-send enablement with SQL apply
- secret setup with Discord send
- reset/retry tooling with normal scheduler operation

## Failure / Retry Policy

Initial scheduler policy:

- do not blindly retry by manually re-running production after a failure
- if the dispatcher returns a safe `stage`, record the stage and stop the
  current gate
- if a claim row exists with `failed` or `skipped`, keep it until a reset
  policy exists
- do not delete logs to force retry without a separate SQL gate
- do not change session settings to hide an ops failure

Duplicate prevention:

- `(session_id, reminder_type)` unique constraint prevents repeated sends for
  the same reminder type on the same session
- normal cron retries should not duplicate sent reminders
- if a reminder must be retried after an operational failure, use a future
  reset/retry policy gate

Recommended reset/retry future design:

- SELECT-only status review first
- SQL draft for a targeted reset or invalidation
- approval gate before any log mutation
- never bulk-delete reminder logs

## Remaining Tasks Before Production Automation

Before scheduler automation:

- write scheduler SQL draft
- write post-apply SELECT-only checklist
- decide secret/Vault names for Function URL and dispatch token references
- confirm real-send flag remains disabled after cron creation
- deploy/check no code changes are needed
- run production-disabled scheduler/runtime verification

Before GM automatic operation:

- confirm at least one safe GM candidate can be handled through scheduler
- keep `@everyone` out of GM reminder path
- verify logs increment only once
- confirm duplicate prevention in SELECT-only review

Before shortage operation:

- perform fresh `dry_run:true` shortage candidate count
- require exact target count approval
- confirm destination channel
- confirm `@everyone` approval
- use one-item or explicitly bounded count
- record only status/counts and safe stages
- stop on first unexpected result

## Next Gate Plan

Recommended gate split:

1. Gate 12C: scheduler SQL draft and post-apply SELECT-only checklist.
2. Gate 12D: scheduler SQL apply under explicit approval, production disabled.
3. Gate 12E: scheduler runtime production-disabled confirmation.
4. Gate 12F: GM automatic scheduler send test with bounded target count.
5. Gate 12G: shortage `@everyone` production planning only.
6. Gate 12H: shortage `@everyone` final approval and bounded production
   operation.

Keep shortage `@everyone` as the final, independent approval gate.

## Gate 12C SQL Draft Follow-up

Gate 12C added the scheduler SQL draft and post-apply checklist:

- `docs/sql-drafts/session-reminder-scheduler-draft.sql`
- `docs/session-reminder-scheduler-sql-checklist.md`

Draft design:

- cron job name: `dispatch-session-reminders-every-minute`
- scheduler mechanism: Supabase `pg_cron` + `pg_net`
- target Function: `dispatch-session-reminders`
- initial schedule: every minute (`* * * * *`)
- lower-noise alternative: every 5 minutes (`*/5 * * * *`)
- payload: `dry_run:false`, `limit:1`
- dispatch token header: `x-dispatch-token`
- Function URL, invoke JWT, and dispatch token are read from Supabase Vault
  secret names, not inline values

Vault secret names expected by the draft:

- `SESSION_REMINDER_FUNCTION_URL`
- `SESSION_REMINDER_INVOKE_JWT`
- `SESSION_REMINDER_DISPATCH_TOKEN`

Important boundary:

- creating cron does not enable real send by itself
- real send remains controlled by the Edge Function secret/env
  `SESSION_REMINDER_REAL_SEND_ENABLED`
- the first apply/runtime gate should keep real send disabled and confirm the
  dispatcher rejects production mode safely
- shortage `@everyone` remains a later independent approval gate

Gate 12C itself did not run SQL, create cron, invoke runtime, enable real send,
send Discord, write DB rows, deploy Edge Functions, change secrets, or change
`updates.json`.

## Not Performed

- Discord send
- Discord dry-run send
- `@everyone` send
- shortage send
- `SESSION_REMINDER_REAL_SEND_ENABLED` enablement
- production `dry_run:false`
- claim/finalize runtime execution
- DB write
- SQL Editor execution
- SQL apply
- DB/RPC/RLS structure change
- Edge deploy
- cron setup
- UI / HTML / CSS / browser JS change
- secret/Webhook setting or change
- `updates.json` change
