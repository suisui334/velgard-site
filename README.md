# “灰壁と花霧の国”ヴェルガルド 公開サイト

## サイト概要

“灰壁と花霧の国”ヴェルガルドのPL向け公開サイトです。ソード・ワールド2.5向けのオープンワールド舞台紹介サイトとして運用します。

## 作業対象ディレクトリ

`C:\Users\rainx\Documents\Codex\2026-05-02\trpg-html-css-javascript-2-5\velgard-site`

## 実装方式

- 静的HTML
- CSS
- Vanilla JavaScript
- `data/*.json` 読み込み
- GitHub Pages等で公開可能な構成

## ローカル確認方法

親ディレクトリ `C:\Users\rainx\Documents\Codex\2026-05-02\trpg-html-css-javascript-2-5` で実行します。

```powershell
py -m http.server 4173 -d velgard-site
```

確認URL: http://127.0.0.1:4173/

## 主要ファイル構成
- `index.html`
- `world.html`
- `campaigns.html`
- `campaign-detail.html`
- `episode-detail.html`
- `regulation.html`
- `spots.html`
- `spot-detail.html`
- `characters.html`
- `scenarios.html`
- `hooks.html`
- `scenario-detail.html`
- `terms.html`
- `gallery.html`
- `tools.html`
- `calendar.html`
- `updates.html`
- `assets/css/`
- `assets/js/`
- `assets/images/`
- `data/`
- `docs/`
  - `docs/task-backlog.md`: 残タスク・保留事項・触らない方がよい互換要素の作業台
  - `docs/scenario-file-policy.md`: シナリオファイル受け入れ方針
  - `docs/release-runbook.md`: 正式公開URL反映後の公開確認手順書
  - `docs/supabase-prototype-plan.md`: 参加希望コメント、申請管理、GM編集、〆ボタン、Discord同期に向けたSupabaseプロトタイプ設計メモ
  - `docs/supabase-prototype-runbook.md`: Supabaseプロトタイプを実操作する直前の判断基準・作業順・RLSテスト手順
  - `docs/supabase-step0-2-preflight.md`: Supabase Freeプロトタイプ Step 0〜2 の実操作前チェックと停止ポイント
  - `docs/supabase-rls-test-matrix.md`: Supabase RLSテストケース表
  - `docs/supabase/sql/`: Supabase最小スキーマ、RLS/GRANT、RPCの実行候補SQL草案

## data/*.json の役割
- `site.json`: サイト共通設定、theme、meta関連
- `world.json`: 舞台紹介本文
- `spots.json`: 主要スポット
- `spotDetails.json`: 主要スポット詳細ページ本文、地図、関連情報
- `characters.json`: 公式NPC等
- `scenarios.json`: 配布予定シナリオ候補データ。旧 `hooks.json` 由来の7件を同IDで保持
- `hooks.json`: 旧フックデータ / 配布予定シナリオ候補カード表示元
- `terms.json`: 用語集
- `campaigns.json`: キャンペーン紹介
- `episodes.json`: 各話紹介
- `regulation.json`: レギュレーション正式規約データ
- `gallery.json`: 画像ギャラリー項目
- `randomTables.json`: TOOLSページのランダム表データ
- `calendarConfig.json`: ラクシア運用カレンダー設定
- `sessions.json`: CALENDARページの静的セッション予定モックデータ
- `updates.json`: 更新履歴

## 画像アセット配置状況
- `assets/images/common/`
  - `favicon.png`
  - `key-visual-main.png`
  - `velgard-logo.png`
  - `ogp-main.png`
  - `ogp-main-1200x630.png`
  - `background-mistwall.png`
  - `favicon-32.png`
  - `favicon-192.png`
  - `apple-touch-icon.png`
  - 既存SVGプレースホルダー類は削除せず維持
- `assets/images/characters/`: 公式NPC20名のPNG画像を配置済み
- `assets/images/locations/`: 地点画像14件を配置済み
- `assets/images/facilities/`: 施設画像9件を配置済み
- `assets/images/hooks/`: 旧フック画像 / 配布予定シナリオ候補画像7件を配置済み
- `assets/images/maps/`: 地図画像9件を配置済み
- 灰壁線路線図 `assets/images/maps/graywall-line-route-map.png` を作成・反映済み

## 画像パス反映状況
- `site.json` へ以下を反映済み
  - `keyvisual`: `assets/images/common/key-visual-main.png`
  - `logoImage`: `assets/images/common/velgard-logo.png`
  - `publicUrl`: `https://suisui334.github.io/velgard-site/`
  - `meta.ogImage`: `assets/images/common/ogp-main-1200x630.png`
  - `meta.favicon`: `assets/images/common/favicon-32.png`
  - `meta.faviconLarge`: `assets/images/common/favicon-192.png`
  - `meta.appleTouchIcon`: `assets/images/common/apple-touch-icon.png`
  - `theme.backgroundImage`: `assets/images/common/background-mistwall.png`
- 正式公開URLは `https://suisui334.github.io/velgard-site/`
- HTML head の `og:url` は正式公開URLへ差し替え済み
- HTML head の `og:image` は軽量版 `https://suisui334.github.io/velgard-site/assets/images/common/ogp-main-1200x630.png` を絶対URLで参照
- HTML head のfaviconは `assets/images/common/favicon-32.png` / `assets/images/common/favicon-192.png` を参照
- HTML head に `assets/images/common/apple-touch-icon.png` を追加済み
- 元画像 `assets/images/common/ogp-main.png` / `assets/images/common/favicon.png` は原本として維持
- `characters.json`: 公式NPC20名に `image` を追加済み
- `spots.json`: 主要スポット8件に代表画像 `image` を追加済み
- `scenarios.json`: 旧 `hooks.json` 由来の7件を同IDで保持し、SCENARIOS表示と個別準備中ページの参照元として利用
- `hooks.json`: 旧フック7件に `image` を追加済み。互換・比較用として維持
- `characters.html` / `spots.html` / `hooks.html`: 画像優先表示とfallback対応済み

## トップページ改修状況
- トップページを情報カード型案内ページから、作品公式サイト風の入口ページへ改修済み
- トップの「基本情報」「コンセプト」「長い説明カード」「Campaign Trailer」系表示は削除済み
- 不要キャッチ文「灰壁の向こうに、花霧はまだ揺れている。」は削除済み
- PC幅では、左側に正式ロゴ画像 / 縦型ナビ / LATEST、右側に大きなキービジュアルを配置
- スマホ幅では、ロゴ、キービジュアル、ナビ、更新の順に縦積み表示
- キービジュアルは `assets/images/common/key-visual-main.png` を使用
- キービジュアルは `object-fit: contain` で極端な切り抜きを避ける方向
- キービジュアルは390px幅での右見切れ・横スクロールを修正済み
- キービジュアル枠は画像実比率 `1926 / 817` に合わせ、PC幅・スマホ幅の上下余白を調整済み
- 大画面ではTOP専用幅 `--home-max: 1600px` で右側キービジュアルを大きめに表示し、左側ナビとのバランスを調整済み
- 共通最大幅は `--max: 1360px`、記事系保護幅は `--article-max: 1240px` として、大画面の左右余白と長文可読幅を両立
- CSSキャッシュクエリは全HTMLで `v=20260529-home-wide-layout` に統一済み
- キービジュアル画像はクリック / Enter / Space でトップページ専用の軽量モーダル拡大表示が可能
- 共通背景表示は維持
- ユーザー実ブラウザ確認で表示良好と確認済み

### 正式ロゴについて
- 正式ロゴ画像 `assets/images/common/velgard-logo.png` を反映済み
- ロゴ画像サイズは `2172x724`
- `data/site.json` に `logoImage` を追加済み
- トップページでは `renderHome.js` が `home-logo-image` として正式ロゴ画像を表示
- ロゴ画像の `alt` は `“灰壁と花霧の国”ヴェルガルド`
- 画像読み込み失敗時は従来の文字ロゴを表示する fallback あり
- 正式ロゴ画像はクリック / Enter / Space でトップページ専用の軽量モーダル拡大表示が可能
- ロゴ拡大モーダルとキービジュアル拡大モーダルは、既存 gallery / spot / character / scenario モーダルとは分離
- 共通ヘッダーは視認性とスマホ幅を優先し、従来のテキストブランドを維持
- `index.html` / `main.js` / `renderHome.js` / `data/site.json` に `v=20260527-logo` のキャッシュ対策を適用済み
- ロゴ拡大対応では `v=20260527-logo-modal`、キービジュアル拡大対応では `v=20260527-keyvisual-modal` のキャッシュ対策を適用済み
- トップキービジュアル横はみ出し修正では `v=20260528-home-keyvisual-overflow-fix`、上下余白修正では `v=20260528-home-keyvisual-fit-fix` のキャッシュ対策を適用済み
- 今後の微調整候補として、ロゴ表示サイズや余白の追加調整を検討可能

### トップページナビゲーション
- `WORLD`
- `CHARACTERS`
- `SPOTS`
- `SCENARIOS`
- `GALLERY`
- `TOOLS`
- `CALENDAR`
- `TERMS`
- `UPDATES`
- `REGULATION`
- `CAMPAIGN`

補足:

- `CAMPAIGN` は控えめ表示
- 主要ページリンクは存在確認済み

### 最新更新表示
- トップページでは `updates.json` から最新3件を控えめに表示
- 現在の最新3件は以下
  - セッション詳細ページと履歴保持を追加
  - カレンダー予定の詳細表示を追加
  - カレンダーにセッション予定表示を追加

## regulation正式規約ページ反映状況
- `regulation.html` は準備中ではなく、正式規約ページとして公開中
- `data/regulation.json` は `status: public`
- 開催スケジュール、レベルキャップ表、採用ルールブック、共通ルール、報酬、補填金、一般技能、リビルド、日数の数え方を `regulation.json` から表示
- トップページの `REGULATION` 補足表示は `開催規約`
- `regulation.html` は world ページ風の右側目次レイアウトを採用
- PC幅では本文横に目次、スマホ幅では縦積み表示になる想定
- 右側目次の下端見切れを調整済み
- 目次が長い場合は目次枠内でスクロール可能
- レベルキャップ表は横スクロールを維持
- `renderRegulation.js` は `article-layout` 構造に寄せ、本文 `article.regulation-main` と目次 `aside.toc.article-box.regulation-toc` を生成
- `world.html` / `renderWorld.js` は変更せず、既存の目次構造とCSSを参考にしている
- `index.html` / `regulation.html` / `main.js` / `renderHome.js` / `renderRegulation.js` に `v=20260526-regulation-toc` のキャッシュ対策を適用済み

