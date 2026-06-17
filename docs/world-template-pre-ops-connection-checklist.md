# World Template Pre-Ops Connection Checklist

Date: 2026-06-17

Phase: 3-C8 pre-auth / pre-DB / pre-Discord checklist docs.

Baseline commit: `d191828 Plan campaigns episodes template structures`

This is a docs-only checklist. It does not include implementation, HTML, CSS,
JS, JSON/data, image, renderer, sample data, auth connection, DB connection,
RPC/RLS change, SQL Editor execution, SQL apply, Edge Function deploy,
Discord operation, secret/Webhook change, direct Supabase write, console
logging addition, `updates.json` change, permission logic change, or raw
id/email/token/JWT/management key display.

## Purpose

Phase 3-C1 through C7 documented the world-template side:

- next-world adoption procedure
- regulation sample data and data-module adoption
- scalable characters / spots / terms structures
- gallery and image asset boundaries
- scenarios / hooks structures
- page-by-page adoption checklist
- campaigns / episodes structures

This checklist defines the stop line before connecting operational surfaces:

- auth
- membership and approved gate
- DB/RPC/RLS
- Edge Functions
- Discord sync
- live session operation workflows

Use this document before moving from a static world-template site to a live
operations site.

## Stage Model

### Stage 1: Static World-Template Stage

Scope:

- `index`
- `world`
- `terms`
- `regulation`
- `characters`
- `spots`
- `scenarios`
- `hooks`
- `campaigns`
- `episodes`
- `gallery`
- optional `tools` / `updates`

Properties:

- public data only
- no auth dependency
- no DB dependency
- no Discord sync
- no real session operations
- GitHub Pages delivery checks are the main QA surface

Allowed checks:

- public HTML HTTP 200
- public JS and JSON/data HTTP 200
- image path checks
- broken import / 404 checks
- visible `undefined` / `[object Object]` checks
- public-data review for GM secrets and private information

Do not advance to operations until this stage is stable.

### Stage 2: Ops Core Static Connection Stage

Scope:

- `calendar`
- `session-post`
- `session-detail`
- `mypage`
- `timeline`
- admin surfaces, only if explicitly needed

Properties:

- screen structure can be reviewed
- static, fixture, mock, or dry checks only
- DB/RPC/RLS are not changed
- Discord production sync is not touched
- approved gate and auth flow are either unconnected, disabled, or recorded as
  limited

Allowed checks:

- page availability
- static import chains
- labels and empty states
- fixture rendering
- no data-changing operation
- no production Discord operation

Do not treat Stage 2 as proof that auth, DB, or Discord are ready.

### Stage 3: Auth Connection Preparation Stage

Scope:

- login/logout paths
- `mypage`
- profile display
- membership status display
- approved gate
- role/manager decisions

Properties:

- still preparatory
- no real user data should be copied into docs
- raw user ids, emails, tokens, JWT values, and actual management keys must not
  be displayed or recorded
- authenticated QA is a separate gate

Decision required:

- which pages are public
- which pages require login
- which pages require approved membership
- what unauthenticated users see
- what unapproved users see
- what profile fields are safe to display

### Stage 4: DB / RPC / RLS Connection Preparation Stage

Scope:

- Supabase schema
- RPCs
- RLS policies
- session posting
- session editing/deletion
- applications
- comments
- membership approval
- timeline and notifications

Properties:

- SQL Editor execution is an independent gate
- SQL apply is an independent gate
- RLS changes are independent gates
- RPC additions or changes are independent gates
- SELECT-only investigation and write tests must not be mixed
- DB write QA is a separate gate
- project-specific values and raw user data are not recorded in docs

Decision required:

- which surfaces truly need DB
- which surfaces can remain static or disabled
- which write workflows are allowed to be tested
- how rollback is recorded per SQL/RPC/RLS unit

### Stage 5: Discord / Edge Function Connection Preparation Stage

Scope:

- Discord sync client
- Edge Functions
- webhook/secret setup
- dry-run sync
- production posting
- production editing
- production deletion

Properties:

- Edge Function deploy is an independent gate
- secret setup is an independent gate
- dry run and production operation are separate gates
- production post, edit, and delete are separate gates
- webhook URLs, tokens, channel ids, message ids, and Discord URLs are not
  written into docs
- payload previews should be summarized, not pasted in full

Decision required:

- whether Discord sync is needed for the next world
- what counts as a duplicate post
- what retry policy is safe
- what rollback means after a message is already posted

## Pre-Auth Checklist

Before connecting auth:

- world-template pages are readable without auth where intended
- public pages and login-required pages are classified
- `calendar`, `session-detail`, `session-post`, `timeline`, and `mypage`
  public availability is decided
- approved-gate target pages are listed
- unauthenticated display state is defined
- unapproved-member display state is defined
- rejected/revoked/blocked-member display states are defined if used
- raw user ids, emails, JWT values, tokens, and actual management keys are not
  shown in UI, DOM, logs, or docs
