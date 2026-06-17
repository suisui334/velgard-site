# World Content Structures Plan

Date: 2026-06-17

Phase: 3-C3 characters / spots / terms scalable template structure plan.

Baseline commit: `75558b0 Plan regulation sample data`

This is a docs-only plan. It does not include implementation, HTML, CSS, JS,
JSON/data, image, sample data, renderer, `updates.json`, SQL, DB/RPC/RLS, Edge
Function, Discord, Supabase direct write, console logging, auth, or secret
changes.

## Purpose

Characters, spots, and terms must work across very different next-world sizes.

The template should not require a fixed number of records. A next world may
launch with no public characters, only a small set of key locations, or a large
dictionary that grows as sessions progress.

The reusable target is:

- card/list/detail structure
- optional category and tag handling
- related-id patterns
- image and placeholder policy
- sort order
- empty states
- status / visibility concepts

The world-specific target is:

- names
- summaries
- body text
- categories
- tags
- images
- relation choices
- publication timing

## Shared Scale Policy

Use these rules for characters, spots, and terms:

- Do not set a required record count.
- Treat zero public records as a valid initial state.
- Keep fields optional unless the renderer truly needs them.
- Hide or simplify filters when there is only one visible category.
- Hide related-link blocks when relation arrays are missing or empty.
- Use a safe placeholder image or image-free card layout when images are
  missing.
- Keep sort behavior stable when `sortOrder` is missing.
- Keep unpublished/private/draft records out of public output unless a
  dedicated publication gate defines otherwise.
- Record partial checks as `limited` and unauthenticated/data-changing scopes as
  `not_tested`.

## Characters

### Scale Patterns

Characters should support:

- zero public records or a hidden page during early launch
- a small key-NPC list
- larger lists grouped by faction, region, chapter, status, or story arc
- image-present and image-missing records
- records without category, tags, region, or affiliation
- public NPCs only, with PC/member-related data kept out unless a separate gate
  approves it

### Field Policy

Minimum fields:

- `id` or `slug`
- `name`

Recommended minimum for a useful card:

- `id`
- `name`
- `summary`

Optional fields:

- `alias`
- `title`
- `race`
- `gender`
- `category`
- `tags`
- `region`
- `affiliation`
- `faction`
- `chapter`
- `role`
- `summary`
- `description`
- `image`
- `thumbnail`
- `relatedSpotIds`
- `relatedScenarioIds`
- `relatedTermIds`
- `sortOrder`
- `status`
- `visibility`
- `publish`

Visibility / publish flag:

- useful for staged publication
- should remain world-site content status, not auth logic
- do not store membership, role, raw user id, or private identity data here

### Empty State

When no characters are visible:

- show a quiet empty state or hide the section/page link during early launch
- do not show broken filters
- do not show an empty card grid
- do not imply data failed to load unless the fetch/import actually failed

When category/tag fields are missing:

- show all visible records
- hide category tabs if there is only one effective category
- hide tag chips when no tags exist

When images are missing:

- use image-free cards or a generic placeholder
- do not require stand-in portraits
- do not treat missing image as invalid data

When related links are missing:

- hide relation sections
- keep the character card/detail readable without relations

### Generic Structure Versus World Content

Generic structure:

- character card
- list/grid
- optional detail view
- category/filter controls
- tag chips
- image frame
- related links
- sort order
- empty state

World-specific content:

- NPC names
- aliases
- races
- factions
- regions
- roles
- descriptions
- portrait art
- relationship choices
- tags and categories

### Pseudo Structures

Minimal:

```js
{
  id: "PLACEHOLDER_CHARACTER_ID",
  name: "PLACEHOLDER_CHARACTER_NAME"
}
```

Standard:

```js
{
  id: "PLACEHOLDER_CHARACTER_ID",
  name: "PLACEHOLDER_CHARACTER_NAME",
  summary: "PLACEHOLDER_CHARACTER_SUMMARY",
  category: "PLACEHOLDER_CATEGORY",
  image: "PLACEHOLDER_IMAGE_PATH",
  status: "public"
}
```

Extended:

```js
{
  id: "PLACEHOLDER_CHARACTER_ID",
  slug: "PLACEHOLDER_CHARACTER_SLUG",
  name: "PLACEHOLDER_CHARACTER_NAME",
  alias: "PLACEHOLDER_ALIAS",
  race: "PLACEHOLDER_RACE",
  gender: "PLACEHOLDER_GENDER",
  region: "PLACEHOLDER_REGION",
  affiliation: "PLACEHOLDER_FACTION",
  chapter: "PLACEHOLDER_CHAPTER",
  role: "PLACEHOLDER_ROLE",
  tags: ["PLACEHOLDER_TAG"],
  summary: "PLACEHOLDER_CHARACTER_SUMMARY",
  description: "PLACEHOLDER_CHARACTER_BODY",
  image: "PLACEHOLDER_IMAGE_PATH",
  thumbnail: "PLACEHOLDER_THUMBNAIL_PATH",
  relatedSpotIds: ["PLACEHOLDER_SPOT_ID"],
  relatedScenarioIds: ["PLACEHOLDER_SCENARIO_ID"],
  relatedTermIds: ["PLACEHOLDER_TERM_ID"],
  sortOrder: 100,
  status: "public"
}
```

These examples are placeholders only. They are not production recommendations
or required field counts.

## Spots

### Scale Patterns

Spots should support:

- a small set of key bases or hub locations
- multiple locations grouped by region, nation, city, district, facility type,
  or exploration category
- exploration spots, facilities, countries, cities, districts, and landmarks
- image-present and image-missing records
- map-present and map-missing detail pages
- records without related hooks, NPCs, terms, or gallery links

### Field Policy

Minimum fields:

- `id` or `slug`
- `name`

Recommended minimum for a useful card:

- `id`
- `name`
- `summary`

Optional fields:

- `category`
- `tags`
- `area`
- `region`
- `type`
- `role`
- `summary`
- `description`
- `definition`
- `lead`
- `sections`
- `image`
- `thumbnail`
- `mapImage`
- `mapGalleryIds`
- `relatedGalleryIds`
- `relatedFacilityGalleryIds`
- `relatedCharacterIds`
- `relatedScenarioIds`
- `relatedTermIds`
- `hooks`
- `organizations`
- `notes`
- `sortOrder`
- `status`
- `visibility`
- `publish`

Visibility / publish flag:

- useful when a location is secret or story-locked
- should remain public content status, not role-based access control
- do not use it to store DB/RPC/auth permission rules

### Empty State

When no spots are visible:

- show a quiet empty state or hide the page link until location data is ready
- do not show empty filter controls
- do not render broken map or image placeholders as if they were content

When there is only one category:

- hide or simplify category tabs
- keep the list usable without forcing a filter UI

When images or maps are missing:

- use image-free cards or a neutral placeholder
- hide map sections when no map data exists
- keep detail text readable without media

When related links are missing:

- hide related NPC/scenario/term/gallery sections
- do not display empty headings

### Generic Structure Versus World Content

Generic structure:

- spot card
- list/grid
- optional detail page
- category/filter controls
- image frame
- map/media area
- related links
- sort order
- empty state

World-specific content:

- place names
- country/city/district names
- organization names
- location descriptions
- maps
- image assets
- local category names
- related NPC/scenario/term choices

### Pseudo Structures

Minimal:

```js
{
  id: "PLACEHOLDER_SPOT_ID",
  name: "PLACEHOLDER_SPOT_NAME"
}
```

Standard:

```js
{
  id: "PLACEHOLDER_SPOT_ID",
  name: "PLACEHOLDER_SPOT_NAME",
  category: "PLACEHOLDER_CATEGORY",
  summary: "PLACEHOLDER_SPOT_SUMMARY",
  image: "PLACEHOLDER_IMAGE_PATH",
  status: "public"
}
```

Extended:

