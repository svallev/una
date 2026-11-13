// La página de inicio es la landing y las otras páginas no cambian (spec 025, CA-025-01).
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { BuildError, buildHome, homeGenDir, readIdentity, renderHomeHtml, writeHomeGen } from "../build.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

const FIXTURES = join(import.meta.dirname, "fixtures/023");

let base;
let identity;
before(async () => {
  base = world();
  base.build();
  await base.buildHome();
  identity = readIdentity(read(base.paths.identity));
});
after(() => base.cleanup());

describe("CA-025-01: cinco páginas, la de inicio es la landing", () => {
  test("existen las cinco páginas, como antes", () => {
    for (const f of ["index.html", "privacy/index.html", "licenses/index.html", "help/index.html", "404.html"]) {
      assert.ok(existsSync(join(base.dist, f)), `falta ${f}`);
    }
    const html = readdirSync(base.dist, { recursive: true }).filter((f) => String(f).endsWith(".html"));
    assert.equal(html.length, 5, `hay otras páginas: ${html.join(", ")}`);
  });

  test("/help y la página de error son idénticas byte a byte a las de la 023 (capturadas en T-025-01)", () => {
    for (const f of ["help/index.html", "404.html"]) {
      assert.ok(readFileSync(join(base.dist, f)).equals(readFileSync(join(FIXTURES, f))), `${f} cambió`);
    }
  });

  test("la de inicio es la que construye Vite: carga su programa, no la página sin JavaScript de la 023", () => {
    const html = read(join(base.dist, "index.html"));
    assert.match(html, /<script type="module" crossorigin src="\/assets\/[^"]+\.js"><\/script>/);
    assert.ok(!html.includes('href="/site.css"'), "lleva la hoja de las páginas sin JavaScript");
  });

  test("el nombre del título y del encabezado sale de la identidad (CA-025-14)", () => {
    const html = read(join(base.dist, "index.html"));
    assert.ok(html.includes(`<title>${identity.displayName}</title>`), html);
    assert.ok(html.includes(`>${identity.displayName}</h1>`), html);
  });
});

describe("CA-025-01: build.mjs escribe home/gen/ para Vite", () => {
  test("otro nombre en la identidad cambia la página generada", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro <b>"'));
      assert.deepEqual(writeHomeGen(w.paths).sort(), ["index.html", "site.json", "tokens.css"]);
      const html = read(join(homeGenDir(w.paths), "index.html"));
      assert.ok(html.includes("<title>Zorro &lt;b&gt;</title>"), "el nombre no se escapa o no se usa");
      assert.ok(!html.includes(`<title>${identity.displayName}</title>`), "sigue el nombre anterior");
      assert.match(read(join(homeGenDir(w.paths), "tokens.css")), /--color-paper:/);
    } finally {
      w.cleanup();
    }
  });

  test("un marcador desconocido o mal cerrado en la plantilla hace fallar la construcción", () => {
    assert.throws(() => renderHomeHtml("<p>{{otro}}</p>", identity), BuildError);
    assert.throws(() => renderHomeHtml("<p>{{title}</p>", identity), BuildError);
    assert.equal(renderHomeHtml("<p>{{name}}</p>", { displayName: "A & B" }), "<p>A &amp; B</p>");
  });

  test("Vite no escribe fuera de la dist/ de al lado de home/", async () => {
    const w = cloneWorld(base);
    try {
      await assert.rejects(buildHome({ ...w.paths, out: join(w.dir, "otra", "dist") }), BuildError);
    } finally {
      w.cleanup();
    }
  });
});
