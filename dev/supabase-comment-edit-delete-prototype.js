const SESSION_COLUMNS = [
  { key: "select", label: "選択" },
  { key: "id", label: "セッションID" },
  { key: "title", label: "タイトル" },
  { key: "date", label: "日付" },
  { key: "status", label: "募集状態" },
  { key: "visibility", label: "公開範囲" },
  { key: "gm_name", label: "GM名" },
];

const COMMENT_COLUMNS = [
  { key: "select", label: "選択" },
  { key: "comment_id", label: "コメントID" },
  { key: "display_name", label: "表示名" },
  { key: "body", label: "コメント本文" },
  { key: "application_status", label: "申請状態" },
  { key: "is_application", label: "申請コメント" },
  { key: "created_at", label: "投稿日時" },
  { key: "updated_at", label: "更新日時" },
  { key: "edited_at", label: "編集日時" },
  { key: "deleted_at", label: "削除状態" },
  { key: "data_source", label: "取得元" },
];

const COUNT_COLUMNS = [
  { key: "session_id", label: "セッションID" },
  { key: "accepted_count", label: "承認済み人数" },
  { key: "pending_count", label: "申請中人数" },
  { key: "waitlisted_count", label: "待機人数" },
];

const DELETE_RESULT_COLUMNS = [
  { key: "deleted_comment_id", label: "削除コメントID" },
  { key: "affected_session_id", label: "対象セッションID" },
  { key: "application_status", label: "削除後の申請状態" },
  { key: "application_canceled", label: "取消扱いになったか" },
  { key: "active_application_comment_count", label: "残っている有効申請コメント数" },
];

const EDIT_RESULT_COLUMNS = [
  { key: "comment_id", label: "コメントID" },
  { key: "session_id", label: "セッションID" },
  { key: "edited_at", label: "編集日時" },
];

const STATUS_LABELS = {
  recruiting: "募集中",
  tentative: "仮募集",
  full: "満席",
  closed: "締切",
  finished: "終了",
  canceled: "取消済み",
  pending: "申請中",
  accepted: "承認済み",
  rejected: "却下",
  waitlisted: "待機",
};

const VISIBILITY_LABELS = {
  public: "公開",
  private: "非公開",
  hidden: "非表示",
};

const SENSITIVE_FIELD_NAMES = new Set([
  "gm_user_id",
  "gmUserId",
  "user_id",
  "userId",
  "discord_user_id",
  "discordUserId",
  "discordThreadUrl",
  "email",
  "role",
  "access_token",
  "refresh_token",
  "token",
  "password",
]);

const $ = (selector) => document.querySelector(selector);

const refs = {
  url: $("#supabase-url"),
  key: $("#supabase-key"),
  email: $("#login-email"),
  password: $("#login-password"),
  checkState: $("#check-state"),
  loadSessions: $("#load-sessions"),
  clear: $("#clear-inputs"),
  login: $("#login"),
  logout: $("#logout"),
  publicSessions: $("#public-sessions-result"),
  gmSessions: $("#gm-sessions-result"),
  selectedSession: $("#selected-session-result"),
  reloadComments: $("#reload-comments"),
  comments: $("#comments-result"),
  selectedComment: $("#selected-comment-result"),
  ownerEditBody: $("#owner-edit-body"),
  ownerUpdateComment: $("#owner-update-comment"),
  ownerDeleteComment: $("#owner-delete-comment"),
  gmEditBody: $("#gm-edit-body"),
  gmUpdateComment: $("#gm-update-comment"),
  gmDeleteComment: $("#gm-delete-comment"),
  deleteTestConfirm: $("#delete-test-confirm"),
  counts: $("#counts-result"),
  stateChange: $("#state-change-result"),
  status: $("#connection-status"),
  operationResult: $("#operation-result"),
  authState: $("#auth-state-result"),
  errors: $("#error-result"),
  operationLog: $("#operation-log"),
};

let activeClient = null;
let activeClientSignature = "";
let currentUser = null;
let selectedSession = null;
let selectedComment = null;
let currentComments = [];
let logItems = [];
let isBusy = false;

