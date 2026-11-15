// Pantallas de la app construidas en HTML, con las medidas del prototipo (marco de 390 × 844)
// y de las capturas de la ficha de Play. Todo se mide en --u (1/390 del ancho de la pantalla),
// así que el mismo marcado sirve para un móvil grande o uno pequeño y se ve nítido a cualquier tamaño.
import { t } from '../shared/i18n.js';
import { WORDMARK } from '../shared/config.js';
import { icon, HANDLE, STATUS_ICONS } from '../shared/icons.js';
import { NOTE } from '../shared/story.js';
import { esc } from '../shared/html.js';

/** Tamaño del texto de la tarea según su longitud (igual que la app: 50, 40, 31 o 26). */
export const noteSize = (text) => (text.length < 40 ? 50 : text.length < 90 ? 40 : text.length < 160 ? 31 : 26);

export const statusBar = (time = '10:00') =>
  `<div class="app__status" aria-hidden="true"><span class="app__time">${esc(time)}</span>${STATUS_ICONS}</div>`;

/** Logo y menú. Con un adjunto, los dos llevan fondo blanco para leerse sobre la foto. */
export const chromeBar = (solid = false) =>
  `<div class="app__chrome${solid ? ' is-solid' : ''}" aria-hidden="true"><span class="app__logo">${esc(WORDMARK)}</span><span class="app__menu">${icon('menu')}</span></div>`;

export const ctaButton = () =>
  `<div class="app__cta" aria-hidden="true"><span class="app__btn">${icon('check')}<span>${esc(t('app.complete'))}</span></span></div>`;

const home = '<span class="app__home" aria-hidden="true"></span>';

/**
 * Marco de móvil. `label` describe la pantalla para quien no la ve; sin él, el móvil solo decora y se oculta
 * al lector, salvo con `open` (el de la demo, que tiene un botón de verdad).
 */
export function phone(inner, { cls = '', label = '', id = '', open = false } = {}) {
  const a11y = label ? ` role="img" aria-label="${esc(label)}"` : open ? '' : ' aria-hidden="true"';
  return `<div class="phone ${cls}"${id ? ` id="${esc(id)}"` : ''}${a11y}><div class="phone__screen">${inner}</div><span class="phone__cam"></span></div>`;
}

/** Tarea de solo texto: la nota a pantalla completa. */
export function textTask(text, color = NOTE.yellow, { time } = {}) {
  return `<div class="app" style="--note:${color}">${statusBar(time)}${chromeBar()}
    <div class="app__body"><p class="app__text" style="--fs:${noteSize(text)}">${esc(text)}</p></div>
    ${ctaButton()}${home}</div>`;
}

/**
 * Tarea con imagen (o varias, con los puntos del carrusel). La imagen ocupa toda la pantalla,
 * de arriba abajo, y el texto de la tarea va en la barra negra (sin `caption`, no hay barra). `before` va debajo de la imagen.
 */
export function photoTask({ art, caption, dots = 0, time, before = '' }) {
  const carousel = dots > 1
    ? `<div class="app__dots">${Array.from({ length: dots }, (_, i) => `<span${i === 0 ? ' class="is-on"' : ''}></span>`).join('')}</div>`
    : '';
  return `<div class="app app--media">
    ${before}<div class="app__media">${art}</div>${carousel}
    ${statusBar(time)}${chromeBar(true)}
    ${caption ? `<p class="app__caption">${esc(caption)}</p>` : ''}
    ${ctaButton()}${home}</div>`;
}

const recipePage = () => `
  <h4>${esc(t('app.pdfTitle'))}</h4><p class="pdf__meta">${esc(t('app.pdfServes'))}</p>
  <h5>${esc(t('app.pdfIngredientsTitle'))}</h5><ul>${t('app.pdfIngredients').map((x) => `<li>${esc(x)}</li>`).join('')}</ul>
  <h5>${esc(t('app.pdfStepsTitle'))}</h5><ol>${t('app.pdfSteps').map((x) => `<li>${esc(x)}</li>`).join('')}</ol>
  <h5>${esc(t('app.pdfNotesTitle'))}</h5><ul>${t('app.pdfNotes').map((x) => `<li>${esc(x)}</li>`).join('')}</ul>`;

const programmePage = () => `
  <h4>${esc(t('app.progTitle'))}</h4><p class="pdf__meta">${esc(t('app.progMeta'))}</p>
  <table class="prog"><tbody>${t('app.progRows').map((r) => {
    const [h, what, where] = r.split('|');
    return `<tr><th>${esc(h)}</th><td><b>${esc(what)}</b><span>${esc(where)}</span></td></tr>`;
  }).join('')}</tbody></table>`;

/** Tarea con PDF: el documento ocupa toda la pantalla, bajo su barra de archivo. */
export function pdfTask({ kind = 'recipe', time } = {}) {
  const recipe = kind === 'recipe';
  return `<div class="app app--doc">${statusBar(time)}
    <div class="app__frame">
      <div class="app__bar">${icon('document')}<span>${esc(t(recipe ? 'app.pdfFile' : 'app.progFile'))}</span><b>PDF</b></div>
      <div class="pdf pdf--${kind}"><article class="pdf__page">${recipe ? recipePage() : programmePage()}<span class="pdf__num">1 / 2</span></article></div>
    </div>
    ${chromeBar(true)}
    <p class="app__caption">${esc(t(recipe ? 'app.pdfTask' : 'app.progTask'))}</p>
    ${ctaButton()}${home}</div>`;
}

/** Tarea con web: la página ocupa toda la pantalla, bajo la barra del dominio. */
export function webTask({ art, time } = {}) {
  return `<div class="app app--doc app--web">${statusBar(time)}
    <div class="app__frame">
      <div class="app__bar">${icon('lock')}<span>${esc(t('app.routeHost'))}</span><b>WEB</b></div>
      <div class="site">${art}</div>
    </div>
    ${chromeBar(true)}${ctaButton()}${home}</div>`;
}

/** Una fila de la lista "Todas las tareas". */
export function listRow(text, color, { first = false, thumb = '' } = {}) {
  const lead = first && thumb
    ? `<span class="row__thumb"><img src="${esc(thumb)}" alt="" width="900" height="1100" decoding="async"></span>`
    : `<span class="row__handle">${HANDLE}</span>`;
  return `<div class="row${first ? ' row--first' : ''}" style="--note:${color}">${lead}<span class="row__text">${esc(text)}</span><span class="row__acts">${icon('edit')}${icon('trash')}</span></div>`;
}

/** Pantalla "Todas las tareas". */
export function listScreen(tasks, colors, { time } = {}) {
  const rows = tasks.map((task, i) => listRow(task, colors[i % colors.length], { first: i === 0 })).join('');
  return `<div class="app app--list">${statusBar(time)}
    <div class="list__head"><span class="app__menu">${icon('arrowLeft')}</span><b>${esc(t('app.allTasks'))}</b></div>
    <p class="list__hint">${esc(t('app.allTasksHint'))}</p>
    <div class="list__rows">${rows}</div>
    <div class="list__foot"><span class="app__btn">${icon('plus')}<span>${esc(t('app.newTask'))}</span></span></div>
    ${home}</div>`;
}

/** Fila de Ajustes con su interruptor, como fragmento suelto. */
export function settingRow(title, hint, ic, { on = false } = {}) {
  return `<div class="setting" data-ui><span class="setting__ic">${icon(ic)}</span><span class="setting__txt"><b>${esc(title)}</b><small>${esc(hint)}</small></span><span class="sw${on ? ' is-on' : ''}" aria-hidden="true"></span></div>`;
}
