# Supabase M-11 session-detail 参加希望コメント統合前 調査・設計

作業日: 2026-05-31

## 1. 目的

M-11では、本番 `session-detail.html` へ参加希望コメント機能を統合する前に、既存の静的セッション詳細表示、Supabase RPC / RLS、devプロトタイプ、M-10検証データの扱いを確認し、安全な実装順序を決める。

今回の工程では、本番フロント実装、SQL Editor実行、DBデータ変更、cleanup、`close_session` 呼び出しは行わない。

## 2. 現在の session-detail 構造

- `session-detail.html` は `#app` と `assets/js/main.js` だけを持つ薄いページ。
- `main.js` は `body[data-page="session-detail"]` のとき `renderSessionDetail.js` を呼ぶ。
- `renderSessionDetail.js` は URL パラメータ `id` を読み、`data/sessions.json` の `sessions[]` から `visibility === "public"` かつ `status !== "draft"` かつ ID が空でないものだけを対象にする。
- `id` 未指定時は「セッション予定IDが指定されていません。」、該当なしは「指定されたセッション予定が見つかりませんでした。」を表示する。
- 表示本体は `sessionDisplay.js` の `renderSessionDetailContent(session, { mode: "page" })`。
- ページ表示順は、見出し、基本情報、概要、詳細 / 参加条件、参加希望コメント、タグ、補足情報。
- `sessionDisplay.js` には `renderSessionApplicationPanel()` があり、現在は「参加希望コメント」の準備中モックを表示している。
- `closed` / `finished` / `canceled` では投稿不可の案内に切り替わる。
- 既存CSSは `body[data-page="session-detail"] .session-application-panel`、`.session-comment-form-mock`、`.session-comment-field`、`.session-comment-textarea`、`.session-comment-count-note` などを持つ。

`data/sessions.json` 側で公開詳細表示に使っている主な情報:

- `id`
- `title`
- `date`
- `startTime`
- `endTime`
- `gmName`
- `status`
- `levelRange`
- `playerMin`
- `playerMax`
- `playerCount`
- `summary`
- `detail`
- `requirements`
- `tags`
- `visibility`
- `updatedAt`

`gmUserId` やDiscordスレッドURL風の値はデータに存在するが、M-11の画面テキストとして追加表示しない。

## 3. 既存RPC / RLSで使えるもの

既存または反映済みとして確認できるもの:

| 用途 | 実名 | 現状 |
| --- | --- | --- |
| 公開コメント読み取り | `get_public_session_comments(target_session_id text)` | `anon` / `authenticated` 実行可。`display_name`、本文、申請状態、作成/更新/編集日時を返す。内部 `user_id` やDiscord IDは返さない。 |
| 公開人数読み取り | `get_public_session_application_counts(target_session_id text)` | `anon` / `authenticated` 実行可。`accepted_count`、`pending_count`、`waitlisted_count` を返す。 |
| 投稿 | `create_application_comment(target_session_id text, comment_body text)` | `authenticated` 実行可。`tentative` / `recruiting` の public session のみ許可する設計。 |
| GM状態変更 | `set_application_status(target_application_id uuid, new_status text)` | `authenticated` 実行可。`is_session_gm()` またはadmin判定で制御。 |
| コメント編集 | `update_application_comment(target_comment_id uuid, comment_body text)` | F-6でSQL反映済み。本人 / 対象GM / adminが実行できる設計。 |
| コメント論理削除・必要時取消 | `delete_application_comment_and_maybe_cancel(target_comment_id uuid)` | F-6でSQL反映済み。最後の有効申請コメント削除時に申請を `canceled` にできる。 |
| 権限判定 | `is_admin()` / `is_session_gm(target_session_id text)` | SQL草案とF-6結果で存在確認済み。 |
| 公開プロフィール | `public_profiles` | `id` / `display_name` のみ公開。 |

RLS / GRANT上の重要な境界:

- `session_comments` の直接SELECTは広げない方針。
- 公開コメント表示は `get_public_session_comments()` 経由を維持する。
- `session_applications` は `authenticated` にSELECT grantがあり、RLSで本人 / 対象GM / adminに制限される。
- `session_applications` には `unique (session_id, user_id)` があり、同一ユーザーの複数コメントでも申請人数は1人分。
- `canceled` は人数RPCの count 対象外。
- `public_profiles` は `id` / `display_name` のみに絞る。

