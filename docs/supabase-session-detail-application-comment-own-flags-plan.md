# Supabase M-11C-1 session-detail 参加希望コメント本人判定RPC方針・SQL草案

作業日: 2026-06-01

## 1. 目的

M-11Cで `session-detail.html` の参加希望コメントに編集・削除UIを追加する前に、どのコメントがログイン中PL本人のものかを安全に判定するRPC方針を確定する。

今回の目的は、編集・削除ボタン表示の前提となる `is_own` / `can_edit` / `can_delete` 相当の情報を、`user_id` をフロントへ返さずに取得できるよう設計すること。

この工程では、SQL Editor実行、DB変更、本番フロント実装、編集・削除RPC呼び出し、GM承認・却下UI、GM編集・削除UIは行わない。

## 2. 調査対象

主に確認したファイル:

- `docs/supabase-session-detail-application-comment-edit-delete-plan.md`
- `docs/supabase-session-detail-application-comment-post-result.md`
- `docs/supabase-session-detail-application-comment-post-plan.md`
- `docs/supabase-session-detail-application-comments-read-result.md`
- `docs/supabase-session-detail-application-comments-integration-plan.md`
- `docs/supabase-f6-comment-edit-delete-prototype.md`
- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `docs/supabase/sql/008_comment_management_rpc_draft.sql`
- `scripts/supabase-rls-smoke-test.mjs`
- `assets/js/sessionDetailApplicationComments.js`
- `session-detail.html`
- `README.md`
- `docs/task-backlog.md`

必要箇所として、RLS helper、`session_comments` / `session_applications` schema、既存RPC定義、M-11A/B/C docs、F-6 edit/delete prototype、RLS smoke testの既存観点を確認した。

## 3. 既存 `get_public_session_comments` の仕様

現行定義は `docs/supabase/sql/002_rls_grants_draft.sql`。

```text
get_public_session_comments(target_session_id text)
```

| 項目 | 現行仕様 |
| --- | --- |
| 引数 | `target_session_id text` |
| 実行方式 | `language sql`, `security definer`, `stable`, `set search_path = ''` |
| 実行権限 | `anon`, `authenticated` に execute grant |
| 返却列 | `comment_id`, `session_id`, `display_name`, `body`, `application_status`, `created_at`, `updated_at`, `edited_at` |
| コメントID | `comment_id uuid` を返す。画面テキストには出さない |
| user_id | 返さない |
| updated_at | 返す |
| 申請status | `session_applications.status` を `application_status` として返す |
| deleted除外 | `c.deleted_at is null` で除外 |
| 公開条件 | `s.visibility = 'public'`, `s.status not in ('draft', 'canceled')` |
| 表示名 | `public.profiles p` を `p.id = c.user_id` でjoinし、`p.display_name` のみ返す |
| 非返却 | email、Discord ID、role、`user_id`、`application_id`、`edited_by`、`deleted_by` は返さない |

現行JSの `normalizeComments()` は `comment_id` を保持していない。M-11C-2以降で編集・削除ボタン表示に進む場合は、内部状態として `commentId` と権限フラグを保持しつつ、画面文言やconsoleには出さない変更が必要。

## 4. 本人判定で不足しているもの

M-11Cで必要なUIは次の通り。

- 自分のコメントだけに `編集` / `削除` を表示する。
- 他人のコメントには表示しない。
- 画面に `user_id` / `comment_id` / `application_id` は表示しない。
- 内部処理では編集・削除RPC引数として `comment_id` が必要。

現行RPCは `comment_id` を返すが、本人判定に必要な以下を返さない。

- `is_own`
- `can_edit`
- `can_delete`

`session_applications.comment_id` だけで本人コメントを判定する案は不十分。同一ユーザーが複数コメントした場合、`session_applications.comment_id` は本人の全コメントを表せない。

## 5. 本人判定案の比較

### 案A: `get_public_session_comments` を拡張する

返却列の末尾に次を追加する。

```text
is_own boolean
can_edit boolean
can_delete boolean
```

扱い:

- `anon` は `auth.uid()` がnullなので全て `false`。
- `authenticated` は `auth.uid() = session_comments.user_id` のコメントだけ `true`。
- `user_id` は返さない。
- 既存の `comment_id` は維持する。
- 既存列は同じ順序で維持し、末尾にboolean列だけを足す。

