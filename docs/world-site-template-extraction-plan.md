# World Site Template Extraction Plan

## 1. 背景

Phase 1-A〜1-Cでは、calendar / mypage を中心に、汎用TRPG運用基盤へ近づけるための設定入口を整えた。

この文書では、ヴェルガルド固有の世界観紹介ページ群を対象に、将来別世界観を立てる場合に流用できる「ページ骨格」「データ項目」「表示ブロック」「導線設計」を棚卸しする。今回は実装変更、ファイル移動、フォルダ再編、JSON構造変更、DB/RPC/RLS変更は行わない。

## 2. テンプレート化の定義

ここでいうテンプレート化は、デザイン固定ではない。

テンプレート化対象:

- ページ種別。
- データ項目。
- 表示ブロック。
- JSON構造。
- ナビゲーションの考え方。
- カテゴリ設計。
- 画像ギャラリーの扱い。
- 用語、規約、人物、地点、シナリオ候補の管理方式。

テンプレート固定しないもの:

- 色。
- ロゴ。
- キービジュアル。
- 背景画像。
- 装飾。
- 文章量。
- 画面の雰囲気。
- 世界観固有の固有名詞。

別世界観では、同じ「ページ骨格」を使っても、見た目とトーンは世界観ごとに作り替える前提にする。

## 3. 現在の世界観紹介ページ一覧

現在の世界観紹介側の主なページ:

- `index.html`: トップ、キービジュアル、主要導線、最近の活動。
- `world.html`: 世界概要、セクション型本文、目次。
- `characters.html`: NPC/人物一覧、地域フィルタ、画像モーダル。
- `spots.html`: 地点/施設一覧、カテゴリフィルタ、関連NPC導線。
- `spot-detail.html`: 地点詳細、地図/関連画像、関連NPC/シナリオ/用語導線。
- `hooks.html`: 互換ページ。現状は `renderScenarios` に接続されている。
- `scenarios.html`: シナリオ候補一覧、カテゴリフィルタ、画像モーダル。
- `scenario-detail.html`: シナリオ候補詳細、関連地点/関連NPC。
- `terms.html`: 用語辞典、カテゴリフィルタ、検索、アンカー。
- `regulation.html`: レギュレーション、長文裁定、表、リスト、details。
- `gallery.html`: 画像ギャラリー、カテゴリフィルタ、検索、モーダル、左右移動。
- `campaigns.html` / `campaign-detail.html` / `episode-detail.html`: キャンペーン紹介、エピソード記事。
- `tools.html`: ランダム表などの補助ツール。世界観紹介側と運用補助の中間。

運用基盤側として扱うページ:

- `calendar.html`
- `session-post.html`
- `session-detail.html`
- `mypage.html`
- `timeline.html`
- `admin-cap-announcements.html`

## 4. ページ別棚卸し

分類:

- A: 次世界観でもほぼ流用できるページ骨格。
- B: データ項目を差し替えれば流用できるもの。
- C: デザイン・演出だけ差し替えれば流用できるもの。
- D: ヴェルガルド固有性が強く、テンプレート化しにくいもの。
- E: 将来テンプレート化する際に障害になりそうな依存。

### index

分類: A / B / C / E

流用しやすい骨格:

- キービジュアルつきトップ。
- ロゴ/タイトル。
- 主要ページへのカード型ナビ。
- 最近の活動/TIMELINE枠。
- 画像拡大モーダル。

差し替え候補:

- サイト名、世界観名、タグライン。
- ロゴ、キービジュアル、背景。
- TOP導線のページ構成。
- 最近の活動枠を使うか、静的お知らせにするか。

障害になりそうな依存:

- `homeNavItems` が `renderHome.js` に固定で書かれている。
- `TOOLS`、`CALENDAR`、`TIMELINE` のような運用基盤導線と世界観紹介導線が同じ配列に混在している。
- approved gate によって一部導線を隠す挙動がトップページにも入っている。

### world

分類: A / B / C

流用しやすい骨格:

- `data/world.json` の `pageTitle`、`pageLabel`、`lead`、`sections`。
- セクション単位の本文。
- 目次。
- サブセクション。

差し替え候補:

- 世界概要、地理、歴史、組織、文化、魔法/技術、世界観固有用語。
- section IDとタイトル。
- セクション画像。

テンプレート候補:

- `world.json` を、任意のセクション配列を持つ世界ガイドデータとして扱う。
- 目次生成と本文レンダリングはほぼ流用可能。

### characters

分類: A / B / C / E

流用しやすい骨格:

- 人物/NPCカード一覧。
- 地域または所属によるフィルタ。
- 画像モーダル。
- 関連地点への導線。

現在の主な項目:

- `id`
- `status`
- `official`
- `alias`
- `name`
- `race`
- `gender`
- `region`
- `affiliation`
- `role`
- `summary`
- `description`
- `relatedSpotIds`
- `image`

障害になりそうな依存:

