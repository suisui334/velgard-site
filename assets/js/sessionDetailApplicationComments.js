const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
const COMMENT_RPC = "get_public_session_comments";
const COUNT_RPC = "get_public_session_application_counts";
const POST_RPC = "create_application_comment";
const UPDATE_RPC = "update_application_comment";
const DELETE_RPC = "delete_application_comment_and_maybe_cancel";
const WITHDRAW_RPC = "cancel_my_session_application";
const GM_HISTORY_RPC = "get_gm_session_application_history";
const GM_ACCEPTED_CONTACTS_RPC = "get_gm_session_accepted_contacts";
const SET_APPLICATION_STATUS_RPC = "set_application_status";
const ADMIN_CHECK_RPC = "is_admin";
const SESSION_GM_CHECK_RPC = "is_session_gm";
const APPLICATION_SELECT_COLUMNS = "session_id,status,created_at,updated_at,canceled_at";
const GM_APPLICATION_SELECT_COLUMNS = "id,session_id,status,comment_id,created_at,updated_at";
const COMMENT_MAX_LENGTH = 4000;
const POST_ALLOWED_STATUSES = new Set(["recruiting", "tentative"]);
const COMMENT_UPDATE_ERROR_MESSAGE = "コメントを保存できませんでした。時間をおいて再度お試しください。";
const COMMENT_UPDATE_PERMISSION_MESSAGE = "編集権限がないか、コメントの状態が変更された可能性があります。";
const COMMENT_DELETE_ERROR_MESSAGE = "コメントを削除できませんでした。時間をおいて再度お試しください。";
const COMMENT_DELETE_PERMISSION_MESSAGE = "権限がないか、コメントの状態が変更された可能性があります。";
const COMMENT_DELETE_CONFIRM_TEXT = "この参加希望コメントを削除しますか？";
const COMMENT_DELETE_CONFIRM_NOTE = "最後の有効コメントを削除した場合、参加申請が取り消されることがあります。";
const APPLICATION_WITHDRAW_ERROR_MESSAGE = "参加申請を取り下げできませんでした。時間をおいて再度お試しください。";
const APPLICATION_WITHDRAW_PERMISSION_MESSAGE = "申請状態が変更された可能性があります。ページを再読み込みしてください。";
const GM_APPLICATION_STATUS_ERROR_MESSAGE = "申請状況を更新できませんでした。状態が変更された可能性があります。";
const GM_APPLICATION_STATUS_PERMISSION_MESSAGE = "権限がないか、申請状態が変更された可能性があります。";
const WITHDRAW_ELIGIBLE_STATUSES = new Set(["pending", "waitlisted", "accepted"]);
const GM_ACTION_ALLOWED_STATUSES = new Set(["pending", "waitlisted"]);
const GM_ACTION_TARGET_STATUSES = new Set(["accepted", "rejected"]);
const panelEditStates = new WeakMap();
const panelCommentRenderContexts = new WeakMap();

const APPLICATION_STATUS_LABELS = Object.freeze({
  pending: "申請中",
  accepted: "承認済み",
  waitlisted: "申請中",
  rejected: "見送り",
  canceled: "取消済み"
});

const APPLICATION_STATUS_MESSAGES = Object.freeze({
  pending: "参加申請中です。",
  accepted: "参加予定として承認済みです。",
  waitlisted: "参加申請中です。",
  rejected: "このセッションへの申請は現在行えません。",
  canceled: "このセッションへの参加申請は取り下げ済みです。再申請する場合は、参加希望コメントを投稿してください。"
});

const GM_HISTORY_STATUS_LABELS = Object.freeze({
  pending: "申請中",
  waitlisted: "申請中",
  accepted: "承認済み",
  canceled: "辞退 / 取消",
  rejected: "却下"
});

const GM_HISTORY_GROUP_LABELS = Object.freeze({
  pending: "申請中",
  accepted: "承認済み",
  canceled: "辞退 / 取消",
  rejected: "却下",
  unknown: "その他"
});

const GM_HISTORY_GROUP_ORDER = ["pending", "accepted", "canceled", "rejected", "unknown"];

const GM_APPLICATION_INTERNAL_FIELD_NAMES = new Set([
  "id",
  "session_id",
  "status",
  "comment_id",
  "created_at",
  "updated_at"
]);

const GM_HISTORY_FIELD_NAMES = new Set([
  "display_name",
  "application_status",
  "created_at",
  "updated_at",
  "canceled_at",
  "comment_count",
  "last_comment_at"
]);

const GM_CONTACT_FIELD_NAMES = new Set([
  "display_name",
  "discord_handle"
]);

const GM_APPLICATION_STATUS_ACTION_COPY = Object.freeze({
  accepted: {
    label: "承認",
    confirmTitle: "この申請を承認しますか？",
    confirmButton: "承認する",
    progress: "承認処理中です。",
    success: "申請状況を更新しました。",
    feedback: "申請を承認しました。"
  },
  rejected: {
    label: "却下",
    confirmTitle: "この申請を却下しますか？",
    confirmButton: "却下する",
    progress: "却下処理中です。",
    success: "申請状況を更新しました。",
    feedback: "申請を却下しました。"
  }
});

const APPLICATION_WITHDRAW_UI_COPY = Object.freeze({
  pending: {
    note: "参加申請を取り下げると、コメントは残したまま申請中人数から除外されます。",
    confirmTitle: "参加申請を取り下げますか？",
    confirmNote: "コメントは履歴として残りますが、申請中人数からは除外されます。"
  },
  waitlisted: {
    note: "参加申請を取り下げると、コメントは残したまま申請中人数から除外されます。",
    confirmTitle: "参加申請を取り下げますか？",
    confirmNote: "コメントは履歴として残りますが、申請中人数からは除外されます。"
  },
  accepted: {
    note: "参加を取り下げる場合は、GMへの連絡も推奨されます。",
    confirmTitle: "承認済みの参加予定を取り下げますか？",
    confirmNote: "コメントは履歴として残りますが、参加予定からは外れます。承認済みの参加予定を取り下げる場合は、GMへの連絡も推奨されます。"
  }
});

const SENSITIVE_FIELD_NAMES = new Set([
  "access_token",
  "anon_key",
  "application_id",
  "db_password",
  "direct_connection_string",
  "discord_id",
  "discord_handle",
  "discord_name",
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

function toBooleanFlag(value) {
  return value === true;
}

function getCommentCreatedTime(comment) {
  const time = Date.parse(comment?.createdAt || "");
  return Number.isFinite(time) ? time : Number.NEGATIVE_INFINITY;
}

function getStatusLabel(status) {
  const key = String(status || "").trim().toLowerCase();
  return APPLICATION_STATUS_LABELS[key] || "申請状況未設定";
}

function getStatusClass(status) {
  const key = String(status || "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(APPLICATION_STATUS_LABELS, key) ? key : "unknown";
}

function getGmHistoryGroupKey(status) {
  const key = String(status || "").trim().toLowerCase();
  if (key === "pending" || key === "waitlisted") return "pending";
  return Object.prototype.hasOwnProperty.call(GM_HISTORY_GROUP_LABELS, key) ? key : "unknown";
}

function getGmHistoryStatusLabel(status) {
  const key = String(status || "").trim().toLowerCase();
  return GM_HISTORY_STATUS_LABELS[key] || GM_HISTORY_GROUP_LABELS.unknown;
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

function assertOnlyGmApplicationInternalFields(rows) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (!GM_APPLICATION_INTERNAL_FIELD_NAMES.has(String(key).toLowerCase())) {
        throw new Error("gm-application-field-returned");
      }
    }
  }
}

function assertOnlyGmHistoryFields(rows) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (!GM_HISTORY_FIELD_NAMES.has(String(key).toLowerCase())) {
        throw new Error("gm-history-field-returned");
      }
    }
  }
}

