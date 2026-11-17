// La construcción de la web (spec 023): CA-023-13 (páginas, dos idiomas, sin JavaScript, nombre de la
// identidad) y los huecos de identidad al publicar (plan §1.3).
import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { build, defaultPaths, DOWNLOAD_ICON_PATH, fill, loadLandingStrings, LANDING_STRING_KEYS, readIdentity, tokensCss } from "../build.mjs";
import { checkSite, mentionsName } from "../check.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";
import { iconPaths } from "../home/src/shared/icons.js";

let base;
let name;
before(() => {
  base = world();
  base.build();
  name = readIdentity(read(base.paths.identity)).displayName;
});
after(() => base.cleanup());

// Las páginas sin JavaScript. La de inicio la construye Vite desde la spec 025: sus tests, en `home-*.test.mjs`.
const pages = ["privacy/index.html", "licenses/index.html", "help/index.html", "404.html"];

describe("CA-023-13: las páginas", () => {
  test("salen las tres webs de la app y la de error, más los estilos, los avisos y las fuentes", () => {
    for (const f of [...pages, "tokens.css", "site.css", "lang.js", "third-party-notices.txt"]) {
      assert.ok(existsSync(join(base.dist, f)), `falta ${f}`);
    }
    for (const f of [
      "fonts/archivo/Archivo-Variable.ttf",
      "fonts/archivo/OFL.txt",
      "fonts/space_mono/SpaceMono-Regular.ttf",
      "fonts/space_mono/SpaceMono-Bold.ttf",
      "fonts/space_mono/OFL.txt",
    ]) {
      assert.ok(existsSync(join(base.dist, f)), `falta ${f}`);
    }
  });

  // Desde la spec 026 (CA-026-09) el enlace al otro idioma es el selector ES / EN, encima del título; «Read in
  // English» y «Leer en español» desaparecen.
  test("CA-026-09: cada página tiene el español y el inglés, cada uno con su idioma, y el selector lleva a cada mitad", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f));
      assert.match(html, /<html lang="es" /, f);
      assert.match(html, /<section class="half" lang="es" data-l="es" aria-labelledby="es">/, f);
      assert.match(html, /<section class="half" lang="en" data-l="en" aria-labelledby="en">/, f);
      assert.match(html, /<h2 id="es" tabindex="-1" class="half__title">/, f);
      assert.match(html, /<h2 id="en" tabindex="-1" class="half__title">/, f);
      assert.ok(html.indexOf('data-l="es" aria-labelledby="es"') < html.indexOf('data-l="en" aria-labelledby="en"'), `${f}: primero el español`);
      assert.match(html, /<a href="#es" hreflang="es" lang="es"><span>ES<\/span><span class="vh">, Español<\/span><\/a>/, f);
      assert.match(html, /<a href="#en" hreflang="en" lang="en"><span>EN<\/span><span class="vh">, English<\/span><\/a>/, f);
      assert.ok(!/Read in English|Leer en español/.test(html), `${f}: sigue el enlace antiguo al otro idioma`);
    }
  });

  // Desde la spec 026 (CA-026-08, plan §1.2) cada página carga el programa de idioma: uno solo, clásico y síncrono,
  // en el <head> después de las dos hojas de estilo; nada escrito dentro de la página ni manejadores on….
  test("CA-026-08: un único <script src=\"/lang.js\"> en el <head>, tras las hojas de estilo, sin manejadores", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f)).replace(/<pre\b[^>]*>[\s\S]*?<\/pre>/g, " "); // los avisos de terceros son texto escapado
      assert.equal(html.match(/<script\b/gi)?.length, 1, `${f}: tiene que haber un solo <script>`);
      assert.ok(
        html.includes('<link rel="stylesheet" href="/tokens.css">\n<link rel="stylesheet" href="/site.css">\n<script src="/lang.js"></script>\n</head>'),
        `${f}: el <script> no va justo tras las hojas de estilo, al final del <head>`,
      );
      assert.ok(!/\son[a-z]+\s*=/i.test(html), `${f} tiene un manejador on…`);
    }
  });

  test("CA-026-05: la página de error está en los dos idiomas y vuelve al inicio", () => {
    const html = read(join(base.dist, "404.html"));
    assert.ok(html.includes("Esta página no existe."));
    assert.ok(html.includes("This page doesn&#39;t exist."));
    assert.ok(html.includes("Puede que la dirección esté mal escrita."));
    assert.ok(html.includes("The address may be mistyped."));
    assert.ok(html.includes('<a class="block-link" href="/">Volver al inicio</a>'));
    assert.ok(html.includes('<a class="block-link" href="/">Back to home</a>'));
  });

  test("el pie lleva el contacto en los dos idiomas (hueco de identidad hasta F6)", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f));
      assert.ok(html.includes("Contacto: [CONTACTO]"), f);
      assert.ok(html.includes("Contact: [CONTACT]"), f);
    }
  });

  test("el título del navegador lleva los dos idiomas y el nombre", () => {
    assert.match(read(join(base.dist, "privacy/index.html")), new RegExp(`<title>Política de privacidad · ${name.replace(".", "\\.")} / Privacy policy · ${name.replace(".", "\\.")}</title>`));
  });

  test("la comprobación pasa con lo construido", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  test("las páginas no pasan de 100 KB (sin las fuentes ni la de licencias, que lleva los avisos)", () => {
    for (const f of pages.filter((p) => p !== "licenses/index.html")) {
      assert.ok(readFileSync(join(base.dist, f)).length < 100_000, f);
    }
  });
});

