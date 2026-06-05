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
