# Supabase F-6 RLS smoke test更新計画

## 1. 目的

F-6で追加されたコメント編集・削除・申請取消RPCを、Auth文脈のRLS smoke testへ追加するための設計メモ。

この計画の目的は次のとおり。

- `update_application_comment(target_comment_id uuid, comment_body text)` の本人 / 他人 / GM / 他GM / 未ログイン差を確認する
- `delete_application_comment_and_maybe_cancel(target_comment_id uuid)` の削除権限と申請取消連動を確認する
- コメント編集・削除・申請取消が本番 `session-detail.html` 統合前に安全に検証できる状態を作る
- 状態変更を伴うテストを、通常実行と明示フラグ付き実行に分ける
- RLS smoke testの既存 `PASS` / `FAIL` / `SKIP` 出力形式を維持する

この工程では、まだ `scripts/supabase-rls-smoke-test.mjs` は変更しない。

## 2. 対象RPC

| RPC | 引数 | 目的 |
| --- | --- | --- |
| `update_application_comment` | `target_comment_id uuid`, `comment_body text` | 参加希望コメント本文を編集する |
| `delete_application_comment_and_maybe_cancel` | `target_comment_id uuid` | コメントを論理削除し、必要に応じて申請を `canceled` にする |

対象外:

- `close_session`
- `set_application_status`
- Discord連携
- 通知 / メール送信
- 本番ページ統合

## 3. 既存smoke testの前提

既存の `scripts/supabase-rls-smoke-test.mjs` は、次の前提で動いている。

- `.env.local` を明示的に読む
- anon client と authenticated user client を分ける
- `signInWithPassword` で `player A` / `player B` / `gm A` / `gm B` / `admin` を使う
- `runTest` / `skipTest` / `expectOk` / `expectError` の形で結果を集計する
- 失敗時はSupabase errorの `message` / `code` / `details` / `hint` 程度に整形する
- URL、key、password、token類はログに出さない
- `RUN_DESTRUCTIVE_TESTS=true` の場合のみ、破壊的な成功系を実行する
- 現在の `AUTH-018` は `close_session` 成功系を意図的にSKIPしている

F-6追加テストも、この作りに合わせる。

## 4. テスト分類

| 分類 | 対象例 | 実行方針 |
| --- | --- | --- |
| 非破壊テスト | anonが編集・削除RPCを実行できない、空文字や長文が拒否される、他人操作が拒否される | 通常実行に含める |
| 状態変更を伴うテスト | テスト用コメント本文の編集、テスト用コメントの論理削除、公開RPCから消える確認 | 通常実行に含めるが、専用fixtureを使う |
| 破壊的または戻しが必要なテスト | 最後の有効申請コメント削除でapplicationを `canceled` にする | 原則SKIPまたは専用fixture限定 |
| `RUN_DESTRUCTIVE_TESTS` が必要なテスト | accepted済み申請の最後の有効コメント削除、戻しが難しい状態遷移 | 明示フラグ付きでのみ実行 |

コメント編集・削除はDB状態変更を伴う。通常実行では、既存の重要fixtureを壊さず、テスト専用に作成したコメントを対象にする。

## 5. `update_application_comment` テストケース案

| テストID | 主体 | 操作 | 期待結果 | 分類 |
| --- | --- | --- | --- | --- |
| `F6-EDIT-001` | player A | 自分のコメントを編集 | 成功 | 状態変更 |
| `F6-EDIT-002` | player A | player Bのコメントを編集 | 失敗 | 非破壊 |
| `F6-EDIT-003` | GM A | 自分のsessionのコメントを編集 | 成功 | 状態変更 |
| `F6-EDIT-004` | GM A | GM Bのsessionのコメントを編集 | 失敗 | 非破壊 |
| `F6-EDIT-005` | anon / 未ログイン | コメントを編集 | 失敗 | 非破壊 |
| `F6-EDIT-006` | player A | 空文字で編集 | 失敗 | 非破壊 |
| `F6-EDIT-007` | player A | 4000字超過で編集 | 失敗 | 非破壊 |
| `F6-EDIT-008` | player A / GM A | 削除済みコメントを編集 | 失敗 | 状態変更後確認 |

確認観点:

- 本人は自分のコメントのみ編集できる
- GMは自分のsessionに紐づくコメントのみ編集できる
- 他人 / 他GM / anon は編集できない
- 編集後、公開コメントRPCに更新後本文が出る
- 削除済みコメントは編集できない
- secret、token、内部 `user_id`、Discord IDをログや画面に出さない

## 6. `delete_application_comment_and_maybe_cancel` テストケース案

