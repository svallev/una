import es from './strings.es.json';
import en from './strings.en.json';
import { APP_NAME } from './config.js';

const DICT = { es, en };
const KEY = 'una-lang';

function detect() {
  const fromUrl = new URLSearchParams(location.search).get('lang');
  let stored = null;
  try { stored = localStorage.getItem(KEY); } catch { /* sin almacenamiento */ }
  const wanted = fromUrl || stored || navigator.language || 'es';
  // Igual que la app: español y catalán abren en español; el resto, en inglés.
  return /^(es|ca)/i.test(wanted) ? 'es' : 'en';
}

export const lang = detect();
document.documentElement.lang = lang;

const fill = (value, vars) =>
  String(value).replace(/\{(\w+)\}/g, (_, k) => (k === 'app' ? APP_NAME : vars?.[k] ?? `{${k}}`));

/** Texto de una clave con puntos ("scenes.hero.lead"). Las listas se devuelven como listas. */
export function t(key, vars) {
  const value = key.split('.').reduce((node, part) => node?.[part], DICT[lang]);
  if (value == null) return key;
  if (Array.isArray(value)) return value.map((v) => fill(v, vars));
  return fill(value, vars);
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

const escapeHtml = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

/** Titular: "|" separa líneas y *así* marca la palabra en 3D. */
export function parseTitle(key) {
  return t(key).split('|').map((line) =>
    line.split('*').map((text, i) => ({ text, strong: i % 2 === 1 })).filter((p) => p.text));
}

export function titleHtml(key) {
  return parseTitle(key).map((parts) =>
    `<span class="ln"><span class="ln__i">${parts.map((p) =>
      p.strong ? `<span class="x3d">${escapeHtml(p.text)}</span>` : escapeHtml(p.text)).join('')}</span></span>`).join(' ');
}

export function titleText(key) {
  return t(key).replace(/\*/g, '').replace(/\|/g, ' ');
}
