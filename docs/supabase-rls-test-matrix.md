# Supabase RLSテストケース表

この表は、Supabase FreeプロトタイプでSQL/RLSを実行した後に確認するためのテストマトリクスである。実プロジェクトURL、API key、secret、実メール、実Discord IDは記載しない。

| テストID | 前提ロール | 対象操作 | 期待結果 | 失敗時の危険度 | 備考 |
| --- | --- | --- | --- | --- | --- |
| RLS-001 | guest / anon | public sessionを読む | 成功 | 中 | `visibility = 'public'` のみ |
| RLS-002 | guest / anon | private sessionを読む | 失敗 | 高 | private予定漏洩 |
| RLS-003 | guest / anon | hidden sessionを読む | 失敗 | 高 | hidden予定漏洩 |
| RLS-004 | anon | `user_roles` を読む | 失敗 | 高 | 権限情報漏洩 |
| RLS-005 | anon | `profiles.discord_user_id` を読む | 失敗 | 高 | Discord ID漏洩 |
| RLS-006 | anon | `public_profiles` を読む | `id` / `display_name` のみ成功 | 中 | Discord IDを含めない |
| RLS-007 | authenticated player | open sessionにコメント申請 | 成功 | 高 | `create_application_comment()` |
| RLS-008 | authenticated player | full sessionにコメント申請 | 失敗 | 高 | 満席状態の新規申請停止 |
| RLS-009 | authenticated player | closed sessionに申請 | 失敗 | 高 | 〆後申請停止 |
| RLS-010 | authenticated player | finished sessionに申請 | 失敗 | 高 | 終了後申請停止 |
| RLS-011 | authenticated player | canceled sessionに申請 | 失敗 | 高 | 中止後申請停止 |
| RLS-012 | authenticated player | 同一sessionに追加コメント | commentは増えるがapplicationは1件 | 高 | 申請者単位カウント |
| RLS-013 | authenticated player | 自分のコメント本文を読む | 成功 | 中 | 投稿者本人 |
| RLS-014 | authenticated player / anon | public sessionの他人コメントを表示用RPCで読む | 成功 | 中 | 公開申請欄として扱う。内部user_idは返さない |
| RLS-015 | GM | 自分のsessionのコメント本文を読む | 成功 | 中 | 対象セッションGM |
| RLS-016 | unrelated player / anon | private / hidden sessionのコメント本文を読む | 失敗 | 高 | 非公開予定のコメント漏洩防止 |
| RLS-017 | anon | `create_application_comment()` を実行 | 失敗 | 高 | RPC execute不可 / auth.uid() null拒否 |
| RLS-018 | authenticated player | `session_comments` に直接insert | 失敗 | 高 | 投稿はRPC経由 |
| RLS-019 | authenticated player | `session_applications` に直接insert | 失敗 | 高 | application作成はRPC経由 |
| RLS-020 | authenticated player | 自分のコメントを編集 | 成功 | 中 | `edit_comment()` |
| RLS-021 | authenticated player | 他人コメントを直接update | 失敗 | 高 | 他人データ改変防止 |
| RLS-022 | authenticated player | 他人applicationを直接update | 失敗 | 高 | 他人申請改変防止 |
| RLS-023 | authenticated player | 自分をadmin/gm化 | 失敗 | 高 | `user_roles` 書換禁止 |
| RLS-024 | authenticated player | 自分の申請をcanceledにする | 成功 | 中 | `cancel_application()` |
| RLS-025 | authenticated player | `set_application_status()` で自分の申請をacceptedにする | 失敗 | 高 | GM/admin操作のみ |
| RLS-026 | authenticated player | `close_session()` を実行 | 失敗 | 高 | GM/admin操作のみ |
| RLS-027 | GM | 自分のsession申請をacceptedにする | 成功 | 中 | `set_application_status()` |
| RLS-028 | GM | 他GMのsession申請を変更 | 失敗 | 高 | 他GM領域保護 |
| RLS-029 | GM | 自分のsessionをclosedにする | 成功 | 中 | `close_session()` |
| RLS-030 | GM | 他GMのsessionをclosedにする | 失敗 | 高 | 他GM領域保護 |
| RLS-031 | GM | finished/canceledをclosedにする | 失敗 | 中 | 状態遷移制御 |
| RLS-032 | admin | 全件管理 | 成功 | 中 | adminのみ |
| RLS-033 | anon | public count RPCを見る | public session人数のみ | 中 | 個票は返さない |
| RLS-034 | anon | private / hidden session人数を見る | 返らない | 高 | 人数漏洩防止 |
| RLS-035 | anon | `public_profiles` の列を確認 | `id` / `display_name` のみで `discord_user_id` がない | 高 | 列レベル漏洩確認 |
| RLS-036 | public comment表示 | コメント表示用RPCの返却列を確認 | 表示名、申請状態、本文、投稿/更新日時程度で、Discord IDや内部user_idを含まない | 高 | `get_public_session_comments()` などで確認 |
| RLS-037 | フロント想定権限 | service role key相当の高権限キーなしで操作 | 必要な操作のみ成功 | 高 | 高権限キーをフロントに置かない |
| RLS-038 | リポジトリ確認 | secret / API key / tokenが混入していないか検索 | 実値なし | 高 | 説明語の出現と実値を区別 |

## 実行時メモ

- まずanonで読める範囲を確認する
- 次にplayerで自分のコメント・申請だけ扱えることを確認する
- GMテストでは自分のsessionと他GMのsessionを必ず分ける
- adminテストは最後に行う
- 1件でも高危険度の失敗が出たら、本番接続へ進まない
