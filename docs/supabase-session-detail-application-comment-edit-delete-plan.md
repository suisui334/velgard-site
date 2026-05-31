# Supabase M-11C session-detail 参加希望コメント編集・削除 実装前調査・設計

## 1. 目的

M-11Cでは、本番 `session-detail.html` の参加希望コメント欄で、ログイン済みPL本人が自分の参加希望コメントを編集・削除できるようにする。

今回の工程では本番実装は行わず、既存RPC、RLS、現在のUI構造、削除時の申請取消扱い、エラー処理、テスト観点を調査し、次工程で安全に実装できる設計図を作る。

## 2. 調査対象

主に確認したファイル:

- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `docs/supabase/sql/007_rls_smoke_fix_grants_draft.sql`
- `docs/supabase/sql/008_comment_management_rpc_draft.sql`
- `docs/supabase-f6-sql-execution-result.md`
- `docs/supabase-f6-comment-edit-delete-application-cancel-plan.md`
- `docs/supabase-f6-comment-edit-delete-prototype.md`
- `docs/supabase-f6-rls-smoke-test-update-plan.md`
- `scripts/supabase-rls-smoke-test.mjs`
- `dev/supabase-comment-edit-delete-prototype.html`
- `dev/supabase-comment-edit-delete-prototype.js`
- `session-detail.html`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDisplay.js`
- `assets/js/main.js`
- `assets/js/supabaseRuntimeConfig.js`
- `data/sessions.json`
- `README.md`
- `docs/task-backlog.md`

`assets/js/supabaseRuntimeConfig.js` は設定の存在確認のみとし、実URLやkeyの値はこのdocsへ記録しない。

## 3. 既存RPC/RLS調査結果

F-6 SQL実行結果によると、以下はユーザーによりSupabase SQL Editorで実行済み。

- `session_comments.edited_by` 追加
- `session_comments.deleted_by` 追加
- `update_application_comment(target_comment_id uuid, comment_body text)` 作成
- `delete_application_comment_and_maybe_cancel(target_comment_id uuid)` 作成
- 両RPCの `revoke all from public`
- 両RPCの `grant execute to authenticated`

Codex側では今回SQL Editorを実行していない。

RLS / GRANT上の現行方針:

- `session_comments` の直接SELECTは広げない。
- 公開コメント表示は `get_public_session_comments()` 経由を維持する。
- `session_applications` は `authenticated` がSELECTでき、RLSで本人 / 対象GM / adminに制限される。
- コメント編集・削除はテーブル直接UPDATE / DELETEではなくRPC経由に寄せる。

## 4. `update_application_comment` の正確な仕様

SQL正本は `docs/supabase/sql/008_comment_management_rpc_draft.sql`。

```text
update_application_comment(target_comment_id uuid, comment_body text)
```

仕様:

| 項目 | 内容 |
| --- | --- |
| RPC名 | `update_application_comment` |
| 引数 | `target_comment_id uuid`, `comment_body text` |
| 返り値 | table: `comment_id uuid`, `session_id text`, `edited_at timestamptz` |
| 実行権限 | `authenticated` のみ。`anon` は実行不可 |
| 認証必須 | `auth.uid()` がnullなら失敗 |
| 編集可能者 | コメント本人、対象セッションGM、admin |
| 本人編集 | 可能 |
| GM編集 | 対象セッションGMなら可能。ただしM-11C本番UIではまだ出さない |
| 削除済みコメント | `deleted_at is null` 条件があるため編集不可 |
| 空本文 | `comment_body is null` または `trim` 後空欄なら失敗 |
| 文字数 | `length(comment_body) > 4000` なら失敗 |
| 更新列 | `body`, `edited_at`, `edited_by`, `updated_at` |
| RLS/権限 | `security definer`。関数内で本人 / GM / adminを判定し、直接UPDATE権限は広げない |

`comment_body` はHTMLを保存前に特別変換せずテキストとして保存する。UI側では必ず `textContent` などで描画し、HTMLとして挿入しない。

## 5. `delete_application_comment_and_maybe_cancel` の正確な仕様

SQL正本は `docs/supabase/sql/008_comment_management_rpc_draft.sql`。

```text
delete_application_comment_and_maybe_cancel(target_comment_id uuid)
```

仕様:

| 項目 | 内容 |
| --- | --- |
| RPC名 | `delete_application_comment_and_maybe_cancel` |
| 引数 | `target_comment_id uuid` |
| 返り値 | table: `deleted_comment_id uuid`, `affected_session_id text`, `application_status text`, `application_canceled boolean`, `active_application_comment_count integer` |
| 実行権限 | `authenticated` のみ。`anon` は実行不可 |
| 認証必須 | `auth.uid()` がnullなら失敗 |
| 削除可能者 | コメント本人、対象セッションGM、admin |
| 本人削除 | 可能 |
| GM削除 | 対象セッションGMなら可能。ただしM-11C本番UIではまだ出さない |
| 削除方式 | 論理削除。物理削除ではない |
| 削除済みコメント | 対象取得時に `deleted_at is null` を要求し、既に削除済みなら失敗 |
| 更新列 | `session_comments.deleted_at`, `deleted_by`, `updated_at` |
| 申請取消 | 対象コメントが申請コメントで、同一session/userに有効申請コメントが残らない場合、`session_applications.status = 'canceled'` |
| canceled_at | `coalesce(sa.canceled_at, now())` |
| 取消対象status | `pending`, `accepted`, `rejected`, `waitlisted` |
| 複数コメントがある場合 | 有効申請コメントが残れば申請statusは維持される |
| RLS/権限 | `security definer`。関数内で本人 / GM / adminを判定し、直接UPDATE権限は広げない |

短期実装では既存制約に含まれる `canceled` を申請取消statusとして使う。将来 `withdrawn` を導入する場合は、CHECK制約、RPC、集計RPC、RLS smoke testの別更新が必要。

注意点:

- `accepted` の最後の有効コメント削除でも `canceled` になり得る。
- 本番UIでは、承認済み申請の最後コメント削除に強い確認を入れる。
- M-11CのPL本人UIでは、GM削除・admin削除のUIは出さない。

## 6. `get_public_session_comments` の返却列と本人判定可否

現行SQL定義は `docs/supabase/sql/002_rls_grants_draft.sql`。

```text
get_public_session_comments(target_session_id text)
```

返却列:

| 列 | 用途 |
| --- | --- |
| `comment_id uuid` | 内部操作対象識別に使えるが、画面テキストには出さない |
| `session_id text` | 内部突合に使えるが、画面テキストには出さない |
| `display_name text` | 表示可 |
| `body text` | 表示可 |
| `application_status text` | 表示可 |
| `created_at timestamptz` | 表示可 |
| `updated_at timestamptz` | 表示可 |
| `edited_at timestamptz` | 編集済み表示に使用可 |

現行条件:

- `c.deleted_at is null`
- `s.visibility = 'public'`
- `s.status not in ('draft', 'canceled')`
- `user_id`, Discord ID, email, roleは返さない

本人判定可否:

- 現行RPCは `comment_id` を返すが、`user_id`、`is_own`、`can_edit`、`can_delete` は返さない。
- 本番UIで「自分のコメントにだけ編集・削除ボタンを出す」には、このままでは材料が不足する。
- `session_applications.comment_id` は本人の申請行から取得できる可能性があるが、同一ユーザーが複数コメントした場合、全コメントの本人判定には不足する。
- `create_application_comment` は既存申請が `pending` / `accepted` / `rejected` / `waitlisted` の場合、`session_applications.comment_id` を必ず最新コメントへ更新する設計ではない。

結論:

M-11C実装前に、本人判定用の安全な返却列または別RPCが必要。

推奨案:

```text
get_public_session_comments(target_session_id text)
```

へ以下のboolean列を追加する、または別RPCを追加する。

```text
is_own boolean
can_edit boolean
can_delete boolean
```

ただし `user_id` は返さない。画面にもconsoleにも出さない。

既存関数の戻り値変更はPostgreSQL上で `create or replace` だけでは済まない可能性があるため、実装時は既存RPCを安全に拡張できるか、`get_session_comments_for_current_user(target_session_id text)` のような補助RPCに分けるかをSQL計画で決める。

## 7. 現在の `session-detail.html` UI構造

`session-detail.html` は `assets/js/main.js` から `renderSessionDetail.js` を呼び、`renderSessionDetailContent()` 内の参加希望コメントパネルへ `initSessionDetailApplicationComments()` を接続している。

参加希望コメント欄のDOM:

- `[data-session-application-panel]`
- `[data-session-comment-post-control]`
- `[data-session-comment-counts]`
- `[data-session-comment-list]`
- `[data-session-comment-auth-note]`

現在の `assets/js/sessionDetailApplicationComments.js` は以下を実装済み。

- Supabase SDK読み込み
- 公開コメント取得
- 公開人数取得
- Auth session取得
- 本人申請状態取得
- 投稿フォーム
- 投稿後のコメント一覧・人数・本人申請状態再取得

現在のコメント描画では `normalizeComments()` が `comment_id` を保持していない。編集・削除UIを出す場合は、内部状態として `commentId`、`canEdit`、`canDelete` を保持しつつ、画面テキストには出さない形に変更する必要がある。

M-11C-1後の現状:

- `get_public_session_comments(target_session_id text)` は11列版へ置換済み。
- 既存8列の末尾に `is_own`, `can_edit`, `can_delete` が追加済み。
- `user_id`, email, Discord ID, role, `application_id`, `edited_by`, `deleted_by` は返さない。
- 現行フロントはまだ追加3列を利用していないため、M-11C-2で `normalizeComments()` の内部状態へ取り込む。
- SQL適用結果は `docs/supabase-session-detail-application-comment-own-flags-result.md` に記録済み。

## 8. 編集UIの差し込み位置案

M-11C本実装では、自分のコメントだけに編集UIを出す。

推奨位置:

- 各コメントカードのヘッダー右側、またはメタ情報下の控えめな操作列。
- 既存の `session-comment-item` 内に操作用コンテナを追加する。
- ボタン文言は `編集` / `削除` で十分。内部IDは出さない。

編集フロー:

1. `can_edit === true` のコメントだけ `編集` ボタンを表示する。
2. クリック時にそのコメント本文をtextareaへ切り替える。
3. `保存` / `キャンセル` を表示する。
4. 保存中はtextareaとボタンをdisabledにする。
5. 成功後はコメント一覧、人数カウント、本人申請状態を再取得する。
6. 失敗時は短い安全な文言を表示する。

UI実装時の注意:

- `comment_id` はDOMの表示テキストにしない。
- `data-comment-id` に入れる場合も、CSSや画面表示で露出しないよう扱う。
- 本文は必ず `textContent` で表示する。
- 編集フォーム内に現在本文を入れるのは可。

## 9. 削除UIの差し込み位置案

削除UIも自分のコメントだけに表示する。

推奨位置:

- 編集ボタンと同じ操作列に `削除` を配置する。
- 危険操作として見た目は控えめでも、確認は必須。

削除フロー:

1. `can_delete === true` のコメントだけ `削除` ボタンを表示する。
2. 削除前に確認ダイアログまたはインライン確認を出す。
3. 確認文に「最後の有効コメントを削除すると参加申請を取り下げます」を含める。
4. 削除中は対象コメントの操作ボタンをdisabledにする。
5. 成功後はコメント一覧、人数カウント、本人申請状態を再取得する。
6. `application_canceled === true` の場合は「参加申請を取り下げました」と短く表示する。

強い確認が必要なケース:

- 本人申請状態が `accepted` の場合。
- 自分の有効コメントが1件だけと判定できる場合。

ただし現行RPCだけでは「自分の有効コメント総数」を事前に正確に判定できない可能性があるため、M-11C実装時は `active_application_comment_count` を事前取得できる補助RPCを用意するか、確認文を常に安全側へ倒す。

## 10. 編集バリデーション案

投稿時と同等にする。

- trim後空欄は禁止。
- 最大4000文字。
- 改行は許可。
- HTML/URLはプレーンテキスト扱い。
- 保存中はtextareaとボタンをdisabledにする。
- 二重押しを防止する。
- 画面表示は安全な短文にする。

実装時は投稿フォームの `validateCommentBody()` を編集用にも使えるよう共通化するか、同じ仕様の小関数を追加する。

## 11. 削除確認と申請取消扱い

削除はコメント単体の非表示に留まらず、最後の有効申請コメントなら参加申請取消に繋がる。

確認文に含める内容:

- コメントを削除すると公開コメント一覧から消える。
- 同じセッションに自分の有効な参加希望コメントが他にない場合、参加申請を取り下げる。
- 参加申請を取り下げると、申請中人数やmypageの参加申請中一覧から外れる。
- 承認済みの場合は、参加予定から外れる可能性があるため、通常より強く確認する。

削除後再取得:

1. `get_public_session_comments(target_session_id)` を再取得する。
2. `get_public_session_application_counts(target_session_id)` を再取得する。
3. `session_applications` の本人行を再取得する。
4. 本人申請が `canceled` になった場合、投稿フォームの再申請案内とmypage表示方針に揃える。

複数コメントがある場合:

- RPC戻り値の `active_application_comment_count > 0` なら申請は維持される。
- UI文言は「コメントを削除しました。参加申請は継続しています。」のように短くする。

## 12. 本人判定方針

推奨はDB/RPC側で本人判定を返す方式。

候補比較:

| 候補 | 評価 |
| --- | --- |
| `get_public_session_comments` に `is_own` / `can_edit` / `can_delete` を追加 | UI実装が最も素直。`user_id` を返さずに済む。既存RPC戻り値変更のSQL手順確認が必要 |
| 別RPCで自分のコメントID一覧を取得 | 既存公開RPCを壊しにくい。公開コメント一覧と内部IDリストの突合が必要 |
| `session_applications.comment_id` だけで判定 | 同一ユーザー複数コメントに弱く、M-11C正本方針に不足 |
| `user_id` を返してclient側で比較 | 画面・console漏洩リスクが上がるため非推奨 |

M-11C本実装では、`user_id` を返さないRPC拡張または補助RPCを先に用意し、`can_edit` / `can_delete` がtrueのコメントだけ操作UIを出す。

## 13. エラー処理方針

画面表示は短く安全にする。

| ケース | 表示案 |
| --- | --- |
| 未ログイン | ログインが必要です。 |
| 編集権限なし | このコメントは編集できません。 |
| 削除権限なし | このコメントは削除できません。 |
| 対象コメントなし | コメントを確認できませんでした。表示を更新してください。 |
| すでに削除済み | すでに削除されています。表示を更新してください。 |
| 募集状態変更 | 募集状態が変更された可能性があります。表示を更新してください。 |
| 通信失敗 | 通信に失敗しました。時間をおいて再度お試しください。 |
| RPC失敗 | 操作できませんでした。表示を更新してください。 |
| 想定外エラー | 操作できませんでした。 |

出さないもの:

- Supabase詳細エラー全文
- SQLエラー詳細
- Project URL
- key
- token
- email
- `user_id`
- `comment_id`
- `application_id`
- secret類

consoleにもURL、key、token、email、`user_id`全文、内部ID類を出さない。

## 14. RLS smoke test更新案

既に `scripts/supabase-rls-smoke-test.mjs` にはF-6系テストが追加されている。通常実行では削除成功・申請取消系の一部を `RUN_DESTRUCTIVE_TESTS` なしでSKIPする設計になっている。

M-11C本番統合時に再確認したい観点:

- 本人は自分のコメントを編集できる。
- 本人は他人のコメントを編集できない。
- 本人は自分のコメントを削除できる。
- 本人は他人のコメントを削除できない。
- anonは編集・削除RPCを実行できない。
- GMは担当セッションのコメントを編集・削除できる。
- 非GMはGM操作できない。
- 削除済みコメントは編集できない。
- 削除済みコメントは公開一覧に出ない。
- 有効申請コメントが残る場合、申請状態は維持される。
- 最後の有効申請コメント削除で申請が `canceled` になる。
- `canceled` は公開人数カウントに含まれない。
- public comments RPCやログに内部 `user_id`、Discord ID、email、token、secret類が出ない。

本番統合前に、既存テストの通常実行結果と、必要なら破壊的テスト専用fixtureの実行方針を改めて確認する。

## 15. M-11C実装段階案

M-11Cは1回でまとめず、次のように分けるのが安全。

| 段階 | 内容 | 理由 |
| --- | --- | --- |
| M-11C-1 | 本人判定RPC方針の確定。`is_own` / `can_edit` / `can_delete` を返すRPC拡張または補助RPCを設計 | 現行公開RPCだけでは自分の全コメント判定が不足するため |
| M-11C-2 | 本番UIに自分のコメント判定と編集・削除ボタン表示だけを追加。RPC呼び出しはまだしない | 内部IDを表示せず、自分のコメントだけに操作が出ることを先に確認するため |
| M-11C-3 | `update_application_comment` 呼び出しを統合。編集保存、バリデーション、再取得、エラー処理を実装 | 削除より影響が軽く、UI/権限境界を先に固めやすい |
| M-11C-4 | `delete_application_comment_and_maybe_cancel` 呼び出しを統合。確認、申請取消扱い、再取得を実装 | 申請状態・人数・mypage反映に影響するため分離する |
| M-11C-5 | RLS smoke test・実ブラウザ確認結果をdocsへ記録 | 本番公開前の安全確認として必要 |

停止条件:

- 本人判定に `user_id` を画面表示する必要が出た場合。
- `get_public_session_comments` に安全な本人判定列を追加できず、別RPC設計も未確定の場合。
- 削除時の `accepted` 申請取消扱いを運用上まだ許可できない場合。
- RPC戻り値や権限がdocsとDB実体で食い違う場合。
- secret類、URL、key、token、email、内部ID類を表示する必要が出た場合。

## 16. 表示してよい情報 / 表示しない情報

表示してよい情報:

- `display_name`
- コメント本文
- コメント作成日時
- コメント更新日時
- 編集日時
- 編集済み表示
- 申請ステータス
- 編集/削除の成功・失敗メッセージ

表示しない情報:

- email
- `user_id`全文
- token
- Project URL
- key
- `gmUserId`
- secret類
- `comment_id`
- `application_id`
- `deleted_by`
- `edited_by`

`comment_id` はRPC呼び出しに必要だが、画面テキストとして表示しない。

## 17. まだやらないこと

この調査工程では以下を行わない。

- 本番フロント実装
- コメント編集UIの実装
- コメント削除UIの実装
- `update_application_comment` の実呼び出し
- `delete_application_comment_and_maybe_cancel` の実呼び出し
- GM編集・削除UI
- GM承認・却下UI
- SQL Editor実行
- DBデータ変更
- cleanup SQL実行
- RLS変更
- `close_session` 呼び出し
- `updates.json` 変更
- commit / push

## 18. 次工程プロンプト案

次工程でM-11C-1を行う場合の依頼案:

```text
M-11C-1として、session-detail の参加希望コメント編集・削除UI実装前に、本人判定に必要なRPC方針を確定してください。

