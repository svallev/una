import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import 'lenis/dist/lenis.css';
import { SCENES, HOLD } from './story.js';

gsap.registerPlugin(ScrollTrigger);

export { gsap, ScrollTrigger };

// Con ?motion=reduce se puede ver la versión sin movimiento sin cambiar los ajustes del sistema.
export const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  || new URLSearchParams(location.search).get('motion') === 'reduce';
export const isPhone = () => window.innerWidth < 760;

/**
 * Scroll suave (Lenis) y una línea de tiempo maestra ligada al scroll (ScrollTrigger con scrub).
 * El tiempo de la línea va de 0 a N-1+HOLD: la escena i descansa en [i, i+HOLD] y el viaje a la
 * siguiente ocupa [i+HOLD, i+1].
 */
export function createJourney({ journey, onRender }) {
  const N = SCENES.length;
  const total = N - 1 + HOLD;

  const lenis = new Lenis();
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add((time) => lenis.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);

  const clock = { t: 0 };
  const tl = gsap.timeline({
    defaults: { ease: 'none' },
    scrollTrigger: { trigger: journey, start: 'top top', end: 'bottom bottom', scrub: 0.6, invalidateOnRefresh: true },
    onUpdate: () => onRender(tl.time()),
  });
  tl.to(clock, { t: total, duration: total }, 0);

  // Imán: al dejar de hacer scroll fuera del descanso de una escena, la página se acerca sola
  // a la escena más cercana. Así la cámara nunca se queda a medio camino (y el texto, a escala).
  let snapTimer = 0;
  let touching = false;
  const snap = () => {
    if (touching) return;
    const st = tl.scrollTrigger;
    const time = st.progress * total; // posición real del scroll, sin el suavizado
    const k = sceneAt(time);
    const target = time < k ? k : time > k + HOLD ? k + HOLD : null;
    if (target === null || Math.abs(target - time) < 0.004) return;
    lenis.scrollTo(st.start + (st.end - st.start) * (target / total), {
      duration: 0.5 + Math.min(0.7, Math.abs(target - time) * 1.6),
      easing: (x) => 1 - (1 - x) ** 3,
    });
  };
  const scheduleSnap = () => { clearTimeout(snapTimer); snapTimer = setTimeout(snap, 170); };
  lenis.on('scroll', scheduleSnap);
  window.addEventListener('touchstart', () => { touching = true; clearTimeout(snapTimer); }, { passive: true });
  window.addEventListener('touchend', () => { touching = false; scheduleSnap(); }, { passive: true });
  window.addEventListener('touchcancel', () => { touching = false; scheduleSnap(); }, { passive: true });

  const scrollToScene = (i) => {
    const st = tl.scrollTrigger;
    const p = i === 0 ? 0 : (i + HOLD * 0.5) / total;
    lenis.scrollTo(st.start + (st.end - st.start) * p, { duration: 1.6 });
  };

  // Solo en desarrollo: saltar a un tiempo de la historia desde la consola (__una.go(2.2)).
  if (import.meta.env.DEV) {
    window.__una = {
      tl,
      go: (time) => { const st = tl.scrollTrigger; window.scrollTo(0, st.start + (st.end - st.start) * (time / total)); },
    };
  }

  return {
    tl,
    lenis,
    N,
    total,
    scrollToScene,
    /** Ventana del viaje que llega a la escena i. */
    travel: (i) => ({ start: i - 1 + HOLD, duration: 1 - HOLD }),
  };
}

/** Índice de la escena más cercana para un tiempo de la línea. */
export function sceneAt(time) {
  const i = Math.floor(time);
  const f = time - i;
  const k = f < HOLD + (1 - HOLD) / 2 ? i : i + 1;
  return Math.max(0, Math.min(SCENES.length - 1, k));
}