## 4. 不足・再確認が必要なもの

- 本番 `session-detail.html` 用のSupabase接続モジュールはまだない。現状の `mypageAuthClient.js` はマイページ専用のIIFE。
- 参加希望コメント欄の実データマウント位置は既存モック内にあるが、実装時には静的表示が壊れない差し替え単位を決める必要がある。
- `get_public_session_comments()` は公開表示用であり、GM操作に必要な `application_id` は返さない。
- GM操作では `set_application_status()` のために `session_applications.id` が必要。既存devプロトタイプはRLSで見える `session_applications` と公開コメントRPCを `comment_id` で突合していたが、本番でも同じ方針にするか、GM専用RPC / viewを追加するか判断が必要。
- `get_public_session_comments()` は現行定義では `deleted_at is null` と public session を条件にする。将来 `session_comments` に非申請コメントを混ぜるなら、`is_application = true` の扱いを再確認する。
- PL本人の「自分の申請状態」表示は、`session_applications` の本人行SELECTで可能そうだが、M-11Aではまだ扱わない。
- accepted済み申請の最後の有効コメント削除は `canceled` 化の可能性があるため、本番UIでは強い確認が必要。
- `close_session` は既存RPCとして存在するが、M-11では呼び出さない。

## 5. M-11 段階分割案

M-11は以下の順で分けるのが安全。

| 段階 | 範囲 | DB変更 |
| --- | --- | --- |
| M-11A | `session-detail.html` の参加希望コメント欄を読み取り表示へ置き換える。公開コメント一覧、公開人数、未ログイン時のACCOUNT導線、接続失敗時フォールバックのみ。投稿・編集・削除・GM操作はなし。 | なし |
| M-11B | ログイン済みPLの投稿。`create_application_comment` を使い、投稿後にコメント一覧・人数・自分の申請状態を再読込する。 | なし想定 |
| M-11C | PL本人のコメント編集・削除。`update_application_comment` / `delete_application_comment_and_maybe_cancel` を使う。最後の有効コメント削除時の警告を入れる。 | なし想定 |
| M-11D | 自分の申請状態と人数表示の整備。本人行SELECT、pending / accepted / waitlisted / rejected / canceled の文言整理。 | なし想定 |
| M-11E | GM承認・却下・待機操作。`set_application_status` を統合する。`application_id` 取得方針を事前に固定する。 | GM専用RPC / view追加が必要になる可能性あり |
| M-11F | GMコメント編集・削除統合、accepted済み最後コメント削除の強警告、運用上の確認導線。 | なし想定だが要再確認 |

M-11E以降は、既存RLSで直接 `session_applications` を読ませる案と、GM向け最小列RPCを追加する案を比較してから進める。

## 6. 次に実装するなら M-11A で行う最小範囲

M-11Aの推奨範囲:

- 既存の「参加希望コメント」パネルを実データ用の器に差し替える、または既存パネル内に読み取り用マウントDOMを追加する。
- `get_public_session_comments(target_session_id)` で公開コメント一覧を読む。
- `get_public_session_application_counts(target_session_id)` で人数を読む。
- 表示するのは `display_name`、コメント本文、作成日時、編集日時、申請ステータス、人数だけにする。
- `comment_id`、`session_id` はDOM内部で必要になっても画面テキストとして出さない。
- 未ログイン時は投稿欄を出さず、`ACCOUNT` / `mypage.html` への短い導線を出す。
- Supabase未構成・通信失敗時も、セッション詳細本体と静的戻りリンクは壊さない。
- 投稿、編集、削除、GM承認・却下、`close_session` は実装しない。

M-11Aで使う既存RPCは読み取り専用で、`anon` にも実行権限があるため、DB変更なしで始められる見込み。ただし実装直前に公開RPCの戻り列が内部情報を含まないことを再確認する。

