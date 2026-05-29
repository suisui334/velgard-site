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
- カレンダー拡張 Phase 1-D として、セッション詳細表示の表示順をPL向けに整理済み。基本情報、概要、詳細 / 参加条件、参加希望コメント、タグ、補足情報の順で表示する。
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
- セッション詳細表示は、基本情報、概要、詳細 / 参加条件、参加希望コメント、タグ、補足情報の順で表示する。
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
