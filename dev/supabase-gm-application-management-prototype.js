const SESSION_COLUMNS = [
  "select",
  "id",
  "title",
  "date",
  "status",
  "visibility",
  "gm_name",
];

const APPLICATION_COLUMNS = [
  "application_id",
  "display_name",
  "comment_body",
  "application_status",
  "created_at",
  "updated_at",
  "edited_at",
  "actions",
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
  publicSessions: $("#public-sessions-result"),
  gmSessions: $("#gm-sessions-result"),
  selected: $("#selected-session-result"),
  reloadApplications: $("#reload-applications"),
  applications: $("#applications-result"),
  counts: $("#counts-result"),
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
let currentApplications = [];
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
  if (lower.includes("not allowed") || lower.includes("permission denied") || lower.includes("rls")) {
    return `この操作は対象セッションのGMまたはadminだけが実行できます。${formatted}`;
  }
  if (lower.includes("not found")) {
    return `申請が見つかりません。再読込してください。${formatted}`;
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
  logItems = [`${timestamp} ${redactSensitive(message)}`, ...logItems].slice(0, 14);
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
  currentApplications = [];
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

function maskId(value) {
  const text = String(value || "");
  if (text.length <= 10) return text;
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
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
    return;
  }

  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");
  const rows = [
    ["id", selectedSession.id],
    ["title", selectedSession.title],
    ["date", selectedSession.date],
    ["status", selectedSession.status],
    ["visibility", selectedSession.visibility],
    ["gm_name", selectedSession.gm_name],
    ["source", selectedSession.sourceLabel || ""],
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
          reloadApplicationDetails();
          appendLog(`session selected: ${row.id}`);
        });
        td.append(button);
      } else {
        td.textContent = toDisplayValue(row[column]);
      }
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  target.append(wrap);
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

