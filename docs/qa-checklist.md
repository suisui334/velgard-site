# QAチェックリスト

## 基本確認
- [ ] data/*.json のJSONパース確認
- [ ] assets/js/*.js のJS構文チェック
- [ ] 各HTML主要ページのHTTP 200確認
- [ ] ブラウザコンソールに重大エラーが出ていないこと

## 表示確認
- [ ] index.html が表示される
- [ ] world.html に8章が表示される
- [ ] spots.html に8件表示される
- [ ] characters.html に公式NPC20名が表示される
- [ ] scenarios.html が SCENARIOS / シナリオとして表示される
- [ ] scenarios.html に配布予定シナリオ準備中カード7件が表示される
- [ ] hooks.html が SCENARIOS / シナリオとして表示される
- [ ] hooks.html に配布予定シナリオ準備中カード7件が表示される
- [ ] scenario-detail.html で個別シナリオ準備中ページが表示される
- [ ] terms.html に35件表示される
- [ ] campaigns.html にキャンペーン一覧が表示される
- [ ] campaign-detail.html?id=velgard-open-campaign が表示される
- [ ] episode-detail.html で episode-01〜03 が表示される
- [ ] regulation.html が準備中ではなく正式規約ページとして表示される
- [ ] gallery.html に画像ギャラリー41件が表示される
- [ ] updates.html が表示される
- [ ] index.html に最新更新履歴が表示される

## 機能確認
- [ ] spots.html のカテゴリフィルターが動作する
- [ ] characters.html の地域フィルターが動作する
- [ ] scenarios.html のシナリオ準備中カード表示が破綻していない
- [ ] hooks.html の互換入口表示が破綻していない
- [ ] gallery.html のカテゴリフィルターが動作する
- [ ] terms.html の検索が動作する
- [ ] terms.html のカテゴリフィルターが動作する
- [ ] relatedSpots が実名表示される
- [ ] relatedCharacters が実名表示される
- [ ] campaign-detail.html の導線が動作する
- [ ] episode-detail.html の前後リンクが動作する

## トップページ確認
- [ ] トップページが作品公式サイト風レイアウトになっている
- [ ] 基本情報カードが表示されていない
- [ ] コンセプトカードが表示されていない
- [ ] 長い説明カードが表示されていない
- [ ] Campaign Trailer 系の表示がトップから外れている
- [ ] 左側に正式ロゴ画像が表示される
- [ ] 「灰壁の向こうに、花霧はまだ揺れている。」が表示されない
- [ ] 左側に縦型ナビゲーションが表示される
- [ ] 右側に `key-visual-main.png` が大きく表示される
- [ ] トップページにキービジュアルが表示される
- [ ] キービジュアルが極端に切り抜かれていない
- [ ] 最新更新3件が控えめに表示される
- [ ] 共通背景が表示される
- [ ] 文字が読みにくくなっていない
- [ ] スマホ幅でロゴ、キービジュアル、ナビ、更新の順に縦積みされる
- [ ] broken image がない
- [ ] `undefined` / `null` / `[]` が画面に露出していない
- [ ] ブラウザコンソールに重大エラーがない

## ロゴ確認
- [ ] `assets/images/common/velgard-logo.png` が存在する
- [ ] トップページに正式ロゴ画像が表示される
- [ ] ロゴ画像の alt が `“灰壁と花霧の国”ヴェルガルド` である
- [ ] ロゴ画像読み込み失敗時に文字ロゴ fallback がある
- [ ] キービジュアル、ナビ、LATEST 表示が維持されている
- [ ] スマホ幅でロゴが大きく崩れない
- [ ] 共通ヘッダーはテキストブランド維持であることを確認する
- [ ] `data/site.json` に `logoImage` が設定されている

## トップ画像拡大モーダル確認
- [ ] ロゴ画像クリックで拡大モーダルが開く
- [ ] ロゴ拡大モーダルが Enter / Space で開く
- [ ] ロゴ拡大モーダルが閉じるボタン / 背景クリック / Esc で閉じる
- [ ] ロゴ拡大モーダルを閉じた後、フォーカスが戻る
- [ ] キービジュアルクリックで拡大モーダルが開く
- [ ] キービジュアル拡大モーダルが Enter / Space で開く
- [ ] キービジュアル拡大モーダルが閉じるボタン / 背景クリック / Esc で閉じる
- [ ] キービジュアル拡大モーダルを閉じた後、フォーカスが戻る
- [ ] ロゴ / キービジュアルの拡大モーダルが既存 gallery / spot / character / scenario モーダルと衝突していない

## トップページナビ確認
- [ ] WORLD へのリンクが動作する
- [ ] CHARACTERS へのリンクが動作する
- [ ] SPOTS へのリンクが動作する
- [ ] SCENARIOS へのリンクが動作する
- [ ] GALLERY へのリンクが動作する
- [ ] TERMS へのリンクが動作する
- [ ] UPDATES へのリンクが動作する
- [ ] REGULATION へのリンクが動作する
- [ ] CAMPAIGN へのリンクが動作する

## regulation確認
- [ ] regulation.html が準備中ではなく正式規約ページとして表示される
- [ ] トップページの REGULATION 表示が「準備中」ではなく「開催規約」系になっている
- [ ] トップページから regulation.html へ遷移できる
- [ ] regulation.html の目次がPC幅で右側に表示される
- [ ] 目次リンクから各章へ移動できる
- [ ] スクロール時に目次が本文確認を妨げない
- [ ] スマホ幅で目次が本文の邪魔にならず縦積みになる
- [ ] レベルキャップ表が横スクロールで確認できる
- [ ] data/regulation.json の schedule 15件、levelCaps 14件、adoptedRulebooks 27件が維持されている
- [ ] 共通ルール［その他］6項目が維持されている

## 表示まわり確認
- [ ] `characters.html` のキャラクターカード画像で顔が見える
- [ ] キャラクター画像が横長に不自然に切り取られていない
- [ ] 公式NPC画像20件が表示される
- [ ] `summary` / `quote` の表示が維持されている
- [ ] 地域フィルターが動作する
- [ ] broken image がない
- [ ] 共通背景画像 `background-mistwall.png` が表示される
- [ ] `index.html` で共通背景が見える
- [ ] `characters.html` で共通背景が見える
- [ ] `world.html` で共通背景が見える
- [ ] 背景のせいで文字が読みにくくなっていない
- [ ] `undefined` / `null` / `[]` が画面に露出していない
- [ ] ブラウザコンソールに重大エラーがない

## theme確認
- [ ] `site.json` の `theme.backgroundImage` が `assets/images/common/background-mistwall.png` を指している
- [ ] `main.js` で `theme.backgroundImage` が絶対URL化され、CSS変数に渡されている
- [ ] 背景の透明度、彩度、オーバーレイ、パネル濃度をtheme側で調整できる

## world本文確認
- [ ] `world.json` が8章のまま維持されている
- [ ] 第1章〜第8章すべてに詳細版本文が反映されている
- [ ] 各章の `title` が維持されている
- [ ] 既存の `id` / `number` / `lead` / `image` が維持されている
- [ ] subsection構成が維持されている
- [ ] 第4章・第6章・第7章・第8章が subsections-only 構造として破綻していない
- [ ] 空文字paragraphが存在しない
- [ ] `world.html` に8章表示される
- [ ] subsectionが21件表示される
- [ ] 目次リンクが29件表示される
- [ ] 目次リンクに破綻がない
- [ ] 右側目次リンクが表示される
- [ ] スクロールに合わせて目次active表示が切り替わる
- [ ] active項目に `aria-current="true"` が付与される
- [ ] 長い目次が内部スクロールできる
- [ ] active項目が目次内で追従する
- [ ] 目次リンククリックで該当章へ移動できる
- [ ] スマホ幅で目次が本文の邪魔にならない
- [ ] regulation.html の目次が壊れていない
- [ ] `undefined` / `null` / `[]` が画面に露出していない
- [ ] ブラウザコンソールに重大エラーがない

## world章別確認
- [ ] 第1章「舞台概要」に、ヴェルガルドの位置、灰壁、灰壁線、花霧谷、人蛮共存、未解決の火種が反映されている
- [ ] 第2章「冒険者ギルド『灰壁の灯火亭』」で、PCたちが「初期拠点」ではなく「所属」として扱われている
- [ ] 第3章「PCたちの立場」で、PCたちが独立した冒険者であり、公的権限を持たないことが明確化されている
- [ ] 第4章「歴史」で、灰壁・灰壁線・灰花盟約・現在の火種が詳細化されている
- [ ] 第5章「政治と法」で、灰花評議会・灰花盟約・壁内法・共存制度の現実が役割ごとに整理されている
- [ ] 第6章「土地・産業・交通」で、鉄道、薬草産業、鉱山、交易、関所物流が詳細化されている
- [ ] 第7章「人々の暮らしと文化」で、墓・死者名簿・灰壁に刻まれた名の役割差が明確化されている
- [ ] 第8章「防衛体制と怪異対策」で、灰壁・守備隊・鉄道公社・封印院・冒険者の役割が整理されている

## 公式NPC確認
- [ ] `characters.json` の公式NPC20名が維持されている
- [ ] 公式NPC20名すべてに `summary` が存在する
- [ ] 公式NPC20名すべてに `quote` が存在する
- [ ] 公式NPC20名すべてに `image` が存在する
- [ ] `summary` 内に本人名が含まれていない
- [ ] `characters.html` に公式NPC20名が表示される
- [ ] `characters.html` でNPC画像20件が表示される
- [ ] `quote` が引用風に表示される
- [ ] hidden / official:false のサンプルNPCが表示されていない
- [ ] 地域フィルターが動作する
- [ ] broken image がない
- [ ] `undefined` / `null` / `[]` が画面に露出していない

## 公式NPC年齢表示確認
- [ ] `characters.json` の公式NPC20名が維持されている
- [ ] 公式NPC20名すべてに `ageLabel` が存在する
- [ ] `characters.html` の公式NPCカードに年齢行が表示される
- [ ] 年齢行が20件表示される
- [ ] 年齢表示が `summary` / `quote` より上に表示される
- [ ] トーヴェ・リントが 年齢：7歳 と表示される
- [ ] トーヴェ・リントの古い `age`「未定。一桁年齢想定」が残っていない
- [ ] ブリギッテ・フェルゼンが ダークドワーフ と表示される
- [ ] ヤード・クロイツが ナイトメア（シャドウ生まれ） と表示される
- [ ] ヴォルフラム・シュタール、オイゲン・ホフマンの正名が維持されている
- [ ] `gald-valks` が正IDとして維持されている
- [ ] 公式NPC画像20件が表示される
- [ ] `summary` / `quote` の表示が維持されている
- [ ] 地域フィルターが動作する
- [ ] hidden / official:false のサンプルNPCが表示されていない
- [ ] broken image がない
- [ ] `undefined` / `null` / `[]` が画面に露出していない
- [ ] ブラウザコンソールに重大エラーがない

## キャラクター画像拡大モーダル確認
- [ ] `characters.html` の公式NPCカード画像をクリックするとモーダルが開く
- [ ] 大きめの立ち絵画像が表示される
- [ ] NPC名が表示される
- [ ] `role` または `title` が表示される
- [ ] 種族が表示される
- [ ] 年齢が表示される
- [ ] `summary` / `quote` はモーダルに表示されていない
- [ ] 閉じるボタンで閉じられる
- [ ] 背景クリックで閉じられる
- [ ] Escキーで閉じられる
- [ ] Enter / Space で開ける
- [ ] 閉じた後にフォーカスが元画像へ戻る
- [ ] PC幅で画像＋情報の2カラム表示になる
- [ ] スマホ幅で1カラム縦積みになる
- [ ] 画像が画面からはみ出しすぎない
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない

## characters.html 既存表示確認
- [ ] 公式NPC20名が表示される
- [ ] 公式NPC画像20件が表示される
- [ ] `ageLabel` 20件が維持されている
- [ ] ブリギッテ・フェルゼンがダークドワーフと表示される
- [ ] ヤード・クロイツがナイトメア（シャドウ生まれ）と表示される
- [ ] トーヴェ・リントが年齢：7歳と表示される
- [ ] `summary` / `quote` の表示が維持されている
- [ ] 地域フィルターが動作する
- [ ] hidden / official:false のサンプルNPCが表示されていない
- [ ] broken image がない
- [ ] ブラウザコンソールに重大エラーがない

## 既存モーダル維持確認
- [ ] `gallery.html` の既存モーダルが壊れていない
- [ ] `spot-detail.html` の画像拡大モーダルが壊れていない
- [ ] `character-image-modal` 系クラスが `gallery-modal` / `spot-image-modal` 系クラスと衝突していない
- [ ] `gallery-modal` 系クラスが `spot-image-modal` 系 / `character-image-modal` 系と衝突していない

## キャッシュ対策確認
- [ ] `characters.html` が `assets/js/main.js?v=20260526-character-modal` を読み込んでいる
- [ ] `main.js` が `./renderCharacters.js?v=20260526-character-modal` を読み込んでいる
- [ ] `characters.json` は `data/characters.json?v=20260526-age` を維持している
- [ ] `renderCharacters.js` が `data/characters.json?v=20260526-age` を fetch している
- [ ] `Ctrl + F5` 後に年齢表示が反映される
- [ ] `Ctrl + F5` 後にキャラクター画像モーダルが動作する
- [ ] Brave と Chrome のどちらでも年齢表示が確認できる
- [ ] `gallery.html` が `assets/js/main.js?v=20260526-gallery-label` を読み込んでいる
- [ ] `main.js` が `./renderGallery.js?v=20260526-gallery-label` を読み込んでいる
- [ ] `Ctrl + F5` 後にギャラリーモーダル移動導線が反映される

## 地域フィルター確認
- [ ] すべて: 20名
- [ ] ヴェルガルド中央駅都: 6名
- [ ] 灰壁線・防衛鉄道公社: 3名
- [ ] 花霧谷リュスベル・花霧薬師組合: 3名
- [ ] 裂原グラシュ峡・裂原封印院: 2名
- [ ] 双角市場オルム: 3名
- [ ] フェルゼ坑町: 1名
- [ ] 黒橋関所: 1名
- [ ] 灰名神殿会: 1名

## 主要スポット確認
- [ ] `spots.json` が8件のまま維持されている
- [ ] 全8件に `summary` が存在する
- [ ] 全8件に `image` が存在する
- [ ] `spots.html` に主要スポット8件が表示される
- [ ] `spots.html` で代表画像8件が表示される
- [ ] スポット説明文が簡潔版に更新されている
- [ ] カテゴリフィルターが動作する
- [ ] 関連NPCが実名表示される
- [ ] 関連NPCの生IDが露出していない
- [ ] broken image がない
- [ ] `undefined` / `null` / `[]` が画面に露出していない

## スポット詳細ページ確認
- [ ] `data/spotDetails.json` が存在する
- [ ] `spotDetails.json` が8件である
- [ ] `spotDetails.json` の各idが `spots.json` と一致する
- [ ] `spot-detail.html` が存在する
- [ ] `spot-detail.html?id=central-station-city` が表示される
- [ ] `spot-detail.html?id=ryusbel-flower-mist-valley` が表示される
- [ ] `spot-detail.html?id=orm-twinhorn-city` が表示される
- [ ] `spot-detail.html?id=grasch-rift` が表示される
- [ ] `spot-detail.html?id=defense-railway` が表示される
- [ ] `spot-detail.html?id=felsen-mining-town` が表示される
- [ ] `spot-detail.html?id=grayname-temple` が表示される
- [ ] `spot-detail.html?id=blackbridge-checkpoint` が表示される
- [ ] 各詳細ページにタイトル、definition、lead、sections本文が表示される
- [ ] 長文が読みやすい
- [ ] 共通背景と本文の可読性が維持されている
- [ ] `spots.html` の各カードに「詳細を見る」導線がある
- [ ] `spots.html` から各詳細ページへ遷移できる
- [ ] raw ID が画面に表示されていない
- [ ] `undefined` / `null` / `[]` が画面に露出していない

## スポット詳細 関連情報確認
- [ ] 地図画像が表示される
- [ ] 関連画像が表示される
- [ ] 関連施設画像が表示される
- [ ] 関連NPCが名前で表示される
- [ ] 関連シナリオが名称で表示される
- [ ] 関連用語が名称で表示される
- [ ] gallery / characters / hooks / terms の参照切れがない
- [ ] 詳細ページで使う画像参照に欠損がない
- [ ] broken image がない

## スポット詳細 画像拡大モーダル確認
- [ ] `spot-detail.html` 内の地図画像をクリックするとモーダルで拡大表示される
- [ ] 関連画像をクリックするとモーダルで拡大表示される
- [ ] 関連施設画像をクリックするとモーダルで拡大表示される
- [ ] モーダルに画像タイトルが表示される
- [ ] 説明文がある場合は説明文が表示される
- [ ] 閉じるボタンで閉じられる
- [ ] 背景クリックで閉じられる
- [ ] Escキーで閉じられる
- [ ] Enter / Space で拡大表示できる
- [ ] 画像が画面からはみ出しすぎない
- [ ] スマホ幅で大きく崩れない
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない
- [ ] `gallery.html` の既存モーダルが壊れていない

## スポット詳細 章別確認
- [ ] 中央駅都が「運用都市」として描かれている
- [ ] 花霧谷リュスベルが「秤の谷」として描かれている
- [ ] 双角市場オルムが「信用と面子を扱う市場」として描かれている
- [ ] 裂原グラシュ峡が「分からないものに境界線を引き続ける場所」として描かれている
- [ ] 灰壁線・防衛鉄道公社が「途切れやすい土地をつなぎ続ける鉄の縫い目」として描かれている
- [ ] フェルゼ坑町が「守るための硬さに代償があることを知っている町」として描かれている
- [ ] 灰名神殿会が「失われる名をこの国の記憶へ留める場所」として描かれている
- [ ] 黒橋関所が「通してよいものと止めるべきものを選り分ける篩の門」として描かれている

## scenarios正式化STEP2確認 / シナリオページ確認
- [ ] `data/scenarios.json` が存在する
- [ ] `scenarios.json` が7件である
- [ ] `data/hooks.json` が7件維持されている
- [ ] `scenarios.json` と `hooks.json` のIDが一致している
- [ ] `assets/js/renderScenarios.js` が存在する
- [ ] `scenarios.html` が存在する
- [ ] `scenarios.html` が HTTP 200 で開く
- [ ] `scenarios.html` が SCENARIOS / シナリオ一覧ページとして表示される
- [ ] `scenarios.html` にシナリオカード7件が表示される
- [ ] `scenarios.html` のカードが `scenario-detail.html?id=<id>` へ遷移する
- [ ] `scenarios.html` のシナリオ画像クリックで拡大モーダルが開く
- [ ] `hooks.html` が互換入口として HTTP 200 で開く
- [ ] `hooks.html` が SCENARIOS / シナリオ として表示される
- [ ] `hooks.html` でもシナリオカード7件が表示される
- [ ] 共通ナビが SCENARIOS 表記になっている
- [ ] 共通ナビの SCENARIOS が `scenarios.html` を指す
- [ ] トップページナビが SCENARIOS / シナリオ 表記になっている
- [ ] トップページナビの SCENARIOS / シナリオ が `scenarios.html` を指す
- [ ] `hooks.html` は `renderScenarios.js` 経由で描画される
- [ ] 各カードに画像が表示される
- [ ] 各カードにタイトルが表示される
- [ ] 各カードに `category` / `genre` が表示される
- [ ] 各カードに `summary` が表示される
- [ ] 各カードに準備中バッジが表示される
- [ ] 各カードから `scenario-detail.html?id=<id>` へ遷移できる
- [ ] `scenario-detail.html` 側で SCENARIOS ナビ active が維持される
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない
- [ ] 旧「フック」見出しやラベルが目立って残っていない
- [ ] broken image がない

## シナリオ候補カード7件確認
- [ ] 列車と鉄道の事件 が表示される
- [ ] 花霧谷の探索と薬草事件 が表示される
- [ ] 人蛮共存と交渉 が表示される
- [ ] 鉱山と産業事件 が表示される
- [ ] 裂原と怪異 が表示される
- [ ] 密輸と裏社会 が表示される
- [ ] 死者名簿と灰壁の記録 が表示される

## 個別シナリオ準備中ページ確認
- [ ] `scenario-detail.html` が存在する
- [ ] `assets/js/renderScenarioDetail.js` が存在する
- [ ] `scenario-detail.html` が `data/scenarios.json` を参照して表示される
- [ ] `scenario-detail.html?id=railway-incidents` が表示される
- [ ] `scenario-detail.html?id=flower-mist-valley-cases` が表示される
- [ ] `scenario-detail.html?id=coexistence-negotiation` が表示される
- [ ] `scenario-detail.html?id=mining-industrial-cases` が表示される
- [ ] `scenario-detail.html?id=rift-anomalies` が表示される
- [ ] `scenario-detail.html?id=smuggling-underworld` が表示される
- [ ] `scenario-detail.html?id=grayname-records` が表示される
- [ ] 各個別ページにタイトルが表示される
- [ ] 各個別ページに代表画像が表示される
- [ ] 各個別ページに `category` / `genre` が表示される
- [ ] 各個別ページに `summary` が表示される
- [ ] 各個別ページに配布シナリオ準備中案内が表示される
- [ ] 各個別ページに関連スポット / 関連NPCが名称で表示される
- [ ] シナリオ一覧へ戻る導線がある
- [ ] idなし / 不正id で「シナリオが見つかりません」表示になる
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない

## シナリオ画像拡大モーダル確認
- [ ] `scenarios.html` の配布予定シナリオカード画像をクリックするとモーダルが開く
- [ ] `hooks.html` の配布予定シナリオカード画像をクリックするとモーダルが開く
- [ ] 大きめの画像が表示される
- [ ] シナリオ候補タイトルが表示される
- [ ] `category` / `genre` が表示される
- [ ] 準備中バッジが表示される
- [ ] `summary` が控えめに表示される
- [ ] `description` / `examples` / シナリオ本文 / 秘匿情報は表示されていない
- [ ] 閉じるボタンで閉じられる
- [ ] 背景クリックで閉じられる
- [ ] Escキーで閉じられる
- [ ] Enter / Space で開ける
- [ ] 閉じた後にフォーカスが元画像へ戻る
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない
- [ ] スマホ幅で大きく崩れない

## 個別シナリオ準備中ページ画像確認
- [ ] `scenario-detail.html?id=railway-incidents` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=flower-mist-valley-cases` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=coexistence-negotiation` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=mining-industrial-cases` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=rift-anomalies` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=smuggling-underworld` の代表画像クリックでモーダルが開く
- [ ] `scenario-detail.html?id=grayname-records` の代表画像クリックでモーダルが開く
- [ ] 個別準備中ページの既存表示が壊れていない

## シナリオ画像 既存モーダル維持確認
- [ ] `gallery.html` のモーダルが壊れていない
- [ ] `spot-detail.html` の画像モーダルが壊れていない
- [ ] `characters.html` のキャラクター画像モーダルが壊れていない
- [ ] `scenario-image-*` 系クラスが既存モーダルクラスと衝突していない

## シナリオページ既存表示確認
- [ ] SCENARIOS / シナリオ表示が維持されている
- [ ] 配布予定シナリオカード7件が表示されている
- [ ] 各カードに画像が表示されている
- [ ] 各カードに準備中バッジが表示されている
- [ ] 各カードから `scenario-detail.html?id=<id>` へ遷移できる
- [ ] 個別シナリオ準備中ページが表示される
- [ ] 関連スポット / 関連NPC名表示が維持されている
- [ ] spot-detail の関連シナリオ導線が維持されている

## シナリオ画像 キャッシュ対策確認
- [ ] `scenarios.html` が `assets/js/main.js?v=20260527-scenarios-page` を読み込んでいる
- [ ] `hooks.html` が `assets/js/main.js?v=20260527-scenarios-page` を読み込んでいる
- [ ] `scenario-detail.html` が `assets/js/main.js?v=20260527-scenarios-page` を読み込んでいる
- [ ] `spot-detail.html` が `assets/js/main.js?v=20260528-spotdetail-scenarios-only` を読み込んでいる
- [ ] `main.js` が `renderScenarios.js?v=20260527-scenarios-page` を読み込んでいる
- [ ] `main.js` が `renderScenarioDetail.js?v=20260527-scenarios-page` を読み込んでいる
- [ ] `main.js` が `renderSpotDetail.js?v=20260528-spotdetail-scenarios-only` を読み込んでいる
- [ ] `Ctrl + F5` 後にシナリオ画像モーダルが動作する

## spot-detail 関連シナリオ確認
- [ ] spot-detail の関連表示が「関連シナリオ」になっている
- [ ] 「関連フック」表記が画面に出ていない
- [ ] 関連シナリオが `scenario-detail.html?id=<hook id>` へリンクしている
- [ ] spot-detail の関連シナリオが `relatedScenarioIds` を参照して表示される
- [ ] 関連シナリオ名称解決が `scenarios.json` を参照している
- [ ] 準備中注記が表示される
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない
- [ ] `spot-detail.html` の meta description / og:description 内も「関連シナリオ」表記になっている

## relatedScenarioIds整理確認
- [ ] `spotDetails.json` が8件である
- [ ] 8スポットすべてに `relatedScenarioIds` が存在する
- [ ] `spotDetails.json` 上に `relatedHookIds` が残っていない
- [ ] `relatedScenarioIds` の参照切れがない
- [ ] `relatedScenarioIds` に重複がない
- [ ] spot-detail.html の関連シナリオが表示される
- [ ] 関連シナリオリンクが `scenario-detail.html?id=<id>` を指す
- [ ] 中央駅都の関連シナリオ表示が壊れていない
- [ ] 灰壁線・防衛鉄道公社の関連シナリオ表示が壊れていない
- [ ] 灰名寺の関連シナリオ表示が壊れていない
- [ ] `renderSpotDetail.js` の `relatedHookIds` fallback は撤去済みである
- [ ] `data/characters.json` の `relatedHooks` は別スキーマとして維持されている
- [ ] raw ID / `undefined` / `null` / `[]` が露出していない

## spot-detail関連シナリオ正本化確認
- [ ] `renderSpotDetail.js` に `relatedHookIds` 参照が残っていない
- [ ] `renderSpotDetail.js` で `data/hooks.json` をfetchしていない
- [ ] `renderSpotDetail.js` に `hooks.json` fallback が残っていない
- [ ] spot-detail の関連シナリオ表示が `relatedScenarioIds` を参照している
- [ ] 関連シナリオ名称解決が `scenarios.json` を参照している
- [ ] 関連シナリオリンクが `scenario-detail.html?id=<id>` を指す
- [ ] 関連シナリオカードの `defaultHref` が `scenarios.html` である
- [ ] 中央駅都の関連シナリオ表示が壊れていない
- [ ] 灰壁線・防衛鉄道公社の関連シナリオ表示が壊れていない
- [ ] 灰名寺の関連シナリオ表示が壊れていない
- [ ] raw ID / `undefined` / `null` / `[]` が露出していない
- [ ] `hooks.html` / `data/hooks.json` は互換要素として維持され、`renderHooks.js` は削除済みである
- [ ] `data/characters.json` の `relatedHooks` は別スキーマとして維持されている

## renderHooks.js整理確認
- [ ] `assets/js/renderHooks.js` が存在しない
- [ ] `main.js` から `renderHooks.js` が参照されていない
- [ ] `hooks.html` が互換入口として HTTP 200 で開く
- [ ] `hooks.html` が `renderScenarios.js` 経由でシナリオ一覧を表示する
- [ ] `scenarios.html` が正式入口として HTTP 200 で開く
- [ ] `data/hooks.json` は7件維持されている
- [ ] `data/scenarios.json` は7件維持されている
- [ ] scenarios / hooks のIDが一致している
- [ ] `data/characters.json` の `relatedHooks` は別スキーマとして維持されている
- [ ] raw ID / `undefined` / `null` / `[]` が露出していない

## 既存データ維持確認
- [ ] `data/scenarios.json` は7件である
- [ ] `data/hooks.json` は7件維持
- [ ] `data/gallery.json` の `scenarios` カテゴリ7件、`hooks` カテゴリ0件が維持されている
- [ ] `data/spotDetails.json` は8件維持
- [ ] `relatedScenarioIds` が8スポット分維持されている
- [ ] `spotDetails.json` 上の `relatedHookIds` は0件である
- [ ] `renderSpotDetail.js` の `relatedHookIds` fallback / `hooks.json` fallback は撤去済みである
- [ ] `scenarios.html` は正式なシナリオ一覧入口として作成済み
- [ ] `data/hooks.json` は互換・比較用として維持されている
- [ ] `assets/js/renderHooks.js` は削除済みである
- [ ] gallery category: `hooks` から `scenarios` への移行は完了済み
- [ ] campaign / episode 系ページが壊れていない

## 用語集確認
- [ ] `terms.json` が35件のまま維持されている
- [ ] 全35件に `summary` が存在する
- [ ] `terms.html` に35件表示される
- [ ] 用語説明文が簡潔版に更新されている
- [ ] 検索が動作する
- [ ] カテゴリフィルターが動作する
- [ ] 関連スポット / 関連NPC表示が破綻していない
- [ ] `undefined` / `null` / `[]` が画面に露出していない

## terms.json 用語追加確認
- [ ] `terms.json` が35件になっている
- [ ] 花摘み村ミレア が存在する
- [ ] 防衛鉄道公社 が存在する
- [ ] 灰壁第一要塞駅 が存在する
- [ ] 死者名簿 が存在する
- [ ] 未帰還簿 が存在する
- [ ] 未詳者 が存在する
- [ ] 未詳失踪記録 が存在する
- [ ] 名待ち札 が存在する
- [ ] 奈落の魔域 が独立termとして追加されていない
- [ ] 賢神キルヒア が独立termとして追加されていない
- [ ] `relatedHooks` が `terms.json` に追加されていない
- [ ] 各追加項目に `id` / `term` / `category` / `summary` / `relatedSpots` / `relatedCharacters` / `status` がある

## spotDetails 関連用語ID確認
- [ ] `ryusbel-flower-mist-valley` に `mirea-flower-pickers-village` が関連用語として追加されている
- [ ] `defense-railway` に `defense-railway-corporation` が関連用語として追加されている
- [ ] `defense-railway` に `first-graywall-fortress-station` が関連用語として追加されている
- [ ] `grayname-temple` に `death-register` が関連用語として追加されている
- [ ] `grayname-temple` に `missing-returnees-register` が関連用語として追加されている
- [ ] `grayname-temple` に `unidentified-deceased` が関連用語として追加されている
- [ ] `grayname-temple` に `unidentified-disappearance-record` が関連用語として追加されている
- [ ] `grayname-temple` に `name-waiting-tag` が関連用語として追加されている
- [ ] `relatedTermIds` に重複がない
- [ ] `relatedTermIds` に参照切れがない
- [ ] 奈落の魔域 / 賢神キルヒア に相当する独自IDを `relatedTermIds` に追加していない

## 関連用語アンカーリンク確認
- [ ] spot-detail の関連用語リンクが `terms.html#term-<term id>` 形式になっている
- [ ] 新規追加用語だけでなく、既存用語も同じ形式になっている
- [ ] 全スポット・全関連用語が対象になっている
- [ ] 表示テキストは日本語term名になっている
- [ ] raw ID が画面に表示されない
- [ ] `undefined` / `null` / `[]` が画面に表示されない
- [ ] `central-station-city` の 灰壁の灯火亭 が該当用語カードへ直接移動する
- [ ] `central-station-city` の 灰花評議会 が該当用語カードへ直接移動する
- [ ] `central-station-city` の 壁内法 が該当用語カードへ直接移動する
- [ ] `ryusbel-flower-mist-valley` の 花摘み村ミレア が該当用語カードへ直接移動する
- [ ] `defense-railway` の 防衛鉄道公社 が該当用語カードへ直接移動する
- [ ] `defense-railway` の 灰壁第一要塞駅 が該当用語カードへ直接移動する
- [ ] `grayname-temple` の 死者名簿 が該当用語カードへ直接移動する
- [ ] `grayname-temple` の 未帰還簿 が該当用語カードへ直接移動する
- [ ] `grayname-temple` の 未詳者 が該当用語カードへ直接移動する
- [ ] `grayname-temple` の 未詳失踪記録 が該当用語カードへ直接移動する
- [ ] `grayname-temple` の 名待ち札 が該当用語カードへ直接移動する

## terms.html アンカー挙動確認
- [ ] `terms.json` 全35件の用語カードに `id="term-<id>"` が付いている
- [ ] `terms.html#term-death-register` で死者名簿カードへスクロールする
- [ ] `terms.html#term-mirea-flower-pickers-village` で花摘み村ミレアカードへスクロールする
- [ ] `terms.html#term-defense-railway-corporation` で防衛鉄道公社カードへスクロールする
- [ ] `terms.html#term-graywall-lantern-inn` で灰壁の灯火亭カードへスクロールする
- [ ] 対象カードが一時的にハイライトされる
- [ ] 対象カードへフォーカスされる
- [ ] `hashchange` に対応している
- [ ] hash遷移時に検索欄が空になりカテゴリが「すべて」に戻る
- [ ] フィルターで対象カードが非表示にならない
- [ ] カテゴリフィルターの通常動作が壊れていない

## 関連用語導線 既存機能維持確認
- [ ] terms の検索が動作する
- [ ] terms のカテゴリフィルターが動作する
- [ ] spot-detail の関連NPC表示が維持されている
- [ ] spot-detail の関連シナリオ表示が維持されている
- [ ] spot-detail の関連画像表示が維持されている
- [ ] spot-detail 画像モーダルが壊れていない
- [ ] spots.html から詳細ページへの導線が壊れていない
- [ ] broken image がない
- [ ] ブラウザコンソールに重大エラーがない

## 画像アセット確認
- [ ] common PNG 4件が存在する
- [ ] characters PNG 20件が存在する
- [ ] locations PNG 14件が存在する
- [ ] facilities PNG 9件が存在する
- [ ] hooks PNG 7件が存在する
- [ ] maps PNG 9件が存在する
- [ ] 既存SVGプレースホルダー類を削除していない
- [ ] 灰壁線路線図 `assets/images/maps/graywall-line-route-map.png` が存在する

## 画像表示確認
- [ ] characters.html に公式NPC20名が表示される
- [ ] characters.html でNPC画像20件が表示される
- [ ] spots.html に主要スポット8件が表示される
- [ ] spots.html で代表画像8件が表示される
- [ ] hooks.html に配布予定シナリオ準備中カード7件が表示される
- [ ] hooks.html でシナリオ候補画像7件が表示される
- [ ] broken image がない
- [ ] 画像未設定・読込失敗時にfallbackする

## gallery確認
- [ ] gallery.html が準備中ではなく画像ギャラリーとして表示される
- [ ] gallery.html がHTTP 200で表示される
- [ ] data/gallery.json が41件である
- [ ] key-visual 2件、locations 14件、facilities 9件、scenarios 7件、hooks 0件、maps 9件が維持されている
- [ ] キービジュアルカテゴリが2件
- [ ] 地点カテゴリが14件
- [ ] 施設カテゴリが9件
- [ ] scenariosカテゴリが画面表示上は「シナリオ」として表示される
- [ ] 「シナリオフック」が画面上に不要に残っていない
- [ ] 地図カテゴリが9件
- [ ] gallery.html の maps カテゴリに灰壁線路線図が表示される
- [ ] カテゴリフィルターが動作する
- [ ] 画像カードクリックでモーダル表示される
- [ ] モーダルに拡大画像、タイトル、説明が表示される
- [ ] 閉じるボタンでモーダルを閉じられる
- [ ] 背景クリックでモーダルを閉じられる
- [ ] Escキーでモーダルを閉じられる
- [ ] 前へ / 次へボタンが動作する
- [ ] ArrowLeft / ArrowRight で前後移動できる
- [ ] 現在位置表示が出る
- [ ] 地図画像がモーダルで確認できる
- [ ] 灰壁線路線図画像がクリックでモーダル表示される
- [ ] 灰壁線路線図画像の参照切れがない
- [ ] spot-detail.html?id=defense-railway に灰壁線路線図が関連地図として表示される
- [ ] README内の灰壁線路線図に関する現在状況が作成・反映済みとして整理されている
- [ ] fallback画像が機能する
- [ ] NPC画像がgalleryに混入していない
- [ ] gallery.html のmeta / OGP description に「準備中」「掲載予定」「NPC立ち絵」系の古い文言が残っていない

## ギャラリーモーダル移動導線確認
- [ ] gallery.html の画像クリックでモーダルが開く
- [ ] モーダルに前へボタンが表示される
- [ ] モーダルに次へボタンが表示される
- [ ] モーダルに現在位置表示が表示される
- [ ] 次へボタンで次の画像へ移動できる
- [ ] 前へボタンで前の画像へ移動できる
- [ ] 最後の画像で次へを押すと最初に戻る
- [ ] 最初の画像で前へを押すと最後に移動する
- [ ] ArrowRight で次の画像へ移動できる
- [ ] ArrowLeft で前の画像へ移動できる
- [ ] 左スワイプで次の画像へ移動できる
- [ ] 右スワイプで前の画像へ移動できる
- [ ] スワイプ移動が検索・カテゴリ絞り込み後の表示中リスト内で行われる
- [ ] 縦スワイプや短いタップ風操作で誤って前後移動しない
- [ ] 複数指タッチでスワイプ追跡がリセットされる
- [ ] Escキーで閉じられる
- [ ] 閉じるボタンで閉じられる
- [ ] 背景クリックで閉じられる
- [ ] 画像、タイトル、説明、カテゴリ、カウンターが切り替えに合わせて更新される
- [ ] raw ID が表示されない
- [ ] `undefined` / `null` / `[]` が表示されない
- [ ] broken image がない

## galleryカテゴリ正式化確認
- [ ] gallery.json が41件である
- [ ] gallery category: scenarios が7件である
- [ ] gallery category: hooks が0件である
- [ ] gallery-hook-* ID 7件は互換維持されている
- [ ] assets/images/hooks/ の7画像が存在する
- [ ] シナリオ系7件の画像参照欠損がない
- [ ] gallery.html のカテゴリフィルターに「シナリオ」が表示される
- [ ] gallery.html に不要な hooks 表示ボタンが出ない
- [ ] gallery.html の「すべて」で41件表示される
- [ ] gallery.html の「シナリオ」で7件表示される
- [ ] シナリオカテゴリ内でモーダル前後移動ができる
- [ ] galleryモーダルの左右キー、閉じるボタン、背景クリック、Esc が維持されている
- [ ] key-visual / locations / facilities / maps のカテゴリ表示が壊れていない
- [ ] raw ID / undefined / null / [] が露出していない

## ギャラリーフィルター中の移動確認
- [ ] すべて表示中は全画像内で前後移動する
- [ ] mapsカテゴリ表示中はmapsカテゴリ内だけで前後移動する
- [ ] facilitiesカテゴリ表示中はfacilitiesカテゴリ内だけで前後移動する
- [ ] フィルター外の画像へ勝手に移動しない
- [ ] カテゴリフィルター通常動作が壊れていない
- [ ] 検索中はカテゴリ条件と検索条件を満たす現在表示リスト内で前後移動する
- [ ] 検索中・カテゴリ絞り込み中のスワイプ移動も現在表示リスト内で動作する

## gallery検索機能確認
- [x] gallery.html に検索欄が表示される
- [x] 「すべて」で41件表示される
- [x] 「シナリオ」で7件表示される
- [x] 「地図」で9件表示される
- [x] title検索が効く
- [x] description検索が効く
- [x] カテゴリフィルターと検索を併用できる
- [x] 検索結果0件時にメッセージが表示される
- [x] 検索結果内でモーダル前後移動できる
- [x] 左右キー / Esc / 背景クリック / 閉じるボタンが維持されている
- [x] 390px幅で検索欄とカテゴリ欄の余白が不自然でない
- [x] raw ID / undefined / null / [] が露出していない
- 注記: gallery検索機能と検索UI余白調整は、ユーザーDevTools確認済み。

## TOOLS / ランダム表ツール確認
- [x] tools.html が表示される
- [x] ナビまたはトップ導線から tools.html に移動できる
- [x] TOP左側縦ナビに `TOOLS` が表示される
- [x] TOP左側縦ナビで `GALLERY → TOOLS → TERMS` の順に表示される
- [x] TOP左側縦ナビの `TOOLS` から `tools.html` に遷移できる
- [x] 表選択UIが表示される
- [x] 表選択肢が13件である
- [x] TDA1 / TDA2 が表選択UIに直接表示されない
- [x] TDA（自動分岐）で 1d2 → TDA1 / TDA2 → 1d36 の順に処理される
- [x] TDA1分岐・TDA2分岐の両方で実本文が表示される
- [x] TDB〜TDF が 1d36 で振れる
- [x] TDG〜TDL が 1d12 で振れる
- [x] アビス浸蝕表が 2D6 で振れる
- [x] アビス浸蝕表で合計値と内訳が表示される
- [x] 結果履歴が表示される
- [x] 結果表示に `結果をコピー` ボタンが表示される
- [x] 通常表の結果をコピーできる
- [x] TDA自動分岐の結果をコピーできる
- [x] アビス浸蝕表の結果をコピーできる
- [x] 直近履歴の各項目に `コピー` ボタンが表示される
- [x] 履歴ごとに個別コピーできる
- [x] コピー成功時または失敗時に分かる反応がある
- [x] 直近履歴に `履歴をまとめてコピー` ボタンが表示される
- [x] 履歴0件時のまとめコピー挙動が自然である
- [x] 10回以上振っても履歴が消えず全件表示される
- [x] 履歴まとめコピーが表示中の全履歴を対象にしている
- [x] `結果本文未設定` が表示されない
- [x] raw JSON / undefined / null / [] が露出していない
- [x] 390px幅で横スクロールや操作部品のはみ出しがない
- [x] 390px幅でコピー按钮や履歴コピー按钮がはみ出さない
- [x] U+FFFDや文字化けが出ていない
- 注記: ランダム表ツールは実本文データ反映後、ユーザー実ブラウザ確認済み。

## 公開前軽微UI改善確認
- [x] tools.html の表選択UI見切れが緩和されている
- [x] tools.html の個別履歴コピーが維持されている
- [x] tools.html に履歴まとめてコピーボタンが表示される
- [x] 履歴0件時のまとめコピー挙動が自然である
- [x] 履歴を複数件まとめてコピーできる
- [x] 10回以上振っても履歴が消えず全件表示される
- [x] 履歴まとめコピーが表示中の全履歴を対象にしている
- [x] regulation.html の右側目次枠が下に見切れない
- [x] regulation.html の目次が長い場合、枠内スクロールできる
- [x] spot-detail.html の関連キャラクターリンクから characters.html の該当キャラクター位置へ移動できる
- [x] 固定ヘッダーに該当カードが隠れない
- [x] 該当キャラクターカードが一時的に強調される
- [x] 390px幅で tools / regulation / spot-detail / characters に横スクロールが出ない
- [x] raw JSON / undefined / null / [] が露出していない
- 注記: 公開前軽微UI改善バッチはユーザー実ブラウザ確認済み。

## ページ上部へ戻るボタン確認
- [x] 全ページで「ページ上部へ戻る」ボタンが生成される
- [x] ページ上部付近ではボタンが非表示である
- [x] 300px超スクロール後に表示される
- [x] クリックすると現在ページの最上部へ戻る
- [x] TOPページへ遷移しない
- [x] `aria-label="ページ上部へ戻る"` が付与されている
- [x] `prefers-reduced-motion` に配慮されている
- [x] galleryモーダル表示中は邪魔にならない
- [x] 画像モーダルより前面に出ない
- [x] 390px幅で横スクロールやボタンのはみ出しがない
- [x] raw JSON / undefined / null / [] が露出していない
- 注記: 全ページ共通「ページ上部へ戻る」ボタンは、ユーザー実ブラウザ確認済み。

## シナリオ本文受け入れ基盤確認
- [ ] `scenarios.json` が7件である
- [ ] 既存7件すべて `status: public` を維持している
- [ ] 既存7件すべて `releaseStatus: preparing` である
- [ ] `textUrl` / `pdfUrl` が未設定の現状で、不要なリンクが出ない
- [ ] `scenarios.html` の一覧カードに「準備中」バッジが表示される
- [ ] `scenario-detail.html` の詳細ページに「配布情報」セクションが表示される
- [ ] `preparing` 状態では「準備中」表示になる
- [ ] TXT本文表示は `textContent` 前提である
- [ ] PDFリンクには `target="_blank"` と `rel="noopener"` が付く
- [ ] 390px幅で `scenarios.html` / `scenario-detail.html` に横スクロールが出ない
- [ ] raw JSON / undefined / null / [] が露出していない
- 注記: シナリオ本文・PDF受け入れ基盤は、ユーザー実ブラウザ確認済み。実本文 `.txt` / PDF配置は本文ファイル受領後に行う。

## ラクシア運用カレンダー確認
- [x] calendar.html が表示される
- [x] グローバルナビから calendar.html に移動できる
- [x] TOP左側縦ナビに CALENDAR が表示される
- [x] TOPメイン目次側に CALENDAR が表示される
- [x] 今日の換算カードが表示される
- [x] 任意日付入力が動作する
- [x] 確認ボタンが動作する
- [x] 今日に戻すボタンが動作する
- [x] 月表示カレンダーが表示される
- [x] 前月へ / 次月へ / 今日の月へ が動作する
- [x] 日付セルクリックで選択日が更新される
- [x] 選択日詳細カードが更新される
- [x] 今日セルが視覚的に分かる
- [x] 選択中セルが視覚的に分かる
- [x] 季節が視覚的に分かる
- [x] 新月期間 / 満月期間が視覚的に分かる
- [x] レベルキャップがセル内に表示される
- [x] レベルキャップ開始日に開始バッジが表示される
- [x] `2026-06-01` に `2Lv開始` が表示される
- [x] `2026-06-08` に `3Lv開始` が表示される
- [x] `2026-06-22` に `4Lv開始` が表示される
- [x] `2026-07-06` に `5Lv開始` が表示される
- [x] `2027-02-01` に `15Lv開始` が表示される
- [x] `2026-06-02` には開始日表示が出ない
- [x] `2026-06-21` には開始日表示が出ない
- [x] `2027-02-21` には開始日表示が出ない
- [x] 選択日詳細カードに開始日のみ節目表示が出る
- [x] 開催期間外には開始日バッジやLv情報が出ない
- [x] 390px幅で開始日バッジが読める
- [x] 開催期間外の日付ではラクシア日付・季節・月齢・Lv数値が表示されない
- [x] `2026-05-31` が `開催期間前` になり、ラクシア情報が表示されない
- [x] `2026-06-01` が `1年目3月1日(日)〜5日(木)` / `2Lv` になる
- [x] `2026-06-08` が `1年目4月6日(日)〜10日(木)` / `3Lv` になる
- [x] `2026-07-06` が `1年目8月26日(日)〜30日(木)` / `5Lv` になる
- [x] `2027-02-21` が `15Lv` 期間内になる
- [x] `2027-02-22` が `開催期間終了後` になり、ラクシア情報が表示されない
- [x] ラクシア年切り替わりが3月1日起点である
- [x] `data/sessions.json` が存在し、parseできる
- [x] `data/sessions.json` の仮データが7件である
- [x] `2026-06-08` に3件の同日複数予定がある
- [x] カレンダーセルに予定が `時刻 GM名 タイトル` で全件縦表示される
- [x] `closed` 予定が `〆 時刻 GM名 タイトル` 形式で表示される
- [x] `gmName` がセル内に表示され、JS側で `GM` 接頭辞を二重追加していない
- [x] カレンダーセルに `+n件` 圧縮表示が出ない
- [x] カレンダーセルに `募集中` / `満席` の強い状態バッジが出ない
- [x] `closed` 予定に `〆` が表示される
- [x] 選択日詳細エリアに「選択日のセッション予定」が表示される
- [x] 選択日予定カードにタイトル、開催時刻、GM名、レベル、募集人数、概要、タグが表示される
- [x] 選択日予定カードの「詳細を見る」からセッション詳細モーダルを開ける
- [x] カレンダーセル内予定行クリック / タップからセッション詳細モーダルを開ける
- [x] 予定行クリック時に日付選択とモーダル表示が二重に暴発しない
- [x] 詳細モーダルの表示順がPL向けに、基本情報、概要、詳細 / 参加条件、タグ、補足情報の順へ整理されている
- [x] 詳細モーダル上部に開催日、開催時刻、GM、レベル帯、募集人数がまとまって表示される
- [x] 詳細モーダル下部の補足情報に、状態、更新日、関連スポットID、シナリオID、公開範囲が控えめに表示される
- [x] 詳細モーダルの空項目が表示されない
- [x] 選択日予定カードと詳細モーダルにDiscordスレッドリンクやDiscord誘導ボタンが表示されない
- [x] `discordThreadUrl` は将来のbot/Webhook同期用データとして残し、PL向けUIには出していない
- [x] `assets/js/sessionDisplay.js` が存在し、セッション表示・詳細表示の整形ロジックが共通化されている
- [x] `renderSessionDetailContent(session, options)` 系の共通関数を将来の `session-detail.html?id=...` に流用できる前提で整理されている
- [x] 詳細モーダルがフッターや黒い領域に隠れない
- [x] 詳細モーダルは閉じるボタン、背景クリック、Escキーで閉じられる
- [x] 予定がない日の空表示が自然である
- [x] セッション予定表示追加後もラクシア日付、季節、月齢、レベルキャップ表示が維持されている
- [x] Phase 1-A / Phase 1-B / Phase 1-C / Phase 1-D は静的モックUIと表示整理であり、予定登録、編集、参加申請、認証、Discord連携、外部DB/APIを実装していない
- [x] `session-detail.html`、詳細ページ遷移、URLクエリでのモーダル自動表示は未実装である
- [x] 〆ボタン、参加申請停止処理、保存処理は未実装のままである
- [x] カレンダー関連キャッシュクエリが `v=20260529-calendar-session-detail-polish` である
- [x] galleryスワイプ用キャッシュクエリ `v=20260529-gallery-swipe` が維持されている
- [x] カレンダー予定表示は390px幅で横スクロールが出ない
- [x] 390px幅で横スクロールが出ない
- [x] raw JSON / undefined / null / [] が露出していない
- 注記: ラクシア運用カレンダー Phase 1、月表示カレンダー、期間外表示、ラクシア年切り替わり修正、レベルキャップ開始日可視化、Phase 1-A 静的セッション予定モックUI、Phase 1-B セッション詳細モーダル、Phase 1-C 表示ロジック共通化、Phase 1-D PL向け詳細表示整理はユーザー実ブラウザ確認済み。

## 公開後軽微UI改善バッチ2確認
- [x] WORLD本文小見出しの上余白が自然になっている
- [x] WORLD本文小見出し直下の本文との距離が自然になっている
- [x] WORLD本文全体の `line-height` を変更していない
- [x] TOPキービジュアルがPC幅・大画面幅で大きめに表示される
- [x] TOP左側ナビと右側キービジュアルの高さバランスが改善されている
- [x] 共通最大幅 `--max: 1360px` が反映されている
- [x] TOP専用幅 `--home-max: 1600px` が反映されている
- [x] 記事系保護幅 `--article-max: 1240px` が反映されている
- [x] `world.html` / `regulation.html` など長文記事系の可読幅が保護されている
- [x] `gallery.html` / `calendar.html` / `tools.html` などが大画面で少し広く使える
- [x] 全HTMLのCSSキャッシュクエリが `v=20260529-home-wide-layout` で統一されている
- [x] 390px幅で横スクロールが出ない
- 注記: WORLD余白調整、TOPキービジュアル拡大、大画面幅調整はユーザー実ブラウザ確認済み。GitHub Pages公開反映は次の commit / push 工程で行う。

## ギャラリー既存表示確認
- [ ] `gallery.json` が41件である
- [ ] `key-visual` が2件である
- [ ] `locations` が14件である
- [ ] `facilities` が9件である
- [ ] `scenarios` が7件である
- [ ] `hooks` が0件である
- [ ] `maps` が9件である
- [ ] gallery画像参照に欠損がない
- [ ] 画像一覧表示が維持されている
- [ ] 画像タイトル表示が維持されている
- [ ] 画像説明文表示が維持されている

## 更新履歴確認
- [ ] updates.html に「カレンダー予定の詳細表示を追加」が表示される
- [ ] index.html の最新更新欄に「カレンダー予定の詳細表示を追加」が反映される
- [ ] updates.json に「カレンダー予定の詳細表示を追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「カレンダーにセッション予定表示を追加」が表示される
- [ ] index.html の最新更新欄に「カレンダーにセッション予定表示を追加」が反映される
- [ ] updates.json に「カレンダーにセッション予定表示を追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「ギャラリーのスワイプ操作を追加」が表示される
- [ ] index.html の最新更新欄に「ギャラリーのスワイプ操作を追加」が反映される
- [ ] updates.json に「ギャラリーのスワイプ操作を追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「表示余白とトップ表示を調整」が表示される
- [ ] index.html の最新更新欄に「表示余白とトップ表示を調整」が反映される
- [ ] updates.json に「表示余白とトップ表示を調整」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「カレンダー表示を調整」が表示される
- [ ] index.html の最新更新欄に「カレンダー表示を調整」が反映される
- [ ] updates.json に「カレンダー表示を調整」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「細部UIを調整」が表示される
- [ ] index.html の最新更新欄に「細部UIを調整」が反映される
- [ ] updates.json に「細部UIを調整」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「ラクシア運用カレンダーを追加」が表示される
- [ ] index.html の最新更新欄に「ラクシア運用カレンダーを追加」が反映される
- [ ] updates.json に「ラクシア運用カレンダーを追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「シナリオ本文の受け入れ基盤を追加」が表示される
- [ ] index.html の最新更新欄に「シナリオ本文の受け入れ基盤を追加」が反映される
- [ ] updates.json に「シナリオ本文の受け入れ基盤を追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「ページ上部へ戻るボタンを追加」が表示される
- [ ] index.html の最新更新欄に「ページ上部へ戻るボタンを追加」が反映される
- [ ] updates.json に「ページ上部へ戻るボタンを追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「ランダム表ツールを追加」が表示される
- [ ] index.html の最新更新欄に「ランダム表ツールを追加」が反映される
- [ ] updates.json に「ランダム表ツールを追加」が追加されている
- [ ] updates.json が40件である
- [ ] updates.html に「ギャラリー検索機能を追加」が表示される
- [ ] index.html の最新更新欄に「ギャラリー検索機能を追加」が反映される
- [ ] updates.json に「ギャラリー検索機能を追加」が追加されている
- [ ] updates.json が40件である
- [ ] 「ギャラリー検索機能を追加」の更新日が2026-05-28である
- [ ] updates.html に「旧フック描画JSを整理」が表示される
- [ ] index.html の最新更新欄に「旧フック描画JSを整理」が反映される
- [ ] updates.json に「旧フック描画JSを整理」が追加されている
- [ ] updates.json が40件である
- [ ] 「旧フック描画JSを整理」の更新日が2026-05-28である
- [ ] updates.html に「スポット詳細の関連シナリオ参照を正本化」が表示される
- [ ] index.html の最新更新欄に「スポット詳細の関連シナリオ参照を正本化」が反映される
- [ ] updates.json に「スポット詳細の関連シナリオ参照を正本化」が既存履歴として残っている
- [ ] 「スポット詳細の関連シナリオ参照を正本化」の更新日が2026-05-28である
- [ ] updates.html に「関連シナリオIDを整理」が表示される
- [ ] index.html の最新更新欄に「関連シナリオIDを整理」が反映される
- [ ] updates.json に「関連シナリオIDを整理」が既存履歴として残っている
- [ ] 「関連シナリオIDを整理」の更新日が2026-05-28である
- [ ] updates.html に「ギャラリーのシナリオ分類を正式化」が表示される
- [ ] index.html の最新更新欄に「ギャラリーのシナリオ分類を正式化」が反映される
- [ ] updates.json に「ギャラリーのシナリオ分類を正式化」が追加されている
- [ ] updates.html に「シナリオ正式入口を追加」が表示される
- [ ] index.html の最新更新欄に「シナリオ正式入口を追加」が反映される
- [ ] updates.json に「シナリオ正式入口を追加」が追加されている
- [ ] updates.html に「シナリオ正式化の土台を追加」が表示される
- [ ] index.html の最新更新欄に「シナリオ正式化の土台を追加」が反映される
- [ ] updates.json に「シナリオ正式化の土台を追加」が追加されている
- [ ] updates.html に「トップページと目次表示を調整」が表示される
- [ ] index.html の最新更新欄に「トップページと目次表示を調整」が反映される
- [ ] updates.json に「トップページと目次表示を調整」が追加されている
- [ ] updates.html に「正式ロゴを反映」が表示される
- [ ] index.html の最新更新欄に「正式ロゴを反映」が反映される
- [ ] updates.json に「正式ロゴを反映」が追加されている
- [ ] updates.html に「灰壁線路線図を追加」が表示される
- [ ] index.html の最新更新欄に「灰壁線路線図を追加」が反映される
- [ ] updates.html に「ギャラリー表示を調整」が表示される
- [ ] index.html の最新更新欄に「ギャラリー表示を調整」が反映される
- [ ] updates.json に「ギャラリー表示を調整」が追加されている
- [ ] updates.json の件数が意図通り増えている
- [ ] updates.html に「レギュレーション表示導線を調整」が表示される
- [ ] index.html の最新更新欄に「レギュレーション表示導線を調整」が反映される
- [ ] updates.html に「シナリオ画像の拡大表示を追加」が表示される
- [ ] index.html の最新更新欄に「シナリオ画像の拡大表示を追加」が反映される
- [ ] updates.html に「シナリオページを準備中化」が表示される
- [ ] index.html の最新更新欄に「シナリオページを準備中化」が反映される
- [ ] updates.html に「ギャラリーモーダルの移動導線を追加」が表示される
- [ ] index.html の最新更新欄に「ギャラリーモーダルの移動導線を追加」が反映される
- [ ] updates.html に「関連用語の導線を改善」が表示される
- [ ] index.html の最新更新欄に「関連用語の導線を改善」が反映される
- [ ] updates.html に「キャラクター画像の拡大表示を追加」が表示される
- [ ] index.html の最新更新欄に「キャラクター画像の拡大表示を追加」が反映される
- [ ] updates.html に「スポット詳細ページを追加」が表示される
- [ ] index.html の最新更新欄に「スポット詳細ページを追加」が反映される
- [ ] updates.html に「公式NPCの年齢表示を追加」が表示される
- [ ] updates.html に「トップページを改修」が表示される
- [ ] updates.html に「表示まわりを調整」が表示される
- [ ] updates.html に「世界観本文を詳細版へ更新」が表示される
- [ ] updates.html に「画像ギャラリーを本格整備」が表示される
- [ ] updates.html に「用語集の説明文を整備」が表示される
- [ ] updates.html に「主要スポットの説明文を整備」が表示される
- [ ] updates.html に「公式NPCの紹介文を整備」が表示される
- [ ] updates.html に「シナリオフックの説明文を整備」が表示される
- [ ] index.html の最新更新欄に反映される
- [ ] index.html の最新更新欄に「公式NPCの年齢表示を追加」が反映される
- [ ] index.html の最新更新欄に「トップページを改修」が反映される
- [ ] index.html の最新更新欄に「表示まわりを調整」が反映される
- [ ] index.html の最新更新欄に「世界観本文を詳細版へ更新」が反映される
- [ ] 更新履歴の件数が想定通り表示される
- [ ] `updates.json` が40件になっている
- [ ] index.html の最新3件が以下の順になっている
  - カレンダー予定の詳細表示を追加
  - カレンダーにセッション予定表示を追加
  - ギャラリーのスワイプ操作を追加

## meta / OGP確認
- [ ] 全HTMLにtitleが設定されている
- [ ] 全HTMLにdescriptionが設定されている
- [ ] 全HTMLにDiscord共有向けOGPタグが設定されている
- [ ] X / Twitterカード互換metaを追加していない
- [ ] `data/site.json` の `publicUrl` が `https://suisui334.github.io/velgard-site/` になっている
- [ ] 全HTMLの `og:url` が `https://example.com/...` ではない
- [ ] 全HTMLの `og:url` が `https://suisui334.github.io/velgard-site/...` になっている
- [ ] 全HTMLの `og:image` が相対パスではなく絶対URLになっている
- [ ] 全HTMLの `og:image` が `https://suisui334.github.io/velgard-site/assets/images/common/ogp-main-1200x630.png` を参照している
- [ ] 全HTMLの favicon が `assets/images/common/favicon-32.png` / `assets/images/common/favicon-192.png` を参照している
- [ ] 全HTMLに `apple-touch-icon` が設定されている
- [ ] `data/site.json` の `meta.ogImage` が `assets/images/common/ogp-main-1200x630.png` を指している
- [ ] `data/site.json` の `meta.favicon` が `assets/images/common/favicon-32.png` を指している
- [ ] `data/site.json` の `meta.faviconLarge` が `assets/images/common/favicon-192.png` を指している
- [ ] `data/site.json` の `meta.appleTouchIcon` が `assets/images/common/apple-touch-icon.png` を指している
- [ ] 元画像 `assets/images/common/ogp-main.png` / `assets/images/common/favicon.png` が原本として残っている
- [ ] `assets/images/common/ogp-main-1200x630.png` が存在する
- [ ] `assets/images/common/favicon-32.png` が存在する
- [ ] `assets/images/common/favicon-192.png` が存在する
- [ ] `assets/images/common/apple-touch-icon.png` が存在する
- [ ] Discordで共有した際にOGP画像が表示されるか確認する
- [ ] 正式公開URLとOGP絶対URL化がREADMEに記載されている

## release-runbook確認
- [ ] `docs/release-runbook.md` が存在する
- [ ] 正式公開URL `https://suisui334.github.io/velgard-site/` が記載されている
- [ ] `publicUrl` / `og:url` / `og:image` が反映済みとして整理されている
- [ ] 現在HTML参照用のOGP画像 `assets/images/common/ogp-main-1200x630.png` が記載されている
- [ ] 公開前最終チェック項目が整理されている
- [ ] 公開後スマホ実機確認が残タスクとして整理されている
- [ ] Twitter / Xカード系metaは不要方針として整理されている

## 禁止表記チェック
- [ ] 灰壁の灯亭 が表示用本文・HTML・JS・JSONに残っていない
- [ ] 双角市オルム が表示用本文・HTML・JS・JSONに残っていない
- [ ] ヴォルフラム・グラシュ が表示用本文・HTML・JS・JSONに残っていない
- [ ] オイゲン・ノルデン が表示用本文・HTML・JS・JSONに残っていない
- [ ] グラシュ吊橋砦市 がREADME/docs以外に残っていない
- [ ] gald-valx が表示用本文・HTML・JS・JSONに残っていない
- [ ] gald-valk が表示用本文・HTML・JS・JSONに残っていない
- [ ] gald-valkus が表示用本文・HTML・JS・JSONに残っていない
- [ ] wolfram-grasch が表示用本文・HTML・JS・JSONに残っていない
- [ ] eugen-norden が表示用本文・HTML・JS・JSONに残っていない
- [ ] grasch-suspension-bridge-fort-city がREADME/docs以外に残っていない

## 不正表示チェック
- [ ] undefined が画面に露出していない
- [ ] null が画面に露出していない
- [ ] [] が不自然に画面に露出していない
- [ ] 空の関連項目が不自然に表示されていない
- [ ] ブラウザコンソールに重大エラーがない

## 公開前UI実ブラウザ確認 v1
- [x] PC実ブラウザで主要ページを確認し、大きな表示崩れがない
- [x] トップ正式ロゴ画像モーダルがPC環境で動作する
- [x] トップキービジュアル画像モーダルがPC環境で動作する
- [x] gallery画像モーダルがPC環境で動作する
- [x] spot-detail画像モーダルがPC環境で動作する
- [x] character画像モーダルがPC環境で動作する
- [x] scenario画像モーダルがPC環境で動作する
- [x] 主要ナビ導線がPC環境で問題なく動作する
- [x] SCENARIOS が `scenarios.html` を指す
- [x] galleryカテゴリ「シナリオ」で7件表示される
- [x] galleryカテゴリ「地図」で9件表示される
- [x] spot-detail から `scenario-detail.html?id=<id>` へ移動できる
- [x] spot-detail から `terms.html#term-<id>` へ移動できる
- [x] raw ID / undefined / null / [] の目立つ露出なし
- [ ] スマホ実機で横スクロールが不自然に出ない
- [ ] スマホ実機でナビが破綻しない
- [ ] スマホ実機で各モーダルが画面内に収まる
- [ ] スマホ実機で閉じる操作が問題なく行える
- [ ] スマホ実機で横スクロール・カード密度・ナビ崩れを確認する
- [ ] 必要に応じてDevToolsレスポンシブ表示で暫定確認する
- 注記: 未公開ローカル環境ではスマホ実機確認が困難なため、正式公開後または外部確認可能URL発行後に実施する。

## responsive UI修正確認
- [x] galleryモーダルで横長画像が上寄りにならない
- [x] galleryモーダルで下側に大きな黒余白が出ない
- [x] galleryモーダル画像がスマホ幅相当でも画面内に収まる
- [x] galleryモーダルの前へ / 次へ / カウンターが維持されている
- [x] galleryモーダルの Esc / 閉じるボタン / 背景クリックが維持されている
- [x] world目次リンククリックで該当章へ移動できる
- [x] world目次クリック後、目次側へ強制的に戻されない
- [x] world目次の active 表示が維持される
- [x] regulation.html の目次に悪影響がない
- [x] `v=20260528-responsive-ui-fix` が反映されている
- 注記: galleryモーダル画像上寄り・黒余白問題と world目次スクロール戻り問題は、DevTools 390px幅でユーザー確認済み。スマホ実機確認は正式公開後または外部確認可能URL発行後に実施する。

## トップキービジュアル表示調整確認
- [x] 390px幅でトップキービジュアルが右へ見切れない
- [x] ページ全体に不自然な横スクロールが出ない
- [x] PC幅でキービジュアル上下に不自然な余白が出ない
- [x] スマホ幅でキービジュアル上下に不自然な余白が出ない
- [x] キービジュアル画像の縦横比が崩れていない
- [x] キービジュアルクリック拡大モーダルが維持されている
- [x] トップ正式ロゴ拡大モーダルが維持されている
- 注記: トップキービジュアル横はみ出し修正と上下余白修正は、ユーザー確認済み。キャッシュ対策は `v=20260528-home-keyvisual-overflow-fix` / `v=20260528-home-keyvisual-fit-fix`。

## レスポンシブ確認
- [ ] スマホ実機で主要ページを確認する
- [ ] スマホ実機で横スクロールが不自然に出ない
- [ ] スマホ実機でナビが破綻しない
- [ ] スマホ実機でカード表示が大きく崩れていない
- [ ] スマホ実機で各モーダルが画面内に収まる
- [ ] スマホ実機で閉じる操作が問題なく行える
- [ ] 必要に応じてDevToolsレスポンシブ表示で暫定確認する
- 注記: 未公開ローカル環境ではスマホ実機確認が困難なため、正式公開後または外部確認可能URL発行後に実施する。

## 注意事項
- HOOKS / フックは今後 SCENARIOS / シナリオとして扱う
- 正式なシナリオ一覧入口は `scenarios.html`
- `hooks.html` のURLは互換入口として当面維持
- 現時点では配布シナリオ本文は未公開・準備中
- `data/scenarios.json` は旧 `hooks.json` 由来の7件を同IDで保持する正式化STEP1の参照元
- `data/hooks.json` は互換・比較用として保持
- `assets/js/renderHooks.js` は削除済み
- `spotDetails.json` は `relatedScenarioIds` を正本として使用する
- `spotDetails.json` 上の `relatedHookIds` は削除済み
- `renderSpotDetail.js` の `relatedHookIds` fallback / `hooks.json` fallback は撤去済み
- `data/characters.json` の `relatedHooks` は別スキーマとして維持する
- `scenario-detail.html` は個別準備中ページとして使う
- シナリオ画像拡大モーダルは画像閲覧用の軽量モーダルであり、配布シナリオ本文表示ではない
- `description` / `examples` / シナリオ本文 / 秘匿情報はモーダルに表示しない
- シナリオ画像クリック拡大対応は完了済み
- 配布シナリオ本文は未作成
- `scenarios.html` 新設は完了済み
- `data/hooks.json` の完全廃止は未実施
- gallery `hooks` カテゴリ移行は完了済み
- 表示が古い場合は `Ctrl + F5` を行う
- gallery説明文推敲は現時点では必須対応しない方針
- スワイプ操作は実装済み。gallery画像モーダル表示中のみ、左スワイプで次へ、右スワイプで前へ移動する
- galleryモーダル前後移動は、モーダルを開いた時点の表示中リストを基準にする
- カテゴリフィルター中はカテゴリ内で前後移動する
- 検索・カテゴリ絞り込み後の表示リスト内でスワイプ移動する
- Braveなど一部ブラウザでは古いJSモジュールやJSONキャッシュを掴むことがあるため、表示が古い場合は `Ctrl + F5` を行う
- NPC詳細ページはいったん作成しない方針
- キャラクター画像拡大モーダルは `characters.html` 専用の軽量モーダル
- `summary` / `quote` はモーダルには表示しない
- キャラクター画像表示が反映されない場合は `Ctrl + F5` で強制更新する
- Braveなど一部ブラウザでは古いJSモジュールやJSONキャッシュを掴むことがある
- `character-image-modal` 系CSSと既存gallery / spot-detailモーダルCSSの衝突に注意する
- スポット詳細ページは `spot-detail.html?id=<spot id>` 形式
- `spots.json` は一覧カード用、`spotDetails.json` は詳細ページ用として分離している
- 詳細ページ本文は「PCや依頼との関わり」ではなく「そこがどのような場所か」を主軸にする
- raw ID が画面に出ていないか必ず確認する
- 画像クリック拡大モーダルは spot-detail 専用であり、`gallery.html` の既存モーダルとは分離している
- 灰壁線路線図は作成・反映済みであり、gallery mapsカテゴリと `defense-railway` のスポット詳細から確認する
- 奈落の魔域 / 賢神キルヒア はSW2.5公式用語のため、ヴェルガルド独自termとして追加しない方針
- spot-detail の関連用語リンクは、新規追加用語だけでなく全スポット・全関連用語を対象にする
- 関連用語リンクは用語集トップではなく、`terms.html#term-<term id>` へ飛ばす
- hash遷移時はカテゴリフィルターで対象カードが非表示にならないよう確認する
- raw ID が画面に出ていないか必ず確認する
- 表示が古い場合は `Ctrl + F5` で強制更新する
- トップ左側のロゴは正式ロゴ画像を使用し、読み込み失敗時のみ文字ロゴfallbackを表示する
- トップページの不要キャッチ文「灰壁の向こうに、花霧はまだ揺れている。」は削除済み
- トップページのロゴ / キービジュアル拡大モーダルはトップページ専用の軽量モーダルとして扱う
- world目次は現在位置に合わせてactive同期し、長い場合は目次内スクロールで確認する
- トップページは世界観説明を詰め込む場所ではなく、作品公式サイト風の入口ページとして扱う
- トップページの詳細情報削除後も、world / characters / spots / SCENARIOS / gallery / terms への導線が確保されていることを確認する
- トップページの表示崩れ確認時は、`Ctrl + F5` でキャッシュを更新してから確認する
- 共通背景が見えない場合、ブラウザキャッシュの可能性があるため `Ctrl + F5` で強制更新する
- 背景が薄い／濃い場合は、まず `site.json` の `backgroundOpacity` / `overlayColor` / `panelOpacity` などを調整する
- キャラクター画像表示が崩れた場合は、`character-card` / `character-visual` / `object-fit` / `object-position` を確認する
- world本文は詳細版として整備済み
- 今後world本文を編集する場合は、章数・subsection構成を不用意に変更しない
- 灰壁に名を刻む文化は墓の代替ではなく、公共的な記憶・追悼・防衛の記録として扱う
- 現行 `terms.json` は `description` ではなく `summary` を使用している
- 将来 `description` フィールドへ移行する場合は、`renderTerms.js` 側も変更が必要
- 現行 `spots.json` は、カード表示用説明文として `summary` を使用している
- スポット詳細ページは実装済み。将来さらに本文を拡張する場合は、`spotDetails.json` 側の詳細本文構造を維持して検討する
- 現行 `characters.json` は、カード表示用紹介文として `summary` を使用している
- 公式NPC20名には `quote` が追加され、characters.html で引用風に表示される
- 将来NPC詳細ページを作る場合、`summary` とは別に詳細本文用フィールドを検討する
- 年齢表示が出ない場合は、まず `Ctrl + F5` で強制更新する
- Braveなど一部ブラウザでは古いJSモジュールやJSONキャッシュを掴むことがある
- `characters.html` / `main.js` / `renderCharacters.js` / `characters.json` のキャッシュ回避クエリを確認する
- ブリギッテ・フェルゼンはダークドワーフを正表記とする
- ヤード・クロイツはナイトメア（シャドウ生まれ）を正表記とする
- 年齢は公式NPCマスターデータ由来であり、推測作成ではない
- 現行 `hooks.json` は、旧フックデータ兼シナリオ候補カード表示元として保持している
- `summary` はシナリオ準備中カード / 個別準備中ページで使用している
- `description` / `examples` は現時点のSCENARIOS画面では大きく展開しない
- README / docs 内の禁止旧表記は、チェック項目としての記載のみ例外扱い

## シナリオファイル受け入れ確認
- [ ] `docs/scenario-file-policy.md` が存在する
- [ ] ユーザー提供の `.txt` ファイルを正本として配置している
- [ ] `.txt` ファイル名が `scenario-id` ベースである
- [ ] 配置先が `assets/scenarios/<scenario-id>/` である
- [ ] PDFがある場合、PDFリンクが存在する
- [ ] `scenarios.json` の `textUrl` / `pdfUrl` が正しい
- [ ] `releaseStatus` が `released` になっている
- [ ] `scenario-detail.html` にTXT/PDFダウンロード導線が表示される
- [ ] `scenario-detail.html` に秘匿情報を不用意に露出していない
- [ ] TXT / PDF ダウンロードがHTTP 200である
- [ ] PDF化した場合、元TXTと内容差分がない
- [ ] README / task-backlog / updates が更新されている
- [ ] Codex / ChatGPT がユーザー提供前にシナリオ本文を自動作成していない

## task-backlog確認
- [ ] `docs/task-backlog.md` が存在する
- [ ] README.md から詳細残タスクが `docs/task-backlog.md` へ分離されている
- [ ] `docs/task-backlog.md` に「すぐやる候補」「シナリオファイル受け入れ後」「後回し」「触らない方がよいもの」が整理されている
- [ ] シナリオ本文作成はユーザー提供ファイル待ちであることが明記されている
- [ ] シナリオファイル受け入れ方針が `docs/scenario-file-policy.md` に分離されている
- [ ] `hooks.html` / `data/hooks.json` / `gallery-hook-*` / `assets/images/hooks/` / `characters.json` の `relatedHooks` が互換維持として整理されている
- [ ] 公開前総点検 v2 の候補が整理されている
- [ ] 正式公開URL反映後の公開確認手順が `docs/release-runbook.md` に分離されている
- [ ] 日付整理方針が今後の確認項目として残っている
- [ ] `docs/task-backlog.md` で、シナリオ本文を自動作成する前提になっていない
- [ ] `docs/task-backlog.md` で、互換維持中の hooks 系要素が誤って削除済み扱いになっていない

## 作業後報告
- [ ] 修正ファイル一覧を報告
- [ ] 追加ファイル一覧を報告
- [ ] 実施した確認内容を報告
- [ ] 未実施または注意点を報告

注意: README.md の「禁止旧表記」欄と docs/qa-checklist.md のチェック項目として記載される分は例外です。

