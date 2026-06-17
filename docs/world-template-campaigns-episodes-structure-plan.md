# World Campaigns Episodes Structure Plan

Date: 2026-06-17

Phase: 3-C7 campaigns / episodes template structure docs.

Baseline commit: `07e77ac Document world template page adoption`

This is a docs-only plan. It does not include implementation, HTML, CSS, JS,
JSON/data, sample data, campaign/episode text, image file, renderer,
session-post, session-detail, calendar, DB/RPC/RLS, Edge Function, Discord,
Supabase direct write, console logging, auth, membership, `updates.json`, or
secret changes.

## Purpose

Campaigns / episodes are world-site content for public story units:

- campaign introductions
- chapter structures
- public episode summaries
- public recap pages
- recommended reading order
- links to public NPCs, spots, terms, hooks, and scenarios

They are not live session operation data. They should not own recruitment,
attendance, comments, Discord sync, DB/RPC-backed state, membership state, or
auth behavior.

This plan documents a scale-variable template structure that can be reused by
a next world without copying Velgard story content or private operation notes.

## Current Velgard Inventory

Current pages:

- `campaigns.html`: campaign list page.
- `campaign-detail.html`: campaign detail and episode list page.
- `episode-detail.html`: single episode detail page.

Current renderers and routes:

- `assets/js/main.js` maps `campaigns` to `renderCampaigns`.
- `assets/js/main.js` maps `campaign-detail` to `renderCampaignDetail`.
- `assets/js/main.js` maps `episode-detail` to `renderEpisodeDetail`.
- `assets/js/main.js` marks `campaign-detail` and `episode-detail` as active
  under the `CAMPAIGN` navigation item.

Current data:

- `data/campaigns.json`: 1 campaign record.
- `data/episodes.json`: 3 episode records.
- `data/campaigns.json` status count: `preparing` 1.
- `data/episodes.json` status count: `preparing` 3.
- all current episodes belong to `campaignId: "velgard-open-campaign"`.

Current campaign fields:

- `id`
- `title`
- `subtitle`
- `catchcopy`
- `trailer`
- `introduction`
- `keyVisual`
- `thumbnail`
- `image`
- `status`
- `visibility`
- `relatedSpots`
- `relatedCharacters`
- `notes`

Current episode fields:

- `id`
- `campaignId`
- `episodeNumber`
- `episodeIndex`
- `title`
- `catchcopy`
- `summary`
- `image`
- `relatedSpots`
- `relatedCharacters`
- `status`
- `visibility`
- `notes`

Current renderer behavior:

- `renderCampaigns` loads `data/campaigns.json`.
- `renderCampaigns` includes `preparing` records through `isVisible(item, true)`.
- campaign list cards show image/placeholder, optional preparing badge, title,
  subtitle, catchcopy, trailer excerpt, and detail link.
- `renderCampaignDetail` loads campaigns, episodes, spots, and characters.
- campaign detail shows hero, trailer, introduction, sorted episode cards,
  related spot names, and related NPC names.
- episode sorting uses `episodeIndex`.
- related NPC labels are resolved only from visible official characters.
- `renderEpisodeDetail` loads campaigns, episodes, spots, and characters.
- episode detail can resolve the campaign from either `campaign` query or
  `episode` / `id` query.
- episode detail shows hero, public summary, related spots, related NPCs,
  previous/next episode links, and campaign-detail return link.
- if a campaign or episode is missing, the renderer shows a safe not-found
  notice.
- image paths currently fall back through `imageOrPlaceholder`.
- renderer output uses shared world-site structures such as `detail-hero`,
  `page-visual`, `hero-copy`, `section`, `grid`, `card`, `article-box`,
  `tag`, `status`, `lead`, `button`, and `actions`.

Current relationship to ops surfaces:

- campaign and episode renderers do not call Supabase, RPC, Discord, calendar,
  session-post, or session-detail modules.
- current cross-links are public related spot and character labels.
- live session history is not automatically reflected in campaign/episode
  pages.

## Role Separation

### World-Template Side

Campaigns / episodes may own:

- campaign introduction pages
- chapter lists
- public episode summaries
- public recap text
- recommended reading order
- campaign status labels used only for public display
- related public scenario ids
- related public hook ids
- related public character ids
- related public spot ids
- related public term ids
- world-facing "how to play this story" guidance

This data is authored for each world and replaced for each next world.

### Reusable Ops Core Side

Reusable ops core owns:

