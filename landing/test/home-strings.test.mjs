// Los textos de la página de inicio (spec 025, §7): `landing/home/src/strings.es.json` y `strings.en.json`.
// Se comparan con la tabla del §7 de la spec (leída del propio `spec.md`), con la otra lengua y con la app.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";
import { REPO_ROOT, defaultPaths } from "../build.mjs";

const HOME_SRC = join(defaultPaths().homeDir, "src");
const strings = {
  es: JSON.parse(readFileSync(join(HOME_SRC, "strings.es.json"), "utf8")),
  en: JSON.parse(readFileSync(join(HOME_SRC, "strings.en.json"), "utf8")),
};
const arb = {
  es: JSON.parse(readFileSync(join(REPO_ROOT, "app/lib/l10n/app_es.arb"), "utf8")),
  en: JSON.parse(readFileSync(join(REPO_ROOT, "app/lib/l10n/app_en.arb"), "utf8")),
};

/**
 * La tabla del §7 de la spec: `{ key, es, en, f6 }` por clave. Las filas con varias claves (`a` / `b`) reparten
 * sus textos por « / ». `f6` marca las que «no entran hasta F6».
 */
function specTable() {
  const spec = readFileSync(join(REPO_ROOT, "specs/025-landing-de-producto/spec.md"), "utf8");
  const from = spec.indexOf("## 7. Textos");
  const to = spec.indexOf("## 8. ", from);
  assert.ok(from > 0 && to > from, "no encuentro el §7 de la spec");
  const rows = [];
  for (const line of spec.slice(from, to).split("\n")) {
    if (!line.startsWith("| `")) continue;
    const cells = line.split(" | ").map((c) => c.replace(/^\| ?| ?\|$/g, "").trim());
    assert.equal(cells.length, 4, `fila del §7 que no entiendo: ${line}`);
    const keys = [...cells[0].matchAll(/`([A-Za-z]+)`/g)].map((m) => m[1]);
    const split = (cell) => (keys.length === 1 ? [cell] : cell.split(" / "));
    const es = split(cells[1]);
    const en = split(cells[2]);
    assert.equal(es.length, keys.length, `fila del §7: ${line}`);
    assert.equal(en.length, keys.length, `fila del §7: ${line}`);
    const f6 = cells[3].includes("No entra hasta F6");
    keys.forEach((key, i) => rows.push({ key, es: es[i], en: en[i], f6 }));
  }
  return rows;
}

/** Lo que se lee de un texto: los titulares marcan con `*` la palabra destacada y con `|` los saltos de línea. */
const plain = (value) => (Array.isArray(value) ? value.join(" · ") : value.replaceAll("*", "").replaceAll("|", " "));

/** La forma de un valor: las claves de un objeto (y su forma) y la longitud de una lista. */
function shape(value) {
  if (Array.isArray(value)) return `[${value.length}:${value.map(shape).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((k) => `${k}=${shape(value[k])}`).join(",")}}`;
  return typeof value;
}

/** Todos los textos de un archivo, con su ruta de claves. */
function leaves(value, path = []) {
  if (typeof value === "string") return [[path.join("."), value]];
  if (Array.isArray(value)) return value.flatMap((v, i) => leaves(v, [...path, String(i)]));
  return Object.entries(value).flatMap(([k, v]) => leaves(v, [...path, k]));
}

/** Las claves del §7 que no son de la página de inicio, sino de las otras páginas (`landing/src/strings.json`). */
const OTHER_PAGES = ["licensesWebTitle"];
const allRows = specTable();
const table = allRows.filter((r) => !OTHER_PAGES.includes(r.key));

describe("CA-025-09: español e inglés dicen lo mismo", () => {
  test("las mismas claves, con la misma forma (listas de la misma longitud)", () => {
    assert.equal(shape(strings.es), shape(strings.en));
  });

  test("ningún texto vacío", () => {
    for (const lang of ["es", "en"]) {
      for (const [key, text] of leaves(strings[lang])) assert.ok(text.trim(), `${lang}.${key} está vacío`);
    }
  });

  test("el único marcador es {appName}, en las mismas claves en los dos idiomas", () => {
    const withName = {};
    for (const lang of ["es", "en"]) {
      withName[lang] = [];
      for (const [key, text] of leaves(strings[lang])) {
        for (const m of text.matchAll(/\{([^{}]*)\}/g)) {
          assert.equal(m[1], "appName", `${lang}.${key} lleva el marcador {${m[1]}}`);
          withName[lang].push(key);
        }
        assert.ok(!/[{}]/.test(text.replaceAll("{appName}", "")), `${lang}.${key} lleva una llave suelta`);
      }
    }
    assert.deepEqual(withName.es, withName.en);
    assert.deepEqual(withName.es.sort(), ["alt.icon", "footerLegal", "metaDescription", "metaTitle", "navHome"]);
  });
});