- `official === true` の扱いがヴェルガルド運用に寄っている。
- フィルタが地域/地点由来で、別世界観では所属、勢力、登場章などに変えたい可能性がある。
- `relatedHooks` のような互換項目が残る場合、次世界観では整理が必要。

### spots / facilities

分類: A / B / C

流用しやすい骨格:

- 地点/施設カード一覧。
- カテゴリフィルタ。
- 地点詳細ページ。
- 地図、関連画像、関連施設画像。
- 関連NPC、関連シナリオ、関連用語への導線。

現在の主な項目:

- `spots.json`: `id`, `name`, `category`, `image`, `thumbnail`, `role`, `summary`, `hooks`, `organizations`, `relatedCharacters`, `status`
- `spotDetails.json`: `definition`, `lead`, `sections`, `mapGalleryIds`, `relatedGalleryIds`, `relatedFacilityGalleryIds`, `relatedCharacterIds`, `relatedScenarioIds`, `relatedTermIds`, `notes`

テンプレート候補:

- 一覧用の軽量データと詳細用の長文データを分ける構造は流用しやすい。
- 関連データID配列で人物、シナリオ、用語、画像を接続する方式も流用しやすい。

### hooks / scenarios

分類: A / B / E

流用しやすい骨格:

- シナリオ候補一覧。
- カテゴリ/ジャンル。
- 画像。
- 概要、説明、例。
- 関連地点、関連NPC。
- 詳細ページ。

現在の主な項目:

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

障害になりそうな依存:

- `hooks.html` は残っているが、現状は `renderScenarios` に紐づいている。
- `data/hooks.json` は互換・比較用として残っており、正式表示は `scenarios.json` 側へ寄っている。
- 次世界観では、`hooks` を残すのか、`scenarios` に統一するのかを先に決めた方がよい。

運用基盤との接続点:

- `session-post` の依頼書テンプレートやシナリオ候補選択と連携できる可能性がある。
- ただし、今回のテンプレート化では依頼書作成RPCやDiscord同期には触れない。

### terms

分類: A / B

流用しやすい骨格:

- 用語辞典。
- カテゴリフィルタ。
- 検索。
- 用語ごとのアンカー。
- 関連地点、関連NPC。

現在の主な項目:

- `id`
- `term`
- `category`
- `summary`
- `relatedSpots`
- `relatedCharacters`
- `status`

テンプレート候補:

- `terms.json` は次世界観でもそのまま使いやすい。
- 関連先として、地点、人物、シナリオ、規約項目などを追加できる余地がある。

### regulation

分類: A / B / E

流用しやすい骨格:

- レギュレーションページ。
- 目次。
- スケジュール表。
- レベルキャップ表。
- 用語説明。
- 採用ルールブック。
- カテゴリ別長文項目。
- paragraphs / callout / list / ordered / subsections / table / details 型の表示ブロック。

現在の主な項目:

- `pageLabel`
- `title`
- `subtitle`
- `lead`
- `schedule`
- `levelCaps`
- `termExplanations`
- `adoptedRulebooks`
- `sections`

障害になりそうな依存:

- `TOC_ITEMS` と `LEVEL_CAP_COLUMNS` が `renderRegulation.js` に固定で書かれている。
- 「魔動天使の使用制限」のような長文裁定はJSON化されているが、項目カテゴリや目次固定値はコード側にも残っている。
- 次世界観ではレベルキャップ表の列が変わる可能性があるため、列定義もデータ化候補。

### gallery

分類: A / B / C / E

流用しやすい骨格:

- 画像一覧。
- カテゴリフィルタ。
- 検索。
- 画像モーダル。
- 左右移動。
- スワイプ。

現在の主な項目:

- `id`
- `category`
- `title`
- `image`
- `description`

障害になりそうな依存:

- `categoryLabels` と `categoryOrder` が `renderGallery.js` に固定で書かれている。
- `key-visual`, `locations`, `facilities`, `scenarios`, `maps` は次世界観でも使えるが、カテゴリ追加/削除は設定化した方がよい。
- `assets/images/hooks/` や `gallery-hook-*` の互換維持は、次世界観では不要になる可能性がある。

### tools

分類: B / E

流用しやすい骨格:

- ランダム表。
- 分岐表。
- 履歴。
- コピー。

現在の主な項目:

- `randomTables.json`: `version`, `description`, `tables`
- table側: `id`, `title`, `type`, `dice`, `description`, `branches`

位置づけ:

- 世界観紹介ページというより、プレイ補助ツール。
- 将来の汎用運用基盤に寄せるか、世界観固有補助として残すかは別途判断する。

## 5. データ構造別棚卸し

### `data/site.json`

分類: B / C

役割:

- サイト名。
- 短縮名。
- タグライン。
- 説明。
- キービジュアル。
- ロゴ。
- テーマ背景。
- placeholder画像。
- basicInfo。
- concepts。
- OGP系meta。

テンプレート化方針:

- 世界観ごとのサイト設定として最重要。
- public URLや実デプロイ先は、docsやテンプレートに実値を持ち込まず、環境ごとの設定として扱う。