### regulation確認メモ
- 実ブラウザ最終確認では、目次クリックで各章へ移動できることを確認する
- PC幅で右側目次の追従具合を確認する
- スマホ幅で目次が本文の邪魔にならず縦積みになることを確認する
- レベルキャップ表が横スクロールできることを確認する

## world本文詳細版反映状況
- `data/world.json` の第1章〜第8章すべてに詳細版本文を反映済み
- 対象章は以下の8章
  - 舞台概要
  - 冒険者ギルド「灰壁の灯火亭」
  - PCたちの立場
  - 歴史
  - 政治と法
  - 土地・産業・交通
  - 人々の暮らしと文化
  - 防衛体制と怪異対策
- 章数、各章 `title`、既存の `id` / `number` / `lead` / `image`、subsection構成は維持
- 第4章・第6章・第7章・第8章は章直下 `paragraphs` を持たない subsections-only 構造を維持
- 空文字paragraphは精密チェックで存在しないことを確認済み
- `world.html` では8章表示、subsection 21件表示、目次リンク29件、破綻リンク0件を確認済み
- `world.html` の右側目次は、スクロール中の現在位置に合わせて active 表示が同期する
- active中の目次項目には `aria-current="true"` を付与する
- 長い目次は目次ボックス内で内部スクロールでき、active項目が目次内で追従する
- 目次リンククリックで該当章へ移動できる導線は維持
- WORLD本文小見出しは、`body[data-page="world"] .article-box > .subsection` の上余白 `1.32em` と `h3` 下余白 `0.45em` で本文リズムを調整済み
- 本文全体の `line-height` は変更せず、`4-1.` / `4-2.` / `4-3.` などの小見出し周辺だけを軽く整えている
- `regulation.html` の右側目次には悪影響なし
- `world.html` / `renderWorld.js` / `main.js` / `index.html` に `v=20260527-world-toc` のキャッシュ対策を適用済み
- WORLD本文余白と大画面幅調整後、CSS読み込みは全HTMLで `v=20260529-home-wide-layout` に統一済み
- `undefined` / `null` / `[]` の露出なし
- ブラウザコンソール重大エラーなし

### 反映した内容の要約
- 第1章: ヴェルガルドの位置、山岳鉄道、防衛帯、灰壁線、花霧谷、人蛮共存、未解決の火種を含む舞台性を補強
- 第2章: 灰壁の灯火亭を、PCたちの所属先・冒険者の宿・依頼受付・帰る場所として整理
- 第3章: PCたちは正規軍や評議会直属ではなく、灰壁の灯火亭に所属する独立した冒険者であることを明確化
- 第4章: 灰壁と灰壁線の成立、灰花盟約、人蛮共存、現在まで残る火種を詳細化
- 第5章: 灰花評議会、灰花盟約、壁内法、共存制度の現実を役割ごとに整理
- 第6章: 灰壁線、薬草産業、鉱山資源、交易、物流管理を詳細化
- 第7章: 人蛮共存の日常、薬と毒の価値観、灰壁に名を刻む文化、温泉・旅籠・駅町の暮らしを詳細化
- 第8章: 灰壁と外縁守備隊、防衛鉄道公社、裂原封印院、冒険者に回される任務を詳細化

### 灰壁に名を刻む文化の補足
- 灰壁に名を刻む文化は、墓の代替ではない
- ヴェルガルドにも通常の墓は存在する
- 墓は個人・家族・信仰による弔いの場所
- 死者名簿は灰名神殿会が管理する記録
- 灰壁に刻まれた名は、国が公に記憶する公共的な追悼・防衛の記録
- 墓を持つ者でも灰壁に名が刻まれることがあり、墓を持てなかった者にとっては灰壁の名が祈りの目印になる

## 公式NPC紹介文整備状況
- `data/characters.json` の公式NPC20名について、カード表示用の中厚版紹介文 `summary` を反映済み
- 公式NPC20名すべてに、自然なサンプルセリフ `quote` を追加済み
- `summary` にはNPC本人の名前を含めない方針で整備済み
- `id` / `name` / `image` / `title` / `species` / `gender` / `areaId` / `areaName` / `organization` / `role` / `thumbnail` / `description` / `relatedSpots` / `relatedHooks` / `status` / `official` は維持
- `characters.html` では公式NPC20名表示、画像20件表示、`quote` の引用風表示、地域フィルターが動作確認済み
- hidden / official:false のサンプルNPCは非表示を維持
- NPC紹介文は、PCとの導線ではなく、その人物の性格・仕事・行動・ギャップ・周囲からの見られ方を重視した中厚版として整備済み

## 公式NPC年齢表示追加状況
- `data/characters.json` の公式NPC20名すべてに `ageLabel` を反映済み
- `characters.html` の公式NPCカード上に年齢表示を追加済み
- 年齢表示は `summary` / `quote` より上に控えめに表示
- `ageLabel` がある場合のみ年齢行を表示する仕様
- 公式NPC20名すべてで年齢行が出る構造になっている
- 画像表示、`summary`、`quote`、地域フィルター、hidden / official:false の非表示条件は維持

### 反映済みの主な年齢・種族調整
- トーヴェ・リントの古い `age`「未定。一桁年齢想定」は削除済み
- トーヴェ・リントは `ageLabel`「7歳」に統一済み
- ブリギッテ・フェルゼンの `species` を「ドワーフ」から「ダークドワーフ」へ修正済み
- ヤード・クロイツの `species` を「ナイトメア」から「ナイトメア（シャドウ生まれ）」へ修正済み
- ヴォルフラム・シュタール、オイゲン・ホフマンは現行正名を維持
- `gald-valks` は正IDとして維持

### キャッシュ対策状況
- `characters.html` は `main.js` をバージョン付きURLで読み込むよう調整済み
- `main.js` は `renderCharacters.js` をバージョン付きURLで import するよう調整済み
- `renderCharacters.js` は `data/characters.json` をバージョン付きURLで fetch するよう調整済み
- 具体的には、`characters.json` の読み込みに `data/characters.json?v=20260526-age` を使用
- Brave / Chrome の実ブラウザで年齢表示が確認済み
- キャッシュが残る場合は `Ctrl + F5` で強制更新する必要がある

### 表示確認状況
- Brave / Chrome の実ブラウザで `characters.html` の年齢表示を確認済み
- 公式NPC20名、年齢行20件、画像20件、quote20件が確認済み
- ダークドワーフ表示あり
- ナイトメア（シャドウ生まれ）表示あり
- 年齢：7歳 表示あり
- hidden / official:false のサンプルNPCは非表示を維持
- `undefined` / `null` / `[]` の露出なし

## キャラクター画像拡大表示対応状況
- `characters.html` の公式NPCカード画像クリック拡大対応を実装済み
- NPC詳細ページは作成していない
- 対象は公式NPC20名のカード画像のみ
- クリックすると大きめの立ち絵画像をモーダル表示
- characters専用の軽量モーダルとして実装
- `gallery.html` の既存モーダル、`spot-detail.html` の画像拡大モーダルとは分離
- `summary` / `quote` はモーダルには表示しない
- モーダルには大きめのキャラクター画像、NPC名、`role` または `title`、種族、年齢を表示

### 操作仕様
- NPC画像クリックでモーダルを開く
- Enter / Space でもモーダルを開ける
- 閉じるボタンで閉じる
- 背景クリックで閉じる
- Escキーで閉じる
- 閉じた後は元画像へフォーカス復帰
- 画像は3:4立ち絵向けに大きく表示
- PCでは画像＋情報の2カラム
- スマホ幅では1カラム縦積み

### 実装ファイルとクラス
- `assets/js/renderCharacters.js` に characters専用モーダルを追加
- `assets/js/main.js` の `renderCharacters.js` import にキャッシュ対策を追加
- `characters.html` の `main.js` 読み込みにキャッシュ対策を追加
- `assets/css/style.css` に characters専用モーダルCSSを追加
- 主な追加・利用クラス:
  - `character-image-clickable`
  - `character-image-modal`
  - `character-image-modal-backdrop`
  - `character-image-modal-content`
  - `character-image-modal-image`
  - `character-image-modal-text`
  - `character-image-modal-close`

### キャッシュ対策状況
- `characters.html` は `assets/js/main.js?v=20260526-character-modal` を読み込む
- `main.js` は `./renderCharacters.js?v=20260526-character-modal` を読み込む
- `characters.json` は既存の `data/characters.json?v=20260526-age` を維持
- 以前の年齢表示キャッシュ対策を壊さない形で実装済み

### 表示確認状況
- ユーザー実ブラウザ確認でキャラクター画像拡大モーダルの動作に問題なし
- 公式NPC20名表示を維持
- 公式NPC画像20件表示を維持
- `ageLabel` 20件を維持
- ブリギッテ・フェルゼンはダークドワーフを維持
- ヤード・クロイツはナイトメア（シャドウ生まれ）を維持
- トーヴェ・リントは7歳を維持
- `summary` / `quote` / 地域フィルターを維持
- hidden / official:false の非表示条件を維持
- `gallery.html` と `spot-detail.html` の既存モーダルを維持
- 禁止旧表記・旧IDの復活なし

## 表示調整状況
- `renderCharacters.js` で、`quote` がある場合のみ `blockquote.character-quote` として表示するよう調整済み
- `summary` 未設定時や `role` 未設定時のfallbackも調整済み
- `style.css` に `.character-quote` を追加し、控えめな引用風表示にした
- `characters.html` のキャラクターカード画像表示を改善済み
- キャラクター画像枠を3:4の縦型寄りに調整済み
- `object-fit: contain` / `object-position: center top` により、顔が見えない横長トリミングを避ける方向へ修正済み
- 公式NPC画像20件は3:4画像であり、調整後も全件表示できる想定
- `summary` / `quote` / 地域フィルター / 画像fallbackは維持

