// Licencias de terceros en la web (spec 023): CA-023-16. Cada regla con un caso que falla.
import assert from "node:assert/strict";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { assertNoticesRoundTrip, build, checkNoticesText, defaultPaths, parseNotices, parseNoticesBody, parseWebNotices, rebuildNoticesBody } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { HEADER_BUILD, HEADER_VERSION, cloneWorld, edit, fakeNotices, noticesBody, read, specificErrors, world } from "./support.mjs";

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

  // CA-027-05: el aviso de prueba va dentro de la estructura mínima que se reconoce (antes, un cuerpo sin marcadores).
  test("CA-026-12, CA-027-05: tiene las dos mitades, el código de esta web (spec 025) y, después, el bloque de avisos en inglés, una sola vez", () => {
    const marker = "AVISO-UNICO-DE-PRUEBA";
    const { w } = withNotices(fakeNotices(HEADER_BUILD, noticesBody(marker)));
    try {
      const html = read(licenses(w));
      const es = html.indexOf('<section class="half" lang="es" data-l="es" aria-labelledby="es">');
      const en = html.indexOf('<section class="half" lang="en" data-l="en" aria-labelledby="en">');
      const notices = html.indexOf('<section lang="en" aria-labelledby="notices">');
      const web = html.indexOf('<section aria-labelledby="web-code">');
      assert.ok(es >= 0 && en > es && web > en && notices > web, "orden: español, inglés, código de esta web y avisos");
      assert.equal(html.split(marker).length - 1, 1, "los avisos se publican una sola vez");
      assert.ok(html.indexOf(marker) > notices);
      assert.match(html, /<h2 id="notices">[^<]+<\/h2>\n<pre lang="en">Third-party notices\n/);
      assert.equal(html.split('<section ').length - 1, 4);
    } finally {
      w.cleanup();
    }
  });

  test("las dos mitades enlazan al archivo de texto y la web lo publica tal cual", () => {
    const html = read(licenses(base));
    assert.equal(html.split('href="/third-party-notices.txt"').length - 1, 2);
    assert.equal(read(join(base.dist, "third-party-notices.txt")), read(base.paths.notices));
  });

  test("CA-027-05: el <pre> escapa el HTML de los avisos", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, noticesBody('<script>alert("x")</script> & más')));
    try {
      const html = read(licenses(w));
      assert.ok(!html.includes("<script>"));
      assert.ok(html.includes("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; más"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("CA-027-05: los saltos de línea de Windows del archivo no pasan al HTML", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, noticesBody("línea 1\nlínea 2").replaceAll("\n", "\r\n")));
    try {
      assert.ok(!read(licenses(w)).includes("\r"));
    } finally {
      w.cleanup();
    }
  });

  test("CA-027-05: un texto de licencia con «[DATE]» o «[WEBSITE]» no es un hueco de identidad", () => {
    const { w, result } = withNotices(fakeNotices(HEADER_BUILD, noticesBody("Copyright [DATE] [WEBSITE] [WEB]")));
    try {
      const own = result.warnings.filter((m) => m.includes("licenses/index.html"));
      assert.ok(own.length >= 1, "el pie de la página sí lleva el hueco del contacto");
      assert.ok(!own.some((m) => /\[(DATE|WEBSITE|WEB)\]/.test(m)), own.join("\n"));
    } finally {
      w.cleanup();
    }
  });

  test("CA-027-05: palabras de analítica dentro de una licencia no hacen fallar la comprobación", () => {
    const { w } = withNotices(fakeNotices(HEADER_BUILD, noticesBody("It is plausible that gtag( and matomo and _vercel/ appear in a text.")));
    try {
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("la página de licencias existe (desde la spec 025, la enlaza el pie de la página de inicio, CA-025-20)", () => {
    assert.ok(existsSync(licenses(base)));
  });

  test("el título es el de la fila de Ajustes", () => {
    const html = read(licenses(base));
    assert.ok(html.includes('<h1><span lang="es" data-l="es">Licencias de terceros</span><span data-l="sep"> · </span><span lang="en" data-l="en">Third-party licenses</span></h1>'));
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
  fails("el bloque de avisos sin su <h2>", (w) => edit(licenses(w), (t) => t.replace(/<h2 id="notices">([^<]*)<\/h2>/, '<h3 id="notices">$1</h3>')), /avisos|h2|salta/);
  fails("el bloque de avisos sin <pre>", (w) => edit(licenses(w), (t) => t.replace(/(<h2 id="notices">[^<]*<\/h2>\n)<pre lang="en">([\s\S]*?)<\/pre>/, "$1<div>$2</div>")), /<pre|avisos/);
  fails("CA-026-12: los avisos en un <pre> sin lang=\"en\"", (w) => edit(licenses(w), (t) => t.replace(/(<h2 id="notices">[^<]*<\/h2>\n)<pre lang="en">/, "$1<pre>")), /avisos.*<pre lang="en">/);
  fails("el bloque de avisos sin aria-labelledby", (w) => edit(licenses(w), (t) => t.replace('<section lang="en" aria-labelledby="notices">', '<section lang="en">')), /aria-labelledby|avisos/);
  fails("una tercera mitad que no es de avisos", (w) => edit(licenses(w), (t) => t.replace("</main>", '<section lang="fr" aria-labelledby="fr"><p>x</p></section></main>')), /section|avisos/);
  fails("el bloque de avisos antes de las mitades", (w) => edit(licenses(w), (t) => {
    const a = t.indexOf('<section class="half" lang="es"');
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
  fails("un <script> en un aviso sin escapar", (w) => edit(licenses(w), (t) => t.replace(/(<h2 id="notices">[^<]*<\/h2>\n<pre lang="en">)/, "$1<script>1</script>")), /script/);
  fails("la cabecera del archivo con otro formato", (w) => edit(w.paths.notices, (t) => t.replace(/^[^\n]*/, "Versión: x")), /cabecera/);
});

// ─── El código de esta web (spec 025, CA-025-18) ──────────────────────────────────────────────────

describe("CA-025-18: cada pieza de terceros que va al navegador tiene su aviso, con su versión", () => {
  const LANDING = join(import.meta.dirname, "..");
  const pkg = JSON.parse(read(join(LANDING, "package.json")));
  const real = () => read(defaultPaths().webNotices);
  const squash = (t) => t.replace(/\s+/g, " ").trim();

  test("web-notices.txt nombra exactamente las dependencias de navegador de package.json, con su versión", () => {
    const { packages } = parseWebNotices(real());
    assert.deepEqual(
      packages.map((p) => `${p.name} ${p.version}`).sort(),
      Object.entries(pkg.dependencies).map(([n, v]) => `${n} ${v}`).sort(),
    );
  });

  test("H-026-02: el encabezado dice que las otras páginas solo llevan el programa propio de idioma (no «run no program»)", () => {
    const text = squash(real());
    assert.ok(!text.includes("run no program"), "vuelve la frase antigua: las cuatro páginas cargan /lang.js (spec 026)");
    assert.ok(
      text.includes("The other pages (privacy policy, licenses, help and the error page) run only a small program of the website's own, to show one language at a time; it includes no third-party code."),
      "falta la frase de la 026 sobre el programa de idioma de las otras páginas",
    );
  });

  test("Lenis: el texto de su LICENSE (MIT), tal cual viene en el paquete", () => {
    const license = read(join(LANDING, "node_modules/lenis/LICENSE"));
    assert.ok(squash(real()).includes(squash(license)), "falta el texto de la licencia de Lenis");
  });

  test("GSAP: su aviso de copyright, el mismo que lleva el paquete, y el enlace a su licencia", () => {
    const core = read(join(LANDING, "node_modules/gsap/gsap-core.js"));
    const copyright = /@license (Copyright [^\n]+)/.exec(core)?.[1];
    assert.ok(copyright, "no se encontró el aviso en gsap-core.js");
    assert.ok(real().includes(copyright), `falta «${copyright}»`);
    assert.ok(real().includes("Subject to the terms at https://gsap.com/standard-license"));
  });

  test("sin caracteres de control ni de dirección", () => {
    const bad = [...real()].filter((c) => {
      const n = c.codePointAt(0);
      return (n < 32 && c !== "\n") || n === 127 || (n >= 0x202a && n <= 0x202e) || (n >= 0x2066 && n <= 0x2069) || n === 0x200e || n === 0x200f;
    });
    assert.deepEqual(bad, []);
  });

  test("/licenses lo publica en su bloque, con el título en los dos idiomas, entre las mitades y los avisos de la app", () => {
    const html = read(licenses(base));
    // Con las marcas de idioma de la spec 026 (CA-026-12: sin JavaScript, el título en los dos idiomas).
    const block = /<section aria-labelledby="web-code">\n<h2 id="web-code"><span lang="es" data-l="es">Código de esta web<\/span><span data-l="sep"> · <\/span><span lang="en" data-l="en">Code of this website<\/span><\/h2>\n<pre lang="en">([\s\S]*?)<\/pre>\n<\/section>/.exec(html);
    assert.ok(block, "falta el bloque «Código de esta web»");
    const unescape = (t) => t.replaceAll("&quot;", '"').replaceAll("&#39;", "'").replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&amp;", "&");
    assert.equal(unescape(block[1]), real());
    assert.ok(block.index > html.indexOf('<section class="half" lang="en" data-l="en" aria-labelledby="en">'));
    assert.ok(block.index < html.indexOf('<section lang="en" aria-labelledby="notices">'));
  });

  test("el <pre> del código de esta web escapa el HTML", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.webNotices, (t) => `${t}\n<script>alert(1)</script>\n`);
      w.build();
      const html = read(licenses(w));
      assert.ok(html.includes("&lt;script&gt;alert(1)&lt;/script&gt;"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  for (const [label, mutate, pattern] of [
    ["sin archivo", (w) => rmSync(w.paths.webNotices), /web-notices\.txt/],
    ["vacío", (w) => writeFileSync(w.paths.webNotices, "  \n"), /está vacío/],
    ["sin la primera línea", (w) => edit(w.paths.webNotices, (t) => t.replace("Third-party code in this website\n", "")), /Third-party code in this website/],
    ["sin ningún paquete", (w) => edit(w.paths.webNotices, (t) => t.replaceAll("Package: ", "Paquete: ")), /ningún paquete/],
  ]) {
    test(`la construcción falla: ${label}`, () => {
      const w = cloneWorld(base);
      try {
        mutate(w);
        assert.throws(() => w.build(), pattern);
      } finally {
        w.cleanup();
      }
    });
  }

  for (const [label, mutate, pattern] of [
    ["sin el bloque", (t) => t.replace(/<section aria-labelledby="web-code">[\s\S]*?<\/section>\n/, ""), /tiene 3 <section>/],
    ["sin su aria-labelledby", (t) => t.replace('<section aria-labelledby="web-code">', "<section>"), /aria-labelledby="web-code"/],
    ["sin su <h2>", (t) => t.replace('<h2 id="web-code">', '<h2 id="otro">'), /<h2 id="web-code">/],
    ["con el <pre> sin lang", (t) => t.replace('<pre lang="en">', "<pre>"), /<pre lang="en">/],
  ]) {
    test(`la comprobación falla: ${label}`, () => {
      const w = cloneWorld(base);
      try {
        edit(licenses(w), mutate);
        const errors = specificErrors(checkSite(w.paths));
        assert.ok(errors.some((e) => pattern.test(e)), `ningún error casa ${pattern}:\n${errors.join("\n")}`);
      } finally {
        w.cleanup();
      }
    });
  }

  test("un aviso cambiado en el archivo sin reconstruir falla", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.webNotices, (t) => t.replace("Package: lenis", "Package: lenis-otro"));
      assert.ok(checkSite(w.paths).some((e) => /^licenses\/index\.html: no coincide/.test(e)));
    } finally {
      w.cleanup();
    }
  });
});

// ─── La estructura del archivo de avisos (spec 027) ───────────────────────────────────────────────

const DASH80 = "-".repeat(80);
/** Un cuerpo de prueba a partir de sus líneas (la línea N del cuerpo es `lines[N - 1]`). */
const doc = (lines) => `${lines.join("\n")}\n`;
/** El cuerpo válido de referencia: preámbulo con `ENTRIES`, tres avisos (dos de `a` y uno de `b, c`) y una sección. */
const VALID = [
  "Third-party notices", //                    1
  "===== BEGIN ENTRIES =====", //              2
  "dart:a", //                                 3
  "===== END ENTRIES =====", //                4
  "===== BEGIN NOTICES =====", //              5
  "a", //                                      6
  "", //                                       7
  "text a1", //                                8
  DASH80, //                                   9
  "a", //                                     10
  "", //                                      11
  "text a2", //                               12
  DASH80, //                                  13
  "b", //                                     14
  "c", //                                     15
  "", //                                      16
  "text bc", //                               17
  "===== END NOTICES =====", //               18
  "===== BEGIN assets/x.txt =====", //        19
  "section x", //                             20
  "===== END assets/x.txt =====", //          21
];
/** [VALID] con las líneas [from]…[to] (numeradas desde 1, inclusive) cambiadas por [insert]. */
const splice = (from, to, ...insert) => {
  const lines = [...VALID];
  lines.splice(from - 1, to - from + 1, ...insert);
  return lines;
};
/** Recuento independiente del analizador: parte la parte de avisos por las líneas de 80 guiones. */
function countByHand(body) {
  const lines = body.split("\n");
  const from = lines.indexOf("===== BEGIN NOTICES =====");
  const to = lines.indexOf("===== END NOTICES =====");
  const chunks = lines.slice(from + 1, to).join("\n").split(`\n${DASH80}\n`);
  const headers = chunks.map((c) => c.slice(0, c.indexOf("\n\n")));
  const runs = headers.filter((h, k) => k === 0 || h !== headers[k - 1]).length;
  return { notices: chunks.length, distinct: new Set(headers).size, runs };
}

describe("CA-027-05: el analizador reconoce la estructura del archivo", () => {
  test("el cuerpo de referencia: preámbulo tal cual, grupos por cabecera exacta y en orden, y la sección", () => {
    const p = parseNoticesBody(doc(VALID));
    assert.equal(p.preamble, doc(VALID.slice(0, 4)));
    assert.deepEqual(p.groups, [
      { names: ["a"], notices: ["text a1", "text a2"] },
      { names: ["b", "c"], notices: ["text bc"] },
    ]);
    assert.deepEqual(p.sections.map((s) => [s.path, s.text]), [["assets/x.txt", "section x"]]);
  });

  test("el texto de un aviso conserva sus líneas en blanco y sus espacios del principio y del final", () => {
    const p = parseNoticesBody(doc(splice(8, 8, "", "  first", "", "last  ", "", "")));
    assert.deepEqual(p.groups[0].notices[0], "\n  first\n\nlast  \n\n");
  });

  test("CL-027-3: una línea de 79 u 81 guiones dentro de un aviso es texto; una de 80 dentro de una sección, también", () => {
    const p = parseNoticesBody(doc(splice(20, 20, "x", DASH80, "y")));
    assert.equal(p.sections[0].text, `x\n${DASH80}\ny`);
    const q = parseNoticesBody(doc(splice(8, 8, "-".repeat(79), "-".repeat(81), "=".repeat(80))));
    assert.equal(q.groups[0].notices[0], `${"-".repeat(79)}\n${"-".repeat(81)}\n${"=".repeat(80)}`);
    assert.equal(q.groups[0].notices.length, 2);
  });

  test("CL-027-1: `a, b` y `b, a` son dos grupos, y `dart` y `dart, perfetto` también", () => {
    const p = parseNoticesBody(doc(splice(6, 17, "a", "b", "", "t1", DASH80, "b", "a", "", "t2", DASH80, "dart", "", "t3", DASH80, "dart", "perfetto", "", "t4")));
    assert.deepEqual(p.groups.map((g) => g.names.join(", ")), ["a, b", "b, a", "dart", "dart, perfetto"]);
  });

  test("las líneas en blanco fuera de una parte se admiten y se conservan para la ida y vuelta", () => {
    const body = doc(splice(19, 19, "", "  ", VALID[18])).concat("\n");
    const p = parseNoticesBody(body);
    assert.equal(p.preamble + rebuildNoticesBody(p), body);
  });

  test("CA-027-02 (c): la ida y vuelta reconstruye el cuerpo desde «BEGIN NOTICES», también sin salto de línea final", () => {
    for (const body of [doc(VALID), VALID.join("\n")]) {
      const p = parseNoticesBody(body);
      assert.equal(rebuildNoticesBody(p), body.slice(body.indexOf("===== BEGIN NOTICES =====")));
      assertNoticesRoundTrip(body, p);
    }
  });

  test("CA-027-02: la construcción falla si el analizador pierde, repite o cambia un aviso", () => {
    const body = doc(VALID);
    const tampered = [
      (p) => p.groups[0].notices.pop(),
      (p) => p.groups[0].notices.push(p.groups[0].notices[0]),
      (p) => (p.groups[1].notices[0] = "text bC"),
      (p) => (p.groups[1].names = ["c", "b"]),
      (p) => (p.sections[0].text += " "),
      (p) => (p.preamble = p.preamble.replace("dart:a", "dart:b")),
    ];
    for (const tamper of tampered) {
      const p = parseNoticesBody(body);
      tamper(p);
      assert.throws(() => assertNoticesRoundTrip(body, p), /no reconstruyen el archivo/);
    }
  });

  const rejects = (label, lines, pattern) =>
    test(`falla: ${label}`, () => assert.throws(() => parseNoticesBody(typeof lines === "string" ? lines : doc(lines)), pattern));

  rejects("ningún aviso (sin «BEGIN NOTICES»)", VALID.slice(0, 4), /ningún aviso/);
  rejects("«BEGIN NOTICES» sin «END NOTICES»", VALID.slice(0, 17), /línea 5: «BEGIN NOTICES» sin su «END NOTICES»/);
  rejects("una sección sin su «END»", VALID.slice(0, 20), /línea 19: «BEGIN assets\/x\.txt» sin su «END assets\/x\.txt»/);
  rejects("un «END» sin su «BEGIN» tras los avisos", splice(19, 21, "===== END assets/y.txt ====="), /línea 19: «===== END assets\/y\.txt =====» sin su «BEGIN assets\/y\.txt»/);
  rejects("un «END» de otra parte dentro de los avisos", splice(18, 18, "===== END ENTRIES ====="), /línea 18: .*END ENTRIES.* sin su «BEGIN ENTRIES»/);
  rejects("el «END» de otra sección dentro de una sección", splice(21, 21, "===== END assets/y.txt ====="), /línea 21: .*sin su «BEGIN assets\/y\.txt»/);
  rejects("una parte anidada en los avisos", splice(8, 8, "===== BEGIN assets/y.txt ====="), /línea 8: .*anidada/);
  rejects("una parte anidada en una sección", splice(20, 20, "===== BEGIN assets/y.txt ====="), /línea 20: .*anidada/);
  rejects("una sección repetida", [...VALID, ...VALID.slice(18, 21)], /línea 22: la sección «assets\/x\.txt» está repetida \(la primera, en la línea 19\)/);
  rejects("una segunda pareja «NOTICES»", [...VALID, ...VALID.slice(4, 18)], /línea 22: una segunda pareja «NOTICES»/);
  rejects("«ENTRIES» tras los avisos", [...VALID, ...VALID.slice(1, 4)], /línea 22: .*fuera del preámbulo/);
  rejects("otro marcador en el preámbulo", splice(2, 4, "===== BEGIN OTHER =====", "===== END OTHER ====="), /línea 2: marcador .*en el preámbulo/);
  rejects("«ENTRIES» sin cerrar", splice(4, 4), /línea 4: la parte «NOTICES» empieza dentro de «ENTRIES»/);
  rejects("«ENTRIES» anidado", splice(3, 3, "===== BEGIN ENTRIES ====="), /línea 3: «BEGIN ENTRIES» dentro de «ENTRIES»/);
  rejects("una segunda pareja «ENTRIES»", splice(5, 4, VALID[1], VALID[3]), /línea 5: una segunda pareja «ENTRIES»/);
  rejects("«END ENTRIES» sin su «BEGIN»", splice(2, 2), /línea 3: «END ENTRIES» sin su «BEGIN ENTRIES»/);
  rejects("una cabecera vacía", splice(6, 6), /línea 6: un aviso con la cabecera vacía/);
  rejects("una cabecera con espacios", splice(14, 14, "b c"), /línea 14: cabecera no válida \(«b c»\)/);
  rejects("una cabecera con un carácter de formato invisible (U+200B)", splice(15, 15, `c${String.fromCodePoint(0x200b)}`), /línea 15: cabecera no válida/);
  rejects("un aviso sin la línea en blanco tras la cabecera", splice(16, 16), /línea 14: un aviso sin la línea en blanco/);
  rejects("un aviso sin texto", splice(17, 17), /línea 14: el aviso de «b, c» no tiene texto/);
  rejects("un aviso con solo espacios en blanco", splice(17, 17, "  ", ""), /línea 14: el aviso de «b, c» no tiene texto/);
  rejects("un aviso vacío (dos separadores seguidos)", splice(9, 9, DASH80, DASH80), /línea 10: un aviso vacío/);
  rejects("un separador justo tras «BEGIN NOTICES»", splice(6, 5, DASH80), /línea 6: un aviso vacío/);
  rejects("una cabecera que reaparece lejos de su primer tramo", [...VALID.slice(0, 17), DASH80, "a", "", "text a3", ...VALID.slice(17)], /línea 19: la cabecera «a» reaparece lejos de su primer tramo \(línea 6\)/);
  rejects("texto tras «END NOTICES»", splice(19, 18, "loose"), /línea 19: texto fuera de una parte \(«loose»\)/);
  rejects("texto entre secciones", [...VALID, "loose", "===== BEGIN assets/y.txt =====", "y", "===== END assets/y.txt ====="], /línea 22: texto fuera de una parte/);
  rejects("texto tras la última sección", [...VALID, "", "loose"], /línea 23: texto fuera de una parte/);
  rejects("una sección sin texto", splice(20, 20), /línea 19: la sección «assets\/x\.txt» no tiene texto/);
});

describe("CA-027-01, CA-027-02 (c): con el archivo real", () => {
  const { body: raw } = parseNotices(readFileSync(defaultPaths().notices, "utf8"));
  const body = raw.replace(/\r\n?/g, "\n");
  const parsed = parseNoticesBody(body, { firstLine: 3 });

  test("CA-027-01: el número de grupos y la suma de sus avisos coinciden con un recuento independiente del analizador", () => {
    const hand = countByHand(body);
    assert.equal(parsed.groups.length, hand.distinct);
    assert.equal(hand.runs, hand.distinct, "cada cabecera en un único tramo seguido");
    assert.equal(parsed.groups.reduce((n, g) => n + g.notices.length, 0), hand.notices);
    assert.deepEqual(parsed.sections.map((s) => s.path), [...body.matchAll(/^===== BEGIN (assets\/\S+) =====$/gm)].map((m) => m[1]));
  });

  test("CA-027-02 (c): rebuild(parse(x)) es el cuerpo desde «BEGIN NOTICES», y el preámbulo es lo anterior", () => {
    const at = body.indexOf("===== BEGIN NOTICES =====");
    assert.equal(rebuildNoticesBody(parsed), body.slice(at));
    assert.equal(parsed.preamble, body.slice(0, at));
  });
});

describe("CA-027-04, CA-027-05: la construcción falla cerrado", () => {
  const breaks = (label, text, pattern) =>
    test(label, () => {
      const w = cloneWorld(base);
      try {
        writeFileSync(w.paths.notices, text);
        assert.throws(() => build(w.paths, { env: {} }), pattern);
      } finally {
        w.cleanup();
      }
    });
  const lines = noticesBody().split("\n"); // la línea N del cuerpo es la N + 2 del archivo

  breaks("CA-027-05: una estructura no reconocida, con la línea del archivo", fakeNotices(HEADER_BUILD, lines.filter((l) => l !== "===== END NOTICES =====").join("\n")), /third-party-notices\.txt, línea 6: «BEGIN NOTICES» sin su «END NOTICES»/);
  breaks("CA-027-05: un cuerpo sin la parte de avisos (el de la 023)", fakeNotices(HEADER_BUILD, "Third-party notices\nVersion: 0.0.0+0\n\nLicencia de prueba.\n"), /ningún aviso/);
  breaks("CA-027-04: una ruta de /Users/ en un aviso", fakeNotices(HEADER_BUILD, noticesBody("built in /Users/someone/src")), /línea 9: lleva una ruta de una carpeta personal \(«\/Users\/»\)/);
  breaks("CA-027-04: una ruta de /home/ en un aviso", fakeNotices(HEADER_BUILD, noticesBody("built in /home/someone/src")), /ruta de una carpeta personal \(«\/home\/»\)/);
  breaks("CA-027-04: una ruta C:\\Users\\ en un aviso", fakeNotices(HEADER_BUILD, noticesBody("built in C:\\Users\\someone")), /ruta de una carpeta personal/);
  breaks("CA-027-04: una ruta personal en el preámbulo", fakeNotices(HEADER_BUILD, noticesBody().replace("Version: 0.0.0+0", "Version: 0.0.0+0 /Users/x/")), /línea 4: lleva una ruta/);
  for (const n of [0x07, 0x1b, 0x7f, 0x85, 0x202e, 0x2066, 0x200f, 0x2028]) {
    const code = `U+${n.toString(16).toUpperCase().padStart(4, "0")}`;
    breaks(`CA-027-04: el carácter ${code} en un aviso`, fakeNotices(HEADER_BUILD, noticesBody(`a${String.fromCodePoint(n)}b`)), new RegExp(`línea 9: lleva un carácter de (control|dirección) \\(${code.replace("+", "\\+")}\\)`));
  }

  test("CA-027-04: /home/runner/ (la CI), tabuladores y retornos de carro se admiten", () => {
    checkNoticesText(fakeNotices(HEADER_BUILD, noticesBody("built in /home/runner/work\tx\r\ny")));
    const { w } = withNotices(fakeNotices(HEADER_BUILD, noticesBody("built in /home/runner/work\tx")));
    w.cleanup();
  });
});
