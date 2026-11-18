// El programa de idioma de las páginas de contenido (spec 026, plan §2.3): se ejecuta en `node:vm` con objetos
// falsos de `document`, `location`, `navigator`, `localStorage` e `history` (sin navegador en la CI).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, test } from "node:test";
import vm from "node:vm";

const SOURCE = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "src", "lang.js"), "utf8");

/** Un enlace del selector (`.langs a[hreflang]`). */
function fakeLink(lang) {
  const listeners = {};
  return {
    hreflang: lang,
    attrs: {},
    listeners,
    focusCalls: 0,
    getAttribute(name) {
      return name === "hreflang" ? lang : (this.attrs[name] ?? null);
    },
    setAttribute(name, value) {
      this.attrs[name] = String(value);
    },
    addEventListener(type, fn) {
      (listeners[type] ??= []).push(fn);
    },
    focus() {
      this.focusCalls += 1;
    },
  };
}

/** Un `<details>` (un grupo de avisos, spec 027) que apunta cada cambio de su estado abierto en `changes`. */
function fakeDetails(initial) {
  let open = initial;
  const changes = [];
  return {
    tagName: "DETAILS",
    changes,
    get open() {
      return open;
    },
    set open(value) {
      changes.push(["open", value]);
      open = Boolean(value);
    },
    setAttribute(name, value) {
      changes.push(["setAttribute", name, value]);
    },
    removeAttribute(name) {
      changes.push(["removeAttribute", name]);
    },
    toggleAttribute(name) {
      changes.push(["toggleAttribute", name]);
    },
  };
}

/** Un evento falso que recuerda si se llamó a `preventDefault`. */
function fakeEvent(props = {}) {
  return { defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, ...props };
}

/**
 * Monta el entorno y ejecuta el programa. [stored] es lo guardado (`undefined` = nada), [storage] `"throws"`
 * hace que leer y escribir lancen, [readyState] `"loading"` (en el `<head>`) o `"interactive"`.
 */
function run({
  hash = "",
  search = "",
  pathname = "/help",
  stored,
  storage = "ok",
  language = "es-ES",
  readyState = "loading",
  titles = { titleEs: "Ayuda · Una", titleEn: "Help · Una" },
  titleThrows = false,
  details = [],
} = {}) {
  const store = new Map(stored === undefined ? [] : [["una-lang", stored]]);
  const writes = [];
  const localStorage = {
    getItem(key) {
      if (storage === "throws") throw new Error("SecurityError");
      return store.has(key) ? store.get(key) : null;
    },
    setItem(key, value) {
      if (storage === "throws") throw new Error("QuotaExceededError");
      writes.push([key, value]);
      store.set(key, String(value));
    },
  };
  const html = { lang: "es", dataset: { ...titles } };
  const links = [fakeLink("es"), fakeLink("en")];
  const docListeners = {};
  const winListeners = {};
  let title = "Ayuda · Una / Help · Una";
  // Los grupos de avisos (spec 027): `<details>` falsos que apuntan cualquier cambio de su estado abierto.
  const groups = details.map((open) => fakeDetails(open));
  const document = {
    documentElement: html,
    getElementsByTagName(name) {
      return name.toLowerCase() === "details" ? groups : [];
    },
    getElementById() {
      return null;
    },
    readyState,
    activeElement: null,
    get title() {
      return title;
    },
    set title(value) {
      if (titleThrows) throw new Error("forzado");
      title = value;
    },
    querySelectorAll(selector) {
      assert.equal(selector, ".langs a[hreflang]");
      return this.readyState === "loading" ? [] : links;
    },
    addEventListener(type, fn) {
      (docListeners[type] ??= []).push(fn);
    },
  };
  const location = { hash, search, pathname, href: `https://example.test${pathname}${search}${hash}` };
  const replaced = [];
  const history = {
    state: { kept: true },
    replaceState(state, unused, url) {
      replaced.push({ state, unused, url });
      const i = url.indexOf("#");
      location.hash = i < 0 ? "" : url.slice(i);
    },
  };
  const context = {
    document,
    location,
    history,
    navigator: { language },
    addEventListener(type, fn) {
      (winListeners[type] ??= []).push(fn);
    },
  };
  Object.defineProperty(context, "localStorage", {
    get() {
      if (storage === "throws") throw new Error("SecurityError");
      return localStorage;
    },
  });
  context.window = context;
  vm.createContext(context);
  vm.runInContext(SOURCE, context, { filename: "lang.js" });

  const fire = (map, type, event = fakeEvent()) => {
    for (const fn of map[type] ?? []) fn(event);
    return event;
  };
  const env = {
    html,
    links,
    groups,
    store,
    writes,
    replaced,
    location,
    history,
    get title() {
      return title;
    },
    /** Termina de leerse la página (`DOMContentLoaded`). */
    loaded() {
      document.readyState = "interactive";
      fire(docListeners, "DOMContentLoaded");
    },
    click(lang) {
      const link = links.find((l) => l.hreflang === lang);
      return fire(link.listeners, "click");
    },
    key(lang, key) {
      const link = links.find((l) => l.hreflang === lang);
      return fire(link.listeners, "keydown", fakeEvent({ key }));
    },
    hashChange(next) {
      location.hash = next;
      fire(winListeners, "hashchange");
    },
    pageshow(persisted) {
      fire(winListeners, "pageshow", fakeEvent({ persisted }));
    },
    docListeners,
    winListeners,
  };
  return env;
}

