import { byId, getParams, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

function paragraphs(value) {
  const items = Array.isArray(value) ? value : [value].filter(Boolean);
  return items.map((text) => `<p>${text}</p>`).join("");
}

export async function renderCampaignDetail(root, site) {
  const params = getParams();
  const id = params.get("id");
  const [campaigns, episodes, spots, characters] = await Promise.all([
    loadJson("data/campaigns.json"),
    loadJson("data/episodes.json"),
    loadJson("data/spots.json"),
    loadJson("data/characters.json")
  ]);
  const campaign = byId(campaigns).get(id);
  if (!isVisible(campaign, true)) {
    root.innerHTML = `<section class="section"><div class="notice">キャンペーンが見つかりません。</div></section>`;
    return;
  }
  const campaignEpisodes = episodes
    .filter((item) => item.campaignId === campaign.id && isVisible(item, true))
    .sort((a, b) => (a.episodeIndex ?? 0) - (b.episodeIndex ?? 0));
  const spotMap = byId(spots);
  const charMap = byId(characters.filter((item) => isVisible(item) && item.official === true));
  const relatedSpotNames = (campaign.relatedSpots || []).map((spotId) => spotMap.get(spotId)?.name).filter(Boolean);
  const relatedCharacterNames = (campaign.relatedCharacters || []).map((characterId) => charMap.get(characterId)?.name).filter(Boolean);

  root.innerHTML = `
    <section class="detail-hero">
      <div class="page-visual"><img src="${imageOrPlaceholder(campaign.keyVisual || campaign.image, site, "keyvisual")}" alt="${campaign.title}"></div>
      <div class="hero-copy">
        <div class="eyebrow">Campaign Trailer</div>
        <h1>${campaign.title}</h1>
        ${campaign.subtitle ? `<p>${campaign.subtitle}</p>` : ""}
        <p class="lead">${campaign.catchcopy}</p>
        ${campaign.status === "preparing" ? `<span class="tag status">準備中</span>` : ""}
      </div>
    </section>
    <section class="section">
      <div class="grid two">
        <article class="article-box"><div class="eyebrow">TRAILER</div><p>${campaign.trailer}</p></article>
        <article class="article-box"><div class="eyebrow">INTRODUCTION</div>${paragraphs(campaign.introduction)}</article>
      </div>
    </section>
    <section class="section">
      <div class="section-head"><h2>STORY</h2><a class="button" href="campaigns.html">キャンペーン一覧へ戻る</a></div>
      <div class="grid">
        ${campaignEpisodes.map((episode) => `
          <article class="card">
            <div class="card-visual"><img src="${imageOrPlaceholder(episode.image, site, "gallery")}" alt="${episode.episodeNumber} ${episode.title}"></div>
            <div class="card-meta"><span class="tag">${episode.episodeNumber}</span>${episode.status === "preparing" ? `<span class="tag status">準備中</span>` : ""}</div>
            <h3>${episode.title}</h3>
            <p class="lead">${episode.catchcopy}</p>
            ${paragraphs(episode.summary)}
            <div><a class="button" href="episode-detail.html?campaign=${campaign.id}&episode=${episode.id}">読む</a></div>
          </article>
        `).join("")}
      </div>
    </section>
    <section class="section">
      <div class="grid two">
        <article class="card"><h3>関連スポット</h3><p>${textList(relatedSpotNames)}</p></article>
        <article class="card"><h3>関連NPC</h3><p>${textList(relatedCharacterNames)}</p></article>
      </div>
    </section>
  `;
}
