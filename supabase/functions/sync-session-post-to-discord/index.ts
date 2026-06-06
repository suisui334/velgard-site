import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SyncAction = "create" | "update" | "close" | "delete" | "resync";

type ErrorCode =
  | "config_missing"
  | "db_update_failed"
  | "discord_create_already_synced"
  | "discord_sent_db_update_failed"
  | "invalid_action"
  | "invalid_payload"
  | "login_required"
  | "method_not_allowed"
  | "missing_post_reference"
  | "not_allowed"
  | "not_sync_target"
  | "real_send_not_enabled"
  | "session_not_found"
  | "unsupported_action"
  | "webhook_config_missing"
  | "webhook_response_invalid"
  | "webhook_send_failed";

interface ValidPayload {
  sessionId: string;
  action: SyncAction;
  dryRun: boolean;
  requestSource: string | null;
}

interface SessionRow {
  id: string;
  title: string | null;
  summary: string | null;
  status: string | null;
  visibility: string | null;
  session_type: string | null;
  session_tool: string | null;
  date: string | null;
  start_time: string | null;
  end_time: string | null;
  end_at: string | null;
  application_deadline: string | null;
  player_min: number | null;
  player_max: number | null;
  gm_name: string | null;
  discord_sync_status: string | null;
  discord_last_action: string | null;
  discord_sync_requested_at: string | null;
  discord_synced_at: string | null;
  discord_sync_error: string | null;
  discord_message_id: string | null;
  discord_channel_id: string | null;
  discord_thread_id: string | null;
  discord_post_url: string | null;
}

type BooleanRpcResult = Promise<{ data: boolean | null; error: unknown }>;
type IsSessionGmRpc = (
  functionName: "is_session_gm",
  args: { target_session_id: string }
) => BooleanRpcResult;
type IsSessionGmRpcClient = ReturnType<typeof createClient> & {
  rpc: IsSessionGmRpc;
};

interface DiscordCreateReadyRow {
  can_send: boolean | null;
  has_existing_post: boolean | null;
}

interface DiscordCreateRecordRow {
  discord_sync_status: string | null;
  discord_last_action: string | null;
  has_external_post_identifier?: boolean | null;
}

interface DiscordFailureRecordRow {
  discord_sync_status: string | null;
  discord_last_action: string | null;
}

type DiscordCreateReadyRpcResult = Promise<{ data: DiscordCreateReadyRow[] | null; error: unknown }>;
type DiscordCreateSuccessRpcResult = Promise<{ data: DiscordCreateRecordRow[] | null; error: unknown }>;
type DiscordCreateFailureRpcResult = Promise<{ data: DiscordFailureRecordRow[] | null; error: unknown }>;
type DiscordSyncRpc = {
  (
    functionName: "check_discord_session_post_create_ready",
    args: { p_session_id: string }
  ): DiscordCreateReadyRpcResult;
  (
    functionName: "record_discord_session_post_create_success",
    args: {
      p_session_id: string;
      p_discord_message_id: string;
      p_discord_channel_id: string | null;
      p_discord_thread_id: string | null;
      p_discord_post_url: string | null;
    }
  ): DiscordCreateSuccessRpcResult;
  (
    functionName: "record_discord_session_post_create_failure",
    args: { p_session_id: string; p_error_code: string | null }
  ): DiscordCreateFailureRpcResult;
};
type DiscordSyncRpcClient = ReturnType<typeof createClient> & {
  rpc: DiscordSyncRpc;
};

interface SyncTargetJudgment {
  isTarget: boolean;
  reason: string;
}

interface DiscordWebhookPayload {
  content: string;
  allowed_mentions: {
    parse: string[];
  };
}

type DiscordWebhookErrorCode =
  | "webhook_config_missing"
  | "webhook_send_failed"
  | "webhook_response_invalid";

