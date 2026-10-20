// La Ayuda en la web (spec 023): CA-023-17. Cada regla con un caso que falla.
import assert from "node:assert/strict";
import { readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { build, compareHelpStructure, defaultPaths, stripComments } from "../build.mjs";
import { checkSite } from "../check.mjs";
import { cloneWorld, edit, read, specificErrors, world } from "./support.mjs";

let base;
before(() => {
  base = world();
  base.build();
});
after(() => base.cleanup());

const helpEs = () => read(base.paths.helpEs);
const helpEn = () => read(base.paths.helpEn);
const page = (w) => join(w.dist, "help/index.html");

/** Los títulos `##` de un texto de ayuda. */
const titles = (md) => [...md.matchAll(/^## (.+)$/gm)].map((m) => m[1]);

/** El texto de la sección número [n] (desde 1) sin sus comentarios. */
function section(md, n) {
  const parts = stripComments(md).split(/^## /m).slice(1);
  return parts[n - 1];
}

describe("CA-023-17: los temas de la Ayuda", () => {
  // [tema, [ES: expresiones que tiene que haber], [EN: ídem]]
  const topics = [
    ["la tarea actual y completarla", [/Pulsa para completar/, /[Mm]antén pulsado/, /1,2/], [/Press to complete/, /[Pp]ress and hold/, /1\.2/]],
    ["crear una tarea y elegir dónde va", [/Nueva tarea/, /¿Dónde la pones\?/, /Arriba del todo/, /A la cola/], [/New task/, /Where does it go\?/, /On top/, /At the end/]],
    ["editar", [/Editar/, /Guardar cambios/, /Quitar adjunto/], [/Edit/, /Save changes/, /Remove attachment/]],
    ["eliminar y deshacer", [/Eliminar/, /Tarea eliminada/, /Deshacer/, /4 segundos/], [/Delete/, /Task deleted/, /Undo/, /4 seconds/]],
    ["todas mis tareas y reordenar", [/Todas mis tareas/, /Mover tarea/, /Hacer actual/, /Mover arriba/, /Mover abajo/], [/All my tasks/, /Move task/, /Make current/, /Move up/, /Move down/]],
    ["adjuntos", [/Hacer foto/, /Subir imágenes/, /Subir archivo/, /Cargar URL/, /necesita conexión/i, /10 fotos/, /PDF/], [/Take photo/, /Upload images/, /Upload file/, /Load URL/, /needs a connection/i, /10 photos/, /PDF/]],
    ["Ajustes", [/Idioma/, /Notificaciones/, /08:55/, /13:55/, /18:55/, /Pantalla siempre activa/, /Bloquear zoom/, /Política de privacidad/], [/Language/, /Notifications/, /08:55/, /13:55/, /18:55/, /Keep screen on/, /Lock zoom/, /Privacy policy/]],
    ["Recientes", [/Recientes/], [/Recents/]],
    ["copias de seguridad", [/copias? de seguridad/i, /Adjunto no disponible/], [/backups?/i, /Attachment unavailable/]],
    ["ampliar", [/pellizco/, /lupa/], [/pinch/, /magnif/i]],
    ["TalkBack", [/TalkBack/, /Completar tarea/, /Foto siguiente/, /Ampliar/], [/TalkBack/, /Complete task/, /Next photo/, /Zoom in/]],
    ["contacto", [/\[CONTACTO\]/], [/\[CONTACT\]/]],
  ];

  test("hay una sección por tema, en este orden, en español y en inglés", () => {
    assert.equal(titles(helpEs()).length, topics.length, titles(helpEs()).join(" | "));
    assert.equal(titles(helpEn()).length, topics.length, titles(helpEn()).join(" | "));
  });

  topics.forEach(([name, es, en], i) => {
    test(`el tema «${name}» tiene lo que pide la spec (ES y EN)`, () => {
      const a = section(helpEs(), i + 1);
      const b = section(helpEn(), i + 1);
      for (const re of es) assert.match(a, re, `ES, sección ${i + 1}`);
      for (const re of en) assert.match(b, re, `EN, section ${i + 1}`);
    });
  });

  test("no explica «Restringir» de HyperOS, la parada forzada, el retraso con la pantalla apagada ni los arranques automáticos (propietario, 2026-10-19)", () => {
    for (const md of [helpEs(), helpEn()]) {
      const text = stripComments(md);
      for (const re of [/Restring/i, /HyperOS/i, /Xiaomi/i, /parada forzada/i, /forzar (la )?(parada|detención)/i, /force[- ]stop/i, /arranques? autom[aá]tic/i, /auto-?start/i, /pantalla apagada/i, /screen is off/i, /battery optimi[sz]/i, /optimizaci[oó]n de (la )?bater/i]) {
        assert.doesNotMatch(text, re);
      }
    }
  });
});

describe("CA-023-17: ES y EN dicen lo mismo", () => {
  test("la Ayuda real pasa", () => {
    assert.deepEqual(compareHelpStructure(helpEs(), helpEn()), []);
  });

  test("una viñeta de menos en una sección inglesa falla y dice cuál", () => {
    const en = helpEn();
    const at = en.indexOf("\n- ", en.indexOf("## ", 10));
    assert.ok(at > 0);
    const end = en.indexOf("\n", at + 1);
    const errors = compareHelpStructure(helpEs(), en.slice(0, at) + en.slice(end));
    assert.ok(errors.length >= 1);
    assert.match(errors.join("\n"), /viñetas/);
  });

  test("un párrafo de más en una sección inglesa falla", () => {
    const en = helpEn();
    const first = titles(en)[0];
    const errors = compareHelpStructure(helpEs(), en.replace(`## ${first}\n`, `## ${first}\n\nUn párrafo extra.\n`));
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /párrafos/);
  });

  test("una sección de menos falla", () => {
    const en = helpEn();
    const last = en.lastIndexOf("\n## ");
    const errors = compareHelpStructure(helpEs(), en.slice(0, last));
    assert.match(errors.join("\n"), /secciones/);
  });

  test("un enlace de menos falla", () => {
    const es = helpEs();
    const link = es.match(/\[[^\]]+\]\(\/privacy#es\)/);
    assert.ok(link, "la Ayuda en español enlaza a la política");
    const errors = compareHelpStructure(es.replace(link[0], "la política"), helpEn());
    assert.ok(errors.length >= 1);
  });

  test("el hueco de contacto de menos falla", () => {
    const errors = compareHelpStructure(helpEs(), helpEn().replace("[CONTACT]", "us"));
    assert.match(errors.join("\n"), /huecos/);
  });
});

describe("CA-023-17: cada sección dice de qué spec sale, en un comentario que no se publica", () => {
  for (const [lang, md] of [["es", helpEs], ["en", helpEn]]) {
    test(`help.${lang}.md: debajo de cada título hay «Fuente: spec …»`, () => {
      const lines = md().split("\n");
      const heads = lines.map((l, i) => (l.startsWith("## ") ? i : -1)).filter((i) => i >= 0);
      assert.ok(heads.length >= 12);
      for (const i of heads) {
        const next = lines.slice(i + 1, i + 6).join("\n");
        assert.match(next, /^\s*<!-- Fuente: specs? \d{3}[^]*?-->/, `sin fuente bajo «${lines[i]}»`);
      }
    });
  }

  test("los comentarios no salen en la web", () => {
    const html = read(page(base));
    assert.ok(!html.includes("Fuente:"));
    assert.ok(!html.includes("<!--"));
    assert.ok(!/spec \d{3}/i.test(html));
  });

  test("stripComments quita los comentarios de línea entera, de una o varias líneas", () => {
    assert.equal(stripComments("a\n<!-- x -->\nb\n<!--\nvarias\nlíneas\n-->\nc\n"), "a\n\nb\n\nc\n");
  });

  const rejects = (label, text, pattern) => test(`stripComments falla: ${label}`, () => assert.throws(() => stripComments(text), pattern));
  rejects("sin cerrar", "a\n<!-- x\nb\n", /sin cerrar/);
  rejects("a mitad de un párrafo", "hola <!-- x --> mundo\n", /no empieza la línea/);
  rejects("un cierre suelto", "a\n-->\n", /sin abrir/);
  rejects("anidado en una sola línea", "<!-- a <!-- b -->\n", /anidado/);
  rejects("anidado en varias líneas", "<!--\na <!-- b\n-->\n", /anidado/);
  rejects("uno que no empieza la línea", "a <!--\nb\n-->\n", /no empieza la línea/);
  rejects("seguido de texto en la misma línea", "<!-- x --> texto\n", /seguido de texto/);
  rejects("seguido de texto al cerrar varias líneas", "<!--\nx\n--> texto\n", /seguido de texto/);
});

describe("CA-023-17: la página de Ayuda", () => {
  test("sale en español e inglés, con el título de la fila de Ajustes", () => {
    const html = read(page(base));
    assert.ok(html.includes('<h1><span lang="es">Ayuda</span> · <span lang="en">Help</span></h1>'));
    assert.match(html, /<section lang="es" aria-labelledby="es">/);
    assert.match(html, /<section lang="en" aria-labelledby="en">/);
    assert.match(html, /<h2 id="es" tabindex="-1">Ayuda \(ES\)<\/h2>/);
    assert.match(html, /<h2 id="en" tabindex="-1">Help \(EN\)<\/h2>/);
  });

  test("una sección por tema (h3) en cada idioma, sin saltos de nivel", () => {
    const html = read(page(base));
    const es = html.slice(html.indexOf('<section lang="es"'), html.indexOf('<section lang="en"'));
    const en = html.slice(html.indexOf('<section lang="en"'));
    assert.equal(es.split("<h3>").length - 1, 12);
    assert.equal(en.split("<h3>").length - 1, 12);
    assert.ok(!/<h[56]/.test(html));
  });

  test("el hueco de contacto sale como aviso, no como error", () => {
    const { warnings } = build(base.paths, { env: {} });
    assert.ok(warnings.some((m) => m.includes("help/index.html") && m.includes("[CONTACTO]")), warnings.join("\n"));
    assert.ok(warnings.some((m) => m.includes("help/index.html") && m.includes("[CONTACT]")));
  });

  test("con VERCEL_ENV=production un hueco en la Ayuda hace fallar aunque todo lo demás esté relleno", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.policy, (t) =>
        t
          .replaceAll("[RESPONSABLE]", "Ana Pérez")
          .replaceAll("[CONTROLLER]", "Ana Pérez")
          .replaceAll("[CONTACTO]", "ana@ejemplo.org")
          .replaceAll("[CONTACT]", "ana@ejemplo.org")
          .replaceAll("[FECHA]", "3 de marzo de 2027")
          .replaceAll("[DATE]", "March 3, 2027"),
      );
      edit(w.paths.strings, (t) => t.replace("[CONTACTO]", "ana@ejemplo.org").replace("[CONTACT]", "ana@ejemplo.org"));
      assert.throws(
        () => build(w.paths, { env: { VERCEL_ENV: "production" } }),
        (e) => /\[CONTACTO\] en help\/index\.html/.test(e.message) && !/privacy|404|licenses/.test(e.message),
      );
      edit(w.paths.helpEs, (t) => t.replaceAll("[CONTACTO]", "ana@ejemplo.org"));
      edit(w.paths.helpEn, (t) => t.replaceAll("[CONTACT]", "ana@ejemplo.org"));
      assert.deepEqual(build(w.paths, { env: { VERCEL_ENV: "production" } }).warnings, []);
    } finally {
      w.cleanup();
    }
  });

  test("la comprobación de la web pasa", () => {
    assert.deepEqual(checkSite(base.paths), []);
  });

  test("{appName} se sustituye por el nombre de la identidad", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.helpEs, (t) => t.replace("## ", "Esto es {appName} en la Ayuda.\n\n## "));
      w.build();
      assert.match(read(page(w)), /Esto es [^<]+ en la Ayuda\./);
      assert.ok(!read(page(w)).includes("{appName}"));
    } finally {
      w.cleanup();
    }
  });
});

