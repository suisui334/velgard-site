# M-15H GM向けテンプレ変数置換UI

M-15Hでは、`session-detail.html` のGM/admin向け管理領域に、呼び出し文用のテンプレ変数置換UIを追加する。

第一段階ではテンプレート保存機能は扱わない。DB保存、localStorage保存、DB構造変更、RPC変更、Discord実送信、Edge Function deployは行わない。

## 表示対象

UIはGM/admin権限確認後の管理領域にのみ表示する。通常PL、未ログイン閲覧者、権限のないユーザーには表示しない。

## 対応変数

```text
{{session_title}}
{{approved_call_list}}
{{approved_pc_names}}
```

`{{session_title}}` は現在のセッション名に置換する。

`{{approved_call_list}}` は、M-15Gで確定したGM/admin向け承認済み参加者連絡先と同じラベル付き形式で出力する。

```text
Discord：<@123456789012345678>｜ユーザー名：ゼウス｜PC名：ハリーポッター
Discord：登録されていません｜ユーザー名：ボボボーボ・ボーボボ｜PC名：PC名未登録
```

Discord未登録または形式不正時は `Discord：登録されていません` とし、不正な `discord_handle` 生値は表示・コピーしない。

`{{approved_pc_names}}` は承認済み参加者のPC名だけを `、` 区切りで出力する。PC名未登録は `PC名未登録` とする。

```text
ハリーポッター、PC名未登録
```

承認済み参加者がいない場合、`{{approved_call_list}}` は既存連絡先UIに合わせて `承認済み参加者はまだいません` とする。`{{approved_pc_names}}` は空扱いとし、`PC名未登録` は出さない。

## 実装方針

表示・コピーの形式ズレを避けるため、`{{approved_call_list}}` は既存の `formatGmContactLine` / `formatGmContactCopyText` を再利用する。

承認済み参加者データは既存RPC `get_gm_session_accepted_contacts(text)` を利用する。フロントからDB直UPDATE / DELETEは行わない。

raw user_id / email / token / selected_character_id / application_id は画面、DOM、console、docsに出さない。内部IDやemailを代替表示にも使わない。

## 今回行わないこと

- SQL Editor実行
- DB構造変更
- RPC変更
- Discord実送信
- Edge Function deploy
- テンプレート保存機能
- localStorage保存
- `updates.json` 変更
- commit / push
