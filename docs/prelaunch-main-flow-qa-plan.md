# Prelaunch Main Flow QA Inventory

## Purpose

This inventory reviews the main public-site operation flows after recent
membership access controls, UI changes, and the first comment/application
approved-member RPC gate.

This is a non-destructive documentation and static review step. It does not
create, edit, or delete live data; does not run SQL Editor; does not apply SQL;
does not change DB/RPC/RLS; does not deploy Edge Functions; does not run
dry_run=false; and does not perform Discord operations.

## Baseline

- Latest baseline commit: `43c2469 Record comment application approved gate QA`.
- Comment/application approved-member gate:
  - 083 apply completed.
  - 084 SELECT-only confirmation returned all `ok`.
  - Functional QA confirmed approved users pass and unapproved/pending/rejected
    equivalent users are rejected for the four target RPCs.
- Frontend unapproved-user restrictions are implemented.
- Remaining approved-member gates for session post, player character,
  templates, notifications, TIMELINE, avatar, Discord sync, and GM/admin
  operations are still later gates unless otherwise noted.

## Static Review Summary

Code-level review points:

- `assets/js/main.js` marks `CALENDAR` and `TIMELINE` as requiring approved
  membership in the shared navigation.
- `assets/js/renderCalendar.js`,
  `assets/js/renderSessionDetail.js`,
  `assets/js/renderSessionPost.js`, and `assets/js/renderTimeline.js` call the
  membership access helper and render an approved-member notice when the current
  state is not approved.
- `assets/js/mypageAuthClient.js` keeps unapproved users on a minimal mypage
  account/status surface and does not show avatar, PC, template, schedule, or
  approval management panels unless the user is approved or otherwise
  authorized.
- `assets/js/sessionDetailApplicationComments.js` is the frontend call surface
  for the four comment/application RPCs gated by 083.
- `assets/js/sessionData.js` loads static session JSON only when an explicit
  development URL flag is present; normal UI should not resurrect static JSON
  fixture sessions.
- Discord create/update/delete sync entry points remain in
  `assets/js/renderSessionPost.js`, `assets/js/renderSessionDetail.js`, and
  `assets/js/discordSyncClient.js`; live create/update/delete QA can call the
  Edge Function with `dry_run=false`, so those flows require an explicit
  Discord-safe QA gate.
- `sessionDisplay.js` continues to show Discord sync status without external
  post URL or message ID details.
- Public profile display-name lookup uses `public_profiles` with
  `display_name` only in the inspected frontend path.

## Actor Matrix

### Not Logged In

Expected access policy:

- Static world/regulation/gallery/terms style pages remain publicly readable.
- `calendar`, `session-detail`, `timeline`, and `session-post` are community
  operation surfaces and require an approved account.
- Unauthenticated visitors cannot view session posts, apply, comment, create
  posts, edit posts, delete posts, or close posts.

Current static finding:

- `session-detail`, `calendar`, `timeline`, and `session-post` currently render
  the membership gate notice for non-approved states, including anonymous
  users.
- This is the intended access control behavior.

Required follow-up:

- No anonymous read-only session browsing fix is required.
- Later QA should confirm anonymous users see the approved-member gate on
  calendar/session-detail rather than the session content.

### Approved Normal User

Expected:

- Can view calendar and session detail.
- Can create session posts through the session-post UI.
- Can submit application comments, edit/delete owned eligible comments, and
  cancel owned eligible applications.
- Can use normal mypage panels.

Static/recorded state:

- Calendar, session detail, session post, and TIMELINE frontend gates allow
  approved membership.
- Comment/application RPC gate functional QA is complete and passed for the
  four target RPCs.
- Session post create/update/delete live QA remains a separate gate because it
  can create records and trigger Discord sync.

### Unapproved / Pending / Rejected User

Expected:

- Can log in and see minimal mypage account/status information.
- Cannot normally use community features such as calendar, session detail
  actions, applications, comments, PC management, templates, notifications,
  TIMELINE, avatar settings, or session-post forms.
- Direct comment/application RPC calls are rejected.

Static/recorded state:

- Mypage minimal unapproved view is implemented.
- Calendar, session detail, session post, and TIMELINE render approved-member
  guidance instead of the main UI.
- Comment/application RPC gate functional QA confirmed rejected behavior for
  pending/rejected-equivalent users.

Remaining risk:

- Other RPC categories are not yet all DB-gated. Frontend hiding is a normal
  operation guard, not a complete raw-RPC barrier for every feature.

### Session Owner

Expected:

