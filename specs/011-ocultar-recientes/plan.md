# Plan técnico — Spec 011: Ocultar el contenido en "Recientes"

- **Spec:** `specs/011-ocultar-recientes/spec.md` (estado: **Aprobada**, 2026-09-30)
- **ADR aplicables:** ninguno vigente. Se propone **ADR-0019** (tarea T-011-06): "Ocultar "Recientes" sin bloquear las capturas" (decisión con impacto de seguridad y con un comportamiento distinto por versión de Android)
- **Estado del plan:** **Aprobado** (propietario, 2026-09-30), con las dos decisiones de §8 aceptadas: sin test automático de CI (verificación con `adb`) y ADR-0019
- **Etiquetas:** [Hecho], [Suposición] y [Pendiente]

## 1. Resumen del enfoque

- **Todo es nativo (Kotlin), en `MainActivity`. No hay Dart, ni canal, ni ajuste, ni esquema, ni dependencias, ni textos.** Lo que se oculta es lo que el sistema guarda al pasar la app a segundo plano; la interfaz de Flutter no interviene.
- Una clase pequeña, `RecentsPrivacy.kt`, con dos mecanismos y un único punto de entrada desde `MainActivity` (`onCreate`, `onPause`, `onResume`):
  - **Mecanismo A (Android 13+, API 33):** `Activity.setRecentsScreenshotEnabled(false)`, una sola vez al crear la actividad. Es la petición explícita al sistema de que no haga la miniatura. No toca la ventana, así que las capturas con la app abierta no se ven afectadas (CA-011-04).
  - **Mecanismo B (Android 8–12, API 26–32):** marcar la ventana como segura (`FLAG_SECURE`) en `onPause` y quitarla en `onResume`. Con la app en primer plano no hay marca, así que las capturas funcionan.
- **[Suposición] a validar primero (T-011-01, emulador API 37):** que A oculta la miniatura sin parpadeo al volver. Si no, se usa **B en todas las versiones** (un solo camino, más fácil de verificar ahora que Android 8–12 está aplazado, PD-10).
- **Cómo se verifica:** no hay tests unitarios de Kotlin en el proyecto ni se añade JUnit (P11: dependencia nueva). La verificación es un script con `adb` (`tools/check-recents.sh`) y una guía manual (`specs/011-ocultar-recientes/dispositivo.md`), como en la 007. Ver §5 y el riesgo R-3.

### Lo que se sabe y lo que no

| Punto | Estado |
|---|---|
| `FLAG_SECURE` hace que las capturas de esa ventana salgan en blanco (documentación de Android, "Set FLAG_SECURE Window Flag") | **[Hecho]** |
| `setRecentsScreenshotEnabled` existe desde Android 13 y evita la miniatura de "Recientes" | **[Suposición]** No la he encontrado en la documentación consultada; se comprueba en el emulador en T-011-01 |
| En Android 8–12, poner `FLAG_SECURE` en `onPause` llega antes de que el sistema haga la miniatura | **[Suposición]** Es lo que usan varios plugins, pero depende de la versión y del fabricante. **No se puede verificar ahora** (PD-10): por eso la regla de desempate de la spec acepta la miniatura visible en Android 8–12 en la beta |
| Quitar o poner `FLAG_SECURE` con la app viva no reconstruye la superficie de Flutter ni parpadea | **[Suposición]** Se mide en T-011-03 (CA-011-03) |
| `compileSdk` de Flutter 3.47.5 es ≥ 33 (hace falta para compilar la llamada de A) | **[Suposición]** Se ve al compilar en T-011-02; la llamada va protegida por `Build.VERSION.SDK_INT` |

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Ninguno |
| Datos | — | Ninguno (sin esquema, sin archivos, sin ajustes) |
| Estado | — | Ninguno |
| Presentación | — | Ninguna: la interfaz no cambia |
| Nativo | `android/app/src/main/kotlin/invalid/pending/app/RecentsPrivacy.kt` (nuevo) y `MainActivity.kt` | `RecentsPrivacy(activity)`: `onCreate()` aplica A si `SDK_INT >= 33`; `onPause()` pone B si `SDK_INT < 33` (o en todas, si se decide en T-011-01); `onResume()` la quita. `MainActivity` la llama junto a `rotation?.pause()` y `rotation?.resume()`, que ya están. Sin registrar canales |
| Manifiesto | — | Ninguno: sin permisos nuevos |
| l10n | — | Ninguna (spec §7) |
| Herramientas | `tools/check-recents.sh` (nuevo) | Verificación con `adb`: captura de "Recientes" con dos tareas distintas (A y B) y comparación; presencia o ausencia de `SECURE` en `dumpsys window` con la app delante y detrás; bucle de 10 vueltas (CA-011-08); `screenrecord` para el parpadeo |
| Docs | `docs/security/threat-model.md` T-2, `docs/security/checklist.md`, `docs/architecture.md`, `docs/perf/baseline.md`, `docs/adr/0019-*.md`, CL de 007/008/009, `PLAN.md`, `CLAUDE.md` | Ver tareas T-011-06 y T-011-08 |

