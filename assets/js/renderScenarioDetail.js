import { byId, getParams, imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

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

function safeResourceUrl(value) {
  if (typeof value !== "string") return "";
  const url = value.trim();
  if (!url || /^javascript:/i.test(url)) return "";
  return url;
}

function getReleaseInfo(item) {
  const status = normalizeReleaseStatus(item);
  const textUrl = safeResourceUrl(item.textUrl);
  const pdfUrl = safeResourceUrl(item.pdfUrl);
  const hasFiles = Boolean(textUrl || pdfUrl);
  const info = {
    status,
    textUrl,
    pdfUrl,
    hasFiles,
    label: "準備中",
    title: "シナリオ本文は準備中です。",
    body: "本文ファイルが提供されたあと、TXT/PDFの導線を追加します。"
  };

  if (status === "released") {
    info.label = hasFiles ? "配布中" : "配布準備中";
    info.title = hasFiles ? "配布ファイルを公開中です。" : "配布状態ですが、ファイルは未登録です。";
    info.body = hasFiles
      ? "TXT本文またはPDFが登録されている場合のみ、下記に閲覧・ダウンロード導線を表示します。"
      : "公開ファイルが登録されるまで、閲覧・ダウンロード導線は表示しません。";
  }

  if (status === "archived") {
    info.label = "旧版";
    info.title = "このシナリオは旧版または配布終了扱いです。";
    info.body = hasFiles
      ? "旧版ファイルとして参照できる導線のみ表示します。利用時は卓内の採用可否を確認してください。"
      : "現在参照できる配布ファイルはありません。";
  }

  return info;
}

function renderReleaseMeta(item) {
  const rows = [
    ["バージョン", item.version],
    ["公開日", item.releaseDate],
    ["最終更新", item.lastUpdated],
    ["備考", item.fileNote]
  ].filter(([, value]) => value);

  if (!rows.length) return "";

  return `
    <dl class="scenario-release-meta">
      ${rows.map(([label, value]) => `
        <div>
          <dt>${escapeHtml(label)}</dt>
          <dd>${escapeHtml(value)}</dd>
        </div>
      `).join("")}
    </dl>
  `;
}

function renderReleaseActions(info) {
  const actions = [];
  if (info.textUrl) {
    actions.push(`<a class="button primary" href="${escapeHtml(info.textUrl)}" target="_blank" rel="noopener">TXTを開く</a>`);
  }
  if (info.pdfUrl) {
    actions.push(`<a class="button" href="${escapeHtml(info.pdfUrl)}" target="_blank" rel="noopener">PDFを開く</a>`);
  }
  if (!actions.length) return "";
  return `<div class="scenario-release-actions">${actions.join("")}</div>`;
}

function renderTextViewer(info) {
  if (!info.textUrl) return "";
  return `
    <div class="scenario-text-panel" data-scenario-text-viewer data-scenario-text-url="${escapeHtml(info.textUrl)}">
      <h3>TXT本文</h3>
      <pre class="scenario-text-content" data-scenario-text-content>TXT本文を読み込んでいます...</pre>
    </div>
  `;
}

function renderReleaseSection(item) {
  const info = getReleaseInfo(item);
  const statusClass = `scenario-release-info--${info.status}`;

  return `
    <section class="section">
      <article class="article-box scenario-release-info ${statusClass}">
        <div class="eyebrow">Release</div>
        <h2>配布情報</h2>
        <div class="card-meta">
          <span class="tag status scenario-detail-status scenario-release-status scenario-release-status--${info.status}">${escapeHtml(info.label)}</span>
        </div>
        <h3>${escapeHtml(info.title)}</h3>
        <p>${escapeHtml(info.body)}</p>
        ${renderReleaseMeta(item)}
        ${renderReleaseActions(info)}
        ${renderTextViewer(info)}
      </article>
    </section>
  `;
}

async function hydrateScenarioText(root) {
  const viewers = [...root.querySelectorAll("[data-scenario-text-viewer]")];
  await Promise.all(viewers.map(async (viewer) => {
    const target = viewer.querySelector("[data-scenario-text-content]");
    const url = viewer.dataset.scenarioTextUrl;
    if (!target || !url) return;

    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error("TXT本文を読み込めませんでした。");
      const text = await response.text();
      target.textContent = text || "TXT本文は空です。";
    } catch (error) {
      target.textContent = error.message || "TXT本文を読み込めませんでした。";
    }
  }));
}

