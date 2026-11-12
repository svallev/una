// Sin terceros ni rastreo en la página de inicio (spec 025, CA-025-12; plan §6.1). Lo de T-025-01: el
// programa construido y las dos reglas de cabeceras. T-025-03 añade el juego de reglas de check.mjs.
import assert from "node:assert/strict";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { checkSite } from "../check.mjs";
import { cloneWorld, read, specificErrors, world } from "./support.mjs";

let base;
before(async () => {
  base = world();
  base.build();
  await base.buildHome();
});
after(() => base.cleanup());

const all = (dir) => readdirSync(dir, { recursive: true }).map(String);
const program = () => {
  const js = all(base.dist).filter((f) => f.endsWith(".js"));
  assert.equal(js.length, 1, `tiene que haber un solo programa: ${js.join(", ")}`);
  return { file: js[0], code: readFileSync(join(base.dist, js[0]), "utf8") };
};

describe("CA-025-12: el programa construido", () => {
  test("un solo programa y una sola hoja de estilo, en assets/", () => {
    assert.match(program().file, /^assets\/[^/]+\.js$/);
    const css = all(join(base.dist, "assets")).filter((f) => f.endsWith(".css"));
    assert.equal(css.length, 1);
  });

  test("sin mapas de código", () => {
    assert.deepEqual(all(base.dist).filter((f) => f.endsWith(".map")), []);
    for (const f of all(join(base.dist, "assets"))) {
      assert.ok(!read(join(base.dist, "assets", f)).includes("sourceMappingURL"), `${f} apunta a un mapa`);
    }
  });

  test("sin fetch( (el relleno de modulepreload de Vite está desactivado)", () => {
    assert.ok(!program().code.includes("fetch("));
  });

  test("sin eval ni new Function (la CSP no lleva 'unsafe-eval')", () => {
    const { code } = program();
    assert.ok(!/\beval\(/.test(code));
    assert.ok(!code.includes("new Function"));
  });

  test("el programa se carga solo del propio origen, por src, sin nada escrito dentro de la página ni estilos en línea", () => {
    const html = read(join(base.dist, "index.html"));
    const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)];
    assert.equal(scripts.length, 1);
    assert.match(scripts[0][1], /^ type="module" crossorigin src="\/assets\/[^"/]+\.js"$/);
    assert.equal(scripts[0][2], "");
    assert.ok(!/\sstyle=/i.test(html), "style= en la página");
    assert.ok(!/<style\b/i.test(html), "<style> en la página");
    assert.ok(!/\son[a-z]+\s*=/i.test(html), "manejador en línea");
  });

  test("ScrollTrigger no deja una infracción de CSP al registrarse: <body> recibe una propiedad por CSSOM antes que nada", () => {
    // ScrollTrigger 3.15.1 hace body.setAttribute("style", "") si <body> no tiene atributo style (plan §1.6).
    const { code } = program();
    const prepare = code.indexOf("document.body.style.setProperty(");
    assert.ok(prepare >= 0, "falta la propiedad de <body>");
    assert.ok(prepare < code.indexOf("GreenSock"), "la propiedad de <body> tiene que ir antes que GSAP");
  });
});

describe("CA-025-12: dos reglas de cabeceras, la de la página de inicio solo añade script-src 'self'", () => {
  const vercel = (w) => w.paths.vercelJson;
  const mutate = (w, fn) => {
    const json = JSON.parse(read(vercel(w)));
    fn(json);
    writeFileSync(vercel(w), JSON.stringify(json, null, 2));
  };
  const homeCsp = (w, fn) =>
    mutate(w, (json) => {
      const rule = json.headers.find((r) => r.source === "/");
      for (const h of rule.headers) if (h.key === "Content-Security-Policy") h.value = fn(h.value);
    });

  test("lo construido pasa", () => {
    assert.deepEqual(checkSite(base.paths), []);
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

  fails("sin la regla de la página de inicio", (w) => mutate(w, (json) => json.headers.splice(1, 1)), /dos reglas/);
  fails("una sola regla para todo, como en la 023", (w) => mutate(w, (json) => {
    json.headers = [{ ...json.headers[0], source: "/(.*)" }];
  }), /dos reglas/);
  fails("la página de inicio sin script-src", (w) => homeCsp(w, (v) => v.replace("script-src 'self'; ", "")), /script-src.*regla «\/»/);
  fails("la página de inicio con 'unsafe-inline'", (w) => homeCsp(w, (v) => v.replace("script-src 'self'", "script-src 'self' 'unsafe-inline'")), /script-src.*regla «\/»/);
  fails("la página de inicio con estilos en línea", (w) => homeCsp(w, (v) => v.replace("style-src 'self'", "style-src 'self' 'unsafe-inline'")), /style-src.*regla «\/»/);
  fails("la página de inicio con connect-src", (w) => homeCsp(w, (v) => `${v}; connect-src 'self'`), /connect-src.*regla «\/»/);
  fails("la página de inicio sin una cabecera de las de siempre", (w) => mutate(w, (json) => {
    const rule = json.headers.find((r) => r.source === "/");
    rule.headers = rule.headers.filter((h) => h.key !== "X-Frame-Options");
  }), /X-Frame-Options.*regla «\/»/);
  fails("el resto de páginas con script-src", (w) => mutate(w, (json) => {
    const rule = json.headers.find((r) => r.source === "/(.+)");
    for (const h of rule.headers) if (h.key === "Content-Security-Policy") h.value += "; script-src 'self'";
  }), /script-src no se admite$/);
});