## 共通背景表示修正状況
- 共通背景画像 `assets/images/common/background-mistwall.png` の表示不具合を修正済み
- 背景画像ファイル自体は直接URLで表示できることを確認済み
- 背景が表示されなかった主因は、`theme.backgroundImage` の相対パスをそのままCSS変数に渡していたため、外部CSS内でのURL解決基準がずれていた可能性が高い
- `main.js` で `new URL(theme.backgroundImage, document.baseURI).href` により、ページ基準の絶対URLへ解決してから `--theme-bg-image` に渡すよう修正済み
- 実ブラウザで共通背景表示OKを確認済み
- 背景の濃さや見え方は、`site.json` のtheme項目で今後も調整可能

### site.json theme関連
- `backgroundImage`: 共通背景画像
- `backgroundOpacity`: 背景画像の透明度
- `backgroundSaturation`: 背景画像の彩度
- `overlayColor`: 背景上に重ねるオーバーレイ色
- `panelOpacity`: 本文パネル濃度
- `contentPanelOpacity`: 既存互換用の本文パネル濃度
- `cardOpacity`: カード濃度

## 主要スポット整備状況
- `data/spots.json` の現行8件について、一覧カード向けの簡潔版説明文を反映済み
- 現行スキーマでは、`spots.html` の表示用説明文として `summary` を使用しているため、8件すべての `summary` を更新済み
- `id` / `name` / `category` / `image` / `thumbnail` / `role` / `hooks` / `organizations` / `relatedCharacters` / `status` は維持
- `spots.html` では8件表示、画像8件表示、カテゴリフィルター、関連NPC表示が動作確認済み
- スポット説明は「完全版」ではなく、場所の役割・雰囲気・公開可能な範囲の性格を伝える簡潔版として整備済み

対象スポット:

- ヴェルガルド中央駅都
- 灰壁線・防衛鉄道公社
- 花霧谷リュスベル・花霧薬師組合
- 裂原グラシュ峡・裂原封印院
- 双角市場オルム
- フェルゼ坑町
- 黒橋関所
- 灰名神殿会

## スポット詳細ページ実装状況
- 主要8スポットの詳細ページを実装済み
- `data/spotDetails.json` を新規作成済み
- `spot-detail.html` を新規作成済み
- `assets/js/renderSpotDetail.js` を新規作成済み
- `spot-detail.html?id=<spot id>` 形式で詳細ページを表示可能
- `spots.html` の各スポットカードに「詳細を見る」導線を追加済み
- `data/spots.json` は一覧カード用として維持
- 詳細本文、地図、関連画像、関連NPC、関連シナリオ候補、関連用語は `data/spotDetails.json` 側で管理

### 対応済みスポット8件
- `central-station-city` / ヴェルガルド中央駅都
- `ryusbel-flower-mist-valley` / 花霧谷リュスベル・花霧薬師組合
- `orm-twinhorn-city` / 双角市場オルム
- `grasch-rift` / 裂原グラシュ峡・裂原封印院
- `defense-railway` / 灰壁線・防衛鉄道公社
- `felsen-mining-town` / フェルゼ坑町・煤煙鉱山フェルゼ坑
- `grayname-temple` / 灰名神殿会
- `blackbridge-checkpoint` / 黒橋関所

### spotDetails.json の構造
- `id`
- `definition`
- `lead`
- `sections`
- `mapGalleryIds`
- `relatedGalleryIds`
- `relatedFacilityGalleryIds`
- `relatedCharacterIds`
- `relatedScenarioIds`
- `relatedTermIds`
- `notes`

補足:

- `id` は `spots.json` の `id` と一致
- `spotDetails.json` は8件
- `sections` に詳細本文を格納
- `mapGalleryIds` で地図画像を紐づけ
- `relatedGalleryIds` / `relatedFacilityGalleryIds` で関連画像を紐づけ
- `relatedCharacterIds` / `relatedScenarioIds` / `relatedTermIds` で関連情報を紐づけ
- `relatedScenarioIds` は関連シナリオ参照の正本として使用
- `relatedHookIds` は `spotDetails.json` 上では削除済み
- raw ID は画面に表示しない処理

### 詳細本文の方針
- スポット詳細文は「PCや依頼との関わり」よりも「そこがどのような場所か」を重視
- 各スポットに固有の定義軸を設定済み
- 中央駅都: 運用都市
- 花霧谷リュスベル: 秤の谷
- 双角市場オルム: 信用と面子を扱う市場
- 裂原グラシュ峡: 分からないものに境界線を引き続ける場所
- 灰壁線・防衛鉄道公社: 途切れやすい土地をつなぎ続ける鉄の縫い目
- フェルゼ坑町: 守るための硬さに代償があることを知っている町
- 灰名神殿会: 失われる名をこの国の記憶へ留める場所
- 黒橋関所: 通してよいものと止めるべきものを選り分ける篩の門

### 関連情報表示
- 詳細ページでは地図、関連画像、関連施設画像を表示
- 関連NPCは名前で表示し、`characters.html#character-<characterId>` で該当キャラクター位置へ直接遷移可能
- 遷移先のキャラクターカードは一時ハイライト表示に対応
- 関連シナリオは名称で表示
- 関連用語は名称で表示
- gallery / characters / hooks / terms の存在IDのみ表示
- raw ID は画面に表示しない
- ID照合できない候補は無理に表示しない

### 画像クリック拡大モーダル実装状況
- `spot-detail.html` 内の画像クリック拡大モーダルを実装済み
- 対象はスポット詳細内のヒーロー画像、地図画像、関連画像、関連施設画像
- クリックで大きめの画像をモーダル表示
- Enter / Space でも拡大可能
- 閉じるボタンで閉じられる
- 背景クリックで閉じられる
- Escキーで閉じられる
- モーダルには `gallery.json` のタイトル・説明文を表示
- raw ID / `undefined` / `null` / `[]` は表示しない
- `gallery.html` の既存モーダルとは分離しており、既存galleryモーダルは維持

### 表示確認状況
- `spots.html` の詳細導線はユーザー実ブラウザ確認済み
- `spot-detail.html` の表示はユーザー実ブラウザ確認済み
- 主要スポット詳細ページの表示に問題なし
- 画像クリック拡大モーダルもユーザー実ブラウザ確認済み
- 地図画像、関連画像、関連施設画像のクリック拡大表示に問題なし
- `data/*.json` parse OK
- `spotDetails.json` 8件維持
- `spots.json` 8件とID一致
- gallery / characters / hooks / terms 参照切れなし
- 詳細ページで使う画像参照に欠損なし
- `undefined` / `null` / `[]` の露出なし
- 禁止旧表記・旧IDの復活なし

## terms.json 用語追加状況
- `data/terms.json` にヴェルガルド固有用語8件を追加済み
- `terms.json` は現在35件
- 追加した用語は以下の8件
  - `mirea-flower-pickers-village` / 花摘み村ミレア
  - `defense-railway-corporation` / 防衛鉄道公社
  - `first-graywall-fortress-station` / 灰壁第一要塞駅
  - `death-register` / 死者名簿
  - `missing-returnees-register` / 未帰還簿
  - `unidentified-deceased` / 未詳者
  - `unidentified-disappearance-record` / 未詳失踪記録
  - `name-waiting-tag` / 名待ち札

カテゴリ件数:

- 地域: 8
- 組織: 9
- 施設: 5
- 文化: 7
- 制度: 2
- 防衛: 1
- 交通: 1
- 怪異: 1
- 裏社会: 1

### 追加しなかった用語
- 奈落の魔域はSW2.5公式用語のため、ヴェルガルド独自termとして追加していない
- 賢神キルヒアはSW2.5公式用語のため、ヴェルガルド独自termとして追加していない
- 本文中に言及があることは問題ない
- 関連用語欄に用語カードとして表示されない状態で問題ない

## spotDetails.json 関連用語ID反映状況
- `data/spotDetails.json` の `relatedTermIds` を再照合し、追加用語を関連スポットへ反映済み

反映内容:

- `ryusbel-flower-mist-valley`
  - `mirea-flower-pickers-village`
- `defense-railway`
  - `defense-railway-corporation`
  - `first-graywall-fortress-station`
- `grayname-temple`
  - `death-register`
  - `missing-returnees-register`
  - `unidentified-deceased`
  - `unidentified-disappearance-record`
  - `name-waiting-tag`

補足:

- `relatedTermIds` 重複なし
- `relatedTermIds` 参照切れなし
- `relatedHooks` は `spotDetails.json` に追加していない
- 奈落の魔域 / 賢神キルヒアは `relatedTermIds` に追加していない

## 関連用語アンカーリンク対応状況
- `spot-detail.html` の関連用語リンクを `terms.html#term-<term id>` 形式へ変更済み
- 新規追加用語だけでなく、全スポット・全関連用語が対象
- `terms.html` 側では `terms.json` 全35件の用語カードに `id="term-<id>"` と `tabindex="-1"` を付与済み
- spot-detail 側の関連用語表示テキストは `terms.json` の日本語 `term` を使用
- raw ID は画面に表示しない
- 未解決IDは表示しない
- `undefined` / `null` / `[]` は表示しない

### terms.html 側の挙動
- `terms.html` 読み込み時に `location.hash` を確認
- 対象カードがある場合、`scrollIntoView` で自動スクロール
- 対象カードへフォーカス
- 対象カードを一時ハイライト
- `hashchange` にも対応
- hash遷移時は検索欄を空にし、カテゴリを「すべて」に戻してから対象カードを探す
- フィルターで対象カードが非表示になる状態を回避済み

### 関連用語導線の確認状況
- ユーザー実ブラウザ確認済み
- `spot-detail.html` の関連用語リンクから `terms.html#term-<term id>` 形式で該当用語カードへ移動できる
- 自動スクロールとハイライトが機能する
- 新規追加用語だけでなく、中央駅都など既存用語も含めて全スポット・全関連用語対象で動作確認済み
- raw ID / `undefined` / `null` / `[]` の露出なし

確認例:

- 防衛鉄道公社
- 灰壁第一要塞駅
- 死者名簿
- 未帰還簿
- 未詳者
- 未詳失踪記録
- 名待ち札
- 灰壁の灯火亭
- 灰花評議会
- 壁内法

### 実装ファイルとキャッシュ対策状況
- 関連用語アンカーリンク対応で主に修正された実装ファイル
  - `assets/js/renderTerms.js`
  - `assets/js/renderSpotDetail.js`
  - `assets/js/main.js`
  - `terms.html`
  - `spot-detail.html`
  - `assets/css/style.css`
