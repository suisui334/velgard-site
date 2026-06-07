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

## M-14E-10 dry-run専用deploy実施前 最終安全確認

dry-run専用deployの最終安全確認として、作業ツリー、Deno構文確認、Supabase CLI利用可否、安全検索、生成物、`updates.json`差分を確認した。この工程ではdeployしない。

確認結果:

- 作業ツリーはclean。
- 最新commitは `cf8037c Document Discord sync dry run deploy checklist`。
- Deno構文確認は成功。
- Supabase CLIは `npx.cmd` 経由で `2.105.0` を確認。
- `fetch(`、DB書き込み系メソッド、`console.` は0件。
- 外部投稿URL形式、bot token風文字列、認証系生値風文字列、service-role系文字列はいずれも0件。
- `deno.lock` なし。
- `updates.json` 差分なし。

deploy対象:

- Function名: `sync-session-post-to-discord`
- 対象ファイル: `supabase/functions/sync-session-post-to-discord/index.ts`
- 候補コマンド: `npx.cmd supabase functions deploy sync-session-post-to-discord`
- Codex側では実行しない。

deploy時にCLIログイン、project link、project ref相当、Supabase access token相当が必要になる可能性がある。実値はユーザー手元だけで扱い、docsやチャットへ書かない。認証やlinkの扱いが不明な場合はdeployを止める。

現時点の確認結果では、ユーザーが明示確認したうえで手動deployへ進むための直前安全条件は満たしている。ただし、deploy後確認は `create` / `dry_run = true` のみに絞り、`dry_run = false` はまだ実行しない。

この追記では最終安全確認とdocs整理のみ行い、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-11 dry-run専用deploy結果

ユーザー手元で `sync-session-post-to-discord` のEdge Function deployを実施し、成功した。Docker未起動に関するWARNINGは表示されたが、deploy自体は成功し、Supabaseプロジェクトへのアップロード・deployは完了している。

deploy後に `supabase/.temp/` がCLI生成物として未追跡生成されたが、ユーザーが削除済み。削除後の作業ツリーはclean。

現在の状態:

- Edge Function deploy済み。
- `dry_run = true` は未実行。
- `dry_run = false` は未実行。
- Discord実送信なし。
- DB更新なし。
- SQL Editor未実行。
- DB/RPC変更なし。
- フロント実装なし。
- 秘匿値の実値設定なし。
- `updates.json` 変更なし。

次工程は deploy後 `create` / `dry_run = true` 確認。Authorization Bearer、確認対象依頼書ID相当の値、Supabase接続先等はユーザー手元だけで扱い、docsや報告には実値を書かない。`dry_run = false`、Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

この追記ではdeploy結果のdocs記録のみ行い、Codex側でEdge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値設定、commit / pushは行っていない。

## M-14E-12B dry-run 500エラー修正

deploy済みEdge Functionの `create` / `dry_run = true` 確認でHTTP 500が発生したため、Functionコード側のRPC呼び出しを修正した。

原因:

- `is_session_gm` RPC呼び出し用helperで `supabase.rpc` を分離して呼んでいた。
- supabase-js内部のmethod bindingが外れ、RPC呼び出し時に内部client状態を参照できなくなった。
- エラー原因は「Supabase client rpc method binding issue」として一般化して扱う。

修正:

- `callIsSessionGmRpc` はclient本体を局所的に型緩和し、`rpcClient.rpc(...)` として呼ぶ形へ変更。
- Supabase client全体の型は崩さず、影響範囲を `is_session_gm` helperに限定。
- GM/adminのみ許可する権限判定意図は維持。
- `dry_run = false` は有効化しない。
- Discord実送信処理とDB更新処理は追加しない。

次工程は、ユーザー確認後に修正版のEdge Function deployを行い、その後 `create` / `dry_run = true` を再確認すること。

この追記ではFunctionコード修正とdocs記録のみ行い、SQL Editor実行、DB/RPC変更、Discord実送信、`dry_run = false` 実行、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-12D 修正版deploy後dry-run成功結果

修正版 `sync-session-post-to-discord` をdeploy後、ユーザー手元で `create` / `dry_run = true` を再確認し、HTTP 200で成功した。M-14E-12Bで発生していたHTTP 500は、Supabase client RPC method binding修正後の再deployで解消した。

確認できたこと:

- HTTP statusは200。
- レスポンスJSONのparseに成功。
- `ok = true`。
- `dry_run = true`。
- `action = create`。
- レスポンスには `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings` が含まれる。
- `message_preview` は返却あり。ただし本文全文は記録しない。
- Discord実送信なし。
- `dry_run = false` 未実行。
- DB更新なし。

`planned_db_update` はdry-run上の予定情報であり、実DB更新は行わない設計として扱う。

次工程候補は、`dry_run = false` 拒否確認、またはDiscord実送信実装前の追加安全レビュー。Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

この追記ではdry-run成功結果のdocs記録のみ行い、Edge Functionコード変更、Edge Function deploy、Discord実送信、`dry_run = true` 実行、`dry_run = false` 実行、SQL Editor実行、DB/RPC変更、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

## M-14E-13 dry_run=false拒否確認手順整理

`sync-session-post-to-discord` の `dry_run = false` が実送信へ進まず、安全に拒否されることを確認するための手順を整理した。この工程では実行しない。

確認方針:

- payloadは `create` / `dry_run = false` に限定する。
- `request_source` は手動拒否確認用の固定文字列を使う。
- 確認対象依頼書ID相当の値、Supabase接続先、Authorization Bearer等はユーザー手元だけで扱い、docsや報告へ実値を書かない。
- 期待する挙動は、HTTP 4xxまたは `ok = false` 相当での拒否。
- `real_send_not_enabled` または同等の拒否理由が返ることを確認する。
- Discord投稿なし、DB同期状態変更なし、Function Logsの安全性を確認する。

停止条件:

- `dry_run = false` が成功送信扱いになった。
- Discord投稿が作成された。
- DB同期状態列が変更された。
- レスポンスまたはログに秘匿値の実値、認証系の生値、内部識別子が含まれた。
- 想定外のエラーで拒否確認として扱えない。

停止条件に該当した場合は以後再実行せず、一般化した結果だけを記録し、追加安全レビューへ戻る。

次工程候補は、ユーザー手元での `dry_run = false` 拒否確認結果記録、またはDiscord実送信実装前の追加安全レビュー。Discord実送信、Discord投稿先credential設定、DB更新、フロント接続はまだ行わない。

この追記では手順整理のみ行い、`dry_run = false` 実行、Discord実送信、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、Edge Function deploy、フロント実装、秘匿値の実値記録、commit / pushは行っていない。

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

## M-14E-13C dry_run=false拒否結果と初期投稿先方針

### dry_run=false拒否確認結果

ユーザー手元でdeploy済み `sync-session-post-to-discord` の `create` / `dry_run = false` 拒否確認を実施し、HTTP 501で想定どおり拒否された。レスポンスはJSONとしてparse可能で、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。

この確認ではDiscord実送信は発生していない。DB/RPC変更、SQL Editor実行、Edge Functionコード変更、Edge Function deploy、フロント実装も行っていない。確認に使った認証文脈、対象依頼書ID相当の値、Supabase接続先全文、Discord投稿先、レスポンス本文全文はdocsへ記録しない。

### 初期Discord投稿先方針

M-14E-14へ進む前の方針として、初期実装では「案A: 全依頼書を1つの募集チャンネルへ投稿」を採用する。

採用する方針:

- 全依頼書のDiscord同期先は、初期実装では単一の募集チャンネルに固定する。
- GMごとの投稿先選択は初期実装では行わない。
- 依頼書種別ごとのチャンネル分岐は初期実装では行わない。
- セッションごとの投稿先指定は初期実装では行わない。
- 投稿先の実値、外部送信用credential、チャンネル識別子相当の値は、フロント、docs、GitHub、チャットに記録しない。
- 投稿先設定は将来のsecret設定工程で扱う。
- 実送信実装前に、単一募集チャンネル向けのsecret名候補、設定手順、失敗時挙動を別工程で整理する。

将来拡張候補:

- GM別投稿先
- 依頼書種別別投稿先
- セッション別投稿先
- 複数チャンネルへの通知分岐

初期実装では、投稿先分岐を増やす前に、単一募集チャンネルへのcreate同期を安全に成立させることを優先する。

## M-14E-14 単一募集チャンネル向け実送信前設計

初期Discord同期は、全依頼書を1つの募集チャンネルへ投稿する方針で進める。GM別、依頼書種別別、セッション別の投稿先分岐は初期実装では行わない。

### 推奨方式

初期実装ではWebhook方式を第一候補にする。単一投稿先に固定する要件と相性がよく、Bot tokenを扱わずに済むため、実送信前の安全境界を小さく保てる。

Bot方式は、将来的にGM別、種別別、セッション別の投稿先分岐や複雑なDiscord操作が必要になった場合に再検討する。初期実装ではBot方式に必要なtokenや投稿先識別子相当の値を扱わない。

### DB更新タイミング方針

- `dry_run = true` ではDB更新しない。
- 実送信成功後にのみ、外部投稿識別子相当の値、同期状態、最終アクション、同期日時を更新する案を第一候補にする。
- 実送信失敗時は、依頼書保存自体は成功扱いとし、Discord同期だけをfailed相当にする。
- failed時のエラー記録は一般化した概要にとどめ、secret、認証情報、外部APIレスポンス全文、投稿先実値を含めない。
- update/close/delete/resyncは、create実送信が安全に成立した後に段階的に扱う。

### 実送信有効化前の安全境界

- `dry_run = false` は実送信有効化条件を満たすまで拒否を維持する。
- 投稿先secret未設定時は一般化エラーで拒否する。
- Discord API送信処理追加後も、`dry_run = true` はpreview専用に固定する。
- レスポンス、Function Logs、docsへsecret実値、認証情報、確認対象依頼書ID相当の値、Supabase接続先全文、Discord投稿先実値、`message_preview` 本文全文を出さない。

### 次工程分割案

1. M-14E-14A: secret設計docs整理。
2. M-14E-14B: 実送信draft設計。
3. M-14E-14C: 実送信コード実装。ただし `dry_run = false` 拒否はまだ維持。
4. M-14E-14D: secret設定手順整理。
5. M-14E-14E: テスト用チャンネルまたは本番募集チャンネルで実送信確認。

今回の工程ではdocs整理のみ行い、secret実値設定、Discord実送信、Edge Functionコード変更、deploy、SQL Editor実行、DB/RPC変更、フロント実装は行わない。

## M-14E-14B/C 実送信draft設計と実装前レビュー
初期実送信は、単一募集チャンネル向けWebhook方式の `create` から小さく始める。GM別、依頼書種別別、セッション別の投稿先分岐は初期実装に含めず、将来拡張候補として残す。

### action別の将来設計
- `create`: Discordへ新規投稿する。外部投稿識別子が既にある場合は二重投稿を避け、拒否または `update` / `resync` 相当へ誘導する案を第一候補にする。
- `update`: 外部投稿識別子がある場合のみ、既存Discord投稿を更新する。識別子がない場合は拒否または `create` 相当へ明示的に誘導する。
- `close`: 募集終了・終了表示に更新する。投稿削除ではなく、募集終了状態を残す案を第一候補にする。
- `delete`: Discord投稿を削除する案と、削除せず終了表示へ更新する案を比較する。依頼書完全削除後は外部投稿識別子を参照できないため、完全削除前の処理順を別途レビューする。
- `resync`: failed状態やGM/admin手動再同期で使う。外部投稿識別子がある場合は `update` 相当、ない場合は `create` 相当を候補にする。

### DB更新タイミング
- `dry_run = true` ではDB更新しない。
- `dry_run = false` 拒否時もDB更新しない。
- 実送信成功後にのみ、外部投稿識別子、同期状態、最終action、同期日時相当をDBへ反映する案を第一候補にする。
- 実送信失敗時は、依頼書保存自体を壊さず、同期状態をfailed相当にして一般化したエラー概要だけを残す案を検討する。
- DB更新には安全なサーバー側経路が必要。既存RPCで足りるか、同期状態更新専用RPCが必要かは後続工程で確認する。現段階ではSQLを作らない。

### 実装前レビュー
実装前には、secret未設定時の拒否、dry-run境界、外部API失敗時の一般化、ログ安全性、二重投稿防止、送信成功後DB更新失敗時の扱い、外部投稿識別子既存時の `create` 挙動をレビューする。

次工程は、M-14E-14Cで実送信コードdraftを作る場合でも `dry_run = false` 拒否を維持したままレビューできる形にする。その後、secret設定手順、dry-run再確認、テスト投稿、DB更新連携、フロント管理UI接続へ分割する。

## M-14E-14C Webhook実送信用draftコード追加
Edge Function `sync-session-post-to-discord` に、将来のWebhook実送信用draft helperを追加した。ただし、現行制御フローでは呼び出していない。`dry_run = false` は認証やDB読取より前に `real_send_not_enabled` 相当で拒否される状態を維持している。

追加したdraftの役割:

- Webhook secret名候補をコード上の定数として参照する。
- Webhook payloadを `content` と `allowed_mentions` で組み立てる。
- Discord WebhookへPOSTする将来処理をhelper内に隔離する。
- Discord成功レスポンスから外部投稿識別子相当だけを抽出する。
- 失敗時は生レスポンス全文ではなく、一般化したエラー種別へ丸める。

今回追加していないもの:

- `dry_run = false` の実送信有効化。
- DB更新処理。
- 外部投稿識別子保存処理。
- Discord同期状態更新処理。
- フロントからの呼び出しUI。

次工程では、実送信helperを有効化する前に、secret設定手順、実送信ON/OFF条件、DB更新RPCの要否、二重投稿防止、送信成功後DB更新失敗時の扱いを再レビューする。

## M-14E-14D secret設定後の同期安全境界
`DISCORD_SESSION_POST_WEBHOOK_URL` を設定しても、現行の同期処理はただちに実送信へ進まない。Webhook helperはdraftとして存在するが、現行リクエスト処理からは呼ばれず、`dry_run = false` は `real_send_not_enabled` 相当で拒否される。

secret設定後の確認順は以下とする。

1. secret実値をdocs、GitHub、DB、フロント、チャットへ出していないことを確認する。
2. `dry_run = true` がpreviewのみで、Discord送信とDB更新を行わないことを再確認する。
3. 実送信有効化前に `dry_run = false` が拒否されることを確認する。
4. Function Logsにsecret実値、認証情報、確認対象依頼書ID相当の実値、投稿先実値が出ていないことを確認する。
5. Discord側に新規投稿が増えていないことを確認する。

実送信を有効化するコード変更は別工程にする。有効化前に、投稿先をテスト用チャンネルにするか本番募集チャンネルにするか、誤投稿時の削除/訂正方針、二重投稿防止、既存外部投稿識別子がある場合の `create` 挙動、Discord送信成功後のDB更新失敗時の扱いを最終レビューする。

次工程候補は、M-14E-14E secret設定手順のユーザー確認、M-14E-14F secret設定後dry_run=true再確認、M-14E-14G 実送信有効化コード設計、M-14E-14H テスト投稿確認とする。

## M-14E-14E secret設定前の投稿先判断と同期停止条件
`DISCORD_SESSION_POST_WEBHOOK_URL` の実secret設定へ進む前に、同期先と初回確認方針を明確にする。初期方針は「全依頼書を1つの募集チャンネルへ投稿」で確定しているが、実際に使う投稿先はdocsへ実値を書かず、「本番募集チャンネル」または「テスト用チャンネル」という抽象名で扱う。

投稿先判断:

- 初回実送信確認をテスト用チャンネルで行うか、本番募集チャンネルで行うかをユーザーが判断する。
- 本番募集チャンネルを使う場合は、投稿本文が公開されても問題ない状態であることを事前に確認する。
- テスト用チャンネルを使う場合は、本番募集チャンネルへ切り替える前にsecret差し替え、dry-run再確認、拒否境界確認を別工程で行う。
- GM別、依頼書種別別、セッション別の投稿先分岐は初期実装では行わない。

secret設定後の同期境界:

- secret設定だけではDiscord同期の実送信を有効化しない。
- Webhook helperは現行リクエスト経路から呼ばず、`dry_run = false` は `real_send_not_enabled` 相当で拒否を維持する。
- secret設定後も最初は `dry_run = true` のpreview維持、Discord投稿なし、DB更新なし、ログ安全性を確認する。
- 実送信有効化コード変更までは、Discord側に投稿が増えないことを確認観点にする。

実送信有効化前の停止条件:

- 投稿先チャンネルが未確定。
- テスト用チャンネルか本番募集チャンネルかの判断が未確定。
- 誤投稿時の削除または訂正方針が未確定。
- 二重投稿防止策、外部投稿識別子既存時の `create` 挙動、Discord成功後DB更新失敗時の扱いが未整理。
- secret、Webhook URL、認証情報、投稿先実値、確認対象依頼書ID相当の実値が露出するおそれがある。

次工程候補は、M-14E-14F ユーザー手元でのsecret設定、M-14E-14G secret設定後 `dry_run = true` 再確認、M-14E-14H `dry_run = false` 拒否維持確認、M-14E-14I 実送信有効化コード変更案、M-14E-14J 初回テスト投稿確認とする。

## M-14E-14F テスト用チャンネル前提のsecret設定直前整理
初回のDiscord実送信確認は、本番募集チャンネルではなくテスト用チャンネルを先に使う方針に確定する。初期同期方針は「全依頼書を1つの募集チャンネルへ投稿」のままだが、最初のWebhook secretはテスト用チャンネル向けに設定する。テスト用チャンネル名、チャンネルID、Webhook URL、投稿先実値はdocsへ記録しない。

手順概要:

1. Discord側でテスト用チャンネルを用意する。
2. テスト用チャンネルにWebhookを作成する。
3. Webhook URLはユーザー手元だけで扱い、チャット、docs、GitHub、consoleへ出さない。
4. Supabase secret `DISCORD_SESSION_POST_WEBHOOK_URL` にWebhook URLを設定する。
5. secret設定後も実送信は有効化せず、`dry_run = true` preview維持と `dry_run = false` 拒否維持を確認する。
6. テスト用チャンネルでの確認完了後、本番募集チャンネルへ切り替えるかは別工程で判断する。

同期境界:

- secret設定だけでは実送信しない。
- Webhook helperは現行リクエスト経路から呼ばれず、`dry_run = false` は `real_send_not_enabled` 相当で拒否される。
- secret設定後もDiscord投稿なし、DB更新なし、Function Logsのsecret非露出を確認する。
- 本番募集チャンネルへの切り替えは、テスト用チャンネルでの確認結果を記録してから行う。

停止条件:

- Webhook URLがdocs、GitHub、チャット、ログ、consoleに出た可能性がある。
- テスト用チャンネルではないWebhookを設定した可能性がある。
- `dry_run = false` が拒否されない。
- Function LogsにWebhook URLまたは認証情報が出た。
- Discordに意図しない投稿が出た。
- secret設定後のdry-run確認が未完了。

次工程候補は、M-14E-14G テスト用チャンネルWebhook作成、M-14E-14H Supabase secret設定、M-14E-14I secret設定後 `dry_run = true` 再確認、M-14E-14J `dry_run = false` 拒否維持確認、M-14E-14K 実送信有効化コード変更案、M-14E-14L テスト用チャンネル初回実送信確認とする。

## M-14E-14G/H/I/J テスト用Webhook secret設定後の同期確認結果
ユーザー手元で、テスト用チャンネル向けWebhook secret設定、secret設定後 `create` / `dry_run = true` 再確認、secret設定後 `create` / `dry_run = false` 拒否維持確認を実施済み。

結果:

- Supabase secret `DISCORD_SESSION_POST_WEBHOOK_URL` をテスト用チャンネル向けWebhookで設定した。
- Webhook URL本体、投稿先実値、認証情報、確認対象依頼書ID相当の実値は記録しない。
- 設定時に誤った値を設定した可能性があったため、正しいテスト用Webhook URLで上書き済み。
- `dry_run = true` はHTTP 200で成功し、preview専用のまま維持された。
- `dry_run = true` レスポンスでは `ok = true`、`dry_run = true`、`action = create`、`message_preview`、`planned_db_update`、`warnings` を確認した。`message_preview` 本文全文は記録しない。
- `dry_run = false` はHTTP 501で拒否され、`ok = false`、`error_code = real_send_not_enabled`、`dry_run = false` を確認した。
- テスト用チャンネルに新規投稿は増えていないことをユーザーが目視確認済み。
- secret設定だけではDiscord投稿は発生せず、実送信はまだ有効化していない。
- DB/RPC変更、SQL Editor実行、Edge Functionコード変更、deploy、フロント実装は行っていない。

次工程候補は、M-14E-14K 実送信有効化コード変更案レビュー、M-14E-14L 初回実送信確認手順整理、M-14E-14M 実送信有効化コード実装、M-14E-14N テスト用チャンネル初回実送信確認とする。

## M-14E-14K 実送信有効化コード変更案の同期レビュー
次のコード変更では、実送信対象をテスト用チャンネル向け `create` のみに限定する案を第一候補にする。`dry_run = true` はpreview専用のまま維持し、`update` / `close` / `delete` / `resync` は引き続き未対応または拒否として扱う。

有効化条件:

- `action = create` である。
- GM本人またはアプリ内admin相当の権限確認が通っている。
- 対象依頼書が同期対象として許可されている。
- テスト用チャンネル向けWebhook secretが解決できる。
- `dry_run = true` preview再確認が直前に成功している。

同期境界:

- secret未設定または不正時は一般化エラーで拒否し、Discord送信もDB更新も行わない。
- Discord送信成功前にDB更新しない。
- 初回実送信ではDiscord投稿のみを確認し、外部投稿識別子保存、同期状態更新、失敗状態記録は後続工程へ分離する案を推奨する。
- DB更新連携を同時に入れる場合は、送信成功後DB更新失敗時の扱い、二重投稿防止、既存外部投稿識別子がある場合の `create` 挙動を追加レビューする。

二重投稿防止:

- 初回テストは手動で1回だけ実行し、同じpayloadを再実行しない。
- 恒久対応は、外部投稿識別子相当をDBへ保存した後、既存識別子がある `create` を拒否または `update` / `resync` へ誘導する方針を第一候補にする。

停止条件:

- `dry_run = true` がpreview専用でなくなった。
- `update` / `close` / `delete` / `resync` が意図せず実送信可能になった。
- Webhook URL、投稿先実値、認証情報、確認対象依頼書ID相当の実値がログやレスポンスへ出た。
- Discord APIエラー本文がそのままログやレスポンスへ出た。
- テスト用チャンネル以外に投稿された。
- 二重投稿が発生した。

次工程候補は、M-14E-14L 実送信有効化コード実装、M-14E-14M 構文確認と安全検索、M-14E-14N deploy、M-14E-14O `dry_run = true` 再確認、M-14E-14P テスト用チャンネルで `create` 実送信1回確認、M-14E-14Q 結果記録とする。

## M-14E-14L create実送信経路の実装記録
テスト用チャンネル向けWebhook secretを使う `create` 実送信経路をEdge Functionに接続した。接続範囲は `dry_run = false` かつ `action = create` のみで、他actionは初回実装では拒否を維持する。

同期フロー:

1. payload検証後、`dry_run = false` かつ `action` が `create` 以外なら拒否する。
2. Authorization、GM/admin権限、対象依頼書取得、同期対象判定、action検証を行う。
3. `dry_run = true` なら従来どおりpreviewと予定情報だけを返す。
4. `dry_run = false` かつ `create` なら、preview本文相当をWebhook payloadとして送信する。
5. 成功時は最小レスポンスを返し、DB更新は行わない。

DB更新連携、外部投稿識別子保存、同期状態更新は未実装のまま維持する。二重投稿防止は初回テストでは手動1回運用とし、恒久対策は外部投稿識別子保存工程で扱う。deploy、Discord実送信、dry-run再実行はこの工程では行っていない。

## M-14E-14M deploy前最終安全確認
テスト用チャンネル向け `create` 実送信経路をdeployする前に、コード静的確認と運用停止条件を再整理した。この工程ではdeploy、Discord実送信、dry-run再実行、SQL Editor実行、DB/RPC変更、フロント実装は行っていない。

確認済み:

- 最新commitは `feb9f24 Enable Discord create send path for test webhook`。
- 作業開始時の作業ツリーはclean。
- Deno構文確認は成功。
- `fetch(` はWebhook helper内の想定箇所のみ。
- DB書き込み系メソッドと `console.*` は追加されていない。
- `dry_run = true` はpreview専用で、Webhook helperへ到達しない。
- 実送信経路は `dry_run = false` かつ `action = create` のみに限定される。
- `update` / `close` / `delete` / `resync` は拒否維持。
- secret未設定または不正時はfetch前で拒否する。
- DB更新、外部投稿識別子保存、同期状態更新はまだ行わない。

