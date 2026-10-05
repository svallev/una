# ADR-0023: Idioma elegido en la app: "Como el sistema", Español o English; con uno elegido la app no mira el sistema y la excepción de voz del ADR-0020 se amplía

- **Estado:** Aceptado (propietario, 2026-10-05, con la spec 015); incluye una enmienda a la excepción de P6 del ADR-0020 (constitución 1.7)
- **Fecha:** 2026-10-05
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 015 (CA-015-06 a 11, Q-015-1), spec 010 (idioma automático); sustituye en parte al ADR-0020 (solo el alcance de la excepción); constitución P6 y P7 (y 1.7); D23 y R-26 en `docs/PLAN.md`; R-22; ADR-0026 (misma subida de la constitución)

## Contexto

- **[Hecho]** Hoy el idioma lo decide solo el sistema (spec 010): `resolveAppLocale` (`app/lib/app/locale_resolution.dart`) usa el primer idioma preferido que la app admita (`es-*` y `ca-*` → español; `en-*` → inglés) y, si ninguno, inglés. Se aplica con `localeListResolutionCallback` en las dos `MaterialApp` de `una_app.dart`. No hay selector (010, §8 y CL-010-6).
- **[Hecho]** El propietario decidió el 2026-10-04 que el idioma sea **elegible** en Ajustes: por defecto "Como el sistema" (con las reglas de la 010) y, a elección, español o inglés, en una página de selección (D23, P-3; spec 015, CA-015-06 a 09). Al elegir, la app cambia **al momento, sin reiniciar**, y vuelve a Ajustes.
- **[Hecho]** Flutter 3.47.5 (`.fvmrc`; código fuente del SDK leído el 2026-10-05, `widgets/app.dart`): `WidgetsApp.locale` es el idioma inicial de `Localizations`; con `null` se usa el del sistema (con los callbacks de resolución), y con un valor, `Localizations.locale` es ese idioma si está en `supportedLocales`. Cambiar `locale` reconstruye la app sin recrear la actividad (el manifiesto ya trae `locale|layoutDirection` en `configChanges`, spec 015, anexo).
- **[Hecho]** La tabla `settings` (clave y valor) ya reserva la clave `locale` (`system | es | en`) y el arranque ya lee `keepScreenOn` en `readBootState` (`app/lib/app/providers.dart`): no hace falta migración (CA-015-17); hay que **escribir** el valor y **leerlo en el mismo arranque** para pintar el primer fotograma en ese idioma (CA-015-10).
- **[Hecho]** ADR-0020 (aceptado 2026-10-01): `appFrame` marca todo el contenido con el idioma de la app (`localeForSubtree`) y TalkBack lo lee con su voz. Pero **los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz del sistema** (WCAG 3.1.2, excepción a P6). Hoy esa excepción solo alcanza a quien tiene como **primer** idioma del sistema uno que no es español ni inglés (`ca`, `gl`, `eu`, `fr`…): es rara. El motivo técnico (ADR-0020, consultado el 2026-10-01 con el SDK y Context7): `SemanticsService.sendAnnouncement` y la API de Android que lo dice no llevan idioma, y están obsoletos desde la API 36. **[Hecho]** Esta sesión (2026-10-05) la documentación consultada en Context7 no aportó nada nuevo (solo APIs del *embedder*, sin idioma por anuncio); el estado del motor no se ha vuelto a comprobar.
- **[Hecho]** Con un idioma elegido distinto del del sistema (p. ej. sistema en inglés, app en español) la excepción **pasa de rara a habitual**: es precisamente el caso para el que existe el selector. Es el riesgo **R-26** del plan (probabilidad Alta, impacto Medio).
- **[Hecho]** Decisión del propietario (Q-015-1, 2026-10-05): se acepta la limitación ampliada (opción 1, recomendación); las regiones vivas se retoman con la migración de R-22 o si lo señala la beta.
- **[Suposición]** El mecanismo es el mismo que el del ADR-0020 (anuncios sin idioma), así que el efecto con español e inglés es el mismo que ya se observa con `ca`: una voz que pronuncia con el acento del otro idioma. No se ha oído todavía con este caso concreto. **[Pendiente]** Comprobarlo a oído con TalkBack (sistema en inglés y app en español, y al revés) en el móvil: casilla de la auditoría en dispositivo (spec 022).

