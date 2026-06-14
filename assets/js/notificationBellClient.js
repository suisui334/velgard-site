import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js";
import { getCurrentMembershipState } from "./membershipAccessClient.js?v=20260615-session-gate-labels";

const NOTIFICATION_LIMIT = 8;
const FALLBACK_TARGET = "mypage.html";
const EMPTY_MESSAGE = "通知はありません";
const LOAD_ERROR_MESSAGE = "通知を読み込めませんでした";
const TYPE_LABELS = {
  session_comment: "コメント",
  session_application: "コメント",
  session_comment_updated: "コメント更新",
  application_status_changed: "申請状況更新",
  session_created: "依頼書登録",
  session_post_created: "依頼書登録",
  session_updated: "依頼書更新"
};
const COMMENT_NOTIFICATION_TYPES = new Set(["session_comment", "session_application"]);
const SESSION_CREATED_NOTIFICATION_TYPES = new Set(["session_created", "session_post_created"]);

const state = {
  initialized: false,
  client: null,
  container: null,
  button: null,
  badge: null,
  panel: null,
  list: null,
  status: null,
  markAll: null,
  isOpen: false,
  isAuthenticated: false,
  isApprovedMember: false,
  listLoading: false,
  cachedItems: []
};

function createBellSvg() {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("width", "18");
  svg.setAttribute("height", "18");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");

  const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
  path.setAttribute("d", "M12 22a2.5 2.5 0 0 0 2.35-1.65h-4.7A2.5 2.5 0 0 0 12 22Zm7-5.5-1.7-2.05V10a5.32 5.32 0 0 0-4.05-5.2V3.75a1.25 1.25 0 0 0-2.5 0V4.8A5.32 5.32 0 0 0 6.7 10v4.45L5 16.5v1.2h14v-1.2Z");
  path.setAttribute("fill", "currentColor");
  svg.append(path);
  return svg;
}

function ensureNotificationShell() {
  if (state.container?.isConnected) return true;

  const accountLink = document.querySelector(".account-nav__link");
  if (!accountLink) return false;

  const container = document.createElement("div");
  container.className = "notification-nav";
  container.hidden = true;

  const button = document.createElement("button");
  button.className = "notification-bell";
  button.type = "button";
  button.setAttribute("aria-label", "通知を開く");
  button.setAttribute("aria-haspopup", "dialog");
  button.setAttribute("aria-expanded", "false");
  button.append(createBellSvg());

  const badge = document.createElement("span");
  badge.className = "notification-bell__badge";
  badge.hidden = true;
  button.append(badge);

  const panel = document.createElement("div");
  panel.className = "notification-panel";
  panel.hidden = true;
  panel.setAttribute("role", "dialog");
  panel.setAttribute("aria-label", "通知一覧");

  const header = document.createElement("div");
  header.className = "notification-panel__header";

  const heading = document.createElement("strong");
  heading.textContent = "通知";

  const markAll = document.createElement("button");
  markAll.className = "notification-panel__mark-all";
  markAll.type = "button";
  markAll.textContent = "すべて既読";

  header.append(heading, markAll);

  const status = document.createElement("p");
  status.className = "notification-panel__status";
  status.hidden = true;

  const list = document.createElement("ul");
  list.className = "notification-panel__list";

  panel.append(header, status, list);
  container.append(button, panel);
  accountLink.insertAdjacentElement("beforebegin", container);

  button.addEventListener("click", () => {
    setPanelOpen(!state.isOpen);
  });

  markAll.addEventListener("click", () => {
    markAllNotificationsRead();
  });

  document.addEventListener("click", (event) => {
    if (!state.container || !state.isOpen) return;
    if (state.container.contains(event.target)) return;
    setPanelOpen(false);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.isOpen) {
      setPanelOpen(false);
      state.button?.focus();
    }
  });

  state.container = container;
  state.button = button;
  state.badge = badge;
  state.panel = panel;
  state.list = list;
  state.status = status;
  state.markAll = markAll;
  return true;
}

function setStatus(message = "", isError = false) {
  if (!state.status) return;
  state.status.textContent = message;
  state.status.hidden = !message;
  state.status.classList.toggle("is-error", isError);
}

function setPanelOpen(open) {
  if (!state.panel || !state.button) return;
  state.isOpen = Boolean(open);
  state.panel.hidden = !state.isOpen;
  state.button.setAttribute("aria-expanded", String(state.isOpen));
  if (state.isOpen) {
    loadNotificationList();
  }
}

