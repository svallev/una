// Accesibles e idénticas a la app (spec 023, CA-023-15): cada caso falla por separado.
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
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

const css = (w) => join(w.dist, "site.css");
const privacy = (w) => join(w.dist, "privacy/index.html");
const home = (w) => join(w.dist, "index.html");
const addCss = (rule) => (w) => edit(css(w), (t) => `${t}\n${rule}\n`);

test("CA-023-15: la web construida pasa", () => {
  assert.deepEqual(checkSite(base.paths), []);
});

describe("CA-023-15: colores, fuentes y medidas solo desde los tokens", () => {
  fails("un color hexadecimal suelto", addCss("a { color: #ff0000; }"), /valor suelto|color/i);
  fails("un color rgba suelto", addCss("p { background-color: rgba(0, 0, 0, 0.5); }"), /valor suelto|color/i);
  fails("un color con nombre", addCss("p { color: red; }"), /valor suelto|color/i);
  fails("una medida en px", addCss("p { margin: 10px; }"), /valor suelto|medida/i);
  fails("una medida en rem", addCss("p { padding: 1.5rem; }"), /valor suelto|medida/i);
  fails("una medida en ch", addCss("main { max-width: 70ch; }"), /valor suelto|medida/i);
  fails("una familia de fuente suelta", addCss("p { font-family: Arial, sans-serif; }"), /valor suelto|font-family/i);
  fails("un tamaño de letra suelto", addCss("h1 { font-size: 2rem; }"), /valor suelto|font-size|medida/i);
  fails("un grosor suelto", addCss("h1 { font-weight: 700; }"), /valor suelto|font-weight/i);
  fails("un número suelto que no es el interlineado", addCss("p { opacity: 0.5; }"), /valor suelto|opacity/i);
  fails("una variable que no existe", addCss("p { color: var(--color-inventado); }"), /--color-inventado/);
  fails("un @media (no se admiten reglas @)", addCss("@media (min-width: 40rem) { p { margin: 0; } }"), /@media|regla @/i);
});

describe("CA-023-15: contraste AA, solo con los pares de docs/design/tokens.md", () => {
  fails("texto secundario sobre línea (no está en la tabla)", addCss("p { color: var(--color-text-muted); background-color: var(--color-line); }"), /par de colores|contraste/i);
  fails("texto desactivado sobre papel (contraste bajo)", addCss("p { color: var(--color-disabled); }"), /par de colores|contraste/i);
  fails("texto blanco sobre papel (no está en la tabla)", addCss("p { color: var(--color-on-ink); background-color: var(--color-paper); }"), /par de colores|contraste/i);
  test("un par permitido pero con poco contraste (por unos tokens cambiados) falla", () => {
    const w = cloneWorld(base);
    try {
      const tokens = JSON.parse(read(w.paths.tokens));
      tokens.color.textMuted.$value = "#BBBBBB";
      const copy = join(w.dir, "tokens.json");
      writeFileSync(copy, JSON.stringify(tokens));
      w.paths.tokens = copy;
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /textMuted\/paper/.test(e) && /contraste/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });
  test("tinta sobre papel y texto secundario sobre papel sí pasan", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.siteCss, (t) => `${t}\nsmall { color: var(--color-text-muted); }\nem { color: var(--color-ink); }\n`);
      w.build();
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });
});

