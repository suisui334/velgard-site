import { byId, getParams, imageOrPlaceholder, isVisible, loadJson, textList } from "./dataLoader.js";

function paragraphs(value) {
  const items = Array.isArray(value) ? value : [value].filter(Boolean);
  return items.map((text) => `<p>${text}</p>`).join("");
}

export async function renderEpisodeDetail(root, site) {
  const params = getParams();
  let campaignId = params.get("campaign");
  const episodeId = params.get("episode") || params.get("id");
  const [campaigns, episodes, spots, characters] = await Promise.all([
    loadJson("data/campaigns.json"),
    loadJson("data/episodes.json"),
    loadJson("data/spots.json"),
    loadJson("data/characters.json")
  ]);
  if (!campaignId && episodeId) {
    campaignId = episodes.find((item) => item.id === episodeId)?.campaignId || "";
  }
  const campaign = byId(campaigns).get(campaignId);
  const campaignEpisodes = episodes
    .filter((item) => item.campaignId === campaignId && isVisible(item, true))
    .sort((a, b) => (a.episodeIndex ?? 0) - (b.episodeIndex ?? 0));
  const episode = campaignEpisodes.find((item) => item.id === episodeId);
  if (!campaign || !episode) {
    root.innerHTML = `<section class="section"><div class="notice">エピソードが見つかりません。</div></section>`;
    return;
  }
  const spotMap = byId(spots);
  const charMap = byId(characters.filter((item) => isVisible(item) && item.official === true));
  const relatedSpotNames = (episode.relatedSpots || []).map((spotId) => spotMap.get(spotId)?.name).filter(Boolean);
  const relatedCharacterNames = (episode.relatedCharacters || []).map((characterId) => charMap.get(characterId)?.name).filter(Boolean);
  const idx = campaignEpisodes.findIndex((item) => item.id === episode.id);
  const prev = campaignEpisodes[idx - 1];
  const next = campaignEpisodes[idx + 1];

  root.innerHTML = `
    <section class="detail-hero">
      <div class="page-visual"><img src="${imageOrPlaceholder(episode.image, site, "gallery")}" alt="${episode.episodeNumber} ${episode.title}"></div>
      <div class="hero-copy">
        <div class="eyebrow">${campaign.title}</div>
        <h1>${episode.episodeNumber} ${episode.title}</h1>
        <p class="lead">${episode.catchcopy}</p>
        ${episode.status === "preparing" ? `<span class="tag status">準備中</span>` : ""}
      </div>
    </section>
    <section class="section">
      <article class="article-box"><h2>公開用あらすじ</h2>${paragraphs(episode.summary)}</article>
    </section>
    <section class="section">
      <div class="grid two">
        <article class="card"><h3>関連スポット</h3><p>${textList(relatedSpotNames)}</p></article>
        <article class="card"><h3>関連NPC</h3><p>${textList(relatedCharacterNames)}</p></article>
      </div>
      <div class="actions" style="margin-top: 18px;">
        ${prev ? `<a class="button" href="episode-detail.html?campaign=${campaignId}&episode=${prev.id}">前の話</a>` : ""}
        ${next ? `<a class="button" href="episode-detail.html?campaign=${campaignId}&episode=${next.id}">次の話</a>` : ""}
        <a class="button primary" href="campaign-detail.html?id=${campaignId}">キャンペーン詳細へ戻る</a>
      </div>
    </section>
  `;
}
