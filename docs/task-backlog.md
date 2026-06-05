# ヴェルガルド公開サイト task-backlog

この文書は、公開前後の残タスク、保留事項、触らない方がよい互換要素を整理する作業台です。利用者向け更新履歴ではなく、制作管理用のメモとして扱います。

## 1. 現在の基準状態

- `updates.json` は41件。
- 最新更新は 2026-05-29「セッション詳細ページと履歴保持を追加」。
- `scenarios.html` は正式な SCENARIOS / シナリオ入口。
- `hooks.html` は既存リンク互換入口として維持。
- `data/scenarios.json` は7件、`data/hooks.json` は7件維持。
- `scenarios.json` と `hooks.json` のIDは一致。
- `assets/js/renderHooks.js` は削除済み。
- `scenario-detail.html` は `data/scenarios.json` を参照。
- `data/scenarios.json` は既存7件すべて `releaseStatus: preparing`。
- シナリオ本文・PDF受け入れ基盤は実装済み。
- `scenario-detail.html` は配布情報セクションを表示し、将来の `textUrl` / `pdfUrl` に対応できる。
- 実シナリオ本文 `.txt` / PDF の配置と `textUrl` / `pdfUrl` の実URL追加は未実施。
- `spotDetails.json` は8件で、`relatedScenarioIds` は8スポット分、`relatedHookIds` は0件。
- `renderSpotDetail.js` は `relatedScenarioIds` / `scenarios.json` 正本。
- `gallery.json` は41件で、`category: scenarios` は7件、`category: hooks` は0件。
- `gallery-hook-*` ID は7件維持。
- `assets/images/hooks/` は7画像維持。
- `characters.json` の `relatedHooks` は20件維持。`spotDetails.json` の `relatedHookIds` とは別スキーマとして扱う。
- mapsカテゴリは9件。
- `tools.html` は補助ツールページとして追加済み。
- ランダム表ツールは実装済みで、実本文データ反映済み。
- TDA自動分岐、TDB〜TDFの1d36、TDG〜TDLの1d12、アビス浸蝕表の2D6に対応済み。
- TOP左側縦ナビに `TOOLS` 導線を追加済み。
- ランダム表ツールの結果コピー機能と履歴別コピー機能は追加済み。
- ランダム表ツールの履歴まとめコピー機能は追加済み。
- ランダム表ツールの履歴表示上限は撤廃済みで、同一ページ表示中に振った結果は全件表示する。
- ランダム表ツールの履歴は `localStorage` キー `velgard.tools.rollHistory` で保存し、ブラウザ更新後も復元する。
- ランダム表ツールに `履歴をすべて削除` ボタンを追加済み。確認ダイアログ後、画面上の履歴と `localStorage` 履歴を削除する。
- `localStorage` のJSON parse失敗時は空履歴へフォールバックし、保存失敗時もページ全体を壊さない。
- ランダム表ツールの表選択UI見切れは標準selectのまま緩和済み。
- `regulation.html` の右側目次見切れは調整済み。
- `spot-detail.html` の関連キャラクターリンクは、`characters.html#character-<characterId>` で該当カード位置へ遷移できる。
- 全ページ共通の「ページ上部へ戻る」ボタンは追加済み。
- 「ページ上部へ戻る」ボタンは、スクロール後に表示し、同一ページの最上部へ戻る仕様。
- 「ページ上部へ戻る」ボタンはモーダル干渉対策済みで、390px幅確認済み。
- ラクシア運用カレンダー Phase 1 は実装済み。
- `calendar.html` は独立ページとして追加済み。
- `data/calendarConfig.json` は開始日、ラクシア暦、季節、月齢、レベルキャップの設定元。
- カレンダー拡張 Phase 1-A として、`data/sessions.json` による静的セッション予定モックUIは実装済み。
- `data/sessions.json` は7件の仮予定を持ち、`2026-06-08` に3件の同日複数予定を含む。
- カレンダーセルでは予定を `時刻 GM名 タイトル` で全件縦表示し、`+n件` 圧縮は採用しない。
- `status: closed` は `〆 時刻 GM名 タイトル` 形式で表示する。
- `gmName` はJS側で接頭辞を足さず、データ値をそのまま表示する。
- `募集中` / `満席` の強い状態バッジは出さない。
- 選択日詳細エリアに、選択日の予定カードと予定なし空表示を追加済み。
- カレンダー拡張 Phase 1-B として、セッション詳細モーダルは実装済み。
- 選択日予定カードの「詳細を見る」と、カレンダーセル内予定行クリック / タップから詳細モーダルを開ける。
- DiscordリンクはPL向けUIから削除済み。現行 `data/sessions.json` には実Discord IDが含まれるため注意対象とし、将来Supabaseへ移行する場合は `profiles.discord_user_id` などの非公開列へ移す。
- 詳細モーダルのフッター重なり・黒い領域隠れは修正済み。
- カレンダー拡張 Phase 1-C として、`assets/js/sessionDisplay.js` にセッション表示・詳細表示の整形ロジックを共通化済み。
- カレンダー拡張 Phase 1-D として、セッション詳細表示の表示順をPL向けに整理済み。M-11A follow-up後は、session-detailでは基本情報、概要、補足情報、参加希望コメントの順で表示し、自由タグは表示しない。
- M-13Aとして、`data/sessions.json` に固定分類 `sessionType` を追加済み。既存7件は `one-shot` とし、`session-detail.html` と `calendar.html` の選択日セッション一覧に `単発シナリオ` と表示する。
- M-13Bとして、`data/sessions.json` に参加申請締切 `applicationDeadline` を追加済み。既存7件は開催日前日 `23:59` で統一し、`session-detail.html` と `calendar.html` の選択日セッション一覧に `申請締切` と表示する。
- PL向け詳細では関連スポットID、シナリオID、公開範囲を表示せず、補足情報は状態と更新日時中心に整理済み。
- `updatedAt` は日付＋時刻表示に対応済み。日付のみの場合も表示が壊れない。
- カレンダー拡張 Phase 1-E として、`session-detail.html?id=<session.id>` のセッション詳細ページを追加済み。
- `assets/js/renderSessionDetail.js` を追加し、`data/sessions.json` から該当セッションを取得して `renderSessionDetailContent(session, { mode: "page" })` で描画する。
- カレンダーセル内予定行クリック / タップ、選択日予定カードの「詳細を見る」は `session-detail.html?id=<session.id>` へ遷移する。
- `calendar.html?date=YYYY-MM-DD` に対応し、日付選択時はURLクエリと `localStorage` キー `velgard.calendar.selectedDate` を更新する。
- ブラウザ更新後、クエリなし表示、不正クエリ時も、保存済み日付または今日へ自然にフォールバックする。
- `session-detail.html` の「カレンダーへ戻る」は `calendar.html?date=<session.date>` へ戻る。
- カレンダー拡張 Phase 2-A として、`session-detail.html` に参加希望コメント型の静的UIモックを追加済み。
- 通常予定では disabled のテンプレート選択、textarea、`コメント投稿（準備中）` を表示し、旧 `参加申請する（準備中）` は表示しない。
- `closed` 予定では `募集締切` 表示にし、新規参加希望コメントを受け付けない旨を表示する。
- `finished` / `canceled` では終了・中止メッセージのみ表示し、投稿UIを出さない。
- コメント申請型では、参加人数はコメント件数ではなく申請者単位で管理する方針。将来 `userId` / `discordUserId` / 認証ユーザーIDなどで重複排除する。
- 複数コメントは補足、修正、相談として扱い、同一ユーザーを複数人分として数えない想定。
- 月表示カレンダー、日付換算、季節、月齢、レベルキャップ表示に対応済み。
- 月表示カレンダー上で、`levelCaps[].startDate` に一致する日付に `3Lv開始` などの開始バッジを表示済み。
- 選択日詳細カードにも、レベルキャップ開始日のみ節目表示を出す。
- 開催期間外ではラクシア日付、季節、月齢、Lv数値を表示しない仕様。
- ラクシア年切り替わりは3月1日起点。
- ラクシア暦の月順は 3月〜2月。
- ラクシア運用カレンダーは390px幅確認済み。
- ラクシア運用カレンダー Phase 1 / Phase 1-A / Phase 1-B / Phase 1-C / Phase 1-D / Phase 1-E / Phase 2-A は読み取り専用・静的モック、表示整理、詳細ページ導入、日付保持、参加希望コメント準備表示で、予定登録、編集、実コメント投稿、コメント保存、コメント編集、申請用テンプレート保存、参加人数自動再計算、〆ボタン実処理、参加申請停止処理、認証、外部DB/API、Discord連携は将来フェーズ。
- README / QA は現状反映済み。
- 配布シナリオ本文作成は後回し。ユーザーが本文・PDF・配布ファイルを渡してから反映する。
- 直近バックアップは `velgard-site_backup_2026-05-29_session-comment-ui-mock-complete`。

## 2. すぐやる候補

### 日付整理方針の確認

- 途中まで 2026-05-24 の更新日・バックアップ名が使われていた。
- 2026-05-28 以降は日付を修正済み。
- 過去の 2026-05-24 記録を修正するか、履歴として残すかを別工程で判断する。

### 日付運用方針

- 過去の `updates.json` 日付やバックアップ名に含まれる 2026-05-24 は、原則として履歴として残す。
- 既存バックアップフォルダ名も、追跡性を優先して原則そのまま残す。
- 今後の新規 `updates.json` 追記日付は、その作業時点の実日付を使う。
- 今後の新規バックアップ名も、その作業時点の実日付を使う。
- 日付整理そのものを目的とした大規模修正は、現時点では行わない。
- 必要になった場合のみ、別工程で日付監査を行う。

### 公開前総点検 v2

- 全HTML HTTP 200。
- `data/*.json` parse。
- `assets/js/*.js` syntax。
- 画像参照欠損。
- `undefined` / `null` / `[]` の画面露出。
- 禁止旧表記・旧ID。
- PC実ブラウザ確認 v1 は概ね問題なし。主要ページ、主要モーダル、主要ナビ導線、SCENARIOS導線、galleryカテゴリ、spot-detail関連導線、raw ID / undefined / null / [] の目立つ露出なしを確認済み。
- PC実ブラウザでの主要モーダル実操作はv1確認済み。
- responsive UI修正として、galleryモーダルの横長画像上寄り・黒余白問題は修正済み。
- responsive UI修正として、world目次クリック後に該当章から目次側へ戻される問題は修正済み。
- 上記2件は DevTools 390px幅でユーザー確認済み。キャッシュ対策は `v=20260528-responsive-ui-fix`。
- gallery検索機能は実装済み。title / description / カテゴリ表示名 / id を対象に検索でき、カテゴリフィルターと併用可能。
- gallery検索UIの390px幅余白は修正済み。キャッシュ対策は `v=20260528-gallery-search` / `v=20260528-gallery-search-layout`。
- gallery画像モーダルの左右スワイプ操作は実装済み。モーダル表示中のみ、左スワイプで次へ、右スワイプで前へ移動し、既存の `moveModal()` と現在表示中リストを再利用する。キャッシュ対策は `v=20260529-gallery-swipe`。
- トップキービジュアルの390px幅横はみ出しと、PC幅・スマホ幅の上下余白は修正済み。キャッシュ対策は `v=20260528-home-keyvisual-overflow-fix` / `v=20260528-home-keyvisual-fit-fix`。
- gallery検索UIとトップキービジュアル表示調整は DevTools 390px幅でユーザー確認済み。
- ランダム表ツールは実装済み。実本文データ反映後、390px幅を含めてユーザー実ブラウザ確認済み。
- 全ページ共通の「ページ上部へ戻る」ボタンは実装済み。スクロール後表示、同一ページ最上部へ戻る仕様、モーダル干渉対策、390px幅確認済み。
- シナリオ本文・PDF受け入れ基盤は実装済み。`scenario-detail.html` の配布情報セクション、`textUrl` がある場合のTXTリンクとページ内本文表示欄、`pdfUrl` がある場合のPDFリンク、一覧カードの準備中 / 配布中 / 旧版バッジに対応済み。キャッシュ対策は `v=20260529-scenario-release-base`。
- ラクシア運用カレンダー Phase 1 は実装済み。`calendar.html`、`calendarConfig.json`、月表示カレンダー、期間外表示、3月1日起点のラクシア年切り替わり、レベルキャップ開始日バッジに対応済み。Phase 1-A として `sessions.json` による静的予定表示モックを追加し、Phase 1-B〜1-D としてセッション詳細モーダル、予定行クリック導線、表示ロジック共通化、PL向け詳細表示整理に対応済み。Phase 1-E として `session-detail.html` と日付保持を追加済み。Phase 2-A として参加希望コメント型の静的UIモックを追加済み。キャッシュ対策は `v=20260529-calendar-cap-start` / `v=20260529-calendar-session-detail-polish` / `v=20260529-calendar-date-tools-history` / `v=20260529-session-comment-ui-mock`。
- 公開前軽微UI改善バッチは完了済み。TOOLS選択UI見切れ緩和、履歴まとめコピー、履歴全件表示、regulation右側目次見切れ調整、spot-detail関連キャラクター遷移修正に対応済み。キャッシュ対策は `v=20260529-ui-polish` / `v=20260529-tools-history-full`。
- 公開後軽微UI改善バッチ2は完了済み。WORLD本文小見出し余白、TOPキービジュアル拡大、大画面時の共通最大幅、長文記事系ページの可読幅保護を調整済み。CSSキャッシュ対策は `v=20260529-home-wide-layout`。
- 幅設定は `--home-max: 1600px`、`--max: 1360px`、`--article-max: 1240px`。
- スマホ実機確認は未実施。正式公開後または外部確認可能URL発行後に実施する。
- 必要に応じて、公開前の暫定確認としてブラウザDevToolsのレスポンシブ表示確認を行う。
- ナビ導線確認。

### 正式公開URL / OGP / publicUrl 反映状況

- 正式公開URLは `https://suisui334.github.io/velgard-site/`。
- `data/site.json` の `publicUrl` は正式公開URLへ設定済み。
- 全HTMLの `og:url` は正式公開URLへ差し替え済み。
- 全HTMLの `og:image` は `https://suisui334.github.io/velgard-site/assets/images/common/ogp-main-1200x630.png` へ絶対URL化済み。
- 公開後確認は `docs/release-runbook.md` に従って行う。
- OGP / favicon軽量版参照切替は完了済み。
- 現在HTMLのOGP参照は `assets/images/common/ogp-main-1200x630.png`。
- `data/site.json` のmeta画像パスもHTML参照方針に合わせ、軽量版OGP / favicon / apple-touch-iconへ整合済み。
- faviconは `assets/images/common/favicon-32.png` / `assets/images/common/favicon-192.png`、apple-touch-iconは `assets/images/common/apple-touch-icon.png` を参照。
- 元画像 `assets/images/common/ogp-main.png` / `assets/images/common/favicon.png` は原本として維持。
- Discord等でのOGP表示確認は残タスク。
- スマホ実機確認は公開後または外部確認可能URL発行後に実施する。
- 必要に応じて公開後キャッシュ確認を行う。
- X / Twitterカード系metaは不要方針。

## 3. シナリオファイル受け入れ後にやること

現時点では配布シナリオ本文をこちらで作らない。ユーザーがシナリオ本文、PDF、配布ファイルを渡した後に、`docs/scenario-file-policy.md` の方針に沿って検討・実装する。

- 初期方針は TXT正本 / PDF任意 / HTML将来対応。
- `.txt` はユーザー提供のシナリオ本文原本として扱う。
- PDFは任意の整形版として追加できる。
- HTML本文表示は将来対応とする。
- 配布ファイル配置先は `assets/scenarios/<scenario-id>/` を推奨する。
- 本文受領後に `assets/scenarios/<scenario-id>/` へ配置し、`scenarios.json` の `textUrl` / `pdfUrl` を更新する。
- シナリオ本文公開前には、秘匿情報、敵データ、GM向け情報、結末などの公開可否を確認する。
- 今後の手順は、本文受領 → `assets/scenarios/<scenario-id>/` 配置 → `scenarios.json` 更新 → 表示確認 → README / QA / task-backlog / updates 反映 → バックアップ。
- Codex / ChatGPT は、ユーザーの依頼なしに配布シナリオ本文を自動作成しない。
- 詳細な受け入れ手順、追加フィールド、命名規則、禁止事項は `docs/scenario-file-policy.md` を参照する。

## 4. 後回しでよい便利機能

### gallery追加操作

- 左右スワイプ操作は実装済み。
- スマホ・タブレット向けに、gallery画像モーダル表示中のみ左スワイプで次へ、右スワイプで前へ移動する。
- 既存の `moveModal()` を再利用し、検索・カテゴリ絞り込み後の表示リスト内で移動する。
- 今後の追加ジェスチャーや高度なタッチ操作は必要に応じて後回しでよい。

### maps専用ページ

- 地図画像が増えた場合に有効。

### facilities専用ページ

- 施設系画像や施設説明が増えた場合に検討。

### characters詳細ページ

- 現状は作らない方針。
- 画像拡大モーダルで対応中。
- `characters.json` の `relatedHooks` を将来活かす場合に再検討。

### campaign / episode 周りの整理

- 既存ページの破綻確認は必要。
- 大改修は後回し。

### editor.html 等の編集者ページ

- 今は後回し。
- データ構造が固まりきる前に作ると保守負担が増える。

### ランダム表ツール

- 実装済み。
- `tools.html` 追加済み。
- TOP左側導線追加済み。
- `data/randomTables.json` に実本文データ反映済み。
- TDA自動分岐対応済み。
- アビス浸蝕表2D6対応済み。
- 結果コピー機能追加済み。
- 履歴別コピー機能追加済み。
- 履歴まとめコピー機能追加済み。
- 履歴表示上限は撤廃済み。同一ページ表示中に振った結果を全件表示する。
- 履歴は新しい順表示を維持。
- `localStorage` キー `velgard.tools.rollHistory` で履歴を保存し、ページリロード後も復元する。
- `履歴をすべて削除` ボタンで画面上の履歴と `localStorage` 履歴を削除できる。
- `localStorage` 破損時は空履歴へフォールバックする。
- 表選択UIの見切れは標準selectのまま緩和済み。
- 390px幅確認済み。
- 今後の拡張候補として、表追加、クラウド同期、アカウント別履歴管理、カスタムselect化、スマホ向け追加操作などは必要に応じて後回し。

### ページ上部へ戻るボタン

- 実装済み。
- 全ページ共通で表示。
- スクロール後に表示し、同一ページの最上部へ戻る。
- モーダル干渉対策済み。
- 390px幅確認済み。
- 完了済み扱い。

### ラクシア運用カレンダー

- Phase 1 は実装済み。
- `calendar.html` 追加済み。
- `data/calendarConfig.json` 追加済み。
- Phase 1-A の静的セッション予定モックUIは実装済み。
- `data/sessions.json` 追加済み。
- 仮データは7件で、`recruiting` / `full` / `tentative` / `finished` / `canceled` / `closed` を含む。
- `2026-06-08` には3件の同日複数予定を配置済み。
- 月表示カレンダー追加済み。
- 現実日付からラクシア日付範囲、季節、月齢、レベルキャップを表示できる。
- レベルキャップ開始日は、月表示カレンダー上で `3Lv開始` などの開始バッジ表示に対応済み。
- 選択日詳細カードにも開始日のみ節目表示を出す。
- カレンダーセルでは予定を `時刻 GM名 タイトル` で全件縦表示し、`+n件` 圧縮は行わない。
- `closed` は `〆 時刻 GM名 タイトル` 形式で表示する。
- `gmName` はJS側で接頭辞を足さず、データ値をそのまま表示する。
- `募集中` / `満席` は強いバッジ表示にしない。
- 選択日詳細エリアに予定カードを表示し、予定がない日は空表示を出す。
- Phase 1-B のセッション詳細モーダルは実装済み。
- カレンダーセル内予定行クリック / タップ、または選択日予定カードの「詳細を見る」から詳細モーダルを開ける。
- Phase 1-C として `assets/js/sessionDisplay.js` を追加し、セッション表示・詳細表示の整形ロジックを共通化済み。
- Phase 1-D としてセッション詳細表示の情報設計をPL向けに整理済み。
- セッション詳細表示は、基本情報、概要、補足情報、参加希望コメントの順で表示する。`鉄道` / `調査` のような自由タグはsession-detailでは表示しない。
- PL向け詳細では関連スポットID、シナリオID、公開範囲を表示せず、補足情報は状態と更新日時中心に整理する。
- Phase 2-A として、参加希望コメント型の静的UIモックを追加済み。通常予定では disabled のテンプレート選択、textarea、`コメント投稿（準備中）` を表示し、`closed` 予定では `募集締切` 表示にする。
- コメント申請型では、参加人数はコメント件数ではなく申請者単位で管理する方針。
- DiscordリンクはPL向けUIから削除済み。`discordThreadUrl` は将来のbot/Webhook同期用データとして残す。
- 参加希望コメント、申請管理、GM編集、〆ボタン、Discord同期に向けたSupabaseプロトタイプ設計方針は `docs/supabase-prototype-plan.md` に分離済み。実Supabase登録、SQL実行、本番接続は未実施。
- Supabaseプロトタイプを実操作する直前の判断基準・作業順・RLSテスト手順は `docs/supabase-prototype-runbook.md` に分離済み。
- Supabase Freeプロトタイプ Step 0〜2 準備パックは `docs/supabase-step0-2-preflight.md`、`docs/supabase-rls-test-matrix.md`、`docs/supabase/sql/` に分離済み。参加希望コメントは公開申請欄に近い扱いだが表示用RPC/viewではDiscord IDや内部user_idを出さず、private / hidden コメントは漏洩防止、`full` sessionは新規申請不可の方針へ整理済み。実行候補SQL草案であり、SQL実行・APIキー発行・本番接続は未実施。
- Supabase Step 4 SQL実行前の段階実行計画は `docs/supabase-step4-sql-execution-plan.md`、Step 5 RLSテスト準備計画は `docs/supabase-step5-rls-test-plan.md` に分離済み。Step 5のseed / query草案は `docs/supabase/sql/005_rls_test_seed_draft.sql` と `docs/supabase/sql/006_rls_test_queries_draft.sql` に置き、実UUID・実メール・実Discord ID・secret類は入れない方針。
- Supabase Step 6 Authテストユーザー作成手順とseed投入前チェックは `docs/supabase-step6-auth-test-users.md` に分離済み。UUIDはSQL Editor内でのみ一時置換し、置換済みseed SQLは保存・commitしない方針。
- Supabase Step 9 Auth文脈RLSテスト手順は `docs/supabase-step9-auth-context-test-plan.md` に分離済み。ローカル検証スクリプト方式を推奨し、`.env.local` はGit管理せず、service role keyは使わない方針。
- Supabase Step 10 ローカルAuth文脈RLSスモークテスト手順は `docs/supabase-step10-local-auth-smoke-test.md`、検証スクリプトは `scripts/supabase-rls-smoke-test.mjs` に分離済み。本番サイトへ組み込まず、`.env.local` の実値はGit管理しない方針。
- Supabase Step 11 RLS smoke test FAIL修正計画は `docs/supabase-step11-rls-smoke-fix-plan.md`、GRANT修正SQL草案は `docs/supabase/sql/007_rls_smoke_fix_grants_draft.sql` に分離済み。まだ追加SQL実行・本番接続は行わない。
- Supabase Auth文脈RLSスモークテスト結果は `docs/supabase-rls-smoke-test-result.md` に整理済み。007 grant fix後の結果は `PASS 19 / FAIL 0 / SKIP 1` で、`AUTH-018` は破壊的close成功系のため意図的SKIP。
- Supabase本番接続前の停止条件と確認事項は `docs/supabase-production-connection-checklist.md` に分離済み。次工程は本番ページ接続ではなく、Supabaseフロント連携設計を先に固める方針。
- Supabaseフロント連携設計は `docs/supabase-frontend-integration-plan.md` に分離済み。当面は `data/sessions.json` を正本のまま維持し、Supabaseは参加希望コメント・申請状態まわりから読み取り専用プロトタイプで段階確認する方針。
- Supabase F-1 ローカル読み取り専用プロトタイプは `docs/supabase-f1-readonly-prototype.md` と `dev/supabase-readonly-prototype.html` / `dev/supabase-readonly-prototype.js` に分離済み。本番ページへ接続せず、接続値は手入力で保存しない。
- Supabase F-2 公開セッション読み取りプロトタイプ設計は `docs/supabase-f2-public-session-read-plan.md` に分離済み。Supabase `sessions` のsnake_caseを既存 `sessionDisplay.js` 用camelCaseへ変換し、まず `dev/` 配下で表示互換性を確認する方針。
- Supabase F-2 dev セッション表示マッピングプロトタイプは `docs/supabase-f2-session-mapping-prototype.md` と `dev/supabase-session-mapping-prototype.html` / `dev/supabase-session-mapping-prototype.js` に分離済み。public sessionsを読み取り、`accepted_count` を `playerCount` 相当に補完して既存 `sessionDisplay.js` プレビューで確認する。
- Supabase F-3 dev ログイン状態表示プロトタイプは `docs/supabase-f3-auth-state-prototype.md` と `dev/supabase-auth-state-prototype.html` / `dev/supabase-auth-state-prototype.js` に分離済み。Authログイン状態、ログアウト、再読込後のセッション復元、`public_profiles.display_name` 取得をdev専用で確認する。
- Supabase F-4 dev 参加希望コメント投稿プロトタイプは `docs/supabase-f4-application-comment-prototype.md` と `dev/supabase-application-comment-prototype.html` / `dev/supabase-application-comment-prototype.js` に分離済み。prototype DBのテストsessionに `create_application_comment` を呼ぶが、本番ページへ接続せずGM操作は扱わない。
- Supabase F-5 GM承認・却下プロトタイプ設計は `docs/supabase-f5-gm-application-management-plan.md` に分離済み。対象RPCは `set_application_status` のみとし、`close_session` や本番ページ統合は別工程にする方針。
- Supabase F-5 dev GM承認・却下プロトタイプは `docs/supabase-f5-gm-application-management-prototype.md` と `dev/supabase-gm-application-management-prototype.html` / `dev/supabase-gm-application-management-prototype.js` に分離済み。ユーザー実ブラウザ確認済みで、`set_application_status` による `accepted` / `rejected` 変更を確認した。本番UXは専用GM一覧ページではなく、`session-detail.html` の参加希望コメント欄へGM操作を統合する方針。
- Supabase次工程候補: F-5 dev prototype commit / push、コメント編集・削除・申請取消RPC設計、`session-detail.html` 統合前の本番UX設計。
- Supabase F-6 コメント編集・削除・申請取消RPC設計は `docs/supabase-f6-comment-edit-delete-application-cancel-plan.md` に分離済み。次工程候補はF-6 RPC SQL草案、RLS smoke testケース追加、dev編集・削除プロトタイプ。
- Supabase F-6 SQL草案は `docs/supabase/sql/008_comment_management_rpc_draft.sql` に分離済み。次工程候補はcommit / push後、RLS smoke testケース追加とdev編集・削除プロトタイプ。
- Supabase F-6 SQL実行前レビュー計画は `docs/supabase-f6-sql-execution-review-plan.md` に分離済み。次工程候補はcommit / push後、F-6 SQL実行判断、SQL Editor実行、RLS smoke test更新、dev編集・削除プロトタイプ。
- Supabase F-6 SQL実行結果は `docs/supabase-f6-sql-execution-result.md` に分離済み。次工程候補はF-6 RLS smoke test更新、Auth文脈での編集・削除・取消テスト、dev編集・削除プロトタイプ、`session-detail.html` 統合前UX設計。
- Supabase F-6 RLS smoke test更新計画は `docs/supabase-f6-rls-smoke-test-update-plan.md` に分離済み。次工程候補はスクリプト実装、Auth文脈でのF-6追加テスト実行、テスト結果docs記録。
- Supabase F-6 RLS smoke testスクリプト更新は `scripts/supabase-rls-smoke-test.mjs` に反映済み。通常実行は `PASS 29 / FAIL 0 / SKIP 10`。次工程候補はcommit / push後、F-6 devコメント編集・削除プロトタイプ、または破壊的テスト専用fixture設計。
- Supabase F-6 devコメント編集・削除プロトタイプ設計は `docs/supabase-f6-comment-edit-delete-prototype-plan.md` に分離済み。次工程候補はcommit / push後、dev配下の実装とユーザー実ブラウザ確認。
- Supabase F-6 devコメント編集・削除プロトタイプは `docs/supabase-f6-comment-edit-delete-prototype.md` と `dev/supabase-comment-edit-delete-prototype.html` / `dev/supabase-comment-edit-delete-prototype.js` に分離済み。次工程候補はユーザー実ブラウザ確認、確認結果docs記録、`session-detail.html` 統合前UX設計。
- 詳細モーダルのフッター重なり・黒い領域隠れは修正済み。
- 開催期間外ではラクシア日付、季節、月齢、Lv数値を表示しない。
- ラクシア年切り替わりは3月1日起点。
- 390px幅確認済み。
- Phase 1 / Phase 1-A / Phase 1-B / Phase 1-C / Phase 1-D / Phase 1-E / Phase 2-A は読み取り専用・静的モック、表示整理、詳細ページ導入、日付保持、参加希望コメント準備表示。
- セッション本番データ登録、予定登録、編集、〆ボタン実処理、参加申請停止処理、実コメント投稿、コメント保存、コメント編集、申請用テンプレート保存、参加人数自動再計算、アカウント、外部DB/API、Discord連携は将来フェーズ。

