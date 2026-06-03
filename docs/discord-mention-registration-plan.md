# DiscordユーザーID登録方針

## 目的

呼び出し用テンプレートで承認済み参加者をまとめてメンションできるようにするため、Discord連絡先登録は17〜20桁の数字であるDiscordユーザーIDとして扱う。

既に `<@ID>` 形式で入力・保存された値がある可能性を考慮し、UIでは `<@123456789012345678>` 形式の入力も互換として受け付ける。ただし保存前に数字部分だけへ正規化し、保存値は `123456789012345678` のような数字IDに寄せる。

呼び出し文で初期実装時に優先する変数は `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` とする。

`{{approved_discord_mentions}}` は、保存済みのDiscordユーザーIDからDiscordメンションを生成してまとめて出す変数として後続候補に残してよい。`{{approved_discord_ids}}` は初期実装では見送る。

## UI方針

ユーザー向けの表記は `DiscordユーザーID` に寄せる。DB列名や既存RPC名は変更しない。

入力欄の近くには、DiscordユーザーIDは17〜20桁の数字で入力することを赤字で表示する。入力例 `123456789012345678` も常に見えるようにする。

保存前チェックは `^\d{17,20}$` を基本にする。互換として `^<@\d{17,20}>$` も受け付けるが、保存時は数字だけに正規化する。空欄は未登録扱いとして残せる。

英字混じり、桁数不正、改行入り、`<@abc>`、`@123456789012345678` は保存しない。既に形式不正の値が保存されている場合、自動変換はしない。本人画面では再登録を促し、GM向けの承認済み参加者連絡先表示では生の不正値を出さず、`登録されていません` と表示する。

## テンプレート方針

呼び出し用テンプレートでは、GMが承認済み参加者を一人ずつ選ぶ方式にはしない。現在のセッションに紐付く承認済み参加者全員を対象にし、コピー時にテンプレート内の変数をまとめて置換する。

`{{approved_call_list}}` は、承認済み参加者のDiscordメンション、ユーザー名、PC名を1人1行でまとめて出力する。呼び出し文で実用性が高いため、初期実装では `{{approved_discord_mentions}}` より優先して扱う。

出力形式:

```text
<@123456789012345678> ユーザー名 PC名
登録されていません ユーザー名 PC名
<@234567890123456789> ユーザー名 PC名
```

DiscordユーザーIDが登録済みで形式が正しい場合は、`<@DiscordユーザーID> ユーザー名 PC名` の形式で出力する。DiscordユーザーIDが未登録、または形式不正の場合は、メンション部分を `登録されていません` に置き換える。

PC名が未登録の場合は、初期方針として `PC名未登録` を出すことを推奨する。リザルトテンプレート運用を考えると、PC名が未登録であることが明示される方が望ましい。

```text
<@123456789012345678> ユーザー名 PC名未登録
```

`{{approved_discord_mentions}}` は、承認済み参加者全員のDiscordメンションだけをまとめて出力する変数として後続候補に残してよい。`{{approved_pc_names}}` は承認済み参加者のPC名一覧を出す変数候補とし、PC名未登録時は `PC名未登録` を含める方針を優先する。

## 今回やらないこと

DB構造変更、SQL Editor実行、RPC作成 / 置換、GRANT / REVOKE、Discord実送信、Edge Function deploy、テンプレート保存テーブル作成、テンプレート生成UI、`{{approved_call_list}}` の実際の置換処理、テンプレート保存機能本体、PC名登録機能、mypage予定プルダウン化、`updates.json` 変更、service_role key利用は行わない。

## M-15A PC名登録との接続方針

`{{approved_call_list}}` と `{{approved_pc_names}}` には、承認済み参加者のセッション参加PC名が必要になる。M-15Aでは、PC名保存方式として `player_characters` テーブルでPC名を管理し、`session_applications` に `selected_character_id` と `pc_name_snapshot` を持たせる複合案を推奨する。

テンプレート出力では `pc_name_snapshot` を優先する。これにより、mypageでPC名マスターを後から編集しても、そのセッションで承認済みになった参加PC名を固定しやすい。PC名が未登録の場合は、引き続き `PC名未登録` を出す。

初期実装ではmypageのデフォルトPCを参加申請時に自動採用し、後続で申請時PC選択へ拡張する。SQL Editor実行、DB構造変更、RPC変更、フロントUI実装、テンプレート置換処理はM-15Aでは行わない。詳細は `docs/player-character-registration-plan.md` に整理した。

