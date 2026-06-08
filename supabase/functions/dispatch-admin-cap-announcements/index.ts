// DRAFT ONLY / NOT DEPLOYED BY CODEX
// Admin-only cap update announcement dispatcher skeleton.
//
// This Edge Function draft is prepared for a later explicit deploy gate.
// It does not contain Webhook URL values, project URLs, JWTs, Discord IDs, or
// token values. Keep real credentials in Edge Function secrets/env only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type MentionMode = "none" | "everyone";
type TargetChannelKey = "cap_announcement";
type DeliveryStatus = "posted" | "scheduled" | "failed";

type ErrorCode =
  | "config_missing"
  | "cron_auth_required"
  | "db_claim_failed"
  | "db_finalize_failed"
  | "invalid_payload"
  | "method_not_allowed"
  | "real_send_not_enabled"
  | "unsupported_target_channel"
  | "webhook_config_missing"
  | "webhook_send_failed";

interface DispatchOptions {
  dryRun: boolean;
  batchLimit: number;
}

interface ClaimedAnnouncement {
  id: string;
  lock_token: string;
  announcement_title: string;
  announcement_body: string;
  target_channel_key: TargetChannelKey;
  scheduled_at: string;
  timezone: string | null;
  mention_mode: MentionMode;
  cap_level: string | null;
  apply_start_date: string | null;
  apply_end_date: string | null;
  note: string | null;
  attempt_count: number | null;
  max_attempts: number | null;
}

interface DiscordWebhookPayload {
  content: string;
  allowed_mentions: {
    parse: Array<"everyone">;
  };
}

type SupabaseClient = ReturnType<typeof createClient>;

type ClaimResult =
  | { ok: true; rows: ClaimedAnnouncement[] }
  | { ok: false; errorCode: ErrorCode };

type SendResult =
  | { ok: true }
  | { ok: false; errorCode: ErrorCode; retryable: boolean };

const DEFAULT_BATCH_LIMIT = 5;
const MAX_BATCH_LIMIT = 10;
const TARGET_CHANNEL_ENV_NAMES: Record<TargetChannelKey, string> = {
  cap_announcement: "DISCORD_WEBHOOK_CAP_ANNOUNCEMENT"
};

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
    return jsonError(405, "method_not_allowed", "POSTで呼び出してください。", true);
  }

  const parsedBody = await readJsonBody(request);
  if (!parsedBody.ok) {
    return jsonError(400, "invalid_payload", "リクエスト内容を確認してください。", true);
  }

  const options = readDispatchOptions(parsedBody.value);
  if (options.dryRun) {
    return jsonOk({
      ok: true,
      dry_run: true,
      planned_only: true,
      rpc_order: [
        "claim_due_admin_discord_announcements",
        "finalize_admin_discord_announcement"
      ],
      target_channel_mapping: {
        cap_announcement: TARGET_CHANNEL_ENV_NAMES.cap_announcement
      },
      delivery_policy: {
        none: { allowed_mentions: { parse: [] } },
        everyone: { allowed_mentions: { parse: ["everyone"] } }
      },
      note: "draft dry run only; no DB mutation and no Discord request"
    });
  }

  if (!isRealSendEnabled()) {
    return jsonError(403, "real_send_not_enabled", "実送信は未有効です。", false);
  }

  if (!hasCronAuthorization(request)) {
    return jsonError(401, "cron_auth_required", "cron呼び出し権限を確認できません。", false);
  }

  const clientResult = createServiceSupabaseClient();
  if (!clientResult.ok) {
    return jsonError(500, "config_missing", "Dispatcher設定が不足しています。", false);
  }

  const claimResult = await claimDueAnnouncements(clientResult.client, options.batchLimit);
  if (!claimResult.ok) {
    return jsonError(500, claimResult.errorCode, "予約告知のclaimに失敗しました。", false);
  }

  const results = [];
  for (const announcement of claimResult.rows) {
    const sendResult = await sendAnnouncement(announcement);
    const nextStatus = resolveNextStatus(sendResult);
    const finalizeResult = await finalizeAnnouncement(clientResult.client, announcement, nextStatus, sendResult);

    results.push({
      announcement_id: "redacted",
      target_channel_key: announcement.target_channel_key,
      delivery_status: nextStatus,
      delivery_error_code: sendResult.ok ? null : sendResult.errorCode,
      db_finalize: finalizeResult.ok ? "ok" : "failed"
    });
  }

  return jsonOk({
    ok: true,
    dry_run: false,
    claimed_count: claimResult.rows.length,
    results
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

function readDispatchOptions(value: Record<string, unknown>): DispatchOptions {
  return {
    dryRun: value.dry_run !== false,
    batchLimit: normalizeBatchLimit(value.batch_limit)
  };
}

function normalizeBatchLimit(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_BATCH_LIMIT;
  return Math.max(1, Math.min(MAX_BATCH_LIMIT, Math.floor(parsed)));
}

function isRealSendEnabled(): boolean {
  return Deno.env.get("ADMIN_CAP_ANNOUNCEMENT_REAL_SEND_ENABLED") === "true";
}

function hasCronAuthorization(request: Request): boolean {
  const expected = normalizeText(Deno.env.get("ADMIN_CAP_ANNOUNCEMENT_DISPATCH_TOKEN"), 300);
  const actual = normalizeText(request.headers.get("x-dispatch-token"), 300);
  return Boolean(expected && actual && expected === actual);
}

function createServiceSupabaseClient(): { ok: true; client: SupabaseClient } | { ok: false } {
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
    })
  };
}

