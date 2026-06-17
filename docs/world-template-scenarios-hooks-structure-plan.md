# World Scenarios Hooks Structure Plan

Date: 2026-06-17

Phase: 3-C5 scenarios / hooks template structures docs.

Baseline commit: `ffb4ba2 Document world image asset boundaries`

This is a docs-only plan. It does not include implementation, HTML, CSS, JS,
JSON/data, sample data, scenario/hook text, image file, renderer,
session-post, session-detail, `updates.json`, SQL, DB/RPC/RLS, Edge Function,
Discord, Supabase direct write, console logging, auth, membership, or secret
changes.

## Purpose

Scenarios and hooks sit between world content and live play operations.

For a next world, they should describe adventure seeds, scenario ideas, public
premises, and ways to play the setting. They should not become the source of
truth for actual session recruitment, attendance, comments, Discord sync, or
DB-backed operations.

This plan documents a scale-variable template structure for:

- hooks as lightweight adventure seeds
- scenarios as more concrete one-shot, chapter, or campaign scenario entries
- compatibility decisions between `hooks` and `scenarios`
- public information versus GM-only or spoiler information
- boundaries from reusable ops core

## Current Velgard Inventory

Current pages:

- `scenarios.html`: official SCENARIOS entry page
- `hooks.html`: compatibility entry page; currently routed to the same
  renderer as scenarios
- `scenario-detail.html`: scenario detail page

Current renderers and routes:

- `assets/js/main.js` maps both `scenarios` and `hooks` page keys to
  `renderScenarios`
- `assets/js/main.js` maps `scenario-detail` to `renderScenarioDetail`
- `assets/js/renderScenarios.js` loads
  `data/scenarios.json?v=20260529-scenario-release-base`
- `assets/js/renderScenarioDetail.js` loads the same scenarios data, plus
  spots and characters for related labels
- `assets/js/renderSpotDetail.js` reads `relatedScenarioIds` from
  `data/spotDetails.json` and links to `scenario-detail.html?id=...`

Current data:

- `data/scenarios.json`: 7 records, all `status: "public"`, all
  `releaseStatus: "preparing"`
- `data/hooks.json`: 7 records with matching ids, kept as compatibility /
  comparison data and not the active list source
- current shared ids:
  - `railway-incidents`
  - `flower-mist-valley-cases`
  - `coexistence-negotiation`
  - `mining-industrial-cases`
  - `rift-anomalies`
  - `smuggling-underworld`
  - `grayname-records`

Current `data/scenarios.json` fields:

- `id`
- `title`
- `category`
- `genre`
- `image`
- `summary`
- `description`
- `examples`
- `relatedSpots`
- `relatedCharacters`
- `status`
- `releaseStatus`

Current `data/hooks.json` fields:

- `id`
- `title`
- `category`
- `genre`
- `image`
- `summary`
- `description`
- `examples`
- `relatedSpots`
- `relatedCharacters`
- `status`

Current renderer behavior:

- `isVisible(item)` controls public display via `status`
- scenario categories are collected from visible `category` values
- list cards show image, release badge, category, genre, title, summary, and a
  detail link
- images use the `hook` placeholder type from `data/site.json`
- detail pages show a hero, release section, related spots, and related NPCs
- detail release data can later use `textUrl`, `pdfUrl`, `releaseDate`,
  `version`, `lastUpdated`, and `fileNote`
- TXT body loading is public `fetch(textUrl)` and uses `textContent`
- there is no current DB/RPC/Discord/auth dependency in scenario rendering

Current related docs:

- `docs/scenario-file-policy.md` records TXT/PDF release policy and warns
  against publishing GM-secret scenario content without review.

## Role Separation

### World-Template Side

Scenarios / hooks own world-facing content such as:

- world hooks
- scenario ideas
- adventure seeds
- public introduction premises
- short playable proposals
- campaign chapter concepts
- public GM-facing framing guidance when intentionally published
- play-style suggestions for the setting
- related public NPC, spot, term, and gallery references

This data is authored per world and replaced for each next world.

### Reusable Ops Core Side

Reusable ops core owns live operations such as:

- actual session recruitment
- schedule and calendar entries
- participant applications
- comments
- `session-post`
- `session-detail`
- Discord sync
- DB/RPC/RLS
- membership and auth
- owner/admin/role behavior

Scenarios / hooks may link to an eventual session-post or session-detail flow,
but that link does not transfer data ownership. A scenario idea is not a live
session, and a live session is not the source of truth for world-template
scenario copy.

## Scale Policy

Scenarios / hooks should support these next-world states:

