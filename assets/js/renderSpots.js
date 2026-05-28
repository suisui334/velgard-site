import { byId, imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

export async function renderSpots(root, site) {
  const [spots, characters] = await Promise.all([loadJson("data/spots.json"), loadJson("data/characters.json")]);
  const visible = spots.filter((item) => isVisible(item));
  const charMap = byId(characters.filter((item) => isVisible(item) && item.official === true));
  const categories = ["すべて", ...new Set(visible.map((item) => item.category))];
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Spot</div>
      <h1>SPOT</h1>
      <p class="lead">ヴェルガルド各地の主要スポットです。カテゴリで絞り込めます。</p>
    </header>
    <section class="section">
      <div class="filter-bar">
        <label>カテゴリ <select id="spot-filter">${categories.map((cat) => `<option value="${cat}">${cat}</option>`).join("")}</select></label>
      </div>
      <div id="spot-grid" class="grid"></div>
    </section>
  `;
  const grid = root.querySelector("#spot-grid");
  const select = root.querySelector("#spot-filter");
  const draw = () => {
    const selected = select.value;
    const items = visible.filter((item) => selected === "すべて" || item.category === selected);
    grid.innerHTML = items.map((item) => `
      <article class="card">
        <div class="card-visual"><img src="${imageOrPlaceholder(item.image, site, "spot")}" alt="${item.name}" ${imageFallbackAttr(site, "spot")}></div>
        <div class="card-meta"><span class="tag">${item.category}</span></div>
        <h2>${item.name}</h2>
        <p><strong>役割:</strong> ${item.role || "未設定"}</p>
        <p>${item.summary}</p>
        <p><strong>主な導入:</strong> ${textList(item.hooks || item.introductions)}</p>
        <p><strong>関連組織:</strong> ${textList(item.organizations)}</p>
        <p><strong>関連NPC:</strong> ${textList((item.relatedCharacters || item.relatedNpcIds || []).map((id) => charMap.get(id)?.name).filter(Boolean))}</p>
        <div><a class="button" href="spot-detail.html?id=${item.id}">詳細を見る</a></div>
      </article>
    `).join("");
  };
  select.addEventListener("change", draw);
  draw();
}