- キャッシュ対策
  - `terms.html` の `main.js` 読み込みに `20260526-term-anchor` を適用
  - `spot-detail.html` の `main.js` 読み込みに `20260526-term-anchor` を適用
  - `main.js` の `renderTerms.js` import に `20260526-term-anchor` を適用
  - `main.js` の `renderSpotDetail.js` import に `20260526-term-anchor` を適用
  - `renderTerms.js` / `renderSpotDetail.js` の `terms.json` fetch に `20260526-term-anchor` を適用
- CSS追加
  - `.term-card`
  - `.term-card:focus-visible`
  - `.term-card-highlight`

## HOOKS → SCENARIOS 段階移行状況
- 従来の HOOKS / フックは、今後 SCENARIOS / シナリオとして扱う
- フック詳細ページ設計・本文作成は中止
- 今後は作成済み配布シナリオ置き場として扱う
- 現時点では配布シナリオ本文は未作成のため準備中表示
- 正式なシナリオ一覧入口として `scenarios.html` を新設済み
- `scenarios.html` は body `data-page="scenarios"` の正式SCENARIOSページ
- `hooks.html` は既存リンク互換入口として当面残している
- `hooks.html` の body `data-page="hooks"` は互換上維持
- 表示上は SCENARIOS / シナリオへ変更済み
- `data/scenarios.json` を新設済み
- `data/scenarios.json` は旧 `hooks.json` 由来の7件を同IDで保持
- `assets/js/renderScenarios.js` を新設済み
- `assets/js/renderHooks.js` は未使用整理として削除済み
- `main.js` から `renderHooks.js` は参照されていない
- `scenarios.html` は `renderScenarios.js` で `data/scenarios.json` を描画
- `hooks.html` はURL互換のため維持し、描画は `renderScenarios.js` 経由へ切替済み
- `scenario-detail.html` は `data/scenarios.json` 参照へ切替済み
- `spotDetails.json` は `relatedScenarioIds` を正本として使用
- `data/spotDetails.json` から `relatedHookIds` を削除済み
- `renderSpotDetail.js` の関連シナリオ表示は `relatedScenarioIds` / `data/scenarios.json` 正本へ一本化済み
- `renderSpotDetail.js` の `relatedHookIds` fallback / `hooks.json` fallback は撤去済み
- `data/hooks.json` は削除せず、互換・比較用として保持
- ユーザー実ブラウザ確認済み

### シナリオ準備中カード表示状況
- `scenarios.html` に SCENARIOS / シナリオ と表示
- `hooks.html` でも互換入口として同じシナリオカード7件を表示
- 旧フック7件を「配布予定シナリオ」準備中カードとして表示
- 各カードは画像、タイトル、`category` / `genre`、`summary`、準備中バッジ、`scenario-detail.html?id=<id>` への導線を持つ
- 画面上では「フック」ではなく「シナリオ」文脈に寄せている
- 表示データは `data/scenarios.json` を参照
- galleryのシナリオ系カテゴリは `category: scenarios` へ移行済み

### 個別シナリオ準備中ページ
- `scenario-detail.html` を新規作成済み
- `assets/js/renderScenarioDetail.js` を新規作成済み
- `scenario-detail.html?id=<hook id>` 形式で個別準備中ページを表示
- `data/scenarios.json` 参照で旧フック7件由来の個別準備中ページに対応
- 表示内容は、タイトル、代表画像、`category` / `genre`、`summary`、配布シナリオ準備中案内、関連スポット、関連NPC、シナリオ一覧へ戻る導線
- idなし / 不正id では「シナリオが見つかりません」表示
- 配布シナリオ本文、PDF、HTML本文は未作成

### シナリオ本文・PDF受け入れ基盤
- シナリオ本文・PDF受け入れ基盤は実装済み
- `data/scenarios.json` に `releaseStatus` を追加済み
- 既存の `status` は可視性、`releaseStatus` は配布状態として扱う
- 現在の7件は `releaseStatus: preparing`
- `textUrl` / `pdfUrl` は現時点では未設定
- `scenario-detail.html` に配布情報セクションを追加済み
- `textUrl` がある場合のみ TXTリンクとページ内本文表示欄を表示する
- TXT本文表示は `fetch(textUrl)` + `textContent` で行い、`innerHTML` は使わない
- `pdfUrl` がある場合のみPDFリンクを表示する
- PDFリンクは `target="_blank"` と `rel="noopener"` を付与する
- `scenarios.html` / `hooks.html` の一覧カードは、準備中 / 配布中 / 旧版バッジ表示に対応済み
- 実シナリオ本文 `.txt` とPDFはまだ未配置
- キャッシュ対策は `v=20260529-scenario-release-base`

### 対応済み配布予定シナリオ候補7件
- `railway-incidents` / 列車と鉄道の事件
- `flower-mist-valley-cases` / 花霧谷の探索と薬草事件
- `coexistence-negotiation` / 人蛮共存と交渉
- `mining-industrial-cases` / 鉱山と産業事件
- `rift-anomalies` / 裂原と怪異
- `smuggling-underworld` / 密輸と裏社会
- `grayname-records` / 死者名簿と灰壁の記録

### シナリオ画像拡大表示対応状況
- SCENARIOS / シナリオページの配布予定シナリオカード画像クリック拡大対応を実装済み
- `scenario-detail.html?id=<hook id>` の個別シナリオ準備中ページ代表画像もクリック拡大対応済み
- `scenario-image-*` 系クラスの専用軽量モーダルとして実装
- `gallery.html` / `spot-detail.html` / `characters.html` の既存モーダルとは分離
- シナリオ本文、`description`、`examples`、秘匿情報はモーダルに表示しない
- あくまで画像を大きく見せるためのUI改善として扱う

### シナリオ画像拡大対象
- `scenarios.html` に表示される配布予定シナリオカード画像7件
- 互換入口の `hooks.html` に表示される配布予定シナリオカード画像7件
- `scenario-detail.html?id=<hook id>` に表示される代表画像

対象シナリオ候補:

- `railway-incidents` / 列車と鉄道の事件
- `flower-mist-valley-cases` / 花霧谷の探索と薬草事件
- `coexistence-negotiation` / 人蛮共存と交渉
- `mining-industrial-cases` / 鉱山と産業事件
- `rift-anomalies` / 裂原と怪異
- `smuggling-underworld` / 密輸と裏社会
- `grayname-records` / 死者名簿と灰壁の記録

### シナリオ画像モーダル表示内容
- モーダルには、大きめの画像、シナリオ候補タイトル、`category` / `genre`、準備中バッジ、`summary` を控えめに表示
- モーダルには、`description`、`examples`、配布シナリオ本文、GM向け秘匿情報、犯人 / 黒幕 / 結末、raw ID、`undefined` / `null` / `[]` は表示しない

### シナリオ画像モーダル操作仕様
- 画像クリックでモーダルを開く
- Enter / Space でも開ける
- 閉じるボタンで閉じる
- 背景クリックで閉じる
- Escキーで閉じる
- 閉じた後は元画像へフォーカス復帰

### シナリオ画像モーダル 実装ファイルとCSS
- 実装時に修正済み
  - `assets/js/renderHooks.js`（当時修正済み、現在は未使用整理により削除済み）
  - `assets/js/renderScenarios.js`
  - `assets/js/renderScenarioDetail.js`
  - `assets/js/main.js`
  - `scenarios.html`
  - `hooks.html`
  - `scenario-detail.html`
  - `assets/css/style.css`
- 追加CSS
  - `scenario-image-clickable`
  - `scenario-image-modal`
  - `scenario-image-modal-backdrop`
  - `scenario-image-modal-content`
  - `scenario-image-modal-image`
  - `scenario-image-modal-text`
  - `scenario-image-modal-close`
- スマホ幅用の縦積み調整も追加済み

### ナビゲーション変更状況
- 共通ナビは HOOK から SCENARIOS へ変更済み
- トップページナビは HOOKS / シナリオフック から SCENARIOS / シナリオ へ変更済み
- 正式リンク先は `scenarios.html` へ切替済み
- `scenario-detail.html` 側でも SCENARIOS ナビ active を維持
- CAMPAIGN はキャンペーン紹介
- SCENARIOS は配布予定・作成済みシナリオ置き場として役割分離

### spot-detail 関連シナリオ導線
- spot-detail の「関連フック」は「関連シナリオ」へ変更済み
- `spotDetails.json` は `relatedScenarioIds` を正本として使用
- 8スポットすべてに `relatedScenarioIds` が存在
- `relatedScenarioIds` 参照切れなし
- `data/spotDetails.json` から `relatedHookIds` を削除済み
- `renderSpotDetail.js` の `relatedHookIds` fallback は撤去済み
- `renderSpotDetail.js` の `data/hooks.json` fetch は撤去済み
- `renderSpotDetail.js` の `hooks.json` fallback は撤去済み
- 関連シナリオ名称解決は `data/scenarios.json` を正本として参照
- 関連シナリオ欄のリンク先は `scenario-detail.html?id=<id>` へ変更済み
- 関連シナリオカードの `defaultHref` は `scenarios.html`
- 準備中注記を維持
- raw ID / `undefined` / `null` / `[]` は表示しない
- `spot-detail.html` の meta description / og:description 内の「関連フック」は「関連シナリオ」へ修正済み

