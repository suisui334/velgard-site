# Supabase F-7 session-detail統合前UX設計

## 1. 目的

F-7は、Supabaseの参加希望コメント機能を本番 `session-detail.html` へ統合する前に、PL向け、GM向け、未ログイン向けの表示と操作を整理するためのUX設計である。

目的:

- 本番 `session-detail.html` へ参加希望コメント機能を統合する前のUXを固める。
- PL / GM / 未ログインで見える情報と操作を分ける。
- 参加希望コメントを参加申請の意思表示として扱う。
- コメント件数ではなく、`session_id + user_id` 単位で参加人数を数える。
- 同一ユーザーが複数コメントしても申請人数は1人分にする。
- 本番実装前に表示、操作、エラー、安全策を固定する。

この工程では、本番実装、追加SQL実行、`close_session`、Discord連携、通知、メール送信は行わない。

## 2. 現状整理

現行の `session-detail.html` は、`assets/js/main.js` から `renderSessionDetail.js` を呼び、静的 `data/sessions.json` のセッションを詳細表示している。

`sessionDisplay.js` には、ページ表示時だけ出る「参加希望コメント」パネルがある。現時点では投稿欄は準備中表示であり、Supabaseには接続していない。

現行方針:

- セッション本体の正本は当面 `data/sessions.json` のまま維持する。
- Supabaseは参加希望コメント、申請状態、人数集計を担当する。
- `sessions.id` は静的JSONとSupabase側で一致させる。
- `data/sessions.json` にあるDiscord ID風の値は公開JSON上に残っているが、本番Supabase表示用データへは混ぜない。

F-4〜F-6でdev確認済み:

| フェーズ | 確認済み内容 |
| --- | --- |
| F-4 | `create_application_comment` による参加希望コメント投稿、公開コメント再読込、参加人数RPC再読込 |
| F-5 | `set_application_status` によるGMの `accepted` / `rejected` 変更、人数RPC再読込 |
| F-6 | `update_application_comment` / `delete_application_comment_and_maybe_cancel` による編集・論理削除 |
| F-6 RLS smoke test | 通常実行 `PASS 29 / FAIL 0 / SKIP 10` |

## 3. 本番UIの基本方針

本番統合では、専用GM管理ページを前面に出さない。基本は `session-detail.html` の参加希望コメント欄へ統合する。

- GMはセッション詳細ページ上で参加希望コメントを確認、承認、却下、待機、編集、削除できる。
- PLは同じセッション詳細ページ上で参加希望コメントを投稿し、自分のコメントを編集・削除できる。
- 未ログインユーザーには閲覧中心で、投稿や編集はログイン案内にする。
- GM向け操作はGMにのみ表示する。
- admin操作は復旧・確認用途として扱い、通常UIへ強く出しすぎない。
- 参加希望コメントは公開申請欄として扱うが、内部 `user_id`、Discord ID、email、権限情報は出さない。

## 4. 状態別UI整理

| 対象者 / 状態 | 表示する情報 | 可能な操作 | 非表示にする情報 | 注意文 |
| --- | --- | --- | --- | --- |
| 未ログイン | セッション概要、公開コメント、参加人数、募集状態 | ログイン案内を見る | 内部ID、email、token、GM操作 | 投稿・編集にはログインが必要 |
| ログイン済みPL | セッション概要、公開コメント、参加人数、自分の表示名 | 申請可能sessionへ参加希望コメント投稿 | 他人の内部情報、GM操作 | コメントは公開申請欄に表示される |
| 自分がコメント済みのPL | 自分の申請状態、自分のコメント、公開コメント | 自分のコメント編集・論理削除、追加コメント投稿 | 他人の内部情報、GM操作 | 複数コメントしても人数は1人分 |
| 承認済みPL | 参加確定表示、自分のコメント、公開コメント | 自分のコメント編集。削除は強い注意付き | GM操作、内部ID | 最後の有効コメント削除で取消扱いの可能性 |
| 却下済みPL | 見送り表示、公開コメント | 新規投稿を許すかは運用判断。初期は案内中心 | GM操作、内部ID | 再申請可否はGM運用に従う |
| 待機中PL | キャンセル待ち表示、公開コメント | 自分のコメント編集・削除 | GM操作、内部ID | 繰り上がりはGM判断 |
| GM | 自分のセッションの申請一覧、公開コメント、申請状態、操作結果 | 承認、却下、待機、GM編集、GM削除、再読込 | token、secret、Discord ID、email | 操作対象と現在状態を確認してから実行 |
| admin | 管理確認用の状態、必要な操作UI | 全体確認・復旧候補。通常UIでは控えめに扱う | secret、token、DB password | 誤操作防止と監査方針が必要 |
| 満席 session | 満席表示、公開コメント、参加人数 | 新規申請不可。GM操作は可 | 投稿ボタン | 満席のため新規申請不可 |
| closed session | 募集締切表示、公開コメント、参加人数 | 新規申請不可。GM操作は可 | 投稿ボタン | 募集締切済み |
| private / hidden session | 無関係ユーザーには表示しない | 関係者・GM向けは別途設計 | コメント本文、人数、内部情報 | 現行公開RPCでは本文取得しない |