### `data/world.json`

分類: A / B

任意の世界紹介セクション配列として流用しやすい。次世界観でも、地理、歴史、文化、組織、技術、宗教などをsectionとして持てる。

### `data/characters.json`

分類: A / B / E

人物データとして流用可能。ただし、`official`、`region`、`race`、`relatedSpotIds` の意味は世界観ごとに調整が必要。

### `data/spots.json` / `data/spotDetails.json`

分類: A / B

一覧用と詳細用の分離はよい構造。関連IDでNPC、シナリオ、用語、画像に接続できるため、次世界観でも使いやすい。

### `data/scenarios.json` / `data/hooks.json`

分類: B / E

シナリオ候補データとしては使いやすい。一方で、`hooks.json` は互換・比較用として残っており、次世界観では初期段階で統一方針を決める必要がある。

### `data/terms.json`

分類: A / B

用語辞典として流用しやすい。次世界観では関連先を地点/人物だけでなく、シナリオ/規約/キャンペーンにも広げられる。

### `data/regulation.json`

分類: A / B / E

長文規約のデータ化は進んでいる。block type方式は流用可能。目次やレベルキャップ列定義の固定値が残っている点は、今後の設定化候補。

### `data/gallery.json`

分類: A / B / C / E

画像メタデータとして流用しやすい。カテゴリ定義と表示順はコード固定なので設定化候補。

### `data/campaigns.json` / `data/episodes.json`

分類: A / B

キャンペーン紹介、章/エピソード記事として流用可能。次世界観が連作紹介を持たない場合は任意機能として扱う。

### `data/randomTables.json`

分類: B

世界観固有表にも汎用TRPGツールにもできる。ツール側の分類は、運用基盤か世界観サイトかを後続で決める。

## 6. ヴェルガルド固有依存

固有性が強いもの:

- ロゴ、キービジュアル、背景、OGP画像、placeholder画像。
- `site.json` のタイトル、タグライン、basicInfo、concepts。
- `world.json` の本文、セクション画像。
- 人物、地点、用語、規約、ギャラリー画像の実データ。
- レギュレーションのSW2.5/ヴェルガルド固有裁定。
- 魔動天使など個別裁定の本文。
- `assets/css/style.css` 内のホーム演出、色、背景、カード雰囲気。
- gallery categoryの文言。
- `homeNavItems` の表示文言。

テンプレート化時に注意すること:

- デザインを固定しない。
- 固有名詞をcore側へ移さない。
- 世界観本文と運用機能のラベルを混ぜない。

## 7. 次世界観でも流用できる骨格

流用候補:

- Top: hero + site nav + activity/news block。
- World: section + subsection + table of contents。
- Characters: card grid + category/filter + modal。
- Spots: card grid + detail page + related links。
- Scenarios: card grid + detail page + related links。
- Terms: dictionary + category filter + search + anchor。
- Regulation: long-form blocks + table/list/details/callout。
- Gallery: category filter + search + modal + previous/next。
- Campaigns: optional campaign list + episode detail。

## 8. 設定ファイル化・データ差し替え候補

短期候補:

- `homeNavItems` のデータ化。
- gallery category labels/orderのデータ化。
- regulation TOC labels/orderのデータ化。
- regulation level cap table columnsのデータ化。
- world-site page registryのデータ化。
- character filter axisの設定化。
- spots/scenarios/termsの関連リンクラベルの設定化。

中期候補:

- `data/world-site-config.json` の新設。
- `data/world/gallery-config.json` のような世界観別画像カテゴリ設定。
- `data/world/regulation-config.json` のような規約表示設定。
- `assets/js/worldSiteConfig.js` でworld側表示ラベルを集約。

今は避けること:

- 全JSON schemaの一括変更。
- 大規模ファイル移動。
- `style.css` の一括分割。
- world側とops側の同時分離。

## 9. デザイン差し替え前提の整理

次世界観では以下を差し替える前提にする。

- logo。
- key visual。
- background。
- color palette。
- section decoration。
- card density。
- image aspect。
- typography tone。
- gallery category。
- world page order。

一方で、以下は共通骨格として残せる。

- `main.js` のpage renderer registryに相当する考え方。
- `data-page` でページを選ぶ構造。
- JSONを読み、カード/詳細/フィルタ/検索/モーダルへ展開する方式。
- related IDで人物/地点/シナリオ/用語/画像を接続する方式。

## 10. 運用基盤との接続点

world-site側とops側の境界:

- world / characters / spots / terms / regulation / gallery: 世界観紹介側。
- calendar / mypage / session-post / session-detail / membership / template / notification / TIMELINE / Discord sync: 運用基盤側。

接続点:

- scenariosとsession-post: 将来、シナリオ候補から依頼書テンプレートを作る導線が考えられる。
- spotsとcalendar/session-detail: 開催場所や関連地点の導線に使える。
- NPCとscenarios/session-detail: 関連NPCや依頼書本文の参照に使える。
- regulationとsession-post: 依頼書作成時のルール確認導線に使える。
- galleryと各ページ: key visual、地点画像、人物画像、シナリオ画像、地図の参照元になる。

