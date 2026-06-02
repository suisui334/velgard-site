# M-14D-8 update_session_post RPC / UI接続計画

## 目的

`session-post.html` でselectから選択した既存依頼書をフォームへ反映できる状態になったため、次工程で編集保存へ進むための `update_session_post` RPC草案とUI接続方針を整理する。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、フロントUI接続実装、Edge Function deploy、Discord実送信は行わない。

## 対象範囲

- `public.sessions` の既存行を、GM/adminが安全に更新するためのRPC草案。
- SQL適用前レビュー用のpreflight / stop条件。
- `session-post.html` の編集保存UI接続計画。
- Discord同期メタデータの更新方針。
- RLS / 権限 / smoke test観点。

対象外:

- SQL Editorでの適用。
- 実DBへのRPC作成。
- Edge FunctionからのDiscord送信。
- 公開切替、削除、募集終了ボタンの実装。
- `updates.json` 変更。

## 既存仕様との照合

既存 `create_session_post` は `docs/supabase/sql/016_session_posting_end_at_draft.sql` 適用後、末尾に `p_end_at text default null` を持つ。
戻り値は `session_id` / `discord_sync_status` / `created_at` に限定され、内部ID、email、Discord credential類は返さない。

既存 `public.sessions.id` は `text` で、`public.is_session_gm(target_session_id text)` もtext前提。
そのため、引き継ぎ案にあった `p_session_id uuid` は採用せず、SQL草案では `p_session_id text` とする。

既存 `create_session_post` の人数引数は `p_player_min` / `p_player_max` であるため、`p_min_players` / `p_max_players` ではなく既存名に寄せる。

## update_session_post RPC案

SQL草案:

```text
docs/supabase/sql/017_update_session_post_rpc_draft.sql
```

RPC名:

```text
update_session_post
```

引数案:

```text
p_session_id text
p_title text
p_session_date text
p_start_time text default null
p_end_time text default null
p_application_deadline text default null
p_session_type text default 'one-shot'
p_player_min integer default null
p_player_max integer default null
p_summary text default null
p_visibility text default 'hidden'
p_status text default 'draft'
p_end_at text default null
```

戻り値案:

```text
session_id text
discord_sync_status text
discord_last_action text
updated_at timestamptz
```

戻り値に含めない:

- email
- user_id全文
- gm_user_id
- gmUserId
- token / key / secret類
- Discord credential
- Webhook URL
- bot token
- service_role

## 権限方針

RPCは `security definer`、`set search_path = ''`、`authenticated` のみEXECUTEを付与する。
`anon` にはEXECUTEを付与しない。

関数内ではRLSだけに依存せず、以下を確認する。

- `auth.uid()` がnullなら拒否。
- 対象 `sessions.id` が存在しなければ拒否。
- adminは更新可。
- GMは `public.has_role('gm')` かつ対象行の `gm_user_id = auth.uid()` の場合のみ更新可。
- 通常PLは拒否。
- 他GMの依頼書は拒否。

既存helper `public.is_session_gm(text)` はadminもtrueにするため、草案ではGM本人性を明示する目的で `has_role('gm')` と `gm_user_id = auth.uid()` を直接組み合わせる。

## 入力バリデーション方針

- `p_session_id` は空文字不可。
- `title` は必須、120文字以内。
- `p_session_date` は必須、dateへ変換できること。
- `p_start_time` は必須、`HH:mm` 形式。
- `p_end_time` は任意、ある場合は `HH:mm` 形式。
- `p_end_at` は任意、ある場合は `YYYY-MM-DDTHH:mm` または `YYYY-MM-DD HH:mm` 形式としてAsia/Tokyoの `timestamptz` へ変換する。
- `p_end_at <= start_at` は拒否。
- `p_end_at` がなく `p_end_time` だけがある場合は、同日終了として `end_time <= start_time` を拒否する。
- `session_type` は `one-shot` / `campaign` / `special` / `other` のみ。
- `visibility` は `hidden` / `private` / `public` のみ。
- `status` は `draft` / `tentative` / `recruiting` / `full` / `closed` / `finished` / `canceled` のみを候補にする。
- `visibility = public` かつ `status = draft` は拒否する。
- `player_min` / `player_max` はnullまたは0以上。
- `player_min > player_max` は拒否。
- `summary` は1000文字以内。

