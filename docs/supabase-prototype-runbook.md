# Supabaseプロトタイプ実操作前ランブック

## 1. 実操作開始前の判断

### Supabaseを作成してよい条件

- 本番サイトとは完全に分けた検証として扱える
- Freeプランで試す前提になっている
- SQL / RLSを段階実行し、失敗したら作り直してよいと割り切れる
- service role key / secret / Discord bot token を記録・共有しない運用を守れる
- player / gm / admin のテストユーザーを用意できる
- RLSテストを最後まで実行する時間が取れる

### まだ作成しない方がよい条件

- 本番サイトへすぐ接続するつもりになっている
- SQLを一括実行して一気に進めたい
- secret類の保管場所が決まっていない
- 初回admin作成手順が曖昧
- RLSテストを省略する予定がある
- 支払い方法、無料枠、課金条件を確認しないまま本番導入しようとしている

### 基本前提

- 本番サイトへ接続しない
- 失敗したらプロジェクト削除・作り直しでよい
- Freeプランで試す
- 支払い方法、無料枠、課金条件は本番導入前に再確認する

## 2. 作成前に用意するもの

| 用意するもの | 内容 |
| --- | --- |
| Supabaseアカウント | 検証用に利用 |
| プロジェクト名候補 | 本番と混同しない名前 |
| リージョン候補 | 日本から近い場所を優先しつつ、選択肢は作成時に確認 |
| 管理用メモ置き場 | secretを書かない設計メモのみ |
| SQL草案 | 修正版SQL草案・RLSポリシー第2版 |
| RLSテストケース | guest / player / gm / admin を分けて確認 |
| テストユーザー用メール候補 | 実メールアドレスを不用意に記録しない |
| 役割 | player / gm / admin |
| 命名方針 | `prototype` / `test` を含める |

プロジェクト名案：

```text
velgard-session-prototype
velgard-supabase-prototype
velgard-calendar-auth-test
```

## 3. 絶対に記録・共有してはいけないもの

- Supabase service role key
- Supabase secret key
- JWT secret
- API secret
- Discord bot token
- Discord webhook URL
- 本番パスワード
- 実ユーザーのメールアドレス
- 実Discord ID
- 支払い情報

注意：

- チャットに貼らない
- READMEに書かない
- GitHubにcommitしない
- スクリーンショットにも不用意に写さない
- `.env` を作る場合は `.gitignore` を先に確認する

## 4. Supabaseプロジェクト作成時の注意

- Freeプランを選ぶ
- project name に `prototype` / `test` を含める
- 本番用っぽい名前にしない
- リージョンは日本から近い場所を優先しつつ、選択肢は作成時に確認する
- database password は安全に管理する
- 作成直後に本番サイトへ接続しない
- API settings を開いても key をチャットへ貼らない
- service role key は絶対にフロントへ使わない
- Discord bot token / webhook URL はまだ扱わない

## 5. 初回の作業順

### Step 0：空プロジェクト確認

- Supabaseプロジェクトが作成されたことだけ確認
- まだ本番サイトに接続しない
- まだGitHub Pagesへ何も設定しない
- APIキーをどこにも貼らない

### Step 1：SQLを段階実行

実行順：

1. extension
2. tables
3. indexes / constraints
4. triggers
5. views
6. helper functions
7. RPC
8. RLS enable
9. RLS policies
10. grants

一括実行しない理由：

- どの段階で失敗したか分かりにくくなる
- RLS有効化前後の挙動を確認できない
- 権限漏れが混ざっても見落としやすい
- 作り直し判断が遅れる

### Step 2：初期Authユーザー作成

推奨5ユーザー：

- player A
- player B
- gm A
- gm B
- admin A

最小なら3人でも可：

- player A
- gm A
- admin A

ただし、他人編集拒否・他GM拒否を確認するには5人推奨。

### Step 3：profiles / roles 投入

- 各AuthユーザーIDを確認
- `profiles` に対応行を作る
- `user_roles` に player / gm / admin を設定
- 初回adminは手動投入
- 一般ユーザーが自分をadminにできないことを後で必ず確認

### Step 4：テストsessions投入

最低限：

- public open
- private open
- closed
- finished
- canceled
- other GM session

### Step 5：RLSテスト

確認軸：

- guest
- player
- gm
- admin
- 他人編集拒否
- 他GM拒否
- private漏洩なし
- Discord ID漏洩なし
- 申請者単位カウント

## 6. 初回admin作成手順の注意

- 初回adminだけは通常UIでは作れない
- Supabase Dashboard / SQL Editorで手動投入する想定
- 以後adminが他ユーザーへrole付与する
- 一般ユーザーが自分をadminにできないことを必ずテスト
- admin復旧手順を本番前に決める
- adminが1人だけだと復旧不能リスクがあるため、本番前に予備admin方針を決める

## 7. RLSテストの必須ケース