// Spec 026, T-026-02: la estructura nueva de las cuatro páginas, sobre lo construido y sin ejecutar nada.
describe("CA-026-01, 05, 09, 12 y 16: la página nueva, sin JavaScript", () => {
  const html = (f) => read(join(base.dist, f));
  const identity = () => readIdentity(read(base.paths.identity));
  const both = (es, en, sep = " / ") => `<span lang="es" data-l="es">${es}</span><span data-l="sep">${sep}</span><span lang="en" data-l="en">${en}</span>`;
  const CURRENT = { "privacy/index.html": "/privacy", "licenses/index.html": "/licenses", "help/index.html": "/help", "404.html": null };

  test("CA-026-01: de arriba abajo: cabecera, selector, «← Volver al inicio», título, mitades y pie", () => {
    for (const f of pages) {
      const t = html(f);
      const marks = [
        '<header class="top">',
        '<div class="langs" role="group" aria-labelledby="langs-name">',
        ...(f === "404.html" ? [] : ['<a class="back" href="/">']),
        "<h1>",
        '<section class="half" lang="es"',
        '<section class="half" lang="en"',
        '<footer class="end">',
      ];
      const at = marks.map((m) => t.indexOf(m));
      assert.ok(at.every((i) => i >= 0), `${f}: falta alguna pieza (${marks.filter((_, i) => at[i] < 0).join(", ")})`);
      for (let i = 1; i < at.length; i++) assert.ok(at[i - 1] < at[i], `${f}: «${marks[i - 1]}» va después de «${marks[i]}»`);
      // Un solo «← Volver al inicio» (en la de error, el de su texto, uno por idioma).
      assert.equal(t.split('class="back"').length - 1, f === "404.html" ? 0 : 1, f);
    }
  });

  test("CA-026-01: el pie de la landing: aviso legal, Ayuda, Privacidad y Licencias en ese orden, la actual marcada, y el contacto", () => {
    for (const f of pages) {
      const footer = html(f).slice(html(f).indexOf('<footer class="end">'));
      assert.ok(footer.includes(`<p>© 2026 ${identity().displayName}</p>`), f);
      const links = [...footer.matchAll(/<a href="([^"]+)"( aria-current="page")?>/g)];
      assert.deepEqual(links.map((m) => m[1]), ["/help", "/privacy", "/licenses"], f);
      assert.deepEqual(links.filter((m) => m[2]).map((m) => m[1]), CURRENT[f] ? [CURRENT[f]] : [], f);
      assert.equal(html(f).split("aria-current").length - 1, CURRENT[f] ? 1 : 0, `${f}: aria-current fuera del pie`);
      assert.ok(footer.includes(`<a href="/help"${f === "help/index.html" ? ' aria-current="page"' : ""}>${both("Ayuda", "Help")}</a>`), f);
      assert.ok(footer.includes('<nav aria-labelledby="footer-nav">\n<span id="footer-nav" class="vh"><span class="vh" lang="es" data-l="es">Ayuda, privacidad y licencias</span><span class="vh" lang="en" data-l="en">Help, privacy and licenses</span></span>'), f);
      assert.ok(footer.includes('<p lang="es" data-l="es">Contacto: [CONTACTO]</p>\n<p lang="en" data-l="en">Contact: [CONTACT]</p>'), f);
      // La fecha y «Volver al inicio» ya no van en el pie.
      assert.ok(!/Última actualización|Last updated|Volver al inicio|Back to home/.test(footer), `${f}: el pie lleva la fecha o «Volver al inicio»`);
    }
  });

  test("CA-026-02: la cabecera lleva el logotipo (a la landing, con nombre en los dos idiomas) y «Descargar»", () => {
    for (const f of pages) {
      const t = html(f);
      const header = t.slice(t.indexOf('<header class="top">'), t.indexOf("</header>"));
      assert.ok(header.includes(`<a class="logo" href="/"><span aria-hidden="true">${identity().wordmark}</span><span class="vh" lang="es" data-l="es">${identity().displayName}, inicio</span><span class="vh" lang="en" data-l="en">${identity().displayName}, home</span></a>`), f);
      assert.ok(header.includes(`<span class="btn__label">${both("Descargar", "Download")}</span></a>`), f);
      assert.equal(header.split("<a ").length - 1, 2, `${f}: la cabecera lleva otros enlaces`);
    }
  });

  test("CA-026-16: «Descargar» lleva a la escena de cierre de la landing, con la flecha de la landing en línea", () => {
    const d = iconPaths("arrowDown");
    assert.equal(d.length, 1);
    assert.equal(DOWNLOAD_ICON_PATH, d[0]);
    for (const f of pages) {
      const t = html(f);
      assert.ok(t.includes(`<a class="btn" href="/#fin"><svg class="ic" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="${d[0]}"/></svg>`), f);
      assert.equal(t.split("<svg").length - 1, 1, `${f}: más de un <svg>`);
    }
  });

  test("CA-026-09: las piezas comunes salen en los dos idiomas, cada parte con su idioma", () => {
    const titles = {
      "privacy/index.html": ["Política de privacidad", "Privacy policy"],
      "licenses/index.html": ["Licencias de terceros", "Third-party licenses"],
      "help/index.html": ["Ayuda", "Help"],
      "404.html": ["Esta página no existe.", "This page doesn&#39;t exist."],
    };
    const name = identity().displayName;
    for (const f of pages) {
      const t = html(f);
      const [es, en] = titles[f];
      assert.ok(t.includes(`<html lang="es" data-title-es="${es} · ${name}" data-title-en="${en} · ${name}">`), f);
      assert.ok(t.includes(`<title>${es} · ${name} / ${en} · ${name}</title>`), f);
      assert.ok(t.includes(`<h1>${both(es, en, " · ")}</h1>`), f);
      assert.ok(t.includes(`<span id="langs-name" class="vh"><span class="vh" lang="es" data-l="es">Idioma</span><span class="vh" lang="en" data-l="en">Language</span></span>`), f);
      if (f !== "404.html") assert.ok(t.includes(`<p><a class="back" href="/"><span aria-hidden="true">← </span>${both("Volver al inicio", "Back to home")}</a></p>`), f);
      // Toda pieza marcada con un idioma lleva ese idioma; los separadores, ninguno.
      for (const m of t.matchAll(/<[a-z0-9]+ [^>]*data-l="([^"]+)"[^>]*>/g)) {
        if (m[1] === "sep") assert.ok(!/\slang=/.test(m[0]), `${f}: ${m[0]}`);
        else assert.ok(m[0].includes(`lang="${m[1]}"`), `${f}: ${m[0]}`);
      }
    }
  });

  test("CA-026-05: la página de error lleva cabecera, selector y pie, y en cada mitad su texto y «Volver al inicio»", () => {
    const t = html("404.html");
    for (const piece of ['<header class="top">', '<div class="langs"', '<footer class="end">']) assert.ok(t.includes(piece), piece);
    assert.ok(t.includes('<h2 id="es" tabindex="-1" class="half__title">Español</h2>\n<p>Puede que la dirección esté mal escrita.</p>\n<p><a class="block-link" href="/">Volver al inicio</a></p>\n</section>'));
    assert.ok(t.includes('<h2 id="en" tabindex="-1" class="half__title">English</h2>\n<p>The address may be mistyped.</p>\n<p><a class="block-link" href="/">Back to home</a></p>\n</section>'));
    assert.ok(t.includes('<a class="logo" href="/">'));
  });

  test("CA-026-12: licencias: los avisos una sola vez, en inglés y fuera de las mitades; el título del código de la web en los dos idiomas", () => {
    const t = html("licenses/index.html");
    const pres = [...t.matchAll(/<pre([^>]*)>/g)];
    assert.deepEqual(pres.map((m) => m[1]), [' lang="en"', ' lang="en"'], "dos <pre> (código de la web y avisos de la app), los dos en inglés");
    assert.ok(t.includes(`<h2 id="web-code">${both("Código de esta web", "Code of this website", " · ")}</h2>`));
    const enEnd = t.indexOf("</section>", t.indexOf('<section class="half" lang="en"'));
    assert.ok(t.indexOf("<pre") > enEnd, "los avisos van después de las dos mitades");
    const body = read(base.paths.notices).split("\n").slice(2).join("\n").slice(0, 40);
    assert.equal(t.split(body).length - 1, 1, "el texto de los avisos sale una sola vez");
  });
});

