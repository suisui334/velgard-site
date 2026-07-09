// Session reminder dispatcher.
//
// Gate 6 adds the production-gated code path, but this source is not deployed
// in Gate 6. Dry-run still performs preview only: no Discord request, no DB
// write, and no claim/finalize RPC calls.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ReminderType = "shortage" | "gm_confirmed";
type FinalizeStatus = "sent" | "failed" | "skipped";
type DeliveryStatus = FinalizeStatus | "finalize_failed";

type ErrorCode =
  | "config_missing"
  | "cron_auth_required"
  | "db_claim_failed"
  | "db_finalize_failed"
  | "db_preview_failed"
  | "invalid_payload"
  | "method_not_allowed"
  | "production_not_enabled"
  | "webhook_config_missing"
  | "webhook_response_invalid"
  | "webhook_send_failed";

type ErrorStage =
  | "request_validation"
  | "service_client_config"
  | "production_gate"
  | "production_auth"
  | "webhook_config"
  | "preview_rpc"
  | "claim_rpc";

interface DispatchOptions {
  dryRun: boolean;
  nowIso: string;
  limit: number;
}

interface PreviewReminderRow {
  session_id: string;
  reminder_type: string | null;
  title: string | null;
  start_at: string | null;
  min_players: number | null;
  pending_count: number | null;
  accepted_count: number | null;
  waitlisted_count: number | null;
  count_for_minimum: number | null;
  shortage_count: number | null;
  gm_display_name: string | null;
  gm_discord_user_id: string | null;
  reminder_offset_minutes: number | null;
  target_channel_key: string | null;
  session_public_id: string | null;
  scheduled_for: string | null;
}

interface ClaimedReminderRow extends PreviewReminderRow {
  log_id: string | null;
  lock_token: string | null;
}

interface FinalizedReminderRow {
  log_id: string | null;
  session_id: string | null;
  reminder_type: string | null;
  status: string | null;
  sent_at: string | null;
  finalized_at: string | null;
}

type SupportedPreviewReminderRow = PreviewReminderRow & { reminder_type: ReminderType };
type SupportedClaimedReminderRow = ClaimedReminderRow & {
  log_id: string;
  lock_token: string;
  reminder_type: ReminderType;
};

interface ReminderPreviewItem {
  reminder_type: ReminderType;
  session_id: string;
  title: string;
  start_at: string | null;
  min_players: number | null;
  pending_count: number;
  accepted_count: number;
  waitlisted_count: number;
  count_for_minimum: number;
  shortage_count: number;
  gm_display_name: string;
  reminder_offset_minutes: number | null;
  target_channel_key: string | null;
  session_url: string;
  scheduled_for: string | null;
  message_preview: string;
  gm_mention_available: boolean;
  discord_delivery_preview: {
    would_send: false;
    suppress_embeds: true;
    session_url_is_absolute: boolean;
    allowed_mentions: {
      parse: string[];
    };
  };
}

interface ProductionReminderResult {
  reminder_type: ReminderType;
  status: DeliveryStatus;
  title: string;
  error_summary: string | null;
  gm_mention_used: boolean;
  discord_message_reference: "received" | "not_sent";
}

interface DiscordWebhookPayload {
  content: string;
  flags: number;
  allowed_mentions: {
    parse: Array<"everyone">;
    users?: string[];
  };
}

type SupabaseClient = ReturnType<typeof createClient>;

type PreviewDueSessionRemindersRpcResult = Promise<{
  data: PreviewReminderRow[] | null;
  error: unknown;
}>;

type ClaimDueSessionRemindersRpcResult = Promise<{
  data: ClaimedReminderRow[] | null;
  error: unknown;
}>;

type FinalizeSessionReminderRpcResult = Promise<{
  data: FinalizedReminderRow[] | null;
  error: unknown;
}>;

type SessionReminderRpc = {
  (
    functionName: "preview_due_session_reminders",
    args: { p_now: string; p_limit: number }
  ): PreviewDueSessionRemindersRpcResult;
  (
    functionName: "claim_due_session_reminders",
    args: { p_now: string; p_limit: number }
  ): ClaimDueSessionRemindersRpcResult;
  (
    functionName: "finalize_session_reminder",
    args: {
      p_log_id: string;
      p_lock_token: string;
      p_status: FinalizeStatus;
      p_discord_message_id: string | null;
      p_error_message: string | null;
    }
  ): FinalizeSessionReminderRpcResult;
};

