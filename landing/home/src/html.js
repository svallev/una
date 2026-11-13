// HTML del programa de la página de inicio (spec 025, plan §6.1). Todo texto que el programa mete en el HTML
// (los textos de `strings.*.json`, los de `gen/site.json`, las direcciones) pasa por `esc`, la única función de
// escape del programa: los cinco caracteres, comilla simple incluida.

/** Escapa el texto para HTML (también dentro de atributos entre comillas). */
export const esc = (s) =>
  String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

/** El primer elemento de un fragmento de HTML ya escapado, creado en [doc] (sin insertarlo). */
export function fragment(doc, html) {
  const tpl = doc.createElement("template");
  tpl.innerHTML = html;
  return tpl.content.firstElementChild;
}