初回実送信前の運用前提:

- 投稿先はテスト用チャンネルであり、本番募集チャンネルではない。
- 初回実送信に使う依頼書は検証用に限定する。
- 初回実送信は1回だけ行い、二重実行しない。
- 二重投稿防止の恒久対策は、外部投稿識別子保存とDB更新連携の後続工程で扱う。
- 実送信後に確認するのは、テスト用チャンネルへの1件投稿とFunctionレスポンスの一般化情報のみ。

deployを止める条件:

- gitがcleanでない。
- Deno構文確認が失敗する。
- `fetch(` が想定外に増える。
- DB書き込み系メソッドまたは `console.*` が追加される。
- secret実値、Webhook URL実値、投稿先実値、認証情報、確認対象依頼書ID相当の値が露出している。
- テスト用チャンネルでない可能性がある。
- 検証用依頼書や1回だけ実行する運用が未確定。

次工程は、Edge Function deploy、deploy後 `dry_run = true` preview維持確認、テスト用チャンネルで `create` 実送信1回確認、結果記録、DB更新連携設計の順に分割する。

## M-14E-14Q テスト用チャンネル初回実送信結果
テスト用チャンネル向けに、`create` / `dry_run = false` の初回実送信をユーザー手元で1回実施し、HTTP 200で成功した。対象は検証用依頼書 `TEST_1`。確認対象ID相当の実値、Webhook URL、投稿先実値、認証情報、Supabase接続先全文、Discord message id相当の実値、`message_preview` 本文全文は記録しない。

確認結果:

- HTTP 200で成功。
- JSON parse成功。
- レスポンスは `ok` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings` を含む。
- `ok = true`、`dry_run = false`、`action = create` を確認。
- 外部投稿識別子相当の実値はレスポンスに返っていない。
- テスト用チャンネルに依頼書通知が1件作成されたことを確認。
- 本番募集チャンネルへの投稿はなし。
- DB更新連携は未実装のため、今回のFunction処理ではDB更新を行わない設計。

注意点:

- 今回、確認入力の意図に反して貼り付け済みの後続行が実行され、実送信が行われた。
- 投稿先がテスト用チャンネルで、結果が1件投稿に留まったため重大事故には至っていない。
- 今後は対話プロンプト依存を避け、確認コマンドと送信コマンドを明確に分離する。
- 再実行は禁止。二重投稿防止は後続のDB更新連携と外部投稿識別子保存工程で恒久対応する。

次工程は、DB更新連携設計、外部投稿識別子保存、二重投稿防止、本番募集チャンネルへの切り替え判断に分ける。

## M-14E-15 Discord投稿フォーマット改善と開催場所フィールド設計
テスト用チャンネルへの初回実送信は成功したが、現行のDiscord投稿本文はDB項目を並べた印象が強く、参加者向け募集文として読みづらい。M-14E-15では、Discord依頼書投稿を参加者向けの依頼書形式へ改善し、あわせて「開催場所」フィールドを依頼書データに追加する方針を整理する。この工程では設計docs整理のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

### Discord投稿フォーマット改善方針
今後のDiscord投稿本文は、参加者が募集内容を一目で読める形式を第一候補にする。旧来の詳細URL付きフォーマットは、Discord側の埋め込み表示で画面が散らかるため、次工程以降では採用しない。

新フォーマット案:

```text
＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝

■依頼書【タイトル】
GM【GM名】
開催場所【開催場所】
日時【MM/DD(曜) HH:mm　～　MM/DD(曜) HH:mm】
参加人数【最小～最大人】
参加締切【MM/DD(曜) HH:mm】

概要
概要本文
```

本文方針:

- 冒頭に `＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝` を置く。
- 下部には区切り線を置かない。
- `詳細` 欄は置かない。
- サイト詳細URLやクエリ付き詳細導線はDiscord本文に入れない。
- URLを入れるとDiscord側のOGP/埋め込み表示が出るため、投稿本文は概要までで完結させる。
- 参加者はカレンダーまたはサイト側の通常導線から詳細を確認する前提にする。
- `dry_run = true` previewと実送信本文は同じ整形関数・同じフォーマットを使う。
- `message_preview` 本文全文はdocsやログへ記録しない方針を維持する。

未設定時の候補:

- 開催場所未設定時は `開催場所【未定】` を第一候補にする。
- GM名未設定時は既存表示方針に合わせて一般化した未設定表示を使う。
- 概要が空の場合は `概要` の下に `未設定` を表示する案を第一候補にする。

### 開催場所フィールド追加方針
日本語ラベルは「開催場所」とする。ただし意味としては物理的な会場ではなく、Tekey、ココフォリア、ユドナリウムリリィ、Discordボイスなどのセッションツール/開催環境を指す。

内部名候補:

| 候補 | 評価 |
| --- | --- |
| `session_tool` | 第一候補。セッションで使うツール/環境という意味が明確で、物理会場と混同しにくい。 |
| `play_location` | 「場所」寄りで自然だが、物理的な場所にも読める。 |
| `venue` | 会場の意味が強く、オンラインツール用途ではややずれる。 |
| `session_place` | 日本語ラベルとは近いが、物理場所の印象が残る。 |

初期設計では `session_tool` を第一候補にし、DB/RPC/UI/Discord投稿の意味を「開催場所 = セッションツール/開催環境」で統一する。

### DB/RPC設計観点
後続工程で、依頼書の正本テーブルに `session_tool` 相当列が必要かをpreflightで確認する。既存列がなければDB/RPC変更が必要になる可能性が高い。

確認・設計観点:

- 依頼書テーブルに `session_tool` 相当列が既に存在するか。
- `create_session_post(...)` / `update_session_post(...)` / detail/list取得処理が `session_tool` を扱う必要がある。
- 既存データは未設定を許容する。初期はNULLまたは空文字を許容し、表示時に `未定` へ丸める案を第一候補にする。
- CHECK制約や固定候補化は急がず、初期はtextの自由入力を第一候補にする。
- 将来、候補selectへ寄せる場合でも、Tekey、ココフォリア、ユドナリウムリリィ、Discord、その他の候補をUI側で扱い、DB値の固定化は別途検討する。
- SQLはM-14E-15では作成しない。M-14E-15B以降でdraft/applyを分ける。

### 依頼書編集UI修正方針
`session-post.html` の依頼書編集UIでは、募集人数min/maxを同じ行へまとめ、空いたスペースに「開催場所」を配置する案を第一候補にする。

UI方針:

- 募集人数min/maxは横並びまたはコンパクトな2カラムにまとめる。
- 開催場所は、初期は自由入力を第一候補にする。
- 候補式にする場合は、Tekey、ココフォリア、ユドナリウムリリィ、Discord、その他を候補にする。
- 候補式にしても、卓ごとの表記揺れや新ツールに対応するため、その他/自由入力の逃げ道を残す。
- 既存テンプレート機能の `session_post` JSONにも開催場所を含めるかは、UI実装時に互換性を確認する。

### session-detail / GM管理表示の方針
`session-detail.html` では、参加者向け情報を上に、GM/admin管理操作を下に寄せる。

表示方針:

- 右側情報枠の募集状態付近に開催場所を表示する案を検討する。
- 管理ブロックは募集状態の下へ移動し、情報表示より目立ちすぎない配置にする。
- 募集状態表示と管理ボタンの窮屈さを解消する。
- 通常PLにはGM/admin管理操作を表示しない既存方針を維持する。
- 開催場所未設定時は `未定` 表示を第一候補にする。

### Edge Functionフォーマット反映方針
Edge Functionのmessage preview生成処理を新フォーマットへ変更する必要がある。

実装時の確認観点:

- `dry_run = true` と実送信で同一フォーマットを使う。
- 日時はISO文字列ではなく、`MM/DD(曜) HH:mm` のような短い日本語向け形式へ整形する。
- 曜日表示を入れる。
- UTC表記やISO時刻をDiscord本文に出さない。
- 募集人数は `2～5人` のように表示する。
- 開催場所未設定時は `未定` に丸める。
- 概要空欄時は `未設定` に丸める案を第一候補にする。
- 詳細URLやサイトURLは本文に入れない。
- 承認済み参加者連絡先、GM/admin向け情報、内部ID、認証情報、Discord投稿先実値は本文に含めない。

### 次工程分割案
M-14E-15は安全に以下へ分割する。

1. M-14E-15A: 投稿フォーマット/開催場所フィールド設計docs整理。
2. M-14E-15B: DB/RPC変更SQL draft作成。
3. M-14E-15C: SQL apply前レビュー。
4. M-14E-15D: 依頼書編集UIフィールド追加実装。
5. M-14E-15E: session-detail表示とGM/admin管理配置調整。
6. M-14E-15F: Edge Function preview/実送信フォーマット変更。
7. M-14E-15G: `dry_run = true` QA。
8. M-14E-15H: テスト用チャンネル実送信QA。

## M-14E-15B session_tool追加に向けたDB/RPC preflight・SQL draft設計
M-14E-15Bでは、Discord投稿新フォーマットの `開催場所【...】` に使う依頼書データとして `session_tool` を追加できるかを確認するため、SELECT-onlyのpreflight SQL draftを作成した。この工程ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

作成したpreflight:

- `docs/supabase/sql/026_session_tool_preflight_select_only.sql`
- 単一結果セット形式。
- 出力列は `sort_order` / `section` / `check_name` / `expected` / `status` / `result_value` / `notes`。
- 実データ値ではなく、catalog上のテーブル、列、RPC signature、権限、RLS、policy概要だけを確認する。

preflight確認対象:

- `public.sessions` が依頼書の正本テーブルとして存在するか。
- `public.session_posts` のような別テーブルが存在し、設計判断に影響しないか。
- `public.sessions.session_tool` が既に存在するか。
- `play_location` / `venue` / `session_place` など類似列が既に存在しないか。
- public schema全体に `tool` / `place` / `location` / `venue` 系の類似列がないか。
- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` の存在、signature、`security_definer`、`search_path`、EXECUTE権限。
- session_tool相当の引数または戻り値を既存RPCが既に持っているか。
- detail/list系に相当するpublic functionが存在するか。
- `has_role(text)` / `is_admin()` / `is_session_gm(text)` の存在。
- `public.sessions` のRLS enabled状態とpolicy概要。
- session_tool相当のCHECK制約が既に存在しないか。

### session_tool列追加案
列名は `session_tool` を第一候補にする。日本語ラベルは「開催場所」だが、意味は物理的な場所ではなく、Tekey、ココフォリア、ユドナリウムリリィ、Discordボイスなどのセッションツール/開催環境とする。

初期列案:

- `session_tool text`
- NULL許容。
- 既存データには値を入れず、未設定として扱う。
- RPC側ではtrim後に空文字をNULLへ丸める。
- 表示時はNULLまたは空文字を `未定` へ丸める。
- 固定候補のCHECK制約は初期実装では入れない。

NULL許容を第一候補にする理由:

- 既存依頼書を一括補正しなくても追加できる。
- 現行依頼書の表示・編集・Discord同期へ段階的に反映できる。
- セッションツール名は表記揺れや新ツールが出やすく、初期から固定値制約を置くと運用に詰まりやすい。

空文字の扱い:

- DB列としてはNULLを正とする。
- フロント入力やRPC引数で空文字が来た場合は、RPC側でtrimしNULLへ丸める案を第一候補にする。
- UI、session-detail、Discord投稿ではNULL/空文字を `未定` と表示する。

文字数制限:

- 初期案では自由入力を優先する。
- apply draft作成時に、`length(session_tool) <= 80` 程度の軽い制約を入れるか再検討する。
- 固定候補制約ではなく、過度な長文や改行だけを避ける方向が安全。

### RPC変更方針
`session_tool` は依頼書の作成・更新・表示・Discord投稿本文生成で必要になるため、RPCと取得処理へ段階的に反映する。

作成RPC:

- `create_session_post(...)` に `p_session_tool text default null` を追加する候補。
- 既存の `p_end_at` と同様、末尾引数に追加する案を第一候補にする。
- ただしPostgREST RPCはdefault引数つきoverloadで曖昧化しやすいため、preflightで既存signatureを確認してから、旧signature drop/recreateまたは別RPC化を判断する。

更新RPC:

- `update_session_post(...)` に `p_session_tool text default null` を追加する候補。
- 既存編集保存と同じ権限判定、入力検証、戻り値最小化方針を維持する。
- `session_tool` の戻り値を含めるかは、フロント更新後の再描画要件に合わせて決める。

詳細/list取得:

- 既存がRLS付きの直接SELECTであれば、フロント取得列へ `session_tool` を追加する。
- detail/list RPCが存在する場合は、戻り値に `session_tool` を含める必要がある。
- raw user_id、email、token、内部ID、Discord投稿先実値は返さない既存方針を維持する。

削除RPC:

- `delete_session_post(text)` は物理削除専用であり、`session_tool` の引数追加は不要。
- 戻り値に `session_tool` を含める必要もない。

互換性:

- 既存フロントが現行RPC signatureを呼んでいるため、SQL applyとフロント実装の順序を分ける。
- 過去の `p_end_at` 対応では、overload曖昧化を避けるため旧signatureをdropし、新signatureを1本だけ残した。`session_tool` でも同じ方針が候補になる。
- apply draft作成時は、既存signature、EXECUTE権限、PostgREST RPC呼び出しの互換性を再レビューする。

### 次工程
次工程は以下に分ける。

1. M-14E-15C: ユーザー手元で `026_session_tool_preflight_select_only.sql` をSQL Editor実行。
2. M-14E-15D: preflight結果にもとづくDB/RPC apply draft作成。
3. M-14E-15E: apply前レビュー。
4. M-14E-15F: ユーザー手動SQL Editor適用。
5. M-14E-15G: 依頼書編集UIへ開催場所入力を追加。
6. M-14E-15H: session-detail表示とGM/admin管理配置調整。
7. M-14E-15I: Edge Function preview/実送信フォーマット変更。
8. M-14E-15J: `dry_run = true` QA。

この工程ではSQL draft作成とdocs整理のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15C session_tool preflight SQL実行結果
ユーザー手元で `docs/supabase/sql/026_session_tool_preflight_select_only.sql` をSupabase SQL Editorへ貼り付けて実行した。Codex側ではSQL Editorを実行していない。

初回実行では、SQL内の日本語説明文字列がPowerShell経由の貼り付けで文字化けし、520行目前後で構文エラーになった。原因はDB構造やRPCではなく、SQL draft内の説明用文字列リテラルが壊れたこと。対策として、preflight SQL内の説明文字列と結果ラベルをASCIIへ寄せ、ヘッダーにもASCII維持の注意を追加した。修正後の再実行ではSQL Editorに結果グリッドが表示された。

preflight結果の要約:

- `public.sessions` は存在し、依頼書相当の正本テーブル候補として妥当。
- `public.session_posts` は見つからず、現状では別の依頼書専用テーブルへ分かれていない。
- 既存core columnsは概ね確認できた。
- `public.sessions.session_tool` は存在しない。
- 類似候補の `play_location` / `venue` / `session_place` / `session_place_name` 等も見つからない。
- `session_tool` 関連CHECK制約は見つからない。
- `create_session_post(...)` / `update_session_post(...)` / `delete_session_post(text)` は存在する。
- `delete_session_post(text)` は完全削除用途のため、`session_tool` 追加対象ではない見込み。
- create/update RPCは、`session_tool` 追加後にsignature変更または別RPC化の検討が必要。
- default引数つきRPCのoverload曖昧化に注意が必要。
- 既存RPCは `security_definer` と明示的な `search_path` が設定済みに見える。
- `authenticated` 向けEXECUTE権限があり、`anon` / `public` は基本的に許可しない既存方針と整合する。
- `public.sessions` のRLSは有効で、policyは複数存在する。

判断:

- `session_tool` は新規列追加が必要な可能性が高い。
- `public.sessions` へ `session_tool text null` を追加し、空文字をRPC側でtrim後NULLへ丸め、表示時に `未定` へfallbackする案を第一候補として維持する。
- 初期実装ではCHECK制約による固定候補化は行わず、自由入力を優先する。
- 次工程は、preflight結果にもとづくsession_tool追加用SQL apply draft作成とする。

この工程では結果記録とpreflight SQL draftのASCII説明文修正のみ行い、SQL apply、DB/RPC変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15D session_tool SQL apply draft作成
M-14E-15Cのpreflight結果にもとづき、`public.sessions` へ `session_tool` を追加するためのSQL apply draftを作成した。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

作成したdraft:

- `docs/supabase/sql/027_session_tool_apply_review_draft.sql`
- 冒頭に未実行draftであること、SQL Editorへ貼る前に別工程レビューが必須であること、このチャットでは実行しないことを明記した。
- コメントとレビュー用ラベルはASCII中心にし、貼り付け経路での文字化けリスクを下げる。

draft概要:

- `public.sessions` に `session_tool text null` を追加する。
- 既存データへ一括値設定は行わず、NULLを未設定の正規値として扱う。
- 初期実装では固定候補CHECK制約を追加しない。
- `create_session_post(...)` / `update_session_post(...)` へ最終引数として `p_session_tool text default null` を追加する案にした。
- RPC内では `nullif(btrim(p_session_tool), '')` 相当で空文字をNULLへ丸める。
- `session_tool` は改行不可、80文字上限の軽い入力制約をdraftに含めた。
- `delete_session_post(text)` は物理削除用途のため変更対象外とする。

RPC signature方針:

- PostgRESTのdefault引数つきRPC overload曖昧化を避けるため、既存signatureと新signature候補を明示的にdropしたうえで、新しい1本を作り直す案を第一候補にした。
- 既存の `security definer` と `set search_path = ''` 方針を維持する。
- `authenticated` へのEXECUTE付与を維持し、`public` / `anon` にはEXECUTEさせない。
- post-apply確認SELECTで列、signature、security/search_path、EXECUTE権限、RLS状態を確認する。

RLS / rollback注意:

- nullable text列追加だけならRLS policy自体は原則変更不要とする。
- rollbackで安易に `DROP COLUMN` すると保存済み `session_tool` が消えるため、実行用rollbackとして列削除は入れない。
- 適用前レビューで想定外のRPC overload、権限差分、RLS/policy影響、フロント更新順序の問題が見つかった場合はSQL Editor適用へ進まない。

次工程候補:

1. M-14E-15E: SQL apply draftレビュー。
2. M-14E-15F: ユーザー手元でSQL Editor適用。
3. M-14E-15G: SQL適用結果記録。
4. M-14E-15H: フロントUIへ `session_tool` 入力追加。
5. M-14E-15I: session-detail表示調整。
6. M-14E-15J: Edge Function Discord投稿フォーマット変更。
7. M-14E-15K: `dry_run = true` QA。

## M-14E-15E session_tool SQL apply draftレビュー
`docs/supabase/sql/027_session_tool_apply_review_draft.sql` をSQL Editor適用前の安全レビュー対象として確認した。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

レビュー結果:

- `public.sessions.session_tool text null` の列追加は既存データへの影響が小さい。固定候補CHECKは初期では入れず、自由入力を優先する方針を維持する。
- `DROP TABLE` / `DROP COLUMN` / `TRUNCATE` は実行文として含めない。
- `DROP FUNCTION` は `create_session_post` / `update_session_post` のsignature整理目的に限定し、対象signatureを明示する。`CASCADE` は使わない。
- apply用draftのため `ALTER TABLE` / `DROP FUNCTION` / `CREATE FUNCTION` / `GRANT` / `REVOKE` は含むが、SQL Editor実行は別工程まで行わない。
- `INSERT` / `UPDATE` はRPC本文内にのみ存在し、apply時に既存データを直接変更するDMLではない。
- RPC再作成と権限整理部分を明示トランザクションで包む方針へ修正した。

RPCレビュー:

- `create_session_post(...)` は最終引数 `p_session_tool text default null` を追加し、空文字をNULLへ丸める。
- `update_session_post(...)` は最終引数 `p_session_tool text default null` を追加する。
- updateでは `p_session_tool` 未指定時に既存値を保持し、空文字を渡した場合のみNULLへ丸めてクリアできる方針に修正した。
- create/updateとも、改行不可と80文字上限をRPC側バリデーションとして扱う。
- `delete_session_post(text)` は `session_tool` 追加対象外として維持する。

権限/RLS:

- 既存の `security definer` / `set search_path = ''` 方針を維持する。
- `authenticated` EXECUTEを維持し、`public` / `anon` にはEXECUTEさせない。
- nullable text列追加だけならRLS policy変更は不要と判断する。ただし適用後SELECTでRLS有効状態を確認する。

停止条件:

- SQL Editor実行前に必ず別工程でユーザー確認を挟む。
- draft内signatureとpreflight結果が合わない場合は停止する。
- 適用中にエラーが出た場合は再実行せず停止し、どこまで反映されたかを確認する。
- `DROP COLUMN session_tool` は保存済み値を消すため、安易なrollbackとして使わない。
- 適用後にRPCが見えない/呼べない場合は、signature、EXECUTE権限、PostgREST schema cache、RLS順に確認する。

適用後検証SQL方針:

- `session_tool` 列存在、型、NULL許容をSELECT-onlyで確認する。
- create/update/delete RPCのsignature、`security_definer`、`search_path` を確認する。
- authenticated/anon/publicのEXECUTE権限を確認する。
- `public.sessions` のRLS有効状態を確認する。
- 実データ行、ユーザーID、認証情報、外部投稿先実値は出さない。

## M-14E-15F session_tool SQL apply手動実行前最終確認
`docs/supabase/sql/027_session_tool_apply_review_draft.sql` をユーザー手元でSQL Editor適用する前の最終確認を整理した。この工程ではSQL Editor実行、DB/RPC実変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装は行わない。

貼るSQL範囲:

- SQL Editorに貼る対象は `docs/supabase/sql/027_session_tool_apply_review_draft.sql` 全体。
- ファイル冒頭に未実行draft、SQL Editorへ貼る前のレビュー必須、このチャットでは実行しない旨が明記されている。
- rollback方針はコメントだけで、実行される `DROP COLUMN` などは含めない。
- 古いSQL Editor内容を消してから、ファイル全体を貼る。
- SQL Editorが複数のSELECT結果を全部表示しない場合があるため、適用成功後に一部結果しか見えなくても再実行しない。M-14E-15Hで結果記録・追加確認へ進む。

実行前チェック:

- `git status --short` がclean。
- 最新commitが `fe7d5ef Review session tool apply draft`。
- `DROP TABLE` / `DROP COLUMN` / `TRUNCATE` / `CASCADE` が実行文としてない。
- `INSERT` / `UPDATE` はRPC本文内のみで、既存データを直接変更するstandalone DMLではない。
- `DROP FUNCTION` はcreate/update RPCのsignature明示に限定されている。
- `GRANT` / `REVOKE` は再作成後のcreate/update RPCに限定され、authenticated許可、anon/public不可の既存方針に沿う。
- SQL Editorへ貼る前に、貼り付け対象がこのファイル全体であることをユーザーが確認する。

停止条件:

- SQL Editorでエラーが出たら即停止し、同じSQLを再実行しない。
- permission denied、function does not exist、duplicate function、cannot drop functionなどが出たら停止する。
- 貼り付け内容にsecret、URL実値、認証情報、実データ行が混ざっていたら実行しない。
- SQL Editorに古いSQLや別SQLが残っていたら、消してから貼り直す。
- 途中成功/途中失敗の可能性があるため、エラー時は結果を一般化して記録し、次工程で確認する。

成功時確認項目:

- SQL Editor上でエラーが出ていない。
- `public.sessions.session_tool` が存在し、型は `text`、NULL許容。
- `create_session_post` / `update_session_post` のsignatureに `p_session_tool` が含まれる。
- `delete_session_post` は変更対象外。
- authenticatedにEXECUTEがあり、anon/publicに不要なEXECUTEがない。
- `public.sessions` のRLSが有効のまま。
- 実データ行、ユーザーID、メールアドレス、認証情報、外部投稿先実値は記録しない。

ユーザー手元コピー例:

```powershell
Get-Content -Raw -Encoding UTF8 .\docs\supabase\sql\027_session_tool_apply_review_draft.sql | Set-Clipboard
```

結果記録テンプレート:

- SQL Editor実行: 成功 / エラー
- エラー有無: なし / あり
- 表示された確認結果: column / rpc signature / execute grants / rls の要約のみ
- `session_tool` 列: ok / 要確認
- create/update RPC: ok / 要確認
- delete RPC: 変更なし / 要確認
- EXECUTE権限: ok / 要確認
- RLS: ok / 要確認
- 実データ行・内部ID・認証情報・外部投稿先実値: 記録していない
- 次工程へ進めるか: はい / いいえ

適用後にまだ行わないこと:

- すぐにフロント実装しない。
- すぐにEdge Functionを変更しない。
- すぐにDiscord実送信しない。
- dry-run確認へ進む前に、SQL適用結果をdocsへ記録する。

