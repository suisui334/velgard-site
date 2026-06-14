import {
  escapeActivityHtml,
  formatActivityDateTime,
  getActivitySessionLabel,
  getActivityTitle,
  normalizeActivityTargetPath
} from "./activityTimelineDisplay.js?v=20260611-home-activity";
import { imageFallbackAttr, imageOrPlaceholder } from "./dataLoader.js";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js";
import {
  getCurrentMembershipState,
  isApprovedMembershipState,
  shouldHideCommunityNav
} from "./membershipAccessClient.js?v=20260615-core-config-move";

const homeNavItems = [
  { label: "WORLD", href: "world.html", text: "舞台紹介" },
  { label: "CHARACTERS", href: "characters.html", text: "公式NPC" },
  { label: "SPOTS", href: "spots.html", text: "主要スポット" },
  { label: "SCENARIOS", href: "scenarios.html", text: "シナリオ" },
  { label: "GALLERY", href: "gallery.html", text: "画像資料" },
  { label: "TOOLS", href: "tools.html", text: "補助ツール" },
  { label: "CALENDAR", href: "calendar.html", text: "運用カレンダー", requiresApproved: true },
  { label: "TERMS", href: "terms.html", text: "用語集" },
  { label: "UPDATES", href: "updates.html", text: "更新履歴" },
  { label: "REGULATION", href: "regulation.html", text: "開催規約" },
  { label: "CAMPAIGN", href: "campaigns.html", text: "仮公開" }
];

const HOME_ACTIVITY_LIMIT = 5;

async function loadHomeActivities(membershipState = null) {
  const access = membershipState || await getCurrentMembershipState();
  const client = access.client || await createSupabaseBrowserClient();
  if (!client) {
    return { items: [], isAuthenticated: false, isApproved: false, hasError: true };
  }

  const isAuthenticated = Boolean(access.isAuthenticated);
  const isApproved = isApprovedMembershipState(access);
  if (!isApproved) {
    return { items: [], isAuthenticated, isApproved, hasError: false };
  }

  const { data, error } = await client.rpc("get_activity_timeline", { p_limit: HOME_ACTIVITY_LIMIT });
  if (error) {
    return { items: [], isAuthenticated, isApproved, hasError: true };
  }

  return {
    items: Array.isArray(data) ? data : [],
    isAuthenticated,
    isApproved,
    hasError: false
  };
}

function renderHomeActivityList(activityState) {
  if (!activityState.items.length) {
    if (activityState.hasError) {
      return `<p class="empty">最近の活動を読み込めませんでした。</p>`;
    }
    if (!activityState.isAuthenticated) {
      return `<p class="empty">ログインすると最近の活動を確認できます。</p>`;
    }
    if (!activityState.isApproved) {
      return `<p class="empty">承認後に最近の活動を確認できます。</p>`;
    }
    return `<p class="empty">まだ更新はありません。</p>`;
  }

  return activityState.items.map((item) => {
    const href = escapeActivityHtml(normalizeActivityTargetPath(item?.target_path));
    const title = escapeActivityHtml(getActivityTitle(item));
    const session = escapeActivityHtml(getActivitySessionLabel(item));
    const createdAt = formatActivityDateTime(item?.created_at, { includeYear: false });
    return `
      <a href="${href}" class="home-latest-item home-activity-item">
        <time>${escapeActivityHtml(createdAt)}</time>
        <span>
          <strong>${title}</strong>
          <small>${session}</small>
        </span>
      </a>
    `;
  }).join("");
}

export async function renderHome(root, site, options = {}) {
  const membershipState = options.membershipState || null;
  const activityState = await loadHomeActivities(options.membershipState);
  const hideCommunityNav = shouldHideCommunityNav(membershipState);
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
        ${homeNavItems.filter((item) => !(item.requiresApproved && hideCommunityNav)).map((item) => `
          <a href="${item.href}" class="${item.subtle ? "is-subtle" : ""}">
            <span class="home-nav-label">${item.label}</span>
            <span class="home-nav-text">${item.text}</span>
          </a>
        `).join("")}
      </nav>
      <section class="home-latest" aria-labelledby="home-activity-title">
        <div class="home-latest-head">
          <h2 id="home-activity-title">TIMELINE</h2>
          ${hideCommunityNav ? "" : `<a href="timeline.html">ALL</a>`}
        </div>
        <div class="home-latest-list">
          ${renderHomeActivityList(activityState)}
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
