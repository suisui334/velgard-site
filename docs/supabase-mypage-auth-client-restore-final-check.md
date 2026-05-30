# Supabase M-5 mypage Auth client初期化・Auth復元 最終確認メモ

このメモは、`mypage.html` のM-5実装へ進む直前に、Auth client初期化・Authセッション復元の実装方式、実configの扱い、UI、エラー表示、確認手順、ロールバック方針を最終整理するためのものです。

この工程では、実装、`mypage.html` 変更、`assets/js/renderMypage.js` 変更、実config作成、実Project URL / anon key / publishable key投入、Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウト、`display_name` 取得、申請一覧表示、追加SQL実行は行わない。

## 1. 現在の前提

- M-5実装計画書は `8d2767e Add Supabase mypage auth client restore plan` でcommit / push済み。
- `mypage.html` は静的なマイページ準備中ページとして存在する。
- 共通ヘッダーの `ACCOUNT` は `mypage.html` へ遷移する。
- `assets/js/renderMypage.js` には、アカウント機能の未構成フォールバック表示がある。
- `assets/js/supabaseRuntimeConfig.example.js` は実値なしの見本として存在し、HTMLからは読み込んでいない。
- Supabase SDK読み込み、client初期化、`auth.getSession`、ログイン / ログアウト、`display_name` 取得、申請一覧表示は未実装。
- ユーザー判断として、publishable key / anon keyは公開前提で扱い、GitHub Pages静的サイトでSupabase Auth実接続へ進む方向とする。
- 実Project URL / key実値、secret類、tokenはREADME、docs、チャット、作業報告へ記録しない。

## 2. M-5実装方式

M-5では、`assets/js/supabaseRuntimeConfig.js` を実configとして読み、`assets/js/supabaseRuntimeConfig.example.js` は実値なしの見本として維持する。

推奨する責務分担:

| 対象 | M-5での役割 |
| --- | --- |
| `mypage.html` | 必要な場合だけ、マイページ専用のruntime config / SDK / Auth client読み込みを追加する候補。全ページ共通化しない |
| `assets/js/renderMypage.js` | 既存の未構成フォールバックを初期表示として維持し、M-5状態に応じてアカウント機能セクションだけを短く更新する候補 |
| `assets/js/mypageAuthClient.js` | 新規候補。runtime config検査、Supabase SDK検査、client初期化、`auth.getSession` 復元を担当する |
| `assets/js/supabaseRuntimeConfig.js` | 実config候補。Project URLとpublishable / anon相当のkeyだけを置く。今回の最終確認工程では作成しない |
| `assets/js/supabaseRuntimeConfig.example.js` | 実値なしplaceholderのshape共有用。実値は入れない |

実装時は、`mypage.html` または `renderMypage.js` から、マイページに必要なJSだけを読み込む。現行 `assets/js/main.js` は全ページで読み込まれるため、Auth関連JSを静的importで全ページへ広げない。`renderMypage.js` 側で扱う場合は、マイページ描画時だけ動く動的読み込みを候補にする。

Supabase SDKを読み込む場合も、使うkeyはpublishable key / anon keyのみとする。`service_role`、secret key、DB password、direct connection string、tokenは使わない。

## 3. 実configの扱い

- GitHub Pagesで動かすため、実configを配信する場合は公開される前提になる。
- publishable key / anon keyはsecretではないが、公開値として扱う。
- repoへ実値を置く場合も、秘匿されない値としてレビューする。
- 安全性はkey秘匿ではなく、RLS、RPC、公開viewの最小化で担保する。
- README、docs、チャット、作業報告には実Project URL / key実値を書かない。
- `assets/js/supabaseRuntimeConfig.js` にはProject URLとpublishable / anon相当のkey以外を含めない。
- `.env.local` の中身は出力しない。
- localStorageへSupabase URL / key / tokenを独自保存しない。
- Auth token管理はSupabase SDK標準の範囲に任せる。

## 4. M-5で実装する範囲

M-5実装で扱う範囲:

- Supabase SDK読み込み
- runtime config読み込み
- Supabase client初期化
- `auth.getSession` による既存セッション復元
- 未ログイン表示
- 接続未構成時フォールバック
- 初期化失敗時の短いエラー表示

M-5は、ログイン済みか未ログインかを安全に確認する入口だけを作る工程とする。PL本人向けの情報表示や操作機能は後続工程に分ける。

## 5. M-5でまだ扱わないもの

- ログインフォーム
- ログアウトボタン
- `display_name` 取得
- `public_profiles` 取得
- 自分の申請一覧
- 参加予定セッション
- コメント履歴
- `session-detail.html` 連携
- 投稿、編集、削除
- GM操作
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- 追加SQL実行

## 6. UI方針

ログイン状態カード単体には戻さない。`mypage.html` のアカウント機能セクション内に、状態を短く統合する。

| 状態 | 表示方針 |
| --- | --- |
| 接続未構成 | アカウント機能は準備中です |
| 未ログイン | 未ログインです。ログイン機能は次段階で対応予定です |
| ログイン済み | ログイン状態を確認しました |
| 初期化失敗 | 初期化に失敗しました |
| セッション確認失敗 | セッションを確認できませんでした |

