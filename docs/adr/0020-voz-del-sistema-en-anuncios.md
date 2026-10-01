# ADR-0020: Los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz del sistema

- **Estado:** Aceptado (propietario, 2026-10-01, junto con la aprobación de la spec 013)
- **Fecha:** 2026-10-01
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 013 (D-013-2), spec 010 (CA-010-10, CL-010-2, §8 y §9), spec 012 (hallazgo 012-A-B2), constitución P6 y P7

## Contexto

- **[Hecho]** La app solo tiene español e inglés; el idioma lo decide el sistema (spec 010). Con el sistema en `ca`, la app sale en español; con `gl`, `eu`, `fr` o cualquier otro idioma, en inglés.
- **[Hecho]** CA-010-10: `appFrame` marca todo el contenido con el idioma de la app (`localeForSubtree`), y TalkBack lee la interfaz y el contenido del usuario con la voz de ese idioma. Se aceptó como **excepción de la beta**, "a revisar en F5", que tres cosas se oigan con la voz del **sistema**:
  - los anuncios (p. ej. "Tarea completada", "Cargando licencias…");
  - los nombres de las acciones del lector (p. ej. "Mover arriba");
  - los títulos de las hojas.
- **[Hecho]** El cierre de la 012 lo volvió a señalar (012-A-B2, bajo): con el sistema en `ca`, los anuncios en español los dice la voz catalana; con `gl` o `eu`, los anuncios en inglés los dice la voz del sistema.
- **[Hecho]** Con el **primer** idioma del sistema en español o en inglés no pasa nada: la voz del sistema es la del idioma de la app. Con una lista como `fr-FR, es-ES` (CA-010-02), la app sale en español y la voz del sistema es la francesa: también entra en la excepción.
- **[Hecho]** Flutter 3.47.5 (la versión de `.fvmrc`; código fuente del SDK y Context7, `/websites/api_flutter_dev`, consultados el 2026-10-01):
  - `SemanticsService.sendAnnouncement(view, message, textDirection, {assertiveness})` no tiene parámetro de idioma;
  - en Android, el anuncio llega como un `String` sin idioma. Tanto el método del canal de Flutter (`AccessibilityChannel.announce`) como la API de Android que lo dice (`View.announceForAccessibility`) están **obsoletos desde la API 36**: Flutter recomienda usar propiedades semánticas en su lugar.
- **[Suposición]** Tampoco hay forma, desde Flutter, de marcar el idioma de los nombres de las acciones del lector ni del título de una hoja (las acciones se envían con su etiqueta como texto plano). No se ha comprobado en el código del motor de Android.
- **[Hecho]** WCAG 3.1.2 (Idioma de las partes, nivel AA) pide que el idioma de cada parte se pueda determinar. P6 exige WCAG 2.2 AA, y cada excepción tiene que tener su ADR, su mitigación y su criterio de revisión.

## Opciones consideradas

1. **Mantener la voz del sistema** en las tres cosas, como excepción permanente a P6 con criterio de revisión.
2. **Cambiar los anuncios por regiones vivas** (nodos que el lector lee al cambiar), que sí llevan la marca de idioma de la app, y mantener la excepción solo para las acciones y los títulos de las hojas.
3. **Hacerlo en nativo**: un canal propio que mande cada anuncio a Android con su idioma.

## Decisión

Se mantiene la **voz del sistema** en los anuncios, los nombres de las acciones del lector y los títulos de las hojas (opción 1), como excepción a P6 (WCAG 3.1.2). Se revisa si Flutter llega a permitir indicar el idioma de los anuncios o de las acciones, si la app añade un tercer idioma, o si un tester de la beta lo señala.

## Motivos

- **A quién afecta:** solo cuando el primer idioma del sistema no es español ni inglés. Para el público inicial no cambia nada.
- **Lo que ya está cubierto:** todo el contenido y la interfaz que el lector recorre ya llevan su idioma (CA-010-10). La excepción se limita a textos cortos y puntuales.
- **Opción 2:** arregla solo una de las tres cosas. Además, cambia cómo y cuándo se oye cada anuncio (**[Hecho]** 14 anuncios en 10 archivos de `lib/`), con riesgo de anuncios duplicados o perdidos que solo se ven con TalkBack real. Es mucho trabajo y riesgo para un beneficio que solo nota quien tiene el sistema en otro idioma.
- **Opción 3:** añade código nativo y un canal propio (P11) para algo que la plataforma está retirando (los anuncios, obsoletos desde la API 36). Tampoco resuelve las acciones ni los títulos.
- **Decisión del propietario (2026-10-01):** "que se quede con la voz del sistema".

## Consecuencias

- **Positivas:**
  - sin cambios de código ni riesgo de regresión en los anuncios;
  - la 013 se queda pequeña;
  - se cierran 012-A-B2 y la revisión de F5 de CA-010-10.
- **Negativas y su mitigación:**
  - con el sistema en `ca`, `gl`, `eu`, `fr`…, esas tres cosas pueden oírse con una pronunciación ajena;
  - **mitigación:** los textos ya están en el idioma de la app, los nodos que se recorren llevan su marca de idioma y los anuncios son cortos;
  - el riesgo se anota para el feedback de la beta (F6).
- **Riesgo:** que Android retire del todo los anuncios (obsoletos desde la API 36) y dejen de oírse (p. ej. CA-003-07 o CA-012-15). Eso no depende de esta decisión y es otro problema. Se registra como **R-22** en `docs/PLAN.md` y se vigila en cada actualización de Flutter.
- **Qué hay que hacer al aceptarlo:**
  - añadir esta línea en la lista de excepciones de P6 de `specs/constitution.md` y subir la constitución a la versión 1.5: "[ADR-0020](../docs/adr/0020-voz-del-sistema-en-anuncios.md) (2026-10-01): los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz del sistema cuando su primer idioma no es español ni inglés (WCAG 3.1.2). Lo mitiga que todo lo que se recorre lleva el idioma de la app. Se revisa si Flutter permite indicar el idioma, si se añade un idioma o si lo señala la beta.";
  - enmendar la 010: CA-010-10 ("excepción aceptada en la beta" pasa a "ADR-0020"), CL-010-2, §8 y §9;
  - marcar 012-A-B2 como aceptado en `docs/PLAN.md`.
- **Qué dispararía revisarlo:** los criterios de la decisión.
