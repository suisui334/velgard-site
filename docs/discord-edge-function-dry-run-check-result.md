# M-14E-6 Discord同期Edge Function Deno構文確認 / dry-run確認準備結果

## 目的

M-14E-4で追加したDiscord同期Edge Function draftについて、deploy前の安全確認としてDeno利用可否、構文確認可否、安全検索、dry-run確認準備状況を記録する。

対象:

- `supabase/functions/sync-session-post-to-discord/index.ts`
- `docs/discord-edge-function-secret-plan.md`

今回の工程では、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値の設定・記録、commit / pushは行っていない。

## 作業前状態

- 作業前 `git status --short`: clean
- 作業前最新commit: `fdbdfd6 Document Discord sync secret and dry run checks`
- Edge Function draft path: `supabase/functions/sync-session-post-to-discord/index.ts`

## Deno / TypeScript確認

実行結果:

| 確認 | 結果 |
| --- | --- |
| `deno --version` | `deno not found` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | Deno未導入のため未実施 |

判断:

- この環境ではDeno構文確認は未完了。
- M-14E-6以降で、Denoが利用できる環境またはSupabase Edge Functionのローカル確認環境を用意してから `deno check` を実施する。
- 追加の依存導入、deploy、外部送信は今回行っていない。

## 安全検索結果

対象: `supabase/functions/sync-session-post-to-discord/index.ts`

| 検索対象 | 件数 |
| --- | ---: |
| `fetch(` | 0 |
| `.insert(` | 0 |
| `.update(` | 0 |
| `.delete(` | 0 |
| `.upsert(` | 0 |
| `console.` | 0 |

対象: Edge Function draftと関連docs

| 検索対象 | 件数 |
| --- | ---: |
| Discord webhook URL形式 | 0 |
| Discord旧webhook URL形式 | 0 |
| bot token風prefix | 0 |
| MFA token風文字列 | 0 |
| 3セグメントtoken風文字列 | 0 |

判断:

- Edge Function draftにはDiscord実送信経路がない。
- Edge Function draftにはDB書き込み経路がない。
- Edge Function draftにはconsole出力がない。
- secret実値らしき文字列は検出していない。

## dry-run確認準備

今回の工程では、Edge Function起動、deploy、secret実値設定、dry-run呼び出しは行っていない。

将来確認するpayload例はダミー値のみを使う。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

確認予定:

- `dry_run = true` でpreviewだけが返る。
- `dry_run = false` は `real_send_not_enabled` で拒否される。
- Discord実送信が発生しない。
- DB更新が発生しない。
- レスポンスにsecret実値、認証系の生値、ユーザー内部識別子、参加申請やPC選択関連の内部キー、外部投稿参照情報そのものが含まれない。
- 作成者GMまたはapp内adminだけがpreviewできる。
- 未ログイン、通常PL、他GMは拒否される。

## ローカル確認手順候補

ローカル確認は、DenoまたはSupabase Edge Functionのローカル実行環境が用意できた後に行う。

1. Deno / Supabase CLIの利用可否を確認する。
2. secret実値をdocsやチャットに出さない形で、ローカル環境だけに設定する。
3. `deno check supabase/functions/sync-session-post-to-discord/index.ts` を実行する。
4. Edge Functionをローカル起動できる場合のみ、`dry_run = true` のダミーpayloadでpreviewを確認する。
5. `dry_run = false` が拒否されることを確認する。
6. DB状態列が変化していないことを確認する。
7. Discord側に投稿・編集・削除相当処理が発生していないことを確認する。

今回、上記手順の実行は行っていない。

## 残した懸念点

- Denoがこの環境にないため、TypeScript / Deno構文確認は未完了。
- Edge Functionのローカル起動確認は未実施。
- `dry_run = true` の実レスポンス確認は未実施。
- 権限helperがEdge Function実行環境で期待どおり動くかは未確認。
- CORS許可元は実運用前に再確認が必要。
- 実送信へ進む前に、DB状態更新経路と外部投稿credential管理の再レビューが必要。
- 完全削除前に外部投稿側処理をどう行うかは未決定。

## 後続候補

1. Deno利用環境での `deno check` 実施。
2. dry-runローカル起動確認。
3. deploy手順整理。
4. deploy実施判断。
5. GM/admin向け再同期UI検討。
6. Discord実送信QA。

## M-14E-6B Deno確認方針

M-14E-6時点ではDenoが利用できず、構文確認とdry-run実行確認は未完了のまま残っている。現時点でDeno導入、Supabase CLI導入、deploy、外部送信、secret実値設定は行わない。

現状:

