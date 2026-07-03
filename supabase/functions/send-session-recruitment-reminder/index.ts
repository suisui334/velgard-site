// Manual recruitment reminder sender.
//
// MR-04 adds the Edge Function source only. This file is not deployed in MR-04.
// Dry-run calls preview_manual_recruitment_reminder only: no Discord request,
// no DB write, and no claim/finalize RPC calls.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type FinalizeStatus = "sent" | "failed" | "skipped";

type ErrorCode =
  | "config_missing"
  | "db_claim_failed"
  | "db_finalize_failed"
  | "db_preview_failed"
  | "invalid_payload"
  | "login_required"
  | "method_not_allowed"
  | "production_not_enabled"
  | "webhook_config_missing"
  | "webhook_response_invalid"
  | "webhook_send_failed";

interface RequestOptions {
  sessionId: string;
  dryRun: boolean;
}

interface PreviewManualRecruitmentReminderRow {
  session_id: string | null;
  session_public_id: string | null;
  can_send: boolean | null;
  blocked_reason: string | null;
  title: string | null;
  start_at: string | null;
  player_min: number | null;
  accepted_count: number | null;
  pending_count: number | null;
  waitlisted_count: number | null;
  gm_display_name: string | null;
  cooldown_until: string | null;
  cooldown_seconds_remaining: number | null;
}

interface ClaimManualRecruitmentReminderRow {
  log_id: string | null;
  lock_token: string | null;
  session_id: string | null;
  session_public_id: string | null;
  title: string | null;
  start_at: string | null;
  player_min: number | null;
  accepted_count: number | null;
  pending_count: number | null;
  waitlisted_count: number | null;
  gm_display_name: string | null;
  cooldown_until: string | null;
}

interface FinalizeManualRecruitmentReminderRow {
  log_id: string | null;
  session_id: string | null;
  status: string | null;
  sent_at: string | null;
  failed_at: string | null;
  cooldown_until: string | null;
  finalized_at: string | null;
}

type SupabaseClient = ReturnType<typeof createClient>;

type PreviewManualRecruitmentReminderRpcResult = Promise<{
  data: PreviewManualRecruitmentReminderRow[] | null;
  error: unknown;
}>;

type ClaimManualRecruitmentReminderRpcResult = Promise<{
  data: ClaimManualRecruitmentReminderRow[] | null;
  error: unknown;
}>;

type FinalizeManualRecruitmentReminderRpcResult = Promise<{
  data: FinalizeManualRecruitmentReminderRow[] | null;
  error: unknown;
}>;

type ManualRecruitmentReminderRpc = {
  (
    functionName: "preview_manual_recruitment_reminder",
    args: { p_session_id: string }
  ): PreviewManualRecruitmentReminderRpcResult;
  (
    functionName: "claim_manual_recruitment_reminder",
    args: { p_session_id: string }
  ): ClaimManualRecruitmentReminderRpcResult;
  (
    functionName: "finalize_manual_recruitment_reminder",
    args: {
      p_log_id: string;
      p_lock_token: string;
      p_status: FinalizeStatus;
      p_discord_message_id: string | null;
      p_error_message: string | null;
    }
  ): FinalizeManualRecruitmentReminderRpcResult;
};

type ManualRecruitmentReminderRpcClient = SupabaseClient & {
  rpc: ManualRecruitmentReminderRpc;
};

type DiscordSendResult =
  | { ok: true; messageId: string }
  | { ok: false; errorCode: ErrorCode; retryable: boolean };

interface DiscordWebhookPayload {
  content: string;
  flags: number;
  allowed_mentions: {
    parse: Array<"everyone">;
  };
}

const DISCORD_SUPPRESS_EMBEDS_FLAG = 4;
const SESSION_DETAIL_PAGE = "session-detail.html";
const PUBLIC_SITE_BASE_URL_ENV = "PUBLIC_SITE_BASE_URL";
const DEFAULT_PUBLIC_SITE_BASE_URL = "https://suisui334.github.io/velgard-site/";
const SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED_ENV = "SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED";
const DISCORD_RECRUITMENT_REMINDER_WEBHOOK_URL_ENV = "DISCORD_SESSION_RECRUITMENT_REMINDER_WEBHOOK_URL";
const DISCORD_SESSION_REMINDER_WEBHOOK_URL_ENV = "DISCORD_SESSION_REMINDER_WEBHOOK_URL";

