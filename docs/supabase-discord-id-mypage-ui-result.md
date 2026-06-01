# Supabase M-12C mypage Discord ID登録UI 実装結果

作業日: 2026-06-01

## 1. 実装範囲

`mypage.html` のログイン済みアカウント機能内に、本人が自分のDiscord IDを登録・編集できるUIを追加した。

今回扱ったのは本人用UIのみ。GM向け承認済み参加者連絡先表示 / コピー導線、RLS smoke test追加、SQL Editor実行、DB変更、Discord ID実値入力、`updates.json` 変更、commit / pushは行っていない。

## 2. 変更した主なファイル

```text
assets/js/mypageAuthClient.js
assets/css/style.css
mypage.html
docs/supabase-discord-id-mypage-ui-result.md
docs/supabase-discord-id-contact-plan.md
docs/supabase-discord-id-contact-sql-result.md
docs/task-backlog.md
README.md
```

## 3. UI配置

ログイン済みアカウント機能内で、既存の表示名編集UIの直後に `Discord ID` パネルを配置した。

表示文言は、GMが承認済み参加者へ連絡するために使うこと、未登録でも参加申請は可能であること、公開プロフィールには表示されないことが伝わる範囲に留めた。

未ログイン時は既存のログイン導線に従い、Discord ID欄は表示しない。

## 4. RPC呼び出し

取得:

```js
client.rpc("get_my_profile_contact")
```

保存:

```js
client.rpc("update_my_discord_id", {
  new_discord_id: value
})
```

戻り値は `display_name` / `discord_handle` の想定だが、今回のUIでは本人の `discord_handle` だけを現在値として反映する。`discord_handle` の実値はconsoleやdocsへ出力しない。

## 5. バリデーション

フロント側で以下を確認する。

- 入力値は `trim` する。
- 空欄保存は未登録扱いとして保存RPCへ渡す。
- 100文字超過は保存前に止める。
- CR / LF の改行入りは保存前に止める。
- Discord側の仕様変更に備え、数字限定や `@` 必須などの厳密な正規表現は使わない。
- DOM反映は `textContent` と input value に限定し、HTMLとして扱わない。

## 6. 表示状態

最低限の状態として以下を実装した。

```text
読み込み中
保存中
保存しました
保存できませんでした
未登録
```

保存失敗や読み込み失敗では短い安全文言だけを画面に出す。consoleにはエラー種別のコード / name / status 程度だけを出し、Discord ID実値やsecret類は出さない。

## 7. 表示しない情報

今回の本人UIでは、本人の `discord_handle` 以外をDiscord ID欄で扱わない。

画面・console・docsへ出さないもの:

```text
email
user_id
token
key
secret
discord_user_id
discord_name
他人のdiscord_handle
```

## 8. 未実施

未実施:

- GM向け承認済み参加者Discord ID表示 / コピー導線。
- `get_gm_session_accepted_contacts(target_session_id text)` のフロント接続。
- 連絡先RPCのRLS smoke test追加。
- SQL Editor実行。
- DB変更。
- Discord ID実値入力。
- `updates.json` 変更。
- commit / push。

ユーザー実ブラウザでの保存確認は、実Discord IDではなく短いテスト文字列を使うか、保存実行自体をユーザー側確認へ回す方針。

## 9. Codex側確認

実施済み:

- `node --check assets/js/mypageAuthClient.js`
- `Get-ChildItem assets/js -Filter *.js | ForEach-Object { node --check $_.FullName }`
- `Get-ChildItem dev -Filter *.js | ForEach-Object { node --check $_.FullName }`
- `node --check scripts/supabase-rls-smoke-test.mjs`
- `Get-ChildItem data -Filter *.json | ForEach-Object { python -m json.tool $_.FullName > $null; ... }`
- `git diff --check`
- `http://127.0.0.1:4173/mypage.html` の未ログイン表示確認

ローカル未ログイン表示では、既存のログイン導線が表示され、Discord ID欄はログイン後にだけ出る状態であることを確認した。Codex側では実ログイン、実保存、実Discord ID入力は行っていない。
