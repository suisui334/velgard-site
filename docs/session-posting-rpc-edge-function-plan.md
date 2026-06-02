# M-14B 依頼書投稿DB/RPC + Discord同期Edge Function草案

## 1. 目的

M-14Aの全体設計を、次工程でレビュー・適用候補にできる粒度へ具体化する。

対象:

- GM/adminが依頼書を投稿するためのDB/RPC草案。
- Discord同期用Edge Function草案。
- 投稿済みセッションをcalendar/session-detailへ表示するための方針。

この工程ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、フロント実装は行わない。

## 2. 既存sessions拡張で行けるか

第一候補は既存 `public.sessions` の拡張で問題ない。

理由:

- `session_comments` と `session_applications` が `sessions.id` を外部キーとして参照済み。
- GM判定は `sessions.gm_user_id` を見る `is_session_gm(target_session_id)` 系の既存関数を使っている。
- mypage、session-detail、GM履歴、GM承認/却下、GM Discord連絡先は `session_id` を共有している。
- 新テーブルを正本にすると、既存RPC群との接続と二重管理が増える。

新テーブルは、依頼書本文そのものではなくDiscord同期履歴や複数投稿先が必要になった段階で検討する。

## 3. 追加DB列案

`public.sessions` 追加候補:

- `session_type text`
- `application_deadline timestamptz`
- `discord_sync_status text`
- `discord_last_action text`
- `discord_message_id text`
- `discord_channel_id text`
- `discord_thread_id text`
- `discord_sync_requested_at timestamptz`
- `discord_synced_at timestamptz`
- `discord_sync_error text`
- `discord_post_url text`

`session_type` は `one-shot` / `campaign` / `special` / `other` の固定分類。`application_deadline` は開催時刻とは別に扱う。

Discord同期メタデータにはDiscord投稿credentialやサーバー側credential値を保存しない。

公開かつ `tentative` / `recruiting` の新規投稿だけを初期同期対象にする。`draft`、`private`、`hidden` は `discord_sync_status = skipped` とし、Discordへ即時同期しない。`draft` を `public` で保存する要件が出た場合は、公開範囲とRLS/一覧表示の扱いを再レビューしてから許可する。

## 4. 投稿RPC案

SQL草案:

```text
docs/supabase/sql/015_session_posting_rpc_draft.sql
```

RPC候補:

```text
create_session_post
```

戻り値:

- `session_id`
- `discord_sync_status`
- `created_at`

戻り値に含めない:

- 内部user ID
- email
- Discord credential
- サーバー側credential値

`update_session_post`、`delete_or_close_session_post` は、Edge Function側actionとして先に設計し、DB RPCとして切り出すかは次工程で判断する。

初期案ではGM本人投稿の `gm_user_id` は `auth.uid()` 固定。admin代理投稿やGM差し替えは未確定事項として残し、実装前に別途確認する。

## 5. Edge Function案

Edge Function草案:

```text
docs/supabase/functions/session-post-discord-sync-draft.md
```

1 endpointで以下のactionを受ける案を第一候補にする。

```text
action = create | update | delete | close | resync
```

各actionの概要:

- `create`: DBへ新規保存し、Discordへ新規投稿する。
- `update`: DBを更新し、既存Discord投稿を編集、または更新通知を追記する。
- `close`: DB上は募集終了状態にし、Discord投稿を「募集終了」表示へ編集する。
- `delete`: 初期案では物理削除ではなく非公開化し、Discord投稿を「削除済み」表示へ編集する。
- `resync`: 失敗・不整合時に現在のDB内容からDiscordへ再送/再編集する。

Discord投稿先が通常チャンネル、フォーラムチャンネル、既存スレッド、イベントのどれになるかは未確定。実装前にユーザー確認が必要。

## 6. Discord側の削除・編集方針

比較:

