# Plan técnico — Spec 003: Completar la tarea actual

- **Spec:** `specs/003-completar/spec.md` (estado: En revisión → pendiente de aprobación)
- **ADR aplicables:** ADR-0001 (Flutter; spike S2), ADR-0002 (modelo y repositorio), ADR-0004 (el histórico viaja en la copia)
- **Estado del plan:** Borrador

## 1. Resumen del enfoque

- Completar = caso de uso de dominio `CompleteCurrentTask` que **guarda antes de animar** (CA-003-03a, CL-003-1).
- El botón de completar pasa a ser un `HoldToCompleteButton` propio: controlador de animación de `holdToComplete`, retroceso en `holdRelease`, teclado (Espacio/Intro mantenidos, sin repeticiones), acción semántica "Completar tarea" y **sin** `onTap` semántico (el doble toque del lector no completa).
- La secuencia visual la orquesta un `CompletionController` (Riverpod) con fases `idle → holding → saving → celebrating → idle`; mientras no es `idle`, la pantalla ignora toques, acciones y el gesto atrás (CA-003-09) sin cambiar de aspecto.
- **Rotura sin captura de imagen** (mejora de la decisión I-3 del spike S2): cada mitad es el propio contenido de la nota recortado con `ClipPath` (borde irregular determinista) y transformado (traslación + giro) según la curva `motion.easing.tear`. Así no hay fotograma lento al empezar.
- Enhorabuena: sello ✓, títulos que suben, confeti (cuadrados con borde, colores de la paleta) y "Ahora a por la siguiente →", con los tiempos del prototipo. Con reducir movimiento: fundido de `reducedMotionFade` a una versión estática.
- "Todo hecho." es un estado del enrutado (`HomeRouter`) cuando no hay pendientes y sí completadas (CA-003-11). "Crear una tarea" **abre el editor como ruta** (`Navigator.push`) para que el gesto atrás vuelva a "Todo hecho." (CA-003-10).
- Vibración: `HapticFeedback.lightImpact()` — respeta el ajuste del sistema y **no necesita el permiso `VIBRATE`** (la release sigue sin permisos).

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `entities/task.dart`, `usecases/complete_current_task.dart`, `ports/task_repository.dart` | `Task.complete(at)`; caso de uso con `Clock`; puerto: `complete(id, at)` y `hasCompleted()` |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart` | Implementar `complete` (status, `completedAt`, `updatedAt`) y `hasCompleted`; tests de contrato |
| Estado | `app/providers.dart`, `features/complete/completion_controller.dart` | `BootState.hasCompleted`; `completeCurrentTaskProvider`; controlador de fases; `allDoneProvider` |
| Presentación | `features/complete/hold_to_complete_button.dart`, `tear_overlay.dart`, `success_screen.dart`, `features/all_done/all_done_screen.dart`, `current_task_screen.dart`, `una_app.dart` | Botón de mantener; capa de rotura; enhorabuena; "Todo hecho."; enrutado; editor con color al azar desde "Todo hecho." |
| Nativo | — | Nada (vibración con `HapticFeedback`, sin permisos) |
| l10n | `app_es.arb`, `app_en.arb` | Claves de §7 de la spec |
| Diseño | `design/tokens.json` | Tiempos del sello, subida de títulos y confeti del prototipo (0,3 s / 0,45 s / 0,65 s / 0,38 s; 0,55 s / 0,5 s / 1,1 s) si no existen |

## 3. Modelo de datos y migraciones

Sin cambios: `status` y `completedAt` existen desde la v1 del esquema (spec 001). No hay nueva `schemaVersion`.

## 4. Dependencias nuevas

Ninguna.

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-003-03a, CA-003-06, CL-003-1 | Unitario + contrato de repositorio (memoria y drift) | `test/domain/complete_current_task_test.dart`, `test/data/repository_contract_test.dart` |
| CA-003-01, 02, 08, CL-003-3, 6 | Widget con reloj de pruebas | `test/features/complete/hold_to_complete_button_test.dart` |
| CA-003-07, 09, 13 | Widget (semántica, acciones, bloqueo) | `test/features/complete/completion_flow_test.dart` |
| CA-003-03b, 04, 05, CL-003-5, 7 | Widget (fases y tiempos) + *goldens* (enhorabuena, "Todo hecho.", relleno a mitad) | `completion_flow_test.dart`, `test/goldens/` |
| CA-003-10, 11 | Enrutado | `test/app/home_router_test.dart` |
| CA-003-12 | Widget con repositorio que falla | `completion_flow_test.dart` |
| Flujo completo en dispositivo | Integración | `integration_test/complete_flow_test.dart` |
| Fluidez de la rotura | Manual en el Xiaomi (FrameTiming, como S2) | `docs/perf/baseline.md` |

## 6. Riesgos

- Fluidez de la rotura en gama media (R-02): se mide en el Xiaomi; el recorte con `ClipPath` evita la captura del primer fotograma.
- Accesibilidad de un gesto de mantener: cubierta por la acción semántica y el teclado (CA-003-07/08).
