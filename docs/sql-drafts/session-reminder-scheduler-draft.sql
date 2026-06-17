-- session-reminder-scheduler-draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- CRON APPLY DRAFT ONLY.
--
-- Purpose:
-- - Schedule the deployed Edge Function dispatch-session-reminders.
-- - This scheduler is for session reminder dispatch only.
-- - It is not a general Discord scheduler.
--
-- Danger:
-- - Running this SQL creates an active cron job.
-- - The cron job invokes dispatch-session-reminders with dry_run=false.
-- - Discord send still depends on SESSION_REMINDER_REAL_SEND_ENABLED inside
--   the Edge Function, but cron creation and real-send enablement must remain
--   separate approval gates.
-- - Apply only after a separate explicit cron SQL Apply approval.
-- - If any error appears, stop and do not rerun blindly.
--
-- Required secret handling:
-- - Do not paste Webhook URLs, JWTs, Supabase project URLs, Discord IDs, or
--   token values into this file.
-- - This draft expects the following Supabase Vault secret names to exist
--   before apply:
--   - SESSION_REMINDER_FUNCTION_URL
--   - SESSION_REMINDER_INVOKE_JWT
--   - SESSION_REMINDER_DISPATCH_TOKEN
-- - SESSION_REMINDER_FUNCTION_URL should contain the full deployed Function
--   invoke URL for dispatch-session-reminders.
-- - SESSION_REMINDER_INVOKE_JWT should be a JWT accepted by Supabase Edge
--   Function platform verification.
-- - SESSION_REMINDER_DISPATCH_TOKEN should match the Edge Function secret
--   SESSION_REMINDER_DISPATCH_TOKEN.
--
-- Cron policy:
-- - Initial schedule: every 1 minute, aligned with the existing
--   dispatch-admin-cap-announcements scheduled-post cron.
-- - Lower-noise alternative: every 5 minutes using */5 * * * *.
-- - The 5-minute option is fallback only; every minute is preferred for
--   parity with existing scheduled posts.
-- - Safety limiter: payload uses dry_run=false and limit=1.
-- - The admin dispatcher uses batch_limit=1; this dispatcher expects limit=1.
-- - Shortage @everyone production operation remains a later independent gate.
--
-- Rollback / stop plan, for a later explicit rollback gate only:
--   select cron.unschedule('dispatch-session-reminders-every-minute');

begin;

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
declare
  missing_secret_names text[];
begin
  select array_agg(required_name order by required_name)
    into missing_secret_names
  from (
    values
      ('SESSION_REMINDER_FUNCTION_URL'),
      ('SESSION_REMINDER_INVOKE_JWT'),
      ('SESSION_REMINDER_DISPATCH_TOKEN')
  ) as required(required_name)
  where not exists (
    select 1
    from vault.decrypted_secrets s
    where s.name = required.required_name
      and nullif(btrim(s.decrypted_secret), '') is not null
  );

  if coalesce(array_length(missing_secret_names, 1), 0) > 0 then
    raise exception 'missing_required_vault_secret: %', array_to_string(missing_secret_names, ', ');
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'dispatch-session-reminders-every-minute'
  ) then
    perform cron.unschedule('dispatch-session-reminders-every-minute');
  end if;
end;
$$;

select cron.schedule(
  'dispatch-session-reminders-every-minute',
  '* * * * *',
  $cron$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'SESSION_REMINDER_FUNCTION_URL'
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'SESSION_REMINDER_INVOKE_JWT'
      ),
      'apikey', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'SESSION_REMINDER_INVOKE_JWT'
      ),
      'x-dispatch-token', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'SESSION_REMINDER_DISPATCH_TOKEN'
      )
    ),
    body := jsonb_build_object(
      'dry_run', false,
      'limit', 1
    ),
    timeout_milliseconds := 10000
  ) as request_id;
  $cron$
);

commit;

-- Post-apply SELECT-only checks are documented in:
-- docs/session-reminder-scheduler-sql-checklist.md
