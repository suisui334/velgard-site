import {
  escapeHtml,
  getSessionStatusLabel,
  getSessionTypeLabel
} from "./sessionDisplay.js?v=20260601-session-post";
import {
  createSupabaseBrowserClient,
  getSupabaseRuntimeConfig,
  hasSupabaseRuntimeConfig
} from "./supabaseBrowserClient.js?v=20260601-session-post";

const ERROR_MESSAGE = "依頼書を投稿できませんでした。権限または入力内容を確認してください。";
const END_BEFORE_START_MESSAGE = "終了日時は開始日時より後にしてください。";
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DATE_TIME_PATTERN = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})$/;
const MANAGE_SESSION_SELECT = [
  "id",
  "title",
  "date",
  "start_time",
  "end_time",
  "end_at",
  "application_deadline",
  "session_type",
  "player_min",
  "player_max",
  "summary",
  "visibility",
  "status",
  "discord_sync_status",
  "created_at",
  "updated_at"
].join(",");
const VISIBILITY_LABELS = {
  hidden: "非公開",
  private: "限定",
  public: "公開"
};
const DISCORD_SYNC_STATUS_LABELS = {
  not_requested: "未要求",
  skipped: "同期対象外",
  pending: "同期待ち",
  posted: "同期済み",
  failed: "同期失敗"
};
const EDIT_STATUS_MESSAGE = "編集保存は次工程です。新規作成する場合は「新規依頼書を書く」を選んでください。";

function renderShell(initialStartAt = "") {
  return `
    <header class="page-title">
      <div class="eyebrow">Session Post</div>
      <h1>依頼書投稿</h1>
      <p class="lead">GM/admin向けのセッション予定投稿フォームです。</p>
    </header>
    <section class="section session-post-section">
      <article class="article-box session-post-auth-panel">
        <h2>投稿権限</h2>
        <p class="session-post-state" data-session-post-auth-state>確認しています。</p>
        <p class="session-post-actions">
          <a class="button" href="mypage.html">ACCOUNTへ</a>
          <a class="button" href="calendar.html">CALENDARへ</a>
        </p>
      </article>
      <article class="article-box session-post-form-panel" data-session-post-form-panel hidden>
        <div class="session-post-form-head">
          <div class="session-post-mode-row">
            <h2 data-session-post-mode-title>依頼書</h2>
          </div>
          <p data-session-post-mode-note>初期値は非公開の下書きです。</p>
        </div>
        <form class="session-post-form" data-session-post-form>
          <div class="session-post-grid">
            ${renderTextField("タイトル", "p_title", "text", { required: true, maxlength: 120 })}
            ${renderTextField("開始日時", "p_start_at", "datetime-local", { required: true, value: initialStartAt })}
            ${renderTextField("終了日時", "p_end_at", "datetime-local", { required: true })}
            ${renderTextField("申請締切", "p_application_deadline", "datetime-local")}
            ${renderSelectField("種別", "p_session_type", [
              ["one-shot", "単発シナリオ"],
              ["campaign", "キャンペーン"],
              ["special", "特殊"],
              ["other", "その他"]
            ], "one-shot")}
            ${renderTextField("募集人数 min", "p_player_min", "number", { min: 0 })}
            ${renderTextField("募集人数 max", "p_player_max", "number", { min: 0 })}
            ${renderSelectField("公開状態", "p_visibility", [
              ["hidden", "非公開"],
              ["private", "限定"],
              ["public", "公開"]
            ], "hidden")}
            ${renderSelectField("募集状態", "p_status", [
              ["draft", "下書き"],
              ["tentative", "仮予定"],
              ["recruiting", "募集中"]
            ], "draft")}
            <label class="session-post-field" id="my-sessions" data-session-post-manage-panel hidden>
              <span data-session-post-manage-label>自分の依頼書</span>
              <select data-session-post-manage-select disabled>
                <option value="new">読み込み中</option>
              </select>
              <span data-session-post-manage-state aria-live="polite" hidden>読み込み中</span>
            </label>
            ${renderTextareaField("概要", "p_summary", 1000)}
          </div>
          <label class="session-post-public-confirm">
            <input type="checkbox" name="public_confirm" value="yes">
            <span>公開状態で保存する場合に確認する</span>
          </label>
          <div class="session-post-submit-row">
            <button class="button primary" type="submit" data-session-post-submit>作成する</button>
            <p class="session-post-state" data-session-post-state aria-live="polite"></p>
          </div>
        </form>
      </article>
      <article class="article-box session-post-result-panel" data-session-post-result-panel hidden>
        <h2>作成結果</h2>
        <dl class="session-post-result-list" data-session-post-result></dl>
      </article>
    </section>
  `;
}

