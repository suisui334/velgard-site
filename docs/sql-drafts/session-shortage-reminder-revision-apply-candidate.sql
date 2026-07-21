-- APPLY CANDIDATE ONLY.
-- Do not run automatically.
-- Paste into Supabase SQL Editor only after explicit user approval.
-- If any error occurs, stop and do not re-run blindly.
--
-- Purpose:
-- - Allow a shortage reminder to be sent again after its schedule-relevant
--   session fields change.
-- - Keep one claim/send attempt per session and shortage revision.
-- - Keep gm_confirmed duplicate prevention at one log per session.
-- - Return the exact shortage revision selected by preview so claim cannot
--   mix an old schedule snapshot with a newer session revision.
-- - Append the revision column to the existing return shapes. The deployed
--   Edge Function ignores unknown response fields, so SQL can be applied
--   before an optional TypeScript contract-alignment gate.
--
-- This file is not a migration and must remain under docs/sql-drafts.
-- It does not configure cron, secrets, Discord, or Edge Functions.

begin;

-- ============================================================
-- 1. Session-side shortage revision
-- ============================================================

alter table public.sessions
  add column if not exists shortage_reminder_revision integer not null default 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.sessions'::regclass
      and conname = 'sessions_shortage_reminder_revision_check'
  ) then
    alter table public.sessions
      add constraint sessions_shortage_reminder_revision_check
      check (shortage_reminder_revision >= 1);
  end if;
end;
$$;

comment on column public.sessions.shortage_reminder_revision is
  'Version for shortage reminder duplicate prevention. Incremented only when date, start_time, shortage reminder enabled state, or shortage reminder offset changes.';

create or replace function public.bump_session_shortage_reminder_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.date is distinct from new.date
    or old.start_time is distinct from new.start_time
    or old.shortage_reminder_enabled is distinct from new.shortage_reminder_enabled
    or old.shortage_reminder_hours_before is distinct from new.shortage_reminder_hours_before
  then
    new.shortage_reminder_revision := greatest(coalesce(old.shortage_reminder_revision, 1), 1) + 1;
  else
    -- Do not allow unrelated updates or direct assignments to mutate the
    -- revision. All revision changes are derived from the four fields above.
    new.shortage_reminder_revision := greatest(coalesce(old.shortage_reminder_revision, 1), 1);
  end if;

  return new;
end;
$$;

revoke all on function public.bump_session_shortage_reminder_revision() from public;
revoke all on function public.bump_session_shortage_reminder_revision() from anon;
revoke all on function public.bump_session_shortage_reminder_revision() from authenticated;

drop trigger if exists sessions_shortage_reminder_revision_trigger on public.sessions;

create trigger sessions_shortage_reminder_revision_trigger
before update on public.sessions
for each row
execute function public.bump_session_shortage_reminder_revision();

-- ============================================================
-- 2. Log-side revision and duplicate keys
-- ============================================================

alter table public.session_reminder_logs
  add column if not exists shortage_reminder_revision integer;

-- Existing shortage logs represent the current revision at rollout. This
-- avoids an immediate resend merely because the schema was applied.
update public.session_reminder_logs as l
set shortage_reminder_revision = s.shortage_reminder_revision
from public.sessions as s
where l.session_id = s.id
  and l.reminder_type = 'shortage'
  and l.shortage_reminder_revision is null;

-- GM reminder rows do not participate in shortage revisioning.
update public.session_reminder_logs
set shortage_reminder_revision = null
where reminder_type = 'gm_confirmed'
  and shortage_reminder_revision is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.session_reminder_logs'::regclass
      and conname = 'session_reminder_logs_shortage_revision_check'
  ) then
    alter table public.session_reminder_logs
      add constraint session_reminder_logs_shortage_revision_check
      check (
        (reminder_type = 'shortage' and shortage_reminder_revision is not null and shortage_reminder_revision >= 1)
        or
        (reminder_type = 'gm_confirmed' and shortage_reminder_revision is null)
      );
  end if;
end;
$$;