利点:

- コメント一覧と本人判定を1回のRPCで取得できる。
- UI側の突合処理が不要。
- 同一ユーザー複数コメントでも全コメントを正しく本人判定できる。
- `user_id` をフロントへ渡さずに済む。
- 現行JSは追加列を無視できるため、フロント実装前にSQLを適用しても表示上の互換性を保ちやすい。

注意:

- PostgreSQLでは戻り値型変更を `create or replace function` だけでは行えないため、既存関数をdropして作り直す必要がある。
- SQL適用時はトランザクション内で行い、`drop ... cascade` は使わない。
- Supabase/PostgRESTのschema cache reloadが必要になる可能性がある。

### 案B: 別RPCを追加する

例:

```text
get_my_session_comment_permissions(target_session_id text)
```

返却候補:

```text
comment_id uuid
can_edit boolean
can_delete boolean
```

扱い:

- 公開コメントRPCはそのまま。
- ログイン済み時だけ追加RPCを呼び、`comment_id` でコメント一覧にマージする。
- `anon` は実行不可、または空配列/false扱いにする。
- `user_id` は返さない。

利点:

- 既存公開RPCの戻り値型を変えないため、SQL適用リスクが小さい。
- フラグ取得RPCを `authenticated` のみに絞りやすい。

欠点:

- UI側で2つのRPC結果を `comment_id` で突合する必要がある。
- 追加RPC失敗時の表示分岐が増える。
- M-11Cの表示制御としては、公開コメント一覧と権限表示の材料が分散する。

### 案C: `user_id` を返してフロントで比較する

これは採用しない。

理由:

- `user_id` 全文をフロントへ渡す必要がある。
- 画面、DOM、console、docsへの漏洩リスクが上がる。
- 既存方針の「email / user_id全文 / token / 内部ID類を画面やconsoleへ出さない」と相性が悪い。
- RLS/RPC側で判定できる情報をclient側へ広げる必要がない。

## 6. 採用案

採用案は案A。`get_public_session_comments(target_session_id text)` の返却列末尾に `is_own` / `can_edit` / `can_delete` を追加する。

理由:

- M-11Cの目的である「自分のコメントだけに編集・削除ボタンを出す」に最短で対応できる。
- `user_id` を返さず、本人判定をDB/RPC側で閉じられる。
- 同一ユーザーの複数コメントでも、各コメント単位で正しく判定できる。
- 既存画面は追加列を無視できるため、フロント本番実装前のDB側準備として扱いやすい。
- 別RPC案より、M-11C-2以降のフロント実装が単純になる。

ただし、今回の `can_edit` / `can_delete` はPL本人向けフラグとして定義する。既存の `update_application_comment` / `delete_application_comment_and_maybe_cancel` はGM/adminにも実行権限を持つが、M-11CではGM/admin操作を前倒ししないため、公開コメントRPCのフラグにはGM/admin判定を含めない。

将来GM/adminの操作UIを入れる場合は、公開コメントRPCへGM/admin権限を混ぜるのではなく、GM/admin向けの最小列RPCを別途設計する。

## 7. SQL草案

作成したSQL草案:

```text
docs/supabase/sql/011_session_comment_own_flags_rpc_draft.sql
```

概要:

- `get_public_session_comments(target_session_id text)` をdrop/recreateする草案。
- 既存8列は同じ順序で維持する。
- 末尾に `is_own`, `can_edit`, `can_delete` を追加する。
- 判定式は `auth.uid() is not null and c.user_id = auth.uid()`。
- `can_edit` / `can_delete` はM-11C PL本人UI用として `is_own` と同じ値にする。
- `anon` / `authenticated` のexecute grantを維持する。
- `security definer`, `stable`, `set search_path = ''` を維持する。
- `user_id`, email, Discord ID, role, `application_id`, `edited_by`, `deleted_by` は返さない。
- `comment_id` は既存通り返すが、画面表示やconsole出力は禁止。
- 事前確認SELECT、適用後確認SELECT、ロールバック草案、停止条件を含める。

互換性:

- 現行JSは追加列を無視するため、表示上は壊れにくい。
- ただしDB側の関数戻り値型変更なので、SQL適用時は既存依存とPostgREST schema cacheを確認する。
- `drop function ... cascade` は使わない。dropで依存エラーが出る場合は停止する。