## 5. 互換維持として残すもの

- `hooks.html`
  - 既存リンク互換入口として維持。
  - 正式導線は `scenarios.html`。
- `data/hooks.json`
  - 互換・比較用として維持。
- `gallery-hook-*` ID
  - 現時点では改名しない。
- `assets/images/hooks/`
  - 現時点では移動しない。
- `characters.json` の `relatedHooks`
  - `spotDetails.json` の `relatedHookIds` とは別スキーマ。
  - 今は削除しない。

## 6. 今は触らない方がよいもの

- `gallery-hook-*` ID改名。
- `assets/images/hooks/` の `assets/images/scenarios/` への移動。
- `characters.json` の `relatedHooks` 削除。
- `hooks.html` 削除。
- `data/hooks.json` 削除。
- 配布シナリオ本文未作成のまま hooks系全面撤去。
- シナリオ本文の自動作成（行わない）。

## 7. 将来判断が必要なもの

- 過去の 2026-05-24 更新日・バックアップ名を整理するか。
- 日付監査が必要になった場合、監査対象と修正範囲を事前に決める。
- `hooks.html` を互換入口のまま残すか、将来案内ページ化するか。
- `data/hooks.json` をいつまで残すか。
- `gallery-hook-*` IDを将来 `gallery-scenario-*` へ改名するか。
- `assets/images/hooks/` を将来 `assets/images/scenarios/` へ移すか。
- OGP軽量版PNGとfavicon軽量版で公開上問題ないか。
- 正式公開URL反映後のDiscord OGP確認とスマホ実機確認。

## Supabase F-7 session-detail統合前UX設計

- `docs/supabase-f7-session-detail-integration-ux-plan.md` に、参加希望コメント機能を本番 `session-detail.html` へ統合する前のUX方針を分離済み。
- 次工程候補: F-7 UX設計書 commit / push、ログイン状態表示のみの統合設計、公開コメント読み取り統合計画、GM用コメント一覧RPC / view要否判断、rollback手順整理。

## Supabase F-7a session-detailログイン状態表示 仮統合計画

- `docs/supabase-f7a-session-detail-auth-state-plan.md` に、ログイン中 / 未ログイン / `public_profiles.display_name` 表示だけを扱う仮統合計画を分離済み。
- 次工程候補: F-7a計画 commit / push、Supabase接続情報の公開方針最終確認、ログイン状態表示のみの本番仮統合判断。
- F-7a最小実装のローカル確認で本文中ログイン状態表示の安全フォールバックは確認済み。ただし本番UXでは `session-detail.html` 本文中の常時表示を採用せず、サイト共通ヘッダー付近のアカウントアイコン / マイページ導線として再設計する方針に変更。

## Supabase 共通アカウント導線 / マイページUX設計

- `docs/supabase-account-nav-mypage-ux-plan.md` に、共通ヘッダーのアカウントアイコン、マイページ最小構成、ログイン / ログアウト導線、Supabase接続情報の扱いを整理済み。
- 次工程候補: 設計書 commit / push、ヘッダー静的アカウントアイコン追加計画、`mypage.html` 最小版設計、Supabase接続情報の公開方針最終確認。

## Supabase A-2 共通ヘッダー静的アカウントアイコン実装計画

- `docs/supabase-account-nav-static-icon-implementation-plan.md` に、静的アカウントアイコンだけを共通ヘッダーへ追加する前の対象ページ、配置、リンク先、CSS/JS方針、ロールバックを整理済み。
- 次工程候補: A-2計画 commit / push、A-2静的アイコン実装判断、`mypage.html` 未作成時のリンク扱い最終確認。

## Supabase A-3 mypage.html最小版 実装計画

- `docs/supabase-mypage-minimal-implementation-plan.md` に、共通アカウントアイコンのリンク先404を避けるための `mypage.html` 最小版計画を整理済み。
- 次工程候補: A-3計画 commit / push、`mypage.html` 最小版実装判断、`renderMypage.js` 要否確認、A-2静的アイコン実装。
- `mypage.html` 最小版と `assets/js/renderMypage.js` を静的な準備中ページとして追加済み。Supabase接続、Auth復元、ログイン / ログアウト、申請一覧表示は未実装のまま。
- 次工程候補: A-3最小版 commit / push、A-2静的アカウントアイコン実装、A-4接続設定未構成時フォールバック計画。

## Supabase A-2 共通ヘッダー静的アカウント導線 実装

- 共通ヘッダーのナビ末尾に、`mypage.html` へ遷移する静的な `ACCOUNT` 導線を追加済み。CALENDAR右側に同一行で収まるよう、activeなしの控えめなテキスト導線へ調整済み。共通ヘッダー変更を各ページで確実に反映するため、HTML構造は変えず `main.js` / `style.css` cache-bust queryのみ更新済み。Supabase接続、Auth復元、ログイン / ログアウト、申請一覧表示は未実装のまま。
- 次工程候補: A-2静的導線 commit / push、A-4接続設定未構成時フォールバック計画、A-5 Authセッション復元表示計画。

## Supabase A-4 mypage Auth状態表示 実装計画
- `docs/supabase-mypage-auth-state-implementation-plan.md` に、`mypage.html` でログイン中 / 未ログイン / `display_name` / 接続設定未構成フォールバックを扱う前の実装範囲、接続情報の扱い、UI配置、ロールバックを整理済み。
- 次工程候補: A-4計画 commit / push、A-4a接続設定未構成フォールバック実装、A-4b Authセッション復元表示実装判断。

## Supabase A-4a mypage Auth状態表示 方針修正
- `mypage.html` にログイン状態カードだけを常時表示する案は、ユーザー確認後のUX方針として採用しない。A-3最小版の静的準備中ページへ戻し、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、`display_name` 取得は未実装のまま。
- 次工程候補: A-4a方針修正 commit / push、マイページ全体のアカウント操作UX再設計、ログイン / ログアウトと申請一覧を含む段階計画の再整理。

## Supabase マイページ アカウント操作UX再設計
- `docs/supabase-mypage-account-actions-ux-plan.md` に、ログイン状態だけの常時カードではなく、ログイン / ログアウト、申請状況、参加予定などを一体で扱うマイページUXを整理済み。
- 次工程候補: 再設計書 commit / push、M-2接続設定未構成時フォールバック、M-3 runtime config分離、M-4 Authセッション復元。

## Supabase M-2/M-3 mypage runtime config / 未構成フォールバック計画
- `docs/supabase-mypage-runtime-config-fallback-plan.md` に、Supabase Auth実装前のruntime config候補、Git管理するもの / しないもの、接続設定未構成時の安全フォールバックUXを整理済み。
- 次工程候補: M-2/M-3計画 commit / push、未構成フォールバック最小実装、runtime config example作成判断。
- M-2/M-3最小実装として、実値なしの `assets/js/supabaseRuntimeConfig.example.js` と、`mypage.html` 内のアカウント操作セクションの未構成フォールバックを追加済み。Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、申請一覧表示は未実装。

## Supabase M-4 mypage runtime config 実接続前レビュー計画
- `docs/supabase-mypage-runtime-config-deployment-review-plan.md` に、GitHub Pages静的運用での実config候補、公開可能keyの扱い、接続前チェックリスト、エラー・ログ方針、ロールバック方針を整理済み。
- 次工程候補: M-4計画 commit / push、実config運用方針のユーザー最終判断、未構成フォールバック維持またはAuth client初期化計画。

## Supabase M-5前 mypage Auth実接続採否判断
- `docs/supabase-mypage-auth-connection-decision.md` に、Supabase Auth実接続へ進む前の採否判断材料、publishable key / anon keyのrepo公開運用、接続前チェックリスト、現時点の推奨を整理済み。
- M-5前時点では短期未構成フォールバック維持を安全策として記録。その後、ユーザー方針を受けて、M-5計画ではpublishable key / anon keyを公開前提で扱いSupabase Auth実接続へ進む方向へ更新済み。

## Supabase mypage Auth実接続保留
- `docs/supabase-mypage-auth-connection-hold-note.md` に、Supabase実接続へまだ進まず、未構成フォールバック維持とする現状を整理済み。
- ACCOUNT導線、`mypage.html` 最小版、runtime config example、未構成フォールバックは安定状態として記録済み。現在は、実接続時に問題が出た場合のロールバック / 保留案として残す。

## Supabase M-5 mypage Auth client初期化・Auth復元 実装計画
- `docs/supabase-mypage-auth-client-restore-plan.md` に、`mypage.html` でAuth client初期化と `auth.getSession` による既存セッション復元へ進む前の実装範囲、runtime config候補、UI、エラー表示、ロールバック、接続前チェックを整理済み。
- M-5計画書では、ユーザー判断としてpublishable key / anon keyを公開前提で扱い、Supabase Auth実接続へ進む方向を整理済み。この工程では実値投入、実config作成、接続実装は行っていない。

## Supabase M-5 mypage Auth client初期化・Auth復元 最終確認
- `docs/supabase-mypage-auth-client-restore-final-check.md` に、M-5実装直前のAuth client初期化方式、`assets/js/supabaseRuntimeConfig.js` 実config運用、M-5で扱う範囲、UI / エラー表示、実装後確認手順、ロールバック方針を整理済み。
- 次工程候補: 最終確認メモ commit / push、ユーザー確認後にM-5実装可否判断。実装する場合もAuth client初期化と `auth.getSession` による既存セッション復元だけに限定する。

## Supabase M-5 mypage Auth client初期化・Auth復元 最小実装
- M-5最小実装として、`assets/js/supabaseRuntimeConfig.js` の空placeholder、`assets/js/mypageAuthClient.js`、`mypage.html` のマイページ専用読み込みを追加済み。実Project URL / key実値は未投入で、config空欄時はSupabase SDKを読み込まず未構成フォールバックを維持する。
- `assets/js/renderMypage.js` のアカウント機能セクションは、未構成 / 未ログイン / ログイン状態確認 / 初期化失敗の短い状態表示に差し替えられる器だけを持つ。ログインフォーム、ログアウト、`display_name` 取得、自分の申請一覧、参加予定セッションは未実装。

## Supabase M-6 mypage ログイン / ログアウト最小実装 計画
- `docs/supabase-mypage-login-logout-plan.md` に、`mypage.html` のアカウント機能セクション内でメールアドレス + パスワードログイン、`signInWithPassword`、ログアウトボタン、`signOut` を扱う前の実装範囲、UI、安全条件、確認手順、ロールバック方針を整理済み。
- M-6計画では、ログイン状態カード単体へ戻さず、email / user_id / tokenを表示しない方針を維持する。`display_name` 取得、自分の申請一覧、参加予定セッション、`session-detail.html` 投稿統合、追加SQLはまだ扱わない。

## Supabase M-6 mypage ログイン / ログアウト最小実装
- M-6最小実装として、`mypage.html` 内のアカウント機能セクションにメールアドレス + パスワードログイン、`signInWithPassword`、ログアウトボタン、`signOut` を追加済み。
- `display_name` / `public_profiles` 取得、自分の申請一覧、参加予定セッションは未実装のまま。ログイン後もemail / user_id / tokenは画面に出さない。

## Supabase M-7 mypage 一般サインアップ実装 計画
- `docs/supabase-mypage-signup-plan.md` に、サイト上に誰でも登録できる一般サインアップフォームを置く前の仕様、UI、Supabase設定確認、安全条件、確認手順、ロールバック方針を整理済み。
- M-7計画では、メールアドレス + パスワード + パスワード確認、`signUp`、登録成功時の短い案内、ログインフォームとの切り替えを候補にする。`display_name` / `public_profiles` 登録、自分の申請一覧、参加予定セッション、`session-detail.html` 統合、追加SQLはまだ扱わない。

## Supabase M-7 mypage 一般サインアップ最小実装
- M-7一般サインアップとして、`mypage.html` 内でログイン / 新規登録を切り替え、Supabase Auth `signUp` で登録できる最小UIを追加済み。
- `display_name` 登録、`profiles` / `public_profiles` 書き込み、自分の申請一覧、参加予定セッションは未実装のまま。登録後もemail / user_id / tokenは画面に出さない。

## Supabase M-8 mypage パスワード再設定 / 変更最小実装
- M-8アカウント補助導線として、未ログイン時の「パスワードを忘れた方はこちら」から再設定メール送信フォームへ切り替え、ログイン済み時の「パスワードを変更する」から新しいパスワード変更フォームへ切り替える最小UIを追加済み。
- 再設定メール送信はメールアドレスの存在有無を断定しない短い案内に限定し、登録済み可能性の案内も「すでに登録済み」の断定表示にはしない。`display_name` 登録、プロフィール書き込み、自分の申請一覧、参加予定セッション、`session-detail.html` 統合は未実装のまま。email / user_id / tokenは画面に出さない。

## Supabase M-9 mypage display_name SQL草案
- `docs/supabase-mypage-display-name-sql-plan.md` と `docs/supabase/sql/009_profiles_display_name_rpc_draft.sql` に、`profiles` 自動作成trigger、既存ユーザーbackfill、`update_display_name` RPC、`public_profiles` 最小公開確認の草案を分離済み。
- この工程ではSQL Editor実行、`mypage.html` 変更、`assets/js/mypageAuthClient.js` 変更、表示名フォーム実装、自分の申請一覧、参加予定セッション、`session-detail.html` 統合は行わない。

## Supabase M-9 mypage display_name SQL実行前レビュー計画
- `docs/supabase-mypage-display-name-sql-execution-review-plan.md` に、009草案をSQL Editorで実行する前の実行範囲、事前確認SQL、trigger / backfill / RPC確認点、実行順序、ロールバック、実行後検証、RLS smoke test更新要否を分離済み。
- この工程でもSQL Editor実行、`mypage.html` 変更、`assets/js/mypageAuthClient.js` 変更、表示名フォーム実装、本番接続拡張は行わない。

## Supabase M-9 mypage display_name SQL反映結果
- `docs/supabase-mypage-display-name-sql-result.md` に、`handle_new_auth_user_profile` と `update_display_name(new_display_name text)` の存在、`update_display_name` の anon execute不可 / authenticated execute可、`public_profiles` が `id` / `display_name` のみ、`auth_users_without_profile = 0` を確認済みとして整理済み。
- `profiles` 自動作成trigger と `update_display_name` RPC は追加済みまたは既存反映済み扱いとし、M-9 SQLについて追加SQLはこれ以上実行しない。次工程は `mypage.html` のdisplay_name表示・編集フロント実装。

## Supabase M-9 mypage display_name フロント最小実装
- `mypage.html` のログイン済みアカウント機能内に、`public_profiles` から取得した `display_name` の表示と編集フォームを追加済み。
- 保存は `update_display_name` RPCで行い、空欄と40文字超は送信しない。email / user_id / tokenは画面に出さず、自分の申請一覧、参加予定セッション、`session-detail.html` 統合は未実装のまま。

## Supabase M-9 mypage display_name フロント修正
- 新規登録フォームに表示名欄を追加し、`signUp` のuser metadataへ `display_name` を渡すよう修正済み。
- 既存ユーザーは `update_display_name` RPCでマイページから表示名を保存する。email / user_id / tokenは画面に出さず、自分の申請一覧、参加予定セッション、`session-detail.html` 統合は未実装のまま。
- ログイン済み画面では現在の表示名を入力欄とは別DOMで表示し、取得反映が入力中の値を上書きしないようにした。保存成功後は現在表示名と入力欄を保存後の値へ更新する。

## Supabase M-9 mypage display_name RPC修正結果
- 表示名保存時の `42702 ambiguous_column` は、`update_display_name` RPC側で `public.profiles as p` と `returning p.id, p.display_name` を明示する修正により解消済み。
- 修正後、ユーザー実ブラウザで表示名保存、保存成功表示、表示名テキスト更新、入力欄更新、再読み込み後維持、再ログイン後維持、email / user_id / token非表示を確認済み。

## Supabase M-10 mypage 申請一覧・参加予定表示
- `mypage.html` のログイン済みアカウント機能内に、本人の「参加申請中」「参加予定」表示を追加済み。`pending` / `waitlisted` は参加申請中、`accepted` は参加予定、`rejected` / `canceled` は今回非表示。
- `session_applications` の本人行を `data/sessions.json` の公開セッションと `session_id` で突合し、タイトル、日付、開始時刻、GM表示名、セッション状態、申請ステータス、更新日時、公開詳細リンクを表示する。突合できない場合は内部IDを出さず「非公開または未同期のセッション」と表示する。
- `closed` / `finished` / `canceled` / `archived` の公開セッションは、`accepted` でも参加予定に出さない。DB/RPC正本の中止状態は `canceled` に統一する。email / user_id全文 / token / key / gmUserId / コメント本文 / 内部ID類は画面に出さない。
- RLS smoke testへM-10向けの読み取り観点を追加済み。M-10フロント実装時点ではSupabase SQL Editorを実行しておらず、公開版確認はユーザー実ブラウザ確認前だった。
- M-10 follow-up完了: DB側の `sessions.id` / `session_applications.session_id` と `data/sessions.json` の `sessions[].id` を一致させた検証データで、mypage の詳細リンク表示・遷移を確認済み。対象は `session-2026-06-08-railway-incident`。公開版 mypage で「灰壁線異常調査」、`詳細を見る`、`session-detail.html?id=session-2026-06-08-railway-incident` への遷移を確認済み。
- M-10 follow-up後の残タスク: 検証データのcleanup要否判断、`session-detail.html` 本番投稿統合前の設計確認、mypage申請一覧の履歴表示、GM操作統合。

