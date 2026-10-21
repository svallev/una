# Spec 024: Correcciones de la auditoría

- **Estado:** Borrador (2026-10-21; revisada por `spec-reviewer` el 2026-10-21: 0 altos, 5 medios y 4 bajos, aplicados; Q-024-1 respondida por el propietario el 2026-10-21)
- **Reglas de producto:** R8 (arranque y barras del sistema), R15 (idioma), R16 (deshacer al eliminar), R19 (notificaciones)
- **Pantallas del prototipo:** tableros 2 (Menú), 12 y 13 (Eliminar con deshacer); el resto, sin cambio visual (ver `docs/design/screen-map.md`)
- **Decisiones y ADR relacionados:** D23, D25, D30; ADR-0020, ADR-0021, ADR-0023, ADR-0025 (criterio de revisión de la voz, que cierra CA-024-05)
- **Dependencias:** 022 (auditoría, **Implementada**; hallazgos en `specs/022-auditoria-en-dispositivo/informe.md` §4), 014, 015, 019 y 021 (todas en `main`)

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 0. Alcance (decidido por el propietario, 2026-10-21)

Spec de corrección prevista por la 022 (Q-022-1). Cubre **solo los siete hallazgos abiertos de la auditoría** (respuesta 1a), sin los de los revisores de la 023 ni la lista de «hallazgos de código ya conocidos» de la 022 (§5 del informe), que siguen donde están.

| Hallazgo | Gravedad | Qué decide la 024 | CA |
|---|---|---|---|
| H-022-04 · iconos oscuros de la barra de navegación sobre la card de deshacer | Baja | **Se corrige** (decisión de la sesión, sin objeción del propietario) | CA-024-01, 03 |
| H-022-05 · iconos de la barra de estado bajo el velo de la hoja | Baja | **Se corrige** (ídem) | CA-024-02, 03 |
| H-022-10 · `ca-ES, en-US` abre en inglés | Baja | **Se corrige** (ídem): ya lo pide CA-010-02 | CA-024-04 |
| H-022-03 · TalkBack lee la notificación con la voz del sistema | Media | **Aceptado sin excepción de P6** (propietario, 2026-10-21: «Lo más fácil que se quede como está» y, en Q-024-1, «aceptarlo sin excepción»): la notificación no cambia y no se abre ADR ni constitución nueva | CA-024-05 |
| H-022-02 · el aviso de notificaciones bloqueadas no se anuncia con TalkBack al 200 % | Media | **Aceptado** (respuesta 3b), como H-022-01 | CA-024-06 |
| H-022-06 · con la app cerrada, HyperOS no deja mover la alarma al cambiar de huso | Baja | **Sin código**: límite del sistema anotado en la 019, sin ayuda web (respuesta 4a) | CA-024-07 |
| H-022-07 · aviso retenido tras ~5 h sin abrir la app | Baja | **Sin código**: ídem (respuesta 4a) | CA-024-07 |

## 1. Objetivo

Cerrar lo que la auditoría en dispositivo dejó abierto: que los iconos del sistema se lean también mientras se ve la card de deshacer o una hoja, que el catalán abra en español aunque el inglés esté detrás en la lista, y dejar por escrito, con la decisión del propietario, lo que se acepta tal cual. Con esto, la 019 pasa a **Implementada** y no queda ningún hallazgo de la 022 abierto.

## 2. Historias de usuario

- **HU-024-1** Como persona que acaba de eliminar una tarea, quiero seguir viendo los botones de navegación del sistema mientras está la card de deshacer, para poder salir o volver sin buscarlos.
- **HU-024-2** Como persona que abre el menú de una tarea, quiero que la hora y la batería se sigan leyendo bajo el velo, para no perder la barra de estado.
- **HU-024-3** Como persona con el móvil en catalán y el inglés de reserva, quiero que la app me hable en español, como si solo tuviera el catalán.
- **HU-024-4** Como propietario, quiero que cada hallazgo de la auditoría quede corregido o aceptado por escrito, para empezar F6 sin cabos sueltos.

**Trazabilidad HU → CA:** HU-024-1 → CA-024-01, 03; HU-024-2 → CA-024-02, 03; HU-024-3 → CA-024-04; HU-024-4 → CA-024-05 a 08.