- 既存メッセージ編集: 最新情報を1投稿に集約できる。編集時の第一候補。
- 変更通知追記: 変更履歴を残しやすい。重要変更や編集不可時の代替。
- 物理削除: Discord側から消せるが監査性が落ちる。初期は非推奨。
- 募集終了/削除済みへ編集: 監査性と文脈を残せる。削除/非公開時の第一候補。

初期推奨は、削除時も物理削除せず「募集終了 / 削除済み」に編集する方式。

## 7. 同期失敗時の扱い

初期方針:

- DB保存・更新は成功扱いにする。
- Discord同期失敗は `discord_sync_status = failed` として記録する。
- `discord_last_action` に失敗したactionを残す。
- `discord_sync_error` は短い概要だけを保存する。
- GM/admin画面から `resync` できる余地を残す。

外部API呼び出しを含むため、DB保存とDiscord反映を完全な単一トランザクションにしない。

## 8. Discord本文案

最低限含める:

- タイトル
- 開催日
- 開催時刻
- 申請締切
- 種別
- レベル帯（将来、カレンダー側算出値またはDB側値が使える場合）
- 募集人数
- 概要（依頼書本文）
- 詳細ページURL

含めない:

- 内部user ID
- email
- Discord投稿credential
- サーバー側credential値
- 内部application/comment ID
- 承認済み参加者のDiscord ID

## 9. data/sessions.jsonとの併用方針

次工程の表示統合では、しばらく静的 `data/sessions.json` とSupabase `sessions` を併用する。

案:

1. `data/sessions.json` を既存静的予定として読み込む。
2. Supabase `sessions` から公開投稿セッションを読み込む。
3. Supabase行を既存 `sessionDisplay.js` 用camelCaseへ変換する。
4. `id` で重複排除する。
5. 同じ `id` がある場合はSupabase側を優先する。
6. calendarではマージ後の配列を日付ごとに表示する。
7. `session-detail?id=...` では、まず静的/DBマージ後の対象を探す。投稿セッションだけでも詳細を開けるようにする。

ID重複防止:

- 投稿時の `id` はサーバー側生成を優先する。
- 既存静的IDと衝突しないことをDB側で確認する。
- URL互換のためtext idを維持する。

将来、投稿セッションが正本化できたら、`data/sessions.json` は初期データまたは移行前互換へ縮小する。

## 10. テンプレート保存との関係

テンプレート保存は今回実装しない。

後続:

- M-15A: `request_templates` SQL草案。
- M-15B: mypage/GM管理画面でテンプレート保存。
- M-15C: 投稿フォームへテンプレート挿入。

テンプレートは下書き補助であり、投稿済み依頼書の正本は `sessions`。

## 11. まだやらないこと

- SQL Editor実行。
- DB変更。
- Edge Function deploy。
- Discord実送信。
- フロント実装。
- credential値の記録。
- `updates.json` 変更。
- commit / push。

## 12. M-14C preflight follow-up

M-14C / 015 preflight中に、`public.sessions` だけでなくpublic schema内の複数テーブルで `anon` / `authenticated` に `TRUNCATE` 権限が見えていた。

ユーザーがSupabase SQL Editorで `TRUNCATE` だけをrevoke済み。`SELECT` / `INSERT` / `UPDATE` / `DELETE` は今回触っていない。確認クエリでは `anon` / `authenticated` の `TRUNCATE` 権限が0件になった。

`postgres` などの管理者系ロール側の権限は対象外。TRUNCATE権限整理時点では `015_session_posting_rpc_draft.sql` のapplyは未実行だった。

詳細は `docs/supabase-public-truncate-privilege-cleanup-result.md` に記録済み。

## 13. M-14C SQL apply result

ユーザーが `docs/supabase/sql/015_session_posting_rpc_draft.sql` のapply sectionをSupabase SQL Editorで実行し、`Success. No rows returned` で通過済み。

`public.sessions` の `session_type` / `application_deadline` / Discord同期メタデータ列、check制約、`create_session_post(...)` RPC、grantを確認済み。M-14C apply直後時点では、`create_session_post(...)` の実行テスト、Edge Function deploy、Discord実送信、フロント実装は未実施だった。

