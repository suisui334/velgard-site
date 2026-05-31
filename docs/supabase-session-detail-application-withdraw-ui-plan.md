# Supabase M-11D-3 本人申請辞退UI 実装前確認・設計

作業日: 2026-06-01

## 1. 目的

本人申請辞退UIを本番フロントへ実装する前に、`session-detail.html` 上の配置、表示文言、辞退後の画面状態、`mypage.html` への影響、テスト方針を整理する。

この工程では、本番フロント実装、`cancel_my_session_application` 呼び出し実装、RPC実行、SQL Editor実行、DB変更、GM履歴RPC / UI実装、`updates.json` 変更、commit / pushは行わない。

## 2. 調査したファイル

- `docs/supabase-session-detail-application-withdraw-rpc-result.md`
- `docs/supabase-session-detail-application-withdraw-rpc-plan.md`
- `docs/supabase-session-detail-application-withdraw-history-plan.md`
- `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql`
- `docs/supabase-session-detail-application-comment-delete-result.md`
- `docs/supabase-session-detail-application-comment-edit-result.md`
- `docs/supabase-session-detail-application-comment-post-result.md`
- `docs/supabase-mypage-applications-list-result.md`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderMypage.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDisplay.js`
- `session-detail.html`
- `README.md`
- `docs/task-backlog.md`
- `scripts/supabase-rls-smoke-test.mjs`

`assets/js/supabaseRuntimeConfig.js` は実値確認対象にせず、Project URL / key類は記録しない。

## 3. 既存実装の確認結果

`session-detail.html` の参加希望コメント欄は、`assets/js/sessionDisplay.js` が `data-session-application-panel` を持つパネルとして生成し、`assets/js/sessionDetailApplicationComments.js` が初期化する構造になっている。

現状の主な構成:

- `data-session-comment-post-control`: 本人申請状態メッセージと投稿フォームを表示する領域。
- `data-session-comment-counts`: `get_public_session_application_counts` の `pending_count` / `accepted_count` を表示する領域。
- `data-session-comment-list`: `get_public_session_comments` の公開コメント一覧を表示する領域。
- コメントカード内操作: 本人コメントの編集 / 削除だけを表示する領域。

本人申請状態は `session_applications` から `session_id,status,created_at,updated_at,canceled_at` のみ取得している。`APPLICATION_STATUS_MESSAGES.canceled` と `shouldShowCommentForm()` により、`canceled` でも投稿フォームは出る。つまり、既存方針どおり `create_application_comment` による再申請導線を置きやすい。

`mypageAuthClient.js` は `APPLICATION_STATUSES = ["pending", "waitlisted", "accepted"]` のみを取得する。`canceled` は「参加申請中」「参加予定」のどちらにも出ない。

## 4. UI配置案

推奨配置は、参加希望コメント欄の `data-session-comment-post-control` 内、本人申請状態メッセージの直下、投稿フォームの直上。

理由:

- 「参加申請中です」という本人状態案内の近くに置ける。
- コメントカード内の編集 / 削除操作と距離を取り、コメント削除と申請辞退を混同しにくい。
- GM操作領域ではなく、PL本人の申請状態操作として扱える。
- 辞退後の再申請投稿フォームとのつながりが自然。

表示条件案:

- ログイン済み。
- セッションが `public` かつ `recruiting` / `tentative`。
- 本人の `session_applications` 行がある。
- 本人申請statusが `pending` / `waitlisted` / `accepted`。
- `rejected` / `canceled` では辞退ボタンを出さない。
- 投稿中、コメント保存中、コメント削除中、辞退実行中は押せない。
- コメント編集中またはコメント削除確認中も押せない。

ボタンはコメント本文カード内に置かない。削除ボタンの隣にも置かない。

## 5. 表示文言案

辞退前の本人状態:

```text
参加申請中です。
```

辞退ボタン:

```text
参加申請を取り下げる
```

`accepted` の場合は、本人状態を次のように強める。

```text
参加予定として承認済みです。
```

`accepted` 用ボタンは同じでもよいが、確認UIでは参加予定から外れることを明示する。

通常の確認UI:

```text
参加申請を取り下げますか？
コメントは履歴として残りますが、申請中人数からは除外されます。
```

`accepted` の確認UI:

```text
承認済みの参加予定を取り下げますか？
取り下げ後は参加予定から外れます。必要ならGMへコメントで事情を伝えてください。
```

確認ボタン:

```text
取り下げる
キャンセル
```

辞退後:

```text
このセッションへの参加申請は取り下げ済みです。
再申請する場合は、参加希望コメントを投稿してください。
```

既存の `APPLICATION_STATUS_MESSAGES.canceled` は、実装時に上記へ寄せると「取消」と「取り下げ」の揺れが減る。

## 6. 辞退後の画面状態

`cancel_my_session_application(target_session_id text)` が成功した後は、既存の投稿 / 編集 / 削除成功後と同じく、楽観更新せず再取得結果を正とする。

再取得対象:

- `get_public_session_comments(target_session_id)`
- `get_public_session_application_counts(target_session_id)`
- 本人 `session_applications` 行

期待状態:

- 本人申請statusは `canceled`。
- 申請中人数は、`pending` / `waitlisted` からの辞退なら1名減る。
- 承認済み人数は、`accepted` からの辞退なら1名減る可能性がある。
- コメント一覧は残る。
- コメントカードの申請statusバッジは `取消済み` になる想定。
- 投稿フォームは表示し、再申請コメントを投稿できる状態にする。
- 成功メッセージは短く `参加申請を取り下げました。` 程度にする。

エラー時はSupabase詳細、SQL詳細、内部ID、email、token、key、secret類を出さず、短い安全文言にする。

```text
参加申請を取り下げられませんでした。時間をおいて再度お試しください。
権限がないか、申請状態が変更された可能性があります。
```

## 7. mypageへの影響

`mypageAuthClient.js` は `pending` / `waitlisted` / `accepted` だけを取得するため、`canceled` になった申請は現在の「参加申請中」「参加予定」から消える。

短期方針では、この非表示挙動でよい。マイページに「取り下げ済み履歴」を出す場合は、M-11D本線ではなく将来の履歴表示工程で扱う。

## 8. session-detailへの影響

人数表示は `get_public_session_application_counts` の戻り値を使う。既存方針どおり `canceled` は公開人数カウントから除外される。

`sessionDetailApplicationComments.js` には `canceled` のラベルがあり、公開コメント一覧では `取消済み` として表示できる。コメント本文は削除しないため、GMやPLが文脈を読み返せる。

辞退後も投稿フォームを出す方針は、既存 `create_application_comment` の `canceled -> pending` 再申請仕様と合う。

## 9. 再申請方針

既存 `create_application_comment(target_session_id, comment_body)` は、`canceled` の既存申請を `pending` に戻す設計として整理済み。

そのため、本人辞退後の再申請は新規RPCを追加せず、既存の参加希望コメント投稿フォームを使う。

確認すべき観点:

- `canceled` 後も投稿フォームが表示される。
- 投稿成功後に本人申請状態が `pending` に戻る。
- 投稿成功後に申請中人数へ戻る。
- `canceled_at` はRPC仕様どおり再申請時に消える想定だが、過去の辞退時刻を履歴として追うなら将来 `session_application_events` が必要。

## 10. テストデータ影響

現在の検証対象として整理されている公開セッションID:

```text
session-2026-06-08-railway-incident
```

テストプレイヤーAは現在 `pending` の想定。

このユーザーで辞退RPCを実行すると、`session_applications.status = canceled` になり、申請中カウントとmypage表示から外れる。再申請コメント投稿で `pending` に戻せる方針だが、今回の工程では実行しない。

次工程以降で実操作確認する場合は、次のどちらかを採用する。

- テストプレイヤーAで辞退確認し、同じ工程内で再申請コメント投稿により `pending` 復帰まで確認する。
- 辞退専用の別ユーザー / 別セッションfixtureを用意し、既存の公開確認データを汚さない。

推奨は、専用fixtureを用意できるなら後者。既存の `session-2026-06-08-railway-incident` はmypage / session-detailの公開確認に使われているため、辞退成功だけで止めない。

## 11. 実装段階案

M-11D-3:

- 今回の実装前確認・UI設計docs作成。
- 本番フロント実装、RPC呼び出し、DB変更はしない。

M-11D-4:

- `session-detail.html` 側で、辞退UIの状態表示と配置だけを実装する。
- `canceled` 表示文言を「取り下げ済み」に寄せる。
- まだ `cancel_my_session_application` は呼ばない。

M-11D-5:

- 確認UIと `cancel_my_session_application(target_session_id text)` 呼び出しを接続する。
- 成功後はコメント一覧、人数、本人申請状態を再取得する。
- Codex側では実RPCクリックを行わず、ユーザー実ブラウザ確認または専用fixture工程に分ける。

M-11D-6:

- 辞退後の再申請確認とRLS smoke test更新案を整理する。
- 破壊的成功系は専用fixtureと `RUN_DESTRUCTIVE_TESTS=true` を分ける。

M-11D-7:

- GM向け申請履歴RPC草案を作る。
- 本人辞退とコメント削除を、GMが後から区別できる履歴設計を検討する。

M-11D-8:

- GM向け申請履歴UIを折りたたみで実装する。

「辞退コメントとして投稿」は、本人辞退ボタンの実装と再申請確認が安定した後の追加候補にする。

## 12. まだやらないこと

- 本番フロント実装
- `cancel_my_session_application` 呼び出し実装
- `cancel_my_session_application` 実行
- SQL Editor実行
- DB変更
- GM履歴RPC実装
- GM履歴UI実装
- `close_session` 呼び出し
- `updates.json` 変更
- secret類、実Project URL、実key、実email、実user_id全文の記録
- `git add .`
- commit / push
