# Supabase F-2 公開セッション読み取りプロトタイプ設計

## 1. 目的

F-2では、Supabase `sessions` を公開セッションの読み取り元として扱えるかを、まだ本番ページへ接続せずに検証する。

目的は以下。

- Supabase `sessions` と既存 `data/sessions.json` の表示用データ差分を把握する
- Supabaseのsnake_case列を、既存 `sessionDisplay.js` が想定するcamelCaseオブジェクトへ変換する
- `sessionDisplay.js` の表示関数をdevプロトタイプで再利用できるか確認する
- public sessionのみを対象にし、private / hiddenを表示しない
- 投稿処理、Auth処理、GM操作、本番ページ統合はまだ扱わない

F-2の実装先は本番 `calendar.html` / `session-detail.html` ではなく、`dev/` 配下のローカル検証ページとする。

## 2. 既存 data/sessions.json の構造

`data/sessions.json` はトップレベルに以下を持つ。

| フィールド | 内容 |
| --- | --- |
| `schemaVersion` | 静的JSONスキーマのバージョン |
| `updatedAt` | 静的JSON全体の更新日 |
| `sessions` | セッション配列 |

各セッションで確認できる主要フィールドは以下。

| フィールド | 現行表示での扱い |
| --- | --- |
| `id` | URL、詳細ページ、カレンダー導線のキー |
| `title` | タイトル。`closed` の場合は表示側で `〆` を付ける |
| `date` | 開催日 |
| `startTime` | 開始時刻 |
| `endTime` | 終了時刻 |
| `gmName` | 表示用GM名 |
| `gmUserId` | 将来の権限・同期用。PL向け表示には出さない |
| `status` | `recruiting` / `tentative` / `full` / `closed` / `finished` / `canceled` など |
| `levelRange` | レベル帯 |
| `playerMin` | 最低人数 |
| `playerMax` | 最大人数 |
| `playerCount` | 静的な現在人数表示 |
| `summary` | 概要 |
| `detail` | 詳細本文。存在する場合のみ表示 |
| `requirements` | 参加条件。存在する場合のみ表示 |
| `scenarioId` | 管理・関連付け用。PL向け詳細では非表示 |
| `relatedSpotIds` | 管理・関連付け用。PL向け詳細では非表示 |
| `discordThreadUrl` | 将来同期用。PL向けUIには出さない |
| `tags` | 予定カード・詳細で表示 |
| `visibility` | 公開範囲。PL向け詳細では非表示 |
| `createdAt` | 作成日時。現行UIでは主表示しない |
| `updatedAt` | 更新日時。日付のみ / 日付時刻に対応 |

## 3. Supabase sessions の構造

SQL草案上の `public.sessions` 主要列は以下。

| フィールド | 内容 |
| --- | --- |
| `id` | text primary key。現行URL互換のため既存session idと合わせる想定 |
| `title` | タイトル |
| `date` | 開催日 |
| `start_time` | 開始時刻 |
| `end_time` | 終了時刻 |
| `gm_user_id` | Supabase Auth / profiles に紐づくGMユーザーID |
| `gm_name` | 表示用GM名 |
| `status` | 募集状態。`closed` が〆状態の正本 |
| `level_range` | レベル帯 |
| `player_min` | 最低人数 |
| `player_max` | 最大人数 |
| `summary` | 概要 |
| `detail` | 詳細本文 |
| `requirements` | 参加条件 |
| `visibility` | `public` / `private` / `hidden` |
| `created_at` | 作成日時 |
| `updated_at` | 更新日時 |

現行SQL草案では、`tags`、`player_count`、`scenario_id`、`related_spot_ids`、`discord_thread_url` は `sessions` テーブルに含めていない。

## 4. マッピング表

| 表示用sessionDisplay想定フィールド | data/sessions.json側 | Supabase sessions側 | 変換の必要性 | 備考 |
| --- | --- | --- | --- | --- |
| `id` | `id` | `id` | なし | 既存URLと合わせるためtext id維持 |
| `title` | `title` | `title` | なし | 空文字は不可に寄せる |
| `date` | `date` | `date` | ほぼなし | `YYYY-MM-DD` 文字列として扱う |
| `startTime` | `startTime` | `start_time` | 必要 | `21:00:00` なら `21:00` に整形 |
| `endTime` | `endTime` | `end_time` | 必要 | `24:00` はPostgres `time` と相性注意。実DB値は要確認 |
| `gmName` | `gmName` | `gm_name` | 必要 | 未設定時は表示側で「未設定」扱い |
| `gmUserId` | `gmUserId` | `gm_user_id` | 必要 | PL向け表示には出さない。Supabase側はUUID想定 |
| `status` | `status` | `status` | なし | `full` は満席、`closed` は〆、`finished` / `canceled` は申請不可 |
| `levelRange` | `levelRange` | `level_range` | 必要 | 表示用文字列として渡す |
| `playerMin` | `playerMin` | `player_min` | 必要 | 数値として渡す |
| `playerMax` | `playerMax` | `player_max` | 必要 | 数値として渡す |
| `playerCount` | `playerCount` | なし | 必要 | `get_public_session_application_counts` の `accepted_count` などから補完候補 |
| `summary` | `summary` | `summary` | なし | HTMLとして解釈せずエスケープ表示 |
| `detail` | `detail` | `detail` | なし | NULLなら空扱い |
| `requirements` | `requirements` | `requirements` | なし | NULLなら空扱い |
| `tags` | `tags` | なし | 必要 | F-2では `[]` にする。将来 `session_tags` / JSONB / text[] を検討 |
| `visibility` | `visibility` | `visibility` | なし | publicのみ読み取り対象 |
| `createdAt` | `createdAt` | `created_at` | 必要 | 現行表示では主に使わない |
| `updatedAt` | `updatedAt` | `updated_at` | 必要 | `formatSessionUpdatedAt()` がISO風日時に対応済み |
| `scenarioId` | `scenarioId` | なし | 必要 | PL向け詳細では非表示。F-2では扱わない |
| `relatedSpotIds` | `relatedSpotIds` | なし | 必要 | PL向け詳細では非表示。F-2では扱わない |
| `discordThreadUrl` | `discordThreadUrl` | なし | 必要 | PL向けUIには出さない。将来 `discord_links` 側へ分離候補 |

