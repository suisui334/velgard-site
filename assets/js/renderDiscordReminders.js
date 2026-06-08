import { escapeHtml } from "./sessionDisplay.js?v=20260603-delete-equivalent";
import {
  buildDiscordReminderCreatePayload,
  getDiscordReminderAllowedMentionsPolicy,
  getDiscordReminderRpcNames,
  validateDiscordReminderPayload
} from "./discordReminderClient.js?v=20260608-discord-reminder-mvp";

const CHANNEL_OPTIONS = Object.freeze([
  { value: "session-reminders", label: "セッション告知" },
  { value: "gm-notices", label: "GM向け連絡" },
  { value: "site-updates", label: "サイト更新" }
]);

function formatLocalDateTime(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate())
  ].join("-") + `T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function getDefaultScheduledAt() {
  const date = new Date();
  date.setHours(date.getHours() + 1, 0, 0, 0);
  return formatLocalDateTime(date);
}

function renderChannelOptions() {
  return CHANNEL_OPTIONS.map((option) => (
    `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`
  )).join("");
}

function renderShell() {
  return `
    <header class="page-title">
      <div class="eyebrow">Discord Reminder</div>
      <h1>Discordリマインダー管理</h1>
      <p class="lead">指定した時刻に、事前登録した日本語テキストをDiscordへ投稿するための予約入力画面です。</p>
    </header>
    <section class="section discord-reminder-section">
      <article class="article-box discord-reminder-status-panel">
        <h2>MVP準備状況</h2>
        <p>この画面はDB/RPC適用前の低リスク骨格です。現在は入力内容の検証と将来RPC payloadの確認のみ行います。</p>
        <dl class="discord-reminder-rpc-list">
          ${Object.entries(getDiscordReminderRpcNames()).map(([label, name]) => `
            <div>
              <dt>${escapeHtml(label)}</dt>
              <dd>${escapeHtml(name)}</dd>
            </div>
          `).join("")}
        </dl>
      </article>
      <article class="article-box discord-reminder-form-panel">
        <div class="discord-reminder-form-head">
          <h2>予約内容</h2>
          <p>投稿先は公開IDではなく管理キーで扱い、実チャンネルへの対応はサーバー側で管理します。</p>
        </div>
        <form class="discord-reminder-form" data-discord-reminder-form>
          <div class="discord-reminder-grid">
            <label class="discord-reminder-field">
              <span>投稿先チャンネル</span>
              <select name="channelKey" required>
                ${renderChannelOptions()}
              </select>
            </label>
            <label class="discord-reminder-field">
              <span>投稿予定日時</span>
              <input type="datetime-local" name="scheduledAt" value="${escapeHtml(getDefaultScheduledAt())}" required>
            </label>
            <label class="discord-reminder-field">
              <span>タイムゾーン</span>
              <select name="timezone">
                <option value="Asia/Tokyo" selected>Asia/Tokyo</option>
              </select>
            </label>
            <fieldset class="discord-reminder-field discord-reminder-mention-field">
              <legend>通知モード</legend>
              <label>
                <input type="radio" name="mentionMode" value="none" checked>
                <span>通知なし</span>
              </label>
              <label>
                <input type="radio" name="mentionMode" value="everyone">
                <span>@everyone</span>
              </label>
            </fieldset>
            <label class="discord-reminder-field discord-reminder-field--wide">
              <span>投稿テキスト</span>
              <textarea name="messageBody" rows="7" maxlength="1800" required placeholder="例：本日のセッション開始30分前です。準備ができた方から集合してください。"></textarea>
            </label>
          </div>
          <div class="discord-reminder-submit-row">
            <button class="button primary" type="submit">内容を確認</button>
            <button class="button" type="reset">入力をリセット</button>
            <p class="discord-reminder-state" data-discord-reminder-state aria-live="polite"></p>
          </div>
        </form>
      </article>
      <article class="article-box discord-reminder-preview-panel" data-discord-reminder-preview hidden>
        <h2>保存予定payload</h2>
        <dl class="discord-reminder-preview-list" data-discord-reminder-preview-list></dl>
        <pre class="discord-reminder-payload" data-discord-reminder-payload></pre>
      </article>
    </section>
  `;
}

function setState(element, message, modifier = "") {
  if (!element) return;
  element.textContent = message;
  element.classList.toggle("is-ok", modifier === "is-ok");
  element.classList.toggle("is-error", modifier === "is-error");
}

function collectFormInput(form) {
  const data = new FormData(form);
  return {
    channelKey: data.get("channelKey"),
    scheduledAt: data.get("scheduledAt"),
    timezone: data.get("timezone"),
    mentionMode: data.get("mentionMode"),
    messageBody: data.get("messageBody")
  };
}

function renderPreview(list, payload) {
  const allowedMentions = getDiscordReminderAllowedMentionsPolicy(payload.p_mention_mode);
  const rows = [
    ["投稿先キー", payload.p_channel_key],
    ["投稿予定日時", payload.p_scheduled_at],
    ["タイムゾーン", payload.p_timezone],
    ["通知モード", payload.p_mention_mode === "everyone" ? "@everyone" : "通知なし"],
    ["allowed_mentions.parse", allowedMentions.parse.length ? allowedMentions.parse.join(", ") : "[]"],
    ["文字数", `${payload.p_message_body.length} / 1800`]
  ];

  list.innerHTML = rows.map(([label, value]) => `
    <div>
      <dt>${escapeHtml(label)}</dt>
      <dd>${escapeHtml(value)}</dd>
    </div>
  `).join("");
}

function createPayloadJson(payload) {
  return JSON.stringify({
    rpc: "create_discord_reminder",
    payload,
    delivery_policy: {
      allowed_mentions: getDiscordReminderAllowedMentionsPolicy(payload.p_mention_mode)
    }
  }, null, 2);
}

export async function renderDiscordReminders(root) {
  root.innerHTML = renderShell();

  const form = root.querySelector("[data-discord-reminder-form]");
  const state = root.querySelector("[data-discord-reminder-state]");
  const preview = root.querySelector("[data-discord-reminder-preview]");
  const previewList = root.querySelector("[data-discord-reminder-preview-list]");
  const payloadBlock = root.querySelector("[data-discord-reminder-payload]");

  form.addEventListener("reset", () => {
    window.requestAnimationFrame(() => {
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, "");
    });
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const payload = buildDiscordReminderCreatePayload(collectFormInput(form));
    const validation = validateDiscordReminderPayload(payload);

    if (!validation.ok) {
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, validation.errors.join(" "), "is-error");
      return;
    }

    renderPreview(previewList, payload);
    payloadBlock.textContent = createPayloadJson(payload);
    preview.hidden = false;
    setState(state, "入力内容を確認しました。DB保存はRPC適用ゲート後に有効化します。", "is-ok");
  });
}
