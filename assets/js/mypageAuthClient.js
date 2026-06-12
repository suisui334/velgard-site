(function () {
  "use strict";

  const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
  const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
  const TURNSTILE_SRC = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
  const TURNSTILE_LOAD_KEY = "__VELGARD_TURNSTILE_SDK_LOAD";
  const MIN_PASSWORD_LENGTH = 8;
  const DISPLAY_NAME_MAX_LENGTH = 40;
  const AVATAR_BUCKET = "avatars";
  const AVATAR_MAX_BYTES = 1024 * 1024;
  const AVATAR_ALLOWED_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);
  const AVATAR_EXTENSION_BY_TYPE = Object.freeze({
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/webp": "webp"
  });
  const MEMBERSHIP_STATUS_VIEWS = Object.freeze({
    pending: {
      label: "承認待ち",
      tone: "pending",
      message: "現在、管理者承認待ちです。承認後に依頼書への参加申請やコメント投稿などが利用できるようになります。手動確認のため、反映まで時間がかかる場合があります。"
    },
    approved: {
      label: "承認済み",
      tone: "approved",
      message: "承認済みです。通常機能を利用できます。"
    },
    rejected: {
      label: "未承認",
      tone: "rejected",
      message: "承認されていないため、主要機能は利用できません。"
    },
    revoked: {
      label: "利用停止中",
      tone: "revoked",
      message: "現在、このアカウントは利用停止中です。"
    },
    blocked: {
      label: "利用不可",
      tone: "blocked",
      message: "現在、このアカウントでは利用できません。"
    }
  });
  const MEMBERSHIP_STATUS_VALUES = new Set(Object.keys(MEMBERSHIP_STATUS_VIEWS));
  const DISCORD_ID_MAX_LENGTH = 100;
  const PC_NAME_MAX_LENGTH = 40;
  const DISCORD_USER_ID_EXAMPLE = "123456789012345678";
  const DISCORD_USER_ID_PATTERN = /^\d{17,20}$/;
  const DISCORD_MENTION_INPUT_PATTERN = /^<@(\d{17,20})>$/;
  const DISCORD_USER_ID_FORMAT_MESSAGE = `DiscordユーザーIDは17〜20桁の数字で入力してください。\n入力例: ${DISCORD_USER_ID_EXAMPLE}`;
  const DISCORD_USER_ID_RECHECK_MESSAGE = `登録形式を確認してください。今後は ${DISCORD_USER_ID_EXAMPLE} のように17〜20桁の数字で登録してください。`;
  const APPLICATION_SELECT_COLUMNS = "session_id,status,comment_id,created_at,updated_at,canceled_at";
  const PUBLIC_SESSION_SELECT_COLUMNS = "id,title,date,start_time,gm_name,status,visibility";
  const TEMPLATE_PRESETS_RPC = "get_my_template_presets";
  const TEMPLATE_CREATE_RPC = "create_template_preset";
  const TEMPLATE_UPDATE_RPC = "update_template_preset";
  const TEMPLATE_DEACTIVATE_RPC = "deactivate_template_preset";
  const TEMPLATE_NAME_MAX_LENGTH = 80;
  const TEMPLATE_BODY_MAX_LENGTH = 5000;
  const SESSION_POST_TEMPLATE_FORMAT = "velgard.session_post_template.v1";
  const SESSION_POST_TITLE_MAX_LENGTH = 120;
  const SESSION_POST_TOOL_MAX_LENGTH = 80;
  const SESSION_POST_SUMMARY_MAX_LENGTH = 1000;
  const APPLICATION_STATUSES = ["pending", "waitlisted", "accepted"];
  const APPLICATION_STATUS_GROUPS = Object.freeze({
    pending: "pending",
    waitlisted: "pending",
    accepted: "accepted"
  });
  const APPLICATION_STATUS_LABELS = Object.freeze({
    pending: "参加申請中",
    waitlisted: "参加申請中（キャンセル待ち）",
    accepted: "参加予定"
  });
  const SESSION_STATUS_LABELS = Object.freeze({
    draft: "下書き",
    tentative: "仮予定",
    recruiting: "募集中",
    full: "満席",
    closed: "締切",
    finished: "終了",
    canceled: "中止",
    cancelled: "中止",
    archived: "アーカイブ"
  });
  const ENDED_SESSION_STATUSES = new Set(["closed", "finished", "canceled", "cancelled", "archived"]);
  const TEMPLATE_TYPE_OPTIONS = Object.freeze([
    { value: "call", label: "呼び出し用", note: "GM向け呼び出し用の自由本文テンプレートです。" },
    { value: "result", label: "リザルト用", note: "GM向けリザルト用の自由本文テンプレートです。" },
    { value: "session_post", label: "依頼書用", note: "依頼書フォーム用テンプレートです。この画面ではフォーム項目として編集します。" },
    { value: "application", label: "申請用", note: "PL向け参加申請コメント用の自由本文テンプレートです。" },
    { value: "other", label: "その他", note: "補助用途です。利用先に合わせて内容を確認してください。" }
  ]);
  const TEMPLATE_TYPE_VALUES = new Set(TEMPLATE_TYPE_OPTIONS.map((option) => option.value));
  const GM_TEMPLATE_VARIABLE_HELP = Object.freeze([
    {
      name: "{{session_title}}",
      substitution: "現在開いているセッションのタイトル",
      example: "灰壁線異常調査",
      note: "mypage上では置換されません。session-detailなど、実セッション文脈がある画面で置換されます。"
    },
    {
      name: "{{approved_call_list}}",
      substitution: "承認済み参加者のDiscordメンション、ユーザー名、PC名の一覧",
      example: [
        "Discord：<@123456789012345678>｜ユーザー名：マルフォイ｜PC名：ハリーポッター",
        "Discord：登録されていません｜ユーザー名：ボボボーボ・ボーボボ｜PC名：PC名未登録"
      ].join("\n"),
      note: "Discord未登録時は「登録されていません」、PC名未登録時は「PC名未登録」と表示されます。"
    },
    {
      name: "{{approved_pc_names}}",
      substitution: "承認済み参加者のPC名一覧",
      example: "ハリーポッター、軍艦、PC名未登録",
      note: "PC名未登録の参加者は「PC名未登録」として出力されます。"
    }
  ]);
  const TEMPLATE_VARIABLE_HELP_BY_TYPE = Object.freeze({
    call: GM_TEMPLATE_VARIABLE_HELP,
    result: GM_TEMPLATE_VARIABLE_HELP
  });
  const TEMPLATE_EXAMPLES_BY_TYPE = Object.freeze({
    call: [[
      "■依頼書【{{session_title}}】",
      "",
      "お待たせしました。以下のX名で開催します！",
      "{{approved_call_list}}",
      "",
      "- ここにTekey部屋リンクなどを置く",
      "",
      "お部屋を解放しました。入室後、ご準備をお願い致します。"
    ].join("\n")],
    result: [[
      "■依頼名【{{session_title}}】リザルト",
      "獲得資金【G】",
      "名誉点【点】",
      "参加者【{{approved_pc_names}}】",
      "【戦利品から全額補填】",
      "【買取（キャラクター名）／内容】",
      "称号【なし】",
      "コネクション【なし】",
      "フレーバーアイテム【なし】",
      "",
      "備考",
      "【】"
    ].join("\n")],
    session_post: [[
      "依頼人【】　報酬【規定額G】",
      "",
      "依頼内容文",
      "",
      "備考",
      "[部位数制限：なし] [環境：自然環境] [第二戦闘準備：あり] [シナリオ傾向：戦闘、RP]",
      "",
      "【】",
      "【】",
      "【】"
    ].join("\n")],
    application: [[
      "キャラクター名【】　性別【】　年齢【】",
      "技能【】",
      "役割【】",
      "URL【】"
    ].join("\n")],
    other: []
  });
  const DISCORD_MENTION_MODES = new Set(["everyone", "none"]);
  const SESSION_POST_TEMPLATE_FIELD_KEYS = Object.freeze([
    "p_title",
    "p_start_at",
    "p_end_at",
    "p_application_deadline",
    "p_session_type",
    "p_session_tool",
    "p_player_min",
    "p_player_max",
    "p_visibility",
    "p_status",
    "discord_mention_mode",
    "p_summary"
  ]);
  const SESSION_POST_TEMPLATE_DEFAULT_FIELDS = Object.freeze({
    p_title: "",
    p_start_at: "",
    p_end_at: "",
    p_application_deadline: "",
    p_session_type: "one-shot",
    p_session_tool: "",
    p_player_min: "",
    p_player_max: "",
    p_visibility: "hidden",
    p_status: "draft",
    discord_mention_mode: "",
    p_summary: ""
  });
  const SESSION_POST_TYPE_OPTIONS = Object.freeze([
    { value: "one-shot", label: "単発シナリオ" },
    { value: "campaign", label: "キャンペーン" },
    { value: "special", label: "特殊" },
    { value: "other", label: "その他" }
  ]);
  const SESSION_POST_VISIBILITY_OPTIONS = Object.freeze([
    { value: "hidden", label: "非公開" },
    { value: "private", label: "限定" },
    { value: "public", label: "公開" }
  ]);
  const SESSION_POST_STATUS_OPTIONS = Object.freeze([
    { value: "draft", label: "下書き" },
    { value: "tentative", label: "仮予定" },
    { value: "recruiting", label: "募集中" }
  ]);
  const TEMPLATE_PRESET_FIELD_NAMES = new Set([
    "template_id",
    "template_name",
    "template_type",
    "template_body",
    "is_active",
    "created_at",
    "updated_at"
  ]);

  function getConfig() {
    const config = window.VELGARD_SUPABASE_CONFIG || {};
    return {
      url: typeof config.url === "string" ? config.url.trim() : "",
      anonKey: typeof config.anonKey === "string" ? config.anonKey.trim() : "",
      turnstileSiteKey: typeof config.turnstileSiteKey === "string" ? config.turnstileSiteKey.trim() : ""
    };
  }

  function hasConfig(config) {
    return Boolean(config.url && config.anonKey);
  }

  function hasTurnstileConfig(config = getConfig()) {
    return Boolean(config.turnstileSiteKey);
  }

  function loadTurnstileSdk() {
    if (window.turnstile && typeof window.turnstile.render === "function") {
      return Promise.resolve(window.turnstile);
    }

    if (window[TURNSTILE_LOAD_KEY]) {
      return window[TURNSTILE_LOAD_KEY];
    }

    window[TURNSTILE_LOAD_KEY] = new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src^="${TURNSTILE_SRC.split("?")[0]}"]`);
      if (existing) {
        existing.addEventListener("load", () => resolve(window.turnstile), { once: true });
        existing.addEventListener("error", () => reject(new Error("turnstile-sdk-load-failed")), { once: true });
        return;
      }

      const script = document.createElement("script");
      script.src = TURNSTILE_SRC;
      script.async = true;
      script.defer = true;
      script.onload = () => resolve(window.turnstile);
      script.onerror = () => reject(new Error("turnstile-sdk-load-failed"));
      document.head.append(script);
    });

    return window[TURNSTILE_LOAD_KEY];
  }

  function createTurnstileControl(purpose) {
    const config = getConfig();
    const wrapper = document.createElement("div");
    wrapper.className = "auth-captcha-panel";
    wrapper.dataset.authCaptchaPurpose = purpose;

    const label = document.createElement("p");
    label.className = "auth-captcha-label";
    label.textContent = "CAPTCHA";

    const target = document.createElement("div");
    target.className = "auth-captcha-widget";

    const status = document.createElement("p");
    status.className = "auth-captcha-status";
    status.setAttribute("role", "status");
    status.setAttribute("aria-live", "polite");

    wrapper.append(label, target, status);

    let widgetId = null;
    let token = "";
    let rendered = false;
    let renderFailed = false;

    function setStatusText(message, isError = false) {
      status.textContent = message || "";
      status.hidden = !message;
      status.classList.toggle("is-error", Boolean(isError));
    }

    function clearToken(message = "") {
      token = "";
      setStatusText(message);
    }

    function mount() {
      if (!hasTurnstileConfig(config)) {
        wrapper.classList.add("is-unconfigured");
        target.textContent = "CAPTCHA設定が未完了です。";
        setStatusText("管理者側のCAPTCHA Site key設定後に送信できます。", true);
        return;
      }

      loadTurnstileSdk()
        .then((turnstile) => {
          if (!target.isConnected || !turnstile || typeof turnstile.render !== "function" || rendered) return;
          const isNarrowViewport = typeof window.matchMedia === "function"
            && window.matchMedia("(max-width: 360px)").matches;
          widgetId = turnstile.render(target, {
            sitekey: config.turnstileSiteKey,
            size: isNarrowViewport ? "compact" : "flexible",
            callback: (value) => {
              token = typeof value === "string" ? value : "";
              setStatusText(token ? "" : "CAPTCHA認証を完了してください。", !token);
            },
            "expired-callback": () => {
              clearToken("CAPTCHAの有効期限が切れました。もう一度認証してください。");
            },
            "error-callback": () => {
              clearToken("CAPTCHAを読み込めませんでした。時間を置いて再度お試しください。");
            }
          });
          rendered = true;
        })
        .catch(() => {
          renderFailed = true;
          setStatusText("CAPTCHAを読み込めませんでした。時間を置いて再度お試しください。", true);
        });
    }

    function reset() {
      token = "";
      if (window.turnstile && widgetId !== null && typeof window.turnstile.reset === "function") {
        window.turnstile.reset(widgetId);
      }
    }

    function getToken() {
      return token;
    }

    function isReady() {
      return hasTurnstileConfig(config) && !renderFailed;
    }

    return {
      element: wrapper,
      getToken,
      isReady,
      mount,
      reset,
      setStatusText
    };
  }

  function requireCaptchaToken(control, elements) {
    if (!control) return "";
    if (!control.isReady()) {
      setMessage(elements, "CAPTCHAを利用できません。設定または通信状態を確認してください。");
      return null;
    }

    const token = control.getToken();
    if (!token) {
      control.setStatusText("CAPTCHA認証を完了してください。", true);
      setMessage(elements, "CAPTCHA認証を完了してから送信してください。");
      return null;
    }

    return token;
  }

  function getMypageRedirectUrl() {
    const pagePath = "/mypage.html";
    const pathname = window.location.pathname || pagePath;
    const basePath = pathname.endsWith(pagePath)
      ? pathname.slice(0, -pagePath.length)
      : pathname.replace(/\/[^/]*$/, "");
    const normalizedBasePath = basePath === "/" ? "" : basePath.replace(/\/$/, "");
    return `${window.location.origin}${normalizedBasePath}${pagePath}`;
  }

  function isPasswordRecoveryReturnUrl() {
    const searchParams = new URLSearchParams(window.location.search || "");
    const hashParams = new URLSearchParams((window.location.hash || "").replace(/^#/, ""));
    return searchParams.get("type") === "recovery" || hashParams.get("type") === "recovery";
  }

  function findAccountElements(root) {
    const scope = root || document;
    let section = scope.querySelector("[data-mypage-auth-section]");

    if (!section) {
      const accountHeading = Array.from(scope.querySelectorAll("h2")).find((heading) => heading.textContent.trim() === "アカウント機能");
      section = accountHeading ? accountHeading.closest("article") : null;
    }

    if (!section) return null;

    const paragraphs = Array.from(section.querySelectorAll("p"));
    return {
      section,
      primary: section.querySelector("[data-mypage-auth-primary]") || paragraphs[0] || null,
      detail: section.querySelector("[data-mypage-auth-detail]") || paragraphs[1] || null,
      content: section.querySelector("[data-mypage-auth-content]") || null,
      message: section.querySelector("[data-mypage-auth-message]") || null
    };
  }

  function ensureAuthElements(elements) {
    if (!elements) return;

    if (!elements.content) {
      elements.content = document.createElement("div");
      elements.content.dataset.mypageAuthContent = "";
      elements.section.append(elements.content);
    }

    if (!elements.message) {
      elements.message = document.createElement("p");
      elements.message.className = "status";
      elements.message.dataset.mypageAuthMessage = "";
      elements.message.setAttribute("role", "status");
      elements.message.setAttribute("aria-live", "polite");
      elements.message.hidden = true;
      elements.section.append(elements.message);
    }
  }

  function setStatus(elements, primaryText, detailText) {
    if (!elements) return;
    if (elements.primary) elements.primary.textContent = primaryText;
    if (elements.detail) {
      elements.detail.textContent = detailText || "";
      elements.detail.hidden = !detailText;
    }
  }

  function setMessage(elements, message) {
    if (!elements || !elements.message) return;
    elements.message.textContent = message || "";
    elements.message.hidden = !message;
  }

  function clearContent(elements) {
    if (!elements || !elements.content) return;
    elements.content.replaceChildren();
  }

  function createInputField(labelText, input) {
    const label = document.createElement("label");
    label.className = "calendar-date-label";
    label.append(document.createTextNode(labelText));
    label.append(input);
    return label;
  }

  function createMypageDetails(titleText, metaText, options = {}) {
    const details = document.createElement("details");
    details.className = `mypage-details${options.className ? ` ${options.className}` : ""}`;
    if (options.open) details.open = true;

    const summary = document.createElement("summary");
    summary.className = "mypage-details-summary";

    const title = document.createElement("span");
    title.className = "mypage-details-title";
    title.textContent = titleText;

    const meta = document.createElement("span");
    meta.className = "mypage-details-meta";
    meta.textContent = metaText || "";

    const body = document.createElement("div");
    body.className = "mypage-details-body";

    summary.append(title, meta);
    details.append(summary, body);
    return { details, body, meta };
  }

  function setMypageDetailsMeta(panel, metaText) {
    if (panel && panel.meta) panel.meta.textContent = metaText || "";
  }

  function normalizeStatus(value) {
    return String(value || "").trim().toLowerCase();
  }

  function getApplicationGroup(application) {
    return APPLICATION_STATUS_GROUPS[normalizeStatus(application && application.status)] || "";
  }

  function getApplicationStatusLabel(status) {
    return APPLICATION_STATUS_LABELS[normalizeStatus(status)] || "申請状況未設定";
  }

  function getSessionStatusLabel(status) {
    return SESSION_STATUS_LABELS[normalizeStatus(status)] || "未設定";
  }

  function isEndedSession(session) {
    return ENDED_SESSION_STATUSES.has(normalizeStatus(session && session.status));
  }

  function isPublicSession(session) {
    return Boolean(
      session
        && typeof session.id === "string"
        && session.id.trim()
        && session.visibility === "public"
    );
  }

  function isVisibleScheduleSession(session) {
    const status = normalizeStatus(session && session.status);
    return isPublicSession(session) && !["draft", "canceled", "cancelled", "archived"].includes(status);
  }

  function getSessionTitle(session) {
    return String(session && session.title ? session.title : "無題のセッション").trim();
  }

  function isClosedMarkedSession(session) {
    return getSessionTitle(session).startsWith("〆");
  }

  function formatApplicationUpdatedAt(value) {
    const text = String(value || "").trim();
    if (!text) return "未設定";

    const dateOnly = text.match(/^(\d{4}-\d{2}-\d{2})$/);
    if (dateOnly) return dateOnly[1];

    const dateTime = text.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?$/);
    if (dateTime) return `${dateTime[1]} ${dateTime[2]}:${dateTime[3]}`;

    return text;
  }

  function formatSessionDate(session) {
    return String(session && session.date ? session.date : "").trim() || "日付未定";
  }

  function formatSessionStartTime(session) {
    return String(session && session.startTime ? session.startTime : "").trim() || "時刻未定";
  }

  function createMetaItem(labelText, valueText) {
    const item = document.createElement("div");
    const label = document.createElement("dt");
    const value = document.createElement("dd");
    label.textContent = labelText;
    value.textContent = valueText;
    item.append(label, value);
    return item;
  }

  function createApplicationSection(titleText, descriptionText, emptyText) {
    const section = document.createElement("section");
    section.className = "mypage-application-section";

    const head = document.createElement("div");
    head.className = "mypage-application-section-head";

    const title = document.createElement("h3");
    title.textContent = titleText;

    const count = document.createElement("span");
    count.className = "mypage-application-count";
    count.textContent = "0件";
    title.append(count);

    const description = document.createElement("p");
    description.textContent = descriptionText;

    head.append(title, description);

    const state = document.createElement("p");
    state.className = "mypage-application-state";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.textContent = "読み込み中です。";

    const list = document.createElement("div");
    list.className = "mypage-application-list";

    section.append(head, state, list);
    return { section, state, list, emptyText, count };
  }

  function createApplicationsPanel() {
    const container = document.createElement("div");
    container.className = "mypage-applications";
    container.dataset.mypageApplicationsPanel = "";

    const gm = createApplicationSection(
      "GM予定",
      "本人がGMとして公開している依頼書です。admin管理対象とは分けて表示します。",
      "現在、GM予定の依頼書はありません。"
    );

    const pending = createApplicationSection(
      "参加申請中",
      "参加希望コメントを送信済みで、GMの確認待ち、またはキャンセル待ちのセッションです。",
      "現在、参加申請中のセッションはありません。"
    );

    const accepted = createApplicationSection(
      "参加予定",
      "GMに承認された参加予定セッションです。",
      "現在、参加予定のセッションはありません。"
    );

    container.append(gm.section, pending.section, accepted.section);
    return {
      container,
      gm,
      pending,
      accepted,
      counts: { gm: 0, pending: 0, accepted: 0 },
      summaryDetails: null
    };
  }

  function setApplicationSectionState(section, message, options = {}) {
    section.list.replaceChildren();
    section.state.textContent = message;
    section.state.hidden = false;
    section.state.classList.toggle("is-error", Boolean(options.error));
  }

  function setApplicationSectionCount(section, count) {
    if (section && section.count) section.count.textContent = `${count}件`;
  }

  function setApplicationsLoading(panel) {
    setApplicationSectionState(panel.gm, "読み込み中です。");
    setApplicationSectionState(panel.pending, "読み込み中です。");
    setApplicationSectionState(panel.accepted, "読み込み中です。");
    setScheduleSummary(panel, "読み込み中");
  }

  function getApplicationUpdatedAt(application) {
    return formatApplicationUpdatedAt((application && application.updated_at) || (application && application.created_at));
  }

  function createApplicationDetailLink(session) {
    const link = document.createElement("a");
    link.className = "button mypage-application-detail-link";
    link.href = `session-detail.html?id=${encodeURIComponent(session.id)}`;
    link.textContent = "詳細を見る";
    return link;
  }

  function createGmManageLink(session) {
    const link = document.createElement("a");
    link.className = "button mypage-application-detail-link";
    link.href = `session-post.html?id=${encodeURIComponent(session.id)}#my-sessions`;
    link.textContent = "編集・管理";
    return link;
  }

  function createGmSessionCard(session) {
    const card = document.createElement("article");
    card.className = "mypage-application-card mypage-gm-session-card";

    const head = document.createElement("div");
    head.className = "mypage-application-card-head";

    const title = document.createElement("h4");
    title.textContent = getSessionTitle(session);

    const badge = document.createElement("span");
    badge.className = "tag";
    badge.textContent = getSessionStatusLabel(session.status);

    head.append(title, badge, createApplicationDetailLink(session), createGmManageLink(session));

    const meta = document.createElement("dl");
    meta.className = "mypage-application-meta";
    meta.append(
      createMetaItem("日付", formatSessionDate(session)),
      createMetaItem("開始時刻", formatSessionStartTime(session)),
      createMetaItem("GM", String(session.gmName || "GM未設定").trim() || "GM未設定"),
      createMetaItem("セッション状態", getSessionStatusLabel(session.status))
    );

    card.append(head, meta);
    return card;
  }

  function createApplicationCard(item) {
    const { application, session } = item;
    const card = document.createElement("article");
    card.className = "mypage-application-card";

    const head = document.createElement("div");
    head.className = "mypage-application-card-head";

    const title = document.createElement("h4");
    title.textContent = session ? getSessionTitle(session) : "非公開または未同期のセッション";

    const badge = document.createElement("span");
    badge.className = "tag";
    badge.textContent = getApplicationStatusLabel(application.status);

    head.append(title, badge);

    if (session) {
      head.append(createApplicationDetailLink(session));
    }

    const meta = document.createElement("dl");
    meta.className = "mypage-application-meta";

    if (session) {
      meta.append(
        createMetaItem("日付", formatSessionDate(session)),
        createMetaItem("開始時刻", formatSessionStartTime(session)),
        createMetaItem("GM", String(session.gmName || "GM未設定").trim() || "GM未設定"),
        createMetaItem("セッション状態", getSessionStatusLabel(session.status)),
        createMetaItem("申請ステータス", getApplicationStatusLabel(application.status)),
        createMetaItem("更新日時", getApplicationUpdatedAt(application))
      );
    } else {
      meta.append(
        createMetaItem("申請ステータス", getApplicationStatusLabel(application.status)),
        createMetaItem("更新日時", getApplicationUpdatedAt(application))
      );
    }

    card.append(head, meta);

    return card;
  }

  function getApplicationSortKey(item) {
    if (item.session) {
      return `${formatSessionDate(item.session)}T${formatSessionStartTime(item.session)}`;
    }
    return `9999-99-99T${getApplicationUpdatedAt(item.application)}`;
  }

  function sortApplicationItems(items) {
    return items.sort((a, b) => {
      const keyA = getApplicationSortKey(a);
      const keyB = getApplicationSortKey(b);
      if (keyA !== keyB) return keyA.localeCompare(keyB, "ja");
      const titleA = a.session ? getSessionTitle(a.session) : "";
      const titleB = b.session ? getSessionTitle(b.session) : "";
      return titleA.localeCompare(titleB, "ja");
    });
  }

  function renderApplicationItems(section, items) {
    section.list.replaceChildren();
    section.state.classList.remove("is-error");
    setApplicationSectionCount(section, items.length);

    if (!items.length) {
      section.state.textContent = section.emptyText;
      section.state.hidden = false;
      return;
    }

    section.state.hidden = true;
    sortApplicationItems(items).forEach((item) => {
      section.list.append(createApplicationCard(item));
    });
  }

  function renderGmSessionItems(section, sessions) {
    section.list.replaceChildren();
    section.state.classList.remove("is-error");
    setApplicationSectionCount(section, sessions.length);

    if (!sessions.length) {
      section.state.textContent = section.emptyText;
      section.state.hidden = false;
      return;
    }

    section.state.hidden = true;
    sessions
      .slice()
      .sort((a, b) => `${formatSessionDate(a)}T${formatSessionStartTime(a)}`.localeCompare(`${formatSessionDate(b)}T${formatSessionStartTime(b)}`, "ja"))
      .forEach((session) => {
        section.list.append(createGmSessionCard(session));
      });
  }

  function setScheduleSummary(panel, overrideText = "") {
    if (!panel || !panel.summaryDetails) return;
    const counts = panel.counts || { gm: 0, pending: 0, accepted: 0 };
    const text = overrideText || `GM ${counts.gm} / 申請中 ${counts.pending} / 参加予定 ${counts.accepted}`;
    setMypageDetailsMeta(panel.summaryDetails, text);
  }

  function renderApplications(panel, applications, sessionsById) {
    const grouped = {
      pending: [],
      accepted: []
    };

    applications.forEach((application) => {
      const group = getApplicationGroup(application);
      if (!group) return;

      const sessionId = String(application && application.session_id ? application.session_id : "").trim();
      const session = sessionsById.get(sessionId) || null;
      if (group === "accepted" && isEndedSession(session)) return;

      grouped[group].push({ application, session });
    });

    renderApplicationItems(panel.pending, grouped.pending);
    renderApplicationItems(panel.accepted, grouped.accepted);
    panel.counts.pending = grouped.pending.length;
    panel.counts.accepted = grouped.accepted.length;
    setScheduleSummary(panel);
  }

  function showApplicationsLoadFailure(panel, error) {
    const message = "申請情報を取得できませんでした。時間を置いて再度お試しください。";
    setApplicationSectionState(panel.gm, message, { error: true });
    setApplicationSectionState(panel.pending, message, { error: true });
    setApplicationSectionState(panel.accepted, message, { error: true });
    setScheduleSummary(panel, "読み込み失敗");

    if (error) {
      console.warn("mypage applications load failed", {
        code: error?.code || "unknown",
        name: error?.name || "unknown",
        status: error?.status || "unknown"
      });
    }
  }

  function normalizePublicSessionRow(row) {
    return {
      id: String(row && row.id ? row.id : "").trim(),
      title: String(row && row.title ? row.title : "").trim(),
      date: String(row && row.date ? row.date : "").trim(),
      startTime: String(row && row.start_time ? row.start_time : "").trim(),
      gmName: String(row && row.gm_name ? row.gm_name : "").trim(),
      status: String(row && row.status ? row.status : "").trim(),
      visibility: String(row && row.visibility ? row.visibility : "").trim()
    };
  }

  async function fetchPublicSessionsMap(client) {
    const { data, error } = await client
      .from("sessions")
      .select(PUBLIC_SESSION_SELECT_COLUMNS)
      .eq("visibility", "public");
    if (error) throw error;

    const sessions = Array.isArray(data) ? data.map(normalizePublicSessionRow) : [];
    const map = new Map();
    sessions.filter(isPublicSession).forEach((session) => {
      map.set(session.id, session);
    });
    return map;
  }

  async function fetchOwnGmSessions(client, session) {
    const { data, error } = await client
      .from("sessions")
      .select(PUBLIC_SESSION_SELECT_COLUMNS)
      .eq("gm_user_id", session.user.id)
      .eq("visibility", "public");

    if (error) throw error;
    return (Array.isArray(data) ? data.map(normalizePublicSessionRow) : [])
      .filter((item) => isVisibleScheduleSession(item) && !isEndedSession(item) && !isClosedMarkedSession(item));
  }

  async function fetchOwnApplications(client, session) {
    const { data, error } = await client
      .from("session_applications")
      .select(APPLICATION_SELECT_COLUMNS)
      .eq("user_id", session.user.id)
      .in("status", APPLICATION_STATUSES)
      .order("updated_at", { ascending: false });

    if (error) throw error;
    return Array.isArray(data) ? data : [];
  }

  async function loadApplications(client, panel, knownSession) {
    setApplicationsLoading(panel);

    try {
      const session = await getActiveSession(client, knownSession);
      if (!session) {
        renderGmSessionItems(panel.gm, []);
        renderApplicationItems(panel.pending, []);
        renderApplicationItems(panel.accepted, []);
        panel.counts = { gm: 0, pending: 0, accepted: 0 };
        setScheduleSummary(panel);
        return;
      }

      const [gmSessions, applications, sessionsById] = await Promise.all([
        fetchOwnGmSessions(client, session),
        fetchOwnApplications(client, session),
        fetchPublicSessionsMap(client)
      ]);

      if (!panel.container.isConnected) return;
      panel.counts.gm = gmSessions.length;
      renderGmSessionItems(panel.gm, gmSessions);
      renderApplications(panel, applications, sessionsById);
    } catch (error) {
      if (!panel.container.isConnected) return;
      showApplicationsLoadFailure(panel, error);
    }
  }

  function setFormBusy(form, busy, busyText, readyText) {
    const controls = form.querySelectorAll("input, button");
    controls.forEach((control) => {
      control.disabled = busy;
    });

    const submit = form.querySelector("[data-mypage-form-submit]");
    if (submit) submit.textContent = busy ? busyText : readyText;
  }

  function normalizeDisplayName(value) {
    return String(value || "").trim();
  }

  function countDisplayNameCharacters(value) {
    return Array.from(value).length;
  }

  function normalizeAvatarPath(value) {
    const text = String(value || "").trim();
    if (!text || text.includes("://") || text.startsWith("/") || text.includes("..") || text.includes("//")) {
      return "";
    }
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[A-Za-z0-9._-]+\.(png|jpg|jpeg|webp)$/i.test(text)
      ? text
      : "";
  }

  function normalizeAvatarUpdatedAt(value) {
    return String(value || "").trim();
  }

  function getAvatarInitial(displayName) {
    const text = normalizeDisplayName(displayName);
    return Array.from(text || "？")[0] || "？";
  }

  function getAvatarPublicUrl(client, avatarPath, avatarUpdatedAt) {
    const path = normalizeAvatarPath(avatarPath);
    if (!client || !path) return "";

    const { data } = client.storage.from(AVATAR_BUCKET).getPublicUrl(path);
    const publicUrl = String(data?.publicUrl || "").trim();
    if (!publicUrl) return "";

    const cacheKey = normalizeAvatarUpdatedAt(avatarUpdatedAt);
    if (!cacheKey) return publicUrl;

    try {
      const url = new URL(publicUrl);
      url.searchParams.set("v", cacheKey);
      return url.toString();
    } catch {
      return `${publicUrl}${publicUrl.includes("?") ? "&" : "?"}v=${encodeURIComponent(cacheKey)}`;
    }
  }

  function normalizeAvatarProfileRow(row) {
    return {
      displayName: normalizeDisplayName(row && row.display_name),
      avatarPath: normalizeAvatarPath(row && row.avatar_path),
      avatarUpdatedAt: normalizeAvatarUpdatedAt(row && row.avatar_updated_at)
    };
  }

  function createAvatarFilePath(session, file) {
    const userId = String(session?.user?.id || "").trim();
    const extension = AVATAR_EXTENSION_BY_TYPE[file?.type] || "";
    if (!userId || !extension) return "";
    return `${userId}/avatar-${Date.now()}.${extension}`;
  }

  function validateAvatarFile(file) {
    if (!file) {
      return { ok: false, message: "アイコン画像を選択してください。" };
    }
    if (!AVATAR_ALLOWED_TYPES.has(file.type)) {
      return { ok: false, message: "png / jpeg / webp の画像を選択してください。" };
    }
    if (file.size > AVATAR_MAX_BYTES) {
      return { ok: false, message: "アイコン画像は1MB以下にしてください。" };
    }
    return { ok: true };
  }

  function normalizeDiscordId(value) {
    return String(value || "").trim();
  }

  function normalizeDiscordUserIdInput(value) {
    const text = normalizeDiscordId(value);
    if (!text) return { valid: true, value: "" };
    if (DISCORD_USER_ID_PATTERN.test(text)) return { valid: true, value: text };

    const mentionMatch = text.match(DISCORD_MENTION_INPUT_PATTERN);
    if (mentionMatch) return { valid: true, value: mentionMatch[1] };

    return { valid: false, value: text };
  }

  function countDiscordIdCharacters(value) {
    return Array.from(value).length;
  }

  function hasLineBreak(value) {
    return /[\r\n]/.test(String(value || ""));
  }

  function normalizePcName(value) {
    return String(value || "").trim();
  }

  function countPcNameCharacters(value) {
    return Array.from(String(value || "")).length;
  }

  function validatePcName(value) {
    const rawValue = String(value || "");
    const pcName = normalizePcName(rawValue);
    if (!pcName) {
      return {
        valid: false,
        message: "PC名を入力してください。"
      };
    }
    if (hasLineBreak(rawValue)) {
      return {
        valid: false,
        message: "PC名に改行は使えません。"
      };
    }
    if (countPcNameCharacters(pcName) > PC_NAME_MAX_LENGTH) {
      return {
        valid: false,
        message: `PC名は${PC_NAME_MAX_LENGTH}文字以内で入力してください。`
      };
    }
    return {
      valid: true,
      value: pcName
    };
  }

  function redactSensitiveText(value) {
    return String(value ?? "")
      .replace(/\b(?:application_id|owner_user_id|selected_character_id|user_id|email|token|secret)\b/gi, "[非表示]")
      .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[非表示]")
      .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[非表示]")
      .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, "[非表示]")
      .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[非表示]")
      .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[非表示]");
  }

  function normalizeTemplateType(value) {
    const templateType = String(value || "").trim().toLowerCase();
    return TEMPLATE_TYPE_VALUES.has(templateType) ? templateType : "";
  }

  function getTemplateTypeLabel(value) {
    const templateType = normalizeTemplateType(value);
    const option = TEMPLATE_TYPE_OPTIONS.find((item) => item.value === templateType);
    return option?.label || "その他";
  }

  function getTemplateTypeNote(value) {
    const templateType = normalizeTemplateType(value);
    const option = TEMPLATE_TYPE_OPTIONS.find((item) => item.value === templateType);
    return option?.note || "";
  }

  function getTemplateVariableHelpItems(value) {
    const templateType = normalizeTemplateType(value);
    return TEMPLATE_VARIABLE_HELP_BY_TYPE[templateType] || [];
  }

  function getTemplateExamples(value) {
    const templateType = normalizeTemplateType(value);
    return TEMPLATE_EXAMPLES_BY_TYPE[templateType] || [];
  }

  function normalizeDiscordMentionMode(value) {
    const text = String(value || "").trim();
    return DISCORD_MENTION_MODES.has(text) ? text : "";
  }

  function normalizeTemplateName(value) {
    return redactSensitiveText(value).replace(/[\r\n]+/g, " ").trim();
  }

  function normalizeTemplateBody(value) {
    return redactSensitiveText(value);
  }

  function countTemplateCharacters(value) {
    return Array.from(String(value || "")).length;
  }

  function isValueInOptions(value, options) {
    return options.some((option) => option.value === value);
  }

  function normalizeSessionPostSelectValue(value, options, fallback) {
    const text = String(value || "").trim();
    return isValueInOptions(text, options) ? text : fallback;
  }

  function normalizeSessionPostIntegerText(value) {
    const text = String(value ?? "").trim();
    if (!text) return "";
    const number = Number(text);
    return Number.isInteger(number) && number >= 0 ? String(number) : text;
  }

  function normalizeDateTimeLocalText(value) {
    const text = String(value ?? "").trim().replace(" ", "T");
    const match = text.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
    return match ? `${match[1]}T${match[2]}` : text;
  }

  function createDefaultSessionPostTemplateFields() {
    return { ...SESSION_POST_TEMPLATE_DEFAULT_FIELDS };
  }

  function normalizeSessionPostTemplateFields(source = {}) {
    const fields = createDefaultSessionPostTemplateFields();
    fields.p_title = redactSensitiveText(source.p_title).replace(/[\r\n]+/g, " ").trim();
    fields.p_start_at = normalizeDateTimeLocalText(source.p_start_at);
    fields.p_end_at = normalizeDateTimeLocalText(source.p_end_at);
    fields.p_application_deadline = normalizeDateTimeLocalText(source.p_application_deadline);
    fields.p_session_type = normalizeSessionPostSelectValue(source.p_session_type, SESSION_POST_TYPE_OPTIONS, fields.p_session_type);
    fields.p_session_tool = redactSensitiveText(source.p_session_tool).replace(/[\r\n]+/g, " ").trim();
    fields.p_player_min = normalizeSessionPostIntegerText(source.p_player_min);
    fields.p_player_max = normalizeSessionPostIntegerText(source.p_player_max);
    fields.p_visibility = normalizeSessionPostSelectValue(source.p_visibility, SESSION_POST_VISIBILITY_OPTIONS, fields.p_visibility);
    fields.p_status = normalizeSessionPostSelectValue(source.p_status, SESSION_POST_STATUS_OPTIONS, fields.p_status);
    fields.discord_mention_mode = normalizeDiscordMentionMode(source.discord_mention_mode);
    fields.p_summary = redactSensitiveText(source.p_summary).trim();
    return fields;
  }

  function parseSessionPostTemplateBody(value) {
    const text = normalizeTemplateBody(value).trim();
    if (!text) return null;

    try {
      const parsed = JSON.parse(text);
      const sourceFields = parsed
        && parsed.format === SESSION_POST_TEMPLATE_FORMAT
        && parsed.fields
        && typeof parsed.fields === "object"
        ? parsed.fields
        : null;
      return sourceFields ? normalizeSessionPostTemplateFields(sourceFields) : null;
    } catch {
      return null;
    }
  }

  function isSessionPostTemplateBody(value) {
    return Boolean(parseSessionPostTemplateBody(value));
  }

  function buildSessionPostTemplateBody(fields) {
    return JSON.stringify({
      format: SESSION_POST_TEMPLATE_FORMAT,
      fields: normalizeSessionPostTemplateFields(fields)
    });
  }

  function validateSessionPostTemplateFields(fields) {
    const normalized = normalizeSessionPostTemplateFields(fields);

    if (countTemplateCharacters(normalized.p_title) > SESSION_POST_TITLE_MAX_LENGTH) {
      return { valid: false, message: `タイトルは${SESSION_POST_TITLE_MAX_LENGTH}文字以内で入力してください。` };
    }
    if (countTemplateCharacters(normalized.p_session_tool) > SESSION_POST_TOOL_MAX_LENGTH) {
      return { valid: false, message: `開催場所は${SESSION_POST_TOOL_MAX_LENGTH}文字以内で入力してください。` };
    }
    if (countTemplateCharacters(normalized.p_summary) > SESSION_POST_SUMMARY_MAX_LENGTH) {
      return { valid: false, message: `概要は${SESSION_POST_SUMMARY_MAX_LENGTH}文字以内で入力してください。` };
    }

    const dateTimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/;
    const dateTimeValues = [
      ["開始日時", normalized.p_start_at],
      ["終了日時", normalized.p_end_at],
      ["申請締切", normalized.p_application_deadline]
    ];
    for (const [label, value] of dateTimeValues) {
      if (value && !dateTimePattern.test(value)) {
        return { valid: false, message: `${label}の形式を確認してください。` };
      }
    }
    if (normalized.p_start_at && normalized.p_end_at && normalized.p_end_at <= normalized.p_start_at) {
      return { valid: false, message: "終了日時は開始日時より後にしてください。" };
    }

    const playerMin = normalized.p_player_min ? Number(normalized.p_player_min) : null;
    const playerMax = normalized.p_player_max ? Number(normalized.p_player_max) : null;
    if (
      (normalized.p_player_min && (!Number.isInteger(playerMin) || playerMin < 0))
      || (normalized.p_player_max && (!Number.isInteger(playerMax) || playerMax < 0))
    ) {
      return { valid: false, message: "募集人数は0以上の整数で入力してください。" };
    }
    if (Number.isInteger(playerMin) && Number.isInteger(playerMax) && playerMin > playerMax) {
      return { valid: false, message: "募集人数の範囲を確認してください。" };
    }

    return { valid: true, fields: normalized };
  }

  function assertOnlyTemplatePresetFields(rows) {
    const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
    for (const row of list) {
      if (!row || typeof row !== "object") continue;
      for (const key of Object.keys(row)) {
        if (!TEMPLATE_PRESET_FIELD_NAMES.has(String(key).toLowerCase())) {
          throw new Error("template-preset-field-returned");
        }
      }
    }
  }

  function normalizeTemplatePresetRow(row) {
    const templateType = normalizeTemplateType(row && row.template_type);
    return {
      templateId: String(row && row.template_id ? row.template_id : "").trim(),
      templateName: normalizeTemplateName(row && row.template_name) || "名称未設定",
      templateType: templateType || "other",
      templateBody: normalizeTemplateBody(row && row.template_body),
      createdAt: String(row && row.created_at ? row.created_at : "").trim(),
      updatedAt: String(row && row.updated_at ? row.updated_at : "").trim()
    };
  }

  function normalizeTemplatePresetRows(rows) {
    return (Array.isArray(rows) ? rows : [])
      .map(normalizeTemplatePresetRow)
      .filter((row) => row.templateId && row.templateType);
  }

  function validateTemplatePresetInput(nameValue, typeValue, bodyValue) {
    const rawName = String(nameValue || "");
    const templateName = normalizeTemplateName(rawName);
    const templateType = normalizeTemplateType(typeValue);
    const templateBody = normalizeTemplateBody(bodyValue);
    const trimmedBody = templateBody.trim();

    if (!templateName) {
      return { valid: false, message: "テンプレート名を入力してください。" };
    }
    if (hasLineBreak(rawName)) {
      return { valid: false, message: "テンプレート名に改行は使えません。" };
    }
    if (countTemplateCharacters(templateName) > TEMPLATE_NAME_MAX_LENGTH) {
      return { valid: false, message: `テンプレート名は${TEMPLATE_NAME_MAX_LENGTH}文字以内で入力してください。` };
    }
    if (!templateType) {
      return { valid: false, message: "テンプレート種別を選んでください。" };
    }
    if (!trimmedBody) {
      return { valid: false, message: "テンプレート本文を入力してください。" };
    }
    if (countTemplateCharacters(templateBody) > TEMPLATE_BODY_MAX_LENGTH) {
      return { valid: false, message: `テンプレート本文は${TEMPLATE_BODY_MAX_LENGTH}文字以内で入力してください。` };
    }
    if (templateType === "session_post" && !isSessionPostTemplateBody(templateBody)) {
      return {
        valid: false,
        message: "依頼書用テンプレートとして保存できない内容です。"
      };
    }

    return {
      valid: true,
      templateName,
      templateType,
      templateBody
    };
  }

  function collectSessionPostTemplateFields(panel) {
    const fields = panel.sessionPostFields || {};
    return {
      p_title: fields.titleInput?.value || "",
      p_start_at: fields.startAtInput?.value || "",
      p_end_at: fields.endAtInput?.value || "",
      p_application_deadline: fields.applicationDeadlineInput?.value || "",
      p_session_type: fields.sessionTypeSelect?.value || "",
      p_session_tool: fields.sessionToolInput?.value || "",
      p_player_min: fields.playerMinInput?.value || "",
      p_player_max: fields.playerMaxInput?.value || "",
      p_visibility: fields.visibilitySelect?.value || "",
      p_status: fields.statusSelect?.value || "",
      discord_mention_mode: fields.discordMentionSelect?.value || "",
      p_summary: fields.summaryTextarea?.value || ""
    };
  }

  function buildTemplatePresetInput(panel) {
    const templateType = normalizeTemplateType(panel.typeSelect.value);

    if (templateType === "session_post") {
      const fieldsValidation = validateSessionPostTemplateFields(collectSessionPostTemplateFields(panel));
      if (!fieldsValidation.valid) {
        return fieldsValidation;
      }

      const templateBody = buildSessionPostTemplateBody(fieldsValidation.fields);
      return validateTemplatePresetInput(panel.nameInput.value, templateType, templateBody);
    }

    return validateTemplatePresetInput(panel.nameInput.value, templateType, panel.bodyTextarea.value);
  }

  function getTemplateOperationErrorMessage(error) {
    const text = [
      error && error.message,
      error && error.code,
      error && error.details,
      error && error.hint
    ].filter(Boolean).join(" ").toLowerCase();

    if (text.includes("login_required") || text.includes("28000")) {
      return "ログインが必要です。";
    }
    if (text.includes("template_not_found") || text.includes("not_found") || text.includes("p0002")) {
      return "対象のテンプレートが見つかりません。";
    }
    if (text.includes("not_allowed") || text.includes("42501") || text.includes("permission")) {
      return "このテンプレートを操作する権限がありません。";
    }
    if (
      text.includes("template_name") ||
      text.includes("template_body") ||
      text.includes("template_type") ||
      text.includes("22023")
    ) {
      return "テンプレートの入力内容を確認してください。";
    }
    return "テンプレートの保存に失敗しました。";
  }

  async function queryTemplatePresets(client) {
    const { data, error } = await client.rpc(TEMPLATE_PRESETS_RPC);
    if (error) throw error;
    const rows = Array.isArray(data) ? data : [];
    assertOnlyTemplatePresetFields(rows);
    return rows;
  }

  async function createTemplatePreset(client, preset) {
    const { data, error } = await client.rpc(TEMPLATE_CREATE_RPC, {
      p_template_name: preset.templateName,
      p_template_type: preset.templateType,
      p_template_body: preset.templateBody
    });
    if (error) throw error;
    assertOnlyTemplatePresetFields(data);
    return Array.isArray(data) ? data[0] || null : data || null;
  }

  async function updateTemplatePreset(client, preset) {
    const { data, error } = await client.rpc(TEMPLATE_UPDATE_RPC, {
      p_template_id: preset.templateId,
      p_template_name: preset.templateName,
      p_template_type: preset.templateType,
      p_template_body: preset.templateBody,
      p_is_active: true
    });
    if (error) throw error;
    assertOnlyTemplatePresetFields(data);
    return Array.isArray(data) ? data[0] || null : data || null;
  }

  async function deactivateTemplatePreset(client, templateId) {
    const targetTemplateId = String(templateId || "").trim();
    if (!targetTemplateId) throw new Error("template-preset-target-missing");

    const { data, error } = await client.rpc(TEMPLATE_DEACTIVATE_RPC, {
      p_template_id: targetTemplateId
    });
    if (error) throw error;
    assertOnlyTemplatePresetFields(data);
  }

  function getPlayerCharacterErrorMessage(error) {
    const text = [
      error && error.message,
      error && error.code,
      error && error.details,
      error && error.hint
    ].filter(Boolean).join(" ").toLowerCase();

    if (text.includes("login_required") || text.includes("28000")) {
      return "ログインが必要です。";
    }
    if (text.includes("character_not_found") || text.includes("not_found") || text.includes("p0002")) {
      return "対象のPC名が見つかりません。";
    }
    if (text.includes("not_allowed") || text.includes("42501") || text.includes("permission")) {
      return "このPC名を操作する権限がありません。";
    }
    if (
      text.includes("invalid_pc_name") ||
      text.includes("pc_name_required") ||
      text.includes("pc_name_too_long") ||
      text.includes("pc_name_invalid") ||
      text.includes("22023")
    ) {
      return "PC名の形式を確認してください。";
    }
    return "PC名の保存に失敗しました。";
  }

  function normalizePlayerCharacterRow(row) {
    return {
      characterId: String(row && row.character_id ? row.character_id : "").trim(),
      pcName: normalizePcName(row && row.pc_name),
      isDefault: Boolean(row && row.is_default),
      isActive: row && Object.prototype.hasOwnProperty.call(row, "is_active") ? Boolean(row.is_active) : true
    };
  }

  function getActivePlayerCharacters(panel) {
    return (panel.records || []).filter((record) => record.characterId && record.isActive);
  }

  async function getActiveSession(client, knownSession) {
    if (knownSession && knownSession.user && knownSession.user.id) {
      return knownSession;
    }

    const { data, error } = await client.auth.getSession();
    if (error || !data || !data.session || !data.session.user || !data.session.user.id) {
      return null;
    }
    return data.session;
  }

  function createAuthModeSwitch(client, elements, activeMode) {
    const switcher = document.createElement("div");
    switcher.className = "actions";
    switcher.setAttribute("role", "tablist");
    switcher.setAttribute("aria-label", "アカウント操作の切り替え");

    const modes = [
      { mode: "login", label: "ログイン" },
      { mode: "signup", label: "新規登録" }
    ];

    modes.forEach(({ mode, label }) => {
      const button = document.createElement("button");
      button.className = mode === activeMode ? "button primary" : "button";
      button.type = "button";
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", String(mode === activeMode));
      button.textContent = label;
      button.addEventListener("click", () => {
        if (mode !== activeMode) renderAnonymous(client, elements, "", mode);
      });
      switcher.append(button);
    });

    return switcher;
  }

  function renderAnonymous(client, elements, message, mode = "login", options = {}) {
    ensureAuthElements(elements);
    removeNavLogoutButton();
    resetHeaderNotifications();
    const isResetMode = mode === "reset";
    setStatus(
      elements,
      isResetMode
        ? "パスワード再設定"
        : "ログインすると、今後ここで参加申請状況や参加予定を確認できるようになります。",
      isResetMode
        ? "登録済みのメールアドレス宛に、パスワード再設定用のリンクを送信します。"
        : ""
    );
    clearContent(elements);

    if (mode !== "reset") {
      elements.content.append(createAuthModeSwitch(client, elements, mode));
    }

    if (mode === "reset") {
      renderPasswordResetForm(client, elements, options.email || "");
    } else if (mode === "signup") {
      renderSignupForm(client, elements);
    } else {
      renderLoginForm(client, elements);
    }

    setMessage(elements, message || "");
  }

  function renderLoginForm(client, elements) {
    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypageLoginForm = "";
    form.noValidate = true;

    const emailInput = document.createElement("input");
    emailInput.type = "email";
    emailInput.name = "email";
    emailInput.autocomplete = "username";
    emailInput.required = true;

    const passwordInput = document.createElement("input");
    passwordInput.type = "password";
    passwordInput.name = "password";
    passwordInput.autocomplete = "current-password";
    passwordInput.required = true;

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "submit";
    submit.dataset.mypageLoginSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    const captcha = createTurnstileControl("login");
    submit.textContent = "ログイン";

    form.append(
      createInputField("メールアドレス", emailInput),
      createInputField("パスワード", passwordInput),
      captcha.element,
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handleLogin(client, elements, form, captcha);
    });

    const forgotActions = document.createElement("div");
    forgotActions.className = "actions";

    const forgotPassword = document.createElement("button");
    forgotPassword.className = "button";
    forgotPassword.type = "button";
    forgotPassword.dataset.mypagePasswordResetOpen = "";
    forgotPassword.textContent = "パスワードを忘れた方はこちら";
    forgotPassword.addEventListener("click", () => {
      renderAnonymous(client, elements, "", "reset", { email: emailInput.value.trim() });
    });

    forgotActions.append(forgotPassword);
    elements.content.append(form, forgotActions);
    captcha.mount();
  }

  function renderSignupForm(client, elements) {
    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypageSignupForm = "";
    form.noValidate = true;

    const displayNameInput = document.createElement("input");
    displayNameInput.type = "text";
    displayNameInput.name = "displayName";
    displayNameInput.autocomplete = "nickname";
    displayNameInput.required = true;

    const emailInput = document.createElement("input");
    emailInput.type = "email";
    emailInput.name = "email";
    emailInput.autocomplete = "username";
    emailInput.required = true;

    const passwordInput = document.createElement("input");
    passwordInput.type = "password";
    passwordInput.name = "password";
    passwordInput.autocomplete = "new-password";
    passwordInput.required = true;

    const passwordConfirmInput = document.createElement("input");
    passwordConfirmInput.type = "password";
    passwordConfirmInput.name = "passwordConfirm";
    passwordConfirmInput.autocomplete = "new-password";
    passwordConfirmInput.required = true;

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "submit";
    submit.dataset.mypageSignupSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    const captcha = createTurnstileControl("signup");
    submit.textContent = "登録する";

    form.append(
      createInputField("ユーザー名", displayNameInput),
      createInputField("メールアドレス", emailInput),
      createInputField("パスワード", passwordInput),
      createInputField("パスワード確認", passwordConfirmInput),
      captcha.element,
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handleSignup(client, elements, form, captcha);
    });

    elements.content.append(form);
    captcha.mount();
  }

  function renderPasswordResetForm(client, elements, initialEmail = "") {
    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypagePasswordResetForm = "";
    form.noValidate = true;

    const emailInput = document.createElement("input");
    emailInput.type = "email";
    emailInput.name = "email";
    emailInput.autocomplete = "username";
    emailInput.required = true;
    emailInput.value = String(initialEmail || "").trim();

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "submit";
    submit.dataset.mypagePasswordResetSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    const captcha = createTurnstileControl("password-reset");
    submit.textContent = "再設定メールを送る";

    form.append(
      createInputField("メールアドレス", emailInput),
      captcha.element,
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handlePasswordReset(client, elements, form, captcha);
    });

    const actions = document.createElement("div");
    actions.className = "actions";

    const backToLogin = document.createElement("button");
    backToLogin.className = "button";
    backToLogin.type = "button";
    backToLogin.textContent = "ログインへ戻る";
    backToLogin.addEventListener("click", () => {
      renderAnonymous(client, elements);
    });

    actions.append(backToLogin);
    elements.content.append(form, actions);
    captcha.mount();
  }

  function createDisplayNameEditor(client, elements, session) {
    const container = document.createElement("div");
    container.dataset.mypageDisplayNamePanel = "";

    const current = document.createElement("p");
    current.className = "status";
    current.dataset.mypageDisplayNameCurrent = "";

    const currentLabel = document.createElement("span");
    currentLabel.textContent = "ユーザー名：";

    const currentValue = document.createElement("strong");
    currentValue.dataset.mypageDisplayNameCurrentValue = "";
    currentValue.textContent = "確認中";

    current.append(currentLabel, currentValue);

    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypageDisplayNameForm = "";
    form.noValidate = true;

    const displayNameInput = document.createElement("input");
    displayNameInput.type = "text";
    displayNameInput.name = "displayName";
    displayNameInput.autocomplete = "nickname";
    displayNameInput.required = true;
    displayNameInput.placeholder = "ユーザー名を入力";

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "button";
    submit.dataset.mypageDisplayNameSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    submit.disabled = true;
    submit.textContent = "保存";

    form.append(
      createInputField("ユーザー名", displayNameInput),
      submit
    );

    const editor = {
      container,
      current,
      currentValue,
      form,
      input: displayNameInput,
      submit,
      session,
      inputDirty: false
    };

    displayNameInput.addEventListener("input", () => {
      editor.inputDirty = true;
    });

    submit.addEventListener("click", (event) => {
      handleDisplayNameSave(client, elements, editor, event);
    });

    form.addEventListener("submit", (event) => {
      handleDisplayNameSave(client, elements, editor, event);
    });

    container.append(current, form);
    return editor;
  }

  function setDisplayNameEditorState(editor, displayName, options = {}) {
    const nextDisplayName = normalizeDisplayName(displayName);
    editor.currentValue.textContent = nextDisplayName || "未設定";

    if (!options.preserveDirtyInput || !editor.inputDirty) {
      editor.input.value = nextDisplayName;
      editor.inputDirty = false;
    }

    editor.input.disabled = false;
    editor.input.readOnly = false;
    editor.submit.disabled = false;
  }

  function setDisplayNameEditorError(editor) {
    editor.currentValue.textContent = "確認できませんでした";
    editor.input.disabled = false;
    editor.input.readOnly = false;
    editor.submit.disabled = false;
  }

  function showDisplayNameSaveFailure(elements, error) {
    setMessage(elements, "ユーザー名を保存できませんでした。\nしばらくしても続く場合は、管理者へお知らせください。");

    if (error) {
      console.warn("display_name update failed", {
        code: error?.code || "unknown",
        name: error?.name || "unknown"
      });
    }
  }

  async function loadDisplayName(client, editor) {
    try {
      const session = await getActiveSession(client, editor.session);
      if (!session) {
        setDisplayNameEditorError(editor);
        return;
      }

      const { data, error } = await client
        .from("public_profiles")
        .select("display_name")
        .eq("id", session.user.id)
        .single();

      if (error || !data || typeof data.display_name !== "string") {
        setDisplayNameEditorError(editor);
        return;
      }

      setDisplayNameEditorState(editor, data.display_name, { preserveDirtyInput: true });
    } catch (error) {
      setDisplayNameEditorError(editor);
    }
  }

  async function handleDisplayNameSave(client, elements, editor, event) {
    event?.preventDefault?.();

    const displayNameInput = editor.input;
    const nextDisplayName = normalizeDisplayName(displayNameInput ? displayNameInput.value : "");

    if (!nextDisplayName) {
      setMessage(elements, "ユーザー名を入力してください。");
      return;
    }

    if (countDisplayNameCharacters(nextDisplayName) > DISPLAY_NAME_MAX_LENGTH) {
      setMessage(elements, "ユーザー名は40文字以内で入力してください。");
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(editor.form, true, "保存中", "保存");
      const { data, error } = await client.rpc("update_display_name", {
        new_display_name: nextDisplayName
      });

      if (error) {
        showDisplayNameSaveFailure(elements, error);
        return;
      }

      const row = Array.isArray(data) ? data[0] : data;
      const savedDisplayName = normalizeDisplayName(row && row.display_name ? row.display_name : nextDisplayName);
      editor.inputDirty = false;
      setDisplayNameEditorState(editor, savedDisplayName);
      setMessage(elements, "ユーザー名を保存しました。");
    } catch (error) {
      showDisplayNameSaveFailure(elements, error);
    } finally {
      if (editor.form.isConnected) setFormBusy(editor.form, false, "保存中", "保存");
    }
  }

  function normalizeMembershipStatus(status) {
    const normalized = typeof status === "string" ? status.trim().toLowerCase() : "";
    return MEMBERSHIP_STATUS_VALUES.has(normalized) ? normalized : "pending";
  }

  function getMembershipStatusView(status) {
    return MEMBERSHIP_STATUS_VIEWS[normalizeMembershipStatus(status)];
  }

  function getMembershipStatusRow(data) {
    return Array.isArray(data) ? data[0] : data;
  }

  function setMembershipPanelLoading(panel) {
    panel.badge.className = "mypage-membership-badge is-loading";
    panel.badge.textContent = "確認中";
    panel.message.textContent = "会員状態を確認しています。";
    panel.state.textContent = "";
    panel.state.hidden = true;
    panel.state.classList.remove("is-error");
  }

  function setMembershipPanelValue(panel, status) {
    const view = getMembershipStatusView(status);
    panel.badge.className = `mypage-membership-badge is-${view.tone}`;
    panel.badge.textContent = view.label;
    panel.message.textContent = view.message;
    panel.state.textContent = "";
    panel.state.hidden = true;
    panel.state.classList.remove("is-error");
  }

  function setMembershipPanelError(panel) {
    panel.badge.className = "mypage-membership-badge is-error";
    panel.badge.textContent = "確認不可";
    panel.message.textContent = "会員状態を確認できませんでした。";
    panel.state.textContent = "時間をおいて再度お試しください。";
    panel.state.hidden = false;
    panel.state.classList.add("is-error");
  }

  function createMembershipStatusPanel(session) {
    const container = document.createElement("section");
    container.className = "mypage-profile-panel mypage-membership-panel";
    container.dataset.mypageMembershipPanel = "";

    const head = document.createElement("div");
    head.className = "mypage-profile-panel-head";

    const title = document.createElement("h3");
    title.textContent = "会員状態";

    const description = document.createElement("p");
    description.textContent = "コミュニティ承認の現在の状態です。";

    head.append(title, description);

    const card = document.createElement("div");
    card.className = "mypage-membership-card";

    const badge = document.createElement("span");
    badge.className = "mypage-membership-badge is-loading";
    badge.dataset.mypageMembershipBadge = "";

    const message = document.createElement("p");
    message.className = "mypage-membership-message";
    message.dataset.mypageMembershipMessage = "";

    const note = document.createElement("p");
    note.className = "mypage-profile-note mypage-membership-note";
    note.textContent = "この表示は案内です。主要機能の制限は今後の承認ゲートでサーバー側にも追加します。";

    const state = document.createElement("p");
    state.className = "mypage-profile-state";
    state.dataset.mypageMembershipState = "";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.hidden = true;

    card.append(badge, message, note, state);

    const panel = {
      container,
      badge,
      message,
      note,
      state,
      session
    };

    setMembershipPanelLoading(panel);
    container.append(head, card);
    return panel;
  }

  async function loadMembershipStatus(client, panel) {
    try {
      const session = await getActiveSession(client, panel.session);
      if (!session) {
        setMembershipPanelError(panel);
        return;
      }

      const { data, error } = await client.rpc("get_my_membership_status");
      if (error) {
        setMembershipPanelError(panel);
        return;
      }

      const row = getMembershipStatusRow(data);
      setMembershipPanelValue(panel, row && row.status);
    } catch {
      setMembershipPanelError(panel);
    }
  }

  function createAvatarEditor(client, elements, session) {
    const container = document.createElement("section");
    container.className = "mypage-profile-panel mypage-avatar-panel";
    container.dataset.mypageAvatarPanel = "";

    const head = document.createElement("div");
    head.className = "mypage-profile-panel-head";

    const title = document.createElement("h3");
    title.textContent = "アイコン画像";

    const description = document.createElement("p");
    description.textContent = "この画像は依頼書コメント等で公開表示されます。";

    head.append(title, description);

    const previewWrap = document.createElement("div");
    previewWrap.className = "mypage-avatar-preview-row";

    const preview = document.createElement("div");
    preview.className = "profile-avatar-preview is-default";
    preview.dataset.mypageAvatarPreview = "";
    preview.setAttribute("aria-label", "現在のアイコン");

    const currentText = document.createElement("p");
    currentText.className = "mypage-profile-note";
    currentText.dataset.mypageAvatarCurrent = "";
    currentText.textContent = "現在のアイコンを確認中です。";

    previewWrap.append(preview, currentText);

    const form = document.createElement("form");
    form.className = "calendar-form mypage-avatar-form";
    form.dataset.mypageAvatarForm = "";
    form.noValidate = true;

    const fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.name = "avatar";
    fileInput.accept = "image/png,image/jpeg,image/webp,.png,.jpg,.jpeg,.webp";

    const uploadButton = document.createElement("button");
    uploadButton.className = "button primary";
    uploadButton.type = "button";
    uploadButton.dataset.mypageAvatarUpload = "";
    uploadButton.textContent = "アップロード";

    const deleteButton = document.createElement("button");
    deleteButton.className = "button danger";
    deleteButton.type = "button";
    deleteButton.dataset.mypageAvatarDelete = "";
    deleteButton.textContent = "削除";
    deleteButton.disabled = true;

    const actions = document.createElement("div");
    actions.className = "mypage-avatar-actions";
    actions.append(uploadButton, deleteButton);

    const note = document.createElement("p");
    note.className = "mypage-profile-note";
    note.textContent = "png / jpeg / webp、1MB以下の画像を選択してください。";

    const state = document.createElement("p");
    state.className = "mypage-profile-state";
    state.dataset.mypageAvatarState = "";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.hidden = true;

    form.append(createInputField("画像ファイル", fileInput), actions);

    const editor = {
      container,
      preview,
      currentText,
      form,
      input: fileInput,
      uploadButton,
      deleteButton,
      state,
      session,
      displayName: "",
      avatarPath: "",
      avatarUpdatedAt: ""
    };

    uploadButton.addEventListener("click", (event) => {
      handleAvatarUpload(client, elements, editor, event);
    });

    deleteButton.addEventListener("click", (event) => {
      handleAvatarDelete(client, elements, editor, event);
    });

    form.addEventListener("submit", (event) => {
      handleAvatarUpload(client, elements, editor, event);
    });

    container.append(head, previewWrap, form, note, state);
    return editor;
  }

  function setAvatarPanelState(editor, message, options = {}) {
    editor.state.textContent = message || "";
    editor.state.hidden = !message;
    editor.state.classList.toggle("is-error", Boolean(options.error));
    editor.state.classList.toggle("is-warn", Boolean(options.warn));
  }

  function setAvatarPanelBusy(editor, busy) {
    editor.form.setAttribute("aria-busy", String(Boolean(busy)));
    editor.input.disabled = Boolean(busy);
    editor.uploadButton.disabled = Boolean(busy);
    editor.deleteButton.disabled = Boolean(busy || !editor.avatarPath);
  }

  function renderAvatarPreview(client, editor, profile) {
    editor.displayName = normalizeDisplayName(profile?.displayName || editor.displayName);
    editor.avatarPath = normalizeAvatarPath(profile?.avatarPath);
    editor.avatarUpdatedAt = normalizeAvatarUpdatedAt(profile?.avatarUpdatedAt);
    editor.preview.replaceChildren();

    const avatarUrl = getAvatarPublicUrl(client, editor.avatarPath, editor.avatarUpdatedAt);
    editor.preview.classList.toggle("is-default", !avatarUrl);

    if (avatarUrl) {
      const image = document.createElement("img");
      image.className = "profile-avatar-preview-image";
      image.src = avatarUrl;
      image.alt = `${editor.displayName || "ユーザー"}のアイコン`;
      image.loading = "lazy";
      image.decoding = "async";
      image.addEventListener("error", () => {
        editor.preview.classList.add("is-default");
        editor.preview.replaceChildren();
        const initial = document.createElement("span");
        initial.className = "profile-avatar-preview-initial";
        initial.textContent = getAvatarInitial(editor.displayName);
        editor.preview.append(initial);
        editor.currentText.textContent = "アイコン画像を読み込めませんでした。削除して初期表示へ戻せます。";
        editor.deleteButton.disabled = !editor.avatarPath;
      }, { once: true });
      editor.preview.append(image);
      editor.currentText.textContent = "現在のアイコンが設定されています。";
    } else {
      const initial = document.createElement("span");
      initial.className = "profile-avatar-preview-initial";
      initial.textContent = getAvatarInitial(editor.displayName);
      editor.preview.append(initial);
      editor.currentText.textContent = "アイコン未設定です。デフォルト表示が使われます。";
    }

    editor.deleteButton.disabled = !editor.avatarPath;
  }

  async function loadAvatarProfile(client, editor) {
    try {
      const session = await getActiveSession(client, editor.session);
      if (!session) {
        renderAvatarPreview(client, editor, {});
        setAvatarPanelState(editor, "ログイン状態を確認できませんでした。", { error: true });
        return;
      }

      const { data, error } = await client
        .from("public_profiles")
        .select("display_name,avatar_path,avatar_updated_at")
        .eq("id", session.user.id)
        .single();

      if (error || !data) {
        renderAvatarPreview(client, editor, {});
        setAvatarPanelState(editor, "アイコン情報を取得できませんでした。", { error: true });
        return;
      }

      renderAvatarPreview(client, editor, normalizeAvatarProfileRow(data));
      setAvatarPanelState(editor, "");
    } catch {
      renderAvatarPreview(client, editor, {});
      setAvatarPanelState(editor, "アイコン情報を取得できませんでした。", { error: true });
    }
  }

  async function handleAvatarUpload(client, elements, editor, event) {
    event?.preventDefault?.();

    const file = editor.input.files && editor.input.files[0] ? editor.input.files[0] : null;
    const validation = validateAvatarFile(file);
    if (!validation.ok) {
      setAvatarPanelState(editor, validation.message, { warn: true });
      return;
    }

    try {
      const session = await getActiveSession(client, editor.session);
      if (!session) {
        setAvatarPanelState(editor, "ログイン状態を確認できませんでした。", { error: true });
        return;
      }

      const nextPath = createAvatarFilePath(session, file);
      if (!nextPath) {
        setAvatarPanelState(editor, "アイコン画像の形式を確認してください。", { error: true });
        return;
      }

      setMessage(elements, "");
      setAvatarPanelState(editor, "アイコン画像をアップロードしています。");
      setAvatarPanelBusy(editor, true);

      const { error: uploadError } = await client.storage
        .from(AVATAR_BUCKET)
        .upload(nextPath, file, {
          cacheControl: "3600",
          contentType: file.type,
          upsert: true
        });

      if (uploadError) {
        setAvatarPanelState(editor, "アイコン画像をアップロードできませんでした。", { error: true });
        return;
      }

      const { data, error: rpcError } = await client.rpc("update_my_avatar_path", {
        new_avatar_path: nextPath
      });

      if (rpcError) {
        await client.storage.from(AVATAR_BUCKET).remove([nextPath]);
        setAvatarPanelState(editor, "アイコン情報を保存できませんでした。", { error: true });
        return;
      }

      const row = Array.isArray(data) ? data[0] : data;
      renderAvatarPreview(client, editor, normalizeAvatarProfileRow(row));
      editor.input.value = "";
      setAvatarPanelState(editor, "アイコン画像を保存しました。");
    } catch {
      setAvatarPanelState(editor, "アイコン画像を保存できませんでした。", { error: true });
    } finally {
      if (editor.container.isConnected) setAvatarPanelBusy(editor, false);
    }
  }

  async function handleAvatarDelete(client, elements, editor, event) {
    event?.preventDefault?.();

    const currentPath = normalizeAvatarPath(editor.avatarPath);
    if (!currentPath) {
      setAvatarPanelState(editor, "削除するアイコン画像はありません。", { warn: true });
      return;
    }

    if (!window.confirm("アイコン画像を削除しますか？")) return;

    try {
      setMessage(elements, "");
      setAvatarPanelState(editor, "アイコン画像を削除しています。");
      setAvatarPanelBusy(editor, true);

      const { error: removeError } = await client.storage.from(AVATAR_BUCKET).remove([currentPath]);
      if (removeError) {
        setAvatarPanelState(editor, "アイコン画像を削除できませんでした。", { error: true });
        return;
      }

      const { data, error: rpcError } = await client.rpc("clear_my_avatar_path");
      if (rpcError) {
        setAvatarPanelState(editor, "アイコン情報を初期化できませんでした。", { error: true });
        return;
      }

      const row = Array.isArray(data) ? data[0] : data;
      renderAvatarPreview(client, editor, normalizeAvatarProfileRow(row));
      editor.input.value = "";
      setAvatarPanelState(editor, "アイコン画像を削除しました。");
    } catch {
      setAvatarPanelState(editor, "アイコン画像を削除できませんでした。", { error: true });
    } finally {
      if (editor.container.isConnected) setAvatarPanelBusy(editor, false);
    }
  }

  function createDiscordIdEditor(client, elements, session) {
    const container = document.createElement("section");
    container.className = "mypage-profile-panel";
    container.dataset.mypageDiscordIdPanel = "";

    const head = document.createElement("div");
    head.className = "mypage-profile-panel-head";

    const title = document.createElement("h3");
    title.textContent = "DiscordユーザーID";

    const description = document.createElement("p");
    description.textContent = "GMが承認済み参加者を呼び出すために使用します。未登録でも参加申請は可能です。";

    head.append(title, description);

    const current = document.createElement("p");
    current.className = "status";
    current.dataset.mypageDiscordIdCurrent = "";

    const currentLabel = document.createElement("span");
    currentLabel.textContent = "DiscordユーザーID：";

    const currentValue = document.createElement("strong");
    currentValue.dataset.mypageDiscordIdCurrentValue = "";
    currentValue.textContent = "読み込み中";

    current.append(currentLabel, currentValue);

    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypageDiscordIdForm = "";
    form.noValidate = true;

    const discordIdInput = document.createElement("input");
    discordIdInput.type = "text";
    discordIdInput.name = "discordId";
    discordIdInput.autocomplete = "off";
    discordIdInput.placeholder = DISCORD_USER_ID_EXAMPLE;

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "button";
    submit.dataset.mypageDiscordIdSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    submit.disabled = true;
    submit.textContent = "保存";

    const warning = document.createElement("p");
    warning.className = "mypage-profile-warning";
    warning.textContent = "DiscordユーザーIDは17〜20桁の数字で入力してください。";

    const example = document.createElement("p");
    example.className = "mypage-profile-note";
    example.textContent = `入力例: ${DISCORD_USER_ID_EXAMPLE}`;

    const guide = document.createElement("details");
    guide.className = "mypage-profile-guide";

    const guideSummary = document.createElement("summary");
    guideSummary.textContent = "DiscordユーザーIDの確認方法";

    const guideList = document.createElement("ol");
    [
      "Discord左下のアカウント付近にある歯車を押して、設定メニューを開きます。",
      "メニュー内の「詳細設定」または「開発者向け」項目を開きます。",
      "開発者モードをオンにします。",
      "再びDiscordの画面へ戻り、左下の自分のアカウントを押します。",
      "一番下に表示される「ユーザーIDをコピー」を押すと、自動的にコピーされます。",
      "コピーした数字を、この入力欄へ形式に従って貼り付けてください。"
    ].forEach((text) => {
      const item = document.createElement("li");
      item.textContent = text;
      guideList.append(item);
    });

    guide.append(guideSummary, guideList);

    form.append(
      createInputField("DiscordユーザーID", discordIdInput),
      warning,
      example,
      guide,
      submit
    );

    const note = document.createElement("p");
    note.className = "mypage-profile-note";
    note.textContent = "この情報は公開プロフィールには表示されません。";

    const state = document.createElement("p");
    state.className = "mypage-profile-state";
    state.dataset.mypageDiscordIdState = "";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.hidden = true;

    const editor = {
      container,
      currentValue,
      form,
      input: discordIdInput,
      state,
      submit,
      session,
      inputDirty: false
    };

    discordIdInput.addEventListener("input", () => {
      editor.inputDirty = true;
    });

    submit.addEventListener("click", (event) => {
      handleDiscordIdSave(client, elements, editor, event);
    });

    form.addEventListener("submit", (event) => {
      handleDiscordIdSave(client, elements, editor, event);
    });

    container.append(head, current, form, note, state);
    return editor;
  }

  function setDiscordIdPanelState(editor, message, options = {}) {
    editor.state.textContent = message || "";
    editor.state.hidden = !message;
    editor.state.classList.toggle("is-error", Boolean(options.error));
    editor.state.classList.toggle("is-warn", Boolean(options.warn));
  }

  function setDiscordIdEditorState(editor, discordId, options = {}) {
    const rawDiscordId = normalizeDiscordId(discordId);
    const normalized = normalizeDiscordUserIdInput(rawDiscordId);
    const nextDiscordId = normalized.valid ? normalized.value : rawDiscordId;
    const hasInvalidStoredValue = Boolean(rawDiscordId && !normalized.valid);
    editor.currentValue.textContent = hasInvalidStoredValue
      ? "登録形式を確認してください"
      : nextDiscordId || "未登録";
    editor.currentValue.classList.toggle("is-invalid", hasInvalidStoredValue);

    if (!options.preserveDirtyInput || !editor.inputDirty) {
      editor.input.value = hasInvalidStoredValue ? "" : nextDiscordId;
      editor.inputDirty = false;
    }

    editor.input.disabled = false;
    editor.input.readOnly = false;
    editor.submit.disabled = false;
  }

  function setDiscordIdEditorError(editor, message = "読み込みできませんでした") {
    editor.currentValue.textContent = "確認できませんでした";
    editor.input.disabled = false;
    editor.input.readOnly = false;
    editor.submit.disabled = false;
    setDiscordIdPanelState(editor, message, { error: true });
  }

  function showDiscordIdSaveFailure(editor, error) {
    setDiscordIdPanelState(editor, "保存できませんでした", { error: true });

    if (error) {
      console.warn("discord user id update failed", {
        code: error?.code || "unknown",
        name: error?.name || "unknown",
        status: error?.status || "unknown"
      });
    }
  }

  async function loadProfileContact(client, editor) {
    setDiscordIdPanelState(editor, "読み込み中");

    try {
      const session = await getActiveSession(client, editor.session);
      if (!session) {
        setDiscordIdEditorError(editor);
        return;
      }

      const { data, error } = await client.rpc("get_my_profile_contact");

      if (error) {
        setDiscordIdEditorError(editor);
        return;
      }

      const row = Array.isArray(data) ? data[0] : data;
      if (!row || !Object.prototype.hasOwnProperty.call(row, "discord_handle")) {
        setDiscordIdEditorError(editor);
        return;
      }

      const storedDiscordId = normalizeDiscordId(row.discord_handle);
      const storedDiscordIdState = normalizeDiscordUserIdInput(storedDiscordId);
      const needsRecheck = Boolean(storedDiscordId && !storedDiscordIdState.valid);
      setDiscordIdEditorState(editor, storedDiscordId, { preserveDirtyInput: true });
      setDiscordIdPanelState(
        editor,
        needsRecheck ? DISCORD_USER_ID_RECHECK_MESSAGE : "",
        { warn: needsRecheck }
      );
    } catch (error) {
      setDiscordIdEditorError(editor);
    }
  }

  async function handleDiscordIdSave(client, elements, editor, event) {
    event?.preventDefault?.();

    const rawDiscordId = editor.input ? editor.input.value : "";
    const normalizedDiscordId = normalizeDiscordUserIdInput(rawDiscordId);
    const nextDiscordId = normalizedDiscordId.valid ? normalizedDiscordId.value : normalizeDiscordId(rawDiscordId);

    if (hasLineBreak(rawDiscordId)) {
      setDiscordIdPanelState(editor, "改行は使えません。", { error: true });
      return;
    }

    if (countDiscordIdCharacters(nextDiscordId) > DISCORD_ID_MAX_LENGTH) {
      setDiscordIdPanelState(editor, DISCORD_USER_ID_FORMAT_MESSAGE, { error: true });
      return;
    }

    if (!normalizedDiscordId.valid) {
      setDiscordIdPanelState(editor, DISCORD_USER_ID_FORMAT_MESSAGE, { error: true });
      return;
    }

    try {
      setMessage(elements, "");
      setDiscordIdPanelState(editor, "保存中");
      setFormBusy(editor.form, true, "保存中", "保存");
      const { data, error } = await client.rpc("update_my_discord_id", {
        new_discord_id: nextDiscordId
      });

      if (error) {
        showDiscordIdSaveFailure(editor, error);
        return;
      }

      const row = Array.isArray(data) ? data[0] : data;
      const returnedDiscordId = row && Object.prototype.hasOwnProperty.call(row, "discord_handle")
        ? normalizeDiscordUserIdInput(row.discord_handle)
        : null;
      const savedDiscordId = returnedDiscordId?.valid && returnedDiscordId.value
        ? returnedDiscordId.value
        : nextDiscordId;
      editor.inputDirty = false;
      setDiscordIdEditorState(editor, savedDiscordId);
      setDiscordIdPanelState(editor, "保存しました");
    } catch (error) {
      showDiscordIdSaveFailure(editor, error);
    } finally {
      if (editor.form.isConnected) setFormBusy(editor.form, false, "保存中", "保存");
    }
  }

  function setPlayerCharacterPanelState(panel, message, options = {}) {
    panel.state.textContent = message || "";
    panel.state.hidden = !message;
    panel.state.classList.toggle("is-error", Boolean(options.error));
    panel.state.classList.toggle("is-warn", Boolean(options.warn));
  }

  function setPlayerCharacterPanelBusy(panel, busy) {
    panel.container.querySelectorAll("input, button").forEach((control) => {
      control.disabled = Boolean(busy);
    });
  }

  function createPcNameCheckbox(labelText, checked = false) {
    const label = document.createElement("label");
    label.className = "mypage-pc-checkbox";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = checked;

    const text = document.createElement("span");
    text.textContent = labelText;

    label.append(checkbox, text);
    return { label, checkbox };
  }

  function createPlayerCharacterPanel(client, elements, session) {
    const container = document.createElement("section");
    container.className = "mypage-profile-panel";
    container.dataset.mypagePlayerCharacterPanel = "";

    const head = document.createElement("div");
    head.className = "mypage-profile-panel-head";

    const title = document.createElement("h3");
    title.textContent = "PC名";

    const description = document.createElement("p");
    description.textContent = "参加申請やリザルト表示に使うPC名を登録できます。";

    head.append(title, description);

    const note = document.createElement("p");
    note.className = "mypage-profile-note";
    note.textContent = `PC名は${PC_NAME_MAX_LENGTH}文字以内で入力してください。改行は使えません。`;

    const list = document.createElement("div");
    list.className = "mypage-pc-list";
    list.dataset.mypagePcList = "";

    const createForm = document.createElement("form");
    createForm.className = "calendar-form mypage-pc-create-form";
    createForm.dataset.mypagePcCreateForm = "";

    const createInput = document.createElement("input");
    createInput.type = "text";
    createInput.name = "pcName";
    createInput.autocomplete = "off";
    createInput.maxLength = PC_NAME_MAX_LENGTH;
    createInput.placeholder = "例: ボボボーボ・ボーボボ";

    const defaultControl = createPcNameCheckbox("このPCを既定にする");

    const createSubmit = document.createElement("button");
    createSubmit.type = "submit";
    createSubmit.className = "button primary";
    createSubmit.dataset.mypageFormSubmit = "";
    createSubmit.textContent = "保存";

    createForm.append(
      createInputField("PC名", createInput),
      defaultControl.label,
      createSubmit
    );

    const state = document.createElement("p");
    state.className = "mypage-profile-state";
    state.dataset.mypagePlayerCharacterState = "";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.hidden = true;

    const panel = {
      container,
      list,
      createForm,
      createInput,
      defaultCheckbox: defaultControl.checkbox,
      state,
      client,
      records: [],
      keyToCharacter: new Map(),
      session
    };

    createForm.addEventListener("submit", (event) => {
      handlePlayerCharacterCreate(client, elements, panel, event);
    });

    container.append(head, note, list, createForm, state);
    return panel;
  }

  function renderPlayerCharacters(panel) {
    panel.list.replaceChildren();
    panel.keyToCharacter = new Map();

    const activeRecords = getActivePlayerCharacters(panel);
    if (!activeRecords.length) {
      setPlayerCharacterPanelState(panel, "現在、登録済みPC名はありません。");
      return;
    }

    setPlayerCharacterPanelState(panel, "");
    activeRecords.forEach((character, index) => {
      const localKey = `pc-${index}`;
      panel.keyToCharacter.set(localKey, character);
      panel.list.append(createPlayerCharacterCard(panel, character, localKey));
    });
  }

  function createPlayerCharacterCard(panel, character, localKey) {
    const card = document.createElement("article");
    card.className = "mypage-pc-card";
    card.dataset.mypagePcCard = "";
    card.dataset.pcKey = localKey;

    const head = document.createElement("div");
    head.className = "mypage-pc-card-head";

    const name = document.createElement("h4");
    name.textContent = character.pcName || "PC名未設定";

    const defaultBadge = document.createElement("span");
    defaultBadge.className = "tag";
    defaultBadge.textContent = character.isDefault ? "既定" : "通常";

    const activeBadge = document.createElement("span");
    activeBadge.className = "tag";
    activeBadge.textContent = character.isActive ? "有効" : "非アクティブ";

    head.append(name, defaultBadge, activeBadge);

    const editForm = document.createElement("form");
    editForm.className = "calendar-form mypage-pc-edit-form";
    editForm.dataset.mypagePcEditForm = "";

    const editInput = document.createElement("input");
    editInput.type = "text";
    editInput.name = "pcName";
    editInput.autocomplete = "off";
    editInput.maxLength = PC_NAME_MAX_LENGTH;
    editInput.value = character.pcName || "";

    const defaultControl = createPcNameCheckbox("既定PCにする", character.isDefault);

    const saveButton = document.createElement("button");
    saveButton.type = "submit";
    saveButton.className = "button primary";
    saveButton.dataset.mypageFormSubmit = "";
    saveButton.textContent = "保存";

    editForm.append(
      createInputField("PC名", editInput),
      defaultControl.label,
      saveButton
    );

    editForm.addEventListener("submit", (event) => {
      handlePlayerCharacterUpdate(panel, localKey, editInput, defaultControl.checkbox, event);
    });

    const actions = document.createElement("div");
    actions.className = "mypage-pc-actions";

    if (!character.isDefault) {
      const setDefaultButton = document.createElement("button");
      setDefaultButton.type = "button";
      setDefaultButton.className = "button";
      setDefaultButton.textContent = "既定にする";
      setDefaultButton.addEventListener("click", () => {
        handlePlayerCharacterSetDefault(panel, localKey);
      });
      actions.append(setDefaultButton);
    }

    const deactivateButton = document.createElement("button");
    deactivateButton.type = "button";
    deactivateButton.className = "button";
    deactivateButton.textContent = "一覧から外す";
    deactivateButton.addEventListener("click", () => {
      handlePlayerCharacterDeactivate(panel, localKey);
    });
    actions.append(deactivateButton);

    card.append(head, editForm, actions);
    return card;
  }

  function getPlayerCharacterFromPanel(panel, localKey) {
    return panel.keyToCharacter.get(localKey) || null;
  }

  async function loadPlayerCharacters(client, panel, options = {}) {
    setPlayerCharacterPanelState(panel, "読み込み中");

    try {
      const session = await getActiveSession(client, panel.session);
      if (!session) {
        setPlayerCharacterPanelState(panel, "ログインが必要です。", { error: true });
        return;
      }

      const { data, error } = await client.rpc("get_my_player_characters");
      if (error) {
        setPlayerCharacterPanelState(panel, getPlayerCharacterErrorMessage(error), { error: true });
        return;
      }

      panel.records = (Array.isArray(data) ? data : []).map(normalizePlayerCharacterRow);
      renderPlayerCharacters(panel);
      if (options.successMessage) {
        setPlayerCharacterPanelState(panel, options.successMessage);
      }
    } catch (error) {
      setPlayerCharacterPanelState(panel, getPlayerCharacterErrorMessage(error), { error: true });
    }
  }

  function showPlayerCharacterSaveFailure(panel, error) {
    setPlayerCharacterPanelState(panel, getPlayerCharacterErrorMessage(error), { error: true });
    if (error) {
      console.warn("player character operation failed", {
        code: error?.code || "unknown",
        name: error?.name || "unknown",
        status: error?.status || "unknown"
      });
    }
  }

  async function handlePlayerCharacterCreate(client, elements, panel, event) {
    event?.preventDefault?.();

    const validation = validatePcName(panel.createInput ? panel.createInput.value : "");
    if (!validation.valid) {
      setPlayerCharacterPanelState(panel, validation.message, { error: true });
      return;
    }

    try {
      setMessage(elements, "");
      setPlayerCharacterPanelState(panel, "保存中");
      setPlayerCharacterPanelBusy(panel, true);
      const makeDefault = panel.defaultCheckbox.checked || getActivePlayerCharacters(panel).length === 0;
      const { error } = await client.rpc("create_player_character", {
        p_pc_name: validation.value,
        p_is_default: makeDefault
      });

      if (error) {
        showPlayerCharacterSaveFailure(panel, error);
        return;
      }

      panel.createInput.value = "";
      panel.defaultCheckbox.checked = false;
      await loadPlayerCharacters(client, panel, { successMessage: "PC名を登録しました。" });
    } catch (error) {
      showPlayerCharacterSaveFailure(panel, error);
    } finally {
      if (panel.container.isConnected) setPlayerCharacterPanelBusy(panel, false);
    }
  }

  async function handlePlayerCharacterUpdate(panel, localKey, input, defaultCheckbox, event) {
    event?.preventDefault?.();

    const character = getPlayerCharacterFromPanel(panel, localKey);
    if (!character) {
      setPlayerCharacterPanelState(panel, "対象のPC名が見つかりません。", { error: true });
      return;
    }

    const validation = validatePcName(input ? input.value : "");
    if (!validation.valid) {
      setPlayerCharacterPanelState(panel, validation.message, { error: true });
      return;
    }

    try {
      setPlayerCharacterPanelState(panel, "保存中");
      setPlayerCharacterPanelBusy(panel, true);
      const { error } = await panel.client.rpc("update_player_character", {
        p_character_id: character.characterId,
        p_pc_name: validation.value,
        p_is_default: Boolean(defaultCheckbox && defaultCheckbox.checked),
        p_is_active: true
      });

      if (error) {
        showPlayerCharacterSaveFailure(panel, error);
        return;
      }

      await loadPlayerCharacters(panel.client, panel, { successMessage: "PC名を保存しました。" });
    } catch (error) {
      showPlayerCharacterSaveFailure(panel, error);
    } finally {
      if (panel.container.isConnected) setPlayerCharacterPanelBusy(panel, false);
    }
  }

  async function handlePlayerCharacterSetDefault(panel, localKey) {
    const character = getPlayerCharacterFromPanel(panel, localKey);
    if (!character) {
      setPlayerCharacterPanelState(panel, "対象のPC名が見つかりません。", { error: true });
      return;
    }

    try {
      setPlayerCharacterPanelState(panel, "保存中");
      setPlayerCharacterPanelBusy(panel, true);
      const { error } = await panel.client.rpc("set_default_player_character", {
        p_character_id: character.characterId
      });

      if (error) {
        showPlayerCharacterSaveFailure(panel, error);
        return;
      }

      await loadPlayerCharacters(panel.client, panel, { successMessage: "既定PCを更新しました。" });
    } catch (error) {
      showPlayerCharacterSaveFailure(panel, error);
    } finally {
      if (panel.container.isConnected) setPlayerCharacterPanelBusy(panel, false);
    }
  }

  async function handlePlayerCharacterDeactivate(panel, localKey) {
    const character = getPlayerCharacterFromPanel(panel, localKey);
    if (!character) {
      setPlayerCharacterPanelState(panel, "対象のPC名が見つかりません。", { error: true });
      return;
    }

    const confirmed = window.confirm("このPC名を一覧から外しますか？\n過去の参加申請に保存されたPC名は残ります。");
    if (!confirmed) return;

    try {
      setPlayerCharacterPanelState(panel, "保存中");
      setPlayerCharacterPanelBusy(panel, true);
      const { error } = await panel.client.rpc("deactivate_player_character", {
        p_character_id: character.characterId
      });

      if (error) {
        showPlayerCharacterSaveFailure(panel, error);
        return;
      }

      await loadPlayerCharacters(panel.client, panel, { successMessage: "PC名を一覧から外しました。" });
    } catch (error) {
      showPlayerCharacterSaveFailure(panel, error);
    } finally {
      if (panel.container.isConnected) setPlayerCharacterPanelBusy(panel, false);
    }
  }

  function appendTemplateSelectOptions(select, options, selectedValue = "") {
    options.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.value;
      option.textContent = item.label;
      option.selected = item.value === selectedValue;
      select.append(option);
    });
  }

  function createTemplateVariableHelpPanel() {
    const container = document.createElement("details");
    container.className = "mypage-template-variable-help";
    container.dataset.mypageTemplateVariableHelp = "";
    container.hidden = true;

    const summary = document.createElement("summary");
    summary.className = "mypage-template-variable-summary";
    summary.textContent = "使用できる変数一覧";

    const body = document.createElement("div");
    body.className = "mypage-template-variable-help-body";

    const description = document.createElement("p");
    description.className = "mypage-template-variable-help-description";
    description.textContent = "本文に以下の変数を書くと、セッション詳細画面などでコピーするときに実際の値へ置き換えられます。mypage上では保存用の説明として表示しています。";

    const list = document.createElement("div");
    list.className = "mypage-template-variable-help-list";
    list.dataset.mypageTemplateVariableHelpList = "";

    body.append(description, list);
    container.append(summary, body);
    return { container, list };
  }

  function renderTemplateVariableHelp(panel) {
    const items = getTemplateVariableHelpItems(panel.typeSelect.value);
    panel.variableHelpList.replaceChildren();

    items.forEach((item) => {
      const card = document.createElement("article");
      card.className = "mypage-template-variable-card";

      const code = document.createElement("code");
      code.textContent = item.name;

      const detailList = document.createElement("dl");
      [
        ["代入内容", item.substitution],
        ["出力例", item.example],
        ["補足", item.note]
      ].forEach(([label, value]) => {
        const row = document.createElement("div");
        const term = document.createElement("dt");
        term.textContent = label;
        const description = document.createElement("dd");
        description.textContent = value;
        if (label === "出力例") description.className = "mypage-template-variable-example";
        row.append(term, description);
        detailList.append(row);
      });

      card.append(code, detailList);
      panel.variableHelpList.append(card);
    });

    panel.variableHelp.hidden = !items.length;
    if (!items.length) panel.variableHelp.open = false;
  }

  function createTemplateExamplePanel() {
    const container = document.createElement("details");
    container.className = "mypage-template-example-help";
    container.dataset.mypageTemplateExampleHelp = "";

    const summary = document.createElement("summary");
    summary.className = "mypage-template-variable-summary";
    summary.textContent = "テンプレート例";

    const body = document.createElement("div");
    body.className = "mypage-template-example-body";
    body.dataset.mypageTemplateExampleBody = "";

    container.append(summary, body);
    return { container, body };
  }

  function renderTemplateExamples(panel) {
    const examples = getTemplateExamples(panel.typeSelect.value);
    panel.exampleBody.replaceChildren();

    if (!examples.length) {
      const empty = document.createElement("p");
      empty.textContent = "この種別の例はまだありません。";
      panel.exampleBody.append(empty);
      return;
    }

    const note = document.createElement("p");
    note.className = "mypage-template-example-note";
    note.textContent = "これは例です。本文には自動挿入されません。";

    const list = document.createElement("div");
    list.className = "mypage-template-example-list";
    examples.forEach((example) => {
      const item = document.createElement("pre");
      item.className = "mypage-template-example-text";
      item.textContent = example;
      list.append(item);
    });
    panel.exampleBody.append(note, list);
  }

  function createSessionPostTemplateEditor() {
    const container = document.createElement("section");
    container.className = "mypage-template-session-post-editor";
    container.dataset.mypageTemplateSessionPostEditor = "";
    container.hidden = true;

    const title = document.createElement("h4");
    title.textContent = "依頼書用フォーム";

    const description = document.createElement("p");
    description.className = "mypage-template-session-post-note";
    description.textContent = "依頼書用テンプレートはフォーム内容を保存します。保存時は既存の依頼書テンプレートJSON形式へ変換します。";

    const grid = document.createElement("div");
    grid.className = "mypage-template-session-post-grid";

    const titleInput = document.createElement("input");
    titleInput.type = "text";
    titleInput.maxLength = SESSION_POST_TITLE_MAX_LENGTH;
    titleInput.autocomplete = "off";
    titleInput.placeholder = "例：灰壁線異常調査";

    const startAtInput = document.createElement("input");
    startAtInput.type = "datetime-local";

    const endAtInput = document.createElement("input");
    endAtInput.type = "datetime-local";

    const applicationDeadlineInput = document.createElement("input");
    applicationDeadlineInput.type = "datetime-local";

    const sessionTypeSelect = document.createElement("select");
    appendTemplateSelectOptions(sessionTypeSelect, SESSION_POST_TYPE_OPTIONS, "one-shot");

    const sessionToolInput = document.createElement("input");
    sessionToolInput.type = "text";
    sessionToolInput.maxLength = SESSION_POST_TOOL_MAX_LENGTH;
    sessionToolInput.autocomplete = "off";
    sessionToolInput.placeholder = "例：Tekey / ココフォリア / Discordボイス";

    const playerMinInput = document.createElement("input");
    playerMinInput.type = "number";
    playerMinInput.min = "0";
    playerMinInput.step = "1";
    playerMinInput.inputMode = "numeric";

    const playerMaxInput = document.createElement("input");
    playerMaxInput.type = "number";
    playerMaxInput.min = "0";
    playerMaxInput.step = "1";
    playerMaxInput.inputMode = "numeric";

    const visibilitySelect = document.createElement("select");
    appendTemplateSelectOptions(visibilitySelect, SESSION_POST_VISIBILITY_OPTIONS, "hidden");

    const statusSelect = document.createElement("select");
    appendTemplateSelectOptions(statusSelect, SESSION_POST_STATUS_OPTIONS, "draft");

    const discordMentionSelect = document.createElement("select");
    appendTemplateSelectOptions(discordMentionSelect, [
      { value: "", label: "未設定" },
      { value: "everyone", label: "@everyone通知を送る" },
      { value: "none", label: "@everyone通知を送らない" }
    ], "");

    const summaryTextarea = document.createElement("textarea");
    summaryTextarea.maxLength = SESSION_POST_SUMMARY_MAX_LENGTH;
    summaryTextarea.rows = 5;
    summaryTextarea.placeholder = "依頼書の概要を入力します。";

    const summaryField = createInputField("概要", summaryTextarea);
    summaryField.classList.add("mypage-template-session-post-field-wide");

    grid.append(
      createInputField("タイトル", titleInput),
      createInputField("開始日時", startAtInput),
      createInputField("終了日時", endAtInput),
      createInputField("申請締切", applicationDeadlineInput),
      createInputField("種別", sessionTypeSelect),
      createInputField("開催場所", sessionToolInput),
      createInputField("募集人数 min", playerMinInput),
      createInputField("募集人数 max", playerMaxInput),
      createInputField("公開状態", visibilitySelect),
      createInputField("募集状態", statusSelect),
      createInputField("Discord通知", discordMentionSelect),
      summaryField
    );

    container.append(title, description, grid);

    return {
      container,
      fields: {
        titleInput,
        startAtInput,
        endAtInput,
        applicationDeadlineInput,
        sessionTypeSelect,
        sessionToolInput,
        playerMinInput,
        playerMaxInput,
        visibilitySelect,
        statusSelect,
        discordMentionSelect,
        summaryTextarea
      }
    };
  }

  function setSessionPostTemplateFields(panel, fields) {
    const normalized = normalizeSessionPostTemplateFields(fields);
    const controls = panel.sessionPostFields || {};
    if (controls.titleInput) controls.titleInput.value = normalized.p_title;
    if (controls.startAtInput) controls.startAtInput.value = normalized.p_start_at;
    if (controls.endAtInput) controls.endAtInput.value = normalized.p_end_at;
    if (controls.applicationDeadlineInput) controls.applicationDeadlineInput.value = normalized.p_application_deadline;
    if (controls.sessionTypeSelect) controls.sessionTypeSelect.value = normalized.p_session_type;
    if (controls.sessionToolInput) controls.sessionToolInput.value = normalized.p_session_tool;
    if (controls.playerMinInput) controls.playerMinInput.value = normalized.p_player_min;
    if (controls.playerMaxInput) controls.playerMaxInput.value = normalized.p_player_max;
    if (controls.visibilitySelect) controls.visibilitySelect.value = normalized.p_visibility;
    if (controls.statusSelect) controls.statusSelect.value = normalized.p_status;
    if (controls.discordMentionSelect) controls.discordMentionSelect.value = normalized.discord_mention_mode;
    if (controls.summaryTextarea) controls.summaryTextarea.value = normalized.p_summary;
  }

  function resetSessionPostTemplateFields(panel) {
    setSessionPostTemplateFields(panel, createDefaultSessionPostTemplateFields());
  }

  function updateTemplateMode(panel) {
    const templateType = normalizeTemplateType(panel.typeSelect.value);
    const isSessionPost = templateType === "session_post";
    panel.bodyField.hidden = isSessionPost;
    panel.sessionPostEditor.hidden = !isSessionPost;
    renderTemplateExamples(panel);
    renderTemplateVariableHelp(panel);
  }

  function setTemplatePanelState(panel, message, options = {}) {
    panel.state.textContent = message || "";
    panel.state.hidden = !message;
    panel.state.classList.toggle("is-error", Boolean(options.error));
    panel.state.classList.toggle("is-warn", Boolean(options.warn));
  }

  function setTemplatePanelBusy(panel, busy) {
    panel.isBusy = Boolean(busy);
    panel.container.querySelectorAll("input, select, textarea, button").forEach((control) => {
      control.disabled = Boolean(busy);
    });
    updateTemplateControls(panel);
  }

  function createTemplateManagementPanel(client, elements, session) {
    const container = document.createElement("section");
    container.className = "mypage-profile-panel mypage-template-panel";
    container.dataset.mypageTemplatePanel = "";

    const head = document.createElement("div");
    head.className = "mypage-profile-panel-head";

    const title = document.createElement("h3");
    title.textContent = "テンプレート管理";

    const description = document.createElement("p");
    description.textContent = "呼び出し、リザルト、依頼書、申請コメントなどの個人テンプレートを管理できます。";

    head.append(title, description);

    const note = document.createElement("p");
    note.className = "mypage-profile-note";
    note.textContent = "テンプレート本文に秘匿情報や認証情報を入れないでください。依頼書用はフォーム内容として保存します。";

    const form = document.createElement("form");
    form.className = "calendar-form mypage-template-form";
    form.dataset.mypageTemplateForm = "";
    form.noValidate = true;

    const savedSelect = document.createElement("select");
    savedSelect.dataset.mypageTemplateSelect = "";
    savedSelect.disabled = true;
    const loadingOption = document.createElement("option");
    loadingOption.value = "";
    loadingOption.textContent = "読み込み中";
    savedSelect.append(loadingOption);

    const nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.name = "templateName";
    nameInput.autocomplete = "off";
    nameInput.maxLength = TEMPLATE_NAME_MAX_LENGTH;
    nameInput.placeholder = "例：卓前呼び出し";

    const typeSelect = document.createElement("select");
    typeSelect.name = "templateType";
    typeSelect.dataset.mypageTemplateType = "";
    TEMPLATE_TYPE_OPTIONS.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.value;
      option.textContent = item.label;
      typeSelect.append(option);
    });
    typeSelect.value = "call";

    const bodyTextarea = document.createElement("textarea");
    bodyTextarea.name = "templateBody";
    bodyTextarea.dataset.mypageTemplateBody = "";
    bodyTextarea.maxLength = TEMPLATE_BODY_MAX_LENGTH;
    bodyTextarea.rows = 8;
    bodyTextarea.placeholder = "{{session_title}} などの変数を含めた本文を入力できます。";
    bodyTextarea.spellcheck = false;

    const typeNote = document.createElement("p");
    typeNote.className = "mypage-template-type-note";
    typeNote.dataset.mypageTemplateTypeNote = "";
    typeNote.textContent = getTemplateTypeNote(typeSelect.value);

    const actions = document.createElement("div");
    actions.className = "mypage-template-actions";

    const createButton = document.createElement("button");
    createButton.type = "button";
    createButton.className = "button primary";
    createButton.dataset.mypageTemplateCreate = "";
    createButton.textContent = "新規保存";
    createButton.disabled = true;

    const updateButton = document.createElement("button");
    updateButton.type = "button";
    updateButton.className = "button";
    updateButton.dataset.mypageTemplateUpdate = "";
    updateButton.textContent = "変更を保存";
    updateButton.disabled = true;

    const deleteButton = document.createElement("button");
    deleteButton.type = "button";
    deleteButton.className = "button danger";
    deleteButton.dataset.mypageTemplateDelete = "";
    deleteButton.textContent = "削除";
    deleteButton.disabled = true;

    const clearButton = document.createElement("button");
    clearButton.type = "button";
    clearButton.className = "button";
    clearButton.dataset.mypageTemplateClear = "";
    clearButton.textContent = "新規入力に戻す";

    actions.append(createButton, updateButton, deleteButton, clearButton);

    const bodyField = createInputField("本文", bodyTextarea);
    bodyField.classList.add("mypage-template-body-field");

    const exampleHelp = createTemplateExamplePanel();
    const variableHelp = createTemplateVariableHelpPanel();
    const sessionPostEditor = createSessionPostTemplateEditor();

    form.append(
      createInputField("保存済みテンプレート", savedSelect),
      createInputField("テンプレート名", nameInput),
      createInputField("種別", typeSelect),
      typeNote,
      bodyField,
      sessionPostEditor.container,
      exampleHelp.container,
      variableHelp.container,
      actions
    );

    const state = document.createElement("p");
    state.className = "mypage-profile-state";
    state.dataset.mypageTemplateState = "";
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    state.hidden = true;

    const panel = {
      container,
      form,
      savedSelect,
      nameInput,
      typeSelect,
      bodyTextarea,
      bodyField,
      typeNote,
      exampleHelp: exampleHelp.container,
      exampleBody: exampleHelp.body,
      variableHelp: variableHelp.container,
      variableHelpList: variableHelp.list,
      sessionPostEditor: sessionPostEditor.container,
      sessionPostFields: sessionPostEditor.fields,
      createButton,
      updateButton,
      deleteButton,
      clearButton,
      state,
      client,
      records: [],
      keyToTemplate: new Map(),
      selectedTemplateId: "",
      session,
      isBusy: false
    };

    savedSelect.addEventListener("change", () => {
      const template = panel.keyToTemplate.get(savedSelect.value) || null;
      if (!template) {
        resetTemplateForm(panel, { preserveInputs: true });
        return;
      }
      const result = applyTemplateToForm(panel, template);
      setTemplatePanelState(panel, result.message, { warn: result.warn });
    });

    nameInput.addEventListener("input", () => {
      updateTemplateControls(panel);
      setTemplatePanelState(panel, "");
    });

    typeSelect.addEventListener("change", () => {
      panel.typeNote.textContent = getTemplateTypeNote(typeSelect.value);
      updateTemplateMode(panel);
      updateTemplateControls(panel);
      setTemplatePanelState(panel, "");
    });

    bodyTextarea.addEventListener("input", () => {
      updateTemplateControls(panel);
      setTemplatePanelState(panel, "");
    });

    sessionPostEditor.container.querySelectorAll("input, select, textarea").forEach((control) => {
      control.addEventListener("input", () => {
        updateTemplateControls(panel);
        setTemplatePanelState(panel, "");
      });
      control.addEventListener("change", () => {
        updateTemplateControls(panel);
        setTemplatePanelState(panel, "");
      });
    });

    createButton.addEventListener("click", () => {
      handleTemplateCreate(client, elements, panel);
    });

    updateButton.addEventListener("click", () => {
      handleTemplateUpdate(panel);
    });

    deleteButton.addEventListener("click", () => {
      handleTemplateDelete(panel);
    });

    clearButton.addEventListener("click", () => {
      resetTemplateForm(panel);
      setTemplatePanelState(panel, "");
    });

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      if (getSelectedTemplate(panel)) {
        handleTemplateUpdate(panel);
      } else {
        handleTemplateCreate(client, elements, panel);
      }
    });

    container.append(head, note, form, state);
    resetSessionPostTemplateFields(panel);
    updateTemplateMode(panel);
    updateTemplateControls(panel);
    return panel;
  }

  function renderTemplateOptions(panel) {
    panel.savedSelect.replaceChildren();
    panel.keyToTemplate = new Map();

    const blankOption = document.createElement("option");
    blankOption.value = "";
    blankOption.textContent = panel.records.length
      ? "新規テンプレートとして編集"
      : "保存済みテンプレートはありません";
    panel.savedSelect.append(blankOption);

    panel.records.forEach((template, index) => {
      const localKey = `template-${index}`;
      panel.keyToTemplate.set(localKey, template);

      const option = document.createElement("option");
      option.value = localKey;
      option.textContent = `${template.templateName}（${getTemplateTypeLabel(template.templateType)}）`;
      option.selected = template.templateId === panel.selectedTemplateId;
      panel.savedSelect.append(option);
    });
  }

  function getSelectedTemplate(panel) {
    return panel.selectedTemplateId
      ? panel.records.find((template) => template.templateId === panel.selectedTemplateId) || null
      : null;
  }

  function resetTemplateForm(panel, options = {}) {
    panel.selectedTemplateId = "";
    panel.savedSelect.value = "";
    if (!options.preserveInputs) {
      panel.nameInput.value = "";
      panel.typeSelect.value = "call";
      panel.bodyTextarea.value = "";
      resetSessionPostTemplateFields(panel);
      panel.typeNote.textContent = getTemplateTypeNote("call");
    }
    updateTemplateMode(panel);
    updateTemplateControls(panel);
  }

  function applyTemplateToForm(panel, template) {
    panel.selectedTemplateId = template.templateId;
    panel.nameInput.value = template.templateName;
    const templateType = normalizeTemplateType(template.templateType) || "other";
    panel.typeSelect.value = templateType;
    if (templateType === "session_post") {
      panel.bodyTextarea.value = "";
      const fields = parseSessionPostTemplateBody(template.templateBody);
      if (fields) {
        setSessionPostTemplateFields(panel, fields);
      } else {
        resetSessionPostTemplateFields(panel);
        panel.typeNote.textContent = getTemplateTypeNote(panel.typeSelect.value);
        updateTemplateMode(panel);
        updateTemplateControls(panel);
        return {
          message: "依頼書用テンプレートの形式を確認できませんでした。フォームには反映していません。",
          warn: true
        };
      }
    } else {
      panel.bodyTextarea.value = template.templateBody;
      resetSessionPostTemplateFields(panel);
    }
    panel.typeNote.textContent = getTemplateTypeNote(panel.typeSelect.value);
    updateTemplateMode(panel);
    updateTemplateControls(panel);
    return { message: "保存済みテンプレートを読み込みました。", warn: false };
  }

  function updateTemplateControls(panel) {
    const validation = buildTemplatePresetInput(panel);
    const selectedTemplate = getSelectedTemplate(panel);
    const busy = Boolean(panel.isBusy);

    panel.savedSelect.disabled = busy || !panel.records.length;
    panel.nameInput.disabled = busy;
    panel.typeSelect.disabled = busy;
    panel.bodyTextarea.disabled = busy;
    panel.createButton.disabled = busy || !validation.valid;
    panel.updateButton.disabled = busy || !selectedTemplate || !validation.valid;
    panel.deleteButton.disabled = busy || !selectedTemplate;
    panel.clearButton.disabled = busy;
  }

  async function loadTemplatePresets(client, panel, options = {}) {
    setTemplatePanelState(panel, options.loadingMessage || "読み込み中");

    try {
      const session = await getActiveSession(client, panel.session);
      if (!session) {
        setTemplatePanelState(panel, "ログインが必要です。", { error: true });
        return;
      }

      const rows = await queryTemplatePresets(client);
      panel.records = normalizeTemplatePresetRows(rows);
      panel.selectedTemplateId = panel.records.some((template) => template.templateId === options.preferredTemplateId)
        ? options.preferredTemplateId
        : "";
      renderTemplateOptions(panel);

      const selectedTemplate = getSelectedTemplate(panel);
      let selectedState = null;
      if (selectedTemplate) {
        selectedState = applyTemplateToForm(panel, selectedTemplate);
      } else {
        resetTemplateForm(panel, { preserveInputs: Boolean(options.preserveInputs) });
      }

      setTemplatePanelState(
        panel,
        options.successMessage || selectedState?.message || (panel.records.length ? "" : "保存済みテンプレートはありません。"),
        { warn: Boolean(!options.successMessage && selectedState?.warn) }
      );
    } catch (error) {
      panel.records = [];
      panel.selectedTemplateId = "";
      renderTemplateOptions(panel);
      updateTemplateControls(panel);
      setTemplatePanelState(panel, getTemplateOperationErrorMessage(error), { error: true });
    }
  }

  async function handleTemplateCreate(client, elements, panel) {
    const validation = buildTemplatePresetInput(panel);
    if (!validation.valid) {
      setTemplatePanelState(panel, validation.message, { error: true });
      return;
    }

    try {
      setMessage(elements, "");
      setTemplatePanelState(panel, "保存中");
      setTemplatePanelBusy(panel, true);
      const created = normalizeTemplatePresetRow(await createTemplatePreset(client, validation));
      await loadTemplatePresets(client, panel, {
        preferredTemplateId: created.templateId,
        successMessage: "テンプレートを保存しました。"
      });
    } catch (error) {
      setTemplatePanelState(panel, getTemplateOperationErrorMessage(error), { error: true });
    } finally {
      if (panel.container.isConnected) setTemplatePanelBusy(panel, false);
    }
  }

  async function handleTemplateUpdate(panel) {
    const template = getSelectedTemplate(panel);
    if (!template) {
      setTemplatePanelState(panel, "保存済みテンプレートを選んでください。", { error: true });
      return;
    }

    const validation = buildTemplatePresetInput(panel);
    if (!validation.valid) {
      setTemplatePanelState(panel, validation.message, { error: true });
      return;
    }

    try {
      setTemplatePanelState(panel, "保存中");
      setTemplatePanelBusy(panel, true);
      const updated = normalizeTemplatePresetRow(await updateTemplatePreset(panel.client, {
        ...validation,
        templateId: template.templateId
      }));
      await loadTemplatePresets(panel.client, panel, {
        preferredTemplateId: updated.templateId || template.templateId,
        successMessage: "変更を保存しました。"
      });
    } catch (error) {
      setTemplatePanelState(panel, getTemplateOperationErrorMessage(error), { error: true });
    } finally {
      if (panel.container.isConnected) setTemplatePanelBusy(panel, false);
    }
  }

  async function handleTemplateDelete(panel) {
    const template = getSelectedTemplate(panel);
    if (!template) {
      setTemplatePanelState(panel, "保存済みテンプレートを選んでください。", { error: true });
      return;
    }

    const confirmed = window.confirm("このテンプレートを削除します。テンプレートは一覧から外れます。続けますか？");
    if (!confirmed) return;

    try {
      setTemplatePanelState(panel, "削除中");
      setTemplatePanelBusy(panel, true);
      await deactivateTemplatePreset(panel.client, template.templateId);
      await loadTemplatePresets(panel.client, panel, {
        preferredTemplateId: "",
        successMessage: "テンプレートを削除しました。"
      });
    } catch (error) {
      setTemplatePanelState(panel, getTemplateOperationErrorMessage(error), { error: true });
    } finally {
      if (panel.container.isConnected) setTemplatePanelBusy(panel, false);
    }
  }

  function createLogoutButton(client, elements, className = "button danger") {
    const logout = document.createElement("button");
    logout.className = className;
    logout.type = "button";
    logout.dataset.mypageLogout = "";
    logout.textContent = "ログアウト";
    logout.addEventListener("click", () => {
      handleLogout(client, elements, logout);
    });
    return logout;
  }

  function removeNavLogoutButton() {
    document.querySelectorAll("[data-mypage-nav-logout]").forEach((button) => button.remove());
  }

  function refreshHeaderNotifications() {
    window.VelgardNotifications?.refresh?.();
  }

  function resetHeaderNotifications() {
    window.VelgardNotifications?.reset?.();
  }

  function renderNavLogoutButton(client, elements) {
    removeNavLogoutButton();
    const accountLink = document.querySelector(".account-nav__link");
    if (!accountLink) return null;
    const logout = createLogoutButton(client, elements, "button danger account-nav__logout");
    logout.dataset.mypageNavLogout = "";
    accountLink.insertAdjacentElement("afterend", logout);
    const mobileNav = document.querySelector(".global-nav");
    if (mobileNav) {
      const menuLogout = createLogoutButton(client, elements, "account-nav__logout-menu");
      menuLogout.dataset.mypageNavLogout = "";
      menuLogout.dataset.mypageMobileNavLogout = "";
      mobileNav.append(menuLogout);
    }
    return logout;
  }

  function isAdminRpcResult(value) {
    if (value === true) return true;
    if (Array.isArray(value)) return value.some((item) => item === true || item?.is_admin === true);
    return value?.is_admin === true;
  }

  function createAdminCapAnnouncementDetails() {
    const adminDetails = createMypageDetails("admin専用", "キャップ更新告知");
    adminDetails.details.dataset.mypageAdminCapAnnouncements = "";

    const note = document.createElement("p");
    note.className = "mypage-profile-note";
    note.textContent = "キャップ更新案内をDiscordへ予約投稿するadmin専用機能です。admin RPCで予約を保存し、Discord投稿は後続Edge Functionゲートで扱います。";

    const actions = document.createElement("div");
    actions.className = "actions";

    const link = document.createElement("a");
    link.className = "button primary";
    link.href = "admin-cap-announcements.html";
    link.textContent = "キャップ更新告知へ";

    actions.append(link);
    adminDetails.body.append(note, actions);
    return adminDetails.details;
  }

  async function loadAdminCapAnnouncementLink(client, elements) {
    try {
      const { data, error } = await client.rpc("is_admin");
      if (error || !isAdminRpcResult(data) || !elements?.content) return;
      if (elements.content.querySelector("[data-mypage-admin-cap-announcements]")) return;
      elements.content.append(createAdminCapAnnouncementDetails());
    } catch {
      // Fail closed: non-admin and unknown admin state should not see the admin-only link.
    }
  }

  function renderAuthenticated(client, elements, message, session) {
    ensureAuthElements(elements);
    renderNavLogoutButton(client, elements);
    refreshHeaderNotifications();
    setStatus(
      elements,
      "ログイン済みです。",
      "ユーザー名、PC名、DiscordユーザーID、参加申請中・参加予定セッションを確認できます。"
    );
    clearContent(elements);

    const membershipPanel = createMembershipStatusPanel(session);
    const displayNameEditor = createDisplayNameEditor(client, elements, session);
    const avatarEditor = createAvatarEditor(client, elements, session);
    const playerCharacterPanel = createPlayerCharacterPanel(client, elements, session);
    const discordIdEditor = createDiscordIdEditor(client, elements, session);
    const templatePanel = createTemplateManagementPanel(client, elements, session);
    const applicationsPanel = createApplicationsPanel();
    const accountDetails = createMypageDetails("アカウント概要", "ログイン中");
    const profileDetails = createMypageDetails("プロフィール / PC情報", "PC名・Discord ID");
    const scheduleDetails = createMypageDetails("予定 / 申請履歴", "読み込み中");
    const templateDetails = createMypageDetails("テンプレート管理", "保存済みテンプレート");
    applicationsPanel.summaryDetails = scheduleDetails;

    const actions = document.createElement("div");
    actions.className = "actions";

    const changePassword = document.createElement("button");
    changePassword.className = "button";
    changePassword.type = "button";
    changePassword.dataset.mypagePasswordChangeOpen = "";
    changePassword.textContent = "パスワードを変更する";
    changePassword.addEventListener("click", () => {
      renderPasswordChangeForm(client, elements);
    });

    actions.append(changePassword);
    accountDetails.body.append(membershipPanel.container, displayNameEditor.container, avatarEditor.container, actions);
    profileDetails.body.append(playerCharacterPanel.container, discordIdEditor.container);
    scheduleDetails.body.append(applicationsPanel.container);
    templateDetails.body.append(templatePanel.container);
    elements.content.append(
      accountDetails.details,
      profileDetails.details,
      scheduleDetails.details,
      templateDetails.details
    );
    setMessage(elements, message || "");
    loadMembershipStatus(client, membershipPanel);
    loadDisplayName(client, displayNameEditor);
    loadAvatarProfile(client, avatarEditor);
    loadPlayerCharacters(client, playerCharacterPanel);
    loadProfileContact(client, discordIdEditor);
    loadTemplatePresets(client, templatePanel);
    loadApplications(client, applicationsPanel, session);
    loadAdminCapAnnouncementLink(client, elements);
  }

  function renderPasswordChangeForm(client, elements, message) {
    ensureAuthElements(elements);
    renderNavLogoutButton(client, elements);
    refreshHeaderNotifications();
    setStatus(
      elements,
      "ログイン済みです。",
      "新しいパスワードを入力してください。"
    );
    clearContent(elements);

    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypagePasswordChangeForm = "";
    form.noValidate = true;

    const passwordInput = document.createElement("input");
    passwordInput.type = "password";
    passwordInput.name = "newPassword";
    passwordInput.autocomplete = "new-password";
    passwordInput.required = true;

    const passwordConfirmInput = document.createElement("input");
    passwordConfirmInput.type = "password";
    passwordConfirmInput.name = "newPasswordConfirm";
    passwordConfirmInput.autocomplete = "new-password";
    passwordConfirmInput.required = true;

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "submit";
    submit.dataset.mypagePasswordChangeSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    submit.textContent = "変更する";

    form.append(
      createInputField("新しいパスワード", passwordInput),
      createInputField("新しいパスワード確認", passwordConfirmInput),
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handlePasswordChange(client, elements, form);
    });

    const actions = document.createElement("div");
    actions.className = "actions";

    const back = document.createElement("button");
    back.className = "button";
    back.type = "button";
    back.textContent = "戻る";
    back.addEventListener("click", () => {
      renderAuthenticated(client, elements);
    });

    actions.append(back);
    elements.content.append(form, actions);
    setMessage(elements, message || "");
  }

  async function handleLogin(client, elements, form, captcha) {
    const emailInput = form.querySelector('input[name="email"]');
    const passwordInput = form.querySelector('input[name="password"]');
    const email = emailInput ? emailInput.value.trim() : "";
    const password = passwordInput ? passwordInput.value : "";

    if (!email || !password || !emailInput.checkValidity()) {
      if (passwordInput) passwordInput.value = "";
      setMessage(elements, "ログインできませんでした。入力内容を確認してください。");
      return;
    }

    const captchaToken = requireCaptchaToken(captcha, elements);
    if (captchaToken === null) {
      if (passwordInput) passwordInput.value = "";
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "送信中", "ログイン");
      const { data, error } = await client.auth.signInWithPassword({
        email,
        password,
        options: { captchaToken }
      });
      if (passwordInput) passwordInput.value = "";

      if (error || !data || !data.session) {
        setMessage(elements, "ログインできませんでした。入力内容を確認してください。");
        return;
      }

      renderAuthenticated(client, elements, "", data.session);
    } catch (error) {
      if (passwordInput) passwordInput.value = "";
      setMessage(elements, "ログインできませんでした。入力内容を確認してください。");
    } finally {
      if (captcha && form.isConnected) captcha.reset();
      if (form.isConnected) setFormBusy(form, false, "送信中", "ログイン");
    }
  }

  async function handlePasswordReset(client, elements, form, captcha) {
    const emailInput = form.querySelector('input[name="email"]');
    const email = emailInput ? emailInput.value.trim() : "";

    if (!email || !emailInput.checkValidity()) {
      setMessage(elements, "入力内容を確認してください。");
      return;
    }

    const captchaToken = requireCaptchaToken(captcha, elements);
    if (captchaToken === null) return;

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "送信中", "再設定メールを送る");
      const { error } = await client.auth.resetPasswordForEmail(email, {
        redirectTo: getMypageRedirectUrl(),
        captchaToken
      });

      if (emailInput) emailInput.value = "";

      if (error) {
        setMessage(elements, "パスワード再設定メールを送信できませんでした。時間を置いて再度お試しください。");
        return;
      }

      setMessage(elements, "パスワード再設定メールを送信しました。メール内のリンクから新しいパスワードを設定してください。");
    } catch (error) {
      if (emailInput) emailInput.value = "";
      setMessage(elements, "パスワード再設定メールを送信できませんでした。時間を置いて再度お試しください。");
    } finally {
      if (captcha && form.isConnected) captcha.reset();
      if (form.isConnected) setFormBusy(form, false, "送信中", "再設定メールを送る");
    }
  }

  function clearSignupPasswords(form) {
    const passwordInput = form.querySelector('input[name="password"]');
    const passwordConfirmInput = form.querySelector('input[name="passwordConfirm"]');
    if (passwordInput) passwordInput.value = "";
    if (passwordConfirmInput) passwordConfirmInput.value = "";
  }

  function signupFailureMessage(error) {
    const message = String(error && error.message ? error.message : "").toLowerCase();
    if (message.includes("already") || message.includes("registered") || message.includes("exists")) {
      return "登録できませんでした。すでに登録済みの可能性があります。ログイン、またはパスワード再設定をお試しください。";
    }
    if (message.includes("password")) {
      return "パスワードは十分な長さで入力してください。";
    }
    return "登録できませんでした。入力内容を確認してください。";
  }

  async function handleSignup(client, elements, form, captcha) {
    const displayNameInput = form.querySelector('input[name="displayName"]');
    const emailInput = form.querySelector('input[name="email"]');
    const passwordInput = form.querySelector('input[name="password"]');
    const passwordConfirmInput = form.querySelector('input[name="passwordConfirm"]');
    const displayName = normalizeDisplayName(displayNameInput ? displayNameInput.value : "");
    const email = emailInput ? emailInput.value.trim() : "";
    const password = passwordInput ? passwordInput.value : "";
    const passwordConfirm = passwordConfirmInput ? passwordConfirmInput.value : "";

    if (!displayName) {
      clearSignupPasswords(form);
      setMessage(elements, "ユーザー名を入力してください。");
      return;
    }

    if (countDisplayNameCharacters(displayName) > DISPLAY_NAME_MAX_LENGTH) {
      clearSignupPasswords(form);
      setMessage(elements, "ユーザー名は40文字以内で入力してください。");
      return;
    }

    if (!email || !password || !passwordConfirm || !emailInput.checkValidity()) {
      clearSignupPasswords(form);
      setMessage(elements, "登録できませんでした。入力内容を確認してください。");
      return;
    }

    if (password !== passwordConfirm) {
      clearSignupPasswords(form);
      setMessage(elements, "パスワードが一致しません。");
      return;
    }

    if (password.length < MIN_PASSWORD_LENGTH) {
      clearSignupPasswords(form);
      setMessage(elements, "パスワードは十分な長さで入力してください。");
      return;
    }

    const captchaToken = requireCaptchaToken(captcha, elements);
    if (captchaToken === null) {
      clearSignupPasswords(form);
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "登録中", "登録する");
      const { data, error } = await client.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: getMypageRedirectUrl(),
          captchaToken,
          data: {
            display_name: displayName
          }
        }
      });
      clearSignupPasswords(form);

      if (error) {
        setMessage(elements, signupFailureMessage(error));
        return;
      }

      if (data && data.session) {
        renderAuthenticated(
          client,
          elements,
          "登録を受け付けました。確認メールが届いた場合は、メール内のリンクを確認してください。",
          data.session
        );
        return;
      }

      renderAnonymous(
        client,
        elements,
        "登録を受け付けました。確認メールが届いた場合は、メール内のリンクを確認してください。",
        "login"
      );
    } catch (error) {
      clearSignupPasswords(form);
      setMessage(elements, "登録できませんでした。入力内容を確認してください。");
    } finally {
      if (captcha && form.isConnected) captcha.reset();
      if (form.isConnected) setFormBusy(form, false, "登録中", "登録する");
    }
  }

  function clearPasswordChangeFields(form) {
    const passwordInput = form.querySelector('input[name="newPassword"]');
    const passwordConfirmInput = form.querySelector('input[name="newPasswordConfirm"]');
    if (passwordInput) passwordInput.value = "";
    if (passwordConfirmInput) passwordConfirmInput.value = "";
  }

  async function handlePasswordChange(client, elements, form) {
    const passwordInput = form.querySelector('input[name="newPassword"]');
    const passwordConfirmInput = form.querySelector('input[name="newPasswordConfirm"]');
    const password = passwordInput ? passwordInput.value : "";
    const passwordConfirm = passwordConfirmInput ? passwordConfirmInput.value : "";

    if (!password || !passwordConfirm) {
      clearPasswordChangeFields(form);
      setMessage(elements, "パスワードを変更できませんでした。入力内容を確認してください。");
      return;
    }

    if (password !== passwordConfirm) {
      clearPasswordChangeFields(form);
      setMessage(elements, "パスワードが一致しません。");
      return;
    }

    if (password.length < MIN_PASSWORD_LENGTH) {
      clearPasswordChangeFields(form);
      setMessage(elements, "パスワードは十分な長さで入力してください。");
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "変更中", "変更する");
      const { error } = await client.auth.updateUser({ password });
      clearPasswordChangeFields(form);

      if (error) {
        setMessage(elements, "パスワードを変更できませんでした。時間を置いて再度お試しください。");
        return;
      }

      renderAuthenticated(client, elements, "パスワードを変更しました。");
    } catch (error) {
      clearPasswordChangeFields(form);
      setMessage(elements, "パスワードを変更できませんでした。時間を置いて再度お試しください。");
    } finally {
      if (form.isConnected) setFormBusy(form, false, "変更中", "変更する");
    }
  }

  async function handleLogout(client, elements, button) {
    if (!window.confirm("ログアウトしますか？")) return;

    try {
      setMessage(elements, "");
      button.disabled = true;
      button.textContent = "ログアウト中";
      const { error } = await client.auth.signOut();

      if (error) {
        setMessage(elements, "ログアウトに失敗しました。時間を置いて再度お試しください。");
        button.disabled = false;
        button.textContent = "ログアウト";
        return;
      }

      removeNavLogoutButton();
      resetHeaderNotifications();
      renderAnonymous(client, elements);
    } catch (error) {
      setMessage(elements, "ログアウトに失敗しました。時間を置いて再度お試しください。");
      button.disabled = false;
      button.textContent = "ログアウト";
    }
  }

  function loadSupabaseSdk() {
    if (window.supabase && typeof window.supabase.createClient === "function") {
      return Promise.resolve();
    }

    if (window[SDK_LOAD_KEY]) {
      return window[SDK_LOAD_KEY];
    }

    window[SDK_LOAD_KEY] = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = SDK_SRC;
      script.async = true;
      script.crossOrigin = "anonymous";
      script.onload = () => {
        if (window.supabase && typeof window.supabase.createClient === "function") {
          resolve();
          return;
        }
        reject(new Error("supabase-sdk-unavailable"));
      };
      script.onerror = () => reject(new Error("supabase-sdk-load-failed"));
      document.head.appendChild(script);
    });

    return window[SDK_LOAD_KEY];
  }

  async function init(root) {
    const elements = findAccountElements(root || document);
    if (!elements) return { status: "missing-account-section" };
    if (elements.section.dataset.mypageAuthInitialized === "true") {
      return { status: "already-initialized" };
    }
    elements.section.dataset.mypageAuthInitialized = "true";
    ensureAuthElements(elements);

    const config = getConfig();
    if (!hasConfig(config)) {
      clearContent(elements);
      setStatus(
        elements,
        "アカウント機能は準備中です。",
        "接続設定が未構成のため、Supabaseには接続していません。"
      );
      setMessage(elements, "");
      return { status: "unconfigured" };
    }

    try {
      await loadSupabaseSdk();
      const client = window.supabase.createClient(config.url, config.anonKey);
      let passwordRecoveryMode = isPasswordRecoveryReturnUrl();
      client.auth.onAuthStateChange((event) => {
        if (event !== "PASSWORD_RECOVERY") return;
        passwordRecoveryMode = true;
        renderPasswordChangeForm(
          client,
          elements,
          "メール確認が完了しました。新しいパスワードを設定してください。"
        );
      });
      const { data, error } = await client.auth.getSession();

      if (error) {
        clearContent(elements);
        setStatus(
          elements,
          "セッションを確認できませんでした。",
          "時間を置いて再度お試しください。"
        );
        setMessage(elements, "");
        return { status: "session-error" };
      }

      if (data && data.session && passwordRecoveryMode) {
        renderPasswordChangeForm(
          client,
          elements,
          "メール確認が完了しました。新しいパスワードを設定してください。"
        );
        return { status: "password-recovery" };
      }

      if (data && data.session) {
        renderAuthenticated(client, elements, "", data.session);
        return { status: "authenticated" };
      }

      renderAnonymous(client, elements);
      return { status: "anonymous" };
    } catch (error) {
      clearContent(elements);
      setStatus(
        elements,
        "アカウント機能を初期化できませんでした。",
        "時間を置いて再度お試しください。"
      );
      setMessage(elements, "");
      return { status: "initialization-error" };
    }
  }

  function setupAutoInit() {
    if (!document.body || document.body.dataset.page !== "mypage") return;

    const app = document.querySelector("#app");
    if (!app) return;

    const runIfReady = () => {
      if (!findAccountElements(app)) return false;
      init(app);
      return true;
    };

    if (runIfReady()) return;

    const observer = new MutationObserver(() => {
      if (runIfReady()) observer.disconnect();
    });
    observer.observe(app, { childList: true, subtree: true });
  }

  window.VELGARD_MYPAGE_AUTH = {
    init
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setupAutoInit, { once: true });
  } else {
    setupAutoInit();
  }
})();
