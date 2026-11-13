import '../shared/base.css';
import './device.css';
import './scene.css';
import { t } from '../shared/i18n.js';
import { SCENES, NOTE, HOLD } from '../shared/story.js';
import { icon } from '../shared/icons.js';
import { buildChrome, copyHtml, storesHtml, footerHtml } from '../shared/chrome.js';
import { createJourney, sceneAt, reduceMotion, gsap } from '../shared/journey.js';
import { phone, textTask, photoTask, pdfTask, webTask, listScreen, listRow, settingRow } from './app-ui.js';
import { golfMap, lineupPoster, bookCover, routeMap, athlete } from './art.js';
import { holdHtml, setupHold } from './hold.js';

const N = SCENES.length;
// Distancia en Z entre escenas. Es corta a propósito: la siguiente escena empieza a llegar
// antes de que la actual haya terminado de irse, para que no haya tramos vacíos.
const DEPTH = 1400;
// Todas las escenas están en el mismo eje: la cámara solo avanza hacia dentro. Así las piezas
// vienen de frente y nos sobrepasan; nada se desliza hacia los lados.
const DRIFT = SCENES.map(() => [0, 0]);

// La perspectiva de .stage (scene.css) es 1000 px: ahí está la cámara. Una pieza se da por pasada
// un poco antes, cuando ya se ve unas 17 veces más grande.
const PASS = 940;

const tasks = t('tasks');
const COLORS = [NOTE.yellow, NOTE.blue, NOTE.pink, NOTE.green, NOTE.orange];

/** Pieza colocada en el espacio de la escena. */
const obj = (inner, { x, y, z = 0, r = 0, ry = 0, bob = 6, cls = '' }) =>
  `<div class="obj ${cls}" data-z="${z}" style="--x:${x}%;--y:${y}%;--z:${z}px;--r:${r}deg;--ry:${ry}deg;--bob:${bob}s"><div class="obj__f">${inner}</div></div>`;

// Filas sueltas de "Todas las tareas" alrededor del titular: [x%, y%, giro, z, ancho, solo escritorio]
const ROWS = [
  [14, 14, -5, 200, 330, 0], [86, 12, 4, -120, 310, 0], [6, 46, 3, -180, 300, 1], [93, 31, -4, 120, 320, 1],
  [15, 83, 4, 260, 330, 0], [86, 86, -5, -140, 300, 0],
];

/** La tarea de la mesa de luz: la imagen de un jugador de baloncesto y, encima, el papel donde se calca. */
function traceScreen() {
  const { art, trace } = athlete();
  const screen = photoTask({ caption: t('app.traceTask'), art });
  return screen.replace('<div class="app__media">', `<div class="lightbox__paper">${trace}</div><div class="app__media">`);
}