### シナリオページ キャッシュ対策状況
- scenarios正式化STEP1では `v=20260527-scenarios-step1` を適用済み
- `hooks.html` / `scenario-detail.html` / `spot-detail.html` の `main.js` 読み込みに `v=20260527-scenarios-step1` を適用済み
- `main.js` の `renderScenarios.js` / `renderScenarioDetail.js` / `renderSpotDetail.js` import に `v=20260527-scenarios-step1` を適用済み
- `renderScenarios.js` / `renderScenarioDetail.js` / `renderSpotDetail.js` の `scenarios.json` fetch に `v=20260527-scenarios-step1` を適用済み
- scenarios正式化STEP2では `v=20260527-scenarios-page` を適用済み
- `scenarios.html` 新設およびナビ切替に合わせ、全HTMLの `main.js` 読み込みを `v=20260527-scenarios-page` に統一済み
- `main.js` の `renderHome.js` / `renderScenarios.js` / `renderScenarioDetail.js` import に `v=20260527-scenarios-page` を適用済み
- `renderScenarios.js` / `renderScenarioDetail.js` の `scenarios.json` fetch に `v=20260527-scenarios-page` を適用済み
- relatedHookIds整理では `v=20260528-related-scenarioids` を適用済み
- `spot-detail.html` の `main.js` 読み込み、`main.js` の `renderSpotDetail.js` import、`renderSpotDetail.js` の `spotDetails.json` fetch に適用済み
- spot-detail関連シナリオ正本化では `v=20260528-spotdetail-scenarios-only` を適用済み
- `spot-detail.html` の `main.js` 読み込み、`main.js` の `renderSpotDetail.js` import、`renderSpotDetail.js` の `spotDetails.json` / `scenarios.json` fetch に適用済み
- 旧 `20260526-scenario-image-modal` はシナリオ画像拡大対応時のキャッシュ対策として記録上残る

### シナリオページ確認状況
- ユーザー実ブラウザ確認済み
- `scenarios.html?scenariosPageCheck=1` で正式SCENARIOS / シナリオ一覧入口を確認
- `scenarios.html` で配布予定シナリオ準備中カード7件表示を確認
- トップページナビと共通ナビの SCENARIOS が `scenarios.html` を指すことを確認
- `scenario-detail.html` のシナリオ一覧へ戻る導線が `scenarios.html` を指すことを確認
- `hooks.html?scenarioCardsCheck=1` で SCENARIOS / シナリオ表示を確認
- `hooks.html?scenariosPageCheck=1` でも互換入口としてシナリオカード7件表示を確認
- `hooks.html?scenarioImageCheck=1` の配布予定シナリオカード画像クリックで専用モーダルが開くことを確認済み
- 配布予定シナリオ準備中カード7件表示を確認
- カード画像、タイトル、準備中バッジ、`scenario-detail.html?id=<id>` 導線を確認
- `scenario-detail.html?id=railway-incidents` / `grayname-records` など個別準備中ページを確認
- `scenario-detail.html?id=railway-incidents` の代表画像クリック拡大確認済み
- `scenario-detail.html?id=grayname-records` の代表画像クリック拡大確認済み
- 個別ページのタイトル、画像、`summary`、準備中案内、関連スポット / 関連NPC名表示に問題なし
- spot-detail の関連シナリオ導線も問題なし
- `data/*.json` parse OK
- `scenarios.json` 7件
- `releaseStatus: preparing` 7件
- `textUrl` / `pdfUrl` 0件
- `hooks.json` 7件維持
- `scenarios.json` と `hooks.json` のID一致
- `relatedScenarioIds` 参照切れなし
- `spotDetails.json` は8件
- `relatedScenarioIds` 8スポット分
- `relatedHookIds` は `spotDetails.json` 上では0件
- `renderSpotDetail.js` の `relatedHookIds` fallback / `hooks.json` fallback は撤去済み
- gallery `scenarios` カテゴリ7件、`hooks` カテゴリ0件
- `data/characters.json` の `relatedHooks` は20件維持
- `assets/js/renderHooks.js` は削除済み
- `assets/js/*.js` 構文OK
- version付き `main.js` / `renderScenarios.js` / `renderScenarioDetail.js` / `renderSpotDetail.js` HTTP 200
- `gallery.html` / `spot-detail.html` / `characters.html` の既存モーダル維持
- 現在の `updates.json` は41件
- 禁止旧表記・旧IDの復活なし

### 後工程候補
- シナリオ画像クリック拡大対応は完了済み
- `scenarios.html` 新設は完了済み
- `assets/js/renderHooks.js` の削除は完了済み
- `data/hooks.json` の削除または完全廃止は後工程候補
- `data/characters.json` の `relatedHooks` をどう扱うかは別途整理候補
- galleryカテゴリキー `hooks` → `scenarios` 移行は完了済み
- `gallery-hook-*` IDを維持するか改名するかは後工程で判断
- `assets/images/hooks/` を維持するか `scenarios` へ移すかは後工程で判断
- 配布シナリオ本文作成は未実施

### scenarios正式化STEP1 互換維持
- `hooks.html` は既存リンク互換のため維持
- `data/hooks.json` は互換・比較用として維持
- `assets/js/renderHooks.js` は削除済み
- `data/spotDetails.json` の `relatedHookIds` は削除済み
- spot-detail の関連シナリオ表示では `relatedHookIds` / `hooks.json` fallback は使用しない
- `data/characters.json` の `relatedHooks` は `spotDetails.json` の `relatedHookIds` とは別スキーマとして維持
- `gallery.json` のシナリオ系7件は `category: scenarios` へ移行済み（`category: hooks` は0件）
- `gallery-hook-*` IDは互換維持
- `assets/images/hooks/` は互換維持

### scenarios正式化STEP2 正式入口
- `scenarios.html` は正式な SCENARIOS / シナリオ一覧ページとして新設済み
- `scenarios.html` は body `data-page="scenarios"`
- `scenarios.html` は `renderScenarios.js` で `data/scenarios.json` を描画
- シナリオカード7件を表示し、各カードは `scenario-detail.html?id=<id>` へ遷移
- シナリオ画像拡大モーダルは `scenarios.html` 側でも維持
- トップページナビの SCENARIOS / シナリオ は `scenarios.html` を指す
- 共通ナビの SCENARIOS は `scenarios.html` を指す
- `scenario-detail.html` 側でも SCENARIOS ナビ active を維持
- `hooks.html` は削除せず、既存リンク互換入口として維持
- `hooks.html` を開いても SCENARIOS / シナリオカード7件が表示される
- `hooks.html` の data-page `hooks` は互換上維持
- 正式導線は `scenarios.html` へ移行済みで、`hooks.html` への新規正式導線は増やさない方針

## 旧シナリオフックデータ整備状況
- `data/hooks.json` の既存7件について、PL向け説明文を整備済み
- 旧シナリオフック運用時に、7件すべての `description` を更新済み
- `id` / `title` / `category` / `genre` / `image` / `summary` / `examples` / `relatedSpots` / `relatedCharacters` / `status` は維持
- 現在の `hooks.html` では、旧フック7件を配布予定シナリオ準備中カードとして表示
- 旧シナリオフック説明文は、具体的事件や真相を断定せず、各題材の雰囲気・遊び味・扱えるテーマを伝える方向で整備済み

対象フック:

- 列車と鉄道の事件
- 花霧谷の探索と薬草事件
- 人蛮共存と交渉
- 鉱山と産業事件
- 裂原と怪異
- 密輸と裏社会
- 死者名簿と灰壁の記録

## gallery.html 本格整備 v1
- `gallery.html` は準備中ではなく、画像資料庫として稼働中
- `gallery.html` の `description` / `og:description` は画像資料庫としての実態に合わせて更新済み
- `data/gallery.json` は配列形式
- 各項目は `id` / `category` / `title` / `image` / `description` の5項目で管理
- 掲載件数は合計41件
  - `key-visual`: 2件
  - `locations`: 14件
  - `facilities`: 9件
  - `scenarios`: 7件
  - `hooks`: 0件
  - `maps`: 9件
- 灰壁線路線図を `maps` カテゴリに追加済み
- 灰壁線路線図の画像パスは `assets/images/maps/graywall-line-route-map.png`
- `defense-railway` の `spot-detail.html` から灰壁線路線図を関連地図として確認可能
- 画面表示上は `scenarios` カテゴリを「シナリオ」として表示
- 旧内部カテゴリキー `hooks` は `gallery.json` 上では0件。`gallery-hook-*` IDと `assets/images/hooks/` は互換維持
- NPC立ち絵20件は `characters.html` と役割が重なるため、gallery v1には原則掲載しない
- カテゴリフィルター、画像カード、画像クリック拡大モーダル、前へ / 次へ、左右キー、現在位置表示、fallback対応済み
- gallery表記整合、gallery meta / OGP description の準備中文面解消、galleryカテゴリ表示の「シナリオ」寄せは完了済み
- galleryカテゴリ正式化として、シナリオ系7件は `category: scenarios` へ移行済み
- `gallery-hook-*` ID、`assets/images/hooks/`、`data/scenarios.json` / `data/hooks.json` 内の画像パスは互換維持
- `gallery.html` の「シナリオ」フィルターで7件、「すべて」で41件表示をユーザー実ブラウザ確認済み
- gallery検索機能を追加済み
  - 検索対象は `title` / `description` / カテゴリ表示名 / `id`
  - カテゴリフィルターと検索を併用可能
  - 検索結果件数を表示し、0件時は「検索条件に合う画像がありません。」を表示
  - 検索結果内でgalleryモーダルの前へ / 次へ移動が可能
  - 390px幅で検索欄とカテゴリ欄の余白を調整済み
- gallery画像モーダルはスマホ・タブレット向けに左右スワイプで前後移動できる
  - 左スワイプで次の画像へ、右スワイプで前の画像へ移動
  - 既存の `moveModal()` を再利用し、前へ / 次へボタン、左右キー操作と同じ `modalItems` を使う
  - 検索・カテゴリ絞り込み後の現在表示リスト内でスワイプ移動する
  - 1本指、横移動50px以上、横移動優勢のときだけ反応し、縦スワイプや短いタップ風操作では移動しない
  - 390px幅で横スクロールなし、ユーザー実ブラウザ確認済み

## ギャラリーモーダル移動導線追加状況
- `gallery.html` の画像モーダルに前へ / 次へ操作を追加済み
- 画像モーダル内に現在位置表示を追加済み
  - 例: `3 / 8`
  - 例: `12 / 40`
- ArrowLeft で前の画像へ移動
- ArrowRight で次の画像へ移動
- 最後の画像から次へで最初へ戻るループ移動に対応
- 最初の画像から前へで最後へ戻るループ移動に対応
- Esc / 閉じるボタン / 背景クリックで閉じる既存挙動は維持
- ユーザー実ブラウザ確認済みで問題なし

### 実装方式
- galleryモーダル内に現在表示リストのスナップショットを保持
- `modalIndex` を前後に動かして、画像・タイトル・説明・カテゴリ・カウンターを差し替える方式
- モーダルを開いた時点の表示中リストを基準に前後移動
- カテゴリフィルター中は、そのカテゴリ内だけで前後移動
- 検索中は、カテゴリ条件と検索条件を満たす現在表示リスト内で前後移動

