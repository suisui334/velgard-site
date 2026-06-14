# Reusable Ops Platform Phase 2-A Boundary Plan

## 1. 背景

Phase 1-A〜1-Eでは、calendar / mypage / session-post / session-detail / approved gate 周辺の表示ラベルを `reusableOpsConfig` 系へ段階的に寄せた。

Phase 2-Aでは、将来的にこのサイトを「汎用TRPG運用基盤コア」と「ヴェルガルド固有の世界観紹介サイト」へ分けるため、現行ファイルの境界を棚卸しする。今回は実装変更、ファイル移動、フォルダ再編、CSS分割、HTML構造変更、DB/RPC/RLS変更は行わない。

## 2. Phase 1までの到達点

- `assets/js/reusableOpsConfig.js` が、calendar session type、calendar button、mypage候補、approved gate候補、session-post/detail候補の表示ラベル入口になった。
- `assets/js/reusableOpsMypageLabels.js` が、通常scriptである `mypageAuthClient.js` へ安全にmypageラベルを渡すbridgeになった。
- `sessionDisplay.js`、`renderSessionPost.js`、`renderSessionDetail.js`、`membershipAccessClient.js` の一部表示ラベルが設定参照化された。
- 公開配信では最新cache-bustと公開JS markerを確認済み。
- 認証、approved判定、owner/admin判定、RPC、DB/RPC/RLS、Discord同期処理、`management_key`、内部ID、raw user id、email、token類は設定化していない。

## 3. JSファイル境界一覧

分類:

- A: 汎用運用基盤コア候補
- B: 汎用運用基盤だがヴェルガルド依存が残るもの
- C: ヴェルガルド世界観紹介側
- D: 共通ユーティリティ候補
- E: まだ分類保留

