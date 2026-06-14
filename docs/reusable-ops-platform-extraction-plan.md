# Reusable Ops Platform Extraction Plan

## 1. 背景

ヴェルガルド公開サイトは、現在ひとつの静的サイト内に次の2種類の役割を持っている。

- ヴェルガルド固有の世界観紹介サイト
- 次の世界観でも再利用したいTRPG運用基盤

将来、ヴェルガルド期間満了後に別世界観を立てる場合、`mypage`、`calendar`、依頼書作成、依頼書詳細、参加申請、コメント、会員管理、テンプレート管理、Discord同期、通知、TIMELINEなどは再利用候補になる。一方で、`world`、`characters`、`spots`、`gallery`、`terms`、`regulation`などは世界観ごとに内容と見た目が大きく変わる。

この計画では、いきなり独立アプリ化せず、現在のコード・データ・docsをもとに、どこから切り出せるか、どこはまだ切ってはいけないかを整理する。実装変更、ファイル移動、DB/RPC/RLS変更、SQL apply、Edge deploy、Discord操作は行わない。

## 2. 現在のサイト構造

主要なフロント構造:

- `assets/js/main.js`: 共通ヘッダー、ナビ、ページ判定、主要rendererの起動、会員状態によるナビ表示制御。
- `assets/js/dataLoader.js`: JSONデータ読み込みの共通部品。
- `assets/js/supabaseBrowserClient.js`: Supabase client初期化。
- `assets/js/membershipAccessClient.js`: 会員状態取得、approved gate表示、アクセス案内。
- `assets/js/mypageAuthClient.js`: 認証、プロフィール、PC、予定、テンプレート、会員状態、会員管理UIが集約されている。
- `assets/js/renderCalendar.js`: カレンダー描画、会員gate、日付変換、依頼書表示。
- `assets/js/renderSessionPost.js`: 依頼書作成・編集フォーム、テンプレート、Discord同期導線。
- `assets/js/renderSessionDetail.js` / `assets/js/sessionDetailApplicationComments.js`: 依頼書詳細、参加申請、コメント、GM/admin管理、テンプレート。
- `assets/js/sessionData.js` / `assets/js/sessionDisplay.js`: 依頼書データ取得、正規化、表示補助。
- `assets/js/notificationBellClient.js` / `assets/js/activityTimelineDisplay.js`: 通知ベルとTIMELINE表示。
- `assets/js/discordSyncClient.js`: Discord同期Edge Function呼び出しのフロント導線。
- `assets/css/style.css`: 世界観見た目、共通ヘッダー、運用UI、会員管理、依頼書、カレンダー、ギャラリー等が混在する単一CSS。

主要なデータ構造:

- `data/site.json`: サイト名、世界観名、ロゴ、画像、テーマ色、メタ情報。
- `data/calendarConfig.json`: 開始日、ゲーム内暦、季節、月齢、レベルキャップ、ラベル。
- `data/world.json`, `characters.json`, `spots.json`, `spotDetails.json`, `gallery.json`: 世界観紹介データ。
- `data/terms.json`, `regulation.json`: 規約・レギュレーション。
- `data/hooks.json`, `scenarios.json`, `campaigns.json`, `episodes.json`: フック、シナリオ、キャンペーン表示。
- `data/sessions.json`: 旧静的依頼書データ。現在はSupabase側が主だが、フロントに補助経路が残る。

DB/RPC/Edge Function関連:

- `docs/supabase/sql/` に依頼書、コメント、通知、TIMELINE、会員承認、テンプレート等のSQL履歴が蓄積されている。
- `supabase/functions/sync-session-post-to-discord` はDiscord同期の中核で、世界観固有の投稿文言や公開導線との関係を持つ。
- `supabase/functions/dispatch-admin-cap-announcements` はレベルキャップ告知系で、キャンペーン運用と強く関係する。

## 3. 汎用運用基盤候補

### A. ほぼそのまま汎用化できるもの