async function claimDueAnnouncements(client: SupabaseClient, batchLimit: number): Promise<ClaimResult> {
  const { data, error } = await client.rpc("claim_due_admin_discord_announcements", {
    p_limit: batchLimit
  });

  if (error || !Array.isArray(data)) {
    return { ok: false, errorCode: "db_claim_failed" };
  }

  return {
    ok: true,
    rows: data
      .map((row) => normalizeClaimedAnnouncement(row))
      .filter((row): row is ClaimedAnnouncement => Boolean(row))
  };
}

function normalizeClaimedAnnouncement(row: unknown): ClaimedAnnouncement | null {
  if (!isRecord(row)) return null;

  const id = normalizeText(row.id, 80);
  const lockToken = normalizeText(row.lock_token, 80);
  const title = normalizeText(row.announcement_title, 120);
  const body = normalizeMultiline(row.announcement_body, 1800);
  const targetChannelKey = readTargetChannelKey(row.target_channel_key);
  const mentionMode = readMentionMode(row.mention_mode);

  if (!id || !lockToken || !title || !body || !targetChannelKey) return null;

  return {
    id,
    lock_token: lockToken,
    announcement_title: title,
    announcement_body: body,
    target_channel_key: targetChannelKey,
    scheduled_at: normalizeText(row.scheduled_at, 80),
    timezone: normalizeText(row.timezone, 80) || null,
    mention_mode: mentionMode,
    cap_level: normalizeText(row.cap_level, 40) || null,
    apply_start_date: normalizeText(row.apply_start_date, 20) || null,
    apply_end_date: normalizeText(row.apply_end_date, 20) || null,
    note: normalizeText(row.note, 500) || null,
    attempt_count: readNullableNumber(row.attempt_count),
    max_attempts: readNullableNumber(row.max_attempts)
  };
}

function readTargetChannelKey(value: unknown): TargetChannelKey | null {
  return value === "cap_announcement" ? "cap_announcement" : null;
}

function readMentionMode(value: unknown): MentionMode {
  return value === "everyone" ? "everyone" : "none";
}

async function sendAnnouncement(announcement: ClaimedAnnouncement): Promise<SendResult> {
  const webhook = readWebhookUrl(announcement.target_channel_key);
  if (!webhook.ok) {
    return { ok: false, errorCode: webhook.errorCode, retryable: false };
  }

  const response = await fetch(webhook.url, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify(buildDiscordWebhookPayload(announcement))
  });

  if (!response.ok) {
    return {
      ok: false,
      errorCode: "webhook_send_failed",
      retryable: response.status === 429 || response.status >= 500
    };
  }

  return { ok: true };
}

function readWebhookUrl(targetChannelKey: TargetChannelKey): { ok: true; url: string } | { ok: false; errorCode: ErrorCode } {
  const envName = TARGET_CHANNEL_ENV_NAMES[targetChannelKey];
  if (!envName) return { ok: false, errorCode: "unsupported_target_channel" };

  const url = Deno.env.get(envName);
  if (!url) return { ok: false, errorCode: "webhook_config_missing" };

  return { ok: true, url };
}

function buildDiscordWebhookPayload(announcement: ClaimedAnnouncement): DiscordWebhookPayload {
  return {
    content: buildDiscordContent(announcement),
    allowed_mentions: getAllowedMentions(announcement.mention_mode)
  };
}

function buildDiscordContent(announcement: ClaimedAnnouncement): string {
  const mentionLine = announcement.mention_mode === "everyone" ? "@everyone" : "";
  const capLine = announcement.cap_level ? `キャップLv: ${announcement.cap_level}` : "";
  const periodLine = formatPeriodLine(announcement.apply_start_date, announcement.apply_end_date);

  return [
    mentionLine,
    `【${announcement.announcement_title}】`,
    "",
    announcement.announcement_body,
    "",
    capLine,
    periodLine
  ].filter(Boolean).join("\n");
}

function formatPeriodLine(startDate: string | null, endDate: string | null): string {
  if (startDate && endDate) return `適用期間: ${startDate} - ${endDate}`;
  if (startDate) return `適用開始日: ${startDate}`;
  if (endDate) return `適用終了日: ${endDate}`;
  return "";
}

function getAllowedMentions(mentionMode: MentionMode): DiscordWebhookPayload["allowed_mentions"] {
  return mentionMode === "everyone"
    ? { parse: ["everyone"] }
    : { parse: [] };
}

function resolveNextStatus(sendResult: SendResult): DeliveryStatus {
  if (sendResult.ok) return "posted";
  return sendResult.retryable ? "scheduled" : "failed";
}

async function finalizeAnnouncement(
  client: SupabaseClient,
  announcement: ClaimedAnnouncement,
  nextStatus: DeliveryStatus,
  sendResult: SendResult
): Promise<{ ok: true } | { ok: false }> {
  const { error } = await client.rpc("finalize_admin_discord_announcement", {
    p_announcement_id: announcement.id,
    p_lock_token: announcement.lock_token,
    p_delivery_status: nextStatus,
    p_delivery_error_code: sendResult.ok ? null : sendResult.errorCode,
    p_retry_after_seconds: sendResult.ok || nextStatus === "failed" ? null : 60
  });

  return error ? { ok: false } : { ok: true };
}

function readNullableNumber(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeText(value: unknown, maxLength: number): string {
  return String(value ?? "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function normalizeMultiline(value: unknown, maxLength: number): string {
  return String(value ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .trim()
    .slice(0, maxLength);
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
