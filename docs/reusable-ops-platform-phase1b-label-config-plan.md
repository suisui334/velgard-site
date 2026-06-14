# Reusable Ops Platform Phase 1-B Label Config Plan

## 背景

Phase 1-Aで `assets/js/reusableOpsConfig.js` を追加し、calendarの一部を設定入口から参照する形にした。Phase 1-Bでは、mypage / approved gate / session-post / session-detail 周辺に散っている表示ラベルを棚卸しし、安全に設定化できる範囲だけを小さく広げた。

今回も、独立アプリ化、フォルダ再編、DB/RPC/RLS変更、SQL apply、Edge deploy、Discord操作は行っていない。認証・権限判定・RPC名・DBカラム名は設定化対象外のまま維持する。

## 実施方針

案B寄りの小実装を採用した。ただし、mypage本体は通常scriptとして読み込まれており、ES moduleの `reusableOpsConfig.js` を直接importするには構造変更が必要になるため、今回はmypageの実表示接続までは行っていない。

実装したこと:

- `reusableOpsConfig.js` にmypage / approved gate / session系の候補ラベルを追加。
- `sessionDisplay.js` の `getSessionTypeLabel()` を `reusableOpsConfig.js` のsession type設定へ接続。
- session-post / session-detail / calendar で使われるセッション種別ラベルの入口を共通化。
- 関連するimport cache-bustを最小更新。

## 今回設定化した値

実際に参照するようにした値:

- `one-shot`: 単発シナリオ
- `campaign`: キャンペーン
- `special`: 特殊
- `other`: その他

これにより、calendarだけでなく、`sessionDisplay.js` 経由で表示されるsession-post / session-detail系のセッション種別ラベルも同じ設定入口を参照する。

設定候補として追加したが、まだ実表示へ接続していない値:

- mypage主要セクション名
  - アカウント概要
  - プロフィール / PC情報
  - 予定 / 申請履歴
  - テンプレート管理
  - 会員管理
- 会員管理ステータスラベル
  - 承認待ち
  - 承認済み
  - 却下
- 会員管理操作ラベル
  - 承認する
  - 却下する
  - 再承認する
  - 管理権限を付与
  - 管理権限を剥奪
- approved gate系ラベル候補
  - 承認済みアカウント専用
  - 承認済みアカウントのみ利用できます
  - ログイン誘導文言
- session系ラベル候補
  - 依頼書
  - 参加申請
  - 参加希望コメント
  - コメント
  - GM管理
  - Discord同期
  - 募集状態
  - 公開状態
  - 募集人数
  - 開催場所
  - セッション種別
  - 詳細を見る
  - 編集・管理

## mypage周辺の棚卸し

安全に設定化しやすい候補:

- details見出し。
- ステータス表示ラベル。
- ボタン文言。
- 空状態文言。
- テンプレート種別ラベル。

慎重に扱う候補:

- 会員管理UIの操作可否表示。
- manager権限付与/剥奪のエラー分類文言。
- pending / approved / rejected の状態遷移に関わる説明文。

今回触らなかった理由:

- `mypageAuthClient.js` は通常scriptで、ES module設定を直接importするには読み込み方式の変更が必要。
- mypageには認証、プロフィール、PC、予定、テンプレート、会員管理が密集しており、見出しだけでも広範囲に影響する。
- management keyや内部ID非露出方針を崩さないため、会員管理UIの構造変更は別ゲートに分ける。

## approved gate周辺の棚卸し

安全に設定化しやすい候補:

- gateのtitle。
- gateのheading。
- 未ログイン時の案内文。
- mypageへの導線ラベル。

設定化してはいけないもの:

- approved判定そのもの。
- `get_my_membership_status` のRPC呼び出し。
- membership statusの正規化ロジック。
- role/admin判定。
- public_profilesへのmembership/role露出。

今回は候補ラベルだけを `reusableOpsConfig.js` に追加し、`membershipAccessClient.js` の実接続は次工程へ残した。

## session-post / session-detail周辺の棚卸し

安全に設定化しやすい候補:

- セッション種別ラベル。
- 詳細表示の項目名。
- フォームラベル。
- 依頼書/参加申請/コメント/GM管理などの表示名。
- Discord同期の表示ラベル。

慎重に扱う候補:

- 削除確認文言。
- Discord同期失敗文言。
- 申請/コメントの権限エラー文言。
- spam guardやapproved gateのエラー文言。

設定化してはいけないもの:

- RPC名。
- DBカラム名。
- direct table write経路。
- Discord同期の実行可否判定。
- 申請/コメント/編集/削除の権限分岐。

今回接続したのは、`sessionDisplay.js` のセッション種別ラベルのみ。

## 独立ツール化に向けて前進した点

- session type labelの参照入口をcalendar専用から、session表示共通の入口へ広げた。
- mypage / approved gate / session UIのラベル候補を同じ設定ファイルに集める準備ができた。
- 通常scriptであるmypage本体を無理にmodule化しない判断を明記できた。
- 表示文言の設定化と、認証・権限・RPCの非設定化の境界を整理できた。

## 次に設定化すべき候補

1. `membershipAccessClient.js` のgate title / heading / account link label。
2. `mypageAuthClient.js` をmodule化せずに安全に設定参照できる仕組みの設計。
3. `renderSessionPost.js` のフォームラベルのうち、権限やRPCに関係しないもの。
4. `sessionDisplay.js` の詳細表示項目名。
5. notification / TIMELINE のtype label。

## QA観点

- calendarのセッション種別表示が変わっていない。
- session-detailの種別表示が変わっていない。
- session-postの既存依頼書編集/一覧内の種別表示が変わっていない。
- mypageの表示や会員管理UIが壊れていない。
- approved gateの表示や判定が壊れていない。
- RPC呼び出し、DB更新、Discord同期処理に変更がない。

## 禁止工程の扱い

今回、SQL Editor実行、SQL apply、DB/RPC/RLS変更、Edge Function deploy、Discord操作、secret変更、Supabase直接write追加、`console.*` 追加、`updates.json` 変更、フォルダ再編、独立アプリ化は行っていない。
