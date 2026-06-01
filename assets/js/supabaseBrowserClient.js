const SDK_SRC = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
const SDK_LOAD_KEY = "__VELGARD_SUPABASE_SDK_LOAD";

export function getSupabaseRuntimeConfig() {
  const config = window.VELGARD_SUPABASE_CONFIG || {};
  return {
    url: typeof config.url === "string" ? config.url.trim() : "",
    anonKey: typeof config.anonKey === "string" ? config.anonKey.trim() : ""
  };
}

export function hasSupabaseRuntimeConfig(config = getSupabaseRuntimeConfig()) {
  return Boolean(config.url && config.anonKey);
}

export function loadSupabaseSdk() {
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

export async function createSupabaseBrowserClient() {
  const config = getSupabaseRuntimeConfig();
  if (!hasSupabaseRuntimeConfig(config)) return null;
  await loadSupabaseSdk();
  return window.supabase.createClient(config.url, config.anonKey, {
    auth: {
      detectSessionInUrl: false
    }
  });
}