function assertOnlyGmContactFields(rows) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (!GM_CONTACT_FIELD_NAMES.has(String(key).toLowerCase())) {
        throw new Error("gm-contact-field-returned");
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

async function createApplicationComment(client, sessionId, body) {
  const { error } = await client.rpc(POST_RPC, {
    target_session_id: sessionId,
    comment_body: body
  });

  if (error) throw new Error("application-comment-post-failed");
}

async function updateApplicationComment(client, commentId, body) {
  const targetCommentId = String(commentId || "").trim();
  if (!targetCommentId) throw new Error("application-comment-update-target-missing");

  const { data, error } = await client.rpc(UPDATE_RPC, {
    target_comment_id: targetCommentId,
    comment_body: body
  });

  if (error) throw new Error("application-comment-update-failed");
  assertNoSensitiveFields(data);
}

async function deleteApplicationComment(client, commentId) {
  const targetCommentId = String(commentId || "").trim();
  if (!targetCommentId) throw new Error("application-comment-delete-target-missing");

  const { data, error } = await client.rpc(DELETE_RPC, {
    target_comment_id: targetCommentId
  });

  if (error) throw new Error("application-comment-delete-failed");
  assertNoSensitiveFields(data);
}

async function cancelMySessionApplication(client, sessionId) {
  const targetSessionId = String(sessionId || "").trim();
  if (!targetSessionId) throw new Error("application-withdraw-session-missing");

  const { data, error } = await client.rpc(WITHDRAW_RPC, {
    target_session_id: targetSessionId
  });

  if (error) throw new Error("application-withdraw-failed");
  assertNoSensitiveFields(data);
}

async function queryGmSessionApplications(client, sessionId) {
  const targetSessionId = String(sessionId || "").trim();
  if (!targetSessionId) throw new Error("gm-applications-session-missing");

  const { data, error } = await client
    .from("session_applications")
    .select(GM_APPLICATION_SELECT_COLUMNS)
    .eq("session_id", targetSessionId)
    .in("status", Array.from(GM_ACTION_ALLOWED_STATUSES))
    .order("created_at", { ascending: true });

  if (error) throw new Error("gm-applications-query-failed");
  const rows = Array.isArray(data) ? data : [];
  assertOnlyGmApplicationInternalFields(rows);
  return rows;
}

async function setGmApplicationStatus(client, applicationId, newStatus) {
  const targetApplicationId = String(applicationId || "").trim();
  const targetStatus = String(newStatus || "").trim().toLowerCase();
  if (!targetApplicationId) throw new Error("gm-application-target-missing");
  if (!GM_ACTION_TARGET_STATUSES.has(targetStatus)) throw new Error("gm-application-status-invalid");

  const { data, error } = await client.rpc(SET_APPLICATION_STATUS_RPC, {
    target_application_id: targetApplicationId,
    new_status: targetStatus
  });

  if (error) throw new Error("gm-application-status-update-failed");
  assertNoSensitiveFields(data);
}

async function queryGmSessionApplicationHistory(client, sessionId) {
  const targetSessionId = String(sessionId || "").trim();
  if (!targetSessionId) throw new Error("gm-history-session-missing");

  const { data, error } = await client.rpc(GM_HISTORY_RPC, {
    target_session_id: targetSessionId
  });

  if (error) throw new Error("gm-history-rpc-failed");
  const rows = Array.isArray(data) ? data : [];
  assertOnlyGmHistoryFields(rows);
  return rows;
}

async function queryGmSessionAcceptedContacts(client, sessionId) {
  const targetSessionId = String(sessionId || "").trim();
  if (!targetSessionId) throw new Error("gm-contacts-session-missing");

  const { data, error } = await client.rpc(GM_ACCEPTED_CONTACTS_RPC, {
    target_session_id: targetSessionId
  });

  if (error) throw new Error("gm-contacts-rpc-failed");
  const rows = Array.isArray(data) ? data : [];
  assertOnlyGmContactFields(rows);
  return rows;
}

async function queryBooleanRpc(client, rpcName, params) {
  const result = params ? await client.rpc(rpcName, params) : await client.rpc(rpcName);
  if (result.error) throw new Error("boolean-rpc-failed");
  return result.data === true;
}

async function queryGmHistoryAccess(client, sessionId, authState) {
  const targetSessionId = String(sessionId || "").trim();
  if (authState !== "authenticated" || !targetSessionId) return false;

  const [adminResult, gmResult] = await Promise.allSettled([
    queryBooleanRpc(client, ADMIN_CHECK_RPC),
    queryBooleanRpc(client, SESSION_GM_CHECK_RPC, {
      target_session_id: targetSessionId
    })
  ]);

  return Boolean(
    (adminResult.status === "fulfilled" && adminResult.value)
    || (gmResult.status === "fulfilled" && gmResult.value)
  );
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
    target.textContent = "参加希望コメントは公開申請欄に表示されます。個人情報や公開したくない内容は含めないでください。";
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

function getOwnApplicationStatus(ownApplication) {
  return String(ownApplication?.status || "").trim().toLowerCase();
}

function getPostContextError(options = {}) {
  if (!options.sessionId) return "対象のセッションを確認できませんでした。";
  if (!options.sessionMeta?.canApply) return "募集状態が変更された可能性があります。ページを再読み込みしてください。";
  if (options.authState !== "authenticated") return "投稿にはログインが必要です。";
  if (getOwnApplicationStatus(options.ownApplication) === "rejected") return "このセッションへの申請は現在行えません。";
  return "";
}

function validateCommentBody(value) {
  const body = String(value || "").trim();
  if (!body) {
    return {
      ok: false,
      body,
      message: "コメントを入力してください。"
    };
  }
  if (body.length > COMMENT_MAX_LENGTH) {
    return {
      ok: false,
      body,
      message: "コメントは4000文字以内で入力してください。"
    };
  }
  return {
    ok: true,
    body,
    message: ""
  };
}

function setInlineStatus(target, message, modifier = "") {
  if (!target) return;
  target.textContent = message || "";
  target.className = `session-comment-state session-comment-post-status${modifier ? ` ${modifier}` : ""}`;
  target.hidden = !message;
}

function getPanelEditState(panel) {
  return {
    activeCommentId: "",
    activeDeleteCommentId: "",
    activeGmApplicationId: "",
    activeGmApplicationStatus: "",
    isPosting: false,
    isSaving: false,
    isDeleting: false,
    isWithdrawing: false,
    isSettingGmApplicationStatus: false,
    ...(panelEditStates.get(panel) || {})
  };
}

function setPanelEditState(panel, patch = {}) {
  if (!panel) return;
  panelEditStates.set(panel, {
    ...getPanelEditState(panel),
    ...patch
  });
}

function clearPanelEditMode(panel) {
  setPanelEditState(panel, {
    activeCommentId: "",
    isSaving: false
  });
}

function clearPanelDeleteMode(panel) {
  setPanelEditState(panel, {
    activeDeleteCommentId: "",
    isDeleting: false
  });
}

function clearGmApplicationStatusMode(panel) {
  setPanelEditState(panel, {
    activeGmApplicationId: "",
    activeGmApplicationStatus: "",
    isSettingGmApplicationStatus: false
  });
}

function isPanelBusy(panel) {
  const state = getPanelEditState(panel);
  return Boolean(
    state.isPosting
    || state.isSaving
    || state.isDeleting
    || state.isWithdrawing
    || state.isSettingGmApplicationStatus
  );
}

function setRenderedOperationButtonsDisabled(panel, disabled) {
  if (!panel) return;
  panel.querySelectorAll(
    [
      "[data-session-comment-edit-action]",
      "[data-session-comment-delete-action]",
      "[data-session-comment-delete-confirm-action]",
      "[data-session-gm-application-action]",
      "[data-session-gm-application-confirm-action]"
    ].join(", ")
  ).forEach((button) => {
    button.disabled = disabled;
  });
}

function setRenderedPostFormControlsDisabled(panel, disabled) {
  if (!panel) return;
  panel.querySelectorAll(".session-comment-form textarea, .session-comment-form button").forEach((control) => {
    control.disabled = disabled;
  });
}

function rerenderPanelComments(panel) {
  const context = panelCommentRenderContexts.get(panel);
  if (!context) return;
  renderComments(context.target, context.rows, context.options);
}

function appendCommentForm(target, options = {}) {
  const form = document.createElement("form");
  form.className = "session-comment-form";
  form.noValidate = true;

  const field = document.createElement("label");
  field.className = "session-comment-field";

  const labelText = document.createElement("span");
  labelText.textContent = "参加希望コメント";

  const textarea = document.createElement("textarea");
  textarea.className = "session-comment-textarea";
  textarea.name = "application-comment";
  textarea.rows = 4;
  textarea.placeholder = "参加希望や連絡事項を入力してください。";

  field.append(labelText, textarea);

  const guidance = document.createElement("p");
  guidance.className = "session-comment-form-guidance";
  guidance.textContent = "コメント投稿時点で参加申請として扱われます。複数コメントしても申請人数は重複してカウントされません。申請を辞退する場合は、自分が投稿したコメントをすべて削除するか、辞退する旨のコメントを残したうえで申請取り下げ操作を行ってください。";

  const button = document.createElement("button");
  button.className = "session-application-button session-comment-button";
  button.type = "submit";
  button.disabled = true;
  button.textContent = "参加希望コメントを送信";

  const status = document.createElement("p");
  status.setAttribute("aria-live", "polite");
  setInlineStatus(status, "");

  let isSubmitting = false;
  const baseContextError = getPostContextError(options);

  const updateAvailability = (showValidation = false) => {
    const validation = validateCommentBody(textarea.value);
    const busy = isPanelBusy(options.panel);
    button.disabled = isSubmitting || busy || Boolean(baseContextError) || !validation.ok;

    if (baseContextError) {
      setInlineStatus(status, baseContextError, "is-error");
      return;
    }

    if (showValidation && textarea.value.length > 0 && !validation.ok) {
      setInlineStatus(status, validation.message, "is-error");
      return;
    }

    if (!isSubmitting) {
      setInlineStatus(status, "");
    }
  };

  textarea.addEventListener("input", () => updateAvailability(true));

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (isSubmitting) return;

    if (isPanelBusy(options.panel)) {
      setInlineStatus(status, "別の操作を処理中です。完了後にお試しください。", "is-warn");
      return;
    }

    const contextError = getPostContextError(options);
    if (contextError) {
      updateAvailability(false);
      setInlineStatus(status, contextError, "is-error");
      return;
    }

    const validation = validateCommentBody(textarea.value);
    if (!validation.ok) {
      updateAvailability(false);
      setInlineStatus(status, validation.message, "is-error");
      return;
    }

    isSubmitting = true;
    setPanelEditState(options.panel, { isPosting: true });
    setRenderedOperationButtonsDisabled(options.panel, true);
    form.setAttribute("aria-busy", "true");
    textarea.disabled = true;
    button.disabled = true;
    setInlineStatus(status, "送信中です。", "is-warn");

    try {
      await createApplicationComment(options.client, options.sessionId, validation.body);
      textarea.value = "";
      setInlineStatus(status, "送信しました。表示を更新しています。", "is-ok");
      setPanelEditState(options.panel, { isPosting: false });
      await refreshPanel(options.panel, options.sessionId, {
        feedbackMessage: "参加希望コメントを送信しました。",
        feedbackModifier: "is-ok"
      });
    } catch {
      isSubmitting = false;
      setPanelEditState(options.panel, { isPosting: false });
      rerenderPanelComments(options.panel);
      form.removeAttribute("aria-busy");
      textarea.disabled = false;
      updateAvailability(false);
      setInlineStatus(
        status,
        "参加希望コメントを送信できませんでした。募集状態が変更された可能性があります。ページを再読み込みしてください。",
        "is-error"
      );
    }
  });

  if (baseContextError) {
    textarea.disabled = true;
  }

  updateAvailability(false);
  form.append(field, guidance, button, status);
  target.append(form);
}

