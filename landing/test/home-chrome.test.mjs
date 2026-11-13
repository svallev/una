// La cabecera y el pie de la página de inicio (spec 025; plan §2 y §6.2): el logotipo y el nombre salen de la
// identidad (CA-025-14), los destinos de los enlaces (CA-025-20: portada, cierre, `/help`, `/privacy` y
// `/licenses`, nada de otro sitio), el control ES / EN con nombre accesible (CA-025-09, Q-025-6) y los
// objetivos de 44 × 44 declarados en el CSS (CA-025-15).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";
import { defaultPaths, homeSite } from "../build.mjs";
import { DOWNLOAD_HREF, FOOTER_LINKS, HOME_HREF, LANG_CODES, footerHtml, headerHtml, wireLangButtons } from "../home/src/chrome.js";

const strings = {
  es: JSON.parse(readFileSync(new URL("../home/src/strings.es.json", import.meta.url), "utf8")),
  en: JSON.parse(readFileSync(new URL("../home/src/strings.en.json", import.meta.url), "utf8")),
};
const tokens = JSON.parse(readFileSync(defaultPaths().tokens, "utf8"));
const site = homeSite(defaultPaths());
const named = (text, name = site.appName) => text.replaceAll("{appName}", name);

const openTags = (html) =>
  [...html.matchAll(/<([a-z]+)((?:\s+[a-z-]+(?:="[^"]*")?)*)\s*>/g)].map((m) => ({
    name: m[1],
    attrs: Object.fromEntries([...m[2].matchAll(/([a-z-]+)(?:="([^"]*)")?/g)].map((a) => [a[1], a[2] ?? ""])),
  }));
/** El elemento con [cls] (primera aparición): atributos y contenido. */
const element = (html, tag, cls) => {
  const m = new RegExp(`<${tag} class="${cls}"([^>]*)>([\\s\\S]*?)</${tag}>`).exec(html);
  assert.ok(m, `no encuentro <${tag} class="${cls}"> en:\n${html}`);
  return { attrs: m[1], body: m[2] };
};
const attr = (attrs, name) => new RegExp(`\\b${name}="([^"]*)"`).exec(attrs)?.[1];
const textOf = (body) => body.replace(/<svg[\s\S]*?<\/svg>/g, "").replace(/<[^>]*>/g, "").trim();

describe("CA-025-14 y CA-025-20: la cabecera", () => {
  for (const lang of ["es", "en"]) {
    const s = strings[lang];
    const html = headerHtml({ strings: s, site, lang });

    test(`${lang}: el logotipo es el de la identidad, vuelve a la portada y su nombre es «${named(s.navHome)}»`, () => {
      const logo = element(html, "a", "logo");
      assert.equal(textOf(logo.body), site.wordmark);
      assert.equal(attr(logo.attrs, "href"), HOME_HREF);
      assert.equal(HOME_HREF, "/");
      assert.equal(attr(logo.attrs, "aria-label"), named(s.navHome));
    });

    test(`${lang}: «${s.navDownload}» lleva al cierre y su nombre es su texto`, () => {
      const dl = element(html, "a", "download");
      assert.equal(attr(dl.attrs, "href"), DOWNLOAD_HREF);
      assert.equal(DOWNLOAD_HREF, "/#download");
      assert.equal(textOf(dl.body), s.navDownload);
      assert.equal(attr(dl.attrs, "aria-label"), undefined, "sin aria-label: el nombre es el texto visible (2.5.3)");
      assert.ok(/<svg[^>]*aria-hidden="true"/.test(dl.body), "la flecha no se lee");
    });

    test(`${lang}: ES / EN, un grupo con nombre y un botón por idioma con su nombre en su idioma`, () => {
      const group = element(html, "div", "langs");
      assert.equal(attr(group.attrs, "role"), "group");
      assert.equal(attr(group.attrs, "aria-label"), s.navLanguage);
      const buttons = openTags(group.body).filter((t) => t.name === "button");
      assert.deepEqual(buttons.map((b) => b.attrs["data-lang"]), LANG_CODES);
      assert.deepEqual(LANG_CODES, ["es", "en"]);
      for (const b of buttons) {
        assert.equal(b.attrs.type, "button");
        assert.equal(b.attrs.class, "langs__btn");
        assert.equal(b.attrs.lang, b.attrs["data-lang"], "cada nombre se lee en su idioma");
        assert.equal(b.attrs["aria-label"], b.attrs["data-lang"] === "es" ? s.navLanguageEs : s.navLanguageEn);
        assert.equal(b.attrs["aria-pressed"], String(b.attrs["data-lang"] === lang), "dice cuál está elegido");
      }
      assert.deepEqual([...group.body.matchAll(/<button[^>]*>([^<]*)<\/button>/g)].map((m) => m[1]), ["ES", "EN"]);
    });
  }

  test("un idioma que no es de la página no se acepta", () => {
    assert.throws(() => headerHtml({ strings: strings.es, site, lang: "fr" }), /idioma/);
  });

  test("con otro nombre y textos hostiles, todo sale escapado", () => {
    const hostile = { ...strings.es, navHome: '{appName}"><script>', navDownload: "<b>x</b>", navLanguage: "\"'" };
    const html = headerHtml({ strings: hostile, site: { ...site, appName: "Zorro & <i>", wordmark: "<z>" }, lang: "es" });
    assert.ok(!/<script|<b>|<i>|<z>/.test(html), html);
    assert.ok(html.includes("Zorro &amp; &lt;i&gt;&quot;&gt;&lt;script&gt;") && html.includes("&lt;z&gt;"), html);
  });
});

describe("CA-025-20: el pie", () => {
  for (const lang of ["es", "en"]) {
    const s = strings[lang];
    const html = footerHtml({ strings: s, site });

    test(`${lang}: Ayuda, Privacidad y Licencias abren /help, /privacy y /licenses`, () => {
      const nav = element(html, "nav", "end__nav");
      assert.equal(attr(nav.attrs, "aria-label"), s.footerNav);
      const links = [...nav.body.matchAll(/<a class="end__link" href="([^"]*)">([^<]*)<\/a>/g)].map((m) => [m[1], m[2]]);
      assert.deepEqual(links, [["/help", s.footerHelp], ["/privacy", s.footerPrivacy], ["/licenses", s.footerLicenses]]);
      assert.deepEqual(FOOTER_LINKS.map(([href]) => href), ["/help", "/privacy", "/licenses"]);
    });

    test(`${lang}: la línea legal lleva el nombre de la identidad`, () => {
      assert.equal(textOf(element(html, "p", "end__legal").body), named(s.footerLegal));
    });
  }

  test("ningún enlace a otro sitio en la cabecera ni en el pie", () => {
    for (const lang of ["es", "en"]) {
      const html = headerHtml({ strings: strings[lang], site, lang }) + footerHtml({ strings: strings[lang], site });
      const hrefs = openTags(html).filter((t) => "href" in t.attrs).map((t) => t.attrs.href);
      assert.equal(hrefs.length, 5);
      for (const h of hrefs) assert.match(h, /^\/(?!\/)/, `«${h}» no es una ruta de esta web`);
    }
  });
});

describe("CA-025-09: el control de idioma", () => {
  /** Botones de mentira con `dataset.lang` y sus oyentes. */
  const fakeHeader = (codes) => {
    const buttons = codes.map((code) => {
      const listeners = new Set();
      return {
        dataset: { lang: code },
        addEventListener: (type, fn) => type === "click" && listeners.add(fn),
        removeEventListener: (type, fn) => type === "click" && listeners.delete(fn),
        click: () => [...listeners].forEach((fn) => fn({ preventDefault() {} })),
        listeners,
      };
    });
    return { buttons, querySelectorAll: (sel) => (sel === ".langs__btn" ? buttons : []) };
  };

  test("pulsar el otro idioma lo pide; el que ya está, no; un valor raro, tampoco", () => {
    const header = fakeHeader(["es", "en", "__proto__"]);
    const chosen = [];
    const stop = wireLangButtons(header, { current: "es", onChoose: (l) => chosen.push(l) });
    header.buttons[0].click();
    header.buttons[1].click();
    header.buttons[2].click();
    assert.deepEqual(chosen, ["en"]);
    stop();
    assert.ok(header.buttons.every((b) => b.listeners.size === 0), "se quitan los oyentes");
  });
});

// ─── Objetivos de 44 × 44 (CA-025-15; plan §6.2) ────────────────────────────────────────────────

const CSS = readFileSync(new URL("../home/src/base.css", import.meta.url), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
/** Las declaraciones de todas las reglas (también dentro de `@media`) cuyo selector incluye [selector]. */
const declarations = (selector) =>
  [...CSS.matchAll(/([^{}]+)\{([^{}]*)\}/g)]
    .filter((m) => m[1].split(",").map((x) => x.trim()).includes(selector))
    .flatMap((m) => m[2].split(";").map((d) => d.trim()).filter(Boolean).map((d) => d.split(/:(.*)/s).slice(0, 2).map((x) => x.trim())));
const TARGET = "var(--size-min-touch-target)";
const atLeastTarget = (value) => value === TARGET || new RegExp(`^calc\\(${TARGET.replace(/[()]/g, "\\$&")} \\+ var\\(--space-[a-z]+\\)\\)$`).test(value);

describe("CA-025-15: la cabecera, los enlaces del pie y los rótulos con enlace miden 44 × 44 o más", () => {
  test("el token del objetivo mínimo es de 44 px", () => {
    assert.deepEqual(tokens.size.minTouchTarget.$value, { value: 44, unit: "px" });
  });

  for (const selector of [".logo", ".langs__btn", ".download", ".end__link", "a.store"]) {
    test(`${selector}: min-width y min-height del objetivo mínimo, y nada que lo limite`, () => {
      const decls = declarations(selector);
      assert.ok(decls.length > 0, `no hay reglas para ${selector}`);
      for (const prop of ["min-width", "min-height"]) {
        const values = decls.filter(([p]) => p === prop).map(([, v]) => v);
        assert.ok(values.length > 0, `${selector} no declara ${prop}`);
        for (const v of values) assert.ok(atLeastTarget(v), `${selector} { ${prop}: ${v} } no llega a 44`);
      }
      const limits = decls.filter(([p]) => ["width", "height", "max-width", "max-height"].includes(p));
      assert.deepEqual(limits, [], `${selector} no puede fijar ni limitar su tamaño`);
    });
  }

  test("en pantallas estrechas, el texto de «Descargar» se oculta a la vista, no al lector", () => {
    const hidden = declarations(".download__label").filter(([p, v]) => (p === "display" && v === "none") || (p === "visibility" && v === "hidden"));
    assert.deepEqual(hidden, [], "con display: none el enlace se quedaría sin nombre");
  });
});
