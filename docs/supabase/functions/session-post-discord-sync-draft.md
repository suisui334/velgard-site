# M-14B session-post-discord-sync Edge Function草案

## 1. 目的

GM/adminが依頼書を作成・編集・削除/非公開化・再同期するとき、Supabase側の `public.sessions` を正本として更新し、Discord専用投稿先へサーバー側から反映する。

この文書は草案であり、Edge Functionのdeploy、Discord実送信、DB変更、credential値の記録は行わない。

## 2. 基本方針

フロントはSupabase Auth付きでEdge Functionを呼ぶ。Discord投稿先のcredentialはフロントへ渡さず、Edge Function側だけで管理する。

Edge Functionは1つのendpointで `action` を受ける案を第一候補にする。

```text
action = create | update | delete | close | resync
```

操作ごとの責務:

| action | DB側 | Discord側 |
| --- | --- | --- |
| `create` | `create_session_post` 相当で新規保存 | 専用投稿先へ新規投稿 |
| `update` | 既存 `sessions` 行を更新 | 既存Discord投稿を編集、または更新通知を追記 |
| `close` | `status = closed` などへ更新 | 募集終了表示へ編集、または終了通知を追記 |
| `delete` | 物理削除より `visibility = hidden` などを優先 | 削除済み表示へ編集、または必要なら物理削除 |
| `resync` | 既存行を再取得 | Discord投稿失敗・不整合時に再送/再編集 |

初期推奨は、Discord側も即物理削除せず、既存投稿を「募集終了」または「削除済み」へ編集する方式。監査性とリンク切れ回避を優先する。

## 3. 権限

全actionでログイン必須。

- `create`: `gm` または `admin`
- `update`: 対象セッションのGMまたは `admin`
- `close`: 対象セッションのGMまたは `admin`
- `delete`: 対象セッションのGMまたは `admin`
- `resync`: 対象セッションのGMまたは `admin`

GM本人投稿では `gm_user_id` はログインユーザーに固定する。adminによる代理投稿やGM差し替えは、初期実装では保留するのが安全。

## 4. 同期メタデータ

`public.sessions` 拡張案:

| 列 | 用途 |
| --- | --- |
| `discord_sync_status` | `not_requested` / `pending` / `posted` / `failed` / `skipped` |
| `discord_last_action` | `create` / `update` / `delete` / `close` / `resync` |
| `discord_message_id` | 既存投稿編集・削除・再同期に使うDiscord側message ID |
| `discord_channel_id` | 投稿先識別子 |
| `discord_thread_id` | フォーラム/スレッド運用時の識別子 |
| `discord_synced_at` | 最終同期成功日時 |
| `discord_sync_error` | GM/admin向けに短く見せられる失敗概要 |
| `discord_post_url` | 公開してよい場合だけGM/admin向け参照用 |

Discord投稿credential、サーバー側credential値はDBへ保存しない。

将来、履歴や複数投稿先が必要になった場合は `session_discord_posts` / `session_discord_sync_events` のような関連テーブルへ分離する。初期は `sessions` 直列でも運用可能だが、監査履歴を強く求めるなら関連テーブル案を優先する。

## 5. Discord反映方式の比較

### A. 既存メッセージを編集する

利点:

- 詳細ページURLや募集情報が常に最新に近い。
- Discord側の投稿が散らばりにくい。
- `discord_message_id` を活用できる。

懸念:

- 編集履歴がDiscord UI上で十分に読めない場合がある。
- フォーラム/スレッド運用では本文編集APIや権限確認が必要。

初期推奨: 更新時の第一候補。

### B. 変更通知を追記投稿する

利点:

- 変更履歴が追いやすい。
- 既存投稿の編集に失敗しても通知を残しやすい。

懸念:

- 通知が増えるとチャンネルが流れる。
- 最新情報の所在が分散する。

初期推奨: 重要変更時または既存メッセージ編集不可の場合の代替。

### C. 削除時はDiscordメッセージも削除する

利点:

- Discord側から依頼書を消せる。

懸念:

- 監査性が落ちる。
- 参加者が参照していたリンクや文脈が失われる。

初期推奨: 原則非推奨。運用希望が明確な場合だけ選択。

### D. 削除時は「募集終了 / 削除済み」に編集する

利点:

- 監査性が残る。
- 詳細URLや募集終了状態を明示できる。
- 誤操作時にも復旧しやすい。

懸念:

- Discord側に古い依頼書の痕跡は残る。

初期推奨: 削除/非公開/close時の第一候補。

## 6. 失敗時の扱い

初期方針:

- DB保存・更新は成功扱いにする。
- Discord同期失敗は `discord_sync_status = failed` として記録する。
- `discord_last_action` に失敗したactionを残す。
- `discord_sync_error` には短い失敗概要だけを保存する。
- GM/admin画面から `resync` できる余地を残す。

外部APIを含むため、DB保存とDiscord投稿を完全な単一トランザクションとして扱わない。依頼書本文の保存を優先し、Discordは後から復旧可能な同期対象として扱う。

## 7. Discord本文案

Discord本文には公開してよい情報のみを含める。

```text
【依頼書】{title}

種別: {sessionTypeLabel}
開催日: {date}
開催時刻: {startTime}〜{endTime}
申請締切: {applicationDeadline}
レベル帯: {levelRange}
募集人数: {playerMin}〜{playerMax}名

依頼書本文:
{requestBody}

詳細ページ:
{publicSessionDetailUrl}
```

入れないもの:

- 内部user ID
- email
- 内部application ID
- 内部comment ID
- Discord投稿credential
- サーバー側credential類
- 承認済み参加者のDiscord ID

本文が長すぎる場合は、Discord本文を要約し、詳細ページURLを必ず付ける。Discord側の文字数制限は実装時に確認する。

## 8. action別処理草案

### create

1. Auth確認。
2. `gm` / `admin` 権限確認。
3. 入力検証。
4. `create_session_post` RPCまたは同等のDB処理で `sessions` を作成。
5. `discord_sync_status = pending`, `discord_last_action = create`。
6. Discordへ新規投稿。
7. 成功時は `posted` とmessage/channel/thread情報を保存。
8. 失敗時は `failed` と短い失敗概要を保存。

### update

1. Auth確認。
2. `is_session_gm(session_id)` または `admin` 確認。
3. `sessions` の公開本文フィールドを更新。
4. `discord_last_action = update`, `discord_sync_status = pending`。
5. `discord_message_id` があれば既存投稿を編集。
6. 編集不可なら変更通知を追記投稿する代替を検討。
7. 成功/失敗状態を保存。

### close

1. Auth確認。
2. 対象GMまたはadmin確認。
3. `status = closed` へ更新。
4. Discord投稿を「募集終了」表示へ編集。
5. `discord_last_action = close` を保存。

### delete

1. Auth確認。
2. 対象GMまたはadmin確認。
3. 初期案では物理削除せず `visibility = hidden` などへ更新。
4. Discord投稿は物理削除ではなく「削除済み / 非公開」表示へ編集する。
5. 運用希望が明確なら物理削除方式も選択可能にする。

### resync

1. Auth確認。
2. 対象GMまたはadmin確認。
3. `sessions` の現在値を再取得。
4. `discord_message_id` があれば編集、なければ新規投稿。
5. 成功時にmessage/channel/thread情報を保存。
6. 失敗時は `failed` を維持/更新する。

## 9. Discord投稿先の未確定事項

専用投稿先が以下のどれかは実装前にユーザー確認する。

- 通常チャンネル
- フォーラムチャンネル
- 既存スレッド
- Discordイベント

投稿先により、`discord_channel_id` / `discord_thread_id` / `discord_message_id` の扱いとAPIが変わる。

## 10. まだやらないこと

- Edge Function deploy
- Discord実送信
- DB変更
- SQL Editor実行
- フロント実装
- credential値の記録
- `updates.json` 変更
- commit / push
