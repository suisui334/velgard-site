import { loadJson } from "./dataLoader.js";

const REGULATION_DATA_PATH = "data/regulation.json?v=20260615-angel-layout-data";

const STRONG_PARAGRAPHS = new Set([
  "【ルートA・B共通】",
  "【ルートA】",
  "【ルートB】"
]);

const TOC_ITEMS = [
  { id: "schedule", label: "開催スケジュール" },
  { id: "level-caps", label: "レベルキャップ表" },
  { id: "term-explanations", label: "用語説明" },
  { id: "reward", label: "報酬・超過報酬" },
  { id: "compensation", label: "補填金" },
  { id: "adopted-rulebooks", label: "採用ルールブック・サプリメント" },
  { id: "common-rules", label: "共通ルール" },
  { id: "general-skills", label: "一般技能" },
  { id: "original-general-skills", label: "オリジナル一般技能" },
  { id: "rebuild", label: "リビルド" },
  { id: "calendar-days", label: "日数の数え方" }
];

const LEVEL_CAP_COLUMNS = [
  ["levelCap", "レベルキャップ"],
  ["fixedExperience", "固定経験点"],
  ["minGrowth", "下限成長"],
  ["minReward", "下限報酬"],
  ["minHonor", "下限名誉点"],
  ["maxGrowth", "上限成長"],
  ["maxReward", "上限報酬"],
  ["growthPerSession", "成長回数"],
  ["rankLimit", "冒険者ランク上限"],
  ["rewardAmount", "報酬金額"],
  ["swordShardGuide", "剣の欠片目安"]
];

function isPresent(value) {
  return value !== undefined
    && value !== null
    && !(Array.isArray(value) && value.length === 0)
    && String(value).trim() !== "";
}

function create(tagName, className, text) {
  const element = document.createElement(tagName);
  if (className) element.className = className;
  if (isPresent(text)) element.textContent = text;
  return element;
}

function appendParagraphs(parent, paragraphs) {
  (Array.isArray(paragraphs) ? paragraphs : [])
    .filter(isPresent)
    .forEach((paragraph) => {
      const text = String(paragraph);
      const paragraphElement = create("p");
      if (STRONG_PARAGRAPHS.has(text.trim())) {
        paragraphElement.append(create("strong", "", text));
      } else {
        paragraphElement.textContent = text;
      }
      parent.append(paragraphElement);
    });
}

function appendList(parent, items, { ordered = false, marker = "" } = {}) {
  const list = create(ordered ? "ol" : "ul", `regulation-list${marker === "roman" ? " regulation-list-roman" : ""}`);
  (Array.isArray(items) ? items : [])
    .filter(isPresent)
    .forEach((item) => list.append(create("li", "", item)));
  if (list.children.length) parent.append(list);
}

function renderTable(rows, columns, className = "regulation-table") {
  const wrap = create("div", "regulation-table-wrap");
  const table = create("table", className);
  const thead = create("thead");
  const headerRow = create("tr");

  columns.forEach(([, label]) => {
    headerRow.append(create("th", "", label));
  });
  thead.append(headerRow);

  const tbody = create("tbody");
  rows.forEach((row) => {
    const tableRow = create("tr");
    columns.forEach(([key]) => {
      tableRow.append(create("td", "", isPresent(row[key]) ? row[key] : ""));
    });
    tbody.append(tableRow);
  });

  table.append(thead, tbody);
  wrap.append(table);
  return wrap;
}

function createSection(id, title, eyebrow) {
  const section = create("section", "section regulation-section");
  if (id) section.id = id;
  const article = create("article", "article-box");
  if (eyebrow) article.append(create("div", "eyebrow", eyebrow));
  article.append(create("h2", "", title));
  section.append(article);
  return { section, article };
}

function renderPreparing(root, regulation) {
  const page = create("div", "regulation-page");
  const header = create("header", "page-title");
  header.append(create("div", "eyebrow", regulation.pageLabel || "REGULATION"));
  header.append(create("h1", "", regulation.pageTitle || regulation.title || "レギュレーション"));
  if (isPresent(regulation.lead)) header.append(create("p", "lead", regulation.lead));
  page.append(header);

  const { section, article } = createSection("", regulation.preparingTitle || "現在準備中です", "Preparing");
  article.append(create("p", "", regulation.preparingMessage || "レギュレーションは準備中です。"));
  page.append(section);

  if (Array.isArray(regulation.plannedSections) && regulation.plannedSections.length) {
    const planned = create("section", "section");
    const head = create("div", "section-head");
    head.append(create("h2", "", "今後掲載予定"));
    const grid = create("div", "grid two");
    regulation.plannedSections.forEach((item) => {
      const card = create("article", "card");
      card.append(create("span", "tag status", "準備中"));
      card.append(create("h3", "", item));
      grid.append(card);
    });
    planned.append(head, grid);
    page.append(planned);
  }

  root.append(page);
}

function renderHero(regulation) {
  const header = create("header", "page-title regulation-page-title");
  header.append(create("div", "eyebrow", regulation.pageLabel || "REGULATION"));
  header.append(create("h1", "", regulation.title || regulation.pageTitle || "レギュレーション"));
  if (isPresent(regulation.subtitle)) header.append(create("p", "regulation-subtitle", regulation.subtitle));
  if (isPresent(regulation.lead)) header.append(create("p", "lead", regulation.lead));
  return header;
}

function renderToc() {
  const nav = create("aside", "toc article-box regulation-toc");
  nav.setAttribute("aria-label", "レギュレーション目次");
  nav.append(create("h2", "", "目次"));
  const list = create("ol", "regulation-toc-list");
  TOC_ITEMS.forEach((item) => {
    const listItem = create("li");
    const link = create("a", "", item.label);
    link.href = `#${item.id}`;
    listItem.append(link);
    list.append(listItem);
  });
  nav.append(list);
  return nav;
}

