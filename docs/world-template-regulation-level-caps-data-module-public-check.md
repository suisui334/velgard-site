# World Template Regulation Level Caps Data Module Public Check

Phase 3-B10 verifies the public rollout of the Phase 3-B9 `levelCaps` data
module split.

This is a public delivery check. It does not change implementation, HTML, CSS,
JavaScript, JSON/data, renderers, regulation copy, `updates.json`, or reusable
ops core behavior.

Baseline:

- `8d10447 Extract regulation level caps data`

Expected cache-bust:

- `20260617-regulation-level-caps-data-module`

## Public Static Delivery

Checked public files on GitHub Pages:

| Public file | Result |
| --- | --- |
| `regulation.html` | HTTP 200 |
| `assets/js/main.js?v=20260617-regulation-level-caps-data-module` | HTTP 200 |
| `assets/js/renderRegulation.js?v=20260617-regulation-level-caps-data-module` | HTTP 200 |
| `assets/js/world/regulation/levelCapsData.js` | HTTP 200 |
| `assets/js/world/regulation/termExplanationsData.js` | HTTP 200 |
| `data/regulation.json?v=20260617-regulation-level-caps-data-module` | HTTP 200 |
| `assets/js/dataLoader.js` | HTTP 200 |
| `assets/css/style.css?v=20260615-regulation-wide-layout` | HTTP 200 |

Public file equivalence:

- public `regulation.html` matched the local `HEAD` file after line-ending
  normalization
- public `main.js` matched the local `HEAD` file after line-ending
  normalization
- public `renderRegulation.js` matched the local `HEAD` file after line-ending
  normalization
- public `levelCapsData.js` matched the local `HEAD` file after line-ending
  normalization
- public `data/regulation.json` matched the local `HEAD` file after
  line-ending normalization

The HTML-referenced CSS path was served and still contained the regulation
table and TOC classes checked in this gate.

## Cache-Bust Chain

Confirmed:

- public `regulation.html` references
  `assets/js/main.js?v=20260617-regulation-level-caps-data-module`
- public `main.js` imports
  `./renderRegulation.js?v=20260617-regulation-level-caps-data-module`
- public `renderRegulation.js` loads
  `data/regulation.json?v=20260617-regulation-level-caps-data-module`
- public `renderRegulation.js` imports
  `./world/regulation/levelCapsData.js`

Cache-mixing risks checked:

- new `data/regulation.json` plus old `renderRegulation.js`: not observed
- old `regulation.html` plus new `renderRegulation.js`: not observed
- new `renderRegulation.js` plus missing `levelCapsData.js`: not observed

Checked public 404 count for the files above:

- `0`

## Public Renderer Checks

Public `renderRegulation.js` confirmed:

- imports `levelCapsData.js`
- imports `termExplanationsData.js`
- attaches imported `levelCaps` to the regulation object
- keeps `renderLevelCaps(regulation)` present
- keeps the call path `renderTable(rows, LEVEL_CAP_COLUMNS)`
- keeps `renderTable()` present
- keeps the `level-caps` TOC id
- keeps the `level-caps` section creation path
- keeps `.regulation-table-wrap`
- keeps `.regulation-table`

Because public `renderRegulation.js` matched the local `HEAD` file, this also
confirms the public file is serving the same `LEVEL_CAP_COLUMNS` and
`renderTable()` implementation as Phase 3-B9.

## Public Data Module Checks

Public `levelCapsData.js` confirmed:

- exports `levelCaps`
- imported/evaluated as an array in the static smoke check
- row count: 14
- first row `levelCap`: `Lv2`
- last row `levelCap`: `Lv15`
- every row has the expected 11 fields
- every cell value is a non-empty string
- no `undefined` text in the exported row data
- no `[object Object]` text in the exported row data
- no empty row in the exported row data

The public data module matched the local `HEAD` file after line-ending
normalization.

## Public Regulation JSON Checks

Public `data/regulation.json` confirmed:

- HTTP 200
- parse OK
- top-level `levelCaps` key: absent
- top-level keys:
  - `status`
  - `pageLabel`
  - `title`
  - `subtitle`
  - `lead`
  - `schedule`
  - `adoptedRulebooks`
  - `sections`

This confirms the JSON ownership change is live publicly.

## Display-Equivalent Checks

Full browser visual QA was not performed in this gate. Instead, the public
renderer and public data module were combined in a static display-equivalent
check.

Confirmed:

- level-cap table body row count: 14
- first row remains `Lv2`
- last row remains `Lv15`
- expected column count remains 11
- expected row fields are present for every row
- cell count is 154
- all cell values are non-empty strings
- no `undefined`
- no `[object Object]`
- no empty rows
- public renderer still imports `termExplanationsData.js`
- public renderer still places `renderLevelCaps(regulation)` before
  `renderTermExplanations(regulation)`

CSS/class checks through public renderer and HTML-referenced CSS:

- `#level-caps` path: present
- `#level-caps` TOC id: present
- `.regulation-table-wrap`: present
- `.regulation-table`: present
- `.regulation-toc`: present in served CSS
- `.toc a.toc-link-active`: present in served CSS

## Limited And Not Tested

Limited or not tested in this gate:

- full browser DOM inspection: `limited`
- desktop/mobile visual review: `not_tested`
- scroll-through active TOC behavior: `limited`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

Reason:

- this gate focused on public static delivery, module availability, cache-bust
  consistency, JSON state, and table data equivalence
- no browser automation library was available in the workspace for a full DOM
  or visual pass

## Result

Phase 3-B10 public rollout check passed for the checked static delivery path.

Observed public state:

- `levelCapsData.js` is publicly available
- public `renderRegulation.js` imports the module
- public `data/regulation.json` no longer carries `levelCaps`
- public level-cap data remains 14 rows, ordered `Lv2` through `Lv15`
- no checked broken import path or 404 was observed
- no checked cache-mixing risk was observed

## Next Step

Recommended next gate:

- summarize the second data-module pilot and decide whether to stop after two
  pilots or choose another small regulation data candidate

Keep out of scope until a separate gate:

- `LEVEL_CAP_COLUMNS` extraction
- `renderTable()` changes
- reward/honor/Sword Shard table splitting
- long rule or magic-angel data migration
- standalone JSON/fetch migration
- reusable ops core integration
