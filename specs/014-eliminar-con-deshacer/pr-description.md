# PR: spec 014, eliminar con deshacer

**Título:** `feat(014): delete without confirmation and undo for 4 s with a card`

## Qué y por qué

Hasta ahora la única red de seguridad al eliminar era una hoja de confirmación que se interponía cada vez. Con esta PR la red pasa a estar **después**: la tarea se va al momento y una card negra deja recuperarla durante 4 s (más si el sistema da más "Tiempo para actuar"); pasado ese tiempo, la eliminación es definitiva y no queda nada (ADR-0012 sigue en lo demás).

- **Spec:** `specs/014-eliminar-con-deshacer/spec.md` (estado: **Implementada parcialmente**)
- **Tareas:** T-014-01 a T-014-12 (y T-014-10b)
- **Criterios de aceptación cubiertos:** CA-014-01 a CA-014-23 y CL-014-1 a 17 (tabla CA → prueba en `spec.md` §11)
- **ADR nuevos o afectados:** **ADR-0021** (nuevo, eliminar en dos tiempos; sustituye en parte al ADR-0012); constitución 1.6 (excepción a P6: 10 s en Android 8 y 9 con un servicio de accesibilidad)
- **Enmiendas a otras specs:** 001, 004, 005, 006, 007, 008, 009, 011; DEV-51 (nueva) y DEV-09, 10 y 23 obsoletas

## Qué cambia

- **Sin confirmación:** desaparece `delete_confirm_sheet` (menú, acción del lector, "Adjunto no disponible" y listado eliminan directamente). Las 6 claves de la hoja se retiran; entran 5 (`undoDeletedTitle`, `undoButton`, `undoA11yLabel`, `a11yUndone`, `undoError`).
- **La card (`UndoCard`, `UndoCardHost`):** franja negra con "Tarea eliminada", la etiqueta, "Deshacer" y una barra de tiempo del color de la nota; un solo nodo de botón para el lector, sin región en vivo, la primera en el orden de lectura; foco explícito del lector y del teclado; entrada de 220 ms (solo fundido con reducir movimiento); 200 % y horizontal.
- **`UndoController`:** una sola eliminación deshacible; cuenta atrás con reloj inyectable que se detiene mientras el foco del lector o del teclado está en la card y no empieza hasta el primer foco con TalkBack; definitiva por tiempo, por otra eliminación, completar, ir a otra pantalla (observador de navegación), editar, reordenar, segundo plano o muerte de la app.
- **Datos, sin esquema nuevo (v2):** la fila se quita al instante y los archivos quedan **retenidos** (`AttachmentJanitor.hold/releaseHeld/discardHeld`) hasta que es definitiva; `RestoreDeletedTask` la vuelve a insertar con el mismo id y `rank`. El barrido comprueba la protección y después la BD antes de cada borrado.
- **Canal nativo `una/a11y`** (`AccessibilityTimeouts.kt`): solo lectura de `AccessibilityManager` (tiempo recomendado en API 29+, servicio activo, exploración táctil). Sin permisos, sin dependencias nuevas.
- **Documentación:** `architecture`, `testing`, `glossary`, DEV-51, `threat-model` (T-2, T-7), política de privacidad (borrador), matriz de CA-011-02 y PD-10, `PLAN.md`, `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/014-eliminar-con-deshacer/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **1736 tests en verde** (60 omitidos como antes); `gen-l10n` sin avisos | Local (Mac) |
| `node tools/validate-tokens.mjs` | 29 combinaciones de texto y 15 no textuales (barra ≥ 3:1 sobre `undoTrack` con todas las paletas) | Local |
| `/i18n-check`, `/security-check` | Sin hallazgos; sin secretos, sin cambios de manifiesto, `pubspec.yaml` ni `pubspec.lock` | Local |
| `security-reviewer` | 0 altos, 0 medios, 3 bajos; el 1 (`discardHeld`) corregido en `84a4aa3`; el resto, en `PLAN.md` y `spec.md` §11 | `git diff main...HEAD` |
| `a11y-reviewer` | 0 altos, 3 medios, 3 bajos; test de guías de Flutter añadido; el resto, registrado en `PLAN.md` | `git diff main...HEAD` |
| `integration_test` (`delete_flow`, `delete_perf`, `image_flow`, `web_flow`) | En verde | Emulador API 37 |
| TalkBack, tiempo del sistema, animaciones, cortina y segundo plano, teclado real, Switch Access, `check-recents.sh` con la card, 200 % y 600 dp | Resultados y capturas en `dispositivo.md` (un hallazgo corregido en T-014-10b, uno aceptado, uno pendiente) | Emulador API 37 |
| p90 de raster del arrugado | 5,9 ms frente a 5,6 del baseline: sin empeoramiento | **Xiaomi** (*profile*) |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [ ] CI en verde: el job `CI` falló solo por los 10 *goldens* sin subir; se vuelve a lanzar con ellos
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens)
- [x] Accesibilidad: semántica, alternativas a gestos, contraste, texto grande, reducir movimiento
- [x] Documentación actualizada (spec, ADR, glosario, arquitectura)
- [x] Rendimiento del arranque sin degradar (no toca el arranque; raster del arrugado medido)

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados: "Siempre", almacenamiento (T-1, T-7), nativo (T-8), permisos y privacidad (T-13)
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas

## Pendiente antes o después de fusionar

- **[Hecho]** *Goldens* nuevos (10) generados en CI con `actualizar-goldens`, revisados a ojo y subidos.
- **[Cerrado, propietario 2026-10-05]** Hallazgo 1 de `dispositivo.md` ("Tarea recuperada" se oye en el Xiaomi; solo faltaba en el panel de voz del emulador), M2, M3 y B5 (descartados o aceptados como están).
- **[Pendiente, 022]** Casillas de dispositivo (`docs/PLAN.md`, «Casillas de la 014»): TalkBack real, Voice Access, API 26 y 28, PD-10 con la card.

## Nueva dependencia

Ninguna.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
