# ADR-0028: Las páginas de contenido llevan un programa propio, sin dependencias, solo para el idioma

- **Estado:** **Aceptado** (propietario, 2026-11-17, al aprobar el plan de la spec 026). Antes Propuesto (2026-11-17)
- **Fecha:** 2026-11-17
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 026 (páginas de contenido, CA-026-06 a 09, 13 y 15), spec 023 (CA-023-13 y 14), spec 025 (CA-025-12 y 13), ADR-0009 (monorepo y `landing/`, **enmendado aquí**), ADR-0027 (Vite, GSAP y Lenis, **enmendado aquí**), ADR-0010 (Vercel), P4, P5 y P11 de la constitución, amenazas T-9 y T-18 de `docs/security/threat-model.md`

## Contexto

- **[Hecho]** El ADR-0009 (enmendado por el 0027) y el ADR-0027 dicen que la política, las licencias, la Ayuda y la página de error van **sin JavaScript**: solo la página de inicio lleva programa (Vite, GSAP y Lenis). Hoy esas cuatro páginas enseñan los dos idiomas, uno debajo del otro, y `landing/check.mjs` falla ante cualquier `<script>`.
- **[Hecho]** El propietario decidió el 2026-11-17 (spec 026, Q-026-2, 3 y 5): «Quiero que el idioma se pueda elegir y no se vean las 2 a la vez. Si hace falta usar JavaScript lo cambiamos para que se use». La dirección es la misma para ES y EN (P-012-2): la app enlaza a `/privacy`, `/licenses` y `/help` sin idioma.
- **[Hecho]** Sin programa, una sola dirección no puede enseñar un idioma y recordar la elección: CSS no lee `localStorage` ni el idioma del navegador de forma fiable (`:lang()` mira el documento, no al visitante), y una dirección por idioma (`/en/privacy`) la descartó la spec (§8).
- **[Hecho]** La landing ya guarda el idioma en `localStorage` con la clave `una-lang` (`landing/home/src/shared/locale.js`); la CSP de esas cuatro páginas es `default-src 'none'` sin `script-src`.

## Opciones consideradas

1. **Seguir sin JavaScript:** los dos idiomas siempre (lo de hoy). No cumple la decisión del propietario.
2. **Una dirección por idioma** (`/es/…`, `/en/…`) con redirección del servidor: cambia lo que enlaza la app (P-012-2) y necesita reglas en Vercel; fuera de la spec.
3. **Reutilizar el programa de la landing** (Vite, con su `i18n.js` y `locale.js`): mete el empaquetador y su salida en cuatro páginas que no lo necesitan, y la CSP de «/» admite estilos en línea.
4. **Un programa propio, pequeño, escrito a mano, sin dependencias ni empaquetador**, servido desde la propia web y cargado en el `<head>` de las cuatro páginas, que solo decide el idioma y lo cambia; el contenido sigue escrito en el HTML en los dos idiomas.

## Decisión

Opción 4. Las cuatro páginas de contenido cargan **un solo archivo**, `/lang.js`, escrito a mano en `landing/src/lang.js`, de 10 KB como máximo, sin `import` ni bibliotecas, que:

- decide el idioma (ancla de la dirección, elección guardada, idioma del navegador; CA-026-06) y lo marca en `<html>` antes de que se pinte la página, para que el CSS oculte la otra mitad;
- cambia el idioma al pulsar ES o EN y guarda **solo** `es` o `en` con la clave `una-lang`, la misma de la landing;
- no hace peticiones, no escribe en la página nada leído del almacenamiento ni de la dirección (solo los compara con `es` y `en`), no usa estilos en línea ni HTML generado.

La CSP de esas páginas pasa a admitir **programas del propio origen** (`script-src 'self'`) y, a la vez, exige Trusted Types (`require-trusted-types-for 'script'; trusted-types 'none'`: el navegador no deja escribir HTML desde un programa); siguen prohibidos los programas en la página y los estilos en línea. Sin JavaScript, o si el programa falla, se leen los dos idiomas como hoy.

**Enmiendas:** el ADR-0009 pasa de «ningún programa de otro origen ni que envíe datos; las cuatro páginas sin JavaScript» a «las cuatro páginas llevan solo el programa propio de idioma (ADR-0028)». El ADR-0027 deja de decir que las otras cuatro páginas siguen sin JavaScript: siguen **sin dependencias** (ni GSAP, ni Lenis, ni Vite en su resultado).

Se revisa si el programa necesita algo más que el idioma, si pasa de 10 KB o si se decide dar a cada idioma su dirección.

## Motivos

- Cumple la decisión del propietario sin cambiar las direcciones que usa la app ni añadir dependencias (P11: nada que revisar en §5 del modelo de amenazas).
- El riesgo nuevo es pequeño y medible: un archivo propio, revisable entero, que `check.mjs` comprueba (sin red, sin `innerHTML`, sin otro almacenamiento, tamaño) y que la CSP limita al propio origen.
- Mantiene lo que la 023 garantizaba: sin JavaScript se lee todo.

## Consecuencias

- **Positivas:** un idioma cada vez; la elección se comparte con la landing; sin dependencias nuevas; la versión sin JavaScript sigue completa.
- **Negativas y riesgos:**
  - Un programa en el `<head>` bloquea un instante el análisis de la página: es un archivo de pocos KB del propio origen; se mide en C-026-2.
  - La CSP de todo lo que no es «/» admite programas del propio origen: también la de `/third-party-notices.txt` o `/fonts/…`, que no ejecutan nada. Mitigación: la web no sirve contenido de terceros ni subido por nadie (T-9); `nosniff` impide ejecutar como programa lo que no lo es; `check.mjs` exige que el único programa de esas páginas sea `/lang.js` y **falla si en `dist/` hay algún `.html` o `.js` fuera de la lista esperada** (un resto de la construcción no puede colarse con permiso para ejecutar programas).
  - La clave `una-lang` lleva el nombre de la app escrito a mano (aceptado en la 025; CA-026-13).
- **[Hecho, 2026-11-17, spec 026]** La política dice que la web guarda el idioma y que las cuatro páginas usan JavaScript solo para él (CA-026-14, T-026-08); las amenazas T-9 y T-18 (`threat-model.md` 1.11), la checklist de la web, y las marcas de enmienda de los ADR-0009 y 0027 están al día (T-026-10). Medido en C-026-2: `lang.js` pesa 4,1 KB y no se ve ningún salto de idioma al cargar (`specs/026-paginas-de-contenido/navegadores.md`).
