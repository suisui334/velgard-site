# World Template Regulation Level Caps Spec

Phase 3-B8 freezes the current `levelCaps` behavior before a future data-module
implementation gate.

This is a docs-only gate. It does not change implementation, HTML, CSS,
JavaScript, JSON/data, data modules, renderers, regulation copy, `updates.json`,
or reusable ops core behavior.

Baseline:

- `878950c Summarize regulation data pilot`

## Current Data Contract

Current definition:

- file: `data/regulation.json`
- top-level key: `levelCaps`
- data type: array of row objects
- current row count: 14
- display order: array order
- current level order:
  - `Lv2`
  - `Lv3`
  - `Lv4`
  - `Lv5`
  - `Lv6`
  - `Lv7`
  - `Lv8`
  - `Lv9`
  - `Lv10`
  - `Lv11`
  - `Lv12`
  - `Lv13`
  - `Lv14`
  - `Lv15`

Current row fields:

| Field | Current role | Current value shape |
| --- | --- | --- |
| `levelCap` | level-cap label | string labels such as `Lv2` through `Lv15` |
| `fixedExperience` | fixed experience total/change | string, either `初期作成` or plus/total point notation |
| `minGrowth` | lower-bound growth count | string, either `初期作成` or count notation |
| `minReward` | lower-bound reward total | string, either `初期作成` or `G` amount |
| `minHonor` | lower-bound honor total | string, either `初期作成` or point notation |
| `maxGrowth` | upper growth count | string count notation |
| `maxReward` | upper reward total | string `G` amount |
| `growthPerSession` | growth count per session | string count notation |
| `rankLimit` | adventurer-rank limit | string rank label |
| `rewardAmount` | reward amount guide | string `G` amount with parenthesized value |
| `swordShardGuide` | Sword Shard guide | string count with parenthesized honor-point guide |

Required-looking fields:

- All 14 current rows contain all 11 fields.
- All current field values are non-empty strings.
- Future data-module implementation should preserve the same complete row
  shape for the first move.

Optional-looking fields:

- None in the current production data.
- There is no current `notes`, `description`, `startDate`, or `endDate` field
  on `data/regulation.json` `levelCaps` rows.

Date handling:

- Regulation `levelCaps` rows do not carry start or end dates.
- Calendar-side level-cap date ranges live separately in
  `data/calendarConfig.json`.
- The next regulation data-module pilot must not merge, normalize, or otherwise
  couple these two `levelCaps` concepts.

Content ownership:

- The exact values are Velgard-specific.
- The repeated row/table shape is reusable for future world sites.
- Future worlds may need different columns, so the first implementation should
  treat only the current row data as the pilot target.

## `LEVEL_CAP_COLUMNS`

Current definition:

- file: `assets/js/renderRegulation.js`
- constant: `LEVEL_CAP_COLUMNS`
- current column count: 11

Current column order:

| Column | Header label | Row field |
| --- | --- | --- |
| 1 | `レベルキャップ` | `levelCap` |
| 2 | `固定経験点` | `fixedExperience` |
| 3 | `下限成長` | `minGrowth` |
| 4 | `下限報酬` | `minReward` |
| 5 | `下限名誉点` | `minHonor` |
| 6 | `上限成長` | `maxGrowth` |
| 7 | `上限報酬` | `maxReward` |
| 8 | `成長回数` | `growthPerSession` |
| 9 | `冒険者ランク上限` | `rankLimit` |
| 10 | `報酬金額` | `rewardAmount` |
| 11 | `剣の欠片目安` | `swordShardGuide` |

Current relationship:

- Each column maps directly to one current `levelCaps` row field.
- Header labels are renderer-owned.
- Row values are data-owned.

Future extraction boundary:

- Do not move `LEVEL_CAP_COLUMNS` in the first `levelCaps` data-module gate.
- Column extraction should wait for a separate renderer-constant audit.
- Do not split `rewardAmount`, `minHonor`, or `swordShardGuide` into standalone
  table schemas during the first `levelCaps` move.

## `renderTable()` Behavior

Current definition:

- file: `assets/js/renderRegulation.js`
- function: `renderTable(rows, columns, className = "regulation-table")`

Arguments:

- `rows`: array of row objects
- `columns`: array entries shaped as `[fieldKey, label]`
- `className`: optional table class string; defaults to `regulation-table`

Level-cap call path:

1. `renderRegulation(root)` loads `data/regulation.json`.
2. `renderRegulation(root)` appends `renderLevelCaps(regulation)` before
   `renderTermExplanations(regulation)`.
3. `renderLevelCaps(regulation)` creates the `level-caps` section.
4. `renderLevelCaps(regulation)` reads
   `Array.isArray(regulation.levelCaps) ? regulation.levelCaps : []`.
5. `renderLevelCaps(regulation)` calls
   `renderTable(rows, LEVEL_CAP_COLUMNS)`.

Generated DOM for level caps:

- `section.section.regulation-section#level-caps`
- `article.article-box`
- `h2` with the current section title
- `div.regulation-table-wrap`
- `table.regulation-table`
- `thead > tr > th`
- `tbody > tr > td`

Current CSS classes involved:

- `.regulation-section`
- `.article-box`
- `.regulation-table-wrap`
- `.regulation-table`

Current DOM id and anchor contract:

- section id: `level-caps`
- TOC link target: `#level-caps`
- TOC label source: `TOC_ITEMS` in `assets/js/renderRegulation.js`
- active TOC observer target: `.regulation-section[id]`

Empty or missing data behavior:

- If `regulation.levelCaps` is not an array, `renderLevelCaps(regulation)` passes
  an empty array to `renderTable()`.
- With an empty array, the section and table headers still render, with an
  empty `tbody`.
- If a row is missing a field or a field is empty, `renderTable()` renders an
  empty cell because it checks values through `isPresent()`.
- Current production data has no missing or empty `levelCaps` fields.

Shared renderer use:

- `renderTable()` is also used by the schedule table.
- `renderTable()` is also used for block tables inside `data/regulation.json`
  `sections`.
- Reward amount, honor, and Sword Shard guides are currently cells in the
  level-cap table, not separate renderer paths.
- A future `levelCaps` row-data move must not change schedule tables or any
  other regulation block tables.

Event and ops distance:

- `renderLevelCaps()` and `renderTable()` attach no event handlers.
- The level-cap table does not read auth state.
- The level-cap table does not call RPC, DB, Supabase writes, Edge Functions,
  or Discord sync.

## Comparison Checklist For A Future Move

Future `levelCaps` data-module implementation should compare:

- row count remains 14
- row order remains `Lv2` through `Lv15`
- row field set remains the same 11 keys
- all cell text remains unchanged
- column count remains 11
- column header labels remain unchanged
- section order remains before `term-explanations`
- section id remains `level-caps`
- TOC anchor remains `#level-caps`
- `.regulation-table-wrap` and `.regulation-table` remain unchanged
- active TOC behavior has no obvious regression
- schedule and other regulation block tables have no obvious regression
- no `undefined`, `[object Object]`, empty header, or unexpected empty row/cell
  appears
- desktop and mobile table behavior has no meaningful display regression

## Recommended Future Implementation

Recommended scope:

- Move only the `levelCaps` row array to a world-site data module.

Expected module:

- `assets/js/world/regulation/levelCapsData.js`

Expected export:

- `levelCaps`

Expected connection:

- import `levelCaps` in `assets/js/renderRegulation.js`
- attach it at the existing merge point in `renderRegulation(root)`
- keep `renderLevelCaps(regulation)` reading `regulation.levelCaps`

Expected ownership decision for the implementation gate:

- Decide in that gate whether to remove only the `levelCaps` key from
  `data/regulation.json`.
- If the key is removed, public cache-mixing checks are mandatory, as in the
  `termExplanations` pilot.

Do not introduce:

- standalone JSON/fetch loading
- row normalization
- formula parsing
- executable rule logic
- renderer rewrite

Cache-bust and public delivery targets for the implementation gate:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query for
  `data/regulation.json`
- public availability of
  `assets/js/world/regulation/levelCapsData.js`

QA for the implementation gate:

- `node --check` for changed JavaScript
- `data/regulation.json` parse OK
- data-module import smoke OK
- old JSON `levelCaps` data and new module export match exactly
- public `regulation.html`, `main.js`, `renderRegulation.js`,
  `levelCapsData.js`, and `data/regulation.json` return HTTP 200
- public `data/regulation.json` state matches the chosen ownership decision
- public DOM table has 14 body rows
- public DOM table has the same 11 headers
- public DOM table text matches the baseline
- no broken import path or checked 404
- no fetch or module-load failure

Rollback:

1. Revert the implementation commit, or
2. restore `levelCaps` in `data/regulation.json`, remove the module import, and
   return `renderRegulation(root)` to the previous merge shape.

## First Implementation Out Of Scope

The first `levelCaps` data-module implementation must not touch:

- `LEVEL_CAP_COLUMNS`
- `renderTable()`
- schedule table rendering
- regulation block table rendering
- reward table splitting
- honor or Sword Shard table splitting
- growth rule text
- fumble experience rule text
- lower-bound growth rule text
- magic-angel rulings
- long house rules
- active TOC control
- CSS class names
- DOM ids
- anchors
- regulation copy meaning
- `updates.json`
- auth, membership, RPC, DB/RPC/RLS, Edge Functions, Discord sync, or secrets

## Reusable Ops Core Boundary

`levelCaps` for `regulation.html` belongs to the world-site template side.

Boundary rules:

- Do not move regulation `levelCaps` into reusable ops core.
- Do not connect regulation `levelCaps` to calendar-side level-cap date ranges
  in this gate.
- Do not connect regulation data-module work to `calendar`, `session-post`, or
  `mypage` reusable ops behavior.
- Do not connect it to auth, membership, Discord sync, DB, RPC, or RLS.
- Regulation data work must not break calendar, session-post, mypage,
  session-detail, membership, or Discord-related behavior.

## Limited And Not Tested

This B8 gate is docs-only.

Limited or not tested:

- rendered DOM comparison: `not_tested`
- desktop/mobile visual review: `not_tested`
- active TOC scroll-through behavior: `not_tested`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These are acceptable here because the gate freezes current behavior in docs and
does not change production assets.