type DiscordWebhookDraftResult =
  | {
    ok: true;
    messageId: string | null;
    channelId: string | null;
    threadId: string | null;
    postUrl: string | null;
  }
  | {
    ok: false;
    status: number;
    errorCode: DiscordWebhookErrorCode;
  };

const ALLOWED_ACTIONS = new Set<SyncAction>(["create", "update", "close", "delete", "resync"]);
const SYNC_TARGET_STATUSES = new Set(["tentative", "recruiting", "full", "closed", "finished"]);
const CLOSED_STATUSES = new Set(["closed", "finished"]);
const DISCORD_SESSION_POST_WEBHOOK_URL_ENV = "DISCORD_SESSION_POST_WEBHOOK_URL";
const SESSION_SELECT_COLUMNS = [
  "id",
  "title",
  "summary",
  "status",
  "visibility",
  "session_type",
  "session_tool",
  "date",
  "start_time",
  "end_time",
  "end_at",
  "application_deadline",
  "player_min",
  "player_max",
  "gm_name",
  "discord_sync_status",
  "discord_last_action",
  "discord_sync_requested_at",
  "discord_synced_at",
  "discord_sync_error",
  "discord_message_id",
  "discord_channel_id",
  "discord_thread_id",
  "discord_post_url"
].join(",");

const STATUS_LABELS: Record<string, string> = {
  draft: "下書き",
  tentative: "仮予定",
  recruiting: "募集中",
  full: "満席",
  closed: "締切",
  finished: "終了",
  canceled: "中止"
};

const VISIBILITY_LABELS: Record<string, string> = {
  hidden: "非公開",
  private: "限定",
  public: "公開"
};

