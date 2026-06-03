# M-15F 参加申請PC名スナップショット計画

## 目的

M-15Eまでに、mypageでPC名を管理するUIと `player_characters` / `session_applications.pc_name_snapshot` のDB土台が用意された。M-15Fでは、参加申請コメント投稿時に、ログインユーザー本人の既定PCを `session_applications` へ自動保存するRPC草案を整理する。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT / REVOKE実行、フロントUI実装、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行わない。

## 現在の接続

フロントの参加申請投稿は `create_application_comment(target_session_id, comment_body)` を呼び、渡している値はセッションIDとコメント本文だけである。コメント本文はPLの自由本文として扱う。

```text
参加希望です。
よろしくお願いします。
日程問題ありません。
```

参加申請コメント欄に、ユーザー名、PC名、DiscordユーザーIDを手入力させない。コメント本文からPC名やDiscord IDを解析せず、特定書式も強制しない。

## 登録情報の取得元

ユーザー名は `profiles.display_name` を使う。DiscordユーザーIDは `profiles.discord_handle` を使う。PC名は `player_characters` のうち、本人所有、active、default の行を使う。

M-15FのRPC草案では、参加申請時点の既定PCを以下のように保存する。

```text
selected_character_id = ログインユーザー本人の既定PC id
pc_name_snapshot = ログインユーザー本人の既定PC名
```

既定PCがない場合も参加申請は許可し、以下の状態にする。

```text
selected_character_id = null
pc_name_snapshot = null
```

PC名未登録を理由に参加申請を拒否しない。テンプレート出力側では未登録を `PC名未登録` に丸める。

## RPC草案

新規作成した草案は `docs/supabase/sql/020_application_pc_snapshot_rpc_draft.sql`。既存の `create_application_comment(text, text)` と同じシグネチャを維持し、フロントからPC名やDiscordユーザーIDを渡さない。

新規PL申請では既定PCをsnapshotする。辞退済みからの再申請では、その時点の既定PCで `selected_character_id` / `pc_name_snapshot` を更新する。既に `pending` / `accepted` / `rejected` / `waitlisted` の申請行がある場合は、コメント追記のみを許可し、既存の申請状態とPC snapshotは変更しない。

コメント編集は既存の `update_application_comment` 側の責務であり、PC snapshotは変更しない。

## GMコメント

GM本人コメントは許可する。ただし参加申請として扱わない。M-15FのRPC草案では、GM本人が `create_application_comment` を使ってコメントした場合、`session_comments.is_application = false` として保存し、`session_applications` 行の作成/更新やPC snapshot保存を行わない。

これにより、GMコメントは告知・補足用コメントとして残しつつ、参加人数、申請者一覧、承認済み参加者連絡先、テンプレート変数の対象から外す。既存フロントにはGMコメント後に `cancel_my_session_application` を呼ぶcleanupがあるが、RPC置換後はキャンセル対象の申請行がない場合があり、その失敗は既存どおり握りつぶす想定。

## preflight SQL

新規作成したpreflight SQLは `docs/supabase/sql/020_application_pc_snapshot_preflight_select_only.sql`。以下をSELECT-onlyで確認する。

- `session_applications.selected_character_id` / `pc_name_snapshot`
- `player_characters` のPC名管理列
- `session_comments.is_application`
- `create_application_comment(text, text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)` などの関数契約
- 関連関数の `security_definer` / `search_path` / 権限
- `session_applications` / `session_comments` / `player_characters` のRLS policyとtable privilege

preflightはcatalog inspectionのみで、schema、data、privilegesを変更しない。

## 後続工程との分離

M-15Fは参加申請時のPC名snapshotまでを扱う。M-15GではGM向け承認済み参加者一覧/連絡先表示にPC名を含める。M-15Hでは `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` のテンプレート変数置換に接続する。

将来、複数PCから申請時に選びたい場合は、コメント欄とは別に「参加PC選択UI」を追加する。初期実装ではmypageで設定した既定PCを自動採用する。

