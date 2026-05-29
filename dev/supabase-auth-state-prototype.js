const $ = (selector) => document.querySelector(selector);

const refs = {
  url: $("#supabase-url"),
  key: $("#supabase-key"),
  email: $("#login-email"),
  password: $("#login-password"),
  checkState: $("#check-state"),
  clear: $("#clear-inputs"),
  login: $("#login"),
  logout: $("#logout"),
  status: $("#connection-status"),
  authState: $("#auth-state-result"),
  profile: $("#profile-result"),
  errors: $("#error-result"),
};

let activeClient = null;
let activeClientSignature = "";

function formatSupabaseError(error) {
  if (!error) return "unknown error";
  if (typeof error === "string") return redactSensitive(error);

  const parts = [
    error.message && `message=${error.message}`,
    error.code && `code=${error.code}`,
    error.details && `details=${error.details}`,
    error.hint && `hint=${error.hint}`,
    error.status && `status=${error.status}`,
    error.name && `name=${error.name}`,
  ].filter(Boolean);

  return redactSensitive(parts.join(" | ") || "unknown error object");
}

function redactSensitive(value) {
  let text = String(value ?? "");
  const directValues = [
    refs.url?.value,
    refs.key?.value,
    refs.password?.value,
  ].filter(Boolean);

  for (const directValue of directValues) {
    text = text.split(directValue).join("[redacted]");
  }

  return text
    .replace(/https:\/\/[a-z0-9.-]+\.supabase\.co/gi, "[redacted-url]")
    .replace(/\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, "[redacted-token]")
    .replace(/\b[A-Za-z0-9_-]{80,}\b/g, "[redacted-long-value]");
}

function setStatus(message, type = "") {
  refs.status.textContent = message;
  refs.status.className = `status ${type}`.trim();
}

function setEmpty(target, message) {
  target.replaceChildren();
  const paragraph = document.createElement("p");
  paragraph.className = "empty";
  paragraph.textContent = message;
  target.append(paragraph);
}

function renderErrorList(errors) {
  refs.errors.replaceChildren();
  if (!errors.length) {
    setEmpty(refs.errors, "エラーはありません。");
    return;
  }

  const list = document.createElement("ul");
  list.className = "error-list";
  for (const error of errors) {
    const item = document.createElement("li");
    item.textContent = redactSensitive(error);
    list.append(item);
  }
  refs.errors.append(list);
}

function renderState(rows) {
  refs.authState.replaceChildren();
  const card = document.createElement("div");
  card.className = "state-card";
  const dl = document.createElement("dl");

  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = value || "未取得";
    dl.append(dt, dd);
  }

  card.append(dl);
  refs.authState.append(card);
}

function renderProfile(message, type = "") {
  refs.profile.replaceChildren();
  const paragraph = document.createElement("p");
  paragraph.className = type ? `status ${type}` : "status";
  paragraph.textContent = message;
  refs.profile.append(paragraph);
}

function validateConnectionInputs() {
  const url = refs.url.value.trim();
  const key = refs.key.value.trim();
  const joined = `${url} ${key}`;

  if (!url) throw new Error("Supabase URLを入力してください。");
  if (!key) throw new Error("Publishable / anon keyを入力してください。");
  if (/service[_-]?role|secret|sb_secret|postgresql:\/\//i.test(joined)) {
    throw new Error("service role / secret key / Direct connection string らしき値は入力しないでください。");
  }
  if (!window.supabase?.createClient) {
    throw new Error("Supabase clientライブラリを読み込めませんでした。");
  }

  return { url, key };
}

function getClient() {
  const { url, key } = validateConnectionInputs();
  const signature = `${url.length}:${key.length}:${url.slice(0, 8)}:${key.slice(0, 8)}`;

  if (activeClient && activeClientSignature === signature) {
    return activeClient;
  }

  activeClient = window.supabase.createClient(url, key, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  });
  activeClientSignature = signature;
  return activeClient;
}

async function fetchDisplayName(client, user) {
  if (!user?.id) return { displayName: "", error: null };

  const { data, error } = await client
    .from("public_profiles")
    .select("display_name")
    .eq("id", user.id)
    .maybeSingle();

  if (error) return { displayName: "", error };
  return { displayName: data?.display_name || "", error: null };
}

