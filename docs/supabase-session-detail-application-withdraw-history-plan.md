# Supabase M-11D 申請辞退 / 申請履歴フロー 調査・設計

作業日: 2026-06-01

## 1. 今回の目的

M-11Dでは、`session-detail.html` の参加希望コメント機能に対して、コメント削除、申請辞退、GM向け申請履歴を分けて扱うためのDB/RPC/UI/RLS方針を整理する。

今回の工程では本番フロント実装、SQL Editor実行、DB変更、申請辞退RPC実行、GM操作実装、`close_session` 呼び出しは行わない。

正本方針:

- コメント削除 = 発言そのものを消す。
- 申請辞退 = コメントを残したまま `session_applications.status` を人数集計対象外にする。
- 申請履歴 = GMが後から人物単位で申請状態を追えるようにする。

## 2. 調査したファイル

主に確認したファイル:

- `docs/supabase-session-detail-application-comment-delete-result.md`
- `docs/supabase-session-detail-application-comment-edit-result.md`
- `docs/supabase-session-detail-application-comment-edit-delete-plan.md`
- `docs/supabase-session-detail-application-comment-post-result.md`
- `docs/supabase-session-detail-application-comment-post-plan.md`
- `docs/supabase-session-detail-application-comment-own-flags-result.md`
- `docs/supabase-session-detail-application-comments-integration-plan.md`
- `docs/supabase-mypage-applications-list-result.md`
- `docs/supabase-mypage-applications-id-aligned-test-data-result.md`
- `docs/supabase-f5-gm-application-management-prototype.md`
- `docs/supabase-f6-comment-edit-delete-prototype.md`
- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `docs/supabase/sql/008_comment_management_rpc_draft.sql`
- `docs/supabase/sql/011_session_comment_own_flags_rpc_draft.sql`
- `scripts/supabase-rls-smoke-test.mjs`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderMypage.js`
- `session-detail.html`
- `README.md`
- `docs/task-backlog.md`
- `dev/supabase-gm-application-management-prototype.js`
- `dev/supabase-comment-edit-delete-prototype.js`

`assets/js/supabaseRuntimeConfig.js` は実値確認対象にせず、Project URL / key類は記録しない。

## 3. 現在の問題

M-11C-4までで、自分の参加希望コメントを削除できるようになった。既存の削除RPCは、最後の有効申請コメントを削除した場合に、申請行を `canceled` にし得る。

この挙動は「発言を消したい」と「参加意思を取り下げたい」が同じ操作に見えやすい。

一方、PLが辞退理由をコメントとして残したい場合は、コメントを削除してはいけない。GMは「誰が辞退したか」「いつ辞退したか」「関連コメントがあるか」を後から追いたい。

そのため、次工程では削除ボタンとは別に、本人向けの「参加申請を取り下げる」導線と、GM向けの「申請履歴を見る」導線を設計する。

## 4. `session_applications.status` の現状

`docs/supabase/sql/001_core_schema_draft.sql` の `session_applications_status_check` では、申請statusは次の5種類。

```text
pending
accepted
rejected
waitlisted
canceled
```

現状の申請statusには `withdrawn` はない。`finished` は `sessions.status` にはあるが、`session_applications.status` にはない。

`session_applications` には以下がある。

- `status`
- `created_at`
- `updated_at`
- `canceled_at`
- `unique (session_id, user_id)`

`canceled_by`、`canceled_reason`、`withdrawn_at`、状態遷移履歴テーブルは現状ない。

人数集計:

- `get_public_session_application_counts(target_session_id)` は `accepted` / `pending` / `waitlisted` を集計する。
- `rejected` は集計対象外。
- `canceled` は `sa.status <> 'canceled'` でjoinから外れ、集計対象外。
- `session-detail` フロントでは現状 `pending_count` と `accepted_count` だけを表示し、`waitlisted_count` は表示していない。

mypage:

- `assets/js/mypageAuthClient.js` は `APPLICATION_STATUSES = ["pending", "waitlisted", "accepted"]` のみを取得する。
- `pending` / `waitlisted` は「参加申請中」。
- `accepted` は「参加予定」。
- `rejected` / `canceled` はmypageの申請中/参加予定には出ない。

結論:

- 本人辞退/取消の短期statusは既存の `canceled` を使う案が最も自然。
- `withdrawn` 新設は、CHECK制約、既存RPC、人数集計、mypage、session-detail、RLS smoke testを広く更新するため、現時点では優先しない。
- `canceled` だけでは「本人辞退」と「GM取消」を区別しにくいため、将来必要なら `session_application_events` のような履歴テーブル、または `canceled_by` / `canceled_reason` 相当の補助設計を検討する。

## 5. 現在のコメント削除RPCとの関係

`delete_application_comment_and_maybe_cancel(target_comment_id uuid)` の現状:

- 論理削除として `session_comments.deleted_at` / `deleted_by` / `updated_at` を更新する。
- 対象コメントが申請コメントで、同じsession/userに有効申請コメントが残らない場合、`session_applications.status = 'canceled'` にする。
- 取消対象statusは `pending` / `accepted` / `rejected` / `waitlisted`。
- 有効申請コメントが残る場合は申請statusを維持する。
- 戻り値には `application_status`、`application_canceled`、`active_application_comment_count` がある。

M-11D以降の位置づけ:

- 既存削除RPCは「発言を消す」操作として維持する。
- 最後の有効コメント削除時の `canceled` 化は、コメントが1件も残らない場合の整合維持として扱う。
- 明示的な辞退導線は、削除RPCではなく、本人用の申請辞退RPCへ分ける。
- UI文言も「コメント削除」と「申請取り下げ」を分ける。

## 6. コメント削除と申請辞退を分ける設計方針

採用方針:

- コメント削除はコメント本文を公開コメント一覧から消す。
- 申請辞退はコメントを残したまま `session_applications.status = 'canceled'` にする。
- 辞退済み申請は公開人数カウント、mypageの参加申請中/参加予定から除外する。
- コメント本文は履歴・連絡として残すため、GMは文脈を追える。
- GM向け履歴は常時表示せず、折りたたみまたはボタンで開く。

注意:

- 公開参加希望コメント欄に残した本文は、現行設計では公開コメントとして表示される。
- 非公開の辞退理由が必要になった場合は、`session_comments` の公開コメントとは別に、GM専用メモまたは可視性付きコメントを設計する。

## 7. 本人向け申請辞退フロー案

推奨導線:

```text
参加申請を取り下げる
```

表示条件案:

- ログイン済み。
- 本人の `session_applications` 行がある。
- 本人申請statusが `pending` / `waitlisted` / `accepted`。
- `canceled` / `rejected` では表示しない。
- コメント編集中、投稿中、削除中は押せない。

確認文案:

```text
参加申請を取り下げますか？
コメントは履歴として残りますが、申請中人数からは除外されます。
```

`accepted` の場合は強める。

```text
承認済みの参加予定を取り下げますか？
取り下げ後は参加予定から外れます。必要ならGMへコメントで事情を伝えてください。
```

辞退後表示案:

```text
このセッションへの参加申請は取り下げ済みです。
再申請する場合は、参加希望コメントを投稿してください。
```

既存RPCで足りるか:

- `set_application_status(target_application_id, new_status)` はGM/admin判定が前提で、PL本人の辞退には使わない。
- `cancel_application(target_session_id text)` はSQL草案上存在するが、現行docs上は古い本人取消RPC候補であり、`accepted` を取消対象に含めていない。
- M-11Dの完成形では、既存 `cancel_application` をそのまま使うより、意図が明確な `cancel_my_session_application(target_session_id text)` を新規または置換草案として設計する方が安全。

本人辞退RPC案:

```text
cancel_my_session_application(target_session_id text)
```

最小仕様:

- `authenticated` のみ実行可。
- `auth.uid()` の本人行だけを対象にする。
- 対象statusは `pending` / `waitlisted` / `accepted` を基本にする。
- `status = 'canceled'`、`canceled_at = now()`、`updated_at = now()` にする。
- コメント本文は削除しない。
- 戻り値は `session_id`、`application_status`、`canceled_at` 程度に絞る。
- `user_id`、email、Discord ID、token、secret類は返さない。

## 8. 「辞退コメントとして投稿」案

候補UI:

```text
□ このコメントを辞退連絡として扱う
```

動作案:

1. コメント本文を投稿する。
2. 同じトランザクションで本人申請statusを `canceled` にする。
3. 申請中人数から除外する。
4. コメント本文は残す。
5. GM向け履歴では辞退コメントとして参照できるようにする。

既存 `create_application_comment` との関係:

- 現行 `create_application_comment(target_session_id, comment_body)` は、申請なしなら `pending` 作成、`canceled` なら `pending` 復帰、その他statusではコメント追記のみという設計。
- このRPCへ「辞退扱い」引数を追加すると、投稿=申請/再申請という既存意味が濁る。
- すぐ実装しないなら、既存RPC拡張ではなく、別RPC `withdraw_session_application(target_session_id text, reason_comment_body text default null)` として設計する方が安全。

推奨:

- M-11D本線は、まず「コメントは既存投稿UIで残す」「辞退は別ボタンで行う」にする。
- 「辞退コメントとして投稿」はM-11D後半または別工程の追加候補にする。

## 9. GM向け申請履歴UI案

導線:

```text
申請履歴を見る
```

表示条件:

- 対象セッションのGM、またはadminだけ。
- PL/anonには他人の履歴を見せない。
- PL本人には、自分の現在statusと必要な案内だけを見せる。全体履歴は出さない。

表示方式:

- 参加希望コメント欄の下、またはGM操作領域に折りたたみで置く。
- 初期状態では閉じる。
- 開いたときだけ履歴RPCを呼ぶ案がよい。

表示案:

```text
申請中
- Aさん

