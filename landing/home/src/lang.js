// Idioma de la página de inicio (spec 025, CA-025-09; CL-025-3, 4 y 16; plan §3). Funciones puras: el
// almacenamiento, los idiomas del navegador y el documento llegan como argumentos, para probarlas sin navegador.
//
// La regla es la de la app (CA-010-02): se recorre la lista de idiomas preferidos y el primero que sea
// español o catalán abre en español, el primero que sea inglés abre en inglés; si no hay ninguno, inglés. La
// elección guardada manda sobre el navegador. Lo guardado es un dato no confiable (P5): solo vale si es
// exactamente `es` o `en`, comparado por igualdad, nunca como clave de objeto ni como selector.

/** Los idiomas de la página. */
export const LANGS = Object.freeze(["es", "en"]);

/** La única clave que la página guarda en el navegador (plan §3). */
export const LANG_KEY = "lang";

const isLang = (value) => value === "es" || value === "en";

/** El idioma que toca según la lista de idiomas preferidos del navegador (`navigator.languages`). */
export function langFromList(list) {
  for (const tag of Array.isArray(list) ? list : []) {
    if (typeof tag !== "string") continue;
    const primary = tag.trim().toLowerCase().split(/[-_]/)[0];
    if (primary === "es" || primary === "ca") return "es";
    if (primary === "en") return "en";
  }
  return "en";
}

/**
 * El almacenamiento del navegador, o `null` si no se puede usar: en algunos navegadores leer
 * `window.localStorage` ya lanza un error con el almacenamiento bloqueado (CL-025-3).
 */
export function browserStorage(win) {
  try {
    return win?.localStorage ?? null;
  } catch {
    return null;
  }
}

/** El idioma guardado, o `null` si no hay, si no se puede leer o si no es un valor válido (CL-025-16). */
export function storedLang(storage) {
  let value;
  try {
    value = storage?.getItem(LANG_KEY);
  } catch {
    return null;
  }
  return isLang(value) ? value : null;
}

/** Guarda la elección; si no se puede (CL-025-3), no pasa nada: solo no se recordará. Devuelve si se guardó. */
export function saveLang(storage, lang) {
  if (!isLang(lang) || !storage) return false;
  try {
    storage.setItem(LANG_KEY, lang);
    return true;
  } catch {
    return false;
  }
}

/**
 * El idioma de la página: el guardado (si es válido) o la regla con los idiomas del navegador. Si el navegador
 * no da la lista, se usa su idioma principal (`navigator.language`).
 */
export function pickLang({ storage = null, languages = undefined, language = undefined } = {}) {
  const stored = storedLang(storage);
  if (stored) return stored;
  const list = Array.isArray(languages) && languages.length > 0 ? languages : typeof language === "string" ? [language] : [];
  return langFromList(list);
}

/** Un texto con su marcador `{appName}` relleno (los textos de la página no llevan otros), sin interpretar `$&` ni `$1` del nombre. */
export const withName = (text, appName) => String(text).replaceAll("{appName}", () => appName);

/** Lo que se lee de un titular: sin la marca de la palabra destacada (`*`) ni los saltos de línea (`|`). */
export const plainTitle = (text) => String(text).replaceAll("*", "").split("|").map((s) => s.trim()).join(" ");

/**
 * Declara el idioma en el documento (para el lector de pantalla y el buscador) y pone el título y la
 * descripción de ese idioma. `strings` son los textos de ese idioma (`strings.<lang>.json`).
 */
export function applyLang(doc, lang, strings, appName) {
  if (!isLang(lang)) throw new Error(`idioma no válido: ${lang}`);
  doc.documentElement.lang = lang;
  doc.title = withName(strings.metaTitle, appName);
  doc.querySelector('meta[name="description"]')?.setAttribute("content", withName(strings.metaDescription, appName));
}
