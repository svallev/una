// Las tiendas en la página de inicio (spec 025, CA-025-08 enmendado el 2026-11-13, CL-025-8; plan §6.1 y §6.2):
// un rótulo propio por tienda, App Store primero, sin imágenes de las tiendas; sin dirección no es un enlace
// («(muy pronto)» en un `span` oculto a la vista, sin `role`, `tabindex` ni `aria-disabled`); con dirección,
// enlaza a la ficha. «Muy pronto» sobre los rótulos de la portada mientras falte alguna, y la entradilla del
// cierre según las que haya. Los cuatro casos: ninguna, solo Google Play, solo App Store y las dos.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";
import { endLeadKey as buildEndLeadKey } from "../build.mjs";
import { STORES, endLeadKey, endLeadText, storesHtml, storesPending } from "../home/src/stores.js";

const strings = {
  es: JSON.parse(readFileSync(new URL("../home/src/strings.es.json", import.meta.url), "utf8")),
  en: JSON.parse(readFileSync(new URL("../home/src/strings.en.json", import.meta.url), "utf8")),
};

const APPLE = "https://apps.apple.com/app/id0000000000";
const PLAY = "https://play.google.com/store/apps/details?id=invalid.pending.app&hl=es";
const CASES = [
  { name: "ninguna", stores: { appStoreUrl: null, googlePlayUrl: null }, lead: "endLead" },
  { name: "solo Google Play", stores: { appStoreUrl: null, googlePlayUrl: PLAY }, lead: "endLeadPlayOnly" },
  { name: "solo App Store", stores: { appStoreUrl: APPLE, googlePlayUrl: null }, lead: "endLeadAppStoreOnly" },
  { name: "las dos", stores: { appStoreUrl: APPLE, googlePlayUrl: PLAY }, lead: "endLeadBoth" },
];

