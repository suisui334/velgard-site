# M-14E-5 Discord同期Edge Function secret管理・dry-run確認手順

## 目的

Discord同期Edge Functionを今後安全にdry-run確認・deploy準備するため、secret管理方針、dry-run確認手順、deploy前チェックリストを整理する。

この文書では実値を扱わない。外部投稿credential、サーバ側高権限credential、認証系の生値、内部識別子はdocs、GitHub、フロント、DB、チャットへ書かない。

## スコープ

対象:

- `supabase/functions/sync-session-post-to-discord/index.ts`
- `dry_run = true` のpreview確認
- `dry_run = false` が拒否されることの確認
- Edge Function側のsecret管理方針
- deploy前に必要な安全チェック

対象外:

- Edge Function deploy
- Discord実送信
- SQL Editor実行
- DB/RPC変更
- フロント実装
- 実credential設定
- commit / push

## secret管理方針

- 外部投稿credentialやサーバ側高権限credentialの実値は、Edge Function側のsecret管理で扱う。
- docs、GitHub、フロント、DB、チャットには実値を書かない。
- secret名候補は一般名としてdocsへ書いてよいが、値・接続文字列・認証文字列は書かない。
- 外部投稿credentialはDBに保存しない。
- フロントは外部投稿先へ直接送信しない。
- app内admin権限はアプリ上の管理権限であり、サーバ側高権限credentialとは別物として扱う。
- ログには外部投稿credential、認証系の生値、外部API応答の生全文を出さない。

## 想定secret名候補

初期dry-runで必要:

| 名前候補 | 用途 | 初期dry-runでの扱い |
| --- | --- | --- |
| `SUPABASE_URL` | Edge FunctionからSupabaseへ接続するためのURL | 必須候補。実値はdocsへ書かない |
| `SUPABASE_ANON_KEY` | 呼び出しユーザーの認証文脈でDB/RPCを読むための公開クライアント鍵 | 必須候補。実値はdocsへ書かない |
| `PUBLIC_SITE_BASE_URL` | message previewに詳細ページURLを作るための公開URL | 任意。未設定なら相対URLpreviewでよい |

実送信・DB状態更新へ進む後続で検討:

| 名前候補 | 用途 | 備考 |
| --- | --- | --- |
| `DISCORD_WEBHOOK_URL` | Webhook方式で投稿する場合の外部投稿先 | 実送信までは未設定でよい |
| `DISCORD_BOT_TOKEN` | Bot方式で投稿・編集・削除相当処理をする場合のcredential | 実送信までは未設定でよい |
| `DISCORD_CHANNEL_ID` | 投稿先を固定する場合の投稿先識別子 | 実送信方式確定後に検討 |
| `SUPABASE_SERVICE_ROLE_KEY` | サーバ側でDB状態更新が必要になった場合の高権限credential候補 | app内admin権限とは別物。使用前に方式レビュー必須 |

初期dry-runではDiscord実送信しないため、Discord系のsecretは必須にしない。

## dry-run確認手順案

### 事前確認

1. 作業ツリーが想定差分だけであることを確認する。
2. Deno / TypeScript構文確認が可能か確認する。
3. `sync-session-post-to-discord/index.ts` に外部送信処理とDB書き込み処理がないことを確認する。
4. secret実値がコード・docs・diffに含まれていないことを確認する。
5. 実在の内部識別子や認証系の生値を手順書へ貼らない。

### deploy前ローカル確認候補

deploy前にローカルでEdge Functionを起動できる環境がある場合のみ行う。

- `dry_run = true` のpayloadだけを使う。
- 認証付きの呼び出しは実値をdocsへ残さず、作業者のローカル環境だけで扱う。
- レスポンスに外部投稿credential、認証系の生値、ユーザー内部識別子、外部投稿参照情報そのものが出ないことを確認する。
- DB更新が発生しないことを、レスポンスの `planned_db_update.will_update = false` とDB状態で確認する。
- Discord実送信が発生しないことを確認する。

### deploy後dry-run確認候補

deploy後の確認はM-14E-6以降で行う。M-14E-5では手順整理のみ。

確認すること:

- `dry_run = true` でpreviewが返る。
- `dry_run = false` で `real_send_not_enabled` が返り、外部送信されない。
- 通常PLは拒否される。
- 作成者GMまたはapp内adminだけがpreviewできる。
- 同期対象外の依頼書では `not_sync_target` が返る。
- レスポンスにsecret実値や内部情報が含まれない。
- DB状態列が変化しない。

## payload例

実IDは使わず、以下はダミー値として扱う。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

`dry_run = false` 拒否確認用:

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": false
}
```

期待:

- `ok = false`
- `error_code = real_send_not_enabled`
- Discord実送信なし
- DB更新なし

## action別dry-run確認

| action | 前提 | 期待結果 |
| --- | --- | --- |
| `create` | 公開かつ同期対象statusの依頼書 | 新規投稿preview、`planned_db_update.will_update = false` |
| `create` | 既存投稿参照情報あり | previewは返るが、更新扱い検討のwarning |
| `update` | 既存投稿参照情報あり | 更新preview |
| `update` | 既存投稿参照情報なし | `missing_post_reference` |
| `close` | 既存投稿参照情報あり | 募集終了・開催終了相当のpreview |
| `close` | 既存投稿参照情報なし | `missing_post_reference` |
| `delete` | 既存投稿参照情報あり | 削除相当処理preview。DB完全削除前に外部投稿側処理が必要というwarning |
| `delete` | 既存投稿参照情報なし | `missing_post_reference` |
| `resync` | 既存投稿参照情報あり | `update` 相当preview |
| `resync` | 既存投稿参照情報なし | `create` 相当preview |

同期対象外状態:

- `visibility != public`
- `status = draft`
- `status = canceled`
- 未対応status

`create` / `update` / `close` / `resync` は同期対象外なら `not_sync_target` を期待する。`delete` は既存投稿参照情報がある場合のみ削除相当処理previewを検討できる。

## deploy前チェックリスト

- Deno / TypeScript構文確認を通す。
- `dry_run = false` が拒否される。
- Discord API送信処理が未接続である。
- DB書き込み処理がない。
- `fetch()` による外部投稿API呼び出しがない。
- `.insert()` / `.update()` / `.delete()` / `.upsert()` がない。
- `console.log` / `console.error` で機微情報や外部API応答全文を出していない。
- secret実値がコード・docs・diffに含まれていない。
- payloadに内部識別子や認証系の生値を渡す前提になっていない。
- レスポンスに外部投稿参照情報そのものを含めない。
- CORS方針を確認する。初期draftの `*` はdry-run確認用とし、実運用前に許可元を絞るか判断する。
- JWT / 認証ヘッダー検証方針を確認する。
- `is_admin()` / `is_session_gm(target_session_id)` によるGM/admin限定が期待どおり動く。
- 通常PL、未ログイン、他GMが拒否される。
- app内admin権限とサーバ側高権限credentialを混同していない。
- 静的JSON由来はDB同期対象外として扱う。

## 後続工程案

1. M-14E-5: secret管理・dry-run確認手順docs整理。
2. M-14E-6: Deno構文確認 / dry-run確認。
3. M-14E-7: deploy手順整理。
4. M-14E-8: deploy実施判断。
5. M-14E-9: GM/admin向け再同期UI。
6. M-14E-10: Discord実送信QA。

## 残した懸念点

- 完全削除前にDiscord側deleteまたは削除相当表示をどう呼ぶか。
- `delete_session_post(text)` 後は既存投稿参照情報を参照できない問題。
- dry-runから実送信へ進める際のDB状態更新経路。
- サーバ側高権限credentialを使う場合の最小権限化とレビュー手順。
- resync専用RPCが未作成であること。
- GM/admin再同期UIをEdge Function直呼びにするか、同期要求RPC経由にするか。
- Discord投稿本文テンプレートとM-15テンプレート機能の接続時期。
- CORS許可元を実運用前にどう絞るか。

## やらないこと

- SQL Editor実行
- DB/RPC変更
- Edge Functionコード変更
- Edge Function deploy
- Discord実送信
- フロント実装
- `updates.json` 変更
- commit / push

## M-14E-6 Deno構文確認 / dry-run確認準備結果

確認結果は `docs/discord-edge-function-dry-run-check-result.md` に分離した。

要約:

- 作業前の作業ツリーはclean。
- 最新commitは `fdbdfd6 Document Discord sync secret and dry run checks`。
- `deno --version` は `deno not found`。
- Deno未導入のため `deno check supabase/functions/sync-session-post-to-discord/index.ts` は未実施。
- Edge Function draftに `fetch(`、DB書き込み系メソッド、`console.` は検出されなかった。
- 関連ファイルにsecret実値らしき文字列は検出されなかった。
- Edge Function起動、dry-run呼び出し、secret実値設定、deploy、Discord実送信は行っていない。

後続では、DenoまたはSupabase Edge Functionのローカル確認環境を用意してから、構文確認と `dry_run = true` のpreview確認へ進む。

## M-14E-6B Deno確認方針

M-14E-6Bでは、Deno構文確認とdry-run実行確認をどの環境で行うかを整理した。詳細は `docs/discord-edge-function-dry-run-check-result.md` のM-14E-6B節に記録する。

方針:

- Deno確認前にdeployへ進まない。
- dry-run実行確認前にDiscord実送信へ進まない。
- secret設定方針を再確認する前に実送信コードへ進まない。
- 確認環境の候補は、ローカルWindows環境でのDeno確認、Supabase CLI環境での確認、CIまたは別環境での確認とする。
- 今回はDeno導入、Supabase CLI導入、Edge Function起動、deploy、Discord実送信、secret実値設定は行わない。

## M-14E-6C ユーザーローカルWindows確認結果

ユーザーのローカルWindows PowerShellでも `deno --version` は認識されず、Deno未導入であることを確認した。詳細は `docs/discord-edge-function-dry-run-check-result.md` のM-14E-6C節に記録する。

方針:

- `deno check` は未実施のまま。
- Deno確認前にdeployへ進まない。
- dry-run実行確認前にDiscord実送信へ進まない。
- 次工程候補は、Deno導入、Supabase CLI環境、CIまたは別環境のいずれかで確認する案をユーザー確認のうえ選ぶこと。

この工程ではDeno導入、Supabase CLI導入、Edge Function起動、deploy、Discord実送信、secret実値設定は行っていない。

## M-14E-6C Deno導入後の確認結果

ユーザーのローカルWindows環境でDeno導入後、`deno --version` と `deno check supabase/functions/sync-session-post-to-discord/index.ts` が成功した。

確認中に `is_session_gm` RPC引数まわりのTypeScript型エラーが出たが、`is_session_gm` 呼び出し専用の薄い型緩和helperで修正済み。Supabase client全体の型を崩さず、作成者GMまたはアプリ内adminのみ許可する権限判定方針は維持している。

現時点でも、`dry_run = true` preview専用、`dry_run = false` 拒否、Discord実送信なし、DB更新なしの方針を維持する。`fetch(`、DB書き込み系メソッド、`console.` は追加していない。

deploy前には、dry-run実レスポンス、拒否応答、ログ安全性、secret実値や内部識別子の非露出を改めて確認する。

この追記ではdocs記録のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、commit / pushは行っていない。

## M-14E-6D dry-run実行確認時の秘匿値管理

dry-run実レスポンス確認では、Supabase CLIのローカルserveを第一候補にする。ただし、Supabase CLI利用可否確認と導入判断は次工程に分ける。

必要になりうる環境情報は、Supabase接続先、呼び出しユーザーの認証文脈、Edge Function実行用の環境変数、確認対象の依頼書ID相当の値。いずれも実値はdocs、GitHub、フロント、DB、チャットへ書かない。

初期dry-runではDiscord実送信しないため、Discord投稿先credentialは原則不要。将来DB状態更新や実送信に進む場合も、アプリ内admin権限とサーバ側高権限credentialを混同せず、方式レビュー後に扱う。

`dry_run = false` は今回実行しない。将来確認する場合も、実送信コードを有効化する前のdraft状態で拒否されることだけを確認する。

この追記ではdocs整理のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6E Supabase CLI利用可否確認結果

`supabase --version` を確認した結果、この環境ではSupabase CLIは認識されなかった。したがって、Supabase CLIローカルserveによるdry-run確認は未実施。

今回、Supabase CLI導入、Edge Function deploy、Discord実送信、`dry_run = false` 実行、秘匿値の実値設定は行っていない。

次工程では、Supabase CLIを導入するか、CLIが使える別環境で確認するかをユーザー確認のうえ選ぶ。いずれの場合も、秘匿値の実値、認証系の生値、内部識別子をdocsやログへ残さない。

## M-14E-6E / 6F npx.cmd経由確認とローカルserve準備

ユーザーのローカルPowerShellでは、Node.js `v24.16.0` が利用可能。PowerShellの `npx` は実行ポリシーで止まるが、`npx.cmd supabase --version` では `2.105.0` を確認できた。

今後PowerShellでSupabase CLIを使う場合は、`npx.cmd` 経由を候補にする。グローバル導入済みCLIではなく、npx経由で利用可能な状態として扱う。

ローカルserve候補:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

この候補は実行前手順として整理するだけで、この工程では実行しない。

ローカルserve時の秘匿値管理:

- Supabase接続先、認証文脈、Edge Function実行用環境変数、確認対象依頼書ID相当の値は、ユーザーの手元だけで扱う。
- 実値はdocs、GitHub、フロント、DB、チャットへ書かない。
- 初期dry-runではDiscord投稿先credentialは原則不要。
- `dry_run = true` のみ確認対象にし、`dry_run = false` は実行しない。
- レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを重点確認する。

この追記ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6H dry-run実行条件と認証文脈

Edge Functionは `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL` を参照する。また、呼び出し時にはBearer形式のAuthorizationヘッダーが必要。

今回の作業環境では、`SUPABASE_URL` / `SUPABASE_ANON_KEY` / `PUBLIC_SITE_BASE_URL` が未設定で、認証文脈も未用意だった。そのため、ローカルserveと `dry_run = true` 呼び出しは実行していない。

認証文脈や環境変数の実値はCodex側で要求しない。次工程で確認する場合も、ユーザー手元の環境変数、ブラウザ、ローカル設定で扱い、docsや報告には実値を書かない。

`dry_run = false` は引き続き実行しない。Discord実送信なし、DB更新なし、レスポンスとログの安全性確認を優先する。

この追記ではdocs整理のみ行い、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6I 手元dry-run時の値の扱い

ユーザー手元でdry-run確認を行う場合、必要値はPowerShell環境変数、ブラウザ、ローカルメモだけで扱う。Codexは実値を要求しない。

必要な名前:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUBLIC_SITE_BASE_URL`
- `Authorization: Bearer <USER_JWT>`
- `<SESSION_ID_FOR_DRY_RUN>`

docsや報告に残すのは上記の名前やプレースホルダーだけにする。初回確認は `create` の `dry_run = true` のみに絞り、`dry_run = false` は実行しない。

手元実行後の結果記録では、成功 / 権限不足 / 同期対象外 / 対象なし等の一般化した結果だけを残す。レスポンスやログに秘匿値の実値、認証系の生値、内部識別子が含まれる場合は、そのまま共有しない。

この追記ではdocs整理のみ行い、ローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-6J ローカルserve不可時の秘匿値管理

ユーザー手元では `npx.cmd supabase --version` とDeno構文確認は成功し、必要環境変数も手元で設定済み。ただし、`npx.cmd supabase functions serve sync-session-post-to-discord` はDocker Desktop / Docker daemonへ接続できず失敗した。

このため、ローカルserveは未実行扱いとし、`dry_run = true` も未実行。Discord実送信なし、DB更新なし、`dry_run = false` 未実行のまま。

Docker Desktopを導入する場合も、秘匿値の実値、認証系の生値、実在する依頼書ID相当の値はユーザー手元だけで扱い、docsや報告へ書かない。Docker導入を保留する場合は、deploy前手順整理と安全レビューへ進む。

この追記ではdocs記録のみ行い、Docker Desktop導入、Supabase CLI追加導入、ローカルserve再実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-7 deploy後dry-run確認時のsecret管理

Docker未導入によりローカルserveが使えない場合、将来deploy後に `dry_run = true` だけを確認する案を残す。ただし、この工程ではdeployしない。

deploy前に確認すること:

- 秘匿値の実値がコード、docs、GitHub差分にない。
- 初期dry-run段階ではDiscord投稿先credentialを不要とする。
- Authorization Bearerはユーザー手元だけで扱う。
- レスポンスやログに秘匿値の実値、認証系の生値、内部識別子を出さない。
- サーバ側高権限credentialをアプリ内admin権限と混同しない。

deploy後dry-run確認を行う場合も、最初は `create` / `dry_run = true` のみに絞る。`dry_run = false` は実行しない。実値はSupabase管理画面またはユーザー手元の環境だけで扱い、docsや報告には書かない。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-10 手動deploy直前の認証・secret注意

dry-run専用deployをユーザー手元で行う場合、Supabase CLIログイン、project link、project ref相当、Supabase access token相当の入力が必要になる可能性がある。これらの実値はdocs、GitHub、DB、フロント、チャットへ書かない。

Codex側は実値を要求しない。CLI認証やproject linkが未設定、対象projectが不明、または実値を共有しないと進められない状態になった場合はdeployを止め、結果だけを一般化して記録する。

初期dry-run段階ではDiscord投稿先credentialは不要な方針を維持する。必要になる場合もSupabase側のsecret管理で扱い、実値は記録しない。サーバ側高権限credentialをアプリ内admin権限と混同しない。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-9 CLI認証・project link時の秘匿値管理

dry-run専用deploy時には、Supabase CLIのログイン状態、project link、project ref相当の情報が必要になる可能性がある。これらはユーザー手元またはSupabase管理画面側だけで扱い、docs、GitHub、DB、フロント、チャットへ実値を書かない。

deploy前の判断:

- CLI認証が必要な場合はユーザー手元で行う。
- project linkやproject ref相当の実値をCodexへ渡さない。
- 認証やlinkの状態が不明ならdeployを止め、一般化した結果だけを記録する。
- Authorization Bearerや認証系の生値はdeploy後dry-run確認時もユーザー手元だけで扱う。
- サーバ側高権限credentialをアプリ内admin権限と混同しない。

初期dry-run段階ではDiscord投稿先credentialは不要な方針を維持する。必要になる場合もSupabase側のsecret管理で扱い、実値は記録しない。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-8 dry-run専用deploy前のsecret確認

dry-run専用draftを将来deployする場合でも、初期確認ではDiscord投稿先credentialは不要とする。必要になる場合もSupabase側のsecret管理で扱い、docs、GitHub、フロント、DB、チャットには実値を書かない。

deploy前に確認すること:

- コード、docs、GitHub差分に秘匿値の実値がない。
- Authorization Bearerや認証系の生値はユーザー手元だけで扱う。
- サーバ側高権限credentialをアプリ内admin権限と混同しない。
- `dry_run = false` が `real_send_not_enabled` で拒否される。
- Discord API送信処理とDB書き込み処理が未接続である。

deploy候補コマンドは `npx.cmd supabase functions deploy sync-session-post-to-discord` とするが、この工程では実行しない。deploy後確認も最初は `create` / `dry_run = true` のみに絞り、結果は実値を除いて一般化して記録する。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6G ローカルserve前の環境変数確認

Edge Functionコードが参照している環境変数名:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUBLIC_SITE_BASE_URL`

このうち `SUPABASE_URL` と `SUPABASE_ANON_KEY` は、呼び出しユーザーの認証文脈でSupabase RPCを呼ぶために必要。`PUBLIC_SITE_BASE_URL` は詳細URLpreview用で、未設定時は相対URLになる。

今回の作業環境では、上記3つの環境変数はいずれも未設定だった。認証文脈も未用意のため、`npx.cmd supabase functions serve sync-session-post-to-discord` は実行していない。`dry_run = true` 呼び出しも未実行。

次工程でローカルserveを行う場合は、必要な値をユーザー手元だけで用意し、docsや報告には実値を書かない。`dry_run = false` は実行せず、Discord実送信なし、DB更新なし、ログ安全性を確認する。

この追記ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。
