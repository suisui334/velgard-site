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

## M-14E-8 deploy前IOレビューとdeploy後dry-run確認

deploy対象は `sync-session-post-to-discord`、対象ファイルは `supabase/functions/sync-session-post-to-discord/index.ts`。現状はdry-run preview専用draftで、`dry_run = true` はpreviewのみ、`dry_run = false` は `real_send_not_enabled` で拒否する。

deploy前IOレビュー:

- Discord API送信処理は未接続。
- DB書き込み処理は未接続。
- `fetch(`、DB書き込み系メソッド、`console.` は0件を維持する。
- レスポンスに秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものを含めない。
- Function名と対象パスを明確にしたうえで、ユーザー確認なしにdeployしない。

deployコマンド候補:

```powershell
npx.cmd supabase functions deploy sync-session-post-to-discord
```

このコマンドは候補として整理するだけで、M-14E-8では実行しない。deploy後確認を行う場合は、最初に `create` / `dry_run = true` のみを確認し、`message_preview`、`planned_db_update`、Discord実送信なし、DB更新なし、レスポンスとログの安全性を一般化して記録する。`dry_run = false` はまだ実行しない。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-11 deploy結果と次のIO確認

ユーザー手元で `sync-session-post-to-discord` のdeployは成功した。Docker未起動に関するWARNINGは表示されたが、Supabaseプロジェクトへのアップロード・deploy自体は完了した。

deploy後に `supabase/.temp/` がCLI生成物として未追跡生成されたが、ユーザーが削除済み。削除後の作業ツリーはclean。

IO観点の現在地:

- Edge Functionはdeploy済み。
- `dry_run = true` は未実行。
- `dry_run = false` は未実行。
- Discord実送信なし。
- DB更新なし。
- フロント接続なし。

次工程では、`create` / `dry_run = true` のみを確認する。レスポンスでは `message_preview` と `planned_db_update` の有無、Discord実送信なし、DB更新なし、レスポンスとログの安全性を確認する。実値はユーザー手元だけで扱い、結果は一般化して記録する。

この追記ではdocs記録のみ行い、Codex側でEdge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-12B dry-run 500エラーのIO修正

`create` / `dry_run = true` でHTTP 500が発生した原因は、Supabase clientのRPCメソッドを分離して呼んだことによるmethod binding不具合として整理する。外部送信やDB更新の問題ではない。

IO上の修正方針:

- RPC呼び出しはclient本体の `client.rpc(...)` として呼ぶ。
- `is_session_gm` 用の型緩和はhelper内に限定する。
- `dry_run = true` preview専用の入出力は維持する。
- `dry_run = false` は引き続き拒否する。
- Discord API送信処理、DB書き込み処理、console出力は追加しない。

この追記ではdocs記録のみ行い、SQL Editor実行、DB/RPC変更、Discord実送信、`dry_run = false` 実行、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-12D 修正版deploy後dry-run成功時のIO結果

RPC method binding修正後の再deployにより、`create` / `dry_run = true` はHTTP 200で成功した。レスポンスには `ok`、`dry_run`、`action`、`sync_target`、`message_preview`、`planned_db_update`、`warnings` が含まれた。

IO上の確認:

- `message_preview` は返却あり。ただし本文全文は記録しない。
- `planned_db_update` は返却あり。ただしdry-run上の予定情報であり、実DB更新は行わない設計。
- Discord実送信なし。
- `dry_run = false` 未実行。
- DB更新なし。
- フロント接続なし。

次工程では、`dry_run = false` が拒否されることを別工程で確認するか、Discord実送信実装前の安全レビューへ進む。実送信やDB更新はまだ行わない。

この追記ではdocs記録のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-13 dry_run=false拒否確認のIO観点

`dry_run = false` 拒否確認は、実送信を有効化しない状態で拒否ガードだけを確認する工程として扱う。この工程では実行しない。

IO確認観点:

- 入力payloadは `action = create` / `dry_run = false` に限定する。
- 確認対象依頼書ID相当の値とAuthorization Bearerはユーザー手元だけで扱う。
- 期待結果は、`real_send_not_enabled` または同等理由での拒否。
- Discord投稿が作成されない。
- DB同期状態列が変更されない。
- レスポンスとFunction Logsに秘匿値の実値、認証系の生値、内部識別子を出さない。

記録対象はHTTP status、response keys、error codeまたは一般化した拒否理由、Discord投稿なし確認、DB更新なし確認に絞る。レスポンス本文全文やURL実値、`message_preview` 本文全文は記録しない。

`dry_run = false` が成功送信扱いになった場合は即停止し、以後再実行しない。Discord実送信実装やDB更新処理の追加へはまだ進まない。

この追記では手順整理のみ行い、`dry_run = false` 実行、Discord実送信、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-10 deploy直前IO最終確認

最終確認では、`sync-session-post-to-discord` がdry-run preview専用draftのままであることを確認した。Deno構文確認は成功し、Supabase CLIは `npx.cmd` 経由で利用可能。`fetch(`、DB書き込み系メソッド、`console.` は0件で、Discord API送信処理とDB書き込み処理は未接続のまま。

deploy候補コマンドは以下だが、Codex側では実行しない。

```powershell
npx.cmd supabase functions deploy sync-session-post-to-discord
```

deploy後の初回IO確認は `create` / `dry_run = true` のみに絞る。確認項目は、Function到達、`message_preview` と `planned_db_update` の有無、Discord実送信なし、DB更新なし、レスポンスとログの安全性。実値はユーザー手元だけで扱い、結果は一般化して記録する。

`dry_run = false` はまだ実行しない。将来確認する場合も、実送信コード追加前の拒否確認として別工程に分ける。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-9 deploy直前IO判断

deploy直前のIO観点では、dry-run専用draftが外部送信にもDB書き込みにも進まないことを再確認する。

確認済み:

- Deno構文確認は成功。
- Supabase CLIは `npx.cmd` 経由で利用可能。
- `fetch(` は0件。
- DB書き込み系メソッドは0件。
- `console.` は0件。
- `deno.lock` はなし。
- `updates.json` 差分なし。

deploy後の初回確認は `create` / `dry_run = true` のみ。レスポンスは `message_preview` と `planned_db_update` の有無、Discord実送信なし、DB更新なし、レスポンスとログの安全性を確認する。実値はユーザー手元だけで扱い、記録は一般化する。

`dry_run = false` はまだ実行しない。将来確認する場合でも、`real_send_not_enabled` の拒否確認として別工程に分ける。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6I ローカルdry-run手元実行ガイド

手元実行では、PowerShell上で環境変数とAuthorizationヘッダーを用意し、ローカルserveへ `dry_run = true` のpayloadを送る。docsに残す手順はプレースホルダーのみとし、実値は書かない。

初回の確認対象は `create` のみにする。`update` / `close` / `delete` / `resync` は既存投稿参照情報や依頼書状態に依存するため、後続工程で必要に応じて扱う。

期待結果は、成功してpreviewが返る、権限不足、同期対象外、対象なし等の一般化結果。`message_preview` は公開情報のみ、`planned_db_update` は予定情報のみで、実DB更新は行わない。

結果記録テンプレートは `docs/discord-edge-function-dry-run-check-result.md` に置いた。記録時は、秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものを含めない。

この追記ではdocs整理のみ行い、ローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-6J ローカルserve不可結果

ユーザー手元で `npx.cmd supabase functions serve sync-session-post-to-discord` を試したが、Docker Desktop / Docker daemonへ接続できず失敗した。`docker --version` もPowerShellで認識されなかったため、Docker CLI / Docker Desktopが未導入、またはPATH上で利用不可と判断する。

このため、Edge Functionのローカルserveは未実行扱い。ローカルserveが起動していないため、`dry_run = true` の実レスポンス確認も未実行。`dry_run = false` は実行していない。

IO確認の次工程候補:

- Docker Desktopを導入してローカルserve dry-run確認へ進む。
- Docker導入を保留し、deploy前手順整理と安全レビューへ進む。
- deploy後確認を選ぶ場合でも、まず `dry_run = true` 限定確認から始める。

この追記ではdocs記録のみ行い、Docker Desktop導入、Supabase CLI追加導入、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-7 deploy前安全レビュー・deploy後dry-run確認

ローカルserveがDocker未導入により不可のため、deploy後に `dry_run = true` だけを確認する場合のIO観点を整理する。この工程ではdeployしない。

deploy前IOチェック:

- `dry_run = false` は `real_send_not_enabled` で拒否する。
- Discord API送信処理は未接続。
- DB書き込み処理は未接続。
- `fetch(`、DB書き込み系メソッド、`console.` が増えていない。
- レスポンスに秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものを含めない。
- CORS方針をdry-run確認用として扱い、実運用前に再レビューする。

deploy後dry-run確認は `create` / `dry_run = true` から始める。確認するのは、`message_preview`、`planned_db_update`、Discord実送信なし、DB更新なし、レスポンスとログの安全性。実値はユーザー手元だけで扱い、結果は一般化して記録する。

`dry_run = false` はまだ実行しない。Discord実送信コードを追加するまでは実送信へ進まない。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6H dry-run実行可否と停止判断

`npx.cmd supabase --version` は `2.105.0`。Deno構文確認はユーザー領域のDeno実行ファイルをフルパス実行して成功した。

Edge Functionは `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL` を参照し、呼び出し時にはBearer形式のAuthorizationヘッダーを要求する。

今回の作業環境では環境変数が未設定で、認証文脈も未用意だったため、`npx.cmd supabase functions serve sync-session-post-to-discord` は実行していない。ローカルserve未起動のため、`dry_run = true` の実レスポンス確認も未実行。

安全検索では `fetch(`、DB書き込み系メソッド、`console.`、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。

次工程では、ユーザー手元で必要な環境変数と認証文脈を用意し、`dry_run = true` のみを確認する。`dry_run = false` は実行しない。

この追記ではdocs整理のみ行い、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-13C dry_run=false拒否確認のIO結果

ユーザー手元で `create` / `dry_run = false` を確認し、実送信未有効化として拒否されることを確認した。HTTP statusは501で、レスポンスはJSONとしてparse可能だった。返却キーは `ok`、`error_code`、`message`、`dry_run` で、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。

IO観点の判断:

- 入力は `create` / `dry_run = false` に限定して確認した。
- 出力は拒否レスポンスとして扱い、実送信成功レスポンスではない。
- Discord投稿は作成されていない。
- DB同期状態列を更新する処理は行っていない。
- レスポンス本文全文、確認対象依頼書ID相当の値、Supabase接続先全文、認証ヘッダー、Discord投稿先、`message_preview` 本文全文は記録しない。

`dry_run = false` が拒否される安全境界は確認できたため、次のIO設計では実送信を有効化する前に、単一募集チャンネル向けの投稿先secret、失敗時レスポンス、DB更新タイミング、ログ安全性を別工程で整理する。

## M-14E-14 実送信前IO設計

初期実装の出力先は単一募集チャンネルに固定する。IO設計上は、投稿先をリクエストpayloadで受け取らず、Edge Function側のsecretから解決する方針を第一候補にする。これにより、フロントやdocsに投稿先実値を出さず、GM別、種別別、セッション別の分岐を初期実装から外す。

### dry-runとreal-sendのIO境界

- `dry_run = true`: `message_preview` と `planned_db_update` 相当の予定情報だけを返す。Discord送信なし、DB更新なし。
- `dry_run = false`: 実送信有効化前は拒否を維持する。実送信有効化後も、secret未設定、権限不足、同期対象外、投稿先解決不可の場合は一般化エラーで返す。
- レスポンスにはsecret実値、認証情報、投稿先実値、内部識別子相当の値、外部APIレスポンス全文を含めない。

### 実送信時のIO順序案

1. 認証とGM/admin権限を確認する。
2. 同期対象の依頼書情報を取得し、公開情報だけでDiscord本文を組み立てる。
3. 投稿先secretを解決する。
4. Discordへ送信する。
5. 送信成功時のみ、外部投稿識別子相当の値と同期状態をDBへ反映する。
6. 送信失敗時は、依頼書保存自体を壊さず、同期失敗として一般化して扱う。

create以外のupdate/close/delete/resyncは、外部投稿識別子相当の保存と失敗時挙動を追加レビューしてから扱う。特にdeleteは、依頼書完全削除前にDiscord側処理を行う必要があるため、実装順序を別途レビューする。

## M-14E-14B 実送信IO draft
Webhook方式で実送信を有効化する場合のIOは、以下の流れを候補にする。

1. Authorizationを検証し、GM本人またはadmin相当のみを許可する。
2. 対象依頼書を取得し、同期対象となる公開情報だけでDiscord投稿本文を組み立てる。
3. `dry_run = true` の場合は、送信せず `message_preview` と `planned_db_update` 相当だけを返す。
4. `dry_run = false` の場合も、実送信有効化条件が満たされるまでは拒否する。
5. 実送信有効化後は、Edge Function側secretからWebhookを解決する。payloadやフロントから投稿先実値を受け取らない。
6. DiscordへPOSTし、成功時のみ作成済みメッセージ情報から外部投稿識別子相当を取得する。
7. Discord送信成功後にのみ、同期状態と外部投稿識別子相当をDB更新する。
8. Discord送信失敗時は、一般化した失敗情報だけを返し、必要ならfailed相当を記録する。レスポンス全文は扱わない。

