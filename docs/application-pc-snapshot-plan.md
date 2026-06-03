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

### APPLY前レビュー修正

適用前の最終確認として、管理コメント判定を `public.is_admin() or public.is_session_gm(v_target_session_id)` に修正した。これによりadminが他GMのセッションへコメントした場合もPL参加申請扱いにならず、`session_applications` 作成/更新やPC snapshot保存を行わない。

また、`session_comments.body` へ保存する値をtrim後の `v_comment_body` に揃えた。コメント本文は自由本文のまま維持するが、前後空白は保存しない方針とする。この修正時点でもAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行。

## M-15F APPLY結果

M-15Fとして、`docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` をSupabase SQL Editorに適用済み。`create_application_comment(text,text)` の置換は成功した。

確認結果は、`function_count = 1`、`all_security_definer = true`、signatureは `create_application_comment(text,text)`、function configに `search_path` 設定あり。権限確認では `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて `ok = true`。`session_applications.selected_character_id` / `pc_name_snapshot` の存在も確認済み。

適用後の方針として、PLの新規申請・再申請時は既定PCをsnapshotする。PC名未登録でも申請可能。GM/admin管理コメントは参加申請扱いにせず、snapshotしない。参加申請コメント本文は自由本文のままで、PC名やDiscordユーザーIDを本文に書かせない。

実データ投入、フロントUI変更、参加申請UI変更、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。

## M-15F 実動作確認結果

実ブラウザ / SQL確認で、通常PLの参加申請時に `session_applications.pc_name_snapshot` へ既定PC名が保存され、`selected_character_id` も紐付くことを確認した。確認用SELECT上では `linked_pc_name` と `pc_name_snapshot` が一致した。

`status = accepted` の申請でもPC名snapshotは保持されていた。これにより、PC名やDiscordユーザーIDを参加申請コメント本文へ書かせず、mypage登録情報とプロフィール登録情報から自動で紐付けるM-15F方針が成立していることを確認した。

この記録では raw user_id / application_id / selected_character_id の実値、ユーザー名、PC名の実値は記録しない。SQL Editor追加実行、DB追加変更、RPC変更、フロントUI変更、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。

## M-15G GM向け承認済み参加者PC名表示RPC準備

M-15Gとして、GM/admin向け承認済み参加者連絡先へPC名を追加するためのpreflight専用SQLとRPC草案を作成した。

作成ファイルは `docs/supabase/sql/022_gm_accepted_contacts_pc_name_preflight_select_only.sql`、`docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql`、`docs/gm-accepted-contacts-pc-name-plan.md`。既存 `get_gm_session_accepted_contacts(text)` は現在 `display_name` / `discord_handle` のみを返し、フロントもこの2列だけを許可しているため、PC名列追加は後続APPLYとUI更新を同じ工程で扱う。

PC名は `session_applications.pc_name_snapshot` を正とし、未登録時は `PC名未登録` とする。DiscordユーザーIDは `profiles.discord_handle` から `<@ID>` へ変換表示し、未登録または形式不正は `登録されていません` とする。raw user_id / email / token / selected_character_id などの内部情報は返さない方針を維持する。

この工程ではSQL Editor未実行、DB構造変更なし、RPC変更なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G preflight結果との接続

ユーザーが `022_gm_accepted_contacts_pc_name_preflight_select_only.sql` をSQL Editorで実行し、既存 `get_gm_session_accepted_contacts(text)` は `display_name` / `discord_handle` の2列のみを返すことを確認した。`security_definer = true`、`search_path` 設定あり、`authenticated EXECUTEあり`、`anon` / `public EXECUTEなし`。

PC名をGM向け承認済み参加者連絡先へ出すには戻り値列追加が必要。既存列を維持し、追加列として `discord_mention` / `pc_name` / `pc_name_missing` を検討する。`pc_name` はM-15Fで保存する `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録` とする。過去申請ではsnapshotなしが混在するため、fallback表示は必須。

同名RPCの戻り値型変更はdrop/recreateが必要になる可能性がある。後続APPLYでは既存signature維持のdrop/recreate案と、v2 RPC案を比較する。今回はSQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、APPLY専用SQL作成、フロントUI実装は行っていない。

## M-15G APPLY専用SQL作成

`get_gm_session_accepted_contacts(text)` にPC名を返すため、APPLY専用SQL `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を作成した。既存RPCは `display_name` / `discord_handle` の2列返却だったため、戻り値型変更に備えてdrop/recreate方針を採用した。

戻り値は `display_name` / `discord_handle` を維持し、`discord_mention` / `pc_name` / `pc_name_missing` を追加する。`pc_name` はM-15Fで保存する `session_applications.pc_name_snapshot` を正とし、PC名未登録時は `PC名未登録` に丸める。DiscordユーザーID未登録・形式不正時は `登録されていません` とし、raw user_id / email / token は返さない。

APPLY専用SQLには実行後確認SELECTを含めたが、今回はAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし。