describe("CA-023-15: idioma, viewport, estructura", () => {
  const viewport = '<meta name="viewport" content="width=device-width, initial-scale=1">';
  fails("sin viewport", (w) => edit(privacy(w), (t) => t.replace(viewport, "")), /viewport/);
  fails("viewport con user-scalable=no", (w) => edit(privacy(w), (t) => t.replace("initial-scale=1", "initial-scale=1, user-scalable=no")), /viewport|user-scalable/);
  fails("viewport con maximum-scale", (w) => edit(home(w), (t) => t.replace("initial-scale=1", "initial-scale=1, maximum-scale=1")), /viewport|maximum-scale/);
  fails("viewport sin width=device-width", (w) => edit(home(w), (t) => t.replace("width=device-width, ", "")), /viewport/);
  fails("el <title> no es el esperado", (w) => edit(home(w), (t) => t.replace(/<title>[^<]*<\/title>/, "<title>Otra cosa</title>")), /title/);
  fails("un enlace javascript:", (w) => edit(home(w), (t) => t.replace('href="/help"', 'href="javascript:alert(1)"')), /javascript/);
  fails("un <link> que no es una hoja de estilo", (w) => edit(home(w), (t) => t.replace("</head>", '<link rel="preload" href="/site.css"></head>')), /link/);
  fails("una tercera mitad", (w) => edit(home(w), (t) => t.replace("</main>", '<section lang="fr" aria-labelledby="fr"><p>x</p></section></main>')), /section/);
  fails("una mitad sin aria-labelledby", (w) => edit(home(w), (t) => t.replace('<section lang="en" aria-labelledby="en">', '<section lang="en">')), /aria-labelledby/);
  fails("sin enlace al español en la mitad inglesa", (w) => edit(home(w), (t) => t.replace(/<p><a class="block-link" href="#es"[^]*?<\/p>\n/, "")), /#es/);
  fails("el enlace al español sin lang", (w) => edit(home(w), (t) => t.replace('href="#es" lang="es"', 'href="#es"')), /lang/);
  fails("el mismo salto de nivel en las dos mitades", (w) => edit(privacy(w), (t) => t.replaceAll("<h3>", "<h5>").replaceAll("</h3>", "</h5>")), /salta/);
  fails("un encabezado a otro nivel solo en la mitad inglesa (sin saltarse ninguno)", (w) => edit(privacy(w), (t) => {
    const i = t.indexOf('<section lang="en"');
    return t.slice(0, i) + t.slice(i).replace("<h3>", "<h2>").replace("</h3>", "</h2>");
  }), /mismo nivel|encabezados de la mitad inglesa/);
  fails("sin lang en la página", (w) => edit(privacy(w), (t) => t.replace('<html lang="es">', "<html>")), /lang/);
  fails("la mitad inglesa sin lang", (w) => edit(privacy(w), (t) => t.replace('<section lang="en" aria-labelledby="en">', '<section aria-labelledby="en">')), /lang/);
  fails("la mitad española sin lang", (w) => edit(home(w), (t) => t.replace('<section lang="es" aria-labelledby="es">', '<section aria-labelledby="es">')), /lang/);
  fails("el enlace al inglés sin lang", (w) => edit(privacy(w), (t) => t.replace('href="#en" lang="en"', 'href="#en"')), /enlace|lang/);
  fails("sin enlace al inglés", (w) => edit(home(w), (t) => t.replace(/<p><a class="block-link" href="#en"[^]*?<\/p>\n/, "")), /enlace.*#en|#en/);
  fails("el enlace al inglés va a otro sitio", (w) => edit(home(w), (t) => t.replace('href="#en"', 'href="#es"')), /enlace|#en/);
  fails("el destino del salto no existe", (w) => edit(privacy(w), (t) => t.replace('<h2 id="en"', '<h2 id="ingles"')), /id="en"|destino/);
  fails("dos <h1>", (w) => edit(privacy(w), (t) => t.replace("<h3>", "<h1>Otro</h1><h3>")), /h1/);
  fails("sin <h1>", (w) => edit(home(w), (t) => t.replace("<h1>", "<h2>").replace("</h1>", "</h2>")), /h1/);
  fails("un salto de nivel de encabezado", (w) => edit(privacy(w), (t) => t.replace("<h3>", "<h5>").replace("</h3>", "</h5>")), /salta|nivel/);
  fails("la mitad inglesa con otro desplazamiento de encabezados", (w) => edit(privacy(w), (t) => {
    const i = t.indexOf('<section lang="en"');
    const rest = t.slice(i).replace(/<h3>/g, "<h4>").replace(/<\/h3>/g, "</h4>");
    return t.slice(0, i) + rest;
  }), /salta|nivel|desplaza|encabezados/);
  fails("sin <main>", (w) => edit(home(w), (t) => t.replace("<main>", "<div>").replace("</main>", "</div>")), /main/);
  fails("sin <footer>", (w) => edit(home(w), (t) => t.replace("<footer>", "<div>").replace("</footer>", "</div>")), /footer/);
  fails("sin <header>", (w) => edit(home(w), (t) => t.replace("<header>", "<div>").replace("</header>", "</div>")), /header/);
  fails("dos <main>", (w) => edit(home(w), (t) => t.replace("</main>", "</main><main></main>")), /main/);
  fails("el título de la política no es el de la ARB", (w) => edit(privacy(w), (t) => t.replace('<span lang="es">Política de privacidad</span>', '<span lang="es">Privacidad</span>')), /ARB|título/i);
  fails("el título de la política sin sus idiomas", (w) => edit(privacy(w), (t) => t.replace('<span lang="en">Privacy policy</span>', "Privacy policy")), /ARB|título|lang/i);
  fails("sin <title>", (w) => edit(home(w), (t) => t.replace(/<title>[^<]*<\/title>/, "")), /title/);
  fails("la mitad española no va primero", (w) => edit(home(w), (t) => {
    const es = t.indexOf('<section lang="es"');
    const en = t.indexOf('<section lang="en"');
    const mainEnd = t.indexOf("</main>");
    return t.slice(0, es) + t.slice(en, mainEnd) + "\n" + t.slice(es, en) + t.slice(mainEnd);
  }), /primero|orden/);
});

describe("CA-023-15: foco, interlineado, movimiento y reflujo", () => {
  fails("se quita el anillo de foco", (w) => edit(css(w), (t) => t.replace(/[^{}\n]*:focus-visible\s*\{[^}]*\}/, "")), /focus-visible|foco/);
  fails("el foco se oculta con outline: none", addCss("a:focus-visible { outline: none; }"), /outline|foco/);
  fails("el foco se oculta con outline: 0", addCss("a:focus { outline: 0; }"), /outline|foco/);
  fails("un enlace sin subrayar", addCss("a { text-decoration: none; }"), /subray|text-decoration/);
  fails("sin subrayado en los enlaces", (w) => edit(css(w), (t) => t.replace("text-decoration: underline;", "")), /subray|underline/);
  fails("una altura fija", addCss("p { height: var(--size-button); }"), /altura|height/);
  fails("un interlineado fijo", addCss("p { line-height: var(--size-button); }"), /interlineado|line-height/);
  fails("un ancho fijo", addCss("main { width: var(--size-frame-width); }"), /ancho|width/);
  fails("un desbordamiento horizontal forzado", addCss("main { overflow-x: scroll; }"), /overflow|desplazamiento horizontal/);
  fails("una animación", addCss("a { transition: none; }"), /transition|animaci/i);
  fails("una animación con animation", addCss("a { animation-name: x; }"), /animation|animaci/i);
  fails("un movimiento suave", addCss("html { scroll-behavior: smooth; }"), /scroll-behavior|movimiento/);
  fails("una animación con @keyframes", addCss("@keyframes x { from { opacity: 1; } }"), /keyframes|regla @|animaci/i);
  fails("un <pre> sin pre-wrap", (w) => edit(css(w), (t) => t.replace(/pre\s*\{[^}]*\}/, "pre { margin: 0; }")), /pre-wrap|pre/);
  fails("un <pre> sin overflow-wrap", (w) => edit(css(w), (t) => t.replace(/overflow-wrap: anywhere;(?=[^}]*white-space: pre-wrap)/, "")), /overflow-wrap|pre/);
  fails("los enlaces de bloque sin objetivo de 44", (w) => edit(css(w), (t) => t.replace(/min-height: var\(--size-link-button\);/, "")), /44|objetivo|min-height/);
  fails("un posicionamiento fijo (tapa el foco)", addCss("header { position: sticky; top: 0; }"), /sticky|fixed|tapa|position/);
  fails("un posicionamiento fijo con fixed", addCss("footer { position: fixed; }"), /sticky|fixed|tapa|position/);
  fails("el tamaño del texto del navegador no se respeta (html con font-size)", addCss("html { font-size: var(--font-size-body); }"), /html|navegador|font-size/);

  test("el texto va en rem: ningún tamaño del CSS generado está en px", () => {
    const tokens = read(join(base.dist, "tokens.css"));
    for (const m of tokens.matchAll(/--(font-size|space|size)-[a-z0-9-]+: ([^;]+);/g)) {
      assert.ok(!/px$/.test(m[2]), `${m[0]} está en px`);
    }
  });
});
