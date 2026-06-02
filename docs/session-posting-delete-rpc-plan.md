# M-14D-13B delete_session_post RPC preflight / design plan

## Purpose

M-14D-13A時点では、削除相当操作を `visibility = hidden` / `status = canceled` としてQA確認済み。
ただし運用方針として、今後の「削除」ボタンは完全削除へ変更する。

`hidden` / `canceled` は「中止として残す」操作として扱い、完全削除とは分ける。
完全削除はフロントからDBへ直接DELETEせず、新規RPC `delete_session_post` 経由で実装する。

この工程では、preflight用SELECT-only SQLとRPC草案を作成するだけで、SQL Editor実行、DB変更、RPC作成、実データ削除は行わない。

## Files

- SELECT-only preflight: `docs/supabase/sql/018_delete_session_post_preflight_select_only.sql`
- RPC draft: `docs/supabase/sql/018_delete_session_post_rpc_draft.sql`

## RPC design

```text
delete_session_post(p_session_id text)
```

戻り値は最小限にする。

```text
deleted_session_id text
deleted_at timestamptz
```

`deleted_session_id` は既存公開セッションID範囲に留め、email、user_id全文、gm_user_id、Discord credential、token、secret類は返さない。

RPCは `security definer`、`set search_path = ''`、`auth.uid()` によるログイン確認を前提にする。
対象行を `for update` で確認した上で、adminまたは対象GMだけが削除できる。

## Permission policy

- `authenticated` のみEXECUTEを付ける。
- `anon` / `public` にはEXECUTEを許可しない。
- 未ログインは `login_required`。
- 対象が見つからない場合は `session_not_found`。
- 通常GMは自分のSupabase由来依頼書だけ削除可。
- adminはSupabase由来依頼書を削除可。
- 通常PL、他GMは `not_allowed`。
- 静的JSON由来の予定はDB対象外なので、このRPCでは削除できない。
- service_role keyは使わない。

## Related data policy

完全削除は `public.sessions` 行を消すため、関連テーブルの扱いをpreflightで確認してから確定する。

- `session_applications`: 参加申請行。FKがCASCADEならセッション削除と同時に消える。RESTRICT / NO ACTIONならRPC草案を見直す。
- `session_comments`: 申請コメント行。FKがCASCADEなら同時に消える。コメントだけを残す設計に変える場合は完全削除ではなく別方針が必要。
- 申請履歴: 現状のGM履歴は `session_applications` / `session_comments` 由来の集計が中心。監査専用テーブルが存在する場合はpreflight結果を見て保持・削除・匿名化の方針を決める。
- Discord連絡先表示: 承認済み申請行とprofile情報を起点に表示しているため、セッション削除後は詳細画面から表示できない扱いにする。
- Discord同期メタデータ: `discord_message_id` などが `sessions` 行にある場合、完全削除でDB上の参照も失われる。初期 `delete_session_post` はDB削除のみとしてよいが、将来はEdge FunctionでDiscord投稿削除同期が必要。
- `session-detail`: DB行がなくなったSupabase依頼書は見つからない状態にする。静的JSON予定は対象外。
- `calendar`: public calendarはDB行削除後に表示されない。
- `mypage`: 削除済み依頼書は選択候補や管理対象から消える。申請側表示で参照できない場合は内部IDを出さず「非公開または未同期」系の短文に丸める。

`018_delete_session_post_rpc_draft.sql` は、preflightでFKのON DELETEが確認されるまで暫定草案とする。
RESTRICT / NO ACTIONの参照や、CASCADEしてはいけない関連テーブルが見つかった場合、APPLY前にRPC草案を改訂する。

## Discord policy

この工程ではDiscord実送信を行わない。
初期 `delete_session_post` はDB削除のみでよいが、`discord_message_id` がある公開済み依頼書を完全削除するとDiscord投稿が残る可能性がある。

Edge Functionによる削除同期が未実装の間は、公開済みまたはDiscord投稿済み依頼書の完全削除前に強い確認を出す。
確認文には、中止として残したい場合の代替操作を必ず入れる。

```text
この依頼書を完全削除します。
削除すると依頼書、申請、コメントなどの関連データも表示できなくなる場合があります。
中止として残したい場合は、削除せず募集状態を中止にしてください。
よろしいですか？
```

## Future UI connection

- `session-detail.html` の削除ボタンは、後続で `delete_session_post` RPCへ接続する。
- `session-post.html` の編集モードにも削除ボタンを置く。
- 新規作成モードでは削除ボタンを出さない。
- 静的JSON由来では削除不可理由を表示する。
- 削除成功後、`session-post.html` は新規作成モードへ戻す。
- 削除成功後、`session-detail.html` はcalendar/listへ戻すか、削除済みの短文状態を表示する。
- raw id / uuid / user_id / email / gmUserId / token / secret類は画面、DOM、consoleへ出さない。

## Preflight checklist

`018_delete_session_post_preflight_select_only.sql` で以下をSELECTだけで確認する。

- `public.sessions` の主キー。
- `public.sessions.id` の型。
- `public.sessions` を参照するFK。
- FKのON DELETEが CASCADE / RESTRICT / NO ACTION / SET NULL / SET DEFAULT のどれか。
- `session_id` 列を持つpublicテーブル。
- `sessions.id` を参照するpublicテーブル。
- 申請、コメント、連絡先、履歴候補テーブルの存在。
- 既存 `delete_session_post` RPCの有無。
- 既存 helper `has_role(text)` / `is_admin()` / `is_session_gm(text)`。
- 既存 `update_session_post` RPCの権限。
- `anon` / `authenticated` / `PUBLIC` のroutine権限。

## Not done

- SQL Editor未実行。
- DB構造変更なし。
- RPC作成なし。
- RPC置換なし。
- GRANT / REVOKE未実行。
- 実データ削除なし。
- フロントからのDB直DELETEなし。
- Discord実送信なし。
- Edge Function deployなし。
- Discord resync UIなし。
- service_role key利用なし。
- secret類の記録なし。
- `updates.json` 未変更。
- commit / pushなし。

## Remaining work

1. ユーザーがSQL Editorでpreflight SELECT-only SQLを実行する。
2. FK / 関連テーブル結果を見て、RPC草案の削除方針を最終化する。
3. 必要ならEdge Function側のDiscord削除同期方針を追加する。
4. `delete_session_post` APPLY専用SQLをレビュー済みファイルとして分離する。
5. ユーザー実行後にRPC権限と戻り値を確認する。
6. `session-detail.html` と `session-post.html` 編集モードの削除ボタンをRPCへ接続する。