## 3. Criterios de aceptación

- **CA-024-01** · Barra de navegación legible con la card de deshacer (H-022-04)
  - **Dado** la tarea actual o el listado, en vertical, con la barra de navegación de **tres botones** o de **gestos**
  - **Cuando** se elimina una tarea y aparece la card negra «Tarea eliminada» + «Deshacer» junto a la barra de navegación
  - **Entonces**, **mientras la card ocupa la franja de la barra de navegación**, los iconos de esa barra son **claros**, con **3:1 o más** contra el negro de la card; la barra de estado no cambia (CA-021-09). Si en una pantalla o modo de navegación la card **no** llega a esa franja, la barra sigue con CA-021-09 (iconos oscuros sobre el fondo de la app).
  - **[Hecho, H-022-04]** en la tarea actual del Xiaomi la card ocupa la franja (`#121212`) con tres botones y con gestos. **[Suposición, plan]** en el listado también; el plan lo mide en cada pantalla y modo y lo deja en una tabla.
  - **Fuera del criterio** (como en CA-021-09): la píldora de gestos, cuyo color adapta el sistema. **[Suposición]** al pedir iconos claros, HyperOS aclara también la píldora (hoy ≈ 1,05:1); se mide en el Xiaomi y, si no la aclara, se anota como límite del sistema sin bloquear.
  - **Verificable:** test de lo que la app pide a cada barra con la card visible y sin ella; casilla C-024-1 (contraste medido en capturas del Xiaomi, tres botones y gestos, desde la tarea actual y desde el listado).
- **CA-024-02** · Barra de estado legible con una hoja abierta (H-022-05)
  - **Dado** cualquier pantalla de la app en vertical (la tarea actual con una nota de **cualquier color** de la paleta, el listado, el editor)
  - **Cuando** se abre una hoja inferior con velo («Esta tarea», Añadir, Cargar URL, ¿Dónde la pones?, Eliminar o cualquier otra de la app)
  - **Entonces**, mientras haya una hoja con velo abierta:
    - los iconos de la **barra de estado** son **claros**, con **3:1 o más** contra el fondo con el velo (cada color de nota y `paper`);
    - los de la **barra de navegación** siguen **oscuros**, con 3:1 o más contra la hoja (`paper`), como en CA-021-09.
  - **Fuera del criterio** (como en CA-021-09): la parte de una foto, un PDF o una página web que quede detrás de la barra de estado; en esas tareas solo se exige que los iconos sean claros.
  - **[Suposición, plan]** con el velo actual, los iconos claros dan 3:1 o más sobre todos los fondos (en la naranja, `#ffffff` sobre `#7c5c3c` ≈ 6,1:1); el plan lo calcula con cada color de la paleta y `paper`. Si alguno no llega, se para y se pregunta. El velo y el prototipo no cambian (sin desviación).
  - **Verificable:** test con cada fondo (estilo pedido a cada barra y contraste calculado de los iconos claros contra el color con velo); casilla C-024-2 (capturas del Xiaomi con la nota naranja y la amarilla, tres botones y gestos).
- **CA-024-03** · Vuelta al estilo de siempre
  - **Dado** la card de deshacer (CA-024-01) o una hoja (CA-024-02) a la vista
  - **Cuando** la card se va (por tiempo, al tocar «Deshacer», al salir de la pantalla o al reordenar: ADR-0021) o la hoja se cierra (por cualquier camino: tocar fuera, «Atrás», elegir una opción)
  - **Entonces** las barras vuelven a lo que pide CA-021-09 para la pantalla que queda debajo (iconos oscuros sobre `paper` o sobre la nota; claros sobre la enhorabuena) en cuanto la card o la hoja dejan de estar a la vista.
  - **Verificable:** test de las transiciones (card que se va de cada forma, hoja que se cierra de cada forma, hoja que abre otra hoja): el estilo pedido cambia en el mismo fotograma en que la card o la hoja dejan de estar a la vista; C-024-1 y 2.