const SESSION_TYPE_LABELS: Record<string, string> = {
  "one-shot": "単発シナリオ",
  campaign: "キャンペーン",
  special: "特殊",
  other: "その他"
};

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

  const parsedJson = await readJsonBody(request);
  if (!parsedJson.ok) {
    return jsonError(400, "invalid_payload", "リクエスト内容を確認してください。", true);
  }

  const payload = validatePayload(parsedJson.value);
  if (!payload.ok) {
    return jsonError(payload.status, payload.errorCode, payload.message, payload.dryRun);
  }

  if (!payload.value.dryRun && payload.value.action !== "create") {
    return jsonError(
      501,
      "unsupported_action",
      "この同期アクションの実送信はまだ有効化していません。",
      false,
      { action: payload.value.action }
    );
  }

  const authHeader = request.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return jsonError(401, "login_required", "ログインが必要です。", payload.value.dryRun);
  }

  const clientResult = createCallerSupabaseClient(authHeader);
  if (!clientResult.ok) {
    return jsonError(500, "config_missing", "同期確認の設定が不足しています。", payload.value.dryRun);
  }

  const supabase = clientResult.client;
  const hasPermission = await verifyManagementPermission(supabase, payload.value.sessionId);
  if (!hasPermission.ok) {
    return jsonError(403, "not_allowed", "この依頼書を同期する権限を確認できませんでした。", payload.value.dryRun);
  }

  if (!hasPermission.allowed) {
    return jsonError(403, "not_allowed", "この依頼書を同期する権限がありません。", payload.value.dryRun);
  }

  const sessionResult = await fetchSession(supabase, payload.value.sessionId);
  if (!sessionResult.ok) {
    return jsonError(404, "session_not_found", "対象の依頼書が見つかりません。", payload.value.dryRun);
  }

  const session = sessionResult.session;
  const syncTarget = judgeSyncTarget(session);
  const hasExternalPostReference = hasPostReference(session);
  const warnings = buildWarnings(payload.value.action, session, syncTarget, hasExternalPostReference);
  const actionError = validateActionForSession(payload.value.action, syncTarget, hasExternalPostReference);

  if (actionError) {
    return jsonError(actionError.status, actionError.errorCode, actionError.message, payload.value.dryRun, {
      action: payload.value.action,
      sync_target: {
        eligible: syncTarget.isTarget,
        reason: syncTarget.reason
      },
      warnings
    });
  }

  const messagePreview = buildMessagePreview(session, payload.value.action);

  if (payload.value.dryRun) {
    return jsonOk({
      ok: true,
      dry_run: true,
      action: payload.value.action,
      sync_target: {
        eligible: syncTarget.isTarget,
        reason: syncTarget.reason
      },
      message_preview: messagePreview,
      planned_db_update: buildPlannedDbUpdate(payload.value.action, hasExternalPostReference),
      warnings
    });
  }

  const createGuard = await checkDiscordCreateReady(supabase, payload.value.sessionId);
  if (!createGuard.ok) {
    return jsonError(createGuard.status, createGuard.errorCode, createGuard.message, false, {
      action: payload.value.action,
      sync_target: {
        eligible: syncTarget.isTarget,
        reason: syncTarget.reason
      },
      discord_send: {
        status: "not_sent"
      },
      db_update: {
        success: false,
        reason: "create_guard_failed"
      },
      warnings: mergeWarnings(warnings, createGuard.warning)
    });
  }

  const sendResult = await sendDiscordWebhookDraft(messagePreview);
  if (!sendResult.ok) {
    const failureRecord = await recordDiscordCreateFailure(supabase, payload.value.sessionId, sendResult.errorCode);
    return jsonError(
      sendResult.status,
      sendResult.errorCode,
      messageForWebhookError(sendResult.errorCode),
      false,
      {
        action: payload.value.action,
        sync_target: {
          eligible: syncTarget.isTarget,
          reason: syncTarget.reason
        },
        discord_send: {
          status: "failed"
        },
        db_update: {
          success: failureRecord.ok,
          reason: failureRecord.ok ? "failure_recorded" : "failure_record_failed"
        },
        warnings: mergeWarnings(
          warnings,
          failureRecord.ok ? null : "同期失敗の記録にも失敗しました。再実行せず、手動確認してください。"
        )
      }
    );
  }

  const successRecord = await recordDiscordCreateSuccess(supabase, payload.value.sessionId, sendResult);
  if (!successRecord.ok) {
    const failureRecord = await recordDiscordCreateFailure(
      supabase,
      payload.value.sessionId,
      "discord_sent_db_update_failed"
    );

    return jsonError(
      500,
      "discord_sent_db_update_failed",
      "Discord投稿は完了しましたが、同期状態の記録に失敗しました。再実行せず、手動確認してください。",
      false,
      {
        action: payload.value.action,
        sync_target: {
          eligible: syncTarget.isTarget,
          reason: syncTarget.reason
        },
        discord_send: {
          status: "posted",
          message_reference: sendResult.messageId ? "received" : "not_returned"
        },
        db_update: {
          success: false,
          reason: "success_record_failed",
          failure_recorded: failureRecord.ok
        },
        warnings: mergeWarnings(
          warnings,
          "Discord投稿済みのため、同じcreateを再実行しないでください。"
        )
      }
    );
  }

  return jsonOk({
    ok: true,
    dry_run: false,
    action: payload.value.action,
    sync_target: {
      eligible: syncTarget.isTarget,
      reason: syncTarget.reason
    },
    discord_send: {
      status: "posted",
      message_reference: sendResult.messageId ? "received" : "not_returned"
    },
    db_update: {
      success: true,
      status: "recorded",
      sync_status: successRecord.syncStatus,
      last_action: successRecord.lastAction,
      external_post_identifier_saved: successRecord.hasExternalPostIdentifier
    },
    warnings
  });
});

async function readJsonBody(request: Request): Promise<{ ok: true; value: unknown } | { ok: false }> {
  try {
    return { ok: true, value: await request.json() };
  } catch {
    return { ok: false };
  }
}

