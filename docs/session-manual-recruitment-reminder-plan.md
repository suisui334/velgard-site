# Session Manual Recruitment Reminder Plan

Status: Gate MR-01 design investigation only.

This document plans a manual Discord recruitment reminder that a GM or admin
can send from `session-detail`. It is separate from the automatic session start
reminder flow. No implementation, SQL apply, DB/RPC/RLS change, Edge deploy,
Discord send, secret change, UI change, or `updates.json` change was performed.

## Goal

Add a controlled manual action for a session GM/admin:

- Button label candidate: `参加者募集リマインドを送る`
- Location: the GM/admin management area on `session-detail`
- Confirmation: explicitly warns that the Discord notification includes
  `@everyone`
- Result display: status/count oriented success or failure message

Planned Discord content shape:

```text
@everyone
■依頼書【依頼書タイトル】［absolute session-detail URL］
現在、参加者を募集しています。
ご都合よろしければ参加をご検討ください。
現在の参加状況：承認済みX名 / 申請中Y名 / 最低人数Z名
```

The count line is optional for the first release, but it is useful enough to
include if the server-side context can provide `accepted`, `pending`, and
`min_players` safely.

## Existing Structure Findings

### `session-detail` management area

Relevant files:

- `assets/js/sessionDisplay.js`
- `assets/js/renderSessionDetail.js`

The detail page already renders a management panel for Supabase-backed sessions.
`renderSessionDetail.js` then checks edit/manage permission using:

- `is_admin()`
- `is_session_gm(target_session_id)`

The same area already hosts edit, delete, close-marker, and Discord sync UI
state. A manual recruitment reminder button naturally belongs there, after the
basic edit/delete controls and near the existing Discord sync panel.

The frontend permission check should only control visibility/enabled state. The
Edge Function or RPC must re-check permission server-side before any Discord
send.

### Existing session Discord sync

Relevant files:

- `assets/js/discordSyncClient.js`
- `supabase/functions/sync-session-post-to-discord/index.ts`

Observed pattern:

- Browser invokes the Edge Function with the authenticated Supabase client.
- The Edge Function checks GM/admin permission server-side.
- Webhook URL is held in an Edge secret/env, not browser JS.
- Discord payload uses `flags: 4` to suppress embeds.
- `allowed_mentions.parse=["everyone"]` is used only when explicitly requested.
- Absolute `session-detail` URLs are built from `PUBLIC_SITE_BASE_URL` or a
  browser/request-derived base where available.
- Full Webhook URL, message id, and concrete session URL values are not recorded
  in docs.

This is the closest implementation pattern for a manual button-triggered send.

### Existing automatic session reminders

Relevant files:

- `supabase/functions/dispatch-session-reminders/index.ts`
- `docs/session-reminder-discord-production-gate-plan.md`
- `docs/session-reminder-current-operation-status.md`
- `docs/session-reminder-discord-url-fix-result.md`

Automatic reminders use:

- `preview_due_session_reminders`
- `claim_due_session_reminders`
- `finalize_session_reminder`
- `session_reminder_logs`
- `DISCORD_SESSION_REMINDER_WEBHOOK_URL`
- `SESSION_REMINDER_REAL_SEND_ENABLED`
- `SESSION_REMINDER_DISPATCH_TOKEN`

The automatic flow is scheduler/due-time driven and uses claim/finalize
duplicate prevention. It already separates `shortage` `@everyone` delivery from
`gm_confirmed` GM-mention delivery.

Manual recruitment reminders should not be stored in `session_reminder_logs`
unless that table is deliberately generalized. Reusing it directly would mix
manual GM intent with automatic due reminders and would make duplicate
prevention semantics harder to reason about.

## Option Comparison

### A. Extend `dispatch-session-reminders`

Pros:

- Reuses existing Discord payload helpers, absolute URL handling, Webhook env,
  and suppress-embed behavior.
- Reuses the existing reminder destination channel boundary.

Cons:

- The current Function is scheduler-oriented and centered on due reminders.
- It relies on service-role preview/claim/finalize RPCs rather than a
  browser-user action model.
- It would mix manual `@everyone` sends with automatic reminder logs and
  duplicate prevention.
- The production gate is dispatch-token oriented, not GM/admin browser auth
  oriented.

Assessment: possible, but not recommended for the initial manual button.

