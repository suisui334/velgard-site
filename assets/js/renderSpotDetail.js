import { byId, getParams, imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

const categoryLabels = {
  maps: "地図",
  locations: "地点",
  facilities: "施設",
  hooks: "シナリオ",
  "key-visual": "キービジュアル"
};

function categoryLabel(category) {
  return categoryLabels[category] || "画像";
}

function paragraphs(value) {
  const items = Array.isArray(value) ? value.filter(Boolean) : [value].filter(Boolean);
  return items.map((text) => `<p>${text}</p>`).join("");
}

function section(title, html, className = "") {
  return html ? `<section class="section ${className}"><div class="section-head"><h2>${title}</h2></div>${html}</section>` : "";
}

function galleryCards(ids, galleryMap, site, type = "gallery") {
  const items = (ids || []).map((id) => galleryMap.get(id)).filter(Boolean);
  if (!items.length) return "";
  return `<div class="grid two spot-detail-gallery">
    ${items.map((item) => `
      <article class="card">
        <div class="card-visual spot-detail-image spot-detail-image-clickable" role="button" tabindex="0" data-spot-gallery-id="${item.id}" aria-label="${item.title}を拡大表示"><img src="${imageOrPlaceholder(item.image, site, type)}" alt="${item.title}" ${imageFallbackAttr(site, type)}></div>
        <div class="card-meta"><span class="tag">${categoryLabel(item.category)}</span></div>
        <h3>${item.title}</h3>
        ${item.description ? `<p>${item.description}</p>` : ""}
      </article>
    `).join("")}
  </div>`;
}

function linkCards(items, title, href, note = "") {
  const links = (items || []).map((item) => {
    if (!item) return null;
    if (typeof item === "string") return { label: item, href };
    const label = item.label || item.term || item.title || item.name;
    return label ? { label, href: item.href || href } : null;
  }).filter(Boolean);
  if (!links.length) return "";
  return `
    <article class="card spot-detail-related-card">
      <h3>${title}</h3>
      <div class="tag-list">
        ${links.map((item) => `<a class="tag link-tag" href="${item.href}">${item.label}</a>`).join("")}
      </div>
      ${note ? `<p class="related-note">${note}</p>` : ""}
    </article>
  `;
}

function termLink(item) {
  const label = item?.term || item?.title || item?.name;
  return item && label ? { label, href: `terms.html#term-${item.id}` } : null;
}

function setupImageModal(root, galleryMap, site) {
  const modal = root.querySelector("#spot-image-modal");
  const modalImage = root.querySelector("#spot-image-modal-image");
  const modalTitle = root.querySelector("#spot-image-modal-title");
  const modalDescription = root.querySelector("#spot-image-modal-description");
  const closeButton = root.querySelector(".spot-image-modal-close");
  if (!modal || !modalImage || !modalTitle || !modalDescription || !closeButton) return;
  let lastFocused = null;

  const closeModal = () => {
    modal.hidden = true;
    if (typeof document !== "undefined") document.body.classList.remove("is-modal-open");
    if (lastFocused) lastFocused.focus();
  };

  const openModal = (id, trigger) => {
    const item = galleryMap.get(id);
    if (!item) return;
    lastFocused = trigger;
    modalImage.onerror = () => {
      modalImage.onerror = null;
      modalImage.src = imageOrPlaceholder("", site, "gallery");
    };
    modalImage.src = imageOrPlaceholder(item.image, site, "gallery");
    modalImage.alt = item.title || "";
    modalTitle.textContent = item.title || "無題の画像";
    modalDescription.textContent = item.description || "";
    modal.hidden = false;
    if (typeof document !== "undefined") document.body.classList.add("is-modal-open");
    closeButton.focus();
  };

  root.addEventListener?.("click", (event) => {
    const image = event.target.closest?.(".spot-detail-image-clickable");
    if (image) openModal(image.dataset.spotGalleryId, image);
    if (event.target.hasAttribute?.("data-spot-image-close")) closeModal();
  });

  root.addEventListener?.("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const image = event.target.closest?.(".spot-detail-image-clickable");
    if (!image) return;
    event.preventDefault();
    openModal(image.dataset.spotGalleryId, image);
  });

  if (typeof document !== "undefined") document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.hidden) closeModal();
  });
}

function notFound(root, message) {
  root.innerHTML = `
    <section class="section">
      <div class="notice">
        <p>${message}</p>
        <p><a class="button" href="spots.html">スポット一覧へ戻る</a></p>
      </div>
    </section>
  `;
}

