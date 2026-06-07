import {
  escapeHtml,
  getSessionStatusLabel,
  getSessionTypeLabel
} from "./sessionDisplay.js?v=20260603-delete-equivalent";
import {
  createSupabaseBrowserClient,
  getSupabaseRuntimeConfig,
  hasSupabaseRuntimeConfig
} from "./supabaseBrowserClient.js?v=20260601-session-post";
import {
  deleteSyncedSession,
  getDiscordSyncStateModifier,
  getDiscordSyncUiMessage,
  hasDiscordPostReference,
  syncCreatedSession,
  syncUpdatedSession
} from "./discordSyncClient.js?v=20260606-discord-auto-sync";

const ERROR_MESSAGE = "依頼書を投稿できませんでした。権限または入力内容を確認してください。";
const END_BEFORE_START_MESSAGE = "終了日時は開始日時より後にしてください。";
const SAVE_ERROR_MESSAGE = "保存に失敗しました。";
const SAVE_SUCCESS_MESSAGE = "変更を保存しました。";
const PUBLIC_SAVE_SUCCESS_MESSAGE = "変更を保存しました。公開カレンダーに反映されます。";
const DRAFT_PUBLIC_MESSAGE = "下書きは公開にできません。募集状態を変更するか、公開状態を非公開にしてください。";
const DELETE_CONFIRM_MESSAGE = "この依頼書を完全に削除します。\n削除すると、依頼書本体に加えて参加申請・コメントも削除されます。\n中止として残したい場合は、削除せず募集状態を「中止」にしてください。\nDiscord投稿済みの場合は同期削除を試みます。\n本当に削除しますか？";
const DELETE_SUCCESS_MESSAGE = "この依頼書を削除しました。";
const DELETE_ERROR_MESSAGE = "依頼書の削除に失敗しました。";
const PUBLICATION_HIDDEN_HINT = "この依頼書は公開カレンダーには表示されません。";
const PUBLICATION_ACTIVE_HINT = "保存すると公開カレンダーに表示されます。";
const STATUS_CLOSED_HINTS = {
  closed: "保存すると募集終了扱いになります。",
  finished: "保存すると開催終了扱いになります。",
  canceled: "保存すると中止扱いになります。公開状態が非公開の場合、公開カレンダーには表示されません。"
};
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
  "session_tool",
  "player_min",
  "player_max",
  "summary",
  "visibility",
  "status",
  "discord_sync_status",
  "discord_message_id",
  "gm_user_id",
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
const UPDATE_ERROR_MESSAGES = {
  login_required: "ログインが必要です。",
  not_allowed: "この依頼書を編集する権限がありません。",
  session_not_found: "対象の依頼書が見つかりません。",
  draft_must_not_be_public: DRAFT_PUBLIC_MESSAGE,
  invalid_player_range: "募集人数の範囲を確認してください。",
  end_at_must_be_after_start_at: END_BEFORE_START_MESSAGE,
  end_time_must_be_after_start_time: END_BEFORE_START_MESSAGE,
  summary_too_long: "概要が長すぎます。",
  invalid_player_min: "募集人数の範囲を確認してください。",
  invalid_player_max: "募集人数の範囲を確認してください。",
  "invalid-player-count": "募集人数の範囲を確認してください。",
  "end-before-start": END_BEFORE_START_MESSAGE
};
const DELETE_ERROR_MESSAGES = {
  login_required: "ログインが必要です。",
  not_allowed: "この依頼書を削除する権限がありません。",
  session_not_found: "対象の依頼書が見つかりません。",
  session_id_required: "対象の依頼書が見つかりません。"
};
const TEMPLATE_PRESETS_RPC = "get_my_template_presets";
const TEMPLATE_CREATE_RPC = "create_template_preset";
const TEMPLATE_UPDATE_RPC = "update_template_preset";
const TEMPLATE_DEACTIVATE_RPC = "deactivate_template_preset";
const TEMPLATE_NAME_MAX_LENGTH = 80;
const TEMPLATE_BODY_MAX_LENGTH = 5000;
const SESSION_POST_TEMPLATE_FORMAT = "velgard.session_post_template.v1";
const SESSION_POST_TEMPLATE_APPLY_CONFIRM_MESSAGE = "保存せずにテンプレートを反映すると、現在の入力内容が失われます。続けますか？";
const SESSION_POST_TEMPLATE_TYPE_OPTIONS = Object.freeze([
  { value: "session_post", label: "依頼書用" },
  { value: "other", label: "その他" }
]);
const SESSION_POST_TEMPLATE_TYPE_VALUES = new Set(SESSION_POST_TEMPLATE_TYPE_OPTIONS.map((option) => option.value));
const SESSION_POST_TEMPLATE_FIELD_KEYS = Object.freeze([
  "p_title",
  "p_start_at",
  "p_end_at",
  "p_application_deadline",
  "p_session_type",
  "p_session_tool",
  "p_player_min",
  "p_player_max",
  "p_visibility",
  "p_status",
  "p_summary"
]);
const TEMPLATE_PRESET_FIELD_NAMES = new Set([
  "template_id",
  "template_name",
  "template_type",
  "template_body",
  "is_active",
  "created_at",
  "updated_at"
]);