承認済み
- Bさん

辞退/取消
- Cさん（2026-..-..）

却下
- Dさん（2026-..-..）
```

表示してよい情報:

- `display_name`
- 申請statusラベル
- 申請作成日時
- 申請更新日時
- `canceled_at`
- 有効コメント数
- 最新コメント本文または「関連コメントを見る」折りたたみ

表示しない情報:

- email
- `user_id` 全文
- access token / refresh token / JWT
- Project URL / key実値
- secret類
- `gmUserId`
- Discord ID
- `application_id` の画面テキスト表示
- `comment_id` の画面テキスト表示

`application_id` / `comment_id` はGM操作の内部処理で必要になる可能性があるが、履歴表示のテキストとしては出さない。

Discord IDコピー機能:

- M-11Dでは扱わない。
- 将来プロフィール拡張とDiscord ID登録設計が固まってから、GMだけが必要最小限で扱う別工程にする。

## 10. GM向け申請履歴RPC案

既存RLSでは、`session_applications` は本人 / 対象GM / adminがSELECTできる。GM用devプロトタイプでは、RLSで見える `session_applications` と公開コメントRPCを `comment_id` で突合している。

ただし本番UIでは、公開コメントRPCをGM履歴の正本にしすぎると以下が残る。

- `application_id` を公開RPCは返さない。
- 非public / hiddenのコメント本文は公開RPCでは取らない。
- 今後、辞退済み・却下済み・削除済み・GM専用メモが混じると突合が複雑になる。

推奨RPC:

```text
get_gm_session_application_history(target_session_id text)
```

最小仕様:

- `authenticated` のみ実行可。
- `public.is_session_gm(target_session_id)` または `public.is_admin()` の場合だけ返す。
- 対象セッションの人物単位申請行を返す。
- `pending` / `accepted` / `waitlisted` / `rejected` / `canceled` を含める。
- `display_name`、status、申請作成/更新日時、`canceled_at`、有効コメント数、最新コメント要約を返す。
- `user_id`、email、Discord ID、role、token、secret類は返さない。
- `application_id` / `comment_id` は、将来の操作UIで必要な場合のみ内部用列として返すか、履歴表示RPCとは別のGM操作RPCへ分ける。

現状スキーマで足りないこと:

- `session_applications` は `unique (session_id, user_id)` の現在行なので、過去の状態遷移イベントまでは保持していない。
- `create_application_comment` は `canceled` から `pending` に戻すとき `canceled_at = null` にするため、再申請後に過去の辞退時刻は失われる。
- 「誰がいつ何度辞退/再申請したか」まで追う本当の履歴には、将来 `session_application_events` のような履歴テーブルが必要。

M-11Dの最小履歴は「現在の人物単位status一覧」として扱い、完全な監査ログは別工程にする。

## 11. 必要RPC案まとめ

| RPC案 | 目的 | M-11Dでの位置づけ |
| --- | --- | --- |
| `cancel_my_session_application(target_session_id text)` | 本人がコメントを残したまま申請を取り下げる | 優先 |
| `withdraw_session_application(target_session_id text, reason_comment_body text default null)` | 辞退理由コメント投稿とstatus取消を同時に行う | 追加候補。初回実装では保留可 |
| `get_gm_session_application_history(target_session_id text)` | GM/adminが人物単位の現在statusと辞退/却下を確認する | 優先 |
| `get_my_session_application_history(target_session_id text)` | PL本人が自分の履歴だけ確認する | 後回し。まずは本人status表示で足りる |

既存RPCの扱い:

- `create_application_comment`: 投稿/再申請用として維持する。辞退同時処理は混ぜない。
- `delete_application_comment_and_maybe_cancel`: コメント削除用として維持する。明示辞退には使わない。
- `set_application_status`: GM/admin操作用として維持する。本人辞退には使わない。
- `cancel_application`: 古い本人取消候補として参考にするが、M-11Dの正本RPC名・対象status・戻り値は再設計する。

## 12. `canceled` を使うか `withdrawn` を新設するか

短期採用:

```text
canceled
```

理由:

- 既存CHECK制約に含まれている。
- 既存削除RPCが `canceled` を使っている。
- 人数集計で `canceled` は除外される。
- mypageでも `canceled` は参加申請中/参加予定に出ない。
- `create_application_comment` は `canceled` から `pending` への再申請復帰を想定している。

`withdrawn` を新設する場合に必要なもの:

- `session_applications_status_check` の変更。
- `create_application_comment` の再申請復帰対象更新。
- `delete_application_comment_and_maybe_cancel` の戻り値/集計方針確認。
- `get_public_session_application_counts` の除外条件更新。
- `mypageAuthClient.js` の表示/非表示方針更新。
- `sessionDetailApplicationComments.js` のstatusラベル更新。
- RLS smoke test更新。
- 適用SQLとrollbackのレビュー。

現時点では、`withdrawn` は必要性が高まった場合のみ提案する。

## 13. 表示してよい情報 / 表示しない情報

表示してよい情報:

- `display_name`
- コメント本文
- 申請statusラベル
- 申請作成日時
- 申請更新日時
- `canceled_at`
- 申請中 / 承認済みカウント
- 辞退済み / 却下済みの表示グループ
- 短い成功/失敗メッセージ

表示しない情報:

- email
- `user_id` 全文
- access token / refresh token / JWT
- Project URL実値
- publishable key / anon key実値
- service role key
- DB password
- Direct connection string
- JWT secret
- Discord ID
- `gmUserId`
- `application_id` / `comment_id` の実値テキスト表示
- `edited_by` / `deleted_by`

consoleにも上記の実値は出さない。

## 14. RLS smoke test更新案

本人辞退:

- 本人は自分の `pending` 申請を `canceled` にできる。
- 本人は自分の `waitlisted` 申請を `canceled` にできる。
- 本人は自分の `accepted` 申請を `canceled` にできるか、方針に従い明示的に拒否される。
- 本人は他人の申請を辞退できない。
- anonは辞退RPCを実行できない。
- 辞退後、公開人数カウントから除外される。
- 辞退後、コメント本文は削除されず、公開コメントRPCに残る。
- 辞退後、mypageの参加申請中/参加予定に出ない。
- `create_application_comment` で再申請した場合、`canceled` から `pending` に戻る。

GM履歴:

- 対象GMは自分のセッションの申請履歴RPCを読める。
- adminは読める。
- 非GMは他GMセッションの申請履歴RPCを読めない。
- PLは他人の申請履歴を読めない。
- 返却列に `user_id`、email、Discord ID、role、token、secret類がない。
- `canceled` / `rejected` も履歴RPCでは返るが、公開人数カウントには含まれない。

削除RPCとの回帰確認:

- 有効申請コメントが残る場合、削除しても申請statusは維持される。
- 最後の有効申請コメント削除時は既存どおり `canceled` になる。
- 明示辞退RPCはコメントを削除しない。

破壊的な成功系は、既存方針どおり専用fixtureと `RUN_DESTRUCTIVE_TESTS=true` の扱いを分ける。

## 15. 実装段階案

| 段階 | 内容 | DB/SQL |
| --- | --- | --- |
| M-11D-1 | 申請辞退/申請履歴フロー調査・設計。本docs作成。 | なし |
| M-11D-2 | 本人辞退RPC SQL草案。`cancel_my_session_application` の対象status、戻り値、grant、rollback、確認SQLを整理。 | 草案のみ |
| M-11D-3 | 本人辞退UI。`session-detail.html` に「参加申請を取り下げる」導線、確認、成功後再取得を追加。 | なし想定 |
| M-11D-4 | GM向け申請履歴RPC SQL草案。`get_gm_session_application_history` の返却列とRLS境界を整理。 | 草案のみ |
| M-11D-5 | GM向け申請履歴折りたたみUI。GM/adminだけに表示し、人物単位のstatus一覧を出す。 | なし想定 |
| M-11D-6 | RLS smoke test強化。本人辞退、他人辞退不可、GM履歴可否、内部情報非露出を追加。 | テストのみ |
| M-11D-7 | 実ブラウザ確認結果docs化。公開版確認、secret非露出、commit/pushなしを記録。 | なし |

「辞退コメントとして投稿」は、M-11D-3後に必要性を見て、M-11D-8または別工程に分ける。

## 16. まだやらないこと

今回やらないこと:

- 本番フロント実装
- SQL Editor実行
- DB構造変更
- 申請辞退RPC実行
- GM操作実装
- `close_session` 呼び出し
- `updates.json` 変更
- secret類の出力
- `git add .`
- commit / push

M-11D-1時点ではSQL草案ファイルは作成しない。次工程M-11D-2で、今回の設計を正本にして別途作成する。

## 17. M-11D-2 追記

2026-06-01に、M-11D-2として本人申請辞退RPCの設計docsとSQL草案を追加した。

- 設計docs: `docs/supabase-session-detail-application-withdraw-rpc-plan.md`
- SQL草案: `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql`
- 採用RPC案: `cancel_my_session_application(target_session_id text)`
- 採用status: `canceled`
- 対象status: `pending` / `waitlisted` / `accepted`
- `rejected` は辞退対象外。
- `canceled` は安全に現在値を返す。
- コメント本文は削除しない。
- SQL Editor実行、DB変更、RPC実行、本番フロント実装、GM履歴RPC実装、`updates.json` 変更、commit / pushは行っていない。

## 18. M-11D-2 SQL適用結果追記

2026-06-01に、ユーザーがSupabase SQL Editorで `cancel_my_session_application(target_session_id text)` を作成した。適用結果は `docs/supabase-session-detail-application-withdraw-rpc-result.md` に分離して記録した。

確認済み:

- status制約に `canceled` が含まれる。
- `session_applications` に `session_id` / `user_id` / `status` / `created_at` / `updated_at` / `canceled_at` がある。
- 作成前に同名RPC `cancel_my_session_application` は存在しない。
- 作成後の関数定義は `cancel_my_session_application(text)`、`security definer = true`、引数 `target_session_id text`。
- 戻り値は `session_id` / `application_status` / `canceled_at` / `updated_at`。
- grant確認では `authenticated EXECUTE` と `postgres EXECUTE` があり、`anon EXECUTE` はない。
- `postgres EXECUTE` はownerまたは管理者側の表示として扱い、anon / PUBLICへの広いgrantとは見なさない。

未実施:

- RPC実行テストはまだ行っていない。
- rollbackは未実行。
- 本番フロント実装はまだ行っていない。
- このdocs追記工程でCodexはSQL Editorを実行していない。
- このdocs追記工程でCodexはDB変更、RPC実行、`updates.json` 変更、commit / pushを行っていない。

注意:

- `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql` のRPC作成SQLは適用済みのため、通常運用では同じ作成SQLをそのまま再実行しない。

## 19. M-11D-6 再申請復帰確認追記

2026-06-01に、ユーザー実ブラウザで辞退後の再申請復帰を確認した。詳細は `docs/supabase-session-detail-application-withdraw-reapply-result.md` に分離して記録した。

確認済み:

- 申請取り下げ後も、コメント本文は削除されず残る。
- 申請取り下げ後、公開人数カウントの申請中人数から除外される。
- 申請取り下げ後、mypageの参加申請中から対象セッションが消える。
- 参加希望コメントを投稿し直すと、再申請扱いになる。
- `create_application_comment` により、`session_applications.status` は `canceled` から `pending` 相当に復帰する挙動として扱う。
- コメントは増えても、申請人数はユーザー単位のため重複カウントされない。
- 公開版でも確認済み。

これにより、M-11D本線では「辞退は別ボタン」「再申請は既存の参加希望コメント投稿」という方針を維持する。

この追記工程で、フロント実装、SQL Editor実行、DB変更、`updates.json` 変更、secret類の記録、commit / pushは行っていない。