## status / visibility 更新方針

DB側RPCとしては `visibility` と `status` を受け取る。
ただし、UI接続初期段階では現在フォームにある値だけを扱い、公開切替や募集終了専用操作は別工程で確認する。

DB/RPC草案では `visibility = public` かつ `draft` / `canceled` 以外を表示対象にする方針に寄せる。
hidden / draft更新後もpublic calendarに出ないことをsmoke test観点に含める。

`closed` / `finished` / `canceled` は既存表示ラベルに存在するが、今回のUIで積極的に切り替える操作はまだ作らない。

## Discord同期メタデータ更新方針

RPC内でDiscord実送信は行わない。
DB更新後にEdge Functionが処理できるよう、同期メタデータだけを更新する。

方針:

- `visibility = public` かつ `status in ('tentative', 'recruiting', 'full')` の場合は `discord_sync_status = pending`。
- 既に `discord_message_id` がある場合は `discord_last_action = update`。
- まだ `discord_message_id` がない場合は `discord_last_action = create`。
- `visibility = public` かつ `status in ('closed', 'finished')` で既存Discord投稿がある場合は `discord_last_action = close`。
- 非公開化、下書き化、中止化で既存Discord投稿がある場合は `discord_last_action = delete` 相当としてpending化する。
- hidden / draft更新で既存Discord投稿がない場合は `discord_sync_status = skipped` のままでよい。
- `discord_sync_error` は新しい更新要求時にクリアする。
- `discord_sync_requested_at` はpending化する場合だけ更新する。
- `discord_message_id` / channel / thread / post_url等の既存投稿識別子はRPCで上書きしない。

直接UPDATEで本文だけ変え、`discord_sync_status` を置き去りにしないことを重視する。
Edge Function側は後続工程でpending行を `create` / `update` / `close` / `delete` として処理する。

## UI接続計画

現在の `session-post.html` は既存依頼書選択時に作成ボタンをdisabledにし、`create_session_post` を呼ばない。
次工程以降では以下の接続を行う。

1. 既存依頼書選択時に `変更を保存` ボタンを出す。
2. 保存時にフォーム値から `update_session_post` payloadを作る。
3. `p_session_id` はDOMのoption valueからではなく、JSメモリ上の選択レコードから取得する。
4. option valueは引き続き `manage-0` 形式のローカルキーだけを使い、raw id / uuidをDOMへ出さない。
5. 保存成功後、selectの選択肢ラベルを最新タイトル・日時・状態へ更新する。
6. 保存成功後、JSメモリ上の選択レコードも最新値として更新する。
7. フォーム内容を保存済みの最新値として保持し、二重保存や古い値の再送を避ける。
8. `新規依頼書を書く` を選んだ場合は、従来どおり新規作成モードへ戻し、`create_session_post` モードを使う。
9. 公開切替、削除、募集終了、Discord再同期ボタンは別工程で扱う。

UI実装時の表示制限:

- raw id / uuidをDOM、画面、consoleへ出さない。
- email、user_id全文、gmUserId、token、key、secret類を出さない。
- 保存失敗時は安全な短文エラーだけを表示する。

## smoke test観点

後続のSQL適用・テスト工程で確認する。

- anon拒否。
- 通常PL拒否。
- 他GM拒否。
- 対象GM成功。
- admin成功。
- invalid status拒否。
- invalid visibility拒否。
- min > max拒否。
- end_at <= start_at拒否。
- title空欄拒否。
- session_type不正値拒否。
- public draft拒否。
- 戻り値やエラー整形に内部情報が出ない。
- hidden/draft更新時のpublic非表示維持。
- public/recruiting更新時の `discord_sync_status = pending` 化。
- 既存 `discord_message_id` ありなら `discord_last_action = update`。
- 既存 `discord_message_id` なしなら `discord_last_action = create`。
- hidden/private/draftへ戻した時、既存Discord投稿がある場合のpending delete方針。

