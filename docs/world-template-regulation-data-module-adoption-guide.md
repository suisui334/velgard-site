# Regulation Data Module Adoption Guide

Date: 2026-06-17

Phase: 3-B19 regulation data module adoption, ownership, rollback, and
checklist guide.

Baseline commit: `00c3804 Summarize regulation data module midpoint`

This is a docs-only guide. It does not include implementation, HTML, CSS, JS,
JSON/data, data-module, renderer, regulation copy, visual design, or
`updates.json` changes.

## Purpose

This guide converts the first five regulation data-module pilots into a
repeatable next-world adoption procedure.

Completed pilot modules:

- `termExplanations`
- `levelCaps`
- `rewardCalloutBlocks`
- `generalSkillNoteSubsections`
- `originalGeneralSkillBonusSubsections`

The pattern is approved only for small, isolated world-site template data.
Whole-section migration, standalone JSON/fetch loading, renderer rewrites,
table-column movement, CSS/DOM/anchor changes, and reusable ops core changes
remain separate gates.

## Adoption Procedure

Use this order when applying the same method to another regulation target.

1. Candidate selection

   Pick one target only. Prefer a short card, note, callout, one subsection
   item, or table row array whose current position and renderer path are clear.
   Reject the target if it requires moving a whole section, multiple sections,
   shared renderer behavior, CSS classes, DOM ids, anchors, active TOC logic, or
   standalone JSON/fetch loading.

2. Current behavior check

   Record the current source path, source key/block/item location, title,
   fields, body shape, count, order, renderer function, CSS classes, section id,
   anchor, sibling data, and old-HEAD comparison method before editing code.
   If the position is ambiguous, stop with docs-only.

3. Data module creation

   Create one focused module under `assets/js/world/regulation/`. Export the
   moved data by a name that matches the target. Do not add normalization,
   transformation, parsing, or helper functions unless a separate gate approves
   them.

4. Remove only the source target from `data/regulation.json`

   Remove the exact key, block, or item that moved. Keep the parent section and
   all sibling keys/items/blocks in place. Confirm that JSON parsing still
   passes.

5. Import connection in `renderRegulation.js`

   Import the module synchronously and compose the moved data back into the
   existing rendering path. Keep the existing renderer branch responsible for
   the DOM. Do not rewrite `renderBlock()`, `renderDataSection()`, or
   `renderTable()` as part of a data move.

6. Stale JSON duplicate-display guard

   If the target is nested under a section block or subsection item, consider a
   narrow duplicate guard for stale JSON. Scope the guard to the exact section,
   block position, title, and/or target field so it cannot remove unrelated
   content.

7. Cache-bust update

   Update only the affected public chain. The usual targets are
   `regulation.html`, `assets/js/main.js`, and the regulation JSON query inside
   `assets/js/renderRegulation.js`. Use a target-specific cache key. Do not
   update `updates.json` unless a separate content-release gate requires it.

8. Smoke and snapshot checks

   Run syntax, JSON parse, module import, target count, title/body/row/cell
   equality, old-HEAD exact-match, sibling retention, composition order, and
   no-renderer-rewrite checks.

9. GitHub Pages public rollout check

   After commit and push, verify public `regulation.html`, `main.js`,
   `renderRegulation.js`, the new data module, and `data/regulation.json`.
   Confirm the target appears exactly once in the public DOM and that existing
   moved modules still render.

10. Docs record

    Record the source split, module/export name, import connection, removed
    JSON target, maintained output, smoke/snapshot results, public rollout
    results, limited/not-tested QA, ownership boundaries, and rollback path.

11. Rollback

    If public delivery or DOM output regresses, remove the module import,
    restore the target key/block/item in `data/regulation.json`, remove the
    composition helper or insertion code, update the cache-bust chain, record
    the reason in docs, and repeat public checks. Do not use DB, RPC, Edge,
    Discord, or other dangerous operations for rollback.

## Suitable Targets

These are good candidates for the current data-module method:

- short cards
- short notes or callouts
- one subsection item
- one section block when its insertion point is exact
- table row data only
- data that already has a simple array/object shape
- data rendered by an existing renderer branch without changes
- data whose old-HEAD output can be compared exactly
- data whose display order can be restored by one clear insertion point

The best next-world candidates are small enough that one implementation gate
can include behavior check, data move, smoke/snapshot, public rollout, and docs.

## Targets To Avoid For Now

Avoid these until separate schema or renderer gates exist:

- whole sections
- multiple sections in one gate
- long house rules
- magic-angel style special rulings
- full growth-rule clusters
- complex fumble or lower-bound growth text
- table column definitions
- `renderTable()`
- `renderBlock()`
- `renderDataSection()`
- CSS class names
- DOM ids
- anchors
- active TOC behavior
- standalone JSON/fetch loading

If the target naturally pulls any of these into scope, stop with docs-only and
record the blocker.

## Ownership Boundaries

Regulation data modules belong to the world-site template side.

They do not belong to reusable ops core.

Keep these areas separate from regulation data-module work:

- auth and membership
- `mypage`
- `session-post`
- `session-detail`
- Discord sync
- DB / RPC / RLS
- Edge Functions
- calendar-side level-cap date ranges

The regulation `levelCaps` module and calendar-side `levelCaps` data are not
integrated at this stage. They solve different display problems and must remain
separate until a dedicated cross-page schema gate exists.

This work is a world-template data separation, not an ops platform change.
`updates.json` must stay untouched unless a separate release/content gate
explicitly asks for it.

## File Naming And Placement

Existing module examples:

- `assets/js/world/regulation/termExplanationsData.js`
- `assets/js/world/regulation/levelCapsData.js`
- `assets/js/world/regulation/rewardCalloutBlocksData.js`
- `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`
- `assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js`

Naming policy:

- Use a file name that identifies the target data.
- Match the export name to the target name.
- Keep modules as synchronous ES module imports.
- Keep one file to one target or a very closely related target group.
- Do not add conversion helpers, runtime normalization, or parsing logic.
- Treat standalone JSON/fetch loading as a separate gate.
- If ownership is unclear, split the target smaller or stop.

## Stale JSON And Cache-Mixing Risks

Removing a key, block, or item from `data/regulation.json` creates two main
public delivery risks.

Disappearance risk:

- new `data/regulation.json` plus old `renderRegulation.js`
- old `regulation.html` or old `main.js` cache key plus mismatched renderer
- new `renderRegulation.js` plus missing data module path

Duplicate-display risk:

- old `data/regulation.json` still contains the moved nested block/item
- new `renderRegulation.js` inserts the same module data again

Mitigation:

- update the cache-bust chain every time
- verify public HTML, main module, renderer module, data module, and
  `data/regulation.json` as one chain
- add target-scoped duplicate guards for nested block/item moves
- do not make duplicate guards broad enough to remove sibling content
- record propagation issues as rollout status, not as a pass

## Smoke And Snapshot Checklist

Use this checklist before commit or before public rollout, depending on the
gate structure.

- `node --check` for touched JS
- `data/regulation.json` parse
- data module import smoke
- target count
- target title match
- paragraphs/items/rows/cells match old HEAD
- moved object or array exactly matches old HEAD where practical
- current JSON no longer contains the moved target
- parent section remains
- sibling items/blocks remain
- composed render data preserves the old display order
- renderer body rewrites are absent
- CSS classes are unchanged
- DOM ids are unchanged
- anchors are unchanged
- active TOC logic is unchanged
- existing moved modules still render:
  `termExplanations`, `levelCaps`, `rewardCalloutBlocks`,
  `generalSkillNoteSubsections`, and
  `originalGeneralSkillBonusSubsections`
- no `undefined`, `[object Object]`, empty card, empty row, or empty subsection
  appears in checked output

## Public Rollout Checklist

Use this checklist after GitHub Pages propagation.

