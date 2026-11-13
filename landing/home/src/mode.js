// Recorrido o versión apilada (spec 025, CA-025-10 y CL-025-13; plan §6.2 y §6.3). Funciones puras: la
// ventana, el observador de tamaños y la medida llegan como argumentos.
//
// La página va apilada (las siete escenas una debajo de otra, con el scroll normal) si el sistema pide
// «reducir movimiento», si el navegador no tiene lo que el recorrido necesita (`transform-style: preserve-3d`
// y unidades `svh`) o si el contenido de una escena no cabe en el alto de la ventana. Lo último se vuelve a
// mirar al cambiar de tamaño la ventana y también el contenido: el tamaño de letra y el espaciado de texto no
// lanzan `resize`, pero sí cambian lo que mide cada escena. Una vez apilada, no vuelve al recorrido en esa
// visita (no hay `?motion=` en la dirección, Q-025-9).

export const REDUCE_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

/** Las causas de la versión apilada, en el orden en que se miran. */
export const STACK_REASONS = Object.freeze(["reduce-motion", "no-3d", "no-svh", "does-not-fit"]);

/** Recorrido (`journey`) o apilada (`stacked`), con la causa. */
export function chooseMode({ reduceMotion, preserve3d, svh, fits = true }) {
  if (reduceMotion !== false) return { mode: "stacked", reason: "reduce-motion" };
  if (preserve3d !== true) return { mode: "stacked", reason: "no-3d" };
  if (svh !== true) return { mode: "stacked", reason: "no-svh" };
  if (fits !== true) return { mode: "stacked", reason: "does-not-fit" };
  return { mode: "journey", reason: null };
}

/**
 * Lo que el navegador dice de sí mismo. Si no se puede preguntar (sin `matchMedia` o sin `CSS.supports`), se
 * toma la opción prudente: «reducir movimiento» activado y sin soporte.
 */
export function detectMode(win) {
  const ask = (fn) => {
    try {
      return fn() === true;
    } catch {
      return false;
    }
  };
  const query = (q) => {
    try {
      return win.matchMedia(q).matches === true;
    } catch {
      return null;
    }
  };
  const reduce = query(REDUCE_MOTION_QUERY);
  return {
    reduceMotion: reduce === null ? true : reduce,
    preserve3d: ask(() => win.CSS.supports("transform-style", "preserve-3d")),
    svh: ask(() => win.CSS.supports("height", "100svh")),
  };
}

/** ¿Cabe cada uno de [elements] en el alto de la ventana? (CL-025-13) */
export function contentFits(elements, win) {
  const height = win.innerHeight;
  return [...elements].every((el) => el.scrollHeight <= height);
}

/**
 * Una función `observe(cb)` que llama a `cb` cuando cambia el tamaño de la ventana o el de alguno de
 * [targets] (con `ResizeObserver`, que ve también el cambio de tamaño de letra). Devuelve cómo dejar de
 * observar. Sin `ResizeObserver`, solo la ventana.
 */
export function observeSizes(win, targets) {
  return (cb) => {
    const Observer = win.ResizeObserver;
    const ro = typeof Observer === "function" ? new Observer(() => cb()) : null;
    if (ro) for (const t of targets) ro.observe(t);
    const onResize = () => cb();
    win.addEventListener("resize", onResize);
    return () => {
      ro?.disconnect();
      win.removeEventListener("resize", onResize);
    };
  };
}

/**
 * Vigila que el contenido quepa (CL-025-13): cuando las fuentes están listas ([ready], la promesa de
 * `document.fonts.ready`), mide; y vuelve a medir cada vez que [observe] avisa. La primera vez que no cabe,
 * llama a [onStack] y deja de observar: no se vuelve al recorrido. Devuelve `stop()` y `stacked`.
 */
export function watchFit({ fits, observe, ready = undefined, onStack }) {
  let stacked = false;
  let stopped = false;
  let unobserve = () => {};
  const stop = () => {
    stopped = true;
    unobserve();
  };
  const check = () => {
    if (stopped) return;
    if (!fits()) {
      stacked = true;
      stop();
      onStack();
    }
  };
  const start = () => {
    if (stopped) return;
    unobserve = observe(check) ?? (() => {});
    check();
  };
  Promise.resolve(ready).then(start, start);
  return {
    stop,
    get stacked() {
      return stacked;
    },
  };
}
