# Supabase M-11E-1 GM向け申請履歴RPC / 折りたたみUI 調査・設計

作業日: 2026-06-01

## 1. 今回の目的

GMが自分の担当セッションについて、参加申請の現在状態を人物単位で安全に確認できるようにするため、`get_gm_session_application_history(target_session_id text)` と `session-detail.html` 上の控えめな折りたたみUIを設計する。

今回は調査・設計のみを行う。本番フロント実装、SQL Editor実行、DB変更、GM履歴RPC実行、GM承認 / 却下UI実装、Discord IDコピー実装、`close_session` 呼び出しは行わない。

## 2. GM向け申請履歴が必要な理由

PL側は以下の操作ができるようになっている。

- コメント投稿 = 参加申請。
- 同一ユーザーの複数コメントは申請人数として重複カウントしない。
- 本人コメントの編集 / 削除。
- 最後の有効コメント削除時の申請取消扱い。
- コメントを残したまま本人が申請を取り下げる操作。
- 取り下げ後、コメント投稿で `pending` 相当に再申請する挙動。

次に必要なのは、GMが「誰が申請中か」「誰が承認済みか」「誰が辞退 / 取消済みか」「誰が却下されたか」「最後にいつ状態が動いたか」を必要な時だけ確認できる導線である。常時表示するとPL向け画面が重くなるため、GM/adminだけに閉じた折りたたみ表示を基本にする。

## 3. 既存調査結果

### 3-1. DB / RLS

`session_applications` は `session_id + user_id` 単位の人物別申請状態を持つ。

主な列:

- `id`
- `session_id`
- `user_id`
- `comment_id`
- `status`
- `created_at`
- `updated_at`
- `canceled_at`

`status` は次の5種類。

- `pending`
- `accepted`
- `rejected`
- `waitlisted`
- `canceled`

`public_profiles` は `id` / `display_name` のみを返す公開表示用viewであり、GM履歴RPCでも表示名取得の参照口として使える。

`session_applications` のRLSは本人 / 対象GM / adminにSELECTを許す方針。公開PL向けには `session_applications` を直接広く読ませず、公開RPCや本人用最小SELECTへ寄せている。

### 3-2. GM判定方法

既存のGM判定は以下を使う。

- `public.is_admin()`
- `public.is_session_gm(target_session_id text)`

`is_session_gm(target_session_id text)` は `sessions.gm_user_id = auth.uid()` を確認し、adminも許可する設計になっている。GM履歴RPCでは読みやすさと将来変更への耐性のため、`public.is_admin() or public.is_session_gm(target_session_id)` を明示条件にする。

確認したこと:

- 対象セッションGMは、自分の担当セッションの履歴を読める設計にできる。
- adminは読める設計にできる。
- 非GM / 非adminはRPCで拒否する方針にする。
- `public_profiles` 経由で `display_name` だけを返し、email / `user_id` 全文は返さない。
- `user_id` はJOINや集計の内部キーとしてのみ使い、戻り値にも画面表示にも出さない。

### 3-3. 既存フロント

`assets/js/sessionDetailApplicationComments.js` は現在、公開コメントRPC、人数カウントRPC、本人申請状態SELECTを使っている。

- 公開コメント: `get_public_session_comments(target_session_id)`
- 人数カウント: `get_public_session_application_counts(target_session_id)`
- 本人申請: `session_applications` の `session_id,status,created_at,updated_at,canceled_at`
- 本人辞退: `cancel_my_session_application(target_session_id text)`

本番 `session-detail.html` にはGM履歴UIはまだない。今回も追加しない。

## 4. 表示する情報 / 表示しない情報

### 表示する情報

GM履歴RPC / UIで表示してよい情報:

- `display_name`
- `application_status`
- status表示名
- `created_at`
- `updated_at`
- `canceled_at`
- 関連する有効参加希望コメント数
- 最終有効コメント日時

将来候補:

- 辞退コメントの有無。
- 承認後辞退かどうか。
- Discord IDコピー用導線の足場。

### 表示しない情報

戻り値、画面、console、docsに出さない情報:

- email
- `user_id` 全文
- access token / refresh token / JWT
- Project URL / key実値
- secret類
- `application_id`
- `comment_id`
- Discord ID
- role

`application_id` / `comment_id` は将来のGM操作UIでは内部的に必要になる可能性があるが、この履歴表示RPCでは返さない。承認 / 却下などの操作RPCとは分ける。

## 5. RPC案

採用候補:

```text
get_gm_session_application_history(target_session_id text)
```

戻り値:

```text
display_name text
application_status text
created_at timestamptz
updated_at timestamptz
canceled_at timestamptz
comment_count integer
last_comment_at timestamptz
```

設計方針:

- `authenticated` のみ実行可能。
- `public.is_admin()` または `public.is_session_gm(target_session_id)` の場合だけ返す。
- 非GM / 非adminは0件ではなく `not allowed` で拒否する案を第一候補にする。
- adminが存在しないセッションIDを指定した場合は0件になり得る。
- `session_applications` を主軸にするため、`canceled` / `rejected` も返す。
- `display_name` は `public_profiles` から取得する。
- `user_id` / email / `application_id` / `comment_id` / Discord IDは返さない。
- `comment_count` は有効な参加希望コメント数として扱う。
- `last_comment_at` は有効な参加希望コメントの最終日時として扱う。

完全な状態遷移履歴ではない点に注意する。`session_applications` は現在行であり、再申請時に `canceled_at` がnullへ戻るため、「過去に何度辞退したか」まで追うには将来 `session_application_events` のようなイベントテーブルが必要になる。