type SessionReminderRpcClient = SupabaseClient & {
  rpc: SessionReminderRpc;
};

type DiscordSendResult =
  | { ok: true; messageId: string }
  | { ok: false; errorCode: ErrorCode; retryable: boolean };

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const DISCORD_SUPPRESS_EMBEDS_FLAG = 4;
const PUBLIC_SITE_BASE_URL_ENV = "PUBLIC_SITE_BASE_URL";
const DEFAULT_PUBLIC_SITE_BASE_URL = "https://suisui334.github.io/velgard-site/";
const SESSION_DETAIL_PAGE = "session-detail.html";
const SESSION_REMINDER_REAL_SEND_ENABLED_ENV = "SESSION_REMINDER_REAL_SEND_ENABLED";
const SESSION_REMINDER_DISPATCH_TOKEN_ENV = "SESSION_REMINDER_DISPATCH_TOKEN";
const DISCORD_SESSION_REMINDER_WEBHOOK_URL_ENV = "DISCORD_SESSION_REMINDER_WEBHOOK_URL";
const DISPATCH_TOKEN_HEADER = "x-dispatch-token";
const MASKED_GM_MENTION = "<@GM>";

const CORS_HEADERS = {
  "access-control-allow-headers": "authorization, content-type, x-client-info, apikey, x-dispatch-token",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-origin": "*",
  "content-type": "application/json; charset=utf-8"
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (request.method !== "POST") {
    return jsonError(405, "method_not_allowed", "POSTで呼び出してください。", true, "request_validation");
  }

  const parsedBody = await readJsonBody(request);
  if (!parsedBody.ok) {
    return jsonError(400, "invalid_payload", "リクエスト内容を確認してください。", true, "request_validation");
  }

  const optionsResult = readDispatchOptions(parsedBody.value);
  if (!optionsResult.ok) {
    return jsonError(400, "invalid_payload", optionsResult.message, true, "request_validation");
  }

  const options = optionsResult.value;
  if (!options.dryRun) {
    const productionGate = readProductionGate(request);
    if (!productionGate.ok) {
      return jsonError(productionGate.status, productionGate.errorCode, productionGate.message, false, productionGate.stage);
    }

    const clientResult = createServiceSupabaseClient();
    if (!clientResult.ok) {
      return jsonError(500, "config_missing", "Dispatcher configuration is missing.", false, "service_client_config");
    }

    return handleProductionDispatch(clientResult.client, options, productionGate.webhookUrl);
  }

  const clientResult = createServiceSupabaseClient();
  if (!clientResult.ok) {
    return jsonError(500, "config_missing", "Dispatcher configuration is missing.", true, "service_client_config");
  }

  return handleDryRun(clientResult.client, options);
});

async function handleDryRun(client: SessionReminderRpcClient, options: DispatchOptions): Promise<Response> {
  const previewResult = await previewDueSessionReminders(client, options);
  if (!previewResult.ok) {
    return jsonError(502, "db_preview_failed", "Reminder preview failed.", true, "preview_rpc");
  }

  const publicSiteBaseUrl = resolvePublicSiteBaseUrl();
  const items = previewResult.rows.map((row) => buildReminderPreviewItem(row, publicSiteBaseUrl));

  return jsonOk({
    ok: true,
    dry_run: true,
    now: options.nowIso,
    count: items.length,
    items,
    safety: {
      preview_rpc_only: true,
      db_write: false,
      discord_send: false,
      production_enabled: false
    }
  });
}