function renderSessionPostTemplatePanel() {
  return `
    <section class="session-post-template-panel" data-session-post-template-panel>
      <div class="session-post-template-head">
        <h3>依頼書テンプレート</h3>
        <p>保存済みテンプレートの選択だけではフォームへ反映しません。</p>
      </div>
      <div class="session-post-template-grid">
        <label class="session-post-template-field">
          <span>保存済みテンプレート</span>
          <select data-session-post-template-select disabled>
            <option value="">読み込み中</option>
          </select>
        </label>
        <label class="session-post-template-field">
          <span>テンプレート名</span>
          <input type="text" maxlength="${TEMPLATE_NAME_MAX_LENGTH}" autocomplete="off" data-session-post-template-name placeholder="例：週末募集用">
        </label>
        <label class="session-post-template-field">
          <span>種別</span>
          <select data-session-post-template-type>
            ${SESSION_POST_TEMPLATE_TYPE_OPTIONS.map((option) => (
              `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`
            )).join("")}
          </select>
        </label>
      </div>
      <p class="session-post-template-note">秘匿情報や認証情報はテンプレート本文に入れないでください。</p>
      <div class="session-post-template-actions">
        <button class="button" type="button" data-session-post-template-create disabled>新規保存</button>
        <button class="button" type="button" data-session-post-template-update disabled>変更を保存</button>
        <button class="button danger" type="button" data-session-post-template-delete disabled>削除</button>
        <button class="button primary" type="button" data-session-post-template-apply disabled>反映</button>
        <p class="session-post-state" data-session-post-template-state aria-live="polite"></p>
      </div>
    </section>
  `;
}

