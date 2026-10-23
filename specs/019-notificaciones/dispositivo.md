# Spec 019: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, arm64, sin GPU, `emulator-5554`, idioma del sistema en inglés)** con la compilación *release* (`flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=UNA_NOTIFICATIONS=true`, 29,1 MB, app real `invalid.pending.app`) sobre la rama `feat/019-notificaciones` (HEAD `82d321e`). **Sin tocar el Xiaomi** (T-019-15 lo hará con el permiso del propietario). Capturas en el directorio temporal de la sesión (no se suben). El reloj del emulador se movió con `adb shell cmd alarm set-time` (con `auto_time` apagado) y se restauró al final.

## T-019-14: emulador (2026-10-13)

### Manifiesto (CA-019-25)

- **[Hecho]** `tools/check-android-permissions.sh release` (desde `app/`, tras compilar): «Permisos y componentes de release correctos (4 permisos revisados)».
- **[Hecho]** Difusiones a un receptor **no exportado** desde `adb shell` (uid 2000): `BOOT_COMPLETED`, `TIME_SET` y `LOCKED_BOOT_COMPLETED` a `WakeReceiver` → `Permission Denial: not allowed to send broadcast … uid=2000` (acciones protegidas del sistema). La acción **propia** `invalid.pending.app.action.NOTIFICATION_ALARM`, enviada con el componente explícito, por paquete o implícita, con el proceso **muerto** (`pidof` vacío antes y después): el proceso **no arranca** y no sale ninguna notificación. El receptor no es alcanzable desde fuera.

### El permiso y los avisos (CA-019-06 a 10 y relacionadas)

Permiso reiniciado con `pm reset-permissions` (`granted=false`).

| Paso | Resultado |
|---|---|
| 1.er toque al interruptor | Diálogo del sistema («Allow Una. to send you notifications?»). **Don't allow** → el interruptor sigue **apagado** y aparece el aviso estático «Notifications are blocked in your system settings.» con el botón «Open notification settings» |
| 2.º toque | **Otro diálogo** (Android permite preguntar una segunda vez). **Don't allow** → `USER_SET\|USER_FIXED`, mismo aviso |
| 3.er toque | **Ya no sale diálogo** (`USER_FIXED`); el aviso se queda; la pantalla de entrada sigue como estaba (`ResumedActivity` = `MainActivity`) |
| «Open notification settings» | Abre `Settings$AppNotificationSettingsActivity` de la app (interruptor «All Una. notifications» apagado) |
| Conceder en el sistema y volver con «atrás» | El aviso **desaparece** al volver y el interruptor de la app **sigue apagado** (no se enciende solo) |
| Encender el interruptor | Se enciende con **1·2·3** (1 marcado), línea «The notification will be at 08:55.»; alarma `*walarm*:invalid.pending.app.action.NOTIFICATION_ALARM` programada (`RTC_WAKEUP`, 14/10 08:55, **ventana +1 h, sin `exactAllowReason`**: inexacta) |

### Entrega real con la app cerrada (CA-019-11, 14, 18)

- **[Hecho]** Proceso muerto (`am kill` tras HOME; `pidof` vacío), reloj a 08:54:00 → la notificación llegó a las **08:55:44** (retraso 44 s; el sistema agrupa la alarma inexacta): título «Current task», texto «Llamar a Marta», `category=reminder`, `flags=AUTO_CANCEL|LOCAL_ONLY`, `vis=PRIVATE` con `publicVersion` (CA-019-17), canal **único** `current_task` (importancia 3, `mShowBadge=false`, `mVibrationEnabled=false`, sin luces ni patrón propios; nombre «Current task» en el idioma del sistema, CA-019-22), `timeout=PT72H`.
- **[Hecho]** Dos horas seguidas (3 al día): la de las 13:55 llega con la app en segundo plano; la de las 18:55 la **sustituye** (`id=1`, una sola notificación; `when` 18:55:44).
- **[Hecho]** Tocar la notificación: **con la app cerrada** → se abre en la tarea actual y la notificación se quita; **con la app en segundo plano y la segunda notificación** (la primera ya sustituida) → abre en la tarea actual; **con el editor abierto en segundo plano** → vuelve a la tarea actual (el editor se descarta, consecuencia aceptada de CA-019-19b).
- **[Hecho]** `nonce` (T-8): con el editor abierto (captura antes y después idéntica salvo el cursor), `am start -a invalid.pending.app.action.OPEN_CURRENT_TASK` **con un nonce inventado**, **sin nonce** y con una **acción desconocida** + nonce no cambian nada: el editor se queda donde estaba.
- **[No repetido aquí]** Que con la app a la vista a la hora del aviso no se notifique (CA-019-19a) lo cubren los tests; en el dispositivo no se aisló. **[Suposición, no comprobada]** la primera prueba de estrés, de ráfagas sin sincronizar (la app pasaba casi todo el tiempo a la vista y la lectura de la notificación era muy breve), no mostró ninguna notificación en cuatro «días»; puede deberse a eso, pero no se separó de la ventana de lectura del propio guion.

