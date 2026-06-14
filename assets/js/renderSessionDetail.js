import { getParams } from "./dataLoader.js";
import { loadMergedSessions } from "./sessionData.js?v=20260607-static-retire";
import {
  escapeHtml,
  getSessionDisplayTitle,
  hasSessionClosingMark,
  renderSessionDiscordSyncPanel,
  renderSessionDetailContent
} from "./sessionDisplay.js?v=20260615-session-row-helper-extract";
import { initSessionDetailApplicationComments } from "./sessionDetailApplicationComments.js?v=20260610-avatar-preview";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js?v=20260601-session-post";
import {
  getCurrentMembershipState,
  isApprovedMembershipState,
  renderMembershipGateNotice
} from "./membershipAccessClient.js?v=20260615-core-config-move";
import { getOpsSessionLabel } from "./core/config/reusableOpsConfig.js?v=20260615-core-config-move";
import {
  deleteSyncedSession,
  getDiscordSyncStateModifier,
  getDiscordSyncUiMessage,
  hasDiscordPostReference,
  syncUpdatedSession
} from "./discordSyncClient.js?v=20260610-discord-absolute-link";

const SESSIONS_URL = "data/sessions.json?v=20260601-session-post";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DETAIL_EXCLUDED_STATUSES = new Set(["draft", "canceled", "cancelled"]);
const DELETE_CONFIRM_MESSAGE = "この依頼書を完全に削除します。\n削除すると、依頼書本体に加えて参加申請・コメントも削除されます。\n中止として残したい場合は、削除せず募集状態を「中止」にしてください。\nDiscord投稿済みの場合は同期削除を試みます。\n本当に削除しますか？";
const DELETE_SUCCESS_MESSAGE = "この依頼書を削除しました。";
const DELETE_ERROR_MESSAGE = "依頼書の削除に失敗しました。";
const DELETE_ERROR_MESSAGES = {
  login_required: "ログインが必要です。",
  not_allowed: "この依頼書を削除する権限がありません。",
  session_not_found: "対象の依頼書が見つかりません。",
  session_id_required: "対象の依頼書が見つかりません。",
  discord_sync_delete_failed: "Discord同期削除に失敗しました。依頼書は削除していません。管理パネルで確認してください。"
};
const CLOSING_MARK = "〆";
const CLOSE_BEFORE_DEADLINE_CONFIRM_MESSAGE = "募集締切時刻より前ですが、〆マークを付けて募集終了表示にしますか？";
const CLOSE_CONFIRM_MESSAGE = "〆マークを付けて募集終了表示にしますか？";
const CLOSE_REMOVE_CONFIRM_MESSAGE = "〆マークを外して募集終了表示を解除しますか？";
const CLOSE_OVERDUE_NOTE = "募集締切時刻を過ぎています。〆ボタンを押し忘れていませんか？";
const CLOSE_SUCCESS_MESSAGE = "〆マークを更新しました。";
const CLOSE_ERROR_MESSAGE = "〆マークの更新に失敗しました。";

function getSessionDetailLabel(key, fallback) {
  return getOpsSessionLabel(key, fallback);
}

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

function normalizeTitleText(value) {
  return String(value ?? "").trim();
}

function addClosingMarkToTitle(title) {
  const withoutMarks = normalizeTitleText(title).replace(/^(?:〆\s*)+/, "").trim();
  return `${CLOSING_MARK}${withoutMarks || "無題のセッション"}`;
}

function removeClosingMarkFromTitle(title) {
  return normalizeTitleText(title).replace(/^〆\s*/, "").trim() || "無題のセッション";
}

function toNullableText(value) {
  const text = String(value ?? "").trim();
  return text || null;
}