| ケース | 操作ユーザー | 期待結果 |
| --- | --- | --- |
| public session閲覧 | guest | 成功 |
| private session閲覧 | guest | 失敗 |
| hidden session閲覧 | guest | 失敗 |
| user_roles閲覧 | anon | 失敗 |
| profiles.discord_user_id閲覧 | anon | 失敗 |
| public_profiles閲覧 | anon | id / display_nameのみ |
| open sessionコメント申請 | player | 成功 |
| full sessionコメント申請 | player | 失敗 |
| closed session申請 | player | 失敗 |
| finished session申請 | player | 失敗 |
| canceled session申請 | player | 失敗 |
| 同一session追加コメント | player | commentは増えるがapplicationは1件 |
| 自分コメント閲覧 | player | 成功 |
| public sessionの他人コメント閲覧 | player / anon | 表示用RPCで成功 |
| private / hidden sessionの無関係コメント閲覧 | player | 失敗 |
| 自分コメント編集 | player | 成功 |
| 他人コメント編集 | player | 失敗 |
| コメント直接insert | player | 失敗 |
| application直接insert | player | 失敗 |
| 自分の申請をcanceled | player | 成功 |
| 自分の申請をaccepted | player | 失敗 |
| 自分をadmin化 | player | 失敗 |
| 自分のsessionコメント閲覧 | gm | 成功 |
| 他GM private / hidden sessionコメント閲覧 | gm | 失敗 |
| 自分のsession申請をaccepted | gm | 成功 |
| 他GM session申請変更 | gm | 失敗 |
| 自分のsessionをclosed | gm | 成功 |
| 他GM sessionをclosed | gm | 失敗 |
| finished/canceledをclosed | gm | 失敗 |
| 全件管理 | admin | 成功 |
| public count RPC | anon | public session人数のみ |
| private count漏洩確認 | anon | private session人数は返らない |

## 8. 成功条件

- RLSテストが全件成功
- service role keyなしでフロント想定権限のテストができる
- anonに機密情報が漏れない
- playerが他人のデータを変更できない
- playerがpublic sessionの参加希望コメントを読める
- public comment表示でDiscord IDや内部user_idが返らない
- playerがprivate / hidden sessionの無関係コメントを読めない
- Discord IDは公開view / public RPC / public JSONレスポンスへ出さない
- playerが自分をgm/adminにできない
- GMが他GMの予定を変更できない
- GMが他GM private / hidden sessionの参加希望コメント本文を読めない
- adminだけが全体管理できる
- コメント件数ではなく申請者単位で人数が数えられる
- full状態で新規申請が止まる
- closed状態で新規申請が止まる
- `sessions.status = 'closed'` が〆状態の正本として機能する

## 9. 中止条件

- RLSをOFFにしないと動かない
- anonがprivate/hidden sessionを読める
- anonがDiscord IDを読める
- anonがuser_rolesを読める
- playerが他人コメントを編集できる
- playerがprivate / hidden sessionの無関係コメント本文を読める
- コメント表示経由でDiscord IDや内部user_idが漏れる
- playerが自分をadmin/gmにできる
- full sessionへ申請できる
- closed/finished/canceled sessionへ申請できる
- playerが自分の申請をacceptedにできる
- GMが他GM sessionをclosedにできる
- GMがfinished/canceled sessionをclosedにできる
- private session人数がpublic count RPCから返る
- service role keyをフロントへ置く必要が出る
- API keyやsecretをGitHubへ入れそうになる

## 10. 本番接続前に必ず止まるポイント

- RLSテスト全件成功まで本番接続しない
- GitHub PagesにSupabase接続コードを入れない
- `.env` / secret管理方針を決める
- 利用者向け説明を用意する
- バックアップ/復旧手順を決める
- 管理者アカウント復旧手順を決める
- Discord同期はまだ後回し
- 支払い方法・無料枠・課金条件を再確認する
- 本番用テーブルと試作用テーブルを混ぜない

## 11. 次に実際へ進む場合の最小アクション

1. Supabase Freeプロジェクトを1つ作る
2. 空プロジェクトであることだけ確認する
3. SQL Step 1：extensionだけ実行する
4. SQL Step 2：tablesだけ実行する
5. テーブルができるか確認する
6. まだ本番サイトには接続しない
7. APIキーをアプリへ貼らない
8. 次の作業に進む前に、実行結果を記録する

いきなり全部やらず、プロジェクト作成と最小SQL確認までを最初の単位にする。

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
- GitHub Pages公開反映

## 13. 関連資料

- `docs/supabase-prototype-plan.md`: 設計方針・スキーマ・RLS方針の資料
- `docs/supabase-step0-2-preflight.md`: Supabase Freeプロトタイプ Step 0〜2 の実操作前チェックと停止ポイント
- `docs/supabase-rls-test-matrix.md`: RLSテストケース表
- `docs/supabase/sql/`: 最小スキーマ、RLS/GRANT、RPCの実行候補SQL草案
