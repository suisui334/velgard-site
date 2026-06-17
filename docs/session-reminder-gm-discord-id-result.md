# Session Reminder GM Discord ID Result

Status: Gate 6.2 SQL/RPC draft created. SQL not applied.

## Scope

Gate 6.2 investigated how to add a GM Discord user id to the session reminder service-role delivery path.

Created:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`
- `docs/session-reminder-gm-discord-id-sql-checklist.md`

This gate did not change Edge Function code and did not execute SQL.

## GM Discord ID Source Review

Confirmed existing ownership/source path:

- `public.sessions.gm_user_id` identifies the session GM.
- `public.sessions.gm_user_id` references the profile/user identity used by `is_session_gm`.
- `public.profiles.discord_handle` is the existing Discord contact value used by Discord ID registration and GM contact features.
- Existing docs and UI direction treat `profiles.discord_handle` as a Discord user ID when it is a 17-20 digit numeric value.
- Existing public profile surfaces intentionally do not expose Discord contact fields.

Important distinction:

- `profiles.discord_handle` can be used only after validation as a Discord snowflake-like user id.
- Values containing letters, `@`, `#`, whitespace-only content, or non-17-20-digit formats must be treated as missing.
- The actual Discord id must not be written to docs, reports, runtime summaries, or public/browser responses.

## SQL/RPC Draft

The draft updates only service-role reminder RPCs:

- `public.preview_due_session_reminders(p_now timestamptz, p_limit integer)`
- `public.claim_due_session_reminders(p_now timestamptz, p_limit integer)`

Added return column:

- `gm_discord_user_id text`

Source logic:

- join `public.sessions.gm_user_id` to `public.profiles.id`
- read `public.profiles.discord_handle`
- return it only when it matches `^[0-9]{17,20}$`
- otherwise return `null`

Reminder behavior:

- shortage reminders return `null` for `gm_discord_user_id`
- `gm_confirmed` reminders return a safe value only when one is available
- Edge Function will later use the value to build `<@id>` only in production content
- Edge Function dry-run previews must mask the mention as `<@GM>` or equivalent

## Privilege Boundary

The draft keeps both RPCs server-only:

- `security definer`
- `set search_path = ''`
- explicit `auth.role() = 'service_role'` check
- revoke execute from `public`
- revoke execute from `anon`
- revoke execute from `authenticated`
- grant execute only to `service_role`

The draft does not change:

- `public_profiles`
- browser/public RPCs
- `get_my_profile_contact()`
- `update_my_discord_id(text)`
- `get_gm_session_accepted_contacts(text)`
- `update_session_reminder_settings`
- `finalize_session_reminder`
- tables / RLS / policies

## Drop/Recreate Policy

Because both target functions use `returns table`, the draft uses explicit drop/recreate:

1. `begin`
2. drop `claim_due_session_reminders(timestamptz, integer)`
3. drop `preview_due_session_reminders(timestamptz, integer)`
4. recreate `preview_due_session_reminders`
5. restore service-role-only execute boundary
6. recreate `claim_due_session_reminders`
7. restore service-role-only execute boundary
8. `commit`

The draft does not use `cascade`.

## Post-Apply Checks

The draft includes SELECT-only checks for:

- RPC presence
- `gm_discord_user_id` in both return definitions
- `security definer`
- `service_role` execute
- `anon` execute false
- `authenticated` execute false
- `session_reminder_logs` count as a reference only

The draft does not call `preview_due_session_reminders` in the post-apply section.

## Not Performed

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- Webhook/secret setting or change
- claim/finalize runtime execution
- `session_reminder_logs` write
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change
- `console.*` addition
- direct Supabase write helper addition

## Limited / Not Tested

- SQL syntax is draft-reviewed only; it was not applied.
- Live DB function body was not inspected by executing SQL in this gate.
- The actual presence of GM profile Discord IDs was not checked.
- No real Discord user id was viewed, copied, or recorded.

## Next Gate Candidate

Recommended next gates:

1. Gate 6.3: GM Discord ID RPC apply candidate review.
2. Gate 6.4: SQL apply independent approval.
3. Gate 6.5: Edge Function GM mention implementation, no deploy.

## Gate 6.3 Apply Candidate Review

Status: apply candidate created. SQL not applied.

Reviewed source draft:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`

Created apply candidate:

- `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`

Review result:

- drop/recreate order is `claim_due_session_reminders` first, then
  `preview_due_session_reminders`
- `cascade` is not used
- both RPC return definitions include `gm_discord_user_id text`
- both RPCs remain `security definer`
- both RPCs keep `set search_path = ''`
- both RPCs check `auth.role() = 'service_role'`
- execute grants remain service-role-only
- `anon` and `authenticated` execute grants are revoked
- `profiles.discord_handle` is returned only when it matches
  `^[0-9]{17,20}$`
- invalid, empty, or missing values return `null`
- shortage reminder rows return `null` for `gm_discord_user_id`
- `gm_confirmed` rows return the sanitized value when available
- post-apply checks are SELECT-only and do not run preview

The apply candidate remains under `docs/sql-drafts/` and was not placed in
`supabase/migrations/`.

Still not performed:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- Webhook/secret change
- claim/finalize runtime execution
- `session_reminder_logs` write

Next gate:

- Gate 6.4: SQL apply independent approval and SELECT-only confirmation.
