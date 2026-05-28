import { imageOrPlaceholder, isVisible, loadJson } from "./dataLoader.js";

function excerpt(text, length = 96) {
  if (!text) return "";
  return text.length > length ? `${text.slice(0, length)}...` : text;
}

export async function renderCampaigns(root, site) {
  const campaigns = (await loadJson("data/campaigns.json")).filter((item) => isVisible(item, true));
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Campaign</div>
      <h1>CAMPAIGN</h1>
      <p class="lead">ヴェルガルドを舞台にした連続キャンペーンの公開トレーラーです。</p>
    </header>
    <section class="section">
      <div class="grid two">
        ${campaigns.map((item) => `
          <article class="card">
            <div class="card-visual"><img src="${imageOrPlaceholder(item.thumbnail || item.image || item.keyVisual, site, "keyvisual")}" alt="${item.title}"></div>
            <div class="card-meta">${item.status === "preparing" ? `<span class="tag status">準備中</span>` : ""}</div>
            <h2>${item.title}</h2>
            ${item.subtitle ? `<p>${item.subtitle}</p>` : ""}
            <p class="lead">${item.catchcopy}</p>
            <p>${excerpt(item.trailer)}</p>
            <div><a class="button primary" href="campaign-detail.html?id=${item.id}">詳細を見る</a></div>
          </article>
        `).join("")}
      </div>
    </section>
  `;
}