## 5. PL向けUX

PL向けの基本操作:

- 参加希望コメントを投稿する。
- 自分のコメントを編集する。
- 自分のコメントを削除する。
- 自分の申請状態を見る。
- 満席・締切・終了・中止時は投稿できない。
- 未ログイン時はログイン案内を表示する。
- 自分以外の内部情報は見せない。

PLに見せてよい情報:

- セッション名
- 開催日時
- GM表示名
- 参加人数
- 申請状態
- 公開コメント本文
- 表示名
- 投稿日時
- 編集日時

PLに見せない情報:

- `user_id` 全文
- `discord_user_id`
- email
- access token
- refresh token
- service role key
- 内部role

投稿欄の初期文言案:

```text
参加希望コメントは公開申請欄に表示されます。予定や相談内容に、公開したくない個人情報を含めないでください。
```

## 6. GM向けUX

GM向けの基本操作:

- 参加希望コメント一覧を見る。
- 申請者ごとの状態を見る。
- `pending` を `accepted` / `rejected` / `waitlisted` に変更する。
- コメントを管理編集する。
- コメントを論理削除する。
- 削除時に申請人数が変わる可能性を表示する。
- 承認済み申請の最後の有効コメント削除は強警告にする。

GMにだけ見せるもの:

- 承認ボタン
- 却下ボタン
- 待機ボタン
- GM編集ボタン
- GM削除ボタン
- 状態変更結果
- 操作エラー詳細

GMにも見せないもの:

- access token
- refresh token
- service role key
- secret key
- DB password
- `discord_user_id`
- email

GM操作の基本配置:

- コメント一覧の各コメント行に状態バッジを出す。
- GMの場合のみ、行内または折りたたみ操作欄に承認・却下・待機・編集・削除を出す。
- 誤操作防止のため、状態変更と削除は確認ダイアログを必須にする。

## 7. コメント削除UX

削除は論理削除として扱う。削除後、通常の公開コメント一覧からは消える。

削除時の基本方針:

- 削除前に確認ダイアログを出す。
- 削除対象のセッション名、コメントID、現在の申請状態を表示する。
- 削除は論理削除であり、画面上では元に戻さないことを説明する。
- 最後の有効申請コメント削除時は申請取消扱いになる。
- 承認済み申請の最後の有効コメント削除は原則避ける。
- GM削除とPL本人削除の文言を分ける。

PL本人削除の文言案:

```text
このコメントを削除します。最後の有効な参加希望コメントの場合、参加申請が取消扱いになり、参加人数から外れる可能性があります。
```

GM削除の文言案:

```text
GM権限でこのコメントを削除します。削除後、参加申請人数から外れる場合があります。対象者と申請状態を確認してください。
```

承認済み申請向け強警告:

```text
この申請は参加確定済みです。最後の有効コメントを削除すると、申請が取消扱いになる可能性があります。原則としてこの操作は避け、必要な場合は参加者と確認してから実行してください。
```

## 8. 申請状態の表示文言

| 内部状態 | PL向け文言 | GM向け文言 | 人数に含めるか | 備考 |
| --- | --- | --- | --- | --- |
| `pending` | 申請中 | 申請中 | pending_count | 初期申請状態 |
| `accepted` | 参加確定 | 承認済み | accepted_count | 参加人数に含める |
| `rejected` | 見送り | 却下 | 含めない | 再申請可否は運用判断 |
| `waitlisted` | キャンセル待ち | 待機 | waitlisted_count | 参加枠とは別表示 |
| `canceled` | 申請取消 | 取消済み | 含めない | 最後の有効コメント削除など |
| `closed` | 募集締切 | 募集締切 | セッション状態 | 新規投稿不可 |
| `full` | 満席 | 満席 | セッション状態 | 新規投稿不可 |

