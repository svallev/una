// La construcción de la web (spec 023): CA-023-13 (páginas, dos idiomas, sin JavaScript, nombre de la
// identidad) y los huecos de identidad al publicar (plan §1.3).
import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { build, defaultPaths, fill, readIdentity, tokensCss } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

let base;
let name;
before(() => {
  base = world();
  base.build();
  name = readIdentity(read(base.paths.identity)).displayName;
});
after(() => base.cleanup());

const pages = ["index.html", "privacy/index.html", "404.html"];

describe("CA-023-13: las páginas", () => {
  test("salen la de inicio, la política y la de error, más los estilos y las fuentes", () => {
    for (const f of [...pages, "tokens.css", "site.css"]) {
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

  test("cada página tiene el español y el inglés, cada uno con su idioma y el enlace al otro", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f));
      assert.match(html, /<html lang="es">/, f);
      assert.match(html, /<section lang="es" aria-labelledby="es">/, f);
      assert.match(html, /<section lang="en" aria-labelledby="en">/, f);
      assert.match(html, /<h2 id="es" tabindex="-1">/, f);
      assert.match(html, /<h2 id="en" tabindex="-1">/, f);
      assert.ok(html.indexOf('lang="es" aria-labelledby') < html.indexOf('lang="en" aria-labelledby'), `${f}: primero el español`);
      assert.match(html, /<a class="block-link" href="#en" lang="en">Read in English<\/a>/, f);
      assert.match(html, /<a class="block-link" href="#es" lang="es">Leer en español<\/a>/, f);
    }
  });

  test("ninguna página lleva JavaScript", () => {
    for (const f of pages) {
      const html = read(join(base.dist, f));
      assert.ok(!/<script/i.test(html), `${f} tiene <script>`);
      assert.ok(!/\son[a-z]+\s*=/i.test(html), `${f} tiene un manejador on…`);
    }
  });

  test("la página de inicio enlaza a las tres webs con los títulos de las ARB", () => {
    const html = read(join(base.dist, "index.html"));
    for (const [href, es, en] of [
      ["/privacy", "Política de privacidad", "Privacy policy"],
      ["/licenses", "Licencias de terceros", "Third-party licenses"],
      ["/help", "Ayuda", "Help"],
    ]) {
      assert.ok(html.includes(`<a class="block-link" href="${href}">${es}</a>`), `falta el enlace en español a ${href}`);
      assert.ok(html.includes(`<a class="block-link" href="${href}">${en}</a>`), `falta el enlace en inglés a ${href}`);
    }
  });

  test("la página de error está en los dos idiomas y vuelve al inicio", () => {
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
    assert.match(read(join(base.dist, "index.html")), new RegExp(`<title>${name.replace(".", "\\.")}</title>`));
  });

  test("la comprobación pasa con lo construido", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  test("las páginas no pasan de 100 KB (sin las fuentes)", () => {
    for (const f of pages) {
      assert.ok(readFileSync(join(base.dist, f)).length < 100_000, f);
    }
  });
});

describe("CA-023-13: el nombre sale de la identidad", () => {
  test("otro nombre en identity.yaml cambia la web entera", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.identity, (t) => t.replace(/displayName: "[^"]*"/, 'displayName: "Zorro"'));
      w.build();
      for (const f of pages) {
        const html = read(join(w.dist, f));
        assert.ok(!html.includes(name), `${f} sigue con el nombre anterior`);
      }
      assert.match(read(join(w.dist, "index.html")), /<h1>Zorro<\/h1>/);
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
        edit(w.paths.strings, (t) => t.replace("Puede que la dirección", `${value} Puede que la dirección`));
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
      const r = w.build({ VERCEL_ENV: "production" });
      assert.deepEqual(r.warnings, []);
      assert.ok(read(join(w.dist, "index.html")).includes("Contacto: hola@ejemplo.org"));
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
