const APPLY_ALLOWED_STATUSES = new Set(["recruiting", "tentative"]);

const SESSION_COLUMNS = [
  "select",
  "id",
  "title",
  "date",
  "status",
  "visibility",
  "gm_name",
  "canApply",
];

const COMMENT_COLUMNS = [
  "comment_id",
  "session_id",
  "display_name",
  "body",
  "application_status",
  "created_at",
  "updated_at",
  "edited_at",
];

const COUNT_COLUMNS = [
  "session_id",
  "accepted_count",
  "pending_count",
  "waitlisted_count",
];

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
  sessions: $("#sessions-result"),
  selected: $("#selected-session-result"),
  manualSessionId: $("#manual-session-id"),
  selectManualSession: $("#select-manual-session"),
  commentBody: $("#comment-body"),
  postComment: $("#post-comment"),
  refreshReadbacks: $("#refresh-readbacks"),
  status: $("#connection-status"),
  postStatus: $("#post-status"),
  authState: $("#auth-state-result"),
  comments: $("#comments-result"),
  counts: $("#counts-result"),
  errors: $("#error-result"),
  operationLog: $("#operation-log"),
};

let activeClient = null;
let activeClientSignature = "";
let selectedSession = null;
let isLoggedIn = false;
let logItems = [];

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
  if (lower.includes("not open for applications")) {
    return `このセッションは現在申請できません。${formatted}`;
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
  logItems = [`${timestamp} ${redactSensitive(message)}`, ...logItems].slice(0, 12);
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
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  });
  activeClientSignature = signature;
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

function canApplyToSession(session) {
  return session?.visibility === "public" && APPLY_ALLOWED_STATUSES.has(session?.status);
}

function toDisplayValue(value) {
  if (Array.isArray(value)) return `[${value.join(", ")}]`;
  if (value === null || value === undefined) return "";
  return String(value);
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
  refs.selected.replaceChildren();
  if (!selectedSession) {
    setEmpty(refs.selected, "sessionを選択してください。");
    updatePostButtonState();
    return;
  }

  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");
  const canApply = canApplyToSession(selectedSession);
  const rows = [
    ["id", selectedSession.id],
    ["title", selectedSession.title],
    ["date", selectedSession.date],
    ["status", selectedSession.status],
    ["visibility", selectedSession.visibility],
    ["gm_name", selectedSession.gm_name],
    ["canApply", canApply ? "UI判定: 申請可能" : "UI判定: 申請不可。RPCが最終判定します。"],
  ];

  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = value || "";
    dl.append(dt, dd);
  }

  card.append(dl);
  refs.selected.append(card);
  updatePostButtonState();
}

function updatePostButtonState() {
  refs.postComment.disabled = !isLoggedIn || !selectedSession || refs.commentBody.value.trim().length === 0;
}

