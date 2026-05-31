const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
const COMMENT_RPC = "get_public_session_comments";
const COUNT_RPC = "get_public_session_application_counts";
const APPLICATION_SELECT_COLUMNS = "session_id,status,created_at,updated_at,canceled_at";
const POST_ALLOWED_STATUSES = new Set(["recruiting", "tentative"]);

const APPLICATION_STATUS_LABELS = Object.freeze({
  pending: "申請中",
  accepted: "承認済み",
  waitlisted: "申請中",
  rejected: "見送り",
  canceled: "取消済み"
});

const APPLICATION_STATUS_MESSAGES = Object.freeze({
  pending: "参加申請中です。追加コメント投稿は次工程で実装予定です。",
  accepted: "参加予定として承認済みです。追加コメント投稿は次工程で実装予定です。",
  waitlisted: "申請中です。追加コメント投稿は次工程で実装予定です。",
  rejected: "このセッションへの申請は現在行えません。",
  canceled: "参加申請は取り消されています。再申請投稿は次工程で扱います。"
});

const SENSITIVE_FIELD_NAMES = new Set([
  "access_token",
  "anon_key",
  "application_id",
  "db_password",
  "direct_connection_string",
  "discord_id",
  "discord_user_id",
  "email",
  "gm_user_id",
  "gmuserid",
  "jwt",
  "key",
  "password",
  "publishable_key",
  "refresh_token",
  "role",
  "secret",
  "service_role",
  "token",
  "user_id"
]);

function getConfig() {
  const config = window.VELGARD_SUPABASE_CONFIG || {};
  return {
    url: typeof config.url === "string" ? config.url.trim() : "",
    anonKey: typeof config.anonKey === "string" ? config.anonKey.trim() : ""
  };
}

function hasConfig(config) {
  return Boolean(config.url && config.anonKey);
}

function loadSupabaseSdk() {
  if (window.supabase && typeof window.supabase.createClient === "function") {
    return Promise.resolve();
  }

  if (window[SDK_LOAD_KEY]) {
    return window[SDK_LOAD_KEY];
  }

  window[SDK_LOAD_KEY] = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = SDK_SRC;
    script.async = true;
    script.crossOrigin = "anonymous";
    script.onload = () => {
      if (window.supabase && typeof window.supabase.createClient === "function") {
        resolve();
        return;
      }
      reject(new Error("supabase-sdk-unavailable"));
    };
    script.onerror = () => reject(new Error("supabase-sdk-load-failed"));
    document.head.appendChild(script);
  });

  return window[SDK_LOAD_KEY];
}

function createClient(config) {
  return window.supabase.createClient(config.url, config.anonKey, {
    auth: {
      detectSessionInUrl: false
    }
  });
}

function redactSensitiveText(value) {
  return String(value ?? "")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[非表示]")
    .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[非表示]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, "[非表示]")
    .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[非表示]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[非表示]");
}

function setState(target, message, modifier = "") {
  if (!target) return;
  target.replaceChildren();
  const paragraph = document.createElement("p");
  paragraph.className = `session-comment-state${modifier ? ` ${modifier}` : ""}`;
  paragraph.textContent = message;
  target.append(paragraph);
}

function toCount(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : 0;
}

function getStatusLabel(status) {
  const key = String(status || "").trim().toLowerCase();
  return APPLICATION_STATUS_LABELS[key] || "申請状況未設定";
}

function getStatusClass(status) {
  const key = String(status || "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(APPLICATION_STATUS_LABELS, key) ? key : "unknown";
}

function formatDateTime(value) {
  const text = String(value || "").trim();
  if (!text) return "";
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Asia/Tokyo"
  }).format(date);
}

function assertNoSensitiveFields(rows) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (SENSITIVE_FIELD_NAMES.has(String(key).toLowerCase())) {
        throw new Error("sensitive-field-returned");
      }
    }
  }
}

async function queryPublicComments(client, sessionId) {
  const { data, error } = await client.rpc(COMMENT_RPC, {
    target_session_id: sessionId
  });

  if (error) throw new Error("comments-rpc-failed");
  const rows = Array.isArray(data) ? data : [];
  assertNoSensitiveFields(rows);
  return rows;
}

async function queryApplicationCounts(client, sessionId) {
  const { data, error } = await client.rpc(COUNT_RPC, {
    target_session_id: sessionId
  });

  if (error) throw new Error("counts-rpc-failed");
  const rows = Array.isArray(data) ? data : [];
  assertNoSensitiveFields(rows);
  return rows[0] || null;
}

async function getAuthSession(client) {
  if (!client?.auth || typeof client.auth.getSession !== "function") {
    return { state: "unknown", session: null };
  }

  try {
    const { data, error } = await client.auth.getSession();
    if (error) return { state: "unknown", session: null };
    return data?.session?.user?.id
      ? { state: "authenticated", session: data.session }
      : { state: "anonymous", session: null };
  } catch {
    return { state: "unknown", session: null };
  }
}

