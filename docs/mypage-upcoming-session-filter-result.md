# Mypage upcoming-session start-time filter result

## Gate

Gate MP-01: hide started sessions from upcoming plans.

## Implementation

- The `accepted` application group now excludes sessions whose combined
  `date` and `start_time` is at or before the current instant.
- Session date/time is interpreted as Japan Standard Time (UTC+09:00),
  independent of the browser's local time zone.
- The boundary is strict: a session remains visible before its start instant
  and is removed at the start instant.
- Missing or invalid date/time values do not hide a session. This preserves the
  previous display for anomalous data instead of silently dropping it.
- Existing ended-status filtering remains in place. The new time comparison
  does not depend on session status.
- The filter runs only for the `accepted` group. Pending applications and other
  mypage sections are unchanged.
- The upcoming count and schedule summary use the filtered array length, so
  their counts match the rendered cards.

## Verification

- `node --check assets/js/mypageAuthClient.js`: completed.
- Pure date/time cases were checked for a past session, a same-day future
  session, the exact start boundary, a later future session, and missing or
  invalid date/time values.
- The mypage script cache-bust was updated in `mypage.html`.
- Authenticated browser display with live application data: `not_tested` in
  this gate.

## Exclusions

No SQL/DB change, Edge deploy, secret or cron change, Discord send,
`updates.json` change, or data write was performed.
