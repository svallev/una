// El contenido sin JavaScript de la página de inicio (spec 025, CA-025-11 y CL-025-12; plan §2.2): está en el
// HTML construido sin ejecutar nada (textos de las dos lenguas, español primero, y los tres enlaces), se ve
// sin programa por CSS (al momento con `scripting: none`, a los 2 s si el programa no llega, sin que
// «reducir movimiento» lo anule), y el arranque lo quita al montar o lo enseña si el montaje falla.
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { BuildError, endLeadKey, loadHomeStrings, plainTitle, readIdentity, renderHomeHtml, staticHtml, storeUrls } from "../build.mjs";
import { STATIC_ID, boot } from "../home/src/boot.js";
import { cloneWorld, edit, read, world } from "./support.mjs";

let base;
let html;
let strings;
let identity;
before(async () => {
  base = world();
  base.build();
  await base.buildHome();
  html = read(join(base.dist, "index.html"));
  strings = loadHomeStrings(base.paths);
  identity = readIdentity(read(base.paths.identity));
});
after(() => base.cleanup());

/** El bloque `#static` del HTML construido. */
const staticBlock = (page) => {
  const m = /<div class="static" id="static">([\s\S]*?)\n<\/div>\n<\/main>/.exec(page);
  assert.ok(m, "no encuentro el bloque #static dentro de <main>");
  return m[1];
};
/** Las dos mitades del bloque, por idioma, en el orden en que aparecen. */
const halves = (block) => [...block.matchAll(/<section lang="(es|en)"[^>]*>([\s\S]*?)<\/section>/g)].map((m) => ({ lang: m[1], body: m[2] }));
/** Lo que se lee de un fragmento de HTML: sin etiquetas y con las entidades de `esc` deshechas. */
const textOf = (fragment) =>
  fragment
    .replace(/<[^>]*>/g, " ")
    .replaceAll("&#39;", "'")
    .replaceAll("&quot;", '"')
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&")
    .replace(/\s+/g, " ");
const withName = (s) => s.replaceAll("{appName}", identity.displayName);

