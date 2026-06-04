# M-14E-3 Discord同期Edge Function 入出力・dry-run仕様整理

## 目的

Discord同期Edge Functionは、依頼書DBを正本とし、Discord投稿を同期先として扱うためのサーバ側処理である。

目的:

- `create` / `update` / `close` / `delete` / `resync` を安全に処理する。
- Discord送信失敗時も依頼書保存自体は成功扱いにする。
- 失敗時は `failed` と一般化した短いエラー要約を記録し、再同期可能にする。
- フロントからDiscordへ直接送らず、秘匿値をフロント、docs、DB、GitHub、チャットに置かない。
- 実送信前にdry-runで本文・状態更新予定・権限判定を確認できるようにする。

今回は仕様整理のみで、SQL作成、SQL Editor実行、DB/RPC変更、Edge Function実装、deploy、Discord実送信、フロント実装は行わない。

## 想定名称

候補:

| 候補名 | 評価 |
| --- | --- |
| `sync-session-post-to-discord` | 依頼書をDiscordへ同期する目的が明確。少し長いが運用時に分かりやすい。 |
| `discord-session-sync` | 短く扱いやすい。対象が依頼書投稿であることはやや伝わりにくい。 |

初期推奨は `sync-session-post-to-discord`。既存の関数命名規則とデプロイ手順を確認してから最終決定する。

## 入力payload案

最小入力:

```json
{
  "session_id": "public-session-id",
  "action": "create",
  "dry_run": true
}
```

任意入力候補:

```json
{
  "request_source": "gm"
}
```

入力方針:

- `session_id` は公開依頼書IDを想定する。
- `action` は `create` / `update` / `close` / `delete` / `resync` のみ許可する。
- `dry_run` は明示的な真偽値にする。初期QAでは `true` を優先する。
- `request_source` は表示・監査用の補助値候補。権限判定の根拠にはしない。
- 認証系の生値、ユーザー内部識別子、PC選択や申請関連の内部キーはフロントから渡さない。
- 権限判定はEdge Function側、またはレビュー済みRPC側で、認証済みセッションと既存helperを使って行う。

## action別挙動

### create

目的:

- 公開対象の依頼書をDiscordへ新規投稿する。

前提:

- 対象依頼書がSupabase由来である。
- 同期対象判定を通過する。
- 既存投稿識別子がない、または新規投稿として扱うべき状態である。

成功時の状態更新候補:

- `discord_sync_status = posted`
- `discord_last_action = create`
- `discord_sync_requested_at` を要求時刻として記録
- `discord_synced_at` を同期完了時刻として記録
- `discord_sync_error` をクリア
- `discord_message_id` 相当列、投稿先、投稿URL相当列を保存

dry-run時:

- 実送信しない。
- 生成予定本文、同期対象判定、状態更新予定を返す。
- 投稿識別子は生成しない。

### update

目的:

- 既存Discord投稿を現在の依頼書内容へ更新する。

前提:

- `discord_message_id` 相当列が存在し、対象行に値がある。
- 値がない場合は、誤って新規投稿を増やさず、`failed` または手動確認扱いにする。

成功時の状態更新候補:

- `discord_sync_status = posted`
- `discord_last_action = update`
- `discord_synced_at` を更新
- `discord_sync_error` をクリア
- 投稿URLなどが変わる場合は保存値を更新

### close

目的:

- 募集終了・開催終了としてDiscord投稿を更新する。

方針:

- 削除ではなく終了表示寄せを第一候補にする。
- Discord側にも履歴やリンクを残し、現在状態が分かる本文へ更新する。
- `closed` / `finished` などの募集状態に応じたラベルを本文へ反映する。

成功時の状態更新候補:

- `discord_sync_status = posted`
- `discord_last_action = close`
- `discord_synced_at` を更新
- `discord_sync_error` をクリア

### delete

目的:

- Discord投稿を削除、または削除相当表示へ更新する。

比較:

| 方針 | 利点 | 懸念 |
| --- | --- | --- |
| Discord投稿を削除 | 外部表示から依頼書を消せる | 監査性が下がる。失敗時に再確認しにくい。 |
| 削除相当表示へ更新 | 履歴とリンクを残せる | 外部投稿が残るため、削除の期待と差が出る可能性がある。 |

初期推奨:

- 完全削除前に、削除相当表示へ更新する方針を第一候補にする。
- 実際に物理削除するかどうかは運用方針確認後に決める。

重要な懸念:

- `delete_session_post(text)` はDB本体を完全削除する。
- DB削除後は外部投稿識別子を参照できなくなる可能性がある。
- そのため、Discord側のdelete/削除相当処理はDB完全削除前に行う案を優先して検討する。
- 既存削除RPC側に同期要求をどう組み込むかは後続設計とする。

### resync

目的:

- `failed` 状態や手動再同期時に、現在のDB内容から再送信・再更新する。

前提:

- M-14E-2時点でresync専用public関数は未作成。
- GM/admin向け再同期ボタンを作る場合は、Edge Functionを直接呼ぶか、同期要求用RPCを作るかを後続で比較する。

挙動案:

- 外部投稿識別子があれば `update` 相当で再同期する。
- 外部投稿識別子がなく、公開対象なら `create` 相当を許可するかを検討する。
- 非公開・下書き・中止など同期対象外なら `skipped` または一般化メッセージを返す。

## dry-run方針

dry-runは、Discord実送信を行わず、同期予定内容だけを確認するモードである。

用途:

- 初期QAでの安全確認。
- 投稿本文プレビュー。
- action判定と同期対象判定の確認。
- 状態更新予定の確認。
- ログ安全性と戻り値安全性の確認。

dry-runで返す候補:

- `ok`
- `action`
- `dry_run`
- `sync_status`
- `would_send`
- `would_update_columns`
- `message_preview`
- `public_message_url` の予定または既存値
- 一般化された注意メッセージ

dry-runで返さないもの:

- 秘匿値
- 認証系の生値
- ユーザー内部識別子
- PC選択や申請関連の内部キー
- 外部サービス応答の生全文

dry-runでは、外部投稿credentialが未設定でも本文生成と状態更新予定を確認できる設計を優先する。

## Discord投稿本文の方針

初期実装では固定フォーマットを第一候補にする。

理由:

- M-15テンプレート機能との接続は選択UI・利用文脈・権限が増える。
- まずは同期処理、状態更新、dry-run、安全なログ出力を安定させる。
- 投稿本文の差し替えは後続でも可能。

本文候補:

```text
【依頼書】{title}

日時: {date} {start_time} - {end_time_or_end_at}
募集状態: {status_label}
申請締切: {application_deadline}
人数: {player_min} - {player_max}

概要:
{summary}

詳細:
{session_detail_url}
```

含めないもの:

- 秘匿値
- 内部識別子の実値
- 認証系の生値
- GM/admin向け承認済み参加者連絡先
- Discord mentionを使った参加者呼び出し情報

M-15テンプレート機能との接続は後続候補にする。必要になった場合は、投稿文脈専用の種別または利用文脈を追加するかを先に整理する。

## 状態更新方針

使用候補列:

- `discord_sync_status`
- `discord_last_action`
- `discord_sync_requested_at`
- `discord_synced_at`
- `discord_sync_error`
- `discord_message_id`
- `discord_channel_id`
- `discord_thread_id`
- `discord_post_url`

要求時:

- `discord_sync_requested_at` を要求時刻として記録する候補。
- `discord_last_action` は今回actionへ更新する候補。
- dry-runではDB更新しない案を第一候補にする。

成功時:

- `discord_sync_status = posted`
- `discord_last_action` を今回actionへ更新
- `discord_synced_at` を更新
- `discord_sync_error` をクリア
- 必要に応じて外部投稿識別子、投稿先、投稿URLを保存

失敗時:

- `discord_sync_status = failed`
- `discord_last_action` は今回actionへ更新する案を第一候補にする
- `discord_sync_error` に一般化した短い要約を保存
- `discord_synced_at` は更新しない
- 秘匿値や外部サービス応答の生全文はDBへ保存しない

skipped:

- 下書き、非公開、内部向け、静的JSON由来など、同期対象外の状態に使う候補。
- `discord_last_action` を更新するかは実装時に決める。
- dry-runでは「送信対象外」として返す。

## 同期対象判定

同期対象候補:

- `visibility = public`
- `status` が `recruiting` / `full` / `closed` / `finished` など、外部表示してよい状態
- Supabase由来の依頼書

同期対象外候補:

- `draft`
- `hidden`
- `private`
- `canceled`
- 静的JSON由来
- 対象依頼書が見つからない場合

public draft guard:

- M-14E-2 preflightではDB制約としては見つからなかった。
- 既存のRPC/UI側ガードを維持し、Edge Function側でも安全側に判定する。
- `draft` かつ `public` のような矛盾状態は送信しない。

## 権限判定

基本方針:

- 未ログインは拒否する。
- 通常PLは同期要求不可。
- 作成者GMは自分のSupabase由来依頼書だけ同期可能。
- adminはアプリ内権限として横断管理できる候補。
- 他GMは対象外。

確認方法:

- Edge Function側で認証済みセッションを検証する。
- 既存helperまたはレビュー済みRPCでGM/admin判定を行う。
- フロントから権限根拠を渡さない。
- `request_source` は補助値であり、権限判定には使わない。

サーバ側DB更新権限:

- Edge Function内部でDB更新に必要な権限の扱いは、実装前に慎重に設計する。
- アプリ内admin権限とサーバ側の高権限は別物として扱う。
- 可能なら、状態更新専用のレビュー済みRPCを使う案と、Edge Function内で安全に更新する案を比較する。

## 秘匿値管理

- 外部投稿credentialやサーバ側の高権限値の実値は、フロント、docs、DB、GitHub、チャットに書かない。
- 実値はEdge Function側の管理設定で扱う。
- DBへ外部投稿credentialを保存しない。
- ローカルと本番で設定項目を分ける場合も、docsには目的と一般名だけを書く。
- dry-runでは外部APIを呼ばず、秘匿値なしでも本文生成確認ができる設計を優先する。

一般化した設定項目名候補:

- `DISCORD_POST_ENDPOINT`
- `DISCORD_POST_CREDENTIAL`
- `SUPABASE_INTERNAL_ACCESS`

上記は名称候補のみであり、実値は記録しない。

## ログ安全性

- Edge Function logsに秘匿値を出さない。
- 外部サービス応答の生全文をログ出力しない。
- 認証系の生値や内部識別子の実値をログ出力しない。
- ユーザー向けエラーは一般化する。
- DBの `discord_sync_error` も短い一般化要約にする。
- debugログはdry-run時でも本文プレビューと状態判定程度に限定する。

## 戻り値案

成功時:

```json
{
  "ok": true,
  "action": "update",
  "dry_run": false,
  "sync_status": "posted",
  "public_message_url": "https://example.invalid/public-message",
  "message": "Discord同期が完了しました。"
}
```

dry-run成功時:

```json
{
  "ok": true,
  "action": "create",
  "dry_run": true,
  "sync_status": "pending",
  "would_send": true,
  "message_preview": "公開情報だけで構成した投稿本文プレビュー",
  "would_update_columns": [
    "discord_sync_status",
    "discord_last_action",
    "discord_sync_requested_at"
  ]
}
```

失敗時:

```json
{
  "ok": false,
  "action": "update",
  "dry_run": false,
  "error_code": "sync_failed",
  "message": "Discord同期に失敗しました。時間をおいて再試行してください。"
}
```

戻り値に含めないもの:

- 秘匿値
- 認証系の生値
- ユーザー内部識別子
- PC選択や申請関連の内部キー
- 外部投稿識別子そのもの
- 外部サービス応答の生全文

`public_message_url` を返す場合は、公開して問題ないURLだけに限定する。

## エラーコード案

| error_code | 用途 |
| --- | --- |
| `login_required` | 未ログイン |
| `not_allowed` | 権限不足 |
| `session_not_found` | 対象依頼書なし |
| `not_sync_target` | 同期対象外 |
| `missing_post_reference` | 既存投稿識別子不足 |
| `sync_failed` | 外部投稿失敗 |
| `invalid_action` | 未対応action |
| `invalid_payload` | payload不正 |

いずれも一般化した日本語メッセージへ変換する。内部詳細は返さない。

## 後続工程案

1. M-14E-3: 入出力・dry-run仕様整理。
2. M-14E-4: Edge Function draft実装。
3. M-14E-5: Edge Function側の管理設定手順docs整理。
4. M-14E-6: dry-runローカル / 手動確認。
5. M-14E-7: deploy手順整理。
6. M-14E-8: deploy実施判断。
7. M-14E-9: GM/admin向け再同期UI。
8. M-14E-10: Discord実送信QA。

