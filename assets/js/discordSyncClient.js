const DISCORD_SYNC_ACTIONS = new Set(["create", "update", "delete"]);
const DISCORD_MENTION_MODES = new Set(["everyone", "none"]);
const PUBLIC_VISIBILITY = "public";
const DRAFT_STATUS = "draft";

function normalizeText(value) {
  return String(value ?? "").trim();
}

function normalizeAction(action) {
  const normalized = normalizeText(action);
  return DISCORD_SYNC_ACTIONS.has(normalized) ? normalized : "";
}

function normalizeDiscordMentionMode(value) {
  const normalized = normalizeText(value);
  return DISCORD_MENTION_MODES.has(normalized) ? normalized : "";
}

function hasSessionId(value) {
  return normalizeText(value).length > 0;
}

function isPublicVisibility(value) {
  return normalizeText(value) === PUBLIC_VISIBILITY;
}

function isNonDraftStatus(value) {
  return normalizeText(value) !== DRAFT_STATUS;
}

function getSessionId(session) {
  return normalizeText(session?.id ?? session?.session_id);
}

function getPayloadSessionId(payload) {
  return normalizeText(payload?.p_session_id ?? payload?.session_id);
}

function getPublicSiteBaseUrl() {
  if (typeof window === "undefined" || !window.location?.href) return "";
  try {
    return new URL("./", window.location.href).toString();
  } catch {
    return "";
  }
}

export function isPublicNonDraftPayload(payload) {
  return isPublicVisibility(payload?.p_visibility) && isNonDraftStatus(payload?.p_status);
}

export function isPublicNonDraftSession(session) {
  return isPublicVisibility(session?.visibility) && isNonDraftStatus(session?.status);
}

export function hasDiscordPostReference(session) {
  return normalizeText(session?.discordMessageId ?? session?.discord_message_id).length > 0;
}

function makeSkippedResult(reason) {
  return {
    ok: true,
    attempted: false,
    status: "skipped",
    reason
  };
}

function makeFailureResult(action, reason) {
  return {
    ok: false,
    attempted: true,
    action,
    status: "failed",
    reason
  };
}

export function getDiscordSyncUiMessage(result, options = {}) {
  if (!result || result.attempted === false) {
    return "";
  }
  if (result.ok) {
    return options.successMessage || "Discord同期を実行しました。詳細は管理パネルで確認してください。";
  }
  if (options.deleteMode) {
    return "Discord同期削除に失敗しました。依頼書は削除していません。管理パネルで確認してください。";
  }
  return "依頼書の保存は完了しましたが、Discord同期は失敗しました。管理パネルで確認してください。";
}

export function getDiscordSyncStateModifier(result, fallback = "is-ok") {
  if (result?.attempted && !result.ok) {
    return "is-warn";
  }
  return fallback;
}

export async function runDiscordSessionSync(client, options) {
  const action = normalizeAction(options?.action);
  const sessionId = normalizeText(options?.sessionId);
  if (!client?.functions?.invoke || !action || !hasSessionId(sessionId)) {
    return makeFailureResult(action || "unknown", "invalid_request");
  }

  const body = {
    session_id: sessionId,
    action,
    dry_run: false,
    request_source: normalizeText(options?.requestSource) || "frontend_auto_sync",
    public_site_base_url: getPublicSiteBaseUrl()
  };
  const discordMentionMode = action === "create" ? normalizeDiscordMentionMode(options?.discordMentionMode) : "";
  if (discordMentionMode) {
    body.discord_mention_mode = discordMentionMode;
  }

  const { data, error } = await client.functions.invoke("sync-session-post-to-discord", {
    body
  });

  if (error) {
    return makeFailureResult(action, "function_error");
  }

  const responseAction = normalizeAction(data?.action);
  const responseOk = data?.ok === true && data?.dry_run === false && responseAction === action;
  if (!responseOk) {
    return makeFailureResult(action, "function_rejected");
  }

  const dbUpdateSuccess = data?.db_update?.success !== false;
  if (!dbUpdateSuccess) {
    return makeFailureResult(action, "db_update_failed");
  }

  return {
    ok: true,
    attempted: true,
    action,
    status: "success"
  };
}

export async function syncCreatedSession(client, options) {
  const payload = options?.payload;
  const sessionId = normalizeText(options?.sessionId ?? getPayloadSessionId(payload));
  if (!isPublicNonDraftPayload(payload)) {
    return makeSkippedResult("not_public_post");
  }
  if (!hasSessionId(sessionId)) {
    return makeFailureResult("create", "missing_session_id");
  }
  return runDiscordSessionSync(client, {
    sessionId,
    action: "create",
    discordMentionMode: options?.discordMentionMode,
    requestSource: "frontend_auto_create"
  });
}

export async function syncUpdatedSession(client, options) {
  const payload = options?.payload;
  const session = options?.session;
  const sessionId = normalizeText(options?.sessionId ?? getPayloadSessionId(payload) ?? getSessionId(session));
  if (!isPublicNonDraftPayload(payload)) {
    return makeSkippedResult("not_public_post");
  }
  if (!hasDiscordPostReference(session)) {
    return makeSkippedResult("no_existing_discord_post");
  }
  if (!hasSessionId(sessionId)) {
    return makeFailureResult("update", "missing_session_id");
  }
  return runDiscordSessionSync(client, {
    sessionId,
    action: "update",
    requestSource: "frontend_auto_update"
  });
}

export async function deleteSyncedSession(client, options) {
  const session = options?.session;
  const sessionId = normalizeText(options?.sessionId ?? getSessionId(session));
  if (!hasDiscordPostReference(session)) {
    return makeSkippedResult("no_existing_discord_post");
  }
  if (!hasSessionId(sessionId)) {
    return makeFailureResult("delete", "missing_session_id");
  }
  return runDiscordSessionSync(client, {
    sessionId,
    action: "delete",
    requestSource: "frontend_auto_delete"
  });
}
