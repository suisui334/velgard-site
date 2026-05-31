# Supabase M-11B session-detail 参加希望コメント投稿 実装前調査・設計

作業日: 2026-05-31

## 1. 目的

M-11Bでは、ログイン済みPLが `session-detail.html` の参加希望コメント欄から参加希望コメントを投稿できるようにする。

今回の調査では、本番実装前に既存RPC、RLS、ログイン状態取得、UI差し込み位置、重複投稿、申請状態、エラー処理を確認し、書き込み実装で濁りやすい権限境界を先に固定する。

この工程では、本番フロント実装、投稿UI実装、RPC実呼び出し、SQL Editor実行、DBデータ変更は行わない。

## 2. 調査対象

- `docs/supabase-session-detail-application-comments-integration-plan.md`
- `docs/supabase-session-detail-application-comments-read-result.md`
- `docs/supabase-mypage-applications-id-aligned-test-data-result.md`
- `docs/supabase-mypage-applications-list-result.md`
- `docs/supabase-f4-application-comment-prototype.md`
- `docs/supabase-f5-gm-application-management-prototype.md`
- `docs/supabase-f6-comment-edit-delete-prototype.md`
- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `scripts/supabase-rls-smoke-test.mjs`
- `session-detail.html`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDisplay.js`
- `assets/js/main.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderMypage.js`
- `assets/js/supabaseRuntimeConfig.js`
- `data/sessions.json`
- `README.md`
- `docs/task-backlog.md`

補助的に、F-6 SQL実行結果、F-6 RPC草案、F-7 UX設計、`dev/supabase-application-comment-prototype.js` も確認した。

## 3. 既存RPC / RLS調査結果

### `create_application_comment`

正確な呼び出し:

```js
await supabase.rpc("create_application_comment", {
  target_session_id: sessionId,
  comment_body: commentBody
});
```

SQL定義上の仕様:

| 項目 | 内容 |
| --- | --- |
| RPC名 | `create_application_comment` |
| 引数 | `target_session_id text`, `comment_body text` |
| 返り値 | `uuid`。作成された `session_comments.id`。画面には表示しない |
| 実行権限 | `authenticated` のみ。`anon` は不可 |
| 認証条件 | `auth.uid()` が必要 |
| セッション条件 | `can_apply_to_session(target_session_id)` がtrue |
| 許可されるDB側session | `visibility = 'public'` かつ `status in ('tentative', 'recruiting')` |
| コメント検証 | `target_session_id` 必須、`comment_body` 必須、trim後空文字不可、4000文字以下 |
| 作成される行 | 必ず `session_comments` に `is_application = true` の新規コメントを作成 |

既存申請がない場合:

- `session_comments` を1件作成する。
- `session_applications` を `status = 'pending'`、`comment_id = 新規コメントID` で1件作成する。

既存申請が `canceled` の場合:

- `session_comments` を1件作成する。
- 既存 `session_applications` を `status = 'pending'`、`comment_id = 新規コメントID`、`canceled_at = null` に戻す。

既存申請が `pending` / `accepted` / `rejected` / `waitlisted` の場合:

- `session_comments` を1件作成する。
- `session_applications` の状態は変更しない。
- コメントは追記として保存され、人数は増えない。

### 人数集計

`session_applications` には `unique (session_id, user_id)` がある。人数RPCは `session_applications` を基準にし、`accepted` / `pending` / `waitlisted` を `distinct user_id` で数える。`canceled` は除外され、`rejected` も集計対象外。

したがって同一ユーザーが複数コメントしても、申請人数は1人分のままになる。

### 公開コメント読み取り

`get_public_session_comments(target_session_id text)` は `anon` / `authenticated` が実行できる。戻り値には `comment_id`、`session_id`、`display_name`、`body`、`application_status`、`created_at`、`updated_at`、`edited_at` が含まれる。

画面テキストとして出してよいのは、表示名、本文、申請状態、日時だけ。`comment_id` / `session_id` は処理上必要でも表示しない。

### 本人の申請状態取得

M-11Bでは、投稿フォームの状態出し分けのために本人の `session_applications` を読むのが望ましい。

推奨取得:

```js
client
  .from("session_applications")
  .select("session_id,status,created_at,updated_at,canceled_at")
  .eq("session_id", sessionId)
  .maybeSingle();
