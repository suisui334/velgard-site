import { loadJson } from "./dataLoader.js";

export async function renderWorld(root) {
  const world = await loadJson("data/world.json");
  const renderParagraphs = (paragraphs = []) => paragraphs.map((paragraph) => `<p>${paragraph}</p>`).join("");
  const titleText = (item) => `${item.number ? `${item.number}. ` : ""}${item.title}`;
  const tocItems = world.sections.flatMap((section) => [
    `<a class="toc-link" href="#${section.id}">${titleText(section)}</a>`,
    ...((section.subsections || []).map((subsection) => `<a class="toc-link toc-sub" href="#${subsection.id}">${titleText(subsection)}</a>`))
  ]).join("");
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">${world.pageLabel || "World Guide"}</div>
      <h1>${world.pageTitle || world.title || "WORLD"}</h1>
      ${world.lead ? `<p class="lead">${world.lead}</p>` : ""}
    </header>
    <div class="article-layout">
      <article class="article">
        ${world.sections.map((section) => `
          <section id="${section.id}" class="article-box">
            <h2>${titleText(section)}</h2>
            ${section.lead ? `<p class="lead">${section.lead}</p>` : ""}
            ${renderParagraphs(section.paragraphs || section.body)}
            ${(section.subsections || []).map((subsection) => `
              <section id="${subsection.id}" class="subsection">
                <h3>${titleText(subsection)}</h3>
                ${renderParagraphs(subsection.paragraphs)}
              </section>
            `).join("")}
          </section>
        `).join("")}
      </article>
      <aside class="toc article-box" aria-label="ページ内目次">
        ${tocItems}
      </aside>
    </div>
  `;
  syncWorldToc(root);
}

function syncWorldToc(root) {
  const toc = root.querySelector(".toc");
  const targets = [...root.querySelectorAll(".article-box[id], .subsection[id]")];
  const links = new Map([...root.querySelectorAll(".toc-link[href^='#']")].map((link) => [decodeURIComponent(link.hash.slice(1)), link]));

  if (!toc || !targets.length || !links.size) return;

  toc.classList.add("world-toc");

  let activeId = "";
  let ticking = false;

  const setActive = (id) => {
    if (!id || id === activeId) return;
    const activeLink = links.get(id);
    if (!activeLink) return;

    activeId = id;
    links.forEach((link) => {
      const isActive = link === activeLink;
      link.classList.toggle("toc-link-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "true");
      } else {
        link.removeAttribute("aria-current");
      }
    });

    keepActiveLinkInToc(toc, activeLink);
  };

  const updateActive = () => {
    ticking = false;
    const offset = 120;
    let current = targets[0].id;

    targets.forEach((target) => {
      if (target.getBoundingClientRect().top <= offset) {
        current = target.id;
      }
    });

    setActive(current);
  };

  const requestUpdate = () => {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(updateActive);
  };

  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(requestUpdate, {
      rootMargin: "-18% 0px -68% 0px",
      threshold: [0, 0.1, 0.35]
    });
    targets.forEach((target) => observer.observe(target));
  }

  window.addEventListener("scroll", requestUpdate, { passive: true });
  window.addEventListener("resize", requestUpdate);
  requestUpdate();
}

function keepActiveLinkInToc(toc, activeLink) {
  const style = window.getComputedStyle(toc);
  const canScroll = /(auto|scroll)/.test(style.overflowY) && toc.scrollHeight > toc.clientHeight + 1;
  if (!canScroll) return;

  const padding = 12;
  const tocRect = toc.getBoundingClientRect();
  const linkRect = activeLink.getBoundingClientRect();

  if (linkRect.top < tocRect.top + padding) {
    toc.scrollTop -= (tocRect.top + padding) - linkRect.top;
    return;
  }

  if (linkRect.bottom > tocRect.bottom - padding) {
    toc.scrollTop += linkRect.bottom - (tocRect.bottom - padding);
  }
}
