// Sin terceros ni rastreo en la página de inicio (spec 025, CA-025-12 y CA-025-14; plan §6.1): el programa
// construido, las dos reglas de cabeceras (iguales salvo script-src) y el segundo juego de reglas de check.mjs
// (`checkHome`), cada regla con un caso que falla. Las reglas de las otras cuatro páginas no cambian.
import assert from "node:assert/strict";
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
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

  // Iguales salvo script-src: un cambio que cada regla admite por sí sola, pero solo en una de las dos.
  const inRule = (source, fn) => (w) => mutate(w, (json) => fn(json.headers.find((r) => r.source === source)));
  fails("HSTS distinto en la regla de la página de inicio (válido por sí solo)", inRule("/", (rule) => {
    for (const h of rule.headers) if (h.key === "Strict-Transport-Security") h.value = "max-age=63072001; includeSubDomains";
  }), /iguales salvo script-src.*strict-transport-security/);
  fails("una cabecera de más solo en la regla de la página de inicio", inRule("/", (rule) => {
    rule.headers.push({ key: "X-DNS-Prefetch-Control", value: "off" });
  }), /iguales salvo script-src.*x-dns-prefetch-control/);
  fails("una cabecera de más solo en la regla del resto", inRule("/(.+)", (rule) => {
    rule.headers.push({ key: "X-DNS-Prefetch-Control", value: "off" });
  }), /iguales salvo script-src.*x-dns-prefetch-control/);
  fails("Permissions-Policy con una directiva de más solo en la del resto", inRule("/(.+)", (rule) => {
    for (const h of rule.headers) if (h.key === "Permissions-Policy") h.value += ", bluetooth=()";
  }), /iguales salvo script-src.*permissions-policy/);

  test("el orden de las directivas de la CSP no cuenta: iguales salvo script-src", () => {
    const w = cloneWorld(base);
    try {
      homeCsp(w, (v) => v.split("; ").reverse().join("; "));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });
});

describe("CA-025-12: Vercel instala sin scripts, como la CI (installCommand)", () => {
  const install = (value) => (w) => {
    const json = JSON.parse(read(w.paths.vercelJson));
    if (value === undefined) delete json.installCommand;
    else json.installCommand = value;
    writeFileSync(w.paths.vercelJson, JSON.stringify(json, null, 2));
  };
  const failsWith = (label, fn) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        fn(w);
        assert.ok(specificErrors(checkSite(w.paths)).some((e) => /installCommand/.test(e)));
      } finally {
        w.cleanup();
      }
    });
  test("es npm ci --ignore-scripts", () => {
    assert.equal(JSON.parse(read(base.paths.vercelJson)).installCommand, "npm ci --ignore-scripts");
  });
  failsWith("sin installCommand (Vercel haría npm install con scripts)", install(undefined));
  failsWith("npm install", install("npm install"));
  failsWith("npm ci con scripts", install("npm ci"));
});

// ─── El segundo juego de reglas: la página de inicio (checkHome) ────────────────────────────────

/** Aplica [mutate] a una copia y comprueba que `checkHome` falla con un error que casa [pattern]. */
const homeFails = (label, mutate, pattern) =>
  test(label, () => {
    const w = cloneWorld(base);
    try {
      mutate(w);
      const errors = checkHome(w.paths);
      assert.ok(errors.some((e) => pattern.test(e)), `ningún error casa ${pattern}:\n${errors.join("\n")}`);
    } finally {
      w.cleanup();
    }
  });

const home = (w) => join(w.dist, "index.html");
const asset = (w, ext) => join(w.dist, all(join(w.dist, "assets")).filter((f) => f.endsWith(ext)).map((f) => `assets/${f}`)[0]);
const homeSrc = (w, file) => join(w.paths.homeDir, file);