### 修正済みファイルとCSS
- 実装時に修正済み
  - `assets/js/renderGallery.js`
  - `assets/js/main.js`
  - `gallery.html`
  - `assets/css/style.css`
- 追加CSS
  - `.gallery-modal-nav`
  - `.gallery-modal-control`
  - `.gallery-modal-counter`
  - `.gallery-modal-prev`
  - `.gallery-modal-next`
- PC幅では横並び
- スマホ幅ではカウンター上段、前後ボタン下段
- 画像の邪魔をしすぎず、押しやすい配置

### キャッシュ対策状況
- gallery表記整合では `v=20260526-gallery-label` を適用済み
- galleryカテゴリ正式化では `v=20260527-gallery-scenarios-category` を適用済み
  - `gallery.html` の `main.js` 読み込み
  - `main.js` の `renderGallery.js` import
  - `renderGallery.js` の `data/gallery.json` fetch
- gallery検索機能では `v=20260528-gallery-search` を適用済み
- gallery検索UIのスマホ幅余白修正では `v=20260528-gallery-search-layout` を適用済み
- galleryスワイプ対応では `v=20260529-gallery-swipe` を適用済み

### 確認状況
- `data/*.json` parse OK
- `gallery.json` 41件維持
- galleryカテゴリ件数維持
  - `key-visual`: 2
  - `locations`: 14
  - `facilities`: 9
  - `scenarios`: 7
  - `hooks`: 0
  - `maps`: 9
- gallery画像参照欠損なし
- `assets/js/*.js` 構文OK
- `gallery.html` HTTP 200
- `gallery.html?galleryLabelCheck=1` HTTP 200
- version付き `main.js` / `renderGallery.js` HTTP 200
- `spot-detail.html?id=central-station-city` HTTP 200
- `characters.html` HTTP 200
- `gallery-modal` 系クラスのみ追加・利用し、`spot-image-modal` 系 / `character-image-modal` 系と衝突なし
- ユーザー実ブラウザで前へ / 次へ、左右キー、ループ移動、カテゴリフィルター中の前後移動を確認済み
- ユーザー実ブラウザで左右スワイプ、検索・カテゴリ絞り込み後リスト内でのスワイプ移動、390px幅横スクロールなしを確認済み

## 用語集整備状況
- `data/terms.json` の既存27件について、PL向け公開情報として読みやすい簡潔版説明文を反映済み
- 追加のヴェルガルド固有用語8件を含め、現在は35件で運用
- 現行スキーマでは `description` ではなく `summary` を表示・検索に使用
- `id` / `term` / `category` / `relatedSpots` / `relatedCharacters` / `status` を基本フィールドとして維持
- `terms.html` では35件表示、検索、カテゴリフィルター、関連スポット / 関連NPC表示が動作確認済み
- 将来 `description` フィールドへ移行する場合は、`renderTerms.js` 側の対応も必要

## TOOLS / ランダム表ツール
- `tools.html` を補助ツールページとして追加済み
- `data/randomTables.json` を使用し、`assets/js/renderTools.js` でランダム表を描画
- TOP左側縦ナビに `TOOLS` 導線を追加済み
- TOP左側縦ナビでは `GALLERY` と `TERMS` の間に `TOOLS` を表示
- `TOOLS` の補助文は「補助ツール」
- 表選択、振るボタン、結果表示、分岐表示、出目表示、直近履歴に対応
- 表選択UIには13件を表示
  - `TDA（自動分岐）`
  - `TDB` 〜 `TDL`
  - `アビス浸蝕表`
- `TDA（自動分岐）` は `1d2 → TDA1 / TDA2 → 1d36` の二段処理
- `TDA1` / `TDA2` は hidden 内部表として保持し、UIには直接表示しない
- `TDB` 〜 `TDF` は `1d36`
- `TDG` 〜 `TDL` は `1d12`
- `アビス浸蝕表` は `2D6`
- 実本文データ反映済み
- `結果本文未設定` 残存なし
- 結果表示に `結果をコピー` ボタンを追加済み
- 直近履歴の各項目に個別 `コピー` ボタンを追加済み
- 直近履歴に `履歴をまとめてコピー` ボタンを追加済み
- 直近履歴は同一ページ表示中に振った結果を全件表示
- 履歴まとめコピーは表示中の全履歴を対象
- 履歴0件時はまとめコピーを disabled
- `localStorage` キー `velgard.tools.rollHistory` で直近履歴を保存し、ブラウザ更新後も復元
- `履歴をすべて削除` ボタンを追加済み
- 履歴0件時は全削除ボタンを disabled
- 全削除時は確認ダイアログ後、画面上の履歴と `localStorage` 履歴を削除
- `localStorage` のJSON parse失敗時は空履歴へフォールバックし、保存失敗時もページ全体を壊さずステータスメッセージで通知
- コピー対象は、表名 / 分岐 / 出目 / 結果本文
- 通常表、TDA自動分岐、アビス浸蝕表のコピー形式に対応
- `navigator.clipboard.writeText()` と `textarea` fallback を併用
- 390px幅でユーザー実ブラウザ確認済み
- 390px幅で横スクロールなし確認済み
- 表選択UIの見切れは、標準selectのまま親要素のoverflow、余白、z-index調整で緩和済み
- HTML文字化け検出後、直近バックアップから復元し、UTF-8状態でキャッシュクエリのみ再適用済み
- U+FFFDなし確認済み
- キャッシュ対策は `v=20260528-tools-random-tables` / `v=20260528-tools-nav-copy` / `v=20260529-ui-polish` / `v=20260529-tools-history-full` / `v=20260529-calendar-date-tools-history`

## CALENDAR / ラクシア運用カレンダー
- `calendar.html` を独立ページとして追加済み
- `CALENDAR / ラクシア運用カレンダー` は、現実日付からラクシア日付範囲、季節、月齢、レベルキャップを確認する読み取り専用ページ
- `data/calendarConfig.json` で開始日、ラクシア暦、季節、月齢、レベルキャップを管理
- `assets/js/renderCalendar.js` で描画と日付換算を担当
- 現実1日 = ラクシア5日分として換算
- 現実日付差分は `Date.UTC()` ベースで算出し、タイムゾーン差を避ける
- グローバルナビ、TOP左側縦ナビ、TOPメイン目次側に `CALENDAR / 運用カレンダー` 導線を追加済み
- 月表示カレンダーを追加済み
  - PC幅では7列グリッド表示
  - スマホ幅では縦積みリスト形式
  - 前月へ / 次月へ / 今日の月へ に対応
  - 日付セルクリックで詳細表示と日付入力が同期
- 季節、月齢、レベルキャップをセル内ラベルや淡い背景で視覚表示
- レベルキャップ開始日は、月表示カレンダー上に `3Lv開始` などの小バッジで表示済み
- `levelCaps[].startDate` と一致する日付のみ開始日扱いとし、期間中の日付や終了日は開始日扱いにしない
- 選択日詳細カードにも、開始日のみ `この日から3Lv期間が開始します。` 形式の節目表示を出す
- 開催期間外ではラクシア日付、季節、月齢、Lv数値を表示しない
- 開催期間外では開始日バッジやLv情報を表示しない
- 開催期間前 / 開催期間終了後のみ表示
- ラクシア年切り替わりは3月1日起点
- 暦年の月順は 3月,4月,5月,6月,7月,8月,9月,10月,11月,12月,1月,2月
- Phase 1 は読み取り専用
- カレンダー拡張 Phase 1-A として、静的セッション予定モックUIを追加済み
- `data/sessions.json` を追加済み
- `sessions.json` は `schemaVersion` / `updatedAt` / `sessions` を持つ
- 仮データは7件で、`recruiting` / `full` / `tentative` / `finished` / `canceled` / `closed` を含む
- Discord ID相当の将来用値は文字列で扱う。現行 `data/sessions.json` には実Discord IDが含まれるため、個人識別子として注意対象にする。
- 将来Supabaseへ移行する場合、Discord IDは `profiles.discord_user_id` などの非公開列へ移し、公開view / public RPC / public JSONレスポンスには出さない。
- 月表示カレンダーの日付セルには、その日の予定を `時刻 GM名 タイトル` で全件縦表示する
- `status: "closed"` の予定は、セル内で `〆 時刻 GM名 タイトル` 形式で表示する
- `〆` は行頭に置き、`gmName` はJS側で接頭辞を足さずデータ値をそのまま表示する
- `+n件` 圧縮は採用しない方針
- `募集中` / `満席` の強い状態バッジ表示は行わない
- 選択日詳細エリアに「選択日のセッション予定」を追加済み
- 選択日予定カードには、タイトル、`〆` 状態、開催時刻、GM名、レベル、募集人数、概要、タグを表示する
- カレンダー拡張 Phase 1-B として、セッション詳細モーダルを追加済み
- カレンダー拡張 Phase 1-E として、`session-detail.html?id=<session-id>` のセッション詳細ページを追加済み
- `assets/js/renderSessionDetail.js` を追加済み
- `session-detail.html` は `data/sessions.json` から該当セッションを取得し、`renderSessionDetailContent(session, { mode: "page" })` で表示する
- `id` 未指定 / 不存在ID / 読み込み失敗時は自然なエラー表示を出す
- カレンダーセル内予定行クリック / タップ、選択日予定カードの「詳細を見る」は `session-detail.html?id=<session-id>` へ遷移する
- 詳細ページには「カレンダーへ戻る」導線があり、`calendar.html?date=<session.date>` へ戻る
- `calendar.html?date=YYYY-MM-DD` に対応し、日付選択時にURLクエリを更新する
- `localStorage` キー `velgard.calendar.selectedDate` で選択日を補助保存し、ブラウザ更新後やクエリなし表示でも復元できる
- 不正な `date` クエリは画面を壊さず、保存済み日付または今日へフォールバックする
- 既存の詳細モーダル生成・イベント処理は `renderCalendar.js` から削除済み
- カレンダー拡張 Phase 1-C として、`assets/js/sessionDisplay.js` を追加し、セッション表示・詳細表示の整形ロジックを共通化済み
- `renderSessionDetailContent(session, options)` 系の共通関数は、詳細ページと将来の表示拡張で流用できる前提
- カレンダー拡張 Phase 1-D として、セッション詳細表示の情報設計をPL向けに整理済み
- セッション詳細表示の表示順は、基本情報、概要、詳細 / 参加条件、参加希望コメント、タグ、補足情報
- 基本情報には開催日、開催時刻、GM、レベル帯、募集人数をまとめて表示する
- PL向け詳細では `関連スポットID` / `シナリオID` / `公開範囲` を表示しない
- 補足情報は `状態` と `更新日時` 中心に整理する
- `updatedAt` は日付＋時刻表示に対応し、`2026-05-29T21:30:00` は `2026-05-29 21:30` として表示する
- 空項目は表示しない
- DiscordリンクはPL向けUIから削除済み。`discordThreadUrl` は将来のbot/Webhook同期用データとして残す
- `session-detail.html` に参加希望コメント型の静的UIモックを追加済み
- 通常予定では `参加希望コメント` セクションに、disabled のテンプレート選択、textarea、`コメント投稿（準備中）` ボタンを表示する
- 旧 `参加申請する（準備中）` ボタンは表示しない
- `closed` 予定では `募集締切` 表示になり、新規参加希望コメントを受け付けない旨を表示する
- `finished` / `canceled` では終了・中止メッセージのみを表示し、投稿UIを出さない
- コメント申請型では、参加人数はコメント件数ではなく申請者単位で管理する方針
- 同一ユーザーが複数回コメントしても参加人数は1人分として扱い、補足・修正・相談のコメントは人数として重複カウントしない想定
- 重複判定は将来 `userId` / `discordUserId` / 認証ユーザーIDなどで行う
- 予定がない日は「この日のセッション予定はまだありません。」を表示する
- 390px幅で横スクロールなし確認済み
- Phase 1-A / Phase 1-B / Phase 1-C / Phase 1-D / Phase 1-E / Phase 2-A は静的モックUIと表示整理であり、セッション予定登録、編集、実コメント投稿、コメント保存、コメント編集、申請用テンプレート保存、参加人数自動再計算、認証、Discord連携、外部DB/APIは未実装
- 〆ボタン実処理、参加申請停止処理、保存処理は未実装
- キャッシュ対策は `v=20260529-calendar-cap-start` / `v=20260529-calendar-sessions-mock-3` / `v=20260529-calendar-session-detail-polish` / `v=20260529-calendar-date-tools-history` / `v=20260529-session-comment-ui-mock`

