import { isVisible, loadJson } from "./dataLoader.js";

function sortUpdates(items) {
  return [...items].sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
}

function updateCard(item, heading = "h2") {
  const tags = Array.isArray(item.tags) ? item.tags : [];
  return `
    <article class="card update-item">
      <time class="update-date">${item.date || ""}</time>
      <div>
        <div class="card-meta">${item.target ? `<span class="tag">${item.target}</span>` : ""}${tags.map((tag) => `<span class="tag">${tag}</span>`).join("")}</div>
        <${heading}>${item.title || "更新"}</${heading}>
        <p>${item.description || item.body || ""}</p>
      </div>
    </article>
  `;
}

export async function renderUpdates(root) {
  const updates = sortUpdates((await loadJson("data/updates.json")).filter((item) => isVisible(item) || !item.status));
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Updates</div>
      <h1>UPDATES</h1>
      <p class="lead">サイトの更新履歴です。</p>
    </header>
    <section class="section">
      <div class="updates-list">
        ${updates.length ? updates.map((item) => updateCard(item)).join("") : `<div class="empty">更新履歴はまだありません。</div>`}
      </div>
    </section>
  `;
}
