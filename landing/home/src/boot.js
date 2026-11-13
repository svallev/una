// Arranque de la página de inicio (spec 025, CA-025-11 y CL-025-12; plan §2.2). Sin dependencias: el
// documento y el montaje llegan como argumentos.
//
// El HTML trae el contenido sin JavaScript (`#static`), oculto los primeros 2 s por CSS (`static.css`). El
// arranque lo saca del dibujo mientras monta (así nunca hay dos `h1` a la vista ni para el lector) y lo
// quita al final del montaje. Si el montaje falla, de forma síncrona o asíncrona, se deshace lo montado (las
// funciones registradas con `onUndo`, en orden inverso) y el contenido sin JavaScript se enseña al momento.
// Si el foco estaba dentro de ese contenido (el programa llegó después de los 2 s), pasa al `h1` que quede.

export const STATIC_ID = "static";

/** Devuelve `true` si el montaje terminó y `false` si falló (y se enseña el contenido sin JavaScript). */
export async function boot({ doc, mount }) {
  const block = doc.getElementById(STATIC_ID);
  const hadFocus = Boolean(block && doc.activeElement && block.contains(doc.activeElement));
  const undo = [];
  block?.classList.add("is-mounting");
  try {
    await mount({ onUndo: (fn) => undo.push(fn) });
  } catch {
    for (const fn of undo.reverse()) {
      try {
        fn();
      } catch {
        // Se sigue deshaciendo lo demás: no puede quedar nada a medias.
      }
    }
    if (block) {
      block.classList.remove("is-mounting");
      block.classList.add("is-shown");
    }
    if (hadFocus) doc.querySelector("h1")?.focus();
    return false;
  }
  block?.remove();
  if (hadFocus) doc.querySelector("h1")?.focus();
  return true;
}
