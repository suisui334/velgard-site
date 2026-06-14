import { loadJson } from "./dataLoader.js";
import { loadMergedSessions } from "./sessionData.js?v=20260607-static-retire";
import {
  getCurrentMembershipState,
  isApprovedMembershipState,
  renderMembershipGateNotice
} from "./membershipAccessClient.js?v=20260613-unapproved-ui";
import {
  getCalendarButtonLabel,
  getOpsSessionTypeCalendarClass,
  getOpsSessionTypeLabel
} from "./reusableOpsConfig.js?v=20260615-ops-config-foundation";
import {
  escapeHtml,
  formatSessionApplicationDeadline,
  formatPlayerCount,
  formatSessionTime,
  getSessionDisplayTitle,
  getSessionStatusClass,
  getSessionStatusLabel,
  getSessionTitle,
  getSessionTitleWithoutClosingMark,
  hasSessionClosingMark,
  isClosedSession,
  renderSessionTags,
  shouldShowSessionState
} from "./sessionDisplay.js?v=20260607-gm-close-mark";

const CONFIG_URL = "data/calendarConfig.json?v=20260529-calendar-cap-start";
const SESSIONS_URL = "data/sessions.json?v=20260601-session-post";
const CALENDAR_SELECTED_DATE_KEY = "velgard.calendar.selectedDate";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const CALENDAR_EXCLUDED_STATUSES = new Set(["draft", "canceled", "cancelled"]);

function isVisibleSession(session) {
  const status = String(session?.status || "").trim();
  return session
    && session.visibility === "public"
    && !CALENDAR_EXCLUDED_STATUSES.has(status)
    && ISO_DATE_PATTERN.test(String(session.date || ""));
}

function sortSessions(a, b) {
  const timeA = String(a.startTime || "99:99");
  const timeB = String(b.startTime || "99:99");
  if (timeA !== timeB) return timeA.localeCompare(timeB, "ja");
  return String(a.title || "").localeCompare(String(b.title || ""), "ja");
}

function groupSessionsByDate(sessions) {
  const groups = new Map();
  sessions.filter(isVisibleSession).sort(sortSessions).forEach((session) => {
    if (!groups.has(session.date)) {
      groups.set(session.date, []);
    }
    groups.get(session.date).push(session);
  });
  return groups;
}

function sessionsForDate(sessionsByDate, isoDate) {
  return sessionsByDate.get(isoDate) || [];
}

function sessionDetailHref(session) {
  const id = String(session?.id || "").trim();
  return id ? `session-detail.html?id=${encodeURIComponent(id)}` : "session-detail.html";
}

function sessionPostHref(isoDate) {
  return `session-post.html?date=${encodeURIComponent(isoDate)}`;
}

function getCalendarSessionTypeClass(session) {
  return getOpsSessionTypeCalendarClass(session?.sessionType);
}

function isValidIsoDate(value) {
  try {
    parseIsoDate(value);
    return true;
  } catch {
    return false;
  }
}

function readStoredSelectedDate() {
  try {
    const stored = window.localStorage.getItem(CALENDAR_SELECTED_DATE_KEY);
    return isValidIsoDate(stored) ? stored : "";
  } catch {
    return "";
  }
}

function writeStoredSelectedDate(isoDate) {
  try {
    window.localStorage.setItem(CALENDAR_SELECTED_DATE_KEY, isoDate);
  } catch {
    // Storage failures should not block the calendar itself.
  }
}

function readInitialSelectedDate(fallbackIsoDate) {
  const params = new URLSearchParams(window.location.search);
  const queryDate = params.get("date");
  if (isValidIsoDate(queryDate)) return queryDate;
  return readStoredSelectedDate() || fallbackIsoDate;
}

function updateSelectedDateState(isoDate) {
  writeStoredSelectedDate(isoDate);
  try {
    const url = new URL(window.location.href);
    url.searchParams.set("date", isoDate);
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
  } catch {
    // URL state is helpful, but non-critical.
  }
}

function parseIsoDate(value) {
  const text = String(value || "").trim();
  if (!ISO_DATE_PATTERN.test(text)) {
    throw new Error("日付は YYYY-MM-DD 形式で指定してください。");
  }
  const [year, month, day] = text.split("-").map(Number);
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw new Error("存在しない日付です。");
  }
  return { year, month, day, time };
}