| file | classification | notes |
| --- | --- | --- |
| `assets/js/reusableOpsConfig.js` | A | 運用基盤の表示ラベル/色/設定入口。今後 `core/config` 候補。ただしサイト名などヴェルガルド値も含むため、将来はdefault configとworld overrideに分けたい。 |
| `assets/js/reusableOpsMypageLabels.js` | A | classic script bridge。mypageがmodule化できるまでの安全な接続層。将来はcore config adapterへ移せる。 |
| `assets/js/membershipAccessClient.js` | A | approved gate / membership status / nav非表示判定の中核。表示ラベルは一部設定参照化済み。権限判定ロジックなので慎重に扱う。 |
| `assets/js/supabaseBrowserClient.js` | D | Supabase browser client生成の共通adapter。運用基盤コアに近いが、runtime configとの境界を明確にしてから移す。 |
| `assets/js/supabaseRuntimeConfig.js` | D | 公開runtime config。project固有値を含み得るため、独立ツール化時は配布用exampleと環境別configに分ける。実値をdocsへ記録しない。 |
| `assets/js/supabaseRuntimeConfig.example.js` | D | runtime config example。core配布候補。 |
| `assets/js/dataLoader.js` | D | JSON loaderと可視性/画像補助の共通utility。world-siteでもopsでも使うため、最初に切り出しやすい候補。 |
| `assets/js/sessionDisplay.js` | A | session表示の共通部品、escape、session type、Discord panel表示を持つ。運用基盤コア候補だが、Discord表示と一部文言は追加整理が必要。 |
| `assets/js/sessionData.js` | B | Supabase `sessions` 取得と静的 `sessions.json` fixture合成を持つ重要導線。静的JSON退役、RLS、表示同期に関わるため、移動は後回し。 |
| `assets/js/renderCalendar.js` | B | calendar UIは汎用運用基盤候補。ただし `calendarConfig.json` のヴェルガルド暦/レベルキャップ、session color class、approved-only導線と結びつく。 |
| `assets/js/renderSessionPost.js` | B | 依頼書投稿/編集/削除、テンプレート、Discord同期、approved gate、RPCが密結合。汎用化価値は高いが、移動は危険。 |
| `assets/js/renderSessionDetail.js` | B | 依頼書詳細、GM管理、削除/〆、Discord同期パネル、コメントpanel初期化を束ねる。運用基盤候補だがowner/admin/Discord依存が強い。 |
| `assets/js/sessionDetailApplicationComments.js` | B | 参加申請/コメント、GM履歴、GM連絡先、GMテンプレート、avatar modal、clipboard、複数RPCを抱える大型ファイル。独立前に責務分割が必要。 |
| `assets/js/mypageAuthClient.js` | B | 4700行規模でAuth、Turnstile、profile、avatar、PC、templates、membership management、schedule/application historyを持つ。最重要危険箇所。 |
| `assets/js/renderMypage.js` | A | mypage shellの薄いrenderer。現状は本体処理を `mypageAuthClient.js` に委譲しているため、core page shell候補。 |
| `assets/js/discordSyncClient.js` | B | session-post/detailから呼ばれるDiscord同期adapter。運用基盤候補だがEdge Function、public-site URL、Discord modeに密結合。 |
| `assets/js/notificationBellClient.js` | A | 通知ベルの表示/既読RPC。membership stateとheaderに依存。core notification候補。 |
| `assets/js/renderTimeline.js` | A | activity timeline表示。membership gateとactivity RPCに依存する運用基盤ページ候補。 |
| `assets/js/activityTimelineDisplay.js` | A | TOP/TIMELINE向けactivity表示ラベル/整形。core activity display候補。 |
| `assets/js/renderAdminCapAnnouncements.js` | E | admin向けcap告知/診断系。運用基盤管理ツールかヴェルガルド固有管理か判断保留。 |
| `assets/js/adminCapAnnouncementClient.js` | E | 同上。RPCや運用方針を確認してから分類する。 |
| `assets/js/main.js` | B | header/footer/nav/theme/render dispatch/membership nav gating/notification initを全て束ねる混在ファイル。すぐ動かすと危険。 |
| `assets/js/renderHome.js` | E | TOP hero/world visualとhome activity timelineが混在。world-site homeとops activity panelを分ける設計が必要。 |
| `assets/js/renderTools.js` | E | 現状は `randomTables.json` のTRPG tool表示。汎用toolにもworld固有toolにもなり得るため保留。 |
| `assets/js/renderUpdates.js` | E | 旧更新履歴ページ用。homeではactivityへ置換済み。archive/ops changelog/world changelogのどれにするか保留。 |
| `assets/js/renderWorld.js` | C | world introduction renderer。world-site側。 |
| `assets/js/renderCharacters.js` | C | NPC/人物一覧renderer。world-site側。 |
| `assets/js/renderSpots.js` | C | 地点一覧renderer。world-site側。 |
| `assets/js/renderSpotDetail.js` | C | 地点詳細renderer。spots / gallery / characters / scenarios / termsを横断するworld-site側。 |
| `assets/js/renderScenarios.js` | C | hooks/scenarios一覧renderer。world-site側。ただしsession-postとの導線設計は接続点。 |
| `assets/js/renderScenarioDetail.js` | C | scenario detail renderer。world-site側。 |
| `assets/js/renderTerms.js` | C | 用語辞典renderer。world-site側。 |
| `assets/js/renderRegulation.js` | C | regulation renderer。world-site側。ただし参加/投稿前の規約導線とは接続する。 |
| `assets/js/renderGallery.js` | C | gallery renderer。world-site側。category labels/orderは設定化候補。 |
| `assets/js/renderCampaigns.js` | C | campaign一覧renderer。world-site側。 |
| `assets/js/renderCampaignDetail.js` | C | campaign detail renderer。world-site側。 |
| `assets/js/renderEpisodeDetail.js` | C | episode detail renderer。world-site側。 |

## 4. CSS境界一覧

現状は `assets/css/style.css` の単一ファイルで、約7400行規模。今すぐ分割しない。

将来の境界候補:

| candidate | scope | notes |
| --- | --- | --- |
| `core.css` | button, form, card, details, modal, header/footer, utility layout | ops/world両方で使う共通UI。最初は抽出せず、セレクタ責務表だけ作るのが安全。 |
| `ops.css` | calendar, mypage, auth/Turnstile, membership gate, membership management, session-post/detail, comment/application, notification, timeline, Discord sync panel | 運用基盤UI。`body[data-page="calendar"]`、`body[data-page="session-detail"]`、`body[data-page="mypage"]` 周辺を中心に分けられる。 |
| `world.css` | world, characters, spots, spot-detail, scenario, terms, regulation, gallery, campaign/episode | 世界観紹介ページの表示骨格。デザイン固定ではなくカード/一覧/詳細/辞書/規約/ギャラリー構造を保持する。 |
| `theme-velgard.css` | logo, key visual, background, palette, world-specific atmosphere, home hero visual tone | ヴェルガルド固有の見た目。別世界観では差し替える。 |

