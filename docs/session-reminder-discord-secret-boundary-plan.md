# Session Reminder Discord Secret Boundary Plan

Status: Gate 8 destination and secret boundary planning completed. No secret,
Webhook, Edge deploy, runtime invocation, Discord send, DB write, SQL apply, or
cron setup was performed.

## Scope

This gate fixes the pre-production boundary for session start reminder Discord
sends.

Reminder types:

- shortage reminder: public recruitment reminder with `@everyone`
- GM confirmed reminder: GM user mention reminder without `@everyone`

This document records the agreed destination and env/secret policy only. Real
Webhook URLs, project refs, dispatch tokens, Discord IDs, channel IDs, provider
message IDs, and session URLs are intentionally not recorded.

## Destination Decision

### Shortage Reminder

Decision:

- Use the existing Discord notification channel for the first production
  version.
- Use a dedicated session-reminder Webhook/env boundary instead of reusing the
  existing session-post sync env directly.
- `@everyone` is allowed only for the shortage reminder type.
- Actual `@everyone` production sending remains a later independent gate.

Reasoning:

- The existing notification channel is the current audience for session-related
  announcements.
- A dedicated Webhook/env boundary allows reminders to be disabled without
  disabling normal session-post Discord sync.
- Scheduled `@everyone` behavior is riskier than immediate session-post sync,
  so it should be auditable through a separate env name.

Payload boundary:

- content may include `@everyone`
- `allowed_mentions.parse=["everyone"]`
- `flags: 4` for suppressing session URL embeds
- Webhook `wait=true` remains preferred so production finalize can receive a
  provider message reference without exposing it in docs

### GM Confirmed Reminder

Decision:

- Use the same existing Discord notification channel for the first production
  version.
- Mention the GM directly with Discord user mention syntax when a valid
  `gm_discord_user_id` is available.
- Do not use `@everyone`.
- Fall back to a no-mention GM display-name message if the GM Discord user ID is
  missing or invalid.

Payload boundary:

- content uses `<@id>` only in production payload after server-side and Edge-side
  validation
- docs and dry-run previews mask the mention as `<@GM>`
- `allowed_mentions.parse=[]`
- `allowed_mentions.users=[GM_ID]` when a valid GM ID is present
- `allowed_mentions.parse=[]` with no `users` entry when falling back
- `flags: 4` for suppressing session URL embeds

The first production version does not use Discord DM. A separate GM-only channel
or DM route can be considered after the channel-based flow is proven.

## Env / Secret Boundary

Chosen env names:

- `DISCORD_SESSION_REMINDER_WEBHOOK_URL`
- `SESSION_REMINDER_DISPATCH_TOKEN`
- `SESSION_REMINDER_REAL_SEND_ENABLED`

Policy:

- Secret values are never written to docs, source comments, commit messages, or
  reports.
- `DISCORD_SESSION_REMINDER_WEBHOOK_URL` should target the chosen existing
  notification channel for the first version.
- `SESSION_REMINDER_DISPATCH_TOKEN` gates manual or scheduled production
  dispatch calls.
- `SESSION_REMINDER_REAL_SEND_ENABLED` must remain disabled until a later
  production send gate explicitly enables it.
- Gate 8 does not set or modify any secret.
- Gate 8 does not enable real send.

Recommended secret setup order:

1. Set or confirm `DISCORD_SESSION_REMINDER_WEBHOOK_URL`.
2. Set or confirm `SESSION_REMINDER_DISPATCH_TOKEN`.
3. Keep `SESSION_REMINDER_REAL_SEND_ENABLED` absent or not equal to `true`.
4. Deploy/check runtime only in a separate gate.
5. Enable real send only in a later limited-send gate with explicit approval.

## Production Disabled Expectations

While `SESSION_REMINDER_REAL_SEND_ENABLED` is disabled:

- `dry_run:true` may call `preview_due_session_reminders`.
- `dry_run:true` must not send Discord.
- `dry_run:true` must not write DB.
- `dry_run:false` must reject before claim/send/finalize.
- `session_reminder_logs` must not grow.

Secret presence alone is not sufficient to allow production send. Real send
requires the enable flag, dispatch token validation, and the approved send gate.

## Reporting Rules

Allowed in docs/reports:

- function name
- env variable names
- HTTP status
- `ok` / error status
- `production_enabled` boolean
- counts
- reminder type
- redacted/masked mention facts such as `gm_mention_used=true`

Not allowed in docs/reports:

- Webhook URL
- project ref
- dispatch token
- Discord user ID
- channel ID
- provider message ID
- raw session URL
- full real message payload
- raw user ID or email
- JWT, service key, anon key, management key

## Next Gate Split

### Gate 9: Secret Setting Only, Real Send Disabled

Scope:

- Set or confirm `DISCORD_SESSION_REMINDER_WEBHOOK_URL`.
- Set or confirm `SESSION_REMINDER_DISPATCH_TOKEN`.
- Keep `SESSION_REMINDER_REAL_SEND_ENABLED` disabled.
- Do not deploy unless explicitly included.
- Do not invoke runtime unless explicitly included.
- Do not send Discord.
- Do not call claim/finalize.
- Do not write DB.

Expected result:

- secrets are configured or confirmed
- real send remains disabled
- no runtime send path is exercised

### Gate 10: Deploy / Runtime Secret Presence Check, Production Still Rejected

Scope:

- deploy only `dispatch-session-reminders` if source or env boundary requires
  redeploy confirmation
- call `dry_run:true`
- call `dry_run:false` only after `production_enabled:false` is confirmed
- confirm `dry_run:false` still rejects because real send is disabled
- confirm no Discord send and no `session_reminder_logs` growth

Expected result:

- Webhook/token presence does not accidentally enable production
- production remains rejected until `SESSION_REMINDER_REAL_SEND_ENABLED` is
  explicitly enabled in a later gate

### Gate 11: Limited Production Send Test

Scope:

- explicitly enable real send only for the test gate
- target a known candidate count, preferably `1`
- prefer GM confirmed reminder first because it does not use `@everyone`
- use claim/finalize
- stop on the first unexpected result
- record only sanitized counts/status

If the only available test is shortage, the gate must explicitly approve
`@everyone` even for a single message.

### Gate 12: Shortage `@everyone` Production Operation

Scope:

- final independent approval gate for shortage `@everyone`
- confirm target count immediately before send
- confirm the destination channel manually without recording IDs/URLs
- send only the approved target reminders
- confirm finalize status counts
- confirm no duplicate sends
- record only sanitized status/counts

## Rollback / Stop Boundary

If a later gate finds a problem:

- keep or return `SESSION_REMINDER_REAL_SEND_ENABLED` to disabled
- do not rotate or paste secrets into docs
- do not resend blindly
- check `session_reminder_logs` with SELECT-only status/counts
- do not delete or mutate reminder logs without a separate SQL gate
- stop cron/scheduled invocation if it has been configured in a later gate

Gate 8 does not require rollback actions because it changes docs only.

## Not Performed

- secret/Webhook setting or change
- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- `@everyone` send
- SQL Editor execution
- SQL apply
- DB/RPC/RLS mutation
- claim/finalize runtime execution
- `session_reminder_logs` write
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change
