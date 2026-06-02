# M-15B PC名登録・参加申請PC紐付け SQL草案

## 目的

M-15Aで整理したPC名登録方針をもとに、後続レビュー用のSELECT-only preflight SQLと、まだ実行しないSQL草案を作成した。

今回の工程ではSQL Editor実行、DB構造変更、RPC作成 / 置換、GRANT / REVOKE、フロントUI実装、PC名登録UI実装、参加申請UI変更、テンプレート保存機能実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行わない。

## 作成ファイル

```text
docs/supabase/sql/019_player_characters_preflight_select_only.sql
docs/supabase/sql/019_player_characters_rpc_draft.sql
```

`019_player_characters_preflight_select_only.sql` はcatalog確認専用で、SELECT / WITH SELECT / information_schema / pg_catalog / to_regclass / to_regprocedure の範囲に限定する。

`019_player_characters_rpc_draft.sql` は実行しない草案で、player_characters、session_applications追加列、PC名管理RPC、参加申請RPCへの影響、テンプレート用RPC候補、権限案、post-apply確認案をまとめる。

## preflightで確認すること

- `public.profiles` の存在と主要列。
- `profiles` と `auth.users` の関係。
- `public.session_applications` の存在。
- `session_applications` の列一覧。
- `session_applications` の主キー。
- `session_applications` の `user_id` / `session_id` / `status` / `comment_id`。
- `session_applications` の既存制約。
- `session_applications` と `public.sessions` / `public.profiles` / `public.session_comments` の外部キー。
- 既存 `player_characters` テーブルの有無。
- 既存 `selected_character_id` / `pc_name_snapshot` 列の有無。
- PC名関連RPC候補の有無。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)`。
- routine privileges。
- RLS policy候補。
- direct table privileges。

## player_characters テーブル案

推奨列:

```text
id uuid primary key default gen_random_uuid()
owner_user_id uuid not null references public.profiles(id) on delete cascade
pc_name text not null
is_default boolean not null default false
is_active boolean not null default true
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

`owner_user_id` は `auth.users(id)` 直接参照ではなく `public.profiles(id)` 参照を推奨する。既存のサイト側ユーザー情報は `profiles.id` を軸にしており、`profiles` 自体が `auth.users(id)` に紐付いているため。

PC名制約:

- `trim` 後に空でない。
- 40文字以内。
- 改行禁止。
- HTMLはUI側でテキスト扱い。

同一ユーザー内の同名PC:

- 初期草案ではDB上の一意制約は置かない。
- 既存PC名の再利用、別システム/別シナリオ由来の同名を許容する。
- UI側では重複注意表示を後続検討にする。

デフォルトPC:

- activeなPCのうち、1ユーザーにつき1件だけ `is_default = true` とする。
- partial unique index `owner_user_id where is_default = true and is_active = true` で制限する案。

削除:

- 物理削除ではなく `is_active = false` を推奨する。
- 過去の参加申請やリザルト出力は `session_applications.pc_name_snapshot` を正として維持する。

## session_applications 追加列案

```text
selected_character_id uuid null references public.player_characters(id) on delete set null
pc_name_snapshot text null
```

方針:

- 参加申請時点のPC名を `pc_name_snapshot` に保存する。
- PC名マスター変更後も、過去申請や承認済みセッションのPC名が勝手に変わらないようにする。
- `selected_character_id` は元キャラクターとの紐付けとして使う。
- テンプレート出力では `pc_name_snapshot` を優先し、未登録時は `PC名未登録` とする。

## RPC案

MVP候補:

```text
get_my_player_characters()
create_player_character(p_pc_name text, p_is_default boolean)
update_player_character(p_character_id uuid, p_pc_name text, p_is_default boolean, p_is_active boolean)
set_default_player_character(p_character_id uuid)
deactivate_player_character(p_character_id uuid)
```

`delete_player_character` という名前はUI文言上の削除に近いが、初期実装では物理削除を避け、RPC名も `deactivate_player_character` を推奨する。UIで「削除」と表示する場合も内部処理は `is_active = false` とする。

参加申請連携候補:

```text
create_application_comment(target_session_id text, comment_body text) の置換
update_my_application_character(target_session_id text, target_character_id uuid)
```

テンプレート用候補:

```text
get_gm_session_approved_template_data(target_session_id text)
```

返却列候補:

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

## 参加申請との紐付け方針

現行仕様では、参加希望コメント投稿RPC `create_application_comment(target_session_id, comment_body)` がコメント投稿と参加申請行作成を兼ねている。

後続でこのRPCを置換する場合は、申請行作成時または `canceled -> pending` 復帰時に本人のdefault PCを読み、`selected_character_id` と `pc_name_snapshot` を保存する。

PC名未登録の場合:

```text
selected_character_id = null
pc_name_snapshot = null
```

テンプレート出力では `PC名未登録` に丸める。

辞退 / 再申請:

- 辞退時は既存どおり申請行を `canceled` にし、PCスナップショットは残してよい。
- 再申請時は、その時点のdefault PCで `selected_character_id` / `pc_name_snapshot` を更新する。

GMコメント:

- GM本人コメントは参加申請扱いしない既存方針を維持する。
- 現在のフロントはGMコメント投稿後にGM本人申請行を `canceled` へ戻す補正をしている。
- PC名スナップショット追加後も、GM本人が参加者扱いで `accepted` に混ざらないようにする。

## テンプレート変数との関係

`{{approved_call_list}}` に必要なデータ:

```text
session_title
display_name
discord_handle
pc_name_snapshot
```

出力:

```text
<@DiscordユーザーID> 表示名 PC名
登録されていません 表示名 PC名未登録
```

`{{approved_pc_names}}` に必要なデータ:

```text
pc_name_snapshot
```

出力:

```text
PC名1、PC名2、PC名未登録
```

DiscordユーザーIDは既存方針どおり、17〜20桁の数字なら `<@ID>` に変換し、未登録または形式不正なら `登録されていません` とする。

## 既存GM連絡先RPCとの関係

`get_gm_session_accepted_contacts(target_session_id text)` は現在 `display_name` / `discord_handle` のみを返し、フロントJSもこの返却列を前提に検査している。

そのためM-15B草案では、既存RPCをすぐPC名付きへ変更せず、テンプレート用の別RPC `get_gm_session_approved_template_data(target_session_id text)` 候補を置いた。

後続M-15Fで、以下のどちらかを選ぶ。

- テンプレートUIだけ別RPCを使う。
- JS側の返却列検査と表示を更新した上で、既存連絡先RPCをPC名付きへ置換する。

## 段階実装案

1. M-15B: preflight SELECT-only SQLとSQL草案作成。
2. M-15C: ユーザーがSQL Editorでpreflightを実行した場合の結果記録と草案レビュー。
3. M-15D: reviewed apply SQL作成または草案修正。
4. M-15E: SQL適用結果記録。
5. M-15F: mypage PC名登録UI。
6. M-15G: 参加申請へのPC名スナップショット接続。
7. M-15H: GM向け承認済み参加者情報とテンプレート変数置換UI。

## 今回やらないこと

- SQL Editor実行。
- DB構造変更。
- RPC作成 / 置換。
- GRANT / REVOKE。
- フロントUI実装。
- PC名登録UI実装。
- 参加申請UI変更。
- テンプレート保存機能実装。
- Discord実送信。
- Edge Function deploy。
- `updates.json` 変更。
- service_role key利用。
- secret類の出力。
- commit / push。