- profile fields safe for display are listed
- profile fields that must stay private are listed
- membership / role / manager features are either adopted or explicitly
  deferred
- auth-unconfigured fallback is decided
- login/logout QA is separated from world-template public QA
- authenticated role matrix QA is a separate gate
- no auth or permission logic change is bundled with docs-only work

Recommended status labels:

- `not_configured`
- `disabled`
- `public_only`
- `limited`
- `not_tested`
- `ready_for_auth_gate`

## Pre-DB / Pre-RPC / Pre-RLS Checklist

Before connecting DB/RPC/RLS:

- features that require DB are classified
- features that can remain static are classified
- session post create/edit/delete workflows are separate from static display
- participation applications are separate write workflows
- comments are separate write workflows
- membership approval is a separate admin workflow
- timeline and notification generation are separate workflows
- SQL Editor execution is not part of docs-only work
- SQL apply is not part of docs-only work
- RLS changes are not part of docs-only work
- RPC additions or changes are not part of docs-only work
- direct Supabase insert/update/delete/upsert client writes are not introduced
  casually
- SELECT-only checks are separated from write checks
- DB write QA is a separate explicit gate
- project ref, project URL, anon key, service key, and private config values
  are not recorded in docs
- raw user ids and emails are not recorded in docs
- rollback plan is recorded per schema/RPC/RLS change before apply

Recommended classification:

- static only
- requires read RPC
- requires write RPC
- requires RLS change
- requires Edge Function
- requires authenticated QA
- requires data-changing QA

## Pre-Discord / Pre-Edge Checklist

Before connecting Discord or Edge Functions:

- decision is recorded: Discord sync needed or not needed
- world-template remains functional without Discord sync
- Edge Function deploy is planned as its own gate
- secret setup is planned as its own gate
- dry-run sync is separated from production sync
- production post is separated from production edit
- production edit is separated from production delete
- webhook URLs and secrets are not written into docs
- tokens are not written into docs
- channel ids are not written into docs
- message ids are not written into docs
- Discord URLs are not written into docs
- full payload previews are not pasted into docs
- allowed mentions / notification behavior is reviewed without recording
  secret values
- duplicate-post prevention is defined
- failed-sync retry policy is defined
- failed-sync rollback policy is defined
- production Discord operation requires a clear approval gate

Recommended status labels:

- `not_configured`
- `dry_run_only`
- `production_not_tested`
- `posting_not_tested`
- `editing_not_tested`
- `deletion_not_tested`
- `limited`

## Public-Only Checklist Before Ops

Before moving beyond public-only static delivery:

- all enabled world-template pages return HTTP 200
- `index`, `world`, `terms`, `regulation`, `characters`, `spots`,
  `scenarios`, `hooks`, `campaigns`, `episodes`, and `gallery` status is
  recorded as enabled, disabled, or intentionally absent
- public `main.js` and page renderers return HTTP 200
- public JSON/data paths return HTTP 200 and parse where applicable
- no broken import or module-load failure is observed
- no visible 404 is observed in referenced public assets
- no broken image icon is visible
- no visible `undefined` or `[object Object]` text appears
- zero-record and small-record states are checked or recorded as limited
- regulation data-module import chain is checked if regulation modules are used
- characters / spots / terms tolerate missing optional fields
- scenarios / hooks contain only public-safe information
- campaigns / episodes contain only public-safe recap information
- gallery assets are world-owned and rights-reviewed
- public data contains no real GM secrets
- public data contains no personal information or secret values
- Velgard-specific names, images, maps, and public copy are removed or
  intentionally re-authored
- OGP, favicon, logo, and hero images are either checked separately or recorded
  as deferred
- desktop/mobile visual review is recorded as `limited` if not completed
- auth pages are recorded as `not_configured`, `limited`, or `not_tested`
  before auth setup
- DB/RPC/RLS, Edge, Discord, and data-changing workflows are recorded as
  `not_tested`

## Independent Gates

The following must remain independent gates:

- SQL Editor execution
- SQL apply
- RLS changes
- RPC additions or changes
- Edge Function deploy
- secret / Webhook configuration
- Discord production posting
- Discord production editing
- Discord production deletion
- membership approval permission changes
- manager permission changes
- real session post create/edit/delete QA
- participation application write QA
- comment write QA
- cleanup apply
- bulk data changes
- auth role matrix QA
- production notification or timeline generation QA

Do not combine these with docs-only work, world-template copy changes, image
changes, or regulation data-module moves.

## Rollback And Recovery

If auth, DB, or Discord connection work fails:

1. First confirm the static world-template pages still render.
2. Separate the failure category: auth, DB schema, RPC, RLS, Edge deploy,
   secret setup, Discord operation, or front-end integration.