const CORS_HEADERS = {
  "access-control-allow-headers": "authorization, content-type, x-client-info, apikey",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-origin": "*",
  "content-type": "application/json; charset=utf-8"
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (request.method !== "POST") {
    return jsonError(405, "method_not_allowed", "POST is required.", true);
  }

  const authHeader = normalizeAuthorizationHeader(request.headers.get("authorization"));
  if (!authHeader) {
    return jsonError(401, "login_required", "Login is required.", true);
  }

  const parsedBody = await readJsonBody(request);
  if (!parsedBody.ok) {
    return jsonError(400, "invalid_payload", "Request body must be JSON.", true);
  }

  const optionsResult = readRequestOptions(parsedBody.value);
  if (!optionsResult.ok) {
    return jsonError(400, "invalid_payload", optionsResult.message, true);
  }

  const callerClientResult = createCallerSupabaseClient(authHeader);
  if (!callerClientResult.ok) {
    return jsonError(500, "config_missing", "Supabase caller configuration is missing.", optionsResult.value.dryRun);
  }

  if (optionsResult.value.dryRun) {
    return handleDryRun(callerClientResult.client, optionsResult.value);
  }

  return handleProductionSend(callerClientResult.client, optionsResult.value);
});

async function handleDryRun(
  callerClient: ManualRecruitmentReminderRpcClient,
  options: RequestOptions
): Promise<Response> {
  const previewResult = await previewManualRecruitmentReminder(callerClient, options.sessionId);
  if (!previewResult.ok) {
    return jsonError(502, "db_preview_failed", "Manual recruitment reminder preview failed.", true);
  }

  const publicSiteBaseUrl = resolvePublicSiteBaseUrl();
  const items = previewResult.rows.map((row) => buildPreviewItem(row, publicSiteBaseUrl));

  return jsonOk({
    ok: true,
    dry_run: true,
    count: items.length,
    items,
    safety: {
      preview_rpc_only: true,
      db_write: false,
      discord_send: false,
      claim_finalize: false,
      production_enabled: false
    }
  });
}

async function handleProductionSend(
  callerClient: ManualRecruitmentReminderRpcClient,
  options: RequestOptions
): Promise<Response> {
  const productionGate = readProductionGate();
  if (!productionGate.ok) {
    return jsonError(productionGate.status, productionGate.errorCode, productionGate.message, false);
  }

  const serviceClientResult = createServiceSupabaseClient();
  if (!serviceClientResult.ok) {
    return jsonError(500, "config_missing", "Supabase service configuration is missing.", false);
  }

  const claimResult = await claimManualRecruitmentReminder(callerClient, options.sessionId);
  if (!claimResult.ok) {
    return jsonError(502, "db_claim_failed", "Manual recruitment reminder claim failed.", false);
  }

  const publicSiteBaseUrl = resolvePublicSiteBaseUrl();
  const results = [];

  for (const row of claimResult.rows) {
    const sessionUrl = buildSessionDetailUrl(row.session_public_id || row.session_id, publicSiteBaseUrl);
    const sendResult = await sendDiscordRecruitmentReminder(row, sessionUrl, productionGate.webhookUrl);
    const finalizeStatus: FinalizeStatus = sendResult.ok ? "sent" : "failed";
    const errorSummary = sendResult.ok ? null : normalizeErrorSummary(sendResult.errorCode);
    const finalizeResult = await finalizeManualRecruitmentReminder(
      serviceClientResult.client,
      row,
      finalizeStatus,
      sendResult.ok ? sendResult.messageId : null,
      errorSummary
    );

    results.push({
      status: finalizeResult.ok ? finalizeStatus : "finalize_failed",
      title: normalizeText(row.title, 160) || "Untitled session",
      error_summary: finalizeResult.ok ? errorSummary : "db_finalize_failed",
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
      claim_finalize: true,
      allowed_mentions_parse: ["everyone"],
      suppress_embeds: true
    }
  });
}

async function previewManualRecruitmentReminder(
  client: ManualRecruitmentReminderRpcClient,
  sessionId: string
): Promise<{ ok: true; rows: PreviewManualRecruitmentReminderRow[] } | { ok: false }> {
  try {
    const result = await client.rpc("preview_manual_recruitment_reminder", {
      p_session_id: sessionId
    });
    if (result.error || !Array.isArray(result.data) || result.data.length === 0) return { ok: false };
    return { ok: true, rows: result.data.map(normalizePreviewRow) };
  } catch {
    return { ok: false };
  }
}

