import { t } from '../shared/i18n.js';
import { icon } from '../shared/icons.js';
import { NOTE } from '../shared/story.js';
import { esc } from '../shared/html.js';
import { phone, statusBar, chromeBar, noteSize } from './app-ui.js';

// Empieza en rosa: la escena tiene el fondo amarillo y una nota amarilla se perdería.
const COLORS = [NOTE.pink, NOTE.orange, NOTE.yellow, NOTE.green, NOTE.blue];
const HOLD_MS = 1200;
const TEAR_MS = 1250;

const label = () => `${icon('check')}<span>${esc(t('app.complete'))}</span>`;

/** La tarea número `i` de la demo: su texto y su color (la lista da la vuelta). */
const noteAt = (tasks, i) => ({ text: tasks[i % tasks.length], color: COLORS[i % COLORS.length] });

/** Cada nota de la demo, ya con su tarea. La de debajo (`next`) solo se ve al rasgarse la de encima. */
const noteHtml = (kind, { text, color }) =>
  `<div class="hold__note hold__note--${kind}" style="--note:${color}"${kind === 'next' ? ' aria-hidden="true"' : ''}><div class="app__body"><p class="app__text" style="--fs:${noteSize(text)}">${esc(text)}</p></div></div>`;

/**
 * El móvil de la demo: la pantalla de la tarea actual, con su botón de verdad. El nombre del botón es su
 * texto visible (WCAG 2.5.3) y cómo se usa va en su descripción.
 */
export function holdHtml() {
  const tasks = t('tasks');
  const screen = `<div class="app hold">
    ${noteHtml('next', noteAt(tasks, 1))}
    ${noteHtml('cur', noteAt(tasks, 0))}
    ${statusBar()}${chromeBar()}
    <div class="hold__tear" aria-hidden="true"></div>
    <div class="hold__stamp" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M4 12.5l5 5L20 6.5"/></svg></div>
    <div class="hold__confetti" aria-hidden="true"></div>
    <div class="app__cta"><button class="app__btn hold__btn" type="button" aria-describedby="solo-how">
      <span class="hold__label">${label()}</span><span class="hold__fill" aria-hidden="true">${label()}</span>
    </button></div>
    <span class="app__home" aria-hidden="true"></span>
    <span class="vh" id="solo-how">${esc(t('app.completeA11y'))}</span>
    <span class="vh" aria-live="polite"></span>
  </div>`;
  return phone(screen, { cls: 'phone--hold', id: 'solo', open: true });
}

/** Mantener pulsado para completar: con el dedo, el ratón o el teclado (Intro o espacio). */
export function setupHold(root, { animate = true } = {}) {
  const tasks = t('tasks');
  const app = root.querySelector('.hold');
  const cur = root.querySelector('.hold__note--cur');
  const next = root.querySelector('.hold__note--next');
  const tear = root.querySelector('.hold__tear');
  const btn = root.querySelector('.hold__btn');
  const confetti = root.querySelector('.hold__confetti');
  const live = root.querySelector('[aria-live]');
  let index = 0;
  let busy = false;
  let timer = 0;
  let touched = false;

  const fill = (note, i) => {
    const { text, color } = noteAt(tasks, i);
    note.style.setProperty('--note', color);
    const p = note.querySelector('.app__text');
    p.textContent = text;
    p.style.setProperty('--fs', noteSize(text));
  };
  const paint = () => { fill(cur, index); fill(next, index + 1); };
  paint();

  const burst = () => {
    confetti.innerHTML = Array.from({ length: 18 }, (_, k) => {
      const a = (k / 18) * Math.PI * 2 + Math.random() * 0.35;
      const d = 32 + Math.random() * 22; // en % del ancho de la pantalla
      return `<span style="--k:${COLORS[k % COLORS.length]};--dx:${(Math.cos(a) * d).toFixed(1)}cqw;--dy:${(Math.sin(a) * d).toFixed(1)}cqw;--dr:${(Math.random() * 540 - 270).toFixed(0)}deg"></span>`;
    }).join('');
  };

  const complete = () => {
    if (busy) return;
    busy = true;
    clearTimeout(timer);
    app.classList.remove('is-holding');
    live.textContent = t('app.done');
    if (!animate) { index += 1; paint(); busy = false; return; }
    // Sello y confeti; después la nota se rasga en dos y debajo ya está la siguiente
    app.classList.add('is-done');
    burst();
    setTimeout(() => {
      tear.innerHTML = `<div class="hold__half hold__half--l">${cur.innerHTML}</div><div class="hold__half hold__half--r">${cur.innerHTML}</div>`;
      tear.querySelectorAll('.hold__half').forEach((h) => h.style.setProperty('--note', cur.style.getPropertyValue('--note')));
      app.classList.add('is-tearing');
    }, 520);
    setTimeout(() => {
      index += 1;
      paint();
      app.classList.remove('is-done', 'is-tearing');
      tear.innerHTML = '';
      confetti.innerHTML = '';
      busy = false;
    }, 520 + TEAR_MS);
  };

  const start = () => {
    if (busy) return;
    app.classList.add('is-holding');
    clearTimeout(timer);
    timer = setTimeout(complete, HOLD_MS);
  };
  const cancel = () => {
    if (busy) return;
    clearTimeout(timer);
    app.classList.remove('is-holding');
  };

  btn.addEventListener('pointerdown', (e) => { touched = true; btn.setPointerCapture?.(e.pointerId); start(); });
  btn.addEventListener('pointerup', cancel);
  btn.addEventListener('pointercancel', cancel);
  btn.addEventListener('contextmenu', (e) => e.preventDefault());
  btn.addEventListener('keydown', (e) => {
    if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) { e.preventDefault(); touched = true; start(); }
  });
  btn.addEventListener('keyup', (e) => { if (e.key === 'Enter' || e.key === ' ') cancel(); });
  // Lectores de pantalla: activar el botón completa la tarea.
  btn.addEventListener('click', (e) => { if (e.detail === 0 && !app.classList.contains('is-holding')) { touched = true; complete(); } });

  let demoTimer = 0;
  return {
    /** Al llegar a la escena, la nota se completa sola una vez si nadie la ha tocado. */
    demo() {
      clearTimeout(demoTimer);
      if (!animate || touched) return;
      demoTimer = setTimeout(() => { if (!touched) start(); }, 900);
    },
    stop() { clearTimeout(demoTimer); if (!touched) cancel(); },
  };
}