describe("CA-023-13: el nombre sale de la identidad", () => {
  test("otro nombre en identity.yaml cambia la web entera", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro"'));
      w.build();
      for (const f of pages) {
        // El texto de cada nodo en su línea; «Una» como artículo («Una sola tarea…») no es el nombre.
        const text = read(join(w.dist, f)).replace(/<[^>]*>/g, "\n");
        const left = text.split("\n").find((line) => mentionsName(line, name));
        assert.equal(left, undefined, `${f} sigue con el nombre anterior`);
      }
      assert.match(read(join(w.dist, "privacy/index.html")), /Zorro <strong>no recoge datos tuyos/);
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("el nombre escrito a mano en landing/src hace fallar la comprobación", () => {
    for (const value of [name, readIdentity(read(base.paths.identity)).wordmark]) {
      const w = cloneWorld(base);
      try {
        edit(w.paths.strings, (t) => t.replace("Puede que la dirección", `Sobre ${value} Puede que la dirección`));
        const errors = checkSite(w.paths);
        assert.ok(errors.some((e) => /a mano/.test(e) && /strings\.json/.test(e)), errors.join("\n"));
      } finally {
        w.cleanup();
      }
    }
  });

  test("el nombre escrito a mano en build.mjs hace fallar la comprobación", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.buildFile, (t) => `${t}\nconst oops = "${name} es el nombre";\n`);
      assert.ok(checkSite(w.paths).some((e) => /a mano/.test(e) && /build\.mjs/.test(e)));
    } finally {
      w.cleanup();
    }
  });

  test("el artículo «Una» al abrir frase y seguido de más texto no es el nombre", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.strings, (t) => t.replace("Puede que la dirección", "Una dirección mal escrita. Puede que la dirección"));
      assert.ok(!checkSite(w.paths).some((e) => /a mano/.test(e)));
    } finally {
      w.cleanup();
    }
  });

  test("la búsqueda del nombre: el artículo no cuenta, el nombre sí", () => {
    for (const line of ["Una sola tarea", "- Una tarea con foto", '    "k": "Una foto, nada más"', "Hola. Una cosa", "«Una foto»", "* Una tarea", "> Una tarea", "## Una guía corta"]) {
      assert.equal(mentionsName(line, "Una"), false, line);
    }
    for (const line of ["Una", "Una.", "Bienvenido a Una", "Abre Una para empezar", "Una: ayuda", "Hola. Abre Una", "x = \"Una es\""]) {
      assert.equal(mentionsName(line, "Una"), true, line);
    }
    assert.equal(mentionsName("Elige una. Luego", "una."), true);
    assert.equal(mentionsName("ninguna. Luego", "una."), false);
    assert.equal(mentionsName("una. Luego", "una."), true);
  });

  test("una palabra que contiene el nombre no cuenta (ninguna. termina en 'una.')", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.strings, (t) => t.replace("Puede que la dirección", "Ninguna. Puede que la dirección"));
      assert.ok(!checkSite(w.paths).some((e) => /a mano/.test(e)));
    } finally {
      w.cleanup();
    }
  });
});

