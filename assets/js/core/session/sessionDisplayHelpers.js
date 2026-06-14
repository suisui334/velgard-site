import {
  getOpsSessionLabel,
  getOpsSessionTypeLabel
} from "../config/reusableOpsConfig.js?v=20260615-core-config-move";

const SESSION_STATUSES = {
  draft: "下書き",
  tentative: "仮予定",
  recruiting: "募集中",
  full: "満席",
  closed: "締切",
  finished: "終了",
  canceled: "中止"
};

const SESSION_VISIBILITIES = {
  hidden: "非公開",
  private: "限定",
  public: "公開"
};

export function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[char]));
}

export function getSessionStatusLabel(status) {
  return SESSION_STATUSES[status] || "未設定";
}

export function getSessionVisibilityLabel(visibility) {
  return SESSION_VISIBILITIES[visibility] || "未設定";
}

export function getSessionStatusClass(status) {
  return Object.prototype.hasOwnProperty.call(SESSION_STATUSES, status) ? status : "unknown";
}

export function getSessionTypeLabel(sessionType) {
  return getOpsSessionTypeLabel(sessionType);
}

export function getSessionLabel(key, fallback) {
  return getOpsSessionLabel(key, fallback);
}

export function isClosedSession(session) {
  return session?.status === "closed";
}

export function getSessionTitle(session) {
  return String(session?.title || "無題のセッション").trim();
}

export function hasSessionClosingMark(session) {
  return getSessionTitle(session).startsWith("〆");
}

export function getSessionTitleWithoutClosingMark(session) {
  return getSessionTitle(session).replace(/^〆\s*/, "").trim() || "無題のセッション";
}

export function getSessionDisplayTitle(session) {
  if (hasSessionClosingMark(session)) return getSessionTitle(session);
  return isClosedSession(session) ? `〆${getSessionTitle(session)}` : getSessionTitle(session);
}

export function shouldShowSessionState(session) {
  return ["tentative", "finished", "canceled"].includes(session?.status);
}

export function formatSessionStartDateTime(session) {
  const date = String(session?.date || "").trim();
  const start = String(session?.startTime || "").trim();
  if (date && start) return `${date} ${start}`;
  return start || date;
}

export function formatSessionTime(session) {
  const start = formatSessionStartDateTime(session);
  const endAt = String(session?.endAt || "").trim();
  if (endAt) {
    const match = endAt.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})$/);
    if (match) {
      const end = `${match[1]} ${match[2]}`;
      if (start) return `${start}〜${end}`;
      return end;
    }
    if (start) return `${start}〜${endAt}`;
    return endAt;
  }
  const end = String(session?.endTime || "").trim();
  const date = String(session?.date || "").trim();
  const endLabel = date && end ? `${date} ${end}` : end;
  if (start && endLabel) return `${start}〜${endLabel}`;
  return start || endLabel || "時刻未定";
}

export function formatSessionApplicationDeadline(session) {
  return String(session?.applicationDeadline || "").trim() || "未定";
}

export function formatSessionTool(session) {
  return String(session?.sessionTool || session?.session_tool || "").trim() || "未定";
}

export function formatPlayerCount(session, options = {}) {
  const count = Number.isFinite(Number(session?.playerCount)) ? Number(session.playerCount) : null;
  const max = Number.isFinite(Number(session?.playerMax)) ? Number(session.playerMax) : null;
  const min = Number.isFinite(Number(session?.playerMin)) ? Number(session.playerMin) : null;
  const base = (() => {
    if (count !== null && max !== null) return `${count} / ${max}名`;
    if (max !== null) return `最大${max}名`;
    if (count !== null) return `${count}名`;
    return "未設定";
  })();
  if (options.includeMinimum && min !== null && base !== "未設定") {
    return `${base}（最低${min}名）`;
  }
  return base;
}

export function formatSessionUpdatedAt(value) {
  const text = String(value ?? "").trim();
  if (!text) return "";

  const dateOnly = text.match(/^(\d{4}-\d{2}-\d{2})$/);
  if (dateOnly) return dateOnly[1];

  const dateTime = text.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?$/);
  if (dateTime) return `${dateTime[1]} ${dateTime[2]}:${dateTime[3]}`;

  return "";
}