async function handleProductionDispatch(
  client: SessionReminderRpcClient,
  options: DispatchOptions,
  webhookUrl: string
): Promise<Response> {
  const claimResult = await claimDueSessionReminders(client, options);
  if (!claimResult.ok) {
    return jsonError(502, "db_claim_failed", "Reminder claim failed.", false, "claim_rpc");
  }

  const publicSiteBaseUrl = resolvePublicSiteBaseUrl();
  const results: ProductionReminderResult[] = [];

  for (const row of claimResult.rows) {
    const sessionUrl = buildSessionDetailUrl(row.session_public_id || row.session_id, publicSiteBaseUrl);
    const sendResult = await sendDiscordReminder(row, sessionUrl, webhookUrl);
    const finalizeStatus: FinalizeStatus = sendResult.ok ? "sent" : "failed";
    const errorSummary = sendResult.ok ? null : normalizeErrorSummary(sendResult.errorCode);
    const finalizeResult = await finalizeSessionReminder(
      client,
      row,
      finalizeStatus,
      sendResult.ok ? sendResult.messageId : null,
      errorSummary
    );

    results.push({
      reminder_type: row.reminder_type,
      status: finalizeResult.ok ? finalizeStatus : "finalize_failed",
      title: row.title || "タイトル未設定",
      error_summary: finalizeResult.ok ? errorSummary : "db_finalize_failed",
      gm_mention_used: shouldUseGmMention(row),
      discord_message_reference: sendResult.ok ? "received" : "not_sent"
    });
  }

  return jsonOk({
    ok: true,
    dry_run: false,
    production_enabled: true,
    claimed_count: claimResult.rows.length,
    sent_count: results.filter((result) => result.status === "sent").length,
    failed_count: results.filter((result) => result.status === "failed" || result.status === "finalize_failed").length,
    skipped_count: results.filter((result) => result.status === "skipped").length,
    results,
    safety: {
      preview_rpc_only: false,
      db_write: true,
      discord_send: true,
      claim_finalize: true
    }
  });
}

async function readJsonBody(request: Request): Promise<{ ok: true; value: Record<string, unknown> } | { ok: false }> {
  const text = await request.text();
  if (!text.trim()) return { ok: true, value: {} };

  try {
    const value = JSON.parse(text);
    return isRecord(value) ? { ok: true, value } : { ok: false };
  } catch {
    return { ok: false };
  }
}

function readDispatchOptions(
  value: Record<string, unknown>
): { ok: true; value: DispatchOptions } | { ok: false; message: string } {
  const dryRun = value.dry_run !== false;
  const nowIso = normalizeOptionalIsoTimestamp(value.now);
  if (!nowIso) {
    return { ok: false, message: "now must be an ISO timestamp when provided." };
  }

  return {
    ok: true,
    value: {
      dryRun,
      nowIso,
      limit: normalizeLimit(value.limit)
    }
  };
}

function normalizeOptionalIsoTimestamp(value: unknown): string | null {
  const text = normalizeText(value, 80);
  if (!text) return new Date().toISOString();
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function normalizeLimit(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_LIMIT;
  return Math.max(1, Math.min(MAX_LIMIT, Math.floor(parsed)));
}

function readProductionGate(request: Request): {
  ok: true;
  webhookUrl: string;
} | {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  stage: ErrorStage;
  message: string;
} {
  if (Deno.env.get(SESSION_REMINDER_REAL_SEND_ENABLED_ENV) !== "true") {
    return {
      ok: false,
      status: 403,
      errorCode: "production_not_enabled",
      stage: "production_gate",
      message: "production dispatch is not enabled."
    };
  }

  if (!hasDispatchAuthorization(request)) {
    return {
      ok: false,
      status: 401,
      errorCode: "cron_auth_required",
      stage: "production_auth",
      message: "dispatch authorization failed."
    };
  }

  const webhookUrl = readDiscordWebhookUrl();
  if (!webhookUrl.ok) {
    return {
      ok: false,
      status: 502,
      errorCode: "webhook_config_missing",
      stage: "webhook_config",
      message: "Discord Webhook is not configured."
    };
  }

  return { ok: true, webhookUrl: webhookUrl.value };
}

function hasDispatchAuthorization(request: Request): boolean {
  const expected = normalizeText(Deno.env.get(SESSION_REMINDER_DISPATCH_TOKEN_ENV), 300);
  const actual = normalizeText(request.headers.get(DISPATCH_TOKEN_HEADER), 300);
  return Boolean(expected && actual && expected === actual);
}

function createServiceSupabaseClient(): { ok: true; client: SessionReminderRpcClient } | { ok: false } {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return { ok: false };
  }

  return {
    ok: true,
    client: createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }) as SessionReminderRpcClient
  };
}

async function previewDueSessionReminders(
  client: SessionReminderRpcClient,
  options: DispatchOptions
): Promise<{ ok: true; rows: SupportedPreviewReminderRow[] } | { ok: false }> {
  try {
    const result = await client.rpc("preview_due_session_reminders", {
      p_now: options.nowIso,
      p_limit: options.limit
    });
    if (result.error || !Array.isArray(result.data)) return { ok: false };
    return { ok: true, rows: result.data.map(normalizePreviewReminderRow).filter(isSupportedReminderRow) };
  } catch {
    return { ok: false };
  }
}

