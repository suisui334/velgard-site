# M-14D-14A static session retirement plan

## Purpose

M-14D-14Aとして、`data/sessions.json` 由来の静的セッション予定を棚卸しし、Supabase運用へ移行・退役するための方針を整理する。
今回は計画のみで、`data/sessions.json` の削除や大規模編集、Supabaseへの投入、SQL Editor実行は行わない。

依頼書機能はSupabase上で新規作成、編集保存、公開状態/募集状態保存、admin管理対象、`session-detail.html` からの編集、中止扱い、完全削除まで実装済み。
そのため、静的JSON由来の予定は本番運用の正本ではなく、公開表示・URL互換・回帰確認用の残存データとして扱う。

## Current Static Data Role

`data/sessions.json` は、calendar / session-detail の初期モック、公開予定表示のサンプル、`session-detail.html?id=...` のURL回帰確認、mypageの公開セッションID突合確認に使われてきた。
一方で、静的JSON由来はSupabaseの編集・削除・admin管理対象に入らないため、現在の依頼書運用とは権限・保存・削除導線が分離している。

静的データにはGMサンプル名、DiscordスレッドURL相当フィールド、公開セッションIDが含まれる。
この棚卸しでは公開ID、タイトル、日付、状態だけを記録し、個人ID、URL、token、key、secret類の実値は記録しない。

## Supabase Features Already Available

- 新規依頼書作成
- 既存依頼書編集保存
- 公開状態 / 募集状態保存
- admin管理対象select
- `session-detail.html` から `session-post.html?id=...` への編集導線
- `status = canceled` による中止として残す操作
- `delete_session_post` RPCによる完全削除

## Current Merge And Display Behavior

`assets/js/sessionData.js` の `loadMergedSessions()` は、先に `data/sessions.json` を読み、その後Supabaseの公開行を読み込む。
`mergeSessions(staticSessions, supabaseSessions)` は静的JSONのIDを先に `staticIds` へ入れるため、同じIDがSupabaseにも存在する場合は静的JSON由来が優先され、Supabase由来の同ID行は追加されない。

Supabase由来は `visibility = public` の行だけを取得し、さらに `draft` / `canceled` / `cancelled` を除外する。
calendar側も `visibility = public`、ISO日付、`draft` / `canceled` / `cancelled` 以外の条件で表示する。
session-detail側も `visibility = public`、IDあり、`draft` / `canceled` / `cancelled` 以外の条件で詳細表示する。

重要な注意点として、移行時に同じIDのSupabase行を作っても、静的JSON行が残っている間はSupabase行が表に出ない。
特に静的JSON側に `canceled` 行が残っている同IDへSupabase公開行を投入した場合でも、静的行が先に重複扱いになるため、公開表示が妨げられる可能性がある。

## Inventory

2026-06-03時点の `data/sessions.json` は7件。

| id | title | date | status | 公開予定として必要か | 分類案 |
| --- | --- | --- | --- | --- | --- |
| `session-2026-06-08-railway-incident` | 灰壁線異常調査 | 2026-06-08 | `recruiting` | URL互換・既存QA参照があるため要確認 | Supabase移行候補 / 一時残存 |
| `session-2026-06-08-flower-mist-closed` | 花霧谷採取護衛 | 2026-06-08 | `closed` | 募集終了表示のfixtureとしてのみ必要 | 削除候補 / fixture代替後退役 |
| `session-2026-06-08-market-tentative` | 双角市場オルム小競り合い | 2026-06-08 | `tentative` | 仮予定表示のfixtureとしてのみ必要 | 削除候補またはSupabase移行候補 |
| `session-2026-07-06-ironbridge-finished` | グラシュ鉄橋砦市補給路 | 2026-07-06 | `finished` | 開催終了表示のfixtureとしてのみ必要 | 削除候補 / fixture代替後退役 |
| `session-2026-08-17-mine-canceled` | 煤煙鉱山フェルゼ坑点検 | 2026-08-17 | `canceled` | 現在のcalendar/detailでは表示対象外 | 強い削除候補 |
| `session-2026-09-28-east-watch` | 灰壁東端監視駅の交代番 | 2026-09-28 | `recruiting` | 実運用予定なら必要、モックなら不要 | Supabase移行候補または削除候補 |
| `session-2027-02-01-final-cap` | 中央操車区最終点検 | 2027-02-01 | `full` | 満席表示/高レベル期間fixtureとしてのみ必要 | Supabase移行候補または削除候補 |