describe("CA-025-11: el HTML construido, sin ejecutar nada", () => {
  test("hay un bloque #static dentro de <main>, y no es un <noscript>", () => {
    staticBlock(html);
    assert.ok(!/<noscript/i.test(html), "el contenido sin JavaScript no puede ser un <noscript> (no se vería con el programa roto)");
  });

  test("dos mitades, español primero, cada una marcada con su idioma", () => {
    assert.deepEqual(halves(staticBlock(html)).map((h) => h.lang), ["es", "en"]);
  });

  test("cada mitad dice qué hace, las cuatro propuestas y dónde estará disponible, con los textos del §7", () => {
    for (const { lang, body } of halves(staticBlock(html))) {
      const text = textOf(body);
      const s = strings[lang];
      const expected = [
        plainTitle(s.heroTitle),
        s.heroLead,
        ...["one", "handy", "awake", "light"].flatMap((id) => [plainTitle(s[`${id}Title`]), s[`${id}Lead`]]),
        s.endLead,
      ].map(withName);
      let at = 0;
      for (const piece of expected) {
        const found = text.indexOf(piece, at);
        assert.ok(found >= 0, `${lang}: falta o va fuera de orden «${piece}»`);
        at = found + piece.length;
      }
    }
  });

  test("el nombre de la app (de la identidad) es el único <h1>", () => {
    const h1 = [...html.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/g)];
    assert.equal(h1.length, 1, "tiene que haber un solo <h1>");
    assert.equal(textOf(h1[0][1]).trim(), identity.displayName);
    assert.match(h1[0][0], /tabindex="-1"/, "el <h1> tiene que poder recibir el foco (si el montaje falla)");
  });

  test("los enlaces a Ayuda, Privacidad y Licencias, en cada mitad, con su texto en ese idioma", () => {
    for (const { lang, body } of halves(staticBlock(html))) {
      const links = [...body.matchAll(/<a href="([^"]*)">([^<]*)<\/a>/g)].map((m) => [m[1], textOf(m[2]).trim()]);
      assert.deepEqual(links, [
        ["/help", strings[lang].footerHelp],
        ["/privacy", strings[lang].footerPrivacy],
        ["/licenses", strings[lang].footerLicenses],
      ]);
    }
  });

  test("la cabeza va en español hasta que el programa fija el idioma, con el nombre de la identidad", () => {
    assert.match(html, /<html lang="es">/);
    assert.ok(html.includes(`<title>${withName(strings.es.metaTitle)}</title>`), "título");
    assert.ok(html.includes(`<meta name="description" content="${withName(strings.es.metaDescription)}">`), "descripción");
    assert.match(html, /<meta name="theme-color" content="#[0-9A-Fa-f]{6}">/);
  });

  test("con otro nombre y un texto hostil, todo sale escapado", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro <b>"'));
      edit(join(w.paths.homeDir, "src/strings.en.json"), (t) => t.replace(/"heroLead": "[^"]*"/, '"heroLead": "<script>x</script> & \\"q\\""'));
      const s = loadHomeStrings(w.paths);
      const out = staticHtml({ appName: "Zorro <b>", strings: s, stores: { appStoreUrl: null, googlePlayUrl: null } });
      assert.ok(out.includes("<h1 tabindex=\"-1\">Zorro &lt;b&gt;</h1>"), out);
      assert.ok(out.includes("&lt;script&gt;x&lt;/script&gt; &amp; &quot;q&quot;"), "el texto no se escapa");
      assert.ok(!out.includes("<script>"));
    } finally {
      w.cleanup();
    }
  });

  test("la entradilla del cierre sigue a las tiendas (CA-025-08, CL-025-8)", () => {
    assert.equal(endLeadKey({ appStoreUrl: null, googlePlayUrl: null }), "endLead");
    assert.equal(endLeadKey({ appStoreUrl: null, googlePlayUrl: "https://play.google.com/x" }), "endLeadPlayOnly");
    assert.equal(endLeadKey({ appStoreUrl: "https://apps.apple.com/x", googlePlayUrl: null }), "endLeadAppStoreOnly");
    assert.equal(endLeadKey({ appStoreUrl: "https://apps.apple.com/x", googlePlayUrl: "https://play.google.com/x" }), "endLeadBoth");
    const s = loadHomeStrings(base.paths);
    const stores = { appStoreUrl: null, googlePlayUrl: "https://play.google.com/store/apps/details?id=x" };
    const out = textOf(staticHtml({ appName: "A", strings: s, stores }));
    assert.ok(out.includes(s.es.endLeadPlayOnly) && out.includes(s.en.endLeadPlayOnly), out);
    assert.ok(!out.includes(s.es.endLead + " "));
    // Con la identidad real (sin fichas hasta F6), la de «muy pronto».
    assert.equal(endLeadKey(storeUrls(identity)), "endLead");
  });

  test("un texto que falta hace fallar la construcción", () => {
    const s = structuredClone(strings);
    delete s.en.lightLead;
    assert.throws(() => staticHtml({ appName: "A", strings: s, stores: {} }), (e) => e instanceof BuildError && /lightLead/.test(e.message));
  });

  test("la plantilla: marcadores desconocidos o sin cerrar fallan; {{static}} va sin escapar", () => {
    const opts = { identity: { displayName: "A & B" }, strings, themeColor: "#000000", staticHtml: "<div id=\"static\"></div>" };
    assert.throws(() => renderHomeHtml("<p>{{otro}}</p>", opts), BuildError);
    assert.throws(() => renderHomeHtml("<p>{{title}</p>", opts), BuildError);
    assert.equal(renderHomeHtml("{{static}}", opts), "<div id=\"static\"></div>");
    assert.equal(renderHomeHtml("<title>{{title}}</title>", opts), `<title>${strings.es.metaTitle.replace("{appName}", "A &amp; B")}</title>`);
  });
});

// ─── El CSS del bloque ───────────────────────────────────────────────────────────────────────────

const STATIC_CSS = read(new URL("../home/src/static.css", import.meta.url));

