# M-15G GM向け承認済み参加者PC名表示RPC計画

## 目的

M-15Fで参加申請時の `session_applications.pc_name_snapshot` 保存が確認できたため、M-15GではGM/admin向けの承認済み参加者連絡先RPCにPC名を追加するためのpreflight SQLとRPC草案を用意する。

後続の `{{approved_call_list}}` / `{{approved_pc_names}}` では、承認済み参加者のDiscordメンション、ユーザー名、PC名をまとめて出力する。

## 現在の調査結果

既存RPC `get_gm_session_accepted_contacts(target_session_id text)` は、現在 `display_name` / `discord_handle` の2列を返す。`assets/js/sessionDetailApplicationComments.js` もGM連絡先RPCの返却列を `display_name` / `discord_handle` に限定して検査している。

そのため、PC名列を追加するAPPLYとフロントUI更新は同じ後続工程で扱う。M-15GではSQL Editor実行、RPC作成/置換、フロントUI実装は行わない。

## 作成したSQL

SELECT-only preflight:

```text
docs/supabase/sql/022_gm_accepted_contacts_pc_name_preflight_select_only.sql
```

確認内容:

- `get_gm_session_accepted_contacts(text)` のsignature / 戻り値構造
- `security_definer` / `search_path`
- `authenticated EXECUTE` と `anon` / `public` EXECUTEなし
- `session_applications.pc_name_snapshot` / `selected_character_id`
- `session_applications.status` 許可値と `accepted`
- `profiles.display_name` / `profiles.discord_handle`
- `player_characters` table
- `sessions.gm_user_id`
- `has_role(text)` / `is_admin()` / `is_session_gm(text)`
- accepted申請の安全な集計

preflightは `pg_get_functiondef` を使わず、`pg_get_function_arguments` / `pg_get_function_result` / `prosecdef` / `proconfig` / routine privileges を使う。

RPC草案:

```text
docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql
```

## RPC更新方針

対象RPCは既存の `get_gm_session_accepted_contacts(target_session_id text)` を維持する。ただし戻り値列を増やすため、実APPLY時はPostgreSQLの返却型変更制約に注意し、drop/recreateまたは別RPC化をレビューする。

追加候補列:

```text
display_name text
discord_handle text
discord_mention text
pc_name text
pc_name_missing boolean
```

既存列 `display_name` / `discord_handle` は互換のため維持する。PC名は追加列として増やし、フロント側の許可列と表示UIを後続で更新する。

## PC名表示方針

`session_applications.pc_name_snapshot` を正とする。`player_characters.pc_name` は参考に留め、テンプレートやGM向け表示では過去申請時点のsnapshotを優先する。

`pc_name_snapshot` が未登録または空の場合は `PC名未登録` と扱い、`pc_name_missing = true` を返す案とする。

## DiscordユーザーID方針

`profiles.discord_handle` はDiscordユーザーIDの保存先として扱う。17〜20桁の数字なら `<@ID>` 形式を生成する。

未登録または形式不正の場合、GM向け表示・コピー用には `登録されていません` とする。生の形式不正値は返さない。

## GM本人除外方針

GM本人は承認済み参加者一覧に混ぜない。RPC内で `sessions.gm_user_id` と `session_applications.user_id` を比較して除外し、戻り値には内部IDを含めない。

M-15F以降、GM/admin管理コメントは参加申請扱いにしないため、新規の管理コメントは `session_applications` に混ざらない方針。

## 返さない情報

以下はRPC戻り値、画面、DOM、console、docsへ出さない。

```text
user_id
email
application_id
comment_id
selected_character_id
owner_user_id
role
token
key
secret類
```

## 今回やらないこと

- SQL Editor実行
- DB構造変更
- RPC作成 / 置換
- GRANT / REVOKE
- APPLY専用SQL作成
- フロントUI実装
- テンプレート保存機能
- テンプレート変数置換UI
- Discord実送信
- Edge Function deploy
- `updates.json` 変更
- service_role key利用
- secret類の出力
- commit / push

## M-15G preflight結果

ユーザーがSupabase SQL Editorで `docs/supabase/sql/022_gm_accepted_contacts_pc_name_preflight_select_only.sql` を実行し、既存 `get_gm_session_accepted_contacts(text)` の現在状態を確認した。

