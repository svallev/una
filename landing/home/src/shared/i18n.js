// Los textos de la página en español e inglés. Sin nada del navegador: lo usan la construcción
// (`landing/build.mjs`, en el idioma por defecto) y el programa (en el que detecta `locale.js`).
import es from './strings.es.json' with { type: 'json' };
import en from './strings.en.json' with { type: 'json' };
import { APP_NAME } from './config.js';
import { esc } from './html.js';

const DICT = { es, en };

/** El idioma del HTML que genera la construcción. */
export const DEFAULT_LANG = 'es';

/** El idioma de los textos (`t`). Lo cambia `useLang`. */
export let lang = DEFAULT_LANG;

export function useLang(next) {
  if (!Object.hasOwn(DICT, next)) throw new Error(`idioma desconocido: ${next}`);
  lang = next;
}

/** Igual que la app: español y catalán abren en español; el resto, en inglés. */
export const pickLang = (wanted) => (/^(es|ca)/i.test(wanted) ? 'es' : 'en');

const fill = (value, vars) =>
  String(value).replace(/\{(\w+)\}/g, (_, k) => (k === 'app' ? APP_NAME : vars?.[k] ?? `{${k}}`));

/** Texto de una clave con puntos ("scenes.hero.lead"). Las listas se devuelven como listas. */
export function t(key, vars) {
  const value = key.split('.').reduce((node, part) => node?.[part], DICT[lang]);
  if (value == null) return key;
  if (Array.isArray(value)) return value.map((v) => fill(v, vars));
  return fill(value, vars);
}

/** Titular: "|" separa líneas y *así* marca la palabra en 3D. */
export function parseTitle(key) {
  return t(key).split('|').map((line) =>
    line.split('*').map((text, i) => ({ text, strong: i % 2 === 1 })).filter((p) => p.text));
}

export function titleHtml(key) {
  return parseTitle(key).map((parts) =>
    `<span class="ln"><span class="ln__i">${parts.map((p) =>
      p.strong ? `<span class="x3d">${esc(p.text)}</span>` : esc(p.text)).join('')}</span></span>`).join(' ');
}

export function titleText(key) {
  return t(key).replace(/\*/g, '').replace(/\|/g, ' ');
}
