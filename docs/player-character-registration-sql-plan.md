# M-15B PC名登録・参加申請PC紐付け SQL草案

## 目的

M-15Aで整理したPC名登録方針をもとに、後続レビュー用のSELECT-only preflight SQLと、まだ実行しないSQL草案を作成した。

今回の工程ではSQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行わない。

## 作成ファイル

```text
docs/supabase/sql/019_player_characters_preflight_select_only.sql
docs/supabase/sql/019_player_characters_rpc_draft.sql
```

`019_player_characters_preflight_select_only.sql` はcatalog確認専用で、SELECT / WITH SELECT / information_schema / pg_catalog / to_regclass / to_regprocedure の範囲に限定する。

`019_player_characters_rpc_draft.sql` は実行しない草案で、player_characters、session_applications追加列、PC名管理RPC、参加申請RPCへの影響、テンプレート用RPC候補、権限案、post-apply確認案をまとめる。

## preflightで確認すること

- `public.profiles` の存在と主要列。
- `profiles` と `auth.users` の関係。
- `public.session_applications` の存在。
- `session_applications` の列一覧。
- `session_applications` の主キー。
- `session_applications` の `user_id` / `session_id` / `status` / `comment_id`。
- `session_applications` の既存制約。
- `session_applications` と `public.sessions` / `public.profiles` / `public.session_comments` の外部キー。
- 既存 `player_characters` テーブルの有無。
- 既存 `selected_character_id` / `pc_name_snapshot` 列の有無。
- PC名関連RPC候補の有無。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)`。
- routine privileges。
- RLS policy候補。
- direct table privileges。

## player_characters テーブル案

推奨列:

```text
id uuid primary key default gen_random_uuid()
owner_user_id uuid not null references public.profiles(id) on delete cascade
pc_name text not null
is_default boolean not null default false
is_active boolean not null default true
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

`owner_user_id` は `auth.users(id)` 直接参照ではなく `public.profiles(id)` 参照を推奨する。既存のサイト側ユーザー情報は `profiles.id` を軸にしており、`profiles` 自体が `auth.users(id)` に紐付いているため。

PC名制約:

- `trim` 後に空でない。
- 40文字以内。
- 改行禁止。
- HTMLはUI側でテキスト扱い。

同一ユーザー内の同名PC:

- 初期草案ではDB上の一意制約は置かない。
- 既存PC名の再利用、別システム/別シナリオ由来の同名を許容する。
- UI側では重複注意表示を後続検討にする。

デフォルトPC:

- activeなPCのうち、1ユーザーにつき1件だけ `is_default = true` とする。
- partial unique index `owner_user_id where is_default = true and is_active = true` で制限する案。

削除:

- 物理削除ではなく `is_active = false` を推奨する。
- 過去の参加申請やリザルト出力は `session_applications.pc_name_snapshot` を正として維持する。

## session_applications 追加列案

```text
selected_character_id uuid null references public.player_characters(id) on delete set null
pc_name_snapshot text null
```

方針:

- 参加申請時点のPC名を `pc_name_snapshot` に保存する。
- PC名マスター変更後も、過去申請や承認済みセッションのPC名が勝手に変わらないようにする。
- `selected_character_id` は元キャラクターとの紐付けとして使う。
- テンプレート出力では `pc_name_snapshot` を優先し、未登録時は `PC名未登録` とする。

## RPC案

MVP候補:

```text
get_my_player_characters()
create_player_character(p_pc_name text, p_is_default boolean)
update_player_character(p_character_id uuid, p_pc_name text, p_is_default boolean, p_is_active boolean)
set_default_player_character(p_character_id uuid)
deactivate_player_character(p_character_id uuid)
```

`delete_player_character` という名前はUI文言上の削除に近いが、初期実装では物理削除を避け、RPC名も `deactivate_player_character` を推奨する。UIで「削除」と表示する場合も内部処理は `is_active = false` とする。

参加申請連携候補:

```text
create_application_comment(target_session_id text, comment_body text) の置換
update_my_application_character(target_session_id text, target_character_id uuid)
```

テンプレート用候補:

```text
get_gm_session_approved_template_data(target_session_id text)
```

返却列候補:

```text
session_title text
display_name text
discord_handle text
pc_name_snapshot text
```

返さないもの:

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

## 参加申請との紐付け方針

現行仕様では、参加希望コメント投稿RPC `create_application_comment(target_session_id, comment_body)` がコメント投稿と参加申請行作成を兼ねている。

