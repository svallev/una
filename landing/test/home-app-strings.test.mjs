// `gen/site.json`: lo que la página de inicio toma de la app (spec 025, CA-025-06, 08 y 14; plan §2.3 y §6.1):
// el nombre y el logotipo de `identity.yaml`, las direcciones de las tiendas y los textos de la app de las ARB.
import assert from "node:assert/strict";
import { cpSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import {
  BuildError,
  HOME_APP_TEXT_KEYS,
  STORE_HOSTS,
  homeGenDir,
  homeSite,
  readIdentity,
  storeUrls,
  writeHomeGen,
} from "../build.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

let base;
before(() => {
  base = world();
  writeHomeGen(base.paths);
});
after(() => base.cleanup());

const arbOf = (paths, lang) => JSON.parse(read(lang === "es" ? paths.arbEs : paths.arbEn));
const siteOf = (w) => JSON.parse(read(join(homeGenDir(w.paths), "site.json")));

/** Una copia del mundo con sus propias ARB (en el mundo base se leen del repositorio). */
function withOwnArb() {
  const w = cloneWorld(base);
  for (const [key, name] of [["arbEs", "app_es.arb"], ["arbEn", "app_en.arb"]]) {
    const copy = join(w.dir, name);
    cpSync(w.paths[key], copy);
    w.paths[key] = copy;
  }
  return w;
}

describe("CA-025-06: los textos de la app, tal cual (lista cerrada, plan §2.3)", () => {
  test("la lista: el botón de completar, el menú, el listado y los dos ajustes (nombre y subtítulo)", () => {
    assert.deepEqual(HOME_APP_TEXT_KEYS, [
      "completeButton",
      "menuButton",
      "listTitle",
      "listHelp",
      "listNewTask",
      "settingsKeepAwake",
      "settingsKeepAwakeHint",
      "settingsLockZoom",
      "settingsLockZoomHint",
    ]);
  });

  test("site.json lleva exactamente esos textos, iguales a los de app_es.arb y app_en.arb", () => {
    const site = siteOf(base);
    for (const lang of ["es", "en"]) {
      const arb = arbOf(base.paths, lang);
      assert.deepEqual(Object.keys(site.app[lang]), HOME_APP_TEXT_KEYS);
      for (const key of HOME_APP_TEXT_KEYS) assert.equal(site.app[lang][key], arb[key], `${lang}.${key}`);
    }
    assert.deepEqual(Object.keys(site.app).sort(), ["en", "es"]);
  });

  test("si la app cambia un texto, la página cambia con él (CL-025-9)", () => {
    const w = withOwnArb();
    try {
      edit(w.paths.arbEn, (t) => t.replace('"completeButton": "Press to complete"', '"completeButton": "Hold <b> to finish"'));
      writeHomeGen(w.paths);
      assert.equal(siteOf(w).app.en.completeButton, "Hold <b> to finish");
    } finally {
      w.cleanup();
    }
  });

  for (const lang of ["es", "en"]) {
    test(`si falta un texto en app_${lang}.arb (o no es texto), la construcción falla`, () => {
      const w = withOwnArb();
      try {
        const path = lang === "es" ? w.paths.arbEs : w.paths.arbEn;
        const arb = arbOf(w.paths, lang);
        delete arb.listHelp;
        writeFileSync(path, JSON.stringify(arb));
        assert.throws(() => writeHomeGen(w.paths), (e) => e instanceof BuildError && e.message.includes(`app_${lang}.arb`) && e.message.includes("listHelp"));
        arb.listHelp = 3;
        writeFileSync(path, JSON.stringify(arb));
        assert.throws(() => writeHomeGen(w.paths), /listHelp/);
        writeFileSync(path, "{ no es json");
        assert.throws(() => writeHomeGen(w.paths), BuildError);
      } finally {
        w.cleanup();
      }
    });
  }
});

describe("CA-025-14: el nombre y el logotipo salen de la identidad", () => {
  test("site.json lleva displayName y wordmark de identity.yaml", () => {
    const identity = readIdentity(read(base.paths.identity));
    const site = siteOf(base);
    assert.equal(site.appName, identity.displayName);
    assert.equal(site.wordmark, identity.wordmark);
    assert.deepEqual(Object.keys(site).sort(), ["app", "appName", "stores", "wordmark"]);
  });

  test("otro nombre en la identidad cambia site.json", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro"').replace(/wordmark: "[^"]*"/, 'wordmark: "zorro."'));
      writeHomeGen(w.paths);
      assert.equal(siteOf(w).appName, "Zorro");
      assert.equal(siteOf(w).wordmark, "zorro.");
    } finally {
      w.cleanup();
    }
  });
});