describe("CA-025-02: los textos son los de la tabla del §7 de la spec", () => {
  test("la tabla se lee entera (ninguna fila se pierde)", () => {
    assert.ok(table.length >= 40, `solo ${table.length} claves en el §7`);
    assert.ok(table.some((r) => r.key === "heroTitle"));
    assert.ok(table.some((r) => r.key === "footerLegal"));
  });

  for (const lang of ["es", "en"]) {
    test(`cada clave del §7 está en ${lang}, con su texto (los titulares, sin las marcas de línea y de palabra)`, () => {
      for (const row of table.filter((r) => !r.f6)) {
        assert.ok(row.key in strings[lang], `falta ${lang}.${row.key}`);
        assert.equal(plain(strings[lang][row.key]), row[lang], `${lang}.${row.key}`);
      }
    });
  }

  test("`licensesWebTitle` (título del bloque de avisos del código de la web en /licenses) está en landing/src/strings.json", () => {
    const pages = JSON.parse(readFileSync(defaultPaths().strings, "utf8"));
    const row = allRows.find((r) => r.key === "licensesWebTitle");
    for (const lang of ["es", "en"]) {
      assert.equal(pages[lang].licensesWebTitle, row[lang]);
      assert.ok(!("licensesWebTitle" in strings[lang]));
    }
  });

  test("las claves que no entran hasta F6 (texto alternativo de las insignias oficiales) no están", () => {
    const f6 = table.filter((r) => r.f6).map((r) => r.key);
    assert.deepEqual(f6.sort(), ["storeAppStoreAlt", "storeGooglePlayAlt"]);
    for (const lang of ["es", "en"]) for (const key of f6) assert.ok(!(key in strings[lang]), `${lang}.${key} no entra hasta F6`);
  });

  test("fuera del §7, solo las descripciones para el lector (`alt`) y el contenido de ejemplo (`sample`)", () => {
    const known = new Set([...table.filter((r) => !r.f6).map((r) => r.key), "alt", "sample"]);
    for (const lang of ["es", "en"]) {
      for (const key of Object.keys(strings[lang])) assert.ok(known.has(key), `${lang}.${key} no está en el §7`);
    }
  });

  test("las marcas de los titulares: líneas no vacías y una palabra destacada (`*…*`) por titular", () => {
    for (const lang of ["es", "en"]) {
      for (const key of ["heroTitle", "manyTitle", "oneTitle", "handyTitle", "awakeTitle", "lightTitle", "endTitle"]) {
        const title = strings[lang][key];
        assert.ok(title.split("|").every((line) => line.trim() === line && line), `${lang}.${key}: «${title}»`);
        assert.equal(title.split("*").length, 3, `${lang}.${key}: una palabra destacada (${title})`);
      }
      for (const [key, text] of leaves(strings[lang])) {
        if (key.endsWith("Title") && !key.startsWith("sample.")) continue;
        if (key.startsWith("sample.progRows.")) continue; // «hora|título|lugar», lo parte el programa
        assert.ok(!/[*|]/.test(text), `${lang}.${key} lleva una marca de titular`);
      }
    }
  });
});

describe("CA-025-06: los textos que son de la app no se copian aquí", () => {
  test("ninguna clave de la maqueta que sea de la app (o que no entra) está", () => {
    const appKeys = ["complete", "completeA11y", "menu", "success1", "success2", "allTasks", "allTasksHint", "newTask", "keepAwakeHint", "lockZoomHint", "switch", "locked", "scenes", "done", "screenAlt"];
    for (const lang of ["es", "en"]) {
      const keys = leaves(strings[lang]).map(([k]) => k.split("."));
      for (const path of keys) for (const part of path) assert.ok(!appKeys.includes(part), `${lang}: ${path.join(".")}`);
    }
  });

  test("ningún texto repite uno de la app (salen de site.json, CA-025-06)", () => {
    const appKeys = ["completeButton", "menuButton", "listTitle", "listHelp", "listNewTask", "successTitle1", "successTitle2", "settingsKeepAwake", "settingsKeepAwakeHint", "settingsLockZoom", "settingsLockZoomHint"];
    for (const lang of ["es", "en"]) {
      const appTexts = new Set(appKeys.map((k) => arb[lang][k]));
      for (const [key, text] of leaves(strings[lang])) assert.ok(!appTexts.has(text), `${lang}.${key} es un texto de la app: «${text}»`);
    }
  });

  test("las entradillas de las escenas 5 y 6 nombran los ajustes con el nombre de la app (CL-025-9)", () => {
    const quote = { es: (s) => `«${s}»`, en: (s) => `“${s}”` };
    for (const lang of ["es", "en"]) {
      assert.ok(strings[lang].awakeLead.includes(quote[lang](arb[lang].settingsKeepAwake)), `${lang}.awakeLead`);
      assert.ok(strings[lang].lightLead.includes(quote[lang](arb[lang].settingsLockZoom)), `${lang}.lightLead`);
    }
  });
});

describe("§7: descripciones para el lector y contenido de ejemplo (los de la maqueta)", () => {
  test("una descripción por móvil y la del icono, con el nombre de la app en la del icono", () => {
    const keys = ["book", "golf", "icon", "lineup", "list", "pdf", "prog", "route", "screen", "trace"];
    for (const lang of ["es", "en"]) {
      assert.deepEqual(Object.keys(strings[lang].alt).sort(), keys);
      assert.ok(strings[lang].alt.icon.includes("{appName}"));
    }
  });

  test("ocho tareas de ejemplo, distintas", () => {
    for (const lang of ["es", "en"]) {
      assert.equal(strings[lang].sample.tasks.length, 8);
      assert.equal(new Set(strings[lang].sample.tasks).size, 8);
    }
  });

  test("cada fila del programa es «hora|título|lugar»", () => {
    for (const lang of ["es", "en"]) {
      for (const row of strings[lang].sample.progRows) assert.match(row, /^\d\d:\d\d\|[^|]+\|[^|]+$/, `${lang}: ${row}`);
    }
  });
});
