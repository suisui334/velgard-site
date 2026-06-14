import { escapeHtml } from "./sessionDisplay.js?v=20260615-session-summary-tags-extract";
import {
  createSupabaseBrowserClient,
  getSupabaseRuntimeConfig,
  hasSupabaseRuntimeConfig
} from "./supabaseBrowserClient.js?v=20260601-session-post";
import {
  buildAdminCapAnnouncementCreatePayload,
  cancelAdminCapAnnouncement,
  createAdminCapAnnouncement,
  getAdminCapAnnouncementAllowedMentionsPolicy,
  getAdminCapAnnouncementRpcNames,
  listAdminCapAnnouncements,
  updateAdminCapAnnouncement,
  validateAdminCapAnnouncementPayload
} from "./adminCapAnnouncementClient.js?v=20260610-admin-cap-rpc";

const TARGET_CHANNEL_OPTIONS = Object.freeze([
  { value: "cap_announcement", label: "キャップ更新告知" }
]);

const STATUS_LABELS = Object.freeze({
  draft: "下書き",
  scheduled: "予約済み",
  processing: "投稿処理中",
  posted: "投稿済み",
  failed: "失敗",
  canceled: "キャンセル"
});

const STATUS_FILTERS = Object.freeze([
  { value: "active", label: "有効のみ" },
  { value: "", label: "すべて" },
  { value: "draft", label: "下書き" },
  { value: "scheduled", label: "予約済み" },
  { value: "processing", label: "投稿処理中" },
  { value: "posted", label: "投稿済み" },
  { value: "failed", label: "失敗" },
  { value: "canceled", label: "キャンセル" }
]);

const RPC_STATUS_FILTERS = new Set(["draft", "scheduled", "processing", "posted", "failed", "canceled"]);
const ACTIVE_LIST_STATUSES = new Set(["draft", "scheduled", "processing", "failed"]);
const EDITABLE_STATUSES = new Set(["draft", "scheduled", "failed"]);
const CANCELABLE_STATUSES = new Set(["draft", "scheduled", "failed"]);

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

function formatDateTimeForInput(value) {
  if (!value) return getDefaultScheduledAt();
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return getDefaultScheduledAt();
  return formatLocalDateTime(date);
}

function formatDateTimeForDisplay(value) {
  if (!value) return "未設定";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat("ja-JP", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Tokyo"
  }).format(date);
}

function formatOptionalDate(value) {
  return value ? String(value) : "";
}

function getStatusLabel(status) {
  return STATUS_LABELS[status] || status || "未設定";
}

function renderTargetChannelOptions() {
  return TARGET_CHANNEL_OPTIONS.map((option) => (
    `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`
  )).join("");
}

function renderStatusFilterOptions() {
  return STATUS_FILTERS.map((option) => (
    `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`
  )).join("");
}