- JSON読み込み: `assets/js/dataLoader.js`。
- Supabase client初期化の考え方: `assets/js/supabaseBrowserClient.js` と runtime config構造。
- 会員状態取得とapproved gateの仕組み: `assets/js/membershipAccessClient.js`。文言は設定化が必要。
- 通知ベルの未読件数、一覧、既読化、エラー時の控えめ表示: `assets/js/notificationBellClient.js`。通知種別ラベルと遷移先は設定化が必要。
- TIMELINE表示の基本: `assets/js/activityTimelineDisplay.js`。イベント種別ラベル、対象名、詳細リンク文言は設定化が必要。
- 依頼書データ正規化の方向性: `assets/js/sessionData.js` / `sessionDisplay.js`。DB列名や表示ラベルは設定化が必要。
- 会員承認・会員管理RPCの設計方針: `community_memberships`、`is_approved_member()`、`membership_approver`、管理用RPC。運用基盤として再利用価値が高い。
- コメント/参加申請の基本RPC設計: `create_application_comment`、編集、削除、申請取消、spam guard、approved gate。
- テンプレート管理の基本設計: 本人テンプレート、種別、保存/更新/削除、画面別呼び出し。

### B. 設定ファイル化すれば汎用化できるもの

- ナビゲーションとページregistry: `assets/js/main.js` の固定navとpage判定。
- サイト名、世界観名、短縮名、ロゴ、テーマ色: `data/site.json`。
- カレンダー開始日、ゲーム内暦、月名、季節、月齢、レベルキャップ: `data/calendarConfig.json`。
- 依頼書の種別、色、ラベル、募集状態、公開状態、フォーム項目名。
- `依頼書`、`参加申請`、`コメント`、`GM`、`PL` などの固定ラベル。
- approved gateや会員状態案内の文言。
- 通知/TIMELINEのイベント種別ラベル。
- Discord同期対象、Edge Function名、投稿本文の世界観依存文言。
- mypageの見出し、折りたたみ構成、テンプレート種別ラベル。
- 規約・レギュレーションのカテゴリ名、表示ブロック種別。
- ギャラリーカテゴリ、画像分類、世界観ページの表示ブロック構造。

### C. ヴェルガルド固有依存が強く、当面は切り離さない方がよいもの

- `data/site.json` の実内容、ロゴ、キービジュアル、テーマ色、世界観説明。
- `data/world.json`、`characters.json`、`spots.json`、`spotDetails.json`、`gallery.json` の内容。
- `data/terms.json`、`regulation.json` の規約・ハウスルール本文。
- ヴェルガルド固有の暦変換、開始日、レベルキャップ運用、キャンペーン表現。
- `hooks`、`scenarios`、`campaigns`、`episodes` の実データ。
- 世界観固有の画像、地図、人物/施設/用語、ギャラリー分類。
- 世界観紹介ページのビジュアルトーン、余白、装飾、見出し表現。

### D. 将来独立ツール化する際に障害になりそうな依存

- `assets/js/main.js` が共通ナビ、世界観ページ、運用ページ、会員gateを一手に扱っている。
- `assets/css/style.css` に世界観見た目と運用UIが混在している。
- `assets/js/mypageAuthClient.js` が認証、プロフィール、PC管理、予定、テンプレート、会員状態、会員管理を抱えている。
- `session-post`、`session-detail`、`calendar`、Discord同期が同じ依頼書データ構造に密結合している。
- Supabase RPC名、DB列名、フロント表示ラベルが一部同じ層に混ざっている。
- Edge Function側のDiscord投稿文言とサイト側の世界観設定がまだ明確に分離されていない。
- `data/sessions.json` の旧静的経路が残っており、完全な運用基盤化時に責務が曖昧になりやすい。
- cache-bustやimport queryがHTML/JSへ分散している。
- 会員承認、approved gate、RLS/RPC、UI導線が強く絡むため、フォルダ移動だけで切ると権限境界を壊しやすい。

## 4. ヴェルガルド固有部分

当面は、以下をヴェルガルド固有として保持する。

- 世界観名、ステージ名、ロゴ、キービジュアル、画像群。
- world / characters / spots / gallery / terms / regulation の実データ。
- ヴェルガルド固有の規約本文とレギュレーション本文。
- キャンペーン内の暦、月名、季節、レベルキャップ、運用日付。
- ヴェルガルド用のページ順、導線、見出し、コピー。
- Discord投稿本文のうち、世界観名や運用文脈に依存する部分。