async function refreshAuthState(reason = "manual") {
  const errors = [];
  setStatus("ログイン状態を確認しています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) {
      throw new Error(`セッション確認失敗: ${formatSupabaseError(sessionError)}`);
    }

    const { data: userData, error: userError } = await client.auth.getUser();
    if (userError && sessionData?.session) {
      throw new Error(`ユーザー確認失敗: ${formatSupabaseError(userError)}`);
    }

    const user = userData?.user || null;
    if (!user) {
      renderState([
        ["状態", "未ログイン"],
        ["メールアドレス", ""],
        ["セッション復元", sessionData?.session ? "セッションあり / ユーザー未取得" : "なし"],
      ]);
      renderProfile("ログイン後に public_profiles.display_name を確認します。");
      setStatus("未ログインです。ログインするか、接続値入力後に再読込復元を確認してください。", "warn");
      return;
    }

    const { displayName, error: profileError } = await fetchDisplayName(client, user);
    if (profileError) {
      errors.push(`public_profiles取得失敗: ${formatSupabaseError(profileError)}`);
    }

    renderState([
      ["状態", "ログイン済み"],
      ["メールアドレス", user.email || ""],
      ["セッション復元", sessionData?.session && reason === "manual" ? "確認済み" : "ログイン操作で確認"],
    ]);
    renderProfile(
      displayName
        ? `public_profiles.display_name: ${displayName}`
        : "public_profiles.display_name は未取得または未設定です。",
      displayName ? "ok" : "warn"
    );
    setStatus("ログイン状態を確認しました。user_id / token / discord_user_id は表示していません。", errors.length ? "warn" : "ok");
  } catch (error) {
    errors.push(error.message || String(error));
    renderState([
      ["状態", "確認失敗"],
      ["メールアドレス", ""],
      ["セッション復元", "未確認"],
    ]);
    renderProfile("表示名は取得していません。", "warn");
    setStatus("ログイン状態の確認に失敗しました。", "error");
  } finally {
    renderErrorList(errors);
  }
}

async function login() {
  const errors = [];
  setStatus("ログインしています。", "warn");
  renderErrorList([]);

  try {
    const email = refs.email.value.trim();
    const password = refs.password.value;
    if (!email) throw new Error("Emailを入力してください。");
    if (!password) throw new Error("Passwordを入力してください。");

    const client = getClient();
    const { error } = await client.auth.signInWithPassword({ email, password });
    refs.password.value = "";

    if (error) throw new Error(`ログイン失敗: ${formatSupabaseError(error)}`);
    await refreshAuthState("login");
  } catch (error) {
    errors.push(error.message || String(error));
    refs.password.value = "";
    renderErrorList(errors);
    setStatus("ログインに失敗しました。", "error");
  }
}

async function logout() {
  const errors = [];
  setStatus("ログアウトしています。", "warn");
  renderErrorList([]);

  try {
    const client = getClient();
    const { error } = await client.auth.signOut();
    if (error) throw new Error(`ログアウト失敗: ${formatSupabaseError(error)}`);
    refs.password.value = "";
    renderState([
      ["状態", "未ログイン"],
      ["メールアドレス", ""],
      ["セッション復元", "ログアウト済み"],
    ]);
    renderProfile("ログアウトしました。", "ok");
    setStatus("ログアウトしました。検証後はこの状態にしてください。", "ok");
  } catch (error) {
    errors.push(error.message || String(error));
    renderErrorList(errors);
    setStatus("ログアウトに失敗しました。", "error");
  }
}

function clearInputs() {
  refs.url.value = "";
  refs.key.value = "";
  refs.email.value = "";
  refs.password.value = "";
  setStatus("入力をクリアしました。Authセッション削除ではありません。必要ならログアウトしてください。");
  setEmpty(refs.authState, "まだ確認していません。");
  setEmpty(refs.profile, "まだ取得していません。");
  renderErrorList([]);
  activeClient = null;
  activeClientSignature = "";
}

refs.checkState.addEventListener("click", () => {
  refreshAuthState("manual");
});

refs.login.addEventListener("click", () => {
  login();
});

refs.logout.addEventListener("click", () => {
  logout();
});

refs.clear.addEventListener("click", clearInputs);
