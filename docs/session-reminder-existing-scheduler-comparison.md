# Session Reminder Existing Scheduler Comparison

Status: Gate 12E comparison completed. No SQL apply, cron creation, runtime
invoke, Discord send, DB write, secret change, or Edge deploy was performed.

## Purpose

Before applying the session reminder scheduler SQL, Gate 12E compares it with
the existing admin scheduled Discord post mechanism and aligns the reminder
scheduler with that proven pattern.

Reviewed files:

- `docs/supabase/sql/057_admin_cap_announcements_cron_apply_draft.sql`
- `docs/supabase/sql/058_admin_cap_announcements_cron_post_apply_select_only.sql`
- `supabase/functions/dispatch-admin-cap-announcements/index.ts`
- `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql`
- `docs/sql-drafts/session-reminder-scheduler-draft.sql`
- `docs/session-reminder-scheduler-sql-checklist.md`
- `supabase/functions/dispatch-session-reminders/index.ts`

## Existing Admin Scheduled Post Mechanism

The admin scheduled post mechanism uses:

- Supabase `pg_cron`
- Supabase `pg_net`
- a deployed Edge Function: `dispatch-admin-cap-announcements`
- cron job name: `dispatch-admin-cap-announcements-every-minute`
- schedule: `* * * * *`
- payload: `dry_run:false`, `batch_limit:1`
- Vault secret references for Function URL, invoke JWT, and dispatch token
- `x-dispatch-token` header
- Edge-side real-send flag:
  `ADMIN_CAP_ANNOUNCEMENT_REAL_SEND_ENABLED`
- service-role-only claim/finalize RPCs

The cron command reads these values from Supabase Vault secret names:

- `ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL`
- `ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT`
- `ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN`

No Webhook URL, JWT value, Supabase project URL, dispatch token, Discord ID,
provider message id, or response body is written into the cron SQL or docs.

## Why One-Minute Scheduled Posting Works

The admin scheduler achieves roughly one-minute-later posting because:

- cron runs once per minute
- each tick calls the dispatcher with `dry_run:false`
- the claim RPC selects rows where `scheduled_at <= now()`
- the claim RPC also respects `next_attempt_at`
- due rows are ordered by `scheduled_at` / creation time
- `batch_limit:1` keeps each tick to one claimed post
- `for update skip locked` and status transition to `processing` prevent
  concurrent double-claiming
- `lock_token` is required for finalize
- finalize marks successful posts as `posted`
- retryable failures can be moved back to `scheduled` with `next_attempt_at`
- final failures become `failed`

The practical behavior is: a post scheduled one minute in the future is picked
up by the first cron tick after its scheduled timestamp. The exact wall-clock
delay can be up to roughly one cron interval.

## Existing Duplicate Prevention And Failure Handling

Admin scheduled posts:

- claim due rows through `claim_due_admin_discord_announcements`
- move rows from `scheduled` to `processing`
- set a `lock_token`
- increment `attempt_count`
- finalize with `finalize_admin_discord_announcement`
- on success: status `posted`
- on retryable failure: status `scheduled` with `next_attempt_at`
- on terminal failure: status `failed`

This model owns retries inside the announcement table.

Session reminders:

- claim due reminders through `claim_due_session_reminders`
- insert rows into `session_reminder_logs`
- use status `claimed`, then `sent` / `failed` / `skipped`
- require `lock_token` for finalize
- prevent duplicates through
  `session_reminder_logs_unique_session_type`
- keep retry/reset as a separate future SQL gate

This model owns duplicate prevention in a reminder log table and does not
automatically retry failed/skipped rows in the initial design.

## Session Reminder Scheduler Alignment

The current session reminder scheduler draft is aligned with the admin pattern:

| Area | Admin scheduled posts | Session reminders |
| --- | --- | --- |
| Scheduler | `pg_cron` | `pg_cron` |
| HTTP caller | `pg_net.http_post` | `pg_net.http_post` |
| Cadence | every minute | every minute |
| Function URL | Vault secret | Vault secret |
| Invoke JWT | Vault secret | Vault secret |
| Dispatch token | Vault secret + `x-dispatch-token` | Vault secret + `x-dispatch-token` |
| Real-send gate | Edge env flag | Edge env flag |
| Batch limiter | `batch_limit:1` | `limit:1` |
| Duplicate prevention | DB claim status + lock token | reminder log unique constraint + lock token |
| Post-apply checks | status/count style | status/count style |

The payload key differs intentionally:

- admin dispatcher expects `batch_limit`
- session reminder dispatcher expects `limit`

No functional SQL change was required in Gate 12E.

## Cadence Decision

Every minute remains the primary scheduler cadence.

Reason:

- it matches the existing scheduled post mechanism
- it supports "about one minute after due" behavior
- the dispatcher limit and DB-side duplicate prevention keep work bounded

The 5-minute cadence remains only a lower-noise fallback and should not be the
default for initial parity with existing scheduled posts.

## Reminder Draft Review Result

Reviewed draft:

- `docs/sql-drafts/session-reminder-scheduler-draft.sql`

Result:

- cron job name is distinct:
  `dispatch-session-reminders-every-minute`
- schedule is every minute
- Function target is `dispatch-session-reminders`
- `pg_net.http_post` is used
- Vault secret names are reminder-specific:
  - `SESSION_REMINDER_FUNCTION_URL`
  - `SESSION_REMINDER_INVOKE_JWT`
  - `SESSION_REMINDER_DISPATCH_TOKEN`
- payload is `dry_run:false`, `limit:1`
- Webhook URL is not referenced by cron SQL
- real-send flag is not set by cron SQL
- shortage `@everyone` remains separate from scheduler apply

Draft adjustment:

- added comments/docs to explicitly record alignment with the existing admin
  scheduled post mechanism
- no runtime SQL behavior was changed

## Next Gate

Recommended next gate:

- Gate 12F: scheduler SQL apply under explicit approval while real send remains
  disabled.

Gate 12F should:

- stop if required Vault secrets are missing
- create no shortage `@everyone` send
- keep real send disabled
- record only status/count style results

## Not Performed

- SQL Editor execution
- SQL apply
- cron creation
- runtime invocation
- production `dry_run:false`
- claim/finalize runtime execution
- DB write
- Discord send
- `@everyone` send
- `SESSION_REMINDER_REAL_SEND_ENABLED` enablement
- Edge deploy
- DB/RPC/RLS structure change
- secret/Webhook setting or change
- UI / HTML / CSS / browser JS change
- `updates.json` change
- raw Function URL / JWT / token / Webhook / Discord ID / message id recording
