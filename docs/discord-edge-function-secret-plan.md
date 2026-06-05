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

## M-14E-11 deploy後のsecret状態

ユーザー手元でdry-run専用Edge Function deployは成功したが、この段階ではDiscord投稿先credentialや追加secretの実値設定は行っていない。deploy後の確認も、まず `create` / `dry_run = true` のみに絞る。

deploy後dry-run確認時に必要になるAuthorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsやチャットへ書かない。`dry_run = false`、Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

`supabase/.temp/` はCLI生成物として未追跡生成されたが、ユーザーが削除済みでcommit対象外。

この追記ではdocs記録のみ行い、Codex側でEdge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-13 dry_run=false拒否確認時のsecret確認

`dry_run = false` 拒否確認でも、Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先、Discord投稿先、認証系の生値はユーザー手元だけで扱う。docs、GitHub、DB、フロント、チャットには実値を書かない。

確認時に記録してよいのは、HTTP status、response keys、error codeまたは一般化した拒否理由、Discord投稿なし、DB更新なし、ログ安全性の結果だけとする。レスポンス本文全文、URL実値、`message_preview` 本文全文は記録しない。

Function Logsに秘匿値の実値や認証系の生値が表示された場合は、そのまま共有せず、一般化した問題として記録して追加安全レビューへ戻る。

この追記では手順整理のみ行い、`dry_run = false` 実行、Discord実送信、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

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

## M-14E-13C / M-14E-14 初期投稿先secret方針

`dry_run = false` 拒否確認では、実送信未有効化としてHTTP 501で拒否されることを確認した。Discord実送信は発生しておらず、外部投稿先credentialの実値設定も行っていない。

初期実送信実装での投稿先は、まず「全依頼書を1つの募集チャンネルへ投稿」に固定する。GM別、依頼書種別別、セッション別の投稿先分岐は初期実装では扱わない。

secret管理方針:

- 投稿先の実値、外部送信用credential、チャンネル識別子相当の値は、フロント、docs、GitHub、チャットに記録しない。
- 初期実装の投稿先は、将来のsecret設定工程で管理する。
- secret名候補と設定手順は後続工程で整理するが、実値は記録しない。
- アプリ内admin権限と高権限credentialを混同しない。
- 実送信実装前に、単一募集チャンネル向けの失敗時挙動、再試行方針、ログ安全性を別工程で確認する。

将来拡張として、GM別、依頼書種別別、セッション別の投稿先分岐を検討できる。ただし、初期実装では投稿先分岐を増やさず、単一募集チャンネルへのcreate同期を安全に成立させる。

## M-14E-14 単一募集チャンネル向けsecret設計

初期実装では、全依頼書を1つの募集チャンネルへ投稿する。GM別、依頼書種別別、セッション別の投稿先分岐は扱わず、投稿先を増やす設計は将来拡張候補として残す。

### secret名候補

実値はSupabase Edge Function側のsecret管理で扱い、docs、GitHub、フロント、DB、チャットには書かない。名前候補のみを整理する。

| 用途 | secret名候補 | 初期必須 | 備考 |
| --- | --- | --- | --- |
| 単一募集チャンネル投稿用Webhook | `DISCORD_SESSION_POST_WEBHOOK_URL` | Webhook方式なら必須 | 投稿先credentialを含むため実値は絶対に記録しない。 |
| Bot方式用token | `DISCORD_BOT_TOKEN` | 初期は非推奨 | 権限範囲が広くなりやすいため、初期単一チャンネル投稿では採用しない想定。 |
| Bot方式用投稿先 | `DISCORD_RECRUITMENT_CHANNEL_ID` | 初期は不要 | Bot方式へ移行する場合の候補。実値は記録しない。 |
| 公開サイト基底URL | `PUBLIC_SITE_BASE_URL` | 既存previewで使用 | 詳細URL生成用。実値はdocsへ書かない。 |

### Webhook方式 / Bot方式の比較

