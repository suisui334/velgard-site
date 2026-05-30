# Supabase M-7 mypage 一般サインアップ実装計画書

この計画書は、`mypage.html` のアカウント機能セクションに、誰でも登録できる一般サインアップフォームを実装する前に、仕様、UI、Supabase設定確認、安全条件、確認手順、ロールバック方針を整理するためのものです。

この工程では、実装、`mypage.html` 変更、`assets/js/mypageAuthClient.js` 変更、`assets/js/renderMypage.js` 変更、`signUp` 実装、Supabase Auth設定変更、追加SQL実行、`display_name` 登録、`profiles` / `public_profiles` 書き込みは行わない。

## 1. 現状整理

- M-6最小実装として、`mypage.html` 内のメールアドレス + パスワードログイン、`signInWithPassword`、ログアウトボタン、`signOut` は実装済み。
- 既存ユーザーは `mypage.html` でログイン / ログアウトできる。
- サイト上からの新規アカウント登録は未実装。
- ログイン後もemail / user_id / tokenは画面に出さない方針を維持している。
- `display_name` / `public_profiles` 取得、自分の申請一覧、参加予定セッション、コメント履歴、`session-detail.html` 投稿統合、GM操作は未実装。
- ユーザー方針として、アカウント登録方式は「サイト上に、誰でも登録できる一般サインアップフォームを置く」方針とする。

既存のマイページUX設計では、M-7を `display_name` 表示候補としていたが、今回の方針によりM-7は一般サインアップ計画へ切り替える。`display_name` 登録 / 表示は後続工程へ分ける。

## 2. M-7で実装する候補

M-7実装では以下に限定する。

- メールアドレス + パスワードの新規登録フォーム。
- パスワード確認入力。
- Supabase Auth `signUp`。
- 登録成功時の短い案内。
- メール確認が必要な場合の案内。
- 登録失敗時の短い日本語エラー表示。
- 既存ログインフォームとの切り替え。
- 入力中 / 送信中の最小状態。

登録成功後の表示は、以下のような短い案内に留める。

```text
登録を受け付けました。メール確認が必要な場合は、届いたメールを確認してください。
```

登録直後もemail / user_id / tokenは画面に出さない。

## 3. M-7でまだ扱わないもの

- `display_name` 登録。
- `public_profiles` / `profiles` へのプロフィール作成。
- ユーザーID表示。
- メールアドレス表示。
- 自分の申請一覧表示。
- 参加予定セッション表示。
- コメント履歴。
- `session-detail.html` 投稿統合。
- コメント編集・削除統合。
- GM承認・却下統合。
- Discord OAuth。
- メールテンプレート編集。
- Edge Functions。
- 追加SQL。
- 追加RPC実装。

M-7ではまず「アカウントを作れる」ことに絞る。表示名登録、プロフィール作成、本人向け情報表示は後続工程で扱う。

## 4. Supabase側設定確認

M-7実装前に、Supabase Dashboard上で以下を確認する。ただし、この計画書作成工程では設定変更しない。

| 確認項目 | 確認内容 |
| --- | --- |
| Allow new users to sign up | 一般ユーザーの新規登録を許可する運用にするか。公開サイトから誰でも登録できる影響を確認する |
| Confirm Email | 登録後にメール確認を必須にするか。必須の場合、UIでは確認メール案内を出す |
| Site URL | メール確認後やAuthリンク後の戻り先が公開サイトの想定URLになっているか |
| Redirect URLs | `mypage.html` や公開サイトURLが許可されているか。実URLはdocsへ記録しない |
| Email provider | 確認メールが送れる状態か。送信元名、到達性、送信制限を確認する |
| Rate limit / abuse対策 | 公開サインアップによる連投、捨てアドレス、bot登録への対策が運用上許容できるか |

設定が不足している場合は、M-7実装へ進む前にユーザー確認へ戻る。

## 5. UI方針

ログイン状態カード単体には戻さず、`mypage.html` の「アカウント機能」セクション内に統合する。

未ログイン時は、ログインと新規登録を同じセクション内で切り替えられるようにする。

推奨案:

- 「ログイン」「新規登録」の2つのタブまたはセグメント風切り替えを置く。
- 初期表示はログインフォームのままにする。
- 新規登録を選ぶと同じ場所でサインアップフォームへ切り替える。
- フォームの下に小さな戻り導線として「ログインに戻る」を置く。

理由:

- ログインフォームの下にボタンを追加するだけだと、ログイン送信ボタンと登録導線が近くなりやすい。
- タブ切り替えなら、ログインと登録の文脈が分かれ、フォーム項目の増加による混乱を抑えやすい。
- `mypage.html` 内で完結し、`session-detail.html` 本文中へフォームを置かない方針を維持できる。

登録フォーム項目:

```text
メールアドレス
パスワード
パスワード確認
登録する
```

登録後表示:

```text
登録を受け付けました。メール確認が必要な場合は、届いたメールを確認してください。
```

## 6. エラー表示方針

表示してよい例:

- 登録できませんでした。入力内容を確認してください。
- パスワードが一致しません。
- パスワードは十分な長さで入力してください。
- すでに登録済みの可能性があります。ログインをお試しください。
- 通信に失敗しました。時間を置いて再度お試しください。

表示してはいけないもの:

- Project URL。
- anon key / publishable key。
- access token。
- refresh token。
- JWT。
- UUID全文。
- emailの詳細な存在確認。
- SQL詳細。
- `service_role`。
- secret。
- DB password。
- direct connection string。

ユーザー列挙を助けるような詳細エラーは出しすぎない。Supabase errorの生値を画面やconsoleへそのまま出さず、PL向けの短い文言へ丸める。

## 7. セキュリティ方針

- `service_role` / secret / DB passwordは絶対に使わない。
- Supabase Auth SDKの `signUp` を使う。
- URL / key / tokenを独自にlocalStorage保存しない。
- tokenをconsoleや画面に出さない。
- 登録失敗時に詳細すぎる内部エラーを出さない。
- email / user_id / tokenは画面に出さない。
- パスワードとパスワード確認は保存しない。送信後または失敗後に入力欄から消す。
- `assets/js/supabaseRuntimeConfig.js` はM-7では原則変更しない。
- `profiles` / `public_profiles` への書き込みはM-7では行わない。

## 8. 実装対象ファイル案

M-7実装候補:

| ファイル | 想定役割 |
| --- | --- |
| `mypage.html` | 既存読み込みの維持。必要なcache-bust query更新候補 |
| `assets/js/mypageAuthClient.js` | ログイン / 新規登録フォーム切り替え、`signUp`、エラー整形、成功案内を担当する候補 |
| `README.md` | 実値なしの作業メモ参照 |
| `docs/task-backlog.md` | 次工程候補整理 |
| `docs/supabase-mypage-signup-plan.md` | M-7計画正本 |

原則変更しない:

- `assets/js/supabaseRuntimeConfig.js`
- `assets/js/supabaseRuntimeConfig.example.js`
- `session-detail.html`
- `updates.json`

## 9. 実装時の確認手順

ローカル確認:

1. `mypage.html` が開く。
2. 未ログイン時にログインフォームが表示される。
3. 新規登録フォームへ切り替えられる。
4. パスワード不一致で短いエラーが出る。
5. 無効なメール / 短いパスワードで短いエラーが出る。
6. 登録成功時に短い案内が出る。
7. email / user_id / tokenが表示されない。
8. ログインフォームへ戻れる。
9. コンソールエラーがない。
10. `ACCOUNT` 導線が壊れていない。

公開確認:

1. GitHub Pages反映後に `mypage.html` を確認する。
2. 新規登録フォームが表示される。
3. 登録成功または確認メール案内が出る。
4. email / user_id / tokenが表示されない。
5. コンソールエラーがない。
6. `ACCOUNT` 導線から `mypage.html` へ遷移できる。

実メールアドレスやパスワードは、チャット、README、docs、作業報告へ出さない。

## 10. ロールバック方針

問題が出た場合は以下の順でM-6状態へ戻す。

1. サインアップフォーム描画を外す。
2. ログイン / 新規登録の切り替えUIを外す。
3. `supabase.auth.signUp` 呼び出しを外す。
4. M-6ログイン / ログアウトのみ状態へ戻す。
5. Git revert可能な単位でcommitする。
6. Supabase側ロールバックは不要にする。

