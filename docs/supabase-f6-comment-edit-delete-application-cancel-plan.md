# Supabase F-6 コメント編集・削除・申請取消RPC設計書

## 1. 目的

F-6では、参加希望コメントの編集・削除と、コメント削除に連動する参加申請取消のRPC / RLS / 本番UX方針を整理する。

目的:

- コメント者が自分の参加希望コメントを編集できる
- コメント者が自分の参加希望コメントを削除できる
- GMが自分のセッションに紐づくコメントを管理編集・削除できる
- 最後の有効コメント削除時、そのユーザーの参加申請を取消扱いにできる
- 参加人数はコメント件数ではなく `session_id + user_id` 単位で数える
- 同一ユーザーが複数コメントしても申請人数は1人分
- 本番 `session-detail.html` 統合前に、RPC / RLS / UI方針を整理する

この資料は設計書であり、Supabase上でSQLを実行しない。

## 2. 本番UX前提

本番UIは、専用GM管理ページ中心ではなく、`session-detail.html` の参加希望コメント欄への統合を基本にする。

- PLは自分のコメントを編集・削除できる
- PLには自分の申請状態と必要な案内だけを見せる
- GMは参加希望コメント一覧上で承認・却下・コメント管理を行う
- GM操作は対象セッションのGMにのみ表示する
- admin操作は本番初期UIでは出しすぎず、必要なら別の管理導線で扱う

## 3. データ設計前提

既存の最小核:

```text
session_comments
session_applications
```

前提:

- `session_comments` はコメント本文を扱う
- `session_applications` は `session_id + user_id` 単位の申請状態を扱う
- 人数集計は `session_applications` を基準とする
- コメント件数を人数として扱わない
- `rejected` / `canceled` / `withdrawn` 相当は参加人数に含めない

既存カラム:

```text
session_comments:
id / session_id / user_id / body / is_application / created_at / updated_at / edited_at / deleted_at

session_applications:
id / session_id / user_id / comment_id / status / created_at / updated_at / canceled_at
```

既存status:

```text
pending
accepted
rejected
waitlisted
canceled
```

現行DB制約では `withdrawn` は未対応。追加する場合はcheck制約、RPC、集計RPC、RLSテストの更新が必要になる。

## 4. 既存RPCとの関係

既存RPC:

- `create_application_comment(target_session_id, comment_body)`: コメント作成と申請行作成 / 更新
- `edit_comment(target_comment_id, comment_body)`: 現状は本人コメント編集用
- `cancel_application(target_session_id)`: 現状は本人申請を `canceled` にする
- `set_application_status(target_application_id, new_status)`: GM/adminによる状態変更
- `get_public_session_comments(target_session_id)`: 公開表示用の最小列コメントRPC
- `get_public_session_application_counts(target_session_id)`: 公開参加人数集計RPC

F-6では、既存 `edit_comment` / `cancel_application` をそのまま本番用完成形とせず、GM管理編集・削除、最後の有効コメント削除との整合を追加設計する。

## 5. 必要になりそうなRPC案

候補:

```text
update_application_comment(target_comment_id uuid, comment_body text)
delete_application_comment(target_comment_id uuid)
cancel_application(target_session_id text)
delete_application_comment_and_maybe_cancel(target_comment_id uuid)
```

推奨:

- 本人編集は `update_application_comment` に寄せる
- 本人削除とGM管理削除は `delete_application_comment` で扱う
- 最後の有効コメント削除時の申請取消は `delete_application_comment_and_maybe_cancel` 相当の一括RPCに寄せる
- 既存 `cancel_application` は、PL本人が明示的に申請を取り下げる操作として残す

命名は暫定。実装時には、既存 `edit_comment` と役割が重複するため、既存RPCを拡張するか、新RPCへ移行するかを決める。

## 6. コメント編集RPC設計

### 6.1 操作できる人

- 本人は自分のコメントのみ編集できる
- GMは自分のsessionに紐づくコメントのみ編集できる
- adminは全体操作可能にするか、初期devでは確認対象に留める
- 未ログインは編集できない
- playerは他人のコメントを編集できない
- GMは他GMのsessionコメントを編集できない

### 6.2 入力検証

- `comment_body` は必須
- 空文字、空白のみは禁止
- 既存制約に合わせ、最大4000文字を基本にする
- HTMLは文字列として扱い、表示時にHTMLとして挿入しない
- 危険なHTMLを保存前に除去するか、表示時に必ずescapeする

### 6.3 更新項目

- `body` を更新する
- `edited_at = now()`
- `updated_at = now()`
- `deleted_at is null` のコメントのみ編集可能

### 6.4 編集履歴

初期方針では編集履歴テーブルは持たなくてもよい。

将来課題:

- `session_comment_revisions`
- 編集前本文
- 編集者
- 編集理由
- 編集日時

### 6.5 SQL草案

以下は草案。まだ実行しない。

