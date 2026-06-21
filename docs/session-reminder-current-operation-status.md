# Session Reminder Current Operation Status

Status: Gate 12G production-disabled scheduler operation recorded.

## Current Operation State

The session reminder automatic check foundation is installed but production
sending is still disabled.

Current scheduler state:

- cron job `dispatch-session-reminders-every-minute` exists
- cron job id: `2`
- cron job count: `1`
- schedule: `* * * * *`
- job active: true
- each tick invokes `dispatch-session-reminders`
- payload markers:
  - `dry_run:false`: true
  - `limit:1`: true
- required Vault secret count: `3/3`

Production-disabled state:

- real send remains disabled
- recent pg_net responses include HTTP `403`
- HTTP `403` rows include a production-disabled marker
- no sent-count success marker was observed
- Discord send has not occurred through scheduler automation
- `session_reminder_logs` count remains `1`

Manual send history:

- one manual `gm_confirmed` production send succeeded in the previous bounded
  production gate
- that manual send created the existing single reminder log row

Not started:

- scheduler automatic production send
- shortage reminder send
- `@everyone` send
- shortage production operation
- failed/skipped reset or retry tooling

## Gate 12G Confirmation

Gate 12G rechecked the scheduler after cron creation:

- cron job count: `1`
- recent cron run status: `succeeded`
- recent cron run count observed: `13`
- recent pg_net `403` rows with production-disabled marker: observed
- `session_reminder_logs` count: `1`

No response body, Function URL, JWT, dispatch token, Webhook URL, project ref,
Discord ID, session id, message id, request headers, or message text was
recorded.

## Safety Boundary

Still not performed:

- real-send enablement
- scheduler automatic production send
- Discord send through scheduler
- `@everyone` send
- shortage send
- Edge deploy
- SQL structure change after scheduler creation
- cron change after scheduler creation
- secret change in Gate 12G
- UI / HTML / CSS / browser JS change
- `updates.json` change
- raw secret, response body, or provider id recording

## Next Gate Candidates

Recommended next gates:

1. Gate 12H: GM automatic scheduler send test with bounded target count and
   explicit approval.
2. Gate 12I: shortage `@everyone` production planning only.
3. Gate 12J: shortage `@everyone` final approval and bounded production
   operation.

## Gate 12H GM Automatic Send Preflight

Gate 12H attempted to start a bounded GM automatic scheduler send test, but
stopped at preflight.

Preflight result:

- current time was used
- no `now` override was used
- `dry_run:true` HTTP status: `200`
- `count`: `0`
- `gm_confirmed` count: `0`
- shortage count: `0`
- `@everyone` marker: false
- raw Discord ID pattern: false
- `session_reminder_logs` before/after: `1` -> `1`

Because the preflight did not return exactly one `gm_confirmed` candidate,
real send was not enabled and the scheduler automatic production send test was
not attempted.

Current state after Gate 12H:

- scheduler automatic checks remain active
- real send remains disabled
- scheduler automatic production send remains not started
- Discord send did not occur
- shortage `@everyone` did not occur

## Gate 12I Real Send Enabled

Gate 12I enabled automatic production delivery for session reminders.

Result doc:

- `docs/session-reminder-real-send-enabled-result.md`

Preflight result before enablement:

- current-time `dry_run:true` was executed without `now` override
- HTTP status: `200`
- `count`: `0`
- `gm_confirmed` count: `0`
- shortage count: `0`
- `@everyone` marker: false
- raw Discord ID pattern: false
- `session_reminder_logs` before: `1`

Enablement and observation:

- `SESSION_REMINDER_REAL_SEND_ENABLED=true` was set
- scheduler cron was not changed
- Edge Function was not redeployed
- observed approximately 2 to 3 minutes after enablement
- recent pg_net rows included HTTP `200`
- recent 5-minute HTTP `200` response count observed: `10`
- `session_reminder_logs` before/after: `1` -> `1`
- reminder log growth: `0`

Current state after Gate 12I:

- scheduler automatic checks remain active
- real send is enabled
- future due candidates may be sent automatically by cron
- no new Discord send was indicated during the observation window
- shortage `@everyone` did not occur during the observation window

## Gate 13A Discord URL Clickable Source Fix

Gate 13A fixed reminder message URL generation in source so Discord messages
use an absolute `session-detail` URL instead of a relative
`session-detail.html?id=...` URL.

Result doc:

- `docs/session-reminder-discord-url-fix-result.md`

Updated source:

- `supabase/functions/dispatch-session-reminders/index.ts`

Summary:

- reviewed the existing session-post Discord sync absolute URL pattern
- kept `PUBLIC_SITE_BASE_URL` as the first source
- added scheduler-safe fallback base URL behavior
- applied the shared absolute session-detail URL path to both `gm_confirmed`
  and `shortage`
- kept Discord payload `flags: 4`
- kept shortage `allowed_mentions.parse=["everyone"]`
- kept GM reminder mention restrictions

Gate 13A did not deploy the Edge Function, send Discord, change real-send
state, change cron, change SQL, or change secrets. The deployed Function keeps
the previous URL behavior until a later explicit deploy gate.
