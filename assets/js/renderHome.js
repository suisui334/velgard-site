import { imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson } from "./dataLoader.js";

const homeNavItems = [
  { label: "WORLD", href: "world.html", text: "舞台紹介" },
  { label: "CHARACTERS", href: "characters.html", text: "公式NPC" },
  { label: "SPOTS", href: "spots.html", text: "主要スポット" },
  { label: "SCENARIOS", href: "scenarios.html", text: "シナリオ" },
  { label: "GALLERY", href: "gallery.html", text: "画像資料" },
  { label: "TOOLS", href: "tools.html", text: "補助ツール" },
  { label: "CALENDAR", href: "calendar.html", text: "運用カレンダー" },
  { label: "TERMS", href: "terms.html", text: "用語集" },
  { label: "UPDATES", href: "updates.html", text: "更新履歴" },
  { label: "REGULATION", href: "regulation.html", text: "開催規約" },
  { label: "CAMPAIGN", href: "campaigns.html", text: "仮公開" }
];

function sortUpdates(items) {
  return [...items].sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
}

export async function renderHome(root, site) {
  const updates = await loadJson("data/updates.json");
  const latest = sortUpdates(updates.filter((item) => isVisible(item) || !item.status)).slice(0, 3);
  const logoImage = site.logoImage && site.logoImage.trim() ? site.logoImage : "";
  const keyvisualImage = imageOrPlaceholder(site.keyvisual, site, "keyvisual");
  const logoFallback = `
    <span class="home-logo-kicker">“灰壁と花霧の国”</span>
    <span class="home-logo-main">VELGARD</span>
    <span class="home-logo-sub">ヴェルガルド</span>
  `;
  const logoMarkup = `
    <h1 class="home-logo ${logoImage ? "home-logo-with-image" : "is-logo-fallback"}" id="home-logo-title">
      <span class="home-logo-fallback">${logoFallback}</span>
      ${logoImage ? `
        <button class="home-logo-button home-logo-clickable" type="button" aria-label="正式ロゴを拡大表示">
          <img class="home-logo-image" src="${logoImage}" alt="“灰壁と花霧の国”ヴェルガルド" onerror="this.closest('.home-logo-button').hidden=true;this.closest('.home-logo').classList.add('is-logo-fallback');">
        </button>
      ` : ""}
    </h1>
  `;
  root.innerHTML = `
    <section class="home-landing" aria-labelledby="home-logo-title">
      <div class="home-intro">
        <div class="eyebrow">Official Player Guide</div>
        ${logoMarkup}
      </div>
      <nav class="home-nav" aria-label="トップページ主要ナビゲーション">
        ${homeNavItems.map((item) => `
          <a href="${item.href}" class="${item.subtle ? "is-subtle" : ""}">
            <span class="home-nav-label">${item.label}</span>
            <span class="home-nav-text">${item.text}</span>
          </a>
        `).join("")}
      </nav>
      <section class="home-latest" aria-labelledby="home-latest-title">
        <div class="home-latest-head">
          <h2 id="home-latest-title">LATEST</h2>
          <a href="updates.html">ALL</a>
        </div>
        <div class="home-latest-list">
          ${latest.length ? latest.map((item) => `
            <a href="updates.html" class="home-latest-item">
              <time>${item.date || ""}</time>
              <span>${item.title || "更新"}</span>
            </a>
          `).join("") : `<p class="empty">更新履歴はまだありません。</p>`}
        </div>
      </section>
      <div class="home-visual">
        <button class="home-keyvisual-button home-keyvisual-clickable" type="button" aria-label="キービジュアルを拡大表示">
          <img src="${keyvisualImage}" alt="ヴェルガルド キービジュアル" ${imageFallbackAttr(site, "keyvisual")}>
        </button>
      </div>
    </section>
    ${logoImage ? `
      <div class="home-logo-modal" role="dialog" aria-modal="true" aria-label="正式ロゴ拡大表示" aria-hidden="true" hidden>
        <div class="home-logo-modal-backdrop" aria-hidden="true"></div>
        <div class="home-logo-modal-content">
          <button class="home-logo-modal-close" type="button" aria-label="閉じる">×</button>
          <img class="home-logo-modal-image" src="${logoImage}" alt="“灰壁と花霧の国”ヴェルガルド">
        </div>
      </div>
    ` : ""}
    <div class="home-keyvisual-modal" role="dialog" aria-modal="true" aria-label="キービジュアル拡大表示" aria-hidden="true" hidden>
      <div class="home-keyvisual-modal-backdrop" aria-hidden="true"></div>
      <div class="home-keyvisual-modal-content">
        <button class="home-keyvisual-modal-close" type="button" aria-label="閉じる">×</button>
        <img class="home-keyvisual-modal-image" src="${keyvisualImage}" alt="ヴェルガルド キービジュアル" ${imageFallbackAttr(site, "keyvisual")}>
      </div>
    </div>
  `;
  setupHomeImageModal(root, {
    triggerSelector: ".home-logo-clickable",
    modalSelector: ".home-logo-modal",
    closeSelector: ".home-logo-modal-close",
    backdropSelector: ".home-logo-modal-backdrop"
  });
  setupHomeImageModal(root, {
    triggerSelector: ".home-keyvisual-clickable",
    modalSelector: ".home-keyvisual-modal",
    closeSelector: ".home-keyvisual-modal-close",
    backdropSelector: ".home-keyvisual-modal-backdrop"
  });
}

function setupHomeImageModal(root, selectors) {
  const trigger = root.querySelector(selectors.triggerSelector);
  const modal = root.querySelector(selectors.modalSelector);
  const closeButton = root.querySelector(selectors.closeSelector);
  const backdrop = root.querySelector(selectors.backdropSelector);

  if (!trigger || !modal || !closeButton) return;

  let lastFocused = null;

  const openModal = () => {
    if (trigger.hidden) return;
    lastFocused = trigger;
    modal.hidden = false;
    modal.setAttribute("aria-hidden", "false");
    document.body.classList.add("is-modal-open");
    closeButton.focus();
  };

  const closeModal = () => {
    modal.hidden = true;
    modal.setAttribute("aria-hidden", "true");
    document.body.classList.remove("is-modal-open");
    if (lastFocused && typeof lastFocused.focus === "function") {
      [0, 120, 280].forEach((delay) => {
        window.setTimeout(() => lastFocused.focus(), delay);
      });
    }
  };

  trigger.addEventListener("click", openModal);
  trigger.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    openModal();
  });
  closeButton.addEventListener("click", closeModal);
  modal.addEventListener("click", (event) => {
    if (event.target === modal || event.target === backdrop) {
      closeModal();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.hidden) {
      closeModal();
    }
  });
}