function getStatusFilterLabel(value) {
  return STATUS_FILTERS.find((option) => option.value === value)?.label || "すべて";
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
        <h2>RPC接続状況</h2>
        <p>admin確認後、browser/admin用RPCだけを使ってDBへ保存します。Discord投稿、Edge Function deploy、cron実行はまだ行いません。</p>
        <dl class="admin-cap-announcement-rpc-list">
          ${Object.entries(getAdminCapAnnouncementRpcNames()).map(([label, name]) => `
            <div>
              <dt>${escapeHtml(label)}</dt>
              <dd>${escapeHtml(name)}</dd>
            </div>
          `).join("")}
        </dl>
      </article>
      <article class="article-box admin-cap-announcement-list-panel" data-admin-cap-announcement-list-panel hidden>
        <div class="admin-cap-announcement-panel-head">
          <h2>告知一覧</h2>
          <div class="admin-cap-announcement-list-controls">
            <label>
              <span>状態</span>
              <select data-admin-cap-announcement-status-filter>
                ${renderStatusFilterOptions()}
              </select>
            </label>
            <button class="button" type="button" data-admin-cap-announcement-refresh>再読み込み</button>
          </div>
        </div>
        <p class="admin-cap-announcement-state" data-admin-cap-announcement-list-state aria-live="polite">読み込み前です。</p>
        <div class="admin-cap-announcement-list" data-admin-cap-announcement-list></div>
      </article>
      <article class="article-box admin-cap-announcement-form-panel" data-admin-cap-announcement-form-panel hidden>
        <div class="admin-cap-announcement-form-head">
          <h2>告知予約</h2>
          <p>投稿先は実チャンネル値ではなく target_channel_key で扱い、Webhook対応はEdge Function側のsecret/envに閉じます。</p>
        </div>
        <p class="admin-cap-announcement-editing" data-admin-cap-announcement-editing hidden></p>
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
            <button class="button" type="submit" data-admin-cap-announcement-action="draft">下書き保存</button>
            <button class="button primary" type="submit" data-admin-cap-announcement-action="scheduled">予約保存</button>
            <button class="button" type="submit" data-admin-cap-announcement-action="update-draft" hidden>下書きで編集保存</button>
            <button class="button primary" type="submit" data-admin-cap-announcement-action="update-scheduled" hidden>予約として編集保存</button>
            <button class="button" type="button" data-admin-cap-announcement-edit-cancel hidden>編集を中止</button>
            <button class="button" type="reset">入力をリセット</button>
            <p class="admin-cap-announcement-state" data-admin-cap-announcement-state aria-live="polite"></p>
          </div>
        </form>
      </article>
      <article class="article-box admin-cap-announcement-preview-panel" data-admin-cap-announcement-preview hidden>
        <h2>保存結果</h2>
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

function normalizeRows(value) {
  if (Array.isArray(value)) return value.filter((item) => item && typeof item === "object");
  if (value && typeof value === "object") return [value];
  return [];
}

function setSubmitDisabled(root, disabled) {
  root.querySelectorAll("[data-admin-cap-announcement-form] button").forEach((button) => {
    button.disabled = disabled;
  });
  const refresh = root.querySelector("[data-admin-cap-announcement-refresh]");
  if (refresh) refresh.disabled = disabled;
}

function renderPreview(list, payload, resultRows, label) {
  const allowedMentions = getAdminCapAnnouncementAllowedMentionsPolicy(payload.p_mention_mode);
  const firstRow = resultRows[0] || {};
  const rows = [
    ["操作", label],
    ["告知タイトル", payload.p_announcement_title],
    ["投稿先key", payload.p_target_channel_key],
    ["投稿予定日時", payload.p_scheduled_at],
    ["保存状態", firstRow.status || payload.p_status],
    ["メンション設定", payload.p_mention_mode],
    ["allowed_mentions.parse", allowedMentions.parse.length ? allowedMentions.parse.join(", ") : "[]"],
    ["エラー有無", firstRow.has_delivery_error ? "あり" : "なし"]
  ];

  list.innerHTML = rows.map(([rowLabel, value]) => `
    <div>
      <dt>${escapeHtml(rowLabel)}</dt>
      <dd>${escapeHtml(value)}</dd>
    </div>
  `).join("");
}

function createPayloadJson(payload, rpcName) {
  return JSON.stringify({
    rpc: rpcName,
    payload,
    delivery_policy: {
      allowed_mentions: getAdminCapAnnouncementAllowedMentionsPolicy(payload.p_mention_mode)
    }
  }, null, 2);
}

function resetFormForCreate(root, resetFields = true) {
  const form = root.querySelector("[data-admin-cap-announcement-form]");
  const editing = root.querySelector("[data-admin-cap-announcement-editing]");
  const draftButton = root.querySelector("[data-admin-cap-announcement-action='draft']");
  const scheduledButton = root.querySelector("[data-admin-cap-announcement-action='scheduled']");
  const updateDraftButton = root.querySelector("[data-admin-cap-announcement-action='update-draft']");
  const updateScheduledButton = root.querySelector("[data-admin-cap-announcement-action='update-scheduled']");
  const editCancelButton = root.querySelector("[data-admin-cap-announcement-edit-cancel]");

  if (resetFields) form.reset();
  form.elements.scheduledAt.value = getDefaultScheduledAt();
  form.elements.status.value = "draft";
  form.elements.mentionMode.value = "none";
  form.dataset.editingAnnouncementIndex = "";
  editing.hidden = true;
  editing.textContent = "";
  draftButton.hidden = false;
  scheduledButton.hidden = false;
  updateDraftButton.hidden = true;
  updateScheduledButton.hidden = true;
  editCancelButton.hidden = true;
}

function fillFormForEdit(root, row, index) {
  const form = root.querySelector("[data-admin-cap-announcement-form]");
  const editing = root.querySelector("[data-admin-cap-announcement-editing]");
  const draftButton = root.querySelector("[data-admin-cap-announcement-action='draft']");
  const scheduledButton = root.querySelector("[data-admin-cap-announcement-action='scheduled']");
  const updateDraftButton = root.querySelector("[data-admin-cap-announcement-action='update-draft']");
  const updateScheduledButton = root.querySelector("[data-admin-cap-announcement-action='update-scheduled']");
  const editCancelButton = root.querySelector("[data-admin-cap-announcement-edit-cancel]");

  form.elements.announcementTitle.value = row.announcement_title || "";
  form.elements.announcementBody.value = row.announcement_body || "";
  form.elements.targetChannelKey.value = row.target_channel_key || "cap_announcement";
  form.elements.scheduledAt.value = formatDateTimeForInput(row.scheduled_at);
  form.elements.status.value = row.status === "scheduled" ? "scheduled" : "draft";
  form.elements.capLevel.value = row.cap_level || "";
  form.elements.applyStartDate.value = formatOptionalDate(row.apply_start_date);
  form.elements.applyEndDate.value = formatOptionalDate(row.apply_end_date);
  form.elements.timezone.value = row.timezone || "Asia/Tokyo";
  form.elements.note.value = row.note || "";
  form.elements.mentionMode.value = row.mention_mode === "everyone" ? "everyone" : "none";
  form.dataset.editingAnnouncementIndex = String(index);
  editing.hidden = false;
  editing.textContent = `編集中: ${row.announcement_title || "無題の告知"}`;
  draftButton.hidden = true;
  scheduledButton.hidden = true;
  updateDraftButton.hidden = false;
  updateScheduledButton.hidden = false;
  editCancelButton.hidden = false;
  form.scrollIntoView({ behavior: "smooth", block: "start" });
}

function getPeriodText(row) {
  if (row.apply_start_date && row.apply_end_date) return `${row.apply_start_date} - ${row.apply_end_date}`;
  if (row.apply_start_date) return `${row.apply_start_date}開始`;
  if (row.apply_end_date) return `${row.apply_end_date}終了`;
  return "未設定";
}

function renderAnnouncementList(root, rows) {
  const list = root.querySelector("[data-admin-cap-announcement-list]");
  if (!rows.length) {
    list.innerHTML = `<p class="admin-cap-announcement-empty">該当する告知はありません。</p>`;
    return;
  }

  list.innerHTML = rows.map((row, index) => {
    const canEdit = EDITABLE_STATUSES.has(row.status);
    const canCancel = CANCELABLE_STATUSES.has(row.status);
    const errorText = row.has_delivery_error ? `エラーあり: ${row.delivery_error_code || "general"}` : "エラーなし";
    return `
      <section class="admin-cap-announcement-list-row">
        <div class="admin-cap-announcement-list-main">
          <h3>${escapeHtml(row.announcement_title || "無題の告知")}</h3>
          <span class="admin-cap-announcement-status-badge">${escapeHtml(getStatusLabel(row.status))}</span>
        </div>
        <dl class="admin-cap-announcement-list-meta">
          <div>
            <dt>投稿予定</dt>
            <dd>${escapeHtml(formatDateTimeForDisplay(row.scheduled_at))}</dd>
          </div>
          <div>
            <dt>メンション</dt>
            <dd>${escapeHtml(row.mention_mode || "none")}</dd>
          </div>
          <div>
            <dt>キャップLv</dt>
            <dd>${escapeHtml(row.cap_level || "未設定")}</dd>
          </div>
          <div>
            <dt>適用期間</dt>
            <dd>${escapeHtml(getPeriodText(row))}</dd>
          </div>
          <div>
            <dt>エラー</dt>
            <dd>${escapeHtml(errorText)}</dd>
          </div>
        </dl>
        <p class="admin-cap-announcement-list-body">${escapeHtml(row.announcement_body || "")}</p>
        <div class="admin-cap-announcement-row-actions">
          <button class="button" type="button" data-admin-cap-announcement-row-action="edit" data-admin-cap-announcement-row-index="${index}" ${canEdit ? "" : "disabled"}>編集</button>
          <button class="button danger" type="button" data-admin-cap-announcement-row-action="cancel" data-admin-cap-announcement-row-index="${index}" ${canCancel ? "" : "disabled"}>キャンセル</button>
        </div>
      </section>
    `;
  }).join("");
}

async function loadAnnouncements(root, client) {
  const filter = root.querySelector("[data-admin-cap-announcement-status-filter]");
  const listState = root.querySelector("[data-admin-cap-announcement-list-state]");
  const filterValue = filter?.value ?? "active";
  const rpcStatusFilter = RPC_STATUS_FILTERS.has(filterValue) ? filterValue : "";
  setState(listState, "告知一覧を読み込んでいます。");

  try {
    const rows = normalizeRows(await listAdminCapAnnouncements(client, {
      statusFilter: rpcStatusFilter,
      limit: 100
    }));
    const visibleRows = filterValue === "active"
      ? rows.filter((row) => ACTIVE_LIST_STATUSES.has(row.status))
      : rows;
    root.adminCapAnnouncementRows = visibleRows;
    renderAnnouncementList(root, visibleRows);
    setState(listState, `${getStatusFilterLabel(filterValue)}: ${visibleRows.length}件の告知を表示しています。`, "is-ok");
  } catch {
    root.adminCapAnnouncementRows = [];
    renderAnnouncementList(root, []);
    setState(listState, "告知一覧を取得できませんでした。権限とRPC状態を確認してください。", "is-error");
  }
}

function bindList(root, client) {
  const refresh = root.querySelector("[data-admin-cap-announcement-refresh]");
  const filter = root.querySelector("[data-admin-cap-announcement-status-filter]");

  refresh.addEventListener("click", () => {
    loadAnnouncements(root, client);
  });

  filter.addEventListener("change", () => {
    loadAnnouncements(root, client);
  });

  root.querySelector("[data-admin-cap-announcement-list]").addEventListener("click", async (event) => {
    const button = event.target.closest("[data-admin-cap-announcement-row-action]");
    if (!button) return;

    const row = root.adminCapAnnouncementRows?.[Number(button.dataset.adminCapAnnouncementRowIndex)];
    if (!row) return;

    const action = button.dataset.adminCapAnnouncementRowAction;
    if (action === "edit") {
      fillFormForEdit(root, row, Number(button.dataset.adminCapAnnouncementRowIndex));
      return;
    }

    if (action !== "cancel") return;
    if (!window.confirm("このキャップ更新告知をキャンセルします。")) return;

    const listState = root.querySelector("[data-admin-cap-announcement-list-state]");
    setSubmitDisabled(root, true);
    setState(listState, "キャンセルしています。");
    try {
      await cancelAdminCapAnnouncement(client, { announcementId: row.id });
      resetFormForCreate(root);
      await loadAnnouncements(root, client);
      setState(listState, "キャンセルしました。", "is-ok");
    } catch {
      setState(listState, "キャンセルに失敗しました。状態または権限を確認してください。", "is-error");
    } finally {
      setSubmitDisabled(root, false);
    }
  });
}

function bindForm(root, client) {
  const form = root.querySelector("[data-admin-cap-announcement-form]");
  const state = root.querySelector("[data-admin-cap-announcement-state]");
  const preview = root.querySelector("[data-admin-cap-announcement-preview]");
  const previewList = root.querySelector("[data-admin-cap-announcement-preview-list]");
  const payloadBlock = root.querySelector("[data-admin-cap-announcement-payload]");
  const editCancelButton = root.querySelector("[data-admin-cap-announcement-edit-cancel]");

  editCancelButton.addEventListener("click", () => {
    resetFormForCreate(root);
    preview.hidden = true;
    payloadBlock.textContent = "";
    setState(state, "編集を中止しました。");
  });

  form.addEventListener("reset", () => {
    window.requestAnimationFrame(() => {
      resetFormForCreate(root, false);
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, "");
    });
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const action = event.submitter?.dataset.adminCapAnnouncementAction || "draft";
    const isUpdateAction = action === "update-draft" || action === "update-scheduled";
    const editingIndex = form.dataset.editingAnnouncementIndex;
    const editingRow = editingIndex ? root.adminCapAnnouncementRows?.[Number(editingIndex)] : null;
    const input = collectFormInput(form);

    if (action === "draft" || action === "scheduled" || action === "update-draft" || action === "update-scheduled") {
      input.status = action.endsWith("scheduled") ? "scheduled" : "draft";
      form.elements.status.value = input.status;
    }

    const payload = buildAdminCapAnnouncementCreatePayload(input);
    const validation = validateAdminCapAnnouncementPayload(payload);

    if (!validation.ok) {
      preview.hidden = true;
      payloadBlock.textContent = "";
      setState(state, validation.errors.join(" "), "is-error");
      return;
    }

    setSubmitDisabled(root, true);
    setState(state, isUpdateAction ? "編集内容を保存しています。" : "告知を保存しています。");

    try {
      const rpcName = isUpdateAction ? "update_admin_discord_announcement" : "create_admin_discord_announcement";
      const resultRows = normalizeRows(isUpdateAction
        ? await updateAdminCapAnnouncement(client, { ...payload, announcementId: editingRow?.id })
        : await createAdminCapAnnouncement(client, payload));
      const resultLabel = isUpdateAction ? `${getStatusLabel(payload.p_status)}へ編集保存` : getStatusLabel(payload.p_status);

      renderPreview(previewList, payload, resultRows, resultLabel);
      payloadBlock.textContent = createPayloadJson(
        isUpdateAction ? { p_announcement_id: "selected", ...payload } : payload,
        rpcName
      );
      preview.hidden = false;
      resetFormForCreate(root);
      await loadAnnouncements(root, client);
      setState(state, isUpdateAction ? "編集内容を保存しました。" : "告知を保存しました。", "is-ok");
    } catch {
      setState(state, "保存に失敗しました。入力内容、状態、admin権限を確認してください。", "is-error");
    } finally {
      setSubmitDisabled(root, false);
    }
  });
}

export async function renderAdminCapAnnouncements(root) {
  root.innerHTML = renderShell();

  const accessState = root.querySelector("[data-admin-cap-announcement-access-state]");
  const adminPanel = root.querySelector("[data-admin-cap-announcement-admin-panel]");
  const listPanel = root.querySelector("[data-admin-cap-announcement-list-panel]");
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
    listPanel.hidden = false;
    formPanel.hidden = false;
    bindList(root, client);
    bindForm(root, client);
    await loadAnnouncements(root, client);
    setState(accessState, "admin権限を確認しました。キャップ更新告知をRPC経由で管理できます。", "is-ok");
  } catch {
    setState(accessState, "admin権限の確認に失敗しました。時間をおいて再読み込みしてください。", "is-error");
  }
}
