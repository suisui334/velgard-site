import { loadJson } from "./dataLoader.js";
import { renderHome } from "./renderHome.js?v=20260529-calendar-phase1";
import { renderWorld } from "./renderWorld.js?v=20260528-responsive-ui-fix";
import { renderCampaigns } from "./renderCampaigns.js";
import { renderCampaignDetail } from "./renderCampaignDetail.js";
import { renderEpisodeDetail } from "./renderEpisodeDetail.js";
import { renderRegulation } from "./renderRegulation.js?v=20260526-regulation-toc";
import { renderSpots } from "./renderSpots.js";
import { renderSpotDetail } from "./renderSpotDetail.js?v=20260529-ui-polish";
import { renderCharacters } from "./renderCharacters.js?v=20260529-ui-polish";
import { renderScenarios } from "./renderScenarios.js?v=20260529-scenario-release-base";
import { renderScenarioDetail } from "./renderScenarioDetail.js?v=20260529-scenario-release-base";
import { renderTerms } from "./renderTerms.js?v=20260526-term-anchor";
import { renderGallery } from "./renderGallery.js?v=20260528-gallery-search";
import { renderUpdates } from "./renderUpdates.js";
import { renderTools } from "./renderTools.js?v=20260529-tools-history-full";
import { renderCalendar } from "./renderCalendar.js?v=20260529-calendar-cap-start";

const navItems = [
  { label: "TOP", href: "index.html", key: "home", enabled: true },
  { label: "WORLD", href: "world.html", key: "world", enabled: true },
  { label: "CAMPAIGN", href: "campaigns.html", key: "campaigns", enabled: true },
  { label: "REGULATION", href: "regulation.html", key: "regulation", enabled: true },
  { label: "SPOT", href: "spots.html", key: "spots", enabled: true },
  { label: "CHARACTER", href: "characters.html", key: "characters", enabled: true },
  { label: "SCENARIOS", href: "scenarios.html", key: "scenarios", enabled: true },
  { label: "TERMS", href: "terms.html", key: "terms", enabled: true },
  { label: "GALLERY", href: "gallery.html", key: "gallery", enabled: true },
  { label: "TOOLS", href: "tools.html", key: "tools", enabled: true },
  { label: "CALENDAR", href: "calendar.html", key: "calendar", enabled: true }
];

const renderers = {
  home: renderHome,
  world: renderWorld,
  campaigns: renderCampaigns,
  "campaign-detail": renderCampaignDetail,
  "episode-detail": renderEpisodeDetail,
  regulation: renderRegulation,
  spots: renderSpots,
  "spot-detail": renderSpotDetail,
  characters: renderCharacters,
  hooks: renderScenarios,
  scenarios: renderScenarios,
  "scenario-detail": renderScenarioDetail,
  terms: renderTerms,
  gallery: renderGallery,
  updates: renderUpdates,
  tools: renderTools,
  calendar: renderCalendar
};

function renderHeader(site, page) {
  const header = document.querySelector("#site-header");
  const links = navItems.filter((item) => item.enabled).map(({ label, href, key }) => {
    const active = page === key || (page === "campaign-detail" && key === "campaigns") || (page === "episode-detail" && key === "campaigns") || (page === "spot-detail" && key === "spots") || ((page === "scenario-detail" || page === "hooks") && key === "scenarios");
    return `<a href="${href}" class="${active ? "is-active" : ""}">${label}</a>`;
  }).join("");
  header.innerHTML = `
    <header class="site-header">
      <div class="header-inner">
        <a class="brand" href="index.html">
          <span class="brand-mark">Sword World 2.5 Stage</span>
          <span class="brand-title">${site.title}</span>
        </a>
        <button class="nav-toggle" type="button" aria-label="メニューを開く" aria-expanded="false">☰</button>
        <nav class="global-nav" aria-label="グローバルナビゲーション">${links}</nav>
      </div>
    </header>
  `;
  const toggle = header.querySelector(".nav-toggle");
  const nav = header.querySelector(".global-nav");
  toggle.addEventListener("click", () => {
    const opened = nav.classList.toggle("is-open");
    toggle.setAttribute("aria-expanded", String(opened));
  });
}

function renderFooter(site) {
  document.querySelector("#site-footer").innerHTML = `
    <footer class="site-footer">
      <div class="footer-inner">
        <div>
          <h2>${site.shortTitle}</h2>
          <p>${site.description}</p>
        </div>
        <div class="footer-links">
          ${navItems.filter((item) => item.enabled).map(({ label, href }) => `<a href="${href}">${label}</a>`).join("")}
          <a href="updates.html">UPDATES</a>
        </div>
      </div>
    </footer>
  `;
}

function applyTheme(site) {
  const theme = site.theme || {};
  const root = document.documentElement;
  const backgroundImage = theme.backgroundImage ? new URL(theme.backgroundImage, document.baseURI).href : "";
  root.style.setProperty("--theme-bg-image", backgroundImage ? `url("${backgroundImage}")` : "none");
  root.style.setProperty("--theme-bg-blur", theme.backgroundBlur || "0px");
  root.style.setProperty("--theme-bg-opacity", theme.backgroundOpacity ?? 0.32);
  root.style.setProperty("--theme-bg-saturation", theme.backgroundSaturation ?? 0.82);
  root.style.setProperty("--theme-overlay-color", theme.overlayColor || "rgba(239, 241, 239, 0.68)");
  root.style.setProperty("--content-panel-opacity", theme.panelOpacity ?? theme.contentPanelOpacity ?? 0.9);
  root.style.setProperty("--card-opacity", theme.cardOpacity ?? 0.88);
  document.body.classList.toggle("has-theme-background", Boolean(backgroundImage));
}

function setupBackToTopButton() {
  if (document.querySelector("[data-back-to-top]")) return;

  const button = document.createElement("button");
  button.className = "back-to-top";
  button.type = "button";
  button.setAttribute("aria-label", "ページ上部へ戻る");
  button.setAttribute("aria-hidden", "true");
  button.setAttribute("data-back-to-top", "");
  button.tabIndex = -1;
  button.textContent = "↑";
  document.body.appendChild(button);

  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let ticking = false;

  const setVisible = (visible) => {
    button.classList.toggle("is-visible", visible);
    button.setAttribute("aria-hidden", String(!visible));
    button.tabIndex = visible ? 0 : -1;
  };

  const updateVisibility = () => {
    setVisible(window.scrollY > 300);
    ticking = false;
  };

  const requestUpdate = () => {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(updateVisibility);
  };

  button.addEventListener("click", () => {
    window.scrollTo({
      top: 0,
      behavior: prefersReducedMotion.matches ? "auto" : "smooth"
    });
  });

  window.addEventListener("scroll", requestUpdate, { passive: true });
  window.addEventListener("resize", requestUpdate);
  updateVisibility();
}

async function init() {
  const site = await loadJson("data/site.json?v=20260527-logo");
  const page = document.body.dataset.page;
  applyTheme(site);
  renderHeader(site, page);
  renderFooter(site);
  setupBackToTopButton();
  await renderers[page](document.querySelector("#app"), site);
}

init().catch((error) => {
  document.querySelector("#app").innerHTML = `<section class="section"><div class="notice">${error.message}</div></section>`;
  console.error(error);
});