/** Las reglas de un CSS (sin comentarios), con el `@media` que las contiene (o `null`). */
function rules(css) {
  const clean = css.replace(/\/\*[\s\S]*?\*\//g, "");
  const out = [];
  const walk = (text, media) => {
    let i = 0;
    while (i < text.length) {
      const open = text.indexOf("{", i);
      if (open < 0) break;
      const prelude = text.slice(i, open).trim();
      let depth = 1;
      let j = open + 1;
      while (depth > 0 && j < text.length) {
        if (text[j] === "{") depth++;
        else if (text[j] === "}") depth--;
        j++;
      }
      const body = text.slice(open + 1, j - 1);
      if (prelude.startsWith("@media")) walk(body, prelude);
      else if (!prelude.startsWith("@keyframes")) {
        const decls = Object.fromEntries(
          body.split(";").map((d) => d.trim()).filter(Boolean).map((d) => [d.slice(0, d.indexOf(":")).trim(), d.slice(d.indexOf(":") + 1).trim()]),
        );
        out.push({ selectors: prelude.split(",").map((s) => s.trim()), media, decls });
      }
      i = j;
    }
  };
  walk(clean, null);
  return out;
}
const ruleFor = (list, selector, media = null) => list.find((r) => r.selectors.includes(selector) && r.media === media);
/** Todas las hojas de la página de inicio (las fuentes de `home/src/`). */
const homeCss = () =>
  readdirSync(new URL("../home/src/", import.meta.url))
    .filter((f) => f.endsWith(".css"))
    .map((f) => [f, read(new URL(`../home/src/${f}`, import.meta.url))]);

describe("CA-025-11 y CL-025-12: el bloque se ve sin programa", () => {
  const list = rules(STATIC_CSS);

  test("sin JavaScript (`scripting: none`), al instante", () => {
    const r = ruleFor(list, ".static", "@media (scripting: none)");
    assert.ok(r, "falta la regla de `scripting: none`");
    assert.equal(r.decls.visibility, "visible");
    assert.equal(r.decls.animation, "none");
  });

  test("con JavaScript, oculto al principio y a la vista a los 2 s (si nadie lo quita antes)", () => {
    const r = ruleFor(list, ".static");
    assert.equal(r.decls.visibility, "hidden");
    assert.match(r.decls.animation, /^static-reveal 0s linear 2s forwards$/);
    assert.match(STATIC_CSS, /@keyframes static-reveal\s*\{\s*to\s*\{\s*visibility:\s*visible;\s*\}\s*\}/);
  });

  test("si el montaje falla (`is-shown`), al momento; mientras monta (`is-mounting`), fuera del dibujo", () => {
    assert.deepEqual(ruleFor(list, ".static.is-shown").decls, { visibility: "visible", animation: "none" });
    assert.deepEqual(ruleFor(list, ".static.is-mounting").decls, { display: "none" });
  });

  test("ninguna regla de «reducir movimiento» anula el retardo (ni la del bloque ni una general)", () => {
    for (const [file, css] of homeCss()) {
      for (const r of rules(css)) {
        if (!r.media || !/prefers-reduced-motion/.test(r.media)) continue;
        const touchesAnimation = Object.keys(r.decls).some((p) => /^(animation|transition|visibility|display)/.test(p));
        const couldMatchStatic = r.selectors.some((s) => /\*|static|^(html|body|main|div)\b|^:root/.test(s));
        assert.ok(!(touchesAnimation && couldMatchStatic), `${file}: «${r.selectors.join(", ")}» en ${r.media} anula el retardo de #static`);
      }
    }
    assert.ok(!/prefers-reduced-motion/.test(STATIC_CSS.replace(/\/\*[\s\S]*?\*\//g, "")), "static.css no mira «reducir movimiento»");
  });

  test("la hoja construida lleva las mismas reglas (el minificador no las quita)", () => {
    const assets = readdirSync(join(base.dist, "assets")).filter((f) => f.endsWith(".css"));
    const css = read(join(base.dist, "assets", assets[0]));
    assert.match(css, /@media \(scripting:\s*none\)\{\.static\{visibility:visible;animation:none\}\}/);
    assert.match(css, /\.static\{visibility:hidden;[^}]*animation:0s linear 2s forwards static-reveal/);
    assert.match(css, /\.static\.is-shown\{visibility:visible;animation:none\}/);
    assert.match(css, /\.static\.is-mounting\{display:none\}/);
    assert.ok(html.includes(`<link rel="stylesheet" crossorigin href="/assets/${assets[0]}">`), "la hoja se carga desde el HTML, sin programa");
  });
});

// ─── El arranque ─────────────────────────────────────────────────────────────────────────────────

/** Un DOM de mentira con lo que usa `boot`: árbol, clases, foco, `getElementById` y `querySelector("h1")`. */
function fakeDom() {
  const doc = { activeElement: null };
  class El {
    constructor(tag, { id = null, classes = [] } = {}) {
      this.tag = tag;
      this.id = id;
      this.children = [];
      this.parent = null;
      this.classes = new Set(classes);
      this.classList = {
        add: (c) => this.classes.add(c),
        remove: (c) => this.classes.delete(c),
        contains: (c) => this.classes.has(c),
      };
    }
    append(...els) {
      for (const el of els) {
        el.parent = this;
        this.children.push(el);
      }
      return this;
    }
    remove() {
      if (!this.parent) return;
      this.parent.children.splice(this.parent.children.indexOf(this), 1);
      this.parent = null;
    }
    contains(el) {
      for (let x = el; x; x = x.parent) if (x === this) return true;
      return false;
    }
    focus() {
      doc.activeElement = this;
    }
    *all() {
      yield this;
      for (const c of this.children) yield* c.all();
    }
  }
  const body = new El("body");
  const main = new El("main", { id: "journey" });
  const block = new El("div", { id: STATIC_ID, classes: ["static"] });
  const staticH1 = new El("h1");
  const link = new El("a");
  block.append(staticH1, new El("section").append(link));
  main.append(block);
  body.append(main);
  Object.assign(doc, {
    body,
    getElementById: (id) => [...body.all()].find((e) => e.id === id) ?? null,
    querySelector: (sel) => (sel === "h1" ? [...body.all()].find((e) => e.tag === "h1") ?? null : null),
  });
  /**
   * Los `h1` que se ven y se leen: los del documento que no están dentro de un bloque `#static` oculto. El
   * bloque se ve solo si no está `is-mounting` y (pasados los 2 s, [late]) o `is-shown`.
   */
  const visibleH1 = ({ late = false } = {}) =>
    [...body.all()].filter((e) => {
      if (e.tag !== "h1") return false;
      for (let x = e; x; x = x.parent) {
        if (x.id === STATIC_ID) return !x.classes.has("is-mounting") && (late || x.classes.has("is-shown"));
      }
      return true;
    });
  return { doc, El, main, block, staticH1, link, visibleH1 };
}

describe("CL-025-12: el arranque quita el bloque al montar o lo enseña si falla", () => {
  test("montaje correcto: se quita el bloque y queda un solo <h1>, el del montaje", async () => {
    const dom = fakeDom();
    const sceneH1 = new dom.El("h1");
    const ok = await boot({ doc: dom.doc, mount: () => dom.main.append(sceneH1) });
    assert.equal(ok, true);
    assert.equal(dom.doc.getElementById(STATIC_ID), null, "el bloque sigue (se vería y se leería dos veces, CA-025-15)");
    assert.deepEqual(dom.visibleH1({ late: true }), [sceneH1]);
  });

  test("un solo <h1> a la vista en cada momento, también si el programa llega después de los 2 s", async () => {
    for (const late of [false, true]) {
      const dom = fakeDom();
      assert.equal(dom.visibleH1({ late: true }).length, 1, "antes de arrancar");
      const seen = [];
      await boot({
        doc: dom.doc,
        mount: async () => {
          seen.push(dom.visibleH1({ late }).length);
          dom.main.append(new dom.El("h1"));
          seen.push(dom.visibleH1({ late }).length);
          await null; // un montaje asíncrono: el navegador puede pintar aquí
          seen.push(dom.visibleH1({ late }).length);
        },
      });
      seen.push(dom.visibleH1({ late }).length);
      assert.deepEqual(seen, [0, 1, 1, 1], `programa ${late ? "tardío" : "a tiempo"}`);
    }
  });

  test("fallo forzado al arrancar (síncrono): se deshace lo montado y el bloque se enseña al momento", async () => {
    const dom = fakeDom();
    const ok = await boot({
      doc: dom.doc,
      mount: ({ onUndo }) => {
        const partial = new dom.El("h1");
        dom.main.append(partial);
        onUndo(() => partial.remove());
        throw new Error("fallo forzado");
      },
    });
    assert.equal(ok, false);
    assert.equal(dom.doc.getElementById(STATIC_ID), dom.block, "el bloque se quitó");
    assert.ok(dom.block.classes.has("is-shown"));
    assert.ok(!dom.block.classes.has("is-mounting"), "sigue fuera del dibujo");
    assert.deepEqual(dom.main.children, [dom.block], "quedan restos del montaje");
    assert.deepEqual(dom.visibleH1(), [dom.staticH1], "a la vista al momento, sin esperar 2 s");
  });

  test("fallo asíncrono del arranque: igual", async () => {
    const dom = fakeDom();
    const ok = await boot({
      doc: dom.doc,
      mount: async ({ onUndo }) => {
        const partial = new dom.El("section");
        dom.main.append(partial);
        onUndo(() => partial.remove());
        await Promise.resolve();
        throw new Error("fallo forzado asíncrono");
      },
    });
    assert.equal(ok, false);
    assert.deepEqual(dom.main.children, [dom.block]);
    assert.ok(dom.block.classes.has("is-shown"));
  });

  test("se deshace todo en orden inverso, aunque un paso de deshacer falle", async () => {
    const dom = fakeDom();
    const order = [];
    await boot({
      doc: dom.doc,
      mount: ({ onUndo }) => {
        onUndo(() => order.push("a"));
        onUndo(() => {
          order.push("b");
          throw new Error("x");
        });
        onUndo(() => order.push("c"));
        throw new Error("fallo forzado");
      },
    });
    assert.deepEqual(order, ["c", "b", "a"]);
    assert.ok(dom.block.classes.has("is-shown"));
  });

  test("con el montaje bien, no se deshace nada", async () => {
    const dom = fakeDom();
    let undone = false;
    await boot({ doc: dom.doc, mount: ({ onUndo }) => onUndo(() => (undone = true)) });
    assert.equal(undone, false);
  });

  test("si el foco estaba en el bloque (programa tardío), pasa al <h1> del montaje", async () => {
    const dom = fakeDom();
    dom.link.focus();
    const sceneH1 = new dom.El("h1");
    await boot({ doc: dom.doc, mount: () => dom.main.append(sceneH1) });
    assert.equal(dom.doc.activeElement, sceneH1);
  });

  test("si el foco estaba en el bloque y el montaje falla, pasa al <h1> del bloque", async () => {
    const dom = fakeDom();
    dom.link.focus();
    await boot({
      doc: dom.doc,
      mount: () => {
        throw new Error("fallo forzado");
      },
    });
    assert.equal(dom.doc.activeElement, dom.staticH1);
  });

  test("si el foco no estaba en el bloque, no se mueve", async () => {
    const dom = fakeDom();
    const other = new dom.El("button");
    dom.doc.body.append(other);
    other.focus();
    await boot({ doc: dom.doc, mount: () => dom.main.append(new dom.El("h1")) });
    assert.equal(dom.doc.activeElement, other);
  });

  test("main.js monta dentro de `boot` y elige el idioma con `pickLang`", () => {
    const src = read(new URL("../home/src/main.js", import.meta.url));
    assert.match(src, /^boot\(\{ doc: document, mount \}\);$/m);
    assert.match(src, /pickLang\(\{ storage: browserStorage\(window\), languages: navigator\.languages, language: navigator\.language \}\)/);
    assert.match(src, /applyLang\(document, lang, strings, site\.appName\)/);
    assert.match(src, /chooseMode\(detectMode\(window\)\)/);
    assert.ok(!/location\.search|URLSearchParams/.test(src), "lee parámetros de la dirección (Q-025-9)");
  });
});
