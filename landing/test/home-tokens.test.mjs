// Los colores de la página de inicio salen de los tokens (spec 025, CA-025-14 y CA-025-15; plan §3 y §6.2): el
// grupo `landing` de `design/tokens.json`, sus pares de contraste en `tools/validate-tokens.mjs` (con la única
// salvedad con nombre, la palabra destacada `paperFiber` sobre `orange`) y su sitio en el `tokens.css` de la
// página de inicio (no en el de las otras cuatro).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { REPO_ROOT, defaultPaths, homeGenDir, tokensCss, writeHomeGen } from "../build.mjs";
import { read, world } from "./support.mjs";

const VALIDATOR = join(REPO_ROOT, "tools/validate-tokens.mjs");
const tokens = JSON.parse(readFileSync(defaultPaths().tokens, "utf8"));

let tmp;
before(() => {
  tmp = mkdtempSync(join(tmpdir(), "landing-tokens-"));
});
after(() => rmSync(tmp, { recursive: true, force: true }));

/** Corre el validador sobre una copia de los tokens cambiada por [change]. */
function validate(change = () => {}) {
  const copy = structuredClone(tokens);
  change(copy);
  const file = join(tmp, `tokens-${Math.random().toString(36).slice(2)}.json`);
  writeFileSync(file, JSON.stringify(copy));
  const r = spawnSync(process.execPath, [VALIDATOR, "--tokens", file], { encoding: "utf8" });
  return { code: r.status, out: `${r.stdout}${r.stderr}` };
}

describe("CA-025-14: los fondos de la página de inicio son tokens", () => {
  test("grupo `landing` con los cuatro fondos de la maqueta, sin cambios (plan §3, P-025-2)", () => {
    const values = Object.fromEntries(Object.entries(tokens.landing).filter(([k]) => !k.startsWith("$")).map(([k, v]) => [k, v.$value]));
    assert.deepEqual(values, { magenta: "#D4145A", magentaDeep: "#B8146E", orange: "#FF8A1F", yellow: "#FFD21F" });
    assert.equal(tokens.landing.$type, "color");
    assert.ok(!("landing" in tokens.color), "los fondos van en su grupo, no en `color` (la app no los tiene)");
  });

  test("el tokens.css de la página de inicio lleva los fondos; el de las otras cuatro, no", () => {
    const home = tokensCss(tokens, { landing: true });
    assert.match(home, /--landing-magenta: #D4145A;/);
    assert.match(home, /--landing-magenta-deep: #B8146E;/);
    assert.match(home, /--landing-orange: #FF8A1F;/);
    assert.match(home, /--landing-yellow: #FFD21F;/);
    assert.ok(!tokensCss(tokens).includes("--landing"), "el tokens.css de las otras páginas cambió");
  });

  test("home/gen/tokens.css es el de la página de inicio", () => {
    const w = world();
    try {
      writeHomeGen(w.paths);
      assert.equal(read(join(homeGenDir(w.paths), "tokens.css")), tokensCss(tokens, { landing: true }));
    } finally {
      w.cleanup();
    }
  });

  test("sin el grupo `landing`, la página de inicio no se construye", () => {
    const copy = structuredClone(tokens);
    delete copy.landing;
    assert.throws(() => tokensCss(copy, { landing: true }), /landing/);
  });
});

describe("CA-025-15: contraste de los fondos de la página de inicio (validate-tokens)", () => {
  test("los tokens del repositorio pasan, y la salvedad paperFiber / orange se dice con su razón", () => {
    const r = validate();
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /salvedad: landing\/palabra destacada \(paperFiber\) \/ orange: 2\.31 \(< 3\)/);
  });

  const breaks = (why, change, ...messages) =>
    test(`falla: ${why}`, () => {
      const r = validate(change);
      assert.notEqual(r.code, 0, r.out);
      for (const m of messages) assert.ok(r.out.includes(m), `falta «${m}» en:\n${r.out}`);
    });

  breaks("sin el grupo `landing`", (t) => delete t.landing, 'Falta el grupo "landing"');
  breaks("sin uno de los cuatro fondos", (t) => delete t.landing.orange, "Falta el color landing.orange");
  breaks("un fondo que no es hex", (t) => (t.landing.yellow.$value = "amarillo"), "Falta el color landing.yellow");
  breaks(
    "un magenta claro: el texto en paper y la palabra destacada no llegan",
    (t) => (t.landing.magenta.$value = "#FF9EC4"),
    "Contraste insuficiente landing/texto (paper) / magenta",
    "Contraste insuficiente (texto grande) landing/palabra destacada (palette.classic.0) / magenta",
    "Contraste no textual insuficiente landing/anillo de foco (paper) / magenta",
  );
  breaks(
    "un magenta oscuro de la escena 4: el borde de tinta no se distingue",
    (t) => (t.landing.magentaDeep.$value = "#5A0A36"),
    "Contraste no textual insuficiente landing/borde de tinta (ink) / magentaDeep",
  );
  breaks(
    "un amarillo oscuro: el texto en tinta y la palabra destacada en magenta no llegan",
    (t) => (t.landing.yellow.$value = "#7A6400"),
    "Contraste insuficiente landing/texto (ink) / yellow",
    "Contraste insuficiente (texto grande) landing/palabra destacada (landing.magenta) / yellow",
  );
  breaks(
    "un naranja oscuro: el texto en tinta no llega y la salvedad ya no hace falta (hay que quitarla)",
    (t) => (t.landing.orange.$value = "#7A3A00"),
    "Contraste insuficiente landing/texto (ink) / orange",
    "La salvedad landing/palabra destacada (paperFiber) / orange ya no hace falta",
  );
});