function setBellVisible(visible) {
  if (!state.container && !ensureNotificationShell()) return;
  state.container.hidden = !visible;
  if (!visible) {
    setPanelOpen(false);
    setUnreadCount(0);
    cacheNotifications([]);
  }
}

function setUnreadCount(count) {
  const normalized = Number.isFinite(Number(count)) ? Math.max(0, Number(count)) : 0;
  if (!state.badge || !state.markAll) return;
  if (normalized <= 0) {
    state.badge.hidden = true;
    state.badge.textContent = "";
    state.markAll.disabled = true;
    return;
  }
  state.badge.hidden = false;
  state.badge.textContent = normalized > 99 ? "99+" : String(normalized);
  state.markAll.disabled = false;
}

function normalizeTargetPath(value) {
  const target = typeof value === "string" ? value.trim() : "";
  if (!target) return FALLBACK_TARGET;
  if (/[\r\n]/.test(target)) return FALLBACK_TARGET;
  if (/^[a-z][a-z0-9+.-]*:/i.test(target)) return FALLBACK_TARGET;
  if (target.startsWith("//")) return FALLBACK_TARGET;
  if (target.includes("..")) return FALLBACK_TARGET;
  return target.replace(/^\/+/, "") || FALLBACK_TARGET;
}

function getTypeLabel(type) {
  return TYPE_LABELS[type] || "通知";
}

function getActorLabel(item) {
  const name = typeof item?.actor_display_name === "string" ? item.actor_display_name.trim() : "";
  if (!name) return "ユーザーさん";
  return /(?:さん|様|くん|ちゃん)$/.test(name) ? name : `${name}さん`;
}

function getSessionTitle(item) {
  const title = typeof item?.session_title === "string" ? item.session_title.trim() : "";
  return title || "タイトル未設定";
}

function formatDateTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("ja-JP", {
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

function getNotificationTitle(item) {
  const actor = getActorLabel(item);
  if (COMMENT_NOTIFICATION_TYPES.has(item?.notification_type)) {
    return `${actor}がコメントしました`;
  }
  if (SESSION_CREATED_NOTIFICATION_TYPES.has(item?.notification_type)) {
    return `${actor}が依頼書を登録しました`;
  }
  if (item?.notification_type === "session_comment_updated") {
    return `${actor}がコメントを更新しました`;
  }
  return `${actor}が更新しました`;
}

function getNotificationBody(item) {
  return `依頼書：${getSessionTitle(item)}`;
}

function createNotificationItem(item) {
  const listItem = document.createElement("li");
  listItem.className = "notification-panel__item";
  listItem.classList.toggle("is-unread", item?.is_read === false);
  listItem.classList.toggle("is-read", item?.is_read === true);

  const link = document.createElement("a");
  link.className = "notification-panel__link";
  link.href = normalizeTargetPath(item?.target_path);

  const meta = document.createElement("span");
  meta.className = "notification-panel__meta";
  const formattedTime = formatDateTime(item?.created_at);
  meta.textContent = formattedTime ? `${getTypeLabel(item?.notification_type)} / ${formattedTime}` : getTypeLabel(item?.notification_type);

  const title = document.createElement("strong");
  title.className = "notification-panel__title";
  title.textContent = getNotificationTitle(item);

  const sessionTitle = document.createElement("span");
  sessionTitle.className = "notification-panel__session";
  sessionTitle.textContent = getNotificationBody(item);

  const body = document.createElement("span");
  body.className = "notification-panel__body";
  body.textContent = "";

  link.append(meta, title);
  if (sessionTitle.textContent) link.append(sessionTitle);
  if (body.textContent) link.append(body);

  link.addEventListener("click", (event) => {
    if (item?.is_read !== false || !item?.notification_id) return;
    event.preventDefault();
    markNotificationRead(item.notification_id).finally(() => {
      window.location.href = link.href;
    });
  });

  listItem.append(link);

  if (item?.is_read === false && item?.notification_id) {
    const markOne = document.createElement("button");
    markOne.className = "notification-panel__mark-one";
    markOne.type = "button";
    markOne.textContent = "既読";
    markOne.addEventListener("click", () => {
      markNotificationRead(item.notification_id);
    });
    listItem.append(markOne);
  }

  return listItem;
}

function renderNotifications(items = []) {
  if (!state.list) return;
  state.list.replaceChildren();
  if (!items.length) {
    setStatus(EMPTY_MESSAGE);
    return;
  }
  setStatus("");
  items.forEach((item) => {
    state.list.append(createNotificationItem(item));
  });
}

function cacheNotifications(items = []) {
  state.cachedItems = Array.isArray(items) ? items : [];
}

function markCachedNotificationRead(notificationId = "") {
  if (!notificationId || !state.cachedItems.length) return;
  state.cachedItems = state.cachedItems.map((item) => (
    item?.notification_id === notificationId
      ? { ...item, is_read: true }
      : item
  ));
}

function markAllCachedNotificationsRead() {
  if (!state.cachedItems.length) return;
  state.cachedItems = state.cachedItems.map((item) => ({ ...item, is_read: true }));
}

async function refreshUnreadCount() {
  if (!state.client || !state.isAuthenticated || !state.isApprovedMember) return;
  const { data, error } = await state.client.rpc("get_my_unread_notification_count");
  if (error) {
    setUnreadCount(0);
    return;
  }
  setUnreadCount(data);
}

async function loadNotificationList(options = {}) {
  if (!state.client || !state.isAuthenticated || !state.isApprovedMember || state.listLoading) return;
  state.listLoading = true;
  setStatus("読み込み中");
  try {
    const { data, error } = await state.client.rpc("get_my_notifications", {
      p_limit: NOTIFICATION_LIMIT,
      p_unread_only: false
    });
    if (error) {
      renderNotifications([]);
      setStatus(LOAD_ERROR_MESSAGE, true);
      return;
    }
    const items = Array.isArray(data) ? data : [];
    if (items.length || !options.preserveCached || !state.cachedItems.length) {
      cacheNotifications(items);
    }
    renderNotifications(state.cachedItems);
    await refreshUnreadCount();
  } catch {
    renderNotifications([]);
    setStatus(LOAD_ERROR_MESSAGE, true);
  } finally {
    state.listLoading = false;
  }
}

async function markNotificationRead(notificationId) {
  if (!state.client || !notificationId) return;
  try {
    await state.client.rpc("mark_my_notification_read", {
      p_notification_id: notificationId
    });
  } catch {
    setStatus(LOAD_ERROR_MESSAGE, true);
    return;
  }
  markCachedNotificationRead(notificationId);
  renderNotifications(state.cachedItems);
  await loadNotificationList({ preserveCached: true });
  await refreshUnreadCount();
}

async function markAllNotificationsRead() {
  if (!state.client || !state.isAuthenticated || !state.isApprovedMember || !state.markAll) return;
  state.markAll.disabled = true;
  try {
    await state.client.rpc("mark_all_my_notifications_read");
  } catch {
    setStatus(LOAD_ERROR_MESSAGE, true);
    return;
  } finally {
    state.markAll.disabled = false;
  }
  markAllCachedNotificationsRead();
  renderNotifications(state.cachedItems);
  await loadNotificationList({ preserveCached: true });
  await refreshUnreadCount();
}

async function handleAuthSession(session) {
  state.isAuthenticated = Boolean(session);
  state.isApprovedMember = false;
  setBellVisible(false);
  if (!state.isAuthenticated) {
    setPanelOpen(false);
    return;
  }

  const membershipState = await getCurrentMembershipState(state.client);
  state.isAuthenticated = membershipState.isAuthenticated;
  state.isApprovedMember = membershipState.isApproved;
  setBellVisible(state.isApprovedMember);
  if (!state.isApprovedMember) {
    setPanelOpen(false);
    return;
  }
  refreshUnreadCount();
}

export function refreshNotificationBell() {
  if (!state.container && !ensureNotificationShell()) return;
  if (!state.client) return;
  state.client.auth.getSession().then(({ data }) => {
    void handleAuthSession(data?.session || null);
  }).catch(() => {
    void handleAuthSession(null);
  });
}

export function resetNotificationBell() {
  state.isAuthenticated = false;
  state.isApprovedMember = false;
  setPanelOpen(false);
  setBellVisible(false);
}

export async function initNotificationBell() {
  if (state.initialized) return;
  state.initialized = true;
  ensureNotificationShell();

  window.VelgardNotifications = {
    refresh: refreshNotificationBell,
    reset: resetNotificationBell
  };

  try {
    state.client = await createSupabaseBrowserClient();
    if (!state.client) {
      resetNotificationBell();
      return;
    }

    const { data } = await state.client.auth.getSession();
    void handleAuthSession(data?.session || null);
    state.client.auth.onAuthStateChange((_event, session) => {
      void handleAuthSession(session);
    });
  } catch {
    resetNotificationBell();
  }
}