describe("CA-025-08: las direcciones de las tiendas, de la identidad y validadas (plan §6.1)", () => {
  const identity = (appStoreUrl, googlePlayUrl) => ({ displayName: "X", wordmark: "x.", appStoreUrl, googlePlayUrl });

  test("hoy, sin ficha: las dos claves están en identity.yaml, vacías, y site.json lleva null", () => {
    const real = readIdentity(read(base.paths.identity));
    assert.equal(real.appStoreUrl, "");
    assert.equal(real.googlePlayUrl, "");
    assert.deepEqual(siteOf(base).stores, { appStoreUrl: null, googlePlayUrl: null });
  });

  test("con dirección (una, otra o las dos), tal cual", () => {
    const apple = "https://apps.apple.com/es/app/x/id123456789";
    const play = "https://play.google.com/store/apps/details?id=com.example.x&hl=es";
    assert.deepEqual(storeUrls(identity(apple, "")), { appStoreUrl: apple, googlePlayUrl: null });
    assert.deepEqual(storeUrls(identity("", play)), { appStoreUrl: null, googlePlayUrl: play });
    assert.deepEqual(storeUrls(identity(apple, play)), { appStoreUrl: apple, googlePlayUrl: play });
    assert.deepEqual(STORE_HOSTS, { appStoreUrl: "apps.apple.com", googlePlayUrl: "play.google.com" });
  });

  test("una dirección en identity.yaml llega a site.json", () => {
    const w = cloneWorld(base);
    try {
      const play = "https://play.google.com/store/apps/details?id=com.example.x";
      edit(w.paths.identity, (t) => t.replace('googlePlayUrl: ""', `googlePlayUrl: "${play}"`));
      writeHomeGen(w.paths);
      assert.deepEqual(siteOf(w).stores, { appStoreUrl: null, googlePlayUrl: play });
    } finally {
      w.cleanup();
    }
  });

  test("sin alguna de las dos claves en identity.yaml, la construcción falla", () => {
    for (const key of ["appStoreUrl", "googlePlayUrl"]) {
      const w = cloneWorld(base);
      try {
        edit(w.paths.identity, (t) => t.replace(new RegExp(`^${key}:.*\\n`, "m"), ""));
        assert.throws(() => writeHomeGen(w.paths), (e) => e instanceof BuildError && e.message.includes(`falta «${key}»`));
      } finally {
        w.cleanup();
      }
    }
  });

  const BAD = {
    "http, no https": ["http://apps.apple.com/app/id1", "http://play.google.com/store/apps/details?id=a"],
    "otro anfitrión": ["https://apple.com/app/id1", "https://example.com/store?id=a"],
    "la tienda de la otra": ["https://play.google.com/store/apps/details?id=a", "https://apps.apple.com/app/id1"],
    "un subdominio": ["https://evil.apps.apple.com/app/id1", "https://play.google.com.evil.example/x"],
    "con usuario": ["https://user@apps.apple.com/app/id1", "https://a:b@play.google.com/x"],
    "con puerto": ["https://apps.apple.com:443/app/id1", "https://play.google.com:8443/x"],
    "anfitrión en mayúsculas o con %": ["https://APPS.apple.com/app/id1", "https://play.google.c%6fm/x"],
    "sin protocolo": ["apps.apple.com/app/id1", "//play.google.com/x"],
    "javascript:": ["javascript:alert(1)", "javascript://play.google.com/%0aalert(1)"],
    "con espacios o comillas": ["https://apps.apple.com/app/id1 x", 'https://play.google.com/x"onclick=1'],
    "con < >": ["https://apps.apple.com/<script>", "https://play.google.com/x>"],
    "con un carácter no ASCII o de control": ["https://apps.apple.com/app/ñ", `https://play.google.com/x${String.fromCharCode(0x202e)}`],
  };
  for (const [why, [apple, play]] of Object.entries(BAD)) {
    test(`falla: ${why}`, () => {
      assert.throws(() => storeUrls(identity(apple, "")), (e) => e instanceof BuildError && e.message.includes("appStoreUrl"));
      assert.throws(() => storeUrls(identity("", play)), (e) => e instanceof BuildError && e.message.includes("googlePlayUrl"));
    });
  }

  test("una dirección mala en identity.yaml hace fallar la construcción de la página de inicio", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace('appStoreUrl: ""', 'appStoreUrl: "https://example.com/app"'));
      assert.throws(() => writeHomeGen(w.paths), /appStoreUrl/);
      assert.throws(() => homeSite(w.paths), /apps\.apple\.com/);
    } finally {
      w.cleanup();
    }
  });
});

test("CA-025-06: site.json se escribe en home/gen/ (fuera de git)", () => {
  const gitignore = readFileSync(join(base.paths.repoRoot, ".gitignore"), "utf8");
  assert.match(gitignore, /^landing\/home\/gen\/$/m);
});
