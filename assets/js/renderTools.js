import { loadJson } from "./dataLoader.js";

const HISTORY_STORAGE_KEY = "velgard.tools.rollHistory";

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[char]));
}

function rollDie(sides) {
  return Math.floor(Math.random() * sides) + 1;
}

function rollDice(dice) {
  const normalized = String(dice || "").toLowerCase();
  if (normalized === "1d36") {
    const total = rollDie(36);
    return { total, label: `1d36 = ${total}` };
  }
  if (normalized === "1d12") {
    const total = rollDie(12);
    return { total, label: `1d12 = ${total}` };
  }
  if (normalized === "1d2") {
    const total = rollDie(2);
    return { total, label: `1d2 = ${total}` };
  }
  if (normalized === "2d6") {
    const first = rollDie(6);
    const second = rollDie(6);
    const total = first + second;
    return { total, label: `2D6 = ${total}（${first} + ${second}）` };
  }
  throw new Error(`未対応のダイス形式です: ${dice || "未設定"}`);
}

function resultForRoll(table, roll) {
  return (table.results || []).find((item) => Number(item.roll) === Number(roll));
}

function visibleTables(tables) {
  return tables.filter((table) => !table.hidden && (table.type === "table" || table.type === "branch"));
}

function createTableMap(tables) {
  return new Map(tables.map((table) => [table.id, table]));
}

function formatCopyText(result) {
  const lines = [
    `表：${result.tableTitle}`
  ];
  if (result.branchLabel) {
    lines.push(`分岐：${result.branchLabel}`);
  }
  lines.push(`出目：${result.rollLabel}`);
  lines.push(`結果：${result.text}`);
  return lines.join("\n");
}

function formatHistoryCopyText(history) {
  return history.map((item) => formatCopyText(item)).join("\n\n---\n\n");
}

function normalizeHistoryItem(item) {
  if (!item || typeof item !== "object") return null;
  const tableTitle = String(item.tableTitle || "").trim();
  const rollLabel = String(item.rollLabel || "").trim();
  const text = String(item.text || "").trim();
  if (!tableTitle || !rollLabel || !text) return null;
  const branchLabel = String(item.branchLabel || "").trim();
  return {
    tableTitle,
    ...(branchLabel ? { branchLabel } : {}),
    rollLabel,
    text
  };
}

function loadStoredHistory() {
  try {
    const raw = window.localStorage.getItem(HISTORY_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.map(normalizeHistoryItem).filter(Boolean);
  } catch {
    return [];
  }
}

function saveStoredHistory(history) {
  try {
    window.localStorage.setItem(HISTORY_STORAGE_KEY, JSON.stringify(history.map(normalizeHistoryItem).filter(Boolean)));
    return true;
  } catch {
    return false;
  }
}

function clearStoredHistory() {
  try {
    window.localStorage.removeItem(HISTORY_STORAGE_KEY);
    return true;
  } catch {
    return false;
  }
}

function formatResult(result) {
  const branchHtml = result.branchLabel ? `<p><strong>分岐:</strong> ${escapeHtml(result.branchLabel)}</p>` : "";
  return `
    <article class="tool-result-card">
      <div class="card-meta"><span class="tag">${escapeHtml(result.tableTitle)}</span></div>
      ${branchHtml}
      <p><strong>出目:</strong> ${escapeHtml(result.rollLabel)}</p>
      <p class="tool-result-text">${escapeHtml(result.text)}</p>
      <div class="tool-copy-actions">
        <button class="button tool-copy-button" type="button" data-copy-current>結果をコピー</button>
      </div>
    </article>
  `;
}

function formatHistory(history) {
  return history.length ? history.map((item, index) => `
    <li>
      <div class="tool-history-item">
        <div class="tool-history-text">
          <span>${escapeHtml(item.tableTitle)}</span>
          ${item.branchLabel ? `<span>${escapeHtml(item.branchLabel)}</span>` : ""}
          <span>${escapeHtml(item.rollLabel)}</span>
          <strong>${escapeHtml(item.text)}</strong>
        </div>
        <button class="button tool-history-copy" type="button" data-copy-history="${index}">コピー</button>
      </div>
    </li>
  `).join("") : `<li class="tool-history-empty">まだ履歴はありません。</li>`;
}

function copyTextWithTextarea(text) {
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.top = "0";
  textarea.style.left = "-9999px";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();
  textarea.setSelectionRange(0, textarea.value.length);
  const copied = document.execCommand("copy");
  textarea.remove();
  return copied;
}

async function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch (error) {
      if (copyTextWithTextarea(text)) {
        return;
      }
      throw new Error("クリップボードへコピーできませんでした。ブラウザの権限設定を確認してください。");
    }
  }

  if (copyTextWithTextarea(text)) {
    return;
  }

  throw new Error("クリップボードへコピーできませんでした。");
}