## 今回やらないこと

- SQL Editor実行
- DB構造変更
- RPC作成 / 置換
- GRANT / REVOKE実行
- フロントUI実装
- 参加申請コメント欄へのPC名入力欄追加
- 参加申請コメント欄へのDiscordユーザーID入力欄追加
- コメント本文からのPC名 / Discord ID解析
- PC名未登録を理由にした参加申請拒否
- テンプレート保存機能本体
- Discord実送信
- Edge Function deploy
- `updates.json` 変更
- service_role key利用
- secret類の出力
- commit / push

## M-15F preflight確認結果

修正版 `020_application_pc_snapshot_preflight_select_only.sql` は、Supabase SQL Editorでの実行時に `ERROR: 42809: "array_agg" is an aggregate function` で途中停止した。これはSELECT-only preflight中のエラーであり、DB変更は起きていない。

小型確認SQLでは、`player_characters` table、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` が存在することを確認済み。`session_applications.status` の許可値は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` で、M-15F草案の `pending` / `canceled` と矛盾しない。

主要RPCとhelper関数は `security_definer = true` と確認済み。`cancel_my_session_application`、`create_application_comment`、`get_gm_session_accepted_contacts`、`get_my_player_characters` は `authenticated EXECUTE` ありで、確認結果画面では `anon` / `public` のEXECUTEは出ていない。

今回、preflight SQLから `pg_get_functiondef` と不要な集約表示を外し、必要なRPCのsignature / arguments / result / `prosecdef` / `proconfig` / routine privileges確認に絞った。SQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、APPLY専用SQL作成、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## M-15F preflight再実行成功

修正版 `020_application_pc_snapshot_preflight_select_only.sql` をSupabase SQL Editorで実行し、preflightは成功した。前回の `ERROR: 42809: "array_agg" is an aggregate function` は解消済み。

確認済みの前提として、`public.player_characters`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot`、`session_applications` の `UNIQUE(session_id, user_id)`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` は存在する。

`session_applications.status` の許可値は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled`。主要RPCとhelper関数は `security_definer = true`。対象RPCには `authenticated EXECUTE` があり、確認画面では `anon` / `public` のEXECUTEは出ていない。

`table_privileges` には `REFERENCES` / `TRIGGER` / `TRUNCATE` などの権限表示が見えたが、これはcatalog読み取り結果であり、preflightがそれらを実行したわけではない。後続実装ではフロントからDB直操作を行わず、RPC経由方針を維持する。

## M-15F APPLY専用SQL作成

M-15Fとして、参加申請時にPC名snapshotを保存するAPPLY専用SQL `docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` を作成した。SQL Editorで適用する場合はこのAPPLY専用ファイルを使い、`020_application_pc_snapshot_rpc_draft.sql` の全文は貼らない。

APPLY専用SQLは `create_application_comment(text,text)` の置換に絞る。参加申請コメント本文は自由本文のままとし、PC名、DiscordユーザーID、ユーザー名をコメント欄へ手入力させない。新規PL申請と `canceled -> pending` の再申請時は、本人の active default PC を `selected_character_id` / `pc_name_snapshot` へ保存する。

PC名未登録でも申請可能で、その場合は `selected_character_id = null` / `pc_name_snapshot = null` とする。GM本人または既存GM/admin helperで管理コメント扱いとなる投稿は `session_comments.is_application = false` として保存し、`session_applications` 行の作成/更新やPC snapshot保存を行わない。コメント編集時はsnapshotを変更しない。

APPLY専用SQLには、`authenticated` のみEXECUTEを許可し、`public` / `anon` のEXECUTEを外す権限文と、実行後確認SELECTを含めた。確認SELECTでは `create_application_comment(text,text)` が1本だけ存在すること、`security_definer = true`、`authenticated EXECUTEあり`、`anon` / `public EXECUTEなし`、`selected_character_id` / `pc_name_snapshot` の存在を確認する。

この記録時点ではAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。