- zero visible hooks or scenarios
- a hidden or "coming soon" page during early launch
- a few lightweight adventure hooks
- several one-shot scenario proposals
- campaign chapters or arcs
- draft ideas kept outside public data
- complete, preparing, archived, or idea-only display states
- records without related NPCs, spots, terms, gallery entries, images,
  categories, or tags

Do not require a fixed record count.

Do not require a next world to keep both `hooks` and `scenarios`. The next
world should decide one of these patterns:

- keep only `scenarios` and use it for both seeds and developed scenarios
- keep `hooks` as lightweight seeds and `scenarios` as developed entries
- keep `hooks.html` only as a compatibility redirect or alias
- remove the hooks compatibility path behind a separate implementation gate

## Hooks Template Structure

Hooks are best treated as lightweight adventure seeds.

### Current Definition

Current Velgard hook-like data exists in:

- `data/hooks.json`
- `data/scenarios.json`

Current public rendering is scenario-driven:

- `hooks.html` has `data-page="hooks"`
- `main.js` routes `hooks` to `renderScenarios`
- `renderScenarios` reads `data/scenarios.json`, not `data/hooks.json`

For a next world, this compatibility choice should be made before adding new
records.

### Hook Field Policy

Minimum fields:

- `id` or `slug`
- `title`
- `summary`
- `visibility` or a local public/draft state

Useful optional fields:

- `category`
- `tags`
- `genre`
- `recommendedLevel`
- `image`
- `body` or `description`
- `examples`
- `relatedSpots`
- `relatedCharacters`
- `relatedTerms`
- `relatedGalleryIds`
- `sortOrder`
- `status` if the existing `isVisible` helper remains in use

Required-looking current fields:

- `id`, because renderer links and maps depend on ids
- `title`, because cards and detail links need a label
- `summary`, because cards need a short public premise

Optional-looking current fields:

- `category`
- `genre`
- `image`
- `description`
- `examples`
- related ids
- `releaseStatus`, which belongs more naturally to scenarios than hooks

### Hook Generic Structure

Reusable structure:

- hook card
- title
- short public premise
- public description
- recommended level
- category
- tags
- related spot ids
- related NPC ids
- related term ids
- gallery/image reference
- public GM framing note
- display order
- empty state

Renderer / CSS responsibilities:

- card layout
- filter UI
- image fallback
- modal or no-modal behavior
- tag display
- related-link rendering
- empty-state rendering
- CSS classes, DOM ids, and JS hooks

### Hook World-Specific Content

Replace these per world:

- incident concepts
- NPC names
- place names
- organization names
- terms
- opening text
- category labels
- setting-specific genre labels
- spoiler material

Do not copy Velgard hook names, descriptions, examples, or image paths into a
new world unless they are intentionally re-authored for that world.

## Scenarios Template Structure

Scenarios are best treated as more concrete playable proposals or release
entries.

### Current Definition

Current Velgard scenario data exists in:

- `data/scenarios.json`

Current renderers:

- `assets/js/renderScenarios.js`
- `assets/js/renderScenarioDetail.js`

Current HTML shells:

- `scenarios.html`
- `scenario-detail.html`

Current cross-links:

- `renderSpotDetail.js` links `relatedScenarioIds` from spot details to
  `scenario-detail.html?id=...`
- gallery includes scenario images through `category: "scenarios"` and legacy
  `gallery-hook-*` style ids

### Scenario Field Policy

Minimum fields:

- `id` or `slug`
- `title`
- `summary`
- `visibility` or current `status`

Useful optional fields:

- `type`: `oneshot`, `campaign`, `chapter`, `seed`, or a world-specific value
- `category`
- `genre`
- `recommendedLevel`
- `playerCount`
- `estimatedTime`
- `tags`
- `image`
- `publicBody` or `description`
- `examples`
- `relatedHooks`
- `relatedSpots`
- `relatedCharacters`
- `relatedTerms`
- `relatedGalleryIds`
- `releaseStatus`
- `textUrl`
- `pdfUrl`
- `releaseDate`
- `version`
- `lastUpdated`
- `fileNote`
- `sortOrder`

Required-looking current fields:

- `id`
- `title`
- `summary`
- `status` if current `isVisible` remains unchanged

Optional-looking current fields:

- `category`
- `genre`
- `image`
- `description`
- `examples`
- related ids
- `releaseStatus`
- file-release fields

### Scenario Generic Structure

Reusable structure:

- scenario card
- title
- public overview
- recommended level
- estimated time
- recommended player count
- tags
- related hook ids
- related spot ids
- related NPC ids
- related term ids
- release or visibility state
- display order
- detail page
- public file-release links when explicitly published