- actual session recruitment
- session dates and calendar display
- participant applications
- comments
- `session-post`
- `session-detail`
- Discord sync
- DB/RPC/RLS
- membership and auth
- live participation logs
- operation status and admin controls

Campaigns / episodes may link to a public scenario or a live session page in a
future gate, but the data ownership remains separate.

Do not make campaign/episode records the source of truth for live session
state. Do not make session records the source of truth for public campaign
recaps.

## Scale Policy

Campaigns / episodes should support these next-world states:

- zero campaigns or hidden campaign pages
- a single one-shot world that does not use campaign pages
- one short campaign with a few public episode summaries
- multiple short serial stories
- a long campaign with many chapters
- front/back parts or chapter groups
- planned, public, frozen, archived, or completed display states
- missing related scenarios, hooks, NPCs, spots, terms, tags, and images
- public-only records without private GM notes

Do not require a fixed number of campaigns or episodes.

Do not require a next world to launch campaigns / episodes at all. These pages
are optional world-template pages.

## Campaign Template Structure

Campaigns represent public story containers.

### Campaign Field Policy

Minimum fields:

- `id` or `slug`
- `title`
- `summary` or `catchcopy`
- `status` or `visibility`

Useful optional fields:

- `subtitle`
- `summary`
- `catchcopy`
- `trailer`
- `body`
- `introduction`
- `status`
- `visibility`
- `recommendedLevel`
- `tags`
- `keyVisual`
- `thumbnail`
- `image`
- `relatedEpisodes`
- `relatedScenarios`
- `relatedHooks`
- `relatedCharacters`
- `relatedSpots`
- `relatedTerms`
- `sortOrder`
- `notes` when the note is public-safe, or omitted entirely

Required-looking current fields:

- `id`, because detail links and episode ownership depend on it.
- `title`, because list/detail headings depend on it.
- `catchcopy` or equivalent short public summary, because cards and hero copy
  need a public description.

Optional-looking current fields:

- `subtitle`
- `trailer`
- `introduction`
- image fields
- related ids
- `notes`

### Campaign Generic Structure

Reusable structure:

- campaign card
- title
- subtitle
- short public summary
- campaign status display
- key visual or placeholder
- chapter / episode list
- related links
- tags
- display order
- empty state

Renderer / CSS responsibilities:

- card layout
- hero layout
- status badge layout
- image fallback
- episode-list rendering
- relation label rendering
- empty-state rendering
- CSS classes, DOM ids, and JS hooks

### Campaign World-Specific Content

Replace these per world:

- campaign names
- campaign subtitles
- incident names
- public trailer text
- public introduction text
- NPC names
- place names
- organization names
- unique story gimmicks
- public recap wording
- images and key visuals
- spoiler-sensitive descriptions

Do not copy current Velgard campaign copy, ids, related ids, or placeholder
notes into a next world as production defaults.

## Episode Template Structure

Episodes represent public story units inside a campaign or serial structure.

### Episode Field Policy

Minimum fields:

- `id` or `slug`
- `campaignId` when attached to a campaign
- `title`
- `summary`
- `status` or `visibility`
- `sortOrder`, `episodeIndex`, or `episodeNo` for ordering

Useful optional fields:

- `episodeNo`
- `episodeNumber`
- `chapterNo`
- `episodeIndex`
- `subtitle`
- `catchcopy`
- `publicBody`
- `summary`
- `status`
- `visibility`
- `recommendedLevel`
- `tags`
- `image`
- `relatedScenario`
- `relatedScenarios`
- `relatedHook`
- `relatedHooks`
- `relatedCharacters`
- `relatedSpots`
- `relatedTerms`
- `previous`
- `next`
- `releaseDate`
- `notes` when the note is public-safe, or omitted entirely

Required-looking current fields:

- `id`, because episode detail links depend on it.
- `campaignId`, because current detail and ordering are campaign-scoped.
- `title`, because cards and detail headings depend on it.
- `summary`, because detail pages render public recap paragraphs.
- `episodeIndex`, because current ordering uses it.

Optional-looking current fields:

- `episodeNumber`
- `catchcopy`
- `image`
- related ids
- `notes`

### Episode Generic Structure

Reusable structure:

- episode card
- chapter or episode number
- title
- public summary
- status display
- related links
- previous / next navigation
- tags
- display order
- empty state

Renderer / CSS responsibilities:

