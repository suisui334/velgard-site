# Session Reminder GM Mention Result

Status: Gate 6.1 blocked before code change.

## Scope

Gate 6.1 reviewed whether `gm_confirmed` session reminders can mention the GM directly in Discord.

Requested policy:

- shortage reminder keeps `@everyone`
- GM confirmed reminder uses a Discord user mention for the GM only
- GM confirmed reminder does not use `@everyone`
- `allowed_mentions` for GM confirmed should be `parse=[]` plus the specific GM Discord user id
- dry-run previews and docs must not expose the actual Discord user id

No source change was made in this gate because the required GM Discord user id is not available in the current reminder RPC result.

## Existing Data Path Review

Current reminder RPC result fields were reviewed in:

- `docs/sql-drafts/session-reminder-notifications-apply-candidate.sql`
- `supabase/functions/dispatch-session-reminders/index.ts`

`preview_due_session_reminders` currently returns:

- session and reminder identifiers
- title / start time / player counts
- `gm_display_name`
- reminder timing / routing fields
- `session_public_id`

`claim_due_session_reminders` currently returns the same reminder delivery fields plus:

- `log_id`
- `lock_token`

Neither RPC currently returns a safe GM Discord user id, masked GM mention, or profile contact field for the session GM.

## Related Existing Discord ID Structures

Existing contact structures were found:

- `profiles.discord_handle`
- `get_my_profile_contact()`
- `update_my_discord_id(text)`
- `get_gm_session_accepted_contacts(text)`
- frontend GM contact formatting in `assets/js/sessionDetailApplicationComments.js`

These are useful precedents for Discord ID storage and safe mention formatting, but they do not currently give `dispatch-session-reminders` a GM-owned Discord id for the claimed reminder row.

Important distinction:

- `get_gm_session_accepted_contacts(text)` is for GM/admin viewing accepted participant contact rows.
- The reminder dispatcher needs the session GM's own Discord user id in the service-role preview/claim path.
- Reusing accepted participant contact data would not reliably identify the GM and would blur ownership boundaries.

## Blocker

Gate 6.1 meets the blocker condition:

- `preview_due_session_reminders` / `claim_due_session_reminders` do not return a GM Discord id.
- A safe existing RPC path for the dispatcher to obtain the session GM's Discord id was not found.
- Adding the required value appears to require a SQL/RPC change.

Because of this, the Edge Function production code was not changed.

## Required Follow-up

Next gate should draft a SQL/RPC change that adds a safe GM mention source to the reminder delivery result.

Candidate next gate:

- Gate 6.2: GM Discord ID reminder SQL/RPC draft

Candidate fields to add to `preview_due_session_reminders` and `claim_due_session_reminders`:

- `gm_discord_user_id text`
- optional masked preview field such as `gm_discord_mention_preview text`
- optional boolean such as `gm_discord_mention_available boolean`

Recommended SQL source:

- join `public.sessions.gm_user_id` to the GM's profile row
- read the same safe stored contact value used for Discord contact registration
- only return a value if it is a valid Discord snowflake-like user id
- return null if missing or invalid

Recommended Edge behavior after SQL/RPC update:

- production content can include `<@gm_discord_user_id>` only for `gm_confirmed`
- production payload uses `allowed_mentions.parse=[]`
- production payload uses `allowed_mentions.users=[gm_discord_user_id]`
- dry-run `message_preview` masks the mention as `<@GM>`
- runtime responses and docs do not include the real Discord user id
- if the id is missing, fall back to GM display name with no mention and `allowed_mentions.parse=[]`

## Not Performed

- Edge Function deploy
- runtime invocation
- Discord send
- Discord dry-run send
- Webhook/secret setting or change
- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- claim RPC runtime execution
- finalize RPC runtime execution
- `session_reminder_logs` write
- cron setup
- UI / HTML / CSS / browser JS change
- `updates.json` change
- `console.*` addition
- direct Supabase write helper addition