function rollTable(selectedTable, tableMap) {
  if (selectedTable.type === "branch") {
    const branchRoll = rollDice(selectedTable.dice);
    const branch = (selectedTable.branches || []).find((item) => Number(item.roll) === Number(branchRoll.total));
    if (!branch) throw new Error("分岐先が見つかりませんでした。");
    const targetTable = tableMap.get(branch.tableId);
    if (!targetTable) throw new Error("分岐先の表データが見つかりませんでした。");
    const targetRoll = rollDice(targetTable.dice);
    const targetResult = resultForRoll(targetTable, targetRoll.total);
    if (!targetResult) throw new Error("出目に対応する結果が見つかりませんでした。");
    return {
      tableTitle: selectedTable.title,
      branchLabel: `${branchRoll.label} → ${branch.label || targetTable.title}`,
      rollLabel: targetRoll.label,
      text: targetResult.text || "結果本文が見つかりませんでした。"
    };
  }

  const roll = rollDice(selectedTable.dice);
  const result = resultForRoll(selectedTable, roll.total);
  if (!result) throw new Error("出目に対応する結果が見つかりませんでした。");
  return {
    tableTitle: selectedTable.title,
    rollLabel: roll.label,
    text: result.text || "結果本文が見つかりませんでした。"
  };
}

