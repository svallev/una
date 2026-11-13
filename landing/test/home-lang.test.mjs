// El idioma de la página de inicio (spec 025, CA-025-09; CL-025-3, 4 y 16): la regla de la app con la lista
// de casos de la spec, lo guardado (que manda, y que se valida) y el idioma declarado en el documento.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, test } from "node:test";
import { defaultPaths } from "../build.mjs";
import {
  LANG_KEY,
  applyLang,
  browserStorage,
  langFromList,
  pickLang,
  plainTitle,
  saveLang,
  storedLang,
  withName,
} from "../home/src/lang.js";

const HOME_SRC = join(defaultPaths().homeDir, "src");
const strings = {
  es: JSON.parse(readFileSync(join(HOME_SRC, "strings.es.json"), "utf8")),
  en: JSON.parse(readFileSync(join(HOME_SRC, "strings.en.json"), "utf8")),
};

/** Un `localStorage` de mentira; con [broken] lanza en cada operación (almacenamiento bloqueado). */
function memoryStorage(initial = {}, { broken = false } = {}) {
  const data = new Map(Object.entries(initial));
  return {
    data,
    getItem(k) {
      if (broken) throw new Error("SecurityError");
      return data.has(k) ? data.get(k) : null;
    },
    setItem(k, v) {
      if (broken) throw new Error("QuotaExceededError");
      data.set(k, String(v));
    },
  };
}

describe("CA-025-09: la regla de idioma de la app, con los casos de la spec", () => {
  const cases = [
    [["es-MX"], "es"],
    [["ca-ES", "en-US"], "es"],
    [["fr-FR", "es-ES"], "es"],
    [["en-GB", "es-ES"], "en"],
    [["gl-ES"], "en"],
    [["eu"], "en"],
    [["de"], "en"],
    [[], "en"],
  ];
  for (const [list, expected] of cases) {
    test(`${JSON.stringify(list)} → ${expected.toUpperCase()}`, () => {
      assert.equal(langFromList(list), expected);
      assert.equal(pickLang({ languages: list }), expected);
    });
  }

  test("se mira la subetiqueta principal entera, sin importar mayúsculas ni el guion bajo", () => {
    assert.equal(langFromList(["ES"]), "es");
    assert.equal(langFromList(["es_ES"]), "es");
    assert.equal(langFromList(["CA"]), "es");
    assert.equal(langFromList(["EN-us"]), "en");
    // «español», «cat» o «eng» no son español, catalán ni inglés: sigue la lista.
    assert.equal(langFromList(["español", "es"]), "es");
    assert.equal(langFromList(["cat", "fr"]), "en");
    assert.equal(langFromList(["eng", "es"]), "es");
  });

  test("valores que no son una lista o elementos que no son texto se ignoran", () => {
    assert.equal(langFromList(undefined), "en");
    assert.equal(langFromList("es"), "en");
    assert.equal(langFromList([null, 3, { toString: () => "es" }, "es-AR"]), "es");
  });

  test("sin lista, el idioma principal del navegador; sin nada, inglés", () => {
    assert.equal(pickLang({ languages: [], language: "es-ES" }), "es");
    assert.equal(pickLang({ languages: undefined, language: "ca" }), "es");
    assert.equal(pickLang({ language: "pt-BR" }), "en");
    assert.equal(pickLang(), "en");
    assert.equal(pickLang({ languages: ["en-US"], language: "es" }), "en", "la lista manda sobre el idioma principal");
  });
});

describe("CA-025-09: la elección guardada manda y se recuerda", () => {
  test("lo guardado manda sobre el navegador, en los dos sentidos", () => {
    assert.equal(pickLang({ storage: memoryStorage({ [LANG_KEY]: "en" }), languages: ["es-ES"] }), "en");
    assert.equal(pickLang({ storage: memoryStorage({ [LANG_KEY]: "es" }), languages: ["de"] }), "es");
  });

  test("guardar y leer de nuevo da el mismo idioma (la siguiente visita)", () => {
    const storage = memoryStorage();
    assert.equal(saveLang(storage, "es"), true);
    assert.equal(storage.data.get(LANG_KEY), "es");
    assert.equal(pickLang({ storage, languages: ["en-US"] }), "es");
    assert.equal(saveLang(storage, "en"), true);
    assert.equal(pickLang({ storage, languages: ["es-ES"] }), "en");
  });

  test("solo se guarda «es» o «en», en la única clave", () => {
    const storage = memoryStorage();
    for (const bad of ["fr", "ES", "es-ES", "", null, undefined, "__proto__", "<img>"]) {
      assert.equal(saveLang(storage, bad), false, `guardó ${String(bad)}`);
    }
    assert.equal(storage.data.size, 0);
    saveLang(storage, "en");
    assert.deepEqual([...storage.data.keys()], [LANG_KEY]);
    assert.equal(LANG_KEY, "lang");
  });
});