async function claimManualRecruitmentReminder(
  client: ManualRecruitmentReminderRpcClient,
  sessionId: string
): Promise<{ ok: true; rows: RequiredClaimRow[] } | { ok: false }> {
  try {
    const result = await client.rpc("claim_manual_recruitment_reminder", {
      p_session_id: sessionId
    });
    if (result.error || !Array.isArray(result.data)) return { ok: false };
    const rows = result.data.map(normalizeClaimRow).filter(isRequiredClaimRow);
    if (rows.length === 0) return { ok: false };
    return { ok: true, rows };
  } catch {
    return { ok: false };
  }
}

async function finalizeManualRecruitmentReminder(
  client: ManualRecruitmentReminderRpcClient,
  row: RequiredClaimRow,
  status: FinalizeStatus,
  discordMessageId: string | null,
  errorMessage: string | null
): Promise<{ ok: true } | { ok: false }> {
  try {
    const result = await client.rpc("finalize_manual_recruitment_reminder", {
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

type RequiredClaimRow = ClaimManualRecruitmentReminderRow & {
  log_id: string;
  lock_token: string;
};

function isRequiredClaimRow(row: ClaimManualRecruitmentReminderRow): row is RequiredClaimRow {
  return Boolean(row.log_id && row.lock_token);
}

function buildPreviewItem(row: PreviewManualRecruitmentReminderRow, publicSiteBaseUrl: string) {
  const sessionUrl = buildSessionDetailUrl(row.session_public_id || row.session_id, publicSiteBaseUrl);
  const messagePreview = buildRecruitmentReminderMessage(row, sessionUrl);

  return {
    can_send: row.can_send === true,
    blocked_reason: row.blocked_reason,
    title: row.title || "Untitled session",
    start_at: row.start_at,
    player_min: row.player_min,
    accepted_count: row.accepted_count ?? 0,
    pending_count: row.pending_count ?? 0,
    waitlisted_count: row.waitlisted_count ?? 0,
    gm_display_name: row.gm_display_name || "GM",
    cooldown_until: row.cooldown_until,
    cooldown_seconds_remaining: row.cooldown_seconds_remaining ?? 0,
    session_url: sessionUrl,
    message_preview: messagePreview,
    discord_delivery_preview: {
      would_send: false,
      suppress_embeds: true,
      session_url_is_absolute: isAbsoluteHttpUrl(sessionUrl),
      allowed_mentions: {
        parse: ["everyone"]
      },
      content_has_everyone: messagePreview.includes("@everyone")
    }
  };
}

async function sendDiscordRecruitmentReminder(
  row: RequiredClaimRow,
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

function buildDiscordWebhookPayload(row: ClaimManualRecruitmentReminderRow, sessionUrl: string): DiscordWebhookPayload {
  return {
    content: truncateDiscordContent(buildRecruitmentReminderMessage(row, sessionUrl)),
    flags: DISCORD_SUPPRESS_EMBEDS_FLAG,
    allowed_mentions: {
      parse: ["everyone"]
    }
  };
}

function buildRecruitmentReminderMessage(
  row: Pick<
    PreviewManualRecruitmentReminderRow,
    "title" | "player_min" | "accepted_count" | "pending_count"
  >,
  sessionUrl: string
): string {
  const title = row.title || "Untitled session";
  const acceptedCount = Math.max(0, row.accepted_count ?? 0);
  const pendingCount = Math.max(0, row.pending_count ?? 0);
  const playerMin = Math.max(0, row.player_min ?? 0);

  return [
    "@everyone",
    `■依頼書【${title}】［${sessionUrl}］`,
    "現在、参加者を募集しています。",
    "ご都合よろしければ参加をご検討ください。",
    `現在の参加状況：承認済み${acceptedCount}名 / 申請中${pendingCount}名 / 最低人数${playerMin}名`
  ].join("\n");
}

function readProductionGate(): {
  ok: true;
  webhookUrl: string;
} | {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  message: string;
} {
  if (Deno.env.get(SESSION_MANUAL_RECRUITMENT_REAL_SEND_ENABLED_ENV) !== "true") {
    return {
      ok: false,
      status: 403,
      errorCode: "production_not_enabled",
      message: "production send is not enabled."
    };
  }

  const webhookUrl = readDiscordWebhookUrl();
  if (!webhookUrl.ok) {
    return {
      ok: false,
      status: 502,
      errorCode: "webhook_config_missing",
      message: "Discord Webhook is not configured."
    };
  }

  return { ok: true, webhookUrl: webhookUrl.value };
}

function readDiscordWebhookUrl(): { ok: true; value: string } | { ok: false } {
  const rawUrl = normalizeText(Deno.env.get(DISCORD_RECRUITMENT_REMINDER_WEBHOOK_URL_ENV), 2048)
    || normalizeText(Deno.env.get(DISCORD_SESSION_REMINDER_WEBHOOK_URL_ENV), 2048);
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

function createCallerSupabaseClient(authHeader: string): { ok: true; client: ManualRecruitmentReminderRpcClient } | { ok: false } {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) return { ok: false };

  return {
    ok: true,
    client: createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      },
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    }) as ManualRecruitmentReminderRpcClient
  };
}

function createServiceSupabaseClient(): { ok: true; client: ManualRecruitmentReminderRpcClient } | { ok: false } {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return { ok: false };

  return {
    ok: true,
    client: createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }) as ManualRecruitmentReminderRpcClient
  };
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

function readRequestOptions(value: Record<string, unknown>): { ok: true; value: RequestOptions } | { ok: false; message: string } {
  const sessionId = normalizeText(value.session_id, 160);
  if (!sessionId) {
    return { ok: false, message: "session_id is required." };
  }

  return {
    ok: true,
    value: {
      sessionId,
      dryRun: value.dry_run !== false
    }
  };
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

function buildDiscordWebhookWaitUrl(webhookUrl: string): string {
  const url = new URL(webhookUrl);
  url.searchParams.set("wait", "true");
  return url.toString();
}

function buildSessionDetailUrl(sessionId: string | null, publicSiteBaseUrl = resolvePublicSiteBaseUrl()): string {
  const safeSessionId = normalizeText(sessionId, 160);
  const detailPath = `${SESSION_DETAIL_PAGE}?id=${encodeURIComponent(safeSessionId)}`;
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

function normalizePreviewRow(row: PreviewManualRecruitmentReminderRow): PreviewManualRecruitmentReminderRow {
  return {
    session_id: normalizeNullableText(row?.session_id, 160),
    session_public_id: normalizeNullableText(row?.session_public_id, 160),
    can_send: row?.can_send === true,
    blocked_reason: normalizeNullableText(row?.blocked_reason, 80),
    title: normalizeNullableText(row?.title, 160),
    start_at: normalizeNullableText(row?.start_at, 80),
    player_min: normalizeNullableInteger(row?.player_min),
    accepted_count: normalizeNullableInteger(row?.accepted_count),
    pending_count: normalizeNullableInteger(row?.pending_count),
    waitlisted_count: normalizeNullableInteger(row?.waitlisted_count),
    gm_display_name: normalizeNullableText(row?.gm_display_name, 80),
    cooldown_until: normalizeNullableText(row?.cooldown_until, 80),
    cooldown_seconds_remaining: normalizeNullableInteger(row?.cooldown_seconds_remaining)
  };
}

function normalizeClaimRow(row: ClaimManualRecruitmentReminderRow): ClaimManualRecruitmentReminderRow {
  return {
    log_id: normalizeNullableText(row?.log_id, 120),
    lock_token: normalizeNullableText(row?.lock_token, 120),
    session_id: normalizeNullableText(row?.session_id, 160),
    session_public_id: normalizeNullableText(row?.session_public_id, 160),
    title: normalizeNullableText(row?.title, 160),
    start_at: normalizeNullableText(row?.start_at, 80),
    player_min: normalizeNullableInteger(row?.player_min),
    accepted_count: normalizeNullableInteger(row?.accepted_count),
    pending_count: normalizeNullableInteger(row?.pending_count),
    waitlisted_count: normalizeNullableInteger(row?.waitlisted_count),
    gm_display_name: normalizeNullableText(row?.gm_display_name, 80),
    cooldown_until: normalizeNullableText(row?.cooldown_until, 80)
  };
}

function normalizeAuthorizationHeader(value: unknown): string {
  const text = normalizeText(value, 4096);
  return /^Bearer\s+\S+$/i.test(text) ? text : "";
}

function normalizeErrorSummary(value: unknown): string {
  return normalizeText(value, 120).replace(/[^a-z0-9_:-]/gi, "_") || "manual_recruitment_reminder_error";
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

function truncateDiscordContent(value: string): string {
  return value.slice(0, 1900);
}

function isDiscordSnowflakeLike(value: string): boolean {
  return /^\d{10,30}$/.test(value);
}

function isAbsoluteHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
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

function jsonError(status: number, errorCode: ErrorCode, message: string, dryRun: boolean): Response {
  return new Response(JSON.stringify({
    ok: false,
    error_code: errorCode,
    message,
    dry_run: dryRun
  }), {
    status,
    headers: CORS_HEADERS
  });
}
