# Session Manual Recruitment Reminder Edge Result

Status: Gate MR-04 Edge Function source implemented, deploy not performed.

Added Edge Function source:

- `supabase/functions/send-session-recruitment-reminder/index.ts`

No Edge deploy, runtime invocation, Discord send, SQL execution, DB/RPC/RLS
change, secret change, cron change, UI change, or `updates.json` change was
performed.

## Request Shape

The function accepts HTTP `POST` JSON:

```json
{
  "session_id": "session key",
  "dry_run": true
}
```

`dry_run` defaults to `true` unless explicitly set to `false`.

## Dry-Run Path

Dry-run uses the caller's authenticated Supabase JWT and calls only:

- `preview_manual_recruitment_reminder(p_session_id text)`

Dry-run does not:

- claim a log row
- call finalize
- write to DB
- send Discord
- read or expose Webhook values

The dry-run response is status/count oriented and includes safe eligibility
fields such as `can_send`, `blocked_reason`, player counts, cooldown state, and
delivery-shape markers. It does not include Webhook URL, token, Discord message
id, raw user id, email, or secret values.

## Production Path

Production path is implemented but not deployed or executed in MR-04.

Production send requires:

- authenticated caller JWT
- `SESSION_REMINDER_REAL_SEND_ENABLED=true`
- configured Discord Webhook env

The production path performs these steps in order:

1. Rejects before claim if real send is not enabled.
2. Validates Discord Webhook configuration before claim.
3. Calls `claim_manual_recruitment_reminder(p_session_id text)` with the caller
   JWT so the DB can enforce GM/admin authorization using `auth.uid()`.
4. Sends Discord only after claim succeeds.
5. Calls `finalize_manual_recruitment_reminder(...)` with a service-role client.
6. Records `sent` on success or `failed` on send failure.

Discord message ids may be stored by the finalize RPC, but the function response
uses only a `discord_message_reference` marker and does not return message id
values.

## Discord Payload

Manual recruitment reminders use:

- `@everyone`
- `allowed_mentions.parse=["everyone"]`
- `flags: 4` for suppress embeds / OGP card suppression
- absolute `session-detail` URL from `PUBLIC_SITE_BASE_URL`

The Webhook env lookup prefers:

- `DISCORD_SESSION_RECRUITMENT_REMINDER_WEBHOOK_URL`

and falls back to:

- `DISCORD_SESSION_REMINDER_WEBHOOK_URL`

Webhook values are not recorded.

## Local Static Check

- `deno check --no-lock supabase/functions/send-session-recruitment-reminder/index.ts`
  passed

## Not Tested In MR-04

- Edge deploy
- runtime dry-run
- authenticated browser invocation
- production send
- Discord delivery
- claim/finalize execution
- DB write
- UI integration from `session-detail`

## Next Gate

Recommended next gates:

1. MR-05: deploy `send-session-recruitment-reminder` and confirm dry-run /
   production-disabled runtime behavior.
2. MR-06: UI integration from `session-detail` with dry-run/disabled send
   handling.
3. MR-07: explicit `@everyone` limited production send test.