describe("Plan §1.3: huecos de identidad al publicar", () => {
  test("sin VERCEL_ENV los huecos son avisos y la construcción sigue", () => {
    const w = cloneWorld(base);
    try {
      const r = w.build({});
      assert.ok(r.warnings.length >= 1);
      assert.ok(r.warnings.some((m) => m.includes("[CONTACTO]")), r.warnings.join("\n"));
      assert.ok(r.warnings.some((m) => m.includes("[RESPONSABLE]")));
      assert.ok(r.warnings.some((m) => m.includes("[FECHA]")));
    } finally {
      w.cleanup();
    }
  });

  test("en una vista previa (VERCEL_ENV=preview) también son avisos", () => {
    const w = cloneWorld(base);
    try {
      assert.ok(w.build({ VERCEL_ENV: "preview" }).warnings.length >= 1);
    } finally {
      w.cleanup();
    }
  });

  test("con VERCEL_ENV=production un hueco hace fallar y dice cuál", () => {
    const w = cloneWorld(base);
    try {
      assert.throws(() => w.build({ VERCEL_ENV: "production" }), /\[CONTACTO\]|\[RESPONSABLE\]|\[FECHA\]/);
    } finally {
      w.cleanup();
    }
  });

  test("con VERCEL_ENV=production y todos los huecos rellenos, construye", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) =>
        t
          .replaceAll("[RESPONSABLE]", "Ana Pérez")
          .replaceAll("[CONTROLLER]", "Ana Pérez")
          .replaceAll("[CONTACTO]", "[hola@ejemplo.org](mailto:hola@ejemplo.org)")
          .replaceAll("[CONTACT]", "[hola@ejemplo.org](mailto:hola@ejemplo.org)")
          .replaceAll("[FECHA]", "3 de marzo de 2027")
          .replaceAll("[DATE]", "March 3, 2027"),
      );
      edit(w.paths.strings, (t) => t.replace("[CONTACTO]", "hola@ejemplo.org").replace("[CONTACT]", "hola@ejemplo.org"));
      edit(w.paths.helpEs, (t) => t.replaceAll("[CONTACTO]", "hola@ejemplo.org"));
      edit(w.paths.helpEn, (t) => t.replaceAll("[CONTACT]", "hola@ejemplo.org"));
      const r = w.build({ VERCEL_ENV: "production" });
      assert.deepEqual(r.warnings, []);
      assert.ok(read(join(w.dist, "404.html")).includes("Contacto: hola@ejemplo.org"));
    } finally {
      w.cleanup();
    }
  });
});

