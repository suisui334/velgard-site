const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
const COMMENT_RPC = "get_public_session_comments";
const COUNT_RPC = "get_public_session_application_counts";
const POST_RPC = "create_application_comment";
const UPDATE_RPC = "update_application_comment";
const DELETE_RPC = "delete_application_comment_and_maybe_cancel";
const APPLICATION_SELECT_COLUMNS = "session_id,status,created_at,updated_at,canceled_at";
const COMMENT_MAX_LENGTH = 4000;
const POST_ALLOWED_STATUSES = new Set(["recruiting", "tentative"]);
const COMMENT_UPDATE_ERROR_MESSAGE = "コメントを保存できませんでした。時間をおいて再度お試しください。";
const COMMENT_UPDATE_PERMISSION_MESSAGE = "編集権限がないか、コメントの状態が変更された可能性があります。";
const COMMENT_DELETE_ERROR_MESSAGE = "コメントを削除できませんでした。時間をおいて再度お試しください。";
const COMMENT_DELETE_PERMISSION_MESSAGE = "権限がないか、コメントの状態が変更された可能性があります。";
const COMMENT_DELETE_CONFIRM_TEXT = "この参加希望コメントを削除しますか？";
const COMMENT_DELETE_CONFIRM_NOTE = "最後の有効コメントを削除した場合、参加申請が取り消されることがあります。";
const WITHDRAW_ELIGIBLE_STATUSES = new Set(["pending", "waitlisted", "accepted"]);
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

const APPLICATION_WITHDRAW_UI_COPY = Object.freeze({
  pending: {
    note: "参加申請を取り下げる機能は次工程で実装予定です。",
    confirmTitle: "参加申請を取り下げますか？",
    confirmNote: "コメントは履歴として残りますが、申請中人数からは除外されます。"
  },
  waitlisted: {
    note: "参加申請を取り下げる機能は次工程で実装予定です。",
    confirmTitle: "参加申請を取り下げますか？",
    confirmNote: "コメントは履歴として残りますが、申請中人数からは除外されます。"
  },
  accepted: {
    note: "参加を取り下げる場合は、GMへの連絡も推奨されます。取り下げ機能は次工程で実装予定です。",
    confirmTitle: "承認済みの参加予定を取り下げますか？",
    confirmNote: "参加予定から外れます。必要ならGMへコメントで事情を伝えてください。"
  }
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
    isPosting: false,
    isSaving: false,
    isDeleting: false,
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

function isPanelBusy(panel) {
  const state = getPanelEditState(panel);
  return Boolean(state.isPosting || state.isSaving || state.isDeleting);
}

function setRenderedOperationButtonsDisabled(panel, disabled) {
  if (!panel) return;
  panel.querySelectorAll(
    "[data-session-comment-edit-action], [data-session-comment-delete-action], [data-session-comment-delete-confirm-action]"
  ).forEach((button) => {
    button.disabled = disabled;
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
  guidance.textContent = "コメント投稿時点で参加申請として扱われます。複数コメントしても申請人数は重複してカウントされません。申請を辞退する場合は、自分が投稿したコメントをすべて削除するか、辞退する旨のコメントを残したうえで申請取り下げ操作を行ってください。申請取り下げの確定処理は次工程で実装予定です。";

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
    button.disabled = isSubmitting || Boolean(baseContextError) || !validation.ok;

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

function appendApplicationWithdrawUi(target, ownApplication) {
  const status = getOwnApplicationStatus(ownApplication);
  if (!shouldShowWithdrawUi(ownApplication)) return;

  const copy = APPLICATION_WITHDRAW_UI_COPY[status] || APPLICATION_WITHDRAW_UI_COPY.pending;
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

  const disabledNote = document.createElement("p");
  disabledNote.className = "session-application-withdraw-disabled-note";
  disabledNote.textContent = "この工程では取り下げは実行されません。確定操作は次工程で実装予定です。";

  const actions = document.createElement("div");
  actions.className = "session-application-withdraw-actions";

  const confirmButton = document.createElement("button");
  confirmButton.className = "session-application-button session-comment-button session-application-withdraw-confirm-button";
  confirmButton.type = "button";
  confirmButton.textContent = "取り下げる（次工程で実装予定）";
  confirmButton.disabled = true;

  const cancelButton = document.createElement("button");
  cancelButton.className = "session-application-button session-comment-button session-application-withdraw-cancel";
  cancelButton.type = "button";
  cancelButton.textContent = "キャンセル";

  openButton.addEventListener("click", () => {
    const willOpen = confirm.hidden;
    confirm.hidden = !willOpen;
    openButton.setAttribute("aria-expanded", String(willOpen));
  });

  cancelButton.addEventListener("click", () => {
    confirm.hidden = true;
    openButton.setAttribute("aria-expanded", "false");
  });

  actions.append(confirmButton, cancelButton);
  confirm.append(title, confirmNote, disabledNote, actions);
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

  appendApplicationWithdrawUi(target, options.ownApplication);

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