後続でこのRPCを置換する場合は、申請行作成時または `canceled -> pending` 復帰時に本人のdefault PCを読み、`selected_character_id` と `pc_name_snapshot` を保存する。

PC名未登録の場合:

```text
selected_character_id = null
pc_name_snapshot = null
```

テンプレート出力では `PC名未登録` に丸める。

辞退 / 再申請:

- 辞退時は既存どおり申請行を `canceled` にし、PCスナップショットは残してよい。
- 再申請時は、その時点のdefault PCで `selected_character_id` / `pc_name_snapshot` を更新する。

GMコメント:

- GM本人コメントは参加申請扱いしない既存方針を維持する。
- 現在のフロントはGMコメント投稿後にGM本人申請行を `canceled` へ戻す補正をしている。
- PC名スナップショット追加後も、GM本人が参加者扱いで `accepted` に混ざらないようにする。

## テンプレート変数との関係

`{{approved_call_list}}` に必要なデータ:

```text
session_title
display_name
discord_handle
pc_name_snapshot
```

出力:

```text
Discord：<@DiscordユーザーID>｜ユーザー名：表示名｜PC名：PC名
Discord：登録されていません｜ユーザー名：表示名｜PC名：PC名未登録
```

`{{approved_pc_names}}` に必要なデータ:

```text
pc_name_snapshot
```

出力:

```text
PC名1、PC名2、PC名未登録
```

DiscordユーザーIDは既存方針どおり、17〜20桁の数字なら `<@ID>` に変換し、未登録または形式不正なら `登録されていません` とする。

## 既存GM連絡先RPCとの関係

`get_gm_session_accepted_contacts(target_session_id text)` は現在 `display_name` / `discord_handle` のみを返し、フロントJSもこの返却列を前提に検査している。

そのためM-15B草案では、既存RPCをすぐPC名付きへ変更せず、テンプレート用の別RPC `get_gm_session_approved_template_data(target_session_id text)` 候補を置いた。

後続M-15Fで、以下のどちらかを選ぶ。

- テンプレートUIだけ別RPCを使う。
- JS側の返却列検査と表示を更新した上で、既存連絡先RPCをPC名付きへ置換する。

## 段階実装案

1. M-15B: preflight結果記録とSQL草案レビュー。
2. M-15C: 019_player_characters APPLY専用SQL作成・最終レビュー。
3. M-15D: SQL Editor適用と結果記録。
4. M-15E: mypage PC名登録UI。
5. M-15F: 参加申請へのPC名スナップショット接続。
6. M-15G: GM向け承認済み参加者情報のPC名対応。
7. M-15H: テンプレート変数置換UI。

## 今回やらないこと

- SQL Editor実行。
- DB構造変更。
- RPC作成 / 置換。
- GRANT / REVOKE。
- フロントUI実装。
- PC名登録UI実装。
- 参加申請UI変更。
- テンプレート保存機能実装。
- Discord実送信。
- Edge Function deploy。
- `updates.json` 変更。
- service_role key利用。
- secret類の出力。
- commit / push。

## M-15B preflight結果・草案点検

ユーザーがSupabase SQL Editorで実行したのは `019_player_characters_preflight_select_only.sql` のSELECT-only preflightのみ。
`019_player_characters_rpc_draft.sql`、CREATE TABLE、ALTER TABLE、CREATE FUNCTION、GRANT / REVOKE、DB構造変更、RPC作成は未実行。

preflight結果:

```text
player_characters table: missing
session_applications.selected_character_id: missing
session_applications.pc_name_snapshot: missing
profiles.id: uuid / NOT NULL
session_applications.user_id: uuid / NOT NULL
session_applications.session_id: text / NOT NULL
```

追加確認した制約:

```text
profiles.id:
PRIMARY KEY
FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE

session_applications.user_id:
FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE

session_applications.session_id:
FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE

session_applications:
UNIQUE(session_id, user_id)
PRIMARY KEY(id)
```

`session_applications.comment_id` は `session_comments(id)` を参照する既存制約があり、削除時挙動は既存挙動維持として扱う。

SQL草案点検結果:

- `player_characters.owner_user_id` は `public.profiles(id)` 参照で、preflight結果と矛盾しない。
- `session_applications.selected_character_id` は `public.player_characters(id) on delete set null` 参照で、将来PC行が消えても申請側の参照だけを外せる。
- `session_applications.pc_name_snapshot` は nullable text で、テンプレートや履歴表示ではこちらを正とする。
- 既存 `UNIQUE(session_id, user_id)` と矛盾せず、申請行は従来どおりセッション/ユーザー単位で1件を維持する。
- 既存 `session_applications.user_id = profiles(id)` 方針と矛盾しない。
- PC名の削除は物理削除ではなく `is_active = false` を基本にする。
- `selected_character_id` が指すPCを非アクティブ化しても、`pc_name_snapshot` は残る設計にする。

`selected_character_id` の外部キー方針は `references public.player_characters(id) on delete set null` を推奨する。
理由は、PC行が何らかの理由で削除されても、過去申請のPC名スナップショットを `pc_name_snapshot` として残し、テンプレートや履歴表示を維持するため。

次工程方針:

```text
M-15C: 019_player_characters APPLY専用SQL作成・最終レビュー
M-15D: SQL Editor適用
M-15E: mypage PC名登録UI
```

今回CodexはSQL Editor追加実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15C APPLY専用SQL作成

M-15Cとして、PC名登録・参加申請PC紐付け用のAPPLY専用SQLファイル `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を作成した。
SQL Editorで実行する場合は、この `apply_reviewed.sql` の全文のみを使い、`019_player_characters_rpc_draft.sql` の全文は貼らない。

preflight / draft / apply は以下のように分離する。

```text
preflight:
docs/supabase/sql/019_player_characters_preflight_select_only.sql
SELECT-only。DBを変更しない。

draft:
docs/supabase/sql/019_player_characters_rpc_draft.sql
検討用草案。参加申請RPC置換案やテンプレート用RPC候補も含むため、そのまま貼らない。

apply:
docs/supabase/sql/019_player_characters_apply_reviewed.sql
レビュー済みAPPLY専用。SQL Editorで実行する対象を固定する。
```

APPLY専用SQLに含めた内容:

- `public.player_characters` テーブル作成。
- `session_applications.selected_character_id` / `pc_name_snapshot` 追加。
- PC名の空文字禁止、40文字上限、単一行制約。
- `owner_user_id` / active検索用index。
- 有効なdefault PCを1ユーザー1件にする部分unique index。
- `player_characters_set_updated_at` trigger。
- `player_characters` RLS有効化と本人select policy。
- 書き込みはsecurity definer RPC経由とし、直接insert/update/delete policyは追加しない方針。
- PC管理RPC 5本: `get_my_player_characters`、`create_player_character`、`update_player_character`、`set_default_player_character`、`deactivate_player_character`。
- `public` / `anon` からのEXECUTE revoke、`authenticated` へのEXECUTE grant。
- table / column / FK / RPC security definer / EXECUTE権限の実行後確認SELECT。

参加申請へのdefault PC自動採用、`create_application_comment` 置換、`update_my_application_character`、テンプレート用 `get_gm_session_approved_template_data` はM-15F以降に分離した。
後続では、参加申請時にdefault PCを `pc_name_snapshot` へ保存し、GMコメントは参加申請扱いしない方針、辞退 / 再申請時のPC名扱いを改めて整理する。

APPLYはまだ未実行。
今回CodexはSQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE実行、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushを行っていない。

## M-15D APPLY結果

M-15Dとして、ユーザーがSupabase SQL Editorで `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を適用した。
PC名登録・参加申請PC紐付け用のDB変更は適用済み。

確認結果:

- `player_characters` table は作成済みで `ok = true`。
- `player_characters.id`、`owner_user_id`、`pc_name`、`is_default`、`is_active` は存在し、すべて `ok = true`。
- `session_applications.selected_character_id` と `session_applications.pc_name_snapshot` は作成済みで `ok = true`。
- `player_characters.owner_user_id` は `profiles(id)` を参照し、FK確認 `ok = true`。
- `session_applications.selected_character_id` は `player_characters(id)` を参照し、FK確認 `ok = true`。
- PC管理RPC 5本は作成済み。`create_player_character(text, boolean)`、`deactivate_player_character(uuid)`、`get_my_player_characters()`、`set_default_player_character(uuid)`、`update_player_character(uuid, text, boolean, boolean)` はそれぞれ `function_count = 1`、`security_definer = true`。
- RPC権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて `ok = true`。

