# Supabase M-5 mypage Auth client初期化・Auth復元 実装計画書

この計画書は、`mypage.html` でSupabase Auth client初期化とAuthセッション復元を行う前に、実装範囲、runtime config運用、UI、エラー表示、ロールバック、接続前チェックを整理するためのものです。

この工程では、実装、実config作成、実Project URL / anon key / publishable key投入、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、追加SQL実行は行わない。

## 1. 目的

- `mypage.html` でSupabase Auth client初期化とAuthセッション復元を行う前の実装計画を整理する
- ログインフォーム、ログアウト、`display_name` 取得、申請一覧表示は後続工程に分ける
- まず既存セッションがある場合だけ復元し、未ログインなら未ログイン表示へ安全に落とす
- 接続設定未構成時は、現在の未構成フォールバックを壊さず維持する
- ユーザー判断として、publishable key / anon keyを公開前提で扱い、GitHub Pages静的サイトでSupabase Auth実接続へ進む方向を整理する
- 実Project URL / key実値、secret類、tokenをdocs / README / チャットへ記録しない

## 2. M-5で扱う候補

M-5実装へ進む場合の候補は以下に限定する。

- runtime config読み込み
- Supabase SDK読み込み
- Supabase client初期化
- `auth.getSession` による既存セッション復元
- 未ログイン表示
- 接続未構成時フォールバック
- 初期化失敗時の短いエラー表示

M-5は、ログイン済みか未ログインかの入口を作る工程とし、PL本人向け情報や操作機能の本格表示は後続へ送る。

## 3. M-5ではまだ扱わないもの

- ログインフォーム
- ログアウトボタン
- `display_name` 取得
- `public_profiles` 取得
- 自分の申請一覧
- 参加予定セッション
- コメント履歴
- `session-detail.html` 連携
- 投稿、編集、削除、GM承認・却下
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- 追加SQL実行

## 4. publishable key / anon keyの扱い

- publishable key / anon keyはブラウザ配布前提の公開可能keyとして扱う
- GitHub Pages静的サイトで実接続へ進む場合、repoへ置く実値は秘匿されない値として扱う
- 安全性はkey秘匿ではなく、RLS、RPC、公開view制限で担保する
- `service_role`、secret key、DB password、direct connection stringは絶対に使わない
- 実Project URL / key実値はdocs、README、チャット、作業報告へ記録しない
- repoへ実値を置く場合は、公開される前提として扱う
- localStorageへSupabase URL / key / tokenを独自保存しない
- Auth token管理はSupabase SDK標準の範囲に任せる
- consoleや画面にProject URL、key、token、email、UUID全文を出さない

## 5. runtime config実装候補

| 案 | 内容 | 利点 | 注意点 | 現時点の評価 |
| --- | --- | --- | --- | --- |
| A案 | `assets/js/supabaseRuntimeConfig.js` を作成し、実値を置く | no-build構成で単純。`mypage.html` から読み込みやすい | 実値がファイルに残る。Git管理するかどうかの判断が必要 | 実接続へ進む場合の直接候補 |
| B案 | GitHub Pagesでは実値commitを許容し、公開前提で扱う | GitHub Pagesだけで配信できる。運用が単純 | public repoへ実Project URL / keyが残る。安全性はRLS / RPC / 公開view制限で担保する | GitHub Pages静的運用の実接続候補 |
| C案 | 実configはまだ作らず、M-5では未構成フォールバック維持 | 最も安全。現状を壊さず、実値露出リスクがない | Auth復元の本番確認は進まない | 保留時の安全策 / ロールバック案 |
| D案 | GitHub Actions等で公開用configを生成する | repoに実値を直書きしない。公開時に生成できる | Actions secrets、ログ出力、Pagesデプロイ手順の設計が必要 | 将来候補 |

現時点の推奨は、ユーザー判断としてpublishable key / anon keyを公開前提で扱い、GitHub Pages静的サイトでSupabase Auth実接続へ進む方向とすること。

短期の未構成フォールバック維持は完了済みの安全状態であり、次段階ではこのM-5実装計画に基づいてAuth client初期化・Auth復元へ進む。ただし、この計画書作成工程では、実値投入、実config作成、Supabase接続、Auth実装は行わない。

C案は保留時の安全策としては有効だが、現在のユーザー方針では最終推奨ではなく、ロールバック / 保留案として残す。