`015_session_posting_rpc_draft.sql` のapply sectionは適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。詳細は `docs/session-posting-rpc-apply-result.md` に記録済み。

## 14. M-14D-1 hidden draft execution test

`dev/run-create-session-post-test.mjs` で、GM認証文脈から `create_session_post(...)` のhidden draft最小実行を確認済み。通常実行ではSKIPし、明示フラグ付きの1回実行で `discord_sync_status = skipped`、作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot`、anonからpublic表示対象として見えないことを確認した。

このテストで作成されたhidden draft rowは削除していない。Edge Function deploy、Discord実送信、SQL EditorでのRPC直接実行、DB構造変更、フロント実装は行っていない。

詳細は `docs/session-posting-rpc-execution-test-result.md` に記録済み。
## 15. M-14D-2 posting form and merged display

`session-post.html` にGM/admin向け依頼書投稿フォームを追加し、認証済みSupabase clientから `create_session_post(...)` を呼ぶ。
初期値は `visibility = hidden` / `status = draft` / `sessionType = one-shot` とし、公開保存時は確認チェックを要求する。
成功時の画面表示は作成成功メッセージと `discord_sync_status` のみに限定し、raw IDは表示しない。
グローバルメニューの `POST` は削除し、投稿導線はcalendarの日付セル内の `＋依頼書` から `session-post.html?date=YYYY-MM-DD` へ遷移する形にした。
`date` queryがある場合は開始日時欄へ日付を初期反映する。
フォーム上は `開催日` / `開始時刻` を `開始日時` に統合し、送信時に `p_session_date` / `p_start_time` へ分解する。
`終了時刻` は `終了日時` に変更し、送信時は時刻部分だけを `p_end_time` として送る。
現DB/RPCは終了日を保持しないため、日跨ぎ終了日時は投稿前バリデーションで止める。
日跨ぎ対応は将来 `end_date` または `end_at` を追加する工程で扱う。
`レベル帯` 欄は削除し、`p_level_range` は `null` にする。
依頼書本文は概要欄へ記載する運用にし、フォームの `依頼書本文` 欄と `参加条件` 欄は削除した。
RPC送信時の `p_request_body` / `p_requirements` は `null` にする。

calendar / session-detail は `data/sessions.json` とSupabase `public.sessions` の公開表示対象をマージして読む。
Supabase側は `gm_user_id` を取得せず、`session_type` / `application_deadline` を既存表示用の `sessionType` / `applicationDeadline` に正規化する。
同一IDは静的JSON側を優先する。

Discord実送信はまだ行わず、RPC戻り値の同期状態表示に留める。
詳細は `docs/session-posting-form-result.md` に記録済み。

## 16. M-14D-3 end_at draft

M-14D-2の投稿フォームは `開始日時` / `終了日時` UIに整理済みだが、015適用済みのDB/RPCは終了日を保存できない。
そのため、SQL/RPCが対応するまでは日跨ぎ終了日時を投稿前バリデーションで止める。

正式対応の第一候補は `public.sessions.end_at timestamptz` を追加する差分SQL。
015は適用済みのため、同じapply sectionを通常運用で再実行せず、`docs/supabase/sql/016_session_posting_end_at_draft.sql` として扱う。

`create_session_post(...)` は既存引数順を維持し、末尾に `p_end_at text default null` を追加する案。
`p_end_at` はフォームの `datetime-local` 値をAsia/Tokyo前提で `timestamptz` 化し、`sessions.end_at` へ保存する。
互換用に `p_end_time` / `end_time` も維持し、戻り値は `session_id` / `discord_sync_status` / `created_at` のまま増やさない。

SQL/RPC適用後、フロントは `終了日時` から `p_end_at` を送信し、現在の日跨ぎブロックを解除する。
表示側は `end_at` / `endAt` を終了日時として優先し、なければ従来の `date + end_time` / `endTime` にフォールバックする。
Discord本文生成も `end_at` を優先し、日跨ぎ終了日時を正しく表示する。

この草案作成ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 17. M-14D-4 end_at apply result

ユーザーが `docs/supabase/sql/016_session_posting_end_at_draft.sql` のapply sectionをSupabase SQL Editorで実行し、`Success. No rows returned` で通過済み。
apply前は `public.sessions.end_at` 未作成、`create_session_post` は1本のみ、`p_end_at` 引数なしだった。
apply後は `public.sessions.end_at timestamptz` が追加され、`create_session_post(...)` は `p_end_at` 対応版へ差し替わった。

旧signatureを明示dropしてから新signatureを作成したため、`create_session_post` は1本だけであることを確認済み。
grantは `authenticated EXECUTE` と `postgres EXECUTE` のみで、`anon EXECUTE` はない。
関数定義は `security definer = true`、`volatile`、`search_path` 固定あり、戻り値は `session_id` / `discord_sync_status` / `created_at` のみ。

`016_session_posting_end_at_draft.sql` は適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。
日跨ぎhidden/draft投稿テスト、フォーム側の日跨ぎ許可切替、Edge Function deploy、Discord実送信はまだ未実施。
詳細は `docs/session-posting-end-at-apply-result.md` に記録済み。

## 18. M-14D-5 posting form end_at support

`session-post.html` の投稿フォームは、終了日時を `p_end_at` として `create_session_post(...)` へ送信する実装へ切り替えた。
互換用に `p_end_time` も終了日時の時刻部分として送る。
日跨ぎ終了日時の投稿前ブロックは解除し、終了日時が開始日時以下の場合だけ投稿前に拒否する。

Supabase sessions読み込みは `end_at` を取得して `endAt` に正規化する。
表示側は `endAt` があれば終了日時として優先し、なければ従来の `endTime` にフォールバックする。

`レベル帯` 欄、`依頼書本文` 欄、`参加条件` 欄はフォームへ復活させていない。
`p_level_range` / `p_request_body` / `p_requirements` は `null` を送る。
Discord実送信は未実装のまま。public/recruiting投稿はユーザー確認なしでは実施しない。

GM認証文脈のSupabase clientで、日跨ぎ終了日時を含むhidden/draft投稿を1回確認済み。
`discord_sync_status = skipped`、作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot`、`end_at` あり、anonからpublic表示対象として見えない。
認証情報を画面やツール入力へ出さないため、ブラウザフォームでのGMログイン送信は行っていない。

