import { getParams } from "./dataLoader.js";
import { loadMergedSessions } from "./sessionData.js?v=20260605-gm-count-fix";
import {
  escapeHtml,
  getSessionDisplayTitle,
  renderSessionDetailContent
} from "./sessionDisplay.js?v=20260603-management-qa";
import { initSessionDetailApplicationComments } from "./sessionDetailApplicationComments.js?v=20260607-pl-application-template";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js?v=20260601-session-post";

const SESSIONS_URL = "data/sessions.json?v=20260601-session-post";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DETAIL_EXCLUDED_STATUSES = new Set(["draft", "canceled", "cancelled"]);
const DELETE_CONFIRM_MESSAGE = "この依頼書を完全に削除します。\n削除すると、依頼書本体に加えて参加申請・コメントも削除されます。\n中止として残したい場合は、削除せず募集状態を「中止」にしてください。\nDiscord通知・投稿削除はまだ未実装です。\n本当に削除しますか？";
const DELETE_SUCCESS_MESSAGE = "この依頼書を削除しました。";
const DELETE_ERROR_MESSAGE = "依頼書の削除に失敗しました。";
const DELETE_ERROR_MESSAGES = {
  login_required: "ログインが必要です。",
  not_allowed: "この依頼書を削除する権限がありません。",
  session_not_found: "対象の依頼書が見つかりません。",
  session_id_required: "対象の依頼書が見つかりません。"
};

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
  const status = String(session?.status || "").trim();
  return session
    && session.visibility === "public"
    && !DETAIL_EXCLUDED_STATUSES.has(status)
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

function buildDeletePayload(session) {
  const sessionId = String(session?.id ?? "").trim();
  if (!sessionId) throw new Error("session_not_found");
  return { p_session_id: sessionId };
}

function getDeleteErrorMessage(error) {
  const text = [
    error?.message,
    error?.details,
    error?.hint,
    error?.code
  ].map((value) => String(value || "")).join(" ");
  const key = Object.keys(DELETE_ERROR_MESSAGES).find((name) => text.includes(name));
  return key ? DELETE_ERROR_MESSAGES[key] : DELETE_ERROR_MESSAGE;
}

function getAccessDeniedManageMessage(access) {
  const message = String(access?.message || "");
  return message.includes("ログイン") ? "ログインが必要です。" : "この依頼書を操作する権限がありません。";
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

async function applyDeleteSessionPost(client, elements, session) {
  if (!elements.deleteButton || elements.deleteButton.disabled) return;
  if (!window.confirm(DELETE_CONFIRM_MESSAGE)) return;

  elements.deleteButton.disabled = true;
  if (elements.editButton) elements.editButton.disabled = true;
  setManageState(elements.state, "削除しています。");

  try {
    const payload = buildDeletePayload(session);
    const { error } = await client.rpc("delete_session_post", payload);
    if (error) throw error;

    setManageState(elements.state, DELETE_SUCCESS_MESSAGE, "is-ok");
    elements.deleteButton.title = "この依頼書は削除済みです。";
    window.setTimeout(() => {
      window.location.href = calendarHref(session?.date);
    }, 900);
  } catch (error) {
    setManageState(elements.state, getDeleteErrorMessage(error), "is-error");
    elements.deleteButton.disabled = false;
    if (elements.editButton) elements.editButton.disabled = false;
  }
}

async function initSessionDetailManageActionsWithDelete(root, session) {
  const elements = getSessionManageElements(root);
  if (!elements.panel) return;

  if (elements.deleteButton) {
    elements.deleteButton.disabled = true;
    elements.deleteButton.title = "権限確認後に有効化します。";
  }

  if (!isSupabaseSession(session)) {
    if (elements.editButton) elements.editButton.disabled = true;
    if (elements.deleteButton) {
      elements.deleteButton.disabled = true;
      elements.deleteButton.title = "この予定は静的データ由来のため、この画面では削除できません。";
    }
    setManageState(elements.state, "この予定は静的データ由来のため、この画面では編集できません。この予定は静的データ由来のため、この画面では削除できません。");
    return;
  }

  try {
    const client = await createSupabaseBrowserClient();
    if (!client) {
      if (elements.editButton) elements.editButton.disabled = true;
      if (elements.deleteButton) elements.deleteButton.disabled = true;
      setManageState(elements.state, "接続設定が未構成のため、編集・削除できません。", "is-error");
      return;
    }

    const access = await hasSessionEditAccess(client, session.id);
    if (access.allowed && elements.editButton) {
      elements.editButton.disabled = false;
      elements.editButton.addEventListener("click", () => {
        window.location.href = `session-post.html?id=${encodeURIComponent(session.id)}#my-sessions`;
      });
      if (elements.deleteButton) {
        elements.deleteButton.disabled = false;
        elements.deleteButton.title = "この依頼書を完全に削除します。";
        elements.deleteButton.addEventListener("click", () => {
          applyDeleteSessionPost(client, elements, session);
        });
      }
      setManageState(elements.state, access.message, "is-ok");
      return;
    }

    if (elements.editButton) elements.editButton.disabled = true;
    if (elements.deleteButton) {
      elements.deleteButton.disabled = true;
      elements.deleteButton.title = "この依頼書を操作する権限がありません。";
    }
    setManageState(elements.state, getAccessDeniedManageMessage(access));
  } catch {
    if (elements.editButton) elements.editButton.disabled = true;
    if (elements.deleteButton) {
      elements.deleteButton.disabled = true;
      elements.deleteButton.title = "権限確認に失敗しました。";
    }
    setManageState(elements.state, "編集権限を確認できませんでした。", "is-error");
  }
}

async function initSessionDetailManageActions(root, session) {
  return initSessionDetailManageActionsWithDelete(root, session);
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
  initSessionDetailApplicationComments(root, {
    sessionId: session.id,
    gmUserId: session.gmUserId,
    sessionTitle: getSessionDisplayTitle(session)
  });
}