const BUILD = {
  hero: (s, i) => `
    ${obj(phone(listScreen(tasks.slice(0, 5), COLORS), { label: t('app.listAlt') }), { x: 16, y: 56, z: -320, ry: 24, r: -4, cls: 'obj--m0' })}
    ${obj(phone(textTask(tasks[0], NOTE.yellow), { label: t('app.screenAlt') }), { x: 83, y: 54, z: 0, ry: -24, r: 3, bob: 7, cls: 'obj--hero-r' })}
    ${copyHtml(s, i, storesHtml())}`,

  muchas: (s, i) => `
    ${ROWS.map(([x, y, r, z, w, desk], k) => obj(`<div style="--w:${w}px">${listRow(tasks[(k + 1) % tasks.length], COLORS[k % COLORS.length])}</div>`, { x, y, r, z, bob: 5 + (k % 4) * 0.8, cls: `${desk ? 'obj--m0' : ''} ${x < 50 ? 'obj--l' : 'obj--r'}` })).join('')}
    ${copyHtml(s, i)}`,

  una: (s, i) => `
    <div class="split split--hold">
      ${copyHtml(s, i)}
      <div class="device">
        ${holdHtml()}
        <p class="try"><span>${t('scenes.una.try')}</span><svg class="try__arrow" viewBox="0 0 140 72" aria-hidden="true"><path class="try__halo" d="M4 14 C20 62 90 70 128 26"/><path class="try__halo" d="M113 32 L128 26 L124.5 41.5"/><path d="M4 14 C20 62 90 70 128 26"/><path d="M113 32 L128 26 L124.5 41.5"/></svg></p>
      </div>
    </div>`,

  amano: (s, i) => `
    <div class="split split--rev">
      <div class="fan" aria-hidden="false">
        <div class="fan__card" style="--rot:-15deg;--tx:-52%">${phone(photoTask({ art: golfMap(), caption: t('app.golfTask') }), { label: t('app.golfAlt') })}</div>
        <div class="fan__card" style="--rot:-5deg;--tx:-17%">${phone(photoTask({ art: lineupPoster(), caption: t('app.lineupTask'), dots: 3 }), { label: t('app.lineupAlt') })}</div>
        <div class="fan__card" style="--rot:5deg;--tx:17%">${phone(pdfTask({ kind: 'programme' }), { label: t('app.progAlt') })}</div>
        <div class="fan__card" style="--rot:15deg;--tx:52%">${phone(webTask({ art: routeMap() }), { label: t('app.routeAlt') })}</div>
      </div>
      ${copyHtml(s, i, `<ul class="kinds">${t('scenes.amano.chips').map((c, k) => `<li>${icon(['image', 'document', 'link'][k])}${c}</li>`).join('')}</ul>`)}
    </div>`,

  activa: (s, i) => `
    <div class="split">
      ${copyHtml(s, i, `<p class="fine">${t('scenes.activa.note')}</p>`)}
      <div class="device">
        ${phone(pdfTask(), { label: t('app.pdfAlt') })}
        ${settingRow(t('scenes.activa.switch'), t('app.keepAwakeHint'), 'phone')}
      </div>
    </div>`,

  luz: (s, i) => `
    <div class="split split--rev">
      <div class="table">
        <div class="table__tilt">${phone(traceScreen(), { label: t('app.traceAlt') })}</div>
        ${settingRow(t('scenes.luz.switch'), t('app.lockZoomHint'), 'magnifierMinus')}
      </div>
      ${copyHtml(s, i, `<p class="fine">${t('scenes.luz.note')}</p>`)}
    </div>`,

  fin: (s, i) => `
    ${obj(phone(photoTask({ art: bookCover(), caption: t('app.bookTask') }), { label: t('app.bookAlt') }), { x: 12, y: 56, z: -360, ry: 24, r: -4, cls: 'obj--m0' })}
    ${obj(phone(textTask(tasks[1], NOTE.blue)), { x: 88, y: 53, z: -140, ry: -24, r: 3, bob: 7, cls: 'obj--m0' })}
    ${copyHtml(s, i, storesHtml({ label: false })).replace('<div class="copy">', `<div class="copy"><div class="appicon"><img src="/img/icon-512.png" width="512" height="512" alt="${t('app.iconAlt')}"></div>`)}`,
};

// ---------- Montaje ----------
const journey = document.getElementById('journey');
const stage = document.getElementById('stage');
const world = document.getElementById('world');

world.innerHTML = SCENES.map((s, i) => `
  <section class="sc sc--${s.id}${s.ink ? ' sc--ink' : ''}" id="${s.id}" style="--bg:${s.bg}" aria-labelledby="h-${s.id}">
    <div class="sc__inner">${BUILD[s.id](s, i)}</div>
    ${i === N - 1 ? footerHtml() : ''}
  </section>`).join('');

const scenes = [...world.querySelectorAll('.sc')];
// Orden de entrada dentro de cada escena: líneas del titular (--i) y piezas repetidas (--k)
scenes.forEach((sc) => {
  sc.querySelectorAll('.ln__i').forEach((ln, k) => ln.style.setProperty('--i', k));
  ['.obj', '.fan__card', '.kinds li'].forEach((sel) => sc.querySelectorAll(sel).forEach((el, k) => el.style.setProperty('--k', k)));
});

const hold = setupHold(document.getElementById('solo'), { animate: !reduceMotion });

if (reduceMotion) {
  // Sin cámara: paneles apilados, cada uno con su fondo. La demo sigue funcionando sin animación.
  document.querySelectorAll('.sw').forEach((sw) => sw.classList.add('is-on'));
  const chrome = buildChrome({ onGoTo: (i) => scenes[i].scrollIntoView() });
  // La cabecera toma el tono del panel que queda bajo ella
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) chrome.setActive(scenes.indexOf(e.target), 1); });
  }, { rootMargin: '0px 0px -92% 0px' });
  scenes.forEach((sc) => io.observe(sc));
} else {
  startStage();
}

