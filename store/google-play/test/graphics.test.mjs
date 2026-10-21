// CA-023-10 (la regla): icono, gráfico de funciones y capturas. Las imágenes de los casos se generan en
// el test (`support.mjs`); los archivos reales se exigen a partir de T-023-10 (`GRAPHICS_REQUIRED`).
import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { GRAPHICS_REQUIRED, checkGraphics, imageInfo } from "../check.mjs";
import { cloneWorld, jpeg, png, put, world } from "./support.mjs";

const LANGS = ["es-ES", "en-US"];
const SHOT = { width: 1080, height: 1920 };
const NAMES = ["1-current-task", "2-task-with-photo", "3-all-tasks", "4-settings"];

let base;
const good = {};
before(() => {
  base = world();
  good.feature = png({ width: 1024, height: 500 });
  good.shot = png(SHOT);
  put(base.paths.featureGraphic, good.feature);
  for (const lang of LANGS) {
    for (const name of NAMES) put(join(base.paths.screenshotsDir, lang, `${name}.png`), good.shot);
  }
});
after(() => base.cleanup());

/** Los errores tras aplicar [mutate(paths)] a una copia del mundo bueno (con las imágenes exigidas). */
function errorsWith(mutate, { requireGraphics = true } = {}) {
  const w = cloneWorld(base);
  try {
    mutate?.(w.paths);
    return checkGraphics(w.paths, { requireGraphics });
  } finally {
    w.cleanup();
  }
}

const shot = (p, lang, name, ext = "png") => join(p.screenshotsDir, lang, `${name}.${ext}`);
const has = (errors, ...res) => errors.some((e) => res.every((r) => r.test(e)));

describe("CA-023-10: el caso bueno", () => {
  test("CA-023-10: icono, gráfico y 4 capturas por idioma pasan", () => {
    assert.deepEqual(errorsWith(), []);
  });

  test("CA-023-10: JPEG también vale para el gráfico y las capturas", () => {
    const errors = errorsWith((p) => {
      rmSync(p.featureGraphic);
      put(join(p.storeDir, "feature-graphic.jpg"), jpeg({ width: 1024, height: 500 }));
      rmSync(shot(p, "es-ES", NAMES[0]));
      put(shot(p, "es-ES", NAMES[0], "jpg"), jpeg(SHOT));
    });
    assert.deepEqual(errors, []);
  });

  test("CA-023-10: el repositorio real, con los gráficos aún sin exigir, pasa", () => {
    assert.equal(GRAPHICS_REQUIRED === true || GRAPHICS_REQUIRED === false, true);
    assert.deepEqual(checkGraphics(base.paths, { requireGraphics: false }), []);
  });
});

describe("CA-023-10: el icono de 512 × 512", () => {
  const withIcon = (bytes) => (p) => writeFileSync(p.icon, bytes);

  test("CA-023-10: otro tamaño falla", () => {
    const errors = errorsWith(withIcon(png({ width: 511, height: 512, colorType: 6 })));
    assert.ok(has(errors, /icon-512\.png/, /511/, /512/), errors.join("\n"));
  });

  test("CA-023-10: sin canal alfa falla (Play pide PNG de 32 bits con alfa)", () => {
    const errors = errorsWith(withIcon(png({ width: 512, height: 512, colorType: 2 })));
    assert.ok(has(errors, /icon-512\.png/, /alfa/), errors.join("\n"));
  });

  test("CA-023-10: más de 1024 KB falla; justo 1024 KB pasa", () => {
    const small = png({ width: 512, height: 512, colorType: 6 });
    const pad = (target) => png({ width: 512, height: 512, colorType: 6, extra: target - small.length - 12 });
    assert.equal(pad(1024 * 1024).length, 1024 * 1024);
    assert.deepEqual(errorsWith(withIcon(pad(1024 * 1024))), []);
    const errors = errorsWith(withIcon(pad(1024 * 1024 + 1)));
    assert.ok(has(errors, /icon-512\.png/, /1024 KB/), errors.join("\n"));
  });

  test("CA-023-10: un JPEG no es un icono válido", () => {
    const errors = errorsWith(withIcon(jpeg({ width: 512, height: 512 })));
    assert.ok(has(errors, /icon-512\.png/), errors.join("\n"));
  });

  test("CA-023-10: sin icono falla, también con los gráficos sin exigir", () => {
    const errors = errorsWith((p) => rmSync(p.icon), { requireGraphics: false });
    assert.ok(has(errors, /icon-512\.png/, /falta/), errors.join("\n"));
  });
});