### Pantalla de bloqueo (CA-019-17, 30)

| Situación | Resultado |
|---|---|
| PIN, `lock_screen_allow_private_notifications=1` (por defecto) | La pantalla de bloqueo enseña **«Current task» / «Llamar a Marta»** y la pantalla se enciende sola |
| PIN, preferencia a `0` («ocultar contenido sensible»; se lee al instante, sin nueva notificación) | Enseña **«Current task» / «You have a task waiting.»** (sin ninguna parte de la tarea) |
| **Sin bloqueo seguro** (`locksettings clear`) y preferencia a `0` | No hay pantalla de bloqueo (`isKeyguardShowing=false`); la bandeja (clara y oscura) enseña la completa |
| **Reinicio con PIN, antes del primer desbloqueo** (`adb reboot`; `am get-started-user-state 0` = `RUNNING_LOCKED`) | El receptor arrancó el proceso (12:53:14, `LOCKED_BOOT_COMPLETED`) y la alarma estaba **reprogramada** (13:55) sin desbloquear; con el reloj a 13:54 la notificación llegó a las 13:55 **aún bloqueado**, con la **versión genérica de respaldo** («Current task» / «You have a task waiting.», CA-019-30). Tras desbloquear con el PIN la notificación se queda genérica, el usuario sigue `RUNNING_UNLOCKED` y la siguiente alarma (18:55) está programada |

### Reprogramaciones del sistema (CA-019-13)

- **[Hecho]** **Huso:** Madrid (siguiente 14/10 08:55) → Tokio (14/10 08:55 **hora de Tokio**) → Nueva York (13/10 13:55, la siguiente de ese día) → Madrid (14/10 08:55): las mismas horas locales; un cambio de huso o de hora **no recupera** horas (regla 3 de CA-019-14: tras `set-time` a una hora ya pasada no salió nada y se programó la siguiente).
- **[Hecho]** **Actualizar la app** (`adb install -r` del mismo APK): tras 4 s la alarma estaba reprogramada (14/10 08:55).
- **[Hecho]** **Apagar el interruptor** cancela la alarma (0 pendientes; el volcado de `dumpsys alarm` lista las cancelaciones `pi_cancelled`, también las de cada arranque, que cancelan y reprograman al reconciliar); **encenderlo** la reprograma.
- **[Hecho, caso aceptado por la spec]** `am force-stop` (el que hace al final `tools/measure-cold-start.sh`) cancela la alarma: no llega ninguna notificación hasta que la app vuelve a arrancar (lo previsto: «lo que el usuario fuerza a parar» no se recupera).

### Idioma (CA-019-20, 21, 22)

- **[Hecho]** Sistema en inglés y app en **Español** (Ajustes → Idioma): la notificación sale con `android.title=SpannableString (Tarea actual)` (con la marca de idioma) y `android.text=String (Llamar a Marta)` (el texto de la tarea no se marca); el **canal** se queda en el idioma del sistema («Current task»).
- **[Pendiente, 022]** La **voz** de TalkBack con `LocaleSpan` (S7 la comprobó a oído en el Xiaomi); el cambio de **idioma del sistema** (`LOCALE_CHANGED`) y el canal recreado: el emulador no cambia el idioma del sistema con `adb` sin pasar por los ajustes.

### Arranque (CA-019-24, CA-001-09)

`tools/measure-cold-start.sh emulator-5554 20` (am start -W -S; `TotalTime`), compilación *release*, una tarea de texto, alternando:

| Pasada | Notificaciones | mín | **p50** | p90 | máx (ms) |
|---|---|---|---|---|---|
| 1 | encendido (3 al día) | 349 | **369** | 389 | 447 |
| 2 | apagado | 344 | **370** | 420 | 455 |
| 3 | apagado | 343 | **363** | 387 | 402 |
| 4 | encendido | 339 | **372** | 414 | 432 |
| 5 | encendido | 345 | **369** | 382 | 416 |