-- Create the replacement unique indexes before removing the old broad key.
-- Existing data already satisfies the stricter per-type indexes because the
-- old constraint allowed at most one row per session/reminder type.
create unique index if not exists session_reminder_logs_shortage_revision_unique
  on public.session_reminder_logs (
    session_id,
    reminder_type,
    shortage_reminder_revision
  )
  where reminder_type = 'shortage';

create unique index if not exists session_reminder_logs_gm_confirmed_unique
  on public.session_reminder_logs (session_id, reminder_type)
  where reminder_type = 'gm_confirmed';

alter table public.session_reminder_logs
  drop constraint if exists session_reminder_logs_unique_session_type;

comment on column public.session_reminder_logs.shortage_reminder_revision is
  'Shortage revision claimed by this log row. Null for gm_confirmed reminders.';

comment on index public.session_reminder_logs_shortage_revision_unique is
  'Prevents duplicate shortage claims for the same session revision while allowing later revisions.';

comment on index public.session_reminder_logs_gm_confirmed_unique is
  'Preserves the original one-log-per-session behavior for gm_confirmed reminders.';

-- ============================================================
-- 3. Preview RPC
-- ============================================================
-- The return type gains one final integer column. PostgreSQL cannot change a
-- RETURNS TABLE shape with CREATE OR REPLACE, so claim is dropped first and
-- preview second. CASCADE is intentionally not used.

drop function if exists public.claim_due_session_reminders(timestamptz, integer);
drop function if exists public.preview_due_session_reminders(timestamptz, integer);