- Can edit, delete, and close their own session post where current status and
  business rules allow it.
- Cannot accidentally leak raw IDs, external post IDs, or full post URLs.
- Existing Discord sync update/delete behavior remains unchanged unless a
  separate Discord gate is opened.

Static state:

- Session detail and session post management surfaces still call
  `update_session_post` / `delete_session_post` and wrap Discord sync via the
  existing client helpers.
- Delete flow attempts Discord cleanup before deleting when an existing synced
  Discord post is present.
- Live owner QA is deferred because it can modify live session posts and trigger
  Discord sync.

### Admin

Expected:

- Can access admin/GM management views where current permissions allow.
- Can see membership approval UI in mypage.
- Can manage applications/comments through the established admin/GM paths.
- General users cannot edit/delete/close others' session posts.

Static/recorded state:

- Membership approval UI/RPC functional QA is complete.
- GM/admin management-comment display was confirmed not broken during
  comment/application approved gate QA.
- Session owner/admin edit/delete/close permissions need live end-to-end QA in
  a separate safe gate because they can update live records and Discord sync
  state.

## Main Flow Inventory

| Flow | Static state | Live QA status | Next action |
| --- | --- | --- | --- |
| Session post create | Approved frontend gate present; create RPC path still used from session-post UI; Discord create sync remains wired | Not run in this inventory | Explicit create QA gate with Discord-safe plan |
| Session detail display | Approved frontend gate present for anonymous/unapproved users as intended | Not run in this inventory | Live approved/unapproved display QA later |
| Application/comment create | Four target RPCs DB-gated and functional QA passed | Confirmed | No immediate follow-up for first gate |
| Application cancel | DB-gated and functional QA passed | Confirmed | No immediate follow-up for first gate |
| Comment edit/delete | DB-gated and functional QA passed | Confirmed | No immediate follow-up for first gate |
| GM/admin management display | Not visibly broken in latest functional QA | Confirmed for this gate | Broader admin workflow QA later |
| Mypage | Approved vs unapproved split is implemented; approval UI QA passed | Partly confirmed | Prelaunch visual/empty-state QA later |
| Calendar | Approved frontend gate present; type color, close mark, GM name rendering still in code | Not run in this inventory | Live visual QA later |
| Discord sync | Client wiring unchanged; external post URL/message ID details hidden in display | Not run; intentionally untouched | Separate Discord dry-run/live gate only |
| Static JSON fixtures | Normal load excludes static sessions unless explicit dev URL flag is present | Static confirmed | No action unless fixture flag behavior changes |
| public_profiles exposure | Frontend inspected path selects `display_name` only; latest SQL checks showed no membership/role exposure | Static/SQL-record confirmed | Recheck when profile view/RPC changes |

## Required Live QA Gates

The following require explicit later gates because they can create, edit, delete,
or synchronize live data:

1. Approved session-post create/update/delete QA.
2. Session owner edit/delete/close QA.
3. Discord create/update/delete sync QA, including no duplicate post and no
   unintended mention checks.
4. Anonymous/unapproved access-gate display QA for calendar and session-detail.
5. Calendar visual QA for type colors, close mark, and GM name after safe test
   data is selected.
6. Mypage empty-state and status-state visual QA for approved/unapproved/admin
   accounts.
7. Broader admin/GM application management QA.

## Stop Conditions For Later Live QA

Stop before live QA if any of these are needed or likely:

- SQL Editor execution, SQL apply, or DB/RPC/RLS change.
- Edge Function deploy.
- dry_run=false or Discord operation outside an explicitly approved Discord QA
  gate.
- Secret/Webhook change.
- Exposure or recording of concrete user ID, email, session ID, application ID,
  comment ID, Discord message/channel ID, full post URL, JWT, token, project
  identifier, or Webhook URL.
- Broad production data pollution or unclear cleanup ownership.

## Current Conclusion

- The first DB/RPC-side comment/application approved-member gate is complete:
  083 applied, 084 checked, and functional QA passed.
- The main-flow static inventory did not find evidence that static JSON fixtures
  returned to normal UI or that membership/role state is exposed through the
  inspected public profile path.
- Anonymous and unapproved users are intentionally blocked from
  `calendar` and `session-detail` by the approved-member gate. The previous
  read-only expectation was a documentation interpretation error and is not a
  required fix.
- The remaining major flows need explicit live QA gates because they can mutate
  live data or touch Discord sync.

No concrete identifiers, email addresses, tokens, full URLs, Discord message
IDs, project identifiers, Webhook URLs, or secrets are recorded in this
inventory.