function renderSchedule(regulation) {
  const { section, article } = createSection("schedule", "開催スケジュール");
  const rows = Array.isArray(regulation.schedule) ? regulation.schedule : [];
  article.append(renderTable(rows, [["date", "日付"], ["label", "内容"]], "regulation-table regulation-schedule-table"));
  return section;
}

function renderLevelCaps(regulation) {
  const { section, article } = createSection("level-caps", "レベルキャップ表");
  const rows = Array.isArray(regulation.levelCaps) ? regulation.levelCaps : [];
  article.append(renderTable(rows, LEVEL_CAP_COLUMNS));
  return section;
}

function renderTermExplanations(regulation) {
  const { section, article } = createSection("term-explanations", "用語説明");
  const grid = create("div", "regulation-term-grid");
  (Array.isArray(regulation.termExplanations) ? regulation.termExplanations : []).forEach((item) => {
    const card = create("article", "regulation-term-card");
    card.append(create("h3", "", item.term));
    appendParagraphs(card, item.paragraphs);
    if (isPresent(item.exampleTitle) || (Array.isArray(item.exampleParagraphs) && item.exampleParagraphs.length)) {
      const callout = create("div", "regulation-callout");
      if (isPresent(item.exampleTitle)) callout.append(create("h4", "", item.exampleTitle));
      appendParagraphs(callout, item.exampleParagraphs);
      card.append(callout);
    }
    grid.append(card);
  });
  article.append(grid);
  return section;
}

function renderAdoptedRulebooks(regulation) {
  const { section, article } = createSection("adopted-rulebooks", "採用ルールブック・サプリメント");
  appendList(article, regulation.adoptedRulebooks, { ordered: false });
  article.querySelector(".regulation-list")?.classList.add("regulation-book-list");
  return section;
}

function renderBlock(block) {
  const fragment = document.createDocumentFragment();
  if (!block || typeof block !== "object") return fragment;

  if (block.type === "paragraphs") {
    const group = create("div", "regulation-block");
    if (isPresent(block.title)) group.append(create("h3", "", block.title));
    appendParagraphs(group, block.paragraphs);
    fragment.append(group);
  }

  if (block.type === "callout") {
    const callout = create("div", "regulation-callout");
    if (isPresent(block.title)) callout.append(create("h3", "", block.title));
    appendParagraphs(callout, block.paragraphs);
    fragment.append(callout);
  }

  if (block.type === "list" || block.type === "ordered") {
    const group = create("div", "regulation-block");
    if (isPresent(block.title)) group.append(create("h3", "", block.title));
    appendList(group, block.items, { ordered: block.type === "ordered", marker: block.marker });
    fragment.append(group);
  }

  if (block.type === "subsections") {
    const group = create("div", "regulation-subsections");
    (Array.isArray(block.items) ? block.items : []).forEach((item) => {
      const sub = create("article", "regulation-subsection");
      if (isPresent(item.title)) sub.append(create("h3", "", item.title));
      appendParagraphs(sub, item.paragraphs);
      appendList(sub, item.items, { ordered: false });
      (Array.isArray(item.sections) ? item.sections : []).forEach((section) => {
        const detail = create("div", "regulation-subsection-detail");
        if (isPresent(section.title)) detail.append(create("h4", "", section.title));
        appendParagraphs(detail, section.paragraphs);
        appendList(detail, section.items, { ordered: Boolean(section.ordered), marker: section.marker });
        if (detail.children.length) sub.append(detail);
      });
      group.append(sub);
    });
    fragment.append(group);
  }

  if (block.type === "details") {
    const details = create("details", "regulation-details");
    details.append(create("summary", "", block.title || "詳細"));
    appendParagraphs(details, block.paragraphs);
    appendList(details, block.items, { ordered: Boolean(block.ordered), marker: block.marker });
    fragment.append(details);
  }

  if (block.type === "table" && Array.isArray(block.rows) && Array.isArray(block.columns)) {
    const group = create("div", "regulation-block");
    if (isPresent(block.title)) group.append(create("h3", "", block.title));
    group.append(renderTable(block.rows, block.columns.map((column) => [column.key, column.label])));
    fragment.append(group);
  }

  return fragment;
}

function renderDataSection(sectionData) {
  if (!sectionData) return null;
  const { section, article } = createSection(sectionData.id, sectionData.title);
  (Array.isArray(sectionData.blocks) ? sectionData.blocks : []).forEach((block) => {
    article.append(renderBlock(block));
  });
  return section;
}

export async function renderRegulation(root) {
  const regulation = await loadJson(REGULATION_DATA_PATH);
  root.replaceChildren();

  if (regulation.status !== "public") {
    renderPreparing(root, regulation);
    return;
  }

  const page = create("div", "regulation-page");
  const layout = create("div", "article-layout regulation-layout");
  const main = create("article", "article regulation-main");
  const sections = new Map((Array.isArray(regulation.sections) ? regulation.sections : []).map((section) => [section.id, section]));

  main.append(
    renderSchedule(regulation),
    renderLevelCaps(regulation),
    renderTermExplanations(regulation)
  );

  ["reward", "compensation"].forEach((id) => {
    const rendered = renderDataSection(sections.get(id));
    if (rendered) main.append(rendered);
  });

  main.append(renderAdoptedRulebooks(regulation));

  ["common-rules", "general-skills", "original-general-skills", "rebuild", "calendar-days"].forEach((id) => {
    const rendered = renderDataSection(sections.get(id));
    if (rendered) main.append(rendered);
  });

  layout.append(main, renderToc());
  page.append(renderHero(regulation), layout);
  root.append(page);
}