## 19. M-14D-6 manage list

hidden/draftは公開calendarに出ないため、`session-post.html` にGM/admin向けの `自分の依頼書` 一覧を追加した。
M-14D-6bでcalendar側の常設 `自分の依頼書` 導線は削除し、依頼書一覧は `session-post.html` 内へ集約した。
calendarの日付セルにある `＋依頼書` 導線は維持し、`session-post.html?date=YYYY-MM-DD` へ遷移できる。

一覧は認証済みSupabase clientから `public.sessions` をSELECTし、RLSで見える範囲を表示する。
取得・表示する情報は、タイトル、開催日時、終了日時、公開状態、募集状態、Discord同期状態、作成日時、詳細導線に限定する。
`gm_user_id`、email、user_id全文、token、key、secret、Discord credential類は取得・表示しない。

`詳細を見る` は `session-post.html?id=SESSION_ID#my-sessions` へ向ける。
今回は一覧表示のみで、下書き詳細表示、編集、削除、公開切替は次工程。
Discord実送信、Edge Function deploy、public/recruiting投稿は実施しない。

## 20. M-14D-7b manage select UI

`session-post.html` の `自分の依頼書` は、カード一覧形式やスクロール付き一覧パネルを不採用にし、フォーム内の `公開状態` 欄の下段、`募集状態` の右隣付近にあるselect形式へ変更した。
既存依頼書は `【募集状態・公開状態】YYYY/MM/DD HH:mm タイトル` の短い選択肢として表示する。