独立化時も、これらを単純に削除するのではなく、`world/velgard` 的な世界観packageとして残すのが安全。

## 5. 世界観サイトテンプレート候補

ここでのテンプレート化は、デザイン固定ではない。次世界観でも使えるページ種別、データ項目、導線設計、表示ブロックの型を抽出する。

### ページ種別

- TOP: ロゴ、キービジュアル、世界観概要、最近の活動、主要導線。
- WORLD: 世界観概要、章立て、補足、用語、表。
- CHARACTERS: NPC / PC / 重要人物などの一覧と詳細。
- SPOTS: 地点、施設、エリア、関連人物、関連フック。
- HOOKS / SCENARIOS: 導入、依頼種別、推奨条件、関連地点。
- TERMS: 参加規約、運用規約、連絡/禁止事項。
- REGULATION: ルールカテゴリ、ハウスルール、表、注意ブロック。
- GALLERY: 画像カテゴリ、説明、関連ページ導線。
- MAPS: 地図、地点リンク、エリア説明。

### データ項目候補

- 共通: `id`, `title`, `name`, `summary`, `description`, `category`, `tags`, `status`, `image`, `relatedIds`。
- 人物: `role`, `faction`, `location`, `quote`, `relationships`。
- 地点/施設: `area`, `type`, `facilities`, `npcIds`, `hookIds`, `mapPosition`。
- 用語/規約: `section`, `blocks`, `notes`, `tables`, `severity`。
- ギャラリー: `category`, `caption`, `source`, `relatedPage`, `sortOrder`。
- シナリオ/フック: `hookType`, `recommendedLevel`, `sessionType`, `relatedSpotIds`, `visibility`。

### 表示ブロック候補

- 見出し + 段落
- カード一覧
- 詳細パネル
- 関連リンク
- 表
- 注意/補足/callout
- 画像ギャラリー
- フィルタ/カテゴリタブ
- TOC

### テンプレート化の注意

- 世界観ごとに雰囲気、色、レイアウト密度、画像比率は変わる前提にする。
- まずはデータschemaとページ骨格をテンプレート化し、CSSやビジュアルは世界観package側に逃がす。
- TOPだけは世界観の顔になりやすいため、完全共通化より「共通ブロックを選べる」方式がよい。

## 6. 独立化案の比較

### 案A: 現状維持に近い軽い設定化

内容:

- 同じサイト内で、文言、色、ナビ、セッション種別、カレンダー設定を少しずつ設定ファイル化する。
- ファイル移動や大規模分割はしない。

メリット:

- 低リスクで始められる。
- 現行ヴェルガルド運用を壊しにくい。
- 小さいPR/commitに分けやすい。

デメリット:

- コアと世界観の境界は曖昧なまま残る。
- 次世界観で再利用する時に手作業コピーが多い。
- CSSと大きなJSの混在は解消しない。

移行コスト: 低。

現時点での危険度: 低。

将来の再利用性: 中。

今すぐやるべきか: はい。Phase 1として最初に進める候補。

### 案B: 同一repo内で運用基盤コアと世界観サイトを分離

内容:

- 例として、将来的に次のような構成へ寄せる。
  - `assets/js/core/`
  - `assets/js/ops/`
  - `assets/js/world/`
  - `assets/js/velgard/`
  - `data/core/`
  - `data/world/velgard/`
  - `assets/css/core.css`
  - `assets/css/ops.css`
  - `assets/css/world.css`
  - `assets/css/velgard.css`
- まずimport境界と責務を分け、DB/RPCやUIの動作は変えない。

メリット:

- 現行サイトを維持しながら再利用性を上げられる。
- どの機能が運用基盤で、どれが世界観packageか見えやすくなる。
- 次世界観の試作を同じrepo内で作りやすい。

デメリット:

- import/cache-bust/HTML参照更新が多くなりやすい。
- `mypageAuthClient.js` や `style.css` の分割は慎重さが必要。
- 表面上はファイル移動でも、権限・RPC・UI導線の回帰リスクがある。

移行コスト: 中。

現時点での危険度: 中。

将来の再利用性: 高。

今すぐやるべきか: 設計後に段階的に進める。いきなり全体分割は避ける。

### 案C: 別repo / 別サイト / 別サブアプリとして独立

