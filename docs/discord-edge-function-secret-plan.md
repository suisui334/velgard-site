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
