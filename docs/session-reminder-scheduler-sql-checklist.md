# Session Reminder Scheduler SQL Checklist

Status: Gate 12D Vault preparation documented. SQL not applied.

## Scope

This checklist is for the future scheduler SQL apply gate that will create a
cron job for `dispatch-session-reminders`.

It is SELECT-only except for the separately approved apply draft:

- apply draft: `docs/sql-drafts/session-reminder-scheduler-draft.sql`
- cron job name: `dispatch-session-reminders-every-minute`
- expected cadence: every 1 minute
- lower-noise alternative: every 5 minutes
- expected Function: `dispatch-session-reminders`
- expected payload: `dry_run:false`, `limit:1`

Gate 12C did not run SQL, apply cron, invoke the Edge Function, enable real
send, send Discord, write DB rows, change secrets, deploy Edge Functions, or
change `updates.json`.

Gate 12D documented the Vault boundary and setup procedure, but did not query
or change Vault secret values.

Result doc:

- `docs/session-reminder-scheduler-vault-secret-result.md`

## Gate 12D Vault Prep Result

The scheduler draft and this checklist are aligned on these required Vault
secret names:

- `SESSION_REMINDER_FUNCTION_URL`
- `SESSION_REMINDER_INVOKE_JWT`
- `SESSION_REMINDER_DISPATCH_TOKEN`

Confirmed by file review:

- `SESSION_REMINDER_FUNCTION_URL` is the Function URL source for
  `dispatch-session-reminders`.
- `SESSION_REMINDER_INVOKE_JWT` is used for the platform `Authorization` and
  `apikey` headers.
- `SESSION_REMINDER_DISPATCH_TOKEN` is used for the `x-dispatch-token` header.
- `DISCORD_SESSION_REMINDER_WEBHOOK_URL` remains an Edge Function secret/env
  and is not read by cron SQL.
- `SESSION_REMINDER_REAL_SEND_ENABLED=true` is not set by the scheduler draft.

Actual Vault existence and values were not checked by Codex in Gate 12D.
Future confirmation must be SELECT-only and value-redacted.

## Apply Before Checklist

Before any later apply gate:

- Confirm `dispatch-session-reminders` is already deployed.
- Confirm production disabled behavior was checked after the latest deploy.
- Confirm `SESSION_REMINDER_REAL_SEND_ENABLED` is not enabled unless the gate
  explicitly allows production send.
- Confirm Supabase Vault contains nonempty secret names:
  - `SESSION_REMINDER_FUNCTION_URL`
  - `SESSION_REMINDER_INVOKE_JWT`
  - `SESSION_REMINDER_DISPATCH_TOKEN`
- Confirm `SESSION_REMINDER_DISPATCH_TOKEN` in Vault matches the Edge Function
  secret of the same name.
- Do not paste Webhook URL, token, JWT, Supabase project URL, Discord ID,
  session id, or message id values into SQL, docs, or reports.
- If apply errors, stop and do not rerun blindly.

## Post-Apply SELECT-Only Checks

Run only after a separately approved scheduler SQL apply.

Do not run these in Gate 12C.