## Verification

Static review only:

- confirmed current reminder SQL draft/apply candidate has `gm_display_name` but no GM Discord id return column
- confirmed current Edge Function row types have `gm_display_name` but no GM Discord id field
- confirmed existing Discord ID/contact flows are not sufficient for dispatcher GM mention without SQL/RPC work

## Next Gate Candidate

Recommended next gate:

- Gate 6.2: draft SQL/RPC update for GM Discord ID in reminder preview/claim results

Gate 6.2 should still avoid SQL apply until a later explicit gate.

## Gate 6.2 Follow-up Result

Gate 6.2 confirmed a safe draft source and created the SQL/RPC draft.

Created:

- `docs/sql-drafts/session-reminder-gm-discord-id-draft.sql`
- `docs/session-reminder-gm-discord-id-sql-checklist.md`
- `docs/session-reminder-gm-discord-id-result.md`

Source decision:

- use `public.sessions.gm_user_id` to identify the session GM
- join to `public.profiles.id`
- read `public.profiles.discord_handle`
- return it as `gm_discord_user_id` only when it matches `^[0-9]{17,20}$`
- return `null` when missing or invalid

The draft keeps `preview_due_session_reminders` and `claim_due_session_reminders` service-role-only and does not expose Discord ids to browser/public RPCs.

Still not performed:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge deploy
- runtime invocation
- Discord send
- DB write

Next gates:

- Gate 6.3: GM Discord ID RPC apply candidate review
- Gate 6.4: SQL apply independent approval
- Gate 6.5: Edge Function GM mention implementation, no deploy

## Gate 6.3 Follow-up Result

Gate 6.3 reviewed the SQL/RPC draft and created an apply candidate.

Created:

- `docs/sql-drafts/session-reminder-gm-discord-id-apply-candidate.sql`

Updated:

- `docs/session-reminder-gm-discord-id-sql-checklist.md`
- `docs/session-reminder-gm-discord-id-result.md`

Review summary:

- `gm_discord_user_id text` is included in both
  `preview_due_session_reminders` and `claim_due_session_reminders`
- source remains `public.sessions.gm_user_id` ->
  `public.profiles.id` -> `public.profiles.discord_handle`
- the value is returned only when it matches `^[0-9]{17,20}$`
- service-role-only execution is preserved
- browser/public RPCs are not given Discord user IDs
- post-apply checks remain SELECT-only

Still not performed:

- SQL Editor execution
- SQL apply
- DB/RPC/RLS change
- Edge Function change
- Edge deploy
- runtime invocation
- Discord send
- DB write

Next gate:

- Gate 6.4: SQL apply independent approval and SELECT-only confirmation.

## Gate 6.4 / 6.5 Follow-up Result

Gate 6.4 apply result:

- First SQL attempt failed near `union`.
- The user rolled back and confirmed the old RPCs were retained.
- A corrected no-UNION SQL version was applied successfully by the user.
- `gm_discord_user_id` is now present in both reminder preview/claim RPC return
  definitions.
- Both RPCs remain service-role-only.
- anon/authenticated execute remains false.
- `session_reminder_logs_count=0`.
- Preview body, claim, and finalize were not executed.
- No real Discord ID was recorded.

Gate 6.5 implementation result:

- `dispatch-session-reminders` now accepts `gm_discord_user_id` from the
  service-role RPC result.
- Edge code validates it with `^[0-9]{17,20}$` before use.
- `gm_confirmed` production content uses `<@id>` only when the value is valid.
- GM payload uses `allowed_mentions.parse=[]` and
  `allowed_mentions.users=[id]` only for that one GM user.
- Missing/invalid ID falls back to no mention.
- Dry-run preview masks the mention as `<@GM>` and exposes no raw ID.
- Production response exposes no raw ID.

Still not performed:

- Edge deploy
- runtime invocation
- Discord send
- DB write
- Webhook/secret change
