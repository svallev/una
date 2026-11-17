// La política en la web (spec 023): CA-023-03 (ES y EN dicen lo mismo) y CA-023-04 (una sola fuente).
import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { comparePolicyStructure, extractPolicy, readIdentity, sectionAnchor } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { cloneWorld, edit, idsOf, read, specificErrors, tocOf, world } from "./support.mjs";

let base;
before(() => {
  base = world();
  base.build();
});
after(() => base.cleanup());

const policyText = () => read(base.paths.policy);

describe("CA-023-03: ES y EN tienen las mismas secciones y viñetas", () => {
  test("la política real pasa", () => {
    assert.deepEqual(comparePolicyStructure(policyText()), []);
  });

  test("una viñeta de menos en una sección inglesa falla y dice cuál", () => {
    const md = policyText();
    const en = md.indexOf("# Privacy policy (EN)");
    const at = md.indexOf("- **Internet:** the app uses it", en);
    assert.ok(at > en, "no se encontró la viñeta de Internet en la parte inglesa");
    const end = md.indexOf("\n", at);
    const errors = comparePolicyStructure(md.slice(0, at) + md.slice(end + 1));
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /What permissions it uses/);
    assert.match(errors[0], /viñetas/);
  });

  test("un párrafo de más en una sección inglesa falla", () => {
    const md = policyText();
    assert.ok(md.includes("## Children\n"));
    const errors = comparePolicyStructure(md.replace("## Children\n", "## Children\n\nUn párrafo extra.\n"));
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /párrafos/);
  });

  test("un enlace de menos en una sección inglesa falla", () => {
    const md = policyText();
    const errors = comparePolicyStructure(md.replace("[its privacy policy](https://vercel.com/legal/privacy-policy)", "its privacy policy"));
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /enlaces/);
  });

  test("un hueco de identidad de menos en una sección inglesa falla", () => {
    const md = policyText();
    const errors = comparePolicyStructure(md.replace("write to [CONTACT]", "write to us"));
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /huecos/);
  });

  test("una sección que falta en la parte española falla", () => {
    const md = policyText();
    const a = md.indexOf("## Menores");
    const b = md.indexOf("## Tus derechos");
    const errors = comparePolicyStructure(md.slice(0, a) + md.slice(b));
    assert.ok(errors.length >= 1);
    assert.match(errors.join("\n"), /secciones/);
  });

  test("dos secciones intercambiadas de sitio fallan", () => {
    const md = policyText();
    const es = md.indexOf("# Política de privacidad (ES)");
    const en = md.indexOf("# Privacy policy (EN)");
    const half = md.slice(es, en);
    const a = half.indexOf("## Menores");
    const b = half.indexOf("## Tus derechos");
    const c = half.indexOf("## Cambios en esta política");
    const swapped = half.slice(0, a) + half.slice(b, c) + half.slice(a, b) + half.slice(c);
    assert.notEqual(swapped, half);
    const errors = comparePolicyStructure(md.slice(0, es) + swapped + md.slice(en));
    assert.ok(errors.length >= 1, "el cambio de orden pasó sin avisar");
  });

  test("faltan las dos partes, o sobra una: la extracción falla", () => {
    const md = policyText();
    assert.throws(() => extractPolicy(md.replace("# Privacy policy (EN)", "# Otra cosa")), /Privacy policy \(EN\)/);
    assert.throws(() => extractPolicy(md.replace("## Notas para la revisión", "## Otras")), /Notas para la revisión/);
    assert.throws(() => extractPolicy(md + "\n# Privacy policy (EN)\n"), /más de una vez|dos veces/);
  });
});