const pressed = (env) => Object.fromEntries(env.links.map((l) => [l.hreflang, l.attrs["aria-pressed"]]));

describe("CA-026-06: qué idioma sale", () => {
  // La tabla de la spec, fila a fila (`undefined` = nada guardado).
  const rows = [
    ["en", "es-ES", "en"],
    ["es", "en-US", "es"],
    [undefined, "es-MX", "es"],
    [undefined, "ca-ES", "es"],
    [undefined, "fr-FR", "en"],
    [undefined, "en-GB", "en"],
    [undefined, "gl-ES", "en"],
    ["xx", "fr-FR", "en"],
    ["es-MX", "fr-FR", "en"],
    ["", "fr-FR", "en"],
    ["xx", "es-ES", "es"],
    [undefined, "", "es"],
  ];
  for (const [stored, language, expected] of rows) {
    test(`CA-026-06: guardado ${JSON.stringify(stored ?? "—")}, navegador ${JSON.stringify(language)} → ${expected}`, () => {
      const env = run({ stored, language });
      assert.equal(env.html.dataset.lang, expected);
      assert.equal(env.html.lang, expected);
    });
  }

  test("CA-026-06: sin idioma en el navegador (`undefined`), español", () => {
    const env = run({ language: undefined });
    assert.equal(env.html.dataset.lang, "es");
  });

  test("CA-026-06: el título de la pestaña y el idioma declarado son los del idioma que sale", () => {
    const es = run({ language: "es-ES" });
    assert.equal(es.title, "Ayuda · Una");
    assert.equal(es.html.lang, "es");
    const en = run({ language: "en-US" });
    assert.equal(en.title, "Help · Una");
    assert.equal(en.html.lang, "en");
  });

  test("CA-026-06: decide en el `<head>`, antes de que exista el selector (sin esperar a la página)", () => {
    const env = run({ language: "en-US", readyState: "loading" });
    assert.equal(env.html.dataset.lang, "en");
    assert.deepEqual(pressed(env), { es: undefined, en: undefined });
  });

  test("CA-026-06: no guarda nada al decidir", () => {
    const env = run({ language: "en-US" });
    assert.deepEqual(env.writes, []);
  });

  test("CA-026-06: `?lang=` no cambia nada", () => {
    for (const search of ["?lang=en", "?lang=es"]) {
      assert.equal(run({ search, language: "es-ES" }).html.dataset.lang, "es", search);
      assert.equal(run({ search, language: "fr-FR" }).html.dataset.lang, "en", search);
      assert.equal(run({ search, stored: "en", language: "es-ES" }).html.dataset.lang, "en", search);
    }
  });
});

describe("CL-026-2: el ancla manda, sin guardarse", () => {
  const cases = [
    ["#es", "en", "en-US", "es"],
    ["#en", "es", "es-ES", "en"],
    ["#es-ajustes", "en", "en-US", "es"],
    ["#en-settings", "es", "es-ES", "en"],
    ["#es-toc", undefined, "fr-FR", "es"],
  ];
  for (const [hash, stored, language, expected] of cases) {
    test(`CA-026-06: ${hash} con ${stored ?? "nada"} guardado y ${language} → ${expected}`, () => {
      const env = run({ hash, stored, language });
      assert.equal(env.html.dataset.lang, expected);
      assert.deepEqual(env.writes, []);
      assert.equal(env.store.get("una-lang"), stored);
    });
  }

  // Anclas que no son de un idioma: se ignoran y manda lo guardado o el navegador; nada falla.
  const ignored = ["#xx", "#esx", "#ES", "#EN", "#es%2Dajustes", "#en%2D", "#enes", "#-es", "# es", "#x#es", "#x#en-settings", `#es${"x".repeat(100000)}`];
  for (const hash of ignored) {
    test(`CA-026-06: el ancla ${JSON.stringify(hash.slice(0, 20))} no marca idioma`, () => {
      assert.equal(run({ hash, stored: "en", language: "es-ES" }).html.dataset.lang, "en");
      assert.equal(run({ hash, language: "es-ES" }).html.dataset.lang, "es");
      assert.equal(run({ hash, language: "fr-FR" }).html.dataset.lang, "en");
    });
  }

  test("CA-026-06: un ancla de idioma muy larga sigue valiendo", () => {
    const env = run({ hash: `#en-${"a".repeat(100000)}`, language: "es-ES" });
    assert.equal(env.html.dataset.lang, "en");
  });
});