内容:

- TRPG運用ポータルを独立アプリ化し、ヴェルガルドはそのポータルを利用する一世界観として扱う。
- 世界観サイトと運用基盤を別deploy、別repo、またはサブアプリ化する。

メリット:

- 再利用性は最大。
- 複数世界観を本格的に扱う場合に責務が明確。
- 運用基盤のセキュリティ/QAを単独で管理しやすい。

デメリット:

- 現時点では移行コストが高すぎる。
- 認証、会員状態、RPC、通知、Discord同期、依頼書リンクの接続点が多い。
- 別ドメイン/別サイト化するとAuth redirect、CORS、メールURL、Discord投稿URLの再設計が必要。
- 現行ヴェルガルド運用を壊すリスクが高い。

移行コスト: 高。

現時点での危険度: 高。

将来の再利用性: 最高。

今すぐやるべきか: いいえ。少なくともPhase 1〜4で境界と設定化を進め、次世界観の実需要が見えてから判断する。

## 7. 設定ファイル化候補

### サイト/世界観設定

候補ファイル:

- `data/site.json` を維持しつつ、将来 `data/world/velgard/site.json` へ移す。
- 汎用側には `data/core/site-defaults.json` のような既定値を置く。

設定候補:

- サイト名
- 世界観名
- 短縮名
- tagline
- ロゴ
- key visual
- theme color
- meta description
- favicon / OGP画像

### ナビゲーション設定

候補:

- `data/core/navigation.json`
- `data/world/velgard/navigation.json`

設定候補:

- ページID
- 表示ラベル
- href
- public / approved-only / admin-only
- nav group
- 表示順
- mobile時の扱い

### カレンダー/依頼書設定

候補:

- `data/core/calendar-defaults.json`
- `data/world/velgard/calendarConfig.json`
- `data/core/session-config.json`

設定候補:

- カレンダー開始日
- ゲーム内暦変換
- 月名
- 曜日
- 季節
- 月齢
- レベルキャップ
- セッション種別
- セッション種別ごとの色/class
- 募集状態
- 公開状態
- `依頼書` などの表示ラベル

### Auth / Membership / Gate設定

候補:

- `data/core/access-labels.json`

設定候補:

- pending / approved / rejected / revoked / blocked の表示文言
- approved gate文言
- 未ログイン時案内
- mypage会員状態見出し
- 会員管理UIラベル
- エラー表示の汎用文言

DB/RPC側の権限判定は設定ファイル化しない。設定化するのは表示文言とUI導線のみ。

### 通知/TIMELINE設定

候補:

- `data/core/activity-labels.json`

設定候補:

- event type / notification type の表示ラベル
- `session_application` を表示上 `コメントしました` にするようなサイト方針
- 対象名ラベル
- 詳細ページpath
- 空状態文言

### Discord同期設定

候補:

- `data/core/discord-sync-client-config.json`
- Edge Function側は別途環境変数/設定分離を検討。

設定候補:

- Edge Function名
- 同期対象
- dry-run文言
- UI確認文言
- 投稿本文の世界観依存ラベル
- 公開サイト相対path

Webhook secretや実チャンネル情報は設定ファイルへ置かない。

### 世界観ページ設定

候補:

- `data/world/page-registry.json`
- `data/world/gallery-config.json`
- `data/world/regulation-config.json`

設定候補:

- world / characters / spots / hooks / scenarios / terms / regulation / gallery の有効化
- ページ見出し
- ブロック種別
- カテゴリ
- フィルタ
- TOC有無
- 画像分類

## 8. 段階的ロードマップ

### Phase 0: 棚卸し・設計整理

目的:

- 現在の混在状態を把握し、切り出し候補と危険箇所を整理する。

作業内容:

- 本ドキュメント作成。
- task backlogへ次工程候補を記録。

触るファイル候補:

- `docs/reusable-ops-platform-extraction-plan.md`
- `docs/task-backlog.md`

リスク:

- 実装変更なしのため低い。

完了条件:

- 汎用運用基盤、世界観固有、テンプレート候補、ロードマップが整理済み。

危険工程:

- なし。

### Phase 1: 世界観依存文言・色・ラベルの設定ファイル化

