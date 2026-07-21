# Shortage Reminder Reschedule Plan

Status: Gate SR-01 design and SQL apply candidate completed. SQL not applied.

## Goal

Allow the automatic shortage reminder to become eligible again when its
schedule changes, while keeping one claim per unchanged schedule and leaving
the GM confirmed reminder behavior unchanged.

Required outcomes:

- changing the shortage offset from three hours to two hours creates a new
  eligible revision
- changing or postponing the session start creates a new eligible revision
- every later relevant change can create another revision
- repeated cron ticks cannot claim the same revision twice
- title, description, player counts, and other unrelated edits do not change
  the revision
- a session at or above its minimum player count is never a shortage candidate

## Current One-Time Cause

The current log table has the named unique constraint:

```text
unique (session_id, reminder_type)
```

The current preview RPC excludes a candidate as soon as any log exists for the
same session and reminder type. The current claim RPC also uses that same
constraint as its conflict target. Consequently, one shortage log blocks all
future shortage schedules for that session, even if the start date, start
time, or reminder offset changes.

## Existing Schema And RPC Facts

- Session schedule columns are `public.sessions.date` and `start_time`.
- Shortage settings are `shortage_reminder_enabled` and
  `shortage_reminder_hours_before`.
- `update_session_reminder_settings(...)` updates the shortage settings in a
  separate RPC after the main session save.
- Preview and claim are service-role-only, security-definer RPCs.
- The currently applied preview return shape has 16 columns.
- The currently applied claim return shape has 18 columns, including the GM
  Discord ID field added in the earlier gate.
- Application minimum logic is still distinct `pending + accepted`;
  `waitlisted` is reported but excluded.
- `finalize_session_reminder(...)` operates on `log_id + lock_token` and does
  not need schedule or revision information.

## Adopted Revision Design

Add to `public.sessions`:

```text
shortage_reminder_revision integer not null default 1
```

A `before update` trigger owns this value. It increments exactly once per SQL
update when at least one of these fields changes:

- `date`
- `start_time`
- `shortage_reminder_enabled`
- `shortage_reminder_hours_before`

The trigger uses `IS DISTINCT FROM`, so assigning the same value does not bump
the revision. On updates that change only unrelated fields, it preserves the
old revision and ignores attempts to assign the revision directly.

The trigger covers the current main session update RPC, the dedicated reminder
settings RPC, admin/server updates, and any future update route that writes the
same `public.sessions` row. This avoids maintaining revision logic in each
caller.

One form save may call the main session RPC and reminder settings RPC
separately. If both schedule and shortage settings change, each committed SQL
update can increment the revision. Only the final current revision is eligible
under normal operation; the apply and runtime QA gates should still avoid
running the production scheduler across a multi-step test edit.

## Log And Uniqueness Design

Add nullable `session_reminder_logs.shortage_reminder_revision`:

- required and positive for `shortage`
- null for `gm_confirmed`

Replace the broad unique constraint with two partial unique indexes:

- shortage: unique `(session_id, reminder_type, shortage_reminder_revision)`
  where `reminder_type='shortage'`
- GM: unique `(session_id, reminder_type)` where
  `reminder_type='gm_confirmed'`

This keeps GM behavior unchanged. For shortage, `ON CONFLICT DO NOTHING`
guards concurrent cron calls and repeated minute ticks. A failed or skipped
attempt also consumes that revision, matching the current no-automatic-retry
policy.

Existing shortage log rows are backfilled to revision `1`, which is also the
initial revision for existing sessions. Applying the schema alone therefore
does not turn historical shortage logs into immediate resend candidates.
Revision tracking starts for relevant edits made after apply.

## RPC Changes

`preview_due_session_reminders(...)`:

- reads the session's current shortage revision internally
- excludes a shortage only when a log exists for the same revision
- continues to exclude GM confirmed after any GM log for that session
- preserves the existing player-count, status, deadline, visibility, and due
  time checks
- appends `shortage_reminder_revision` as a 17th return column so claim uses
  the exact revision from the same candidate snapshot

`claim_due_session_reminders(...)`:

- writes the current shortage revision into the claimed log
- uses targetless `ON CONFLICT DO NOTHING` because duplicate enforcement moves
  to partial unique indexes
