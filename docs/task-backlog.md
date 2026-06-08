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
- mypageの本人登録UIでは赤字注意文、入力例、折りたたみ式の確認方法を表示し、保存前に `^\d{17,20}$` 相当の形式チェックを行う。桁数不正、英字混じり、改行入り、`<@abc>`、`@数字ID風の値` は保存しない。空欄は未登録扱いとして維持する。
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

## M-14E-14 Discord同期Edge Function 単一募集チャンネル向けsecret設計

- 初期Discord依頼書同期は、全依頼書を1つの募集チャンネルへ投稿する方針で進める。
- GM別、依頼書種別別、セッション別の投稿先分岐は初期実装では行わず、将来拡張候補として残す。
- 初期実装ではWebhook方式を第一候補にする。単一チャンネル投稿と相性がよく、Bot tokenを扱わずに済むため安全境界を小さくできる。
- Bot方式は、将来の複数投稿先分岐や複雑なDiscord操作が必要になった場合に再検討する。
- secret名候補、投稿先解決、失敗時挙動、DB更新タイミングをdocsへ整理した。secret実値、投稿先実値、認証情報、確認対象依頼書ID相当の値は記録しない。
- DB更新は、実送信成功後に外部投稿識別子相当の値と同期状態を反映する案を第一候補にする。送信失敗時は依頼書保存自体を壊さず、同期失敗として扱う。
- 次工程候補は、M-14E-14B 実送信draft設計、M-14E-14C 実送信コード実装前レビュー、M-14E-14D secret設定手順整理、M-14E-14E 実送信確認。
- この工程ではdocs整理のみ。secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-14B/C Discord同期Edge Function 実送信draft設計
- 初期実送信は単一募集チャンネル向けWebhook方式の `create` から始める方針として整理した。GM別、依頼書種別別、セッション別の投稿先分岐は初期実装に含めず、将来拡張候補に残す。
- Webhook secretはEdge Function側で解決し、payload、フロント、docsに投稿先実値を持たせない。secret未設定時は一般化エラーで拒否し、Discord送信もDB更新も行わない。
- `dry_run = true` はpreview専用、`dry_run = false` は実送信有効化条件が揃うまで拒否を維持する。
- DB更新はDiscord送信成功後のみ行う案を第一候補にした。送信失敗時は依頼書保存自体を壊さず、同期失敗として一般化した理由だけを扱う。
- action別には、`create` を先行し、`update` / `close` / `delete` / `resync` は外部投稿識別子と状態遷移の設計を追加レビューしてから扱う。
- 実装前レビュー項目として、secret未設定時の拒否、dry-run境界、二重投稿防止、既存外部投稿識別子がある場合の `create` 挙動、送信成功後DB更新失敗時の扱い、ログ安全性を整理した。
- 次工程候補は、M-14E-14C 実送信コードdraft実装前レビュー、M-14E-14D secret設定手順整理、M-14E-14E secret設定後dry-run再確認、M-14E-14F テスト投稿確認、M-14E-14G DB更新連携、M-14E-14H フロント管理UI接続。
- この工程ではdocs整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14C Discord同期Edge Function Webhook実送信用draftコード
- `sync-session-post-to-discord` に将来のWebhook実送信用draft helperを追加した。
- helperは `DISCORD_SESSION_POST_WEBHOOK_URL` をsecret名候補として参照するが、実値は記録していない。
- Webhook payload draftは `content` と `allowed_mentions.parse = []` を使う形にした。
- Discord成功レスポンスから外部投稿識別子相当を抽出するdraft処理を置いたが、レスポンス全文は扱わない。
- 現行制御フローではhelperを呼ばない。`dry_run = false` は引き続き `real_send_not_enabled` 相当で拒否し、実送信へ進まない。
- DB更新処理、外部投稿識別子保存処理、同期状態更新処理、フロント接続はまだ追加していない。
- Codex環境では `deno` がPATH上に見つからず、`deno check` は未実施。Denoが利用できる環境での再確認を後続候補に残す。
- この工程ではEdge Functionコードdraftとdocs記録のみ行い、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、SQL Editor実行、DB/RPC変更、Edge Function deploy、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14D Discord同期Edge Function secret設定手順・設定後確認手順
- Webhook方式の投稿先secret名は `DISCORD_SESSION_POST_WEBHOOK_URL` で進める前提を整理した。
- Supabase CLIでは `npx.cmd supabase secrets set DISCORD_SESSION_POST_WEBHOOK_URL="<DISCORD_SESSION_POST_WEBHOOK_URL_VALUE>"` というプレースホルダー手順を記録した。実値はユーザー手元だけで扱い、docs、GitHub、DB、フロント、チャットには出さない。
- Supabase Dashboardで設定する場合は、対象project、対象Function環境、secret名、値欄の非共有を確認する方針にした。
- secret設定だけでは実送信は有効化されない。現行コードではWebhook helperは実行経路から呼ばれず、`dry_run = false` は `real_send_not_enabled` 相当で拒否される。
- secret設定後は、まず `dry_run = true` preview維持、次に実送信有効化前の `dry_run = false` 拒否維持、Function Logsのsecret非露出、Discord投稿増加なし、DB更新なしを確認する。
- 実送信有効化前の最終レビューとして、投稿先チャンネル確認、テスト用/本番募集チャンネル判断、誤投稿時の削除/訂正方針、二重投稿防止、既存外部投稿識別子がある場合の `create` 挙動、Discord成功後DB更新失敗時の扱いを整理した。
- 次工程候補は、M-14E-14E secret設定手順のユーザー確認、M-14E-14F secret設定後dry_run=true再確認、M-14E-14G 実送信有効化コード設計、M-14E-14H テスト投稿確認。
- この工程ではdocs整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14E Discord同期Edge Function secret設定前の最終意思決定
- `DISCORD_SESSION_POST_WEBHOOK_URL` の実secret設定前に、投稿先と初回確認方針をユーザー判断事項として整理した。
- 初期方針は「全依頼書を1つの募集チャンネルへ投稿」を維持する。docsでは投稿先実値を扱わず、「本番募集チャンネル」「テスト用チャンネル」の抽象名だけを使う。
- secret設定前の判断事項は、Webhook方式で進めるか、初回確認先をテスト用チャンネルにするか本番募集チャンネルにするか、検証用依頼書を使うか、誤投稿時の削除/訂正担当と手順、投稿文面が本番に出ても問題ないか。
- secret設定だけでは実送信は有効化されない。設定後も `dry_run = true` はpreview専用、`dry_run = false` は `real_send_not_enabled` 相当で拒否維持、Discord投稿なし、DB更新なしを確認する。
- 実送信有効化前の停止条件は、投稿先未確定、テスト/本番判断未確定、誤投稿時対応未確定、二重投稿防止未整理、既存外部投稿識別子がある場合の `create` 挙動未整理、Discord成功後DB更新失敗時の扱い未整理、secret実値や投稿先実値の露出リスク。
- 次工程候補は、M-14E-14F ユーザー手元でsecret設定、M-14E-14G secret設定後dry_run=true再確認、M-14E-14H secret設定後もdry_run=false拒否維持確認、M-14E-14I 実送信有効化コード変更案作成、M-14E-14J 初回テスト投稿確認。
- この工程ではdocs整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14F Discord同期Edge Function テスト用チャンネルsecret設定直前手順
- 初回実送信確認は、本番募集チャンネルではなくテスト用チャンネルを先に使う方針に確定した。
- テスト用チャンネル名、チャンネルID、Webhook URL、Discord投稿先実値はdocsへ記録せず、「テスト用チャンネル」という抽象名だけを使う。
- Discord側ではテスト用チャンネルを用意し、そのチャンネルにWebhookを作成する。Webhook URLはユーザー手元だけで扱い、チャット、docs、GitHub、Issue、README、console、ログへ貼らない。
- Supabase secret名は `DISCORD_SESSION_POST_WEBHOOK_URL` を使う。CLI手順は `npx.cmd supabase secrets set DISCORD_SESSION_POST_WEBHOOK_URL="<WEBHOOK_URL>"` のようにプレースホルダーのみで記録する。
- Dashboard設定時も対象project、対象Function環境、secret名、値欄非共有を確認する。PowerShell履歴、画面共有、スクリーンショットにWebhook URLが残らないよう注意する。
- secret設定後もすぐ実送信しない。まず `dry_run = true` preview維持、次に `dry_run = false` の `real_send_not_enabled` 拒否維持、Discord投稿増加なし、DB更新なし、Function LogsのWebhook URL非露出、git status cleanを確認する。
- 停止条件は、Webhook URLをdocs等へ貼った可能性、テスト用チャンネルではないWebhook設定、`dry_run = false` 拒否境界の崩れ、Function LogsへのWebhook URL露出、意図しないDiscord投稿、secret設定後dry-run確認未完了。
- 次工程候補は、M-14E-14G テスト用チャンネルWebhook作成、M-14E-14H Supabase secret設定、M-14E-14I secret設定後dry_run=true再確認、M-14E-14J dry_run=false拒否維持確認、M-14E-14K 実送信有効化コード変更案、M-14E-14L テスト用チャンネル初回実送信確認。
- この工程ではdocs整理のみ行い、実Webhook作成、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14G/H/I/J テスト用Webhook secret設定とdry-run確認結果
- ユーザー手元でテスト用チャンネル向けWebhook URLを取得し、Supabase secret `DISCORD_SESSION_POST_WEBHOOK_URL` へ設定済み。
- Webhook URL本体、投稿先実値、認証情報、確認対象依頼書ID相当の実値、Supabase接続先全文はdocs、GitHub、チャットへ記録していない。
- secret設定は成功扱い。Webhook URL値は環境変数から削除済み。一度誤った値を設定した可能性があったため、正しいテスト用Webhook URLで上書き済み。
- secret設定後 `create` / `dry_run = true` はHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create` を確認。`message_preview`、`planned_db_update`、`warnings` は返却あり。`message_preview` 本文全文は記録しない。
- secret設定後 `create` / `dry_run = false` はHTTP 501、JSON parse成功、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認し、拒否維持。
- ユーザー目視により、テスト用チャンネルに新規投稿が増えていないことを確認済み。
- secret設定だけではDiscord投稿は発生せず、実送信はまだ有効化していない。DB/RPC変更、SQL Editor実行、Edge Functionコード変更、deploy、フロント実装は行っていない。
- 次工程候補は、M-14E-14K 実送信有効化コード変更案レビュー、M-14E-14L テスト用チャンネル初回実送信確認手順整理、M-14E-14M 実送信有効化コード実装、M-14E-14N テスト用チャンネル初回実送信確認。
- この工程ではdocs記録のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14K Discord同期Edge Function 実送信有効化コード変更案レビュー
- 実送信有効化の最小範囲は、テスト用チャンネル向け `create` のみに限定する案を第一候補に整理した。
- `dry_run = true` はpreview専用のまま維持し、Discord送信とDB更新を行わない。
- `dry_run = false` の早期拒否解除は、`action = create`、GM/admin権限確認済み、同期対象確認済み、Webhook secret解決済み、直前dry-run確認済みの場合だけを候補にする。
- `update` / `close` / `delete` / `resync` は初回実装では未対応または拒否維持とする。
- 成功レスポンスは最小情報に丸め、Discord APIレスポンス全文、Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値は返さない。message id相当は初回では返さず、DB更新連携設計後に内部保持する案を第一候補にする。
- 初回実送信テストは、テスト用チャンネル、`create` のみ、検証用依頼書、実送信前dry_run=true再確認、テスト用チャンネルへ1件だけ投稿確認、二重実行なしを前提にする。
- DB更新連携は初回実送信では分離推奨。Discord投稿成功後DB更新失敗時の二重投稿や状態不整合を避けるため、外部投稿識別子保存、同期状態更新、失敗状態記録は後続工程で扱う。
- 二重投稿防止は、初回は手動1回のみで運用し、恒久対策として外部投稿識別子がある `create` の拒否または `update` / `resync` 誘導を後続設計に残す。
- ログ安全性として、Webhook URL、request body全文、Discord APIエラー本文全文、JWT、投稿先実値、確認対象依頼書ID相当の実値をログやレスポンスに出さない方針を整理した。
- 次工程候補は、M-14E-14L 実送信有効化コード実装、M-14E-14M deno check / 安全検索 / 差分レビュー、M-14E-14N deploy、M-14E-14O dry_run=true再確認、M-14E-14P テスト用チャンネルでcreate実送信1回確認、M-14E-14Q 結果docs記録。
- この工程ではdocs整理のみ行い、Edge Functionコード変更、deploy、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14L Discord同期Edge Function テスト用チャンネル向けcreate実送信コード
- `sync-session-post-to-discord` に、テスト用チャンネルWebhook secretを使う `action = create` の実送信経路を接続した。
- `dry_run = true` はpreview専用のまま維持し、Webhook helperを呼ばない。
- `dry_run = false` かつ `action = create` の場合のみ、権限確認、対象依頼書取得、同期対象判定、action検証を通過した後にWebhook helperを呼ぶ。
- `update` / `close` / `delete` / `resync` は初回実装では `unsupported_action` 相当で拒否維持。
- secret `DISCORD_SESSION_POST_WEBHOOK_URL` が未設定、空、不正な場合は一般化エラーで拒否し、fetchを呼ばない。
- Webhook payloadは既存preview本文相当を `content` とし、`allowed_mentions.parse = []` を維持する。
- 成功時レスポンスは最小限にし、外部投稿識別子相当の実値、Discord APIレスポンス全文、Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値、`message_preview` 本文全文は返さない。
- DB更新処理、外部投稿識別子保存、同期状態更新は追加していない。
- この工程ではコード実装とdocs記録のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14M Discord同期Edge Function deploy前最終安全確認
- 最新commitは `feb9f24 Enable Discord create send path for test webhook`、作業開始時の `git status --short` はclean。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は成功。Codex側シェルでは `deno` がPATH上にないため、既存Deno実行ファイルを直接指定して確認した。
- 安全検索では、`fetch(` はWebhook helper内の想定箇所のみ。DB書き込み系メソッドと `console.*` は0件。
- `dry_run = true` はpreview専用維持。`dry_run = false` で実送信候補になるのは `action = create` のみ。
- `update` / `close` / `delete` / `resync` は拒否維持。secret未設定、空、不正時はfetch前に一般化エラーで拒否する。
- 初回実送信はテスト用チャンネル、検証用依頼書、手動1回のみを前提にする。本番募集チャンネルにはまだ送らない。
- DB更新、外部投稿識別子保存、同期状態更新は未実装のまま。恒久的な二重投稿防止は後続のDB更新連携工程で扱う。
- deploy前停止条件は、git dirty、Deno確認失敗、想定外fetch、DB書き込み、`console.*`、秘匿値や投稿先実値の混入、テスト用チャンネル/検証用依頼書/1回実行運用の未確定。
- 次工程候補は、M-14E-14N Edge Function deploy、M-14E-14O deploy後 `dry_run = true` preview維持確認、M-14E-14P テスト用チャンネルで `create` 実送信1回確認、M-14E-14Q 結果記録、M-14E-14R DB更新連携設計。
- この工程では確認とdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-14Q Discord同期Edge Function テスト用チャンネル初回実送信結果
- ユーザー手元で、deploy済み `sync-session-post-to-discord` の `create` / `dry_run = false` 初回実送信を1回だけ実施した。
- 対象は検証用依頼書 `TEST_1`。確認対象ID相当の実値、Webhook URL、投稿先実値、認証情報、Supabase接続先全文、Discord message id相当の実値、`message_preview` 本文全文は記録しない。
- HTTP statusは200。レスポンスはJSONとしてparse成功。
- レスポンスキーは `ok` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- `ok = true`、`dry_run = false`、`action = create` を確認。
- 外部投稿識別子相当の実値はレスポンスに返っていない。
- テスト用チャンネルに依頼書通知が1件作成されたことを確認済み。本番募集チャンネルへの投稿はなし。
- DB更新連携、外部投稿識別子保存、同期状態更新は未実装のため、今回のFunction処理ではDB更新を行わない設計。
- 今回、PowerShellの確認入力で意図した確認語を入力していないにもかかわらず、貼り付け済みの後続行が実行され、実送信が行われた。結果はテスト用チャンネルへの1件投稿に留まり、重大事故には至っていない。
- 今後の実送信系手順では、対話プロンプト依存にせず、確認コマンドと送信コマンドを明確に分離する。同じ検証用依頼書での再実行は禁止。
- 次工程候補は、M-14E-14R DB更新連携設計、M-14E-14S 外部投稿識別子保存と二重投稿防止方針整理、M-14E-14T 本番募集チャンネル切り替え判断。
- この工程ではdocs記録のみ行い、追加実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Function deploy、Edge Functionコード変更、SQL Editor実行、DB/RPC変更、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15 Discord依頼書投稿フォーマット改善・開催場所フィールド追加設計
- テスト用チャンネルへの初回実送信は成功したが、現行のDiscord投稿本文はDB項目列挙寄りで読みにくいため、参加者向けの依頼書形式へ改善する方針を整理した。
- 新フォーマットは、冒頭に `＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝` を置き、`■依頼書【タイトル】`、GM、開催場所、日時、参加人数、参加締切、概要を並べる案を第一候補にする。
- Discord本文には `詳細` 欄、サイト詳細URL、クエリ付き詳細導線、下部区切り線を入れない。URLを入れるとDiscord側のOGP/埋め込み表示で画面が散らかるため、本文は概要までで完結させる。
- 「開催場所」は物理会場ではなく、Tekey、ココフォリア、ユドナリウムリリィ、Discordボイス等のセッションツール/開催環境を指す。内部名は `session_tool` を第一候補にした。
- DB/RPC観点では、依頼書テーブルに `session_tool` 相当列があるかを後続preflightで確認し、なければ `create_session_post(...)` / `update_session_post(...)` / detail/list取得処理への追加を検討する。既存データはNULLまたは空文字を許容し、表示時は `未定` へ丸める案を第一候補にする。
- 依頼書編集UIでは、募集人数min/maxを同じ行へまとめ、空いた位置に開催場所入力を置く案を第一候補にする。初期は自由入力を優先し、候補式にする場合もその他/自由入力の逃げ道を残す。
- session-detailでは、参加者向け情報を上に、GM/admin管理操作を下に寄せる。開催場所を右側情報枠に表示し、管理ブロックは募集状態の下へ移動する案を検討する。
- Edge Functionでは、`dry_run = true` previewと実送信本文で同じ新フォーマットを使う。日時はISO/UTC表記ではなく、曜日入りの短い日本語形式へ整形する。
- 次工程候補は、M-14E-15B DB/RPC変更SQL draft、M-14E-15C SQL apply前レビュー、M-14E-15D UIフィールド追加、M-14E-15E session-detail表示調整、M-14E-15F Edge Functionフォーマット変更、M-14E-15G dry_run QA、M-14E-15H テスト用チャンネル実送信QA。
- この工程では設計docs整理のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15B 開催場所/session_tool追加DB/RPC preflight・SQL draft設計
- `開催場所` は物理会場ではなくセッションツール/開催環境を指す項目として、内部名 `session_tool` を第一候補にする方針を維持する。
- SELECT-only preflight SQL draft `docs/supabase/sql/026_session_tool_preflight_select_only.sql` を作成した。単一結果セットで、`sort_order` / `section` / `check_name` / `expected` / `status` / `result_value` / `notes` を返す。
- preflightでは `public.sessions` と `public.session_posts` 候補、`session_tool` / `play_location` / `venue` / `session_place` 類似列、public schema内のtool/location系列、`create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` のsignature・security・EXECUTE権限、session関連function scan、helper、RLS、policy概要を確認する。
- `session_tool` 列案は `text` / NULL許容を第一候補にする。既存データは未設定扱いで保持し、RPC側で空文字をtrim後NULLへ丸め、表示時は `未定` にする。
- 初期実装では固定候補CHECKを置かず、自由入力を優先する。必要なら後続apply draftで文字数上限や改行拒否など軽い制約だけ検討する。
- RPC変更は、`create_session_post(...)` と `update_session_post(...)` へ `p_session_tool text default null` を追加する候補。ただしPostgREST RPCのdefault引数overload曖昧化を避けるため、preflight結果後に旧signature drop/recreateか別RPC化をレビューする。
- 詳細/list取得が直接SELECTなら取得列に `session_tool` を追加する。detail/list RPCが存在する場合は戻り値へ含める。`delete_session_post(text)` は `session_tool` を扱わない。
- Discord新フォーマットでは `開催場所【session_toolまたは未定】` を使い、サイト詳細URLや内部ID、認証情報、外部投稿先実値は本文へ入れない。
- 次工程候補は、M-14E-15C preflight SQL手動実行、M-14E-15D preflight結果にもとづくapply draft、M-14E-15E apply前レビュー、M-14E-15F ユーザー手動SQL Editor適用、M-14E-15G フロントUI実装、M-14E-15H session-detail表示調整、M-14E-15I Edge Functionフォーマット変更、M-14E-15J dry_run QA。
- この工程では調査・SQL draft・docs整理のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15C 開催場所/session_tool preflight実行結果
- ユーザーがSupabase SQL Editorで `docs/supabase/sql/026_session_tool_preflight_select_only.sql` を手動実行した。
- 初回はSQL内の日本語説明文字列がPowerShell経由で文字化けし、文字列リテラルが壊れて構文エラーになった。対策として、preflight SQL内の説明文字列と結果ラベルをASCIIへ寄せた。
- 修正版ではSQL Editorに単一結果セットの結果グリッドが表示された。
- `public.sessions` は存在し、現状の依頼書相当テーブル候補として妥当。`public.session_posts` は見つからなかった。
- `session_tool` 列は存在しない。`play_location` / `venue` / `session_place` / `session_place_name` 等の類似列も見つからない。
- `session_tool` 関連CHECK制約は見つからないため、初期自由入力案と矛盾しない。
- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` は存在する。create/updateはsession_tool対応のsignature変更または別RPC化検討が必要。deleteはsession_tool追加対象外でよさそう。
- 既存RPCは `security_definer` と `search_path` 設定あり、`authenticated` EXECUTEあり、`anon` / `public` は基本なしの既存方針と整合する。
- `public.sessions` のRLSは有効で、policyは複数存在する。nullable text列追加だけでRLS境界を広げない方針を維持する。
- session_tool列追加案は `text null`、空文字trim後NULL、表示時 `未定` fallback、初期CHECKなし自由入力を第一候補にする。
- 次工程候補は、M-14E-15D preflight結果にもとづくsession_tool追加SQL apply draft作成。
- この工程ではdocs記録とpreflight SQL draftのASCII説明文修正のみ行い、SQL apply、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15D 開催場所/session_tool追加SQL apply draft作成
- M-14E-15Cのpreflight結果にもとづき、未実行のapply review draft `docs/supabase/sql/027_session_tool_apply_review_draft.sql` を作成した。
- draftでは `public.sessions.session_tool text null` を追加する。既存データへの一括値設定は行わず、NULLを未設定として扱う。
- 初期実装では固定候補CHECK制約を追加せず、自由入力を優先する。RPC内では空文字をtrim後NULLへ丸め、改行拒否と80文字上限をdraftに含めた。
- `create_session_post(...)` / `update_session_post(...)` は最終引数 `p_session_tool text default null` を追加する案。PostgREST RPCのdefault引数overload曖昧化を避けるため、既存signatureと新signature候補をdrop/recreateするdraftにした。
- `delete_session_post(text)` は物理削除用途のため、`session_tool` 追加対象外として扱う。
- RPCの `security definer` / `set search_path = ''` / `authenticated` EXECUTE方針を維持し、`public` / `anon` にはEXECUTEを許可しない。
- post-apply確認SELECTとして、列存在、RPC signature、security/search_path、EXECUTE権限、RLS状態を確認する項目を含めた。
- rollbackでは安易に `DROP COLUMN` しない。列削除は保存済み `session_tool` のデータ消失につながるため、必要なら別工程で影響確認する。
- SQL draft内にapply用のDDL/GRANT/REVOKEは含むが、この工程ではSQL Editor実行を行わない。INSERT/UPDATEはRPC本文内にのみ現れ、既存データを直接変更するDMLとしては実行されない。
- 次工程候補は、M-14E-15E SQL apply draftレビュー、M-14E-15F ユーザー手動SQL Editor適用、M-14E-15G SQL適用結果記録、M-14E-15H フロントUI実装、M-14E-15I session-detail表示調整、M-14E-15J Edge Function投稿フォーマット変更。
- この工程ではSQL apply draft作成とdocs整理のみ行い、SQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15E 開催場所/session_tool追加SQL apply draftレビュー
- `docs/supabase/sql/027_session_tool_apply_review_draft.sql` をSQL Editor適用前レビューした。
- 実行順序は、列追加、create RPC drop/recreate、create権限整理、update RPC drop/recreate、update権限整理、commit、最後にSELECT-only検証という流れに整理した。
- RPC再作成と権限整理部分を明示トランザクションで包むようSQL draftを修正した。
- `DROP TABLE` / `DROP COLUMN` / `TRUNCATE` は実行文として入れない。`DROP FUNCTION` はsignature明示のRPC整理目的のみで、`CASCADE` は使わない。
- `INSERT` / `UPDATE` はRPC本文内にのみ存在し、apply時に既存データを直接変更するDMLではない。
- `create_session_post(...)` は `p_session_tool text default null` を最終引数に追加し、空文字をNULLへ丸める。
- `update_session_post(...)` は `p_session_tool text default null` を最終引数に追加し、未指定なら既存値保持、空文字ならNULL化するようdraftを修正した。
- `delete_session_post(text)` は `session_tool` 追加対象外。
- `security definer` / `set search_path = ''` / authenticated EXECUTE維持、anon/public不可方針を確認した。
- RLS policyはnullable text列追加だけなら変更不要。ただし適用後SELECTでRLS有効状態を確認する。
- rollbackでは安易に `DROP COLUMN session_tool` しない。適用中エラー時は再実行せず停止し、反映状態を確認する。
- 次工程候補は、M-14E-15F ユーザー手動SQL Editor適用、M-14E-15G SQL適用結果記録、M-14E-15H フロントUI実装、M-14E-15I session-detail表示調整、M-14E-15J Edge Function投稿フォーマット変更。
- この工程ではレビュー・docs整理・SQL draft修正のみ行い、SQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15F 開催場所/session_tool追加SQL apply手動実行前最終確認
- SQL Editorへ貼る対象は `docs/supabase/sql/027_session_tool_apply_review_draft.sql` 全体と整理した。
- SQLファイル冒頭には未実行draft、レビュー必須、このチャットでは実行しないことが明記されている。
- SQL Editor実行前に、古いSQL Editor内容を消してから全文を貼る。
- PowerShellで全文をクリップボードへ送る候補は `Get-Content -Raw -Encoding UTF8 .\docs\supabase\sql\027_session_tool_apply_review_draft.sql | Set-Clipboard`。
- 実行前チェックは、git clean、最新commit `fe7d5ef Review session tool apply draft`、DROP TABLE/DROP COLUMN/TRUNCATE/CASCADE実行文なし、standalone DMLなし、DROP FUNCTION対象signature明示、secretやURL実値なし。
- SQL Editorでエラーが出たら即停止し、同じSQLを再実行しない。permission denied、function does not exist、duplicate function、cannot drop functionなども停止条件。
- 成功時は、`session_tool` 列、create/update RPC signature、delete RPC対象外、authenticated EXECUTE、anon/public不可、RLS有効を確認する。
- SQL Editorが一部結果グリッドしか表示しない場合は再実行せず、見えている範囲とエラーなしを記録し、M-14E-15Hで追加確認する。
- 実データ行、ユーザーID、メールアドレス、認証情報、外部投稿先実値、Discord message id相当の実値は記録しない。
- SQL適用後もすぐにフロント実装、Edge Function変更、Discord実送信、dry-runへ進まず、先に適用結果docs記録を行う。
- 次工程候補は、M-14E-15G ユーザー手動SQL Editor実行、M-14E-15H SQL適用結果docs記録、M-14E-15I フロントUI実装、M-14E-15J session-detail表示調整、M-14E-15K Edge Function投稿フォーマット変更、M-14E-15L dry_run QA。
- この工程では最終確認・docs整理のみ行い、SQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15H 開催場所/session_tool追加SQL適用結果docs記録
- M-14E-15Gとして、ユーザー手元で `docs/supabase/sql/027_session_tool_apply_review_draft.sql` 全体をSupabase SQL Editorへ貼り付けて手動実行した。
- SQL Editorはエラー表示ではなく結果グリッドを表示したため、SQL applyは成功扱いとする。
- 最後に見えていた結果はRLS確認で、`sessions_rls_enabled = true`、`sessions_force_rls = false`。
- SQL Editorが最後の結果グリッドのみ表示している可能性があるため、同一apply SQLは再実行しない。
- `session_tool` 列、create/update RPC signature、EXECUTE権限などの詳細確認は、必要なら次工程でSELECT-only確認として行う。
- DB/RPC変更はユーザー手元SQL applyにより適用済みとして扱う。このdocs記録工程ではDB/RPC追加変更は行わない。
- 実データ行、ユーザーID、メールアドレス、認証情報、project ref、Supabase URL全文、外部投稿先実値、Discord message id相当の実値は記録していない。
- 次工程候補は、M-14E-15I 必要なら適用後SELECT-only確認、M-14E-15J フロントUIへ `session_tool` 追加、M-14E-15K session-detail表示調整、M-14E-15L Edge Function Discord投稿フォーマット変更、M-14E-15M dry_run QA。
- この工程ではdocs記録のみ行い、SQL Editor再実行、追加SQL apply、DB/RPC追加変更、Edge Functionコード変更、deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15I/J/K session_tool UI・詳細表示・Discord投稿フォーマット実装
- SQL適用後SELECT-only確認として、`public.sessions.session_tool` は `text` / NULL許容、create/update RPCは `p_session_tool` 引数あり、delete RPCは変更対象外、`public.sessions` RLSは `rls=true, force_rls=false` と記録した。
- session-post作成/編集フォームへ `開催場所` 入力を追加し、`create_session_post` / `update_session_post` のpayloadへ `p_session_tool` を渡す。
- session-post管理一覧取得、既存依頼書編集反映、session-postテンプレートJSON、mypage依頼書用テンプレートフォームにも `session_tool` / `p_session_tool` を含める。
- session-detailの基本情報へ `開催場所` を追加し、未設定時は `未定`。GM/admin管理操作は補足情報内の募集状態の下へ移動する。
- Edge FunctionのDiscord本文生成を参加者向け依頼書形式へ変更し、詳細URLやクエリ付き導線を本文に入れない。日時は曜日つき短縮形式、参加人数は `2～5人` 形式、開催場所未設定は `未定`。
- 次工程候補は M-14E-15L `dry_run = true` QA、M-14E-15M テスト用チャンネル実送信QA、M-14E-15N DB更新連携/二重投稿防止設計。
- この工程ではコード実装とdocs整理のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Function deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、`updates.json` 変更、commit / pushは行わない。

## M-14E-15L/M deploy後 dry_run=true新フォーマットpreview確認
- `f76064f Add session tool UI and Discord post format` の状態でdeploy済みの `sync-session-post-to-discord` について、ユーザー手元で `create / dry_run = true` を再確認した。
- 前回のHTTP 401は、JWT期限切れまたは無効化の可能性が高く、Edge Functionや新フォーマットの失敗とは判断しない。
- ユーザー手元でJWTをPowerShell待機方式により再取得した。JWT本体は記録していない。JWTは3パート形式として確認済み。
- 確認対象IDも待機方式により再取得した。ID本体は記録していない。値は出力していない。
- 再確認結果はHTTP 200、HTTP errorなし、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返却あり。ただし本文全文は記録しない。previewは125文字、9行。
- 新フォーマット確認として、冒頭区切り線あり、開催場所ラベルあり、詳細URLなし、詳細ラベルなし、ISO/UTC表記なしを確認した。
- `planned_db_update` と `warnings` は返却あり。ただしdry-run上の予定情報であり、DB更新実行ではない。
- Discordテスト用チャンネルをユーザーが目視確認し、新規投稿が増えていないことを確認済み。
- `dry_run = false` 実送信、追加Discord投稿、DB更新連携、外部投稿識別子保存、同期状態更新は未実施。
- M-14E-15L/M相当のdeploy後 `dry_run = true` 新フォーマットpreview確認は完了扱いとする。

次工程候補:

- UI手動QAを優先する。依頼書作成で開催場所入力、依頼書編集で開催場所変更、保存後session-detailで開催場所表示、未入力時の `未定` 表示を確認する。
- 募集人数min/maxの同一行UI崩れ、GM/admin管理ブロックの配置を確認する。
- 必要なら、その後に新しい検証用依頼書で新フォーマット実送信を1回だけ別工程として扱う。
- 旧フォーマットで送信済みの既存検証用依頼書は、二重投稿防止のため再利用しない。
- DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程として残す。
- この工程ではdocs記録のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15N-FIX session_tool UI手動QAと空欄クリア修正
- M-14E-15Nとして、ユーザー実ブラウザでsession_tool UI手動QAを実施した。
- 新規依頼書作成で開催場所を入力して保存でき、session-detailに開催場所が表示された。
- 編集で開催場所を別値へ変更して保存でき、session-detailに変更後の開催場所が表示された。
- 募集人数min/max欄の見た目崩れなし。
- GM/admin管理ブロックは補足情報内の募集状態下、更新日時前に表示され、参加者向け基本情報の上部を邪魔していない。
- raw id、user_id、email、token等の画面露出なし。
- Discordテスト用チャンネルに新規投稿増加なし。
- 不具合として、編集時に開催場所を空欄保存しても `未定` 表示にならず、前回入力値が保持される問題を発見した。
- 原因は、更新payloadで空欄が `nullableText(...)` により `null` へ変換され、`update_session_post` 側で既存値保持として扱われたこと。
- `assets/js/renderSessionPost.js` の `buildUpdatePayload()` で、更新時の `p_session_tool` を `getValue(form, "p_session_tool")` に変更した。
- 新規作成時は従来どおり空欄を `null` とし、更新時だけ空欄を空文字としてRPCへ送り、明示クリアできるようにした。
- DB/RPC変更なしで修正完了。
- 修正後、編集で開催場所を空欄保存し、session-detailで `未定` 表示になることをユーザー実ブラウザで確認済み。
- Discord投稿増加なし、`dry_run = false` 未実行。

次工程候補:

- M-14E-15O: session_tool UI QA結果とFIXをcommit / pushする。
- その後、必要なら新しい検証用依頼書で新フォーマット実送信を1回だけ別工程として扱う。
- 旧フォーマットで送信済みの既存検証用依頼書は、二重投稿防止のため再利用しない。
- DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程として残す。
- この工程ではコード修正、docs記録、静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-A 公開サイト反映後QAとDiscord新フォーマット実送信前安全レビュー
- `73968eb Fix session tool clear handling` がGitHub Pagesへ反映された後、ユーザー実ブラウザで再QAした。
- 開催場所を空欄保存するとsession-detailで `未定` 表示になった。
- 再編集画面でも開催場所欄が空欄になった。
- Discord投稿増加なし。
- raw id、user_id、email、token等の画面露出なし。
- `73968eb` の修正は公開サイトにも反映済みと判断する。
- 次工程は、新しい検証用依頼書を使ったDiscord新フォーマット実送信1回確認に向ける。
- 既存 `TEST_1` は旧フォーマットで送信済みのため再利用しない。
- 今回のUI QA用依頼書も編集検証済みのため、実送信用には別の新規検証用依頼書を推奨する。
- 推奨タイトルは `M14E15P_discord_format_QA_01`。
- 初回実送信はテスト用チャンネルのみ。本番募集チャンネル投稿なし。
- 実送信前に必ず `dry_run = true` preview確認を行う。
- 確認コマンドと送信コマンドは分離し、対話プロンプト依存の送信手順は禁止する。
- `dry_run = false` はユーザー確認後、独立工程で1回のみ実行する。
- preview確認項目は、HTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`、`message_preview` あり、冒頭区切り線あり、開催場所ラベルあり、詳細URLなし、詳細ラベルなし、ISO/UTC表記なし、Discord投稿増加なし。
- 停止条件は、JWT/確認対象ID/Supabase URL準備失敗、preview確認失敗、previewへのURL/詳細リンク/ISO/UTC混入、旧 `TEST_1` または意図しない依頼書、テスト用チャンネルではない疑い、投稿済み対象の再利用疑い、不明なエラー。
- Discord投稿後も、DB更新連携、外部投稿識別子保存、同期状態更新は未実装のまま。
- 実送信確認後も、二重投稿防止、DB更新連携、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程として残す。
- この工程ではdocs記録と安全レビューのみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-B 新規検証用依頼書 dry_run=true preview確認
- 新しい検証用依頼書 `M14E15P_discord_format_QA_01` を対象に、ユーザー手元で `create / dry_run = true` previewを確認した。
- 旧 `TEST_1` は再利用していない。
- UI QA用依頼書も再利用していない。
- PowerShell待機方式で確認対象IDを安全に取得した。ID本体は記録しない。
- JWTはユーザー手元で再取得した。JWT本体は記録しない。
- `SESSION_ID_CAPTURED = true`、`SESSION_ID_SET = true`、`SESSION_ID_LENGTH = 27`。
- `USER_JWT_READY = true`、`SESSION_ID_READY = true`、`SUPABASE_URL_READY = true`。
- preview確認結果は、HTTP 200、HTTP errorなし、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返却あり。ただし本文全文は記録しない。previewは145文字、9行。
- 新フォーマット確認として、冒頭区切り線あり、開催場所ラベルあり、対象タイトル一致、詳細URLなし、詳細ラベルなし、ISO/UTC表記なしを確認した。
- `planned_db_update` と `warnings` は返却あり。ただしdry-run上の予定情報であり、DB更新実行ではない。
- Discordテスト用チャンネルをユーザーが目視確認し、新規投稿が増えていないことを確認済み。
- M-14E-15P-B `dry_run = true` preview確認は完了扱いとする。

次工程候補:

- M-14E-15P-C: テスト用チャンネルへの `create / dry_run = false` 実送信1回確認。
- 実送信時は確認コマンドと送信コマンドを分離し、対話プロンプト依存の送信手順を使わない。
- DB更新連携、外部投稿識別子保存、二重投稿防止、action拡張、本番募集チャンネル切り替えは後続工程として維持する。
- この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 実送信、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-C テスト用チャンネル create dry_run=false 実送信1回確認
- 新しい検証用依頼書 `M14E15P_discord_format_QA_01` を対象に、ユーザー手元で `create / dry_run = false` 実送信を1回だけ実行した。
- 旧 `TEST_1` は再利用していない。
- UI QA用依頼書も再利用していない。
- 実送信はテスト用チャンネル向けWebhook設定のまま実施した。
- 送信対象確認コマンドと送信コマンドは分離済み。
- 送信前確認として、JWT、確認対象ID、Supabase URLの準備が整っていることと、対象タイトルが `M14E15P_discord_format_QA_01` であることを確認した。
- 実送信結果はHTTP 200、HTTP errorなし、JSON parse成功、`ok = true`、`dry_run = false`、`action = create`。
- レスポンスキーは `ok,dry_run,action,sync_target,discord_send,db_update,warnings`。
- `discord_send`、`db_update`、`warnings` は返却あり。
- `message_preview` は返却なし。
- 外部投稿識別子相当は存在検知されたが、実値は記録しない。
- Discordテスト用チャンネルに新規投稿が1件増えた。
- 投稿は「依頼書通知」アプリから送信され、タイトルは `M14E15P_discord_format_QA_01` 相当。
- 投稿本文は、冒頭区切り線あり、GM表示あり、開催場所表示あり、日時は日本語短縮形式、参加人数表示あり、参加締切表示あり、概要表示あり、詳細URL/詳細リンクなし、ISO/UTC表記なし。
- 本番募集チャンネル投稿なし。
- message_preview本文全文、Discord message id実値、Discord投稿先実値、JWT、確認対象ID、project ref、Supabase URL全文は記録しない。
- M-14E-15P-Cのテスト用チャンネル新フォーマット実送信1回確認は成功扱いとする。
- 実送信コマンドは再実行禁止。

次工程候補:

- M-14E-15P-D: 実送信結果docsのcommit / push。
- M-14E-15S以降: DB更新連携、外部投稿識別子保存、二重投稿防止設計。
- `update` / `close` / `delete` / `resync` 対応、GM/admin同期UI、本番募集チャンネル切り替えは後続工程として維持する。
- 本番募集チャンネル切り替えはまだ行わない。
- この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16A Discord同期DB更新連携・外部投稿識別子保存・二重投稿防止設計
- M-14E-15P-Cでテスト用チャンネルへの新フォーマット実送信1回確認が成功したため、次工程としてDB更新連携、外部投稿識別子保存、`create` 二重投稿防止を設計した。
- 目的は、Discord投稿成功後に依頼書DBへ外部投稿識別子相当と同期状態を保存し、同じ依頼書への `create` 二重投稿を防ぎ、将来の `update` / `close` / `delete` / `resync` の足場を作ること。
- 保存候補カラムは `discord_message_id`、`discord_channel_id`、`discord_sync_status`、`discord_last_action`、`discord_synced_at`、`discord_sync_error`、`discord_sync_error_at`、`discord_sync_attempted_at`、`discord_webhook_kind`、`discord_target_kind` など。
- 初期状態設計は過剰に複雑化せず、`synced` / `failed` / `not_synced` 相当を中心にし、既存CHECK制約がある場合は既存値へマッピングする。
- 外部投稿識別子相当が既にある依頼書への `action = create` は拒否し、将来は `update` または `resync` へ誘導する方針。
- Discord送信成功後にDB更新が失敗した場合は、Discord送信成功とDB更新失敗を分けて返す必要がある。再実行は二重投稿リスクになる。
- `dry_run = true` ではDB更新しない。`dry_run = false` かつDiscord送信成功後のみDB更新する方針。
- DB更新連携、外部投稿識別子保存、二重投稿防止、本番初回実送信手順レビューが揃うまで、本番募集チャンネル切り替えは行わない。
- SELECT-only preflight SQL draftとして `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` を作成した。
- preflightでは、`public.sessions` のDiscord同期系カラム、類似カラム、CHECK制約、session posting RPC signature、関連function、helper、RLS、policy概要、EXECUTE権限を単一結果表で確認する。
- SQL Editor実行は次工程。今回の工程では実行しない。

次工程候補:

- M-14E-16B: ユーザー手元で `028_discord_sync_state_preflight_select_only.sql` をSQL Editor手動実行。
- M-14E-16C: preflight結果docs記録。
- M-14E-16D: DB更新連携/RPCまたはEdge Function内DB更新方針のapply draft設計。
- M-14E-16E: `create` 二重投稿防止コード設計。
- M-14E-16F: テスト用チャンネルでDB更新連携QA。
- この工程ではdocs設計とSELECT-only preflight SQL draft作成のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16C Discord同期DB状態 preflight実行結果記録
- ユーザー手元で `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` をSupabase SQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行した。
- SQL Editorではエラーなしで結果グリッドが表示された。
- 同じSQLの再実行はしていない。
- `public.sessions` は存在し、依頼書基本カラムは確認上OK。
- core column summaryは `15/15 present`。
- `session_tool` も存在確認済み。
- Discord同期系カラムとして、`discord_message_id`、`discord_channel_id`、`discord_thread_id`、`discord_post_url`、`discord_sync_status`、`discord_last_action`、`discord_sync_requested_at`、`discord_synced_at`、`discord_sync_error` を確認。
- required sync column summaryは `4/4 present`。
- optional sync column summaryは `6/10 present`。
- `discord_last_synced_at` 候補は `discord_synced_at` 類似カラムとして扱えそう。
- `discord_sync_error_at`、`discord_sync_attempted_at`、`discord_webhook_kind`、`discord_target_kind` は未検出候補として記録する。
- `discord_sync_status` / `discord_last_action` / posting status / visibility のCHECK制約は確認上OK。
- ただし実装前に、許容値の正確な表現は既存制約に合わせる必要がある。
- `create_session_post` / `update_session_post` / `delete_session_post` RPCあり。
- 各RPCはsecurity definer、search_path明示、authenticated EXECUTEあり、anon/PUBLIC不可を確認上OK。
- public function名にdiscord/sync/resyncを含むものは一部検出。sync専用helperは未検出。
- `has_role(text)`、`is_admin()`、`is_session_gm(text)`、`user_roles` は確認上OK。
- `sessions` と `user_roles` はRLS enabled。
- policy概要は取得できたが、具体的なpolicy本文や実値は記録しない。
- create double-post prevention readinessは、外部投稿識別子相当が存在するため設計上進められる見込み。
- sync state update readinessは、`discord_sync_status` / `discord_last_action` / `discord_synced_at` が存在するため設計上進められる見込み。
- Discord成功後DB更新失敗時の扱いはmanual review required。
- production channel switch gateはclosedのまま。本番募集チャンネル切り替えはまだ行わない。

判断:

- 新規カラム追加なしでも、既存Discord同期系カラムを使ってDB更新連携を実装できる可能性が高い。
- 二重投稿防止は `discord_message_id` 等の既存外部投稿識別子を使う方針が有力。
- DB更新はEdge Functionから直接updateするか、専用RPCを追加するかを次工程で比較する。
- DB/RPC変更やEdge Function変更はまだ行わない。

次工程候補:

- M-14E-16D: preflight結果に基づくDB更新連携実装設計。
- CHECK制約の既存許容値に合わせた状態更新案を整理する。
- DB更新経路をEdge Function直接updateにするか専用RPCにするか比較する。
- `create` 二重投稿防止をDB側、RPC側、Edge Function側のどこで担保するか決める。
- この工程ではdocs記録と静的確認のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16D/E Discord同期DB更新連携・二重投稿防止 実装設計
- M-14E-16Cのpreflight結果を踏まえ、新規カラム追加なしで既存Discord同期系カラムを使う案を第一候補として整理した。
- 外部投稿識別子の主軸は `discord_message_id`。
- `discord_channel_id` / `discord_thread_id` / `discord_post_url` は投稿先照合や将来UIに使える候補。ただし実値はdocs/console/画面に出さない。
- `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` の更新タイミングを整理した。
- `dry_run = true` ではDB更新しない。
- `dry_run = false` かつDiscord送信成功後のみDB更新する。
- CHECK制約の許容値に合わせる必要があるため、`synced` / `not_synced` 等の想定値だけで実装しない。
- 必要なら追加SELECT-onlyで `discord_sync_status` / `discord_last_action` の制約定義を確認する。ただし実行は別工程。

DB更新経路比較:

- A案: Edge Functionから `public.sessions` をサーバー側で直接update。実装は速いが、権限境界・原子性・監査性がEdge Function側に寄りやすい。
- B案: Discord同期状態更新専用RPCを追加。二重投稿防止、状態遷移、権限、search_path、一般化エラーをDB側へ閉じ込めやすい。SQL/RPC applyゲートが必要。
- C案: 既存 `update_session_post` へ混在。既存RPCを使えるが、GM編集用RPCと同期状態更新が混ざるため非推奨。
- 暫定結論として、専用RPC案を第一候補とする。

二重投稿防止方針:

- `action = create` 時、対象sessionに `discord_message_id` 等が既に存在する場合はDiscord送信前に拒否する。
- 拒否時は一般化エラーを返し、外部投稿識別子実値は出さない。
- 将来は `update` または `resync` に誘導する。
- Edge Function側の事前チェックに加え、可能ならDB/RPC側でも原子的に担保する。

Discord成功後DB更新失敗時:

- Discord投稿は既に発生しているため、同じ `create` 再実行は禁止。
- レスポンスではDiscord送信成功とDB更新失敗を分離する。
- top-level `ok` は `false` とし、Discord送信済みであることを明示する案を暫定推奨する。
- `discord_sync_error` へは一般化エラーだけを保存する案を検討する。
- repair/resync/手動照合は後続工程へ分離する。

次工程を大きめに再編:

- 設計確定バッチ: CHECK許容値、DB更新経路、二重投稿防止、失敗時レスポンス、repair/resync方針を確定。
- SQL/RPC draft作成バッチ: 専用RPC案を第一候補にdraft化。
- SQL Editor applyゲート: DB/RPC変更をユーザー手元で独立実行。
- Edge Function実装バッチ: DB更新連携と二重投稿防止を実装。
- deployゲート: Edge Function deployを独立実行。
- まとめQAバッチ: dry-run、テスト用チャンネル実送信、二重投稿拒否、DB状態確認をまとめて実施。
- 本番切替前レビューゲート。
- 本番切替ゲート。

本番募集チャンネル切り替え停止条件:

- DB更新連携未完了。
- 二重投稿防止未完了。
- `update` / `resync` 方針未整理。
- 本番Webhook/secret切り替えレビュー未完了。
- 本番初回投稿手順未レビュー。
- これらが残る間は本番募集チャンネルへ進まない。

この工程ではdocs設計のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16F/G Discord同期DB更新連携 SQL/RPC draft作成バッチ
- CHECK許容値確認用SELECT-only SQL draftとして `docs/supabase/sql/029_discord_sync_check_values_select_only.sql` を作成。
- 専用RPC案の未実行apply draftとして `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` を作成。
- 029は `discord_sync_status` / `discord_last_action` のCHECK定義、関連カラム、既存RPC signature、EXECUTE、RLS/policyを単一結果表で確認するSELECT-only preflight。
- 030は `DO NOT RUN UNTIL REVIEWED` を明記したapply draftで、029結果によりCHECK許容値を確認するまで実行しない。
- 030のRPC案は、`check_discord_session_post_create_ready(text)`、`record_discord_session_post_create_success(text,text,text,text,text)`、`record_discord_session_post_create_failure(text,text)` の3本。
- 既存 `update_session_post` にDiscord同期責務を混ぜず、専用RPCで二重投稿防止、同期状態更新、一般化エラー保存を扱う方針を維持。
- `dry_run = true` ではDB更新なし。`dry_run = false` かつDiscord送信成功後のみsuccess記録RPCを呼ぶ。
- Edge Function実装バッチでは、request validation、user auth、target session fetch、create guard、message build、Discord send、DB success update、partial failure handling、sanitized responseの順で整理する。
- Discord送信成功後にDB更新失敗した場合は、同じ `create` 再実行を禁止し、Discord送信済みとDB更新失敗を分けて返す。
- 本番募集チャンネル切替は、DB更新連携、外部投稿識別子保存、二重投稿防止、update/resync方針、本番Webhook/secret切替レビュー、本番初回投稿手順レビューが完了するまで停止。

次工程を大きめに再編:

1. CHECK確認SQL実行ゲート: 029をユーザー手元でSQL Editor実行し、CHECK許容値を記録する。
2. RPC applyレビューゲート: 029結果を踏まえ、030の状態値・関数名・戻り値・権限をレビューする。
3. RPC applyゲート: ユーザー手元でSQL Editor適用する。
4. Edge Function実装バッチ: 専用RPC呼び出し、DB更新連携、二重投稿防止、partial failure responseを実装する。
5. deployゲート: Edge Function deployを独立ゲートで扱う。
6. まとめQAバッチ: dry-run、テスト用チャンネル実送信、二重投稿拒否、DB状態確認をまとめて行う。
7. 本番切替前レビューゲート: 本番Webhook/secret切替、初回投稿手順、停止条件を確認する。
8. 本番切替ゲート: 本番募集チャンネル切替を独立ゲートで扱う。

この工程ではSQL/RPC draft作成とdocs整理のみ行い、SQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16H 029実行結果記録と030 RPC apply draftレビュー
- ユーザー手元で `docs/supabase/sql/029_discord_sync_check_values_select_only.sql` をSQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行済み。エラーなしで結果グリッドが表示された。同じSQLは再実行していない。
- `public.sessions` は存在し、core column summaryは `15/15 present`。`session_tool` も存在確認済み。
- Discord同期系カラムは `9/9 present`。確認済みカラムは `discord_message_id` / `discord_channel_id` / `discord_thread_id` / `discord_post_url` / `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error`。
- `discord_sync_status` は `text` / nullable YES / defaultあり、`discord_last_action` は `text` / nullable YES / default NULL。
- `sessions_discord_last_action_check`、`sessions_discord_sync_status_check`、`sessions_status_check`、`sessions_visibility_check` が確認できた。
- `create_session_post` / `update_session_post` / `delete_session_post` は存在し、security definer、search_path、authenticated EXECUTEあり、anon / PUBLIC不可を確認上OK。
- `sessions` / `user_roles` はRLS enabled。policy概要は取得できたが、具体的なpolicy本文や実値は記録しない。
- 重要: この時点ではCHECK制約の許容値配列が結果表示幅の都合で完全には読めていなかったため、`posted` / `failed` / `create` 等を推測で確定扱いにしなかった。M-14E-16IでCHECK値確定結果を記録済み。
- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` は未実行のapply draft。`DO NOT RUN UNTIL REVIEWED` 注記を維持し、M-14E-16IでCHECK整合確認後もRPC apply review gate完了までは実行可能扱いにしない。
- 030のRPC案は `check_discord_session_post_create_ready(text)`、`record_discord_session_post_create_success(text,text,text,text,text)`、`record_discord_session_post_create_failure(text,text)` の3本。既存 `update_session_post` に同期責務を混ぜない方針を維持。
- 030 draftには、029は成功したがCHECK許容値全体は未確認であり、正確な許容値確認まで非実行とするコメントを追加した。SQL本文の実行ロジックは変更していない。
- Edge Function実装バッチでは、request validation、user auth、target session fetch、create guard RPC、message build、Discord send、success記録RPC、failure記録RPCまたはpartial failure handling、sanitized responseの順で整理する。
- `dry_run = true` はDB更新なし。`dry_run = false` かつDiscord送信成功後のみDB更新連携を行う。
- 次工程は、RPC apply前レビューゲート、RPC applyゲート、Edge Function実装バッチ、deployゲート、まとめQAバッチ、本番切替前レビューゲート、本番切替ゲートの大きめ工程へ再編する。
- 本番募集チャンネル切替は、DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `resync` 方針、本番Webhook/secret切替レビュー、本番初回投稿手順レビューが揃うまで停止。
- この工程ではdocs/SQL draftコメント整理のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、030 SQL実行、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16I CHECK値確定結果と030 RPC apply draft整合
- ユーザー手元で追加のCHECK値展開SELECT-onlyを1回だけ実行済み。SQL Editorではエラーなしで結果グリッドが表示された。同じSELECTは再実行していない。
- `sessions_discord_last_action_check` の許容値は `close` / `create` / `delete` / `resync` / `update`。
- `sessions_discord_sync_status_check` の許容値は `failed` / `not_requested` / `pending` / `posted` / `skipped`。
- `discord_last_action` は `text` / nullable YES / default NULL。
- `discord_sync_status` は `text` / nullable NO / default `not_requested`。
- M-14E-16H時点のCHECK許容値未確定扱いは、この確認結果で更新済み。
- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` は未実行apply draftのまま。`DO NOT RUN UNTIL REVIEWED` とRPC apply review gate完了までSQL Editorへ貼らない方針を維持。
- 030の成功記録は `posted` + `create`、失敗記録は `failed` + `create` を使うため、確定済みCHECK値と整合する。
- 030内の実行ロジックに `synced` / `not_synced` などCHECK外の状態値は使わない。
- 初期/未送信状態は既存defaultの `not_requested`、処理中候補は `pending`、同期対象外候補は `skipped` と整理する。
- `check_discord_session_post_create_ready(text)` はcreate送信前guard、`record_discord_session_post_create_success(...)` はDiscord送信成功後の外部投稿識別子保存、`record_discord_session_post_create_failure(...)` は一般化エラー保存を担う候補。
- 3RPCとも `security definer` / `search_path` 固定 / authenticated EXECUTE / anon・PUBLIC不可の方針で、既存依頼書RPCの流儀に寄せる。
- 同時実行時の二重投稿リスクは残るため、将来の予約状態更新またはより強いDB側排他をTODOとして残す。
- Edge Function実装バッチでは、request validation、user auth、target session fetch、create guard RPC、message build、Discord send、success記録RPC、failure記録RPCまたはpartial failure handling、sanitized responseの順で実装する。
- `dry_run = true` はDB更新なし。`dry_run = false` かつDiscord送信成功後のみsuccess記録RPCを呼ぶ。
- 次工程はRPC apply前レビューゲートへ進める状態。ただしSQL Editor実行、DB/RPC変更、SQL apply、030実行、Edge Functionコード変更、deploy、Discord送信はまだ行わない。
- 本番募集チャンネル切替は、DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `resync` 方針、secret切替レビュー、本番初回投稿手順が揃うまで停止。

## M-14E-16J RPC apply前レビューゲート
- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` をRPC apply前レビューゲートとして静的確認した。030は未実行apply draftのままで、SQL Editorへは貼っていない。
- 冒頭の `DO NOT RUN UNTIL REVIEWED` 注記と、ユーザー明示確認なしにSQL applyしない方針を維持。
- 030で作成/変更候補のRPCは `check_discord_session_post_create_ready(text)`、`record_discord_session_post_create_success(text,text,text,text,text)`、`record_discord_session_post_create_failure(text,text)`。
- CHECK整合: success記録は `posted` + `create`、failure記録は `failed` + `create`。いずれも確定済みCHECK値の範囲内。CHECK外の状態/action値は030実行ロジックに残っていない。
- create送信前guardは既存 `discord_message_id` を検出してDiscord送信前に拒否する。success記録RPCも既存 `discord_message_id` がある場合は拒否し、条件更新で二重記録を防ぐ。
- failure記録RPCは、既存外部投稿識別子がある行を `failed` に上書きしないよう030 draft上で補強した。
- 3RPCとも `security definer` / `search_path` 固定 / authenticated EXECUTE / anon・PUBLIC不可の方針で、既存依頼書RPCの流儀と大きくズレない。
- 同時実行時、複数リクエストが送信前guardを通過してDiscord送信が二重化するリスクは理論上残る。将来の予約状態更新、より強いDB側排他、またはEdge Function側の単発運用をTODOとして残す。
- Discord送信成功後にDB更新失敗した場合は、`discord_send` 成功と `db_update` 失敗を分離し、同じcreate再実行を禁止する。manual repair/resyncは後続工程。
- apply後確認計画は、3RPC存在、signature、security_definer、search_path、EXECUTE権限、既存create/update/delete RPC影響なし、Discord同期系カラム維持、RLS enabled、`updates.json` 差分なしをSELECT-onlyで確認する。
- SQL applyゲート停止条件は、030内容不一致、レビュー結果と異なる変更、CHECK外値、secret/URL/ID実値混入、貼り付け欠落、SQL Editorエラー、Supabase側の予期しない警告/挙動。
- 030は次のSQL applyゲートへ進める候補。ただしSQL Editor実行、DB/RPC変更、SQL applyは独立ゲートであり、この工程では実施しない。

## M-14E-16K SQL apply結果記録とEdge Function DB更新連携実装
- ユーザー手元のSQL applyゲートで `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` をSQL Editor実行済み。
- SQL Editor画面上、`check_discord_session_post_create_ready(text)`、`record_discord_session_post_create_failure(text,text)`、`record_discord_session_post_create_success(text,text,text,text,text)` の作成を確認。
- 確認画面では `security_definer = true`、`has_search_path = true` を確認。
- エラー表示なし。030は再実行していない。
- EXECUTE権限の詳細行は確認画面に表示された範囲では未確認として扱い、後続の `dry_run = true` QAまたはSELECT-only確認で実動確認する。
- `supabase/functions/sync-session-post-to-discord/index.ts` にDB更新連携を実装した。
- `dry_run = true` はpreview専用を維持し、guard RPC、記録RPC、DB更新、Discord送信を行わない。
- `dry_run = false` + `action = create` では、Discord送信前に `check_discord_session_post_create_ready` を呼び、既存外部投稿識別子があれば送信前に拒否する。
- Discord送信成功後に `record_discord_session_post_create_success` を呼び、DBへ外部投稿識別子相当と同期状態を記録する。
- Discord送信失敗時は、可能な範囲で `record_discord_session_post_create_failure` を呼び、一般化エラーだけを保存する。
- Discord送信成功後にDB記録が失敗した場合はpartial failureとして返し、同じcreate再実行禁止を一般化warningとして返す。
- `dry_run = false` レスポンスではmessage preview本文全文、Discord message id実値、post URL全文、Webhook URL、確認対象ID実値を返さない。
- 同時実行でDiscord送信自体が二重化する理論上のリスクは残るため、予約状態更新、より強いDB側排他、単発運用を後続TODOとして維持。
- この工程ではSQL Editor再実行、DB/RPC追加変更、SQL apply再実行、Edge Function deploy、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16L DB更新連携版deploy結果とpost-deploy dry_run=true確認
- DB更新連携入りの `sync-session-post-to-discord` はユーザー手元でdeploy済み。
- deployは終了コード0で成功扱い。WARNING表示はあったが認証問題ではない。
- deploy前後で `deno.lock` / `supabase/.temp` は生成物として掃除済み。deploy後の作業ツリーはclean。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は成功済み。
- deploy後、ユーザー手元で `create` / `dry_run = true` を再確認した。
- JWT、確認対象、Supabase接続先はユーザー手元だけで扱い、実値はdocsへ記録しない。
- 対象は `M14E15P_discord_format_QA_01`。
- dry-run結果はHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- レスポンスキーは `ok,dry_run,action,sync_target,message_preview,planned_db_update,warnings`。
- `message_preview` あり。ただし本文全文は記録しない。
- `planned_db_update` と `warnings` あり。ただしdry-run上の予定情報であり、DB更新実行ではない。
- previewは冒頭区切り線あり、開催場所ラベルあり、対象タイトルあり、詳細URLなし、詳細ラベルなし、ISO/UTC表記なし。
- Discordテスト用チャンネルへの新規投稿増加なし。
- `dry_run = true` はpreview専用を維持し、Discord投稿、DB更新、guard RPC、記録RPCへ進んでいないと判断する。
- `dry_run = false` はまだ未実行。
- 次の危険工程はDB更新連携込みの `dry_run = false` 実送信QA。
- 次回の実送信QAでは、既に投稿済みの `M14E15P_discord_format_QA_01` を再利用せず、新しい検証用依頼書を使う。
- 二重投稿防止の実動確認はDiscord送信を伴う可能性があるため、独立ゲートとして扱う。

次のまとめQAバッチ:

1. 新しい検証用依頼書を作成する。
2. deploy後 `dry_run = true` previewを確認する。
3. 独立ゲートで `dry_run = false` 実送信を1回だけ確認する。
4. DB同期状態保存を確認する。ただし実値IDは記録しない。
5. 同じ対象でcreate再実行が送信前に拒否されるか確認する。ただし別ゲート化する。
6. Discord投稿増加数が想定どおりか確認する。

停止条件:

- JWT、確認対象、Supabase接続先の準備不備。
- `dry_run = true` 不通過。
- previewへのURL、詳細リンク、ISO/UTC表記混入。
- 対象依頼書の誤り。
- 既に投稿済み対象を実送信用に使っている疑い。
- DB同期状態確認で実値IDを出す必要がありそうな場合。
- Discord投稿先がテスト用チャンネルであると確認できない。
- 本番募集チャンネル投稿の疑い。
- 不明なエラー。

この工程ではdocs記録と静的確認のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 実送信、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16M 表示・導線・Discord本文追加改善
- DB同期込み実送信QAへ進む前に、Discord本文、依頼書保存後導線、session-detail概要表示を改善した。
- Discord投稿本文では、概要本文直前の `概要` ラベル行を削除した。概要本文そのものは維持し、ユーザー入力本文が参加締切行の下に続く。
- Discord本文には詳細URL、詳細リンク、ISO/UTC表記を追加しない。
- Edge Function本文生成を変更したため、反映には別ゲートでEdge Function deployが必要。
- 依頼書作成成功後、公開かつ非draftで保存された場合は対象依頼書の `session-detail.html?id=...` へ遷移する。
- 依頼書編集成功後も、公開かつ非draftで保存された場合は対象依頼書の詳細画面へ遷移する。
- 非公開保存、下書き保存、遷移先IDを安全に解決できない場合は既存挙動を維持する。
- session-detail / calendar modalの概要表示では見出し `概要` を削除し、本文だけを表示する。
- 概要本文はHTMLとして解釈せず、escape済み表示を維持する。
- CSSで概要本文に `white-space: pre-wrap` を指定し、改行と空行を保持する。
- フロント側はcommit/push後、GitHub Pages反映待ちで手動QAする。
- QA項目は、公開作成後の詳細遷移、公開編集後の詳細遷移、非公開/下書き保存の既存挙動、概要改行保持、概要見出し非表示、raw id/user_id/email/token等の露出なし。
- Edge Function deployは別ゲート。
- deploy後 `dry_run = true` previewで `概要` ラベル削除、URL/詳細リンクなし、ISO/UTC表記なしを確認する。
- DB同期込み `dry_run = false` 実送信QA、Discord追加投稿、二重投稿防止実動確認、本番投稿、secret切替はさらに別ゲート。
- この工程ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Function deploy、追加deploy、`dry_run = false` 実送信、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16N DB同期込み実送信QA結果
- DB更新連携入り `sync-session-post-to-discord` deploy後、新しい検証用依頼書 `M14E16_sync_db_QA_01` に対して `create` / `dry_run = false` を1回だけ実施済み。同じコマンドの再実行は禁止。
- 実送信結果はHTTP 200、JSON parse成功、`ok = true`、`dry_run = false`、`action = create`。`discord_send`、`db_update`、`warnings` が返り、`db_update.success = true` 相当を確認した。
- `message_preview` は返っていない。message preview本文全文、Discord message id実値、post URL全文、Webhook URL、JWT、対象session id実値、Supabase URL全文は記録しない。
- Discordテスト用チャンネルには新規投稿が1件増えた。対象タイトル相当、冒頭区切り線、開催場所、概要本文改行を確認し、`概要` ラベル、詳細URL/詳細リンク、ISO/UTC表記はない。本番募集チャンネル投稿なし。
- DB同期状態SELECT確認では、外部投稿識別子相当と投稿先識別子相当の保存、`discord_sync_status = posted`、`discord_last_action = create`、同期成功時刻あり、同期エラー空を確認した。
- `discord_post_url` 相当は未保存。現時点では非致命とし、管理UIの投稿リンク導線やrepair/resync補助情報として後続課題に残す。
- 次工程は二重投稿防止確認ゲート。投稿済みの `M14E16_sync_db_QA_01` を対象に、`action = create` 再実行が送信前guardで拒否され、Discord投稿が増えないことを確認する。ただし `dry_run = false` を伴う可能性があるため独立ゲートで扱う。
- 二重投稿防止ゲート停止条件は、対象不一致、外部投稿識別子保存済み未確認、JWT/対象依頼書/Supabase接続先不備、テスト用チャンネル未確認、本番投稿疑い、不明エラー、確認コマンドと送信コマンド未分離、同一コマンド再実行。
- 後続課題は `discord_post_url` 保存補強、二重投稿防止の実動確認、`update` / `close` / `delete` / `resync` 方針整理、管理UI同期状態表示、本番切替前レビュー、本番募集チャンネル切替ゲート。
- この記録作業ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16O 二重投稿防止確認ゲート結果
- DB同期込み実送信済みの `M14E16_sync_db_QA_01` に対して、ユーザー手元で `create` / `dry_run = false` を1回だけ実施し、送信前guardの拒否を確認した。同じ確認コマンドは再実行禁止。
- 結果はHTTP 409、JSON parse成功、`ok = false`、`dry_run = false`、`action = create`。`message_preview` は返っていない。
- Discordテスト用チャンネルに新規投稿増加なし。本番募集チャンネル投稿なし。
- `discord_send` / `db_update` はレスポンスキーとして存在したが、HTTP 409 / `ok = false` のため、実送信成功やDB更新成功を示すものとして扱わない。判定は送信前拒否、`message_preview` なし、Discord投稿増加なしを重視する。
- 二重投稿防止の基本動作は確認済みとして扱う。
- 後続課題は `discord_post_url` 保存補強、`update` / `close` / `delete` / `resync` 方針整理、GM/admin同期状態表示UI、失敗時repair/resync導線、本番切替前レビュー、本番初回投稿手順、本番募集チャンネルsecret切替ゲート。
- 本番募集チャンネル切替はまだ行わない。
- この記録作業ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16P discord_post_url補強と後続ゲート整理
- `discord_post_url` 相当が未保存だった原因をEdge Functionコードで確認した。success記録RPCへpost URL相当を渡す設計はあったが、送信結果の `postUrl` が常に `null` だった。
- 低リスク修正として、Webhook `wait = true` レスポンスからmessage id相当、channel id相当、guild/server id相当を取り出し、3値がsnowflake相当に見える場合だけDB保存用の投稿URL相当を組み立てるようにした。
- guild/server id相当が得られない場合や形式が想定外の場合は、`discord_post_url` は従来どおり未保存にする。無理に不正確なURLは保存しない。
- 生成した投稿URL相当はsuccess記録RPCへ渡すだけで、レスポンス、docs、consoleへURL全文やID実値を出さない。
- `dry_run = true`、Discord本文フォーマット、DB/RPC定義には影響させていない。
- update/resync/repair方針として、`update` は既存投稿編集、`resync` はGM/admin向け再同期、`repair` は部分失敗の補正導線、`close` は募集終了反映、`delete` は削除または削除済み扱いとして後続設計に残す。
- GM/admin同期状態表示UIの最小仕様は、session-detail管理ブロック内に未同期、投稿済み、同期失敗、確認が必要を一般化表示する案。生のmessage id、channel id、post URL全文は表示しない。resync/repairボタンは後続。
- 本番切替前チェックリストは、テスト用チャンネルcreate成功、DB更新成功、二重投稿防止成功、post URL未保存の扱い了承または補強QA済み、update/resync/repair方針docs化、GM/admin同期状態表示方針、本番secret切替手順、本番初回投稿手順、本番前 `dry_run = true` 確認。
- 次工程候補は、Edge Function deployゲート、deploy後 `dry_run = true` 確認、テスト用チャンネルでのpost URL保存補強QA、またはGM/admin同期状態表示UI設計。
- 本番募集チャンネル切替はまだ行わない。
- この工程ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Function deploy、追加deploy、`dry_run = false` 実送信、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16Q post URL補強deploy結果とdry_run=true確認
- `9420c53` の `sync-session-post-to-discord` はユーザー手元でdeploy済み。
- deploy前のgit状態はclean、deploy前 `deno check` は成功、deployは終了コード0で成功扱い。WARNING表示はあったが認証問題ではない。
- deploy後のgit状態はclean。`deno.lock` / `supabase/.temp` は生成物として掃除済み。
- deploy後、`M14E16_sync_db_QA_01` を対象に `create` / `dry_run = true` を確認済み。
- dry-runはHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- response keysは `ok,dry_run,action,sync_target,message_preview,planned_db_update,warnings`。
- previewでは `概要` ラベルなし、詳細URLなし、対象タイトルあり、ISO/UTC表記なし。
- Discordテスト用チャンネルに新規投稿増加なし。`dry_run = false` は未実行。
- 次工程はpost URL保存補強QAゲート。新しい検証用依頼書 `M14E16_post_url_QA_01` を使い、既存投稿済みの `M14E16_sync_db_QA_01` は再利用しない。
- post URL保存補強QAでは、作成、session-detail確認、`dry_run = true`、独立ゲートでの `dry_run = false` 1回、Discord投稿1件確認、SELECT-only DB確認で `discord_post_url` 相当の保存有無を見る。
- 停止条件は、対象不一致、認証/対象/Supabase接続先不備、dry-run失敗、詳細URL/ISO/UTC/`概要` ラベル混入、テスト用チャンネル未確認、本番投稿疑い、実値IDやURL全文の記録が必要になりそうな場合、不明エラー、同一実送信コマンド再実行。
- 後続課題は、post URL保存補強QA、`update` / `close` / `delete` / `resync` / `repair` 実装、GM/admin同期状態表示UI、本番切替前レビュー、本番secret切替ゲート、本番初回投稿ゲート。
- この工程ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16R post URL保存補強QA結果
- `M14E16_post_url_QA_01` を使ったpost URL保存補強QAをユーザー手元で実施済み。
- `dry_run = true` preview確認は成功済み。
- `dry_run = false` 実送信は1回のみ実行済み。同じコマンドは再実行禁止。
- Discordテスト用チャンネルに新規投稿1件を確認。本番募集チャンネル投稿なし。
- 投稿は対象タイトル相当、`概要` ラベルなし、概要本文改行保持、詳細URLなし、ISO/UTC表記なし。
- SELECT-onlyのDB同期状態確認では、対象あり、外部投稿識別子相当保存あり、投稿先チャンネル識別子相当保存あり、`discord_sync_status = posted`、`discord_last_action = create`、同期時刻あり、同期エラー空を確認した。
- thread id相当は未使用または空。`discord_post_url` 相当は未保存。
- `discord_post_url` 未保存は非致命の後続課題として扱う。原因候補は、Webhookレスポンスからguild/server id相当を取得できず、正確な投稿URLを組み立てられなかったこと。
- 偽URLや不完全URLを保存しない現在の挙動は安全側。
- 最小本番create投入では、message id相当、channel id相当、sync status、last action、synced atが保存されているため、post URL未保存をブロッカーにしない案を第一候補にする。
- 本番create投稿に向けた到達済み項目は、テスト用チャンネル新フォーマットcreate成功、`概要` ラベル削除、概要改行保持、詳細URL/ISO/UTCなし、DB同期状態保存、外部投稿識別子保存、二重投稿防止guard、本番投稿なし。
- 優先度高の残課題は、本番切替前レビュー、本番Webhook secret切替ゲート、本番向け `dry_run = true`、本番初回投稿ゲート、post URL未保存許容またはguild id設定補強判断。
- 優先度中の残課題は、GM/admin同期状態表示UI、update/resync/repair方針詳細化、投稿済み依頼書resync導線、失敗時一般化エラー表示、本番投稿後DB確認手順。
- 優先度低の残課題は、post URLリンク表示、close/delete/update実装、同期履歴表示、詳細監査ログ。
- この工程ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16S GM/admin Discord同期状態パネル
- session-detailのGM/admin管理ブロック内に、Discord同期状態の最小パネルを追加した。
- UIは `details` / `summary` による折りたたみ式。通常は1行サマリーとして `Discord同期：投稿済み` などを表示し、展開時に詳細を表示する。
- 表示項目は、同期状態、最終操作、最終同期日時、同期エラー有無、投稿リンク保存有無。
- `discord_sync_status` と `discord_last_action` は安全な日本語ラベルへ変換する。
- `discord_sync_error` は生テキストを表示せず、エラーあり/なしの一般化表示にする。
- `discord_post_url` はURL全文リンクにせず、保存あり/保存なしだけを表示する。
- Discord message id、channel id、thread id、post URL全文、raw session id、raw user id、email、token、selected character id、application idは画面やDOMへ出さない。
- 管理権限確認前は非表示。GM本人またはadminとして権限確認できた場合だけ表示する。静的JSON由来、未ログイン、権限なし、権限確認失敗では表示しない。
- post URL全文リンク表示、resync/repair/update/close/deleteボタン、同期履歴表示は後続課題。
- 本番切替前レビューの前に、画面上で投稿済み/同期失敗などの状態をGM/adminが確認できる足場ができた。
- 次工程候補は、GitHub Pages反映後のGM/admin表示QA、本番切替前レビュー、または本番secret切替ゲート準備。
- この工程ではSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、Edge Function deploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16T 本番切替前レビュー準備
- 最新commit `a41abd5 Add Discord sync status panel` の公開サイト反映後、GM/admin向けDiscord同期状態UIの軽量QAを記録した。
- 折りたたみ式 `Discord同期` パネルはGM/admin管理ブロック内に表示され、GM本人またはadmin確認後だけ表示される。
- summaryは `Discord同期：投稿済み` 相当。詳細では投稿済み、新規投稿、最終同期日時、同期エラーなし、投稿リンク保存なしを確認する。
- Discord message id、channel id、thread id、post URL全文、raw session id、raw user id、email、token、selected character id、application idは表示されない。
- post URL未保存は、本番create最小投入のブロッカーにしない案を第一候補にする。message id相当、channel id相当、`posted` / `create`、同期時刻、同期エラー空、二重投稿防止が確認済みで、偽URLや不完全URLを保存しない挙動が安全側であるため。
- 本番Webhook secret切替ゲートは独立ゲート。secret実値はチャット、docs、GitHub、consoleへ出さず、設定後も本番投稿は行わない。
- 本番向け `dry_run = true` 確認ゲートは独立ゲート。本番Webhook設定後に行い、Discord投稿が増えないこと、message preview本文全文を貼らないことを守る。
- 本番初回投稿ゲートは独立ゲート。本番向け `dry_run = true` 確認済みの依頼書だけを対象にし、確認コマンドと送信コマンドを分離し、`dry_run = false` は1回だけ行う。
- 本番初回投稿後は、SELECT-onlyでDB同期状態を確認し、GM/admin同期状態UIで投稿済み表示を確認する。
- 停止条件は、git dirty、最新commit不一致、GM/admin同期状態UI未反映、テスト用create/DB同期/二重投稿防止記録未確認、本番Webhook secret未準備、本番投稿対象未確定、本番向け `dry_run = true` 未確認、本番募集チャンネル未目視確認、post URL未保存を許容しない判断、不明エラー。
- 今回はSQL Editor実行、DB/RPC変更、SQL apply、Edge Function変更、Edge Function deploy、`dry_run = true` 実行、`dry_run = false` 実送信、Discord本番投稿、secret設定/切替、Discord追加投稿、`updates.json` 変更は行わない。

## M-14E-16U 本番Webhook secret切替結果
- ユーザー手元でSupabase Dashboardから `DISCORD_SESSION_POST_WEBHOOK_URL` を本番募集チャンネル向けWebhookへ切替済み。
- Webhook URL実値はチャット、docs、GitHub、consoleへ記録していない。
- Codex側ではsecret実値を扱っていない。
- `dry_run = true` は未実行。
- `dry_run = false` は未実行。
- Discord本番投稿なし。
- Edge Function deployなし。
- SQL Editor実行なし。
- DB/RPC変更なし。
- git状態はcleanのまま。
- 次工程は本番向け `dry_run = true` 確認ゲート。
- この工程ではWebhook URL実値の確認・表示・再入力、secret設定/切替の再実行、Discord投稿、`updates.json` 変更は行わない。

## M-14E-16V 本番初回Discord投稿結果
- 指定タイトル `【連携確認】依頼書投稿テスト` を対象に、本番初回投稿まとめゲートを実施した。
- 開始commitは `f2bd4d0 Record production Discord webhook switch`、開始時git状態はclean。
- 指定タイトルの既存対象が0件だったため、既存アプリ用RPC経由で公開/非draftの依頼書を1件作成した。SQL Editor、直接insert、DBスキーマ変更、RPC定義変更は行っていない。
- 初回作成時に `open` は初期statusとして拒否されたため、DB変更なしで停止し、既存仕様に合わせて `recruiting` で作成した。
- 作成後、指定タイトルの対象が1件だけであることを確認した。対象ID実値は記録していない。
- `create / dry_run = true` を1回だけ実行し、HTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`、`message_preview` あり、`planned_db_update` あり、warning count 0を確認した。message preview本文全文は記録していない。
- `dry_run = true` ではDiscord投稿なし、DB同期識別子保存なし、DB同期更新なし。
- ユーザーが本番依頼書チャンネルに投稿増加なしを目視確認し、`dry_run = false` 1回実行を明示許可した。
- `create / dry_run = false` はユーザー許可後に1回だけ実行した。同じコマンドは再実行禁止。
- 実送信結果はHTTP 200、JSON parse成功、`ok = true`、`dry_run = false`、`action = create`、response keys `ok,dry_run,action,sync_target,discord_send,db_update,warnings`、`db_update.success = true`、warning count 0、`message_preview` なし。
- Discord message id、channel id、post URL全文、JWT、対象session id、Supabase URL全文、Webhook URL、message preview本文全文は記録していない。
- 読み取り専用のDB同期状態確認で、`discord_message_id_saved = true`、`discord_channel_id_saved = true`、`discord_sync_status = posted`、`discord_last_action = create`、`discord_synced_at_present = true`、`discord_sync_error_empty = true` を確認した。
- `discord_post_url_saved = false` は既知の非致命制約として扱う。post URL補強やリンク表示は後続課題。
- ユーザー目視確認項目として、本番依頼書チャンネルに1件だけ投稿されたこと、タイトル一致、`概要` ラベルなし、概要本文改行保持、詳細URL/詳細リンクなし、ISO/UTC表記なしを確認する。
- 次工程候補は、本番投稿の目視確認結果追記、GM/admin同期状態UIで投稿済み表示確認、`update` / `resync` / `repair` 方針と実装。
- この工程ではsecret設定/切替、Webhook URL実値確認、Edge Function deploy、SQL Editor実行、DB/RPC定義変更、`dry_run = false` の複数回実行、Discord追加投稿、`updates.json` 変更は行わない。

## M-14E-17 Discord同期 update/delete/close/resync 大型実装準備
- 本番初回create投稿成功を最終到達状態として整理し、update/delete/close/resync/repairへ広げる準備を行った。
- 開始commitは `801c561 Record first production Discord post`、開始時git状態はclean。
- 本番create投稿は1回だけ成功済みで、DB同期状態は外部投稿識別子保存あり、投稿先チャンネル識別子保存あり、`discord_sync_status = posted`、`discord_last_action = create`、同期時刻あり、同期エラー空。
- `discord_post_url_saved = false` は既知の非致命制約。update/deleteのブロッカーにせず、message id相当とWebhook secretで既存投稿を扱う方針。
- 本番依頼書チャンネルの目視確認項目は、投稿1件、タイトル一致、`概要` ラベルなし、概要改行保持、詳細URLなし、ISO/UTCなし。未確認が残る場合は目視確認待ちとして扱う。
- update MVPは、外部投稿識別子が保存済みの依頼書を対象に既存Discord投稿本文を更新する。成功時は `posted/update/synced_at/error clear`、失敗時は依頼書保存を巻き戻さず一般化エラーを保存する。
- delete MVPは、Discord投稿削除を先に行い、その後に既存 `delete_session_post` RPCでDB削除する案を第一候補にした。Discord削除失敗時はDB削除へ進まない。
- delete成功後はsessions行が消えるため、現行MVPでは同じ行へのsuccess永続保存はできない。永続監査ログは後続課題。
- closeは募集終了/締切/開催終了をDiscord本文へ反映するupdate扱い。resyncは外部投稿識別子ありならupdate相当、なしなら手動確認必須。repairはpartial failure修復の後続導線。
- 未実行SQL draft `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` を追加した。冒頭にDO NOT RUN、未実行、SQL Editor貼付禁止を明記。
- 031 draftの候補RPCは、`check_discord_session_post_update_ready(text)`、`record_discord_session_post_update_success(text)`、`record_discord_session_post_update_failure(text, text)`、`check_discord_session_post_delete_ready(text)`、`record_discord_session_post_delete_failure(text, text)`。
- CHECK値は `discord_last_action = close / create / delete / resync / update`、`discord_sync_status = failed / not_requested / pending / posted / skipped` に整合。
- Edge Function `sync-session-post-to-discord` に `action = update` / `action = delete` のreal-send準備経路を追加した。ただしdeployは行っていない。
- `dry_run = true` はpreview専用を維持し、Discord送信/編集/削除、DB更新、RPC記録を行わない。
- update real-sendは guard RPC -> Discord PATCH -> success/failure RPC。delete real-sendは guard RPC -> Discord DELETE -> existing `delete_session_post` RPC。
- responseやconsoleへDiscord message id実値、channel id実値、post URL全文、Webhook URL、Discord API raw bodyを出さない方針を維持。
- DB直書き込み `.insert()` / `.update()` / `.delete()` / `.upsert()` は追加せず、DB操作はRPC経由にした。
- 031 SQL/RPC apply前にEdge Functionをdeployしない。deploy前にRPC applyレビュー、SQL applyゲート、post-apply確認が必須。
- フロント自動同期はまだ有効化しない。backend update/delete対応deploy後に、編集保存後update、削除時delete orchestrationを検討する。
- 次工程候補は、031 RPC apply前レビューゲート、031 RPC applyゲート、Edge Function deploy前レビューゲート、deployゲート、update/delete dry-run QA、update/delete real-send QA、フロント自動同期導線実装。
- この工程ではSQL Editor実行、SQL apply、DB/RPC実変更、Edge Function deploy、`dry_run = true` 実行、`dry_run = false` 実行、Discord投稿/編集/削除、secret設定/切替、Webhook URL実値確認、`updates.json` 変更は行わない。
## M-14E-17 SQL applyゲート Codex側実行経路確認
- 最新commit `9cf71a4 Prepare Discord update delete sync`、git cleanの状態から、`docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` のSQL applyゲートを確認した。
- 対象SQLには `DO NOT RUN`、`NOT EXECUTED`、`DO NOT PASTE` の誤爆防止注記が残っていることを確認した。
- 対象SQLはupdate/delete用RPC追加draftで、既存create用RPCを破壊しない方針。CHECK値 `update` / `delete` / `posted` / `failed` と整合する。
- secret、Webhook URL、JWT、DB password、Direct connection string、実ID、URL全文らしき値は検出されなかった。
- `DROP TABLE`、`DROP COLUMN`、`TRUNCATE`、`CASCADE` の実行文は検出されなかった。
- Supabase CLIの `db query --linked --file` は存在するが、このrepoには `supabase/.temp` や `supabase/config.toml` がなく、linked projectを秘匿値なしで確定できなかった。
- 関連環境変数名にも安全に対象DBを特定できるものは見つからなかった。
- 既存の安全なDB apply用スクリプトは見つからなかった。
- Chrome連携は対象プロファイルにCodex Chrome Extensionがなく、Codex側からSQL Editorを操作できなかった。
- 安全なSQL apply経路が確定しないため、停止条件に従ってSQL applyは未実行で停止した。
- 031 SQLのSQL Editor貼付、CLI apply、psql実行はいずれも行っていない。
- apply後SELECT-only確認はapply未実行のため未実施。
- Edge Function deploy、`dry_run = true`、`dry_run = false`、Discord投稿/編集/削除、secret設定/切替、`updates.json` 変更は行っていない。
- 次工程候補は、安全な031 apply経路の確定、031 SQL apply 1回実行、apply後SELECT-only確認、Edge Function deployゲート。

## M-14E-17 SQL apply成功結果記録
- ユーザー手元で `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` をSQL Editorへ貼り付け、1回だけ実行した。
- SQL Editor上でエラー表示はなかった。
- 同じSQLは再実行していない。
- 結果グリッドで以下5本のRPCを確認した。
  - `check_discord_session_post_delete_ready(text)`
  - `check_discord_session_post_update_ready(text)`
  - `record_discord_session_post_delete_failure(text, text)`
  - `record_discord_session_post_update_failure(text, text)`
  - `record_discord_session_post_update_success(text)`
- 表示されている範囲では、5本とも `security_definer = true`、`has_search_path = true`。
- EXECUTE権限の詳細列はユーザー提供画像上では未確認。
- RPC本体、`security_definer`、`search_path` は確認済み。EXECUTE権限の詳細はEdge Function deploy後QAで実呼び出しにより確認する。
- 既存create用RPCは維持されている前提で、update/delete同期用RPCのDB側準備が進んだと扱う。
- Codex側ではSQL Editor再実行、SQL apply再実行、DB/RPC追加変更を行っていない。
- Edge Function deploy、`dry_run = true`、`dry_run = false`、Discord投稿/編集/削除、secret設定/切替、`updates.json` 変更は行っていない。
- 次工程はEdge Function deployゲート。deploy後QAではupdate/delete用RPCの実呼び出し可否、EXECUTE権限、既存create同期への影響なしを確認する。

## M-14E-17 Edge Function deployゲート
- 最新commit `36cca94 Record Discord update delete RPC apply success`、git cleanの状態から、`sync-session-post-to-discord` をdeployした。
- 事前の `deno check supabase/functions/sync-session-post-to-discord/index.ts` は成功。
- 通常PATHの `deno` が見つからないため、既存のローカルDeno実行ファイルを使用した。
- deploy用project refはクリップボードからPowerShell環境変数へ読み込み、値そのものはdocs、GitHub、チャット、consoleへ記録していない。
- `npx.cmd supabase functions deploy sync-session-post-to-discord --project-ref <PROJECT_REF>` を1回だけ実行した。
- Edge Function deployは成功した。
- Docker未起動WARNINGは出たが、deploy自体は成功扱い。
- `deno.lock` と `supabase/.temp` は生成物として削除済みで、commit対象外。
- DB側update/delete RPC 5本はSQL Editorで適用済み。
- `dry_run = true` / `dry_run = false` は未実行。
- Discord投稿、編集、削除は未実行。
- SQL Editor再実行、SQL apply再実行、DB/RPC追加変更、secret設定/切替、`updates.json` 変更は行っていない。
- 次工程はupdate/delete本番QAまとめゲート。deploy後QAでRPC実呼び出し可否、EXECUTE権限、既存create同期への影響なしを確認する。
## M-14E-17 Discord同期ライフサイクルQAまとめゲート

ステータス: 完了

実施内容:

- 最新commit `c3e95c8 Deploy Discord update delete sync` のdeploy済みEdge Functionで、使い捨てQA依頼書を新規作成した。
- QA対象は `M14E17_lifecycle_QA` prefix の新規依頼書。session id実値は記録していない。
- `create / dry_run = true`、`create / dry_run = false` 1回、編集、`update / dry_run = true`、`update / dry_run = false` 1回、`delete / dry_run = true`、`delete / dry_run = false` 1回を実施した。
- create後は `posted/create`、update後は `posted/update`、いずれも外部投稿識別子相当保存あり、channel識別子相当保存あり、synced atあり、sync error空を確認した。
- delete後は対象DB行0件を確認し、QA依頼書の削除まで完了した。
- `discord_post_url` は保存なしのままだが、既知の非致命制約として扱う。
- update/delete用RPCの実呼び出しはEdge Function経由で成功し、EXECUTE権限の実動確認として扱える。

安全境界:

- `dry_run = false` はcreate / update / deleteそれぞれ1回のみ。失敗時再実行はしていない。
- Edge Function deploy、SQL Editor実行、SQL apply、DB/RPC定義変更、secret設定/切替は行っていない。
- JWT、session id、project ref、Supabase URL全文、Webhook URL、Discord message id、channel id、thread id、post URL全文、message preview本文全文、raw user id、email、token、selected character id、application id は記録していない。

次工程候補:

- GM/admin向け手動同期UI導線の設計・実装。
- close / resync / repair の方針整理と実装ゲート。
- 残存QA依頼書がある場合のadmin cleanup候補整理。
- post URL保存補強またはリンク表示方針の再レビュー。
## M-14E-18 Discord auto-sync frontend flow

Status: implementation batch completed.

- Added a shared frontend Discord sync helper for create/update/delete.
- Public, non-draft create saves now attempt Discord create sync after the app save succeeds.
- Public, non-draft edits now attempt Discord update sync only when the session already has a Discord post reference.
- Posted deletes now attempt Discord delete sync before DB deletion. If Discord delete sync fails, the DB delete is stopped.
- Draft/private saves and unposted edits do not trigger hidden create sync.
- No Edge Function deploy, SQL Editor execution, DB/RPC change, secret setting/switching, dry-run execution, real send, Discord edit/delete, or production Discord operation was performed in this implementation batch.
- Next batch: wait for public site reflection and run a frontend manual QA gate for create/update/delete auto-sync behavior. Existing leftover QA session posts can remain as admin cleanup candidates unless they block QA.
## M-14E-18B Discord auto-sync browser QA preparation

Status: public reflection confirmed, browser automation blocked.

- Public `session-post.html` / `session-detail.html` delivery now references the auto-sync cache-bust version.
- Delivered session post/detail JS references `discordSyncClient.js`, and the delivered helper includes create/update/delete auto-sync paths.
- Codex could not connect to the Chrome extension backend, so it did not perform public-site UI create/update/delete QA.
- No QA session was created, no Discord post/edit/delete was performed, no DB/RPC change or SQL Editor execution occurred, and no secret setting/switching occurred.
- Manual QA checklist is now documented in the sync/IO docs.

Next:

- User-run public-site browser QA for one disposable session post: create auto-sync, update auto-sync, delete auto-sync, GM/admin panel display, and no sensitive/raw ID exposure.
- Record the manual QA result in docs after completion.
- Treat any leftover QA session posts as admin cleanup candidates only if they remain after QA.
## M-14E-18C Discord auto-sync manual QA result

Status: manual browser QA completed.

- User performed public-site browser QA with disposable session post `【連携確認】自動同期ブラウザQA`.
- Public, non-draft create produced one Discord post in the production request channel.
- GM/admin Discord sync panel was visible and not broken after create, showing posted/create-equivalent state.
- Editing the QA post to `【連携確認】自動同期ブラウザQA・編集確認済み` updated the existing Discord post.
- No extra Discord post was created during update.
- Deleting the QA post also deleted the Discord QA post.
- After deletion, the QA post is not normally visible on the public site.
- Sensitive values and raw identifiers were not recorded.

Next:

- Move to post-QA production readiness cleanup and remaining scope review.
- Keep close / resync / repair, post URL handling, and any admin cleanup candidates as follow-up work.

## M-14E-18D Prelaunch session cleanup planning

Status: cleanup investigation/design completed. No destructive cleanup was run.

What was reviewed:

- Session detail delete button and GM/admin permission path.
- Supabase vs static JSON source split.
- Frontend Discord delete sync path.
- Existing DB-only delete fallback for unposted Supabase rows.
- Edge Function delete behavior for posted rows.
- Static `data/sessions.json` fallback behavior.

Findings:

- Production-webhook Supabase posts should continue to use current auto-delete sync.
- Unposted Supabase posts should continue to use the existing `delete_session_post` path.
- Static JSON rows are not DB rows and cannot be deleted through DB/RPC cleanup.
- Older test-webhook Discord posts may not be deletable by the current production webhook; these are likely manual Discord cleanup or repair/resync candidates.
- Discord-only remnants without DB rows cannot be safely targeted by the app.

Code changes:

- None in this batch. Current create/update/delete auto-sync paths remain unchanged.

Prelaunch cleanup backlog:

- Build a source/status cleanup inventory that does not expose raw ids, Discord ids, URLs, JWTs, user ids, emails, or tokens.
- Decide whether to retire or shrink `data/sessions.json` before operations.
- Separate cleanup candidates into production auto-delete, DB-only delete, static JSON retirement, old test-channel manual cleanup, and Discord-only manual cleanup.
- Run actual deletion only as a separate explicit cleanup gate.
- Recheck calendar, session-detail, mypage/session-post management list, and GM/admin Discord sync panel after cleanup.

Stop conditions for cleanup:

- Source category is unclear.
- Old test-webhook vs production-webhook ownership is unclear.
- Static fixture retirement has not been decided.
- Cleanup would require SQL Editor, DB/RPC change, Edge Function deploy, secret inspection, or raw external ids.
- Non-QA production content might be affected.

Next:

- Prelaunch cleanup inventory gate.
- Static JSON retirement review.
- Supabase remnant cleanup gate.
- Test-channel / Discord-only manual cleanup gate.
## M-14E-18E 運用前リセット実行準備

Status: cleanup inventory/procedure draft completed. No destructive cleanup was run.

Added SQL drafts:

- `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql`
  - SELECT-only inventory for Supabase session counts and cleanup categories.
  - Does not return raw ids, Discord ids, post URLs, user ids, emails, tokens, secrets, or row data.
- `docs/supabase/sql/033_prelaunch_session_cleanup_apply_draft.sql`
  - DO NOT RUN / NOT EXECUTED / USER APPROVAL REQUIRED cleanup procedure draft.
  - Contains no executable delete/update/cleanup operation.

Static/code review:

- Static JSON rows remain outside DB/RPC cleanup and are marked by source as static.
- Supabase rows remain the only normal edit/delete target.
- Posted Supabase rows go through Discord delete sync before DB delete.
- Unposted Supabase rows use the existing DB-only delete path.
- Old test-webhook Discord remnants may not be deletable by the current production webhook and should be separated from normal production cleanup.
- No code change was made in this batch to avoid disturbing already verified create/update/delete auto-sync behavior.

Prelaunch cleanup plan:

1. Run the SELECT-only inventory gate.
2. Decide whether to retire or shrink `data/sessions.json`.
3. Classify Supabase rows into production auto-delete, DB-only delete, and manual-review candidates.
4. Handle old test-channel or Discord-only remnants on the Discord side or through a separately reviewed repair path.
5. Recheck calendar, session-detail, mypage/session-post management list, and GM/admin Discord sync panel after cleanup.

Future admin cleanup UI candidate:

- Admin-only inventory view with generalized counts.
- Individual and bulk cleanup actions with strong confirmation.
- Static JSON rows shown as fixture retirement targets, not DB delete targets.
- Discord-only remnants shown as manual Discord cleanup targets.

Not executed:

- No actual deletion, Discord post deletion, SQL Editor execution, SQL apply, DB/RPC change, Edge Function deploy, dry-run, real-send, secret switch, or `updates.json` change.

Next:

- Cleanup inventory SELECT-only gate.
- Static JSON retirement review.
- Supabase remnant cleanup gate.
- Old test-channel / Discord-only manual cleanup gate.
## M-14E-18F 運用前cleanup inventory結果記録

Status: SELECT-only inventory result recorded. No destructive cleanup was run.

- User ran `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql` once in SQL Editor.
- No SQL Editor error was shown, and a result grid was displayed.
- The inventory query was not rerun.
- No actual deletion, Discord post deletion, SQL apply, DB/RPC change, Edge Function deploy, dry-run, real-send, secret switch, or `updates.json` change was performed.

Inventory summary:

- Supabase session total: 23.
- QA/test/連携確認系 title candidates: 22.
- Manual confirmation required total: 22.
- Production-webhook posted Supabase candidate: 1.
- Possible old test webhook or manual review candidate: 2.
- Unposted Supabase DB-only cleanup candidate: 21.
- Saved external post identifier rows: 2.
- Saved channel identifier rows: 2.
- Saved thread identifier rows: 0.
- Saved post URL rows: 0.

Distribution summary:

- `discord_last_action`: null-like 20, create 2, delete 1.
- `discord_sync_status`: failed 1, not_requested 9, pending 1, posted 1, skipped 11.
- visibility: hidden 13, private 1, public 10.
- status: canceled 3, closed 1, draft 7, finished 1, full 1, recruiting 9, tentative 1.

Cleanup interpretation:

- Most Supabase session rows are likely QA/test cleanup candidates.
- 21 rows have no external post identifier and should be separated into a Supabase DB-only cleanup gate after manual classification.
- 2 rows have external post identifiers and need webhook-origin or manual review before any cleanup.
- The normal production-webhook delete-sync candidate appears to be 1 row.
- `discord_post_url` is saved on 0 rows, so it cannot be used for cleanup classification.
- Static JSON rows are outside this SQL inventory and need a separate retirement/non-display review.

Next:

- Split the next work into static JSON retirement review and Supabase DB-only cleanup gate.
- Keep external-identifier rows and old test-channel / Discord-only remnants in separate manual-review gates.
## M-14E-18G 静的JSON依頼書退役

Status: static JSON retirement implemented for normal UI. No destructive cleanup was run.

What changed:

- `data/sessions.json` remains in the repository as a fixture file.
- Normal calendar/session-detail loading no longer reads static JSON.
- Static fixture loading is available only through explicit development URL flags: `includeStaticSessions=1` or `staticSessions=1`.
- mypage application session metadata now comes from Supabase public session rows instead of `data/sessions.json`.
- Supabase remains the source of truth for production calendar/session-detail/mypage display.

Changed files:

- `assets/js/sessionData.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderCalendar.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/main.js`
- `calendar.html`
- `session-detail.html`
- `mypage.html`

Safety notes:

- Static JSON rows are no longer normally shown in calendar/session-detail and do not automatically return when Supabase load fails.
- Static JSON rows remain outside normal delete and Discord sync targets.
- Existing Supabase create/update/delete auto-sync code was not changed.
- No Supabase DB row deletion, Discord post deletion, SQL Editor execution, SQL apply, DB/RPC change, Edge Function deploy, dry-run, real-send, secret switch, or `updates.json` change was performed.

Next:

- Supabase DB-only cleanup gate for rows without external post identifiers.
- External-identifier row review gate for rows that require webhook-origin/manual confirmation.
- Old test-channel / Discord-only manual cleanup gate.
## M-14E-18H Supabase DB-only cleanup実行準備

Status: SELECT-only confirm SQL and guarded apply draft created. No destructive cleanup was run.

Context:

- Static JSON session fallback has been retired from normal UI.
- 032 inventory showed 21 Supabase DB-only cleanup candidates without external Discord identifiers.
- 2 rows with external Discord identifiers remain outside this DB-only cleanup path.
- Old test-webhook / Discord-only remnants remain separate manual-review items.

Existing delete path review:

- Existing `delete_session_post(text)` is a per-session GM/admin RPC and is still suitable for normal UI deletes.
- SQL Editor bulk cleanup does not have the same browser auth context, so a guarded direct-delete SQL draft is more practical for the prelaunch DB-only batch.
- Prior reviewed delete RPC notes confirmed `session_applications` and `session_comments` cascade with session deletion; the new draft still rechecks cascade readiness before deleting.

Added SQL drafts:

- `docs/supabase/sql/034_prelaunch_db_only_cleanup_confirm_select_only.sql`
  - SELECT-only confirmation for DB-only cleanup candidates.
  - Returns candidate count, 032 reference match, excluded counts, FK cascade readiness, and aggregate candidate distributions.
  - Does not return raw ids, Discord ids, post URLs, user ids, emails, tokens, secrets, or row data.
- `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql`
  - DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED.
  - Guarded direct-delete draft for a future apply gate only.
  - Stops if count mismatch, external identifier mix-in, non-QA mix-in, zero candidates, or FK cascade not confirmed.

Next:

- User runs 034 once in SQL Editor and reviews generalized results.
- If 034 is safe, decide in a separate apply gate whether to run 035.
- Keep external-identifier rows, old test-webhook remnants, Discord-only remnants, and static JSON fixture cleanup in separate tracks.

Not executed:

- No actual deletion, Discord post deletion, SQL Editor execution, SQL apply, DB/RPC change, Edge Function deploy, dry-run, real-send, secret switch, or `updates.json` change.
## M-14E-18I DB-only cleanup 034確認結果

Status: SELECT-only confirmation result recorded. No destructive cleanup was run.

- User ran `docs/supabase/sql/034_prelaunch_db_only_cleanup_confirm_select_only.sql` once in SQL Editor.
- No SQL Editor error was shown, and a result grid was displayed.
- The query was not rerun.
- No 035 execution, actual deletion, Discord post deletion, SQL apply, DB/RPC change, Edge Function deploy, dry-run, real-send, secret switch, or `updates.json` change was performed.

034 summary:

- DB-only cleanup candidate_count: 19.
- candidate_matches_032_reference: false.
- external_identifier_in_candidate_count: 0.
- non_qa_candidate_count: 0.
- excluded discord_identifier_rows: 2.
- excluded non_qa_rows: 1.
- FK readiness: `session_applications -> sessions cascade = true`, `session_comments -> sessions cascade = true`.

Candidate distribution:

- status: canceled 3, closed 1, draft 6, finished 1, full 1, recruiting 6, tentative 1.
- visibility: hidden 11, private 1, public 7.
- discord_sync_status: not_requested 8, pending 1, skipped 10.
- discord_last_action: null-like 18, create 1.

Decision:

- The candidate count changed from the 032 reference value 21 to 19, so the old 21-count 035 draft must not be executed.
- Current confirmation shows 19 DB-only cleanup candidates, external identifier mix-in 0, non-QA mix-in 0, and FK cascade OK.
- `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql` remains a DO NOT RUN / NOT EXECUTED draft, but its expected candidate count was updated to 19.
- Next step is an independent 035 apply gate if the user approves actual DB-only cleanup.

## M-14E-18J DB-only cleanup 035実行結果

Status: 035 apply result recorded. DB-only cleanup is treated as successful.

User-run result:

- `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql` was pasted into SQL Editor and executed once.
- No SQL Editor error was shown.
- The SQL was not rerun.
- The 19 DB-only cleanup candidates confirmed by 034 are treated as successfully deleted.
- Raw ids, Discord ids, post URL, JWT, session id, project ref, Supabase URL, webhook URL, user id, email, token, and message preview body were not recorded.

Decision:

- Since 034 confirmed external identifier mix-in 0, non-QA mix-in 0, and FK CASCADE OK, the 035 result is recorded as a guarded DB-only cleanup success.
- Additional post-cleanup SELECT-only confirmation was not run in this docs-recording batch. If needed, a separate SELECT-only gate should verify generalized counts only: DB-only cleanup candidates 0, Supabase session total decreased, and the 2 Discord-external-identifier rows still excluded.
- Discord post deletion was not performed.
- Static JSON rows remain retired from normal UI and are not part of this DB cleanup.

Next:

- Review the 2 rows with Discord external identifiers.
- Decide how to handle old test-channel / Discord-only remnants.
- Optional post-cleanup SELECT-only confirmation gate if the user wants a final generalized count check.

## M-14E-18K DB-only cleanup後の再棚卸し結果

Status: post-cleanup inventory recorded. No additional destructive cleanup was run.

User-run SELECT-only result:

- `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql` was run once in SQL Editor after DB-only cleanup.
- No SQL Editor error was shown.
- A result grid was displayed.
- The query was not rerun.
- Raw ids, Discord ids, post URL, JWT, session id, project ref, Supabase URL, webhook URL, user id, email, token, and message preview body were not recorded.

Inventory summary:

- Supabase session total: 3.
- manual_confirmation_required_total: 2.
- possible_old_test_webhook_or_manual_review_candidate: 2.
- production_webhook_posted_supabase_candidate: 1.
- unposted_supabase_db_delete_candidate: 1.
- Discord external identifier rows: message id-like 2, channel id-like 2, thread id-like 0, post URL 0.
- discord_last_action: null-like 1, create 1, delete 1.
- discord_sync_status: failed 1, posted 1, skipped 1.
- status_count: draft 1, recruiting 2.
- visibility_count: hidden 1, public 2.

Decision:

- DB-only cleanup reduced Supabase sessions to 3 rows.
- 2 remaining rows have Discord external identifiers and need webhook-origin or manual confirmation.
- 1 remaining row is an unposted DB-only candidate, but because it may be non-QA, it should be handled as part of a final reset rather than immediate bulk cleanup.
- 1 row appears to be a production-webhook delete-sync candidate.
- Old test-webhook-origin or Discord-only remnants may not be deletable through the current production webhook.
- `discord_post_url` is saved on 0 rows and cannot be used for cleanup classification.
- Static JSON rows remain retired from normal UI.

Preferred next approach:

- Treat manual Discord channel cleanup first, then use a guarded final-reset SQL for the 3 remaining DB rows.
- Split the next work into final-reset SELECT-only SQL creation and a guarded apply draft.
- Keep Discord post deletion, final DB reset, and any manual Discord cleanup as separate explicit gates.

## M-14E-18L 残り3件最終reset SQL準備

Status: final reset SQL drafts prepared. No destructive cleanup was run.

Context:

- Static JSON rows are retired from normal UI.
- The DB-only cleanup candidates were removed.
- Supabase sessions now have 3 remaining rows.
- 2 remaining rows have Discord external identifiers.
- 1 remaining row has no external Discord identifier.
- `discord_post_url` is saved on 0 rows and cannot be used for cleanup classification.

Final reset policy:

- The remaining 3 rows are prelaunch reset targets.
- Deleting DB rows does not delete Discord posts.
- The 2 Discord-external-identifier rows need Discord-side handling before DB deletion.
- The likely production-webhook row should preferably use auto-delete sync first if feasible.
- Old test-webhook or Discord-only remnants may need manual Discord deletion or channel cleanup.
- The final reset should be treated as DB cleanup plus Discord-side cleanup, not as a DB-only operation.

Added SQL drafts:

- `docs/supabase/sql/036_prelaunch_final_session_reset_confirm_select_only.sql`
  - SELECT-only confirmation for the remaining 3 rows.
  - Returns only aggregate status/count/result rows.
  - Confirms remaining count, external-identifier count, no-external count, status/visibility/sync aggregates, QA-like/non-QA counts, and FK cascade readiness.
- `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql`
  - DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED / DISCORD SIDE CLEANUP MUST BE DECIDED FIRST.
  - Defaults its Discord-side cleanup decision guard to false, so it aborts until a separately approved gate updates it.
  - Guards remaining count 3, external-identifier count 2, no-external count 1, and FK cascade readiness.
  - Notes that SQL cannot delete Discord posts.

Discord cleanup checklist:

- Production request channel: inspect unwanted posts and prefer auto-delete sync for production-webhook-origin rows where feasible.
- Test channel: old test-webhook posts may need manual deletion or channel cleanup.
- Discord-only remnants: handle manually because DB cannot track them.

Recommended order:

1. Run 036 SELECT-only confirmation once.
2. Decide how to handle the 2 Discord-external-identifier rows.
3. Use delete sync for production-webhook-origin rows if feasible.
4. Manually clean old test-webhook / Discord-only remnants on Discord.
5. Run 037 in a separate apply gate if approved.
6. Confirm DB sessions are 0 with SELECT-only inventory.
7. Confirm calendar/session-detail/mypage no longer show normal session posts.

Next:

- User runs 036 once in SQL Editor.
- Review 036 output and decide Discord-side cleanup / 037 apply gate.

## M-14E-18M 036 SELECT-only確認結果

Status: final reset confirmation recorded. 037 was not executed.

User-run SELECT-only result:

- `docs/supabase/sql/036_prelaunch_final_session_reset_confirm_select_only.sql` was run once in SQL Editor.
- No SQL Editor error was shown.
- A result grid was displayed.
- The query was not rerun.
- Raw ids, Discord ids, post URL, JWT, session id, project ref, Supabase URL, webhook URL, user id, email, token, and message preview body were not recorded.

036 summary:

- remaining_session_count: 3.
- external_identifier_rows: 2.
- no_external_identifier_rows: 1.
- discord_side_cleanup_required: true.
- qa_like_title_rows: 2.
- non_qa_rows: 1.
- FK readiness: `session_applications -> sessions cascade = true`, `session_comments -> sessions cascade = true`.
- discord_last_action: null-like 1, create 1, delete 1.
- discord_sync_status: failed 1, posted 1, skipped 1.
- status: draft 1, recruiting 2.
- visibility: hidden 1, public 2.

Decision:

- The remaining 3 rows are prelaunch reset targets.
- SQL cannot delete Discord posts for the 2 rows with Discord external identifiers.
- Old test-webhook-origin or Discord-only remnants should be manually cleaned on Discord.
- Running the DB final reset may remove the ability to track Discord posts from DB state.
- Even so, for prelaunch reset, the DB direction is to eventually reach 0 session rows.

037 execution rule:

- `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql` remains unexecuted.
- It still has DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED / DISCORD SIDE CLEANUP MUST BE DECIDED FIRST.
- `v_discord_side_cleanup_decided` remains false by default.
- In the next final reset apply gate, set `v_discord_side_cleanup_decided` to true only after the user explicitly approves the Discord-side cleanup decision and DB final reset.

Next:

- User confirms Discord-side cleanup handling.
- If approved, run 037 once in an independent final reset apply gate.
- After final reset, run SELECT-only confirmation for DB sessions 0 and verify normal UI pages show no session posts.

## M-14E-18N 037 final reset実行結果

Status: final reset apply result recorded. Supabase session rows are treated as reset.

User-run result:

- `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql` was run once in SQL Editor.
- Before execution, `v_discord_side_cleanup_decided` was changed to true after deciding that Discord-side remnants would be handled manually.
- No SQL Editor error was shown.
- The SQL was not rerun.
- deleted_count: 3.
- The remaining 3 Supabase session rows are treated as successfully deleted for prelaunch final reset.
- Raw ids, Discord ids, post URL, JWT, session id, project ref, Supabase URL, webhook URL, user id, email, token, and message preview body were not recorded.

Decision:

- Supabase-side remaining session rows are treated as reset to 0.
- Discord post deletion was not performed.
- Old test-webhook-origin or Discord-only remnants remain Discord-side manual cleanup targets.
- Static JSON rows remain retired from normal UI.

Next:

- Public-site final display confirmation.
- Discord channel remnant cleanup.
- Optional SELECT-only confirmation for DB sessions 0.

## M-14E-18O 運用前リセット完了記録・最終表示確認

Status: prelaunch cleanup completion recorded. No destructive operation was run.

Cleanup completion:

- After 037 final reset, DB-side session posts are treated as prelaunch-reset complete.
- The remaining 3 Supabase session rows are treated as successfully deleted by final reset.
- Discord test-channel posts were manually deleted by the user.
- Discord post deletion was not performed by SQL or Codex.
- Static JSON rows remain retired from normal UI.
- Major prelaunch session-remnant cleanup is treated as complete.
- If Discord-only remnants are found later, they should be handled manually on Discord, not through DB cleanup.

Final public-site display checklist:

- Calendar should not normally show old session posts.
- Session detail should not normally resurrect old static JSON posts.
- Mypage should not show unnecessary old session/application helper data.
- The UI should not break when normal session posts are 0.
- Create/update/delete Discord auto-sync for session posts has already passed QA.
- Raw Discord ids, post URLs, JWT/session values, user ids, emails, and tokens must not be displayed.

Static review:

- `sessionData.js` loads static JSON fixtures only with explicit development URL flags.
- `renderCalendar.js` and `renderSessionDetail.js` use `loadMergedSessions()`, so normal pages should not resurrect static JSON fixtures.
- Hosted-page final visual confirmation remains a user-side check.

Next:

- Public-site visual confirmation for calendar/session-detail/mypage.
- Manual Discord channel cleanup if any remnants are found.
- Prelaunch smoke check for a new production session post if desired.

## M-14E-19 GM手動〆マーク機能

Status: implemented. No DB/RPC change, SQL execution, Edge Function deploy, dry-run, Discord operation, or secret switch was performed.

Implemented scope:

- Added a GM-only manual close-mark control to the `session-detail` GM/admin management area.
- The control is shown only when the logged-in user is the session GM. Admin-only access does not expose this close-mark operation.
- `〆にする` updates the session title by prefixing the fullwidth `〆` mark through the existing `update_session_post` RPC.
- `〆解除` removes the leading `〆` mark and preserves the rest of the title.
- Duplicate close marks are avoided when adding `〆`.
- The title update reuses the existing frontend Discord update auto-sync path, so posted sessions should update Discord through the same `update` route as normal edits.
- The calendar display treats a leading `〆` title as closed display and renders the mark before the GM name rather than after it in the title text.
- Session detail and Discord update formatting can keep the actual title with `〆`.

Policy decisions:

- Application deadline remains a GM judgment reference, not an automatic wall.
- Comments remain available after the deadline in this task.
- Application availability is not forcibly changed by deadline time in this task.
- No new extension mode was added.
- No new DB column was added.
- Static JSON fixture sessions remain retired from normal UI and are not made Discord sync targets.

GM prompts and notes:

- If GM presses `〆にする` before the application deadline, the UI asks for confirmation before applying the mark.
- If the deadline has passed and the title is not marked, the GM management area shows a lightweight reminder instead of repeated modal prompts.
- Non-GM users, normal players, and logged-out users do not see the close-mark button or deadline reminder.

QA checklist:

- GM本人にだけ `〆にする` / `〆解除` が見えること。
- 通常PL、未ログインユーザー、GMではないadminに〆ボタンが見えないこと。
- 締切前に `〆にする` を押すと確認ダイアログが出ること。
- OK時のみタイトル先頭に `〆` が付き、キャンセル時は変わらないこと。
- 締切後で `〆` なしの場合、GM管理領域に押し忘れ注意が出ること。
- 締切後もコメント機能がこの変更で無効化されないこと。
- `〆〆タイトル` のような二重付与にならないこと。
- `〆解除` で先頭の `〆` だけ外れること。
- カレンダーでは `〆` がGM名より前に表示されること。
- Discord update自動同期が既存導線で発火し、余分なcreate投稿が増えないこと。
- create / update / delete自動同期、依頼書0件状態、静的JSON退役状態が壊れないこと。

Next:

- Public-site reflection check for calendar and session-detail.
- GM account browser QA for `〆にする` / `〆解除`.
- Discord update reflection check for a posted session, if needed, in a separate QA gate.

## M-14E-19A GM手動〆マーク 公開サイト軽量QA

Status: public static reflection checked. Interactive GM browser QA is still pending.

Public-site reflection check:

- `session-detail.html` returns HTTP 200 and references `assets/js/main.js?v=20260607-gm-close-mark`.
- `calendar.html` returns HTTP 200 and references `assets/js/main.js?v=20260607-gm-close-mark`.
- Public `main.js` imports `renderSessionDetail.js?v=20260607-gm-close-mark` and `renderCalendar.js?v=20260607-gm-close-mark`.
- Public `renderSessionDetail.js` contains the GM close-mark control, `〆にする`, `〆解除`, deadline reminder text, existing `update_session_post` usage, and existing `syncUpdatedSession` usage.
- Public `sessionDisplay.js` contains close-mark detection and title-without-close-mark helper logic.
- Public `renderCalendar.js` contains close-mark detection and renders the close mark before the GM label while avoiding duplicate title-prefix display.
- Public `style.css` contains the close-mark button, hidden-button, and close-note styles.

Safety result:

- No `dry_run=true` or `dry_run=false` was executed.
- No Discord production edit/post/delete was performed.
- No SQL Editor execution, SQL apply, DB/RPC change, Edge Function deploy, or secret/Webhook change was performed.
- No raw session id, JWT, user id, email, token, Discord message id, channel id, thread id, post URL, Webhook URL, or message preview body was recorded.

Interactive QA status:

- Codex-side Chrome control was unavailable in this session; only the in-app browser backend was discoverable, and it could not reliably attach to a public-site tab.
- Therefore, GM logged-in browser operations were not executed by Codex.
- GM-only visibility, normal-player visibility, confirmation dialog behavior, actual title update, double-mark prevention, close-mark removal, deadline reminder, and comment availability remain user-side browser QA items.

QA gate separation:

- Use a draft / hidden / unposted QA session first if available, to avoid Discord production edit.
- If testing on a public non-draft session with an existing Discord post reference, stop before pressing `〆にする` / `〆解除`; that operation can trigger Discord production update and must be a separate explicit gate.
- Discord production edit QA should be limited to one clearly selected posted session.

Remaining user-side QA checklist:

- GM本人にだけ `〆にする` / `〆解除` が表示されること。
- 通常PL/未ログインでは表示されないこと。
- 締切前に押すと確認ダイアログが出ること。
- キャンセルではタイトルが変化しないこと。
- OKでタイトル先頭に `〆` が付くこと。
- 二重に `〆〆` にならないこと。
- `〆解除` で先頭の `〆` だけ外れること。
- カレンダーでは `〆` がGM名より前に表示されること。
- 締切後で `〆` なしの場合、GM管理領域に押し忘れ注意が出ること。
- 締切後でもコメント機能が無効化されていないこと。
- 依頼書0件状態と静的JSON退役状態に影響しないこと。

## M-14E-20 mypage全体UI整理 / 予定表示整理

Status: implemented. No SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.

Implemented scope:

- Reorganized the logged-in mypage body into native `details` / `summary` sections.
- The top account section remains open by default and keeps the minimal logged-in overview, display-name editor, password-change action, and logout action.
- Profile and PC information is grouped into a collapsed section containing the existing PC-name panel and Discord user ID panel.
- Template management is grouped into its own collapsed section without changing template RPC behavior.
- Schedule / application history is grouped into one collapsed section with a compact summary count.
- Schedule categories are now separated as GM予定, 参加申請中, and 参加予定.
- Each schedule category shows its own `n件` count in the category heading.
- GM予定 uses Supabase session rows only, filters to normal public display candidates, and does not mix admin-managed targets with the user's own GM schedule.
- GM予定 cards keep a session-detail link and an edit/manage link.
- 参加申請中 and 参加予定 continue to use existing application data and public Supabase session metadata.
- Static JSON fixture sessions remain retired from normal operation and are not reintroduced into mypage.
- No PC selection select was added. Existing PC-name display/edit behavior was left in place.

UI policy:

- Use browser-native folding instead of a custom accordion script.
- Each summary shows a short section label and compact state/count text.
- The schedule summary updates after loading as `GM n / 申請中 n / 参加予定 n`.
- Empty GM schedule, application, and participant schedule states keep existing no-data messages and should not break zero-session operation.
- Admin-specific future UI should remain separate from the user's own GM schedule.

Safety notes:

- No raw user id, email, token, selected character id, application id, Discord message id, channel id, thread id, post URL, Webhook URL, JWT, project ref, or Supabase URL was added to screen text, docs, or console output.
- The implementation adds no Supabase direct `.insert` / `.update` / `.delete` / `.upsert` operation.
- Discord create/update/delete auto-sync code and Edge Function code were not changed.
- `updates.json` was not changed.

QA checklist:

- mypage is shorter on first load because only the account overview is open by default.
- Each mypage section can be opened and closed.
- Section summaries identify the content type without expanding everything vertically.
- Schedule summary counts update after data loading.
- GM予定 only, 参加申請中 only, 参加予定 only, and mixed categories are readable.
- Each visible schedule/application card links to `session-detail`.
- GM予定 keeps an edit/manage route for the user's own GM sessions.
- Admin-managed targets are not mixed into the user's GM schedule.
- Template management still loads, creates, updates, and deactivates through existing RPC paths.
- PC information handles未登録 state naturally and does not add a PC-select control.
- Static JSON fixture sessions do not return to normal mypage display.
- Mobile width keeps summary text and action buttons within their containers.

Next:

- Public-site reflection QA for the folded mypage layout.
- Browser QA with zero sessions, GM schedule only, application only, participant schedule only, and mixed data.
- Follow-up UI pass only if the folded sections feel too terse or counts need richer labels.

## M-14E-20A mypage折りたたみUI 公開反映確認

Status: public static delivery verified. Logged-in browser QA was not executed by Codex because Chrome extension control was unavailable in this environment.

Public delivery checks:

- `mypage.html` is served with the updated `mypageAuthClient.js` cache-bust for the folded mypage layout.
- `mypage.html` is served with the updated `style.css` cache-bust for the folded mypage layout.
- Served `mypageAuthClient.js` contains the native mypage `details` / `summary` helper.
- Served `mypageAuthClient.js` contains the default-open account overview section.
- Served `mypageAuthClient.js` contains the folded section labels `プロフィール / PC情報`, `予定 / 申請履歴`, and `テンプレート管理`.
- Served `mypageAuthClient.js` contains the schedule categories `GM予定`, `参加申請中`, and `参加予定`.
- Served `mypageAuthClient.js` contains the schedule summary count expression for GM / pending applications / accepted schedule counts.
- Served `mypageAuthClient.js` contains the GM schedule detail link and edit/manage route.
- Served `style.css` contains `mypage-details`, `mypage-details-summary`, and `mypage-application-count` styles.

Safety / non-regression checks:

- No visible PC selection label or PC selection control name was found in the served mypage JS.
- Static JSON sessions remain opt-in only through the existing static fixture flags and were not reintroduced into normal mypage behavior.
- No additional SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.
- No JWT, session id, project ref, Supabase URL, Discord message id, channel id, post URL, Webhook URL, raw user id, email, token, selected character id, application id, or message preview body was recorded.

Logged-in QA status:

- Codex attempted Chrome-backed browser confirmation, but Chrome extension control was unavailable.
- Therefore, logged-in visual confirmation of the actual folded authenticated mypage body remains user-side QA.
- Remaining user-side QA: account overview open by default, profile/PC info folded, schedule/application history folded, template management folded, schedule counts update after login, GM schedule / pending applications / accepted schedules render correctly, and zero-data states do not break layout.

Next:

- User-side public mypage visual QA with a logged-in account.
- If the folded sections feel too terse, refine summary labels without changing DB/RPC or Discord sync behavior.

## M-14E-21 mypage / calendar / session-post 軽微UI調整

Status: implemented. No SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.

Implemented scope:

- mypageの折りたたみ `details / summary` の境界線、背景、開閉表示を少し強め、閉じている項目と開いている項目を見分けやすくした。
- ログイン済みmypageのログアウト導線を本文上部の右寄せ操作へ移動し、アカウント概要内の重複ログアウトボタンを外した。
- ログアウト押下時に `ログアウトしますか？` の確認を出すようにした。
- calendarの `今日の月へ` を `今日へ` に短縮した。
- calendar上の依頼書表示に種別色を追加した。単発は青、キャンペーンは緑、特殊は赤、その他/不明は紫で扱う。
- calendarの `〆` 表示は既存どおりGM名より前に置き、タイトル本文側に二重表示しない。
- 依頼書投稿フォームでは、開催場所と種別、公開状態と募集状態が自然に揃うようにフォーム順と募集人数ブロックを調整した。
- 依頼書投稿入口は、GM/admin限定ではなくログインユーザー向けに変更した。
- 投稿済み依頼書の編集/削除一覧は、既存どおり本人GM分またはadmin対象に限定する。
- PC選択selectは追加していない。
- 静的JSON fixtureを通常UIへ戻す変更は行っていない。

Permission notes:

- 未ログインユーザーは引き続き依頼書投稿フォームへ進めない。
- 一般ログインユーザーは新規依頼書作成フォームへ進める。
- 他人の依頼書編集/削除を許可するフロント変更は行っていない。
- DB/RPC/RLSは変更していないため、実際の一般ログインユーザー作成可否は公開サイトQAで確認する。DB側で拒否される場合は、別ゲートでDB/RPC/RLS設計を行う。

QA checklist:

- mypageでログイン中のみ右寄せログアウトボタンが表示される。
- ログアウト押下時に確認ダイアログが出る。
- mypage各折りたたみの開閉状態が視覚的に分かる。
- calendarの今日ボタンが `今日へ` と表示される。
- calendar依頼書の色が種別別に変わり、文字が読める。
- `〆` 付き依頼書はcalendarでGM名より前に `〆` が出る。
- session-postで募集人数、開催場所、公開状態、募集状態が不自然に縦ずれしない。
- 一般ログインユーザーが新規依頼書投稿画面へ入れる。
- 投稿者本人/admin以外に既存依頼書の編集/削除導線が出ない。
- Discord create/update/delete自動同期に余分なcreate投稿が混ざらない。
- raw user id, email, token, selected character id, application id, Discord message id, channel id, post URL, JWT, project ref, Webhook URL, message preview body are not shown.

Next:

- Public-site reflection QA for mypage logout placement, calendar type colors, session-post form alignment, and general logged-in session post creation.
- If general logged-in creation is blocked by DB/RPC/RLS, stop before changing DB and prepare a separate permission gate.

## M-14E-21A 依頼書投稿フォーム 募集人数レイアウト是正

Status: implemented. No SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.

Implemented scope:

- `95b193b` のmypage境界強化、ログアウト外出し、calendar `今日へ`、calendar種別色分け、一般ログイン投稿入口解放は維持した。
- session-postフォームだけを対象に、募集人数ブロックの過剰な全幅化を戻した。
- 募集人数はPC幅で右列側に戻し、min/maxは同じブロック内で横並びのまま表示する。
- フォーム順序は、タイトル/開始日時、終了日時/申請締切、種別/募集人数、開催場所/公開状態、募集状態/管理対象の依頼書、概要の流れに整理した。
- negative margin や強引な位置補正は追加していない。
- テンプレート反映、保存、編集、Discord同期処理には触れていない。

QA checklist:

- 依頼書作成フォームで募集人数 min/max が右列内のまとまりとして表示される。
- 募集人数が横いっぱいの不自然な全幅ブロックになっていない。
- 募集状態が左列にあり、管理対象の依頼書が表示される編集/管理時は右列側に自然に並ぶ。
- 開催場所、公開状態、募集状態、管理対象の依頼書の並びが読みやすい。
- 新規依頼書作成画面と編集画面の両方で破綻しない。
- スマホ幅では従来どおり一列に自然に積まれる。
- mypage、calendar、ログアウト、一般ログイン投稿入口解放、GM手動〆マーク、Discord自動同期導線は巻き戻っていない。

## M-14E-21B mypage折りたたみ外枠調整 / session-post再確認

Status: implemented. No SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.

Implemented scope:

- session-postフォームの募集人数配置は、M-14E-21Aの目標レイアウトどおりであることを再確認した。
- mypageの折りたたみセクションでは、summary行の背景、下線、右端の開閉表示のボタン風装飾を戻した。
- 強調対象をsummary行ではなく、`details` セクション全体の外枠へ寄せた。
- details外枠は2px相当にして、閉じている状態でも独立した箱として見えるようにした。
- 開いているdetailsは外枠色だけを少し変え、中身のカードや入力欄の枠線は太くしていない。
- ログアウト外出し、赤系化、確認ダイアログ、calendar `今日へ`、calendar種別色分け、一般ログイン投稿入口解放は維持した。

QA checklist:

- mypageの項目名/summary行だけが妙に目立たない。
- mypageの各detailsセクション外枠だけが以前より分かりやすい。
- 複数セクションを開いても、各セクションの外側の境界が分かる。
- session-postでは募集人数 min/max が右列内で横並びになっている。
- 募集状態は左列にあり、管理対象の依頼書が出る場合は右列側と自然に並ぶ。
- `95b193b` 以降の他改善は巻き戻っていない。

## M-14E-21C session-postフォーム配置 再是正

Status: implemented. No SQL Editor execution, DB/RPC change, SQL apply, Edge Function deploy, dry-run, Discord operation, or secret/Webhook change was performed.

Implemented scope:

- 前回修正後も公開側で募集人数が全幅ブロックに見える状態が残ったため、`59989fe` の良状態と照合してsession-postフォーム配置だけを再確認した。
- DOM順は、タイトル/開始日時、終了日時/申請締切、種別/募集人数、開催場所/公開状態、募集状態/管理対象の依頼書、概要の順で維持した。
- 募集人数フィールドに `grid-column: auto` と `width: auto` を明示し、フォーム全幅へ広がらないことをCSS側でも固定した。
- session-postページのCSSとmain module、main内の `renderSessionPost` importに新しいcache-bustを付け、古い公開配信JS/CSSが残らないようにした。
- mypage、ログアウト、calendar、一般ログイン投稿入口解放、本人GM/admin管理境界、Discord同期導線、GM手動〆マーク機能は巻き戻していない。

QA checklist:

- 種別の右に募集人数がある。
- 募集人数 min/max は右列内で横並びになっている。
- 募集人数が左右列をまたぐ全幅ブロックになっていない。
- 開催場所の右に公開状態がある。
- 募集状態の右に管理対象の依頼書がある。
- 概要だけが横長エリアになる。
- 公開サイト反映後、session-postページが新しいcache-bustのJS/CSSを読んでいる。

## M-14E-22 UI安定化バッチ

Status: implemented. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord operation, secret/Webhook change, or cleanup apply was performed.

Implemented scope:

- session-postフォームの二列構造を維持し、募集人数を全幅化させないまま右列内のまとまりとして表示するようにした。
- 募集人数は `募集人数` ラベルと min/max 入力を近づけ、右列内で一行に近い見た目へ整理した。
- session-postの行構成は、タイトル/開始日時、終了日時/申請締切、種別/募集人数、開催場所/公開状態、募集状態/管理対象の依頼書、概要のまま維持した。
- mypageのログアウトボタンを本文上部ではなく、ナビゲーションの `ACCOUNT` 直後へ移動した。
- ログアウトボタンはログイン中のみ生成し、未ログイン表示では撤去する。
- ログアウトの赤系表示と `ログアウトしますか？` 確認ダイアログは維持した。
- mypageの折りたたみUIはsummary行を強調せず、detailsセクション全体の外枠を2px相当にする方針を維持した。
- calendarのスマホ幅では月カレンダーを一列リスト化せず、7列月表示を横スクロールで使えるようにした。
- calendarの選択日一覧/詳細パネルは残し、月表示と併用する。
- calendar月表示内の `今日へ` は、今日の月へ移動するだけでなく、今日の日付を選択するようにした。
- session-post / calendar / mypage のcache-bustを更新し、公開側で古いUIが残らないようにした。

Preserved scope:

- calendarの `今日へ` 文言と種別別色分け。
- calendarの `〆` がGM名より前に出る既存表示。
- 一般ログインユーザーの依頼書投稿入口解放。
- 本人GM/adminの編集・削除境界。
- Discord create/update/delete自動同期導線。
- GM手動〆マーク機能。
- 静的JSON fixtureの通常UI退役。

QA checklist:

- session-postで募集人数が右列内にあり、min/maxが横並びで見える。
- 募集人数が全幅ブロック化していない。
- session-postの二列構造がPC幅で維持され、スマホ幅では一列に自然に積まれる。
- mypageのログアウトボタンが `ACCOUNT` 横付近に表示される。
- ログアウトボタンはログイン中のみ表示される。
- ログアウト確認でキャンセルするとログアウトしない。
- mypageのsummary行ではなく、details外枠が太くなっている。
- スマホcalendarで月表示が使え、必要に応じて横スクロールできる。
- `今日へ` を押すと今日が選択状態になり、今日の予定が選択日パネルへ反映される。
- Discord同期、DB/RPC、secret、Webhook、Edge Functionには影響していない。

## M-14E-22A UI安定化バッチ追加調整

Status: implemented. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord operation, secret/Webhook change, or cleanup apply was performed.

Implemented scope:

- スマホ版calendarの月表示で、700px固定幅によるページ全体の横伸びを避けるように調整した。
- スマホ幅ではcalendarの7列構造を維持しつつ、セルの余白、最小高さ、タグ、予定ラベルをコンパクト化した。
- calendarの季節色、月齢、レベルキャップ、種別別色分け、`〆` 表示、`今日へ` で今日を選択する挙動は維持した。
- mypageのログイン後初期表示で、アカウント概要を含む全detailsが閉じた状態になるようにした。
- mypageのログアウトボタンは引き続きACCOUNT横に表示し、赤系表示と確認ダイアログを維持した。
- テンプレート管理内の「使用できる変数一覧」を入れ子のdetailsにし、初期状態では閉じるようにした。
- `calendar.html` / `mypage.html` / `main.js` のcache-bustを更新し、公開反映時に古いUIが残りにくいようにした。

QA checklist:

- スマホ幅でページ全体に横スクロールが出ず、月カレンダー表示が画面内に収まる。
- calendarの予定ラベルがセル外へ大きくはみ出さない。
- `今日へ` を押すと今日の月へ移動し、今日の日付が選択される。
- mypageをログイン済みで開いた直後、アカウント概要、プロフィール/PC情報、予定/申請履歴、テンプレート管理がすべて閉じている。
- 各detailsのsummaryを押すと正常に開閉できる。
- テンプレート管理を開いた中で、「使用できる変数一覧」がさらに折りたたみとして表示され、開くと従来の変数一覧を確認できる。
- テンプレート保存/編集/削除/反映UI、session-post募集人数表示、Discord自動同期導線、GM手動〆マーク機能には影響しない。

## M-14E-22B calendar月表示UI再調整

Status: implemented. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord operation, secret/Webhook change, or cleanup apply was performed.

Implemented scope:

- calendar月表示ヘッダーを、左に年月、右に `‹ 今日 ›` の短い操作群を置く構成へ変更した。
- 旧 `前月へ` / `今日へ` / `次月へ` の長い文字ボタンは月表示内から廃止し、aria-label / title で前月・今日・次月の意味を残した。
- `今日` ボタンは、従来どおり今日の月へ移動し、今日の日付を選択する。
- スマホ幅では月セルをさらにコンパクト化し、曜日、ラクシア短縮日付、長い予定ラベルを月セル内で縦に伸ばさないようにした。
- スマホ幅では、季節/月齢/レベルは小さなドット表示、依頼書作成リンクは `+` 表示、予定ありの日は件数チップで示す。
- 詳細な依頼書/セッション情報は、日付選択後の選択日パネルで確認する方針を維持した。
- calendarの季節色、今日表示、選択日表示、種別別色分け、`〆` がGM名より前に出る表示は維持した。
- `calendar.html` / `main.js` のcache-bustを更新し、公開反映時に古い月表示UIが残りにくいようにした。

QA checklist:

- スマホ版calendarで日付セルが縦に伸びすぎず、月全体を見渡しやすい。
- スマホ幅でページ全体に横スクロールが出ない。
- 予定/依頼書がある日は件数チップで分かる。
- 依頼書作成リンクがスマホ幅で長い `＋依頼書` ラベルとして縦に伸びない。
- web版/スマホ版とも、月表示ヘッダーが `年月左上 / ‹ 今日 › 右上` に近い構成になっている。
- `‹` で前月、`›` で次月、`今日` で今日の日付選択まで行われる。
- PC版の月カレンダー情報量は極端に劣化していない。
- mypage、session-post、Discord同期導線、GM手動〆マーク機能には影響しない。

## M-14E-22C calendar月表示の縦リスト化是正

Status: implemented. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord operation, secret/Webhook change, or cleanup apply was performed.

Context:

- `d8eef8c` 後、web版/スマホ版calendarの月表示が7列月カレンダーではなく、日ごとの縦リストのように見える問題があった。
- スマホ版では予定表示や依頼書導線も圧縮されすぎ、文字省略で意味が分かりづらい状態になっていた。

Implemented scope:

- calendar月表示のCSSを見直し、web版/スマホ版とも `日/月/火/水/木/金/土` の7列グリッドを明示的に維持するよう是正した。
- `d8eef8c` で混入していたcalendarヘッダー直後の余分なCSS閉じ括弧を削除した。
- スマホ幅でも日付セルを1日ずつ縦に積まず、7列月カレンダーとして表示する方針へ戻した。
- スマホ幅では、予定ありの日に件数チップと短い予定行を表示し、詳細は日付選択後のパネルで確認する方針にした。
- 依頼書作成導線はスマホでも `+` だけにせず、短いテキストとして意味が分かる表示に戻した。
- calendarヘッダーの `年月左上 / ‹ 今日 ›右上` 形式、旧長文ボタン廃止、`今日` で今日の日付を選択する挙動は維持した。
- `calendar.html` / `main.js` のcache-bustを更新し、公開反映時に古いcalendar UIが残りにくいようにした。

QA checklist:

- web版で7列の月カレンダー表示になり、日ごとの縦リスト表示になっていない。
- スマホ版でも7列の月カレンダー表示になり、日ごとの縦リスト表示になっていない。
- スマホ版で予定ありの日が分かり、詳細情報は日付選択後のパネルで確認できる。
- ページ全体が横に広がらない。
- calendarヘッダーは `年月左上 / ‹ 今日 ›右上` を維持している。
- `‹` / `›` / `今日` の挙動が正常で、`今日` では今日の日付が選択される。
- calendar種別別色分け、`〆` 表示、静的JSON通常UI退役、Discord同期導線には影響しない。

## M-14E-22D スマホ版calendar月グリッド可読性改善

Status: implemented. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord operation, secret/Webhook change, or cleanup apply was performed.

Implemented scope:

- web版calendarの正常な7列月グリッドには大きく触れず、スマホ用media query内の月セル表示だけを再調整した。
- スマホ版calendarは7列グリッドを維持したまま、日付セルの高さを確保して縦方向に情報を積む方針へ変更した。
- ラクシア日付、季節、新月/満月/通常、レベル表示をドット化・非表示化せず、小さな文字バッジとして読めるように戻した。
- 予定/依頼書タイトルはスマホ幅でも省略しっぱなしにせず、必要に応じて折り返して表示するようにした。
- 依頼書作成導線は `+` だけにせず、短いテキスト表示として意味が分かる状態を維持した。
- スマホでは月全体が縦に長くなることを許容し、日ごとの縦リスト表示には戻さない方針を明記した。
- `calendar.html` のCSS cache-bustを更新し、公開反映時に古いスマホ用CSSが残りにくいようにした。

QA checklist:

- web版calendarは引き続き7列月グリッドで表示される。
- スマホ版calendarも `日/月/火/水/木/金/土` の7列グリッドを維持している。
- スマホ版の日付セルが縦長になり、ラクシア日付、季節、新月/満月/通常、レベル、依頼書導線の文字が読める。
- 依頼書導線が `+` だけではなく、意味が分かる短い表示になっている。
- ページ全体が横に広がらず、スマホでは縦スクロールで月全体を読める。
- calendarヘッダーの `年月左上 / ‹ 今日 ›右上` 形式と、`今日` で今日の日付を選択する挙動は維持されている。
- calendar種別別色分け、`〆` 表示、mypage/session-post、Discord同期導線には影響しない。

## M-14E-23 Discord everyone mention Edge support

Status: implemented in Edge Function source only. No frontend UI change, template change, Edge Function deploy, dry-run, real send, Discord operation, SQL Editor execution, DB/RPC/RLS change, SQL apply, secret/Webhook change, cleanup apply, or `updates.json` change was performed.

Implemented scope:

- `sync-session-post-to-discord` now accepts a future string payload field `discord_mention_mode`.
- Supported values are `everyone` and `none`; missing, null, or unexpected values fall back to `none`.
- `@everyone` is inserted into the Discord body only when `action=create` and `discord_mention_mode=everyone`.
- The mention line is placed directly under the top separator line.
- `update` / `delete` / `close` / `resync` ignore the mention mode and do not add `@everyone`.
- Webhook `allowed_mentions` remains disabled by default, and opens only `everyone` for the explicit create opt-in path. Roles and users are not enabled.
- Existing create/update/delete sync behavior, DB state recording, double-post guard, and message formatting remain otherwise unchanged.

Next gate:

- Deploy the Edge Function in a separate gate.
- After deploy, first verify `create / dry_run=true` with `discord_mention_mode=none` and `discord_mention_mode=everyone` without recording the preview body.
- Any `dry_run=false` Discord post that includes `@everyone` must be a separate explicit gate and should use one clearly selected QA request only.

QA checklist:

- Missing `discord_mention_mode` produces no mention.
- `discord_mention_mode=none` produces no mention.
- `discord_mention_mode=everyone` with `action=create` includes one `@everyone` directly under the top separator.
- Repeated processing does not add duplicate mention lines because the message body is rebuilt from session data.
- `update` / `delete` / `close` / `resync` do not include `@everyone` even if `discord_mention_mode=everyone` is passed.
- `allowed_mentions.parse` is `["everyone"]` only on the create/everyone send path and `[]` otherwise.

## M-14E-23A Discord everyone mention Edge deploy

Status: deployed. No dry-run, real-send, Discord post/edit/delete, SQL Editor execution, DB/RPC/RLS change, SQL apply, secret/Webhook change, cleanup apply, frontend UI change, template change, or `updates.json` change was performed.

Deploy result:

- Target function: `sync-session-post-to-discord`.
- Target source commit: `9210598 Support Discord everyone mention mode`.
- Project ref was read from the clipboard into an environment variable and was not recorded.
- Project ref format check passed.
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` succeeded before deploy.
- Edge Function deploy was executed once.
- Deploy exit code was 0 and the CLI reported success.
- A deploy warning was present, but no authentication failure hint was detected.
- CLI raw output was not copied into docs because it may contain project metadata.
- Generated `deno.lock` and `supabase/.temp` artifacts were removed and are not commit targets.

Still not performed:

- `dry_run=true` verification.
- `dry_run=false` real send.
- Discord post/edit/delete.
- Secret/Webhook setting or switch.
- SQL/DB/RPC/RLS change.

Next gate:

- Post-deploy `dry_run=true` verification for `discord_mention_mode=none` and `discord_mention_mode=everyone`.
- Record only booleans/status such as preview presence and mention presence checks; do not record the preview body.
- Any real `@everyone` Discord send remains a separate explicit gate with one selected QA request.

## M-14E-23B Discord mention selection UI and template prep

Status: implemented in frontend/docs only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, real-send, Discord post/edit/delete, secret/Webhook change, cleanup apply, or `updates.json` change was performed.

Context:

- Post-deploy `dry_run=true` verification for `discord_mention_mode` was not completed in the previous gate because there was no safe candidate request to use at that time.
- The dry-run verification remains folded into a later actual registration QA gate, where a new safe QA request can be selected without exposing IDs or preview text.
- `message_preview` body text, JWT, session ID, project ref, Supabase URL, Webhook URL, Discord IDs, post URL, and raw user/account identifiers are not recorded.

Implemented scope:

- session-post create form now shows a create-only `Discord通知` radio choice with `@everyone通知を送る` and `@everyone通知を送らない`.
- The mention UI is hidden in edit/update mode, and edit/update/delete sync calls do not pass `discord_mention_mode`.
- Public non-draft creation requires an explicit mention choice before DB save and before Discord auto-create sync.
- Draft, hidden/private, or otherwise non-create-sync saves may leave the mention choice unset.
- If `@everyone` is selected for a public non-draft create during JST 00:00-05:59, the form asks for one confirmation before saving.
- The frontend passes `discord_mention_mode` only to the create auto-sync path. Update/delete paths remain mention-free.
- session-post templates now preserve `discord_mention_mode` as `everyone`, `none`, or unset. Older templates without the field remain unset.
- Applying a template on the new-create page restores the mention selection; applying a template while editing ignores the mention field because the edit UI is hidden.
- session-post and mypage template management now include a display-only `テンプレート例` details block by template type. No example text was invented; empty types show `この種別の例はまだありません。`.
- Cache-bust values were updated for session-post, mypage, `renderSessionPost`, `discordSyncClient`, and the shared CSS path so the public site does not keep stale mention/template UI assets.

QA checklist:

- New public non-draft request creation cannot proceed until either `@everyone通知を送る` or `@everyone通知を送らない` is selected.
- New draft or non-public request creation can proceed with the mention choice unset.
- Edit mode does not show the mention radio group.
- Create sync payload includes `discord_mention_mode` only for the create path.
- Update/delete sync payloads do not include the mention mode.
- JST late-night warning appears only for public non-draft create with `@everyone` selected.
- Template save/apply preserves the mention choice on new-create forms and ignores it on edit forms.
- Template example display is read-only and does not overwrite form body/template content.
- No PC select, DB schema/RPC change, Edge Function change, or Discord operation is part of this gate.

## M-14E-23C Discord mention UI public reflection and no-send QA

Status: partially verified by public asset fetch and static/code-path review. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, real-send, Discord post/edit/delete, public non-draft save, secret/Webhook change, cleanup apply, or `updates.json` change was performed.

Public reflection:

- `session-post.html` on the public site references the `20260608-discord-mention-ui` cache-bust for CSS and main JS.
- Public `main.js` references the updated `renderSessionPost.js` cache-bust.
- Public `renderSessionPost.js` references the updated `discordSyncClient.js` cache-bust.
- Public `renderSessionPost.js` includes `discord_mention_mode`, `everyone`, `none`, the required-selection message, and the JST late-night confirmation message.
- Public `discordSyncClient.js` includes the create-only `discord_mention_mode` payload path.
- Public `mypage.html` / `mypageAuthClient.js` include the template mention field and display-only template example UI.
- Public CSS includes the session-post mention field and template example styling.

No-send QA result:

- Logged-in Chrome UI operation was not completed because the Codex Chrome Extension was not available/enabled in the selected Chrome profile, so browser-client tab control could not attach.
- Because logged-in browser control was unavailable, actual form clicking, template save/apply operation, and edit-mode UI inspection remain user/browser QA items.
- Static/code-path review confirms the new-create form renders a `Discord通知` radio group with `@everyone通知を送る` and `@everyone通知を送らない`.
- Static/code-path review confirms the mention field is hidden and cleared in edit mode.
- Static/code-path review confirms public non-draft creation validates the mention selection before `create_session_post` RPC is called.
- Static/code-path review confirms `discord_mention_mode` is passed only to create auto-sync and not to update/delete auto-sync.
- Static/code-path review confirms templates can persist `discord_mention_mode` as `everyone`, `none`, or unset, and older templates remain unset.
- Static/code-path review confirms template mention values are applied only on new-create forms and ignored on edit forms.
- Static/code-path review confirms the template example UI is display-only and does not write into the template body or request body.
- JST late-night warning was not runtime-tested because no safe logged-in browser operation was available; the JST 00:00-05:59 branch remains covered by static/code-path review.

User/browser QA items still open:

- On the public site while logged in, confirm the `Discord通知` radio group appears only on new create.
- Confirm initial mention state is unset and the radio choices are mutually exclusive.
- Confirm public non-draft save with no mention choice stops before DB save with `Discord通知を送るか送らないかを選択してください。`.
- Confirm edit mode does not show the mention UI.
- Confirm template save/apply can restore `everyone` / `none` / unset on the new-create form without sending Discord.
- Confirm template example UI shows the empty state naturally and does not insert text into the form.

Next gate:

- Continue to actual registration QA only after selecting a safe QA request path.
- `dry_run=true` mention verification remains deferred until a safe request candidate exists.
- Any `dry_run=false` or real Discord post involving `@everyone` remains a separate explicit gate.

## M-14E-24 Registration QA gate prep: mention none and calendar colors

Status: static/public-reflection review only. No public non-draft save, DB write, dry-run, real-send, Discord post/edit/delete, SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, secret/Webhook change, cleanup apply, or `updates.json` change was performed.

Scope decision:

- This gate can involve Discord production posts if public non-draft requests are actually saved.
- Because each save that triggers Discord create must be explicitly approved one by one, Codex stopped before any real save.
- Past-three-session registration and any public non-draft registration remain user/manual gated work.
- The `@everyone通知を送る` real notification path remains deferred to the later unheld-session gate.

Confirmed by public asset fetch / static review:

- Public `session-post.html` and `mypage.html` still serve the latest mention UI cache-bust.
- Public `renderSessionPost.js` contains the new-create `Discord通知` UI, required-selection validation, and edit-mode hiding path.
- Public `discordSyncClient.js` passes `discord_mention_mode` only for create sync.
- Public `mypageAuthClient.js` includes template mention save/restore and display-only template example UI.
- General logged-in users are allowed to open the posting form path; the current code reports `ログインユーザーとして投稿できます。` for non-admin users.
- Managed edit/delete listing remains filtered to own GM sessions unless admin, based on the current user ID check inside `normalizeManageSessions`.
- Calendar type color classes exist:
  - one-shot: blue tone.
  - campaign: green tone.
  - special: red tone.
  - other/unknown: purple tone.
- Calendar session rows/cards use `sessionType` to apply the type color class.
- Static JSON fixture remains outside normal UI flow from the earlier retirement work.

Not executed:

- Public/non-draft request save.
- `@everyone通知を送らない` actual registration.
- Past-three-session admin registration.
- Calendar visual confirmation with newly registered sessions.
- Template save/apply by logged-in browser operation.
- JST late-night warning runtime check.

Reason not executed:

- Logged-in Chrome UI operation is still unavailable from Codex because browser-client tab control cannot attach to the selected Chrome profile.
- More importantly, public non-draft save can trigger Discord production create, so it must be a separate explicit user-confirmed action per request.

Next gated checklist:

- Before each public non-draft save, confirm the exact request title and that `@everyone通知を送らない` is selected.
- For mention-none registration, record only booleans/status:
  - `mention_mode_selected=none`
  - `discord_post_created=true/false`
  - `discord_everyone_present=false`
  - `unexpected_extra_create=false`
- Do not record Discord message ID, channel ID, post URL, session ID, JWT, project ref, Supabase URL, Webhook URL, or message body text.
- If three past sessions are registered manually, record which session types were covered and leave missing type colors as unverified rather than creating fake data.
- Keep `@everyone通知を送る` real notification for a later independent gate.

## M-14E-25 Template example content and mention template QA prep

Status: frontend/docs update only. No public non-draft save, DB write, dry-run, real-send, Discord post/edit/delete, SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, secret/Webhook change, cleanup apply, or `updates.json` change was performed.

Implemented:

- Added display-only template examples for the four template types:
  - application template.
  - call template.
  - result template.
  - session post template.
- The mypage template management UI now shows only the example matching the selected template type.
- The session-post template UI shows only the session-post example; unsupported/other types keep the existing empty state.
- Template examples are rendered with preserved line breaks in a separated example area.
- A short note clarifies that examples are not automatically inserted into the body.
- Updated cache-bust values for `mypage.html`, `session-post.html`, and the session-post module import.

Safety / behavior boundaries:

- Examples are not inserted into the template body.
- Examples do not overwrite current template text or request form text.
- Examples are not saved as user templates.
- Examples are not mixed into the user template list or shared as presets.
- Template type separation is maintained: application/call/result/session-post examples do not cross-display.
- Existing template save/edit/delete/apply logic was not changed except for the read-only example rendering.
- Existing `discord_mention_mode` template save/restore paths were left intact.
- Edit-mode mention UI hiding remains unchanged.

Mention template QA status:

- Static/code-path review confirms the mention setting remains part of session-post template fields.
- Static/code-path review confirms `everyone`, `none`, and unset values can be represented by existing template parsing.
- Static/code-path review confirms edit mode still ignores/hides the mention UI even if a template contains a mention value.
- Logged-in browser operation for saving/applying mention templates was not executed in this gate.
- User/browser QA remains: save/apply `@everyone通知を送らない`, save/apply `@everyone通知を送る`, confirm unset old templates remain unset, and confirm no Discord post is triggered during template-only work.

Next:

- Continue to the gated registration QA only after explicitly selecting a safe request registration path.
- Keep `@everyone通知を送る` real notification for a later independent gate.

## M-14E-26 General user session-post create failure triage

Status: frontend triage/docs update only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, public non-draft retry, or `updates.json` change was performed.

Observed failure:

- A logged-in general user could open the session-post new-create form.
- The user selected `@everyone通知を送らない`, `公開`, and `開催終了`.
- Pressing create showed `依頼書を投稿できませんでした。権限または入力内容を確認してください。`.
- No Discord post verification or retry was performed in this gate.

Repo-side finding:

- Frontend access was intentionally loosened so logged-in users can open the create form.
- The create payload still calls `create_session_post` with the existing RPC argument set, including `p_session_tool` and `discord_mention_mode` only for Discord auto-sync after successful create.
- `discord_mention_mode` does not change the RPC payload sent to `create_session_post`.
- The local SQL draft for the currently applied `create_session_post` still has a GM/admin gate in the function body: logged-in non-GM users are likely rejected by the RPC even though the frontend form is visible.
- The same draft limits initial create status to `draft` / `tentative` / `recruiting`; `closed` / `finished` / `canceled` are update-time statuses, not initial create statuses.
- Therefore the failure has two likely causes:
  - primary: DB/RPC policy still requires GM/admin for new create.
  - secondary: `開催終了` maps to `finished`, which the create RPC rejects as `invalid_initial_status`.

Frontend mitigation implemented:

- New-create now validates initial status before calling `create_session_post`.
- If the selected status is not `下書き` / `仮予定` / `募集中`, the form stops locally with a specific message and does not call the RPC.
- Create RPC errors are mapped to safer, more specific user-facing messages, including the GM/admin-required case.
- Edit/update status handling is unchanged; existing sessions can still use the broader status set through `update_session_post`.
- No edit/delete ownership boundary was relaxed.

SQL / DB follow-up prepared but not executed:

- Added `docs/supabase/sql/038_general_user_session_post_create_preflight_select_only.sql`.
  - SELECT-only.
  - Confirms `create_session_post` existence, security definer, search_path, authenticated EXECUTE, anon/PUBLIC state, GM/admin gate presence, initial status limitation, and helper presence.
  - Does not return real IDs, user rows, Discord IDs, URLs, or personal data.
- Added `docs/supabase/sql/039_general_user_session_post_create_apply_design_draft.sql`.
  - Design-only / not executable.
  - Records the candidate policy: allow any authenticated user to create a session post while keeping owner/admin update/delete controls.
  - Requires a later full `create_session_post` replacement draft after 038 confirms the live function body.

Next gate:

- Run/review 038 SELECT-only in SQL Editor only after explicit approval.
- If 038 confirms the GM/admin gate, prepare a full reviewed `create_session_post` replacement draft that removes only the create-time GM/admin role gate.
- Keep initial create statuses limited to `draft` / `tentative` / `recruiting` unless a separate policy review decides past-session direct create is safe.
- Any public non-draft retry can trigger Discord create and remains a separate explicit gate.

## M-14E-26B General user create preflight SQL fix

Status: docs/SQL draft correction only. No SQL Editor rerun, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, public non-draft retry, or `updates.json` change was performed.

038 execution result:

- User ran `docs/supabase/sql/038_general_user_session_post_create_preflight_select_only.sql` once in SQL Editor.
- SQL Editor stopped with `ERROR: 42704: role "PUBLIC" does not exist`.
- The user did not rerun 038.
- No DB mutation occurred.

Cause:

- 038 treated PostgreSQL `PUBLIC` as if it were a normal role in `has_function_privilege(...)`.
- PostgreSQL `PUBLIC` is a pseudo-role/pseudo-grantee and should not be passed as a normal role name for this check.

Fix prepared:

- Added `docs/supabase/sql/040_general_user_session_post_create_preflight_select_only_fix.sql`.
- 040 is SELECT-only and keeps 038 as the failed historical draft.
- 040 does not reference `PUBLIC` as a role.
- 040 uses `to_regrole(...)` for role lookup and focuses on:
  - `create_session_post` existence.
  - security definer.
  - search_path.
  - authenticated EXECUTE.
  - anon EXECUTE state.
  - GM/admin gate presence in the RPC body.
  - initial status limitation to `draft` / `tentative` / `recruiting`.
  - whether general-user create likely needs an RPC change.
- 040 does not return real IDs, user rows, Discord IDs, URLs, or personal data.

Next gate:

- Run 040 once in SQL Editor after explicit approval.
- Do not rerun 038.
- If 040 confirms the GM/admin gate, prepare a full reviewed `create_session_post` replacement draft in a later gate.

## M-14E-26C General user create preflight result and RPC draft

Status: docs/SQL draft/frontend UI update only. No SQL Editor execution by Codex, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, public non-draft retry, or `updates.json` change was performed.

040 SELECT-only result:

- User ran `docs/supabase/sql/040_general_user_session_post_create_preflight_select_only_fix.sql` once in SQL Editor.
- Result was shared as boolean/status values only; no real IDs, URLs, user rows, JWT, session IDs, or Discord IDs were recorded.
- Key results:
  - `authenticated_role_exists`: ok / true.
  - `create_rpc_anon_execute`: ok / false.
  - `create_rpc_authenticated_execute`: ok / true.
  - `create_rpc_exists`: ok / 1.
  - `create_rpc_has_gm_admin_gate`: review / true.
  - `create_rpc_has_search_path`: ok / true.
  - `create_rpc_initial_status_limited`: review / true.
  - `create_rpc_security_definer`: ok / true.
  - `general_user_create_change_needed`: review / true.
  - `helper_has_role_exists`: ok / 1.
  - `helper_is_admin_exists`: ok / 1.
  - `status_check_constraints_present`: ok / 2.

Interpretation:

- `create_session_post` exists and authenticated can execute it.
- The RPC body still has a GM/admin gate, so authenticated EXECUTE alone does not let logged-in non-GM users create session posts.
- General logged-in user create requires a `create_session_post` RPC replacement.
- The initial create status guard remains aligned with the intended UI policy: `draft` / `tentative` / `recruiting`.

Prepared RPC apply draft:

- Added `docs/supabase/sql/041_general_user_session_post_create_rpc_apply_draft.sql`.
- 041 is an apply draft and was not executed.
- 041 keeps the existing signature, return shape, security definer, search_path, input validation, `session_tool`, Discord sync metadata, and authenticated grant pattern.
- 041 removes only the create-time GM/admin role gate.
- The creator remains the owner/GM for the new session via `gm_user_id = auth.uid()`.
- `update_session_post` / `delete_session_post` are not changed.
- Edit/delete/close/manual-close remain owner-GM/admin scoped by existing flows.
- Initial create statuses remain limited to `draft` / `tentative` / `recruiting`.
- `closed` / `finished` / `canceled` are not allowed as initial create statuses.

Frontend UI update:

- The base session-post status select now shows only:
  - `下書き`.
  - `仮予定`.
  - `募集中`.
- `募集終了` / `開催終了` / `中止` were removed from the normal user-selectable options.
- Existing old data compatibility is preserved: if an existing managed session has an old/broader status, the current temporary-option path can still display that value for edit compatibility.
- The frontend pre-submit guard from the previous gate still prevents invalid initial create statuses before calling the RPC.

Next gates:

- Review 041 before any SQL apply.
- SQL apply must be a separate explicit gate.
- After apply, run SELECT-only confirmation for RPC existence, security definer, search_path, authenticated EXECUTE, anon blocked, removed GM/admin gate, and retained initial status guard.
- Any public non-draft retry can trigger Discord create and remains a separate explicit gate.

## M-14E-26D General user create RPC apply draft review

Status: apply-preflight review only. No SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, public non-draft retry, or `updates.json` change was performed.

Review target:

- `docs/supabase/sql/041_general_user_session_post_create_rpc_apply_draft.sql`.
- 041 remains an unexecuted apply draft with `DO NOT RUN` / `NOT EXECUTED` / user approval warnings.
- Review result: ready to move to a separate SQL apply gate if the user explicitly approves and the apply-time stop conditions below remain clear.

SQL safety review:

- The draft is limited to replacing `public.create_session_post(...)`.
- No `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, `CASCADE`, standalone `DELETE`, standalone `UPDATE`, or RLS policy change was found.
- `DROP FUNCTION IF EXISTS` appears only for the current/legacy `create_session_post` signatures to avoid PostgREST overload ambiguity before recreating the target RPC.
- The intended `INSERT INTO public.sessions` appears inside the replacement function body only; it is the normal create RPC behavior and is not a standalone data mutation executed by the draft review.
- `GRANT` / `REVOKE` handling is limited to the target function execute permissions: PUBLIC/anon are revoked and authenticated is granted.
- No secret, token, Webhook URL, JWT, project ref, Supabase URL, Discord ID, post URL, user row, or raw personal identifier was recorded.

Signature / frontend compatibility:

- The RPC arguments match the existing frontend create payload shape, including `p_session_tool`.
- Existing placeholder arguments `p_level_range`, `p_request_body`, and `p_requirements` remain compatible with the current frontend payload.
- The return shape remains `session_id`, `discord_sync_status`, and `created_at`, matching the current frontend expectation.
- `discord_mention_mode` is not saved by this RPC and remains a frontend-to-Discord-sync input after successful create; this is compatible with the current mention design.
- Existing Discord sync metadata initialization is preserved.

Permission boundary review:

- Auth is still required through `auth.uid()`.
- Create-time GM/admin role gating is removed only from `create_session_post`.
- The new session creator is saved as the owner/GM via `gm_user_id = auth.uid()`.
- `update_session_post`, `delete_session_post`, close/delete/update sync RPCs, and GM manual close-mark flows are not changed by 041.
- This draft does not grant general users permission to edit, delete, close-mark, or manage other users' session posts.
- Admin management behavior remains delegated to the existing update/delete/management flows.

Input validation review:

- Initial create status remains limited to `draft` / `tentative` / `recruiting`.
- `closed` / `finished` / `canceled` remain disallowed for create.
- Existing validation for title, date/time, deadline, visibility, session type, player min/max, summary, and session tool is preserved.
- The three-choice frontend status policy remains aligned with the draft.

Apply gate stop conditions:

- Stop if the SQL file is not the reviewed 041 draft.
- Stop if the live RPC signature differs from the reviewed signature.
- Stop if the SQL Editor reports any error or unexpected warning.
- Stop if the pasted SQL is incomplete or modified unexpectedly.
- Stop if any secret, URL, token, raw ID, personal identifier, or Discord external identifier appears.
- Stop if update/delete/close permissions, RLS policies, table structure, Edge Function code, or Discord operations become necessary.

Apply-after confirmation plan:

- Confirm `create_session_post` exists with the expected signature.
- Confirm `security_definer = true`.
- Confirm search_path is set.
- Confirm authenticated EXECUTE is available and anon EXECUTE is blocked.
- Confirm the create-time GM/admin gate is removed from the live RPC body.
- Confirm the initial status guard still limits create to `draft` / `tentative` / `recruiting`.
- Confirm a logged-in general user can create a safe session post in a later explicit QA gate.
- Confirm the created session owner/GM is the actor without recording raw IDs.
- Confirm general users still cannot edit/delete/close-mark another user's session post.
- Confirm admin management remains available.
- Confirm public non-draft + `@everyone通知を送らない` creates a Discord post without `@everyone` only in a separate explicit Discord-risk gate.

Next gate:

- Run 041 SQL apply only after explicit approval.
- Keep public non-draft create retry, Discord create verification, and `@everyone通知を送る` verification as later independent gates.

## M-14E-26E General user create RPC apply result

Status: SQL apply result recording only. Codex did not execute SQL Editor, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, public non-draft retry, or `updates.json` change in this recording gate.

041 apply result:

- User ran `docs/supabase/sql/041_general_user_session_post_create_rpc_apply_draft.sql` once in Supabase SQL Editor.
- SQL Editor reported no error.
- The user did not rerun the SQL.
- No real IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, or Webhook URL were recorded.

Applied scope:

- The applied DB/RPC change is the `create_session_post` replacement from 041.
- `create_session_post` is now treated as the general logged-in user create-compatible version.
- The create-time GM/admin gate was removed by the applied RPC draft.
- The creator is stored as the owner/GM for the new session via `gm_user_id = auth.uid()`.
- Initial create status remains limited to `draft` / `tentative` / `recruiting`.
- `closed` / `finished` / `canceled` remain disallowed for create.
- `update_session_post`, `delete_session_post`, GM manual close-mark behavior, admin management boundaries, and Discord update/delete sync RPCs were outside the 041 apply scope.

Not performed in this gate:

- No post-apply SELECT-only confirmation was run by Codex.
- No general-user session-post create QA was run.
- No past-session registration, future-session registration, dry-run, Discord post/edit/delete, Edge Function deploy, secret/Webhook change, cleanup apply, or additional DB/RPC/RLS change was performed.

Next gates:

- Post-apply SELECT-only confirmation gate:
  - Confirm `create_session_post` exists.
  - Confirm `security_definer = true`.
  - Confirm search_path is set.
  - Confirm authenticated EXECUTE is available.
  - Confirm anon EXECUTE is blocked.
  - Confirm the create-time GM/admin gate is removed.
  - Confirm the initial status guard still limits create to `draft` / `tentative` / `recruiting`.
- General-user create QA gate:
  - Try a safe general-user create path using one of `draft` / `tentative` / `recruiting`.
  - If using public non-draft create, treat it as a Discord-risk gate because Discord create can be triggered.
  - Keep `@everyone通知を送らない` verification and any Discord post check as explicit follow-up gates.

## M-14E-26F General user create post-apply SELECT draft

Status: SQL draft/docs update only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, general-user create retry, public non-draft retry, or `updates.json` change was performed.

Prepared post-apply confirmation SQL:

- Added `docs/supabase/sql/042_general_user_session_post_create_post_apply_select_only.sql`.
- 042 is SELECT-only and was not executed.
- 042 is intended for the next independent SQL Editor gate after the successful 041 apply.
- 042 does not treat PostgreSQL PUBLIC as a normal role.
- 042 uses `to_regrole(...)` for `authenticated` and `anon`.
- 042 does not return real IDs, user rows, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or function body text.

042 checks:

- `create_session_post` exists.
- `security_definer` remains true.
- search_path remains configured.
- authenticated EXECUTE is available.
- anon EXECUTE is false.
- `p_session_tool` remains in the create RPC signature.
- return shape still includes `session_id`, `discord_sync_status`, and `created_at`.
- create-time GM/admin gate patterns are absent.
- creator/owner pattern ties `gm_user_id` to `auth.uid()`.
- initial status guard remains `draft` / `tentative` / `recruiting`.
- `closed` / `finished` / `canceled` are not present as initial create statuses in the create RPC body.
- `update_session_post` / `delete_session_post` still exist as presence-only checks; 041 did not target them.
- `post_apply_ready_for_general_create_qa` summarizes whether the DB/RPC state is ready for the next general-user create QA gate.

Next gates:

- Run 042 once in SQL Editor after explicit approval.
- If 042 returns `post_apply_ready_for_general_create_qa = ok / true`, proceed to a separate general-user create QA gate.
- If the QA uses public non-draft create, treat it as Discord-risk because create auto-sync can trigger a Discord post.
- Keep Discord post verification, `@everyone通知を送らない`, and `@everyone通知を送る` checks as explicit follow-up gates.

## M-14E-26G General user create post-apply SELECT result

Status: SELECT-only result recording only. Codex did not execute SQL Editor, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, general-user create retry, public non-draft retry, or `updates.json` change in this recording gate.

042 SELECT-only result:

- User ran `docs/supabase/sql/042_general_user_session_post_create_post_apply_select_only.sql` once in Supabase SQL Editor.
- SQL Editor reported no error.
- The user did not rerun the SQL.
- No additional DB/RPC/RLS change or SQL apply was performed.
- Results were shared as boolean/status values only; no real IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, or Webhook URL were recorded.

Key results:

- `authenticated_role_exists`: ok / true.
- `create_rpc_anon_execute`: ok / false.
- `create_rpc_authenticated_execute`: ok / true.
- `create_rpc_creator_owner_pattern`: ok / true.
- `create_rpc_disallowed_initial_statuses_absent`: ok / true.
- `create_rpc_exists`: ok / 1.
- `create_rpc_gm_admin_gate_removed`: ok / true.
- `create_rpc_has_search_path`: ok / true.
- `create_rpc_initial_status_guard`: ok / true.
- `create_rpc_return_shape`: ok / true.
- `create_rpc_security_definer`: ok / true.
- `create_rpc_signature_has_session_tool`: ok / true.
- `delete_session_post_exists`: ok / 1.
- `update_session_post_exists`: ok / 1.
- `post_apply_ready_for_general_create_qa`: ok / true.

Interpretation:

- The 041-applied `create_session_post` state is ready for a separate general-user create QA gate.
- authenticated users can execute the create RPC.
- anon cannot execute the create RPC.
- The create-time GM/admin gate has been removed.
- The creator/owner pattern stores the actor as GM/owner via `gm_user_id = auth.uid()`.
- Initial create status remains limited to `draft` / `tentative` / `recruiting`.
- `closed` / `finished` / `canceled` are not allowed as initial create statuses.
- `update_session_post` and `delete_session_post` still exist; 042 only confirmed presence and did not change them.

Next gate:

- Proceed to general-user create QA only after explicit approval.
- Prefer a low-risk create path first.
- If the QA uses public non-draft create, treat it as a Discord-risk gate because create auto-sync can trigger a Discord post.
- Keep past-session registration, future-session registration, Discord post verification, and mention-mode verification as explicit follow-up gates.

## M-14E-26H General user created-session permission and sync triage

Status: triage, frontend safety fix, and SELECT-only SQL draft only. No SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, additional registration, target session deletion, or `updates.json` change was performed.

Observed QA result:

- A general logged-in user could create one session post after the 041 `create_session_post` apply.
- The created session did not create a Discord post.
- The created session was later treated as no-permission for GM close mark, delete, and edit-save flows.
- The create form still appeared to expose an unwanted legacy end-state option during the attempt.
- The created session must not be deleted or retried until the permission/sync cause is isolated.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.

Code and SQL triage:

- `create_session_post` was the only RPC changed by 041. It now allows authenticated create and stores the actor as `gm_user_id`.
- Current frontend create code calls Discord auto-sync only for public, non-draft create. If the created row was public/non-draft and sync did not produce a Discord post, the likely blocker is downstream sync permission rather than the create RPC itself.
- The Edge Function checks `is_session_gm`, but the DB sync helper RPCs from the Discord create/update/delete drafts still contain the older `has_role('gm')` plus owner gate pattern.
- `check_discord_session_post_create_ready`, `record_discord_session_post_create_success`, and `record_discord_session_post_create_failure` therefore likely block a general owner who does not have the GM role.
- `update_session_post` and `delete_session_post` also still show the older `has_role('gm')` plus owner gate in the reviewed SQL history, which likely explains edit-save, delete, and GM close-mark failures for a general owner.
- Existing `is_session_gm(text)` is the safer owner/admin helper because it checks session ownership or admin without requiring the separate GM role.
- Detail UI permission still needs live confirmation: if the GM/admin management area itself shows no permission, confirm whether the created row has an owner and whether the live helper sees the browser user as session GM. SQL Editor may not have browser `auth.uid()`, so this part may remain browser/manual until a safe RPC/body check is added.

Frontend safety fix:

- New session status options remain limited to `draft` / `tentative` / `recruiting`.
- Template application in new-create mode now refuses to add unknown legacy `p_status` values as temporary options.
- Legacy status values can still be shown while editing an existing session so old data display compatibility is preserved.
- This is only a defensive UI fix; it does not change RPC permissions or Discord sync behavior.

Prepared SELECT-only diagnostics:

- Added `docs/supabase/sql/043_general_user_created_session_permission_diagnostics_select_only.sql`.
- 043 is SELECT-only and was not executed.
- Before running, the user must set the target title locally in SQL Editor; the committed file contains no target title or raw ID.
- 043 returns `check_name / status / result_value / note` only.
- 043 checks the target session match count, status, visibility, owner presence, owner profile presence, Discord sync state booleans, and old GM-role owner gate patterns in update/delete and Discord sync helper RPCs.
- 043 does not return raw session IDs, user IDs, emails, JWTs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or function bodies.

Likely next gates:

- Run 043 once in SQL Editor as an independent SELECT-only confirmation gate.
- If 043 confirms old owner gates, prepare reviewed RPC replacement drafts for:
  - `update_session_post`
  - `delete_session_post`
  - Discord create sync helper RPCs
  - Discord update/delete sync helper RPCs
- The replacement direction should be owner/admin via `is_session_gm(text)` or equivalent owner/admin logic, not GM-role plus owner.
- Apply any DB/RPC changes only in later independent SQL apply gates.
- Resume general-user registration / Discord create QA only after the owner permission and sync helper gates are resolved.

## M-14E-26I General owner permission RPC draft

Status: 043 result recording, RPC replacement draft, and docs update only. No SQL Editor execution by Codex, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, additional registration, target session deletion, or `updates.json` change was performed.

043 SELECT-only result:

- User ran `docs/supabase/sql/043_general_user_created_session_permission_diagnostics_select_only.sql` once in Supabase SQL Editor.
- The result was shared as boolean/status values only.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.
- Target session match count: ok / 1.
- Target status: `recruiting`.
- Target visibility: `public`.
- Target owner present: ok / true.
- Target owner profile present: ok / true.
- `target_owner_matches_sql_auth_uid`: unknown, because SQL Editor did not provide browser `auth.uid()`.
- Discord sync status: `pending`.
- Discord last action: `create`.
- Discord message ID saved: false.
- Discord channel ID saved: false.
- Discord post URL saved: false.
- Discord synced timestamp present: false.
- Discord sync error empty: true.

Old gate confirmation:

- `update_session_post_has_old_gm_owner_gate`: true.
- `delete_session_post_has_old_gm_owner_gate`: true.
- `check_discord_session_post_create_ready_has_old_gm_owner_gate`: true.
- `record_discord_session_post_create_success_has_old_gm_owner_gate`: true.
- `record_discord_session_post_create_failure_has_old_gm_owner_gate`: true.
- `check_discord_session_post_update_ready_has_old_gm_owner_gate`: true.
- `record_discord_session_post_update_success_has_old_gm_owner_gate`: true.
- `record_discord_session_post_update_failure_has_old_gm_owner_gate`: true.
- `check_discord_session_post_delete_ready_has_old_gm_owner_gate`: true.
- `record_discord_session_post_delete_failure_has_old_gm_owner_gate`: true.
- `owner_permission_rpc_change_needed`: true.
- `discord_create_sync_rpc_change_needed`: true.
- `discord_update_delete_sync_old_gate_count`: 5.

Interpretation:

- `create_session_post` is working for general authenticated create after the 041 apply.
- The inspected session exists and has an owner/profile, so the create row itself is present.
- Edit/save, delete, and GM close-mark failures are most likely caused by the old owner permission gate in `update_session_post` and `delete_session_post`.
- Discord create auto-sync likely stopped in DB helper RPCs rather than the Edge Function body, because `check_discord_session_post_create_ready` and `record_discord_session_post_create_*` still require GM role plus ownership.
- Discord update/delete helper RPCs have the same old gate pattern and should be updated before general-owner update/delete sync QA.
- The pending/create target session should remain as a diagnostic sample until the owner permission and Discord helper gates are resolved.

Owner/admin replacement direction:

- Do not require a fixed GM role for owner actions.
- Permit owner/admin by using existing `public.is_session_gm(text)` as the first candidate helper.
- `public.is_session_gm(text)` is defined as browser actor owns the target session or actor is admin, and requires a non-null `auth.uid()`.
- Keep anon blocked.
- Keep admin management available.
- Do not grant general users access to other users' edit/delete/close-mark actions.
- Preserve existing signatures, return shapes, validations, `security definer`, and `search_path`.
- Keep Edge Function payload and response sanitization unchanged.

Prepared apply draft:

- Added `docs/supabase/sql/044_general_owner_session_permission_rpc_apply_draft.sql`.
- 044 is an apply draft and was not executed.
- 044 contains `DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED`.
- 044 targets these RPCs only:
  - `update_session_post`
  - `delete_session_post`
  - `check_discord_session_post_create_ready`
  - `record_discord_session_post_create_success`
  - `record_discord_session_post_create_failure`
  - `check_discord_session_post_update_ready`
  - `record_discord_session_post_update_success`
  - `record_discord_session_post_update_failure`
  - `check_discord_session_post_delete_ready`
  - `record_discord_session_post_delete_failure`
- 044 was mechanically derived from the reviewed 017/018/030/031 RPC drafts.
- The old permission pattern was replaced with `coalesce(public.is_session_gm(target_session_id), false)`.
- 044 does not include table/RLS/policy changes, Edge Function changes, Discord operations, cleanup apply, secrets, Webhook URLs, JWTs, raw IDs, or Discord IDs.
- 044 keeps normal function-body writes that are part of the existing RPC behavior, such as session update/delete and Discord sync state recording. It does not add standalone cleanup or unrelated mutation statements.
- Existing EXECUTE grants are expected to remain because the targeted signatures are unchanged; 044 does not add new GRANT/REVOKE statements.

Apply-after checks for a later gate:

- Each target RPC exists with `security_definer = true` and search_path set.
- authenticated can execute and anon cannot execute.
- Old `has_role('gm') + owner` gate is absent from all target RPCs.
- `is_session_gm(...)` owner/admin pattern is present.
- General owner can edit, delete, and close-mark own session.
- General owner cannot edit/delete/close-mark another user's session.
- admin can still manage sessions.
- Discord create ready/record can run for a general-owner-created session.
- Discord update/delete ready/record can run for a general-owner-created session.
- The current pending/create diagnostic target is handled only in a later explicit gate.

Next gates:

- Review 044 before apply.
- Apply 044 only in an independent SQL apply gate after explicit approval.
- After apply, run SELECT-only post-apply confirmation before retrying the target session, registration QA, Discord sync QA, or cleanup.

## M-14E-26J General owner permission RPC apply draft review

Status: SQL apply pre-review only. No SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session deletion, additional registration, or `updates.json` change was performed.

Review target:

- `docs/supabase/sql/044_general_owner_session_permission_rpc_apply_draft.sql`.
- 044 keeps `DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED` notes.
- 044 remains an apply draft and has not been executed.

SQL safety review:

- Target RPC count: 10.
- Target RPCs:
  - `update_session_post`
  - `delete_session_post`
  - `check_discord_session_post_create_ready`
  - `record_discord_session_post_create_success`
  - `record_discord_session_post_create_failure`
  - `check_discord_session_post_update_ready`
  - `record_discord_session_post_update_success`
  - `record_discord_session_post_update_failure`
  - `check_discord_session_post_delete_ready`
  - `record_discord_session_post_delete_failure`
- No `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, `ALTER`, `GRANT`, or `REVOKE` statements were found.
- No table/RLS/policy changes were found.
- No secret, token, JWT, Webhook URL, Supabase URL, raw ID, Discord ID, post URL, or message preview body was found.
- `CASCADE` appears only in an inherited explanatory comment for existing session delete dependencies.
- `UPDATE public.sessions` and `DELETE FROM public.sessions` appear only inside the existing RPC bodies as the normal update/delete/sync-state behavior. They are not standalone cleanup or unrelated mutation statements.
- Existing EXECUTE privileges are expected to be retained because 044 uses `CREATE OR REPLACE FUNCTION` with unchanged signatures and does not recreate different signatures.

RPC compatibility review:

- 044 preserves the existing function names, signatures, return shapes, validation flow, `security definer`, and `search_path`.
- The frontend and Edge Function call targets remain unchanged.
- `update_session_post` still returns session update metadata expected by the frontend.
- `delete_session_post` still returns delete metadata expected by the frontend.
- Discord create/update/delete helper RPC return shapes remain aligned with the existing Edge Function calls.
- Existing Discord external identifier handling remains unchanged; the draft only changes owner/admin permission gates.
- `discord_mention_mode` is not part of these DB helper RPCs and requires no DB-side change here.

Permission boundary review:

- The old execution gate pattern requiring `has_role('gm')` plus ownership is absent from the target RPC bodies.
- The replacement gate uses `coalesce(public.is_session_gm(target_session_id), false)`.
- `public.is_session_gm(text)` is defined as `auth.uid()` present and either target session owner or admin.
- Because `is_session_gm` requires non-null `auth.uid()`, anon remains blocked.
- General owners should be allowed to edit/delete/close-mark/sync-helper their own sessions after apply.
- General users should not be allowed to operate on other users' sessions, because `is_session_gm` checks the target session's `gm_user_id`.
- Admin management remains available through the helper.

Discord sync helper review:

- `check_discord_session_post_create_ready` should become callable for general-owner-created sessions.
- `record_discord_session_post_create_success/failure` should be able to record create sync results for general-owner-created sessions.
- Update/delete sync ready and record helpers follow the same owner/admin gate.
- Edge Function body, payload shape, sanitized response handling, and message preview policy do not need to change for this draft.
- Discord posting/edit/delete is still a later explicit QA gate.

Known caution:

- 044 is a broad RPC replacement across ten functions. It should be applied only after explicit approval and only if the live signatures still match the reviewed draft.
- The current pending/create diagnostic session should not be deleted before the owner-permission and Discord helper gates are confirmed.
- Applying 044 does not by itself recover the existing pending/create Discord sync state; resync/repair handling is a later gate.

Apply-after confirmation plan:

- Run a SELECT-only post-apply confirmation that checks all ten target RPCs.
- Confirm each target RPC exists with `security_definer = true` and search_path set.
- Confirm authenticated EXECUTE is available and anon is blocked.
- Confirm old `has_role('gm') + owner` gate is absent from all target RPCs.
- Confirm `is_session_gm(...)` pattern is present in all target RPCs.
- Confirm a general owner can edit-save the diagnostic target.
- Confirm a general owner can use the manual close mark on the diagnostic target.
- Defer delete QA until the diagnostic target is no longer needed, because delete removes the sample.
- Confirm a general owner cannot edit/delete/close-mark another user's session.
- Confirm admin management still works.
- Confirm Discord create/update/delete helper behavior only in later explicit Discord-risk gates.

Review conclusion:

- 044 is suitable to move to a separate SQL apply gate, provided the user explicitly approves the apply and no live signature mismatch is discovered.
- SQL apply, DB changes, Discord operations, and target-session cleanup remain unperformed in this review gate.

## M-14E-26K update_session_post overload diagnostics draft

Status: SELECT-only SQL draft and docs update only. No SQL Editor execution by Codex, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session delete/edit/close-mark, additional registration, or `updates.json` change was performed.

Observed after 044 apply:

- User reported that the post-044 result showed two `update_session_post` rows.
- One `update_session_post` row appeared to still contain the old GM-role owner gate.
- Because edit-save and GM close-mark could call an old overload, registration, edit QA, close-mark QA, and Discord sync QA remain stopped.
- 044 must not be rerun.
- The diagnostic target session must not be deleted while this overload/signature issue is unresolved.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.

Frontend call context:

- Current `assets/js/renderSessionPost.js` update payload calls `update_session_post` with named parameters including `p_session_tool`.
- The current frontend payload expects these named inputs:
  - `p_session_id`
  - `p_title`
  - `p_session_date`
  - `p_start_time`
  - `p_end_time`
  - `p_application_deadline`
  - `p_session_type`
  - `p_player_min`
  - `p_player_max`
  - `p_summary`
  - `p_visibility`
  - `p_status`
  - `p_end_at`
  - `p_session_tool`
- A legacy overload without `p_session_tool` may be harmless for the current frontend, but it still needs confirmation because multiple overloads can create PostgREST/RPC ambiguity or leave stale callable paths.

Prepared SELECT-only diagnostics:

- Added `docs/supabase/sql/045_update_session_post_overload_diagnostics_select_only.sql`.
- 045 is SELECT-only and was not executed.
- 045 does not include `DROP`, `CREATE`, `ALTER`, `UPDATE`, `DELETE`, `INSERT`, `GRANT`, `REVOKE`, or `TRUNCATE` statements.
- 045 does not return function bodies.
- 045 returns `check_name / status / result_value / note` rows.
- 045 checks:
  - `update_session_post` overload count.
  - Each overload signature and identity arguments.
  - Input argument count.
  - Whether each overload has `p_session_tool`.
  - Whether each overload matches the current frontend payload keys.
  - Whether each overload still has the old `has_role('gm') + owner` gate.
  - Whether each overload uses `is_session_gm`.
  - `security_definer` and search_path.
  - authenticated/anon EXECUTE booleans.
  - Whether overload cleanup is likely needed before edit/close-mark QA.

Next gate:

- Run 045 once in SQL Editor as an independent SELECT-only confirmation gate.
- If the frontend-matching overload still has the old gate, prepare a corrective apply draft before any edit/close-mark QA.
- If only a legacy non-frontend overload has the old gate, decide whether to remove/replace it with a focused cleanup draft before QA.
- Do not retry registration, edit-save, close-mark, Discord sync, or target cleanup until the overload result is understood.

## M-14E-26L update_session_post overload diagnostics SQL fix

Status: 045 failure recording and SELECT-only SQL fix only. No SQL Editor execution by Codex, 045 rerun, 044 rerun, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, or `updates.json` change was performed.

045 result:

- User ran `docs/supabase/sql/045_update_session_post_overload_diagnostics_select_only.sql` once in Supabase SQL Editor.
- 045 stopped with `ERROR: 42703: column "frontend_matching_old_gate_count" does not exist`.
- The likely cause is a diagnostic SQL alias/scope issue, not a DB mutation.
- The user did not rerun 045.
- No DB change occurred from the failed SELECT-only diagnostic.
- 044 was not rerun.
- Target session edit-save, close-mark, delete, and Discord sync checks remain stopped.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.

Prepared fix:

- Added `docs/supabase/sql/046_update_session_post_overload_diagnostics_select_only_fix.sql`.
- 046 is SELECT-only and has not been executed.
- 046 keeps the `check_name / status / result_value / note` result shape.
- 046 does not return function bodies; it returns signatures, argument summaries, and pattern booleans only.
- 046 computes aggregate values such as `frontend_matching_old_gate_count` inside dedicated `summary_counts` / `summary_flags` CTEs before downstream checks reference them.
- 046 avoids same-level alias reuse that can fail in PostgreSQL scope rules.
- 046 still checks:
  - `update_session_post_overload_count`.
  - `frontend_matching_overload_count`.
  - `frontend_matching_old_gate_count`.
  - `old_gate_overload_count`.
  - `legacy_without_session_tool_count`.
  - `overload_cleanup_needed`.
  - `frontend_call_risk`.
  - Each overload signature and identity arguments.
  - Each overload frontend payload match.
  - Each overload old GM-owner gate pattern.
  - Each overload `is_session_gm` pattern.
  - authenticated/anon EXECUTE booleans.

Next gate:

- Run 046 once in SQL Editor as an independent SELECT-only confirmation gate.
- If 046 errors, stop without rerun.
- If 046 confirms a frontend-matching old gate or ambiguous callable overload, prepare a focused cleanup/replace apply draft before edit-save, close-mark, delete, registration, or Discord sync QA.
- Continue to keep 044 rerun, SQL apply, target session operations, and Discord operations stopped until the overload result is understood.

## M-14E-26M update_session_post frontend overload apply draft

Status: 046 result recording and SQL apply draft creation only. No SQL Editor execution by Codex, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, or `updates.json` change was performed.

046 result summary:

- User ran 046 once in Supabase SQL Editor and shared the boolean/status summary.
- Codex did not operate SQL Editor.
- No 046 rerun was performed.
- `update_session_post_overload_count = 2`.
- `frontend_matching_overload_count = 1`.
- `frontend_matching_old_gate_count = 1`.
- `old_gate_overload_count = 1`.
- `legacy_without_session_tool_count = 1`.
- `overload_cleanup_needed = true`.
- `frontend_call_risk = frontend_matching_old_gate`.
- `anon_execute_overload_count = 1`.
- 044 was not rerun.
- 045 was not rerun.
- No DB/RPC/RLS additional change, SQL apply, target session operation, or Discord operation was performed in this recording/draft gate.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.

Interpretation:

- The overload that contains `p_session_tool` matches the current frontend update payload.
- That frontend-matching overload still has the old `has_role('gm') + owner` gate and does not use `is_session_gm`.
- This explains why edit-save and GM manual close-mark can still fail for a general owner after the 044 apply.
- The owner/admin rewrite applied by 044 appears to have landed on the legacy overload without `p_session_tool`, which the current frontend does not call.
- The legacy overload is not a current frontend match, but it remains a cleanup concern because it lacks `p_session_tool` and is reported as anon-executable.

Current frontend call context:

- `assets/js/renderSessionPost.js` builds the edit-save payload with `p_session_tool`.
- `assets/js/renderSessionDetail.js` builds the GM close-mark title-update payload with `p_session_tool`.
- `assets/js/discordSyncClient.js` update sync runs after a successful edit/close update and does not change the `update_session_post` RPC signature.
- Current public JS is expected to use the `p_session_tool` overload after cache-busted release; old cached clients should be refreshed before the apply/QA gate.

Prepared apply draft:

- Added `docs/supabase/sql/047_update_session_post_frontend_overload_apply_draft.sql`.
- 047 is an apply draft with `DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED`.
- 047 has not been executed.
- 047 targets `update_session_post` only.
- 047 replaces the 14-input `p_session_tool` overload with the same signature, return shape, validation flow, `security definer`, and `search_path`.
- 047 changes the permission gate for that frontend-matching overload to `coalesce(public.is_session_gm(p_session_id), false)`.
- 047 keeps authenticated EXECUTE and explicitly revokes public/anon EXECUTE for the 14-input overload.
- 047 drops the legacy 13-input `update_session_post` overload without `CASCADE` because it is not the current frontend target and was reported as an anon-executable cleanup risk.
- 047 does not change `delete_session_post`, Discord helper RPCs, RLS/policies, Edge Function code, or Discord behavior.

Apply-after confirmation plan:

- Run 046 again, or a focused 048 SELECT-only post-apply confirmation, after 047 apply.
- Confirm `update_session_post_overload_count` is reduced to the expected safe state.
- Confirm the frontend-matching overload has `is_session_gm` pattern.
- Confirm the frontend-matching overload has no old GM-owner gate.
- Confirm authenticated EXECUTE is available.
- Confirm anon EXECUTE is false.
- Confirm the legacy overload is removed or no longer callable.
- Confirm a general owner can edit-save the diagnostic session.
- Confirm a general owner can use the GM manual close-mark flow.
- Confirm a general owner cannot edit or close-mark another user's session.
- Defer delete and Discord update sync confirmation to later explicit gates.

Next gate:

- Review 047 before apply.
- If review passes, run 047 once in SQL Editor as an independent DB/RPC change gate.
- Keep additional registration, edit-save, close-mark, delete, Discord sync, dry-run, Edge Function deploy, and secret/Webhook changes stopped until 047 is applied and confirmed.

## M-14E-26N update_session_post frontend overload apply draft review

Status: SQL apply pre-review only. No SQL Editor execution, SQL apply, DB/RPC/RLS change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, or `updates.json` change was performed.

Review target:

- `docs/supabase/sql/047_update_session_post_frontend_overload_apply_draft.sql`.
- 047 remains `DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED`.
- 047 has not been executed.

Frontend signature alignment:

- Current `assets/js/renderSessionPost.js` edit-save payload includes:
  - `p_session_id`
  - `p_title`
  - `p_session_date`
  - `p_start_time`
  - `p_end_time`
  - `p_application_deadline`
  - `p_session_type`
  - `p_player_min`
  - `p_player_max`
  - `p_summary`
  - `p_visibility`
  - `p_status`
  - `p_end_at`
  - `p_session_tool`
- Current `assets/js/renderSessionDetail.js` GM close-mark title-update payload also includes `p_session_tool`.
- Therefore the current frontend matches the 14-input `update_session_post` overload, not the legacy 13-input overload.
- `assets/js/discordSyncClient.js` update sync runs after a successful edit/close update and does not change the `update_session_post` RPC signature.

047 review result:

- 047 targets `update_session_post` only.
- The 14-input `p_session_tool` overload signature matches the current frontend payload.
- The executable function body uses `coalesce(public.is_session_gm(v_session_id), false)` for owner/admin permission.
- The old `has_role('gm') + owner` gate is not present in the executable function body; it appears only in review comments describing the previous pattern.
- `security definer` and `set search_path = ''` are preserved.
- Existing validation for title, date/time, visibility, status, player range, summary, and `session_tool` is preserved from the session-tool-aware draft.
- Return shape remains `session_id`, `discord_sync_status`, `discord_last_action`, `updated_at`.
- `session_tool` update behavior is preserved: omitted `p_session_tool` keeps the existing value, empty text clears to null, and newline/length validation remains.
- Discord update/create/delete pending-state metadata behavior is preserved and no Edge Function contract change is introduced.
- General owners should be able to edit-save and GM close-mark only their own sessions through `is_session_gm`.
- Other users should still be rejected because `is_session_gm` is expected to mean owner-or-admin for the target session.
- Admin management remains covered by `is_session_gm` helper semantics.

Legacy overload review:

- The legacy 13-input overload lacks `p_session_tool` and does not match the current frontend payload.
- 046 reported the legacy overload as anon-executable, so leaving it in place is an avoidable risk.
- 047 explicitly drops only the legacy `update_session_post(text,text,text,text,text,text,text,integer,integer,text,text,text,text)` overload.
- The legacy DROP is signature-specific and uses no `CASCADE`.
- Dropping the legacy overload is acceptable for the next apply gate because the current cache-busted frontend sends `p_session_tool`; stale browsers should refresh before QA.

SQL safety review:

- No `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, `ALTER TABLE`, standalone `DELETE`, or standalone `UPDATE` was found.
- The only `UPDATE public.sessions` is inside the reviewed RPC body and is the intended edit-save behavior.
- The only `DROP FUNCTION` is the legacy `update_session_post` 13-input overload cleanup.
- `CASCADE` is present only in the comment that says it must not be used.
- No RLS/policy changes are included.
- `REVOKE`/`GRANT` are present and necessary to close public/anon execute on the 14-input overload and keep authenticated execute.
- No secret, token, JWT, Webhook URL, Supabase URL, Discord ID, raw user ID, email, session ID, or message preview body was recorded.

Review conclusion:

- 047 is suitable to move to a separate SQL apply gate, provided the user explicitly approves the apply and the SQL Editor content is exactly this file.
- If SQL Editor reports any error, stop without rerun.
- Do not retry edit-save, close-mark, delete, registration, or Discord sync before 047 is applied and confirmed.
- Keep the diagnostic target session undeleted until the owner-permission path is confirmed.

Apply-after confirmation plan:

- Run 046 again or prepare/run a focused 048 SELECT-only confirmation after 047 apply.
- Confirm the frontend-matching 14-input overload uses `is_session_gm`.
- Confirm the frontend-matching overload has no old GM-owner gate.
- Confirm `frontend_matching_old_gate_count = 0`.
- Confirm `old_gate_overload_count = 0`.
- Confirm `anon_execute_overload_count = 0`.
- Confirm the legacy 13-input overload is gone or otherwise not callable.
- Confirm authenticated execute remains available.
- Confirm general owner edit-save works on the diagnostic session.
- Confirm general owner close-mark works on the diagnostic session.
- Confirm another user cannot edit or close-mark the diagnostic session.
- Defer target deletion and Discord update sync confirmation to later explicit gates.

Next gate:

- 047 SQL apply independent gate.
- SQL Editor old content must be cleared before pasting 047.
- Execute 047 once only.
- Record success/failure and do not rerun on error.

## M-14E-26O update_session_post frontend overload apply result

Status: SQL apply result recording only. Codex did not execute SQL Editor, SQL apply, DB/RPC/RLS additional change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, cleanup, or `updates.json` change in this recording gate.

047 apply result:

- User ran `docs/supabase/sql/047_update_session_post_frontend_overload_apply_draft.sql` once in Supabase SQL Editor.
- SQL Editor execution was performed on the user's side only.
- Codex did not operate SQL Editor.
- Error: none reported.
- Rerun: none.
- 044 was not rerun.
- 045 was not rerun.
- Target session was not edited, close-marked, deleted, or resynced.
- No Discord post/edit/delete was performed.
- No dry-run false, Edge Function deploy, or secret/Webhook change was performed.
- No raw IDs, user IDs, emails, JWTs, session IDs, Supabase URL, project ref, Discord IDs, post URLs, Webhook URL, or message preview body were recorded.

Applied scope, as reported:

- The frontend-matching 14-input `update_session_post` overload with `p_session_tool` is treated as applied.
- That overload should now use `public.is_session_gm(v_session_id)` as the owner/admin gate.
- The old GM-role owner gate should be removed from the frontend-matching overload.
- The legacy 13-input `update_session_post` overload without `p_session_tool` is treated as removed by signature-specific `DROP FUNCTION` without `CASCADE`.
- The 14-input overload public/anon execute closure and authenticated execute grant are treated as applied.
- `delete_session_post`, Discord helper RPCs, RLS/policies, Edge Function code, and Discord behavior were outside the 047 apply scope.

Post-apply confirmation needed:

- Create or reuse a SELECT-only confirmation for the post-047 state before target session edit-save or close-mark QA.
- Confirm `update_session_post` overload count.
- Confirm the frontend-matching 14-input signature exists.
- Confirm the frontend-matching 14-input signature uses `is_session_gm`.
- Confirm the frontend-matching 14-input signature has no old GM-role owner gate.
- Confirm the legacy 13-input overload is gone or otherwise not callable.
- Confirm anon execute overload count is 0.
- Confirm authenticated execute remains available.
- Confirm `security_definer` and search_path are preserved.
- After SELECT-only confirmation, test general owner edit-save on the diagnostic session.
- After edit-save confirmation, test general owner GM close-mark on the diagnostic session.
- Confirm another user cannot edit or close-mark the diagnostic session.
- Defer target deletion and Discord update/create repair or resync confirmation to later explicit gates.

Next gate:

- Prepare a focused post-047 SELECT-only confirmation SQL, or explicitly rerun the existing 046 SELECT-only diagnostic if it is still suitable.
- Do not proceed to edit-save, close-mark, delete, Discord sync, additional registration, dry-run false, Edge deploy, or secret/Webhook changes until the post-apply SELECT-only confirmation is reviewed.

## M-14E-26P update_session_post post-apply SELECT-only SQL

Status: SELECT-only SQL draft and docs update only. No SQL Editor execution, SQL apply, DB/RPC/RLS additional change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, cleanup, or `updates.json` change was performed.

Prepared SELECT-only confirmation:

- Added `docs/supabase/sql/048_update_session_post_overload_post_apply_select_only.sql`.
- 048 is SELECT-only and has not been executed.
- 048 keeps the `check_name / status / result_value / note` result shape.
- 048 does not return function bodies; it returns signatures, argument summaries, and pattern booleans only.
- 048 computes aggregate values in dedicated CTEs and avoids same-level alias reuse.
- 048 does not include `DROP`, `CREATE`, `ALTER`, `UPDATE`, `DELETE`, `INSERT`, `GRANT`, `REVOKE`, or `TRUNCATE` statements.

048 checks:

- `update_session_post_overload_count`.
- `frontend_matching_overload_count`.
- `frontend_matching_is_session_gm_count`.
- `frontend_matching_old_gate_count`.
- `frontend_matching_authenticated_execute_count`.
- `frontend_matching_anon_execute_count`.
- `old_gate_overload_count`.
- `legacy_without_session_tool_count`.
- `anon_execute_overload_count`.
- `security_definer_overload_count`.
- `search_path_overload_count`.
- `frontend_call_risk`.
- `post_apply_ready_for_owner_update_qa`.
- Each remaining overload signature and identity arguments.
- Each remaining overload frontend payload match.
- Each remaining overload old GM-owner gate pattern.
- Each remaining overload `is_session_gm` pattern.
- Each remaining overload authenticated/anon EXECUTE booleans.

Expected interpretation:

- Ready state should have exactly one frontend-matching 14-input overload.
- The frontend-matching overload should use `is_session_gm`.
- The frontend-matching overload should have no old GM-role owner gate.
- Legacy 13-input overload count should be 0.
- anon executable overload count should be 0.
- authenticated execute should remain available.
- `security_definer` and search_path should remain set.

Next gate:

- Run 048 once in SQL Editor as an independent SELECT-only confirmation gate.
- If 048 errors, stop without rerun.
- If 048 returns `post_apply_ready_for_owner_update_qa = true`, proceed to general-owner edit-save and GM close-mark QA in a later gate.
- Keep target deletion, Discord sync recovery/resync, Discord post/edit/delete, dry-run false, Edge deploy, and secret/Webhook changes as later explicit gates.

## M-14E-26Q update_session_post post-apply SELECT-only SQL fix

Status: 048 failure record and replacement SELECT-only SQL draft only. No SQL Editor rerun, SQL apply, DB/RPC/RLS additional change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, cleanup, or `updates.json` change was performed.

048 SQL Editor result reported by the user:

- `docs/supabase/sql/048_update_session_post_overload_post_apply_select_only.sql` was executed once in the user's SQL Editor.
- Error: `ERROR: 42703` for missing `note` column at the final output.
- The user did not rerun 048.
- No DB change occurred.
- 047 was not rerun.
- Target session edit-save, close-mark, delete, Discord sync, and Discord operation checks remain stopped.

Cause handling:

- The issue is treated as a diagnostic SQL shape problem, not as a DB/RPC state problem.
- The likely cause is that the output CTE/UNION did not guarantee a `note` column name in every final-output scope.
- 048 is kept as the failed diagnostic record and was not overwritten.

Prepared replacement SELECT-only SQL:

- Added `docs/supabase/sql/049_update_session_post_overload_post_apply_select_only_fix.sql`.
- 049 is SELECT-only and has not been executed.
- 049 explicitly declares `checks(check_name, status, result_value, note)`.
- 049 explicitly declares `overload_rows(check_name, status, result_value, note)`.
- 049 explicitly declares `final_rows(check_name, status, result_value, note)`.
- Every `UNION ALL` branch returns the same four columns in the same order.
- The final SELECT reads `check_name / status / result_value / note` from `final_rows`.
- 049 does not return function bodies; it returns signatures, argument summaries, and pattern booleans only.
- 049 keeps aggregate values in dedicated CTEs and avoids same-level alias reuse.
- 049 does not include `DROP`, `CREATE`, `ALTER`, `UPDATE`, `DELETE`, `INSERT`, `GRANT`, `REVOKE`, or `TRUNCATE` statements.

049 checks:

- `update_session_post_overload_count`.
- `frontend_matching_overload_count`.
- `frontend_matching_is_session_gm_count`.
- `frontend_matching_old_gate_count`.
- `frontend_matching_authenticated_execute_count`.
- `frontend_matching_anon_execute_count`.
- `old_gate_overload_count`.
- `legacy_without_session_tool_count`.
- `anon_execute_overload_count`.
- `security_definer_overload_count`.
- `search_path_overload_count`.
- `frontend_call_risk`.
- `post_apply_ready_for_owner_update_qa`.
- Each remaining overload signature and identity arguments.
- Each remaining overload frontend payload match.
- Each remaining overload old GM-owner gate pattern.
- Each remaining overload `is_session_gm` pattern.
- Each remaining overload authenticated/anon EXECUTE booleans.

Next gate:

- Run 049 once in SQL Editor as an independent SELECT-only confirmation gate.
- If 049 errors, stop without rerun.
- If 049 returns `post_apply_ready_for_owner_update_qa = true`, proceed to general-owner edit-save and GM close-mark QA in a later gate.
- Keep target deletion, Discord sync recovery/resync, Discord post/edit/delete, dry-run false, Edge deploy, and secret/Webhook changes as later explicit gates.

## M-14E-26R update_session_post post-apply SELECT-only result

Status: 049 SELECT-only result record only. No Codex-side SQL Editor execution, SQL apply, DB/RPC/RLS additional change, Edge Function deploy, dry-run, Discord post/edit/delete, secret/Webhook change, target session edit/close/delete, additional registration, cleanup, or `updates.json` change was performed.

049 SQL Editor result reported by the user:

- `docs/supabase/sql/049_update_session_post_overload_post_apply_select_only_fix.sql` was executed once in the user's SQL Editor.
- Error: none reported.
- Rerun: none.
- DB/RPC additional change: none.
- SQL apply: none.
- Codex did not operate SQL Editor.

Main SELECT-only results:

- `update_session_post_overload_count`: `ok / 1`.
- `frontend_matching_overload_count`: `ok / 1`.
- `frontend_matching_old_gate_count`: `ok / 0`.
- `old_gate_overload_count`: `ok / 0`.
- `legacy_without_session_tool_count`: `ok / 0`.
- `anon_execute_overload_count`: `ok / 0`.
- `frontend_call_risk`: `ok / ready_for_owner_update_qa`.
- `post_apply_ready_for_owner_update_qa`: `ok / true`.

Remaining overload summary:

- One frontend-matching 14-input overload remains.
- The remaining overload includes `p_session_tool`.
- The remaining overload matches the current frontend update payload.
- authenticated execution is available.
- anon execution is not available.
- `public.is_session_gm` owner/admin pattern is present.
- The old GM-role owner gate is absent.
- `security_definer` is preserved.
- search_path is preserved.

Conclusion:

- The post-047 `update_session_post` overload state is ready for general-owner edit-save and GM close-mark QA.
- The frontend-matching overload is treated as replaced with the owner/admin gate.
- The legacy 13-input overload is treated as cleaned up.
- No anon-executable `update_session_post` overload remains.
- Target session edit-save and GM close-mark QA can proceed in the next gate.

Still deferred:

- Target session deletion.
- Discord sync recovery or resync.
- Discord post/edit/delete.
- dry-run false.
- Edge Function deploy.
- secret/Webhook changes.
- Additional session registration.

Next gate:

- Use the diagnostic target session to verify general-owner edit-save.
- Then verify general-owner GM close-mark on the same target if edit-save passes.
- Keep Discord sync recovery/resync and any Discord operation as later explicit gates.

## M-14E-27 Discord scheduled-post MVP low-risk preparation (superseded)

Status: frontend skeleton, docs, and SQL apply draft only. No SQL Editor execution, DB/RPC/RLS apply, Edge Function deploy, Discord post, dry_run=false, secret setting, Webhook value recording, raw external channel value recording, or `updates.json` change was performed.

Superseded preparation:

- A first low-risk scheduled-post skeleton was prepared before the scope was corrected.
- That generic direction is no longer the active implementation plan.
- The active files and names are now recorded under M-14E-27A and later entries as admin-only cap announcement work.
- Page-scoped UI styling and future RPC payload-preview concepts were retained only where they fit the admin cap announcement scope.

Design notes:

- Webhook credentials and real channel routing values remain outside browser JS, docs, and DB draft content.
- The UI uses logical `channel_key` values only.
- `mention_mode=none` maps to `allowed_mentions.parse=[]`.
- `mention_mode=everyone` is the only path that allows the everyone parse value.
- Static JS does not add Supabase direct insert/update/delete/upsert calls.
- Current admin cap announcement screen does not execute DB save; it validates input and displays the future admin-only create RPC payload only.

Deferred dangerous gates:

- SQL Editor execution.
- DB/RPC/RLS schema apply.
- Future create/update/cancel/list RPC implementation apply.
- Edge Function implementation and deploy.
- cron setup.
- Discord dry-run checks.
- Discord real send.
- secret/Webhook configuration.

Next SQL apply gate:

- The superseded generic scheduled-post draft must not be applied.
- Use only the admin cap announcement SQL draft named in M-14E-27A or later.
- Stop without rerun on any SQL error.
- After apply, run the matching SELECT-only confirmation for table existence, status CHECK, mention_mode CHECK, RLS state, grants, and admin-only RPC policy.

## M-14E-27A admin cap announcement direction change

Status: direction change, rename, frontend skeleton update, docs update, and SQL apply draft replacement only. No SQL Editor execution, DB/RPC/RLS apply, Edge Function deploy, Discord post, dry_run=false, secret setting/change, Webhook URL recording, JWT/Supabase URL/Discord ID/token recording, or `updates.json` change was performed.

Direction change:

- The earlier Discord scheduled-post idea is no longer a general reminder feature.
- The scope is now limited to admin-only Discord scheduled posting for cap update announcements.
- GM/PL-created reminders, table/session reminders, general user creation, free-form multi-purpose scheduled posting, Discord Bot slash commands, and channel/Webhook URL free input are out of scope.

Renamed and updated:

- The direct-access page is now `admin-cap-announcements.html`.
- The render module is now `assets/js/renderAdminCapAnnouncements.js`.
- The future RPC client module is now `assets/js/adminCapAnnouncementClient.js`.
- The plan doc is now `docs/discord-cap-announcement-plan.md`.
- The SQL apply draft is now `docs/supabase/sql/050_admin_discord_announcements_schema_apply_draft.sql`.
- SQL table candidate is now `admin_discord_announcements`.

Admin-only design:

- `admin-cap-announcements.html` checks Supabase runtime config, login session, and `is_admin()` before showing the form.
- If non-admin or not logged in opens the URL directly, the page displays an unavailable/no-permission state and leaves the form hidden.
- `mypage` adds a small admin-only folded details link to `admin-cap-announcements.html` only when `is_admin()` returns true.
- Frontend hiding is not treated as security. DB/RPC/Edge Function gates must also verify admin authority.
- Future create/update/cancel/list RPCs must be authenticated admin only.
- Future Edge Function claim/finalize path must validate the admin announcement table, `announcement_type='cap_update'`, `target_channel_key='cap_announcement'`, and safe status transitions.

Announcement model:

- Required MVP fields: announcement title, announcement body, scheduled time, target channel key, mention mode, and status.
- Status values: `draft`, `scheduled`, `processing`, `posted`, `failed`, `canceled`.
- Failure handling keeps generalized delivery error fields so admin UI can show whether an error exists without exposing raw external response details.
- `target_channel_key` stores only logical routing such as `cap_announcement`.
- Edge Function secret/env mapping candidate is `DISCORD_WEBHOOK_CAP_ANNOUNCEMENT`; only the name is recorded, not the value.

Mention policy:

- `mention_mode=none` means Discord delivery must use `allowed_mentions.parse=[]`.
- `mention_mode=everyone` is the only mode that may prepend/use `@everyone` and set `allowed_mentions.parse=["everyone"]`.
- users/roles parse remains out of scope for the MVP.

Next gates:

- SQL apply gate: review `050_admin_discord_announcements_schema_apply_draft.sql`, then run it once only if explicitly approved.
- After SQL apply, prepare SELECT-only confirmation for table, CHECK constraints, RLS, grants, admin-only SELECT/RPC behavior, and absence of direct public write paths.
- Edge Function draft gate: design the Webhook mapping, claim/finalize RPC contract, allowed_mentions behavior, retry/failure recording, and no-secret logging before any deploy.

## M-14E-27B admin cap announcement SQL-apply preflight batch

Status: SQL Apply前の非破壊準備のみ。No SQL Editor execution, DB/RPC/RLS apply, Edge Function deploy, Discord post, real send, secret/env setting or change, Webhook value recording, JWT/Supabase URL/Discord ID/token recording, production channel post, `updates.json` change, `deno.lock` change, or `supabase/.temp` change was performed.

Baseline note:

- `4b56ff2 Refocus Discord scheduling on admin cap announcements` is an ancestor of the current branch.
- The current HEAD at this batch start was newer than that baseline, so the batch was applied on top of the existing clean tree without reverting later user/repo changes.

Scope confirmation:

- The active feature remains admin-only cap update announcement scheduling.
- It is not a general reminder feature, not a table/session reminder feature, not a GM/PL free reminder feature, and not a Discord Bot slash command feature.
- Public navigation does not expose the admin cap announcement page.
- `mypage` shows the link only after `is_admin()` returns true.
- Direct URL access by a non-admin or logged-out user keeps the form hidden and shows an unavailable/no-permission state.
- Frontend gating is only UX; DB/RPC/Edge Function gates must enforce admin/server authority.

Prepared files:

- Reviewed and tightened `docs/supabase/sql/050_admin_discord_announcements_schema_apply_draft.sql` as DO NOT RUN / NOT EXECUTED.
- Added `docs/supabase/sql/051_admin_discord_announcements_post_apply_select_only.sql` as SELECT-only post-apply confirmation.
- Added `supabase/functions/dispatch-admin-cap-announcements/index.ts` as a not-deployed Edge Function draft.
- Updated `docs/discord-cap-announcement-plan.md` with the pre-apply batch, 051 confirmation, and Edge Function draft notes.
- Cleaned backlog wording so the active implementation names point to admin cap announcement files, not the superseded generic direction.

050 SQL draft review result:

- Table candidate remains `admin_discord_announcements`.
- `announcement_type` is fixed to `cap_update`.
- `target_channel_key` is fixed to logical `cap_announcement`; Webhook URL values are not stored in DB.
- `mention_mode` remains `none` / `everyone`.
- `status` remains `draft` / `scheduled` / `processing` / `posted` / `failed` / `canceled`.
- RLS is enabled with admin SELECT policy notes.
- Direct browser table writes remain out of scope; create/update/cancel/list must go through admin-only RPC.
- claim/finalize RPCs are documented as server-only boundaries for Edge Function use.

051 SELECT-only confirmation design:

- Returns `check_name / status / result_value / note`.
- Checks table existence, status CHECK, mention_mode CHECK, announcement_type CHECK, target_channel_key CHECK, RLS, admin SELECT policy, direct write policy absence, anon table privileges, authenticated table privileges, browser admin RPC presence, server RPC presence, security definer, search_path, execute privileges, and admin-check patterns.
- Uses function definitions only internally for boolean pattern checks and does not return full function bodies.
- Does not return real IDs, Webhook URLs, Discord IDs, JWTs, token values, Supabase project URLs, or row data.

Edge Function draft design:

- Draft path: `supabase/functions/dispatch-admin-cap-announcements/index.ts`.
- Default request behavior is dry-run style and returns planned RPC order without DB mutation or Discord request.
- Future real send path is guarded by explicit env/secret configuration and cron authorization; this batch did not enable either.
- Real delivery design calls `claim_due_admin_discord_announcements` before any Discord request, so claimed rows move to `processing` with `lock_token` for double-post prevention.
- Delivery finalization calls `finalize_admin_discord_announcement` with `posted`, retry `scheduled`, or terminal `failed`.
- `target_channel_key='cap_announcement'` maps only to the env/secret name candidate `DISCORD_WEBHOOK_CAP_ANNOUNCEMENT`; no actual value is recorded.
- `mention_mode='none'` builds `allowed_mentions.parse=[]`.
- `mention_mode='everyone'` is the only path that adds `@everyone` and `allowed_mentions.parse=["everyone"]`.

Next SQL Apply gate:

- Review 050 and 051 together before applying anything.
- SQL Editor must remain untouched until the user explicitly approves the SQL apply gate.
- If 050 is approved, paste only the reviewed 050 SQL and run once.
- If any SQL error occurs, stop and do not rerun.
- After apply, run 051 SELECT-only and review any `missing` or `review` rows before Edge Function deploy work.

## M-14E-26S general owner edit/close Discord sync QA result

Status: user-performed browser/Discord QA result record only. No Codex-side SQL Editor execution, SQL apply, DB/RPC/RLS additional change, Edge Function deploy, dry-run false, secret/Webhook change, target session delete, additional registration, cleanup, or `updates.json` change was performed.

Reported QA results:

- General owner edit-save on the diagnostic session succeeded.
- General owner close-mark operation on the same diagnostic session succeeded.
- Discord sync was confirmed after the owner update/close-mark path.
- The post-047 `update_session_post` owner/admin gate change is treated as validated by actual owner operations.

Interpretation:

- The 049 SELECT-only ready state matched the browser QA result.
- The frontend-matching `update_session_post` overload now works for the general owner flow.
- General owner edit-save and manual close-mark can proceed through the intended owner/admin permission path.
- Discord sync for this path is confirmed at QA-result level.

Safety notes:

- Raw IDs, session IDs, user IDs, emails, JWTs, Supabase URL, project ref, Discord message IDs, channel IDs, post URLs, Webhook URL, Discord body text, and message preview body were not recorded.
- Target session deletion was not performed.
- Additional registration was not performed.
- Unscheduled `@everyone` notification confirmation was not performed.
- Discord sync recovery/resync policy remains a separate gate if needed.

Remaining gates:

- Target session deletion remains deferred.
- Additional session registration remains deferred.
- Unheld-session `@everyone` notification confirmation remains a separate explicit gate.
- Any Discord post/edit/delete outside the already reported QA result remains an explicit gate.

## M-14E-28 mypage template responsive/status cleanup

Status: frontend/UI fix and docs update only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, Discord operation, dry-run false, secret/Webhook change, or `updates.json` change was performed.

Implemented:

- Tightened smartphone-width layout for the mypage template management panel.
- Added width containment for the template panel, form labels, session-post template editor, template example details, variable-help details, variable cards, long example text, and action buttons.
- Smartphone layout keeps the template editor in one column and prevents long examples/variables from pushing the page wider than the viewport.
- Kept the existing folded mypage sections, logout placement, admin-only announcement link behavior, and other mypage sections unchanged.

Session-post template status cleanup:

- The mypage session-post template status options now only expose `draft`, `tentative`, and `recruiting`.
- Removed user-selectable old terminal statuses from the session-post template editor: closed/recruitment ended, finished/session ended, canceled, and equivalent "ended" choices.
- Existing old template values are normalized through the allowed option list and are not restored into the template editor as selectable create/edit values.
- Existing old session/status display compatibility remains outside the template editor.

QA focus:

- On smartphone width, opening mypage template management and editing a template should not cause horizontal page overflow.
- Template name, type, body textarea, mention mode, template examples, variable list, and action buttons should fit within the viewport.
- Long template examples and variable output examples should wrap instead of widening the page.
- Session-post template status choices should be only the three create-safe values.
- Session-post page status choices and mention template save/restore behavior should remain intact.

Still deferred:

- SQL/DB/RPC changes.
- Discord operations.
- Additional registration.
- Unheld-session `@everyone` notification confirmation.

## M-14E-29 mypage/calendar light UI cleanup

Status: frontend/UI fix and docs update only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, Discord operation, dry-run false, secret/Webhook change, or `updates.json` change was performed.

Implemented:

- Fixed the mypage details/summary right-edge open/close labels by replacing the garbled CSS `content` strings with `開く` and `閉じる`.
- Kept the existing details/summary behavior, section borders, smartphone template-management containment, and folded mypage section structure.
- Removed the old `Phase 1では読み取り専用です。` wording from the calendar page lead text.

Maintained:

- Smartphone mypage template-management overflow fix remains in place.
- Session-post template status options remain limited to `draft`, `tentative`, and `recruiting`.
- Old terminal statuses are still not exposed as new template/session-post choices.
- Calendar month layout, compact header, today behavior, type color coding, Discord mention UI, template examples, owner edit/save, close-mark flow, and Discord sync implementation were not changed.

QA focus:

- mypage folded sections should show `開く` when closed and `閉じる` when open without garbled text.
- Calendar page should no longer show the obsolete Phase 1 read-only sentence.
- PC and smartphone layouts should keep the existing mypage template and calendar behavior.

## M-14E-30 calendar today label text cleanup

Status: frontend/UI fix and docs update only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, Discord operation, dry-run false, secret/Webhook change, or `updates.json` change was performed.

Implemented:

- Fixed the remaining garbled calendar `今日` label in the calendar CSS today marker.
- Confirmed the calendar month navigation center button text, `aria-label`, and `title` are already `今日` / `今日へ`.
- Kept the existing previous/next month buttons, today selection behavior, month grid, type color coding, and smartphone calendar layout unchanged.

QA focus:

- The calendar top-right month navigation should show `‹ 今日 ›` without garbled text.
- The today marker should not display mojibake.
- Pressing `今日` should continue selecting today's date and moving to today's month.

## M-14E-31 mypage template responsive retry and GM count cleanup

Status: frontend/UI and display-logic fix only. No SQL Editor execution, DB/RPC/RLS change, SQL apply, Edge Function deploy, Discord operation, dry-run false, secret/Webhook change, or `updates.json` change was performed.

Implemented:

- Retried the smartphone mypage template-management overflow fix because the previous containment was not sufficient.
- Strengthened width containment for the template panel, nested details bodies, template example blocks, variable cards, code/example text, form labels, inputs, selects, textareas, and action buttons.
- Treated the template management section itself as the horizontal-scroll source, and adjusted parent/child layout containment instead of hiding overflow at the page level.
- Rechecked the template-management grid/flex inheritance, `min-width`, long `pre`/code text, textarea/select width, nested details/summary width, and button wrapping assumptions.
- Smartphone-width template management now forces the template form and session-post template editor into a single-column layout, instead of inheriting the wider `.calendar-form` row layout.
- Kept the session-post template status choices limited to `draft`, `tentative`, and `recruiting`; terminal statuses remain unavailable as new template choices.
- Excluded manual-close-marked sessions from the mypage GM schedule count by filtering titles that start with `〆`.
- Existing ended-status filtering remains in place, so closed/finished/canceled/archive-like sessions are not counted as upcoming GM schedules.

QA focus:

- Smartphone mypage template edit controls should stay within the viewport without page-level horizontal scroll.
- Template examples and variable examples should wrap instead of widening the page.
- Template action buttons should stack within the viewport on smartphone width.
- The `予定 / 申請履歴` summary GM count should not include sessions whose title starts with `〆`.
- Unclosed GM sessions should still be counted, and pending/accepted application counts should keep their existing logic.
- Codex did not perform logged-in smartphone browser verification in this batch; final device-width visual confirmation remains a user QA item.

## M-15G-Auth signup failure triage

Status: low-risk signup triage only. Session-post registration, Discord sync QA, deletion QA, SQL Editor execution, DB/Auth/RLS setting change, SQL apply, Edge Function deploy, Discord operation, dry-run false, secret/Webhook change, and `updates.json` change were not performed.

Findings:

- The emergency issue is account signup, not session-post creation; additional session registration, upcoming-session notification QA, and deletion QA are paused.
- The public signup entry point is the mypage account section. `mypage.html` loads `assets/js/mypageAuthClient.js`, which renders login/signup tabs for anonymous users.
- Static frontend review confirmed that the signup form calls Supabase Auth `signUp` with email, password, and `display_name` in user metadata after local validation.
- The current UI intentionally shows a generalized signup failure message, so the visible error alone cannot distinguish Auth signup disabled, email/redirect setting mismatch, profile handler failure, rate limit, duplicate account, or validation failure.
- Existing docs indicate that `handle_new_auth_user_profile` and `update_display_name` were previously confirmed, but the current production signup failure needs a fresh SELECT-only preflight before assuming the trigger/profile path is still healthy.
- Added `docs/supabase/sql/054_signup_auth_profile_preflight_select_only.sql` to check signup-related profile wiring without returning emails, ids, tokens, URLs, or secrets.
- The 054 SQL checks the profile handler, Auth-user trigger, `profiles` table readiness, `display_name` constraints, minimal `public_profiles` view shape, and auth-users-without-profile count using boolean/status/count-style results only.
- Auth Dashboard settings cannot be fully verified by SQL. Public signup enablement, email confirmation behavior, Site URL, and redirect allowlist remain manual Dashboard checks without recording real values.

Next actions:

- Run 054 in a separate SELECT-only SQL Editor gate, once only, and record boolean/status results without real email, ids, JWTs, URLs, or tokens.
- If 054 is healthy, ask the user for the signup Network/Auth error status/code/message type only, without payloads or headers.
- If 054 points to trigger/profile/RLS issues, prepare a dedicated SQL review/apply gate; do not combine it with session-post or Discord QA.

Follow-up result:

- 054 SELECT-only confirmation was reported healthy: profile handler, Auth users trigger, `profiles`, `display_name`, `public_profiles`, and auth-users-without-profile checks were all ok.
- Supabase Dashboard manual confirmation found the Email provider enabled, the Site URL set for the public site, and the public site included in Redirect URLs.
- User-side signup retry confirmed a new Auth user row exists and the account is confirmed.
- Current conclusion: new account signup is confirmed working.
- Audit Logs being empty in the Dashboard is not treated as abnormal here because DB write logging is disabled.
- No real email, user id, JWT, token, full URL, or project ref was recorded.
- No additional SQL Editor execution by Codex, DB/Auth/RLS change, SQL apply, or secret change was performed.

Rate-limit cause confirmed:

- Brave DevTools Network showed the `signup` request returning HTTP 429.
- The Auth response was `code=over_email_send_rate_limit` with message type `email rate limit exceeded`.
- Because 054 and Dashboard checks were healthy, the signup failure cause is not DB/RLS/RPC/profile trigger wiring.
- Current root cause: Supabase Auth built-in email provider send-rate limit.
- Short-term workaround: wait before retrying signup.
- Durable mitigation: configure Supabase Auth Custom SMTP in a separate gate because SMTP credentials are secret-equivalent.
- Added `docs/supabase-auth-custom-smtp-plan.md` to plan Custom SMTP setup and post-setup QA without recording SMTP credentials, real emails, ids, tokens, full URLs, or project refs.
- Account registration policy is to keep the current Supabase Auth email and password configuration.
- Email addresses are private login/recovery identifiers, while public-facing user names use `profiles.display_name`.
- Public display, session GM names, applicant display, and similar user-facing labels should stay username-centric through `profiles.display_name`.
- Username-only custom Auth, anonymous-login-only operation, and removing the email requirement are not adopted at this stage.
- Custom SMTP remains the durable mitigation for signup send-rate limits and remains an independent gate because SMTP credentials are secret-equivalent.
- Current expected account scale is about 10 users, but SMTP selection should leave room for user growth.
- Custom SMTP candidate priority is Resend first, Brevo second, with SendGrid and AWS SES left as future lower-priority candidates because their setup or paid/production assumptions are heavier for the current stage.
- Future reuse is expected beyond Velgard: calendar, session posts, mypage, accounts, Discord sync, and related private operations foundations should remain reusable as a TRPG operations platform.
- Public world content may stay Velgard-specific, but Auth email sender names and email copy should avoid depending too heavily on a single world name.
- Resend adoption assumes obtaining an owned reusable domain first. The base domain name is `tsumetai-hiyasireimen`, with `tsumetai-hiyasireimen.com` as the first candidate and `.net` / `.jp` as reserve candidates.
- Domain availability, purchase price, and renewal price must be checked by a human in the purchase screen; domain purchase, DNS change, Resend domain addition, Resend API key creation, and Supabase Custom SMTP setting are all separate gates.
- SMTP credentials, API keys, DNS-management secrets, real emails, ids, JWTs, tokens, full URLs, and project refs were not recorded.
- `tsumetai-hiyasireimen.com` was purchased through Cloudflare using Chrome. Brave showed a Cloudflare management-screen API 429, but Chrome completed the purchase.
- DNS change, Resend domain addition, Resend API key creation, and Supabase Custom SMTP setting remain unperformed independent gates.
- Real emails, addresses, payment details, Cloudflare account ids, receipt numbers, DNS secrets, API keys, SMTP credentials, full URLs, and project refs were not recorded.
- `tsumetai-hiyasireimen.com` was added to Resend, Resend-specified records were added to Cloudflare DNS, and Resend showed verified status for DNS and domain verification.
- At the domain verification point, Resend API key creation, Supabase Custom SMTP setting, and repeated signup QA remained unperformed independent gates.
- Real emails, API keys, SMTP passwords, full DNS values, payment details, Cloudflare account ids, and project refs were not recorded.
- Supabase Custom SMTP was later saved, and Auth email sending was switched to Resend.
- Repeated signup QA was performed: the first and second signup both succeeded, confirmation email arrival was confirmed, and new user rows were present in Users.
- HTTP 429 / `over_email_send_rate_limit` did not recur after Custom SMTP setup.
- Real emails, user ids, JWTs, tokens, API keys, SMTP passwords, full URLs, and project refs were not recorded for the signup QA result.
- Confirmation email link follow-up: account confirmation completes, but the post-confirm redirect went to a GitHub Pages 404, so the remaining issue is the confirmation-complete redirect destination rather than email sending.
- Frontend fix: `signUp` now passes `emailRedirectTo: getMypageRedirectUrl()`, matching the existing password-reset redirect helper and targeting the deployed `mypage.html` path at runtime.
- Supabase Auth Redirect URLs should include or confirm the deployed `mypage.html` URL represented by the public site origin, existing site base path, and `/mypage.html`; the full URL was not recorded.
- A future dedicated `auth-complete.html` page remains an optional later design, but was not added in this batch.
- Follow-up QA found that Supabase Redirect URLs already allowed the public-site `/velgard-site/**` path and `/velgard-site/mypage.html`, so Dashboard change was not needed.
- After `2c56fa8 Fix signup email redirect target` was reflected, a new signup confirmation email was used for QA. `Confirm email address` redirected to `mypage.html`, not a GitHub Pages 404.
- HTTP 429 / `over_email_send_rate_limit` did not recur, and the signup path is now confirmed through registration, confirmation email arrival, and post-confirm redirect.
- Real emails, user ids, JWTs, tokens, API keys, SMTP passwords, full URLs, and project refs were not recorded for the redirect QA result.
- Codex did not perform Supabase Dashboard operation, SQL Editor execution, DB/Auth/RLS change, SQL apply, secret value recording, Edge Function deploy, Discord operation, or direct signup operation in this recording batch.

## M-14E-27C admin cap announcement RPC draft preparation

Status: 052 RPC追加SQL draft、053 SELECT-only確認SQL、docs更新のみ。No SQL Editor execution, 052 SQL apply, DB/RPC/RLS actual change, Edge Function deploy, Discord post, dry_run=false, secret/env setting or change, cron setting, frontend RPC connection QA, Webhook value recording, JWT/Supabase URL/Discord ID/token recording, `updates.json` change, `deno.lock` change, or `supabase/.temp` change was performed.

051 result handled:

- 050 SQL Applyはユーザー操作を含む明示ゲートで一度だけ実行され、成功扱い。
- 051 SELECT-only確認では、`table_exists`、`rls_enabled`、`admin_select_policy`、`status_check`、`mention_mode_check`、`announcement_type_check`、`target_channel_key_check`、`anon_table_privileges`、`authenticated_table_privileges`、`direct_write_policy_absent`、`rpc_anon_execute` がOK。
- RPC未作成のため、`browser_admin_rpc_exists` は `missing 0/4`、`server_rpc_exists` は `missing 0/2`。
- RPC未作成に起因する `browser_admin_rpc_admin_check`、`browser_admin_rpc_search_path`、`browser_admin_rpc_security_definer`、`browser_rpc_authenticated_execute`、`server_rpc_search_path`、`server_rpc_security_definer`、`server_rpc_contract_patterns`、`post_apply_ready_for_next_gate` はreview。
- ルール通り、Edge Function deploy、Discord投稿、secret/env設定、cron設定、フロントRPC接続確認へは進まず停止した。

Prepared 052 RPC apply draft:

- Added `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql` as `DO NOT RUN` / `NOT EXECUTED` / explicit approval required.
- The draft is for the post-050 RPC apply gate and exists because 051 found RPC missing/review rows.
- Browser/admin RPCs: `create_admin_discord_announcement`, `update_admin_discord_announcement`, `cancel_admin_discord_announcement`, `list_admin_discord_announcements`.
- Server/Edge RPCs: `claim_due_admin_discord_announcements`, `finalize_admin_discord_announcement`.
- Browser/admin RPCs are `security definer`, pin `search_path`, call `public.is_admin()`, grant execute only to `authenticated`, and still reject non-admin users internally.
- Server/Edge RPCs are `security definer`, pin `search_path`, check the service role boundary internally, revoke `anon` and normal `authenticated` execute, and grant execute to the service role boundary.
- `claim_due_admin_discord_announcements` claims only due `scheduled` cap announcements, moves them to `processing`, sets `lock_token`, increments `attempt_count`, and returns only delivery fields needed by the Edge draft.
- `finalize_admin_discord_announcement` updates only `id + lock_token` claimed rows and resolves to `posted`, retry `scheduled`, or terminal `failed`.
- The draft includes an optional `discord_message_id` column for delivery success recording, but browser list RPCs do not return its values.
- Webhook URL values, real channel values, tokens, JWTs, Supabase URLs, Discord IDs, and raw external response bodies are not recorded.

Prepared 053 SELECT-only confirmation:

- Added `docs/supabase/sql/053_admin_discord_announcements_rpc_post_apply_select_only.sql`.
- Kept 051 as the post-050 schema/table check and separated 053 as the post-052 RPC check.
- 053 returns `check_name / status / result_value / note`.
- 053 checks browser/admin RPC 4本、server/Edge RPC 2本、anon execute不可、browser RPCのauthenticated execute、server RPCのauthenticated不可、service role execute、`security definer`、`search_path`、`public.is_admin()` pattern、service-role boundary pattern、claim/finalize契約、`discord_message_id` column、`post_apply_ready_for_next_gate`。
- 053 does not return function bodies, row data, Webhook values, raw external IDs, JWTs, token values, or Supabase project URLs.

Current scope confirmation:

- The active feature remains admin-only cap update announcement scheduling.
- It is not a general reminder feature, not a table/session reminder feature, not a GM/PL free reminder feature, not a Discord Bot slash command feature, and not a free-form multi-purpose Discord scheduler.
- Static JS was not changed to add Supabase direct `.insert` / `.update` / `.delete` / `.upsert`.

Next SQL Apply gate:

- Review `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql`.
- Confirm its `DO NOT RUN` / `NOT EXECUTED` / explicit approval requirement, then treat it as the one approved SQL apply target only if the user explicitly opens that gate.
- Run 052 once only in SQL Editor.
- If an error appears, stop and do not rerun.
- If 052 succeeds, run `docs/supabase/sql/053_admin_discord_announcements_rpc_post_apply_select_only.sql`.
- If 053 contains `missing` / `review` / `error`, stop before Edge deploy or frontend RPC connection.

## M-15H profile avatar MVP preparation

Status: non-destructive preparation only. No SQL Editor execution, DB/Auth/RLS change, Storage bucket creation, Supabase Dashboard change, SQL apply, real file upload, API key/secret handling, Edge Function deploy, Discord operation, dry-run false, or `updates.json` change was performed.

Current findings:

- mypage has existing profile/account editing surfaces, including display-name and related profile panels, but no connected avatar UI yet.
- `profiles` is the private profile table; `public_profiles` is the public display surface and currently centers on display-name style identity.
- Session-detail comments are loaded through `get_public_session_comments(text)`, which returns public comment display data rather than exposing raw `session_comments.user_id`.
- `assets/js/sessionDetailApplicationComments.js` renders the comment header using `display_name`; this is the natural future insertion point for a public avatar element.
- The current comment UI can be extended after DB/Storage readiness, but no frontend avatar rendering was wired in this preparation batch.

Prepared design and SQL drafts:

- Added `docs/profile-avatar-plan.md` with the avatar MVP scope, data-flow findings, Storage/DB design, frontend follow-up plan, safety gates, and QA checklist.
- Added `docs/supabase/sql/055_profile_avatars_storage_schema_apply_draft.sql` as a DO NOT RUN / NOT EXECUTED apply draft.
- 055 proposes `profiles.avatar_path` and `profiles.avatar_updated_at`, stores object paths rather than full image URLs, extends `public_profiles`, extends `get_public_session_comments(text)` with public avatar metadata, drafts the `avatars` Storage bucket and owner-only Storage policies, and drafts avatar metadata update/clear RPCs.
- Added `docs/supabase/sql/056_profile_avatars_post_apply_select_only.sql` as the post-055 SELECT-only confirmation SQL.
- 056 checks avatar columns, public view shape, bucket readiness, Storage policies, avatar metadata RPCs, comment RPC avatar shape, and readiness for a later frontend avatar QA gate.

MVP policy:

- Storage bucket candidate is `avatars`.
- Avatar images are public display assets, so public read is the MVP candidate.
- Writes, replacements, and removals should be limited to the authenticated owner path.
- Candidate image types are png/jpeg/webp, with about a 1MB size limit.
- Default avatar display should be used when no avatar is configured.
- Comment display should eventually show the author's avatar next to or near the display name and timestamp.

Next gates:

- Review 055 in a dedicated SQL apply gate before any DB/Storage change.
- If 055 is applied once successfully, run 056 in a separate SELECT-only confirmation gate.
- Only after 056 is healthy, implement mypage avatar upload/delete UI and session-detail comment avatar rendering.
- Real avatar upload/delete QA is a later Storage-writing gate.

Safety notes:

- No real user id, email, avatar object path, signed URL, full Supabase URL, project ref, JWT, token, API key, Discord id, or Webhook value was recorded.
- The preparation does not change existing mypage, session-detail, comment, Discord sync, signup, or session-post runtime behavior.
