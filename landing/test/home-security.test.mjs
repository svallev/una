// Sin terceros ni red en la página de inicio (spec 025, CA-025-12; segunda enmienda del propietario): la CSP de
// «/» (programas y estilos del propio origen, estilos en línea admitidos), un único programa del propio origen,
// sin API de red ni dominios externos en el programa y sin mapas. Las reglas de las otras cuatro páginas no
// cambian.
import assert from "node:assert/strict";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, sep } from "node:path";
import { after, before, describe, test } from "node:test";
import { checkHome, checkSite } from "../check.mjs";
import { cloneWorld, edit, read, specificErrors, world } from "./support.mjs";

let base;
before(async () => {
  base = world();
  base.build();
  await base.buildHome();
});
after(() => base.cleanup());

const all = (dir) => readdirSync(dir, { recursive: true }).map(String);
const programOf = (w) => {
  const js = all(join(w.dist, "assets")).filter((f) => f.endsWith(".js"));
  assert.equal(js.length, 1, `tiene que haber un solo programa: ${js.join(", ")}`);
  return join(w.dist, "assets", js[0]);
};
const cssOf = (w) => {
  const css = all(join(w.dist, "assets")).filter((f) => f.endsWith(".css"));
  assert.equal(css.length, 1, `tiene que haber una sola hoja: ${css.join(", ")}`);
  return join(w.dist, "assets", css[0]);
};

describe("CA-025-12: el programa construido", () => {
  test("un solo <script type=module src> del propio origen, vacío", () => {
    const html = read(join(base.dist, "index.html"));
    const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)];
    assert.equal(scripts.length, 1);
    assert.match(scripts[0][1], /^ type="module" crossorigin src="\/assets\/[^"/]+\.js"$/);
    assert.equal(scripts[0][2], "");
  });

  test("sin mapas de código ni fetch(", () => {
    assert.deepEqual(all(base.dist).filter((f) => f.endsWith(".map")), []);
    const code = readFileSync(programOf(base), "utf8");
    assert.ok(!code.includes("sourceMappingURL"));
    assert.ok(!code.includes("fetch("));
  });

  test("lo construido pasa checkHome y checkSite", () => {
    assert.deepEqual(checkHome(base.paths), []);
    assert.deepEqual(checkSite(base.paths), []);
  });
});

