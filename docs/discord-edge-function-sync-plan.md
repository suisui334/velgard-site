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
2. M-14E-2: 既存DB列 / 不足列 preflight SELECT-only SQL作成・実行結果記録。
3. M-14E-3: Edge Function入出力・dry-run仕様整理。
4. M-14E-4: Edge Function draft実装。
5. M-14E-5: Edge Function側の管理設定手順docs整理。
6. M-14E-6: dry-runローカル / 手動確認。
7. M-14E-7: deploy手順整理。
8. M-14E-8: deploy実施判断。
9. M-14E-9: GM/admin向け再同期UI。
10. M-14E-10: Discord実送信QA。

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

## M-14E-3 入出力・dry-run仕様整理

M-14E-2で既存同期列と外部投稿識別子がそろっていることを確認できたため、DB列追加draftを急がず、既存列を前提にしたEdge Function入出力仕様を `docs/discord-edge-function-io-plan.md` に整理した。

整理内容:

- Edge Functionの想定名称は `sync-session-post-to-discord` を初期推奨、`discord-session-sync` を比較候補とした。
- 入力payloadは `session_id`、`action`、`dry_run` を最小候補にし、`request_source` は補助値として扱う。権限判定の根拠にはしない。
- `create` / `update` / `close` / `delete` / `resync` のaction別挙動を整理した。
- dry-runはDiscord実送信せず、投稿本文プレビュー、同期対象判定、状態更新予定を返す方針にした。
- 初期投稿本文は固定フォーマットを第一候補にし、M-15テンプレート機能との接続は後続候補にした。
- 状態更新は `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` と、外部投稿識別子・投稿先・投稿URL相当列を使う方針にした。
- 失敗時は `failed` と一般化した短いエラー要約を残し、秘匿値や外部サービス応答の生全文は保存しない。
- 権限は未ログイン、通常PL、他GMを拒否し、作成者GMまたはアプリ内adminのみを許可する方針にした。
- Edge Function内部でDB更新に必要な権限は、アプリ内admin権限と混同せず、レビュー済みRPC経由案と安全なサーバ側更新案を後続で比較する。

懸念点:

- `delete_session_post(text)` の完全削除前にDiscord側delete/削除相当処理をどう呼ぶか。
- DB削除後に外部投稿識別子を参照できなくなる問題。
- resync専用RPCが未作成であること。
- GM/admin再同期UIの呼び出し先をEdge Function直呼びにするか、同期要求RPC経由にするか。
- M-15テンプレート機能との接続時期。

この工程ではdocs設計のみ。SQL Editor実行、DB/RPC変更、Edge Function実装、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-15テンプレート機能との接続候補

Discord投稿本文テンプレートは、M-15のテンプレート保存機能と接続できる可能性がある。

初期判断:

- M-14E初期実装では固定フォーマットを第一候補にする。
- GM個人テンプレートをDiscord投稿本文に使う場合、どのテンプレートを同期に使うかの選択UIと権限が必要になる。
- `call` / `result` / `session_post` / `application` / `other` の既存種別だけでDiscord投稿本文を表すと混線しやすい。
- 必要になった場合のみ、投稿文脈専用の種別または利用文脈の追加設計を検討する。

## M-14E-4 Edge Function draft実装結果

M-14E-2で既存DB列が概ねそろっていること、M-14E-3で入出力とdry-run方針を整理できたことを受け、DB列追加draftを挟まずに既存列前提のEdge Function draftを追加した。

作成ファイル:

- `supabase/functions/sync-session-post-to-discord/index.ts`

draftの性質:

- dry-run preview専用。
- `dry_run = true` では外部送信もDB更新も行わず、投稿本文preview、同期対象判定、状態更新予定、警告を返す。
- `dry_run = false` は明示的に未実装エラーとして拒否する。
- 入力payloadは `session_id` / `action` / `dry_run` / 任意の `request_source` に限定する。
- `request_source` は補助値であり、権限根拠にはしない。
- 作成者GMまたはアプリ内adminのみを既存helperで確認する。
- 外部投稿credential実値は読み出し・表示・記録しない。

action preview:

- `create`: 同期対象の依頼書から新規投稿previewを作る。既存投稿参照情報がある場合は警告を返す。
- `update`: 既存投稿参照情報がある場合だけ更新previewを返す。
- `close`: 既存投稿参照情報がある場合だけ終了表示previewを返す。
- `delete`: 既存投稿参照情報がある場合だけ削除相当処理previewを返す。DB完全削除前に外部投稿側処理が必要という警告を返す。
- `resync`: 既存投稿参照情報があれば `update` 相当、なければ `create` 相当のpreviewとして扱う。

