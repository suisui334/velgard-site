import { loadJson } from "./dataLoader.js";

const CONFIG_URL = "data/calendarConfig.json?v=20260529-calendar-cap-start";
const REAL_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[char]));
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

function renderMonthCalendar(year, month, selectedIso, todayIso, config) {
  const firstIso = toIsoDate(year, month, 1);
  const firstWeekday = new Date(parseIsoDate(firstIso).time).getUTCDay();
  const days = realDaysInMonth(year, month);
  const blanks = Array.from({ length: firstWeekday }, (_, index) => `<div class="calendar-day-empty" aria-hidden="true" data-empty="${index}"></div>`).join("");
  const cells = Array.from({ length: days }, (_, index) => {
    const day = index + 1;
    const isoDate = toIsoDate(year, month, day);
    const result = calculateCalendarResult(isoDate, config);
    const weekday = REAL_WEEKDAYS[new Date(parseIsoDate(isoDate).time).getUTCDay()];
    const classes = [
      "calendar-day-cell",
      result.inCampaign ? seasonClass(result.season) : "calendar-period-outside",
      result.inCampaign ? moonClass(result.moonPhase) : "",
      `calendar-cap-${result.levelCap.state}`,
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
      `
      : `<span class="calendar-day-status">${escapeHtml(result.levelCap.label)}</span>`;

    return `
      <button class="${classes}" type="button" data-calendar-date="${escapeHtml(isoDate)}" aria-label="${escapeHtml(ariaLabel)}">
        <span class="calendar-day-top">
          <span class="calendar-day-number">${day}</span>
          <span class="calendar-day-weekday">${weekday}</span>
        </span>
        ${detailHtml}
      </button>
    `;
  }).join("");

  return `
    <article class="article-box calendar-month-panel">
      <div class="calendar-month-toolbar">
        <button class="button" type="button" data-calendar-prev>前月へ</button>
        <h2>${year}年${month}月</h2>
        <button class="button" type="button" data-calendar-next>次月へ</button>
        <button class="button calendar-this-month" type="button" data-calendar-this-month>今日の月へ</button>
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

export async function renderCalendar(root) {
  const config = await loadJson(CONFIG_URL);
  const initialDate = todayInJapan();
  const initialParsed = parseIsoDate(initialDate);
  const todayResult = calculateCalendarResult(initialDate, config);
  let selectedIso = initialDate;
  let displayYear = initialParsed.year;
  let displayMonth = initialParsed.month;

  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Calendar</div>
      <h1>CALENDAR</h1>
      <p class="lead">現実日付から、ヴェルガルド運用上のラクシア日付・季節・月齢・レベルキャップを確認できます。Phase 1では読み取り専用です。</p>
    </header>
    <section class="section calendar-section">
      <div id="calendar-today">
        ${renderResultCard("今日の換算", todayResult)}
      </div>
      <div id="calendar-month-view">
        ${renderMonthCalendar(displayYear, displayMonth, selectedIso, initialDate, config)}
      </div>
      <div class="article-box calendar-control-panel">
        <div class="calendar-control-copy">
          <h2>任意日付を確認</h2>
          <p>現実日付を選ぶと、対応するラクシア5日分の範囲を表示します。選択した日付の月へ、月表示カレンダーも移動します。</p>
        </div>
        <form class="calendar-form" id="calendar-form">
          <label class="calendar-date-label" for="calendar-date-input">
            <span>現実日付</span>
            <input type="date" id="calendar-date-input" value="${escapeHtml(initialDate)}">
          </label>
          <div class="calendar-actions">
            <button class="button primary" type="submit">確認</button>
            <button class="button" type="button" id="calendar-today-button">今日に戻す</button>
          </div>
        </form>
      </div>
      <div id="calendar-selected" aria-live="polite">
        ${renderResultCard("選択日の換算", todayResult)}
      </div>
    </section>
  `;

  const form = root.querySelector("#calendar-form");
  const input = root.querySelector("#calendar-date-input");
  const todayButton = root.querySelector("#calendar-today-button");
  const selected = root.querySelector("#calendar-selected");
  const monthView = root.querySelector("#calendar-month-view");

  const drawSelected = () => {
    try {
      const result = calculateCalendarResult(selectedIso, config);
      selected.innerHTML = renderResultCard("選択日の換算", result);
    } catch (error) {
      selected.innerHTML = renderError(error.message || "日付換算に失敗しました。");
    }
  };

  const drawMonth = () => {
    monthView.innerHTML = renderMonthCalendar(displayYear, displayMonth, selectedIso, initialDate, config);
  };

  const selectDate = (isoDate, syncMonth = true) => {
    const parsed = parseIsoDate(isoDate);
    selectedIso = isoDate;
    input.value = isoDate;
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
      const today = parseIsoDate(todayInJapan());
      displayYear = today.year;
      displayMonth = today.month;
      drawMonth();
    }
  });
}