## 懸念点

- `delete_session_post(text)` の完全削除前にDiscord側delete/削除相当処理をどう呼ぶか。
- DB削除後に外部投稿識別子を参照できなくなる問題。
- 削除前同期、または削除RPC側で同期要求をどう扱うか。
- Edge FunctionのDB更新権限をどう安全に扱うか。
- resync専用RPCが未作成であること。
- GM/admin再同期UIの呼び出し先をEdge Function直呼びにするか、同期要求RPC経由にするか。
- M-15テンプレート機能との接続時期。
- dry-runと実送信の戻り値差分を小さく保てるか。
- 失敗時のエラー要約が短く一般化されているか。

## やらないこと

- SQLファイル作成
- SQL Editor実行
- DB構造変更
- RPC変更
- Edge Functionコード作成
- Edge Function deploy
- Discord実送信
- フロント実装
- `updates.json` 変更
- commit / push

## M-14E-4 draft実装結果

`supabase/functions/sync-session-post-to-discord/index.ts` に、Discord同期Edge Functionのdraftを追加した。

実装した範囲:

- `POST` / `OPTIONS` のみを受け付ける。
- 入力は `session_id` / `action` / `dry_run` / 任意の `request_source` に限定する。
- `action` は `create` / `update` / `close` / `delete` / `resync` のみ許可する。
- `dry_run` は未指定時も安全側で `true` とみなす。
- `dry_run = false` は `real_send_not_enabled` として明示的に拒否する。
- 認証ヘッダーがない場合は拒否する。
- 既存helper `is_admin()` / `is_session_gm(target_session_id)` により、作成者GMまたはアプリ内adminだけを許可する。
- `public.sessions` から公開投稿本文に必要な依頼書情報と同期状態列だけを取得する。
- `visibility = public` かつ `status = tentative / recruiting / full / closed / finished` を同期対象候補にする。
- `draft` / `private` / `hidden` / `canceled` は同期対象外として扱う。
- `update` / `close` / `delete` は既存投稿参照情報がない場合に拒否する。
- `resync` は既存投稿参照情報があれば `update` 相当、なければ `create` 相当のpreviewとして扱う。
- 投稿本文preview、同期対象判定、状態更新予定、警告だけを返す。
- dry-runではDB更新も外部送信も行わない。

返す情報:

- `ok`
- `dry_run`
- `action`
- `sync_target`
- `message_preview`
- `planned_db_update`
- `warnings`

返さない情報:

- 秘匿値の実値
- 認証系の生値
- ユーザー内部識別子
- 参加申請やPC選択関連の内部キー
- 外部投稿参照情報そのもの
- 外部サービス応答の生全文

未実装として残した範囲:

- 外部投稿APIの呼び出し。
- `dry_run = false` の実送信処理。
- 同期成功 / 失敗時のDB状態更新。
- 外部投稿参照情報の保存更新。
- retry / mock / deploy手順。
- GM/admin向け再同期UI。
- M-15テンプレート機能との本文連携。

権限方針:

- draftでは呼び出しユーザーの認証文脈で既存helperを呼び、作成者GMまたはアプリ内adminだけに限定する。
- アプリ内admin権限とサーバ側高権限credentialは別物として扱う。
- 将来DB状態更新が必要になった場合も、レビュー済みRPC経由案と安全なサーバ側更新案を比較してから進める。

この工程ではSQL Editor実行、DB/RPC変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-5 secret管理・dry-run確認手順

Edge Function draftをdeploy前に安全確認するための手順を `docs/discord-edge-function-secret-plan.md` に分離した。

整理内容:

- Edge Function側secret管理の方針。
- 初期dry-runに必要な設定候補と、実送信時まで不要な設定候補の切り分け。
- `dry_run = true` のpayload例。
- `dry_run = false` が `real_send_not_enabled` で拒否されることの確認手順。
- `create` / `update` / `close` / `delete` / `resync` のaction別dry-run確認観点。
- deploy前チェックリスト。
- CORS、認証、GM/admin限定、通常PL拒否の確認観点。

この工程ではEdge Functionコード変更、SQL Editor実行、DB/RPC変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6D dry-run実行確認方法

