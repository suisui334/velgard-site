# Repeatable Shortage Reminder Rollout Result

Status: Gate SR-03 rollout completed and automatic real send restored.

## Applied Change

The user applied the reviewed shortage revision SQL in the independent SR-03
SQL gate. Codex did not execute SQL in this recording/restoration gate.

The applied behavior is:

- shortage reminders use
  `(session_id, reminder_type, shortage_reminder_revision)`
- GM confirmed reminders continue to use `(session_id, reminder_type)`
- the shortage revision increments only when `date`, `start_time`, shortage
  enabled state, or shortage offset changes
- unrelated session edits preserve the current shortage revision
- preview returns the current shortage revision and claim writes that exact
  revision into the claimed log
- repeated cron ticks cannot claim the same shortage revision twice
- reaching the minimum player count still excludes the shortage candidate

## Post-Apply Confirmation

The user reported that all `16 / 16` post-apply checks succeeded.

Confirmed areas included:

- session revision column, CHECK, trigger, and trigger markers
- log revision column, type-specific CHECK, and direct-access boundary
- shortage revision and GM confirmed partial unique indexes
- no invalid or duplicate revision groups
- historical log/session revision alignment
- all four reminder RPCs and their security-definer boundary
- service-role/authenticated EXECUTE boundaries
- preview/claim return shapes and revision-flow markers

The return-shape check reports:

- preview revision `ordinal_position = 19`
- claim revision `ordinal_position = 21`

These values are expected. `information_schema.parameters.ordinal_position`
counts the two input parameters before the OUT columns. The actual OUT-column
counts remain preview `17` and claim `19`, with
`shortage_reminder_revision` as the final OUT column in each RPC.

## Production Restoration

Before SQL apply, automatic real send was temporarily disabled while the
every-minute cron remained installed and active.

In Gate SR-03D:

- `SESSION_REMINDER_REAL_SEND_ENABLED` was set back to enabled
- the secret name was confirmed without reading or recording its raw value
- no Edge Function deploy was needed
- no cron setting was changed
- no manual Discord send test was run

The existing every-minute cron can now dispatch due reminders automatically.
Shortage reminders may be sent again after a schedule-relevant revision change;
GM confirmed reminder duplicate behavior remains unchanged.

## Current Operation

- automatic dispatcher: active through the existing every-minute cron
- automatic real send: enabled
- shortage duplicate unit: session/type/revision
- GM duplicate unit: session/type
- manual Discord test in SR-03D: not performed
- Edge deploy in SR-03D: not performed
- cron change in SR-03D: not performed
- SQL/DB change by Codex in SR-03D: not performed
- `updates.json` change: not performed

No project reference, JWT, token, Webhook, Discord identifier, message
identifier, session identifier, or message body was recorded.