function toIsoDate(year, month, day) {
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function diffDays(fromIso, toIso) {
  const from = parseIsoDate(fromIso);
  const to = parseIsoDate(toIso);
  return Math.round((to.time - from.time) / 86400000);
}

function todayInJapan() {
  return new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(new Date());
}

function floorDiv(value, divisor) {
  return Math.floor(value / divisor);
}

function positiveMod(value, divisor) {
  return ((value % divisor) + divisor) % divisor;
}

function uniqueInOrder(items) {
  const seen = new Set();
  return items.filter((item) => {
    if (seen.has(item)) return false;
    seen.add(item);
    return true;
  });
}

function realDaysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function realMonthOffset(year, month, offset) {
  const date = new Date(Date.UTC(year, month - 1 + offset, 1));
  return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1 };
}

function laxiaMonthOrder(config) {
  const { monthsPerYear, yearStartMonth, monthOrder } = config.calendar;
  if (Array.isArray(monthOrder) && monthOrder.length === monthsPerYear) {
    return monthOrder.map(Number);
  }
  const startMonth = Number(yearStartMonth) || 1;
  return Array.from({ length: monthsPerYear }, (_, index) => positiveMod(startMonth - 1 + index, monthsPerYear) + 1);
}

function laxiaMonthIndex(month, config) {
  const order = laxiaMonthOrder(config);
  const index = order.indexOf(Number(month));
  return index >= 0 ? index : Number(month) - 1;
}

function laxiaAbsoluteDay(laxiaDate, config) {
  const monthsPerYear = config.calendar.monthsPerYear;
  const daysPerMonth = config.calendar.daysPerMonth;
  return (Number(laxiaDate.year) - 1) * monthsPerYear * daysPerMonth
    + laxiaMonthIndex(laxiaDate.month, config) * daysPerMonth
    + Number(laxiaDate.day) - 1;
}

function laxiaDateFromAbsolute(absoluteDay, config) {
  const { monthsPerYear, daysPerMonth, weekdays } = config.calendar;
  const monthOrder = laxiaMonthOrder(config);
  const daysPerYear = monthsPerYear * daysPerMonth;
  const yearOffset = floorDiv(absoluteDay, daysPerYear);
  const dayOfYear = positiveMod(absoluteDay, daysPerYear);
  const month = monthOrder[Math.floor(dayOfYear / daysPerMonth)];
  const day = dayOfYear % daysPerMonth + 1;
  const startAbsolute = laxiaAbsoluteDay(config.laxiaStart, config);
  const startWeekdayIndex = Math.max(0, weekdays.indexOf(config.laxiaStart.weekday));
  const weekday = weekdays[positiveMod(startWeekdayIndex + absoluteDay - startAbsolute, weekdays.length)];
  return {
    year: yearOffset + 1,
    month,
    day,
    weekday,
    absoluteDay
  };
}

function formatLaxiaDate(date, includeYear = true, includeMonth = true) {
  const year = includeYear ? `${date.year}年目` : "";
  const month = includeMonth ? `${date.month}月` : "";
  return `${year}${month}${date.day}日(${date.weekday})`;
}

function formatLaxiaRange(start, end) {
  if (start.year === end.year && start.month === end.month) {
    return `${formatLaxiaDate(start)}〜${end.day}日(${end.weekday})`;
  }
  if (start.year === end.year) {
    return `${formatLaxiaDate(start)}〜${formatLaxiaDate(end, false, true)}`;
  }
  return `${formatLaxiaDate(start)}〜${formatLaxiaDate(end)}`;
}

function formatShortLaxiaRange(start, end) {
  const startText = `${start.year}年目${start.month}/${start.day}`;
  if (start.year === end.year && start.month === end.month) {
    return `${startText}〜${end.day}`;
  }
  if (start.year === end.year) {
    return `${startText}〜${end.month}/${end.day}`;
  }
  return `${startText}〜${end.year}年目${end.month}/${end.day}`;
}

function formatRealDate(isoDate) {
  const parsed = parseIsoDate(isoDate);
  const weekday = REAL_WEEKDAYS[new Date(parsed.time).getUTCDay()];
  return `${parsed.year}年${parsed.month}月${parsed.day}日(${weekday})`;
}

