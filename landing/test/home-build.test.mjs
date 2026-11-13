// La página de inicio es la landing y las otras páginas no cambian (spec 025, CA-025-01).
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { BuildError, buildHome, homeGenDir, readIdentity, writeHomeGen } from "../build.mjs";
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

  test("lleva los archivos de public/ que usa la versión A de la maqueta, y nada de la variante B", () => {
    for (const f of ["favicon.png", "img/icon-512.png", "fonts/Archivo-Variable.woff2", "fonts/SpaceMono-Regular.woff2", "fonts/SpaceMono-Bold.woff2"]) {
      assert.ok(existsSync(join(base.dist, f)), `falta ${f}`);
    }
    for (const f of ["b/index.html", "img/badges", "propuestas"]) assert.ok(!existsSync(join(base.dist, f)), `sobra ${f}`);
  });
});

describe("CA-025-01: build.mjs escribe home/gen/ para Vite", () => {
  test("site.json lleva el nombre, el logotipo y las tiendas de la identidad (sin ficha, null)", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro"').replace(/googlePlayUrl: "[^"]*"/, 'googlePlayUrl: "https://play.google.com/store/apps/details?id=x"'));
      assert.deepEqual(writeHomeGen(w.paths), ["site.json"]);
      const site = JSON.parse(read(join(homeGenDir(w.paths), "site.json")));
      assert.deepEqual(site, {
        appName: "Zorro",
        wordmark: identity.wordmark,
        stores: { appStoreUrl: null, googlePlayUrl: "https://play.google.com/store/apps/details?id=x" },
      });
    } finally {
      w.cleanup();
    }
  });

  test("una dirección de tienda que no es de su tienda hace fallar la construcción", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/appStoreUrl: "[^"]*"/, 'appStoreUrl: "https://evil.example/app"'));
      assert.throws(() => writeHomeGen(w.paths), BuildError);
    } finally {
      w.cleanup();
    }
  });

  test("las tiendas: App Store primero, un rótulo de texto sin imágenes y «muy pronto» sin dirección", async () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/appStoreUrl: "[^"]*"/, 'appStoreUrl: "https://apps.apple.com/app/id1"'));
      await w.buildHome();
      // El programa que enlaza la página: la copia conserva el de la base (Vite no vacía dist/).
      const script = read(join(w.dist, "index.html")).match(/src="\/assets\/([^"]+\.js)"/)[1];
      const code = read(join(w.dist, "assets", script));
      assert.ok(code.includes("https://apps.apple.com/app/id1"), "la dirección de la identidad no llega al programa");
      assert.ok(!code.includes("/img/badges/"), "quedan insignias");
    } finally {
      w.cleanup();
    }
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