| テストID | 主体 | 操作 | 期待結果 | 分類 |
| --- | --- | --- | --- | --- |
| `F6-DELETE-001` | player A | 自分のコメントを削除 | 成功 | 状態変更 |
| `F6-DELETE-002` | player A | player Bのコメントを削除 | 失敗 | 非破壊 |
| `F6-DELETE-003` | GM A | 自分のsessionのコメントを削除 | 成功 | 状態変更 |
| `F6-DELETE-004` | GM A | GM Bのsessionのコメントを削除 | 失敗 | 非破壊 |
| `F6-DELETE-005` | anon / 未ログイン | コメントを削除 | 失敗 | 非破壊 |
| `F6-DELETE-006` | player A | 最後の有効申請コメントを削除 | applicationが `canceled` になる | 破壊的または要復旧 |
| `F6-DELETE-007` | player A | 有効申請コメントが残る状態で1件削除 | application statusは維持 | 状態変更 |
| `F6-DELETE-008` | player A / GM A | 非申請コメントを削除 | application statusは変わらない | 状態変更 |
| `F6-DELETE-009` | anon | 削除済みコメントを公開RPCで読む | 削除済みコメントは返らない | 状態変更後確認 |
| `F6-DELETE-010` | anon | 参加人数RPCを読む | `canceled` は人数に含まれない | 状態変更後確認 |
| `F6-DELETE-011` | player A / GM A | accepted済み申請の最後の有効コメントを削除 | 通常実行ではSKIP | `RUN_DESTRUCTIVE_TESTS` |

accepted済み申請の最後の有効コメント削除は、運用上の影響が大きい。通常のsmoke testではSKIPし、明示フラグ付きでのみ実行する。

## 7. seed / fixture 方針

F-6追加テストでは、次のfixtureが必要になる。

| fixture | 用途 |
| --- | --- |
| player Aの申請コメント | 本人編集・本人削除 |
| player Bの申請コメント | 他人編集・他人削除拒否 |
| 同一ユーザーの複数申請コメント | 1件削除してもapplication statusを維持する確認 |
| 非申請コメント | 削除してもapplication statusが変わらない確認 |
| GM Aのsession | GM A管理成功系 |
| GM Bのsession | 他GM操作拒否 |
| `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` application | 集計・状態遷移確認 |
| 削除済みコメント | 編集拒否・公開RPC非表示確認 |

既存の `create_application_comment` は参加申請コメントを作るため、非申請コメントfixtureは現行RPCだけでは作りにくい可能性がある。その場合は、F-6 smoke test実装時に以下のどちらかを選ぶ。

1. 非申請コメントケースはSQL seed更新後に追加する
2. 非申請コメントケースを初回スクリプト更新ではSKIPし、必要fixture不足として記録する

この計画書ではseed実装は行わない。

## 8. 復旧・後片付け方針

状態変更テストは、次の方針で扱う。

- 編集テストは、テスト専用コメントを作って編集する
- 編集後の本文は元に戻すか、smoke test用本文として残してよいものだけにする
- 論理削除したコメントは再利用しない
- 削除テスト用コメントは、実行ごとに新規作成する
- applicationを `canceled` にするテストは、専用session / 専用ユーザーに限定する
- `canceled` にしたapplicationを戻す必要がある場合は、GM/admin権限の既存RPCまたは再seedで戻す
- `RUN_DESTRUCTIVE_TESTS` なしでは、accepted済み申請の最後の有効コメント削除は実行しない
- テストデータが増えるため、必要に応じて再seedやテスト環境作り直しを選ぶ

## 9. スクリプト実装方針

`scripts/supabase-rls-smoke-test.mjs` を更新する場合は、次の方針にする。

- 既存の `PASS` / `FAIL` / `SKIP` 出力形式に合わせる
- 既存のAuth helper、RPC helper、error formatterを流用する
- F-6用ヘルパーを追加する
  - `updateApplicationComment(client, commentId, body)`
  - `deleteApplicationCommentAndMaybeCancel(client, commentId)`
  - `getPublicComments(sessionId)`
  - `getApplicationStatus(client, sessionId, userId)` または既存取得処理の再利用
- テストIDは `F6-EDIT-001`、`F6-DELETE-001` のように分ける
- 破壊的テストは `skipTest` で明示的にSKIPできるようにする
- 失敗時もURL、key、password、token類をログに出さない
- RPC引数名はSQL定義に合わせる
- サーバー専用鍵は使わない

初回実装では、通常実行で安全に確認できるケースを優先する。accepted済み申請の最後のコメント削除など、戻し方の確認が必要なものは後続に分ける。

## 10. F-6 smoke test更新で扱わないもの

この更新計画では、以下を扱わない。

- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- devコメント編集・削除プロトタイプ
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- 本番サイトへのSupabase接続

## 11. 次工程候補

次工程候補:

1. F-6 RLS smoke test更新計画のcommit / push
2. `scripts/supabase-rls-smoke-test.mjs` へのF-6テスト実装
3. Auth文脈でのF-6 smoke test実行
4. テスト結果docs記録
5. F-6 devコメント編集・削除プロトタイプ設計・実装
6. 本番 `session-detail.html` 統合前UX設計

## 12. スクリプト実装メモ

`scripts/supabase-rls-smoke-test.mjs` にF-6追加RPCのAuth文脈テストを追加済み。

通常実行で確認した結果:

```text
PASS: 29
FAIL: 0
SKIP: 10
```

通常実行では、コメント削除成功系、削除済みコメント確認、最後の有効コメント削除による `canceled` 化、accepted済み申請の最後の有効コメント削除はSKIPする。

実行時の注意:

- `RUN_DESTRUCTIVE_TESTS=true` なしでは、論理削除成功系と復旧困難な状態変更は実行しない。
- 現行fixtureでは非申請コメントと最後の有効申請コメントを安全に作り分けられないため、該当ケースはSKIPする。
- `close_session` はF-6対象外のまま。
- 本番ページへのSupabase接続、追加SQL実行、dev UI実装は行っていない。