function isMonthDayInRange(month, day, range) {
  const current = month * 100 + day;
  const start = Number(range.startMonth) * 100 + Number(range.startDay);
  const end = Number(range.endMonth) * 100 + Number(range.endDay);
  if (start <= end) {
    return current >= start && current <= end;
  }
  return current >= start || current <= end;
}

function seasonForDate(date, config) {
  const season = (config.seasons || []).find((item) => isMonthDayInRange(date.month, date.day, item));
  return season?.label || "不明";
}

function moonPhaseForDate(date, config) {
  const phase = (config.moonPhases || []).find((item) => date.day >= Number(item.startDay) && date.day <= Number(item.endDay));
  return phase?.label || config.labels?.normalMoon || "通常";
}

function labelsForRange(startAbsolute, endAbsolute, config, getLabel) {
  const labels = [];
  for (let absolute = startAbsolute; absolute <= endAbsolute; absolute += 1) {
    labels.push(getLabel(laxiaDateFromAbsolute(absolute, config), config));
  }
  return uniqueInOrder(labels).join(" → ");
}

function levelCapForDate(isoDate, config) {
  const labels = config.labels || {};
  if (isoDate < config.realStartDate) {
    return {
      state: "before",
      label: labels.beforeCampaign || "開催期間前",
      period: "",
      note: "ヴェルガルド運用開始前の日付です。"
    };
  }
  if (isoDate > config.realEndDate) {
    return {
      state: "after",
      label: labels.afterCampaign || "開催期間終了後",
      period: "",
      note: "レベルキャップ期間は終了しています。"
    };
  }

  const cap = (config.levelCaps || []).find((item) => isoDate >= item.startDate && isoDate <= item.endDate);
  if (!cap) {
    return {
      state: "outside",
      label: labels.outsideLevelCap || "レベルキャップ期間外",
      period: "",
      note: "この日付に対応するレベルキャップ設定が見つかりません。"
    };
  }

  return {
    state: "active",
    label: `${cap.level}Lv`,
    isStart: isoDate === cap.startDate,
    startLabel: `${cap.level}Lv開始`,
    period: `${formatRealDate(cap.startDate)}〜${formatRealDate(cap.endDate)}`,
    note: ""
  };
}

export function calculateCalendarResult(isoDate, config) {
  const levelCap = levelCapForDate(isoDate, config);
  const baseResult = {
    isoDate,
    realDate: formatRealDate(isoDate),
    inCampaign: isoDate >= config.realStartDate && isoDate <= config.realEndDate,
    levelCap
  };

  if (!baseResult.inCampaign) {
    return baseResult;
  }

  const realOffset = diffDays(config.realStartDate, isoDate);
  const startAbsolute = laxiaAbsoluteDay(config.laxiaStart, config) + realOffset * Number(config.daysPerRealDay);
  const endAbsolute = startAbsolute + Number(config.daysPerRealDay) - 1;
  const laxiaStart = laxiaDateFromAbsolute(startAbsolute, config);
  const laxiaEnd = laxiaDateFromAbsolute(endAbsolute, config);

  return {
    ...baseResult,
    laxiaRange: formatLaxiaRange(laxiaStart, laxiaEnd),
    laxiaShortRange: formatShortLaxiaRange(laxiaStart, laxiaEnd),
    season: labelsForRange(startAbsolute, endAbsolute, config, seasonForDate),
    moonPhase: labelsForRange(startAbsolute, endAbsolute, config, moonPhaseForDate),
    levelCap,
    laxiaStart,
    laxiaEnd
  };
}

function seasonClass(label) {
  if (label.includes("春")) return "calendar-season-spring";
  if (label.includes("夏")) return "calendar-season-summer";
  if (label.includes("秋")) return "calendar-season-autumn";
  if (label.includes("冬")) return "calendar-season-winter";
  return "calendar-season-unknown";
}

function moonClass(label) {
  if (label.includes("新月")) return "calendar-moon-new";
  if (label.includes("満月")) return "calendar-moon-full";
  return "calendar-moon-normal";
}

function shortLevelLabel(levelCap) {
  if (levelCap.state === "before") return "期間前";
  if (levelCap.state === "after") return "終了後";
  if (levelCap.state === "outside") return "期間外";
  return levelCap.label;
}

