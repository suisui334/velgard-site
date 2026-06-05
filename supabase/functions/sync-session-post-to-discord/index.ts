import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SyncAction = "create" | "update" | "close" | "delete" | "resync";

type ErrorCode =
  | "config_missing"
  | "invalid_action"
  | "invalid_payload"
  | "login_required"
  | "method_not_allowed"
  | "missing_post_reference"
  | "not_allowed"
  | "not_sync_target"
  | "real_send_not_enabled"
  | "session_not_found";

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

interface SyncTargetJudgment {
  isTarget: boolean;
  reason: string;
}

const ALLOWED_ACTIONS = new Set<SyncAction>(["create", "update", "close", "delete", "resync"]);
const SYNC_TARGET_STATUSES = new Set(["tentative", "recruiting", "full", "closed", "finished"]);
const CLOSED_STATUSES = new Set(["closed", "finished"]);
const SESSION_SELECT_COLUMNS = [
  "id",
  "title",
  "summary",
  "status",
  "visibility",
  "session_type",
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

  if (!payload.value.dryRun) {
    return jsonError(
      501,
      "real_send_not_enabled",
      "実送信はこのdraftでは有効化していません。dry_run=trueで確認してください。",
      false
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

  return jsonOk({
    ok: true,
    dry_run: true,
    action: payload.value.action,
    sync_target: {
      eligible: syncTarget.isTarget,
      reason: syncTarget.reason
    },
    message_preview: buildMessagePreview(session, payload.value.action),
    planned_db_update: buildPlannedDbUpdate(payload.value.action, hasExternalPostReference),
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
  const prefix = deletePrefix || closePrefix || "【依頼書】";
  const summary = normalizeMultiline(session.summary, 1400) || "概要未設定";
  const detailUrl = buildDetailUrl(session.id);

  return [
    `${prefix}${title}`,
    "",
    `種別: ${labelFor(SESSION_TYPE_LABELS, session.session_type)}`,
    `開催: ${formatSchedule(session)}`,
    `募集状態: ${labelFor(STATUS_LABELS, session.status)}`,
    `公開状態: ${labelFor(VISIBILITY_LABELS, session.visibility)}`,
    `申請締切: ${formatOptionalValue(session.application_deadline)}`,
    `募集人数: ${formatPlayerRange(session.player_min, session.player_max)}`,
    `GM: ${normalizeText(session.gm_name, 80) || "未設定"}`,
    "",
    "概要:",
    summary,
    "",
    "詳細:",
    detailUrl,
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

function buildDetailUrl(sessionId: string): string {
  const baseUrl = normalizeText(Deno.env.get("PUBLIC_SITE_BASE_URL"), 240).replace(/\/+$/, "");
  const path = `session-detail.html?id=${encodeURIComponent(sessionId)}`;

  return baseUrl ? `${baseUrl}/${path}` : `/${path}`;
}

function formatSchedule(session: SessionRow): string {
  const date = normalizeText(session.date, 20);
  const start = normalizeText(session.start_time, 20);
  const end = normalizeText(session.end_time, 20);
  const endAt = normalizeText(session.end_at, 40);

  if (date && start && endAt) {
    return `${date} ${start} - ${endAt}`;
  }

  if (date && start && end) {
    return `${date} ${start} - ${end}`;
  }

  if (date) {
    return date;
  }

  return "未設定";
}

function formatOptionalValue(value: unknown): string {
  return normalizeText(value, 80) || "未設定";
}

function formatPlayerRange(min: number | null, max: number | null): string {
  if (typeof min === "number" && typeof max === "number") {
    return `${min} - ${max}名`;
  }

  if (typeof min === "number") {
    return `${min}名以上`;
  }

  if (typeof max === "number") {
    return `${max}名まで`;
  }

  return "未設定";
}

function labelFor(labels: Record<string, string>, value: unknown): string {
  const key = normalizeText(value, 40);
  return labels[key] ?? "未設定";
}

function hasPostReference(session: SessionRow): boolean {
  return normalizeText(session.discord_message_id, 180).length > 0;
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
