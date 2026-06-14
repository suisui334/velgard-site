(function () {
  "use strict";

  const labels = Object.freeze({
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
    })
  });

  function getLabel(groupName, key, fallback = "") {
    const group = labels[groupName];
    if (!group || !key) return fallback;
    return group[key] || fallback;
  }

  window.VELGARD_REUSABLE_OPS_MYPAGE = Object.freeze({
    labels,
    getSectionLabel(key, fallback = "") {
      return getLabel("sections", key, fallback);
    },
    getSummaryLabel(key, fallback = "") {
      return getLabel("summaries", key, fallback);
    }
  });
})();