select option の value にはSupabase row id / uuidを入れず、`manage-0`、`manage-1` のようなローカルキーだけを使う。
対象レコードはJSメモリ上の配列から取得する。

選択した依頼書は同ページのメインフォームへ即時反映する。
巨大な `編集中: 依頼書タイトル` 見出しは削除し、ページ見出しは通常どおり `依頼書` のままにする。
編集モード中は作成ボタンをdisabledにし、Enter submitでも `create_session_post(...)` を呼ばない。
selectの `新規依頼書を書く` で選択解除、フォーム初期化、URLの `id` 除去を行い、新規作成モードへ戻れる。

保存更新・公開切替・削除・募集終了は未実装。
RPC変更とDB構造変更は行っていない。

次工程候補は `update_session_post` RPC草案、下書き編集保存、公開切替。
この工程ではSQL Editor実行、DB構造変更、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 21. M-14D-7c manage select layout

M-14D-7bのselect化後、`自分の依頼書` selectが `募集状態` と `概要` を下へ押し下げるレイアウト崩れがあった。
M-14D-7cでは、selectを通常フォーム項目として扱い、`募集状態` の右隣付近に収めた。

カード一覧形式、スクロール付き一覧パネル、大型パネル余白は復活させない。
RPC変更、DB構造変更、SQL Editor実行、Edge Function deploy、Discord実送信、credential類の実値記録は行っていない。

## 22. M-14D-8 update_session_post RPC草案

下書き依頼書の編集保存へ進む前段として、`update_session_post` RPC草案とUI接続計画を作成した。
SQL草案は `docs/supabase/sql/017_update_session_post_rpc_draft.sql`、設計docsは `docs/session-posting-update-rpc-plan.md`。

既存 `public.sessions.id` と `is_session_gm(target_session_id text)` がtext前提のため、引き継ぎ案の `p_session_id uuid` は採用せず、草案では `p_session_id text` とした。
人数引数も既存 `create_session_post` に合わせて `p_player_min` / `p_player_max` とする。

権限方針は、`authenticated` のみEXECUTE、anon不可、GMは自分の依頼書のみ、adminは管理者権限で更新可。
通常PLと他GMは拒否する。

Discord同期メタデータは、公開かつ活動中なら `pending` とし、既存 `discord_message_id` の有無で `update` / `create` を分ける。
hidden / draft更新で既存Discord投稿がなければ `skipped`、既存投稿がある非公開化・下書き化・中止化は後続Edge Function向けに `delete` 相当のpendingとする案。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、Edge Function deploy、Discord実送信、フロントUI接続実装、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 23. M-14D-8b update_session_post preflight整理

`docs/supabase/sql/017_update_session_post_rpc_draft.sql` で、SQL Editorへ先に貼る非破壊確認範囲を `SECTION 1: PREFLIGHT ONLY` として明確化した。
preflightはSELECTのみで、`public.sessions` 列一覧、主要列型、関連check制約、既存RPC、helper関数、anon/authenticatedの既存grant状況を確認する。

apply範囲は `SECTION 2: APPLY` とし、preflight結果レビュー前に実行しない注意コメントを追加した。
この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 24. M-14D-8c preflight専用SELECTファイル

固定行番号でpreflightを抜き出す方式では、実適用SQLが混入する危険があるため破棄した。
SQL Editor実行前に停止し、専用のSELECT-onlyファイル `docs/supabase/sql/017_update_session_post_preflight_select_only.sql` を作成した。

今後SQL Editorへ貼るのはpreflight専用ファイル全文とし、`017_update_session_post_rpc_draft.sql` 本体から行番号で抜き出さない。
017本体には、固定行番号方式禁止と専用ファイル使用を明記した。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 25. M-14D-8d update_session_post preflight結果

