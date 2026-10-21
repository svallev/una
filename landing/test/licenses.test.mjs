// Licencias de terceros en la web (spec 023): CA-023-16. Cada regla con un caso que falla.
import assert from "node:assert/strict";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { build, defaultPaths, parseNotices } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { HEADER_BUILD, HEADER_VERSION, cloneWorld, edit, fakeNotices, read, specificErrors, world } from "./support.mjs";

let base;
before(() => {
  base = world();
  base.build();
});
after(() => base.cleanup());

const licenses = (w) => join(w.dist, "licenses/index.html");

/** Una copia con [text] como archivo de avisos, ya construida. */
function withNotices(text, env = {}) {
  const w = cloneWorld(base);
  writeFileSync(w.paths.notices, text);
  const result = w.build(env);
  return { w, result };
}

describe("CA-023-16: el archivo de avisos del repositorio", () => {
  const real = defaultPaths().notices;

  test("existe y empieza por una cabecera válida (la compilación de main o una versión)", () => {
    assert.ok(existsSync(real), "falta landing/third-party-notices.txt");
    const parsed = parseNotices(readFileSync(real, "utf8"));
    assert.ok(["build", "version"].includes(parsed.kind));
    if (parsed.kind === "build") {
      assert.match(parsed.sha, /^[0123456789abcdef]{40}$/);
      assert.match(parsed.runId, /^\d+$/);
    }
  });

  test("el cuerpo es el archivo que emite tools/check-licenses.sh (cabecera, sha256 y entradas)", () => {
    const { body } = parseNotices(readFileSync(real, "utf8"));
    assert.match(body, /^Third-party notices\r?\nVersion: \S+\r?\nGenerated \(UTC\): \d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\r?\n/);
    assert.match(body, /^APK: \S+ sha256 [0123456789abcdef]{64}$/m);
    assert.match(body, /^===== BEGIN NOTICES =====$/m);
    assert.match(body, /^===== END NOTICES =====$/m);
  });

  test("no lleva rutas de una carpeta personal ni caracteres de dirección o de control", () => {
    const text = readFileSync(real, "utf8");
    assert.ok(!/\/Users\/|\/home\//.test(text), "lleva una ruta personal");
    const bad = [...text].filter((c) => {
      const n = c.codePointAt(0);
      return (n < 32 && c !== "\n" && c !== "\r" && c !== "\t") || n === 127 || (n >= 0x202a && n <= 0x202e) || (n >= 0x2066 && n <= 0x2069) || n === 0x200e || n === 0x200f || n === 0x2028 || n === 0x2029;
    });
    assert.deepEqual(bad, []);
  });
});

describe("CA-023-16: la cabecera", () => {
  test("una versión: «Versión: X.Y.Z+N»", () => {
    const p = parseNotices(fakeNotices(HEADER_VERSION));
    assert.equal(p.kind, "version");
    assert.equal(p.version, "1.2.3+4");
    assert.match(p.body, /^Third-party notices/);
  });

  test("la compilación de main: sha de 40 cifras y número de ejecución", () => {
    const p = parseNotices(fakeNotices(HEADER_BUILD));
    assert.equal(p.kind, "build");
    assert.equal(p.sha, "2e835cf9e1d8e1c7e203c90426f28f66e7ba4181");
    assert.equal(p.runId, "38874734623");
  });

  const rejects = (label, text, pattern) =>
    test(`falla: ${label}`, () => assert.throws(() => parseNotices(text), pattern));

  rejects("vacío", "", /está vacío/);
  rejects("sin cabecera (empieza por el archivo)", "Third-party notices\nVersion: 0.1.0+1\n", /cabecera/);
  rejects("versión sin build (X.Y.Z)", fakeNotices("Versión: 1.2.3"), /cabecera/);
  rejects("versión con texto de más", fakeNotices("Versión: 1.2.3+4 beta"), /cabecera/);
  rejects("sha corto", fakeNotices(HEADER_BUILD.replace("2e835cf9e1d8e1c7e203c90426f28f66e7ba4181", "2e835cf")), /cabecera/);
  rejects("sha con mayúsculas", fakeNotices(HEADER_BUILD.replace("2e835cf9", "2E835CF9")), /cabecera/);
  rejects("sin número de ejecución", fakeNotices(HEADER_BUILD.replace(/ejecución \d+/, "ejecución ")), /cabecera/);
  rejects("el nombre de otra rama", fakeNotices(HEADER_BUILD.replace("de main", "de otra")), /cabecera/);
  rejects("otro modo de publicación", fakeNotices(HEADER_BUILD.replace("modo testers", "modo estricto")), /cabecera/);
  rejects("sin línea en blanco tras la cabecera", `${HEADER_VERSION}\nThird-party notices\n`, /línea en blanco/);
  rejects("cuerpo vacío", `${HEADER_VERSION}\n\n`, /sin cuerpo/);
  rejects("el cuerpo no es un archivo de avisos", fakeNotices(HEADER_VERSION, "Otra cosa\n"), /Third-party notices/);
  rejects("una cabecera con retorno de carro", `${HEADER_VERSION}\r\n\r\nThird-party notices\n`, /cabecera/);
});

describe("CA-023-16: la página de licencias", () => {
  test("con versión, dice de qué versión es, en español y en inglés", () => {
    const { w } = withNotices(fakeNotices(HEADER_VERSION));
    try {
      const html = read(licenses(w));
      assert.ok(html.includes("Avisos de la versión 1.2.3+4"));
      assert.ok(html.includes("Notices for version 1.2.3+4"));
      assert.ok(!html.includes("Aún no hay ninguna versión publicada"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("sin versión, dice que son los de la última compilación (CL-023-11)", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD));
    try {
      const html = read(licenses(w));
      assert.ok(html.includes("Aún no hay ninguna versión publicada: estos son los avisos de la última compilación."));
      assert.ok(html.includes("No version has been published yet: these are the notices of the latest build."));
      assert.ok(!html.includes("Avisos de la versión"));
      assert.ok(!html.includes("Notices for version"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("explica que los textos de las licencias van también dentro de la app, en los dos idiomas", () => {
    const html = read(licenses(base));
    assert.ok(html.includes("Los textos completos de las licencias también van dentro de la app."));
    assert.ok(html.includes("The full license texts are also included in the app."));
  });

  test("tiene las dos mitades y, después, el bloque de avisos en inglés, una sola vez", () => {
    const marker = "AVISO-UNICO-DE-PRUEBA";
    const { w } = withNotices(fakeNotices(HEADER_BUILD, `Third-party notices\n${marker}\n`));
    try {
      const html = read(licenses(w));
      const es = html.indexOf('<section lang="es" aria-labelledby="es">');
      const en = html.indexOf('<section lang="en" aria-labelledby="en">');
      const notices = html.indexOf('<section lang="en" aria-labelledby="notices">');
      assert.ok(es >= 0 && en > es && notices > en, "orden: español, inglés y avisos");
      assert.equal(html.split(marker).length - 1, 1, "los avisos se publican una sola vez");
      assert.ok(html.indexOf(marker) > notices);
      assert.match(html, /<h2 id="notices">[^<]+<\/h2>\n<pre>Third-party notices\n/);
      assert.equal(html.split('<section ').length - 1, 3);
    } finally {
      w.cleanup();
    }
  });

  test("las dos mitades enlazan al archivo de texto y la web lo publica tal cual", () => {
    const html = read(licenses(base));
    assert.equal(html.split('href="/third-party-notices.txt"').length - 1, 2);
    assert.equal(read(join(base.dist, "third-party-notices.txt")), read(base.paths.notices));
  });

  test("el <pre> escapa el HTML de los avisos", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, 'Third-party notices\n<script>alert("x")</script> & más\n'));
    try {
      const html = read(licenses(w));
      assert.ok(!html.includes("<script>"));
      assert.ok(html.includes("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; más"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("los saltos de línea de Windows del archivo no pasan al HTML", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, "Third-party notices\r\nlínea 2\r\n"));
    try {
      assert.ok(!read(licenses(w)).includes("\r"));
    } finally {
      w.cleanup();
    }
  });

  test("un texto de licencia con «[DATE]» o «[WEBSITE]» no es un hueco de identidad", () => {
    const { w, result } = withNotices(fakeNotices(HEADER_BUILD, "Third-party notices\nCopyright [DATE] [WEBSITE] [WEB]\n"));
    try {
      const own = result.warnings.filter((m) => m.includes("licenses/index.html"));
      assert.ok(own.length >= 1, "el pie de la página sí lleva el hueco del contacto");
      assert.ok(!own.some((m) => /\[(DATE|WEBSITE|WEB)\]/.test(m)), own.join("\n"));
    } finally {
      w.cleanup();
    }
  });

  test("palabras de analítica dentro de una licencia no hacen fallar la comprobación", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, "Third-party notices\nIt is plausible that gtag( and matomo and _vercel/ appear in a text.\n"));
    try {
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("la página de inicio ya enlazaba a /licenses: ahora existe", () => {
    assert.ok(read(join(base.dist, "index.html")).includes('href="/licenses"'));
    assert.ok(existsSync(licenses(base)));
  });

  test("el título es el de la fila de Ajustes", () => {
    const html = read(licenses(base));
    assert.ok(html.includes('<h1><span lang="es">Licencias de terceros</span> · <span lang="en">Third-party licenses</span></h1>'));
    assert.match(html, /<title>Licencias de terceros · .+ \/ Third-party licenses · .+<\/title>/);
  });
});

describe("CA-023-16: sin archivo o con uno malo, la construcción falla", () => {
  const breaks = (label, mutate, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        assert.throws(() => build(w.paths, { env: {} }), pattern);
      } finally {
        w.cleanup();
      }
    });

  breaks("sin archivo de avisos", (w) => rmSync(w.paths.notices), /third-party-notices\.txt: no se puede leer/);
  breaks("con un archivo vacío", (w) => writeFileSync(w.paths.notices, ""), /third-party-notices\.txt/);
  breaks("con el artefacto tal cual, sin cabecera", (w) => edit(w.paths.notices, (t) => t.slice(t.indexOf("Third-party notices"))), /cabecera/);
  breaks("con una cabecera mal formada", (w) => edit(w.paths.notices, (t) => t.replace(/^[^\n]*/, "Versión: 1")), /cabecera/);
  breaks("sin los textos de las licencias en strings.json", (w) => edit(w.paths.strings, (t) => t.replace('"webLicensesInApp": "Los textos completos de las licencias también van dentro de la app.",', "")), /webLicensesInApp/);
  breaks("sin el texto del enlace al archivo", (w) => edit(w.paths.strings, (t) => t.replace(/\s*"webLicensesFile": "[^"]*",?/, "")), /webLicensesFile/);
});

describe("CA-023-16: la comprobación de la web", () => {
  const fails = (label, mutate, pattern) =>
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

  test("lo construido con el archivo real pasa", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  fails("falta la página de licencias", (w) => rmSync(licenses(w)), /licenses\/index\.html/);
  fails("falta el archivo de avisos publicado", (w) => rmSync(join(w.dist, "third-party-notices.txt")), /third-party-notices\.txt/);
  fails("el bloque de avisos sin lang=\"en\"", (w) => edit(licenses(w), (t) => t.replace('<section lang="en" aria-labelledby="notices">', '<section aria-labelledby="notices">')), /avisos|lang/);
  fails("el bloque de avisos con lang=\"es\"", (w) => edit(licenses(w), (t) => t.replace('<section lang="en" aria-labelledby="notices">', '<section lang="es" aria-labelledby="notices">')), /avisos|lang/);
  fails("el bloque de avisos sin su <h2>", (w) => edit(licenses(w), (t) => t.replace('<h2 id="notices">', '<h3 id="notices">').replace(/<\/h2>\n<pre>/, "</h3>\n<pre>")), /avisos|h2|salta/);
  fails("el bloque de avisos sin <pre>", (w) => edit(licenses(w), (t) => t.replace("<pre>", "<div>").replace("</pre>", "</div>")), /<pre>|avisos/);
  fails("el bloque de avisos sin aria-labelledby", (w) => edit(licenses(w), (t) => t.replace('<section lang="en" aria-labelledby="notices">', '<section lang="en">')), /aria-labelledby|avisos/);
  fails("una tercera mitad que no es de avisos", (w) => edit(licenses(w), (t) => t.replace("</main>", '<section lang="fr" aria-labelledby="fr"><p>x</p></section></main>')), /section|avisos/);
  fails("el bloque de avisos antes de las mitades", (w) => edit(licenses(w), (t) => {
    const a = t.indexOf('<section lang="es"');
    const n = t.indexOf('<section lang="en" aria-labelledby="notices">');
    const end = t.indexOf("</main>");
    return t.slice(0, a) + t.slice(n, end) + "\n" + t.slice(a, n) + t.slice(end);
  }), /avisos|orden|primero/);
  test("los avisos publicados no son los del archivo: falla", () => {
    const w = cloneWorld(base);
    try {
      edit(join(w.dist, "third-party-notices.txt"), (t) => `${t}\nlínea de más\n`);
      const errors = checkSite(w.paths);
      assert.ok(errors.some((e) => /^third-party-notices\.txt: no coincide/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });
  test("los avisos del bloque de la página no son los del archivo: falla", () => {
    const w = cloneWorld(base);
    try {
      edit(licenses(w), (t) => t.replace("</pre>", "texto añadido</pre>"));
      const errors = checkSite(w.paths);
      assert.ok(errors.some((e) => /^licenses\/index\.html: no coincide/.test(e)), errors.join("\n"));
    } finally {
      w.cleanup();
    }
  });
  fails("un <script> en un aviso sin escapar", (w) => edit(licenses(w), (t) => t.replace("<pre>", "<pre><script>1</script>")), /script/);
  fails("la cabecera del archivo con otro formato", (w) => edit(w.paths.notices, (t) => t.replace(/^[^\n]*/, "Versión: x")), /cabecera/);
});