function getOwnApplicationMessage(ownApplication) {
  const status = getOwnApplicationStatus(ownApplication);
  if (!status) return "参加希望コメントを投稿できます。";
  return APPLICATION_STATUS_MESSAGES[status] || "申請状態を確認しました。参加希望コメントを送信できます。";
}

function shouldShowCommentForm(ownApplication) {
  return getOwnApplicationStatus(ownApplication) !== "rejected";
}

function shouldShowWithdrawUi(ownApplication) {
  return WITHDRAW_ELIGIBLE_STATUSES.has(getOwnApplicationStatus(ownApplication));
}

function canStartApplicationWithdraw(options = {}) {
  const state = getPanelEditState(options.panel);
  return Boolean(
    options.client
    && typeof options.client.rpc === "function"
    && options.authState === "authenticated"
    && String(options.sessionId || "").trim()
    && WITHDRAW_ELIGIBLE_STATUSES.has(getOwnApplicationStatus(options.ownApplication))
    && !state.activeCommentId
    && !state.activeDeleteCommentId
    && !state.isPosting
    && !state.isSaving
    && !state.isDeleting
    && !state.isWithdrawing
  );
}

function appendApplicationWithdrawUi(target, ownApplication, options = {}) {
  const status = getOwnApplicationStatus(ownApplication);
  if (!shouldShowWithdrawUi(ownApplication)) return;

  const copy = APPLICATION_WITHDRAW_UI_COPY[status] || APPLICATION_WITHDRAW_UI_COPY.pending;
  const withdrawOptions = { ...options, ownApplication };
  const container = document.createElement("div");
  container.className = `session-application-withdraw is-${status}`;
  container.setAttribute("role", "group");
  container.setAttribute("aria-label", "参加申請取り下げUI");

  const note = document.createElement("p");
  note.className = "session-application-withdraw-note";
  note.textContent = copy.note;

  const openButton = document.createElement("button");
  openButton.className = "session-application-button session-comment-button session-application-withdraw-open";
  openButton.type = "button";
  openButton.textContent = "参加申請を取り下げる";
  openButton.setAttribute("aria-expanded", "false");

  const confirm = document.createElement("div");
  confirm.className = "session-application-withdraw-confirm";
  confirm.hidden = true;
  confirm.setAttribute("role", "group");
  confirm.setAttribute("aria-label", "参加申請取り下げ確認");

  const title = document.createElement("p");
  title.className = "session-application-withdraw-confirm-title";
  title.textContent = copy.confirmTitle;

  const confirmNote = document.createElement("p");
  confirmNote.className = "session-application-withdraw-confirm-note";
  confirmNote.textContent = copy.confirmNote;

  const inlineStatus = document.createElement("p");
  inlineStatus.setAttribute("aria-live", "polite");
  setInlineStatus(inlineStatus, "");

  const actions = document.createElement("div");
  actions.className = "session-application-withdraw-actions";

  const confirmButton = document.createElement("button");
  confirmButton.className = "session-application-button session-comment-button session-application-withdraw-confirm-button";
  confirmButton.type = "button";
  confirmButton.textContent = "取り下げる";

  const cancelButton = document.createElement("button");
  cancelButton.className = "session-application-button session-comment-button session-application-withdraw-cancel";
  cancelButton.type = "button";
  cancelButton.textContent = "キャンセル";

  let isWithdrawing = Boolean(getPanelEditState(options.panel).isWithdrawing);

  const updateAvailability = () => {
    const canStart = canStartApplicationWithdraw(withdrawOptions);
    openButton.disabled = isWithdrawing || !canStart;
    confirmButton.disabled = isWithdrawing || !canStart;
    cancelButton.disabled = isWithdrawing;
  };

  openButton.addEventListener("click", () => {
    updateAvailability();
    if (openButton.disabled) return;
    const willOpen = confirm.hidden;
    confirm.hidden = !willOpen;
    openButton.setAttribute("aria-expanded", String(willOpen));
    setRenderedOperationButtonsDisabled(options.panel, willOpen);
    if (!willOpen) {
      setRenderedOperationButtonsDisabled(options.panel, isPanelBusy(options.panel));
      setInlineStatus(inlineStatus, "");
    }
  });

  cancelButton.addEventListener("click", () => {
    if (isWithdrawing) return;
    confirm.hidden = true;
    openButton.setAttribute("aria-expanded", "false");
    setRenderedOperationButtonsDisabled(options.panel, isPanelBusy(options.panel));
    setInlineStatus(inlineStatus, "");
  });

  confirmButton.addEventListener("click", async () => {
    if (isWithdrawing) return;

    if (!canStartApplicationWithdraw(withdrawOptions)) {
      setInlineStatus(inlineStatus, APPLICATION_WITHDRAW_PERMISSION_MESSAGE, "is-error");
      updateAvailability();
      return;
    }

    isWithdrawing = true;
    setPanelEditState(options.panel, { isWithdrawing: true });
    setRenderedOperationButtonsDisabled(options.panel, true);
    setRenderedPostFormControlsDisabled(options.panel, true);
    confirm.setAttribute("aria-busy", "true");
    updateAvailability();
    setInlineStatus(inlineStatus, "取り下げ中です。", "is-warn");

    try {
      await cancelMySessionApplication(options.client, options.sessionId);
      setInlineStatus(inlineStatus, "参加申請を取り下げました。表示を更新しています。", "is-ok");
      setPanelEditState(options.panel, {
        activeCommentId: "",
        activeDeleteCommentId: "",
        isWithdrawing: false
      });
      await refreshPanel(options.panel, options.sessionId, {
        feedbackMessage: "参加申請を取り下げました。",
        feedbackModifier: "is-ok"
      });
    } catch {
      isWithdrawing = false;
      setPanelEditState(options.panel, { isWithdrawing: false });
      await refreshPanel(options.panel, options.sessionId, {
        feedbackMessage: APPLICATION_WITHDRAW_ERROR_MESSAGE,
        feedbackModifier: "is-error"
      });
    }
  });

  updateAvailability();
  actions.append(confirmButton, cancelButton);
  confirm.append(title, confirmNote, actions, inlineStatus);
  container.append(note, openButton, confirm);
  target.append(container);
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
  const status = getOwnApplicationStatus(options.ownApplication);
  target.append(createStateMessage(message, status === "rejected" ? "is-warn" : "is-ok"));

  appendApplicationWithdrawUi(target, options.ownApplication, options);

  if (options.feedbackMessage) {
    target.append(createStateMessage(options.feedbackMessage, options.feedbackModifier || ""));
  }

  if (shouldShowCommentForm(options.ownApplication)) {
    appendCommentForm(target, options);
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

function setGmHistoryState(target, message, modifier = "") {
  if (!target) return;
  target.replaceChildren();
  const paragraph = createStateMessage(message, modifier);
  paragraph.classList.add("session-gm-history-state");
  target.append(paragraph);
}

function getGmHistoryActivityTime(row) {
  const updatedAt = Date.parse(row?.updatedAt || "");
  if (Number.isFinite(updatedAt)) return updatedAt;
  const createdAt = Date.parse(row?.createdAt || "");
  return Number.isFinite(createdAt) ? createdAt : Number.NEGATIVE_INFINITY;
}

function normalizeGmHistoryRows(rows) {
  return rows.map((row) => {
    const applicationStatus = String(row?.application_status || "").trim().toLowerCase();
    return {
      displayName: redactSensitiveText(row?.display_name).trim() || "名前未設定",
      applicationStatus,
      groupKey: getGmHistoryGroupKey(applicationStatus),
      statusLabel: getGmHistoryStatusLabel(applicationStatus),
      createdAt: String(row?.created_at || "").trim(),
      updatedAt: String(row?.updated_at || "").trim(),
      canceledAt: String(row?.canceled_at || "").trim(),
      commentCount: toCount(row?.comment_count),
      lastCommentAt: String(row?.last_comment_at || "").trim()
    };
  }).sort((a, b) => {
    const groupDiff = GM_HISTORY_GROUP_ORDER.indexOf(a.groupKey) - GM_HISTORY_GROUP_ORDER.indexOf(b.groupKey);
    if (groupDiff !== 0) return groupDiff;
    return getGmHistoryActivityTime(b) - getGmHistoryActivityTime(a);
  });
}

function normalizeGmApplicationActionRows(rows, publicCommentRows) {
  const commentsById = new Map();
  for (const comment of normalizeComments(Array.isArray(publicCommentRows) ? publicCommentRows : [])) {
    if (comment.commentId) commentsById.set(comment.commentId, comment);
  }

  const actionRows = [];
  let skippedUnsafeCount = 0;

  for (const row of rows) {
    const applicationId = String(row?.id || "").trim();
    const applicationStatus = String(row?.status || "").trim().toLowerCase();
    const commentId = String(row?.comment_id || "").trim();
    const comment = commentId ? commentsById.get(commentId) : null;
    const displayName = comment?.displayName || "";

    if (!applicationId || !GM_ACTION_ALLOWED_STATUSES.has(applicationStatus)) continue;
    if (!displayName) {
      skippedUnsafeCount += 1;
      continue;
    }

    actionRows.push({
      applicationId,
      displayName,
      applicationStatus,
      groupKey: getGmHistoryGroupKey(applicationStatus),
      statusLabel: getGmHistoryStatusLabel(applicationStatus),
      createdAt: String(row?.created_at || "").trim(),
      updatedAt: String(row?.updated_at || "").trim()
    });
  }

  actionRows.sort((a, b) => getGmHistoryActivityTime(b) - getGmHistoryActivityTime(a));
  return { actionRows, skippedUnsafeCount };
}

function toSingleLineText(value) {
  return String(value ?? "").replace(/[\r\n]+/g, " ").trim();
}

function normalizeGmContactRows(rows) {
  return rows.map((row) => ({
    displayName: redactSensitiveText(row?.display_name).trim() || "名前未設定",
    discordHandle: toSingleLineText(row?.discord_handle)
  })).sort((a, b) => a.displayName.localeCompare(b.displayName, "ja"));
}

function formatGmContactCopyText(rows) {
  return rows
    .map((row) => `${row.displayName}: ${row.discordHandle || "未登録"}`)
    .join("\n");
}

async function writeClipboardText(text) {
  if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch {
      // Fall through to the textarea copy path for browsers without clipboard permission.
    }
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.inset = "0 auto auto 0";
  textarea.style.width = "1px";
  textarea.style.height = "1px";
  textarea.style.opacity = "0";
  document.body.append(textarea);
  textarea.select();

  try {
    if (!document.execCommand("copy")) {
      throw new Error("clipboard-copy-failed");
    }
  } finally {
    textarea.remove();
  }
}

function appendGmHistoryMetaRow(target, label, value) {
  const text = String(value || "").trim();
  if (!text) return;

  const item = document.createElement("div");
  const term = document.createElement("dt");
  const description = document.createElement("dd");

  term.textContent = label;
  description.textContent = text;
  item.append(term, description);
  target.append(item);
}

function createGmHistoryItem(row) {
  const item = document.createElement("li");
  item.className = `session-gm-history-item is-${row.groupKey}`;

  const header = document.createElement("div");
  header.className = "session-gm-history-item-head";

  const name = document.createElement("strong");
  name.className = "session-gm-history-name";
  name.textContent = row.displayName;

  const status = document.createElement("span");
  status.className = `session-comment-status-badge session-gm-history-status is-${row.groupKey}`;
  status.textContent = row.statusLabel;

  header.append(name, status);

  const meta = document.createElement("dl");
  meta.className = "session-gm-history-meta";

  appendGmHistoryMetaRow(meta, "申請", formatDateTime(row.createdAt));
  appendGmHistoryMetaRow(meta, "更新", formatDateTime(row.updatedAt));
  appendGmHistoryMetaRow(meta, "辞退 / 取消", formatDateTime(row.canceledAt));
  appendGmHistoryMetaRow(meta, "有効コメント", `${row.commentCount}件`);
  appendGmHistoryMetaRow(meta, "最終コメント", formatDateTime(row.lastCommentAt));

  item.append(header, meta);
  return item;
}

function getGmApplicationStatusCopy(newStatus) {
  return GM_APPLICATION_STATUS_ACTION_COPY[newStatus] || GM_APPLICATION_STATUS_ACTION_COPY.accepted;
}

function canUseGmApplicationStatusAction(row, options = {}, newStatus = "") {
  return Boolean(
    options.client
    && typeof options.client.rpc === "function"
    && options.authState === "authenticated"
    && String(options.sessionId || "").trim()
    && row?.applicationId
    && GM_ACTION_ALLOWED_STATUSES.has(row.applicationStatus)
    && GM_ACTION_TARGET_STATUSES.has(newStatus)
  );
}

function canOpenGmApplicationStatusConfirm(row, options = {}, newStatus = "") {
  const state = getPanelEditState(options.panel);
  return Boolean(
    canUseGmApplicationStatusAction(row, options, newStatus)
    && !state.activeCommentId
    && !state.activeDeleteCommentId
    && !state.activeGmApplicationId
    && !state.isPosting
    && !state.isSaving
    && !state.isDeleting
    && !state.isWithdrawing
    && !state.isSettingGmApplicationStatus
  );
}

function canConfirmGmApplicationStatus(row, options = {}, newStatus = "") {
  const state = getPanelEditState(options.panel);
  return Boolean(
    canUseGmApplicationStatusAction(row, options, newStatus)
    && state.activeGmApplicationId === row.applicationId
    && state.activeGmApplicationStatus === newStatus
    && !state.isPosting
    && !state.isSaving
    && !state.isDeleting
    && !state.isWithdrawing
    && !state.isSettingGmApplicationStatus
  );
}

function appendGmApplicationStatusConfirm(item, row, target, historyRows, options = {}, newStatus = "") {
  const copy = getGmApplicationStatusCopy(newStatus);
  const confirm = document.createElement("div");
  confirm.className = `session-gm-application-confirm is-${newStatus}`;
  confirm.setAttribute("role", "group");
  confirm.setAttribute("aria-label", `${copy.label}確認`);

  const title = document.createElement("p");
  title.className = "session-gm-application-confirm-title";
  title.textContent = copy.confirmTitle;

  const targetName = document.createElement("p");
  targetName.className = "session-gm-application-confirm-target";
  targetName.textContent = row.displayName;

  const actions = document.createElement("div");
  actions.className = "session-gm-application-confirm-actions";

  const confirmButton = document.createElement("button");
  confirmButton.className = `session-application-button session-comment-button session-gm-application-confirm-button is-${newStatus}`;
  confirmButton.type = "button";
  confirmButton.textContent = copy.confirmButton;
  confirmButton.dataset.sessionGmApplicationConfirmAction = "true";

  const cancelButton = document.createElement("button");
  cancelButton.className = "session-application-button session-comment-button session-gm-application-cancel";
  cancelButton.type = "button";
  cancelButton.textContent = "キャンセル";
  cancelButton.dataset.sessionGmApplicationConfirmAction = "true";

  actions.append(confirmButton, cancelButton);

  const status = document.createElement("p");
  status.setAttribute("aria-live", "polite");
  setInlineStatus(status, "");

  let isUpdating = Boolean(getPanelEditState(options.panel).isSettingGmApplicationStatus);

  const updateAvailability = () => {
    const canConfirm = canConfirmGmApplicationStatus(row, options, newStatus);
    confirmButton.disabled = isUpdating || !canConfirm;
    cancelButton.disabled = isUpdating;
  };

  cancelButton.addEventListener("click", () => {
    if (isUpdating) return;
    clearGmApplicationStatusMode(options.panel);
    renderGmHistoryRows(target, historyRows, options);
  });

  confirmButton.addEventListener("click", async () => {
    if (isUpdating) return;

    if (!canConfirmGmApplicationStatus(row, options, newStatus)) {
      setInlineStatus(status, GM_APPLICATION_STATUS_PERMISSION_MESSAGE, "is-error");
      updateAvailability();
      return;
    }

    isUpdating = true;
    setPanelEditState(options.panel, { isSettingGmApplicationStatus: true });
    setRenderedOperationButtonsDisabled(options.panel, true);
    setRenderedPostFormControlsDisabled(options.panel, true);
    confirm.setAttribute("aria-busy", "true");
    updateAvailability();
    setInlineStatus(status, copy.progress, "is-warn");

    try {
      await setGmApplicationStatus(options.client, row.applicationId, newStatus);
      setInlineStatus(status, `${copy.success}表示を更新しています。`, "is-ok");
      clearGmApplicationStatusMode(options.panel);
      await refreshPanel(options.panel, options.sessionId, {
        openGmHistory: true,
        gmFeedbackMessage: copy.feedback,
        gmFeedbackModifier: "is-ok"
      });
    } catch {
      clearGmApplicationStatusMode(options.panel);
      await refreshPanel(options.panel, options.sessionId, {
        openGmHistory: true,
        gmFeedbackMessage: GM_APPLICATION_STATUS_ERROR_MESSAGE,
        gmFeedbackModifier: "is-error"
      });
    }
  });

  updateAvailability();
  confirm.append(title, targetName, actions, status);
  item.append(confirm);
}

function createGmApplicationActionItem(row, target, historyRows, options = {}) {
  const item = document.createElement("li");
  item.className = `session-gm-application-action-item is-${row.groupKey}`;

  const header = document.createElement("div");
  header.className = "session-gm-history-item-head";

  const name = document.createElement("strong");
  name.className = "session-gm-history-name";
  name.textContent = row.displayName;

  const status = document.createElement("span");
  status.className = `session-comment-status-badge session-gm-history-status is-${row.groupKey}`;
  status.textContent = row.statusLabel;

  header.append(name, status);

  const meta = document.createElement("dl");
  meta.className = "session-gm-history-meta";
  appendGmHistoryMetaRow(meta, "申請", formatDateTime(row.createdAt));
  appendGmHistoryMetaRow(meta, "更新", formatDateTime(row.updatedAt));

  const actions = document.createElement("div");
  actions.className = "session-gm-application-actions";

  for (const targetStatus of GM_ACTION_TARGET_STATUSES) {
    const copy = getGmApplicationStatusCopy(targetStatus);
    const button = document.createElement("button");
    button.className = `session-application-button session-comment-button session-gm-application-action-button is-${targetStatus}`;
    button.type = "button";
    button.textContent = copy.label;
    button.dataset.sessionGmApplicationAction = "true";
    button.disabled = !canOpenGmApplicationStatusConfirm(row, options, targetStatus);
    button.addEventListener("click", () => {
      if (!canOpenGmApplicationStatusConfirm(row, options, targetStatus)) return;
      setPanelEditState(options.panel, {
        activeGmApplicationId: row.applicationId,
        activeGmApplicationStatus: targetStatus,
        isSettingGmApplicationStatus: false
      });
      renderGmHistoryRows(target, historyRows, options);
    });
    actions.append(button);
  }

  item.append(header, meta, actions);

  const editState = getPanelEditState(options.panel);
  if (editState.activeGmApplicationId === row.applicationId) {
    appendGmApplicationStatusConfirm(item, row, target, historyRows, options, editState.activeGmApplicationStatus);
  }

  return item;
}

function appendGmApplicationActionsSection(fragment, target, historyRows, options = {}) {
  const actionRows = Array.isArray(options.gmApplicationActions?.actionRows)
    ? options.gmApplicationActions.actionRows
    : [];
  const skippedUnsafeCount = Number(options.gmApplicationActions?.skippedUnsafeCount || 0);
  const operationLoadFailed = Boolean(options.gmApplicationActionsLoadFailed);

  const section = document.createElement("section");
  section.className = "session-gm-history-group session-gm-application-action-group";

  const title = document.createElement("h4");
  title.className = "session-gm-history-group-title";
  title.textContent = "申請中の操作";

  section.append(title);

  if (operationLoadFailed) {
    section.append(createStateMessage("承認 / 却下操作を準備できませんでした。", "is-error"));
    fragment.append(section);
    return;
  }

  if (actionRows.length) {
    const list = document.createElement("ul");
    list.className = "session-gm-history-list session-gm-application-action-list";
    for (const row of actionRows) {
      list.append(createGmApplicationActionItem(row, target, historyRows, options));
    }
    section.append(list);
    fragment.append(section);
    return;
  }

  const message = skippedUnsafeCount > 0
    ? "対象を安全に確認できない申請があるため、操作ボタンを表示していません。"
    : "承認 / 却下できる申請はありません。";
  section.append(createStateMessage(message, skippedUnsafeCount > 0 ? "is-warn" : "is-empty"));
  fragment.append(section);
}

function renderGmHistoryRows(target, rows, options = {}) {
  if (!target) return;
  const historyRows = normalizeGmHistoryRows(rows);
  target.replaceChildren();

  if (options.gmFeedbackMessage) {
    const feedback = createStateMessage(options.gmFeedbackMessage, options.gmFeedbackModifier || "");
    feedback.classList.add("session-gm-history-state");
    target.append(feedback);
  }

  const groupedRows = new Map();
  for (const row of historyRows) {
    const group = groupedRows.get(row.groupKey) || [];
    group.push(row);
    groupedRows.set(row.groupKey, group);
  }

  const fragment = document.createDocumentFragment();
  appendGmApplicationActionsSection(fragment, target, rows, options);

  if (!historyRows.length) {
    const empty = createStateMessage("申請履歴はまだありません。", "is-empty");
    empty.classList.add("session-gm-history-state");
    fragment.append(empty);
    target.append(fragment);
    return;
  }

  for (const groupKey of GM_HISTORY_GROUP_ORDER) {
    const group = groupedRows.get(groupKey);
    if (!group?.length) continue;

    const section = document.createElement("section");
    section.className = `session-gm-history-group is-${groupKey}`;

    const title = document.createElement("h4");
    title.className = "session-gm-history-group-title";
    title.textContent = GM_HISTORY_GROUP_LABELS[groupKey];

    const list = document.createElement("ul");
    list.className = "session-gm-history-list";
    for (const row of group) {
      list.append(createGmHistoryItem(row));
    }

    section.append(title, list);
    fragment.append(section);
  }

  target.append(fragment);
}

function setGmContactState(target, message, modifier = "") {
  if (!target) return;
  target.replaceChildren();
  const paragraph = createStateMessage(message, modifier);
  paragraph.classList.add("session-gm-contact-state");
  target.append(paragraph);
}

function createGmContactItem(row) {
  const item = document.createElement("li");
  item.className = "session-gm-contact-item";

  const name = document.createElement("strong");
  name.className = "session-gm-contact-name";
  name.textContent = row.displayName;

  const value = document.createElement("span");
  value.className = `session-gm-contact-value${row.discordHandle ? "" : " is-missing"}`;
  value.textContent = row.discordHandle || "未登録";

  item.append(name, value);
  return item;
}

function renderGmContactRows(target, rows) {
  if (!target) return;
  const contactRows = normalizeGmContactRows(rows);
  target.replaceChildren();

  if (!contactRows.length) {
    const empty = createStateMessage("承認済み参加者はまだいません", "is-empty");
    empty.classList.add("session-gm-contact-state");
    target.append(empty);
    return;
  }

  const list = document.createElement("ul");
  list.className = "session-gm-contact-list";
  for (const row of contactRows) {
    list.append(createGmContactItem(row));
  }

  const actions = document.createElement("div");
  actions.className = "session-gm-contact-actions";

  const copyButton = document.createElement("button");
  copyButton.className = "session-application-button session-comment-button session-gm-contact-copy-button";
  copyButton.type = "button";
  copyButton.textContent = "連絡先一覧をコピー";

  const status = document.createElement("p");
  status.setAttribute("aria-live", "polite");
  setInlineStatus(status, "");

  copyButton.addEventListener("click", async () => {
    copyButton.disabled = true;
    setInlineStatus(status, "");

    try {
      await writeClipboardText(formatGmContactCopyText(contactRows));
      setInlineStatus(status, "コピーしました", "is-ok");
    } catch {
      setInlineStatus(status, "コピーできませんでした", "is-error");
    } finally {
      copyButton.disabled = false;
    }
  });

  actions.append(copyButton, status);
  target.append(list, actions);
}

function createGmContactControl(options = {}) {
  const details = document.createElement("details");
  details.className = "session-gm-contact-details";

  const summary = document.createElement("summary");
  summary.className = "session-gm-contact-summary";
  summary.textContent = "GM向け：承認済み参加者連絡先";

  const body = document.createElement("div");
  body.className = "session-gm-contact-body";

  let hasLoaded = false;
  let isLoading = false;

  const loadGmContacts = async () => {
    if (!details.open || hasLoaded || isLoading) return;

    isLoading = true;
    setGmContactState(body, "読み込み中", "is-warn");

    try {
      const rows = await queryGmSessionAcceptedContacts(options.client, options.sessionId);
      renderGmContactRows(body, rows);
      hasLoaded = true;
    } catch {
      setGmContactState(body, "連絡先を取得できませんでした", "is-error");
    } finally {
      isLoading = false;
    }
  };

  details.addEventListener("toggle", () => {
    void loadGmContacts();
  });

  details.append(summary, body);
  return details;
}

function renderGmHistoryControl(target, canView, options = {}) {
  if (!target) return;
  target.replaceChildren();
  target.hidden = !canView;

  if (!canView) return;

  const details = document.createElement("details");
  details.className = "session-gm-history-details";

  const summary = document.createElement("summary");
  summary.className = "session-gm-history-summary";
  summary.textContent = "GM向け：申請履歴を見る";

  const body = document.createElement("div");
  body.className = "session-gm-history-body";

  let hasLoaded = false;
  let isLoading = false;

  const loadGmHistory = async () => {
    if (!details.open || hasLoaded || isLoading) return;

    isLoading = true;
    setGmHistoryState(body, "申請履歴を読み込んでいます。", "is-warn");

    try {
      const [historyResult, applicationsResult] = await Promise.allSettled([
        queryGmSessionApplicationHistory(options.client, options.sessionId),
        queryGmSessionApplications(options.client, options.sessionId)
      ]);

      if (historyResult.status !== "fulfilled") {
        throw new Error("gm-history-rpc-failed");
      }

      const gmApplicationActions = applicationsResult.status === "fulfilled"
        ? normalizeGmApplicationActionRows(applicationsResult.value, options.publicCommentRows)
        : { actionRows: [], skippedUnsafeCount: 0 };

      renderGmHistoryRows(body, historyResult.value, {
        ...options,
        gmApplicationActions,
        gmApplicationActionsLoadFailed: applicationsResult.status !== "fulfilled"
      });
      hasLoaded = true;
    } catch {
      setGmHistoryState(body, "申請履歴を取得できませんでした。", "is-error");
    } finally {
      isLoading = false;
    }
  };

  details.addEventListener("toggle", () => {
    void loadGmHistory();
  });

  details.append(summary, body);
  target.append(details, createGmContactControl(options));

  if (options.openOnLoad) {
    details.open = true;
    void loadGmHistory();
  }
}

function normalizeComments(rows) {
  return rows.map((row) => {
    const isOwn = toBooleanFlag(row?.is_own);
    return {
      commentId: String(row?.comment_id || "").trim(),
      displayName: redactSensitiveText(row?.display_name).trim() || "名前未設定",
      body: redactSensitiveText(row?.body).trim() || "本文なし",
      applicationStatus: String(row?.application_status || "").trim(),
      createdAt: String(row?.created_at || "").trim(),
      updatedAt: String(row?.updated_at || "").trim(),
      editedAt: String(row?.edited_at || "").trim(),
      isOwn,
      canEdit: toBooleanFlag(row?.can_edit),
      canDelete: toBooleanFlag(row?.can_delete)
    };
  }).sort((a, b) => {
    const aTime = getCommentCreatedTime(a);
    const bTime = getCommentCreatedTime(b);
    if (aTime === bTime) return 0;
    return bTime > aTime ? 1 : -1;
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

function canStartCommentEdit(comment, options = {}) {
  const editState = getPanelEditState(options.panel);
  return Boolean(
    options.authState === "authenticated"
    && comment.canEdit
    && comment.commentId
    && !editState.activeCommentId
    && !editState.activeDeleteCommentId
    && !isPanelBusy(options.panel)
  );
}

function canStartCommentDelete(comment, options = {}) {
  const editState = getPanelEditState(options.panel);
  return Boolean(
    options.authState === "authenticated"
    && comment.canDelete
    && comment.commentId
    && !editState.activeCommentId
    && !editState.activeDeleteCommentId
    && !isPanelBusy(options.panel)
  );
}

function appendCommentEditForm(item, comment, rows, target, options = {}) {
  const form = document.createElement("form");
  form.className = "session-comment-edit-form";
  form.noValidate = true;

  const field = document.createElement("label");
  field.className = "session-comment-field";

  const labelText = document.createElement("span");
  labelText.textContent = "コメント本文";

  const textarea = document.createElement("textarea");
  textarea.className = "session-comment-textarea session-comment-edit-textarea";
  textarea.name = "application-comment-edit";
  textarea.rows = 5;
  textarea.value = comment.body;

  field.append(labelText, textarea);

  const actions = document.createElement("div");
  actions.className = "session-comment-edit-actions";

  const saveButton = document.createElement("button");
  saveButton.className = "session-application-button session-comment-button session-comment-edit-save";
  saveButton.type = "submit";
  saveButton.textContent = "保存";

  const cancelButton = document.createElement("button");
  cancelButton.className = "session-application-button session-comment-button session-comment-edit-cancel";
  cancelButton.type = "button";
  cancelButton.textContent = "キャンセル";

  actions.append(saveButton, cancelButton);

  const status = document.createElement("p");
  status.setAttribute("aria-live", "polite");
  setInlineStatus(status, "");

  let isSaving = false;

  const updateAvailability = (showValidation = false) => {
    const validation = validateCommentBody(textarea.value);
    saveButton.disabled = isSaving || !validation.ok;
    cancelButton.disabled = isSaving;

    if (showValidation && !validation.ok) {
      setInlineStatus(status, validation.message, "is-error");
      return;
    }

    if (!isSaving) {
      setInlineStatus(status, "");
    }
  };

  textarea.addEventListener("input", () => updateAvailability(true));

  cancelButton.addEventListener("click", () => {
    if (isSaving) return;
    clearPanelEditMode(options.panel);
    renderComments(target, rows, options);
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (isSaving) return;

    if (
      options.authState !== "authenticated"
      || !comment.canEdit
      || !comment.commentId
      || isPanelBusy(options.panel)
    ) {
      setInlineStatus(status, COMMENT_UPDATE_PERMISSION_MESSAGE, "is-error");
      return;
    }

    const validation = validateCommentBody(textarea.value);
    if (!validation.ok) {
      updateAvailability(false);
      setInlineStatus(status, validation.message, "is-error");
      return;
    }

    isSaving = true;
    setPanelEditState(options.panel, { isSaving: true });
    setRenderedOperationButtonsDisabled(options.panel, true);
    form.setAttribute("aria-busy", "true");
    textarea.disabled = true;
    saveButton.disabled = true;
    cancelButton.disabled = true;
    setInlineStatus(status, "保存中です。", "is-warn");

    try {
      await updateApplicationComment(options.client, comment.commentId, validation.body);
      setInlineStatus(status, "保存しました。表示を更新しています。", "is-ok");
      clearPanelEditMode(options.panel);
      await refreshPanel(options.panel, options.sessionId, {
        feedbackMessage: "参加希望コメントを保存しました。",
        feedbackModifier: "is-ok"
      });
    } catch {
      isSaving = false;
      setPanelEditState(options.panel, { isSaving: false });
      form.removeAttribute("aria-busy");
      textarea.disabled = false;
      updateAvailability(false);
      setInlineStatus(status, COMMENT_UPDATE_ERROR_MESSAGE, "is-error");
    }
  });

  updateAvailability(false);
  form.append(field, actions, status);
  item.append(form);
}

function appendCommentDeleteConfirm(preview, comment, rows, target, options = {}) {
  const confirm = document.createElement("div");
  confirm.className = "session-comment-delete-confirm";
  confirm.setAttribute("role", "group");
  confirm.setAttribute("aria-label", "参加希望コメント削除の確認");

  const message = document.createElement("p");
  message.className = "session-comment-delete-confirm-text";
  message.textContent = COMMENT_DELETE_CONFIRM_TEXT;

  const note = document.createElement("p");
  note.className = "session-comment-delete-confirm-note";
  note.textContent = COMMENT_DELETE_CONFIRM_NOTE;

  const actions = document.createElement("div");
  actions.className = "session-comment-delete-confirm-actions";

  const deleteButton = document.createElement("button");
  deleteButton.className = "session-application-button session-comment-button session-comment-delete-confirm-button";
  deleteButton.type = "button";
  deleteButton.textContent = "削除する";
  deleteButton.dataset.sessionCommentDeleteConfirmAction = "true";

  const cancelButton = document.createElement("button");
  cancelButton.className = "session-application-button session-comment-button session-comment-delete-cancel";
  cancelButton.type = "button";
  cancelButton.textContent = "キャンセル";
  cancelButton.dataset.sessionCommentDeleteConfirmAction = "true";

  actions.append(deleteButton, cancelButton);

  const status = document.createElement("p");
  status.setAttribute("aria-live", "polite");
  setInlineStatus(status, "");

  let isDeleting = Boolean(getPanelEditState(options.panel).isDeleting);

  const updateAvailability = () => {
    deleteButton.disabled = isDeleting;
    cancelButton.disabled = isDeleting;
  };

  cancelButton.addEventListener("click", () => {
    if (isDeleting) return;
    clearPanelDeleteMode(options.panel);
    renderComments(target, rows, options);
  });

  deleteButton.addEventListener("click", async () => {
    if (isDeleting) return;

    const state = getPanelEditState(options.panel);
    if (
      options.authState !== "authenticated"
      || !comment.canDelete
      || !comment.commentId
      || state.activeDeleteCommentId !== comment.commentId
      || state.isPosting
      || state.isSaving
      || state.isWithdrawing
    ) {
      setInlineStatus(status, COMMENT_DELETE_PERMISSION_MESSAGE, "is-error");
      return;
    }

    isDeleting = true;
    setPanelEditState(options.panel, { isDeleting: true });
    setRenderedOperationButtonsDisabled(options.panel, true);
    confirm.setAttribute("aria-busy", "true");
    updateAvailability();
    setInlineStatus(status, "削除中です。", "is-warn");

    try {
      await deleteApplicationComment(options.client, comment.commentId);
      setInlineStatus(status, "削除しました。表示を更新しています。", "is-ok");
      clearPanelDeleteMode(options.panel);
      await refreshPanel(options.panel, options.sessionId, {
        feedbackMessage: "参加希望コメントを削除しました。",
        feedbackModifier: "is-ok"
      });
    } catch {
      isDeleting = false;
      setPanelEditState(options.panel, { isDeleting: false });
      confirm.removeAttribute("aria-busy");
      updateAvailability();
      setInlineStatus(status, COMMENT_DELETE_ERROR_MESSAGE, "is-error");
    }
  });

  updateAvailability();
  confirm.append(message, note, actions, status);
  preview.append(confirm);
}

function appendCommentOperationPreview(item, comment, rows, target, options = {}) {
  const showEdit = comment.canEdit;
  const showDelete = comment.canDelete;
  if (!showEdit && !showDelete) return;

  const editState = getPanelEditState(options.panel);
  const preview = document.createElement("div");
  preview.className = "session-comment-operation-preview";

  const buttons = document.createElement("div");
  buttons.className = "session-comment-operation-buttons";

  if (showEdit) {
    const editButton = document.createElement("button");
    editButton.className = "session-application-button session-comment-operation-button";
    editButton.type = "button";
    editButton.textContent = "編集";
    editButton.dataset.sessionCommentEditAction = "true";
    editButton.disabled = !canStartCommentEdit(comment, options);
    editButton.addEventListener("click", () => {
      if (!canStartCommentEdit(comment, options)) return;
      setPanelEditState(options.panel, { activeCommentId: comment.commentId, isSaving: false });
      renderComments(target, rows, options);
    });
    buttons.append(editButton);
  }

  if (showDelete) {
    const button = document.createElement("button");
    button.className = "session-application-button session-comment-operation-button session-comment-delete-button";
    button.type = "button";
    button.textContent = "削除";
    button.dataset.sessionCommentDeleteAction = "true";
    button.disabled = !canStartCommentDelete(comment, options);
    button.addEventListener("click", () => {
      if (!canStartCommentDelete(comment, options)) return;
      setPanelEditState(options.panel, { activeDeleteCommentId: comment.commentId, isDeleting: false });
      renderComments(target, rows, options);
    });
    buttons.append(button);
  }

  preview.append(buttons);

  const noteText = (() => {
    if ((showEdit || showDelete) && !comment.commentId) return "コメントを確認できませんでした。表示を更新してください。";
    return "";
  })();

  if (noteText) {
    const note = document.createElement("p");
    note.className = "session-comment-operation-note";
    note.textContent = noteText;
    preview.append(note);
  }

  if (showDelete && editState.activeDeleteCommentId === comment.commentId) {
    appendCommentDeleteConfirm(preview, comment, rows, target, options);
  }

  item.append(preview);
}

function renderComments(target, rows, options = {}) {
  if (!target) return;
  if (options.panel) {
    panelCommentRenderContexts.set(options.panel, { target, rows, options });
  }
  const comments = normalizeComments(rows);
  const editState = getPanelEditState(options.panel);
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

    const metaText = renderCommentMeta(comment);
    item.append(header);

    if (editState.activeCommentId && editState.activeCommentId === comment.commentId) {
      appendCommentEditForm(item, comment, rows, target, options);
    } else {
      const body = document.createElement("p");
      body.className = "session-comment-body";
      body.textContent = comment.body;
      item.append(body);
    }

    if (metaText) {
      const meta = document.createElement("p");
      meta.className = "session-comment-meta";
      meta.textContent = metaText;
      item.append(meta);
    }

    if (!editState.activeCommentId || editState.activeCommentId !== comment.commentId) {
      appendCommentOperationPreview(item, comment, rows, target, options);
    }
    list.append(item);
  }

  target.append(list);
}

async function refreshPanel(panel, sessionId, options = {}) {
  const countsTarget = panel.querySelector("[data-session-comment-counts]");
  const commentsTarget = panel.querySelector("[data-session-comment-list]");
  const authNote = panel.querySelector("[data-session-comment-auth-note]");
  const postTarget = panel.querySelector("[data-session-comment-post-control]");
  const gmHistoryTarget = panel.querySelector("[data-session-gm-history-control]");
  const sessionMeta = getSessionMeta(panel);

  if (!sessionId) {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderGmHistoryControl(gmHistoryTarget, false);
    renderAuthNote(authNote, "unknown");
    return;
  }

  const config = getConfig();
  if (!hasConfig(config)) {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderGmHistoryControl(gmHistoryTarget, false);
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

    if (countsResult.status === "fulfilled") {
      renderCounts(countsTarget, countsResult.value);
    } else {
      setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    }

    const authContext = authResult.status === "fulfilled" ? authResult.value : { state: "unknown", session: null };
    let ownApplication = null;
    let ownApplicationError = false;
    let canViewGmHistory = false;

    if (authContext.state === "authenticated") {
      const [ownApplicationResult, gmHistoryAccessResult] = await Promise.allSettled([
        queryOwnApplication(client, sessionId, authContext.session),
        queryGmHistoryAccess(client, sessionId, authContext.state)
      ]);

      if (ownApplicationResult.status === "fulfilled") {
        ownApplication = ownApplicationResult.value;
      } else {
        ownApplicationError = true;
      }

      if (gmHistoryAccessResult.status === "fulfilled") {
        canViewGmHistory = gmHistoryAccessResult.value;
      }
    }

    renderAuthNote(authNote, authContext.state);
    renderGmHistoryControl(gmHistoryTarget, canViewGmHistory, {
      client,
      panel,
      sessionId,
      authState: authContext.state,
      publicCommentRows: commentsResult.status === "fulfilled" ? commentsResult.value : [],
      openOnLoad: options.openGmHistory === true,
      gmFeedbackMessage: options.gmFeedbackMessage || "",
      gmFeedbackModifier: options.gmFeedbackModifier || ""
    });

    if (commentsResult.status === "fulfilled") {
      renderComments(commentsTarget, commentsResult.value, {
        client,
        panel,
        sessionId,
        authState: authContext.state
      });
    } else {
      setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    }

    renderPostControl(postTarget, {
      client,
      panel,
      sessionId,
      authState: authContext.state,
      ownApplication,
      ownApplicationError,
      sessionMeta,
      feedbackMessage: options.feedbackMessage || "",
      feedbackModifier: options.feedbackModifier || ""
    });
  } catch {
    setState(countsTarget, "申請人数の取得に失敗しました", "is-error");
    setState(commentsTarget, "参加希望コメントを取得できませんでした", "is-error");
    setState(postTarget, "投稿状態を確認できませんでした", "is-error");
    renderGmHistoryControl(gmHistoryTarget, false);
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
