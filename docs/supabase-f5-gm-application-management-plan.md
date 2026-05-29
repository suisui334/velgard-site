# Supabase F-5 GM承認・却下プロトタイプ設計書

## 1. 目的

F-5では、dev配下のローカル専用ページで、GMが自分のセッションへの参加申請を確認し、申請状態を `accepted` / `rejected` へ変更できるかを検証する。

確認したいこと:

- GMが自分のセッションへの参加申請を確認できる
- GMが自分のセッション申請を `accepted` / `rejected` へ変更できる
- GMが他GMのセッション申請を操作できない
- playerが承認・却下操作を実行できない
- 未ログインでは操作できない
- adminの権限境界は確認するが、UIに全体管理機能を出しすぎない
- 操作後に参加人数RPCを再読込し、`accepted_count` / `pending_count` の変化を確認できる
- 本番ページ統合前にdev配下で安全に確認する

F-5では `set_application_status` だけを対象にする。`close_session` はまだ扱わない。

## 2. 対象RPC

対象RPC:

```text
set_application_status
```

`docs/supabase/sql/003_rpc_draft.sql` 上の引数名:

```js
await supabase.rpc("set_application_status", {
  target_application_id: applicationId,
  new_status: "accepted"
});
```

状態候補:

```text
pending
accepted
rejected
waitlisted
canceled
```

F-5のUIでは、まず `accepted` / `rejected` を主操作にする。`waitlisted` / `canceled` は状態表示・将来候補に留め、UIへ出す場合は誤操作防止を追加してから扱う。

## 3. F-5でまだ扱わないもの

F-5では以下を扱わない。

```text
close_session
Discord連携
通知
メール送信
GM用本番管理画面
admin用全体管理画面
本番 session-detail.html 統合
本番 calendar.html 統合
既存本番用 assets/js 統合
```

`close_session` は、募集停止・既存pending申請・Discord同期・戻し操作の影響が大きいため、F-5とは分ける。

## 4. devプロトタイプ方針

F-5実装時は、本番ページではなく `dev/` 配下に新規作成する。

候補ファイル:

```text
dev/supabase-gm-application-management-prototype.html
dev/supabase-gm-application-management-prototype.js
docs/supabase-f5-gm-application-management-prototype.md
```

既存F-4を直接肥大化させず、GM操作用に分離する。

理由:

- PL投稿UIとGM承認UIは責務が違う
- GM操作は申請状態を変更するため誤操作の影響が大きい
- 権限確認の成否を切り分けやすい
- 本番統合前に、承認・却下だけを独立して検証できる
- F-4の投稿検証ページを壊さずに済む

## 5. UI方針

F-5 prototypeでは以下を表示する。

```text
重要な注意
接続入力欄
ログイン入力欄
ログイン状態
public sessions一覧
自分がGMのsession一覧またはGM操作候補session一覧
選択中session
申請一覧
承認ボタン
却下ボタン
再読込ボタン
操作結果
エラー表示
操作ログ
```

表示してよいもの:

```text
session_id
session title
display_name
comment body
application_status
created_at
updated_at
edited_at
```

表示してはいけないもの:

```text
user_id全文
discord_user_id
access_token
refresh_token
service_role
secret key
password
DB password
```

開発用エラー表示では、Supabase error の `message` / `code` / `hint` 程度は表示してよい。ただしURL、key、password、token、secret類はredactする。

## 6. 申請一覧取得方針

F-5では、GM操作に必要な `application_id` を取得する必要がある。

候補:

### 案A：既存RLSの範囲で `session_applications` を直接読む

内容:

- `session_applications` から `id` / `session_id` / `status` / `comment_id` / `created_at` / `updated_at` を取得する
- 対象sessionのコメント本文・表示名は、許可済みの範囲で `session_comments` / `public_profiles` / public comments RPC の情報と突き合わせる
- 画面表示では内部 `user_id` を出さない

良い点:

- 追加SQLなしで検証しやすい
- RLSで「対象GMだけ読める」境界を確認しやすい

注意点:

- Supabase JSのjoin指定やRLS境界で取得しにくい場合がある
- 表示用に不要な内部IDを持ちすぎないよう注意が必要

### 案B：GM申請一覧用RPCを後続で設計する

内容:

- `get_gm_session_applications(target_session_id)` のようなRPCを別途設計する
- 返す列を `application_id` / `display_name` / `body` / `application_status` などに絞る
- 内部 `user_id` / `discord_user_id` を返さない

