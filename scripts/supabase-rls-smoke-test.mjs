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

const GM_HISTORY_ALLOWED_KEYS = new Set([
  "display_name",
  "application_status",
  "created_at",
  "updated_at",
  "canceled_at",
  "comment_count",
  "last_comment_at"
]);

const GM_HISTORY_FORBIDDEN_KEYS = [
  "user_id",
  "email",
  "application_id",
  "comment_id",
  "discord_id",
  "discord_user_id",
  "discord_name",
  "role",
  "token",
  "access_token",
  "refresh_token",
  "jwt",
  "key",
  "secret",
  "gmUserId",
  "discordUserId"
];

const GM_HISTORY_ALLOWED_STATUSES = new Set(["pending", "accepted", "rejected", "waitlisted", "canceled"]);

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

function assertGmHistoryRows(rowOrRows, context) {
  assert(Array.isArray(rowOrRows), `${context} did not return an array`);

  for (const row of rowOrRows.filter(Boolean)) {
    const rowKeys = Object.keys(row);

    for (const expectedKey of GM_HISTORY_ALLOWED_KEYS) {
      assert(Object.prototype.hasOwnProperty.call(row, expectedKey), `${context} missing ${expectedKey}`);
    }

    for (const key of rowKeys) {
      assert(GM_HISTORY_ALLOWED_KEYS.has(key), `${context} exposed unexpected column ${key}`);
    }

    for (const forbiddenKey of GM_HISTORY_FORBIDDEN_KEYS) {
      assert(!Object.prototype.hasOwnProperty.call(row, forbiddenKey), `${context} exposed ${forbiddenKey}`);
    }

    assert(typeof row.display_name === "string", `${context} display_name was not a string`);
    assert(
      GM_HISTORY_ALLOWED_STATUSES.has(row.application_status),
      `${context} returned unexpected application_status ${row.application_status}`
    );
    assert(Number.isInteger(row.comment_count), `${context} comment_count was not an integer`);
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

async function getPublicComments(client, sessionId) {
  return expectOk(
    client.rpc("get_public_session_comments", {
      target_session_id: sessionId
    }),
    `get public comments for ${sessionId}`
  );
}

async function getGmSessionApplicationHistory(client, sessionId) {
  return expectOk(
    client.rpc("get_gm_session_application_history", {
      target_session_id: sessionId
    }),
    `get GM session application history for ${sessionId}`
  );
}

async function updateApplicationComment(client, commentId, body) {
  return expectOk(
    client.rpc("update_application_comment", {
      target_comment_id: commentId,
      comment_body: body
    }),
    `update application comment ${commentId}`
  );
}

async function deleteApplicationCommentAndMaybeCancel(client, commentId) {
  return expectOk(
    client.rpc("delete_application_comment_and_maybe_cancel", {
      target_comment_id: commentId
    }),
    `delete application comment ${commentId}`
  );
}

function assertPublicCommentBody(comments, commentId, expectedBody, context) {
  const row = comments.find((comment) => comment.comment_id === commentId);
  assert(row, `${context} did not return comment ${commentId}`);
  assert(row.body === expectedBody, `${context} returned an unexpected comment body`);
}

function assertPublicCommentMissing(comments, commentId, context) {
  const row = comments.find((comment) => comment.comment_id === commentId);
  assert(!row, `${context} returned deleted comment ${commentId}`);
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
  let playerAOtherGmCommentId;
  let f6PlayerAEditableCommentId;
  let f6GmEditableCommentId;
  let f6OwnerDeletedCommentId;
  let f6OwnerDeleteResult;
  let playerBRecruitingApplicationId;
  let gmAHistoryRows;
  let adminHistoryRows;

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

  await runTest("M11E-HIST-001", "anon cannot call GM session application history RPC", async () => {
    await expectError(
      anon.rpc("get_gm_session_application_history", {
        target_session_id: SESSION.recruiting
      }),
      "anon get_gm_session_application_history"
    );
  });

  await runTest("M10-APP-001", "anon cannot read session_applications rows", async () => {
    const { data, error } = await anon
      .from("session_applications")
      .select("session_id, status")
      .eq("session_id", SESSION.recruiting)
      .limit(1);

    if (error) return;

    assert(Array.isArray(data), "anon session_applications select did not return an array");
    assert(data.length === 0, "anon session_applications select returned rows");
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
    if (["pending", "accepted", "waitlisted"].includes(application.status)) {
      assert(total >= 1, "public count total did not include a countable player A application");
    } else {
      assert(
        ["rejected", "canceled"].includes(application.status),
        `unexpected player A application status after duplicate comment test: ${application.status}`
      );
    }
  });

  await runTest("M11E-HIST-002", "player A cannot read GM session application history", async () => {
    await expectError(
      playerA.rpc("get_gm_session_application_history", {
        target_session_id: SESSION.recruiting
      }),
      "player A get_gm_session_application_history"
    );
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
    playerAOtherGmCommentId = await createApplicationComment(
      playerA,
      SESSION.otherGm,
      "Player A other-GM application from smoke test."
    );
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
    const application = await getOwnApplication(playerB, SESSION.recruiting);
    playerBRecruitingApplicationId = application.id;
  });

  await runTest("M10-APP-002", "player A direct application select sees own rows but not player B rows", async () => {
    const data = await expectOk(
      playerA
        .from("session_applications")
        .select("id, session_id, status")
        .eq("session_id", SESSION.recruiting),
      "player A direct application select for recruiting"
    );
    const playerAApplicationId = requireId(playerARecruitingApplicationId, "player A recruiting application id");
    const playerBApplicationId = requireId(playerBRecruitingApplicationId, "player B recruiting application id");
    assert(data.some((row) => row.id === playerAApplicationId), "player A own application was not visible");
    assert(
      !data.some((row) => row.id === playerBApplicationId),
      "player B application was visible to player A"
    );
    assertNoSensitiveColumns(data, "player A direct application select");
  });

  await runTest("M10-APP-003", "player A mypage application column select does not expose user identity fields", async () => {
    const data = await expectOk(
      playerA
        .from("session_applications")
        .select("session_id, status, comment_id, created_at, updated_at, canceled_at")
        .eq("session_id", SESSION.recruiting),
      "player A mypage application column select"
    );
    assert(data.length >= 1, "player A mypage application column select returned no own rows");
    assertNoSensitiveColumns(data, "player A mypage application column select");
  });

  await runTest("M10-APP-004", "player A cannot see private or hidden application rows", async () => {
    const data = await expectOk(
      playerA
        .from("session_applications")
        .select("session_id, status")
        .in("session_id", [SESSION.private, SESSION.hidden]),
      "player A private hidden applications select"
    );
    assert(data.length === 0, "private or hidden application rows leaked to player A");
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

  await runTest("F6-EDIT-001", "player A can update own application comment", async () => {
    f6PlayerAEditableCommentId = await createApplicationComment(
      playerA,
      SESSION.recruiting,
      "F6 editable application comment from player A."
    );
    const editedBody = "F6 player A edited own application comment.";
    const data = await updateApplicationComment(
      playerA,
      requireId(f6PlayerAEditableCommentId, "F6 player A editable comment id"),
      editedBody
    );
    assert(data.length === 1, "update_application_comment did not return one updated row");
    const comments = await getPublicComments(anon, SESSION.recruiting);
    assertPublicCommentBody(
      comments,
      f6PlayerAEditableCommentId,
      editedBody,
      "F6 player A edited comment public RPC check"
    );
  });

  await runTest("F6-EDIT-002", "player A cannot update player B application comment", async () => {
    await expectError(
      playerA.rpc("update_application_comment", {
        target_comment_id: requireId(playerBCommentId, "player B comment id"),
        comment_body: "Player A should not update Player B comment through F6 RPC."
      }),
      "player A update player B application comment"
    );
  });

  await runTest("F6-EDIT-005", "anon cannot update application comments", async () => {
    await expectError(
      anon.rpc("update_application_comment", {
        target_comment_id: requireId(playerBCommentId, "player B comment id"),
        comment_body: "Anon should not update comments."
      }),
      "anon update_application_comment"
    );
  });

  await runTest("F6-EDIT-006", "blank application comment update is rejected", async () => {
    await expectError(
      playerA.rpc("update_application_comment", {
        target_comment_id: requireId(f6PlayerAEditableCommentId, "F6 player A editable comment id"),
        comment_body: "   "
      }),
      "blank update_application_comment"
    );
  });

  await runTest("F6-EDIT-007", "overlong application comment update is rejected", async () => {
    await expectError(
      playerA.rpc("update_application_comment", {
        target_comment_id: requireId(f6PlayerAEditableCommentId, "F6 player A editable comment id"),
        comment_body: "x".repeat(4001)
      }),
      "overlong update_application_comment"
    );
  });

  await runTest("F6-DELETE-002", "player A cannot delete player B application comment", async () => {
    await expectError(
      playerA.rpc("delete_application_comment_and_maybe_cancel", {
        target_comment_id: requireId(playerBCommentId, "player B comment id")
      }),
      "player A delete player B application comment"
    );
  });

  await runTest("F6-DELETE-005", "anon cannot delete application comments", async () => {
    await expectError(
      anon.rpc("delete_application_comment_and_maybe_cancel", {
        target_comment_id: requireId(playerBCommentId, "player B comment id")
      }),
      "anon delete_application_comment_and_maybe_cancel"
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

  await runTest("M11E-HIST-003", "gm A can read own session application history", async () => {
    gmAHistoryRows = await getGmSessionApplicationHistory(gmA, SESSION.recruiting);
    assert(gmAHistoryRows.length >= 1, "gm A history RPC returned no rows for own session");
    assertGmHistoryRows(gmAHistoryRows, "gm A history RPC");
  });

  await runTest("F6-EDIT-003", "gm A can update own session application comment", async () => {
    f6GmEditableCommentId = await createApplicationComment(
      playerB,
      SESSION.recruiting,
      "F6 GM editable application comment from player B."
    );
    const editedBody = "F6 GM A edited own session application comment.";
    const data = await updateApplicationComment(
      gmA,
      requireId(f6GmEditableCommentId, "F6 GM editable comment id"),
      editedBody
    );
    assert(data.length === 1, "GM update_application_comment did not return one updated row");
    const comments = await getPublicComments(anon, SESSION.recruiting);
    assertPublicCommentBody(
      comments,
      f6GmEditableCommentId,
      editedBody,
      "F6 GM edited comment public RPC check"
    );
  });

  await runTest("F6-EDIT-004", "gm A cannot update gm B session application comment", async () => {
    await expectError(
      gmA.rpc("update_application_comment", {
        target_comment_id: requireId(playerAOtherGmCommentId, "player A other GM comment id"),
        comment_body: "GM A should not update a GM B session comment through F6 RPC."
      }),
      "gm A update GM B session application comment"
    );
  });

  await runTest("F6-DELETE-004", "gm A cannot delete gm B session application comment", async () => {
    await expectError(
      gmA.rpc("delete_application_comment_and_maybe_cancel", {
        target_comment_id: requireId(playerAOtherGmCommentId, "player A other GM comment id")
      }),
      "gm A delete GM B session application comment"
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

  await runTest("M11E-HIST-004", "gm A cannot read gm B session application history", async () => {
    await expectError(
      gmA.rpc("get_gm_session_application_history", {
        target_session_id: SESSION.otherGm
      }),
      "gm A get_gm_session_application_history for gm B session"
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
    await runTest("F6-DELETE-001", "player A can delete own application comment when destructive tests are enabled", async () => {
      const keepAliveCommentId = await createApplicationComment(
        playerA,
        SESSION.recruiting,
        "F6 keep-alive application comment before owner delete."
      );
      f6OwnerDeletedCommentId = await createApplicationComment(
        playerA,
        SESSION.recruiting,
        "F6 owner delete target application comment."
      );
      requireId(keepAliveCommentId, "F6 keep-alive comment id");
      f6OwnerDeleteResult = await deleteApplicationCommentAndMaybeCancel(
        playerA,
        requireId(f6OwnerDeletedCommentId, "F6 owner delete target comment id")
      );
      assert(f6OwnerDeleteResult.length === 1, "delete RPC did not return one result row");
    });

    await runTest("F6-DELETE-003", "gm A can delete own session application comment when destructive tests are enabled", async () => {
      const gmDeleteTargetCommentId = await createApplicationComment(
        playerB,
        SESSION.recruiting,
        "F6 GM delete target application comment."
      );
      const data = await deleteApplicationCommentAndMaybeCancel(
        gmA,
        requireId(gmDeleteTargetCommentId, "F6 GM delete target comment id")
      );
      assert(data.length === 1, "GM delete RPC did not return one result row");
    });

    await runTest("F6-DELETE-007", "deleting one of multiple active application comments preserves application status", async () => {
      const row = f6OwnerDeleteResult?.[0];
      assert(row, "F6 owner delete result was not available");
      assert(row.application_canceled === false, "application was canceled even though an active comment remained");
      assert(
        Number(row.active_application_comment_count ?? 0) > 0,
        "delete RPC did not report remaining active application comments"
      );
      assert(row.application_status !== "canceled", "application status became canceled unexpectedly");
    });

    await runTest("F6-DELETE-009", "deleted application comment is not returned by public comments RPC", async () => {
      const comments = await getPublicComments(anon, SESSION.recruiting);
      assertPublicCommentMissing(
        comments,
        requireId(f6OwnerDeletedCommentId, "F6 owner deleted comment id"),
        "F6 public comments deleted filter check"
      );
    });

    await runTest("F6-EDIT-008", "deleted application comment cannot be updated", async () => {
      await expectError(
        playerA.rpc("update_application_comment", {
          target_comment_id: requireId(f6OwnerDeletedCommentId, "F6 owner deleted comment id"),
          comment_body: "This deleted comment should not be editable."
        }),
        "update deleted application comment"
      );
    });
  } else {
    await skipTest(
      "F6-DELETE-001",
      "player A delete own application comment success",
      "RUN_DESTRUCTIVE_TESTS is not true; logical delete success test is intentionally skipped."
    );
    await skipTest(
      "F6-DELETE-003",
      "gm A delete own session application comment success",
      "RUN_DESTRUCTIVE_TESTS is not true; GM logical delete success test is intentionally skipped."
    );
    await skipTest(
      "F6-DELETE-007",
      "active application comments remain after deleting one comment",
      "RUN_DESTRUCTIVE_TESTS is not true; delete state preservation test is intentionally skipped."
    );
    await skipTest(
      "F6-DELETE-009",
      "deleted application comment is hidden from public comments RPC",
      "RUN_DESTRUCTIVE_TESTS is not true; deleted comment visibility test is intentionally skipped."
    );
    await skipTest(
      "F6-EDIT-008",
      "deleted application comment cannot be updated",
      "RUN_DESTRUCTIVE_TESTS is not true; deleted comment edit rejection test is intentionally skipped."
    );
  }

  await skipTest(
    "F6-DELETE-006",
    "last active application comment deletion cancels the application",
    "Dedicated last-active fixture is not available in the current smoke test; avoid canceling reusable seeded applications."
  );
  await skipTest(
    "F6-DELETE-008",
    "non-application comment deletion does not change application status",
    "Current public RPC fixtures create application comments only; non-application fixture requires a future seed update."
  );
  await skipTest(
    "F6-DELETE-010",
    "application counts exclude canceled applications after delete",
    "Dedicated canceled-by-delete fixture is not available in the current smoke test."
  );
  await skipTest(
    "F6-DELETE-011",
    "accepted application last-comment deletion is guarded",
    "Accepted last-comment deletion is operationally heavy and requires a dedicated disposable fixture."
  );

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

  await runTest("M11E-HIST-005", "admin can read GM session application history", async () => {
    adminHistoryRows = await getGmSessionApplicationHistory(admin, SESSION.recruiting);
    assert(adminHistoryRows.length >= 1, "admin history RPC returned no rows for recruiting session");
    assertGmHistoryRows(adminHistoryRows, "admin history RPC");
  });

  await runTest("M11E-HIST-006", "GM history rows do not expose internal fields", async () => {
    assert(Array.isArray(gmAHistoryRows), "gm A history rows were not available");
    assert(Array.isArray(adminHistoryRows), "admin history rows were not available");
    assertGmHistoryRows(gmAHistoryRows, "gm A history shape check");
    assertGmHistoryRows(adminHistoryRows, "admin history shape check");
  });

  await runTest("M11E-HIST-007", "GM history includes current application status rows", async () => {
    assert(Array.isArray(gmAHistoryRows), "gm A history rows were not available");
    assert(
      gmAHistoryRows.some((row) => row.application_status === "accepted"),
      "gm A history did not include the accepted application status set earlier in the smoke test"
    );
  });

  await skipTest(
    "M11E-HIST-008",
    "canceled and rejected application history rows",
    "Fixture gap: dedicated canceled/rejected session_applications rows are not available in the reusable seed."
  );
  await skipTest(
    "M11E-HIST-009",
    "deleted comments do not break GM history",
    "Fixture gap: dedicated deleted-comment history fixture requires future seed or destructive setup."
  );
  await skipTest(
    "M11E-HIST-010",
    "comment_count counts active comments only",
    "Fixture gap: dedicated mixed active/deleted comment fixture is not available in the reusable seed."
  );

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