確認した混在点:

- header/nav/footerは全ページ共通だが、approved-only nav gatingとworld-site navが同居している。
- calendar/session/mypageのopsスタイルは `style.css` 中盤以降にまとまっているが、共通カード/フォーム/ボタンと密接。
- regulation/gallery/spot-detail/charactersなどworld-siteのセレクタも同じCSSに混在している。
- theme background、logo、hero、色は `site.json` とCSS変数で一部切り替え可能だが、完全なtheme分離には未達。

## 5. HTMLページ境界一覧

| page | classification | notes |
| --- | --- | --- |
| `calendar.html` | A 運用基盤ページ | approved member向けcalendar。core ops候補。 |
| `mypage.html` | A 運用基盤ページ | Auth、profile、PC、template、membership management。core ops候補だが本体JSが巨大。 |
| `session-post.html` | A 運用基盤ページ | 依頼書作成/編集。Discord同期導線に注意。 |
| `session-detail.html` | A 運用基盤ページ | 依頼書詳細、申請、コメント、GM管理。core ops候補。 |
| `timeline.html` | A 運用基盤ページ | activity timeline。notification/activity系core候補。 |
| `admin-cap-announcements.html` | D 判断必要 | admin運用ページ。世界観のレベルキャップ告知か、汎用管理機能か追加確認が必要。 |
| `index.html` | C 共通入口/混在ページ | world heroとhome activity panelが混在。world homeとops dashboardの境界設計が必要。 |
| `tools.html` | C 共通入口/混在ページ | random table tool。世界観固有toolか汎用toolか保留。 |
| `updates.html` | C 共通入口/混在ページ | 旧更新履歴。activity timeline導入後の役割を再定義する。 |
| `world.html` | B 世界観紹介ページ | world-site側。 |
| `characters.html` | B 世界観紹介ページ | world-site側。 |
| `spots.html` | B 世界観紹介ページ | world-site側。 |
| `spot-detail.html` | B 世界観紹介ページ | world-site側。 |
| `hooks.html` | B 世界観紹介ページ | scenarios rendererを使用。hooks/scenarios統合方針が必要。 |
| `scenarios.html` | B 世界観紹介ページ | world-site側。ただしsession-post導線との接続点。 |
| `scenario-detail.html` | B 世界観紹介ページ | world-site側。 |
| `terms.html` | B 世界観紹介ページ | world-site側。 |
| `regulation.html` | B 世界観紹介ページ | world-site側。ただし運用規約としてsession/mypageに接続。 |
| `gallery.html` | B 世界観紹介ページ | world-site側。 |
| `campaigns.html` | B 世界観紹介ページ | world-site側。 |
| `campaign-detail.html` | B 世界観紹介ページ | world-site側。 |
| `episode-detail.html` | B 世界観紹介ページ | world-site側。 |
| `dev/*.html` | E 開発検証用 | 本番ページではない。独立ツール化時はdev sandboxとして別管理。 |

## 6. data境界一覧

| data file | classification | notes |
| --- | --- | --- |
| `data/calendarConfig.json` | B ops config with world values | calendar運用設定。日付、ラクシア暦、季節、月相、レベルキャップは世界観/キャンペーン依存。core schema + world configへ分けたい。 |
| `data/sessions.json` | E legacy fixture | 静的session fixture。通常UIはSupabase優先で、query指定時のみ含める設計。独立化時はdev fixtureへ移す候補。実ID風サンプルやDiscord URL風サンプルを本番dataに残すべきか再確認する。 |
| `data/site.json` | C mixed site/world theme | サイト名、ロゴ、theme、placeholder、publicUrl、metaを持つ。world theme configとdeploy/site configに分けたい。 |
| `data/world.json` | C world-site data | 世界紹介。次世界観でもschema流用候補。 |
| `data/characters.json` | C world-site data | 人物/NPC。schema流用候補。 |
| `data/spots.json` | C world-site data | 地点一覧。schema流用候補。 |
| `data/spotDetails.json` | C world-site data | 地点詳細長文。schema流用候補だが文章量と構造はworld依存。 |
| `data/scenarios.json` | C world-site data | hooks/scenarios data。session-post導線と接続し得る。 |
| `data/hooks.json` | E duplicate/legacy candidate | scenariosとほぼ重なる構造。統合/退役/別用途の判断が必要。 |
| `data/terms.json` | C world-site data | 用語辞典。schema流用候補。 |
| `data/regulation.json` | C world-site data | 規約/裁定。運用基盤と接続するが内容はworld/campaign依存。 |
| `data/gallery.json` | C world-site data | gallery metadata。category設計はテンプレート化候補。 |
| `data/campaigns.json` | C world-site data | campaign紹介。次世界観でも使えるが必須ではない。 |
| `data/episodes.json` | C world-site data | campaign episode紹介。任意module候補。 |
| `data/randomTables.json` | E tools/world-specific | TRPG tool data。汎用toolとして切り出すか、ヴェルガルド固有toolとして残すか保留。 |
| `data/updates.json` | E legacy/news | 旧更新履歴。home activity panelとは別。site changelogとして残すか退役するか判断が必要。 |

