# Supabase M-9 mypage display_name SQL草案計画

この文書は、`mypage.html` で表示名を扱う前に必要な Supabase SQL / RPC の追加候補を整理するものです。

この工程では、SQL Editorでの実行、`mypage.html` 実装、`assets/js/mypageAuthClient.js` 実装、commit / push は行わない。

## 1. M-9の目的

- マイページで扱うアカウント名として `display_name` を安全に保存、取得、更新できるようにする。
- Authユーザー作成後に `profiles` 行がない状態を避ける。
- フロント実装前に、`public_profiles` の公開範囲と表示名更新経路を固定する。

## 2. 現在不足しているもの

既存調査では、以下は確認済み。

- `profiles` に `display_name text not null` がある。
- `public_profiles` は `id` / `display_name` のみ返すviewである。
- F-3 devでは `public_profiles.display_name` 取得を確認済み。
- `profiles_update_own` / `profiles_insert_own` のRLS草案はある。

一方で、M-9最小実装には以下が不足している。

- Authユーザー作成時に `profiles` 行を自動作成するtrigger。
- 既存Authユーザーで `profiles` 行がない場合のbackfill手順。
- 本人が表示名だけを更新する `update_display_name` RPC。
- SQL適用後の確認観点。

## 3. 追加SQL草案の概要

追加SQL草案は以下に分離する。

```text
docs/supabase/sql/009_profiles_display_name_rpc_draft.sql
```

含める内容:

- 事前確認SQL。
- `public.handle_new_auth_user_profile()` trigger function案。
- `on_auth_user_created_create_profile` trigger案。
- 既存ユーザーbackfill案。
- `public.update_display_name(new_display_name text)` RPC案。
- `public_profiles` 最小公開確認。
- RLS / security確認。
- SQL適用後のテスト観点。

## 4. profiles自動作成trigger方針

Authユーザー作成時に `public.profiles(id, display_name)` を作る。

方針:

- `auth.users` insert時に `public.profiles` へ本人の行を作成する。
- `raw_user_meta_data.display_name` があれば初期値として使う。
- なければ `名無しの冒険者` を使う。
- 40文字を超える場合は初期値として40文字までに丸める。
- `email` は `profiles` に保存しない。
- `discord_user_id`、`discord_name`、role、tokenは保存しない。
- 既存 `profiles` 行がある場合は上書きしない。

関数名案:

```text
public.handle_new_auth_user_profile()
```

trigger名案:

```text
on_auth_user_created_create_profile
```

## 5. 既存ユーザーbackfill方針

既に `auth.users` にいるが `profiles` 行がないユーザーへ、本人の `profiles` 行だけを補完する。

実行前に、欠損件数のみ確認する。実user_id全文はチャット、README、docsへ転記しない。

方針:

- `auth.users` と `public.profiles` を照合する。
- `profiles` がないユーザーだけ `insert` する。
- 既存 `profiles` は上書きしない。
- 初期 `display_name` は `raw_user_meta_data.display_name`、なければ `名無しの冒険者`。
- `email` / `discord_user_id` / role / token は保存しない。

## 6. update_display_name RPC方針

本人が自分の表示名だけを更新するRPCを追加する。

関数名案:

```text
public.update_display_name(new_display_name text)
```

方針:

- `auth.uid()` がnullなら拒否する。
- `new_display_name` が空なら拒否する。
- 40文字を超える名前は拒否する。
- `profiles` 行がない場合は本人分だけ作成する。
- `updated_at` を更新する。
- 戻り値は `id` / `display_name` のみに限定する。
- `email` / token / role / `discord_user_id` は返さない。
- `grant execute` は `authenticated` のみに付与する。
- `anon` にはexecuteさせない。

## 7. public_profiles最小公開方針

現行の `public_profiles` が `id` / `display_name` のみならview変更は不要。

確認すること:

- `public_profiles` の列が `id` / `display_name` のみである。
- `discord_user_id`、`discord_name`、email、role、tokenを返さない。
- `anon` / `authenticated` の `select` は `public_profiles` のみに限定する。
- `profiles` 本体をanon公開しない。

## 8. RLS / security方針

- `profiles` 本体をanon公開しない。
- 表示名の公開は `public_profiles` の最小列に限定する。
- 本人更新は直接 `profiles` UPDATE を広げるより、`update_display_name` RPCへ寄せる。
- RPCは `security definer` とし、`auth.uid()` を必ず確認する。
- RPCの戻り値にemail、token、role、`discord_user_id` を含めない。
- service role key、secret key、DB passwordは使わない。

## 9. 実行前確認

SQL Editorで実行する前に、少なくとも以下を確認する。

- `profiles` のカラムと制約。
- `profiles.id` が `auth.users.id` に対応する外部キーであること。
- `profiles.display_name` がnot nullであること。
- `public_profiles` の定義と列。
- `profiles` のRLS有効化状態。
- `profiles` の既存policy。
- 既存のprofile関連trigger / RPCの有無。
- `auth.users` に対して `profiles` が欠損している件数。

## 10. 実行後検証

SQL適用後は、以下を確認する。

- 未ログインで `update_display_name` が拒否される。
- 本人が自分の `display_name` を更新できる。
- 空文字が拒否される。
- 40文字超が拒否される。
- `public_profiles` から `id` / `display_name` のみ読める。
- `profiles` 本体にemail / token / roleが出ない。
- 既存ユーザーbackfill後に `profiles` が作られる。
- 新規signUp後に `profiles` が自動作成される。
- 実メール、実パスワード、実Project URL、API key、tokenを画面、console、docsへ出していない。

## 11. まだ扱わないもの

- `mypage.html` 実装。
- display_nameフォーム実装。
- `assets/js/mypageAuthClient.js` 実装。
- 自分の申請一覧。
- 参加予定。
- `session-detail.html` 統合。
- GM操作。
- Discord連携。
- 追加通知。