ユーザーがSQL Editorで実行したのは `docs/supabase/sql/017_update_session_post_preflight_select_only.sql` のみ。
`017_update_session_post_rpc_draft.sql` の実適用sectionは未実行で、DB構造変更、RPC作成、grant変更は行っていない。

preflightで、`public.sessions` の想定列はすべて存在し、`id` はtext、`end_at` / `updated_at` / Discord同期日時列は `timestamp with time zone` と確認できた。
`update_session_post` は未存在、`create_session_post` は1本のみ存在し、`p_end_at` 対応済み、`security_definer = true`。
`has_role(text)` / `is_admin()` / `is_session_gm(text)` は存在し、いずれも `security_definer = true`。

制約の許可値は、`status = draft / tentative / recruiting / full / closed / finished / canceled`、`visibility = public / private / hidden`、`session_type = one-shot / campaign / special / other`、`discord_sync_status = not_requested / pending / posted / failed / skipped`、`discord_last_action = create / update / delete / close / resync`。
DB/RPC草案では状態値を `canceled` に統一し、英国綴りは使わない。

SQL草案は、`p_session_id text`、既存許可値、Discord同期メタデータ更新、`security definer`、authenticated EXECUTE / anon不可の方針でpreflight結果と矛盾しない。
この工程ではSQL Editor追加実行、DB構造変更、RPC作成/置換、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 26. M-14D-8e update_session_post apply section review

`docs/supabase/sql/017_update_session_post_rpc_draft.sql` の `SECTION 2: APPLY` をSQL Editor実行前に最終レビューした。
RPC signatureは `p_session_id text` と `p_player_min` / `p_player_max` でpreflight結果と整合し、`security definer` / `set search_path = ''` / `auth.uid()` による認証確認を維持している。

GM/admin制御は、未ログイン拒否、対象session未存在拒否、admin許可、対象GM許可、通常PL/他GM拒否の方針。
入力値はpreflightで確認した `session_type` / `visibility` / `status` 許可値に合わせ、`canceled` を米国綴りに統一している。
Discord同期メタデータはRPC内で実送信せず、`pending` / `skipped` と `create` / `update` / `delete` / `close` の範囲で後続Edge Function向け状態だけを更新する。

権限草案は、function作成後に `public` と `anon` からEXECUTEを明示的に外し、`authenticated` へEXECUTEを付与する形へ補強した。
危険語チェックの誤検出を減らすため、SQL草案内のcredential注意コメントを中立表現へ修正した。
この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 27. M-14D-8f reviewed apply-only SQL

SQL Editor貼り付け対象を明確にするため、APPLY専用ファイル `docs/supabase/sql/017_update_session_post_apply_reviewed.sql` を作成した。
このファイルには、レビュー済みの `update_session_post` 関数作成/置換、`security definer`、`set search_path = ''`、`public` / `anon` からのEXECUTE取り外し、`authenticated` へのEXECUTE付与、実行後確認SELECTだけを入れている。

preflight専用SQLとは分離済みで、`017_update_session_post_rpc_draft.sql` は草案・レビュー記録として残す。
今後SQL Editorで実行する場合は `017_update_session_post_apply_reviewed.sql` の全文のみを使い、draft全文は貼らない。
M-14D-8fではSQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。

## 28. M-14D-8g update_session_post apply result

ユーザーがSupabase SQL Editorで `docs/supabase/sql/017_update_session_post_apply_reviewed.sql` を適用し、`update_session_post` RPC作成と権限設定が完了した。
適用後確認では `function_count = 1`、`all_security_definer = true`、signatureは `update_session_post(text,text,text,text,text,text,text,integer,integer,text,text,text,text)`。

権限確認は、`authenticated` にEXECUTEあり、`anon` と `public` にEXECUTEなしで、いずれも期待値どおり `ok = true`。
DB側の変更はRPC作成・権限設定のみで、テーブル構造変更はない。Discord実送信、Edge Function deploy、credential類の実値記録、`updates.json` 変更は行っていない。
次工程はM-14D-9として、`session-post.html` の既存依頼書編集モードに「変更を保存」UIを接続し、`update_session_post` を呼ぶ。

