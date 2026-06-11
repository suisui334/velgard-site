import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js";

const TIMELINE_LIMIT = 50;
const FALLBACK_TARGET = "calendar.html";

const EVENT_TYPE_LABELS = {
  session_comment: "コメント",
  session_application: "コメント",
  application_status_changed: "申請状況",
  session_created: "依頼書登録",
  session_post_created: "依頼書登録",
  session_updated: "依頼書更新"
};
const COMMENT_EVENT_TYPES = new Set(["session_comment", "session_application"]);
const SESSION_CREATED_EVENT_TYPES = new Set(["session_created", "session_post_created"]);

const VISIBILITY_LABELS = {
  public: "公開",
  authenticated: "ログイン限定",
  private: "限定"
};

function normalizeTargetPath(value) {
  const target = typeof value === "string" ? value.trim() : "";
  if (!target) return FALLBACK_TARGET;
  if (/[\r\n]/.test(target)) return FALLBACK_TARGET;
  if (/^[a-z][a-z0-9+.-]*:/i.test(target)) return FALLBACK_TARGET;
  if (target.startsWith("//")) return FALLBACK_TARGET;
  if (target.includes("..")) return FALLBACK_TARGET;
  return target.replace(/^\/+/, "") || FALLBACK_TARGET;
}

function getEventTypeLabel(type) {
  return EVENT_TYPE_LABELS[type] || "更新";
}

function getActorLabel(item) {
  const name = typeof item?.actor_display_name === "string" ? item.actor_display_name.trim() : "";
  if (!name) return "ユーザーさん";
  return /(?:さん|様|くん|ちゃん)$/.test(name) ? name : `${name}さん`;
}

function getSessionTitle(item) {
  const title = typeof item?.session_title === "string" ? item.session_title.trim() : "";
  return title || "タイトル未設定";
}

function getTimelineTitle(item) {
  const actor = getActorLabel(item);
  if (COMMENT_EVENT_TYPES.has(item?.event_type)) {
    return `${actor}がコメントしました`;
  }
  if (SESSION_CREATED_EVENT_TYPES.has(item?.event_type)) {
    return `${actor}が依頼書を登録しました`;
  }
  return `${actor}が更新しました`;
}

function getVisibilityLabel(visibility) {
  return VISIBILITY_LABELS[visibility] || "";
}

function formatDateTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

function setStatus(statusElement, message, isError = false) {
  statusElement.textContent = message;
  statusElement.hidden = !message;
  statusElement.classList.toggle("is-error", isError);
}

async function waitForAuthBootstrap(client) {
  try {
    await client.auth.getSession();
  } catch {
    // Timeline can still show public activity if auth restoration is unavailable.
  }
}

function createTextElement(tagName, className, text) {
  const element = document.createElement(tagName);
  element.className = className;
  element.textContent = text || "";
  return element;
}

function createTimelineCard(item) {
  const article = document.createElement("article");
  article.className = "timeline-card";

  const head = document.createElement("div");
  head.className = "timeline-card__head";

  const type = createTextElement("span", "timeline-card__type", getEventTypeLabel(item?.event_type));
  head.append(type);

  const visibilityText = getVisibilityLabel(item?.visibility);
  if (visibilityText) {
    head.append(createTextElement("span", "timeline-card__visibility", visibilityText));
  }

  const timeText = formatDateTime(item?.created_at);
  if (timeText) {
    const time = document.createElement("time");
    time.className = "timeline-card__time";
    time.dateTime = item.created_at;
    time.textContent = timeText;
    head.append(time);
  }

  const title = createTextElement("h2", "timeline-card__title", getTimelineTitle(item));

  const metaItems = [];
  metaItems.push(`依頼書：${getSessionTitle(item)}`);

  const footer = document.createElement("div");
  footer.className = "timeline-card__footer";

  if (metaItems.length) {
    footer.append(createTextElement("span", "timeline-card__meta", metaItems.join(" / ")));
  }

  const link = document.createElement("a");
  link.className = "button timeline-card__link";
  link.href = normalizeTargetPath(item?.target_path);
  link.textContent = "詳細を見る";
  footer.append(link);

  article.append(head, title, footer);
  return article;
}

function renderEmpty(listElement) {
  listElement.innerHTML = "";
  const empty = document.createElement("div");
  empty.className = "timeline-empty";
  empty.textContent = "まだ更新はありません。";
  listElement.append(empty);
}

function renderItems(listElement, items) {
  listElement.innerHTML = "";
  const fragment = document.createDocumentFragment();
  items.forEach((item) => {
    fragment.append(createTimelineCard(item));
  });
  listElement.append(fragment);
}

export async function renderTimeline(root) {
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">TIMELINE</div>
      <h1>更新タイムライン</h1>
      <p class="lead">コメント、申請、依頼書まわりの公開できる更新を、GM/PL共通で新しい順に確認できます。</p>
    </header>
    <section class="section timeline-section" aria-labelledby="timeline-heading">
      <div class="timeline-toolbar">
        <div>
          <h2 id="timeline-heading">最近の更新</h2>
          <p>通知ベルは自分宛ての非公開通知、こちらは共有できる活動一覧です。</p>
        </div>
      </div>
      <p class="timeline-status" data-timeline-status>読み込み中です。</p>
      <div class="timeline-list" data-timeline-list></div>
    </section>
  `;

  const status = root.querySelector("[data-timeline-status]");
  const list = root.querySelector("[data-timeline-list]");
  const client = await createSupabaseBrowserClient();

  if (!client) {
    setStatus(status, "タイムラインを読み込む設定が見つかりませんでした。", true);
    renderEmpty(list);
    return;
  }

  await waitForAuthBootstrap(client);
  const { data, error } = await client.rpc("get_activity_timeline", { p_limit: TIMELINE_LIMIT });
  if (error) {
    setStatus(status, "タイムラインを読み込めませんでした。時間をおいて再度お試しください。", true);
    renderEmpty(list);
    return;
  }

  const items = Array.isArray(data) ? data : [];
  setStatus(status, "");
  if (!items.length) {
    renderEmpty(list);
    return;
  }
  renderItems(list, items);
}
