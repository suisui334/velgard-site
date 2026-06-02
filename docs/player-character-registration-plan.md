# M-15A PC名登録・テンプレート変数前提設計

## 目的

テンプレート機能で使う `{{approved_call_list}}` と `{{approved_pc_names}}` のために、承認済み参加者のPC名を安全に保存・取得できる前提を整理する。

今回の工程では調査・設計・docs整理のみを行う。SQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行わない。

## 現状確認

- mypageの参加申請中 / 参加予定は `session_applications` を本人文脈で取得し、`pending` / `waitlisted` / `accepted` だけを表示している。
- session-detailのGM向け承認済み参加者連絡先は `get_gm_session_accepted_contacts(target_session_id text)` を使い、返却列は `display_name` / `discord_handle` に限定している。
- `profiles.discord_handle` はDiscordユーザーID保存先として使っているが、PC名はまだ保存していない。
- 現在の `session_applications` には `pc_name` / `character_id` 相当の列がない。
- テンプレート方針では、初期優先変数を `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` としている。

## PC名保存方式の候補

### 候補A: profilesにdefault_pc_nameを追加する

利点:

- 実装が単純。
- mypageで1つだけ登録しやすい。
- 初期実装は軽い。

弱点:

- 複数PCに弱い。
- セッションごとに違うPCで参加する場合に不自然。
- 参加申請時点のPC名を固定できず、後からプロフィールを変えると過去セッションのリザルト出力も変わってしまう可能性がある。

評価:

短期の仮実装としては可能だが、リザルトテンプレート運用には弱い。M-15系の正本にはしない方がよい。

### 候補B: player_charactersテーブルを作る

列候補:

```text
id uuid
owner_user_id uuid
pc_name text
is_default boolean
is_active boolean
created_at timestamptz
updated_at timestamptz
```

利点:

- 複数PCに対応できる。
- mypageでPC名一覧、デフォルトPC、編集、無効化を扱える。
- 後続で参加申請時のPC選択へ繋げやすい。

弱点:

- 初期実装が少し重い。
- 一覧UI、デフォルト設定、削除/無効化方針が必要。
- セッション参加時点のPC名を固定するには、`session_applications` 側にもスナップショットが必要。

評価:

将来拡張の土台として最も自然。ただし単独ではリザルト出力の時点固定に弱い。

### 候補C: session_applications側にpc_nameを保存する

列候補:

```text
pc_name_snapshot text
```

利点:

- 参加申請時点のPC名をセッションごとに固定できる。
- リザルトテンプレートや承認済み参加者一覧と相性がよい。
- PC名変更後も、そのセッションで使ったPC名を維持できる。

弱点:

- mypageでPC名を事前管理する用途とは別になる。
- 申請ごとに入力が必要になりやすい。
- 複数PCの管理やデフォルトPCの概念を別途持ちにくい。

評価:

テンプレート出力には強いが、PC名登録機能としては単体だと弱い。

## 推奨方式

推奨は、候補Bと候補Cを組み合わせる方式。

```text
player_characters テーブルでPC名を管理する
session_applications に selected_character_id と pc_name_snapshot を持たせる
初期実装では default PC を自動採用する
後続で参加申請時PC選択へ拡張する
```

設計理由:

- mypageではPC名一覧とデフォルトPCを管理できる。
- 参加申請時は、申請行へ `pc_name_snapshot` を保存して、セッションごとの参加PC名を固定できる。
- 後からPC名マスターを編集しても、過去または承認済みセッションのテンプレート出力が勝手に変わりにくい。
- 初期UIは単一PC名またはデフォルトPCだけでも始められ、複数PC選択UIを後続へ回せる。

`selected_character_id` はPCマスターとの関連を残すために使う。ただしPCが削除/無効化されてもテンプレート出力に必要な名前は `pc_name_snapshot` を正とする。

## mypage側PC名登録方針

初期実装では、mypageのログイン済みアカウント機能内に「PC名」セクションを置く。

初期UI:

- PC名登録欄。
- 現在のデフォルトPC表示。
- PC名が未登録なら `PC名未登録` と表示。
- 保存ボタンはDiscordユーザーIDや表示名とは分ける。
- PC名は空欄保存で未登録扱い、またはデフォルトPCなしに戻す。

複数PC対応を見据えたUI:

- PC名一覧。
- デフォルトPCのバッジ。
- `デフォルトにする` 操作。
- 編集。
- 削除ではなく初期は `非表示` / `使わない` 相当の `is_active = false` を推奨。

削除方針:

- 過去の参加申請やリザルト出力に影響しないよう、初期は物理削除より `is_active = false` を推奨する。
- `session_applications.pc_name_snapshot` があるため、PCマスターを非表示にしてもセッション側のPC名は維持する。

バリデーション案:

- `trim` 後に1文字以上。
- 最大40文字程度。
- 改行禁止。
- HTMLはテキスト扱い。
- 内部IDや実user_idは画面・consoleに出さない。

## 参加申請との紐付け方針

初期方針:

- 参加申請時に、本人のデフォルトPCがあれば `session_applications.pc_name_snapshot` に保存する。
- デフォルトPCが未登録なら `pc_name_snapshot = null` とし、テンプレートでは `PC名未登録` と出す。
- 既存 `create_application_comment(target_session_id, comment_body)` を後続で置換し、申請行作成または `canceled -> pending` 復帰時にPC名スナップショットを保存する方向で検討する。

後続拡張:

- 参加申請フォームにPC選択UIを追加する。
- 選択したPCの `selected_character_id` と、その時点の `pc_name_snapshot` を申請行へ保存する。
- 申請後のPC名変更は、本人が申請中 / 承認済みの自分の申請に対して変更できるRPCを用意するか、GM承認後はGM確認が必要かを別工程で決める。

承認済み参加者一覧:

- GM向け承認済み参加者情報取得RPCは、`display_name` / `discord_handle` に加えて `pc_name_snapshot` を返す後続案とする。
- 返却対象は引き続き `session_applications.status = 'accepted'` のみを基本にする。
- GM本人は参加者扱いしない方針を維持する。
- raw `user_id`、email、`application_id`、`comment_id`、token、key、secret類は返さない。

## テンプレート変数との関係

### `{{session_title}}`

必要データ:

```text
sessions.title
```

出力:

```text
セッションタイトル
```

### `{{approved_call_list}}`

必要データ:

```text
accepted参加者の display_name
accepted参加者の discord_handle
accepted参加者の pc_name_snapshot
```

初期出力方針:

```text
<@123456789012345678> 表示名 PC名
登録されていません 表示名 PC名
<@234567890123456789> 表示名 PC名
```

ルール:

- DiscordユーザーIDが17〜20桁の数字として登録済みなら `<@DiscordユーザーID>` に変換する。
- DiscordユーザーIDが未登録または形式不正なら `登録されていません` を出す。
- PC名が未登録なら `PC名未登録` を出す。

### `{{approved_pc_names}}`

必要データ:

```text
accepted参加者の pc_name_snapshot
```

初期出力方針:

```text
トレクティア、ロエアス、PC名未登録
```

ルール:

- 承認済み参加者の順序は `{{approved_call_list}}` と揃える。
- 未登録は空欄にせず `PC名未登録` を含める。

## 後続SQL/RPC候補

### SQL候補

```text
player_characters テーブル追加
session_applications.selected_character_id 追加
session_applications.pc_name_snapshot 追加
player_characters の owner_user_id / is_default / is_active index
owner_user_id ごとの default PC 一意化用 partial unique index
```

`session_applications.pc_name_snapshot` はテンプレート出力の正本として扱う。`selected_character_id` は参照・再選択・将来UI用であり、PC名表示はスナップショットを優先する。

### RPC候補

本人PC管理:

```text
get_my_player_characters()
create_player_character(pc_name text, make_default boolean)
update_player_character(character_id uuid, pc_name text)
delete_player_character(character_id uuid) または deactivate_player_character(character_id uuid)
set_default_player_character(character_id uuid)
```

参加申請連携:

```text
create_application_comment(...) の置換
update_my_application_character(target_session_id text, character_id uuid)
```