今回の棚卸しでは、これらの接続を実装しない。接続点だけを記録する。

## 11. 今すぐやるべきこと

- world-site側の設定化候補をdocsで固める。
- gallery category labels/orderを設定化する小さな候補を作る。
- regulation TOC/level cap columnsを設定化する前の設計レビューを行う。
- `hooks.html` / `hooks.json` の互換扱いを、次世界観テンプレートではどうするか決める。
- world-site configとops configを混ぜない方針を保つ。

## 12. 今はやらない方がいいこと

- world-site全体のフォルダ再編。
- `data/` の大規模schema変更。
- `style.css` の一括分割。
- world/opsの同時独立化。
- hooks/scenarios互換の即削除。
- DB/RPC/RLS、SQL、Edge Function、Discord同期に関係する変更。
- public profileやmembership情報をworld-site側へ出す変更。

## 13. 段階的ロードマップ

### Phase W-0: 棚卸し

目的: 現状のページ種別、JSON構造、固定値、固有依存を整理する。

作業内容:

- この文書を作成。
- ページ別分類A〜Eを記録。
- world-site側とops側の境界を整理。

リスク: 低。docsのみ。

完了条件: 次世界観へ流用できる骨格と、触らない方がよい固有依存が見える。

危険工程: なし。

### Phase W-1: 表示カテゴリの小設定化

目的: gallery category、home nav、regulation TOCなど、表示だけの固定値を設定へ逃がす。

触る候補:

- `assets/js/renderGallery.js`
- `assets/js/renderHome.js`
- `assets/js/renderRegulation.js`
- 新規world-site config。

リスク: 中。表示順やカテゴリ名が変わる可能性。

完了条件: 表示結果を変えず、固定値を設定参照へ寄せられる。

危険工程: なし。

### Phase W-2: JSON schema文書化

目的: characters/spots/scenarios/terms/regulation/galleryのデータ項目を、次世界観向けに文書化する。

触る候補:

- docsのみ。
- 必要ならサンプルJSONを別docsで作る。

リスク: 低。

完了条件: 次世界観の初期データ作成に使える項目表がある。

危険工程: なし。

### Phase W-3: world-site renderer境界整理

目的: world-site側のrendererとops側rendererを同一repo内で分かりやすく整理する。

触る候補:

- `assets/js/renderWorld.js`
- `assets/js/renderCharacters.js`
- `assets/js/renderSpots.js`
- `assets/js/renderTerms.js`
- `assets/js/renderRegulation.js`
- `assets/js/renderGallery.js`

リスク: 中〜高。ファイル移動やimport変更が絡む場合は別ゲート。

完了条件: world-site側rendererの責務がdocsとコード上で見える。

危険工程: ファイル移動を伴う場合は明示ゲート。

### Phase W-4: 次世界観テンプレート試作

目的: デザイン固定ではなく、データ差し替えで最小の別世界観ページを立てられるか検証する。

触る候補:

- 別ブランチまたはdev領域。
- サンプルdata。

リスク: 高。現行サイトを壊さない隔離が必要。

完了条件: 現行ヴェルガルド表示を維持したまま、別世界観データの試作ができる。

危険工程: あり。実装前レビュー必須。

## 14. 次工程候補

1. Gallery category config:
   - `renderGallery.js` の `categoryLabels` / `categoryOrder` をworld-site config候補へ移す小設計。
2. Regulation display config:
   - `TOC_ITEMS` / `LEVEL_CAP_COLUMNS` をデータ化できるか、apply不要のフロント設計を行う。
3. World-site JSON schema docs:
   - characters/spots/scenarios/terms/regulation/galleryの項目表を次世界観向けに整備する。
4. Hooks/scenarios compatibility review:
   - `hooks.html` / `hooks.json` を次世界観テンプレートに含めるか、scenariosへ統一するか決める。
5. CSS responsibility audit:
   - world-site演出、ops UI、shared layoutをdocs上で分類する。

## Phase 2-A boundary follow-up

`10f9a66 Check reusable ops config rollout` 後のPhase 2-Aで、world-site側とops側のファイル境界を `docs/reusable-ops-platform-phase2-boundary-plan.md` に整理した。

world-site側としては、`renderWorld.js`、`renderCharacters.js`、`renderSpots.js`、`renderSpotDetail.js`、`renderScenarios.js`、`renderScenarioDetail.js`、`renderTerms.js`、`renderRegulation.js`、`renderGallery.js`、campaign/episode系renderer、world / characters / spots / terms / regulation / gallery / campaigns / episodes系dataを引き続きテンプレート候補として扱う。

一方で、`index.html` / `renderHome.js` はworld heroとhome activity panelが混在し、`tools.html` / `randomTables.json` と `updates.html` / `updates.json` はworld-siteかops補助か判断が必要な混在/保留領域として残した。