describe("CA-026-07: el selector", () => {
  test("CA-026-07: al terminar de leerse la página, cada opción es un botón con su estado", () => {
    const env = run({ language: "en-US" });
    env.loaded();
    for (const link of env.links) assert.equal(link.attrs.role, "button");
    assert.deepEqual(pressed(env), { es: "false", en: "true" });
  });

  test("CA-026-07: si la página ya está leída al ejecutarse, engancha el selector enseguida", () => {
    const env = run({ language: "es-ES", readyState: "interactive" });
    for (const link of env.links) assert.equal(link.attrs.role, "button");
    assert.deepEqual(pressed(env), { es: "true", en: "false" });
  });

  for (const how of ["click", "space"]) {
    test(`CA-026-07: ${how === "click" ? "clic (o Intro)" : "Espacio"} en el otro idioma cambia la página entera sin navegar`, () => {
      const env = run({ language: "es-ES" });
      env.loaded();
      const event = how === "click" ? env.click("en") : env.key("en", " ");
      assert.equal(event.defaultPrevented, true, "no debe seguir el enlace a #en ni desplazar");
      assert.equal(env.html.dataset.lang, "en");
      assert.equal(env.html.lang, "en");
      assert.equal(env.title, "Help · Una");
      assert.deepEqual(pressed(env), { es: "false", en: "true" });
      assert.deepEqual(env.writes, [["una-lang", "en"]]);
      for (const link of env.links) assert.equal(link.focusCalls, 0, "el foco no se mueve");
      // Y de vuelta.
      how === "click" ? env.click("es") : env.key("es", " ");
      assert.equal(env.html.dataset.lang, "es");
      assert.equal(env.title, "Ayuda · Una");
      assert.deepEqual(pressed(env), { es: "true", en: "false" });
      assert.deepEqual(env.writes, [["una-lang", "en"], ["una-lang", "es"]]);
    });
  }

  test("CA-026-07: las demás teclas no hacen nada (Intro llega como clic)", () => {
    const env = run({ language: "es-ES" });
    env.loaded();
    for (const key of ["Enter", "a", "Tab", "ArrowRight"]) {
      const event = env.key("en", key);
      assert.equal(event.defaultPrevented, false, key);
    }
    assert.equal(env.html.dataset.lang, "es");
    assert.deepEqual(env.writes, []);
  });

  test("CA-026-07: pulsar el idioma que ya está no hace nada (ni navega)", () => {
    const env = run({ stored: "en", language: "es-ES" });
    env.loaded();
    for (const event of [env.click("en"), env.key("en", " ")]) assert.equal(event.defaultPrevented, true);
    assert.equal(env.html.dataset.lang, "en");
    assert.deepEqual(env.writes, []);
    assert.deepEqual(env.replaced, []);
  });

  test("CL-026-2: cambiar quita de la dirección el ancla del otro idioma (sin `#`, mismo camino)", () => {
    for (const hash of ["#es", "#es-ajustes"]) {
      const env = run({ hash, search: "?q=1", pathname: "/privacy", stored: "en" });
      env.loaded();
      assert.equal(env.html.dataset.lang, "es");
      env.click("en");
      assert.equal(env.html.dataset.lang, "en");
      assert.equal(env.replaced.length, 1, hash);
      const [{ state, unused, url }] = env.replaced;
      assert.equal(url, "/privacy?q=1");
      assert.ok(!url.includes("#"));
      assert.equal(unused, "");
      assert.deepEqual(state, { kept: true });
    }
  });

  test("CL-026-2: un ancla que no es del otro idioma se queda", () => {
    const env = run({ hash: "#xx", language: "es-ES" });
    env.loaded();
    env.click("en");
    assert.deepEqual(env.replaced, []);
  });

  test("CL-026-4: sin almacenamiento (leer y escribir lanzan), decide por el navegador y el selector funciona", () => {
    const env = run({ storage: "throws", language: "fr-FR" });
    assert.equal(env.html.dataset.lang, "en");
    env.loaded();
    env.click("es");
    assert.equal(env.html.dataset.lang, "es");
    assert.equal(env.title, "Ayuda · Una");
    assert.deepEqual(pressed(env), { es: "true", en: "false" });
  });
});

