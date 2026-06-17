# Regulation Data Module Midpoint Summary

Date: 2026-06-17

Phase: 3-B18 regulation data module midpoint summary and next-route decision.

Baseline commit: `258449b Check regulation original general skill bonus rollout`

This is a docs-only checkpoint. It does not include implementation, HTML, CSS,
JS, JSON/data, data-module, renderer, regulation copy, visual design, or
`updates.json` changes.

## Completed Data Modules

| Target | Data Module | Export | Source In `data/regulation.json` | Removed From JSON | Renderer Connection | Cache-Bust | Public Check Commit | Confirmed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `termExplanations` | `assets/js/world/regulation/termExplanationsData.js` | `termExplanations` | top-level `termExplanations` key | `termExplanations` key | imported in `renderRegulation.js` and attached to the loaded `regulation` object before `renderTermExplanations(regulation)` | `20260616-regulation-term-data-module` | `03c3229 Check regulation term data rollout` | 12 cards, original order, title/body stability, callout 1 item at card index 7 |
| `levelCaps` | `assets/js/world/regulation/levelCapsData.js` | `levelCaps` | top-level `levelCaps` key | `levelCaps` key | imported in `renderRegulation.js` and attached to the loaded `regulation` object before `renderLevelCaps(regulation)` | `20260617-regulation-level-caps-data-module` | `628a8c2 Check regulation level caps rollout` | 14 rows, `Lv2` through `Lv15`, 11 fields per row, 154 cell-equivalent values, `LEVEL_CAP_COLUMNS` and `renderTable()` unchanged |
| `rewardCalloutBlocks` | `assets/js/world/regulation/rewardCalloutBlocksData.js` | `rewardCalloutBlocks` | `sections[].id === "reward"`, block index 1, `type: "callout"` | one `超過報酬の例` callout block | imported in `renderRegulation.js`; `withRewardCalloutBlocks(sectionData)` filters stale JSON duplicates and inserts the module block at reward block index 1 | `20260617-regulation-reward-callout-data-module` | `da56e7c Check regulation reward callout rollout` | callout 1 item, 4 paragraphs, `.regulation-callout`, parent `#reward`, duplicate-display guard |
| `generalSkillNoteSubsections` | `assets/js/world/regulation/generalSkillNoteSubsectionsData.js` | `generalSkillNoteSubsections` | `sections[].id === "general-skills"`, block index 0, `type: "subsections"`, item index 7 | one `注釈2：『制限』について` subsection item | imported in `renderRegulation.js`; `withGeneralSkillNoteSubsections(sectionData)` filters stale JSON duplicates and inserts the module item at item index 7 | `20260617-regulation-general-skill-note-data-module` | `8b69a8c Check regulation general skill note rollout` | target 1 item, item index 7, 1 paragraph, `.regulation-subsection`, parent `#general-skills`, prior modules unchanged |
| `originalGeneralSkillBonusSubsections` | `assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js` | `originalGeneralSkillBonusSubsections` | `sections[].id === "original-general-skills"`, block index 2, `type: "subsections"`, item index 2 | one `オリジナル一般技能による「技能レベルボーナス」` subsection item | imported in `renderRegulation.js`; `withOriginalGeneralSkillBonusSubsections(sectionData)` filters stale JSON duplicates and inserts the module item at item index 2 | `20260617-regulation-original-general-skill-bonus-data-module` | `258449b Check regulation original general skill bonus rollout` | target 1 item, item index 2, 1 paragraph, `.regulation-subsection`, parent `#original-general-skills`, prior modules unchanged |

Common remaining QA classification for the five completed items:

- `limited`: full desktop/mobile visual review, scroll-through active TOC
  details, and full browser DOM inspection.
- `not_tested`: regulation-unrelated detail pages,
  auth/membership/mypage/session-post, DB/RPC/RLS, Edge Functions, Discord
  sync, and data-changing workflows.

## Data Module Method Evaluation

The five completed pilots support continuing to use static data modules for
small, isolated world-site data:

- No additional JSON/fetch lifecycle was introduced.
- GitHub Pages delivery is easy to inspect through normal static file checks.
- Cache-bust targets remained clear: `regulation.html`, `assets/js/main.js`,
  and the `REGULATION_DATA_PATH` query in `assets/js/renderRegulation.js`.
- Removing a JSON key, block, or item requires explicit cache-mixing checks.
- Stale JSON duplicate-display protection is necessary for nested block/item
  moves, and should stay target-scoped.
- Renderers were mostly preserved; `renderBlock()`, `renderDataSection()`, and
  `renderTable()` bodies remained unchanged.
- CSS classes, DOM ids, anchors, and active TOC behavior were preserved in the
  checked paths.
- The method now covers repeated cards, table rows, one section-level callout,
  and two nested subsection item shapes.
- Shared renderer behavior and table column definitions should remain separate
  gates.
- Low-risk candidates can use one combined task for behavior check,
  implementation, smoke/snapshot, public rollout, and docs, as long as the
  target is one clearly positioned item or block.

## Constraints To Keep

Keep these constraints for future regulation data work:

- Do not move whole sections in one step.
- Do not move multiple sections at the same time.
- Keep long rules, magic-angel rulings, and growth-rule clusters out of the
  current data-module path.
- Treat `renderBlock()`, `renderDataSection()`, and `renderTable()` changes as
  separate gates.
- Treat column-definition movement as a separate gate.
- Treat CSS class, DOM id, anchor, and active TOC changes as separate gates.
- Treat standalone JSON/fetch migration as a separate gate.
- Do not change `updates.json` without a separate release/content gate.
- Keep auth, DB/RPC/RLS, Discord, Edge Functions, and secrets out of this path.
- Keep reusable ops core separate from world-site template data modules.

## QA Status

Completed for the five pilots:

- data module import
- JSON parse
- count checks
- title / paragraph / cell checks
- old-HEAD exact-match checks
- public HTTP 200 checks
- public import/export checks
- public JSON ownership checks after removal
- public DOM one-item display checks for moved nested blocks/items
- duplicate-display checks for stale JSON cases

Limited:

- full desktop/mobile visual review
- scroll-through active TOC details
- full browser DOM inspection

Not tested:

- regulation-unrelated detail pages
- auth/membership/mypage/session-post
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## Next Route Options

Route A: continue a few more low-risk data-module moves.

- Candidate shape: one short note, callout, or subsection item at a time.
- Pros: keeps momentum and proves more one-off shapes.
- Cons: may add diminishing returns and more one-off composition helpers before
  the template story is documented.

Route B: create a phase-level regulation data-module summary.

- This B18 document now completes the first midpoint version of that route.
- A later summary can still revisit candidates after template docs are richer.

Route C: return to table-shaped data.

- Candidate shape: reward amount or honor/Sword Shard row data only.
- Constraint: do not move column definitions or `renderTable()`.
- Risk: the table values are currently tied to `levelCapsData.js`, so this
  needs a spec gate before implementation.

Route D: pause implementation and strengthen regulation template docs.

- Candidate work: write the template-facing ownership rules, module import
  pattern, cache-bust checklist, rollback checklist, and next-world adoption
  procedure for the already moved data.
- Pros: converts five pilots into reusable template guidance before the code
  accumulates more one-off cases.
- Cons: pauses further extraction briefly.

Recommended next route:

- Route D.

Reason:

- Five successful pilots are enough to establish the low-risk method.
- The next most useful step is making the result repeatable for future worlds
  before adding more module files or composition helpers.
- Route D also keeps heavier candidates out of scope until ownership,
  rollback, and schema boundaries are documented.

## No Dangerous Work

This checkpoint did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, or raw id/email/token/JWT display.
