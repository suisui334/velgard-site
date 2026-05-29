# Supabaseフロント連携設計書

## 1. 目的

この資料は、Supabase連携を公開サイトへ入れる前に、フロント側の影響範囲と接続順序を整理するための設計書である。

目的:

- Supabase連携を公開サイトへ入れる前に、影響範囲を整理する。
- `session-detail.html` の参加希望コメントUIを、将来的に実投稿可能にする。
- 静的 `data/sessions.json` とSupabase `sessions` の関係を整理する。
- 既存のGitHub Pages公開版を壊さない。
- RLSテスト済みの範囲と未確認範囲を明確にする。
- `service_role` / secret key をフロントへ絶対に置かない。

現時点では、本番公開ページへSupabase接続コードを追加しない。

## 2. 現時点で接続しない理由

RLSスモークテストは `PASS 19 / FAIL 0 / SKIP 1` まで通過しているが、公開サイトへ接続するにはまだ不足がある。

- 認証UIがまだない。
- 投稿失敗時のUIが未設計。
- GM承認・却下画面が未設計。
- admin操作画面が未設計。
- 既存 `sessions.json` とDBの正本関係が未確定。
- コメント投稿後の画面更新方法が未確定。
- ログアウト / セッション維持の扱いが未確定。
- レート制限・連投対策が未設計。
- Discord IDの公開・非公開境界が未確定。
- 本番用ロール付与運用が未確定。
- 破壊的な `close_session` 成功系は、通常スモークテストでは意図的にSKIPしている。

## 3. 推奨接続方針

いきなり `session-detail.html` 本体へ接続しない。

推奨フェーズ:

```text
Phase F-0：フロント連携設計書作成
Phase F-1：ローカル専用の開発用ページまたは開発用JSでSupabase読み取りだけ試す
Phase F-2：公開セッション一覧の読み取りプロトタイプ
Phase F-3：ログイン状態表示プロトタイプ
Phase F-4：参加希望コメント投稿プロトタイプ
Phase F-5：GM承認・却下プロトタイプ
Phase F-6：本番ページ統合の可否判断
```

まずは読み取り専用プロトタイプを推奨する。

理由:

- 現行の公開サイトは静的表示として安定している。
- 認証・投稿・権限操作を同時に入れると原因切り分けが難しい。
- `sessions.json` とDBの正本関係を急に切り替えると、カレンダーと詳細ページの両方に影響する。
- 公開ページ統合は、失敗時UIとfallback設計が固まってから行う方が安全。

## 4. データ正本の整理

### 案1：当面は `data/sessions.json` を正本のまま維持

内容:

- 既存カレンダーと `session-detail.html` は引き続き `data/sessions.json` を読む。
- Supabaseは参加希望コメント、申請状態、参加人数集計を担当する。
- `sessions.id` は静的JSONとSupabase側で一致させる。
- セッション作成・編集はまだ静的ファイル運用にする。

良い点:

- 既存サイトが安定する。
- カレンダー表示、詳細表示、日付保持の既存挙動を壊しにくい。
- Supabase連携の影響範囲をコメント申請まわりに限定しやすい。

注意点:

- 静的 `sessions.json` とSupabase `sessions` のID同期が必要。
- セッション本体の編集はまだDB化されない。
- GM編集や〆ボタンの本格運用には、将来正本切り替えが必要になる。

### 案2：Supabase `sessions` を正本にする

内容:

- カレンダーと詳細ページがSupabase `sessions` を読む。
- `data/sessions.json` はバックアップまたは初期データ扱いにする。

良い点:

- 将来の動的管理に向く。
- GM編集、〆ボタン、Discord同期と接続しやすい。

注意点:

- 既存カレンダーと詳細ページの改修範囲が大きい。
- GitHub Pagesだけでは管理画面が足りない。
- 認証UI、管理UI、fallback、エラー表示まで同時に考える必要がある。

結論:

現時点では案1を推奨する。まず `data/sessions.json` を正本のまま維持し、Supabaseは参加希望コメントと申請状態のプロトタイプに限定する。

## 5. フロント接続時の影響範囲

将来の候補ファイル:

```text
session-detail.html
assets/js/renderSessionDetail.js
assets/js/sessionDisplay.js
assets/js/supabaseClient.js（新規候補）
assets/js/sessionApplications.js（新規候補）
assets/js/main.js
calendar.html
assets/js/renderCalendar.js
data/sessions.json
```

想定:

- `session-detail.html` は既存ページ枠を維持する。
- `renderSessionDetail.js` は静的セッション詳細表示と、将来の申請コメント欄初期化の入口になる候補。
- `sessionDisplay.js` は表示整形の共通ロジックを維持し、DB取得処理を直接混ぜない。
- `supabaseClient.js` は将来作る場合も、publishable / anon相当のkeyだけを扱う。
- `sessionApplications.js` は参加希望コメント、申請状態、参加人数表示を担当する候補。
- `renderCalendar.js` は当面Supabaseへ接続しない。
- `data/sessions.json` は当面正本として維持する。

