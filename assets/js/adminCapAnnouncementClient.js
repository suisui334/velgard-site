const ADMIN_CAP_ANNOUNCEMENT_RPC = Object.freeze({
  create: "create_admin_discord_announcement",
  update: "update_admin_discord_announcement",
  cancel: "cancel_admin_discord_announcement",
  list: "list_admin_discord_announcements"
});

const MENTION_MODES = new Set(["none", "everyone"]);
const CREATE_STATUSES = new Set(["draft", "scheduled"]);
const LIST_STATUSES = new Set(["draft", "scheduled", "processing", "posted", "failed", "canceled"]);
const DEFAULT_TIMEZONE = "Asia/Tokyo";
const DEFAULT_TARGET_CHANNEL_KEY = "cap_announcement";
const TITLE_MAX_LENGTH = 120;
const BODY_MAX_LENGTH = 1800;
const CAP_LEVEL_MAX_LENGTH = 40;
const NOTE_MAX_LENGTH = 500;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DATE_TIME_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/;

function normalizeText(value) {
  return String(value ?? "").trim();
}

function normalizeDateTime(value) {
  return normalizeText(value).replace(" ", "T");
}

function normalizeMentionMode(value) {
  const normalized = normalizeText(value);
  return MENTION_MODES.has(normalized) ? normalized : "none";
}

function normalizeStatus(value) {
  const normalized = normalizeText(value);
  return CREATE_STATUSES.has(normalized) ? normalized : "draft";
}

function normalizeTargetChannelKey(value) {
  return normalizeText(value || DEFAULT_TARGET_CHANNEL_KEY).toLowerCase();
}

function normalizeStatusFilter(value) {
  const normalized = normalizeText(value);
  return LIST_STATUSES.has(normalized) ? normalized : "";
}

function normalizeOptionalDate(value) {
  return normalizeText(value);
}

function hasRpcClient(client) {
  return Boolean(client && typeof client.rpc === "function");
}

async function callAdminCapAnnouncementRpc(client, rpcName, payload) {
  if (!hasRpcClient(client)) throw new Error("admin-cap-announcement-rpc-client-required");
  const { data, error } = await client.rpc(rpcName, payload);
  if (error) throw new Error("admin-cap-announcement-rpc-failed");
  return data;
}

export function getAdminCapAnnouncementRpcNames() {
  return { ...ADMIN_CAP_ANNOUNCEMENT_RPC };
}

export function getAdminCapAnnouncementAllowedMentionsPolicy(mentionMode) {
  return normalizeMentionMode(mentionMode) === "everyone"
    ? { parse: ["everyone"] }
    : { parse: [] };
}

export function buildAdminCapAnnouncementCreatePayload(input = {}) {
  return {
    p_announcement_title: normalizeText(input.announcementTitle ?? input.p_announcement_title),
    p_announcement_body: normalizeText(input.announcementBody ?? input.p_announcement_body),
    p_target_channel_key: normalizeTargetChannelKey(input.targetChannelKey ?? input.p_target_channel_key),
    p_scheduled_at: normalizeDateTime(input.scheduledAt ?? input.p_scheduled_at),
    p_timezone: normalizeText(input.timezone ?? input.p_timezone) || DEFAULT_TIMEZONE,
    p_mention_mode: normalizeMentionMode(input.mentionMode ?? input.p_mention_mode),
    p_status: normalizeStatus(input.status ?? input.p_status),
    p_cap_level: normalizeText(input.capLevel ?? input.p_cap_level),
    p_apply_start_date: normalizeOptionalDate(input.applyStartDate ?? input.p_apply_start_date),
    p_apply_end_date: normalizeOptionalDate(input.applyEndDate ?? input.p_apply_end_date),
    p_note: normalizeText(input.note ?? input.p_note)
  };
}

export function buildAdminCapAnnouncementUpdatePayload(input = {}) {
  return {
    p_announcement_id: normalizeText(input.announcementId ?? input.p_announcement_id),
    ...buildAdminCapAnnouncementCreatePayload(input)
  };
}

export function buildAdminCapAnnouncementCancelPayload(input = {}) {
  return {
    p_announcement_id: normalizeText(input.announcementId ?? input.p_announcement_id)
  };
}