function startStage() {
  document.documentElement.classList.add('fx');
  journey.style.setProperty('--n', N);
  stage.style.setProperty('--bg0', SCENES[0].bg);

  const cam = { x: 0, y: 0, z: 0 };
  const iA = SCENES.findIndex((s) => s.id === 'activa');
  const iL = SCENES.findIndex((s) => s.id === 'luz');
  const swActiva = document.querySelector('.sc--activa .sw');
  const swLuz = document.querySelector('.sc--luz .sw');
  const clock = document.querySelector('.sc--activa .app__time');
  let active = -1;
  let lastClock = '';

  // En píxeles enteros: en reposo la escena cae exacta sobre la rejilla y el texto pequeño sale nítido
  const driftX = (i) => Math.round(DRIFT[i][0] * innerWidth);
  const driftY = (i) => Math.round(DRIFT[i][1] * innerHeight);

  // Piezas con profundidad propia dentro de cada escena: pasan la cámara antes o después que el texto
  const pieces = scenes.map((sc) => [...sc.querySelectorAll('.obj')].map((el) => ({ el, z: Number(el.dataset.z) || 0, gone: false })));

  const place = () => {
    scenes.forEach((sc, i) => {
      sc.style.transform = `translate3d(${driftX(i)}px, ${driftY(i)}px, ${-i * DEPTH}px)`;
    });
  };

  const render = (time) => {
    // Cerca del descanso se redondea, para que el suavizado del scroll no deje la escena a 0,3 px
    const near = Math.abs(cam.z - Math.round(cam.z / DEPTH) * DEPTH) < 0.6;
    const [cx, cy, cz] = near ? [Math.round(cam.x), Math.round(cam.y), Math.round(cam.z)] : [cam.x, cam.y, cam.z];
    world.style.transform = `translate3d(${-cx}px, ${-cy}px, ${cz}px)`;
    for (let i = 0; i < N; i++) {
      const rel = cam.z - i * DEPTH; // 0 = la escena está en el plano de la pantalla
      const far = gsap.utils.clamp(0, 1, (rel + DEPTH * 0.95) / (DEPTH * 0.3));
      // Solo se funde al aparecer, cuando aún es pequeña y está lejos. Al acercarse no pierde
      // opacidad: crece hasta atravesar la cámara (a 1000 px, la perspectiva) y queda detrás.
      const o = far;
      const sc = scenes[i];
      // Cada pieza se oculta justo antes de cruzar el plano de la cámara (ya ocupa muchas pantallas).
      // No se la deja llegar a estar detrás: ahí Chrome deja de pintarla bien y, al volver hacia
      // arriba, reaparecía a trozos.
      sc.style.visibility = o > 0.001 && rel < PASS + 600 ? 'visible' : 'hidden';
      sc.classList.toggle('is-past', rel > PASS);
      for (const piece of pieces[i]) {
        const gone = rel + piece.z > PASS;
        if (gone !== piece.gone) { piece.el.style.visibility = gone ? 'hidden' : ''; piece.gone = gone; }
      }
      sc.style.setProperty('--o', o.toFixed(3));
      // Las piezas empiezan a entrar con la escena aún lejos, mientras la anterior pasa de largo.
      // Una escena ya sobrepasada conserva sus piezas: se van creciendo hacia la cámara, no encogiendo.
      sc.classList.toggle('is-in', rel > -DEPTH * 0.8);
    }
    const now = sceneAt(time);
    if (now !== active) {
      scenes.forEach((sc, i) => { sc.inert = i !== now; sc.classList.toggle('is-on', i === now); });
      if (SCENES[now].id === 'una') hold.demo(); else hold.stop();
      active = now;
    }
    // Pantalla siempre activa: se enciende el ajuste y el reloj del móvil corre con la pantalla encendida
    swActiva.classList.toggle('is-on', time > iA - 0.02 && time < iA + 0.95);
    const mins = Math.round(gsap.utils.clamp(0, 1, (time - iA - 0.08) / 0.34) * 45);
    const label = `10:${String(mins).padStart(2, '0')}`;
    if (label !== lastClock) { clock.textContent = label; lastClock = label; }
    swLuz.classList.toggle('is-on', time > iL - 0.04);
    chrome.setActive(now, time);
  };

  const j = createJourney({ journey, onRender: render });
  const chrome = buildChrome({ onGoTo: j.scrollToScene });
  const { tl } = j;

  // La cámara viaja de escena en escena y el fondo se funde por el camino
  for (let i = 1; i < N; i++) {
    const { start, duration } = j.travel(i);
    tl.to(cam, { x: () => driftX(i), y: () => driftY(i), z: i * DEPTH, duration, ease: 'power2.inOut' }, start);
    const from = SCENES[i - 1].dim || SCENES[i - 1].bg;
    tl.fromTo(stage, { backgroundColor: from }, { backgroundColor: SCENES[i].bg, duration: duration * 0.5, immediateRender: false }, start + duration * 0.25);
  }



  // Mesa de luz: llega el papel y el trazo se dibuja con el scroll
  const paper = document.querySelector('.lightbox__paper');
  // El papel llega de frente: baja desde la cámara hasta posarse sobre la pantalla
  tl.fromTo(paper, { scale: 2.4, autoAlpha: 0 }, { scale: 1, autoAlpha: 1, duration: 0.3, ease: 'power2.out', immediateRender: false }, iL - 0.2);
  tl.fromTo(paper, { '--draw': 1 }, { '--draw': 0, duration: HOLD + 0.12, immediateRender: false }, iL + 0.06);
  gsap.set(paper, { scale: 2.4, autoAlpha: 0, '--draw': 1 });

  place();
  window.addEventListener('resize', place);
  void world.offsetWidth; // fija el estado de salida antes del primer fotograma: la portada también entra escalonada
  render(0);
}