function renderSessions(rows) {
  refs.sessions.replaceChildren();
  if (!Array.isArray(rows) || rows.length === 0) {
    setEmpty(refs.sessions, "public sessionは0件です。");
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
    th.textContent = column;
    headRow.append(th);
  }

  thead.append(headRow);
  table.append(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of SESSION_COLUMNS) {
      const td = document.createElement("td");
      if (column === "select") {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "secondary";
        button.textContent = "選択";
        button.addEventListener("click", () => {
          selectedSession = row;
          renderSelectedSession();
          refreshSelectedSessionReadbacks();
          appendLog(`session selected: ${row.id}`);
        });
        td.append(button);
      } else if (column === "canApply") {
        const badge = document.createElement("span");
        const canApply = canApplyToSession(row);
        badge.className = `badge ${canApply ? "ok" : "warn"}`;
        badge.textContent = canApply ? "申請可能" : "申請不可";
        td.append(badge);
      } else {
        td.textContent = toDisplayValue(row[column]);
      }
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  refs.sessions.append(wrap);
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
    th.textContent = column;
    headRow.append(th);
  }

  thead.append(headRow);
  table.append(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of columns) {
      const td = document.createElement("td");
      td.textContent = toDisplayValue(row?.[column]);
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  target.append(wrap);
}

function pickColumns(row, columns) {
  return columns.reduce((picked, column) => {
    picked[column] = row?.[column];
    return picked;
  }, {});
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
    isLoggedIn = Boolean(user);

    if (!user) {
      renderAuthState([
        ["状態", "未ログイン"],
        ["メールアドレス", ""],
        ["display_name", ""],
        ["セッション復元", sessionData?.session ? "セッションあり / ユーザー未取得" : "なし"],
      ]);
      setStatus(refs.status, "未ログインです。投稿にはログインが必要です。", "warn");
      updatePostButtonState();
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
      ["セッション復元", sessionData?.session && reason === "manual" ? "確認済み" : "ログイン操作で確認"],
    ]);
    setStatus(refs.status, "ログイン状態を確認しました。user_id / token / discord_user_id は表示していません。", errors.length ? "warn" : "ok");
  } catch (error) {
    isLoggedIn = false;
    errors.push(error.message || String(error));
    renderAuthState([
      ["状態", "確認失敗"],
      ["メールアドレス", ""],
      ["display_name", ""],
      ["セッション復元", "未確認"],
    ]);
    setStatus(refs.status, "ログイン状態の確認に失敗しました。", "error");
  } finally {
    updatePostButtonState();
    renderErrorList(errors);
  }
}

