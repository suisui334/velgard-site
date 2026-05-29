# Supabaseプロトタイプ設計メモ

## 1. 目的

ヴェルガルド公開サイトは、現時点では GitHub Pages 上で動作する静的サイトである。

実コメント投稿、コメント編集、参加申請、〆ボタン、GM編集、認証、Discord同期を行うには、ブラウザだけで完結しない外部DB/APIと権限管理が必要になる。

現時点の第一候補は Supabase とする。ただし、まだ Supabase 登録、プロジェクト作成、SQL実行、本番サイト接続は行わない。まずは本番サイトとは分離した別環境プロトタイプで、認証、RLS、申請者単位カウント、GM権限、〆状態の扱いを検証する。

## 2. 現時点の採用候補

### 第一候補：Supabase

理由：

- Postgresでリレーション設計しやすい
- 参加人数を申請者単位で数える設計に向いている
- Auth / RLS / Edge Functions が揃っている
- Discord OAuth や将来の bot / Webhook 連携へ拡張しやすい

注意点：

- RLS設計ミスが危険
- service role key / secret key はフロントに置かない
- 本番接続前にRLSテストが必須

### 第二候補：Cloudflare Workers + D1

理由：

- 軽量APIとDiscord中継に強い
- D1でSQL系DBを扱える
- Workers Secretsでtoken管理が可能

注意点：

- 認証を自前または外部IdPで組む必要がある
- Supabaseより自作範囲が広い

### Firebase

位置づけ：

- リアルタイムコメント重視なら候補
- ただしDiscord OAuth、参加人数集計、Security Rulesが複雑になりやすいため、現時点では優先度を下げる

## 3. 最小プロトタイプの目的

別環境プロトタイプでは、以下を検証する。

- ログインユーザーを識別できるか
- 1セッションにコメント投稿できるか
- 自分のコメントだけ編集できるか
- コメント投稿と参加希望申請を関連づけられるか
- 同一ユーザーが複数コメントしても参加人数が1人分になるか
- `sessions.status = 'closed'` で新規申請を止められるか
- GM/adminだけが〆操作・申請管理できるか
- adminが全体確認できるか

## 4. 最小テーブル構成

最小核は以下5テーブルとする。

```text
profiles
user_roles
sessions
session_comments
session_applications
```

| テーブル | 役割 |
| --- | --- |
| `profiles` | Authユーザーの公開プロフィール |
| `user_roles` | player / gm / admin の権限 |
| `sessions` | セッション予定本体 |
| `session_comments` | コメント本文 |
| `session_applications` | 申請状態と申請者単位カウントの正本 |

後回し候補：

```text
session_participants
session_revisions
discord_links
session_templates
notifications
```

## 5. 重要設計方針

### 参加人数カウント

- コメント件数では数えない
- `session_applications` の `accepted` な一意ユーザー数で数える
- 同一ユーザーが複数コメントしても参加人数は1人分
- 重複申請は `unique(session_id, user_id)` で防ぐ
- `pending` / `waitlisted` は別集計にする

### 〆状態

- `sessions.status = 'closed'` を正本にする
- `is_closed` は作らない
- statusと別フラグの二重管理を避ける

### Discord ID

- `discord_user_id` は `text`
- 数値型にしない
- anonに公開しない
- 現行 `data/sessions.json` の18桁値は実Discord IDとして扱い、仮値扱いしない
- 現行公開JSONに実Discord IDが含まれることはリスクとして認識する
- Supabase移行時は `profiles.discord_user_id` などの非公開列へ移し、公開view / public RPC / public JSONレスポンスには出さない

### profiles公開

- `profiles` 本体をanonに全公開しない
- 公開用には `public_profiles` viewなどで `id` / `display_name` のみに絞る
- `discord_user_id` は出さない

### secret管理

- service role key / secret key / Discord bot token はフロントに置かない
- 公開リポジトリにも書かない
- チャットにも貼らない

## 6. RPC化方針

以下の処理は、直接INSERT/UPDATEよりRPC化を推奨する。

```text
create_application_comment()
edit_comment()
cancel_application()
set_application_status()
close_session()
```

理由：

- コメント作成と申請作成の整合性を保つ
- 申請状態遷移を安全に制御する
- 本人編集とGM/admin操作を分ける
- `closed` / `finished` / `canceled` への申請を拒否する
- `security definer` 利用時に入力検証・権限確認を関数内へ集約できる

注意：

- `security definer` は危険もあるため、`search_path` 固定、入力検証、`revoke/grant execute` が必要
- 実行前レビュー必須

## 7. RLS方針

### profiles

- 本人は自分のprofileを読める / 更新できる
- adminは全件管理
- anon全公開は禁止
- 公開用viewで最小列のみ公開

### user_roles

- 本人は自分のroleを読める
- adminのみrole管理可能
- 一般ユーザーが自分をgm/adminにできない

### sessions

- public sessionは閲覧可
- private / hidden はGM/adminのみ
- GMは自分のsessionのみ編集
- adminは全件管理
- 〆操作はRPC推奨