function renderShell(initialStartAt = "") {
  return `
    <header class="page-title">
      <div class="eyebrow">Session Post</div>
      <h1>依頼書投稿</h1>
      <p class="lead">ログインユーザー向けのセッション予定投稿フォームです。</p>
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
        ${renderSessionPostTemplatePanel()}
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
            ${renderPlayerCountFields()}
            ${renderTextField("開催場所", "p_session_tool", "text", { maxlength: 80, placeholder: "例：Tekey / ココフォリア / Discordボイス" })}
            ${renderSelectField("公開状態", "p_visibility", [
              ["hidden", "非公開"],
              ["private", "限定"],
              ["public", "公開"]
            ], "hidden")}
            ${renderSelectField("募集状態", "p_status", [
              ["draft", "下書き"],
              ["tentative", "仮予定"],
              ["recruiting", "募集中"],
              ["closed", "募集終了"],
              ["finished", "開催終了"],
              ["canceled", "中止"]
            ], "draft")}
            <label class="session-post-field" id="my-sessions" data-session-post-manage-panel hidden>
              <span data-session-post-manage-label>自分の依頼書</span>
              <select data-session-post-manage-select disabled>
                <option value="new">読み込み中</option>
              </select>
              <span data-session-post-manage-state aria-live="polite" hidden>読み込み中</span>
            </label>
            <p class="session-post-publication-note" data-session-post-publication-note aria-live="polite" hidden></p>
            ${renderTextareaField("概要", "p_summary", 1000)}
          </div>
          <label class="session-post-public-confirm">
            <input type="checkbox" name="public_confirm" value="yes">
            <span>公開状態で保存する場合に確認する</span>
          </label>
          <div class="session-post-submit-row">
            <button class="button primary" type="submit" data-session-post-submit>作成する</button>
            <button class="button primary" type="button" data-session-post-save hidden>変更を保存</button>
            <button class="button danger" type="button" data-session-post-delete hidden>削除</button>
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

function renderPlayerCountFields() {
  return `
    <div class="session-post-field session-post-player-field" role="group" aria-labelledby="session-post-player-count-label">
      <span class="session-post-player-label" id="session-post-player-count-label">募集人数</span>
      <div class="session-post-player-inputs">
        <label>
          <span>min</span>
          <input type="number" name="p_player_min" min="0">
        </label>
        <label>
          <span>max</span>
          <input type="number" name="p_player_max" min="0">
        </label>
      </div>
    </div>
  `;
}

function setState(target, message, modifier = "") {
  if (!target) return;
  target.textContent = message;
  target.className = `session-post-state${modifier ? ` ${modifier}` : ""}`;
  if (target.matches?.("[data-session-post-manage-state], [data-session-post-template-state]")) {
    target.hidden = !message;
  }
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

function buildSessionPayload(form) {
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
    p_session_tool: nullableText(getValue(form, "p_session_tool")),
    p_player_min: playerMin,
    p_player_max: playerMax,
    p_summary: nullableText(getValue(form, "p_summary")),
    p_visibility: getValue(form, "p_visibility"),
    p_status: getValue(form, "p_status")
  };
}

function buildCreatePayload(form) {
  return {
    ...buildSessionPayload(form),
    p_level_range: null,
    p_request_body: null,
    p_requirements: null
  };
}

function buildUpdatePayload(form, session) {
  const sessionId = String(session?.id ?? "").trim();
  if (!sessionId) throw new Error("session_not_found");
  return {
    p_session_id: sessionId,
    ...buildSessionPayload(form),
    p_session_tool: getValue(form, "p_session_tool")
  };
}

function buildDeletePayload(session) {
  const sessionId = String(session?.id ?? "").trim();
  if (!sessionId) throw new Error("session_not_found");
  return { p_session_id: sessionId };
}

function redactTemplateText(value) {
  return String(value ?? "")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[非表示]")
    .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[非表示]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, "[非表示]")
    .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[非表示]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[非表示]");
}

function assertOnlyTemplatePresetFields(rows) {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  for (const row of list) {
    if (!row || typeof row !== "object") continue;
    for (const key of Object.keys(row)) {
      if (!TEMPLATE_PRESET_FIELD_NAMES.has(String(key).toLowerCase())) {
        throw new Error("template-preset-field-returned");
      }
    }
  }
}

function normalizeTemplateType(value) {
  const templateType = String(value || "").trim().toLowerCase();
  return SESSION_POST_TEMPLATE_TYPE_VALUES.has(templateType) ? templateType : "";
}

function getTemplateTypeLabel(value) {
  const templateType = normalizeTemplateType(value);
  const option = SESSION_POST_TEMPLATE_TYPE_OPTIONS.find((item) => item.value === templateType);
  return option?.label || "その他";
}

function toTemplateDisplayName(value) {
  return redactTemplateText(value).replace(/[\r\n]+/g, " ").trim();
}

function collectSessionPostTemplateFields(form) {
  return SESSION_POST_TEMPLATE_FIELD_KEYS.reduce((fields, name) => {
    const control = getFormControl(form, name);
    fields[name] = control && "value" in control ? String(control.value ?? "") : "";
    return fields;
  }, {});
}

function buildSessionPostTemplateBody(form) {
  return JSON.stringify({
    format: SESSION_POST_TEMPLATE_FORMAT,
    fields: collectSessionPostTemplateFields(form)
  });
}

function parseSessionPostTemplateBody(value) {
  const text = redactTemplateText(value).trim();
  if (!text) return null;

  try {
    const parsed = JSON.parse(text);
    const sourceFields = parsed?.format === SESSION_POST_TEMPLATE_FORMAT && parsed.fields && typeof parsed.fields === "object"
      ? parsed.fields
      : null;
    if (!sourceFields) return null;

    return SESSION_POST_TEMPLATE_FIELD_KEYS.reduce((fields, name) => {
      fields[name] = String(sourceFields[name] ?? "");
      return fields;
    }, {});
  } catch {
    return null;
  }
}

function validateTemplatePresetInput(nameValue, typeValue, bodyValue) {
  const rawName = String(nameValue || "");
  const templateName = toTemplateDisplayName(rawName);
  const templateType = normalizeTemplateType(typeValue);
  const templateBody = String(bodyValue || "");

  if (!templateName) {
    return { ok: false, message: "テンプレート名を入力してください。" };
  }
  if (/[\r\n]/.test(rawName)) {
    return { ok: false, message: "テンプレート名は1行で入力してください。" };
  }
  if (templateName.length > TEMPLATE_NAME_MAX_LENGTH) {
    return { ok: false, message: `テンプレート名は${TEMPLATE_NAME_MAX_LENGTH}文字以内で入力してください。` };
  }
  if (!templateType) {
    return { ok: false, message: "テンプレート種別を選んでください。" };
  }
  if (!templateBody.trim()) {
    return { ok: false, message: "テンプレート本文を作成できませんでした。" };
  }
  if (templateBody.length > TEMPLATE_BODY_MAX_LENGTH) {
    return { ok: false, message: `テンプレート本文は${TEMPLATE_BODY_MAX_LENGTH}文字以内で保存してください。` };
  }
  if (!parseSessionPostTemplateBody(templateBody)) {
    return { ok: false, message: "依頼書テンプレートとして保存できない内容です。" };
  }

  return {
    ok: true,
    message: "",
    templateName,
    templateType,
    templateBody
  };
}

function normalizeTemplatePresetRows(rows) {
  return (Array.isArray(rows) ? rows : []).map((row) => {
    const templateId = String(row?.template_id || "").trim();
    const templateType = normalizeTemplateType(row?.template_type);
    const templateBody = redactTemplateText(row?.template_body);
    const fields = parseSessionPostTemplateBody(templateBody);
    return {
      templateId,
      templateName: toTemplateDisplayName(row?.template_name) || "名称未設定",
      templateType,
      templateBody,
      fields,
      createdAt: String(row?.created_at || "").trim(),
      updatedAt: String(row?.updated_at || "").trim()
    };
  }).filter((row) => row.templateId && row.templateType && row.templateBody.trim() && row.fields);
}

async function queryTemplatePresets(client) {
  const { data, error } = await client.rpc(TEMPLATE_PRESETS_RPC);
  if (error) throw new Error("template-presets-rpc-failed");
  const rows = Array.isArray(data) ? data : [];
  assertOnlyTemplatePresetFields(rows);
  return rows;
}

async function createTemplatePreset(client, preset) {
  const { data, error } = await client.rpc(TEMPLATE_CREATE_RPC, {
    p_template_name: preset.templateName,
    p_template_type: preset.templateType,
    p_template_body: preset.templateBody
  });
  if (error) throw new Error("template-preset-create-failed");
  assertOnlyTemplatePresetFields(data);
  return Array.isArray(data) ? data[0] || null : data || null;
}

async function updateTemplatePreset(client, preset) {
  const { data, error } = await client.rpc(TEMPLATE_UPDATE_RPC, {
    p_template_id: preset.templateId,
    p_template_name: preset.templateName,
    p_template_type: preset.templateType,
    p_template_body: preset.templateBody,
    p_is_active: true
  });
  if (error) throw new Error("template-preset-update-failed");
  assertOnlyTemplatePresetFields(data);
  return Array.isArray(data) ? data[0] || null : data || null;
}

async function deactivateTemplatePreset(client, templateId) {
  const targetTemplateId = String(templateId || "").trim();
  if (!targetTemplateId) throw new Error("template-preset-target-missing");

  const { data, error } = await client.rpc(TEMPLATE_DEACTIVATE_RPC, {
    p_template_id: targetTemplateId
  });
  if (error) throw new Error("template-preset-deactivate-failed");
  assertOnlyTemplatePresetFields(data);
}

function applySessionPostTemplateFields(form, fields) {
  if (!fields || typeof fields !== "object") return;
  setFormValue(form, "p_title", fields.p_title);
  setFormValue(form, "p_start_at", fields.p_start_at);
  setFormValue(form, "p_end_at", fields.p_end_at);
  setFormValue(form, "p_application_deadline", fields.p_application_deadline);
  setFormValue(form, "p_session_tool", fields.p_session_tool);
  setFormValue(form, "p_player_min", fields.p_player_min);
  setFormValue(form, "p_player_max", fields.p_player_max);
  setFormValue(form, "p_summary", fields.p_summary);
  setSelectValue(form, "p_session_type", fields.p_session_type, "one-shot", getSessionTypeLabel);
  setSelectValue(form, "p_visibility", fields.p_visibility, "hidden", (value) => VISIBILITY_LABELS[value] || value);
  setSelectValue(form, "p_status", fields.p_status, "draft", getSessionStatusLabel);
  const publicConfirm = getFormControl(form, "public_confirm");
  if (publicConfirm && "checked" in publicConfirm) publicConfirm.checked = false;
}

async function getPostingAccess(client) {
  const adminResult = await client.rpc("is_admin");
  const isAdmin = !adminResult.error && Boolean(adminResult.data);
  return {
    canPost: true,
    isAdmin,
    isGm: false
  };
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

function normalizeManagedSession(row, options = {}) {
  const date = String(row?.date ?? "").trim();
  const startTime = normalizeTime(row?.start_time);
  const endTime = normalizeTime(row?.end_time);
  const endAt = formatJapanDateTime(row?.end_at);
  const applicationDeadline = formatJapanDateTime(row?.application_deadline);
  const sessionTool = String(row?.session_tool ?? "").trim();
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
    sessionTool,
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
    manageScope: options.manageScope === "admin" ? "admin" : "own",
    discordSyncStatus: String(row?.discord_sync_status ?? "").trim(),
    discordSyncStatusLabel: DISCORD_SYNC_STATUS_LABELS[String(row?.discord_sync_status ?? "").trim()] || "未設定",
    discordMessageId: String(row?.discord_message_id ?? "").trim(),
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
  const scopeLabel = session.manageScope === "admin" ? "管理" : "自分";
  return `<option value="manage-${Number(index)}">${escapeHtml(`【${scopeLabel}】${formatManagedOptionDate(session)} ${session.title}（${session.statusLabel}・${session.visibilityLabel}）`)}</option>`;
}

function getManagedSessionIndex(elements, session) {
  if (!session) return -1;
  const byReference = elements.managedSessions.findIndex((item) => item === session);
  if (byReference >= 0) return byReference;
  const sessionId = String(session.id ?? "").trim();
  return elements.managedSessions.findIndex((item) => sessionId && item.id === sessionId);
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
  setFormValue(form, "p_session_tool", session.sessionTool);
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
  setFormValue(form, "p_session_tool", "");
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

function setEditControls(elements, isEditing) {
  elements.submit.disabled = Boolean(isEditing);
  elements.submit.hidden = Boolean(isEditing);
  elements.save.hidden = !isEditing;
  elements.save.disabled = !isEditing;
  elements.save.textContent = "変更を保存";
  if (elements.deleteButton) {
    elements.deleteButton.hidden = !isEditing;
    elements.deleteButton.disabled = !isEditing;
    elements.deleteButton.textContent = "削除";
  }
}

function enterEditMode(elements, session) {
  elements.currentSession = session;
  fillFormFromManagedSession(elements.form, session);
  elements.formPanel.classList.add("is-editing");
  elements.form.classList.add("is-editing");
  elements.modeTitle.textContent = "依頼書";
  elements.modeNote.textContent = "選択中の依頼書を編集中です。内容を変更したら「変更を保存」を押してください。";
  setEditControls(elements, true);
  elements.resultPanel.hidden = true;
  setState(elements.formState, "選択中の依頼書を編集中です。");
  setState(elements.manageState, "");
  updatePublicationHint(elements);
  elements.refreshTemplateControls?.();
  replaceSelectedSessionId("");
}

function enterNewMode(elements, options = {}) {
  elements.currentSession = null;
  if (options.clearForm) resetFormForNewSession(elements.form);
  elements.formPanel.classList.remove("is-editing");
  elements.form.classList.remove("is-editing");
  elements.modeTitle.textContent = "依頼書";
  elements.modeNote.textContent = "初期値は非公開の下書きです。";
  setEditControls(elements, false);
  if (options.clearResult) elements.resultPanel.hidden = true;
  if (options.clearForm) setState(elements.formState, "");
  setState(elements.manageState, "");
  updatePublicationHint(elements);
  elements.refreshTemplateControls?.();
  replaceSelectedSessionId("");
}

function validatePublicSave(payload) {
  if (payload.p_visibility === "public" && payload.p_status === "draft") {
    return DRAFT_PUBLIC_MESSAGE;
  }
  return "";
}

function requirePublicConfirm(form, payload) {
  return payload.p_visibility === "public" && new FormData(form).get("public_confirm") !== "yes";
}

function getPublicationHint(visibility, status) {
  if (visibility === "public" && status === "draft") {
    return DRAFT_PUBLIC_MESSAGE;
  }
  if (STATUS_CLOSED_HINTS[status]) {
    if (status === "canceled") return STATUS_CLOSED_HINTS[status];
    return visibility === "public"
      ? STATUS_CLOSED_HINTS[status]
      : `${STATUS_CLOSED_HINTS[status]} ${PUBLICATION_HIDDEN_HINT}`;
  }
  if (visibility !== "public" || status === "draft") {
    return PUBLICATION_HIDDEN_HINT;
  }
  return PUBLICATION_ACTIVE_HINT;
}

function updatePublicationHint(elements) {
  const target = elements.publicationNote;
  if (!target) return;
  if (!elements.currentSession) {
    target.textContent = "";
    target.hidden = true;
    return;
  }
  const message = getPublicationHint(getValue(elements.form, "p_visibility"), getValue(elements.form, "p_status"));
  target.textContent = message;
  target.hidden = !message;
}

function getSaveSuccessMessage(payload) {
  return payload.p_visibility === "public" ? PUBLIC_SAVE_SUCCESS_MESSAGE : SAVE_SUCCESS_MESSAGE;
}

function appendDiscordSyncMessage(message, syncResult, options = {}) {
  const syncMessage = getDiscordSyncUiMessage(syncResult, options);
  return syncMessage ? `${message} ${syncMessage}` : message;
}

function shouldRedirectToSessionDetailAfterSave(payload) {
  return payload?.p_visibility === "public" && payload?.p_status !== "draft";
}

function normalizeSessionDetailId(value) {
  return String(value ?? "").trim();
}

function resolveSavedSessionId(result, fallbackId = "") {
  return normalizeSessionDetailId(result?.id)
    || normalizeSessionDetailId(result?.session_id)
    || normalizeSessionDetailId(fallbackId);
}

function redirectToSessionDetail(sessionId) {
  const targetId = normalizeSessionDetailId(sessionId);
  if (!targetId) return false;
  window.location.assign(`session-detail.html?id=${encodeURIComponent(targetId)}`);
  return true;
}

function getUpdateErrorMessage(error) {
  const text = [
    error?.message,
    error?.details,
    error?.hint,
    error?.code
  ].map((value) => String(value || "")).join(" ");
  const key = Object.keys(UPDATE_ERROR_MESSAGES).find((name) => text.includes(name));
  return key ? UPDATE_ERROR_MESSAGES[key] : SAVE_ERROR_MESSAGE;
}

function getDeleteErrorMessage(error) {
  const text = [
    error?.message,
    error?.details,
    error?.hint,
    error?.code
  ].map((value) => String(value || "")).join(" ");
  const key = Object.keys(DELETE_ERROR_MESSAGES).find((name) => text.includes(name));
  return key ? DELETE_ERROR_MESSAGES[key] : DELETE_ERROR_MESSAGE;
}

function normalizeManagedSessionFromUpdate(previousSession, payload, result) {
  return normalizeManagedSession({
    id: previousSession.id,
    title: payload.p_title,
    date: payload.p_session_date,
    start_time: payload.p_start_time,
    end_time: payload.p_end_time,
    end_at: payload.p_end_at,
    application_deadline: payload.p_application_deadline,
    session_tool: payload.p_session_tool,
    session_type: payload.p_session_type,
    player_min: payload.p_player_min,
    player_max: payload.p_player_max,
    summary: payload.p_summary,
    visibility: payload.p_visibility,
    status: payload.p_status,
    discord_sync_status: result?.discord_sync_status || previousSession.discordSyncStatus,
    discord_message_id: previousSession.discordMessageId,
    created_at: previousSession.createdAt,
    updated_at: result?.updated_at || previousSession.updatedAt
  });
}

function updateManagedSessionMemory(elements, updatedSession, previousSession) {
  const index = getManagedSessionIndex(elements, previousSession);
  if (index < 0) {
    elements.currentSession = updatedSession;
    return;
  }
  elements.managedSessions[index] = updatedSession;
  elements.currentSession = updatedSession;
  setManageSelectOptions(elements, elements.managedSessions);
  elements.select.value = `manage-${index}`;
}

async function saveManagedSession(client, elements) {
  if (!elements.currentSession || elements.isSaving) return;

  const previousSession = elements.currentSession;
  elements.isSaving = true;
  elements.resultPanel.hidden = true;
  elements.save.disabled = true;
  elements.save.textContent = "保存中...";
  elements.submit.disabled = true;
  setState(elements.formState, "保存中...");

  try {
    const payload = buildUpdatePayload(elements.form, previousSession);
    const validationMessage = validatePublicSave(payload);
    if (validationMessage) {
      setState(elements.formState, validationMessage, "is-error");
      return;
    }
    if (requirePublicConfirm(elements.form, payload)) {
      setState(elements.formState, "公開状態で保存する場合は確認してください。", "is-error");
      return;
    }

    const { data, error } = await client.rpc("update_session_post", payload);
    if (error) throw error;

    const result = Array.isArray(data) ? data[0] : data;
    if (!result || typeof result !== "object") throw new Error("invalid-result");

    const syncResult = await syncUpdatedSession(client, {
      sessionId: resolveSavedSessionId(result, previousSession.id),
      payload,
      session: previousSession
    });
    const resultForMemory = syncResult.ok && syncResult.attempted
      ? { ...result, discord_sync_status: "posted" }
      : result;
    const updatedSession = normalizeManagedSessionFromUpdate(previousSession, payload, resultForMemory);
    updateManagedSessionMemory(elements, updatedSession, previousSession);
    fillFormFromManagedSession(elements.form, updatedSession);
    updatePublicationHint(elements);
    elements.refreshTemplateControls?.();
    setState(
      elements.formState,
      appendDiscordSyncMessage(getSaveSuccessMessage(payload), syncResult),
      getDiscordSyncStateModifier(syncResult)
    );
    setState(elements.manageState, "");
    if (shouldRedirectToSessionDetailAfterSave(payload)) {
      redirectToSessionDetail(resolveSavedSessionId(result, updatedSession.id));
    }
  } catch (error) {
    setState(elements.formState, getUpdateErrorMessage(error), "is-error");
  } finally {
    elements.isSaving = false;
    if (elements.currentSession) {
      setEditControls(elements, true);
    }
  }
}

async function deleteManagedSession(client, elements) {
  if (!elements.currentSession || elements.isDeleting || elements.isSaving) return;
  if (!window.confirm(DELETE_CONFIRM_MESSAGE)) return;

  const previousSession = elements.currentSession;
  elements.isDeleting = true;
  elements.resultPanel.hidden = true;
  elements.save.disabled = true;
  if (elements.deleteButton) {
    elements.deleteButton.disabled = true;
    elements.deleteButton.textContent = "削除中...";
  }
  elements.submit.disabled = true;
  elements.select.disabled = true;
  setState(elements.formState, "削除しています。");

  try {
    const payload = buildDeletePayload(previousSession);
    if (hasDiscordPostReference(previousSession)) {
      const syncResult = await deleteSyncedSession(client, {
        session: previousSession,
        sessionId: payload.p_session_id
      });
      if (!syncResult.ok) {
        throw new Error("discord_sync_delete_failed");
      }
    } else {
      const { error } = await client.rpc("delete_session_post", payload);
      if (error) throw error;
    }

    const index = getManagedSessionIndex(elements, previousSession);
    if (index >= 0) {
      elements.managedSessions.splice(index, 1);
    }
    setManageSelectOptions(elements, elements.managedSessions);
    enterNewMode(elements, { clearForm: true, clearResult: true });
    elements.select.value = "new";
    setState(elements.formState, DELETE_SUCCESS_MESSAGE, "is-ok");
    if (!elements.managedSessions.length) {
      const emptyMessage = elements.access?.isAdmin
        ? "管理対象の依頼書は見つかりませんでした。"
        : "自分の依頼書はまだありません。";
      setState(elements.manageState, emptyMessage);
    }
  } catch (error) {
    setState(elements.formState, getDeleteErrorMessage(error), "is-error");
  } finally {
    elements.isDeleting = false;
    elements.select.disabled = false;
    if (elements.currentSession) {
      setEditControls(elements, true);
    } else {
      setEditControls(elements, false);
    }
  }
}

function setManageSelectOptions(elements, sessions) {
  const baseLabel = elements.access?.isAdmin ? "管理対象の依頼書" : "自分の依頼書";
  const countLabel = sessions.length ? `${baseLabel}（${sessions.length}件）` : baseLabel;
  elements.manageLabel.textContent = countLabel;
  elements.select.innerHTML = [
    `<option value="new">新規依頼書を書く</option>`,
    ...sessions.map((session, index) => renderManagedSessionOption(session, index))
  ].join("");
  elements.select.disabled = false;
}

function normalizeManageSessions(rows, access) {
  const currentUserId = String(access?.userId || "").trim();
  const isAdmin = Boolean(access?.isAdmin);
  return rows.reduce((sessions, row) => {
    const ownerUserId = String(row?.gm_user_id || "").trim();
    const isOwn = Boolean(currentUserId && ownerUserId && currentUserId === ownerUserId);
    if (!isAdmin && !isOwn) return sessions;
    sessions.push(normalizeManagedSession(row, {
      manageScope: isOwn ? "own" : "admin"
    }));
    return sessions;
  }, []);
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
    const message = elements.access?.isAdmin
      ? "管理対象の依頼書を取得できませんでした。管理用RPCの追加が必要です。"
      : "依頼書一覧を取得できませんでした。";
    setState(state, message, "is-error");
    return;
  }

  const sessions = Array.isArray(data) ? normalizeManageSessions(data, elements.access) : [];
  elements.managedSessions = sessions;
  setManageSelectOptions(elements, sessions);

  if (!sessions.length) {
    const emptyMessage = elements.access?.isAdmin
      ? "管理対象の依頼書は見つかりませんでした。"
      : "自分の依頼書はまだありません。";
    setState(state, emptyMessage);
    if (readSelectedSessionId()) {
      setState(elements.formState, "編集対象の依頼書が見つかりません。静的データ由来、または権限のない予定は編集できません。", "is-error");
      replaceSelectedSessionId("");
    }
    select.value = "new";
    return;
  }

  setState(state, "");
  const selectedSessionId = readSelectedSessionId();
  const selectedIndex = sessions.findIndex((session) => selectedSessionId && session.id === selectedSessionId);
  if (selectedSessionId && selectedIndex < 0) {
    setState(elements.formState, "編集対象の依頼書が見つかりません。静的データ由来、または権限のない予定は編集できません。", "is-error");
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

async function initializeSessionPostTemplateUi(client, elements) {
  const ui = elements.templateUi;
  if (!ui?.panel) return;

  let presetRows = [];
  let selectedTemplateId = "";
  let presetsByKey = new Map();
  let isTemplateOperation = false;

  const getSelectedPreset = () => (
    selectedTemplateId
      ? presetRows.find((preset) => preset.templateId === selectedTemplateId) || null
      : null
  );

  const buildValidatedPreset = () => {
    let templateBody = "";
    try {
      templateBody = buildSessionPostTemplateBody(elements.form);
    } catch {
      templateBody = "";
    }
    return validateTemplatePresetInput(ui.name.value, ui.type.value, templateBody);
  };

  const renderPresetOptions = () => {
    const selectedPresetExists = Boolean(getSelectedPreset());
    if (!selectedPresetExists) selectedTemplateId = "";

    presetsByKey = new Map();
    ui.select.replaceChildren();

    const blankOption = document.createElement("option");
    blankOption.value = "";
    blankOption.textContent = presetRows.length
      ? "新規テンプレートとして編集"
      : "保存済みテンプレートはありません";
    ui.select.append(blankOption);

    presetRows.forEach((preset, index) => {
      const optionKey = `template-${index}`;
      presetsByKey.set(optionKey, preset);

      const option = document.createElement("option");
      option.value = optionKey;
      option.textContent = `${preset.templateName}（${getTemplateTypeLabel(preset.templateType)}）`;
      option.selected = preset.templateId === selectedTemplateId;
      ui.select.append(option);
    });
  };

  const updateTemplateControls = (showValidation = false) => {
    const validation = buildValidatedPreset();
    const selectedPreset = getSelectedPreset();
    const isUnavailable = isTemplateOperation;

    ui.name.disabled = isTemplateOperation;
    ui.type.disabled = isTemplateOperation;
    ui.select.disabled = isUnavailable || !presetRows.length;
    ui.createButton.disabled = isUnavailable || !validation.ok;
    ui.updateButton.disabled = isUnavailable || !selectedPreset || !validation.ok;
    ui.deleteButton.disabled = isUnavailable || !selectedPreset;
    ui.applyButton.disabled = isUnavailable || !selectedPreset;

    if (showValidation && !validation.ok) {
      setState(ui.state, validation.message, "is-error");
    }
  };

  const applyPresetMetadataToControls = (preset) => {
    if (!preset) return;
    ui.name.value = preset.templateName;
    ui.type.value = normalizeTemplateType(preset.templateType) || "session_post";
    updateTemplateControls(false);
  };

  const loadTemplatePresets = async (preferredTemplateId = selectedTemplateId) => {
    const rows = await queryTemplatePresets(client);
    presetRows = normalizeTemplatePresetRows(rows);
    selectedTemplateId = presetRows.some((preset) => preset.templateId === preferredTemplateId)
      ? preferredTemplateId
      : "";
    renderPresetOptions();
    const selectedPreset = getSelectedPreset();
    if (selectedPreset) applyPresetMetadataToControls(selectedPreset);
    updateTemplateControls(false);
    return selectedPreset;
  };

  const runTemplateOperation = async (operation, progressMessage, successMessage, errorMessage) => {
    if (isTemplateOperation) return;

    isTemplateOperation = true;
    ui.panel.setAttribute("aria-busy", "true");
    setState(ui.state, progressMessage, "is-warn");
    updateTemplateControls(false);

    try {
      await operation();
      setState(ui.state, successMessage, "is-ok");
    } catch {
      setState(ui.state, errorMessage, "is-error");
    } finally {
      isTemplateOperation = false;
      ui.panel.removeAttribute("aria-busy");
      updateTemplateControls(false);
    }
  };

  const handleCreatePreset = async () => {
    const validation = buildValidatedPreset();
    if (!validation.ok) {
      setState(ui.state, validation.message, "is-error");
      updateTemplateControls(false);
      return;
    }

    await runTemplateOperation(
      async () => {
        const created = normalizeTemplatePresetRows([
          await createTemplatePreset(client, validation)
        ])[0];
        selectedTemplateId = created?.templateId || "";
        const selectedPreset = await loadTemplatePresets(selectedTemplateId);
        if (selectedPreset) applyPresetMetadataToControls(selectedPreset);
      },
      "テンプレートを保存しています。",
      "テンプレートを保存しました。",
      "テンプレートを保存できませんでした。時間をおいて再読み込みしてください。"
    );
  };

  const handleUpdatePreset = async () => {
    const selectedPreset = getSelectedPreset();
    const validation = buildValidatedPreset();
    if (!selectedPreset) {
      setState(ui.state, "保存済みテンプレートを選んでください。", "is-error");
      updateTemplateControls(false);
      return;
    }
    if (!validation.ok) {
      setState(ui.state, validation.message, "is-error");
      updateTemplateControls(false);
      return;
    }

    await runTemplateOperation(
      async () => {
        const updated = normalizeTemplatePresetRows([
          await updateTemplatePreset(client, {
            ...validation,
            templateId: selectedPreset.templateId
          })
        ])[0];
        selectedTemplateId = updated?.templateId || selectedPreset.templateId;
        const reloadedPreset = await loadTemplatePresets(selectedTemplateId);
        if (reloadedPreset) applyPresetMetadataToControls(reloadedPreset);
      },
      "テンプレートを保存しています。",
      "変更を保存しました。",
      "テンプレートを保存できませんでした。時間をおいて再読み込みしてください。"
    );
  };

  const handleDeletePreset = async () => {
    const selectedPreset = getSelectedPreset();
    if (!selectedPreset) {
      setState(ui.state, "保存済みテンプレートを選んでください。", "is-error");
      updateTemplateControls(false);
      return;
    }
    if (!window.confirm("このテンプレートを削除します。テンプレートは一覧から外れます。続けますか？")) return;

    await runTemplateOperation(
      async () => {
        await deactivateTemplatePreset(client, selectedPreset.templateId);
        selectedTemplateId = "";
        await loadTemplatePresets("");
        ui.select.value = "";
      },
      "テンプレートを削除しています。",
      "テンプレートを削除しました。",
      "テンプレートを削除できませんでした。時間をおいて再読み込みしてください。"
    );
  };

  const handleApplyPreset = () => {
    const selectedPreset = getSelectedPreset();
    if (!selectedPreset) {
      setState(ui.state, "反映するテンプレートを選んでください。", "is-error");
      updateTemplateControls(false);
      return;
    }

    if (elements.currentSession && !window.confirm(SESSION_POST_TEMPLATE_APPLY_CONFIRM_MESSAGE)) return;

    applySessionPostTemplateFields(elements.form, selectedPreset.fields);
    updatePublicationHint(elements);
    updateTemplateControls(false);
    setState(ui.state, "テンプレートをフォームに反映しました。", "is-ok");
  };

  ui.select.addEventListener("change", () => {
    const preset = presetsByKey.get(ui.select.value);
    if (!preset) {
      selectedTemplateId = "";
      updateTemplateControls(false);
      setState(ui.state, "");
      return;
    }

    selectedTemplateId = preset.templateId;
    applyPresetMetadataToControls(preset);
    setState(ui.state, "テンプレートを選びました。「反映」でフォームに適用します。", "is-ok");
  });

  ui.name.addEventListener("input", () => {
    updateTemplateControls(false);
    if (!isTemplateOperation) setState(ui.state, "");
  });

  ui.type.addEventListener("change", () => {
    updateTemplateControls(false);
    if (!isTemplateOperation) setState(ui.state, "");
  });

  elements.form.addEventListener("input", () => {
    updateTemplateControls(false);
  });
  elements.form.addEventListener("change", () => {
    updateTemplateControls(false);
  });

  ui.createButton.addEventListener("click", () => {
    void handleCreatePreset();
  });
  ui.updateButton.addEventListener("click", () => {
    void handleUpdatePreset();
  });
  ui.deleteButton.addEventListener("click", () => {
    void handleDeletePreset();
  });
  ui.applyButton.addEventListener("click", () => {
    handleApplyPreset();
  });

  elements.refreshTemplateControls = () => updateTemplateControls(false);
  updateTemplateControls(false);
  setState(ui.state, "保存済みテンプレートを読み込んでいます。", "is-warn");

  try {
    await loadTemplatePresets("");
    setState(ui.state, presetRows.length ? "" : "保存済みテンプレートはありません。");
  } catch {
    setState(ui.state, "保存済みテンプレートを取得できませんでした。", "is-error");
  }
}

async function initializeForm(root, client, access = {}) {
  const formPanel = root.querySelector("[data-session-post-form-panel]");
  const form = root.querySelector("[data-session-post-form]");
  const submit = root.querySelector("[data-session-post-submit]");
  const save = root.querySelector("[data-session-post-save]");
  const deleteButton = root.querySelector("[data-session-post-delete]");
  const state = root.querySelector("[data-session-post-state]");
  const resultPanel = root.querySelector("[data-session-post-result-panel]");
  const resultList = root.querySelector("[data-session-post-result]");
  const manageElements = {
    currentSession: null,
    managedSessions: [],
    access,
    formPanel,
    form,
    submit,
    save,
    deleteButton,
    formState: state,
    resultPanel,
    modeTitle: root.querySelector("[data-session-post-mode-title]"),
    modeNote: root.querySelector("[data-session-post-mode-note]"),
    publicationNote: root.querySelector("[data-session-post-publication-note]"),
    panel: root.querySelector("[data-session-post-manage-panel]"),
    select: root.querySelector("[data-session-post-manage-select]"),
    manageLabel: root.querySelector("[data-session-post-manage-label]"),
    manageState: root.querySelector("[data-session-post-manage-state]"),
    state: root.querySelector("[data-session-post-manage-state]"),
    templateUi: {
      panel: root.querySelector("[data-session-post-template-panel]"),
      select: root.querySelector("[data-session-post-template-select]"),
      name: root.querySelector("[data-session-post-template-name]"),
      type: root.querySelector("[data-session-post-template-type]"),
      createButton: root.querySelector("[data-session-post-template-create]"),
      updateButton: root.querySelector("[data-session-post-template-update]"),
      deleteButton: root.querySelector("[data-session-post-template-delete]"),
      applyButton: root.querySelector("[data-session-post-template-apply]"),
      state: root.querySelector("[data-session-post-template-state]")
    }
  };

  formPanel.hidden = false;
  await loadManagedSessions(client, manageElements);
  await initializeSessionPostTemplateUi(client, manageElements);
  save.addEventListener("click", () => {
    saveManagedSession(client, manageElements);
  });
  deleteButton?.addEventListener("click", () => {
    deleteManagedSession(client, manageElements);
  });
  form.addEventListener("change", (event) => {
    if (event.target?.name === "p_visibility" || event.target?.name === "p_status") {
      updatePublicationHint(manageElements);
    }
  });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (manageElements.currentSession) {
      await saveManagedSession(client, manageElements);
      return;
    }
    resultPanel.hidden = true;
    setState(state, "送信しています。");
    submit.disabled = true;

    try {
      const payload = buildCreatePayload(form);
      const validationMessage = validatePublicSave(payload);
      if (validationMessage) {
        setState(state, validationMessage, "is-error");
        submit.disabled = false;
        return;
      }
      if (requirePublicConfirm(form, payload)) {
        setState(state, "公開状態で保存する場合は確認してください。", "is-error");
        submit.disabled = false;
        return;
      }

      const { data, error } = await client.rpc("create_session_post", payload);
      if (error) throw error;
      const result = Array.isArray(data) ? data[0] : data;
      if (!result || typeof result !== "object") throw new Error("invalid-result");
      const syncResult = await syncCreatedSession(client, {
        sessionId: resolveSavedSessionId(result),
        payload
      });
      setState(
        state,
        appendDiscordSyncMessage("作成しました。", syncResult),
        getDiscordSyncStateModifier(syncResult)
      );
      renderResult(resultList, syncResult.ok && syncResult.attempted
        ? { ...result, discord_sync_status: "posted" }
        : result);
      resultPanel.hidden = false;
      if (shouldRedirectToSessionDetailAfterSave(payload) && redirectToSessionDetail(resolveSavedSessionId(result))) {
        return;
      }
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

    const access = await getPostingAccess(client);
    access.userId = String(data.session.user?.id || "").trim();

    setState(authState, access.isAdmin ? "admin権限で管理できます。" : "ログインユーザーとして投稿できます。", "is-ok");
    await initializeForm(root, client, access);
  } catch {
    setState(authState, "依頼書投稿の準備に失敗しました。", "is-error");
  }
}
