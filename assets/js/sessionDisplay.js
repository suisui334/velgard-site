const SESSION_STATUSES = {
  draft: "下書き",
  tentative: "仮予定",
  recruiting: "募集中",
  full: "満席",
  closed: "締切",
  finished: "終了",
  canceled: "中止"
};

export function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[char]));
}

export function getSessionStatusLabel(status) {
  return SESSION_STATUSES[status] || "未設定";
}

export function getSessionStatusClass(status) {
  return Object.prototype.hasOwnProperty.call(SESSION_STATUSES, status) ? status : "unknown";
}

export function isClosedSession(session) {
  return session?.status === "closed";
}

export function getSessionTitle(session) {
  return String(session?.title || "無題のセッション").trim();
}

export function getSessionDisplayTitle(session) {
  return isClosedSession(session) ? `〆 ${getSessionTitle(session)}` : getSessionTitle(session);
}

export function shouldShowSessionState(session) {
  return ["tentative", "finished", "canceled"].includes(session?.status);
}

export function formatSessionTime(session) {
  const start = String(session?.startTime || "").trim();
  const end = String(session?.endTime || "").trim();
  if (start && end) return `${start}〜${end}`;
  if (start) return `${start}〜`;
  return end || "時刻未定";
}

export function formatPlayerCount(session, options = {}) {
  const count = Number.isFinite(Number(session?.playerCount)) ? Number(session.playerCount) : null;
  const max = Number.isFinite(Number(session?.playerMax)) ? Number(session.playerMax) : null;
  const min = Number.isFinite(Number(session?.playerMin)) ? Number(session.playerMin) : null;
  const base = (() => {
    if (count !== null && max !== null) return `${count} / ${max}名`;
    if (max !== null) return `最大${max}名`;
    if (count !== null) return `${count}名`;
    return "未設定";
  })();
  if (options.includeMinimum && min !== null && base !== "未設定") {
    return `${base}（最低${min}名）`;
  }
  return base;
}

export function formatSessionUpdatedAt(value) {
  const text = String(value ?? "").trim();
  if (!text) return "";

  const dateOnly = text.match(/^(\d{4}-\d{2}-\d{2})$/);
  if (dateOnly) return dateOnly[1];

  const dateTime = text.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?$/);
  if (dateTime) return `${dateTime[1]} ${dateTime[2]}:${dateTime[3]}`;

  return "";
}

export function renderSessionTags(tags) {
  if (!Array.isArray(tags) || !tags.length) return "";
  return `
    <div class="calendar-session-tags">
      ${tags.map((tag) => `<span>${escapeHtml(tag)}</span>`).join("")}
    </div>
  `;
}

export function renderSessionDetailRow(label, value) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  return `
    <div>
      <dt>${escapeHtml(label)}</dt>
      <dd>${escapeHtml(text)}</dd>
    </div>
  `;
}

export function renderSessionDetailArrayRow(label, values) {
  if (!Array.isArray(values) || !values.length) return "";
  const text = values.map((value) => String(value ?? "").trim()).filter(Boolean).join(" / ");
  return renderSessionDetailRow(label, text);
}

export function renderSessionSummary(session) {
  return session?.summary
    ? `<section class="calendar-session-modal-block"><h3>概要</h3><p>${escapeHtml(session.summary)}</p></section>`
    : "";
}