function toOptionalInteger(value) {
  if (value === null || value === undefined || String(value).trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? Math.trunc(number) : null;
}

function toRpcEndAt(session) {
  const endAt = String(session?.endAt || "").trim();
  if (/^\d{4}-\d{2}-\d{2} [0-2]\d:[0-5]\d$/.test(endAt)) return endAt;
  const date = String(session?.date || "").trim();
  const endTime = String(session?.endTime || "").trim();
  return date && endTime ? `${date} ${endTime}` : null;
}

function buildTitleUpdatePayload(session, title) {
  const sessionId = String(session?.id ?? "").trim();
  if (!sessionId) throw new Error("session_not_found");
  return {
    p_session_id: sessionId,
    p_title: normalizeTitleText(title),
    p_session_date: toNullableText(session?.date),
    p_start_time: toNullableText(session?.startTime),
    p_end_time: toNullableText(session?.endTime),
    p_end_at: toRpcEndAt(session),
    p_application_deadline: toNullableText(session?.applicationDeadline),
    p_session_type: toNullableText(session?.sessionType) || "other",
    p_session_tool: String(session?.sessionTool ?? session?.session_tool ?? "").trim(),
    p_player_min: toOptionalInteger(session?.playerMin),
    p_player_max: toOptionalInteger(session?.playerMax),
    p_summary: toNullableText(session?.summary),
    p_visibility: toNullableText(session?.visibility) || "hidden",
    p_status: toNullableText(session?.status) || "draft"
  };
}

function parseLocalDateTime(value) {
  const text = String(value || "").trim();
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
  if (!match) return null;
  const [, year, month, day, hour, minute] = match.map(Number);
  const date = new Date(year, month - 1, day, hour, minute);
  return Number.isNaN(date.getTime()) ? null : date;
}

function isBeforeApplicationDeadline(session) {
  const deadline = parseLocalDateTime(session?.applicationDeadline);
  return Boolean(deadline && Date.now() < deadline.getTime());
}

function isAfterApplicationDeadline(session) {
  const deadline = parseLocalDateTime(session?.applicationDeadline);
  return Boolean(deadline && Date.now() > deadline.getTime());
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
    closeButton: panel?.querySelector("[data-session-detail-close]") || null,
    closeNote: panel?.querySelector("[data-session-detail-close-note]") || null,
    deleteButton: panel?.querySelector("[data-session-detail-delete]") || null,
    state: panel?.querySelector("[data-session-detail-manage-state]") || null,
    discordSync: panel?.querySelector("[data-session-detail-discord-sync]") || null
  };
}

function hideClosingMarkControl(elements) {
  if (elements.closeButton) {
    elements.closeButton.hidden = true;
    elements.closeButton.disabled = true;
  }
  if (elements.closeNote) {
    elements.closeNote.hidden = true;
    elements.closeNote.textContent = "";
    elements.closeNote.className = "session-detail-manage-close-note";
  }
}

function hideDiscordSyncPanel(elements) {
  if (!elements.discordSync) return;
  elements.discordSync.hidden = true;
  elements.discordSync.replaceChildren();
}

function showDiscordSyncPanel(elements, session) {
  if (!elements.discordSync) return;
  elements.discordSync.innerHTML = renderSessionDiscordSyncPanel(session);
  elements.discordSync.hidden = false;
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
    return { allowed: true, isAdmin, isSessionGm, message: "この依頼書を編集できます。" };
  }

  return { allowed: false, isAdmin, isSessionGm, message: "この予定は編集できません。" };
}

function setManageButtonsDisabled(elements, disabled) {
  if (elements.editButton) elements.editButton.disabled = disabled;
  if (elements.deleteButton) elements.deleteButton.disabled = disabled;
  if (elements.closeButton && !elements.closeButton.hidden) elements.closeButton.disabled = disabled;
}

function configureClosingMarkControl(elements, session, client, access) {
  if (!elements.closeButton || access?.isSessionGm !== true) {
    hideClosingMarkControl(elements);
    return;
  }

  const marked = hasSessionClosingMark(session);
  elements.closeButton.hidden = false;
  elements.closeButton.disabled = false;
  elements.closeButton.textContent = marked ? "〆解除" : "〆にする";
  elements.closeButton.title = marked ? "タイトル先頭の〆マークを外します。" : "タイトル先頭に〆マークを付けます。";
  elements.closeButton.addEventListener("click", () => {
    applyToggleClosingMark(client, elements, session);
  });

  if (elements.closeNote) {
    const showOverdueNote = !marked && isAfterApplicationDeadline(session);
    elements.closeNote.hidden = !showOverdueNote;
    elements.closeNote.textContent = showOverdueNote ? CLOSE_OVERDUE_NOTE : "";
    elements.closeNote.className = `session-detail-manage-close-note${showOverdueNote ? " is-warn" : ""}`;
  }
}

