# Shortage Reminder Revision Preflight Result

Status: Gate SR-02 SELECT-only live preflight completed. SQL apply not run.

## Scope

Reviewed:

- `docs/sql-drafts/session-shortage-reminder-revision-apply-candidate.sql`
- live `public.sessions` and `public.session_reminder_logs` metadata
- live preview, claim, finalize, and settings RPC contracts
- the active reminder cron, Vault name boundary, and aggregate pg_net results
- deployed Edge row normalization for the appended RPC field

No row identifiers, session URLs, Discord identifiers, messages, tokens,
Webhook values, JWTs, or secret values were read into this document.

## Live Schema Preflight

The SELECT-only aggregate check returned:

- required session schedule/reminder columns: `6 / 6`
- session column types: matched
- `sessions.shortage_reminder_revision`: absent, as expected before apply
- required reminder log columns: `12 / 12`
- log revision column: absent, as expected before apply
- reminder log constraints: `12`
- current named broad unique constraint: `1`
- current broad key definition: `unique(session_id, reminder_type)` matched
- reminder log foreign keys: `1`
- reminder log CHECK constraints: `9`
- new revision partial indexes: `0`, as expected before apply

The current broad unique constraint and preview exclusion are the live cause of
one-time shortage behavior.

## RPC Preflight

All four expected RPCs exist and remain security definer:

- `preview_due_session_reminders(timestamptz, integer)`
- `claim_due_session_reminders(timestamptz, integer)`
- `finalize_session_reminder(uuid, uuid, text, text, text)`
- `update_session_reminder_settings(text, boolean, integer, boolean, integer)`

Contract results:

- preview output columns: `16`
- claim output columns: `18`
- both preview and claim include the prior `gm_discord_user_id text` field
- neither function contains `shortage_reminder_revision` before apply
- preview still excludes by session plus reminder type
- claim still targets `session_reminder_logs_unique_session_type`
- the settings RPC still updates both shortage fields and both GM fields
- finalize still uses terminal status and lock-token guards

Privilege results:

- service role can preview, claim, and finalize
- authenticated can update settings
- anon/authenticated cannot preview or claim
- all service-only boundaries required by the candidate remain intact

## Existing Log Safety

Aggregate log state at preflight:

- total logs: `8`
- shortage logs: `2`
- GM confirmed logs: `6`
- sent logs: `8`
- claimed, failed, or skipped logs: `0`

One existing shortage log has a stored schedule that differs from the session's
current start schedule. Its reminder offset still matches, and it is not due at
the preflight time. No identifiers or schedule values were recorded.

The SR-01 candidate originally assigned every old shortage log and current
session to revision `1`. That would have hidden this already-rescheduled case
until another edit. SR-02 corrected the migration:

- every historical shortage log receives revision `1`
- a session whose current schedule still matches its log stays at revision `1`
- a session whose start or shortage offset differs moves to revision `2`
- GM rows keep a null shortage revision

This preserves no-surprise resend for unchanged schedules while allowing an
already-postponed schedule to become eligible under its new due time.

## Cron And Function State

Read-only operational checks found:

- cron job count: `1`
- schedule: every minute
- job active: true
- pg_net call and all three Vault secret-name references: present
- payload markers: `dry_run:false`, `limit:1`
- expected Vault names: `3 / 3`
- recent cron runs checked: `10`, all scheduler runs succeeded
- recent reminder runtime responses checked: `10`, all HTTP 2xx
- those responses reported production enabled
- positive claim/send responses in that observation window: `0`
- response-side Discord-send and DB-write flags: no positive values

The cron should not be unscheduled for the apply. The apply is one transaction,
and PostgreSQL table/function changes become visible atomically. However,
production send must be temporarily disabled in a separate approved operation
before apply. The existing schedule mismatch will intentionally become a new
revision, and leaving real send enabled would allow cron to claim it whenever
its new due window arrives.

## Apply Candidate Review

The candidate now:

- revisions only shortage reminders
- keeps GM uniqueness at one log per session and reminder type
- increments on `date`, `start_time`, shortage enabled state, or shortage offset
- preserves revision for unrelated edits and direct revision assignments
- carries preview's exact revision into claim and the inserted log
- uses partial unique indexes plus targetless `ON CONFLICT DO NOTHING`
- leaves finalize and settings signatures unchanged
- keeps preview/claim service-role-only
- does not use `CASCADE`

Apply and verification are now physically separated:

- apply only:
  `docs/sql-drafts/session-shortage-reminder-revision-apply-candidate.sql`
- preflight SELECT-only:
  `docs/sql-drafts/session-shortage-reminder-revision-preflight-select-only.sql`
- post-apply SELECT-only:
  `docs/sql-drafts/session-shortage-reminder-revision-post-apply-select-only.sql`

## Edge Contract

No Edge behavior change is required before SQL apply. The new column is
appended, and `dispatch-session-reminders` normalizes named fields while
ignoring unknown properties.

A later source-only alignment should add nullable
`shortage_reminder_revision` to `PreviewReminderRow` and preserve it through
`normalizePreviewReminderRow`. This is recommended for contract clarity, not a
blocker for the SQL gate. The raw revision should not be added to public dry-run
or production responses without a separate need.

## Apply Readiness

Schema/RPC blocker: none.

Operational condition before SR-03 apply:

1. temporarily set automatic real send to disabled
2. observe production-disabled cron responses and unchanged log count
3. run only the apply candidate transaction
4. stop on any SQL error; do not rerun blindly
5. run only the separate post-apply SELECT file
6. keep production send disabled for revision-aware dry-run QA

The SQL candidate is ready for that separately approved, production-disabled
apply gate. It is not approved for execution while real send remains enabled.

## Not Performed

- SQL apply or any DB/RPC/RLS mutation
- preview, claim, or finalize RPC execution
- Edge Function source change or deploy
- Discord send
- cron or secret change
- `updates.json` change