- Deno未導入。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` 未実施。
- Edge Functionコード変更なし。
- `fetch(` / DB書き込み系メソッド / `console.` の安全検索は0件。
- secret実値らしき文字列は検出なし。
- deployなし。
- Discord実送信なし。
- dry-run実行なし。

deploy前必須確認:

- DenoまたはSupabase Edge Function互換環境で構文確認する。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` を実行する。
- 可能ならSupabase Edge Function形式でローカル起動確認する。
- `dry_run = true` のみpreview確認する。
- `dry_run = false` が拒否されることを確認する。
- Discord実送信が発生しないことを確認する。
- DB更新が発生しないことを確認する。
- レスポンスとログにsecret実値、認証系の生値、内部識別子が出ないことを確認する。

確認方法の選択肢:

| 選択肢 | 内容 | 注意 |
| --- | --- | --- |
| ローカルWindows環境でDeno確認 | Windows上にDenoを用意し、`deno check` を実行する | 今回は導入しない。導入前にユーザー確認を取る |
| Supabase CLI環境で確認 | Edge Functionローカル実行に近い形で起動とdry-runを確認する | 今回は導入しない。secret実値はdocsへ残さない |
| CIまたは別環境で確認 | Denoがある環境で構文確認だけを先に通す | 実行ログにsecret実値や内部情報を出さない |

進行判断:

- Deno確認前にdeployへ進まない。
- dry-run実行確認前にDiscord実送信へ進まない。
- secret設定方針を再確認する前に実送信コードへ進まない。
- M-14E-7 deploy手順整理へ進む前に、どの環境でDeno確認を実施するかを決めるのが安全。

今回のM-14E-6Bでは方針整理のみ行い、Deno導入、Supabase CLI導入、Edge Function起動、deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、commit / pushは行っていない。

## M-14E-6C ユーザーローカルWindows Deno確認結果

ユーザーがローカルWindows PowerShellで `deno --version` を実行した。

結果:

```text
deno はコマンドレット、関数、スクリプトファイル、または操作可能なプログラムの名前として認識されません。
```

判断:

- ユーザーのローカルWindows環境でもDenoは未導入。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は未実施。
- 現時点でEdge FunctionのDeno構文確認は未完了。
- Deno確認前にdeployへ進まない方針を維持する。
- dry-run実行確認前にDiscord実送信へ進まない方針を維持する。

次工程候補:

1. ユーザー確認のうえでローカルWindows環境にDenoを導入して構文確認する。
2. Supabase CLI環境を用意し、Edge Functionローカル実行に近い形で確認する。
3. CIまたは別環境で `deno check` を先に通す。

いずれの案でも、secret実値、認証系の生値、内部識別子はdocsやログへ残さない。

今回のM-14E-6Cではdocs記録のみ行い、Deno導入、Supabase CLI導入、Edge Function起動、deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、commit / pushは行っていない。

## M-14E-6C Deno導入後の構文確認・型エラー修正結果

ユーザーのローカルWindows環境でDeno導入後、以下を実行し、どちらも成功した。

```text
deno --version
deno check supabase/functions/sync-session-post-to-discord/index.ts
```

途中で、`is_session_gm` RPC呼び出しの引数まわりにTypeScript型エラーが出た。

```text
TS2345: Argument of type '{ target_session_id: string; }' is not assignable to parameter of type 'undefined'.
```

対応結果:

- `is_session_gm` 呼び出し専用の薄い型緩和helperを追加し、Supabase client全体の型を崩さない形で修正済み。
- 権限判定は、作成者GMまたはアプリ内adminのみ許可する方針を維持している。
- 通常PLを許可する方向の変更はしていない。
- `dry_run = true` はpreview専用、`dry_run = false` は拒否する方針を維持している。
- Discord実送信なし、DB更新なしの方針を維持している。
- `fetch(`、DB書き込み系メソッド、`console.` は追加していない。

deploy前にまだ残す確認:

- `dry_run = true` の実レスポンス確認。
- `dry_run = false` の拒否確認。
- レスポンスとログにsecret実値、認証系の生値、内部識別子が出ないことの確認。
- Discord実送信とDB更新が発生しないことの確認。

この記録工程ではdocs記録のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、commit / pushは行っていない。

## M-14E-6D dry-run実行確認方法整理

### 目的

dry-run実レスポンス確認では、Edge Functionが安全なpreview専用挙動を保っていることを確認する。

- `dry_run = true` でpreviewを返す。
- `dry_run = false` が `real_send_not_enabled` で拒否される。
- Discord実送信が発生しない。
- DB更新が発生しない。
- レスポンスやログに秘匿値の実値、認証系の生値、内部識別子が出ない。
- 作成者GMまたはアプリ内adminのみ許可され、通常PLは拒否される。

### 実行方法候補

| 方法 | 内容 | 利点 | 注意 |
| --- | --- | --- | --- |
| Supabase CLIのローカルserve | Supabase Edge Functionに近い形でローカル起動し、`dry_run = true` を呼ぶ | deploy前に実行時挙動を確認しやすい | Supabase CLI利用可否確認が必要。秘匿値の実値はdocsへ残さない |
| Deno単体起動 | Denoで `index.ts` を直接起動できるか検討する | 追加ツールが少ない可能性がある | Edge Functionの実行構造や環境変数前提に依存するため慎重に判断する |
| deploy後dry-run限定確認 | deploy後に `dry_run = true` だけを呼ぶ | 本番に近い環境で確認できる | deploy前確認を飛ばさない。`dry_run = false` 実行や実送信へ進まない |
| CI / 別環境 | DenoやSupabase CLIがある別環境で確認する | ローカル環境差分を避けられる | 実行ログに秘匿値の実値や内部識別子を残さない |

### 推奨案

deploy前確認としては、Supabase CLIのローカルserveで `dry_run = true` を確認する案を第一候補にする。

ただし、Supabase CLIが未導入の場合は導入判断が必要。Deno単体起動は可能性があるものの、Edge Function形式の実行環境との差異が出やすいため、まずはSupabase CLI利用可否確認を次工程に分ける。

現時点で無理にdeployへ進まない。`dry_run = true` の実レスポンス確認とログ安全性確認が終わるまで、Discord実送信には進まない。

### 必要になりそうな環境情報

実行時に必要になりうる情報は、実値を書かず、作業者のローカル環境またはEdge Function側の環境変数管理で扱う。

- Supabase URL相当の接続先情報。
- 呼び出しユーザーの認証文脈を表す値。
- Edge Function実行用の環境変数。
- `dry_run = true` 確認用の対象依頼書ID相当の値。

初期dry-runではDiscord実送信しないため、Discord投稿先credentialは原則不要。将来DB状態更新を行う段階でサーバ側高権限credentialが必要になる可能性はあるが、アプリ内admin権限とは別物として扱い、実値をdocsへ書かず、方式レビュー後に判断する。

### payload例

payload例はダミー値だけを使う。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

実在ID、秘匿値の実値、認証系の生値はdocsへ書かない。

### dry_run = true 確認項目

- `create` previewが返る。
- `update` previewが返る。
- `close` previewが返る。
- `delete` previewが返る。
- `resync` previewが返る。
- 同期対象外状態では安全に拒否またはskip相当の結果になる。
- 既存投稿参照情報がない場合、`update` / `close` / `delete` は拒否される。
- 作成者GMまたはアプリ内adminだけがpreviewできる。
- 通常PLはpreviewできない。
- レスポンスに秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものが含まれない。

### dry_run = false 確認項目

`dry_run = false` は今回実行しない。将来確認する場合も、実送信コードを有効化する前のdraft状態で `real_send_not_enabled` により拒否されることだけを確認対象にする。

- `real_send_not_enabled` で拒否される。
- Discord APIを呼ばない。
- DB更新しない。
- ログに秘匿値の実値や内部識別子を出さない。

### 事前安全検索

dry-run実行前に、Edge Function draft内で以下が増えていないことを確認する。

- `fetch(`
- `.insert(`
- `.update(`
- `.delete(`
- `.upsert(`
- `console.`

これらが増えている場合は、dry-run確認へ進む前に安全レビューを行う。

### まだやらないこと

- Edge Function deploy。
- Discord実送信。
- 秘匿値の実値設定。
- `dry_run = false` 実行。
- DB更新。
- フロント接続。

### 次工程案

1. M-14E-6E: Supabase CLI利用可否確認。
2. M-14E-6F: ローカルserve dry-run確認。
3. M-14E-7: deploy手順整理。
4. M-14E-8: deploy判断。
5. M-14E-9: 再同期UI。
6. M-14E-10: 実送信QA。

この工程ではdocs整理のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6E Supabase CLI利用可否確認

ローカルserve dry-run確認へ進む前に、ローカル環境でSupabase CLIが利用できるかを確認した。

実行コマンド:

```text
supabase --version
```

結果:

```text
supabase はコマンドレット、関数、スクリプトファイル、または操作可能なプログラムの名前として認識されません。
```

判断:

- この環境ではSupabase CLIは利用不可。
- Supabase CLIローカルserveは、現時点では未実施。
- Supabase CLI導入は今回行わない。
- Edge Function deploy、Discord実送信、`dry_run = false` 実行には進まない。

次工程候補:

1. ユーザー確認のうえでSupabase CLIを導入し、ローカルserve dry-run確認準備へ進む。
2. Supabase CLIが利用できる別環境でローカルserve dry-run確認を行う。
3. deploy前ローカル確認が難しい場合でも、deploy手順整理と安全レビューを先に行い、deploy後は `dry_run = true` 限定確認から始める。

いずれの案でも、秘匿値の実値、認証系の生値、内部識別子はdocsやログへ残さない。

この工程では利用可否確認とdocs記録のみ行い、Supabase CLI導入、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6E 追加確認: npx.cmd経由のSupabase CLI利用可否

ユーザーのローカルPowerShellで、Node.jsとnpx経由のSupabase CLI利用可否を確認した。

確認結果:

| コマンド | 結果 |
| --- | --- |
| `node --version` | `v24.16.0` |
| `where.exe npx` | Node.js配下の `npx` / `npx.cmd` を確認 |
| `npx supabase --version` | PowerShell実行ポリシーにより `npx.ps1` がブロック |
| `npx.cmd supabase --version` | `supabase@2.105.0` の利用確認後、`2.105.0` を表示 |
| `git status --short` | clean |

判断:

- Node.jsは利用可能。
- PowerShell上の `npx` は実行ポリシーで止まる。
- PowerShellでは `npx.cmd` 経由ならSupabase CLI v2.105.0を利用可能。
- Supabase CLIはグローバル導入ではなく、`npx.cmd` 経由で利用可能な状態として扱う。
- 今回、Supabase CLI導入、ローカルserve、deploy、Discord実送信、`dry_run = false` 実行は行っていない。

## M-14E-6F ローカルserve dry-run確認準備

次工程でローカルserve dry-run確認を行う場合の候補コマンド:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

このコマンドは候補として整理するだけで、M-14E-6F準備段階では実行しない。

必要になりそうな環境情報:

- Supabase接続先。
- 呼び出しユーザーの認証文脈。
- Edge Function実行用の環境変数。
- dry-run確認対象の依頼書ID相当の値。

扱い方:

- 実値はdocsへ書かない。
- 認証文脈が必要な場合は、ユーザーが手元だけで用意する。
- 実在する依頼書ID相当の値もdocsへ書かない。
- 初期dry-runではDiscord投稿先credentialは原則不要。
- サーバ側高権限credentialが必要になる場合も、アプリ内admin権限と混同せず、後続レビューで扱う。

ローカルserveで確認する範囲:

- `dry_run = true` のみ確認対象にする。
- `create` / `update` / `close` / `delete` / `resync` のpreviewを確認する。
- 同期対象外、既存投稿参照情報不足、通常PL拒否、GM/admin許可を確認する。
- Discord実送信が発生しないことを確認する。
- DB更新が発生しないことを確認する。
- レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを確認する。

まだやらないこと:

- `supabase functions serve` 実行。
- `supabase start` 実行。
- Edge Function deploy。
- Discord実送信。
- `dry_run = false` 実行。
- SQL Editor実行。
- DB/RPC変更。
- フロント接続。

次工程候補:

1. M-14E-6F: `npx.cmd` 経由ローカルserve dry-run確認。
2. M-14E-7: deploy手順整理。
3. M-14E-8: deploy判断。
4. M-14E-9: 再同期UI。
5. M-14E-10: 実送信QA。

この工程ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6G ローカルserve dry-run実行準備・実行可否確認

ローカルserve dry-run確認へ進む前に、作業環境とEdge Functionの前提を確認した。

事前確認結果:

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `70cd55d Record Supabase CLI dry run preparation` |
| `npx.cmd supabase --version` | `2.105.0` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | PATH上の `deno` は未認識。ユーザー領域のDeno実行ファイルをフルパス実行し成功 |

Edge Functionが参照する環境変数名:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUBLIC_SITE_BASE_URL`

このうち、呼び出しユーザーの認証文脈でSupabase RPCを呼ぶため、`SUPABASE_URL` と `SUPABASE_ANON_KEY` はローカルserve dry-run確認に必要。`PUBLIC_SITE_BASE_URL` は詳細URLpreview用の任意設定で、未設定時は相対URLになる。

この作業環境での環境変数存在確認:

| 環境変数名 | 状態 |
| --- | --- |
| `SUPABASE_URL` | 未設定 |
| `SUPABASE_ANON_KEY` | 未設定 |
| `PUBLIC_SITE_BASE_URL` | 未設定 |

ローカルserve候補:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

実行判断:

- 上記候補コマンドは実行しなかった。
- 理由は、ローカルserve dry-run確認に必要な `SUPABASE_URL` / `SUPABASE_ANON_KEY` がこの作業環境に未設定で、さらに認証文脈も未用意のため。
- 秘匿値の実値や認証系の生値をdocsや報告へ出さない条件を優先し、無理にserveやdry-run呼び出しへ進まない判断にした。

dry_run=true確認:

- 実行しなかった。
- 理由は、ローカルserveを起動しておらず、必要な環境変数と認証文脈も未用意のため。
- payload例は引き続きダミー値のみをdocsに残す。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

安全検索結果:

| 検索対象 | 件数 |
| --- | ---: |
| `fetch(` | 0 |
| `.insert(` | 0 |
| `.update(` | 0 |
| `.delete(` | 0 |
| `.upsert(` | 0 |
| `console.` | 0 |

次工程候補:

1. ユーザー手元で `SUPABASE_URL` / `SUPABASE_ANON_KEY` と認証文脈を安全に用意する。
2. `npx.cmd supabase functions serve sync-session-post-to-discord` を実行する。
3. `dry_run = true` のみを呼び、preview、権限判定、同期対象外、既存投稿参照情報不足時の挙動を確認する。
4. レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを確認する。

この工程では、ローカルserveは未実行、`dry_run = true` も未実行。Edge Function deploy、Discord実送信、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6H dry-run実行条件整理・ローカル実行手順確定

ローカルserve dry-run確認の実行条件を再確認した。

事前確認結果:

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `48597b3 Record Supabase CLI dry run preparation` |
| `npx.cmd supabase --version` | `2.105.0` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | PATH上の `deno` は未認識。ユーザー領域のDeno実行ファイルをフルパス実行し成功 |

Edge Functionが参照する環境変数名:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUBLIC_SITE_BASE_URL`

認証文脈:

- `Authorization` ヘッダーが必要。
- 値はBearer形式の認証文脈として扱われる。
- 実値はdocs、報告、チャットへ書かない。
- Codex側では値を要求せず、ユーザー手元で用意する前提にする。

この作業環境での状態:

| 項目 | 状態 |
| --- | --- |
| `SUPABASE_URL` | 未設定 |
| `SUPABASE_ANON_KEY` | 未設定 |
| `PUBLIC_SITE_BASE_URL` | 未設定 |
| 認証文脈 | 未用意 |

ローカルserve候補:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

実行判断:

- ローカルserveは実行しなかった。
- 理由は、必須の `SUPABASE_URL` / `SUPABASE_ANON_KEY` が未設定で、Authorizationヘッダー用の認証文脈も未用意のため。
- 秘匿値の実値や認証系の生値をCodex側で扱う必要が出るため、実行せず停止した。
- `supabase start`、Edge Function deploy、Discord実送信には進んでいない。

dry_run=true確認:

- 実行しなかった。
- 理由は、ローカルserveを起動しておらず、必要な環境変数と認証文脈も未用意のため。
- 実行する場合のpayload例はダミー値のみを使う。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

dry_run=false:

- 実行していない。
- 将来確認項目として、draft段階では `real_send_not_enabled` で拒否されることを残す。

安全検索結果:

| 検索対象 | 件数 |
| --- | ---: |
| `fetch(` | 0 |
| `.insert(` | 0 |
| `.update(` | 0 |
| `.delete(` | 0 |
| `.upsert(` | 0 |
| `console.` | 0 |
| Discord webhook URL形式 | 0 |
| bot token風文字列 | 0 |
| service-role系credential風文字列 | 0 |

次工程候補:

1. ユーザー手元で必要な環境変数と認証文脈を用意する。
2. ローカルserveを起動する。
3. `dry_run = true` のみを呼ぶ。
4. 権限エラーの場合は認証文脈不足または権限不足として一般化して記録する。
5. レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを確認する。

この工程では、ローカルserve未実行、`dry_run = true` 未実行、`dry_run = false` 未実行。Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6I ローカルdry-run手元実行ガイド・結果記録テンプレート

Codex側では秘匿値の実値、認証系の生値、実在する依頼書ID相当の値を扱わない。dry-run実レスポンス確認は、ユーザーが手元のPowerShell環境だけで必要値を設定して行う。

### 事前確認結果

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `d7bab80 Record Discord sync local dry run readiness` |
| `npx.cmd supabase --version` | `2.105.0` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | PATH上の `deno` は未認識。ユーザー領域のDeno実行ファイルをフルパス実行し成功 |

Edge Functionが参照する環境変数名:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PUBLIC_SITE_BASE_URL`

必要な認証文脈:

- `Authorization: Bearer <USER_JWT>`
- 実値はdocs、報告、チャットへ書かない。
- Codexは値を要求しない。
- ユーザーが手元のPowerShell、ブラウザ、ローカルメモだけで扱う。

確認対象:

- `<SESSION_ID_FOR_DRY_RUN>`
- 実在する値はdocs、報告、チャットへ書かない。

### 実行前チェック

手元実行前に必ず確認する。

- Edge Function draftがDiscord実送信なし、DB更新なしのdry-run preview専用である。
- `dry_run = true` のみ実行する。
- `dry_run = false` は実行しない。
- Discord投稿先credentialは初期dry-runでは不要。
- 秘匿値の実値、認証系の生値、実在する依頼書ID相当の値をチャットへ貼らない。
- ログやレスポンスに秘匿値の実値、認証系の生値、内部識別子が出た場合、そのまま共有しない。

### PowerShell手順案

値はすべてプレースホルダー。実行時はユーザー手元でのみ実値に置き換える。

```powershell
$env:SUPABASE_URL = "<YOUR_SUPABASE_URL>"
$env:SUPABASE_ANON_KEY = "<YOUR_SUPABASE_ANON_KEY>"
$env:PUBLIC_SITE_BASE_URL = "<YOUR_PUBLIC_SITE_BASE_URL>"
```

ローカルserve候補:

```powershell
npx.cmd supabase functions serve sync-session-post-to-discord
```

別PowerShellで、`dry_run = true` のみを呼ぶ候補:

```powershell
$headers = @{
  "Authorization" = "Bearer <USER_JWT>"
  "Content-Type" = "application/json"
}

$body = @{
  session_id = "<SESSION_ID_FOR_DRY_RUN>"
  action = "create"
  dry_run = $true
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:54321/functions/v1/sync-session-post-to-discord" `
  -Headers $headers `
  -Body $body
```

payload例:

```json
{
  "session_id": "<SESSION_ID_FOR_DRY_RUN>",
  "action": "create",
  "dry_run": true
}
```

docsに残すpayload例はダミー値だけにする。

```json
{
  "session_id": "example-session-id",
  "action": "create",
  "dry_run": true
}
```

### 初回確認の優先度

初回は `create` の `dry_run = true` だけに絞る。

`update` / `close` / `delete` / `resync` は既存投稿参照情報や依頼書状態に依存するため、初回でまとめて実行しない。`create` のレスポンス安全性と権限判定を確認した後、後続工程で必要に応じて扱う。

### dry_run=trueで期待する結果

結果は次のいずれかでよい。実値を含む生レスポンスをdocsへ貼らない。

- 成功し、`message_preview` と `planned_db_update` が返る。
- 権限不足として拒否される。
- 同期対象外として拒否またはskip相当になる。
- 対象依頼書が見つからない等の一般化エラーになる。

確認すること:

- `message_preview` が返る場合、公開情報だけで構成されている。
- `planned_db_update` が返る場合、予定情報だけで、実DB更新は行われない。
- 秘匿値の実値、認証系の生値、内部識別子がレスポンスに出ない。
- Discord実送信なし。
- DB更新なし。
- ログに秘匿値の実値、認証系の生値、内部識別子が出ない。

### dry_run=false

実行しない。

将来確認項目として、draft段階では `real_send_not_enabled` で拒否されることを残す。

### 結果記録テンプレート

手元実行後、実値を抜いて以下の形式で記録する。

```markdown
## M-14E-6J dry_run=true 手元実行結果

- 実施日:
- 実施者:
- 対象環境:
- action: create
- dry_run: true
- 結果: 成功 / 権限不足 / 同期対象外 / 対象なし / その他
- message_preview: 実値を含まない要約のみ
- planned_db_update: 予定情報のみ / なし
- Discord実送信なし確認: 済 / 未確認
- DB更新なし確認: 済 / 未確認
- 秘匿値・認証系の生値非露出確認: 済 / 未確認
- 内部識別子非露出確認: 済 / 未確認
- console / serve log安全性: 問題なし / 要確認
- 残課題:
```

記録時の注意:

- 認証系の生値を貼らない。
- 実在する依頼書ID相当の値を貼らない。
- レスポンス全文を貼る場合は、秘匿値の実値、認証系の生値、内部識別子、外部投稿参照情報そのものを除去してからにする。
- ログに危険な値が含まれる場合は共有しない。

### 安全検索結果

| 検索対象 | 件数 |
| --- | ---: |
| `fetch(` | 0 |
| `.insert(` | 0 |
| `.update(` | 0 |
| `.delete(` | 0 |
| `.upsert(` | 0 |
| `console.` | 0 |
| Discord webhook URL形式 | 0 |
| bot token風文字列 | 0 |
| service-role系credential風文字列 | 0 |

この工程では、Codex側でローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行は行っていない。Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushも行っていない。

## M-14E-6J ローカルserve不可結果記録

ユーザー手元で、ローカルserveに必要な前提を確認した。

確認結果:

| 確認 | 結果 |
| --- | --- |
| `npx.cmd supabase --version` | `2.105.0` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | 成功 |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `PUBLIC_SITE_BASE_URL` | ユーザー手元で設定済み。実値は記録しない |
| `npx.cmd supabase functions serve sync-session-post-to-discord` | 失敗 |
| `docker --version` | PowerShellで `docker` が認識されない |

ローカルserve失敗の概要:

- Docker Desktopがローカル開発の前提として必要、というエラーが出た。
- Docker daemonへ接続できない旨のエラーが出た。
- Docker engine pipeが見つからない、またはDocker clientが接続できない状態。
- ユーザー環境ではDocker CLI / Docker Desktopが未導入、またはPATH上で利用不可と判断する。

判断:

- ローカルserveはDocker未導入またはDocker daemon利用不可により未実行扱い。
- `dry_run = true` は未実行。
- `dry_run = false` も未実行。
- Discord実送信なし。
- DB更新なし。
- Edge Function deployなし。
- 秘匿値の実値、認証系の生値、実在する依頼書ID相当の値はdocsへ記録していない。

次工程候補:

1. ユーザー判断でDocker Desktopを導入し、ローカルserve dry-run確認へ進む。
2. Docker導入を保留し、deploy前手順整理と安全レビューへ進む。
3. deploy後に確認する場合でも、まず `dry_run = true` 限定確認から始め、実送信へ進まない。

今回の記録工程では、Docker Desktop導入、Supabase CLI追加導入、ローカルserve再実行、`dry_run = true` 実行、`dry_run = false` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-7 deploy後dry-run確認手順・deploy前安全レビュー

Docker Desktop / Docker CLIが未導入または利用不可で、ローカルserve dry-run確認は保留になっている。Docker導入を保留する場合に備え、将来deploy後に `dry_run = true` だけを安全に確認する手順と、deploy前の安全レビュー項目を整理する。

### 現状

- Deno構文確認は成功済み。
- Supabase CLIは `npx.cmd` 経由で `2.105.0` を確認済み。
- ローカルserveはDocker未導入またはDocker daemon利用不可により不可。
- `dry_run = true` は未実行。
- `dry_run = false` も未実行。
- Discord実送信なし。
- DB更新なし。

### deploy前チェックリスト

deploy前に必ず確認する。

- `git status --short` がcleanである。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` が成功する。
- `fetch(` が増えていない。
- `.insert(` / `.update(` / `.delete(` / `.upsert(` が増えていない。
- `console.` が増えていない。
- `dry_run = false` が `real_send_not_enabled` で拒否される実装である。
- Discord API送信処理が未接続である。
- DB更新処理が未接続である。
- 秘匿値の実値がコード、docs、GitHub差分にない。
- 初期dry-run段階ではDiscord投稿先credentialが不要である。
- ログに秘匿値の実値、認証系の生値、内部識別子を出さない。
- CORS方針を確認する。初期draftの許可元はdry-run確認用として扱い、実運用前に再レビューする。
- Authorization Bearerはユーザー手元だけで扱い、docsやチャットへ貼らない。
- アプリ内admin権限とサーバ側高権限credentialを混同しない。

### deploy後dry_run=true確認手順案

deploy後に確認する場合も、最初は `create` / `dry_run = true` のみに絞る。

必要な値:

- Supabase接続先相当のURL。
- Authorization Bearer。
- 確認対象の依頼書ID相当の値。

扱い:

- 実値はユーザー手元だけで扱う。
- docsや報告には実値を書かない。
- レスポンスは一般化して記録する。
- `message_preview` と `planned_db_update` の有無を確認する。
- Discord実送信が発生していないことを確認する。
- DB更新が発生していないことを確認する。
- 秘匿値の実値、認証系の生値、内部識別子がレスポンスやログに出ないことを確認する。

payload例はダミー値だけで記載する。

```json
{
  "session_id": "<SESSION_ID_FOR_DRY_RUN>",
  "action": "create",
  "dry_run": true
}
```

### dry_run=false

- まだ実行しない。
- 将来確認する場合も、実送信コードを追加する前のdraft段階では `real_send_not_enabled` で拒否されることだけを確認対象にする。
- Discord実送信コードを追加するまでは、実送信へ進まない。

### secret管理

- 初期dry-runではDiscord投稿先credentialは不要な方針を維持する。
- 必要になる場合も、Supabase側のsecret管理で扱い、docsやチャットには実値を書かない。
- サーバ側高権限credentialはアプリ内admin権限とは別物として扱う。
- Codexは秘匿値の実値や認証系の生値を要求しない。

### deploy判断の前提

- この工程ではdeployしない。
- 次工程でdeployする場合も、deploy前にユーザー確認を必須にする。
- deploy後も最初は `dry_run = true` のみ確認する。
- Discord実送信はさらに後続工程へ分ける。

### 次工程候補

1. M-14E-8: Edge Function deploy手順・事前確認。
2. M-14E-9: deploy実施判断。
3. M-14E-10: deploy後dry_run=true確認。
4. M-14E-11: real_send createのみ実装検討。
5. M-14E-12: Discord実送信QA。
6. またはDocker Desktop導入後にローカルserve dry-runへ戻る。

この工程ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-8 dry-run専用deploy実施前レビュー・コマンド整理

Docker導入を保留したまま、将来deploy後dry-run確認へ進むためのdeploy前安全レビューと、実行コマンド候補を整理する。この工程ではdeployしない。

### deploy対象

- Edge Function名: `sync-session-post-to-discord`
- 対象ファイル: `supabase/functions/sync-session-post-to-discord/index.ts`
- 性質: dry-run preview専用draft
- `dry_run = true`: previewのみ
- `dry_run = false`: `real_send_not_enabled` で拒否
- Discord実送信なし
- DB更新なし

### deploy前安全レビュー

確認済み:

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `9919119 Document Discord sync deploy dry run review` |
| `npx.cmd supabase --version` | `2.105.0` |
| `deno check supabase/functions/sync-session-post-to-discord/index.ts` | PATH上の `deno` は未認識。ユーザー領域のDeno実行ファイルをフルパス実行し成功 |
| `fetch(` | 0 |
| `.insert(` / `.update(` / `.delete(` / `.upsert(` | 0 |
| `console.` | 0 |
| Discord webhook URL形式 | 0 |
| bot token風文字列 | 0 |
| service-role系credential風文字列 | 0 |
| `deno.lock` | なし |
| `updates.json`差分 | なし |

deploy前に再確認すること:

- Discord API送信処理が未接続である。
- DB書き込み処理が未接続である。
- 秘匿値の実値がコード、docs、GitHub差分にない。
- `dry_run = false` 拒否が崩れていない。
- Function名と対象パスが明確である。
- ユーザーのdeploy実施確認がある。

### deployコマンド候補

PowerShellでは `npx` ではなく `npx.cmd` を使う。

```powershell
npx.cmd supabase functions deploy sync-session-post-to-discord
```

このコマンドは候補として整理するだけで、M-14E-8では実行しない。deploy実施時はユーザー確認を必須にする。

### secret設定

- 初期dry-run段階ではDiscord投稿先credentialは不要な方針を維持する。
- 必要になる場合も、Supabase側のsecret管理で扱い、docsやチャットへ実値を書かない。
- Authorization Bearerや認証系の生値はユーザー手元だけで扱う。
- サーバ側高権限credentialをアプリ内admin権限と混同しない。

### deploy後dry_run=true確認手順

最初は `create` / `dry_run = true` のみ確認する。

payload例:

```json
{
  "session_id": "<SESSION_ID_FOR_DRY_RUN>",
  "action": "create",
  "dry_run": true
}
```

確認項目:

- Functionに到達する。
- `ok = true` または一般化エラーが返る。
- `message_preview` の有無。
- `planned_db_update` の有無。
- Discord実送信なし。
- DB更新なし。
- 秘匿値の実値、認証系の生値、内部識別子がレスポンスやログに出ない。
- ログ安全性。

結果は実値を除いて一般化して記録する。

### dry_run=false

- 今回も実行しない。
- 将来確認する場合でも、`real_send_not_enabled` の拒否確認だけに分ける。
- Discord実送信コード追加前に実送信へ進まない。

### deployを止める条件

以下がある場合はdeployしない。

- `git status --short` がdirty。
- Deno構文確認が失敗する。
- `fetch(`、DB書き込み系メソッド、`console.` が増えている。
- 秘匿値の実値がコードまたはdocsに混入している。
- `dry_run = false` 拒否が崩れている。
- Function名または対象パスが曖昧。
- ユーザーのdeploy実施確認がない。

### 次工程候補

1. M-14E-9: deploy実施判断。
2. M-14E-10: deploy後 create / dry_run=true 確認。
3. M-14E-11: dry_run=false拒否確認。
4. M-14E-12: real_send createのみ実装検討。
5. M-14E-13: Discord実送信QA。
6. またはDocker Desktop導入後にローカルserve dry-runへ戻る。

この工程ではdocs整理とdeploy前レビューのみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-9 dry-run専用deploy実施判断・最終手順整理

dry-run専用deployを実施してよいか判断するため、deploy直前チェック、Supabase CLI認証・project link確認観点、deploy候補コマンド、deploy後dry-run確認手順を整理する。この工程ではdeployしない。

### deploy直前チェック

確認済み:

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `ff9ea72 Review Discord sync dry run deploy plan` |
| Deno構文確認 | 成功 |
| `npx.cmd supabase --version` | `2.105.0` |
| `fetch(` | 0 |
| `.insert(` / `.update(` / `.delete(` / `.upsert(` | 0 |
| `console.` | 0 |
| 外部投稿URL形式 | 0 |
| bot token風文字列 | 0 |
| 認証系生値風文字列 | 0 |
| `deno.lock` | なし |
| `updates.json`差分 | なし |

deploy前に維持すること:

- `dry_run = false` が `real_send_not_enabled` で拒否される。
- Discord API送信処理が未接続である。
- DB書き込み処理が未接続である。
- 秘匿値の実値がコード、docs、GitHub差分にない。

### Supabase CLI認証・project link確認観点

deploy時には、Supabase CLIのログイン状態、対象project link、project ref相当の情報が必要になる可能性がある。これらの実値はdocs、GitHub、チャットへ書かず、ユーザー手元またはSupabase管理画面側だけで扱う。

CLI認証やproject linkが未設定、対象projectが不明、実値をCodexへ渡す必要がある状態になった場合はdeployしない。必要な確認結果だけを一般化して記録し、ユーザー確認後に次工程へ分ける。

### deploy候補コマンド

PowerShellでは `npx` ではなく `npx.cmd` を使う。

```powershell
npx.cmd supabase functions deploy sync-session-post-to-discord
```

このコマンドは候補として整理するだけで、M-14E-9では実行しない。deploy実施時はユーザーの明示確認を必須にする。

### deployを止める条件

- `git status --short` がdirty。
- Deno構文確認が失敗する。
- `fetch(`、DB書き込み系メソッド、`console.` が増えている。
- 秘匿値の実値がコードまたはdocsに混入している。
- CLI認証、project link、project ref相当の扱いが不明。
- `dry_run = false` 拒否が崩れている。
- ユーザーの明示確認がない。

### deploy後dry_run=true確認手順

deploy後確認は最初に `create` / `dry_run = true` のみに絞る。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsや報告には実値を書かない。

payload例:

```json
{
  "session_id": "<SESSION_ID_FOR_DRY_RUN>",
  "action": "create",
  "dry_run": true
}
```

確認項目:

- Functionに到達する。
- `ok = true` または一般化エラーが返る。
- `message_preview` と `planned_db_update` の有無。
- Discord実送信なし。
- DB更新なし。
- 秘匿値の実値、認証系の生値、内部識別子がレスポンスやログに出ない。
- ログ安全性。

### dry_run=false

まだ実行しない。将来確認する場合も拒否確認として別工程に分ける。実送信コードを追加するまではDiscord実送信へ進まない。

### 次工程候補

1. M-14E-10: ユーザー手動deploy実施。
2. M-14E-11: deploy後 create / dry_run=true 確認。
3. M-14E-12: dry_run=false拒否確認。
4. M-14E-13: real_send createのみ実装検討。
5. M-14E-14: Discord実送信QA。
6. またはDocker Desktop導入後にローカルserve dry-runへ戻る。

この工程ではdocs整理とdeploy直前レビューのみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-10 dry-run専用deploy実施前 最終安全確認

Codex側ではdeployせず、dry-run実行にも進まず、ユーザー手動deployへ進めるかどうかの最終安全確認だけを行った。

### 最終安全確認結果

| 確認 | 結果 |
| --- | --- |
| `git status --short` | clean |
| `git log --oneline -1` | `cf8037c Document Discord sync dry run deploy checklist` |
| Deno構文確認 | 成功 |
| `npx.cmd supabase --version` | `2.105.0` |
| `fetch(` | 0 |
| `.insert(` / `.update(` / `.delete(` / `.upsert(` | 0 |
| `console.` | 0 |
| 外部投稿URL形式 | 0 |
| bot token風文字列 | 0 |
| 認証系生値風文字列 | 0 |
| service-role系文字列 | 0 |
| `deno.lock` | なし |
| `updates.json`差分 | なし |

### deploy対象

- Function名: `sync-session-post-to-discord`
- 対象ファイル: `supabase/functions/sync-session-post-to-discord/index.ts`
- deploy候補コマンド: `npx.cmd supabase functions deploy sync-session-post-to-discord`
- Codex側ではこのコマンドを実行しない。

### deploy停止条件

- 作業ツリーがdirty。
- Deno構文確認が失敗する。
- 外部送信処理、DB書き込み処理、console出力が増えている。
- 秘匿値の実値がコードまたはdocsに混入している。
- CLI認証、project link、project ref相当の扱いが不明。
- `dry_run = false` 拒否が崩れている。
- ユーザーの明示確認がない。

### ユーザー手動deploy時の注意

deploy時にSupabase CLIログイン、project link、project ref相当の確認、Supabase access token相当の入力が求められる可能性がある。実値はユーザー手元だけで扱い、docsやチャットへ書かない。認証やlinkが未設定の場合はdeployを止め、結果だけを一般化して記録する。

deploy後の確認は最初に `create` / `dry_run = true` のみに絞る。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、結果は一般化して記録する。`dry_run = false` はまだ実行しない。

### 判断

現時点の確認結果では、dry-run専用deployへ進むための直前安全条件は満たしている。ただし、実際のdeployはユーザー明示確認後にユーザー手元で行う。Codex側ではdeployしない。

この工程では最終安全確認とdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-11 dry-run専用deploy結果記録

ユーザー手元で `sync-session-post-to-discord` のdry-run専用Edge Function deployを実施し、成功したことを記録する。この工程ではCodex側でdeployしない。

### deploy結果

- 実行主体: ユーザー手元
- 対象Function: `sync-session-post-to-discord`
- deploy結果: 成功
- Supabaseプロジェクトへのアップロード・deploy: 完了
- Docker未起動に関するWARNING: 表示されたが、deploy自体は成功
- `supabase/.temp/`: deploy後にCLI生成物として未追跡生成されたが、ユーザーが削除済み
- 削除後の `git status --short`: clean

### 現在の状態

- Edge Function deploy済み
- `dry_run = true`: 未実行
- `dry_run = false`: 未実行
- Discord実送信なし
- DB更新なし
- SQL Editor未実行
- DB/RPC変更なし
- フロント実装なし
- 秘匿値の実値設定なし
- `updates.json` 変更なし

### 次工程

次工程は、deploy後 `create` / `dry_run = true` の確認。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsや報告には実値を書かない。結果は成功、権限不足、同期対象外、対象なし等に一般化して記録する。

`dry_run = false`、Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

この工程ではdeploy結果のdocs記録のみ行い、Codex側でEdge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-12B dry-run 500エラー修正

deploy済み `sync-session-post-to-discord` で、ユーザー手元の `create` / `dry_run = true` 確認時にHTTP 500が発生した。レスポンスは一般的なInternal Server Errorで、Discord実送信、`dry_run = false`、DB更新は行っていない。

原因は、`is_session_gm` RPC呼び出し用の型緩和で `supabase.rpc` メソッドを一度変数へ取り出して呼んでいたこと。supabase-js内部のmethod bindingが外れ、RPC呼び出し時に内部client状態を参照できなくなる問題として整理する。

修正内容:

- `callIsSessionGmRpc` で `rpc` メソッドを分離して呼ぶ形を廃止。
- client本体を局所的に型緩和し、`rpcClient.rpc("is_session_gm", { target_session_id: sessionId })` のメソッド呼び出しに変更。
- `is_admin()` と `is_session_gm(...)` によるGM/admin許可方針は維持。
- `dry_run = false` 拒否、Discord実送信なし、DB更新なしの方針は維持。
- `fetch(`、DB書き込み系メソッド、`console.` は追加していない。

確認結果:

- Deno構文確認は成功。
- `rpc` のdestructureや `const rpc = ...` 形式は残っていない。
- Discord実送信なし。
- `dry_run = false` 未実行。
- Edge Function deployはこの工程では未実行。

次工程は、ユーザー確認後に修正版Edge Functionのdeployと、deploy後 `create` / `dry_run = true` 再確認を行うこと。

この工程ではFunctionコード修正とdocs記録のみ行い、SQL Editor実行、DB/RPC変更、Discord実送信、`dry_run = false` 実行、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-12D 修正版deploy後 create / dry_run=true 成功結果

M-14E-12Bで発生していたHTTP 500は、RPC method binding修正後の再deployにより解消した。ユーザー手元で修正版 `sync-session-post-to-discord` の `create` / `dry_run = true` を再確認し、HTTP 200で成功した。

確認結果:

| 確認 | 結果 |
| --- | --- |
| `create` / `dry_run = true` 実行 | ユーザー手元で実施 |
| HTTP status | 200 |
| JSON parse | 成功 |
| `ok` | true |
| `dry_run` | true |
| `action` | `create` |
| response keys | `ok`, `dry_run`, `action`, `sync_target`, `message_preview`, `planned_db_update`, `warnings` |
| `message_preview` | 返却あり |
| `planned_db_update` | 返却あり |
| Discord実送信 | なし |
| `dry_run = false` | 未実行 |

レスポンスサイズ、preview行数、preview有無は確認済み。ただし、確認対象依頼書ID相当の値、Supabase接続先、Authorization Bearer、`message_preview` 本文全文はdocsへ記録しない。

DB更新については、dry-runレスポンス上は `planned_db_update` として予定情報が返る段階であり、実DB更新は行わない設計として扱う。

次工程候補は、`dry_run = false` 拒否確認、またはDiscord実送信実装前の追加安全レビュー。Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

この工程ではdry-run成功結果のdocs記録のみ行い、Codex側でEdge Functionコード変更、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-13 dry_run=false拒否確認手順整理

deploy済み `sync-session-post-to-discord` について、`dry_run = false` を送っても実送信が有効化されておらず、安全に拒否されることを確認するための手順を整理する。この工程では実行しない。

### 目的

- `dry_run = false` が実送信へ進まず拒否されることを確認する。
- 拒否レスポンスに秘匿値の実値、認証系の生値、内部識別子が含まれないことを確認する。
- Discord投稿が作成されないことを確認する。
- DB同期状態が変更されないことを確認する。

### payload例

実行時の値はユーザー手元だけで扱い、docsや報告へ実値を書かない。

```json
{
  "session_id": "<SESSION_ID_FOR_DRY_RUN>",
  "action": "create",
  "dry_run": false,
  "request_source": "manual_real_send_rejection_check"
}
```

### 期待する拒否レスポンス

- HTTP 4xx、またはHTTP 200かつ `ok = false` 相当で拒否される。
- `real_send_not_enabled`、または同等の拒否理由が返る。
- Discord投稿は作成されない。
- DB更新は行われない。
- `discord_sync_status` / `discord_last_action` / `discord_sync_error` 等の同期状態列を変更しない。

### 記録する内容

- HTTP status。
- JSON parse可否。
- response keys。
- error codeまたは一般化した拒否理由。
- Discord投稿なし確認。
- DB同期状態変更なし確認。
- Function Logsに秘匿値の実値や認証系の生値が出ていないこと。

レスポンス本文全文、確認対象依頼書ID相当の値、Supabase接続先全文、Authorization Bearer、Discord投稿先、`message_preview` 本文全文は記録しない。

### 停止条件

- `dry_run = false` が成功送信扱いになった。
- Discord投稿が作成された。
- DB同期状態が変更された。
- レスポンスまたはログに秘匿値の実値、認証系の生値、内部識別子が含まれた。
- 想定外のHTTP 500など、拒否確認として扱えないエラーが返った。

停止条件に該当した場合は以後再実行せず、結果を一般化して記録し、追加安全レビューへ戻る。

この工程では手順整理のみ行い、`dry_run = false` 実行、Discord実送信、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-13C dry_run=false拒否確認結果

ユーザー手元で、deploy済み `sync-session-post-to-discord` に対する `create` / `dry_run = false` の拒否確認を実施した。確認に必要な認証文脈と対象依頼書はユーザー手元だけで扱い、docsには実値を記録しない。

確認結果:

| 項目 | 結果 |
| --- | --- |
| 実行主体 | ユーザー手元 |
| action | `create` |
| `dry_run` | `false` |
| HTTP status | 501 |
| HTTP error | true |
| error body | あり |
| JSON parse | 成功 |
| response keys | `ok`, `error_code`, `message`, `dry_run` |
| `ok` | `false` |
| `error_code` | `real_send_not_enabled` |
| `dry_run` | `false` |
| 拒否メッセージ | 一般化された実送信未有効化メッセージ |
| Discord実送信 | なし |
| DB/RPC変更 | なし |
| SQL Editor | 未実行 |
| Edge Functionコード変更 | なし |
| Edge Function deploy | 今回なし |

判断:

- `dry_run = false` は想定どおり実送信へ進まず拒否された。
- HTTP 501で拒否され、レスポンスはJSONとしてparse可能だった。
- `real_send_not_enabled` により、dry-run専用draftの安全境界は維持されている。
- レスポンス本文全文、確認対象依頼書ID相当の値、Supabase接続先全文、認証ヘッダー、Discord投稿先、`message_preview` 本文全文は記録しない。

次工程候補は、Discord実送信実装前の追加安全レビュー、または `real_send` createのみの実装方針整理とする。実送信、DB更新、`dry_run = true` / `dry_run = false` の再実行、secret実値設定、フロント接続はまだ行わない。

## M-14E-14 実送信前安全レビュー観点

`create` / `dry_run = true` の成功確認と、`create` / `dry_run = false` の拒否確認は完了済み。次に実送信を有効化する場合も、dry-runの安全境界を崩さないことを前提にする。

実送信前の確認項目:

- secret実値がコード、docs、GitHub、フロント、DB、チャットにない。
- 初期投稿先は単一募集チャンネルであり、投稿先はEdge Function側secretから解決する。
- `dry_run = true` は引き続きpreview専用で、Discord送信もDB更新も行わない。
- `dry_run = false` は、実送信コード、secret設定、失敗時挙動、ログ安全性レビューが揃うまで拒否を維持する。
- 実送信有効化後も、secret未設定時は一般化エラーで拒否する。
- Discord送信失敗時も依頼書保存自体を壊さない。
- レスポンスとログにsecret、認証情報、確認対象依頼書ID相当の値、Supabase接続先全文、Discord投稿先実値、`message_preview` 本文全文を出さない。

今回の追記ではdocs整理のみ行い、`dry_run = true` / `dry_run = false` の再実行、Discord実送信、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行っていない。

## M-14E-14B/C 実送信draft実装前レビュー記録
`create / dry_run = true` はHTTP 200で成功済み、`create / dry_run = false` はHTTP 501および `real_send_not_enabled` で拒否済みである。この確認済み境界を、実送信draft設計でも維持する。

実送信コードを追加する前のレビュー観点:

- `dry_run = true` は今後もDiscord送信なし・DB更新なしでpreviewだけを返す。
- `dry_run = false` は、Webhook secret、送信処理、DB更新経路、安全レビューが揃うまで拒否を維持する。
- secret未設定時は一般化エラーで拒否し、Discord送信もDB更新も行わない。
- Discord失敗レスポンス全文、投稿先実値、認証情報、確認対象依頼書ID相当の実値、`message_preview` 本文全文をdocsやログへ残さない。
- 送信成功後にDB更新が失敗した場合の再実行・二重投稿防止策を実装前に確認する。
- `create` 実行時に外部投稿識別子相当が既にある場合の挙動を、実送信前に明示する。

次工程では、実送信コードdraftを追加する場合でも、最初は `dry_run = false` 拒否を維持したままレビューできる形を優先する。secret設定、実送信確認、DB更新連携、フロント接続は別工程に分ける。

## M-14E-14C Webhook helper draft追加後の確認観点
Webhook実送信用draft helperを追加したが、dry-run確認済みの境界は維持している。

- `dry_run = true`: preview専用のまま。Discord送信なし、DB更新なし。
- `dry_run = false`: `real_send_not_enabled` 相当で拒否する挙動を維持。今回も再実行していない。
- Webhook helper: 将来用draftとして追加したが、現行リクエスト処理からは呼ばない。
- `fetch`: draft helper内に将来送信用として存在するが、実送信有効化条件へ到達しない。
- DB書き込み: 追加なし。
- `console.*`: 追加なし。

Codex環境では `deno` コマンドがPATH上で見つからず、今回の環境では `deno check` を実行できなかった。Deno構文確認は、Denoが利用できるユーザー手元環境または別環境で再実施する候補として残す。

## M-14E-14D secret設定後確認の記録テンプレート
secret設定後に確認する場合も、実値は記録しない。結果は以下のように一般化して記録する。

| 項目 | 記録内容 |
| --- | --- |
| secret設定 | 設定済み / 未設定 / 未確認 |
| 設定方法 | CLI / Dashboard / その他 |
| secret名 | `DISCORD_SESSION_POST_WEBHOOK_URL` |
| secret実値 | 記録しない |
| `dry_run = true` | preview維持 / 未確認 |
| `dry_run = false` | 拒否維持 / 未確認 |
| Discord投稿 | 増加なし / 未確認 |
| DB更新 | なし / 未確認 |
| Function Logs | secret非露出 / 未確認 |
| 残課題 | 一般化して記録 |

M-14E-14Dではこのテンプレートと確認観点だけを追加する。secret実値設定、`dry_run = true` / `dry_run = false` の再実行、Discord実送信、Edge Functionコード変更、deploy、DB/RPC変更は行わない。

## M-14E-14E secret設定前判断の記録テンプレート
`DISCORD_SESSION_POST_WEBHOOK_URL` を設定する前に、投稿先と初回確認方針を実値なしで記録する。チャンネル名、チャンネルID、Webhook URL、認証情報、確認対象依頼書ID相当の実値は記録しない。

| 項目 | 記録内容 |
| --- | --- |
| 投稿先方針 | 単一募集チャンネル |
| 初回確認先 | テスト用チャンネル / 本番募集チャンネル / 未決定 |
| Webhook方式 | 採用 / 再確認中 |
| テスト投稿用依頼書 | 検証用を使う / 未決定 |
| 誤投稿時対応 | 削除または訂正担当を確認済み / 未確認 |
| 投稿文面の本番可否 | 問題なし / 要確認 |
| 二重投稿防止 | 確認済み / 未確認 |
| 既存外部投稿識別子がある場合の `create` | 拒否または更新系へ誘導 / 未決定 |
| Discord成功後DB更新失敗時 | 扱い確認済み / 未確認 |
| 停止判断 | 進行可 / 停止 |

停止条件に該当する場合は、secret設定や実送信有効化へ進まず、結果だけを一般化して記録する。この工程ではsecret実値設定、`dry_run = true` / `dry_run = false` の再実行、Discord実送信、Edge Functionコード変更、deploy、DB/RPC変更は行わない。

## M-14E-14F テスト用チャンネルsecret設定前後の記録テンプレート
初回確認はテスト用チャンネルで行う方針に確定した。記録時も、テスト用チャンネル名、チャンネルID、Webhook URL、確認対象依頼書ID相当の実値、認証情報、レスポンス本文全文は残さない。

| 項目 | 記録内容 |
| --- | --- |
| 初回確認先 | テスト用チャンネル |
| Discord側Webhook | 作成済み / 未作成 / 作成失敗 |
| Webhook URL実値 | 記録しない |
| secret名 | `DISCORD_SESSION_POST_WEBHOOK_URL` |
| Supabase secret設定 | 設定済み / 未設定 / 設定失敗 |
| 設定方法 | CLI / Dashboard / その他 |
| git差分のsecret混入 | なし / 要確認 / 停止 |
| `dry_run = true` | preview維持 / 未確認 |
| `dry_run = false` | `real_send_not_enabled` 拒否維持 / 未確認 |
| Discord投稿 | 増加なし / 未確認 / 停止 |
| DB更新 | なし / 未確認 / 停止 |
| Function Logs | Webhook URL非露出 / 未確認 / 停止 |
| 次工程判断 | 継続 / 停止 |

停止条件に該当した場合は、Webhook削除または再作成、secret再設定、ログ安全性確認へ戻る。M-14E-14Fではこのテンプレートと手順整理のみ行い、実Webhook作成、secret実値設定、`dry_run = true` / `dry_run = false` 再実行、Discord実送信、Edge Functionコード変更、deploy、DB/RPC変更は行わない。

## M-14E-14G/H/I/J テスト用Webhook secret設定後dry-run確認結果
ユーザー手元でテスト用チャンネル向けWebhook secret設定と、設定後のdry-run確認を実施済み。Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値、Supabase接続先全文、`message_preview` 本文全文は記録しない。

### secret設定

| 項目 | 結果 |
| --- | --- |
| secret名 | `DISCORD_SESSION_POST_WEBHOOK_URL` |
| secret設定 | 実施済み |
| secret設定結果 | 成功 |
| secret値 | 記録しない |
| 環境変数上の値 | 削除済み |
| 補足 | 誤った値を設定した可能性があったため、正しいテスト用Webhook URLで上書き済み |

### `dry_run = true` 確認

| 項目 | 結果 |
| --- | --- |
| action | `create` |
| HTTP status | 200 |
| JSON parse | 成功 |
| `ok` | `true` |
| `dry_run` | `true` |
| `action` | `create` |
| `message_preview` | 返却あり。本文全文は記録しない |
| preview length | 212 |
| preview lines | 12 |
| `planned_db_update` | 返却あり |
| `warnings` | 返却あり |
| 確認結果 | preview専用維持 |

### `dry_run = false` 拒否維持確認

| 項目 | 結果 |
| --- | --- |
| action | `create` |
| HTTP status | 501 |
| JSON parse | 成功 |
| `ok` | `false` |
| `dry_run` | `false` |
| `error_code` | `real_send_not_enabled` |
| 拒否メッセージ | 実送信はdraftでは有効化されていない旨の一般化メッセージ |
| 確認結果 | 想定どおり拒否維持 |

### Discord側確認

- テスト用チャンネルに新規投稿が増えていないことをユーザーが目視確認済み。
- Discord実送信はまだ有効化していない。
- secret設定だけではDiscord投稿は発生しない方針を再確認した。

次工程候補は、M-14E-14K 実送信有効化コード変更案レビュー、M-14E-14L テスト用チャンネル初回実送信確認手順整理、M-14E-14M 実送信有効化コード実装、M-14E-14N テスト用チャンネル初回実送信確認。