function renderResultCard(title, result) {
  const noteHtml = result.levelCap.note ? `<p class="calendar-note">${escapeHtml(result.levelCap.note)}</p>` : "";
  const capStartHtml = result.inCampaign && result.levelCap.isStart
    ? `
        <div class="calendar-cap-start-detail">
          <dt>節目</dt>
          <dd>この日から${escapeHtml(result.levelCap.label)}期間が開始します。</dd>
        </div>
      `
    : "";
  const rowsHtml = result.inCampaign
    ? `
        <div>
          <dt>現実日付</dt>
          <dd>${escapeHtml(result.realDate)}</dd>
        </div>
        <div>
          <dt>ラクシア日付</dt>
          <dd>${escapeHtml(result.laxiaRange)}</dd>
        </div>
        <div>
          <dt>季節</dt>
          <dd>${escapeHtml(result.season)}</dd>
        </div>
        <div>
          <dt>月齢</dt>
          <dd>${escapeHtml(result.moonPhase)}</dd>
        </div>
        <div>
          <dt>レベルキャップ</dt>
          <dd>${escapeHtml(result.levelCap.label)}</dd>
        </div>
        <div>
          <dt>期間</dt>
          <dd>${escapeHtml(result.levelCap.period || "--")}</dd>
        </div>
        ${capStartHtml}
      `
    : `
        <div>
          <dt>現実日付</dt>
          <dd>${escapeHtml(result.realDate)}</dd>
        </div>
        <div>
          <dt>状態</dt>
          <dd>${escapeHtml(result.levelCap.label)}</dd>
        </div>
      `;
  return `
    <article class="article-box calendar-result-card">
      <div class="calendar-result-head">
        <h2>${escapeHtml(title)}</h2>
        <span class="tag">${escapeHtml(result.levelCap.label)}</span>
      </div>
      <dl class="calendar-result-list">
        ${rowsHtml}
      </dl>
      ${noteHtml}
    </article>
  `;
}

function renderSessionBadges(sessions) {
  if (!sessions.length) return "";
  return `
    <span class="calendar-session-badges" aria-label="この日の予定 ${sessions.length}件">
      <span class="calendar-session-count" aria-hidden="true">${sessions.length}件</span>
      ${sessions.map((session) => {
        const closed = isClosedSession(session) || hasSessionClosingMark(session);
        const time = String(session.startTime || "未定").trim() || "未定";
        const gmName = String(session.gmName || "GM未設定").trim() || "GM未設定";
        const title = getSessionTitleWithoutClosingMark(session);
        const typeClass = getCalendarSessionTypeClass(session);
        return `
        <a class="calendar-session-row ${typeClass} ${closed ? "is-closed" : ""}" href="${escapeHtml(sessionDetailHref(session))}">
          <span class="calendar-session-time">${escapeHtml(time)}</span>
          ${closed ? `<span class="calendar-session-close" aria-label="締切">〆</span>` : ""}
          <span class="calendar-session-gm">${escapeHtml(gmName)}</span>
          <span class="calendar-session-title">${escapeHtml(title)}</span>
        </a>
      `;
      }).join("")}
    </span>
  `;
}

function renderSessionCard(session) {
  const detailButton = session.id
    ? `<a class="button small calendar-session-detail-button" href="${escapeHtml(sessionDetailHref(session))}">詳細を見る</a>`
    : "";
  const actionsHtml = detailButton
    ? `<div class="calendar-session-actions">${detailButton}</div>`
    : "";
  return `
    <article class="calendar-session-card ${getCalendarSessionTypeClass(session)}">
      <div class="calendar-session-card-head">
        <h3>${escapeHtml(getSessionDisplayTitle(session))}</h3>
        ${shouldShowSessionState(session) ? `<span class="calendar-session-state-note calendar-session-status-${getSessionStatusClass(session.status)}">${escapeHtml(getSessionStatusLabel(session.status))}</span>` : ""}
      </div>
      <dl class="calendar-session-meta">
        <div>
          <dt>時刻</dt>
          <dd>${escapeHtml(formatSessionTime(session))}</dd>
        </div>
        <div>
          <dt>種別</dt>
          <dd>${escapeHtml(getOpsSessionTypeLabel(session.sessionType))}</dd>
        </div>
        <div>
          <dt>申請締切</dt>
          <dd>${escapeHtml(formatSessionApplicationDeadline(session))}</dd>
        </div>
        <div>
          <dt>GM</dt>
          <dd>${escapeHtml(session.gmName || "未設定")}</dd>
        </div>
        <div>
          <dt>レベル</dt>
          <dd>${escapeHtml(session.levelRange || "未設定")}</dd>
        </div>
        <div>
          <dt>募集</dt>
          <dd>${escapeHtml(formatPlayerCount(session))}</dd>
        </div>
      </dl>
      ${session.summary ? `<p class="calendar-session-summary">${escapeHtml(session.summary)}</p>` : ""}
      ${renderSessionTags(session.tags)}
      ${actionsHtml}
    </article>
  `;
}

