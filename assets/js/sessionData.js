import { loadJson } from "./dataLoader.js";
import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js?v=20260601-session-post";

const PUBLIC_SESSION_EXCLUDED_STATUSES = new Set(["draft", "canceled", "cancelled"]);
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function normalizeText(value) {
  return String(value ?? "").trim();
}

function normalizeTime(value) {
  const text = normalizeText(value);
  const match = text.match(/^(\d{2}):(\d{2})/);
  return match ? `${match[1]}:${match[2]}` : "";
}

function formatJapanDateTime(value) {
  const text = normalizeText(value);
  if (!text) return "";

  const alreadyFormatted = text.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}):(\d{2})/);
  if (alreadyFormatted && !/[zZ]|[+-]\d{2}:?\d{2}$/.test(text)) {
    return `${alreadyFormatted[1]} ${alreadyFormatted[2]}:${alreadyFormatted[3]}`;
  }

  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return "";

  const parts = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).formatToParts(date).reduce((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});

  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}`;
}

function isPublicDisplaySession(session) {
  const status = normalizeText(session?.status);
  return Boolean(
    session
      && session.visibility === "public"
      && !PUBLIC_SESSION_EXCLUDED_STATUSES.has(status)
      && ISO_DATE_PATTERN.test(normalizeText(session.date))
      && normalizeText(session.id)
  );
}

function normalizeSupabaseSession(row) {
  return {
    id: normalizeText(row?.id),
    title: normalizeText(row?.title) || "無題のセッション",
    date: normalizeText(row?.date),
    startTime: normalizeTime(row?.start_time),
    endTime: normalizeTime(row?.end_time),
    endAt: formatJapanDateTime(row?.end_at),
    gmName: normalizeText(row?.gm_name) || "GM未設定",
    status: normalizeText(row?.status),
    sessionType: normalizeText(row?.session_type) || "other",
    applicationDeadline: formatJapanDateTime(row?.application_deadline),
    levelRange: normalizeText(row?.level_range),
    playerMin: row?.player_min,
    playerMax: row?.player_max,
    summary: normalizeText(row?.summary),
    detail: normalizeText(row?.detail),
    requirements: normalizeText(row?.requirements),
    visibility: normalizeText(row?.visibility),
    updatedAt: normalizeText(row?.updated_at)
  };
}

async function loadSupabasePublicSessions() {
  const client = await createSupabaseBrowserClient();
  if (!client) {
    return { sessions: [], loadError: false };
  }

  const { data, error } = await client
    .from("sessions")
    .select("id,title,date,start_time,end_time,end_at,gm_name,status,session_type,application_deadline,level_range,player_min,player_max,summary,detail,requirements,visibility,updated_at")
    .eq("visibility", "public");

  if (error) {
    return { sessions: [], loadError: true };
  }

  const sessions = Array.isArray(data)
    ? data.map(normalizeSupabaseSession).filter(isPublicDisplaySession)
    : [];
  return { sessions, loadError: false };
}

function mergeSessions(staticSessions, supabaseSessions) {
  const merged = [];
  const staticIds = new Set();

  for (const session of staticSessions) {
    const id = normalizeText(session?.id);
    if (id) staticIds.add(id);
    merged.push(session);
  }

  for (const session of supabaseSessions) {
    if (!staticIds.has(normalizeText(session.id))) {
      merged.push(session);
    }
  }

  return merged;
}

export async function loadMergedSessions(staticSessionsUrl) {
  const staticData = await loadJson(staticSessionsUrl);
  const staticSessions = Array.isArray(staticData.sessions) ? staticData.sessions : [];
  const supabaseResult = await loadSupabasePublicSessions().catch(() => ({
    sessions: [],
    loadError: true
  }));

  return {
    sessions: mergeSessions(staticSessions, supabaseResult.sessions),
    supabaseLoadError: Boolean(supabaseResult.loadError)
  };
}
