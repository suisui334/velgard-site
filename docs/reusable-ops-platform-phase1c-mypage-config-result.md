# Reusable Ops Platform Phase 1-C Mypage Config Result

## 背景

Phase 1-Bでは、`mypageAuthClient.js` が通常scriptとして読み込まれており、ES moduleの `assets/js/reusableOpsConfig.js` を直接importするには影響範囲が大きいと判断して、mypage本体への接続を見送った。

Phase 1-Cでは、mypageを将来の汎用TRPG運用基盤として切り出しやすくするため、認証・権限・RPC処理を変えずに、表示ラベルだけを安全に設定参照へ寄せる最小実装を行った。

## 実装方針

- `mypageAuthClient.js` は通常scriptのまま維持した。
- module化、フォルダ再編、独立アプリ化は行っていない。
- `assets/js/reusableOpsMypageLabels.js` を追加し、mypage用の安全な表示ラベルだけを `window.VELGARD_REUSABLE_OPS_MYPAGE` として公開した。
- `mypage.html` では `mypageAuthClient.js` より前に `reusableOpsMypageLabels.js` を読み込む。
- bridgeが未読込、または値が空の場合は、`mypageAuthClient.js` 内の既存fallback文言を使う。
- `assets/js/reusableOpsConfig.js` には、mypage summary用の候補値とgetterを追加した。

## 接続した値

今回、実表示で設定参照にしたのは以下のmypage見出しと短い補足のみ。

- `アカウント概要`
- `ログイン中`
- `プロフィール / PC情報`
- `PC名・Discord ID`
- `予定 / 申請履歴`
- `読み込み中`
- `テンプレート管理`
- `保存済みテンプレート`
- `会員管理`

表示結果は従来と同じになるよう、設定値とfallbackを同じ文言にしている。

## 触っていない範囲

- 認証処理。
- approved gate判定。
- membership status判定。
- 会員管理RPC呼び出し。
- `management_key` の保持・参照・非表示方針。
- 承認/却下/manager付与/剥奪などの状態変更ボタン文言。
- エラー文言。
- session-post / session-detail のフォーム処理。
- Discord同期処理。
- DB/RPC/RLS、SQL、Edge Function、Discord操作。

## リスク管理

- `management_key`、raw user_id、email、token、URL全文、secretは設定ファイルにも画面にも出していない。
- 設定化したのは表示ラベルだけであり、RPC名やDBカラム名は設定化していない。
- bridgeはclassic script専用の薄い入口なので、既存のmypage初期化順を大きく変えない。
- 将来はsource of truthを1つに寄せる必要があるが、今回は通常scriptのmypageを安全に接続することを優先した。

## 未実施

- `membershipAccessClient.js` のapproved gate文言接続。
- mypage会員管理の操作ボタン文言接続。
- session-post / session-detail のラベル接続。
- `mypageAuthClient.js` のES module化。
- `assets/js/core/` 等へのフォルダ分離。

## 次候補

1. `membershipAccessClient.js` のapproved gate見出し・案内文を設定参照へ寄せる。
2. mypage会員管理の状態表示ラベルだけを設定参照へ寄せる。
3. session-post / session-detail の見出しやフォームラベルを、RPCや権限に触れない範囲で設定参照へ寄せる。
4. Phase 2で、classic bridgeとmodule configの二重管理を解消する設計を行う。

## QA観点

- mypageが開く。
- ログイン済みmypageで主要details見出しが従来どおり表示される。
- `reusableOpsMypageLabels.js` が読めない場合でもfallback文言でmypageが壊れない。
- 会員管理UIが従来どおり表示・操作できる。
- 認証、権限、RPC、DB、Discord同期に変更がない。