create function public.preview_due_session_reminders(
  p_now timestamptz default now(),
  p_limit integer default 50
)
returns table (
  session_id text,
  reminder_type text,
  title text,
  start_at timestamptz,
  min_players integer,
  pending_count integer,
  accepted_count integer,
  waitlisted_count integer,
  count_for_minimum integer,
  shortage_count integer,
  gm_display_name text,
  gm_discord_user_id text,
  reminder_offset_minutes integer,
  target_channel_key text,
  session_public_id text,
  scheduled_for timestamptz,
  shortage_reminder_revision integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  return query
  with app_counts as (
    select
      sa.session_id,
      count(distinct sa.user_id) filter (where sa.status = 'pending')::integer as pending_count,
      count(distinct sa.user_id) filter (where sa.status = 'accepted')::integer as accepted_count,
      count(distinct sa.user_id) filter (where sa.status = 'waitlisted')::integer as waitlisted_count
    from public.session_applications as sa
    where sa.status in ('pending', 'accepted', 'waitlisted')
    group by sa.session_id
  ),
  base_sessions as (
    select
      s.id,
      s.title,
      (s.date + s.start_time)::timestamp at time zone 'Asia/Tokyo' as start_at,
      s.player_min,
      coalesce(ac.pending_count, 0) as pending_count,
      coalesce(ac.accepted_count, 0) as accepted_count,
      coalesce(ac.waitlisted_count, 0) as waitlisted_count,
      coalesce(nullif(btrim(s.gm_name), ''), 'GM') as gm_display_name,
      case
        when nullif(btrim(gm_profile.discord_handle), '') ~ '^[0-9]{17,20}$'
          then nullif(btrim(gm_profile.discord_handle), '')::text
        else null::text
      end as gm_discord_user_id,
      s.status,
      s.visibility,
      s.application_deadline,
      s.shortage_reminder_enabled,
      s.shortage_reminder_hours_before,
      s.shortage_reminder_revision,
      s.gm_reminder_enabled,
      s.gm_reminder_minutes_before
    from public.sessions as s
    left join app_counts as ac on ac.session_id = s.id
    left join public.profiles as gm_profile on gm_profile.id = s.gm_user_id
    where s.visibility = 'public'
      and s.start_time is not null
      and s.player_min is not null
      and s.player_min > 0
  ),
  candidate_types(reminder_type) as (
    values
      ('shortage'::text),
      ('gm_confirmed'::text)
  ),
  candidates as (
    select
      b.id as session_id,
      ct.reminder_type,
      b.title,
      b.start_at,
      b.player_min as min_players,
      b.pending_count,
      b.accepted_count,
      b.waitlisted_count,
      (b.pending_count + b.accepted_count)::integer as count_for_minimum,
      case
        when ct.reminder_type = 'shortage'
          then greatest(b.player_min - (b.pending_count + b.accepted_count), 0)::integer
        else 0::integer
      end as shortage_count,
      b.gm_display_name,
      case
        when ct.reminder_type = 'gm_confirmed' then b.gm_discord_user_id
        else null::text
      end as gm_discord_user_id,
      case
        when ct.reminder_type = 'shortage'
          then (b.shortage_reminder_hours_before * 60)::integer
        else b.gm_reminder_minutes_before::integer
      end as reminder_offset_minutes,
      'session_reminder'::text as target_channel_key,
      b.id as session_public_id,
      b.start_at as scheduled_for,
      case
        when ct.reminder_type = 'shortage' then b.shortage_reminder_revision
        else null::integer
      end as shortage_reminder_revision
    from base_sessions as b
    cross join candidate_types as ct
    where b.start_at > p_now
      and (
        (
          ct.reminder_type = 'shortage'
          and b.shortage_reminder_enabled = true
          and b.shortage_reminder_hours_before in (1, 2, 3)
          and b.status in ('tentative', 'recruiting')
          and (b.start_at - make_interval(mins => b.shortage_reminder_hours_before * 60)) <= p_now
          and (
            b.application_deadline is null
            or b.application_deadline > p_now
          )
          and (b.pending_count + b.accepted_count) < b.player_min
        )
        or
        (
          ct.reminder_type = 'gm_confirmed'
          and b.gm_reminder_enabled = true
          and b.gm_reminder_minutes_before in (30, 60)
          and b.status in ('tentative', 'recruiting', 'full')
          and (b.start_at - make_interval(mins => b.gm_reminder_minutes_before)) <= p_now
          and (b.pending_count + b.accepted_count) >= b.player_min
        )
      )
  )
  select
    c.session_id,
    c.reminder_type,
    c.title,
    c.start_at,
    c.min_players,
    c.pending_count,
    c.accepted_count,
    c.waitlisted_count,
    c.count_for_minimum,
    c.shortage_count,
    c.gm_display_name,
    c.gm_discord_user_id,
    c.reminder_offset_minutes,
    c.target_channel_key,
    c.session_public_id,
    c.scheduled_for,
    c.shortage_reminder_revision
  from candidates as c
  where not exists (
    select 1
    from public.session_reminder_logs as l
    where l.session_id = c.session_id
      and l.reminder_type = c.reminder_type
      and l.status in ('claimed', 'sent', 'failed', 'skipped')
      and (
        (
          c.reminder_type = 'shortage'
          and l.shortage_reminder_revision = c.shortage_reminder_revision
        )
        or c.reminder_type = 'gm_confirmed'
      )
  )
  order by c.scheduled_for, c.session_id, c.reminder_type
  limit v_limit;
end;
$$;

revoke all on function public.preview_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.preview_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.preview_due_session_reminders(timestamptz, integer) is
  'Service-role preview for due session reminders. Shortage duplicate checks use the current session shortage revision; gm_confirmed remains one log per session.';

-- ============================================================
-- 4. Claim RPC
-- ============================================================
-- The return type gains the same final revision column. ON CONFLICT has no
-- named target because the replacement duplicate keys are partial unique
-- indexes.

create function public.claim_due_session_reminders(
  p_now timestamptz default now(),
  p_limit integer default 10
)
returns table (
  log_id uuid,
  lock_token uuid,
  session_id text,
  reminder_type text,
  title text,
  start_at timestamptz,
  min_players integer,
  pending_count integer,
  accepted_count integer,
  waitlisted_count integer,
  count_for_minimum integer,
  shortage_count integer,
  gm_display_name text,
  gm_discord_user_id text,
  reminder_offset_minutes integer,
  target_channel_key text,
  session_public_id text,
  scheduled_for timestamptz,
  shortage_reminder_revision integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 50);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  return query
  with candidates as (
    select
      c.session_id::text as candidate_session_id,
      c.reminder_type::text as candidate_reminder_type,
      c.title::text as candidate_title,
      c.start_at::timestamptz as candidate_start_at,
      c.min_players::integer as candidate_min_players,
      c.pending_count::integer as candidate_pending_count,
      c.accepted_count::integer as candidate_accepted_count,
      c.waitlisted_count::integer as candidate_waitlisted_count,
      c.count_for_minimum::integer as candidate_count_for_minimum,
      c.shortage_count::integer as candidate_shortage_count,
      c.gm_display_name::text as candidate_gm_display_name,
      c.gm_discord_user_id::text as candidate_gm_discord_user_id,
      c.reminder_offset_minutes::integer as candidate_reminder_offset_minutes,
      c.target_channel_key::text as candidate_target_channel_key,
      c.session_public_id::text as candidate_session_public_id,
      c.scheduled_for::timestamptz as candidate_scheduled_for,
      c.shortage_reminder_revision::integer as candidate_shortage_reminder_revision
    from public.preview_due_session_reminders(p_now, v_limit) as c
  ),
  to_insert as (
    select
      c.*,
      gen_random_uuid()::uuid as generated_lock_token,
      now()::timestamptz as claim_time
    from candidates as c
  ),
  inserted as (
    insert into public.session_reminder_logs (
      session_id,
      reminder_type,
      scheduled_for,
      reminder_offset_minutes,
      shortage_reminder_revision,
      status,
      dry_run,
      lock_token,
      created_at,
      claimed_at
    )
    select
      ti.candidate_session_id,
      ti.candidate_reminder_type,
      ti.candidate_scheduled_for,
      ti.candidate_reminder_offset_minutes,
      ti.candidate_shortage_reminder_revision,
      'claimed'::text,
      false::boolean,
      ti.generated_lock_token,
      ti.claim_time,
      ti.claim_time
    from to_insert as ti
    on conflict do nothing
    returning
      public.session_reminder_logs.id as inserted_log_id,
      public.session_reminder_logs.lock_token as inserted_lock_token,
      public.session_reminder_logs.session_id as inserted_session_id,
      public.session_reminder_logs.reminder_type as inserted_reminder_type,
      public.session_reminder_logs.shortage_reminder_revision as inserted_shortage_reminder_revision
  )
  select
    i.inserted_log_id as log_id,
    i.inserted_lock_token as lock_token,
    ti.candidate_session_id as session_id,
    ti.candidate_reminder_type as reminder_type,
    ti.candidate_title as title,
    ti.candidate_start_at as start_at,
    ti.candidate_min_players as min_players,
    ti.candidate_pending_count as pending_count,
    ti.candidate_accepted_count as accepted_count,
    ti.candidate_waitlisted_count as waitlisted_count,
    ti.candidate_count_for_minimum as count_for_minimum,
    ti.candidate_shortage_count as shortage_count,
    ti.candidate_gm_display_name as gm_display_name,
    ti.candidate_gm_discord_user_id as gm_discord_user_id,
    ti.candidate_reminder_offset_minutes as reminder_offset_minutes,
    ti.candidate_target_channel_key as target_channel_key,
    ti.candidate_session_public_id as session_public_id,
    ti.candidate_scheduled_for as scheduled_for,
    ti.candidate_shortage_reminder_revision as shortage_reminder_revision
  from inserted as i
  join to_insert as ti
    on ti.candidate_session_id = i.inserted_session_id
   and ti.candidate_reminder_type = i.inserted_reminder_type
   and ti.candidate_shortage_reminder_revision is not distinct from i.inserted_shortage_reminder_revision
  order by
    ti.candidate_scheduled_for,
    ti.candidate_session_id,
    ti.candidate_reminder_type;
end;
$$;

revoke all on function public.claim_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.claim_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.claim_due_session_reminders(timestamptz, integer) is
  'Service-role claim for due session reminders. Shortage claims are unique per session revision; gm_confirmed remains unique per session.';

comment on function public.update_session_reminder_settings(text, boolean, integer, boolean, integer) is
  'Owner/admin RPC for per-session reminder settings. The sessions trigger increments shortage revision only when shortage enabled state or offset changes.';

commit;

-- ============================================================
-- 5. SELECT-only post-apply checks
-- ============================================================
-- Run these only after the apply transaction succeeds. Do not run preview or
-- claim in the apply gate. Record counts/booleans/definitions only, not rows.

select
  'shortage_revision_session_column' as check_name,
  count(*) as column_count,
  bool_and(data_type = 'integer') as all_integer,
  bool_and(is_nullable = 'NO') as all_not_null,
  bool_and(column_default is not null) as all_have_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name = 'shortage_reminder_revision';

select
  'shortage_revision_session_constraint' as check_name,
  count(*) filter (where conname = 'sessions_shortage_reminder_revision_check') as constraint_count
from pg_constraint
where conrelid = 'public.sessions'::regclass;

select
  'shortage_revision_trigger' as check_name,
  count(*) as trigger_count,
  bool_and(tgenabled <> 'D') as all_enabled
from pg_trigger
where tgrelid = 'public.sessions'::regclass
  and tgname = 'sessions_shortage_reminder_revision_trigger'
  and not tgisinternal;

select
  'shortage_revision_trigger_function' as check_name,
  to_regprocedure('public.bump_session_shortage_reminder_revision()') is not null as function_exists;

with trigger_function as (
  select pg_get_functiondef('public.bump_session_shortage_reminder_revision()'::regprocedure) as definition
)
select
  'shortage_revision_trigger_markers' as check_name,
  definition like '%old.date is distinct from new.date%' as checks_date,
  definition like '%old.start_time is distinct from new.start_time%' as checks_start_time,
  definition like '%old.shortage_reminder_enabled is distinct from new.shortage_reminder_enabled%' as checks_enabled,
  definition like '%old.shortage_reminder_hours_before is distinct from new.shortage_reminder_hours_before%' as checks_offset
from trigger_function;

select
  'shortage_revision_log_column' as check_name,
  count(*) as column_count,
  bool_and(data_type = 'integer') as all_integer,
  bool_and(is_nullable = 'YES') as all_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_reminder_logs'
  and column_name = 'shortage_reminder_revision';

select
  'shortage_revision_log_constraint' as check_name,
  count(*) filter (where conname = 'session_reminder_logs_shortage_revision_check') as constraint_count,
  count(*) filter (where conname = 'session_reminder_logs_unique_session_type') as old_unique_constraint_count
from pg_constraint
where conrelid = 'public.session_reminder_logs'::regclass;

select
  'shortage_revision_unique_indexes' as check_name,
  count(*) filter (where indexname = 'session_reminder_logs_shortage_revision_unique') as shortage_index_count,
  count(*) filter (where indexname = 'session_reminder_logs_gm_confirmed_unique') as gm_index_count,
  bool_and(indexdef like 'CREATE UNIQUE INDEX%') as all_unique
from pg_indexes
where schemaname = 'public'
  and tablename = 'session_reminder_logs'
  and indexname in (
    'session_reminder_logs_shortage_revision_unique',
    'session_reminder_logs_gm_confirmed_unique'
  );

select
  'shortage_revision_unique_index_definitions' as check_name,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'session_reminder_logs'
  and indexname in (
    'session_reminder_logs_shortage_revision_unique',
    'session_reminder_logs_gm_confirmed_unique'
  )
order by indexname;

select
  'shortage_revision_log_access' as check_name,
  c.relrowsecurity as rls_enabled,
  has_table_privilege('anon', 'public.session_reminder_logs', 'select') as anon_select,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'select') as authenticated_select,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'insert') as authenticated_insert,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'update') as authenticated_update,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'delete') as authenticated_delete
