# Supabase Freeプロトタイプ Step 0〜2 準備パック

## 1. 目的

この資料は、ヴェルガルド公開サイトの参加希望コメント、申請管理、GM編集、〆ボタン検証に向けた Supabase Free プロトタイプの実操作前準備メモである。

この工程では、GitHub Pages公開中のサイト本体をSupabaseへ接続しない。`calendar.html` / `session-detail.html` / `assets/js/` へSupabase client初期化コードや実DB接続処理は追加しない。

今回作るものは、安全に検証するための手順、SQL草案、RLSテスト表、停止ポイントであり、実プロジェクト作成やSQL実行はまだ行わない。

## 2. Step 0〜2の範囲

| Step | 内容 | 今回の扱い |
| --- | --- | --- |
| Step 0 | 空プロジェクト確認 | 実操作前の確認項目のみ整理 |
| Step 1 | extension / tables の段階実行 | SQL草案を作成するが、実行しない |
| Step 2 | 初期Authユーザー作成 | テスト役割と注意点のみ整理 |

## 3. 作成した準備ファイル

| ファイル | 役割 |
| --- | --- |
| `docs/supabase-step0-2-preflight.md` | Step 0〜2の総合チェック、停止ポイント、secret混入防止手順 |
| `docs/supabase-rls-test-matrix.md` | RLSテストケース表 |
| `docs/supabase/sql/001_core_schema_draft.sql` | 最小核テーブル、制約、インデックス、updated_at、公開プロフィールviewのSQL草案 |
| `docs/supabase/sql/002_rls_grants_draft.sql` | helper関数、count view/RPC、RLS enable、RLS policy、grant/revoke方針のSQL草案 |
| `docs/supabase/sql/003_rpc_draft.sql` | コメント申請、コメント編集、申請取消、GM申請管理、〆操作RPCのSQL草案 |

## 4. 実操作前チェックリスト

- [ ] 本番サイトへ接続しない
- [ ] GitHub PagesへSupabase接続コードを追加しない
- [ ] Supabase client初期化コードを `assets/js/` に追加しない
- [ ] `session-detail.html` に実コメント投稿処理を入れない
- [ ] `calendar.html` に実DB読み込み処理を入れない
- [ ] 実プロジェクトURL、API key、secret、Discord bot用token、Webhook URL、実メール、実Discord IDをファイルに書かない
- [ ] SQLは草案として扱い、まだ実行しない
- [ ] SQLは一括実行ではなく段階実行する前提にする
- [ ] RLS有効化とテストを本番接続前の必須条件にする
- [ ] 失敗したらプロトタイプを削除・作り直してよい前提にする

## 5. SQL実行順序メモ

実操作時は、以下の順で段階実行する。

1. `001_core_schema_draft.sql` のextension
2. `001_core_schema_draft.sql` のtables
3. `001_core_schema_draft.sql` のindexes / constraints
4. `001_core_schema_draft.sql` のupdated_at trigger
5. `001_core_schema_draft.sql` のpublic view
6. `002_rls_grants_draft.sql` のhelper functions
7. `003_rpc_draft.sql` のRPC functions
8. `002_rls_grants_draft.sql` のcount view / count RPC
9. `002_rls_grants_draft.sql` のRLS enable
10. `002_rls_grants_draft.sql` のRLS policies
11. 各ファイル末尾のrevoke / grant確認

一括実行しない理由：

- 失敗箇所を特定しやすくするため
- RLS有効化前後の挙動を分けて確認するため
- 権限漏れを見落とさないため
- 作り直し判断を早めるため

## 6. 最小スキーマSQL草案の方針

最小核：

```text
profiles
user_roles
sessions
session_comments
session_applications
```

設計方針：

- `profiles` 本体を anon 全公開しない
- Discord IDを公開しない
- 現行 `data/sessions.json` には実Discord IDが含まれるため、個人識別子として注意対象にする
- 将来Supabaseへ移行する場合、Discord IDは `profiles.discord_user_id` などの非公開列へ移し、公開view / public RPC / public JSONレスポンスには出さない
- 公開用情報は `public_profiles` view で `id` / `display_name` 程度に絞る
- `sessions.status` を募集状態の正本にする
- `is_closed` は作らない
- 参加人数はコメント件数ではなく、`session_applications` の一意ユーザー単位で数える
- 重複申請は `unique(session_id, user_id)` で防ぐ
- `session_comments` と `session_applications` の直接UPDATEは最小化し、RPC経由を主導線にする
- RLSなしのテーブルを公開しない

