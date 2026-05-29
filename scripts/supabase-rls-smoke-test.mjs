import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: ".env.local" });

const REQUIRED_ENV = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "TEST_PLAYER_A_EMAIL",
  "TEST_PLAYER_A_PASSWORD",
  "TEST_PLAYER_B_EMAIL",
  "TEST_PLAYER_B_PASSWORD",
  "TEST_GM_A_EMAIL",
  "TEST_GM_A_PASSWORD",
  "TEST_GM_B_EMAIL",
  "TEST_GM_B_PASSWORD",
  "TEST_ADMIN_EMAIL",
  "TEST_ADMIN_PASSWORD"
];

const FORBIDDEN_ENV = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "SERVICE_ROLE_KEY",
  "SUPABASE_SECRET_KEY",
  "DB_PASSWORD",
  "JWT_SECRET",
  "DISCORD_BOT_TOKEN",
  "WEBHOOK_URL"
];

const SESSION = {
  recruiting: "rls-test-public-recruiting",
  tentative: "rls-test-public-tentative",
  full: "rls-test-public-full",
  closed: "rls-test-public-closed",
  finished: "rls-test-public-finished",
  canceled: "rls-test-public-canceled",
  private: "rls-test-private-recruiting",
  hidden: "rls-test-hidden-recruiting",
  otherGm: "rls-test-other-gm-recruiting"
};

const RUN_DESTRUCTIVE_TESTS = process.env.RUN_DESTRUCTIVE_TESTS === "true";
const SENSITIVE_ENV = [...REQUIRED_ENV, ...FORBIDDEN_ENV];
const sensitiveValues = SENSITIVE_ENV.map((name) => process.env[name]).filter(
  (value) => typeof value === "string" && value.length >= 8
);

const results = [];

function sanitizeText(value) {
  let text = String(value ?? "");
  for (const secret of sensitiveValues) {
    if (secret && text.includes(secret)) {
      text = text.split(secret).join("[redacted]");
    }
  }
  return text
    .replace(/https:\/\/[^\s)]+/g, "[redacted-url]")
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[redacted-token]");
}

function formatSupabaseError(error) {
  if (!error) {
    return "unknown error";
  }

  if (typeof error === "string") {
    return sanitizeText(error);
  }

  const parts = [];
  for (const key of ["message", "code", "details", "hint", "status", "name"]) {
    if (error[key]) {
      parts.push(`${key}=${sanitizeText(error[key])}`);
    }
  }

  return parts.length > 0 ? parts.join(" | ") : "unrecognized error object";
}