world-site rendererを動かす前に、`main.js` のrenderer registry / nav registryをどう分けるかを別ゲートで設計する。いきなりworld-site rendererをフォルダ移動すると、全ページのscript importとcache-bustに波及するため、Phase 2-Aでは実装変更を行っていない。

## Regulation Layout Policy Follow-Up

直近のレギュレーション改修で、`regulation.html` は世界観サイトテンプレート側の重要ページとして、以下の方針を採用した。

- レギュレーションページは世界観紹介側に属する。
- ただし、`session-post` や `mypage` の利用ルール確認導線と関係するため、運用基盤とも接続する重要ページとして扱う。
- PC版では、中央寄りの狭いカード群ではなく、本文を広く使う読み物ページとして扱う。
- 長文レギュレーションや個別裁定は、横2列カードより縦1列カードの方が読みやすい。
- 右側メニューまたは目次メニューで、現在位置が分かる構造を推奨する。
- スマホ版は従来通り縦積み中心でよい。
- カードデザイン、余白、見出しの雰囲気は維持しつつ、見た目の装飾より参照性と可読性を優先する。

次世界観テンプレートへ流用する場合、regulationはデザイン固定対象ではない。流用対象はページ骨格、データ構造、長文カード、表、用語説明カード、目次/サイドメニュー、現在位置active表示である。項目名、本文、表、裁定文、色、装飾、ロゴ、背景は世界観ごとに差し替える。

魔動天使のような長文個別裁定が入っても崩れない構造が必要である。特に、長文カード、表データ、強調見出し、右側メニューactive表示は次世界観でも再利用価値が高い。

運用基盤との境界は引き続き分ける:

- `calendar` / `mypage` / `session-post` / `session-detail` / `membership` は汎用運用基盤側。
- `regulation` は世界観紹介側。
- ただし、利用ルール確認、依頼書投稿前の参照、マイページからの案内など、導線上は運用基盤と接続する。
- 将来、運用基盤を独立ツール化しても、規約ページそのものは各世界観サイト側に残す可能性が高い。
- 一方で、規約データ構造と表示コンポーネントはworld-site templateとして再利用できる。

Current related status:

- Phase 1: `reusableOpsConfig` 設定入口作成と主要ラベル接続済み。
- Phase 2-B/C: config系ファイルを `assets/js/core/config/` へ移動し、公開確認済み。
- Phase 2-D/E: calendar rendererを `assets/js/core/calendar/` へ移動し、公開確認済み。
- Phase 2-F: `sessionDisplay.js` は丸ごと移動せず、依存調査済み。
- Phase 2-G: `sessionDisplay.js` から純粋helperのみ `assets/js/core/session/` へ抽出済み。
- regulation改修は独立ツール化本筋とは別だが、世界観サイトテンプレートの規約ページ方針として反映する。

Detailed regulation template policy:

- `docs/regulation-template-layout-policy.md`

This follow-up records the concrete Velgard regulation updates, the reusable
future-world structure, the Velgard-specific content that should remain data,
and the boundary between regulation pages and reusable ops surfaces.

## Phase 3-B1 Regulation Structure Detail

Phase 3-B1 adds a dedicated structure plan for the regulation page:

- `docs/world-template-regulation-structure-plan.md`

This keeps the regulation page on the world-site template track. The reusable
target is the structure, not Velgard's design or exact rules:

- page title and lead
- TOC / side menu with active section state
- term explanation cards
- level-cap, reward, honor, and growth tables
- long house-rule cards
- individual ruling cards
- note/callout blocks for GM and player guidance

The plan classifies reusable structure, data/JSON candidates, Velgard-specific
content, and values that should not be generalized. It also records that
regulation can connect to `calendar`, `session-post`, `session-detail`, and
`mypage` through navigation or user guidance, but auth, membership, RPC, DB,
and Discord sync behavior should remain outside the regulation template.

## Phase 3-B2 Regulation Data Schema Detail

Phase 3-B2 adds a docs-only data/json schema plan:

- `docs/world-template-regulation-data-schema-plan.md`

This plan inventories current regulation elements and separates them into:

- very good data/json candidates, such as tables, term cards, short notes, and
  individual ruling cards
- data/json candidates that need body-structure design, such as long house
  rules, growth rules, fumble/lower-bound growth rules, and complex special
  rulings
- renderer/layout concerns that should remain outside the schema for now, such
  as active TOC behavior, anchors, DOM structure, section ordering, and CSS
  classes
- values that should not become data defaults, such as DOM ids, CSS class names,
  JavaScript hook names, ops payload keys, auth/membership/RPC/DB/Discord
  behavior, and exact Velgard numeric values

The next safe world-template candidate is a docs-only renderer-constant audit
for `renderRegulation.js` before any data/json implementation.

## Phase 3-B3 Regulation Data Pilot Selection

Phase 3-B3 adds the first data/json pilot selection:

- `docs/world-template-regulation-data-pilot-plan.md`

