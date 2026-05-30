# Supabase A-4 mypage Auth状態表示 実装計画書

## 1. 目的

この計画書は、`mypage.html` にSupabase Auth状態表示を入れる前に、実装範囲、接続情報の扱い、表示情報、ロールバック方針を整理するためのものです。

A-4の目的:

- `mypage.html` でログイン中 / 未ログイン / 読み込み失敗を表示する
- ログイン中の場合は `public_profiles.display_name` を表示する
- `session-detail.html` 本文中ではなく、マイページでログイン状態を扱う
- 接続設定が未構成でも既存の静的マイページ表示を壊さない
- ログインフォーム、ログアウト処理、申請一覧表示は別工程として扱う

F-3 devプロトタイプでは、Authセッション復元、ログイン状態表示、`public_profiles.display_name` 取得は確認済みです。A-4ではその知見を本番導線へ移す前段として、まずマイページに限定して安全な表示範囲を決めます。

この工程では実装しません。`mypage.html`、既存HTML、既存JS、既存CSSへの変更は次工程で判断します。

## 2. 現在の前提

現在の本番側の前提:

- 共通ヘッダーに静的な `ACCOUNT` 導線がある
- `ACCOUNT` は `mypage.html` へ遷移する
- `mypage.html` は静的な準備中ページとして存在する
- `assets/js/renderMypage.js` は準備中文言と戻り導線だけを描画している
- Supabase接続、Auth復元、ログイン / ログアウト処理はまだ本番側へ入れていない

A-4は、この静的マイページへ「Auth状態表示欄」を段階追加するための計画です。

## 3. A-4で扱う範囲

A-4で扱う候補:

```text
Authセッション復元
ログイン状態表示
display_name表示
接続設定未構成時の安全フォールバック
短いエラー表示
```

推奨する分割:

| 段階 | 扱うこと | 扱わないこと |
| --- | --- | --- |
| A-4a | 接続設定未構成時の安全フォールバック、Auth状態表示欄の器 | Supabase初期化、Auth復元、ログイン、ログアウト |
| A-4b | 公開可能な接続設定が確定した後のAuthセッション復元、`display_name` 表示 | ログインフォーム、ログアウト処理、申請一覧 |

安全優先の推奨は、まずA-4aで「設定がなければ安全に準備中表示」を実装し、その後A-4bでAuth復元を入れることです。

A-4でまだ扱わない候補:

```text
ログインフォーム
ログアウトボタン
自分の申請一覧表示
参加確定セッション一覧
コメント履歴
GM管理機能
```

## 4. 表示してよい情報 / 表示しない情報

表示してよい情報:

- ログイン中 / 未ログイン
- `public_profiles.display_name`
- 簡潔な案内文
- 簡潔なエラー文

表示しない情報:

- `user_id` 全文
- `discord_user_id`
- email
- access token
- refresh token
- service_role
- secret key
- DB password
- 内部role
- Supabase Project URL
- anon key / publishable key

メールアドレスは、F-3 devでは表示確認済みですが、本番PL向けでは原則表示しません。必要になった場合も、マイページ内の限定表示として別途検討します。

## 5. Supabase接続情報の扱い

必須方針:

- service_role は絶対に使わない
- secret key / DB password は絶対に使わない
- Project URL / anon key / publishable key 実値をREADMEやdocsに記録しない
- Project URL / anon key / publishable key 実値をチャットへ貼らない
- `.env.local` はGit管理しない
- localStorageへURL / key / tokenを独自保存しない
- Supabase Auth標準のセッション永続化を使う場合は、ログアウト時の消去挙動を実装前に確認する

GitHub Pages静的運用での候補:

| 案 | 内容 | 評価 |
| --- | --- | --- |
| A案 | 静的JSに公開可能anon / publishable keyを直接設定する | no-build運用では単純。ただし実値がリポジトリに入るため、公開可能keyであることの最終確認が必須 |
| B案 | runtime configファイルを分離する | 推奨。公開される点は同じだが、接続設定とAuth処理を隔離しやすい。repoにはexampleだけを置く |
| C案 | まず接続設定未構成フォールバックだけ実装する | 最も安全。Auth復元はまだ行わず、UIと失敗時挙動だけ確認できる |

