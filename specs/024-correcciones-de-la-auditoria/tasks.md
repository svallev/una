# Tareas — Spec 024: Correcciones de la auditoría

**Siguiente:** T-024-02 <!-- el coordinador la actualiza al cortar cada sesión: la tarea que va después -->

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se hacen **de una en una, en orden** (nada en paralelo). La columna **Toca** dice qué archivos o zonas cambia cada tarea, para revisar el plan y acotar lo que lee el subagente. Sin textos ni tokens nuevos. Rama de implementación: `feat/024-correcciones-de-la-auditoria`.

| ID | Tarea | Depende de | Toca | Verificación | CA |
|---|---|---|---|---|---|
| T-024-01 | Card de deshacer: estilo `systemBarsOnDarkNavStyle` y `AnnotatedRegion` con tamaño en `UndoCard`, solo con la barra de navegación abajo (plan §1.2) | — | `lib/app/system_bars.dart`, `lib/features/delete/undo_card.dart`, `test/app/system_bars_test.dart` | Tests de la tabla §5 (CA-024-01, 03; CL-024-1 a 3) en verde; los de CA-021-09 sin cambios | CA-024-01, 03 |
| T-024-02 | Hojas: estilo `systemBarsUnderScrimStyle` y `AnnotatedRegion` sin tamaño en `showUnaSheet` (plan §1.3); test de contraste desde los tokens. Si el primer test muestra que el punto de arriba no la encuentra (R-3), se para y se avisa antes de pasar al contador | T-024-01 | `lib/app/system_bars.dart`, `lib/ui/una_sheet.dart`, `test/app/system_bars_test.dart`, `test/ui/sheet_scrim_contrast_test.dart` | Tests §5 (CA-024-02, 03; CL-024-6, 11) en verde | CA-024-02, 03 |
| T-024-03 | Catalán: **primero** `integration_test/system_locales_test.dart`, **solo en el emulador** de API 37 (idiomas con `adb` y restaurados al acabar, plan §6), con `ca-ES, en-US` sobre el código actual (debe fallar: confirma la causa, R-4; si no falla, se para); después `values-ca` en `gen_android_strings.dart`, archivo generado, tests del generador y de `localeConfig`, y la prueba de integración en verde. Resultado de C-024-3 en `dispositivo.md` (nuevo) | — | `tool/gen_android_strings.dart`, `android/app/src/main/res/values-ca/`, `test/tool/gen_android_strings_test.dart`, `test/app/locale_config_test.dart`, `integration_test/system_locales_test.dart`, `specs/024-…/dispositivo.md` | Fallo antes y verde después en el emulador; `--check` limpio; C-024-3 (app y Ajustes en español con «Como el sistema»; con `en-US, ca-ES`, inglés) | CA-024-04 |
| T-024-04 | Casillas en el emulador de API 37: C-024-1 y C-024-2 (tres botones y gestos; card en la tarea actual, «Todo hecho.» y listado; hoja «Esta tarea» sobre la nota naranja y la amarilla y vuelta al cerrar), contraste medido de las capturas, y las pruebas a mano del plan §5 (horizontal, giro con la card, `screenrecord` del tránsito, hoja que abre otra, TalkBack) | T-024-01, 02 | `specs/024-…/dispositivo.md` | Tabla con el contraste de cada caso ≥ 3:1 (píldora aparte) | CA-024-01, 02, 03 |
| T-024-05 | **Coordinador, con el Xiaomi** (permiso del propietario, `--keep-app-running`, tareas ficticias, notificaciones ocultas, aviso antes de cada captura, recorte y borrado en el Mac y en el móvil: plan §6): C-024-1 y C-024-2 como en T-024-04; anotar si HyperOS aclara la píldora | T-024-04 | `specs/024-…/dispositivo.md` | Mismo criterio; si un icono sigue < 3:1, se para y se pregunta (R-1) | CA-024-01, 02, 03 |
| T-024-06 | Documentación de los hallazgos (plan §1.5): H-022-02 y 03 Aceptados, 06 y 07 Cerrados (límite del sistema), 04, 05 y 10 Corregidos con C-024-1 a 3; notas en CA-019-11, 13, 21, CL-019-4, ADR-0025, CA-021-09 y CA-010-02; N-1 (a) de la 019; 019 **Implementada**; estados de 015 y 021; `docs/PLAN.md` («Casillas de la 024», hallazgos de la 022, trazabilidad, F5) y `CLAUDE.md` | T-024-05 | `specs/022-…/informe.md`, `specs/019-notificaciones/{spec,dispositivo}.md`, `docs/adr/0025-*.md`, `specs/021-…/spec.md`, `specs/015-ajustes/spec.md`, `specs/010-*/spec.md`, `docs/PLAN.md`, `CLAUDE.md` | `rg 'H-022-0[2-7]\|H-022-10'` sin «Abierto»; tests de la 019 sin cambios; `landing/src/help.*` sin cambios | CA-024-05 a 08 |

## Cierre

- [ ] Todos los CA de la spec tienen test en verde o su casilla/revisión hecha.
- [ ] `/i18n-check`, `/tokens-validate`, `/security-check`; `a11y-reviewer` y `security-reviewer` sobre `git diff main...HEAD`.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.

## Estado

Una fila por tarea, **≤ 3 líneas**: qué se hizo, dónde se verificó (tests, emulador), fallos encontrados y lo pendiente con **[Suposición]**/**[Pendiente]**. El detalle va en el mensaje del commit; lo que sirve para otras tareas, a las **Trampas** de `.claude/agents/spec-task.md`.

| Tareas | Estado | Commit |
|---|---|---|
| T-024-01 | Hecha: `systemBarsOnDarkNavStyle` y `AnnotatedRegion(sized)` en `UndoCard` (valor claro solo con `viewPadding.bottom > 0` y card a todo el ancho; si no, `systemBarsStyle`, y la región siempre montada para no recrear la card al girar). 13 tests nuevos en `system_bars_test.dart` (tarea actual, «Todo hecho.», listado, sustitución sin parpadeo, barra a un lado, card estrecha, giro, caducar/Deshacer/segundo plano/salir): fallaban antes (navegación oscura); 3 mutaciones, 2 detectadas (`sized: false` es equivalente en tests). Analyze limpio y `flutter test -j 3` 4493 verdes. **[Pendiente]** reordenar en el listado no tiene test propio (misma salida del árbol); el emulador va en T-024-04. | (este commit) |