async function applyToggleClosingMark(client, elements, session) {
  if (!elements.closeButton || elements.closeButton.disabled) return;
  const marked = hasSessionClosingMark(session);
  const nextTitle = marked
    ? removeClosingMarkFromTitle(session?.title)
    : addClosingMarkToTitle(session?.title);
  if (nextTitle === normalizeTitleText(session?.title)) return;

  const confirmMessage = marked
    ? CLOSE_REMOVE_CONFIRM_MESSAGE
    : (isBeforeApplicationDeadline(session) ? CLOSE_BEFORE_DEADLINE_CONFIRM_MESSAGE : CLOSE_CONFIRM_MESSAGE);
  if (!window.confirm(confirmMessage)) return;

  setManageButtonsDisabled(elements, true);
  setManageState(elements.state, "〆マークを更新しています。");

  try {
    const payload = buildTitleUpdatePayload(session, nextTitle);
    const { error } = await client.rpc("update_session_post", payload);
    if (error) throw error;

    const syncResult = await syncUpdatedSession(client, {
      sessionId: payload.p_session_id,
      payload,
      session
    });
    const syncMessage = getDiscordSyncUiMessage(syncResult, {
      successMessage: "Discord同期更新を実行しました。詳細は管理パネルで確認してください。"
    });
    const message = syncMessage ? `${CLOSE_SUCCESS_MESSAGE} ${syncMessage}` : CLOSE_SUCCESS_MESSAGE;
    setManageState(elements.state, message, getDiscordSyncStateModifier(syncResult, "is-ok"));
    window.setTimeout(() => {
      window.location.reload();
    }, 900);
  } catch {
    setManageState(elements.state, CLOSE_ERROR_MESSAGE, "is-error");
    setManageButtonsDisabled(elements, false);
  }
}

async function applyDeleteSessionPost(client, elements, session) {
  if (!elements.deleteButton || elements.deleteButton.disabled) return;
  if (!window.confirm(DELETE_CONFIRM_MESSAGE)) return;

  setManageButtonsDisabled(elements, true);
  setManageState(elements.state, "削除しています。");

  try {
    const payload = buildDeletePayload(session);
    if (hasDiscordPostReference(session)) {
      const syncResult = await deleteSyncedSession(client, {
        session,
        sessionId: payload.p_session_id
      });
      if (!syncResult.ok) {
        throw new Error("discord_sync_delete_failed");
      }
    } else {
      const { error } = await client.rpc("delete_session_post", payload);
      if (error) throw error;
    }

    setManageState(elements.state, DELETE_SUCCESS_MESSAGE, "is-ok");
    elements.deleteButton.title = "この依頼書は削除済みです。";
    window.setTimeout(() => {
      window.location.href = calendarHref(session?.date);
    }, 900);
  } catch (error) {
    setManageState(elements.state, getDeleteErrorMessage(error), "is-error");
    elements.deleteButton.disabled = false;
    if (elements.editButton) elements.editButton.disabled = false;
    if (elements.closeButton && !elements.closeButton.hidden) elements.closeButton.disabled = false;
  }
}

async function initSessionDetailManageActionsWithDelete(root, session) {
  const elements = getSessionManageElements(root);
  if (!elements.panel) return;
  hideDiscordSyncPanel(elements);
  hideClosingMarkControl(elements);

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
    hideClosingMarkControl(elements);
    setManageState(elements.state, "この予定は静的データ由来のため、この画面では編集できません。この予定は静的データ由来のため、この画面では削除できません。");
    return;
  }

  try {
    const client = await createSupabaseBrowserClient();
    if (!client) {
      if (elements.editButton) elements.editButton.disabled = true;
      if (elements.deleteButton) elements.deleteButton.disabled = true;
      hideClosingMarkControl(elements);
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
      configureClosingMarkControl(elements, session, client, access);
      showDiscordSyncPanel(elements, session);
      setManageState(elements.state, access.message, "is-ok");
      return;
    }

    if (elements.editButton) elements.editButton.disabled = true;
    if (elements.deleteButton) {
      elements.deleteButton.disabled = true;
      elements.deleteButton.title = "この依頼書を操作する権限がありません。";
    }
    hideClosingMarkControl(elements);
    hideDiscordSyncPanel(elements);
    setManageState(elements.state, getAccessDeniedManageMessage(access));
  } catch {
    if (elements.editButton) elements.editButton.disabled = true;
    if (elements.deleteButton) {
      elements.deleteButton.disabled = true;
      elements.deleteButton.title = "権限確認に失敗しました。";
    }
    hideClosingMarkControl(elements);
    hideDiscordSyncPanel(elements);
    setManageState(elements.state, "編集権限を確認できませんでした。", "is-error");
  }
}

async function initSessionDetailManageActions(root, session) {
  return initSessionDetailManageActionsWithDelete(root, session);
}

export async function renderSessionDetail(root, _site, options = {}) {
  const membershipState = options.membershipState || await getCurrentMembershipState();
  if (!isApprovedMembershipState(membershipState)) {
    root.innerHTML = renderMembershipGateNotice(membershipState, {
      eyebrow: "Session Detail",
      title: getSessionDetailLabel("sessionDetailGateTitle", "セッション予定詳細"),
      lead: getSessionDetailLabel("sessionDetailGateLead", "依頼書詳細、参加申請、コメントは承認済みメンバー向けの機能です。"),
      heading: getSessionDetailLabel("sessionDetailGateHeading", "承認後に依頼書詳細を確認できます")
    });
    return;
  }

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
