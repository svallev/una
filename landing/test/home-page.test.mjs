// La página de inicio llega escrita (T-025-07c): la construcción genera con los mismos constructores que usa
// el programa la cabecera, las siete escenas y el pie; todo texto pasa por una sola función de escape; y el
// botón de completar se llama como lo que enseña.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { after, before, describe, test } from "node:test";
import { BuildError, HOME_PAGE_MARK, fillHomePage, writeHomeGen } from "../build.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

const SCENE_IDS = ["hero", "muchas", "una", "amano", "activa", "luz", "fin"];

let base;
let html;
before(async () => {
  base = world();
  base.build();
  await base.buildHome();
  html = read(join(base.dist, "index.html"));
});
after(() => base.cleanup());

/** Los módulos de la página de inicio de [w] (cada mundo, su copia: Node no mezcla sus cachés). */
const homeModule = (w, ...path) => import(pathToFileURL(join(w.paths.homeDir, "src", ...path)).href);
const strings = (w, lang) => JSON.parse(read(join(w.paths.homeDir, "src", "shared", `strings.${lang}.json`)));

/** El texto de un trozo de HTML sin etiquetas ni lo que va `aria-hidden` (un nombre accesible aproximado). */
function visibleText(fragment) {
  let s = fragment;
  // Quita los elementos `aria-hidden="true"` (svg o span), de dentro hacia fuera.
  for (let prev = ""; prev !== s; ) {
    prev = s;
    s = s.replace(/<(svg|span)\b[^>]*aria-hidden="true"[^>]*>(?:(?!<\1\b)[\s\S])*?<\/\1>/g, "");
  }
  return s.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
}

/** El botón de completar del móvil de prueba: su etiqueta de apertura y su contenido. */
function holdButton(page) {
  const m = /<button class="app__btn hold__btn"([^>]*)>([\s\S]*?)<\/button>/.exec(page);
  assert.ok(m, "no está el botón de completar");
  return { attrs: m[1], inner: m[2] };
}