describe("La construcción falla cerrada", () => {
  const breaks = (label, mutate, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        assert.throws(() => w.build(), pattern);
      } finally {
        w.cleanup();
      }
    });

  breaks("Markdown no admitido en la política (una tabla)", (w) => edit(w.paths.policy, (t) => t.replace("## Menores", "| a | b |\n|---|---|\n\n## Menores")), /tabla|no se admite/i);
  breaks("un enlace javascript: en la política", (w) => edit(w.paths.policy, (t) => t.replace("## Menores", "[x](javascript:alert(1))\n\n## Menores")), /enlace/i);
  breaks("un {otro} en la política", (w) => edit(w.paths.policy, (t) => t.replace("## Menores", "Hola {otro}\n\n## Menores")), /\{otro\}/);
  breaks("una marca [Suposición] en la parte publicada", (w) => edit(w.paths.policy, (t) => t.replace("## Menores", "Esto [Suposición] va\n\n## Menores")), /corchetes/i);
  breaks("una clave que falta en strings.json", (w) => edit(w.paths.strings, (t) => t.replace(/\s*"webBackHome": "Volver al inicio",?/, "")), /webBackHome/);
  breaks("una clave desconocida en strings.json", (w) => edit(w.paths.strings, (t) => t.replace('"webBackHome"', '"webBackHom"')), /webBackHom/);
  breaks("un marcador sin sustituir en strings.json", (w) => edit(w.paths.strings, (t) => t.replace("Volver al inicio", "Volver {allí}")), /\{allí\}/);
  breaks("sin displayName en la identidad", (w) => edit(w.paths.identity, (t) => t.replace(/displayName:.*\n/, "")), /displayName/);
  breaks("un valor sin comillas en la identidad", (w) => edit(w.paths.identity, (t) => t.replace(/wordmark: "[^"]*"/, "wordmark: una")), /wordmark|comillas/);
  breaks("una línea de la identidad que no entiende", (w) => edit(w.paths.identity, (t) => `${t}\n  algo: raro\n`), /identity\.yaml/);
  breaks("sin archivo de política", (w) => edit(w.paths.policy, () => ""), /política|policy/i);

  breaks("una clave repetida en la identidad", (w) => edit(w.paths.identity, (t) => `${t}\ndisplayName: "Otra"\n`), /repetida/);
  breaks("strings.json que no es JSON", (w) => edit(w.paths.strings, () => "{"), /no es JSON/);
  breaks("strings.json con un idioma de más", (w) => edit(w.paths.strings, (t) => t.replace(/\}\s*$/, ', "fr": {}}')), /solo «es» y «en»/);
  breaks("una clave de más en strings.json", (w) => edit(w.paths.strings, (t) => t.replace('"webLanguageName": "English"', '"webLanguageName": "English", "webExtra": "x"')), /webExtra.*no es una clave conocida/);
  breaks("las partes de la política en otro orden", (w) => edit(w.paths.policy, (t) => {
    const es = t.indexOf("# Política de privacidad (ES)");
    const en = t.indexOf("# Privacy policy (EN)");
    const notes = t.indexOf("## Notas para la revisión");
    return t.slice(0, es) + t.slice(en, notes) + t.slice(es, en) + t.slice(notes);
  }), /el orden tiene que ser/);

  test("una ARB sin el título de una fila de Ajustes falla", () => {
    const w = cloneWorld(base);
    try {
      const arb = join(w.dir, "app_es.arb");
      writeFileSync(arb, read(w.paths.arbEs).replace('"settingsHelp"', '"settingsAyuda"'));
      assert.throws(() => build({ ...w.paths, arbEs: arb }, { env: {} }), /app_es\.arb: falta «settingsHelp»/);
    } finally {
      w.cleanup();
    }
  });

  test("una ARB que no existe falla y dice cuál", () => {
    const w = cloneWorld(base);
    try {
      assert.throws(() => build({ ...w.paths, arbEn: join(w.dir, "nada.arb") }, { env: {} }), /app_en\.arb: no se puede leer/);
    } finally {
      w.cleanup();
    }
  });

  test("un marcador sin valor al rellenar un texto falla", () => {
    assert.equal(fill("a {x} b", { x: "1" }), "a 1 b");
    assert.throws(() => fill("a {y} b", { x: "1" }), /\{y\}/);
  });

  test("una carpeta de salida que no se llama dist no se borra", () => {
    const w = cloneWorld(base);
    try {
      const paths = { ...w.paths, out: join(w.dir, "src") };
      assert.throws(() => build(paths, { env: {} }), /dist/);
      assert.ok(existsSync(join(w.dir, "src/strings.json")), "se borró una carpeta que no era la salida");
    } finally {
      w.cleanup();
    }
  });

  test("una fuente que falta (OFL) hace fallar", () => {
    const w = cloneWorld(base);
    try {
      const paths = { ...w.paths, fontsDir: join(w.dir, "nada") };
      assert.throws(() => build(paths, { env: {} }), /falta la fuente .*Archivo-Variable/);
    } finally {
      w.cleanup();
    }
  });
});

