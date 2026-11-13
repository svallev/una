// Reflujo de la página de inicio a 320 px (H-025-02): con una columna, una pista `1fr` tiene mínimo automático
// y la fila del ajuste de la escena 5 (`white-space: nowrap`) la ensancha hasta sacar el texto por la derecha.
// La escena 5 es un `.split` sin modificador (regla de `shared/base.css`); las escenas con `.split--hold` y
// `.split--rev` tienen su propia regla móvil en `a/scene.css`.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

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
