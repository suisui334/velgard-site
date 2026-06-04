# M-14D-15 依頼書RPC/RLS smoke test整理

## 目的

依頼書の作成、編集、公開状態変更、募集状態変更、中止、完全削除について、既存RPC / RLS / 権限のsmoke test観点を整理する。

この文書は後続のSELECT-only preflightや手動ブラウザQAのためのチェックリストであり、SQLファイル作成、SQL Editor実行、DB構造変更、RPC変更、フロント実装は行わない。

## 対象RPC / 対象機能

対象RPC候補:

- `create_session_post(...)`
- `update_session_post(...)`
- `delete_session_post(text)`
- 必要に応じて、公開表示や管理対象一覧の取得処理

対象機能:

- 依頼書新規作成
- 既存依頼書編集
- 公開 / 非公開 / 下書きの変更
- 募集中 / 満員 / 募集終了 / 開催終了 / 中止の変更
- `status = canceled` による「中止として残す」操作
- `delete_session_post(text)` による完全削除
- `session-detail.html` から `session-post.html` への編集導線
- adminによるSupabase由来依頼書の管理
- 静的JSON由来依頼書の編集不可 / 削除不可表示
- Supabase由来を優先するマージ表示

## 権限ロール別の確認表

| 文脈 | 作成 | 更新 | 完全削除 | 管理UI / 操作表示 | smoke test観点 |
| --- | --- | --- | --- | --- | --- |
| 未ログイン | 不可 | 不可 | 不可 | GM/admin向け操作を出さない、または実行不可 | RPCが未ログインを拒否し、画面も管理操作を出さないこと |
| 通常PL | 不可または権限拒否 | 他人の依頼書は不可 | 他人の依頼書は不可 | GM/admin向け操作を出さない | 依頼書管理対象やadmin管理対象が見えず、RPCでも拒否されること |
| 作成者GM | 可 | 自分のSupabase由来依頼書は可 | 自分のSupabase由来依頼書は可 | 自分の管理対象として表示 | 公開状態、募集状態、中止、完全削除を既存RPC経由で扱えること |
| 他GM | 権限がなければ不可 | 他GMの依頼書は不可 | 他GMの依頼書は不可 | 他GMの管理対象として出さない、または編集不可 | 表示制御とRPC側の本人所有制御が一致すること |
| admin | 可 | Supabase由来依頼書を横断管理可 | Supabase由来依頼書を横断管理可 | 管理対象として表示 | adminはアプリ内権限として扱い、サーバ高権限とは混同しないこと |
| 静的JSON由来 | DB対象外 | DB対象外 | DB対象外 | 編集不可 / 削除不可理由を表示 | 既存RPCへ流さず、Supabase由来の同ID行がある場合はSupabase側を優先すること |

## 入力バリデーション確認表

| 観点 | 期待 |
| --- | --- |
| `draft + public` | 拒否または保存前ガードされる |
| 不正な `status` | 拒否される |
| 不正な `visibility` | 拒否される |
| `player_min > player_max` | 拒否される |
| `end_at <= start_at` | 拒否される |
| タイトル空欄 | 既存仕様に沿って拒否または保存前ガードされる |
| 概要空欄 | 既存仕様に沿って拒否または保存前ガードされる |
| 申請締切と開催日時の関係 | 必要なら後続smoke testで確認する |
| エラー表示 | 内部情報を含まない一般的な日本語表示へ丸める |

## 削除 / 中止 / 募集終了の確認観点

- 完全削除は `delete_session_post(text)` を使う。
- 完全削除では依頼書本体に加え、関連する参加申請と参加希望コメントもDB制約により削除される。
- 削除前確認文には、参加申請とコメントも削除されることを明記する。
- 中止として履歴を残す場合は `status = canceled` を使い、完全削除とは分ける。
- 募集終了は募集状態の変更として扱い、完全削除とは分ける。
- 開催終了も募集状態の変更として扱い、完全削除とは分ける。
- 完全削除後はcalendar、session-detail、session-post管理対象に残らないことを確認する。
- Discord投稿削除同期は別工程で扱い、このsmoke test整理には実送信を含めない。

## 静的JSON由来とSupabase由来の扱い

- 静的JSON由来の予定はDB RPCの編集 / 削除対象にしない。
- 静的JSON由来の場合は、編集不可 / 削除不可理由を短く表示する。
- 同じ公開IDでSupabase由来行が取得できる場合は、Supabase由来を優先する。
- Supabase側が非公開、下書き、中止など公開表示対象外の場合でも、静的JSON fallbackで復活しないことを確認する。
- 静的JSON由来を誤ってSupabase管理対象selectへ混ぜない。

## 内部情報非露出の確認観点

- 画面、DOM、console、docsに内部識別子、認証系の生値、PC選択や申請に関わる内部キー、外部連携credential類の実値を出さない。
- select option valueには表示用の一時キーだけを使う方針を維持する。
- RPC戻り値やエラー表示は、UIに必要な最小情報と一般化したエラー文だけに丸める。
- consoleへRPC結果の生データを出さない。
- docsには実データの値を記録せず、確認観点と期待値のみを記録する。

## EXECUTE / security確認観点

後続のSELECT-only preflightでは、既存RPCについて以下を確認候補にする。

- 対象RPCが存在すること。
- signatureが想定と一致すること。
- `security_definer = true` であること。
- `search_path` が明示されていること。
- `authenticated` にEXECUTEがあること。
- `anon` / `public` にEXECUTEがないこと。
- 既存helperの存在と権限方針。
- `sessions` の `status` / `visibility` / `session_type` 関連CHECK制約。
- 完全削除時に影響を受ける関連テーブルとON DELETE方針。

