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