function validatePayload(
  value: unknown
): { ok: true; value: ValidPayload } | {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  message: string;
  dryRun: boolean;
} {
  if (!isRecord(value)) {
    return invalidPayload("リクエスト内容を確認してください。");
  }

  const sessionId = typeof value.session_id === "string" ? value.session_id.trim() : "";
  if (!sessionId || sessionId.length > 160 || /\s/.test(sessionId)) {
    return invalidPayload("対象の依頼書を指定してください。");
  }

  const action = typeof value.action === "string" ? value.action.trim() : "";
  if (!ALLOWED_ACTIONS.has(action as SyncAction)) {
    return {
      ok: false,
      status: 400,
      errorCode: "invalid_action",
      message: "未対応の同期アクションです。",
      dryRun: readDryRunFlag(value)
    };
  }

  if ("dry_run" in value && typeof value.dry_run !== "boolean") {
    return invalidPayload("dry_runはtrueまたはfalseで指定してください。");
  }

  const requestSource = typeof value.request_source === "string"
    ? normalizeText(value.request_source, 40)
    : null;

  return {
    ok: true,
    value: {
      sessionId,
      action: action as SyncAction,
      dryRun: readDryRunFlag(value),
      requestSource
    }
  };
}

function invalidPayload(message: string): {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  message: string;
  dryRun: boolean;
} {
  return {
    ok: false,
    status: 400,
    errorCode: "invalid_payload",
    message,
    dryRun: true
  };
}

function readDryRunFlag(value: Record<string, unknown>): boolean {
  return typeof value.dry_run === "boolean" ? value.dry_run : true;
}

function createCallerSupabaseClient(authHeader: string): { ok: true; client: ReturnType<typeof createClient> } | { ok: false } {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    return { ok: false };
  }

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
    })
  };
}

async function sendDiscordWebhookDraft(messagePreview: string): Promise<DiscordWebhookDraftResult> {
  const webhookUrl = readDiscordWebhookUrl();
  if (!webhookUrl.ok) {
    return {
      ok: false,
      status: 500,
      errorCode: "webhook_config_missing"
    };
  }

  const response = await fetch(withDiscordWebhookWait(webhookUrl.value), {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify(buildDiscordWebhookPayload(messagePreview))
  });

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      errorCode: "webhook_send_failed"
    };
  }

  const responseBody = await readDiscordWebhookResponse(response);
  if (!responseBody.ok) {
    return {
      ok: false,
      status: response.status,
      errorCode: "webhook_response_invalid"
    };
  }

  const messageId = extractDiscordMessageId(responseBody.value);
  const channelId = extractDiscordTextField(responseBody.value, "channel_id");
  const guildId = extractDiscordTextField(responseBody.value, "guild_id");

  return {
    ok: true,
    messageId,
    channelId,
    threadId: extractDiscordThreadId(responseBody.value),
    postUrl: buildDiscordPostUrl(guildId, channelId, messageId)
  };
}

function readDiscordWebhookUrl(): { ok: true; value: string } | { ok: false } {
  const rawUrl = normalizeText(Deno.env.get(DISCORD_SESSION_POST_WEBHOOK_URL_ENV), 2048);
  if (!rawUrl) {
    return { ok: false };
  }

  try {
    const parsedUrl = new URL(rawUrl);
    const isDiscordHost = parsedUrl.hostname === "discord.com" || parsedUrl.hostname === "discordapp.com";
    const isWebhookPath = parsedUrl.pathname.startsWith("/api/webhooks/");
    if (parsedUrl.protocol !== "https:" || !isDiscordHost || !isWebhookPath) {
      return { ok: false };
    }

    return { ok: true, value: rawUrl };
  } catch {
    return { ok: false };
  }
}

function buildDiscordWebhookPayload(messagePreview: string): DiscordWebhookPayload {
  return {
    content: truncateDiscordContent(messagePreview),
    allowed_mentions: {
      parse: []
    }
  };
}

function withDiscordWebhookWait(webhookUrl: string): string {
  const separator = webhookUrl.includes("?") ? "&" : "?";
  return `${webhookUrl}${separator}wait=true`;
}