## ページ上部へ戻るボタン
- 全ページ共通の「ページ上部へ戻る」ボタンを追加済み
- `assets/js/main.js` で自動生成
- `assets/css/style.css` で共通スタイル管理
- 表示は `↑`、`button` 要素として実装
- ページ上部付近では非表示、300px超スクロール後に表示
- クリックで同一ページの最上部へ戻る
- TOPページへ遷移するボタンではない
- `prefers-reduced-motion` に対応し、該当時はスムーズスクロールを避ける
- galleryモーダル表示時は非表示
- 画像モーダルより前面に出ない z-index で運用
- 390px幅で横スクロールなし確認済み
- キャッシュ対策は `v=20260528-back-to-top`

## 更新履歴追記
`data/updates.json` は現在41件です。以下の更新履歴を追加済みです。

### 2026-05-29 セッション詳細ページと履歴保持を追加
- 日付: 2026-05-29
- タイトル: セッション詳細ページと履歴保持を追加
- 本文: セッション予定の詳細ページ、カレンダー選択日の復元、TOOLS履歴の保存と全削除に対応しました。
- 対象: SITE
- タグ: UI

### 2026-05-29 カレンダー予定の詳細表示を追加
- 日付: 2026-05-29
- タイトル: カレンダー予定の詳細表示を追加
- 本文: カレンダーの予定行や予定カードからセッション詳細を確認できるモーダルを追加し、予定詳細の表示導線と読みやすさを整理しました。
- 対象: CALENDAR
- タグ: UI

### 2026-05-29 カレンダーにセッション予定表示を追加
- 日付: 2026-05-29
- タイトル: カレンダーにセッション予定表示を追加
- 本文: カレンダーに静的セッション予定データを追加し、日付セルと選択日詳細で予定を確認できるようにしました。
- 対象: CALENDAR
- タグ: UI

### 2026-05-29 ギャラリーのスワイプ操作を追加
- 日付: 2026-05-29
- タイトル: ギャラリーのスワイプ操作を追加
- 本文: スマホ・タブレット向けに、ギャラリー画像モーダルで左右スワイプによる前後移動に対応しました。
- 対象: GALLERY
- タグ: UI

### 2026-05-29 表示余白とトップ表示を調整
- 日付: 2026-05-29
- タイトル: 表示余白とトップ表示を調整
- 本文: WORLD本文の小見出し余白、トップページのキービジュアル表示、大画面時の横幅バランスを調整しました。
- 対象: SITE
- タグ: UI

### 2026-05-29 カレンダー表示を調整
- 日付: 2026-05-29
- タイトル: カレンダー表示を調整
- 本文: ラクシア運用カレンダーで、各レベルキャップ開始日が分かりやすく見えるように表示を調整しました。
- 対象: SITE
- タグ: カレンダー

### 2026-05-29 細部UIを調整
- 日付: 2026-05-29
- タイトル: 細部UIを調整
- 本文: TOOLSの履歴コピー、レギュレーション目次、関連キャラクター遷移など、公開前の細部UIを調整しました。
- 対象: SITE
- タグ: UI

### 2026-05-29 ラクシア運用カレンダーを追加
- 日付: 2026-05-29
- タイトル: ラクシア運用カレンダーを追加
- 本文: 現実日付からラクシア日付、季節、月齢、レベルキャップを確認できる運用カレンダーを追加しました。
- 対象: SITE
- タグ: カレンダー

### 2026-05-29 シナリオ本文の受け入れ基盤を追加
- 日付: 2026-05-29
- タイトル: シナリオ本文の受け入れ基盤を追加
- 本文: シナリオ詳細ページに配布情報欄を追加し、将来のTXT本文表示とPDFリンク表示に対応する基盤を整備しました。
- 対象: SCENARIOS
- タグ: シナリオ

### 2026-05-28 ページ上部へ戻るボタンを追加
- 日付: 2026-05-28
- タイトル: ページ上部へ戻るボタンを追加
- 本文: 全ページ共通で、スクロール後に現在ページの最上部へ戻れる固定ボタンを追加しました。
- 対象: SITE
- タグ: UI

### 2026-05-28 ランダム表ツールを追加
- 日付: 2026-05-28
- タイトル: ランダム表ツールを追加
- 本文: TOOLSページにランダム表ツールを追加し、TDA自動分岐、1d36表、1d12表、アビス浸蝕表の2D6判定に対応しました。
- 対象: SITE
- タグ: ツール

### 2026-05-28 ギャラリー検索機能を追加
- 日付: 2026-05-28
- タイトル: ギャラリー検索機能を追加
- 本文: ギャラリーに画像検索機能を追加し、カテゴリ絞り込みと組み合わせて画像を探しやすくしました。あわせてトップキービジュアルとギャラリー検索UIの表示を調整しました。
- 対象: GALLERY / SITE
- タグ: ギャラリー

### 2026-05-28 旧フック描画JSを整理
- 日付: 2026-05-28
- タイトル: 旧フック描画JSを整理
- 本文: シナリオ正式化により未使用となった旧フック描画用のrenderHooks.jsを削除しました。hooks.htmlは既存リンク互換入口として維持し、scenarios系描画へ接続しています。
- 対象: SCENARIOS
- タグ: シナリオ

### 2026-05-28 スポット詳細の関連シナリオ参照を正本化
- 日付: 2026-05-28
- タイトル: スポット詳細の関連シナリオ参照を正本化
- 本文: スポット詳細ページの関連シナリオ表示をrelatedScenarioIdsとscenarios.json参照へ一本化し、旧hooks由来のfallback処理を撤去しました。
- 対象: SCENARIOS / SPOTS
- タグ: シナリオ

### 2026-05-28 関連シナリオIDを整理
- 日付: 2026-05-28
- タイトル: 関連シナリオIDを整理
- 本文: スポット詳細ページの関連シナリオ参照をrelatedScenarioIdsへ一本化し、旧relatedHookIdsはデータ上から削除しました。互換用のfallback処理は維持しています。
- 対象: SCENARIOS / SPOTS
- タグ: シナリオ

### 2026-05-24 ギャラリーのシナリオ分類を正式化
- 日付: 2026-05-24
- タイトル: ギャラリーのシナリオ分類を正式化
- 本文: ギャラリー内のシナリオ画像カテゴリを正式なscenarios分類へ移行し、表示名やフィルターは「シナリオ」として維持しました。既存の画像IDと画像パスは互換維持しています。
- 対象: GALLERY / SCENARIOS
- タグ: ギャラリー

### 2026-05-24 シナリオ正式入口を追加
- 日付: 2026-05-24
- タイトル: シナリオ正式入口を追加
- 本文: 正式なシナリオ一覧ページとして scenarios.html を追加し、トップページと共通ナビのSCENARIOS導線を新入口へ切り替えました。既存の hooks.html は互換入口として維持しています。
- 対象: SCENARIOS
- タグ: シナリオ

### 2026-05-24 シナリオ正式化の土台を追加
- 日付: 2026-05-24
- タイトル: シナリオ正式化の土台を追加
- 本文: シナリオ候補データを scenarios.json へ分離し、既存URLを維持したままシナリオ一覧・個別準備中ページ・スポット詳細の関連シナリオ導線を正式化に向けて調整しました。
- 対象: SCENARIOS / SPOTS
- タグ: シナリオ

### 2026-05-24 トップページと目次表示を調整
- 日付: 2026-05-24
- タイトル: トップページと目次表示を調整
- 本文: トップページの表示文言と画像拡大導線を調整し、worldページの目次を現在位置に合わせて見やすくしました。
- 対象: SITE / WORLD
- タグ: UI

### 2026-05-24 正式ロゴを反映
- 日付: 2026-05-24
- タイトル: 正式ロゴを反映
- 本文: トップページの仮文字ロゴを正式ロゴ画像へ差し替え、サイト入口の視認性と印象を調整しました。
- 対象: SITE
- タグ: ロゴ