export async function renderTools(root) {
  const data = await loadJson("data/randomTables.json?v=20260529-calendar-date-tools-history");
  const tables = Array.isArray(data.tables) ? data.tables : [];
  const tableMap = createTableMap(tables);
  const options = visibleTables(tables);

  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Tools</div>
      <h1>TOOLS</h1>
      <p class="lead">ランダム表やGM補助用の小道具を置く補助ページです。現在はランダム表のみ利用できます。</p>
    </header>
    <section class="section tools-section">
      <div class="article-box tool-panel">
        <label class="tool-select-label" for="random-table-select">
          <span>表を選択</span>
          <select id="random-table-select">
            ${options.map((table) => `<option value="${escapeHtml(table.id)}">${escapeHtml(table.title)}</option>`).join("")}
          </select>
        </label>
        <button class="button primary" type="button" id="random-table-roll">振る</button>
      </div>
      <div class="article-box tool-result" aria-live="polite">
        <h2>結果</h2>
        <div id="random-table-result" class="tool-result-body empty">表を選んで「振る」を押してください。</div>
        <p id="tool-copy-status" class="tool-copy-status" aria-live="polite"></p>
      </div>
      <div class="article-box tool-history">
        <div class="tool-history-head">
          <h2>直近履歴</h2>
          <div class="tool-history-actions">
            <button class="button tool-history-copy-all" type="button" id="random-table-history-copy-all" disabled>履歴をまとめてコピー</button>
            <button class="button tool-history-reset" type="button" id="random-table-history-reset" disabled>履歴をすべて削除</button>
          </div>
        </div>
        <ol id="random-table-history"></ol>
      </div>
    </section>
  `;

  const select = root.querySelector("#random-table-select");
  const button = root.querySelector("#random-table-roll");
  const resultArea = root.querySelector("#random-table-result");
  const historyList = root.querySelector("#random-table-history");
  const historyCopyAll = root.querySelector("#random-table-history-copy-all");
  const historyReset = root.querySelector("#random-table-history-reset");
  const copyStatus = root.querySelector("#tool-copy-status");
  const history = loadStoredHistory();
  let currentResult = null;

  const drawHistory = () => {
    historyList.innerHTML = formatHistory(history);
    historyCopyAll.disabled = !history.length;
    historyReset.disabled = !history.length;
  };

  const showError = (message) => {
    currentResult = null;
    resultArea.classList.remove("empty");
    resultArea.innerHTML = `<div class="notice">${escapeHtml(message)}</div>`;
  };

  const showCopyStatus = (message, isError = false) => {
    copyStatus.textContent = message;
    copyStatus.classList.toggle("is-error", isError);
  };

  const markCopied = (copyButton) => {
    const originalText = copyButton.textContent;
    copyButton.textContent = "コピー済み";
    copyButton.disabled = true;
    window.setTimeout(() => {
      copyButton.textContent = originalText;
      copyButton.disabled = false;
    }, 1200);
  };

  const handleCopy = async (result, copyButton) => {
    if (!result) {
      showCopyStatus("コピーできる結果がありません。", true);
      return;
    }

    try {
      await copyText(formatCopyText(result));
      showCopyStatus("コピーしました。");
      markCopied(copyButton);
    } catch (error) {
      showCopyStatus(error.message || "コピーに失敗しました。", true);
    }
  };

  const handleCopyHistoryAll = async (copyButton) => {
    if (!history.length) {
      showCopyStatus("コピーできる履歴がありません。", true);
      return;
    }

    try {
      await copyText(formatHistoryCopyText(history));
      showCopyStatus("履歴をまとめてコピーしました。");
      markCopied(copyButton);
    } catch (error) {
      showCopyStatus(error.message || "履歴のコピーに失敗しました。", true);
    }
  };

  button.addEventListener("click", () => {
    const selectedTable = tableMap.get(select.value);
    if (!selectedTable) {
      showError("表データが見つかりませんでした。");
      return;
    }

    try {
      const result = rollTable(selectedTable, tableMap);
      currentResult = result;
      showCopyStatus("");
      resultArea.classList.remove("empty");
      resultArea.innerHTML = formatResult(result);
      history.unshift(result);
      if (!saveStoredHistory(history)) {
        showCopyStatus("履歴を保存できませんでした。ブラウザの保存領域を確認してください。", true);
      }
      drawHistory();
    } catch (error) {
      showError(error.message || "ランダム表の処理に失敗しました。");
    }
  });

  resultArea.addEventListener("click", (event) => {
    const copyButton = event.target.closest("[data-copy-current]");
    if (!copyButton) return;
    handleCopy(currentResult, copyButton);
  });

  historyList.addEventListener("click", (event) => {
    const copyButton = event.target.closest("[data-copy-history]");
    if (!copyButton) return;
    const historyIndex = Number(copyButton.dataset.copyHistory);
    handleCopy(history[historyIndex], copyButton);
  });

  historyCopyAll.addEventListener("click", () => {
    handleCopyHistoryAll(historyCopyAll);
  });

  historyReset.addEventListener("click", () => {
    if (!history.length) {
      showCopyStatus("削除する履歴がありません。", true);
      return;
    }
    if (!window.confirm("履歴をすべて削除します。よろしいですか？")) return;
    history.splice(0, history.length);
    const cleared = clearStoredHistory();
    drawHistory();
    showCopyStatus(cleared ? "履歴をすべて削除しました。" : "画面上の履歴を削除しました。保存履歴の削除には失敗しました。", !cleared);
  });

  drawHistory();
}