## Supabase M-11 session-detail 参加希望コメント統合前 調査・設計
- `docs/supabase-session-detail-application-comments-integration-plan.md` に、`session-detail.html` の現状構造、既存RPC/RLSで使えるもの、不足点、M-11A〜M-11Fの段階分割、M-11Aの最小読み取り範囲、M-10 ID整合検証データの扱いを整理済み。
- M-11A完了: `session-detail.html` の参加希望コメント欄を読み取り専用表示へ更新済み。`get_public_session_comments` と `get_public_session_application_counts` を使い、公開コメント一覧と `申請中` / `承認済み` の公開カウントを表示する。`参加希望人数` と `キャンセル待ち` はM-11Aの画面には表示しない。投稿、編集、削除、GM承認・却下、DB変更、cleanup、`close_session` は扱っていない。実装結果は `docs/supabase-session-detail-application-comments-read-result.md` に整理済み。
- M-11A follow-upとして、`session-detail.html` の表示順を基本情報、概要、補足情報、参加希望コメントへ整理し、概要をカード状ブロック表示にした。自由タグはsession-detailでは表示しない。
- session-detail の申請締切表示は、M-13Bで `data/sessions.json` の `applicationDeadline` 明示フィールドとして追加済み。`startTime` / `endTime` は開催時刻であり、締切時間として流用しない。
- セッション種別は自由タグではなく、`data/sessions.json` の `sessionType` 明示フィールドで扱う。候補は `単発シナリオ`、`キャンペーン`、`特殊`、`その他`。M-13Aで既存7件へ `one-shot` を追加し、`session-detail` / `calendar` の一覧表示に反映済み。calendar の種別フィルターは将来拡張で扱う。
- M-11B実装前調査・設計完了: `docs/supabase-session-detail-application-comment-post-plan.md` に、`create_application_comment(target_session_id text, comment_body text)` の正確な仕様、既存申請状態ごとの挙動、投稿フォーム差し込み位置、ログイン状態取得、本人申請状態取得、バリデーション、投稿後再取得、エラー処理、RLS smoke test更新案を整理済み。この工程では投稿UI実装、RPC実呼び出し、SQL Editor実行、DB変更は行っていない。
- M-11B-1完了: `session-detail.html` の参加希望コメント欄に、ログイン状態取得、本人申請状態取得、未ログイン時のACCOUNT導線、ログイン済み時のdisabled投稿フォーム器、申請状態別案内を追加済み。`create_application_comment` は呼び出さず、投稿、編集、削除、GM操作、`close_session`、SQL実行、DB変更は扱っていない。実装結果は `docs/supabase-session-detail-application-comment-post-ui-result.md` に整理済み。
- M-11B-2完了: ログイン済みPLの参加希望コメント投稿を `create_application_comment` で統合済み。空欄 / 4000文字超過バリデーション、送信中の二重押し防止、成功後の公開コメント一覧・公開カウント・本人申請状態再取得、短い安全な成功 / 失敗表示を追加した。Codex側では投稿実行、SQL Editor実行、DB変更、編集・削除・GM操作、`close_session` は扱っていない。実装結果は `docs/supabase-session-detail-application-comment-post-result.md` に整理済み。
- M-11C実装前調査・設計完了: `docs/supabase-session-detail-application-comment-edit-delete-plan.md` に、`update_application_comment(target_comment_id uuid, comment_body text)`、`delete_application_comment_and_maybe_cancel(target_comment_id uuid)`、`get_public_session_comments(target_session_id text)` の返却列、本人判定不足、編集・削除UI差し込み方針、削除時の申請取消扱い、RLS smoke test更新案、段階実装案を整理済み。この工程では本番UI実装、編集・削除RPC呼び出し、SQL Editor実行、DB変更、RLS変更、`close_session` は扱っていない。
- 次工程候補はM-11C-1として、`get_public_session_comments` へ `is_own` / `can_edit` / `can_delete` 相当を追加するか、別の本人コメント判定RPCを作るかを確定すること。M-11B-4の投稿まわりRLS smoke test追加・強化と、GM操作統合は引き続き別工程で扱う。
- M-11C-1本人判定RPC方針完了: `docs/supabase-session-detail-application-comment-own-flags-plan.md` に、既存 `get_public_session_comments(target_session_id text)` の仕様、案A/RPC拡張・案B/別RPC・案C/user_id返却の比較、採用案、anon/authenticated扱い、GM/admin後回し方針、RLS smoke test更新案を整理済み。採用案は公開コメントRPCの末尾へ `is_own` / `can_edit` / `can_delete` を追加する方式。ただしM-11CではPL本人UIのみ扱うため、GM/admin権限フラグは含めず将来のGM/admin向けRPCへ回す。
- M-11C-1 SQL草案として `docs/supabase/sql/011_session_comment_own_flags_rpc_draft.sql` を追加済み。既存列を維持したまま末尾に本人判定フラグを追加し、`auth.uid() is not null and c.user_id = auth.uid()` で判定する草案。`user_id` / email / Discord ID / role / `application_id` は返さない。戻り値型変更のためdrop/recreate前提、事前確認SELECT、適用後確認、ロールバック草案、停止条件を含める。この工程ではSQL Editor実行、DB変更、本番フロント実装、編集・削除RPC呼び出し、`close_session`、commit / pushは行っていない。
- M-11C-1 SQL適用結果として、ユーザーがSupabase SQL Editorで `011_session_comment_own_flags_rpc_draft.sql` を適用済み。`get_public_session_comments(target_session_id text)` は既存8列の末尾に `is_own` / `can_edit` / `can_delete` を追加した11列版になった。grant確認で `anon` / `authenticated` に `EXECUTE` があることを確認済みで、`postgres` 表示は管理者/所有者側として問題扱いしない。`session-detail.html?id=session-2026-06-08-railway-incident` の既存表示、コメント一覧、申請中 / 承認済みカウント、投稿フォーム、console errorなし、email / `user_id` / token / key / `gmUserId` 非表示を確認済み。rollbackは未実行。同じ置換SQLは通常運用で再実行しない。詳細は `docs/supabase-session-detail-application-comment-own-flags-result.md`。
- M-11C-2完了: `assets/js/sessionDetailApplicationComments.js` で `is_own` / `can_edit` / `can_delete` をbooleanとして正規化し、本人コメントかつ許可flagがtrueのカードだけにdisabledの編集 / 削除準備UIを表示する。編集 / 削除RPC呼び出し、編集 / 削除実行テスト、SQL Editor実行、DB変更、GM操作、`updates.json` 変更は行っていない。実装結果は `docs/supabase-session-detail-application-comment-edit-delete-ui-result.md` に分離済み。
- M-11C-2 follow-up完了: 参加希望コメント一覧は `created_at` 降順の新しい順を初期表示にした。`updated_at` / `edited_at` では並べ替えない。将来、参加希望コメント一覧に「新しい順 / 古い順」切替を追加する余地あり。初期表示は新しい順を基本とする。
- M-11C-3完了: `session-detail.html` の本人参加希望コメント編集UIを `update_application_comment` に接続済み。`can_edit === true` かつログイン済み、内部 `comment_id` あり、送信中 / 保存中でない場合だけ編集ボタンを有効化し、対象カードだけをtextarea編集モードにする。保存時は空欄 / 4000文字超過を検証し、成功後に公開コメント一覧・公開カウント・本人申請状態を再取得する。削除RPC、GM操作、SQL Editor実行、DB変更、Codex側での編集保存実行、`updates.json` 変更は行っていない。実装結果は `docs/supabase-session-detail-application-comment-edit-result.md` に分離済み。
- M-11C-4完了: `session-detail.html` の本人参加希望コメント削除UIを `delete_application_comment_and_maybe_cancel` に接続済み。`can_delete === true` かつログイン済み、内部 `comment_id` あり、投稿中 / 保存中 / 削除中でない場合だけ削除ボタンを有効化し、対象カード内の確認UIで `削除する` を選んだ後だけRPCを呼ぶ。成功後に公開コメント一覧・公開カウント・本人申請状態を再取得する。Codex側では削除確定を実行せず、GM操作、SQL Editor実行、DB変更、`updates.json` 変更は行っていない。実装結果は `docs/supabase-session-detail-application-comment-delete-result.md` に分離済み。
- M-11D-1調査・設計完了: `docs/supabase-session-detail-application-withdraw-history-plan.md` に、コメント削除と申請辞退を分ける理由、`session_applications.status` の現状、`canceled` 優先方針、本人向け「参加申請を取り下げる」フロー、辞退コメントとして投稿する案、GM向け申請履歴折りたたみUI案、必要RPC案、RLS smoke test更新案、M-11D段階分割を整理済み。この工程では本番フロント実装、SQL草案作成、SQL Editor実行、DB変更、申請辞退RPC実行、GM操作実装、`close_session`、`updates.json` 変更は行っていない。
- M-11D-2 SQL草案・RPC設計完了: `docs/supabase-session-detail-application-withdraw-rpc-plan.md` と `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql` に、本人申請辞退RPC `cancel_my_session_application(target_session_id text)` の仕様、`canceled` 採用理由、`withdrawn` 保留理由、`accepted` 辞退可方針、コメント削除RPCとの差分、security definer / `auth.uid()` 境界、grant / rollback、RLS smoke test案を整理済み。この工程ではSQL Editor実行、DB変更、申請辞退RPC実行、本番フロント実装、GM履歴RPC実装、`updates.json` 変更、commit / pushは行っていない。
- M-11D-2 SQL適用結果記録完了: ユーザーがSupabase SQL Editorで `cancel_my_session_application(target_session_id text)` を作成済み。適用結果は `docs/supabase-session-detail-application-withdraw-rpc-result.md` に分離済み。関数定義は `security definer = true`、引数 `target_session_id text`、戻り値は `session_id` / `application_status` / `canceled_at` / `updated_at`。grant確認では `authenticated EXECUTE` と `postgres EXECUTE` があり、`anon EXECUTE` はない。`postgres EXECUTE` はownerまたは管理者側の表示として扱う。RPC実行テストとrollbackは未実行。`012_session_application_cancel_my_rpc_draft.sql` の作成SQLは適用済みのため、通常運用では同じ作成SQLをそのまま再実行しない。このdocs記録工程でCodexはSQL Editor実行、DB変更、RPC実行、本番フロント実装、`updates.json` 変更、commit / pushを行っていない。
- M-11D-3 実装前確認・UI設計完了: `docs/supabase-session-detail-application-withdraw-ui-plan.md` に、本人申請辞退UIの配置案、表示条件、辞退前 / 確認 / 辞退後の文言、辞退後の再取得対象、mypage / session-detailへの影響、再申請方針、テストデータ影響、M-11D-4以降の段階案を整理済み。推奨配置は `data-session-comment-post-control` 内の本人申請状態メッセージ直下、投稿フォーム直上。この工程では本番フロント実装、`cancel_my_session_application` 呼び出し実装、RPC実行、SQL Editor実行、DB変更、GM履歴RPC / UI実装、`updates.json` 変更、commit / pushは行っていない。
- M-11D-4 状態表示UI実装完了: `session-detail.html` の参加希望コメント欄で、本人申請状態メッセージ直下、投稿フォーム直上に申請取り下げUI器を追加済み。`pending` / `waitlisted` は参加申請中表示と次工程予定の取り下げUI、`accepted` はGM連絡推奨を含む強めの表示、`canceled` は取り下げ済みと再申請投稿案内、`rejected` は申請不可案内を維持する。確認UIは開けるが、確定ボタンはdisabledで申請辞退RPCは呼び出さない。コメント投稿 / 編集 / 削除、コメント一覧、申請中 / 承認済みカウント、mypage既存表示は維持する方針。実装結果は `docs/supabase-session-detail-application-withdraw-ui-result.md` に分離済み。この工程ではSQL Editor実行、DB変更、申請辞退RPC実行、GM履歴UI、`updates.json` 変更、commit / pushは行っていない。
- M-11D-5 RPC接続実装完了: `session-detail.html` の本人申請取り下げ確認UIを `cancel_my_session_application(target_session_id text)` に接続済み。ログイン済み、対象セッションIDあり、本人申請状態が `pending` / `waitlisted` / `accepted`、投稿中 / 保存中 / 削除中 / 取り下げ中またはコメント編集中でない場合だけ確定できる。取り下げ中は確定 / キャンセル / 投稿フォーム / 編集 / 削除を抑止し、成功後に公開コメント一覧・公開カウント・本人申請状態を再取得する。Codex側では取り下げ確定を実行せず、SQL Editor実行、DB構造変更、GM履歴RPC / UI、`updates.json` 変更、commit / pushは行っていない。実装結果は `docs/supabase-session-detail-application-withdraw-action-result.md` に分離済み。
- M-11D-6 再申請復帰確認完了: ユーザー実ブラウザで、申請取り下げ後もコメントが残り、申請中人数から除外され、mypageの参加申請中から対象セッションが消えることを確認済み。その後、参加希望コメントを投稿し直すと再申請扱いになり、`session_applications.status` は `canceled` から `pending` 相当に復帰する挙動として問題ない。コメントは増えるが申請人数はユーザー単位で重複カウントされず、公開版でも確認済み。結果は `docs/supabase-session-detail-application-withdraw-reapply-result.md` に分離済み。この工程ではフロント実装、SQL Editor実行、DB変更、`updates.json` 変更、secret類の記録、commit / pushは行っていない。
- M-11E-1調査・設計完了: `docs/supabase-session-detail-application-history-gm-plan.md` に、GM向け申請履歴RPC / 折りたたみUIの目的、GM判定、表示する情報 / 表示しない情報、`get_gm_session_application_history(target_session_id text)` 案、deletedコメントの扱い、status表示方針、Discord IDコピー機能との切り分け、RLS smoke test案、実装段階案を整理済み。SQL草案として `docs/supabase/sql/013_gm_session_application_history_rpc_draft.sql` を追加し、`session_applications` を主軸に `display_name` / status / 申請作成・更新日時 / `canceled_at` / 有効コメント数 / 最終有効コメント日時だけを返す方針にした。この工程では本番フロント実装、SQL Editor実行、DB変更、GM履歴RPC実行、GM承認 / 却下実装、Discord IDコピー実装、`close_session`、`updates.json` 変更、secret類の記録、commit / pushは行っていない。
- M-11E-2実行前レビュー完了: `docs/supabase/sql/013_gm_session_application_history_rpc_draft.sql` の安全性、権限、返却列、コメント集計、既存機能への影響、preflight / post-apply / rollbackを確認した。SQL草案は、helper functionのsearch_path確認を強め、SQL Editorのpost-apply確認でGM履歴RPCを呼び出さずカタログ上の戻り値定義を見る形へ修正した。`docs/supabase-session-detail-application-history-gm-plan.md` にレビュー結果を追記済み。この工程ではSQL Editor実行、DB変更、GM履歴RPC実行、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。
- M-11E-3 SQL適用結果記録完了: ユーザーがSupabase SQL Editorで `get_gm_session_application_history(target_session_id text)` を作成済み。適用結果は `docs/supabase-session-detail-application-history-gm-rpc-result.md` に分離済み。関数定義は `security definer = true`、volatilityは `stable`、引数 `target_session_id text`、戻り値は `display_name` / `application_status` / `created_at` / `updated_at` / `canceled_at` / `comment_count` / `last_comment_at`。grant確認では `authenticated EXECUTE` と `postgres EXECUTE` があり、`anon EXECUTE` はない。`postgres EXECUTE` はownerまたは管理者側の表示として扱う。GM/admin/PL/anon文脈でのRPC実行テストとrollbackは未実行。`013_gm_session_application_history_rpc_draft.sql` の作成SQLは適用済みのため、通常運用では同じ作成SQLをそのまま再実行しない。このdocs記録工程でCodexはSQL Editor実行、DB変更、RPC実行、本番フロント実装、`updates.json` 変更、commit / pushを行っていない。
- M-11E-3 follow-up 権限文脈確認計画完了: `docs/supabase-session-detail-application-history-gm-auth-test-plan.md` に、GM履歴RPCをUIへ接続する前のanon / 通常PL / 対象GM / admin文脈の期待値、既存検証データで確認できること、不足fixture、推奨確認方法、SQL Editor直接実行を避ける理由、smoke test追加案、UI実装前の最低合格条件を整理済み。`session-2026-06-08-railway-incident` は公開表示回帰には使えるが、M-10検証SQL草案ではDB側 `gm_user_id` をnullのままにする方針だったため、対象GM文脈確認は既存 `rls-test-*` smoke fixtureまたは別途レビュー済みfixtureを優先する。この工程ではSQL Editor実行、DB変更、GM履歴RPC実行、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。
- M-11E-4 GM履歴RPC RLS smoke test足場実装完了: `scripts/supabase-rls-smoke-test.mjs` に `M11E-HIST-001` から `M11E-HIST-010` を追加し、anon / 通常PL / 対象GM / 他GM / admin のAuth文脈と返却列の内部情報非露出を確認できるようにした。`canceled` / `rejected` / deletedコメント / `comment_count` active-onlyは既存fixture不足としてSKIPに整理。結果は `docs/supabase-session-detail-application-history-gm-smoke-test-result.md` に分離済み。この工程ではDB接続を伴う smoke test 本体実行、SQL Editor実行、DB変更、GM履歴RPC手動実行、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。`node --check scripts/supabase-rls-smoke-test.mjs` は成功。
- M-11E-4通常smoke test確認完了: ユーザーが `node scripts/supabase-rls-smoke-test.mjs` を `RUN_DESTRUCTIVE_TESTS` なしで実行し、`PASS 40 / FAIL 0 / SKIP 13` を確認済み。GM履歴RPC関連は `M11E-HIST-001` から `M11E-HIST-007` がPASSし、anon / 通常PL / 他GM拒否、対象GM / admin取得可、内部情報非露出チェックが通った。`M11E-HIST-008` から `M11E-HIST-010` は専用fixture不足でSKIPし、通常smoke testでは問題扱いしない。これにより次工程としてGM履歴UI実装へ進める状態。`canceled` / `rejected` 履歴やdeletedコメント耐性の詳細確認は将来fixture整備後に扱う。このdocs記録工程でCodexはSQL Editor実行、DB変更、フロント実装、GM履歴RPC手動実行、`updates.json` 変更、secret類の記録、commit / pushを行っていない。
- M-11E-5 GM履歴UI器実装完了: `session-detail.html` の参加希望コメント欄に、GM/adminだけが見られる `GM向け：申請履歴を見る` 折りたたみUIを追加済み。ログイン済みユーザーだけ `is_admin()` / `is_session_gm(sessionId)` で判定し、通常PL / 未ログイン / 判定失敗時は表示しない。配置はコメント一覧直下、人数注記の上。中身は `申請履歴の読み込みは次工程で実装予定です。` のプレースホルダーのみで、`get_gm_session_application_history`、`set_application_status`、`close_session` は呼び出していない。実データ、内部ID、email、Discord ID、token、key、secret類は表示しない。実装結果は `docs/supabase-session-detail-application-history-gm-ui-placeholder-result.md` に分離済み。この工程ではSQL Editor実行、DB変更、`updates.json` 変更、commit / pushは行っていない。
- M-11E-6 GM履歴RPC接続実装完了: `session-detail.html` のGM/admin向け申請履歴折りたたみUIを `get_gm_session_application_history(target_session_id text)` に接続済み。折りたたみを開いた初回だけRPCを呼び、成功後は同じ描画内で結果を保持する。表示は `display_name` / `application_status` / `created_at` / `updated_at` / `canceled_at` / `comment_count` / `last_comment_at` に限定し、loading / empty / error を用意した。通常PL / 未ログイン / 判定失敗時はUI非表示のまま。GM承認 / 却下、GMコメント編集 / 削除、Discord IDコピー、`close_session`、SQL Editor実行、DB変更、`updates.json` 変更、commit / pushは行っていない。実装結果は `docs/supabase-session-detail-application-history-gm-ui-result.md` に分離済み。
- M-11F GM承認 / 却下UI実装完了: `session-detail.html` のGM/admin向け申請履歴折りたたみ内に、`pending` / `waitlisted` だけを対象にした `承認` / `却下` 操作UIを追加済み。対象申請はGM/admin判定済みの文脈で `session_applications` から内部取得し、`get_public_session_comments` の `comment_id` とJS内で突き合わせたdisplay_nameだけを表示する。`application_id` / `comment_id` の実値、email、`user_id`、token、key、secret類は画面・console・docsへ出さない。確認UI後に `set_application_status(target_application_id uuid, new_status text)` を呼び、成功後はGM履歴、コメント一覧、申請中 / 承認済みカウント、本人申請状態を再取得する。対象を安全に確認できない場合は操作ボタンを出さない。Codex側では承認 / 却下の確定操作、SQL Editor実行、DB変更、`close_session`、Discord IDコピー、`updates.json` 変更、commit / pushは行っていない。実装結果は `docs/supabase-session-detail-application-gm-approve-reject-result.md` に分離済み。
- M-11F ユーザー実ブラウザ確認結果記録完了: adminで申請を承認でき、承認後にPL側mypageの `参加予定` へ対象セッションが表示され、`参加申請中` から消えることを確認済み。`session-detail.html` の本人申請状態は承認済み / 参加予定扱いになり、申請中人数が減って承認済み人数が増え、GM履歴でも対象者が承認済みになる。承認済み行には `承認` / `却下` ボタンが出ない。却下時は画面上で `見送り` と表示される。email、`user_id`、token、key、`gmUserId`、`comment_id`、`application_id` は画面に出ておらず、console errorなし。このdocs記録工程ではSQL Editor実行、DB変更、フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。詳細は `docs/supabase-session-detail-application-gm-approve-reject-result.md` に追記済み。
- M-11F GM承認 / 却下 smoke test観点追加完了: `scripts/supabase-rls-smoke-test.mjs` に `M11F-APPROVE-001` から `M11F-APPROVE-007` を追加し、anon / 通常PL / 他GMの状態変更拒否、不正status拒否、関連エラー整形結果の生内部ID・secret類非露出を確認できるようにした。GM/admin成功系は再利用fixtureを壊す可能性があるためM-11F追加分ではSKIPにし、専用の状態リセットfixtureができるまで通常実行の状態変更は増やさない。DB接続を伴う smoke test 本体実行、`RUN_DESTRUCTIVE_TESTS=true` 実行、SQL Editor実行、DB変更、`updates.json` 変更、secret類の記録、commit / pushは行っていない。`node --check scripts/supabase-rls-smoke-test.mjs` は成功。詳細は `docs/supabase-session-detail-application-gm-approve-reject-smoke-test-result.md` に分離済み。
- M-11F GM承認 / 却下 smoke test通常実行結果記録完了: ユーザーが `node scripts/supabase-rls-smoke-test.mjs` を `RUN_DESTRUCTIVE_TESTS` なしで実行し、`PASS 45 / FAIL 0 / SKIP 15` を確認済み。M-11F関連では `M11F-APPROVE-001` / `002` / `003` / `006` / `007` がPASSし、anon / 通常PL / 他GMの状態変更拒否、不正status拒否、関連エラーの内部ID・email・token・key類非露出が確認できた。`M11F-APPROVE-004` / `005` は専用の状態リセットfixtureがなく、通常実行で再利用fixtureの application status を変更すると検証データを壊す可能性があるためSKIP。成功系は将来、専用fixtureまたは `RUN_DESTRUCTIVE_TESTS` 条件つきで扱う。このdocs記録工程ではSQL Editor実行、DB変更、フロント実装、`RUN_DESTRUCTIVE_TESTS` 使用、`updates.json` 変更、secret類の記録、commit / pushは行っていない。詳細は `docs/supabase-session-detail-application-gm-approve-reject-smoke-test-result.md` に追記済み。

## Supabase M-12A Discord ID登録 / GMコピー導線 調査・設計
- `docs/supabase-discord-id-contact-plan.md` に、Discord ID相当の連絡先を安全に保存し、GM/adminが承認済み参加者だけ確認・コピーできるようにするための調査結果と設計を整理済み。既存 `profiles.discord_user_id` は17〜20桁数字制約つきで、今回の柔軟な連絡先入力には厳しすぎるため、新規非公開列 `profiles.discord_handle` を推奨する。`public_profiles` は `id` / `display_name` のみを維持し、Discord IDを公開viewや公開コメントRPCへ含めない。
- SQL草案として `docs/supabase/sql/014_discord_id_profile_contact_draft.sql` を追加済み。`profiles.discord_handle`、本人取得RPC `get_my_profile_contact()`、本人更新RPC `update_my_discord_id(new_discord_id text)`、GM/admin向け承認済み参加者連絡先RPC `get_gm_session_accepted_contacts(target_session_id text)`、grant / revoke、preflight、post-apply、rollback、停止条件を含める。返却列は `display_name` / `discord_handle` に限定し、`user_id`、email、`application_id`、`comment_id`、role、`discord_user_id`、`discord_name`、token、key、secret類は返さない。
- M-12AではSQL Editor実行、DB変更、本番フロント実装、Discord ID実値の記録、GM向けコピー機能実装、`updates.json` 変更、commit / pushは行っていない。次工程候補はM-12B SQL草案レビュー、M-12C SQL適用 / 結果記録、M-12D mypage登録UI、M-12E GM向け承認済み参加者連絡先表示 / コピー、M-12F RLS smoke test強化。

## Supabase M-12B Discord ID連絡先SQL草案 実行前レビュー
- `docs/supabase/sql/014_discord_id_profile_contact_draft.sql` は、`profiles.discord_handle` をPL本人入力の現代Discord ID/handle用の非公開列として追加し、本人RPCとGM/admin向け承認済み参加者連絡先RPCに限定して使う方針でレビューした。
- M-12Bレビューで、既存 `profiles.discord_user_id` / `profiles.discord_name` は既存互換・旧仕様寄りの列として扱い、今回のGMコピー導線では返却・更新対象にしない方針を補強した。返却列は `display_name` / `discord_handle` に統一し、曖昧な `discord_id` aliasも採用しない。
- `public_profiles`、公開コメントRPC、anon、通常PL全体へ `discord_handle` を出さない方針を維持する。M-12FのRLS smoke test強化では、公開系RPC/viewが `discord_handle` / `discord_user_id` / `discord_name` を返さない確認と、連絡先RPCが許可文脈でのみ `display_name` / `discord_handle` を返す確認を追加する。
- M-12BではSQL Editor実行、DB変更、本番フロント実装、Discord ID実値の記録、GM向けコピーUI実装、`updates.json` 変更、commit / pushは行っていない。

## Supabase M-12B Discord ID連絡先SQL適用結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/014_discord_id_profile_contact_draft.sql` のapply sectionを実行済み。適用結果は `docs/supabase-discord-id-contact-sql-result.md` に分離して記録済み。
- DB側では `profiles.discord_handle text`、`profiles_discord_handle_check`、`get_my_profile_contact()`、`update_my_discord_id(new_discord_id text)`、`get_gm_session_accepted_contacts(target_session_id text)` を確認済み。`public_profiles` は `id` / `display_name` のみで、`discord_handle` / `discord_name` / `discord_user_id` は出ていない。
- 3RPCはいずれも `security definer = true`、`search_path = ""`、返却列は `display_name` / `discord_handle`。grantは `authenticated EXECUTE` と `postgres EXECUTE` を確認済みで、`anon EXECUTE` はない。`postgres EXECUTE` はownerまたは管理者側の表示として扱う。
- `profiles_discord_handle_check` はnull許可、100文字以下、改行禁止の制約。rollback、本人RPC / GM用RPCの実ログイン文脈テスト、RLS smoke test追加、本番フロント実装は未実施。同じapply sectionは通常運用で再実行しない。このdocs記録工程でCodexはSQL Editor実行、DB変更、Discord ID実値の記録、secret類の記録、`updates.json` 変更、commit / pushを行っていない。
- 次工程候補は、SQL適用結果commit後に `mypage.html` のDiscord ID登録UI、または連絡先RPCのRLS smoke test追加へ進むこと。

## Supabase M-12C mypage Discord ID登録UI
- M-12C本人用UI実装完了: `mypage.html` のログイン済みアカウント機能内で、既存の表示名編集UIの直後に `Discord ID` 登録 / 編集パネルを追加済み。`get_my_profile_contact()` で現在値を取得し、`update_my_discord_id(new_discord_id text)` で保存する。未ログイン時は既存のログイン導線に従い、Discord ID欄は表示しない。
- バリデーションは空欄保存を未登録扱い、100文字超過拒否、改行拒否に限定し、Discord側の仕様変更に備えて数字限定や `@` 必須の厳密な正規表現は使わない。DOM反映は `textContent` と input value に限定し、HTMLとして扱わない。
- 画面・console・docsへ出す情報は本人の `discord_handle` に限定する。email、`user_id`、token、key、secret、`discord_user_id`、`discord_name`、他人の `discord_handle` は出さない。実装結果は `docs/supabase-discord-id-mypage-ui-result.md` に分離済み。
- M-12CではSQL Editor実行、DB変更、GM向け承認済み参加者Discord ID表示 / コピー導線、RLS smoke test追加、Discord ID実値入力、`updates.json` 変更、commit / pushは行っていない。次工程候補はM-12E GM向け承認済み参加者連絡先表示 / コピー、またはM-12F RLS smoke test強化。