通常実行で既存データを壊す恐れがある成功系は、専用fixtureまたは破壊的テスト明示フラグ付きにする。

## 実行前preflight項目

SQL Editor実行前に以下を確認する。

- `public.sessions` 列一覧。
- `public.sessions.id` がtextであること。
- `end_at` が `timestamptz` であること。
- `updated_at` が存在すること。
- `discord_sync_status` / `discord_last_action` / `discord_message_id` / `discord_sync_error` / `discord_sync_requested_at` が存在すること。
- 既存check制約。
- 既存 `visibility` / `status` の実データ値。
- 既存RPC名 `update_session_post` の衝突有無。
- `create_session_post` の現在signature。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` の存在、`security definer`、`search_path`。
- EXECUTE grant方針。
- PostgREST RPCで同名overloadが曖昧化しないこと。
- Discord同期メタデータ列の意味がEdge Function計画と一致していること。

## M-14D-8b preflight section整理

`docs/supabase/sql/017_update_session_post_rpc_draft.sql` に、SQL Editorで先に実行する範囲として `SECTION 1: PREFLIGHT ONLY` を明示した。
SQL Editorへ貼る範囲は、ファイル内の以下のコメントで囲まれた部分だけ。

```text
-- SECTION 1: PREFLIGHT ONLY
...
-- END SECTION 1: PREFLIGHT ONLY
```

この範囲はSELECTのみで、`information_schema` / `pg_catalog` / `pg_proc` / `pg_namespace` / `information_schema.routine_privileges` の参照に限定する。
preflightでは、`public.sessions` 列一覧、主要列型、関連check制約、既存 `update_session_post` の有無、既存 `create_session_post` signature、GM/admin判定helper、anon/authenticatedの既存grant状況を確認する。

apply範囲は `SECTION 2: APPLY` として分離し、`DO NOT RUN UNTIL PREFLIGHT RESULT IS REVIEWED.` の注意コメントを追加した。
M-14D-8bではSQL Editor実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、secret類の出力は行っていない。

## M-14D-8c preflight専用ファイル化

M-14D-8b後の確認で、固定行番号による抽出範囲に実適用SQLが混入したため、固定行番号方式は破棄する。
SQL Editor実行前に停止し、DB構造変更やRPC作成は行っていない。

以後、SQL Editorへ貼るpreflightは以下の専用ファイル全文とする。

```text
docs/supabase/sql/017_update_session_post_preflight_select_only.sql
```

この専用ファイルはSELECTのみで、`public.sessions` 列一覧、主要列型、関連制約、既存RPC、helper関数、anon/authenticated grant状況を確認する。
`017_update_session_post_rpc_draft.sql` 本体には、固定行番号で抜き出さないこと、preflightには専用ファイルを使うことを明記した。

M-14D-8cではSQL Editor実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、secret類の出力は行っていない。

## M-14D-8d preflight結果記録

ユーザーがSQL Editorで実行したのは、preflight専用ファイル `docs/supabase/sql/017_update_session_post_preflight_select_only.sql` のみ。
`017_update_session_post_rpc_draft.sql` の実適用sectionは未実行で、DB構造変更、RPC作成、grant変更は行っていない。

preflight結果:

- `public.sessions` の想定列はすべて存在する。
- `id` は `text`。
- `end_at` / `application_deadline` / `updated_at` / `discord_sync_requested_at` / `discord_synced_at` は `timestamp with time zone`。
- `gm_user_id` は `uuid`。
- `date` は `date`、`start_time` / `end_time` は `time without time zone`。
- `session_type` / `status` / `visibility` / `discord_sync_status` / `discord_sync_error` / `discord_message_id` / `discord_last_action` は `text`。
- 主要defaultは `session_type = 'one-shot'`、`status = 'recruiting'`、`visibility = 'public'`、`discord_sync_status = 'not_requested'`、`updated_at = now()`。
- `status` 許可値は `draft` / `tentative` / `recruiting` / `full` / `closed` / `finished` / `canceled`。
- `visibility` 許可値は `public` / `private` / `hidden`。
- `session_type` 許可値は `one-shot` / `campaign` / `special` / `other`。
- `discord_sync_status` 許可値は `not_requested` / `pending` / `posted` / `failed` / `skipped`。
- `discord_last_action` 許可値は `create` / `update` / `delete` / `close` / `resync`。
- `create_session_post` は1本のみ存在し、`p_end_at` 対応済み、`security_definer = true`。
- `update_session_post` は未存在。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` は存在し、戻り値はboolean、`security_definer = true`、volatilityはstable。
- `create_session_post` / `has_role` / `is_admin` / `is_session_gm` はauthenticatedにEXECUTEがあり、確認範囲ではanon grantは出ていない。

