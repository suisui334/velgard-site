(function () {
  "use strict";

  const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
  const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";
  const MIN_PASSWORD_LENGTH = 8;
  const DISPLAY_NAME_MAX_LENGTH = 40;

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
      createInputField("表示名", displayNameInput),
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
    currentLabel.textContent = "表示名：";

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
    displayNameInput.placeholder = "表示名を入力";

    const submit = document.createElement("button");
    submit.className = "button primary";
    submit.type = "button";
    submit.dataset.mypageDisplayNameSubmit = "";
    submit.dataset.mypageFormSubmit = "";
    submit.disabled = true;
    submit.textContent = "保存";

    form.append(
      createInputField("表示名", displayNameInput),
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
    setMessage(elements, "表示名を保存できませんでした。\nしばらくしても続く場合は、管理者へお知らせください。");

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
      setMessage(elements, "表示名を入力してください。");
      return;
    }

    if (countDisplayNameCharacters(nextDisplayName) > DISPLAY_NAME_MAX_LENGTH) {
      setMessage(elements, "表示名は40文字以内で入力してください。");
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
      setMessage(elements, "表示名を保存しました。");
    } catch (error) {
      showDisplayNameSaveFailure(elements, error);
    } finally {
      if (editor.form.isConnected) setFormBusy(editor.form, false, "保存中", "保存");
    }
  }

  function renderAuthenticated(client, elements, message, session) {
    ensureAuthElements(elements);
    setStatus(
      elements,
      "ログイン済みです。",
      "参加申請一覧・参加予定セッションは今後対応予定です。"
    );
    clearContent(elements);

    const displayNameEditor = createDisplayNameEditor(client, elements, session);

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
    elements.content.append(displayNameEditor.container, actions);
    setMessage(elements, message || "");
    loadDisplayName(client, displayNameEditor);
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
      setMessage(elements, "表示名を入力してください。");
      return;
    }

    if (countDisplayNameCharacters(displayName) > DISPLAY_NAME_MAX_LENGTH) {
      clearSignupPasswords(form);
      setMessage(elements, "表示名は40文字以内で入力してください。");
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