## 3. Modelo de datos y migraciones

**Sin cambios.** No hay `schemaVersion` nueva, ni captura, ni test de migración (CA-011-06).

## 4. Dependencias nuevas

**Ninguna.** Ni de Dart ni de Gradle. Se descarta JUnit para probar Kotlin (§1 y R-3). `threat-model.md §5` no se activa.

## 5. Estrategia de tests

Ningún test unitario nuevo de Dart: no hay Dart. Los que ya existen y cubren partes de la spec se ejecutan como red de seguridad. Lo nuevo es la verificación en el emulador (API 37 ahora; API 26 y 32 en PD-10).

| Criterio | Tipo | Dónde | Cuándo |
|---|---|---|---|
| CA-011-01, CA-011-02 (matriz) | Prueba en emulador: dos tareas A y B; captura de "Recientes" de cada fila de la matriz; las capturas A y B deben ser idénticas y sin rastro del contenido; comprobación visual de la captura de partida | `tools/check-recents.sh` + `dispositivo.md` (matriz, con la web en fila propia) | API 37 ahora; API 26 y 32 aplazadas (PD-10) |
| CA-011-03 (vuelta y parpadeo) | `screenrecord` de 10 vueltas; revisión de fotogramas. El reloj de 9:59 y 10:00 ya lo prueba CA-001-12 en `test/app/home_router_test.dart`: se comprueba que cubre los dos instantes y, si no, se añade un test ahí | `dispositivo.md` + `home_router_test.dart` | API 37 ahora |
| CA-011-04 (capturas) | Con la app delante, `dumpsys window` sin `SECURE`; y una captura y una grabación reales (`screencap`, `screenrecord`) que salen con contenido, también tras volver de segundo plano, de la cámara y del selector | `tools/check-recents.sh` | API 37 ahora |
| CA-011-05 (arranque) | `tools/measure-cold-start.sh <serial> 20`, dos pasadas de la línea base y dos de la versión nueva, alternadas, la misma máquina y la misma compilación *release* | `docs/perf/baseline.md` | API 37 ahora (el emulador solo compara) |
| CA-011-06 (sin datos ni permisos) | `tools/check-android-permissions.sh release`; `git diff` sin cambios en `pubspec.lock`, `drift_schemas/` ni `schemaVersion`; sin archivos nuevos tras el arranque (`adb shell run-as` listando `files/` antes y después) | T-011-05 | Ahora |
| CA-011-07 (otras plataformas) | `fvm flutter test` completo, `fvm flutter build web`; nada de Dart cambia | T-011-05 | Ahora |
| CA-011-08 (ciclo completo) | Bucle de 10 vueltas con el script, también con cámara y selector | `tools/check-recents.sh` | API 37 ahora |
| CL-011-1 a 13 | Los que se pueden hacer en el emulador se hacen a mano y se anotan; CL-011-5 (8–9 frente a 10+) y CL-011-4 en 8–12 quedan en PD-10; CL-011-9 (HyperOS), solo con permiso del propietario | `dispositivo.md` | Según el caso |

