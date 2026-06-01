import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: ".env.local" });

const RUN_FLAG = "RUN_CREATE_SESSION_POST_TEST";
const CONFIRM_FLAG = "CREATE_SESSION_POST_CONFIRM";
const CONFIRM_VALUE = "hidden-draft";
const ACTOR_ENV = "CREATE_SESSION_POST_ACTOR";
const REQUIRED_BASE_ENV = ["SUPABASE_URL", "SUPABASE_ANON_KEY"];
const ACTOR_ENV_MAP = {
  gm: ["TEST_GM_A_EMAIL", "TEST_GM_A_PASSWORD"],
  admin: ["TEST_ADMIN_EMAIL", "TEST_ADMIN_PASSWORD"]
};

const PAYLOAD = Object.freeze({
  p_title: "M-14D end_at hidden draft test",
  p_session_date: "2026-06-30",
  p_start_time: "23:00",
  p_end_time: "01:00",
  p_end_at: "2026-07-01 01:00",
  p_application_deadline: "2026-06-29 23:59",
  p_session_type: "one-shot",
  p_level_range: null,
  p_player_min: 2,
  p_player_max: 5,
  p_summary: "M-14D end_at hidden draft test.",
  p_request_body: null,
  p_requirements: null,
  p_visibility: "hidden",
  p_status: "draft"
});

const EXPECTED_RETURN_KEYS = ["created_at", "discord_sync_status", "session_id"];
const EXPECTED_ROW_KEYS = [
  "application_deadline",
  "discord_sync_status",
  "end_at",
  "id",
  "session_type",
  "status",
  "title",
  "visibility"
];

function actorName() {
  const raw = String(process.env[ACTOR_ENV] || "gm").trim().toLowerCase();
  if (raw === "gm" || raw === "admin") return raw;
  throw new Error(`${ACTOR_ENV} must be gm or admin`);
}

function sensitiveValues() {
  const names = [
    ...REQUIRED_BASE_ENV,
    ...Object.values(ACTOR_ENV_MAP).flat()
  ];
  return names
    .map((name) => process.env[name])
    .filter((value) => typeof value === "string" && value.length >= 8);
}

function sanitizeText(value) {
  let text = String(value ?? "");
  for (const sensitiveValue of sensitiveValues()) {
    text = text.split(sensitiveValue).join("[redacted]");
  }
  return text
    .replace(/https:\/\/[^\s)]+/g, "[redacted-url]")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted-email]")
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[redacted-auth-value]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[redacted-long-value]");
}

function formatError(error) {
  if (!error) return "unknown error";
  if (typeof error === "string") return sanitizeText(error);

  const parts = [];
  for (const key of ["message", "code", "details", "hint", "status", "name"]) {
    if (error[key]) parts.push(`${key}=${sanitizeText(error[key])}`);
  }
  return parts.length > 0 ? parts.join(" | ") : "unrecognized error object";
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertExactKeys(row, expectedKeys, label) {
  const keys = Object.keys(row || {}).sort();
  assert(
    JSON.stringify(keys) === JSON.stringify(expectedKeys),
    `${label} keys differed: ${keys.join(", ")}`
  );
}

function createSupabaseClient() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    }
  });
}

async function signIn(label, emailEnv, passwordEnv) {
  const client = createSupabaseClient();
  const { error } = await client.auth.signInWithPassword({
    email: process.env[emailEnv],
    password: process.env[passwordEnv]
  });
  assert(!error, `${label} sign-in failed: ${formatError(error)}`);
  return client;
}

function ensureRunnable() {
  if (process.env[RUN_FLAG] !== "true" || process.env[CONFIRM_FLAG] !== CONFIRM_VALUE) {
    console.log(
      `SKIP create_session_post hidden draft test. Set ${RUN_FLAG}=true and ${CONFIRM_FLAG}=${CONFIRM_VALUE} to create one hidden draft session.`
    );
    process.exit(0);
  }

  const actor = actorName();
  const required = [...REQUIRED_BASE_ENV, ...ACTOR_ENV_MAP[actor]];
  const missing = required.filter((name) => !process.env[name]);
  assert(missing.length === 0, `Required environment is missing (${missing.length} item(s)).`);
  return actor;
}

async function run() {
  const actor = ensureRunnable();
  const [emailEnv, passwordEnv] = ACTOR_ENV_MAP[actor];
  const client = await signIn(actor, emailEnv, passwordEnv);

  const { data, error } = await client.rpc("create_session_post", PAYLOAD);
  assert(!error, `create_session_post failed: ${formatError(error)}`);

  const result = Array.isArray(data) ? data[0] : data;
  assert(result && typeof result === "object", "create_session_post did not return a row");
  assertExactKeys(result, EXPECTED_RETURN_KEYS, "create_session_post result");
  assert(result.discord_sync_status === "skipped", "discord_sync_status was not skipped");
  assert(typeof result.session_id === "string" && result.session_id.length > 0, "session_id was empty");

  const { data: row, error: rowError } = await client
    .from("sessions")
    .select("id,title,status,visibility,session_type,application_deadline,end_at,discord_sync_status")
    .eq("id", result.session_id)
    .single();
  assert(!rowError, `created row check failed: ${formatError(rowError)}`);
  assertExactKeys(row, EXPECTED_ROW_KEYS, "created row");
  assert(row.title === PAYLOAD.p_title, "created row title differed");
  assert(row.status === "draft", "created row status was not draft");
  assert(row.visibility === "hidden", "created row visibility was not hidden");
  assert(row.session_type === "one-shot", "created row session_type was not one-shot");
  assert(row.discord_sync_status === "skipped", "created row discord_sync_status was not skipped");
  assert(row.application_deadline, "created row application_deadline was empty");
  assert(row.end_at, "created row end_at was empty");

  const anon = createSupabaseClient();
  const { data: publicRow, error: publicError } = await anon
    .from("sessions")
    .select("id")
    .eq("id", result.session_id)
    .maybeSingle();
  assert(!publicError, `public visibility check failed: ${formatError(publicError)}`);
  assert(publicRow === null, "hidden draft session was visible to anon select");

  console.log(JSON.stringify({
    ok: true,
    actor,
    session_id: result.session_id,
    discord_sync_status: result.discord_sync_status,
    created_at: result.created_at,
    created_row: {
      status: row.status,
      visibility: row.visibility,
      session_type: row.session_type,
      application_deadline_present: Boolean(row.application_deadline),
      end_at_present: Boolean(row.end_at),
      discord_sync_status: row.discord_sync_status
    },
    public_visible_to_anon: false,
    note: "Hidden draft test row was created and was not deleted."
  }, null, 2));
}

run().catch((error) => {
  console.error(`FAIL create_session_post hidden draft test: ${formatError(error)}`);
  process.exitCode = 1;
});
