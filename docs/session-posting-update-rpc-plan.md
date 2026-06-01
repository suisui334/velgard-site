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

公開表示側は既存どおり `visibility = public` かつ `draft` / `canceled` / `cancelled` 以外を表示対象にする。
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