describe("tokens.css sale de design/tokens.json", () => {
  const tokens = JSON.parse(readFileSync(defaultPaths().tokens, "utf8"));
  const css = tokensCss(tokens);

  test("los colores, tal cual", () => {
    assert.match(css, /--color-ink: #111111;/);
    assert.match(css, /--color-paper: #F4F1EA;/);
    assert.match(css, /--color-text-muted: #55534E;/);
  });

  test("tamaños y espacios en rem (respetan el texto del navegador)", () => {
    assert.match(css, /--font-size-body: 1\.0625rem;/);
    assert.match(css, /--space-l: 1\.5rem;/);
    assert.match(css, /--size-min-touch-target: 2\.75rem;/);
    assert.match(css, /--size-content-max-width: 37\.5rem;/);
    assert.match(css, /--size-web-content-max-width: 70rem;/);
  });

  test("bordes en px y familias de fuente", () => {
    assert.match(css, /--border-width-focus: 3px;/);
    assert.match(css, /--font-family-display: "Archivo", system-ui, sans-serif;/);
    assert.match(css, /--font-family-mono: "Space Mono", ui-monospace, monospace;/);
  });

  test("las fuentes van dentro de la web (rutas del propio sitio, font-display: swap)", () => {
    assert.match(css, /@font-face \{\n {2}font-family: "Archivo";\n {2}src: url\("\/fonts\/archivo\/Archivo-Variable\.ttf"\) format\("truetype"\);\n {2}font-weight: 400 900;\n {2}font-display: swap;\n\}/);
    assert.match(css, /font-family: "Space Mono";[^}]*SpaceMono-Regular\.ttf[^}]*font-weight: 400;/);
    assert.match(css, /font-family: "Space Mono";[^}]*SpaceMono-Bold\.ttf[^}]*font-weight: 700;/);
    assert.ok(!/https?:|\/\//.test(css.replace(/\/\*[\s\S]*?\*\//g, "")), "tokens.css apunta a otro origen");
  });

  test("no sale nada de la paleta de notas ni de las sombras", () => {
    assert.ok(!css.includes("--palette"));
    assert.ok(!css.includes("--shadow"));
  });
});

// Spec 026, T-026-01: los textos nuevos y los de la landing que usan la cabecera y el pie.
describe("CA-026-01: los textos de las páginas", () => {
  const strings = () => JSON.parse(read(base.paths.strings));
  // Solo en un idioma: el título de los avisos, en inglés («webSwitchTo*» se retiraron en T-026-02).
  const langOnly = { es: [], en: ["webNoticesTitle"] };

  test("CA-026-09: «webSwitchToSpanish» y «webSwitchToEnglish» ya no existen (los sustituye el selector)", () => {
    for (const lang of ["es", "en"]) {
      for (const key of ["webSwitchToSpanish", "webSwitchToEnglish"]) assert.ok(!(key in strings()[lang]), `${lang}.${key}`);
    }
  });


  test("CA-026-01: «webOnThisPage» en español y en inglés", () => {
    assert.equal(strings().es.webOnThisPage, "En esta página");
    assert.equal(strings().en.webOnThisPage, "On this page");
  });

  test("CA-026-01: las claves de strings.json son las mismas en ES y en EN (salvo las de un solo idioma)", () => {
    const keys = (lang) => Object.keys(strings()[lang]).filter((k) => !langOnly[lang].includes(k)).sort();
    assert.deepEqual(keys("es"), keys("en"));
  });

  const breaks = (label, mutate, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        assert.throws(() => w.build(), pattern);
      } finally {
        w.cleanup();
      }
    });
  const landingStrings = (w, lang) => join(w.paths.homeDir, "src/shared", `strings.${lang}.json`);

  breaks("CA-026-01: sin «webOnThisPage» en español, la construcción falla", (w) => edit(w.paths.strings, (t) => {
    const json = JSON.parse(t);
    delete json.es.webOnThisPage;
    return JSON.stringify(json, null, 2);
  }), /es\.webOnThisPage/);
  breaks("CA-026-01: sin «webOnThisPage» en inglés, la construcción falla", (w) => edit(w.paths.strings, (t) => {
    const json = JSON.parse(t);
    delete json.en.webOnThisPage;
    return JSON.stringify(json, null, 2);
  }), /en\.webOnThisPage/);
  breaks("CA-026-01: un marcador en «webOnThisPage» hace fallar", (w) => edit(w.paths.strings, (t) => t.replace("En esta página", "En {página}")), /\{página\}/);

  test("CA-026-01: la construcción lee de la landing la cabecera y el pie, con el nombre de la identidad", () => {
    const s = loadLandingStrings(base.paths, name);
    assert.deepEqual(s.es, {
      nav: { home: `${name}, inicio`, download: "Descargar", lang: "Idioma" },
      footer: { help: "Ayuda", privacy: "Privacidad", licenses: "Licencias", legal: `© 2026 ${name}`, nav: "Ayuda, privacidad y licencias" },
    });
    assert.deepEqual(s.en, {
      nav: { home: `${name}, home`, download: "Download", lang: "Language" },
      footer: { help: "Help", privacy: "Privacy", licenses: "Licenses", legal: `© 2026 ${name}`, nav: "Help, privacy and licenses" },
    });
  });

  test("CA-026-01: {app} se sustituye por el nombre tal cual (sin interpretar $&)", () => {
    const s = loadLandingStrings(base.paths, "A$&B$1");
    assert.equal(s.es.nav.home, "A$&B$1, inicio");
    assert.equal(s.en.footer.legal, "© 2026 A$&B$1");
  });

  test("CA-026-01: las claves que se leen son las de la cabecera y el pie", () => {
    assert.deepEqual(LANDING_STRING_KEYS, ["nav.home", "nav.download", "nav.lang", "footer.help", "footer.privacy", "footer.licenses", "footer.legal", "footer.nav"]);
  });

  for (const key of ["nav.home", "nav.download", "nav.lang", "footer.help", "footer.privacy", "footer.licenses", "footer.legal", "footer.nav"]) {
    for (const lang of ["es", "en"]) {
      breaks(`CA-026-01: sin «${key}» en strings.${lang}.json de la landing, la construcción falla`, (w) => edit(landingStrings(w, lang), (t) => {
        const json = JSON.parse(t);
        const [group, leaf] = key.split(".");
        delete json[group][leaf];
        return JSON.stringify(json, null, 2);
      }), new RegExp(`strings\\.${lang}\\.json.*${key.replace(".", "\\.")}`));
    }
  }
  breaks("CA-026-01: un texto de la landing que no es texto hace fallar", (w) => edit(landingStrings(w, "en"), (t) => t.replace('"download": "Download"', '"download": 3')), /strings\.en\.json.*nav\.download/);
  breaks("CA-026-01: un texto de la landing vacío hace fallar", (w) => edit(landingStrings(w, "es"), (t) => t.replace('"lang": "Idioma"', '"lang": "  "')), /strings\.es\.json.*nav\.lang/);
  breaks("CA-026-01: un marcador que no es {app} en un texto de la landing hace fallar", (w) => edit(landingStrings(w, "es"), (t) => t.replace("© 2026 {app}", "© {año} {app}")), /strings\.es\.json.*\{año\}/);
  breaks("CA-026-01: un archivo de textos de la landing que no es JSON hace fallar", (w) => edit(landingStrings(w, "en"), () => "{"), /strings\.en\.json.*no es JSON/);
  breaks("CA-026-01: sin el grupo «footer» en la landing, la construcción falla", (w) => edit(landingStrings(w, "es"), (t) => {
    const json = JSON.parse(t);
    delete json.footer;
    return JSON.stringify(json, null, 2);
  }), /strings\.es\.json.*footer\./);
  breaks("CA-026-09: «webSwitchToEnglish» en strings.json ya no es una clave conocida", (w) => edit(w.paths.strings, (t) => t.replace('"webOnThisPage": "On this page"', '"webOnThisPage": "On this page",\n    "webSwitchToEnglish": "Read in English"')), /webSwitchToEnglish.*no es una clave conocida/);
});

