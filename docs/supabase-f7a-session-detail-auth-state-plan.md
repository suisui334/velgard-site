# Supabase F-7a session-detailログイン状態表示 仮統合計画

## 1. 目的

F-7aは、本番 `session-detail.html` へSupabase連携を段階導入する最初の工程として、ログイン状態表示だけを仮統合するための計画である。

この段階で確認すること:

- `session-detail.html` 上でログイン中 / 未ログイン / 読み込み失敗を表示できる
- ログイン済みの場合に `public_profiles.display_name` を表示できる
- 投稿、編集、削除、承認、却下、参加人数表示はまだ扱わない
- 本番ページへ入れる前に、表示情報、接続情報、ロールバック方法を固定する

F-7aはF-3 devログイン状態表示プロトタイプの成果を本番ページに最小限持ち込むための工程であり、F-4以降の書き込み系RPCは対象外とする。

## 2. 現状前提

現在の `session-detail.html` は `#app` に `assets/js/main.js` を読み込み、`assets/js/renderSessionDetail.js` が静的 `data/sessions.json` から対象セッションを取得して表示している。

`assets/js/sessionDisplay.js` には、参加希望コメント欄の静的モックがある。これはまだSupabase接続しておらず、投稿ボタンや入力欄も実処理を持たない。

F-3 devプロトタイプでは以下を確認済み:

- Supabase Authのログイン状態確認
- ログイン / ログアウト
- 再読込後のセッション復元
- `public_profiles.display_name` 取得
- user_id全文、token、discord_user_idを画面に出さないこと

## 3. 表示してよい情報 / 表示しない情報

| 区分 | 表示方針 |
| --- | --- |
| ログイン状態 | `ログイン中` / `未ログイン` / `確認中` / `確認できませんでした` 程度を表示する |
| 表示名 | `public_profiles.display_name` を表示してよい |
| メールアドレス | F-3 devでは表示確認済みだが、本番PL向けでは原則非表示、必要なら一部マスク表示に留める |
| ログアウトボタン | F-7aでは任意。表示する場合もAuth状態表示欄内に限定する |
| ログイン案内 | 未ログイン時に短い案内文だけ表示する。ログインフォーム本体はF-7aでは慎重に扱う |
| 接続失敗 | 人間向けの簡潔なエラーだけ表示する |

表示しないもの:

- user_id全文
- discord_user_id
- access_token
- refresh_token
- service_role
- secret key
- DB password
- 内部role
- Project URL実値
- anon key実値

## 4. UI配置案

候補:

1. 参加希望コメント欄の上
2. セッション概要の下
3. 既存の静的コメントUIモック周辺

推奨は、参加希望コメント欄の上に小さなログイン状態表示ブロックを置く案。

理由:

- セッション本文の読書を邪魔しない
- 参加希望コメント欄へ進む前にログイン状態を確認できる
- GM操作欄と混ざりにくい
- 未ログイン時に自然にログイン案内を出せる
- 後続の投稿、編集、GM操作へ段階拡張しやすい

## 5. 実装対象ファイル案

F-7a実装時に変更・追加が必要になりそうなファイル:

```text
session-detail.html
assets/js/renderSessionDetail.js
assets/js/sessionAuthState.js
assets/js/supabaseClient.js
README.md
docs/task-backlog.md
```

推奨は、新規JS分離。

```text
assets/js/sessionAuthState.js
assets/js/supabaseClient.js
```

新規分離を推奨する理由:

- 既存の静的セッション詳細表示を壊しにくい
- Supabase接続部分を隔離できる
- 問題発生時に読み込みを外して戻しやすい
- 後続の投稿、編集、GM操作へ段階拡張しやすい

`renderSessionDetail.js` 側は、参加希望コメント欄付近へマウント用の小さなDOMを置くか、描画後に `sessionAuthState.js` が対象DOMを探して差し込む程度に留める。

## 6. Supabase接続情報の扱い

必須方針:

- service_roleは絶対に使わない
- secret key / DB passwordは絶対に使わない
- anon / publishable keyのみをフロント候補にする
- Project URL / anon key実値はREADMEやdocsに記録しない
- Project URL / anon key実値はチャットに貼らない
- `.env.local` はGit管理しない
- localStorageへURL / key / tokenを保存しない

接続情報の持ち方候補:

| 案 | 内容 | 評価 |
| --- | --- | --- |
| 静的JSに直接書く | GitHub Pagesのno-build運用では最も単純。ただし公開ソースに値が出るため、anon / publishableであることの最終確認が必須 |
| 別JSへ分離 | `supabaseClient.js` などに分ける。公開される点は同じだが、差し戻しや影響範囲確認はしやすい |
| ビルド時注入 | 値の管理はしやすいが、現サイトはno-build運用なので導入コストが高い |
| 未追跡config | ローカル検証向き。本番GitHub Pagesでは配信されないため、そのままでは本番運用に向かない |