`finished` / `canceled` のセッション状態も新規投稿不可とする。

## 9. データ取得・RPC方針

本番統合時に使う既存RPC:

| 用途 | RPC |
| --- | --- |
| 公開コメント表示 | `get_public_session_comments(target_session_id)` |
| 参加人数表示 | `get_public_session_application_counts(target_session_id)` |
| 参加希望コメント投稿 | `create_application_comment(target_session_id, comment_body)` |
| GM承認・却下・待機 | `set_application_status(target_application_id, new_status)` |
| コメント編集 | `update_application_comment(target_comment_id, comment_body)` |
| コメント論理削除・必要時取消 | `delete_application_comment_and_maybe_cancel(target_comment_id)` |

検討が必要なもの:

- GM用コメント一覧RPC / view。
- private / hidden session のGM向け本文取得。
- `session_applications.comment_id` / `status` / `application_id` の安全な取得方法。
- public RPCだけでは足りない項目の補完方法。
- admin復旧用の表示を本番UIに出すか、別運用にするか。

現行RPCで不足する可能性:

- 公開コメントRPCは公開表示用であり、private / hidden のコメント本文管理には使わない。
- GM操作には `application_id` が必要なため、GM向けに安全なapplication/comment一覧取得が必要になる可能性がある。
- 既存のdevプロトタイプでは、RLS上見える `session_applications` と公開コメントRPCを突き合わせていた。本番ではこの方針をそのまま使えるか再確認する。

## 10. エラー表示方針

エラーは人間向けの短い理由を主表示にし、開発確認が必要な場合だけ安全な補足を出す。

| 状態 | 表示文言案 |
| --- | --- |
| 未ログイン | 投稿・編集にはログインが必要です。 |
| 権限なし | この操作を行う権限がありません。 |
| 満席 | このセッションは満席のため、新規申請できません。 |
| 募集締切 | このセッションは募集を締め切っています。 |
| コメント空欄 | コメント本文を入力してください。 |
| コメント長すぎ | コメント本文が長すぎます。短くして再度お試しください。 |
| 削除済みコメント編集 | このコメントは削除済みのため編集できません。 |
| ネットワークエラー | 通信に失敗しました。時間をおいて再度お試しください。 |
| Supabase RPCエラー | 処理に失敗しました。状態を再読込してから再度お試しください。 |

エラー表示で出さないもの:

- token
- key
- secret
- UUID全文
- email
- 内部SQL
- Project URL全文

## 11. 段階統合方針

本番実装は一気に行わない。段階導入で切り分ける。

| 段階 | 内容 |
| --- | --- |
| F-7a | `session-detail.html` 統合UX設計 |
| F-7b | ログイン状態表示のみ本番ページに仮統合 |
| F-7c | 公開コメント読み取りのみ統合 |
| F-7d | ログインPLの投稿統合 |
| F-7e | 自分のコメント編集・削除統合 |
| F-7f | GM承認・却下統合 |
| F-7g | GMコメント管理統合 |

各段階で確認すること:

- 本番ページの静的表示が壊れない。
- Supabase接続失敗時に最低限のセッション詳細が残る。
- secretや内部IDが画面・ログ・Gitに出ない。
- RLS smoke test `FAIL 0` を維持する。

## 12. 本番統合前の必須条件

本番 `session-detail.html` 統合前に、以下を満たす。

- RLS smoke test `FAIL 0`。
- F-4 / F-5 / F-6 devプロトタイプ確認済み。
- 本番UI文言確定。
- ログイン導線設計。
- GM表示条件の確定。
- 削除確認文言の確定。
- private / hidden session の方針確定。
- Supabase anon / publishable key の扱い確定。
- GitHub Pages上での環境値管理方針確定。
- ロールバック方針。
- 本番接続前に、`service_role` / secret keyをフロントへ置かないことを再確認。

## 13. F-7 UX設計では扱わないもの

この設計書では、以下を扱わない。

- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin専用本番管理画面
- `RUN_DESTRUCTIVE_TESTS=true` の実行
- 追加SQL実行

## 14. 次工程候補

次工程候補:

1. F-7 UX設計書のcommit / push
2. F-7b ログイン状態表示のみの統合設計またはdev確認
3. F-7c 公開コメント読み取り統合の小さな実装計画
4. GM用コメント一覧RPC / view要否の最終判断
5. 本番統合前のrollback手順整理
