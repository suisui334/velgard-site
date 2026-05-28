import { byId, imageFallbackAttr, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

function setupCharacterImageModal(root, characterMap, site) {
  const modal = root.querySelector("#character-image-modal");
  const modalImage = root.querySelector("#character-image-modal-image");
  const modalName = root.querySelector("#character-image-modal-name");
  const modalRole = root.querySelector("#character-image-modal-role");
  const modalProfile = root.querySelector("#character-image-modal-profile");
  const closeButton = root.querySelector(".character-image-modal-close");
  if (!modal || !modalImage || !modalName || !modalRole || !modalProfile || !closeButton) return;
  let lastFocused = null;

  const closeModal = () => {
    modal.hidden = true;
    document.body.classList.remove("is-modal-open");
    if (lastFocused) lastFocused.focus();
  };

  const openModal = (id, trigger) => {
    const item = characterMap.get(id);
    if (!item) return;
    const role = item.role || item.title || "";
    const profile = [item.species, item.ageLabel ? `年齢：${item.ageLabel}` : ""].filter(Boolean).join(" / ");
    lastFocused = trigger;
    modalImage.onerror = () => {
      modalImage.onerror = null;
      modalImage.src = imageOrPlaceholder("", site, "character");
    };
    modalImage.src = imageOrPlaceholder(item.image || item.thumbnail, site, "character");
    modalImage.alt = item.name || "";
    modalName.textContent = item.name || "";
    modalRole.textContent = role;
    modalProfile.textContent = profile;
    modal.hidden = false;
    document.body.classList.add("is-modal-open");
    closeButton.focus();
  };

  root.addEventListener("click", (event) => {
    const trigger = event.target.closest?.(".character-image-clickable");
    if (trigger) openModal(trigger.dataset.characterId, trigger);
    if (event.target.hasAttribute?.("data-character-image-close")) closeModal();
  });

  root.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const trigger = event.target.closest?.(".character-image-clickable");
    if (!trigger) return;
    event.preventDefault();
    openModal(trigger.dataset.characterId, trigger);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.hidden) closeModal();
  });
}

export async function renderCharacters(root, site) {
  const [characters, spots] = await Promise.all([loadJson("data/characters.json?v=20260526-age"), loadJson("data/spots.json")]);
  const visible = characters.filter((item) => isVisible(item) && item.official === true);
  const characterMap = byId(visible);
  const spotMap = byId(spots);
  const areaLabel = (item) => item.areaName || item.region || "未設定";
  const filterLabel = (item) => spotMap.get(item.areaId)?.name || areaLabel(item);
  const speciesLabel = (item) => item.species || item.race || "未設定";
  const ageLabel = (item) => item.ageLabel || "";
  const titleLabel = (item) => item.title || item.alias || "";
  const organizationLabel = (item) => item.organization || item.affiliation || "未設定";
  const relatedSpotIds = (item) => item.relatedSpots || item.relatedSpotIds || [];
  const regions = ["すべて", ...new Set(visible.map((item) => filterLabel(item)).filter(Boolean))];
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Character</div>
      <h1>CHARACTER</h1>
      <p class="lead">PL向けに公開されている公式NPCです。地域で絞り込めます。</p>
    </header>
    <section class="section">
      <div class="filter-bar">
        <label>地域 <select id="character-filter">${regions.map((region) => `<option value="${region}">${region}</option>`).join("")}</select></label>
      </div>
      <div id="character-grid" class="grid"></div>
    </section>
    <div class="character-image-modal" id="character-image-modal" hidden>
      <div class="character-image-modal-backdrop" data-character-image-close></div>
      <article class="character-image-modal-content" role="dialog" aria-modal="true" aria-labelledby="character-image-modal-name">
        <button class="character-image-modal-close button" type="button" data-character-image-close>閉じる</button>
        <div class="character-image-modal-image">
          <img id="character-image-modal-image" src="${imageOrPlaceholder("", site, "character")}" alt="">
        </div>
        <div class="character-image-modal-text">
          <h2 id="character-image-modal-name"></h2>
          <p id="character-image-modal-role"></p>
          <p id="character-image-modal-profile"></p>
        </div>
      </article>
    </div>
  `;
  const grid = root.querySelector("#character-grid");
  const select = root.querySelector("#character-filter");
  setupCharacterImageModal(root, characterMap, site);
  let highlightTimer = null;
  const linkedCharacterId = () => {
    const hash = decodeURIComponent(window.location.hash || "");
    return hash.startsWith("#character-") ? hash.slice("#character-".length) : "";
  };
  const scrollToLinkedCharacter = () => {
    const id = linkedCharacterId();
    if (!id) return;
    const target = document.getElementById(`character-${id}`);
    if (!target) {
      if (select.value !== "すべて") {
        select.value = "すべて";
        draw(true);
      }
      return;
    }
    if (highlightTimer) window.clearTimeout(highlightTimer);
    target.classList.add("character-card-highlight");
    target.scrollIntoView({
      block: "start",
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
    });
    highlightTimer = window.setTimeout(() => {
      target.classList.remove("character-card-highlight");
    }, 2200);
  };
  const draw = (shouldScrollToHash = false) => {
    const selected = select.value;
    const items = visible.filter((item) => selected === "すべて" || filterLabel(item) === selected || areaLabel(item) === selected || item.areaId === selected);
    grid.innerHTML = items.length ? items.map((item) => `
      <article class="card character-card" id="character-${item.id}" data-character-card-id="${item.id}">
        <div class="card-visual character-visual character-image-clickable" role="button" tabindex="0" data-character-id="${item.id}" aria-label="${item.name}の画像を拡大表示"><img src="${imageOrPlaceholder(item.image || item.thumbnail, site, "character")}" alt="${item.name}" ${imageFallbackAttr(site, "character")}></div>
        ${titleLabel(item) ? `<span class="tag">${titleLabel(item)}</span>` : ""}
        <h2>${item.name}</h2>
        <p>${speciesLabel(item)} / ${item.gender || "未設定"}</p>
        ${ageLabel(item) ? `<p class="character-age"><strong>年齢：</strong>${ageLabel(item)}</p>` : ""}
        <p><strong>地域:</strong> ${areaLabel(item)}</p>
        <p><strong>所属:</strong> ${organizationLabel(item)}</p>
        <p><strong>役割:</strong> ${item.role || "未設定"}</p>
        ${item.summary ? `<p>${item.summary}</p>` : ""}
        ${item.quote ? `<blockquote class="character-quote">「${item.quote}」</blockquote>` : ""}
        <p><strong>関連スポット:</strong> ${textList(relatedSpotIds(item).map((id) => spotMap.get(id)?.name).filter(Boolean))}</p>
      </article>
    `).join("") : `<div class="empty">公開中の公式NPCはまだ登録されていません。</div>`;
    if (shouldScrollToHash) window.setTimeout(scrollToLinkedCharacter, 0);
  };
  select.addEventListener("change", () => draw(false));
  window.addEventListener("hashchange", scrollToLinkedCharacter);
  draw(true);
}
