import { getParams } from "./dataLoader.js";
import { loadMergedSessions } from "./sessionData.js?v=20260602-session-edit-route";
import {
  escapeHtml,
  getSessionDisplayTitle,
  renderSessionDetailContent
} from "./sessionDisplay.js?v=20260602-session-edit-route";
import { initSessionDetailApplicationComments } from "./sessionDetailApplicationComments.js?v=20260601-gm-contact-copy";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js?v=20260601-session-post";

const SESSIONS_URL = "data/sessions.json?v=20260601-session-post";
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
        formatDate: formatRealDate,
        includeManageActions: true
      })}
      ${renderBackLinks(session.date)}
    </article>
  `, { eyebrow: "Calendar" });
}

function isSupabaseSession(session) {
  return session?.source === "supabase";
}

function setManageState(target, message, modifier = "") {
  if (!target) return;
  target.textContent = message;
  target.className = `session-detail-manage-note${modifier ? ` ${modifier}` : ""}`;
}

function getSessionManageElements(root) {
  const panel = root.querySelector("[data-session-detail-manage-panel]");
  return {
    panel,
    editButton: panel?.querySelector("[data-session-detail-edit]") || null,
    deleteButton: panel?.querySelector("[data-session-detail-delete]") || null,
    state: panel?.querySelector("[data-session-detail-manage-state]") || null
  };
}

async function hasSessionEditAccess(client, sessionId) {
  const targetSessionId = String(sessionId || "").trim();
  if (!targetSessionId) {
    return { allowed: false, message: "編集対象の予定を確認できませんでした。" };
  }

  const { data, error } = await client.auth.getSession();
  if (error) {
    return { allowed: false, message: "ログイン状態を確認できませんでした。" };
  }
  if (!data?.session?.user?.id) {
    return { allowed: false, message: "編集にはログインが必要です。" };
  }

  const [adminResult, gmResult] = await Promise.allSettled([
    client.rpc("is_admin"),
    client.rpc("is_session_gm", { target_session_id: targetSessionId })
  ]);
  const isAdmin = adminResult.status === "fulfilled" && !adminResult.value.error && adminResult.value.data === true;
  const isSessionGm = gmResult.status === "fulfilled" && !gmResult.value.error && gmResult.value.data === true;
  if (isAdmin || isSessionGm) {
    return { allowed: true, message: "この依頼書を編集できます。" };
  }

  return { allowed: false, message: "この予定は編集できません。" };
}

async function initSessionDetailManageActions(root, session) {
  const elements = getSessionManageElements(root);
  if (!elements.panel) return;

  if (elements.deleteButton) {
    elements.deleteButton.disabled = true;
    elements.deleteButton.title = "削除機能は次工程で実装予定です";
  }

  if (!isSupabaseSession(session)) {
    if (elements.editButton) elements.editButton.disabled = true;
    setManageState(elements.state, "この予定は静的データ由来のため、この画面では編集できません。");
    return;
  }

  try {
    const client = await createSupabaseBrowserClient();
    if (!client) {
      if (elements.editButton) elements.editButton.disabled = true;
      setManageState(elements.state, "接続設定が未構成のため、編集できません。", "is-error");
      return;
    }

    const access = await hasSessionEditAccess(client, session.id);
    if (access.allowed && elements.editButton) {
      elements.editButton.disabled = false;
      elements.editButton.addEventListener("click", () => {
        window.location.href = `session-post.html?id=${encodeURIComponent(session.id)}#my-sessions`;
      });
      setManageState(elements.state, access.message, "is-ok");
      return;
    }
    if (elements.editButton) elements.editButton.disabled = true;
    setManageState(elements.state, access.message);
  } catch {
    if (elements.editButton) elements.editButton.disabled = true;
    setManageState(elements.state, "編集権限を確認できませんでした。", "is-error");
  }
}

export async function renderSessionDetail(root) {
  const id = getParams().get("id")?.trim();
  if (!id) {
    root.innerHTML = renderNotFound("セッション予定IDが指定されていません。");
    return;
  }

  let data;
  try {
    data = await loadMergedSessions(SESSIONS_URL);
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
  initSessionDetailManageActions(root, session);
  initSessionDetailApplicationComments(root, { sessionId: session.id });
}