次工程候補:

1. M-14E-15G: ユーザー手元でSQL Editor実行。
2. M-14E-15H: SQL適用結果docs記録。
3. M-14E-15I: フロントUIへ `session_tool` 追加。
4. M-14E-15J: session-detail表示調整。
5. M-14E-15K: Edge Function Discord投稿フォーマット変更。
6. M-14E-15L: `dry_run = true` QA。

## M-14E-15H session_tool SQL適用結果記録
ユーザー手元で `docs/supabase/sql/027_session_tool_apply_review_draft.sql` 全体をSupabase SQL Editorへ貼り付け、手動実行した。Codex側ではSQL Editorを実行していない。

実行結果:

- SQL Editorはエラー表示ではなく結果グリッドを表示したため、M-14E-15GのSQL applyは成功扱いとする。
- 最後に見えていた結果グリッドはRLS確認で、`sessions_rls_enabled = true`、`sessions_force_rls = false`。
- SQL EditorのUI上、最後の結果グリッドのみ表示されている可能性がある。
- 同一apply SQLは再実行していない。今後も再実行しない。
- 実データ行、ユーザーID、メールアドレス、認証情報、外部投稿先実値は記録していない。

判断:

- `public.sessions` のRLSは有効なまま適用後確認できている。
- `session_tool` 列、create/update RPC signature、EXECUTE権限などの詳細確認は、必要なら次工程でSELECT-onlyの追加確認として行う。
- DB/RPC変更はユーザー手元SQL applyにより適用済みとして扱うが、このdocs記録工程ではDB/RPC追加変更を行わない。

次工程候補:

1. M-14E-15I: 必要なら `session_tool` 適用後SELECT-only確認。
2. M-14E-15J: フロントUIへ `session_tool` 追加。
3. M-14E-15K: session-detail表示調整。
4. M-14E-15L: Edge Function Discord投稿フォーマット変更。
5. M-14E-15M: `dry_run = true` QA。

この工程ではdocs記録のみ行い、SQL Editor再実行、追加SQL apply、DB/RPC追加変更、Edge Functionコード変更、deploy、Discord追加実送信、dry-run再実行、フロント実装、`updates.json` 変更、commit / pushは行わない。

## M-14E-15I/J/K session_tool UI・詳細表示・Discord投稿フォーマット実装
M-14E-15G/Hで適用済みの `session_tool` について、ユーザー手元のSELECT-only確認結果を記録し、フロントUI、session-detail表示、Edge Functionの投稿本文生成へ反映した。この工程ではSQL Editor再実行、DB/RPC追加変更、Edge Function deploy、Discord追加実送信、dry-run再実行は行わない。

SQL適用後SELECT-only確認結果:

- `public.sessions.session_tool exists`: ok。型は `text`、NULL許容。
- `create_session_post has session_tool argument`: ok。
- `update_session_post has session_tool argument`: ok。
- `delete_session_post unchanged presence`: ok。
- `public.sessions rls enabled`: ok。`rls=true, force_rls=false`。

フロント反映:

- 依頼書投稿/編集フォームに `開催場所` 入力を追加した。内部名は `session_tool`。
- 開催場所は物理会場ではなく、Tekey、ココフォリア、ユドナリウムリリィ、Discordボイスなどのセッションツール/開催環境を指す。
- 初期実装では自由入力とし、空欄はRPC側のtrim/NULL化に任せる。
- `create_session_post` / `update_session_post` のRPC payloadへ `p_session_tool` を渡す。
- session-postテンプレートJSONとmypageの依頼書用テンプレート編集UIにも `p_session_tool` を含めた。
- 既存依頼書編集時は、取得済み `session_tool` があればフォームへ反映し、未設定なら空欄にする。

session-detail表示:

- session-detailの基本情報へ `開催場所` を追加し、未設定時は `未定` と表示する。
- 参加者向け情報を上に置き、GM/admin管理操作は補足情報内の募集状態の下へ移動した。
- raw user_id、email、token、認証情報、外部投稿先実値、Discord message id相当の実値は画面へ出さない。

Discord投稿フォーマット:

- `dry_run = true` previewと `dry_run = false` 実送信は同じ本文生成処理を使う。
- 新本文は参加者向け依頼書形式へ変更した。
- 冒頭に `＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝` を置き、タイトル、GM、開催場所、日時、参加人数、参加締切、概要だけを出す。
- 下部区切り線、`詳細` 欄、サイト詳細URL、クエリ付き詳細導線は入れない。
- 日時はISO/UTC表記を避け、`MM/DD(曜) HH:mm　～　MM/DD(曜) HH:mm` の短い日本語向け形式に整形する。
- 募集人数は `2～5人` のように表示し、開催場所/申請締切/概要が未設定の場合は `未定` または概要未設定のfallbackを使う。
- Webhook URL、Discord投稿先実値、JWT、確認対象ID、project ref、Supabase URL全文、Discord message id相当の実値は本文・レスポンス・docsへ出さない方針を維持する。

次工程候補:

1. M-14E-15L: `dry_run = true` QAで新フォーマットpreviewを確認する。
2. M-14E-15M: テスト用チャンネルで新フォーマット実送信QAを行う。
3. M-14E-15N: DB更新連携、外部投稿識別子保存、二重投稿防止を設計する。
4. M-14E-15O: 本番募集チャンネル切り替え判断を行う。

## M-14E-15L/M deploy後 dry_run=true 新フォーマットpreview確認
`sync-session-post-to-discord` の `f76064f Add session tool UI and Discord post format` 版をdeploy済みの状態で、ユーザー手元により `create / dry_run = true` を再確認した。Codex側ではdry-run実行、追加deploy、Discord送信、SQL Editor実行、DB/RPC変更、フロント追加実装は行っていない。

前回のdeploy後確認ではHTTP 401が返っていたが、今回PowerShell待機方式でJWTを再取得し、確認対象IDも安全に再取得したうえで再確認したところHTTP 200で成功した。したがって前回のHTTP 401はJWT期限切れまたは無効化の可能性が高く、Edge Functionや新フォーマットの失敗とは判断しない。

認証文脈と確認対象:

- JWTはユーザー手元で再取得済み。JWT本体は記録していない。
- `TOKEN_CAPTURED = true`、`USER_JWT_SET = true`、`USER_JWT_PARTS = 3`、`USER_JWT_LOOKS_JWT = true`。
- 確認対象IDはユーザー手元で再取得済み。ID本体は記録していない。
- `SESSION_ID_CAPTURED = true`、`SESSION_ID_SET = true`、`SESSION_ID_LENGTH = 27`、`SESSION_ID_VALUE_OUTPUT = false`。

dry-run再確認結果:

- `USER_JWT_READY = true`、`SESSION_ID_READY = true`、`SUPABASE_URL_READY = true`。
- `DRY_RUN_EXECUTED = true`。
- requestは `action = create`、`dry_run = true`。
- `HTTP_ERROR = false`、`HTTP_STATUS = 200`。
- JSON parse成功。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返却あり。ただし本文全文は記録しない。
- previewは `PREVIEW_LENGTH = 125`、`PREVIEW_LINES = 9`。
- 冒頭区切り線あり。
- `詳細` URLなし。
- `詳細` ラベルなし。
- `開催場所` ラベルあり。
- ISO/UTC表記なし。
- `planned_db_update` あり。
- `warnings` あり。
- Discordテスト用チャンネルをユーザーが目視確認し、新規投稿が増えていないことを確認済み。

判断:

- deploy済み `sync-session-post-to-discord` は `dry_run = true` preview専用を維持している。
- 新Discord投稿フォーマットはpreviewへ反映されている。
- 投稿本文は、冒頭区切り線あり、開催場所ラベルあり、URL/詳細リンクなし、詳細ラベルなし、ISO/UTC表記なしの方針に沿っている。
- `dry_run = false` 実送信、追加Discord投稿、DB更新連携、外部投稿識別子保存、同期状態更新は未実施。

次工程候補:

1. M-14E-15N: UI手動QAを優先する。
2. 依頼書作成で開催場所を入力できることを確認する。
3. 依頼書編集で開催場所を変更できることを確認する。
4. 保存後session-detailに開催場所が表示されることを確認する。
5. 開催場所未入力時に `未定` 表示になることを確認する。
6. 募集人数min/maxの同一行UIが崩れていないことを確認する。
7. GM/admin管理ブロックの位置が参加者向け情報より目立ちすぎないことを確認する。
8. 必要なら、別工程で新しい検証用依頼書を使い、新フォーマットのテスト用チャンネル実送信を1回だけ行う。
9. 旧フォーマットで送信済みの既存検証用依頼書は、二重投稿防止のため再利用しない。
10. DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程に残す。

この工程ではdocs記録のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15N-FIX session_tool UI手動QAと空欄クリア修正
M-14E-15Nとして、ユーザー実ブラウザで `session_tool` / 開催場所UIの手動QAを行った。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信、dry-run実行、secret設定/切替を行っていない。

手動QAで確認できた項目:

- 新規依頼書作成で開催場所を入力して保存できた。
- session-detailに開催場所が表示された。
- 編集で開催場所を別値へ変更して保存できた。
- session-detailに変更後の開催場所が表示された。
- 募集人数min/max欄の見た目崩れなし。
- GM/admin管理ブロックは補足情報内の募集状態下、更新日時前に表示される。
- 管理ブロックは参加者向け基本情報の上部を邪魔していない。
- raw id、user_id、email、token等の画面露出なし。
- Discordテスト用チャンネルに新規投稿増加なし。

発見した不具合:

- 編集時、開催場所を空欄保存しても `未定` 表示にならず、前回入力値が保持された。
- 編集画面へ戻っても開催場所欄が空欄ではなく前回値になった。

原因:

- フロントの更新payloadで空欄が `nullableText(...)` により `null` へ変換されていた。
- SQL/RPC設計上、`update_session_post` は `p_session_tool is null` を「未指定」として扱い、既存値を保持する。
- 明示クリアするには空文字を渡し、RPC側でtrim後NULL化する必要があった。

修正:

- `assets/js/renderSessionPost.js` の `buildUpdatePayload()` で、更新時の `p_session_tool` を `getValue(form, "p_session_tool")` に変更した。
- 新規作成時は従来どおり空欄を `null` として扱う。
- 更新時は空欄を空文字として送るため、RPC側で明示クリアできる。
- DB/RPC変更なしで修正できると判断した。

修正後QA:

- 編集で開催場所を空欄保存した。
- session-detailで `未定` 表示になることをユーザー実ブラウザで確認済み。
- 再編集画面でも前回値保持問題は解消済みとして扱う。
- Discord投稿増加なし。
- `dry_run = false` は未実行。

次工程候補:

1. M-14E-15O: session_tool UI QA結果とFIXをcommit / pushする。
2. 必要なら、新しい検証用依頼書で新フォーマット実送信を1回だけ別工程として扱う。
3. 旧フォーマットで送信済みの既存検証用依頼書は、二重投稿防止のため再利用しない。
4. DB更新連携、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程に残す。

この工程ではdocs記録と既存フロント差分の静的確認のみ行い、SQL Editor再実行、DB/RPC追加変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-A 公開サイト反映後QAとDiscord新フォーマット実送信前安全レビュー
`73968eb Fix session tool clear handling` の修正がGitHub Pagesへ反映された後、ユーザー実ブラウザで再QAした。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信、dry-run実行、secret設定/切替を行っていない。

公開サイト反映後QA結果:

- 開催場所を空欄保存すると、session-detailで `未定` 表示になった。
- 再編集画面でも開催場所欄が空欄になった。
- Discord投稿増加なし。
- raw id、user_id、email、token等の画面露出なし。
- 以上により、`73968eb` の修正は公開サイトにも反映済みと判断する。

M-14E-15P安全レビュー:

- 次工程は、新しい検証用依頼書を使ったDiscord新フォーマット実送信1回確認とする。
- 既存 `TEST_1` は旧フォーマットで送信済みのため再利用しない。
- 今回のUI QA用依頼書も編集検証済みのため、実送信用には別の新規検証用依頼書を推奨する。
- 推奨タイトルは `M14E15P_discord_format_QA_01`。
- 初回実送信はテスト用チャンネルのみで行う。
- 本番募集チャンネル投稿は行わない。
- 実送信前に必ず `dry_run = true` preview確認を行う。
- 確認コマンドと送信コマンドは分離する。
- 対話プロンプト依存の送信手順は禁止する。
- `dry_run = false` はユーザー確認後、独立工程で1回のみ実行する。
- Discord投稿後も、DB更新連携、外部投稿識別子保存、同期状態更新はまだ未実装である点を明記する。
- 実送信確認後も、二重投稿防止、DB更新連携、`update` / `close` / `delete` / `resync` 対応は後続工程とする。

M-14E-15Pで確認すべきpreview項目:

- HTTP 200。
- JSON parse成功。
- `ok = true`。
- `dry_run = true`。
- `action = create`。
- `message_preview` あり。ただし本文全文は記録しない。
- 冒頭区切り線あり。
- 開催場所ラベルあり。
- 詳細URLなし。
- 詳細ラベルなし。
- ISO/UTC表記なし。
- Discord投稿増加なし。

実送信へ進む場合の停止条件:

- JWT、確認対象ID、Supabase URLの準備に失敗した場合。
- `dry_run = true` preview確認が通らない場合。
- previewにURL、詳細リンク、ISO/UTC表記が混入している場合。
- 対象が旧 `TEST_1`、または意図しない依頼書である場合。
- Discordテスト用チャンネルではない疑いがある場合。
- 既に投稿済みの対象を再利用している疑いがある場合。
- 少しでも不明なエラーが出た場合。

次工程候補:

1. M-14E-15P: 新しい検証用依頼書で `dry_run = true` preview確認。
2. M-14E-15Q: ユーザー確認後、テスト用チャンネルへ `create / dry_run = false` を1回だけ実送信。
3. M-14E-15R: 実送信結果docs記録。
4. M-14E-15S: DB更新連携、外部投稿識別子保存、二重投稿防止設計。

この工程ではdocs記録と安全レビューのみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = true` / `dry_run = false` 実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-B 新規検証用依頼書 dry_run=true preview確認結果
新しい検証用依頼書 `M14E15P_discord_format_QA_01` を作成し、deploy済み `sync-session-post-to-discord` で `create / dry_run = true` previewをユーザー手元で確認した。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord送信、dry-run実行、secret設定/切替を行っていない。

対象と事前準備:

- 対象依頼書は `M14E15P_discord_format_QA_01`。
- 旧 `TEST_1` は再利用していない。
- UI QA用依頼書も再利用していない。
- session-detailで開催場所表示OKを確認済み。
- Discord投稿増加なしを確認済み。
- PowerShell待機方式で対象IDを安全に取得した。ID本体は記録しない。
- `SESSION_ID_CAPTURED = true`、`SESSION_ID_SET = true`、`SESSION_ID_LENGTH = 27`。
- JWT再取得後、`USER_JWT_READY = true`、`SESSION_ID_READY = true`、`SUPABASE_URL_READY = true`。JWT本体とSupabase URL全文は記録しない。

dry-run preview確認結果:

- `DRY_RUN_EXECUTED = true`。
- requestは `action = create`、`dry_run = true`。
- `TARGET_SESSION_TITLE = M14E15P_discord_format_QA_01`。
- `HTTP_ERROR = false`、`HTTP_STATUS = 200`。
- JSON parse成功。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` 返却あり。ただし本文全文は記録しない。
- previewは145文字、9行。
- 冒頭区切り線あり。
- 詳細URLなし。
- 詳細ラベルなし。
- 開催場所ラベルあり。
- 対象タイトル一致。
- ISO/UTC表記なし。
- `planned_db_update` 返却あり。ただしdry-run上の予定情報であり、DB更新実行ではない。
- `warnings` 返却あり。
- Discordテスト用チャンネルをユーザーが目視確認し、新規投稿が増えていないことを確認済み。

判断:

- deploy済み `sync-session-post-to-discord` は `dry_run = true` preview専用を維持している。
- 新Discord投稿フォーマットpreviewは期待どおり反映されている。
- URL/詳細リンクなし、開催場所ラベルあり、対象タイトル一致、ISO/UTC表記なしを確認した。
- 次工程として `dry_run = false` 実送信1回確認へ進める前提は整った。
- ただし実送信は別工程とし、確認コマンドと送信コマンドを分離する。

次工程候補:

1. M-14E-15P-C: テスト用チャンネルへの `create / dry_run = false` 実送信1回確認。
2. M-14E-15P-D: 実送信結果docs記録。
3. DB更新連携、外部投稿識別子保存、二重投稿防止、action拡張、GM/admin同期UI、本番募集チャンネル切り替えは後続工程として維持する。

この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 実送信、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-15P-C テスト用チャンネル create dry_run=false 実送信1回確認結果
新しい検証用依頼書 `M14E15P_discord_format_QA_01` を対象に、ユーザー手元でテスト用チャンネル向け `create / dry_run = false` 実送信を1回だけ確認した。Codex側ではSQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替を行っていない。

対象:

- 対象依頼書は `M14E15P_discord_format_QA_01`。
- 旧 `TEST_1` は再利用していない。
- UI QA用依頼書も再利用していない。
- 実送信はテスト用チャンネル向けWebhook設定のまま実施した。
- Discord投稿先実値、Webhook URL、確認対象ID、JWT、project ref、Supabase URL全文は記録しない。

送信前確認:

- `USER_JWT_READY = true`。
- `SESSION_ID_READY = true`。
- `SUPABASE_URL_READY = true`。
- `TARGET_SESSION_TITLE_EXPECTED = M14E15P_discord_format_QA_01`。
- `REAL_SEND_NOT_EXECUTED = true`。
- `READY_FOR_MANUAL_CONFIRMATION = true`。
- 送信対象確認コマンドと送信コマンドは分離済み。

実送信結果:

- `REAL_SEND_REQUEST_ACTION = create`。
- `REAL_SEND_REQUEST_DRY_RUN = false`。
- `REAL_SEND_EXPECTED_TARGET = TEST_CHANNEL_CONFIGURED_WEBHOOK`。
- `DO_NOT_RERUN_THIS_COMMAND = true`。
- `REAL_SEND_EXECUTED = true`。
- `HTTP_ERROR = false`、`HTTP_STATUS = 200`。
- JSON parse成功。
- `RESPONSE_KEYS = ok,dry_run,action,sync_target,discord_send,db_update,warnings`。
- `ok = true`、`dry_run = false`、`action = create`。
- `discord_send` 返却あり。
- `db_update` 返却あり。ただしDB更新連携、外部投稿識別子保存、同期状態更新は後続工程として維持する。
- `warnings` 返却あり。
- `message_preview` は返却なし。
- 外部投稿識別子相当は存在検知されたが、実値は記録しない。
- `REAL_SEND_CHECK_COMPLETE = true`。
- この送信コマンドは再実行禁止とする。

Discord目視確認:

- Discordテスト用チャンネルに新規投稿が1件増えた。
- 投稿は「依頼書通知」アプリから送信された。
- 投稿タイトルは `M14E15P_discord_format_QA_01` 相当。
- 冒頭区切り線あり。
- GM表示あり。
- 開催場所表示あり。
- 日時は日本語短縮形式。
- 参加人数表示あり。
- 参加締切表示あり。
- 概要表示あり。
- 詳細URL/詳細リンクなし。
- ISO/UTC表記なし。
- message_preview本文全文、Discord message id実値、Discord投稿先実値は記録しない。
- 本番募集チャンネル投稿なし。

判断:

- 新Discord投稿フォーマットのテスト用チャンネル実送信は成功。
- `dry_run = true` previewと `dry_run = false` 実送信のフォーマット整合性は概ね確認できた。
- 実送信コマンドは再実行禁止。
- 今回の成功により、次はDB更新連携または二重投稿防止設計へ進む候補がある。
- 本番募集チャンネル切り替えはまだ行わない。
- DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `close` / `delete` / `resync`、本番募集チャンネル切り替えは後続工程として維持する。

この工程ではdocs記録と静的確認のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16A Discord同期DB更新連携・外部投稿識別子保存・二重投稿防止設計
M-14E-15P-Cでテスト用チャンネルへの新フォーマット実送信1回確認が成功したため、次工程としてDiscord投稿成功後のDB更新連携、外部投稿識別子保存、`create` 二重投稿防止を設計する。この工程では設計とSELECT-only preflight SQL draft作成のみを行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信は行わない。

目的:

- Discord投稿成功後に、依頼書DBへ外部投稿識別子相当と同期状態を保存する。
- 同じ依頼書への `action = create` 二重投稿を防止する。
- 将来の `update` / `close` / `delete` / `resync` の足場を作る。
- Discord実送信成功とDB更新失敗を分けて扱う。

保存候補カラム案:

- `discord_message_id`: 外部投稿識別子相当。`create` 二重投稿防止と将来の更新/削除の中心になる。
- `discord_channel_id`: 投稿先チャンネル識別子相当。単一チャンネル初期実装では必須でない可能性がある。
- `discord_sync_status`: 同期状態。
- `discord_last_action`: 最後に実行した同期アクション。
- `discord_synced_at` または `discord_last_synced_at`: 最後に同期成功した時刻。
- `discord_sync_error`: 一般化した同期エラー概要。生レスポンス全文や秘匿値は保存しない。
- `discord_sync_error_at`: エラー発生時刻候補。
- `discord_sync_attempted_at`: 最後に同期試行した時刻候補。
- `discord_webhook_kind` または `discord_target_kind`: テスト用/本番用や将来の投稿先分岐を扱う候補。

現時点では既存スキーマを変更せず、実カラム名と不足有無は `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` の手動実行結果を見て確定する。

状態設計案:

- 初期は過剰に複雑化せず、`synced` / `failed` / `not_synced` 相当を中心に整理する。
- 既存CHECK制約に `not_requested` / `pending` / `posted` / `failed` / `skipped` などがある場合は、既存値へマッピングする。
- `pending` は将来の非同期キューや再同期要求が必要になった場合に使う候補。
- `skipped` は非公開、下書き、対象外状態などで同期しない場合の候補。
- `unknown` は運用上扱いが曖昧になりやすいため、初期実装では安易に増やさない。

`create` 二重投稿防止案:

- 外部投稿識別子相当が既にある依頼書に対する `action = create` は拒否する。
- ユーザー向けレスポンスは一般化したエラーにし、外部投稿識別子実値は返さない。
- 将来は `update` または `resync` へ誘導する。
- DB更新連携と二重投稿防止が入るまで、本番募集チャンネル切り替えは行わない。

Discord成功後DB更新失敗時の扱い:

- Discord投稿は既に発生しているため、同じ `create` を再実行すると二重投稿リスクがある。
- レスポンスではDiscord送信成功とDB更新失敗を分けて返す。
- 外部投稿識別子実値はdocs、console、GitHub、チャットへ出さない。
- 後続で、手動照合、repair、resyncの方針を検討する。
- DB更新失敗時の `ok` を true / false どちらにするかは、実装前レビューで決める。利用者の安全を優先し、少なくとも「Discord送信済みだがDB更新未完了」を明確に返す。

Edge Function側の将来実装方針:

- `dry_run = true` ではDB更新しない。
- `dry_run = false` かつDiscord送信成功後のみDB更新する。
- DB更新成功後に `db_update` を成功扱いにする。
- DB更新失敗時はDiscord送信成功とDB更新失敗を分けて返す。
- Discord成功レスポンス全文は返さない。
- 外部投稿識別子実値はレスポンスに出すか慎重に扱う。少なくともdocs、console、GitHub、チャットへは出さない。

action拡張の足場:

- `create`: 未投稿なら新規投稿する。既存投稿識別子があれば拒否する。
- `update`: 既存投稿を編集する。
- `close`: 募集終了/締切反映へ更新する。
- `delete`: Discord投稿削除または削除済み扱いへ更新する。完全削除前の順序設計が必要。
- `resync`: DB状態とDiscord状態の再同期を行う。

本番チャンネル切り替えの停止条件:

- DB更新連携が未実装。
- 外部投稿識別子保存が未実装。
- `create` 二重投稿防止が未実装。
- 本番Webhook未設定/未切替。
- 本番初回実送信手順が未レビュー。
- 上記の間は本番募集チャンネルへ進まない。

SELECT-only preflight SQL draft:

- `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` を作成した。
- `public.sessions` のDiscord同期系カラム、類似カラム、CHECK制約、session posting RPC signature、関連function、helper、RLS、policy概要、EXECUTE権限を単一結果表で確認する。
- 出力列は `sort_order / section / check_name / expected / status / result_value / notes`。
- SQL内の説明文字列はASCII中心にし、文字化けや構文崩れを避ける。
- この工程ではSQL Editorで実行しない。

次工程候補:

1. M-14E-16B: ユーザー手元で `028_discord_sync_state_preflight_select_only.sql` をSQL Editor手動実行。
2. M-14E-16C: preflight結果docs記録。
3. M-14E-16D: DB更新連携/RPCまたはEdge Function内DB更新方針のapply draft設計。
4. M-14E-16E: `create` 二重投稿防止コード設計。
5. M-14E-16F: テスト用チャンネルでDB更新連携QA。

この工程ではdocs設計とSELECT-only preflight SQL draft作成のみ行い、SQL Editor実行、DB/RPC変更、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16C Discord同期DB状態 preflight 実行結果
ユーザー手元で `docs/supabase/sql/028_discord_sync_state_preflight_select_only.sql` をSupabase SQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行した。SQL Editorではエラーなしで結果グリッドが表示された。同じSQLの再実行はしていない。Codex側ではSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替を行っていない。

実行概要:

- `028_discord_sync_state_preflight_select_only.sql` をファイル全体で実行。
- SELECT-only preflightとして実行。
- エラーなし。
- 結果グリッド表示。
- 再実行なし。

public.sessions / 基本カラム:

- `public.sessions` は存在。
- 依頼書基本カラムは確認上OK。
- core column summaryは `15/15 present`。
- `session_tool` も存在確認済み。

Discord同期系カラム:

- `discord_message_id` 既存。
- `discord_channel_id` 既存。
- `discord_thread_id` 既存。
- `discord_post_url` 既存。
- `discord_sync_status` 既存。
- `discord_last_action` 既存。
- `discord_sync_requested_at` 既存。
- `discord_synced_at` 既存。
- `discord_sync_error` 既存。
- required sync column summaryは `4/4 present`。
- optional sync column summaryは `6/10 present`。
- `discord_last_synced_at` 候補は `discord_synced_at` 類似カラムとして扱えそう。
- `discord_sync_error_at`、`discord_sync_attempted_at`、`discord_webhook_kind`、`discord_target_kind` は未検出候補として扱う。

CHECK制約:

- `discord_sync_status` のCHECK制約あり。
- `discord_last_action` のCHECK制約あり。
- posting status / visibility のCHECK制約も確認上OK。
- 実装前に、許容値の正確な表現は既存制約に合わせる必要がある。

RPC / security / EXECUTE:

- `create_session_post` RPCあり。
- `update_session_post` RPCあり。
- `delete_session_post` RPCあり。
- 各RPCはsecurity definer確認上OK。
- search_path明示確認上OK。
- authenticatedは実行可能。
- anon / PUBLIC は実行不可。

sync関連function / helper:

- public function名にdiscord/sync/resyncを含むものは一部検出。
- sync専用helperは未検出。
- `has_role(text)`、`is_admin()`、`is_session_gm(text)`、`user_roles` は確認上OK。

RLS / policy:

- `sessions` RLS enabled。
- `user_roles` RLS enabled。
- policy概要が取得できた。
- 具体的なpolicy本文や実値は記録しない。

readiness:

- create double-post prevention readinessは、外部投稿識別子相当が存在するため設計上進められる見込み。
- sync state update readinessは、`discord_sync_status` / `discord_last_action` / `discord_synced_at` が存在するため設計上進められる見込み。
- Discord成功後DB更新失敗時の扱いはmanual review required。
- production channel switch gateはclosedのまま。
- 本番募集チャンネル切り替えはまだ行わない。

判断:

- 新規カラム追加なしでも、既存Discord同期系カラムを使ってDB更新連携を実装できる可能性が高い。
- ただし、既存CHECK制約の許容値を正確に確認してから実装する。
- 二重投稿防止は `discord_message_id` 等の既存外部投稿識別子を使う方針が有力。
- DB更新はEdge Functionから直接updateするか、専用RPCを追加するかを次工程で比較する。
- DB/RPC変更やEdge Function変更はまだ行わない。

次工程候補:

1. M-14E-16D: preflight結果に基づくDB更新連携実装設計。
2. DB更新をEdge Function内の安全なDB更新経路で行うか、専用RPCを追加するか比較する。
3. `create` 二重投稿防止をDB側、RPC側、Edge Function側のどこで担保するか決める。
4. CHECK制約の既存許容値に合わせた状態更新案を整理する。

この工程ではdocs記録と静的確認のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更、commit / pushは行わない。

## M-14E-16D/E DB更新連携実装設計とcreate二重投稿防止方針
M-14E-16Cのpreflight結果により、`public.sessions` にはDiscord同期に必要な主要カラムが既に揃っている可能性が高いと判断した。このため、M-14E-16D/E相当では新規カラム追加なしで進める案を第一候補として、DB更新連携、外部投稿識別子保存、`create` 二重投稿防止の実装設計を整理する。この工程ではdocs設計のみを行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信は行わない。

既存カラム前提のDB更新案:

- 外部投稿識別子の主軸は `discord_message_id` とする。
- `discord_channel_id` は投稿先チャンネル識別子相当として保存候補にする。ただし初期は単一テスト用チャンネル/単一本番チャンネル方針のため、必須度は `discord_message_id` より低い。
- `discord_thread_id` はスレッド運用を使う場合に保存候補とする。初期実装では未使用でもよい。
- `discord_post_url` は運用上の照合や将来の管理UIに有用だが、画面やdocsへ実値を出さない方針を維持する。
- `discord_sync_status` は同期状態を保存する。
- `discord_last_action` は最後の同期アクションを保存する。初期は `create` が中心。
- `discord_sync_requested_at` は同期要求/試行の開始時刻候補。初期実装で更新するかは、既存CHECK/運用方針に合わせて決める。
- `discord_synced_at` はDiscord送信成功後、DB更新も成功した時刻として扱う候補。
- `discord_sync_error` は一般化したエラー概要のみを保存する。Webhook URL、認証情報、外部投稿識別子実値、Discord API生レスポンス全文は保存しない。
- `dry_run = true` ではDB更新しない。
- `dry_run = false` かつDiscord送信成功後のみDB更新する。

CHECK制約の確認方針:

- `discord_sync_status` / `discord_last_action` は既存CHECK制約があるため、想定値だけで実装しない。
- 実装前に、M-14E-16Cのpreflight結果または追加SELECT-onlyで許容値の正確な表現を明確化する。
- 追加SELECT-only候補は、`pg_constraint` から `discord_sync_status` / `discord_last_action` の `pg_get_constraintdef(...)` を取得し、実値行を取らず制約定義だけ確認する形にする。
- CHECK値が既存の `posted` / `failed` / `not_requested` 等であれば、アプリ側の `synced` / `not_synced` 相当を既存値へマッピングする。
- CHECK値が不十分な場合でも、この工程ではSQL applyしない。必要ならSQL/RPC draft作成バッチで扱う。

DB更新経路比較:

| 案 | 内容 | 利点 | 欠点/リスク | 暫定評価 |
| --- | --- | --- | --- | --- |
| A案 | Edge Functionから `public.sessions` をサーバー側で直接update | RPC追加なしで実装が速い。既存カラムをすぐ使える。 | 権限境界と不変条件がEdge Function内に寄りやすい。二重投稿防止の原子性や監査性を設計しにくい。サーバー側権限とアプリ内admin権限を混同しない注意が必要。 | 初期検証には速いが、本番運用前の第一候補にはしない。 |
| B案 | Discord同期状態更新専用RPCを追加 | 二重投稿防止、状態遷移、権限、search_path、エラー一般化をDB側へ閉じ込めやすい。`discord_message_id is null` 条件などを原子的に扱いやすい。 | SQL/RPC applyゲートが必要。RPC設計・権限レビューが必要。 | 暫定第一候補。 |
| C案 | 既存 `update_session_post` にDiscord同期状態更新を混在 | 既存RPCを再利用できる。 | GM編集用RPCと同期状態更新が混ざり、権限・監査・UI編集との境界が曖昧になる。誤更新やsignature複雑化のリスクがある。 | 非推奨。 |

暫定結論:

- 専用RPC案を第一候補とする。
- Edge Function側でも送信前に `discord_message_id` 等を確認するが、最終的な二重投稿防止は可能ならDB/RPC側でも担保する。
- DB/RPC変更はSQL/RPC draft作成バッチとSQL Editor applyゲートに分ける。

`create` 二重投稿防止方針:

- `action = create` の場合、Discord送信前に対象依頼書の外部投稿識別子相当を確認する。
- `discord_message_id` 等が既に存在する場合はDiscord送信前に拒否する。
- 拒否時は一般化エラーを返し、外部投稿識別子実値をレスポンス、docs、consoleへ出さない。
- 将来は `update` または `resync` へ誘導する。
- DB/RPC側では、専用RPC内で `discord_message_id is null` を条件にした更新、または同等の原子的なチェックを検討する。
- Edge Function側だけのチェックは競合時に弱いため、本番切り替え前にはDB/RPC側の担保を優先する。

Discord成功後DB更新失敗時:

- Discord投稿は既に発生しているため、同じ `create` 再実行は禁止する。
- レスポンスでは `discord_send` 成功と `db_update` 失敗を分離する。
- top-level `ok` は、利用者に再実行させないための注意喚起を優先し、`false` として `error_code = discord_sent_db_update_failed` 相当を返す案を暫定推奨する。
- ただし `discord_send.ok = true` 相当を含め、Discord投稿済みであることは明確にする。
- `discord_sync_error` へは一般化エラーのみを保存する案を検討する。生レスポンス全文、Webhook URL、認証情報、外部投稿識別子実値は保存しない。
- 手動修復、repair、resync導線は後続工程で設計する。

次工程の大きめ再編:

1. 設計確定バッチ: CHECK許容値、DB更新経路、二重投稿防止、失敗時レスポンス、repair/resync方針を確定する。
2. SQL/RPC draft作成バッチ: 専用RPC案を第一候補に、必要なSQL/RPC draftとSELECT-only確認を作る。
3. SQL Editor applyゲート: ユーザー手元でSQL applyを実行する独立ゲート。
4. Edge Function実装バッチ: DB更新連携、二重投稿防止、一般化エラーを実装する。
5. deployゲート: Edge Function deployを独立ゲートで実行する。
6. まとめQAバッチ: `dry_run = true`、テスト用チャンネル実送信、二重投稿拒否、DB状態確認をまとめて行う。
7. 本番切替前レビューゲート: 本番Webhook/secret、初回投稿手順、停止条件を再確認する。
8. 本番切替ゲート: 本番募集チャンネルへの切り替えを独立ゲートで実施する。

本番募集チャンネル切り替え停止条件:

- DB更新連携が未完了。
- 外部投稿識別子保存が未完了。
- `create` 二重投稿防止が未完了。
- `update` / `resync` 方針が未整理。
- 本番Webhook/secret切り替えレビューが未完了。
- 本番初回投稿手順が未レビュー。
- 上記が残る間は本番募集チャンネルへ進まない。

この工程ではdocs設計のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、`dry_run = false` 再実行、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16F/G Discord同期DB更新連携 SQL/RPC draft作成バッチ
M-14E-16C/D/Eの設計を受け、既存Discord同期系カラムを前提に、CHECK許容値確認用のSELECT-only SQL draftと、専用RPC案のapply draftを作成した。この工程ではSQLファイルとdocsの整理のみを行い、SQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替は行わない。

作成したSQL draft:

- `docs/supabase/sql/029_discord_sync_check_values_select_only.sql`
  - `discord_sync_status` / `discord_last_action` の既存CHECK定義を正確に読むためのSELECT-only preflight。
  - Discord同期系カラムの型、NULL許容、default、関連CHECK制約、既存RPC signature、security/search_path、EXECUTE権限、RLS/policy概要を単一結果表で確認する。
  - 独立した変更系SQLを含めない。SQL Editor実行は次の独立ゲートで扱う。
- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql`
  - 専用RPC案の未実行apply draft。
  - 冒頭に `DO NOT RUN UNTIL REVIEWED` を明記し、029でCHECK許容値を確認してからレビューする前提にした。
  - 新規カラム追加は行わず、既存の `discord_message_id` / `discord_channel_id` / `discord_thread_id` / `discord_post_url` / `discord_sync_status` / `discord_last_action` / `discord_sync_requested_at` / `discord_synced_at` / `discord_sync_error` を使う案。

専用RPC draftの構成:

- `check_discord_session_post_create_ready(text)`
  - `action = create` の送信前guard候補。
  - GM本人またはadminのみ許可し、対象依頼書が存在しない場合、権限がない場合、外部投稿識別子相当が既に存在する場合は一般化エラーで拒否する。
  - DB更新は行わず、Discord送信も行わない。最終的な二重投稿防止は成功記録RPC側の条件更新でも担保する。
- `record_discord_session_post_create_success(text, text, text, text, text)`
  - Discord送信成功後にのみ呼ぶ成功記録RPC候補。
  - `discord_message_id` が未設定であることをDB側で再確認し、外部投稿識別子、投稿先相当、投稿URL相当、同期状態、最終action、同期成功時刻、同期エラークリアを更新する。
  - 戻り値には外部投稿識別子実値やURL実値を返さず、`has_external_post_identifier = true` のような最小限の状態だけ返す。
- `record_discord_session_post_create_failure(text, text)`
  - Discord送信失敗後に、一般化エラーのみを保存する候補。
  - 生レスポンス全文、Webhook URL、認証情報、外部投稿識別子実値は保存しない。

CHECK許容値に関する注意:

- 030 draftは、既存CHECKが `pending` / `posted` / `failed` と `create` を許可する前提の草案である。
- 029をSQL Editorで実行し、既存制約の正確な許容値を確認するまで030は実行しない。
- 既存CHECKが別表現の場合は、030をapply前に修正する。

二重投稿防止方針:

- Edge Function側では、送信前に `check_discord_session_post_create_ready` を呼ぶ。
- DB/RPC側では、成功記録時にも `discord_message_id` が未設定であることを条件にして更新する。
- 同時実行リスクは、送信前guardだけでは完全に消えないため、将来は予約状態更新またはより強いDB側排他の検討を残す。
- `discord_message_id` 等が既に存在する場合、`create` はDiscord送信前に拒否し、将来の `update` または `resync` へ誘導する。

Discord送信成功後にDB更新が失敗した場合:

- Discord投稿は既に発生しているため、同じ `create` 再実行は禁止する。
- Edge Functionレスポンスでは `discord_send` 成功と `db_update` 失敗を分離して返す。
- top-level `ok` は、利用者の再実行を避けるため `false` としつつ、Discord送信済みであることを明示する案を第一候補にする。
- 手動修復、repair、resync導線は後続工程で設計する。

Edge Function実装バッチでの処理順序:

1. request validation
2. user auth
3. target session fetch
4. `create` 二重投稿防止guard
5. message build
6. Discord send
7. DB sync success update
8. partial failure handling
9. sanitized response

`dry_run = true` はmessage previewまででDB更新なしを維持する。`dry_run = false` のみDB更新連携を試行する。レスポンス、docs、consoleには外部投稿識別子実値、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値、message preview本文全文を残さない。

次工程を大きめに再編:

1. CHECK確認SQL実行ゲート: 029をユーザー手元でSQL Editor実行し、CHECK許容値を記録する。
2. RPC applyレビューゲート: 029結果を踏まえて030を修正・レビューする。
3. RPC applyゲート: ユーザー手元でSQL Editor適用する。
4. Edge Function実装バッチ: 専用RPC呼び出し、DB更新連携、二重投稿防止、partial failure responseを実装する。
5. deployゲート: Edge Function deployを独立ゲートで扱う。
6. まとめQAバッチ: dry-run、テスト用チャンネル実送信、二重投稿拒否、DB状態確認をまとめて行う。
7. 本番切替前レビューゲート: 本番Webhook/secret切替、初回投稿手順、停止条件を確認する。
8. 本番切替ゲート: 本番募集チャンネル切替を独立ゲートで扱う。

## M-14E-16H 029実行結果記録と030 RPC apply draftレビュー
ユーザー手元で `docs/supabase/sql/029_discord_sync_check_values_select_only.sql` をSupabase SQL Editorへファイル全体貼り付けし、SELECT-only preflightとして1回だけ実行した。SQL Editorではエラーなしで結果グリッドが表示された。同じSQLの再実行はしていない。この工程でCodexはSQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替を行っていない。

029実行結果の要点:

- `public.sessions` は存在する。
- core column summaryは `15/15 present`。
- `session_tool` は存在する。
- Discord同期系カラムは `9/9 present`。
- 確認済みカラムは `discord_message_id`、`discord_channel_id`、`discord_thread_id`、`discord_post_url`、`discord_sync_status`、`discord_last_action`、`discord_sync_requested_at`、`discord_synced_at`、`discord_sync_error`。
- `discord_sync_status` は `text` / nullable YES / defaultあり。
- `discord_last_action` は `text` / nullable YES / default NULL。
- `sessions_discord_last_action_check`、`sessions_discord_sync_status_check`、`sessions_status_check`、`sessions_visibility_check` が確認できた。
- `create_session_post` / `update_session_post` / `delete_session_post` のRPC signatureを確認した。
- create/update/delete RPCは `security_definer` と `search_path` 明示が確認上OK。
- authenticatedはEXECUTE可能、anon / PUBLICはEXECUTE不可。
- `sessions` と `user_roles` はRLS enabled。
- `sessions` / `user_roles` のpolicy概要は取得できたが、具体的なpolicy本文や実値は記録しない。

CHECK許容値の扱い:

- 029結果ではCHECK制約名と関連カラムは確認できた。
- ただし結果表示の横幅都合により、CHECK許容値配列の全体は完全には読めていない。
- この時点では `discord_sync_status` / `discord_last_action` の正確な許容値は未確定として扱った。M-14E-16Iで確定結果を記録済み。
- `posted` / `failed` / `create` などの値を推測で確定扱いにしない。
- 030 apply draftを実行可能扱いにする前に、既存CHECK定義の完全な確認が必要。
- 必要なら追加SELECT-onlyで `pg_get_constraintdef(...)` の該当制約だけを読み、許容値を明確化する。ただしこの工程では新規SQL作成やSQL Editor実行は行わない。

030 apply draftレビュー結果:

- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` は専用RPC案のapply draftであり、未実行。
- 冒頭に `DO NOT RUN UNTIL REVIEWED` があり、SQL Editorへ貼る前にレビュー必須である。
- `CREATE OR REPLACE FUNCTION`、`REVOKE`、`GRANT`、関数内 `UPDATE` を含むため、SELECT-onlyではない。SQL applyゲートまで実行しない。
- 030には新規カラム追加はなく、既存Discord同期系カラムを使う案だけを記載している。
- 既存 `update_session_post` にDiscord同期責務を混ぜず、専用RPCへ分離する方針を維持する。
- `check_discord_session_post_create_ready(text)` は送信前guard候補。GM本人またはadminのみ許可し、既存外部投稿識別子がある場合は送信前に拒否する。
- `record_discord_session_post_create_success(text, text, text, text, text)` はDiscord送信成功後の成功記録候補。外部投稿識別子相当、投稿先相当、投稿URL相当、同期状態、最終action、同期成功時刻、同期エラークリアを扱う。
- `record_discord_session_post_create_failure(text, text)` はDiscord送信失敗時の一般化エラー記録候補。生レスポンス全文やsecret、外部投稿識別子実値は保存しない。
- この時点では030 draft内の状態値が既存CHECKと一致するか未確定だったためapply前TODOとして残した。M-14E-16Iで `posted` / `failed` / `create` がCHECK内であることを確認済み。

Edge Function実装計画の更新:

1. request validation。
2. user auth。
3. target session fetch。
4. `create` 二重投稿防止guard RPC。
5. message build。
6. Discord send。
7. success記録RPC。
8. failure記録RPCまたはpartial failure handling。
9. sanitized response。

`dry_run = true` ではDB更新しない。`dry_run = false` かつDiscord送信成功後のみsuccess記録RPCを呼ぶ。送信前guardで既存 `discord_message_id` 等が検出された場合はDiscord送信前に拒否する。DB更新失敗時は同じ `create` 再実行を禁止し、手動修復またはresync/repair導線を後続工程で設計する。レスポンス、docs、consoleには外部投稿識別子実値、投稿URL全文、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値、message preview本文全文を残さない。

次工程を大きめに再編:

1. RPC apply前レビューゲート: 030の状態値、権限、関数名、戻り値、停止条件をレビューし、CHECK許容値未確定なら追加SELECT-only確認を先に行う。
2. RPC applyゲート: ユーザー手元でSQL Editor適用する独立ゲート。
3. Edge Function実装バッチ: 専用RPC呼び出し、DB更新連携、二重投稿防止、partial failure responseを実装する。
4. deployゲート: Edge Function deployを独立ゲートで扱う。
5. まとめQAバッチ: `dry_run = true`、テスト用チャンネル実送信、二重投稿拒否、DB状態確認をまとめて行う。
6. 本番切替前レビューゲート: 本番Webhook/secret切替、初回投稿手順、停止条件を確認する。
7. 本番切替ゲート: 本番募集チャンネル切替を独立ゲートで扱う。

本番募集チャンネル切替は、DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `resync` 方針、本番Webhook/secret切替レビュー、本番初回投稿手順レビューが揃うまで停止する。

## M-14E-16I CHECK値確定結果と030 RPC apply draft整合レビュー
追加のCHECK値展開SELECT-onlyをユーザー手元で1回だけ実行し、SQL Editorではエラーなしで結果グリッドが表示された。同じSELECTは再実行していない。この工程でCodexはSQL Editor実行、DB/RPC変更、SQL apply、030 SQL実行、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替を行っていない。

CHECK値確定結果:

- `sessions_discord_last_action_check` の許容値は `close` / `create` / `delete` / `resync` / `update`。
- `sessions_discord_sync_status_check` の許容値は `failed` / `not_requested` / `pending` / `posted` / `skipped`。
- `discord_last_action` は `text` / nullable YES / default NULL。
- `discord_sync_status` は `text` / nullable NO / default `not_requested`。
- M-14E-16H時点の「CHECK許容値未確定」扱いは、この確認結果で更新する。
- 実値ID、投稿URL全文、外部投稿識別子実値、認証情報、実データ行は記録しない。

030 apply draft整合レビュー:

- `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` は引き続き未実行apply draft。
- 冒頭の `DO NOT RUN UNTIL REVIEWED` と、RPC apply review gate完了までSQL Editorへ貼らない方針を維持する。
- 030内の成功記録は `discord_sync_status = posted`、`discord_last_action = create` を使う。
- 030内の失敗記録は `discord_sync_status = failed`、`discord_last_action = create` を使う。
- いずれも確定済みCHECK許容値内であり、`synced` / `not_synced` などCHECK外の状態値は030内の実行ロジックに使わない。
- 初期/未送信状態は既存defaultの `not_requested` として扱い、030では明示初期化しない。
- `pending` は処理中・将来キュー化候補、`skipped` は同期対象外候補として残るが、今回のcreate成功/失敗RPCでは更新しない。
- 030のコメントを、CHECK値確定済みだがRPC apply前レビューまでは非実行、という表現へ更新した。
- 既存 `update_session_post` にDiscord同期責務を混ぜない方針を維持する。

RPC案の役割と安全性:

- `check_discord_session_post_create_ready(text)`
  - create送信前guardとして、ログイン済みGM本人またはadminのみを想定する。
  - 既存 `discord_message_id` 等がある場合はDiscord送信前に拒否し、二重投稿を抑止する。
  - DB更新は行わないため、最終的な同時実行対策はsuccess記録RPC側の条件更新でも担保する。
- `record_discord_session_post_create_success(text, text, text, text, text)`
  - Discord送信成功後に外部投稿識別子相当、投稿先相当、投稿URL相当、同期状態、最終action、同期成功時刻、同期エラークリアを保存する候補。
  - 戻り値は状態とboolean中心にし、外部投稿識別子実値やURL全文を返さない。
  - `discord_message_id is null` を条件にした更新により、DB側でも二重投稿防止を補強する。
- `record_discord_session_post_create_failure(text, text)`
  - Discord送信失敗時に一般化エラーだけを保存する候補。
  - 生レスポンス全文、Webhook URL、認証情報、外部投稿識別子実値は保存しない。
- 3RPCとも `security definer` / `set search_path = ''` を使い、既存依頼書RPCの流儀へ寄せる。
- EXECUTEはauthenticatedを想定し、anon / PUBLICには不要な権限を与えない。
- 同時実行でDiscord送信そのものが先に二重化するリスクは完全には消えないため、将来の予約状態更新またはより強いDB側排他をTODOとして残す。

Edge Function実装計画:

1. request validation。
2. user auth。
3. target session fetch。
4. create guard RPC。
5. message build。
6. Discord send。
7. success記録RPC。
8. failure記録RPCまたはpartial failure handling。
9. sanitized response。

`dry_run = true` ではDB更新なしを維持する。`dry_run = false` かつDiscord送信成功後のみsuccess記録RPCを呼ぶ。送信前guardで既存 `discord_message_id` 等がある場合はDiscord送信前に拒否する。DB更新失敗時は同じ `create` 再実行を禁止し、manual repair / resyncは後続工程へ分離する。レスポンスやconsoleに外部投稿識別子実値、投稿URL全文、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値、message preview本文全文を出さない。