async function claimDueSessionReminders(
  client: SessionReminderRpcClient,
  options: DispatchOptions
): Promise<{ ok: true; rows: SupportedClaimedReminderRow[] } | { ok: false }> {
  try {
    const result = await client.rpc("claim_due_session_reminders", {
      p_now: options.nowIso,
      p_limit: options.limit
    });
    if (result.error || !Array.isArray(result.data)) return { ok: false };
    return { ok: true, rows: result.data.map(normalizeClaimedReminderRow).filter(isSupportedClaimedReminderRow) };
  } catch {
    return { ok: false };
  }
}

async function finalizeSessionReminder(
  client: SessionReminderRpcClient,
  row: SupportedClaimedReminderRow,
  status: FinalizeStatus,
  discordMessageId: string | null,
  errorMessage: string | null
): Promise<{ ok: true } | { ok: false }> {
  try {
    const result = await client.rpc("finalize_session_reminder", {
      p_log_id: row.log_id,
      p_lock_token: row.lock_token,
      p_status: status,
      p_discord_message_id: discordMessageId,
      p_error_message: errorMessage
    });
    return result.error || !Array.isArray(result.data) || result.data.length === 0 ? { ok: false } : { ok: true };
  } catch {
    return { ok: false };
  }
}

function normalizePreviewReminderRow(row: PreviewReminderRow): PreviewReminderRow {
  return {
    session_id: normalizeText(row?.session_id, 120),
    reminder_type: normalizeText(row?.reminder_type, 40),
    title: normalizeText(row?.title, 160),
    start_at: normalizeNullableText(row?.start_at, 80),
    min_players: normalizeNullableInteger(row?.min_players),
    pending_count: normalizeNullableInteger(row?.pending_count),
    accepted_count: normalizeNullableInteger(row?.accepted_count),
    waitlisted_count: normalizeNullableInteger(row?.waitlisted_count),
    count_for_minimum: normalizeNullableInteger(row?.count_for_minimum),
    shortage_count: normalizeNullableInteger(row?.shortage_count),
    gm_display_name: normalizeText(row?.gm_display_name, 80) || "GM",
    gm_discord_user_id: normalizeDiscordUserId(row?.gm_discord_user_id),
    reminder_offset_minutes: normalizeNullableInteger(row?.reminder_offset_minutes),
    target_channel_key: normalizeNullableText(row?.target_channel_key, 80),
    session_public_id: normalizeText(row?.session_public_id, 120) || normalizeText(row?.session_id, 120),
    scheduled_for: normalizeNullableText(row?.scheduled_for, 80)
  };
}

function normalizeClaimedReminderRow(row: ClaimedReminderRow): ClaimedReminderRow {
  return {
    ...normalizePreviewReminderRow(row),
    log_id: normalizeText(row?.log_id, 120),
    lock_token: normalizeText(row?.lock_token, 120)
  };
}

function isSupportedReminderRow(row: PreviewReminderRow): row is SupportedPreviewReminderRow {
  return row.reminder_type === "shortage" || row.reminder_type === "gm_confirmed";
}

function isSupportedClaimedReminderRow(row: ClaimedReminderRow): row is SupportedClaimedReminderRow {
  return Boolean(row.log_id && row.lock_token && isSupportedReminderRow(row));
}

function buildReminderPreviewItem(row: SupportedPreviewReminderRow, publicSiteBaseUrl: string): ReminderPreviewItem {
  const sessionUrl = buildSessionDetailUrl(row.session_public_id || row.session_id, publicSiteBaseUrl);
  const messagePreview = buildReminderMessage(row, sessionUrl, { maskGmMention: true });

  return {
    reminder_type: row.reminder_type,
    session_id: row.session_public_id || row.session_id,
    title: row.title || "タイトル未設定",
    start_at: row.start_at,
    min_players: row.min_players,
    pending_count: row.pending_count ?? 0,
    accepted_count: row.accepted_count ?? 0,
    waitlisted_count: row.waitlisted_count ?? 0,
    count_for_minimum: row.count_for_minimum ?? 0,
    shortage_count: row.shortage_count ?? 0,
    gm_display_name: row.gm_display_name || "GM",
    reminder_offset_minutes: row.reminder_offset_minutes,
    target_channel_key: row.target_channel_key,
    session_url: sessionUrl,
    scheduled_for: row.scheduled_for,
    message_preview: messagePreview,
    gm_mention_available: shouldUseGmMention(row),
    discord_delivery_preview: {
      would_send: false,
      suppress_embeds: true,
      session_url_is_absolute: isAbsoluteHttpUrl(sessionUrl),
      allowed_mentions: {
        parse: getAllowedMentionParse(row.reminder_type)
      }
    }
  };
}