function createScenarioImageModal(root, site, item) {
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

  const open = (trigger) => {
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
    statusNode.textContent = getReleaseInfo(item).label;
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
    if (trigger) open(trigger);
  });

  root.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const trigger = event.target.closest("[data-scenario-modal-id]");
    if (!trigger) return;
    event.preventDefault();
    open(trigger);
  });
}

function notFound(root) {
  root.innerHTML = `
    <section class="section">
      <div class="notice">
        <p>シナリオが見つかりません。</p>
        <p><a class="button" href="scenarios.html">シナリオ一覧へ戻る</a></p>
      </div>
    </section>
  `;
}

export async function renderScenarioDetail(root, site) {
  const id = getParams().get("id");
  if (!id) {
    notFound(root);
    return;
  }

  const [items, spots, characters] = await Promise.all([
    loadJson(SCENARIOS_DATA_URL),
    loadJson("data/spots.json"),
    loadJson("data/characters.json?v=20260526-age")
  ]);
  const item = byId(items.filter((entry) => isVisible(entry))).get(id);
  if (!item) {
    notFound(root);
    return;
  }

  const spotMap = byId(spots);
  const characterMap = byId(characters.filter((entry) => isVisible(entry) && entry.official === true));
  const relatedSpotNames = (item.relatedSpots || item.relatedSpotIds || []).map((spotId) => spotMap.get(spotId)?.name).filter(Boolean);
  const relatedCharacterNames = (item.relatedCharacters || item.relatedNpcIds || []).map((characterId) => characterMap.get(characterId)?.name).filter(Boolean);
  const title = item.title || item.name || "シナリオ";
  const safeTitle = escapeHtml(title);
  const releaseInfo = getReleaseInfo(item);

  root.innerHTML = `
    <section class="detail-hero scenario-detail-hero">
      <button class="page-visual scenario-detail-image scenario-image-clickable" type="button" data-scenario-modal-id="${escapeHtml(item.id)}" aria-label="${safeTitle}の画像を拡大表示">
        <img src="${imageOrPlaceholder(item.image, site, "hook")}" alt="${safeTitle}" ${imageFallbackAttr(site, "hook")}>
      </button>
      <div class="hero-copy">
        <div class="eyebrow">SCENARIOS / シナリオ</div>
        <h1>${safeTitle}</h1>
        <div class="card-meta">
          <span class="tag status scenario-detail-status scenario-release-status scenario-release-status--${releaseInfo.status}">${escapeHtml(releaseInfo.label)}</span>
          ${item.category ? `<span class="tag">${escapeHtml(item.category)}</span>` : ""}
          ${item.genre ? `<span class="tag">${escapeHtml(item.genre)}</span>` : ""}
        </div>
        <p class="lead">${escapeHtml(item.summary || "配布シナリオ概要は準備中です。")}</p>
        <p><a class="button" href="scenarios.html">シナリオ一覧へ戻る</a></p>
      </div>
    </section>
    ${renderReleaseSection(item)}
    <section class="section scenario-detail-related">
      <div class="section-head"><h2>関連情報</h2></div>
      <div class="grid two">
        <article class="card">
          <h3>関連スポット</h3>
          <p>${textList(relatedSpotNames)}</p>
        </article>
        <article class="card">
          <h3>関連NPC</h3>
          <p>${textList(relatedCharacterNames)}</p>
        </article>
      </div>
    </section>
  `;
  createScenarioImageModal(root, site, item);
  await hydrateScenarioText(root);
}
