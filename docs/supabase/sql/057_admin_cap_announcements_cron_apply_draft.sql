-- 057_admin_cap_announcements_cron_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- CRON APPLY DRAFT ONLY
--
-- Purpose:
-- - Schedule the deployed Edge Function dispatch-admin-cap-announcements.
-- - This is for admin-only Discord cap update announcements.
-- - This is not a general reminder scheduler.
--
-- Danger:
-- - Running this SQL can start automatic Discord posting.
-- - Apply only after a separate explicit cron SQL Apply approval.
-- - Run once only; if an error appears, stop and do not rerun blindly.
--
-- Required secret handling:
-- - Do not paste Webhook URLs, JWTs, Supabase project URLs, Discord IDs, or
--   token values into this file.
-- - This draft expects the following Supabase Vault secret names to exist
--   before apply:
--   - ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL
--   - ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT
--   - ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN
-- - ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL should contain the full deployed
--   function invoke URL for dispatch-admin-cap-announcements.
-- - ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT should be a JWT accepted by Supabase
--   Edge Function platform verification.
-- - ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN should match the Edge Function
--   secret ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN.
--
-- Cron policy:
-- - Initial schedule: every 1 minute.
-- - Reason: cap update announcements are time-sensitive enough that a 1-minute
--   delay is acceptable and keeps the dispatcher simple.
-- - Safety limiter: payload always uses dry_run=false and batch_limit=1.
-- - Alternative schedule for lower traffic: every 5 minutes using */5 * * * *.

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
      ('ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL'),
      ('ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT'),
      ('ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN')
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
    where jobname = 'dispatch-admin-cap-announcements-every-minute'
  ) then
    perform cron.unschedule('dispatch-admin-cap-announcements-every-minute');
  end if;
end;
$$;

select cron.schedule(
  'dispatch-admin-cap-announcements-every-minute',
  '* * * * *',
  $cron$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'ADMIN_CAP_ANNOUNCEMENT_FUNCTION_URL'
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT'
      ),
      'apikey', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'ADMIN_CAP_ANNOUNCEMENT_INVOKE_JWT'
      ),
      'x-dispatch-token', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN'
      )
    ),
    body := jsonb_build_object(
      'dry_run', false,
      'batch_limit', 1
    ),
    timeout_milliseconds := 10000
  ) as request_id;
  $cron$
);

commit;