async function sendDiscordReminder(
  row: SupportedClaimedReminderRow,
  sessionUrl: string,
  webhookUrl: string
): Promise<DiscordSendResult> {
  let response: Response;
  try {
    response = await fetch(buildDiscordWebhookWaitUrl(webhookUrl), {
      method: "POST",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify(buildDiscordWebhookPayload(row, sessionUrl))
    });
  } catch {
    return { ok: false, errorCode: "webhook_send_failed", retryable: true };
  }

  if (!response.ok) {
    return {
      ok: false,
      errorCode: "webhook_send_failed",
      retryable: response.status === 429 || response.status >= 500
    };
  }

  const messageId = await readDiscordMessageId(response);
  return messageId
    ? { ok: true, messageId }
    : { ok: false, errorCode: "webhook_response_invalid", retryable: false };
}

function readDiscordWebhookUrl(): { ok: true; value: string } | { ok: false } {
  const rawUrl = normalizeText(Deno.env.get(DISCORD_SESSION_REMINDER_WEBHOOK_URL_ENV), 2048);
  if (!rawUrl) return { ok: false };

  try {
    const parsedUrl = new URL(rawUrl);
    const isDiscordHost = parsedUrl.hostname === "discord.com" || parsedUrl.hostname === "discordapp.com";
    const isWebhookPath = parsedUrl.pathname.startsWith("/api/webhooks/");
    if (parsedUrl.protocol !== "https:" || !isDiscordHost || !isWebhookPath) return { ok: false };
    return { ok: true, value: rawUrl };
  } catch {
    return { ok: false };
  }
}

function buildDiscordWebhookWaitUrl(webhookUrl: string): string {
  const url = new URL(webhookUrl);
  url.searchParams.set("wait", "true");
  return url.toString();
}

function buildDiscordWebhookPayload(
  row: SupportedClaimedReminderRow,
  sessionUrl: string
): DiscordWebhookPayload {
  return {
    content: truncateDiscordContent(buildReminderMessage(row, sessionUrl)),
    flags: DISCORD_SUPPRESS_EMBEDS_FLAG,
    allowed_mentions: buildAllowedMentions(row)
  };
}

function getAllowedMentionParse(reminderType: ReminderType): Array<"everyone"> {
  return reminderType === "shortage" ? ["everyone"] : [];
}

function buildAllowedMentions(row: SupportedPreviewReminderRow): DiscordWebhookPayload["allowed_mentions"] {
  if (row.reminder_type === "shortage") {
    return { parse: ["everyone"] };
  }

  const gmDiscordUserId = getGmDiscordUserId(row);
  return gmDiscordUserId ? { parse: [], users: [gmDiscordUserId] } : { parse: [] };
}

async function readDiscordMessageId(response: Response): Promise<string | null> {
  try {
    const value = await response.json();
    if (!isRecord(value)) return null;
    const messageId = normalizeText(value.id, 120);
    return isDiscordSnowflakeLike(messageId) ? messageId : null;
  } catch {
    return null;
  }
}

function buildReminderMessage(
  row: SupportedPreviewReminderRow,
  sessionUrl: string,
  options: { maskGmMention?: boolean } = {}
): string {
  return row.reminder_type === "shortage"
    ? buildShortageMessagePreview(row, sessionUrl)
    : buildGmConfirmedMessage(row, sessionUrl, options);
}

function buildShortageMessagePreview(row: PreviewReminderRow, sessionUrl: string): string {
  const title = row.title || "タイトル未設定";
  const startTime = formatStartTimeForJapaneseMessage(row.start_at);
  const shortageCount = Math.max(0, row.shortage_count ?? 0);
  return [
    "@everyone",
    `■依頼書【${title}】[ ${sessionUrl} ]`,
    `本日${startTime}より開催予定です。最低人数に後${shortageCount}人足りていません。ご都合よろしければ参加いかがでしょうか。`
  ].join("\n");
}