from pg_class as c
where c.oid = 'public.session_reminder_logs'::regclass;

select
  'shortage_revision_log_shape' as check_name,
  count(*) filter (
    where reminder_type = 'shortage'
      and (shortage_reminder_revision is null or shortage_reminder_revision < 1)
  ) as invalid_shortage_rows,
  count(*) filter (
    where reminder_type = 'gm_confirmed'
      and shortage_reminder_revision is not null
  ) as invalid_gm_rows,
  count(*) as total_log_count
from public.session_reminder_logs;

with shortage_duplicates as (
  select session_id, reminder_type, shortage_reminder_revision
  from public.session_reminder_logs
  where reminder_type = 'shortage'
  group by session_id, reminder_type, shortage_reminder_revision
  having count(*) > 1
),
gm_duplicates as (
  select session_id, reminder_type
  from public.session_reminder_logs
  where reminder_type = 'gm_confirmed'
  group by session_id, reminder_type
  having count(*) > 1
)
select
  'shortage_revision_duplicate_groups' as check_name,
  (select count(*) from shortage_duplicates) as shortage_duplicate_group_count,
  (select count(*) from gm_duplicates) as gm_duplicate_group_count;

select
  'shortage_revision_rpc_presence' as check_name,
  to_regprocedure('public.preview_due_session_reminders(timestamptz, integer)') is not null as preview_exists,
  to_regprocedure('public.claim_due_session_reminders(timestamptz, integer)') is not null as claim_exists,
  to_regprocedure('public.finalize_session_reminder(uuid, uuid, text, text, text)') is not null as finalize_exists,
  to_regprocedure('public.update_session_reminder_settings(text, boolean, integer, boolean, integer)') is not null as settings_exists;