The selected first pilot is the regulation term explanation card group. It is
safer than the level-cap/reward/honor tables because the card data is already a
simple repeated structure and does not require moving table column definitions.
It is safer than magic-angel and other long special rulings because it avoids
deep paragraph/list/table nesting.

Future implementation gates should keep the first pilot limited to term-card
data and renderer compatibility. They should not change TOC/active behavior,
anchors, CSS classes, DOM ids, reward values, honor values, long special
rulings, auth, membership, RPC, DB, Discord sync, or reusable ops core.

## Phase 3-B4 Term Explanation Behavior Spec

Phase 3-B4 adds the current behavior spec for the selected regulation pilot:

- `docs/world-template-regulation-term-explanations-spec.md`

It records that `termExplanations` currently has 12 cards, is rendered by
`renderTermExplanations(regulation)`, uses the existing term-card CSS classes,
and has one optional example callout. It also records the comparison checklist
and recommends a data-module pilot before a separate JSON-file migration.

## Phase 3-B5 Regulation Term Data Module Pilot

Phase 3-B5 applies the first world-site data split:

- `assets/js/world/regulation/termExplanationsData.js`
- `docs/world-template-regulation-term-explanations-data-module-result.md`

The pilot moves only `termExplanations` out of `data/regulation.json`. It keeps
the regulation renderer, CSS classes, section anchor, active side menu, and
reusable ops core unchanged. This is a world-site template step, not a reusable
ops platform split.

## Phase 3-B6 Regulation Term Data Public Rollout

Phase 3-B6 verifies the B5 split on public delivery:

- `docs/world-template-regulation-term-explanations-data-module-public-check.md`

The public site serves the new cache-bust chain, the public regulation renderer
imports the world-site term data module, the module is HTTP 200, and public
`data/regulation.json` no longer owns `termExplanations`. The browser DOM check
still found 12 term cards, one callout on card index 7, the existing term-card
classes, and the `#term-explanations` TOC link.

This completes the first small world-site data-module rollout check. The next
world-site template extraction steps should stay scoped to similarly small
data groups unless a separate JSON/fetch migration gate is opened.

## Phase 3-B7 Regulation Data Pilot Summary

Phase 3-B7 summarizes the first regulation data-module pilot and selects the
next candidate:

- `docs/world-template-regulation-data-pilot-summary.md`

The result keeps regulation on the world-site template track:

- term-card data can live in a world-site data module
- public rollout must check the full HTML/main/renderer/data/module chain
- ops-core behavior remains outside regulation data
- standalone JSON/fetch migration remains a later gate

Next selected candidate:

- level-cap table row data

The future implementation should move only the `levelCaps` row array. It should
not move `LEVEL_CAP_COLUMNS`, split reward/honor/Sword Shard columns, change
table CSS/DOM, or alter anchors and active TOC behavior.

## Phase 3-B8 Regulation Level-Cap Behavior Spec

Phase 3-B8 adds the current behavior spec for the selected level-cap row-data
candidate:

- `docs/world-template-regulation-level-caps-spec.md`

The spec confirms that regulation `levelCaps` is world-site template content,
not reusable ops core. It also records that the next implementation should move
only the row array, keep `LEVEL_CAP_COLUMNS` and `renderTable()` renderer-owned,
avoid JSON/fetch migration, and avoid coupling with calendar-side level-cap
date ranges.

## Phase 3-B9 Regulation Level-Cap Data Module

Phase 3-B9 applies the second small world-site data-module split:

- `assets/js/world/regulation/levelCapsData.js`
- `docs/world-template-regulation-level-caps-data-module-result.md`

The implementation moves only the `levelCaps` row array, removes the matching
key from `data/regulation.json`, and attaches the imported rows at the existing
`renderRegulation(root)` merge point. It keeps `LEVEL_CAP_COLUMNS`,
`renderTable()`, table CSS classes, anchors, active TOC behavior, calendar-side
level-cap ranges, and reusable ops core unchanged.

Public delivery should be checked in a separate rollout gate before choosing
another regulation data-module candidate.

## Phase 3-B10 Regulation Level-Cap Public Rollout

Phase 3-B10 verifies the public rollout of the level-cap data module:

- `docs/world-template-regulation-level-caps-data-module-public-check.md`

The public site serves the new cache-bust chain, the public regulation renderer
imports the world-site level-cap data module, the module is HTTP 200, and
public `data/regulation.json` no longer owns `levelCaps`. The static
display-equivalent check still found 14 level-cap rows from `Lv2` through
`Lv15`, 11 expected fields, non-empty cell values, and the existing table
classes and anchors in the checked public renderer/CSS path.

This completes public static delivery verification for the second world-site
data-module pilot. Browser visual QA and active TOC scroll-through QA remain
limited/not tested.

## Phase 3-B11 Regulation Data Pilot Summary

Phase 3-B11 summarizes the second pilot and chooses the next candidate:

- `docs/world-template-regulation-level-caps-data-pilot-summary.md`