## 6. deletedコメントの扱い

推奨方針は、`session_applications` 行を履歴の主軸にし、コメントは補助情報にすること。

今回のRPC草案では次の扱いにする。

- 履歴行の存在判定は `session_applications` を使う。
- `comment_count` は `deleted_at is null` の有効参加希望コメントだけを数える。
- `last_comment_at` も有効参加希望コメントだけを対象にする。
- 削除済みコメントしか残っていない場合でも、`session_applications` 行があれば履歴行は返る。
- その場合 `comment_count = 0`、`last_comment_at = null` になり得る。

理由:

- 削除済みコメント本文や内部IDをGM履歴の表示正本にしない。
- 「誰が申請したことがあるか」は `session_applications` の人物単位行で追う。
- コメントは発言ログであり、申請履歴そのものではない。

将来、削除済みコメントも過去活動として数えたい場合は、`comment_count` の意味を変えるのではなく、`active_comment_count` / `total_comment_count` / `deleted_comment_count` のように列を分ける。

## 7. UI案

配置候補:

- `session-detail` の参加希望コメント欄の下。
- 申請人数カウントとコメント一覧のあと、投稿 / 本人状態UIより下またはコメント欄全体の末尾。
- GM/adminだけに表示する。

折りたたみ初期状態:

- 閉じる。
- ボタン文言は `GM向け：申請履歴を見る` を第一候補にする。
- 開いた時だけRPCを呼び、通常表示時の負荷と情報露出面を小さくする。

開いた内容例:

```text
申請中
- Aさん

承認済み
- Bさん

辞退 / 取消
- Cさん（更新日時）

却下
- Dさん
```

スマホ方針:

- 人物名、状態、更新日時を縦積みで表示する。
- 大きな表より、状態グループごとの短いリストを基本にする。
- `comment_count` と `last_comment_at` は補助メタとして小さく表示する。
- 内部IDはツールチップやdata属性にも置かない。

## 8. status表示方針

GM履歴UIでの表示名:

| DB status | 表示名 | グループ |
| --- | --- | --- |
| `pending` | 申請中 | 申請中 |
| `waitlisted` | 申請中 | 申請中 |
| `accepted` | 承認済み | 承認済み |
| `canceled` | 辞退 / 取消 | 辞退 / 取消 |
| `rejected` | 却下 | 却下 |

`waitlisted` は今の運用では積極利用しないが、DB上にあるため、履歴UIでは `pending` と同じ「申請中」グループに置く。

## 9. Discord IDコピー機能との関係

今回はDiscord IDコピーを実装しない。

方針:

- 今回の履歴RPCにDiscord IDを含めない。
- emailや `user_id` ではなく、将来ユーザーが公開 / 許可したDiscord IDだけを扱う。
- Discord ID登録機能ができた後、別RPCまたはGM専用RPCとして設計する。
- 承認済み参加者だけを対象にする場合も、今回の履歴RPCに列を足す前に別工程で要件を確認する。

## 10. RLS smoke test案

将来 `scripts/supabase-rls-smoke-test.mjs` に追加する候補:

- GM Aは自分の担当セッションの履歴RPCを読める。
- adminは履歴RPCを読める。
- GM AはGM B担当セッションの履歴RPCを読めない。
- playerは他人を含む履歴RPCを読めない。
- anonは履歴RPCを実行できない。
- 戻り値に `user_id` / email / `application_id` / `comment_id` / Discord ID / token / key / secret類がない。
- `canceled` / `rejected` の行も履歴RPCでは返る。
- 削除済みコメントがあってもRPCが失敗しない。
- 有効コメントが0件でも `session_applications` 行があれば履歴行が返る。

状態変更を伴うfixturesは `RUN_DESTRUCTIVE_TESTS` や専用seedと切り分ける。SQL Editorのowner文脈ではRLS / Auth境界の確認にしない。

## 11. 実装段階案

推奨分割:

| 段階 | 内容 | DB変更 |
| --- | --- | --- |
| M-11E-1 | GM向け申請履歴RPC / UI 調査・設計 | なし |
| M-11E-2 | GM向け申請履歴RPC SQL草案 | 草案のみ |
| M-11E-3 | SQL適用・結果記録 | あり。ユーザー側SQL Editor工程 |
| M-11E-4 | session-detail GM履歴折りたたみUI 状態表示 | なし |
| M-11E-5 | GM履歴RPC接続 | RPC呼び出しあり。Codex側では実データ変更なし |
| M-11E-6 | RLS smoke test強化 | テストのみ |

補足案:

- M-11E-4では、最初にGM判定UI器と閉じた状態だけを作る。
- M-11E-5で、開いた時だけRPCを呼ぶ。
- GM承認 / 却下ボタンはM-11Eには混ぜず、M-11F以降に分ける。
- 完全な状態遷移監査ログが必要になった場合は、M-12以降で `session_application_events` を別設計にする。

## 12. まだやらないこと

- 本番フロント実装。
- SQL Editor実行。
- DB変更。
- GM履歴RPC実行。
- GM承認 / 却下UI実装。
- Discord IDコピー実装。
- `close_session` 呼び出し。
- `updates.json` 変更。
- secret類、実Project URL、実key値、email、内部ID実値の記録。
- commit / push。

## 13. SQL草案

SQL草案は次に分離した。

```text
docs/supabase/sql/013_gm_session_application_history_rpc_draft.sql
```

このSQL草案は実行していない。SQL Editor未実行、DB変更なし。