function redactSensitive(value) {
  let text = String(value ?? "");
  const directValues = [
    refs.url?.value,
    refs.key?.value,
    refs.password?.value,
  ].filter(Boolean);

  for (const directValue of directValues) {
    text = text.split(directValue).join("[redacted]");
  }

  return text
    .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[redacted-url]")
    .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[redacted-token]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[redacted-long-value]");
}

function formatSupabaseError(error) {
  if (!error) return "unknown error";
  if (typeof error === "string") return redactSensitive(error);

  const parts = [
    error.message && `message=${error.message}`,
    error.code && `code=${error.code}`,
    error.details && `details=${error.details}`,
    error.hint && `hint=${error.hint}`,
    error.status && `status=${error.status}`,
    error.name && `name=${error.name}`,
  ].filter(Boolean);

  return redactSensitive(parts.join(" | ") || "unknown error object");
}

function humanizeError(error) {
  const formatted = formatSupabaseError(error);
  const lower = formatted.toLowerCase();

  if (lower.includes("not authenticated") || lower.includes("jwt")) {
    return `ログインが必要です。${formatted}`;
  }
  if (lower.includes("blank")) {
    return `コメント本文が空です。${formatted}`;
  }
  if (lower.includes("too long")) {
    return `コメント本文が長すぎます。${formatted}`;
  }
  if (lower.includes("not editable")) {
    return `このコメントは編集できません。${formatted}`;
  }
  if (lower.includes("not deletable")) {
    return `このコメントは削除できません。${formatted}`;
  }
  if (lower.includes("not found") || lower.includes("already deleted")) {
    return `コメントが見つからないか、すでに削除済みです。${formatted}`;
  }
  if (lower.includes("permission denied") || lower.includes("rls")) {
    return `権限がありません。${formatted}`;
  }

  return `通信またはDB側でエラーが発生しました。${formatted}`;
}

function setStatus(target, message, type = "") {
  target.textContent = message;
  target.className = `status ${type}`.trim();
}

function setEmpty(target, message) {
  target.replaceChildren();
  const paragraph = document.createElement("p");
  paragraph.className = "empty";
  paragraph.textContent = message;
  target.append(paragraph);
}

function renderErrorList(errors) {
  refs.errors.replaceChildren();
  if (!errors.length) {
    setEmpty(refs.errors, "エラーはありません。");
    return;
  }

  const list = document.createElement("ul");
  list.className = "error-list";
  for (const error of errors) {
    const item = document.createElement("li");
    item.textContent = redactSensitive(error);
    list.append(item);
  }
  refs.errors.append(list);
}

function appendLog(message) {
  const timestamp = new Date().toLocaleTimeString("ja-JP", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  logItems = [`${timestamp} ${redactSensitive(message)}`, ...logItems].slice(0, 16);
  renderLog();
}

function renderLog() {
  refs.operationLog.replaceChildren();
  if (logItems.length === 0) {
    setEmpty(refs.operationLog, "まだ操作ログはありません。");
    return;
  }

  const list = document.createElement("ul");
  list.className = "log-list";
  for (const message of logItems) {
    const item = document.createElement("li");
    item.textContent = message;
    list.append(item);
  }
  refs.operationLog.append(list);
}

function validateConnectionInputs() {
  const url = refs.url.value.trim();
  const key = refs.key.value.trim();
  const joined = `${url} ${key}`;

  if (!url) throw new Error("Supabase URLを入力してください。");
  if (!key) throw new Error("Publishable / anon keyを入力してください。");
  if (/service[_-]?role|secret|sb_secret|postgres(?:ql)?:\/\//i.test(joined)) {
    throw new Error("service role / secret key / Direct connection string らしき値は入力しないでください。");
  }
  if (!window.supabase?.createClient) {
    throw new Error("Supabase clientライブラリを読み込めませんでした。");
  }

  return { url, key };
}

function getClient() {
  const { url, key } = validateConnectionInputs();
  const signature = `${url.length}:${key.length}:${url.slice(0, 8)}:${key.slice(0, 8)}`;

  if (activeClient && activeClientSignature === signature) {
    return activeClient;
  }

  activeClient = window.supabase.createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  activeClientSignature = signature;
  currentUser = null;
  selectedSession = null;
  selectedComment = null;
  currentComments = [];
  return activeClient;
}

function assertNoSensitiveFields(rows, contextLabel) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  const leaked = new Set();

  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (SENSITIVE_FIELD_NAMES.has(key)) leaked.add(key);
    }
  }

  if (leaked.size > 0) {
    throw new Error(`${contextLabel} に表示禁止フィールドがあります: ${[...leaked].join(", ")}`);
  }
}