## 5. 変換関数案

F-2 devプロトタイプでは、Supabase行を直接 `sessionDisplay.js` に渡さず、表示用オブジェクトへ変換する。

```js
function mapSupabaseSessionToDisplaySession(row, countsBySessionId = new Map()) {
  const counts = countsBySessionId.get(row.id) || {};
  return {
    id: row.id,
    title: row.title,
    date: row.date,
    startTime: formatTimeForDisplay(row.start_time),
    endTime: formatTimeForDisplay(row.end_time),
    gmName: row.gm_name,
    gmUserId: row.gm_user_id,
    status: row.status,
    levelRange: row.level_range,
    playerMin: row.player_min,
    playerMax: row.player_max,
    playerCount: Number(counts.accepted_count || 0),
    summary: row.summary,
    detail: row.detail,
    requirements: row.requirements,
    tags: [],
    visibility: row.visibility,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}
```

時刻整形案:

```js
function formatTimeForDisplay(value) {
  const text = String(value || "").trim();
  const matched = text.match(/^(\d{2}):(\d{2})/);
  return matched ? `${matched[1]}:${matched[2]}` : text;
}
```

## 6. マッピング上の注意点

### playerCount

現行 `data/sessions.json` は `playerCount` を保存値として持つ。一方、Supabaseでは参加人数は `session_applications` の一意ユーザー単位で算出する。

F-2では以下の扱いを推奨する。

- `accepted_count` を `playerCount` として表示する
- `pending_count` / `waitlisted_count` は補助表示として別扱いにする
- コメント件数を人数として使わない

### tags

Supabase `sessions` には `tags` がない。

F-2ではまず `tags: []` として表示互換性を確認する。必要になった段階で以下を検討する。

- `session_tags` テーブル
- `sessions.tags text[]`
- `sessions.tags jsonb`

### status

`sessionDisplay.js` は `closed` のタイトルに `〆` を付け、`tentative` / `finished` / `canceled` を控えめ状態表示に使う。`full` は強いバッジとして復活させない方針を維持する。

申請可否としては以下を維持する。

| status | F-2表示 | 申請可否方針 |
| --- | --- | --- |
| `recruiting` | 通常表示 | 将来申請可 |
| `tentative` | 仮予定表示 | 将来申請可候補 |
| `full` | 満席扱い | 新規申請不可 |
| `closed` | `〆` 表示 | 新規申請不可 |
| `finished` | 終了表示 | 新規申請不可 |
| `canceled` | 中止表示 | 新規申請不可 |
| `draft` | 原則publicに出さない | 新規申請不可 |

### Discord関連

現行 `data/sessions.json` のDiscord関連値はPL向けUIには出さない。Supabase移行時も `profiles.discord_user_id` や将来の `discord_links` などの非公開領域へ分離し、公開view / RPC / フロント表示用オブジェクトへ混ぜない。

## 7. devプロトタイプ拡張案

F-2実装では、既存F-1を大きく膨らませるより、以下の新規devページを推奨する。

```text
dev/supabase-session-mapping-prototype.html
dev/supabase-session-mapping-prototype.js
```

理由:

- F-1は「生の読み取り確認」として残せる
- F-2は「既存表示互換マッピング確認」に集中できる
- `sessionDisplay.js` の読み込み・描画確認を分離できる

F-2 devプロトタイプで確認すること:

- Supabase public sessionsを取得する
- private / hiddenが表示されない
- `mapSupabaseSessionToDisplaySession()` でcamelCaseへ変換する
- `renderSessionDetailContent(session, { mode: "page" })` を一部カード表示に流用できるか確認する
- `formatSessionTime()` / `formatPlayerCount()` / `renderSessionTags()` の崩れがないか確認する
- 接続値は手入力で保存しない
- 投稿処理なし
- Authログインなし

## 8. 本番統合前の注意

F-2後も、以下が決まるまでは本番統合しない。

- 既存 `data/sessions.json` はまだ正本のまま維持する
- Supabase `sessions` をいきなり正本にしない
- 本番 `calendar.html` へ接続しない
- 本番 `session-detail.html` へ接続しない
- 本番 `assets/js` にSupabase clientを混ぜない
- service role / secret keyは使わない
- publishable / anon keyだけでも、公開ページに入れる前に設計確認する
- `data/sessions.json` とDBの二重管理問題を解く
- tags、playerCount、Discord関連、関連スポット、シナリオIDの移行方針を決める
- Supabase読み取り失敗時に静的表示へfallbackするか決める

## 9. 推奨結論

現時点の推奨は以下。

1. F-2では新規 `dev/supabase-session-mapping-prototype.*` を作る
2. Supabase `sessions` はpublic readのみを対象にする
3. 読み取った行を既存 `sessionDisplay.js` 用のcamelCaseオブジェクトへ変換する
4. `playerCount` は `accepted_count` 由来で補完する
5. `tags` はF-2では空配列として扱う
6. 本番ページ統合はまだ行わない

F-2の成功条件は、Supabase由来のpublic sessionを、既存静的表示と同等の見た目へ変換できることに限定する。
