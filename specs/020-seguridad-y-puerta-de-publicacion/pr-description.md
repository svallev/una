# PR: spec 020, Seguridad y puerta de publicación

**Título:** `feat(020): release workflow with strict and testers modes, hardened gate and MASTG pass`

## Qué y por qué

Primera spec de F5. Nada se publica ni se entrega a testers sin un **trabajo de publicación** en verde sobre ese commit. El trabajo (`.github/workflows/release.yml`, aparte de `ci.yml`) compila desde el commit los APK por ABI y el AAB de *release* y les pasa todas las comprobaciones. Tiene dos modos:

- **Modo estricto**, con una etiqueta `v*`: todo tiene que pasar. Hoy falla siempre por las direcciones marcador y las marcas de la política, como debe.
- **Modo testers**, lanzado a mano desde `main`: los avisos de la lista cerrada no paran el trabajo; un permiso de más o un paquete depurable, sí.

Además: la puerta de la identidad y de la política está endurecida, hay herramientas nuevas en la CI de cada PR, los hallazgos bajos del código de la app están corregidos y se hizo la pasada MASTG en el emulador. La app no cambia de pantallas, textos ni interacción.

- **Spec:** `specs/020-seguridad-y-puerta-de-publicacion/spec.md`. Estado: **Implementada parcialmente**, hasta las dos ejecuciones reales en GitHub tras fusionar.
- **Tareas:** T-020-01 a T-020-16.
- **Criterios de aceptación cubiertos:** CA-020-01 a 28. Los 01, 03, 04 y 06 tienen el *lint* y la simulación en local; su ejecución real va después de fusionar.
- **ADR nuevos o afectados:** ninguno. La constitución sigue en la 1.10, sin excepciones.
- **Documentos:** `threat-model.md` 1.8 (§7 con H-1 aceptado), `checklist.md` (sección «Trabajo de publicación»), `/release-checklist`, `testing.md`, glosario, `docs/perf/baseline.md`, `PLAN.md` y `CLAUDE.md`.

## Qué cambia

- **Trabajo de publicación** (`release.yml`, `tools/release/`, `app/tool/release_summary.dart`):
  - Disparadores `v*` y `workflow_dispatch`.
  - Pide solo `contents: read` y `actions: read`, con las acciones fijadas por SHA, `persist-credentials: false` y sin secretos.
  - Cada comprobación pasa por `run-check.sh`. El resumen falla cerrado: cruza el `outcome` de GitHub con `results.tsv` y usa una lista fija de ids y una tabla cerrada de avisos.
  - Solo sube `summary.md` y el archivo de avisos de terceros, nunca `.apk` ni `.aab`.
  - Comprobaciones: CI del commit, etiqueta, identidad y política, textos nativos, permisos y componentes, clases de pruebas, PDFium, licencias, tamaño, estática MASTG, *package name* y firma.
- **Puerta de la identidad endurecida** (`check_release_config.dart`): ruta restringida, `GateIssue` con clases y `--json` atómico. Las marcas `[Suposición]`, `[Assumption]`, `[Pendiente]` y `[Pending]` de la política bloquean en modo estricto.
- **Herramientas en la CI de cada PR:**
  - `check-package.sh`, la estática MASTG sobre APK y AAB, que incluye la búsqueda de secretos con una lista de excepciones vacía.
  - `check-gradle-wrapper.sh`, con `distributionSha256Sum` y `tools/gradle-wrapper.lock`.
  - `check-size.sh`.
  - Manifiestos negativos de permisos y componentes, que ahora incluyen `<uses-permission-sdk-23>` y `-m`.
- **Hallazgos bajos del código, corregidos:**
  - Ajustes acotados en SQL.
  - `firstRunDone` y `hasEverHadTasks` caen a su valor por defecto.
  - El barrido del *janitor* va por lotes.
  - Migración probada.
  - El tope de `PickedItems` se aplica antes de `getItemAt`.
  - `IntentSpecs` con `FLAG_IMMUTABLE` y JUnit.
  - `host_display` ya no descodifica a medias un `%XX` mal formado.
  - Dos comentarios de `LinkOpener` aclarados.
- **Pasada MASTG** en el emulador de API 37 (`mastg.md`): 17 pruebas (con 5b y 12b), sin hallazgos altos.
  - **H-1** (medio): la consulta de autorrelleno de la WebView a Google. **Aceptado** por el propietario y anotado para Data Safety.
  - **H-2** (bajo): la ruta de compilación dentro de `libapp.so`. Va a la 023.
  - **O-1:** una observación que no se reprodujo. Va a la 022.
- **Sin cambios:** dependencias (solo la suma del *wrapper* de Gradle), permisos, manifiesto, ARB, recursos, pantallas y *goldens*.

## Cómo se ha verificado

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `validate-tokens` | Limpios | Mac |
| `flutter test` | 4199 en verde y 116 saltados. 1 fallo suelto de `codesign` del Mac, cuando varios `dart run` firman a la vez `libpdfium.dylib`; el archivo pasa solo y en Linux no ocurre (Trampas de `spec-task.md`) | Mac |
| Test de la firma del APK real | En verde con el Java de Android Studio (aviso `debug`); se salta si no hay Java | Mac |
| Mutaciones de la puerta (T-020-07) | 58, todas detectadas (2 equivalentes) | Mac |
| Pasos de `release.yml` simulados con los APK y AAB reales | Testers: «verde con avisos». Estricto: rojo | Mac |
| Arranque p50 | Rama 422/420 ms frente a `main` 453/430 ms (deriva 23 ms) | Emulador API 37 |
| Pasada MASTG (CA-020-23) | 15 [Hecho] y 2 hallazgos | Emulador API 37 con root |