推奨:

```text
A-4aではC案を採用し、接続設定未構成時の安全フォールバックだけを入れる。
A-4bではB案を基本に、runtime config分離とAuth復元を検討する。
```

`assets/js/supabaseRuntimeConfig.example.js` を作る場合も、実URLや実keyは入れずplaceholderだけにします。

## 6. 実装対象ファイル案

将来実装時の候補:

```text
mypage.html
assets/js/renderMypage.js
assets/js/mypageAuthState.js
assets/js/supabaseAuthClient.js
assets/js/supabaseRuntimeConfig.example.js
README.md
docs/task-backlog.md
```

推奨は新規JS分離です。

理由:

- 静的準備中ページの描画とAuth処理を分けられる
- Supabase接続部分を隔離できる
- 接続設定未構成時のフォールバックを独立して検証できる
- ロールバックしやすい
- 将来ログイン / ログアウト実装へ拡張しやすい

`renderMypage.js` にはAuth状態欄の表示用DOMだけを置き、Supabase初期化やAuth復元処理は `mypageAuthState.js` または `supabaseAuthClient.js` に分離する方針がよいです。

## 7. UI配置案

候補:

| 案 | 内容 | 評価 |
| --- | --- | --- |
| 準備中カードの上部にログイン状態カード | `マイページ` 見出し直下に独立カードを置く | 推奨。状態確認と今後対応案内を分けやすい |
| 準備中カード内にログイン状態欄を追加 | 既存カード内に短く追加する | 差分は小さいが、今後の拡張で混ざりやすい |
| ログイン状態カードと今後対応案内を横並びにする | PCでは見やすい | スマホで崩れやすく、最小版には過剰 |

推奨:

```text
準備中カードの上に「ログイン状態」カードを追加する。
Auth状態表示と、今後対応予定の案内は別カードにする。
```

表示例:

```text
ログイン状態
確認中です。
```

```text
ログイン状態
現在ログインしていません。
```

```text
ログイン状態
ログイン中: 表示名
```

接続設定未構成時:

```text
ログイン状態
アカウント機能は準備中です。
```

## 8. エラー表示方針

想定する状態と表示:

| 状態 | 表示文言案 |
| --- | --- |
| 接続設定未構成 | アカウント機能は準備中です。 |
| Supabase初期化失敗 | ログイン状態を確認できませんでした。 |
| Authセッション復元失敗 | ログイン状態を確認できませんでした。時間をおいて再度お試しください。 |
| `public_profiles` 取得失敗 | 表示名を取得できませんでした。 |
| ネットワークエラー | 通信に失敗しました。時間をおいて再度お試しください。 |
| 未ログイン | 現在ログインしていません。 |

エラー表示に出さないもの:

- URL
- key
- token
- UUID全文
- email
- 内部SQL
- Supabaseの生エラー全文

開発確認時に詳細が必要な場合も、ユーザー向け画面には伏せた短い文言を出します。consoleにもURL / key / token / passwordは出しません。

## 9. ロールバック方針

A-4実装後に問題が出た場合の戻し方:

1. Auth用JS読み込みを外す
2. `mypage.html` または `renderMypage.js` のAuth状態欄を非表示または削除する
3. `renderMypage.js` を静的準備中表示へ戻す
4. runtime config読み込みを止める
5. `mypageAuthState.js` / `supabaseAuthClient.js` を読み込まない
6. README / backlog の実装済み記述を戻す

A-4は表示とAuth状態取得のみのため、Supabase側のロールバックは不要です。

## 10. 実装前チェックリスト

A-4実装へ進む前に確認すること:

- RLS smoke testが FAIL 0 である
- F-3 devログイン状態表示の挙動が確認済みである
- A-2静的ACCOUNT導線がユーザー実ブラウザ確認済みである
- A-3 `mypage.html` 最小版がユーザー実ブラウザ確認済みである
- 本番に表示してよい情報が `display_name` 中心に限定されている
- メールアドレスは原則表示しない方針で合意済みである
- Supabase接続情報の扱いを確定している
- 接続設定未構成時のフォールバック文言を確定している
- ロールバック手順を確認済みである