The updated extraction path is:

- `termExplanations` proved repeated card data
- `levelCaps` proved table-shaped row data
- the next target should test one small nested block without changing shared
  renderers

Selected next candidate:

- short note card
- first concrete target: `reward` section `type: "callout"` block

The next gate should freeze the current callout behavior and output before any
implementation. It should not move the whole reward section, split
reward/honor/Sword Shard table values, change `renderBlock()`, change
`renderTable()`, or touch reusable ops core.

## Phase 3-B12 Regulation Reward Callout Behavior Spec

Phase 3-B12 adds the current behavior spec for the selected short-note
candidate:

- `docs/world-template-regulation-reward-callout-spec.md`

The spec confirms that the target is one nested `reward` section callout block
with title `超過報酬の例`, 4 plain-string paragraphs, and the existing
`renderBlock(block)` callout renderer path. It keeps the reward section,
reward paragraphs, CSS classes, anchors, active TOC behavior, and reusable ops
core out of the next implementation scope.

## Phase 3-B13 Regulation Reward Callout Data Module

Phase 3-B13 applies the selected nested-block data-module split:

- `assets/js/world/regulation/rewardCalloutBlocksData.js`
- `docs/world-template-regulation-reward-callout-data-module-result.md`

The implementation moves only the selected `reward` section callout block,
exports it as `rewardCalloutBlocks`, removes that block from
`data/regulation.json`, and inserts it back into the loaded reward section for
rendering.

This keeps the world-site template extraction path narrow:

- the whole `reward` section remains in `data/regulation.json`
- reward paragraphs remain in `data/regulation.json`
- `renderBlock()` and `renderDataSection()` are unchanged
- CSS classes, DOM ids, anchors, and active TOC behavior are unchanged
- no JSON/fetch migration or generic block registry is introduced
- reusable ops core remains unaffected

The next world-site gate should verify public rollout and cache-bust behavior
for the new module before selecting another regulation data target.

## Phase 3-B14 Regulation Reward Callout Public Rollout

Phase 3-B14 verifies the public rollout of the reward callout data module:

- `docs/world-template-regulation-reward-callout-data-module-public-check.md`

The public site now serves the expected cache-bust chain, imports
`rewardCalloutBlocksData.js`, serves the module with HTTP 200, and serves
`data/regulation.json` without the moved callout block. Browser DOM inspection
confirmed that the `reward` section still renders the `超過報酬の例` callout
exactly once with 4 paragraphs.

This completes public delivery verification for the third small world-site
data-module pilot. The next world-site template step should summarize the
three pilots before expanding to another regulation data shape.

## Phase 3-B15 Regulation Reward Callout Pilot Summary

Phase 3-B15 summarizes the third pilot and selects the next candidate:

- `docs/world-template-regulation-reward-callout-data-pilot-summary.md`

The updated extraction path is:

- `termExplanations` proved repeated card data
- `levelCaps` proved table row data
- `rewardCalloutBlocks` proved one nested section block with stale JSON
  duplicate-display protection
- the next target should test one nested subsection item without changing
  shared renderers

Selected next candidate:

- short note subsection item
- first concrete target:
  `general-skills` item `注釈2：『制限』について`

The next gate should freeze the current subsection item behavior and output
before any implementation. It should not move the whole `general-skills`
section, split table columns out of `levelCapsData.js`, change shared
renderers, or touch reusable ops core.

## Phase 3-B16 Regulation General Skill Note Module

Phase 3-B16 completed that next narrow extraction target:

- `docs/world-template-regulation-general-skill-note-data-module-result.md`

World-site template boundary:

- moved one Velgard-specific note item into
  `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`
- kept the parent `general-skills` section and rendering behavior in place
- kept reusable ops core untouched
- avoided standalone JSON/fetch migration
- verified public GitHub Pages delivery and DOM output

This adds one nested subsection-item success case to the world-site extraction
pattern. Future work should still avoid whole-section extraction or generic
registries without a separate schema decision.

## Phase 3-B17 Regulation Original General Skill Bonus Module

Phase 3-B17 completed one more narrow extraction target:

- `docs/world-template-regulation-original-general-skill-bonus-data-module-result.md`

World-site template boundary:

- moved one Velgard-specific original-general-skills note item into
  `assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js`
- kept the parent `original-general-skills` section and rendering behavior in
  place
- kept reusable ops core untouched
- avoided standalone JSON/fetch migration
- verified public GitHub Pages delivery and DOM output

This is another nested subsection-item success case, still without a generic
registry. Future work should decide whether more small pilots add value before
extracting broader schemas.

## Phase 3-B18 Regulation Data Module Midpoint

Phase 3-B18 summarizes the five completed regulation data-module pilots:

- `docs/world-template-regulation-data-module-midpoint-summary.md`

World-site template impact:

- five world-site data modules are now public-rollout checked
- the extraction path remains separated from reusable ops core
- the path still avoids JSON/fetch migration, whole-section moves, shared
  renderer changes, column-definition moves, CSS/anchor changes, and active TOC
  changes
