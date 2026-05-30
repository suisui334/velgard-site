# Supabase M-4 mypage runtime config deployment review plan

この計画書は、`mypage.html` からSupabase Authへ実接続する前に、GitHub Pages静的運用でのruntime config、公開可能key、接続前確認、ロールバック方針を整理するためのものです。

この工程では、実config作成、実Project URL / anon key / publishable key投入、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、追加SQL実行は行わない。

## 1. 目的

- Supabase Auth実接続前にruntime config運用方針を決める
- GitHub Pages静的運用では環境変数をそのままブラウザへ注入できない制約を明確化する
- 実Project URL / anon key / publishable keyの扱いを整理する
- service_role / secret key / DB passwordをフロントへ絶対に出さない境界を再確認する
- M-2/M-3の未構成フォールバックから実接続へ進む条件を整理する

## 2. 現在の前提

- `mypage.html` にはアカウント機能セクションがある
- 接続設定未構成時の準備中表示は実装済み
- `assets/js/supabaseRuntimeConfig.example.js` は実値なしplaceholderのみ
- example configはHTMLから読み込んでいない
- Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウトは未実装
- ログイン状態カード単体は採用しない

## 3. 運用候補比較

| 案 | 内容 | メリット | デメリット | GitHub Pagesとの相性 | secret管理リスク | 現方針との整合 | 推奨度 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A案 | 実Project URL / publishable keyを静的JSへcommitする | no-build運用で単純。GitHub Pagesだけで配信できる | 実値が公開repoに残る。公開可能keyであることを運用上明確にする必要がある | 高い | service_role等を誤って混ぜるリスク管理が必要 | docs/README/chatへ実値を残さない方針とはやや緊張する | 中 |
| B案 | `supabaseRuntimeConfig.js` をGit管理外にし、ローカルのみで読み込む | repoに実値を残さない。ローカル検証に向く | GitHub Pages本番では実configの配布方法が別途必要 | 低から中 | Git管理外の実ファイル紛失や誤配布に注意 | 実値をrepoに残さない方針と整合 | 中 |
| C案 | GitHub Actions等で公開用configを生成する | repoに実値を直書きしない。公開時に生成できる | Actions secret、Pagesデプロイ、ビルド工程の設計が必要 | 中から高 | Actions設定ミスやログ出力に注意 | docsに実値を残さない方針と整合 | 中から高 |
| D案 | GitHub PagesではSupabase接続を保留し、dev検証に留める | 最も安全。現在の未構成フォールバックを維持できる | 本番のAuth確認は進まない | 高い | 低い | 現時点の慎重な運用方針と整合 | 高 |
| E案 | Cloudflare Workers等を挟んでconfigやAPIを扱う | 将来のAPI境界や秘匿処理を設計しやすい | 運用コストと構成要素が増える。Authの公開key秘匿そのものには過剰な場合がある | 中 | worker側のsecret管理が必要 | 将来拡張向きだが現段階では重い | 低から中 |

## 4. 現時点の推奨案

短期推奨は、D案として未構成フォールバックを維持すること。

次段階では、実config運用をGitHub Pages公開運用として採用するかを最終判断する。公開可能なanon / publishable keyは本来ブラウザ配布前提だが、repoへcommitするかどうかは別の運用判断として扱う。

実装へ進む前に、以下を再確認する。

- publishable keyが公開前提であること
- 実データ保護はkey秘匿ではなくRLSとRPC設計で担保すること
- service_role、secret key、DB passwordは絶対にフロントへ出さないこと
- Project URL / key実値をREADME、docs、チャットへ貼らないこと
- GitHub Pages静的運用では、ビルド時secret注入なしに実値を隠して配信することはできないこと

## 5. 接続前チェックリスト

実接続へ進む前に、以下を確認する。