DB側の変更は、`player_characters` テーブル、`session_applications.selected_character_id` / `pc_name_snapshot`、PC管理RPC 5本、関連index / constraint / RLS / 権限設定の適用。
実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、secret類の出力、`updates.json` 変更は行っていない。

次工程はM-15Eとして mypage PC名登録UI を実装する想定。
今回CodexはSQL Editor追加実行、DB構造追加変更、RPC再作成、GRANT / REVOKE再実行、実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。
## M-15E mypage PC名登録UI接続

M-15Eで、SQL Editor適用済みのPC管理RPC 5本をmypage UIから利用する接続を行った。利用するRPCは `get_my_player_characters()`、`create_player_character(text, boolean)`、`update_player_character(uuid, text, boolean, boolean)`、`set_default_player_character(uuid)`、`deactivate_player_character(uuid)`。

今回のUI実装ではDB構造追加変更、RPC再作成、GRANT / REVOKE再実行は行っていない。PC名の非表示化は `deactivate_player_character` に任せ、`player_characters` 行の物理削除は行わない。

参加申請時に `session_applications.selected_character_id` / `pc_name_snapshot` へ反映する処理、承認済み参加者一覧やテンプレート用データ取得のPC名対応は後続M-15F以降で扱う。

raw DB uuid / owner_user_id / Supabase user_id / email / token / secret類はUI・DOM・consoleへ出さない。DOM上の操作キーは `pc-0` などのローカル値だけを使う。

今回CodexはSQL Editor追加実行、DB追加変更、RPC再作成、GRANT / REVOKE再実行、実データ投入、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-15F 参加申請PC名スナップショットRPC草案

M-15Fとして、参加申請コメント投稿時に既定PCを `session_applications.selected_character_id` / `pc_name_snapshot` へ自動保存するためのpreflight SQLとRPC草案を作成した。

作成したpreflight SQLは `docs/supabase/sql/020_application_pc_snapshot_preflight_select_only.sql`。`session_applications` のPC snapshot列、`player_characters` のPC管理列、`session_comments.is_application`、`create_application_comment(text, text)` と関連RPCの関数契約、権限、RLS policyをSELECT-onlyで確認する。schema、data、privilegesは変更しない。

作成したRPC草案は `docs/supabase/sql/020_application_pc_snapshot_rpc_draft.sql`。既存の `create_application_comment(target_session_id text, comment_body text)` と同じシグネチャを維持し、フロントからPC名、DiscordユーザーID、ユーザー名、character idを渡さない。参加申請コメントは自由本文のままとし、コメント本文から識別情報を解析しない。

新規PL申請では、ログインユーザー本人のactive default PCを読み取り、`selected_character_id` と `pc_name_snapshot` に保存する。既定PCがない場合は `null` のまま申請を許可する。辞退済みからの再申請では、その時点の既定PCでsnapshotを更新する。コメント編集時はsnapshotを変更しない。

GM本人コメントは許可するが、参加申請として扱わない。RPC草案ではGMコメントを `session_comments.is_application = false` として保存し、`session_applications` 行の作成/更新やPC snapshot保存を行わない。GMコメントは参加人数、申請者一覧、承認済み連絡先、テンプレート変数対象から除外する方針を維持する。

M-15GではGM向け承認済み参加者一覧/連絡先表示にPC名を含める。M-15Hでは `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` のテンプレート変数置換に接続する。今回CodexはSQL Editor実行、DB構造変更、RPC作成/置換、GRANT / REVOKE実行、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-15D補正 selected_character_id FK ON DELETE SET NULL

M-15D適用後確認で、`session_applications.selected_character_id` のFKが `FOREIGN KEY (selected_character_id) REFERENCES player_characters(id)` となっており、期待方針だった `ON DELETE SET NULL` が付いていないことを確認した。M-15F以降のPC snapshot接続へ進む前の補正として、FKを `ON DELETE SET NULL` 付きで作り直すSQLを用意した。

作成したpreflight SQLは `docs/supabase/sql/021_fix_selected_character_fk_preflight_select_only.sql`。現在のFK定義、constraint名、`player_characters` table存在、`session_applications.selected_character_id` 存在、既存 `selected_character_id` のNULL/非NULL件数、参照先 `player_characters.id` との整合性をSELECT-onlyで確認する。

