# Supabase M-11F GM承認 / 却下 smoke test追加結果

作業日: 2026-06-01

## 1. 記録範囲

`scripts/supabase-rls-smoke-test.mjs` に、GM承認 / 却下UIで使う `set_application_status(target_application_id uuid, new_status text)` まわりの明示的なM-11F smoke test観点を追加した。

この工程では、DB接続を伴う smoke test 本体実行、Supabase SQL Editor実行、DB構造変更、本番フロント実装、`updates.json` 変更、commit / pushは行っていない。

## 2. 追加したテスト観点

追加ID:

```text
M11F-APPROVE-001 anon cannot set application status
M11F-APPROVE-002 normal player cannot set application status
M11F-APPROVE-003 other GM cannot set application status for another GM session
M11F-APPROVE-004 target GM can set own session application status if safe fixture exists
M11F-APPROVE-005 admin can set application status if safe fixture exists
M11F-APPROVE-006 invalid application status is rejected
M11F-APPROVE-007 application status RPC errors do not expose raw internal identifiers
```

拒否系:

- anonによる状態変更は失敗する。
- 通常PLによる状態変更は失敗する。
- 他GMによる別GMセッション申請の状態変更は失敗する。
- 不正statusは失敗する。

内部情報非露出:

- M-11F関連の失敗RPCから得たエラー整形結果に、生のUUID形式、email、JWT、Supabase URL、長いkey/tokenらしき文字列が混ざらないことを確認する。
- 実際の `application_id` / `comment_id` / `user_id` 実値はログやdocsへ記録しない。

## 3. 成功系の扱い

`M11F-APPROVE-004` と `M11F-APPROVE-005` はSKIPにした。

理由:

- `set_application_status` の成功系は `session_applications.status` を変更する。
- 現在の再利用fixtureには、通常実行で安全に状態変更して自動復旧できる専用の使い捨て申請行がない。
- 既存の `AUTH-014` にはGM Aによる状態変更確認が残っているが、今回のM-11F追加分では、さらに通常実行の状態変更を増やさない方針にした。
- admin成功系も同様に、専用の状態リセットfixtureがないためSKIPとした。

将来、状態リセット可能な専用fixtureを用意した場合に、`RUN_DESTRUCTIVE_TESTS` 条件つき、またはfixture復旧つきで成功系を再検討する。

## 4. 実行結果

実行した確認:

```powershell
node --check scripts/supabase-rls-smoke-test.mjs
```

結果:

```text
成功
```

実行していないこと:

- `node scripts/supabase-rls-smoke-test.mjs` の本体実行。
- `RUN_DESTRUCTIVE_TESTS=true` での実行。
- Supabase SQL Editor実行。
- DB変更。

## 5. 秘密情報の扱い

この工程では、secret、key、token、email、`user_id` 全文、`application_id` 実値、`comment_id` 実値を出力・記録していない。