describe("CA-023-04: una sola fuente para la política", () => {
  test("lo publicado es lo de la política, sin el aviso de borrador ni las notas", () => {
    const html = read(join(base.dist, "privacy/index.html"));
    for (const fuera of [
      "Notas para la revisión",
      "No es asesoramiento jurídico",
      "[Hecho]",
      "[Suposición",
      "Estado: texto sin suposiciones",
      "{appName}",
    ]) {
      assert.ok(!html.includes(fuera), `la web publica «${fuera}»`);
    }
    assert.ok(html.includes("En pocas palabras"));
    assert.ok(html.includes("In short"));
  });

  test("el nombre sale de la identidad", () => {
    const name = readIdentity(read(base.paths.identity)).displayName;
    const html = read(join(base.dist, "privacy/index.html"));
    assert.ok(html.includes(`${name} <strong>no recoge datos tuyos</strong>`), "falta el nombre en la parte española");
    assert.ok(html.includes(`${name} <strong>doesn&#39;t collect data about you</strong>`));
  });

  test("la comprobación pasa con lo construido", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  test("una frase cambiada en dist/ falla", () => {
    const w = cloneWorld(base);
    try {
      edit(join(w.dist, "privacy/index.html"), (t) => t.replace("no recoge datos tuyos", "recoge algunos datos tuyos"));
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /pol[ií]tica/i.test(e) && /privacy\/index\.html/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });

  test("un párrafo añadido en dist/ a la parte inglesa falla", () => {
    const w = cloneWorld(base);
    try {
      edit(join(w.dist, "privacy/index.html"), (t) =>
        t.replace('<h2 id="en"', "<p>Texto extra.</p>\n<h2 id=\"en\""),
      );
      assert.ok(specificErrors(checkSite(w.paths)).some((e) => /pol[ií]tica/i.test(e)));
    } finally {
      w.cleanup();
    }
  });

  test("un cambio en la política sin reconstruir la web falla", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) => t.replace("**no recoge datos tuyos**", "**no recoge ningún dato tuyo**"));
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /pol[ií]tica/i.test(e)), errors.join("\n"));
      // Reconstruida, vuelve a pasar.
      w.build();
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("una mitad de la política que falta en dist/ falla", () => {
    const w = cloneWorld(base);
    try {
      edit(join(w.dist, "privacy/index.html"), (t) => t.replace('<section class="half" lang="en" data-l="en" aria-labelledby="en">', "<section>"));
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /no está la mitad «en» de la política/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });

  test("lo publicado tiene que ser lo que construyen las fuentes (también los estilos)", () => {
    const w = cloneWorld(base);
    try {
      assert.ok(!checkSite(w.paths).some((e) => e.includes("no coincide con lo que construye la web")));
      edit(join(w.dist, "site.css"), (t) => `${t}\n/* retocado a mano */\n`);
      const errors = checkSite(w.paths);
      assert.ok(errors.some((e) => /^site\.css: no coincide con lo que construye la web/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });

  test("un cambio en el nombre de la identidad sin reconstruir falla", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Otra"'));
      assert.ok(checkSite(w.paths).length >= 1);
      w.build();
      assert.deepEqual(checkSite(w.paths), []);
      assert.ok(read(join(w.dist, "privacy/index.html")).includes("Otra <strong>no recoge"));
    } finally {
      w.cleanup();
    }
  });

  test("la política se lee entera: un hueco de identidad se publica tal cual en testers", () => {
    const html = read(join(base.dist, "privacy/index.html"));
    assert.ok(html.includes("[RESPONSABLE]"));
    assert.ok(html.includes("[CONTROLLER]"));
  });

  // Desde la spec 026 (CA-026-01 y 04) la fecha ya no va en el pie ni en el cuerpo: va bajo el título de su mitad.
  test("CA-026-04: la fecha sale de la propia política, bajo el título de cada mitad, y ya no va en el pie", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) =>
        t.replace("**Última actualización:** [FECHA]", "**Última actualización:** 3 de marzo de 2027").replace(
          "**Last updated:** [DATE]",
          "**Last updated:** March 3, 2027",
        ),
      );
      w.build();
      const html = read(join(w.dist, "privacy/index.html"));
      const footer = html.slice(html.indexOf('<footer class="end">'));
      const half = (lang) => html.slice(html.indexOf(`<section class="half" lang="${lang}"`), html.indexOf("</section>", html.indexOf(`<section class="half" lang="${lang}"`)));
      assert.ok(half("es").includes('<p class="date">Última actualización: 3 de marzo de 2027</p>'));
      assert.ok(half("en").includes('<p class="date">Last updated: March 3, 2027</p>'));
      assert.ok(!/3 de marzo de 2027|March 3, 2027/.test(footer), "la fecha sigue en el pie");
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("sin la línea de la última actualización la construcción falla", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) => t.replace("**Last updated:** [DATE]\n", ""));
      assert.throws(() => w.build(), /Last updated|última actualización/i);
    } finally {
      w.cleanup();
    }
  });
});

