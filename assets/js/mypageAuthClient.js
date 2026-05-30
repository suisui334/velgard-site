(function () {
  "use strict";

  const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
  const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";

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
      detail: section.querySelector("[data-mypage-auth-detail]") || paragraphs[1] || null
    };
  }

  function setStatus(elements, primaryText, detailText) {
    if (!elements) return;
    if (elements.primary) elements.primary.textContent = primaryText;
    if (elements.detail) elements.detail.textContent = detailText;
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

    const config = getConfig();
    if (!hasConfig(config)) {
      setStatus(
        elements,
        "アカウント機能は準備中です。",
        "接続設定が未構成のため、Supabaseには接続していません。"
      );
      return { status: "unconfigured" };
    }

    try {
      await loadSupabaseSdk();
      const client = window.supabase.createClient(config.url, config.anonKey);
      const { data, error } = await client.auth.getSession();

      if (error) {
        setStatus(
          elements,
          "セッションを確認できませんでした。",
          "時間を置いて再度お試しください。"
        );
        return { status: "session-error" };
      }

      if (data && data.session) {
        setStatus(
          elements,
          "ログイン状態を確認しました。",
          "表示名や参加申請一覧は今後対応予定です。"
        );
        return { status: "authenticated" };
      }

      setStatus(
        elements,
        "現在ログインしていません。",
        "ログイン機能は次の工程で対応予定です。"
      );
      return { status: "anonymous" };
    } catch (error) {
      setStatus(
        elements,
        "アカウント機能の初期化に失敗しました。",
        "時間を置いて再度お試しください。"
      );
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