function renderTextField(label, name, type, options = {}) {
  const attrs = [
    `type="${escapeHtml(type)}"`,
    `name="${escapeHtml(name)}"`,
    options.required ? "required" : "",
    options.maxlength ? `maxlength="${Number(options.maxlength)}"` : "",
    Number.isFinite(Number(options.min)) ? `min="${Number(options.min)}"` : "",
    typeof options.value === "string" ? `value="${escapeHtml(options.value)}"` : "",
    options.placeholder ? `placeholder="${escapeHtml(options.placeholder)}"` : ""
  ].filter(Boolean).join(" ");
  return `
    <label class="session-post-field">
      <span>${escapeHtml(label)}</span>
      <input ${attrs}>
    </label>
  `;
}

function renderSelectField(label, name, options, selectedValue) {
  return `
    <label class="session-post-field">
      <span>${escapeHtml(label)}</span>
      <select name="${escapeHtml(name)}">
        ${options.map(([value, text]) => `<option value="${escapeHtml(value)}"${value === selectedValue ? " selected" : ""}>${escapeHtml(text)}</option>`).join("")}
      </select>
    </label>
  `;
}

function renderTextareaField(label, name, maxlength) {
  return `
    <label class="session-post-field session-post-field--wide">
      <span>${escapeHtml(label)}</span>
      <textarea name="${escapeHtml(name)}" maxlength="${Number(maxlength)}" rows="5"></textarea>
    </label>
  `;
}

function setState(target, message, modifier = "") {
  if (!target) return;
  target.textContent = message;
  target.className = `session-post-state${modifier ? ` ${modifier}` : ""}`;
}

function getValue(form, name) {
  return String(new FormData(form).get(name) ?? "").trim();
}

function nullableText(value) {
  const text = String(value ?? "").trim();
  return text || null;
}

function nullableInteger(value) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const number = Number(text);
  return Number.isInteger(number) ? number : NaN;
}

function normalizeTime(value) {
  const text = String(value ?? "").trim();
  const match = text.match(/^(\d{2}):(\d{2})/);
  return match ? `${match[1]}:${match[2]}` : "";
}

