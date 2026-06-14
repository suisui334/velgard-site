import { escapeHtml } from "./sessionDisplayHelpers.js?v=20260615-session-helper-extract";

export function renderSessionDetailRow(label, value, options = {}) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  const attrs = options.attrs ? ` ${options.attrs}` : "";
  return `
    <div${attrs}>
      <dt>${escapeHtml(label)}</dt>
      <dd>${escapeHtml(text)}</dd>
    </div>
  `;
}

export function renderSessionDetailArrayRow(label, values) {
  if (!Array.isArray(values) || !values.length) return "";
  const text = values.map((value) => String(value ?? "").trim()).filter(Boolean).join(" / ");
  return renderSessionDetailRow(label, text);
}