## 6. 実装対象ファイル案

将来M-5実装へ進む場合の候補は以下。

| ファイル | 想定役割 |
| --- | --- |
| `mypage.html` | Supabase SDK、runtime config、Auth client用JSの読み込み候補 |
| `assets/js/renderMypage.js` | アカウント機能セクションの未構成 / 未ログイン / ログイン済み / エラー表示候補 |
| `assets/js/mypageAuthClient.js` | runtime config検査、client初期化、`auth.getSession` 復元の候補 |
| `assets/js/supabaseRuntimeConfig.example.js` | 実値なしplaceholderのshape共有 |
| `assets/js/supabaseRuntimeConfig.js` | 実config候補。作成・Git管理可否は未決定 |
| `README.md` | 実値なしの運用メモ参照 |
| `docs/task-backlog.md` | 次工程候補と保留事項の整理 |

この計画書作成工程では、上記ファイルの実装変更は行わない。

## 7. UI方針

ログイン状態カード単体は採用しない。`mypage.html` 内のアカウント機能セクションに、操作入口として短く統合する。

| 状態 | 表示方針 |
| --- | --- |
| 接続未構成 | アカウント機能は準備中です |
| 未ログイン | アカウント機能 / ログイン機能は準備中、または未ログインです |
| ログイン済み | アカウント機能 / ログイン済みです |
| 初期化失敗 | アカウント機能を読み込めませんでした |
| Auth復元失敗 | ログイン状態を確認できませんでした |

M-5では `display_name` 取得は扱わない。ログイン済み表示も、表示名ではなく「ログイン済みです」程度に留める。

## 8. エラー表示方針

| 状態 | PL向け表示 | console方針 |
| --- | --- | --- |
| runtime config未構成 | アカウント機能は準備中です | エラー扱いにしすぎない |
| Supabase SDK読み込み失敗 | アカウント機能を読み込めませんでした | 原因カテゴリのみ |
| client初期化失敗 | アカウント機能を読み込めませんでした | URL / keyは出さない |
| Auth復元失敗 | ログイン状態を確認できませんでした | tokenやUUID全文は出さない |
| ネットワークエラー | 通信に失敗しました。時間を置いて再度お試しください | endpoint実値は出さない |

表示しないもの:

- Project URL
- anon key / publishable key
- token
- UUID全文
- email
- SQL詳細
- `service_role`
- secret key
- DB password

## 9. ロールバック方針

実装後に問題が出た場合は、以下の順で未構成フォールバックへ戻す。

1. Auth client JS読み込みを外す
2. Supabase SDK読み込みを外す
3. runtime config読み込みを外す
4. `mypage.html` を未構成フォールバックへ戻す
5. `assets/js/renderMypage.js` をA-3 / M-2状態へ戻す
6. Supabase接続を試みない状態へ戻す
7. Supabase側ロールバックは不要にする

M-5はDB変更を伴わない前提のため、ロールバックはフロント差分だけで完結させる。

## 10. 接続前チェックリスト

- RLS smoke testがFAIL 0である
- `public_profiles` は公開用途では `id` / `display_name` 中心の最小公開である
- `profiles` 本体をanon公開していない
- 公開RPC / viewが内部user_id、Discord ID、email、内部roleを返さない
- `service_role` は未使用である
- secret key / DB password / direct connection stringを使わない
- publishable key / anon keyを公開前提で扱い、GitHub Pages静的サイトで実接続へ進む方針が確認済みである
- repoへ実値を置く場合、それが秘匿されない値であることを前提にしている
- 実Project URL / keyをdocs、README、チャットへ貼らない
- localStorageへURL / key / tokenを独自保存しない
- エラー表示やconsoleにProject URL、key、token、email、UUID全文を出さない
- 未構成フォールバックへ戻すrollback手順がある

## 11. 次工程候補

1. この計画書のcommit / push
2. 実値をdocs / README / チャットへ記録しない運用を再確認
3. `docs/supabase-mypage-auth-client-restore-final-check.md` でM-5実装直前のAuth client初期化方式、実装後確認手順、ロールバック方針を最終確認
4. M-5実装可否判断
5. 実装する場合は、`mypage.html` 内のAuth client初期化・`auth.getSession` 復元だけに限定する
6. 問題が出た場合はC案の未構成フォールバックへ戻す
