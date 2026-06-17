# Session Reminder GM Discord ID SQL Checklist

Status: Gate 6.2 checklist draft. SQL not applied.

## Target File

Use this draft only after explicit approval in a later gate:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`

Do not run it automatically. Do not place it under `supabase/migrations/` yet.

## Apply Preconditions

Before applying, confirm:

- current git worktree is clean
- current production/dry-run runtime behavior is understood
- no Edge Function deploy is bundled into this SQL gate
- no Discord send or Discord dry-run send is bundled into this SQL gate
- no Webhook/secret change is bundled into this SQL gate
- user explicitly approves SQL Editor execution

## SQL Review Checklist

Confirm the draft:

- drops `claim_due_session_reminders(timestamptz, integer)` before `preview_due_session_reminders(timestamptz, integer)`
- does not use `cascade`
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

After apply, run only the SELECT-only checks included at the end of the draft.

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

If SQL review passes:

- Gate 6.3: GM Discord ID RPC apply candidate review
- Gate 6.4: SQL apply independent approval

After apply succeeds:

- Gate 6.5: Edge Function GM mention implementation, no deploy
