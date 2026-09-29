# Tareas — Spec 010: Idioma automático

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR puede agrupar varias tareas consecutivas. En este proyecto se ejecutan **una a una**, con un `spec-task` por tarea. La T-010-10 la hace la sesión coordinadora (emulador).

Todas terminan con `fvm dart format .`, `fvm flutter analyze --fatal-infos` y `fvm flutter test` en verde, y con un commit `test(010): …` o `fix(010): …`.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-010-01 | Retirar el ajuste manual: quitar `setting` y `supportedAppLocales` de `locale_resolution.dart`, borrar el test `'CA-010-03: …'` y ampliar los tests de 01/02 (`es-419`, lista sin ningún idioma admitido, `ar`/`he` → en) | — | `locale_resolution_test.dart` en verde; `grep -rn "setting:\|supportedAppLocales" lib test` vacío | 01, 02, CL-010-4 |
| T-010-02 [P] | Test de formatos ES/EN: tamaño de PDF, `menuAllTasksCount`, `editorCharsLeft`, `a11yDeletedFromList` | — | `test/l10n/formats_test.dart` en verde | 04 |
| T-010-03 [P] | Test del nombre de la app: sin el nombre escrito tal cual en `lib/` ni en los ARB; título de la app = `displayName`; `strings.xml` generado. Confirmar el paso `gen_identity --check` en CI | — | `test/app/app_identity_test.dart` en verde; que el test falle si se escribe el nombre a mano en un archivo de prueba temporal (y luego se borra) | 05 |
| T-010-04 | Helper `test/support/l10n_leaks.dart` (fragmentos del otro idioma sacados de los ARB; recorrido del árbol semántico y de los anuncios) con tests del propio helper | — | Tests del helper: detecta una etiqueta en EN dentro de la app en ES y no salta con textos iguales en los dos idiomas | 07 |
| T-010-05 | Fugas de idioma, 1.ª parte: bienvenida, editor, tarea actual (solo texto, imagen), menú, "Todo hecho." y error de almacenamiento, en ES y EN, con anuncios de completar y eliminar. Más CA-010-10: sin `locale` ni `LocaleStringAttribute` ajenos, con una tarea en catalán | T-010-04 | `test/l10n/semantics_language_test.dart` en verde | 07, 10 |
| T-010-06 | Fugas de idioma, 2.ª parte: tarea con PDF y con web, hojas (adjuntar, URL, eliminar) y listado (con el anuncio de eliminar desde la fila), en ES y EN | T-010-05 | Mismo archivo en verde | 07, 10 |
| T-010-07 | Cambio de idioma en caliente, sin adjuntos: tarea actual, editor con texto, menú abierto, hoja de eliminar abierta y listado; vuelta en menos de 10 min y en 10 min o más (CA-001-12 en EN); `ar` → EN y LTR sin perder el estado | T-010-01 | `test/app/locale_change_test.dart` en verde | 06, CL-010-4 |
| T-010-08 | Cambio de idioma en caliente, con adjuntos: imagen, PDF (misma página y zoom) y web (sin recargar) + orden de las acciones del lector antes y después (tarea solo texto, imagen, PDF, web, fila del listado), ES → EN y EN → ES. Si el orden falla, se corrige en `semantics_action_order.dart` (plan §7) | T-010-07 | Mismo archivo en verde | 06, 11 |
| T-010-09 [P] | Texto al 200 % en inglés, con `loadAppFonts`, a 360 × 640: pantallas y hojas de CA-010-07 sin desbordamientos | — | `test/l10n/large_text_en_test.dart` en verde | 12 |
| T-010-10 | **Verificación manual en el emulador (coordinador).** (a) Idiomas del sistema `fr-FR` + `es-ES` → español (suposición de CA-010-02). (b) TalkBack con fr-FR, ca-ES, es-MX y en-GB: voz de la interfaz y de una tarea, anuncios, menú de acciones y título de hoja. (c) CA-010-06 con TalkBack: foco en la nota, con el menú abierto y con el editor a medias; cambio es → en. (d) Orden de las acciones. (e) Switch Access y teclado físico tras el cambio. (f) Texto al máximo en inglés. (g) CL-010-5: el sistema cierra la app en Ajustes. (h) CL-010-7: dónde queda el foco al pulsar "Configuración y perfil". Anotar los resultados aquí | T-010-01 a 09 | Tabla de resultados en este archivo; el propietario la confirma | 02, 06, 10, 11, 12, CL-010-3, 5, 7 |
| T-010-11 | Cierre: `/i18n-check`, `/security-check`, `a11y-reviewer` sobre el diff, `spec-reviewer` (cumplimiento), lista CA → test, DoD, spec en **Implementada**, `PLAN.md` y `CLAUDE.md` al día, descripción de la PR (sin push hasta el sí del propietario) | T-010-10 | Checklist de cierre completa | todos |