## 29. M-14D-9 frontend update save UI

`session-post.html` の既存依頼書編集モードに `変更を保存` UIを接続し、保存時に `update_session_post` RPCを呼ぶようにした。
新規作成モードでは従来どおり `create_session_post` を使い、既存依頼書選択中は作成ボタンを非表示/disabledにして誤作成を防ぐ。

更新payloadは作成用と同じフォーム値整形を共通利用し、`p_end_at` / 日跨ぎ対応、申請締切、種別、募集人数、概要、公開状態、募集状態を維持する。
`p_session_id` はDOMやselect option valueから取得せず、JSメモリ上の選択レコードからRPCへ渡す。

保存成功後はフォーム内容、select表示、JSメモリ上の選択レコードを最新化する。
保存失敗時は既知RPCエラーを日本語に丸め、内部IDやcredential類を表示しない。

この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、公開切替専用UI、削除/募集終了UI、`updates.json` 変更、credential類の実値記録、commit / pushは行っていない。

## 30. M-14D-10 publication switch UI guard

既存依頼書編集中に、`公開状態` / `募集状態` の組み合わせに応じた短い補助文を追加した。
非公開または下書きは公開カレンダー非表示、公開系は公開カレンダー反映とDiscord通知未実装、終了系は募集終了扱いになることを示す。

`draft + public` はUI側でも保存前に止め、該当時は `下書きは公開にできません。募集状態を変更するか、公開状態を非公開にしてください。` と表示する。
この場合は `update_session_post` RPCを呼ばない。

公開保存時の成功メッセージは、公開カレンダー反映とDiscord未実装を明示する。
非公開保存は従来どおり短い成功メッセージに留める。

この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、公開切替専用大型UI、削除/募集終了専用UI、`updates.json` 変更、credential類の実値記録、commit / pushは行っていない。

## 31. M-14D-10.5 session-detail edit route

`session-detail.html` の基本情報グリッド右下に、編集 / 削除ボタン枠を追加した。
編集ボタンはSupabase由来の依頼書で、`is_admin()` または `is_session_gm(target_session_id)` が通る場合だけ有効化し、`session-post.html?id=<session_id>#my-sessions` へ遷移する。

削除ボタンはdisabled配置のみで、削除処理、status変更、visibility変更、RPC呼び出しは行わない。
開催時刻は開始側にも年月日を出し、日跨ぎ時に開始日時が欠けないようにした。

`session-post.html?id=...` は既存の自分の依頼書select復元を使い、編集状態の補助文を明確化した。
raw id / uuid、user_id、email、token、credential類はDOM、画面、consoleへ出さない方針を維持する。

この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、admin全件管理UI、削除/募集終了本実装、`updates.json` 変更、credential類の実値記録、commit / pushは行っていない。

## 32. M-14D-11A admin management scope

adminをヴェルガルド公開サイト内の全権限ユーザーとして扱う方針で、`session-post.html` の管理対象selectを整理した。
通常GMは自分が作成した依頼書だけを編集対象にし、adminは既存RLS/APIで取得できるSupabase由来依頼書を管理対象として扱う。

service_role keyやsecret類は使わず、フロントからDB直UPDATEもしない。
取得は認証済みSupabase clientと既存RLSに従い、保存は既存 `update_session_post` RPCを使う。
select option valueは `manage-0` 形式のローカルキーだけを維持し、raw id / uuid / user_id / email / token はDOM、画面、consoleへ出さない。

adminの管理対象取得が既存RLS/APIで失敗した場合は、管理対象の依頼書を取得できない旨と管理用RPC追加が必要である旨を表示する。
この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Edge Function deploy、Discord実送信、削除/募集終了本実装、Discord resync UI、`updates.json` 変更、credential類の実値記録、commit / pushは行っていない。