良い点:

- 表示用データを安全に絞りやすい
- 本番UIへ進む時の形に近い

注意点:

- F-5実装前に追加SQL設計・RLS再確認が必要
- 今回のF-5設計段階ではSQL追加は行わない

推奨:

最初のF-5 dev実装は案Aで試し、取得や表示が複雑になったら案Bの専用RPC設計へ戻る。

## 7. 権限テスト方針

F-5のdev確認では以下を必須にする。

| No | 操作主体 | 操作 | 期待結果 |
| --- | --- | --- | --- |
| 1 | 未ログイン | 申請一覧取得 | 失敗または空表示 |
| 2 | 未ログイン | `set_application_status` 実行 | 失敗 |
| 3 | player A | 承認・却下操作 | 失敗 |
| 4 | GM A | GM Aのsession申請一覧取得 | 成功 |
| 5 | GM A | GM Aのsession申請を `accepted` に変更 | 成功 |
| 6 | GM A | GM Aのsession申請を `rejected` に変更 | 成功 |
| 7 | GM A | GM Bのsession申請を操作 | 失敗 |
| 8 | GM B | GM Aのsession申請を操作 | 失敗 |
| 9 | admin | prototype rows確認 | 成功 |
| 10 | GM操作後 | 参加人数RPC再読込 | `accepted_count` / `pending_count` の変化を確認 |

確認したい集計:

- `accepted` は `accepted_count` に含める
- `pending` は `pending_count` に含める
- `rejected` は参加人数に含めない
- `canceled` は参加人数に含めない
- コメント件数は人数として扱わない

## 8. 状態変更テストの注意

F-5はDB状態を変更する。

注意:

- テストDB限定で実行する
- 本番DBで実行しない
- 実行前に対象sessionとapplicationを画面上で明確に表示する
- 操作後は `session_applications.status` が変わる
- 同じ申請に対して再操作した場合の挙動を確認する
- `accepted` から `rejected` へ戻す、または `rejected` から `accepted` へ戻す操作を許容するか確認する
- 必要なら再seedまたは手動で状態を戻す
- 本番導入前に「承認済みを取り消す」設計を別途検討する

誤操作防止:

- クリック前に対象session title / display_name / 現在status / 変更後statusを表示する
- 承認・却下ボタンは連打できないよう処理中disabledにする
- 操作後は申請一覧と参加人数RPCを再読込する
- 操作ログに「誰を何に変更したか」を残す。ただし内部IDやsecretは表示しない

## 9. エラー表示方針

人間向けに表示する例:

```text
ログインが必要です。
この操作は対象セッションのGMだけが実行できます。
申請が見つかりません。
既に別の状態へ変更されています。再読込してください。
通信またはDB側でエラーが発生しました。
```

開発用詳細として表示してよいもの:

- `message`
- `code`
- `hint`

表示してはいけないもの:

- Supabase URL全文
- publishable / anon key全文
- access token
- refresh token
- password
- service role key
- secret key
- DB password

## 10. 本番統合前の条件

F-5後も、すぐに本番統合しない。

本番統合前に必要な条件:

- F-5 dev確認完了
- RLS smoke test再実行でFAILなし
- GM操作ログまたは操作結果表示方針を整理済み
- 誤操作時の戻し方を整理済み
- 本番GM付与運用を確定済み
- 本番UIで操作対象を明確に表示できる
- `accepted` / `rejected` / `pending` / `waitlisted` / `canceled` の文言を確定済み
- admin操作を本番UIにどこまで出すか整理済み
- `close_session` は別工程として扱う
- rollback / backup / admin復旧手順を整理済み

## 11. 実装時の禁止事項

F-5実装時も以下は禁止する。

- `session-detail.html` の変更
- `calendar.html` の変更
- 既存本番用 `assets/js` の変更
- `data/sessions.json` の変更
- `updates.json` の変更
- Supabase追加SQL実行
- `close_session` 呼び出し
- service role / secret keyの使用
- localStorageへのkey保存
- GitHub Pages本番ページへの導線追加

## 12. F-5実装へ進む条件

次に実装へ進む条件:

- この設計書の内容を確認済み
- F-4投稿プロトタイプの成功結果を維持している
- `set_application_status` の引数名が `target_application_id` / `new_status` であることを確認済み
- GM A / GM B / player / admin のテストユーザーが使用可能
- テストsessionにpending申請が存在する、またはF-4で作成できる
- 失敗時に本番接続へ進まない停止ルールを維持する