整合点検結果:

- SQL草案の `p_session_id text` は実DBの `sessions.id text` と一致する。
- SQL草案の `status` / `visibility` / `session_type` 許可値はpreflight結果と一致する。
- SQL草案の `discord_sync_status` は許可値内の `pending` / `skipped` のみを設定するため制約と矛盾しない。
- SQL草案の `discord_last_action` は許可値内の `create` / `update` / `delete` / `close` のみを設定するため制約と矛盾しない。
- DB/RPC草案では状態値を米国綴りの `canceled` に統一し、英国綴りは使わない。
- SQL草案は `security definer`、`set search_path = ''`、authenticated EXECUTE、anon不可の方針で、既存 `create_session_post` と整合する。

M-14D-8dではSQL Editor追加実行、DB構造変更、RPC作成/置換、Discord実送信、Edge Function deploy、secret類の出力は行っていない。

## M-14D-8e apply section review

`docs/supabase/sql/017_update_session_post_rpc_draft.sql` の `SECTION 2: APPLY` をSQL Editor実行前レビューとして点検した。
この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Discord実送信、Edge Function deployは行っていない。

レビュー結果:

- RPC名は `public.update_session_post`、`p_session_id text`、人数引数は `p_player_min` / `p_player_max` で、preflight結果の `public.sessions.id = text` と既存 `create_session_post` 方針に合っている。
- 戻り値は `session_id` / `discord_sync_status` / `discord_last_action` / `updated_at` に限定し、内部user情報やcredential類を返さない。
- `security definer` と `set search_path = ''` を維持し、未ログイン拒否、対象session未存在拒否、admin許可、対象GM許可、通常PL/他GM拒否の方針を確認した。
- `session_type` / `visibility` / `status` はpreflightで確認した許可値と一致し、`canceled` は米国綴りに統一している。
- `public + draft`、`player_min > player_max`、`end_at <= start_at`、同日終了時刻逆転、長すぎるsummaryを拒否する方針を確認した。
- Discord同期メタデータは許可値内の `pending` / `skipped` と `create` / `update` / `delete` / `close` に整理され、実送信は行わない。
- `updated_at`、`discord_sync_status`、`discord_last_action`、`discord_sync_requested_at`、`discord_sync_error` を更新対象として確認した。
- 権限草案は `revoke execute ... from public`、`revoke execute ... from anon`、`grant execute ... to authenticated` を明示する形へ補強した。
- 危険語チェックで注意コメント由来のノイズが出にくいよう、SQL草案内のcredential注意コメントを中立表現へ寄せた。

## M-14D-8f apply専用SQLファイル

SQL Editorで実行する対象を固定するため、レビュー済みAPPLY専用ファイルを作成した。

```text
docs/supabase/sql/017_update_session_post_apply_reviewed.sql
```

このファイルは `create or replace function public.update_session_post(...)`、`security definer`、`set search_path = ''`、`public` / `anon` からのEXECUTE取り外し、`authenticated` へのEXECUTE付与、実行後確認SELECTだけを含む。
preflight SELECT群、rollback草案、draft全文は含めない。