describe("CA-025-11: sin JavaScript, la página construida ya trae su contenido", () => {
  test("las siete escenas, en orden, con su titular (un h1 y seis h2) y sin la marca de la plantilla", () => {
    const ids = [...html.matchAll(/<section class="sc sc--([a-z]+)[^"]*" id="([a-z]+)"/g)].map((m) => m[2]);
    assert.deepEqual(ids, SCENE_IDS);
    assert.equal((html.match(/<h1 /g) ?? []).length, 1);
    assert.equal((html.match(/<h2 /g) ?? []).length, 6);
    for (const id of SCENE_IDS) assert.match(html, new RegExp(`<h[12] class="big" id="h-${id}"`));
    assert.ok(!html.includes(HOME_PAGE_MARK), "queda la marca de la plantilla");
    assert.ok(!/<noscript/i.test(html), "queda el aviso de «Activa JavaScript»");
  });

  test("la cabecera, las tiendas y el pie con Ayuda, Privacidad y Licencias", () => {
    const es = strings(base, "es");
    assert.match(html, /<header class="top">[\s\S]*<a class="logo" href="#top"/);
    assert.match(html, /<a class="btn" href="#fin">/);
    for (const [href, key] of [["/help", "help"], ["/privacy", "privacy"], ["/licenses", "licenses"]]) {
      assert.ok(html.includes(`<a href="${href}">${es.footer[key]}</a>`), `falta el enlace a ${href}`);
    }
    const stores = [...html.matchAll(/class="badge badge--(appStore|googlePlay)/g)].map((m) => m[1]);
    assert.deepEqual(stores, ["appStore", "googlePlay", "appStore", "googlePlay"]);
  });

  test("en el idioma por defecto: lang, título, descripción y textos de las escenas en español", () => {
    const es = strings(base, "es");
    assert.match(html, /^<!doctype html>\s*<html lang="es">/i);
    assert.ok(html.includes(`<title>${es.meta.title.replace("{app}", "Una")}</title>`), "el título no es el de los textos");
    assert.ok(html.includes(`content="${es.meta.description.replace("{app}", "Una")}"`), "la descripción no es la de los textos");
    assert.ok(html.includes(`<p class="lead">${es.scenes.fin.lead}</p>`));
    assert.ok(html.includes(es.scenes.hero.lead));
  });

  test("el móvil de prueba sale con sus dos notas escritas y los interruptores encendidos (versión apilada)", () => {
    const es = strings(base, "es");
    assert.ok(html.includes(`>${es.tasks[0]}</p>`), "la nota de encima está vacía");
    assert.match(html, /<div class="hold__note hold__note--next" style="--note:[^"]+" aria-hidden="true">/);
    assert.equal((html.match(/<span class="sw is-on" aria-hidden="true">/g) ?? []).length, 2);
  });

  test("un solo programa, el de Vite; la página entera va antes que nada de lo que añade", () => {
    assert.equal((html.match(/<script\b/g) ?? []).length, 1);
    assert.ok(html.indexOf("<header") > html.indexOf("</head>"));
  });

  test("CA-025-09: las tiendas, en el mismo orden en la entradilla del cierre que en los rótulos", () => {
    assert.equal(strings(base, "es").scenes.fin.lead, "Muy pronto en App Store y Google Play.");
    assert.equal(strings(base, "en").scenes.fin.lead, "Coming soon to the App Store and Google Play.");
  });
});

describe("CA-025-11: la construcción y el programa usan los mismos constructores", () => {
  test("el cuerpo construido es pageHtml() en español, sin cambiar nada", async () => {
    const page = await homeModule(base, "a", "page.js");
    const i18n = await homeModule(base, "shared", "i18n.js");
    i18n.useLang("es");
    assert.ok(html.includes(page.pageHtml()), "el cuerpo no es el que genera page.js");
  });

  test("en inglés, el mismo constructor da la página en inglés (lo que escribe el programa)", async () => {
    const page = await homeModule(base, "a", "page.js");
    const i18n = await homeModule(base, "shared", "i18n.js");
    const en = strings(base, "en");
    try {
      i18n.useLang("en");
      const body = page.pageHtml();
      assert.ok(body.includes(en.scenes.amano.chips[0]));
      assert.ok(body.includes('aria-pressed="true">EN'));
      assert.equal(page.pageMeta().lang, "en");
    } finally {
      i18n.useLang("es");
    }
  });

  test("un idioma que no existe no se acepta", async () => {
    const i18n = await homeModule(base, "shared", "i18n.js");
    assert.throws(() => i18n.useLang("fr"));
    assert.equal(i18n.lang, "es");
  });

  test("pickLang: español y catalán abren en español; el resto, en inglés", async () => {
    const { pickLang } = await homeModule(base, "shared", "i18n.js");
    assert.deepEqual(["es-ES", "ca", "CA-es", "en-US", "gl", "fr"].map(pickLang), ["es", "es", "es", "en", "en", "en"]);
  });

  test("una plantilla sin la marca, o con dos, hace fallar la construcción", async () => {
    const template = read(join(base.paths.homeDir, "index.html"));
    await assert.rejects(fillHomePage(template.replace(HOME_PAGE_MARK, ""), base.paths), BuildError);
    await assert.rejects(fillHomePage(template.replace(HOME_PAGE_MARK, HOME_PAGE_MARK + HOME_PAGE_MARK), base.paths), BuildError);
    await assert.rejects(fillHomePage(template.replace(/<title>[^<]*<\/title>/, ""), base.paths), BuildError);
  });
});

describe("CA-025-12: todo texto del HTML generado pasa por una sola función de escape", () => {
  test("esc escapa & < > \" y '", async () => {
    const { esc } = await homeModule(base, "shared", "html.js");
    assert.equal(esc(`<a href="x" title='y'>&amp;</a>`), "&lt;a href=&quot;x&quot; title=&#39;y&#39;&gt;&amp;amp;&lt;/a&gt;");
    assert.equal(esc(42), "42");
  });

  test("con texto hostil en titulares, entradillas, notas, tareas, etiquetas y enlaces, no entra ninguna etiqueta", async () => {
    const w = cloneWorld(base);
    try {
      const evil = `<img src=x onerror=alert(1)>"'&`;
      const file = join(w.paths.homeDir, "src", "shared", "strings.es.json");
      const s = JSON.parse(read(file));
      s.meta.title = s.meta.description = evil;
      s.nav.home = s.nav.lang = s.nav.download = s.nav.hint = evil;
      s.store.soon = s.store.appStore = s.store.googlePlay = evil;
      s.footer.legal = s.footer.nav = s.footer.help = s.footer.privacy = s.footer.licenses = evil;
      for (const id of SCENE_IDS) {
        s.scenes[id].title = `${evil}|*${evil}*`;
        s.scenes[id].lead = evil;
      }
      s.scenes.una.try = s.scenes.activa.note = evil;
      s.scenes.activa.switch = s.scenes.luz.switch = evil;
      s.scenes.amano.chips = [evil, evil, evil];
      s.tasks = s.tasks.map(() => evil);
      for (const key of Object.keys(s.app)) s.app[key] = Array.isArray(s.app[key]) ? s.app[key].map(() => evil) : evil;
      s.app.progRows = s.app.progRows.map(() => `${evil}|${evil}|${evil}`);
      edit(file, () => `${JSON.stringify(s, null, 2)}\n`);
      writeHomeGen(w.paths);
      const out = await fillHomePage(read(join(w.paths.homeDir, "index.html")), w.paths);
      assert.ok(!out.includes("<img src=x"), "entró una etiqueta sin escapar");
      assert.ok(!/onerror=alert\(1\)>"/.test(out), "entró un atributo sin escapar");
      const escaped = (out.match(/&lt;img src=x onerror=alert\(1\)&gt;&quot;&#39;&amp;/g) ?? []).length;
      // Cada texto que se cambió aparece escapado (muchas veces: tareas, filas, pantallas…).
      assert.ok(escaped > 60, `solo ${escaped} textos escapados`);
      // Y fuera de lo escapado no queda ninguna comilla suelta de ese texto rompiendo un atributo.
      for (const m of out.matchAll(/<[a-z][^>]*>/g)) {
        assert.ok(!m[0].replace(/"[^"]*"/g, '""').includes("onerror"), `etiqueta rota: ${m[0]}`);
      }
    } finally {
      w.cleanup();
    }
  });

  test("ningún constructor escapa por su cuenta: solo html.js define la función de escape", () => {
    const files = ["shared/chrome.js", "shared/i18n.js", "a/app-ui.js", "a/art.js", "a/hold.js", "a/page.js", "a/main.js"];
    for (const f of files) {
      const code = readFileSync(join(base.paths.homeDir, "src", f), "utf8");
      assert.ok(!/&amp;|&lt;|&quot;/.test(code), `${f} escapa a mano`);
    }
  });
});

describe("CA-025-15: el nombre del botón de completar contiene su texto visible (WCAG 2.5.3)", () => {
  for (const lang of ["es", "en"]) {
    test(`en ${lang}`, async () => {
      const page = await homeModule(base, "a", "page.js");
      const i18n = await homeModule(base, "shared", "i18n.js");
      const t = strings(base, lang);
      let body;
      try {
        i18n.useLang(lang);
        body = page.pageHtml();
      } finally {
        i18n.useLang("es");
      }
      const { attrs, inner } = holdButton(body);
      const visible = visibleText(/<span class="hold__label">([\s\S]*?)<\/span><span class="hold__fill"/.exec(inner)[1]);
      assert.equal(visible, t.app.complete);
      const label = /aria-label="([^"]*)"/.exec(attrs)?.[1];
      const name = label ?? visibleText(inner);
      assert.ok(name.toLowerCase().includes(visible.toLowerCase()), `«${name}» no contiene «${visible}»`);
      // Cómo se usa va en la descripción, y el móvil no esconde el botón al lector.
      const described = /aria-describedby="([^"]+)"/.exec(attrs)?.[1];
      assert.ok(body.includes(`<span class="vh" id="${described}">${t.app.completeA11y}</span>`));
      const phone = /<div class="phone phone--hold"[^>]*>/.exec(body)[0];
      assert.ok(!phone.includes("aria-hidden"), `el móvil de prueba se oculta al lector: ${phone}`);
    });
  }
});

describe("T-025-07c: si el programa no arranca, la página no se queda en blanco", () => {
  test("el cuerpo oculto a la espera del programa se enseña solo a los 2 s", () => {
    const css = readFileSync(new URL("../home/src/shared/base.css", import.meta.url), "utf8");
    assert.match(css, /html:not\(\.is-ready\) body \{ visibility: hidden; animation: reveal 0s 2s forwards; \}/);
    assert.match(css, /@keyframes reveal \{ to \{ visibility: visible; \} \}/);
  });
});

describe("Cambio del propietario (2026-11-15): la mesa de luz, un gato sin texto y sin nota", () => {
  /** El HTML de la escena de la mesa de luz en la página construida. */
  const luzScene = () => {
    const m = /<section class="sc sc--luz[^"]*" id="luz"[\s\S]*?<\/section>/.exec(html);
    assert.ok(m, "no está la escena de la mesa de luz");
    return m[0];
  };

  test("la tarea de la mesa de luz no lleva título y su imagen y su calco no tienen texto", () => {
    const scene = luzScene();
    const phone = /<div class="table__tilt">[\s\S]*?<\/div><\/div>/.exec(scene)?.[0] ?? scene;
    assert.ok(phone.includes('class="lightbox__paper"'), "no está el papel de calco");
    assert.ok(!phone.includes("app__caption"), "la tarea de la mesa de luz lleva título");
    for (const svg of scene.match(/<svg\b[\s\S]*?<\/svg>/g) ?? []) assert.ok(!/<text\b/.test(svg), "un dibujo de la escena lleva texto");
  });

  test("la imagen y el calco del gato comparten la geometría y cada trazo del calco lleva pathLength", async () => {
    const { cat } = await homeModule(base, "a", "art.js");
    const { art, trace } = cat();
    const traced = [...trace.matchAll(/<(path|ellipse|circle|rect) ([^>]*?) pathLength="1"\/>/g)];
    assert.ok(traced.length >= 15, `solo ${traced.length} trazos en el calco`);
    for (const [, tag, geo] of traced) assert.ok(art.includes(`<${tag} ${geo} `), `el calco no está en la imagen: ${geo}`);
    assert.ok(!/<text\b/.test(art + trace));
  });

  test("las demás tareas con imagen siguen con su título", () => {
    assert.ok((html.match(/class="app__caption"/g) ?? []).length >= 3);
  });

  test("ni app.traceTask ni scenes.luz.note existen en ES ni en EN; scenes.activa.note sigue", () => {
    for (const lang of ["es", "en"]) {
      const s = strings(base, lang);
      assert.equal(s.app.traceTask, undefined, `app.traceTask sigue en ${lang}`);
      assert.equal(s.scenes.luz.note, undefined, `scenes.luz.note sigue en ${lang}`);
      assert.ok(s.scenes.activa.note);
      assert.match(s.app.traceAlt, lang === "es" ? /gato estilo anime/ : /anime-style cat/);
    }
  });

  test("la escena de la mesa de luz no pinta nota (ni un párrafo vacío) y la de activa sí", () => {
    const es = strings(base, "es");
    assert.ok(!/<p class="fine">/.test(luzScene()), "la mesa de luz pinta una nota");
    assert.ok(!html.includes("Solo para imágenes."));
    const activa = /<section class="sc sc--activa[\s\S]*?<\/section>/.exec(html)[0];
    assert.ok(activa.includes(`<p class="fine">${es.scenes.activa.note}</p>`));
  });
});