作成したAPPLY専用SQLは `docs/supabase/sql/021_fix_selected_character_fk_apply_reviewed.sql`。既存FK `session_applications_selected_character_id_fkey` をdropし、同名で `references public.player_characters(id) on delete set null` として作り直す。末尾に、FKが存在し、参照先が `player_characters(id)` で、definition / `confdeltype` が `ON DELETE SET NULL` 相当であることを確認するSELECTを入れた。

今回CodexはSQL Editor実行、DB構造変更、ALTER TABLE実行、RPC変更、GRANT / REVOKE、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushを行っていない。

## M-15D補正preflight結果

ユーザーがSupabase SQL Editorで `docs/supabase/sql/021_fix_selected_character_fk_preflight_select_only.sql` を実行し、`selected_character_fk_has_on_delete_set_null = true` を確認した。現DB上では、`session_applications.selected_character_id` のFKはすでに `ON DELETE SET NULL` 相当として確認済み。

このため、`docs/supabase/sql/021_fix_selected_character_fk_apply_reviewed.sql` は未実行のまま、現時点では実行不要と整理する。前回の `ON DELETE SET NULL` 不足は、表示上の見切れまたは確認不足だった可能性として扱う。

DB追加変更、ALTER TABLE実行、RPC変更、GRANT / REVOKE実行は行っていない。M-15Fは参加申請PC名スナップショット接続へ戻る。

## M-15F preflight確認結果

ユーザーが修正版 `020_application_pc_snapshot_preflight_select_only.sql` をSQL Editorで実行したところ、`ERROR: 42809: "array_agg" is an aggregate function` で途中停止した。このpreflightはSELECT-onlyであり、DB変更は発生していない。

小型確認SQLでは、M-15Fに必要な前提として `public.player_characters`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` の存在を確認済み。`session_applications.status` は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` を許可しており、RPC草案の `pending` / `canceled` と矛盾しない。

主要RPCとhelper関数は `security_definer = true`。対象RPCは `authenticated EXECUTE` ありで、確認画面では `anon` / `public` のEXECUTEは出ていない。020 preflightは `pg_get_functiondef` を使わず、必要なRPCだけを `to_regprocedure`、`pg_get_function_arguments`、`pg_get_function_result`、`prosecdef`、`proconfig`、routine privilegesで確認する形へ修正した。

RPC草案 `020_application_pc_snapshot_rpc_draft.sql` は既存signature、security definer、`set search_path = ''`、PC名未登録でも申請可能、GMコメント非申請扱い、新規PL申請時active default PC snapshot、再申請時snapshot更新、コメント編集時snapshot維持の方針と一致する。今回CodexはSQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、APPLY専用SQL作成、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushを行っていない。

## M-15F preflight再実行成功

ユーザーがSupabase SQL Editorで修正版 `020_application_pc_snapshot_preflight_select_only.sql` を実行し、preflightは成功した。前回発生していた `array_agg` aggregate function エラーは解消済み。

確認済みの前提は、`public.player_characters`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot`、`session_applications UNIQUE(session_id, user_id)`、`create_application_comment(text,text)`、`cancel_my_session_application(text)`、`get_gm_session_accepted_contacts(text)`、`get_my_player_characters()` の存在。`session_applications.status` 許可値は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled`。

主要RPCとhelper関数は `security_definer = true`。対象RPCは `authenticated EXECUTE` ありで、確認結果画面では `anon` / `public` EXECUTEは出ていない。`table_privileges` に `REFERENCES` / `TRIGGER` / `TRUNCATE` 等が表示されたが、これは権限一覧の読み取り結果であり、SQLがTRUNCATE等を実行したわけではない。後続実装ではフロント直操作を行わずRPC経由を維持する。

`020_application_pc_snapshot_rpc_draft.sql` は、既存signature、`security definer`、`set search_path = ''`、authenticated EXECUTEのみ、status許可値、PC名未登録許可、GMコメント非申請扱い、新規PL申請時active default PC snapshot、再申請時snapshot更新、コメント編集時snapshot維持の各方針と矛盾しない。今回CodexはSQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、APPLY専用SQL作成、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushを行っていない。

## M-15F application PC snapshot APPLY専用SQL作成

M-15FのAPPLY準備として `docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` を作成した。対象は `public.create_application_comment(text,text)` の置換のみで、`player_characters` や `session_applications` の構造変更は含めない。

