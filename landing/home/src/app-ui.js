// Pantallas de la app en HTML (spec 025, CA-025-06; plan §2 y §2.3), traídas de la maqueta (`app-ui.js`) con
// las medidas del prototipo (marco de 390 × 844): todo se mide en `--u` (1/390 del ancho de la pantalla), así
// que el mismo marcado sirve para un móvil grande o uno pequeño. Cambios respecto a la maqueta:
// - los textos que la app ya tiene salen de `gen/site.json` (las ARB, lista cerrada del plan §2.3) y el
//   logotipo, de la identidad (CA-025-14); los de ejemplo, de `strings.*.json` (`sample.*` y `alt.*`);
// - sin `style=` (la CSP lo bloquearía, CA-025-12): el color de la nota va en `data-note` (índice de la paleta
//   clásica) y el tamaño del texto en `data-fs`, y `device.css` los traduce a tokens;
// - todo texto pasa por `esc` de `html.js`, la única del programa (plan §6.1);
// - sin la miniatura de la fila del listado (una imagen que la página no usa, CA-025-21).
//
// Funciones puras que devuelven HTML: las escenas (`story.js`) colocan los móviles.
import { esc } from "./html.js";
import { HANDLE, STATUS_ICONS, icon } from "./icons.js";
import { LANGS } from "./lang.js";
import { athlete, bookCover, golfMap, lineupPoster, routeMap } from "./art.js";

/** Los colores de nota que se pueden pedir: índices de `palette.classic` (0 amarillo, 1 rosa, 2 azul, 3 verde, 4 naranja). */
export const NOTES = Object.freeze([0, 1, 2, 3, 4]);
/** El orden de colores de las filas del listado de la maqueta: amarillo, azul, rosa, verde, naranja. */
export const LIST_NOTES = Object.freeze([0, 2, 1, 3, 4]);
/** Los tamaños del texto de la tarea (los de la app: 50, 40, 31 o 26). */
export const NOTE_SIZES = Object.freeze([50, 40, 31, 26]);

/** Tamaño del texto de la tarea según su longitud (igual que la app). */
export const noteSize = (text) => (text.length < 40 ? 50 : text.length < 90 ? 40 : text.length < 160 ? 31 : 26);

const noteOf = (note) => {
  if (!NOTES.includes(note)) throw new Error(`color de nota no válido: ${note}`);
  return note;
};

/**
 * Lo que necesitan las pantallas en un idioma: los textos de la página ([strings], con `sample` y `alt`), los
 * de la app (`site.app[lang]`) y el logotipo (`site.wordmark`).
 */
export function appUi({ strings, site, lang }) {
  if (!LANGS.includes(lang)) throw new Error(`idioma no válido: ${lang}`);
  return { strings, app: site.app[lang], wordmark: site.wordmark };
}

/** La barra de estado del sistema. */
export const statusBar = (time = "10:00") =>
  `<div class="app__status" aria-hidden="true"><span class="app__time">${esc(time)}</span>${STATUS_ICONS}</div>`;

/** Logotipo y menú. Con un adjunto, los dos llevan fondo blanco para leerse sobre la foto. */
export const chromeBar = (ui, solid = false) =>
  `<div class="app__chrome${solid ? " is-solid" : ""}" aria-hidden="true"><span class="app__logo">${esc(ui.wordmark)}</span><span class="app__menu">${icon("menu")}</span></div>`;

/** El botón de completar, con el texto de la app. */
export const ctaButton = (ui) =>
  `<div class="app__cta" aria-hidden="true"><span class="app__btn">${icon("check")}<span>${esc(ui.app.completeButton)}</span></span></div>`;

const home = '<span class="app__home" aria-hidden="true"></span>';

/**
 * Marco de móvil. [label] describe la pantalla para quien no la ve (`role="img"`: lo de dentro no se lee); sin
 * él, el móvil solo decora y se oculta al lector (CA-025-15).
 */