後続で確認すること:

- dry-runのローカル / 手動確認。
- 権限helper呼び出しがEdge Function実行環境で期待どおり通るか。
- 返却previewに秘匿値や内部情報が混ざらないこと。
- `delete_session_post(text)` の完全削除前に外部投稿側処理を呼ぶ運用順。
- 実送信を有効化する前の外部投稿credential設定手順。
- 実送信時のDB状態更新経路。

この工程ではSQL Editor実行、DB/RPC変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-5 secret管理・dry-run確認手順docs

`docs/discord-edge-function-secret-plan.md` を追加し、Edge Function draftを安全にdry-run確認・deploy準備するための手順を整理した。

整理した方針:

- 外部投稿credentialやサーバ側高権限credentialの実値は、Edge Function側のsecret管理だけで扱う。
- docs、GitHub、フロント、DB、チャットへ実値を書かない。
- 初期dry-runではDiscord系secretを必須にしない。
- `dry_run = true` ではpreview確認だけを行う。
- `dry_run = false` は現draftでは拒否されることを確認する。
- DB更新、Discord実送信、外部投稿credential設定は後続工程まで行わない。
- app内admin権限とサーバ側高権限credentialを混同しない。

次工程候補:

- M-14E-6: Deno構文確認 / dry-run確認。
- M-14E-7: deploy手順整理。
- M-14E-8: deploy実施判断。
- M-14E-9: GM/admin向け再同期UI。
- M-14E-10: Discord実送信QA。

この工程ではdocs整理のみ。SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6 Deno構文確認 / dry-run確認準備

`docs/discord-edge-function-dry-run-check-result.md` を追加し、Edge Function draftのdeploy前確認結果を記録した。

確認結果:

- Denoはこの環境で利用できず、`deno check` は未実施。
- Edge Function draftに外部送信処理、DB書き込み処理、console出力は検出されなかった。
- 関連ファイルにsecret実値らしき文字列は検出されなかった。
- dry-run実行、Edge Function起動、deploy、secret実値設定、Discord実送信は行っていない。

次工程では、DenoまたはSupabase Edge Functionのローカル確認環境を用意し、構文確認と `dry_run = true` のpreview確認を行う。

この工程では確認・docs記録のみ。SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6B Deno確認方針整理

M-14E-6でDeno未導入により構文確認が未完了だったため、deploy前にどの環境でDeno確認とdry-run確認を行うかを整理した。

確認方法の候補:

- ローカルWindows環境でDenoを用意し、`deno check supabase/functions/sync-session-post-to-discord/index.ts` を実行する。
- Supabase CLI環境でEdge Functionローカル起動に近い形で確認する。
- CIまたは別環境でDeno構文確認を先に通す。

進行判断:

- Deno確認前にdeployへ進まない。
- dry-run実行確認前にDiscord実送信へ進まない。
- secret設定方針を再確認する前に実送信コードへ進まない。
- M-14E-7 deploy手順整理へ進む前に、Deno確認の実施環境を決める。

この工程ではdocs整理のみ。Deno導入、Supabase CLI導入、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6C ユーザーローカルWindows Deno確認結果

ユーザーのローカルWindows PowerShellでも `deno --version` は認識されず、Deno未導入であることを確認した。これにより、`deno check supabase/functions/sync-session-post-to-discord/index.ts` は引き続き未実施。

判断:

- Edge FunctionのDeno構文確認は未完了。
- Deno確認前にdeployへ進まない方針を維持する。
- dry-run実行確認前にDiscord実送信へ進まない方針を維持する。
- 次工程候補は、Deno導入、Supabase CLI環境、CIまたは別環境のいずれかで確認する案をユーザー確認のうえ選ぶこと。

この工程ではdocs記録のみ。Deno導入、Supabase CLI導入、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushは行っていない。

## M-14E-6C Deno導入後の構文確認・型エラー修正結果

ユーザーのローカルWindows環境でDeno導入後、`deno --version` と `deno check supabase/functions/sync-session-post-to-discord/index.ts` が成功した。

過去に `is_session_gm` RPC呼び出しで、`target_session_id` 引数が型定義上 `undefined` と衝突するTypeScript型エラーが出た。これは `is_session_gm` 呼び出し専用の薄い型緩和helperで修正済み。