3. For DB/RPC/RLS, record rollback per changed unit.
4. For Discord, minimize the target surface: post, edit, or delete.
5. For Edge deploy, record before/after commit and function version status.
6. For secrets, record only `configured`, `rotated`, `not_configured`, or
   `not_tested` style status.
7. Do not paste secret values, raw ids, emails, tokens, JWT values, Discord
   URLs, Webhook URLs, channel ids, or message ids into docs.
8. Do not re-run a failing production action repeatedly.
9. Record the observed failure and suspected cause before retry.
10. Do not hide auth/DB/Discord problems by changing world-template data.
11. After rollback, re-check public HTML, JS, JSON/data, and image delivery.
12. Record remaining `limited` and `not_tested` scopes.

## Ownership Boundary

### World-Template Side

Owned by world-template:

- `index`
- `world`
- `characters`
- `spots`
- `terms`
- `regulation`
- `scenarios`
- `hooks`
- `campaigns`
- `episodes`
- `gallery`
- world-specific JSON/data
- images and maps
- NPC descriptions
- public lore text
- public rules and regulation copy
- public scenario/hook/campaign/episode summaries

### Reusable Ops Core Side

Owned by reusable ops core or ops-adjacent surfaces:

- `calendar`
- `session-post`
- `session-detail`
- `mypage`
- `timeline`
- membership display
- approved gate display
- session helpers
- reusable ops config
- Discord sync client
- auth-adjacent clients
- application/comment surfaces
- template management surfaces

These can link to world-template content, but they do not own world lore,
gallery assets, public scenario copy, or regulation meaning.

### External / Secret Side

Owned outside public world-template docs and data:

- Supabase project configuration
- Webhooks
- tokens
- Edge secrets
- Discord IDs
- user IDs
- emails
- JWT values
- actual management keys
- service credentials
- private operational logs
- private member data

Record only status-style results for this side.

## Next Candidate Options

Candidate A: ops core static connection dry-run checklist.

- Define how to review calendar, session-post, session-detail, mypage, and
  timeline with static fixtures or disabled states before auth/DB/Discord.

Candidate B: OGP / favicon / hero image rollout gate.

- Document identity-image replacement, cache-bust, public preview checks, and
  rollback for a next world.

Candidate C: tools / updates auxiliary page policy.

- Decide whether tools and updates are world-template, reusable utility, or
  disabled for a next world.

Candidate D: authenticated QA matrix plan.

- Define role-based QA only after auth connection is explicitly approved.

Recommended next candidate:

- Candidate A: ops core static connection dry-run checklist.

Reason:

- Stage 2 is the safest bridge after a public-only world-template launch.
- It can remain docs-only and avoid auth, DB/RPC/RLS, Edge deploy, Discord, and
  data-changing workflows.
- It gives the team a structured way to inspect ops pages without accidentally
  treating them as connected production operations.

## Phase 3-C9 Ops Static Dry-Run Checklist Follow-Up

Phase 3-C9 completes the recommended Stage 2 dry-run checklist:

- `docs/world-template-ops-static-dry-run-checklist.md`

Pre-ops impact:

- defines static dry-run purpose for `calendar`, `session-post`,
  `session-detail`, `mypage`, `timeline`, `tools`, and strict admin surfaces
- records what can be checked before auth/DB/Discord: HTTP 200, broken imports,
  cache-bust, config/helper imports, empty states, fixture display, and
  unconnected/gated-state documentation
- records what must not be checked in dry-run: SQL, DB write, RLS/RPC changes,
  Edge deploy, Discord production operations, real posting/editing/deleting,
  applications, comments, membership approval, manager grants, and cleanup
  apply
- documents conservative status labels such as `completed`, `limited`,
  `not_tested`, `not_connected`, `requires_auth`, `requires_db`,
  `requires_discord`, and `requires_separate_gate`
- defines conditions for advancing to auth, DB/RPC/RLS, or Discord/Edge gates
- recommends the next docs-only candidate:
  tools / updates auxiliary page policy

## Limited And Not Tested

This checklist is docs-only and does not add runtime QA.

Limited:

- stage definitions are based on current docs and known page ownership
- no browser public HTTP sweep was run in this phase
- no live next-world site exists in this phase
- no role matrix was exercised

Not tested:

- auth connection
- login/logout
- membership approval
- manager permissions
- session create/edit/delete
- participation application writes
- comment writes
- DB/RPC/RLS behavior
- SQL Editor execution
- SQL apply
- Edge Function deploy
- Discord dry run
- Discord production post/edit/delete
- secret configuration

## No Dangerous Work

This checklist did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, console logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, CSS class/DOM id/anchor change, `management_key` display, raw
id/email/token/JWT display, HTML change, CSS change, JS change, JSON/data
change, image change, renderer change, sample data creation, auth connection,
DB connection, or Discord connection.
