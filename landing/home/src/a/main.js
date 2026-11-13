import '../shared/base.css';
import './device.css';
import './scene.css';
import { lang, useLang } from '../shared/i18n.js';
import { detectLang, applyMeta } from '../shared/locale.js';
import { SCENES, HOLD } from '../shared/story.js';
import { buildChrome } from '../shared/chrome.js';
import { createJourney, sceneAt, reduceMotion, gsap } from '../shared/journey.js';
import { setupHold } from './hold.js';
import { pageHtml } from './page.js';

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

// ---------- Montaje ----------
// La construcción deja la página escrita en el idioma por defecto (`page.js`): se usa tal cual y solo se
// vuelve a escribir si el idioma es otro (o si no está, con el servidor de desarrollo de Vite).
useLang(detectLang());
if (document.documentElement.lang !== lang || !document.getElementById('journey')) {
  document.querySelectorAll('body > .top, #journey, body > .hint').forEach((el) => el.remove());
  document.body.insertAdjacentHTML('afterbegin', pageHtml());
  document.documentElement.lang = lang;
}
applyMeta();

const journey = document.getElementById('journey');
const stage = document.getElementById('stage');
const world = document.getElementById('world');

const scenes = [...world.querySelectorAll('.sc')];
// Orden de entrada dentro de cada escena: líneas del titular (--i) y piezas repetidas (--k)
scenes.forEach((sc) => {
  sc.querySelectorAll('.ln__i').forEach((ln, k) => ln.style.setProperty('--i', k));
  ['.obj', '.fan__card', '.kinds li'].forEach((sel) => sc.querySelectorAll(sel).forEach((el, k) => el.style.setProperty('--k', k)));
});

const hold = setupHold(document.getElementById('solo'), { animate: !reduceMotion });

if (reduceMotion) {
  // Sin cámara: paneles apilados, cada uno con su fondo (y los interruptores encendidos, `page.js`). La demo
  // sigue funcionando sin animación.
  const chrome = buildChrome({ onGoTo: (i) => scenes[i].scrollIntoView() });
  // La cabecera toma el tono del panel que queda bajo ella
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) chrome.setActive(scenes.indexOf(e.target), 1); });
  }, { rootMargin: '0px 0px -92% 0px' });
  scenes.forEach((sc) => io.observe(sc));
} else {
  startStage();
}
// Ya montada: se deja ver (`base.css`).
document.documentElement.classList.add('is-ready');

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