- **[Hecho]** p50 encendido 369, 372 y 369 (media 370) frente a apagado 370 y 363 (media 366,5): **+3,5 ms**, dentro de la deriva entre pasadas del mismo estado (7 ms). p50 < 1 s con un 37 % del presupuesto (CA-001-09 y CA-019-24).
- **[Hecho]** Arranque **desde la notificación** con el proceso muerto (`ActivityTaskManager: Displayed invalid.pending.app/.MainActivity … +406ms`, `+403ms`, `+408ms`; 3 muestras): ≈ 406 ms, también < 1 s.

### Privacidad en el registro del sistema (CA-019-23)

- **[Hecho]** Tarea con el texto `Llamar a MartaTareaSECRETAzx9`, ciclo completo (editar, HOME, `am kill`, alarma, notificación completa con ese texto, toque): `adb logcat -d` completo (8643 líneas, del `logcat -c` previo al ciclo hasta después del toque) → **0 coincidencias** con `SECRETA` y con `zx9`. (La notificación sí lleva el texto: `dumpsys notification --noredact` lo muestra, pero ese comando lo consulta al sistema, no sale en el registro.)

### Estrés de P-019-12 (dos copias de SQLite en el proceso)

**Método.** Compilación de **depuración** con el indicador (`invalid.pending.app.debug`; mismo código nativo y misma Drift; la *release* no permite `run-as`), base de datos recién creada con una tarea «EstresUno», 1 al día. Script de pruebas (no versionado): para cada «día» se pone el reloj a 08:54:30 con `cmd alarm set-time` (la alarma salta ≈ +22 s después de las 08:55:00), se espera a un segundo objetivo del 08:55:16 al 08:55:25 (barrido de 10 desfases), se lanza una **ráfaga de 5 escrituras** (los interruptores «Pantalla siempre activa» y «Bloquear zoom» de Ajustes, cada uno es un guardado en la base de datos) con **HOME inmediato**, y 12 s después se lee la notificación publicada.

- **[Hecho]** 10 pasadas: **ninguna lectura fallida**: en las 8 en que la ráfaga acabó antes del disparo salió la notificación **completa** («EstresUno») y no la genérica de respaldo; en 2 (días 3 y 5) un fallo del propio guion (lee `%S` y `%M` en instantes distintos y se adelanta al cambio de minuto) lanzó la ráfaga a las 08:55:00, antes de la alarma, y la lectura a los 12 s fue previa al disparo (≈ :22): sin dato válido.
- **[Hecho]** **`PRAGMA integrity_check` = `ok`** (copia de `una.sqlite`, `-wal` y `-shm` sacada con `run-as`; modo `wal`, `user_version` 3, `notificationsOn=true`, `keepScreenOn=false`, `lockZoom=true`, 1 tarea).
- **[Límite]** El caso real (la app a la vista escribe y la alarma salta justo al pasar a segundo plano) tiene una ventana de milisegundos: se ejercitó a ≈ 0-6 s antes del disparo, no dentro de la misma décima de segundo. Con un solo escritor y la lectura de solo lectura (`query_only`) no se observó ninguna corrupción ni lectura inconsistente; no se puede descartar con esta prueba. Sigue la decisión de P-019-12 (b) del propietario.

### Icono pequeño

- **[Hecho]** El icono pequeño (la «u.» de la app, teñida por el sistema) se ve en la barra de estado con el tema claro y, en la cortina, con el tema oscuro (`cmd uimode night yes`); en la pantalla de bloqueo con PIN se ve junto a la tarjeta de la notificación.

### Sin diferencias de comportamiento con la hora real

Al restaurar la hora real del emulador (después de simular hasta el 10/12) la app programó la siguiente alarma (18:55 de ese día) y no recuperó nada: la «última hora» futura se ignora (CA-019-14).

## T-019-15: Xiaomi 15T Pro (HyperOS 3, Android 16) (2026-10-13)

**Método.** Con el permiso del propietario (que estuvo presente), **sin capturas de pantalla** (la interfaz se leyó con `uiautomator dump`, solo texto y límites de nuestra app, comprobando antes con `dumpsys window` que estaba delante). Compilación **profile** con el indicador (`flutter build apk --profile --split-per-abi --target-platform android-arm64 --dart-define=UNA_NOTIFICATIONS=true`, 39,8 MB) como app aparte `invalid.pending.app.profile`, **sin tocar la app real ni el reloj del móvil**. Una tarea de texto «Prueba 019», 3 al día. El móvil estaba **cargando** (`AC powered`). Estado inicial de «Pantalla siempre activa» (`stay_on_while_plugged_in`) restaurado al acabar los arranques (`svc power stayon false` → 0).

### Entrega con el móvil bloqueado e inactivo (CA-019-11, 17)

