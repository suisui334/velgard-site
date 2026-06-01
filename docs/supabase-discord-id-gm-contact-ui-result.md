# Supabase M-12D GM向け承認済み参加者連絡先UI 実装結果

作業日: 2026-06-01

## 1. 実装範囲

`session-detail.html` のGM/admin向け領域に、承認済み参加者のDiscord ID表示とコピー導線を追加した。

既存のGM/admin判定に従い、未ログイン、通常PL、判定失敗時はUIを表示しない。

## 2. 使用RPC

```js
client.rpc("get_gm_session_accepted_contacts", {
  target_session_id: sessionId
})
```

返却列は `display_name` / `discord_handle` のみを想定し、それ以外の列が返った場合は表示せずエラー扱いにする。

## 3. UI

GM履歴折りたたみと同じGM/admin向け領域に、以下の折りたたみを追加した。

```text
GM向け：承認済み参加者連絡先
```

表示は `表示名: Discord ID` の形式。未登録者は `未登録` と表示する。

コピー導線:

```text
連絡先一覧をコピー
```

コピー文字列も `表示名: Discord ID` の行区切り。未登録者は `未登録` として含める。

## 4. 状態表示

実装した状態:

```text
読み込み中
承認済み参加者はまだいません
連絡先を取得できませんでした
コピーしました
コピーできませんでした
```

## 5. 表示する情報 / 表示しない情報

表示する情報:

```text
display_name
discord_handle
```

表示しない情報:

```text
email
user_id
application_id
comment_id
discord_user_id
discord_name
token
key
secret
```

Discord ID実値はdocsやconsoleへ記録しない。UI上もGM/admin判定後の領域に限定する。

## 6. 未実施

- SQL Editor実行。
- DB変更。
- RLS smoke test追加。
- 実Discord IDの入力・記録。
- `updates.json` 変更。
- commit / push。

Codex側でGM/adminログイン確認は行っていない。実ブラウザでのGM/admin表示、acceptedのみ表示、コピー成功確認はユーザー側確認へ回す。