前提:
- `update_application_comment(target_comment_id uuid, comment_body text)` と `delete_application_comment_and_maybe_cancel(target_comment_id uuid)` は作成済み。
- 現行 `get_public_session_comments(target_session_id text)` は `comment_id` を返すが、`is_own` / `can_edit` / `can_delete` を返さない。
- `user_id`、email、token、Project URL、key、secret類、内部ID類は画面にもconsoleにも出さない。

やること:
- 既存RPCを拡張する案と、補助RPCを追加する案を比較する。
- 同一ユーザー複数コメントでも自分の全コメントを判定できる設計にする。
- SQL草案またはdocs更新までに留め、SQL Editor実行と本番UI実装はまだ行わない。
```

## 19. M-11C-2実装結果追記

2026-06-01に、M-11C-2として本番 `session-detail.html` の参加希望コメント一覧へ編集 / 削除準備UIを追加した。

- `get_public_session_comments(target_session_id text)` の `is_own` / `can_edit` / `can_delete` をフロント側でbooleanに正規化する。
- 本人コメントかつ `can_edit` がtrueの場合だけ、disabledの `編集` を表示する。
- 本人コメントかつ `can_delete` がtrueの場合だけ、disabledの `削除` を表示する。
- 他人コメントには編集 / 削除UIを出さない。
- `comment_id` は内部状態として保持するが、画面テキストには出さない。
- `update_application_comment` / `delete_application_comment_and_maybe_cancel` は呼び出していない。

実装結果は `docs/supabase-session-detail-application-comment-edit-delete-ui-result.md` に分離した。次工程はM-11C-3として、編集UIを `update_application_comment` に接続する段階。

2026-06-01 follow-upで、参加希望コメント一覧は `created_at` 降順の新しい順を初期表示にした。将来、参加希望コメント一覧に「新しい順 / 古い順」切替を追加する余地あり。初期表示は新しい順を基本とする。
