# Supabase mypage Auth実接続保留メモ

このメモは、`mypage.html` のSupabase Auth実接続へまだ進まず、現状を未構成フォールバック維持として整理するための短い記録である。

この工程では、実config作成、実Project URL / anon key / publishable key投入、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、追加SQL実行は行わない。

## 1. 現在は未構成フォールバック維持とする

保留メモ作成時点では、`mypage.html` のアカウント機能は未構成フォールバックのまま維持する判断だった。

これは当時、GitHub Pages静的運用でpublishable key / anon keyをどのように扱うかが未決定であり、実接続前にユーザー判断を挟む必要があったためである。

## 2. Supabase実接続はまだ行わない

以下はまだ行わない。

- Supabase SDK読み込み
- Supabase client初期化
- Authセッション復元
- ログイン処理
- ログアウト処理
- `display_name` / `public_profiles` 取得
- 自分の申請一覧表示
- 参加予定セッション表示
- 本番 `session-detail.html` へのSupabase接続

## 3. publishable key / anon keyのrepo投入は未決定

publishable key / anon keyはブラウザ配布前提で扱える可能性があるが、GitHub repoへ実値を置くかどうかは別の運用判断である。

保留メモ作成時点でも、実Project URL / anon key / publishable keyをREADME、docs、チャット、作業報告、GitHub repoへ記録しない方針だった。

## 4. 実接続前にユーザー判断が必要

実接続へ進む前に、少なくとも以下をユーザー判断とする。

- publishable key / anon keyをGitHub repoへ置く運用にするか
- 実configをGit管理外にするか
- GitHub Actions等で公開用configを生成するか
- 本番公開前にdev検証だけへ留めるか

どの案でも、`service_role`、secret key、DB password、token、direct connection stringは絶対に扱わない。

## 5. 現時点で安定しているもの

- 共通ヘッダーの静的 `ACCOUNT` 導線
- `mypage.html` 最小版
- `assets/js/supabaseRuntimeConfig.example.js` の実値なしplaceholder
- `mypage.html` 内のアカウント機能未構成フォールバック
- Supabase SDKを読み込まない状態
- Auth復元を試みない状態

## 6. 次に実接続へ進む場合の条件

- publishable key / anon key公開運用についてユーザー判断が済んでいる
- repoへ実値を置くか、置かない場合の配信運用が決まっている
- RLS smoke testがFAIL 0で維持されている
- 公開RPC / viewが内部user_id、Discord ID、email、内部roleを返さない
- エラー表示やconsoleにProject URL、key、token、email、UUID全文、SQL詳細を出さない方針が固定されている
- 未構成フォールバックへ戻すロールバック手順がある

## 7. 次にサイト軽作業へ戻る場合の候補

- 既存静的ページの文言整理
- 既存docs / backlogの棚卸し
- Supabaseと無関係な表示確認
- `updates.json` を変更しない範囲の軽微な資料整理
- マイページ実接続以外の次工程候補整理

## 8. M-5計画への接続

Auth client初期化と既存セッション復元へ進む場合の実装計画は、`docs/supabase-mypage-auth-client-restore-plan.md` に分離する。

この保留メモは、未構成フォールバック維持を安定状態として記録した過去方針である。その後、ユーザーはSupabase / アカウント / スケジュール登録 / テンプレート関連の流れを止めずに進めたい意向を示した。

したがって、次段階ではpublishable key / anon keyを公開前提で扱い、GitHub Pages静的サイトでSupabase Auth実接続へ進むためのM-5計画へ移る。

ただし、この時点でも実Project URL / anon key / publishable key実値はdocs、README、チャット、作業報告へ記録しない。未構成フォールバックは、問題が出た場合のロールバック / 保留案として残す。
