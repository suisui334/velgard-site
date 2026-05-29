# Supabase A-3 mypage.html最小版 実装計画書

## 1. 目的

この計画書は、共通アカウントアイコンのリンク先として `mypage.html` 最小版を用意する前に、ページ構成、表示内容、Supabase未接続時の扱い、ロールバック方針を整理するためのものです。

A-3の目的:

- 共通アカウントアイコンのリンク先として `mypage.html` 最小版を用意する
- A-2静的アイコン実装時にリンク先404を避ける
- この段階ではSupabaseへ接続しない
- Authセッション復元やログイン状態判定を行わない
- ログイン / ログアウト処理を行わない
- 将来のAuth導入に備えた「器」だけを作る

この工程で扱うのは、静的なマイページ入口だけです。認証、DB、RPC、投稿、編集、GM操作はまだ扱いません。

## 2. 現在のページ構造前提

既存HTMLは、基本的に以下の構造です。

```html
<body data-page="...">
  <div id="site-header"></div>
  <main id="app" class="site-main"></main>
  <div id="site-footer"></div>
  <script type="module" src="assets/js/main.js?..."></script>
</body>
```

`assets/js/main.js` は以下を行います。

- `data/site.json` を読む
- 共通ヘッダーを描画する
- 共通フッターを描画する
- `document.body.dataset.page` に対応する renderer を呼ぶ

注意:

```text
現在の main.js は renderers[page] を必ず呼ぶため、mypage.html を既存構造に乗せるなら data-page="mypage" に対応する renderer 登録が必要。
```

つまりA-3ではAuth用JSは不要ですが、既存サイト構造に合わせるための静的本文 renderer は必要になる可能性があります。

## 3. mypage.html 最小版の表示内容案

候補:

```text
ページタイトル: マイページ
準備中メッセージ
ログイン機能は今後対応
参加申請一覧は今後対応
トップまたはセッション一覧への戻り導線
```

推奨する最小構成:

```text
マイページ
現在準備中です。
今後、ログイン状態・参加申請中のセッション・参加予定セッションを確認できるようにする予定です。
トップへ戻る
```

補助リンク候補:

- `index.html`: トップへ戻る
- `calendar.html`: セッション一覧へ戻る

この段階では、ログインフォーム、ログアウトボタン、表示名、申請一覧は置きません。

## 4. レイアウト方針

既存ページと合わせるため、以下を基本にします。

- 既存共通ヘッダーを使う
- 既存共通フッターを使う
- `site-main`, `page-title`, `section`, `article-box`, `button` 系の既存クラスを活用する
- 新規CSSを増やしすぎない
- スマホ表示で崩れない
- 本文は1カラムの短い案内に留める

推奨レイアウト:

```text
page-title:
  eyebrow: Account
  h1: マイページ
  lead: アカウント機能は準備中です。

section:
  article-box:
    現在準備中です。
    今後、ログイン状態・参加申請中のセッション・参加予定セッションを確認できるようにする予定です。
    トップへ戻る / CALENDARへ戻る
```

既存CSSで足りる場合は、A-3ではCSS追加を行わない方針を優先します。

## 5. 実装対象ファイル案

A-3実装時に追加・変更する可能性があるファイル:

```text
mypage.html
assets/js/renderMypage.js
assets/js/main.js
README.md
docs/task-backlog.md
docs/supabase-mypage-minimal-implementation-plan.md
```

必要ならCSS追加候補:

```text
assets/css/style.css
```

ただし、最小版では既存CSS流用を推奨します。

JS方針:

```text
Auth / Supabase用JSは追加しない。
既存 main.js の renderer 方式に合わせるため、静的本文を描画する renderMypage.js だけを追加する可能性が高い。
```

扱わないJS処理:

- Supabase接続
- Auth判定
- ログイン / ログアウト
- localStorage操作
- sessionStorage操作
- Cookie操作

## 6. A-2静的アカウントアイコンとの関係

`mypage.html` 最小版を先に用意することで、A-2静的アカウントアイコンのリンク先404を避けられます。

関係整理:

- A-3で `mypage.html` 最小版を作る
- その後A-2静的アイコン実装時に `href="mypage.html"` を安全に設定できる
- Auth実装前でも「マイページ準備中ページ」として成立する
- 将来A-4以降でAuth復元やログイン / ログアウトを段階追加できる

推奨順:

```text
1. A-3 mypage.html最小版
2. A-2 共通ヘッダー静的アカウントアイコン
3. A-4 接続設定未構成時フォールバック
4. A-5 Authセッション復元表示
```

既存の段階表では `mypage.html` 最小版が後続候補として整理されていましたが、404回避を優先し、この計画ではA-3として前倒しします。

## 7. Supabase未接続時の扱い

A-3ではSupabaseに接続しません。

画面上の扱い:

```text
アカウント機能は準備中です。
ログイン機能は今後対応予定です。
参加申請一覧は今後対応予定です。
```

表示しないもの:

- ログイン中 / 未ログイン判定
- display_name
- email
- user_id
- token
- Supabase Project URL
- anon key / publishable key
- service_role
- secret key

A-3は静的ページとして成立させ、接続設定が未構成でもエラーにならない状態を目指します。

## 8. 将来拡張案

将来、マイページに追加する候補:

- ログイン状態表示
- ログインフォーム
- ログアウトボタン
- `display_name` 表示
- 自分の参加申請一覧
- 参加確定セッション一覧
- 待機中セッション一覧
- 自分のコメント履歴

将来追加時の注意:

- 申請一覧表示には、本人だけが読める安全なRPC / viewが必要になる可能性がある
- emailや内部IDは原則表示しない
- Supabase接続情報の実値はdocs / README / チャットに記録しない
- AuthやDBを扱う工程はA-3とは分ける

## 9. ロールバック方針

A-3実装後に問題が出た場合の戻し方:

1. `mypage.html` を削除する
2. `assets/js/renderMypage.js` を追加していた場合は削除する
3. `assets/js/main.js` の `mypage` renderer登録を戻す
4. README / backlog のA-3実装済み記述を戻す
5. A-2静的アイコン実装前なら、他ページへの影響はない

A-3ではSupabaseへ接続しないため、Supabase側ロールバックは不要です。

## 10. A-3で扱わないもの

A-3では以下を扱いません。

- Supabase接続
- Authセッション復元
- ログインフォーム
- ログアウト処理
- 自分の申請一覧表示
- `session-detail.html` 投稿統合
- コメント編集・削除統合
- GM承認・却下統合
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- 追加SQL実行

## 11. 実装前チェックリスト

A-3実装前に確認すること:

- `mypage.html` のtitle / description / OGP方針を決める
- `data-page="mypage"` を使うか確認する
- `renderMypage.js` を追加するか確認する
- `main.js` へ `mypage` renderer登録を入れるか確認する
- 既存CSSだけでスマホ表示が崩れないか確認する
- `mypage.html` にはSupabase接続コードを入れない
- ログイン / ログアウト処理を入れない
- `.env.local` やProject URL / anon key実値を入れない

## 12. 次工程候補

1. この計画書のcommit / push
2. A-3 `mypage.html` 最小版実装判断
3. A-3実装時の `renderMypage.js` 要否確認
4. A-2静的アカウントアイコン実装
5. A-4接続設定未構成時フォールバック計画

## 13. A-3最小版実装メモ

A-3最小版として、`mypage.html` と `assets/js/renderMypage.js` を静的な準備中ページとして追加した。

実装内容:

- `mypage.html` は既存ページと同じ `#site-header` / `#app.site-main` / `#site-footer` 構造を使う
- `assets/js/main.js` に `mypage` rendererを登録する
- `renderMypage.js` は静的な案内文と `index.html` / `calendar.html` への戻り導線だけを描画する
- 既存CSSを流用し、新規CSSは追加しない

これにより、次工程A-2静的アカウントアイコン実装時に `href="mypage.html"` を安全に設定できる。

未実装のまま維持するもの:

- Supabase接続
- Authセッション復元
- ログインフォーム
- ログアウト処理
- 自分の申請一覧表示
- コメント投稿・編集・削除
- GM承認・却下
- `close_session`