```sql
-- SELECT ONLY / NO MUTATION / NOT EXECUTED BY CODEX
--
-- Purpose:
-- - Confirm the session reminder cron job created by the reviewed scheduler
--   apply gate.
-- - Return generalized check results only.
-- - Do not return Webhook URLs, JWTs, Supabase project URLs, Discord IDs,
--   token values, full request headers, or response bodies.

with target_job as (
  select
    jobid,
    jobname,
    schedule,
    command,
    active
  from cron.job
  where jobname = 'dispatch-session-reminders-every-minute'
),
job_summary as (
  select
    count(*) as job_count,
    bool_or(active) as any_active,
    bool_or(schedule = '* * * * *') as has_expected_schedule,
    bool_or(jobname = 'dispatch-session-reminders-every-minute') as has_expected_jobname,
    bool_or(command ilike '%net.http_post%') as uses_pg_net_http_post,
    bool_or(command ilike '%dry_run%' and command ilike '%false%') as has_dry_run_false,
    bool_or(command ilike '%limit%' and command ilike '%1%') as has_limit_one,
    bool_or(command ilike '%x-dispatch-token%') as has_dispatch_token_header,
    bool_or(command ilike '%Authorization%' and command ilike '%Bearer%') as has_authorization_header,
    bool_or(command ilike '%apikey%') as has_apikey_header,
    bool_or(command ilike '%SESSION_REMINDER_FUNCTION_URL%') as uses_vault_function_url,
    bool_or(command ilike '%SESSION_REMINDER_INVOKE_JWT%') as uses_vault_invoke_jwt,
    bool_or(command ilike '%SESSION_REMINDER_DISPATCH_TOKEN%') as uses_vault_dispatch_token,
    bool_or(command ~* 'discord(app)?\.com/api/webhooks') as has_webhook_url_pattern,
    bool_or(command ~* 'https://[a-z0-9.-]+\.supabase\.co') as has_supabase_url_pattern,
    bool_or(command ~* 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+') as has_jwt_pattern,
    bool_or(command ~* '<@[0-9]{17,20}>') as has_discord_mention_pattern
  from target_job
),
vault_summary as (
  select
    count(*) filter (
      where name in (
        'SESSION_REMINDER_FUNCTION_URL',
        'SESSION_REMINDER_INVOKE_JWT',
        'SESSION_REMINDER_DISPATCH_TOKEN'
      )
      and nullif(btrim(decrypted_secret), '') is not null
    ) as nonempty_required_secret_count
  from vault.decrypted_secrets
),
checks as (
  select
    10 as sort_order,
    'cron_job_exists'::text as check_name,
    case when js.job_count = 1 then 'ok' else 'missing' end as status,
    js.job_count::text as result_value,
    'exactly one cron job should exist for the session reminder dispatcher'::text as note
  from job_summary js

  union all
  select
    20,
    'cron_job_name',
    case when js.has_expected_jobname then 'ok' else 'missing' end,
    coalesce((select jobname from target_job limit 1), ''),
    'job name should be dispatch-session-reminders-every-minute'
  from job_summary js

  union all
  select
    30,
    'cron_schedule',
    case when js.has_expected_schedule then 'ok' else 'review' end,
    coalesce((select schedule from target_job limit 1), ''),
    'initial schedule should be every 1 minute; 5 minutes is the documented alternative'
  from job_summary js

  union all
  select
    40,
    'cron_job_active',
    case when js.any_active then 'ok' else 'review' end,
    coalesce(js.any_active::text, 'false'),
    'cron job should be active after the apply gate'
  from job_summary js

  union all
  select
    50,
    'pg_net_target',
    case when js.uses_pg_net_http_post then 'ok' else 'review' end,
    coalesce(js.uses_pg_net_http_post::text, 'false'),
    'command should call the Edge Function through pg_net.http_post'
  from job_summary js

  union all
  select
    60,
    'payload_dry_run_false',
    case when js.has_dry_run_false then 'ok' else 'review' end,
    coalesce(js.has_dry_run_false::text, 'false'),
    'cron payload should use dry_run=false only after explicit cron apply approval'
  from job_summary js

  union all
  select
    70,
    'payload_limit_one',
    case when js.has_limit_one then 'ok' else 'review' end,
    coalesce(js.has_limit_one::text, 'false'),
    'cron payload must keep limit=1 to avoid unexpected multi-posting'
  from job_summary js

  union all
  select
    80,
    'authorization_headers',
    case
      when js.has_authorization_header and js.has_apikey_header and js.has_dispatch_token_header
      then 'ok' else 'review'
    end,
    concat(
      'authorization=', coalesce(js.has_authorization_header, false),
      ',apikey=', coalesce(js.has_apikey_header, false),
      ',dispatch_token=', coalesce(js.has_dispatch_token_header, false)
    ),
    'command should send platform auth headers and x-dispatch-token without returning values'
  from job_summary js

  union all
  select
    90,
    'vault_secret_references',
    case
      when js.uses_vault_function_url
       and js.uses_vault_invoke_jwt
       and js.uses_vault_dispatch_token
      then 'ok' else 'review'
    end,
    concat(
      'function_url=', coalesce(js.uses_vault_function_url, false),
      ',invoke_jwt=', coalesce(js.uses_vault_invoke_jwt, false),
      ',dispatch_token=', coalesce(js.uses_vault_dispatch_token, false)
    ),
    'command should reference Vault secret names rather than inline secret values'
  from job_summary js

  union all
  select
    100,
    'vault_secret_presence',
    case when vs.nonempty_required_secret_count = 3 then 'ok' else 'review' end,
    vs.nonempty_required_secret_count::text,
    'three required Vault secrets should exist and be nonempty; values must not be returned'
  from vault_summary vs

  union all
  select
    110,
    'no_inline_secret_patterns',
    case
      when not coalesce(js.has_webhook_url_pattern, false)
       and not coalesce(js.has_supabase_url_pattern, false)
       and not coalesce(js.has_jwt_pattern, false)
       and not coalesce(js.has_discord_mention_pattern, false)
      then 'ok' else 'review'
    end,
    concat(
      'webhook_url=', coalesce(js.has_webhook_url_pattern, false),
      ',supabase_url=', coalesce(js.has_supabase_url_pattern, false),
      ',jwt=', coalesce(js.has_jwt_pattern, false),
      ',discord_mention=', coalesce(js.has_discord_mention_pattern, false)
    ),
    'command should not inline Webhook URLs, Supabase URLs, JWT-like values, or Discord mentions'
  from job_summary js
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by sort_order;
```

## pg_net Response / Log Check Policy

After a future cron apply, wait for at least one scheduled tick before checking
pg_net response metadata.

Use status/count summaries only. Do not paste response body, request headers,
Function URL, token, JWT, Webhook URL, Discord ID, session id, or message body.

Suggested optional check, if the project exposes `net._http_response`:

```sql
-- SELECT ONLY / OPTIONAL / RESPONSE BODY MUST NOT BE COPIED INTO DOCS
select
  status_code,
  count(*) as response_count
from net._http_response
where created > now() - interval '10 minutes'
group by status_code
order by status_code;
```

Expected first scheduler apply behavior:

- If real send is still disabled, `dry_run:false` should be rejected by the
  Edge Function production gate.
- That rejection is expected during production-disabled scheduler confirmation.
- `session_reminder_logs` should not increase while production is disabled.
- Discord should not receive any message.

## Unschedule / Rollback Draft

Use only in a later explicit rollback gate:

```sql
-- MUTATION / ROLLBACK GATE ONLY / DO NOT RUN IN GATE 12C
select cron.unschedule('dispatch-session-reminders-every-minute');
```

After unschedule, verify with SELECT-only:

```sql
-- SELECT ONLY
select
  count(*) as matching_job_count
from cron.job
where jobname = 'dispatch-session-reminders-every-minute';
```

## Next Gate

Recommended next gate:

- Gate 12E: apply the scheduler SQL under explicit approval while real send
  remains disabled.

If required Vault secrets are missing, stop before cron creation and record the
missing secret names only.
