// Sin terceros ni rastreo (spec 023, CA-023-14; spec 026, CA-026-13 y 15: el programa de idioma y la CSP con
// programas del propio origen y Trusted Types): cada regla con un caso que falla.
import assert from "node:assert/strict";
import { mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { checkSite } from "../check.mjs";
import { cloneWorld, edit, read, specificErrors, world } from "./support.mjs";

let base;
before(() => {
  base = world();
  base.build();
});
after(() => base.cleanup());

/** Aplica [mutate] a una copia y comprueba que la comprobación falla con un error que casa [pattern]. */
function fails(label, mutate, pattern) {
  test(label, () => {
    const w = cloneWorld(base);
    try {
      mutate(w);
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.length >= 1, "la comprobación pasó con una web que no debería pasar");
      assert.ok(errors.some((e) => pattern.test(e)), `ningún error casa ${pattern}:\n${errors.join("\n")}`);
    } finally {
      w.cleanup();
    }
  });
}

// La página de inicio la construye Vite desde la spec 025 y tiene sus propias reglas: estos casos van sobre
// la de error, que sigue sin JavaScript.
const page = (w) => join(w.dist, "404.html");
const vercel = (w) => w.paths.vercelJson;
const headers = (w) => JSON.parse(read(vercel(w))).headers[0].headers;
const setHeaders = (w, fn) => {
  const json = JSON.parse(read(vercel(w)));
  json.headers[0].headers = fn(json.headers[0].headers);
  writeFileSync(vercel(w), JSON.stringify(json, null, 2));
};