export function buildAdminCapAnnouncementListPayload(input = {}) {
  return {
    p_status_filter: normalizeStatusFilter(input.statusFilter ?? input.p_status_filter),
    p_limit: Number.isFinite(Number(input.limit ?? input.p_limit))
      ? Math.max(1, Math.min(100, Number(input.limit ?? input.p_limit)))
      : 50
  };
}

export function validateAdminCapAnnouncementPayload(payload = {}) {
  const errors = [];
  const title = normalizeText(payload.p_announcement_title);
  const body = normalizeText(payload.p_announcement_body);
  const targetChannelKey = normalizeTargetChannelKey(payload.p_target_channel_key);
  const scheduledAt = normalizeDateTime(payload.p_scheduled_at);
  const mentionMode = normalizeText(payload.p_mention_mode);
  const status = normalizeText(payload.p_status);
  const capLevel = normalizeText(payload.p_cap_level);
  const note = normalizeText(payload.p_note);

  if (!title) errors.push("告知タイトルを入力してください。");
  if (title.length > TITLE_MAX_LENGTH) errors.push(`告知タイトルは${TITLE_MAX_LENGTH}文字以内にしてください。`);
  if (!body) errors.push("告知本文を入力してください。");
  if (body.length > BODY_MAX_LENGTH) errors.push(`告知本文は${BODY_MAX_LENGTH}文字以内にしてください。`);
  if (targetChannelKey !== DEFAULT_TARGET_CHANNEL_KEY) errors.push("投稿先チャンネルkeyを選択してください。");
  if (!DATE_TIME_PATTERN.test(scheduledAt)) errors.push("投稿予定日時を入力してください。");
  if (!MENTION_MODES.has(mentionMode)) errors.push("メンション設定を選択してください。");
  if (!CREATE_STATUSES.has(status)) errors.push("保存状態を選択してください。");
  if (capLevel.length > CAP_LEVEL_MAX_LENGTH) errors.push(`キャップLvは${CAP_LEVEL_MAX_LENGTH}文字以内にしてください。`);
  if (payload.p_apply_start_date && !DATE_PATTERN.test(payload.p_apply_start_date)) errors.push("適用開始日を確認してください。");
  if (payload.p_apply_end_date && !DATE_PATTERN.test(payload.p_apply_end_date)) errors.push("適用終了日を確認してください。");
  if (note.length > NOTE_MAX_LENGTH) errors.push(`補足文は${NOTE_MAX_LENGTH}文字以内にしてください。`);

  return {
    ok: errors.length === 0,
    errors
  };
}

export async function createAdminCapAnnouncement(client, input) {
  const payload = buildAdminCapAnnouncementCreatePayload(input);
  const validation = validateAdminCapAnnouncementPayload(payload);
  if (!validation.ok) throw new Error("admin-cap-announcement-invalid-payload");
  return callAdminCapAnnouncementRpc(client, ADMIN_CAP_ANNOUNCEMENT_RPC.create, payload);
}

export async function updateAdminCapAnnouncement(client, input) {
  const payload = buildAdminCapAnnouncementUpdatePayload(input);
  if (!payload.p_announcement_id) throw new Error("admin-cap-announcement-id-required");
  const validation = validateAdminCapAnnouncementPayload(payload);
  if (!validation.ok) throw new Error("admin-cap-announcement-invalid-payload");
  return callAdminCapAnnouncementRpc(client, ADMIN_CAP_ANNOUNCEMENT_RPC.update, payload);
}

export async function cancelAdminCapAnnouncement(client, input) {
  const payload = buildAdminCapAnnouncementCancelPayload(input);
  if (!payload.p_announcement_id) throw new Error("admin-cap-announcement-id-required");
  return callAdminCapAnnouncementRpc(client, ADMIN_CAP_ANNOUNCEMENT_RPC.cancel, payload);
}

export async function listAdminCapAnnouncements(client, input = {}) {
  return callAdminCapAnnouncementRpc(client, ADMIN_CAP_ANNOUNCEMENT_RPC.list, buildAdminCapAnnouncementListPayload(input));
}
