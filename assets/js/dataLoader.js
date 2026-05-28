const cache = new Map();

export async function loadJson(path) {
  if (!cache.has(path)) {
    cache.set(path, fetch(path).then((response) => {
      if (!response.ok) throw new Error(`${path} を読み込めませんでした`);
      return response.json();
    }));
  }
  return cache.get(path);
}

export function isVisible(item, includePreparing = false) {
  return item && (item.status === "public" || (includePreparing && item.status === "preparing"));
}

export function imageOrPlaceholder(image, site, type) {
  return image && image.trim() ? image : site.placeholders[type];
}

export function imageFallbackAttr(site, type) {
  const fallback = site?.placeholders?.[type];
  return fallback ? `onerror="this.onerror=null;this.src='${fallback}'"` : "";
}

export function byId(items) {
  return new Map(items.map((item) => [item.id, item]));
}

export function getParams() {
  return new URLSearchParams(window.location.search);
}

export function textList(values) {
  return Array.isArray(values) && values.length ? values.join(" / ") : "未設定";
}