- **[Hecho]** Muestra 1 (13:49:59 móvil bloqueado y con la pantalla apagada; el proceso seguía en segundo plano, HyperOS no lo mata con `am kill`; alarma de las 13:55 con **ventana hasta ≈ 13:59**, `dumpsys alarm`: `window=+4m4s`): la notificación llegó a las **13:55:21** (**+21 s**). Título «Tarea actual», texto «Prueba 019».
- **[Hecho]** Pantalla de bloqueo con PIN y la preferencia de «contenido sensible» **por defecto** (`lock_screen_allow_private_notifications=1`): el propietario vio **«Tarea actual / Prueba 019»** (la completa), como en S7 (CA-019-17).
- **[Hecho]** Reinicio del móvil (por el propietario, 14:19; al volver se comprobó con la app **sin abrir**, `pidof` vacío y la pantalla de inicio delante): la alarma estaba **reprogramada** a las 18:55 (`RTC_WAKEUP`, ventana +1 h) por el aviso de arranque del sistema, sin haber abierto la app (CA-019-13).
- **[Hecho, parcial]** Muestra de las **18:55** (leída a las 22:20 en `dumpsys alarm` y `dumpsys notification`, solo consulta, sin capturas): la alarma de la app `.profile` (`NOTIFICATION_ALARM`, `RTC_WAKEUP`, ventana +1 h) **saltó a las 19:10:02**, es decir **+15 min** sobre la hora (el sistema la agrupó casi al final de lo que permite su ventana mínima), y la app **dejó ya programada la de las 08:55 del 2026-10-14** (CA-019-12/13). Es la cifra de W = 15 min del objetivo, no un criterio de paso (CA-019-11). **No confirmado:** que el móvil estuviera bloqueado con la app cerrada en ese momento, qué vio el propietario con la preferencia en «oculto» y el arranque tocando la notificación; pasa a la 022.
- **[Hecho, 2026-10-13 ~22:30]** Móvil restaurado: `lock_screen_allow_private_notifications` vuelve a **1** (comprobado) y `invalid.pending.app.profile` está **desinstalada** (la app base `invalid.pending.app` sigue instalada). La primera orden la bloqueó el clasificador de permisos de Claude Code y el propietario la autorizó de nuevo.

### Arranque en frío (CA-019-24, CA-001-09)

`am start -W -S` (copia de `tools/measure-cold-start.sh` con el nombre completo de la actividad para la app `.profile`), 20 arranques por pasada, alternando el ajuste (comprobado cada vez con `uiautomator`):

| Orden | Notificaciones | mín | **p50** | p90 | máx (ms) |
|---|---|---|---|---|---|
| 1 | encendido | 356 | **374** | 388 | 409 |
| 2 | apagado | 344 | **362** | 387 | 394 |
| 3 | apagado | 352 | **363** | 377 | 391 |
| 4 | encendido | 319 | **369** | 373 | 379 |
| 5 | encendido | 355 | **370** | 388 | 396 |
| 6 | apagado | 343 | **366** | 382 | 385 |
| 7 | apagado | 347 | **366** | 381 | 386 |
| 8 | encendido | 359 | **391** | 408 | 411 |
| 9 | encendido | 362 | **390** | 409 | 428 |
| 10 | apagado | 366 | **388** | 401 | 405 |
| 11 | apagado | 358 | **383** | 397 | 406 |

- **[Hecho]** p50 < 1 s en todas (CA-001-09; ≈ 38 % del presupuesto). Medias: encendido **378,8** (374, 369, 370, 391, 390) y apagado **371,3** (362, 363, 366, 366, 388, 383): **+7,5 ms (+2 %)**.
- **[Hecho]** La diferencia está **dentro de la deriva del propio móvil**: hubo una deriva monótona de ≈ +25 ms a lo largo de la hora (el móvil, cargando y recién reiniciado con carga alta, `load average` ≈ 19-20 y 36,9 °C), y las pasadas **apagadas** de al final (388, 383) son tan lentas como las **encendidas** del medio (391, 390). Comparando pares adyacentes la diferencia es +11, +6,5, +4, +24,5 y +4,5 ms: sin un patrón que dependa del ajuste. Criterio de CA-019-24 cumplido con ese margen (no es una prueba estadística; un solo móvil).
- **[Nota]** Los tres primeros arranques justo tras el reinicio medían 473-799 ms (el móvil aún arrancando procesos); no cuentan.

## Pendiente de esta tarea (T-019-14)