describe("CA-023-17: textos de la app, tal cual", () => {
  const arb = (lang) => {
    const json = JSON.parse(readFileSync(lang === "es" ? defaultPaths().arbEs : defaultPaths().arbEn, "utf8"));
    return new Set(Object.entries(json).filter(([k, v]) => !k.startsWith("@") && typeof v === "string").map(([, v]) => v));
  };
  // Nombres de ajustes de Android y frases compuestas por la interfaz que no son una sola cadena.
  const extra = {
    es: ["Todo hecho.", "Tiempo para actuar", "Recientes"],
    en: ["All done.", "Time to take action", "Recents"],
  };
  // Cómo se citan los textos de la app: «así» en español y “así” en inglés.
  const quotes = { es: /«([^»]+)»/g, en: /“([^”]+)”/g };

  for (const [lang, md] of [["es", helpEs], ["en", helpEn]]) {
    test(`help.${lang}.md: todo lo que va entre comillas es un texto de la app, un título de sección o un ajuste del sistema`, () => {
      const text = stripComments(md());
      const known = new Set([...arb(lang), ...extra[lang], ...titles(md())]);
      const quoted = [...text.matchAll(quotes[lang])].map((m) => m[1]);
      assert.ok(quoted.length >= 30, `pocos textos de la app citados (${quoted.length})`);
      const unknown = quoted.filter((q) => !known.has(q));
      assert.deepEqual([...new Set(unknown)], []);
    });
  }

  test("un nombre de botón mal copiado se detecta", () => {
    const known = arb("es");
    assert.ok(known.has("Pulsa para completar"));
    assert.ok(!known.has("Pulsa para completarla"));
  });
});