M-5では `display_name` 取得を行わないため、ログイン済みでも表示名は出さない。未ログイン時もログインフォームを出さず、次段階で対応予定であることを短く示す。

## 7. エラー表示方針

表示してよいもの:

- 接続設定未構成
- 初期化に失敗しました
- セッションを確認できませんでした
- 未ログインです

表示してはいけないもの:

- Project URL
- anon key / publishable key
- token
- UUID全文
- email
- SQL詳細
- `service_role`
- secret key
- DB password
- direct connection string

consoleへ出す場合も、原因カテゴリに留める。URL、key、token、email、UUID全文、SQL詳細は出さない。

## 8. 実装時の確認手順

M-5実装後は以下を確認する。

1. 未構成時: 既存の未構成フォールバックが壊れない。
2. configあり: Supabase client初期化ができる。
3. 未ログイン: 未ログイン表示になる。
4. 既存ログインセッションあり: セッションありとして表示できる。
5. consoleにProject URL、key、token、email、UUID全文を出さない。
6. `mypage.html` が壊れない。
7. 共通ヘッダーの `ACCOUNT` 導線が壊れない。
8. トップ / CALENDARへ戻る導線が維持される。
9. `session-detail.html` 本文中の常時ログイン状態表示へ戻らない。
10. JSON / JS構文確認とsecret混入チェックを実行する。

## 9. ロールバック方針

問題が出た場合は、以下の順で未構成フォールバックへ戻す。

1. `supabaseRuntimeConfig.js` の読み込みを外す。
2. Auth client JSを外す。
3. Supabase SDK読み込みを外す。
4. `assets/js/renderMypage.js` を未構成フォールバックへ戻す。
5. `mypage.html` をA-3 / M-2状態へ戻す。
6. Supabase接続を試みない状態へ戻す。
7. Git revert可能な単位でcommitする。

M-5はDB変更を伴わない前提のため、Supabase側ロールバックは不要にする。

## 10. 実装直前の停止条件

以下に該当する場合は、M-5実装へ進まず未構成フォールバックを維持する。

- 実Project URL / key実値をdocs、README、チャットへ貼る必要が出た場合。
- `service_role`、secret key、DB password、direct connection stringが必要になる設計になった場合。
- RLS smoke testがFAIL 0でない場合。
- 公開RPC / viewが内部user_id、Discord ID、email、内部roleを返す場合。
- エラー表示やconsoleにURL、key、token、email、UUID全文が出る設計になった場合。
- ロールバック手順がGit revertしにくい差分になった場合。

## 11. 最終確認メモ作成時に行っていなかったこと

- `mypage.html` の変更
- `assets/js/renderMypage.js` の変更
- `assets/js/supabaseRuntimeConfig.example.js` への実値投入
- `assets/js/supabaseRuntimeConfig.js` の作成
- Supabase SDK読み込み
- Supabase client初期化
- Auth復元
- ログイン処理
- ログアウト処理
- `display_name` / `public_profiles` 取得
- 自分の申請一覧表示
- 参加予定セッション表示
- Supabase SQL Editorでの追加SQL実行
- 実Project URL / anon key / publishable keyの記録
- secret類の出力・記録
- `updates.json` の変更

## 12. 次工程候補

1. この最終確認メモのcommit / push。
2. ユーザー確認後、M-5実装可否を判断する。
3. 実装する場合は、Auth client初期化と `auth.getSession` による既存セッション復元だけに限定する。
4. 問題が出た場合は、未構成フォールバックへ戻す。

## 13. M-5最小実装メモ

M-5最小実装として、Auth client初期化と既存セッション復元の器を追加した。

- `assets/js/supabaseRuntimeConfig.js` は空placeholderとして作成し、実Project URL / anon key / publishable key実値は入れていない。
- `assets/js/mypageAuthClient.js` は、`window.VELGARD_SUPABASE_CONFIG` の `url` / `anonKey` が空ならSupabase SDKを読み込まず、未構成フォールバックを維持する。
- configが入っている場合だけSupabase SDKを動的に読み込み、client初期化後に `auth.getSession` で既存セッションを確認する。
- 未ログイン時は「現在ログインしていません。ログイン機能は次の工程で対応予定です。」と短く表示する。
- ログイン済み時は「ログイン状態を確認しました。表示名や参加申請一覧は今後対応予定です。」と短く表示する。
- ログインフォーム、ログアウト、`display_name` 取得、`public_profiles` 取得、自分の申請一覧、参加予定セッションは未実装のまま。
- 実Project URL / key実値、secret類、tokenはREADME、docs、チャット、作業報告へ記録しない。

## 14. M-6ログイン / ログアウト計画への接続

次工程のログイン / ログアウト最小実装計画は `docs/supabase-mypage-login-logout-plan.md` に分離する。

M-6では、M-5のAuth client初期化・既存セッション復元の器を前提に、メールアドレス + パスワードログイン、`signInWithPassword`、ログアウトボタン、`signOut` だけを扱う。`display_name` 取得、`public_profiles` 取得、自分の申請一覧、参加予定セッション、`session-detail.html` 投稿統合はまだ扱わない。