## Supabase M-12D GM向け承認済み参加者連絡先UI
- M-12D GM向け連絡先UI実装完了: `session-detail.html` のGM/admin向け領域に `GM向け：承認済み参加者連絡先` 折りたたみを追加済み。既存のGM/admin判定に従い、未ログイン / 通常PL / 判定失敗時はUIを表示しない。
- `get_gm_session_accepted_contacts(target_session_id text)` を呼び、`display_name` / `discord_handle` のみを扱う。未登録者は `未登録` と表示し、`連絡先一覧をコピー` で同じ形式の行区切りテキストをコピーできる。
- email、`user_id`、`application_id`、`comment_id`、`discord_user_id`、`discord_name`、token、key、secret類は表示・コピー対象にしない。実装結果は `docs/supabase-discord-id-gm-contact-ui-result.md` に分離済み。この工程ではSQL Editor実行、DB変更、RLS smoke test追加、Discord ID実値入力、`updates.json` 変更、commit / pushは行っていない。

## M-13A sessionType分類フィールド
- `data/sessions.json` の各セッションに `sessionType` を追加済み。既存7件は `one-shot` とし、表示名は `単発シナリオ`。
- 表示は `session-detail.html` の基本情報と、`calendar.html` の選択日セッション一覧で行う。自由タグは分類に使わず、session-detailで自由タグを表示しない方針も維持する。
- 実装結果は `docs/session-type-field-result.md` に分離済み。この工程ではSQL Editor実行、DB変更、`updates.json` 変更、commit / pushは行っていない。

## M-13B 申請締切日時フィールド
- `data/sessions.json` の各セッションに `applicationDeadline` を追加済み。既存7件は開催日前日の `23:59` で統一した。
- 表示は `session-detail.html` の基本情報と、`calendar.html` の選択日セッション一覧で行う。未設定時は `未定` と表示する。
- M-13B内の追加調整として、`session-detail.html` の基本情報からGM固定表示を削除済み。`data/sessions.json` のGM情報とcalendar側のGM表示は維持する。
- `startTime` / `endTime` は開催時刻として維持し、申請締切には流用しない。実装結果は `docs/session-application-deadline-field-result.md` に分離済み。この工程ではSQL Editor実行、DB変更、`updates.json` 変更、pushは行っていない。

## M-14A セッション予定投稿＋Discord同期 全体設計
- GM/adminがサイト上からセッション予定を投稿し、Discord専用投稿先へサーバー側で同期するための最小設計を `docs/session-posting-discord-sync-plan.md` に分離済み。
- 投稿セッションの正本は、既存の参加申請・GM判定・GM連絡先RPCとの接続を優先して、既存 `public.sessions` を拡張して使う案を第一候補にした。M-13A/M-13Bで追加した `sessionType` / `applicationDeadline` に対応するDB列追加は将来SQL草案で扱う。
- Discord投稿credentialはフロントやdocsへ置かず、Supabase Edge Function側だけで管理する方針。Discord投稿先がチャンネル、フォーラム、既存スレッド、イベントのどれに近いかは実装前のユーザー確認事項として残す。
- この工程ではフロント実装、SQL Editor実行、DB変更、Edge Function作成、Discord実投稿、`updates.json` 変更、commit / pushは行っていない。

## M-14B 依頼書投稿DB/RPC + Discord同期Edge Function草案
- `docs/supabase/sql/015_session_posting_rpc_draft.sql` に、既存 `public.sessions` の拡張、`create_session_post` RPC、grant / revoke、preflight、post-apply、rollback草案を追加済み。`session_type`、`application_deadline`、Discord同期状態、`discord_message_id` / `discord_channel_id` / `discord_thread_id` / `discord_last_action` などのメタデータ案を含めた。
- `docs/supabase/functions/session-post-discord-sync-draft.md` に、Edge Functionが `action = create / update / delete / close / resync` を扱う草案を追加済み。Discord同期は新規投稿だけでなく、編集、募集終了、削除/非公開、失敗後再同期までを対象にする。
- `docs/session-posting-rpc-edge-function-plan.md` に、投稿RPC、Edge Function、Discord側の編集/通知/削除方針、`data/sessions.json` とSupabase `sessions` の併用・マージ方針、テンプレート保存の後続化を整理済み。
- この工程ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。Discord投稿credential値は記録していない。

## M-14C 依頼書投稿RPC SQL草案 実行前レビュー
- `015_session_posting_rpc_draft.sql` を既存 `public.sessions`、RLS、申請/コメントRPC、`data/sessions.json` の `sessionType` / `applicationDeadline` と突き合わせてレビュー済み。`sessions.id` はtextのまま維持し、GM本人投稿の `gm_user_id` は `auth.uid()` 固定、戻り値は `session_id` / `discord_sync_status` / `created_at` のみに限定する方針。
- 実行前修正として、`draft` のpublic保存を拒否し、`draft` / `private` / `hidden` はDiscord即時同期対象外として `discord_sync_status = skipped` にする草案へ調整済み。公開かつ `tentative` / `recruiting` のみ `pending` としてEdge Function同期対象にする。
- admin代理投稿、public draft運用、非公開投稿のDiscord同期が必要になった場合は、SQL適用前に停止して方針確認する。このレビュー工程ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、`updates.json` 変更、commit / pushは行っていない。Discord投稿credential値は記録していない。

## M-14C public schema TRUNCATE権限整理結果
- M-14C / 015 preflight中に、`public.sessions` だけでなくpublic schema内の複数テーブルで `anon` / `authenticated` に `TRUNCATE` 権限が見えていたため、ユーザーがSupabase SQL Editorで `TRUNCATE` だけをrevoke済み。実行結果は `Success. No rows returned`。
- 確認クエリでは、public schema内で `anon` / `authenticated` に残る `TRUNCATE` 権限が `0 rows` になった。`SELECT` / `INSERT` / `UPDATE` / `DELETE` は今回触っていない。`postgres` などの管理者系ロール側の権限は対象外。
- 結果は `docs/supabase-public-truncate-privilege-cleanup-result.md` に分離済み。TRUNCATE権限整理時点では `015_session_posting_rpc_draft.sql` のapplyは未実行だった。このdocs記録工程でCodexはSQL Editor追加実行、DB変更、Edge Function deploy、Discord実送信、credential値の記録、`updates.json` 変更、commit / pushを行っていない。

## M-14C 015 session posting RPC SQL適用結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/015_session_posting_rpc_draft.sql` のapply sectionを実行し、`Success. No rows returned` で通過済み。`public.sessions` に `session_type` / `application_deadline` / Discord同期メタデータ列が追加され、`application_deadline` は `timestamptz`、`session_type` は `text` / not null / default `'one-shot'`、`discord_sync_status` は `text` / not null / default `'not_requested'` と確認済み。
- `sessions_session_type_check` / `sessions_discord_sync_status_check` / `sessions_discord_last_action_check` / `sessions_discord_sync_error_length_check`、`create_session_post(...)` の `security definer = true` / `volatile` / 戻り値 `session_id`・`discord_sync_status`・`created_at`、grantが `authenticated EXECUTE` と `postgres EXECUTE` のみで `anon EXECUTE` がないことを確認済み。
- M-14C apply直後時点では、`create_session_post(...)` の実行テスト、Edge Function deploy、Discord実送信、フロント実装は未実施だった。結果は `docs/session-posting-rpc-apply-result.md` に分離済み。`015_session_posting_rpc_draft.sql` のapply sectionは適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。このdocs記録工程でCodexはSQL Editor追加実行、DB変更、credential類の実値記録、`updates.json` 変更、commit / pushを行っていない。

## M-14D-1 create_session_post hidden draft実行テスト
- `dev/run-create-session-post-test.mjs` は通常実行ではSKIPすることを確認済み。`RUN_CREATE_SESSION_POST_TEST=true` / `CREATE_SESSION_POST_CONFIRM=hidden-draft` / `CREATE_SESSION_POST_ACTOR=gm` で、GM認証文脈から `create_session_post(...)` を1回実行した。
- 結果は `ok: true`、`discord_sync_status = skipped`、作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot` / `application_deadline_present = true` / `discord_sync_status = skipped`。anonからpublic表示対象として見えないことも確認済み。
- hidden draft test row は作成済みで削除していない。結果は `docs/session-posting-rpc-execution-test-result.md` に分離済み。SQL EditorでのRPC直接実行、Edge Function deploy、Discord実送信、DB構造変更、フロント実装、token / key / email / user_id全文 / credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。`dev/run-create-session-post-test.mjs` はcommit対象候補。
## M-14D-2 GM/admin依頼書投稿フォーム + Supabase sessions表示反映
- `session-post.html` と `assets/js/renderSessionPost.js` を追加し、GM/adminが認証済みSupabase clientから `create_session_post(...)` を呼べる投稿フォームを実装した。初期値は `visibility = hidden` / `status = draft` / `sessionType = one-shot`。
- `assets/js/sessionData.js` で `data/sessions.json` とSupabase `public.sessions` の公開表示対象をマージし、calendar / session-detail に接続した。同一IDは静的JSON側を優先し、Supabase側は `visibility = public` かつ `draft` / `canceled` 以外を対象にする方針。
- 追加修正として、ヘッダー圧迫回避のためグローバルメニューの `POST` を削除し、依頼書投稿導線をcalendarの日付セル内の `＋依頼書` へ寄せた。`session-post.html?date=YYYY-MM-DD` では開始日時欄へ日付を初期反映する。
- フォームの `開催日` / `開始時刻` は `開始日時` に統合し、送信時に `p_session_date` / `p_start_time` へ分解する。`終了時刻` は `終了日時` に変更し、送信時は時刻部分だけを `p_end_time` として送る。日跨ぎ終了日時は現DB/RPCで永続化できないため投稿前バリデーションで止め、将来 `end_date` または `end_at` 追加工程で扱う。
- `レベル帯` 欄は削除し、RPC送信時の `p_level_range` は `null` を送る。
- フォームの `依頼書本文` 欄と `参加条件` 欄は削除し、依頼書本文は `概要` 欄へ記載する運用にした。RPC送信時の `p_request_body` / `p_requirements` は `null` を送る。
- Discord実送信は未実装で、投稿成功時は `discord_sync_status` 表示のみ。SQL Editor実行、DB構造変更、Edge Function deploy、Discord実送信、secret類の実値記録、`updates.json` 変更、commit / pushは行っていない。詳細は `docs/session-posting-form-result.md` に記録済み。

## M-14D-3 依頼書投稿フォーム 日跨ぎ終了日時正式対応 SQL/RPC差分草案
- M-14D-2の投稿フォームは `開始日時` / `終了日時` UIに整理済みだが、現DB/RPCは `end_time` しか保存できないため、日跨ぎ終了日時は投稿前バリデーションで止めている。
- 正式対応の第一候補として `public.sessions.end_at timestamptz` を追加し、`create_session_post(...)` の末尾に `p_end_at text default null` を追加する差分SQL草案 `docs/supabase/sql/016_session_posting_end_at_draft.sql` を作成した。015は適用済みのため、同じapply sectionを通常運用で再実行しない。
- SQL/RPC適用後は、フォームの `終了日時` から `p_end_at` を送信し、日跨ぎ終了日時の投稿前ブロックを解除する。表示側は `end_at` / `endAt` を優先し、なければ従来の `date + end_time` / `endTime` にフォールバックする。Discord本文も `end_at` 優先にする。
- 草案と方針は `docs/session-posting-end-at-plan.md` に分離済み。この工程ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、secret類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## M-14D-4 016 end_at SQL適用結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/016_session_posting_end_at_draft.sql` のapply sectionを実行し、`Success. No rows returned` で通過済み。apply前は `sessions.end_at` 未作成、`create_session_post` は1本のみ、`p_end_at` 引数なしだった。
- apply後は `public.sessions.end_at timestamptz` が追加され、`create_session_post(...)` は `p_end_at` 対応版へ差し替え済み。旧signatureをdropしてから新signatureを作成したため、関数は1本だけであることを確認済み。
- grantは `authenticated EXECUTE` と `postgres EXECUTE` のみで、`anon EXECUTE` はなし。関数定義は `security definer = true`、`volatile`、`search_path` 固定あり、戻り値は `session_id` / `discord_sync_status` / `created_at` のみ。
- `016_session_posting_end_at_draft.sql` は適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。日跨ぎhidden/draft投稿テスト、フォーム側の日跨ぎ許可切替、Edge Function deploy、Discord実送信はまだ未実施。詳細は `docs/session-posting-end-at-apply-result.md` に記録済み。
- このdocs記録工程でCodexはSQL Editor追加実行、DB変更、フロント実装、Edge Function deploy、Discord実送信、secret類の実値記録、`updates.json` 変更、commit / pushを行っていない。

## M-14D-5 依頼書投稿フォーム end_at対応
- `assets/js/renderSessionPost.js` を `p_end_at` 送信へ切り替えた。開始日時から `p_session_date` / `p_start_time`、終了日時から `p_end_at` と互換用 `p_end_time` を送る。
- 日跨ぎ終了日時の投稿前ブロックは解除した。開始日時/終了日時は必須で、終了日時が開始日時以下の場合は `終了日時は開始日時より後にしてください。` として拒否する。
- `レベル帯` 欄、`依頼書本文` 欄、`参加条件` 欄は復活させていない。RPC送信時の `p_level_range` / `p_request_body` / `p_requirements` は `null` のまま。
- `assets/js/sessionData.js` でSupabase `end_at` を取得し `endAt` へ正規化する。`assets/js/sessionDisplay.js` では `endAt` があれば終了日時として優先し、なければ従来の `endTime` へフォールバックする。
- GM認証文脈のSupabase clientで日跨ぎhidden/draft投稿を1回確認済み。作成成功、`discord_sync_status = skipped`、作成行は `draft` / `hidden` / `one-shot` / `end_at` あり、anonからpublic表示対象として見えない。hidden draft test rowは削除していない。
- Discord実送信は未実装のまま。public/recruiting投稿はユーザー確認なしでは実施しない。この工程でCodexはSQL Editor実行、DB構造変更、Edge Function deploy、secret類の実値記録、`updates.json` 変更、commit / pushを行っていない。

## M-14D-6 GM/admin向け 自分の依頼書一覧
- hidden/draftは公開calendarに出ないため、`session-post.html` にGM/admin向けの `自分の依頼書` 一覧を追加した。未ログインまたは通常PLには一覧を表示しない。
- 一覧は認証済みSupabase clientで `public.sessions` をSELECTし、RLSで見える範囲を表示する。取得・表示する情報はタイトル、開催日時、終了日時、公開状態、募集状態、Discord同期状態、作成日時、詳細導線に限定し、`gm_user_id`、email、user_id全文、token、key、secret、Discord credential類は取得・表示しない。
- M-14D-6bでcalendar側の常設 `自分の依頼書` 導線は削除し、依頼書一覧は `session-post.html` 内へ集約した。calendarの日付セルにある `＋依頼書` 導線は維持し、`session-post.html?date=YYYY-MM-DD` へ遷移できる。`詳細を見る` は `session-post.html?id=SESSION_ID#my-sessions` へ向けるが、下書き詳細表示、編集、削除、公開切替は次工程。
- Discord実送信、Edge Function deploy、public/recruiting投稿、テンプレート保存は実施していない。テンプレート保存はM-15系で扱う。詳細は `docs/session-posting-manage-list-result.md` に記録済み。

## M-14D-7b 自分の依頼書select化
- `session-post.html` の `自分の依頼書` は、カード一覧形式やスクロール付き一覧パネルを不採用にし、フォーム内の `公開状態` 欄の下段、`募集状態` の右隣付近にあるselect形式へ変更した。先頭項目は `新規依頼書を書く`、既存依頼書は `【募集状態・公開状態】YYYY/MM/DD HH:mm タイトル` の短い選択肢として表示する。
- select option の value にはSupabase row id / uuidを入れず、`manage-0`、`manage-1` のようなローカルキーだけを使う。対象レコードはJSメモリ上の配列から取得する。
- 既存依頼書を選ぶと、タイトル、開始日時、終了日時、申請締切、種別、募集人数min/max、公開状態、募集状態、概要をメインフォームへ即時反映する。巨大な `編集中: 依頼書タイトル` 見出しは削除し、ページ見出しは通常どおり `依頼書` のままにする。
- 編集モード中は作成ボタンをdisabledにし、Enter submitでも `create_session_post(...)` を呼ばないため、誤って重複新規作成されない。selectの `新規依頼書を書く` で選択解除、フォーム初期化、URLの `id` 除去を行い、新規作成モードへ戻れる。保存更新、公開切替、削除、募集終了、Discord実送信は未実装で次工程。
- `gm_user_id`、email、user_id全文、gmUserId、token、key、secret、Discord credential、Webhook URL、bot token、service_role、Supabase row id / uuidは画面・console・docsへ出さない。詳細は `docs/session-posting-manage-detail-result.md` に記録済み。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、Edge Function deploy、Discord実送信、`updates.json` 変更、commit / pushを行っていない。

## M-14D-7c 依頼書フォーム下部レイアウト調整
- M-14D-7bのselect化後、`自分の依頼書` selectにより `募集状態` と `概要` が下へ押し下げられ、左カラムに大きな空白が出る状態があった。M-14D-7cではselectを通常フォーム項目として扱い、`募集状態` の右隣付近に収めた。
- フォーム下部は `募集人数 max` / `公開状態`、`募集状態` / `自分の依頼書`、その下に全幅の `概要` となる。カード一覧形式、スクロール付き一覧パネル、大型パネル余白は復活させない。
- 機能はM-14D-7bのまま維持し、選択時のフォーム反映、`manage-0` 形式のローカルキー、編集モード中の作成ボタンdisabled、新規作成モードへの復帰、`p_end_at` / `end_at` 日跨ぎ対応は継続する。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、Edge Function deploy、Discord実送信、secret類の出力、`updates.json` 変更、commit / pushを行っていない。

## M-14D-7d 依頼書フォーム下部グリッド最終調整
- M-14D-7dで依頼書フォーム下部のグリッド整列を再修正し、PC幅では `募集人数 max` / `公開状態`、`募集状態` / `自分の依頼書（N件）`、その下に全幅の `概要` となるようにした。
- `自分の依頼書` は専用パネルではなく通常フォーム項目として扱う方針に統一し、`募集状態` とラベル上端・select上端が揃うようにした。
- 件数はラベルへ集約し、select下に単独で出ていた件数表示は削除した。カード一覧形式、スクロール付き一覧パネル、巨大な編集中見出しは復活させない。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、Edge Function deploy、Discord実送信、secret類の出力、`updates.json` 変更、commit / pushを行っていない。

## M-14D-8 update_session_post RPC / UI接続計画
- 下書き依頼書の編集保存へ進むため、SQL草案 `docs/supabase/sql/017_update_session_post_rpc_draft.sql` と設計docs `docs/session-posting-update-rpc-plan.md` を作成した。今回はSQL Editor実行、DB構造変更、RPC作成/置換、フロントUI接続実装は行っていない。
- 既存 `public.sessions.id` と `public.is_session_gm(text)` がtext前提のため、引き継ぎ案の `p_session_id uuid` は採用せず、草案では `p_session_id text` とした。人数引数も既存 `create_session_post` に合わせて `p_player_min` / `p_player_max` とする。
- 権限方針は `authenticated` のみEXECUTE、anon不可、GMは自分の依頼書のみ、adminは管理者権限で更新可。通常PLと他GMは拒否する。
- バリデーションはtitle/date/start必須、`end_at <= start_at` 拒否、許可済み `session_type` / `visibility` / `status`、public draft拒否、人数範囲、summary長を確認する方針。
- Discord同期メタデータは、public活動中ならpending化し、既存 `discord_message_id` の有無で `update` / `create` を分ける。hidden/draftで既存Discord投稿がなければskipped、既存投稿がある非公開化・下書き化・中止化は後続Edge Function向けにpending delete相当とする案。
- UI接続では既存依頼書選択中に `変更を保存` を出し、保存時に `update_session_post` を呼ぶ。raw id / uuidはDOMへ出さず、JSメモリ上の選択レコードからRPCへ渡す。保存成功後はselect表示とJSメモリ上の選択レコードを最新値に更新する。
- smoke test観点としてanon拒否、通常PL拒否、他GM拒否、対象GM成功、admin成功、invalid status/visibility拒否、min > max拒否、end_at <= start_at拒否、内部情報非露出、hidden/draftのpublic非表示維持、public/recruiting更新時のpending化を整理した。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC実行、Edge Function deploy、Discord実送信、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-8b update_session_post preflight準備
- `docs/supabase/sql/017_update_session_post_rpc_draft.sql` のSQL Editor貼り付け範囲を整理し、非破壊確認の `SECTION 1: PREFLIGHT ONLY` と、実適用用の `SECTION 2: APPLY` を明確に分離した。
- preflightはSELECTのみで、`public.sessions` 列一覧、`id` / `end_at` / `updated_at` / `discord_sync_*` 主要列型、`visibility` / `status` / `session_type` 関連制約、既存 `update_session_post` 有無、既存 `create_session_post` signature、GM/admin helper、anon/authenticated grant状況を確認する。
- apply sectionにはpreflight結果レビュー前に実行しない注意コメントを追加した。M-14D-8bではSQL Editor実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-8c update_session_post preflight専用ファイル化
- 固定行番号でpreflight範囲を抜き出す方式は、実適用SQLが混入したため破棄した。SQL Editor実行前に停止し、DB構造変更やRPC作成は行っていない。
- SQL Editorへ貼る対象として、SELECT-only専用ファイル `docs/supabase/sql/017_update_session_post_preflight_select_only.sql` を作成した。以後preflightはこのファイル全文を使い、`017_update_session_post_rpc_draft.sql` 本体から行番号で抜き出さない。
- 017本体には、固定行番号方式禁止、preflight専用ファイル使用、実適用section未実行を明記した。
- M-14D-8cではSQL Editor実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、フロントUI接続、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-8d update_session_post preflight結果記録
- ユーザーがSQL Editorで実行したのは `docs/supabase/sql/017_update_session_post_preflight_select_only.sql` のみ。`017_update_session_post_rpc_draft.sql` の実適用sectionは未実行で、CREATE FUNCTION / GRANT / REVOKE、DB構造変更、RPC作成は行っていない。
- preflightで `public.sessions` の想定列はすべて存在し、`id = text`、`end_at` / `application_deadline` / `updated_at` / Discord同期日時列は `timestamp with time zone`、`gm_user_id = uuid`、`start_time` / `end_time = time without time zone` と確認できた。
- 主要defaultは `session_type = 'one-shot'`、`status = 'recruiting'`、`visibility = 'public'`、`discord_sync_status = 'not_requested'`、`updated_at = now()`。許可値は `status = draft / tentative / recruiting / full / closed / finished / canceled`、`visibility = public / private / hidden`、`session_type = one-shot / campaign / special / other`、`discord_sync_status = not_requested / pending / posted / failed / skipped`、`discord_last_action = create / update / delete / close / resync`。
- `update_session_post` は未存在。`create_session_post` は1本のみ存在し、`p_end_at` 対応済み、`security_definer = true`。`has_role(text)` / `is_admin()` / `is_session_gm(text)` は存在し、戻り値boolean、`security_definer = true`、stable。確認範囲ではauthenticatedにEXECUTEがあり、anon grantは出ていない。
- SQL草案は `p_session_id text`、既存許可値、`security definer`、authenticated EXECUTE / anon不可の方針でpreflight結果と矛盾しない。DB/RPC草案では米国綴りの `canceled` に統一し、英国綴りは使わない。
- M-14D-8dではSQL Editor追加実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、フロントUI接続、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-8e update_session_post APPLY sectionレビュー
- `docs/supabase/sql/017_update_session_post_rpc_draft.sql` の `SECTION 2: APPLY` をSQL Editor実行前に最終レビューした。RPC名、`p_session_id text`、`p_player_min` / `p_player_max`、戻り値限定、`security definer`、`set search_path = ''` はpreflight結果と整合する。
- GM/admin制御は、未ログイン拒否、対象session未存在拒否、admin許可、対象GM許可、通常PL/他GM拒否の方針で確認した。入力値は既存constraint許可値に合わせ、`status` は `canceled` に統一している。
- Discord同期メタデータは実送信せず、許可値内の `pending` / `skipped` と `create` / `update` / `delete` / `close` で後続処理向けに更新する方針を確認した。
- 権限草案は `revoke execute ... from public`、`revoke execute ... from anon`、`grant execute ... to authenticated` を明示する形へ補強した。危険語チェックのノイズを減らすため、SQL草案内のcredential注意コメントを中立表現へ修正した。
- この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、CREATE FUNCTION実行、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、フロントUI接続、`updates.json` 変更、credential類の実値出力、commit / pushを行っていない。