```

RLSにより本人行だけが見える。M-11Bでは編集・削除を扱わないため、`comment_id` や `application_id` は取得不要。`user_id` はselectしない。

## 4. 既存構造でできること

- 未ログインでも公開コメント一覧と公開人数は読み取れる。
- ログイン済みPLは `create_application_comment` で参加希望コメントを投稿できる。
- 投稿後は公開コメントRPCと人数RPCを再取得できる。
- `session_applications` のRLSで、ログイン済みユーザーは本人の申請状態だけ読める。
- DB側で、publicかつ `tentative` / `recruiting` のsession以外への投稿は拒否される。
- 同一ユーザーの複数コメントでも申請人数は増えない。
- `canceled` の既存申請は、同RPCで `pending` に戻せる。

## 5. 不足していること

- 本番 `session-detail.html` 用の投稿フォームDOMはまだない。
- M-11B用の投稿RPC呼び出しコードはまだない。
- 本人申請状態を `session-detail.html` で表示する実装はまだない。
- `rejected` 既存申請に追加コメントを許すか、再申請として扱うかの運用文言が未確定。
- 既存 `create_application_comment` は `rejected` を `pending` に戻さないため、再申請UIとしては使えない。
- `applicationDeadline` / `deadlineTime` などの明示締切フィールドは `data/sessions.json` にない。
- GM操作、編集、削除、申請取消は別工程。

## 6. 投稿UIの差し込み位置

現在の表示順は次の通り。

```text
基本情報 -> 概要 -> 補足情報 -> 参加希望コメント
```

参加希望コメント欄の内部では、次の順を推奨する。

```text
見出し・説明
ログイン/本人申請状態メッセージ
投稿フォームまたはACCOUNTログイン案内
申請中/承認済み人数カード
既存コメント一覧
人数注記
```

フォームは既存コメント一覧の上に置く。未ログイン時はフォームを出さず、`ACCOUNT` / `mypage.html` への短い案内を出す。ログイン済みかつ投稿可能な状態だけフォームを出す。

`assets/css/style.css` には旧モック由来の `.session-comment-form-mock`、`.session-comment-field`、`.session-comment-textarea`、`.session-application-button` が残っているため、M-11B実装時は既存スタイルを再利用しつつ、読み取り専用モック名は必要に応じて本番フォーム名へ整理する。

## 7. ログイン状態取得方針

`session-detail.html` は既に `assets/js/supabaseRuntimeConfig.js` を読み、`sessionDetailApplicationComments.js` でSupabase SDKを遅延読み込みしている。

M-11Bでは、初期表示時に以下を行う。

1. `supabase.auth.getSession()` で現在のセッションを確認する。
2. セッションがあればログイン済みとして扱う。
3. 画面にはemail、user_id全文、tokenを出さない。
4. 表示名を出す場合は `public_profiles.display_name` だけを使う。
5. `onAuthStateChange` は任意。`session-detail.html` 内にログインフォームを置かないなら、初期 `getSession()` とページ再表示で十分。別タブログイン後の即時反映を狙う場合だけ購読して、フォーム状態を再描画する。

未ログイン時の文言案:

```text
参加希望コメントの投稿にはログインが必要です。ACCOUNTからログインしてください。
```

ログイン済み時の文言案:

```text
参加希望コメントは公開申請欄に表示されます。個人情報や公開したくない内容は含めないでください。
```

## 8. 投稿バリデーション

フロント側で先に止める項目:

- trim後空文字は禁止。
- 最大4000文字。DB制約とRPC検証に合わせる。
- 前後空白はtrimして送信する。
- 改行は許可する。表示側は既存通り `textContent` と `white-space: pre-wrap` で扱う。
- HTMLやURLはプレーンテキストとして保存・表示する。リンク化しない。
- コメント本文を `innerHTML` に入れない。既存の `textContent` 方針を維持する。
- 送信中はボタンとtextareaをdisabledにし、二重押しを防ぐ。

表示するメッセージは短く安全にする。Supabaseの詳細、内部ID、Project URL、key、token、email、user_id全文は出さない。

## 9. 投稿後再取得フロー

投稿成功時:

1. RPC戻り値のuuidは内部処理でも原則使わず、画面表示しない。
2. コメント一覧を `get_public_session_comments(target_session_id)` で再取得する。
3. 申請人数を `get_public_session_application_counts(target_session_id)` で再取得する。
4. 本人申請状態を `session_applications` の本人行SELECTで再取得する。
5. textareaをクリアする。
6. 成功メッセージを出す。

ローカルで楽観的にコメントを追加しない。RPC再取得だけで画面を更新すれば、重複表示を避けられる。

`mypage.html` への反映は、次回表示または再読み込み時でよい。M-11Bではmypage側の即時同期やイベント通知は扱わない。

## 10. 重複投稿 / 既存申請の扱い

M-11Bでの推奨UI:

| 本人申請状態 | M-11Bの扱い |
| --- | --- |
| 申請なし | フォーム表示。投稿成功で `pending` になる |
| `pending` | 申請済み表示を出しつつ、追加コメント投稿は許可する。人数は増えないと明示する |
| `waitlisted` | キャンセル待ち表示を出しつつ、追加コメント投稿は許可する |
| `accepted` | 参加確定表示を出しつつ、補足コメント投稿は許可する |
| `canceled` | 再申請としてフォーム表示。RPC成功で `pending` に戻る |
| `rejected` | M-11Bではフォームを出さず、再申請可否は別工程判断とする |

理由:

- RPCは `rejected` 既存申請でもコメントを追加できるが、申請状態を `pending` に戻さない。
- そのため、M-11Bで `rejected` にフォームを出すと「再申請できた」と誤解される。
- 再申請ポリシーはGM運用と結びつくため、M-11C以降で別途設計する。

技術的には、自分の申請状態取得なしでも投稿RPCは成立する。ただし、既存申請済み表示、`rejected` の誤解防止、`canceled` の再申請表示には本人状態が必要になるため、M-11B-1で最小列の本人申請状態取得を入れるのが安全。

## 11. 募集状態 / 締切 / 終了状態

フロント側の投稿フォーム表示条件:

- `data/sessions.json` の `status` が `recruiting` または `tentative`
- `visibility` が `public`
- ログイン済み
- 本人申請状態が `rejected` 以外

DB側の最終判定:

- `can_apply_to_session(target_session_id)` が `visibility = 'public'` かつ `status in ('tentative', 'recruiting')` だけを許可する。

`data/sessions.json` とDB側statusに差がある場合は、DB側RPCの判定を正とする。フロントで投稿可能表示だったとしてもRPCが拒否したら、安全な募集終了メッセージを出して再読み込みを促す。

締切時間は現状使わない。`startTime` / `endTime` は開催時刻であり、申請締切として流用しない。将来 `applicationDeadline` / `deadlineTime` などの明示フィールドを追加してから扱う。

## 12. エラー処理方針

| ケース | 画面メッセージ案 |
| --- | --- |
| 未ログイン | 投稿にはログインが必要です。 |
| RPC失敗 | 投稿できませんでした。状態を再読み込みしてから再度お試しください。 |
| RLS拒否 / 権限なし | この操作を行う権限がありません。 |
| 対象セッションなし | 対象のセッションを確認できませんでした。 |
| 募集終了 / 満席 / 終了 / 中止 | このセッションは現在申請できません。 |
| 重複または競合 | 申請状態を再読み込みしました。内容を確認して再度お試しください。 |
| ネットワーク失敗 | 通信に失敗しました。時間を置いて再度お試しください。 |
| 想定外エラー | 投稿できませんでした。時間を置いて再度お試しください。 |

consoleに出す場合も、raw error全文ではなく `code` / `name` / `status` 程度へ絞る。URL、key、token、email、user_id全文、内部IDは出さない。

## 13. 表示してよい情報 / 表示しない情報

表示してよい情報:

- `display_name`
- コメント本文
- コメント作成日時
- コメント編集日時または更新日時
- 申請ステータス
- 投稿成功/失敗メッセージ

表示しない情報:

- email
- user_id全文
- token
- Project URL
- key
- gmUserId
- secret類
- `comment_id`
- `application_id`
- その他内部ID類

内部IDはRPC引数やリンク生成に必要な場合のみ内部処理で使い、画面文言、console、docsへ出さない。

## 14. RLS smoke test更新案

既存スクリプトには、anon投稿不可、authenticated投稿可、同一ユーザー複数コメントでapplication重複なし、closed/full/finished/canceled/private/hidden投稿不可、本人申請行SELECT、公開RPCの内部情報非露出が含まれている。

M-11B実装時に追加または強化する候補:

- `create_application_comment` 成功後、公開コメントRPCに本文が出る。
- 成功後、本人の `session_applications` が1件だけ見える。
- 同一 `session_id + user_id` で2回投稿しても `session_applications` が1件のまま。
- 2回目投稿前後で人数が二重加算されない。
- 空コメントと4000文字超コメントが拒否される。
- 存在しないsessionへの投稿が拒否される。
- `canceled` 既存申請への投稿で `pending` に戻ることを、専用fixtureで確認する。
- `rejected` 既存申請への投稿で状態が戻らないことを、専用fixtureまたはM-11C以降で確認する。
- 公開RPC、本人申請SELECT、console出力にemail / user_id / token / secret類が出ない。

今回はテスト実装・実行はしない。状態変更が重いケースは専用fixtureを用意し、既存の重要データを壊さない形で進める。

## 15. M-11B実装段階案

M-11Bは書き込みを含むため、さらに小さく分けるのが安全。

| 段階 | 内容 | DB変更 |
| --- | --- | --- |
| M-11B-1 | ログイン状態取得、本人申請状態取得、フォーム/ログイン案内/申請済み表示の出し分け。RPC投稿はまだ呼ばない | なし |
| M-11B-2 | バリデーション、二重押し防止、`create_application_comment` 呼び出し、短い成功/失敗表示 | 投稿時のみあり |
| M-11B-3 | 投稿成功後のコメント一覧、人数、本人申請状態の再取得。楽観表示なし | 投稿時のみあり |
| M-11B-4 | RLS smoke test観点の追加・強化案をスクリプトへ反映するか判断 | テスト実行時のみ |

1回のM-11B実装でもコード量は大きくないが、`rejected` / `canceled` の扱いと本人申請状態表示が絡むため、まずB-1で表示制御だけを固めてから投稿呼び出しへ進む方が安全。

## 16. M-11B実装の停止条件

以下のどれかに当てはまる場合は、実装へ進まず設計へ戻る。

- `create_application_comment` の定義が現行調査結果と違う。
- `session_applications` の本人SELECTで、本人以外の行や内部情報が見える。
- `get_public_session_comments` がemail、user_id、Discord ID、role、secret類を返す。
- `get_public_session_application_counts` がprivate / hidden sessionの人数を返す。
- `rejected` 既存申請を再申請扱いにしたいが、RPCが `pending` に戻せないまま。
- 申請締切を扱う必要が出たが、明示締切フィールドがない。
- Project URL / key / token / user_id全文 / email を画面やconsoleへ出す必要が出る。
- SQL Editor実行やDBスキーマ変更が必要になる。

## 17. まだやらないこと

- 本番フロント実装
- コメント投稿フォーム実装
- `create_application_comment` の実呼び出し
- 投稿実行テスト
- SQL Editor実行
- DBデータ変更
- cleanup SQL実行
- GM承認・却下UI実装
- コメント編集・削除UI実装
- `close_session` 呼び出し
- `updates.json` 変更
- secret類の出力
- commit / push

