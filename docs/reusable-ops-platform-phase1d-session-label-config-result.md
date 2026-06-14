# Reusable Ops Platform Phase 1-D Session Label Config Result

## 背景

Phase 1-A〜1-Cで、calendarとmypageの一部表示ラベルを `assets/js/reusableOpsConfig.js` へ寄せた。Phase 1-Dでは、session-post / session-detail / approved gate 周辺のうち、認証・権限・RPC・Discord同期処理に触れずに切り出せる表示ラベルだけを設定入口へ接続した。

今回も、独立アプリ化、フォルダ再編、DB/RPC/RLS変更、SQL apply、Edge deploy、Discord操作は行っていない。

## 実施範囲

採用方針は案Bの小実装。ただし接続対象は表示ラベルに限定した。

実装したこと:

- `reusableOpsConfig.js` にsession-post / session-detail / approved gate向けのラベル候補を追加。
- `membershipAccessClient.js` の共通approved gate既定文言を設定参照へ接続。
- `sessionDisplay.js` の依頼書詳細行ラベル、GM管理ボタンラベル、参加希望コメント見出し、Discord同期パネル項目名を設定参照へ接続。
- `renderSessionPost.js` の投稿フォーム見出し、主要フォームラベル、管理対象selectラベル、作成/保存/削除ボタン表示、未承認gate文言を設定参照へ接続。
- 変更したmoduleが対象ページで読まれるよう、session-post / session-detail / calendar / timeline のcache-bustを最小更新。

表示文言は従来と同じ値をfallbackに残しており、設定取得に失敗しても `undefined` が画面へ出ないようにした。

## 今回設定化した値

approved gate共通:

- 承認済みアカウント専用
- この機能は承認済みメンバー向けです。
- 承認済みアカウントのみ利用できます
- ログインし、承認済みアカウントになると利用できます。
- マイページで状態を確認する
- ACCOUNTでログインする
- TOPへ戻る

session-detail周辺:

- 開催日
- 種別
- 開催場所
- 開催時刻
- 申請締切
- レベル帯
- 募集人数
- 詳細
- 参加条件・注意事項
- 補足情報
- 公開状態
- 募集状態
- 更新日時
- 管理
- 編集
- 〆にする
- 削除
- 参加希望コメント
- Discord同期、同期状態、最終操作、最終同期日時、同期エラー、投稿リンク

session-post周辺:

- 依頼書投稿
- ログインユーザー向けのセッション予定投稿フォームです。
- 投稿権限
- 依頼書
- タイトル
- 開始日時
- 終了日時
- 申請締切
- 種別
- 募集人数
- 開催場所
- 公開状態
- 募集状態
- 概要
- 自分の依頼書
- 管理対象の依頼書
- 新規依頼書を書く
- 公開状態で保存する場合に確認する
- 作成する
- 変更を保存
- 削除
- 作成結果
- Discord同期状態

## 今回あえて設定化しなかった値

- session-postの保存・削除・Discord同期に関わる確認文言とエラー分類。
- session-detailの〆操作確認文言、削除確認文言、Discord同期結果文言。
- 参加申請/コメント作成・編集・削除のRPC名、payload、権限分岐、エラー分類。
- owner / GM / admin / approved判定。
- Discord同期の実行可否、Edge Function名、投稿/編集/削除処理。
- DBカラム名、RPC名、`management_key`、内部ID、raw user_id、email、token類。

これらは表示だけでなく操作や権限境界と強く結びつくため、今回のPhase 1-Dでは触らない。

## 独立ツール化に向けて前進した点

- session-post / session-detail / approved gate の主要表示ラベルを、同じ `reusableOpsConfig.js` から読める入口へ寄せた。
- session typeだけでなく、依頼書詳細・依頼書投稿の基本ラベルも世界観差し替え候補として扱えるようになった。
- 表示ラベルの設定化と、認証・権限・RPC・Discord同期処理の非設定化の境界を再確認できた。
- fallbackつき参照にしたため、設定値の追加漏れがあっても既存表示へ戻る。

## QA観点

- session-post画面が表示される。
- session-detail画面が表示される。
- 未ログイン/未承認時のapproved gate表示が破綻しない。
- approvedユーザー向けの依頼書詳細、参加希望コメント、GM管理欄が従来どおり表示される。
- 〆表示、〆解除、押し忘れ注意、Discord同期パネルの表示が壊れていない。
- session種別表示はPhase 1-Bの設定入口を引き続き使う。
- 設定未読込または設定値欠落時もfallbackで表示され、`undefined` や空ラベルが出ない。
- raw ID、email、token、management key実値が画面/docs/consoleに出ない。

## 次に設定化すべき候補

1. session-post / session-detail のエラー文言を、操作ロジックと切り離せる単位で棚卸しする。
2. notification / TIMELINEの表示ラベルを `reusableOpsConfig.js` か専用activity label configへ寄せる。
3. navigation registryをdocs設計し、public / approved-only / admin-only の表示規則を設定候補として整理する。
4. Discord同期UI文言とEdge Function投稿本文のうち、世界観依存部分だけを分離する計画を作る。

## 禁止工程の扱い

SQL Editor実行、SQL apply、DB/RPC/RLS変更、Edge Function deploy、Discord操作、secret変更、Supabase直接write追加、`console.*` 追加、`updates.json` 変更、ファイル大移動、フォルダ再編、独立アプリ化は行っていない。
