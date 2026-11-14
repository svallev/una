// Reflujo de la página de inicio a 320 px (H-025-02): con una columna, una pista `1fr` tiene mínimo automático
// y la fila del ajuste de la escena 5 (`white-space: nowrap`) la ensancha hasta sacar el texto por la derecha.
// La escena 5 es un `.split` sin modificador (regla de `shared/base.css`); las escenas con `.split--hold` y
// `.split--rev` tienen su propia regla móvil en `a/scene.css`.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { MIN_JOURNEY_HEIGHT } from "../home/src/shared/mode.js";
import { titleHtml } from "../home/src/shared/i18n.js";

const src = join(dirname(fileURLToPath(import.meta.url)), "..", "home", "src");
const css = (...path) => readFileSync(join(src, ...path), "utf8");

/** El cuerpo del primer bloque `@media (max-width: <width>px)` de [text]. */
function mobileBlock(text, width) {
  const start = text.indexOf(`@media (max-width: ${width}px)`);
  assert.notEqual(start, -1, `falta el bloque @media (max-width: ${width}px)`);
  let depth = 0;
  for (let i = text.indexOf("{", start); i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}" && --depth === 0) return text.slice(start, i + 1);
  }
  throw new Error("bloque móvil sin cerrar");
}

/** Las columnas que fija, en el bloque móvil, la regla cuyo selector casa con [selector]. */
function mobileColumns(text, selector) {
  const rule = mobileBlock(text, 860).match(new RegExp(`(?:^|[}\\s])${selector}\\s*\\{([^}]*)\\}`));
  assert.ok(rule, `falta la regla móvil de ${selector}`);
  const columns = rule[1].match(/grid-template-columns:\s*([^;]+);/);
  assert.ok(columns, `la regla móvil de ${selector} no fija grid-template-columns`);
  return columns[1].trim();
}

test("CA-025-16: en móvil, la columna única de .split (escena 5) no se ensancha con su contenido", () => {
  assert.equal(mobileColumns(css("shared", "base.css"), "\\.split"), "minmax(0, 1fr)");
});

test("CA-025-16: en móvil, la columna única de .split--hold y .split--rev no se ensancha con su contenido", () => {
  assert.equal(mobileColumns(css("a", "scene.css"), "\\.split--hold,\\s*\\.split--rev"), "minmax(0, 1fr)");
});

// Móvil en horizontal (H-025-03): por debajo de MIN_JOURNEY_HEIGHT de alto la página sale apilada (CL-025-13), y
// las reglas móviles de `max-width: 860px` están pensadas para vertical (una columna, titulares a 14,5vw, una
// línea por `.ln`). Un bloque propio para horizontal bajo pone texto y móvil lado a lado y mide los titulares
// también por el alto. Solo se aplica a la versión apilada (`html:not(.fx)`) y no toca vertical ni escritorio.
const LANDSCAPE_LOW = `@media (orientation: landscape) and (max-height: ${MIN_JOURNEY_HEIGHT - 1}px)`;

/** El cuerpo del bloque `@media` que empieza por [head] en [text] (sin las llaves exteriores). */
function block(text, head) {
  const start = text.indexOf(head);
  assert.notEqual(start, -1, `falta el bloque ${head}`);
  let depth = 0;
  const open = text.indexOf("{", start);
  for (let i = open; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}" && --depth === 0) return text.slice(open + 1, i);
  }
  throw new Error("bloque sin cerrar");
}