async function login() {
  const errors = [];
  setStatus(refs.status, "ログインしています。", "warn");
  renderErrorList([]);

  try {
    const email = refs.email.value.trim();
    const password = refs.password.value;
    if (!email) throw new Error("Emailを入力してください。");
    if (!password) throw new Error("Passwordを入力してください。");

    const client = getClient();
    const { error } = await client.auth.signInWithPassword({ email, password });
    refs.password.value = "";

    if (error) throw new Error(`ログイン失敗: ${formatSupabaseError(error)}`);
    appendLog("login succeeded");
    await refreshAuthState("login");
  } catch (error) {
    errors.push(error.message || String(error));
    refs.password.value = "";
    isLoggedIn = false;
    updatePostButtonState();
    renderErrorList(errors);
    setStatus(refs.status, "ログインに失敗しました。", "error");
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
    isLoggedIn = false;
    renderAuthState([
      ["状態", "未ログイン"],
      ["メールアドレス", ""],
      ["display_name", ""],
      ["セッション復元", "ログアウト済み"],
    ]);
    setStatus(refs.status, "ログアウトしました。検証後はこの状態にしてください。", "ok");
    appendLog("logout succeeded");
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "ログアウトに失敗しました。", "error");
  } finally {
    updatePostButtonState();
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

  if (error) throw new Error(`public sessions取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  const nonPublic = rows.filter((row) => row.visibility !== "public");
  if (nonPublic.length > 0) {
    throw new Error("public sessions一覧にpublic以外のvisibilityが含まれています。");
  }
  assertNoSensitiveFields(rows, "public sessions");
  return rows;
}

async function loadPublicSessions() {
  const errors = [];
  setStatus(refs.status, "public sessionsを読み取っています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const rows = await queryPublicSessions(client);
    renderSessions(rows);
    setStatus(refs.status, `public sessionsを${rows.length}件読み取りました。private / hidden は表示対象外です。`, "ok");
    appendLog(`public sessions loaded: ${rows.length}`);
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "public sessionsの読み取りに失敗しました。", "error");
  }
}

async function queryComments(client, sessionId) {
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

async function refreshSelectedSessionReadbacks() {
  const errors = [];
  renderErrorList([]);

  if (!selectedSession?.id) {
    setEmpty(refs.comments, "sessionを選択してください。");
    setEmpty(refs.counts, "sessionを選択してください。");
    return;
  }

  try {
    const client = getClient();
    const [comments, counts] = await Promise.all([
      queryComments(client, selectedSession.id),
      queryCounts(client, selectedSession.id),
    ]);

    renderTable(
      refs.comments,
      comments.map((row) => pickColumns(row, COMMENT_COLUMNS)),
      COMMENT_COLUMNS,
      "公開コメントは0件です。"
    );
    renderTable(
      refs.counts,
      counts.map((row) => pickColumns(row, COUNT_COLUMNS)),
      COUNT_COLUMNS,
      "公開人数カウントは0件です。private / hidden は返りません。"
    );
    appendLog(`readbacks refreshed: ${selectedSession.id}`);
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.postStatus, "コメントまたは参加人数の再読込に失敗しました。", "error");
  }
}

function selectManualSession() {
  const manualId = refs.manualSessionId.value.trim();
  if (!manualId) {
    renderErrorList(["任意session IDを入力してください。"]);
    return;
  }

  selectedSession = {
    id: manualId,
    title: "手入力session ID",
    date: "",
    status: "unknown",
    visibility: "unknown",
    gm_name: "",
  };
  renderSelectedSession();
  setEmpty(refs.comments, "手入力session IDを選択しました。再読込または投稿でRPC挙動を確認してください。");
  setEmpty(refs.counts, "手入力session IDを選択しました。");
  appendLog(`manual session selected: ${manualId}`);
}

async function postApplicationComment() {
  const errors = [];
  setStatus(refs.postStatus, "投稿RPCを実行しています。", "warn");
  renderErrorList([]);

  try {
    if (!selectedSession?.id) throw new Error("投稿先sessionを選択してください。");
    if (!isLoggedIn) throw new Error("ログインが必要です。");

    const commentText = refs.commentBody.value.trim();
    if (!commentText) throw new Error("コメント本文を入力してください。");
    if (commentText.length > 4000) throw new Error("コメント本文が長すぎます。4000文字以内にしてください。");

    const client = getClient();
    const canApply = canApplyToSession(selectedSession);
    if (!canApply) {
      appendLog(`UI判定では申請不可。RPC失敗確認として送信します: ${selectedSession.id}`);
    }

    const { data, error } = await client.rpc("create_application_comment", {
      target_session_id: selectedSession.id,
      comment_body: commentText,
    });

    if (error) throw error;

    const commentIdLabel = data ? "comment id returned" : "no comment id returned";
    setStatus(refs.postStatus, `参加希望コメントを投稿しました。${commentIdLabel}。公開コメントと人数を再読込します。`, "ok");
    appendLog(`create_application_comment succeeded: ${selectedSession.id}`);
    await refreshSelectedSessionReadbacks();
  } catch (error) {
    const message = humanizeError(error);
    errors.push(message);
    renderErrorList(errors);
    setStatus(refs.postStatus, message, "error");
    appendLog(`create_application_comment failed: ${message}`);
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  refs.email.value = "";
  refs.password.value = "";
  refs.manualSessionId.value = "";
  activeClient = null;
  activeClientSignature = "";
  selectedSession = null;
  isLoggedIn = false;
  setStatus(refs.status, "入力をクリアしました。Authセッション削除ではありません。必要ならログアウトしてください。");
  setStatus(refs.postStatus, "未投稿です。");
  setEmpty(refs.authState, "まだ確認していません。");
  setEmpty(refs.sessions, "まだ読み取っていません。");
  setEmpty(refs.selected, "sessionを選択してください。");
  setEmpty(refs.comments, "session選択後に再読込してください。");
  setEmpty(refs.counts, "まだ読み取っていません。");
  renderErrorList([]);
  logItems = [];
  renderLog();
  updatePostButtonState();
}

refs.checkState.addEventListener("click", () => {
  refreshAuthState("manual");
});

refs.loadSessions.addEventListener("click", () => {
  loadPublicSessions();
});

refs.login.addEventListener("click", () => {
  login();
});

refs.logout.addEventListener("click", () => {
  logout();
});

refs.clear.addEventListener("click", clearInputs);

refs.selectManualSession.addEventListener("click", selectManualSession);

refs.postComment.addEventListener("click", () => {
  postApplicationComment();
});

refs.refreshReadbacks.addEventListener("click", () => {
  refreshSelectedSessionReadbacks();
});

refs.commentBody.addEventListener("input", updatePostButtonState);

updatePostButtonState();
