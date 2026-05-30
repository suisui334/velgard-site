# Supabase M-2/M-3 mypage runtime config分離・未構成フォールバック実装計画書

この計画書は、`mypage.html` にSupabase Authを実装する前に、runtime configの分離と、接続設定が未構成の場合の安全フォールバックをどう扱うかを整理するためのものです。

この工程では実装、HTML / JS / CSS変更、Supabase接続、Auth復元、ログイン / ログアウト、実URL / key投入、追加SQL実行は行いません。

## 1. 目的

- Supabase Auth実装前にruntime configの扱いを決める
- 実Project URL / anon key / publishable key実値をGitHub、README、docs、チャットに残さない
- 接続設定が未構成でも `mypage.html` が壊れないようにする
- ログイン状態カード単体ではなく、将来のアカウント操作UIの一部として扱う
- A-3最小版の静的マイページを壊さず、段階的にAuth導線へ進める

## 2. 前提

- 共通ヘッダーの `ACCOUNT` は静的リンクとして `mypage.html` へ遷移する
- `mypage.html` はA-3最小版として、静的な準備中ページを表示している
- A-4aで試したログイン状態だけの常時カードは採用しない
- マイページは、ログイン / ログアウト、申請状況、参加予定などの操作入口として育てる
- F-3 devプロトタイプでは、Authセッション復元、ログアウト、`public_profiles.display_name` 取得は確認済み

## 3. runtime config候補比較

| 案 | 内容 | 利点 | リスク / 注意 |
| --- | --- | --- | --- |
| A案 | 静的JSへ公開可能keyを直接書く | no-build運用では単純 | 実値がrepoに入る。公開可能keyであってもレビューと合意が必要 |
| B案 | `assets/js/supabaseRuntimeConfig.js` を別ファイル化する | Auth処理と設定を分離できる | 実configをGit管理すると実値が残る。公開時運用の判断が必要 |
| C案 | `assets/js/supabaseRuntimeConfig.example.js` のみGit管理し、実ファイルはGit管理外にする | GitHub / docsに実値を残さず、形だけ共有できる | GitHub Pages公開時に実configをどう配布するか別途運用設計が必要 |
| D案 | まず未構成フォールバックだけ実装し、実接続は次工程に回す | 最も安全。実値なしでUIと失敗時挙動を確認できる | Auth復元やログイン可否は確認できない |

推奨:

1. まずD案で、接続設定未構成時の安全フォールバックだけを実装する。
2. 次にC案で、実値なしの `supabaseRuntimeConfig.example.js` だけをGit管理する。
3. 実Project URL / keyをどのように公開環境へ置くかは、M-4以降の実接続前に別途判断する。

## 4. Git管理するもの / しないもの

Git管理してよいもの:

- `supabaseRuntimeConfig.example.js`
- 接続設定未構成時のフォールバック表示
- 実値なしplaceholder
- docsの運用手順
- runtime configの存在チェック処理

Git管理しないもの:

- 実Project URL
- 実anon key / publishable key
- service_role
- secret key
- DB password
- `.env.local`
- 認証token

`.gitignore` で実configファイルを除外するかどうかは、M-3実装前に確認する。すでに除外済みでない場合は、実configファイル名を決めたうえで追加を検討する。

## 5. 未構成フォールバックUX

ログイン状態だけを大きく表示するカードは採用しない。未構成時の表示は、マイページ内の「アカウント操作」または「ログイン導線」予定地に短く統合する。

候補:

| 案 | 表示内容 | 評価 |
| --- | --- | --- |
| A案 | マイページ内のアカウント操作セクションに「ログイン機能は準備中です」と表示 | 推奨。状態表示ではなく、今後の操作入口として自然 |
| B案 | ログインフォーム予定地に「準備中」と表示 | ログイン実装の差し替えがしやすいが、フォーム未実装感が強い |
| C案 | ページ全体はA-3最小版のまま、実装時期まで何も出さない | 最小だが、M-2としてのフォールバック検証が見えにくい |

推奨案:

- A案を採用する。
- 文言は「ログイン機能は準備中です。今後、参加申請状況や参加予定を確認できるようにします。」程度に留める。
- 「接続設定が未構成です」を前面に出しすぎず、必要なら開発確認用の小さな補足にする。
- 未構成時もトップ / CALENDARへ戻る導線は維持する。

表示しないもの:

- email
- `user_id` 全文
- `discord_user_id`
- token
- key
- Project URL
- 内部role

## 6. 実装対象ファイル案

将来実装時の候補:

| ファイル | 役割 |
| --- | --- |
| `mypage.html` | 必要ならAuth用JS読み込みを追加 |
| `assets/js/renderMypage.js` | マイページ本文、アカウント操作セクション、未構成フォールバックDOMを描画 |
| `assets/js/mypageAuthActions.js` | マイページ内のログイン / ログアウト / Auth状態反映を担当 |
| `assets/js/supabaseAuthClient.js` | Supabase client初期化とAuth helperを隔離 |
| `assets/js/supabaseRuntimeConfig.example.js` | 実値なしplaceholder。Git管理可 |
| `README.md` | 実値なしの参照メモのみ |
| `docs/task-backlog.md` | 次工程候補の整理 |

M-2では、`mypageAuthActions.js` や `supabaseAuthClient.js` はまだ作らず、未構成フォールバックの表示方針だけを実装する案が安全。

M-3で `supabaseRuntimeConfig.example.js` を作る場合も、実値は入れず、shapeだけを示す。

## 7. Supabase接続情報の安全条件

- service_role は絶対に使わない
- secret key / DB password は絶対に使わない
- 実Project URL / anon key / publishable key はREADMEやdocsへ書かない
- チャットへも実値を貼らない
- localStorageへURL / key / tokenを独自保存しない
- Supabase Authのtoken管理は公式SDKの範囲に任せる
- エラー表示やconsoleにURL / key / token / email / UUID全文を出さない
- runtime configがない場合はSupabase client初期化を試みない

## 8. エラー表示方針

| 状態 | PL向け表示案 | 出さないもの |
| --- | --- | --- |
| 接続設定未構成 | アカウント機能は準備中です | URL / key |
| runtime configなし | アカウント機能は準備中です | ファイルパス詳細、実値名 |
| Supabase初期化失敗 | アカウント機能を読み込めませんでした | URL / key / 内部stack |
| Auth復元失敗 | ログイン状態を確認できませんでした | token / UUID全文 |
| ログイン失敗 | ログインできませんでした | email / 内部SQL |
| ログアウト失敗 | ログアウトできませんでした | token / 内部SQL |
| network error | 通信に失敗しました | Project URL / key |

開発者向けの詳細確認が必要な場合も、画面やdocsへ実値を記録しない。エラー整形時はF-3 devプロトタイプと同様に、URL風文字列、JWT風文字列、長いkey風文字列をredactする方針を引き継ぐ。

## 9. 段階実装案

| 段階 | 内容 | 実装可否 |
| --- | --- | --- |
| M-2 | 未構成フォールバックUXの最終方針 | 次工程候補 |
| M-3 | runtime config example作成 | M-2後 |
| M-4 | 実config運用方針確定 | 実接続前に必須 |
| M-5 | Auth client初期化 | runtime config確定後 |
| M-6 | Authセッション復元 | client初期化後 |
| M-7 | ログインフォーム | Auth復元確認後 |
| M-8 | ログアウト | ログイン導線とセットで確認 |
| M-9 | `display_name` 表示 | `public_profiles` 取得方針確定後 |

M-2/M-3では、Supabase SDK読み込み、client初期化、Auth復元はまだ行わない。

## 10. ロールバック方針

問題が出た場合の戻し方:

1. config読み込みを停止する
2. Auth用JSを外す
3. `assets/js/renderMypage.js` をA-3最小版へ戻す
4. `mypage.html` を静的準備中表示へ戻す
5. `supabaseRuntimeConfig.example.js` だけなら削除または未参照にする
6. Supabase側ロールバックは不要

M-2/M-3はDB状態変更を伴わないため、ロールバック時にSupabaseデータを戻す必要はない。

## 11. まだ扱わないもの

この計画では以下を扱わない。

- 実装
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
- コメント編集・削除統合
- GM承認・却下統合
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- 追加SQL実行

## 12. 次工程候補

1. この計画書のcommit / push
2. M-2 未構成フォールバックUX最小実装
3. M-3 `supabaseRuntimeConfig.example.js` 作成計画
4. M-4 実config運用方針の最終確認
5. M-5 Auth client初期化計画

## 13. M-2/M-3最小実装メモ

M-2/M-3最小実装では、以下だけを追加する。

- 実値なしの `assets/js/supabaseRuntimeConfig.example.js`
- `mypage.html` 内のアカウント操作セクションに、接続設定未構成時の準備中表示

実装上の注意:

- `supabaseRuntimeConfig.example.js` は資料ファイルとして置き、`mypage.html` からは読み込まない
- ログイン状態カード単体は追加しない
- 「ログイン中 / 未ログイン」は表示しない
- Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウトは実装しない
- 実Project URL / anon key / publishable key実値は記録しない