同期Edge Functionの基本方針は維持する。

- 作成者GMまたはアプリ内adminのみ許可する。
- 通常PLを許可しない。
- `dry_run = true` はpreview専用。
- `dry_run = false` は拒否する。
- Discord実送信なし。
- DB更新なし。
- `fetch(`、DB書き込み系メソッド、`console.` は追加しない。

deploy前の残確認として、dry-run実レスポンス、拒否応答、ログ安全性、secret実値や内部識別子の非露出確認を残す。

この追記ではdocs記録のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、secret実値設定、commit / pushは行っていない。

## M-14E-6D dry-run実行確認方法整理

Deno構文確認は通ったため、次はdry-run実レスポンス確認へ進む。ただし、現時点でEdge Function deployやDiscord実送信には進まない。

確認方法は、Supabase CLIのローカルserveを第一候補とする。Supabase Edge Functionに近い形で、`dry_run = true` のpreview、権限拒否、同期対象外、既存投稿参照情報不足時の拒否を確認できるため。

Deno単体起動は、Edge Function実行環境との差異が出る可能性があるため慎重に扱う。deploy後dry-run限定確認は、deploy前のローカル確認や手順レビューを経てから判断する。

必要情報は、Supabase接続先、呼び出しユーザーの認証文脈、Edge Function実行用の環境変数、確認対象の依頼書ID相当の値。いずれも実値をdocsへ書かない。初期dry-runではDiscord投稿先credentialは原則不要とする。

次工程候補:

1. M-14E-6E: Supabase CLI利用可否確認。
2. M-14E-6F: ローカルserve dry-run確認。
3. M-14E-7: deploy手順整理。
4. M-14E-8: deploy判断。
5. M-14E-9: 再同期UI。
6. M-14E-10: 実送信QA。

この追記ではdocs整理のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6E Supabase CLI利用可否確認結果

`supabase --version` を確認した結果、この環境ではSupabase CLIは利用不可だった。

判断:

- Supabase CLIローカルserve dry-run確認は未実施。
- Supabase CLI導入は今回行っていない。
- Edge Function deploy、Discord実送信、`dry_run = false` 実行には進まない。

次工程候補:

1. ユーザー確認のうえでSupabase CLIを導入し、M-14E-6F ローカルserve dry-run確認準備へ進む。
2. Supabase CLIが利用できる別環境でローカルserve dry-run確認を行う。
3. deploy手順整理を先に行う場合も、実送信へ進まず、deploy後は `dry_run = true` 限定確認から始める。

この追記では利用可否確認とdocs記録のみ行い、Supabase CLI導入、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6E / 6F npx.cmd経由確認とローカルserve準備

ユーザー確認により、Node.jsは利用可能で、PowerShellの `npx` は実行ポリシーにより止まる。一方で、`npx.cmd supabase --version` ではSupabase CLI `2.105.0` を確認できた。

判断:

- Supabase CLIはグローバル導入済みではなく、`npx.cmd` 経由で利用可能な状態として扱う。
- PowerShellで今後Supabase CLIを使う場合は `npx.cmd` 経由を候補にする。
- ローカルserve dry-run確認の実行候補は `npx.cmd supabase functions serve sync-session-post-to-discord`。
- この工程ではserve、start、deploy、Discord実送信、`dry_run = false` 実行には進まない。

ローカルserve dry-run確認の準備方針:

- 必要情報はユーザーの手元だけで用意し、docsへ実値を書かない。
- `dry_run = true` のみ確認対象にする。
- Discord実送信とDB更新が発生しないことを確認する。
- レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを確認する。
- 初期dry-runではDiscord投稿先credentialは原則不要。

次工程候補:

1. M-14E-6F: `npx.cmd` 経由ローカルserve dry-run確認。
2. M-14E-7: deploy手順整理。
3. M-14E-8: deploy判断。
4. M-14E-9: 再同期UI。
5. M-14E-10: 実送信QA。

この追記ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-8 dry-run専用deploy実施前レビュー

Docker未導入によりローカルserve確認が保留になっているため、将来deploy後にdry-runだけを確認する前提で、deploy実施前レビューとコマンド候補を整理した。この工程ではdeployしない。

対象:

- Function名: `sync-session-post-to-discord`
- 対象ファイル: `supabase/functions/sync-session-post-to-discord/index.ts`
- 現状: dry-run preview専用draft
- `dry_run = true`: previewのみ
- `dry_run = false`: `real_send_not_enabled` で拒否

