// La política en la web (spec 023): CA-023-03 (ES y EN dicen lo mismo) y CA-023-04 (una sola fuente).
import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { comparePolicyStructure, extractPolicy, readIdentity } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { cloneWorld, edit, read, specificErrors, world } from "./support.mjs";

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

  // Desde la spec 026 (CA-026-01 y 04) la fecha ya no va en el pie: queda en su mitad, bajo el título (T-026-03).
  test("CA-026-04: la fecha sale de la propia política, en cada mitad, y ya no va en el pie", () => {
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
      assert.ok(half("es").includes("Última actualización:</strong> 3 de marzo de 2027</p>"));
      assert.ok(half("en").includes("Last updated:</strong> March 3, 2027</p>"));
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

// ─── La política y la página de inicio (spec 025, CA-025-13) ────────────────────────────────────────

/** La sección [title] (`## …`) de la mitad [half], sin el título. */
function policySection(half, title) {
  const at = half.indexOf(`\n## ${title}\n`);
  assert.ok(at >= 0, `no está la sección «${title}»`);
  const rest = half.slice(at + title.length + 5);
  const end = rest.indexOf("\n## ");
  return end < 0 ? rest : rest.slice(0, end);
}

describe("CA-025-13: la política dice la verdad sobre la página de inicio", () => {
  const halves = () => extractPolicy(policyText());
  const SECTIONS = { es: "Esta web", en: "This website" };
  const SAYS = {
    es: [
      /webs de la app\*\* \(la página de inicio, esta política, la ayuda y las licencias de terceros\)/,
      /sin cookies, sin analítica y sin recursos de otros sitios/,
      /\*\*La página de inicio usa JavaScript\*\*: un programa, servido desde la propia web, para la animación y para el idioma/,
      /GSAP y Lenis/,
      /\*\*Lo único que guarda la página de inicio es el idioma que eliges\*\*/,
      /en tu navegador .* no lo envía a ningún sitio/,
      /Esta política, la ayuda y las licencias funcionan sin JavaScript\./,
    ],
    en: [
      /app's websites\*\* \(the home page, this policy, the help and the third-party licenses\)/,
      /no cookies, no analytics and no resources from other sites/,
      /\*\*The home page uses JavaScript\*\*: a program, served from the website itself, for the animation and the language/,
      /GSAP and Lenis/,
      /\*\*The only thing the home page stores is the language you choose\*\*/,
      /in your browser .* doesn't send it anywhere/,
      /This policy, the help and the licenses work without JavaScript\./,
    ],
  };

  for (const lang of ["es", "en"]) {
    test(`«${SECTIONS[lang]}» (${lang}): programa propio, solo el idioma guardado, sin cookies ni analítica, y las otras páginas sin JavaScript`, () => {
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

  test("las dos mitades siguen con la misma estructura y «Esta web» con las mismas viñetas", () => {
    assert.deepEqual(comparePolicyStructure(policyText()), []);
    const bullets = (t) => t.split("\n").filter((l) => l.startsWith("- ")).length;
    const { es, en } = halves();
    assert.equal(bullets(policySection(es, "Esta web")), bullets(policySection(en, "This website")));
    assert.equal(bullets(policySection(es, "Esta web")), 7);
  });

  test("la fecha sigue siendo el hueco hasta F6 (CA-023-04)", () => {
    const md = policyText();
    assert.ok(md.includes("**Última actualización:** [FECHA]"));
    assert.ok(md.includes("**Last updated:** [DATE]"));
  });

  test("las notas de revisión anotan el cambio y su fuente (CA-023-02)", () => {
    const md = policyText();
    const notes = md.slice(md.indexOf("## Notas para la revisión"));
    assert.match(notes, /^18\. \*\*La página de inicio \(spec 025, CA-025-12 y 13/m);
    for (const source of ["landing/home/src/shared/locale.js", "una-lang", "landing/web-notices.txt", "ADR-0027", "landing/check.mjs"]) {
      assert.ok(notes.includes(source), `las notas no citan ${source}`);
    }
  });

  test("lo publicado en /privacy lleva el texto nuevo en los dos idiomas", () => {
    const html = read(join(base.dist, "privacy/index.html"));
    assert.ok(html.includes("<strong>La página de inicio usa JavaScript</strong>"));
    assert.ok(html.includes("<strong>The home page uses JavaScript</strong>"));
    assert.ok(!html.includes("una-lang"), "las notas de revisión no se publican");
  });
});
