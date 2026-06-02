import { getParams } from "./dataLoader.js";
import { loadMergedSessions } from "./sessionData.js?v=20260602-session-edit-route";
import {
  escapeHtml,
  getSessionDisplayTitle,
  getSessionStatusLabel,
  getSessionVisibilityLabel,
  renderSessionDetailContent
} from "./sessionDisplay.js?v=20260603-delete-equivalent";
import { initSessionDetailApplicationComments } from "./sessionDetailApplicationComments.js?v=20260601-gm-contact-copy";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js?v=20260601-session-post";

const SESSIONS_URL = "data/sessions.json?v=20260601-session-post";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DELETE_CONFIRM_MESSAGE = "この依頼書を非公開・中止扱いにします。\n物理削除は行いません。\nよろしいですか？";
const DELETE_SUCCESS_MESSAGE = "この依頼書を非公開・中止扱いにしました。";
const DELETE_ERROR_MESSAGE = "削除相当操作に失敗しました。";
const DELETE_ERROR_MESSAGES = {
  login_required: "ログインが必要です。",
  not_allowed: "この依頼書を操作する権限がありません。",
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

function normalizeRpcTime(value) {
  const text = String(value ?? "").trim();
  const match = text.match(/^(\d{2}:\d{2})/);
  return match ? match[1] : "";
}

function normalizeRpcDateTime(value) {
  const text = String(value ?? "").trim();
  const match = text.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
  return match ? `${match[1]} ${match[2]}` : "";
}

function normalizeNullableInteger(value) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const number = Number(text);
  return Number.isInteger(number) ? number : null;
}

function normalizeNullableDateTime(value) {
  return normalizeRpcDateTime(value) || null;
}

function buildDeleteEquivalentPayload(session) {
  const sessionId = String(session?.id ?? "").trim();
  if (!sessionId) throw new Error("session_not_found");

  const date = String(session?.date ?? "").trim();
  const startTime = normalizeRpcTime(session?.startTime);
  const endTime = normalizeRpcTime(session?.endTime);
  const endAt = normalizeRpcDateTime(session?.endAt) || (date && endTime ? `${date} ${endTime}` : null);

  return {
    p_session_id: sessionId,
    p_title: String(session?.title ?? getSessionDisplayTitle(session)).trim(),
    p_session_date: date,
    p_start_time: startTime,
    p_end_time: endTime || null,
    p_end_at: endAt,
    p_application_deadline: normalizeNullableDateTime(session?.applicationDeadline),
    p_session_type: String(session?.sessionType || "one-shot").trim(),
    p_player_min: normalizeNullableInteger(session?.playerMin),
    p_player_max: normalizeNullableInteger(session?.playerMax),
    p_summary: String(session?.summary ?? "").trim() || null,
    p_visibility: "hidden",
    p_status: "canceled"
  };
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

function updateDetailStateLabels(root, session) {
  const statusValue = root.querySelector("[data-session-detail-status-row] dd");
  const visibilityValue = root.querySelector("[data-session-detail-visibility-row] dd");
  const applicationPanel = root.querySelector("[data-session-application-panel]");
  if (statusValue) statusValue.textContent = getSessionStatusLabel(session?.status);
  if (visibilityValue) visibilityValue.textContent = getSessionVisibilityLabel(session?.visibility);
  if (applicationPanel) {
    applicationPanel.dataset.sessionStatus = String(session?.status || "");
    applicationPanel.dataset.sessionVisibility = String(session?.visibility || "");
    applicationPanel.classList.remove("is-closed", "is-finished");
    applicationPanel.classList.add("is-canceled");
  }
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

async function applyDeleteEquivalent(root, client, elements, session) {
  if (!elements.deleteButton || elements.deleteButton.disabled) return;
  if (!window.confirm(DELETE_CONFIRM_MESSAGE)) return;

  const wasEditDisabled = Boolean(elements.editButton?.disabled);
  elements.deleteButton.disabled = true;
  if (elements.editButton) elements.editButton.disabled = true;
  setManageState(elements.state, "削除相当操作を実行しています。");

  try {
    const payload = buildDeleteEquivalentPayload(session);
    const { error } = await client.rpc("update_session_post", payload);
    if (error) throw error;

    session.visibility = "hidden";
    session.status = "canceled";
    updateDetailStateLabels(root, session);
    setManageState(elements.state, `${DELETE_SUCCESS_MESSAGE}\n公開状態: 非公開\n募集状態: 中止`, "is-ok");
    elements.deleteButton.title = "この依頼書は非公開・中止扱いです。";
    if (elements.editButton) elements.editButton.disabled = wasEditDisabled;
  } catch (error) {
    setManageState(elements.state, getDeleteErrorMessage(error), "is-error");
    elements.deleteButton.disabled = false;
    if (elements.editButton) elements.editButton.disabled = wasEditDisabled;
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
        elements.deleteButton.title = "この依頼書を非公開・中止扱いにします。";
        elements.deleteButton.addEventListener("click", () => {
          applyDeleteEquivalent(root, client, elements, session);
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
  initSessionDetailApplicationComments(root, { sessionId: session.id });
}