function renderSessionsPanel(isoDate, sessions, hasLoadError = false) {
  const bodyHtml = (() => {
    if (hasLoadError) {
      return `<p class="calendar-session-empty">予定データを読み込めませんでした。カレンダー本体はそのまま利用できます。</p>`;
    }
    if (!sessions.length) {
      return `<p class="calendar-session-empty">この日のセッション予定はまだありません。</p>`;
    }
    return `<div class="calendar-session-list">${sessions.map(renderSessionCard).join("")}</div>`;
  })();
  return `
    <article class="article-box calendar-sessions-panel">
      <div class="calendar-sessions-head">
        <h2>選択日のセッション予定</h2>
        <span class="tag">${escapeHtml(hasLoadError ? "読み込み失敗" : `${sessions.length}件`)}</span>
      </div>
      <p class="calendar-sessions-date">${escapeHtml(formatRealDate(isoDate))}</p>
      ${bodyHtml}
    </article>
  `;
}

function renderSelectedPanel(result, sessions, hasLoadError = false) {
  return `
    ${renderResultCard("選択日の換算", result)}
    ${renderSessionsPanel(result.isoDate, sessions, hasLoadError)}
  `;
}

function renderMonthCalendar(year, month, selectedIso, todayIso, config, sessionsByDate = new Map()) {
  const todayShortLabel = getCalendarButtonLabel("todayShort", "今日");
  const todayShortAriaLabel = getCalendarButtonLabel("todayShortAria", "今日へ");
  const firstIso = toIsoDate(year, month, 1);
  const firstWeekday = new Date(parseIsoDate(firstIso).time).getUTCDay();
  const days = realDaysInMonth(year, month);
  const blanks = Array.from({ length: firstWeekday }, (_, index) => `<div class="calendar-day-empty" aria-hidden="true" data-empty="${index}"></div>`).join("");
  const cells = Array.from({ length: days }, (_, index) => {
    const day = index + 1;
    const isoDate = toIsoDate(year, month, day);
    const result = calculateCalendarResult(isoDate, config);
    const daySessions = result.inCampaign ? sessionsForDate(sessionsByDate, isoDate) : [];
    const weekday = REAL_WEEKDAYS[new Date(parseIsoDate(isoDate).time).getUTCDay()];
    const primarySessionTypeClass = daySessions.length ? getCalendarSessionTypeClass(daySessions[0]) : "";
    const classes = [
      "calendar-day-cell",
      result.inCampaign ? seasonClass(result.season) : "calendar-period-outside",
      result.inCampaign ? moonClass(result.moonPhase) : "",
      `calendar-cap-${result.levelCap.state}`,
      primarySessionTypeClass,
      daySessions.length ? "has-sessions" : "",
      result.levelCap.isStart ? "is-cap-start" : "",
      isoDate === selectedIso ? "is-selected" : "",
      isoDate === todayIso ? "is-today" : ""
    ].filter(Boolean).join(" ");
    const ariaLabel = result.inCampaign
      ? `${formatRealDate(isoDate)} ${result.laxiaRange}${result.levelCap.isStart ? ` ${result.levelCap.startLabel}` : ""}`
      : `${formatRealDate(isoDate)} ${result.levelCap.label}`;
    const detailHtml = result.inCampaign
      ? `
        <span class="calendar-day-laxia">${escapeHtml(result.laxiaShortRange)}</span>
        <span class="calendar-day-tags">
          <span class="calendar-mini-tag">${escapeHtml(result.season)}</span>
          <span class="calendar-mini-tag">${escapeHtml(result.moonPhase)}</span>
          <span class="calendar-mini-tag">${escapeHtml(shortLevelLabel(result.levelCap))}</span>
          ${result.levelCap.isStart ? `<span class="calendar-mini-tag calendar-cap-start-tag">${escapeHtml(result.levelCap.startLabel)}</span>` : ""}
        </span>
        ${renderSessionBadges(daySessions)}
        <a class="calendar-session-post-link" href="${escapeHtml(sessionPostHref(isoDate))}">＋依頼書</a>
      `
      : `<span class="calendar-day-status">${escapeHtml(result.levelCap.label)}</span>`;

    return `
      <div class="${classes}" role="button" tabindex="0" data-calendar-date="${escapeHtml(isoDate)}" aria-label="${escapeHtml(ariaLabel)}">
        <span class="calendar-day-top">
          <span class="calendar-day-number">${day}</span>
          <span class="calendar-day-weekday">${weekday}</span>
        </span>
        ${detailHtml}
      </div>
    `;
  }).join("");

  return `
    <article class="article-box calendar-month-panel">
      <div class="calendar-month-toolbar">
        <h2 class="calendar-month-title">${year}年${month}月</h2>
        <div class="calendar-month-nav" aria-label="月表示の操作">
          <button class="button calendar-month-nav-button" type="button" data-calendar-prev aria-label="前月へ" title="前月へ">‹</button>
          <button class="button calendar-this-month calendar-month-today-button" type="button" data-calendar-this-month aria-label="${escapeHtml(todayShortAriaLabel)}" title="${escapeHtml(todayShortAriaLabel)}">${escapeHtml(todayShortLabel)}</button>
          <button class="button calendar-month-nav-button" type="button" data-calendar-next aria-label="次月へ" title="次月へ">›</button>
        </div>
      </div>
      <div class="calendar-weekdays" aria-hidden="true">
        ${REAL_WEEKDAYS.map((day) => `<span>${day}</span>`).join("")}
      </div>
      <div class="calendar-month-grid">
        ${blanks}
        ${cells}
      </div>
    </article>
  `;
}