F-7a実装前に、GitHub Pagesで公開してよいkeyがanon / publishable相当であることを再確認する。

## 7. ログイン方式の推奨

F-7aでは、既存Supabase Authセッションを復元してログイン状態を表示することを優先する。

推奨:

- F-7aではログイン状態表示・復元確認を中心にする
- ログインフォーム本体はまだ本番に置かない
- 未ログイン時は短いログイン案内を表示する
- ログアウトボタンは任意。置く場合はログイン済み時だけ表示し、DB状態変更は行わない

本格的なログインフォーム、参加希望コメント投稿、GM操作はF-7b以降で扱う。

## 8. エラー表示方針

想定するエラー:

- Supabase未接続
- セッション復元失敗
- `public_profiles` 取得失敗
- ネットワークエラー
- 未ログイン

本番PL向けには、以下のような短いメッセージに留める。

```text
ログイン状態を確認できませんでした。時間をおいて再度お試しください。
現在は未ログインです。参加希望コメント機能を使うにはログインが必要です。
表示名を取得できませんでした。
```

エラー表示に出さないもの:

- Project URL
- anon key
- token
- UUID全文
- email
- 内部SQL
- Supabaseの生エラー全文のうちsecret類を含む可能性があるもの

## 9. ロールバック方針

F-7a実装後に問題が出た場合は、以下の順で戻せるようにする。

1. 追加JS読み込みを外す
2. ログイン状態表示DOMを非表示または削除する
3. `session-detail.html` の変更をrevertする
4. `assets/js/sessionAuthState.js` / `assets/js/supabaseClient.js` の読み込みを止める
5. 静的セッション詳細表示は維持する

F-7aは表示のみのため、DB状態変更のロールバックは不要。ただし、接続情報を誤って出した場合は即時差し戻しとkey再発行を検討する。

## 10. 実装前チェックリスト

F-7a実装へ進む前に確認すること:

- RLS smoke testがFAIL 0である
- F-3 devログイン状態表示の挙動確認済みである
- F-7 UX設計が確認済みである
- 本番に表示してよい情報が確定している
- メールアドレスを表示するか、非表示またはマスクにするか決めている
- Supabase接続情報の扱いが確定している
- ロールバック手順を確認済みである
- 本番ページで投稿、編集、削除、承認、却下をまだ有効化しない合意がある

## 11. F-7aで扱わないもの

F-7aでは以下を扱わない。

- 参加希望コメント投稿
- コメント編集
- コメント削除
- GM承認・却下
- GMコメント管理
- 参加人数RPC表示
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- 追加SQL実行

## 12. 次工程候補

1. F-7a計画書のcommit / push
2. Supabase接続情報の公開方針の最終確認
3. ログイン状態表示のみの本番仮統合実装
4. 本番ページ上でログイン状態表示のブラウザ確認
5. 問題なければF-7b以降でログイン導線または公開コメント読み取りを検討する

## 13. F-7aローカル確認後の方針修正

F-7a最小実装のローカル確認では、`session-detail.html` 本文中にログイン状態表示欄を差し込み、接続設定未構成時にSupabaseへ接続せず安全に準備中表示へフォールバックすることを確認した。

確認できたこと:

- 既存セッション詳細表示は壊れない
- 参加希望コメント欄の上にログイン状態表示欄を出せる
- 接続設定未構成時はSupabaseへ接続せず準備中表示にできる
- 投稿・編集・削除・GM操作UIを増やさずに済む
- 実URL / anon key / publishable key 実値を含めない運用にできる

ただし、ユーザー確認後のUX判断として、本番 `session-detail.html` 本文中にログイン状態を常時表示する方針は採用しない。

修正後の本番UX方針:

- ログイン状態はセッション詳細本文中に常時表示しない
- 将来的には右上または左上など、サイト共通ヘッダー付近にアカウントアイコンを置く
- アカウントアイコンからマイページへ遷移する導線を検討する
- ログアウトしない限りログイン状態は維持される前提で設計する
- F-7a最小実装はcommitせず、本文常時表示ではなく共通アカウント導線へ再設計する

このため、`assets/js/sessionAuthState.js` や `assets/js/supabaseRuntimeConfig.example.js` のような `session-detail.html` 専用の未使用JSは本番リポジトリに残さない。今後の認証UIは、サイト共通ヘッダー / マイページ導線として改めて設計する。

関連する再設計は `docs/supabase-account-nav-mypage-ux-plan.md` に分離する。共通ヘッダー付近のアカウントアイコン、マイページ最小構成、ログイン / ログアウト導線、Supabase接続情報の扱いはそちらを正とする。

未実装のまま維持するもの:

- ログインフォーム
- ログアウトボタン
- 参加希望コメント投稿
- コメント編集
- コメント削除
- GM承認・却下
- 参加人数RPC表示
- `close_session`
