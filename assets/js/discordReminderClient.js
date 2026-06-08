const REMINDER_RPC = Object.freeze({
  create: "create_discord_reminder",
  update: "update_discord_reminder",
  cancel: "cancel_discord_reminder",
  list: "list_my_discord_reminders"
});

const MENTION_MODES = new Set(["none", "everyone"]);
const DEFAULT_TIMEZONE = "Asia/Tokyo";
const MESSAGE_MAX_LENGTH = 1800;
const CHANNEL_KEY_PATTERN = /^[a-z0-9][a-z0-9_-]{1,62}[a-z0-9]$/;

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

function normalizeChannelKey(value) {
  return normalizeText(value).toLowerCase();
}

function hasRpcClient(client) {
  return Boolean(client && typeof client.rpc === "function");
}

export function getDiscordReminderRpcNames() {
  return { ...REMINDER_RPC };
}

export function getDiscordReminderAllowedMentionsPolicy(mentionMode) {
  return normalizeMentionMode(mentionMode) === "everyone"
    ? { parse: ["everyone"] }
    : { parse: [] };
}

export function buildDiscordReminderCreatePayload(input = {}) {
  const mentionMode = normalizeMentionMode(input.mentionMode ?? input.p_mention_mode);
  return {
    p_channel_key: normalizeChannelKey(input.channelKey ?? input.p_channel_key),
    p_scheduled_at: normalizeDateTime(input.scheduledAt ?? input.p_scheduled_at),
    p_timezone: normalizeText(input.timezone ?? input.p_timezone) || DEFAULT_TIMEZONE,
    p_message_body: normalizeText(input.messageBody ?? input.p_message_body),
    p_mention_mode: mentionMode
  };
}

export function buildDiscordReminderUpdatePayload(input = {}) {
  return {
    p_reminder_id: normalizeText(input.reminderId ?? input.p_reminder_id),
    ...buildDiscordReminderCreatePayload(input)
  };
}

export function buildDiscordReminderCancelPayload(input = {}) {
  return {
    p_reminder_id: normalizeText(input.reminderId ?? input.p_reminder_id)
  };
}

export function buildDiscordReminderListPayload(input = {}) {
  return {
    p_status_filter: normalizeText(input.statusFilter ?? input.p_status_filter),
    p_limit: Number.isFinite(Number(input.limit ?? input.p_limit))
      ? Math.max(1, Math.min(100, Number(input.limit ?? input.p_limit)))
      : 50
  };
}

export function validateDiscordReminderPayload(payload = {}) {
  const errors = [];
  const channelKey = normalizeChannelKey(payload.p_channel_key);
  const scheduledAt = normalizeDateTime(payload.p_scheduled_at);
  const messageBody = normalizeText(payload.p_message_body);
  const mentionMode = normalizeMentionMode(payload.p_mention_mode);

  if (!CHANNEL_KEY_PATTERN.test(channelKey)) {
    errors.push("投稿先チャンネルの管理キーを選択してください。");
  }
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(scheduledAt)) {
    errors.push("投稿予定日時を入力してください。");
  }
  if (!messageBody) {
    errors.push("投稿テキストを入力してください。");
  }
  if (messageBody.length > MESSAGE_MAX_LENGTH) {
    errors.push(`投稿テキストは${MESSAGE_MAX_LENGTH}文字以内にしてください。`);
  }
  if (!MENTION_MODES.has(mentionMode)) {
    errors.push("通知モードを選択してください。");
  }

  return {
    ok: errors.length === 0,
    errors
  };
}

export async function createDiscordReminder(client, input) {
  if (!hasRpcClient(client)) throw new Error("discord-reminder-rpc-client-required");
  const payload = buildDiscordReminderCreatePayload(input);
  const validation = validateDiscordReminderPayload(payload);
  if (!validation.ok) throw new Error("discord-reminder-invalid-payload");
  return client.rpc(REMINDER_RPC.create, payload);
}

export async function updateDiscordReminder(client, input) {
  if (!hasRpcClient(client)) throw new Error("discord-reminder-rpc-client-required");
  const payload = buildDiscordReminderUpdatePayload(input);
  if (!payload.p_reminder_id) throw new Error("discord-reminder-id-required");
  const validation = validateDiscordReminderPayload(payload);
  if (!validation.ok) throw new Error("discord-reminder-invalid-payload");
  return client.rpc(REMINDER_RPC.update, payload);
}

export async function cancelDiscordReminder(client, input) {
  if (!hasRpcClient(client)) throw new Error("discord-reminder-rpc-client-required");
  const payload = buildDiscordReminderCancelPayload(input);
  if (!payload.p_reminder_id) throw new Error("discord-reminder-id-required");
  return client.rpc(REMINDER_RPC.cancel, payload);
}

export async function listDiscordReminders(client, input = {}) {
  if (!hasRpcClient(client)) throw new Error("discord-reminder-rpc-client-required");
  return client.rpc(REMINDER_RPC.list, buildDiscordReminderListPayload(input));
}