## 7. 将来フォルダ構成案

実装はまだ行わない。段階的に以下へ近づける。

```text
assets/
  js/
    core/
      config/
        reusableOpsConfig.js
        mypageLabelBridge.js
      shared/
        dataLoader.js
        supabaseBrowserClient.js
      membership/
        membershipAccessClient.js
      session/
        sessionData.js
        sessionDisplay.js
        renderCalendar.js
        renderSessionPost.js
        renderSessionDetail.js
        sessionDetailApplicationComments.js
      mypage/
        renderMypage.js
        mypageAuthClient.js
      notification/
        notificationBellClient.js
        renderTimeline.js
        activityTimelineDisplay.js
      discord/
        discordSyncClient.js
    world/
      renderHome.js
      renderWorld.js
      renderCharacters.js
      renderSpots.js
      renderTerms.js
      renderRegulation.js
      renderGallery.js
      renderScenarios.js
      renderCampaigns.js
    velgard/
      worldConfig.js
      homeVisualConfig.js
  css/
    core.css
    ops.css
    world.css
    theme-velgard.css
data/
  core/
    session-fixtures/
  world/
    velgard/
      site.json
      calendarConfig.json
      world.json
      characters.json
      spots.json
      regulation.json
      gallery.json
```

最初の実装段階ではこの構成へ一気に移さない。まずdocs上の分類、次にconfigの追加、最後に小さなutilityから移す。

## 8. 依存関係の危険箇所

### `main.js`

- 全rendererをimportし、nav、header/footer、theme、membership nav gating、notification bell初期化を持つ。
- world-siteとops-coreを一括で束ねているため、ファイル移動やrenderer分割の最初の対象にしない。
- 先にnav registryとrenderer registryのdocs設計が必要。

### `mypageAuthClient.js`

- Auth、Turnstile、profile、Discord ID、avatar、PC、template、membership status、membership management、schedule/application historyを抱える。
- classic scriptであり、module化はロード順/SDK読み込み/Turnstile/Auth処理に影響し得る。
- まずは責務単位のdocs分類とlabel bridge拡張に留める。

### `style.css`

- shared UI、ops UI、world-site UI、Velgard themeが混在。
- 一括分割は高リスク。最初はセレクタ責務マップを作り、次にコメント区切りまたは新規追加分だけ分離する。

### `sessionData.js`

- Supabase `sessions` と静的 `sessions.json` fixtureを合成する。
- RLS、公開/非公開表示、Discord同期status、static fixture退役方針に関わるため、移動前にadapter設計が必要。

### `renderSessionPost.js` / `renderSessionDetail.js`

- RPC、approved gate、owner/admin checks、Discord同期、template UI、delete/close操作が絡む。
- 表示ラベル設定化は進められるが、ファイル移動や責務分割はfunctional QAを伴う別ゲートにする。

### `sessionDetailApplicationComments.js`

- 参加申請、コメント、GM履歴、GM連絡先、GMテンプレート、avatar modalを一つに持つ。
- 将来は application/comment core、GM management、template/clipboard、avatar displayへ分けたいが、現時点で触ると申請/コメントQA範囲が広い。

### `discordSyncClient.js`

- session作成/更新/削除とEdge Functionに直結する。
- 独立ツール化時はDiscord provider adapter化が必要。今は文言棚卸しとdocs設計だけに留める。

### world-site renderer群

- `renderGallery.js` のcategory labels/order、`renderRegulation.js` のTOC/level cap columns、`renderHome.js` のhero/logo altがworld固有。
- 構造は流用可能だが、デザインやカテゴリを固定しない。

