# Session Reminder Claim RPC Diagnosis

Status: Gate 11G diagnosis and SQL draft completed. No claim execution or DB
write was performed.

## Scope

Gate 11G reviewed the `claim_due_session_reminders` SQL definition after Gate
11F returned:

- HTTP status: `502`
- error code: `db_claim_failed`
- stage: `claim_rpc`
- `session_reminder_logs` count after: `0`

This gate did not enable real send, did not call production `dry_run:false`,
did not execute `claim_due_session_reminders`, did not execute
`finalize_session_reminder`, did not send Discord, did not write DB rows, did
not apply SQL, did not deploy Edge Functions, and did not change secrets,
cron, UI, or `updates.json`.

## Logs Count

SELECT-only count:

- `session_reminder_logs` count: `0`

Interpretation:

- The successful claim/finalize path did not complete.
- No reminder log row was persisted.

## Reviewed Areas

Reviewed:

- applied `claim_due_session_reminders` definition via `pg_get_functiondef`
- `preview_due_session_reminders` / `claim_due_session_reminders` OUT column
  metadata
- `session_reminder_logs` relevant column types
- `session_reminder_logs` constraints
- RLS status, policies, owner, and function owner metadata
- function execute privileges for `service_role`, `anon`, and `authenticated`
- Edge Function expected claimed row shape

Not reviewed by execution:

- the runtime body of `claim_due_session_reminders`
- insert behavior inside the claim RPC

The claim RPC was not executed because this gate forbids claim/finalize runtime
execution and DB write.

## SELECT-only Findings

Column and function metadata:

- `session_reminder_logs.session_id`: `text`, `not null`
- `sessions.id`: `text`, `not null`
- `session_reminder_logs.reminder_type`: `text`, `not null`
- `session_reminder_logs.scheduled_for`: `timestamptz`, `not null`
- `session_reminder_logs.reminder_offset_minutes`: `integer`, `not null`
- `session_reminder_logs.status`: `text`, `not null`
- `session_reminder_logs.dry_run`: `boolean`, `not null`
- `session_reminder_logs.lock_token`: `uuid`, nullable at column level but
  required by the claimed-status check
- `claim_due_session_reminders` return shape includes `log_id uuid`,
  `lock_token uuid`, `session_id text`, `gm_discord_user_id text`, and
  `scheduled_for timestamptz`
- Edge-side expected row shape matches those core output columns

Constraint metadata:

- unique duplicate-prevention constraint exists on `(session_id, reminder_type)`
- `status` allows `claimed`, `sent`, `failed`, `skipped`
- `dry_run` must be `false`
- claimed rows require non-null `claimed_at` and `lock_token`
- offset allows `30`, `60`, `120`, `180`
- FK references `sessions(id)`

Owner/RLS metadata:

- `session_reminder_logs` owner: `postgres`
- `session_reminder_logs` RLS: enabled
- `session_reminder_logs` force RLS: false
- `claim_due_session_reminders` owner: `postgres`
- `preview_due_session_reminders` owner: `postgres`
- both functions are `security definer`
- table policies for `session_reminder_logs`: none
- direct table insert/select privileges for `service_role`: false
- `service_role` can execute claim RPC: true
- `anon` / `authenticated` cannot execute claim RPC

Interpretation:

- The table column types and log constraints are broadly compatible with the
  intended claim insert values.
- RLS is unlikely to be the direct blocker because the claim function is
  `security definer`, owned by the same owner as the table, and force RLS is
  false.
- Direct table privileges for `service_role` are false, but the intended
  boundary is function execution, not direct table writes.

## Diagnosis

The exact PostgreSQL runtime error could not be captured without executing the
claim RPC or reading provider-side logs that may include sensitive runtime
context. Gate 11G therefore records the cause as:

- confirmed failing area: `claim_due_session_reminders`
- exact SQL runtime error: not directly captured in this gate
- likely failure point: inside the claim function body before a log row is
  persisted

The applied claim SQL uses unaliased candidate column names in multiple CTE
contexts and returns table columns with names that overlap SQL column names,
including `lock_token`, `session_id`, and `reminder_type`. Although the visible
definition is mostly type-compatible, this is fragile inside PL/pgSQL
`returns table` functions and makes claim failures harder to isolate.

Gate 11G therefore prepares a conservative fix draft that:

- keeps the same function signature and return shape
- keeps service-role-only execution
- keeps duplicate prevention by `(session_id, reminder_type)`
- uses explicit aliases for candidate and inserted columns
- explicitly casts insert and return values
- uses the named unique constraint in `on conflict`
- returns only rows actually inserted by the current claim call

## SQL Draft

Added:

- `docs/sql-drafts/session-reminder-claim-rpc-fix-draft.sql`

The draft is not a migration and was not applied.

Draft highlights:

- `create or replace function public.claim_due_session_reminders(...)`
- explicit `candidate_*` aliases for preview values
- explicit casts for `session_id`, `reminder_type`, `scheduled_for`,
  `reminder_offset_minutes`, `status`, `dry_run`, and `lock_token`
- `on conflict on constraint session_reminder_logs_unique_session_type do nothing`
- explicit `inserted_*` aliases from `returning`
- `revoke` from `public`, `anon`, and `authenticated`
- `grant execute` to `service_role`
- SELECT-only post-apply checks

## SELECT-only Diagnostic SQL

Temporary SELECT-only checks were run locally and not committed under `work/`.
They checked metadata only and did not call claim/finalize. The reusable
post-apply SELECT-only checks are included at the end of:

- `docs/sql-drafts/session-reminder-claim-rpc-fix-draft.sql`

Those checks verify:

- claim RPC existence
- `service_role` execute privilege
- no `anon` / `authenticated` execute privilege
- expected OUT columns
- expected log constraints
- `session_reminder_logs` count

They intentionally do not run `claim_due_session_reminders`.

## Not Performed

- production retry
- production `dry_run:false`
- `SESSION_REMINDER_REAL_SEND_ENABLED` enablement
- claim RPC execution
- finalize RPC execution
- Discord send
- Discord dry-run send
- `@everyone` send
- `session_reminder_logs` write
- SQL apply
- DB/RPC/RLS mutation
- Edge deploy
- secret/Webhook setting or change
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change
- Webhook URL, dispatch token, raw Discord ID, Discord message id, session id,
  session URL, or message body recording

## Next Gate Candidate

Recommended next gate:

- Gate 11H: review/apply the claim RPC fix SQL under explicit SQL apply
  approval, then run SELECT-only post-apply checks.

Do not retry production send until the claim RPC fix is applied and checked.
