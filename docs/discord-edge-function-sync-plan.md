# M-14E-1 Discord同期Edge Function仕様整理

## 目的

依頼書作成・編集・削除の主要RPC smoke testが完了したため、次工程としてDiscord同期を扱うEdge Functionの仕様を整理する。

この文書では、依頼書保存と外部投稿を安全に分け、同期状態、失敗時の扱い、再同期、秘匿値管理、後続工程を定義する。今回は設計のみで、SQL作成、DB/RPC変更、Edge Function実装、deploy、Discord実送信、フロント実装は行わない。

## スコープ

- 依頼書DBを正本とし、Discord投稿は同期先として扱う。
- 既存の `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` はDB保存・更新・削除を担い、Discord実送信は行わない。
- Edge Functionは後続工程で、DB上の同期状態と同期アクションを見て外部投稿を実行する候補とする。
- 依頼書保存に失敗した場合は同期も行わない。逆に外部投稿に失敗しても、依頼書保存自体は成功扱いにする。
- GM/admin向けの再同期UIは後続工程の候補とし、今回は実装しない。

## 秘匿値を出さない方針

- 外部投稿に必要な秘匿値は、フロント、docs、DB、GitHub、チャットへ実値を書かない。
- 秘匿値はEdge Function側の管理設定で扱う。フロントは秘匿値を保持せず、直接Discordへ送らない。
- Edge Functionのログにも秘匿値、外部サービス応答の生全文、認証系の生値、内部識別子の実値を出さない。
- docsには設計方針と確認観点だけを書き、実値や接続文字列は記録しない。
- adminはアプリ内権限として扱い、サーバ高権限とは混同しない。

## Edge Function側の秘匿設定方針

- 外部投稿先のcredentialは、Edge Functionの管理設定として登録する。
- Edge Functionコードは管理設定から必要値を読み取り、レスポンスやログへ出さない。
- ローカル確認、dry-run、mock確認でも実値を表示しない。
- 実送信を伴う設定は、dry-run / mock確認が完了するまで有効化しない。
- 将来の手順docsでは、設定項目名や目的は一般化して記載し、値そのものは扱わない。

## Discord同期対象データ

Discordへ送る本文は、公開してよい依頼書情報だけで構成する。

同期対象候補:

- 依頼書タイトル
- 開催日、開始時刻、終了時刻、終了日時
- 申請締切
- 依頼書種別
- 募集人数
- 募集状態
- 公開状態
- 概要
- 公開詳細ページURL
- GM表示名

含めないもの:

- 認証系の生値
- 内部識別子の実値
- 参加申請やコメントの内部キー
- GM/admin向け承認済み参加者連絡先
- 非公開・下書き・内部管理用途の値
- 外部投稿credential

M-15テンプレート機能との接続は後続候補とする。初期実装では、Edge Function内で固定フォーマットを組み立てる案と、保存済みテンプレートから本文を生成する案を比較してから決める。

## 同期アクション一覧

| action | 用途 | 初期方針 |
| --- | --- | --- |
| `create` | Discordへ新規投稿する | 公開対象の新規依頼書を投稿する。投稿識別子を保存できるかをM-14E-2で確認する。 |
| `update` | 既存Discord投稿を更新する | 投稿識別子がある場合は既存投稿を更新する。ない場合は失敗扱いまたは再投稿候補として扱う。 |
| `close` | 募集終了・開催終了表示へ更新する | 既存投稿を終了表示へ更新する。完全削除とは分ける。 |
| `delete` | Discord投稿を削除または削除相当表示へ更新する | 監査性を考慮し、物理削除か「削除済み」表示への更新かを実装前に選ぶ。 |
| `resync` | 失敗後や手動操作で再同期する | 現在のDB内容から再実行する。GM/admin向け再同期ボタンの候補とする。 |

## DB側に必要な状態

既存列候補:

- `discord_sync_status`
- `discord_last_action`
- `discord_sync_requested_at`
- `discord_synced_at`
- `discord_sync_error`