## M-15B SQL草案との関係

M-15Bでは、`player_characters` と `session_applications.pc_name_snapshot` のSQL草案を作成した。`{{approved_call_list}}` / `{{approved_pc_names}}` の取得元は、承認済み参加者の `display_name`、`discord_handle`、`pc_name_snapshot` とする。

既存 `get_gm_session_accepted_contacts(target_session_id text)` は現在 `display_name` / `discord_handle` の返却列でフロント接続済みのため、M-15B草案ではテンプレート用の別RPC候補 `get_gm_session_approved_template_data(target_session_id text)` を置いた。後続でテンプレートUIだけ別RPCへ接続するか、既存連絡先RPCをPC名付きへ置換するかを選ぶ。

M-15BではSQL Editor実行、DB構造変更、RPC変更、フロントUI実装、テンプレート変数置換処理は行わない。

## M-15B preflight結果との接続

ユーザーがSQL Editorで実行した `019_player_characters_preflight_select_only.sql` はSELECT-only preflightのみで、DB構造変更やRPC作成は行っていない。
結果として、`player_characters`、`session_applications.selected_character_id`、`session_applications.pc_name_snapshot` は未作成であることを確認した。

テンプレート変数方針は維持し、`{{approved_call_list}}` / `{{approved_pc_names}}` のPC名取得元は後続で追加する `session_applications.pc_name_snapshot` とする。
`pc_name_snapshot` は nullable text とし、未登録時はテンプレート出力側で `PC名未登録` に丸める。
`selected_character_id` は `player_characters(id) on delete set null`、PC名マスターは原則 `is_active = false` による非アクティブ化を基本とするため、呼び出し用テンプレートでは過去申請の `pc_name_snapshot` を正として扱う。

今回CodexはSQL Editor追加実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、テンプレート変数置換処理、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-15C APPLY専用SQLとの接続

M-15Cでは、PC名登録のAPPLY専用SQL `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を作成した。
SQL Editorで実行する場合はこのAPPLY専用ファイル全文のみを使い、draft全文は貼らない。

APPLY専用SQLは、`player_characters` と `session_applications.pc_name_snapshot` の土台、PC管理RPC、実行後確認SELECTまでに絞った。
`{{approved_call_list}}` / `{{approved_pc_names}}` の実際の置換処理、テンプレート用RPC接続、参加申請時にdefault PCを `pc_name_snapshot` へ保存する処理は後続に残す。

APPLYはまだ未実行。
今回CodexはSQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE実行、フロントUI実装、テンプレート変数置換処理、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。

## M-15D APPLY結果との接続

ユーザーがSupabase SQL Editorで `docs/supabase/sql/019_player_characters_apply_reviewed.sql` を適用し、`player_characters` と `session_applications.pc_name_snapshot` のDB土台が作成済みになった。
`session_applications.selected_character_id` は `player_characters(id)` を参照し、`player_characters.owner_user_id` は `profiles(id)` を参照する。

PC管理RPC 5本は作成済みで、各RPCは `security_definer = true`。
権限は `authenticated EXECUTEあり`、`anon / public EXECUTEなし` と確認済み。

テンプレート変数方針は維持する。
`{{approved_call_list}}` / `{{approved_pc_names}}` の出力に必要な `pc_name_snapshot` はDB列として用意されたが、参加申請時の保存接続、テンプレート用RPC接続、テンプレート変数置換UIはまだ未実装。

次工程はM-15Eとして mypage PC名登録UI。
今回CodexはSQL Editor追加実行、DB構造追加変更、RPC再作成、GRANT / REVOKE再実行、実データ投入、フロントUI実装、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。
## M-15E PC名登録UIとの関係

M-15EでmypageにPC名登録UIを追加した。DiscordユーザーID登録UIそのものは変更せず、後続テンプレート変数 `{{approved_call_list}}` / `{{approved_pc_names}}` のためのPC名管理導線を追加した扱いとする。

呼び出し用テンプレートでは、DiscordユーザーIDから生成する `<@DiscordユーザーID>`、ユーザー名、PC名を組み合わせる。PC名は後続工程で `session_applications.pc_name_snapshot` を正として使う方針を維持し、M-15E時点では参加申請へのスナップショット保存やテンプレート置換処理はまだ実装していない。

今回CodexはSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushを行っていない。
