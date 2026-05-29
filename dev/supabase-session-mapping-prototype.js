import { renderSessionDetailContent } from "../assets/js/sessionDisplay.js";

const SAFE_RAW_COLUMNS = [
  "id",
  "title",
  "date",
  "start_time",
  "end_time",
  "gm_name",
  "status",
  "level_range",
  "player_min",
  "player_max",
  "visibility",
  "updated_at",
];

const SAFE_MAPPED_COLUMNS = [
  "id",
  "title",
  "date",
  "startTime",
  "endTime",
  "gmName",
  "status",
  "levelRange",
  "playerMin",
  "playerMax",
  "playerCount",
  "visibility",
  "updatedAt",
  "tags",
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
  "password",
]);

const $ = (selector) => document.querySelector(selector);

const refs = {
  url: $("#supabase-url"),
  key: $("#supabase-key"),
  run: $("#run-checks"),
  clear: $("#clear-inputs"),
  status: $("#connection-status"),
  raw: $("#raw-sessions-result"),
  mapped: $("#mapped-sessions-result"),
  preview: $("#preview-result"),
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

function getClient() {
  const url = refs.url.value.trim();
  const key = refs.key.value.trim();
  const joined = `${url} ${key}`;

  if (!url) throw new Error("Supabase URLを入力してください。");
  if (!key) throw new Error("Publishable / anon keyを入力してください。");
  if (/service[_-]?role|secret|sb_secret|postgresql:\/\//i.test(joined)) {
    throw new Error("service role / secret key / Direct connection string らしき値は入力しないでください。");
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
    item.textContent = redactSensitive(error);
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
      td.textContent = Array.isArray(value)
        ? `[${value.join(", ")}]`
        : value === null || value === undefined
          ? ""
          : String(value);
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

function formatTimeForDisplay(value) {
  const text = String(value || "").trim();
  const matched = text.match(/^(\d{2}):(\d{2})/);
  return matched ? `${matched[1]}:${matched[2]}` : text;
}

function toNumberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function buildCountMap(rows) {
  const map = new Map();
  for (const row of rows || []) {
    if (!row?.session_id) continue;
    map.set(row.session_id, {
      accepted_count: toNumberOrNull(row.accepted_count) || 0,
      pending_count: toNumberOrNull(row.pending_count) || 0,
      waitlisted_count: toNumberOrNull(row.waitlisted_count) || 0,
    });
  }
  return map;
}

function mapSupabaseSessionToDisplaySession(row, countMap = new Map()) {
  const counts = countMap.get(row.id) || {};

  return {
    id: row.id,
    title: row.title || "",
    date: row.date || "",
    startTime: formatTimeForDisplay(row.start_time),
    endTime: formatTimeForDisplay(row.end_time),
    gmName: row.gm_name || "",
    status: row.status || "",
    levelRange: row.level_range || "",
    playerMin: toNumberOrNull(row.player_min),
    playerMax: toNumberOrNull(row.player_max),
    playerCount: toNumberOrNull(counts.accepted_count) || 0,
    summary: row.summary || "",
    detail: row.detail || "",
    requirements: row.requirements || "",
    tags: [],
    visibility: row.visibility || "",
    updatedAt: row.updated_at || "",
  };
}

async function queryPublicSessions(client) {
  const { data, error } = await client
    .from("sessions")
    .select("id,title,date,start_time,end_time,gm_name,status,level_range,player_min,player_max,summary,detail,requirements,visibility,updated_at")
    .eq("visibility", "public")
    .order("date", { ascending: true })
    .order("start_time", { ascending: true })
    .limit(50);

  if (error) throw new Error(`public sessions取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  const nonPublic = rows.filter((row) => row.visibility !== "public");
  if (nonPublic.length > 0) {
    throw new Error("public sessions一覧にpublic以外のvisibilityが含まれています。");
  }
  assertNoSensitiveFields(rows, "raw sessions");

  return rows;
}

async function queryApplicationCounts(client) {
  const { data, error } = await client.rpc("get_public_session_application_counts", {
    target_session_id: null,
  });

  if (error) throw new Error(`参加人数RPC取得失敗: ${formatSupabaseError(error)}`);

  const rows = data ?? [];
  assertNoSensitiveFields(rows, "get_public_session_application_counts");
  return rows;
}

function renderPreview(sessions) {
  refs.preview.replaceChildren();
  if (!Array.isArray(sessions) || sessions.length === 0) {
    setEmpty(refs.preview, "プレビュー対象のpublic sessionは0件でした。");
    return;
  }

  const list = document.createElement("div");
  list.className = "preview-list";

  for (const session of sessions) {
    const card = document.createElement("article");
    card.className = "preview-card";
    card.innerHTML = renderSessionDetailContent(session, {
      mode: "modal",
      headingId: `preview-${String(session.id || "session").replace(/[^a-zA-Z0-9_-]/g, "-")}`,
      eyebrow: "Mapped Session Preview",
      includeMinimumPlayers: true,
    });
    list.append(card);
  }

  refs.preview.append(list);
}

async function runMappingPrototype() {
  const errors = [];
  refs.run.disabled = true;
  setStatus("公開セッションを読み取り、表示用オブジェクトへ変換しています。", "warn");
  setEmpty(refs.raw, "読み取り中です。");
  setEmpty(refs.mapped, "変換中です。");
  setEmpty(refs.preview, "プレビュー生成中です。");
  renderErrorList([]);

  try {
    const client = getClient();
    const [rawSessions, countRows] = await Promise.all([
      queryPublicSessions(client),
      queryApplicationCounts(client),
    ]);

    const countMap = buildCountMap(countRows);
    const mappedSessions = rawSessions.map((row) => mapSupabaseSessionToDisplaySession(row, countMap));
    assertNoSensitiveFields(mappedSessions, "mapped display sessions");

    renderTable(
      refs.raw,
      rawSessions.map((row) => pickColumns(row, SAFE_RAW_COLUMNS)),
      SAFE_RAW_COLUMNS,
      "public sessionは0件でした。"
    );
    renderTable(
      refs.mapped,
      mappedSessions.map((session) => pickColumns(session, SAFE_MAPPED_COLUMNS)),
      SAFE_MAPPED_COLUMNS,
      "変換対象のpublic sessionは0件でした。"
    );
    renderPreview(mappedSessions);
  } catch (error) {
    errors.push(redactSensitive(error.message || String(error)));
  } finally {
    refs.run.disabled = false;
    renderErrorList(errors);
    if (errors.length > 0) {
      setStatus(`F-2マッピング確認は完了しましたが、${errors.length}件のエラーがあります。`, "error");
    } else {
      setStatus("F-2マッピング確認は完了しました。public sessionの表示変換はPASSです。", "ok");
    }
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  setStatus("入力をクリアしました。", "");
  setEmpty(refs.raw, "まだ読み取っていません。");
  setEmpty(refs.mapped, "まだ変換していません。");
  setEmpty(refs.preview, "まだプレビューしていません。");
  renderErrorList([]);
}

refs.run.addEventListener("click", () => {
  runMappingPrototype();
});

refs.clear.addEventListener("click", clearInputs);
