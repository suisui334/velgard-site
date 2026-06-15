import { escapeHtml } from "./sessionDisplayHelpers.js?v=20260615-session-helper-extract";

export function renderTextField(label, name, type, options = {}) {
  const attrs = [
    `type="${escapeHtml(type)}"`,
    `name="${escapeHtml(name)}"`,
    options.required ? "required" : "",
    options.maxlength ? `maxlength="${Number(options.maxlength)}"` : "",
    Number.isFinite(Number(options.min)) ? `min="${Number(options.min)}"` : "",
    typeof options.value === "string" ? `value="${escapeHtml(options.value)}"` : "",
    options.placeholder ? `placeholder="${escapeHtml(options.placeholder)}"` : ""
  ].filter(Boolean).join(" ");
  return `
    <label class="session-post-field">
      <span>${escapeHtml(label)}</span>
      <input ${attrs}>
    </label>
  `;
}

export function renderSelectField(label, name, options, selectedValue) {
  return `
    <label class="session-post-field">
      <span>${escapeHtml(label)}</span>
      <select name="${escapeHtml(name)}">
        ${options.map(([value, text]) => `<option value="${escapeHtml(value)}"${value === selectedValue ? " selected" : ""}>${escapeHtml(text)}</option>`).join("")}
      </select>
    </label>
  `;
}

export function renderTextareaField(label, name, maxlength) {
  return `
    <label class="session-post-field session-post-field--wide">
      <span>${escapeHtml(label)}</span>
      <textarea name="${escapeHtml(name)}" maxlength="${Number(maxlength)}" rows="5"></textarea>
    </label>
  `;
}