Renderer / CSS responsibilities:

- scenario card layout
- detail hero layout
- release badge display
- filter/category UI
- related-link rendering
- image modal
- text/PDF link display
- broken-image fallback
- empty state
- CSS classes, DOM ids, and JS hooks

### Scenario World-Specific Content

Replace these per world:

- scenario names
- incidents
- NPC names
- place names
- organizations
- gimmicks
- category and genre wording
- images
- public file paths
- spoilers and GM-only information

## Public And GM-Secret Boundary

GitHub Pages data is public data.

If data is committed to this public site, it must be treated as visible even
when the current renderer does not display it.

Public data may contain:

- PL-facing `summary`
- public premise
- public introduction text
- public related NPC/spot/term links
- public release metadata
- public TXT/PDF paths
- intentionally public GM-facing framing notes

Public data should not contain:

- true GM secrets
- unrevealed culprit, trap, monster, or puzzle answers
- hidden campaign twists
- private GM planning notes
- private session notes
- member-only application or comment data
- raw user ids
- emails
- tokens
- JWT values
- Discord IDs or URLs
- Webhook URLs
- actual `management_key` values

Do not rely on "the renderer does not show this field" as a secrecy boundary.

If GM-only notes are genuinely secret, keep them out of public repo and GitHub
Pages. Store or share them through a separate private process with its own
approval gate.

## Pseudo Data Structures

These examples are placeholders only. They are not production values.

Hook shape:

```js
const hooks = [
  {
    id: "sample-hook",
    title: "Hook title",
    category: "optional category",
    recommendedLevel: "optional",
    tags: ["optional tag"],
    summary: "Short public premise for players.",
    body: ["Public description only."],
    relatedSpots: [],
    relatedCharacters: [],
    relatedTerms: [],
    visibility: "public"
  }
];
```

Scenario shape:

```js
const scenarios = [
  {
    id: "sample-scenario",
    title: "Scenario title",
    type: "oneshot",
    recommendedLevel: "optional",
    playerCount: "optional",
    estimatedTime: "optional",
    tags: ["optional tag"],
    summary: "Public overview for players.",
    publicBody: ["Public description only."],
    relatedHooks: [],
    relatedSpots: [],
    relatedCharacters: [],
    relatedTerms: [],
    visibility: "public"
  }
];
```

Rules for these structures:

- `id` / `slug` is an internal key, not visible copy.
- `status` or `visibility` values are local world-template display states, not
  DB enum values.
- `releaseStatus` is a scenario release display state, not a session operation
  state.
- CSS classes, DOM ids, and JS hook names do not belong in data.
- GM-secret information does not belong in public data.
- world-specific names and premise text must be replaced for each world.

## Empty And Incomplete States

Next-world behavior should be explicit for:

- zero hooks
- zero scenarios
- only draft/private records
- missing category
- missing tags
- missing recommended level
- missing player count or estimated time
- missing related NPCs, spots, terms, or hooks
- missing images
- missing release files

Recommended policy:

- show a simple "coming soon" or "no public entries yet" state for zero visible
  records
- hide filter UI when there are zero or one visible categories
- hide missing optional metadata rather than rendering "undefined"
- hide related-link sections when arrays are missing or empty
- hide release actions unless `textUrl` or `pdfUrl` is present and public
- show placeholder images or image-free cards according to the image asset
  guide
- keep unpublished or GM-secret content out of public data entirely

## Data Module / JSON Policy

Current scenarios and hooks are JSON-backed.

For a next world:

- JSON is acceptable for public scenario/hook lists.
- A data module may be useful for small isolated public blocks, but it is not
  required for this pass.
- Do not introduce JSON/fetch migration or renderer rewrites from this docs-only
  plan.
- Do not move live session operations into scenarios/hooks JSON.
- Do not store private GM notes in public JSON or public JS modules.

## Reusable Ops Core Boundary

Scenarios / hooks are world-template content.

They do not belong in reusable ops core.

Boundary rules:

- `session-post` and `session-detail` are reusable-ops-leaning surfaces.
- scenario/hook data may be referenced by session forms in a future gate, but
  it should not own session operation state.
- DB/RPC/RLS does not own public scenario/hook copy.
- Discord sync does not own public scenario/hook copy.
- auth and membership do not own public scenario/hook copy.
- public hooks/scenarios data must be treated as public information.
- session recruitment data and scenario ideas must remain separate.
- `status`, `visibility`, and `releaseStatus` must not be merged with DB enum
  contracts without a separate explicit gate.

## Introduction Checklist

