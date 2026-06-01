# Supabase M-11E-5 GM向け申請履歴UI器 実装結果

作業日: 2026-06-01

## 1. 記録範囲

`session-detail.html` の参加希望コメント欄に、GM/adminだけが見られる申請履歴折りたたみUIの器を追加した。

この工程では、SQL Editor実行、DB変更、`get_gm_session_application_history` 呼び出し、GM承認 / 却下実装、Discord IDコピー実装、`updates.json` 変更、commit / pushは行っていない。

## 2. 実装したこと

- `assets/js/sessionDisplay.js` にGM履歴UI差し込み先を追加した。
- `assets/js/sessionDetailApplicationComments.js` でログイン済みユーザーだけ `is_admin()` と `is_session_gm(target_session_id text)` を確認するようにした。
- どちらかが `true` の場合だけ、折りたたみUIを表示する。
- 折りたたみUIは初期状態で閉じている。
- 開いた中身はプレースホルダー文言だけを表示する。
- `assets/css/style.css` にGM履歴UI器の控えめな表示スタイルを追加した。
- `session-detail.html` / `assets/js/main.js` / `assets/js/renderSessionDetail.js` のキャッシュ用クエリ文字列を更新した。

## 3. GM/admin判定

判定に使うRPC:

```text
is_admin()
is_session_gm(target_session_id text)
```

表示条件:

- ログイン済みであること。
- `is_admin()` または `is_session_gm(sessionId)` が `true` であること。

判定RPCのどちらかが失敗した場合でも、成功した側が `true` なら表示する。両方が失敗または `false` の場合は表示しない。未ログイン、ログイン状態不明、通常PLでは表示しない。

## 4. UI配置

参加希望コメント欄のコメント一覧直下、人数注記の上に配置した。

```text
参加希望コメント
  投稿 / 本人申請状態
  申請中 / 承認済みカウント
  コメント一覧
  GM向け：申請履歴を見る
  人数注記
```

## 5. 折りたたみUIの仕様

表示文言:

```text
GM向け：申請履歴を見る
```

初期状態:

```text
閉じている
```

開いた中身:

```text
申請履歴の読み込みは次工程で実装予定です。
```

今回のUI器には実データを表示しない。

## 6. 呼び出していないもの

今回のフロント実装では、次を呼び出していない。

```text
get_gm_session_application_history
set_application_status
close_session
```

## 7. 表示しない情報

今回のUI器には、次の情報を表示しない。

```text
email
user_id
application_id
comment_id
Discord ID
token
key
secret類
gmUserId
```

## 8. 既存機能への影響

既存の参加希望コメント機能は維持する方針。

- コメント一覧。
- コメント新しい順。
- コメント投稿。
- コメント編集。
- コメント削除。
- 申請取り下げ。
- 再申請。
- 申請中 / 承認済みカウント。
- 本人申請状態表示。

## 9. 次工程

次工程で、GM/admin向け折りたたみUIを開いた時に `get_gm_session_application_history(target_session_id text)` を接続し、返却契約7列だけを使って履歴一覧を表示する。

GM承認 / 却下、Discord IDコピー、完全な状態遷移監査ログは別工程で扱う。