function buildGmConfirmedMessage(
  row: SupportedPreviewReminderRow,
  sessionUrl: string,
  options: { maskGmMention?: boolean } = {}
): string {
  const title = row.title || "タイトル未設定";
  const startTime = formatStartTimeForJapaneseMessage(row.start_at);
  const gmName = row.gm_display_name || "GM";
  const gmDiscordUserId = getGmDiscordUserId(row);
  const mentionLine = gmDiscordUserId ? (options.maskGmMention ? MASKED_GM_MENTION : `<@${gmDiscordUserId}>`) : null;
  const lines = [
    `■依頼書【${title}】[ ${sessionUrl} ]`,
    `本日${startTime}より開催予定です。最低人数を満たしているため、開催予定のリマインドです。`,
    `GM【${gmName}】さんは、開始準備・会場案内・参加者状況の確認をお願いいたします。`
  ];
  return mentionLine ? [mentionLine, ...lines].join("\n") : lines.join("\n");
}

function formatStartTimeForJapaneseMessage(value: unknown): string {
  const text = normalizeText(value, 80);
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return "開始時刻未定";

  const parts = new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    hour: "numeric",
    minute: "2-digit",
    hour12: false
  }).formatToParts(date).reduce<Record<string, string>>((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});

  const hour = parts.hour || "";
  const minute = parts.minute || "00";
  return minute === "00" ? `${hour}時` : `${hour}時${minute}分`;
}

function buildSessionDetailUrl(sessionId: string, publicSiteBaseUrl = resolvePublicSiteBaseUrl()): string {
  const detailPath = `${SESSION_DETAIL_PAGE}?id=${encodeURIComponent(sessionId)}`;
  const baseUrl = normalizePublicSiteBaseUrl(publicSiteBaseUrl)
    || normalizePublicSiteBaseUrl(DEFAULT_PUBLIC_SITE_BASE_URL);
  if (!baseUrl) return detailPath;

  try {
    return new URL(detailPath, baseUrl).toString();
  } catch {
    return detailPath;
  }
}

function resolvePublicSiteBaseUrl(): string {
  return normalizePublicSiteBaseUrl(Deno.env.get(PUBLIC_SITE_BASE_URL_ENV))
    || normalizePublicSiteBaseUrl(DEFAULT_PUBLIC_SITE_BASE_URL);
}

function normalizePublicSiteBaseUrl(value: unknown): string {
  const text = normalizeText(value, 2048);
  if (!text) return "";
  try {
    const url = new URL(text);
    if (url.protocol !== "https:") return "";
    if (!url.pathname.endsWith("/")) {
      url.pathname = `${url.pathname}/`;
    }
    url.search = "";
    url.hash = "";
    return url.toString();
  } catch {
    return "";
  }
}

function isAbsoluteHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function truncateDiscordContent(value: string): string {
  return value.slice(0, 1900);
}

function isDiscordSnowflakeLike(value: string): boolean {
  return /^\d{10,30}$/.test(value);
}

function isDiscordUserId(value: string): boolean {
  return /^\d{17,20}$/.test(value);
}

function normalizeDiscordUserId(value: unknown): string | null {
  const text = normalizeText(value, 40);
  return isDiscordUserId(text) ? text : null;
}

function getGmDiscordUserId(row: Pick<PreviewReminderRow, "reminder_type" | "gm_discord_user_id">): string | null {
  if (row.reminder_type !== "gm_confirmed") return null;
  return normalizeDiscordUserId(row.gm_discord_user_id);
}

function shouldUseGmMention(row: Pick<PreviewReminderRow, "reminder_type" | "gm_discord_user_id">): boolean {
  return Boolean(getGmDiscordUserId(row));
}

function normalizeErrorSummary(value: unknown): string {
  return normalizeText(value, 120).replace(/[^a-z0-9_:-]/gi, "_") || "session_reminder_dispatch_error";
}

function normalizeText(value: unknown, maxLength: number): string {
  return String(value ?? "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function normalizeNullableText(value: unknown, maxLength: number): string | null {
  const text = normalizeText(value, maxLength);
  return text || null;
}

function normalizeNullableInteger(value: unknown): number | null {
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function jsonOk(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: CORS_HEADERS
  });
}

function jsonError(
  status: number,
  errorCode: ErrorCode,
  message: string,
  dryRun: boolean,
  stage?: ErrorStage
): Response {
  return new Response(JSON.stringify({
    ok: false,
    error_code: errorCode,
    ...(stage ? { stage } : {}),
    message,
    dry_run: dryRun
  }), {
    status,
    headers: CORS_HEADERS
  });
}