function renderAuthNote(target, authState) {
  if (!target) return;
  if (authState === "authenticated") {
    target.textContent = "ログイン状態を確認しました。送信機能は次工程で実装予定です。";
    return;
  }
  if (authState === "unknown") {
    target.textContent = "ログイン状態を確認できませんでした。投稿機能は現在利用できません。";
    return;
  }
  target.textContent = "参加希望コメントの投稿にはログインが必要です。ACCOUNTからログインしてください。";
}

async function queryOwnApplication(client, sessionId, authSession) {
  const userId = String(authSession?.user?.id || "").trim();
  if (!userId) return null;

  const { data, error } = await client
    .from("session_applications")
    .select(APPLICATION_SELECT_COLUMNS)
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error("own-application-query-failed");
  assertNoSensitiveFields(data);
  return data || null;
}

function getSessionMeta(panel) {
  const status = String(panel?.dataset?.sessionStatus || "").trim().toLowerCase();
  const visibility = String(panel?.dataset?.sessionVisibility || "").trim().toLowerCase();
  return {
    status,
    visibility,
    canApply: visibility === "public" && POST_ALLOWED_STATUSES.has(status)
  };
}

function createStateMessage(message, modifier = "") {
  const paragraph = document.createElement("p");
  paragraph.className = `session-comment-state${modifier ? ` ${modifier}` : ""}`;
  paragraph.textContent = message;
  return paragraph;
}

function appendLoginAction(target) {
  const actions = document.createElement("div");
  actions.className = "session-comment-login-actions";

  const link = document.createElement("a");
  link.className = "button session-comment-login-link";
  link.href = "mypage.html";
  link.textContent = "ACCOUNTへ";

  actions.append(link);
  target.append(actions);
}

function appendDisabledCommentForm(target) {
  const form = document.createElement("form");
  form.className = "session-comment-form";
  form.noValidate = true;
  form.addEventListener("submit", (event) => event.preventDefault());

  const field = document.createElement("label");
  field.className = "session-comment-field";

  const labelText = document.createElement("span");
  labelText.textContent = "参加希望コメント";

  const textarea = document.createElement("textarea");
  textarea.className = "session-comment-textarea";
  textarea.name = "application-comment";
  textarea.rows = 4;
  textarea.disabled = true;
  textarea.placeholder = "送信機能は次工程で実装予定です。";

  field.append(labelText, textarea);

  const button = document.createElement("button");
  button.className = "session-application-button session-comment-button";
  button.type = "button";
  button.disabled = true;
  button.textContent = "送信機能は次工程で実装予定";

  form.append(field, button);
  target.append(form);
}

function getOwnApplicationMessage(ownApplication) {
  const status = String(ownApplication?.status || "").trim().toLowerCase();
  if (!status) return "参加希望コメントを投稿できます。送信機能は次工程で実装予定です。";
  return APPLICATION_STATUS_MESSAGES[status] || "申請状態を確認しました。送信機能は次工程で実装予定です。";
}

function shouldShowDisabledForm(ownApplication) {
  const status = String(ownApplication?.status || "").trim().toLowerCase();
  return status !== "rejected";
}

function renderPostControl(target, options = {}) {
  if (!target) return;
  const authState = options.authState || "unknown";
  const sessionMeta = options.sessionMeta || {};
  target.replaceChildren();

  if (!sessionMeta.canApply) {
    target.append(createStateMessage("このセッションは現在申請できません。参加希望コメントは読み取り専用です。", "is-warn"));
    return;
  }

  if (authState === "anonymous") {
    target.append(createStateMessage("参加希望コメントの投稿にはログインが必要です。ACCOUNTからログインしてください。", "is-warn"));
    appendLoginAction(target);
    return;
  }

  if (authState !== "authenticated") {
    target.append(createStateMessage("ログイン状態を確認できませんでした。時間をおいて再読み込みしてください。", "is-error"));
    return;
  }

  if (options.ownApplicationError) {
    target.append(createStateMessage("申請状態を確認できませんでした。時間をおいて再読み込みしてください。", "is-error"));
    return;
  }

  const message = getOwnApplicationMessage(options.ownApplication);
  const status = String(options.ownApplication?.status || "").trim().toLowerCase();
  target.append(createStateMessage(message, status === "rejected" ? "is-warn" : "is-ok"));

  if (shouldShowDisabledForm(options.ownApplication)) {
    appendDisabledCommentForm(target);
  }
}

function renderCounts(target, row) {
  if (!target) return;
  const accepted = toCount(row?.accepted_count);
  const pending = toCount(row?.pending_count);

  target.replaceChildren();
  const list = document.createElement("dl");
  list.className = "session-comment-count-grid";

  [
    ["申請中", pending, "pending"],
    ["承認済み", accepted, "accepted"]
  ].forEach(([label, value, key]) => {
    const item = document.createElement("div");
    item.className = `session-comment-count-item is-${key}`;

    const term = document.createElement("dt");
    term.textContent = label;

    const description = document.createElement("dd");
    description.textContent = `${value}名`;

    item.append(term, description);
    list.append(item);
  });

  target.append(list);
}