describe("CA-023-14: sin recursos de otro origen, scripts ni estilos en línea", () => {
  test("lo construido pasa", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  test("un enlace de navegación a otro sitio es normal (la política enlaza a la de Vercel)", () => {
    const html = read(join(base.dist, "privacy/index.html"));
    assert.ok(html.includes('<a href="https://vercel.com/legal/privacy-policy" rel="noopener noreferrer">'));
    assert.deepEqual(checkSite(base.paths), []);
  });

  fails("un <script> con src", (w) => edit(page(w), (t) => t.replace("</body>", '<script src="/x.js"></script></body>')), /script/i);
  fails("un <script> en línea", (w) => edit(page(w), (t) => t.replace("</body>", "<script>1</script></body>")), /script/i);
  fails("un manejador onclick", (w) => edit(page(w), (t) => t.replace("<h1>", '<h1 onclick="x()">')), /manejador|on…|onclick/i);
  fails("una imagen de otro origen", (w) => edit(page(w), (t) => t.replace("</main>", '<img src="https://evil.example/p.png" alt=""></main>')), /otro origen|img/i);
  fails("una imagen del propio sitio tampoco (la web no lleva imágenes)", (w) => edit(page(w), (t) => t.replace("</main>", '<img src="/p.png" alt=""></main>')), /img/i);
  fails("una hoja de estilo de otro origen", (w) => edit(page(w), (t) => t.replace('<link rel="stylesheet" href="/site.css">', '<link rel="stylesheet" href="https://cdn.example/s.css">')), /otro origen|link/i);
  fails("una hoja de estilo con // (mismo protocolo)", (w) => edit(page(w), (t) => t.replace('href="/site.css"', 'href="//cdn.example/site.css"')), /otro origen|link/i);
  fails("un iframe", (w) => edit(page(w), (t) => t.replace("</main>", '<iframe src="/x"></iframe></main>')), /iframe/i);
  fails("un <style> en línea", (w) => edit(page(w), (t) => t.replace("</head>", "<style>p{}</style></head>")), /style/i);
  fails("un atributo style", (w) => edit(page(w), (t) => t.replace("<h1>", '<h1 style="color:red">')), /style/i);
  fails("un formulario", (w) => edit(page(w), (t) => t.replace("</main>", '<form action="/x"></form></main>')), /form/i);
  fails("un <base>", (w) => edit(page(w), (t) => t.replace("</head>", '<base href="https://evil.example/"></head>')), /base/i);
  fails("una redirección meta", (w) => edit(page(w), (t) => t.replace("</head>", '<meta http-equiv="refresh" content="0;url=https://evil.example"></head>')), /meta/i);
  fails("un @import remoto en site.css", (w) => edit(join(w.dist, "site.css"), (t) => `@import url("https://fonts.example/x.css");\n${t}`), /@import|otro origen/i);
  fails("un url() remoto en site.css", (w) => edit(join(w.dist, "site.css"), (t) => `${t}\nbody { background-image: url(https://evil.example/x.png); }\n`), /url\(|otro origen/i);
  fails("una fuente de otro origen en tokens.css", (w) => edit(join(w.dist, "tokens.css"), (t) => t.replace('url("/fonts/archivo/Archivo-Variable.ttf")', 'url("https://fonts.gstatic.com/a.ttf")')), /otro origen|url\(/i);
  fails("la analítica de Vercel", (w) => edit(page(w), (t) => t.replace("</body>", '<img src="/_vercel/insights/pixel" alt=""></body>')), /anal[ií]tica|_vercel|img/i);
  fails("un recurso de analítica conocido en un enlace", (w) => edit(page(w), (t) => t.replace("</main>", '<a href="/x">https://www.googletagmanager.com/gtag/js</a></main>')), /anal[ií]tica|googletagmanager/i);
});

describe("CA-023-14: las fuentes van dentro de la web con su licencia", () => {
  fails("falta la licencia de Archivo", (w) => rmSync(join(w.dist, "fonts/archivo/OFL.txt")), /OFL/);
  fails("falta la licencia de Space Mono", (w) => rmSync(join(w.dist, "fonts/space_mono/OFL.txt")), /OFL/);
  fails("falta un archivo de fuente", (w) => rmSync(join(w.dist, "fonts/space_mono/SpaceMono-Bold.ttf")), /SpaceMono-Bold/);
  fails("falta una página", (w) => rmSync(join(w.dist, "404.html")), /404\.html/);
  fails("falta tokens.css", (w) => rmSync(join(w.dist, "tokens.css")), /tokens\.css/);
});

describe("CA-023-14: las cabeceras de vercel.json", () => {
  test("están todas y se pueden leer", () => {
    const names = headers(base).map((h) => h.key);
    for (const k of [
      "Content-Security-Policy",
      "Referrer-Policy",
      "Strict-Transport-Security",
      "X-Content-Type-Options",
      "X-Frame-Options",
      "Permissions-Policy",
      "Cross-Origin-Opener-Policy",
    ]) {
      assert.ok(names.includes(k), `falta ${k}`);
    }
    const cfg = JSON.parse(read(vercel(base)));
    assert.equal(cfg.framework, null);
    assert.equal(cfg.buildCommand, "node build.mjs");
    assert.equal(cfg.outputDirectory, "dist");
    assert.equal(cfg.cleanUrls, true);
    assert.equal(cfg.trailingSlash, false);
  });

  for (const key of [
    "Content-Security-Policy",
    "Referrer-Policy",
    "Strict-Transport-Security",
    "X-Content-Type-Options",
    "X-Frame-Options",
    "Permissions-Policy",
    "Cross-Origin-Opener-Policy",
  ]) {
    fails(`falta ${key}`, (w) => setHeaders(w, (h) => h.filter((x) => x.key !== key)), new RegExp(key));
  }

  const csp = (w, fn) =>
    setHeaders(w, (h) => h.map((x) => (x.key === "Content-Security-Policy" ? { ...x, value: fn(x.value) } : x)));

  fails("la CSP admite el propio origen por defecto", (w) => csp(w, (v) => v.replace("default-src 'none'", "default-src 'self'")), /default-src/);
  fails("la CSP admite estilos en línea", (w) => csp(w, (v) => v.replace("style-src 'self'", "style-src 'self' 'unsafe-inline'")), /style-src|unsafe-inline/);
  fails("la CSP admite programas en línea", (w) => csp(w, (v) => v.replace("script-src 'self'", "script-src 'self' 'unsafe-inline'")), /script-src/);
  fails("la CSP admite otro origen de fuentes", (w) => csp(w, (v) => v.replace("font-src 'self'", "font-src 'self' https://fonts.gstatic.com")), /font-src/);
  fails("la CSP permite incrustar la web", (w) => csp(w, (v) => v.replace("frame-ancestors 'none'", "frame-ancestors 'self'")), /frame-ancestors/);
  fails("la CSP no cierra object-src", (w) => csp(w, (v) => v.replace("object-src 'none'; ", "")), /object-src/);
  fails("la CSP no cierra base-uri", (w) => csp(w, (v) => v.replace("base-uri 'none'; ", "")), /base-uri/);
  fails("la CSP no cierra form-action", (w) => csp(w, (v) => v.replace("; form-action 'none'", "")), /form-action/);

  const set = (key, value) => (w) =>
    setHeaders(w, (h) => h.map((x) => (x.key === key ? { ...x, value } : x)));
  fails("Referrer-Policy envía el referente", set("Referrer-Policy", "origin"), /Referrer-Policy/);
  fails("HSTS más corto", set("Strict-Transport-Security", "max-age=60"), /Strict-Transport-Security/);
  fails("HSTS sin subdominios", set("Strict-Transport-Security", "max-age=63072000"), /Strict-Transport-Security/);
  fails("X-Content-Type-Options distinto", set("X-Content-Type-Options", "sniff"), /X-Content-Type-Options/);
  fails("X-Frame-Options permite marcos", set("X-Frame-Options", "SAMEORIGIN"), /X-Frame-Options/);
  fails("COOP relajada", set("Cross-Origin-Opener-Policy", "unsafe-none"), /Cross-Origin-Opener-Policy/);

  for (const d of ["camera", "microphone", "geolocation", "payment", "usb", "interest-cohort"]) {
    fails(
      `Permissions-Policy sin ${d}`,
      (w) =>
        setHeaders(w, (h) =>
          h.map((x) =>
            x.key === "Permissions-Policy"
              ? { ...x, value: x.value.split(", ").filter((p) => !p.startsWith(`${d}=`)).join(", ") }
              : x,
          ),
        ),
      new RegExp(`Permissions-Policy.*${d}`),
    );
  }
  fails(
    "Permissions-Policy que permite la cámara",
    (w) =>
      setHeaders(w, (h) =>
        h.map((x) => (x.key === "Permissions-Policy" ? { ...x, value: x.value.replace("camera=()", "camera=*") } : x)),
      ),
    /Permissions-Policy.*camera/,
  );

  fails("noindex (la política tiene que poder encontrarse)", (w) => setHeaders(w, (h) => [...h, { key: "X-Robots-Tag", value: "noindex" }]), /noindex|X-Robots-Tag/);
  fails("una cookie", (w) => setHeaders(w, (h) => [...h, { key: "Set-Cookie", value: "a=b" }]), /Set-Cookie|cookie/i);
  fails("con barra final", (w) => edit(vercel(w), (t) => t.replace('"trailingSlash": false', '"trailingSlash": true')), /trailingSlash/);
  fails("con un framework", (w) => edit(vercel(w), (t) => t.replace('"framework": null', '"framework": "nextjs"')), /framework/);
  fails("otro comando de construcción", (w) => edit(vercel(w), (t) => t.replace('"node build.mjs"', '"npm run build"')), /buildCommand/);
  fails("otra carpeta de salida", (w) => edit(vercel(w), (t) => t.replace('"dist"', '"public"')), /outputDirectory/);
  fails("un vercel.json que no es JSON", (w) => writeFileSync(vercel(w), "{"), /vercel\.json.*no se puede leer/);
  fails("sin vercel.json", (w) => rmSync(vercel(w)), /vercel\.json: falta/);
  fails("sin cleanUrls", (w) => edit(vercel(w), (t) => t.replace('"cleanUrls": true', '"cleanUrls": false')), /cleanUrls/);
  fails("una cabecera en una ruta concreta que sobrescribe (otra regla)", (w) => {
    const json = JSON.parse(read(vercel(w)));
    json.headers.push({ source: "/privacy", headers: [{ key: "Content-Security-Policy", value: "default-src *" }] });
    writeFileSync(vercel(w), JSON.stringify(json, null, 2));
  }, /source|reglas/i);
  fails("redirecciones o reescrituras (la web no las necesita)", (w) => {
    const json = JSON.parse(read(vercel(w)));
    json.rewrites = [{ source: "/(.*)", destination: "https://evil.example/$1" }];
    writeFileSync(vercel(w), JSON.stringify(json, null, 2));
  }, /rewrites|redirects/i);
});

// ─── Spec 026: el programa de idioma (CA-026-13 y 15, plan §6.1) ───────────────────────────────────────────────────

const program = (w) => join(w.dist, "lang.js");
const SCRIPT = '<script src="/lang.js"></script>';

describe("CA-026-13: un único <script src=\"/lang.js\"> por página, clásico, en el <head> tras las hojas", () => {
  fails("el programa escrito dentro de la página", (w) => edit(page(w), (t) => t.replace(SCRIPT, "<script>1</script>")), /<script>.*(dentro|sin src)/);
  fails("código dentro del <script src=\"/lang.js\">", (w) => edit(page(w), (t) => t.replace(SCRIPT, '<script src="/lang.js">alert(1)</script>')), /<script> con código escrito dentro/);
  fails("un segundo programa del propio origen", (w) => edit(page(w), (t) => t.replace("</body>", '<script src="/lang.js"></script></body>')), /tiene 2 <script>/);
  fails("un programa de otro origen", (w) => edit(page(w), (t) => t.replace(SCRIPT, '<script src="https://cdn.example/lang.js"></script>')), /<script>.*\/lang\.js/);
  fails("un src relativo (la página de error se sirve en cualquier ruta)", (w) => edit(page(w), (t) => t.replace(SCRIPT, '<script src="lang.js"></script>')), /<script>.*\/lang\.js/);
  fails("otro programa del propio origen", (w) => edit(page(w), (t) => t.replace(SCRIPT, '<script src="/assets/x.js"></script>')), /<script>.*\/lang\.js/);
  for (const attr of ["async", "defer", 'type="module"', 'type="text/javascript"', "nomodule", 'integrity="sha256-x"']) {
    fails(`un <script> con ${attr}`, (w) => edit(page(w), (t) => t.replace(SCRIPT, `<script ${attr} src="/lang.js"></script>`)), /<script>.*(atributo|clásico)/);
  }
  fails("el <script> en el <body>", (w) => edit(page(w), (t) => t.replace(`${SCRIPT}\n`, "").replace("</body>", `${SCRIPT}\n</body>`)), /<script>.*<head>/);
  fails("el <script> antes de las hojas de estilo", (w) => edit(page(w), (t) => t.replace(`${SCRIPT}\n`, "").replace('<link rel="stylesheet" href="/tokens.css">', `${SCRIPT}\n<link rel="stylesheet" href="/tokens.css">`)), /<script>.*hojas de estilo/);
  fails("sin el programa", (w) => edit(page(w), (t) => t.replace(`${SCRIPT}\n`, "")), /tiene 0 <script>/);
  fails("una hoja de estilo de más del propio origen (recursos de cada página)", (w) => edit(page(w), (t) => t.replace(SCRIPT, `<link rel="stylesheet" href="/x.css">\n${SCRIPT}`)), /recursos/);
  fails("un estilo en línea sigue prohibido", (w) => edit(page(w), (t) => t.replace("<main>", '<main style="color:red">')), /style en línea/);
});

describe("CA-026-13: lo que el programa de idioma no puede usar", () => {
  test("lo construido pasa (el programa de verdad, sin dominios ni API prohibidas)", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  for (const [label, code] of [
    ["innerHTML", 'html.innerHTML = "";'],
    ["outerHTML", 'html.outerHTML = "";'],
    ["insertAdjacentHTML", 'html.insertAdjacentHTML("beforeend", "");'],
    ["document.write", 'document.write("");'],
    ["fetch", 'fetch("/x");'],
    ["XMLHttpRequest", "new XMLHttpRequest();"],
    ["sendBeacon", 'navigator.sendBeacon("/x");'],
    ["location.assign", 'location.assign("/x");'],
    ["location.replace", 'location.replace("/x");'],
    ["location.href =", 'location.href = "/x";'],
    ["location =", 'location = "/x";'],
    ["window.open", 'window.open("/x");'],
    ["postMessage", 'parent.postMessage("x", "*");'],
    ["setTimeout", "setTimeout(apply, 0);"],
    ["setInterval", "setInterval(apply, 10);"],
    ["textContent", 'html.textContent = "";'],
    ["innerText", 'html.innerText = "";'],
    ["createElement", 'document.createElement("p");'],
    [".style", 'html.style.color = "red";'],
    ["setAttribute de style", 'html.setAttribute("style", "color: red");'],
    ["setAttribute de otro atributo", 'html.setAttribute("href", "/x");'],
    ["removeAttribute de otro atributo", 'html.removeAttribute("hidden");'],
    ["setAttribute con un nombre que no es un texto", "html.setAttribute(name, 1);"],
    ["setAttributeNS", 'html.setAttributeNS(null, "role", "x");'],
    ["toggleAttribute", 'html.toggleAttribute("hidden");'],
    ['addEventListener("storage"', 'addEventListener("storage", apply);'],
    ["onstorage", "onstorage = apply;"],
    ["otra clave de localStorage", 'localStorage.setItem("otra", "x");'],
    ["localStorage.removeItem", 'localStorage.removeItem("una-lang");'],
    ["localStorage con corchetes", 'localStorage["una-lang"] = "es";'],
    ["sessionStorage", 'sessionStorage.setItem("una-lang", "es");'],
    ["document.cookie", 'document.cookie = "a=b";'],
    ["import estático", 'import x from "./x.js";'],
    ["import() dinámico", 'import("./x.js");'],
    ["require", 'require("x");'],
    ["eval", 'eval("1");'],
    ["new Function", 'new Function("return 1");'],
    ["un dominio", 'var u = "https://evil.example/x";'],
    ["un dominio sin protocolo", 'var u = "//evil.example/x";'],
    ["un dominio de los que admite la página de inicio", 'var u = "https://www.w3.org/2000/svg";'],
  ]) {
    fails(`usa ${label}`, (w) => edit(program(w), (t) => `${t}\n${code}\n`), /lang\.js: /);
  }

  test("las dos únicas apariciones de localStorage son la lectura y la escritura de «una-lang»", () => {
    const code = read(program(base));
    assert.equal(code.match(/\blocalStorage\b/g)?.length, 2);
    assert.equal(code.match(/"una-lang"/g)?.length, 2);
  });

  fails("CA-026-15: 10 241 bytes", (w) => {
    const code = read(program(w));
    writeFileSync(program(w), `${code}//${"x".repeat(10_241 - Buffer.byteLength(code) - 2)}`);
  }, /lang\.js: pesa 10241 bytes/);

  test("CA-026-15: 10 240 bytes justos pasan", () => {
    const w = cloneWorld(base);
    try {
      const code = read(program(w));
      writeFileSync(program(w), `${code}//${"x".repeat(10_240 - Buffer.byteLength(code) - 2)}`);
      assert.deepEqual(specificErrors(checkSite(w.paths)).filter((e) => /pesa/.test(e)), []);
    } finally {
      w.cleanup();
    }
  });

  fails("sin lang.js en dist/", (w) => rmSync(program(w)), /lang\.js: falta/);
});

describe("CA-026-13: ningún HTML ni programa de más en dist/", () => {
  fails("un .html de más en la raíz", (w) => writeFileSync(join(w.dist, "extra.html"), "<p>x</p>"), /extra\.html: .*de más/);
  fails("un .html de más en una carpeta", (w) => writeFileSync(join(w.dist, "privacy/old.html"), "<p>x</p>"), /privacy\/old\.html: .*de más/);
  fails("un .js de más en la raíz", (w) => writeFileSync(join(w.dist, "x.js"), ""), /x\.js: .*de más/);
  fails("un .js de más en una carpeta que no es assets/", (w) => writeFileSync(join(w.dist, "fonts/x.js"), ""), /fonts\/x\.js: .*de más/);
  fails("un .js en una subcarpeta de assets/", (w) => {
    mkdirSync(join(w.dist, "assets/sub"), { recursive: true });
    writeFileSync(join(w.dist, "assets/sub/x.js"), "");
  }, /assets\/sub\/x\.js: .*de más/);
  fails("un .HTML en mayúsculas", (w) => writeFileSync(join(w.dist, "X.HTML"), "<p>x</p>"), /X\.HTML: .*de más/);
  fails("un .mjs", (w) => writeFileSync(join(w.dist, "x.mjs"), ""), /x\.mjs: .*de más/);
});

describe("CA-026-13: la CSP de las cuatro páginas: script-src 'self' y Trusted Types", () => {
  const csp = (w, fn) =>
    setHeaders(w, (h) => h.map((x) => (x.key === "Content-Security-Policy" ? { ...x, value: fn(x.value) } : x)));

  test("la regla «/(.+)» lleva script-src 'self' y Trusted Types", () => {
    const value = headers(base).find((h) => h.key === "Content-Security-Policy").value;
    assert.match(value, /(^|; )script-src 'self'(;|$)/);
    assert.match(value, /(^|; )require-trusted-types-for 'script'(;|$)/);
    assert.match(value, /(^|; )trusted-types 'none'(;|$)/);
    assert.match(value, /(^|; )style-src 'self'(;|$)/);
  });

  fails("sin script-src", (w) => csp(w, (v) => v.replace("script-src 'self'; ", "")), /falta script-src/);
  for (const extra of ["'unsafe-inline'", "'unsafe-eval'", "https://cdn.example", "data:", "'strict-dynamic'"]) {
    fails(`script-src con ${extra}`, (w) => csp(w, (v) => v.replace("script-src 'self'", `script-src 'self' ${extra}`)), /script-src tiene que ser 'self'/);
  }
  fails("sin require-trusted-types-for", (w) => csp(w, (v) => v.replace("; require-trusted-types-for 'script'", "")), /falta require-trusted-types-for/);
  fails("sin trusted-types", (w) => csp(w, (v) => v.replace("; trusted-types 'none'", "")), /falta trusted-types/);
  fails("trusted-types con una política", (w) => csp(w, (v) => v.replace("trusted-types 'none'", "trusted-types default")), /trusted-types tiene que ser 'none'/);
});

// ─── Spec 027 (T-027-04): los grupos de avisos no traen programa, estilos, archivos ni cabeceras nuevos ─────

describe("CA-027-04: sin programa nuevo y con las mismas guardias", () => {
  const FIXTURES = join(import.meta.dirname, "fixtures", "027");
  const licenses = (w) => join(w.dist, "licenses/index.html");
  const GROUP_OPEN = '<details class="group"><summary>';

  test("CA-027-04: vercel.json (CSP incluida) es el de main antes de la 027", () => {
    assert.deepEqual(JSON.parse(read(vercel(base))), JSON.parse(read(join(FIXTURES, "vercel-main.json"))));
    const value = headers(base).find((h) => h.key === "Content-Security-Policy").value;
    assert.equal(
      value,
      "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; require-trusted-types-for 'script'; trusted-types 'none'",
    );
  });

  test("CA-027-04: los archivos de dist/ (sin la página de inicio) son los de main antes de la 027", () => {
    const files = [];
    const walk = (dir, prefix = "") => {
      for (const e of readdirSync(dir, { withFileTypes: true })) {
        const rel = `${prefix}${e.name}`;
        if (e.isDirectory()) walk(join(dir, e.name), `${rel}/`);
        else files.push(rel);
      }
    };
    walk(base.dist);
    assert.deepEqual(files.sort(), read(join(FIXTURES, "dist-files.txt")).trim().split("\n"));
  });

  test("CA-027-04: la página de licencias carga solo el programa de idioma y no lleva estilos en línea", () => {
    const html = read(licenses(base));
    assert.deepEqual([...html.matchAll(/<script\b[^>]*>/g)].map((m) => m[0]), ['<script src="/lang.js">']);
    assert.ok(!/\sstyle\s*=/.test(html));
    assert.ok(html.includes(GROUP_OPEN));
  });

  fails("CA-027-04: un <script> en la cabecera de un grupo", (w) => edit(licenses(w), (t) => t.replace(GROUP_OPEN, `${GROUP_OPEN}<script>1</script>`)), /script/);
  fails("CA-027-04: un programa por src en un grupo", (w) => edit(licenses(w), (t) => t.replace(GROUP_OPEN, `${GROUP_OPEN}<script src="/x.js"></script>`)), /script/);
  fails("CA-027-04: un style= en un grupo", (w) => edit(licenses(w), (t) => t.replace(GROUP_OPEN, '<details class="group" style="display:block"><summary>')), /style/);
  fails("CA-027-04: un style= en la cabecera de un grupo", (w) => edit(licenses(w), (t) => t.replace(GROUP_OPEN, '<details class="group"><summary style="list-style:none">')), /style/);
  fails("CA-027-04: un manejador ontoggle en un grupo", (w) => edit(licenses(w), (t) => t.replace(GROUP_OPEN, '<details class="group" ontoggle="x()"><summary>')), /ontoggle/);
  fails("CA-027-04: un archivo de más en dist/", (w) => writeFileSync(join(w.dist, "groups.js"), ""), /groups\.js: .*de más/);
});