- detail hero layout
- card layout
- previous/next UI
- image fallback
- related-link rendering
- missing relation behavior
- empty-state rendering
- CSS classes, DOM ids, and JS hooks

### Episode World-Specific Content

Replace these per world:

- episode names
- chapter labels
- public summaries
- incident descriptions
- NPC names
- place names
- terms
- images
- public recap text
- spoiler-sensitive phrasing

## Public And GM-Secret Boundary

GitHub Pages data is public data.

Public campaign/episode data may contain:

- PL-facing campaign summary
- public campaign trailer
- public introduction text
- public episode recap
- public reading order
- public related character / spot / term / hook / scenario ids
- intentionally public status labels such as planned, public, frozen, archived,
  or completed

Public campaign/episode data must not contain:

- real GM-secret notes
- unrevealed truth
- enemy information that should stay hidden
- hidden rewards
- private session logs
- private operation notes
- future twists not intended for publication
- member-only application/comment data
- raw user ids
- emails
- tokens
- JWT values
- Discord IDs or URLs
- Webhook URLs
- actual `management_key` values

Do not rely on "the renderer does not show this field" as a secrecy boundary.

If GM information is genuinely secret, keep it out of the public repo and out
of GitHub Pages data.

## Boundary With Scenarios / Hooks / Session Operations

Scenarios / hooks and campaigns / episodes are both world-template content, but
they are different content shapes.

Recommended distinctions:

- scenarios / hooks: adventure seeds, playable proposals, public premises, or
  release entries
- campaigns / episodes: public story containers, chapter structure, recap
  pages, and reading order
- session-post / session-detail: live operation surfaces for recruitment,
  applications, comments, owners/admins, and Discord-adjacent workflows

Rules:

- do not auto-sync live session history into campaign episodes
- do not treat a campaign episode as a live session record
- do not treat a session-detail page as a campaign chapter source of truth
- related links may connect pages, but data ownership remains separate
- Discord sync and DB/RPC/RLS remain outside campaigns / episodes
- auth and membership remain outside campaigns / episodes

## Pseudo Data Structures

These examples are placeholders only. They are not production values.

Campaign shape:

```js
const campaigns = [
  {
    id: "sample-campaign",
    title: "Campaign title",
    subtitle: "Optional subtitle",
    status: "public",
    visibility: "public",
    tags: ["optional tag"],
    summary: "Public campaign overview.",
    body: ["Public explanation only."],
    relatedEpisodes: [],
    relatedScenarios: [],
    relatedHooks: [],
    relatedCharacters: [],
    relatedSpots: [],
    relatedTerms: [],
    sortOrder: 10
  }
];
```

Episode shape:

```js
const episodes = [
  {
    id: "sample-episode",
    campaignId: "sample-campaign",
    episodeNo: 1,
    title: "Episode title",
    status: "public",
    visibility: "public",
    summary: "Public episode overview.",
    publicBody: ["Public recap only."],
    relatedScenario: "sample-scenario",
    relatedHooks: [],
    relatedCharacters: [],
    relatedSpots: [],
    relatedTerms: [],
    previous: null,
    next: null,
    sortOrder: 10
  }
];
```

Rules for these structures:

- `id` / `slug` is an internal key, not visible copy.
- status values are local world-template display states, not ops-core DB enum
  values.
- `visibility` is a public-display concept, not auth logic.
- CSS classes, DOM ids, and JS hook names do not belong in data.
- GM-secret information does not belong in public data.
- world-specific names, summaries, and relation ids must be replaced for each
  world.

## Empty And Incomplete States

Next-world behavior should be explicit for:

- zero campaigns
- zero episodes
- a one-shot world that does not use campaign pages
- a campaign with no public episodes yet
- planned or frozen records
- missing related scenarios or hooks
- missing related characters, spots, or terms
- missing previous / next links
- missing tags
- missing images
- hidden or unpublished records

Recommended policy:

- hide campaign pages or show a quiet empty state when no public campaigns
  exist
- allow a one-shot world to skip campaigns / episodes entirely
- hide episode-list sections when no public episodes exist
- hide related-link sections when arrays are missing or empty
- hide previous / next buttons when no neighbor exists
- hide tag UI when tags are missing
- hide filters when there are zero or one effective groups
- show placeholders or image-free cards according to the image asset guide
- keep unpublished or GM-secret content out of public data entirely
- avoid visible `undefined`, `[object Object]`, empty cards, and empty related
  headings

## Data Module / JSON Policy

Current campaigns and episodes are JSON-backed.

