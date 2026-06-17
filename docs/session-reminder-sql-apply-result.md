# Session Reminder SQL Apply Result

Status: Gate 2 user-side SQL apply result recorded.

This document records the user-reported SELECT confirmation results for the session reminder SQL apply. Codex did not run SQL Editor, did not apply SQL, and did not inspect live DB rows.

## Apply Status

- SQL apply: `completed_by_user`
- SQL Editor execution by Codex: `not_run`
- SQL apply by Codex: `not_run`
- DB/RPC/RLS mutation by Codex: `not_run`
- Edge Function deploy: `not_run`
- Discord dry-run: `not_run`
- Discord production send: `not_run`
- Secret/Webhook change: `not_run`
- UI implementation in Gate 2: `not_run`

## SELECT Confirmation

User-reported results:

| Check | Result |
| --- | --- |
| `sessions_reminder_columns` | `4 / expected 4` |
| `sessions_reminder_constraints` | `2 / expected 2` |
| `session_reminder_logs_table` | `true` |
| `session_reminder_logs_constraints` | `6 / expected 6` |
| `session_reminder_logs_rls` | `rls_enabled=true`, `rls_forced=false` |
| `session_reminder_logs_direct_privileges.anon_select` | `false` |
| `session_reminder_logs_direct_privileges.authenticated_select` | `false` |
| `session_reminder_logs_direct_privileges.authenticated_insert` | `false` |
| `session_reminder_logs_direct_privileges.authenticated_update` | `false` |
| `session_reminder_logs_direct_privileges.authenticated_delete` | `false` |
| `session_reminder_rpc_exists` | `4` |
| `session_reminder_rpc_privileges.authenticated_can_update_settings` | `true` |
| `session_reminder_rpc_privileges.anon_can_update_settings` | `false` |
| `session_reminder_rpc_privileges.service_role_can_preview` | `true` |
| `session_reminder_rpc_privileges.authenticated_can_preview` | `false` |
| `session_reminder_rpc_privileges.service_role_can_claim` | `true` |
| `session_reminder_rpc_privileges.service_role_can_finalize` | `true` |
| `sessions_count_after_apply` | `9` |
| `default_enabled_rows_after_apply.shortage_enabled_count` | `0` |
| `default_enabled_rows_after_apply.gm_enabled_count` | `0` |
| `session_reminder_logs_count_after_apply` | `0` |
| preview RPC | `not_run` |

Reported RPC presence:

- `claim_due_session_reminders`
- `finalize_session_reminder`
- `preview_due_session_reminders`
- `update_session_reminder_settings`

## Result Summary

- Reminder columns exist.
- Reminder setting constraints exist.
- Reminder log table exists.
- Reminder log table RLS is enabled.
- Direct table privileges for anon/authenticated are not exposed in the reported checks.
- Reminder RPCs exist.
- Settings update RPC is available to authenticated users and not available to anon.
- Preview/claim/finalize RPCs are service-role oriented in the reported privilege checks.
- Existing sessions were not automatically enabled for reminders.
- Reminder log count is zero after apply.
- Preview RPC was not executed.

## Safety Notes

No raw user identifiers, email addresses, tokens, JWTs, management keys, Discord identifiers, Discord URLs, Webhook URLs, provider message identifiers, or row-level values were recorded in this document.

## Next Gate Consideration

Gate 3 UI implementation requires the session-post edit flow to receive the four reminder setting columns:

- `shortage_reminder_enabled`
- `shortage_reminder_hours_before`
- `gm_reminder_enabled`
- `gm_reminder_minutes_before`

If the current edit fetch contract does not include these columns, UI implementation must stop until the session retrieval contract is updated in a separate approved gate.
