import { createSupabaseBrowserClient } from "./supabaseBrowserClient.js";
import {
  getCurrentMembershipState,
  isApprovedMembershipState,
  renderMembershipGateNotice
} from "./membershipAccessClient.js?v=20260615-session-gate-labels";
import {
  formatActivityDateTime,
  getActivitySessionLabel,
  getActivityTitle,
  getActivityTypeLabel,
  getActivityVisibilityLabel,
  normalizeActivityTargetPath
} from "./activityTimelineDisplay.js?v=20260611-home-activity";

const TIMELINE_LIMIT = 50;

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

  const type = createTextElement("span", "timeline-card__type", getActivityTypeLabel(item?.event_type));
  head.append(type);

  const visibilityText = getActivityVisibilityLabel(item?.visibility);
  if (visibilityText) {
    head.append(createTextElement("span", "timeline-card__visibility", visibilityText));
  }

  const timeText = formatActivityDateTime(item?.created_at, { includeYear: true });
  if (timeText) {
    const time = document.createElement("time");
    time.className = "timeline-card__time";
    time.dateTime = item.created_at;
    time.textContent = timeText;
    head.append(time);
  }

  const title = createTextElement("h2", "timeline-card__title", getActivityTitle(item));

  const metaItems = [];
  metaItems.push(getActivitySessionLabel(item));

  const footer = document.createElement("div");
  footer.className = "timeline-card__footer";

  if (metaItems.length) {
    footer.append(createTextElement("span", "timeline-card__meta", metaItems.join(" / ")));
  }

  const link = document.createElement("a");
  link.className = "button timeline-card__link";
  link.href = normalizeActivityTargetPath(item?.target_path);
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

export async function renderTimeline(root, _site, options = {}) {
  const membershipState = options.membershipState || await getCurrentMembershipState();
  if (!isApprovedMembershipState(membershipState)) {
    root.innerHTML = renderMembershipGateNotice(membershipState, {
      eyebrow: "TIMELINE",
      title: "更新タイムライン",
      lead: "更新タイムラインは承認済みメンバー向けの活動一覧です。",
      heading: "承認後にTIMELINEを確認できます"
    });
    return;
  }

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