function formatJapanDateTime(value) {
  const text = String(value ?? "").trim();
  if (!text) return "";

  const alreadyFormatted = text.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}):(\d{2})/);
  if (alreadyFormatted && !/[zZ]|[+-]\d{2}:?\d{2}$/.test(text)) {
    return `${alreadyFormatted[1]} ${alreadyFormatted[2]}:${alreadyFormatted[3]}`;
  }

  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return "";

  const parts = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).formatToParts(date).reduce((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});

  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}`;
}

function toDateTimeLocalInput(value) {
  const formatted = formatJapanDateTime(value);
  return formatted ? formatted.replace(" ", "T") : "";
}

function toDeadlineValue(value) {
  const text = String(value ?? "").trim();
  return text ? text.replace("T", " ") : null;
}

function toRpcDateTimeValue(value) {
  return `${value.date} ${value.time}`;
}

function parseDateTimeLocal(value) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const match = text.match(DATE_TIME_PATTERN);
  if (!match) throw new Error("invalid-date-time");
  return {
    date: match[1],
    time: match[2]
  };
}

function getInitialStartAt() {
  const params = new URLSearchParams(window.location.search);
  const date = String(params.get("date") || "").trim();
  return ISO_DATE_PATTERN.test(date) ? `${date}T21:00` : "";
}

function readSelectedSessionId() {
  const params = new URLSearchParams(window.location.search);
  return String(params.get("id") || "").trim();
}

function buildPayload(form) {
  const playerMin = nullableInteger(getValue(form, "p_player_min"));
  const playerMax = nullableInteger(getValue(form, "p_player_max"));
  if (Number.isNaN(playerMin) || Number.isNaN(playerMax)) {
    throw new Error("invalid-player-count");
  }

  const startAt = parseDateTimeLocal(getValue(form, "p_start_at"));
  const endAt = parseDateTimeLocal(getValue(form, "p_end_at"));
  if (!startAt) {
    throw new Error("missing-start-at");
  }
  if (!endAt) {
    throw new Error("missing-end-at");
  }
  if (toRpcDateTimeValue(endAt) <= toRpcDateTimeValue(startAt)) {
    throw new Error("end-before-start");
  }

  return {
    p_title: getValue(form, "p_title"),
    p_session_date: startAt.date,
    p_start_time: startAt.time,
    p_end_time: endAt.time,
    p_end_at: toRpcDateTimeValue(endAt),
    p_application_deadline: toDeadlineValue(getValue(form, "p_application_deadline")),
    p_session_type: getValue(form, "p_session_type"),
    p_level_range: null,
    p_player_min: playerMin,
    p_player_max: playerMax,
    p_summary: nullableText(getValue(form, "p_summary")),
    p_request_body: null,
    p_requirements: null,
    p_visibility: getValue(form, "p_visibility"),
    p_status: getValue(form, "p_status")
  };
}

async function hasPostingRole(client) {
  const [gmResult, adminResult] = await Promise.all([
    client.rpc("has_role", { role_name: "gm" }),
    client.rpc("is_admin")
  ]);
  const isGm = !gmResult.error && Boolean(gmResult.data);
  const isAdmin = !adminResult.error && Boolean(adminResult.data);
  return isGm || isAdmin;
}

function renderResult(target, result) {
  target.innerHTML = `
    <div>
      <dt>作成結果</dt>
      <dd>依頼書を作成しました</dd>
    </div>
    <div>
      <dt>Discord同期状態</dt>
      <dd>${escapeHtml(result.discord_sync_status || "未設定")}</dd>
    </div>
  `;
}

function formatPlayerCountLabel(playerMin, playerMax) {
  const min = Number.isFinite(playerMin) ? playerMin : null;
  const max = Number.isFinite(playerMax) ? playerMax : null;
  if (min !== null && max !== null) return `${min}〜${max}名`;
  if (max !== null) return `最大${max}名`;
  if (min !== null) return `最低${min}名`;
  return "未設定";
}

function toNumberOrNull(value) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const number = Number(text);
  return Number.isFinite(number) ? number : null;
}

function normalizeManagedSession(row) {
  const date = String(row?.date ?? "").trim();
  const startTime = normalizeTime(row?.start_time);
  const endTime = normalizeTime(row?.end_time);
  const endAt = formatJapanDateTime(row?.end_at);
  const applicationDeadline = formatJapanDateTime(row?.application_deadline);
  const playerMin = toNumberOrNull(row?.player_min);
  const playerMax = toNumberOrNull(row?.player_max);
  const visibility = String(row?.visibility ?? "").trim();
  const status = String(row?.status ?? "").trim();
  const sessionType = String(row?.session_type ?? "").trim();
  const startLabel = date && startTime ? `${date} ${startTime}` : date || "未定";
  const endLabel = endAt || (endTime && date ? `${date} ${endTime}` : endTime || "未定");
  return {
    id: String(row?.id ?? "").trim(),
    title: String(row?.title ?? "").trim() || "無題の依頼書",
    date,
    startTime,
    endTime,
    endAt,
    startLabel,
    endLabel,
    scheduleLabel: `${startLabel} - ${endLabel}`,
    applicationDeadline: applicationDeadline || "未設定",
    sessionType,
    sessionTypeLabel: getSessionTypeLabel(sessionType),
    playerMin,
    playerMax,
    playerCountLabel: formatPlayerCountLabel(playerMin, playerMax),
    summary: String(row?.summary ?? "").trim(),
    visibility,
    visibilityLabel: VISIBILITY_LABELS[visibility] || "未設定",
    status,
    statusLabel: getSessionStatusLabel(status),
    discordSyncStatus: String(row?.discord_sync_status ?? "").trim(),
    discordSyncStatusLabel: DISCORD_SYNC_STATUS_LABELS[String(row?.discord_sync_status ?? "").trim()] || "未設定",
    createdAt: formatJapanDateTime(row?.created_at) || "未定",
    updatedAt: formatJapanDateTime(row?.updated_at) || "未定",
    startInputValue: date && startTime ? `${date}T${startTime}` : "",
    endInputValue: toDateTimeLocalInput(row?.end_at) || (date && endTime ? `${date}T${endTime}` : ""),
    applicationDeadlineInputValue: toDateTimeLocalInput(row?.application_deadline)
  };
}

function formatManagedOptionDate(session) {
  const date = String(session?.date || "").trim();
  const startTime = String(session?.startTime || "").trim();
  if (date && startTime) return `${date.replaceAll("-", "/")} ${startTime}`;
  if (date) return date.replaceAll("-", "/");
  return "日時未定";
}

function renderManagedSessionOption(session, index) {
  return `<option value="manage-${Number(index)}">${escapeHtml(`【${session.statusLabel}・${session.visibilityLabel}】${formatManagedOptionDate(session)} ${session.title}`)}</option>`;
}

function getFormControl(form, name) {
  return form?.elements?.namedItem(name) || null;
}

function setFormValue(form, name, value) {
  const control = getFormControl(form, name);
  if (!control || !("value" in control)) return;
  control.value = String(value ?? "");
}

function removeTemporaryOptions(select) {
  if (!select?.options) return;
  Array.from(select.options).forEach((option) => {
    if (option.dataset.temporary === "true") option.remove();
  });
}

function setSelectValue(form, name, value, fallbackValue, labelResolver = null) {
  const select = getFormControl(form, name);
  if (!select || !select.options) return;
  const text = String(value ?? "").trim();
  removeTemporaryOptions(select);
  if (text && !Array.from(select.options).some((option) => option.value === text)) {
    const option = document.createElement("option");
    option.value = text;
    option.textContent = typeof labelResolver === "function" ? labelResolver(text) : text;
    option.dataset.temporary = "true";
    select.append(option);
  }
  select.value = text || fallbackValue;
}

function fillFormFromManagedSession(form, session) {
  setFormValue(form, "p_title", session.title);
  setFormValue(form, "p_start_at", session.startInputValue);
  setFormValue(form, "p_end_at", session.endInputValue);
  setFormValue(form, "p_application_deadline", session.applicationDeadlineInputValue);
  setFormValue(form, "p_player_min", Number.isFinite(session.playerMin) ? String(session.playerMin) : "");
  setFormValue(form, "p_player_max", Number.isFinite(session.playerMax) ? String(session.playerMax) : "");
  setFormValue(form, "p_summary", session.summary);
  setSelectValue(form, "p_session_type", session.sessionType, "one-shot", getSessionTypeLabel);
  setSelectValue(form, "p_visibility", session.visibility, "hidden", (value) => VISIBILITY_LABELS[value] || value);
  setSelectValue(form, "p_status", session.status, "draft", getSessionStatusLabel);
  const publicConfirm = getFormControl(form, "public_confirm");
  if (publicConfirm && "checked" in publicConfirm) publicConfirm.checked = false;
}

function resetFormForNewSession(form) {
  form.reset();
  ["p_session_type", "p_visibility", "p_status"].forEach((name) => removeTemporaryOptions(getFormControl(form, name)));
  setFormValue(form, "p_title", "");
  setFormValue(form, "p_start_at", "");
  setFormValue(form, "p_end_at", "");
  setFormValue(form, "p_application_deadline", "");
  setFormValue(form, "p_player_min", "");
  setFormValue(form, "p_player_max", "");
  setFormValue(form, "p_summary", "");
  setSelectValue(form, "p_session_type", "one-shot", "one-shot", getSessionTypeLabel);
  setSelectValue(form, "p_visibility", "hidden", "hidden", (value) => VISIBILITY_LABELS[value] || value);
  setSelectValue(form, "p_status", "draft", "draft", getSessionStatusLabel);
  const publicConfirm = getFormControl(form, "public_confirm");
  if (publicConfirm && "checked" in publicConfirm) publicConfirm.checked = false;
}

function replaceSelectedSessionId(sessionId = "") {
  const url = new URL(window.location.href);
  const id = String(sessionId || "").trim();
  if (id) {
    url.searchParams.set("id", id);
  } else {
    url.searchParams.delete("id");
  }
  window.history.replaceState(null, "", `${url.pathname}${url.search}${url.hash}`);
}

function enterEditMode(elements, session) {
  elements.currentSession = session;
  fillFormFromManagedSession(elements.form, session);
  elements.formPanel.classList.add("is-editing");
  elements.form.classList.add("is-editing");
  elements.modeTitle.textContent = "依頼書";
  elements.modeNote.textContent = "初期値は非公開の下書きです。";
  elements.submit.disabled = true;
  elements.submit.textContent = "編集保存は次工程";
  elements.resultPanel.hidden = true;
  setState(elements.formState, EDIT_STATUS_MESSAGE);
  setState(elements.manageState, "保存更新は次工程です。");
  replaceSelectedSessionId("");
}

function enterNewMode(elements, options = {}) {
  elements.currentSession = null;
  if (options.clearForm) resetFormForNewSession(elements.form);
  elements.formPanel.classList.remove("is-editing");
  elements.form.classList.remove("is-editing");
  elements.modeTitle.textContent = "依頼書";
  elements.modeNote.textContent = "初期値は非公開の下書きです。";
  elements.submit.disabled = false;
  elements.submit.textContent = "作成する";
  if (options.clearResult) elements.resultPanel.hidden = true;
  if (options.clearForm) setState(elements.formState, "");
  setState(elements.manageState, "");
  replaceSelectedSessionId("");
}

function setManageSelectOptions(elements, sessions) {
  const countLabel = sessions.length ? `自分の依頼書（${sessions.length}件）` : "自分の依頼書";
  elements.manageLabel.textContent = countLabel;
  elements.select.innerHTML = [
    `<option value="new">新規依頼書を書く</option>`,
    ...sessions.map((session, index) => renderManagedSessionOption(session, index))
  ].join("");
  elements.select.disabled = false;
}

function selectManagedSession(elements, sessions, selectedIndex, options = {}) {
  const session = sessions[selectedIndex] || null;
  elements.select.value = session ? `manage-${selectedIndex}` : "new";
  if (options.applyToForm && session) {
    enterEditMode(elements, session);
  }
}

async function loadManagedSessions(client, elements) {
  const { panel, select, state } = elements;
  panel.hidden = false;
  setState(state, "");
  select.disabled = true;
  select.innerHTML = `<option value="new">読み込み中</option>`;

  const { data, error } = await client
    .from("sessions")
    .select(MANAGE_SESSION_SELECT)
    .order("created_at", { ascending: false })
    .limit(80);

  if (error) {
    setState(state, "依頼書一覧を取得できませんでした。", "is-error");
    return;
  }

  const sessions = Array.isArray(data) ? data.map(normalizeManagedSession) : [];
  elements.managedSessions = sessions;
  setManageSelectOptions(elements, sessions);

  if (!sessions.length) {
    setState(state, "");
    select.value = "new";
    return;
  }

  setState(state, "");
  const selectedSessionId = readSelectedSessionId();
  const selectedIndex = sessions.findIndex((session) => selectedSessionId && session.id === selectedSessionId);
  if (selectedSessionId && selectedIndex < 0) {
    replaceSelectedSessionId("");
  }
  selectManagedSession(elements, sessions, selectedIndex, { applyToForm: selectedIndex >= 0 });
  select.onchange = () => {
    if (select.value === "new") {
      enterNewMode(elements, { clearForm: true, clearResult: true });
      return;
    }
    const match = String(select.value || "").match(/^manage-(\d+)$/);
    const index = match ? Number(match[1]) : -1;
    if (!Number.isInteger(index) || !sessions[index]) {
      select.value = "new";
      enterNewMode(elements, { clearForm: true, clearResult: true });
      return;
    }
    selectManagedSession(elements, sessions, index, { applyToForm: true });
  };
}

async function initializeForm(root, client) {
  const formPanel = root.querySelector("[data-session-post-form-panel]");
  const form = root.querySelector("[data-session-post-form]");
  const submit = root.querySelector("[data-session-post-submit]");
  const state = root.querySelector("[data-session-post-state]");
  const resultPanel = root.querySelector("[data-session-post-result-panel]");
  const resultList = root.querySelector("[data-session-post-result]");
  const manageElements = {
    currentSession: null,
    managedSessions: [],
    formPanel,
    form,
    submit,
    formState: state,
    resultPanel,
    modeTitle: root.querySelector("[data-session-post-mode-title]"),
    modeNote: root.querySelector("[data-session-post-mode-note]"),
    panel: root.querySelector("[data-session-post-manage-panel]"),
    select: root.querySelector("[data-session-post-manage-select]"),
    manageLabel: root.querySelector("[data-session-post-manage-label]"),
    manageState: root.querySelector("[data-session-post-manage-state]"),
    state: root.querySelector("[data-session-post-manage-state]")
  };

  formPanel.hidden = false;
  await loadManagedSessions(client, manageElements);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (manageElements.currentSession) {
      setState(state, EDIT_STATUS_MESSAGE);
      return;
    }
    resultPanel.hidden = true;
    setState(state, "送信しています。");
    submit.disabled = true;

    try {
      const payload = buildPayload(form);
      const publicConfirmed = new FormData(form).get("public_confirm") === "yes";
      if (payload.p_visibility === "public" && !publicConfirmed) {
        setState(state, "公開状態で保存する場合は確認してください。", "is-error");
        submit.disabled = false;
        return;
      }
      if (payload.p_visibility === "public" && payload.p_status === "draft") {
        setState(state, "公開状態の下書きは保存できません。", "is-error");
        submit.disabled = false;
        return;
      }

      const { data, error } = await client.rpc("create_session_post", payload);
      if (error) throw error;
      const result = Array.isArray(data) ? data[0] : data;
      if (!result || typeof result !== "object") throw new Error("invalid-result");
      setState(state, "作成しました。", "is-ok");
      renderResult(resultList, result);
      resultPanel.hidden = false;
      await loadManagedSessions(client, manageElements);
    } catch (error) {
      setState(state, error?.message === "end-before-start" ? END_BEFORE_START_MESSAGE : ERROR_MESSAGE, "is-error");
    } finally {
      submit.disabled = false;
    }
  });
}

export async function renderSessionPost(root) {
  root.innerHTML = renderShell(getInitialStartAt());
  const authState = root.querySelector("[data-session-post-auth-state]");
  const config = getSupabaseRuntimeConfig();
  if (!hasSupabaseRuntimeConfig(config)) {
    setState(authState, "接続設定が未構成です。", "is-error");
    return;
  }

  try {
    const client = await createSupabaseBrowserClient();
    const { data, error } = await client.auth.getSession();
    if (error || !data?.session) {
      setState(authState, "依頼書投稿にはログインが必要です。");
      return;
    }

    const canPost = await hasPostingRole(client);
    if (!canPost) {
      setState(authState, "依頼書投稿はGM/admin向けです。", "is-error");
      return;
    }

    setState(authState, "投稿できます。", "is-ok");
    await initializeForm(root, client);
  } catch {
    setState(authState, "依頼書投稿の準備に失敗しました。", "is-error");
  }
}