### session_comments

- コメント閲覧範囲は慎重に設計
- 参加希望コメントは公開申請欄に近い扱いとし、public sessionの表示可能コメントは他PLからも読める方針にする
- private / hidden sessionのコメント、deleted_at付きコメント、将来のinternal扱いコメントは公開しない
- anonにも見せる場合は、`user_id` や `discord_user_id` を含まない公開用view/RPCを使う
- 本人だけ本文編集
- GM/adminは対象sessionのコメント管理
- `full` sessionは満席として扱い、新規コメント申請を拒否する
- キャンセル待ちは `waitlist_enabled` / `application_status = 'waitlisted'` / `session_waitlist` などを別設計として後回しにする
- `deleted_at` 付きは通常表示しない
- 投稿・編集はRPC推奨

### session_applications

- playerは自分のapplicationを読める
- GMは自分のsessionのapplicationを読める
- adminは全件管理
- insert/updateはRPC推奨

## 8. RLSテストケース

| No | ケース | 期待結果 |
| -- | --- | --- |
| 1 | guestがpublic sessionを読む | 成功 |
| 2 | guestがprivate sessionを読む | 失敗 |
| 3 | guestがhidden sessionを読む | 失敗 |
| 4 | guestがコメント投稿RPCを実行 | 失敗 |
| 5 | player Aがopen sessionにコメント申請 | 成功 |
| 6 | player Aがfull sessionにコメント申請 | 失敗 |
| 7 | player Aがclosed sessionにコメント申請 | 失敗 |
| 8 | player Aがfinished sessionにコメント申請 | 失敗 |
| 9 | player Aがcanceled sessionにコメント申請 | 失敗 |
| 10 | player Aが同じsessionに追加コメント | commentは増えるがapplicationは1件 |
| 11 | player Aが自分のコメントを読む | 成功 |
| 12 | player Aがpublic sessionのplayer Bコメントを読む | 成功 |
| 13 | GM Aが自分のsessionコメントを読む | 成功 |
| 14 | player Aがprivate / hidden sessionの無関係コメントを読む | 失敗 |
| 15 | player Aが自分のコメントを編集 | 成功 |
| 16 | player Aがplayer Bのコメントを編集 | 失敗 |
| 17 | player Aがsession_commentsへ直接insert | 失敗 |
| 18 | player Aがsession_applicationsへ直接insert | 失敗 |
| 19 | player Aが自分の申請をcanceledにする | 成功 |
| 20 | player Aが自分の申請をacceptedにする | 失敗 |
| 21 | player Aが自分をadmin/gm化 | 失敗 |
| 22 | GM Aが自分のsession申請をacceptedにする | 成功 |
| 23 | GM Aが他GMのsession申請を変更 | 失敗 |
| 24 | GM Aが自分のsessionをclosedにする | 成功 |
| 25 | GM Aが他GMのsessionをclosedにする | 失敗 |
| 26 | adminが全件管理する | 成功 |
| 27 | anonがuser_rolesを読む | 失敗 |
| 28 | anonがprofiles.discord_user_idを読む | 失敗 |
| 29 | public_profilesでid/display_nameのみ読む | 成功 |
| 30 | public count RPCでprivate session人数を見る | 返らない |

## 9. Supabaseプロジェクト作成前チェックリスト

- Freeプランで始める
- 本番サイトとは接続しない
- 別環境プロトタイプ専用にする
- SQLは段階実行
- RLSを必ず有効化
- RLSテストケース全件成功まで本番接続しない
- secret / service role key / Discord bot token を記録しない
- 最初のadmin作成手順を決める
- player / gm / admin テストユーザーを用意する
- public / private / closed / finished / canceled のテストセッションを用意する
- 失敗時はプロジェクト削除・作り直しも許容

## 10. 本番接続前チェックリスト

- RLSテストケース全件成功
- APIキー管理方針確認
- `.env` / secrets の扱い確認
- GitHubリポジトリへsecretを入れない
- GitHub Pagesへservice role keyを出さない
- 本番用テーブルと試作用テーブルを混ぜない
- バックアップ手順
- rollback方針
- 管理者アカウント復旧手順
- 利用者向け説明
- Discord同期は後回し

## 11. まだやらないこと

- Supabase登録
- プロジェクト作成
- SQL実行
- APIキー発行
- 本番サイト接続
- Discord bot作成
- Edge Functions実装
- 認証UI実装
- コメント投稿UI本実装
- Git commit / push
- GitHub Pages公開反映

## 12. 関連資料

- `docs/supabase-prototype-runbook.md`: 実操作直前の判断基準・作業順・RLSテスト手順
- `docs/supabase-step0-2-preflight.md`: Supabase Freeプロトタイプ Step 0〜2 の実操作前チェックと停止ポイント
- `docs/supabase-rls-test-matrix.md`: RLSテストケース表
- `docs/supabase/sql/`: 最小スキーマ、RLS/GRANT、RPCの実行候補SQL草案