function renderApplications(rows) {
  refs.applications.replaceChildren();
  if (!Array.isArray(rows) || rows.length === 0) {
    setEmpty(refs.applications, "表示できる申請は0件です。playerでは自分の申請のみ、GMでは対象sessionの申請が見える想定です。");
    return;
  }

  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");

  for (const column of APPLICATION_COLUMNS) {
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
    for (const column of APPLICATION_COLUMNS) {
      const td = document.createElement("td");
      if (column === "actions") {
        const acceptButton = document.createElement("button");
        acceptButton.type = "button";
        acceptButton.textContent = "承認";
        acceptButton.disabled = isBusy || !currentUser || !row.application_id;
        acceptButton.addEventListener("click", () => {
          updateApplicationStatus(row, "accepted");
        });

        const rejectButton = document.createElement("button");
        rejectButton.type = "button";
        rejectButton.className = "danger";
        rejectButton.textContent = "却下";
        rejectButton.disabled = isBusy || !currentUser || !row.application_id;
        rejectButton.addEventListener("click", () => {
          updateApplicationStatus(row, "rejected");
        });

        const actionWrap = document.createElement("div");
        actionWrap.className = "actions";
        actionWrap.append(acceptButton, rejectButton);
        td.append(actionWrap);
      } else if (column === "application_status") {
        const badge = document.createElement("span");
        badge.className = `badge ${row.application_status === "accepted" ? "ok" : row.application_status === "rejected" ? "error" : "warn"}`;
        badge.textContent = toDisplayValue(row[column]);
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
  refs.applications.append(wrap);
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
    currentUser = user;

    if (!user) {
      renderAuthState([
        ["状態", "未ログイン"],
        ["メールアドレス", ""],
        ["display_name", ""],
        ["user id", ""],
      ]);
      setStatus(refs.status, "未ログインです。GM操作にはログインが必要です。", "warn");
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
      ["user id", `非表示 (${maskId(user.id)})`],
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
      ["user id", ""],
    ]);
    setStatus(refs.status, "ログイン状態の確認に失敗しました。", "error");
  } finally {
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
    await loadSessions();
  } catch (error) {
    errors.push(error.message || String(error));
    refs.password.value = "";
    currentUser = null;
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
    currentUser = null;
    selectedSession = null;
    currentApplications = [];
    renderAuthState([
      ["状態", "未ログイン"],
      ["メールアドレス", ""],
      ["display_name", ""],
      ["user id", ""],
    ]);
    setEmpty(refs.gmSessions, "ログイン後に読み取ってください。");
    setEmpty(refs.selected, "sessionを選択してください。");
    setEmpty(refs.applications, "session選択後に再読込してください。");
    setEmpty(refs.counts, "まだ読み取っていません。");
    setStatus(refs.status, "ログアウトしました。検証後はこの状態にしてください。", "ok");
    appendLog("logout succeeded");
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "ログアウトに失敗しました。", "error");
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
  return rows.map((row) => ({ ...row, sourceLabel: "public sessions" }));
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

  if (error) throw new Error(`自分がGMのsession取得失敗: ${formatSupabaseError(error)}`);
  const rows = data ?? [];
  assertNoSensitiveFields(rows, "own GM sessions");
  return rows.map((row) => ({ ...row, sourceLabel: "own GM sessions" }));
}

async function loadSessions() {
  const errors = [];
  setStatus(refs.status, "sessionsを読み取っています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const publicRows = await queryPublicSessions(client);
    renderSessions(refs.publicSessions, publicRows, "public sessionは0件です。private / hidden は表示されません。");

    let gmRows = [];
    if (currentUser?.id) {
      gmRows = await queryOwnGmSessions(client);
    }
    renderSessions(refs.gmSessions, gmRows, currentUser ? "自分がGMのsessionは0件です。" : "ログイン後に読み取ってください。");

    setStatus(refs.status, `sessionsを読み取りました。public ${publicRows.length}件 / own GM ${gmRows.length}件。`, "ok");
    appendLog(`sessions loaded: public=${publicRows.length}, ownGm=${gmRows.length}`);
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus(refs.status, "sessionsの読み取りに失敗しました。", "error");
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

function mergeApplicationRows(applications, comments, sessionVisibility) {
  const commentsById = new Map();
  for (const comment of comments || []) {
    if (comment.comment_id) commentsById.set(comment.comment_id, comment);
  }

  return applications.map((application) => {
    const comment = application.comment_id ? commentsById.get(application.comment_id) : null;
    const commentUnavailable = sessionVisibility !== "public"
      ? "非public sessionの本文は現行public RPCでは取得不可"
      : "対応コメント未取得";

    return {
      application_id: application.id,
      session_id: application.session_id,
      display_name: comment?.display_name || "(未取得)",
      comment_body: comment?.body || commentUnavailable,
      application_status: application.status,
      created_at: comment?.created_at || application.created_at,
      updated_at: comment?.updated_at || application.updated_at,
      edited_at: comment?.edited_at || "",
      comment_id: application.comment_id || "",
    };
  });
}

async function reloadApplicationDetails() {
  const errors = [];
  renderErrorList([]);

  if (!selectedSession?.id) {
    setEmpty(refs.applications, "sessionを選択してください。");
    setEmpty(refs.counts, "sessionを選択してください。");
    return;
  }

  try {
    const client = getClient();
    const [applications, comments, counts] = await Promise.all([
      queryApplications(client, selectedSession.id),
      selectedSession.visibility === "public" ? queryPublicComments(client, selectedSession.id) : Promise.resolve([]),
      queryCounts(client, selectedSession.id),
    ]);

    currentApplications = mergeApplicationRows(applications, comments, selectedSession.visibility);
    renderApplications(currentApplications);
    renderTable(
      refs.counts,
      counts.map((row) => pickColumns(row, COUNT_COLUMNS)),
      COUNT_COLUMNS,
      "公開人数カウントは0件です。private / hidden はpublic count RPCから返りません。"
    );
    appendLog(`applications refreshed: ${selectedSession.id}`);
  } catch (error) {
    errors.push(error.message || String(error));
    currentApplications = [];
    renderApplications([]);
    renderErrorList(errors);
    setStatus(refs.operationResult, "申請一覧または参加人数の再読込に失敗しました。", "error");
  }
}

async function updateApplicationStatus(application, newStatus) {
  const errors = [];
  renderErrorList([]);

  if (!currentUser) {
    renderErrorList(["ログインが必要です。"]);
    return;
  }
  if (!selectedSession?.id) {
    renderErrorList(["sessionを選択してください。"]);
    return;
  }
  if (!application?.application_id) {
    renderErrorList(["application_idが取得できていないため操作できません。"]);
    return;
  }

  const confirmation = [
    `この申請を ${newStatus} に変更します。よろしいですか？`,
    `session: ${selectedSession.title || selectedSession.id}`,
    `display_name: ${application.display_name || "(未取得)"}`,
    `current status: ${application.application_status || "(未取得)"}`,
  ].join("\n");

  if (!window.confirm(confirmation)) {
    appendLog(`set_application_status canceled by user: ${newStatus}`);
    return;
  }

  isBusy = true;
  renderApplications(currentApplications);
  setStatus(refs.operationResult, `${newStatus} へ変更しています。`, "warn");

  try {
    const client = getClient();
    const { error } = await client.rpc("set_application_status", {
      target_application_id: application.application_id,
      new_status: newStatus,
    });

    if (error) throw error;

    setStatus(refs.operationResult, `申請を ${newStatus} に変更しました。申請一覧と人数を再読込します。`, "ok");
    appendLog(`set_application_status succeeded: ${selectedSession.id} -> ${newStatus}`);
    await reloadApplicationDetails();
  } catch (error) {
    const message = humanizeError(error);
    errors.push(message);
    renderErrorList(errors);
    setStatus(refs.operationResult, message, "error");
    appendLog(`set_application_status failed: ${message}`);
  } finally {
    isBusy = false;
    renderApplications(currentApplications);
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  refs.email.value = "";
  refs.password.value = "";
  activeClient = null;
  activeClientSignature = "";
  currentUser = null;
  selectedSession = null;
  currentApplications = [];
  isBusy = false;
  setStatus(refs.status, "入力をクリアしました。Authセッション削除ではありません。必要ならログアウトしてください。");
  setStatus(refs.operationResult, "未実行です。");
  setEmpty(refs.authState, "まだ確認していません。");
  setEmpty(refs.publicSessions, "まだ読み取っていません。");
  setEmpty(refs.gmSessions, "ログイン後に読み取ってください。");
  setEmpty(refs.selected, "sessionを選択してください。");
  setEmpty(refs.applications, "session選択後に再読込してください。");
  setEmpty(refs.counts, "まだ読み取っていません。");
  renderErrorList([]);
  logItems = [];
  renderLog();
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

refs.reloadApplications.addEventListener("click", () => {
  reloadApplicationDetails();
});