- returns only rows inserted by the current claim
- appends `shortage_reminder_revision` as a 19th return column

`update_session_reminder_settings(...)`:

- implementation and signature stay unchanged
- its writes are observed by the trigger

`finalize_session_reminder(...)`:

- no change required

## Edge Function Impact

No Edge Function source change is required for delivery correctness. The new
RPC column is appended, and the deployed `dispatch-session-reminders`
normalizer reads named fields and ignores unknown response fields. Its existing
claim/finalize flow can therefore continue after SQL apply.

An optional later source-only alignment should add nullable
`shortage_reminder_revision` to the Edge RPC row interface and normalization.
It should still omit the revision from public/runtime responses unless it is
needed as a safe diagnostic count/key. No same-gate Edge deploy is required.

The revision does not need to appear in the Discord payload or production
result. After SQL apply, a separate dry-run QA gate should confirm candidate
behavior before any production observation.

## Behavior Matrix

1. Same start and three-hour setting after one logged send: revision unchanged;
   preview excludes it and claim cannot duplicate it.
2. Change three hours to two hours: trigger increments revision; the new
   revision can become due at the two-hour threshold.
3. Postpone or otherwise change the start: trigger increments revision; the
   new start controls the next due threshold.
4. Change the start multiple times: each distinct update increments revision;
   each final revision has its own one-claim key.
5. Edit only title, body, player range, or another unrelated field: revision
   remains unchanged.
6. Reach `pending + accepted >= player_min`: the existing shortage predicate
   excludes the session regardless of revision.

## Apply And Rollback Boundaries

Apply candidate:

- `docs/sql-drafts/session-shortage-reminder-revision-apply-candidate.sql`

The file contains one apply transaction followed by separate SELECT-only
checks. It must not be run automatically or mixed with the checks in one SQL
Editor execution.

Because the automatic scheduler and real-send gate may be active, the future
apply gate should first confirm the live operation state and current shortage
candidate count. Temporarily disabling production send should be handled as an
explicit operational step if needed; it is not performed in SR-01.

Rollback requires a separately reviewed SQL candidate. The safe order is:

1. stop production reminder dispatch for the rollback window
2. restore the previous preview/claim definitions
3. restore the original GM/shortage-wide unique constraint only after checking
   that no session has multiple shortage revision rows
4. remove the revision trigger, indexes, constraints, and columns only if the
   accumulated data allows it
5. rerun SELECT-only checks before restoring operation

Do not use `CASCADE`, delete reminder logs, or alter secrets/Discord settings as
a shortcut.

## Open Points

- Historical schedule changes made before this SQL is applied cannot be
  reconstructed. Existing shortage logs intentionally bind to initial revision
  `1` to prevent surprise resend.
- Failed/skipped shortage attempts remain non-retryable within the same
  revision. A retry/reset policy remains a separate gate.
- If a main session save and settings save both change relevant fields, two
  revision increments are possible because they are separate DB updates. The
  resulting current revision is still the duplicate key, but controlled QA
  should keep the scheduler production path disabled during multi-step edits.

## Blockers

No design blocker was found in the repository contract. The apply candidate is
based on the applied-equivalent SQL definitions recorded in docs, including the
GM Discord ID return column and the corrected claim aliases/casts.

Before apply, SR-02 must still use SELECT-only preflight to confirm that the
live function signatures, named old unique constraint, table columns, grants,
and active scheduler/real-send state still match this candidate. Any mismatch
is a stop condition; do not edit or rerun SQL ad hoc in the apply gate.

## Next Gates

1. SR-02: independently review the apply candidate, current production state,
   and rollback constraints.
2. SR-03: explicit SQL apply followed by the included SELECT-only checks.
3. SR-03.5: optional Edge TypeScript contract alignment for the appended RPC
   column, without changing response exposure or delivery logic.
4. SR-04: production-disabled preview QA for the six behavior cases using a
   controlled future session; no Discord send.
5. SR-05: limited production observation only after explicit approval.

## Not Performed

- SQL Editor execution or SQL apply
- DB/RPC/RLS mutation
- Edge Function change or deploy
- runtime preview/claim/finalize invocation
- Discord send
- cron or secret change
- UI change
- `updates.json` change