deploy前に止める条件:

- 作業ツリーがdirty。
- Deno構文確認が失敗する。
- `fetch(`、DB書き込み系メソッド、`console.` が増えている。
- 秘匿値の実値がコードまたはdocsに混入している。
- `dry_run = false` 拒否が崩れている。
- Function名または対象パスが曖昧。
- ユーザーのdeploy実施確認がない。

deploy候補コマンドは `npx.cmd supabase functions deploy sync-session-post-to-discord`。PowerShellでは `npx` ではなく `npx.cmd` を使う。deploy後確認は `create` / `dry_run = true` のみに絞り、Discord実送信なし、DB更新なし、レスポンスとログの安全性を確認する。

次工程候補は、M-14E-9 deploy実施判断、M-14E-10 deploy後 `create` / `dry_run = true` 確認、M-14E-11 `dry_run = false` 拒否確認、M-14E-12 real_send createのみ実装検討、M-14E-13 Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。

この追記ではdocs整理とdeploy前レビューのみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-9 dry-run専用deploy実施判断・最終手順整理

dry-run専用deployへ進む前に、deploy直前チェックとCLI認証・project link確認観点を整理した。この工程ではdeployしない。

deploy直前チェック:

- 作業ツリーがclean。
- Deno構文確認が成功。
- Supabase CLIは `npx.cmd` 経由で利用可能。
- `fetch(`、DB書き込み系メソッド、`console.` は0件。
- `deno.lock` なし。
- `updates.json` 差分なし。
- `dry_run = false` 拒否を維持。
- Discord API送信なし。
- DB書き込みなし。
- 秘匿値の実値なし。

CLI認証・project link確認:

- deploy時にはCLIログイン、project link、project ref相当の確認が必要になる可能性がある。
- これらの実値はdocsやチャットへ書かず、ユーザー手元だけで扱う。
- 認証やlinkが未設定、対象projectが不明、または実値をCodexへ渡す必要がある場合はdeployを止める。

deploy候補コマンド:

```powershell
npx.cmd supabase functions deploy sync-session-post-to-discord
```

deploy後確認は `create` / `dry_run = true` のみに絞る。`dry_run = false` はまだ実行しない。

次工程候補は、M-14E-10 ユーザー手動deploy実施、M-14E-11 deploy後 create / dry_run=true 確認、M-14E-12 dry_run=false拒否確認、M-14E-13 real_send createのみ実装検討、M-14E-14 Discord実送信QA、またはDocker Desktop導入後にローカルserve dry-runへ戻る案。

この追記ではdocs整理とdeploy直前レビューのみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6H dry-run実行条件整理とローカル実行可否

確認結果:

- `npx.cmd supabase --version` は `2.105.0`。
- Deno構文確認はユーザー領域のDeno実行ファイルをフルパス実行して成功。
- Edge Functionが参照する環境変数名は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。
- Bearer形式のAuthorizationヘッダーが必要。
- この作業環境では環境変数が未設定で、認証文脈も未用意。

判断:

- ローカルserveは実行しない。
- `dry_run = true` 実レスポンス確認も未実行。
- `dry_run = false` は実行しない。
- 秘匿値の実値や認証系の生値をCodex側で扱わない。

安全検索では、外部送信処理、DB書き込み系メソッド、console出力、外部投稿URL形式、bot token風文字列、service-role系credential風文字列はいずれも0件。

次工程候補:

1. ユーザー手元で必要な環境変数と認証文脈を安全に用意する。
2. ローカルserveを起動する。
3. `dry_run = true` のみを確認する。
4. 結果は実値を伏せ、成功 / 権限エラー / 同期対象外など一般化して記録する。

この追記ではdocs整理のみ行い、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6I ローカルdry-run手元実行ガイド

dry-run確認はユーザー手元で行う。Codexは秘匿値の実値、認証系の生値、実在する依頼書ID相当の値を扱わない。

手元実行の方針:

- PowerShell手順はプレースホルダーのみで記録する。
- 必要値はユーザー手元の環境変数、ブラウザ、ローカルメモだけで扱う。
- 初回は `create` の `dry_run = true` のみ確認する。
- `dry_run = false` は実行しない。
- Discord実送信なし、DB更新なしを確認する。
- レスポンスとログに秘匿値の実値、認証系の生値、内部識別子が出ないことを確認する。

