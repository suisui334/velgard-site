import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js";
import { getMembershipGateLabel } from "./core/config/reusableOpsConfig.js?v=20260615-core-config-move";

const MEMBERSHIP_STATUS_VALUES = new Set(["pending", "approved", "rejected", "revoked", "blocked"]);

const STATUS_MESSAGES = {
  pending: "現在、管理者承認待ちです。承認後にカレンダー、依頼書への参加申請、コメント投稿などが利用できるようになります。",
  rejected: "このアカウントは承認されていないため、コミュニティ機能は利用できません。",
  revoked: "このアカウントは現在利用停止中です。",
  blocked: "このアカウントではコミュニティ機能を利用できません。",
  unknown: "会員状態を確認できませんでした。時間を置いて再度お試しください。",
  anonymous: "ログインし、承認済みアカウントになると利用できます。"
};

function escapeHtml(value = "") {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  })[character]);
}

export function normalizeMembershipStatus(status) {
  const normalized = String(status || "").trim().toLowerCase();
  return MEMBERSHIP_STATUS_VALUES.has(normalized) ? normalized : "unknown";
}

export function isApprovedMembershipStatus(status) {
  return normalizeMembershipStatus(status) === "approved";
}

export function isApprovedMembershipState(state) {
  return Boolean(state && state.isAuthenticated && state.isApproved);
}

export function shouldHideCommunityNav(state) {
  return Boolean(state && state.isAuthenticated && !state.isApproved);
}

function getMembershipStatusRow(data) {
  if (Array.isArray(data)) return data[0] || null;
  return data && typeof data === "object" ? data : null;
}

export async function getCurrentMembershipState(existingClient = null) {
  let client = null;
  try {
    client = existingClient || await createSupabaseBrowserClient();
  } catch {
    client = null;
  }
  if (!client) {
    return {
      client: null,
      session: null,
      isAuthenticated: false,
      isApproved: false,
      status: "anonymous",
      reason: "unconfigured"
    };
  }

  let session = null;
  try {
    const { data, error } = await client.auth.getSession();
    if (error) {
      return {
        client,
        session: null,
        isAuthenticated: false,
        isApproved: false,
        status: "anonymous",
        reason: "session-error"
      };
    }
    session = data?.session || null;
  } catch {
    return {
      client,
      session: null,
      isAuthenticated: false,
      isApproved: false,
      status: "anonymous",
      reason: "session-error"
    };
  }

  if (!session?.user?.id) {
    return {
      client,
      session: null,
      isAuthenticated: false,
      isApproved: false,
      status: "anonymous",
      reason: "signed-out"
    };
  }

  try {
    const { data, error } = await client.rpc("get_my_membership_status");
    if (error) throw error;
    const row = getMembershipStatusRow(data);
    const status = normalizeMembershipStatus(row?.status);
    return {
      client,
      session,
      isAuthenticated: true,
      isApproved: isApprovedMembershipStatus(status),
      status,
      reason: ""
    };
  } catch {
    return {
      client,
      session,
      isAuthenticated: true,
      isApproved: false,
      status: "unknown",
      reason: "membership-error"
    };
  }
}

export function getMembershipGateMessage(state) {
  if (!state || !state.isAuthenticated) {
    return getMembershipGateLabel("loginPrompt", STATUS_MESSAGES.anonymous);
  }
  return STATUS_MESSAGES[normalizeMembershipStatus(state.status)] || STATUS_MESSAGES.unknown;
}

export function renderMembershipGateNotice(state, options = {}) {
  const eyebrow = options.eyebrow || "Account";
  const title = options.title || getMembershipGateLabel("approvedOnlyTitle", "承認済みアカウント専用");
  const lead = options.lead || getMembershipGateLabel("approvedOnlyLead", "この機能は承認済みメンバー向けです。");
  const heading = options.heading || getMembershipGateLabel("approvedOnlyHeading", "承認済みアカウントのみ利用できます");
  const message = options.message || getMembershipGateMessage(state);
  const accountLabel = state?.isAuthenticated
    ? getMembershipGateLabel("accountStatusLink", "マイページで状態を確認する")
    : getMembershipGateLabel("accountLoginLink", "ACCOUNTでログインする");
  const restrictionNote = getMembershipGateLabel(
    "frontendRestrictionNote",
    "フロント表示制限は通常操作を閉じるための補助です。最終的なRPC側のapproved gateは後続工程で扱います。"
  );
  const topLabel = getMembershipGateLabel("topLink", "TOPへ戻る");

  return `
    <header class="page-title">
      <div class="eyebrow">${escapeHtml(eyebrow)}</div>
      <h1>${escapeHtml(title)}</h1>
      <p class="lead">${escapeHtml(lead)}</p>
    </header>
    <section class="section">
      <article class="article-box membership-gate-notice">
        <h2>${escapeHtml(heading)}</h2>
        <p>${escapeHtml(message)}</p>
        <p class="membership-gate-note">${escapeHtml(restrictionNote)}</p>
        <p class="actions">
          <a class="button primary" href="mypage.html">${escapeHtml(accountLabel)}</a>
          <a class="button" href="index.html">${escapeHtml(topLabel)}</a>
        </p>
      </article>
    </section>
  `;
}
