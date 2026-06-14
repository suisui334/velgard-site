# Reusable Ops Platform Phase 2-C Config Public Check

## Background

Phase 2-B moved the reusable operations config files into
`assets/js/core/config/`. Phase 2-C checks whether the public site is loading
the new paths and whether any active old root-path references remain.

This was a public asset and documentation check. No implementation change was
needed.

## Scope

Checked public delivery for:

- `calendar.html`
- `mypage.html`
- `session-post.html`
- `session-detail.html`
- public `main.js`
- public modules that import or bridge reusable operations config

The check did not perform authenticated visual QA, SQL execution, DB/RPC/RLS
changes, Edge Function deployment, Discord operations, direct Supabase writes,
or secret changes.

## Public Asset Check

| check_name | status | result_value | note |
| --- | --- | --- | --- |
| `public_calendar_html_main_cache_bust` | `pass` | `latest_main_cache_bust=true` | Public calendar HTML references the Phase 2-B `main.js` cache-bust. |
| `public_mypage_html_main_cache_bust` | `pass` | `latest_main_cache_bust=true` | Public mypage HTML references the Phase 2-B `main.js` cache-bust. |
| `public_mypage_bridge_path` | `pass` | `new_bridge_path=true` | Public mypage HTML loads `assets/js/core/config/reusableOpsMypageLabels.js`. |
| `public_session_post_html_main_cache_bust` | `pass` | `latest_main_cache_bust=true` | Public session-post HTML references the Phase 2-B `main.js` cache-bust. |
| `public_session_detail_html_main_cache_bust` | `pass` | `latest_main_cache_bust=true` | Public session-detail HTML references the Phase 2-B `main.js` cache-bust. |
| `public_main_import_cache_bust` | `pass` | `new_cache_bust=true; old_cache_bust=false` | Public `main.js` imports the Phase 2-B module cache-bust and no longer uses the previous session-label cache-bust. |
| `public_old_root_config_paths` | `pass` | `old_reusableOpsConfig=false; old_mypage_bridge=false` | Checked public JS for active old root config references. |
| `public_new_config_paths` | `pass` | `new_config=true; new_bridge=true` | Checked public JS for `assets/js/core/config/` references. |
| `public_config_exports_and_bridge` | `pass` | `module_export=true; mypage_bridge=true` | Public JS still contains `REUSABLE_OPS_CONFIG` and `VELGARD_REUSABLE_OPS_MYPAGE` markers. |

Conclusion:

- `public_core_config_path_ok=true`
- `public_old_root_config_path_present=false`
- `public_cache_bust_fix_needed=false`
- `public_config_bridge_preserved=true`

## Local Reference Check

Active local HTML/JS references also point at the new paths:

- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/core/config/reusableOpsMypageLabels.js`

Old root-path references remain only in historical docs that describe earlier
Phase 1/Phase 2-B work. No active HTML/JS needs a path fix.

## Display Compatibility Notes

Expected display behavior remains unchanged:

- Calendar session type labels and colors still resolve through the reusable
  config path with existing fallback labels.
- Mypage major headings still resolve through the classic-script bridge with
  existing fallback labels.
- Session-post and session-detail labels continue to use the reusable config
  import and fallback text.
- Approved-gate default labels continue to use the reusable config import and
  fallback text.
- Public asset checks found no indication that config lookup would produce
  `undefined`, `[object Object]`, empty headings, or empty buttons.

This gate did not run authenticated browser QA. If a client sees stale text or
labels after deployment, the likely first suspect is browser cache rather than
repository path state.

## Inventory

Moved config files:

- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/core/config/reusableOpsMypageLabels.js`

HTML/JS updated in Phase 2-B and confirmed by this check:

- `calendar.html`
- `mypage.html`
- `session-post.html`
- `session-detail.html`
- `assets/js/main.js`
- `assets/js/renderCalendar.js`
- `assets/js/sessionDisplay.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/membershipAccessClient.js`

Cache-bust status:

- `cache_bust_additional_fix_needed=false`

## Next Separation Candidates

Low-risk next candidates:

1. Continue display-label additions inside `assets/js/core/config/`.
2. Prepare a docs-only responsibility note for `assets/js/dataLoader.js`.
3. Prepare a world-site config plan for gallery categories and regulation
   display settings.
4. Perform a CSS selector responsibility audit before any CSS file split.

Still do not move yet:

- `assets/js/main.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/sessionData.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- `assets/css/style.css`

## Prohibited Work Confirmed

This gate did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge Function deploy, Discord operation, secret or webhook change,
direct Supabase write addition, `console.*` addition, `updates.json` change,
config-unrelated file movement, CSS splitting, `main.js` movement,
`mypageAuthClient.js` movement, `sessionData.js` movement, independent app
extraction, auth/permission logic changes, RPC/DB-key configuration, or
`management_key` display/DOM exposure.