function normalizeComments(rows) {
  return rows.map((row) => ({
    displayName: redactSensitiveText(row?.display_name).trim() || "名前未設定",
    body: redactSensitiveText(row?.body).trim() || "本文なし",
    applicationStatus: String(row?.application_status || "").trim(),
    createdAt: String(row?.created_at || "").trim(),
    updatedAt: String(row?.updated_at || "").trim(),
    editedAt: String(row?.edited_at || "").trim()
  })).sort((a, b) => {
    const aTime = Date.parse(a.createdAt) || 0;
    const bTime = Date.parse(b.createdAt) || 0;
    return aTime - bTime;
  });
}

function renderCommentMeta(comment) {
  const createdAt = formatDateTime(comment.createdAt);
  const editedAt = formatDateTime(comment.editedAt);
  const updatedAt = !editedAt ? formatDateTime(comment.updatedAt) : "";
  const parts = [];
  if (createdAt) parts.push(`投稿 ${createdAt}`);
  if (editedAt) parts.push(`編集 ${editedAt}`);
  if (updatedAt && updatedAt !== createdAt) parts.push(`更新 ${updatedAt}`);
  return parts.join(" / ");
}

function renderComments(target, rows) {
  if (!target) return;
  const comments = normalizeComments(rows);
  target.replaceChildren();

  if (!comments.length) {
    setState(target, "まだ参加希望コメントはありません", "is-empty");
    return;
  }

  const list = document.createElement("ul");
  list.className = "session-comment-items";

  for (const comment of comments) {
    const item = document.createElement("li");
    item.className = "session-comment-item";

    const header = document.createElement("div");
    header.className = "session-comment-item-head";

    const name = document.createElement("strong");
    name.className = "session-comment-author";
    name.textContent = comment.displayName;

    const status = document.createElement("span");
    status.className = `session-comment-status-badge is-${getStatusClass(comment.applicationStatus)}`;
    status.textContent = getStatusLabel(comment.applicationStatus);

    header.append(name, status);

    const body = document.createElement("p");
    body.className = "session-comment-body";
    body.textContent = comment.body;

    const metaText = renderCommentMeta(comment);
    item.append(header, body);
    if (metaText) {
      const meta = document.createElement("p");
      meta.className = "session-comment-meta";
      meta.textContent = metaText;
      item.append(meta);
    }

    list.append(item);
  }

  target.append(list);
}

async function refreshPanel(panel, sessionId) {
  const countsTarget = panel.querySelector("[data-session-comment-counts]");
  const commentsTarget = panel.querySelector("[data-session-comment-list]");
  const authNote = panel.querySelector("[data-session-comment-auth-note]");
  const postTarget = panel.querySelector("[data-session-comment-post-control]");
  const sessionMeta = getSessionMeta(panel);

  if (!sessionId) {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderAuthNote(authNote, "unknown");
    return;
  }

  const config = getConfig();
  if (!hasConfig(config)) {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderAuthNote(authNote, "unknown");
    return;
  }

  try {
    await loadSupabaseSdk();
    const client = createClient(config);
    const [commentsResult, countsResult, authResult] = await Promise.allSettled([
      queryPublicComments(client, sessionId),
      queryApplicationCounts(client, sessionId),
      getAuthSession(client)
    ]);

    if (commentsResult.status === "fulfilled") {
      renderComments(commentsTarget, commentsResult.value);
    } else {
      setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    }

    if (countsResult.status === "fulfilled") {
      renderCounts(countsTarget, countsResult.value);
    } else {
      setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    }

    const authContext = authResult.status === "fulfilled" ? authResult.value : { state: "unknown", session: null };
    let ownApplication = null;
    let ownApplicationError = false;

    if (authContext.state === "authenticated") {
      try {
        ownApplication = await queryOwnApplication(client, sessionId, authContext.session);
      } catch {
        ownApplicationError = true;
      }
    }

    renderAuthNote(authNote, authContext.state);
    renderPostControl(postTarget, {
      authState: authContext.state,
      ownApplication,
      ownApplicationError,
      sessionMeta
    });
  } catch {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderAuthNote(authNote, "unknown");
  }
}

export function initSessionDetailApplicationComments(root, options = {}) {
  const scope = root || document;
  const panels = Array.from(scope.querySelectorAll("[data-session-application-panel]"));

  for (const panel of panels) {
    if (panel.dataset.sessionApplicationInitialized === "true") continue;
    panel.dataset.sessionApplicationInitialized = "true";
    const sessionId = String(options.sessionId || panel.dataset.sessionId || "").trim();
    refreshPanel(panel, sessionId);
  }
}