/** Las reglas de [body] como pares [selectores, declaraciones], sin comentarios. */
function rules(body) {
  return [...body.replace(/\/\*[\s\S]*?\*\//g, "").matchAll(/([^{}]+)\{([^}]*)\}/g)].map((m) => [m[1].trim(), m[2].trim()]);
}

/** Las declaraciones de la regla de [body] cuyo selector es exactamente [selector]. */
function declarations(body, selector) {
  const found = rules(body).find(([s]) => s.replace(/\s+/g, " ") === selector);
  assert.ok(found, `falta la regla ${selector}`);
  return found[1];
}

test("CA-025-16, CL-025-13: hay un bloque para horizontal bajo con el umbral de la versión apilada", () => {
  const scene = css("a", "scene.css");
  assert.ok(scene.includes(LANDSCAPE_LOW), `falta ${LANDSCAPE_LOW} en a/scene.css`);
  // Va después del bloque móvil, para ganarle con la misma especificidad.
  assert.ok(scene.indexOf(LANDSCAPE_LOW) > scene.indexOf("@media (max-width: 860px)"));
});

test("CA-025-16, CL-025-13: el bloque de horizontal bajo solo toca la versión apilada", () => {
  for (const [selectors] of rules(block(css("a", "scene.css"), LANDSCAPE_LOW))) {
    for (const selector of selectors.split(",")) {
      assert.match(selector.trim(), /^html:not\(\.fx\) /, `«${selector.trim()}» no va limitado a html:not(.fx)`);
    }
  }
});

test("CA-025-16, CL-025-13: en horizontal bajo, texto y móvil van lado a lado y el titular se mide por el alto", () => {
  const body = block(css("a", "scene.css"), LANDSCAPE_LOW);
  assert.match(declarations(body, "html:not(.fx) .split"), /grid-template-columns:\s*minmax\(0, max-content\) auto/);
  assert.match(declarations(body, "html:not(.fx) .split--rev"), /grid-template-columns:\s*auto minmax\(0, max-content\)/);
  assert.match(declarations(body, "html:not(.fx) .big"), /font-size:[^;]*svh/);
  // Sin un salto por línea del titular: las líneas se juntan si caben.
  assert.match(declarations(body, "html:not(.fx) .ln"), /display:\s*inline/);
});

test("CA-025-16: vertical y escritorio no dependen de la orientación (sus bloques no cambian)", () => {
  for (const text of [css("shared", "base.css"), css("a", "scene.css")]) {
    assert.doesNotMatch(mobileBlock(text, 860), /orientation|max-height/);
    // Solo un bloque con orientación: el de horizontal bajo.
    assert.equal(text.split("orientation").length - 1, text === css("a", "scene.css") ? 1 : 0);
  }
});

test("CA-025-16: en horizontal bajo, el titular de la escena 3 va en dos líneas exactas («Just ONE.» / «Until it's done»)", () => {
  const body = block(css("a", "scene.css"), LANDSCAPE_LOW);
  // La primera línea, sola; las otras dos, juntas y sin partirse (el espacio entre ellas lo pone titleHtml).
  assert.match(declarations(body, "html:not(.fx) .sc--una .ln:first-child"), /display:\s*block/);
  assert.match(declarations(body, "html:not(.fx) .sc--una .big"), /white-space:\s*nowrap/);
  // Las líneas de titleHtml van separadas por un espacio: «Until» y «it's done» no se pegan.
  assert.match(titleHtml("scenes.una.title"), /<\/span><\/span> <span class="ln">/);
});

test("CA-025-16: en horizontal bajo, texto y móvil se agrupan en el centro (sin el centro vacío)", () => {
  const split = declarations(block(css("a", "scene.css"), LANDSCAPE_LOW), "html:not(.fx) .split");
  // Columnas a su medida (ninguna `1fr` que empuje el móvil al borde) y el sobrante, a los dos lados.
  assert.doesNotMatch(split, /1fr/);
  assert.match(split, /justify-content:\s*center/);
});

test("CA-025-16: en horizontal bajo, el contenido respeta la cámara perforada (zona segura a los lados)", () => {
  const meta = readFileSync(join(src, "..", "index.html"), "utf8").match(/<meta name="viewport" content="([^"]*)"/);
  assert.ok(meta, "falta <meta name=viewport> en home/index.html");
  // Sin `viewport-fit=cover` el navegador no da los márgenes de la zona segura.
  assert.match(meta[1], /viewport-fit=cover/);
  const body = block(css("a", "scene.css"), LANDSCAPE_LOW);
  for (const selector of ["html:not(.fx) .sc", "html:not(.fx) .sc > .end"]) {
    const d = declarations(body, selector);
    assert.match(d, /max\(var\(--margin\), env\(safe-area-inset-left, 0px\)\)/, `${selector} sin zona segura izquierda`);
    assert.match(d, /max\(var\(--margin\), env\(safe-area-inset-right, 0px\)\)/, `${selector} sin zona segura derecha`);
  }
});

test("CA-025-16: en horizontal bajo, la escena 3 cabe en la ventana y su móvil no sube bajo la cabecera", () => {
  const una = declarations(block(css("a", "scene.css"), LANDSCAPE_LOW), "html:not(.fx) .sc--una");
  // La cabecera fija mide 64 px (16 + botón de 48 + 16): el contenido empieza al menos 8 px por debajo.
  const top = Number(una.match(/padding-top:\s*(\d+)px/)?.[1]);
  assert.ok(top >= 72, `padding-top de la escena 3: ${top}`);
  // Móvil + rellenos ≤ 100svh: el móvil mide 2,264 veces su ancho; con 33svh, 0,33 × 2,264 ≈ 75 % del alto,
  // y los rellenos (≤ 92 px) caben en el 25 % que queda a partir de 360 px de alto.
  const bottom = Number(una.match(/padding-bottom:\s*(\d+)px/)?.[1]);
  const pw = declarations(block(css("a", "scene.css"), LANDSCAPE_LOW), "html:not(.fx) .sc--una .phone--hold").match(/(\d+)svh/);
  assert.ok(pw, "el móvil de la escena 3 no se mide por el alto");
  assert.ok(Number(pw[1]) / 100 * 2.264 * 360 + top + bottom <= 360, `no cabe a 360 px: ${pw[1]}svh, ${top}+${bottom}`);
});

test("CA-025-16: en horizontal bajo, las escenas 3 y 4 van sin entradilla, como en vertical (también a más de 860 de ancho)", () => {
  const body = block(css("a", "scene.css"), LANDSCAPE_LOW);
  assert.match(declarations(body, "html:not(.fx) .sc--una .lead, html:not(.fx) .sc--amano .lead"), /display:\s*none/);
});
