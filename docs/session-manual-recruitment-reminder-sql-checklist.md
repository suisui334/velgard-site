# Session Manual Recruitment Reminder SQL Checklist

Status: Gate MR-02 checklist draft. SQL has not been applied.

This checklist accompanies:

- `docs/sql-drafts/session-manual-recruitment-reminder-draft.sql`

No SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge implementation,
Edge deploy, Discord send, secret change, UI change, or `updates.json` change
was performed in MR-02.

## Apply-Gate Boundary

Before any SQL apply, promote the draft to an apply candidate in a separate
review gate.

Required review points:

- Confirm `public.sessions.id` remains `text`.
- Confirm `public.sessions.gm_user_id` identifies the session GM.
- Confirm `public.sessions.date` and `public.sessions.start_time` remain the
  source for `start_at`.
- Confirm `public.sessions.application_deadline` remains `timestamptz`.
- Confirm `public.sessions.player_min` remains the minimum-player field.
- Confirm allowed session statuses still include `draft`, `tentative`,
  `recruiting`, `full`, `closed`, `finished`, and `canceled`.
- Confirm `public.session_applications.status` still includes `pending`,
  `accepted`, `waitlisted`, `rejected`, and `canceled`.
- Confirm `public.is_admin()` and `public.is_session_gm(text)` still exist and
  are appropriate for GM/admin authorization.
- Confirm `public.profiles.id` remains the safe profile/user reference for
  `actor_user_id`.

Do not run apply SQL and SELECT checks in the same SQL Editor execution.

## Draft Objects

Proposed table:

- `public.session_manual_recruitment_reminder_logs`

Proposed RPCs:

- `preview_manual_recruitment_reminder(p_session_id text)`
- `claim_manual_recruitment_reminder(p_session_id text)`
- `finalize_manual_recruitment_reminder(p_log_id uuid, p_lock_token uuid, p_status text, p_discord_message_id text, p_error_message text)`

The manual log table is intentionally separate from automatic
`public.session_reminder_logs`.

## Permission Expectations

Table access:

- RLS enabled.
- `anon`: no direct table access.
- `authenticated`: no direct table access.
- Access is through reviewed RPCs only.

RPC access:

- `preview_manual_recruitment_reminder(text)`: `authenticated` execute.
- `claim_manual_recruitment_reminder(text)`: `authenticated` execute.
- `finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)`:
  `service_role` execute only.
- `anon`: no execute.

The future Edge Function should call the claim RPC with the caller's
authenticated JWT context so `auth.uid()` is the GM/admin actor.

## Send Eligibility

The draft claim logic allows manual recruitment reminder claims only when:

- caller is authenticated
- caller is admin or the session GM
- `visibility = public`
- `status in ('recruiting', 'tentative')`
- `start_time` exists
- computed `start_at` is in the future
- `application_deadline` exists
- `application_deadline > now()`
- no active successful-send cooldown exists
- no `status = 'claimed'` manual reminder log exists for the same session

The draft blocks:

- `draft`
- `full`
- `closed`
- `finished`
- `canceled`
- private/hidden sessions
- started/past sessions
- deadline-passed sessions
- in-progress claims
- cooldown-active sessions

Shortage is not required.

## Cooldown And Duplicate Prevention

Initial cooldown policy:

- Successful send sets `cooldown_until = now() + interval '6 hours'`.
- Claim rejects a new manual recruitment reminder while `cooldown_until > now()`.
- Failed/skipped finalization does not start cooldown.

Duplicate prevention:

- A partial unique index blocks more than one `status = 'claimed'` log for the
  same session.
- Claim also checks for an existing claimed row before insert.
- A stuck claimed row should be handled by a later reviewed recovery gate; do
  not manually edit it outside a documented recovery process.

## Returned Fields

The claim RPC returns only safe fields needed by the future Edge Function:

- `log_id`
- `lock_token`
- `session_id`
- `session_public_id`
- `title`
- `start_at`
- `player_min`
- `accepted_count`
- `pending_count`
- `waitlisted_count`
- `gm_display_name`
- `cooldown_until`

The preview RPC returns similar safe context plus `can_send`,
`blocked_reason`, and `cooldown_seconds_remaining`.

Do not record concrete session ids, user ids, full URLs, Discord message ids,
Webhook URLs, token values, or full Discord message bodies in docs.

## Post-Apply SELECT-Only Checks

After a future reviewed apply succeeds, run the SELECT-only checks at the end of
the SQL file separately.

Expected confirmations:

- table exists
- RLS enabled
- no direct browser-role table privileges
- expected constraints exist
- claimed unique index exists
- cooldown index exists
- preview/claim/finalize RPCs exist
- all RPCs are `security definer`
- `search_path` is fixed
- `authenticated` can execute preview and claim
- `authenticated` cannot execute finalize
- `anon` cannot execute preview/claim/finalize
- `service_role` can execute finalize
- log count is recorded as count only

Do not execute preview, claim, or finalize as part of this SELECT-only checklist
unless a later gate explicitly asks for that runtime check.

## Future Edge Function Notes

The planned Edge Function is:

- `send-session-recruitment-reminder`

Expected behavior:

- Uses dry-run/preview first.
- Uses claim before Discord send.
- Sends Discord with `@everyone` only after a separate production approval gate.
- Uses `allowed_mentions.parse=["everyone"]`.
- Uses `flags: 4` to suppress embeds.
- Uses an absolute `session-detail` URL.
- Finalizes success/failure with the service-role finalize RPC.

## Not Performed In MR-02

- SQL Editor execution
- SQL apply
- DB/RPC/RLS mutation
- Edge implementation
- Edge deploy
- Discord send
- secret/Webhook change
- cron change
- UI / HTML / CSS / JS change
- `updates.json` change
- concrete secret, token, Webhook URL, Discord ID, message id, full URL, or
  full message body recording