select
  'shortage_revision_rpc_security' as check_name,
  bool_and(p.prosecdef) as all_security_definer
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'preview_due_session_reminders',
    'claim_due_session_reminders',
    'finalize_session_reminder',
    'update_session_reminder_settings'
  );

select
  'shortage_revision_rpc_privileges' as check_name,
  has_function_privilege('service_role', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as service_role_can_preview,
  has_function_privilege('service_role', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as service_role_can_claim,
  has_function_privilege('service_role', 'public.finalize_session_reminder(uuid, uuid, text, text, text)', 'execute') as service_role_can_finalize,
  has_function_privilege('authenticated', 'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)', 'execute') as authenticated_can_update_settings,
  has_function_privilege('anon', 'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)', 'execute') as anon_can_update_settings,
  has_function_privilege('anon', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as anon_can_preview,
  has_function_privilege('authenticated', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as authenticated_can_preview,
  has_function_privilege('anon', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as anon_can_claim,
  has_function_privilege('authenticated', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as authenticated_can_claim,
  has_function_privilege('authenticated', 'public.finalize_session_reminder(uuid, uuid, text, text, text)', 'execute') as authenticated_can_finalize;

with output_counts as (
  select
    r.routine_name,
    count(*) filter (where p.parameter_mode = 'OUT')::integer as output_column_count,
    bool_or(
      p.parameter_mode = 'OUT'
      and p.parameter_name = 'shortage_reminder_revision'
      and p.data_type = 'integer'
    ) as has_shortage_revision_integer
  from information_schema.routines as r
  join information_schema.parameters as p
    on p.specific_schema = r.specific_schema
   and p.specific_name = r.specific_name
  where r.specific_schema = 'public'
    and r.routine_name in ('preview_due_session_reminders', 'claim_due_session_reminders')
  group by r.routine_name
)
select
  'shortage_revision_rpc_return_shapes' as check_name,
  max(output_column_count) filter (where routine_name = 'preview_due_session_reminders') as preview_output_columns,
  max(output_column_count) filter (where routine_name = 'claim_due_session_reminders') as claim_output_columns,
  bool_or(has_shortage_revision_integer) filter (where routine_name = 'preview_due_session_reminders') as preview_has_shortage_revision,
  bool_or(has_shortage_revision_integer) filter (where routine_name = 'claim_due_session_reminders') as claim_has_shortage_revision
from output_counts;

-- Expected return counts are preview=17 and claim=19. The new final column is
-- shortage_reminder_revision. Current Edge normalization ignores extra RPC
-- fields, so production behavior does not depend on a same-gate Edge deploy.
--
-- Do not execute either RPC in this SELECT-only apply check:
-- select * from public.preview_due_session_reminders(...);
-- select * from public.claim_due_session_reminders(...);
