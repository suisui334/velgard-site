# Session Reminder SQL Apply Checklist

Status: Gate 1.5 checklist only. SQL has not been executed.

Use this checklist for the next explicit user-approved Gate 2 only.

## Gate 2 Result Reference

Gate 2 was later executed by the user and recorded in:

- `docs/session-reminder-sql-apply-result.md`

The checklist below remains as the historical apply procedure and expected SELECT confirmation order. It is not a request to rerun SQL.

## Apply Candidate

Paste this file into Supabase SQL Editor only after explicit approval:

- `docs/sql-drafts/session-reminder-notifications-apply-candidate.sql`

Do not use:

- `docs/sql-drafts/session-reminder-notifications-draft.sql`
- any file under `supabase/migrations/`
- partial snippets copied from chat

## Apply Before Checks

Before opening SQL Editor:

- Confirm the latest committed apply candidate is reviewed.
- Confirm the worktree is clean.
- Confirm this is an explicit SQL apply gate.
- Confirm no Edge Function deploy is being bundled into the same gate.
- Confirm no Discord dry-run or production send is being bundled into the same gate.
- Confirm no UI / HTML / CSS / JS change is being bundled into the same gate.
- Confirm no `updates.json` change is being bundled into the same gate.
- Confirm result reporting will not include raw user identifiers, emails, JWTs, tokens, management keys, Discord IDs, Discord URLs, Webhook URLs, or secret values.

Recommended pre-apply manual note:

- Record the current `public.sessions` row count as a number only if needed.
- Do not paste session row values into docs or chat.

## SQL Editor Apply Rule

Paste the full apply candidate file once.

If any error occurs:

- Stop immediately.
- Do not re-run blindly.
- Copy only the generalized error name/message needed for diagnosis.
- Do not paste raw row values, provider identifiers, user identifiers, URLs, or secret values.
- Report whether the transaction committed or failed before the `commit;` line.

The apply candidate contains SELECT-only post-apply checks after `commit;`. These checks are intended to run after the apply section in the same paste.

## Expected Apply Shape

The apply candidate should:

- Add four reminder setting columns to `public.sessions`.
- Add `public.session_reminder_logs`.
- Enable RLS on `public.session_reminder_logs`.
- Revoke direct table access for anon/authenticated.
- Add `update_session_reminder_settings`.
- Add `preview_due_session_reminders`.
- Add `claim_due_session_reminders`.
- Add `finalize_session_reminder`.
- Grant the settings RPC to authenticated.
- Grant preview/claim/finalize RPCs to service role only.

The apply candidate should not:

- Send Discord messages.
- Invoke Edge Functions.
- Create cron jobs.
- Write reminder logs during dry-run.
- Insert session rows.
- Modify existing session reminder settings to enabled.
- Touch `updates.json`.
- Change `create_session_post` or `update_session_post` signatures.

## SELECT Confirmation Order

After apply, review the SELECT result sections in this order:

1. `sessions_reminder_columns`
   - Expected `found_column_count = 4`.

2. `sessions_reminder_constraints`
   - Expected `found_constraint_count = 2`.

3. `session_reminder_logs_table`
   - Expected `exists = true`.

4. `session_reminder_logs_constraints`
   - Expected `found_constraint_count = 6`.

5. `session_reminder_logs_rls`
   - Expected `rls_enabled = true`.

6. `session_reminder_logs_direct_privileges`
   - Expected anon/authenticated direct table access values are false for the reported checks.

7. `session_reminder_rpc_exists`
   - Expected rows for:
     - `update_session_reminder_settings`
     - `preview_due_session_reminders`
     - `claim_due_session_reminders`
     - `finalize_session_reminder`
   - Expected `security_definer = true` for these functions.

8. `session_reminder_rpc_privileges`
   - Expected authenticated can execute `update_session_reminder_settings`.
   - Expected anon cannot execute `update_session_reminder_settings`.
   - Expected service role can execute preview/claim/finalize.
   - Expected authenticated cannot execute preview.

9. `sessions_count_after_apply`
   - Record count only.
   - Do not paste row data.

10. `default_enabled_rows_after_apply`
    - Expected `shortage_enabled_count = 0`.
    - Expected `gm_enabled_count = 0`.

11. `session_reminder_logs_count_after_apply`
    - Expected `log_count = 0`.

## Preview RPC Note

Do not run `preview_due_session_reminders` during Gate 2 unless the user explicitly approves a service-role dry-run check.

Reason:

- The function is write-free, but it is meant for the later Edge Function dry-run gate.
- It can return live session titles and scheduling facts.
- Gate 2 should focus on schema/RPC existence and access checks.

If a future approved dry-run executes preview:

- Record only counts/status.
- Do not paste raw session ids, titles, URLs, user identifiers, Discord identifiers, or message previews.

## User Report Template

After Gate 2, report:

- SQL apply status: `applied` / `failed` / `stopped_before_apply`.
- Error status if any: generalized error only.
- SELECT check status for each section:
  - `ok`
  - `unexpected`
  - `not_run`
- `sessions_count_after_apply`: number only.
- `default_enabled_rows_after_apply`: numbers only.
- `session_reminder_logs_count_after_apply`: number only.
- Confirmation that no Discord send, Edge deploy, secret change, or UI change occurred.
- Confirmation that no raw identifiers or secret values are included.

## Failure Handling

If apply fails:

- Stop.
- Do not rerun.
- Save the exact step where it stopped, without sensitive values.
- Keep Discord/Edge/UI gates closed.
- Ask for a separate diagnosis gate.

If apply succeeds but SELECT checks are unexpected:

- Stop after recording generalized statuses.
- Do not run cleanup SQL.
- Do not run rollback SQL without a separate rollback gate.
- Do not proceed to UI or Edge gates.

## Next Gate After Successful Apply

Recommended next step after successful Gate 2:

- Gate 2 result recording docs, if not included in the same user report.
- Then Gate 3 UI implementation planning or implementation.

Do not proceed directly to Discord dry-run or production send.