以後、SQL Editorで実行する場合は `017_update_session_post_apply_reviewed.sql` の全文のみを貼り、`017_update_session_post_rpc_draft.sql` の全文は貼らない。
preflightは引き続き `017_update_session_post_preflight_select_only.sql`、applyは `017_update_session_post_apply_reviewed.sql` と分離する。

M-14D-8fではAPPLY専用ファイル作成のみを行い、SQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、secret類の出力は行っていない。

## M-14D-8g apply result

ユーザーがSupabase SQL Editorで `docs/supabase/sql/017_update_session_post_apply_reviewed.sql` を適用した。
`update_session_post` RPCは作成済みで、DB側の変更はRPC作成と権限設定のみ。テーブル構造変更、Discord実送信、Edge Function deployは行っていない。

適用後確認結果:

- `function_count = 1`
- `all_security_definer = true`
- signature: `update_session_post(text,text,text,text,text,text,text,integer,integer,text,text,text,text)`
- `authenticated`: `expected_execute = true` / `actual_execute = true` / `ok = true`
- `anon`: `expected_execute = false` / `actual_execute = false` / `ok = true`
- `public`: `expected_execute = false` / `actual_execute = false` / `ok = true`

M-14D-8gではCodex側のSQL Editor追加実行、DB追加変更、RPC再作成、GRANT/REVOKE再実行、Discord実送信、Edge Function deploy、secret類の出力、`updates.json` 変更は行っていない。
次工程はM-14D-9として、フロントの「変更を保存」UI接続を行う。

## M-14D-9 frontend update save UI

`session-post.html` の既存依頼書編集モードに `変更を保存` UIを接続し、保存時に `update_session_post` RPCを呼ぶ実装を追加した。
新規作成モードでは従来どおり `create_session_post` を使い、既存依頼書選択中は作成ボタンを非表示/disabledにして `変更を保存` ボタンを有効化する。

RPC payloadは `create_session_post` と同じフォーム整形を共通利用しつつ、更新時は `p_session_id`、`p_title`、`p_session_date`、`p_start_time`、`p_end_time`、`p_application_deadline`、`p_session_type`、`p_player_min`、`p_player_max`、`p_summary`、`p_visibility`、`p_status`、`p_end_at` を送る。
`p_session_id` はDOMやselect option valueから取得せず、JSメモリ上の選択レコードから渡す。

保存成功後は成功メッセージを表示し、selectの該当option表示とJSメモリ上の選択レコードを最新化する。
保存失敗時は `login_required`、`not_allowed`、`session_not_found`、`draft_must_not_be_public`、`invalid_player_range`、`end_at_must_be_after_start_at`、`summary_too_long` などを日本語に丸め、内部IDやcredential類を表示しない。

M-14D-9ではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力は行っていない。

## M-14D-10 publication UI guard

既存依頼書編集時に、`公開状態` / `募集状態` の組み合わせに応じた短い補助文を追加した。
非公開または下書きは公開カレンダー非表示、公開系は公開カレンダー反映とDiscord通知未実装、終了系は募集終了扱いになることを明示する。

`draft + public` はDB/RPC側の拒否に加え、UI側でも保存前に止める。
この場合は `update_session_post` RPCを呼ばず、`下書きは公開にできません。募集状態を変更するか、公開状態を非公開にしてください。` と表示する。

公開保存の成功メッセージは、公開カレンダーに反映されることとDiscord通知が未実装であることを示す。
非公開保存は従来どおり短い成功メッセージに留める。

M-14D-10ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、公開切替専用の大型UI、`updates.json` 変更、secret類の出力は行っていない。

## M-14D-10.5 session detail edit route

`session-detail.html` から自分の依頼書を編集画面へ移動できるよう、基本情報グリッド右下に編集 / 削除ボタン枠を追加した。
編集ボタンはSupabase由来の依頼書で、ログイン中のユーザーが `is_admin()` または `is_session_gm(target_session_id)` を満たす場合だけ有効化する。
有効時は `session-post.html?id=<session_id>#my-sessions` へ遷移し、既存の `session-post.html?id=...` 復元処理で自分の依頼書selectとフォーム反映へつなぐ。

