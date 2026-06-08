import { escapeHtml } from "./sessionDisplay.js?v=20260603-delete-equivalent";
import {
  createSupabaseBrowserClient,
  getSupabaseRuntimeConfig,
  hasSupabaseRuntimeConfig
} from "./supabaseBrowserClient.js?v=20260601-session-post";
import {
  buildAdminCapAnnouncementCreatePayload,
  getAdminCapAnnouncementAllowedMentionsPolicy,
  getAdminCapAnnouncementRpcNames,
  validateAdminCapAnnouncementPayload
} from "./adminCapAnnouncementClient.js?v=20260608-admin-cap-announcements";

const TARGET_CHANNEL_OPTIONS = Object.freeze([
  { value: "cap_announcement", label: "キャップ更新告知" }
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

function renderTargetChannelOptions() {
  return TARGET_CHANNEL_OPTIONS.map((option) => (
    `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`
  )).join("");
}

function renderShell() {
  return `
    <header class="page-title">
      <div class="eyebrow">Admin Cap Announcement</div>
      <h1>adminキャップ更新告知</h1>
      <p class="lead">キャップ更新の案内を、指定時刻にDiscordへ投稿するためのadmin専用予約画面です。</p>
    </header>
    <section class="section admin-cap-announcement-section">
      <article class="article-box admin-cap-announcement-access-panel">
        <h2>admin権限</h2>
        <p class="admin-cap-announcement-state" data-admin-cap-announcement-access-state aria-live="polite">確認しています。</p>
        <p class="admin-cap-announcement-access-note">この画面はadmin専用です。フロント側の表示制御に加えて、DB/RPC/Edge Function側でもadmin確認を行う設計です。</p>
        <p class="admin-cap-announcement-actions">
          <a class="button" href="mypage.html">ACCOUNTへ</a>
        </p>
      </article>
      <article class="article-box admin-cap-announcement-status-panel" data-admin-cap-announcement-admin-panel hidden>
        <h2>MVP準備状況</h2>
        <p>現在はDB/RPC適用前の低リスク骨格です。入力検証と将来RPC payloadの確認だけを行い、DB保存やDiscord投稿は行いません。</p>
        <dl class="admin-cap-announcement-rpc-list">
          ${Object.entries(getAdminCapAnnouncementRpcNames()).map(([label, name]) => `
            <div>
              <dt>${escapeHtml(label)}</dt>
              <dd>${escapeHtml(name)}</dd>
            </div>
          `).join("")}
        </dl>
      </article>
      <article class="article-box admin-cap-announcement-form-panel" data-admin-cap-announcement-form-panel hidden>
        <div class="admin-cap-announcement-form-head">
          <h2>告知予約</h2>
          <p>投稿先は実チャンネル値ではなく target_channel_key で扱い、Webhook対応はEdge Function側のsecret/envに閉じます。</p>
        </div>
        <form class="admin-cap-announcement-form" data-admin-cap-announcement-form>
          <div class="admin-cap-announcement-grid">
            <label class="admin-cap-announcement-field">
              <span>告知タイトル</span>
              <input type="text" name="announcementTitle" maxlength="120" required placeholder="例：キャップ更新のお知らせ">
            </label>
            <label class="admin-cap-announcement-field">
              <span>投稿先チャンネルkey</span>
              <select name="targetChannelKey" required>
                ${renderTargetChannelOptions()}
              </select>
            </label>
            <label class="admin-cap-announcement-field">
              <span>投稿予定日時</span>
              <input type="datetime-local" name="scheduledAt" value="${escapeHtml(getDefaultScheduledAt())}" required>
            </label>
            <label class="admin-cap-announcement-field">
              <span>保存状態</span>
              <select name="status">
                <option value="draft" selected>draft</option>
                <option value="scheduled">scheduled</option>
              </select>
            </label>
            <label class="admin-cap-announcement-field">
              <span>キャップLv</span>
              <input type="text" name="capLevel" maxlength="40" placeholder="例：Lv7-8">
            </label>
            <label class="admin-cap-announcement-field">
              <span>適用開始日</span>
              <input type="date" name="applyStartDate">
            </label>
            <label class="admin-cap-announcement-field">
              <span>適用終了日</span>
              <input type="date" name="applyEndDate">
            </label>
            <label class="admin-cap-announcement-field">
              <span>タイムゾーン</span>
              <select name="timezone">
                <option value="Asia/Tokyo" selected>Asia/Tokyo</option>
              </select>
            </label>
            <fieldset class="admin-cap-announcement-field admin-cap-announcement-mention-field">
              <legend>メンション設定</legend>
              <label>
                <input type="radio" name="mentionMode" value="none" checked>
                <span>none</span>
              </label>
              <label>
                <input type="radio" name="mentionMode" value="everyone">
                <span>everyone</span>
              </label>
            </fieldset>
            <label class="admin-cap-announcement-field admin-cap-announcement-field--wide">
              <span>告知本文</span>
              <textarea name="announcementBody" rows="8" maxlength="1800" required placeholder="例：次回からキャップLvが更新されます。適用期間と成長処理を確認してください。"></textarea>
            </label>
            <label class="admin-cap-announcement-field admin-cap-announcement-field--wide">
              <span>補足文</span>
              <textarea name="note" rows="4" maxlength="500" placeholder="将来の自動生成や運用メモ用。Discord投稿本文とは分けて扱う想定です。"></textarea>
            </label>
          </div>
          <div class="admin-cap-announcement-submit-row">
            <button class="button primary" type="submit">内容を確認</button>
            <button class="button" type="reset">入力をリセット</button>
            <p class="admin-cap-announcement-state" data-admin-cap-announcement-state aria-live="polite"></p>
          </div>
        </form>
      </article>
      <article class="article-box admin-cap-announcement-preview-panel" data-admin-cap-announcement-preview hidden>
        <h2>保存予定payload</h2>
        <dl class="admin-cap-announcement-preview-list" data-admin-cap-announcement-preview-list></dl>
        <pre class="admin-cap-announcement-payload" data-admin-cap-announcement-payload></pre>
      </article>
    </section>
  `;
}

function setState(element, message, modifier = "") {
  if (!element) return;
  element.textContent = message;
  element.classList.toggle("is-ok", modifier === "is-ok");
  element.classList.toggle("is-error", modifier === "is-error");
  element.classList.toggle("is-warn", modifier === "is-warn");
}

function collectFormInput(form) {
  const data = new FormData(form);
  return {
    announcementTitle: data.get("announcementTitle"),
    announcementBody: data.get("announcementBody"),
    targetChannelKey: data.get("targetChannelKey"),
    scheduledAt: data.get("scheduledAt"),
    timezone: data.get("timezone"),
    mentionMode: data.get("mentionMode"),
    status: data.get("status"),
    capLevel: data.get("capLevel"),
    applyStartDate: data.get("applyStartDate"),
    applyEndDate: data.get("applyEndDate"),
    note: data.get("note")
  };
}

function isAdminResult(value) {
  if (value === true) return true;
  if (Array.isArray(value)) return value.some((item) => item === true || item?.is_admin === true);
  return value?.is_admin === true;
}

function renderPreview(list, payload) {
  const allowedMentions = getAdminCapAnnouncementAllowedMentionsPolicy(payload.p_mention_mode);
  const rows = [
    ["告知タイトル", payload.p_announcement_title],
    ["投稿先key", payload.p_target_channel_key],
    ["投稿予定日時", payload.p_scheduled_at],
    ["保存状態", payload.p_status],
    ["メンション設定", payload.p_mention_mode],
    ["allowed_mentions.parse", allowedMentions.parse.length ? allowedMentions.parse.join(", ") : "[]"],
    ["本文文字数", `${payload.p_announcement_body.length} / 1800`],
    ["エラー確認設計", "failed時は一覧でエラー有無を表示"]
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
    rpc: "create_admin_discord_announcement",
    payload,
    delivery_policy: {
      allowed_mentions: getAdminCapAnnouncementAllowedMentionsPolicy(payload.p_mention_mode)
    }
  }, null, 2);
}

function bindForm(root) {
  const form = root.querySelector("[data-admin-cap-announcement-form]");
  const state = root.querySelector("[data-admin-cap-announcement-state]");
  const preview = root.querySelector("[data-admin-cap-announcement-preview]");
  const previewList = root.querySelector("[data-admin-cap-announcement-preview-list]");
  const payloadBlock = root.querySelector("[data-admin-cap-announcement-payload]");

  form.addEventListener("reset", () => {
    window.requestAnimationFrame(() => {
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, "");
    });
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const payload = buildAdminCapAnnouncementCreatePayload(collectFormInput(form));
    const validation = validateAdminCapAnnouncementPayload(payload);

    if (!validation.ok) {
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, validation.errors.join(" "), "is-error");
      return;
    }

    renderPreview(previewList, payload);
    payloadBlock.textContent = createPayloadJson(payload);
    preview.hidden = false;
    setState(state, "入力内容を確認しました。DB保存はSQL/RPC適用ゲート後に有効化します。", "is-ok");
  });
}