dry-run実行確認では、`dry_run = true` のpayloadで、Edge Functionが投稿本文preview、同期対象判定、状態更新予定、警告だけを返すことを確認する。

推奨する確認順:

1. 事前安全検索で `fetch(`、DB書き込み系メソッド、`console.` が増えていないことを確認する。
2. Supabase CLIのローカルserve利用可否を確認する。
3. ローカルserveが使える場合、ダミーではないがdocsへ実値を書かない対象依頼書ID相当の値と認証文脈を作業者環境だけで扱い、`dry_run = true` を呼ぶ。
4. `create` / `update` / `close` / `delete` / `resync` のpreview、同期対象外、既存投稿参照情報不足、権限拒否を確認する。
5. レスポンスとログに秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものが出ないことを確認する。

`dry_run = false` は今回実行しない。将来確認する場合も、draft段階では `real_send_not_enabled` で拒否され、Discord API呼び出しとDB更新が発生しないことを確認する。

Deno単体起動は、Supabase Edge Functionの実行構造との差異が出る可能性があるため第二候補とする。deploy後dry-run限定確認は、本番に近い確認ができる一方で、deploy前確認を飛ばさない前提にする。

この追記ではdocs整理のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6F ローカルserve dry-run確認準備

Supabase CLIはPowerShellの `npx` では実行ポリシーにより止まるが、`npx.cmd supabase --version` では `2.105.0` を確認できた。ローカルserve確認では、PowerShell上は `npx.cmd` 経由を候補にする。

実行前候補:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

この候補はまだ実行しない。実行前に、対象依頼書ID相当の値、認証文脈、Edge Function用環境変数をユーザー手元で準備し、実値をdocsへ残さないことを確認する。

dry-run確認では `dry_run = true` のみを扱う。`dry_run = false` は実行せず、Discord実送信なし、DB更新なし、レスポンスとログの安全性を重点確認する。

この追記ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6G ローカルserve dry-run実行可否

`npx.cmd supabase --version` は `2.105.0`、Deno構文確認はユーザー領域のDeno実行ファイルをフルパス実行して成功した。

Edge Functionが参照する環境変数は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。この作業環境ではいずれも未設定で、認証文脈も未用意だった。

そのため、`npx.cmd supabase functions serve sync-session-post-to-discord` は実行していない。ローカルserveを起動していないため、`dry_run = true` の実レスポンス確認も未実行。

安全検索では `fetch(`、DB書き込み系メソッド、`console.` は0件。Discord実送信なし、DB更新なし、`dry_run = false` 実行なしの方針を維持する。

次工程では、ユーザー手元で必要な環境変数と認証文脈を安全に用意したうえで、`dry_run = true` だけを確認する。

この追記ではdocs整理のみ行い、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6I ローカルdry-run手元実行ガイド

手元実行では、PowerShell上で環境変数とAuthorizationヘッダーを用意し、ローカルserveへ `dry_run = true` のpayloadを送る。docsに残す手順はプレースホルダーのみとし、実値は書かない。

初回の確認対象は `create` のみにする。`update` / `close` / `delete` / `resync` は既存投稿参照情報や依頼書状態に依存するため、後続工程で必要に応じて扱う。

期待結果は、成功してpreviewが返る、権限不足、同期対象外、対象なし等の一般化結果。`message_preview` は公開情報のみ、`planned_db_update` は予定情報のみで、実DB更新は行わない。

結果記録テンプレートは `docs/discord-edge-function-dry-run-check-result.md` に置いた。記録時は、秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものを含めない。

この追記ではdocs整理のみ行い、ローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-6H dry-run実行可否と停止判断

`npx.cmd supabase --version` は `2.105.0`。Deno構文確認はユーザー領域のDeno実行ファイルをフルパス実行して成功した。

Edge Functionは `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL` を参照し、呼び出し時にはBearer形式のAuthorizationヘッダーを要求する。

今回の作業環境では環境変数が未設定で、認証文脈も未用意だったため、`npx.cmd supabase functions serve sync-session-post-to-discord` は実行していない。ローカルserve未起動のため、`dry_run = true` の実レスポンス確認も未実行。

安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。

次工程では、ユーザー手元で必要な環境変数と認証文脈を用意し、`dry_run = true` のみを確認する。`dry_run = false` は実行しない。

この追記ではdocs整理のみ行い、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。
