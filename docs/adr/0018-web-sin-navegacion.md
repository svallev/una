# ADR-0018: Tarea web sin navegación: solo se ve la página de la dirección guardada

- **Estado:** Aceptado (propietario, 2026-09-29)
- **Fecha:** 2026-09-29
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 009 (CA-009-10, 11, 12, 19; CL-009-1; §5, §7, §8), ADR-0007 (lo enmienda: sin navegación contenida), ADR-0016 (lo enmienda en lo que mantenía del ADR-0007), ADR-0017 (no cambia), modelo de amenazas T-5

## Contexto

- **[Hecho]** La spec 009, aprobada el 2026-09-28, dejaba navegar dentro del **mismo sitio** (mismo dominio registrable, con la *Public Suffix List*), sacaba al navegador los enlaces a otro sitio y a otra app los `mailto:` y `tel:`, tras confirmar, y hacía que atrás volviera a la página anterior (CA-009-11 y CA-009-12), como decía el ADR-0007.
- **[Hecho]** El 2026-09-29, con T-009-01..06 hechas, el propietario lo cambia: "Cuando cargamos una página web, la idea es que solo se vea esa dirección. Que no se pueda navegar, que no funcionen los links, nada." La tarea web es para **consultar** una página (la carta de un restaurante, la página de contacto de una web, la agenda de un congreso o de un festival), como una imagen o un PDF, y **no para usar Una como navegador**.
- **[Hecho]** Sin navegación, la *Public Suffix List* (T-009-03) solo servía para no avisar de una redirección entre subdominios del mismo sitio (CL-009-1).

## Opciones consideradas

1. **Navegación contenida en el mismo sitio** (la spec aprobada y el ADR-0007).
2. **Sin navegación:** solo la página de la dirección guardada; ningún enlace hace nada.
3. Sin navegación, pero con salida al navegador o a otra app tras confirmar, como los enlaces del PDF (CA-008-12).

## Decisión

Opción 2 (propietario, 2026-09-29), con estas precisiones suyas:

- **Se carga la dirección guardada** y se siguen las **redirecciones del servidor** de esa carga (CL-009-1), como hasta ahora. Una vez se ve la página, no se carga ninguna otra.
- **Ningún enlace hace nada**: ni a otra página del mismo sitio, ni a otro sitio, ni ventanas nuevas, ni formularios, ni redirecciones de la propia página (JavaScript, `meta refresh`). **`mailto:` y `tel:` tampoco** (se leen en la página): no hay confirmaciones para salir.
- **Excepción: las anclas de la misma página** (`#seccion`, p. ej. "Lunes · Martes" en una agenda) sí desplazan dentro de la página, porque no cargan nada nuevo.
- **Atrás** hace lo mismo que en cualquier tarea: no hay páginas anteriores.
- **Se quita la *Public Suffix List*** (asset, `public_suffix.dart`, `tools/psl.lock`, `tools/update-psl.sh`, su paso de CI y su aviso de licencia). El aviso de redirección (CL-009-1) compara el dominio como se ve en la barra (sin `www.`), así que también avisa de un cambio de subdominio (`ejemplo.com` → `m.ejemplo.com`).
- "Abrir en el navegador" de los avisos de §5 (sin https, certificado, no es una página) **se mantiene**: abre la dirección guardada, no un enlace de la página.

Del ADR-0007 y el ADR-0016 **se mantiene todo lo demás**: validación, WebView endurecida, sin copia local, dominio real en la barra (punycode si mezcla alfabetos).

## Motivos

- Es el uso que quiere el propietario: una consulta rápida, como una imagen o un PDF, no un navegador dentro de la app.
- **Seguridad (T-5):** sin navegación no hay decisiones de "mismo sitio" que puedan fallar, ni salidas a otras apps: menos superficie. La barra siempre muestra el dominio de la única página que se ve.
- **Menos código y mantenimiento:** sin la PSL (−335 KB de asset, sin actualizarla en cada versión), sin confirmaciones de enlaces, sin historial ni atrás propio.

## Consecuencias

- **Positivas:** la spec 009 se simplifica (se quitan CA-009-12 como atrás propio, las confirmaciones de enlaces y "Enlace sin app"; T-009-13 desaparece); la barra no cambia de dominio después de cargar.
- **Negativas y riesgos:**
  - Un enlace útil (un "Ver más", el teléfono de la página de contacto) no hace nada: hay que abrir la dirección en el navegador del móvil. Se acepta: es la intención.
  - **[Hecho]** Una página que cambia su contenido sin cargar otra dirección (una aplicación de una sola página con `history.pushState`, pestañas o desplegables hechos con JavaScript) sigue funcionando dentro de la página: la WebView no avisa de esos cambios y no hay forma fiable de impedirlos. Siempre es la misma página y el mismo dominio.
  - Un acortador o una página que redirige con JavaScript (no con el servidor) se queda en esa primera página: la tarea muestra lo que el servidor devuelve para la dirección guardada.
  - **[Hecho, T-009-10]** Android no deja interceptar antes el envío de un formulario con POST. Decisión del propietario (2026-09-29): si, ya vista la página, empieza a cargarse otra, se para y se vuelve a cargar la dirección guardada. Para el usuario, enviar el formulario no hace nada (como mucho, la página se recarga).
  - El aviso de redirección puede salir entre subdominios del mismo sitio (sin la PSL). Se acepta: informa de dónde se está.
- **Hecho al aceptarlo (2026-09-29):**
  - spec, plan y tareas de la 009 actualizados (CA-009-10, 11, 12, 19; CL-009-1, CL-009-12, CL-009-13; §5, §7, §8, §9);
  - T-009-03 revertida y T-009-05 rehecha (`decideWebNavigation` sin sitio de referencia ni PSL);
  - ADR-0007 y ADR-0016 marcados como enmendados; fila en `docs/adr/README.md`;
  - T-5 y §5 del modelo de amenazas actualizados.