## 9. すぐに動かしてはいけないファイル

以下は最初の移動対象にしない。

- `assets/js/main.js`
- `assets/js/mypageAuthClient.js`
- `assets/css/style.css`
- `assets/js/sessionData.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/discordSyncClient.js`
- `assets/js/notificationBellClient.js`
- `assets/js/membershipAccessClient.js`

理由:

- 認証、membership gate、RPC、RLS前提、Discord同期、通知、申請/コメント、cache-bust、公開/非公開表示の複数境界にまたがるため。

## 10. 最初に分離してよい候補

実装ゲートを切るなら、以下から始めるのが比較的安全。

1. docs-only schema map:
   - JS/CSS/data分類表を更新し続ける。
2. `reusableOpsConfig.js` の表示ラベル追加:
   - 認証/権限/RPC名/DB名を含めず、fallback必須で進める。
3. `dataLoader.js` の責務文書化:
   - 移動はまだしない。共通utilityとして最初に候補化する。
4. world-site config候補:
   - `renderGallery.js` category labels/order、`renderRegulation.js` TOC/columnsを表示設定化する小設計。
5. CSS責務マップ:
   - `style.css` を移動せず、セレクタをshared/ops/world/themeへ分類するdocsを作る。
6. data schema docs:
   - `world` / `characters` / `spots` / `terms` / `regulation` / `gallery` の項目表を作る。

## 11. 段階的移行手順

### Phase 2-A: 境界計画

- この文書を作成。
- 実装変更なし。
- 完了条件: JS/CSS/HTML/dataの境界と危険箇所が見える。

### Phase 2-B: CSS責務マップ

- `style.css` を分割せず、セレクタをshared/ops/world/themeへ分類する。
- 危険工程なし。docsのみ。

### Phase 2-C: nav / renderer registry設計

- `main.js` からいきなり切らず、navItemsとrenderersをregistryとしてどう分けるかdocs化する。
- 実装する場合はcache-bustと全ページ表示QAが必要。

### Phase 2-D: world-site config小実装

- `renderGallery.js` のcategory labels/order、`renderRegulation.js` のTOC/columnsなど、world-site側の表示固定値を設定化する。
- DB/RPC/RLSなし。表示QAあり。

### Phase 2-E: ops UI追加ラベル設定化

- session-post/detail、mypage、membership management、Discord panelの残り表示文言を、操作ロジックから切れる範囲で設定化する。
- 認証/権限/RPC/DB/Discord実行処理は触らない。

### Phase 2-F: small utility extraction

- `dataLoader.js` や pure formatting helperなど、依存が薄いutilityだけを同一repo内で移動する。
- import/cache-bust変更を伴うため別ゲート。

### Phase 2-G: ops core module split design

- `mypageAuthClient.js`、`sessionDetailApplicationComments.js`、`renderSessionPost.js`、`renderSessionDetail.js` の責務分割案を作る。
- 実装はさらに後続。functional QA計画が必要。

## 12. 次工程候補

1. `style.css` responsibility audit:
   - `shared / ops / world / theme-velgard` のセレクタ分類表を作る。
2. `main.js` registry design:
   - navItems/renderers/theme/header/footer/notification initをどう分けるか設計する。
3. world-site config Phase W-1:
   - gallery category labels/order、regulation TOC/level cap columnsの表示設定化案を作る。
4. data schema docs:
   - world-site JSON schemaを次世界観向けに項目表化する。
5. ops label Phase 2-E:
   - mypage/session/membership/Discordの残り表示ラベルを、安全なものから設定化する。

## Prohibited Work Confirmed

This gate did not perform implementation changes, file moves, folder restructuring, CSS split, HTML structure changes, JS import/export restructuring, SQL Editor execution, DB/RPC/RLS mutation, SQL apply, Edge Function deploy, Discord operation, secret or webhook change, direct Supabase write addition, `console.*` addition, `updates.json` change, or independent app extraction.

## Phase 2-B Config Move Result

After this boundary plan, Phase 2-B performed the first physical separation
only for reusable operations config files:

- `assets/js/reusableOpsConfig.js` moved to
  `assets/js/core/config/reusableOpsConfig.js`.
- `assets/js/reusableOpsMypageLabels.js` moved to
  `assets/js/core/config/reusableOpsMypageLabels.js`.