| 方式 | 長所 | 注意点 | 初期判断 |
| --- | --- | --- | --- |
| Webhook方式 | 単一チャンネル投稿に向く。Bot権限を持たずに投稿できる。secretが少ない。 | Webhook URL自体がcredentialなので厳格にsecret管理する。投稿済みメッセージの更新/削除には返却された投稿識別子相当の保存とWebhook経由操作の設計が必要。 | 初期推奨。 |
| Bot方式 | 将来の複数チャンネル分岐、権限制御、複雑な操作に拡張しやすい。 | bot tokenと投稿先識別子相当の管理が必要。権限範囲が広くなりやすい。誤設定時の影響が大きい。 | 初期は見送り。 |

初期実装ではWebhook方式を第一候補にする。全依頼書を単一募集チャンネルへ投稿する前提と相性がよく、Bot tokenを扱わずに済むため安全境界を小さく保てる。将来、GM別、種別別、セッション別の投稿先分岐が必要になった時点でBot方式または複数Webhook方式を再検討する。

### 実送信有効化時の安全境界

- `dry_run = true` は引き続きpreviewのみを返し、Discord送信もDB更新も行わない。
- `dry_run = false` は、実送信コード、投稿先secret、DB更新方針、ログ安全性のレビューが揃うまで拒否を維持する。
- 実送信有効化後も、必要secretが未設定または不正な場合は一般化エラーで拒否する。
- レスポンスとログに、secret実値、認証情報、内部識別子相当の値、投稿先実値を出さない。
- アプリ内admin権限と高権限credentialを混同しない。

### 失敗時方針

Discord送信失敗時も、依頼書保存そのものを巻き戻さない方針を維持する。同期失敗は同期状態として扱い、GM/adminが後続で再同期できる余地を残す。

- 送信成功時のみ、外部投稿識別子相当の値、同期状態、最終アクション、同期日時などを更新する。
- 送信失敗時は、同期状態をfailed相当にし、一般化したエラー概要を記録する案を第一候補にする。
- secret、認証情報、外部APIレスポンス全文、投稿先実値はエラー記録に含めない。
- dry-run時はDB更新しない。

### 実送信前チェック

- secret実値がコード、docs、GitHub、フロント、DB、チャットにない。
- dry-run成功と `dry_run = false` 拒否確認が記録済み。
- 実送信コード追加後も `dry_run = true` がpreview専用である。
- secret未設定時の拒否挙動がある。
- Discord API失敗時に依頼書保存全体を壊さない。
- ログにsecretや認証情報を出さない。
- 誤投稿時のdelete/close/resync方針を実送信QA前に整理する。

次工程は、実送信draft設計、実送信コード実装前レビュー、secret設定手順整理、テスト投稿確認の順に分割する。今回の工程ではsecret実値設定、Discord実送信、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14B Webhook実送信draft設計
初期実送信draftでは、全依頼書を単一の募集チャンネルへ投稿する方針を維持し、Webhook方式を第一候補にする。投稿先はリクエストpayloadやフロント設定では受け取らず、Edge Function側のsecretから解決する。secret名候補は `DISCORD_SESSION_POST_WEBHOOK_URL` とするが、実値はdocs、GitHub、DB、フロント、チャットに記録しない。

実送信有効化前は、`dry_run = true` はpreviewのみ、`dry_run = false` は引き続き拒否する。実送信コードを追加する場合も、secret未設定、権限不足、同期対象外、投稿先解決不可のときは一般化エラーで拒否し、Discord送信もDB更新も行わない。

Webhook方式の送信payloadは、既存dry-run previewで確認している公開情報をもとに、`content` または `embeds` を組み立てる案を候補にする。初期実装では不要なメンションを避けるため、`allowed_mentions` で明示的に抑制する案を優先する。Discord成功レスポンスから外部投稿識別子相当の値を取得する必要があるため、Webhook呼び出し時に作成済みメッセージ情報を受け取れる設定を検討する。ただし、Discordレスポンス全文や投稿先実値はログ・DB・レスポンスに残さない。

失敗時は、外部APIの生レスポンス全文を保存しない。DBへ失敗情報を残す場合も、`discord_sync_error` 相当には一般化した短い理由のみを記録し、secret、認証情報、投稿先実値、外部APIレスポンス全文、確認対象依頼書ID相当の実値を含めない。