// Spec 026, T-026-06: el programa de idioma se publica tal cual y cada página no carga nada más que hoy salvo él.
describe("CA-026-13 y 15: el programa de idioma en la web", () => {
  const source = () => join(base.paths.srcDir, "lang.js");

  test("CA-026-15: dist/lang.js es el fuente tal cual (byte a byte) y no pasa de 10 KB", () => {
    const built = readFileSync(join(base.dist, "lang.js"));
    assert.ok(built.equals(readFileSync(source())), "dist/lang.js no es igual a landing/src/lang.js");
    assert.ok(built.length <= 10_240, `lang.js pesa ${built.length} bytes`);
  });

  test("CA-026-15: cada página carga /tokens.css, /site.css y /lang.js, y nada más", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f)).replace(/<pre\b[^>]*>[\s\S]*?<\/pre>/g, " ");
      const loaded = [...html.matchAll(/<(link|script)\b[^>]*\s(?:href|src)="([^"]*)"/g)].map((m) => m[2]);
      assert.deepEqual(loaded, ["/tokens.css", "/site.css", "/lang.js"], f);
      assert.ok(!/<(?:img|source|iframe|object|embed|video|audio)\b/.test(html), `${f}: carga algún medio`);
    }
  });

  test("CA-026-13: data-title-es y data-title-en salen escapados y, al leerlos, son los títulos de cada idioma", () => {
    const w = cloneWorld(base);
    try {
      // El lector de identity.yaml no admite comillas dobles en el valor: «&», «<» y «'» bastan para el escape.
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, "displayName: \"A&B <'C'>\""));
      w.build();
      const html = read(join(w.dist, "help/index.html"));
      const attr = (lang) => new RegExp(`<html lang="es" [^>]*data-title-${lang}="([^"]*)"`).exec(html)?.[1];
      const unescape = (s) => s.replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&quot;", '"').replaceAll("&#39;", "'").replaceAll("&amp;", "&");
      for (const lang of ["es", "en"]) {
        const raw = attr(lang);
        assert.ok(raw, `falta data-title-${lang}`);
        assert.ok(!/[<>']|&(?!(?:amp|lt|gt|quot|#39);)/.test(raw), `data-title-${lang} sin escapar: ${raw}`);
        assert.equal(unescape(raw), lang === "es" ? "Ayuda · A&B <'C'>" : "Help · A&B <'C'>");
      }
    } finally {
      w.cleanup();
    }
  });

  test("CA-026-13: la clave «una-lang» de lang.js no cuenta como el nombre escrito a mano (plan §6.1)", () => {
    const code = read(source());
    assert.ok(code.includes('"una-lang"'));
    assert.deepEqual(checkSite(base.paths).filter((e) => /lang\.js/.test(e)), []);
  });

  test("CA-026-13: el nombre escrito a mano en lang.js hace fallar la comprobación", () => {
    for (const value of [name, readIdentity(read(base.paths.identity)).wordmark]) {
      const w = cloneWorld(base);
      try {
        edit(join(w.paths.srcDir, "lang.js"), (t) => t.replace('"use strict";', `"use strict";\n  // Lo guarda ${value} para la landing.`));
        const errors = checkSite(w.paths);
        assert.ok(errors.some((e) => /a mano/.test(e) && /src\/lang\.js:\d+/.test(e)), errors.join("\n"));
      } finally {
        w.cleanup();
      }
    }
  });
});