状態値候補:

- `not_requested`: 同期未要求
- `pending`: 同期要求済み
- `posted`: 同期成功
- `failed`: 同期失敗
- `skipped`: 同期対象外

action値候補:

- `create`
- `update`
- `close`
- `delete`
- `resync`

初期方針:

- 依頼書保存時点では、同期対象なら `pending` と対象actionを記録する。
- 非公開、下書き、内部向けの依頼書は `skipped` として扱う候補にする。
- 同期成功時は `posted` と同期完了時刻を記録する。
- 同期失敗時は `failed` と短いエラー要約を記録し、依頼書本体は保持する。

## 既存列で足りるか / 不足しそうな列

基本的な「同期要求」「成功」「失敗」「再同期候補」の管理は既存列候補で足りる見込み。

ただし、既存Discord投稿を更新・終了表示・削除相当処理・再同期するには、外部投稿を一意に指す保存先が必要になる。`discord_message_id` 相当の列、投稿URL、投稿先チャンネルまたはスレッドを保持する列が存在するか、実際に運用可能かをM-14E-2のSELECT-only preflightで確認する。

不足候補:

- 外部投稿識別子
- 投稿先識別子
- 投稿URL
- 再試行回数または最終試行時刻
- エラー要約の長さ制限
- 複数投稿先や履歴を扱うための別テーブル

初期実装では、複数投稿先や詳細履歴テーブルまでは広げない。既存列で単一投稿先の同期を安全に成立させられるかを先に確認する。

## Discord投稿識別子保存の必要性

既存投稿を更新・終了表示・削除相当処理するには、どの外部投稿を操作するかを識別できる保存値が必要になる。

- `update` / `close` / `delete` / `resync` では、投稿識別子がないと既存投稿を安全に操作できない。
- 投稿識別子がない場合は、新規投稿を増やすよりも `failed` または「手動確認が必要」として扱う方が安全。
- 投稿識別子は画面やDOMに出さず、GM/admin向けUIでは同期状態と一般化されたメッセージだけを表示する。
- 投稿URLを表示する場合も、公開してよいURLかどうかを実装前に確認する。

## 失敗時の記録方針

- `discord_sync_error` には短い一般化された要約だけを保存する。
- 外部サービス応答の生全文、秘匿値、認証系の生値、内部識別子の実値は保存しない。
- エラー要約には長さ上限を設ける。
- 失敗後もDB上の依頼書本体は維持し、`failed` から `resync` できる余地を残す。
- 連続失敗時の再試行回数、バックオフ、最終試行時刻は後続候補とする。

## 依頼書保存とDiscord同期の扱い

依頼書保存を正本とし、Discord同期は後段処理として扱う。

- DB保存・更新・削除が成功した場合、外部投稿失敗だけで保存結果を取り消さない。
- 外部投稿失敗時は、画面上では「依頼書保存は完了、同期は失敗」のように分けて扱う候補にする。
- Edge Function内でDB更新と外部投稿を完全な単一トランザクションとして扱うことはできないため、状態記録と再実行設計を前提にする。
- 完全削除時はDB行が消えるため、外部投稿の削除相当処理をどのタイミングで行うかをM-14E-2以降で確認する。

## GM/admin向け再同期ボタン構想

後続のフロント実装候補として、GM/admin向けに再同期ボタンを追加する。

- 表示対象は、作成者GMまたはadminが管理できるSupabase由来依頼書。
- `failed` 状態、または手動再同期が必要な状態だけを主対象にする。
- ボタンはEdge Functionまたは専用の同期要求RPCを呼び出す候補とし、フロントからDiscordへ直接送らない。
- 画面には同期状態、最終同期時刻、一般化されたエラー要約を表示する。
- 投稿識別子や内部キーは画面・DOM・consoleに出さない。

## Edge Function呼び出し権限

Edge Functionは、認証済みユーザーの操作として呼び出す方針を基本にする。