- RLS smoke testがFAIL 0である
- `public_profiles` が公開用途では `id` / `display_name` 中心の最小公開である
- `profiles` 本体をanon公開していない
- `get_public_session_comments` など公開RPCが内部情報を返さない
- 公開RPCが `user_id` 全文、`discord_user_id`、email、内部roleを返さない
- service_roleを一切使わない
- secret key / DB passwordを一切使わない
- 実Project URL / keyをチャットへ貼らない
- GitHub repoへ入れる場合は公開前提の値として扱う
- エラー表示やconsoleにtoken / key / URLを出さない
- localStorageへURL / key / tokenを独自保存しない
- Supabase Auth token管理は公式SDKの範囲に任せる
- 未構成フォールバックへ戻すロールバック手順がある
- 実装差分がGit revertしやすい単位になっている

## 6. 実configファイル案

将来 `supabaseRuntimeConfig.js` を作る場合の形は以下を候補にする。

```js
window.VELGARD_SUPABASE_CONFIG = {
  url: "PROJECT_URL_PLACEHOLDER",
  anonKey: "ANON_OR_PUBLISHABLE_KEY_PLACEHOLDER"
};
```

注意:

- 上記は構造案であり、実値ではない
- exampleには空文字placeholderのみを置く
- 実configをGit管理するかどうかは別途判断する
- service_role、secret key、DB password、tokenはconfigへ絶対に含めない
- 実configを読み込む場合も、画面やconsoleに値を出さない

## 7. 未構成フォールバック継続方針

現状の `mypage.html` は、未構成フォールバックで安全に表示される。

継続方針:

- 未構成時はアカウント機能セクションに準備中案内を表示する
- Supabase SDKを読み込まない
- Auth復元を試みない
- コンソールエラーを出さない
- ログイン / ログアウトUIを出さない
- ログイン中 / 未ログインの状態表示だけを大きく出さない
- トップ / CALENDARへの戻り導線は維持する

## 8. エラー・ログ方針

将来実接続する場合の表示方針:

| 状態 | PL向け表示案 | console方針 |
| --- | --- | --- |
| 初期化失敗 | アカウント機能を読み込めませんでした | 原因カテゴリのみ。URL / keyは出さない |
| Auth復元失敗 | ログイン状態を確認できませんでした | tokenやUUID全文は出さない |
| profile取得失敗 | 表示名を取得できませんでした | SQL詳細やemailは出さない |
| ネットワークエラー | 通信に失敗しました。時間を置いて再度お試しください | endpoint実値を出さない |
| config未構成 | アカウント機能は準備中です | エラー扱いにしすぎない |

出してはいけないもの:

- Project URL
- anon key / publishable key
- token
- UUID全文
- email
- SQL詳細
- service_role
- secret key
- DB password

## 9. ロールバック方針

実接続後に問題が出た場合は、以下の順で戻せるようにする。

1. config読み込みを止める
2. Auth用JS読み込みを止める
3. `mypage.html` を未構成フォールバックへ戻す
4. `assets/js/renderMypage.js` をA-3最小版またはM-2/M-3未構成表示へ戻す
5. Supabase接続を試みない状態へ戻す
6. Git revertで戻せる単位にする
7. Supabase側ロールバック不要にする

この段階ではDB状態変更を伴わないため、ロールバックはフロント差分だけで完結させる。

## 10. まだ扱わないもの

このレビュー計画では以下を扱わない。

- 実config作成
- 実Project URL / key投入
- Supabase接続
- Auth復元
- ログインフォーム
- ログアウト
- `display_name` 取得
- `public_profiles` 取得
- 自分の申請一覧
- 参加予定セッション
- コメント履歴
- `session-detail.html` 投稿統合
- GM操作
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- 追加SQL実行

## 11. 次工程候補

1. このレビュー計画書のcommit / push
2. 実config運用方針のユーザー最終判断
3. 未構成フォールバック維持またはruntime config読み込み計画
4. Auth client初期化計画
5. Authセッション復元計画
