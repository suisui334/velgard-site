export const REUSABLE_OPS_CONFIG = Object.freeze({
  site: Object.freeze({
    siteName: "“灰壁と花霧の国”ヴェルガルド",
    worldName: "ヴェルガルド"
  }),
  calendar: Object.freeze({
    buttons: Object.freeze({
      confirm: "確認",
      todayShort: "今日",
      todayShortAria: "今日へ",
      todayReturn: "今日に戻す"
    }),
    sessionTypes: Object.freeze({
      "one-shot": Object.freeze({
        label: "単発シナリオ",
        colorName: "blue",
        calendarClass: "calendar-session-type-one-shot"
      }),
      campaign: Object.freeze({
        label: "キャンペーン",
        colorName: "green",
        calendarClass: "calendar-session-type-campaign"
      }),
      special: Object.freeze({
        label: "特殊",
        colorName: "red",
        calendarClass: "calendar-session-type-special"
      }),
      other: Object.freeze({
        label: "その他",
        colorName: "purple",
        calendarClass: "calendar-session-type-other"
      })
    })
  }),
  membership: Object.freeze({
    gateLabels: Object.freeze({
      approvedOnlyTitle: "承認済みアカウント専用",
      approvedOnlyHeading: "承認済みアカウントのみ利用できます"
    })
  }),
  mypage: Object.freeze({
    sections: Object.freeze({
      account: "アカウント概要",
      profileAndCharacters: "プロフィール / PC情報",
      scheduleAndApplications: "予定 / 申請履歴",
      templates: "テンプレート管理",
      membershipManagement: "会員管理"
    })
  })
});

const DEFAULT_SESSION_TYPE = "other";

function getSessionTypeConfig(sessionType) {
  const key = String(sessionType || "").trim();
  return REUSABLE_OPS_CONFIG.calendar.sessionTypes[key]
    || REUSABLE_OPS_CONFIG.calendar.sessionTypes[DEFAULT_SESSION_TYPE];
}

export function getOpsSessionTypeLabel(sessionType) {
  return getSessionTypeConfig(sessionType).label;
}

export function getOpsSessionTypeCalendarClass(sessionType) {
  return getSessionTypeConfig(sessionType).calendarClass;
}

export function getCalendarButtonLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.calendar.buttons[key] || fallback;
}