async function readDiscordWebhookResponse(
  response: Response
): Promise<{ ok: true; value: unknown } | { ok: false }> {
  try {
    return { ok: true, value: await response.json() };
  } catch {
    return { ok: false };
  }
}

function extractDiscordMessageId(value: unknown): string | null {
  return extractDiscordTextField(value, "id");
}

function extractDiscordTextField(value: unknown, fieldName: string): string | null {
  if (!isRecord(value) || typeof value[fieldName] !== "string") {
    return null;
  }

  return normalizeText(value[fieldName], 120) || null;
}

function extractDiscordThreadId(value: unknown): string | null {
  if (!isRecord(value) || !isRecord(value.thread) || typeof value.thread.id !== "string") {
    return null;
  }

  return normalizeText(value.thread.id, 120) || null;
}

function buildDiscordPostUrl(guildId: string | null, channelId: string | null, messageId: string | null): string | null {
  if (!isDiscordSnowflakeLike(guildId) || !isDiscordSnowflakeLike(channelId) || !isDiscordSnowflakeLike(messageId)) {
    return null;
  }

  return `https://discord.com/channels/${guildId}/${channelId}/${messageId}`;
}

function isDiscordSnowflakeLike(value: string | null): value is string {
  return typeof value === "string" && /^\d{10,32}$/.test(value);
}

function truncateDiscordContent(value: string): string {
  return value.slice(0, 1900);
}

function messageForWebhookError(errorCode: DiscordWebhookErrorCode): string {
  switch (errorCode) {
    case "webhook_config_missing":
      return "Discord投稿先の設定を確認できませんでした。";
    case "webhook_response_invalid":
      return "Discord投稿の結果を確認できませんでした。";
    case "webhook_send_failed":
    default:
      return "Discord投稿に失敗しました。";
  }
}

function callIsSessionGmRpc(
  supabase: ReturnType<typeof createClient>,
  sessionId: string
): BooleanRpcResult {
  const rpcClient = supabase as unknown as IsSessionGmRpcClient;
  return rpcClient.rpc("is_session_gm", { target_session_id: sessionId });
}

async function verifyManagementPermission(
  supabase: ReturnType<typeof createClient>,
  sessionId: string
): Promise<{ ok: true; allowed: boolean } | { ok: false }> {
  const [adminResult, gmResult] = await Promise.all([
    supabase.rpc("is_admin"),
    callIsSessionGmRpc(supabase, sessionId)
  ]);

  if (adminResult.error || gmResult.error) {
    return { ok: false };
  }

  return {
    ok: true,
    allowed: Boolean(adminResult.data) || Boolean(gmResult.data)
  };
}

async function checkDiscordCreateReady(
  supabase: ReturnType<typeof createClient>,
  sessionId: string
): Promise<{ ok: true } | {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  message: string;
  warning: string | null;
}> {
  const rpcClient = supabase as unknown as DiscordSyncRpcClient;
  const { data, error } = await rpcClient.rpc("check_discord_session_post_create_ready", {
    p_session_id: sessionId
  });

  if (error) {
    return mapDiscordSyncRpcError(error, "db_update_failed", "Discord同期の事前確認に失敗しました。");
  }

  const row = firstRow(data);
  if (!row || row.can_send !== true || row.has_existing_post === true) {
    return {
      ok: false,
      status: 409,
      errorCode: "discord_create_already_synced",
      message: "既存のDiscord投稿があるため、新規投稿は実行できません。",
      warning: "既存投稿がある場合はupdateまたはresyncを検討してください。"
    };
  }

  return { ok: true };
}