```js
{
  id: "PLACEHOLDER_SPOT_ID",
  slug: "PLACEHOLDER_SPOT_SLUG",
  name: "PLACEHOLDER_SPOT_NAME",
  category: "PLACEHOLDER_CATEGORY",
  area: "PLACEHOLDER_AREA",
  region: "PLACEHOLDER_REGION",
  type: "PLACEHOLDER_TYPE",
  role: "PLACEHOLDER_ROLE",
  tags: ["PLACEHOLDER_TAG"],
  summary: "PLACEHOLDER_SPOT_SUMMARY",
  description: "PLACEHOLDER_SPOT_DESCRIPTION",
  image: "PLACEHOLDER_IMAGE_PATH",
  thumbnail: "PLACEHOLDER_THUMBNAIL_PATH",
  mapGalleryIds: ["PLACEHOLDER_MAP_GALLERY_ID"],
  relatedGalleryIds: ["PLACEHOLDER_GALLERY_ID"],
  relatedCharacterIds: ["PLACEHOLDER_CHARACTER_ID"],
  relatedScenarioIds: ["PLACEHOLDER_SCENARIO_ID"],
  relatedTermIds: ["PLACEHOLDER_TERM_ID"],
  notes: ["PLACEHOLDER_NOTE"],
  sortOrder: 100,
  status: "public"
}
```

Detail-oriented extension:

```js
{
  id: "PLACEHOLDER_SPOT_ID",
  definition: "PLACEHOLDER_SHORT_DEFINITION",
  lead: "PLACEHOLDER_DETAIL_LEAD",
  sections: [
    {
      title: "PLACEHOLDER_SECTION_TITLE",
      body: ["PLACEHOLDER_PARAGRAPH"]
    }
  ]
}
```

These examples are placeholders only. They do not require a next world to have
maps, images, or relations at launch.

## Terms

### Scale Patterns

Terms should support:

- a small list of important words
- category-based dictionary growth
- session-by-session additions
- records without reading, alias, related terms, related spots, or related
  characters
- public-only records, with secret/story-locked terms handled by publication
  status rather than auth logic

### Field Policy

Minimum fields:

- `id` or `slug`
- `term`

Recommended minimum for a useful card:

- `id`
- `term`
- `summary`

Optional fields:

- `reading`
- `aliases`
- `category`
- `tags`
- `summary`
- `description`
- `body`
- `relatedTermIds`
- `relatedSpotIds`
- `relatedCharacterIds`
- `relatedScenarioIds`
- `firstSeen`
- `source`
- `sortOrder`
- `status`
- `visibility`
- `publish`

Visibility / publish flag:

- useful for terms that should appear after story progress
- should not become an auth/role system
- do not store private player/member data here

### Empty State

When no terms are visible:

- show a quiet empty state or hide dictionary navigation until ready
- do not show an empty search result as an error

When category fields are missing:

- show all visible terms
- hide category filters if there is only one effective category

When reading or aliases are missing:

- show only the term and summary
- do not render empty reading/alias labels

When related terms or related pages are missing:

- hide relation sections
- keep the dictionary entry readable on its own

### Generic Structure Versus World Content

Generic structure:

- dictionary entry
- list/search
- category filter
- tag chips
- anchor per term
- related links
- sort order
- empty state

World-specific content:

- terms
- readings
- aliases
- definitions
- lore text
- category names
- tags
- related-character/spot/scenario choices

### Pseudo Structures

Minimal:

```js
{
  id: "PLACEHOLDER_TERM_ID",
  term: "PLACEHOLDER_TERM"
}
```

Standard:

```js
{
  id: "PLACEHOLDER_TERM_ID",
  term: "PLACEHOLDER_TERM",
  category: "PLACEHOLDER_CATEGORY",
  summary: "PLACEHOLDER_TERM_SUMMARY",
  status: "public"
}
```

Extended:

```js
{
  id: "PLACEHOLDER_TERM_ID",
  slug: "PLACEHOLDER_TERM_SLUG",
  term: "PLACEHOLDER_TERM",
  reading: "PLACEHOLDER_READING",
  aliases: ["PLACEHOLDER_ALIAS"],
  category: "PLACEHOLDER_CATEGORY",
  tags: ["PLACEHOLDER_TAG"],
  summary: "PLACEHOLDER_TERM_SUMMARY",
  description: "PLACEHOLDER_TERM_BODY",
  relatedTermIds: ["PLACEHOLDER_RELATED_TERM_ID"],
  relatedSpotIds: ["PLACEHOLDER_SPOT_ID"],
  relatedCharacterIds: ["PLACEHOLDER_CHARACTER_ID"],
  relatedScenarioIds: ["PLACEHOLDER_SCENARIO_ID"],
  firstSeen: "PLACEHOLDER_SESSION_OR_CHAPTER",
  source: "PLACEHOLDER_SOURCE",
  sortOrder: 100,
  status: "public"
}
```

