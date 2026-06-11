const FALLBACK_TARGET = "calendar.html";

const EVENT_TYPE_LABELS = {
  session_comment: "コメント",
  session_application: "コメント",
  application_status_changed: "申請状況",
  session_created: "依頼書登録",
  session_post_created: "依頼書登録",
  session_updated: "依頼書更新"
};

const COMMENT_EVENT_TYPES = new Set(["session_comment", "session_application"]);
const SESSION_CREATED_EVENT_TYPES = new Set(["session_created", "session_post_created"]);

const VISIBILITY_LABELS = {
  public: "公開",
  authenticated: "ログイン限定",
  private: "限定"
};

export function escapeActivityHtml(value = "") {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  })[character]);
}

export function normalizeActivityTargetPath(value, fallback = FALLBACK_TARGET) {
  const target = typeof value === "string" ? value.trim() : "";
  if (!target) return fallback;
  if (/[\r\n]/.test(target)) return fallback;
  if (/^[a-z][a-z0-9+.-]*:/i.test(target)) return fallback;
  if (target.startsWith("//")) return fallback;
  if (target.includes("..")) return fallback;
  return target.replace(/^\/+/, "") || fallback;
}

export function getActivityTypeLabel(type) {
  return EVENT_TYPE_LABELS[type] || "更新";
}

export function getActivityVisibilityLabel(visibility) {
  return VISIBILITY_LABELS[visibility] || "";
}

export function getActivityActorLabel(item) {
  const name = typeof item?.actor_display_name === "string" ? item.actor_display_name.trim() : "";
  if (!name) return "ユーザーさん";
  return /(?:さん|様|くん|ちゃん)$/.test(name) ? name : `${name}さん`;
}

export function getActivitySessionTitle(item) {
  const title = typeof item?.session_title === "string" ? item.session_title.trim() : "";
  return title || "タイトル未設定";
}

export function getActivitySessionLabel(item) {
  return `依頼書：${getActivitySessionTitle(item)}`;
}

export function getActivityTitle(item) {
  const actor = getActivityActorLabel(item);
  if (COMMENT_EVENT_TYPES.has(item?.event_type)) {
    return `${actor}がコメントしました`;
  }
  if (SESSION_CREATED_EVENT_TYPES.has(item?.event_type)) {
    return `${actor}が依頼書を登録しました`;
  }
  return `${actor}が更新しました`;
}

export function formatActivityDateTime(value, options = {}) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const includeYear = options.includeYear !== false;
  return new Intl.DateTimeFormat("ja-JP", {
    year: includeYear ? "numeric" : undefined,
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}