- public `regulation.html`: HTTP 200
- public `regulation.html` references the expected cache-bust
- public `assets/js/main.js`: HTTP 200
- public `assets/js/renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports the new data module
- public data module: HTTP 200
- public data module exports the expected name
- public `data/regulation.json`: HTTP 200
- public `data/regulation.json` parse OK
- public JSON no longer contains the moved target
- parent section remains in public JSON
- public DOM shows the moved target exactly once
- moved target is not duplicated
- moved target is not missing
- existing moved modules still render:
  - term explanations: 12 cards
  - level caps: 14 rows
  - reward callout: 1 item
  - general-skill note item: 1 item
  - original-general-skill bonus item: 1 item
- no broken import, checked 404, module-load failure, or regulation-data fetch
  failure is observed
- full desktop/mobile visual review may be recorded as `limited` when only
  static delivery and DOM checks are performed
- regulation-unrelated pages, auth flows, DB/RPC/RLS, Edge Functions, Discord
  sync, and data-changing workflows may remain `not_tested` unless a separate
  gate explicitly covers them

## Rollback Checklist

If a moved target disappears, duplicates, or produces output drift:

1. Remove the target data-module import from `renderRegulation.js`.
2. Restore the target key/block/item in `data/regulation.json`.
3. Remove the target-specific composition or insertion helper.
4. Update the cache-bust chain so public delivery cannot remain mixed.
5. Re-run local smoke/snapshot checks.
6. Push the rollback commit.
7. Re-run public rollout checks.
8. Record the rollback reason and observed public status in docs.

Rollback must stay within static files and docs. Do not use SQL, DB/RPC/RLS,
Edge Functions, Discord operations, secret changes, direct Supabase writes,
auth/permission changes, or raw identifier/token exposure as part of this path.

## Next Route Options

Route A: continue low-risk data-module moves.

- Move one short note, callout, or subsection item at a time.
- Keep behavior check, implementation, public rollout, and docs in one task.
- Create another summary after 3 to 5 additional moves.
- This is useful when a concrete next target is already clear.

Route B: return to table-shaped data.

- Candidate targets: reward amount table or honor/Sword Shard table.
- Move row data only.
- Keep column definitions and `renderTable()` unchanged.
- Open a spec gate first if the values are still tied to existing
  `levelCaps` rows.

Route C: strengthen world-template docs.

- Create next-world setup guidance.
- Document the regulation template structure.
- Record initial data/module setup steps.
- Prepare a sample composition plan without changing production data.

Route D: strengthen QA.

- Add desktop/mobile visual review.
- Add active TOC scroll-through checks.
- Add broader non-regulation side-effect checks.
- Keep auth, DB, Discord, and data-changing workflows behind separate gates.

Recommended next route:

- Route C.

Reason:

- Phase 3-B19 now provides the module-level adoption guide requested by Route
  D.
- The next useful step is broader next-world template documentation: initial
  structure, sample composition, and setup order.
- More extraction can wait until the template handoff path is understandable
  for a second world.
- QA strengthening remains valuable, but it should follow from a clear
  template checklist rather than replace it.

## Phase 3-C1 Next World Adoption Follow-Up

Phase 3-C1 creates the broader next-world adoption guide:

- `docs/world-template-next-world-adoption-guide.md`

Relationship to this regulation guide:

- this document remains the detailed procedure for regulation data-module
  moves
- the Phase 3-C1 guide decides when a next world should use the regulation
  template at all, what content must be replaced, and which ops-core surfaces
  remain separate
- the next-world guide keeps the first regulation adoption pass conservative:
  no broad HTML/CSS/renderer rewrite, no standalone JSON/fetch migration, and
  no active TOC / anchor / CSS class changes
- the next-world guide recommends a future docs-only regulation sample data
  composition before more extraction work

## Limited And Not Tested

This docs-only guide does not add new runtime QA.

Existing classification remains:

- `limited`: full desktop/mobile visual review, scroll-through active TOC
  details, and full browser DOM inspection.
- `not_tested`: regulation-unrelated detail pages,
  auth/membership/mypage/session-post, DB/RPC/RLS, Edge Functions, Discord
  sync, and data-changing workflows.

## No Dangerous Work

This guide did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, or raw id/email/token/JWT display.