### CA → prueba

| CA | Prueba o evidencia |
|---|---|
| 01 | `release_workflow_test.dart` (disparadores, SHA, sin secretos, `GH_TOKEN` solo en `ci-runs`). **Ejecución real tras fusionar** |
| 02 | `run_check_test`, `release_summary_test`, `check_package_aab_test`, `check_apk_no_test_classes_test`, `check_pdfium_test`, `check_size_test`, `check_android_permissions_test`, `release_workflow_test` |
| 03 | `check_tag_test`, `check_signature_test`, `check_package_aab_test`, `release_workflow_test`. **Etiqueta real tras fusionar** |
| 04 | `release_summary_test` («en testers los avisos no paran…», «un permiso de más… rojo también en testers»). **Ejecución real tras fusionar** |
| 05 | `check_release_config_test`, `check_signature_test`, `check_tag_test`, `release_summary_test` |
| 06 | `release_workflow_test` («deja solo el archivo de avisos…»). **Lista real de artefactos tras fusionar** |
| 07 | `release_summary_test`, `release_workflow_test` y el negativo de cada herramienta (incluido el test de regla contra `\| grep -q`) |
| 08 | `release_workflow_test` («la CI de las PR no pasa la puerta…») |
| 09–12 | `check_release_config_test` |
| 13 | `check_android_permissions_test` y `tools/fixtures/manifests/` |
| 14 | `check_gradle_wrapper_test` |
| 15 | `png_lite_test` y `gen_icons_test` |
| 16 | `test/data/settings_bounds_test.dart` |
| 17 | `test/app/boot_state_test.dart` |
| 18 | Revisión del diff (`LinkOpener.kt`) |
| 19 | `test/domain/attachment_janitor_batches_test.dart` |
| 20 | `test/drift/app/migration_test.dart` |
| 21 | `PickedItemsTest.kt` (5000 → 10 accesos) y `native_pending_intents_test.dart` |
| 22 | `check_package_test` (grupos a–g) y `check_package_aab_test` |
| 23 | `mastg.md` (pruebas 1–17, 5b y 12b) |
| 24 | Hallazgos de `mastg.md` (H-1, H-2, O-1 y C-1 a C-5 del cierre) y `PLAN.md` |
| 25 | `docs/perf/baseline.md`; el diff no toca ARB, manifiesto, `pubspec.lock` ni *goldens* |
| 26 | `checklist.md`, `threat-model.md` 1.8, `/release-checklist`, glosario, `testing.md`, `PLAN.md` y `CLAUDE.md` |
| 27 | `host_display_test.dart`, `HostDisplayTest.kt` y `fixtures/notifications/hosts.txt` |
| 28 | `IntentSpecsTest.kt`, `ActivationNonceTest.kt`, `WakeActionsTest.kt`, `NotificationSpecTest.kt` y `native_pending_intents_test.dart` |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (01, 03, 04 y 06: falta la ejecución real tras fusionar)
- [ ] CI de la PR en verde
- [x] Textos nuevos en ES y EN; ninguno incrustado (no hay textos nuevos)
- [x] Sin valores visuales sueltos (sin UI)
- [x] Accesibilidad: N/A (sin cambios de UI)
- [x] Documentación actualizada
- [x] Rendimiento del arranque sin degradar (medición en `baseline.md`)
- [x] Título de la PR en formato Conventional Commits

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] «Siempre»: sin secretos en el diff (las coincidencias son claves falsas que arman los tests), sin archivos de firma en el índice, sin permisos nuevos y sin llamadas de red nuevas.
- [x] Dependencias: solo `distributionSha256Sum` del *wrapper* de Gradle (CL-020-18).
- [x] Integración nativa: ningún componente exportado nuevo; `PendingIntent` descritos en `IntentSpecs` y creados solo en los adaptadores.
- [x] CI y workflows: permisos mínimos, acciones fijadas por SHA, sin `pull_request_target`, ningún `${{ }}` dentro de un `run:` y nada de `\| grep -q` bajo `pipefail`.
- [x] `security-reviewer` de cierre: 0 altos y 0 importantes. 4 menores: 2 falsos verdes de la puerta y los validadores, **corregidos** (`d2d952a` y `8a40de0`); el *wrapper* de Gradle en el trabajo y el *ruleset* de `v*`, **anotados** (C-4 y C-5 de `mastg.md`, en `PLAN.md`).
- [x] `spec-reviewer` de cierre: sin bloqueantes ni discrepancias entre el código y la spec.
- [x] Riesgo aceptado: H-1 (`threat-model.md` §7), que va a Data Safety (PD-9, 023).

## Pendiente antes o después de fusionar

- **Tras fusionar, con permiso del propietario:**
  1. Lanzar el trabajo en modo testers desde `main`.
  2. Crear una etiqueta `v0.1.0` de prueba: modo estricto, rojo esperado. Se borra después.
  3. Anotar los dos resúmenes y los artefactos en `mastg.md`, en una PR de documentación.

  Entonces la spec pasa a **Implementada**.
- **[Pendiente, F6]:**
  - `tools/release/upload-cert.sha256`.
  - La configuración del repositorio (T-11): un *ruleset* para las etiquetas `v*` y `main` (C-4), la aprobación de los workflows de *forks* y el *secret scanning*.
- **[Pendiente]:**
  - El paso `gradle-wrapper` en el trabajo de publicación (C-5).
  - `actionlint` en la CI.
  - H-2, en la 023.
  - O-1, en la 022.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