test("CA-023-04: la copia de la política no existe en landing/ (una sola fuente)", () => {
  const src = readFileSync(join(base.paths.landingDir, "build.mjs"), "utf8");
  assert.ok(!src.includes("En pocas palabras"), "el texto de la política está copiado en build.mjs");
});

// ─── La política y la página de inicio (spec 025, CA-025-13; enmendado por la 026) ─────────────────────

/** La sección [title] (`## …`) de la mitad [half], sin el título. */
function policySection(half, title) {
  const at = half.indexOf(`\n## ${title}\n`);
  assert.ok(at >= 0, `no está la sección «${title}»`);
  const rest = half.slice(at + title.length + 5);
  const end = rest.indexOf("\n## ");
  return end < 0 ? rest : rest.slice(0, end);
}

describe("CA-025-13 (enmendado por CA-026-14): la política dice la verdad sobre las webs", () => {
  const halves = () => extractPolicy(policyText());
  const SECTIONS = { es: "Esta web", en: "This website" };
  // Lo que protegía CA-025-13 y sigue en vigor: la lista de webs, sin cookies ni analítica ni recursos de otros
  // sitios, el programa de la página de inicio (animación e idioma, con GSAP y Lenis) y el idioma, en el navegador.
  const SAYS = {
    es: [
      /webs de la app\*\* \(la página de inicio, esta política, la ayuda y las licencias de terceros\)/,
      /sin cookies, sin analítica y sin recursos de otros sitios/,
      /El de la página de inicio hace la animación y elige el idioma/,
      /GSAP y Lenis/,
      /en tu navegador .* no lo envía a ningún sitio/,
    ],
    en: [
      /app's websites\*\* \(the home page, this policy, the help and the third-party licenses\)/,
      /no cookies, no analytics and no resources from other sites/,
      /The home page's program does the animation and picks the language/,
      /GSAP and Lenis/,
      /in your browser .* doesn't send it anywhere/,
    ],
  };

  for (const lang of ["es", "en"]) {
    test(`«${SECTIONS[lang]}» (${lang}): programa propio en la página de inicio, idioma en el navegador, sin cookies ni analítica`, () => {
      const text = policySection(halves()[lang], SECTIONS[lang]);
      for (const re of SAYS[lang]) assert.match(text, re);
    });
  }

  test("ya no dice que todas las webs funcionan sin JavaScript (en ninguna de las dos mitades)", () => {
    const { es, en } = halves();
    assert.doesNotMatch(es, /webs funcionan[^.\n]*sin JavaScript/);
    assert.doesNotMatch(en, /websites work[^.\n]*no JavaScript/);
  });

  test("el resumen del principio también cuenta la página de inicio entre las webs", () => {
    const { es, en } = halves();
    assert.match(policySection(es, "En pocas palabras"), /\(la página de inicio, esta política, la ayuda y las licencias\)/);
    assert.match(policySection(en, "In short"), /\(the home page, this policy, the help and the licenses\)/);
  });

  test("las notas de revisión siguen anotando la página de inicio y su fuente (CA-023-02)", () => {
    const md = policyText();
    const notes = md.slice(md.indexOf("## Notas para la revisión"));
    assert.match(notes, /^18\. \*\*La página de inicio \(spec 025, CA-025-12 y 13/m);
    for (const source of ["landing/home/src/shared/locale.js", "una-lang", "landing/web-notices.txt", "ADR-0027", "landing/check.mjs"]) {
      assert.ok(notes.includes(source), `las notas no citan ${source}`);
    }
  });
});

// ─── La política y las páginas de contenido (spec 026, CA-026-14) ───────────────────────────────────

describe("CA-026-14: la política dice la verdad sobre el programa del idioma de las páginas de contenido", () => {
  const halves = () => extractPolicy(policyText());
  const SECTIONS = { es: "Esta web", en: "This website" };
  const SAYS = {
    es: [
      /\*\*Las webs usan JavaScript\*\*: programas pequeños, servidos desde la propia web, que no envían nada a nadie\./,
      /El de esta política, la ayuda, las licencias y la página de error \*\*solo elige el idioma\*\* y no lleva bibliotecas de terceros\./,
      /\*\*Lo único que guarda la web es el idioma que eliges\*\* con los botones ES y EN de cualquiera de sus páginas/,
      /Sin JavaScript, la página de inicio se ve sin animación y solo en español, y esta política, la ayuda y las licencias se leen enteras, en los dos idiomas\./,
      /\(los estilos, las fuentes, las imágenes y los programas\) está en la propia web/,
    ],
    en: [
      /\*\*The websites use JavaScript\*\*: small programs, served from the website itself, that send nothing to anyone\./,
      /The program of this policy, the help, the licenses and the error page \*\*only picks the language\*\* and includes no third-party libraries\./,
      /\*\*The only thing the website stores is the language you choose\*\* with the ES and EN buttons on any of its pages/,
      /Without JavaScript, the home page is shown without animation and only in Spanish, and this policy, the help and the licenses can be read in full, in both languages\./,
      /\(the styles, the fonts, the images and the programs\) is on the website itself/,
    ],
  };
  // La redacción de la 025, que solo hablaba de la página de inicio y decía que las otras funcionan sin JavaScript.
  const GONE = {
    es: [
      /Esta política, la ayuda y las licencias funcionan sin JavaScript/,
      /La página de inicio usa JavaScript/,
      /Lo único que guarda la página de inicio/,
      /el programa de la página de inicio\) está en la propia web/,
    ],
    en: [
      /This policy, the help and the licenses work without JavaScript/,
      /The home page uses JavaScript/,
      /The only thing the home page stores/,
      /the home page's program\) is on the website itself/,
    ],
  };

  for (const lang of ["es", "en"]) {
    test(`«${SECTIONS[lang]}» (${lang}): las frases nuevas están`, () => {
      const text = policySection(halves()[lang], SECTIONS[lang]);
      for (const re of SAYS[lang]) assert.match(text, re);
    });

    test(`(${lang}) la redacción antigua ya no está en ninguna parte de la mitad`, () => {
      const half = halves()[lang];
      for (const re of GONE[lang]) assert.doesNotMatch(half, re);
    });
  }

  test("las dos mitades siguen con la misma estructura y «Esta web» con las mismas viñetas (CA-023-03)", () => {
    assert.deepEqual(comparePolicyStructure(policyText()), []);
    const bullets = (t) => t.split("\n").filter((l) => l.startsWith("- ")).length;
    const bold = (t) => (t.match(/\*\*/g) ?? []).length;
    const { es, en } = halves();
    const esWeb = policySection(es, "Esta web");
    const enWeb = policySection(en, "This website");
    assert.equal(bullets(esWeb), bullets(enWeb));
    assert.equal(bullets(esWeb), 7);
    assert.equal(bold(esWeb), bold(enWeb), "distinto número de negritas en «Esta web» y «This website»");
  });

  test("la fecha sigue siendo el hueco hasta F6 (CA-023-04)", () => {
    const md = policyText();
    assert.ok(md.includes("**Última actualización:** [FECHA]"));
    assert.ok(md.includes("**Last updated:** [DATE]"));
  });

  test("las notas de revisión anotan el cambio y su fuente (CA-023-02)", () => {
    const md = policyText();
    const notes = md.slice(md.indexOf("## Notas para la revisión"));
    assert.match(notes, /^19\. \*\*Las páginas de contenido \(spec 026, CA-026-13 y 14/m);
    for (const source of ["landing/src/lang.js", "una-lang", "landing/vercel.json", "ADR-0028", "landing/check.mjs", "landing/test/lang.test.mjs"]) {
      assert.ok(notes.slice(notes.search(/^19\. /m)).includes(source), `la nota 19 no cita ${source}`);
    }
    assert.match(notes, /en los puntos 18 y 19/, "la nota 8 remite a los puntos 18 y 19");
  });

  test("lo publicado en /privacy lleva el texto nuevo en los dos idiomas y no las notas", () => {
    const html = read(join(base.dist, "privacy/index.html"));
    assert.ok(html.includes("<strong>Las webs usan JavaScript</strong>"));
    assert.ok(html.includes("<strong>The websites use JavaScript</strong>"));
    assert.ok(html.includes("<strong>solo elige el idioma</strong>"));
    assert.ok(html.includes("<strong>only picks the language</strong>"));
    assert.ok(!html.includes("funcionan sin JavaScript"));
    assert.ok(!html.includes("una-lang"), "las notas de revisión no se publican");
    assert.ok(!html.includes("lang.test.mjs"), "las notas de revisión no se publican");
  });
});

// ─── Índice, anclas y fecha (spec 026, CA-026-04) ────────────────────────────────────────────────────

describe("CA-026-04: índice y fecha de la política", () => {
  const page = (w = base) => read(join(w.dist, "privacy/index.html"));
  /** Los titulares `##` de la mitad [lang] de la política. */
  const titles = (lang) => [...extractPolicy(policyText())[lang].matchAll(/^## (.+)$/gm)].map((m) => m[1]);
  const NAME = { es: "En esta página", en: "On this page" };
  const DATE = { es: "Última actualización: [FECHA]", en: "Last updated: [DATE]" };

  for (const lang of ["es", "en"]) {
    test(`(${lang}) un enlace por sección, en orden, a un ancla única que existe`, () => {
      const html = page();
      const toc = tocOf(html, lang);
      assert.equal(toc.navCount, 1, "tiene que haber un índice por mitad");
      assert.equal(toc.sections.length, titles(lang).length);
      assert.deepEqual(toc.links.map((l) => l.text), toc.sections.map((h) => h.text));
      assert.deepEqual(toc.links.map((l) => l.href), toc.sections.map((h) => `#${h.id}`));
      const ids = idsOf(html);
      for (const h of toc.sections) {
        assert.ok(h.id.startsWith(`${lang}-`), `${h.id}: sin el prefijo del idioma`);
        assert.equal(ids.filter((i) => i === h.id).length, 1, `${h.id}: no es único`);
        assert.equal(h.tabindex, "-1", `${h.id}: sin tabindex="-1" (el foco va a la sección)`);
      }
      assert.deepEqual(toc.sections.map((h) => h.id), titles(lang).map((t) => sectionAnchor(lang, t)));
    });

    test(`(${lang}) el índice se llama «${NAME[lang]}» (no es un encabezado) y va tras la fecha, bajo el título`, () => {
      const toc = tocOf(page(), lang);
      assert.equal(toc.labelledby, `${lang}-toc`);
      assert.equal(toc.name?.[1], `${lang}-toc`);
      assert.equal(toc.name?.[2], NAME[lang]);
      assert.ok(toc.h2At >= 0 && toc.h2At < toc.dateAt, "la fecha no va bajo el título");
      assert.ok(toc.dateAt < toc.navAt, "la fecha no va antes del índice");
      assert.ok(toc.navAt < toc.firstH3At, "el índice no va antes de las secciones");
      assert.ok(toc.half.includes(`<p class="date">${DATE[lang]}</p>`), "la fecha no sale con webLastUpdated");
      assert.equal(toc.half.split('<p class="date">').length - 1, 1, "la fecha sale más de una vez");
    });
  }

  test("la línea de la fecha del Markdown sale del cuerpo", () => {
    const html = page();
    assert.ok(!html.includes("<strong>Última actualización:</strong>"));
    assert.ok(!html.includes("<strong>Last updated:</strong>"));
  });

  test("anclas que no cambian: «Quién es el responsable» y «Who is responsible»", () => {
    const ids = idsOf(page());
    assert.ok(ids.includes("es-quien-es-el-responsable"));
    assert.ok(ids.includes("en-who-is-responsible"));
    assert.ok(ids.includes("es-esta-web") && ids.includes("en-this-website"));
  });

  test("/privacy#es y /privacy#en siguen valiendo (los <h2> de las mitades)", () => {
    const ids = idsOf(page());
    assert.ok(ids.includes("es") && ids.includes("en"));
  });

  test("dos secciones con el mismo titular en una mitad hacen fallar la construcción", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) => t.replace("## Menores\n", "## Tus derechos\n"));
      assert.throws(() => w.build(), /misma ancla.*es-tus-derechos/);
    } finally {
      w.cleanup();
    }
  });

  test("la línea de la fecha repetida hace fallar la construcción", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) => t.replace("## Menores\n", "**Última actualización:** otra\n\n## Menores\n"));
      assert.throws(() => w.build(), /más de una vez/);
    } finally {
      w.cleanup();
    }
  });

  test("un titular nuevo sale en el índice sin escribirlo a mano", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) => t.replace("## Menores\n", "## Una sección nueva\n\nTexto.\n\n## Menores\n").replace("## Children\n", "## A new section\n\nText.\n\n## Children\n"));
      w.build();
      const html = read(join(w.dist, "privacy/index.html"));
      assert.ok(tocOf(html, "es").links.some((l) => l.href === "#es-una-seccion-nueva" && l.text === "Una sección nueva"));
      assert.ok(tocOf(html, "en").links.some((l) => l.href === "#en-a-new-section"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });
});