目的:

- ファイル移動なしで、世界観依存の文言・色・ラベルを設定へ逃がす。

作業内容:

- navラベル、site名、approved gate文言、通知/TIMELINEラベル、セッション種別色の設定化。
- 既存UIの表示結果を変えない。

触るファイル候補:

- `data/site.json`
- `data/calendarConfig.json`
- 新規 `data/core/*.json`
- `assets/js/main.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/notificationBellClient.js`
- `assets/js/activityTimelineDisplay.js`
- `assets/js/sessionDisplay.js`

リスク:

- 中。表示ラベルの読み込み失敗やcache-bust漏れが起きやすい。

完了条件:

- 主要固定文言が設定経由になり、現行表示が維持される。

危険工程:

- DB/RPC変更なし。フロントQAは必要。

### Phase 2: 運用基盤JS/CSSのフォルダ分離

目的:

- 同一repo内で責務を見える化する。

作業内容:

- `assets/js/core/`, `assets/js/ops/`, `assets/js/world/`, `assets/js/velgard/` のような段階的分離。
- `style.css` を `core/ops/world/velgard` 相当へ分割する準備。
- importとcache-bustを最小単位で更新。

触るファイル候補:

- `assets/js/main.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/render*.js`
- `assets/css/style.css`
- 各HTML

リスク:

- 中〜高。見た目や初期化順、import path、cache-bustの回帰が起きやすい。

完了条件:

- 表示・認証・依頼書・会員管理が従来どおり動き、責務別フォルダができている。

危険工程:

- DB/RPC変更なし。ただしブラウザQA必須。

### Phase 3: mypage / calendar / session系を汎用モジュール化

目的:

- 運用基盤として再利用できる単位へ寄せる。

作業内容:

- mypage内の認証、プロフィール、PC、テンプレート、会員管理を小モジュールへ分割。
- calendarとsession-detail/session-postの共通設定を整理。
- session/application/commentのラベルとRPC adapterを分離。

触るファイル候補:

- `assets/js/mypageAuthClient.js`
- `assets/js/renderCalendar.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- Supabase RPC docs

リスク:

- 高。認証、会員状態、RPC、通知、Discord同期、テンプレートが絡む。

完了条件:

- ヴェルガルド固有設定を差し替えても、運用UIの主要導線が成立する。

危険工程:

- 原則フロント中心。ただしRPC adapter設計次第でSQL draftが必要になる可能性あり。

### Phase 4: 次世界観向け world-site-template 作成

目的:

- デザイン固定ではなく、ページ骨格とデータschemaを再利用できるようにする。

作業内容:

- world / characters / spots / terms / regulation / gallery のschema案を確定。
- サンプル世界観データまたは空テンプレートを作る。
- ページregistryで有効ページを選べるようにする。

触るファイル候補:

- `data/world/`
- `assets/js/world/`
- `assets/js/velgard/`
- `docs/`

リスク:

- 中。世界観ページは見た目の自由度を残す必要がある。

完了条件:

- 新しい世界観データを置いた時に、最低限のページ骨格を再利用できる。

危険工程:

- なし。フロント表示QAは必要。

### Phase 5: 必要なら運用基盤を独立アプリ化

目的:

- 複数世界観をまたぐTRPG運用ポータルへ発展させる。

作業内容:

- 別repo / 別サイト / サブアプリ化を検討。
- Auth redirect、メールURL、Discord投稿URL、DB schema、RPC namespaceを再設計。
- ヴェルガルドは一世界観packageとして接続する。

触るファイル候補:

- 全体。
- Supabase project / Auth設定 / Edge Function / deploy設定。

リスク:

- 高。現時点では実施しない方がよい。

完了条件:

- 第二世界観の実需要があり、同一repo内分離が十分進み、独立化コストに見合う状態。

危険工程:

- DB/Auth/Edge/deploy/secret/Discordを含むため、明示ゲート必須。

## 9. 今すぐやるべきこと

- Phase 1に向けて、まず表示文言・色・ラベルの設定化候補を小さく切る。
- `main.js` のnav固定値を設定化する前に、approved-only / public / admin-onlyの表示ルールを整理する。
- `sessionDisplay.js` と `renderCalendar.js` に散らばるセッション種別/色/ラベルを棚卸しする。
- `membershipAccessClient.js` の案内文を設定化候補として整理する。
- `notificationBellClient.js` / `activityTimelineDisplay.js` のイベント表示ラベルを設定化する。
- `style.css` 分割前に、セレクタを ops / world / shared に分類するだけのdocsまたはコメントなし棚卸しを行う。

## 10. 今はやらない方がいいこと

- 完全独立アプリ化。
- DB/RPC namespaceの大規模変更。
- `mypageAuthClient.js` の一括分割。
- `style.css` の一括分割。
- Edge Functionの世界観非依存化を一気に進めること。
- Auth redirectやメールURL、Discord投稿URLを伴う別サイト化。
- 依頼書、申請、コメント、会員管理、通知、TIMELINEを同時に移動すること。
- `public_profiles` にmembership/role情報を出すような設計変更。

## 11. 次工程候補

1. Config inventory:
   - `main.js`、`calendarConfig.json`、`site.json`、通知/TIMELINE、membership gate文言から設定化候補だけを一覧化する。
2. Session label config:
   - セッション種別、状態、色、`依頼書` 表示ラベルを設定化する小さなフロント改修案を作る。
3. Nav registry design:
   - `public` / `approved-only` / `admin-only` / `membership-manager-only` を持つnav定義案をdocs化する。
4. CSS responsibility audit:
   - `style.css` のセレクタを shared / ops / world / velgard に分類する。
5. World data schema audit:
   - `world`、`characters`、`spots`、`gallery`、`terms`、`regulation` のschemaを次世界観テンプレート候補として整理する。
6. Discord text separation plan:
   - Discord同期本文のうち、世界観依存文言と運用基盤文言を分ける計画を作る。

結論として、現時点では案AからPhase 1を始め、次に案Bの同一repo内分離へ進むのが安全。案Cの完全独立アプリ化は、設定化と同一repo内分離が進み、第二世界観の具体要件が見えてから再判断する。

## Phase 1-A Result

`1371a33 Plan reusable ops platform extraction` 後の最初の実装として、
`assets/js/reusableOpsConfig.js` を追加し、calendarのセッション種別ラベル、
calendar用表示class、基本ボタン文言の一部を設定入口から参照する形へ寄せた。

今回の実装は案A寄りの最小範囲で、mypage、approved gate、session-post、
session-detail、Discord同期、DB/RPC/RLSには触れていない。詳細は
`docs/reusable-ops-platform-phase1-config-result.md` に記録する。

## Phase 1-B Result

`2d8f495 Add reusable ops config foundation` 後の次工程として、
`sessionDisplay.js` のセッション種別ラベルを `reusableOpsConfig.js` へ接続した。
これにより、calendar以外のsession-post / session-detail系表示でも同じ
session type label設定を参照できる入口ができた。

mypage、approved gate、session UI周辺のラベル候補も整理し、
`reusableOpsConfig.js` に候補値とgetterを追加した。ただし、mypage本体は通常script
で影響範囲が広いため、今回は実表示接続を行っていない。詳細は
`docs/reusable-ops-platform-phase1b-label-config-plan.md` に記録する。

## Phase 1-C Result

`52e4ac7 Extend reusable ops label config` 後の次工程として、
mypage向けの安全な設定参照方式を実装した。

`mypageAuthClient.js` は通常scriptのまま維持し、ES module化やフォルダ再編は
行っていない。代わりに `assets/js/reusableOpsMypageLabels.js` を追加し、
mypageの表示ラベルだけをclassic scriptから読めるbridgeとして公開した。
`mypage.html` はこのbridgeを `mypageAuthClient.js` より前に読み込む。

接続したのは、アカウント概要、プロフィール / PC情報、予定 / 申請履歴、
テンプレート管理、会員管理などの主要details見出しと短いsummary文言のみ。
設定未読込時は `mypageAuthClient.js` 側のfallback文言を使うため、画面は
従来表示へ戻る。

認証、approved gate判定、会員管理RPC、`management_key`、DB/RPC/RLS、
Discord同期、操作ボタン文言、エラー文言は変更していない。詳細は
`docs/reusable-ops-platform-phase1c-mypage-config-result.md` に記録する。
