// Código de terceros de la página de inicio, con criterio (spec 025, CA-025-18; plan §4 y §6.1).
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import config from "../home/vite.config.mjs";
import { read, world } from "./support.mjs";

const LANDING = join(import.meta.dirname, "..");
const pkg = JSON.parse(read(join(LANDING, "package.json")));
const lock = JSON.parse(read(join(LANDING, "package-lock.json")));
const EXACT = /^\d+\.\d+\.\d+$/;

describe("CA-025-18: versiones fijadas y lista cerrada de tres dependencias", () => {
  test("package.json: privado, sin scripts y con las tres dependencias del plan, a versión exacta", () => {
    assert.equal(pkg.private, true);
    assert.equal(pkg.scripts, undefined, "package.json no puede llevar scripts");
    assert.deepEqual(Object.keys(pkg).sort(), ["dependencies", "devDependencies", "name", "private", "type"]);
    assert.deepEqual(pkg.dependencies, { gsap: "3.15.1", lenis: "1.3.27" });
    assert.deepEqual(pkg.devDependencies, { vite: "8.3.8" });
    for (const [name, v] of Object.entries({ ...pkg.dependencies, ...pkg.devDependencies })) {
      assert.match(v, EXACT, `${name}: «${v}» no es una versión exacta`);
    }
  });

  test(".npmrc: sin scripts de instalación y versiones exactas al añadir", () => {
    const lines = read(join(LANDING, ".npmrc")).split("\n").map((l) => l.trim());
    assert.ok(lines.includes("ignore-scripts=true"));
    assert.ok(lines.includes("save-exact=true"));
  });

  test("package-lock.json: las mismas versiones, todo del registro de npm y con su suma", () => {
    assert.equal(lock.lockfileVersion, 3);
    const root = lock.packages[""];
    assert.deepEqual(root.dependencies, pkg.dependencies);
    assert.deepEqual(root.devDependencies, pkg.devDependencies);
    for (const [name, v] of Object.entries({ ...pkg.dependencies, ...pkg.devDependencies })) {
      assert.equal(lock.packages[`node_modules/${name}`]?.version, v, `${name} en el lockfile`);
    }
    const entries = Object.entries(lock.packages).filter(([path]) => path !== "");
    assert.ok(entries.length > 3);
    for (const [path, entry] of entries) {
      assert.match(entry.resolved ?? "", /^https:\/\/registry\.npmjs\.org\//, `${path}: resolved fuera del registro`);
      assert.match(entry.integrity ?? "", /^sha512-[A-Za-z0-9+/]+=*$/, `${path}: sin integrity sha512`);
    }
  });

  test("las dependencias que van al navegador no tienen dependencias propias", () => {
    for (const name of Object.keys(pkg.dependencies)) {
      assert.equal(lock.packages[`node_modules/${name}`].dependencies, undefined, name);
    }
  });

  test("el lockfile hecho en macOS trae los binarios de Linux de Vite (la CI y Vercel construyen en Linux)", () => {
    for (const p of ["node_modules/@rolldown/binding-linux-x64-gnu", "node_modules/lightningcss-linux-x64-gnu"]) {
      assert.ok(lock.packages[p], `falta ${p} en el lockfile`);
    }
  });

  test("la configuración de Vite no lleva plugins y no publica mapas ni el relleno de modulepreload", () => {
    assert.equal(config.plugins, undefined);
    assert.equal(config.build.rolldownOptions.plugins, undefined);
    assert.equal(config.build.sourcemap, false);
    assert.deepEqual(config.build.modulePreload, { polyfill: false });
    assert.equal(config.build.assetsInlineLimit, 0);
    assert.equal(config.build.emptyOutDir, false);
    assert.equal(config.build.rolldownOptions.output.comments.legal, true);
  });
});

describe("CA-025-18: el aviso de GSAP se conserva en lo publicado", () => {
  let w;
  before(async () => {
    w = world();
    w.build();
    await w.buildHome();
  });
  after(() => w.cleanup());

  test("el programa construido lleva la cabecera de copyright de GSAP y de ScrollTrigger, con su versión", () => {
    const js = readdirSync(join(w.dist, "assets")).filter((f) => f.endsWith(".js"));
    assert.equal(js.length, 1);
    const code = readFileSync(join(w.dist, "assets", js[0]), "utf8");
    const v = pkg.dependencies.gsap;
    for (const header of [`GSAP ${v}`, `ScrollTrigger ${v}`]) {
      assert.match(code, new RegExp(`/\\*!\\s*\\*\\s*${header.replaceAll(".", "\\.")}\\s*\\*\\s*https://gsap\\.com`), `falta la cabecera «${header}»`);
    }
    assert.ok(code.includes("@license Copyright 2008-2026, GreenSock. All rights reserved."));
    assert.ok(code.includes("Subject to the terms at https://gsap.com/standard-license"));
  });
});