function toDisplayValue(value) {
  if (Array.isArray(value)) return `[${value.join(", ")}]`;
  if (value === null || value === undefined) return "";
  return String(value);
}

function getColumnKey(column) {
  return typeof column === "string" ? column : column.key;
}

function getColumnLabel(column) {
  return typeof column === "string" ? column : column.label;
}

function formatCellValue(key, value) {
  if (value === null || value === undefined || value === "") return "";
  if (key === "status" || key === "application_status") {
    return STATUS_LABELS[value] ? `${STATUS_LABELS[value]} (${value})` : toDisplayValue(value);
  }
  if (key === "visibility") {
    return VISIBILITY_LABELS[value] ? `${VISIBILITY_LABELS[value]} (${value})` : toDisplayValue(value);
  }
  if (typeof value === "boolean") {
    return value ? "はい" : "いいえ";
  }
  return toDisplayValue(value);
}

function maskId(value) {
  const text = String(value || "");
  if (text.length <= 10) return text;
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
}

function pickColumns(row, columns) {
  return columns.reduce((picked, column) => {
    const key = getColumnKey(column);
    picked[key] = row?.[key];
    return picked;
  }, {});
}

function renderTable(target, rows, columns, emptyMessage) {
  target.replaceChildren();
  if (!Array.isArray(rows) || rows.length === 0) {
    setEmpty(target, emptyMessage);
    return;
  }

  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");

  for (const column of columns) {
    const th = document.createElement("th");
    th.scope = "col";
    th.textContent = getColumnLabel(column);
    headRow.append(th);
  }

  thead.append(headRow);
  table.append(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of columns) {
      const key = getColumnKey(column);
      const td = document.createElement("td");
      td.textContent = formatCellValue(key, row?.[key]);
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  target.append(wrap);
}

function renderAuthState(rows) {
  refs.authState.replaceChildren();
  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");

  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = value || "未取得";
    dl.append(dt, dd);
  }

  card.append(dl);
  refs.authState.append(card);
}

function renderSelectedSession() {
  refs.selectedSession.replaceChildren();
  if (!selectedSession) {
    setEmpty(refs.selectedSession, "セッションを選択してください。");
    return;
  }

  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");
  const rows = [
    ["セッションID", selectedSession.id],
    ["タイトル", selectedSession.title],
    ["日付", selectedSession.date],
    ["募集状態", formatCellValue("status", selectedSession.status)],
    ["公開範囲", formatCellValue("visibility", selectedSession.visibility)],
    ["GM名", selectedSession.gm_name],
    ["取得元", selectedSession.sourceLabel || ""],
  ];

  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = value || "";
    dl.append(dt, dd);
  }

  card.append(dl);
  refs.selectedSession.append(card);
}

function renderSelectedComment() {
  refs.selectedComment.replaceChildren();
  if (!selectedComment) {
    setEmpty(refs.selectedComment, "コメントを選択してください。");
    updateActionButtonState();
    return;
  }

  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");
  const rows = [
    ["コメントID", selectedComment.comment_id],
    ["表示名", selectedComment.display_name],
    ["申請状態", formatCellValue("application_status", selectedComment.application_status)],
    ["申請コメント", selectedComment.is_application],
    ["削除状態", selectedComment.deleted_at],
    ["コメント本文", selectedComment.body],
  ];

  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = toDisplayValue(value);
    dl.append(dt, dd);
  }

  card.append(dl);
  refs.selectedComment.append(card);
  refs.ownerEditBody.value = selectedComment.body || "";
  refs.gmEditBody.value = selectedComment.body || "";
  updateActionButtonState();
}

function updateActionButtonState() {
  const hasComment = Boolean(selectedComment?.comment_id);
  const loggedIn = Boolean(currentUser);
  const disabled = isBusy || !loggedIn || !hasComment;
  const deleteConfirmed = Boolean(refs.deleteTestConfirm?.checked);
  refs.ownerUpdateComment.disabled = disabled || refs.ownerEditBody.value.trim().length === 0;
  refs.ownerDeleteComment.disabled = disabled || !deleteConfirmed;
  refs.gmUpdateComment.disabled = disabled || refs.gmEditBody.value.trim().length === 0;
  refs.gmDeleteComment.disabled = disabled || !deleteConfirmed;
}