## 8. anon / authenticated の扱い

`anon`:

- 公開コメントは引き続き読める。
- `is_own` / `can_edit` / `can_delete` は全て `false`。
- 編集・削除RPCは既存通り実行不可。

`authenticated` 本人:

- 自分の公開・非削除コメントでは `is_own = true`。
- M-11C PL本人UI用として `can_edit = true`, `can_delete = true`。
- 内部処理では同じ行の `comment_id` を編集・削除RPC引数に使える。

`authenticated` 他人:

- 他人のコメントでは `is_own = false`。
- `can_edit = false`, `can_delete = false`。

GM/admin:

- 今回の公開コメントRPCフラグには含めない。
- GM/adminの編集・削除権限は既存RPC側にはあるが、本番UI表示はM-11D/F以降で別設計にする。

## 9. 表示してよい情報 / 表示しない情報

表示してよい情報:

- `display_name`
- コメント本文
- 申請ステータス
- コメント作成日時
- コメント更新日時
- 編集日時
- 編集/削除ボタン
- 編集/削除の短い成功・失敗メッセージ

表示しない情報:

- email
- `user_id` 全文
- access token / refresh token / JWT
- Project URL実値
- publishable key / anon key実値
- service role key / secret key
- DB password / Direct connection string / JWT secret
- Discord ID
- `comment_id`
- `application_id`
- `edited_by`
- `deleted_by`

`comment_id` はRPC引数として内部処理で使うが、画面テキスト、console、docsへ実値を出さない。

## 10. RLS smoke test更新案

SQL適用後またはM-11C-2以降で追加・強化したい観点:

- `anon` は公開コメントを読める。
- `anon` の `is_own` / `can_edit` / `can_delete` は全て `false`。
- `authenticated` 本人は自分のコメントで `is_own = true`。
- `authenticated` 本人は自分のコメントで `can_edit = true`, `can_delete = true`。
- `authenticated` 本人は他人コメントで全フラグ `false`。
- 同一ユーザーの複数コメントが全て本人コメントとして判定される。
- 削除済みコメントは公開RPCに返らない。
- public comments RPCに `user_id`, email, Discord ID, role, token, secret類が返らない。
- GM/adminフラグを今回含めないことを確認する。GM/admin向けUIを実装する工程で、別RPCまたは別フラグを改めてテストする。

既存 `scripts/supabase-rls-smoke-test.mjs` は、公開コメントRPCの非公開列チェック、F-6編集・削除RPCの本人/他人/GM/anonの主要観点を既に持つ。M-11C-1のSQL適用後は、公開コメントRPCの新フラグ専用チェックを追加するのがよい。

## 11. M-11C-2以降の実装方針

M-11C-2:

- フロントで `comment_id`, `is_own`, `can_edit`, `can_delete` を内部状態として保持する。
- `can_edit` / `can_delete` がtrueのコメントだけにボタンを表示する。
- まだ `update_application_comment` / `delete_application_comment_and_maybe_cancel` は呼び出さない。
- `comment_id` は画面文言、console、docsへ出さない。

M-11C-3:

- `update_application_comment` 呼び出しを統合する。
- 投稿時と同じ本文バリデーション、二重押し防止、再取得、安全なエラー表示を入れる。

M-11C-4:

- `delete_application_comment_and_maybe_cancel` 呼び出しを統合する。
- 最後の有効コメント削除時の申請取消、承認済み申請の強確認、再取得、人数更新を扱う。

M-11C-5:

- RLS smoke test更新、実ブラウザ確認結果、SQL適用結果をdocsへ記録する。

GM/adminのコメント編集・削除UI、GM承認・却下UIは今回もM-11C-2以降の本人UIとは分ける。

## 12. 今回実行していないこと

- Supabase SQL EditorでSQLを実行していない。
- DBデータを変更していない。
- 本番フロント実装をしていない。
- 編集ボタン表示、削除ボタン表示を実装していない。
- `update_application_comment` を呼び出していない。
- `delete_application_comment_and_maybe_cancel` を呼び出していない。
- GM承認・却下UIを実装していない。
- GM編集・削除UIを実装していない。
- `close_session` を呼び出していない。
- `updates.json` を変更していない。
- secret類、実Project URL、key、token、email、`user_id` 実値を記録していない。
- commit / pushしていない。