## Opciones consideradas

1. **Selector en la app y se amplía la excepción del ADR-0020** (anuncios, acciones del lector y títulos de las hojas con la voz del sistema cuando el idioma de la app no es el primer idioma del sistema).
2. **Selector en la app y anuncios como regiones vivas** (nodos que el lector lee al cambiar y que sí llevan la marca de idioma), con la excepción solo para acciones y títulos de hojas. Es la opción 2 del ADR-0020, que entonces se descartó por riesgo y trabajo (14 anuncios en 10 archivos de `lib/`).
3. **Selector en la app y un canal nativo** que mande cada anuncio con su idioma (opción 3 del ADR-0020); tampoco resuelve acciones ni títulos.
4. **Sin selector propio: idioma por app de Android 13+** (`localeConfig`, "Idiomas de la app" de los ajustes del sistema). No hay página de Idioma en la app y en Android 8–12 no hay nada. **[Pendiente]** No se ha comprobado que mejore la voz de los anuncios.

No se considera "no ofrecer la elección": D23 la pide.

## Decisión

Opción 1: el idioma es un ajuste de tres valores (`system`, `es`, `en`; por defecto `system`) que se guarda en `settings.locale`; con `system` se aplica `resolveAppLocale` sin cambios (010) y con `es` o `en` la app **no mira el sistema**. La excepción de P6 del ADR-0020 se amplía de "el primer idioma del sistema no es español ni inglés" a **"el idioma de la app no es el primer idioma del sistema"**, comparando solo el código de idioma (`es` y `es-MX` son el mismo; `ca`, `fr` o `gl` son distintos de `es` y `en`). Se revisa si Flutter permite indicar el idioma de los anuncios o de las acciones, si se aborda la migración a regiones vivas (R-22), si se añade un tercer idioma o si lo señala la beta.

## Motivos

Criterios (peso): cumple D23 y lo pedido en la spec 015 (3), voz con el idioma correcto / P6 (3), esfuerzo y riesgo de regresión (2), cubre Android 8–12 (2). Puntuación de 0 a 5.

| Opción | D23 ×3 | Voz / P6 ×3 | Esfuerzo y riesgo ×2 | Android 8–12 ×2 | Total |
|---|---|---|---|---|---|
| 1. Selector + excepción ampliada | 5 → 15 | 2 → 6 | 5 → 10 | 5 → 10 | **41** |
| 2. Selector + regiones vivas | 5 → 15 | 3 → 9 | 2 → 4 | 5 → 10 | **38** |
| 3. Selector + canal nativo | 5 → 15 | 3 → 9 | 1 → 2 | 5 → 10 | **36** |
| 4. Idioma por app de Android 13+ | 2 → 6 | 2 → 6 | 4 → 8 | 1 → 2 | **22** |

- **Opción 1:** la menos arriesgada: no toca los 14 anuncios y la excepción ya existe; solo cambia a quién alcanza. Es la recomendación aceptada por el propietario.
- **Opción 2:** mejora una de las tres cosas (los anuncios) a cambio de cambiar cómo y cuándo se oye cada uno, con riesgo de duplicados o pérdidas que solo se ven con TalkBack real (ADR-0020). Con el caso ahora habitual su beneficio crece: **es la salida natural si la beta señala el problema**, y se une a la migración que R-22 ya prevé por otra razón (la obsolescencia de los anuncios).
- **Opción 3:** código nativo y un canal propio para algo que la plataforma retira, y sigue sin resolver acciones ni títulos.
- **Opción 4:** no da la página que pidió el propietario, deja sin selector a Android 8–12 y no se sabe si arregla la voz. Además la 010 y la 015 prevén que la app **no** aparezca en esa lista (CL-010-6 y CL-015-10).
- Ninguna opción quita la excepción por completo: lo que sí cumple todas es que **lo que se recorre** (interfaz y contenido) lleva su idioma. La puntuación de "Voz / P6" es mi valoración, no una medida.

