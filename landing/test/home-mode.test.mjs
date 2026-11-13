// Recorrido o versión apilada (spec 025, CA-025-10 y CL-025-13; plan §6.2 y §6.3): cada causa de la versión
// apilada, lo que pregunta al navegador y la vigilancia de que el contenido quepa, incluido el cambio de
// tamaño de letra (que no lanza `resize`). Sin navegador: ventana, observador y medida de mentira.
import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { REDUCE_MOTION_QUERY, STACK_REASONS, chooseMode, contentFits, detectMode, observeSizes, watchFit } from "../home/src/mode.js";

const ok = { reduceMotion: false, preserve3d: true, svh: true, fits: true };
const settle = () => new Promise((r) => setImmediate(r));

/** Una ventana de mentira: preferencias, soporte de CSS, alto, `resize` y un `ResizeObserver` controlable. */
function fakeWindow({ reduce = false, supports = () => true, height = 800, resizeObserver = true } = {}) {
  const listeners = new Set();
  const observers = [];
  const win = {
    innerHeight: height,
    matchMedia: (q) => ({ matches: q === REDUCE_MOTION_QUERY ? reduce : false }),
    CSS: { supports: (p, v) => supports(p, v) },
    addEventListener: (type, fn) => type === "resize" && listeners.add(fn),
    removeEventListener: (type, fn) => type === "resize" && listeners.delete(fn),
    fireResize: () => [...listeners].forEach((fn) => fn()),
    listeners,
    observers,
  };
  if (resizeObserver) {
    win.ResizeObserver = class {
      constructor(cb) {
        this.cb = cb;
        this.targets = new Set();
        observers.push(this);
      }
      observe(t) {
        this.targets.add(t);
      }
      disconnect() {
        this.targets.clear();
      }
      /** Lo que hace el navegador cuando cambia el tamaño de [t]. */
      fire(t) {
        if (this.targets.has(t)) this.cb([{ target: t }]);
      }
    };
  }
  return win;
}

describe("CA-025-10: la versión apilada, con cada causa", () => {
  test("con todo a favor, el recorrido", () => {
    assert.deepEqual(chooseMode(ok), { mode: "journey", reason: null });
  });

  test("«reducir movimiento» → apilada, aunque todo lo demás valga", () => {
    assert.deepEqual(chooseMode({ ...ok, reduceMotion: true }), { mode: "stacked", reason: "reduce-motion" });
  });

  test("sin `transform-style: preserve-3d` → apilada", () => {
    assert.deepEqual(chooseMode({ ...ok, preserve3d: false }), { mode: "stacked", reason: "no-3d" });
  });

  test("sin unidades `svh` → apilada", () => {
    assert.deepEqual(chooseMode({ ...ok, svh: false }), { mode: "stacked", reason: "no-svh" });
  });

  test("CL-025-13: una escena que no cabe en el alto → apilada", () => {
    assert.deepEqual(chooseMode({ ...ok, fits: false }), { mode: "stacked", reason: "does-not-fit" });
  });

  test("lo que no se sabe cuenta como no: la opción prudente es la apilada", () => {
    assert.equal(chooseMode({ ...ok, reduceMotion: undefined }).mode, "stacked");
    assert.equal(chooseMode({ ...ok, preserve3d: undefined }).mode, "stacked");
    assert.equal(chooseMode({ ...ok, svh: "yes" }).mode, "stacked");
    assert.equal(chooseMode({ ...ok, fits: null }).mode, "stacked", "una medida que no se pudo hacer");
    assert.equal(chooseMode({ reduceMotion: false, preserve3d: true, svh: true }).mode, "journey", "sin medir, se da por que cabe");
    assert.deepEqual(STACK_REASONS, ["reduce-motion", "no-3d", "no-svh", "does-not-fit"]);
  });

  test("sin parámetros en la dirección: `?motion=reduce` no existe (Q-025-9)", async () => {
    const { readFileSync } = await import("node:fs");
    const src = readFileSync(new URL("../home/src/mode.js", import.meta.url), "utf8").replace(/^\s*\/\/.*$/gm, "");
    assert.ok(!/location|URLSearchParams|search/.test(src), "mode.js lee la dirección");
  });
});

describe("CA-025-10: lo que se pregunta al navegador", () => {
  test("pregunta por «reducir movimiento», preserve-3d y svh", () => {
    const asked = [];
    const win = fakeWindow({ supports: (p, v) => (asked.push(`${p}: ${v}`), true) });
    assert.deepEqual(detectMode(win), { reduceMotion: false, preserve3d: true, svh: true });
    assert.deepEqual(asked, ["transform-style: preserve-3d", "height: 100svh"]);
    assert.equal(chooseMode(detectMode(fakeWindow({ reduce: true }))).reason, "reduce-motion");
  });

  test("cada soporte que falta lleva a la apilada", () => {
    const no3d = fakeWindow({ supports: (p) => p !== "transform-style" });
    assert.equal(chooseMode(detectMode(no3d)).reason, "no-3d");
    const noSvh = fakeWindow({ supports: (p) => p !== "height" });
    assert.equal(chooseMode(detectMode(noSvh)).reason, "no-svh");
  });

  test("sin `matchMedia` o sin `CSS.supports` (o si lanzan), apilada", () => {
    assert.equal(chooseMode(detectMode({})).mode, "stacked");
    assert.equal(chooseMode(detectMode({ ...fakeWindow(), matchMedia: undefined })).reason, "reduce-motion");
    const throwing = fakeWindow({
      supports: () => {
        throw new Error("x");
      },
    });
    assert.equal(chooseMode(detectMode(throwing)).reason, "no-3d");
  });
});