/** Las etiquetas de apertura de un fragmento, con sus atributos. */
const openTags = (html) =>
  [...html.matchAll(/<([a-z]+)((?:\s+[a-z-]+(?:="[^"]*")?)*)\s*>/g)].map((m) => ({
    name: m[1],
    attrs: Object.fromEntries([...m[2].matchAll(/([a-z-]+)(?:="([^"]*)")?/g)].map((a) => [a[1], a[2] ?? ""])),
  }));
/** Cada rótulo (`class="store…"`): etiqueta, atributos y su contenido. */
const labels = (html) =>
  [...html.matchAll(/<(a|span) class="store(?: [^"]*)?"([^>]*)>([\s\S]*?)<\/\1><\/li>/g)].map((m) => ({ tag: m[1], attrs: m[2], body: m[3] }));
/** Lo que se ve (sin lo oculto a la vista) y lo que se lee (todo el texto). */
const visible = (body) => body.replace(/<span class="vh">[\s\S]*?<\/span>/g, "").replace(/<[^>]*>/g, "").trim();
const read = (body) => body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
const unesc = (s) => s.replaceAll("&amp;", "&");

describe("CA-025-08: los rótulos de las tiendas, en los cuatro casos", () => {
  for (const lang of ["es", "en"]) {
    const s = strings[lang];
    for (const c of CASES) {
      const html = storesHtml({ strings: s, stores: c.stores });
      const list = labels(html);

      test(`${lang}, ${c.name}: un rótulo por tienda, App Store primero, con su nombre de texto`, () => {
        assert.equal(list.length, 2, html);
        assert.deepEqual(list.map((l) => visible(l.body)), [s.storeAppStore, s.storeGooglePlay]);
      });

      test(`${lang}, ${c.name}: ninguna imagen ni logotipo de las tiendas`, () => {
        assert.ok(!/<(img|svg|picture|image|object|embed)\b/i.test(html), html);
        assert.ok(!/badge/i.test(html), "nada de insignias hasta F6");
      });

      test(`${lang}, ${c.name}: con dirección, enlace a la ficha; sin ella, texto sin enlace`, () => {
        for (const [i, store] of STORES.entries()) {
          const url = c.stores[store.urlKey];
          const l = list[i];
          if (url) {
            assert.equal(l.tag, "a");
            assert.equal(unesc(/href="([^"]*)"/.exec(l.attrs)[1]), url);
            assert.match(l.attrs, /rel="noopener noreferrer"/);
            assert.equal(read(l.body), s[store.nameKey], "con ficha no lleva «(muy pronto)»");
          } else {
            assert.equal(l.tag, "span", "sin dirección no puede ser un enlace");
            assert.ok(!/href=/.test(l.attrs));
            assert.equal(read(l.body), `${s[store.nameKey]} ${s.storeSoonAlt}`, "el nombre para el lector lleva «(muy pronto)»");
            assert.ok(l.body.includes(`<span class="vh">${s.storeSoonAlt}</span>`), "«(muy pronto)», en un span oculto a la vista");
          }
          assert.ok(!/\b(role|tabindex|aria-disabled|aria-label)=/.test(l.attrs + l.body), `${store.id}: sin role, tabindex, aria-disabled ni aria-label`);
        }
      });

      test(`${lang}, ${c.name}: ningún enlace salvo las fichas que existen`, () => {
        const hrefs = openTags(html).filter((t) => "href" in t.attrs).map((t) => unesc(t.attrs.href));
        assert.deepEqual(hrefs, STORES.map((st) => c.stores[st.urlKey]).filter(Boolean));
      });

      test(`${lang}, ${c.name}: «Muy pronto» en la portada mientras falte alguna; nunca en el cierre`, () => {
        const soon = (h) => (h.match(/<p class="stores__soon"[^>]*>([^<]*)<\/p>/g) ?? []).length;
        const pending = c.lead !== "endLeadBoth";
        assert.equal(soon(html), pending ? 1 : 0);
        assert.equal(storesPending(c.stores), pending);
        if (pending) assert.ok(html.includes(`<p class="stores__soon" aria-hidden="true">${s.storeSoon}</p>`), "se ve una vez y no se lee dos (ya va en cada rótulo)");
        assert.equal(soon(storesHtml({ strings: s, stores: c.stores, label: false })), 0, "en el cierre lo dice la entradilla");
      });

      test(`${lang}, ${c.name}: la entradilla del cierre es «${c.lead}»`, () => {
        assert.equal(endLeadKey(c.stores), c.lead);
        assert.equal(buildEndLeadKey(c.stores), c.lead, "el contenido sin JavaScript usa la misma regla");
        assert.equal(endLeadText(s, c.stores), s[c.lead]);
      });
    }
  }

  test("sin objeto de tiendas, como sin fichas", () => {
    assert.equal(endLeadKey(undefined), "endLead");
    assert.equal(storesPending(undefined), true);
    assert.equal(labels(storesHtml({ strings: strings.es, stores: undefined })).filter((l) => l.tag === "a").length, 0);
  });

  test("algo que no es una dirección de texto no es una ficha", () => {
    const stores = { appStoreUrl: { toString: () => "javascript:x" }, googlePlayUrl: 1 };
    assert.ok(!/href=/.test(storesHtml({ strings: strings.es, stores })));
    assert.equal(endLeadKey(stores), "endLead");
  });

  test("una dirección vacía no es una ficha", () => {
    const html = storesHtml({ strings: strings.es, stores: { appStoreUrl: "", googlePlayUrl: "" } });
    assert.ok(!/href=/.test(html));
    assert.equal(endLeadKey({ appStoreUrl: "", googlePlayUrl: "" }), "endLead");
  });

  test("todo sale escapado (texto y dirección hostiles)", () => {
    const hostile = { ...strings.es, storeAppStore: "<img src=x>", storeSoonAlt: "\"><script>", storeSoon: "<b>&" };
    const html = storesHtml({ strings: hostile, stores: { appStoreUrl: null, googlePlayUrl: 'https://play.google.com/x?a=1&b="><script>' } });
    assert.ok(!/<img|<script|<b>/.test(html), html);
    assert.ok(html.includes("&lt;img src=x&gt;") && html.includes("&amp;b=&quot;&gt;&lt;script&gt;"), html);
  });
});