## 7. RLS / GRANT 方針

- 全テーブルでRLSを有効化する
- `profiles` 本体は本人/admin中心に制限する
- `user_roles` は本人閲覧とadmin管理に限定する
- public session はguest/anonでも読める
- private / hidden session はGM/adminのみ読める
- 参加希望コメントは公開申請欄に近い扱いとし、public sessionの表示可能コメントは他PLからも読める方針にする
- private / hidden sessionのコメント、deleted_at付きコメント、将来のinternal扱いコメントは公開しない
- anonにも見せる場合は、`user_id` や `discord_user_id` を含まない公開用view/RPCを使う
- public向け人数表示はコメント件数ではなく `session_applications` 集計または専用RPC/viewで行う
- `full` sessionは満席として扱い、新規コメント申請を拒否する
- コメント投稿、コメント編集、申請取消、GM申請管理、〆操作はRPCへ寄せる
- 関数はRLS対象外なので、`revoke all on function ... from public` と必要ロールへの `grant execute` を明示する
- `security definer` 関数では `set search_path = ''`、スキーマ修飾、入力検証、`auth.uid()` nullチェックを必須にする

## 8. RPC草案の方針

RPC化候補：

```text
create_application_comment()
edit_comment()
cancel_application()
set_application_status()
close_session()
```

目的：

- コメント作成と申請作成の整合性を保つ
- 同一ユーザー複数コメントでもapplicationを増やさない
- closed / finished / canceled / draft への申請を拒否する
- 本人編集とGM/admin操作を分ける
- GM/adminだけが申請状態変更や〆操作を行えるようにする

## 9. RLSテスト参照

RLSテストケースは `docs/supabase-rls-test-matrix.md` に分離した。実操作時は、少なくとも以下を確認する。

- guest / anon の閲覧範囲
- player のコメント申請と自分のコメント編集
- public sessionの参加希望コメントを他PLが読めること
- private / hidden sessionのコメントがanon / unrelated playerへ漏れないこと
- コメント表示経由で `profiles.discord_user_id` や内部IDを出さないこと
- player の権限昇格拒否
- GM の自分のsession管理
- GM の他GM session操作拒否
- admin の全件管理
- `full` sessionへの申請拒否
- private / hidden session の人数漏洩なし
- secret / API key / token のリポジトリ混入なし

## 10. secret混入防止チェック手順

実値を検索語に入れず、説明語としての出現と実値混入を分けて確認する。

```powershell
Select-String -Path .\docs\**\*,.\README.md -Pattern "service_role","sb_secret_","SUPABASE_SERVICE_ROLE_KEY","JWT secret","webhook","bot token" -SimpleMatch
```

この検索では、注意喚起の説明文として禁止語が出る場合がある。その場合は、実URL、実key、実token、実メール、実Discord IDが含まれていないことを確認して報告する。

追加確認観点：

- `https://` で始まるSupabase実プロジェクトURLがない
- `eyJ` で始まるJWT風文字列がない
- 実メールアドレスがない
- 18桁の実Discord IDを直接資料に書いていない
- `.env` を作っていない

## 11. 停止ポイント

以下のどれかに該当したら、本番接続へ進まない。

- RLSテストが未完了
- RLSをOFFにしないと動かない
- anonがprivate / hidden sessionを読める
- anonがDiscord IDを読める
- private / hidden sessionの参加希望コメントを無関係な閲覧者が読める
- コメント表示経由でDiscord IDや内部user_idが漏れる
- playerが他人コメントを編集できる
- playerが自分をgm/adminにできる
- full sessionへ申請できる
- closed / finished / canceled sessionへ申請できる
- GMが他GM sessionをclosedにできる
- private / hidden sessionの人数がpublic count RPCから返る
- service role key相当の高権限キーをフロントへ置く必要が出る
- API keyやsecretをGitHubへ入れそうになる

## 12. 今回まだやらないこと

- Supabase登録
- プロジェクト作成
- SQL実行
- APIキー発行
- 本番サイト接続
- GitHub Pagesへの反映
- 認証UI実装
- コメント投稿本実装
- Discord bot / Webhook
- Edge Functions
- 支払い設定
- Git commit / push
