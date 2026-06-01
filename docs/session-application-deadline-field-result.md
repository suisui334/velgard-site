# M-13B 申請締切日時フィールド 実装結果

## 概要

`data/sessions.json` の各セッションに参加申請締切を示す `applicationDeadline` を追加し、`session-detail.html` と `calendar.html` の選択日セッション一覧で表示するようにした。

## 追加内容

既存7件は、明示締切が別途ないため、開催日前日の `23:59` で統一した。

## 表示

- `session-detail.html`: 基本情報に「申請締切」を追加。
- `calendar.html`: 選択日セッションカードのメタ情報に「申請締切」を追加。

`startTime` / `endTime` は開催時刻として扱い、申請締切には流用していない。未設定時は `未定` と表示する。

M-13B内の追加調整として、`session-detail.html` の基本情報からGM固定表示を削除した。`data/sessions.json` のGM情報とcalendar側のGM表示は維持する。

## 非実施

- SQL Editor実行なし。
- DB変更なし。
- `updates.json` 変更なし。
- pushなし。
- secret / key / token / email / user_id全文の記録なし。