## Migration Candidates

最優先の移行候補は `session-2026-06-08-railway-incident`。
このIDは既存docs、mypageの突合確認、session-detail回帰確認で参照されているため、URL互換を保つなら同じIDでSupabaseへ移行し、同時または直後に静的JSON行を退役させる必要がある。

実際の公開予定として残す意思がある場合、`session-2026-09-28-east-watch` と `session-2027-02-01-final-cap` もSupabaseへ移行候補になる。
`session-2026-06-08-market-tentative` は仮予定ステータスを本番運用でも使うなら移行候補だが、単なる表示fixtureなら削除候補へ寄せる。

## Delete Candidates

強い削除候補は `session-2026-08-17-mine-canceled`。
現在の表示条件では `canceled` がcalendar/detailから除外されるため、公開予定としての役割は薄い。

`session-2026-06-08-flower-mist-closed`、`session-2026-07-06-ironbridge-finished`、`session-2026-06-08-market-tentative` は旧モック / 表示fixtureの可能性が高い。
Supabase上に同等の募集終了、開催終了、仮予定fixtureを用意できるなら削除候補。

## Keep Candidates

恒久的に静的JSONとして残す候補は現時点ではない。
ただし、次の確認が終わるまでは一時的に残す。

- `session-2026-06-08-railway-incident`: URL互換、mypage突合、参加希望コメント表示の回帰確認用。
- `session-2026-06-08-flower-mist-closed`: 募集終了表示の回帰確認用。
- `session-2026-06-08-market-tentative`: 仮予定表示の回帰確認用。
- `session-2027-02-01-final-cap`: 満席表示と高レベル期間表示の回帰確認用。

## Checks Before Removal

- 同じIDでSupabaseへ移行する場合、静的JSON行が残るとSupabase行が表示されないことを確認する。
- `session-detail.html?id=<id>` のURL互換を残すか、退役後にNot Foundでよいかを決める。
- mypageの参加申請 / 参加予定リンクが該当IDを参照していないか確認する。
- 参加希望コメント、申請人数、GM履歴、承認/却下UIの既存QA対象になっていないか確認する。
- 募集終了、開催終了、満席、仮予定の表示fixtureをSupabase側で代替できるか確認する。
- DiscordスレッドURL相当フィールドの扱いを決める。値はdocsやチャットへ記録しない。

## Staged Retirement Steps

1. Supabaseへ残す予定を選ぶ。
2. 残す予定は同じ公開セッションIDでSupabaseへ投入する計画を作る。
3. 投入後、静的JSON行をまだ残した状態では同IDのSupabase行が表示されないことを前提に、切替タイミングを決める。
4. 静的JSON行を1件ずつ退役し、calendar / session-detail / mypageリンク / 参加希望コメント表示を確認する。
5. closed / finished / full / tentative の表示fixtureが必要なら、Supabase上のテスト用または運用用依頼書で置き換える。
6. 退役完了後、`data/sessions.json` を空配列にするか、読み込み自体を後続工程で外すかを決める。

## Stop Conditions

- Supabaseへ同ID行が存在しないのに、既存URL互換が必要な静的行を削除しようとしている。
- 参加申請やコメントが既存静的IDに紐づいており、移行先IDが未確定。
- 同じIDの静的JSON行が残ったまま、Supabase行を表示できると誤認している。
- Discord通知・投稿削除同期の扱いが未整理の公開済み予定を完全削除しようとしている。
- 個人ID、URL、token、key、secret類の実値をdocsやconsoleへ出す必要が出た。

## Not Done In M-14D-14A

- `data/sessions.json` の削除
- `data/sessions.json` の大規模編集
- Supabaseへのデータ投入
- SQL Editor実行
- DB構造変更
- RPC作成 / 置換
- GRANT / REVOKE
- Discord実送信
- Edge Function deploy
- `updates.json` 変更
- service_role key利用
- フロントからのDB直UPDATE / DELETE
- commit / push