## M-14D-8f update_session_post APPLY専用SQLファイル
- SQL Editorで実行する対象を固定するため、APPLY専用ファイル `docs/supabase/sql/017_update_session_post_apply_reviewed.sql` を作成した。以後apply時はこのファイル全文のみを貼り、`017_update_session_post_rpc_draft.sql` の全文は貼らない。
- APPLY専用ファイルには `create or replace function public.update_session_post(...)`、`security definer`、`set search_path = ''`、`revoke execute ... from public`、`revoke execute ... from anon`、`grant execute ... to authenticated`、実行後確認SELECTのみを入れた。preflight SELECT群、rollback草案、draft全文は含めない。
- preflight専用SQL `017_update_session_post_preflight_select_only.sql` とAPPLY専用SQL `017_update_session_post_apply_reviewed.sql` を分離済み。draft本体にも、apply時は専用ファイルを使いdraft全文を貼らない注意を追記した。
- M-14D-8fではSQL Editor実行、DB構造変更、RPC作成/置換、CREATE FUNCTION実行、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、フロントUI接続、`updates.json` 変更、credential類の実値出力、commit / pushを行っていない。

## M-14D-8g update_session_post APPLY結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/017_update_session_post_apply_reviewed.sql` を適用済み。`update_session_post` RPC作成と権限設定が完了した。
- 適用後確認結果は `function_count = 1`、`all_security_definer = true`、signatureは `update_session_post(text,text,text,text,text,text,text,integer,integer,text,text,text,text)`。
- 権限確認は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて期待値どおり `ok = true`。DB側の変更はRPC作成・権限設定のみで、テーブル構造変更はない。
- Discord実送信、Edge Function deploy、フロントUI接続、公開切替、削除、`updates.json` 変更、credential類の実値出力は行っていない。
- 次工程はM-14D-9として、`session-post.html` の既存依頼書編集モードに「変更を保存」UIを接続し、`update_session_post` を呼ぶ。

## M-14D-9 既存依頼書の変更保存UI接続
- `session-post.html` の既存依頼書編集モードに `変更を保存` ボタンを追加し、選択中の依頼書を `update_session_post` RPCで保存できるようにした。新規作成モードでは従来どおり `create_session_post` を使い、編集モード中は作成ボタンを非表示/disabledにして誤作成を防ぐ。
- 更新payloadは作成用と同じフォーム値整形を共通利用し、`p_end_at` / `end_at` 日跨ぎ対応、申請締切、種別、募集人数min/max、概要、公開状態、募集状態を維持する。`draft + public` はUI側でも保存前に拒否する。
- `p_session_id` はselect option valueから取らず、JSメモリ上の選択レコードから `update_session_post` へ渡す。select option valueは `manage-0` 形式のローカルキーのみで、raw id / uuidはDOM、画面、consoleへ出さない。
- 保存成功後は `変更を保存しました。` を表示し、select表示とJSメモリ上の選択レコードを最新化する。保存失敗時は既知RPCエラーを日本語表示し、未知エラーは `保存に失敗しました。` に丸める。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、公開切替専用UI、削除/募集終了UI、`updates.json` 変更、credential類の実値出力、commit / pushを行っていない。

## M-14D-10 公開切替まわりのUI整理
- 既存依頼書編集中に、`公開状態` / `募集状態` の選択へ連動する短い補助文を追加した。非公開または下書きは公開カレンダー非表示、公開系は公開カレンダー反映とDiscord通知未実装、終了系は募集終了扱いになることを示す。
- `draft + public` はUI側でも保存前に止める。該当時は `下書きは公開にできません。募集状態を変更するか、公開状態を非公開にしてください。` を表示し、`update_session_post` RPCを呼ばない。
- 保存成功メッセージは公開状態で出し分ける。非公開保存は従来どおり、公開保存は公開カレンダー反映とDiscord未実装を明示する。
- 公開切替専用の大型UI、削除/募集終了専用UIは追加していない。既存のselect、フォーム反映、`変更を保存`、新規作成モード、raw id / uuid非表示方針は維持する。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-10.5 session-detail編集導線改善
- `session-detail.html` の基本情報グリッド右下に編集 / 削除ボタン枠を追加した。PC幅では編集50% / 削除50%の横並びで、右下の空きエリアを使う。
- 編集ボタンはSupabase由来の公開依頼書で、ログイン中ユーザーが `is_admin()` または `is_session_gm(target_session_id)` を満たす場合だけ有効化する。有効時は `session-post.html?id=<session_id>#my-sessions` へ遷移し、既存の自分の依頼書select復元へつなぐ。
- 削除ボタンはdisabled配置のみ。DB削除、status変更、visibility変更、削除RPC呼び出しは行っていない。
- 開催時刻は開始側にも年月日を出すよう修正し、`2026-06-08 21:00〜2026-06-09 09:47` のように表示できるようにした。
- `session-post.html` 側は編集状態の補助文を明確化し、指定IDが自分の依頼書一覧にない場合もIDを表示せず短文エラーにする。select option valueは `manage-0` 形式だけを維持する。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、admin全件管理UI、削除/募集終了本実装、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-11A admin管理対象select整理
- adminをヴェルガルド公開サイト内の全権限ユーザーとして扱う方針で、`session-post.html` の依頼書selectを整理した。通常GMは自分が作成した依頼書のみ、adminは既存RLS/APIで取得できるSupabase由来依頼書を管理対象として扱う。
- admin判定は既存 `is_admin()`、投稿権限は既存 `has_role('gm')` / `is_admin()` を使う。`session-detail.html` の編集ボタンはSupabase由来かつ `is_admin()` または `is_session_gm(target_session_id)` が通る場合だけ有効のまま。
- select option valueは `manage-0` 形式を維持し、表示ラベルは `【自分】` / `【管理】` を付ける。raw id / uuid / user_id / email / token はDOM、画面、consoleへ出さない。
- adminで管理対象取得に失敗した場合は、画面に `管理対象の依頼書を取得できませんでした。管理用RPCの追加が必要です。` と表示する。既存RLS/APIで全件取得できない場合は、後続でlist/update用の管理RPC追加が必要。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、削除/募集終了本実装、Discord resync UI、service_role key利用、フロントからのDB直UPDATE、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-12A 削除相当操作と募集終了補助文
- `session-detail.html` の削除ボタンを、物理削除ではなく既存 `update_session_post` RPC で `visibility = hidden` / `status = canceled` を保存する削除相当操作へ接続した。既存のタイトル、日時、概要、募集人数、種別、締切、`end_at` は維持する。
- 削除相当操作は Supabase由来かつ admin または作成者GMのみ実行可。静的JSON由来、通常PL、他GMでは削除ボタンを disabled のままにし、静的JSON由来では削除できない理由を表示する。
- 成功時は `この依頼書を非公開・中止扱いにしました。` と表示し、詳細画面の公開状態/募集状態も `非公開` / `中止` に更新する。失敗時は `login_required`、`not_allowed`、`session_not_found` を日本語へ丸め、未知エラーは削除相当操作失敗として表示する。
- `session-post.html` の募集状態selectに `closed` / `finished` / `canceled` を追加し、募集終了、開催終了、中止の補助文を整理した。既存の編集ボタン、`session-post.html?id=...` 復元、自分の依頼書select、admin管理対象select、変更保存、`draft + public` ガード、`p_end_at` / 日跨ぎ対応、hidden/draft の公開calendar非表示は維持する。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、物理削除、Discord実送信、Edge Function deploy、Discord resync UI、service_role key利用、フロントからのDB直UPDATE、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-13A 削除方針変更追記
- M-14D-13A時点では soft delete = `visibility = hidden` / `status = canceled` としてQA確認済み。ただし運用方針として、削除ボタンは完全削除へ変更する。
- `hidden` / `canceled` は「中止として残す」操作として扱う。完全削除は後続で `delete_session_post` RPC を新設して実装する。
- `session-detail.html` だけでなく、`session-post.html` 編集画面にも削除ボタンを置く。削除前には確認ポップアップを出し、確認文には「中止として残したい場合は募集状態を中止にする」旨を含める。
- この追記でCodexはSQL Editor実行、DB変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-14D-13B delete_session_post RPC preflight / 草案
- 完全削除用 `delete_session_post` RPC の設計docs `docs/session-posting-delete-rpc-plan.md`、SELECT-only preflight `docs/supabase/sql/018_delete_session_post_preflight_select_only.sql`、未実行RPC草案 `docs/supabase/sql/018_delete_session_post_rpc_draft.sql` を追加した。
- `hidden` / `canceled` は「中止として残す」操作として維持し、削除ボタンは後続で完全削除RPCへ接続する。フロントからDB直DELETEは行わない。
- RPC草案は `delete_session_post(p_session_id text)`、戻り値 `deleted_session_id text` / `deleted_at timestamptz`、authenticatedのみEXECUTE、adminまたは対象GMのみ許可、通常PL/他GM/静的JSON由来は削除不可の方針。
- preflightでは `public.sessions` 主キー、`id` 型、sessions参照FK、ON DELETE、`session_id` 列を持つテーブル、申請/コメント/連絡先/履歴候補テーブル、既存 `delete_session_post`、helper、`update_session_post` 権限、anon/authenticated/PUBLIC routine権限をSELECTだけで確認する。
- 関連データとして `session_applications`、`session_comments`、申請履歴、Discord連絡先表示、Discord同期メタデータ、session-detail、calendar、mypageへの影響を記録した。FKがCASCADEなら関連行も消える可能性があり、RESTRICT / NO ACTIONならAPPLY前に草案改訂が必要。
- Discord実送信は行わない。`discord_message_id` がある場合は将来Edge Functionで削除同期が必要。Edge Function未実装の間は公開済み完全削除前に強い確認を出し、「中止として残したい場合は、削除せず募集状態を中止にしてください」という趣旨を入れる。
- この工程でCodexはSQL Editor未実行、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、Discord実送信なし、Edge Function deployなし、service_role key利用なし、secret類の出力なし、`updates.json` 変更なし、commit / pushなし。

## M-14D-13B preflight結果記録
- ユーザーがSQL Editorで実行したのは `018_delete_session_post_preflight_select_only.sql` のSELECT-only preflightのみ。`018_delete_session_post_rpc_draft.sql`、`delete_session_post` RPC本体、CREATE FUNCTION、GRANT / REVOKE、DELETE、DB構造変更は未実行。
- `public.sessions` を参照する外部キーは `session_applications_session_id_fkey` と `session_comments_session_id_fkey` の2件だけで、どちらも `ON DELETE CASCADE`。
- `session_id` 列を持つpublic base tableも `session_applications` / `session_comments` のみで、現時点で迷子になりそうな外部キーなし `session_id` テーブルは見当たらない。
- 完全削除では依頼書本体だけでなく、該当セッションの参加申請・参加希望コメントもDB制約で削除される。後続UIの確認文には `削除すると、依頼書本体に加えて参加申請・コメントも削除されます。` を明記する。
- SQL草案は `delete_session_post(p_session_id text)`、`security definer`、安全な `search_path`、`auth.uid()` 確認、adminまたは作成者GMのみ許可、静的JSON対象外、対象1件のWHERE付きDELETE、最小戻り値、`public` / `anon` revokeと `authenticated` grant方針で、preflight結果と矛盾しない。
- この工程でCodexはSQL Editor追加実行なし、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、Discord実送信なし、Edge Function deployなし、service_role key利用なし、secret類の出力なし、`updates.json` 変更なし、commit / pushなし。

## M-14D-13C delete_session_post APPLY専用SQLファイル
- SQL Editorで実行する対象を固定するため、APPLY専用ファイル `docs/supabase/sql/018_delete_session_post_apply_reviewed.sql` を作成した。今後SQL Editorで実行する場合はこのファイル全文のみを使い、`018_delete_session_post_rpc_draft.sql` の全文は貼らない。
- APPLY専用ファイルには `create or replace function public.delete_session_post(p_session_id text)`、`security definer`、`set search_path = ''`、`auth.uid()` 確認、対象session存在確認、adminまたは作成者GMのみ許可、`public.sessions` 対象1件のWHERE付きDELETE、function comment、`public` / `anon` revoke、`authenticated` grant、実行後確認SELECTを入れた。
- GM許可は既存更新RPC方針に合わせ、`public.has_role('gm')` かつ `sessions.gm_user_id = auth.uid()` とした。admin判定は `public.is_admin()` を使う。
- `session_applications` / `session_comments` はM-14D-13B preflightで確認した `ON DELETE CASCADE` に任せる。Discord実送信やEdge Function呼び出しは含めない。
- この工程でCodexはSQL Editor実行なし、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、フロントUI接続なし、Discord実送信なし、Edge Function deployなし、service_role key利用なし、secret類の出力なし、`updates.json` 変更なし、commit / pushなし。

## M-14D-13C delete_session_post APPLY結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/018_delete_session_post_apply_reviewed.sql` を適用し、`delete_session_post` RPC作成と権限設定が完了した。
- 適用後確認は `function_count = 1`、`all_security_definer = true`、signatureは `delete_session_post(text)`。
- 権限確認は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて期待値どおり `ok = true`。
- DB側の変更はRPC作成・権限設定のみ。実データ削除、Discord実送信、Edge Function deploy、secret類の出力、`updates.json` 変更は行っていない。
- 次工程はM-14D-13Dとして、`session-detail.html` / `session-post.html` の削除ボタンを `delete_session_post` RPCへ接続する。

