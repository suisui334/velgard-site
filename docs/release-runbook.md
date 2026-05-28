# ヴェルガルド公開サイト release-runbook

この文書は、正式公開URLが決定した後に行う公開前確認、URL差し替え、公開後確認を整理する制作管理用手順書です。現時点では正式公開URLが未定のため、`publicUrl` / `og:url` / `og:image` の本差し替えは行いません。

## 1. 公開前提

- 正式公開URLが決定してから実施する。
- 現時点ではURL未定のため、実差し替えは行わない。
- 身内向け公開を想定する。
- Discord共有を想定する。
- Twitter / Xカード系metaは不要方針とする。
- シナリオ本文はユーザー提供ファイル待ちであり、Codex / ChatGPT が勝手に本文を作成しない。

## 2. 正式公開URL決定後に差し替えるもの

- `data/site.json` の `publicUrl`。
- 各HTMLの `og:url`。
- 各HTMLの `og:image`。
- canonical系URLがある場合はそのURL。
- README / QA / backlog 内の公開URL記述。
- `example.com` の残存。
- 相対パスのままにするものと絶対URLへ置き換えるものの切り分け。

## 3. OGP / favicon画像方針

- 現在HTML参照用のOGP画像は軽量版 `assets/images/common/ogp-main-1200x630.png`。
- `data/site.json` の `meta.ogImage` / `meta.favicon` も軽量版参照へ整合済み。
- 元画像 `assets/images/common/ogp-main.png` は原本として維持する。
- 正式公開後は `og:image` を正式公開URLから始まる絶対URLにする。
- Discord等でOGP画像、タイトル、descriptionが正しく表示されるか確認する。
- favicon軽量版 `assets/images/common/favicon-32.png` / `assets/images/common/favicon-192.png` はHTMLへ反映済み。
- 元画像 `assets/images/common/favicon.png` は原本として維持する。
- `assets/images/common/apple-touch-icon.png` はHTMLへ反映済み。
- Twitter / Xカード系metaは現方針では追加不要。
- 必要になった場合のみ、別工程でTwitter / Xカード系metaを検討する。

## 4. 公開前最終チェック

- `data/*.json` parse。
- `assets/js/*.js` syntax。
- 全HTML HTTP 200。
- 画像参照欠損なし。
- 禁止旧表記・旧IDなし。
- `undefined` / `null` / `[]` の画面露出なし。
- トップページナビと共通ナビの導線確認。
- `scenarios.html` が正式入口として表示される。
- `hooks.html` が互換入口として表示される。
- galleryカテゴリ確認。
- regulation表確認。
- world目次確認。
- 各種モーダル確認。
- PC実ブラウザ確認。
- DevToolsレスポンシブ確認。
- スマホ実機確認は公開後または外部確認URL発行後に行う。

## 5. 公開後確認

- 公開URLへアクセスできる。
- トップページが表示される。
- OGPがDiscord等で表示される。
- スマホ実機で主要ページを確認する。
- スマホ実機でモーダルを確認する。
- 404が出ていない。
- 主要画像が表示される。
- 表示が古い場合は `Ctrl + F5` 等のキャッシュ更新を案内する。

## 6. 公開後にまだ残すもの

- `hooks.html` は互換入口として当面維持する。
- `data/hooks.json` は互換・比較用として当面維持する。
- `gallery-hook-*` ID は当面維持する。
- `assets/images/hooks/` は当面維持する。
- `characters.json` の `relatedHooks` は別スキーマとして当面維持する。
- シナリオ本文はユーザー提供後に反映する。

## 7. やらないこと

- 正式公開URL未定のまま `publicUrl` / `og:url` を本差し替えしない。
- シナリオ本文を勝手に作らない。
- `hooks.html` / `data/hooks.json` を今すぐ削除しない。
- `gallery-hook-*` IDや `assets/images/hooks/` を今すぐ改名・移動しない。
- Twitter / Xカード系metaを必要性なしに追加しない。