function renderSessions(target, rows, emptyMessage) {
  target.replaceChildren();
  if (!Array.isArray(rows) || rows.length === 0) {
    setEmpty(target, emptyMessage);
    return;
  }

  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");

  for (const column of SESSION_COLUMNS) {
    const th = document.createElement("th");
    th.scope = "col";
    th.textContent = getColumnLabel(column);
    headRow.append(th);
  }

  thead.append(headRow);
  table.append(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of SESSION_COLUMNS) {
      const key = getColumnKey(column);
      const td = document.createElement("td");
      if (key === "select") {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "secondary";
        button.textContent = "選択";
        button.addEventListener("click", () => {
          selectedSession = row;
          selectedComment = null;
          if (refs.deleteTestConfirm) refs.deleteTestConfirm.checked = false;
          renderSelectedSession();
          renderSelectedComment();
          reloadCommentDetails();
          appendLog(`セッションを選択: ${row.id}`);
        });
        td.append(button);
      } else {
        td.textContent = formatCellValue(key, row[key]);
      }
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  target.append(wrap);
}

function renderComments(rows) {
  refs.comments.replaceChildren();
  if (!Array.isArray(rows) || rows.length === 0) {
    setEmpty(refs.comments, "表示できるコメントは0件です。公開RPCで取得できないセッションでは、今後GM用RPC / viewが必要です。");
    return;
  }

  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");

  for (const column of COMMENT_COLUMNS) {
    const th = document.createElement("th");
    th.scope = "col";
    th.textContent = getColumnLabel(column);
    headRow.append(th);
  }

  thead.append(headRow);
  table.append(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of COMMENT_COLUMNS) {
      const key = getColumnKey(column);
      const td = document.createElement("td");
      if (key === "select") {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "secondary";
        button.textContent = "選択";
        button.disabled = !row.comment_id;
        button.addEventListener("click", () => {
          selectedComment = row;
          if (refs.deleteTestConfirm) refs.deleteTestConfirm.checked = false;
          renderSelectedComment();
          appendLog(`コメントを選択: ${row.comment_id}`);
        });
        td.append(button);
      } else if (key === "application_status") {
        const badge = document.createElement("span");
        badge.className = `badge ${row.application_status === "accepted" ? "ok" : row.application_status === "rejected" || row.application_status === "canceled" ? "error" : "warn"}`;
        badge.textContent = formatCellValue(key, row[key]);
        td.append(badge);
      } else if (key === "deleted_at") {
        td.textContent = row.deleted_at ? "あり" : "なし / 公開RPCでは通常非表示";
      } else {
        td.textContent = formatCellValue(key, row?.[key]);
      }
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  refs.comments.append(wrap);
}

async function fetchDisplayName(client, user) {
  if (!user?.id) return { displayName: "", error: null };

  const { data, error } = await client
    .from("public_profiles")
    .select("display_name")
    .eq("id", user.id)
    .maybeSingle();

  if (error) return { displayName: "", error };
  return { displayName: data?.display_name || "", error: null };
}

async function refreshAuthState(reason = "manual") {
  const errors = [];
  setStatus(refs.status, "ログイン状態を確認しています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) {
      throw new Error(`セッション確認失敗: ${formatSupabaseError(sessionError)}`);
    }

    const { data: userData, error: userError } = await client.auth.getUser();
    if (userError && sessionData?.session) {
      throw new Error(`ユーザー確認失敗: ${formatSupabaseError(userError)}`);
    }

    const user = userData?.user || null;
    currentUser = user;

    if (!user) {
      renderAuthState([
        ["状態", "未ログイン"],
        ["メールアドレス", ""],
        ["display_name", ""],
        ["ユーザーID", ""],
      ]);
      setStatus(refs.status, "未ログインです。編集・削除にはログインが必要です。", "warn");
      updateActionButtonState();
      return;
    }

    const { displayName, error: profileError } = await fetchDisplayName(client, user);
    if (profileError) {
      errors.push(`public_profiles取得失敗: ${formatSupabaseError(profileError)}`);
    }

    renderAuthState([
      ["状態", "ログイン済み"],
      ["メールアドレス", user.email || ""],
      ["display_name", displayName || "未取得"],
      ["ユーザーID", `非表示 (${maskId(user.id)})`],
      ["セッション", sessionData?.session && reason === "manual" ? "確認済み" : "ログイン操作で確認"],
    ]);
    setStatus(refs.status, "ログイン状態を確認しました。token / discord_user_id は表示していません。", errors.length ? "warn" : "ok");
  } catch (error) {
    currentUser = null;
    errors.push(error.message || String(error));
    renderAuthState([
      ["状態", "確認失敗"],
      ["メールアドレス", ""],
      ["display_name", ""],
      ["ユーザーID", ""],
    ]);
    setStatus(refs.status, "ログイン状態の確認に失敗しました。", "error");
  } finally {
    renderErrorList(errors);
    updateActionButtonState();
  }
}

async function login() {
  const errors = [];
  setStatus(refs.status, "ログインしています。", "warn");
  renderErrorList([]);

  try {
    const email = refs.email.value.trim();
    const password = refs.password.value;
    if (!email) throw new Error("メールアドレスを入力してください。");
    if (!password) throw new Error("パスワードを入力してください。");

    const client = getClient();
    const { error } = await client.auth.signInWithPassword({ email, password });
    refs.password.value = "";

    if (error) throw new Error(`ログイン失敗: ${formatSupabaseError(error)}`);
    appendLog("ログイン成功");
    await refreshAuthState("login");
    await loadSessions();
  } catch (error) {
    errors.push(error.message || String(error));
    refs.password.value = "";
    currentUser = null;
    renderErrorList(errors);
    setStatus(refs.status, "ログインに失敗しました。", "error");
    updateActionButtonState();
  }
}

async function logout() {
  const errors = [];
  setStatus(refs.status, "ログアウトしています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const { error } = await client.auth.signOut();
    if (error) throw new Error(`ログアウト失敗: ${formatSupabaseError(error)}`);
    refs.password.value = "";
    currentUser = null;
    selectedSession = null;
    selectedComment = null;
    currentComments = [];
    renderAuthState([
      ["状態", "未ログイン"],
      ["メールアドレス", ""],
      ["display_name", ""],
      ["ユーザーID", ""],
    ]);
    setEmpty(refs.gmSessions, "ログイン後に読み取ってください。");
    setEmpty(refs.selectedSession, "セッションを選択してください。");
    setEmpty(refs.selectedComment, "コメントを選択してください。");
    setEmpty(refs.comments, "セッション選択後に再読込してください。");
    setEmpty(refs.counts, "まだ読み取っていません。");
    setEmpty(refs.stateChange, "編集・削除後にRPC戻り値と再読込結果を表示します。");
    setStatus(refs.status, "ログアウトしました。検証後はこの状態にしてください。", "ok");
    appendLog("ログアウト成功");
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "ログアウトに失敗しました。", "error");
  } finally {
    updateActionButtonState();
  }
}

