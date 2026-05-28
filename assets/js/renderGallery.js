import { imageFallbackAttr, imageOrPlaceholder, loadJson } from "./dataLoader.js";

const categoryLabels = {
  "key-visual": "キービジュアル",
  locations: "地点",
  facilities: "施設",
  scenarios: "シナリオ",
  hooks: "シナリオ",
  maps: "地図"
};

const categoryOrder = ["key-visual", "locations", "facilities", "scenarios", "maps"];

function categoryLabel(category) {
  return categoryLabels[category] || "その他";
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  })[char]);
}

function normalizeGalleryData(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.images)) return data.images;
  return [];
}

function galleryCard(item, site) {
  const title = escapeHtml(item.title || "無題の画像");
  const description = escapeHtml(item.description || "");
  const category = escapeHtml(categoryLabel(item.category));
  const id = escapeHtml(item.id);
  return `
    <article class="card gallery-card" tabindex="0" role="button" data-gallery-id="${id}" aria-label="${title}を拡大表示">
      <div class="card-visual">
        <img src="${imageOrPlaceholder(item.image, site, "gallery")}" alt="${title}" ${imageFallbackAttr(site, "gallery")}>
      </div>
      <div class="card-meta"><span class="tag">${category}</span></div>
      <h2>${title}</h2>
      <p>${description}</p>
    </article>
  `;
}

function normalizeSearchText(value) {
  return String(value ?? "").normalize("NFKC").toLocaleLowerCase("ja-JP").trim();
}

function gallerySearchText(item) {
  return normalizeSearchText([
    item.title,
    item.description,
    categoryLabel(item.category),
    item.id
  ].filter(Boolean).join(" "));
}

