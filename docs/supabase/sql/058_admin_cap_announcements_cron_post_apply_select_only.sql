-- 058_admin_cap_announcements_cron_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION / NOT EXECUTED BY CODEX
--
-- Purpose:
-- - Confirm the cron job created by the reviewed admin cap announcement cron
--   apply gate.
-- - Return generalized check results only.
-- - Do not return Webhook URLs, JWTs, Supabase project URLs, Discord IDs,
--   token values, or full request headers.
--
-- Run policy:
-- - Run only after a separate explicit 057 cron SQL apply approval and
--   execution.
-- - This file itself must not change DB state.

with target_job as (
  select
    jobid,
    jobname,
    schedule,
    command,
    active
  from cron.job
  where jobname = 'dispatch-admin-cap-announcements-every-minute'
),
job_summary as (
  select
    count(*) as job_count,
    bool_or(active) as any_active,
    bool_or(schedule = '* * * * *') as has_expected_schedule,
    bool_or(command ilike '%dispatch-admin-cap-announcements%') as has_function_name,
    bool_or(command ilike '%net.http_post%') as uses_pg_net_http_post,
    bool_or(command ilike '%dry_run%' and command ilike '%false%') as has_dry_run_false,
    bool_or(command ilike '%batch_limit%' and command ilike '%1%') as has_batch_limit_one,
    bool_or(command ilike '%x-dispatch-token%') as has_dispatch_token_header,
    bool_or(command ilike '%Authorization%' and command ilike '%Bearer%') as has_authorization_header,
    bool_or(command ilike '%ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL%') as uses_vault_function_url,
    bool_or(command ilike '%ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT%') as uses_vault_invoke_jwt,
    bool_or(command ilike '%ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN%') as uses_vault_dispatch_token,
    bool_or(command ~* 'discord(app)?\.com/api/webhooks') as has_webhook_url_pattern,
    bool_or(command ~* 'https://[a-z0-9.-]+\.supabase\.co') as has_supabase_url_pattern,
    bool_or(command ~* 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+') as has_jwt_pattern
  from target_job
),
checks as (
  select
    10 as sort_order,
    'cron_job_exists'::text as check_name,
    case when js.job_count = 1 then 'ok' else 'missing' end as status,
    js.job_count::text as result_value,
    'exactly one cron job should exist for the admin cap announcement dispatcher'::text as note
  from job_summary js

  union all
  select
    20,
    'cron_job_name',
    case when exists (
      select 1 from target_job where jobname = 'dispatch-admin-cap-announcements-every-minute'
    ) then 'ok' else 'missing' end,
    coalesce((select jobname from target_job limit 1), ''),
    'job name should be dispatch-admin-cap-announcements-every-minute'

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
    'function_target',
    case when js.has_function_name and js.uses_pg_net_http_post then 'ok' else 'review' end,
    concat(
      'function=', coalesce(js.has_function_name, false),
      ',pg_net=', coalesce(js.uses_pg_net_http_post, false)
    ),
    'command should call dispatch-admin-cap-announcements through pg_net'
  from job_summary js

  union all
  select
    60,
    'payload_dry_run_false',
    case when js.has_dry_run_false then 'ok' else 'review' end,
    coalesce(js.has_dry_run_false::text, 'false'),
    'cron payload should be real-send mode only after explicit cron apply approval'
  from job_summary js

  union all
  select
    70,
    'payload_batch_limit_one',
    case when js.has_batch_limit_one then 'ok' else 'review' end,
    coalesce(js.has_batch_limit_one::text, 'false'),
    'cron payload must keep batch_limit=1 to avoid unexpected multi-posting'
  from job_summary js

  union all
  select
    80,
    'authorization_headers',
    case when js.has_authorization_header and js.has_dispatch_token_header then 'ok' else 'review' end,
    concat(
      'authorization=', coalesce(js.has_authorization_header, false),
      ',dispatch_token=', coalesce(js.has_dispatch_token_header, false)
    ),
    'command should send platform Authorization and x-dispatch-token headers without returning values'
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
    'no_inline_secret_patterns',
    case
      when not coalesce(js.has_webhook_url_pattern, false)
       and not coalesce(js.has_supabase_url_pattern, false)
       and not coalesce(js.has_jwt_pattern, false)
      then 'ok' else 'review'
    end,
    concat(
      'webhook_url=', coalesce(js.has_webhook_url_pattern, false),
      ',supabase_url=', coalesce(js.has_supabase_url_pattern, false),
      ',jwt=', coalesce(js.has_jwt_pattern, false)
    ),
    'command should not inline Webhook URLs, Supabase URLs, or JWT-like values'
  from job_summary js
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by sort_order;