describe("CA-025-12: checkHome, cada regla con un caso que falla", () => {
  const homeFails = (label, fn, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        fn(w);
        const errors = checkHome(w.paths);
        assert.ok(errors.some((e) => pattern.test(e)), `ningún error casa ${pattern}:\n${errors.join("\n")}`);
      } finally {
        w.cleanup();
      }
    });
  const page = (w) => join(w.dist, "index.html");

  homeFails("sin página de inicio", (w) => edit(page(w), () => ""), /tiene 0 <script>/);
  homeFails("dos programas", (w) => edit(page(w), (t) => t.replace("</head>", '<script type="module" src="/assets/x.js"></script></head>')), /tiene 2 <script>/);
  homeFails("un programa de otro origen", (w) => edit(page(w), (t) => t.replace(/src="\/assets\/[^"]+\.js"/, 'src="https://cdn.example/x.js"')), /otro origen/);
  homeFails("un programa escrito dentro", (w) => edit(page(w), (t) => t.replace("></script>", ">alert(1)</script>")), /código escrito dentro/);
  homeFails("un programa que no es módulo", (w) => edit(page(w), (t) => t.replace('type="module" ', "")), /type="module"/);
  homeFails("un programa que no está en dist/", (w) => edit(page(w), (t) => t.replace(/src="\/assets\/[^"]+\.js"/, 'src="/assets/otro.js"')), /no está en dist/);
  homeFails("un recurso de otro origen", (w) => edit(page(w), (t) => t.replace("</head>", '<link rel="stylesheet" href="https://cdn.example/x.css"></head>')), /<link href> de otro origen/);
  homeFails("un manejador en línea", (w) => edit(page(w), (t) => t.replace("<body>", '<body onload="x()">')), /manejador en línea/);
  homeFails("un mapa de código en dist/", (w) => writeFileSync(join(w.dist, "assets", "x.js.map"), "{}"), /mapa de código/);

  for (const [label, code] of [
    ["fetch(", 'fetch("/x")'],
    ["XMLHttpRequest", "new XMLHttpRequest()"],
    ["navigator.sendBeacon", 'navigator.sendBeacon("/x")'],
    ["WebSocket", 'new WebSocket("/x")'],
    ["EventSource", 'new EventSource("/x")'],
    ["import() dinámico", 'import("/x.js")'],
    ["eval", 'eval("1")'],
    ["sessionStorage", 'sessionStorage.setItem("k","v")'],
    ["indexedDB", 'indexedDB.open("x")'],
    ["document.cookie", 'document.cookie="k=v"'],
    ["cookieStore", 'cookieStore.set("k","v")'],
    ["caches.open", 'caches.open("x")'],
  ]) {
    homeFails(`el programa usa ${label}`, (w) => edit(programOf(w), (t) => `${t}\n;${code};`), new RegExp(`usa ${label.replace(/[.()]/g, "\\$&")} `));
  }
  homeFails("el programa nombra un dominio externo", (w) => edit(programOf(w), (t) => `${t}\n;const u="https://evil.example/p";`), /dominio externo \(«evil\.example»\)/);
  homeFails("el programa apunta a un mapa", (w) => edit(programOf(w), (t) => `${t}\n//# sourceMappingURL=x.js.map`), /mapa de código/);
  homeFails("el programa lleva analítica", (w) => edit(programOf(w), (t) => `${t}\n;const u="plausible";`), /anal[ií]tica/);

  // Cierre de la 025 (revisor de seguridad, T-18): todo lo que hay en assets/, no solo lo enlazado, y el HTML
  // con las mismas prohibiciones que las otras páginas.
  const extra = (w, name) => join(w.dist, "assets", name);
  homeFails("otro programa en assets/, sin enlazar, que usa la red", (w) => writeFileSync(extra(w, "chunk-x.js"), 'fetch("/x");'), /assets\/chunk-x\.js: usa fetch\(/);
  homeFails("otro programa en assets/ que nombra un dominio externo", (w) => writeFileSync(extra(w, "chunk-x.js"), 'const u="https://evil.example/p";'), /assets\/chunk-x\.js: nombra un dominio externo/);
  homeFails("una hoja de assets/ con @import", (w) => edit(cssOf(w), (t) => `@import "/otra.css";${t}`), /assets\/[^:]+\.css: @import/);
  homeFails("una hoja de assets/, sin enlazar, con @import", (w) => writeFileSync(extra(w, "x.css"), '@import url("https://cdn.example/x.css");'), /assets\/x\.css: @import/);
  for (const [label, url] of [
    ["de otro origen", "https://cdn.example/f.woff2"],
    ["de otro origen sin protocolo", "//cdn.example/f.woff2"],
    ["con data:", "data:font/woff2;base64,AAAA"],
  ]) {
    homeFails(`una hoja de assets/ con un url() ${label}`, (w) => edit(cssOf(w), (t) => `${t}\n.x{background:url("${url}")}`), /assets\/[^:]+\.css: url\([^)]*\): recurso de otro origen/);
  }
  homeFails("un <base>", (w) => edit(page(w), (t) => t.replace("</head>", '<base href="https://evil.example/"></head>')), /index\.html: tiene un <base>/);
  homeFails("un <base> sin href", (w) => edit(page(w), (t) => t.replace("</head>", '<base target="_blank"></head>')), /index\.html: tiene un <base>/);
  homeFails("un <meta http-equiv>", (w) => edit(page(w), (t) => t.replace("</head>", '<meta http-equiv="refresh" content="0;url=/x"></head>')), /index\.html: tiene un <meta http-equiv>/);
  for (const scheme of ["javascript", "data", "vbscript"]) {
    homeFails(`un enlace con ${scheme}:`, (w) => edit(page(w), (t) => t.replace('href="#fin"', `href="${scheme}:x"`)), new RegExp(`index\\.html: un href con ${scheme}:`));
  }
  homeFails("un enlace con javascript: en mayúsculas y con espacio", (w) => edit(page(w), (t) => t.replace('href="#fin"', 'href=" JavaScript:x"')), /index\.html: un href con /);

  test("las hojas construidas solo cargan las fuentes del propio origen", () => {
    const urls = [...read(cssOf(base)).matchAll(/url\(([^)]*)\)/g)].map((m) => m[1]);
    assert.ok(urls.length > 0);
    for (const u of urls) assert.match(u, /^\/fonts\/[A-Za-z-]+\.woff2$/);
  });
});

describe("CA-025-12 y CA-025-13: lo único que guarda la página de inicio es el idioma (lo que dice la política)", () => {
  const SRC = join(import.meta.dirname, "../home/src");
  const sources = () =>
    all(SRC)
      .filter((f) => f.endsWith(".js"))
      .map((f) => [f.split(sep).join("/"), read(join(SRC, f))]);

  test("en el código propio, solo locale.js usa localStorage, con la clave «una-lang»", () => {
    const users = sources().filter(([, code]) => /\blocalStorage\b/.test(code)).map(([f]) => f);
    assert.deepEqual(users, ["shared/locale.js"]);
    const code = read(join(SRC, "shared/locale.js"));
    assert.match(code, /^const KEY = 'una-lang';$/m);
    assert.deepEqual([...code.matchAll(/localStorage\.(\w+)\(([^)]*)\)/g)].map((m) => `${m[1]}(${m[2]})`), ["getItem(KEY)", "setItem(KEY, next)"]);
  });

  test("lo guardado solo puede ser «es» o «en»: se guarda al cambiar con ES / EN y se lee pasando por pickLang", async () => {
    const { pickLang } = await import("../home/src/shared/i18n.js");
    for (const v of ["es", "en", "ca-ES", "fr", "<script>", ""]) assert.ok(["es", "en"].includes(pickLang(v)), v);
    const chrome = read(join(SRC, "shared/chrome.js"));
    assert.match(chrome, /setLang\(b\.dataset\.lang\)/);
    const code = read(join(SRC, "shared/locale.js"));
    assert.match(code, /return pickLang\(fromUrl \|\| stored \|\| navigator\.language \|\| 'es'\);/);
  });

  test("setLang no guarda ni recarga con un valor que no sea «es» o «en»", async () => {
    const { setLang } = await import("../home/src/shared/locale.js");
    const calls = [];
    const had = Object.getOwnPropertyDescriptor(globalThis, "localStorage");
    Object.defineProperty(globalThis, "localStorage", { configurable: true, value: { setItem: (k, v) => calls.push(`set ${k}=${v}`) } });
    globalThis.location = { href: "https://una.example/?lang=en", replace: (u) => calls.push(`go ${u}`) };
    try {
      for (const bad of ["fr", "<script>", "", undefined, null, "ES", "en-US", { toString: () => "en" }]) setLang(bad);
      assert.deepEqual(calls, []);
      // El idioma por defecto de i18n.js es «es»: cambiar a «en» sí guarda y recarga sin `?lang`.
      setLang("en");
      assert.deepEqual(calls, ["set una-lang=en", "go https://una.example/"]);
    } finally {
      delete globalThis.location;
      if (had) Object.defineProperty(globalThis, "localStorage", had);
      else delete globalThis.localStorage;
    }
  });

  test("en el programa construido, «localStorage» aparece solo en la lectura y la escritura del idioma", () => {
    const code = readFileSync(programOf(base), "utf8");
    assert.equal(code.match(/\blocalStorage\b/g)?.length, 2);
    assert.equal(code.match(/una-lang/g)?.length, 1);
  });
});

