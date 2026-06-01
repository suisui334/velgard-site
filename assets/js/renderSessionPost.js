import { escapeHtml } from "./sessionDisplay.js?v=20260601-session-post";
import {
  createSupabaseBrowserClient,
  getSupabaseRuntimeConfig,
  hasSupabaseRuntimeConfig
} from "./supabaseBrowserClient.js?v=20260601-session-post";

const ERROR_MESSAGE = "依頼書を投稿できませんでした。権限または入力内容を確認してください。";
const END_BEFORE_START_MESSAGE = "終了日時は開始日時より後にしてください。";
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DATE_TIME_PATTERN = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})$/;

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
          <h2>依頼書</h2>
          <p>初期値は非公開の下書きです。</p>
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
          </div>
          ${renderTextareaField("概要", "p_summary", 1000)}
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
      <dt>session_id</dt>
      <dd>${escapeHtml(result.session_id || "")}</dd>
    </div>
    <div>
      <dt>Discord同期状態</dt>
      <dd>${escapeHtml(result.discord_sync_status || "未設定")}</dd>
    </div>
  `;
}

async function initializeForm(root, client) {
  const formPanel = root.querySelector("[data-session-post-form-panel]");
  const form = root.querySelector("[data-session-post-form]");
  const submit = root.querySelector("[data-session-post-submit]");
  const state = root.querySelector("[data-session-post-state]");
  const resultPanel = root.querySelector("[data-session-post-result-panel]");
  const resultList = root.querySelector("[data-session-post-result]");

  formPanel.hidden = false;
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
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
