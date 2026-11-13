// Las tiendas en la página de inicio (spec 025, CA-025-08 enmendado el 2026-11-13, CL-025-8; plan §6.1 y §6.2).
// Sin dependencias del navegador: lo usan el programa y `build.mjs` (la entradilla del contenido sin
// JavaScript), para que las dos sigan la misma regla.
//
// Hasta que haya ficha no hay insignias ni logotipos de las tiendas: un rótulo propio por tienda, de texto, con
// App Store primero. Sin dirección, el rótulo no es un enlace ni un botón: es texto, y para el lector su nombre
// lleva «(muy pronto)» en un `span` oculto a la vista (sin `role`, `tabindex` ni `aria-disabled`). Con dirección,
// enlaza a la ficha. Las direcciones vienen de `gen/site.json` (de la identidad, validadas al construir); `null`
// o vacía es «sin ficha».
import { esc } from "./html.js";

/** Las tiendas en el orden en que se enseñan, con su clave en `site.stores` y la de su nombre en los textos. */
export const STORES = Object.freeze([
  Object.freeze({ id: "appStore", urlKey: "appStoreUrl", nameKey: "storeAppStore" }),
  Object.freeze({ id: "googlePlay", urlKey: "googlePlayUrl", nameKey: "storeGooglePlay" }),
]);

const urlOf = (stores, store) => {
  const url = stores?.[store.urlKey];
  return typeof url === "string" && url !== "" ? url : null;
};

/** Si falta la ficha de alguna tienda (entonces la portada dice «Muy pronto»). */
export const storesPending = (stores) => STORES.some((store) => !urlOf(stores, store));

/**
 * La clave de la entradilla del cierre según las fichas que ya hay (CL-025-8): sin ninguna, `endLead`; con una,
 * la que dice cuál falta; con las dos, `endLeadBoth`.
 */
export function endLeadKey(stores) {
  const [apple, play] = STORES.map((store) => Boolean(urlOf(stores, store)));
  if (play && apple) return "endLeadBoth";
  if (play) return "endLeadPlayOnly";
  if (apple) return "endLeadAppStoreOnly";
  return "endLead";
}

/** La entradilla del cierre, sin escapar. */
export const endLeadText = (strings, stores) => strings[endLeadKey(stores)];

/**
 * Los rótulos de las tiendas. Con [label] (la portada), un «Muy pronto» visible sobre los rótulos mientras falte
 * alguna ficha, oculto al lector porque ya va en el nombre de cada rótulo sin ficha (spec §6); en el cierre
 * ([label] falso) lo dice la entradilla.
 */
export function storesHtml({ strings, stores, label = true }) {
  const one = (store) => {
    const url = urlOf(stores, store);
    const name = esc(strings[store.nameKey]);
    return url
      ? `<li><a class="store" href="${esc(url)}" rel="noopener noreferrer">${name}</a></li>`
      : `<li><span class="store is-soon">${name} <span class="vh">${esc(strings.storeSoonAlt)}</span></span></li>`;
  };
  const soon = label && storesPending(stores) ? `<p class="stores__soon" aria-hidden="true">${esc(strings.storeSoon)}</p>` : "";
  return `<div class="stores">${soon}<ul class="stores__row">${STORES.map(one).join("")}</ul></div>`;
}