describe("CL-025-16: un valor guardado que no es válido se ignora", () => {
  for (const bad of ["fr", "ES", "En", " es", "es ", "es-ES", "", "null", "__proto__", "constructor", "toString", "<img src=x>", "#hero"]) {
    test(`«${bad}» → la regla del navegador`, () => {
      assert.equal(storedLang(memoryStorage({ [LANG_KEY]: bad })), null);
      assert.equal(pickLang({ storage: memoryStorage({ [LANG_KEY]: bad }), languages: ["es-ES"] }), "es");
      assert.equal(pickLang({ storage: memoryStorage({ [LANG_KEY]: bad }), languages: ["de"] }), "en");
    });
  }

  test("un almacenamiento que devuelve algo que no es texto se ignora", () => {
    const odd = { getItem: () => ({ toString: () => "es" }) };
    assert.equal(storedLang(odd), null);
  });
});

describe("CL-025-3: almacenamiento bloqueado o roto", () => {
  test("leer `window.localStorage` lanza: sin almacenamiento, sin error", () => {
    const win = {
      get localStorage() {
        throw new Error("SecurityError");
      },
    };
    assert.equal(browserStorage(win), null);
    assert.equal(browserStorage(undefined), null);
    assert.equal(pickLang({ storage: browserStorage(win), languages: ["es"] }), "es");
  });

  test("getItem y setItem lanzan: la página sigue con la regla y no guarda", () => {
    const storage = memoryStorage({ [LANG_KEY]: "en" }, { broken: true });
    assert.equal(storedLang(storage), null);
    assert.equal(pickLang({ storage, languages: ["es-ES"] }), "es");
    assert.doesNotThrow(() => saveLang(storage, "en"));
    assert.equal(saveLang(storage, "en"), false);
    assert.equal(saveLang(null, "en"), false);
  });

  test("con el almacenamiento disponible, `browserStorage` lo devuelve", () => {
    const storage = memoryStorage();
    assert.equal(browserStorage({ localStorage: storage }), storage);
  });
});

describe("CA-025-09: idioma declarado, título y descripción", () => {
  /** Un documento de mentira con lo que toca `applyLang`. */
  function fakeDoc() {
    const description = { attrs: {}, setAttribute(k, v) {
      this.attrs[k] = v;
    } };
    return {
      documentElement: { lang: "es" },
      title: "",
      description,
      querySelector: (sel) => (sel === 'meta[name="description"]' ? description : null),
    };
  }

  for (const lang of ["es", "en"]) {
    test(`${lang}: <html lang>, título y descripción en ese idioma, con el nombre de la identidad`, () => {
      const doc = fakeDoc();
      applyLang(doc, lang, strings[lang], "Zorro");
      assert.equal(doc.documentElement.lang, lang);
      assert.equal(doc.title, strings[lang].metaTitle.replace("{appName}", "Zorro"));
      assert.equal(doc.description.attrs.content, strings[lang].metaDescription.replace("{appName}", "Zorro"));
      assert.ok(!doc.title.includes("{"), doc.title);
    });
  }

  test("un idioma que no es «es» ni «en» no se declara", () => {
    const doc = fakeDoc();
    assert.throws(() => applyLang(doc, "fr", strings.es, "Zorro"));
    assert.equal(doc.documentElement.lang, "es");
  });

  test("los textos se rellenan sin interpretar el nombre y los titulares se leen como una frase", () => {
    assert.equal(withName("{appName} — x {appName}", "$& <b>"), "$& <b> — x $& <b>");
    assert.equal(plainTitle("Solo *una*.|Hasta que|la termines"), "Solo una. Hasta que la termines");
  });
});
