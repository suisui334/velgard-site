# Supabase M-12B Discord ID連絡先SQL適用結果

作業日: 2026-06-01

## 1. 記録範囲

ユーザーがSupabase SQL Editorで `docs/supabase/sql/014_discord_id_profile_contact_draft.sql` のapply sectionを実行し、Discord ID連絡先用のDB変更を適用済み。

このdocs記録工程でCodexは、Supabase SQL Editor実行、DB変更、本番フロント実装、Discord ID実値の記録、`updates.json` 変更、commit / pushを行っていない。

## 2. 適用済みDB要素

追加・作成済み:

```text
profiles.discord_handle text
profiles_discord_handle_check
get_my_profile_contact()
update_my_discord_id(new_discord_id text)
get_gm_session_accepted_contacts(target_session_id text)
```

`profiles.discord_handle` は今回追加された、PL本人が入力する現代Discord ID/handle用の非公開連絡先列として扱う。既存 `profiles.discord_user_id` / `profiles.discord_name` とは役割を分離し、今回のGM向け連絡先コピー導線では返却・更新対象にしない。

## 3. profiles列確認結果

SQL Editorで、`profiles` に以下が存在することを確認済み。

```text
id uuid not null
display_name text not null
discord_user_id text nullable
discord_name text nullable
discord_handle text nullable
```

実Discord ID、email、user_id全文、secret類はこのdocsに記録していない。

## 4. public_profiles非露出確認結果

`public_profiles` は以下のみであることを確認済み。

```text
id
display_name
```

`discord_handle` / `discord_name` / `discord_user_id` は公開viewに出ていない。anonや通常PL全体へDiscord連絡先を公開しない方針を維持する。

## 5. RPC定義確認結果

以下3RPCの作成を確認済み。

```text
get_my_profile_contact()
```

- `security definer = true`
- volatility: `stable`
- 戻り値: `display_name text`, `discord_handle text`
- `search_path = ""`

```text
update_my_discord_id(new_discord_id text)
```

- `security definer = true`
- volatility: `volatile`
- 戻り値: `display_name text`, `discord_handle text`
- `search_path = ""`

```text
get_gm_session_accepted_contacts(target_session_id text)
```

- `security definer = true`
- volatility: `stable`
- 戻り値: `display_name text`, `discord_handle text`
- `search_path = ""`

返却列は `display_name` / `discord_handle` に限定する。`user_id`、email、`application_id`、`comment_id`、role、`discord_user_id`、`discord_name`、token、key、secret類は返さない方針。

## 6. grant確認結果

3RPCすべてで以下を確認済み。

```text
authenticated EXECUTE
postgres EXECUTE
```

以下は存在しないことを確認済み。

```text
anon EXECUTE
```

`postgres EXECUTE` はownerまたは管理者側の表示として扱い、client向けの広いgrantとは扱わない。

## 7. 制約確認結果

`profiles_discord_handle_check` を確認済み。

確認された制約定義:

```text
CHECK (((discord_handle IS NULL) OR ((char_length(discord_handle) <= 100) AND (discord_handle !~ '[\r\n]'::text))))
```

確認できること:

- `discord_handle is null` を許可する。
- `char_length(discord_handle) <= 100`。
- CR / LF の改行を禁止する。

空欄入力を未登録扱いの `null` にする挙動は、`update_my_discord_id(new_discord_id text)` 側のtrim / null変換方針として扱う。直接table更新の広い権限は前提にしない。

## 8. 未実施

未実行:

- rollback。
- 本人RPCの実ログイン文脈テスト。
- GM用RPCの対象GM / 他GM / admin / 通常PL / anon文脈テスト。
- 本番フロント実装。
- Discord ID実値入力。
- RLS smoke test追加。

本人/GM文脈の確認は、SQL Editorのowner/editor文脈ではなく、後続の reviewed client または `scripts/supabase-rls-smoke-test.mjs` 強化後に行う。

## 9. 再実行注意

`014_discord_id_profile_contact_draft.sql` のapply sectionは適用済みのため、通常運用で同じapply sectionをそのまま再実行しない。

変更・再適用が必要になった場合は、先に現DBの列、制約、関数定義、grant、返却列、既存データの有無を確認し、別工程で差分SQLとrollback方針をレビューする。

## 10. 次工程候補

SQL適用結果をcommitした後の次工程候補:

- `mypage.html` のDiscord ID登録UI。
- `get_my_profile_contact()` / `update_my_discord_id(new_discord_id text)` / `get_gm_session_accepted_contacts(target_session_id text)` のRLS smoke test追加。
- GM向け承認済み参加者連絡先表示 / コピー導線。

このdocs記録工程ではcommit / pushは行っていない。