### B. Create a separate Edge Function

Candidate name:

- `send-session-recruitment-reminder`

Pros:

- Cleanly separates manual GM/admin action from cron automatic dispatch.
- Can authenticate via the caller's Supabase session and re-check
  `is_admin()` / `is_session_gm(...)`.
- Can use a manual-specific log table and cooldown policy.
- Keeps UI response and manual send errors independent from automatic scheduler
  result semantics.
- Easier to disable or roll back without affecting automatic reminders.

Cons:

- Duplicates or factors out some payload/URL helper behavior.
- Needs a small DB/RPC/log design rather than reusing `session_reminder_logs`
  unmodified.

Recommendation: choose option B for MR-02 onward.

## UI Placement And Behavior

Add a small control to the existing `session-detail` GM/admin management panel:

- Button: `参加者募集リマインドを送る`
- Button is hidden or disabled until the existing GM/admin access check passes.
- If disabled, show a short reason where safe:
  - not public
  - not recruiting/tentative
  - application deadline passed
  - full/closed/finished/canceled
  - cooldown active
- On click, show a confirmation dialog that explicitly says an `@everyone`
  Discord notification will be sent.
- After send, show a short status result. Do not show Webhook URL, Discord
  message id, raw user id, token, or full provider URL.

The UI should not decide final eligibility. It should ask the server and display
the result.

## Permission Design

Initial allowed actors:

- session GM
- admin

Server-side checks:

- Require an authenticated Supabase user.
- Confirm `is_admin()` or `is_session_gm(target_session_id)` on the server.
- Do not trust frontend-only button visibility.
- Do not expose raw `gm_user_id`, email, JWT, token, Webhook URL, or Discord
  IDs to the browser.

The manual reminder Edge Function should be invoked with the browser
authenticated client, like existing session post Discord sync. It can use a
service-role client internally only for reviewed DB reads/writes and Discord
logging, while still deriving the actor from the caller JWT.

## Send Eligibility

Initial eligibility proposal:

- `visibility = public`
- `status` is one of:
  - `recruiting`
  - `tentative`
- `status` is not:
  - `draft`
  - `full`
  - `closed`
  - `finished`
  - `canceled`
- Session has not started yet.
- Application deadline has not passed.
- Session is not deleted or hidden.
- Shortage is not required; the GM can recruit even if minimum players are
  already met.

Rationale:

- This is a manual recruitment tool, not an automatic shortage detector.
- `full`, `closed`, `finished`, and `canceled` should not send a recruitment
  message.
- Deadline-passed sessions should not invite additional applications unless a
  later gate explicitly changes the rule.

Open question for MR-02:

- Whether `tentative` should be allowed in production or only `recruiting`.
  Current recommendation is to allow both if the page is public and the
  deadline is still open.

## Discord Payload Policy

For manual recruitment reminders:

- Include `@everyone` in content.
- Set `allowed_mentions.parse=["everyone"]`.
- Use `flags: 4` to suppress embeds / OGP cards.
- Use an absolute `session-detail` URL, matching the reminder URL fix pattern.
- Use `wait=true` if a Discord message id will be recorded.
- Truncate content using the existing Discord content limit pattern.

Do not record the full message body, concrete session URL, Webhook URL, Discord
message id, channel id, token, or Discord user id in docs or reports.

## Destination And Secret Boundary

Initial destination options:

1. Reuse the existing session reminder Webhook env:
   `DISCORD_SESSION_REMINDER_WEBHOOK_URL`.
2. Create a manual-specific env:
   `DISCORD_SESSION_RECRUITMENT_REMINDER_WEBHOOK_URL`.

Recommendation:

- Prefer a manual-specific env for the new Edge Function, even if it points to
  the same Discord notification channel.
- Keep `@everyone` production send behind an independent manual reminder gate.
- Do not store Webhook URLs or token values in browser JS, DB rows, docs, or
  reports.

Optional future real-send gate:

- `SESSION_RECRUITMENT_REMINDER_REAL_SEND_ENABLED`

If the function is only callable by GM/admin browser action, a real-send env is
still useful for staged deploy and dry-run confirmation before the first
production send.

## Abuse Prevention And Logging

Manual reminders need their own duplicate/cooldown log. Recommended initial
table:

- `session_manual_recruitment_reminder_logs`