Before introducing scenarios / hooks for a next world:

- only public-safe information is in public data
- no GM-secret information is committed to public data
- world-specific names, places, factions, and premise text are replaced
- ids or slugs are unique and stable
- ids do not leak private planning notes
- related spot, character, term, hook, and gallery ids exist or are omitted
- missing recommended level does not break cards
- missing player count or estimated time does not break cards
- missing category or tag does not break filters
- missing images follow the image asset guide
- zero visible records have a deliberate empty state
- `undefined`, `[object Object]`, empty cards, and broken links are absent
- public HTML, JS, JSON/data, and file URLs return HTTP 200 where applicable
- full visual review is recorded as `limited` if not completed
- auth, DB/RPC/RLS, Edge, Discord, session-post operation, and
  data-changing workflows are recorded as `not_tested` unless a separate gate
  covers them

## Rollback And Recovery

If scenario/hook introduction fails:

1. Revert the affected data changes.
2. Remove or restore related ids that point to missing records.
3. Revert renderer changes if a separate implementation gate changed them.
4. Revert file release links if TXT/PDF paths are wrong or not public-safe.
5. Update cache-bust when public stale assets may remain.
6. Re-run public checks for pages, JS, JSON/data, images, and release files.
7. Record the rollback reason in docs.
8. Do not use secret, DB, Discord, auth, or live session operations as a
   workaround.

## Next Candidate Options

Candidate A: page-by-page world-template adoption checklist.

- Convert top, world, characters, spots, scenarios/hooks, terms, regulation,
  gallery, campaigns, and tools readiness into one next-world launch checklist.

Candidate B: campaigns / episodes template structure.

- Document campaign and episode data ownership, scale, empty states, and ops
  boundaries.

Candidate C: OGP / favicon / hero image gate.

- Document site identity image rollout and public-sharing checks.

Candidate D: pre-auth / pre-DB / pre-Discord checklist.

- Define stop conditions before connecting operational surfaces.

Recommended next candidate:

- Candidate A: page-by-page world-template adoption checklist.

Reason:

- C1 through C5 now cover regulation, content structures, gallery/images, and
  scenarios/hooks.
- A consolidated checklist can turn the docs into a practical second-world
  launch sequence.
- It can remain docs-only and avoid implementation, renderer, CSS, auth, DB,
  and Discord risk.

## Phase 3-C6 Page Adoption Checklist Follow-Up

Phase 3-C6 completes the recommended page-by-page adoption checklist:

- `docs/world-template-page-adoption-checklist.md`

Scenarios/hooks impact:

- `scenarios.html`, `hooks.html`, and `scenario-detail.html` are classified as
  world-template pages
- `hooks.html` remains documented as a compatibility route until a future gate
  changes it
- scenario/hook data remains separate from live session-post and
  session-detail data
- public scenario/hook data must remain free of GM secrets before launch
- page-level checks now include detail id behavior, related links, release file
  links, missing images, and cache-bust chain review

Recommended next docs-only candidate after C6:

- campaigns / episodes template structure.

## Phase 3-C7 Campaigns / Episodes Structure Follow-Up

Phase 3-C7 completes that recommended campaigns / episodes structure plan:

- `docs/world-template-campaigns-episodes-structure-plan.md`

Scenarios/hooks impact:

- scenarios/hooks remain world-template adventure seeds and scenario proposals
- campaigns/episodes are documented as separate world-template story units,
  chapter structures, public recaps, and reading-order content
- neither area owns live session recruitment, applications, comments, Discord
  sync, DB/RPC/RLS, auth, membership, or session operation state
- related links between scenarios/hooks and campaigns/episodes are allowed in
  a future gate, but ownership remains separate
- public GitHub Pages data still must not contain real GM secrets, private
  notes, or live operation data

Recommended next docs-only candidate after C7:

- pre-auth / pre-DB / pre-Discord checklist.

## Limited And Not Tested

This plan is docs-only and does not add runtime QA.

Limited:

- current scenarios/hooks review was static
- zero-record rendering was inferred as a future requirement, not browser-tested
- public release file behavior was reviewed from existing code and policy docs,
  not exercised
- relation-id integrity was not exhaustively checked in this phase

Not tested:

- public next-world rendering
- desktop/mobile visual behavior
- scenario detail browser navigation
- TXT/PDF public download flows
- authenticated flows
- session-post and session-detail operations
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## No Dangerous Work

This plan did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, `management_key` display, raw id/email/token/JWT display, HTML
change, CSS change, JS change, JSON/data change, image change, renderer change,
scenario/hook text change, session-post change, or session-detail change.
