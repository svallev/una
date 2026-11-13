// El idioma en el navegador: cuál se pide (dirección, preferencia guardada o idioma del sistema), cómo se
// cambia y el título de la pestaña. Lee `location`, `navigator` y `localStorage` solo al llamarse.
import { lang, pickLang, t } from './i18n.js';

const KEY = 'una-lang';

export function detectLang() {
  const fromUrl = new URLSearchParams(location.search).get('lang');
  let stored = null;
  try { stored = localStorage.getItem(KEY); } catch { /* sin almacenamiento */ }
  return pickLang(fromUrl || stored || navigator.language || 'es');
}

export function setLang(next) {
  if (next === lang) return;
  try { localStorage.setItem(KEY, next); } catch { /* sin almacenamiento */ }
  const url = new URL(location.href);
  url.searchParams.delete('lang');
  location.replace(url);
}

export function applyMeta() {
  document.title = t('meta.title');
  document.querySelector('meta[name="description"]')?.setAttribute('content', t('meta.description'));
}