Candidate columns:

- `id`
- `session_id`
- `actor_user_id`
- `status`
- `discord_message_id`
- `error_message`
- `created_at`
- `claimed_at`
- `sent_at`
- `finalized_at`

Recommended initial policy:

- Use a cooldown rather than a strict lifetime one-shot.
- Suggested first cooldown: one successful manual recruitment reminder per
  session per 6 hours.
- A stricter alternative is one successful send per session per day.
- A simpler first production gate may send only one test reminder and leave
  repeat behavior disabled until the cooldown SQL is reviewed.

Why cooldown instead of one-shot:

- A session may legitimately need renewed recruitment if schedule changes or
  applications are withdrawn.
- Cooldown prevents rapid repeated `@everyone` abuse while keeping the tool
  operational.

DB/RPC should enforce cooldown server-side. UI-only cooldown is not sufficient.

## DB/RPC Design Direction

Recommended reviewed RPC boundaries:

1. `preview_session_recruitment_reminder(p_session_id text)`
   - Returns eligibility, counts, cooldown state, and a safe preview summary.
   - No DB write.
   - Does not return Webhook URL, message id, raw user id, or secret values.
2. `claim_session_recruitment_reminder(p_session_id text)`
   - Checks actor permission, session eligibility, and cooldown.
   - Inserts a claimed log row only if eligible.
   - Prevents concurrent duplicate sends.
3. `finalize_session_recruitment_reminder(...)`
   - Records `sent`, `failed`, or `skipped`.
   - Stores provider message id if available, but never exposes it in docs.

Alternative:

- A single security-definer RPC can return all context and claim atomically, but
  separating preview/claim/finalize is easier to test and mirrors the automatic
  reminder safety pattern.

The browser should not insert/update/delete log rows directly.

## Edge Function Direction

Recommended new Edge Function:

- `send-session-recruitment-reminder`

Expected request shape:

```json
{
  "session_id": "public session key",
  "dry_run": true
}
```

Production send flow:

1. Validate request and authenticated user.
2. Create user-context Supabase client for caller identity checks.
3. Create service-role client only after auth is present.
4. Preview or claim via reviewed RPC.
5. Build absolute session URL and safe Discord message.
6. Send to Discord only if production enabled and claim succeeded.
7. Finalize log with `sent` or `failed`.
8. Return status/counts and safe user-facing error codes.

Dry-run flow:

- Does not send Discord.
- Does not write logs.
- Returns eligibility/cooldown/message-shape markers only.
- Redacts or omits full URL/message body in docs and reports.

## Rollback And Recovery

If manual recruitment reminder introduction fails:

- Hide or disable the `session-detail` button.
- Keep automatic `dispatch-session-reminders` unchanged.
- Disable the manual real-send env flag if one exists.
- Do not change Webhook URL as a rollback substitute.
- If a log row was claimed but not sent, finalize as `failed` or leave for a
  reviewed cleanup gate.
- Record only status/counts and safe error codes.

## Open Questions

- Exact cooldown duration: 6 hours, 12 hours, or 24 hours.
- Whether `tentative` sessions should be allowed, or only `recruiting`.
- Whether to share `DISCORD_SESSION_REMINDER_WEBHOOK_URL` or use
  `DISCORD_SESSION_RECRUITMENT_REMINDER_WEBHOOK_URL`.
- Whether count details should include `waitlisted`.
- Whether admin can bypass cooldown in a later audited gate.
- Whether the first production gate should use a temporary test channel before
  allowing `@everyone` in the main notification channel.

## Next Gate Split

Recommended next gates:

1. MR-02: DB/RPC/log SQL draft for manual recruitment reminders.
2. MR-03: UI implementation with send disabled or dry-run only.
3. MR-04: `send-session-recruitment-reminder` Edge Function implementation,
   deployなし.
4. MR-05: deploy + dry-run / production-disabled runtime confirmation.
5. MR-06: one limited production send test with explicit `@everyone` approval.
6. MR-07: production operation start, with cooldown and rollback notes.

## Not Performed In MR-01

- Implementation
- SQL apply
- DB/RPC/RLS change
- Edge deploy
- Discord send
- secret/Webhook change
- UI / HTML / CSS / JS change
- `updates.json` change
- concrete Webhook URL, token, Discord ID, message id, full URL, or full message
  body recording