- 未ログインは拒否する。
- 作成者GMは自分のSupabase由来依頼書だけを同期できる。
- adminはアプリ内権限として、Supabase由来依頼書を横断管理できる候補にする。
- 通常PLと他GMは同期実行できない。
- 静的JSON由来はDB RPC対象外のため、Edge Function同期対象にも含めない。
- Edge Function内部でサーバ側のDB操作権限が必要になる場合でも、アプリ内admin権限とは別物として扱う。

## dry-run / mock確認

実送信前にdry-run / mock確認を必須にする。

dry-runで確認すること:

- 対象依頼書の取得
- 権限判定
- 同期対象 / 非対象判定
- action判定
- 投稿本文生成
- 状態更新予定
- 秘匿値や内部情報が出力されないこと

mock確認で確認すること:

- 成功扱いの状態遷移
- 失敗扱いの状態遷移
- エラー要約の一般化
- `failed` から `resync` できること
- 同じ依頼書に対する重複実行時の扱い

## 実装前の注意点

- 外部投稿識別子の保存先が未確認のまま `update` / `close` / `delete` を実装しない。
- 同期対象判定を公開状態・募集状態・静的JSON由来の扱いと矛盾させない。
- `delete_session_post(text)` は完全削除であるため、削除前に外部投稿側をどう扱うかを設計する。
- ログに秘匿値や内部情報を出さない。
- 失敗時に依頼書保存そのものを失敗扱いにしない。
- adminはアプリ内権限として扱い、サーバ高権限とは混同しない。
- 実送信前にdry-run / mock確認を通す。
- Discord投稿本文に、承認済み参加者連絡先やGM/admin向け情報を混ぜない。

## 後続工程案

1. M-14E-1: Discord同期Edge Function仕様整理。
2. M-14E-2: 既存DB列 / 不足列 preflight SELECT-only SQL作成。
3. M-14E-3: DB列追加が必要な場合のみdraft SQL作成。
4. M-14E-4: apply_reviewed SQL作成・レビュー・ユーザー手動SQL Editor適用。
5. M-14E-5: Edge Function draft実装。
6. M-14E-6: Edge Function側の管理設定手順docs整理。
7. M-14E-7: dry-run / mock確認。
8. M-14E-8: deploy手順整理・実施判断。
9. M-14E-9: GM/admin向け再同期UI。
10. M-14E-10: 実送信QA。

## やらないこと

- SQLファイル作成
- SQL Editor実行
- DB構造変更
- RPC変更
- Edge Functionコード作成
- Edge Function deploy
- Discord実送信
- フロント実装
- `updates.json` 変更
- commit / push

## M-14E-2 preflight候補

M-14E-2ではSELECT-only SQLで以下を確認する。

