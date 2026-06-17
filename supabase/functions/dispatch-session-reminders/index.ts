// DRAFT ONLY / NOT DEPLOYED BY CODEX.
// Dry-run dispatcher for session reminder previews.
//
// This function intentionally performs no Discord request and no DB write.
// It only calls preview_due_session_reminders with a service-role client.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ReminderType = "shortage" | "gm_confirmed";

type ErrorCode =
  | "config_missing"
  | "db_preview_failed"
  | "invalid_payload"
  | "method_not_allowed"
  | "production_not_enabled";

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
  reminder_offset_minutes: number | null;
  target_channel_key: string | null;
  session_public_id: string | null;
  scheduled_for: string | null;
}

type SupportedPreviewReminderRow = PreviewReminderRow & { reminder_type: ReminderType };

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
  discord_delivery_preview: {
    would_send: false;
    suppress_embeds: true;
    allowed_mentions: {
      parse: string[];
    };
  };
}

type SupabaseClient = ReturnType<typeof createClient>;

type PreviewDueSessionRemindersRpcResult = Promise<{
  data: PreviewReminderRow[] | null;
  error: unknown;
}>;

type SessionReminderRpc = (
  functionName: "preview_due_session_reminders",
  args: { p_now: string; p_limit: number }
) => PreviewDueSessionRemindersRpcResult;

type SessionReminderRpcClient = SupabaseClient & {
  rpc: SessionReminderRpc;
};

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const PUBLIC_SITE_BASE_URL_ENV = "PUBLIC_SITE_BASE_URL";
const SESSION_DETAIL_PAGE = "session-detail.html";

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
    return jsonError(405, "method_not_allowed", "POSTで呼び出してください。", true);
  }

  const parsedBody = await readJsonBody(request);
  if (!parsedBody.ok) {
    return jsonError(400, "invalid_payload", "リクエスト内容を確認してください。", true);
  }

  const optionsResult = readDispatchOptions(parsedBody.value);
  if (!optionsResult.ok) {
    return jsonError(400, "invalid_payload", optionsResult.message, true);
  }

  const options = optionsResult.value;
  if (!options.dryRun) {
    return jsonError(
      403,
      "production_not_enabled",
      "production dispatch is not enabled in this dry-run function.",
      false
    );
  }

  const clientResult = createServiceSupabaseClient();
  if (!clientResult.ok) {
    return jsonError(500, "config_missing", "Dispatcher configuration is missing.", true);
  }

  const previewResult = await previewDueSessionReminders(clientResult.client, options);
  if (!previewResult.ok) {
    return jsonError(500, "db_preview_failed", "Reminder preview failed.", true);
  }

  const publicSiteBaseUrl = normalizePublicSiteBaseUrl(Deno.env.get(PUBLIC_SITE_BASE_URL_ENV));
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
});

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
    reminder_offset_minutes: normalizeNullableInteger(row?.reminder_offset_minutes),
    target_channel_key: normalizeNullableText(row?.target_channel_key, 80),
    session_public_id: normalizeText(row?.session_public_id, 120) || normalizeText(row?.session_id, 120),
    scheduled_for: normalizeNullableText(row?.scheduled_for, 80)
  };
}

function isSupportedReminderRow(row: PreviewReminderRow): row is SupportedPreviewReminderRow {
  return row.reminder_type === "shortage" || row.reminder_type === "gm_confirmed";
}

function buildReminderPreviewItem(row: SupportedPreviewReminderRow, publicSiteBaseUrl: string): ReminderPreviewItem {
  const sessionUrl = buildSessionDetailUrl(row.session_public_id || row.session_id, publicSiteBaseUrl);
  const messagePreview = row.reminder_type === "shortage"
    ? buildShortageMessagePreview(row, sessionUrl)
    : buildGmConfirmedMessagePreview(row, sessionUrl);

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
    discord_delivery_preview: {
      would_send: false,
      suppress_embeds: true,
      allowed_mentions: {
        parse: row.reminder_type === "shortage" ? ["everyone"] : []
      }
    }
  };
}

function buildShortageMessagePreview(row: PreviewReminderRow, sessionUrl: string): string {
  const title = row.title || "タイトル未設定";
  const startTime = formatStartTimeForJapaneseMessage(row.start_at);
  const shortageCount = Math.max(0, row.shortage_count ?? 0);
  return [
    "@everyone",
    `■依頼書【${title}】［${sessionUrl}］`,
    `本日${startTime}より開催予定です。最低人数に後${shortageCount}人足りていません。ご都合よろしければ参加いかがでしょうか。`
  ].join("\n");
}

function buildGmConfirmedMessagePreview(row: PreviewReminderRow, sessionUrl: string): string {
  const title = row.title || "タイトル未設定";
  const startTime = formatStartTimeForJapaneseMessage(row.start_at);
  const gmName = row.gm_display_name || "GM";
  return [
    `GM向けリマインド：${gmName}さん`,
    `■依頼書【${title}】［${sessionUrl}］`,
    `本日${startTime}より開催予定です。最低人数を満たしているため、開催準備の確認をお願いします。`
  ].join("\n");
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

function buildSessionDetailUrl(sessionId: string, publicSiteBaseUrl = ""): string {
  const detailPath = `${SESSION_DETAIL_PAGE}?id=${encodeURIComponent(sessionId)}`;
  const baseUrl = normalizePublicSiteBaseUrl(publicSiteBaseUrl);
  if (!baseUrl) return detailPath;

  try {
    return new URL(detailPath, baseUrl).toString();
  } catch {
    return detailPath;
  }
}

function normalizePublicSiteBaseUrl(value: unknown): string {
  const text = normalizeText(value, 2048);
  if (!text) return "";
  try {
    const url = new URL(text);
    if (url.protocol !== "https:" && url.protocol !== "http:") return "";
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