async function recordDiscordCreateSuccess(
  supabase: ReturnType<typeof createClient>,
  sessionId: string,
  sendResult: Extract<DiscordWebhookDraftResult, { ok: true }>
): Promise<{
  ok: true;
  syncStatus: string | null;
  lastAction: string | null;
  hasExternalPostIdentifier: boolean;
} | { ok: false }> {
  const rpcClient = supabase as unknown as DiscordSyncRpcClient;
  const { data, error } = await rpcClient.rpc("record_discord_session_post_create_success", {
    p_session_id: sessionId,
    p_discord_message_id: sendResult.messageId ?? "",
    p_discord_channel_id: sendResult.channelId,
    p_discord_thread_id: sendResult.threadId,
    p_discord_post_url: sendResult.postUrl
  });

  if (error) {
    return { ok: false };
  }

  const row = firstRow(data);
  if (!row) {
    return { ok: false };
  }

  return {
    ok: true,
    syncStatus: normalizeText(row.discord_sync_status, 40) || null,
    lastAction: normalizeText(row.discord_last_action, 40) || null,
    hasExternalPostIdentifier: row.has_external_post_identifier === true
  };
}

async function recordDiscordCreateFailure(
  supabase: ReturnType<typeof createClient>,
  sessionId: string,
  errorCode: string
): Promise<{ ok: true } | { ok: false }> {
  const rpcClient = supabase as unknown as DiscordSyncRpcClient;
  const { data, error } = await rpcClient.rpc("record_discord_session_post_create_failure", {
    p_session_id: sessionId,
    p_error_code: normalizeErrorCode(errorCode)
  });

  if (error) {
    return { ok: false };
  }

  return firstRow(data) ? { ok: true } : { ok: false };
}

function mapDiscordSyncRpcError(
  error: unknown,
  fallbackCode: ErrorCode,
  fallbackMessage: string
): {
  ok: false;
  status: number;
  errorCode: ErrorCode;
  message: string;
  warning: string | null;
} {
  const message = extractErrorMessage(error);
  if (message.includes("discord_create_already_synced")) {
    return {
      ok: false,
      status: 409,
      errorCode: "discord_create_already_synced",
      message: "既存のDiscord投稿があるため、新規投稿は実行できません。",
      warning: "既存投稿がある場合はupdateまたはresyncを検討してください。"
    };
  }

  if (message.includes("session_not_found")) {
    return {
      ok: false,
      status: 404,
      errorCode: "session_not_found",
      message: "対象の依頼書が見つかりません。",
      warning: null
    };
  }

  if (message.includes("login_required")) {
    return {
      ok: false,
      status: 401,
      errorCode: "login_required",
      message: "ログインが必要です。",
      warning: null
    };
  }

  if (message.includes("not_allowed")) {
    return {
      ok: false,
      status: 403,
      errorCode: "not_allowed",
      message: "この依頼書を同期する権限がありません。",
      warning: null
    };
  }

  return {
    ok: false,
    status: 500,
    errorCode: fallbackCode,
    message: fallbackMessage,
    warning: "同期状態の事前確認に失敗しました。"
  };
}

async function fetchSession(
  supabase: ReturnType<typeof createClient>,
  sessionId: string
): Promise<{ ok: true; session: SessionRow } | { ok: false }> {
  const { data, error } = await supabase
    .from("sessions")
    .select(SESSION_SELECT_COLUMNS)
    .eq("id", sessionId)
    .maybeSingle();

  if (error || !data) {
    return { ok: false };
  }

  return { ok: true, session: data as SessionRow };
}

function judgeSyncTarget(session: SessionRow): SyncTargetJudgment {
  const visibility = normalizeText(session.visibility, 40);
  const status = normalizeText(session.status, 40);

  if (visibility !== "public") {
    return { isTarget: false, reason: "not_public" };
  }

  if (status === "draft") {
    return { isTarget: false, reason: "draft_public_guard" };
  }

  if (status === "canceled") {
    return { isTarget: false, reason: "canceled" };
  }

  if (!SYNC_TARGET_STATUSES.has(status)) {
    return { isTarget: false, reason: "unsupported_status" };
  }

  return { isTarget: true, reason: "public_sync_target" };
}

