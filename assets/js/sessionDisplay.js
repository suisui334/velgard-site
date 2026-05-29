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
    renderSessionDetailRow("更新日", session?.updatedAt),
    renderSessionDetailArrayRow("関連スポットID", session?.relatedSpotIds),
    renderSessionDetailRow("シナリオID", session?.scenarioId),
    renderSessionDetailRow("公開範囲", session?.visibility)
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
      ${renderSessionTags(session?.tags)}
      ${supplementalHtml}
    </div>
  `;
}
