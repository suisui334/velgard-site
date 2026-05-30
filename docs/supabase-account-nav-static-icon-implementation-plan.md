# Supabase A-2 共通ヘッダー静的アカウントアイコン実装計画書

## 1. 目的

この計画書は、共通ヘッダーに静的なアカウントアイコンを追加する前に、対象ファイル、配置、レスポンシブ挙動、リンク先、ロールバック方針を整理するためのものです。

A-2の目的:

- 共通ヘッダーに静的なアカウントアイコンを追加する
- この段階ではSupabaseへ接続しない
- Authセッション復元やログイン状態判定を行わない
- ログイン / ログアウト処理を行わない
- クリック先は将来の `mypage.html` を想定する
- 既存ページ表示、グローバルナビ、スマホメニューを壊さない

この工程で扱うのは、見た目と導線の入口だけです。認証、DB、RPC、投稿、編集、GM操作はまだ扱いません。

## 2. 現在の共通ヘッダー構造

主要HTMLは、共通して以下の構造を持っています。

```html
<div id="site-header"></div>
<script type="module" src="assets/js/main.js?..."></script>
```

`assets/js/main.js` の `renderHeader(site, page)` が `#site-header` に以下を描画します。

- `<header class="site-header">`
- `.header-inner`
- `.brand`
- `.nav-toggle`
- `.global-nav`

PC表示では `.global-nav` が右側に並びます。900px以下では `.nav-toggle` が表示され、`.global-nav.is-open` がドロップダウン表示になります。640px以下ではヘッダー幅やブランド表示がさらに詰まります。

## 3. 対象ページ整理

現行の主要HTMLはすべて `#site-header` と `assets/js/main.js` を使っています。

対象ページ候補:

```text
index.html
world.html
campaigns.html
campaign-detail.html
episode-detail.html
regulation.html
spots.html
spot-detail.html
characters.html
scenarios.html
hooks.html
scenario-detail.html
terms.html
gallery.html
tools.html
calendar.html
session-detail.html
updates.html
```

推奨:

```text
共通ヘッダーの整合性を優先し、実装時は assets/js/main.js の renderHeader 側で主要ページ一括反映する。
```

理由:

- すべての主要HTMLが同じ `#site-header` / `main.js` 構成を使っている
- 個別HTMLに断片を足すより差分が小さい
- ナビゲーションの見た目をページごとにずらさずに済む
- ロールバック時も `main.js` とCSS差分を戻せばよい

段階導入案:

- 実装リスクを下げる場合は、まず `main.js` にDOM生成だけ追加し、CSSで非表示または控えめ表示にする
- ただしページ単位で出し分けるより、共通ヘッダーとして一括で扱う方が長期的には単純

## 4. 配置案

配置候補:

| 候補 | PC | スマホ | 評価 |
| --- | --- | --- | --- |
| ナビ末尾 | `CALENDAR` の後ろ | モバイルメニュー内の末尾 | 実装が単純。ただしスマホでは常時見えない |
| ナビ右端の独立アイコン | `.global-nav` の右側 | ハンバーガー横 | 導線として自然。ただしレイアウト調整が必要 |
| ブランド横 | ブランド付近 | ブランド付近 | ブランドと競合しやすい |

推奨案:

```text
A-2ではナビ末尾に静的な「マイページ」アイコンリンクを追加する。
```

理由:

- 既存の `navItems` / `.global-nav a` の仕組みに寄せられる
- CSS変更が小さく、既存ヘッダーを壊しにくい
- スマホではモバイルメニュー内の末尾に入り、押し間違いが少ない
- A-2は静的導線だけなので、常時右上アイコン化はA-3以降で改めて調整できる

補足:

- UX最終形としては、PC右端 / スマホのハンバーガー付近に独立したアイコンを置く余地を残す
- A-2ではまず「全ページ共通で入口がある」ことを優先する

## 5. 表示案

A-2は静的表示のみです。ログイン済み / 未ログインの出し分けはしません。

候補:

| 表示 | 内容 | 評価 |
| --- | --- | --- |
| 丸い人型アイコン | 人型または丸アイコンのみ | 省スペースだが意味が伝わりにくい可能性 |
| 小さな紋章風アイコン | 世界観に寄せた記号 | 雰囲気は良いが機能説明が弱い |
| `ACCOUNT` テキスト | 既存英字ナビに合わせる | 既存ナビと整合しやすい |
| アイコン + 視覚非表示ラベル | 画面は小さく、支援技術には説明を渡す | アクセシビリティに強い |

推奨案:

```text
PC / スマホとも、初期は既存ナビに馴染む `ACCOUNT` または短いアイコン+ラベルを使う。
```

実装時の候補:

```html
<a class="account-nav__link" href="mypage.html" aria-label="マイページ">
  <span class="account-nav__icon" aria-hidden="true">○</span>
  <span class="account-nav__label">ACCOUNT</span>
</a>
```

アクセシビリティ方針:

- `aria-label="マイページ"` を付ける
- `title` は任意だが、付ける場合も短くする
- キーボードフォーカス時に既存ナビと同等のフォーカス表示を出す
- タップ領域は既存 `.global-nav a` と同程度以上を確保する

## 6. リンク先方針

将来のリンク先は以下を想定します。

```text
href="mypage.html"
```

ただし、A-2では `mypage.html` を作成しません。

候補:

| 案 | 内容 | 評価 |
| --- | --- | --- |
| A案 | アイコンだけ先に置き、リンクは無効にする | 404を避けられるが導線として意味が弱い |
| B案 | `mypage.html` 最小版と同時に入れるまで保留 | ユーザー体験は安全だが、A-2の目的が薄くなる |
| C案 | `href="mypage.html"` を置き、同時に最小版作成を次工程条件にする | 実装は自然だが、A-2単独では404リスクがある |

推奨案:

```text
A-2単独実装ではリンクを有効化しない。静的アイコンを配置する場合は、`aria-disabled` 相当の扱いか、クリック時の遷移なしに留める。
A-3またはA-5で `mypage.html` 最小版と合わせて `href="mypage.html"` を有効化する。
```

理由:

- 未作成ページへのリンクで404を出さない
- A-2の範囲を「静的ヘッダー表示」に限定できる
- マイページ最小版の設計を待ってから安全に導線を開ける

代替:

- `href="mypage.html"` を入れる場合は、同じcommitで `mypage.html` 最小版を作る工程に変更する
- その場合はA-2ではなくA-2/A-5混合工程として扱う

## 7. CSS方針

必要になりそうなクラス:

```text
account-nav
account-nav__link
account-nav__icon
account-nav__label
```

PC方針:

- 既存 `.global-nav a` のサイズ、色、hoverに寄せる
- ナビ末尾に入れる場合は追加CSSを最小にする
- 独立アイコン化する場合は `.header-inner` 内でブランド、ナビ、アカウント導線の3要素を扱う

スマホ方針:

- A-2ではモバイルメニュー内の末尾に入る想定
- 独立右上アイコン化する場合は `.nav-toggle` との間隔、42px前後のタップ領域、折り返しを要確認
- 640px以下ではブランド幅が詰まるため、テキストを短くするかアイコン中心にする

状態:

- hover / focus-visible は既存 `.global-nav a:hover` / `.global-nav a.is-active` と揃える
- A-2ではログイン済み状態、未ログイン状態、現在ページ状態は作らない
- `mypage.html` 作成後に現在ページ表示を検討する

干渉確認:

- PCでナビが折り返しすぎないか
- 900px以下でドロップダウンが崩れないか
- 640px以下でブランド、ハンバーガー、アカウント導線が重ならないか

## 8. JS方針

A-2ではJS追加を基本的に行いません。

扱わないもの:

```text
Supabase接続
Auth判定
ログイン状態表示
ログイン / ログアウト
localStorage操作
sessionStorage操作
Cookie操作
```

実装時に触る可能性があるJS:

```text
assets/js/main.js
```

ただし、これは共通ヘッダーの静的DOMを増やすためだけに使います。AuthやSupabase clientは読み込みません。

