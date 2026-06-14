import {
  escapeHtml,
  formatPlayerCount,
  formatSessionApplicationDeadline,
  formatSessionTime,
  formatSessionTool,
  formatSessionUpdatedAt,
  getSessionDisplayTitle,
  getSessionLabel,
  getSessionStatusClass,
  getSessionStatusLabel,
  getSessionTitle,
  getSessionTitleWithoutClosingMark,
  getSessionTypeLabel,
  getSessionVisibilityLabel,
  hasSessionClosingMark,
  isClosedSession,
  shouldShowSessionState
} from "./core/session/sessionDisplayHelpers.js?v=20260615-session-helper-extract";
import {
  renderSessionDetailArrayRow,
  renderSessionDetailRow
} from "./core/session/sessionHtmlHelpers.js?v=20260615-session-row-helper-extract";

export {
  escapeHtml,
  formatPlayerCount,
  formatSessionApplicationDeadline,
  formatSessionTime,
  formatSessionTool,
  formatSessionUpdatedAt,
  getSessionDisplayTitle,
  getSessionStatusClass,
  getSessionStatusLabel,
  getSessionTitle,
  getSessionTitleWithoutClosingMark,
  getSessionTypeLabel,
  getSessionVisibilityLabel,
  hasSessionClosingMark,
  isClosedSession,
  renderSessionDetailArrayRow,
  renderSessionDetailRow,
  shouldShowSessionState
};

const DISCORD_SYNC_STATUS_LABELS = {
  not_requested: "未投稿",
  pending: "処理中",
  posted: "投稿済み",
  failed: "同期失敗",
  skipped: "スキップ"
};

const DISCORD_LAST_ACTION_LABELS = {
  create: "新規投稿",
  update: "更新",
  close: "募集終了",
  delete: "削除",
  resync: "再同期"
};

function getDiscordSyncStatusLabel(status) {
  const normalized = String(status || "").trim();
  return DISCORD_SYNC_STATUS_LABELS[normalized] || "未確認";
}

function getDiscordLastActionLabel(action) {
  const normalized = String(action || "").trim();
  return DISCORD_LAST_ACTION_LABELS[normalized] || "なし";
}

function getDiscordSyncFields(session) {
  const statusLabel = getDiscordSyncStatusLabel(session?.discordSyncStatus || session?.discord_sync_status);
  const lastActionLabel = getDiscordLastActionLabel(session?.discordLastAction || session?.discord_last_action);
  const syncedAt = String(session?.discordSyncedAt || session?.discord_synced_at || "").trim() || "なし";
  const hasError = session?.discordSyncErrorPresent === true;
  const hasPostUrl = session?.discordPostUrlSaved === true;
  return {
    statusLabel,
    lastActionLabel,
    syncedAt,
    errorLabel: hasError ? "同期エラーあり。確認が必要です。" : "なし",
    postUrlLabel: hasPostUrl ? "保存あり" : "保存なし"
  };
}

export function renderSessionDiscordSyncPanel(session) {
  const fields = getDiscordSyncFields(session);
  const heading = getSessionLabel("discordSync", "Discord同期");
  return `
    <details class="session-detail-discord-sync-details">
      <summary class="session-detail-discord-sync-summary">${escapeHtml(`${heading}：${fields.statusLabel}`)}</summary>
      <div class="session-detail-discord-sync-body">
        <dl class="session-detail-discord-sync-list">
          <div>
            <dt>${escapeHtml(getSessionLabel("discordSyncStatus", "同期状態"))}</dt>
            <dd>${escapeHtml(fields.statusLabel)}</dd>
          </div>
          <div>
            <dt>${escapeHtml(getSessionLabel("discordLastAction", "最終操作"))}</dt>
            <dd>${escapeHtml(fields.lastActionLabel)}</dd>
          </div>
          <div>
            <dt>${escapeHtml(getSessionLabel("discordSyncedAt", "最終同期日時"))}</dt>
            <dd>${escapeHtml(fields.syncedAt)}</dd>
          </div>
          <div>
            <dt>${escapeHtml(getSessionLabel("discordSyncError", "同期エラー"))}</dt>
            <dd>${escapeHtml(fields.errorLabel)}</dd>
          </div>
          <div>
            <dt>${escapeHtml(getSessionLabel("discordPostLink", "投稿リンク"))}</dt>
            <dd>${escapeHtml(fields.postUrlLabel)}</dd>
          </div>
        </dl>
        <p class="session-detail-discord-sync-note">外部投稿IDや投稿URL全文は表示しません。</p>
      </div>
    </details>
  `;
}

export function renderSessionTags(tags) {
  if (!Array.isArray(tags) || !tags.length) return "";
  return `
    <div class="calendar-session-tags">
      ${tags.map((tag) => `<span>${escapeHtml(tag)}</span>`).join("")}
    </div>
  `;
}