function sanitize(value) {
  if (value instanceof Error) {
    return formatSupabaseError(value);
  }
  return sanitizeText(value);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function requireId(value, label) {
  assert(
    typeof value === "string" && value.length > 0,
    `${label} was not available; check the earlier application/comment creation or SELECT test.`
  );
  return value;
}

function assertNoSensitiveColumns(rowOrRows, context) {
  const rows = Array.isArray(rowOrRows) ? rowOrRows : [rowOrRows];
  for (const row of rows.filter(Boolean)) {
    for (const forbiddenKey of ["user_id", "discord_user_id", "discord_name", "role"]) {
      assert(
        !Object.prototype.hasOwnProperty.call(row, forbiddenKey),
        `${context} exposed ${forbiddenKey}`
      );
    }
  }
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
  assert(!error, `${label} sign-in failed: ${formatSupabaseError(error)}`);
  return client;
}

async function expectOk(operation, label) {
  const { data, error } = await operation;
  assert(!error, `${label} failed: ${formatSupabaseError(error)}`);
  return data;
}

async function expectError(operation, label) {
  const { error } = await operation;
  assert(error, `${label} unexpectedly succeeded`);
  return error;
}

async function runTest(id, label, fn) {
  try {
    await fn();
    results.push({ id, label, status: "PASS" });
    console.log(`PASS ${id} ${label}`);
  } catch (error) {
    results.push({ id, label, status: "FAIL", error: sanitize(error) });
    console.log(`FAIL ${id} ${label}: ${sanitize(error)}`);
  }
}

async function skipTest(id, label, reason) {
  results.push({ id, label, status: "SKIP", reason });
  console.log(`SKIP ${id} ${label}: ${reason}`);
}

async function createApplicationComment(client, sessionId, body) {
  return expectOk(
    client.rpc("create_application_comment", {
      target_session_id: sessionId,
      comment_body: body
    }),
    `create application comment for ${sessionId}`
  );
}

async function getOwnApplication(client, sessionId) {
  const data = await expectOk(
    client
      .from("session_applications")
      .select("id, session_id, status")
      .eq("session_id", sessionId),
    `select own application for ${sessionId}`
  );
  assert(data.length === 1, `expected exactly one visible own application for ${sessionId}`);
  assert(data[0].id, `visible own application for ${sessionId} did not include id`);
  return data[0];
}

async function getPublicCountTotal(client, sessionId) {
  const data = await expectOk(
    client.rpc("get_public_session_application_counts", {
      target_session_id: sessionId
    }),
    `get public application counts for ${sessionId}`
  );
  assert(data.length === 1, `expected one count row for ${sessionId}`);
  const row = data[0];
  return Number(row.accepted_count ?? 0) + Number(row.pending_count ?? 0) + Number(row.waitlisted_count ?? 0);
}

function assertEnvironment() {
  const missing = REQUIRED_ENV.filter((name) => !process.env[name]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
  }

  const presentForbidden = FORBIDDEN_ENV.filter((name) => process.env[name]);
  if (presentForbidden.length > 0) {
    throw new Error(
      `Forbidden high-risk environment variables are present: ${presentForbidden.join(", ")}`
    );
  }
}

async function main() {
  assertEnvironment();

  const anon = createSupabaseClient();
  let playerA;
  let playerB;
  let gmA;
  let gmB;
  let admin;
  let playerARecruitingApplicationId;
  let otherGmApplicationId;
  let playerBCommentId;

  await runTest("AUTH-001", "anon can read public sessions only", async () => {
    const data = await expectOk(
      anon
        .from("sessions")
        .select("id, visibility, status")
        .in("id", [SESSION.recruiting, SESSION.private, SESSION.hidden]),
      "anon session select"
    );
    const ids = data.map((row) => row.id);
    assert(ids.includes(SESSION.recruiting), "public recruiting session was not visible");
    assert(!ids.includes(SESSION.private), "private session leaked to anon");
    assert(!ids.includes(SESSION.hidden), "hidden session leaked to anon");
  });

  await runTest("AUTH-002", "anon can read public_profiles without discord fields", async () => {
    const data = await expectOk(
      anon.from("public_profiles").select("*").limit(5),
      "anon public_profiles select"
    );
    assertNoSensitiveColumns(data, "public_profiles");
  });

  await runTest("AUTH-003", "anon can call public comments RPC without internal fields", async () => {
    const data = await expectOk(
      anon.rpc("get_public_session_comments", {
        target_session_id: SESSION.recruiting
      }),
      "anon public comments rpc"
    );
    assertNoSensitiveColumns(data, "public comments rpc");
  });

  await runTest("AUTH-004", "anon cannot create application comment", async () => {
    await expectError(
      anon.rpc("create_application_comment", {
        target_session_id: SESSION.recruiting,
        comment_body: "Anon should not be able to apply."
      }),
      "anon create_application_comment"
    );
  });

  await runTest("AUTH-005", "player A can sign in", async () => {
    playerA = await signIn("player A", "TEST_PLAYER_A_EMAIL", "TEST_PLAYER_A_PASSWORD");
  });

  await runTest("AUTH-006", "player A can apply to recruiting and add a second comment without duplicate application", async () => {
    await createApplicationComment(playerA, SESSION.recruiting, "Player A application comment from smoke test.");
    await createApplicationComment(playerA, SESSION.recruiting, "Player A follow-up comment from smoke test.");
    const application = await getOwnApplication(playerA, SESSION.recruiting);
    playerARecruitingApplicationId = application.id;
    const total = await getPublicCountTotal(playerA, SESSION.recruiting);
    assert(total >= 1, "public count total did not include player A");
  });

  await runTest("AUTH-007", "player A can apply to tentative", async () => {
    await createApplicationComment(playerA, SESSION.tentative, "Player A tentative application from smoke test.");
  });

  await runTest("AUTH-008", "player A cannot apply to full / closed / finished / canceled", async () => {
    for (const sessionId of [SESSION.full, SESSION.closed, SESSION.finished, SESSION.canceled]) {
      await expectError(
        playerA.rpc("create_application_comment", {
          target_session_id: sessionId,
          comment_body: `This should fail for ${sessionId}.`
        }),
        `player A create_application_comment for ${sessionId}`
      );
    }
  });

  await runTest("AUTH-009", "player A cannot apply to private / hidden", async () => {
    for (const sessionId of [SESSION.private, SESSION.hidden]) {
      await expectError(
        playerA.rpc("create_application_comment", {
          target_session_id: sessionId,
          comment_body: `This should fail for ${sessionId}.`
        }),
        `player A create_application_comment for ${sessionId}`
      );
    }
  });

  await runTest("AUTH-010", "player A cannot set application status or close sessions", async () => {
    await expectError(
      playerA.rpc("set_application_status", {
        target_application_id: requireId(playerARecruitingApplicationId, "player A recruiting application id"),
        new_status: "accepted"
      }),
      "player A set_application_status"
    );
    await expectError(
      playerA.rpc("close_session", {
        target_session_id: SESSION.recruiting
      }),
      "player A close_session"
    );
  });

  await runTest("AUTH-011", "player A can create an application on another GM public session", async () => {
    await createApplicationComment(playerA, SESSION.otherGm, "Player A other-GM application from smoke test.");
    const application = await getOwnApplication(playerA, SESSION.otherGm);
    otherGmApplicationId = application.id;
  });

  await runTest("AUTH-012", "player B can sign in and apply to recruiting", async () => {
    playerB = await signIn("player B", "TEST_PLAYER_B_EMAIL", "TEST_PLAYER_B_PASSWORD");
    playerBCommentId = await createApplicationComment(
      playerB,
      SESSION.recruiting,
      "Player B application comment from smoke test."
    );
  });

  await runTest("AUTH-013", "player A cannot edit player B comment, but can edit own comment", async () => {
    await expectError(
      playerA.rpc("edit_comment", {
        target_comment_id: requireId(playerBCommentId, "player B comment id"),
        comment_body: "Player A should not be able to edit Player B comment."
      }),
      "player A edit player B comment"
    );
    const ownCommentId = await createApplicationComment(
      playerA,
      SESSION.recruiting,
      "Player A editable comment from smoke test."
    );
    await expectOk(
      playerA.rpc("edit_comment", {
        target_comment_id: requireId(ownCommentId, "player A own comment id"),
        comment_body: "Player A edited own comment from smoke test."
      }),
      "player A edit own comment"
    );
  });

  await runTest("AUTH-014", "gm A can sign in and manage own session application", async () => {
    gmA = await signIn("gm A", "TEST_GM_A_EMAIL", "TEST_GM_A_PASSWORD");
    await expectOk(
      gmA.rpc("set_application_status", {
        target_application_id: requireId(playerARecruitingApplicationId, "player A recruiting application id"),
        new_status: "accepted"
      }),
      "gm A accept own session application"
    );
  });

  await runTest("AUTH-015", "gm A cannot manage gm B session application or close gm B session", async () => {
    await expectError(
      gmA.rpc("set_application_status", {
        target_application_id: requireId(otherGmApplicationId, "other GM session application id"),
        new_status: "accepted"
      }),
      "gm A set status for gm B session application"
    );
    await expectError(
      gmA.rpc("close_session", {
        target_session_id: SESSION.otherGm
      }),
      "gm A close gm B session"
    );
  });

  await runTest("AUTH-016", "gm A cannot close finished / canceled sessions", async () => {
    for (const sessionId of [SESSION.finished, SESSION.canceled]) {
      await expectError(
        gmA.rpc("close_session", {
          target_session_id: sessionId
        }),
        `gm A close ${sessionId}`
      );
    }
  });

  await runTest("AUTH-017", "gm B can sign in and cannot close gm A session", async () => {
    gmB = await signIn("gm B", "TEST_GM_B_EMAIL", "TEST_GM_B_PASSWORD");
    await expectError(
      gmB.rpc("close_session", {
        target_session_id: SESSION.recruiting
      }),
      "gm B close gm A session"
    );
  });

  if (RUN_DESTRUCTIVE_TESTS) {
    await runTest("AUTH-018", "gm A can close own session when destructive tests are enabled", async () => {
      await expectOk(
        gmA.rpc("close_session", {
          target_session_id: SESSION.recruiting
        }),
        "gm A close own session"
      );
    });
  } else {
    await skipTest(
      "AUTH-018",
      "gm A close own session success",
      "RUN_DESTRUCTIVE_TESTS is not true; close_session success test is intentionally skipped."
    );
  }

  await runTest("AUTH-019", "admin can sign in and inspect all prototype rows", async () => {
    admin = await signIn("admin", "TEST_ADMIN_EMAIL", "TEST_ADMIN_PASSWORD");
    const sessions = await expectOk(
      admin
        .from("sessions")
        .select("id, visibility, status")
        .like("id", "rls-test-%"),
      "admin sessions select"
    );
    assert(sessions.length >= 9, "admin did not see all seeded sessions");

    await expectOk(
      admin
        .from("session_applications")
        .select("id, session_id, status")
        .in("session_id", [SESSION.recruiting, SESSION.otherGm]),
      "admin applications select"
    );
  });

  await runTest("AUTH-020", "public RPCs do not leak private counts or sensitive comment/profile fields", async () => {
    const privateCounts = await expectOk(
      anon.rpc("get_public_session_application_counts", {
        target_session_id: SESSION.private
      }),
      "private public count rpc"
    );
    const hiddenCounts = await expectOk(
      anon.rpc("get_public_session_application_counts", {
        target_session_id: SESSION.hidden
      }),
      "hidden public count rpc"
    );
    assert(privateCounts.length === 0, "private session count leaked");
    assert(hiddenCounts.length === 0, "hidden session count leaked");

    const comments = await expectOk(
      anon.rpc("get_public_session_comments", {
        target_session_id: SESSION.recruiting
      }),
      "public comment rpc final check"
    );
    assertNoSensitiveColumns(comments, "public comment rpc final check");
  });

  const failed = results.filter((result) => result.status === "FAIL");
  const skipped = results.filter((result) => result.status === "SKIP");

  console.log("");
  console.log("Supabase RLS smoke test summary");
  console.log(`PASS: ${results.filter((result) => result.status === "PASS").length}`);
  console.log(`FAIL: ${failed.length}`);
  console.log(`SKIP: ${skipped.length}`);

  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`Fatal error: ${sanitize(error)}`);
  process.exitCode = 1;
});
