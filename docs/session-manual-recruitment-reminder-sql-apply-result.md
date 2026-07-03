# Session Manual Recruitment Reminder SQL Apply Result

Status: Gate MR-03 SQL apply and SELECT-only confirmation recorded.

The SQL apply was performed by the user. Codex did not execute SQL, apply DB
changes, mutate RPC/RLS, deploy Edge Functions, send Discord messages, change
secrets, or change `updates.json` in this recording gate.

## Confirmed Result

The user reported the following SELECT-only confirmation results:

- log table exists: `true`
- RLS enabled: `true`
- direct table privileges: `false`
- constraints: `8`
- claimed unique index: `1`
- cooldown index: `1`
- RPC count: `3`
- `security definer` / fixed `search_path`: `OK`
- `authenticated`: preview/claim allowed, finalize not allowed
- `service_role`: finalize allowed
- log count: `0`

## Boundary

The confirmed objects are:

- `public.session_manual_recruitment_reminder_logs`
- `public.preview_manual_recruitment_reminder(text)`
- `public.claim_manual_recruitment_reminder(text)`
- `public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)`

Direct browser table access remains closed. Manual recruitment reminder sends
are expected to go through reviewed RPCs only.

## Not Recorded

No concrete session id, user id, Webhook URL, token, Discord id, Discord message
id, full session URL, or full Discord message body is recorded here.

## Next Gate

Gate MR-04 implements the Edge Function source for:

- dry-run preview with the caller JWT
- production claim with the caller JWT
- service-role finalize after Discord send

MR-04 still does not deploy, call runtime, send Discord, change secrets, or
write to the database.