削除ボタンはdisabled配置のみで、削除処理、status変更、visibility変更、RPC呼び出しは行わない。
開催時刻は開始側にも年月日を表示し、日跨ぎ表示で開始日時が欠けないようにした。

`session-post.html` 側は編集状態の補助文を明確化し、指定IDが自分の依頼書一覧にない場合もIDを出さず短文エラーにする。
select option valueは引き続き `manage-0` 形式だけを使い、保存時の `p_session_id` はJSメモリ上の選択レコードから渡す。

M-14D-10.5ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、admin全件管理UI、削除/募集終了本実装、`updates.json` 変更、secret類の出力は行っていない。

## M-14D-11A admin management scope

adminをアプリ内全権限ユーザーとして扱う方針に合わせ、`session-post.html` の管理対象selectを整理した。
通常GMは自分が作成した依頼書のみを編集対象にし、adminは既存RLS/APIで取得できるSupabase由来依頼書を管理対象として扱う。

admin判定は既存の `is_admin()`、GM判定は既存の `has_role('gm')` と行所有者判定を使う。
`session-detail.html` の編集ボタンは、Supabase由来かつ `is_admin()` または `is_session_gm(target_session_id)` が通る場合だけ有効にする既存方針を維持する。

`session-post.html` のselectでは、option valueは引き続き `manage-0` 形式だけを使う。
表示ラベルには `【自分】` / `【管理】` を付けるが、raw id / uuid / user_id / email / token はDOM、画面、consoleへ出さない。
保存時の `p_session_id` はJSメモリ上の選択レコードから `update_session_post` へ渡す。

adminの管理対象取得が既存RLS/APIで失敗した場合は、画面に管理RPC追加が必要である旨を表示する。
今回の工程ではSQL Editor実行、DB構造変更、管理RPC作成/置換、GRANT/REVOKE、フロントからのDB直UPDATE、service_role key利用は行っていない。

## 停止条件

- `public.sessions.id` がtextでない。
- `is_session_gm(text)` など既存helperがない、または挙動が想定と違う。
- `public.sessions` に必要列がない。
- `visibility` / `status` の許可値が既存運用と合わない。
- `update_session_post` が既に存在し、既存signatureとの互換性が未確認。
- 公開切替や募集終了を別RPCへ完全分離する方針に変える。
- Discord同期をpendingメタデータ方式ではなくRPC内即時送信へ変える。
- raw id / uuidをDOMへ出すUI方針に変わる。

## 今回は実施しないこと

- SQL Editor実行。
- DB構造変更。
- RPC作成/置換。
- RPC実行。
- Edge Function deploy。
- Discord実送信。
- フロントUI接続実装。
- 公開切替の実操作。
- 削除の実操作。
- 募集終了の実操作。
- `updates.json` 変更。
- commit / push。

## M-14D-12A delete-equivalent UI connection

`session-detail.html` の削除ボタンを、物理削除ではなく既存 `update_session_post` RPC による削除相当操作へ接続した。RPC payloadは通常の更新と同じ形で、既存の `p_title`、`p_session_date`、`p_start_time`、`p_end_time`、`p_end_at`、`p_application_deadline`、`p_session_type`、`p_player_min`、`p_player_max`、`p_summary` を維持し、`p_visibility = hidden` / `p_status = canceled` だけを変更する。

許可条件は Supabase由来かつ `is_admin()` または `is_session_gm(target_session_id)` が通ること。静的JSON由来、通常PL、他GMでは削除ボタンを disabled のままにする。成功時は `この依頼書を非公開・中止扱いにしました。` と表示し、詳細画面の公開状態/募集状態も `非公開` / `中止` に更新する。既知エラーは `login_required`、`not_allowed`、`session_not_found` を日本語へ丸める。

`session-post.html` では募集状態selectに `closed` / `finished` / `canceled` を追加し、`募集終了扱い`、`開催終了扱い`、`中止扱い` の補助文を表示する。`draft + public` ガード、`update_session_post` RPC、`p_end_at` / 日跨ぎ対応、admin管理対象select、raw id非表示方針は維持する。