function renderError(message) {
  return `<div class="notice">${escapeHtml(message)}</div>`;
}

export async function renderCalendar(root, _site, options = {}) {
  const membershipState = options.membershipState || await getCurrentMembershipState();
  if (!isApprovedMembershipState(membershipState)) {
    root.innerHTML = renderMembershipGateNotice(membershipState, {
      eyebrow: "Calendar",
      title: "CALENDAR",
      lead: "運用カレンダーは承認済みメンバー向けの機能です。",
      heading: "承認後にカレンダーを確認できます"
    });
    return;
  }

  const config = await loadJson(CONFIG_URL);
  let sessionsLoadError = false;
  const sessionsData = await loadMergedSessions(SESSIONS_URL).catch((error) => {
    console.warn(error);
    sessionsLoadError = true;
    return { sessions: [] };
  });
  const visibleSessions = Array.isArray(sessionsData.sessions)
    ? sessionsData.sessions.filter(isVisibleSession).sort(sortSessions)
    : [];
  const sessionsByDate = groupSessionsByDate(visibleSessions);
  const todayIso = todayInJapan();
  const initialDate = readInitialSelectedDate(todayIso);
  const initialParsed = parseIsoDate(initialDate);
  const todayResult = calculateCalendarResult(todayIso, config);
  const selectedResult = calculateCalendarResult(initialDate, config);
  const selectedSessions = sessionsForDate(sessionsByDate, initialDate);
  const confirmButtonLabel = getCalendarButtonLabel("confirm", "確認");
  const todayReturnLabel = getCalendarButtonLabel("todayReturn", "今日に戻す");
  let selectedIso = initialDate;
  let displayYear = initialParsed.year;
  let displayMonth = initialParsed.month;

  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Calendar</div>
      <h1>CALENDAR</h1>
      <p class="lead">現実日付から、ヴェルガルド運用上のラクシア日付・季節・月齢・レベルキャップを確認できます。</p>
    </header>
    <section class="section calendar-section">
      <div id="calendar-today">
        ${renderResultCard("今日の換算", todayResult)}
      </div>
      <div id="calendar-month-view">
        ${renderMonthCalendar(displayYear, displayMonth, selectedIso, todayIso, config, sessionsByDate)}
      </div>
      <div class="article-box calendar-control-panel">
        <div class="calendar-control-copy">
          <h2>任意日付を確認</h2>
          <p>現実日付を選ぶと、対応するラクシア5日分の範囲を表示します。選択した日付の月へ、月表示カレンダーも移動します。</p>
        </div>
        <form class="calendar-form" id="calendar-form">
          <label class="calendar-date-label" for="calendar-date-input">
            <span>現実日付</span>
            <input type="date" id="calendar-date-input" value="${escapeHtml(selectedIso)}">
          </label>
          <div class="calendar-actions">
            <button class="button primary" type="submit">${escapeHtml(confirmButtonLabel)}</button>
            <button class="button" type="button" id="calendar-today-button">${escapeHtml(todayReturnLabel)}</button>
          </div>
        </form>
      </div>
      <div id="calendar-selected" aria-live="polite">
        ${renderSelectedPanel(selectedResult, selectedSessions, sessionsLoadError)}
      </div>
    </section>
  `;
  updateSelectedDateState(selectedIso);

  const form = root.querySelector("#calendar-form");
  const input = root.querySelector("#calendar-date-input");
  const todayButton = root.querySelector("#calendar-today-button");
  const selected = root.querySelector("#calendar-selected");
  const monthView = root.querySelector("#calendar-month-view");

  const drawSelected = () => {
    try {
      const result = calculateCalendarResult(selectedIso, config);
      selected.innerHTML = renderSelectedPanel(result, sessionsForDate(sessionsByDate, selectedIso), sessionsLoadError);
    } catch (error) {
      selected.innerHTML = renderError(error.message || "日付換算に失敗しました。");
    }
  };

  const drawMonth = () => {
    monthView.innerHTML = renderMonthCalendar(displayYear, displayMonth, selectedIso, todayIso, config, sessionsByDate);
  };

  const selectDate = (isoDate, syncMonth = true) => {
    const parsed = parseIsoDate(isoDate);
    selectedIso = isoDate;
    input.value = isoDate;
    updateSelectedDateState(isoDate);
    if (syncMonth) {
      displayYear = parsed.year;
      displayMonth = parsed.month;
    }
    drawSelected();
    drawMonth();
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    try {
      selectDate(input.value, true);
    } catch (error) {
      selected.innerHTML = renderError(error.message || "日付換算に失敗しました。");
    }
  });

  input.addEventListener("change", () => {
    try {
      selectDate(input.value, true);
    } catch (error) {
      selected.innerHTML = renderError(error.message || "日付換算に失敗しました。");
    }
  });

  todayButton.addEventListener("click", () => {
    selectDate(todayInJapan(), true);
  });

  monthView.addEventListener("click", (event) => {
    if (event.target.closest(".calendar-session-row, .calendar-session-post-link")) return;
    const dayButton = event.target.closest("[data-calendar-date]");
    if (dayButton) {
      selectDate(dayButton.dataset.calendarDate, false);
      return;
    }
    if (event.target.closest("[data-calendar-prev]")) {
      const nextMonth = realMonthOffset(displayYear, displayMonth, -1);
      displayYear = nextMonth.year;
      displayMonth = nextMonth.month;
      drawMonth();
      return;
    }
    if (event.target.closest("[data-calendar-next]")) {
      const nextMonth = realMonthOffset(displayYear, displayMonth, 1);
      displayYear = nextMonth.year;
      displayMonth = nextMonth.month;
      drawMonth();
      return;
    }
    if (event.target.closest("[data-calendar-this-month]")) {
      selectDate(todayInJapan(), true);
    }
  });

  monthView.addEventListener("keydown", (event) => {
    if (event.target.closest(".calendar-session-row, .calendar-session-post-link")) return;
    if (event.key !== "Enter" && event.key !== " ") return;
    const dayButton = event.target.closest("[data-calendar-date]");
    if (!dayButton) return;
    event.preventDefault();
    selectDate(dayButton.dataset.calendarDate, false);
  });
}