M-7はDB変更や追加SQLを伴わない前提のため、ロールバックはフロント差分だけで完結させる。

## 11. 実装直前の停止条件

以下に該当する場合は、M-7実装へ進まず設計へ戻る。

- サインアップに `service_role` / secret / DB passwordが必要になる。
- Supabase Auth設定変更が未確認のままになる。
- email / user_id / tokenを画面に出す設計になる。
- 登録直後に `profiles` / `public_profiles` 書き込みまで同時に入れる必要が出る。
- Supabase errorの生値をそのまま表示・console出力する設計になる。
- ユーザー列挙を助ける詳細エラー表示が必要になる。
- `session-detail.html` 本文中にサインアップフォームを置く必要が出る。
- 追加SQL / Edge Functions / メールテンプレート編集まで同時に必要になる。

## 12. 次工程候補

1. この計画書のcommit / push。
2. Supabase側設定確認項目をユーザーが確認する。
3. ユーザー確認後、M-7一般サインアップ最小実装可否を判断する。
4. 実装する場合は、`mypage.html` のアカウント機能セクション内の新規登録だけに限定する。
5. 問題が出た場合はM-6ログイン / ログアウトのみ状態へ戻す。

## 13. M-7最小実装メモ

M-7一般サインアップとして、`mypage.html` のアカウント機能セクション内でログイン / 新規登録を切り替え、メールアドレス + パスワード + パスワード確認の登録フォームを表示する最小UIを追加した。

登録処理は Supabase Auth `signUp` を使う。登録成功時は「登録を受け付けました。確認メールが届いた場合は、メール内のリンクを確認してください。」という短い案内を出し、Supabaseがセッションを返した場合は既存のログイン済み表示へ切り替える。

`display_name` 登録、`profiles` / `public_profiles` 書き込み、自分の申請一覧、参加予定セッション、コメント履歴、`session-detail.html` 投稿統合、GM操作、追加SQL、追加RPCは未実装のまま。登録後もemail / user_id / tokenは画面に出さない。

## 14. M-8アカウント補助導線 実装メモ

M-8では、M-7のログイン / 新規登録UIを維持したまま、未ログイン時に「パスワードを忘れた方はこちら」導線を追加した。導線先はメールアドレスだけを入力する再設定フォームで、「再設定メールを送る」と「ログインへ戻る」を表示する。

再設定メール送信は Supabase Auth `resetPasswordForEmail` を使い、戻り先は現在のoriginと `mypage.html` の配置パスから組み立てる。GitHub Pagesの `/velgard-site/mypage.html` とローカルの `/mypage.html` の両方を想定し、メールアドレスの存在有無は画面で断定しない。

ログイン済みユーザーには「パスワードを変更する」導線を追加し、新しいパスワードと確認入力を受け付ける。変更処理は Supabase Auth `updateUser({ password })` に限定し、成功時は「パスワードを変更しました。」とだけ表示する。

登録済み可能性の案内は「登録できませんでした。すでに登録済みの可能性があります。ログイン、またはパスワード再設定をお試しください。」に変更した。`display_name` 登録、`profiles` / `public_profiles` 書き込み、自分の申請一覧、参加予定セッション、コメント履歴、`session-detail.html` 投稿統合、GM操作、追加SQL、追加RPCは未実装のまま。email / user_id / tokenは画面に出さない。

## 15. M-9 display_name登録方針修正

M-9修正として、新規登録時に `display_name` を入力し、Supabase Auth `signUp` のuser metadataへ渡す方針に変更した。既存ユーザーは `update_display_name` RPCでマイページから表示名を保存する。

ログイン済みユーザー向けの表示名編集では、現在の表示名を入力欄とは別に表示し、保存成功後に現在表示名と入力欄の両方を更新する。表示名取得完了時に入力中の値を元値へ戻さない。

この修正後も、自分の申請一覧、参加予定セッション、コメント履歴、`session-detail.html` 投稿統合、GM操作、追加SQL、追加RPCは未実装のまま。email / user_id / tokenは画面に出さない。
