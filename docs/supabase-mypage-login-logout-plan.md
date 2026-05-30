# Supabase M-6 mypage ログイン / ログアウト最小実装 計画書

この計画書は、M-5で追加した `mypage.html` のAuth client初期化・既存セッション復元の器を前提に、次工程でログイン / ログアウト最小機能を実装する前の範囲、UI、安全条件、確認手順、ロールバック方針を整理するためのものです。

この工程では、実装、`mypage.html` 変更、`assets/js/renderMypage.js` 変更、`assets/js/mypageAuthClient.js` 変更、`assets/js/supabaseRuntimeConfig.js` 変更、Supabase SQL実行、追加RPC実行、`display_name` 取得、申請一覧表示、投稿統合は行わない。

## 1. 目的

- `mypage.html` 内でログイン / ログアウトを扱う。
- 共通ヘッダーは静的 `ACCOUNT` 導線のまま維持する。
- `session-detail.html` 本文中にはログインフォームを置かない。
- ログイン後もemail、user_id、tokenを画面に出さない。
- まずはAuthの入口と出口だけを作る。
- ログイン状態カード単体には戻さず、アカウント機能セクション内の操作導線として扱う。

## 2. 現在の前提

- M-5最小実装はcommit / push済み。
- `mypage.html` はマイページ専用にruntime configとAuth client JSを読み込む。
- `assets/js/mypageAuthClient.js` は、Supabase client初期化と `auth.getSession` による既存セッション復元の器を持つ。
- `assets/js/supabaseRuntimeConfig.js` は実configとして扱われているため、M-6計画作成工程では変更しない。
- GitHub Pages公開版で `mypage.html` 表示、未ログイン表示、ログインフォームなし、ログアウトボタンなし、email / user_id / token非表示、コンソールエラーなし、`ACCOUNT` 導線が確認済み。

## 3. M-6で実装する範囲

M-6実装では以下に限定する。

- メールアドレス + パスワードによるログインフォーム。
- Supabase Auth `signInWithPassword`。
- ログアウトボタン。
- Supabase Auth `signOut`。
- ログイン成功後の短い表示更新。
- ログアウト成功後の未ログイン表示。
- エラー時の短い日本語表示。
- 入力中 / 送信中の最小状態。

ログイン成功後も、表示は「ログイン済みです」程度に留める。email、user_id、tokenは表示しない。

## 4. M-6でまだ扱わないもの

- `display_name` 取得。
- `public_profiles` 取得。
- ユーザーID表示。
- メールアドレス表示。
- 自分の申請一覧。
- 参加予定セッション。
- コメント履歴。
- `session-detail.html` 投稿統合。
- コメント編集・削除統合。
- GM承認・却下統合。
- Discord OAuth。
- Discord通知。
- メール通知。
- Edge Functions。
- `close_session`。
- 追加SQL。
- 追加RPC実装。

## 5. UI方針

ログイン状態カード単体には戻さない。`mypage.html` の「アカウント機能」セクション内に統合する。

未ログイン時の表示方針:

```text
ログインすると、今後ここで参加申請状況や参加予定を確認できるようになります。
メールアドレス
パスワード
ログイン
```

ログイン済み時の表示方針:

```text
ログイン済みです。
参加申請一覧・参加予定セッションは今後対応予定です。
ログアウト
```

補足:

- ログイン済みでもemail / user_idは表示しない。
- パスワード欄は `type="password"` とし、ログイン成功 / 失敗後にクリアする。
- フォームはアカウント機能セクション内に置き、ページ全体の主役にしすぎない。
- トップ / CALENDARへ戻る導線は維持する。
- 共通ヘッダーの `ACCOUNT` は静的リンクのまま維持する。

## 6. エラー表示方針

表示してよい例:

- ログインできませんでした。入力内容を確認してください。
- ログアウトに失敗しました。時間を置いて再度お試しください。
- アカウント機能を初期化できませんでした。
- 通信に失敗しました。時間を置いて再度お試しください。

表示してはいけないもの:

- Project URL。
- anon key / publishable key。
- access token。
- refresh token。
- UUID全文。
- email。
- SQL詳細。
- `service_role`。
- secret。
- DB password。
- direct connection string。

consoleへ出す場合も原因カテゴリに留める。Supabase errorの生値をそのまま表示・出力しない。

