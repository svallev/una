# Plan técnico — Spec 001: Primer uso y tarea actual

- **Spec:** `specs/001-primer-uso-y-tarea-actual/spec.md`
- **ADR aplicables:** 0001 (Flutter, provisional), 0002 (drift + repositorio), 0009 (monorepo), 0010 (web)
- **Estado del plan:** Aprobado (2026-09-24). F1 cerrada para Android (ADR-0001 aceptado para Android); spec aprobada.

## 1. Resumen del enfoque

Esta spec es el **esqueleto andante** (*walking skeleton*): crea el proyecto Flutter en `app/` con todo lo transversal (identidad, l10n, tokens, tema, BD v1 completa, repositorio, CI, medición del arranque) y encima la primera funcionalidad vertical: bienvenida → editor → tarea actual → persistencia.

El **esquema v1 completo** (tareas, adjuntos, ajustes y los campos futuros) se crea ya en esta spec. Así las siguientes specs no necesitan migraciones y la herramienta de migraciones queda probada desde el primer día.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Proyecto | `app/` (`flutter create --org <PENDIENTE-dominio> --platforms ios,android,web`), `.fvmrc`, `analysis_options.yaml` (lints estrictos), `app/identity.yaml` | Crear el proyecto; `ios/`: mínimo iOS 16, solo vertical; `android/`: minSdk 26, solo vertical, `network_security_config`, sin backup de cachés |
| Identidad | `lib/app/app_identity.dart` + script `tool/gen_identity.dart` | Nombre de la app desde una sola fuente → ARB, InfoPlist.strings, `strings.xml`. El bundle ID usa un **marcador** hasta que exista el dominio (D15) |
| Tokens y tema | `tool/gen_tokens.dart` → `lib/app/theme/tokens.g.dart`; `lib/app/theme/una_theme.dart`; fuentes Archivo y Space Mono en `assets/fonts/` | Generación desde `design/tokens.json`; `ThemeData` M3 adaptado |
| l10n | `lib/l10n/app_es.arb`, `app_en.arb`, `l10n.yaml` | Textos de la spec; resolución `es-*` → es, resto → en |
| Dominio | `lib/domain/entities/task.dart`, `rank.dart`, `queue_position.dart`, `color_picker.dart`; `lib/domain/ports/task_repository.dart`, `clock.dart`, `id_generator.dart`; `usecases/create_task.dart`, `watch_current_task.dart` | Dart puro; invariantes |
| Datos | `lib/data/db/app_database.dart` (tablas `tasks`, `attachments`, `settings`; `schemaVersion = 1`), `drift_schemas/`, `lib/data/drift_task_repository.dart`, `lib/data/settings_repository.dart` | Esquema completo de `docs/architecture.md §3`; índice de arranque |
| Estado | `lib/features/*/providers.dart` (Riverpod) | `currentTaskProvider` (stream), `firstRunProvider` |
| Presentación | `features/first_run/welcome_intro.dart`, `features/editor/task_editor_screen.dart` (modo "primera tarea"), `features/current_task/current_task_screen.dart`, `ui/sticky_note.dart`, `ui/brutal_button.dart`, `features/app_error/storage_error_screen.dart` | Tal como la spec y el prototipo |
| Arranque | `lib/main.dart`, splash nativo (color `paper` + logotipo) | Abrir la BD y leer la tarea actual antes del primer fotograma; el resto se difiere |
| CI | `.github/workflows/ci.yml` activo para `app/**` | format, analyze, test, test de migraciones, comprobación de i18n y tokens, build web y apk debug, build iOS sin firmar |
| Web | `vercel.json`, `tools/install-flutter.sh` | ADR-0010 |

## 3. Modelo de datos y migraciones

`schemaVersion = 1` con las tres tablas completas. Captura inicial con `drift_dev make-migrations` y un test que abre la BD v1 vacía y con datos de ejemplo.

## 4. Dependencias nuevas (propuesta, a validar según `threat-model.md §5`)

| Paquete | Uso | Licencia |
|---|---|---|
| `drift`, `drift_flutter`, `sqlite3_flutter_libs` (dev: `drift_dev`, `build_runner`) | BD | MIT |
| `flutter_riverpod` | Estado | MIT |
| `uuid` | UUIDv7 | MIT |
| `intl` + `flutter_localizations` (SDK) | i18n | BSD |
| `path_provider` | Directorios del sandbox | BSD |
| `flutter_native_splash` (dev) | Splash nativo | MIT |
| Fuentes Archivo y Space Mono | Tipografía empaquetada | OFL |

Nada de paquetes de analítica, crash reporting ni fuentes remotas (`google_fonts` descartado: descarga en tiempo de ejecución).

## 5. Estrategia de tests

| CA | Tipo | Archivo previsto |
|---|---|---|
| CA-001-01, 05 | Widget (con reloj falso) + variante de reducir movimiento | `test/features/first_run/welcome_intro_test.dart` |
| CA-001-02, 03, 04, CL-001-1/2 | Widget | `test/features/editor/first_task_editor_test.dart` |
| CA-001-06, 07, CL-001-3/9 | Widget + *golden* (ES/EN, escala 1,0 y 2,0) | `test/features/current_task/current_task_screen_test.dart` |
| CA-001-08 | Unitario | `test/domain/color_picker_test.dart` |
| Rank (orden fraccional) | Unitario + propiedades (1 000 inserciones aleatorias mantienen el orden) | `test/domain/rank_test.dart` |
| CA-001-10 | Integración (BD real en disco, reapertura) | `integration_test/persistence_test.dart` |
| CA-001-09 | Integración de rendimiento en dispositivo (*release/profile*) | `integration_test/startup_perf_test.dart` |
| CA-001-11 | Integración: sin llamadas de red (`HttpOverrides` que falla ante cualquier conexión) | `integration_test/offline_test.dart` |
| Migraciones | Generado por drift | `test/data/migration_test.dart` |
| i18n | Unitario: mismas claves en ES y EN, sin textos en los widgets | `test/l10n/l10n_consistency_test.dart` |
| Tokens | Unitario: `tokens.g.dart` sincronizado + contraste | `test/app/tokens_test.dart` |

## 6. Seguridad, accesibilidad y rendimiento

- Checklist: "Siempre", "almacenamiento/esquema" y "CI".
- Android: `android:allowBackup` + reglas (ADR-0004); `usesCleartextTraffic=false`; solo `MainActivity` exportada.
- Accesibilidad: `Semantics` en la nota, el menú y la bienvenida; `MediaQuery.disableAnimations` para reducir movimiento; test con `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline` e `iOSTapTargetGuideline`.
- Rendimiento: medir TTFD en un dispositivo real y registrar la línea base en `docs/perf/baseline.md`.

## 7. Riesgos y alternativas

- **Tiempo de apertura de SQLite en frío:** si supera el presupuesto, se cachea la tarea actual en un archivo pequeño para el primer fotograma y se valida contra la BD después.
- **Fuentes empaquetadas (tamaño):** subconjunto de pesos (Archivo 500/700/800/900, Space Mono 400/700).