- **CA-024-04** · El catalán abre en español aunque detrás haya inglés (H-022-10)
  - **Dado** la app con «Como el sistema» (CA-015-09)
  - **Cuando** se abre con estas listas de idiomas del sistema
  - **Entonces** sale en el idioma de la tabla, que es lo que ya pedía CA-010-02 (el **primero** de la lista que la app admite, contando `ca-*` como español, CA-010-01):

    | Lista del sistema | App |
    |---|---|
    | `ca-ES, en-US` | español (hoy, inglés: H-022-10) |
    | `ca-ES` | español |
    | `en-US, ca-ES` | inglés |
    | `fr-FR, ca-ES, en-US` | español |
    | `gl-ES, en-US` | inglés (gl no se admite, CA-010-01) |
    | `fr-FR, de-DE` | inglés (CL-010-2) |
  - Con un idioma elegido en Ajustes, la app no mira el sistema (CA-015-09): sin cambio.
  - **Verificable:** la regla de la tabla ya la cumple la app con la lista que recibe (sus tests pasan hoy), así que **manda la casilla C-024-3** (emulador de API 37 con `ca-ES, en-US`, como en K-022-056). Cuando el plan conozca la causa, se añade un test de lo que la app recibe del sistema que falle antes del arreglo.
  - **[Suposición]** la causa es que el sistema entrega a la app la lista ya filtrada o reordenada por los idiomas que la app declara; el plan lo confirma antes de corregir. Contradice la [Suposición] de CA-010-02 («Android entrega la lista completa»), que se enmienda al cerrar (CA-024-08).
- **CA-024-05** · La notificación se queda como está, aceptada sin excepción de P6 (H-022-03)
  - **Dado** el criterio de revisión de la voz del ADR-0025 (si un lector no respeta la marca de idioma, la notificación pasa a ser una excepción nueva de P6 o se descarta su cambio de idioma) y la decisión del propietario («Lo más fácil que se quede como está» y, en Q-024-1, «aceptarlo sin excepción», 2026-10-21)
  - **Cuando** se cierra la 024
  - **Entonces**:
    - la notificación **no cambia**: sigue en el idioma de la app y con su marca de idioma (CA-019-21), aunque TalkBack la lea con la voz del sistema cuando el idioma de la app no es el primero del sistema;
    - H-022-03 pasa a **Aceptado por el propietario** con sus palabras, **sin** ADR nuevo ni versión nueva de la constitución; queda registrado que el propietario no siguió ninguna de las dos salidas del criterio de revisión del ADR-0025 y que la notificación no está entre las excepciones de P6 (ver §9);
    - CA-019-21 y el criterio de revisión del ADR-0025 llevan una nota de una línea que apunta a esta decisión.
  - **Verificable:** revisión de `informe.md` §4, la spec 019 y la nota del ADR-0025; los tests de la notificación de la 019 siguen en verde sin cambios.
- **CA-024-06** · El aviso de bloqueo al 200 % queda aceptado (H-022-02)
  - **Dado** H-022-02 (con TalkBack, texto al 200 % y tres botones, el aviso «Las notificaciones están bloqueadas…» se ve pero no se anuncia; con el foco en él, se lee)
  - **Cuando** se cierra la 024
  - **Entonces** el hallazgo pasa a **Aceptado por el propietario** (2026-10-21, respuesta 3b), sin cambio en la app, y la N-1 (a) de la 019 (`specs/019-notificaciones/dispositivo.md`) y su línea en `docs/PLAN.md` se cierran con la misma referencia.
  - **Verificable:** revisión de `informe.md` §4, `specs/019-notificaciones/dispositivo.md` y `docs/PLAN.md`.
- **CA-024-07** · Límites de HyperOS anotados, sin código (H-022-06 y 07)
  - **Dado** H-022-06 (con la app cerrada, un cambio de huso no mueve la alarma hasta abrir la app) y H-022-07 (un aviso retenido por el sistema con la app sin abrir ~5 h)
  - **Cuando** se cierra la 024
  - **Entonces** la spec 019 lleva **una línea de enmienda** por cada uno, como límite del sistema en HyperOS: H-022-06 en **CA-019-13** («siguen funcionando solos» tras cambiar el huso: en HyperOS, con la app cerrada, hasta abrirla) y en CL-019-4; H-022-07 junto a **CA-019-11** («objetivo, no garantía»). **No** cambia la app ni la Ayuda web (propietario, 2026-10-19), y los dos hallazgos pasan a **Cerrado (límite del sistema)**. La ficha de H-022-07 del informe («sin cambio en la 019») se enmienda: el único cambio en la 019 es esa línea.
  - **Verificable:** revisión de la spec 019 y de `informe.md` §4; `landing/src/help.{es,en}.md` sin cambios.
