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
  assert.match(declarations(body, "html:not(.fx) .split"), /grid-template-columns:\s*minmax\(0, 1fr\) auto/);
  assert.match(declarations(body, "html:not(.fx) .split--rev"), /grid-template-columns:\s*auto minmax\(0, 1fr\)/);
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