describe("CA-023-17: falla cerrada", () => {
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

  breaks("sin help.es.md", (w) => rmSync(w.paths.helpEs), /help\.es\.md: no se puede leer/);
  breaks("sin help.en.md", (w) => rmSync(w.paths.helpEn), /help\.en\.md: no se puede leer/);
  breaks("con una tabla", (w) => edit(w.paths.helpEs, (t) => t.replace("## ", "| a | b |\n|---|---|\n\n## ")), /help\.es\.md: .*tabla/);
  breaks("con un marcador {otro}", (w) => edit(w.paths.helpEn, (t) => t.replace("## ", "Hola {otro}\n\n## ")), /\{otro\}/);
  breaks("con una marca [Suposición]", (w) => edit(w.paths.helpEs, (t) => t.replace("## ", "Esto [Suposición] va\n\n## ")), /corchetes/);
  breaks("con un enlace javascript:", (w) => edit(w.paths.helpEs, (t) => t.replace("## ", "[x](javascript:alert(1))\n\n## ")), /enlace/);
  breaks("con un comentario sin cerrar", (w) => edit(w.paths.helpEn, (t) => `${t}\n<!-- sin cerrar\n`), /help\.en\.md: comentario sin cerrar/);
  breaks("con un segundo título «# …»", (w) => edit(w.paths.helpEn, (t) => `${t}\n# Otro título\n`), /único título/);
  breaks("con el título después de un tema", (w) => edit(w.paths.helpEs, (t) => `${t.replace(/^# .*\n/m, "")}\n# Ayuda (ES)\n`), /único título/);
  breaks("sin el título principal (# Ayuda)", (w) => edit(w.paths.helpEs, (t) => t.replace(/^# .*\n/m, "")), /título|encabezado/i);

  test("el HTML que se cuele en la Ayuda se escapa, no se publica", () => {
    const w = cloneWorld(base);
    try {
      edit(w.paths.helpEs, (t) => t.replace("## ", "<script>alert(1)</script> y <b>negrita</b>\n\n## "));
      w.build();
      const html = read(page(w));
      assert.ok(!html.includes("<script>"));
      assert.ok(html.includes("&lt;script&gt;alert(1)&lt;/script&gt; y &lt;b&gt;negrita&lt;/b&gt;"));
      assert.deepEqual(checkSite(w.paths), []);
    } finally {
      w.cleanup();
    }
  });

  test("el nombre de la app escrito a mano en la Ayuda hace fallar la comprobación", () => {
    for (const bad of ["Bienvenido a Una. Una tarea.", "Usa una. cada día."]) {
      const w = cloneWorld(base);
      try {
        edit(w.paths.helpEs, (t) => t.replace("## ", `${bad}\n\n## `));
        w.build();
        const errors = checkSite(w.paths);
        assert.ok(errors.some((e) => /a mano/.test(e) && /help\.es\.md/.test(e)), errors.join("\n"));
      } finally {
        w.cleanup();
      }
    }
  });

  test("la página de Ayuda cambiada a mano no coincide con lo que construyen las fuentes", () => {
    const w = cloneWorld(base);
    try {
      edit(page(w), (t) => t.replace("<h3>", "<h3>X"));
      const errors = checkSite(w.paths);
      assert.ok(errors.some((e) => /help\/index\.html/.test(e) && /no coincide/.test(e)));
    } finally {
      w.cleanup();
    }
  });

  test("falta la página de Ayuda construida", () => {
    const w = cloneWorld(base);
    try {
      rmSync(page(w));
      const errors = specificErrors(checkSite(w.paths));
      assert.ok(errors.some((e) => /help\/index\.html/.test(e)));
    } finally {
      w.cleanup();
    }
  });
});