These examples are placeholders only. They do not require categories, readings,
aliases, or related links at launch.

## Shared Empty-State Rules

Use the same empty-state philosophy across all three areas:

- zero visible records is a valid state
- missing optional fields should hide optional UI, not produce empty labels
- one category should not require visible filter controls
- no tags should mean no tag UI
- no related records should mean no related section
- missing images should not block publication
- unpublished records should not appear in public lists
- empty-state copy should be world-neutral and should not expose internal
  publication plans

Avoid:

- `undefined`
- `[object Object]`
- empty cards
- empty related headings
- broken image icons
- filters that lead to no records unless the user explicitly selected a filter
- auth/role language in world content empty states

## Data Ownership Boundary

Characters, spots, and terms are world-template data.

They do not belong in reusable ops core.

Allowed connections:

- calendar or session-detail may link to a spot, term, or character
- session-post may eventually reference scenarios, spots, terms, or NPCs
- mypage may link to public guidance pages

Ownership remains:

- character data: world-template side
- spot data: world-template side
- term data: world-template side
- ops UI behavior: reusable ops side
- auth, DB/RPC/RLS, Discord sync: separate gates

Do not store these in characters/spots/terms:

- auth state
- membership state
- Discord IDs or URLs
- DB table/column/RPC contracts
- raw user ids
- emails
- tokens
- JWT values
- actual `management_key` values

## Implementation Boundary

This plan does not approve implementation.

Future implementation gates should separately review:

- renderer tolerance for missing optional fields
- filter visibility when category/tag counts are low
- placeholder image behavior
- detail-page behavior when related data is absent
- public HTTP 200 checks for data and pages
- visual behavior on desktop and mobile
- `updates.json` policy

Do not change CSS, renderer code, data files, images, auth, DB, Discord, or
cache-bust chains from this docs-only plan.

## Next Candidate Options

Candidate A: gallery / image asset boundary guide.

- Clarify reusable gallery behavior versus world-specific images, categories,
  captions, key visuals, OGP assets, and placeholder policy.

Candidate B: page-by-page world-template adoption checklist.

- Turn top/world/characters/spots/scenarios/terms/regulation/gallery readiness
  into a checklist.

Candidate C: scenarios/hooks template structure.

- Decide whether next worlds should use `scenarios`, `hooks`, or both, and
  document fields and compatibility policy.

Candidate D: pre-auth / pre-DB / pre-Discord checklist.

- Define stop conditions before connecting live ops surfaces.

Recommended next candidate:

- Candidate A: gallery / image asset boundary guide.

Reason:

- characters and spots both depend on image and gallery boundaries.
- gallery assets are highly world-specific and easy to over-copy from Velgard.
- the guide can remain docs-only and avoid renderer, CSS, auth, DB, and Discord
  changes.

## Phase 3-C4 Gallery / Image Asset Boundary Follow-Up

Phase 3-C4 completes the recommended gallery / image asset boundary guide:

- `docs/world-template-gallery-image-assets-guide.md`

Content-structure impact:

- separates reusable gallery/card/modal/fallback behavior from world-specific
  images, categories, captions, credits, OGP assets, favicon assets, logos,
  maps, key visuals, and placeholders
- records image-bearing data fields such as `image`, `thumbnail`, `alt`,
  `caption`, `credit`, `category`, `tags`, and relation ids as world-template
  data concerns
- keeps CSS classes, DOM ids, modal behavior, image ratios, broken-image
  fallback, and renderer behavior outside data ownership
- confirms characters and spots must remain valid with missing images or
  image-free cards
- keeps gallery and image assets outside reusable ops core, auth, DB/RPC/RLS,
  Edge Functions, Discord sync, and `updates.json`

Recommended next docs-only candidate after C4:

- scenarios / hooks template structure.

## Limited And Not Tested

This plan is docs-only and does not add runtime QA.

Limited:

- actual visual behavior for zero/small/large datasets
- image-missing card layout
- filter UI behavior with one category
- related-link behavior with empty arrays

Not tested:

- public next-world rendering
- renderer tolerance for every missing optional field
- search/filter behavior with future data
- authenticated flows
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## No Dangerous Work

This plan did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, or raw id/email/token/JWT display.