```sql
-- Draft only. Do not run yet.
create or replace function public.update_application_comment(
  target_comment_id uuid,
  comment_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if comment_body is null or length(trim(comment_body)) = 0 then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  update public.session_comments c
  set
    body = comment_body,
    edited_at = now(),
    updated_at = now()
  where c.id = target_comment_id
    and c.deleted_at is null
    and (
      c.user_id = auth.uid()
      or public.is_session_gm(c.session_id)
      or public.is_admin()
    );

  get diagnostics affected_count = row_count;

  if affected_count = 0 then
    raise exception 'comment not found or not editable';
  end if;
end;
$$;
```

## 7. コメント削除RPC設計

### 7.1 操作できる人

- 本人は自分のコメントのみ削除できる
- GMは自分のsessionに紐づくコメントのみ削除できる
- adminは全体操作可能にするか、初期devでは確認対象に留める
- 未ログインは削除できない
- playerは他人のコメントを削除できない
- GMは他GMのsessionコメントを削除できない

### 7.2 論理削除を推奨

初期段階では論理削除を推奨する。

理由:

- 誤削除時に戻しやすい
- GM操作の監査性を残しやすい
- 申請取消との連動を扱いやすい
- トラブル時に確認できる

論理削除時:

- `deleted_at = now()`
- `updated_at = now()`
- 公開表示RPCでは `deleted_at is null` のみ返す
- 削除済みコメント本文は公開表示しない

身内向け簡略案:

- 初期検証だけなら物理削除も可能
- ただし本番統合では復旧・監査・誤操作対応が弱くなるため非推奨

## 8. 削除と申請取消の連動

本番初期案:

- 最後の有効コメントを削除した場合、そのユーザーの参加申請は取消扱いにする
- 有効コメントとは `deleted_at is null` かつ `is_application = true` のコメント
- 同一ユーザーに有効コメントがまだ残っている場合、申請行は維持する
- 申請取消後、参加人数から除外する

注意:

- `accepted` 済み申請を本人が削除で取り下げられるかは要確認
- 初期案では、`accepted` の最後のコメント削除は強い確認を挟む
- GM削除でaccepted申請を取消扱いにする場合は、GM側に操作意図を明確に出す

## 9. 申請取消statusの推奨

候補:

| 候補 | 意味 | 良い点 | 注意点 |
| --- | --- | --- | --- |
| `canceled` | 取消全般 | 既存DB制約に含まれているためすぐ使える | PL本人の取り下げと運営都合取消を区別しにくい |
| `withdrawn` | PL本人による取り下げ | 意味が自然でUI文言にしやすい | 既存check制約、RPC、集計、テスト更新が必要 |
| `cancelled` | 英式綴りの取消 | 文言として見慣れる場合がある | 既存値 `canceled` と混在しやすい |

推奨:

- 短期実装では既存制約に合わせて `canceled` を使う
- UI表示では「取り下げ」と表記してもよい
- 将来的にPL本人取り下げとGM側取消を分けたくなったら `withdrawn` を追加検討する
- `withdrawn` を追加する場合、既存の `cancel_application`、`set_application_status`、`get_public_session_application_counts`、RLS smoke testを更新する

## 10. application status整理

| status | 意味 | 誰が設定できるか | 参加人数に含めるか | PLに表示するか | GMに表示するか |
| --- | --- | --- | --- | --- | --- |
| `pending` | 申請中 / GM判断待ち | コメント投稿RPC、GM/admin | いいえ。pending_countとして別集計 | はい | はい |
| `accepted` | 参加承認済み | GM/admin | はい | はい | はい |
| `rejected` | 却下 | GM/admin | いいえ | はい。文言は慎重にする | はい |
| `waitlisted` | キャンセル待ち / 保留 | GM/admin | いいえ。waitlisted_countとして別集計 | はい | はい |
| `canceled` | 取消 / 取り下げ | PL本人、GM/admin | いいえ | はい | はい |
| `withdrawn` | PL本人による明示取り下げ | 将来候補 | いいえ | はい | はい |

現行DBでは `withdrawn` は未対応。

## 11. 削除連動RPC草案

以下は草案。まだ実行しない。

```sql
-- Draft only. Do not run yet.
create or replace function public.delete_application_comment_and_maybe_cancel(
  target_comment_id uuid
)
returns table (
  deleted_comment_id uuid,
  application_status text,
  application_canceled boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_session_id text;
  target_user_id uuid;
  active_comment_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select c.session_id, c.user_id
  into target_session_id, target_user_id
  from public.session_comments c
  where c.id = target_comment_id
    and c.deleted_at is null;

  if target_session_id is null then
    raise exception 'comment not found';
  end if;

  if not (
    target_user_id = auth.uid()
    or public.is_session_gm(target_session_id)
    or public.is_admin()
  ) then
    raise exception 'comment not deletable';
  end if;

  update public.session_comments
  set
    deleted_at = now(),
    updated_at = now()
  where id = target_comment_id
    and deleted_at is null;

  select count(*)
  into active_comment_count
  from public.session_comments c
  where c.session_id = target_session_id
    and c.user_id = target_user_id
    and c.is_application = true
    and c.deleted_at is null;

  if active_comment_count = 0 then
    update public.session_applications
    set
      status = 'canceled',
      canceled_at = now(),
      updated_at = now()
    where session_id = target_session_id
      and user_id = target_user_id
      and status in ('pending', 'accepted', 'rejected', 'waitlisted');
  end if;

  return query
  select
    target_comment_id,
    sa.status,
    active_comment_count = 0
  from public.session_applications sa
  where sa.session_id = target_session_id
    and sa.user_id = target_user_id;
end;
$$;
```

