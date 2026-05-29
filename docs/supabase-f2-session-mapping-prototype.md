# Supabase F-2 セッション表示マッピングプロトタイプ

## 1. 目的

Supabase `sessions` から読み取った public session を、既存 `sessionDisplay.js` が扱うcamelCaseの表示用オブジェクトへ変換し、dev配下のローカル専用ページで表示互換性を確認する。

この工程では本番ページへ接続しない。投稿処理、Authログイン、追加SQL実行も行わない。

## 2. 作成ファイル

```text
dev/supabase-session-mapping-prototype.html
dev/supabase-session-mapping-prototype.js
docs/supabase-f2-session-mapping-prototype.md
```

必要に応じて以下へ短い参照を追加する。

```text
README.md
docs/task-backlog.md
```

## 3. 本番ページへ接続していないこと

F-2 devプロトタイプは以下を変更しない。

- `session-detail.html`
- `calendar.html`
- 既存本番用 `assets/js`
- `data/sessions.json`
- `updates.json`

`dev/` 配下の検証ページは通常導線に載せない。

## 4. 接続値の扱い

接続値はF-1と同じく手入力する。

入力するもの:

- Supabase URL
- publishable / anon key

禁止するもの:

- service role key
- secret key
- DB password
- Direct connection string
- `postgresql://`
- Discord bot token
- webhook URL

入力値は localStorage、sessionStorage、Cookieへ保存しない。consoleにも出さない。画面上にも全文表示しない。

## 5. 読み取り対象

### public sessions

`public.sessions` から `visibility = 'public'` の行だけを読む。

取得対象:

```text
id
title
date
start_time
end_time
gm_name
status
level_range
player_min
player_max
summary
detail
requirements
visibility
updated_at
```

`gm_user_id` は取得・表示しない。

### application counts

以下のRPCを呼ぶ。

```text
get_public_session_application_counts
```

F-2では `accepted_count` を既存表示用 `playerCount` 相当として扱う。

## 6. マッピング方針

Supabaseのsnake_caseを、既存 `sessionDisplay.js` 向けcamelCaseへ変換する。

| Supabase | 表示用オブジェクト | 備考 |
| --- | --- | --- |
| `id` | `id` | そのまま |
| `title` | `title` | nullは空文字 |
| `date` | `date` | そのまま |
| `start_time` | `startTime` | `21:00:00` を `21:00` に整形 |
| `end_time` | `endTime` | `21:00:00` を `21:00` に整形 |
| `gm_name` | `gmName` | `gm_user_id` は表示しない |
| `status` | `status` | そのまま |
| `level_range` | `levelRange` | そのまま |
| `player_min` | `playerMin` | 数値またはnull |
| `player_max` | `playerMax` | 数値またはnull |
| `accepted_count` | `playerCount` | 参加人数は申請者単位 |
| `summary` | `summary` | nullは空文字 |
| `detail` | `detail` | nullは空文字 |
| `requirements` | `requirements` | nullは空文字 |
| なし | `tags` | F-2では空配列 |
| `visibility` | `visibility` | publicのみ対象 |
| `updated_at` | `updatedAt` | 既存formatterに渡す |

## 7. playerCountの扱い

`playerCount` はSupabase `sessions` の保存値ではなく、`get_public_session_application_counts` の `accepted_count` から補完する。

重要:

- コメント件数を人数として使わない
- `pending_count` / `waitlisted_count` はF-2では表に出す程度に留める
- 将来の本番UIでは accepted / pending / waitlisted の表示方針を別途決める

## 8. tagsの扱い

Supabase `sessions` には現時点で `tags` がない。

F-2では `tags: []` として既存表示関数へ渡す。将来必要になった段階で、`session_tags`、`text[]`、`jsonb` などを比較する。

## 9. Discord関連

F-2の表示用オブジェクトにはDiscord関連フィールドを混ぜない。

- `discordThreadUrl` は作らない
- `discord_user_id` は取得しない
- `gm_user_id` も画面表示しない
- public RPC / view / dev表示に内部IDを出さない方針を維持する

## 10. sessionDisplay.js流用状況

`dev/supabase-session-mapping-prototype.js` は以下をimportして表示プレビューに使う。

```js
import { renderSessionDetailContent } from "../assets/js/sessionDisplay.js";
```

本番用 `sessionDisplay.js` は変更しない。

プレビューでは、変換後の表示用オブジェクトを `renderSessionDetailContent(session, { mode: "modal" })` に渡し、既存詳細表示と互換性があるかを見る。

## 11. 実ブラウザ確認項目

確認URL例:

```text
http://127.0.0.1:4173/dev/supabase-session-mapping-prototype.html
```

確認項目:

- Supabase URL / publishable・anon keyを手入力できる
- 入力値が保存されない
- public sessionsのみ表示される
- private / hidden sessionが表示されない
- raw sessions一覧に `gm_user_id` / `discord_user_id` が出ない
- mapped display sessions一覧がcamelCaseで表示される
- `start_time` / `end_time` が `startTime` / `endTime` に変換される
- `accepted_count` が `playerCount` に反映される
- `tags` が空配列として扱われる
- `sessionDisplay.js` プレビューが表示される
- 投稿処理が発火しない
- Authログイン処理がない
- エラー表示にURL/key全文が出ない

## 12. F-3へ進む条件

F-3へ進む条件:

- F-2 devプロトタイプでpublic sessionsを安定して読める
- private / hiddenが表示されない
- `sessionDisplay.js` プレビューが破綻しない
- `playerCount` 補完方針が妥当
- `tags` 未実装の影響が許容できる
- secret類がファイル・ログ・画面へ出ない
- 本番ページ接続前のfallback方針を設計できる

F-3では、まだ本番統合ではなく、ログイン状態表示や投稿UIプロトタイプへ進むか、読み取り専用の本番統合設計を追加で固める。
