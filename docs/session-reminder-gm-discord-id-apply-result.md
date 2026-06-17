# Session Reminder GM Discord ID Apply Result

Status: Gate 6.4 SQL apply completed by user. Codex did not execute SQL.

## Scope

Gate 6.4 applied the GM Discord ID return-column update for the service-role
session reminder RPCs:

- `preview_due_session_reminders(p_now timestamptz, p_limit integer)`
- `claim_due_session_reminders(p_now timestamptz, p_limit integer)`

The goal was to add:

- `gm_discord_user_id text`

This value remains service-role-only and is intended only for the reminder Edge
dispatcher. Real Discord IDs were not recorded in this document.

## First Apply Attempt

The first apply candidate failed with a SQL syntax error near `union`.

User-side recovery:

- stopped after the error
- ran `rollback`
- confirmed the existing RPCs were still present

Rollback-state confirmation:

- `preview_count=1`
- `claim_count=1`
- `preview_has_gm_discord_user_id=false`
- `claim_has_gm_discord_user_id=false`
- `all_security_definer=true`
- `service_role_can_preview=true`
- `service_role_can_claim=true`
- `anon/authenticated execute=false`
- `session_reminder_logs_count=0`

## Corrected Apply

The user then applied a corrected SQL version that avoids the failing `union`
shape and uses a no-UNION candidate construction.

Final SELECT-only confirmation:

- `preview_count=1`
- `claim_count=1`
- `preview_has_gm_discord_user_id=true`
- `claim_has_gm_discord_user_id=true`
- `all_security_definer=true`
- `service_role_can_preview=true`
- `service_role_can_claim=true`
- `anon_can_preview=false`
- `anon_can_claim=false`
- `authenticated_can_preview=false`
- `authenticated_can_claim=false`
- `session_reminder_logs_count=0`

The preview RPC body was not executed. Claim/finalize were not executed.
`session_reminder_logs` remained at count `0`.

## Corrected Candidate File

The apply candidate file was updated to match the corrected no-UNION shape:

- `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`

The file remains a documentation/apply reference. Codex did not run it.

## Safety Notes

Not performed by Codex in this recording step:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS mutation
- preview RPC runtime execution
- claim/finalize runtime execution
- `session_reminder_logs` write
- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- Webhook/secret change
- UI / HTML / CSS / browser JS change
- `updates.json` change

No real Discord user ID, Webhook URL, channel ID, message ID, token, JWT,
`management_key`, raw user ID, email, real session URL, or full message preview
was recorded.

## Next Gate

Gate 6.5 can update `dispatch-session-reminders` to use the now-applied
`gm_discord_user_id` field for GM-only mentions, with no deploy and no runtime
invocation.