GM/テンプレート用:

```text
get_gm_session_accepted_contacts(...) のPC名対応版
または get_gm_session_approved_template_data(target_session_id text)
```

テンプレート専用RPCを作る場合の返却列候補:

```text
session_title text
display_name text
discord_handle text
pc_name_snapshot text
```

返さないもの:

```text
user_id
email
application_id
comment_id
selected_character_id
owner_user_id
role
token
key
secret類
```

## 段階実装案

### M-15B SQL草案

- `player_characters` テーブル草案。
- `session_applications` への `selected_character_id` / `pc_name_snapshot` 追加草案。
- PC名管理RPC草案。
- 既存 `create_application_comment` / `get_gm_session_accepted_contacts` への影響整理。
- SQL Editorはまだ実行しない。

### M-15C SQL適用結果記録

- ユーザーがSQL Editorで適用した場合、その結果だけdocsへ記録する。
- Codex側では追加実行しない。

### M-15D mypage PC名登録UI

- 初期は単一デフォルトPC登録または簡易一覧。
- 空欄 / 未登録表示。
- display_name / DiscordユーザーID導線を壊さない。

### M-15E 参加申請へのPC名スナップショット接続

- 参加申請投稿時にデフォルトPC名を `pc_name_snapshot` へ保存する。
- 再申請時もスナップショットを更新する。
- 既存PL申請 / 辞退 / 再申請導線を壊さない。

### M-15F GM向け承認済み参加者情報のPC名対応

- GM向け承認済み参加者連絡先表示にPC名を追加する。
- `{{approved_call_list}}` / `{{approved_pc_names}}` 用データを取得できるようにする。

### M-15G テンプレート変数置換UI

- テンプレート保存本体またはコピー用テンプレートUIを実装する。
- 初期変数は `{{session_title}}` / `{{approved_call_list}}` / `{{approved_pc_names}}` を優先する。

## 停止条件

- PC名をpublic profileやanon向け公開RPCへ出す必要が出た場合は、公開範囲を再設計する。
- 申請後PC変更をGM承認後も自由に許すか、GM確認制にするかが未決の場合は、保存RPCの仕様を確定する前に止める。
- 既存 `create_application_comment` の置換がPL再申請、GMコメント、辞退導線に影響する場合は、SQL適用前に分割する。
- 実ID、email、token、key、secret類、実Discord ID、実PC名の全文記録が必要になりそうな場合はdocs記録を止める。

## 今回やらないこと

- SQL Editor実行。
- DB構造変更。
- RPC作成 / 置換。
- GRANT / REVOKE。
- フロントUI実装。
- テンプレート保存機能本体。
- PC名登録UI実装。
- Discord実送信。
- Edge Function deploy。
- `updates.json` 変更。
- service_role key利用。
- secret類の出力。
- commit / push。

## M-15B SQL草案作成

M-15Bとして、PC名登録・参加申請PC紐付け用のSELECT-only preflight SQLと、まだ実行しないSQL草案を作成した。

作成ファイル:

```text
docs/supabase/sql/019_player_characters_preflight_select_only.sql
docs/supabase/sql/019_player_characters_rpc_draft.sql
docs/player-character-registration-sql-plan.md
```

preflight専用SQLでは、`public.profiles`、`public.session_applications`、既存 `player_characters`、`selected_character_id` / `pc_name_snapshot`、PC名関連RPC候補、helper関数、routine privileges、RLS policy候補をSELECT-onlyで確認する。

SQL草案では、`player_characters` テーブル、`session_applications.selected_character_id` / `pc_name_snapshot`、PC名管理RPC、既存 `create_application_comment` へのdefault PC自動採用、テンプレート用 `get_gm_session_approved_template_data(target_session_id text)` 候補を整理した。

既存 `get_gm_session_accepted_contacts(target_session_id text)` は現在のフロント返却列チェックと結びついているため、M-15B草案ではすぐPC名付きへ置換せず、テンプレート用の別RPC候補を置く方針とした。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更、service_role key利用、secret類の出力、commit / pushは行わない。
