// Cabecera y pie de la página de inicio (spec 025; plan §2 y §6.2), traídos de la maqueta (`chrome.js`) con lo
// que la spec corrige: el logotipo y el nombre salen de `gen/site.json` (de la identidad, CA-025-14), el pie
// lleva también Licencias (CA-025-20, Q-025-12), los botones ES / EN tienen nombre para el lector, cada uno en su
// idioma (Q-025-6), y todo texto pasa por `esc` (plan §6.1). Funciones puras que devuelven HTML: el programa
// las inserta (`fragment`) y conecta los botones (`wireLangButtons`).
//
// Destinos (CA-025-20): el logotipo vuelve a la portada (`/`) y «Descargar» lleva al cierre (`/#download`, la
// dirección que se comparte para abrir en el cierre, CL-025-2); Ayuda, Privacidad y Licencias abren las páginas
// de la misma web. Ningún enlace a otro sitio: solo las fichas de las tiendas, cuando existan (`stores.js`).
import { esc } from "./html.js";
import { icon } from "./icons.js";
import { LANGS, withName } from "./lang.js";

export { STORES, endLeadKey, endLeadText, storesHtml, storesPending } from "./stores.js";

/** La portada. */
export const HOME_HREF = "/";
/** El cierre (CL-025-2). */
export const DOWNLOAD_HREF = "/#download";
/** Los enlaces del pie, con la clave de su texto. */
export const FOOTER_LINKS = Object.freeze([
  Object.freeze(["/help", "footerHelp"]),
  Object.freeze(["/privacy", "footerPrivacy"]),
  Object.freeze(["/licenses", "footerLicenses"]),
]);
/** Los idiomas del control ES / EN, en su orden; el texto visible de cada botón es su código en mayúsculas. */
export const LANG_CODES = LANGS;

const LANG_NAME_KEYS = { es: "navLanguageEs", en: "navLanguageEn" };

/**
 * La cabecera: el logotipo (enlace a la portada, con nombre «{appName}, inicio»), el control ES / EN (un grupo
 * con nombre; cada botón dice si está elegido) y «Descargar» (su nombre es su texto; la flecha no se lee).
 * [lang] es el idioma de la página.
 */
export function headerHtml({ strings, site, lang }) {
  if (!LANGS.includes(lang)) throw new Error(`idioma no válido: ${lang}`);
  const button = (code) =>
    `<button type="button" class="langs__btn" data-lang="${code}" lang="${code}" aria-label="${esc(strings[LANG_NAME_KEYS[code]])}" aria-pressed="${code === lang}">${code.toUpperCase()}</button>`;
  return [
    `<header class="top">`,
    `<a class="logo" href="${HOME_HREF}" aria-label="${esc(withName(strings.navHome, site.appName))}">${esc(site.wordmark)}</a>`,
    `<div class="top__right">`,
    `<div class="langs" role="group" aria-label="${esc(strings.navLanguage)}">${LANGS.map(button).join("")}</div>`,
    `<a class="download" href="${DOWNLOAD_HREF}">${icon("arrowDown")}<span class="download__label">${esc(strings.navDownload)}</span></a>`,
    `</div>`,
    `</header>`,
  ].join("");
}

/** El pie (dentro de la última escena): la línea legal y los enlaces a Ayuda, Privacidad y Licencias. */
export function footerHtml({ strings, site }) {
  const links = FOOTER_LINKS.map(([href, key]) => `<a class="end__link" href="${href}">${esc(strings[key])}</a>`).join("");
  return [
    `<footer class="end">`,
    `<p class="end__legal">${esc(withName(strings.footerLegal, site.appName))}</p>`,
    `<nav class="end__nav" aria-label="${esc(strings.footerNav)}">${links}</nav>`,
    `</footer>`,
  ].join("");
}

/**
 * Conecta los botones ES / EN de [header]: pulsar el otro idioma llama a [onChoose] con él; el que ya está
 * elegido no hace nada. El valor del botón se compara por igualdad con la lista de idiomas (P5). Devuelve cómo
 * desconectarlos.
 */
export function wireLangButtons(header, { current, onChoose }) {
  const off = [];
  for (const button of header.querySelectorAll(".langs__btn")) {
    const handler = () => {
      const code = LANGS.find((l) => l === button.dataset.lang);
      if (code && code !== current) onChoose(code);
    };
    button.addEventListener("click", handler);
    off.push(() => button.removeEventListener("click", handler));
  }
  return () => off.forEach((fn) => fn());
}