function renderSessionDetailManageRow(session, options = {}) {
  if (!options.includeManageActions) return "";
  const isSupabase = session?.source === "supabase";
  const note = isSupabase
    ? "編集権限を確認しています。"
    : "この予定は静的データ由来のため、この画面では編集できません。";
  return `
    <div class="session-detail-manage-row" data-session-detail-manage-panel data-session-source="${escapeHtml(isSupabase ? "supabase" : "static")}">
      <dt>${escapeHtml(getSessionLabel("management", "管理"))}</dt>
      <dd>
        <div class="session-detail-manage-buttons">
          <button class="session-detail-manage-button session-detail-manage-edit" type="button" data-session-detail-edit disabled>${escapeHtml(getSessionLabel("edit", "編集"))}</button>
          <button class="session-detail-manage-button session-detail-manage-close" type="button" data-session-detail-close disabled hidden>${escapeHtml(getSessionLabel("close", "〆にする"))}</button>
          <button class="session-detail-manage-button session-detail-manage-delete" type="button" data-session-detail-delete disabled title="権限確認後に有効化します">${escapeHtml(getSessionLabel("delete", "削除"))}</button>
        </div>
        <p class="session-detail-manage-close-note" data-session-detail-close-note hidden></p>
        <p class="session-detail-manage-note" data-session-detail-manage-state>${escapeHtml(note)}</p>
        <div class="session-detail-discord-sync" data-session-detail-discord-sync hidden></div>
      </dd>
    </div>
  `;
}

export function renderSessionSummary(session) {
  return session?.summary
    ? `<section class="calendar-session-modal-block calendar-session-modal-summary-block"><p class="calendar-session-modal-summary-text">${escapeHtml(session.summary)}</p></section>`
    : "";
}

function renderSessionApplicationPanel(session) {
  const status = session?.status;
  const visibility = session?.visibility;
  const statusClass = `is-${getSessionStatusClass(status)}`;
  const lead = (() => {
    if (status === "closed") return "このセッションは募集を締め切っています。参加希望コメントは読み取り専用で確認できます。";
    if (status === "finished") return "このセッションは終了しています。参加希望コメントは読み取り専用で確認できます。";
    if (status === "canceled") return "このセッションは中止されています。参加希望コメントは読み取り専用で確認できます。";
    if (status === "full") return "現在は定員到達状態です。参加希望コメントは読み取り専用で確認できます。";
    return "公開されている参加希望コメントと申請人数を読み取り専用で表示します。";
  })();

  return `
    <section class="session-application-panel session-comment-application-panel is-readonly ${escapeHtml(statusClass)}" data-session-application-panel data-session-status="${escapeHtml(status || "")}" data-session-visibility="${escapeHtml(visibility || "")}" aria-labelledby="session-application-title">
      <div class="session-application-copy">
        <h3 id="session-application-title">${escapeHtml(getSessionLabel("applicationComment", "参加希望コメント"))}</h3>
        <p>${escapeHtml(lead)}</p>
        <p class="session-application-note" data-session-comment-auth-note>参加希望コメントの投稿にはログインが必要です。ACCOUNTからログインしてください。</p>
      </div>
      <div class="session-comment-post-control" data-session-comment-post-control aria-live="polite">
        <p class="session-comment-state">投稿状態を確認しています</p>
      </div>
      <div class="session-comment-counts" data-session-comment-counts aria-live="polite">
        <p class="session-comment-state">読み込み中</p>
      </div>
      <div class="session-comment-list" data-session-comment-list aria-live="polite">
        <p class="session-comment-state">読み込み中</p>
      </div>
      <div class="session-gm-history-control" data-session-gm-history-control hidden></div>
      <p class="session-comment-count-note">※人数はコメント件数ではなく、申請者単位で表示しています。</p>
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
    renderSessionDetailRow(getSessionLabel("sessionDate", "開催日"), session?.date ? formatDate(session.date) : ""),
    renderSessionDetailRow(getSessionLabel("sessionType", "種別"), getSessionTypeLabel(session?.sessionType)),
    renderSessionDetailRow(getSessionLabel("location", "開催場所"), formatSessionTool(session)),
    renderSessionDetailRow(getSessionLabel("sessionTime", "開催時刻"), formatSessionTime(session)),
    renderSessionDetailRow(getSessionLabel("applicationDeadline", "申請締切"), formatSessionApplicationDeadline(session)),
    renderSessionDetailRow(getSessionLabel("levelRange", "レベル帯"), session?.levelRange),
    renderSessionDetailRow(getSessionLabel("playerCount", "募集人数"), playerCount)
  ].join("");
  const detailBlocks = [
    session?.detail ? `<section class="calendar-session-modal-block"><h3>${escapeHtml(getSessionLabel("detail", "詳細"))}</h3><p>${escapeHtml(session.detail)}</p></section>` : "",
    session?.requirements ? `<section class="calendar-session-modal-block"><h3>${escapeHtml(getSessionLabel("requirements", "参加条件・注意事項"))}</h3><p>${escapeHtml(session.requirements)}</p></section>` : ""
  ].join("");
  const supplementalRows = [
    renderSessionDetailRow(getSessionLabel("visibility", "公開状態"), getSessionVisibilityLabel(session?.visibility), { attrs: "data-session-detail-visibility-row" }),
    renderSessionDetailRow(getSessionLabel("recruitingStatus", "募集状態"), getSessionStatusLabel(session?.status), { attrs: "data-session-detail-status-row" }),
    renderSessionDetailManageRow(session, options),
    renderSessionDetailRow(getSessionLabel("updatedAt", "更新日時"), formatSessionUpdatedAt(session?.updatedAt))
  ].join("");
  const supplementalHtml = supplementalRows
    ? `
      <section class="calendar-session-modal-supplement">
        <h3>${escapeHtml(getSessionLabel("supplementalInfo", "補足情報"))}</h3>
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
      ${supplementalHtml}
      ${applicationHtml}
    </div>
  `;
}