## M-14D-13D session post delete RPC UI connection
- `session-detail.html` と `session-post.html` 編集画面の削除ボタンを `delete_session_post` RPCへ接続した。
- 削除ボタンは完全削除として扱い、`visibility = hidden` / `status = canceled` は「中止として残す」操作として維持する。
- 完全削除では依頼書本体に加えて `session_applications` / `session_comments` もDB制約で削除されるため、確認文へ影響を明記した。
- `session-post.html` 編集画面では既存依頼書編集中のみ削除ボタンを表示し、削除成功後は管理対象selectとJSメモリから対象を外して新規作成モードへ戻す。
- 静的JSON由来は編集不可・削除不可のまま維持し、`delete_session_post` RPCへ流さない。
- SQL Editor追加実行、DB構造変更、RPC変更、GRANT/REVOKE再実行、実データ削除、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## M-14D-14A static session retirement planning
- `data/sessions.json` 由来の静的依頼書 / セッション予定7件を棚卸しし、Supabase移行候補、旧モック / テストデータ削除候補、一時的に残す候補を整理した。
- 退役計画docs `docs/session-posting-static-retirement-plan.md` を作成し、現在の静的JSON由来データの役割、Supabase移行済み機能、静的JSONを残すリスク、削除前確認、段階的な退役手順、停止条件を記録した。
- `session-2026-06-08-railway-incident` は既存QA / mypage突合 / URL互換で参照が多いため、いきなり削除せずSupabase移行候補かつ一時残存対象とした。
- `closed` / `finished` / `tentative` / `full` の静的予定は表示fixtureとしての代替確認後に削除候補、`canceled` の静的予定は現行calendar/detailで非表示のため強い削除候補とした。
- `loadMergedSessions()` は静的JSONを先に読み、同じIDのSupabase行を後から追加しないため、同ID移行時はURL互換と静的行退役の順序確認が必要。
- 今回はいきなり削除しない。`data/sessions.json` 削除 / 大規模編集、Supabase投入、SQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## M-14D-14B static/Supabase merge priority
- `assets/js/sessionData.js` のマージ優先順位を変更し、同じIDではSupabase由来を優先、`data/sessions.json` はfallbackとして扱うようにした。
- 静的JSON行には `source: "static"` を付与し、Supabase行は `source: "supabase"` を維持するため、`session-detail.html` の編集不可・削除不可表示とSupabase編集権限判定を壊さない。
- Supabase側で取得できた同ID行が `visibility = hidden`、`status = draft` / `canceled` / `cancelled` の場合も静的JSON fallbackを置き換え、calendar/detail側の既存フィルタで非表示にする。これにより非公開化・下書き化・中止化した予定が静的JSONから復活しない。
- `data/sessions.json` はまだ削除していない。Supabaseへのデータ投入、SQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## DiscordユーザーID登録UI 前提整備
- テンプレート機能の前提として、Discord連絡先登録を17〜20桁の数字である `DiscordユーザーID` として扱う方針へ寄せた。`<@ID>` 形式は互換として受け付けるが、保存前に数字部分だけへ正規化する。
- mypageの本人登録UIでは赤字注意文、入力例、折りたたみ式の確認方法を表示し、保存前に `^\d{17,20}$` 相当の形式チェックを行う。桁数不正、英字混じり、改行入り、`<@abc>`、`@123456789012345678` は保存しない。空欄は未登録扱いとして維持する。
- 保存成功後は、RPC返却が空でも保存に使った正規化済みDiscordユーザーIDで本人画面の表示を即時更新する。登録済み値が形式不正の場合は自動変換せず、再登録を促す。
- GM向け承認済み参加者連絡先表示では、保存された数字IDから `<@DiscordユーザーID>` を生成して表示・コピーする。未登録または形式不正の場合は生表示を避けて `登録されていません` に丸める。
- 呼び出し用テンプレートではGMが承認済み参加者を一人ずつ選ぶ方式にせず、現在のセッションに紐付く承認済み参加者全員を対象にしてコピー時に変数をまとめて置換する。
- 初期実装で優先する変数は `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` とする。`{{approved_call_list}}` は `Discord：<@DiscordユーザーID>｜ユーザー名：ユーザー名｜PC名：PC名` のラベル付き1人1行で出力し、DiscordユーザーID未登録/形式不正は `Discord：登録されていません`、PC名未登録は `PC名：PC名未登録` と出す方針を推奨する。
- `{{approved_discord_mentions}}` はDiscordメンションだけをまとめて出す変数として残してよいが、`{{approved_discord_ids}}` とGMが一人ずつ選ぶ方式は初期実装では見送る。
- 方針docs `docs/discord-mention-registration-plan.md` を追加した。この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、テンプレート保存テーブル作成、テンプレート生成UI、`{{approved_call_list}}` の実際の置換処理、テンプレート保存機能本体、PC名登録機能、mypage予定プルダウン化、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## session-detail GM本人コメントの参加人数除外
- GM本人コメントが参加人数にカウントされる不具合を修正した。Supabase由来セッションでは `gm_user_id` をJS内部判定用に読み込み、ログイン中ユーザーが対象GM本人かを内部比較する。raw Supabase `user_id` / email / token / `gmUserId` は画面、DOM、consoleへ出さない。
- GM本人コメントは許可する。GM本人にはPL向けの参加申請導線ではなく、`GMとして管理中です。参加申請は不要です。` と `GMコメントとして投稿されます。参加申請には含まれません。` を表示し、GMコメント投稿フォームを残す。
- GM本人が投稿した場合は既存 `create_application_comment` の後に既存 `cancel_my_session_application` を呼び、GM本人の申請行を `canceled` へ戻す。これにより参加人数、mypageの申請中/参加予定、承認済み参加者連絡先にGM本人を含めない方針とした。
- GMコメント削除時の確認文をPL参加希望コメント用から分離した。GMコメント削除では `このGMコメントを削除しますか？` と `参加申請には影響しません。` を表示し、PL参加希望コメント削除時の既存注意文は維持する。
- GM/admin文脈の人数表示は、RLSで許可された `session_applications` の `user_id` / `status` を内部取得し、GM本人を除外して `pending` / `waitlisted` / `accepted` を再集計する。公開カウントRPC自体は今回変更しない。
- GM向け申請履歴と承認済み連絡先は、現行RPCが内部 `user_id` を返さないため、GM本人のユーザー名を使ったbest-effort除外とした。厳密化は後続でRPC側にGM本人除外条件を入れる候補。
- adminコメントの扱い、GMコメント専用種別、既存DB上のGM本人申請/コメントcleanupは後続課題とする。この工程ではSQL Editor実行、DB構造変更、`comment_type` 列追加、RPC作成/置換、GRANT/REVOKE、既存データcleanup、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## M-15A PC名登録・テンプレート変数前提設計
- PC名登録とテンプレート変数 `{{session_title}}` / `{{approved_call_list}}` / `{{approved_pc_names}}` の前提設計を実施した。新規docs `docs/player-character-registration-plan.md` を追加し、PC名保存方式、mypage登録方針、参加申請との紐付け、後続SQL/RPC候補、段階実装案を整理した。
- PC名保存方式は `profiles.default_pc_name`、`player_characters`、`session_applications.pc_name_snapshot` を比較した。推奨は `player_characters` でPC名を管理し、`session_applications` に `selected_character_id` と `pc_name_snapshot` を持たせる複合案。
- 初期実装ではmypageのデフォルトPCを参加申請時に自動採用し、後続で参加申請時PC選択へ拡張する。テンプレート出力では `pc_name_snapshot` を正とし、PC名未登録は `PC名未登録` と出す。
- 後続候補は、M-15B SQL草案、M-15C SQL適用結果記録、M-15D mypage PC名登録UI、M-15E 参加申請へのPC名スナップショット接続、M-15F GM向け承認済み参加者情報のPC名対応、M-15G テンプレート変数置換UI。
- この工程でCodexはSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、フロントUI実装、テンプレート保存機能本体、PC名登録UI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15B PC名登録・参加申請PC紐付けSQL草案
- PC名登録用preflight SELECT-only SQL `docs/supabase/sql/019_player_characters_preflight_select_only.sql` を作成した。`profiles`、`session_applications`、既存 `player_characters`、`selected_character_id` / `pc_name_snapshot`、PC名関連RPC候補、helper関数、routine privileges、RLS policy候補を確認する。
- PC名登録・参加申請PC紐付け用SQL草案 `docs/supabase/sql/019_player_characters_rpc_draft.sql` を作成した。`player_characters` テーブル、`session_applications.selected_character_id` / `pc_name_snapshot`、PC名管理RPC、参加申請時のdefault PC自動採用、テンプレート用 `get_gm_session_approved_template_data(target_session_id text)` 候補を含めた。
- 設計docs `docs/player-character-registration-sql-plan.md` を追加し、player_charactersテーブル案、session_applications追加列案、RPC案、参加申請との紐付け方針、`{{approved_call_list}}` / `{{approved_pc_names}}` との関係、段階実装案を整理した。
- 既存 `get_gm_session_accepted_contacts(target_session_id text)` は現行JSの返却列検査と結びついているため、M-15BではすぐPC名付きへ置換せず、テンプレート用別RPC候補を優先した。
- 当時の次工程候補はM-15Cとしてpreflight結果記録とSQL草案レビューだった。今回CodexはSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15B PC名登録SQL preflight結果・草案点検
- ユーザーがSupabase SQL Editorで実行したのは `019_player_characters_preflight_select_only.sql` のSELECT-only preflightのみ。`019_player_characters_rpc_draft.sql`、CREATE TABLE、ALTER TABLE、CREATE FUNCTION、GRANT / REVOKE、DB構造変更、RPC作成は未実行。
- preflightで `player_characters`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot` は未作成と確認した。`profiles.id` は uuid / NOT NULL の主キーで `auth.users(id)` を `ON DELETE CASCADE` 参照し、`session_applications.user_id` は `profiles(id)`、`session_applications.session_id` は `sessions(id)` を参照する。
- `session_applications` には既存どおり `UNIQUE(session_id, user_id)` と `PRIMARY KEY(id)` がある。`comment_id` は `session_comments(id)` 参照の既存制約を維持する。
- SQL草案は、`player_characters.owner_user_id` を `public.profiles(id)` 参照、`selected_character_id` を `player_characters(id) on delete set null`、`pc_name_snapshot` を nullable text とする方針で実DB状態と矛盾しない。
- PC名は物理削除ではなく `is_active = false` を基本にし、過去申請とテンプレート出力では `pc_name_snapshot` を正とする。
- 次工程はM-15Cとして `019_player_characters` APPLY専用SQL作成・最終レビュー、M-15DとしてSQL Editor適用、M-15Eとしてmypage PC名登録UIへ進む想定。
- 今回CodexはSQL Editor追加実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15C PC名登録APPLY専用SQL
- M-15Cとして `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を作成した。SQL Editorで実行する場合はこのAPPLY専用ファイル全文のみを使い、draft全文は貼らない。
- preflight / draft / apply を分離した。preflightはSELECT-only、draftは検討用、applyはレビュー済み実行対象。
- APPLY専用SQLには `player_characters` テーブル、`session_applications.selected_character_id` / `pc_name_snapshot`、必要なconstraint / index、default PC部分unique index、updated_at trigger、本人select RLS policy、PC管理RPC 5本、権限設定、実行後確認SELECTを含めた。
- PC名は物理削除ではなく `is_active = false` を基本とし、テンプレート / 履歴表示では `pc_name_snapshot` を正とする。
- 参加申請RPC置換、default PCの申請時自動採用、テンプレート用RPC、フロントUI実装は後続に分離した。GMコメントは参加申請扱いしない方針、辞退 / 再申請時のPC名扱いは後続で整理する。
- APPLYはまだ未実行。今回CodexはSQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE実行、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15D PC名登録APPLY結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を適用し、PC名登録・参加申請PC紐付け用DB変更が完了した。
- `player_characters` table、`player_characters.id` / `owner_user_id` / `pc_name` / `is_default` / `is_active`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot` は作成済みで、確認結果はすべて `ok = true`。
- `player_characters.owner_user_id` は `profiles(id)`、`session_applications.selected_character_id` は `player_characters(id)` を参照するFKとして確認済み。
- PC管理RPC 5本、`get_my_player_characters()`、`create_player_character(text, boolean)`、`update_player_character(uuid, text, boolean, boolean)`、`set_default_player_character(uuid)`、`deactivate_player_character(uuid)` は作成済み。各RPCは `security_definer = true`。
- RPC権限は `authenticated EXECUTEあり`、`anon / public EXECUTEなし` で、すべて `ok = true`。
- 実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、secret類の出力、`updates.json` 変更は行っていない。次工程はM-15Eとして mypage PC名登録UI。
- 今回CodexはSQL Editor追加実行、DB構造追加変更、RPC再作成、GRANT / REVOKE再実行、実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。
## M-15E mypage PC名登録UI
- mypageのログイン済み表示にPC名登録UIを追加した。PC名の新規登録、一覧表示、編集、既定PC設定、一覧から外す操作を扱う。
- 既存RPC `get_my_player_characters()`、`create_player_character(text, boolean)`、`update_player_character(uuid, text, boolean, boolean)`、`set_default_player_character(uuid)`、`deactivate_player_character(uuid)` へ接続した。
- PC名は空欄、改行、40文字超過を保存前に止める。未登録時は「現在、登録済みPC名はありません。」を表示する。
- 一覧から外す操作は物理削除ではなく `is_active = false` 相当の非アクティブ化として扱い、過去申請のPC名スナップショットは残る前提を確認文に入れる。
- raw DB uuid / Supabase user_id / email / token / secret類は画面、DOM、consoleに出さない。DOM上の操作キーは `pc-0` などのローカル値のみ。
- 参加申請時の `selected_character_id` / `pc_name_snapshot` 保存、承認済み参加者一覧へのPC名表示、テンプレート変数 `{{approved_call_list}}` / `{{approved_pc_names}}` 置換は後続M-15F以降。
- SQL Editor実行なし、DB構造変更なし、RPC変更なし、GRANT / REVOKEなし、Discord実送信なし、Edge Function deployなし、`updates.json` 変更なし、commit / pushなし。

## M-15F 参加申請PC名スナップショットRPC草案
- 参加申請コメント投稿時に、本人の既定PCを `session_applications.selected_character_id` / `pc_name_snapshot` へ自動保存するRPC草案を作成した。
- preflight専用SQL `docs/supabase/sql/020_application_pc_snapshot_preflight_select_only.sql` を作成した。SELECT-onlyで関係列、関数契約、権限、RLSを確認する。
- RPC草案 `docs/supabase/sql/020_application_pc_snapshot_rpc_draft.sql` を作成した。`create_application_comment(target_session_id text, comment_body text)` のシグネチャを維持し、フロントからPC名、ユーザー名、DiscordユーザーID、character idを渡さない。
- 参加申請コメントは自由本文とし、コメント本文に識別情報を書かせない。ユーザー名は `profiles.display_name`、DiscordユーザーIDは `profiles.discord_handle`、PC名は `player_characters` の既定PCから取得する。
- 既定PCがない場合も参加申請を許可し、`selected_character_id` / `pc_name_snapshot` は `null` とする。
- 辞退済みからの再申請では、その時点の既定PCでsnapshotを更新する。コメント編集時はsnapshotを維持する。
- GM本人コメントは許可するが参加申請として扱わない。GMコメントは `session_comments.is_application = false` とし、参加人数、申請者一覧、承認済み連絡先、テンプレート変数対象から除外する。
- M-15GではGM向け承認済み参加者一覧/連絡先表示にPC名を含める。M-15Hでは `{{session_title}}` / `{{approved_call_list}}` / `{{approved_pc_names}}` のテンプレート変数接続を行う。
- SQL Editor未実行、DB構造変更なし、RPC作成/置換なし、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、secret類なし、commit / pushなし。

## M-15D補正 selected_character_id FK ON DELETE SET NULL
- M-15D適用後確認で、`session_applications.selected_character_id` のFKに `ON DELETE SET NULL` が付いていないことを確認した。
- 期待方針は `FOREIGN KEY (selected_character_id) REFERENCES player_characters(id) ON DELETE SET NULL`。
- M-15Fへ進む前に補正する方針として、SELECT-only preflight `docs/supabase/sql/021_fix_selected_character_fk_preflight_select_only.sql` を作成した。
- APPLY専用SQL `docs/supabase/sql/021_fix_selected_character_fk_apply_reviewed.sql` を作成した。既存FKをdropし、`ON DELETE SET NULL` 付きで同名FKを作り直す内容。
- APPLY末尾に、FK存在、参照先 `player_characters(id)`、definition内の `ON DELETE SET NULL` / `confdeltype = 'n'` 相当を確認するSELECTを入れた。
- SQL Editor未実行、DB構造変更なし、ALTER TABLE未実行、RPC変更なし、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15D補正 selected_character_id FK preflight結果
- ユーザーがSupabase SQL Editorで `021_fix_selected_character_fk_preflight_select_only.sql` を実行した。
- `selected_character_fk_has_on_delete_set_null = true` と確認され、現DB上では `session_applications.selected_character_id` FKはすでに `ON DELETE SET NULL` 相当だった。
- `021_fix_selected_character_fk_apply_reviewed.sql` は未実行で、現時点では実行不要と判断する。
- 前回の `ON DELETE SET NULL` 不足は、表示上の見切れまたは確認不足だった可能性として扱う。
- DB追加変更なし、ALTER TABLE未実行、RPC変更なし、GRANT / REVOKE未実行。
- 次はM-15Fとして、参加申請PC名スナップショット接続へ戻る。

## M-15F application PC snapshot preflight確認結果
- 修正版 `020_application_pc_snapshot_preflight_select_only.sql` はSQL Editorで `array_agg` aggregate function エラーにより途中停止した。SELECT-only preflight中のエラーでDB変更なし。
- 小型確認SQLで、`player_characters`、`selected_character_id`、`pc_name_snapshot`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` の存在を確認済み。
- `session_applications.status` 許可値は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled`。M-15F草案の `pending` / `canceled` と矛盾しない。
- 主要RPCとhelper関数は `security_definer = true`。対象RPCは `authenticated EXECUTE` ありで、確認画面では `anon` / `public` EXECUTEは出ていない。
- 020 preflight SQLから `pg_get_functiondef` と不要な集約表示を外し、signature / arguments / result / security definer / privileges確認に絞った。
- 020 RPC草案は既存signature、PC名未登録許可、GMコメント非申請扱い、新規PL申請時snapshot、再申請時snapshot更新、コメント編集時snapshot維持の方針と一致する。
- SQL Editor追加実行なし、DB構造変更なし、RPC作成なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15F application PC snapshot preflight成功
- 修正版 `020_application_pc_snapshot_preflight_select_only.sql` をSupabase SQL Editorで実行し、preflightは成功した。前回の `array_agg` aggregate function エラーは解消済み。
- `player_characters`、`selected_character_id`、`pc_name_snapshot`、`UNIQUE(session_id, user_id)`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` の存在を確認済み。
- `session_applications.status` 許可値は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled`。
- 主要RPCとhelper関数は `security_definer = true`。対象RPCは `authenticated EXECUTE` ありで、確認画面では `anon` / `public` EXECUTEなしの方向。
- `table_privileges` で `REFERENCES` / `TRIGGER` / `TRUNCATE` 等の表示を確認したが、これは権限一覧の読み取り結果であり、今回SQLがTRUNCATE等を実行したものではない。
- 後続実装ではフロントからDB直操作を行わず、RPC経由方針を維持する。
- `020_application_pc_snapshot_rpc_draft.sql` はpreflight結果と矛盾しない。
- SQL Editor追加実行なし、DB構造変更なし、RPC作成なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15F application PC snapshot APPLY専用SQL作成
- 参加申請時にPC名snapshotを保存するAPPLY専用SQL `docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` を作成した。
- 対象は `create_application_comment(text,text)` の置換のみ。SQL Editorで適用する場合はAPPLY専用ファイルを使い、`020_application_pc_snapshot_rpc_draft.sql` の全文は貼らない。
- 参加申請コメント本文にPC名、DiscordユーザーID、ユーザー名を書かせない。コメント本文はPLの自由本文として維持する。
- PLの新規申請と辞退済みからの再申請では、本人のactive default PCを `selected_character_id` / `pc_name_snapshot` へ保存する。PC名未登録でも申請可能で、snapshot列は `null`。
- GMコメントは投稿可能だが参加申請扱いにしない。`session_comments.is_application = false` とし、`session_applications` の作成/更新やPC snapshot保存は行わない。
- コメント編集時はsnapshotを維持する。再申請時のみ、その時点の既定PCでsnapshotを更新する。
- APPLY専用SQLには `authenticated` のみEXECUTEを許可する権限文と、関数本数、`security_definer`、signature、EXECUTE権限、snapshot列の存在を確認するSELECTを含めた。
- APPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15F application PC snapshot APPLY前レビュー修正
- `020_application_pc_snapshot_apply_reviewed.sql` の管理コメント判定を `public.is_admin() or public.is_session_gm(v_target_session_id)` に修正した。
- adminが他GMのセッションへコメントした場合も管理コメント扱いとし、PL参加申請、`session_applications` 作成/更新、PC snapshot保存を行わない。
- `session_comments.body` へ保存する値を、元の `comment_body` ではなくtrim後の `v_comment_body` に修正した。コメント本文は自由本文のまま維持し、前後空白だけ保存しない。
- SQL Editor未実行、DB構造変更なし、RPC作成/置換実行なし、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15F application PC snapshot APPLY結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` を適用した。
- `create_application_comment(text,text)` の置換は成功した。
- 確認結果は `function_count = 1`、`all_security_definer = true`、signature `create_application_comment(text,text)`、`search_path` 設定あり。
- 権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて `ok = true`。
- `session_applications.selected_character_id` / `pc_name_snapshot` の存在を確認済み。
- PL新規申請・再申請時は既定PCをsnapshotする。PC名未登録でも申請可能。
- GM/admin管理コメントでは参加申請扱いせずsnapshotしない。参加申請コメント本文は自由本文で、PC名やDiscordユーザーIDを本文に書かせない。
- 実データ投入なし、フロントUI変更なし、参加申請UI変更なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15F application PC snapshot 実動作確認
- 通常PLの参加申請で `session_applications.pc_name_snapshot` に既定PC名が保存され、`selected_character_id` も紐付くことを確認した。
- SQL確認では `linked_pc_name` と `pc_name_snapshot` が一致した。
- `status = accepted` の申請でもPC名snapshotが保持されていた。
- PC名やDiscordユーザーIDを参加申請コメント本文へ書かせるのではなく、登録情報から自動で紐付ける方針が成立している。
- raw user_id / application_id / selected_character_id の実値、ユーザー名、PC名の実値は記録しない。
- SQL Editor追加実行なし、DB追加変更なし、RPC変更なし、フロントUI変更なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G GM向け承認済み参加者PC名表示RPC準備
- GM/admin向け承認済み参加者連絡先にPC名を追加するため、preflight専用SQL `docs/supabase/sql/022_gm_accepted_contacts_pc_name_preflight_select_only.sql` を作成した。
- RPC草案 `docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql` と設計docs `docs/gm-accepted-contacts-pc-name-plan.md` を作成した。
- 既存 `get_gm_session_accepted_contacts(text)` は `display_name` / `discord_handle` の2列を返し、現行フロントも2列のみ許可している。後続では既存列を維持しつつ `discord_mention` / `pc_name` / `pc_name_missing` を追加する方針。
- PC名は `session_applications.pc_name_snapshot` を正とし、未登録時は `PC名未登録` とする。
- DiscordユーザーIDは `profiles.discord_handle` から `<@ID>` へ変換表示し、未登録または形式不正は `登録されていません` とする。生の不正値は返さない。
- GM本人は承認済み参加者一覧から除外し、raw user_id / email / token / selected_character_id / application_id は返さない。
- SQL Editor未実行、DB構造変更なし、RPC変更なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G GM向け承認済み参加者PC名表示RPC preflight結果
- ユーザーが `022_gm_accepted_contacts_pc_name_preflight_select_only.sql` をSupabase SQL Editorで実行し、既存 `get_gm_session_accepted_contacts(text)` は `display_name` / `discord_handle` の2列返却と確認した。
- 既存RPCは `security_definer = true`、`search_path` 設定あり。`authenticated EXECUTEあり`、`anon` / `public EXECUTEなし`。
- PC名表示には戻り値列追加が必要。既存列 `display_name` / `discord_handle` は維持し、追加列候補は `discord_mention` / `pc_name` / `pc_name_missing`。
- 同名RPCで戻り値型を変更する場合はdrop/recreateが必要になる可能性がある。後続APPLYではdrop/recreate案とv2 RPC案をレビューする。
- `pc_name` は `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録`。過去申請にはsnapshotなしが混在するためfallback必須。
- DiscordユーザーIDは17〜20桁の数字のみ `<@ID>` に変換し、未登録/形式不正は `登録されていません`。生の不正値は返さない。
- GM本人は承認済み参加者一覧から除外し、raw user_id / email / token / selected_character_id / application_id は返さない。
- SQL Editor追加実行なし、DB構造変更なし、RPC作成/置換なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G GM向け承認済み参加者PC名表示RPC APPLY専用SQL
- GM/admin向け承認済み参加者一覧へPC名を返すため、APPLY専用SQL `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を作成した。
- 既存 `get_gm_session_accepted_contacts(text)` は `display_name` / `discord_handle` の2列返却だったため、戻り値型変更に備えてdrop/recreate方針を採用した。
- 既存列 `display_name` / `discord_handle` は維持し、追加列は `discord_mention` / `pc_name` / `pc_name_missing`。
- `pc_name` は `session_applications.pc_name_snapshot` を正とし、PC名未登録時は `PC名未登録`。
- DiscordユーザーID未登録・形式不正時は `登録されていません` とし、生の不正値は返さない。
- GM本人は承認済み参加者一覧から除外し、raw user_id / email / token / selected_character_id / application_id は返さない。
- APPLY専用SQL末尾に、関数本数、signature、`security_definer`、`search_path`、戻り値列、EXECUTE権限の実行後確認SELECTを含めた。
- APPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G GM向け承認済み参加者PC名表示RPC APPLY結果
- ユーザーが `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` をSupabase SQL Editorで適用した。
- `get_gm_session_accepted_contacts(text)` のdrop/recreateは成功した。
- 確認結果は `function_count = 1`、`all_security_definer = true`、`has_search_path_config = true`、signature `get_gm_session_accepted_contacts(text)`。
- 戻り値列は `display_name` / `discord_handle` / `discord_mention` / `pc_name` / `pc_name_missing`。各列の存在確認はtrue。
- 権限は `authenticated EXECUTEあり`、`anon` / `public EXECUTEなし` で、すべて `ok = true`。
- 既存列 `display_name` / `discord_handle` は維持。`pc_name` は `session_applications.pc_name_snapshot` を正とし、PC名未登録時は `PC名未登録`。
- DiscordユーザーID未登録・形式不正時は `登録されていません`。raw user_id / email / token は返さない。
- 実データ投入なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。
- 今回CodexはSQL Editor追加実行なし、DB構造変更なし、RPC再作成なし、GRANT / REVOKE再実行なし、commit / pushなし。

## M-15G GM向け承認済み参加者PC名表示フロント実装
- session-detailのGM/admin向け承認済み参加者連絡先表示にPC名を追加した。
- `get_gm_session_accepted_contacts(text)` の `discord_mention` / `pc_name` / `pc_name_missing` を利用し、既存の `display_name` / `discord_handle` 互換も維持する。
- 画面表示とコピー出力は `Discord：discord_mention｜ユーザー名：display_name｜PC名：pc_name` のラベル付き1人1行。後続 `{{approved_call_list}}` の原型とする。
- PC名未登録は `PC名：PC名未登録`、Discord未登録・形式不正は `Discord：登録されていません`。形式不正の `discord_handle` 生値は表示・コピーしない。
- raw user_id / email / token / selected_character_id / application_id は表示しない。
- SQL Editor未実行、DB構造変更なし、RPC変更なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15H GM向けテンプレ変数置換UI
- session-detailのGM/admin管理領域に、呼び出し文用のテンプレ変数置換UIを追加した。
- UIはGM/admin権限確認後のみ表示し、通常PLには表示しない。配置はGM向け申請履歴、承認済み参加者連絡先の並び。
- 対応変数は `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}`。
- `{{approved_call_list}}` はM-15G確定の `Discord：discord_mention｜ユーザー名：display_name｜PC名：pc_name` 形式を既存 `formatGmContactLine` 経由で出力する。
- `{{approved_pc_names}}` はPC名だけを `、` 区切りで出力し、PC名未登録は `PC名未登録` とする。承認済み参加者がいない場合は空扱い。
- 承認済み参加者がいない場合の `{{approved_call_list}}` は既存連絡先UIに合わせて `承認済み参加者はまだいません` とする。
- 第一段階のためテンプレート保存、DB保存、localStorage保存は実装しない。
- raw user_id / email / token / selected_character_id / application_id は表示・DOM・console・docsに出さない。
- SQL Editor未実行、DB構造変更なし、RPC変更なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15I-1 テンプレート保存機能仕様設計
- `docs/gm-template-storage-plan.md` を作成し、M-15Hのテンプレ変数置換UIを保存・編集・無効化・一覧表示へ拡張するための仕様を整理した。
- 初期実装はログインユーザー本人の個人テンプレートを優先し、`owner_user_id` を持つ保存テーブルを想定する。admin共通テンプレート、共有テンプレート、並び替え、説明文、scopeなどは後続拡張候補に分離する。
- 削除方式は物理削除ではなく `is_active = false` による非アクティブ化を第一候補とする。
- テンプレート種別は `call` / `result` / `session_post` / `application` / `other` の固定候補を想定し、text CHECK制約案とRPC側バリデーション案を後続SQL草案で比較する。
- 想定RPCは `get_my_template_presets()`、`create_template_preset(...)`、`update_template_preset(...)`、`deactivate_template_preset(...)`。フロントからDB直INSERT / UPDATE / DELETEはしない。
- 次工程はM-15I-2として、SELECT-only preflight SQLで `profiles.id`、`auth.uid()` 対応、admin helper、updated_at helper、既存RPCのsecurity/search_path/EXECUTE方針、テーブル名衝突を確認する。
- この工程ではSQLファイル作成なし、SQL Editor未実行、DB構造変更なし、RPC変更なし、フロント実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

## M-15I-2 テンプレート保存機能 preflight SELECT-only SQL
- `docs/supabase/sql/023_gm_template_storage_preflight_select_only.sql` を作成した。対象は `gm_template_presets` の存在有無、類似テーブル名、想定列、`profiles.id` と `auth.uid()` の型前提、`profiles.id` の `auth.users(id)` 参照、updated_at helper、admin / role helper、既存RPCのsecurity/search_path/EXECUTE傾向、想定RPC名衝突、RLS / 権限傾向、既存text CHECK制約、初期テンプレート種別候補。
- `docs/gm-template-storage-plan.md` は、想定テーブル名を `gm_template_presets` 第一候補へ更新し、DB値は `call` / `result` / `session_post` / `application` / `other`、画面表示は日本語ラベルに分ける方針を追記した。
- ユーザーがSQL Editorでpreflight SQLを手動実行し、エラーなし。単一結果セットとして全チェックが表示された。`gm_template_presets` は未作成で予定テーブル名は未使用、類似テーブル名衝突なし、想定列は未作成のためすべて `pending_create`、`profiles.id` はuuidかつ `auth.users(id)` 参照、`auth.uid()` との型互換も問題なし。
- `set_updated_at()` はupdated_at helper再利用候補。`has_role(text)` / `is_admin()` / `is_session_gm(text)` と `public.user_roles` を確認済み。既存RPCは `security_definer=true` / `search_path=true` の傾向があり、EXECUTE権限は `authenticated` が確認できる。想定RPC名 `get_my_template_presets` / `create_template_preset` / `update_template_preset` / `deactivate_template_preset` は同名衝突なし。
- 初期テンプレート種別候補は `call = 呼び出し用`、`result = リザルト用`、`session_post = 依頼書用`、`application = 申請用`、`other = その他`。preflight結果としてはM-15I-3 RPC draft SQL作成へ進める前提が整っている。ただしこの工程では結果記録までとし、RPC draft SQL作成、apply SQL作成、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15I-3 テンプレート保存機能 RPC draft SQL
- `docs/supabase/sql/023_gm_template_storage_rpc_draft.sql` を作成した。`public.gm_template_presets` テーブル、本人行向けRLS、updated_at trigger、テーブル直書き不可の権限方針、RPC 4本、EXECUTE権限、post-apply確認、rollback草案を含むレビュー用draft。
- 想定RPCは `get_my_template_presets()`、`create_template_preset(text, text, text)`、`update_template_preset(uuid, text, text, text, boolean)`、`deactivate_template_preset(uuid)`。RPCは `security_definer` と明示的な `search_path` を使い、戻り値に `owner_user_id` を含めない。
- `template_type` は `call` / `result` / `session_post` / `application` / `other` のCHECK制約案。`template_name` は1〜80文字の単一行、`template_body` は1〜5000文字で改行可。削除は物理削除ではなく `is_active = false`。
- admin共通テンプレート、共有テンプレート、`sort_order`、`scope`、`description`、同名テンプレートの一意制約は初期草案から除外した。この工程ではSQL Editor実行、DB構造変更、RPC作成 / 変更、apply_reviewed SQL作成、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15I-4 テンプレート保存機能 apply_reviewed SQL
- SQL Editorで実行する対象を固定するため、APPLY専用SQL `docs/supabase/sql/023_gm_template_storage_apply_reviewed.sql` を作成した。今後SQL Editorで適用する場合はこのファイル全文のみを使い、`023_gm_template_storage_rpc_draft.sql` の全文は貼らない。
- APPLY専用SQLには `public.gm_template_presets`、CHECK制約、index、updated_at trigger、本人行向けRLS policy、RPC 4本、EXECUTE権限整理、post-apply確認SELECTを含めた。RPC戻り値に `owner_user_id` は含めない。
- preflight SELECT、rollback草案、共有 / admin共通テンプレート、`sort_order`、`scope`、`description`、物理削除、フロント実装内容は含めていない。次工程はM-15I-5として、ユーザーがSQL EditorでAPPLY専用SQLを手動適用する想定。
- この工程ではSQL Editor実行、DB構造変更、RPC作成 / 変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15I-5 テンプレート保存機能 apply_reviewed SQL適用結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/023_gm_template_storage_apply_reviewed.sql` を手動適用し、SQL Editor上のエラーなしを確認した。
- 適用後確認SELECTで、`gm_template_presets` テーブル存在、RLS有効化、本人向けRLS policy 3件、RPC 4本、各RPCの `security_definer=true` と `search_path` 設定ありを確認済み。RLS policyは `gm_template_presets_insert_own` / `gm_template_presets_select_own` / `gm_template_presets_update_own` の3件で、rolesはいずれも `authenticated`。DELETE policyなしは `is_active=false` の非アクティブ化方針と整合する。
- RPCは `create_template_preset(text, text, text)` / `deactivate_template_preset(uuid)` / `get_my_template_presets()` / `update_template_preset(uuid, text, text, text, boolean)` の4本すべて存在確認済み。EXECUTE権限は4本すべて `authenticated` のみ許可、`anon` / `public` は不可であることを確認した。
- M-15I-5は成功扱い。次工程はM-15I-6「フロント接続」。この記録工程でCodexはSQL Editor実行、DB/RPC追加変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushを行っていない。

## M-15I-6 テンプレート保存機能フロント接続
- `assets/js/sessionDetailApplicationComments.js` のGM/admin向けテンプレUIを「GM向け：テンプレート」へ整理し、保存済みテンプレートselect、テンプレート名入力、テンプレート種別select、新規保存、変更を保存、削除ボタンを追加した。削除表示でも内部処理は `deactivate_template_preset(uuid)` による非アクティブ化であり、物理削除ではない。通常PLには既存のGM/admin判定どおり表示しない。
- 一覧取得は `get_my_template_presets()`、新規保存は `create_template_preset(text, text, text)`、更新は `update_template_preset(uuid, text, text, text, boolean)`、無効化は `deactivate_template_preset(uuid)` をRPC経由で呼ぶ。フロントからDB直INSERT / UPDATE / DELETEはしない。
- 保存済みテンプレート選択時、selectの値には表示用の一時キーだけを使い、実IDは画面やDOMに出さない。エラー表示は一般メッセージに丸め、RPC結果の生データをconsole出力しない。
- バリデーションは `template_name` trim後1〜80文字・改行不可、`template_body` trim後空欄不可・最大5000文字、DB/RPC上の `template_type` は `call` / `result` / `session_post` / `application` / `other`。画面上の選択肢は文脈別に絞り、session-detailでは `call` / `result` / `other`、session-postでは `session_post` / `other` のみ表示する。PL向け申請テンプレUIは将来工程で `application` / `other` を扱う想定。
- session-detailの独立した「GM向け：承認済み参加者連絡先」UIは削除した。承認済み参加者データの取得と整形は、`{{approved_call_list}}` / `{{approved_pc_names}}` のテンプレ変数置換用に内部利用を継続する。置換プレビューとコピーは既存M-15Hの `formatGmTemplateText` を維持し、出力形式は変更していない。
- `session-post.html` の依頼書フォーム上部に「依頼書テンプレート」UIを追加した。保存対象はタイトル、開始日時、終了日時、申請締切、種別、募集人数min/max、公開状態、募集状態、概要。管理対象selectや公開確認チェックは保存しない。`template_body` はフロント専用JSON文字列として保存し、保存済みテンプレート選択だけではフォームへ反映せず、「反映」ボタンで適用する。
- 編集中の依頼書にテンプレートを反映する場合は、未保存の入力内容が失われる旨を確認する。この工程ではSQL Editor実行、DB/RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15J テンプレート管理拡張仕様整理
- `docs/gm-template-storage-plan.md` に、将来拡張として mypage テンプレート一元管理とPL申請コメントテンプレートの方針を追記した。この工程はdocs整理のみで、SQL Editor実行、DB/RPC変更、フロント実装は行っていない。
- mypageには将来的に「テンプレート管理」セクションを追加し、`call` / `result` / `session_post` / `application` / `other` を横断的に作成、編集、削除できる管理画面にする案を整理した。テンプレート操作はRPC経由方針を維持する。
- 種別ごとの用途は、`call` がGM向け呼び出し、`result` がGM向けリザルト、`session_post` がGM向け依頼書フォーム、`application` がPL向け参加申請コメント、`other` が補助用途。`session_post` はフォームJSON文字列、その他の基本種別は自由本文 + 変数として扱う。
- PL申請コメントテンプレートは、session-detailの参加希望コメントフォーム付近にテンプレートselectを置き、`application` / `other` を呼び出してコメント本文へ反映する案を候補にした。既に本文入力済みの場合は上書き確認を出し、初期は保存・編集をmypage側に寄せる。
- `other` は文脈をまたいで混線しやすいため、session-detail、session-post、PL申請コメント、mypageで表示対象を慎重に分ける。必要になった場合のみ、将来の利用文脈追加設計を検討する。
- 追加DB/RPCは急がず、まず既存RPC 4本で本人テンプレートの管理と呼び出しに足りるかを見る。admin共通テンプレート、共有テンプレート、説明文、並び順、利用文脈の厳密分離は後続候補。
- 次工程候補は、M-15J-1 mypageテンプレート管理UI、M-15M PL参加希望コメント欄テンプレ呼び出し、M-15N `session_post` フォーム風編集UI、M-15O 利用文脈追加検討。