今回の工程では、上記ファイルの作成・編集は行わない。

## 6. 認証UI方針

### 案A：簡易メールログインUI

内容:

- PLがメール・パスワードでログインする。
- Supabase Authのメールログインを前提にする。

良い点:

- ローカルプロトタイプで検証しやすい。
- Auth文脈RLSスモークテストの前提と近い。
- 身内向け運用に限定しやすい。

注意点:

- UIがやや無骨。
- パスワード管理、パスワードリセット、説明文が必要。
- 実メールをどう扱うかの運用が必要。

### 案B：Discord OAuth

内容:

- Discordアカウントでログインする。
- Discord IDとの紐づけをOAuth由来に寄せる。

良い点:

- ヴェルガルド運用と相性が良い。
- Discord IDの手入力より本人性を確保しやすい。

注意点:

- OAuth設定、Redirect URL、個人情報、Discord ID管理が絡む。
- 本番公開URLや開発URLの整理が必要。
- いま入れるには範囲が大きい。

結論:

現時点ではメールログインのローカルプロトタイプを優先する。Discord OAuthは後回しにする。

## 7. 投稿UI方針

既存の `session-detail.html` には、静的な「参加希望コメント」UIがある。将来はこの欄を実投稿可能にする。

想定表示:

- 未ログイン時: ログイン案内を表示する。
- ログイン済み: コメント入力欄を有効化する。
- 投稿成功: コメント欄を再読込、または即時反映する。
- 投稿失敗: エラー内容を人間向けに表示する。
- `full` / `closed` / `finished` / `canceled`: 投稿不可にする。
- private / hidden: 無関係ユーザーには表示しない。
- 同一ユーザーの複数コメント: コメントは増えても参加人数は1人扱い。
- 参加人数表示: `session_applications` ベースにする。
- コメント本文: 公開申請欄扱いにする。
- 内部 `user_id` / `discord_user_id`: フロント表示用データへ出さない。

投稿UIで必要な状態:

```text
loading
logged-out
logged-in-can-post
logged-in-cannot-post
posting
post-success
post-error
closed-or-full
```

投稿失敗時に出すべき内容:

- 申請可能状態ではない。
- ログインが切れている。
- 権限がない。
- 通信に失敗した。
- 入力が空、または長すぎる。

ログにはProject URL、key、password、token類を出さない。

## 8. 読み取り専用プロトタイプ案

Phase F-1 / F-2では、投稿処理を入れず、読み取りだけを確認する。

読み取り候補:

- public session一覧。
- public application counts。
- public comments RPC。
- public profiles。

確認したいこと:

- `anon` で読める範囲が想定どおりか。
- private / hidden が漏れないか。
- `discord_user_id` が出ないか。
- 内部 `user_id` がコメント表示に出ないか。
- `sessions.json` とSupabase `sessions.id` の対応を取れるか。

読み取り専用プロトタイプは、公開サイト本体ではなくローカル専用ページまたは開発用JSで試す。

## 9. 本番接続前チェック

`docs/supabase-production-connection-checklist.md` と整合させ、以下を本番接続前の必須条件とする。

- RLS smoke test PASSを維持する。
- `.env.local` をGitに入れない。
- `service_role` / secret keyを使わない。
- フロント候補はpublishable / anon keyのみ。
- 投稿失敗時UIを作る。
- ロールバック手順を決める。
- まずローカル・開発ページで試す。
- 公開ページ統合は最後にする。
- Discord IDを公開view / public RPC / public JSONレスポンスに出さない。
- コメント件数を参加人数として扱わない。
- `full` / `closed` / `finished` / `canceled` への新規申請を止める。

## 10. まだやらないこと

- GitHub Pages本体へのSupabase接続。
- `assets/js` へのSupabase client追加。
- `session-detail.html` への実投稿処理追加。
- `calendar.html` / `renderCalendar.js` のDB読み込み化。
- Supabase上での追加SQL実行。
- API key / Project URL / secret類の記録。
- Discord bot / Webhook / Edge Functions。
- GM承認・却下UIの実装。
- admin管理UIの実装。

## 11. 推奨結論

次に進めるなら、まず本番ページ接続ではなく、ローカル専用の読み取りプロトタイプ設計または実装に進む。

推奨順:

1. 読み取り専用プロトタイプの対象RPC / tableを決める。
2. ローカル専用ページまたは開発用JSの置き場所を決める。
3. publishable / anon keyだけで読める範囲を確認する。
4. `session-detail.html` に組み込む前に、失敗時UIとfallbackを設計する。

公開ページへの統合判断は、読み取り、ログイン状態表示、投稿、GM操作を段階的に試したあとに行う。