次工程は大きめ単位で整理する:

1. RPC apply前レビューゲート。
2. RPC applyゲート。
3. Edge Function実装バッチ。
4. deployゲート。
5. まとめQAバッチ。
6. 本番切替前レビューゲート。
7. 本番切替ゲート。

本番切替はまだ行わない。DB更新連携、外部投稿識別子保存、二重投稿防止、`update` / `resync` 方針、secret切替レビュー、本番初回投稿手順が揃うまで停止する。

## M-14E-16J RPC apply前レビューゲート
`docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` をRPC apply前レビューゲートとして静的確認した。この工程ではSQL Editor実行、DB/RPC変更、SQL apply、030 SQL Editor貼り付け、Edge Functionコード変更、追加deploy、Discord追加実送信、secret設定/切替を行っていない。

実行禁止注記:

- 030冒頭には `DO NOT RUN UNTIL REVIEWED` が残っている。
- 030は未実行apply draftであり、ユーザーの明示確認なしにSQL Editorへ貼らない。
- 030には `CREATE OR REPLACE FUNCTION`、`REVOKE`、`GRANT`、関数内 `UPDATE` が含まれるため、SELECT-onlyではない。

RPCごとの役割確認:

- `check_discord_session_post_create_ready(text)`
  - create送信前guard。
  - GM本人またはadminを想定し、未ログイン、対象なし、権限なし、既存 `discord_message_id` ありをDiscord送信前に拒否する。
  - DB更新なし。送信前guardだけでは同時実行を完全には防げないため、success記録RPC側の条件更新でも補強する。
- `record_discord_session_post_create_success(text, text, text, text, text)`
  - Discord送信成功後にだけ呼ぶ成功記録RPC候補。
  - `discord_message_id`、投稿先相当、スレッド相当、投稿URL相当、`discord_sync_status = posted`、`discord_last_action = create`、`discord_synced_at`、`discord_sync_error = null` を更新する。
  - 既に `discord_message_id` がある場合は拒否し、戻り値には外部投稿識別子実値やURL全文を返さない。
- `record_discord_session_post_create_failure(text, text)`
  - Discord送信失敗時に一般化エラーだけを保存する候補。
  - `discord_sync_status = failed`、`discord_last_action = create` を使う。
  - 既存 `discord_message_id` がある行を `failed` に上書きしないよう、030 draft上で既存識別子チェックと条件更新を補強した。
  - 生レスポンス全文、Webhook URL、認証情報、外部投稿識別子実値は保存しない。

CHECK値整合:

- `discord_sync_status` で使う値は `posted` / `failed` のみで、確定済み許容値 `failed / not_requested / pending / posted / skipped` の範囲内。
- `discord_last_action` で使う値は `create` のみで、確定済み許容値 `close / create / delete / resync / update` の範囲内。
- 030内の実行ロジックにCHECK外の状態値やaction値は残っていない。
- `not_requested` は既存defaultとして扱い、030では明示初期化しない。
- `pending` と `skipped` は将来候補として残るが、今回のcreate成功/失敗RPCでは更新しない。

権限・安全境界:

- 3RPCとも `security definer` と `set search_path = ''` を使う。
- 権限判定は `auth.uid()`、`public.is_admin()`、`public.has_role('gm')`、対象依頼書のGM所有関係を使う。
- EXECUTEはauthenticatedに付与し、anon / PUBLICからはrevokeするdraftになっている。
- 既存 `update_session_post` にDiscord同期責務を混ぜない。
- 同時実行で複数リクエストが送信前guardを通過し、Discord送信が二重化するリスクは理論上残る。将来の予約状態更新、より強いDB側排他、またはEdge Function側の単発運用を後続TODOとする。

Discord送信成功後DB更新失敗時:

- Discord投稿は既に発生しているため、同じcreate再実行は禁止する。
- Edge Functionレスポンスでは `discord_send` 成功と `db_update` 失敗を分けて返す。
- top-level `ok` は再実行抑止を優先してfalse寄りに扱い、Discord送信済みであることを明示する案を維持する。
- 手動修復、repair、resyncは後続工程へ分離する。
- レスポンス、docs、consoleには外部投稿識別子実値、投稿URL全文、Webhook URL、JWT、確認対象ID実値、Discord投稿先実値、message preview本文全文を残さない。

apply後確認計画:

- RPC存在確認: `check_discord_session_post_create_ready`、`record_discord_session_post_create_success`、`record_discord_session_post_create_failure`。
- RPC signature確認。
- `security_definer` 確認。
- `search_path` 明示確認。
- EXECUTE権限確認: authenticated可、anon / PUBLIC不可。
- 既存 `create_session_post` / `update_session_post` / `delete_session_post` への影響なし確認。
- `public.sessions` のDiscord同期系カラムが想定どおり残っていること。
- RLS enabledが維持されていること。
- `updates.json` 差分なし確認。
- 実値ID、投稿URL全文、外部投稿識別子実値、認証情報、実データ行を結果記録へ出さない。

SQL applyゲートでの停止条件:

- 030内容が想定ファイルと一致しない。
- このレビュー結果と異なる変更が混ざっている。
- CHECK外のstatus/action値がある。
- secret、URL、ID実値、認証情報が混入している。
- SQL Editor貼り付け内容が途中で欠けている。
- SQL Editorでエラーが出る。
- Supabase側で予期しない警告や挙動が出る。
- 古いSQL Editor内容を消していない、または貼り付け範囲が不明。

このレビュー結果により、030は次のSQL applyゲートへ進める候補になった。ただしSQL applyは独立ゲートであり、ユーザーの明示確認なしには実行しない。

## M-14E-16K SQL apply結果記録とEdge Function DB更新連携実装バッチ
ユーザー手元のSQL applyゲートで `docs/supabase/sql/030_discord_sync_rpc_apply_draft.sql` をSQL Editor実行済み。SQL Editor画面上、対象RPC 3本の作成を確認した。この工程でCodexはSQL Editor再実行、DB/RPC追加変更、SQL apply再実行、Edge Function deploy、Discord追加実送信、本番投稿、secret設定/切替を行っていない。

SQL apply結果:

- `check_discord_session_post_create_ready(text)` 作成確認。
- `record_discord_session_post_create_failure(text, text)` 作成確認。
- `record_discord_session_post_create_success(text, text, text, text, text)` 作成確認。
- 確認画面では `security_definer = true`、`has_search_path = true` を確認。
- エラー表示なし。
- 同じapply SQLは再実行していない。
- EXECUTE権限の詳細行は確認画面に表示された範囲では未確認として扱う。後続の `dry_run = true` QAまたはSELECT-only確認で実動確認する。
- 030の再実行は禁止。

Edge Function実装内容:

- `sync-session-post-to-discord` にDB更新連携を追加した。
- `dry_run = true` は従来どおりpreview生成のみで、guard RPC、記録RPC、DB更新、Discord送信へ進まない。
- `dry_run = false` かつ `action = create` の場合だけ、Discord送信前に `check_discord_session_post_create_ready` を呼ぶ。
- guardが拒否した場合はDiscord送信前に停止し、一般化エラーを返す。
- Discord送信成功後に `record_discord_session_post_create_success` を呼び、外部投稿識別子相当と同期状態をDBへ記録する。
- Discord送信失敗時は、可能な範囲で `record_discord_session_post_create_failure` を呼び、一般化エラーのみを保存する。
- Discord送信成功後にsuccess記録RPCが失敗した場合はpartial failureとして扱い、同じcreate再実行を禁止する注意を返す。
- `dry_run = false` レスポンスではmessage preview本文全文を返さず、外部投稿識別子実値や投稿URL全文も返さない。
- `discord_send` / `db_update` / `warnings` の既存レスポンス構造は一般化情報として維持する。
- Webhook URL、認証情報、確認対象ID実値、外部投稿識別子実値、投稿URL全文、Discord投稿先実値、message preview本文全文をdocs、console、レスポンスへ出さない方針を維持する。

二重投稿防止:

- 送信前guard RPCで既存 `discord_message_id` がある場合はDiscord送信前に拒否する。
- success記録RPC側でも既存 `discord_message_id` がある場合は拒否するため、DB記録の二重化を抑止する。
- 同時実行で複数リクエストが送信前guardを通過してDiscord送信が二重化するリスクは理論上残る。予約状態更新、より強いDB側排他、または運用上の単発実行は後続TODOとして残す。

次の確認:

- Edge Function deployはまだ行わない。
- 次工程はdeployゲート前の静的確認またはdeployゲート。
- deploy後はまず `dry_run = true` を確認し、guard RPCやDB更新が呼ばれないことを確認する。
- その後、独立ゲートでテスト用チャンネル向け `dry_run = false` を1回だけ確認する候補。
- 本番募集チャンネル切替は、DB更新連携QA、二重投稿防止QA、update/resync方針、secret切替レビュー、本番初回投稿手順レビューが揃うまで停止。

## M-14E-16L DB更新連携版 deploy結果とpost-deploy dry_run=true確認
DB更新連携入りの `sync-session-post-to-discord` はユーザー手元でdeploy済み。deployは `npx.cmd` と別プロセス起動の手順で行い、Codex側ではEdge Function deployを実行していない。

deploy結果:

- `DEPLOY_EXECUTED = true`。
- `DEPLOY_EXIT_CODE = 0`。
- `DEPLOY_REPORTED_SUCCESS = true`。
- WARNING表示はあったが、認証問題を示すものではなく、deploy自体は成功扱い。
- project linkに関するヒントは表示された。
- deploy前後で `deno.lock` / `supabase/.temp` は生成物として掃除済み。
- deploy後の作業ツリーはclean。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は成功済み。

post-deploy `create` / `dry_run = true` 確認:

- JWTはユーザー手元で再取得し、docsには実値を記録しない。
- 確認対象は既存の検証用依頼書 `M14E15P_discord_format_QA_01`。
- requestは `action = create`、`dry_run = true`。
- `REAL_SEND_EXECUTED = false`、`DRY_RUN_EXECUTED = true`。
- HTTP 200、HTTP errorなし、JSON parse成功。
- レスポンスキーは `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings`。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` 返却あり。ただし本文全文は記録しない。
- `planned_db_update` と `warnings` 返却あり。ただしdry-run上の予定情報であり、DB更新実行ではない。
- previewは冒頭区切り線あり、詳細URLなし、詳細ラベルなし、開催場所ラベルあり、対象タイトルあり、ISO/UTC表記なし。
- Discordテスト用チャンネルへの新規投稿増加なし。

判断:

- DB更新連携入りEdge Functionはdeploy済み。
- `dry_run = true` はpreview専用を維持し、Discord投稿、DB更新、guard RPC、記録RPCへ進んでいない。
- 新Discord投稿フォーマットのpreviewは期待どおり。
- `dry_run = false` はまだ未実行。
- 次の危険工程は、DB更新連携込みの `dry_run = false` 実送信QA。
- 次回の実送信QAでは、既に投稿済みの `M14E15P_discord_format_QA_01` を再利用しない。新しい検証用依頼書を使う。
- 既に投稿済み対象の二重投稿防止実動確認は、Discord送信を伴う可能性があるため別ゲートとして扱う。

次のまとめQAバッチ案:

1. 新しい検証用依頼書を作成する。
2. deploy後 `dry_run = true` previewを確認する。
3. 独立ゲートで `dry_run = false` 実送信を1回だけ確認する。
4. DB同期状態が保存されたか、実値IDを出さずに確認する。
5. 同じ対象でcreate再実行が送信前に拒否されるか確認する。ただしDiscord送信リスクがあるため別ゲート化する。
6. Discord投稿増加数が想定どおりか確認する。

停止条件:

- JWT、確認対象、Supabase接続先の準備に不備がある。
- `dry_run = true` が通らない。
- previewにURL、詳細リンク、ISO/UTC表記が混入する。
- 対象依頼書が誤っている。
- 既に投稿済み対象を実送信用に使っている疑いがある。
- DB同期状態確認で実値IDを出す必要がありそうな場合。
- Discord投稿先がテスト用チャンネルであると確認できない。
- 本番募集チャンネル投稿の疑いがある。
- 少しでも不明なエラーが出た場合。

この工程ではdocs記録と静的確認のみ行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 実送信、Discord追加実送信、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16M 表示・導線・Discord本文追加改善
DB同期込み実送信QAへ進む前に、依頼書の表示、保存後導線、Discord本文をまとめて改善した。この工程ではフロント軽微修正とEdge Function本文生成修正、docs更新のみを行い、SQL Editor再実行、DB/RPC変更、SQL apply、Edge Function deploy、`dry_run = false` 実送信、Discord追加実送信、本番投稿、secret設定/切替は行わない。

Discord本文:

- `buildMessagePreview(...)` の依頼書本文から、概要本文直前の `概要` ラベル行を削除した。
- 概要本文そのものは削除せず、参加締切行の下に空行を挟んでユーザー入力本文が続く形にした。
- 依頼人、報酬、備考、タグ等は概要本文内にユーザーが書いた内容として扱う。
- Discord本文に詳細URL、詳細リンク、ISO/UTC表記は追加しない。
- `message_preview` 本文全文や外部投稿識別子実値はdocs/consoleへ出さない。
- この変更はEdge Functionコード変更のため、反映には別ゲートでEdge Function deployが必要。

保存後導線:

- 依頼書作成成功後、保存payloadが公開かつ非draftの場合は `session-detail.html?id=...` へ遷移する。
- 依頼書編集成功後も、対象が公開かつ非draftの場合は詳細画面へ遷移する。
- 非公開保存、下書き保存、結果から遷移先IDを安全に解決できない場合は既存画面内挙動を維持する。
- 遷移URLには既存の `session-detail.html?id=...` 構造を使う。
- raw user_id、email、token、認証情報は画面、docs、consoleへ出さない。

概要表示:

- session-detail / calendar modal向けの概要表示から見出し `概要` を削除した。
- 概要本文はHTMLとして解釈せず、既存のescape処理を維持する。
- 概要本文に `white-space: pre-wrap` を適用し、保存済みの改行と空行を自然に保持する。
- 長い行は既存の折り返し指定を維持する。

次工程:

1. フロント側はcommit/push後、GitHub Pages反映を待って作成/編集/詳細表示の手動QAを行う。
2. Edge Function側のDiscord本文変更は別ゲートでdeployする。
3. deploy後に `dry_run = true` previewで `概要` ラベルが消え、URL/詳細リンク/ISO/UTC表記が混入していないことを確認する。
4. DB同期込み `dry_run = false` 実送信QAは、上記の文面/表示/遷移改善確認後のさらに別ゲートで扱う。
5. 本番募集チャンネル切替は引き続き停止する。

## M-14E-16N DB sync real-send verification result
DB更新連携入り `sync-session-post-to-discord` のdeploy後、ユーザー手元で新しい検証用依頼書 `M14E16_sync_db_QA_01` に対して `create` / `dry_run = false` の実送信を1回だけ実施した。Codex側では SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、本番投稿、secret設定/切替を行っていない。同じ実送信コマンドは再実行禁止とする。

実送信結果:

- 対象は新しい検証用依頼書 `M14E16_sync_db_QA_01`。
- JWT、対象依頼書、Supabase接続先はユーザー手元で準備し、実値はdocsへ記録しない。
- requestは `action = create` / `dry_run = false`。
- HTTP 200、HTTP errorなし、JSON parse成功。
- response keysは `ok` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- `ok = true`、`dry_run = false`、`action = create`。
- `discord_send`、`db_update`、`warnings` が返却された。
- `db_update.success = true` 相当を確認済み。
- `message_preview` は返却されていない。
- Discord message id実値、post URL全文、Webhook URL、JWT、対象session id実値、Supabase URL全文は記録しない。

Discord目視確認:

- Discordテスト用チャンネルに新規投稿が1件増えた。
- 対象タイトルは `M14E16_sync_db_QA_01` 相当。
- 冒頭区切り線あり、開催場所あり、`概要` ラベルなし。
- 概要本文の改行が反映されている。
- 詳細URL/詳細リンクなし、ISO/UTC表記なし。
- 本番募集チャンネルへの投稿なし。

DB同期状態SELECT確認:

- 最初の確認SQLは列名誤りで失敗したが、SELECT確認のみでDB変更は発生していない。
- 修正版のSELECT確認では、対象タイトルで確認した。
- `target_found = true`。
- `discord_message_id` 相当は保存済み。
- `discord_channel_id` 相当は保存済み。
- `discord_post_url` 相当は未保存。
- `discord_sync_status = posted`。
- `discord_last_action = create`。
- `discord_synced_at` 相当は保存済み。
- `discord_sync_error` は空。

判断:

- 外部投稿識別子の主軸である `discord_message_id` と、投稿先識別子である `discord_channel_id` が保存されたため、DB同期成功として扱う。
- `discord_sync_status = posted`、`discord_last_action = create`、同期成功時刻あり、同期エラー空を確認できた。
- `discord_post_url` 未保存は現時点では非致命。管理UIの投稿リンク導線やrepair/resyncの補助情報として、後続課題に残す。
- 同一対象への `create` 再実行は二重投稿防止確認ゲートで扱う。`dry_run = false` を伴う可能性があるため、独立ゲートとする。

二重投稿防止確認ゲート案:

- 対象は投稿済みの `M14E16_sync_db_QA_01`。
- 目的は、同じ対象で `action = create` を再実行した際に、送信前guardで拒否され、Discord投稿が増えないことを確認すること。
- 実行前に、DB上で外部投稿識別子保存済みであることを実値を出さずに確認する。
- 実行後にDiscord投稿増加なしを確認する。
- responseやログには一般化エラーだけを記録し、Discord message id実値、post URL全文、session id実値、Webhook URL、JWTは記録しない。
- 同じコマンドを再実行しない。

二重投稿防止ゲート停止条件:

- 対象が `M14E16_sync_db_QA_01` ではない。
- DB上で外部投稿識別子保存済みを確認できていない。
- JWT、対象依頼書、Supabase接続先の準備に不備がある。
- Discord投稿先がテスト用チャンネルと確認できない。
- 本番募集チャンネル投稿の疑いがある。
- 不明なエラーが出る。
- 送信コマンドが確認コマンドと分離されていない。

後続課題:

- `discord_post_url` 保存の補強。
- 二重投稿防止の実動確認。
- `update` / `close` / `delete` / `resync` 方針整理。
- 管理UIでの同期状態表示。
- 本番切替前レビュー。
- 本番募集チャンネル切替ゲート。

## M-14E-16O Double-post guard verification result
DB同期込み実送信済みの検証用依頼書 `M14E16_sync_db_QA_01` に対して、ユーザー手元で `create` / `dry_run = false` を1回だけ実行し、二重投稿防止guardの実動を確認した。Codex側では SQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、Discord追加実送信、本番投稿、secret設定/切替を行っていない。同じ確認コマンドは再実行禁止とする。

確認結果:

- 対象は `M14E16_sync_db_QA_01`。
- requestは `action = create` / `dry_run = false`。
- 期待値は、既存投稿済み対象のためDiscord送信前に拒否すること。
- JWT、対象依頼書、Supabase接続先はユーザー手元で準備し、実値はdocsへ記録しない。
- HTTP 409、HTTP errorあり、JSON parse成功。
- response keysは `ok` / `error_code` / `message` / `dry_run` / `action` / `sync_target` / `discord_send` / `db_update` / `warnings`。
- `ok = false`、`dry_run = false`、`action = create`。
- `message_preview` は返却されていない。
- Discordテスト用チャンネルに新規投稿増加なし。
- 本番募集チャンネル投稿なし。

レスポンスキー解釈:

- `discord_send` と `db_update` はレスポンスキーとして存在した。
- ただし、今回の期待挙動はHTTP 409 / `ok = false` による送信前拒否である。
- したがって、`discord_send` / `db_update` のキー存在は実送信成功やDB更新成功を意味するものとして扱わない。
- 判定では、HTTP 409、`ok = false`、`message_preview` なし、Discord投稿増加なしを重視する。

判断:

- 既存投稿済み対象に対する `create` 再実行は送信前guardで拒否された。
- Discord投稿増加がなかったため、二重投稿防止の基本動作は確認済みとして扱う。
- Discord message id実値、post URL全文、Webhook URL、JWT、対象session id実値、Supabase URL全文、Discord投稿先実値は記録しない方針を維持した。
- 本番募集チャンネル切替はまだ行わない。

後続課題:

- `discord_post_url` 保存補強。
- `update` / `close` / `delete` / `resync` 方針整理。
- GM/admin同期状態表示UI。
- 失敗時repair/resync導線。
- 本番切替前レビュー。
- 本番初回投稿手順。
- 本番募集チャンネルsecret切替ゲート。

## M-14E-16P discord_post_url follow-up and production gates
`M14E16_sync_db_QA_01` のDB同期状態確認で `discord_post_url` 相当が未保存だったため、Edge Functionコードを確認した。Codex側では SQL Editor再実行、DB/RPC変更、SQL apply、Edge Function deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替を行っていない。

`discord_post_url` 未保存の原因:

- Discord Webhook送信後のsuccess記録RPCへ `p_discord_post_url` を渡す設計は既にあった。
- ただし、Edge Function側の送信結果生成で `postUrl` が常に `null` になっていた。
- そのため、Discord送信成功後に `discord_message_id` と `discord_channel_id` は保存されても、`discord_post_url` は保存されなかった。

コード補強:

- Webhook `wait = true` のレスポンスから、message id相当、channel id相当、guild/server id相当を取得する。
- 3つの値がDiscord snowflake相当の形式に見える場合だけ、DB保存用の投稿URL相当を組み立てる。
- guild/server id相当が返らない、または値形式が想定外の場合は、従来どおり `discord_post_url` は `null` のままにする。
- 組み立てたURL相当はsuccess記録RPCへ渡すだけで、レスポンス、docs、consoleへ全文やID実値を出さない。
- `dry_run = true` ではWebhook送信もDB更新も行わないため影響なし。
- Discord本文フォーマットは変更しない。

残る制約:

- Webhookレスポンスにguild/server id相当が含まれない場合、正しい投稿URL相当は組み立てない。
- 投稿URL相当の保存可否は、次回deploy後の `dry_run = true` 確認と、別ゲートのテスト用チャンネル実送信QA後のSELECT確認で判断する。
- `discord_post_url` 保存失敗は、外部投稿識別子保存と二重投稿防止の主目的とは切り離して扱う。

`update` / `resync` / `repair` 方針:

- `update`: 既存Discord投稿を編集する。`discord_message_id` 相当がある依頼書のみ対象にする。
- `resync`: DB上の同期状態とDiscord投稿を再同期するGM/admin向け手動操作候補。failedや確認が必要な状態からの復旧に使う。
- `repair`: Discord送信成功後DB更新失敗など、部分失敗状態を手動で補正する後続導線として設計する。
- `close`: 募集終了、締切、終了表示をDiscord投稿へ反映する。
- `delete`: Discord投稿削除、または削除済み/終了扱いへ更新する。完全削除前に外部投稿をどう扱うかは別レビュー。
- 初期段階ではcreate安定化を優先し、update/resync/repair/close/deleteは後続工程へ残す。

GM/admin同期状態表示UIの最小仕様:

- session-detailのGM/admin管理ブロック内に、Discord同期状態の小さな表示を追加する案を第一候補にする。
- 表示ラベル候補は、未同期、投稿済み、同期失敗、確認が必要。
- 生のDiscord message id、channel id、thread id、post URL全文は表示しない。
- `discord_post_url` が保存できるようになった場合も、リンク表示するかは別レビューにする。
- 失敗時は一般化エラーだけを表示する。
- resyncボタン、repairボタン、update/close/delete操作は後続。

本番切替前チェックリスト:

1. テスト用チャンネルでcreate実送信成功。
2. DB同期状態保存成功。
3. 二重投稿防止guard成功。
4. `discord_post_url` 未保存の扱いを了承、または保存補強をQA済み。
5. update/resync/repair方針がdocs化済み。
6. GM/admin向け同期状態表示の最低方針がある。
7. 本番secret切替手順レビュー済み。
8. 本番初回投稿手順レビュー済み。
9. 本番投稿前に `dry_run = true` 確認を行う。
10. 本番投稿は独立ゲートで1回だけ扱う。

本番募集チャンネル切替はまだ行わない。次工程は、Edge Function deployゲート、deploy後 `dry_run = true` 確認、テスト用チャンネルでのpost URL保存補強QA、またはGM/admin同期状態表示UI設計へ分ける。

## M-14E-16Q discord_post_url補強deploy結果とpost-deploy dry_run=true確認
`discord_post_url` 補強済みの `sync-session-post-to-discord` は、ユーザー手元で `9420c53` の状態としてdeploy済み。Codex側ではEdge Function deploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替を行っていない。

deploy結果:

- 対象commitは `9420c53` と確認済み。
- deploy前の作業ツリーはclean。
- deploy前の `deno check` は終了コード0。
- deployは実行され、終了コード0、成功表示あり。
- deploy時にWARNING表示はあったが、認証問題を示すものではない。
- project linkに関する表示は確認対象として扱う。
- deploy後の作業ツリーはclean。
- `deno.lock` / `supabase/.temp` は生成物として掃除済み。

post-deploy `dry_run = true` 確認:

- 対象は既存検証用依頼書 `M14E16_sync_db_QA_01`。
- JWT、対象session id、Supabase URL全文はユーザー手元だけで扱い、docsへ記録しない。
- requestは `action = create` / `dry_run = true`。
- `dry_run = false` は実行していない。
- HTTP 200、JSON parse成功。
- response keysは `ok` / `dry_run` / `action` / `sync_target` / `message_preview` / `planned_db_update` / `warnings`。
- `ok = true`、`dry_run = true`、`action = create`。
- `message_preview` は返ったが、本文全文は記録しない。
- `message_preview` には対象タイトル相当が含まれ、詳細URLなし、ISO/UTC表記なし。
- `概要` ラベル削除はEdge Function側previewにも反映済み。
- Discordテスト用チャンネルへの新規投稿増加なし。

判断:

- `9420c53` のEdge Function deployは成功扱いでよい。
- `dry_run = true` はpreview専用を維持している。
- `概要` ラベル削除はdeploy後のpreviewで確認済み。
- `discord_post_url` 補強はdeploy済みだが、保存成否は次のテスト用チャンネル実送信QAで確認する。
- 本番募集チャンネル切替はまだ行わない。

post URL保存補強QAゲート案:

1. 新しい検証用依頼書 `M14E16_post_url_QA_01` を作成する。既存の `M14E16_sync_db_QA_01` は投稿済みのため再利用しない。
2. 開催場所は `Tekey` などの一般的な検証値でよい。
3. session-detailで対象依頼書であることを確認する。
4. `dry_run = true` previewを確認し、詳細URL、ISO/UTC表記、`概要` ラベルが混入していないことを確認する。
5. 独立ゲートで `dry_run = false` 実送信を1回だけ行う。
6. Discordテスト用チャンネルに新規投稿が1件だけ増えたことを確認する。
7. SELECT-onlyでDB同期状態を確認し、`discord_post_url` 相当が保存されたかを見る。
8. `discord_post_url` 相当が保存されない場合は、guild/server id相当がWebhookレスポンスから得られない等の既知条件として後続課題化する。

post URL保存補強QAゲート停止条件:

- 対象が `M14E16_post_url_QA_01` ではない。
- JWT、対象session id、Supabase URLの準備に不備がある。
- `dry_run = true` が通らない。
- Discord本文に詳細URL、ISO/UTC表記、`概要` ラベルが混入している。
- Discord投稿先がテスト用チャンネルであると確認できない。
- 本番募集チャンネル投稿の疑いがある。
- DB確認で実値IDやURL全文を出す必要がありそうな場合。
- 不明なエラーが出た場合。
- 同じ `dry_run = false` コマンドを再実行しそうな場合。

後続課題:

- post URL保存補強QA。
- `update` / `close` / `delete` / `resync` / `repair` 実装。
- GM/admin同期状態表示UI。
- 本番切替前レビュー。
- 本番secret切替ゲート。
- 本番初回投稿ゲート。

この記録作業ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16R post URL保存補強QA結果と本番create前整理
`M14E16_post_url_QA_01` を使い、ユーザー手元でpost URL保存補強QAを実施した。Codex側ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替を行っていない。

QA実施概要:

- 対象は新規検証用依頼書 `M14E16_post_url_QA_01`。
- `dry_run = true` preview確認は成功済み。
- `dry_run = false` 実送信はユーザー手元で1回のみ実行済み。同じコマンドは再実行しない。
- Discordテスト用チャンネルに新規投稿が1件増えた。
- 投稿は対象タイトル相当、`概要` ラベルなし、概要本文改行保持、詳細URLなし、ISO/UTC表記なし。
- 本番募集チャンネル投稿なし。
- SQL EditorでSELECT-onlyのDB同期状態確認を実施済み。ただし、この記録工程ではSQL Editor再実行を行わない。

DB同期状態確認結果:

- `target_found`: ok / true。
- `discord_message_id_saved`: ok / true。
- `discord_channel_id_saved`: ok / true。
- `discord_thread_id_saved`: empty_or_not_used / false。
- `discord_post_url_saved`: missing / false。
- `discord_sync_status`: ok / posted。
- `discord_last_action`: ok / create。
- `discord_synced_at_present`: ok / true。
- `discord_sync_error_empty`: ok / empty。

判断:

- Discord投稿、外部投稿識別子保存、投稿先チャンネル識別子保存、同期状態保存、同期時刻保存、同期エラー空は成功。
- `discord_post_url` 相当の保存のみ未達。
- `discord_message_id` と `discord_channel_id` が保存されているため、二重投稿防止と同期状態管理の中核は成立している。
- `discord_post_url` 未保存は非致命の後続課題として扱う。
- 原因候補は、Webhook `wait = true` レスポンスからguild/server id相当を取得できず、正確なDiscord投稿URLを組み立てられなかったこと。
- 偽URLや不完全URLを保存しない現在の挙動は安全側。
- post URL保存を必須にする場合は、後続でguild id相当を安全な設定値として扱うか、別の取得手段を検討する。

本番create投稿に向けた到達済み項目:

- テスト用チャンネルで新フォーマットcreate投稿成功。
- `概要` ラベル削除反映済み。
- 概要本文改行保持確認済み。
- 詳細URLなし、ISO/UTC表記なし確認済み。
- DB同期状態 `posted` / `create` 保存確認済み。
- 外部投稿識別子相当保存確認済み。
- 二重投稿防止guard確認済み。
- 本番募集チャンネル投稿なし維持。

本番create投稿に向けた判断案:

- 最小本番投入では、message id相当、channel id相当、sync status、last action、synced atが保存されているため、`discord_post_url` 未保存はブロッカーにしない案を第一候補にする。
- ただし、運用利便性と管理UI導線のため、post URL補強は後続課題として残す。
- 本番投稿前には、本番切替前レビュー、本番Webhook secret切替ゲート、本番向け `dry_run = true` 確認、本番初回投稿ゲートを独立して扱う。

本番前残課題:

優先度高:

- 本番切替前レビュー。
- 本番Webhook secret切替ゲート。
- 本番向け `dry_run = true` 確認。
- 本番初回投稿ゲート。
- `discord_post_url` 未保存を許容するか、guild id設定で補強するかの判断。

優先度中:

- GM/admin同期状態表示UI。
- `update` / `resync` / `repair` 方針の詳細化。
- 投稿済み依頼書のresync導線。
- 失敗時一般化エラー表示。
- 本番投稿後のDB同期状態確認手順。

優先度低:

- post URLリンク表示。
- `close` / `delete` / `update` 実装。
- 同期履歴の表示。
- 詳細な監査ログ。

この記録作業ではSQL Editor再実行、DB/RPC変更、SQL apply、Edge Functionコード変更、追加deploy、`dry_run = false` 再実行、Discord追加投稿、本番投稿、secret設定/切替、`updates.json` 変更は行わない。

## M-14E-16S GM/admin Discord同期状態パネル最小実装
session-detailのGM/admin管理ブロック内に、Discord同期状態を確認するための最小UIを追加した。この工程ではフロント実装とdocs整理のみを行い、SQL Editor実行、DB/RPC変更、SQL apply、Edge Functionコード変更、Edge Function deploy、`dry_run = false` 実送信、Discord追加投稿、本番投稿、secret設定/切替は行わない。

実装内容:

- Supabase由来のsession取得で、Discord同期状態表示に必要な `discord_sync_status`、`discord_last_action`、`discord_synced_at`、`discord_sync_error`、`discord_post_url` を取得する。
- 表示用データでは、`discord_sync_error` は有無だけ、`discord_post_url` は保存有無だけに丸める。
- `discord_message_id`、`discord_channel_id`、`discord_thread_id`、post URL全文は画面やDOMへ出さない。
- session-detailの管理ブロック内に、`details` / `summary` による折りたたみパネルを追加する。
- 初期状態では非表示にし、GM本人またはadminとして管理権限が確認できた場合のみパネル内容を差し込んで表示する。
- 静的JSON由来、未ログイン、権限なし、権限確認失敗では同期状態パネルを表示しない。

表示ラベル:

- `discord_sync_status`: `not_requested` は未投稿、`pending` は処理中、`posted` は投稿済み、`failed` は同期失敗、`skipped` はスキップ、その他/nullは未確認。
- `discord_last_action`: `create` は新規投稿、`update` は更新、`close` は募集終了、`delete` は削除、`resync` は再同期、その他/nullはなし。
- 展開時は、同期状態、最終操作、最終同期日時、同期エラー有無、投稿リンク保存有無を表示する。
- `discord_sync_error` が空ならなし、値がある場合も本文をそのまま出さず、同期エラーありとして一般化表示する。
- `discord_post_url` が保存されていてもURL全文リンクは表示せず、保存あり/保存なしだけを表示する。

後続に残すもの:

- post URL全文リンク表示。
- `resync` / `repair` / `update` / `close` / `delete` ボタン。
- 同期履歴表示。
- 本番切替前レビューと本番secret切替ゲート。

この工程では、raw user id、email、token、selected character id、application id、Discord message id実値、channel id実値、post URL全文、JWT、Supabase URL全文、Webhook URLを画面、DOM、docs、consoleへ出さない方針を維持する。

## M-14E-16T 本番切替前レビュー準備
最新commit `a41abd5 Add Discord sync status panel` の公開サイト反映後、GM/admin向けDiscord同期状態UIの軽量QAを実施済みとして記録する。この工程ではdocs記録とレビュー準備のみを行い、SQL Editor実行、DB/RPC変更、SQL apply、Edge Function変更、Edge Function deploy、`dry_run = true` 実行、`dry_run = false` 実送信、Discord本番投稿、secret設定/切替は行わない。

GM/admin同期状態UI QA結果:

- session-detailのGM/admin管理ブロック内に、折りたたみ式の `Discord同期` パネルが表示される。
- GM本人またはadmin確認後だけ表示される。
- summaryは `Discord同期：投稿済み` 相当になる。
- 同期状態は投稿済みとして表示される。
- 最終操作は新規投稿として表示される。
- 最終同期日時が表示される。
- 同期エラーはなしとして表示される。
- 投稿リンク保存はなしとして表示される。
- Discord message id、channel id、thread id、post URL全文、raw session id、raw user id、email、token、selected character id、application idは表示されない。

本番切替前レビュー判断:

- post URL未保存は、本番create最小投入のブロッカーにしない案を第一候補にする。
- 理由は、message id相当、channel id相当、`posted` / `create`、同期時刻、同期エラー空、二重投稿防止が確認済みであるため。
- 偽URLや不完全URLを保存しない現在の挙動は安全側である。
- post URLリンク表示やguild id設定による補強は、運用利便性向上の後続課題として扱う。

本番Webhook secret切替ゲート:

1. 独立ゲートとして実施する。
2. secret実値はチャット、docs、GitHub、consoleへ出さない。
3. secret設定/切替はユーザー手元またはSupabase管理画面側で扱う。
4. 設定後も本番投稿は行わない。
5. 設定後は、次工程の本番向け `dry_run = true` 確認ゲートへ進む。

本番向け `dry_run = true` 確認ゲート:

1. 独立ゲートとして実施する。
2. 本番Webhook設定後に行う。
3. 対象依頼書、JWT、Supabase URLはユーザー手元だけで扱い、実値はdocsへ記録しない。
4. Discord投稿が増えないことを確認する。
5. message preview本文全文はdocsやチャットに貼らない。
6. previewに詳細URL、ISO/UTC表記、`概要` ラベルがないことを確認する。

本番初回投稿ゲート:

1. 独立ゲートとして実施する。
2. 本番向け `dry_run = true` 確認済みの依頼書だけを対象にする。
3. 確認コマンドと送信コマンドを分離する。
4. `dry_run = false` は1回だけ実行する。
5. 本番募集チャンネルに1件だけ投稿されることを確認する。
6. 投稿後、SELECT-onlyでDB同期状態を確認する。
7. GM/admin同期状態UIで投稿済み表示を確認する。
8. Discord message id、channel id、post URL全文、session id実値、JWT、Supabase URL全文は記録しない。

停止条件:

- gitがdirty。
- 最新commitが `a41abd5 Add Discord sync status panel` ではない。
- GM/admin同期状態UIが公開サイトへ反映されていない。
- テスト用create、DB同期、二重投稿防止の記録が確認できない。
- 本番Webhook secretが未準備。
- 本番投稿対象が未確定。
- 本番向け `dry_run = true` が未確認。
- 本番募集チャンネルをユーザーが目視確認していない。
- post URL未保存を許容しない判断になった。
- 不明なエラーがある。

本番切替は、secret切替ゲート、本番向け `dry_run = true` 確認ゲート、本番初回投稿ゲートを順に独立して扱う。今回のレビュー準備では危険工程を実行しない。

## M-14E-16U 本番Webhook secret切替結果
本番募集チャンネル向けWebhook secret切替は、ユーザー手元でSupabase Dashboardから実施済み。Codex側ではWebhook URL実値の確認、表示、再入力、再設定を行っていない。

記録内容:

- 設定対象secret名は既存の `DISCORD_SESSION_POST_WEBHOOK_URL`。
- 本番募集チャンネル向けWebhookへの切替はユーザー手元で実施済み。
- Webhook URL実値はチャット、docs、GitHub、consoleへ記録していない。
- Codex側ではsecret実値を扱っていない。
- `dry_run = true` は未実行。
- `dry_run = false` は未実行。
- Discord本番投稿なし。
- Edge Function deployなし。
- SQL Editor実行なし。
- DB/RPC変更なし。
- git状態はcleanのまま。

次工程:

- 本番向け `dry_run = true` 確認ゲートへ進む。
- 本番向け `dry_run = true` でもDiscord投稿が増えないことを確認する。
- message preview本文全文、JWT、対象session id、Supabase URL全文、Webhook URL、Discord message id、channel id、post URL全文は記録しない。

この記録工程では、secret設定/切替の再実行、`dry_run = true` 実行、`dry_run = false` 実送信、Discord投稿、Edge Function deploy、SQL Editor実行、DB/RPC変更、`updates.json` 変更は行わない。

## M-14E-16V 本番初回投稿まとめゲート結果
本番募集チャンネル向けWebhook secret切替後、指定タイトル `【連携確認】依頼書投稿テスト` を対象に、本番初回投稿まとめゲートを実施した。対象の実ID、JWT、Supabase URL全文、Discord message id、channel id、post URL全文、message preview本文全文は記録しない。

対象依頼書:

- 開始commitは `f2bd4d0 Record production Discord webhook switch`、作業開始時git状態はclean。
- 指定タイトルの既存公開依頼書は見つからなかったため、既存アプリ用RPC経由で依頼書を1件作成した。SQL Editor、直接insert、DBスキーマ変更、RPC定義変更は行っていない。
- 初回作成時に `open` は初期状態として拒否されたため、DB変更なしで停止し、既存仕様に合わせて `recruiting` の公開/非draft依頼書として作成した。
- 作成後、指定タイトルの対象が1件だけ存在し、公開済み、非draft、本番投稿対象として扱えることを確認した。

`dry_run = true` 確認:

- `create / dry_run = true` を1回だけ実行した。
- HTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`。
- response keysは `ok,dry_run,action,sync_target,message_preview,planned_db_update,warnings`。
- `message_preview` と `planned_db_update` は返ったが、本文全文は記録しない。
- warning countは0。
- Discord投稿なし、DB同期識別子保存なし、DB同期更新なし。
- 本番依頼書チャンネルに投稿が増えていないことをユーザーが目視確認し、その後 `dry_run = false` 1回実行を明示許可した。

`dry_run = false` 本番初回投稿:

- `create / dry_run = false` はユーザー許可後に1回だけ実行した。同じコマンドは再実行禁止。
- HTTP 200、JSON parse成功、`ok = true`、`dry_run = false`、`action = create`。
- response keysは `ok,dry_run,action,sync_target,discord_send,db_update,warnings`。
- `discord_send`、`db_update`、`warnings` は返った。`db_update.success = true` として扱える。
- warning countは0。
- `message_preview` は返っていない。
- Discord message id、channel id、post URL全文などの実値はレスポンス、docs、consoleへ出さない方針を維持した。

DB同期状態確認:

- 読み取り専用の状態確認で、対象の同期状態をboolean/status形式で確認した。SQL Editor再実行やDB/RPC定義変更は行っていない。
- `discord_message_id_saved = true`。
- `discord_channel_id_saved = true`。
- `discord_sync_status = posted`。
- `discord_last_action = create`。
- `discord_synced_at_present = true`。
- `discord_sync_error_empty = true`。
- `discord_post_url_saved = false`。これは既知の非致命制約として扱い、post URL補強またはリンク表示は後続課題に残す。

ユーザー目視確認項目:

- 本番依頼書チャンネルに投稿が1件だけ増えたこと。
- 投稿タイトルが対象タイトルと一致していること。
- `概要` ラベルがないこと。
- 概要本文の改行が保持されていること。
- 詳細URL/詳細リンクがないこと。
- ISO/UTC表記がないこと。

次工程:

- ユーザー目視結果を必要に応じてdocsへ追記する。
- GM/admin同期状態UIで本番対象が投稿済みとして見えることを確認する。
- `update` / `resync` / `repair` 方針と実装を後続で扱う。
- post URL未保存は本番create最小投入のブロッカーにしないが、運用利便性の後続課題として維持する。

この工程では、secret設定/切替、Webhook URL実値確認、Edge Function deploy、SQL Editor実行、DB/RPC定義変更、`dry_run = false` の複数回実行、Discord追加投稿、`updates.json` 変更は行わない。

## M-14E-17 Discord同期 update/delete/close/resync 大型実装準備
本番初回create投稿が成功し、DB同期状態も `posted` / `create` として保存されたため、次の同期拡張として `update` / `delete` / `close` / `resync` / `repair` のMVP方針を整理し、未実行SQL draftとEdge Function側の準備実装を行う。この工程ではSQL Editor実行、SQL apply、DB/RPC実変更、Edge Function deploy、`dry_run = true` 実行、`dry_run = false` 実行、Discord投稿/編集/削除、secret設定/切替は行わない。

本番初回create到達状態:

- 開始commitは `801c561 Record first production Discord post`、作業開始時git状態はclean。
- 本番create投稿は1回だけ成功済み。
- DB同期状態は、外部投稿識別子保存あり、投稿先チャンネル識別子保存あり、`discord_sync_status = posted`、`discord_last_action = create`、同期時刻あり、同期エラー空。
- `discord_post_url` 未保存は既知の非致命扱い。update/deleteのブロッカーにせず、message id相当とWebhook secretで既存投稿を扱う設計を優先する。
- 本番依頼書チャンネルの目視確認項目は、本番投稿1件、タイトル一致、`概要` ラベルなし、概要改行保持、詳細URLなし、ISO/UTCなし。未確認項目が残る場合は「目視確認待ち」として扱う。

update同期MVP:

- 対象は、既に `discord_message_id` 相当が保存されているSupabase由来依頼書。
- `action = update` は、既存Discord投稿本文を現在の依頼書内容で更新する。
- 既存投稿識別子がない場合、新規投稿を増やさず、一般化エラーまたは手動確認扱いにする。
- 成功時は `discord_sync_status = posted`、`discord_last_action = update`、`discord_synced_at` 更新、`discord_sync_error` クリアを記録する。
- 失敗時も依頼書保存自体は巻き戻さず、一般化エラーを保存する。Discord APIレスポンス全文、message id実値、channel id実値、post URL全文はレスポンスやconsoleへ出さない。

delete同期MVP:

- 投稿済み依頼書を削除する場合、Discord投稿削除を先に行い、その後に既存 `delete_session_post` RPCでDB削除する案を第一候補にする。
- Discord削除に失敗した場合はDB削除へ進めない。
- DB削除後は `sessions` 行が残らないため、現行MVPでは永続監査ログなしの制約を受け入れる。監査ログは後続課題。
- Discord削除成功後にDB削除が失敗した場合は、DB上の依頼書が残るため再削除可能。ただしDiscord側は削除済みのため、同じdelete再実行前に手動確認する。
- 既存投稿識別子がない依頼書は、既存削除導線でDB削除する候補として扱う。Edge Functionの初期実装では投稿済み対象の削除を優先する。

close / resync / repair:

- `close` は物理削除ではなく、募集終了/締切/開催終了をDiscord本文へ反映する更新扱いにする。`discord_last_action = close`。
- `resync` は、保存済み外部投稿識別子がある場合はupdate相当。外部投稿識別子がない場合のcreate再実行は二重投稿リスクがあるため手動確認必須。
- `repair` は、Discord送信成功後DB更新失敗などの部分失敗修復として後続導線に残す。

SQL/RPC draft:

- `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` を未実行apply draftとして追加した。
- draft冒頭に `DO NOT RUN UNTIL REVIEWED`、未実行、SQL Editor貼付禁止を明記した。
- 既存create専用RPCを壊さず、update/delete用RPCを追加する案を第一候補にした。
- 候補RPCは `check_discord_session_post_update_ready(text)`、`record_discord_session_post_update_success(text)`、`record_discord_session_post_update_failure(text, text)`、`check_discord_session_post_delete_ready(text)`、`record_discord_session_post_delete_failure(text, text)`。
- CHECK値は既存の `discord_last_action = close / create / delete / resync / update` と `discord_sync_status = failed / not_requested / pending / posted / skipped` に整合させた。

Edge Function準備実装:

- `sync-session-post-to-discord` に `action = update` と `action = delete` の `dry_run = false` 経路を追加した。ただしdeployは行わない。
- `dry_run = true` はpreview専用のまま維持し、Discord送信/編集/削除、DB更新、RPC記録を行わない。
- `update` は、update guard RPC、Webhook message PATCH、update success/failure RPCの順に進む設計。
- `delete` は、delete guard RPC、Webhook message DELETE、既存 `delete_session_post` RPCの順に進む設計。
- Webhook message URLはsecretから内部的に生成し、message id実値やURL全文はレスポンス、docs、consoleへ出さない。
- DB直書き込み `.insert()` / `.update()` / `.delete()` / `.upsert()` は追加せず、必要なDB操作はRPC経由にした。
- console出力は追加しない。
- 031のSQL/RPC applyが未実施の状態では、update/delete実送信経路はdeployしない。deploy前にSQL/RPC applyゲートとpost-apply確認が必須。

フロント導線:

- 編集保存後の自動Discord update反映は最終目標。ただしEdge Function update対応がdeployされるまで、フロントから自動呼び出しを有効化しない。
- 削除時は、投稿済みなら `action = delete` によるDiscord削除とDB削除オーケストレーションへ寄せる案を第一候補にする。未投稿なら既存削除RPCを使う。
- GM/admin同期パネルには、後続で手動 `Discordへ反映` / `Discord投稿削除` ボタンを置ける余地を残す。

次工程:

- 031 RPC apply前レビューゲート。
- 031 RPC applyゲート。
- Edge Function deploy前レビューゲート。
- Edge Function deployゲート。
- `dry_run = true` update/delete preview QAゲート。
- `dry_run = false` update/delete 実送信QAゲート。
- フロント自動同期導線実装バッチ。

今回の工程では、secret類、JWT、対象session id実値、project ref、Supabase URL全文、Webhook URL、Discord message id、channel id、post URL全文、message preview本文全文は記録しない。
## M-14E-17 SQL apply gate attempt result

`031_discord_update_delete_rpc_apply_draft.sql` のSQL applyゲートとして、Codex側で安全に実行できる既存経路を確認した。

事前確認:

- `git status --short` はclean。
- latest commitは `9cf71a4 Prepare Discord update delete sync`。
- apply対象はリポジトリ内の `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql`。
- 対象SQLには `DO NOT RUN`、`NOT EXECUTED`、`DO NOT PASTE` の誤爆防止注記が残っている。
- 対象SQLはupdate/delete用RPC追加draftであり、既存create用RPCを破壊しない方針。
- secret、Webhook URL、JWT、DB password、Direct connection string、実ID、URL全文らしき値は検出されなかった。
- `DROP TABLE`、`DROP COLUMN`、`TRUNCATE`、`CASCADE` の実行文は検出されなかった。

実行経路確認:

- Supabase CLIには `db query --linked --file` が存在する。
- ただし、この作業ツリーには `supabase/.temp` や `supabase/config.toml` がなく、linked projectを実値なしで確定できなかった。
- 関連環境変数名にもSupabase project / DB接続を安全に特定できるものは見つからなかった。
- 既存スクリプト内に、secretや接続文字列を表示せずに単体SQL applyできる安全なDB apply経路は見つからなかった。
- Chrome連携は対象プロファイルにCodex Chrome Extensionがなく、SQL EditorをCodex側で直接操作できなかった。