APPLYでは、未ログインを拒否し、PL向けには既存の `can_apply_to_session(text)` を維持する。GM本人または既存 `is_session_gm(text)` helperで管理コメント扱いとなる投稿は、コメント投稿を許可しつつ参加申請扱いにしない。GMコメントでは `session_applications` を作成/更新せず、`selected_character_id` / `pc_name_snapshot` も保存しない。

PLの新規申請時は `owner_user_id = auth.uid()` / `is_active = true` / `is_default = true` のPCを取得し、`selected_character_id` と `pc_name_snapshot` へ保存する。既定PCがない場合も申請可能で、snapshot列は `null` のままとする。`canceled -> pending` の再申請時は、その時点のactive default PCでsnapshotを更新する。既存の `pending` / `accepted` / `rejected` / `waitlisted` 行にコメントを追記する場合、およびコメント編集時はsnapshotを維持する。

APPLY専用SQLには `revoke execute` / `grant execute` による権限整理と、関数本数、`security_definer`、signature、`authenticated` / `anon` / `public` のEXECUTE状態、`selected_character_id` / `pc_name_snapshot` の存在を確認するSELECTを含めた。

この工程ではAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、commit / pushなし。

### APPLY前レビュー修正

`020_application_pc_snapshot_apply_reviewed.sql` の適用前レビューで、管理コメント判定を `public.is_admin() or public.is_session_gm(v_target_session_id)` に修正した。GM本人だけでなくadminコメントも管理コメントとして扱い、参加申請行やPC snapshotを作成/更新しない。

コメント保存値はtrim後の `v_comment_body` を使うように修正した。SQL Editor実行、DB構造変更、RPC作成/置換実行、GRANT / REVOKE実行は行っていない。

## M-15F application PC snapshot APPLY結果

M-15Fとして、`docs/supabase/sql/020_application_pc_snapshot_apply_reviewed.sql` をSupabase SQL Editorに適用し、`create_application_comment(text,text)` の置換に成功した。

適用後確認では、`function_count = 1`、`all_security_definer = true`、signatureは `create_application_comment(text,text)`、function configに `search_path` 設定あり。権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、確認結果はいずれも `ok = true`。`session_applications.selected_character_id` / `pc_name_snapshot` の存在も確認済み。

このRPC置換により、PL新規申請・再申請時は現在のactive default PCをsnapshotする。PC名未登録でも申請可能。GM/admin管理コメントは参加申請扱いにせず、`session_applications` 作成/更新や `selected_character_id` / `pc_name_snapshot` 保存を行わない。コメント本文は自由本文で、PC名やDiscordユーザーIDを本文に書かせない。

実データ投入、フロントUI変更、参加申請UI変更、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。

## M-15F 実ブラウザ / SQL確認結果

通常PLの参加申請で、`session_applications.pc_name_snapshot` に既定PC名が保存され、`selected_character_id` も紐付いた。SQL確認では `linked_pc_name` と `pc_name_snapshot` が一致した。

`status = accepted` の申請でもPC名snapshotが保持されていることを確認した。参加申請コメント本文にPC名やDiscordユーザーIDを書かせる設計ではなく、登録済み情報から自動紐付けする方針で実動作確認済み。

raw user_id / application_id / selected_character_id の実値、ユーザー名やPC名の実値はdocsへ記録しない。SQL Editor追加実行、DB追加変更、RPC変更、フロントUI変更、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。

## M-15G GM向け承認済み参加者PC名表示RPC草案

M-15Gとして、`get_gm_session_accepted_contacts(text)` にPC名を追加するためのpreflight SELECT-only SQLとRPC草案を作成した。

preflightは `docs/supabase/sql/022_gm_accepted_contacts_pc_name_preflight_select_only.sql`。既存RPCのsignature / 戻り値、`security_definer`、`authenticated EXECUTE`、`anon` / `public EXECUTEなし`、`pc_name_snapshot` / `selected_character_id`、status許可値、`profiles.display_name` / `discord_handle`、`player_characters`、`sessions.gm_user_id`、helper関数を確認する。`pg_get_functiondef` は使わない。

RPC草案は `docs/supabase/sql/022_gm_accepted_contacts_pc_name_rpc_draft.sql`。既存入力signature `target_session_id text` を維持し、既存列 `display_name` / `discord_handle` に加えて `discord_mention` / `pc_name` / `pc_name_missing` を追加する案とした。戻り値型変更があるため、後続APPLY時はdrop/recreateまたは別RPC化をレビューする。