describe("CL-025-13: si el contenido deja de caber, pasa a la apilada y no vuelve", () => {
  test("se mide cuando las fuentes están listas, no antes", async () => {
    let measured = 0;
    let release;
    const ready = new Promise((r) => (release = r));
    const win = fakeWindow();
    watchFit({ fits: () => (measured++, true), observe: observeSizes(win, []), ready, onStack: () => {} });
    await settle();
    assert.equal(measured, 0, "midió antes de que cargaran las fuentes");
    release();
    await settle();
    assert.equal(measured, 1);
  });

  test("no cabe al cargar las fuentes → apilada una vez", async () => {
    let stacks = 0;
    const win = fakeWindow();
    const w = watchFit({ fits: () => false, observe: observeSizes(win, []), onStack: () => stacks++ });
    await settle();
    assert.equal(stacks, 1);
    assert.equal(w.stacked, true);
  });

  test("cambio de tamaño de letra: sin `resize`, el ResizeObserver del contenido avisa → apilada", async () => {
    const scene = { scrollHeight: 600 };
    const win = fakeWindow({ height: 800 });
    let stacks = 0;
    const w = watchFit({
      fits: () => contentFits([scene], win),
      observe: observeSizes(win, [scene]),
      onStack: () => stacks++,
    });
    await settle();
    assert.equal(stacks, 0, "cabía");
    scene.scrollHeight = 1200; // la letra al 200 %: el contenido crece, la ventana no
    win.observers[0].fire(scene);
    assert.equal(stacks, 1);
    assert.equal(w.stacked, true);
  });

  test("girar el móvil o achicar la ventana: `resize` → apilada", async () => {
    const scene = { scrollHeight: 600 };
    const win = fakeWindow({ height: 800 });
    let stacks = 0;
    watchFit({ fits: () => contentFits([scene], win), observe: observeSizes(win, [scene]), onStack: () => stacks++ });
    await settle();
    win.innerHeight = 400;
    win.fireResize();
    assert.equal(stacks, 1);
  });

  test("una vez apilada no vuelve al recorrido y deja de observar", async () => {
    const scene = { scrollHeight: 1200 };
    const win = fakeWindow({ height: 800 });
    let stacks = 0;
    let measured = 0;
    const w = watchFit({
      fits: () => (measured++, contentFits([scene], win)),
      observe: observeSizes(win, [scene]),
      onStack: () => stacks++,
    });
    await settle();
    assert.equal(stacks, 1);
    scene.scrollHeight = 100;
    win.fireResize();
    win.observers[0].fire(scene);
    assert.equal(stacks, 1);
    assert.equal(measured, 1, "siguió midiendo");
    assert.equal(w.stacked, true);
    assert.equal(win.listeners.size, 0, "sigue escuchando resize");
    assert.equal(win.observers[0].targets.size, 0, "sigue observando el contenido");
  });

  test("`stop()` antes de que carguen las fuentes: no mide ni observa", async () => {
    let measured = 0;
    const win = fakeWindow();
    const w = watchFit({ fits: () => (measured++, false), observe: observeSizes(win, [{}]), onStack: () => assert.fail("apiló") });
    w.stop();
    await settle();
    assert.equal(measured, 0);
    assert.equal(win.observers.length, 0);
    assert.equal(win.listeners.size, 0);
  });

  test("si la carga de las fuentes falla, se mide igual", async () => {
    let stacks = 0;
    watchFit({ fits: () => false, observe: observeSizes(fakeWindow(), []), ready: Promise.reject(new Error("x")), onStack: () => stacks++ });
    await settle();
    assert.equal(stacks, 1);
  });

  test("sin ResizeObserver, al menos la ventana", async () => {
    const scene = { scrollHeight: 600 };
    const win = fakeWindow({ resizeObserver: false });
    let stacks = 0;
    watchFit({ fits: () => contentFits([scene], win), observe: observeSizes(win, [scene]), onStack: () => stacks++ });
    await settle();
    scene.scrollHeight = 900;
    win.fireResize();
    assert.equal(stacks, 1);
  });

  test("cabe exactamente: no pasa a apilada", () => {
    const win = fakeWindow({ height: 800 });
    assert.equal(contentFits([{ scrollHeight: 800 }, { scrollHeight: 10 }], win), true);
    assert.equal(contentFits([{ scrollHeight: 800 }, { scrollHeight: 801 }], win), false);
  });
});