describe("CA-023-10: el gráfico de funciones de 1024 × 500", () => {
  const withFeature = (bytes, name = "feature-graphic.png") => (p) => {
    rmSync(p.featureGraphic);
    put(join(p.storeDir, name), bytes);
  };

  test("CA-023-10: otro tamaño falla", () => {
    for (const [width, height] of [[1024, 501], [1023, 500], [500, 1024]]) {
      const errors = errorsWith(withFeature(png({ width, height })));
      assert.ok(has(errors, /feature-graphic/, new RegExp(`${width}`), /1024/), `${width}x${height}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-10: con canal alfa (RGBA), con tRNS o en paleta falla", () => {
    for (const opts of [{ colorType: 6 }, { colorType: 2, trns: true }, { colorType: 3 }, { colorType: 4 }]) {
      const errors = errorsWith(withFeature(png({ width: 1024, height: 500, ...opts })));
      assert.ok(has(errors, /feature-graphic/, /24 bits|alfa/), `${JSON.stringify(opts)}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-10: de 16 bits por canal falla (no es de 24 bits)", () => {
    const errors = errorsWith(withFeature(png({ width: 1024, height: 500, bitDepth: 16 })));
    assert.ok(has(errors, /feature-graphic/, /24 bits/), errors.join("\n"));
  });

  test("CA-023-10: un formato que no es PNG ni JPEG (gif, webp) falla", () => {
    for (const name of ["feature-graphic.gif", "feature-graphic.webp"]) {
      const errors = errorsWith(withFeature(Buffer.from("GIF89a....."), name));
      assert.ok(has(errors, /feature-graphic/), `${name}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-10: una extensión que no coincide con el contenido falla", () => {
    const errors = errorsWith(withFeature(jpeg({ width: 1024, height: 500 }), "feature-graphic.png"));
    assert.ok(has(errors, /feature-graphic\.png/, /extensión|contenido/), errors.join("\n"));
  });

  test("CA-023-10: un archivo vacío, truncado o que no es una imagen falla", () => {
    for (const bytes of [Buffer.alloc(0), png({ width: 1024, height: 500 }).subarray(0, 100), Buffer.from("hola, esto no es una imagen")]) {
      const errors = errorsWith(withFeature(bytes));
      assert.ok(has(errors, /feature-graphic/), errors.join("\n"));
    }
  });

  test("CA-023-10: un JPEG de 1024 × 500 pasa y uno de otro tamaño falla", () => {
    assert.deepEqual(errorsWith(withFeature(jpeg({ width: 1024, height: 500 }), "feature-graphic.jpg")), []);
    const errors = errorsWith(withFeature(jpeg({ width: 1024, height: 499 }), "feature-graphic.jpg"));
    assert.ok(has(errors, /feature-graphic\.jpg/, /499/), errors.join("\n"));
  });

  test("CA-023-10: falta: error si se exige, y nada si aún no", () => {
    const miss = (p) => rmSync(p.featureGraphic);
    assert.ok(has(errorsWith(miss), /feature-graphic/, /falta/));
    assert.deepEqual(errorsWith(miss, { requireGraphics: false }), []);
  });

  test("CA-023-10: dos gráficos (png y jpg) a la vez fallan", () => {
    const errors = errorsWith((p) => put(join(p.storeDir, "feature-graphic.jpg"), jpeg({ width: 1024, height: 500 })));
    assert.ok(has(errors, /feature-graphic/, /uno solo|más de un/), errors.join("\n"));
  });
});

describe("CA-023-10: las capturas de 1080 × 1920", () => {
  test("CA-023-10: 1080 × 2400 (la pantalla del emulador) falla y dice que debe ser 1080 × 1920", () => {
    const errors = errorsWith((p) => put(shot(p, "es-ES", NAMES[0]), png({ width: 1080, height: 2400 })));
    assert.ok(has(errors, /es-ES/, /1-current-task/, /1080 × 2400/, /1080 × 1920/), errors.join("\n"));
  });

  test("CA-023-10: 1079 × 1920 y horizontales fallan", () => {
    for (const [width, height] of [[1079, 1920], [1920, 1080]]) {
      const errors = errorsWith((p) => put(shot(p, "en-US", NAMES[2]), png({ width, height })));
      assert.ok(has(errors, /en-US/, /3-all-tasks/), `${width}x${height}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-10: con canal alfa, tRNS o paleta falla (P5: sin alfa)", () => {
    for (const opts of [{ colorType: 6 }, { colorType: 2, trns: true }, { colorType: 3 }]) {
      const errors = errorsWith((p) => put(shot(p, "es-ES", NAMES[3]), png({ ...SHOT, ...opts })));
      assert.ok(has(errors, /es-ES/, /4-settings/, /24 bits|alfa/), `${JSON.stringify(opts)}: ${errors.join("\n")}`);
    }
  });

  test("CA-023-10: tres capturas en un idioma falla; cuatro pasan; cinco fallan", () => {
    let errors = errorsWith((p) => rmSync(shot(p, "en-US", NAMES[3])));
    assert.ok(has(errors, /en-US/, /4 capturas/, /3/), errors.join("\n"));
    errors = errorsWith((p) => put(shot(p, "en-US", "5-extra"), good.shot));
    assert.ok(has(errors, /en-US/, /5-extra/), errors.join("\n"));
  });

  test("CA-023-10: los nombres tienen que ser 1-… a 4-… sin repetir ni saltar", () => {
    let errors = errorsWith((p) => {
      rmSync(shot(p, "es-ES", NAMES[1]));
      put(shot(p, "es-ES", "0-extra"), good.shot);
    });
    assert.ok(has(errors, /es-ES/, /0-extra/), errors.join("\n"));
    errors = errorsWith((p) => {
      rmSync(shot(p, "es-ES", NAMES[1]));
      put(shot(p, "es-ES", "1-otra-vez"), good.shot);
    });
    assert.ok(has(errors, /es-ES/, /1-/, /repetid/), errors.join("\n"));
    errors = errorsWith((p) => {
      rmSync(shot(p, "es-ES", NAMES[1]));
      put(shot(p, "es-ES", "Captura 2"), good.shot);
    });
    assert.ok(has(errors, /es-ES/, /Captura 2/), errors.join("\n"));
  });

  test("CA-023-10: un JPEG de 1080 × 1920 pasa, y otro de otro tamaño falla", () => {
    const bad = errorsWith((p) => {
      rmSync(shot(p, "en-US", NAMES[0]));
      put(shot(p, "en-US", NAMES[0], "jpeg"), jpeg({ width: 1080, height: 2400 }));
    });
    assert.ok(has(bad, /en-US/, /1-current-task\.jpeg/, /2400/), bad.join("\n"));
    const ok = errorsWith((p) => {
      rmSync(shot(p, "en-US", NAMES[0]));
      put(shot(p, "en-US", NAMES[0], "jpeg"), jpeg(SHOT));
    });
    assert.deepEqual(ok, []);
  });

  test("CA-023-10: un idioma sin carpeta o una carpeta de más falla", () => {
    let errors = errorsWith((p) => rmSync(join(p.screenshotsDir, "en-US"), { recursive: true }));
    assert.ok(has(errors, /en-US/, /falta/), errors.join("\n"));
    errors = errorsWith((p) => put(join(p.screenshotsDir, "fr-FR", "1-x.png"), good.shot));
    assert.ok(has(errors, /fr-FR/, /inesperad/), errors.join("\n"));
  });

  test("CA-023-10: las capturas sin exigir (T-023-08): sin carpeta, no hay error; con capturas a medias, sí", () => {
    assert.deepEqual(errorsWith((p) => rmSync(p.screenshotsDir, { recursive: true }), { requireGraphics: false }), []);
    const errors = errorsWith((p) => rmSync(shot(p, "en-US", NAMES[3])), { requireGraphics: false });
    assert.ok(has(errors, /en-US/, /4 capturas/), errors.join("\n"));
  });

  test("CA-023-10: se leen las carpetas que hay (el mundo bueno tiene 8 capturas)", () => {
    assert.equal(readdirSync(join(base.paths.screenshotsDir, "es-ES")).length, 4);
  });
});

describe("CA-023-10: imageInfo lee la cabecera a mano", () => {
  test("CA-023-10: PNG, JPEG y lo demás", () => {
    assert.deepEqual(
      (({ format, width, height, bitDepth, colorType, alpha }) => ({ format, width, height, bitDepth, colorType, alpha }))(
        imageInfo(png({ width: 30, height: 20, colorType: 6 })),
      ),
      { format: "png", width: 30, height: 20, bitDepth: 8, colorType: 6, alpha: true },
    );
    assert.equal(imageInfo(png({ width: 30, height: 20, colorType: 2 })).alpha, false);
    assert.equal(imageInfo(png({ width: 30, height: 20, colorType: 4 })).alpha, true);
    assert.equal(imageInfo(png({ width: 30, height: 20, colorType: 2, trns: true })).alpha, true);
    const j = imageInfo(jpeg({ width: 30, height: 20 }));
    assert.deepEqual([j.format, j.width, j.height, j.alpha], ["jpeg", 30, 20, false]);
    assert.throws(() => imageInfo(Buffer.from("xx")), /imagen/);
    assert.throws(() => imageInfo(Buffer.concat([png({ width: 3, height: 3 }), Buffer.from("x")])), /IEND/);
    const whole = png({ width: 3, height: 3 });
    assert.throws(() => imageInfo(whole.subarray(0, whole.length - 12)), /sin IEND/);
    assert.throws(() => imageInfo(whole.subarray(0, whole.length - 3)), /truncado/);
  });
});