export async function renderGallery(root, site) {
  const items = normalizeGalleryData(await loadJson("data/gallery.json?v=20260528-gallery-search"))
    .filter((item) => item && item.id && item.category && item.image)
    .map((item) => ({ ...item, searchText: gallerySearchText(item) }));
  let visibleItems = [...items];
  let modalItems = [];
  let modalIndex = -1;
  const categories = ["all", ...categoryOrder.filter((category) => items.some((item) => item.category === category))];

  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">GALLERY</div>
      <h1>画像ギャラリー</h1>
      <p class="lead">ヴェルガルドのキービジュアル、地点、施設、シナリオ、地図画像をまとめた資料庫です。</p>
    </header>
    <section class="section">
      <div class="filter-bar gallery-toolbar">
        <div class="gallery-filter-controls">
          <label class="gallery-filter-label">カテゴリ
            <select id="gallery-filter">
              ${categories.map((category) => `<option value="${category}">${category === "all" ? "すべて" : categoryLabel(category)}</option>`).join("")}
            </select>
          </label>
          <label class="gallery-search-label">検索
            <input class="gallery-search-input" id="gallery-search" type="search" placeholder="画像を検索" autocomplete="off">
          </label>
        </div>
        <span class="gallery-count" id="gallery-count" aria-live="polite"></span>
      </div>
      <div id="gallery-grid" class="grid gallery-grid"></div>
    </section>
    <div class="gallery-modal" id="gallery-modal" hidden>
      <div class="gallery-modal-backdrop" data-gallery-close></div>
      <article class="gallery-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="gallery-modal-title">
        <button class="gallery-modal-close button" type="button" data-gallery-close>閉じる</button>
        <div class="gallery-modal-image">
          <img id="gallery-modal-image" src="${imageOrPlaceholder("", site, "gallery")}" alt="">
        </div>
        <div class="gallery-modal-nav" aria-label="画像の前後移動">
          <button class="button gallery-modal-control gallery-modal-prev" type="button" data-gallery-prev aria-label="前の画像へ">← 前へ</button>
          <span class="gallery-modal-counter" id="gallery-modal-counter" aria-live="polite"></span>
          <button class="button gallery-modal-control gallery-modal-next" type="button" data-gallery-next aria-label="次の画像へ">次へ →</button>
        </div>
        <div class="gallery-modal-text">
          <span class="tag" id="gallery-modal-category"></span>
          <h2 id="gallery-modal-title"></h2>
          <p id="gallery-modal-description"></p>
        </div>
      </article>
    </div>
  `;

  const filter = root.querySelector("#gallery-filter");
  const search = root.querySelector("#gallery-search");
  const grid = root.querySelector("#gallery-grid");
  const count = root.querySelector("#gallery-count");
  const modal = root.querySelector("#gallery-modal");
  const modalImage = root.querySelector("#gallery-modal-image");
  const modalTitle = root.querySelector("#gallery-modal-title");
  const modalCategory = root.querySelector("#gallery-modal-category");
  const modalDescription = root.querySelector("#gallery-modal-description");
  const closeButton = root.querySelector(".gallery-modal-close");
  const prevButton = root.querySelector(".gallery-modal-prev");
  const nextButton = root.querySelector(".gallery-modal-next");
  const modalCounter = root.querySelector("#gallery-modal-counter");
  let lastFocused = null;

  const draw = () => {
    const selected = filter.value;
    const query = normalizeSearchText(search.value);
    const categoryItems = items.filter((item) => selected === "all" || item.category === selected);
    visibleItems = categoryItems.filter((item) => !query || item.searchText.includes(query));
    count.textContent = query ? `${visibleItems.length}件 / ${categoryItems.length}件中` : `${visibleItems.length}件`;
    grid.innerHTML = visibleItems.length
      ? visibleItems.map((item) => galleryCard(item, site)).join("")
      : `<div class="empty">検索条件に合う画像がありません。</div>`;
  };

  const closeModal = () => {
    modal.hidden = true;
    document.body.classList.remove("is-modal-open");
    modalItems = [];
    modalIndex = -1;
    if (lastFocused) lastFocused.focus();
  };

  const updateModal = () => {
    const item = modalItems[modalIndex];
    if (!item) return;

    modalImage.onerror = () => {
      modalImage.onerror = null;
      modalImage.src = imageOrPlaceholder("", site, "gallery");
    };
    modalImage.src = imageOrPlaceholder(item.image, site, "gallery");
    modalImage.alt = item.title || "";
    modalTitle.textContent = item.title || "無題の画像";
    modalCategory.textContent = categoryLabel(item.category);
    modalDescription.textContent = item.description || "";
    modalCounter.textContent = `${modalIndex + 1} / ${modalItems.length}`;

    const hasMultipleItems = modalItems.length > 1;
    prevButton.disabled = !hasMultipleItems;
    nextButton.disabled = !hasMultipleItems;
  };

  const moveModal = (direction) => {
    if (modal.hidden || !modalItems.length) return;
    modalIndex = (modalIndex + direction + modalItems.length) % modalItems.length;
    updateModal();
  };

  const openModal = (id, trigger) => {
    modalItems = [...visibleItems];
    modalIndex = modalItems.findIndex((item) => item.id === id);
    if (modalIndex < 0) return;

    lastFocused = trigger;
    updateModal();
    modal.hidden = false;
    document.body.classList.add("is-modal-open");
    closeButton.focus();
  };

  filter.addEventListener("change", draw);
  search.addEventListener("input", draw);
  grid.addEventListener("click", (event) => {
    const card = event.target.closest(".gallery-card");
    if (card) openModal(card.dataset.galleryId, card);
  });
  grid.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const card = event.target.closest(".gallery-card");
    if (!card) return;
    event.preventDefault();
    openModal(card.dataset.galleryId, card);
  });
  modal.addEventListener("click", (event) => {
    if (event.target.hasAttribute("data-gallery-close")) {
      closeModal();
      return;
    }

    if (event.target.hasAttribute("data-gallery-prev")) {
      moveModal(-1);
      return;
    }

    if (event.target.hasAttribute("data-gallery-next")) {
      moveModal(1);
    }
  });
  document.addEventListener("keydown", (event) => {
    if (modal.hidden) return;

    if (event.key === "Escape") {
      closeModal();
      return;
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      moveModal(-1);
      return;
    }

    if (event.key === "ArrowRight") {
      event.preventDefault();
      moveModal(1);
    }
  });

  draw();
}
