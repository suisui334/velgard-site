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
      approvedOnlyHeading: "承認済みアカウントのみ利用できます",
      loginPrompt: "ログインし、承認済みアカウントになると利用できます。"
    })
  }),
  mypage: Object.freeze({
    sections: Object.freeze({
      account: "アカウント概要",
      profileAndCharacters: "プロフィール / PC情報",
      scheduleAndApplications: "予定 / 申請履歴",
      templates: "テンプレート管理",
      membershipManagement: "会員管理"
    }),
    membershipStatuses: Object.freeze({
      pending: "承認待ち",
      approved: "承認済み",
      rejected: "却下"
    }),
    membershipActions: Object.freeze({
      approve: "承認する",
      reject: "却下する",
      reapprove: "再承認する",
      grantManager: "管理権限を付与",
      revokeManager: "管理権限を剥奪"
    })
  }),
  session: Object.freeze({
    labels: Object.freeze({
      sessionPost: "依頼書",
      application: "参加申請",
      applicationComment: "参加希望コメント",
      comment: "コメント",
      gmManagement: "GM管理",
      discordSync: "Discord同期",
      recruitingStatus: "募集状態",
      visibility: "公開状態",
      playerCount: "募集人数",
      location: "開催場所",
      sessionType: "セッション種別",
      detailLink: "詳細を見る",
      editManagement: "編集・管理"
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

export function getMembershipGateLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.membership.gateLabels[key] || fallback;
}

export function getMypageSectionLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.mypage.sections[key] || fallback;
}

export function getMypageMembershipStatusLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.mypage.membershipStatuses[key] || fallback;
}

export function getMypageMembershipActionLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.mypage.membershipActions[key] || fallback;
}

export function getOpsSessionLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.session.labels[key] || fallback;
}