Only import/script references and cache-bust markers were updated. The public
module exports and the `window.VELGARD_REUSABLE_OPS_MYPAGE` bridge name remain
unchanged. The move does not change auth, membership, RPC, DB, Discord sync,
approved-gate decisions, owner/admin checks, or fallback labels.

The high-risk files listed in section 9 are still intentionally unmoved. Any
future move of `main.js`, `mypageAuthClient.js`, `sessionData.js`,
`renderSessionPost.js`, `renderSessionDetail.js`, `discordSyncClient.js`, or
`style.css` remains a separate design and QA gate.

Detailed result: `docs/reusable-ops-platform-phase2b-config-move-result.md`.

## Phase 2-C Config Public Check Result

Phase 2-C confirmed the Phase 2-B config move on public delivery. Public HTML
for calendar, mypage, session-post, and session-detail uses the updated
`main.js` cache-bust, and public mypage HTML loads the moved classic bridge
from `assets/js/core/config/reusableOpsMypageLabels.js`.

Public JS checks found no active old root-path references for
`assets/js/reusableOpsConfig.js` or `assets/js/reusableOpsMypageLabels.js`.
The reusable module export and `window.VELGARD_REUSABLE_OPS_MYPAGE` bridge
markers remain present.

No cache-bust fix was needed. No implementation, auth, permission, RPC, DB,
Discord sync, CSS split, or file movement beyond the prior config move was
performed.

Detailed result: `docs/reusable-ops-platform-phase2c-config-public-check.md`.

## Phase 2-D Calendar Renderer Move Result

Phase 2-D moved the calendar renderer from `assets/js/renderCalendar.js` to
`assets/js/core/calendar/renderCalendar.js`.

The move was accepted because the active runtime reference was limited to
`assets/js/main.js`, the renderer already exposed a single `renderCalendar`
entry point, and the required import updates were narrow relative-path changes.
`main.js`, `sessionData.js`, `sessionDisplay.js`, `membershipAccessClient.js`,
`renderSessionPost.js`, `renderSessionDetail.js`, `discordSyncClient.js`, and
`style.css` were not moved.

All HTML entry pages that load `assets/js/main.js` were updated to the
`20260615-calendar-core-move` cache-bust so public clients do not retain the old
module graph. Active HTML/JS has no old `assets/js/renderCalendar.js` or
`./renderCalendar.js` runtime import left.

This is still only a physical boundary step. Calendar data loading,
approved-member gate behavior, session display helpers, and Discord sync remain
unchanged. A public rollout check for the moved calendar renderer is a separate
optional follow-up after deployment/cache propagation.

Detailed result: `docs/reusable-ops-platform-phase2d-calendar-boundary-result.md`.

## Phase 2-E Calendar Renderer Public Check Result

Phase 2-E confirmed the Phase 2-D calendar renderer move on public delivery.
Public `calendar.html` references the `20260615-calendar-core-move` `main.js`
cache-bust, public `main.js` imports
`assets/js/core/calendar/renderCalendar.js`, and the moved renderer path is
served successfully.

Active public and local HTML/JS checks found no runtime reference to
`assets/js/renderCalendar.js` or `./renderCalendar.js`. The old root renderer
path returned 404 for the checked cache-bust. No additional cache-bust fix was
needed.

The check did not change auth, permissions, RPC, DB, Discord sync, session
loading, approved-gate logic, or CSS. Authenticated full-calendar browser
operation remains a separate optional QA gate.

Detailed result: `docs/reusable-ops-platform-phase2e-calendar-public-check.md`.

## Phase 2-F Session Display Boundary Result

After the calendar renderer move, browser QA with an approved signed-in session
confirmed that calendar display, month movement, the today button, session type
labels/colors, closed-session marks, GM-name display, and session-detail links
work. No visible bad label markers were observed, and no sensitive values were
recorded.

The follow-up audit kept `assets/js/sessionDisplay.js` unmoved. It imports only
the reusable ops config, but it is imported by calendar, session-post,
session-detail, and admin-cap announcement rendering. It also mixes pure
helpers with session-detail management, Discord sync panel, and
participation-comment panel rendering.

Classification: `sessionDisplay.js` is core-oriented, but should be split
before moving. Move pure helpers first in a future gate, and leave
session-detail UI block renderers until separate session-detail and Discord
sync QA gates exist.

Detailed result:
`docs/reusable-ops-platform-phase2f-session-display-boundary-plan.md`.