describe("CL-026-2 y CL-026-8: anclas nuevas y vuelta atrás", () => {
  test("CL-026-2: `hashchange` a un ancla de idioma lo aplica sin guardarlo", () => {
    const env = run({ stored: "es", language: "es-ES" });
    env.loaded();
    env.hashChange("#en-settings");
    assert.equal(env.html.dataset.lang, "en");
    assert.deepEqual(pressed(env), { es: "false", en: "true" });
    env.hashChange("#es");
    assert.equal(env.html.dataset.lang, "es");
    assert.deepEqual(env.writes, []);
  });

  test("CL-026-2: `hashchange` a otra ancla no cambia el idioma", () => {
    const env = run({ stored: "en", language: "es-ES" });
    env.loaded();
    env.click("es");
    env.hashChange("#xx");
    assert.equal(env.html.dataset.lang, "es");
    env.hashChange("");
    assert.equal(env.html.dataset.lang, "es");
  });

  test("CL-026-2: tras abrir con un ancla de idioma, otra ancla (o ninguna) no vuelve a lo guardado", () => {
    const env = run({ hash: "#en", stored: "es", language: "es-ES" });
    env.loaded();
    assert.equal(env.html.dataset.lang, "en");
    env.hashChange("#xx");
    assert.equal(env.html.dataset.lang, "en");
    env.hashChange("");
    assert.equal(env.html.dataset.lang, "en");
  });

  test("CL-026-8: `pageshow` desde la memoria del navegador aplica lo guardado ahora", () => {
    const env = run({ stored: "es", language: "es-ES" });
    env.loaded();
    env.store.set("una-lang", "en"); // cambiado en otra página
    env.pageshow(true);
    assert.equal(env.html.dataset.lang, "en");
    assert.equal(env.title, "Help · Una");
    assert.deepEqual(pressed(env), { es: "false", en: "true" });
  });

  test("CL-026-8: `pageshow` de una carga normal no hace nada más", () => {
    const env = run({ stored: "es", language: "es-ES" });
    env.loaded();
    env.store.set("una-lang", "en");
    env.pageshow(false);
    assert.equal(env.html.dataset.lang, "es");
  });

  test("CL-026-7: no escucha `storage` (la otra pestaña no cambia)", () => {
    const env = run();
    assert.equal(env.winListeners.storage, undefined);
    assert.deepEqual(Object.keys(env.winListeners).sort(), ["hashchange", "pageshow"]);
  });
});

describe("CL-026-5: si el programa falla, no marca `<html>`", () => {
  test("CA-026-09: con el título forzado a fallar, `<html>` queda sin `data-lang` y sin errores fuera", () => {
    const env = run({ language: "en-US", titleThrows: true });
    assert.equal(env.html.dataset.lang, undefined);
  });

  test("CA-026-09: sin textos del título en `<html>`, tampoco marca nada", () => {
    const env = run({ language: "en-US", titles: {} });
    assert.equal(env.html.dataset.lang, undefined);
  });

  test("CA-026-09: si falla al cambiar, la página sigue como estaba y el clic no lanza", () => {
    const env = run({ language: "es-ES" });
    env.loaded();
    delete env.html.dataset.titleEn;
    env.click("en");
    assert.equal(env.html.dataset.lang, "es");
    assert.deepEqual(env.writes, []);
  });
});

describe("CA-027-04: cambiar de idioma no cambia qué grupos de avisos están abiertos", () => {
  test("CA-027-04: clic, Espacio y anclas de idioma no tocan el estado abierto de ningún <details>", () => {
    const env = run({ language: "es-ES", pathname: "/licenses", details: [true, false, true] });
    env.loaded();
    env.click("en");
    env.key("es", " ");
    env.hashChange("#en");
    env.hashChange("#es-x");
    env.pageshow(true);
    assert.equal(env.html.dataset.lang, "es");
    assert.deepEqual(env.groups.map((g) => g.open), [true, false, true]);
    for (const g of env.groups) assert.deepEqual(g.changes, []);
  });

  test("CA-027-06: el salto a #notices-end no se toma por un idioma", () => {
    const env = run({ stored: "en", language: "es-ES", pathname: "/licenses", details: [false] });
    env.loaded();
    env.hashChange("#notices-end");
    assert.equal(env.html.dataset.lang, "en");
    assert.deepEqual(env.writes, []);
    const opened = run({ hash: "#notices-end", stored: "en", pathname: "/licenses" });
    assert.equal(opened.html.dataset.lang, "en", "abrir la página con ese ancla tampoco");
  });
});

