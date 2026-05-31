import { getParams, loadJson } from "./dataLoader.js";
import {
  escapeHtml,
  getSessionDisplayTitle,
  renderSessionDetailContent
} from "./sessionDisplay.js?v=20260531-session-comment-post-ui";
import { initSessionDetailApplicationComments } from "./sessionDetailApplicationComments.js?v=20260531-session-comment-post-ui";

const SESSIONS_URL = "data/sessions.json?v=20260531-session-comment-post-ui";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function parseIsoDate(value) {
  const text = String(value || "").trim();
  if (!ISO_DATE_PATTERN.test(text)) return null;
  const [year, month, day] = text.split("-").map(Number);
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return { year, month, day, time };
}

function formatRealDate(isoDate) {
  const parsed = parseIsoDate(isoDate);
  if (!parsed) return isoDate || "";
  const weekday = REAL_WEEKDAYS[new Date(parsed.time).getUTCDay()];
  return `${parsed.year}年${parsed.month}月${parsed.day}日(${weekday})`;
}

function isVisibleSession(session) {
  return session
    && session.visibility === "public"
    && session.status !== "draft"
    && String(session.id || "").trim();
}

function calendarHref(date) {
  return parseIsoDate(date) ? `calendar.html?date=${encodeURIComponent(date)}` : "calendar.html";
}

function renderShell(title, bodyHtml, options = {}) {
  const eyebrow = options.eyebrow || "Session";
  return `
    <header class="page-title">
      <div class="eyebrow">${escapeHtml(eyebrow)}</div>
      <h1>${escapeHtml(title)}</h1>
      <p class="lead">ヴェルガルドのセッション予定詳細です。</p>
    </header>
    <section class="section session-detail-section">
      ${bodyHtml}
    </section>
  `;
}

function renderBackLinks(date = "") {
  return `
    <div class="session-detail-actions">
      <a class="button primary" href="${escapeHtml(calendarHref(date))}">カレンダーへ戻る</a>
      <a class="button" href="index.html">TOPへ戻る</a>
    </div>
  `;
}

function renderNotFound(message) {
  return renderShell("セッション予定が見つかりません", `
    <article class="article-box session-detail-card">
      <div class="notice">
        <p>${escapeHtml(message)}</p>
      </div>
      ${renderBackLinks()}
    </article>
  `, { eyebrow: "Session Detail" });
}

function renderSessionPage(session) {
  const title = getSessionDisplayTitle(session);
  if (typeof document !== "undefined") {
    document.title = `${title}｜セッション予定詳細｜“灰壁と花霧の国”ヴェルガルド`;
  }

  return renderShell("セッション予定詳細", `
    <article class="article-box session-detail-card">
      ${renderSessionDetailContent(session, {
        mode: "page",
        headingId: "session-detail-title",
        eyebrow: "Session Detail",
        formatDate: formatRealDate
      })}
      ${renderBackLinks(session.date)}
    </article>
  `, { eyebrow: "Calendar" });
}

export async function renderSessionDetail(root) {
  const id = getParams().get("id")?.trim();
  if (!id) {
    root.innerHTML = renderNotFound("セッション予定IDが指定されていません。");
    return;
  }

  let data;
  try {
    data = await loadJson(SESSIONS_URL);
  } catch (error) {
    root.innerHTML = renderShell("セッション予定を読み込めません", `
      <article class="article-box session-detail-card">
        <div class="notice">
          <p>${escapeHtml(error.message || "セッション予定データを読み込めませんでした。")}</p>
        </div>
        ${renderBackLinks()}
      </article>
    `, { eyebrow: "Session Detail" });
    return;
  }

  const sessions = Array.isArray(data.sessions) ? data.sessions.filter(isVisibleSession) : [];
  const session = sessions.find((item) => String(item.id || "").trim() === id);
  if (!session) {
    root.innerHTML = renderNotFound("指定されたセッション予定が見つかりませんでした。");
    return;
  }

  root.innerHTML = renderSessionPage(session);
  initSessionDetailApplicationComments(root, { sessionId: session.id });
}