// Spec 027, T-027-01: los textos del bloque de avisos agrupado por paquete (§7 de la spec) y el fragmento de
// referencia de /licenses fuera de ese bloque (CA-027-07), sacado de la construcción de `main` antes de la 027.
describe("CA-027-09: los textos de los grupos de avisos", () => {
  const strings = () => JSON.parse(read(base.paths.strings));
  const texts = {
    webNoticesCountOne: { es: "1 aviso", en: "1 notice" },
    webNoticesCountMany: { es: "{n} avisos", en: "{n} notices" },
    webNoticesSkip: { es: "Saltar la lista de avisos", en: "Skip the notices list" },
  };

  for (const [key, byLang] of Object.entries(texts)) {
    test(`CA-027-09: «${key}» en español y en inglés, con los textos de §7`, () => {
      for (const lang of ["es", "en"]) assert.equal(strings()[lang][key], byLang[lang], `${lang}.${key}`);
    });
  }

  test("CA-027-09: {n} solo va en «webNoticesCountMany» (y relleno da el número)", () => {
    for (const lang of ["es", "en"]) {
      for (const key of Object.keys(texts)) {
        assert.equal(strings()[lang][key].includes("{n}"), key === "webNoticesCountMany", `${lang}.${key}`);
      }
    }
    assert.equal(fill(strings().es.webNoticesCountMany, { n: 552 }), "552 avisos");
    assert.equal(fill(strings().en.webNoticesCountMany, { n: 552 }), "552 notices");
  });

  const breaks = (label, mutate, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        assert.throws(() => w.build(), pattern);
      } finally {
        w.cleanup();
      }
    });
  const without = (lang, key) => (w) => edit(w.paths.strings, (t) => {
    const json = JSON.parse(t);
    delete json[lang][key];
    return JSON.stringify(json, null, 2);
  });

  for (const key of Object.keys(texts)) {
    for (const lang of ["es", "en"]) {
      breaks(`CA-027-09: sin «${key}» en ${lang}, la construcción falla`, without(lang, key), new RegExp(`${lang}\\.${key}`));
    }
  }
  breaks("CA-027-09: {n} en «webNoticesCountOne» hace fallar", (w) => edit(w.paths.strings, (t) => t.replace('"1 aviso"', '"{n} aviso"')), /es\.webNoticesCountOne.*\{n\}/);
  breaks("CA-027-09: {n} en «webNoticesSkip» hace fallar", (w) => edit(w.paths.strings, (t) => t.replace('"Skip the notices list"', '"Skip the {n} notices"')), /en\.webNoticesSkip.*\{n\}/);
  breaks("CA-027-09: un marcador de más en «webNoticesCountMany» hace fallar", (w) => edit(w.paths.strings, (t) => t.replace('"{n} avisos"', '"{n} avisos de {total}"')), /es\.webNoticesCountMany.*\{total\}/);
  breaks("CA-027-09: otro marcador en vez de {n} hace fallar", (w) => edit(w.paths.strings, (t) => t.replace('"{n} notices"', '"{count} notices"')), /en\.webNoticesCountMany.*\{count\}/);
});

describe("CA-027-07 (base): el fragmento de referencia de /licenses fuera del bloque de avisos", () => {
  const reference = join(import.meta.dirname, "fixtures/027/licenses-outside-notices.html");
  const noticesSection = /<section lang="en" aria-labelledby="notices">[\s\S]*?<\/section>/g;

  test("CA-027-07: la referencia no trae el bloque de avisos y sí el resto de la página", () => {
    const ref = read(reference);
    assert.ok(!ref.includes('aria-labelledby="notices"'));
    assert.ok(!ref.includes('id="notices"'));
    for (const piece of ['aria-labelledby="web-code"', 'href="/third-party-notices.txt"', "</footer>"]) assert.ok(ref.includes(piece), piece);
  });

  // Hasta T-027-03 la página no cambia: lo que hay fuera del bloque es la referencia. Desde T-027-03 este test
  // compara con el bloque nuevo quitado (la misma `<section>`).
  test("CA-027-07: la página construida, sin el bloque de avisos, es igual a la referencia", () => {
    const html = read(join(base.dist, "licenses/index.html"));
    assert.equal(html.match(noticesSection)?.length, 1);
    assert.equal(html.replace(noticesSection, ""), read(reference));
  });
});