async function queryPublicSessions(client) {
  const { data, error } = await client
    .from("sessions")
    .select("id,title,date,status,visibility,gm_name,start_time")
    .eq("visibility", "public")
    .order("date", { ascending: true })
    .order("start_time", { ascending: true })
    .limit(80);

  if (error) throw new Error(`公開セッション一覧の取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  const nonPublic = rows.filter((row) => row.visibility !== "public");
  if (nonPublic.length > 0) {
    throw new Error("公開セッション一覧にpublic以外の公開範囲が含まれています。");
  }
  assertNoSensitiveFields(rows, "公開セッション一覧");
  return rows.map((row) => ({ ...row, sourceLabel: "公開セッション一覧" }));
}

async function queryOwnGmSessions(client) {
  if (!currentUser?.id) return [];

  const { data, error } = await client
    .from("sessions")
    .select("id,title,date,status,visibility,gm_name,start_time")
    .eq("gm_user_id", currentUser.id)
    .order("date", { ascending: true })
    .order("start_time", { ascending: true })
    .limit(80);

  if (error) throw new Error(`自分がGMのセッション取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  assertNoSensitiveFields(rows, "自分がGMのセッション一覧");
  return rows.map((row) => ({ ...row, sourceLabel: "自分がGMのセッション" }));
}

async function loadSessions() {
  const errors = [];
  setStatus(refs.status, "セッション一覧を読み取っています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const publicRows = await queryPublicSessions(client);
    renderSessions(refs.publicSessions, publicRows, "公開セッションは0件です。非公開 / 非表示セッションは表示されません。");

    let gmRows = [];
    if (currentUser?.id) {
      gmRows = await queryOwnGmSessions(client);
    }
    renderSessions(refs.gmSessions, gmRows, currentUser ? "自分がGMのセッションは0件です。" : "ログイン後に読み取ってください。");

    setStatus(refs.status, `セッション一覧を読み取りました。公開 ${publicRows.length}件 / 自分がGM ${gmRows.length}件。`, "ok");
    appendLog(`セッション一覧を読込: 公開=${publicRows.length}, 自分がGM=${gmRows.length}`);
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "セッション一覧の読み取りに失敗しました。", "error");
  }
}