## 11. 実装後の確認項目案

A-4実装後に確認すること:

- `mypage.html` が既存通り開く
- ヘッダー / フッターが壊れていない
- 接続設定未構成時に安全な準備中表示になる
- 接続設定未構成時にSupabase接続を試みない
- ログイン中 / 未ログイン / 読み込み失敗の表示が出し分けられる
- `display_name` だけを表示し、emailやuser_id全文を出さない
- URL / key / token / passwordを画面やconsoleに出さない
- ログインフォームやログアウトボタンを増やしていない
- 申請一覧、投稿、編集、削除、GM操作を増やしていない
- スマホ幅で大きく崩れない

## 12. A-4で扱わないもの

A-4では以下を扱いません。

- ログインフォーム
- ログアウト処理
- 自分の申請一覧表示
- 参加予定セッション表示
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

## 13. 次工程候補

1. この計画書のcommit / push
2. A-4a 接続設定未構成時フォールバック実装
3. A-4a ローカル実ブラウザ確認
4. Supabase接続情報の公開方針最終確認
5. A-4b Authセッション復元と `display_name` 表示の実装判断

## 14. A-4a 方針修正メモ

A-4aとして、`mypage.html` の静的描画にログイン状態カードの器を追加する最小フォールバック案をローカルで検討した。

ユーザー確認後のUX方針として、以下を決定した。

- マイページにログイン状態だけを常時大きく表示するカードは採用しない
- ログアウトしていない限りログイン状態は維持されるため、状態そのものを独立カードで強調する必要は薄い
- 将来的には、ログイン / ログアウト、申請一覧、参加予定、コメント履歴など、マイページ内で必要な操作や情報へ進める形にする
- 次に進む場合は、Auth状態表示単体ではなく、マイページ全体のアカウント操作UXとして再設計する

撤回したもの:

- `assets/js/renderMypage.js` 内の静的なログイン状態カード
- 「現在、ログイン状態表示は準備中です。」
- 「接続設定が未構成のため、Supabaseには接続していません。」
- 「ログイン、ログアウト、参加申請一覧の表示は今後対応予定です。」

引き続き未実装のもの:

- Supabase SDK読み込み
- Supabase client初期化
- Authセッション復元
- ログイン処理
- ログアウト処理
- `public_profiles.display_name` 取得
- 申請一覧、投稿、編集、削除、GM操作

A-4a方針修正後も、Project URL / anon key / publishable key 実値、token、email、`user_id` 全文、`discord_user_id` は表示・記録しない。

## 15. マイページ全体UX再設計への分離

A-4a方針修正を受け、Auth状態表示単体ではなく、マイページ全体のアカウント操作UXを `docs/supabase-mypage-account-actions-ux-plan.md` に分離する。

新方針:

- ログイン状態だけを大きく表示するカードは採用しない
- ログイン / ログアウト、申請状況、参加予定など、ユーザーが次にできることと一体化して扱う
- `session-detail.html` 本文中にはログインフォームやログイン状態常時表示を置かない
- Supabase接続、Auth復元、ログイン / ログアウトは、再設計書の段階実装案に沿って後続工程で判断する

## 16. runtime config / 未構成フォールバック計画への分離

Supabase Auth実装前のruntime config分離と、接続設定未構成時の安全フォールバックは `docs/supabase-mypage-runtime-config-fallback-plan.md` に分離する。

新しい段階方針:

- まず接続設定未構成時のフォールバックUXを、ログイン状態カード単体ではなくマイページのアカウント操作導線内で扱う
- 次に実値なしのruntime config exampleを検討する
- 実Project URL / anon key / publishable key実値はREADME、docs、チャットへ記録しない
- Supabase SDK読み込み、client初期化、Auth復元、ログイン / ログアウトは後続工程で判断する