**Nota sobre P9:** el "test" de esta spec es la verificación con `adb` sobre el emulador, no un test de CI. Es coherente con el efecto que se mide (lo que dibuja el sistema fuera de la app), que no se ve desde `flutter test`. **[Suposición]** Se acepta para esta spec; si prefieres un test automático de CI, habría que añadir JUnit y Robolectric (dependencias de prueba) y solo comprobarían las llamadas, no el efecto en "Recientes".

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (checklist):** sin secretos, sin logs de contenido, sin red, sin permisos, sin componentes exportados, sin esquemas nuevos: todo N/A salvo T-2 (que cierra). `security-reviewer` revisa el diff (una clase pequeña) y el ADR-0019.
- **Accesibilidad:** sin interfaz nueva. Se comprueba una vez en el emulador que TalkBack lee la tarjeta de "Recientes" solo con el nombre de la app y que la lupa del sistema y las capturas siguen funcionando con la app delante (spec §6). Se anota para la auditoría de F5.
- **Rendimiento (P2):** una llamada en `onCreate` (mecanismo A) o ninguna (B) y un `addFlags` o `clearFlags` en `onPause` y `onResume`; sin trabajo antes del primer fotograma. Se mide con CA-011-05. El coste real que podría aparecer es un parpadeo al volver (CA-011-03), no en el arranque.
- **Reducir movimiento y texto grande:** no aplican.

## 7. Riesgos y alternativas

| ID | Riesgo | Mitigación / decisión |
|---|---|---|
| R-1 | En Android 8–12 la miniatura se hace **antes** de `onPause` y B no oculta nada, o el cambio de la marca hace parpadear | **Aplazado (PD-10).** Regla de desempate de la spec: se acepta la miniatura visible en Android 8–12 durante la beta y se revisa antes de la v1.0. El código de B se escribe y se prueba en API 37 (mismo mecanismo, distinto momento), pero **no se da por verificado en 8–12** |
| R-2 | En Android 13+, A deja ver la pantalla de arranque del sistema al volver desde "Recientes" (parpadeo) | T-011-03 lo mide. Si ocurre, **se para y se pregunta** (regla de desempate de la spec). Alternativa preparada: B también en 13+ |
| R-3 | Sin tests automáticos de CI, una actualización futura de Flutter o de Android podría quitar el efecto sin que salte nada | La lista de publicación (`/release-checklist`) incluye la comprobación de `tools/check-recents.sh` antes de cada versión entregada a testers (CL-011-13). Se apunta en T-011-06 |
| R-4 | `FLAG_SECURE` también afecta a la WebView y a la lupa del sistema | En B solo está puesta con la app en segundo plano. Se comprueba la fila "web" de la matriz y la lupa en T-011-03 |
| R-5 | HyperOS (Xiaomi) trata la señal a su manera o su lanzador ignora ambos mecanismos | Solo con permiso del propietario (T-011-07); si falla, se para y se pregunta |
| R-6 | Un diálogo o selector del sistema encima de la app la oculta con B (CL-011-4, CL-011-5) | En API 37 se mide (selector parcial de fotos, bandeja de notificaciones). En 8–12, PD-10 |
| Alt. 1 | `FLAG_SECURE` fija en todas las versiones | Descartada por el propietario (bloquea capturas, CA-011-04) |
| Alt. 2 | Pantalla de bloqueo propia (tapar el contenido con Flutter al pasar a segundo plano) | Descartada: llega tarde, la miniatura se hace antes y añade estado a la interfaz |
| Alt. 3 | `excludeFromRecents` | Descartada: quita la tarjeta entera y cambia cómo se vuelve a la app (P2, CA-001-12) |

## 8. Decisiones del propietario (2026-09-30)

1. **Sin test automático de CI** para esta spec: la verificación es con `adb` en el emulador (§5, P9). **Aceptado.**
2. **ADR-0019** corto en T-011-06. **Aceptado.**
3. La verificación en Android 8–12 sigue aplazada (PD-10).
