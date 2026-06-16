# World Template Regulation Term Explanations Data Module Public Check

Phase 3-B6 verifies the public rollout of the Phase 3-B5
`termExplanations` data-module split.

This was a read-only public delivery and display check. It did not change
implementation files, JSON data, CSS, `updates.json`, auth/permission logic,
SQL, DB/RPC/RLS, Edge Functions, Discord sync, secrets, or reusable ops core.

Baseline:

- `f7aa94a Extract regulation term explanations data`

Public base:

- `https://suisui334.github.io/velgard-site/`

## Static Delivery Result

| Target | Result | Notes |
| --- | --- | --- |
| `regulation.html` | pass | HTTP 200. The page references `assets/js/main.js?v=20260616-regulation-term-data-module`. |
| `assets/js/main.js` | pass | HTTP 200. The public import references `./renderRegulation.js?v=20260616-regulation-term-data-module`. |
| `assets/js/renderRegulation.js` | pass | HTTP 200 with the expected cache-bust query. It imports `./world/regulation/termExplanationsData.js`. |
| `assets/js/world/regulation/termExplanationsData.js` | pass | HTTP 200. It exports `termExplanations`. |
| `data/regulation.json` | pass | HTTP 200 and JSON parse OK. The `termExplanations` key is absent. |
| `assets/css/style.css` | pass | HTTP 200. `.regulation-term-grid`, `.regulation-term-card`, and `.regulation-callout` are present. |

Renderer path checks:

- `renderRegulation.js` still attaches imported `termExplanations` to the
  loaded regulation object.
- `renderTermExplanations(regulation)` remains the call path.
- `REGULATION_DATA_PATH` points to
  `data/regulation.json?v=20260616-regulation-term-data-module`.
- No broken checked public import path or checked public 404 was found.

## Cache Mixing Risk Check

The specific risky combinations from the B5 split were checked:

| Risk | Result | Notes |
| --- | --- | --- |
| New `data/regulation.json` plus old `renderRegulation.js` | not observed | Public `renderRegulation.js` imports the new data module. |
| Old `regulation.html` plus new `renderRegulation.js` | not observed | Public `regulation.html` uses the expected B5 cache-bust. |
| New `renderRegulation.js` plus missing `termExplanationsData.js` | not observed | Public data module returned HTTP 200. |
| `data/regulation.json` still carrying `termExplanations` | not observed | Public JSON no longer has the key. |

Browser page load did not show a module-load or regulation-data fetch failure.
A non-blocking pre-existing Supabase client warning was observed, but no
regulation module failure was observed.

## Public Module Data Check

Public `termExplanationsData.js` was fetched and parsed as the exported array.

Result:

- `termExplanations.length`: 12
- empty `term` values: 0
- missing or empty `paragraphs` arrays: 0
- callout count: 1
- callout card index: 7

The public title order was:

1. `レベルキャップ`
2. `固定経験点`
3. `下限成長`
4. `下限報酬`
5. `下限名誉点`
6. `上限成長`
7. `上限報酬`
8. `冒険者ランク上限`
9. `報酬金額`
10. `超過報酬`
11. `剣の欠片目安`
12. `ピンゾロ経験点の獲得・成長の方式について`

## Public DOM Check

The public `regulation.html` page was loaded in the browser and checked against
the public data module contents.

Result:

- page title loaded: pass
- `main#app`: present
- `.regulation-page`: present
- `#term-explanations`: present
- `.regulation-term-grid`: present
- `.regulation-term-card`: 12
- card classes: unchanged
- card headings match public module: pass
- card paragraphs match public module: pass
- `.regulation-callout`: 1
- callout card index: 7
- callout content matches public module: pass
- `.regulation-toc-list a[href="#term-explanations"]`: present
- active TOC initial state: one active link, `#schedule`
- `undefined` text in term section: false
- `[object Object]` text in term section: false
- empty heading count: 0
- empty card count: 0

This confirms that removing `termExplanations` from `data/regulation.json` did
not remove the public term explanation cards when the public module chain is
loaded.

## Limited / Not Tested

- Full manual visual inspection across desktop and mobile viewports:
  `limited`.
- Active TOC behavior after scrolling through all sections: `limited`. The
  initial active state and TOC link were checked.
- Regulation pages other than `regulation.html`: `not_tested`.
- Non-regulation pages: `not_tested`; no implementation files were changed in
  this gate.
- Authenticated role-specific behavior, data-changing workflows, Discord sync,
  DB/RPC/RLS, and Edge Functions: `not_tested`; they are out of scope for this
  public world-site data-module rollout check.

## Safety Notes

No unsafe gate was performed:

- no SQL Editor execution
- no SQL apply
- no DB/RPC/RLS mutation
- no Edge Function deploy
- no Discord production post/edit/delete
- no Discord Webhook, secret, or token change
- no direct Supabase write addition
- no auth/permission logic change
- no RPC name or DB column configuration change
- no `updates.json` change
- no raw user id, email, token, JWT, management key, Discord URL/ID, Webhook,
  or secret value recorded

## Next Candidates

1. If this rollout is accepted, choose whether the next regulation pilot should
   remain a data module or wait for a separate JSON/fetch gate.
2. Consider a second short repeated group, such as a simple note/callout group
   or adopted rulebook list, only with a new behavior spec first.
3. Keep level-cap table migration, reward/honor values, long house rules,
   magic-angel ruling data, and standalone JSON migration behind separate
   later gates.
