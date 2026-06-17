# Session Reminder Edge Dry-run Result

Status: Gate 4 dry-run dispatcher implemented, not deployed.

## Scope

Gate 4 added a Supabase Edge Function draft for session reminder dispatch preview.

Added file:

- `supabase/functions/dispatch-session-reminders/index.ts`

No Edge deploy, cron setup, SQL apply, DB/RPC/RLS change, Discord request, Webhook/secret change, or DB write QA was performed.

## Dry-run API

Expected request:

```json
{
  "dry_run": true,
  "now": "optional ISO timestamp",
  "limit": 20
}
```

Behavior:

- `dry_run` omitted: treated as safe dry-run.
- `dry_run: true`: runs preview only.
- `dry_run: false`: returns `production_not_enabled` and does not send Discord or write DB.
- `now` omitted: current timestamp is used.
- `limit` is clamped to a safe range, with default `20` and max `50`.

## RPC Use

Used RPC:

- `preview_due_session_reminders`

Not used:

- `claim_due_session_reminders`
- `finalize_session_reminder`
- `update_session_reminder_settings`

The function does not write `session_reminder_logs` and does not call any direct Supabase `.insert/.update/.delete/.upsert` operation.

## Response Shape

The dry-run response includes:

- `dry_run: true`
- `now`
- `count`
- `items`
- `safety`

Each item includes safe preview fields such as:

- `reminder_type`
- `session_id` / public session identifier from the preview RPC
- `title`
- `start_at`
- `min_players`
- `pending_count`
- `accepted_count`
- `waitlisted_count`
- `count_for_minimum`
- `shortage_count`
- `gm_display_name`
- `session_url`
- `message_preview`
- `discord_delivery_preview`

Docs and QA reports should not paste real `message_preview` output, real session URLs, raw identifiers, Discord identifiers, Webhook URLs, or provider message IDs.

## Message Generation

### Shortage Reminder

The dry-run builds a preview equivalent to the planned shortage reminder:

- includes `@everyone`
- includes session title
- includes session-detail URL
- includes local start time in Japan time
- includes shortage count

It also marks `discord_delivery_preview.allowed_mentions.parse` as `["everyone"]` and `suppress_embeds: true`, but no Discord request is made.

### GM Confirmed Reminder

The dry-run builds a GM-facing preview using:

- GM display name
- session title
- session-detail URL
- local start time in Japan time
- message that the minimum player count is satisfied

GM individual mention / DM is still not implemented. The first production direction remains an existing Discord notification channel with GM display name only.

## OGP / Embed Suppression

The preview records `suppress_embeds: true` in `discord_delivery_preview`.

The actual Discord payload and embed suppression behavior remain for the later production send gate. No Discord payload was sent in Gate 4.

## Verification

Static checks:

- `preview_due_session_reminders` is the only reminder dispatcher RPC used by the new function.
- `claim_due_session_reminders` is not called.
- `finalize_session_reminder` is not called.
- No Discord webhook fetch/send code was added.
- No `session_reminder_logs` write code was added.
- No direct Supabase `.insert/.update/.delete/.upsert` was added.
- `dry_run:false` returns `production_not_enabled`.
- No `console.*` was added.

`deno check`:

- `deno check --no-lock supabase/functions/dispatch-session-reminders/index.ts`: passed

## Limited / Not Tested

- Edge Function deploy: `not_tested`
- scheduled cron: `not_tested`
- preview RPC execution against production: `not_tested`
- Discord dry-run request/send: `not_tested`
- Discord production send: `not_tested`
- claim/finalize production flow: `not_tested`

## Next Gate Candidate

Recommended next gate:

- Gate 4.5: local/runtime dry-run invocation with safe fixture or approved non-production environment, or
- Gate 5: production send gate planning before any Discord send is enabled.

Before production send, confirm target Discord channel, OGP suppression payload, GM reminder destination, retry behavior, and exact reporting format without exposing raw identifiers or secrets.

## Safety Notes

No raw user identifiers, email addresses, tokens, JWTs, management keys, Discord identifiers, Discord URLs, Webhook URLs, provider message identifiers, or row-level values were recorded.
