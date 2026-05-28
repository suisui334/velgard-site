import { byId, isVisible, loadJson, textList } from "./dataLoader.js";

const termAnchorPrefix = "term-";

function termAnchorId(item) {
  return `${termAnchorPrefix}${item.id}`;
}

function currentTermAnchor() {
  if (typeof window === "undefined" || !window.location.hash) return "";
  return decodeURIComponent(window.location.hash.slice(1));
}

export async function renderTerms(root) {
  const [rawTerms, spots, characters] = await Promise.all([
    loadJson("data/terms.json?v=20260526-term-anchor"),
    loadJson("data/spots.json"),
    loadJson("data/characters.json")
  ]);
  const terms = rawTerms.filter((item) => isVisible(item));
  const spotMap = byId(spots);
  const charMap = byId(characters.filter((item) => isVisible(item) && item.official === true));
  const categories = ["すべて", ...new Set(terms.map((item) => item.category))];
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Terms</div>
      <h1>TERMS</h1>
      <p class="lead">舞台用語を検索できます。</p>
    </header>
    <section class="section">
      <div class="filter-bar">
        <input id="term-search" type="search" placeholder="用語を検索">
        <label>カテゴリ <select id="term-filter">${categories.map((cat) => `<option value="${cat}">${cat}</option>`).join("")}</select></label>
      </div>
      <div id="term-grid" class="grid"></div>
    </section>
  `;
  const grid = root.querySelector("#term-grid");
  const search = root.querySelector("#term-search");
  const select = root.querySelector("#term-filter");
  let highlightTimer = null;

  const draw = () => {
    const keyword = search.value.trim().toLowerCase();
    const selected = select.value;
    const items = terms.filter((item) => {
      const matchedCategory = selected === "すべて" || item.category === selected;
      const matchedKeyword = !keyword || `${item.term} ${item.summary} ${item.category}`.toLowerCase().includes(keyword);
      return matchedCategory && matchedKeyword;
    });
    grid.innerHTML = items.length ? items.map((item) => `
      <article class="card term-card" id="${termAnchorId(item)}" tabindex="-1">
        <span class="tag">${item.category}</span>
        <h2>${item.term}</h2>
        <p>${item.summary}</p>
        <p><strong>関連スポット:</strong> ${textList((item.relatedSpots || []).map((id) => spotMap.get(id)?.name).filter(Boolean))}</p>
        <p><strong>関連NPC:</strong> ${textList((item.relatedCharacters || []).map((id) => charMap.get(id)?.name).filter(Boolean))}</p>
      </article>
    `).join("") : `<div class="empty">該当する用語はありません。</div>`;
  };

  const revealHashTarget = () => {
    const targetId = currentTermAnchor();
    if (!targetId || !targetId.startsWith(termAnchorPrefix)) return;

    if (search.value || select.value !== "すべて") {
      search.value = "";
      select.value = "すべて";
      draw();
    }

    window.setTimeout(() => {
      const target = document.getElementById(targetId);
      if (!target) return;
      root.querySelectorAll(".term-card-highlight").forEach((item) => item.classList.remove("term-card-highlight"));
      target.scrollIntoView({ block: "center", behavior: "smooth" });
      target.focus({ preventScroll: true });
      target.classList.add("term-card-highlight");
      if (highlightTimer) window.clearTimeout(highlightTimer);
      highlightTimer = window.setTimeout(() => {
        target.classList.remove("term-card-highlight");
      }, 4200);
    }, 80);
  };

  search.addEventListener("input", draw);
  select.addEventListener("change", draw);
  draw();
  revealHashTarget();
  window.addEventListener("hashchange", revealHashTarget);
}