- **CA-024-08** · Ningún hallazgo de la 022 abierto
  - **Dado** CA-024-01 a 07 hechos
  - **Cuando** se cierra la 024
  - **Entonces**: H-022-04, 05 y 10 están **Corregidos** (con sus casillas C-024-1 a 3), H-022-02, 03, 06 y 07 **Aceptados** o **Cerrados** con la referencia a esta spec; la 019 pasa a **Implementada** (no le quedan medios); `docs/PLAN.md` (bloque de hallazgos de la 022, trazabilidad y F5) y `CLAUDE.md` lo reflejan; la 021 y la 015 lo citan en su estado; **CA-021-09** lleva una nota que apunta a CA-024-01 y 02 (excepciones mientras están la card o una hoja con velo) y **CA-010-02** la enmienda de su [Suposición] (CA-024-04).
  - **Verificable:** revisión de documentos; `rg 'H-022-0[2-7]|H-022-10'` no deja ninguno «Abierto».

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-024-1 | La card de deshacer sale sobre «Todo hecho.» (se eliminó la última tarea) | CA-024-01: iconos claros mientras está la card; al irse, oscuros sobre `paper` |
| CL-024-2 | Se elimina otra fila del listado con la card ya visible (la card nueva sustituye a la anterior, tablero 13) | Los iconos siguen claros sin parpadeo; se aplica CA-024-03 cuando se va la última |
| CL-024-3 | La app pasa a segundo plano o se bloquea el móvil con la card visible | La card se da por terminada (ADR-0021); al volver, iconos de la pantalla de debajo (CA-024-03) |
| CL-024-4 | Con la card o la hoja a la vista se gira a horizontal (tarea con imagen o PDF) | Las barras se comportan como CL-021-11; al volver a vertical, las de la pantalla que se vea |
| CL-024-5 | Android 8.0 (API 26), sin iconos oscuros en la barra de navegación (excepción de CA-021-09) | La barra de navegación ya es oscura con iconos claros: CA-024-01 se cumple sin más. **[Suposición, PD-10]** sin dispositivo para comprobarlo |
| CL-024-6 | Una hoja abre otra (p. ej. «Esta tarea» → Eliminar, o Añadir → Cargar URL) | El estilo de CA-024-02 se mantiene mientras haya una hoja con velo; CA-024-03 al cerrar la última |
| CL-024-7 | Un diálogo del sistema (selector de fotos, permiso de notificaciones) o uno de la página web dentro de la tarea web | Fuera del criterio: lo dibuja el sistema o la página. **[Hecho]** la app no tiene diálogos propios con velo fuera de las hojas |
| CL-024-11 | La app pasa a segundo plano con una hoja abierta y se vuelve | Si la hoja sigue abierta, CA-024-02; si no, CA-024-03 |
| CL-024-12 | Con el arreglo de CA-024-04, la app y «Idiomas de la app» del sistema (Android 13+) | La app sigue **sin** aparecer en esa lista (CL-010-6, CL-015-10) |
| CL-024-13 | Notificación con `ca-ES, en-US` y «Como el sistema» | Sale en el idioma de la app (español) y con la marca que pide CA-019-21, como la propia app |
| CL-024-8 | Enhorabuena con la barra ya en claro (CA-021-09) y justo después una card de deshacer | No se da: completar y eliminar no se solapan (ADR-0021); si se diera, manda la card (iconos claros en los dos casos) |
| CL-024-9 | Lista del sistema con una variante de catalán (`ca-AD`, `ca-ES-valencia`) primero | Español (CA-010-01: cualquier `ca-*`) |
| CL-024-10 | Se cambia la lista de idiomas del sistema con la app abierta | Como hoy (CA-010-01 y 015): la app sigue la lista nueva con la regla de CA-024-04 |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| — | La spec no añade estados vacíos ni de error | Los de 014, 015, 019 y 021, sin cambio |