判断:

- 安全なSQL apply経路が確定しないため、停止条件に従ってSQL applyは未実行で停止した。
- `031` はSQL Editor、CLI、psql等いずれの経路でも実行していない。
- apply後SELECT-only確認は、apply未実行のため実施していない。
- Edge Function deploy、`dry_run = true`、`dry_run = false`、Discord投稿/編集/削除、secret設定/切替は行っていない。

次工程:

- 安全なapply経路を確定する。
- 候補は、ユーザー手元SQL Editorでの1回実行、またはproject linkを秘匿値なしで安全に確定できる公式CLI経路。
- apply成功後に、対象5RPCの存在、`security_definer`、`search_path`、EXECUTE権限、既存create用RPC維持、CHECK値整合をSELECT-onlyで確認する。

## M-14E-17 SQL apply成功結果

ユーザー手元で `docs/supabase/sql/031_discord_update_delete_rpc_apply_draft.sql` をSupabase SQL Editorへ貼り付け、1回だけ実行した。

実行結果:

- SQL Editor上でエラー表示はなかった。
- 同じSQLは再実行していない。
- update/delete同期用RPCとして、以下5本が結果グリッド上で確認できた。
  - `check_discord_session_post_delete_ready(text)`
  - `check_discord_session_post_update_ready(text)`
  - `record_discord_session_post_delete_failure(text, text)`
  - `record_discord_session_post_update_failure(text, text)`
  - `record_discord_session_post_update_success(text)`
- 表示されている範囲では、上記5本はいずれも `security_definer = true`、`has_search_path = true`。
- EXECUTE権限の詳細列はユーザー提供画像上では未確認。
- RPC本体、`security_definer`、`search_path` は確認済みとして扱う。
- EXECUTE権限の詳細は、Edge Function deploy後QAで実呼び出しにより確認する。
- 既存create用RPCを維持したまま、update/delete同期RPCのDB側準備が進んだと扱う。

未実施:

- Codex側でSQL Editor再実行、SQL apply再実行、DB/RPC追加変更は行っていない。
- Edge Function deploy、`dry_run = true`、`dry_run = false`、Discord投稿/編集/削除、secret設定/切替は行っていない。

次工程:

- Edge Function deployゲートへ進む。
- deploy後QAでは、update/delete用RPCの実呼び出し可否、EXECUTE権限、既存create同期への影響なしを確認する。

## M-14E-17 Edge Function deploy結果

`36cca94 Record Discord update delete RPC apply success` の状態から、update/delete対応準備済みの `sync-session-post-to-discord` をdeployした。

事前確認:

- `git status --short` はclean。
- latest commitは `36cca94 Record Discord update delete RPC apply success`。
- `deno check supabase/functions/sync-session-post-to-discord/index.ts` は成功。
- 通常PATHの `deno` が見つからないため、既存のローカルDeno実行ファイルを使用した。
- `deno.lock` は生成物として削除し、commit対象にしていない。
- deploy用project refはPowerShell環境変数で扱い、実値はdocs、GitHub、チャット、consoleへ記録していない。

deploy結果:

- `npx.cmd supabase functions deploy sync-session-post-to-discord --project-ref <PROJECT_REF>` を1回だけ実行した。
- deployは成功した。
- deploy時にDocker未起動WARNINGは出たが、deploy自体は成功扱い。
- `supabase/.temp` はCLI生成物として削除済みで、commit対象外。
- DB側update/delete RPC 5本はSQL Editorで適用済み。

未実施:

- `dry_run = true`、`dry_run = false` は未実行。
- Discord投稿、編集、削除は未実行。
- SQL Editor再実行、SQL apply再実行、DB/RPC追加変更は未実施。
- secret設定/切替、Webhook URL実値確認は未実施。

次工程:

- update/delete本番QAまとめゲートへ進む。
- deploy後QAでは、`dry_run = true` でpreviewとRPC実呼び出し可否を確認し、危険ゲートを分けてupdate/deleteの実動確認へ進む。
## M-14E-17 Discord同期ライフサイクルQA結果

`c3e95c8 Deploy Discord update delete sync` のdeploy済み `sync-session-post-to-discord` で、新しい使い捨てQA依頼書を作成し、create / update / delete の同期ライフサイクルを確認した。

実施概要:

- JWTはユーザー手元のクリップボードからPowerShell環境変数へ読み込み、実値は記録していない。
- QA依頼書は `M14E17_lifecycle_QA` prefix の新規使い捨て対象として作成した。対象session id実値は記録していない。
- `create / dry_run = true` はHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = create`、`message_preview` ありを確認した。本文全文は記録していない。
- `create / dry_run = false` は1回だけ実行し、HTTP 200、JSON parse成功、`ok = true`、`action = create`、`discord_send` あり、`db_update.success = true` を確認した。
- create後DB状態は、外部投稿識別子相当保存あり、channel識別子相当保存あり、`discord_sync_status = posted`、`discord_last_action = create`、`discord_synced_at` あり、`discord_sync_error` 空を確認した。`discord_post_url` は保存なしで、既知の非致命制約として扱う。
- QA依頼書を編集し、`update / dry_run = true` はHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = update`、`message_preview` ありを確認した。本文全文は記録していない。
- `update / dry_run = false` は1回だけ実行し、HTTP 200、JSON parse成功、`ok = true`、`action = update`、`discord_send` あり、`db_update.success = true` を確認した。
- update後DB状態は、外部投稿識別子相当保存あり、channel識別子相当保存あり、`discord_sync_status = posted`、`discord_last_action = update`、`discord_synced_at` あり、`discord_sync_error` 空を確認した。
- `delete / dry_run = true` はHTTP 200、JSON parse成功、`ok = true`、`dry_run = true`、`action = delete`、`message_preview` ありを確認した。本文全文は記録していない。
- `delete / dry_run = false` は1回だけ実行し、HTTP 200、JSON parse成功、`ok = true`、`action = delete`、`discord_send` あり、`db_update.success = true` を確認した。
- delete後DB確認では対象行が0件になり、QA依頼書のDB削除まで完了した。
- `dry_run = false` はcreate / update / delete 各actionで1回ずつのみ実行した。再実行はしていない。

安全確認:

- JWT、session id、project ref、Supabase URL全文、Webhook URL、Discord message id、channel id、thread id、post URL全文、message preview本文全文、raw user id、email、token、selected character id、application id はdocs / GitHub / consoleへ記録していない。
- Edge Function deploy、SQL Editor実行、SQL apply、DB/RPC定義変更、secret設定/切替は行っていない。
- 既存の残存QA依頼書がある場合は、必要に応じて後続のadmin cleanup候補として扱う。

判断:

- deploy済みEdge Functionから、create / update / delete のDiscord同期ライフサイクルが本番Webhook設定下で一通り成功した。
- update/delete用RPCのEXECUTE可否は、Edge Function経由の実呼び出し成功により実動確認できた。
- deleteはDiscord側削除後に既存 `delete_session_post` RPCでDB行を削除する現行MVPとして成立した。

後続候補:

- GM/admin UIからの手動update/delete同期導線を設計・実装する。
- close / resync / repair の運用方針と実装範囲を整理する。
- post URL保存補強またはリンク表示方針は引き続き後続課題として扱う。
## M-14E-18 Discord auto-sync frontend flow

`70a3cf0 Verify Discord sync lifecycle` の状態から、公開・非draft依頼書の作成/編集/削除に対して、フロント側から `sync-session-post-to-discord` を呼ぶ自動同期導線を実装した。

- 共通helper `assets/js/discordSyncClient.js` を追加し、`create` / `update` / `delete` の `dry_run = false` 呼び出しをフロントから扱う入口をまとめた。
- 作成時は、`create_session_post` 成功後、公開・非draftの場合のみ `action = create` 同期を試みる。下書き/非公開保存では同期しない。
- 編集時は、`update_session_post` 成功後、公開・非draftかつ既存Discord投稿識別子がある場合のみ `action = update` 同期を試みる。既存投稿がない対象に対してフロントが黙ってcreate同期を増やすことはしない。
- 削除時は、既存Discord投稿識別子がある場合のみ `action = delete` 同期を先に試み、失敗時はDB削除へ進まない。未投稿対象は従来どおり既存 `delete_session_post` RPCで削除する。
- 同期失敗時も、作成/編集保存自体は成功扱いを維持し、UIには一般化した警告だけを出す。削除同期失敗時は依頼書削除を止め、一般化したエラーを出す。
- レスポンス内のDiscord message id、channel id、thread id、post URL全文、message preview本文全文はDOM/console/docsへ出さない方針を維持する。
- `dry_run = true` / `dry_run = false` の実行、Discord投稿/編集/削除、Edge Function deploy、SQL Editor実行、DB/RPC変更、secret設定/切替はこの工程では行っていない。

次工程は公開サイト反映後のフロント手動QAバッチとする。確認項目は、新規公開依頼書作成後のcreate同期、投稿済み依頼書編集後のupdate同期、投稿済み依頼書削除時のdelete同期、未投稿依頼書の従来削除、一般参加者向け画面への実ID露出なし、GM/admin同期パネルの一般化表示である。既存の残骸QA依頼書は必要に応じてadmin cleanup候補として扱う。
## M-14E-18B Discord auto-sync browser QA preparation

`8754e5c Add Discord auto sync flow` の公開サイト反映後QAとして、公開配信ファイルとフロント導線を確認した。

公開サイト反映確認:

- `session-post.html` は `assets/js/main.js?v=20260606-discord-auto-sync` を読み込む状態になっている。
- `session-detail.html` も同じく `assets/js/main.js?v=20260606-discord-auto-sync` を読み込む状態になっている。
- 配信中の `renderSessionPost.js` と `renderSessionDetail.js` は `discordSyncClient.js?v=20260606-discord-auto-sync` を参照している。
- 配信中の `discordSyncClient.js` には `sync-session-post-to-discord` 呼び出しと `frontend_auto_create` / `frontend_auto_update` / `frontend_auto_delete` の導線が含まれている。

ブラウザQA実施可否:

- Chrome連携を試したが、Codex側からChrome extension backendへ接続できなかった。
- そのため、公開サイトUIをCodex側で直接操作する create / update / delete 自動同期QAは未実施。
- この工程ではQA用依頼書作成、Discord投稿/編集/削除、DB状態変更、Edge Function deploy、SQL Editor実行、secret設定/切替を行っていない。

静的レビュー結果:

- 作成導線は、`create_session_post` 成功後、公開・非draftの場合のみ `action = create` を呼ぶ。
- 編集導線は、`update_session_post` 成功後、公開・非draftかつ既存Discord投稿識別子がある場合のみ `action = update` を呼ぶ。
- 削除導線は、既存Discord投稿識別子がある場合だけ `action = delete` を先に呼び、失敗時はDB削除へ進まない。
- 未投稿対象の削除は従来の `delete_session_post` RPCに戻る。
- Discord message id、channel id、thread id、post URL全文、raw session idなどは表示用DOMへ出さない。

ユーザー手動QAチェックリスト:

1. 公開サイトUIで新しいQA依頼書を1件作成する。タイトル候補は `【連携確認】自動同期ブラウザQA`。公開・非draft、開催場所は未定、募集人数は1-4人。
2. 作成後に依頼書詳細へ遷移することを確認する。
3. 本番Discord依頼書チャンネルにQA投稿が1件だけ増えたことを目視確認する。
4. GM/adminのDiscord同期パネルで `投稿済み` / `新規投稿` 相当の表示が破綻していないことを確認する。実IDやURL全文が見えないことも確認する。
5. QA依頼書を編集し、タイトルを `【連携確認】自動同期ブラウザQA・編集確認済み` 相当に変更する。概要も編集確認用の本文へ変更する。
6. 編集保存後、既存Discord投稿が更新され、新規投稿が余分に増えないことを目視確認する。
7. GM/admin同期パネルで `投稿済み` / `更新` 相当の表示が破綻していないことを確認する。
8. QA依頼書を削除する。投稿済み対象なので、delete同期経由でDiscord投稿も削除されることを確認する。
9. 削除成功後、通常の依頼書一覧/詳細導線からQA依頼書が見えないこと、Discord側QA投稿が削除されていることを確認する。
10. 失敗した場合は再実行せず停止し、どの段階で失敗したかをboolean/status形式で記録する。

次工程:

- ユーザー手動で上記ブラウザQAを実施し、create / update / delete の結果をdocsへ記録する。
- QA後に残った使い捨て依頼書や過去QA残骸があればadmin cleanup候補として整理する。
## M-14E-18C Discord auto-sync manual browser QA result

公開サイト上で、使い捨てQA依頼書 `【連携確認】自動同期ブラウザQA` を使い、Discord自動同期ブラウザQAをユーザー手元で実施した。

確認結果:

- 公開・非draft依頼書の新規作成後、Discord依頼書チャンネルに投稿が1件増えた。
- 作成後、GM/admin向けDiscord同期パネルは投稿済み/新規投稿相当として表示され、破綻していなかった。
- QA依頼書を `【連携確認】自動同期ブラウザQA・編集確認済み` に編集後、Discord側の既存投稿が更新された。
- 編集時に余分な新規投稿は増えていない。
- QA依頼書削除後、Discord側のQA投稿も削除された。
- 削除後、公開サイト上でもQA依頼書は通常表示されない。
- Discord message id、channel id、post URL全文、JWT、session id、raw user_id、email、tokenなどの実値は記録していない。

判断:

- 公開サイトUIからの create / update / delete 自動同期導線は、使い捨てQA依頼書で一通り成功した。
- GM/admin同期状態パネルは、create後の投稿済み/新規投稿相当表示で破綻していない。
- update時に新規投稿が増えなかったため、既存投稿更新導線として期待どおり。
- delete時にDiscord投稿も削除され、公開サイト上の通常表示からも消えたため、投稿済み依頼書削除の自動同期導線として期待どおり。

次工程候補:

- 本番運用前の残課題整理を行う。
- close / resync / repair の方針と実装範囲を整理する。
- post URL保存補強またはリンク表示方針は引き続き後続課題として扱う。
- 残存QA依頼書があればadmin cleanup候補として整理する。

## M-14E-18D 運用前cleanup設計と削除不能原因調査

Status: 調査・設計完了。実削除は未実施。

公開サイトUIからのDiscord自動同期ブラウザQAは、create / update / delete まで成功済み。一方で、運用開始前に残ったテスト依頼書や古いDiscord投稿を整理するため、削除不能の想定原因とcleanup手順を整理した。

由来別の削除経路:

- Supabase由来、かつ本番Webhookで作成されたDiscord投稿識別子あり: 現行の削除導線で、Discord delete同期を先に行い、成功後に `delete_session_post` でDB行を削除する。
- Supabase由来、かつDiscord投稿識別子なし: Discord delete同期を行わず、既存 `delete_session_post` でDB行を削除する。
- Supabase由来、かつテスト用Webhook時代のDiscord投稿識別子あり: 現在の本番Webhookでは古い投稿を削除できない可能性がある。Discord delete失敗時にDB削除へ進まない現行挙動は安全側として維持する。
- `data/sessions.json` 由来の静的依頼書: DB行ではないためDB/RPC削除対象ではない。運用前退役対象として、静的fixtureを削るか残すかを別途判断する。
- Discord側にだけ残ってDBから追えない投稿: アプリから安全に対象特定できないため、Discord側の手動削除またはチャンネル整理対象にする。

コード上の確認結果:

- `sessionData.js` は静的行に `source: "static"`、Supabase行に `source: "supabase"` を付ける。
- `renderSessionDetail.js` はSupabase由来だけを編集/削除対象にし、静的JSON由来では削除ボタンを有効化しない。
- `discordSyncClient.js` はDiscord投稿識別子がある場合だけdelete同期を試みる。
- Edge Functionのdeleteは、現在設定されているWebhookでDiscordメッセージを削除し、その後にDB削除RPCへ進む。Discord削除に失敗した場合はDB削除を止める。
- `data/sessions.json` の静的fallbackは、Supabase行と同じidならSupabase行で上書きされるが、静的固有idは静的データを退役しない限り通常表示候補に残る。

削除不能の主な想定原因:

- 古いテスト用Webhook投稿を、本番Webhookで削除しようとしている。
- 静的JSON由来の予定をDB依頼書として削除しようとしている。
- Discord投稿識別子がない対象で、Discord delete同期を期待している。
- GM/admin権限やログイン状態が未確認。
- Discord delete失敗時にDB削除を止める安全設計が働いている。

今回の実装判断:

- 既存create/update/delete自動同期を壊すリスクを避けるため、コード変更は行わない。
- 本番Webhook由来のSupabase依頼書は、現行delete自動同期で削除できる状態を維持する。
- 未投稿Supabase依頼書は、既存DB削除RPCで削除できる状態を維持する。
- 静的JSON由来をDiscord delete同期へ送らない現行分岐を維持する。
- テストWebhook時代のDiscord残骸は、手動Discord cleanupまたは別途repair/resync設計で扱う。

運用前cleanup手順案:

1. `data/sessions.json` の旧モック/テスト予定を運用前に残すか退役するか決める。
2. Supabase上の残存テスト依頼書を、実IDを出さない形で一覧化し、未投稿 / 本番Webhook投稿済み / 旧テストWebhook投稿済み候補へ分類する。
3. 未投稿Supabase依頼書は、既存削除RPC導線でcleanupする。
4. 本番Webhook由来の投稿済みSupabase依頼書は、現行delete自動同期でDiscord投稿削除後にDB削除する。
5. テスト用Webhook時代のDiscord投稿は、Discord側で手動削除またはテストチャンネル整理対象にする。
6. Discord側だけに残っている投稿は、DBから追わずDiscord側で手動整理する。
7. cleanup後にcalendar / session-detail / mypage / session-post管理一覧 / GM-admin同期パネルを確認する。

cleanup停止条件:

- 対象の由来が分類できない。
- 本番Webhook由来かテストWebhook由来か判断できない。
- 静的JSON fixtureを退役してよいか未確定。
- SQL Editor実行、DB/RPC変更、Edge Function deploy、secret確認、実IDやURL全文の露出が必要になる。
- Discord削除失敗後に同じ破壊操作を再実行しそうになる。
- QA以外の本番運用依頼書に影響しそうになる。

次工程:

- cleanup inventoryゲート: 実IDや外部IDを出さない形で対象を分類する。
- 静的JSON退役レビュー: fixture用途が残るかを確認する。
- Supabase残骸cleanupゲート: ユーザー明示許可後に個別またはまとめて削除する。
- テストチャンネル/Discord-only残骸cleanupゲート: Discord側の手動整理として扱う。

この工程では、実際の大量削除、Discord投稿削除、SQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替、`updates.json` 変更は行っていない。
## M-14E-18E 運用前リセット実行準備

`6be75f4 Plan prelaunch session cleanup` の状態から、運用開始前に残存依頼書を安全に整理するための準備を行った。この工程では実削除、Discord投稿削除、SQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

静的調査結果:

- `sessionData.js` は静的JSON由来を `source: "static"`、Supabase由来を `source: "supabase"` として正規化する。
- `loadMergedSessions` は静的JSONとSupabase行をmergeする。Supabase行と同じidならSupabase行が優先されるが、静的JSON固有idは静的データとして表示候補に残る。
- `renderSessionDetail.js` はSupabase由来だけを編集/削除対象にし、静的JSON由来では通常の削除ボタンを有効化しない。
- 投稿済みSupabase依頼書は `hasDiscordPostReference` がtrueの場合、削除前にDiscord delete同期を試み、成功後にDB削除へ進む。
- 未投稿Supabase依頼書はDiscord delete同期を行わず、既存 `delete_session_post` RPCへ進む。
- テスト用Webhook時代に作られたDiscord投稿は、現在の本番Webhookでは削除できない可能性がある。この場合、現行delete同期はDB削除へ進まず停止するため安全側の挙動として扱う。
- `data/sessions.json` 由来はDB行ではないため、DB/RPC cleanupでは削除できない。運用前に静的fixtureとして残すか、退役/縮小するかを別ゲートで決める。

追加したSQL draft:

- `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql`
  - SELECT-onlyのinventory draft。
  - Supabase依頼書の件数、公開/下書き/非公開系、Discord同期状態、最終操作、外部投稿識別子保存有無、QA/test/連携確認らしきタイトル件数、cleanup候補分類を集計する。
  - 実ID、Discord ID、post URL全文、user id、email、token、secretは返さない。
  - 実削除は行わない。
- `docs/supabase/sql/033_prelaunch_session_cleanup_apply_draft.sql`
  - 実行禁止のcleanup手順draft。
  - SQL単体ではDiscord投稿を削除できないこと、DB削除対象とDiscord削除対象を混ぜないこと、静的JSON退役はDB cleanupではないことを明記した。
  - 実行可能な削除SQLは含めていない。

静的JSON退役方針:

- 今回はコード変更しない。理由は、既存create/update/delete自動同期を壊すリスクを避け、静的fixtureの用途有無を先に確認するため。
- 現行UIでは静的JSON由来は通常のSupabase編集/削除対象から外れているため、誤ってDiscord delete同期へ送らない境界は維持されている。
- 後続で退役する場合は、`data/sessions.json` の縮小、読み込み停止、またはGM/admin向けに「静的データ由来・運用前退役対象」と一般化表示する案を比較する。
- Supabaseでhidden/draft/canceledにした行が静的JSON fallbackで復活しないかは、inventory後にfixture退役方針と合わせて確認する。

運用前cleanup手順案:

1. `032_prelaunch_session_cleanup_inventory_select_only.sql` を別ゲートで実行し、実IDを出さず件数/分類だけ確認する。
2. 静的JSON fixtureを残すか退役するか決める。
3. Supabase上の未投稿テスト依頼書は、既存DB削除導線でcleanup候補にする。
4. 本番Webhook由来の投稿済みSupabase依頼書は、現行delete自動同期でDiscord投稿削除後にDB削除する。
5. テストWebhook時代の古い投稿は、Discord側の手動削除または別途repair/resync設計に分ける。
6. Discord側にだけ残る投稿はDBから追えないため、Discord側の手動整理対象にする。
7. cleanup後にcalendar / session-detail / mypage / session-post管理一覧 / GM-admin同期パネルを再確認する。

将来のadmin cleanup UI案:

- admin専用ページで、実IDを表示せず分類別件数と一般化状態を表示する。
- 個別削除と一括削除は強い確認文言を必須にする。
- 静的JSON由来はDB削除ボタンではなく、fixture退役対象として表示する。
- Discord-only残骸はアプリから削除せず、Discord側手動整理として表示する。

次工程:

- cleanup inventory SELECT-onlyゲート。
- 静的JSON退役レビュー。
- Supabase残骸cleanupゲート。
- テストチャンネル / Discord-only残骸の手動cleanupゲート。
## M-14E-18F 運用前cleanup inventory結果

ユーザー手元で `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql` をSQL Editorへ貼り付け、1回だけ実行した。エラー表示はなく、結果グリッドが表示された。再実行はしていない。この工程ではSELECT-only inventory結果の記録のみを行い、実削除、Discord投稿削除、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

inventory結果概要:

- Supabase session total: 23。
- QA/test/連携確認系タイトル候補: 22。
- manual confirmation required total: 22。
- production webhook posted Supabase candidate: 1。
- possible old test webhook or manual review candidate: 2。
- unposted Supabase DB delete candidate: 21。
- Discord外部投稿識別子保存あり: 2。
- Discord投稿先チャンネル識別子保存あり: 2。
- Discord thread識別子保存あり: 0。
- Discord post URL保存あり: 0。

同期状態/操作の概要:

- `discord_last_action`: null相当20、create 2、delete 1。
- `discord_sync_status`: failed 1、not_requested 9、pending 1、posted 1、skipped 11。
- visibility: hidden 13、private 1、public 10。
- status: canceled 3、closed 1、draft 7、finished 1、full 1、recruiting 9、tentative 1。

判断:

- Supabase上の依頼書23件のうち、ほとんどがQA/test/連携確認系候補として扱うべき状態。
- 21件は外部投稿識別子がないため、分類確認後はDB-only cleanup候補になり得る。
- 2件はDiscord外部投稿識別子があるため、Webhook由来、現行本番Webhookで削除可能か、または手動確認が必要。
- 本番Webhook由来として現行delete同期で削除できそうな候補は1件に見える。
- `discord_post_url` は0件のため、cleanup分類やリンク確認の判断材料には使わない。
- 静的JSON由来はこのSQL inventoryの対象外であり、別工程で退役/非表示化レビューが必要。

次工程方針:

- 静的JSON退役レビューとSupabase DB-only cleanupゲートを分ける。
- Supabase DB-only cleanupでは、外部投稿識別子なしの候補をさらに公開状態、status、QA/test候補で分類し、実削除はユーザー確認後の別ゲートにする。
- 外部投稿識別子ありの2件は、Discord側手動確認またはdelete同期可否レビューに分離する。
## M-14E-18G 静的JSON依頼書退役

`8de73ec Record prelaunch cleanup inventory` の状態から、運用開始前リセットの前段として `data/sessions.json` 由来の旧モック/静的依頼書が通常運用画面に残り続けないようにした。この工程ではSupabase DB行の実削除、Discord投稿削除、SQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

読み込み経路:

- `calendar.html` と `session-detail.html` は `main.js` 経由で `renderCalendar.js` / `renderSessionDetail.js` を読み込む。
- `renderCalendar.js` と `renderSessionDetail.js` は `loadMergedSessions()` を通じて依頼書一覧を取得する。
- 退役前の `loadMergedSessions()` は `data/sessions.json` とSupabase由来sessionをmergeしていた。
- `mypage.html` の申請一覧補助情報は、退役前は `mypageAuthClient.js` が `data/sessions.json` を直接fetchしていた。
- session-detailの管理導線はSupabase由来のみ編集/削除対象にし、静的JSON由来では通常削除ボタンを有効化しない。
- 静的JSON由来はDiscord同期対象にはならない設計だったが、通常表示に残ることで「消したはずの依頼書が見える」状態を作り得た。

採用した退役方針:

- `data/sessions.json` は削除せず、開発用fixtureとして残す。
- 通常運用では `data/sessions.json` を読み込まない。
- 明示的に `includeStaticSessions=1` または `staticSessions=1` をURLに付けた場合だけ、開発用fixtureとして静的JSONを読み込めるようにした。
- Supabase取得に失敗した場合でも、通常運用では静的JSONが自動復活しない。
- public siteの通常calendar/session-detailではSupabase由来を正本にする。

実装内容:

- `assets/js/sessionData.js`
  - `shouldIncludeStaticSessions()` を追加。
  - 通常時は静的JSONを読まず、Supabase由来sessionだけを返す。
  - 明示フラグ時だけ静的JSONをfixtureとしてmergeする。
- `assets/js/mypageAuthClient.js`
  - 申請一覧補助情報の取得元を `data/sessions.json` からSupabase `sessions` の公開行SELECTへ変更。
  - 表示に必要なタイトル、日時、GM名、状態、公開状態だけを扱う。
- `assets/js/renderCalendar.js` / `assets/js/renderSessionDetail.js` / `assets/js/main.js` / `calendar.html` / `session-detail.html` / `mypage.html`
  - cache-bustを更新し、公開サイトで静的JSON退役版を読み込むようにした。

判断:

- 通常calendar/session-detailでは静的JSON由来の旧モック依頼書は表示されない方針になった。
- session-detailの静的JSON管理UIは、明示fixture表示時だけ到達し得るが、通常削除/Discord同期対象にはならない。
- Supabase由来create/update/delete自動同期のコードは変更していない。
- `data/sessions.json` 自体は残るため、fixture用途の最終扱いは後続で確認する。

次工程:

- Supabase DB-only cleanupゲート。
- 外部投稿識別子あり2件のWebhook由来/手動確認ゲート。
- 旧テストWebhook / Discord-only残骸の手動整理ゲート。
## M-14E-18H Supabase DB-only cleanup実行準備

`147f5a5 Retire static session fallback` の状態から、運用開始前リセットの次段階として、Discord外部投稿識別子を持たないSupabase上のQA/test系依頼書を安全に削除できるよう、SELECT-only再確認SQLとguard付きapply draftを作成した。この工程では実削除、Discord投稿削除、SQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

既存削除RPC/依存関係の調査:

- 既存 `delete_session_post(text)` は、GM/adminのログイン文脈で1件の依頼書を物理削除するRPC。
- 同RPCは `auth.uid()` を使ってactorを確認するため、SQL Editor上の一括cleanupにはそのまま使いにくい。
- 過去のreviewed SQLでは、`session_applications.session_id` と `session_comments.session_id` は `public.sessions` へのON DELETE CASCADEで確認済みとして扱われている。
- DB-only cleanup対象はDiscord外部投稿識別子を持たないため、Discord delete同期は行わない。
- 直接DELETEは危険になり得るため、実行draftでは候補件数、外部識別子混入、非QA候補混入、FK CASCADE確認をすべてguardする。

追加したSQL draft:

- `docs/supabase/sql/034_prelaunch_db_only_cleanup_confirm_select_only.sql`
  - SELECT-onlyの再確認SQL。
  - DB-only cleanup候補件数、032参照値との一致、外部識別子混入なし、非QA候補混入なし、FK CASCADE確認、候補status/visibility/同期状態内訳を返す。
  - 実ID、Discord ID、post URL全文、user id、email、token、secret、row dataは返さない。
- `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql`
  - `DO NOT RUN` / `NOT EXECUTED` / `USER SQL EDITOR APPROVAL REQUIRED` のapply draft。
  - 034を直前に実行してレビューした後の独立applyゲートでのみ扱う。
  - 032時点の参照値は21件だが、実行時には034の最新件数を正として扱う。
  - 候補件数不一致、0件、外部識別子混入、非QA候補混入、FK CASCADE未確認の場合は削除せずエラーにする。

対象外:

- Discord外部識別子あり2件は、Webhook由来確認またはdelete同期/手動確認に分離する。
- 旧テストWebhook/Discord-only残骸は今回対象外。
- 静的JSON由来は通常運用から退役済みだが、DB-only cleanup対象ではない。

次工程:

- ユーザー手元SQL Editorで034を1回だけ実行し、件数とguard項目を確認する。
- 034結果が想定どおりの場合のみ、035を実行するかを別ゲートで判断する。
## M-14E-18I DB-only cleanup 034確認結果

ユーザー手元で `docs/supabase/sql/034_prelaunch_db_only_cleanup_confirm_select_only.sql` をSQL Editorへ貼り付け、1回だけ実行した。エラー表示はなく、結果グリッドが表示された。再実行はしていない。この工程ではSELECT-only確認結果の記録と035 draftの期待件数更新のみを行い、035実行、実削除、Discord投稿削除、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

034確認結果:

- DB-only cleanup candidate_count: 19。
- candidate_matches_032_reference: false。
- external_identifier_in_candidate_count: 0。
- non_qa_candidate_count: 0。
- excluded discord_identifier_rows: 2。
- excluded non_qa_rows: 1。
- FK check: `session_applications -> sessions cascade = true`、`session_comments -> sessions cascade = true`。

候補内訳:

- status: canceled 3、closed 1、draft 6、finished 1、full 1、recruiting 6、tentative 1。
- visibility: hidden 11、private 1、public 7。
- discord_sync_status: not_requested 8、pending 1、skipped 10。
- discord_last_action: null相当18、create 1。

判断:

- 032時点の参照値21件から現在19件へ変化しているため、21件固定の旧035 apply draftはそのまま実行しない。
- 外部識別子混入0、非QA候補混入0、FK CASCADE確認OKのため、現在の再確認結果としてはDB-only cleanup候補19件を次工程の対象候補として扱える。
- Discord外部識別子あり2件はDB-only cleanup対象外のまま、delete同期/手動確認ゲートへ分離する。
- 非QA系1件はcleanup対象外として扱う。
- `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql` は未実行のまま、期待件数を19件へ更新した。

次工程:

- 035 applyゲートを独立工程として扱う。
- 035実行前に、対象ファイルが19件前提であること、実行禁止注記が維持されていること、034結果と矛盾しないことを再確認する。

## M-14E-18J DB-only cleanup 035実行結果

ユーザー手元で `docs/supabase/sql/035_prelaunch_db_only_cleanup_apply_draft.sql` をSQL Editorへ貼り付け、1回だけ実行した。SQL Editor上でエラー表示はなく、再実行はしていない。この結果を、034で再確認したDB-only cleanup候補19件の削除成功として扱う。

記録した結果:

- 035 applyは1回のみ実行。
- エラー表示なし。
- 再実行なし。
- DB-only cleanup候補19件は削除成功扱い。
- 実ID、Discord message id、channel id、thread id、post URL全文、JWT、session_id、project ref、Supabase URL全文、Webhook URL、user_id、email、token、message preview本文全文は記録していない。

判断:

- 034時点で外部投稿識別子混入0、非QA候補混入0、FK CASCADE確認OKだったため、035のguard条件を満たしたcleanupとして扱う。
- 035実行後の追加SELECT-only件数確認は、この記録工程では行っていない。必要な場合は別工程で、実IDやURL全文を返さないSELECT-only確認により、DB-only cleanup候補0件、Supabase session total減少、Discord外部識別子あり2件の残存を確認する。
- 静的JSON由来の依頼書は通常運用画面から退役済みであり、今回のDB-only cleanupとは別系統として扱う。
- Discord投稿削除は未実施。外部識別子あり2件、旧テストWebhook/Discord-only残骸は別途判断する。

次工程候補:

- Discord識別子あり2件の扱い判断。
- テストチャンネル/Discord-only残骸の手動整理。
- 必要ならpost-cleanup SELECT-only確認ゲート。

## M-14E-18K DB-only cleanup後の再棚卸し結果

ユーザー手元で `docs/supabase/sql/032_prelaunch_session_cleanup_inventory_select_only.sql` をDB-only cleanup後の再棚卸しとしてSQL Editorへ貼り付け、1回だけ実行した。SQL Editor上でエラー表示はなく、結果グリッドが表示された。再実行はしていない。この工程では再棚卸し結果の記録と残り3件の方針整理のみを行い、追加削除、Discord投稿削除、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

post-cleanup inventory結果:

- Supabase session total: 3。
- manual_confirmation_required_total: 2。
- possible_old_test_webhook_or_manual_review_candidate: 2。
- production_webhook_posted_supabase_candidate: 1。
- unposted_supabase_db_delete_candidate: 1。
- Discord外部投稿識別子保存行: message id相当2、channel id相当2、thread id相当0、post URL 0。
- discord_last_action: null相当1、create 1、delete 1。
- discord_sync_status: failed 1、posted 1、skipped 1。
- sessions total_rows: 3、qa_like_title_rows: 2、draft_status_rows: 1、public_visibility_rows: 2、hidden_or_private_visibility_rows: 1。
- status_count: draft 1、recruiting 2。
- visibility_count: hidden 1、public 2。

判断:

- DB-only cleanup後、Supabase上の依頼書は3件まで減った。
- 残り3件のうち2件はDiscord外部識別子ありのため、Webhook由来確認または手動確認が必要。
- 残り3件のうち1件は未投稿DB-only候補だが、非QA候補の可能性があるため、即時一括削除ではなく最終reset対象として扱う。
- 本番Webhook由来delete同期で消せそうな候補は1件に見える。
- 旧テストWebhook由来またはDiscord-only残骸は、現在の本番Webhookでは削除できない可能性がある。
- `discord_post_url` は0件のため、残り3件のcleanup判断には使わない。
- 静的JSON由来は通常UIから退役済みであり、この再棚卸しとは別系統で扱う。

最終cleanup方針:

- 第一候補は、運用前にDiscordチャンネル側を手動整理したうえで、DBに残る3件を最終reset用のguard付きSQLで削除する案。
- 最終reset SQLは、実IDやDiscord IDを返さないSELECT-only再確認SQLと、件数・外部識別子有無・非対象混入をguardするapply draftに分ける。
- Discord外部識別子あり2件を自動delete同期で扱うか、Discord側手動整理後にDB resetとして扱うかは次工程で判断する。

次工程候補:

- 残り3件の最終reset用SELECT-only SQL作成。
- 残り3件のguard付きapply draft作成。
- テストチャンネル/Discord-only残骸の手動整理方針確認。

## M-14E-18L 残り3件最終reset SQL準備

`fe97b47 Record post-cleanup session inventory` の状態から、運用開始前に残り3件を最終resetできるよう、確認用SELECT-only SQLとguard付きapply draftを作成した。この工程では実削除、Discord投稿削除、SQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行っていない。

残り3件の扱い方針:

- 残り3件は運用前reset対象。
- DB行を削除してもDiscord投稿はSQLでは削除できない。
- Discord外部識別子あり2件については、DB削除前にDiscord側投稿の扱いを決める必要がある。
- 本番Webhook由来と思われる1件は、可能なら自動delete同期で消すのが第一候補。
- 旧テストWebhook由来またはDiscord-only残骸は、本番Webhookでは消せない可能性が高く、Discord側手動削除またはチャンネル整理候補。
- 本番切替前のテストチャンネル投稿や他残骸も、最終的にはDiscord側整理対象。
- 最終resetは、DBを空にするだけでなく、Discord側残骸整理とセットで扱う。

追加したSQL draft:

- `docs/supabase/sql/036_prelaunch_final_session_reset_confirm_select_only.sql`
  - SELECT-only / DO NOT DELETE / NO MUTATION。
  - 残りsessions totalが3件か、Discord外部識別子あり2件か、外部識別子なし1件かを集計で確認する。
  - public/hidden、status、discord_sync_status、discord_last_action、qa_like/non_qa、FK CASCADE readinessを返す。
  - 実ID、Discord ID、post URL全文、user id、email、token、secret、row dataは返さない。
- `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql`
  - DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED / DISCORD SIDE CLEANUP MUST BE DECIDED FIRST。
  - 036を直前に実行してレビューした後の独立applyゲートでのみ扱う。
  - Discord側整理判断フラグを初期値falseにしており、明示判断なしではエラーで停止する。
  - sessions残件数3、外部識別子あり2、外部識別子なし1、FK CASCADE OKをguardする。
  - DB削除はDiscord投稿削除ではないこと、旧テストWebhook投稿/Discord-only投稿はSQLでは消せないことを明記した。

Discord側cleanupチェックリスト:

- 本番依頼書チャンネル: 不要投稿を手動確認し、本番Webhook由来で自動deleteできるものは自動delete候補にする。
- DBから消した後は自動deleteできなくなるため、Discord外部識別子あり行は削除順序に注意する。
- テストチャンネル: 旧テストWebhook投稿は本番Webhookでは消せない可能性があるため、Discord側手動削除またはチャンネル整理候補にする。
- Discord-only残骸: DBから追跡できないものは手動整理候補にする。

最終reset推奨順:

1. 036 SELECT-only確認。
2. Discord外部識別子あり2件の扱い判断。
3. 本番Webhook由来のものは可能ならdelete同期。
4. 旧テストWebhook/Discord-only残骸はDiscord側で手動整理。
5. 037でDB残り3件を最終削除。
6. 032または036でDB sessions 0件確認。
7. calendar / session-detail / mypageで依頼書が表示されないことを確認。

次工程:

- ユーザー手元SQL Editorで036を1回だけ実行し、結果確認後にDiscord側整理/037実行可否を判断する。

## M-14E-18M 036 SELECT-only確認結果

ユーザー手元で `docs/supabase/sql/036_prelaunch_final_session_reset_confirm_select_only.sql` をSQL Editorへ貼り付け、1回だけ実行した。SQL Editor上でエラー表示はなく、結果グリッドが表示された。再実行はしていない。この工程では036確認結果の記録と037実行方針の明確化のみを行い、037実行、実削除、Discord投稿削除、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

036確認結果:

- remaining_session_count: 3。
- external_identifier_rows: 2。
- no_external_identifier_rows: 1。
- discord_side_cleanup_required: true。
- qa_like_title_rows: 2。
- non_qa_rows: 1。
- FK check: `session_applications -> sessions cascade = true`、`session_comments -> sessions cascade = true`。
- discord_last_action: null相当1、create 1、delete 1。
- discord_sync_status: failed 1、posted 1、skipped 1。
- status: draft 1、recruiting 2。
- visibility: hidden 1、public 2。

判断:

- 残り3件は運用前reset対象とする。
- Discord外部識別子あり2件について、SQLではDiscord投稿を削除できない。
- 旧テストWebhook由来またはDiscord-only残骸は、Discord側で手動整理する方針とする。
- DB最終resetを実行すると、DBからDiscord投稿を追跡できなくなる可能性がある。
- それでも運用前リセットとして、DB側は最終的に0件へ更地化する方針とする。

037 apply draft確認:

- `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql` は DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED / DISCORD SIDE CLEANUP MUST BE DECIDED FIRST を維持している。
- `v_discord_side_cleanup_decided` は初期値falseのまま。次の実行ゲートで、ユーザーがDiscord側cleanup判断済みとして明示許可した場合のみtrueへ変更して実行する設計とする。
- 037はまだ実行しない。

次工程:

- Discord側cleanup判断をユーザーが明示する。
- 037 final reset apply gateで、必要なら `v_discord_side_cleanup_decided` をtrueへ変更して1回だけ実行する。
- 実行後はSELECT-onlyでDB sessions 0件を確認し、calendar / session-detail / mypage表示を確認する。

## M-14E-18N 037 final reset実行結果

ユーザー手元で `docs/supabase/sql/037_prelaunch_final_session_reset_apply_draft.sql` をSQL Editorへ貼り付け、1回だけ実行した。実行前に、Discord側残骸は手動整理する方針で判断済みとして、`v_discord_side_cleanup_decided` をtrueへ変更した。SQL Editor上でエラー表示はなく、再実行はしていない。この工程では実行結果の記録のみを行い、追加削除、Discord投稿削除、SQL apply追加、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行わない。

037実行結果:

- 037 applyは1回のみ実行。
- `v_discord_side_cleanup_decided` をtrueにしたうえで実行。
- エラー表示なし。
- 再実行なし。
- deleted_count: 3。
- Supabase側の残り依頼書3件は、運用前final reset対象として削除成功扱い。
- 実ID、Discord message id、channel id、thread id、post URL全文、JWT、session_id、project ref、Supabase URL全文、Webhook URL、user_id、email、token、message preview本文全文は記録していない。

判断:

- DB側の残り3件はfinal resetで削除済みとして扱う。
- Discord投稿削除は未実施。
- 旧テストWebhook/Discord-only残骸はDiscord側手動整理対象として残る。
- 静的JSON由来は通常UI退役済み。

次工程:

- 公開サイト最終表示確認。
- Discordチャンネル側残骸整理。
- 必要ならSELECT-onlyでDB sessions 0件確認。

## M-14E-18O 運用前リセット完了記録と最終表示確認

`1830a29 Record final session reset` の状態から、運用前リセット完了扱いと公開サイト最終表示確認項目を整理した。この工程ではSQL Editor実行、SQL apply、実削除、Discord投稿削除、DB/RPC変更、Edge Function deploy、dry-run、real-send、secret設定/切替は行っていない。

運用前リセット完了扱い:

- 037 final reset後、DB側依頼書は運用前リセット済み扱い。
- Supabase側の残り依頼書3件はfinal reset対象として削除成功扱い。
- Discord側テストチャンネル投稿は、ユーザー手元で手動削除済み。
- SQLではDiscord投稿削除を行っていない。
- 旧テストWebhook/Discord-only残骸が今後見つかった場合は、DBではなくDiscord側手動整理対象とする。
- 静的JSON由来依頼書は通常UIから退役済み。
- 本番運用前の依頼書残骸cleanupは主要完了扱い。

公開サイト最終表示確認チェックリスト:

- calendarに旧依頼書が通常表示されないこと。
- session-detailで旧静的JSON依頼書が通常復活しないこと。
- mypageに不要な依頼書/申請補助情報が残らないこと。
- 依頼書が0件状態でもcalendar / session-detail / mypageが破綻しないこと。
- 新規依頼書作成・編集・削除のDiscord自動同期はQA済みとして扱う。
- Discord message id、channel id、thread id、post URL全文、JWT、session_id、project ref、Webhook URL、user id、email、tokenなどの実値を画面/docs/consoleへ出さないこと。

静的レビュー結果:

- `sessionData.js` は通常時に `data/sessions.json` を読み込まず、`includeStaticSessions=1` または `staticSessions=1` の明示フラグ時だけfixtureを含める。
- `renderCalendar.js` / `renderSessionDetail.js` は `loadMergedSessions()` 経由でデータを取得するため、通常UIでは静的JSON由来の旧依頼書が復活しない前提。
- 公開サイトの実表示はユーザー目視確認対象として扱う。

次工程候補:

- 公開サイト反映後、calendar / session-detail / mypageの最終目視確認。
- Discordチャンネル側に残骸が見つかった場合の手動整理。
- 運用開始前の新規依頼書作成smoke確認。

## M-14E-19 GM手動〆マークとDiscord update同期

`d87d48e Record prelaunch cleanup completion` の状態から、GM本人だけがsession-detail上で依頼書タイトルに `〆` を付け外しできる最小実装を追加した。この工程ではSQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、Discord実送信/編集/削除、secret設定/切替は行っていない。

実装方針:

- `〆` は新規カラムではなく、既存タイトル先頭の明示マークとして扱う。
- `〆にする` / `〆解除` は既存 `update_session_post` RPCを使うタイトル更新として扱う。
- Discord投稿済み依頼書では、タイトル更新後に既存のfrontend auto update同期導線へ渡す。
- Edge Function本文生成やWebhook設定は変更しない。
- 締切日時による申請/コメントの自動遮断は実装しない。締切日時はGM判断用の目安として扱う。

表示方針:

- session-detailではタイトル自体に `〆` が付いて見える。
- Discord本文も既存update同期により `〆` 付きタイトルへ更新される想定。
- calendarではタイトル内の `〆` をタイトル欄に重複表示せず、GM名より前の閉め印として表示する。
- 通常PL、未ログインユーザー、GMではないadminにはGM向け〆操作を出さない。

QA観点:

- GM本人のみ〆操作が可能。
- 締切前に押すと確認ダイアログを出す。
- 締切後で未〆の場合は管理領域内に押し忘れ注意を出す。
- `〆` の二重付与を避け、解除時は先頭の `〆` だけ外す。
- update自動同期で既存Discord投稿が編集され、余分なcreate投稿が増えないことを確認する。

## M-14E-19A GM手動〆マーク 公開サイト軽量QA

公開サイト配信ファイルの静的確認により、GM手動〆マーク機能のフロント差分は公開側へ反映済みと判断する。この工程ではSQL Editor実行、SQL apply、DB/RPC変更、Edge Function deploy、dry-run、Discord投稿/編集/削除、secret設定/切替は行っていない。

公開反映確認:

- `session-detail.html` / `calendar.html` は `assets/js/main.js?v=20260607-gm-close-mark` を参照している。
- 公開配信中の `main.js` は `renderSessionDetail.js?v=20260607-gm-close-mark` と `renderCalendar.js?v=20260607-gm-close-mark` を参照している。
- 公開配信中の `renderSessionDetail.js` には `〆にする` / `〆解除` / 締切後押し忘れ注意 / `update_session_post` / `syncUpdatedSession` が含まれている。
- 公開配信中の `renderCalendar.js` は、閉め印をGM名より前に出す描画順へ更新済み。
- 公開配信中の `sessionDisplay.js` は、先頭 `〆` 判定とタイトルからの閉め印除去helperを含む。

未実施:

- Codex側ではログイン済みGMブラウザ操作を実施していない。
- Discord投稿済み公開依頼書での `〆` 付与/解除は、Discord本番編集に繋がる可能性があるため実施していない。

次のQA:

- まずdraft / hidden / 未投稿のQA依頼書で、ボタン表示、確認ダイアログ、タイトル整形、二重付与防止、解除、カレンダー表示を確認する。
- Discord投稿済み依頼書で確認する場合は、実行前に対象を明確化し、1件だけのDiscord本番編集ゲートとして扱う。

## M-14E-23 Discord @everyone mention support

`sync-session-post-to-discord` に、将来のフロントUIから明示的に参加者呼び出しを選ぶための `discord_mention_mode` 入力を追加した。この工程ではEdge Function deploy、dry-run、Discord実送信/編集/削除、フロントUI変更、テンプレート変更、SQL Editor実行、DB/RPC変更、secret/Webhook変更は行っていない。

仕様:

- `discord_mention_mode` は文字列として扱う。
- `everyone`: `action=create` の投稿本文だけに `@everyone` を入れる。
- `none`: メンションなし。
- 未指定、null、想定外の値は `none` と同じ扱い。
- `update` / `delete` / `close` / `resync` では、値が `everyone` でも `@everyone` を入れない。
- `@everyone` はDiscord本文の冒頭区切り線の直下に1行だけ入る。
- `allowed_mentions` は既定で無効のまま。明示 `create/everyone` の送信時だけ `everyone` を許可し、roles/usersは許可しない。

次工程:

- Edge Function deployは別ゲート。
- deploy後はまず `dry_run=true` で、本文全文を記録せずに `@everyone` あり/なしのpreview生成をboolean/statusで確認する。
- `dry_run=false` で実際に `@everyone` を送るQAは、対象依頼書を1件に限定した別ゲートにする。