export async function renderSpotDetail(root, site) {
  const id = getParams().get("id");
  if (!id) {
    notFound(root, "スポットIDが指定されていません。");
    return;
  }

  const [spots, details, gallery, characters, scenarios, terms] = await Promise.all([
    loadJson("data/spots.json"),
    loadJson("data/spotDetails.json?v=20260528-spotdetail-scenarios-only"),
    loadJson("data/gallery.json?v=20260527-graywall-line-map"),
    loadJson("data/characters.json?v=20260526-age"),
    loadJson("data/scenarios.json?v=20260528-spotdetail-scenarios-only"),
    loadJson("data/terms.json?v=20260526-term-anchor")
  ]);

  const spot = byId(spots).get(id);
  const detail = byId(details).get(id);
  if (!isVisible(spot) || !detail) {
    notFound(root, "スポット詳細が見つかりません。");
    return;
  }

  const galleryMap = byId(gallery);
  const characterMap = byId(characters.filter((item) => isVisible(item) && item.official === true));
  const scenarioMap = byId(scenarios.filter((item) => isVisible(item)));
  const termMap = byId(terms.filter((item) => isVisible(item)));
  const heroGalleryItem = gallery.find((item) => item.image && item.image === spot.image);

  const maps = galleryCards(detail.mapGalleryIds, galleryMap, site, "gallery");
  const relatedImages = galleryCards(detail.relatedGalleryIds, galleryMap, site, "gallery");
  const relatedFacilities = galleryCards(detail.relatedFacilityGalleryIds, galleryMap, site, "gallery");
  const relatedCharacters = (detail.relatedCharacterIds || []).map((itemId) => {
    const item = characterMap.get(itemId);
    return item?.name ? { label: item.name, href: `characters.html#character-${item.id}` } : null;
  }).filter(Boolean);
  const scenarioIds = detail.relatedScenarioIds || [];
  const relatedScenarios = scenarioIds.map((itemId) => {
    const item = scenarioMap.get(itemId);
    return item?.title ? { label: item.title, href: `scenario-detail.html?id=${item.id}` } : null;
  }).filter(Boolean);
  const relatedTerms = (detail.relatedTermIds || []).map((itemId) => termLink(termMap.get(itemId))).filter(Boolean);

  const sections = (detail.sections || []).map((item) => `
    <article class="article-box spot-detail-section">
      <h2>${item.title}</h2>
      ${paragraphs(item.paragraphs)}
    </article>
  `).join("");

  root.innerHTML = `
    <section class="detail-hero spot-detail-hero">
      <div class="page-visual${heroGalleryItem ? " spot-detail-image-clickable" : ""}" ${heroGalleryItem ? `role="button" tabindex="0" data-spot-gallery-id="${heroGalleryItem.id}" aria-label="${heroGalleryItem.title}を拡大表示"` : ""}><img src="${imageOrPlaceholder(spot.image, site, "spot")}" alt="${spot.name}" ${imageFallbackAttr(site, "spot")}></div>
      <div class="hero-copy">
        <div class="eyebrow">Spot Detail</div>
        <h1>${spot.name}</h1>
        <div class="card-meta">
          ${detail.definition ? `<span class="tag spot-detail-definition">${detail.definition}</span>` : ""}
          ${spot.category ? `<span class="tag">${spot.category}</span>` : ""}
        </div>
        <p class="lead">${detail.lead || spot.summary}</p>
        <p><a class="button" href="spots.html">スポット一覧へ戻る</a></p>
      </div>
    </section>
    <section class="section">
      <div class="grid two">
        <article class="article-box">
          <div class="eyebrow">PROFILE</div>
          <p><strong>役割:</strong> ${spot.role || "未設定"}</p>
          <p><strong>主な導入:</strong> ${textList(spot.hooks || spot.introductions)}</p>
          <p><strong>関連組織:</strong> ${textList(spot.organizations)}</p>
        </article>
        <article class="article-box">
          <div class="eyebrow">SUMMARY</div>
          <p>${spot.summary}</p>
        </article>
      </div>
    </section>
    <section class="section">
      <div class="article">${sections}</div>
    </section>
    ${section("MAP", maps, "spot-detail-map")}
    ${section("関連画像", relatedImages, "spot-detail-gallery-section")}
    ${section("関連施設画像", relatedFacilities, "spot-detail-gallery-section")}
    <section class="section spot-detail-related">
      <div class="section-head"><h2>関連情報</h2></div>
      <div class="grid">
        ${linkCards(relatedCharacters, "関連NPC", "characters.html")}
        ${linkCards(relatedScenarios, "関連シナリオ", "scenarios.html", "配布シナリオは準備中です。")}
        ${linkCards(relatedTerms, "関連用語", "terms.html")}
      </div>
    </section>
    <div class="spot-image-modal" id="spot-image-modal" hidden>
      <div class="spot-image-modal-backdrop" data-spot-image-close></div>
      <article class="spot-image-modal-content" role="dialog" aria-modal="true" aria-labelledby="spot-image-modal-title">
        <button class="spot-image-modal-close button" type="button" data-spot-image-close>閉じる</button>
        <div class="spot-image-modal-image">
          <img id="spot-image-modal-image" src="${imageOrPlaceholder("", site, "gallery")}" alt="">
        </div>
        <div class="spot-image-modal-text">
          <h2 id="spot-image-modal-title"></h2>
          <p id="spot-image-modal-description"></p>
        </div>
      </article>
    </div>
  `;
  setupImageModal(root, galleryMap, site);
}