describe("CA-025-12: la página de inicio construida (checkHome)", () => {
  test("lo construido pasa", () => {
    assert.deepEqual(checkHome(base.paths), []);
  });

  homeFails("un segundo <script> del propio origen", (w) => edit(home(w), (t) => t.replace("</head>", '<script type="module" src="/assets/otro.js"></script></head>')), /2 <script>/);
  homeFails("un programa escrito dentro de la página", (w) => edit(home(w), (t) => t.replace("</body>", "<script>alert(1)</script></body>")), /escrito dentro de la página/);
  homeFails("el programa por src y además con código dentro", (w) => edit(home(w), (t) => t.replace(/(<script [^>]*>)<\/script>/, "$1console.log(1)</script>")), /escrito dentro de la página/);
  homeFails("un programa de otro origen", (w) => edit(home(w), (t) => t.replace(/src="\/assets\/[^"]+\.js"/, 'src="https://cdn.example/gsap.js"')), /de otro origen/);
  homeFails("un programa con // (mismo protocolo, otro anfitrión)", (w) => edit(home(w), (t) => t.replace(/src="\/assets\//, 'src="//cdn.example/assets/')), /de otro origen/);
  homeFails("un programa que no es el de assets/", (w) => edit(home(w), (t) => t.replace(/src="\/assets\/[^"]+\.js"/, 'src="/otro.js"')), /no carga el programa de assets/);
  homeFails("un programa clásico (sin type=\"module\")", (w) => edit(home(w), (t) => t.replace('<script type="module"', "<script")), /type="module"/);
  homeFails("un atributo style", (w) => edit(home(w), (t) => t.replace("<main ", '<main style="color:red" ')), /style en línea/);
  homeFails("un <style> en línea", (w) => edit(home(w), (t) => t.replace("</head>", "<style>p{}</style></head>")), /<style> en línea/);
  homeFails("un manejador onclick", (w) => edit(home(w), (t) => t.replace("<h1 ", '<h1 onclick="x()" ')), /manejador en línea onclick/);
  homeFails("un manejador onload en <body>", (w) => edit(home(w), (t) => t.replace("<body>", '<body onload="x()">')), /manejador en línea onload/);
  homeFails("una imagen data:", (w) => edit(home(w), (t) => t.replace("</main>", '<img src="data:image/png;base64,AAAA" alt=""></main>')), /img src> con una dirección data:/);
  homeFails("un enlace data:", (w) => edit(home(w), (t) => t.replace("</main>", '<a href="data:text/html,x">x</a></main>')), /a href> con una dirección data:/);
  homeFails("un enlace javascript:", (w) => edit(home(w), (t) => t.replace("</main>", '<a href="javascript:x()">x</a></main>')), /javascript:/);
  homeFails("una imagen de otro origen", (w) => edit(home(w), (t) => t.replace("</main>", '<img src="https://evil.example/p.png" alt=""></main>')), /de otro origen/);
  homeFails("un srcset de otro origen", (w) => edit(home(w), (t) => t.replace("</main>", '<img src="/a.png" srcset="/a.png 1x, https://evil.example/b.png 2x" alt=""></main>')), /srcset> de otro origen/);
  homeFails("una hoja de estilo de otro origen", (w) => edit(home(w), (t) => t.replace(/href="\/assets\/[^"]+\.css"/, 'href="https://cdn.example/s.css"')), /otro origen/);
  homeFails("una hoja de estilo que no es la de assets/", (w) => edit(home(w), (t) => t.replace(/href="\/assets\/[^"]+\.css"/, 'href="/site.css"')), /no carga la hoja de estilo de assets/);
  homeFails("un <link rel=\"modulepreload\">", (w) => edit(home(w), (t) => t.replace("</head>", '<link rel="modulepreload" href="/assets/x.js"></head>')), /modulepreload/);
  homeFails("un iframe", (w) => edit(home(w), (t) => t.replace("</main>", '<iframe src="/x"></iframe></main>')), /iframe/);
  homeFails("un formulario", (w) => edit(home(w), (t) => t.replace("</main>", '<form action="/x"></form></main>')), /form/);
  homeFails("un <base>", (w) => edit(home(w), (t) => t.replace("</head>", '<base href="/x/"></head>')), /<base>/);
  homeFails("una redirección meta", (w) => edit(home(w), (t) => t.replace("</head>", '<meta http-equiv="refresh" content="0;url=/x"></head>')), /http-equiv/);
  homeFails("la analítica de Vercel", (w) => edit(home(w), (t) => t.replace("</body>", "<p>/_vercel/insights/script.js</p></body>")), /anal[ií]tica/);
  homeFails("el viewport limita el zoom", (w) => edit(home(w), (t) => t.replace("initial-scale=1", "initial-scale=1, maximum-scale=1")), /zoom/);
  homeFails("un data: dentro de un atributo (url(data:…))", (w) => edit(home(w), (t) => t.replace("<main ", '<main data-bg="url(data:image/png;base64,AAAA)" ')), /main data-bg> con una dirección data:/);
  homeFails("un srcdoc", (w) => edit(home(w), (t) => t.replace("<main ", '<main srcdoc="<p>x</p>" ')), /srcdoc/);
  homeFails("un <script> sin src", (w) => edit(home(w), (t) => t.replace(/ src="\/assets\/[^"]+\.js"/, "")), /<script> sin src/);
  homeFails("sin viewport", (w) => edit(home(w), (t) => t.replace(/<meta name="viewport"[^>]*>/, "")), /falta <meta name="viewport">/);
  homeFails("sin título", (w) => edit(home(w), (t) => t.replace(/<title>[^<]*<\/title>/, "<title> </title>")), /falta el <title>/);
  homeFails("sin lang en <html>", (w) => edit(home(w), (t) => t.replace('<html lang="es">', "<html>")), /lang/);
});

describe("CA-025-12: dist/ por patrón y cuenta", () => {
  homeFails("falta la página de inicio", (w) => rmSync(home(w)), /falta la página de inicio/);
  homeFails("un segundo programa en assets/", (w) => writeFileSync(join(w.dist, "assets/otro-abc.js"), ""), /2 archivo\(s\) \.js/);
  homeFails("una segunda hoja de estilo en assets/", (w) => writeFileSync(join(w.dist, "assets/otra-abc.css"), ""), /2 archivo\(s\) \.css/);
  homeFails("ningún programa en assets/", (w) => rmSync(asset(w, ".js")), /0 archivo\(s\) \.js/);
  homeFails("un mapa de código", (w) => writeFileSync(`${asset(w, ".js")}.map`, "{}"), /mapa de código/);
  homeFails("una página HTML de más", (w) => writeFileSync(join(w.dist, "gen.html"), "<p>x</p>"), /HTML de más/);
  homeFails("una página HTML de más en una carpeta (la de Vite con la raíz mal puesta)", (w) => {
    mkdirSync(join(w.dist, "gen"));
    writeFileSync(join(w.dist, "gen/index.html"), "<p>x</p>");
  }, /gen\/index\.html: página HTML de más/);
  homeFails("un archivo que nadie espera", (w) => writeFileSync(join(w.dist, "assets/logo.png"), "x"), /no esperado/);
});

describe("CA-025-12: la hoja de estilo y el programa construidos", () => {
  homeFails("una imagen data: en la hoja de estilo", (w) => edit(asset(w, ".css"), (t) => `${t}\nbody{background:url(data:image/png;base64,AAAA)}`), /data:/);
  homeFails("un url() de otro origen en la hoja de estilo", (w) => edit(asset(w, ".css"), (t) => `${t}\nbody{background:url(https://evil.example/x.png)}`), /otro origen/);
  homeFails("un @import en la hoja de estilo", (w) => edit(asset(w, ".css"), (t) => `@import "/x.css";\n${t}`), /@import/);
  homeFails("la hoja de estilo lleva analítica", (w) => edit(asset(w, ".css"), (t) => `${t}\n.x::after{content:"plausible.io"}`), /assets\/[^:]+\.css: rastro de analítica/);
  homeFails("la hoja de estilo apunta a un mapa", (w) => edit(asset(w, ".css"), (t) => `${t}\n/*# sourceMappingURL=x.css.map */`), /mapa de código/);

  for (const [label, code] of [
    ["fetch(", 'fetch("/x")'],
    ["XMLHttpRequest", "new XMLHttpRequest()"],
    ["navigator.sendBeacon", 'navigator.sendBeacon("/x")'],
    ["WebSocket", 'new WebSocket("wss://x")'],
    ["WebTransport", 'new WebTransport("https://x")'],
    ["EventSource", 'new EventSource("/x")'],
    ["WebRTC", "new RTCPeerConnection()"],
    ["new Request", 'new Request("/x")'],
    ["importScripts", 'importScripts("/x.js")'],
    ["import() dinámico", 'import("/x.js")'],
    ["Worker", 'new Worker("/x.js")'],
    ["serviceWorker", 'navigator.serviceWorker.register("/sw.js")'],
    ["BroadcastChannel", 'new BroadcastChannel("x")'],
    ["postMessage", "parent.postMessage(1)"],
    ["window.open", 'window.open("/x")'],
    ["new Image", 'new Image().src="/p"'],
    ["sessionStorage", 'sessionStorage.setItem("a","b")'],
    ["indexedDB", 'indexedDB.open("x")'],
    ["cookies", 'document.cookie="a=b"'],
    ["Cache Storage", 'caches.open("x")'],
    ["navigator.storage", "navigator.storage.persist()"],
    ["history.pushState", 'history.pushState(null,"","/x")'],
    ["eval", 'eval("1")'],
    ["new Function", 'new Function("return 1")'],
    ["document.write", 'document.write("x")'],
  ]) {
    homeFails(`el programa usa ${label}`, (w) => edit(asset(w, ".js"), (t) => `${t}\n;${code};`), new RegExp(`usa ${label.replace(/[.()]/g, "\\$&")} `));
  }

  test("localStorage (el idioma) y history.replaceState (quitar el #) se admiten", () => {
    const w = cloneWorld(base);
    try {
      edit(asset(w, ".js"), (t) => `${t}\n;localStorage.setItem("lang","es");history.replaceState(null,"","/");`);
      assert.deepEqual(checkHome(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  homeFails("el programa lleva una imagen data:", (w) => edit(asset(w, ".js"), (t) => `${t}\n;const i="data:image/png;base64,AAAA";`), /dirección data:/);
  homeFails("el programa apunta a un mapa", (w) => edit(asset(w, ".js"), (t) => `${t}\n//# sourceMappingURL=x.js.map`), /mapa de código/);
  homeFails("el programa lleva analítica", (w) => edit(asset(w, ".js"), (t) => `${t}\n;const u="https://www.googletagmanager.com/gtag/js";`), /anal[ií]tica/);
});

describe("CA-025-14: el nombre de la app, a mano en landing/home/", () => {
  const strings = (w, lang = "es") => homeSrc(w, `src/strings.${lang}.json`);
  const setString = (w, key, fn, lang = "es") => {
    const json = JSON.parse(read(strings(w, lang)));
    json[key] = fn(json[key]);
    writeFileSync(strings(w, lang), `${JSON.stringify(json, null, 2)}\n`);
  };

  test("los titulares que juegan con el nombre se admiten (lista cerrada: heroTitle, oneTitle, endTitle y la segunda mitad de metaTitle)", () => {
    const es = JSON.parse(read(strings(base)));
    assert.match(es.heroTitle, /\bUna\b/, "el titular de la portada ya no empieza por «Una»: revisa la lista cerrada");
    assert.match(es.metaTitle, /^\{appName\} — Una /);
    assert.deepEqual(checkHome(base.paths), []);
  });

  homeFails("en el programa", (w) => edit(homeSrc(w, "src/main.js"), (t) => `${t}\nconst name = "Una";\n`), /home\/src\/main\.js:\d+: el nombre de la app «Una»/);
  homeFails("el logotipo en el programa", (w) => edit(homeSrc(w, "src/main.js"), (t) => `${t}\nconst logo = "una.";\n`), /home\/src\/main\.js:\d+: el nombre de la app «una\.»/);
  homeFails("en la plantilla", (w) => edit(homeSrc(w, "index.template.html"), (t) => t.replace("<title>{{title}}</title>", "<title>Una</title>")), /index\.template\.html:\d+/);
  homeFails("en una hoja de estilo", (w) => edit(homeSrc(w, "src/base.css"), (t) => `${t}\n.x::after { content: "Una"; }\n`), /base\.css:\d+/);
  homeFails("en la configuración de Vite", (w) => edit(homeSrc(w, "vite.config.mjs"), (t) => `${t}\n// Construye Una.\n`), /vite\.config\.mjs:\d+/);
  homeFails("en un texto que no es de la lista cerrada", (w) => setString(w, "navHint", () => "Baja por Una"), /strings\.es\.json \(«navHint»\)/);
  homeFails("el logotipo al final de una frase de un texto", (w) => setString(w, "manyLead", (v) => v.replace("a la vez.", "con una.")), /strings\.es\.json \(«manyLead»\): el nombre de la app «una\.»/);
  homeFails("en un texto anidado (descripción para el lector)", (w) => setString(w, "alt", (v) => ({ ...v, icon: "Icono de la app Una" })), /«alt\.icon»/);
  homeFails("en inglés", (w) => setString(w, "navHint", () => "Scroll through Una", "en"), /strings\.en\.json \(«navHint»\)/);
  homeFails("en la primera mitad de metaTitle (la del nombre)", (w) => setString(w, "metaTitle", (v) => v.replace("{appName}", "Una")), /«metaTitle»/);
  homeFails("un JSON de textos que no se puede leer", (w) => edit(strings(w), (t) => t.replace("{", "{,")), /strings\.es\.json: no es JSON válido/);
  homeFails("metaTitle sin el separador: se mira entero", (w) => setString(w, "metaTitle", () => "{appName} · Una tarea a la vez"), /«metaTitle»/);
});

describe("CA-025-12: las reglas de las otras cuatro páginas no cambian", () => {
  test("un <script> en /help sigue fallando (la página de inicio no abre la puerta a las demás)", () => {
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
