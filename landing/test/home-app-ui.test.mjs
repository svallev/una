// Las pantallas de la app y las ilustraciones de la página de inicio (spec 025, CA-025-06, CA-025-14 y
// CA-025-15; plan §2.3 y §6.1): `app-ui.js`, `art.js` y `device.css`. Los textos que la app ya tiene son los de
// sus ARB, los dominios de los ejemplos son reservados, cada móvil lleva descripción o se oculta, todo texto
// pasa por la única `esc` y el HTML generado (ES y EN) pasa las reglas de etiquetas de `check.mjs`.
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";
import { defaultPaths, homeSite } from "../build.mjs";
import { checkMarkup } from "../check.mjs";
import {
  LIST_NOTES,
  NOTES,
  NOTE_SIZES,
  SETTINGS,
  appPhones,
  appUi,
  listRow,
  noteSize,
  settingRow,
  textTask,
} from "../home/src/app-ui.js";
import { esc } from "../home/src/html.js";

const paths = defaultPaths();
const SRC = join(paths.homeDir, "src");
const source = (file) => readFileSync(join(SRC, file), "utf8");
const json = (file) => JSON.parse(source(file));
const STRINGS = { es: json("strings.es.json"), en: json("strings.en.json") };
const SITE = homeSite(paths);
const ARB = { es: JSON.parse(readFileSync(paths.arbEs, "utf8")), en: JSON.parse(readFileSync(paths.arbEn, "utf8")) };
const LANGS = ["es", "en"];

const uiOf = (lang, { strings = STRINGS[lang], site = SITE } = {}) => appUi({ strings, site, lang });
/** Todo lo que generan `app-ui.js` y `art.js`: los móviles y las dos filas de Ajustes. */
const everything = (ui) => ({
  ...appPhones(ui),
  settingKeepAwake: settingRow(ui, "keepAwake"),
  settingLockZoom: settingRow(ui, "lockZoom", { on: true }),
});
/** El texto visible de un fragmento (sin etiquetas ni entidades). */
const textOf = (html) =>
  html
    .replace(/<[^>]*>/g, " ")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&amp;", "&");