function renderSessionApplicationPanel(session) {
  const status = session?.status;
  if (status === "closed") {
    return `
      <section class="session-application-panel session-comment-application-panel is-closed" aria-labelledby="session-application-title">
        <div class="session-application-copy">
          <h3 id="session-application-title">参加希望コメント</h3>
          <p>このセッションは募集を締め切っています。</p>
          <p class="session-application-note">新規の参加希望コメントは受け付けていません。</p>
        </div>
        <button class="session-application-button session-comment-button" type="button" disabled>募集締切</button>
      </section>
    `;
  }

  if (status === "finished" || status === "canceled") {
    const className = status === "finished" ? "is-finished" : "is-canceled";
    const lead = status === "finished"
      ? "このセッションは終了しています。"
      : "このセッションは中止されています。";
    return `
      <section class="session-application-panel session-comment-application-panel ${className}" aria-labelledby="session-application-title">
        <div class="session-application-copy">
          <h3 id="session-application-title">参加希望コメント</h3>
          <p>${escapeHtml(lead)}</p>
        </div>
      </section>
    `;
  }

  const lead = status === "full"
    ? "現在は定員到達状態です。コメント機能は現在準備中です。"
    : "コメント機能は現在準備中です。";
  return `
    <section class="session-application-panel session-comment-application-panel is-preparing" aria-labelledby="session-application-title">
      <div class="session-application-copy">
        <h3 id="session-application-title">参加希望コメント</h3>
        <p>${escapeHtml(lead)}</p>
        <p class="session-application-note">将来的には、この欄から参加希望コメントを投稿できるようにする予定です。</p>
      </div>
      <div class="session-comment-form-mock" aria-label="参加希望コメント入力モック">
        <label class="session-comment-field">
          <span>申請用テンプレート</span>
          <select class="session-comment-select" disabled>
            <option>テンプレートを選択（準備中）</option>
          </select>
        </label>
        <label class="session-comment-field">
          <span>コメント内容</span>
          <textarea class="session-comment-textarea" rows="4" disabled placeholder="参加希望コメントの入力欄（準備中）"></textarea>
        </label>
        <button class="session-application-button session-comment-button" type="button" disabled>コメント投稿（準備中）</button>
      </div>
      <p class="session-comment-count-note">※参加人数はコメント件数ではなく、申請者単位で管理する想定です。</p>
    </section>
  `;
}

export function renderSessionDetailContent(session, options = {}) {
  const mode = options.mode || "modal";
  const headingId = options.headingId || "calendar-session-modal-title";
  const eyebrow = options.eyebrow || "Session Detail";
  const formatDate = typeof options.formatDate === "function" ? options.formatDate : (value) => value;
  const playerCount = formatPlayerCount(session, { includeMinimum: options.includeMinimumPlayers });
  const basicRows = [
    renderSessionDetailRow("開催日", session?.date ? formatDate(session.date) : ""),
    renderSessionDetailRow("開催時刻", formatSessionTime(session)),
    renderSessionDetailRow("GM", session?.gmName),
    renderSessionDetailRow("レベル帯", session?.levelRange),
    renderSessionDetailRow("募集人数", playerCount)
  ].join("");
  const detailBlocks = [
    session?.detail ? `<section class="calendar-session-modal-block"><h3>詳細</h3><p>${escapeHtml(session.detail)}</p></section>` : "",
    session?.requirements ? `<section class="calendar-session-modal-block"><h3>参加条件・注意事項</h3><p>${escapeHtml(session.requirements)}</p></section>` : ""
  ].join("");
  const supplementalRows = [
    renderSessionDetailRow("状態", getSessionStatusLabel(session?.status)),
    renderSessionDetailRow("更新日時", formatSessionUpdatedAt(session?.updatedAt))
  ].join("");
  const supplementalHtml = supplementalRows
    ? `
      <section class="calendar-session-modal-supplement">
        <h3>補足情報</h3>
        <dl class="calendar-session-modal-meta calendar-session-modal-meta--supplement">
          ${supplementalRows}
        </dl>
      </section>
    `
    : "";
  const applicationHtml = mode === "page" ? renderSessionApplicationPanel(session) : "";

  return `
    <div class="calendar-session-modal-content session-detail-content session-detail-content--${escapeHtml(mode)}">
      <div class="calendar-session-modal-head">
        <p class="eyebrow">${escapeHtml(eyebrow)}</p>
        <h2 id="${escapeHtml(headingId)}">${escapeHtml(getSessionDisplayTitle(session))}</h2>
      </div>
      <dl class="calendar-session-modal-meta">
        ${basicRows}
      </dl>
      ${renderSessionSummary(session)}
      ${detailBlocks}
      ${applicationHtml}
      ${renderSessionTags(session?.tags)}
      ${supplementalHtml}
    </div>
  `;
}