## 後続のpreflight SELECT-only SQL候補

この工程ではSQLファイルを作成しない。
後続で作る場合は、単一結果セット形式で以下を縦に並べると確認しやすい。

- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` の存在、signature、security、search_path。
- 対象RPCのEXECUTE権限。
- `sessions` の主要列、CHECK制約、公開状態 / 募集状態の許可値。
- 既存helper関数とadmin / GM判定方針。
- `sessions` を参照する関連テーブルとON DELETE方針。
- 静的JSON由来はSQLではなくフロント表示・マージロジック側で確認する。

## 後続の手動ブラウザQA候補

- 未ログインで管理操作が出ない、または実行できない。
- 通常PLでGM/admin向け管理操作が出ない。
- 作成者GMで自分のSupabase由来依頼書を作成、編集、公開状態変更、募集状態変更、中止、完全削除できる。
- 他GMで他人の依頼書を編集 / 削除できない。
- adminでSupabase由来依頼書を横断管理できる。
- 静的JSON由来で編集不可 / 削除不可理由が表示される。
- 同IDのSupabase由来がある場合、Supabase側が優先される。
- 非公開 / 下書き / 中止のSupabase由来が静的JSON fallbackで復活しない。
- `draft + public`、不正な状態値、不正な人数範囲、終了日時逆転がガードされる。
- 完全削除前確認に参加申請とコメントへの影響が表示される。
- console error 0件。
- 内部情報が画面、DOM、consoleに出ない。

## やらないこと

- SQLファイル作成
- SQL Editor実行
- DB構造変更
- RPC変更
- フロント実装
- Discord実送信
- Edge Function deploy
- テストデータcleanup
- `updates.json` 変更
- commit / push

## 次工程案

- M-14D-15A: 既存RPC / RLS / 権限のSELECT-only preflight SQL作成。
- M-14D-15B: 手動ブラウザsmoke test手順書作成。
- M-14D-15C: ユーザー実ブラウザQA結果記録。
- M-14D-15D: QAで見つかった軽微な表示 / 文言修正。
- M-14D-15E: Discord同期状態との連動確認を別工程で整理。

## M-14D-15B preflight SELECT-only SQL

依頼書RPC smoke testの前段として、SELECT-only preflight SQL `docs/supabase/sql/024_session_posting_rpc_smoke_preflight_select_only.sql` を作成した。

このSQLは、SQL Editorで1つの結果表として確認できるよう、`sort_order` / `section` / `check_name` / `expected` / `status` / `result_value` / `notes` の列に統一している。

確認対象:

- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` の存在、signature、戻り値概要。
- 対象RPCの `security_definer` と `search_path` 設定。
- 対象RPCの `authenticated` / `anon` / `PUBLIC` 向けEXECUTE状態。
- `public.sessions` の存在と主要列。
- `status` / `visibility` / `session_type` のCHECK制約。
- `session_applications` / `session_comments` から `sessions` へのFKとON DELETE方針。
- admin / GM / role helperの存在。
- `user_roles` テーブル存在。
- `sessions` / `session_applications` / `session_comments` / `profiles` / `user_roles` のRLS有効状態とpolicy概要。
- 静的JSON由来がDB RPC対象外であることは、SQLではなくフロント表示・マージロジック側の確認観点として残す。

この工程ではSQLファイル作成のみ。SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-14D-15B preflight実行結果

ユーザーがSupabase SQL Editorで `docs/supabase/sql/024_session_posting_rpc_smoke_preflight_select_only.sql` を手動実行し、エラーなしで単一結果セットが表示された。

確認結果:

- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` はpublic schemaに存在し、いずれもstatus ok。
- 対象RPC 3本はいずれも `security_definer = true`、`search_path` 明示ありでstatus ok。
- EXECUTE権限は、対象RPC 3本すべてで `authenticated = true`、`anon = false`、`PUBLIC = false` と確認でき、status ok。
- `public.sessions` は存在し、status ok。
- `sessions` の主要列として、公開ID、タイトル、開催日、開始/終了時刻、終了日時、GM表示名、募集状態、依頼書種別、申請締切、募集人数、概要、公開状態、作成/更新日時、Discord同期メタデータ列を確認でき、いずれもstatus ok。
- `status` / `visibility` / `session_type` のCHECK制約はstatus ok。`status` 制約では募集状態候補とDiscord同期状態候補の制約が見えているため、各状態値の実動作は後続smoke test候補として残す。
- `session_applications` と `session_comments` は `sessions` へのFKがあり、いずれも `ON DELETE CASCADE` でstatus ok。完全削除時に関連申請・コメントもDB制約上CASCADEされる前提を再確認した。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` と `public.user_roles` は存在し、status ok。adminはアプリ内権限として扱い、サーバ高権限とは混同しない。
- `sessions` / `session_applications` / `session_comments` / `profiles` / `user_roles` はRLS enabledでstatus ok。
- policy summaryはinfoとして確認できた。policy名や式の詳細展開は今回のpreflightでは省略しているため、必要なら後続の詳細smoke test候補にする。
- 静的JSON由来はDB catalog項目ではないためinfo。DB RPC対象外として、フロント表示・マージロジック側の確認観点に残す。

判断:

- M-14D-15B preflightは成功扱いでよい。
- 既存RPC 3本の存在、`security_definer`、`search_path`、`authenticated` のみEXECUTE、`anon` / `PUBLIC` 不可、`sessions` 主要列、関連FK CASCADE、helper、RLS enabled の前提が確認できた。
- 次工程は、このpreflight SQLと結果記録をcommit / pushしたうえで、後続の手動smoke test設計または実ブラウザQAへ進める。

この記録工程でCodexはSQL Editor実行、DB/RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。