/** La primera etiqueta de [html], con sus atributos. */
const firstTag = (html) => {
  const m = /^<([a-z]+)([^>]*)>/.exec(html);
  const attrs = Object.fromEntries([...m[2].matchAll(/([a-z-]+)="([^"]*)"/g)].map((a) => [a[1], a[2]]));
  return { name: m[1], attrs };
};

// ─── CA-025-06: los textos de la app ────────────────────────────────────────────────────────────

describe("CA-025-06: los textos que la app ya tiene son los de la app, sin recortar", () => {
  for (const lang of LANGS) {
    const ui = uiOf(lang);
    const arb = ARB[lang];
    const phones = appPhones(ui);

    test(`${lang}: el listado lleva el título, la ayuda entera y «Nueva tarea» de app_${lang}.arb`, () => {
      for (const key of ["listTitle", "listHelp", "listNewTask"]) {
        assert.ok(phones.list.includes(`>${esc(arb[key])}<`), `falta ${key}: «${arb[key]}»`);
      }
    });

    test(`${lang}: cada tarea lleva el botón de completar de la app`, () => {
      for (const [name, html] of Object.entries(phones)) {
        if (name === "list") continue;
        assert.ok(html.includes(`<span>${esc(arb.completeButton)}</span>`), `${name} sin «${arb.completeButton}»`);
      }
    });

    test(`${lang}: las dos filas de Ajustes llevan el nombre y el subtítulo de la app`, () => {
      for (const which of Object.keys(SETTINGS)) {
        const html = settingRow(ui, which);
        const { title, hint } = SETTINGS[which];
        assert.ok(html.includes(`<b>${esc(arb[title])}</b>`), `${which}: falta ${title}`);
        assert.ok(html.includes(`<small>${esc(arb[hint])}</small>`), `${which}: falta ${hint}`);
      }
      assert.deepEqual(Object.keys(SETTINGS), ["keepAwake", "lockZoom"]);
    });

    test(`${lang}: las entradillas nombran los ajustes como la app (sin recortar)`, () => {
      assert.ok(STRINGS[lang].awakeLead.includes(arb.settingsKeepAwake), "awakeLead no lleva el nombre del ajuste de la app");
      assert.ok(STRINGS[lang].lightLead.includes(arb.settingsLockZoom), "lightLead no lleva el nombre del ajuste de la app");
    });

    test(`${lang}: el logotipo de cada pantalla es el de la identidad`, () => {
      for (const [name, html] of Object.entries(phones)) {
        if (name === "list") continue;
        assert.ok(html.includes(`<span class="app__logo">${esc(SITE.wordmark)}</span>`), `${name} sin el logotipo`);
      }
    });
  }

  test("ningún texto de la app está escrito en app-ui.js, art.js ni en los textos de la página", () => {
    const code = source("app-ui.js") + source("art.js");
    const pageTexts = JSON.stringify(STRINGS);
    for (const lang of LANGS) {
      for (const [key, value] of Object.entries(SITE.app[lang])) {
        assert.ok(!code.includes(value), `«${value}» (${key}) escrito a mano en el código`);
        // Los nombres de los ajustes sí aparecen dentro de las entradillas (spec §7); como texto suelto, no.
        assert.ok(!pageTexts.includes(`"${value}"`), `«${value}» (${key}) copiado en strings.${lang}.json`);
      }
    }
  });

  test("si la app cambia un texto, las pantallas cambian con él (CL-025-9)", () => {
    const site = { ...SITE, app: { ...SITE.app, en: { ...SITE.app.en, completeButton: "Hold to finish", listHelp: "Help." } } };
    const phones = appPhones(uiOf("en", { site }));
    assert.ok(phones.current.includes("<span>Hold to finish</span>"));
    assert.ok(phones.list.includes(">Help.<"));
    assert.ok(!phones.current.includes(ARB.en.completeButton));
  });

  test("si la identidad cambia el logotipo, las pantallas cambian con él (CA-025-14)", () => {
    const phones = appPhones(uiOf("es", { site: { ...SITE, wordmark: "zorro." } }));
    for (const [name, html] of Object.entries(phones)) {
      if (name !== "list") assert.ok(html.includes('<span class="app__logo">zorro.</span>'), name);
    }
  });
});

// ─── CA-025-06: dominios reservados ─────────────────────────────────────────────────────────────

/** Dominios reservados para ejemplos (RFC 2606 y 6761). */
const RESERVED = /(^|\.)(example\.(com|net|org)|example|test|invalid|localhost)$/;
/** Lo que parece un dominio en un texto: etiquetas separadas por puntos (no los nombres de archivo). */
const domainsIn = (text) =>
  [...text.toLowerCase().matchAll(/(?<![\p{L}\p{N}.-])(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z][a-z0-9-]*(?![\p{L}\p{N}-])/gu)]
    .map((m) => m[0])
    .filter((d) => !/\.(pdf|jpe?g|png|svg|txt)$/.test(d));

describe("CA-025-06: los dominios del contenido de ejemplo son reservados para ejemplos", () => {
  for (const lang of LANGS) {
    test(`${lang}: en las pantallas generadas y en los textos de ejemplo`, () => {
      const html = Object.values(everything(uiOf(lang))).join("\n");
      const found = [...domainsIn(textOf(html)), ...domainsIn(JSON.stringify(STRINGS[lang].sample))];
      assert.ok(found.length >= 2, `se esperaban al menos la web y el cartel: ${found.join(", ")}`);
      for (const d of found) assert.match(d, RESERVED, `«${d}» no es un dominio reservado para ejemplos`);
    });
  }

  test("la comprobación ve un dominio real (en el texto de ejemplo o en la ilustración)", () => {
    assert.deepEqual(domainsIn("ver rutas.es/rio y example.com/x"), ["rutas.es", "example.com"]);
    assert.doesNotMatch("rutas.es", RESERVED);
    assert.doesNotMatch("example.com.evil.net", RESERVED);
    assert.deepEqual(domainsIn("bizcocho-de-yogur.pdf · Av. de los Tilos · 8,4 km"), []);
    const strings = structuredClone(STRINGS.es);
    strings.sample.routeHost = "rutas.es/rio";
    const html = appPhones(uiOf("es", { strings })).route;
    assert.ok(domainsIn(textOf(html)).some((d) => !RESERVED.test(d)));
  });

  test("ninguna dirección con protocolo en las pantallas, en las ilustraciones ni en los textos de ejemplo", () => {
    for (const lang of LANGS) {
      const text = Object.values(everything(uiOf(lang))).join("\n") + JSON.stringify(STRINGS[lang].sample);
      assert.doesNotMatch(text, /\b(https?|ftp):/i);
    }
  });
});

// ─── CA-025-15: descripción u oculto ────────────────────────────────────────────────────────────

describe("CA-025-15: cada móvil lleva una descripción o se oculta al lector", () => {
  const LABELS = {
    list: "list",
    current: "screen",
    golf: "golf",
    lineup: "lineup",
    programme: "prog",
    route: "route",
    recipe: "pdf",
    trace: "trace",
    book: "book",
  };

  for (const lang of LANGS) {
    test(`${lang}: los móviles con descripción son una imagen con su texto de alt.*; el resto, ocultos`, () => {
      const phones = appPhones(uiOf(lang));
      assert.deepEqual(Object.keys(phones).sort(), [...Object.keys(LABELS), "endText"].sort());
      for (const [name, html] of Object.entries(phones)) {
        const { name: tag, attrs } = firstTag(html);
        assert.equal(tag, "div");
        assert.match(attrs.class, /^phone\b/);
        if (name in LABELS) {
          assert.equal(attrs.role, "img", `${name} sin role="img"`);
          assert.equal(attrs["aria-label"], esc(STRINGS[lang].alt[LABELS[name]]), `${name}: descripción`);
          assert.ok(!("aria-hidden" in attrs), `${name}: con descripción y oculto a la vez`);
        } else {
          assert.equal(attrs["aria-hidden"], "true", `${name}: sin descripción tiene que ir oculto`);
          assert.ok(!("role" in attrs) && !("aria-label" in attrs));
        }
      }
    });

    test(`${lang}: los textos alt.* de los móviles existen y no están vacíos`, () => {
      for (const key of Object.values(LABELS)) assert.ok(STRINGS[lang].alt[key]?.trim(), `falta alt.${key}`);
    });
  }

  test("un móvil sin descripción se oculta; con descripción, se lee como imagen", async () => {
    const { phone } = await import("../home/src/app-ui.js");
    assert.match(phone("<p>x</p>"), /^<div class="phone" aria-hidden="true">/);
    assert.match(phone("<p>x</p>", { label: "Una lista" }), /^<div class="phone" role="img" aria-label="Una lista">/);
  });

  test("las ilustraciones y los iconos van siempre ocultos al lector", () => {
    for (const lang of LANGS) {
      for (const [name, html] of Object.entries(everything(uiOf(lang)))) {
        for (const m of html.matchAll(/<svg\b[^>]*>/g)) assert.match(m[0], /\baria-hidden="true"/, `${name}: ${m[0]}`);
      }
    }
  });

  test("la fila de Ajustes se lee (nombre y subtítulo) y el interruptor, que solo dibuja, no", () => {
    const html = settingRow(uiOf("es"), "keepAwake", { on: true });
    assert.match(html, /<span class="sw is-on" aria-hidden="true"><\/span>/);
    assert.match(settingRow(uiOf("es"), "keepAwake"), /<span class="sw" aria-hidden="true"><\/span>/);
    assert.ok(!/^<div[^>]*aria-hidden/.test(html));
  });
});

// ─── Plan §6.1: una sola `esc` y texto hostil ───────────────────────────────────────────────────

const HOSTILE = `"><img src=x onerror=alert(1)><a href="javascript:alert(2)">'&amp;<style>*{}</style>`;
/** [value] con el texto hostil delante y detrás de cada texto (las listas conservan su longitud). */
const hostile = (value) =>
  typeof value === "string"
    ? `${HOSTILE}${value}${HOSTILE}`
    : Array.isArray(value)
      ? value.map(hostile)
      : value && typeof value === "object"
        ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, hostile(v)]))
        : value;

