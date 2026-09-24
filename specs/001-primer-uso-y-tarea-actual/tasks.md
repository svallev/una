# Tareas — Spec 001: Primer uso y tarea actual

Requisitos: F0 completa para Android (D17: sin Xcode; el job iOS de CI compila sin firmar), F1 en verde y spec + plan aprobados. ✅ 2026-09-24. `[P]` = puede hacerse en paralelo con la anterior.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-001-01 | Crear `app/` con `flutter create` (org con marcador), `.fvmrc`, lints estrictos, solo vertical, iOS 16 / minSdk 26 | — | `flutter analyze` sin avisos; la app vacía arranca en el simulador y el emulador | — |
| T-001-02 | Activar `.github/workflows/ci.yml` para `app/` (format, analyze, test, build web/apk/ios sin firmar) | 01 | CI verde en una PR | — |
| T-001-03 [P] | Identidad centralizada: `identity.yaml` → generador → ARB `appName`, InfoPlist.strings, `strings.xml` | 01 | Test: cambiar el nombre en un solo sitio lo cambia en los tres; búsqueda de "Una" en `lib/` = 0 resultados | P7 |
| T-001-04 [P] | Generador de tokens `design/tokens.json` → `tokens.g.dart` + test de sincronización y contraste | 01 | `tokens_test.dart` en verde; CI falla si se edita el JSON sin regenerar | — |
| T-001-05 | `UnaTheme` (M3 adaptado) + fuentes empaquetadas + componentes `StickyNote` y `BrutalButton` | 04 | *Goldens* de los componentes | CA-001-06 |
| T-001-06 [P] | l10n: `l10n.yaml`, ARB ES/EN con los textos de la spec, resolución del idioma, test de consistencia | 01 | Test de claves; `es-MX` → ES; `fr-FR` → EN | P7 |
| T-001-07 | Dominio: `Task`, `Rank` (fractional indexing), `QueuePosition`, `ColorPicker`, puertos `TaskRepository`, `Clock`, `IdGenerator` | 01 | Tests unitarios y de propiedades de `Rank`; `ColorPicker` nunca repite el color actual | CA-001-08 |
| T-001-08 | BD drift v1 completa (tareas, adjuntos, ajustes, índices) + `make-migrations` + test de migración | 07 | `migration_test.dart` verde; esquema capturado en `drift_schemas/` | CA-001-10 |
| T-001-09 | `DriftTaskRepository` + `InMemoryTaskRepository` con la misma batería de tests de contrato | 08 | Tests de contrato verdes en ambas implementaciones | CA-001-10 |
| T-001-10 | Casos de uso `CreateTask` (primera tarea) y `WatchCurrentTask` + ajuste `firstRunDone` | 09 | Tests unitarios | CA-001-04, 06 |
| T-001-11 | Arranque: `main.dart` lee la tarea actual antes del primer fotograma; splash nativo; pantalla de error de almacenamiento | 10 | Test de integración de error simulado; TTFD registrado | CA-001-09, CL-001-6 |
| T-001-12 | `WelcomeIntro` (máquina de escribir, se puede saltar, reducir movimiento, anuncio accesible) | 05, 06 | Tests de widget con reloj falso, en ambos modos | CA-001-01, 05 |
| T-001-13 | Editor en modo "primera tarea" (sin cancelar, bloqueo del gesto atrás, validación, contador) | 05, 06, 10 | Tests de widget | CA-001-02, 03, 04, CL-001-1/2 |
| T-001-14 | `CurrentTaskScreen` (nota, tamaño por longitud, escala de texto, desplazamiento, semántica) | 05, 10 | Widget + *goldens* ES/EN × escala 1,0 y 2,0 | CA-001-06, 07, CL-001-3/9 |
| T-001-15 | Enrutado del arranque: sin primer uso → bienvenida; primer uso hecho y sin tareas → editor; con tareas → tarea actual | 11–14 | Test de integración de los 3 caminos | CA-001-03, 05, 09 |
| T-001-16 | Test de integración de persistencia y sin red (`HttpOverrides` que falla) | 15 | `persistence_test`, `offline_test` verdes | CA-001-10, 11 |
| T-001-17 | Test de rendimiento de arranque en un dispositivo real + `docs/perf/baseline.md` | 15 | p50 < 1 s en Android de referencia | CA-001-09 |
| T-001-18 [P] | Web de pruebas: `vercel.json` con cabeceras, script de Flutter, banner "Versión de pruebas" | 02 | Preview de la PR accesible; cabeceras comprobadas con `curl -I` | ADR-0010 |
| T-001-19 | Revisiones: subagentes `spec-reviewer`, `a11y-reviewer` y `security-reviewer`; skill `/security-check` | 01–18 | Hallazgos resueltos o registrados | DoD |

## Cierre

- [ ] Todos los CA-001 tienen test en verde (tabla del plan).
- [ ] Definition of Done completa.
- [ ] Preguntas P-1 y P-2 resueltas por producto (o aplicada la recomendación).
- [ ] Spec marcada como **Implementada**.
