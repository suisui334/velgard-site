export function formatPlayerCountLabel(playerMin, playerMax) {
  const min = Number.isFinite(playerMin) ? playerMin : null;
  const max = Number.isFinite(playerMax) ? playerMax : null;
  if (min !== null && max !== null) return `${min}〜${max}名`;
  if (max !== null) return `最大${max}名`;
  if (min !== null) return `最低${min}名`;
  return "未設定";
}