確認結果は、signature `get_gm_session_accepted_contacts(text)`、arguments `target_session_id text`、result type `TABLE(display_name text, discord_handle text)`。現在の戻り値は `display_name` / `discord_handle` の2列のみ。`security_definer = true` で、function configには `search_path` 設定がある。

権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし`。承認済み申請の集計では `pc_name_snapshot` あり/なしが混在していたが、M-15F以前の過去申請にはsnapshotがないため自然な状態として扱う。

PC名表示にはRPC戻り値列の追加が必要。既存列 `display_name` / `discord_handle` は互換性のため維持し、追加列候補は `discord_mention` / `pc_name` / `pc_name_missing` とする。同名RPCで戻り値型を変更する場合、PostgreSQLでは単純な `create or replace function` では失敗する可能性があるため、後続APPLYでは既存 `get_gm_session_accepted_contacts(text)` をdrop/recreateする案A、または `get_gm_session_accepted_contacts_v2(text)` のような別RPCを作る案Bをレビューする。

基本方針は、既存フロントとの互換性を意識しつつ、同じ工程でフロント許可列とUIを更新できるなら既存signature維持のdrop/recreateを優先する。APPLY専用SQLは今回作成せず、SQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、フロントUI実装は行っていない。

`pc_name` は `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録` に丸める。`discord_handle` が17〜20桁の数字なら `discord_mention` を `<@ID>` として生成し、未登録または形式不正は `登録されていません` とする。形式不正値、raw user_id / email / token / selected_character_id / application_id は返さない。GM本人は承認済み参加者一覧から除外する。

## M-15G APPLY専用SQL作成

M-15Gとして、GM/admin向け承認済み参加者一覧へPC名を返すためのAPPLY専用SQL `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を作成した。SQL Editorで適用する場合はこのAPPLY専用ファイルを使い、`022_gm_accepted_contacts_pc_name_rpc_draft.sql` の全文は貼らない。

既存 `get_gm_session_accepted_contacts(text)` は `display_name` / `discord_handle` の2列返却だったため、戻り値型変更に備えて `drop function if exists public.get_gm_session_accepted_contacts(text);` の後に同名・同signatureで再作成するdrop/recreate方針とした。既存列 `display_name` / `discord_handle` は維持し、追加列として `discord_mention` / `pc_name` / `pc_name_missing` を返す。

`pc_name` は `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録`、`pc_name_missing = true` とする。DiscordユーザーIDは17〜20桁の数字のみ `discord_handle` に残し、`discord_mention` は `<@ID>` とする。未登録・形式不正の場合は `discord_mention = 登録されていません` とし、形式不正の生値は返さない。

対象は `session_applications.status = 'accepted'` のみ。GM本人は `sessions.gm_user_id` との比較で除外し、raw user_id / email / token / selected_character_id / application_id は戻り値に含めない。権限は未ログイン拒否、GMまたはadminのみ取得可、`security definer`、`set search_path = ''`、`authenticated` のみEXECUTE、`anon` / `public` EXECUTE不可の方針。

APPLY専用SQL末尾には、関数本数、signature、`security_definer`、`search_path` 設定、戻り値列、`authenticated` / `anon` / `public` のEXECUTE状態を確認するSELECTを含めた。今回CodexはAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G APPLY結果

ユーザーがSupabase SQL Editorで `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を適用し、`get_gm_session_accepted_contacts(text)` のdrop/recreateが成功した。

確認結果は `function_count = 1`、`all_security_definer = true`、`has_search_path_config = true`、signature `get_gm_session_accepted_contacts(text)`。権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて `ok = true`。

戻り値には `display_name` / `discord_handle` / `discord_mention` / `pc_name` / `pc_name_missing` が含まれる。既存列 `display_name` / `discord_handle` は維持し、`pc_name` は `session_applications.pc_name_snapshot` を正とする。PC名未登録時は `PC名未登録`、DiscordユーザーID未登録・形式不正時は `登録されていません` とし、raw user_id / email / token は返さない方針を維持する。

実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。今回CodexはSQL Editor追加実行、DB構造変更、RPC再作成、GRANT / REVOKE再実行、commit / pushを行っていない。