将来A-4以降の候補:

```text
assets/js/accountNav.js
assets/js/supabaseAuthClient.js
```

これらはA-2では作成しません。Auth復元やマイページ表示が必要になった段階で分離して追加します。

## 9. 実装時の対象ファイル案

A-2実装時に変更する可能性があるファイル:

```text
assets/js/main.js
assets/css/style.css
README.md
docs/task-backlog.md
docs/supabase-account-nav-static-icon-implementation-plan.md
```

変更しない方針のファイル:

```text
index.html
world.html
campaigns.html
campaign-detail.html
episode-detail.html
regulation.html
spots.html
spot-detail.html
characters.html
scenarios.html
hooks.html
scenario-detail.html
terms.html
gallery.html
tools.html
calendar.html
session-detail.html
updates.html
data/sessions.json
updates.json
```

理由:

- 共通ヘッダーは `main.js` から描画されるため、個別HTMLを編集する必要がない
- 静的アイコンの見た目は既存CSSへ最小追加するだけでよい

## 10. ロールバック方針

A-2実装後に問題が出た場合は、以下の順で戻します。

1. `assets/js/main.js` からアカウントアイコンDOM生成を削除する
2. `assets/css/style.css` から `account-nav*` 関連CSSを削除する
3. `mypage.html` への仮リンクまたは無効リンクを削除する
4. README / backlogのA-2実装済み記述を戻す

A-2はDB状態やAuth状態を変更しないため、Supabase側のロールバックは不要です。

## 11. A-2で扱わないもの

A-2では以下を扱いません。

- Supabase接続
- Authセッション復元
- ログインフォーム
- ログアウト
- `mypage.html` 実装
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

## 12. 実装前チェックリスト

A-2実装前に確認すること:

- `docs/supabase-account-nav-mypage-ux-plan.md` の方針に沿っている
- `mypage.html` 未作成時のリンク扱いを決める
- PC / 900px以下 / 640px以下のヘッダー表示確認を行う
- 既存ナビのactive表示を壊さない
- HTML個別編集ではなく共通ヘッダー側の変更に留める
- Supabase Project URL / anon key / publishable key 実値を入れない
- Auth / DB / RPCに触れない

## 13. 次工程候補

1. この計画書のcommit / push
2. A-2静的アカウントアイコン実装判断
3. A-2実装時のリンク有効化方針最終確認
4. `mypage.html` 最小版設計
5. A-3接続設定未構成時フォールバック計画

## 14. mypage.html最小版計画との関係

`mypage.html` 最小版の詳細は `docs/supabase-mypage-minimal-implementation-plan.md` に分離する。

静的アカウントアイコンに `href="mypage.html"` を設定する前に、準備中ページとして成立する `mypage.html` を用意することで、リンク先404を避けられる。A-2実装時にリンクを有効化するかどうかは、A-3最小版の実装状況を見て判断する。

## 15. A-2静的導線実装メモ

A-3で `mypage.html` 最小版が追加済みになったため、A-2では共通ヘッダーのナビ末尾に静的な `ACCOUNT` 導線を追加した。

実装内容:

- `assets/js/main.js` の `renderHeader` で、`mypage.html` への `account-nav__link` を共通ヘッダーに追加する
- 表示はCALENDAR右側に同一行で収まりやすい、控えめな `ACCOUNT` テキスト導線にする
- `aria-label="マイページへ移動"` と `title="マイページ"` を付ける
- `mypage` 表示時の強いactive表示は付けない
- `assets/css/style.css` に `account-nav__link` の最小CSSを追加し、ACCOUNTだけが下段に落ちないように調整する
- 共通ヘッダー変更を各ページで確実に反映するため、既存HTMLの構造は変えず `assets/js/main.js` / `assets/css/style.css` のcache-bust queryのみ更新する

未実装のまま維持するもの:

- Supabase接続
- Authセッション復元
- ログインフォーム
- ログアウト処理
- `display_name` 表示
- 自分の申請一覧表示
- コメント投稿・編集・削除
- GM承認・却下
- `close_session`
