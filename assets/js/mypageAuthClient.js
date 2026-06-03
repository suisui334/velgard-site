(function () {
  "use strict";

  const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
  const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
  const MIN_PASSWORD_LENGTH = 8;
  const DISPLAY_NAME_MAX_LENGTH = 40;
  const DISCORD_ID_MAX_LENGTH = 100;
  const PC_NAME_MAX_LENGTH = 40;
  const DISCORD_USER_ID_EXAMPLE = "123456789012345678";
  const DISCORD_USER_ID_PATTERN = /^\d{17,20}$/;
  const DISCORD_MENTION_INPUT_PATTERN = /^<@(\d{17,20})>$/;
  const DISCORD_USER_ID_FORMAT_MESSAGE = `DiscordユーザーIDは17〜20桁の数字で入力してください。\n入力例: ${DISCORD_USER_ID_EXAMPLE}`;
  const DISCORD_USER_ID_RECHECK_MESSAGE = `登録形式を確認してください。今後は ${DISCORD_USER_ID_EXAMPLE} のように17〜20桁の数字で登録してください。`;
  const SESSIONS_DATA_URL = "data/sessions.json?v=20260531-mypage-applications";
  const APPLICATION_SELECT_COLUMNS = "session_id,status,comment_id,created_at,updated_at,canceled_at";
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

  function getConfig() {
    const config = window.VELGARD_SUPABASE_CONFIG || {};
    return {
      url: typeof config.url === "string" ? config.url.trim() : "",
      anonKey: typeof config.anonKey === "string" ? config.anonKey.trim() : ""
    };
  }

  function hasConfig(config) {
    return Boolean(config.url && config.anonKey);
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

  function getSessionTitle(session) {
    return String(session && session.title ? session.title : "無題のセッション").trim();
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
    return { section, state, list, emptyText };
  }

  function createApplicationsPanel() {
    const container = document.createElement("div");
    container.className = "mypage-applications";
    container.dataset.mypageApplicationsPanel = "";

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

    container.append(pending.section, accepted.section);
    return { container, pending, accepted };
  }

  function setApplicationSectionState(section, message, options = {}) {
    section.list.replaceChildren();
    section.state.textContent = message;
    section.state.hidden = false;
    section.state.classList.toggle("is-error", Boolean(options.error));
  }

  function setApplicationsLoading(panel) {
    setApplicationSectionState(panel.pending, "読み込み中です。");
    setApplicationSectionState(panel.accepted, "読み込み中です。");
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
  }

  function showApplicationsLoadFailure(panel, error) {
    const message = "申請情報を取得できませんでした。時間を置いて再度お試しください。";
    setApplicationSectionState(panel.pending, message, { error: true });
    setApplicationSectionState(panel.accepted, message, { error: true });

    if (error) {
      console.warn("mypage applications load failed", {
        code: error?.code || "unknown",
        name: error?.name || "unknown",
        status: error?.status || "unknown"
      });
    }
  }

  async function fetchPublicSessionsMap() {
    const response = await fetch(SESSIONS_DATA_URL, { cache: "no-store" });
    if (!response.ok) throw new Error("sessions-json-load-failed");
    const data = await response.json();
    const sessions = Array.isArray(data && data.sessions) ? data.sessions : [];
    const map = new Map();
    sessions.filter(isPublicSession).forEach((session) => {
      map.set(session.id, session);
    });
    return map;
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
        renderApplicationItems(panel.pending, []);
        renderApplicationItems(panel.accepted, []);
        return;
      }

      const [applications, sessionsById] = await Promise.all([
        fetchOwnApplications(client, session),
        fetchPublicSessionsMap()
      ]);

      if (!panel.container.isConnected) return;
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

  function renderAnonymous(client, elements, message, mode = "login") {
    ensureAuthElements(elements);
    setStatus(
      elements,
      "ログインすると、今後ここで参加申請状況や参加予定を確認できるようになります。",
      ""
    );
    clearContent(elements);

    if (mode !== "reset") {
      elements.content.append(createAuthModeSwitch(client, elements, mode));
    }

    if (mode === "reset") {
      renderPasswordResetForm(client, elements);
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
    submit.textContent = "ログイン";

    form.append(
      createInputField("メールアドレス", emailInput),
      createInputField("パスワード", passwordInput),
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handleLogin(client, elements, form);
    });

    const forgotActions = document.createElement("div");
    forgotActions.className = "actions";

    const forgotPassword = document.createElement("button");
    forgotPassword.className = "button";
    forgotPassword.type = "button";
    forgotPassword.dataset.mypagePasswordResetOpen = "";
    forgotPassword.textContent = "パスワードを忘れた方はこちら";
    forgotPassword.addEventListener("click", () => {
      renderAnonymous(client, elements, "", "reset");
    });

    forgotActions.append(forgotPassword);
    elements.content.append(form, forgotActions);
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
    submit.textContent = "登録する";

    form.append(
      createInputField("ユーザー名", displayNameInput),
      createInputField("メールアドレス", emailInput),
      createInputField("パスワード", passwordInput),
      createInputField("パスワード確認", passwordConfirmInput),
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handleSignup(client, elements, form);
    });

    elements.content.append(form);
  }

  function renderPasswordResetForm(client, elements) {
    const form = document.createElement("form");
    form.className = "calendar-form";
    form.dataset.mypagePasswordResetForm = "";
    form.noValidate = true;

    const emailInput = document.createElement("input");
    emailInput.type = "email";
    emailInput.name = "email";
    emailInput.autocomplete = "username";
    emailInput.required = true;

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "submit";
    submit.dataset.mypagePasswordResetSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    submit.textContent = "再設定メールを送る";

    form.append(
      createInputField("メールアドレス", emailInput),
      submit
    );

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      handlePasswordReset(client, elements, form);
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

  function renderAuthenticated(client, elements, message, session) {
    ensureAuthElements(elements);
    setStatus(
      elements,
      "ログイン済みです。",
      "ユーザー名、PC名、DiscordユーザーID、参加申請中・参加予定セッションを確認できます。"
    );
    clearContent(elements);

    const displayNameEditor = createDisplayNameEditor(client, elements, session);
    const playerCharacterPanel = createPlayerCharacterPanel(client, elements, session);
    const discordIdEditor = createDiscordIdEditor(client, elements, session);
    const applicationsPanel = createApplicationsPanel();

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

    const logout = document.createElement("button");
    logout.className = "button";
    logout.type = "button";
    logout.dataset.mypageLogout = "";
    logout.textContent = "ログアウト";
    logout.addEventListener("click", () => {
      handleLogout(client, elements, logout);
    });

    actions.append(changePassword, logout);
    elements.content.append(
      displayNameEditor.container,
      playerCharacterPanel.container,
      discordIdEditor.container,
      actions,
      applicationsPanel.container
    );
    setMessage(elements, message || "");
    loadDisplayName(client, displayNameEditor);
    loadPlayerCharacters(client, playerCharacterPanel);
    loadProfileContact(client, discordIdEditor);
    loadApplications(client, applicationsPanel, session);
  }

  function renderPasswordChangeForm(client, elements, message) {
    ensureAuthElements(elements);
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

    const logout = document.createElement("button");
    logout.className = "button";
    logout.type = "button";
    logout.dataset.mypageLogout = "";
    logout.textContent = "ログアウト";
    logout.addEventListener("click", () => {
      handleLogout(client, elements, logout);
    });

    actions.append(back, logout);
    elements.content.append(form, actions);
    setMessage(elements, message || "");
  }

  async function handleLogin(client, elements, form) {
    const emailInput = form.querySelector('input[name="email"]');
    const passwordInput = form.querySelector('input[name="password"]');
    const email = emailInput ? emailInput.value.trim() : "";
    const password = passwordInput ? passwordInput.value : "";

    if (!email || !password || !emailInput.checkValidity()) {
      if (passwordInput) passwordInput.value = "";
      setMessage(elements, "ログインできませんでした。入力内容を確認してください。");
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "送信中", "ログイン");
      const { data, error } = await client.auth.signInWithPassword({ email, password });
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
      if (form.isConnected) setFormBusy(form, false, "送信中", "ログイン");
    }
  }

  async function handlePasswordReset(client, elements, form) {
    const emailInput = form.querySelector('input[name="email"]');
    const email = emailInput ? emailInput.value.trim() : "";

    if (!email || !emailInput.checkValidity()) {
      setMessage(elements, "入力内容を確認してください。");
      return;
    }

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "送信中", "再設定メールを送る");
      const { error } = await client.auth.resetPasswordForEmail(email, {
        redirectTo: getMypageRedirectUrl()
      });

      if (emailInput) emailInput.value = "";

      if (error) {
        setMessage(elements, "パスワード再設定メールを送信できませんでした。時間を置いて再度お試しください。");
        return;
      }

      setMessage(elements, "パスワード再設定メールを送信しました。届いたメールの案内に従ってください。");
    } catch (error) {
      if (emailInput) emailInput.value = "";
      setMessage(elements, "パスワード再設定メールを送信できませんでした。時間を置いて再度お試しください。");
    } finally {
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

  async function handleSignup(client, elements, form) {
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

    try {
      setMessage(elements, "");
      setFormBusy(form, true, "登録中", "登録する");
      const { data, error } = await client.auth.signUp({
        email,
        password,
        options: {
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