## M-15J-1 mypageテンプレート管理UI
- `mypage.html` のログイン済み表示内に「テンプレート管理」セクションを追加し、本人テンプレートを横断的に一覧、作成、編集、削除できるUIを実装した。未ログイン時は既存の認証表示どおり描画しない。
- UIは保存済みテンプレートselect、テンプレート名入力、種別select、本文textarea、新規保存、変更を保存、削除、新規入力に戻す、状態メッセージで構成する。select値は表示用の一時キーのみで、実IDや所有者識別子を画面やDOMへ出さない。
- 対象種別は `call` / `result` / `session_post` / `application` / `other`。`call` / `result` / `application` / `other` は自由本文として扱い、`session_post` は依頼書フォーム用JSON形式のみ保存できるようにした。
- 一覧取得は `get_my_template_presets()`、新規保存は `create_template_preset(text, text, text)`、更新は `update_template_preset(uuid, text, text, text, boolean)`、削除表示の内部処理は `deactivate_template_preset(uuid)` をRPC経由で呼ぶ。フロントからDB直INSERT / UPDATE / DELETEはしない。
- バリデーションはテンプレート名trim後1〜80文字・改行不可、本文trim後空欄不可・最大5000文字・改行可、種別は固定候補のみ。依頼書用テンプレートはmypage上ではフォーム項目として編集する。
- 追加改修として、`call` / `result` 選択時のみ「利用できる変数」ヘルプを表示する。変数名、代入内容、出力例、補足を表示し、mypage上では置換プレビューを行わない。`application` 用変数ヘルプはPL申請コメントUIの後続工程で検討する。
- 追加改修として、`session_post` 選択時は通常本文textareaではなく依頼書用フォーム編集UIを表示する。タイトル、開始日時、終了日時、申請締切、種別、募集人数min/max、公開状態、募集状態、概要を編集し、保存時に既存の依頼書テンプレートJSON形式へ変換して `template_body` に保存する。
- 保存済み `session_post` テンプレート選択時はJSONを読み取ってフォームへ反映する。想定形式として読めない場合は一般的な注意表示にし、フォームへ無理に反映しない。
- この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15K PL申請コメントテンプレート呼び出しUI
- `session-detail.html` の通常PL向け参加希望コメントフォーム付近に、申請コメントテンプレート呼び出しUIを追加した。GM本人として管理中のGMコメントフォームやGM/admin向けテンプレート管理UIには混ぜない。
- UIは保存済みテンプレートselect、反映ボタン、mypageのテンプレート管理への導線で構成する。テンプレート作成・編集・削除はこの画面では行わず、mypage側に寄せる。
- 一覧取得は既存RPC `get_my_template_presets()` のみを使い、表示対象は `application` / `other` に絞る。`call` / `result` / `session_post` はPL申請コメント欄には表示しない。
- select値には表示用の一時キーだけを使い、内部識別子を画面やDOMへ出さない。RPC結果の生データをconsole出力しない。
- テンプレートを選択して「反映」すると `template_body` をコメント本文欄へ入れる。本文がすでに入力済みの場合は上書き確認を出し、キャンセル時は本文を保持する。
- M-15K時点ではPL申請コメントテンプレート内の変数置換は行わない。未対応変数はそのまま本文へ反映し、`application` 用変数ヘルプや実セッション文脈での置換は後続候補として扱う。
- 参加希望コメント投稿、辞退、再申請、GMコメント、PC名snapshot保存挙動は既存導線を維持する。フロントからDB直INSERT / UPDATE / DELETEはしない。
- この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15L テンプレート機能 統合QA・仕様締め
- `docs/template-feature-qa-result.md` を作成し、テンプレート機能全体の現状仕様、種別ごとの用途、表示先、保存形式、画面別QA観点、確認済み事項、残課題、後続候補を整理した。
- 種別は `call` がGM向け呼び出し、`result` がGM向けリザルト、`session_post` が依頼書フォーム、`application` がPL参加申請コメント、`other` が補助用途。自由本文系と依頼書フォームJSON系を分けて扱う。
- 表示先は、mypageが全種別管理、session-detail GM/adminが `call` / `result` / `other`、session-postが `session_post` / `other`、session-detail 通常PL申請コメント欄が `application` / `other`。
- QA観点として、画面ごとの種別絞り込み、変数ヘルプ、依頼書フォームJSON、上書き確認、GM/admin UIと通常PL UIの分離、内部情報を出さないこと、console error 0件を整理した。
- `other` は文脈をまたいで混線しやすいため、現時点では画面ごとの表示対象制御と保存形式の判定で抑える。混線が運用上問題になる場合のみ、利用文脈の追加設計を後続候補とする。
- 次工程候補は、統合実ブラウザQA、QA結果の小修正、PL申請コメント向け変数ヘルプ、PL申請コメントでの変数置換検討、`other` 利用文脈整理、検索・絞り込み、admin共通 / 共有テンプレート。
- この工程ではdocs整理のみ。SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15L-2 テンプレート機能 統合実ブラウザQA
- Codex側ブラウザではChrome連携不可とアプリ内ブラウザ接続タイムアウトにより未確認だったが、ユーザー実ブラウザ確認により、テンプレート機能の横断QAは確認済み扱いへ更新した。
- mypageでは、テンプレート管理UI表示、全種別の横断管理、保存、更新、削除、`call` / `result` 選択時の変数ヘルプ表示、`session_post` 選択時の依頼書フォーム編集UI、`session_post` JSON保存・反映、内部情報非露出、console errorなしを確認済み。
- session-detail GM/adminでは、「GM向け：テンプレート」UI、`call` / `result` / `other` のみ表示、`application` / `session_post` 混入なし、承認済み参加者連絡先UI削除済み、`{{approved_call_list}}` / `{{approved_pc_names}}` の置換維持、コピー機能維持、console errorなしを確認済み。
- session-postでは、依頼書テンプレートUI、`session_post` / `other` のみ表示、依頼書テンプレート反映、既存依頼書編集中の確認ポップアップ、キャンセル時の入力保持、console errorなしを確認済み。
- session-detail 通常PLでは、申請コメントテンプレートUI、`application` / `other` のみ表示、`call` / `result` / `session_post` 混入なし、本文空欄時の反映、本文入力済み時の上書き確認、キャンセル時の本文保持、GMコメントフォームには表示しないこと、console errorなしを確認済み。
- 指定の内部識別子、認証系の生値、PC選択・申請関連の内部キーが画面、DOM、consoleに出ていないことを確認済み。
- 残課題は、`application` 用変数ヘルプ、`application` テンプレートでの変数置換対応検討、`other` 混線が強くなった場合の利用文脈追加検討、admin共通 / 共有テンプレート、テンプレート検索・絞り込み、説明文 / 並び順、`session_post` JSON破損時UI改善。
- この工程ではQA記録のみ。SQL Editor実行、DB/RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15 依頼書編集・公開・募集終了・削除のRLS / RPC smoke test整理
- `docs/session-posting-rpc-smoke-test-plan.md` を作成し、依頼書の作成、編集、公開状態変更、募集状態変更、中止、完全削除に関する既存RPC / RLS / 権限のsmoke test観点を整理した。
- 対象RPC候補は `create_session_post(...)`、`update_session_post(...)`、`delete_session_post(text)`。対象機能は依頼書新規作成、既存依頼書編集、公開 / 非公開 / 下書き、募集中 / 満員 / 募集終了 / 開催終了 / 中止、完全削除、session-detailからの編集導線、admin管理、静的JSON由来の編集不可 / 削除不可、Supabase由来優先のマージ表示。
- 権限ロール別には、未ログイン、通常PL、作成者GM、他GM、admin、静的JSON由来の期待動作を表で整理した。adminはアプリ内権限として扱い、サーバ高権限とは混同しない方針を維持する。
- バリデーション観点として、`draft + public`、不正な `status` / `visibility`、人数範囲、終了日時逆転、タイトル / 概要空欄、エラー表示の一般化を整理した。
- 完全削除は `delete_session_post(text)`、中止として残す場合は `status = canceled`、募集終了 / 開催終了は募集状態変更として扱う。完全削除時は参加申請と参加希望コメントへの影響を確認文に出す観点を残した。
- 静的JSON由来はDB RPCの編集 / 削除対象にせず、同IDのSupabase由来がある場合はSupabase側を優先する。非公開 / 下書き / 中止のSupabase由来が静的JSON fallbackで復活しないことを後続QA候補にした。
- 後続候補は、M-14D-15A SELECT-only preflight SQL作成、M-14D-15B 手動ブラウザsmoke test手順書、M-14D-15C ユーザー実ブラウザQA結果記録、M-14D-15D 軽微修正、M-14D-15E Discord同期状態との連動確認。
- この工程ではdocs整理のみ。SQLファイル作成、SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15B 依頼書RPC smoke test preflight SELECT-only SQL
- `docs/supabase/sql/024_session_posting_rpc_smoke_preflight_select_only.sql` を作成した。SQL Editorで1つの結果表として確認できるよう、`sort_order` / `section` / `check_name` / `expected` / `status` / `result_value` / `notes` へ統一している。
- 確認対象は `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` の存在、signature、`security_definer`、`search_path`、EXECUTE状態、`public.sessions` の存在と主要列、`status` / `visibility` / `session_type` のCHECK制約、`session_applications` / `session_comments` のFKとON DELETE方針、admin / GM / role helper、`user_roles`、RLS有効状態、policy概要。
- 権限確認はACL/OIDベースのカタログ確認に寄せ、実データ行は読まない。静的JSON由来がDB RPC対象外であることはSQLでは確認せず、フロント表示・マージロジック側の確認観点として残した。
- この工程ではSELECT-only SQL作成のみ。SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15B 依頼書RPC smoke preflight実行結果
- ユーザーが `docs/supabase/sql/024_session_posting_rpc_smoke_preflight_select_only.sql` をSupabase SQL Editorで手動実行し、エラーなしで単一結果セットを確認した。
- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` はすべて存在し、`security_definer = true`、`search_path` 明示あり、`authenticated` EXECUTEあり、`anon` / `PUBLIC` EXECUTEなしでstatus ok。
- `public.sessions` と主要列は存在し、`status` / `visibility` / `session_type` のCHECK制約もstatus ok。`status` 制約の実動作は後続smoke test候補として残す。
- `session_applications` / `session_comments` から `sessions` へのFKはどちらも `ON DELETE CASCADE`。完全削除時に関連申請・コメントもDB制約上CASCADEされる前提を再確認した。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` と `public.user_roles` は存在し、`sessions` / `session_applications` / `session_comments` / `profiles` / `user_roles` はRLS enabled。adminはアプリ内権限として扱い、サーバ高権限とは混同しない。
- policy summaryはinfoとして確認済み。静的JSON由来はDB catalog項目ではないため、DB RPC対象外としてフロント表示・マージロジック側の確認観点に残す。
- M-14D-15B preflightは成功扱い。次工程はpreflight SQLと結果記録をcommit / pushしたうえで、手動smoke test設計または実ブラウザQAへ進める想定。
- この記録工程でCodexはSQL Editor実行、DB/RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15C 依頼書RPC smoke test 手動実行手順・テストデータ設計
- `docs/session-posting-rpc-smoke-manual-test.md` を作成し、依頼書RPC smoke testの目的、推奨テスト方式、テストデータ設計、ロール別確認、バリデーション、完全削除 / CASCADE、静的JSON由来、実行順、結果記録フォーマットを整理した。
- 推奨方式は実ブラウザ操作中心。SQL Editorでの直接RPC確認は必要最小限にし、既存本番寄りデータを触らず、テスト用依頼書を明示的に作成してから使う方針にした。
- テストデータは基本確認用、完全削除用、CASCADE確認用を分ける。完全削除確認は削除専用の依頼書だけで行い、参加申請 / コメントのCASCADE確認も専用データに限定する。
- ロール別には未ログイン、通常PL、作成者GM、他GM、admin、静的JSON由来を整理した。adminはアプリ内権限としてのみ扱い、サーバ高権限とは混同しない。
- バリデーションは下書き状態の公開化、不正な募集状態 / 公開状態、募集人数の上下逆転、終了日時逆転、タイトル / 概要空欄、一般化されたエラー表示を確認候補にした。
- 後続候補はM-14D-15D手動ブラウザsmoke test実施、M-14D-15E結果記録、必要なら軽微修正。その後はDiscord Edge Function設計再開または静的JSON退役へ進む想定。
- この工程ではdocs整理のみ。SQL Editor実行、DB/RPC変更、フロント実装、実データ作成・更新・削除、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15D 依頼書RPC smoke test 手動実施サポート
- `docs/session-posting-rpc-smoke-manual-test.md` に、ユーザー実ブラウザ確認用の簡易チェックリストと結果記録準備欄を追加した。
- 確認対象は作成者GMでの作成・編集、公開状態 / 募集状態変更、ガード確認、通常PL / 他GM拒否、admin管理、削除専用テスト依頼書での完全削除、削除後の非表示、静的JSON由来の編集不可 / 削除不可、内部情報非露出、console errorなし。
- 実施時の注意として、既存本番寄りデータではなくテスト用依頼書を使うこと、完全削除確認は削除専用データで行うこと、参加申請 / コメントCASCADE確認はさらに専用データで行うこと、Discord実送信確認は行わないことを整理した。
- M-14D-15D時点では手動実施サポートと結果記録欄準備までを行った。ユーザー実ブラウザでの結果は、後続のM-14D-15Eとして記録済み。
- この工程ではdocs整理のみ。SQL Editor実行、DB/RPC変更、フロント実装、実データ作成・更新・削除、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15E 依頼書RPC smoke test結果記録
- ユーザー実ブラウザで依頼書RPC smoke testを実施済みとして、結果を `docs/session-posting-rpc-smoke-manual-test.md`、`docs/session-posting-rpc-smoke-test-plan.md`、`docs/session-posting-management-qa-result.md` に記録した。
- 成功項目は、作成者GMでのテスト用依頼書新規作成・編集保存、公開状態 / 募集状態変更、下書き状態の公開化などのガード、通常PLの管理UI非表示、他GMの編集不可または管理対象外、admin管理、削除専用テスト依頼書の完全削除、削除後の非表示、静的JSON由来の編集不可 / 削除不可、内部情報非露出、console error 0件。
- 未確認項目は、参加申請 / コメントを含むCASCADEの厳密確認と、静的JSONと同じ公開IDを持つSupabase側の非公開・下書き・中止状態によるfallback抑止の詳細確認。
- 残課題は、CASCADE確認、他GM拒否確認の追加精査、エラー文言の一般化確認、Discord同期状態との連動確認、静的JSON退役後の再確認。
- 削除済みテストデータは一般名でのみ記録し、実IDや内部キーは記録していない。
- この記録工程でCodexはSQL Editor実行、DB/RPC変更、フロント実装、追加の実データ作成・更新・削除、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14E-1 Discord同期Edge Function仕様整理
- `docs/discord-edge-function-sync-plan.md` を作成し、依頼書DBを正本、Discord投稿を同期先として扱うEdge Function仕様を整理した。
- 秘匿値はEdge Function側の管理設定だけで扱い、フロント、docs、DB、GitHub、チャットへ実値を書かない方針を明記した。adminはアプリ内権限として扱い、サーバ高権限とは混同しない。
- 同期アクションは `create` / `update` / `close` / `delete` / `resync`。Discord送信失敗時も依頼書保存自体は成功扱いにし、同期状態を `failed` として短い一般化エラー要約を残し、再同期できる設計にする。
- DB状態管理は `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` を中心に整理した。既存投稿の更新・終了表示・削除相当処理には外部投稿識別子が必要になるため、M-14E-2 preflightで既存列の有無と運用可否を確認する。
- フロントからDiscordへ直接送らず、後続のGM/admin再同期UIもEdge Functionまたは同期要求経路を呼ぶ方針にした。画面・DOM・consoleには内部キーや外部投稿識別子を出さない。
- 実装前の必須確認として、dry-run / mock、権限判定、同期対象判定、失敗時状態遷移、ログの安全性、完全削除時の外部投稿扱いを整理した。
- 後続候補は、M-14E-2 既存DB列 / 不足列 SELECT-only preflight、M-14E-3 必要時draft SQL、M-14E-4 apply_reviewed、M-14E-5 Edge Function draft、M-14E-6 管理設定手順docs、M-14E-7 dry-run / mock、M-14E-8 deploy手順、M-14E-9 再同期UI、M-14E-10 実送信QA。
- この工程ではdocs設計のみ。SQLファイル作成、SQL Editor実行、DB構造変更、RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-2 Discord同期 既存DB列・不足列 preflight SELECT-only SQL
- `docs/supabase/sql/025_discord_sync_preflight_select_only.sql` を作成した。Supabase SQL Editorで1つの結果表として確認できるよう、`sort_order` / `section` / `check_name` / `expected` / `status` / `result_value` / `notes` へ統一している。
- 確認対象は `public.sessions` の存在、依頼書主要列、Discord同期状態列、`discord_message_id` 相当列、投稿先・投稿URL相当列、CHECK制約、RLS、policy概要、依頼書RPC 3本、同期関連RPC名スキャン、admin / GM helper、静的JSON由来の扱い。
- `discord_message_id` 相当列が不足する場合は、既存投稿の更新、終了表示、削除相当処理、再同期に支障があるため、M-14E-3でDB列追加draftを検討する。
- 既存の状態管理列と外部投稿識別子がそろっている場合は、結果記録後にEdge Function draftへ進める可能性がある。
- SQLはカタログ確認のみで、実データ行は読まない。秘匿値や内部情報の実値は出さず、外部投稿credentialをDBに保存する設計にもしていない。
- この工程ではSELECT-only SQL作成のみ。SQL Editor実行、DB構造変更、RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-2 Discord同期 preflight実行結果
- ユーザーが `docs/supabase/sql/025_discord_sync_preflight_select_only.sql` をSupabase SQL Editorで手動実行し、エラーなしで単一結果セットを確認した。
- `public.sessions` と依頼書主要列はstatus ok。Discord同期状態列 `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` もすべてstatus ok。
- 外部投稿識別子・投稿先関連列として、`discord_message_id` 相当、`discord_channel_id` 相当、`discord_thread_id` 相当、`discord_post_url` 相当が存在し、status ok。baseline state columnsは `5/5 present`、message identifier readinessは `has_message_identifier=true`。
- CHECK制約は、同期状態、同期action、募集状態、公開状態、依頼書種別がstatus ok。public draft guardはDB制約ではなくRPC/UI側確認候補としてinfoに残す。
- `sessions` / `user_roles` のRLS enabled、policy summary、依頼書RPC 3本の存在・`security_definer`・`search_path`・EXECUTE状態、admin / GM helperは期待どおり確認できた。
- 同期関連RPC名スキャンではpublic関数1件をinfoとして確認した一方、resync専用public関数は未作成。GM/admin向け再同期ボタンを作る場合は、RPCまたはEdge Function呼び出し方針を後続で検討する。
- M-14E-2 preflightは成功扱い。現時点ではDB列追加が必須とは限らないため、M-14E-3の列追加draftを急がず、既存列を前提にしたEdge Function draft設計へ進めるか検討できる。
- この記録工程でCodexはSQL Editor実行、DB/RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushを行っていない。