## Consecuencias

- **Positivas:**
  - Se cumple D23 sin tocar los anuncios: sin riesgo de regresión en ellos.
  - Con un idioma elegido, el primer fotograma ya sale en ese idioma si se lee junto con el resto del arranque (CA-015-10).
  - Sin esquema, permisos ni dependencias nuevos.
- **Negativas y su mitigación:**
  - **La excepción pasa de rara a habitual.** Quien elija un idioma distinto del del sistema oirá los anuncios ("Tarea completada"), los nombres de las acciones ("Mover arriba") y los títulos de las hojas con la voz del sistema, con una pronunciación ajena. Mitigación: los textos ya están en el idioma de la app, **todo lo que se recorre** (interfaz y contenido del usuario) lleva su marca de idioma, y los anuncios son cortos. **Verificable** con un test que, con el sistema en inglés y la app en español (y al revés), comprueba que todos los nodos recorridos llevan `es` y ninguno `en` (CA-015-11); la voz, a oído (spec 022). **Aceptado por el propietario el 2026-10-05.**
  - **R-26** se queda en Alta/Media: este ADR es su decisión, no su cierre. Se actualiza en `docs/PLAN.md` con la mitigación y el disparador de revisión (cada actualización de Flutter: ¿ya se puede indicar el idioma de un anuncio o de una acción?).
  - **Los selectores y diálogos del sistema** (fotos, archivos, permisos) siguen en el idioma del sistema (CL-015-17), y la app no aparece en "Idiomas de la app" de Android 13+ (CL-015-10).
  - **Si no se puede leer el ajuste al arrancar** se usa "Como el sistema" (CL-015-16); un valor inválido, también (CL-015-14). El idioma viaja con la copia de seguridad (ADR-0004; CL-015-18).
  - **Una lectura más en el arranque** (`locale` junto con el resto de ajustes). Se mide con CA-015-23 (p50 < 1 s, sin empeorar).
- **Riesgos para `docs/PLAN.md`:** actualizar R-26 (arriba); R-22 gana un motivo más para la migración a regiones vivas.
- **Qué hay que hacer al aceptarlo:**
  - añadir a las excepciones de P6 de `specs/constitution.md` la nota de que el ADR-0020 se amplía, y subir la constitución a la versión **1.7** (una sola subida junto con el ADR-0026): "[ADR-0023](../docs/adr/0023-idioma-elegido-en-la-app.md) (2026-10-05): la excepción del ADR-0020 se amplía: los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz del sistema **cuando el idioma de la app no es el primer idioma del sistema** (también con español o inglés elegidos en Ajustes) (WCAG 3.1.2). Lo mitiga que todo lo que se recorre lleva el idioma de la app. Se revisa si Flutter permite indicar el idioma, si se migra a regiones vivas (R-22), si se añade un idioma o si lo señala la beta.";
  - ADR-0020: "Aceptado; sustituido en parte por ADR-0023 (alcance de la excepción)" (como el ADR-0012 con el 0021) y la misma nota en `docs/adr/README.md`;
  - spec 010: CA-010-10 y CL-010-2 pasan a remitir también al ADR-0023 (ya recogido en el §10 de la spec 015); `docs/architecture.md` (cómo se lee y se aplica `locale`), `docs/testing.md` y R-26 en `docs/PLAN.md`.
- **Qué dispararía revisarlo:** los criterios de la decisión.