- **[Pendiente]** voz de TalkBack con `LocaleSpan` y cambio del **idioma del sistema** con el canal recreado (no hay forma fiable con `adb` en el emulador; S7 ya comprobó la voz en el Xiaomi). Va a la 022.
- **[Pendiente]** App **a la vista** a la hora del aviso (CA-019-19a) en el dispositivo; lo cubren los tests.

## Auditoría 022 (spec 022, T-022-02, 2026-10-16)

Resultados de la auditoría en dispositivo que **no** necesitan el emulador ni el Xiaomi en esta tarea (casillas cerradas por decisión del propietario, ya cumplidas por la CI o por lo que el propietario vio el 2026-10-15, y aceptadas con el resultado del emulador). El resto de casillas de esta spec se anotan aquí, con el mismo formato, en las tareas T-022-03 a 13. Inventario: `specs/022-auditoria-en-dispositivo/informe.md`.

- **PD-10: canal único y ausencia del diálogo del permiso en Android 8 y 12L (en 12L solo «bloqueadas» si se apagaron en el sistema)** (K-022-013) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.»
- **PD-10: `java.time`, SQLite 3.18 con la consulta de solo lectura e ICU para partir las letras (CA-019-16)** (K-022-014) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.». Lo que cubren las pruebas JVM y los tests de Dart sigue en verde en la CI (`CI 38761348413`)
- **PD-10: la notificación completa y la genérica en Android 8 y 12L** (K-022-015) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.»
- **CA-019-21: `LocaleSpan` con TalkBack de Android 8–12 (voz de la notificación)** (K-022-016) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.»; propietario, alcance 2 de la 022 (CA-022-07): otros fabricantes, lanzadores, lectores y versiones de Android se cierran sin hacerlas; si un tester de la beta informa de un fallo, es un hallazgo nuevo
- **(d) del cierre: color de acento amarillo de la notificación en la bandeja clara de Android 8–11** (K-022-017) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.». **[Suposición]** de la 022: «el (d) de su cierre» (CA-022-06) es el color de acento; `docs/PLAN.md` tiene otro «(d)» (`Poster`/`MainActivity` sin prueba JVM, hallazgo bajo) que sigue siendo un hallazgo de código de la spec 024 (§8 de la spec 022). Por confirmar con el propietario (informe §6)
- **CA-019-21: `LocaleSpan` con Samsung Voice Assistant** (K-022-022) — **Cerrada sin verificar** · 2026-10-16 · Otro lector (no se prueba) · propietario, alcance 2 de la 022 (CA-022-07): otros fabricantes, lanzadores, lectores y versiones de Android se cierran sin hacerlas; si un tester de la beta informa de un fallo, es un hallazgo nuevo
- ***Goldens* de la 019: `settings_notifications_*` (16 PNG)** (K-022-029) — **Pasa** · 2026-10-16 · CI (Linux) · CI de `main` sobre `2e835cf`, ejecución 38761348413 (2026-10-15, `success`; `gh run view 38761348413`): el paso «Tests (unitarios, widgets, goldens, migraciones, l10n, tokens)» del trabajo «Flutter · format, analyze, test, web» corrió entero (15:35:45 a 15:45:10, `success`; el paso «Diferencias de los goldens (si fallan)» salió `skipped`). Los 16 PNG `settings_notifications_{off,one,two,three,blocked,error}_{es,en}_x1.0` (y `three` y `blocked` también `x2.0`) están en `app/test/goldens/goldens/` (subidos en la PR #50)
- **Teclado físico en el bloque de notificaciones: flechas que solo mueven el foco, opción enfocada a la vista (019)** (K-022-138) — **Aceptada** · 2026-10-16 · Tests de widgets (sin prueba con teclado real en el emulador); sin probar en el Xiaomi · propietario, Q-022-3 (2026-10-16): «No lo voy a probar con otra cosa. Se queda con lo que ya se probó». **Límite:** esta casilla no tiene prueba propia en el emulador (T-019-14 no probó el teclado); la cubren los tests de widgets de `app/test/features/settings/notifications_a11y_test.dart` (Tab recorre el interruptor y las tres opciones, las flechas solo mueven el foco, la opción 3 enfocada al 200 % a 360 dp queda a la vista) y el teclado real de Ajustes del emulador (K-022-137)

**T-022-05 (2026-10-16): corte del texto, 11 minutos en segundo plano y pantalla apagada** (CA-022-14 y 16).

- **(f) Texto de más de 120 letras con emoji ZWJ y acentos: la notificación corta entre letras completas (CA-019-16)** (K-022-053) — **Pasa** · 2026-10-16 · Emulador `Pixel_6a_api37_root` (API 37), `emulator-5554`, *release* arm64 de `2e835cf` (T-022-05) · tarea de 199 unidades: 115 letras con acentos y, en los grafemas 116 a 120, «👩‍👩‍👧‍👦», «é» (e + U+0301), «🏳️‍🌈», «ñ» (n + U+0303) y «👨‍👩‍👧», más texto detrás. Reloj movido a 08:54:05 (`cmd alarm set-time`, `auto_time 0`) con la app en segundo plano: notificación a las 08:55:41. `dumpsys notification --noredact` (`android.text` y `android.bigText`): los 120 primeros grafemas + «…» (136 unidades UTF-16), **idéntico** al esperado calculado aparte con la misma regla; la bandeja a ojo enseña los tres emoji enteros, «é», «ñ» y «…»; la versión pública dice «You have a task waiting.»
- **(g) CA-019-20: tocar la notificación con la app 11 minutos en segundo plano lleva a la tarea actual** (K-022-054) — **Pasa** · 2026-10-16 · Emulador `Pixel_6a_api37_root` (API 37), *release* de `2e835cf` (T-022-05) · app en el editor con el borrador «Borrador sin guardar», HOME a las 08:54:09 (reloj del dispositivo), notificación a las 08:55:41, toque a las 09:05:35 (**11 min 26 s**): se abre la **tarea actual** («Photo 1 of 3», con su texto largo), sin editor ni borrador (consecuencia aceptada de CA-019-20) y sin notificaciones de la app en el sistema (CA-019-19b)
- **(g) CA-019-19a: la notificación con la pantalla apagada** (K-022-055) — **Pasa** · 2026-10-16 · Emulador `Pixel_6a_api37_root` (API 37), *release* de `2e835cf` (T-022-05) · con la tarea delante, `KEYCODE_SLEEP` (`mWakefulness=Asleep`) y reloj a 13:54:05: la notificación se publicó a las **13:55:41 con la pantalla apagada** (el emulador no tiene bloqueo seguro y la pantalla no se encendió sola); al encender (`KEYCODE_WAKEUP`) la app vuelve al frente y la quita (CA-019-19b). **Control:** con la app a la vista y la pantalla encendida (reloj a 08:54:10 del día siguiente y app traída al frente), la alarma de las 08:55 saltó y **no** se publicó nada (CA-019-19a, primera mitad); un primer intento con un salto de reloj de 5 h sin renovar la app **sí** notificó con ella delante (el indicador «a la vista» se renueva cada 5 min y se ignora pasados 12 min: artefacto de la prueba, no un fallo)

**T-022-06 (2026-10-16): idiomas `ca`, `gl` y `eu`, voz de los anuncios y navegador desactivado** (CA-022-15, 16a y 16b).

- **La notificación en `ca`, `gl` y `eu` (título y canal, CA-019-21 y 22)** (K-022-059) — **Pasa** (`ca` y `gl`; `eu` **no se audita**, propietario, 2026-10-16) · 2026-10-16 · Emu `2e835cf` (T-022-06): con `ca`, la notificación de las 08:55 (reloj movido con `cmd alarm set-time`) sale con título «Tarea actual» y texto «Prueba 022», y el canal `current_task` se llama «Tarea actual»; con `gl`, título «Current task» y canal «Current task» (el canal se renombró al abrir la app con el idioma nuevo, CA-019-22). Leído con `dumpsys notification --noredact` y en la bandeja (capturas). Reloj y `auto_time` restaurados

**T-022-07 (2026-10-18): Xiaomi X1, TalkBack en español** (CA-022-17).

- **Interruptor de notificaciones como un solo nodo (CA-019-04)** (K-022-085) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · el interruptor de notificaciones es un solo nodo; el propietario: «Todas las pruebas ok»
- **Acordeón: se despliega sin anuncio y hay uno solo al cambiar de opción (CA-019-07 y 08)** (K-022-086) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · el acordeón se despliega sin anuncio y hay uno solo al cambiar de opción; el propietario: «Todas las pruebas ok»
- **«Notificaciones al día» sin parada de foco propia (CA-019-26); si la tiene, es un hallazgo** (K-022-087) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · «Notificaciones al día» no es una parada de foco; el propietario: «Todas las pruebas ok»
- **La línea de privacidad como parada tras la fila (CA-019-09)** (K-022-088) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · la línea de privacidad es una parada tras la fila; el propietario: «Todas las pruebas ok»
- **Dónde cae el foco tras el diálogo del permiso y «Notificaciones activadas.»** (K-022-089) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · tras el permiso concedido el foco vuelve al interruptor y se dice «Notificaciones activadas.»; el propietario: «Todas las pruebas ok»
- **Aviso de bloqueo y su botón (permiso rechazado de verdad) y «Notificaciones permitidas.» al volver del sistema** (K-022-090) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · permiso rechazado de verdad: aparece el aviso de bloqueo con su botón, que lleva a la pantalla del sistema; al permitirlo y volver se dice «Notificaciones permitidas.»; el propietario: «Todas las pruebas ok»
- **Aviso de error del bloque de notificaciones (si se puede provocar sin tocar nada del propietario; si no, CL-022-2)** (K-022-091) — **Aceptada** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · CL-022-2: el aviso de error del bloque no se puede provocar en el móvil sin tocar nada del propietario
- **Móvil bloqueado y contenido sensible **oculto**: cuando la pantalla se enciende sola, TalkBack no lee ninguna parte de la tarea (CA-019-17; si la lee, **alto**)** (K-022-099) — **Pasa** · 2026-10-18 · Xiaomi · **Evidencia:** no se anotó en la sesión lo que dijo TalkBack y el propietario no la aportó al cierre (2026-10-19); el resultado es el «Pasa» dado en X1.
- **Móvil bloqueado con la preferencia por defecto: lo decide el sistema; se anota qué lee** (K-022-100) — **Aceptada** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español (T-022-07, X1) · Aceptada con lo que diga el sistema: no se pudo provocar en X1; en X7 (K-022-166) con la preferencia por defecto el sistema enseña la completa («Tarea actual» / «example.com»)

**T-022-08 (2026-10-18): Xiaomi X2, texto al 200 %, tres botones y reducir movimiento** (CA-022-18, 23 y 24; detalle en el [informe](../022-auditoria-en-dispositivo/informe.md), §12).

- **N-1 (a): el aviso de bloqueo se oye con TalkBack al 200 % aunque el bloque quede bajo el pliegue (permiso rechazado de forma permanente)** (K-022-101) — **Falla** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf` (T-022-08, X2), TalkBack en español, `font_scale` 2,0, tres botones (≈ 394 dp), permiso rechazado de forma permanente · el aviso se ve entero pero TalkBack **no lo anuncia** al activar el interruptor (2 intentos); con el foco en él, sí lo lee; con `font_scale` 1,0 sí se anuncia · propietario: «No oigo el aviso, lo veo en pantalla» · **H-022-02** (media, destino la 024). La causa no está establecida **[Suposición]** · **Cerrado como Aceptado por el propietario** (spec 024, CA-024-06, 2026-10-21, respuesta 3b): sin cambio en la app
- **El bloque de notificaciones desplegado con la opción 3, la línea de privacidad y el aviso, en ES y EN, al 200 % con tres botones** (K-022-132) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf` (T-022-08, X2), permiso concedido · opción 3 marcada, ayuda con las horas y línea de privacidad sin cortes ni bajo la barra, en ES y EN (propietario: «Todo ok»; en inglés la ayuda termina en y 2567 y la barra empieza en 2619); el aviso de bloqueo, entero en ES y EN. La primera pasada, con el permiso rechazado, no contó (sin permiso no hay opciones, CA-019-09)
- **Reducir movimiento: el acordeón de notificaciones** (K-022-135) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf` (T-022-08, X2), escalas de animación a 0 puestas por `adb` (el valor que deja «Quitar animaciones») · apagar y encender «Notificaciones» y cambiar entre las opciones 1, 2 y 3: todo de golpe, sin transición · propietario: «bien» y «bien». La primera pasada, con el permiso rechazado, no contó (no hay acordeón)

**T-022-09 (2026-10-18): Xiaomi X3, la voz con el idioma de la app** (CA-022-19; detalle en el [informe](../022-auditoria-en-dispositivo/informe.md), §13). Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf`, TalkBack en español, tres rondas (sistema EN + app ES, sistema ES + app EN, EN + EN).

- **La notificación completa con su marca de idioma, en las tres rondas (CA-019-21)** (K-022-107) — **Falla** · sistema EN + app ES: voz inglesa; sistema ES + app EN: voz española; EN + EN: bien. **H-022-03** (media, a la 024): TalkBack no respeta el `LocaleSpan`; contradice la hipótesis de S7. · **Aceptado por el propietario sin excepción de P6** (spec 024, CA-024-05, 2026-10-21)
- **La notificación genérica (desbloqueado y con la pantalla bloqueada y el contenido oculto) (CA-019-21)** (K-022-108) — **Falla** · igual que K-022-107, **H-022-03**. · **Aceptado** igual que K-022-107 (spec 024, CA-024-05)
- **La notificación con la voz del otro idioma sin instalar (CA-019-21)** (K-022-109) — **Aceptada** · propietario: «aceptada»; están instaladas es-ES, es-US, en-US y en-GB y no se desinstala ninguna.
- **Al cambiar el idioma del sistema, el canal toma el nombre nuevo (`LOCALE_CHANGED`, CA-019-21 y 22)** (K-022-110) — **Pasa con límite** · el nombre cambia, pero no se midió cuánto tarda y parece que solo tras reiniciarse el proceso. **Cerrada por el propietario el 2026-10-19 (T-022-14), sin prueba limpia:** el canal acabó con el nombre correcto; la latencia queda anotada como límite.
- **Switch Access: dos opciones seguidas del bloque de notificaciones (K-022-116, CA-022-20)** — **Pasa** · 2026-10-19 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf` (T-022-10, X4) · Switch Access 1.17.0.892789133, vol + «Siguiente» y vol − «Seleccionar», búsqueda lineal; el propietario pulsó las teclas físicas y leyó el resalte
- **Voice Access: «toca 2», «toca notificaciones» y abrir y descartar la notificación por voz (K-022-122 y 124, CA-022-21)** — **Aceptada** · 2026-10-19 · Xiaomi 15T Pro (HyperOS 3), `.profile` de `2e835cf` (T-022-10, X4) · Voice Access no instalado en el Xiaomi; el propietario: «la pasamos a aceptada»
- **CA-019-17: la genérica con el móvil bloqueado, la app cerrada y el contenido sensible en «oculto»** (K-022-166) — **Pasa** · 2026-10-19 · Xiaomi 15T Pro (HyperOS 3, Android 16), `.profile` · «Tarea actual» / «Tienes una tarea pendiente» (nada de la tarea) con el móvil bloqueado, dos veces; desbloqueado, «Tarea actual» / «example.com». Lo leyó el propietario.
- **CA-019-20: tocar la notificación con la app cerrada abre la tarea actual; O-1 de la 020** (K-022-167 y 168) — **Pasa** · 2026-10-19 · Xiaomi · abre «example.com», se pinta bien y la notificación sale de la bandeja (CA-019-19b); O-1 no se reproduce (1 observación).
- **CA-019-19a: la app a la vista a la hora del aviso** (K-022-169) — **Pasa** · 2026-10-19 · Xiaomi · con la `.profile` delante no sale notificación (reloj movido a las 18:56). Límite: con el proceso vivo en segundo plano y saltos de reloj tres entregas no salieron (`power_pending`), no concluyente.
- **Entrega con el ahorro de batería de HyperOS y con la pantalla apagada mucho rato** (K-022-170 y 174) — **Pasa con límite** · 2026-10-19 · Xiaomi · con el ahorro, el aviso sale en < 3 s con el reloj movido; 40 min con la pantalla apagada, sale 2 s después de encender (14:00:14). Con la app sin abrir ~5 h, a las 18:55 reales no llegó en 1 h 10 min (también a la *release* del propietario): ver `informe.md` §17. **Propietario, 2026-10-19 (T-022-14):** «No le daría importancia. Gravedad baja. No hace falta indicarlo en la ayuda»: **H-022-07**, baja, a la spec 024, sin ayuda web; las dos casillas siguen **Pasa con límite**. No confirmado en otras marcas. · H-022-07 (app sin abrir ~5 h) **cerrado como límite del sistema** (spec 024, CA-024-07): una línea en CA-019-11
- **Entrega con «No molestar» y los modos de HyperOS** (K-022-171) — **Aceptada** · 2026-10-19 · propietario: «Con no molestar sé que las notificaciones no serán avisadas. Es justo lo que dice al activar no molestar.»
- **Entrega tras actualizar la app** (K-022-172) — **Pasa con límite** · 2026-10-19 · Xiaomi · `adb install -r`: la alarma se conserva y sale a las 14:00:14; el *receiver* `MY_PACKAGE_REPLACED` no se vio.
- **Entrega tras un cambio de huso** (K-022-173) — **Falla (H-022-06, baja)** · 2026-10-19 · Xiaomi · con el proceso vivo la alarma se mueve a las 13:55 de Londres y vuelve; con el proceso muerto no se mueve (HyperOS rechaza el arranque automático, `appops` 10008) hasta abrir la app. **Propietario, 2026-10-19 (T-022-14):** baja, destino la 024 (una línea), **sin** ayuda web («No hace falta indicarlo en la ayuda»). · **Cerrado como límite del sistema** (spec 024, CA-024-07): una línea en CA-019-13 y CL-019-4