## Estado

| Tarea | Estado | Notas |
|---|---|---|
| T-010-01 | [Hecho] 2026-09-29 | `resolveAppLocale` sin `setting`; fuera `supportedAppLocales` y el test de CA-010-03. Tests nuevos: `es-419` y `es-Latn` con subetiquetas, `en-GB`, lista sin admitidos y vacía → en, `ar`/`he` → en (CL-010-4). `locale_resolution_test.dart` 5/5; suite completa 1072 en verde; el grep sale vacío. Sin emulador (no se pedía) |
| T-010-02 | [Hecho] 2026-09-29 | `test/l10n/formats_test.dart` (5 tests, sin widgets: `lookupAppLocalizations` + `pdfSize`): "2,4 MB"/"2.4 MB", "3 KB" en los dos, `menuAllTasksCount` 1/3, `editorCharsLeft` 1/5, `a11yDeletedFromList` 1/3, pares de la spec tal cual. Pasan sin cambiar `lib/` (los ARB ya cumplían). Suite 1077 en verde. Sin emulador (no se pedía) |
| T-010-03 | [Hecho] 2026-09-29 | `test/app/app_identity_test.dart` (nuevo, 7 tests): `AppIdentity` = `identity.yaml`; ni `displayName` ni `wordmark` como palabra suelta (distingue mayúsculas) en `lib/**/*.dart` ni en los ARB, salvo `app_identity.g.dart` (no cuentan "ninguna." ni `una.sqlite`, el archivo de la BD); `strings.xml` generado + `@string/app_name` en el manifiesto; título = `displayName` en `UnaApp` (ES y EN) y `StorageErrorApp`; paso `gen_identity --check` en `ci.yml` [Hecho]. Comprobado que falla con `lib/tmp_name_leak.dart` y con una clave temporal en `app_es.arb` (borrados). Suite 1084 en verde. Sin emulador |
| T-010-04 | [Hecho] 2026-09-29 | `test/support/l10n_leaks.dart`: `L10nLeaks` (fragmentos ICU del otro ARB, ≥ 4 caracteres, fuera los que están en el idioma propio; ambas comprobaciones **por palabra completa**, para que "Cancel" no salte en "Cancelar"), `semanticsTexts`, `findL10nLeaks`/`expectNoL10nLeaks` (semántica + `takeAnnouncements`) y lista blanca (vacía). Las pistas `onTapHint` llegan como acciones personalizadas. `test/l10n/l10n_leaks_test.dart` 11/11: detecta EN en ES (etiqueta, pista, valor, tooltip, acción, anuncio) y no salta con textos propios ni iguales ("PDF", "https://"). Suite 1095 en verde. Sin emulador |

## Resultados de T-010-10

*(Pendiente)*

## Cierre

- [ ] Todos los CA de la spec tienen test en verde (o verificación manual anotada: CA-010-02, la parte de voz de CA-010-10 y el foco de CA-010-06).
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.
