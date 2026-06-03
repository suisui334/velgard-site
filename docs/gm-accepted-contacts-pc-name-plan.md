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