- `public.sessions` のDiscord同期関連列の存在、型、CHECK制約。
- 投稿識別子、投稿URL、投稿先識別子に相当する列の存在有無。
- `discord_sync_status` / `discord_last_action` の許可値。
- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` が同期状態をどう更新しているか。
- 既存RPCの戻り値に同期状態以上の内部情報が含まれていないか。
- helper関数と権限方針。
- RLS / EXECUTE方針。
- 完全削除時に同期情報が残らないことによる影響。

## M-14E-2 preflight SQL作成メモ

M-14E-2では `docs/supabase/sql/025_discord_sync_preflight_select_only.sql` を作成し、Supabase SQL Editorでユーザーが手動確認できる単一結果セット形式にする。

確認項目:

- `public.sessions` の存在。
- Discord同期状態列の存在、型、nullable。
- `discord_message_id` 相当、投稿先、投稿URLに相当する列の存在有無。
- `discord_sync_status` / `discord_last_action` のCHECK制約。
- 依頼書の `status` / `visibility` / `session_type` のCHECK制約。
- 依頼書同期に関係する既存RPCの存在、`security_definer`、`search_path`、EXECUTE状態。
- 同期状態更新用または再同期用RPCが既にあるかどうかの関数名スキャン。
- admin / GM helper、RLS、policy概要。
- 静的JSON由来はDB catalog項目ではないため、同期対象外としてフロント表示・マージロジック側の確認観点に残す。

判断方針:

- 状態管理列と外部投稿識別子がそろっていれば、M-14E-5 Edge Function draftへ進める可能性がある。
- 状態管理列はあるが `discord_message_id` 相当列が不足する場合は、既存投稿の更新、終了表示、削除相当処理、再同期に支障があるため、M-14E-3でDB列追加draftを検討する。
- 既存列の不足が見つかっても、M-14E-2ではSQL Editor実行とDB変更は行わない。結果記録後にM-14E-3以降で扱う。

## M-14E-2 preflight実行結果

ユーザーが `docs/supabase/sql/025_discord_sync_preflight_select_only.sql` をSupabase SQL Editorで手動実行し、エラーなしで単一結果セットを確認した。

確認済み:

- `public.sessions` は存在し、status ok。
- 依頼書主要列として、公開ID、タイトル、概要、募集状態、公開状態、依頼書種別、開催日、開始/終了時刻、終了日時、申請締切、募集人数、GM表示名がすべてstatus ok。
- Discord同期状態列として、`discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` がすべて存在し、status ok。
- 外部投稿識別子・投稿先関連列として、`discord_message_id` 相当、`discord_channel_id` 相当、`discord_thread_id` 相当、`discord_post_url` 相当が存在し、status ok。
- baseline state columns は `5/5 present` でstatus ok。
- message identifier readiness は `has_message_identifier=true` でstatus ok。
- CHECK制約は、`discord_sync_status`、`discord_last_action`、募集状態、公開状態、依頼書種別がstatus ok。
- public draft guard はinfo / not found。DB制約ではなくRPC/UI側で扱う可能性があるため、後続実装・QA観点に残す。
- `sessions` / `user_roles` のRLS enabled はstatus ok。policy summaryはinfoとして確認済み。
- 既存依頼書RPC 3本は存在し、`security_definer=true`、`search_path=true`、`authenticated` EXECUTEあり、`anon` / `public` EXECUTEなしでstatus ok。
- 同期関連RPCスキャンでは、Discord/sync/resync系の名前を持つpublic関数が1件infoとして確認された。resync専用public関数は0件でmissing。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` と `public.user_roles` は存在し、status ok。
- server-side DB update path はinfo。Edge Function実装時に安全なサーバ側DB更新経路を選ぶ必要がある。
- 静的JSON由来はDB catalog項目ではないためinfo。Discord同期対象外として扱う確認観点を維持する。
- initial readiness judgment はstatus ok。既存同期列と外部投稿識別子が確認できており、初期Discord同期実装に必要なDB状態は概ね整っている可能性が高い。

判断:

- M-14E-2 preflightは成功扱いでよい。
- `discord_message_id` 相当列が既に存在するため、M-14E-3でDB列追加draftを急ぐ必要は低い。
- まず既存列を前提にしたEdge Function draft設計へ進めるかを検討できる。
- ただし再同期専用RPCとGM/admin向け再同期UIは未実装のため、後続工程に残す。
- adminはアプリ内権限として扱い、サーバ高権限とは混同しない方針を維持する。

この記録工程でCodexはSQL Editor実行、DB/RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushを行っていない。

## M-15テンプレート機能との接続候補

Discord投稿本文テンプレートは、M-15のテンプレート保存機能と接続できる可能性がある。

初期判断:

- M-14E初期実装では固定フォーマットを第一候補にする。
- GM個人テンプレートをDiscord投稿本文に使う場合、どのテンプレートを同期に使うかの選択UIと権限が必要になる。
- `call` / `result` / `session_post` / `application` / `other` の既存種別だけでDiscord投稿本文を表すと混線しやすい。
- 必要になった場合のみ、投稿文脈専用の種別または利用文脈の追加設計を検討する。
