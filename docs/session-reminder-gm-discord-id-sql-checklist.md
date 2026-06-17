# Session Reminder GM Discord ID SQL Checklist

Status: Gate 6.4 apply completed by user. Checklist retained for audit.

## Target File

Use this corrected apply candidate only after explicit approval in a later
re-apply or audit gate:

- `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`

Do not run it automatically. Do not place it under `supabase/migrations/` yet.

The Gate 6.2 draft remains available for history:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`

Gate 6.4 note:

- The first Gate 6.3 candidate failed near `union` and was rolled back.
- The current apply candidate has been corrected to the no-UNION shape that the
  user applied successfully.
- Do not rerun it unless a later gate explicitly approves re-apply.

## Apply Preconditions

Before applying, confirm:

- current git worktree is clean
- latest reviewed SQL candidate is
  `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`
- current production/dry-run runtime behavior is understood
- no Edge Function deploy is bundled into this SQL gate
- no Discord send or Discord dry-run send is bundled into this SQL gate
- no Webhook/secret change is bundled into this SQL gate
- user explicitly approves SQL Editor execution

## SQL Review Checklist

Gate 6.3 review confirmed the original apply candidate. Gate 6.4 then required
the no-UNION correction. Confirm the corrected apply candidate:

- drops `claim_due_session_reminders(timestamptz, integer)` before `preview_due_session_reminders(timestamptz, integer)`
- does not use `cascade`
- does not use the failed `union all` candidate shape
- uses a no-UNION candidate construction with explicit reminder-type branching
- recreates `preview_due_session_reminders` with `gm_discord_user_id text`
- recreates `claim_due_session_reminders` with `gm_discord_user_id text`
- keeps both RPCs `security definer`
- keeps `set search_path = ''`
- checks `auth.role() = 'service_role'`
- revokes execute from `public`, `anon`, and `authenticated`
- grants execute only to `service_role`
- does not change `update_session_reminder_settings`
- does not change `finalize_session_reminder`
- does not change tables, RLS, policies, browser grants, Edge Functions, or UI

If reviewing again before apply, confirm the same points against the apply
candidate file, not the draft history file.

## GM Discord ID Source Checklist

Confirm the draft:

- uses `public.sessions.gm_user_id` to identify the session GM
- joins to `public.profiles`
- reads `profiles.discord_handle`
- returns it only when it matches `^[0-9]{17,20}$`
- returns `null` when missing, empty, or invalid
- returns `null` for shortage reminders
- returns the safe value for `gm_confirmed` only when available
- does not use `public_profiles`
- does not expose Discord IDs through browser/public RPCs

## Post-Apply SELECT Checks

After apply, run only the SELECT-only checks included at the end of the apply
candidate.

Record only status/count-style results:

- preview RPC exists
- claim RPC exists
- preview return definition includes `gm_discord_user_id`
- claim return definition includes `gm_discord_user_id`
- both RPCs are `security definer`
- `service_role` can execute both
- `anon` cannot execute either
- `authenticated` cannot execute either
- `session_reminder_logs` count, if recorded, is a count only

Do not run `preview_due_session_reminders` as part of the SQL apply confirmation unless a later gate explicitly asks for a service-role preview.

## Reporting Rules

Do not paste:

- real Discord user IDs
- `<@real id>` mention strings
- real session ids
- real session URLs
- Webhook URLs
- tokens / JWTs / service keys
- email addresses
- raw user ids
- message ids / channel ids
- full message previews

If `gm_discord_user_id` appears in a result set, do not copy the value. Record only whether the return column exists.

## Failure Handling

If any SQL Editor error occurs:

- stop immediately
- do not rerun blindly
- record the error category without secrets or real ids
- do not deploy Edge Function
- do not attempt Discord send
- do not run claim/finalize
- do not modify Webhook/secret settings

## Next Gates

After the successful Gate 6.4 apply:

- Gate 6.5: Edge Function GM mention implementation, no deploy
- Later deploy/runtime gates remain separate.