この工程では SQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、物理削除、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類利用、commit / push は行っていない。

## M-14D-13A delete policy change

M-14D-13A時点では soft delete = `visibility = hidden` / `status = canceled` としてQA確認済み。ただし後続の運用方針では、削除ボタンは完全削除へ変更する。

`hidden` / `canceled` は「中止として残す」操作として扱い、完全削除とは分離する。完全削除は `delete_session_post` RPC を新設して実装する方針とし、`session-detail.html` の削除ボタンに加えて、`session-post.html` の編集画面にも削除ボタンを置く。

完全削除前には確認ポップアップを出し、確認文には「中止として残したい場合は募集状態を中止にする」旨を含める。この方針追記では SQL Editor未実行、DB変更なし、RPC変更なし。

## M-14D-13B delete_session_post設計追記

`update_session_post` は引き続き依頼書の編集保存、公開状態変更、募集状態変更、中止として残す操作に使う。
完全削除は `update_session_post` の `hidden` / `canceled` ではなく、新規 `delete_session_post` RPCへ分離する。

`delete_session_post` 草案は `p_session_id text` を受け取り、`deleted_session_id text` と `deleted_at timestamptz` だけを返す。
権限方針は `update_session_post` と同じく、authenticatedのみ、adminまたは対象GMのみ許可、通常PLと他GMは拒否、静的JSON由来はDB対象外。

preflight専用SQL `docs/supabase/sql/018_delete_session_post_preflight_select_only.sql` で、完全削除前に `public.sessions` 主キー、FK、ON DELETE、関連テーブル、helper、既存routine権限を確認する。
`docs/supabase/sql/018_delete_session_post_rpc_draft.sql` はpreflight結果レビュー前に実行しない草案であり、関連FKがRESTRICT / NO ACTIONの場合やCASCADEしてはいけないテーブルが見つかった場合は改訂する。

この工程ではSQL Editor未実行、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、secret類の出力なし、commit / pushなし。

## M-14D-13B preflight結果

`018_delete_session_post_preflight_select_only.sql` のSELECT-only preflight結果として、`public.sessions` を参照する外部キーは `session_applications_session_id_fkey` / `session_comments_session_id_fkey` の2件だけだった。
どちらも `ON DELETE CASCADE`。
また、`session_id` 列を持つpublic base tableは `session_applications` / `session_comments` のみで、現時点で迷子になりそうな外部キーなし `session_id` テーブルは見当たらない。

完全削除は `update_session_post` の中止保存とは別物であり、`delete_session_post` で対象 `public.sessions` 行を削除すると、DB制約により参加申請・参加希望コメントも削除される。
後続UIの確認文にはこの影響を明記する。

SQL草案は `delete_session_post(p_session_id text)`、`security definer`、安全な `search_path`、`auth.uid()` 確認、adminまたは作成者GMのみ許可、静的JSON対象外、対象1件のWHERE付きDELETE、最小戻り値、`public` / `anon` revokeと `authenticated` grant方針で、preflight結果と矛盾しない。
SQL EditorではSELECT-only preflightのみ実行され、RPC本体、DB構造変更、RPC作成、GRANT/REVOKE、DELETEは未実行。

## M-14D-13D relation to delete flow

M-14D-13Dで削除ボタンは `update_session_post` による `visibility = hidden` / `status = canceled` 保存ではなく、`delete_session_post` RPCによる完全削除へ接続した。
`update_session_post` は引き続き作成者GM/adminの編集保存、公開状態/募集状態変更、`draft + public` ガード、`p_end_at` / 日跨ぎ対応のために使う。
`status = canceled` は「削除」ではなく「中止として残す」募集状態として扱う。

削除確認文には、完全削除であること、参加申請・コメントも削除されること、中止として残す場合は募集状態を「中止」にすること、Discord通知・投稿削除は未実装であることを明記した。
この工程でSQL Editor追加実行、DB構造変更、RPC変更、GRANT/REVOKE再実行、実データ削除、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。