## 7. セキュリティ方針

- `service_role` / secret / DB passwordは絶対に使わない。
- Supabase Auth SDKの標準セッション管理を使う。
- URL / key / tokenを独自にlocalStorage保存しない。
- tokenをconsoleや画面に出さない。
- ログイン失敗時に詳細すぎる内部エラーを出さない。
- emailは入力値としてのみ扱い、ログイン後の状態表示には出さない。
- パスワードは保存しない。送信後は入力欄から消す。
- `assets/js/supabaseRuntimeConfig.js` はM-6では原則変更しない。

## 8. 実装対象ファイル案

M-6実装候補:

| ファイル | 想定役割 |
| --- | --- |
| `mypage.html` | 既存読み込みの維持。必要なcache-bust query更新候補 |
| `assets/js/renderMypage.js` | アカウント機能セクション内にログインフォーム / ログアウト表示のDOMを置く候補 |
| `assets/js/mypageAuthClient.js` | `signInWithPassword` / `signOut` / 状態更新 / エラー整形を担当する候補 |
| `README.md` | 実値なしの作業メモ参照 |
| `docs/task-backlog.md` | 次工程候補整理 |

原則変更しない:

- `assets/js/supabaseRuntimeConfig.js`
- `assets/js/supabaseRuntimeConfig.example.js`
- `session-detail.html`
- `updates.json`

## 9. 実装時の確認手順

ローカル確認:

1. `mypage.html` が開く。
2. 未ログイン時にログインフォームが表示される。
3. 誤ったログイン情報で短いエラーが出る。
4. 正しいログイン情報でログインできる。
5. ログイン後にemail / user_id / tokenが表示されない。
6. ログアウトできる。
7. ログアウト後に未ログイン表示へ戻る。
8. コンソールエラーがない。
9. `ACCOUNT` 導線が壊れていない。
10. トップ / CALENDARへ戻る導線が維持される。

公開確認:

1. GitHub Pages反映後に `mypage.html` を確認する。
2. ログインフォームが表示される。
3. ログインできる。
4. ログアウトできる。
5. email / user_id / tokenが表示されない。
6. コンソールエラーがない。
7. `ACCOUNT` 導線から `mypage.html` へ遷移できる。

## 10. ロールバック方針

問題が出た場合は以下の順でM-5状態へ戻す。

1. ログインフォーム描画を外す。
2. ログアウトボタン描画を外す。
3. `signInWithPassword` 呼び出しを外す。
4. `signOut` 呼び出しを外す。
5. M-5のAuth復元のみ状態へ戻す。
6. Git revert可能な単位でcommitする。
7. Supabase側ロールバックは不要にする。

M-6はDB変更を伴わない前提のため、ロールバックはフロント差分だけで完結させる。

## 11. 実装直前の停止条件

以下に該当する場合は、M-6実装へ進まず設計へ戻る。

- ログインに `service_role` / secret / DB passwordが必要になる。
- URL / key / tokenを独自localStorage保存する必要が出る。
- email / user_id / tokenを画面に出す設計になる。
- Supabase errorの生値をそのまま表示・console出力する設計になる。
- `session-detail.html` 本文中にログインフォームを置く必要が出る。
- `display_name` / 申請一覧 / 投稿統合まで同時に入れる必要が出る。

## 12. 次工程候補

1. この計画書のcommit / push。
2. ユーザー確認後、M-6ログイン / ログアウト最小実装可否を判断する。
3. 実装する場合は、`mypage.html` のアカウント機能セクション内のログイン / ログアウトだけに限定する。
4. 問題が出た場合はM-5のAuth復元のみ状態へ戻す。

## 13. M-6最小実装メモ

M-6最小実装として、`mypage.html` のアカウント機能セクション内にメールアドレス + パスワードログイン、Supabase Auth `signInWithPassword`、ログアウトボタン、Supabase Auth `signOut` を追加した。

既存の `auth.getSession` によるセッション復元は維持し、ログイン済みセッションがある場合はログインフォームではなくログイン済み表示とログアウトボタンを出す。ログイン後もemail / user_id / tokenは画面に出さない。

`display_name` / `public_profiles` 取得、自分の申請一覧、参加予定セッション、コメント履歴、`session-detail.html` 投稿統合、GM操作、追加SQL、追加RPCは未実装のまま。