export function phone(inner, { cls = "", label = "" } = {}) {
  const a11y = label ? `role="img" aria-label="${esc(label)}"` : 'aria-hidden="true"';
  return `<div class="phone${cls ? ` ${esc(cls)}` : ""}" ${a11y}><div class="phone__screen">${inner}</div><span class="phone__cam"></span></div>`;
}

/** Tarea de solo texto: la nota a pantalla completa. */
export function textTask(ui, text, { note = 0, time } = {}) {
  return `<div class="app" data-note="${noteOf(note)}">${statusBar(time)}${chromeBar(ui)}
    <div class="app__body"><p class="app__text" data-fs="${noteSize(text)}">${esc(text)}</p></div>
    ${ctaButton(ui)}${home}</div>`;
}

/**
 * Tarea con imagen (o varias, con los puntos del carrusel). La imagen ocupa toda la pantalla, de arriba abajo,
 * y el texto de la tarea va en la barra negra. [paper] es el papel de la mesa de luz, encima de la imagen.
 */
export function photoTask(ui, { art, caption, dots = 0, time, paper = "" }) {
  const carousel =
    dots > 1
      ? `<div class="app__dots">${Array.from({ length: dots }, (_, i) => `<span${i === 0 ? ' class="is-on"' : ""}></span>`).join("")}</div>`
      : "";
  const sheet = paper ? `<div class="lightbox__paper">${paper}</div>` : "";
  return `<div class="app app--media">
    ${sheet}<div class="app__media">${art}</div>${carousel}
    ${statusBar(time)}${chromeBar(ui, true)}
    <p class="app__caption">${esc(caption)}</p>
    ${ctaButton(ui)}${home}</div>`;
}

const list = (tag, items) => `<${tag}>${items.map((x) => `<li>${esc(x)}</li>`).join("")}</${tag}>`;

const recipePage = (s) => `
  <h4>${esc(s.pdfTitle)}</h4><p class="pdf__meta">${esc(s.pdfServes)}</p>
  <h5>${esc(s.pdfIngredientsTitle)}</h5>${list("ul", s.pdfIngredients)}
  <h5>${esc(s.pdfStepsTitle)}</h5>${list("ol", s.pdfSteps)}
  <h5>${esc(s.pdfNotesTitle)}</h5>${list("ul", s.pdfNotes)}`;

const programmePage = (s) => `
  <h4>${esc(s.progTitle)}</h4><p class="pdf__meta">${esc(s.progMeta)}</p>
  <table class="prog"><tbody>${s.progRows
    .map((r) => {
      const [h, what, where] = r.split("|");
      return `<tr><th>${esc(h)}</th><td><b>${esc(what)}</b><span>${esc(where ?? "")}</span></td></tr>`;
    })
    .join("")}</tbody></table>`;

/** Tarea con PDF: el documento ocupa toda la pantalla, bajo su barra de archivo. */
export function pdfTask(ui, { kind = "recipe", time } = {}) {
  if (kind !== "recipe" && kind !== "programme") throw new Error(`PDF no válido: ${kind}`);
  const s = ui.strings.sample;
  const recipe = kind === "recipe";
  return `<div class="app app--doc">${statusBar(time)}
    <div class="app__frame">
      <div class="app__bar">${icon("document")}<span>${esc(recipe ? s.pdfFile : s.progFile)}</span><b>PDF</b></div>
      <div class="pdf pdf--${kind}"><article class="pdf__page">${recipe ? recipePage(s) : programmePage(s)}<span class="pdf__num">1 / 2</span></article></div>
    </div>
    ${chromeBar(ui, true)}
    <p class="app__caption">${esc(recipe ? s.pdfTask : s.progTask)}</p>
    ${ctaButton(ui)}${home}</div>`;
}

/** Tarea con web: la página ocupa toda la pantalla, bajo la barra del dominio. */
export function webTask(ui, { art, time } = {}) {
  return `<div class="app app--doc app--web">${statusBar(time)}
    <div class="app__frame">
      <div class="app__bar">${icon("lock")}<span>${esc(ui.strings.sample.routeHost)}</span><b>WEB</b></div>
      <div class="site">${art}</div>
    </div>
    ${chromeBar(ui, true)}${ctaButton(ui)}${home}</div>`;
}

