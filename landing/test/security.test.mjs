// Sin terceros ni rastreo (spec 023, CA-023-14): cada regla con un caso que falla.
import assert from "node:assert/strict";
import { rmSync, writeFileSync } from "node:fs";
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

const page = (w) => join(w.dist, "index.html");
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
  fails("la CSP admite scripts", (w) => csp(w, (v) => `${v}; script-src 'self'`), /script-src/);
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