M-11A実装結果は `docs/supabase-session-detail-application-comments-read-result.md` に分離した。`session-detail.html` の参加希望コメント欄は公開コメント一覧と公開カウントの読み取り専用表示になり、人数カードは `申請中` / `承認済み` のみ表示する。投稿、編集、削除、GM操作、`close_session`、SQL実行、DB変更は行っていない。

`session-detail.html` の締切時間表示は、`data/sessions.json` に `applicationDeadline` / `deadlineTime` 等の明示フィールドを追加する設計が必要。`startTime` / `endTime` の流用はしない。

## 7. M-10 ID整合検証データの扱い

M-10 follow-upで投入済みの検証データは、M-11Aの読み取り表示検証にも使える。

- 公開JSON側に `session-2026-06-08-railway-incident` が存在する。
- `session-detail.html?id=session-2026-06-08-railway-incident` は既存構造上、公開セッションとして詳細表示できる。
- DB側にも同じセッションIDで `public.sessions`、`session_comments`、`session_applications` が各1件存在することが記録済み。
- 公開版 mypage では同IDの詳細リンク遷移確認済み。
- M-11Aではこのデータを使い、公開コメント読み取りと人数表示の確認に利用できる。
- `010_mypage_applications_id_aligned_test_data_draft.sql` は使用済みなので再実行しない。
- cleanupはM-11A読み取り検証後に判断する。今回の調査段階では実行しない。

## 8. 表示してよい情報 / 表示しない情報

表示してよい情報:

- `display_name`
- コメント本文
- コメント作成日時
- コメント更新日時
- コメント編集日時
- 申請ステータス
- 公開セッションタイトル
- 公開セッション日時
- 公開人数カウント

表示しない情報:

- email
- `user_id` 全文
- access token / refresh token / JWT
- Project URL実値
- anon key / publishable key 実値
- service role key
- DB password
- Direct connection string
- JWT secret
- `gmUserId`
- Discord ID
- `comment_id` / `application_id` / `session_id` などの内部IDの画面テキスト表示

内部IDはリンク生成やRPC引数に必要な場合のみ内部処理で使い、画面文言・console・docsには出さない。

## 9. RLS smoke test 更新要否

M-11Aは読み取り統合のみなので、既存の以下の観点で概ね足りる。

- `anon` が public comments RPC を呼べる。
- public comments RPC が内部 `user_id` / Discord IDを返さない。
- public counts RPC が private / hidden の人数を漏らさない。
- `session_comments` の直接SELECTを広げていない。

M-11B以降で追加・再確認する観点:

- 未ログイン / anon は投稿できない。
- authenticated は自分の参加希望コメントを投稿できる。
- 同一ユーザーの複数コメントで `session_applications` が重複しない。
- authenticated は他人のコメントを編集 / 削除できない。
- 本人は自分のコメントを編集 / 削除できる。
- GMは対象セッションのコメントを編集 / 削除できる。
- GMは承認 / 却下 / 待機に変更できる。
- 非GMは承認 / 却下 / 待機に変更できない。
- 最後の有効コメント削除時に申請が `canceled` になり、人数から除外される。

破壊的な削除成功系や `close_session` 成功系は、既存方針どおり `RUN_DESTRUCTIVE_TESTS=true` なしでは実行しない。

## 10. 実装前の停止条件

以下のどれかに当てはまる場合は、M-11A実装へ進まず設計へ戻る。

- `get_public_session_comments()` が内部 `user_id`、Discord ID、email、role、secret類を返す。
- public comments RPC が private / hidden session の本文を返す。
- public counts RPC が private / hidden session の人数を返す。
- `session-detail.html` の静的詳細表示がSupabase接続失敗時に消える設計になる。
- Project URL / key 実値をdocs、README、チャット、consoleへ出す必要が出る。
- M-11Aの範囲に投稿・編集・削除・GM操作が混ざる。
- DB変更やSQL Editor実行が必要になる。

## 11. まだやらないこと

- 本番フロント実装
- `session-detail.html` への実コード追加
- コメント投稿UIの実装
- コメント編集・削除UIの実装
- GM承認・却下UIの実装
- SQL Editor実行
- DBデータ変更
- cleanup SQL実行
- `close_session` 呼び出し
- `updates.json` 変更
- secret類の出力
- commit / push
