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
// La página de inicio la construye Vite desde la spec 025 y tiene sus propias reglas: los casos de estas
// reglas, que eran sobre ella, van sobre la de error.
const notFound = (w) => join(w.dist, "404.html");
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

describe("CA-026-03: tinta sobre blanco (el texto del botón «Descargar»)", () => {
  test("CA-026-03: el par ink/surface pasa", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.siteCss, (t) => `${t}\n.btn { color: var(--color-ink); background-color: var(--color-surface); }\n`);
      w.build();
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });
  test("CA-026-03: ink/surface con poco contraste (por unos tokens cambiados) falla", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.siteCss, (t) => `${t}\n.btn { color: var(--color-ink); background-color: var(--color-surface); }\n`);
      const tokens = JSON.parse(read(w.paths.tokens));
      tokens.color.surface.$value = "#333333";
      const copy = join(w.dir, "tokens.json");
      writeFileSync(copy, JSON.stringify(tokens));
      w.paths.tokens = copy;
      w.build();
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /ink\/surface/.test(e) && /contraste/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });
  fails("CA-026-03: un par con blanco que no está en la tabla sigue fallando", addCss("p { color: var(--color-line); background-color: var(--color-surface); }"), /par de colores line\/surface/);
});

describe("CA-023-15: idioma, viewport, estructura", () => {
  const viewport = '<meta name="viewport" content="width=device-width, initial-scale=1">';
  fails("sin viewport", (w) => edit(privacy(w), (t) => t.replace(viewport, "")), /viewport/);
  fails("viewport con user-scalable=no", (w) => edit(privacy(w), (t) => t.replace("initial-scale=1", "initial-scale=1, user-scalable=no")), /viewport|user-scalable/);
  fails("viewport con maximum-scale", (w) => edit(notFound(w), (t) => t.replace("initial-scale=1", "initial-scale=1, maximum-scale=1")), /viewport|maximum-scale/);
  fails("viewport sin width=device-width", (w) => edit(notFound(w), (t) => t.replace("width=device-width, ", "")), /viewport/);
  fails("el <title> no es el esperado", (w) => edit(notFound(w), (t) => t.replace(/<title>[^<]*<\/title>/, "<title>Otra cosa</title>")), /title/);
  fails("un enlace javascript:", (w) => edit(notFound(w), (t) => t.replace('href="/"', 'href="javascript:alert(1)"')), /javascript/);
  fails("un <link> que no es una hoja de estilo", (w) => edit(notFound(w), (t) => t.replace("</head>", '<link rel="preload" href="/site.css"></head>')), /link/);
  fails("una tercera mitad", (w) => edit(notFound(w), (t) => t.replace("</main>", '<section lang="fr" aria-labelledby="fr"><p>x</p></section></main>')), /section/);
  fails("una mitad sin aria-labelledby", (w) => edit(notFound(w), (t) => t.replace('<section class="half" lang="en" data-l="en" aria-labelledby="en">', '<section class="half" lang="en" data-l="en">')), /aria-labelledby/);
  // Desde la spec 026 el salto al otro idioma es el selector ES / EN, encima del título (CA-026-09).
  fails("CA-026-09: sin la opción ES en el selector", (w) => edit(notFound(w), (t) => t.replace(/<a href="#es" hreflang="es"[^\n]*<\/a>\n/, "")), /selector/);
  fails("CA-026-09: la opción ES sin lang", (w) => edit(notFound(w), (t) => t.replace('href="#es" hreflang="es" lang="es"', 'href="#es" hreflang="es"')), /selector.*lang/);
  // Desde la spec 026 cada <h3> lleva su ancla y tabindex="-1" (CA-026-04).
  fails("el mismo salto de nivel en las dos mitades", (w) => edit(privacy(w), (t) => t.replace(/<h3 [^>]*>/g, "<h5>").replaceAll("</h3>", "</h5>")), /salta/);
  fails("un encabezado a otro nivel solo en la mitad inglesa (sin saltarse ninguno)", (w) => edit(privacy(w), (t) => {
    const i = t.indexOf('<section class="half" lang="en"');
    return t.slice(0, i) + t.slice(i).replace(/<h3 [^>]*>/, "<h2>").replace("</h3>", "</h2>");
  }), /mismo nivel|encabezados de la mitad inglesa/);
  fails("sin lang en la página", (w) => edit(privacy(w), (t) => t.replace('<html lang="es" ', "<html ")), /lang/);
  fails("la mitad inglesa sin lang", (w) => edit(privacy(w), (t) => t.replace('<section class="half" lang="en" data-l="en" aria-labelledby="en">', '<section class="half" aria-labelledby="en">')), /lang/);
  fails("la mitad española sin lang", (w) => edit(notFound(w), (t) => t.replace('<section class="half" lang="es" data-l="es" aria-labelledby="es">', '<section class="half" aria-labelledby="es">')), /lang/);
  fails("CA-026-09: la opción EN sin lang", (w) => edit(privacy(w), (t) => t.replace('href="#en" hreflang="en" lang="en"', 'href="#en" hreflang="en"')), /selector.*lang/);
  fails("CA-026-09: sin la opción EN en el selector", (w) => edit(notFound(w), (t) => t.replace(/<a href="#en" hreflang="en"[^\n]*<\/a>\n/, "")), /selector/);
  fails("CA-026-09: la opción EN va a otro sitio", (w) => edit(notFound(w), (t) => t.replace('href="#en"', 'href="#es"')), /selector.*#en/);
  fails("el destino del salto no existe", (w) => edit(privacy(w), (t) => t.replace('<h2 id="en"', '<h2 id="ingles"')), /id="en"|destino/);
  fails("dos <h1>", (w) => edit(privacy(w), (t) => t.replace("<h3 ", "<h1>Otro</h1><h3 ")), /h1/);
  fails("sin <h1>", (w) => edit(notFound(w), (t) => t.replace("<h1>", "<h2>").replace("</h1>", "</h2>")), /h1/);
  fails("un salto de nivel de encabezado", (w) => edit(privacy(w), (t) => t.replace(/<h3 [^>]*>/, "<h5>").replace("</h3>", "</h5>")), /salta|nivel/);
  fails("la mitad inglesa con otro desplazamiento de encabezados", (w) => edit(privacy(w), (t) => {
    const i = t.indexOf('<section class="half" lang="en"');
    const rest = t.slice(i).replace(/<h3 [^>]*>/g, "<h4>").replace(/<\/h3>/g, "</h4>");
    return t.slice(0, i) + rest;
  }), /salta|nivel|desplaza|encabezados/);
  fails("sin <main>", (w) => edit(notFound(w), (t) => t.replace("<main>", "<div>").replace("</main>", "</div>")), /main/);
  fails("sin <footer>", (w) => edit(notFound(w), (t) => t.replace('<footer class="end">', "<div>").replace("</footer>", "</div>")), /footer/);
  fails("sin <header>", (w) => edit(notFound(w), (t) => t.replace('<header class="top">', "<div>").replace("</header>", "</div>")), /header/);
  fails("dos <main>", (w) => edit(notFound(w), (t) => t.replace("</main>", "</main><main></main>")), /main/);
  fails("el título de la política no es el de la ARB", (w) => edit(privacy(w), (t) => t.replace('<span lang="es" data-l="es">Política de privacidad</span>', '<span lang="es" data-l="es">Privacidad</span>')), /ARB|título/i);
  fails("el título de la política sin sus idiomas", (w) => edit(privacy(w), (t) => t.replace('<span lang="en" data-l="en">Privacy policy</span>', "Privacy policy")), /ARB|título|lang/i);
  fails("sin <title>", (w) => edit(notFound(w), (t) => t.replace(/<title>[^<]*<\/title>/, "")), /title/);
  fails("la mitad española no va primero", (w) => edit(notFound(w), (t) => {
    const es = t.indexOf('<section class="half" lang="es"');
    const en = t.indexOf('<section class="half" lang="en"');
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

// Spec 026, T-026-02: cada regla nueva de `checkPage` (la estructura de la página, plan §2.1) con un caso que falla.
describe("CA-026-01, 05, 09 y 16: la estructura de la página (checkPage)", () => {
  const licenses = (w) => join(w.dist, "licenses/index.html");
  const help = (w) => join(w.dist, "help/index.html");
  const BACK = /<p><a class="back" href="\/">[^\n]*<\/a><\/p>\n/;
  const LANGS = /<div class="langs"[\s\S]*?<\/div>\n/;
  const SVG = /<svg [^>]*>[\s\S]*?<\/svg>/;

  // Títulos de la pestaña por idioma.
  fails("CA-026-09: el <html> sin data-title-es", (w) => edit(privacy(w), (t) => t.replace(/ data-title-es="[^"]*"/, "")), /data-title-es/);
  fails("CA-026-09: data-title-en distinto del título", (w) => edit(notFound(w), (t) => t.replace(/data-title-en="[^"]*"/, 'data-title-en="Otra cosa"')), /data-title-en no es el esperado/);

  // Cabecera y «Descargar».
  fails("CA-026-01: un tercer enlace en la cabecera", (w) => edit(help(w), (t) => t.replace("</header>", '<a href="/privacy">x</a>\n</header>')), /cabecera tiene 3 enlaces/);
  fails("CA-026-01: el logotipo no lleva a la landing", (w) => edit(privacy(w), (t) => t.replace('<a class="logo" href="/">', '<a class="logo" href="/help">')), /logotipo/);
  fails("CA-026-16: «Descargar» no lleva al cierre de la landing", (w) => edit(licenses(w), (t) => t.replace('href="/#fin"', 'href="/"')), /Descargar.*#fin/);

  // El único <svg>.
  fails("CA-026-01: un segundo <svg>", (w) => edit(notFound(w), (t) => t.replace("</footer>", '<svg aria-hidden="true" focusable="false"><path d="M0 0"/></svg>\n</footer>')), /2 <svg>/);
  fails("CA-026-01: el <svg> fuera de «Descargar»", (w) => edit(notFound(w), (t) => {
    const svg = SVG.exec(t)[0];
    return t.replace(svg, "").replace("</footer>", `${svg}\n</footer>`);
  }), /<svg> no está dentro de «Descargar»/);
  fails("CA-026-01: el <svg> sin aria-hidden", (w) => edit(privacy(w), (t) => t.replace('viewBox="0 0 24 24" aria-hidden="true"', 'viewBox="0 0 24 24"')), /aria-hidden="true"/);
  fails("CA-026-01: el <svg> sin focusable=\"false\"", (w) => edit(privacy(w), (t) => t.replace(' focusable="false"', "")), /focusable="false"/);
  fails("CA-026-01: el <svg> con otra cosa que <path d>", (w) => edit(help(w), (t) => t.replace('<path d="', '<circle r="1"/><path d="')), /solo <path d>/);
  fails("CA-026-01: un <path> del <svg> con más atributos", (w) => edit(help(w), (t) => t.replace('<path d="', '<path fill="red" d="')), /solo <path d>/);
  fails("CA-026-01: un <path> fuera del <svg>", (w) => edit(help(w), (t) => t.replace("</footer>", '<path d="M0 0"/>\n</footer>')), /<path> fuera del <svg>/);

  // El selector.
  fails("CA-026-09: el selector sin role=\"group\"", (w) => edit(privacy(w), (t) => t.replace('class="langs" role="group"', 'class="langs"')), /grupo con nombre/);
  fails("CA-026-09: dos selectores", (w) => edit(privacy(w), (t) => t.replace(LANGS, (m) => m + m.replace('id="langs-name"', 'id="langs-name-2"').replace('aria-labelledby="langs-name"', 'aria-labelledby="langs-name-2"'))), /2 selectores/);
  fails("CA-026-09: EN antes que ES en el selector", (w) => edit(privacy(w), (t) => t.replace(/(<a href="#es"[^\n]*\n)(<a href="#en"[^\n]*\n)/, "$2$1")), /selector.*en ese orden/);
  fails("CA-026-01: el selector fuera de <main>", (w) => edit(help(w), (t) => {
    const langs = LANGS.exec(t)[0];
    return t.replace(langs, "").replace("<main>\n", `${langs}<main>\n`);
  }), /dentro de <main>/);

  // Un solo «← Volver al inicio».
  fails("CA-026-01: sin «← Volver al inicio»", (w) => edit(privacy(w), (t) => t.replace(BACK, "")), /0 «← Volver al inicio»/);
  fails("CA-026-01: dos «← Volver al inicio»", (w) => edit(licenses(w), (t) => t.replace(BACK, (m) => m + m)), /2 «← Volver al inicio»/);
  fails("CA-026-01: «Volver al inicio» dentro de una mitad, además del de arriba", (w) => edit(help(w), (t) => t.replace('<h2 id="es" tabindex="-1" class="half__title">', '<p><a href="/">x</a></p>\n<h2 id="es" tabindex="-1" class="half__title">')), /mitad «es» tiene 1 enlaces/);
  fails("CA-026-05: la página de error con «← Volver al inicio» encima del título", (w) => edit(notFound(w), (t) => t.replace("<h1>", '<p><a class="back" href="/">x</a></p>\n<h1>')), /página de error no lo lleva/);
  fails("CA-026-05: la página de error sin «Volver al inicio» en una mitad", (w) => edit(notFound(w), (t) => t.replace('<p><a class="block-link" href="/">Back to home</a></p>\n', "")), /mitad «en» tiene 0 enlaces/);

  // El orden.
  fails("CA-026-01: el título antes que «← Volver al inicio»", (w) => edit(privacy(w), (t) => {
    const back = BACK.exec(t)[0];
    const h1 = /<h1>[^\n]*<\/h1>\n/.exec(t)[0];
    return t.replace(back + h1, h1 + back);
  }), /«← Volver al inicio» tiene que ir antes que el título/);
  fails("CA-026-01: «← Volver al inicio» antes que el selector", (w) => edit(help(w), (t) => {
    const back = BACK.exec(t)[0];
    const langs = LANGS.exec(t)[0];
    return t.replace(langs + back, back + langs);
  }), /el selector de idioma tiene que ir antes que «← Volver al inicio»/);

  // El pie.
  fails("CA-026-01: el pie sin <nav>", (w) => edit(privacy(w), (t) => t.replace('<nav aria-labelledby="footer-nav">', "<div>").replace("</nav>", "</div>")), /0 <nav>/);
  fails("CA-026-01: la navegación del pie sin nombre", (w) => edit(privacy(w), (t) => t.replace('<nav aria-labelledby="footer-nav">', "<nav>")), /pie no tiene nombre/);
  fails("CA-026-01: el pie con Privacidad antes que Ayuda", (w) => edit(notFound(w), (t) => t.replace(/(<a href="\/help">[^\n]*\n)(<a href="\/privacy">[^\n]*\n)/, "$2$1")), /en ese orden/);
  fails("CA-026-01: el pie sin Licencias", (w) => edit(notFound(w), (t) => t.replace(/<a href="\/licenses">[^\n]*\n/, "")), /en ese orden/);
  fails("CA-026-01: la página actual sin marcar", (w) => edit(privacy(w), (t) => t.replace(' aria-current="page"', "")), /aria-current="page" solo \/privacy/);
  fails("CA-026-01: otra página marcada como actual", (w) => edit(licenses(w), (t) => t.replace(' aria-current="page"', "").replace('<a href="/help">', '<a href="/help" aria-current="page">')), /aria-current="page" solo \/licenses/);
  fails("CA-026-05: la página de error con una página actual", (w) => edit(notFound(w), (t) => t.replace('<a href="/help">', '<a href="/help" aria-current="page">')), /ningún enlace/);
  fails("CA-026-01: aria-current fuera del pie", (w) => edit(help(w), (t) => t.replace('<a class="back" href="/">', '<a class="back" href="/" aria-current="page">')), /aria-current="page"> fuera de la navegación del pie/);

  // Las marcas de idioma.
  fails("CA-026-09: una pieza en español sin lang", (w) => edit(privacy(w), (t) => t.replace('<span lang="es" data-l="es">Descargar</span>', '<span data-l="es">Descargar</span>')), /data-l="es"> sin lang="es"/);
  fails("CA-026-09: una pieza con otro idioma en data-l", (w) => edit(privacy(w), (t) => t.replace('<span lang="en" data-l="en">Download</span>', '<span lang="en" data-l="fr">Download</span>')), /data-l="fr" no admitido/);
  fails("CA-026-09: un separador con lang", (w) => edit(help(w), (t) => t.replace('<span data-l="sep"> · </span>', '<span lang="es" data-l="sep"> · </span>')), /separador.*con lang/);
  fails("CA-026-09: un separador con etiquetas dentro", (w) => edit(help(w), (t) => t.replace('<span data-l="sep"> · </span>', '<span data-l="sep"><b> · </b></span>')), /separador.*etiquetas dentro/);
  fails("CA-026-09: una pieza en inglés sin su pareja en español", (w) => edit(notFound(w), (t) => t.replace('<span lang="es" data-l="es">Descargar</span>', "Descargar")), /pareja/);
  fails("CA-026-09: una mitad sin class=\"half\" ni data-l", (w) => edit(help(w), (t) => t.replace('<section class="half" lang="en" data-l="en" aria-labelledby="en">', '<section lang="en" aria-labelledby="en">')), /class="half" data-l="en"/);

  // Nombres por id.
  fails("CA-026-09: un id repetido", (w) => edit(privacy(w), (t) => t.replace('<span id="footer-nav"', '<span id="langs-name"')), /id «langs-name» está repetido/);
  fails("CA-026-09: aria-labelledby a un id que no existe", (w) => edit(privacy(w), (t) => t.replace('<span id="footer-nav"', '<span id="pie"')), /aria-labelledby="footer-nav"> apunta a un id que no existe/);
});

// Spec 026, T-026-04: los estilos de las páginas nuevas (plan §2.4). Cada regla nueva de `checkCss` con un caso
// que falla; los de tokens, contraste y movimiento de la 023 (arriba) siguen valiendo.
describe("CA-026-02, 03, 10 y 11: los estilos de las páginas (checkCss)", () => {
  const cut = (from, to) => (w) => edit(css(w), (t) => {
    const i = t.indexOf(from);
    const j = t.indexOf(to, i + from.length);
    assert.ok(i >= 0 && j > i, `no está «${from}» … «${to}» en site.css`);
    return t.slice(0, i) + t.slice(j + to.length);
  });
  const swap = (from, to) => (w) => edit(css(w), (t) => {
    assert.equal(t.split(from).length, 2, `«${from}» tiene que estar una sola vez en site.css`);
    return t.replace(from, to);
  });
  const HEIGHT_MEDIA = "@media (max-height: 539.98px) {";

  test("CA-026-02: la hoja publicada tiene la cabecera fija y sus dos excepciones de @media", () => {
    const text = read(css(base));
    assert.match(text, /\.top \{[^}]*position: fixed;/);
    assert.ok(text.includes(HEIGHT_MEDIA));
    assert.ok(text.includes("@media (max-width: 520px) {"));
    assert.ok(text.includes("@media (forced-colors: active) {"));
    assert.ok(!/transition|animation|@keyframes/.test(text.replace(/\/\*[\s\S]*?\*\//g, "")));
  });

  // Cabecera fija (CA-026-02).
  fails("CA-026-02: la cabecera no es fija", swap("  position: fixed;\n", "  position: absolute;\n"), /cabecera.*position: fixed/);
  fails("CA-026-02: position: fixed en otro elemento", addCss(".langs { position: fixed; }"), /position: fixed/);
  fails("CA-026-02: position: fixed dentro de un @media", addCss("@media (max-width: 520px) { .end { position: fixed; } }"), /position: fixed/);
  fails("CA-026-02: la cabecera con position: sticky", swap("  position: fixed;\n", "  position: sticky;\n"), /sticky/);
  fails("CA-026-02: la cabecera sin fondo de papel opaco", swap("  border-bottom: var(--border-width-hairline) solid var(--color-line);\n  background-color: var(--color-paper);\n", "  border-bottom: var(--border-width-hairline) solid var(--color-line);\n"), /cabecera.*papel/);
  fails("CA-026-02: la cabecera sin white-space: nowrap", swap("  background-color: var(--color-paper);\n  white-space: nowrap;\n", "  background-color: var(--color-paper);\n"), /cabecera.*nowrap/);
  fails("CA-026-02: la altura de la cabecera sin variable", swap("  min-height: var(--top-height);\n", ""), /altura de la cabecera/);
  fails("CA-026-02: scroll-padding-top con otra variable", swap("  scroll-padding-top: var(--top-height);\n", "  scroll-padding-top: var(--size-button);\n"), /scroll-padding-top.*misma variable/);
  fails("CA-026-02: sin scroll-padding-top", swap("  scroll-padding-top: var(--top-height);\n", ""), /scroll-padding-top/);
  fails("CA-026-02: el hueco del cuerpo con otra variable", swap("  padding-top: var(--top-height);\n", "  padding-top: var(--size-button);\n"), /body.*padding-top.*misma variable/);
  fails("CA-026-02: sin la excepción por altura", cut(HEIGHT_MEDIA, "\n}\n"), /max-height: 539\.98px/);
  fails("CA-026-02: la excepción por altura deja la cabecera fija", swap("    position: static;\n", "    position: relative;\n"), /539\.98px.*position: static/);
  fails("CA-026-02: la excepción por altura deja el scroll-padding-top", swap("    scroll-padding-top: 0;\n", ""), /539\.98px.*scroll-padding-top/);
  fails("CA-026-02: la excepción por altura deja el hueco del cuerpo", swap("    padding-top: 0;\n", ""), /539\.98px.*padding-top/);

  // Las dos medidas sueltas admitidas en @media, cada una solo con su valor.
  fails("CA-026-02: la excepción por altura con otro valor (540px)", swap("(max-height: 539.98px)", "(max-height: 540px)"), /@media/);
  fails("CA-026-02: la excepción por altura con otra unidad (33.75rem)", swap("(max-height: 539.98px)", "(max-height: 33.75rem)"), /@media/);
  fails("CA-026-11: la excepción de ancho con otro valor (600px)", swap("(max-width: 520px)", "(max-width: 600px)"), /@media/);
  fails("CA-026-11: la excepción de ancho como min-width", swap("(max-width: 520px)", "(min-width: 520px)"), /@media/);
  fails("CA-026-03: un @media de modo oscuro", addCss("@media (prefers-color-scheme: dark) { p { color: var(--color-ink); } }"), /@media/);
  fails("CA-026-03: un @media anidado", addCss("@media (max-width: 520px) { @media (forced-colors: active) { p { color: var(--color-ink); } } }"), /@media/);
  fails("CA-026-03: un valor suelto dentro de un @media", addCss("@media (max-width: 520px) { p { margin: 10px; } }"), /valor suelto/);
  fails("CA-026-10: una animación dentro de un @media", addCss("@media (max-width: 520px) { a { transition: none; } }"), /animaci/);

  // «Descargar» solo con su icono a 520 px o menos (CA-026-11).
  fails("CA-026-11: «Descargar» no se queda en su icono a 520 px", swap("  .btn__label {\n", "  .btn__nada {\n"), /btn__label/);
  fails("CA-026-11: el texto de «Descargar» con display: none (pierde su nombre)", swap("  .btn__label {\n    position: absolute;\n", "  .btn__label {\n    display: none;\n    position: absolute;\n"), /btn__label.*display: none/);

  // Ocultar el otro idioma (CA-026-06 y 08) y el titular de cada mitad a la vista (CA-026-10).
  fails("CA-026-08: sin ocultar la mitad inglesa", swap('html[data-lang="es"] [data-l="en"], ', ""), /ocultar/);
  fails("CA-026-08: sin ocultar los separadores", swap(', html[data-lang] [data-l="sep"]', ""), /ocultar/);
  fails("CA-026-08: las reglas de ocultar sin display: none", swap("{\n  display: none;\n}", "{\n  visibility: hidden;\n}"), /ocultar/);
  fails("CA-026-10: el titular de la mitad no se oculta a la vista", swap(", html[data-lang] .half__title {", " {"), /half__title/);
  fails("CA-026-10: el titular de la mitad con display: none", addCss("html[data-lang] .half__title { display: none; }"), /half__title.*display: none/);
  fails("CA-026-10: .vh sin recortar", swap("  clip-path: circle(0);\n  white-space: nowrap;\n}\n\n/* ── Cabecera", "  white-space: nowrap;\n}\n\n/* ── Cabecera"), /: \.vh tiene que ocultar/);
  fails("CA-026-10: .half sin position: relative", swap(".half {\n  position: relative;\n}", ".half {\n  margin: 0;\n}"), /\.half.*relative/);

  // Titulares, texto de apoyo y columna (CA-026-01 y 03).
  fails("CA-026-03: el título sin el peso más fuerte", swap("  font-weight: var(--font-weight-black);\n  letter-spacing: var(--font-letter-spacing-tighter);\n", "  font-weight: var(--font-weight-extrabold);\n  letter-spacing: var(--font-letter-spacing-tighter);\n"), /h1.*font-weight-black/);
  fails("CA-026-03: h3 sin la regla de 4 px", swap("  padding-top: var(--space-s);\n  border-top: var(--border-width-section) solid var(--color-ink);\n  font-size: var(--font-size-heading);\n", "  font-size: var(--font-size-heading);\n"), /h3.*border-width-section/);
  fails("CA-026-03: la fecha sin Space Mono", swap(".date, .meta {", ".meta {"), /\.date.*mono/);
  fails("CA-026-03: la versión de licencias sin Space Mono", swap(".date, .meta {", ".date {"), /\.meta.*mono/);
  fails("CA-026-01: la columna sin el máximo de 600 px", swap("  max-width: var(--size-content-max-width);\n", "  max-width: var(--size-frame-width);\n"), /columna|content-max-width/);
  fails("CA-026-01: el pie fuera de la columna", swap("main, .end {", "main {"), /\.end.*content-max-width/);

  // Foco, icono, 44 × 44, marcas y colores forzados (CA-026-10).
  fails("CA-026-10: sin h3:focus-visible", swap(", h3:focus-visible {", " {"), /h3:focus-visible/);
  fails("CA-026-10: el icono sin currentColor", swap("  stroke: currentColor;\n", "  stroke: var(--color-ink);\n"), /\.ic.*currentColor/);
  for (const sel of [".logo", ".btn", ".langs a", ".back", ".toc a", ".end a"]) {
    fails(`CA-026-10: «${sel}» sin objetivo de 44 × 44`, (w) => edit(css(w), (t) => {
      // Quita el selector de su regla (o la regla entera si va sola) en la que da los 44 × 44.
      const lines = t.split("\n");
      const at = lines.findIndex((l, i) => !l.startsWith(" ") && l.endsWith("{") && l.slice(0, -1).split(",").map((s) => s.trim()).includes(sel) &&
        lines.slice(i, lines.indexOf("}", i)).some((x) => x.includes("min-width: var(--size-min-touch-target)")));
      assert.ok(at >= 0, sel);
      const parts = lines[at].slice(0, -1).split(",").map((s) => s.trim()).filter((s) => s !== sel);
      lines[at] = parts.length ? `${parts.join(", ")} {` : ".nada {";
      return lines.join("\n");
    }), /44 × 44/);
  }
  fails("CA-026-10: un enlace del índice sin min-height", addCss(".toc a { min-height: 0; }"), /\.toc a.*44 × 44/);
  fails("CA-026-10: la página actual sin su línea", swap("  border-bottom: var(--border-width-strong) solid var(--color-ink);\n}\n\n/* ── Excepciones", "}\n\n/* ── Excepciones"), /página actual/);
  fails("CA-026-10: la página actual sin negrita", swap("  font-weight: var(--font-weight-bold);\n  text-decoration: none;\n", "  text-decoration: none;\n"), /página actual/);
  fails("CA-026-10: un enlace del índice sin subrayado", addCss(".toc a { text-decoration: none; }"), /subrayado/);
  fails("CA-026-10: el subrayado quitado con un selector que incluye la página actual", addCss('.end a, .end a[aria-current="page"] { text-decoration: none; }'), /subrayado/);
  fails("CA-026-07: el idioma elegido sin el peso más fuerte", swap("  font-weight: var(--font-weight-black);\n  text-decoration-thickness", "  text-decoration-thickness"), /elegido/);
  fails("CA-026-07: el idioma elegido sin el subrayado grueso", swap("  text-decoration-thickness: var(--border-width-strong);\n", ""), /elegido/);
  fails("CA-026-10: sin colores forzados", cut("@media (forced-colors: active) {", "\n}\n"), /forced-colors/);
  fails("CA-026-10: colores forzados sin el trazo del icono", swap("    stroke: CanvasText;\n", ""), /forced-colors.*\.ic/);

  // Lo que solo admite la cabecera.
  fails("CA-026-02: z-index en otro elemento", addCss(".langs { z-index: 1; }"), /z-index/);
  fails("CA-026-02: z-index alto en la cabecera", swap("  z-index: 1;\n", "  z-index: 9999;\n"), /z-index/);
  fails("CA-026-03: una variable propia fuera de html", addCss("p { --x: var(--space-m); }"), /variable propia/);
  fails("CA-026-03: una variable propia con un valor suelto", swap("--top-height: calc(var(--size-button) + var(--border-width-hairline));", "--top-height: 4rem;"), /valor suelto/);
});