describe("Plan §6.1: todo texto pasa por la única esc (html.js)", () => {
  test("solo html.js define una función de escape; app-ui.js y art.js la importan", () => {
    for (const file of readdirSync(SRC).filter((f) => f.endsWith(".js"))) {
      const code = source(file);
      const defines = /\b(const|let|var|function)\s+esc\b/.test(code) || /replace\(\/\[&<>/.test(code) || /'&':\s*'&amp;'/.test(code);
      assert.equal(defines, file === "html.js", `${file}: ${defines ? "define" : "no define"} su propio escape`);
    }
    for (const file of ["app-ui.js", "art.js"]) assert.match(source(file), /^import \{ esc \} from "\.\/html\.js";$/m, file);
  });

  for (const lang of LANGS) {
    test(`${lang}: un texto hostil en strings.${lang}.json y en site.json sale escapado`, () => {
      const site = { ...SITE, wordmark: hostile(SITE.wordmark), app: hostile(SITE.app) };
      const all = everything(uiOf(lang, { strings: hostile(STRINGS[lang]), site }));
      for (const [name, html] of Object.entries(all)) {
        assert.deepEqual(checkMarkup(name, html), []);
        assert.ok(!/<(img|a|style)\b/.test(html), `${name}: una etiqueta del texto hostil llegó sin escapar`);
        assert.ok(html.includes("&lt;img src=x onerror=alert(1)&gt;"), `${name}: el texto hostil no aparece escapado`);
      }
    });
  }

  test("también en una fila suelta, en la hora y en la descripción del móvil", async () => {
    const { phone, statusBar } = await import("../home/src/app-ui.js");
    for (const html of [listRow(HOSTILE), statusBar(HOSTILE), phone("", { label: HOSTILE, cls: HOSTILE })]) {
      assert.deepEqual(checkMarkup("x", html), []);
      assert.ok(!/<(img|a|style)\b/.test(html));
    }
  });

  test("un color de nota que no es de la paleta, un PDF o un ajuste desconocidos fallan (no llegan al HTML)", async () => {
    const { pdfTask } = await import("../home/src/app-ui.js");
    const ui = uiOf("es");
    assert.throws(() => textTask(ui, "x", { note: 5 }), /nota/);
    assert.throws(() => listRow("x", { note: '"><b>' }), /nota/);
    assert.throws(() => pdfTask(ui, { kind: "<x>" }), /PDF/);
    assert.throws(() => settingRow(ui, "__proto__"), /ajuste/);
    assert.throws(() => settingRow(ui, "toString"), /ajuste/);
    assert.throws(() => appUi({ strings: STRINGS.es, site: SITE, lang: "fr" }), /idioma/);
  });
});

// ─── CA-025-12: las reglas de etiquetas sobre lo generado ───────────────────────────────────────

describe("CA-025-12: las pantallas generadas (ES y EN) pasan las reglas de etiquetas", () => {
  for (const lang of LANGS) {
    test(`${lang}: sin style=, manejadores, <style>, direcciones externas ni javascript:`, () => {
      for (const [name, html] of Object.entries(everything(uiOf(lang)))) assert.deepEqual(checkMarkup(name, html), []);
    });
  }

  test("app-ui.js y art.js no escriben style= (ni en el SVG)", () => {
    for (const file of ["app-ui.js", "art.js"]) assert.doesNotMatch(source(file), /\sstyle\s*=/, file);
  });

  const bad = {
    "style en línea": '<div style="color:red"></div>',
    "un manejador": '<span onclick="x()"></span>',
    "manejador en mayúsculas": "<span ONMOUSEOVER=x></span>",
    "un <style>": "<style>*{}</style>",
    "un <script>": "<script></script>",
    "un marco": '<iframe src="/x"></iframe>',
    "javascript:": '<a href="javascript:alert(1)">x</a>',
    "data:": '<img src="data:image/png;base64,AA">',
    "una imagen de otro origen": '<img src="https://cdn.example.net/x.png">',
    "un enlace de otro origen": '<a href="//example.org/">x</a>',
    "xlink:href de otro origen": '<svg><use xlink:href="https://example.com/s.svg#a"/></svg>',
    "un <link>": '<link rel="stylesheet" href="/x.css">',
    "un <meta>": '<meta http-equiv="refresh" content="0">',
    "un formulario": "<form></form>",
    "srcdoc": '<div srcdoc="x"></div>',
  };
  for (const [why, html] of Object.entries(bad)) {
    test(`checkMarkup falla: ${why}`, () => {
      const errors = checkMarkup("pantalla", html);
      assert.ok(errors.length > 0, `no falla: ${html}`);
      assert.ok(errors.every((e) => e.startsWith("pantalla: ")));
    });
  }

  test("checkMarkup admite lo propio: enlaces y recursos del mismo origen, aria-*, data-*", () => {
    assert.deepEqual(checkMarkup("x", '<a href="/help">a</a><img src="/img/icon-512.png" alt=""><div data-note="1" aria-hidden="true"></div>'), []);
  });
});

// ─── CA-025-14: colores y fuentes de los tokens, salvo las ilustraciones ────────────────────────

const CSS = source("device.css");
const ILLUSTRATIONS = ["phone", "pdf", "web", "paper"];
/** device.css partido en lo que es interfaz (tokens) y lo marcado como ilustración, con el nombre de cada marca. */
function splitIllustrations(css) {
  const ui = [];
  const names = [];
  let rest = css;
  for (;;) {
    const open = /\/\* @illustration ([a-z]+):/.exec(rest);
    if (!open) break;
    const close = rest.indexOf("/* @end illustration */", open.index);
    if (close < 0) throw new Error(`la marca «${open[1]}» no se cierra`);
    ui.push(rest.slice(0, open.index));
    names.push(open[1]);
    rest = rest.slice(close + "/* @end illustration */".length);
  }
  if (rest.includes("@end illustration")) throw new Error("un cierre de ilustración sin apertura");
  ui.push(rest);
  return { ui: ui.join("\n").replace(/\/\*[\s\S]*?\*\//g, ""), names };
}
const NAMED_COLORS = /(?<![\w-])(white|black|red|green|blue|yellow|orange|gray|grey|pink|purple|brown|navy|silver|gold|magenta|cyan)(?![\w-])/i;

/** Lo que en [css] (sin comentarios) no sale de los tokens: colores literales y fuentes que no son variables. */
function looseValues(css) {
  const found = [];
  for (const m of css.matchAll(/([a-z-]+)\s*:\s*([^;{}]+);/g)) {
    const [, prop, value] = m;
    if (prop.startsWith("--") && /^(fs|u|pw|bz)$/.test(prop.slice(2))) continue;
    if (/#[0-9a-f]{3,8}\b/i.test(value) || /\b(rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\(/i.test(value) || NAMED_COLORS.test(value)) {
      found.push(`${prop}: ${value.trim()}`);
    }
    const family = prop === "font-family" ? value : prop === "font" ? value.replace(/^.*?\/\s*[\d.]+\s+/, "") : null;
    if (family !== null && !/^\s*var\(--font-family-[a-z]+\)\s*$/.test(family) && family.trim() !== "inherit") found.push(`${prop}: ${value.trim()}`);
  }
  return found;
}

describe("CA-025-14: device.css usa colores y fuentes de los tokens; las ilustraciones van marcadas", () => {
  test("fuera de las ilustraciones marcadas, ningún color ni fuente que no salga de tokens.css", () => {
    const { ui } = splitIllustrations(CSS);
    assert.deepEqual(looseValues(ui), []);
  });

  test("las marcas de ilustración son una lista cerrada: el teléfono, el PDF, la web y el papel de calco", () => {
    assert.deepEqual(splitIllustrations(CSS).names, ILLUSTRATIONS);
  });

  test("la comprobación ve un color o una fuente sueltos fuera de las marcas", () => {
    const { ui } = splitIllustrations(`${CSS}\n.app__btn { background: #FFFFFF; }\n.x { color: white; }\n.y { font: 700 12px / 1 Arial; }\n.z { box-shadow: 0 0 0 rgba(0, 0, 0, 0.5); }\n`);
    assert.equal(looseValues(ui).length, 4);
    assert.deepEqual(looseValues(".a { font: 400 calc(var(--u) * 11) / 1.2 var(--font-family-mono); color: var(--color-ink); }"), []);
    assert.throws(() => splitIllustrations("/* @illustration phone: x */ .a{}"), /no se cierra/);
  });

  test("app-ui.js no escribe colores: solo índices de la paleta (data-note)", () => {
    assert.doesNotMatch(source("app-ui.js").replace(/\/\/.*$/gm, ""), /#[0-9a-f]{3,8}\b|rgba?\(/i);
  });

  test("cada color de nota tiene su regla con el token de la paleta clásica; cada tamaño de texto, la suya", () => {
    const clean = CSS.replace(/\/\*[\s\S]*?\*\//g, "");
    for (const n of NOTES) {
      assert.match(clean, new RegExp(`\\[data-note="${n}"\\] \\{\\s*--note: var\\(--palette-classic-${n}\\);\\s*\\}`), `data-note=${n}`);
    }
    for (const n of NOTE_SIZES) assert.match(clean, new RegExp(`\\[data-fs="${n}"\\] \\{\\s*--fs: ${n};\\s*\\}`), `data-fs=${n}`);
    for (const n of LIST_NOTES) assert.ok(NOTES.includes(n));
  });

  test("noteSize solo da los tamaños de la app (50, 40, 31 o 26)", () => {
    const seen = new Set(Array.from({ length: 300 }, (_, i) => noteSize("x".repeat(i))));
    assert.deepEqual([...seen].sort(), [...NOTE_SIZES].sort());
    assert.equal(noteSize("x".repeat(39)), 50);
    assert.equal(noteSize("x".repeat(40)), 40);
    assert.equal(noteSize("x".repeat(90)), 31);
    assert.equal(noteSize("x".repeat(160)), 26);
  });

  test("la tarea de texto y las filas del listado llevan el color y el tamaño en data-*, no en style", () => {
    const html = textTask(uiOf("es"), "Corta", { note: 3 });
    assert.match(html, /^<div class="app" data-note="3">/);
    assert.match(html, /<p class="app__text" data-fs="50">Corta<\/p>/);
    assert.match(listRow("x", { note: 4, first: true }), /^<div class="row row--first" data-note="4">/);
  });
});

// ─── Plan §2.3: `listHelp` entera cabe en el móvil de la portada ────────────────────────────────

/** El avance de Space Mono (monoespaciada) en unidades del em, leído de la fuente de la app. */
function monoAdvance() {
  const b = readFileSync(join(paths.repoRoot, "app/assets/fonts/space_mono/SpaceMono-Regular.ttf"));
  const tables = {};
  for (let i = 0; i < b.readUInt16BE(4); i++) {
    const o = 12 + 16 * i;
    tables[b.toString("latin1", o, o + 4)] = b.readUInt32BE(o + 8);
  }
  const unitsPerEm = b.readUInt16BE(tables.head + 18);
  return b.readUInt16BE(tables.hmtx) / unitsPerEm;
}
/** El valor en `--u` de [prop] en la regla de [selector] de device.css (`calc(var(--u) * N)`). */
function units(selector, prop) {
  const rule = new RegExp(`(?:^|\\})\\s*${selector.replace(".", "\\.")}\\s*\\{([^}]*)\\}`).exec(CSS.replace(/\/\*[\s\S]*?\*\//g, ""));
  assert.ok(rule, `falta la regla ${selector}`);
  const m = new RegExp(`(?:^|;)\\s*${prop}:\\s*calc\\(var\\(--u\\) \\* ([\\d.]+)\\)`).exec(rule[1]);
  assert.ok(m, `${selector} no declara ${prop} en --u`);
  return Number(m[1]);
}
/** Las líneas de [text] partidas por palabras en [chars] caracteres como mucho (como el navegador). */
function wrap(text, chars) {
  const lines = [];
  let line = "";
  for (const word of text.split(/\s+/)) {
    const next = line ? `${line} ${word}` : word;
    if (next.length <= chars || !line) line = next;
    else {
      lines.push(line);
      line = word;
    }
  }
  if (line) lines.push(line);
  return lines;
}
/** Lo que mide la ayuda del listado, en --u, y dónde empiezan las filas. */
function hintBox(text) {
  const font = /\.list__hint\s*\{[^}]*font:\s*400 calc\(var\(--u\) \* ([\d.]+)\) \/ ([\d.]+) var\(--font-family-mono\);/.exec(CSS);
  assert.ok(font, ".list__hint tiene que declarar «font: 400 calc(var(--u) * N) / L var(--font-family-mono)»");
  const [size, lineHeight] = [Number(font[1]), Number(font[2])];
  const width = 390 - units(".list__hint", "left") - units(".list__hint", "right");
  const chars = Math.floor(width / (size * monoAdvance()));
  const lines = wrap(text, chars);
  return { lines, bottom: units(".list__hint", "top") + lines.length * size * lineHeight, rowsTop: units(".list__rows", "top") };
}

describe("Plan §2.3: la ayuda del listado (listHelp) entera cabe en el móvil de la portada", () => {
  for (const lang of LANGS) {
    test(`${lang}: acaba antes de que empiecen las filas`, () => {
      const { lines, bottom, rowsTop } = hintBox(ARB[lang].listHelp);
      assert.ok(lines.length >= 2);
      assert.ok(bottom <= rowsTop, `la ayuda (${lines.length} líneas) acaba en ${bottom.toFixed(1)}u y las filas empiezan en ${rowsTop}u`);
    });
  }

  test("la comprobación ve una ayuda que no cabe", () => {
    const { bottom, rowsTop } = hintBox(`${ARB.es.listHelp} ${ARB.es.listHelp}`);
    assert.ok(bottom > rowsTop);
    assert.equal(monoAdvance(), 0.612);
  });
});

describe("CA-025-06: la mesa de luz lleva el papel de calco encima de la foto", () => {
  test("el papel va antes de la imagen (encima por z-index) y su trazo, con la misma geometría", () => {
    const html = appPhones(uiOf("es")).trace;
    const paper = html.indexOf('<div class="lightbox__paper">');
    assert.ok(paper >= 0 && paper < html.indexOf('<div class="app__media">'));
    assert.ok((html.match(/pathLength="1"/g) ?? []).length >= 10);
  });
});