## M-14E-3 Discord同期Edge Function 入出力・dry-run仕様整理
- `docs/discord-edge-function-io-plan.md` を作成し、既存DB列を前提にしたEdge Functionの入出力、payload、dry-run、戻り値、状態更新、失敗時処理、権限、秘匿値管理、ログ安全性を整理した。
- 想定名称は `sync-session-post-to-discord` を初期推奨、`discord-session-sync` を比較候補とした。
- 入力payloadは `session_id` / `action` / `dry_run` を最小候補にし、`request_source` は補助値として扱う。権限判定の根拠はEdge Function側またはレビュー済みRPC側で確認する。
- action別に `create` / `update` / `close` / `delete` / `resync` の挙動を整理した。`delete` はDB完全削除前にDiscord側deleteまたは削除相当表示をどう行うかが重要な懸念点。
- dry-runはDiscord実送信せず、公開情報だけで構成した投稿本文プレビュー、同期対象判定、状態更新予定を返す方針にした。
- 初期投稿本文は固定フォーマットを第一候補にし、M-15テンプレート機能との接続は後続候補にした。
- 状態更新は `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` と、外部投稿識別子・投稿先・投稿URL相当列を使う方針にした。失敗時は一般化した短いエラー要約だけを記録する。
- 権限は未ログイン、通常PL、他GMを拒否し、作成者GMまたはアプリ内adminのみを許可する方針。サーバ側DB更新権限はアプリ内admin権限と混同せず、後続でレビュー済みRPC経由案と安全なサーバ側更新案を比較する。
- 後続候補は、M-14E-4 Edge Function draft実装、M-14E-5 管理設定手順docs、M-14E-6 dry-run確認、M-14E-7 deploy手順整理、M-14E-8 deploy実施判断、M-14E-9 再同期UI、M-14E-10 実送信QA。
- この工程ではdocs設計のみ。SQLファイル作成、SQL Editor実行、DB/RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-4 Discord同期Edge Function draft実装
- `supabase/functions/sync-session-post-to-discord/index.ts` を追加し、既存DB列を前提にしたdry-run preview専用のEdge Function draftを実装した。
- 入力payloadは `session_id` / `action` / `dry_run` / 任意の `request_source` に限定し、`action` は `create` / `update` / `close` / `delete` / `resync` のみ許可する。
- `dry_run = true` では外部送信もDB更新も行わず、投稿本文preview、同期対象判定、状態更新予定、警告を返す。`dry_run = false` は実送信未実装として明示的に拒否する。
- 権限は呼び出しユーザーの認証文脈で `is_admin()` / `is_session_gm(target_session_id)` を呼び、作成者GMまたはアプリ内adminだけを許可する。`request_source` は権限根拠にしない。
- `public.sessions` から取得する情報は依頼書本文生成と同期判定に必要な公開系フィールドと同期状態列に限定する。秘匿値、認証系の生値、ユーザー内部識別子、参加申請やPC選択関連の内部キー、外部投稿参照情報そのものは返さない。
- 同期対象は `visibility = public` かつ `status = tentative / recruiting / full / closed / finished` の候補に限定し、`draft` / `private` / `hidden` / `canceled` は同期対象外として扱う。
- `update` / `close` / `delete` は既存投稿参照情報がない場合に拒否し、`resync` は参照情報の有無で `update` 相当または `create` 相当に解釈する。
- 後続候補は、M-14E-5 管理設定手順docs、M-14E-6 dry-runローカル / 手動確認、M-14E-7 deploy手順整理、M-14E-8 deploy実施判断、M-14E-9 GM/admin再同期UI、M-14E-10 実送信QA。
- この工程ではSQL Editor実行、DB/RPC変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-5 Discord同期Edge Function secret管理・dry-run確認手順docs
- `docs/discord-edge-function-secret-plan.md` を追加し、secret管理方針、dry-run確認手順、payload例、action別期待結果、deploy前チェックリスト、後続工程、懸念点を整理した。
- 初期dry-runで必要な設定候補と、実送信・DB状態更新に進む後続で検討する設定候補を分けた。実値は記録していない。
- `dry_run = true` のpreview確認、`dry_run = false` の拒否確認、Discord実送信なし、DB更新なし、レスポンス安全性、GM/admin限定、通常PL拒否を確認観点にした。
- deploy前チェックリストには、Deno / TypeScript構文確認、外部送信処理なし、DB書き込みなし、ログ安全性、CORS、認証、静的JSON由来対象外を含めた。
- 残課題は、完全削除前の外部投稿側処理順、DB削除後に既存投稿参照情報を参照できない問題、実送信時のDB状態更新経路、resync専用RPC未作成、M-15テンプレート機能との接続時期。
- 後続候補は、M-14E-6 Deno構文確認 / dry-run確認、M-14E-7 deploy手順整理、M-14E-8 deploy実施判断、M-14E-9 GM/admin再同期UI、M-14E-10 Discord実送信QA。
- この工程ではdocs整理のみ。SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6 Discord同期Edge Function Deno構文確認 / dry-run確認準備
- `docs/discord-edge-function-dry-run-check-result.md` を追加し、Edge Function draftのDeno利用可否、安全検索、dry-run確認準備を記録した。
- 作業前の作業ツリーはclean、最新commitは `fdbdfd6 Document Discord sync secret and dry run checks`。
- この環境ではDenoが見つからず、`deno check supabase/functions/sync-session-post-to-discord/index.ts` は未実施。後続でDenoまたはSupabase Edge Functionローカル確認環境を用意して実施する。
- 安全検索では、Edge Function draft内に `fetch(`、DB書き込み系メソッド、`console.` は0件。関連ファイルにsecret実値らしき文字列も検出されなかった。
- dry-run確認は手順準備までで、Edge Function起動、`dry_run = true` 呼び出し、`dry_run = false` 呼び出し、secret実値設定、deploy、Discord実送信は行っていない。
- 残課題はDeno構文確認、dry-run実レスポンス確認、権限helperの実行環境確認、CORS再確認、実送信時のDB状態更新経路、完全削除前の外部投稿側処理順。
- この工程では確認・docs記録のみ。SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6B Discord同期Edge Function Deno確認方針整理
- `docs/discord-edge-function-dry-run-check-result.md`、`docs/discord-edge-function-secret-plan.md`、`docs/discord-edge-function-sync-plan.md` に、Deno構文確認とdry-run確認を今後どの環境で行うかの方針を追記した。
- 現状はDeno未導入、`deno check` 未実施、dry-run実行未実施。Edge Functionコード変更なし、安全検索は `fetch(` / DB書き込み系メソッド / `console.` が0件、secret実値らしき文字列も検出なし。
- 確認方法の候補は、ローカルWindows環境でのDeno確認、Supabase CLI環境での確認、CIまたは別環境での確認。
- 進行判断は、Deno確認前にdeployへ進まない、dry-run実行確認前にDiscord実送信へ進まない、secret設定方針を再確認する前に実送信コードへ進まない。
- M-14E-7 deploy手順整理へ進む前に、Deno確認の実施環境を決めるのが安全。
- この工程ではdocs整理のみ。Deno導入、Supabase CLI導入、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6C Discord同期Edge Function ローカルDeno確認結果記録
- ユーザーのローカルWindows PowerShellで `deno --version` を実行した結果、Denoは認識されず、ローカルWindows環境でもDeno未導入であることを確認した。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は未実施のまま。Edge FunctionのDeno構文確認は未完了として残す。
- Deno確認前にdeployへ進まない方針、dry-run実行確認前にDiscord実送信へ進まない方針を維持する。
- 次工程候補は、ユーザー確認のうえでローカルWindows環境にDenoを導入して確認する案、Supabase CLI環境で確認する案、CIまたは別環境で確認する案。
- この工程ではdocs記録のみ。Deno導入、Supabase CLI導入、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6C Discord同期Edge Function Deno構文確認・型エラー修正結果
- ユーザーのローカルWindows環境でDeno導入後、`deno --version` と `deno check supabase/functions/sync-session-post-to-discord/index.ts` が成功した。
- 過去に `is_session_gm` RPC呼び出しの `target_session_id` 引数まわりでTypeScript型エラーが出たが、`is_session_gm` 呼び出し専用の薄い型緩和helperで修正済み。
- Supabase client全体の型を崩さず、作成者GMまたはアプリ内adminのみ許可する権限判定方針を維持している。通常PLを許可する方向の変更はしていない。
- `dry_run = true` preview専用、`dry_run = false` 拒否、Discord実送信なし、DB更新なしの方針を維持している。
- `fetch(`、DB書き込み系メソッド、`console.` は追加していない。
- deploy前の残確認は、dry-run実レスポンス、拒否応答、ログ安全性、secret実値や内部識別子の非露出確認。
- この工程ではdocs記録のみ。Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6D Discord同期Edge Function dry-run実行確認方法整理
- `docs/discord-edge-function-dry-run-check-result.md` を中心に、dry-run実レスポンス確認の目的、実行方法候補、推奨案、必要情報、payload例、確認項目、事前安全検索、まだやらないこと、次工程案を整理した。
- 実行方法候補は、Supabase CLIローカルserve、Deno単体起動、deploy後dry-run限定確認、CI/別環境確認。deploy前の第一候補はSupabase CLIローカルserveとした。
- 必要情報はSupabase接続先、呼び出しユーザーの認証文脈、Edge Function実行用の環境変数、確認対象依頼書ID相当の値。ただし実値はdocsへ書かない。
- 初期dry-runではDiscord投稿先credentialは原則不要。サーバ側高権限credentialが必要になる場合も、アプリ内admin権限と混同せず後続レビューで判断する。
- `dry_run = true` では `create` / `update` / `close` / `delete` / `resync`、同期対象外、既存投稿参照情報不足、通常PL拒否、GM/admin許可を確認する。
- `dry_run = false` は今回実行しない。将来確認する場合も、draft段階では拒否され、Discord API呼び出しとDB更新がないことだけを確認する。
- 次工程候補は、M-14E-6E Supabase CLI利用可否確認、M-14E-6F ローカルserve dry-run確認、M-14E-7 deploy手順整理、M-14E-8 deploy判断、M-14E-9 再同期UI、M-14E-10 実送信QA。
- この工程ではdocs整理のみ。Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6E Supabase CLI利用可否確認
- 作業前の作業ツリーはclean、最新commitは `fed7032 Document Discord sync dry run execution plan`。
- `supabase --version` を実行した結果、この環境ではSupabase CLIは認識されず、利用不可だった。
- Supabase CLIローカルserve dry-run確認は未実施。Supabase CLI導入も行っていない。
- 次工程候補は、ユーザー確認のうえでSupabase CLIを導入する案、Supabase CLIが利用できる別環境で確認する案、deploy手順整理を先に行いdeploy後は `dry_run = true` 限定確認から始める案。
- この工程では利用可否確認とdocs記録のみ。Supabase CLI導入、SQL Editor実行、DB/RPC変更、Edge Function deploy、Discord実送信、`dry_run = false` 実行、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6E / 6F Supabase CLI利用可否確認結果とローカルserve準備
- ユーザー確認で `node --version` は `v24.16.0`、`where.exe npx` はNode.js配下の `npx` / `npx.cmd` を確認済み。
- PowerShellの `npx supabase --version` は実行ポリシーで `npx.ps1` が止まる。一方、`npx.cmd supabase --version` では `supabase@2.105.0` の利用確認後、`2.105.0` が表示された。
- Supabase CLIはグローバル導入済みではなく、PowerShellでは `npx.cmd` 経由で利用可能な状態として記録した。
- ローカルserve dry-run確認の候補コマンドは `npx.cmd supabase functions serve sync-session-post-to-discord`。ただしこの工程では実行していない。
- ローカルserve準備では、Supabase接続先、認証文脈、Edge Function実行用環境変数、確認対象依頼書ID相当の値をユーザー手元だけで扱い、docsへ実値を書かない方針を整理した。
- `dry_run = true` のみ確認対象にし、Discord実送信なし、DB更新なし、ログ安全性、通常PL拒否、GM/admin許可を重点確認する。`dry_run = false` は実行しない。
- 次工程候補は、M-14E-6F `npx.cmd` 経由ローカルserve dry-run確認、M-14E-7 deploy手順整理、M-14E-8 deploy判断、M-14E-9 再同期UI、M-14E-10 実送信QA。
- この工程ではdocs整理のみ。Supabase CLI導入、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6G Discord同期Edge Function ローカルserve dry-run実行準備・実行可否確認
- 作業前の作業ツリーはclean、最新commitは `70cd55d Record Supabase CLI dry run preparation`。
- `npx.cmd supabase --version` は `2.105.0`。`deno check supabase/functions/sync-session-post-to-discord/index.ts` はPATH上の `deno` が未認識だったため、ユーザー領域のDeno実行ファイルをフルパスで実行して成功した。
- Edge Functionが参照する環境変数名は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。この作業環境では3つとも未設定だった。
- `SUPABASE_URL` / `SUPABASE_ANON_KEY` と認証文脈が未用意のため、`npx.cmd supabase functions serve sync-session-post-to-discord` は実行していない。
- ローカルserveを起動していないため、`dry_run = true` の実レスポンス確認も未実行。`dry_run = false` は実行していない。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.` は0件。
- 次工程候補は、ユーザー手元で必要な環境変数と認証文脈を用意し、ローカルserve起動後に `dry_run = true` のみを確認すること。
- この工程ではdocs整理のみ。Supabase CLI導入、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6H Discord同期Edge Function dry-run実行条件整理
- 作業前の作業ツリーはclean、最新commitは `48597b3 Record Supabase CLI dry run preparation`。
- `npx.cmd supabase --version` は `2.105.0`。Deno構文確認はPATH上の `deno` が未認識だったため、ユーザー領域のDeno実行ファイルをフルパスで実行して成功した。
- Edge Functionが参照する環境変数名は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。Authorizationヘッダーも必要。
- この作業環境では必要環境変数が未設定で、認証文脈も未用意だったため、ローカルserveは実行していない。
- `dry_run = true` 実レスポンス確認は未実行。`dry_run = false` も実行していない。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。
- 次工程候補は、ユーザー手元で必要な環境変数と認証文脈を用意し、ローカルserve起動後に `dry_run = true` のみを確認すること。
- この工程ではdocs整理のみ。`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6I Discord同期Edge Function ローカルdry-run手元実行ガイド
- 作業前の作業ツリーはclean、最新commitは `d7bab80 Record Discord sync local dry run readiness`。
- `npx.cmd supabase --version` は `2.105.0`。Deno構文確認はPATH上の `deno` が未認識だったため、ユーザー領域のDeno実行ファイルをフルパスで実行して成功した。
- `docs/discord-edge-function-dry-run-check-result.md` に、PowerShell用の手元実行ガイド、プレースホルダーだけの環境変数設定例、ローカルserve候補、`Invoke-RestMethod` 候補、payload例、結果記録テンプレートを追加した。
- 必要な環境変数名は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。認証文脈は `Authorization: Bearer <USER_JWT>` として扱い、実値はユーザー手元だけで扱う方針。
- 初回確認は `create` の `dry_run = true` のみに絞る。`update` / `close` / `delete` / `resync` は後続候補。
- 結果記録テンプレートは、成功 / 権限不足 / 同期対象外 / 対象なし等の一般化結果、message_preview要約、planned_db_update予定情報、Discord実送信なし、DB更新なし、秘匿値非露出、ログ安全性、残課題を記録する形式。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。
- この工程ではCodex側でローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行は行っていない。Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、`updates.json` 変更、commit / pushも行っていない。

## M-14E-6J Discord同期Edge Function ローカルserve不可結果記録
- ユーザー手元で `npx.cmd supabase --version` は `2.105.0`、Deno構文確認は成功。必要環境変数はユーザー手元で設定済みだが、実値は記録していない。
- `npx.cmd supabase functions serve sync-session-post-to-discord` は、Docker Desktop / Docker daemonへ接続できず失敗した。
- `docker --version` もPowerShellで認識されず、ユーザー環境ではDocker CLI / Docker Desktopが未導入、またはPATH上で利用不可と判断する。
- ローカルserveはDocker未導入またはDocker daemon利用不可により未実行扱い。`dry_run = true` も未実行。
- Discord実送信なし、DB更新なし、`dry_run = false` 未実行、Edge Function deployなし。
- 次工程候補は、Docker Desktopを導入してローカルserve dry-runへ進む案、またはローカルserveを保留してdeploy前手順整理と安全レビューへ進む案。
- この工程ではdocs記録のみ。Docker Desktop導入、Supabase CLI追加導入、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、`updates.json` 変更、commit / pushは行っていない。

## M-14E-7 Discord同期Edge Function deploy後dry-run確認手順・deploy前安全レビュー
- 作業前の作業ツリーはclean、最新commitは `918dcd3 Record Discord sync local serve blocked by Docker`。
- `npx.cmd supabase --version` は `2.105.0`。Deno構文確認はPATH上の `deno` が未認識だったため、ユーザー領域のDeno実行ファイルをフルパスで実行して成功した。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。
- ローカルserveがDocker未導入により不可のため、将来deploy後に `create` / `dry_run = true` だけを安全に確認する手順とdeploy前チェックリストをdocsへ整理した。
- deploy前チェックは、cleanな作業ツリー、Deno構文確認、外部送信なし、DB書き込みなし、console出力なし、`dry_run = false` 拒否、秘匿値実値なし、CORS確認、Authorization Bearerをユーザー手元だけで扱うことを含む。
- deploy後確認では、実値をdocsや報告へ書かず、`message_preview` と `planned_db_update`、Discord実送信なし、DB更新なし、レスポンスとログの安全性を一般化して記録する。
- 次工程候補は、M-14E-8 deploy手順・事前確認、M-14E-9 deploy実施判断、M-14E-10 deploy後dry_run=true確認、M-14E-11 real_send createのみ実装検討、M-14E-12 Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。
- この工程ではdocs整理のみ。Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-8 Discord同期Edge Function dry-run専用deploy実施前レビュー
- 作業前の作業ツリーはclean、最新commitは `9919119 Document Discord sync deploy dry run review`。
- deploy対象は Function名 `sync-session-post-to-discord`、対象ファイル `supabase/functions/sync-session-post-to-discord/index.ts`。
- 現状はdry-run preview専用draftで、`dry_run = true` はpreviewのみ、`dry_run = false` は `real_send_not_enabled` で拒否する。
- `npx.cmd supabase --version` は `2.105.0`。Deno構文確認はPATH上の `deno` が未認識だったため、ユーザー領域のDeno実行ファイルをフルパスで実行して成功した。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。
- deployコマンド候補は `npx.cmd supabase functions deploy sync-session-post-to-discord`。この工程では実行していない。deploy実施時はユーザー確認を必須にする。
- deploy後確認は、最初に `create` / `dry_run = true` のみに絞り、`message_preview` と `planned_db_update`、Discord実送信なし、DB更新なし、レスポンスとログの安全性を一般化して記録する。
- deployを止める条件は、dirtyな作業ツリー、Deno構文確認失敗、外部送信処理やDB書き込みやconsole出力の増加、秘匿値実値混入、`dry_run = false` 拒否の崩れ、Function名や対象パスの曖昧さ、ユーザー確認なし。
- 次工程候補は、M-14E-9 deploy実施判断、M-14E-10 deploy後 create / dry_run=true 確認、M-14E-11 dry_run=false拒否確認、M-14E-12 real_send createのみ実装検討、M-14E-13 Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。
- この工程ではdocs整理とdeploy前レビューのみ。Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-9 Discord同期Edge Function dry-run専用deploy実施判断・最終手順整理
- 作業前の作業ツリーはclean、最新commitは `ff9ea72 Review Discord sync dry run deploy plan`。
- deploy直前チェックとして、Deno構文確認成功、`npx.cmd supabase --version = 2.105.0`、`fetch(` 0件、DB書き込み系メソッド0件、`console.` 0件、`deno.lock` なし、`updates.json` 差分なしを確認した。
- Function名は `sync-session-post-to-discord`、対象ファイルは `supabase/functions/sync-session-post-to-discord/index.ts`。
- 現状はdry-run preview専用draftで、`dry_run = true` はpreviewのみ、`dry_run = false` は `real_send_not_enabled` で拒否する。
- Supabase CLI認証、project link、project ref相当の情報はdeploy時に必要になる可能性があるが、実値はユーザー手元だけで扱う。認証やlinkが未設定、対象projectが不明、Codexへ実値を渡す必要がある場合はdeployを止める。
- deploy候補コマンドは `npx.cmd supabase functions deploy sync-session-post-to-discord`。この工程では実行していない。
- deployを止める条件は、dirtyな作業ツリー、Deno構文確認失敗、外部送信処理やDB書き込みやconsole出力の増加、秘匿値実値混入、CLI認証・project link・project ref相当の扱い不明、`dry_run = false` 拒否の崩れ、ユーザーの明示確認なし。
- deploy後確認は、最初に `create` / `dry_run = true` のみに絞る。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsや報告には実値を書かない。
- `dry_run = false` はまだ実行しない。将来確認する場合も拒否確認として別工程に分ける。
- 次工程候補は、M-14E-10 ユーザー手動deploy実施、M-14E-11 deploy後 create / dry_run=true 確認、M-14E-12 dry_run=false拒否確認、M-14E-13 real_send createのみ実装検討、M-14E-14 Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。
- この工程ではdocs整理とdeploy直前レビューのみ。Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-10 Discord同期Edge Function dry-run専用deploy実施前 最終安全確認
- 作業前の作業ツリーはclean、最新commitは `cf8037c Document Discord sync dry run deploy checklist`。
- Deno構文確認は成功。Supabase CLIは `npx.cmd supabase --version` で `2.105.0`。
- 安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、認証系生値風文字列、service-role系文字列はいずれも0件。
- `deno.lock` は存在しない。`updates.json` 差分なし。
- deploy対象は Function名 `sync-session-post-to-discord`、対象ファイル `supabase/functions/sync-session-post-to-discord/index.ts`。候補コマンドは `npx.cmd supabase functions deploy sync-session-post-to-discord`。
- Codex側ではdeploy候補コマンドを実行していない。`dry_run = true` / `dry_run = false` も実行していない。
- deploy停止条件は、dirtyな作業ツリー、Deno構文確認失敗、外部送信処理やDB書き込みやconsole出力の増加、秘匿値実値混入、CLI認証・project link・project ref相当の扱い不明、`dry_run = false` 拒否の崩れ、ユーザー明示確認なし。
- deploy時にSupabase CLIログイン、project link、project ref相当、Supabase access token相当の入力が必要になる可能性がある。実値はユーザー手元だけで扱い、docsやチャットへ書かない。
- 現時点の確認結果では、ユーザーが明示確認したうえで手動deployへ進むための直前安全条件は満たしている。ただし、deploy後確認は `create` / `dry_run = true` のみに絞り、`dry_run = false` はまだ実行しない。
- 次工程候補は、ユーザー手動deploy実施、deploy後 create / dry_run=true 確認、dry_run=false拒否確認、real_send createのみ実装検討、Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。
- この工程では最終安全確認とdocs整理のみ。Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-11 Discord同期Edge Function dry-run専用deploy結果記録
- 作業前の作業ツリーはclean、最新commitは `439eb10 Document Discord sync deploy final safety check`。
- ユーザー手元で `npx.cmd supabase functions deploy sync-session-post-to-discord` を実行し、対象Function `sync-session-post-to-discord` のdeployに成功した。
- Docker未起動に関するWARNINGは表示されたが、Supabaseプロジェクトへのアップロード・deploy自体は完了している。
- deploy後に `supabase/.temp/` がCLI生成物として未追跡生成されたが、ユーザーが削除済み。削除後の `git status --short` はclean。
- 現在の状態は、Edge Function deploy済み、`dry_run = true` 未実行、`dry_run = false` 未実行、Discord実送信なし、DB更新なし、SQL Editor未実行、DB/RPC変更なし、フロント実装なし、秘匿値の実値設定なし、`updates.json` 変更なし。
- 次工程は deploy後 `create` / `dry_run = true` 確認。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsや報告には実値を書かない。
- `dry_run = false`、Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。
- この工程ではdeploy結果のdocs記録のみ。Codex側でEdge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、`updates.json` 変更、commit / pushは行っていない。

## M-14E-12B Discord同期Edge Function dry-run 500エラー修正
- deploy済み `sync-session-post-to-discord` の `create` / `dry_run = true` 確認でHTTP 500が発生した。
- 原因は、`callIsSessionGmRpc` で `supabase.rpc` を分離して呼んでいたことによるSupabase client rpc method binding issueとして整理した。
- `callIsSessionGmRpc` はclient本体を局所的に型緩和し、`rpcClient.rpc("is_session_gm", { target_session_id: sessionId })` として呼ぶ形へ修正した。
- `is_admin()` / `is_session_gm(...)` によるGM/adminのみ許可する権限判定方針は維持。
- Deno構文確認は成功。`rpc` のdestructureや `const rpc = ...` 形式は残っていない。
- `fetch(`、DB書き込み系メソッド、`console.` は追加していない。
- `dry_run = false` は有効化していない。Discord実送信処理、DB更新処理、フロント接続も追加していない。
- 次工程は、ユーザー確認後に修正版Edge Functionをdeployし、deploy後 `create` / `dry_run = true` を再確認すること。
- この工程ではFunctionコード修正とdocs記録のみ。SQL Editor実行、DB/RPC変更、Discord実送信、`dry_run = false` 実行、Edge Function deploy、フロント実装、秘匿値の実値記録、`updates.json` 変更、commit / pushは行っていない。

## M-14E-12D Discord同期Edge Function 修正版deploy後 dry-run 成功結果記録
- 作業前の作業ツリーはclean、最新commitは `4aeebdf Fix Discord sync RPC binding`。
- 修正版 `sync-session-post-to-discord` はユーザー手元でdeploy済み。deploy時にDocker未起動WARNINGは出たが、deploy自体は成功。
- ユーザー手元で `create` / `dry_run = true` を再実行し、HTTP 200で成功した。
- M-14E-12Bで発生していたHTTP 500は、Supabase client RPC method binding修正後の再deployで解消した。
- レスポンスJSON parseは成功し、`ok = true`、`dry_run = true`、`action = create` を確認した。
- レスポンスには `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings` が含まれた。
- `message_preview` は返却されたが、本文全文はdocsへ記録しない。確認対象依頼書ID相当の値、Supabase接続先、Authorization Bearer等の実値も記録していない。
- Discord実送信なし。`dry_run = false` 未実行。SQL Editor未実行。DB/RPC変更なし。
- `planned_db_update` はdry-run上の予定情報であり、実DB更新は行わない設計として扱う。
- 次工程候補は、`dry_run = false` 拒否確認、またはDiscord実送信実装前の追加安全レビュー。
- この工程ではdocs記録のみ。Edge Functionコード変更、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、`updates.json` 変更、commit / pushは行っていない。

## M-14E-13 Discord同期Edge Function dry_run=false拒否確認手順整理
- 作業前の作業ツリーはclean、最新commitは `253abab Record Discord sync dry run success`。
- deploy済み `sync-session-post-to-discord` について、`dry_run = false` が実送信へ進まず安全に拒否されることを確認する手順を整理した。
- この工程では `dry_run = false` は実行していない。Discord実送信も行っていない。
- payload例は `session_id` をプレースホルダーにし、`action = create`、`dry_run = false`、`request_source = manual_real_send_rejection_check` とする方針。
- 期待する挙動は、HTTP 4xxまたは `ok = false` 相当で拒否され、`real_send_not_enabled` または同等の拒否理由が返ること。
- 確認観点は、拒否レスポンス、Discord投稿なし、DB同期状態変更なし、Function Logsの安全性。
- 記録対象はHTTP status、response keys、error codeまたは一般化した拒否理由に絞る。レスポンス本文全文、確認対象依頼書ID相当の値、Supabase接続先全文、Authorization Bearer、Discord投稿先、`message_preview` 本文全文は記録しない。
- 停止条件は、成功送信扱い、Discord投稿作成、DB同期状態変更、秘匿値実値や認証系の生値の露出、拒否確認として扱えない想定外エラー。
- 停止条件に該当した場合は以後再実行せず、一般化した結果を記録して追加安全レビューへ戻る。
- この工程では手順整理のみ。SQL Editor実行、DB/RPC変更、Discord実送信、`dry_run = false` 実行、Edge Functionコード変更、Edge Function deploy、フロント実装、秘匿値の実値記録、`updates.json` 変更、commit / pushは行っていない。

## M-14E-13C dry_run=false拒否確認結果と単一募集チャンネル方針

- ユーザー手元でdeploy済み `sync-session-post-to-discord` の `create` / `dry_run = false` 拒否確認を実施済み。
- HTTP statusは501。レスポンスはJSONとしてparse可能で、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。
- `dry_run = false` は想定どおり実送信へ進まず拒否された。Discord実送信なし、DB/RPC変更なし、SQL Editor未実行、Edge Functionコード変更なし、Edge Function deployなし。
- 確認に使った認証文脈、対象依頼書ID相当の値、Supabase接続先全文、Discord投稿先、レスポンス本文全文、`message_preview` 本文全文は記録しない。
- M-14E-14の初期方針として、Discord依頼書同期の投稿先は「案A: 全依頼書を1つの募集チャンネルへ投稿」を採用する。
- GM別投稿先、依頼書種別別投稿先、セッション別投稿先は初期実装では行わず、将来拡張候補として残す。
- 投稿先の実値、外部送信用credential、チャンネル識別子相当の値はフロント、docs、GitHub、チャットに出さない。将来のsecret設定工程で扱う。
- 次工程候補は、単一募集チャンネル向けの実送信create実装方針整理、secret設定手順整理、失敗時挙動レビュー、またはDiscord実送信前の追加安全レビュー。
