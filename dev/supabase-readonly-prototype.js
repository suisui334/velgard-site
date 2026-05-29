const SENSITIVE_FIELD_NAMES = new Set([
  "user_id",
  "discord_user_id",
  "email",
  "role",
  "access_token",
  "refresh_token",
  "password",
]);

const SAFE_COMMENT_COLUMNS = [
  "comment_id",
  "session_id",
  "display_name",
  "body",
  "application_status",
  "created_at",
  "updated_at",
  "edited_at",
];

const SAFE_COUNT_COLUMNS = [
  "session_id",
  "accepted_count",
  "pending_count",
  "waitlisted_count",
];

const $ = (selector) => document.querySelector(selector);

const refs = {
  url: $("#supabase-url"),
  key: $("#supabase-key"),
  sessionId: $("#session-id"),
  run: $("#run-checks"),
  clear: $("#clear-inputs"),
  status: $("#connection-status"),
  sessions: $("#sessions-result"),
  comments: $("#comments-result"),
  counts: $("#counts-result"),
  errors: $("#error-result"),
};

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

function redactSensitive(value) {
  let text = String(value ?? "");
  const directValues = [refs.url?.value, refs.key?.value].filter(Boolean);

  for (const directValue of directValues) {
    text = text.split(directValue).join("[redacted]");
  }

  return text
    .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[redacted-url]")
    .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[redacted-token]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[redacted-long-value]");
}

function setStatus(message, type = "") {
  refs.status.textContent = message;
  refs.status.className = `status ${type}`.trim();
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
    item.textContent = error;
    list.append(item);
  }
  refs.errors.append(list);
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
      const value = row?.[column];
      td.textContent = value === null || value === undefined ? "" : String(value);
      tr.append(td);
    }
    tbody.append(tr);
  }

  table.append(tbody);
  wrap.append(table);
  target.append(wrap);
}

function assertNoSensitiveFields(rows, contextLabel) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  const leaked = new Set();

  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (SENSITIVE_FIELD_NAMES.has(key.toLowerCase())) leaked.add(key);
    }
  }

  if (leaked.size > 0) {
    throw new Error(`${contextLabel} に公開禁止フィールドがあります: ${[...leaked].join(", ")}`);
  }
}

function getClient() {
  const url = refs.url.value.trim();
  const key = refs.key.value.trim();

  if (!url) throw new Error("Supabase URLを入力してください。");
  if (!key) throw new Error("Publishable / anon keyを入力してください。");
  if (/service[_-]?role|secret|sb_secret_/i.test(key)) {
    throw new Error("service role / secret key らしき値は入力しないでください。");
  }
  if (!window.supabase?.createClient) {
    throw new Error("Supabase clientライブラリを読み込めませんでした。");
  }

  return window.supabase.createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

async function queryPublicSessions(client) {
  const { data, error } = await client
    .from("sessions")
    .select("id,title,date,status,visibility,gm_name")
    .eq("visibility", "public")
    .order("date", { ascending: true })
    .limit(30);

  if (error) throw new Error(`public sessions取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  const nonPublic = rows.filter((row) => row.visibility !== "public");
  if (nonPublic.length > 0) {
    throw new Error("public sessions一覧にpublic以外のvisibilityが含まれています。");
  }

  renderTable(
    refs.sessions,
    rows,
    ["id", "title", "date", "status", "visibility", "gm_name"],
    "public sessionは0件でした。"
  );

  return rows;
}

async function queryPublicComments(client, targetSessionId) {
  const { data, error } = await client.rpc("get_public_session_comments", {
    target_session_id: targetSessionId,
  });

  if (error) throw new Error(`公開コメントRPC取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  assertNoSensitiveFields(rows, "get_public_session_comments");

  renderTable(
    refs.comments,
    rows.map((row) => pickColumns(row, SAFE_COMMENT_COLUMNS)),
    SAFE_COMMENT_COLUMNS,
    "公開コメントは0件でした。"
  );
}

async function queryApplicationCounts(client, targetSessionId) {
  const { data, error } = await client.rpc("get_public_session_application_counts", {
    target_session_id: targetSessionId || null,
  });

  if (error) throw new Error(`参加人数RPC取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  assertNoSensitiveFields(rows, "get_public_session_application_counts");

  renderTable(
    refs.counts,
    rows.map((row) => pickColumns(row, SAFE_COUNT_COLUMNS)),
    SAFE_COUNT_COLUMNS,
    "参加人数RPCの結果は0件でした。"
  );
}

function pickColumns(row, columns) {
  return columns.reduce((picked, column) => {
    picked[column] = row?.[column];
    return picked;
  }, {});
}

async function runReadOnlyChecks() {
  const errors = [];
  refs.run.disabled = true;
  setStatus("読み取りテストを実行中です。", "warn");
  setEmpty(refs.sessions, "読み取り中です。");
  setEmpty(refs.comments, "読み取り中です。");
  setEmpty(refs.counts, "読み取り中です。");
  renderErrorList([]);

  try {
    const client = getClient();
    const targetSessionId = refs.sessionId.value.trim() || "rls-test-public-recruiting";

    await queryPublicSessions(client).catch((error) => errors.push(error.message));
    await queryPublicComments(client, targetSessionId).catch((error) => errors.push(error.message));
    await queryApplicationCounts(client, targetSessionId).catch((error) => errors.push(error.message));
  } catch (error) {
    errors.push(redactSensitive(error.message || String(error)));
  } finally {
    refs.run.disabled = false;
    renderErrorList(errors.map(redactSensitive));
    if (errors.length > 0) {
      setStatus(`読み取りテストは完了しましたが、${errors.length}件のエラーがあります。`, "error");
    } else {
      setStatus("読み取りテストは完了しました。公開範囲の基本確認はPASSです。", "ok");
    }
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  refs.sessionId.value = "rls-test-public-recruiting";
  setStatus("入力をクリアしました。", "");
  setEmpty(refs.sessions, "まだ読み取っていません。");
  setEmpty(refs.comments, "まだ読み取っていません。");
  setEmpty(refs.counts, "まだ読み取っていません。");
  renderErrorList([]);
}

refs.run.addEventListener("click", () => {
  runReadOnlyChecks();
});

refs.clear.addEventListener("click", clearInputs);
