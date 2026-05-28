import { imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson } from "./dataLoader.js";

const SCENARIOS_DATA_URL = "data/scenarios.json?v=20260529-scenario-release-base";

function escapeHtml(value = "") {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  })[char]);
}

function scenarioMeta(item) {
  return [item.category, item.genre].filter(Boolean).join(" / ");
}

function normalizeReleaseStatus(item) {
  const status = item?.releaseStatus || "preparing";
  return ["preparing", "released", "archived"].includes(status) ? status : "preparing";
}

function hasReleaseFiles(item) {
  return Boolean(item?.textUrl || item?.pdfUrl);
}

function releaseBadgeLabel(item) {
  const status = normalizeReleaseStatus(item);
  if (status === "released") return hasReleaseFiles(item) ? "配布中" : "配布準備中";
  if (status === "archived") return "旧版";
  return "準備中";
}

function detailButtonLabel(item) {
  const status = normalizeReleaseStatus(item);
  if (status === "released") return hasReleaseFiles(item) ? "配布情報を見る" : "準備中ページを見る";
  if (status === "archived") return "旧版情報を見る";
  return "準備中ページを見る";
}

function createScenarioImageModal(root, site, items) {
  const modal = document.createElement("div");
  modal.className = "scenario-image-modal";
  modal.hidden = true;
  modal.innerHTML = `
    <div class="scenario-image-modal-backdrop" data-scenario-modal-close></div>
    <div class="scenario-image-modal-content" role="dialog" aria-modal="true" aria-labelledby="scenario-image-modal-title">
      <button class="button scenario-image-modal-close" type="button" data-scenario-modal-close>閉じる</button>
      <div class="scenario-image-modal-image"><img alt=""></div>
      <div class="scenario-image-modal-text">
        <div class="eyebrow">SCENARIOS / シナリオ</div>
        <h2 id="scenario-image-modal-title"></h2>
        <p class="scenario-image-modal-meta"></p>
        <p><span class="tag status scenario-release-status">準備中</span></p>
        <p class="scenario-image-modal-summary"></p>
      </div>
    </div>
  `;
  root.appendChild(modal);

  const itemMap = new Map(items.map((item) => [item.id, item]));
  const image = modal.querySelector("img");
  const titleNode = modal.querySelector("#scenario-image-modal-title");
  const metaNode = modal.querySelector(".scenario-image-modal-meta");
  const statusNode = modal.querySelector(".scenario-release-status");
  const summaryNode = modal.querySelector(".scenario-image-modal-summary");
  const closeButton = modal.querySelector(".scenario-image-modal-close");
  let lastTrigger = null;

  const close = () => {
    modal.hidden = true;
    document.removeEventListener("keydown", onKeydown);
    if (lastTrigger) lastTrigger.focus();
  };

  function onKeydown(event) {
    if (event.key === "Escape") close();
  }

  const open = (item, trigger) => {
    lastTrigger = trigger;
    const title = item.title || item.name || "シナリオ";
    const imageUrl = imageOrPlaceholder(item.image, site, "hook");
    image.src = imageUrl;
    image.alt = title;
    image.onerror = () => {
      image.onerror = null;
      image.src = site?.placeholders?.hook || imageUrl;
    };
    titleNode.textContent = title;
    metaNode.textContent = scenarioMeta(item);
    metaNode.hidden = !metaNode.textContent;
    statusNode.textContent = releaseBadgeLabel(item);
    summaryNode.textContent = item.summary || "";
    summaryNode.hidden = !summaryNode.textContent;
    modal.hidden = false;
    closeButton.focus();
    document.addEventListener("keydown", onKeydown);
  };

  modal.addEventListener("click", (event) => {
    if (event.target.closest("[data-scenario-modal-close]")) close();
  });

  root.addEventListener("click", (event) => {
    const trigger = event.target.closest("[data-scenario-modal-id]");
    if (!trigger) return;
    const item = itemMap.get(trigger.dataset.scenarioModalId);
    if (item) open(item, trigger);
  });

  root.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const trigger = event.target.closest("[data-scenario-modal-id]");
    if (!trigger) return;
    const item = itemMap.get(trigger.dataset.scenarioModalId);
    if (!item) return;
    event.preventDefault();
    open(item, trigger);
  });
}

export async function renderScenarios(root, site) {
  const items = (await loadJson(SCENARIOS_DATA_URL)).filter((item) => isVisible(item));
  const categories = ["すべて", ...new Set(items.map((item) => item.category).filter(Boolean))];
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Scenarios</div>
      <h1>SCENARIOS</h1>
      <p class="lead">ヴェルガルドを舞台にした配布シナリオを掲載予定です。</p>
    </header>
    <section class="section scenarios-prep">
      <article class="article-box scenarios-prep-card">
        <div class="card-meta"><span class="tag status">準備中</span></div>
        <h2>シナリオ</h2>
        <p>現在、作成済みの配布シナリオを掲載する準備を進めています。公開までしばらくお待ちください。</p>
        <p>今後、単発・短編シナリオやキャンペーン用シナリオを追加予定です。</p>
        <div class="scenarios-prep-actions">
          <a class="button" href="campaigns.html">CAMPAIGNを見る</a>
          <a class="button" href="updates.html">更新履歴を見る</a>
        </div>
      </article>
    </section>
    <section class="section">
      <div class="section-head">
        <h2>配布予定シナリオ</h2>
      </div>
      <div class="filter-bar">
        <label>カテゴリ <select id="scenario-filter">${categories.map((category) => `<option value="${category}">${category}</option>`).join("")}</select></label>
      </div>
      <div id="scenario-grid" class="grid scenario-list"></div>
    </section>
  `;
  const grid = root.querySelector("#scenario-grid");
  const select = root.querySelector("#scenario-filter");
  const draw = () => {
    const selected = select.value;
    const visibleItems = items.filter((item) => selected === "すべて" || item.category === selected);
    grid.innerHTML = visibleItems.map((item) => {
      const title = item.title || item.name || "シナリオ";
      const safeTitle = escapeHtml(title);
      const releaseStatus = normalizeReleaseStatus(item);
      const badgeLabel = releaseBadgeLabel(item);
      const buttonLabel = detailButtonLabel(item);
      return `
        <article class="card scenario-card">
          <button class="card-visual scenario-card-image scenario-image-clickable" type="button" data-scenario-modal-id="${escapeHtml(item.id)}" aria-label="${safeTitle}の画像を拡大表示">
            <img src="${imageOrPlaceholder(item.image, site, "hook")}" alt="${safeTitle}" ${imageFallbackAttr(site, "hook")}>
          </button>
          <div class="card-meta">
            <span class="tag status scenario-card-status scenario-release-status scenario-release-status--${releaseStatus}">${escapeHtml(badgeLabel)}</span>
            ${item.category ? `<span class="tag">${escapeHtml(item.category)}</span>` : ""}
            ${item.genre ? `<span class="tag">${escapeHtml(item.genre)}</span>` : ""}
          </div>
          <h2>${safeTitle}</h2>
          <p>${escapeHtml(item.summary || "配布シナリオ概要は準備中です。")}</p>
          <div><a class="button primary" href="scenario-detail.html?id=${escapeHtml(item.id)}">${escapeHtml(buttonLabel)}</a></div>
        </article>
      `;
    }).join("");
  };
  select.addEventListener("change", draw);
  createScenarioImageModal(root, site, items);
  draw();
}