検討点:

- `accepted` も最後のコメント削除で `canceled` にするか
- GM削除と本人削除をログ上で区別するか
- 取消理由を保存するか
- 削除済みコメントの復元RPCを作るか

## 12. RLS / 権限設計

F-6では直接UPDATE / DELETEを広げず、RPCへ寄せる。

方針:

- 未ログインは編集・削除・取消できない
- playerは自分のコメントのみ編集・削除できる
- playerは他人のコメントを編集・削除できない
- playerは他人の申請状態を変更できない
- GMは自分のsessionに紐づくコメントのみ管理できる
- GMは他GMのsessionコメントを管理できない
- adminは全体操作可能にするか、devでは確認対象に留める

必要な追加確認:

- `update_application_comment` / `delete_application_comment_and_maybe_cancel` は `security definer` にする場合、`set search_path = ''`、入力検証、`revoke all` / `grant execute` を必須にする
- 関数内では `public.is_session_gm(session_id)` / `public.is_admin()` を使い、対象範囲を明示する
- `session_comments` への直接UPDATE権限を広げない
- `session_applications` への直接UPDATE権限を広げない

## 13. 集計RPCへの影響

既存の公開集計方針:

- `accepted_count`: `status = 'accepted'`
- `pending_count`: `status = 'pending'`
- `waitlisted_count`: `status = 'waitlisted'`
- `canceled` は除外

F-6で追加確認すること:

- `rejected` を人数に含めない
- `withdrawn` / `canceled` を人数に含めない
- 最後の有効コメント削除後に人数から外れる
- 同一ユーザー複数コメントでも1人分である

`withdrawn` を追加する場合の修正案:

```sql
-- Draft only. Do not run yet.
-- Existing counts already count by session_applications rows, one row per session_id + user_id.
-- If withdrawn is added, keep accepted/pending/waitlisted filters explicit and do not count withdrawn.
count(distinct sa.user_id) filter (where sa.status = 'accepted') as accepted_count
```

既存のようにstatusごとのfilterを明示していれば、`rejected` / `canceled` / `withdrawn` は参加人数に含まれない。

## 14. UI側への影響

本番 `session-detail.html` 統合時に必要なUI:

PL向け:

- コメント投稿
- 自分のコメント編集
- 自分のコメント削除
- 申請状態表示
- 最後のコメント削除時に申請取消になる旨の確認ダイアログ

GM向け:

- 参加希望コメント一覧
- 承認 / 却下
- コメント編集 / 削除
- 申請取消・取り消し操作
- 操作対象の明確な表示
- 操作後の再読込

共通:

- 確認ダイアログ
- 操作後の再読込
- エラー表示
- secretや内部IDを画面に出さない

この工程ではUI実装しない。

## 15. F-6ではまだ扱わないもの

- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- 実SQLのSupabase実行
- GitHub Pages本番ページへの導線追加

## 16. 次工程候補

- F-6設計書 commit / push
- F-6 RPC SQL草案ファイル作成
- RLS smoke testへのコメント削除・申請取消ケース追加
- dev配下でコメント編集・削除プロトタイプ作成
- `session-detail.html` 統合前の本番UX詳細設計

## 17. SQL草案ファイル

F-6 RPC SQL草案は以下に分離する。

```text
docs/supabase/sql/008_comment_management_rpc_draft.sql
```

このSQL草案は、`update_application_comment` と `delete_application_comment_and_maybe_cancel` の実行候補である。

注意:

- まだSupabase SQL Editorで実行しない
- 本番DBへ適用しない
- 実行前にRLS / SECURITY DEFINER / grant / revokeを再レビューする
- 実行後はRLS smoke testへ編集・削除・申請取消ケースを追加して確認する

## 18. SQL実行前レビュー計画

008草案をSQL Editorで実行する前のレビュー計画は以下に分離する。

```text
docs/supabase-f6-sql-execution-review-plan.md
```

この計画書では、実行前確認SQL、推奨実行順序、リスク、ロールバック方針、実行後検証項目、RLS smoke test更新要否を整理する。

注意:

- この計画書作成時点ではSQLを実行しない
- 本番ページ接続やdevプロトタイプ実装へは進まない
- 実行判断は計画書レビュー後に別工程で行う

## 19. SQL実行結果

F-6 SQL実行結果は以下に分離する。

```text
docs/supabase-f6-sql-execution-result.md
```

ユーザーがSupabase SQL Editorで実行済み。Codex自身はSQL Editorを実行していない。

実行済み:

- `edited_by` / `deleted_by` カラム追加
- `update_application_comment` 作成
- `delete_application_comment_and_maybe_cancel` 作成
- 操作RPCの `revoke all from public`
- 操作RPCの `grant execute to authenticated`

以降は、F-6 RLS smoke test更新、Auth文脈での編集・削除・取消テスト、devコメント編集・削除プロトタイプへ進む。
