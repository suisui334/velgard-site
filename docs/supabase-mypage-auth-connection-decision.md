# Supabase M-5前 mypage Auth実接続採否判断メモ

このメモは、`mypage.html` のアカウント機能をSupabase Authへ実接続する前に、実接続へ進むか、未構成フォールバックを維持するかを判断するための短い整理である。

この工程では、実config作成、実Project URL / anon key / publishable key投入、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、追加SQL実行は行わない。

## 1. 現在の状態

- `mypage.html` は静的な準備中ページとして存在する。
- 共通ヘッダーの `ACCOUNT` から `mypage.html` へ遷移できる。
- `assets/js/renderMypage.js` には、アカウント機能の未構成フォールバックがある。
- `assets/js/supabaseRuntimeConfig.example.js` は実値なしplaceholderのみで、HTMLから読み込んでいない。
- Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、`display_name` 取得、申請一覧表示は未実装。
- 短期方針は、未構成フォールバックを維持したまま実接続採否を判断すること。

## 2. 実接続へ進む場合の前提

- publishable key / anon keyをブラウザ配布前提の公開可能keyとして扱うことを確認する。
- 実データ保護はkey秘匿ではなく、RLS、RPC、公開viewの最小化で担保する。
- `public_profiles` など公開用途のレスポンスが、表示名中心の最小情報になっている。
- RLS smoke testがFAIL 0で維持されている。
- エラー表示やconsoleにProject URL、key、token、email、UUID全文、SQL詳細を出さない。
- 問題発生時に未構成フォールバックへ戻せる差分単位で実装する。

## 3. 実接続を保留する場合のメリット

- GitHub Pages公開中の静的サイトを安定維持できる。
- 実Project URL / keyの公開運用を決める前に、誤commitを避けられる。
- Auth、ログイン、ログアウト、申請一覧などを一度に入れず、設計判断を分離できる。
- secret類やtokenを画面・ログ・docsへ出す事故を避けやすい。
- UI方針を、ログイン状態カード単体ではなくアカウント操作入口として維持できる。

## 4. GitHub Pages静的運用でのpublishable key公開の扱い

- GitHub Pagesは静的配信のため、ブラウザで使う接続情報は最終的に利用者へ配信される。
- publishable key / anon keyは、秘匿値ではなく公開可能keyとして扱える前提を確認してから使う。
- ただし、公開可能keyであっても、GitHub repoへ実値を残すかどうかは別の運用判断である。
- repoへ入れる場合も、実値をREADME、docs、チャット、作業報告へ貼らない。
- key公開に依存して安全性を判断せず、RLSとRPC権限で読める範囲・操作できる範囲を制御する。

## 5. repoへ実値を入れる場合の注意点

- 実値は公開前提として扱い、private情報を混ぜない。
- `service_role`、secret key、DB password、token、direct connection stringは絶対に入れない。
- 実configにはProject URLとpublishable / anon相当のkey以外を含めない。
- 実値を出す差分は、レビューしやすく、revertしやすい単位にする。
- secret混入チェックを行い、説明文・placeholder以外に実値がないことを確認する。
- consoleや画面に接続値を表示しない。

## 6. repoへ実値を入れない場合の運用案

- `assets/js/supabaseRuntimeConfig.example.js` だけをGit管理し、実configはGit管理外にする。
- ローカル検証では実configを手元だけに置き、commitしない。
- GitHub Pages本番へ配信する場合は、GitHub Actions等で公開用configを生成する案を別途検討する。
- 実config配信方法が未確定なら、未構成フォールバックを維持する。
- どの案でも、実Project URL / keyの値そのものはdocsやチャットに記録しない。

## 7. 絶対に入れてはいけないもの

- `service_role`
- secret key
- DB password
- direct connection string
- access token / refresh token
- `.env.local` の中身
- Discord bot token / webhook secret
- 実メールアドレスや内部IDの不要な露出
- 本番運用に不要なadmin権限情報

## 8. 接続前チェックリスト

- publishable key / anon keyを公開可能keyとして扱う運用をユーザーが承認している。
- repoへ実値を入れるか、Git管理外または生成運用にするかを決めている。
- RLS smoke testがFAIL 0である。
- `public_profiles` や公開RPCが内部user_id、Discord ID、email、内部roleを返さない。
- `profiles` 本体をanon公開していない。
- Auth token管理はSupabase SDK標準に任せ、独自にlocalStorageへ保存しない。
- エラー・ログ方針が、Project URL / key / tokenを出さない形になっている。
- 未構成フォールバックへ戻すロールバック手順がある。
- `mypage.html` だけで完結させ、`session-detail.html` 本文中の常時ログイン状態表示へ戻らない。
- 投稿、編集、削除、GM承認・却下は今回の接続判断に含めない。

## 9. 現時点の推奨

短期は未構成フォールバックを維持する。

Supabase実接続へ進む前に、publishable key / anon keyをGitHub repoへ置く運用を採用するか、ユーザー判断を挟む。実接続する場合でも、`service_role`、secret key、DB passwordは絶対に使わない。

## 10. 次工程候補

1. この判断メモのcommit / push
2. `docs/supabase-mypage-auth-connection-hold-note.md` で未構成フォールバック維持の現状を整理
3. publishable key / anon keyをrepoへ置くかどうかのユーザー最終判断
4. 未構成フォールバック維持のままサイト側軽作業へ戻る
5. 実config運用案を決めたうえで、M-5 Auth client初期化計画を作る
6. 実接続へ進む場合も、まず `mypage.html` 内のログイン / ログアウト入口に限定する