export async function renderAdminCapAnnouncements(root) {
  root.innerHTML = renderShell();

  const accessState = root.querySelector("[data-admin-cap-announcement-access-state]");
  const adminPanel = root.querySelector("[data-admin-cap-announcement-admin-panel]");
  const formPanel = root.querySelector("[data-admin-cap-announcement-form-panel]");

  const config = getSupabaseRuntimeConfig();
  if (!hasSupabaseRuntimeConfig(config)) {
    setState(accessState, "権限確認の接続設定がありません。adminログイン後の本番環境で利用してください。", "is-error");
    return;
  }

  try {
    const client = await createSupabaseBrowserClient();
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError || !sessionData?.session) {
      setState(accessState, "adminログインが必要です。ACCOUNTからログインしてください。", "is-error");
      return;
    }

    const { data, error } = await client.rpc("is_admin");
    if (error || !isAdminResult(data)) {
      setState(accessState, "権限がありません。この画面はadmin専用です。", "is-error");
      return;
    }

    adminPanel.hidden = false;
    formPanel.hidden = false;
    bindForm(root);
    setState(accessState, "admin権限を確認しました。キャップ更新告知の内容確認ができます。", "is-ok");
  } catch {
    setState(accessState, "admin権限の確認に失敗しました。時間をおいて再読み込みしてください。", "is-error");
  }
}
