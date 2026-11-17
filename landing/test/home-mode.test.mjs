// Recorrido o versión apilada (H-025-01): una escena que no cabe en el alto de la ventana se recibe apilada,
// como con «reducir movimiento» (CL-025-13, CA-025-10 y CA-025-16).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { MIN_JOURNEY_HEIGHT, TALL_ENOUGH, pickMode } from "../home/src/shared/mode.js";

const tallEnough = (height) => height >= MIN_JOURNEY_HEIGHT;

test("CL-025-13: con «reducir movimiento», apilada aunque la ventana sea alta", () => {
  assert.equal(pickMode({ reduceMotion: true, tallEnough: true }), "stacked");
  assert.equal(pickMode({ reduceMotion: true, tallEnough: false }), "stacked");
});

test("CL-025-13: sin «reducir movimiento», recorrido si cabe y apilada si no", () => {
  assert.equal(pickMode({ reduceMotion: false, tallEnough: true }), "journey");
  assert.equal(pickMode({ reduceMotion: false, tallEnough: false }), "stacked");
});

test("CL-025-13: si no se sabe si cabe, apilada (nada queda sin poder alcanzarse)", () => {
  for (const v of [undefined, null, 1, "true"]) assert.equal(pickMode({ reduceMotion: false, tallEnough: v }), "stacked");
});

test("CA-025-16: móvil en horizontal (844×390) y pantallas bajas, apilada", () => {
  for (const [w, h] of [[844, 390], [915, 412], [640, 480], [1280, 500]]) {
    assert.equal(pickMode({ reduceMotion: false, tallEnough: tallEnough(h) }), "stacked", `${w}×${h}`);
  }
});

test("CA-025-16: los tamaños de la casilla C-025-6 en vertical y escritorio siguen en el recorrido", () => {
  for (const [w, h] of [[320, 568], [390, 844], [768, 1024], [1280, 720], [1920, 1080], [960, 540]]) {
    assert.equal(pickMode({ reduceMotion: false, tallEnough: tallEnough(h) }), "journey", `${w}×${h}`);
  }
});

test("CL-025-13: la consulta de medios usa el mismo umbral", () => {
  assert.equal(TALL_ENOUGH, `(min-height: ${MIN_JOURNEY_HEIGHT}px)`);
});

test("CL-025-13: main.js decide el modo con pickMode y TALL_ENOUGH, y pasa a apilada si deja de caber", () => {
  const main = readFileSync(new URL("../home/src/a/main.js", import.meta.url), "utf8");
  assert.match(main, /pickMode\(\{ reduceMotion, tallEnough: tall\.matches \}\)/);
  assert.match(main, /matchMedia\(TALL_ENOUGH\)/);
  assert.match(main, /tall\.addEventListener\('change', \(\) => \{ if \(!tall\.matches\) location\.reload\(\); \}\)/);
  assert.doesNotMatch(main, /if \(reduceMotion\)/);
});