describe("CA-026-04: la comprobación del índice (cada regla con un caso que falla)", () => {
  const privacy = (w) => join(w.dist, "privacy/index.html");
  const fails = (label, mutate, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        const errors = specificErrors(checkSite(w.paths));
        assert.ok(errors.some((e) => pattern.test(e)), `no falló como se esperaba:\n${errors.join("\n")}`);
      } finally {
        w.cleanup();
      }
    });

  fails("un enlace de menos en el índice", (w) => edit(privacy(w), (t) => t.replace(/<li><a href="#es-menores">[^<]*<\/a><\/li>\n/, "")), /índice.*«es»/);
  fails("dos enlaces del índice cambiados de orden", (w) => edit(privacy(w), (t) => t.replace(/(<li><a href="#en-children">[^<]*<\/a><\/li>)\n(<li><a href="#en-your-rights">[^<]*<\/a><\/li>)/, "$2\n$1")), /índice.*«en»/);
  fails("un enlace que apunta a un id que no existe", (w) => edit(privacy(w), (t) => t.replace('href="#es-menores"', 'href="#es-nada"')), /#es-nada.*no existe/);
  fails("sin índice en una mitad", (w) => edit(privacy(w), (t) => t.replace(/<nav class="toc" aria-labelledby="en-toc">[\s\S]*?<\/nav>\n/, "")), /mitad «en» tiene 0 índices/);
  fails("el índice sin su nombre", (w) => edit(privacy(w), (t) => t.replace('aria-labelledby="es-toc"', 'aria-labelledby="es"')), /índice.*«es».*nombre|aria-labelledby/);
  fails("una sección sin tabindex=\"-1\"", (w) => edit(privacy(w), (t) => t.replace('<h3 id="es-menores" tabindex="-1">', '<h3 id="es-menores">')), /tabindex/);
  fails("una sección sin el prefijo de su idioma", (w) => edit(privacy(w), (t) => t.replaceAll('es-menores"', 'menores"')), /prefijo|«es-»/);
  fails("la fecha después del índice", (w) => edit(privacy(w), (t) => {
    const date = /<p class="date">[^<]*<\/p>\n/.exec(t.slice(t.indexOf('<section class="half" lang="es"')))[0];
    const without = t.replace(date, "");
    return without.replace('<h3 id="es-', `${date}<h3 id="es-`);
  }), /fecha/);
  fails("sin fecha en una mitad de la política", (w) => edit(privacy(w), (t) => t.replace(/<p class="date">Last updated[^<]*<\/p>\n/, "")), /fecha/);
  fails("un tabindex que no es -1", (w) => edit(privacy(w), (t) => t.replace('<a class="logo" href="/">', '<a class="logo" href="/" tabindex="0">')), /tabindex/);
});
