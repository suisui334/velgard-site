# Supabase M-10 follow-up ID整合検証データ投入結果

作業日: 2026-05-31

## 対象セッション

- 公開セッションID: `session-2026-06-08-railway-incident`
- 公開JSON側タイトル: 灰壁線異常調査

## DB投入結果

M-10 follow-upとして、ユーザーがSupabase SQL EditorでID整合検証データを投入した。Codexはこの工程でSQL Editorを実行していない。

投入後のcount確認:

- `public.sessions`: 1
- `public.session_comments`: 1
- `public.session_applications` for test player: 1

実UUID、実email、secret、key、tokenはこのdocsに記録しない。SQL Editor上で置換した実UUIDも記録しない。

## 公開版 mypage 確認結果

GitHub Pages公開版の `mypage.html` で以下を確認した。

- 参加申請中に「灰壁線異常調査」が表示される。
- 「非公開または未同期のセッション」ではなく、公開JSONに突合した表示になる。
- `詳細を見る` が表示される。
- `詳細を見る` から `session-detail.html?id=session-2026-06-08-railway-incident` に遷移する。
- email / user_id / token / key / gmUserId は画面に出ていない。
- console error はない。

## 注意

- `010_mypage_applications_id_aligned_test_data_draft.sql` はM-10 ID整合検証で使用済み。同じSQLを再実行しない。
- 再確認が必要な場合も、まず対象データの有無とcountを確認し、重複投入しない。
- cleanupはまだ実行していない。
- 検証データを残すか削除するかは別工程で判断する。