- remaining QA is explicitly classified as `limited` or `not_tested` where
  appropriate

Recommended next route:

- Route D: strengthen template documentation and next-world adoption guidance
  before continuing extraction

## Phase 3-B19 Regulation Data Module Adoption Guide

Phase 3-B19 completes that Route D follow-up for regulation data modules:

- `docs/world-template-regulation-data-module-adoption-guide.md`

World-site template impact:

- the five completed regulation data modules now have a shared next-world
  adoption procedure
- file naming, export naming, placement, synchronous import policy, and
  one-target-per-module guidance are documented
- stale JSON / cache-mixing risk is documented as a public delivery concern
  that must be checked across `regulation.html`, `main.js`,
  `renderRegulation.js`, the data module, and `data/regulation.json`
- smoke/snapshot, public rollout, and rollback checklists are documented
- the boundary remains clear: regulation data modules are world-site template
  files, not reusable ops core files, and they do not change auth, membership,
  session-post, mypage, Discord sync, DB/RPC/RLS, Edge Functions, or
  `updates.json`

Recommended next route:

- Route C: continue world-template docs by documenting next-world setup order,
  regulation template structure, initial data/module setup, and a sample
  composition plan.

## Phase 3-C1 Next World Adoption Guide

Phase 3-C1 starts Route C by documenting the next-world adoption procedure:

- `docs/world-template-next-world-adoption-guide.md`

World-site template impact:

- classifies what can be reused, what must be replaced per world, what needs a
  careful gate, and what must not be copied
- records a setup order that starts with world name, site identity, minimum
  world/terms/regulation/characters/spots data, and only later considers ops
  connections
- keeps regulation template adoption on the world-site side and points detailed
  data-module work back to
  `docs/world-template-regulation-data-module-adoption-guide.md`
- separates reusable ops core from world-site data and copy
- records file placement guidance for `assets/js/core/`,
  `assets/js/world/regulation/`, `data/`, optional `assets/data/`, and `docs/`
- adds a next-world checklist and rollback/recovery policy
- recommends the next docs-only candidate:
  regulation sample data composition

## Phase 3-C2 Regulation Sample Data Plan

Phase 3-C2 completes that recommended docs-only candidate:

- `docs/world-template-regulation-sample-data-plan.md`

World-site template impact:

- provides a first regulation sample data composition for a future world
- records required, optional, and deferred regulation sample candidates
- documents pseudo structures for page metadata, sections, terms, level caps,
  rewards, honor/Sword Shard guidance, growth notes, callouts, special rulings,
  GM notes, and player notes
- clarifies that sample values must be placeholders or world-reviewed values,
  not copied Velgard production values
- keeps data modules optional, target-scoped, and under
  `assets/js/world/regulation/`
- keeps renderer, CSS, anchor, active TOC, JSON/fetch, and ops-core changes out
  of the sample-data plan

Recommended next docs-only candidate:

- characters / spots / terms template structures

## Phase 3-C3 Characters / Spots / Terms Structures

Phase 3-C3 completes that recommended docs-only candidate:

- `docs/world-template-content-structures-plan.md`

World-site template impact:

- documents scale-variable structures for characters, spots, and terms
- treats zero public records, small initial sets, and large categorized datasets
  as valid template states
- separates minimum, standard, and extended pseudo structures without requiring
  a fixed record count
- records empty-state policies for missing images, maps, tags, categories, and
  related links
- separates generic structures such as cards, lists, details, categories, tags,
  images, related links, sort order, and empty states from world-specific names,
  lore, categories, tags, and images
- keeps ownership on the world-template side and outside reusable ops core,
  auth, DB/RPC/RLS, Edge Functions, and Discord sync

Recommended next docs-only candidate:

- gallery / image asset boundary guide

## Phase 3-C4 Gallery / Image Asset Boundary Guide

Phase 3-C4 completes that recommended docs-only candidate:

- `docs/world-template-gallery-image-assets-guide.md`

World-site template impact:

- documents the current Velgard gallery and image inventory only as a reference
  point, not as content for a second world
- separates reusable gallery behavior, image cards, modal patterns, relation
  ids, placeholders, and fallback helpers from world-specific image files and
  captions
- classifies images into reusable structure, replace-per-world assets,
  careful-gate assets, and do-not-copy assets
- records data-side fields such as `image`, `thumbnail`, `alt`, `caption`,
  `credit`, `category`, `tags`, relation ids, placeholder flags, and visibility
- keeps renderer/CSS responsibilities such as grid, modal, image ratio,
  broken-image fallback, CSS classes, DOM ids, and JS hooks outside data
  ownership
- keeps gallery/image assets on the world-template side and outside reusable
  ops core, auth, DB/RPC/RLS, Edge Functions, Discord sync, and `updates.json`
- records image introduction, missing-image, public-check, and rollback
  checklists

Recommended next docs-only candidate:

- scenarios / hooks template structure
