// CA-023-09: los textos de la ficha en español e inglés.
import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { POINTS, checkListing } from "../check.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

let base;
before(() => {
  base = world();
});
after(() => base.cleanup());

const LANGS = ["es-ES", "en-US"];
const file = (paths, lang, name) => join(paths.listingDir, lang, `${name}.txt`);

/** Los errores de la ficha tras aplicar [mutate(paths)] a un mundo nuevo. */
function errorsWith(mutate) {
  const w = cloneWorld(base);
  try {
    mutate(w.paths);
    return checkListing(w.paths);
  } finally {
    w.cleanup();
  }
}

const setText = (lang, name, text) => (p) => writeFileSync(file(p, lang, name), text);
/** Añade [extra] al final de la descripción completa de [lang]. */
const appendFull = (lang, extra) => (p) => edit(file(p, lang, "full-description"), (t) => `${t.trimEnd()}\n\n${extra}\n`);

/** Rellena [text] hasta [n] caracteres (puntos de código) con una palabra suelta, con el nombre ya sustituido. */
const padTo = (text, n) => {
  const missing = n - [...text.replaceAll("{appName}", "Una")].length;
  assert.ok(missing >= 3, "el texto ya pasa del límite");
  return `${text}\n\n${"a".repeat(missing - 2)}`;
};

describe("CA-023-09: la ficha real", () => {
  test("CA-023-09: pasa, en los dos idiomas", () => {
    assert.deepEqual(checkListing(base.paths), []);
  });

  test("CA-023-09: el título de los dos idiomas es el marcador del nombre", () => {
    for (const lang of LANGS) assert.equal(read(file(base.paths, lang, "title")).trim(), "{appName}");
  });
});