function validateActionForSession(
  action: SyncAction,
  syncTarget: SyncTargetJudgment,
  hasExternalPostReference: boolean
): { status: number; errorCode: ErrorCode; message: string } | null {
  if (action === "delete") {
    return hasExternalPostReference
      ? null
      : {
        status: 409,
        errorCode: "missing_post_reference",
        message: "既存投稿を安全に扱うための参照情報がありません。"
      };
  }

  if (!syncTarget.isTarget) {
    return {
      status: 409,
      errorCode: "not_sync_target",
      message: "この依頼書は現在の状態では同期対象外です。"
    };
  }

  if ((action === "update" || action === "close") && !hasExternalPostReference) {
    return {
      status: 409,
      errorCode: "missing_post_reference",
      message: "既存投稿を更新するための参照情報がありません。"
    };
  }

  return null;
}

function buildWarnings(
  action: SyncAction,
  session: SessionRow,
  syncTarget: SyncTargetJudgment,
  hasExternalPostReference: boolean
): string[] {
  const warnings: string[] = [];
  const status = normalizeText(session.status, 40);

  if (action === "create" && hasExternalPostReference) {
    warnings.push("既存投稿の参照情報があるため、新規投稿ではなく更新扱いを検討してください。");
  }

  if (action === "resync" && !hasExternalPostReference) {
    warnings.push("既存投稿の参照情報がないため、再同期時は新規投稿相当の扱いを検討します。");
  }

  if (action === "close" && !CLOSED_STATUSES.has(status)) {
    warnings.push("終了表示へ更新する前に、募集状態が終了系になっているか確認してください。");
  }

  if (action === "delete") {
    warnings.push("DB完全削除前に外部投稿側の削除または削除相当表示を先に行う必要があります。");
  }

  if (!syncTarget.isTarget && action === "delete") {
    warnings.push("依頼書本体は通常の同期対象外ですが、既存投稿がある場合だけ削除相当処理を検討できます。");
  }

  return warnings;
}

function buildMessagePreview(session: SessionRow, action: SyncAction): string {
  const title = normalizeText(session.title, 120) || "タイトル未設定";
  const status = normalizeText(session.status, 40);
  const closePrefix = action === "close" || CLOSED_STATUSES.has(status) ? "【募集終了】" : "";
  const deletePrefix = action === "delete" ? "【削除予定】" : "";
  const summary = normalizeMultiline(session.summary, 1400) || "概要未設定";
  const titlePrefix = deletePrefix || closePrefix || "";

  return [
    "＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝",
    "",
    `■依頼書【${titlePrefix}${title}】`,
    `GM【${normalizeText(session.gm_name, 80) || "未定"}】`,
    `開催場所【${formatSessionToolForDiscord(session.session_tool)}】`,
    `日時【${formatSchedule(session)}】`,
    `参加人数【${formatPlayerRange(session.player_min, session.player_max)}】`,
    `参加締切【${formatDateTimeForDiscord(session.application_deadline)}】`,
    "",
    summary,
    action === "delete" ? "\n※この依頼書は削除相当処理の確認用previewです。" : "",
    action === "close" ? "\n※募集または開催終了として更新するpreviewです。" : ""
  ].filter(Boolean).join("\n");
}

function buildPlannedDbUpdate(action: SyncAction, hasExternalPostReference: boolean) {
  const resolvedAction = action === "resync"
    ? hasExternalPostReference ? "update" : "create"
    : action;

  return {
    will_update: false,
    reason: "dry_run_preview_only",
    resolved_action: resolvedAction,
    columns: {
      discord_sync_status: action === "delete" ? "posted_or_skipped_after_review" : "posted_on_success",
      discord_last_action: action,
      discord_sync_requested_at: "would_set_to_current_time",
      discord_synced_at: "would_set_on_success",
      discord_sync_error: "would_clear_on_success",
      discord_message_id: resolvedAction === "create"
        ? "would_store_external_reference_on_success"
        : "would_keep_existing_reference"
    }
  };
}

