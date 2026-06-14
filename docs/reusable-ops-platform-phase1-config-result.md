# Reusable Ops Platform Phase 1-A Config Result

## 背景

`docs/reusable-ops-platform-extraction-plan.md` のPhase 1として、汎用TRPG運用基盤へ近づけるための最小設定入口を追加した。今回は独立アプリ化、フォルダ再編、DB/RPC/RLS変更、SQL apply、Edge deploy、Discord操作は行っていない。

## 実施範囲

採用した方針は案A寄りの超安全案。

- 新規 `assets/js/reusableOpsConfig.js` を追加した。
- calendarのセッション種別ラベルを設定入口から参照するようにした。
- calendarのセッション種別ごとの表示classを設定入口から参照するようにした。
- calendarの基本ボタン文言の一部を設定入口から参照するようにした。
- calendarページで更新後の `renderCalendar.js` が読まれるよう、最小限のcache-bustを更新した。

## 設定ファイル化した値

`assets/js/reusableOpsConfig.js` に、まず以下を置いた。

- サイト名候補
- 世界観名候補
- calendar基本ボタン文言
  - 確認
  - 今日
  - 今日へ
  - 今日に戻す
- session type設定
  - `one-shot`: 単発シナリオ / blue / `calendar-session-type-one-shot`
  - `campaign`: キャンペーン / green / `calendar-session-type-campaign`
  - `special`: 特殊 / red / `calendar-session-type-special`
  - `other`: その他 / purple / `calendar-session-type-other`
- approved gate系文言候補
- mypage主要セクション名候補

今回実際に参照しているのは、calendarのセッション種別ラベル、calendar表示class、calendar基本ボタン文言だけである。mypageとapproved gateの値は、次工程で安全に接続するための候補として置いた。

## 表示互換性

表示結果は原則として現状維持にした。

- calendar上のセッション種別名は従来と同じ表示を維持する。
- calendarの色分けclassは従来と同じclass名を維持する。
- 月移動エリアの「今日」ボタンは、表示文言とaria/titleの意味を維持する。
- 下部フォームの「確認」「今日に戻す」も従来の表示を維持する。
- 〆表示、GM名表示、依頼書詳細リンク、申請締切表示、レベルキャップ表示には触れていない。

## まだ設定化していない値

- `calendarConfig.json` の実カレンダー開始日、暦、季節、月齢、レベルキャップ。
- `main.js` のnav定義。
- mypageの実表示見出し。
- approved gateの実表示文言。
- session-postのフォームラベル。
- session-detailの参加申請/コメント/GM管理ラベル。
- notification / TIMELINE の表示文言。
- Discord同期本文やEdge Function側の世界観依存文言。
- CSSの色値そのもの。

## 今回あえて触らなかった範囲

- `mypageAuthClient.js` の会員管理UI、テンプレート管理、PC管理、予定/申請履歴。
- `membershipAccessClient.js` の実approved gate文言と権限判定。
- `renderSessionPost.js` と `renderSessionDetail.js` のフォーム/詳細表示。
- Discord同期クライアントとEdge Function。
- Supabase RPC、RLS、table grant、SQL docs。
- `style.css` の分割や色token化。
- 既存フォルダ構成。

## 独立ツール化に近づいた点

- セッション種別の表示名とcalendar用classを、calendar実装から切り離す入口ができた。
- 世界観ごとにセッション種別ラベルや色分類を差し替える余地ができた。
- mypageやapproved gateの文言候補も同じ設定入口へ集められる見通しができた。
- 大規模分割前に、運用基盤が参照する世界観依存値の置き場を試せた。

## QA観点

- calendarページが開く。
- approvedユーザーでcalendarが表示される。
- セッション種別ごとの色分けが変わっていない。
- セッションカードの種別表示が変わっていない。
- 「今日」ボタンと「今日に戻す」ボタンが従来どおり動く。
- 〆表示、GM名表示、依頼書詳細リンクが壊れていない。
- mypage、会員管理UI、approved gateが今回の変更で壊れていない。

## 次工程候補

1. `main.js` のnav定義を設定ファイル化する前の設計レビュー。
2. `membershipAccessClient.js` のapproved gate表示文言を設定入口へ接続する小改修。
3. `mypageAuthClient.js` の主要セクション名だけを設定入口へ接続する小改修。
4. `renderSessionPost.js` / `renderSessionDetail.js` のsession typeラベルを同じ設定へ寄せる。
5. CSS上のcalendar色classを、将来のtheme tokenへ寄せるための棚卸し。

## Phase 1-B follow-up

Phase 1-Bでは、`sessionDisplay.js` の `getSessionTypeLabel()` を
`reusableOpsConfig.js` のsession type設定へ接続した。これにより、
calendarだけでなくsession-post / session-detail系のセッション種別表示も
同じ設定入口を使う。

また、mypage主要セクション名、会員管理ステータス/操作ラベル、
approved gate系ラベル、session UI系ラベルを設定候補として
`reusableOpsConfig.js` に追加した。ただし、mypage本体やapproved gate本体への
接続は次工程へ残した。詳細は
`docs/reusable-ops-platform-phase1b-label-config-plan.md` に記録する。

## Phase 1-C follow-up

Phase 1-Cでは、通常scriptである `mypageAuthClient.js` をES module化せず、
`assets/js/reusableOpsMypageLabels.js` をclassic bridgeとして追加した。
`mypage.html` はこのbridgeを `mypageAuthClient.js` より前に読み込み、
主要mypage details見出しと短いsummaryだけを設定参照へ接続する。

接続した値は、アカウント概要、プロフィール / PC情報、予定 / 申請履歴、
テンプレート管理、会員管理、および各summary文言の一部である。bridge未読込時は
`mypageAuthClient.js` 内の既存fallback文言を使うため、設定取得失敗でも画面は
従来表示へ戻る。

認証、approved gate判定、会員管理RPC、`management_key` 処理、DB/RPC/RLS、
Discord同期、操作ボタン文言、エラー文言は変更していない。詳細は
`docs/reusable-ops-platform-phase1c-mypage-config-result.md` に記録する。

## Phase 1-D follow-up

Phase 1-Dでは、session-post / session-detail / approved gate 周辺の一部表示ラベルを
`reusableOpsConfig.js` へ接続した。

接続した値は、依頼書投稿フォームの見出し/主要フォームラベル/作成・保存・削除表示、
依頼書詳細の基本情報ラベル/補足情報ラベル/GM管理ボタン表示、
参加希望コメント見出し、Discord同期パネル項目名、共通approved gateの既定文言である。

設定取得に失敗した場合は既存fallback文言を使う。認証、approved判定、owner/admin判定、
参加申請/コメントRPC、依頼書保存/削除RPC、Discord同期処理、DB/RPC/RLSは変更していない。

詳細は `docs/reusable-ops-platform-phase1d-session-label-config-result.md` に記録する。