async function queryApplications(client, sessionId) {
  const { data, error } = await client
    .from("session_applications")
    .select("id,session_id,status,comment_id,created_at,updated_at")
    .eq("session_id", sessionId)
    .order("created_at", { ascending: true });

  if (error) throw new Error(`申請一覧取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  assertNoSensitiveFields(rows, "session_applications");
  return rows;
}

async function queryPublicComments(client, sessionId) {
  const { data, error } = await client.rpc("get_public_session_comments", {
    target_session_id: sessionId,
  });

  if (error) throw new Error(`公開コメントRPC取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  assertNoSensitiveFields(rows, "get_public_session_comments");
  return rows;
}

async function queryCounts(client, sessionId = null) {
  const { data, error } = await client.rpc("get_public_session_application_counts", {
    target_session_id: sessionId,
  });

  if (error) throw new Error(`参加人数RPC取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  assertNoSensitiveFields(rows, "get_public_session_application_counts");
  return rows;
}

function mergeCommentRows(applications, publicComments, sessionVisibility) {
  const applicationsByCommentId = new Map();
  for (const application of applications || []) {
    if (application.comment_id) applicationsByCommentId.set(application.comment_id, application);
  }

  const publicRows = (publicComments || []).map((comment) => {
    const application = comment.comment_id ? applicationsByCommentId.get(comment.comment_id) : null;
    return {
      comment_id: comment.comment_id || application?.comment_id || "",
      session_id: comment.session_id || application?.session_id || selectedSession?.id || "",
      display_name: comment.display_name || "(未取得)",
      body: comment.body || "",
      application_status: comment.application_status || application?.status || "",
      is_application: "公開コメントRPCでは未返却",
      created_at: comment.created_at || application?.created_at || "",
      updated_at: comment.updated_at || application?.updated_at || "",
      edited_at: comment.edited_at || "",
      deleted_at: "",
      data_source: application ? "公開コメント + 見えている申請情報" : "公開コメント",
    };
  });

  const publicCommentIds = new Set(publicRows.map((row) => row.comment_id).filter(Boolean));
  const applicationOnlyRows = (applications || [])
    .filter((application) => application.comment_id && !publicCommentIds.has(application.comment_id))
    .map((application) => ({
      comment_id: application.comment_id,
      session_id: application.session_id,
      display_name: "(現行RPCでは未取得)",
      body: sessionVisibility === "public"
        ? "(公開コメントRPCに対応行がありません。削除済み、または追加RPC確認が必要です。)"
        : "(非公開 / 非表示セッションの本文は現行公開RPCでは取得不可です。)",
      application_status: application.status,
      is_application: "申請コメント相当: 申請情報由来",
      created_at: application.created_at,
      updated_at: application.updated_at,
      edited_at: "",
      deleted_at: sessionVisibility === "public" ? "公開RPCに出ない" : "未取得",
      data_source: "見えている申請情報のみ",
    }));

  return [...publicRows, ...applicationOnlyRows];
}

async function reloadCommentDetails() {
  const errors = [];
  renderErrorList([]);

  if (!selectedSession?.id) {
    setEmpty(refs.comments, "セッションを選択してください。");
    setEmpty(refs.counts, "セッションを選択してください。");
    return;
  }

  try {
    const client = getClient();
    const [applications, comments, counts] = await Promise.all([
      currentUser ? queryApplications(client, selectedSession.id) : Promise.resolve([]),
      selectedSession.visibility === "public" ? queryPublicComments(client, selectedSession.id) : Promise.resolve([]),
      queryCounts(client, selectedSession.id),
    ]);

    currentComments = mergeCommentRows(applications, comments, selectedSession.visibility);
    if (selectedComment?.comment_id) {
      selectedComment = currentComments.find((row) => row.comment_id === selectedComment.comment_id) || null;
    }
    renderComments(currentComments);
    renderSelectedComment();
    renderTable(
      refs.counts,
      counts.map((row) => pickColumns(row, COUNT_COLUMNS)),
      COUNT_COLUMNS,
      "参加人数カウントは0件です。非公開 / 非表示は公開人数RPCから返りません。"
    );
    appendLog(`コメントと人数を再読込: ${selectedSession.id}`);
  } catch (error) {
    errors.push(error.message || String(error));
    currentComments = [];
    selectedComment = null;
    renderComments([]);
    renderSelectedComment();
    renderErrorList(errors);
    setStatus(refs.operationResult, "コメント一覧または参加人数の再読込に失敗しました。", "error");
  }
}

function validateCommentOperation(bodyRequired, body) {
  if (!currentUser) throw new Error("ログインが必要です。");
  if (!selectedSession?.id) throw new Error("セッションを選択してください。");
  if (!selectedComment?.comment_id) throw new Error("comment_idを持つコメントを選択してください。");
  if (bodyRequired) {
    const trimmed = body.trim();
    if (!trimmed) throw new Error("コメント本文を入力してください。");
    if (trimmed.length > 4000) throw new Error("コメント本文が長すぎます。4000文字以内にしてください。");
    return trimmed;
  }
  return "";
}

async function updateSelectedComment(mode) {
  const errors = [];
  renderErrorList([]);

  try {
    const bodySource = mode === "gm" ? refs.gmEditBody : refs.ownerEditBody;
    const body = validateCommentOperation(true, bodySource.value);
    const confirmation = [
      `${mode === "gm" ? "GMとして" : "自分のコメントとして"}コメントを編集します。よろしいですか？`,
      `セッション: ${selectedSession.title || selectedSession.id}`,
      `コメントID: ${selectedComment.comment_id}`,
      `現在の申請状態: ${formatCellValue("application_status", selectedComment.application_status) || "(未取得)"}`,
    ].join("\n");

    if (!window.confirm(confirmation)) {
      appendLog(`コメント編集をキャンセル: ${mode}`);
      return;
    }

    isBusy = true;
    updateActionButtonState();
    setStatus(refs.operationResult, "コメントを編集しています。", "warn");

    const client = getClient();
    const { data, error } = await client.rpc("update_application_comment", {
      target_comment_id: selectedComment.comment_id,
      comment_body: body,
    });

    if (error) throw error;
    assertNoSensitiveFields(data ?? [], "update_application_comment");
    renderTable(refs.stateChange, data ?? [], EDIT_RESULT_COLUMNS, "編集RPC戻り値は空です。");
    setStatus(refs.operationResult, "コメントを編集しました。コメント一覧と人数を再読込します。", "ok");
    appendLog(`コメント編集成功: ${selectedComment.comment_id}`);
    await reloadCommentDetails();
  } catch (error) {
    const message = humanizeError(error);
    errors.push(message);
    renderErrorList(errors);
    setStatus(refs.operationResult, message, "error");
    appendLog(`コメント編集失敗: ${message}`);
  } finally {
    isBusy = false;
    updateActionButtonState();
  }
}

async function deleteSelectedComment(mode) {
  const errors = [];
  renderErrorList([]);

  try {
    validateCommentOperation(false, "");
    if (!refs.deleteTestConfirm.checked) {
      throw new Error("削除前に「これはテスト用コメントです」のチェックを入れてください。");
    }
    const acceptedWarning = selectedComment.application_status === "accepted"
      ? "\n\nこの申請は承認済み (accepted) です。最後の有効コメントを削除すると申請が取消扱いになる可能性があります。"
      : "";
    const confirmation = [
      `${mode === "gm" ? "GMとして" : "自分のコメントとして"}コメントを論理削除します。よろしいですか？`,
      `セッション: ${selectedSession.title || selectedSession.id}`,
      `コメントID: ${selectedComment.comment_id}`,
      `現在の申請状態: ${formatCellValue("application_status", selectedComment.application_status) || "(未取得)"}`,
      "削除後は公開コメント一覧から消えます。元に戻す操作はこの画面では扱いません。",
      acceptedWarning,
    ].join("\n");

    if (!window.confirm(confirmation)) {
      appendLog(`コメント削除をキャンセル: ${mode}`);
      return;
    }

    isBusy = true;
    updateActionButtonState();
    setStatus(refs.operationResult, "コメントを論理削除しています。", "warn");

    const client = getClient();
    const { data, error } = await client.rpc("delete_application_comment_and_maybe_cancel", {
      target_comment_id: selectedComment.comment_id,
    });

    if (error) throw error;
    assertNoSensitiveFields(data ?? [], "delete_application_comment_and_maybe_cancel");
    renderTable(
      refs.stateChange,
      (data ?? []).map((row) => pickColumns(row, DELETE_RESULT_COLUMNS)),
      DELETE_RESULT_COLUMNS,
      "削除RPC戻り値は空です。"
    );
    setStatus(refs.operationResult, "コメントを論理削除しました。コメント一覧と人数を再読込します。", "ok");
    appendLog(`コメント論理削除成功: ${selectedComment.comment_id}`);
    selectedComment = null;
    refs.deleteTestConfirm.checked = false;
    await reloadCommentDetails();
  } catch (error) {
    const message = humanizeError(error);
    errors.push(message);
    renderErrorList(errors);
    setStatus(refs.operationResult, message, "error");
    appendLog(`コメント論理削除失敗: ${message}`);
  } finally {
    isBusy = false;
    updateActionButtonState();
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  refs.email.value = "";
  refs.password.value = "";
  refs.ownerEditBody.value = "";
  refs.gmEditBody.value = "";
  refs.deleteTestConfirm.checked = false;
  activeClient = null;
  activeClientSignature = "";
  currentUser = null;
  selectedSession = null;
  selectedComment = null;
  currentComments = [];
  isBusy = false;
  setStatus(refs.status, "入力をクリアしました。Authセッション削除ではありません。必要ならログアウトしてください。");
  setStatus(refs.operationResult, "未実行です。");
  setEmpty(refs.authState, "まだ確認していません。");
  setEmpty(refs.publicSessions, "まだ読み取っていません。");
  setEmpty(refs.gmSessions, "ログイン後に読み取ってください。");
  setEmpty(refs.selectedSession, "セッションを選択してください。");
  setEmpty(refs.selectedComment, "コメントを選択してください。");
  setEmpty(refs.comments, "セッション選択後に再読込してください。");
  setEmpty(refs.counts, "まだ読み取っていません。");
  setEmpty(refs.stateChange, "編集・削除後にRPC戻り値と再読込結果を表示します。");
  renderErrorList([]);
  logItems = [];
  renderLog();
  updateActionButtonState();
}

refs.checkState.addEventListener("click", () => {
  refreshAuthState("manual");
});

refs.loadSessions.addEventListener("click", () => {
  loadSessions();
});

refs.login.addEventListener("click", () => {
  login();
});

refs.logout.addEventListener("click", () => {
  logout();
});

refs.clear.addEventListener("click", clearInputs);

refs.reloadComments.addEventListener("click", () => {
  reloadCommentDetails();
});

refs.ownerEditBody.addEventListener("input", updateActionButtonState);

refs.gmEditBody.addEventListener("input", updateActionButtonState);

refs.ownerUpdateComment.addEventListener("click", () => {
  updateSelectedComment("owner");
});

refs.gmUpdateComment.addEventListener("click", () => {
  updateSelectedComment("gm");
});

refs.ownerDeleteComment.addEventListener("click", () => {
  deleteSelectedComment("owner");
});

refs.gmDeleteComment.addEventListener("click", () => {
  deleteSelectedComment("gm");
});

updateActionButtonState();
