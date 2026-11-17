// El HTML de la página entera (cabecera, las siete escenas con el pie y la pista de scroll) en el idioma de
// `i18n.js`. Lo usan la construcción (`landing/build.mjs` lo escribe en `index.html`: sin JavaScript se ve la
// versión apilada) y el programa (`main.js`, si el idioma es otro). Sin nada del navegador.
import { t, lang } from '../shared/i18n.js';
import { SCENES, NOTE } from '../shared/story.js';
import { icon } from '../shared/icons.js';
import { esc } from '../shared/html.js';
import { copyHtml, storesHtml, footerHtml, headerHtml, hintHtml } from '../shared/chrome.js';
import { phone, textTask, photoTask, pdfTask, webTask, listScreen, listRow, settingRow } from './app-ui.js';
import { golfMap, lineupPoster, bookCover, routeMap, cat } from './art.js';
import { holdHtml } from './hold.js';

const COLORS = [NOTE.yellow, NOTE.blue, NOTE.pink, NOTE.green, NOTE.orange];

/** Pieza colocada en el espacio de la escena. */
const obj = (inner, { x, y, z = 0, r = 0, ry = 0, bob = 6, cls = '' }) =>
  `<div class="obj ${cls}" data-z="${z}" style="--x:${x}%;--y:${y}%;--z:${z}px;--r:${r}deg;--ry:${ry}deg;--bob:${bob}s"><div class="obj__f">${inner}</div></div>`;

// Filas sueltas de "Todas las tareas" alrededor del titular: [x%, y%, giro, z, ancho, solo escritorio]
const ROWS = [
  [14, 14, -5, 200, 330, 0], [86, 12, 4, -120, 310, 0], [6, 46, 3, -180, 300, 1], [93, 31, -4, 120, 320, 1],
  [15, 83, 4, 260, 330, 0], [86, 86, -5, -140, 300, 0],
];

/** La tarea de la mesa de luz: la imagen de un gato estilo anime (sin título) y, encima, el papel donde se calca. */
function traceScreen() {
  const { art, trace } = cat();
  return photoTask({ art, before: `<div class="lightbox__paper">${trace}</div>` });
}

const fine = (key) => `<p class="fine">${esc(t(key))}</p>`;

const BUILD = {
  hero: (s, i, tasks) => `
    ${obj(phone(listScreen(tasks.slice(0, 5), COLORS), { label: t('app.listAlt') }), { x: 16, y: 56, z: -320, ry: 24, r: -4, cls: 'obj--m0' })}
    ${obj(phone(textTask(tasks[0], NOTE.yellow), { label: t('app.screenAlt') }), { x: 83, y: 54, z: 0, ry: -24, r: 3, bob: 7, cls: 'obj--hero-r' })}
    ${copyHtml(s, i, storesHtml())}`,

  muchas: (s, i, tasks) => `
    ${ROWS.map(([x, y, r, z, w, desk], k) => obj(`<div style="--w:${w}px" aria-hidden="true">${listRow(tasks[(k + 1) % tasks.length], COLORS[k % COLORS.length])}</div>`, { x, y, r, z, bob: 5 + (k % 4) * 0.8, cls: `${desk ? 'obj--m0' : ''} ${x < 50 ? 'obj--l' : 'obj--r'}` })).join('')}
    ${copyHtml(s, i)}`,

  una: (s, i) => `
    <div class="split split--hold">
      ${copyHtml(s, i)}
      <div class="device">
        ${holdHtml()}
        <p class="try"><span>${esc(t('scenes.una.try'))}</span><svg class="try__arrow" viewBox="0 0 140 72" aria-hidden="true"><path class="try__halo" d="M4 14 C20 62 90 70 128 26"/><path class="try__halo" d="M113 32 L128 26 L124.5 41.5"/><path d="M4 14 C20 62 90 70 128 26"/><path d="M113 32 L128 26 L124.5 41.5"/></svg></p>
      </div>
    </div>`,

  amano: (s, i) => `
    <div class="split split--rev">
      <div class="fan">
        <div class="fan__card" style="--rot:-15deg;--tx:-52%">${phone(photoTask({ art: golfMap(), caption: t('app.golfTask') }), { label: t('app.golfAlt') })}</div>
        <div class="fan__card" style="--rot:-5deg;--tx:-17%">${phone(photoTask({ art: lineupPoster(), caption: t('app.lineupTask'), dots: 3 }), { label: t('app.lineupAlt') })}</div>
        <div class="fan__card" style="--rot:5deg;--tx:17%">${phone(pdfTask({ kind: 'programme' }), { label: t('app.progAlt') })}</div>
        <div class="fan__card" style="--rot:15deg;--tx:52%">${phone(webTask({ art: routeMap() }), { label: t('app.routeAlt') })}</div>
      </div>
      ${copyHtml(s, i, `<ul class="kinds">${t('scenes.amano.chips').map((c, k) => `<li>${icon(['image', 'document', 'link'][k])}${esc(c)}</li>`).join('')}</ul>`)}
    </div>`,

  // Los interruptores salen encendidos, como en la versión apilada; en el recorrido los mueve `main.js`.
  activa: (s, i) => `
    <div class="split">
      ${copyHtml(s, i, fine('scenes.activa.note'))}
      <div class="device">
        ${phone(pdfTask(), { label: t('app.pdfAlt') })}
        ${settingRow(t('scenes.activa.switch'), t('app.keepAwakeHint'), 'phone', { on: true })}
      </div>
    </div>`,

  luz: (s, i) => `
    <div class="split split--rev">
      <div class="table">
        <div class="table__tilt">${phone(traceScreen(), { label: t('app.traceAlt') })}</div>
        ${settingRow(t('scenes.luz.switch'), null, 'magnifierMinus', { on: true })}
      </div>
      ${copyHtml(s, i)}
    </div>`,

  fin: (s, i, tasks) => `
    ${obj(phone(photoTask({ art: bookCover(), caption: t('app.bookTask') }), { label: t('app.bookAlt') }), { x: 12, y: 56, z: -360, ry: 24, r: -4, cls: 'obj--m0' })}
    ${obj(phone(textTask(tasks[1], NOTE.blue)), { x: 88, y: 53, z: -140, ry: -24, r: 3, bob: 7, cls: 'obj--m0' })}
    ${copyHtml(s, i, storesHtml({ label: false }), { before: `<div class="appicon"><img src="/img/icon-512.png" width="512" height="512" alt="${esc(t('app.iconAlt'))}"></div>` })}`,
};

/** Las siete escenas; el pie va en la última. */
export function scenesHtml() {
  const tasks = t('tasks');
  return SCENES.map((s, i) => `
  <section class="sc sc--${s.id}${s.ink ? ' sc--ink' : ''}" id="${s.id}" style="--bg:${s.bg}" aria-labelledby="h-${s.id}">
    <div class="sc__inner">${BUILD[s.id](s, i, tasks)}</div>
    ${i === SCENES.length - 1 ? footerHtml() : ''}
  </section>`).join('');
}

/** El contenido entero de `<body>`, sin el programa. */
export function pageHtml() {
  return `${headerHtml()}
<main class="journey" id="journey">
  <div class="stage" id="stage"><div class="world" id="world">${scenesHtml()}</div></div>
</main>
${hintHtml()}`;
}

/** El idioma, el título y la descripción de la página (la construcción los escribe en `<head>`). */
export function pageMeta() {
  return { lang, title: t('meta.title'), description: t('meta.description') };
}