/** La fila de una tarea en el listado. */
export function listRow(text, { note = 0, first = false } = {}) {
  return `<div class="row${first ? " row--first" : ""}" data-note="${noteOf(note)}"><span class="row__handle">${HANDLE}</span><span class="row__text">${esc(text)}</span><span class="row__acts">${icon("edit")}${icon("trash")}</span></div>`;
}

/** La pantalla del listado, con el título, la ayuda entera y el botón de añadir de la app. */
export function listScreen(ui, tasks, { notes = LIST_NOTES, time } = {}) {
  const rows = tasks.map((task, i) => listRow(task, { note: notes[i % notes.length], first: i === 0 })).join("");
  return `<div class="app app--list">${statusBar(time)}
    <div class="list__head"><span class="app__menu">${icon("arrowLeft")}</span><b>${esc(ui.app.listTitle)}</b></div>
    <p class="list__hint">${esc(ui.app.listHelp)}</p>
    <div class="list__rows">${rows}</div>
    <div class="list__foot"><span class="app__btn">${icon("plus")}<span>${esc(ui.app.listNewTask)}</span></span></div>
    ${home}</div>`;
}

/** Los dos ajustes que la página enseña, con su icono y sus textos de la app. */
export const SETTINGS = Object.freeze({
  keepAwake: Object.freeze({ title: "settingsKeepAwake", hint: "settingsKeepAwakeHint", icon: "phone" }),
  lockZoom: Object.freeze({ title: "settingsLockZoom", hint: "settingsLockZoomHint", icon: "magnifierMinus" }),
});

/**
 * La fila de Ajustes, suelta, con su interruptor ([on]: encendido). El nombre y el subtítulo se leen; el
 * interruptor, que solo dibuja, no.
 */
export function settingRow(ui, which, { on = false } = {}) {
  const setting = SETTINGS[Object.keys(SETTINGS).find((k) => k === which)];
  if (!setting) throw new Error(`ajuste no válido: ${which}`);
  return `<div class="setting"><span class="setting__ic">${icon(setting.icon)}</span><span class="setting__txt"><b>${esc(ui.app[setting.title])}</b><small>${esc(ui.app[setting.hint])}</small></span><span class="sw${on ? " is-on" : ""}" aria-hidden="true"></span></div>`;
}

/** La tarea de la mesa de luz: la imagen del jugador y, encima, el papel donde se calca. */
export function traceTask(ui, { time } = {}) {
  const { art, trace } = athlete();
  return photoTask(ui, { art, caption: ui.strings.sample.traceTask, paper: trace, time });
}

/**
 * Los móviles que enseña la página, con su descripción (o sin ella, ocultos, si solo decoran): las escenas
 * los colocan. `holdTask` (el móvil de prueba) no está: es de `hold.js`.
 */
export function appPhones(ui) {
  const s = ui.strings.sample;
  const alt = ui.strings.alt;
  return {
    list: phone(listScreen(ui, s.tasks.slice(0, 5)), { label: alt.list }),
    current: phone(textTask(ui, s.tasks[0], { note: 0 }), { label: alt.screen }),
    golf: phone(photoTask(ui, { art: golfMap(s), caption: s.golfTask }), { label: alt.golf }),
    lineup: phone(photoTask(ui, { art: lineupPoster(s), caption: s.lineupTask, dots: 3 }), { label: alt.lineup }),
    programme: phone(pdfTask(ui, { kind: "programme" }), { label: alt.prog }),
    route: phone(webTask(ui, { art: routeMap(s) }), { label: alt.route }),
    recipe: phone(pdfTask(ui, { kind: "recipe" }), { label: alt.pdf }),
    trace: phone(traceTask(ui), { label: alt.trace }),
    book: phone(photoTask(ui, { art: bookCover(s), caption: s.bookTask }), { label: alt.book }),
    // El segundo móvil del cierre repite lo que ya cuenta el primero: solo decora.
    endText: phone(textTask(ui, s.tasks[1], { note: 2 })),
  };
}