describe("CA-025-12: dos reglas de cabeceras; la de «/» solo añade script-src y estilos en línea", () => {
  const mutate = (w, fn) => {
    const json = JSON.parse(read(w.paths.vercelJson));
    fn(json);
    writeFileSync(w.paths.vercelJson, JSON.stringify(json, null, 2));
  };
  const cspOf = (w, source, fn) =>
    mutate(w, (json) => {
      for (const h of json.headers.find((r) => r.source === source).headers) if (h.key === "Content-Security-Policy") h.value = fn(h.value);
    });
  const fails = (label, fn, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        fn(w);
        const errors = specificErrors(checkSite(w.paths));
        assert.ok(errors.some((e) => pattern.test(e)), `ningún error casa ${pattern}:\n${errors.join("\n")}`);
      } finally {
        w.cleanup();
      }
    });

  test("la CSP de «/»: script-src 'self' y style-src 'self' 'unsafe-inline'", () => {
    const rule = JSON.parse(read(base.paths.vercelJson)).headers.find((r) => r.source === "/");
    const csp = rule.headers.find((h) => h.key === "Content-Security-Policy").value;
    assert.match(csp, /(^|; )script-src 'self'(;|$)/);
    assert.match(csp, /(^|; )style-src 'self' 'unsafe-inline'(;|$)/);
  });

  fails("sin la regla de la página de inicio", (w) => mutate(w, (json) => json.headers.splice(1, 1)), /dos reglas/);
  fails("«/» sin script-src", (w) => cspOf(w, "/", (v) => v.replace("script-src 'self'; ", "")), /script-src.*regla «\/»/);
  fails("«/» con 'unsafe-inline' en los programas", (w) => cspOf(w, "/", (v) => v.replace("script-src 'self'", "script-src 'self' 'unsafe-inline'")), /script-src.*regla «\/»/);
  fails("«/» con connect-src", (w) => cspOf(w, "/", (v) => `${v}; connect-src 'self'`), /connect-src.*regla «\/»/);
  fails("el resto de páginas con estilos en línea", (w) => cspOf(w, "/(.+)", (v) => v.replace("style-src 'self'", "style-src 'self' 'unsafe-inline'")), /style-src tiene que ser 'self'/);
  fails("el resto de páginas con script-src", (w) => cspOf(w, "/(.+)", (v) => `${v}; script-src 'self'`), /script-src no se admite$/);
  fails("HSTS distinto solo en «/»", (w) => mutate(w, (json) => {
    for (const h of json.headers.find((r) => r.source === "/").headers) if (h.key === "Strict-Transport-Security") h.value = "max-age=63072001; includeSubDomains";
  }), /iguales salvo.*strict-transport-security/);

  test("un <script> en /help sigue fallando", () => {
    const w = cloneWorld(base);
    try {
      edit(join(w.dist, "help/index.html"), (t) => t.replace("</body>", '<script type="module" src="/assets/x.js"></script></body>'));
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /^help\/index\.html: tiene un <script>/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });
});