手元実行後は、成功 / 権限不足 / 同期対象外 / 対象なし等に一般化して記録する。実値を含むレスポンス全文やログはそのままdocsへ貼らない。

次工程候補:

1. M-14E-6J: ユーザー手元dry_run=true実行結果記録。
2. 必要なら権限エラーや同期対象外の追加確認。
3. M-14E-7: deploy手順整理。

この追記ではdocs整理のみ行い、ローカルserve実行、`dry_run = true` 実行、`dry_run = false` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-6J ローカルserve不可結果

ユーザー手元では、Supabase CLIは `npx.cmd` 経由で利用可能、Deno構文確認も成功、必要環境変数も手元で設定済み。ただし、ローカルserve実行時にDocker Desktop / Docker daemonへ接続できず、`npx.cmd supabase functions serve sync-session-post-to-discord` は失敗した。

`docker --version` もPowerShellで認識されなかったため、ユーザー環境ではDocker CLI / Docker Desktopが未導入、またはPATH上で利用不可と判断する。

判断:

- ローカルserveはDocker未導入またはDocker daemon利用不可により未実行扱い。
- `dry_run = true` は未実行。
- `dry_run = false` は未実行。
- Discord実送信なし。
- DB更新なし。
- Edge Function deployなし。

次工程候補:

1. Docker Desktopを導入し、ローカルserve dry-run確認へ進む。
2. Docker導入を保留し、deploy前手順整理と安全レビューへ進む。
3. deploy後に確認する場合も、まず `dry_run = true` 限定確認から始める。

この追記ではdocs記録のみ行い、Docker Desktop導入、Supabase CLI追加導入、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-7 deploy後dry-run確認手順・deploy前安全レビュー

Docker未導入によりローカルserve確認が保留になっているため、将来deploy後に `dry_run = true` だけを確認する手順を整理する。この工程ではdeployしない。

現状:

- Deno構文確認は成功済み。
- Supabase CLIは `npx.cmd` 経由で利用可能。
- ローカルserveはDocker未導入またはDocker daemon利用不可により不可。
- `dry_run = true` / `dry_run = false` は未実行。
- Discord実送信なし。
- DB更新なし。

deploy前安全レビュー:

- 作業ツリーがclean。
- Deno構文確認が成功。
- 外部送信処理、DB書き込み処理、console出力が増えていない。
- `dry_run = false` が `real_send_not_enabled` で拒否される。
- 秘匿値の実値がコード、docs、GitHub差分にない。
- Authorization Bearerはユーザー手元だけで扱う。
- CORS方針を確認する。
- アプリ内admin権限とサーバ側高権限credentialを混同しない。

deploy後確認は `create` / `dry_run = true` のみに絞る。実値はdocsや報告へ書かず、`message_preview` と `planned_db_update` の有無、Discord実送信なし、DB更新なし、レスポンスとログの安全性を一般化して記録する。

次工程候補:

1. M-14E-8: Edge Function deploy手順・事前確認。
2. M-14E-9: deploy実施判断。
3. M-14E-10: deploy後dry_run=true確認。
4. M-14E-11: real_send createのみ実装検討。
5. M-14E-12: Discord実送信QA。
6. またはDocker Desktop導入後にローカルserve dry-runへ戻る。

この追記ではdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-6G ローカルserve dry-run実行可否確認

確認結果:

- `npx.cmd supabase --version` は `2.105.0`。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は、ユーザー領域のDeno実行ファイルをフルパス実行して成功。
- Edge Functionが参照する環境変数名は `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`PUBLIC_SITE_BASE_URL`。
- この作業環境では上記環境変数が未設定。
- 認証文脈も未用意。

判断:

- `npx.cmd supabase functions serve sync-session-post-to-discord` は実行しない。
- `dry_run = true` 実レスポンス確認も未実行。
- `dry_run = false` は引き続き実行しない。
- Discord実送信なし、DB更新なし、秘匿値の実値記録なしの方針を維持する。

安全検索では `fetch(`、DB書き込み系メソッド、`console.` は0件。

次工程候補:

1. ユーザー手元で必要な環境変数と認証文脈を用意する。
2. ローカルserveを起動する。
3. `dry_run = true` のみ確認する。
4. レスポンスとログの安全性を確認する。

この追記ではdocs整理のみ行い、Supabase CLI導入、`supabase functions serve` 実行、`supabase start` 実行、Edge Function deploy、Discord実送信、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。