実送信成功レスポンスも、UIに必要な最小情報へ丸める。外部投稿識別子相当、投稿先実値、認証情報、確認対象依頼書ID相当の実値、Webhook実値、外部APIレスポンス全文は返さない。

## M-14E-14C 実装前IOレビュー
実装前に確認すること:

- `dry_run = true` と `dry_run = false` の分岐が先頭近くで明確であること。
- secret未設定時はDiscord送信前に拒否すること。
- Discord送信成功前にDB更新しないこと。
- Discord送信成功後のDB更新失敗時に、二重投稿リスクをどう検出・回避するかを記録すること。
- `create` で既存外部投稿識別子がある場合は二重投稿を作らないこと。
- `update` / `close` / `delete` / `resync` は、外部投稿識別子と状態遷移の扱いが固まるまで段階的に進めること。
- Function Logsやレスポンスにsecret、JWT、投稿先実値、確認対象依頼書ID相当の実値、外部APIレスポンス全文を出さないこと。

## M-14E-14C Webhook helper IO draft実装
Webhook helper draftのIOは、将来の実送信に必要な最小単位として整理した。入力は既存preview本文相当の文字列、出力は「成功して外部投稿識別子相当を得た」または「一般化された失敗理由」に丸める。

現時点の実行経路では、このhelperは呼ばれない。`dry_run = true` は従来どおりpreviewを返し、`dry_run = false` は `real_send_not_enabled` 相当で拒否される。したがって、Webhook helper内に将来用の送信処理draftがあっても、この工程ではDiscord実送信は発生しない。

payload draft:

- `content`: 既存message previewをDiscord本文長に収まるよう切り詰めた文字列。
- `allowed_mentions`: 意図しないメンションを避けるため、初期draftではparse対象なし。

レスポンス処理draft:

- 成功時は外部投稿識別子相当だけを抽出する。
- 失敗時はHTTP status相当と一般化したエラー種別に丸める。
- Discordレスポンス全文、Webhook実値、投稿先実値、認証情報、確認対象依頼書ID相当の実値は返さない。

DB更新はまだIOに含めない。実送信成功後のDB更新、DB更新失敗時の補償、二重投稿防止は後続工程で扱う。

## M-14E-14D secret設定後のIO確認手順
secret設定後も、IO上の安全境界は変えない。`dry_run = true` は `message_preview` と `planned_db_update` 相当のpreviewのみを返し、Discord送信とDB更新を行わない。`dry_run = false` は実送信有効化コードへ進むまで拒否を維持する。

確認するIO項目:

- 入力payloadやAuthorization値をdocsへ記録しない。
- レスポンスにはsecret実値、Webhook実値、投稿先実値、確認対象依頼書ID相当の実値、認証情報、`message_preview` 本文全文を含めない。
- Function Logsにsecret実値やWebhook実値が出ていない。
- Discord側に投稿が作成されていない。
- DB同期状態が変わっていない。

実送信有効化前の最終レビューでは、`create` の二重投稿防止を確認する。既存外部投稿識別子がある場合は、新規投稿を作らず拒否または更新系へ誘導する案を優先する。Discord API成功後にDB更新が失敗した場合の扱いは、実送信コード有効化前に別途設計する。

## M-14E-14E secret設定前のIO安全レビュー
secret設定前に、投稿先と初回確認方針をユーザー判断事項として固定する。docs上では投稿先の実値を扱わず、「本番募集チャンネル」または「テスト用チャンネル」という抽象名のみを使う。

IO境界:

- リクエストpayloadにはWebhook URL、投稿先実値、チャンネル識別子相当の値を含めない。
- `dry_run = true` は引き続きpreviewのみを返し、Discord送信とDB更新を行わない。
- `dry_run = false` は実送信有効化コード変更まで拒否を維持する。
- レスポンスとFunction Logsにはsecret実値、Webhook実値、認証情報、投稿先実値、確認対象依頼書ID相当の実値、`message_preview` 本文全文を含めない。

secret設定前に決めること:

- Webhook方式で進めるか。
- 初回確認をテスト用チャンネルで行うか、本番募集チャンネルで行うか。
- テスト投稿に使う依頼書を検証用に限定するか。
- 誤投稿時の削除または訂正担当と手順。
- 二重投稿防止、外部投稿識別子既存時の `create` 挙動、Discord成功後DB更新失敗時の扱い。

これらが未確定の場合は、実送信有効化コード変更へ進まない。

## M-14E-14F テスト用チャンネル前提のIO確認
初回の実送信確認はテスト用チャンネルを先に使う。IO設計上は、テスト用チャンネルであっても投稿先実値をpayload、docs、レスポンス、Function Logsへ出さない方針を維持する。

secret設定前後のIO境界:

- Webhook URLは `DISCORD_SESSION_POST_WEBHOOK_URL` としてEdge Function側secretに設定するが、リクエストpayloadでは受け取らない。
- docsには `<WEBHOOK_URL>` のようなプレースホルダーだけを使い、実値は記録しない。
- `dry_run = true` はpreviewのみを返し、Discord送信とDB更新を行わない。
- `dry_run = false` は実送信有効化コード変更まで `real_send_not_enabled` 相当で拒否する。
- レスポンスとFunction LogsにはWebhook URL、認証情報、投稿先実値、確認対象依頼書ID相当の実値、`message_preview` 本文全文を含めない。

secret設定後に確認するIO:

- Discord側に投稿が増えていない。
- DB同期状態が更新されていない。
- Function LogsにWebhook URLが出ていない。
- git差分にsecret実値が出ていない。

これらの確認が終わるまでは、実送信有効化コード変更や本番募集チャンネルへの切り替えに進まない。

## M-14E-14G/H/I/J secret設定後dry-run IO確認結果
ユーザー手元でテスト用チャンネル向けsecret設定後のIO確認を実施済み。入力に使った認証情報、確認対象依頼書ID相当の実値、Supabase接続先全文、Webhook URL、投稿先実値はdocsへ記録しない。

`dry_run = true`:

- `create` / `dry_run = true` はHTTP 200で成功した。
- JSON parseは成功した。
- `ok = true`、`dry_run = true`、`action = create` を確認した。
- `message_preview`、`planned_db_update`、`warnings` が返却された。
- `message_preview` 本文全文は記録しない。
- Discord送信なし、DB更新なしのpreview境界を維持した。

`dry_run = false`:

- `create` / `dry_run = false` はHTTP 501で拒否された。
- JSON parseは成功した。
- `ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。
- 拒否レスポンスは一般化されており、実送信はdraftでは有効化されていないことを示した。
- Discord API送信とDB更新には進んでいない。

Discord側:

- テスト用チャンネルに新規投稿が増えていないことをユーザーが目視確認済み。
- secret設定だけでは投稿が発生しないことを再確認した。

次のIO設計では、実送信有効化コードを追加する前に、DB更新連携を同時に入れるか分離するか、送信成功後DB更新失敗時の扱い、二重投稿防止を追加レビューする。

## M-14E-14K 実送信有効化時のIO変更案
実送信有効化時のIO変更は、テスト用チャンネル向け `create` の1回確認に必要な最小範囲に限定する。`dry_run = true` はpreview専用のまま維持し、`dry_run = false` であっても `update` / `close` / `delete` / `resync` は拒否する。

入力:

- `action = create` のみ実送信候補にする。
- Webhook URL、投稿先実値、チャンネル識別子相当、認証情報の実値はpayloadに含めない。
- 確認対象依頼書ID相当の値はユーザー手元だけで扱い、docsやログへ記録しない。

成功レスポンス:

- `ok = true`、`dry_run = false`、`action = create`、一般化した送信結果だけを候補にする。
- Discord message id相当は初回確認ではレスポンスへ返さず、DB更新連携設計後に内部保持する案を第一候補にする。
- Discord APIレスポンス全文、Webhook URL、投稿先実値、確認対象依頼書ID相当の実値、認証情報は返さない。

失敗レスポンス:

- `webhook_secret_missing`、`unsupported_action`、`sync_target_not_allowed`、`discord_send_failed` などの一般化したerror_codeへ丸める。
- Discord APIエラー本文や外部レスポンス全文は返さない。
- 失敗時もDB更新を行わない。

DB更新連携:

- 初回実送信確認ではDB更新を分離する案を推奨する。
- 理由は、Discord投稿成功後にDB更新が失敗すると、再実行時の二重投稿リスクと状態不整合が残るため。
- 外部投稿識別子保存、同期状態更新、失敗状態記録は、送信成功後DB更新失敗時の扱いと二重投稿防止を固めてから別工程で扱う。

ログ:

- request body全文をログに出さない。
- Webhook URL、JWT、Authorization、投稿先実値、確認対象依頼書ID相当の実値をログに出さない。
- Discord APIレスポンス全文をログに出さない。
- Function Logsでは、一般化した成功/失敗種別と処理段階のみを確認対象にする。

## M-14E-14L create実送信経路のIO実装メモ
`dry_run = false` かつ `action = create` の場合のみWebhook送信IOへ進む経路を追加した。`dry_run = true` ではWebhook送信IOを呼ばず、従来どおり `message_preview` と `planned_db_update` 相当を返す。

入力境界:

- payloadからWebhook URLや投稿先実値は受け取らない。
- Webhook URLはEdge Function secret `DISCORD_SESSION_POST_WEBHOOK_URL` からのみ解決する。
- secretが未設定、空、不正な場合は一般化エラーで拒否し、送信IOへ進まない。

出力境界:

- 成功時は `ok = true`、`dry_run = false`、`action = create`、一般化した送信結果、DB更新延期情報だけを返す。
- Discord message id相当は実値として返さず、受け取れたかどうかだけを一般化する。
- 失敗時は一般化したerror_codeとmessageだけを返す。
- Discord APIレスポンス全文、Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値、`message_preview` 本文全文は返さない。

DB更新IOは追加していない。外部投稿識別子保存、同期状態更新、失敗状態記録は後続工程に分離する。

## M-14E-14M deploy前IO安全確認
`create` 実送信経路のdeploy前に、入出力境界を再確認した。この工程ではdeploy、Discord実送信、dry-run再実行、DB/RPC変更、フロント実装は行っていない。

入力境界:

- `dry_run = true` は従来どおりpreview専用。
- `dry_run = false` で実送信候補になるのは `action = create` のみ。
- `update` / `close` / `delete` / `resync` は拒否維持。
- Authorization、GM/admin権限確認、対象依頼書取得、同期対象判定、action検証を通過しない限りWebhook helperへ進まない。
- secret未設定、空、不正時はfetch前に拒否する。

出力境界:

- 成功時レスポンスは最小限にし、Discord APIレスポンス全文は返さない。
- 外部投稿識別子相当の実値はレスポンスへ返さない。
- Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の値、`message_preview` 本文全文は返さない。
- DB更新結果は返さない。初回実装ではDB更新自体を行わない。

deploy前確認:

- Deno構文確認は成功。
- `fetch(` はWebhook helper内の想定箇所のみ。
- DB書き込み系メソッドと `console.*` は追加なし。
- `deno.lock` と `supabase/.temp` はcommit対象にしない。

初回実送信後のIO確認は、テスト用チャンネルへの1件投稿とFunctionレスポンスの一般化情報に絞る。本文全文、投稿先実値、認証情報、確認対象依頼書ID相当の値は記録しない。

## M-14E-14Q 初回実送信後のIO結果
テスト用チャンネル向け `create` / `dry_run = false` をユーザー手元で1回だけ実行し、HTTP 200で成功した。対象は検証用依頼書 `TEST_1`。確認対象ID相当の実値、投稿先実値、認証情報、Supabase接続先全文、Discord message id相当の実値、`message_preview` 本文全文は記録しない。

レスポンスIO:

- JSON parse成功。
- `ok = true`。
- `dry_run = false`。
- `action = create`。
- レスポンスキーは `ok` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- 外部投稿識別子相当の実値は返っていない。
- Discord APIレスポンス全文は返っていない。

Discord IO:

- テスト用チャンネルに依頼書通知が1件作成された。
- 本番募集チャンネルへの投稿はなし。
- 追加実送信は行っていない。

DB IO:

- DB更新連携、外部投稿識別子保存、同期状態更新は未実装のまま。
- 今回の実送信成功後も、Function処理としてDB更新は行わない設計。

手順上の注意:

- 対話プロンプト依存で送信可否を止める方式は、貼り付け済み後続行の実行リスクがある。
- 今後は確認コマンドと送信コマンドを分離し、送信コマンドは単発で実行する。
- 同じ検証用依頼書で再実行しない。

## M-14E-15 Discord投稿本文IO改善方針
テスト用チャンネルへの初回実送信で、現行本文がDB項目列挙寄りで読みにくいことが分かったため、Discord投稿本文IOを参加者向けの依頼書形式へ改善する。M-14E-15では設計のみ行い、Edge Functionコード変更、deploy、dry-run再実行、Discord追加実送信、DB/RPC変更、フロント実装は行わない。

### 新しい出力本文案
Discord本文は次の形を第一候補にする。

```text
＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝

■依頼書【タイトル】
GM【GM名】
開催場所【開催場所】
日時【MM/DD(曜) HH:mm　～　MM/DD(曜) HH:mm】
参加人数【最小～最大人】
参加締切【MM/DD(曜) HH:mm】

概要
概要本文
```

IO上の変更点:

- `詳細` 欄は出力しない。
- サイト詳細URLは出力しない。
- 下部の区切り線は出力しない。
- DiscordのOGP/埋め込み表示を避け、投稿本文は概要までで完結させる。
- `dry_run = true` の `message_preview` と `dry_run = false` 実送信本文は同じ整形結果にする。
- `message_preview` 本文全文はdocsやログへ記録しない。

### 追加入力候補
新フォーマットでは、依頼書データに「開催場所」相当の入力が必要になる。

入力候補:

- 内部名第一候補: `session_tool`
- 日本語ラベル: 開催場所
- 意味: 物理会場ではなく、セッションツール/開催環境
- 例の扱い: docsには実際の卓固有値を記録せず、候補名や一般名だけを扱う。

`session_tool` が未設定の場合、出力では `開催場所【未定】` へ丸める案を第一候補にする。

### 日時・人数・概要の整形
日時:

- ISO文字列やUTC表記はDiscord本文へ出さない。
- `MM/DD(曜) HH:mm` の短い形式へ整形する。
- 開始と終了を `　～　` でつなぐ。
- 日跨ぎや終了時刻未設定時の扱いは実装前に確認する。

人数:

- `2～5人` のように表示する。
- 最小または最大が未設定の場合の丸め方はDB/RPC/UI設計時に決める。

概要:

- 概要が空の場合は `未設定` を出す案を第一候補にする。
- 長文の場合はDiscordの文字数制限に合わせた丸め方をEdge Function実装時に確認する。

### 入出力で含めないもの
新フォーマットにも、以下は含めない。

- Webhook URL、bot token、認証情報、Supabase接続先全文。
- 確認対象依頼書ID相当の実値、外部投稿識別子相当の実値。
- Discord投稿先実値。
- GM/admin向け承認済み参加者連絡先。
- 内部ID、raw user_id、email、token、selected_character_id、application_id。
- サイト詳細URL、クエリ付き詳細導線。

### 後続実装のIO確認
Edge Functionを変更する工程では、次を確認する。

- `dry_run = true` と実送信本文が同じ。
- URL/詳細欄が出ない。
- 開催場所未設定時に `未定` へ丸められる。
- ISO/UTC表記が出ない。
- 実値や秘匿値がレスポンス、ログ、docsへ出ない。

## M-14E-15B session_tool DB/RPC IO設計
Discord投稿本文の `開催場所【...】` に使う値として、依頼書データへ `session_tool` を追加する方針を整理した。この工程ではSELECT-only preflight SQL draftとdocs整理のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

preflight:

- `docs/supabase/sql/026_session_tool_preflight_select_only.sql`
- 単一結果セット形式。
- `public.sessions`、類似列、RPC signature、RLS、EXECUTE権限、helper存在をcatalogから確認する。
- 実データ値、認証情報、外部投稿先実値は扱わない。

DB IO候補:

- 入力列候補は `public.sessions.session_tool text`。
- NULL許容を第一候補にする。
- DB上はNULLを未設定の正規値とし、空文字はRPCでtrim後NULLへ丸める。
- 初期実装では固定候補CHECKを置かず、自由入力を優先する。
- 将来、UI側で候補selectに寄せる場合も、DB値の固定化は別工程で検討する。

RPC IO候補:

- 作成入力: `create_session_post(...)` に `p_session_tool text default null` を追加する候補。
- 更新入力: `update_session_post(...)` に `p_session_tool text default null` を追加する候補。
- 詳細/list出力: session-detail、calendar、session-post管理一覧、Edge Function本文生成で使う範囲に `session_tool` を含める。
- 削除RPC: `delete_session_post(text)` は `session_tool` を扱わない。

互換性注意:

- `p_end_at` 対応時と同様、PostgREST RPCのdefault引数overload曖昧化に注意する。
- preflightで既存signatureが1本か、類似RPCがあるかを確認してから、旧signatureをdrop/recreateするか、別RPCに分けるかを決める。
- 返却値に raw user_id、email、token、認証情報、外部投稿先実値、Discord message id相当の実値は含めない。

Discord出力:

- `session_tool` がある場合は `開催場所【<値>】` として使う。
- NULLまたは空文字は `開催場所【未定】` へ丸める。
- `dry_run = true` previewと実送信本文は同じ丸め結果を使う。
- Discord本文にはサイト詳細URLやクエリ付き詳細導線を入れない。

## M-14E-15C session_tool preflight IO結果
ユーザー手元で `026_session_tool_preflight_select_only.sql` をSQL Editor実行し、結果グリッドを確認した。初回はSQL内の日本語説明文字列が貼り付け経路で壊れて構文エラーになったため、SQL draft側の説明文字列をASCIIへ寄せた。修正後は結果グリッドが表示された。

IO観点の確認結果:

- 依頼書データの正本候補は引き続き `public.sessions`。
- `session_tool` 入力列はまだ存在しない。
- `play_location` / `venue` / `session_place` 系の代替列も見つからず、既存列流用ではなく新規列追加が自然。
- `session_tool` 関連CHECK制約は存在しないため、初期自由入力案と矛盾しない。
- `create_session_post(...)` と `update_session_post(...)` は存在するため、作成/更新IOへ `session_tool` を追加する必要がある。
- `delete_session_post(text)` は削除用途であり、`session_tool` IO追加対象外でよさそう。
- RLSとpolicyは存在し、nullable text列追加だけで権限境界を広げない方針を維持する。

次のIO設計候補:

- DB入力: `public.sessions.session_tool text null`。
- 作成/更新RPC入力: `p_session_tool text default null`。
- RPC内正規化: trim後空文字をNULLへ丸める。
- フロント/詳細/Discord出力: NULLまたは空文字を `未定` へfallbackする。
- 初期CHECKなし。候補selectや固定値制約は後続検討。

この工程ではIO結果のdocs記録のみで、SQL apply、DB/RPC変更、Edge Functionコード変更、deploy、Discord送信、dry-run実行、フロント実装は行わない。

## M-14E-15D session_tool apply draft IO
M-14E-15Cのpreflight結果にもとづき、`session_tool` 追加用の未実行apply draft `docs/supabase/sql/027_session_tool_apply_review_draft.sql` を作成した。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord送信、dry-run実行、フロント実装は行わない。

DB IO draft:

- `public.sessions.session_tool text null` を追加する。
- NULLを未設定の正規値とする。
- 既存データへ一括値設定は行わない。
- 初期実装では固定候補CHECKを置かない。

RPC IO draft:

- `create_session_post(...)` の最終引数に `p_session_tool text default null` を追加する。
- `update_session_post(...)` の最終引数に `p_session_tool text default null` を追加する。
- RPC内で空文字をtrim後NULLへ丸める。
- 改行は拒否し、文字数上限は80文字とする。
- `delete_session_post(text)` は `session_tool` を扱わず、変更対象外。

戻り値と後続IO:

- create/update RPCの戻り値は既存の最小情報を維持し、今回draftでは `session_tool` を返さない。
- detail/listや直接SELECTで画面・Edge Functionが使う取得列へ `session_tool` を含める作業は、SQL適用後のフロント/Edge Function工程で扱う。
- Discord投稿本文では後続工程で `開催場所【session_toolまたは未定】` を使う。
- raw user_id、email、token、認証情報、外部投稿先実値、Discord message id相当の実値は返さない。

互換性:

- PostgREST RPCのdefault引数overload曖昧化を避けるため、既存signatureと新signature候補をdrop/recreateするdraftにした。
- 既存の `security definer` / `set search_path = ''` / `authenticated` EXECUTE方針を維持する。
- `public` / `anon` にはEXECUTEを付与しない。

## M-14E-15E session_tool apply draft IOレビュー
`027_session_tool_apply_review_draft.sql` のIO観点レビューを行った。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord送信、dry-run実行、フロント実装は行わない。

確認したIO:

- DB入力列は `public.sessions.session_tool text null`。
- create RPCは `p_session_tool text default null` を最終引数に追加する。
- update RPCも `p_session_tool text default null` を最終引数に追加する。
- createでは未指定/空文字をNULLとして保存する。
- updateでは未指定なら既存値を保持し、空文字を送った場合はNULLへクリアする。
- 改行不可と80文字上限はRPC側で検証する。
- `delete_session_post(text)` は `session_tool` IO対象外。

レビューで修正した点:

- update RPCの `session_tool` 更新挙動を、未指定時にNULL上書きではなく既存値保持へ変更した。
- schema/RPC/grant適用部分を明示トランザクションで包み、エラー時に途中状態を避けやすいdraftへ修正した。
- `DROP FUNCTION` に `CASCADE` を使わない方針をdraftコメントにも明記した。

後続IO注意:

- SQL適用後、フロントは編集フォームから `session_tool` を明示送信する。
- 既存クライアントが `p_session_tool` を送らない場合は既存値を保持する。
- `session_tool` を消したい場合は空文字を送る。
- detail/list/Edge Function本文生成側へ `session_tool` を含める作業は、SQL適用後の別工程で扱う。

## M-14E-15F session_tool apply手動実行前IO確認
SQL Editorへ貼る前のIO観点を整理した。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord送信、dry-run実行、フロント実装は行わない。

SQL Editorへ貼る範囲:

- `docs/supabase/sql/027_session_tool_apply_review_draft.sql` 全体。
- post-apply確認SELECTも含めて貼る。
- rollback notesはコメントであり、実行対象の列削除SQLではない。

成功時に見るIO:

- DB: `session_tool` 列が `public.sessions` に追加されている。
- create RPC: 最終引数 `p_session_tool` がある。
- update RPC: 最終引数 `p_session_tool` がある。
- delete RPC: session_toolとは無関係のまま。
- EXECUTE: authenticatedのみ許可され、anon/publicには不要なEXECUTEがない。
- RLS: `public.sessions` のRLSが有効のまま。

結果共有時の注意:

- 実データ行、ユーザーID、メールアドレス、認証情報、外部投稿先実値、Discord message id相当の実値を貼らない。
- SQL Editorが最後の結果グリッドだけを表示する場合は、見えている範囲を要約し、再実行しない。

## M-14E-15H session_tool SQL適用後IO結果
ユーザー手元で `027_session_tool_apply_review_draft.sql` 全体をSQL Editorへ貼り付け、手動実行した。Codex側ではSQL Editor実行、追加SQL apply、DB/RPC追加変更を行っていない。

確認できたIO結果:

- SQL Editorはエラーではなく結果グリッドを表示した。
- 最後に見えていた結果はRLS確認で、`sessions_rls_enabled = true`、`sessions_force_rls = false`。
- SQL Editorが最後の結果グリッドのみ表示している可能性がある。
- 同一apply SQLは再実行しない。

残る確認候補:

- `public.sessions.session_tool` 列の存在、型、NULL許容。
- `create_session_post` / `update_session_post` signatureに `p_session_tool` が含まれること。
- `delete_session_post` が変更対象外のままであること。
- authenticated EXECUTE、anon/public不可の権限状態。

これらの詳細確認が必要な場合は、次工程でSELECT-only確認として分ける。実データ行、ユーザーID、メールアドレス、認証情報、外部投稿先実値は記録しない。

## M-14E-15I/J/K session_tool UI/Discord IO反映
SQL適用後SELECT-only確認により、`public.sessions.session_tool` は `text` / NULL許容で存在し、`create_session_post` / `update_session_post` は `p_session_tool` 引数を持ち、`delete_session_post` は変更対象外のまま存在することを確認済みとして記録した。`public.sessions` のRLSは `rls=true, force_rls=false`。

フロントIO:

- session-post作成/編集フォームは `p_session_tool` をRPC payloadへ渡す。
- session-post管理一覧取得のSELECT列に `session_tool` を含め、既存依頼書編集時にフォームへ反映する。
- mypageの依頼書テンプレートJSONにも `p_session_tool` を含め、依頼書用テンプレートのフォーム編集UIで保持できるようにする。
- 空欄はRPC側のtrim/NULL化に任せ、画面表示では未設定値を `未定` へ丸める。

session-detail IO:

- Supabase由来セッション取得列に `session_tool` を含める。
- detail表示では `開催場所` として表示する。
- GM/admin管理操作は参加者向け基本情報から外し、補足情報の募集状態の下へ移動する。

Discord IO:

- Edge FunctionのSELECT列に `session_tool` を含める。
- Discord本文では `開催場所【session_toolまたは未定】` として出力する。
- `dry_run = true` previewと実送信本文は同一フォーマットを使う。
- Discord本文にはサイト詳細URL、クエリ付き詳細導線、Webhook URL、投稿先実値、JWT、確認対象ID、project ref、Supabase URL全文、Discord message id相当の実値を含めない。
- 日時はISO/UTC形式ではなく、曜日つきの `MM/DD(曜) HH:mm　～　MM/DD(曜) HH:mm` へ整形する。

この工程ではコード実装とdocs整理のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Function deploy、Discord追加実送信、dry-run再実行、`updates.json` 変更、commit / pushは行わない。

## M-14E-15L/M deploy後 dry_run=true IO確認
deploy済み `sync-session-post-to-discord` について、ユーザー手元で `create / dry_run = true` を再確認した。Codex側ではリクエスト実行、追加deploy、Discord送信、SQL Editor実行、DB/RPC変更、フロント追加実装は行っていない。

入力IO:

- Authorization用JWTはユーザー手元でPowerShell待機方式により再取得済み。JWT本体は記録しない。
- JWTは3パート形式として確認済み。
- 確認対象IDはユーザー手元で待機方式により再取得済み。ID本体は記録しない。
- 確認対象IDの値は出力されていない。
- Supabase URLはユーザー手元で準備済み。URL全文は記録しない。
- requestは `action = create`、`dry_run = true`。

レスポンスIO:

- HTTP 200。
- HTTP errorなし。
- JSON parse成功。
- `ok = true`。
- `dry_run = true`。
- `action = create`。
- `message_preview` 返却あり。ただし本文全文は記録しない。
- previewは125文字、9行。
- `planned_db_update` 返却あり。dry-run上の予定情報であり、DB更新実行ではない。
- `warnings` 返却あり。

preview確認:

- 冒頭区切り線あり。
- サイト詳細URLなし。
- `詳細` ラベルなし。
- `開催場所` ラベルあり。
- ISO/UTC形式の日時表記なし。
- message preview本文全文、確認対象ID、JWT、project ref、Supabase URL全文、Discord投稿先実値、Discord message id相当の実値は記録していない。

副作用確認:

- Discordテスト用チャンネルに新規投稿が増えていないことをユーザーが目視確認済み。
- `dry_run = true` preview専用のためDiscord送信なし。
- DB更新連携、外部投稿識別子保存、同期状態更新は未実施。
- `dry_run = false` 実送信は再実行していない。

次のIO確認候補:

- まずUI手動QAを優先する。依頼書作成/編集で `session_tool` を入力し、保存後にsession-detailへ開催場所が表示されること、未入力時に `未定` へ丸められることを確認する。
- 募集人数min/maxの同一行表示、GM/admin管理ブロックの位置も確認する。
- 新フォーマットの実送信確認が必要な場合は、旧フォーマットで送信済みの既存検証用依頼書を再利用せず、新しい検証用依頼書を使う。
- DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続IO設計に残す。

この工程ではdocs記録のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15N-FIX session_tool UI QA / update IO修正
ユーザー実ブラウザで `session_tool` / 開催場所UIを手動QAした。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信、dry-run実行を行っていない。

QA結果:

- create IO: 新規依頼書作成時、開催場所入力を保存でき、session-detailへ表示された。
- update IO: 編集時、開催場所を別値へ変更して保存でき、session-detailへ反映された。
- detail IO: session-detailの開催場所表示を確認できた。
- layout IO: 募集人数min/max欄の見た目崩れなし。
- management IO: GM/admin管理ブロックは補足情報内の募集状態下、更新日時前に表示され、参加者向け基本情報の上部を邪魔していない。
- exposure IO: raw id、user_id、email、token等の画面露出なし。
- Discord IO: テスト用チャンネルに新規投稿増加なし。

不具合:

- update IOで開催場所を空欄保存した場合、session-detailが `未定` にならず、前回入力値が保持された。
- 再編集時も開催場所欄に前回値が残った。

原因と修正:

- `buildSessionPayload()` は作成/更新共通で、空欄の `p_session_tool` を `nullableText(...)` により `null` へ丸めていた。
- `update_session_post` は `p_session_tool is null` を既存値保持、空文字を明示クリアとして扱う設計。
- `buildUpdatePayload()` で更新時のみ `p_session_tool: getValue(form, "p_session_tool")` を上書きし、空欄を空文字としてRPCへ渡すよう修正した。
- 新規作成時の空欄は従来どおり `null` のまま。
- DB/RPC変更は不要。

修正後確認:

- 編集で開催場所を空欄保存し、session-detailで `未定` 表示になることを確認済み。
- 前回値保持問題は解消済みとして扱う。
- Discord投稿増加なし。
- `dry_run = false` は未実行。

残るIO候補:

- M-14E-15Oで今回のUI QA結果とFIXをcommit / pushする。
- 新フォーマット実送信確認を行う場合は、新しい検証用依頼書を使い、既存の旧フォーマット送信済み依頼書は再利用しない。
- DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続IO設計に残す。

この工程ではdocs記録と既存フロント差分の静的確認のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-A 公開サイト反映後QA / Discord実送信前IOレビュー
`73968eb Fix session tool clear handling` のGitHub Pages反映後、ユーザー実ブラウザで `session_tool` クリア挙動を再確認した。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信、dry-run実行を行っていない。

公開サイトQA IO:

- update IO: 開催場所を空欄保存できた。
- detail IO: session-detailで `未定` 表示になった。
- edit reload IO: 再編集画面でも開催場所欄が空欄になった。
- Discord IO: テスト用チャンネルに新規投稿増加なし。
- exposure IO: raw id、user_id、email、token等の画面露出なし。
- `73968eb` の修正は公開サイトにも反映済みと判断する。

次回実送信確認の入力IO方針:

- 新しい検証用依頼書を使う。
- 推奨タイトルは `M14E15P_discord_format_QA_01`。
- 旧フォーマットで送信済みの既存 `TEST_1` は再利用しない。
- 今回のUI QA用依頼書も編集検証済みのため、実送信用には別の新規検証用依頼書を使う。
- 実送信前に `dry_run = true` preview確認を必ず行う。
- 確認コマンドと送信コマンドを分離し、対話プロンプト依存の送信手順を使わない。
- `dry_run = false` はユーザー確認後、独立工程で1回のみ実行する。

preview IO確認項目:

- HTTP 200。
- JSON parse成功。
- `ok = true`。
- `dry_run = true`。
- `action = create`。
- `message_preview` あり。ただし本文全文は記録しない。
- 冒頭区切り線あり。
- 開催場所ラベルあり。
- 詳細URLなし。
- 詳細ラベルなし。
- ISO/UTC表記なし。
- Discord投稿増加なし。

実送信IOの停止条件:

- JWT、確認対象ID、Supabase URLの準備に失敗。
- `dry_run = true` preview確認が通らない。
- previewにURL、詳細リンク、ISO/UTC表記が混入。
- 対象が旧 `TEST_1`、または意図しない依頼書。
- Discordテスト用チャンネルではない疑い。
- 既に投稿済みの対象を再利用している疑い。
- 不明なエラーが出た場合。

実送信後も未実装のIO:

- DB更新連携。
- 外部投稿識別子保存。
- 同期状態更新。
- 二重投稿防止。
- `update` / `close` / `delete` / `resync` 対応。
- GM/admin同期UI。
- 本番募集チャンネル切り替え。

この工程ではdocs記録と安全レビューのみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-B 新規検証用依頼書 dry_run=true preview IO結果
新しい検証用依頼書 `M14E15P_discord_format_QA_01` を対象に、ユーザー手元で `create / dry_run = true` previewを確認した。Codex側ではリクエスト実行、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信を行っていない。

入力IO:

- 対象依頼書は `M14E15P_discord_format_QA_01`。
- 旧 `TEST_1` とUI QA用依頼書は再利用していない。
- 確認対象IDはPowerShell待機方式で取得済み。ID本体は出力・記録していない。
- `SESSION_ID_CAPTURED = true`、`SESSION_ID_SET = true`、`SESSION_ID_LENGTH = 27`。
- JWTはユーザー手元で再取得済み。JWT本体は出力・記録していない。
- `USER_JWT_READY = true`、`SESSION_ID_READY = true`、`SUPABASE_URL_READY = true`。
- requestは `action = create`、`dry_run = true`。

レスポンスIO:

- `DRY_RUN_EXECUTED = true`。
- `TARGET_SESSION_TITLE = M14E15P_discord_format_QA_01`。
- `HTTP_ERROR = false`、`HTTP_STATUS = 200`。
- JSON parse成功。
- `ok = true`。
- `dry_run = true`。
- `action = create`。
- `message_preview` 返却あり。ただし本文全文は記録しない。
- previewは145文字、9行。
- `planned_db_update` 返却あり。dry-run上の予定情報であり、DB更新実行ではない。
- `warnings` 返却あり。

preview検証IO:

- 冒頭区切り線あり。
- 詳細URLなし。
- 詳細ラベルなし。
- 開催場所ラベルあり。
- 対象タイトル一致。
- ISO/UTC表記なし。
- message preview本文全文、JWT、確認対象ID、project ref、Supabase URL全文、Discord投稿先実値、Discord message id実値は記録していない。

副作用確認:

- Discordテスト用チャンネルに新規投稿増加なし。
- `dry_run = true` はpreview専用として維持されている。
- `dry_run = false` 実送信は未実行。
- DB更新連携、外部投稿識別子保存、同期状態更新は未実装のまま。

次のIO候補:

- M-14E-15P-Cとして、テスト用チャンネルへ `create / dry_run = false` を1回だけ確認する。
- 実送信前に、確認コマンドと送信コマンドを分離し、対話プロンプト依存の送信手順を使わない。
- DB更新連携、外部投稿識別子保存、二重投稿防止、action拡張、本番募集チャンネル切り替えは後続IO設計に残す。

この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 実送信、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-C テスト用チャンネル create dry_run=false 実送信IO結果
新しい検証用依頼書 `M14E15P_discord_format_QA_01` を対象に、ユーザー手元で `create / dry_run = false` を1回だけ実行し、テスト用チャンネルへの実送信を確認した。Codex側ではリクエスト実行、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加送信を行っていない。

入力IO:

- 対象依頼書は `M14E15P_discord_format_QA_01`。
- 旧 `TEST_1` とUI QA用依頼書は再利用していない。
- 実送信先はテスト用チャンネル向けWebhook設定。
- `USER_JWT_READY = true`。
- `SESSION_ID_READY = true`。
- `SUPABASE_URL_READY = true`。
- `TARGET_SESSION_TITLE_EXPECTED = M14E15P_discord_format_QA_01`。
- `REAL_SEND_NOT_EXECUTED = true`。
- `READY_FOR_MANUAL_CONFIRMATION = true`。
- 送信対象確認コマンドと送信コマンドは分離済み。
- JWT、確認対象ID、Supabase URL全文、Webhook URL、Discord投稿先実値は記録していない。

実送信レスポンスIO:

- `REAL_SEND_REQUEST_ACTION = create`。
- `REAL_SEND_REQUEST_DRY_RUN = false`。
- `REAL_SEND_EXPECTED_TARGET = TEST_CHANNEL_CONFIGURED_WEBHOOK`。
- `DO_NOT_RERUN_THIS_COMMAND = true`。
- `REAL_SEND_EXECUTED = true`。
- `HTTP_ERROR = false`。
- `HTTP_STATUS = 200`。
- JSON parse成功。
- `RESPONSE_KEYS = ok,dry_run,action,sync_target,discord_send,db_update,warnings`。
- `ok = true`。
- `dry_run = false`。
- `action = create`。
- `discord_send` 返却あり。
- `db_update` 返却あり。ただし永続DB更新連携、外部投稿識別子保存、同期状態更新は後続工程として扱う。
- `warnings` 返却あり。
- `message_preview` 返却なし。
- 外部投稿識別子相当は存在検知されたが、実値は記録しない。
- `REAL_SEND_CHECK_COMPLETE = true`。

Discord側IO:

- テスト用チャンネルに新規投稿が1件増えた。
- 投稿は「依頼書通知」アプリから送信された。
- 投稿タイトルは `M14E15P_discord_format_QA_01` 相当。
- 冒頭区切り線あり。
- GM表示あり。
- 開催場所表示あり。
- 日時は日本語短縮形式。
- 参加人数表示あり。
- 参加締切表示あり。
- 概要表示あり。
- 詳細URL/詳細リンクなし。
- ISO/UTC表記なし。
- 本番募集チャンネル投稿なし。
- message preview本文全文、Discord message id実値、Discord投稿先実値は記録しない。

判断:

- 新Discord投稿フォーマットのテスト用チャンネル実送信は成功。
- `dry_run = true` previewと `dry_run = false` 実送信の本文フォーマット整合性は概ね確認できた。
- 送信コマンドは1回のみ実行済みであり、再実行禁止。
- DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `close` / `delete` / `resync`、本番募集チャンネル切り替えは後続IO設計に残す。

この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16A Discord同期DB更新連携 / 二重投稿防止IO設計
M-14E-15P-Cでテスト用チャンネルへの `create / dry_run = false` 実送信IOが成功したため、DB更新連携、外部投稿識別子保存、二重投稿防止のIO境界を整理する。この工程では設計とSELECT-only preflight SQL draft作成のみを行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加送信は行わない。

保存IO候補:

- Discord送信成功後に、依頼書DBへ外部投稿識別子相当を保存する。
- 同期状態、最後のaction、同期成功時刻、一般化エラー概要を保存する。
- 候補カラムは `discord_message_id`、`discord_channel_id`、`discord_sync_status`、`discord_last_action`、`discord_synced_at`、`discord_sync_error`、`discord_sync_error_at`、`discord_sync_attempted_at`、`discord_webhook_kind`、`discord_target_kind`。
- 実カラム名はpreflight結果後に確定する。
- 外部投稿識別子実値、Webhook URL、Discord投稿先実値、JWT、確認対象ID、project ref、Supabase URL全文はdocs/console/GitHubへ出さない。

状態IO案:

- 初期は `synced` / `failed` / `not_synced` 相当を中心にする。
- 既存制約が `not_requested` / `pending` / `posted` / `failed` / `skipped` を持つ場合は、既存値へマッピングする。
- `pending`、`skipped`、`unknown` は必要性を確認してから使う。初期実装では複雑化しすぎない。

`create` 二重投稿防止IO:

- DBに外部投稿識別子相当が既にある場合、`action = create` は拒否する。
- 返却するエラーは一般化し、外部投稿識別子実値は返さない。
- 将来は `update` または `resync` へ誘導する。
- DB更新連携が入るまで、本番募集チャンネル切り替えは止める。

Discord成功 / DB更新失敗IO:

- Discord送信成功後にDB更新が失敗した場合、Discord投稿は既に発生している。
- 同じ `create` 再実行は二重投稿リスクになるため、レスポンスで「Discord送信成功」と「DB更新失敗」を分離して返す。
- `ok` の扱いは実装前レビューで決める。安全上は、利用者が再実行しないよう明確な状態を返す必要がある。
- 後続でrepair/resync/手動照合の手順を検討する。

Edge Function IO方針:

- `dry_run = true`: previewと予定情報のみ。DB更新しない。
- `dry_run = false` + Discord送信成功: DB更新を試行する。
- DB更新成功: `db_update` を成功扱いにする。
- DB更新失敗: Discord送信成功とDB更新失敗を分けて返す。
- Discord APIレスポンス全文は返さない。
- 外部投稿識別子実値をレスポンスに返すかは慎重に扱う。少なくともdocs/console/GitHubには記録しない。

action拡張IO:

- `create`: 未投稿なら新規投稿。既存投稿識別子があれば拒否。
- `update`: 既存投稿を編集。
- `close`: 募集終了/締切反映へ更新。
- `delete`: Discord投稿削除または削除済み扱い。完全削除前の順序設計が必要。
- `resync`: DB状態とDiscord状態を再同期。

preflight IO:

- `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` を作成した。
- `public.sessions` の同期系カラム、類似カラム、CHECK制約、RPC signature、関連function、helper、RLS、policy概要、EXECUTE権限をcatalogから確認する。
- 出力は単一結果表で、`sort_order / section / check_name / expected / status / result_value / notes`。
- 実データ行や秘匿値は選択しない。
- この工程ではSQL Editorで実行しない。

本番チャンネル切り替え停止条件:

- DB更新連携未実装。
- 外部投稿識別子保存未実装。
- `create` 二重投稿防止未実装。
- 本番Webhook未切替。
- 本番初回実送信手順未レビュー。

この工程ではdocs設計とSELECT-only preflight SQL draft作成のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16C Discord同期DB状態 preflight IO結果
ユーザー手元で `028_discord_sync_state_preflight_select_only.sql` をSQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行した。SQL Editorではエラーなしで結果グリッドが表示された。Codex側ではSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加送信を行っていない。

実行IO:

- SQL Editorに貼った範囲は `028_discord_sync_state_preflight_select_only.sql` 全体。
- SELECT-only preflightとして実行。
- エラーなし。
- 結果グリッド表示。
- 再実行なし。
- 実データ行、個人情報、認証情報、外部投稿識別子実値は記録しない。

schema IO:

- `public.sessions` は存在。
- core column summaryは `15/15 present`。
- `session_tool` も存在確認済み。
- Discord同期系カラムとして、`discord_message_id`、`discord_channel_id`、`discord_thread_id`、`discord_post_url`、`discord_sync_status`、`discord_last_action`、`discord_sync_requested_at`、`discord_synced_at`、`discord_sync_error` を確認。
- required sync column summaryは `4/4 present`。
- optional sync column summaryは `6/10 present`。
- `discord_last_synced_at` 候補は `discord_synced_at` 類似カラムとして扱えそう。
- `discord_sync_error_at`、`discord_sync_attempted_at`、`discord_webhook_kind`、`discord_target_kind` は未検出候補。

constraint IO:

- `discord_sync_status` のCHECK制約あり。
- `discord_last_action` のCHECK制約あり。
- posting status / visibility のCHECK制約も確認上OK。
- 実装前に既存制約の許容値へ合わせる必要がある。

RPC / auth IO:

- `create_session_post` / `update_session_post` / `delete_session_post` RPCあり。
- 各RPCはsecurity definer確認上OK。
- search_path明示確認上OK。
- authenticatedは実行可能。
- anon / PUBLIC は実行不可。
- public function名にdiscord/sync/resyncを含むものは一部検出。
- sync専用helperは未検出。
- `has_role(text)`、`is_admin()`、`is_session_gm(text)`、`user_roles` は確認上OK。

RLS / policy IO:

- `sessions` RLS enabled。
- `user_roles` RLS enabled。
- policy概要取得済み。
- policy本文や実値は記録しない。

readiness IO:

- 外部投稿識別子相当が存在するため、`create` 二重投稿防止設計へ進める見込み。
- `discord_sync_status` / `discord_last_action` / `discord_synced_at` が存在するため、同期状態更新設計へ進める見込み。
- Discord成功後DB更新失敗時の扱いはmanual review required。
- production channel switch gateはclosedのまま。

判断:

- 既存カラムだけでDB更新連携を実装できる可能性が高い。
- ただしCHECK制約の許容値に合わせて状態更新する必要がある。
- 二重投稿防止は `discord_message_id` 等の既存外部投稿識別子を使う方針が有力。
- DB更新はEdge Functionから直接updateするか、専用RPCを追加するか次工程で比較する。
- 本番募集チャンネル切り替えはまだ行わない。

この工程ではdocs記録と静的確認のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16D/E DB更新連携IO設計とcreate二重投稿防止
M-14E-16Cのpreflight IO結果により、既存Discord同期系カラムでDB更新連携へ進める可能性が高いと判断した。この工程では、Edge Function実装前のIO境界、DB更新経路、二重投稿防止、失敗時レスポンスを整理する。SQL Editor再実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加送信は行わない。

DB更新IO:

- `dry_run = true`: DB更新しない。`planned_db_update` は予定情報のみ。
- `dry_run = false` + Discord送信成功: DB更新を試行する。
- 外部投稿識別子の主軸は `discord_message_id`。
- `discord_channel_id` / `discord_thread_id` / `discord_post_url` は、投稿先照合や将来UIのための保存候補。ただし画面/docs/consoleへ実値を出さない。
- `discord_sync_status` は既存CHECK制約の許容値へ合わせて更新する。
- `discord_last_action` は初期では `create` 相当を保存する。
- `discord_sync_requested_at` は同期試行開始時刻候補。
- `discord_synced_at` は同期成功時刻候補。
- `discord_sync_error` は一般化エラーのみを保存する候補。

CHECK制約IO:

- `discord_sync_status` / `discord_last_action` は既存CHECK制約の許容値へ合わせる。
- `synced` / `not_synced` などアプリ内表現だけで実装しない。
- 追加確認が必要な場合は、制約定義だけを取得するSELECT-only確認を別途用意する。
- 追加SELECT-only候補は `pg_constraint` と `pg_get_constraintdef(...)` を使い、実データ行を取得しない。

DB更新経路比較:

- A案: Edge Functionから `public.sessions` をサーバー側で直接updateする。
  - 利点: 実装が速く、RPC追加が不要。
  - 欠点: 権限境界、不変条件、二重投稿防止がEdge Functionに寄りやすい。原子性と監査性を別途設計する必要がある。
- B案: Discord同期状態更新専用RPCを追加する。
  - 利点: 二重投稿防止、状態遷移、権限、search_path、一般化エラーをDB側へ閉じ込めやすい。
  - 欠点: SQL/RPC applyゲートとレビューが必要。
  - 暫定評価: 第一候補。
- C案: 既存 `update_session_post` に混在させる。
  - 利点: 既存RPCを再利用できる。
  - 欠点: GM編集用RPCと同期状態更新が混ざり、権限境界や監査が曖昧になる。
  - 暫定評価: 非推奨。

二重投稿防止IO:

- `action = create` では、Discord送信前に `discord_message_id` 等が既に存在しないか確認する。
- 既に存在する場合はDiscord送信前に拒否する。
- 拒否レスポンスは一般化し、外部投稿識別子実値を返さない。
- 将来は `update` または `resync` へ誘導する。
- Edge Function側の事前チェックに加え、専用RPC側で原子的に担保する案を第一候補にする。

Discord成功 / DB更新失敗IO:

- Discord投稿が既に発生しているため、同じ `create` 再実行は禁止。
- レスポンスは `discord_send` 成功と `db_update` 失敗を分けて返す。
- top-level `ok` は `false` とし、`discord_sent_db_update_failed` 相当の一般化エラーを返す案を暫定推奨する。
- ただしDiscord送信済みであることはレスポンス上で明確にする。
- `discord_sync_error` に保存する場合も一般化エラーのみとする。
- repair/resync/手動照合は後続IO設計へ分離する。

大きめ工程への再編:

- 設計確定バッチ。
- SQL/RPC draft作成バッチ。
- SQL Editor applyゲート。
- Edge Function実装バッチ。
- deployゲート。
- まとめQAバッチ。
- 本番切替前レビューゲート。
- 本番切替ゲート。

本番募集チャンネル切り替え停止条件:

- DB更新連携未完了。
- 二重投稿防止未完了。
- `update` / `resync` 方針未整理。
- 本番Webhook/secret切り替えレビュー未完了。
- 本番初回投稿手順未レビュー。

この工程ではdocs設計のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16F/G Discord同期DB更新連携 IO draft
M-14E-16D/EのIO設計を踏まえ、CHECK許容値確認用SELECT-only SQLと専用RPC apply draftを作成した。この工程ではSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord送信は行わない。

SQL draft:

- `029_discord_sync_check_values_select_only.sql`: `discord_sync_status` / `discord_last_action` のCHECK定義、関連カラム、RPC signature、EXECUTE、RLS/policyを単一結果表で読むSELECT-only preflight。
- `030_discord_sync_rpc_apply_draft.sql`: 専用RPC案の未実行apply draft。029結果でCHECK許容値を確認するまで実行しない。

Edge Functionからの将来IO順:

1. request validation: `action` / `dry_run` / 対象依頼書指定を検証する。
2. user auth: Authorizationのユーザー文脈を確認する。JWT本体はログやレスポンスへ出さない。
3. target session fetch: 投稿本文生成に必要な公開情報を取得する。raw内部IDや個人情報を返さない。
4. create二重投稿防止guard: `dry_run = false` かつ `action = create` の場合だけ、専用RPCで既存外部投稿識別子の有無を確認する。
5. message build: `dry_run = true` と実送信で同じ本文生成を使う。
6. Discord send: `dry_run = false` のみ。Webhook URLはsecretから参照し、ログやレスポンスへ出さない。
7. DB sync success update: Discord送信成功後に専用RPCで外部投稿識別子相当と同期状態を保存する。
8. partial failure handling: Discord送信成功後にDB更新が失敗した場合、送信済みとDB更新失敗を分けて返し、同じcreate再実行を禁止する。
9. sanitized response: 外部投稿識別子実値、投稿URL実値、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値を返さない。

RPC IO案:

- `check_discord_session_post_create_ready(text)`
  - 入力: 対象依頼書ID相当。
  - 出力: `can_send`、現在の同期状態、既存投稿有無のboolean。
  - エラー: 未ログイン、権限なし、対象なし、既存投稿ありを一般化して返す。
  - DB更新なし。
- `record_discord_session_post_create_success(text, text, text, text, text)`
  - 入力: 対象依頼書ID相当、外部投稿識別子相当、投稿先相当、スレッド相当、投稿URL相当。
  - 出力: 同期状態、最終action、同期成功時刻、外部投稿識別子を保存したかのboolean。
  - DB更新: Discord送信成功後のみ。
  - 実値IDやURLはレスポンスへ返さない。
- `record_discord_session_post_create_failure(text, text)`
  - 入力: 対象依頼書ID相当、一般化エラーコード。
  - 出力: 同期状態、最終action、更新時刻。
  - 生レスポンスやsecret、外部投稿識別子実値は保存しない。

`dry_run = true` IO:

- guard RPCを呼ばない。
- Discord送信しない。
- DB更新しない。
- message previewと予定情報だけを返す。

`dry_run = false` IO:

- `action = create` のみ初期対象。
- guard RPCで既存投稿ありならDiscord送信前に拒否。
- Discord送信成功後、success記録RPCを呼ぶ。
- DB更新失敗時はpartial failureとして扱い、再実行禁止を明示する。

残るIO論点:

- pre-send guardだけでは同時実行を完全に防げないため、将来の予約状態更新またはより強いDB側排他を検討する。
- CHECK許容値が030 draftの想定と違う場合、RPC draftの状態値を修正する。
- `update` / `close` / `delete` / `resync` は今回のRPC draftでは未実装とし、後続のaction拡張バッチで扱う。

## M-14E-16H 029結果反映後のRPC IOレビュー
ユーザー手元で `029_discord_sync_check_values_select_only.sql` をSQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行した。エラーなしで結果グリッドが表示された。同じSQLの再実行はしていない。`030_discord_sync_rpc_apply_draft.sql` は未実行のapply draftであり、この工程ではDB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信を行わない。

029で確認できたIO前提:

- `public.sessions` は存在し、core column summaryは `15/15 present`。
- `session_tool` は存在する。
- Discord同期系カラムは `9/9 present`。
- `discord_message_id` / `discord_channel_id` / `discord_thread_id` / `discord_post_url` / `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` が確認済み。
- `discord_sync_status` は `text` / nullable YES / defaultあり。
- `discord_last_action` は `text` / nullable YES / default NULL。
- `create_session_post` / `update_session_post` / `delete_session_post` は存在し、security/search_path/EXECUTE権限は確認上OK。
- `sessions` / `user_roles` はRLS enabled。

CHECK値のIO注意:

- `sessions_discord_last_action_check` と `sessions_discord_sync_status_check` は確認できた。
- ただし、結果表示の横幅都合で許容値配列の全体は完全には読めていない。
- この時点では030 draft内で使う `posted` / `failed` / `create` が既存CHECKと一致するか未確定だった。
- M-14E-16IでCHECK値を確定し、`posted` / `failed` / `create` はCHECK内であることを確認済み。ただし030はRPC apply前レビューゲート完了まで実行しない。

030 apply draftのIO役割:

- `check_discord_session_post_create_ready(text)`
  - `dry_run = false` かつ `action = create` の送信前guard。
  - 既存外部投稿識別子がある場合は送信前に拒否する。
  - DB更新なし。
- `record_discord_session_post_create_success(text, text, text, text, text)`
  - Discord送信成功後のDB更新候補。
  - 外部投稿識別子相当を保存するが、実値をレスポンスへ返さない。
  - DB側でも既存識別子なしを確認し、二重投稿防止を補強する。
- `record_discord_session_post_create_failure(text, text)`
  - Discord送信失敗時の一般化エラー記録候補。
  - 生レスポンス、Webhook URL、認証情報、外部投稿識別子実値は保存しない。

Edge Function IO順:

1. request validation。
2. user auth。
3. target session fetch。
4. create guard RPC。
5. message build。
6. Discord send。
7. success記録RPC。
8. failure記録RPCまたはpartial failure handling。
9. sanitized response。

`dry_run = true` はmessage previewまでで、guard RPC、Discord送信、DB更新を行わない。`dry_run = false` のcreateのみ、guard、Discord送信、成功記録RPCへ進む。Discord送信成功後にDB更新が失敗した場合は、Discord送信済みとDB更新失敗を分けて返し、同じcreate再実行を禁止する。

次工程IO:

- RPC apply前レビューゲートでCHECK許容値と030の状態値を照合する。
- RPC applyゲートで専用RPCを適用するか判断する。
- Edge Function実装バッチで専用RPC呼び出しとsanitized responseを実装する。
- deployゲート、まとめQAバッチ、本番切替前レビューゲート、本番切替ゲートへ進む。

## M-14E-16I CHECK値確定後のRPC IO整合
追加のCHECK値展開SELECT-onlyをユーザー手元で1回だけ実行し、SQL Editorではエラーなしで結果グリッドが表示された。同じSELECTは再実行していない。これによりM-14E-16H時点のCHECK値未確定扱いを更新する。この工程でCodexはSQL Editor実行、DB/RPC変更、SQL apply、030 SQL実行、Edge Functionコード変更、deploy、Discord追加実送信を行っていない。

確定したCHECK値:

- `discord_last_action`: `close` / `create` / `delete` / `resync` / `update`。
- `discord_sync_status`: `failed` / `not_requested` / `pending` / `posted` / `skipped`。
- `discord_last_action` は `text` / nullable YES / default NULL。
- `discord_sync_status` は `text` / nullable NO / default `not_requested`。

030 IO整合:

- create成功記録は `posted` + `create` を使うためCHECK内。
- create失敗記録は `failed` + `create` を使うためCHECK内。
- 初期/未送信は既存defaultの `not_requested` を使う。
- `pending` は処理中や将来キュー化候補、`skipped` は同期対象外候補として残る。
- `synced` / `not_synced` などCHECK外の状態値は030の実行ロジックに使わない。
- 030はapply draftのまま未実行で、RPC apply前レビューゲート完了までSQL Editorへ貼らない。

Edge FunctionからのIO順は、request validation、user auth、target session fetch、create guard RPC、message build、Discord send、success記録RPC、failure記録RPCまたはpartial failure handling、sanitized responseとする。`dry_run = true` ではDB更新なし。`dry_run = false` かつDiscord送信成功後のみsuccess記録RPCを呼ぶ。DB更新失敗時は同じcreate再実行を禁止し、manual repair/resyncを後続化する。

## M-14E-16J RPC apply前レビュー後のIO計画
`030_discord_sync_rpc_apply_draft.sql` をRPC apply前レビューゲートとして確認した。030は未実行apply draftのままであり、この工程ではSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信を行わない。

RPC IOレビュー:

- create guard RPCは、`dry_run = false` かつ `action = create` の送信前に呼ぶ。既存 `discord_message_id` があればDiscord送信前に拒否する。
- success記録RPCは、Discord送信成功後にだけ呼ぶ。`posted` + `create` を保存し、外部投稿識別子実値や投稿URL全文をレスポンスへ返さない。
- failure記録RPCは、Discord送信失敗時にだけ呼ぶ。`failed` + `create` と一般化エラーを保存する。
- failure記録RPCは、既存外部投稿識別子がある行を `failed` に上書きしないよう030 draft上で補強した。
- `dry_run = true` ではguard RPC、Discord送信、DB更新を呼ばない。

partial failure IO:

- Discord送信成功後にsuccess記録RPCが失敗した場合、Discord投稿は既に発生しているため同じcreate再実行を禁止する。
- レスポンスは `discord_send` 成功と `db_update` 失敗を分離する。
- top-level `ok` は再実行抑止を優先してfalse寄りに扱う案を維持する。
- repair/resync/手動照合は後続工程で扱う。

apply後SELECT-only確認候補:

- 3RPCの存在とsignature。
- `security_definer`。
- `search_path`。
- EXECUTE権限: authenticated可、anon / PUBLIC不可。
- 既存create/update/delete session post RPCに意図しない影響がないこと。
- Discord同期系カラムが残っていること。
- RLS enabled維持。
- `updates.json` 差分なし。

SQL applyゲートでは、貼り付け範囲欠落、CHECK外値、secret/URL/ID実値混入、SQL Editorエラー、予期しない警告があれば停止する。

## M-14E-16K SQL apply後のDB更新連携IO実装
ユーザー手元のSQL applyゲートで030を実行し、対象RPC 3本の作成、`security_definer = true`、`has_search_path = true` を確認した。SQL Editor再実行はしていない。この工程ではEdge Functionコード変更とdocs記録のみを行い、Edge Function deploy、Discord追加実送信、DB/RPC追加変更、secret設定/切替は行わない。

実装したIO:

- `dry_run = true`
  - 従来どおりmessage previewと予定情報だけを返す。
  - create guard RPC、success記録RPC、failure記録RPCは呼ばない。
  - DB更新なし、Discord送信なし。
- `dry_run = false` + `action = create`
  - 送信前に `check_discord_session_post_create_ready` を呼ぶ。
  - 既存外部投稿識別子がある場合はDiscord送信前に拒否する。
  - Discord送信成功後に `record_discord_session_post_create_success` を呼ぶ。
  - Discord送信失敗時は `record_discord_session_post_create_failure` を可能な範囲で呼ぶ。
  - success記録RPCが失敗した場合はpartial failureとして返し、同じcreate再実行禁止を一般化warningに含める。

レスポンスIO:

- `dry_run = false` では `message_preview` 本文全文を返さない。
- `discord_send` は `posted` / `failed` / `not_sent` などの一般化状態と、message referenceの有無だけを返す。
- `db_update` は `success`、`reason`、`status`、`external_post_identifier_saved` などの一般化情報だけを返す。
- Discord message id実値、post URL全文、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値は返さない。
- console出力は追加しない。

残るIOリスク:

- 送信前guardとsuccess記録RPCの条件更新でDB記録の二重化は抑止するが、同時実行でDiscord送信自体が二重化する理論上のリスクは残る。
- Discord送信成功後にDB記録失敗した場合はmanual repair/resyncが必要になる。
- deploy後の最初の確認は `dry_run = true` とし、DB更新なしとDiscord投稿なしを確認する。

## M-14E-16L deploy後 dry_run=true IO確認
DB更新連携入りの `sync-session-post-to-discord` はユーザー手元でdeploy済み。Codex側ではdeploy、追加dry-run、Discord送信、SQL Editor実行、DB/RPC追加変更、secret切替を行っていない。

deploy IO結果:

- deployは成功扱い。終了コードは0。
- WARNING表示はあったが、認証問題ではない。
- project linkに関するヒントは表示された。
- `deno.lock` / `supabase/.temp` は生成物として掃除済み。
- deploy後の作業ツリーはclean。
- Deno構文確認は成功済み。

post-deploy dry-run入力IO:

- JWT、確認対象、Supabase接続先はユーザー手元で用意し、実値は記録しない。
- requestは `action = create`、`dry_run = true`。
- 対象タイトルは `M14E15P_discord_format_QA_01`。
- `dry_run = false` は実行していない。

post-deploy dry-runレスポンスIO:

- HTTP 200、JSON parse成功。
- レスポンスキーは `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings`。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返ったが本文全文は記録しない。
- `planned_db_update` は返ったが、dry-run上の予定情報でありDB更新ではない。
- previewは冒頭区切り線あり、開催場所ラベルあり、対象タイトルあり、詳細URLなし、詳細ラベルなし、ISO/UTC表記なし。
- Discordテスト用チャンネルへの新規投稿増加なし。

IO判断:

- `dry_run = true` はpreview専用を維持している。
- `dry_run = true` ではDiscord送信なし、DB更新なし、同期状態保存なし。
- DB更新連携入りの `dry_run = false` はまだ未確認。
- 既に投稿済みの `M14E15P_discord_format_QA_01` は次の実送信用に再利用しない。

次のまとめQA IO案:

1. 新しい検証用依頼書を作成する。
2. `dry_run = true` で新フォーマットpreviewを確認する。
3. 独立ゲートで `dry_run = false` の実送信を1回だけ確認する。
4. DB同期状態が保存されたかを、実値IDを記録せず確認する。
5. 同じ対象のcreate再実行が送信前に拒否されるかを別ゲートで確認する。
6. Discord投稿増加数が想定どおりか確認する。

C以降は危険工程を含むため、今回のdocsでは手順案と停止条件だけを整理する。

## M-14E-16M 表示・導線・本文IO改善
DB同期込み `dry_run = false` QAへ進む前に、参加者が見る本文と、公開保存後の導線を改善する。

Discord本文IO:

- `message_preview` / 実送信本文から、概要本文直前の `概要` ラベル行を削除する。
- 概要本文はユーザー入力をそのまま本文として扱い、詳細URLや詳細リンクは入れない。
- ISO/UTC表記、Webhook URL、外部投稿識別子実値、投稿先実値は本文に含めない。
- `dry_run = true` と `dry_run = false` は同じ本文生成処理を使う。
- 反映にはEdge Function deployが必要だが、この工程ではdeployしない。

フロント保存後IO:

- 作成RPC成功後、返却値から詳細画面用IDを解決でき、保存payloadが公開かつ非draftなら詳細画面へ遷移する。
- 編集RPC成功後も同条件で詳細画面へ遷移する。
- 非公開保存、下書き保存、ID解決不可の場合は既存の画面内結果表示と管理一覧更新を維持する。
- raw user_id、email、token、認証情報は表示しない。

概要表示IO:

- 詳細表示の概要見出しは非表示化し、本文だけを表示する。
- 本文はescape済み文字列として出力し、HTMLとして解釈しない。
- CSSで `white-space: pre-wrap` を指定し、改行と空行を保持する。

後続IO:

- GitHub Pages反映後にフロント手動QAを行う。
- Edge Function deploy後に `dry_run = true` previewで本文差分を確認する。
- `dry_run = false` 実送信、DB同期状態保存、二重投稿防止実動確認は独立ゲートで扱う。

## M-14E-16N DB sync real-send IO verification
DB更新連携入りEdge Function deploy後、ユーザー手元で新しい検証用依頼書 `M14E16_sync_db_QA_01` を対象に `create` / `dry_run = false` を1回だけ実行し、Discord送信とDB同期状態保存のIOを確認した。Codex側では実行操作を行わず、結果記録のみを行う。同じ実送信コマンドは再実行禁止。

request / response IO:

- requestは `action = create` / `dry_run = false`。
- HTTP 200、JSON parse成功。
- response keysは `ok` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- `ok = true`、`dry_run = false`、`action = create`。
- `discord_send` と `db_update` が返り、`db_update.success = true` 相当を確認した。
- `message_preview` は返らない。本文全文をレスポンス/docsへ残さない方針を維持。
- Discord message id実値、post URL全文、Webhook URL、JWT、対象session id実値、Supabase URL全文はレスポンス記録やdocsへ出さない。

Discord output:

- テスト用チャンネルに新規投稿1件。
- 投稿タイトルは対象検証用依頼書相当。
- 冒頭区切り線、開催場所、概要本文改行が反映された。
- `概要` ラベル、詳細URL、詳細リンク、ISO/UTC表記はない。
- 本番募集チャンネル投稿なし。

DB sync output:

- `discord_message_id` 相当: saved。
- `discord_channel_id` 相当: saved。
- `discord_post_url` 相当: not saved。
- `discord_sync_status`: `posted`。
- `discord_last_action`: `create`。
- `discord_synced_at` 相当: present。
- `discord_sync_error`: empty。

IO判断:

- Discord送信成功後のsuccess記録RPC呼び出しにより、二重投稿防止の主軸になる外部投稿識別子保存は成功した。
- `discord_post_url` 未保存は、現在のDB同期成功判定では非致命。投稿リンク導線が必要になる管理UIやrepair/resync工程で補強する。
- `dry_run = false` 実送信済み対象の再実行は禁止。二重投稿防止の実動確認は独立ゲートで、送信前guardの拒否とDiscord投稿増加なしを確認する。

二重投稿防止確認IO案:

1. 対象が投稿済み検証用依頼書であることを実値なしで確認する。
2. DB上で外部投稿識別子保存済みを確認する。
3. `action = create` / `dry_run = false` を別ゲートで1回だけ確認する。
4. 期待値は送信前guard拒否、Discord投稿増加なし、一般化エラーのみ。
5. Discord message id実値、post URL全文、session id実値、Webhook URL、JWTは記録しない。

停止条件:

- 対象不一致、外部投稿識別子未確認、認証/接続準備不備、テスト用チャンネル未確認、本番投稿疑い、不明エラー、確認コマンドと送信コマンド未分離。

## M-14E-16O Double-post guard IO verification
DB同期込み実送信済みの `M14E16_sync_db_QA_01` を対象に、ユーザー手元で `create` / `dry_run = false` を1回だけ実行し、送信前guardの拒否IOを確認した。Codex側では実行操作を行わず、結果記録のみを行う。同じ確認コマンドは再実行禁止。

guard request / response IO:

- requestは `action = create` / `dry_run = false`。
- 期待値は、外部投稿識別子保存済みの対象なのでDiscord送信前に拒否すること。
- HTTP 409、JSON parse成功。
- response keysは `ok` / `error_code` / `message` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- `ok = false`、`dry_run = false`、`action = create`。
- `message_preview` は返らない。
- JWT、対象session id実値、Supabase URL全文、Discord message id実値、post URL全文、Webhook URLは記録しない。

guard output:

- Discordテスト用チャンネルに新規投稿増加なし。
- 本番募集チャンネル投稿なし。
- `discord_send` / `db_update` はレスポンスキーとして存在したが、HTTP 409 / `ok = false` のため、実送信成功やDB更新成功を示すものとしては扱わない。
- 判定は送信前拒否、`message_preview` なし、Discord投稿増加なしを中心に行う。

IO判断:

- 外部投稿識別子保存済み対象の `create` 再実行はguardで拒否された。
- Discord投稿増加なしのため、二重投稿防止の基本IOは確認済み。
- 本番切替は、`discord_post_url` 保存補強、update/resync方針、管理UI同期状態表示、repair/resync導線、本番secret切替レビュー、本番初回投稿手順レビューが揃うまで停止する。

## M-14E-16P post URL output and follow-up IO
`discord_post_url` 相当が未保存だった原因をEdge Functionコード上で確認した。この工程では、低リスクなコード補強とIO設計整理のみを行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Function deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替は行わない。

post URL IO原因:

- success記録RPCへ `p_discord_post_url` を渡すIOは存在していた。
- Webhook送信成功結果の `postUrl` が常に `null` だったため、DB側にURL相当が保存されなかった。
- message id相当とchannel id相当は取得済みで、外部投稿識別子保存と二重投稿防止には影響しない。

post URL IO補強:

- Webhookレスポンスからmessage id相当、channel id相当、guild/server id相当を取得する。
- 3値がsnowflake相当の場合だけ、DB保存用の投稿URL相当を生成する。
- guild/server id相当が得られない場合は `null` のままにして、無理に不正確なURLを保存しない。
- 生成した投稿URL相当はsuccess記録RPCへ渡すだけで、レスポンス、docs、consoleへ全文やID実値を出さない。
- `dry_run = true` IOには影響しない。
- Discord本文生成IOは変更しない。

update/resync/repair IO:

- `update`: `discord_message_id` 相当がある依頼書だけ、既存投稿本文を編集する。
- `resync`: GM/admin向けの再同期操作候補。DB状態とDiscord投稿状態を再照合する。
- `repair`: Discord送信成功後DB更新失敗などの部分失敗を補正する手動導線候補。
- `close`: 募集終了や締切状態を既存投稿へ反映する。
- `delete`: 投稿削除または削除済み扱いへの更新。完全削除前の順序は別レビュー。
- これらはcreate安定化後の後続IOに残す。

GM/admin同期状態表示IO:

- session-detailのGM/admin管理ブロック内に、同期状態表示を追加する案を第一候補にする。
- 表示候補は、未同期、投稿済み、同期失敗、確認が必要。
- 生のmessage id、channel id、thread id、post URL全文は表示しない。
- 失敗時は一般化エラーだけを表示する。
- resync/repairボタンやリンク表示は別レビュー。

本番切替前IOチェック:

- テスト用チャンネルcreate成功、DB更新成功、二重投稿防止成功。
- `discord_post_url` 未保存の扱いを了承、または補強QA済み。
- update/resync/repair方針、GM/admin同期状態表示方針、本番secret切替手順、本番初回投稿手順がdocs化済み。
- 本番投稿前に `dry_run = true` を確認する。
- 本番投稿は独立ゲートで扱う。

## M-14E-16Q post URL補強deploy後dry-run IO確認
`9420c53` の `sync-session-post-to-discord` はユーザー手元でdeploy済み。Codex側ではdeploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替を行っていない。

deploy IO:

- deploy対象commitは `9420c53`。
- deploy前のgit状態はclean。
- deploy前の `deno check` は成功。
- deployは終了コード0、成功表示あり。
- deploy時にWARNING表示はあったが、認証問題ではない。
- project linkに関する表示は確認対象として扱う。
- deploy後のgit状態はclean。

post-deploy dry-run IO:

- 対象は `M14E16_sync_db_QA_01`。
- requestは `action = create` / `dry_run = true`。
- JWT、対象session id、Supabase URL全文はユーザー手元だけで扱う。
- HTTP 200、JSON parse成功。
- response keysは `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings`。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返るが本文全文は記録しない。
- `概要` ラベルなし、詳細URLなし、対象タイトルあり、ISO/UTC表記なし。
- Discordテスト用チャンネルへの投稿増加なし。

IO判断:

- `dry_run = true` はpreview専用を維持している。
- `概要` ラベル削除はEdge Function側に反映済み。
- `discord_post_url` 補強後の保存成否は、別ゲートのテスト用チャンネル実送信とSELECT-only確認で判断する。

post URL保存補強QA IO案:

1. 新規検証用依頼書 `M14E16_post_url_QA_01` を作成する。
2. session-detailで対象を確認する。
3. `dry_run = true` previewを確認する。
4. 独立ゲートで `dry_run = false` 実送信を1回だけ行う。
5. Discordテスト用チャンネルに新規投稿が1件だけ増えたことを確認する。
6. SELECT-onlyでDB同期状態を確認し、`discord_post_url` 相当の保存有無を見る。

停止条件:

- 対象不一致、認証/対象/Supabase接続先準備不備、dry-run失敗、本文への詳細URL/ISO/UTC/`概要` ラベル混入、テスト用チャンネル未確認、本番投稿疑い、実値IDやURL全文の記録が必要になりそうな場合、不明エラー、同一実送信コマンド再実行。

## M-14E-16R post URL保存補強QA IO結果
`M14E16_post_url_QA_01` を対象に、ユーザー手元でpost URL保存補強QAを実施した。この記録工程では、Codex側でSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替を行わない。

request / Discord IO:

- `dry_run = true` preview確認は成功済み。
- `dry_run = false` 実送信は1回だけ実行済み。同じコマンドは再実行しない。
- Discordテスト用チャンネルに新規投稿が1件増えた。
- 投稿は対象タイトル相当、`概要` ラベルなし、改行保持、詳細URLなし、ISO/UTC表記なし。
- 本番募集チャンネル投稿なし。

DB sync IO:

- 外部投稿識別子相当は保存済み。
- 投稿先チャンネル識別子相当は保存済み。
- thread id相当は未使用または空。
- post URL相当は未保存。
- sync statusは `posted`。
- last actionは `create`。
- synced at相当は保存済み。
- sync error相当は空。

IO判断:

- create投稿、DB同期状態保存、二重投稿防止の中核に必要な保存は成功。
- `discord_post_url` 相当のみ未保存だが、post URL全文を不正確に組み立てて保存しない現在の挙動は安全側。
- post URL保存を本番createのブロッカーにするかは別判断とする。
- 最小本番投入では、message id相当とchannel id相当が保存されているため、post URL未保存を非致命として許容する案を第一候補にする。

本番前IO残課題:

- 高: 本番切替前レビュー、本番Webhook secret切替ゲート、本番向け `dry_run = true`、本番初回投稿ゲート、post URL未保存許容判断。
- 中: GM/admin同期状態表示UI、update/resync/repair方針、投稿済み依頼書resync導線、失敗時一般化エラー表示、本番投稿後DB確認手順。
- 低: post URLリンク表示、close/delete/update実装、同期履歴表示、詳細監査ログ。

## M-14E-16S GM/admin Discord同期状態UI IO
session-detailのGM/admin管理ブロック内に、Discord同期状態を確認する折りたたみUIを追加した。この工程ではフロント側IOの追加のみを行い、Edge Function、DB/RPC、SQL、Discord送信は変更しない。

入力IO:

- Supabase由来session取得で、同期状態、最終操作、最終同期日時、同期エラー、post URL保存有無を表示用に取得する。
- `discord_sync_error` は有無へ丸める。
- `discord_post_url` は保存有無へ丸める。
- message id、channel id、thread idは取得・表示対象にしない。

表示IO:

- 管理権限確認前は同期状態パネルを空のまま非表示にする。
- GM本人またはadminとして管理権限が確認できた場合だけ、管理ブロック内に同期状態パネルを表示する。
- summaryは `Discord同期：投稿済み` などの1行表示。
- 展開時は同期状態、最終操作、最終同期日時、同期エラー有無、投稿リンク保存有無を表示する。
- 静的JSON由来、未ログイン、権限なし、権限確認失敗では表示しない。

出力しない情報:

- Discord message id実値、channel id実値、thread id実値、post URL全文、raw session id、raw user id、email、token、selected character id、application id。
- `discord_sync_error` の生テキスト。エラーがある場合は一般化表示だけにする。

後続IO:

- post URL全文リンク表示は別レビュー。
- resync/repair/update/close/deleteボタンは未実装。
- 本番切替前に、公開サイト反映後のGM/admin手動QAで表示条件と表示ラベルを確認する。

## M-14E-16T Production gate review IO plan
公開サイト反映後のGM/admin Discord同期状態UIを軽量QA済みとして扱い、本番切替に向けたIOゲートを整理する。この工程では実行IOを行わず、docs記録のみを行う。

GM/admin status panel QA:

- 折りたたみ式の `Discord同期` パネルがGM/admin管理ブロック内に表示される。
- GM本人またはadmin確認後だけ表示される。
- summaryは投稿済み相当。
- 詳細には同期状態、最終操作、最終同期日時、同期エラーなし、投稿リンク保存なしが表示される。
- Discord message id、channel id、thread id、post URL全文、raw session id、raw user id、email、token、selected character id、application idは出力されない。

production secret switch gate:

- 本番Webhook secret切替は独立ゲート。
- secret実値はチャット、docs、GitHub、consoleへ出さない。
- 設定後も本番投稿は行わず、本番向け `dry_run = true` 確認へ進む。

production `dry_run = true` gate:

- 本番Webhook設定後に独立ゲートで行う。
- Discord投稿が増えないことを確認する。
- message preview本文全文は記録しない。
- 詳細URL、ISO/UTC表記、`概要` ラベルが混入していないことを見る。

first production send gate:

- 本番向け `dry_run = true` 確認済みの依頼書だけを対象にする。
- 確認コマンドと送信コマンドを分離する。
- `dry_run = false` は1回だけ。
- 本番募集チャンネルに1件だけ投稿されることを確認する。
- 投稿後、SELECT-onlyでDB同期状態を確認する。
- GM/admin同期状態UIで投稿済み表示を確認する。

production gate blockers:

- git dirty、最新commit不一致、GM/admin同期状態UI未反映、テスト用create/DB同期/二重投稿防止記録未確認、本番Webhook secret未準備、本番投稿対象未確定、本番向け `dry_run = true` 未確認、本番募集チャンネル未目視確認、post URL未保存を許容しない判断、不明エラー。

post URL未保存は、message id相当、channel id相当、`posted` / `create`、同期時刻、同期エラー空、二重投稿防止が確認済みであるため、最小本番create投入のブロッカーにしない案を第一候補にする。

## M-14E-16U Production webhook secret switch result
本番Webhook secret切替はユーザー手元で完了済み。この工程では結果記録のみを行い、Codex側ではsecret実値の確認、表示、再入力、再設定を行わない。

IO記録:

- secret名は `DISCORD_SESSION_POST_WEBHOOK_URL`。
- 本番募集チャンネル向けWebhookへの切替はSupabase Dashboard側で実施済み。
- Webhook URL実値はチャット、docs、GitHub、consoleへ出していない。
- Codex側ではsecret実値を扱っていない。
- `dry_run = true` / `dry_run = false` は未実行。
- Discord本番投稿なし。
- Edge Function deployなし。
- SQL Editor実行なし。
- DB/RPC変更なし。

次IO:

- 本番向け `dry_run = true` 確認ゲート。
- Discord投稿増加なし、preview形式、secret非露出を確認する。
- message preview本文全文、JWT、対象session id、Supabase URL全文、Webhook URL、Discord message id、channel id、post URL全文は記録しない。

## M-14E-16V First production Discord post IO result
本番Webhook secret切替後、指定タイトル `【連携確認】依頼書投稿テスト` を対象に、本番初回投稿IOを実施した。対象ID、JWT、Supabase URL全文、Discord message id、channel id、post URL全文、message preview本文全文はIO記録に残さない。

target preparation:

- 開始commitは `f2bd4d0 Record production Discord webhook switch`、git状態はclean。
- 指定タイトルの既存対象は0件だったため、既存アプリ用RPC経由で公開/非draftの依頼書を1件作成した。
- `open` は初期statusとして拒否されたため、DB変更なしで停止し、既存仕様に合わせて `recruiting` で作成した。
- SQL Editor、直接insert、DBスキーマ変更、RPC定義変更は行っていない。
- 作成後、指定タイトルの対象が1件だけであることを確認した。

dry-run IO:

- `create / dry_run = true` を1回だけ実行。
- HTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- response keysは `ok,dry_run,action,sync_target,message_preview,planned_db_update,warnings`。
- `message_preview` は返ったが本文全文は記録しない。
- warning countは0。
- Discord投稿なし、DB同期識別子保存なし、DB同期更新なし。
- 本番依頼書チャンネルに投稿が増えていないことをユーザーが目視確認し、`dry_run = false` 1回実行を許可した。

real-send IO:

- `create / dry_run = false` はユーザー許可後に1回だけ実行。再実行禁止。
- HTTP 200、JSON parse成功、`ok = true`、`dry_run = false`、`action = create`。
- response keysは `ok,dry_run,action,sync_target,discord_send,db_update,warnings`。
- `discord_send`、`db_update`、`warnings` は返った。
- `db_update.success = true` として扱える。
- warning countは0。
- `message_preview` は返っていない。
- Discord message id、channel id、post URL全文はレスポンス/console/docsへ出さない。

DB sync readback:

- 読み取り専用の状態確認でboolean/status形式だけを確認した。SQL Editor再実行やDB/RPC定義変更は行っていない。
- `discord_message_id_saved = true`。
- `discord_channel_id_saved = true`。
- `discord_sync_status = posted`。
- `discord_last_action = create`。
- `discord_synced_at_present = true`。
- `discord_sync_error_empty = true`。
- `discord_post_url_saved = false` は既知の非致命制約として扱う。

visual confirmation checklist:

- 本番依頼書チャンネルに1件だけ投稿されたこと。
- タイトルが対象タイトルと一致すること。
- `概要` ラベルなし。
- 概要本文の改行保持。
- 詳細URL/詳細リンクなし。
- ISO/UTC表記なし。

follow-up IO:

- ユーザー目視確認結果を必要に応じて追記する。
- GM/admin同期状態UIで投稿済み表示を確認する。
- `update` / `resync` / `repair` IO設計と実装へ進む。
- post URL未保存は本番create最小投入のブロッカーにしないが、リンク表示やguild id補強は後続IOに残す。

このIO記録工程では、secret設定/切替、Webhook URL実値確認、Edge Function deploy、SQL Editor実行、DB/RPC定義変更、`dry_run = false` の複数回実行、Discord追加投稿、`updates.json` 変更は行わない。

## M-14E-17 Update/delete sync preparation IO
本番初回create投稿の成功を基準に、Discord同期IOを `update` / `delete` / `close` / `resync` / `repair` へ広げる準備を行う。この工程では設計、未実行SQL draft、Edge Function静的実装のみを扱い、SQL Editor、SQL apply、DB/RPC実変更、Edge Function deploy、dry-run/real-send、Discord投稿/編集/削除、secret設定/切替は行わない。

current production baseline:

- latest commit: `801c561 Record first production Discord post`。
- production `create / dry_run = false` は1回だけ成功済み。
- DB sync readbackは、message id相当保存あり、channel id相当保存あり、`discord_sync_status = posted`、`discord_last_action = create`、synced atあり、sync error空。
- `discord_post_url` 未保存は既知の非致命制約。update/deleteではmessage id相当とWebhook secretを優先して使う。
- production channel visual checksは、1件投稿、タイトル一致、`概要` ラベルなし、改行保持、詳細URLなし、ISO/UTCなしを確認項目にする。未確認が残る場合は目視確認待ちとして扱う。

update IO:

- targetはSupabase由来で外部投稿識別子が保存済みの依頼書。
- request `action = update` は既存Discord投稿を現在の依頼書本文でPATCHする。
- external post referenceがなければ新規投稿を増やさない。
- success recordは `discord_sync_status = posted`、`discord_last_action = update`、synced at更新、sync error clear。
- failure recordは `discord_sync_status = failed`、`discord_last_action = update`、一般化error codeのみ。

delete IO:

- 投稿済み依頼書削除は、Discord message DELETEを先に行い、その後に既存 `delete_session_post` RPCを呼ぶ案を第一候補にする。
- Discord delete失敗時はDB deleteへ進まない。
- DB delete成功後はsessions行が消えるため、success状態を同じ行へ永続保存できない。現行MVPでは永続監査ログなしの制約として扱う。
- Discord delete成功後にDB delete失敗した場合は、DB上の依頼書が残るため再削除可能。ただしDiscord側は削除済みなので手動確認を必須にする。

close / resync / repair IO:

- `close` は既存投稿を募集終了表示へ更新するIOとして扱う。physical deleteではない。
- `resync` は外部投稿識別子がある場合update相当。識別子がない場合のcreate相当再実行は手動確認必須。
- `repair` はpartial failure修復の後続導線。

SQL/RPC IO draft:

- `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` を追加。
- draftはapply draftだが未実行。SQL Editorへ貼らない。
- 追加候補RPCはupdate guard、update success、update failure、delete guard、delete failure。
- create専用RPC、既存 `update_session_post`、既存 `delete_session_post` は壊さない。
- CHECK値は既存のstatus/action許容値に整合。

Edge Function IO preparation:

- `action = update` / `action = delete` のreal-send経路を追加したが、deployは行わない。
- `dry_run = true` はpreviewのみで、Discord送信/編集/削除、DB更新、RPC記録を行わない。
- update real-sendは guard RPC -> message build -> Discord PATCH -> success/failure RPC。
- delete real-sendは guard RPC -> Discord DELETE -> existing `delete_session_post` RPC。
- responseにはmessage id実値、channel id実値、post URL全文、Webhook URL、Discord API raw bodyを出さない。
- DB direct writeは追加せず、DB操作はRPC経由に限定。
- 031 apply前にdeployしない。deploy前にRPC apply gateとpost-apply verificationが必要。

frontend IO plan:

- 編集保存後の自動update呼び出しは、backend update deploy後に有効化する。
- 削除時は、投稿済みならEdge Function delete orchestration、未投稿なら既存delete RPCを使う案を比較する。
- GM/admin同期パネルには手動反映/削除ボタンの余地を残す。

next gates:

- 031 RPC apply review gate。
- 031 RPC apply gate。
- Edge Function deploy review gate。
- Edge Function deploy gate。
- update/delete dry-run QA gate。
- update/delete real-send QA gate。
- frontend auto-sync implementation batch。
## M-14E-17 SQL apply gate IO attempt result

`031_discord_update_delete_rpc_apply_draft.sql` のIO apply gateとして、Codex側で安全に使える実行経路を確認した。

IO precheck:

- git stateはclean。
- latest commitは `9cf71a4 Prepare Discord update delete sync`。
- apply対象はrepo内の `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` のみ。
- `DO NOT RUN` / `NOT EXECUTED` / `DO NOT PASTE` の誤爆防止注記を確認した。
- secret、Webhook URL、JWT、DB password、Direct connection string、実ID、URL全文の混入は検出されなかった。
- `DROP TABLE`、`DROP COLUMN`、`TRUNCATE`、`CASCADE` の実行文は検出されなかった。

IO route review:

- Supabase CLIの `db query --linked --file` は確認できた。
- ただしrepo内にlinked project情報がなく、project targetを秘匿値なしで確定できなかった。
- DB passwordやDirect connection stringを扱う経路は採用しない。
- 既存のDB apply用スクリプトは見つからなかった。
- Chrome automationでSQL Editorを操作する経路は、Codex Chrome Extension未導入により利用できなかった。

IO result:

- 安全なSQL apply経路が見つからなかったため、SQL applyは実行していない。
- 031のSQL Editor貼付、CLI apply、psql実行はいずれも行っていない。
- apply後SELECT-only確認は未実施。
- Edge Function deploy、dry-run、real-send、Discord投稿/編集/削除、secret設定/切替は未実施。

Next IO gate:

- 031 apply経路を安全に確定してから、SQL applyを1回だけ実行する。
- apply成功後に、update/delete用5RPCの存在、security definer、search_path、EXECUTE権限、既存create用RPC維持、CHECK値整合をSELECT-onlyで確認する。

## M-14E-17 031 SQL apply IO result

ユーザー手元で `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` をSQL Editorへ貼り付け、1回だけ実行した。

IO result:

- SQL Editor上でエラー表示なし。
- 同一SQLの再実行なし。
- 結果グリッドでupdate/delete同期用RPC 5本を確認。
  - `check_discord_session_post_delete_ready(text)`
  - `check_discord_session_post_update_ready(text)`
  - `record_discord_session_post_delete_failure(text, text)`
  - `record_discord_session_post_update_failure(text, text)`
  - `record_discord_session_post_update_success(text)`
- 表示されている範囲では、5本とも `security_definer = true`、`has_search_path = true`。
- EXECUTE権限の詳細はユーザー提供画像上では未確認。
- EXECUTE権限は、Edge Function deploy後QAでRPC実呼び出しにより確認する。

IO safety:

- Codex側ではSQL Editor再実行、SQL apply再実行、DB/RPC追加変更を行っていない。
- Edge Function deploy、dry-run、real-send、Discord投稿/編集/削除、secret設定/切替は未実施。
- secret、Webhook URL、JWT、session id、project ref、Supabase URL全文、Discord message id、channel id、post URL全文、raw user id、email、token類の実値は記録しない。

Next IO gate:

- Edge Function deployゲート。
- deploy後に、update/delete同期RPCのEXECUTE権限を実呼び出しで確認する。

## M-14E-17 Edge Function deploy IO result

IO precheck:

- git stateはclean。
- latest commitは `36cca94 Record Discord update delete RPC apply success`。
- `deno check` は成功。
- project refはクリップボードからPowerShell環境変数へ読み込み、実値を表示しない方針で扱った。
- project ref実値、Webhook URL、JWT、DB password、Direct connection string、実ID、URL全文は記録していない。

IO deploy result:

- `sync-session-post-to-discord` のEdge Function deployを1回だけ実行した。
- deployは成功した。
- Docker未起動WARNINGは表示されたが、deploy自体は成功。
- `deno.lock` は生成物として削除済み。
- `supabase/.temp` はCLI生成物として削除済み。
- DB側update/delete RPC 5本はユーザー手元SQL Editorで適用済み。

IO not executed:

- `dry_run = true` / `dry_run = false` は未実行。
- Discord投稿、編集、削除は未実行。
- SQL Editor再実行、SQL apply再実行、DB/RPC追加変更は未実施。
- secret設定/切替は未実施。

Next IO gate:

- update/delete本番QAまとめゲート。
- deploy後QAでRPC実呼び出し可否と既存create同期への影響なしを確認する。
