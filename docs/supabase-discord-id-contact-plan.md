# Supabase M-12A Discord ID登録 / GM向けコピー導線 調査・設計

作業日: 2026-06-01

## 1. 今回の目的

承認済み参加者へGMが連絡しやすくするために、Discord ID相当の連絡先を安全に保存・取得する設計を整理する。

今回は調査・設計とSQL草案作成のみを行う。本番フロント実装、SQL Editor実行、DB変更、Discord ID実値の記録、GM向けコピー機能の本番実装は行わない。

## 2. 調査したファイル

- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `docs/supabase/sql/009_profiles_display_name_rpc_draft.sql`
- `docs/supabase/sql/013_gm_session_application_history_rpc_draft.sql`
- `docs/supabase-mypage-display-name-sql-result.md`
- `docs/supabase-mypage-applications-list-result.md`
- `docs/supabase-session-detail-application-gm-approve-reject-result.md`
- `docs/supabase-session-detail-application-history-gm-ui-result.md`
- `docs/supabase-session-detail-application-history-gm-rpc-result.md`
- `scripts/supabase-rls-smoke-test.mjs`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderMypage.js`
- `assets/js/sessionDetailApplicationComments.js`
- `mypage.html`
- `session-detail.html`
- `README.md`
- `docs/task-backlog.md`

## 3. 既存DB/RPC調査結果

`profiles` には既に `discord_user_id text` と `discord_name text` がある。`discord_user_id` は `^[0-9]{17,20}$` 制約つきで、Discordの数値snowflake ID用途に近い。`discord_name` は既存互換・旧仕様寄りの列として扱い、今回のGM向け連絡先コピー導線では返却・更新対象にしない。

今回の要件はPLが入力する連絡用の現代Discord ID/handleで、厳しすぎる形式制限を避ける方針のため、既存 `discord_user_id` / `discord_name` をそのまま使うと要件や将来の役割分離に合わない。

`public_profiles` は `id` / `display_name` のみを公開している。Discord ID相当の値は含まれていないため、この方針を維持する。

本人の表示名更新は `update_display_name(new_display_name text)` RPCに寄せられている。`mypage.html` は `public_profiles` から表示名を取得し、保存時はRPCを呼ぶ構造になっているため、Discord ID登録も同じパターンでRPCに寄せるのが自然。

GM向け申請履歴は `get_gm_session_application_history(target_session_id text)` で、`display_name` / 申請状態 / 日時 / コメント集計だけを返す。Discord IDは返さない設計で実装済み。GM承認 / 却下UIでは内部 `application_id` / `comment_id` を画面へ出さない防御が入っている。

## 4. Discord IDの保存先案

推奨は `profiles.discord_handle text` を追加する案。

理由:

- 既存 `discord_user_id` は17〜20桁数字制約つきで、ユーザー入力のDiscord handleには厳しすぎる。
- `discord_name` は意味が曖昧で、既存データがある場合の互換性判断が必要になる。
- `discord_handle` は「連絡先として入力されたDiscord上の識別子」であり、数値IDとは限らないことを列名で表せる。
- `public_profiles` に追加せず、privateな `profiles` 本体だけに保持できる。

UIや画面文言は利用者に伝わりやすい「Discord ID」のままでよい。DB列名とRPC戻り値列は `discord_handle` に統一し、既存 `discord_user_id` や `discord_name`、曖昧な `discord_id` 返却名と混同しないようにする。

## 5. 公開範囲方針

- 本人: 自分のDiscord IDをmypageで登録・編集できる。
- GM/admin: 自分が担当するセッションの承認済み参加者のDiscord IDだけを見られる。
- anon: Discord IDを見られない。
- 通常PL: 他人のDiscord IDを見られない。
- 申請中 / waitlisted: 初期実装ではGM向け表示対象外。
- 辞退 / 取消 / 却下: GM向け連絡先コピー対象外。

初期実装は「承認済み参加者のみGM/adminに表示」を推奨する。申請中の連絡が必要になった場合は、後続工程で明示的に範囲を広げる。

## 6. mypage UI案

`mypage.html` のログイン済みアカウント機能内、表示名設定の近くにDiscord ID欄を置く。

UI案:

- 現在のDiscord ID表示: 未登録の場合は「未登録」。
- 入力欄ラベル: `Discord ID`。
- 保存ボタン: 表示名と別ボタンにして、失敗範囲を狭くする。
- 保存成功: 「Discord IDを保存しました。」。
- 保存失敗: 詳細エラーや内部IDを出さず短文にする。

バリデーション案:

- `trim` する。
- 空欄保存は未登録扱いとして `null` にする。
- 最大100文字。
- 改行禁止。
- HTMLは必ずテキスト扱いにする。
- Discord側のID形式変更に備え、数字限定や厳密な正規表現は使わない。

## 7. GM向けコピー導線案

`session-detail.html` のGM/admin向け申請履歴折りたたみ内、またはその近くに「承認済み参加者連絡先」セクションを追加する。

表示案:

```text
承認済み参加者連絡先
- 表示名A: discord_handle
- 表示名B: 未登録
```

コピー形式案:

```text
表示名A: discord_handle
表示名B: 未登録
```

内部 `user_id`、email、`application_id`、`comment_id`、token、key、secret類は返さず、画面・console・docsにも出さない。

未登録者も表示名つきで出すと、GMが「誰の連絡先が未登録か」を把握できる。ただし返却値は `null` のままにして、UI側で「未登録」表示へ変換するのが扱いやすい。

## 8. 必要RPC案

本人用:

```text
get_my_profile_contact()
update_my_discord_id(new_discord_id text)
```

戻り値:

```text
display_name text
discord_handle text
```

GM/admin用:

```text
get_gm_session_accepted_contacts(target_session_id text)
```

戻り値:

```text
display_name text
discord_handle text
```

返さないもの:

```text
user_id
email
application_id
comment_id
role
discord_user_id
discord_name
token
key
secret類
```

`discord_user_id` / `discord_name` は既存互換・旧仕様寄りの列として扱い、今回のGMコピー導線では返さない。`discord_id` という返却aliasも、既存数値IDとの混同を避けるため採用しない。

`update_my_discord_id` の引数は `new_discord_id` とする。UI文言の「Discord ID」に寄せつつ、戻り値は `discord_handle` として保存列の意味に揃える。既存 `update_display_name(new_display_name text)` と近い入力引数名にし、OUT列名との衝突も避ける。

GM/admin用RPCは `authenticated` のみ実行可能にし、内部で `is_admin()` または `is_session_gm(target_session_id)` を確認する。返却対象は `session_applications.status = 'accepted'` の参加者だけに絞る。

## 9. RLS / smoke test案

追加したい観点:

- anonはDiscord IDを読めない。
- anonは本人用・GM用の連絡先RPCを実行できない。
- 通常PLは自分のDiscord IDだけ読める。
- 通常PLは自分のDiscord IDだけ更新できる。
- 通常PLは他人のDiscord IDを読めない。
- 空欄保存は未登録扱いになる。
- 100文字超は拒否される。
- 改行入りは拒否される。
- 対象GMは担当セッションの承認済み参加者だけ読める。
- 他GMは読めない。
- adminは読める。
- pending / waitlisted / canceled / rejected はGMコピー対象外。
- 連絡先RPCの返却列は `display_name` / `discord_handle` のみ。
- 返却列に `user_id`、email、`application_id`、`comment_id`、role、`discord_user_id`、`discord_name`、token、key、secret類がない。
- エラー整形結果に生の内部IDやsecret類が混ざらない。

## 10. SQL草案

SQL草案を追加した。

```text
docs/supabase/sql/014_discord_id_profile_contact_draft.sql
```

含めたもの:

- `profiles.discord_handle` 追加案。
- 最大100文字、空白のみ禁止、改行禁止の制約案。
- 本人取得RPC `get_my_profile_contact()`。
- 本人更新RPC `update_my_discord_id(new_discord_id text)`。
- GM/admin向け承認済み参加者連絡先取得RPC `get_gm_session_accepted_contacts(target_session_id text)`。
- 戻り値を `display_name` / `discord_handle` に限定し、既存 `discord_user_id` / `discord_name` や曖昧な `discord_id` aliasを返さない方針。
- `grant` / `revoke`。
- preflight。
- post-apply確認。
- rollback草案。
- 停止条件。
- SQL Editor未実行とsecret実値禁止の注意。

M-12A時点では、このSQL草案は実行していない。

## 11. M-12B SQL適用結果

ユーザーがSupabase SQL Editorで `014_discord_id_profile_contact_draft.sql` のapply sectionを実行し、Discord ID連絡先用DB変更を適用済み。Codexはこの結果記録工程でSQL Editor実行、DB変更、本番フロント実装、Discord ID実値の記録、`updates.json` 変更、commit / pushを行っていない。

適用結果:

```text
profiles.discord_handle text
profiles_discord_handle_check
get_my_profile_contact()
update_my_discord_id(new_discord_id text)
get_gm_session_accepted_contacts(target_session_id text)
```

`public_profiles` は `id` / `display_name` のみで、`discord_handle` / `discord_name` / `discord_user_id` は公開viewに出ていない。

3RPCはいずれも `security definer = true`、`search_path = ""`、返却列は `display_name text` / `discord_handle text`。grantは `authenticated EXECUTE` と `postgres EXECUTE` を確認済みで、`anon EXECUTE` はない。`postgres EXECUTE` はownerまたは管理者側の表示として扱う。

制約 `profiles_discord_handle_check` は、`discord_handle is null` 許可、100文字以下、改行禁止を確認済み。確認された制約定義は以下。

```text
CHECK (((discord_handle IS NULL) OR ((char_length(discord_handle) <= 100) AND (discord_handle !~ '[\r\n]'::text))))
```

rollbackは未実行。本人RPC / GM用RPCの実ログイン文脈テストはまだ未実施。SQL適用結果の詳細は `docs/supabase-discord-id-contact-sql-result.md` に記録した。

## 12. 実装段階案

推奨段階:

```text
M-12A: Discord ID登録 / GMコピー導線 調査・設計
M-12B: Discord ID SQL草案レビュー
M-12C: SQL適用 / 結果記録
M-12D: mypage Discord ID登録UI
M-12E: GM向け承認済み参加者Discord ID表示 / コピー
M-12F: RLS smoke test強化
M-12G: 既存 discord_user_id / discord_name の扱い整理
```

`M-12G` は任意だが、既存 `discord_user_id` / `discord_name` の意味を将来混同しないため、DB適用後に別工程で整理すると安全。

## 13. M-12A時点でまだやらないこと

- SQL Editor実行。
- DB変更。
- 本番フロント実装。
- Discord ID実値の記録。
- GM向けコピー機能の本番実装。
- Discord IDを `public_profiles`、公開コメントRPC、公開JSON、anon、通常PL全体へ公開すること。
- 既存 `discord_user_id` / `discord_name` の削除・移行。
- `updates.json` 変更。
- commit / push。
- secret類や実IDの記録。

## 14. M-12C mypage本人用UI実装結果

M-12Cとして、`mypage.html` のログイン済みアカウント機能内に本人用のDiscord ID登録 / 編集UIを追加した。配置は既存の表示名編集UIの直後とし、GMが承認済み参加者へ連絡するために使うこと、未登録でも参加申請は可能であること、公開プロフィールには表示されないことを短く示す。

フロントでは `get_my_profile_contact()` で現在値を取得し、`update_my_discord_id(new_discord_id text)` で保存する。空欄保存は未登録扱い、100文字超過と改行入りは保存前に止める。Discord側の仕様変更に備え、数字限定や `@` 必須などの厳密な正規表現は使わない。

今回の本人UIでは本人の `discord_handle` のみを扱う。email、`user_id`、token、key、secret、`discord_user_id`、`discord_name`、他人の `discord_handle` は画面・console・docsへ出さない。

M-12CではSQL Editor実行、DB変更、GM向けコピー導線、RLS smoke test追加、Discord ID実値入力、`updates.json` 変更、commit / pushは行っていない。詳細は `docs/supabase-discord-id-mypage-ui-result.md` に分離した。

## 15. M-12D GM向け承認済み参加者連絡先UI実装結果

M-12Dとして、`session-detail.html` のGM/admin向け領域に承認済み参加者のDiscord ID表示 / コピー導線を追加した。既存の `is_admin()` / `is_session_gm(target_session_id)` 判定結果を使い、未ログイン、通常PL、判定失敗時はUIを表示しない。

フロントでは `get_gm_session_accepted_contacts(target_session_id text)` を呼び、返却列を `display_name` / `discord_handle` に限定して扱う。未登録者は `未登録` と表示し、コピー文字列にも `未登録` として含める。

email、`user_id`、`application_id`、`comment_id`、`discord_user_id`、`discord_name`、token、key、secret類は表示・コピー対象にしない。Discord ID実値はdocsやconsoleへ記録しない。

M-12DではSQL Editor実行、DB変更、RLS smoke test追加、Discord ID実値入力、`updates.json` 変更、commit / pushは行っていない。詳細は `docs/supabase-discord-id-gm-contact-ui-result.md` に分離した。

## 16. DiscordユーザーID登録方針への変更

テンプレート機能の前提整備として、ユーザー向けの連絡先登録・表示方針を `DiscordユーザーID` へ変更する。

DB列名 `profiles.discord_handle` と既存RPC名 `update_my_discord_id(new_discord_id text)` / `get_my_profile_contact()` / `get_gm_session_accepted_contacts(target_session_id text)` は変更しない。過去セクションの `Discord ID` 表記はM-12時点の履歴として扱い、現在のUIでは17〜20桁の数字を基本形式として保存対象にする。

互換として `<@123456789012345678>` 形式も受け付けるが、保存前に数字部分だけへ正規化する。桁数不正、英字混じり、改行入り、`<@abc>`、`@123456789012345678` は保存しない。既存の形式不正値は自動変換せず、本人画面で再登録を促す。GM向け表示では、保存された数字IDから `<@DiscordユーザーID>` を生成し、未登録または形式不正の値は `登録されていません` へ丸める。

呼び出し用テンプレートでは、GMが承認済み参加者を一人ずつ選ぶ方式にはしない。現在のセッションに紐付く承認済み参加者全員を対象にし、コピー時にテンプレート内の変数をまとめて置換する。

初期実装で優先する変数は `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` とする。`{{approved_call_list}}` は `Discord：<@DiscordユーザーID>｜ユーザー名：ユーザー名｜PC名：PC名` のラベル付き1人1行で出力し、DiscordユーザーIDが未登録または形式不正の場合は `Discord：登録されていません`、PC名未登録の場合は `PC名：PC名未登録` を出す方針を推奨する。

`{{approved_discord_mentions}}` はDiscordメンションだけをまとめて出す変数として残してよいが、呼び出し文で実用性が高いのは `{{approved_call_list}}` とする。`{{approved_discord_ids}}` は初期実装では見送る。

この方針変更でSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、テンプレート保存テーブル作成、テンプレート生成UI、`{{approved_call_list}}` の実際の置換処理、テンプレート保存機能本体、PC名登録機能、mypage予定プルダウン化、`updates.json` 変更、secret類の出力、commit / pushは行っていない。