### 2026-05-24 灰壁線路線図を追加
- 日付: 2026-05-24
- タイトル: 灰壁線路線図を追加
- 本文: 灰壁線・防衛鉄道公社の関連資料として灰壁線路線図を追加し、ギャラリーとスポット詳細ページから確認できるようにしました。
- 対象: GALLERY / SPOTS
- タグ: 地図

### 2026-05-24 ギャラリー表示を調整
- 日付: 2026-05-24
- タイトル: ギャラリー表示を調整
- 本文: ギャラリーページの説明文とカテゴリ表示を現在の構成に合わせて調整し、シナリオ画像を「シナリオ」として閲覧できるようにしました。
- 対象: GALLERY
- タグ: ギャラリー

### 2026-05-24 レギュレーション表示導線を調整
- 日付: 2026-05-24
- タイトル: レギュレーション表示導線を調整
- 本文: トップページのレギュレーション表示を正式規約ページとして整え、レギュレーションページの目次を本文参照しやすい右側目次レイアウトへ調整しました。
- 対象: REGULATION
- タグ: レギュレーション

### 2026-05-24 シナリオ画像の拡大表示を追加
- 日付: 2026-05-24
- タイトル: シナリオ画像の拡大表示を追加
- 本文: 配布予定シナリオカードと個別シナリオ準備中ページの画像をクリックで拡大表示できるようにしました。
- 対象: SCENARIOS
- タグ: シナリオ

### 2026-05-24 シナリオページを準備中化
- 日付: 2026-05-24
- タイトル: シナリオページを準備中化
- 本文: HOOKSページをSCENARIOS / シナリオ表記へ移行し、配布予定シナリオの準備中カードと個別準備中ページを追加しました。
- 対象: SCENARIOS
- タグ: シナリオ

### 2026-05-24 ギャラリーモーダルの移動導線を追加
- 日付: 2026-05-24
- タイトル: ギャラリーモーダルの移動導線を追加
- 本文: ギャラリー画像のモーダルに前へ・次へ操作と現在位置表示を追加し、カテゴリ内で画像を続けて閲覧できるようにしました。
- 対象: GALLERY
- タグ: ギャラリー

### 2026-05-24 関連用語の導線を改善
- 日付: 2026-05-24
- タイトル: 関連用語の導線を改善
- 本文: スポット詳細ページから関連用語をクリックした際、用語集の該当カードへ直接移動できるようにし、ヴェルガルド固有用語も追加しました。
- 対象: TERMS
- タグ: 用語集

### 2026-05-24 キャラクター画像の拡大表示を追加
- 日付: 2026-05-24
- タイトル: キャラクター画像の拡大表示を追加
- 本文: 公式NPCカードの画像をクリックすると、大きめの立ち絵をモーダル表示できるようにしました。
- 対象: CHARACTERS
- タグ: NPC

### 2026-05-24 スポット詳細ページを追加
- 日付: 2026-05-24
- タイトル: スポット詳細ページを追加
- 本文: 主要スポット8件の詳細ページを追加し、地図や関連画像をクリックで拡大表示できるようにしました。
- 対象: SPOTS
- タグ: スポット

### 2026-05-24 公式NPCの年齢表示を追加
- 日付: 2026-05-24
- タイトル: 公式NPCの年齢表示を追加
- 本文: 公式NPC20名のカードに年齢表示を追加し、一部NPCの種族表記を最新設定に合わせて調整しました。
- 対象: CHARACTERS
- タグ: NPC

### 2026-05-24 トップページを改修
- 日付: 2026-05-24
- タイトル: トップページを改修
- 本文: トップページを作品公式サイト風の構成へ改修し、キービジュアルとナビゲーションを中心にした入口ページへ調整しました。
- 対象: SITE
- タグ: トップページ

### 2026-05-24 表示まわりを調整
- 日付: 2026-05-24
- タイトル: 表示まわりを調整
- 本文: キャラクターカードの画像表示と共通背景の表示を調整し、人物画像やページ全体の見え方を改善しました。
- 対象: SITE
- タグ: 表示調整

### 2026-05-24 世界観本文を詳細版へ更新
- 日付: 2026-05-24
- タイトル: 世界観本文を詳細版へ更新
- 本文: worldページの本文を詳細版へ更新し、ヴェルガルドの舞台概要、歴史、政治、産業、文化、防衛体制がより伝わるよう整備しました。
- 対象: WORLD
- タグ: 世界観

### 2026-05-24 シナリオフックの説明文を整備
- 日付: 2026-05-24
- タイトル: シナリオフックの説明文を整備
- 本文: シナリオフック7件の説明文を整備し、各題材の雰囲気や遊び味が伝わりやすくなるよう調整しました。
- 対象: HOOKS
- タグ: シナリオフック

### 2026-05-24 公式NPCの紹介文を整備
- 日付: 2026-05-24
- タイトル: 公式NPCの紹介文を整備
- 本文: 公式NPC20名の紹介文を整備し、人物像や口調が伝わるサンプルセリフを追加しました。
- 対象: CHARACTERS
- タグ: NPC

### 2026-05-24 主要スポットの説明文を整備
- 日付: 2026-05-24
- タイトル: 主要スポットの説明文を整備
- 本文: 主要スポットの説明文を整備し、ヴェルガルド各地の役割や雰囲気を読みやすくしました。
- 対象: SPOTS
- タグ: スポット

### 2026-05-24 用語集の説明文を整備
- 日付: 2026-05-24
- タイトル: 用語集の説明文を整備
- 本文: 用語集の説明文を整備し、ヴェルガルドの地域・制度・組織・文化に関する公開情報を読みやすくしました。
- 対象: TERMS
- タグ: 用語集

### 2026-05-24 画像ギャラリーを本格整備
- 日付: 2026-05-24
- タイトル: 画像ギャラリーを本格整備
- 本文: ギャラリーを本格整備し、キービジュアル・地点・施設・シナリオフック・地図画像をカテゴリ別に閲覧できるようにしました。
- 対象: GALLERY
- タグ: 画像資料

## Discord共有について

本サイトは身内向け共有を想定しています。X等のSNS拡散は現時点では想定していないため、X / Twitterカード互換metaは整備対象外です。

正式公開URLは `https://suisui334.github.io/velgard-site/` です。DiscordでURLを貼った際の表示を整えるため、`data/site.json` の `publicUrl`、全HTMLの `og:url`、全HTMLの `og:image` を正式URLへ反映済みです。OGP画像は軽量版 `assets/images/common/ogp-main-1200x630.png` を使用し、HTML上では `https://suisui334.github.io/velgard-site/assets/images/common/ogp-main-1200x630.png` の絶対URLで参照しています。

Discord共有時にOGP画像が表示されるかは次工程で確認します。公開後確認の手順は `docs/release-runbook.md` に分離しています。

旧仮画像 `assets/images/common/ogp-placeholder.svg` と原本 `assets/images/common/ogp-main.png` は残していますが、現在のHTML参照は軽量版PNGです。

faviconは `assets/images/common/favicon-32.png` / `assets/images/common/favicon-192.png` を参照し、`assets/images/common/apple-touch-icon.png` も設定済みです。原本 `assets/images/common/favicon.png` は維持しています。

## 確定表記
- “灰壁と花霧の国”ヴェルガルド
- 灰壁の灯火亭
- 双角市場オルム
- フェルゼ坑町
- 煤煙鉱山フェルゼ坑
- ヴォルフラム・シュタール
- オイゲン・ホフマン
- ガルド・ヴァルクス

確定ID:

- ガルド・ヴァルクス: `gald-valks`
- ヴォルフラム・シュタール: `wolfram-stahl`
- オイゲン・ホフマン: `eugen-hoffmann`

## 禁止旧表記
- 灰壁の灯亭
- 双角市オルム
- ヴォルフラム・グラシュ
- オイゲン・ノルデン
- グラシュ吊橋砦市
- gald-valx
- gald-valk
- gald-valkus
- wolfram-grasch
- eugen-norden
- grasch-suspension-bridge-fort-city

## 今後の後工程
- 詳細な残タスク・保留事項・触らない方がよい互換要素は `docs/task-backlog.md` に分離済み。
- READMEは現状概要と主要運用方針を中心にする。
- `docs/task-backlog.md` は今後の作業判断・優先順位管理に使う。
- シナリオファイル受け入れ方針は `docs/scenario-file-policy.md` に分離済み。
- 正式公開URL反映後の公開確認手順は `docs/release-runbook.md` に分離済み。
- 参加希望コメント、申請管理、GM編集、〆ボタン、Discord同期に向けたSupabaseプロトタイプ設計方針は `docs/supabase-prototype-plan.md` に分離済み。
- Supabaseプロトタイプを実操作する直前の判断基準・作業順・RLSテスト手順は `docs/supabase-prototype-runbook.md` に分離済み。
- Supabase Freeプロトタイプ Step 0〜2 の準備パックは `docs/supabase-step0-2-preflight.md`、`docs/supabase-rls-test-matrix.md`、`docs/supabase/sql/` に分離済み。参加希望コメントは公開申請欄に近い扱いだが表示用RPC/viewではDiscord IDや内部user_idを出さず、private / hidden コメントは漏洩防止、`full` sessionは新規申請不可の方針へ整理済み。まだSupabase登録、SQL実行、本番接続は行わない。
- シナリオ本文・PDF受け入れ基盤は実装済み。配布シナリオ本文作成と実ファイル配置はユーザー提供ファイル待ち。初期方針はTXT正本 / PDF任意で、本文・PDF・配布ファイルを受け取ってから反映する。
- 互換維持中の `hooks.html` / `data/hooks.json` / `gallery-hook-*` ID / `assets/images/hooks/` / `characters.json` の `relatedHooks` は、未対応ではなく意図的な保留として扱う。

## Codex作業時の注意
- ユーザーが作業報告を貼っていない工程は未実施として扱う
- 完了判断はCodex作業報告ベース
- 文章や説明文は仮〜初稿扱い
- 既存IDを不用意に変更しない
- 確定表記を維持する
- 禁止旧表記を復活させない
- OGP画像は正式公開URLの絶対URLへ差し替え済み
- X / Twitterカード互換metaは今回不要
- 現在のHTML上のOGP参照は `https://suisui334.github.io/velgard-site/assets/images/common/ogp-main-1200x630.png`