For a next world:

- JSON is acceptable for public campaign/episode lists.
- data modules may be useful for small isolated public blocks, but are not
  required here.
- do not introduce JSON/fetch migration or renderer rewrites from this
  docs-only plan.
- do not move live session operations into campaigns / episodes JSON.
- do not store private GM notes in public JSON or public JS modules.

## Reusable Ops Core Boundary

Campaigns / episodes are world-template content.

They do not belong in reusable ops core.

Boundary rules:

- `session-post` and `session-detail` are reusable-ops-leaning surfaces.
- `calendar` is an operational schedule surface.
- campaigns / episodes may link to live session pages in a future gate, but
  do not own live operation state.
- DB/RPC/RLS does not own public campaign/episode copy.
- Discord sync does not own public campaign/episode copy.
- auth and membership do not own public campaign/episode copy.
- public campaigns / episodes data must be treated as public information.
- session operation information and story unit information must remain
  separate.
- campaign/episode `status` or `visibility` must not be merged with DB enum
  contracts without a separate explicit gate.

## Introduction Checklist

Before introducing campaigns / episodes for a next world:

- only public-safe information is in public data
- no GM-secret information is committed to public data
- world-specific campaign names, episode names, locations, factions, and recap
  text are replaced
- ids or slugs are unique and stable
- ids do not leak private planning notes
- campaign ids referenced by episodes exist
- related scenario, hook, spot, character, term, and gallery ids exist or are
  omitted
- missing status does not break cards
- missing previous / next does not break navigation
- missing images follow the image asset guide
- zero campaigns and zero episodes have deliberate behavior
- no `undefined`, `[object Object]`, empty cards, or broken links are visible
- public HTML, JS, JSON/data, and image URLs return HTTP 200 where applicable
- full visual review is recorded as `limited` if not completed
- auth, DB/RPC/RLS, Edge, Discord, session-post operation, session-detail
  operation, and data-changing workflows are recorded as `not_tested` unless a
  separate gate covers them

## Rollback And Recovery

If campaign/episode introduction fails:

1. Revert the affected campaign/episode data changes.
2. Remove or restore related ids that point to missing records.
3. Restore image paths or return to placeholders.
4. Revert renderer changes if a separate implementation gate changed them.
5. Update cache-bust when public stale assets may remain.
6. Re-run public checks for campaign pages, JS, JSON/data, images, and related
   links.
7. Record the rollback reason in docs.
8. Do not use secret, DB, Discord, auth, or live session operations as a
   workaround.

## Next Candidate Options

Candidate A: pre-auth / pre-DB / pre-Discord checklist.

- Define exact stop conditions before enabling reusable ops pages for a next
  world.

Candidate B: OGP / favicon / hero image rollout gate.

- Document public sharing image checks, cache-bust, ownership, and rollback
  for site identity assets.

Candidate C: tools / updates auxiliary page policy.

- Decide whether auxiliary pages stay world-template, reusable utility, or
  optional/disabled for a next world.

Candidate D: campaign/episode implementation hardening gate.

- Future implementation-only gate for empty states, optional filters, and
  relation-link tolerance, if a next world actually adopts these pages.

Recommended next candidate:

- Candidate A: pre-auth / pre-DB / pre-Discord checklist.

Reason:

- Phase 3-C1 through C7 now cover the main world-template content pages and
  optional story pages.
- The next major risk is enabling operational surfaces too early.
- A docs-only stop-condition checklist can keep calendar, session-post,
  session-detail, mypage, timeline, admin, DB/RPC/RLS, auth, and Discord gates
  separated from world-template content.

## Limited And Not Tested

This plan is docs-only and does not add runtime QA.

Limited:

- current campaign/episode review was static
- zero-record and missing-related rendering are documented as next-world
  requirements, not browser-tested here
- CSS behavior was treated as shared `assets/css/style.css`, not line-by-line
  audited
- relation-id integrity was not exhaustively checked in this phase
- public HTTP checks were not run in this phase

Not tested:

- public next-world rendering
- desktop/mobile visual behavior
- campaign detail browser navigation
- episode detail browser navigation
- authenticated flows
- session-post and session-detail operations
- calendar operations
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## No Dangerous Work

This plan did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, CSS class/DOM id/anchor change, `management_key` display, raw
id/email/token/JWT display, HTML change, CSS change, JS change, JSON/data
change, image change, renderer change, campaign/episode text change,
session-post change, session-detail change, or calendar change.