describe("CA-023-09: longitudes contadas en caracteres", () => {
  test("CA-023-09: la breve de 80 caracteres pasa y la de 81 falla", () => {
    for (const lang of LANGS) {
      assert.deepEqual(errorsWith(setText(lang, "short-description", `${"ñ".repeat(79)}x\n`)), []);
      const errors = errorsWith(setText(lang, "short-description", `${"ñ".repeat(80)}x\n`));
      assert.ok(errors.some((e) => /short-description/.test(e) && /81/.test(e) && /80/.test(e)), errors.join("\n"));
    }
  });

  test("CA-023-09: se cuentan caracteres, no bytes ni unidades UTF-16", () => {
    // 80 letras fuera del plano básico (2 unidades UTF-16 y 4 bytes cada una): son 80 caracteres.
    assert.deepEqual(errorsWith(setText("es-ES", "short-description", `${"\u{1d49c}".repeat(80)}\n`)), []);
  });

  test("CA-023-09: la completa de 4000 caracteres pasa y la de 4001 falla", () => {
    for (const lang of LANGS) {
      const full = read(file(base.paths, lang, "full-description")).trimEnd();
      // el marcador {appName} cuenta como el nombre ya sustituido (3 caracteres)
      assert.deepEqual(errorsWith(setText(lang, "full-description", `${padTo(full, 4000)}\n`)).filter((e) => /caracteres/.test(e)), []);
      const errors = errorsWith(setText(lang, "full-description", `${padTo(full, 4001)}\n`));
      assert.ok(errors.some((e) => /full-description/.test(e) && /4001/.test(e)), errors.join("\n"));
    }
  });

  test("CA-023-09: el nombre se cuenta ya sustituido (identidad de más de 30 caracteres)", () => {
    const errors = errorsWith((p) =>
      edit(p.identity, (t) => t.replace(/^displayName: "[^"]*"/m, `displayName: "${"N".repeat(31)}"`)),
    );
    assert.ok(errors.some((e) => /title/.test(e) && /31/.test(e) && /30/.test(e)), errors.join("\n"));
  });

  test("CA-023-09: un archivo vacío falla", () => {
    for (const name of ["title", "short-description", "full-description"]) {
      const errors = errorsWith(setText("en-US", name, "\n"));
      assert.ok(errors.some((e) => e.includes(`${name}.txt`) && /vacío/.test(e)), errors.join("\n"));
    }
  });

  test("CA-023-09: falta un archivo, o sobra uno, o falta un idioma", () => {
    let errors = errorsWith((p) => rmSync(file(p, "es-ES", "short-description")));
    assert.ok(errors.some((e) => /short-description\.txt/.test(e) && /falta/.test(e)), errors.join("\n"));
    errors = errorsWith((p) => writeFileSync(file(p, "en-US", "notes"), "x"));
    assert.ok(errors.some((e) => /notes/.test(e) && /inesperado/.test(e)), errors.join("\n"));
    errors = errorsWith((p) => rmSync(join(p.listingDir, "en-US"), { recursive: true }));
    assert.ok(errors.some((e) => /en-US/.test(e) && /falta/.test(e)), errors.join("\n"));
    errors = errorsWith((p) => mkdirSync(join(p.listingDir, "fr-FR")));
    assert.ok(errors.some((e) => /fr-FR/.test(e) && /inesperado/.test(e)), errors.join("\n"));
  });
});

describe("CA-023-09: el nombre sale de la identidad", () => {
  test("CA-023-09: un título que no es el marcador falla (aunque sea el nombre escrito)", () => {
    for (const title of ["Otra app\n", "Una\n", "{appName} app\n"]) {
      const errors = errorsWith(setText("es-ES", "title", title));
      assert.ok(errors.some((e) => /title/.test(e)), `${JSON.stringify(title)}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-09: el nombre escrito a mano en una descripción falla", () => {
    for (const lang of LANGS) {
      for (const name of ["short-description", "full-description"]) {
        const errors = errorsWith((p) => edit(file(p, lang, name), (t) => `${t.trimEnd()} Descarga Una hoy\n`));
        assert.ok(errors.some((e) => e.includes(`${name}.txt`) && /a mano/.test(e)), errors.join("\n"));
      }
    }
  });

  test("CA-023-09: el logotipo escrito a mano también falla", () => {
    const errors = errorsWith(appendFull("es-ES", "Prueba una."));
    assert.ok(errors.some((e) => /a mano/.test(e)), errors.join("\n"));
  });

  test("CA-023-09: el artículo «Una» que abre frase no es el nombre", () => {
    assert.deepEqual(errorsWith(appendFull("es-ES", "Una foto, un PDF o una web.")), []);
  });

  test("CA-023-09: otros marcadores entre llaves fallan", () => {
    const errors = errorsWith(appendFull("en-US", "Made by {developer}."));
    assert.ok(errors.some((e) => /\{developer\}/.test(e)), errors.join("\n"));
  });
});

describe("CA-023-09: sin huecos ni marcas", () => {
  const MARKS = ["[CONTACTO]", "[CONTACT]", "[FECHA]", "[WEB]", "[RESPONSABLE]", "[Pendiente]", "[TODO]", "[Suposición]", "[Hecho]"];
  for (const mark of MARKS) {
    test(`CA-023-09: ${mark} en la completa falla`, () => {
      const errors = errorsWith(appendFull("es-ES", `Escribe a ${mark}.`));
      assert.ok(errors.some((e) => e.includes("full-description.txt") && e.includes(mark)), errors.join("\n"));
    });
  }

  test("CA-023-09: un hueco en la breve y en el título falla", () => {
    let errors = errorsWith(setText("en-US", "short-description", "One task at a time [CONTACT]\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /\[CONTACT\]/.test(e)), errors.join("\n"));
    errors = errorsWith(setText("en-US", "title", "{appName} [WEB]\n"));
    assert.ok(errors.some((e) => /title/.test(e)), errors.join("\n"));
  });
});

describe("CA-023-09: emojis y formato del nombre y de la breve", () => {
  const EMOJIS = ["\u{1f600}", "\u{2705}", "\u{1f1ea}\u{1f1f8}", "1\u{fe0f}\u{20e3}"];
  for (const emoji of EMOJIS) {
    test(`CA-023-09: un emoji (U+${[...emoji][0].codePointAt(0).toString(16)}) en la breve falla`, () => {
      const errors = errorsWith(setText("es-ES", "short-description", `Una sola tarea ${emoji}\n`));
      assert.ok(errors.some((e) => /short-description/.test(e) && /emoji/.test(e)), errors.join("\n"));
    });
  }

  test("CA-023-09: un emoji en el título falla (con el nombre sustituido en la comprobación)", () => {
    const errors = errorsWith(setText("es-ES", "title", "{appName} \u{1f600}\n"));
    assert.ok(errors.some((e) => /title/.test(e)), errors.join("\n"));
  });

  test("CA-023-09: un emoji en la completa no se prohíbe", () => {
    assert.deepEqual(errorsWith(appendFull("es-ES", "Sin prisas \u{1f642}")), []);
  });

  test("CA-023-09: la breve con salto de línea falla", () => {
    const errors = errorsWith(setText("es-ES", "short-description", "Una sola tarea\na la vez\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /salto de línea/.test(e)), errors.join("\n"));
  });

  test("CA-023-09: la breve de una sola frase no acaba en punto; la de varias, sí puede", () => {
    const one = errorsWith(setText("es-ES", "short-description", "Una sola tarea a la vez.\n"));
    assert.ok(one.some((e) => /short-description/.test(e) && /punto/.test(e)), one.join("\n"));
    assert.deepEqual(errorsWith(setText("es-ES", "short-description", "Una sola tarea a la vez. Sin cuentas.\n")), []);
  });

  test("CA-023-09: palabras enteras en mayúsculas (menos PDF) en la breve o el título fallan", () => {
    const errors = errorsWith(setText("es-ES", "short-description", "SIN cuentas ni analítica\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /mayúsculas/.test(e)), errors.join("\n"));
    assert.deepEqual(errorsWith(setText("es-ES", "short-description", "Tareas con foto, PDF o web\n")), []);
  });

  test("CA-023-09: caracteres especiales repetidos en el título o la breve fallan", () => {
    const errors = errorsWith(setText("en-US", "short-description", "One task at a time!!!\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /repetidos/.test(e)), errors.join("\n"));
  });
});

describe("CA-023-09: sin superlativos ni comparaciones", () => {
  const ES = ["la mejor app", "número 1 en tareas", "nº 1", "app top", "es gratis", "mejor que otras apps", "a diferencia de otras apps"];
  const EN = ["the best app", "#1 task app", "a top app", "totally free", "better than other apps", "unlike other apps"];
  for (const phrase of ES) {
    test(`CA-023-09: «${phrase}» en la completa española falla`, () => {
      const errors = errorsWith(appendFull("es-ES", `Es ${phrase}.`));
      assert.ok(errors.some((e) => e.includes("full-description.txt") && /superlativo|comparaci/.test(e)), errors.join("\n"));
    });
  }
  for (const phrase of EN) {
    test(`CA-023-09: «${phrase}» en la completa inglesa falla`, () => {
      const errors = errorsWith(appendFull("en-US", `It is ${phrase}.`));
      assert.ok(errors.some((e) => e.includes("full-description.txt") && /superlativo|comparaci/.test(e)), errors.join("\n"));
    });
  }

  test("CA-023-09: también en la breve, en los dos idiomas", () => {
    let errors = errorsWith(setText("es-ES", "short-description", "La mejor app de tareas\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /superlativo/.test(e)), errors.join("\n"));
    errors = errorsWith(setText("en-US", "short-description", "Best task app, free\n"));
    assert.ok(errors.some((e) => /short-description/.test(e) && /superlativo/.test(e)), errors.join("\n"));
  });

  test("CA-023-09: palabras enteras: «desktop» o «topografía» no cuentan como «top»", () => {
    assert.deepEqual(errorsWith(appendFull("en-US", "Not for desktop.")), []);
    assert.deepEqual(errorsWith(appendFull("es-ES", "Sin topografía.")), []);
  });
});

describe("CA-023-09: lo que la descripción completa tiene que decir", () => {
  test("CA-023-09: hay un punto por cada cosa de la spec", () => {
    const ids = POINTS.map((p) => p.id);
    for (const id of [
      "one-task",
      "full-screen",
      "photo",
      "photos",
      "pdf",
      "web",
      "no-accounts",
      "no-server",
      "no-analytics",
      "web-needs-connection",
      "notifications-optional",
      "languages",
    ]) {
      assert.ok(ids.includes(id), `falta el punto ${id}`);
    }
  });

  for (const lang of LANGS) {
    for (const id of [
      "one-task",
      "full-screen",
      "photo",
      "photos",
      "pdf",
      "web",
      "no-accounts",
      "no-server",
      "no-analytics",
      "web-needs-connection",
      "notifications-optional",
      "languages",
    ]) {
      test(`CA-023-09: sin «${id}» en ${lang} falla`, () => {
        const point = POINTS.find((p) => p.id === id);
        const re = lang === "es-ES" ? point.es : point.en;
        const errors = errorsWith((p) =>
          edit(file(p, lang, "full-description"), (t) =>
            t
              .split("\n")
              .filter((line) => !re.some((r) => r.test(line)))
              .join("\n"),
          ),
        );
        assert.ok(errors.some((e) => e.includes("full-description.txt") && e.includes(`«${id}»`)), errors.join("\n"));
      });
    }
  }

  test("CA-023-09: «web» y «necesita conexión» en frases distintas no valen", () => {
    const errors = errorsWith((p) =>
      edit(file(p, "es-ES", "full-description"), (t) =>
        t
          .split("\n")
          .map((l) => (/conexi/i.test(l) && /web/i.test(l) ? "Las webs ayudan.\nNecesita conexión para otra cosa." : l))
          .join("\n"),
      ),
    );
    assert.ok(errors.some((e) => e.includes("«web-needs-connection»")), errors.join("\n"));
  });
});

describe("CA-023-09: no promete lo que la app no hace", () => {
  const PROMISES = {
    "es-ES": ["Sincroniza tus tareas entre dispositivos.", "Disponible también en iOS.", "Funciona en iPhone y iPad.", "Disponible en catalán.", "Con subtareas."],
    "en-US": ["Syncs your tasks across devices.", "Also on iOS.", "Works on iPhone and iPad.", "Available in French.", "With subtasks."],
  };
  for (const [lang, list] of Object.entries(PROMISES)) {
    for (const promise of list) {
      test(`CA-023-09: «${promise}» falla`, () => {
        const errors = errorsWith(appendFull(lang, promise));
        assert.ok(errors.some((e) => e.includes("full-description.txt") && /promete|no hace/.test(e)), errors.join("\n"));
      });
    }
  }
});

describe("CA-023-08 (ficha): ni promete ni niega permisos distintos de los reales", () => {
  test("CA-023-08: «pide permiso de cámara» falla (la app no lo pide)", () => {
    let errors = errorsWith(appendFull("es-ES", "Pide permiso de cámara y de fotos."));
    assert.ok(errors.some((e) => /permiso/.test(e) && /cámara/i.test(e)), errors.join("\n"));
    errors = errorsWith(appendFull("en-US", "It asks for camera permission."));
    assert.ok(errors.some((e) => /permission/i.test(e) && /camera/i.test(e)), errors.join("\n"));
  });

  test("CA-023-08: un identificador android.permission.X que no es real falla", () => {
    const errors = errorsWith(appendFull("en-US", "Needs android.permission.CAMERA."));
    assert.ok(errors.some((e) => /^[^«]*android\.permission\.CAMERA: no es un permiso de la app/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: negar un permiso real (notificaciones, Internet) falla", () => {
    let errors = errorsWith(appendFull("es-ES", "No pide permiso de notificaciones."));
    assert.ok(errors.some((e) => /permiso/.test(e) && /notificaciones/i.test(e) && /real/.test(e)), errors.join("\n"));
    errors = errorsWith(appendFull("en-US", "It needs no Internet permission."));
    assert.ok(errors.some((e) => /Internet/.test(e) && /real/.test(e)), errors.join("\n"));
    errors = errorsWith(appendFull("es-ES", "No usa internet."));
    assert.ok(errors.some((e) => /internet/i.test(e)), errors.join("\n"));
  });

  test("CA-023-08: negar un permiso que no se pide (cámara, fotos, archivos) es verdad y pasa", () => {
    assert.deepEqual(errorsWith(appendFull("es-ES", "No necesita permiso de cámara, de fotos ni de archivos.")), []);
    assert.deepEqual(errorsWith(appendFull("en-US", "It doesn't need camera, photo or file permissions.")), []);
  });

  test("CA-023-08: decir que pide el permiso de notificaciones al encenderlas es verdad y pasa", () => {
    assert.deepEqual(errorsWith(appendFull("es-ES", "Android te pide permiso para las notificaciones.")), []);
    assert.deepEqual(errorsWith(appendFull("en-US", "The task web page needs Internet.")), []);
  });
});