PC名は `session_applications.pc_name_snapshot` を正とし、未登録は `PC名未登録`。DiscordユーザーIDは17〜20桁の数字のみ `<@ID>` にし、未登録または形式不正は `登録されていません` とする。GM本人はRPC内で除外し、raw user_id / email / token / selected_character_id などは返さない。

この工程ではSQL Editor未実行、DB構造変更なし、RPC変更なし、GRANT / REVOKE未実行、APPLY専用SQL作成なし、フロントUI実装なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更。

## M-15G preflight結果

`022_gm_accepted_contacts_pc_name_preflight_select_only.sql` のSQL Editor実行により、現行 `get_gm_session_accepted_contacts(text)` は `TABLE(display_name text, discord_handle text)` を返す2列構造と確認した。`security_definer = true`、function configに `search_path` 設定あり。権限は `authenticated EXECUTEあり`、`anon` / `public EXECUTEなし`。

M-15GでPC名を返すには戻り値列追加が必要。互換性のため既存列 `display_name` / `discord_handle` は維持し、追加列候補を `discord_mention` / `pc_name` / `pc_name_missing` とする。`pc_name` は `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録`。過去申請にはsnapshotなしが混在するため、このfallbackを前提にする。

戻り値型変更のため、同名RPCで進める場合は後続APPLYでdrop/recreateが必要になる可能性がある。代替として `get_gm_session_accepted_contacts_v2(text)` のような別RPC化も検討する。今回はSQL Editor追加実行、DB構造変更、RPC作成/置換、GRANT / REVOKE、APPLY専用SQL作成は行っていない。

## M-15G APPLY専用SQL作成

GM/admin向け承認済み参加者PC名表示RPCのAPPLY専用SQLとして `docs/supabase/sql/022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を作成した。既存 `get_gm_session_accepted_contacts(text)` は2列返却のため、戻り値型変更に合わせてdrop/recreateする方針。

既存列 `display_name` / `discord_handle` は維持し、`discord_mention` / `pc_name` / `pc_name_missing` を追加する。`pc_name` は `session_applications.pc_name_snapshot` を正とし、null/空は `PC名未登録`。DiscordユーザーID未登録・形式不正時は `登録されていません` とし、生の不正値や raw user_id / email / token は返さない。

APPLY専用SQLには、`security definer`、`set search_path = ''`、`authenticated` のみEXECUTE、`anon` / `public` EXECUTE不可、関数本数・戻り値列・権限の実行後確認SELECTを含めた。今回CodexはAPPLY未実行、SQL Editor未実行、DB構造変更なし、RPC作成/置換未実行、GRANT / REVOKE未実行、フロントUI実装なし。

## M-15G APPLY結果

ユーザーがSupabase SQL Editorで `022_gm_accepted_contacts_pc_name_apply_reviewed.sql` を適用し、`get_gm_session_accepted_contacts(text)` のdrop/recreateが成功した。

確認結果は `function_count = 1`、`all_security_definer = true`、`has_search_path_config = true`、signature `get_gm_session_accepted_contacts(text)`。戻り値列は `display_name` / `discord_handle` / `discord_mention` / `pc_name` / `pc_name_missing` で、各列の存在確認もtrue。

権限は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし`。`pc_name` は `session_applications.pc_name_snapshot` を正とし、PC名未登録時は `PC名未登録`。DiscordユーザーID未登録・形式不正時は `登録されていません`。raw user_id / email / token は返さない。実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行っていない。

今回CodexはSQL Editor追加実行、DB構造変更、RPC再作成、GRANT / REVOKE再実行、commit / pushを行っていない。

## M-15G フロント実装

session-detailのGM/admin向け承認済み参加者連絡先表示で、RPC戻り値の `discord_mention` / `pc_name` / `pc_name_missing` を扱うようにした。既存列 `display_name` / `discord_handle` は互換のため維持し、画面では `display_name` を「ユーザー名」として表示する。

PC名は `session_applications.pc_name_snapshot` 由来の `pc_name` を表示し、未登録時は `PC名：PC名未登録`。DiscordユーザーID未登録・形式不正時は `Discord：登録されていません`。画面表示とコピー内容は `Discord：discord_mention｜ユーザー名：display_name｜PC名：pc_name` のラベル付き1人1行とする。

raw user_id / email / token / selected_character_id / application_id は画面・DOM・console・コピーに出さない。SQL Editor未実行、DB構造変更なし、RPC変更なし、Discord実送信なし、Edge Function deployなし。
