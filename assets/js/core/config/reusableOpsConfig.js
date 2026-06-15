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
    labels: Object.freeze({
      sessionCountAriaPrefix: "この日の予定",
      detailLink: "詳細を見る",
      sessionsLoadError: "予定データを読み込めませんでした。カレンダー本体はそのまま利用できます。",
      sessionsEmpty: "この日のセッション予定はまだありません。",
      selectedSessionsTitle: "選択日のセッション予定",
      time: "時刻",
      gm: "GM"
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
      approvedOnlyLead: "この機能は承認済みメンバー向けです。",
      approvedOnlyHeading: "承認済みアカウントのみ利用できます",
      loginPrompt: "ログインし、承認済みアカウントになると利用できます。",
      accountStatusLink: "マイページで状態を確認する",
      accountLoginLink: "ACCOUNTでログインする",
      topLink: "TOPへ戻る",
      frontendRestrictionNote: "フロント表示制限は通常操作を閉じるための補助です。最終的なRPC側のapproved gateは後続工程で扱います。"
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
    summaries: Object.freeze({
      loggedIn: "ログイン中",
      characterDiscord: "PC名・Discord ID",
      loading: "読み込み中",
      savedTemplates: "保存済みテンプレート"
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
      management: "管理",
      discordSync: "Discord同期",
      discordSyncResultStatus: "Discord同期状態",
      discordSyncStatus: "同期状態",
      discordLastAction: "最終操作",
      discordSyncedAt: "最終同期日時",
      discordSyncError: "同期エラー",
      discordPostLink: "投稿リンク",
      recruitingStatus: "募集状態",
      visibility: "公開状態",
      playerCount: "募集人数",
      location: "開催場所",
      sessionType: "種別",
      sessionTypeFull: "セッション種別",
      sessionDate: "開催日",
      sessionTime: "開催時刻",
      applicationDeadline: "申請締切",
      levelRange: "レベル帯",
      updatedAt: "更新日時",
      detail: "詳細",
      requirements: "参加条件・注意事項",
      supplementalInfo: "補足情報",
      title: "タイトル",
      startAt: "開始日時",
      endAt: "終了日時",
      summary: "概要",
      detailLink: "詳細を見る",
      editManagement: "編集・管理",
      edit: "編集",
      close: "〆にする",
      delete: "削除",
      sessionPostTitle: "依頼書投稿",
      sessionPostLead: "ログインユーザー向けのセッション予定投稿フォームです。",
      sessionPostGateLead: "依頼書作成・編集は承認済みメンバー向けの機能です。",
      sessionPostGateHeading: "承認済みアカウントのみ依頼書投稿を利用できます",
      sessionDetailGateTitle: "セッション予定詳細",
      sessionDetailGateLead: "依頼書詳細、参加申請、コメントは承認済みメンバー向けの機能です。",
      sessionDetailGateHeading: "承認後に依頼書詳細を確認できます",
      postPermission: "投稿権限",
      sessionPostModeNoteNew: "初期値は非公開の下書きです。",
      sessionPostModeNoteEdit: "選択中の依頼書を編集中です。内容を変更したら「変更を保存」を押してください。",
      ownSessions: "自分の依頼書",
      managedSessions: "管理対象の依頼書",
      newSessionPost: "新規依頼書を書く",
      confirmPublicSave: "公開状態で保存する場合に確認する",
      create: "作成する",
      saveChanges: "変更を保存",
      sessionPostResult: "作成結果"
    }),
    playerCountLabels: Object.freeze({
      min: "min",
      max: "max"
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

export function getCalendarLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.calendar.labels?.[key] || fallback;
}

export function getMembershipGateLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.membership.gateLabels[key] || fallback;
}

export function getMypageSectionLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.mypage.sections[key] || fallback;
}

export function getMypageSummaryLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.mypage.summaries[key] || fallback;
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

export function getOpsSessionPlayerCountLabel(key, fallback = "") {
  return REUSABLE_OPS_CONFIG.session.playerCountLabels?.[key] || fallback;
}