## 6. Accesibilidad

- **Contraste de las barras (WCAG 1.4.11):** CA-024-01 y 02 llevan los iconos del sistema a 3:1 o más en los dos casos que fallaron; la píldora queda fuera, como en CA-021-09.
- **Sin cambio** en la semántica, el orden de foco, los anuncios, las alternativas a gestos, reducir movimiento ni el texto grande: la card y las hojas no cambian, solo lo que la app pide a las barras del sistema.
- **Idioma (WCAG 3.1.1/3.1.2):** CA-024-04 hace que la app y la voz de lo que se recorre coincidan con la regla de la 010 también con `ca` primero. La notificación se oye con la voz del sistema cuando el idioma de la app no es el primero del sistema: aceptado por el propietario sin excepción de P6 (CA-024-05).
- **Aceptados sin corregir:** H-022-02 (CA-024-06): con TalkBack y el texto al 200 % el aviso de bloqueo no se anuncia solo, pero se ve y se lee con el foco.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| — | — | — | Sin textos nuevos ni cambiados en la app ni en la web |

## 8. Fuera de alcance

- Los bajos de los revisores de la 023 (B-1 a B-8, M-1): siguen en `specs/023-…/tasks.md` y en la lista de F6 (respuesta 1a).
- La lista de «hallazgos de código ya conocidos» del informe de la 022 (§5): 013-A-M1, B1/M4/M5/M7/M9 de la 015, (d) y (e) de la 016, (3) de la 018, (b) y (c) de la 019, (d) de la 017, N-2 y N-3, C-5, `accessibleNavigation`, enhorabuena y bienvenida (014), `check-recents.sh` en horizontal, test de Chrome del selector, TD-1, TD-2, H-5 y H-6.
- Cambiar el velo de las hojas, la card o cualquier color del prototipo.
- Reprogramar la alarma en más eventos del sistema o pedir el inicio automático en HyperOS (H-022-06 y 07, respuesta 4a).
- Cambiar el idioma de la notificación al del sistema (alternativa descartada en CA-024-05), y el ADR o la constitución 1.11 para una excepción de P6 (Q-024-1).
- Otros dispositivos o marcas (PD-10 cerrada sin verificar, PD-11 aplazada).

## 9. Preguntas abiertas

- **Q-024-1 (H-022-03), respondida (propietario, 2026-10-21): «aceptarlo sin excepción».** Se le presentaron las dos salidas del ADR-0025 (excepción de P6 con ADR y constitución 1.11, recomendada, o descartar el cambio de idioma) y la de aceptarlo sin excepción, con su consecuencia: la ficha de H-022-03 dice que, sin la regla de excepción de Q-022-5, sería **alta** (incumple P6 sin excepción aprobada). El propietario, que es quien decide sobre la constitución, eligió aceptarlo. **[Hecho]** decisión registrada; no se vuelve a abrir salvo que lo señale la beta.
- **[Suposición, plan]** Causa de H-022-10 (CA-024-04) y si los iconos claros valen para todas las notas con velo (CA-024-02).
- **Casillas en el Xiaomi (C-024-1 y 2):** necesitan capturas del móvil del propietario, que son privadas (pueden salir otras apps): se le avisa antes de cada una.

## 10. Casillas de dispositivo

| ID | CA | Qué se comprueba | Dónde |
|---|---|---|---|
| C-024-1 | CA-024-01, 03 | Contraste de los iconos de la barra de navegación con la card (tres botones y gestos, tarea actual y listado) y vuelta tras irse | Xiaomi (donde falló) y emulador de API 37 |
| C-024-2 | CA-024-02, 03 | Contraste de la barra de estado con la hoja «Esta tarea» sobre la nota naranja y la amarilla (tres botones y gestos) y vuelta al cerrar | Xiaomi y emulador de API 37 |
| C-024-3 | CA-024-04 | `ca-ES, en-US` con «Como el sistema» abre en español | Emulador de API 37 (como K-022-056) |