## M-14E-14C 実装前レビュー観点
実送信コードを追加する前に、以下を必ずレビューする。

- secret未設定時に安全に拒否されること。
- `dry_run = true` がpreview専用のまま維持されること。
- `dry_run = false` の有効化条件がコード上・docs上で明確であること。
- Webhook実値、認証情報、確認対象依頼書ID相当の実値、投稿先実値をレスポンスやログへ出さないこと。
- Discord API失敗時にレスポンス全文を出さず、一般化したエラーだけを扱うこと。
- Discord送信成功を確認する前にDB更新しないこと。
- 送信成功後のDB更新失敗時に、二重投稿や不整合をどう扱うかを別途確認すること。
- 同じ依頼書に外部投稿識別子が既にある場合、`create` が二重投稿を作らないこと。

この工程では設計整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` の再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14C Webhook helper draft実装メモ
`sync-session-post-to-discord` に、将来のWebhook実送信用draft helperを追加した。参照するsecret名候補は `DISCORD_SESSION_POST_WEBHOOK_URL` のみで、実値はコード、docs、GitHub、チャットに記録していない。

このhelperは、secret未設定時に一般化した設定不足として扱う。Webhook payloadは既存preview本文をもとに `content` を作り、意図しないメンションを避けるため `allowed_mentions.parse = []` を含めるdraftとした。Discord成功レスポンスから外部投稿識別子相当を取り出す処理もdraftとして置いたが、レスポンス全文は返さない方針を維持する。

重要な安全境界として、今回追加したhelperはリクエスト処理の実行経路へ接続していない。`dry_run = false` は引き続き `real_send_not_enabled` 相当で先に拒否されるため、secretが設定されていてもDiscord実送信には進まない。DB更新処理、外部投稿識別子保存処理、secret実値設定はまだ行わない。

## M-14E-14D Webhook secret設定手順と設定後確認
Webhook方式の初期実装では、単一募集チャンネル向けの投稿先credentialを `DISCORD_SESSION_POST_WEBHOOK_URL` というsecret名で扱う方針を維持する。secret実値はSupabase側のsecret管理だけで扱い、docs、GitHub、DB、フロント、チャットには書かない。

### Supabase CLIで設定する場合
PowerShellでは `npx.cmd` を使う。コマンド例はプレースホルダーのみで記録する。

```powershell
npx.cmd supabase secrets set DISCORD_SESSION_POST_WEBHOOK_URL="<DISCORD_SESSION_POST_WEBHOOK_URL_VALUE>"
```

`<DISCORD_SESSION_POST_WEBHOOK_URL_VALUE>` はユーザー手元だけで置き換える。実値をチャットやdocsへ貼らない。CLI認証、project link、project ref相当の扱いが必要になった場合も、実値はユーザー手元だけで扱い、Codexへ渡さない。

### Supabase Dashboardで設定する場合
Dashboardから設定する場合も、secret名が `DISCORD_SESSION_POST_WEBHOOK_URL` であること、対象projectと対象Functionの環境に設定すること、保存後に値が画面共有やdocsへ残らないことを確認する。スクリーンショットを共有する場合は、値欄を完全に隠す。

### 設定反映とdeploy要否の確認観点
secret設定だけでは実送信は有効化されない。現行コードではWebhook helperは実行経路から呼ばれず、`dry_run = false` は `real_send_not_enabled` 相当で拒否される。設定後にFunctionがsecretを参照できるようになるタイミングやdeploy要否は、Supabase CLIまたはDashboardの表示に従って確認する。判断が曖昧な場合は、deployや実送信へ進まず、結果だけを一般化して記録する。

### secret設定後の安全確認
secret設定後も、まず `dry_run = true` のpreview維持を確認する。次に、実送信有効化前であれば `dry_run = false` が引き続き拒否されることを確認対象にする。ただし、このM-14E-14D工程ではどちらも実行しない。

確認時は、Function Logsにsecret実値、Webhook実値、認証情報、確認対象依頼書ID相当の実値、投稿先実値が出ていないことを確認する。Discord側にも投稿が増えていないことを、実送信有効化前の確認項目として残す。

### 実送信有効化前の停止条件
以下のどれかに該当する場合は、実送信有効化へ進まない。

- secret名または対象projectが曖昧。
- secret実値がdocs、GitHub、チャット、ログ、フロントに出た。
- `dry_run = true` がpreview専用でなくなった。
- `dry_run = false` の拒否境界が崩れた。
- 投稿先チャンネルが募集チャンネルでよいか未確認。
- テスト用チャンネルと本番募集チャンネルのどちらを使うか未決定。
- 誤投稿時の削除または訂正方針が未整理。
- 二重投稿防止策、既存外部投稿識別子がある場合の `create` 挙動、Discord成功後DB更新失敗時の扱いが未整理。

この工程ではdocs整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14E secret設定前の最終意思決定
`DISCORD_SESSION_POST_WEBHOOK_URL` を設定する前に、投稿先とテスト方針をユーザー判断事項として確定する。初期実装は「全依頼書を1つの募集チャンネルへ投稿」で進めるが、docsではチャンネル名、チャンネルID、Webhook URL、投稿先実値を記録しない。表記は「本番募集チャンネル」または「テスト用チャンネル」の抽象名に限定する。

### 投稿先チャンネル判断

- 初期実装は単一募集チャンネル向けWebhook方式を維持する。
- secret設定前に、最初の投稿先を「テスト用チャンネル」にするか「本番募集チャンネル」にするかを決める。
- 本番募集チャンネルを使う場合は、投稿文面、募集状態、詳細URL相当の扱いが公開されても問題ない状態まで整っていることを確認する。
- テスト用チャンネルを使う場合は、後続で本番募集チャンネルへ切り替える手順と再確認項目を別工程で整理する。
- GM別、依頼書種別別、セッション別の投稿先分岐は初期実装に含めない。

### secret設定前のユーザー判断事項

- Webhook方式で進めることを再確認する。
- 初回確認をテスト用チャンネルで行うか、本番募集チャンネルで行うかを決める。
- テスト投稿に使う依頼書は検証用にし、実運用データを不用意に使わない。
- 誤投稿時に削除または訂正できる担当者と手順を決める。
- 投稿文面が本番募集チャンネルに出ても問題ない状態か確認する。
- 実送信前に二重投稿防止、既存外部投稿識別子がある場合の `create` 挙動、Discord送信成功後DB更新失敗時の扱いを確認する。

### secret設定後の境界

secret設定だけでは実送信を有効化しない。Webhook helperはdraftとして存在するが、実送信有効化コード変更までは現行リクエスト経路から呼ばない。secret設定後も `dry_run = true` はpreview専用、`dry_run = false` は `real_send_not_enabled` 相当で拒否を維持する。

secret設定後の最初の確認は `dry_run = true` の再確認に限定する。Function Logsとレスポンスにsecret実値、Webhook実値、認証情報、確認対象依頼書ID相当の実値、投稿先実値が出ていないことを確認する。実送信有効化コード変更前はDiscord側に投稿が増えないことも確認対象にする。

### 実送信有効化前の停止条件

以下に該当する場合は、secret設定後であっても実送信有効化へ進まない。

- 投稿先チャンネルが未確定。
- テスト用チャンネルか本番募集チャンネルかの判断が未確定。
- 誤投稿時の削除または訂正方針が未確定。
- 二重投稿防止策が未整理。
- 既存外部投稿識別子がある場合の `create` 挙動が未整理。
- Discord送信成功後のDB更新失敗時の扱いが未整理。
- secret、Webhook URL、認証情報、投稿先実値、確認対象依頼書ID相当の実値がdocs、GitHub、チャット、ログ、フロント、DBに露出するおそれがある。

### 次工程分割案

1. M-14E-14F: ユーザー手元でsecret設定。
2. M-14E-14G: secret設定後 `dry_run = true` 再確認。
3. M-14E-14H: secret設定後も `dry_run = false` 拒否維持確認。
4. M-14E-14I: 実送信有効化コード変更案作成。
5. M-14E-14J: 初回テスト投稿確認。

この工程ではdocs整理のみ行い、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14F テスト用チャンネル前提のsecret設定直前手順
初回のDiscord実送信確認は、本番募集チャンネルではなくテスト用チャンネルを先に使う方針に確定する。docsではテスト用チャンネル名、チャンネルID、Webhook URL、Discord投稿先実値を記録しない。以後の手順では「テスト用チャンネル」という抽象名のみを使う。

### テスト用チャンネル方針

- 初回確認はテスト用チャンネルで行う。
- 本番募集チャンネルへの切り替えは、テスト用チャンネルでの確認結果を記録した後の別工程で判断する。
- テスト用チャンネルで確認する場合も、投稿文面、権限、ログ安全性、DB更新境界は本番相当の安全基準で見る。
- テスト投稿に使う依頼書は検証用にし、実運用データを不用意に使わない。

### Discord側Webhook作成手順の概要

1. Discordサーバー側でテスト用チャンネルを用意する。
2. テスト用チャンネルにWebhookを作成する。
3. Webhook URLは作成直後からユーザー手元だけで扱う。
4. Webhook URLをチャット、docs、GitHub、Issue、README、console、ログへ貼らない。
5. Webhook名やアイコンは任意だが、テスト用と分かる名前にする。
6. 不要になったWebhookはDiscord側で削除できることを確認しておく。

### Supabase secret設定手順の概要

secret名は `DISCORD_SESSION_POST_WEBHOOK_URL` を使う。CLIで設定する場合は、PowerShellでは `npx.cmd` を使い、実値はユーザー手元だけで置き換える。

```powershell
npx.cmd supabase secrets set DISCORD_SESSION_POST_WEBHOOK_URL="<WEBHOOK_URL>"
```

`<WEBHOOK_URL>` はプレースホルダーであり、実値をdocs、GitHub、DB、フロント、チャットへ記録しない。Dashboardで設定する場合も、対象projectと対象Function環境、secret名、値欄が画面共有やスクリーンショットに残らないことを確認する。

secret設定後は、git差分にsecret実値が出ていないことを確認する。PowerShell履歴、ターミナル表示、画面共有、スクリーンショットにもWebhook URLが残らないよう注意する。実値が残った可能性がある場合は停止し、Webhookの削除または再作成を検討する。

### secret設定後の確認手順

secret設定後もすぐに実送信しない。まず `dry_run = true` がpreview専用のまま成功することを確認する。次に、実送信有効化前であれば `dry_run = false` が引き続き `real_send_not_enabled` 相当で拒否されることを確認する。

確認観点:

- secret設定だけではDiscord投稿が発生しない。
- Function LogsにWebhook URL、認証情報、確認対象依頼書ID相当の実値、投稿先実値が出ていない。
- git statusがcleanであり、secret実値が差分に出ていない。
- Discord側に意図しない投稿が増えていない。
- DB同期状態が更新されていない。

### 実送信有効化前の停止条件

以下に該当する場合は、実送信有効化へ進まない。

- Webhook URLをdocs、GitHub、チャット、Issue、README、console、ログへ貼った可能性がある。
- テスト用チャンネルではないWebhookを設定した可能性がある。
- `dry_run = false` が拒否されなくなった。
- Function LogsにWebhook URLまたは認証情報が出た。
- Discordに意図しない投稿が出た。
- secret設定後の `dry_run = true` と `dry_run = false` 拒否維持の確認が終わっていない。

### 次工程案

1. M-14E-14G: ユーザー手元でテスト用チャンネルWebhook作成。
2. M-14E-14H: ユーザー手元でSupabase secret設定。
3. M-14E-14I: secret設定後 `dry_run = true` 再確認。
4. M-14E-14J: secret設定後 `dry_run = false` 拒否維持確認。
5. M-14E-14K: 実送信有効化コード変更案作成。
6. M-14E-14L: テスト用チャンネルで初回実送信確認。

この工程ではdocs整理のみ行い、実Webhook作成、secret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14G/H/I/J テスト用Webhook secret設定とdry-run再確認結果
ユーザー手元で、テスト用チャンネル向けWebhook secret設定と、secret設定後の `dry_run = true` preview維持確認、`dry_run = false` 拒否維持確認を実施済みとして記録する。Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値、Supabase接続先全文は記録しない。

### secret設定結果

- テスト用チャンネル向けWebhook URLをユーザー手元で取得した。
- Webhook URL本体はチャット、docs、GitHubへ出していない。
- PowerShell待機方式でWebhook URLを環境変数へ取り込んだ。
- Supabase secret `DISCORD_SESSION_POST_WEBHOOK_URL` へ設定した。
- secret設定は実行済みで、終了コードは成功扱い。
- Webhook URL値は環境変数から削除済み。
- 一度、Webhook URL検査失敗後に誤った値を設定した可能性があったため、正しいテスト用Webhook URLで上書き設定した。
- Webhook URL実値は記録しない。

### secret設定後の `dry_run = true` 確認

ユーザー手元で `create` / `dry_run = true` を再確認し、HTTP 200で成功した。レスポンスはJSONとしてparse可能で、`ok = true`、`dry_run = true`、`action = create` を確認した。`message_preview`、`planned_db_update`、`warnings` は返却されたが、`message_preview` 本文全文は記録しない。previewは12行、212文字相当として記録する。

### secret設定後の `dry_run = false` 拒否維持確認

ユーザー手元で `create` / `dry_run = false` を再確認し、HTTP 501で想定どおり拒否された。レスポンスはJSONとしてparse可能で、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。拒否メッセージは一般化された内容で、実送信はdraftでは有効化されていないことを案内するものだった。

### Discord側確認

ユーザー目視により、テスト用チャンネルに新規投稿が増えていないことを確認済みとして記録する。secret設定だけではDiscord投稿は発生せず、実送信はまだ有効化していない。

### 次工程案

1. M-14E-14K: 実送信有効化コード変更案の詳細レビュー。
2. M-14E-14L: テスト用チャンネルで初回実送信確認の手順整理。
3. M-14E-14M: 実送信有効化コード実装。ただしDB更新連携は分離するか検討する。
4. M-14E-14N: テスト用チャンネルで初回実送信確認。

この記録工程でCodexはsecret実値設定、Discord実送信、`dry_run = true` / `dry_run = false` 再実行、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装を行わない。

## M-14E-14K 実送信有効化コード変更案レビュー
テスト用チャンネルWebhook secret設定後のdry-run確認が完了したため、実送信有効化コードへ進む前の最小変更範囲を整理する。この工程ではdocs整理のみ行い、Edge Functionコード変更、deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

### 最小コード変更案

- `dry_run = true` は引き続きpreview専用に固定し、Discord送信とDB更新を行わない。
- `dry_run = false` の早期拒否は、初回実送信確認では `action = create` かつGM/admin権限確認済み、同期対象確認済み、Webhook secret解決成功、テスト用チャンネル前提のレビュー完了、という条件を満たす場合だけ解除する案を候補にする。
- `update` / `close` / `delete` / `resync` は初回実装では未対応として拒否を維持する。
- Webhook helperは、対象依頼書の公開情報だけでpreview本文を組み立てた後、Discord送信直前に呼ぶ。
- secret未設定、secret形式不備、権限不足、同期対象外、対象依頼書取得失敗時は一般化エラーで拒否し、Discord送信もDB更新も行わない。
- 実送信有効化後も、Webhook URL、認証情報、確認対象依頼書ID相当の実値、投稿先実値をログやレスポンスに出さない。

### レスポンス方針

成功時レスポンスは、UIや手動確認に必要な最小情報に丸める。`ok`、`dry_run = false`、`action = create`、一般化した送信結果、次に必要な確認項目程度を候補にする。Discord APIレスポンス全文、Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値は返さない。

Discord message id相当は、初回実送信確認ではレスポンスへ直接返さず、後続のDB更新連携設計で内部保持する案を第一候補にする。レスポンスに含める必要が出た場合も、docsやチャットへ実値を貼らない運用を前提に追加レビューする。

失敗時は `webhook_secret_missing`、`discord_send_failed`、`unsupported_action`、`sync_target_not_allowed` のような一般化したerror_code候補に丸める。Discord APIエラー本文や外部レスポンス全文は返さない。

### 初回実送信テスト範囲

- 対象はテスト用チャンネルのみ。
- 対象actionは `create` のみ。
- 対象依頼書は検証用依頼書に限定する。
- 実送信前に `dry_run = true` previewを再確認する。
- 実送信後はテスト用チャンネルに1件だけ投稿されたことを確認する。
- 同じpayloadを二重実行しない。
- 想定外投稿、投稿先違い、ログへのsecret露出、レスポンスへの実値露出があれば即停止する。

### DB更新連携の扱い

初回実送信でDiscord投稿とDB更新を同時に行う案は、外部送信成功後のDB更新失敗時に二重投稿や状態不整合の扱いが難しくなる。初回はDiscord投稿のみを確認し、外部投稿識別子保存、同期状態更新、失敗状態記録は後続工程へ分離する案を推奨する。

DB更新連携を行う場合は、外部投稿識別子保存、同期状態更新、送信成功後DB更新失敗時の再実行設計、重複投稿防止、既存外部投稿識別子がある場合の `create` 拒否または更新誘導を別工程でレビューする。DB/RPC変更が必要な場合は、SQL Editor実行やRPC変更をさらに後続工程に分ける。

### 二重投稿防止方針

初回テストでは手動で1回だけ実行する運用にし、同じ確認対象で再実行しない。現段階ではDB更新連携を分離するため、システム上の恒久的な二重投稿防止は未完成として扱う。後続では外部投稿識別子相当がある場合の `create` を拒否し、`update` または `resync` へ誘導する設計を第一候補にする。

### ログと秘匿値安全性

- Webhook URLをログに出さない。
- request body全文をログに出さない。
- Authorization、JWT、確認対象依頼書ID相当の実値、投稿先実値をログに出さない。
- Discord APIエラー本文をそのままログやレスポンスに出さない。
- Function Logsでは、一般化された成功/失敗種別だけを確認対象にする。
- 秘匿値が出た場合は即停止し、Webhook削除または再作成、secret再設定、ログ共有停止を検討する。

### 次工程案

1. M-14E-14L: 実送信有効化コード実装。ただしDB更新連携は分離する方針を第一候補にする。
2. M-14E-14M: `deno check`、安全検索、差分レビュー、commit準備。
3. M-14E-14N: deploy。
4. M-14E-14O: deploy後 `dry_run = true` 再確認。
5. M-14E-14P: テスト用チャンネルで `create` 実送信1回確認。
6. M-14E-14Q: 結果docs記録。

## M-14E-14L テスト用チャンネル向けcreate実送信コード実装メモ
`sync-session-post-to-discord` に、テスト用チャンネルWebhook secretを使う `action = create` の実送信経路を接続した。ただし、この工程ではdeploy、Discord実送信、`dry_run = true` / `dry_run = false` 再実行は行わない。

実装範囲:

- `dry_run = true` は従来どおりpreview専用で、Webhook helperを呼ばない。
- `dry_run = false` かつ `action = create` の場合のみ、権限確認、対象依頼書取得、同期対象判定、action検証を通過した後にWebhook helperを呼ぶ。
- `update` / `close` / `delete` / `resync` は `unsupported_action` 相当で拒否を維持する。
- Webhook secret `DISCORD_SESSION_POST_WEBHOOK_URL` が未設定、空、不正な場合は一般化エラーで拒否し、fetchを呼ばない。
- Webhook payloadは既存preview本文相当を `content` とし、`allowed_mentions.parse = []` で意図しないメンション展開を抑止する。
- Discord API成功時もレスポンス全文は返さない。
- 成功時レスポンスは最小限にし、外部投稿識別子相当は実値として返さない。
- DB更新、外部投稿識別子保存、同期状態更新は追加していない。

実装後も、Webhook URL実値、投稿先実値、認証情報、確認対象依頼書ID相当の実値、Supabase接続先全文、`message_preview` 本文全文はdocsやレスポンスへ出さない方針を維持する。二重投稿防止は初回テストでは手動1回運用とし、恒久対策は外部投稿識別子保存とあわせて後続工程で扱う。