function formatSchedule(session: SessionRow): string {
  const start = formatPlainDateTimeForDiscord(session.date, session.start_time);
  const end = formatDateTimeForDiscord(session.end_at, "")
    || formatPlainDateTimeForDiscord(session.date, session.end_time);

  if (start && end) return `${start}　～　${end}`;
  return start || end || "未定";
}

function formatSessionToolForDiscord(value: unknown): string {
  return normalizeText(value, 80) || "未定";
}

function formatPlayerRange(min: number | null, max: number | null): string {
  if (typeof min === "number" && typeof max === "number") {
    return `${min}～${max}人`;
  }

  if (typeof min === "number") {
    return `最低${min}人`;
  }

  if (typeof max === "number") {
    return `最大${max}人`;
  }

  return "未定";
}

function formatPlainDateTimeForDiscord(dateValue: unknown, timeValue: unknown): string {
  const dateParts = parsePlainDateParts(dateValue);
  if (!dateParts) return "";
  const time = normalizeClock(timeValue);
  const dateLabel = formatPlainDateParts(dateParts);
  return time ? `${dateLabel} ${time}` : dateLabel;
}

function formatDateTimeForDiscord(value: unknown, fallback = "未定"): string {
  const text = normalizeText(value, 80);
  if (!text) return fallback;

  const plain = text.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
  if (plain && !/[zZ]|[+-]\d{2}:?\d{2}$/.test(text)) {
    return formatPlainDateTimeForDiscord(plain[1], plain[2]) || fallback;
  }

  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return fallback;

  const parts = new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).formatToParts(date).reduce<Record<string, string>>((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});

  if (!parts.month || !parts.day || !parts.weekday || !parts.hour || !parts.minute) {
    return fallback;
  }

  return `${parts.month}/${parts.day}(${parts.weekday}) ${parts.hour}:${parts.minute}`;
}

function parsePlainDateParts(value: unknown): { year: number; month: number; day: number; weekday: string } | null {
  const text = normalizeText(value, 20);
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year
    || date.getUTCMonth() !== month - 1
    || date.getUTCDate() !== day
  ) {
    return null;
  }

  const weekdays = ["日", "月", "火", "水", "木", "金", "土"];
  return { year, month, day, weekday: weekdays[date.getUTCDay()] };
}

function formatPlainDateParts(parts: { month: number; day: number; weekday: string }): string {
  return `${String(parts.month).padStart(2, "0")}/${String(parts.day).padStart(2, "0")}(${parts.weekday})`;
}

function normalizeClock(value: unknown): string {
  const match = normalizeText(value, 20).match(/^(\d{2}):(\d{2})/);
  return match ? `${match[1]}:${match[2]}` : "";
}

function labelFor(labels: Record<string, string>, value: unknown): string {
  const key = normalizeText(value, 40);
  return labels[key] ?? "未設定";
}

function hasPostReference(session: SessionRow): boolean {
  return normalizeText(session.discord_message_id, 180).length > 0;
}

function firstRow<T>(data: T[] | null): T | null {
  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

function mergeWarnings(warnings: string[], extra: string | null): string[] {
  return extra ? [...warnings, extra] : warnings;
}

function extractErrorMessage(error: unknown): string {
  if (isRecord(error) && typeof error.message === "string") {
    return error.message;
  }

  return String(error ?? "");
}

function normalizeErrorCode(value: unknown): string {
  return normalizeText(value, 120).replace(/[^a-z0-9_:-]/gi, "_") || "discord_sync_error";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
  extra: Record<string, unknown> = {}
): Response {
  return new Response(JSON.stringify({
    ok: false,
    error_code: errorCode,
    message,
    dry_run: dryRun,
    ...extra
  }), {
    status,
    headers: CORS_HEADERS
  });
}
