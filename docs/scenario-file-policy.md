# ヴェルガルド公開サイト シナリオファイル受け入れ方針

この文書は、ユーザーが作成した配布シナリオ本文、PDF、関連ファイルをサイトへ反映するための制作管理用ポリシーです。利用者向け更新履歴ではなく、受け入れ時の判断基準として扱います。

## 1. 基本方針

- 初期の正本ファイルは `.txt` とする。
- `.txt` はユーザーが作成・提供したシナリオ本文の原本として扱う。
- PDF は任意の整形版として追加できる。
- HTML本文表示は将来対応とする。
- ユーザーが `.txt` のみ提供した場合は、まず `.txt` 配布として反映できるようにする。
- ユーザーがPDFも提供した場合は、PDF配布ボタンも追加できるようにする。
- `textUrl` をTXT本文用の正規フィールドとし、`txtUrl` は使わない。
- `pdfUrl` をPDF用フィールドとする。
- TXTはUTF-8で統一する。
- 必要に応じて、将来 `.txt` からPDF化する工程を別途検討する。
- PDF化を行う場合も、元の `.txt` を正本として残す。

## 2. 表示方針

`scenario-detail.html` は、将来的に配布状態に応じて表示を切り替える。

### releaseStatus: preparing

- 現在の準備中表示。
- 代表画像。
- `summary`。
- 関連スポット。
- 関連NPC。

### releaseStatus: released

- 配布中バッジ。
- 推奨レベル。
- 所要時間。
- プレイヤー人数。
- TXTダウンロードボタン。
- PDFがある場合のみPDFダウンロードボタン。
- TXT本文をページ内表示する場合は `fetch(textUrl)` で読み込み、`textContent` で表示する。
- TXT本文表示に `innerHTML` は使わない。
- バージョン。
- 最終更新日。
- 関連スポット。
- 関連NPC。

### releaseStatus: archived

- 旧版または配布停止表示。
- 注意書き。
- 必要なら旧版ファイルへのリンク。

## 3. scenarios.json 追加候補フィールド

既存の `status: public` は表示可否に使われている可能性があるため、配布状態には別フィールドを使う。

### 最初に必要

- `releaseStatus`: `preparing` / `released` / `archived`
- `textUrl`
- `pdfUrl`
- `releaseDate`
- `recommendedLevel`
- `estimatedPlayTime`
- `playerCount`
- `version`
- `lastUpdated`

### 将来でよい

- `htmlBodyPath`
- `tags`
- `notes`
- `fileSizeText`
- `fileSizePdf`
- `downloadUrl`

## 4. 配置先方針

配布ファイルの配置先は、以下を推奨する。

```text
assets/scenarios/<scenario-id>/
```

例:

```text
assets/scenarios/railway-incidents/railway-incidents_v1.0.txt
assets/scenarios/railway-incidents/railway-incidents_v1.0.pdf
assets/scenarios/grayname-records/grayname-records_v1.0.txt
assets/scenarios/grayname-records/grayname-records_v1.0.pdf
```

- ファイル名は英数字、小文字、kebab-case とする。
- 日本語ファイル名は避ける。
- `scenario-id` を基準にする。
- バージョン番号を入れる。
- TXTを正本として残す。
- PDFは任意とする。
- HTML本文化する場合は、将来 `index.html` または `body.html` のような置き方を別途設計する。

## 5. 実装工程案

1. ユーザーから `.txt` / PDF / 関連ファイルを受領する。
2. 公開可否と秘匿情報混入を確認する。
3. ファイル名と配置先を決定する。
4. `assets/scenarios/<scenario-id>/` に配置する。
5. `scenarios.json` に `releaseStatus` / `textUrl` / `pdfUrl` 等を追加する。
6. `renderScenarioDetail.js` を配布中表示へ対応する。
7. `renderScenarios.js` の一覧カードに配布中バッジ等を追加する。
8. TXT / PDF ダウンロードリンクを確認する。
9. 関連導線を確認する。
10. README / QA / task-backlog / updates を反映する。
11. バックアップを作成する。

## 6. シナリオ本文に関する禁止事項

- Codex / ChatGPT は、ユーザーの依頼なしに配布シナリオ本文を自動作成しない。
- ユーザー提供前に、仮本文を勝手に作らない。
- GM秘匿情報や敵データを、公開確認なしにHTML本文へ出さない。
- `.txt` 受領時も、秘匿情報混入チェックを行う。
- PDF化する場合も、元TXTと内容差分がないか確認する。
