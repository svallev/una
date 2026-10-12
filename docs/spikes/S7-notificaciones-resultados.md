# S7 · Notificaciones locales (spec 019): resultados

- **Fecha:** 2026-10-11 · **Estado:** ✅ **terminado** (emulador y Xiaomi). Aprobado por el propietario el 2026-10-04 y **ampliado el 2026-10-11** (idioma con TalkBack, pantalla de bloqueo, leer la tarea con la app cerrada, entrega tras actualizar y cambiar de huso, reinicio antes del primer desbloqueo; `docs/PLAN.md`, S7). Q-019-1: «lo hacemos ahora».
- **Código desechable:** `spikes/s7_notifications/` (carpeta **ignorada por git**; Kotlin nativo sin Flutter, paquete `spike.s7`, sin dependencias). Se controla con `adb`: `am start -S -n spike.s7/.MainActivity --es cmd seed|schedule|perm|status|cancel` (`--es at "HH:mm,HH:mm" --es mode window|idle|inexact --el windowMs N --es lang es|en --es text Sin_espacios`). Registro: `adb logcat -d -s S7:I`. Compilar: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ANDROID_HOME=~/Library/Android/sdk ./gradlew :app:assembleDebug`.
- **Dispositivos:** emulador `Pixel_6a` (Android 17, API 37, `emulator-5554`) y **Xiaomi 15T Pro** (HyperOS 3, Android 16, `6DRO9TE6WG59CM8T`). **En el Xiaomi: solo con aviso previo y sin capturas de pantalla** (memoria del proyecto). La app del spike se instaló allí tras aceptar el aviso de «Instalar vía USB» de HyperOS.
- **Trampas de las pruebas:** en `adb shell`, los argumentos con espacios o paréntesis se rompen (usa `_`); `am start` sin `-S` sobre una actividad ya abierta no siempre entrega el intent; `am start -S` (parar y arrancar) hace que el sistema vuelva a enviar `BOOT_COMPLETED` a la app (artefacto de la prueba); `am kill` no mata un proceso en uso: se usó `run-as spike.s7 kill <pid>`.

## Resultados (hechos medidos)

| # | Pregunta | Dónde | Resultado |
|---|---|---|---|
| 1 | Entrega de alarmas **inexactas con ventana** (`setWindow`, 10 min), pantalla encendida | Emulador | Dispararon 233 s y 173 s tras su hora (juntas: el sistema las agrupa) |
| 2 | Entrega con **Doze profundo forzado** (`setAndAllowWhileIdle`) | Emulador | 77 s y 17 s de retraso |
| 3 | Entrega con el **proceso muerto** (sin forzar parada) y lectura de la tarea de la BD | Emulador y **Xiaomi** | Entrega y lectura correctas. Xiaomi, ventana de 5 min, retrasos de **136 s y 16 s** |
| 4 | **Cambio de huso horario** | Emulador | `TIMEZONE_CHANGED` llega a la app, que reprograma a las **mismas horas locales** (Madrid → Tokio → Madrid) |
| 5 | **Actualizar la app** | Emulador | `MY_PACKAGE_REPLACED` llega y se reprograma |
| 6 | **Reinicio con PIN, antes del primer desbloqueo** | Emulador | `LOCKED_BOOT_COMPLETED` llega y la app **reprograma** (la configuración vive en almacenamiento «device protected»). La alarma **dispara con el móvil bloqueado** y puede notificar, pero **la BD no se puede abrir** (`SQLiteCantOpenDatabase`) hasta el primer desbloqueo; `BOOT_COMPLETED` llega después, ya con la BD legible. **Las alarmas no sobreviven a un reinicio**: las horas que pasan mientras el móvil está apagado no se recuperan solas; hace falta guardar «última hora notificada» para decidir qué se perdió (CA-019-14) |
| 7 | **Estados del permiso** (Android 13+) | Emulador | 1.er rechazo: `rationale=true` (puede volver a preguntar). 2.º intento: aparece el diálogo otra vez; tras rechazarlo, `rationale=false` y **no hay más diálogos** (respuesta inmediata de rechazo). «Nunca preguntado» y «rechazado sin poder preguntar» dan ambos `rationale=false`: se distinguen **pidiendo y viendo si aparece el diálogo** o recordando que ya se pidió. Con el permiso rechazado, `areNotificationsEnabled=false`; el canal sigue con importancia 3 |
| 8 | **Pantalla de bloqueo con PIN y la preferencia del sistema por defecto** (`lock_screen_allow_private_notifications=1`) | Emulador (captura) | **Se ve el texto completo de la tarea.** Solo con la preferencia de «contenido sensible» en 0 se ve la versión pública «Tienes una tarea pendiente.». **Esto desmiente la lectura de D25/CA-019-17 («con el móvil bloqueado, genérica por defecto»)** |
| 9 | **Sin bloqueo seguro** | Emulador | El teléfono no se considera bloqueado (`isKeyguardShowing=false`): se ve todo en la bandeja |
| 10 | **Pantalla de bloqueo del Xiaomi con PIN y la preferencia de HyperOS por defecto** (`lock_screen_allow_private_notifications=1`), app cerrada deslizándola en Recientes | Xiaomi | **Se ve el texto completo de la tarea** («Llamar a Marta secreto») y **la pantalla se enciende sola**; sonó el canal de importancia por defecto. Mismo resultado que en el emulador (hecho 8). La primera vez (22:37) el propietario las vio tarde, al desbloquear: no cuenta; se repitió a las 23:08 con la pantalla bloqueada |
| 11 | **Ventana de entrega en el Xiaomi** (app cerrada, `setWindow`) | Xiaomi | Se pidieron ventanas de 5 min y de 1 min: el sistema fija una **ventana mínima de 10 min** (`dumpsys alarm`: `window=+10m`). Retrasos medidos: 136 s y 16 s (pantalla en uso), 300 s y 180 s (bloqueado, 22:37), 126 s y 66 s (23:08), **42 s y ~100 s** (09:31, cargando), **600 s y 540 s con el móvil recién reiniciado y bloqueado**. Con el móvil bloqueado e inactivo suelen llegar **al final de la ventana**: W = 10 min + margen (15 min) se cumple en todas las medidas |
| 12 | **Inicio automático de HyperOS** (`MIUIOP(10008)`) | Xiaomi | La app instalada por USB lo tiene en **`ignore` (denegado) por defecto** y el usuario no puede cambiarlo en Ajustes (solo sale «notificaciones»). Aun así: las alarmas se entregan con el proceso muerto, `LOCKED_BOOT_COMPLETED` llega al reiniciar y `BOOT_COMPLETED` llega al desbloquear. HyperOS lo registra como `rejectTime` al arrancar, pero no impidió nada |
| 13 | **Ahorro de batería «Restringir»** (`RUN_ANY_IN_BACKGROUND` y `RUN_IN_BACKGROUND` en `deny`, cubo de espera 40) | Xiaomi | **Las alarmas no se entregan**: pasados más de 10 min de la ventana seguían en la cola. Al levantar la restricción (`allow`) llegaron en 8 s (23:38:09, retraso 789 s). Es A/B limpio. Lo decide el sistema y la app no puede evitarlo ni detectarlo con seguridad: va a la ayuda web |
| 14 | **Voz de TalkBack con `LocaleSpan`** (sistema en español, texto y título en inglés marcados `en`) | Xiaomi | **Inglés bien pronunciado, voz inglesa**, título y texto. La marca de idioma funciona |
| 15 | **Reinicio con PIN, antes del primer desbloqueo** (`adb reboot`, propietario) | Xiaomi | `LOCKED_BOOT_COMPLETED` llegó con el usuario `RUNNING_LOCKED` (09:36:12) y la app **reprogramó** desde su almacenamiento «device protected». Las dos alarmas **dispararon con el móvil bloqueado (10:02:00, final de la ventana)** y la notificación se publicó (una sola: la segunda sustituyó a la primera) y el propietario la vio sobre las 10:10 en la pantalla de bloqueo, aún sin desbloquear (no sabe a qué hora llegó; la hora real la da el registro), pero **la BD no se pudo abrir** (`SQLITE_CANTOPEN`): salió el texto de error de la prueba. `BOOT_COMPLETED` llegó al primer desbloqueo (10:11:46), ya con la BD legible. Igual que en el emulador (hecho 6) |
| 16 | **Importancia del proceso en el receptor** | Xiaomi | Con la app cerrada llegó como 300 (servicio) o 100 (en uso, 22:37 y 09:31); no es un indicador fiable de «app a la vista». CA-019-19a debe apoyarse en el estado del ciclo de vida que la app guarde, no en `importance` |

## Pendiente
**No probado, queda para la 022:** actualizar la app y cambiar el huso en el Xiaomi (solo en el emulador); notificaciones o canal apagados en la UI de ajustes; «Android 8 y 12L»; con el ahorro de batería del sistema activo (`low_power`) en el emulador. **Limpieza (hecha):** `spike.s7` desinstalada del Xiaomi y del emulador (ver abajo).

## Consecuencias para la spec 019
1. **CA-019-17 / HU-019-4:** con PIN y la preferencia por defecto la pantalla de bloqueo **enseña el texto completo** (emulador y HyperOS). La versión genérica solo sale si el usuario oculta el contenido sensible en el sistema. La app pide la genérica (`VISIBILITY_PRIVATE` + versión pública) pero no puede garantizar nada; la línea de privacidad (Q-019-6) debe decirlo con claridad.
2. **CA-019-11:** el sistema impone ventana ≥ 10 min; W = 15 min.
3. **CA-019-13 y 14:** las alarmas no sobreviven a un reinicio; `LOCKED_BOOT_COMPLETED` y `BOOT_COMPLETED` reprograman; hay que guardar «última hora notificada» (en almacenamiento «device protected», sin texto) para decidir qué se perdió.
4. **CL-019-24:** antes del primer desbloqueo la BD no se puede leer: la notificación debe salir con una **versión genérica de respaldo** («Tienes una tarea pendiente.»), no con la etiqueta de la tarea.
5. **CA-019-21:** `LocaleSpan` funciona con TalkBack: no hace falta ampliar la excepción de voz ni subir la constitución por la notificación.
6. **CL-019-10 / ayuda web:** el ahorro de batería «Restringir» de HyperOS bloquea las notificaciones del todo; el inicio automático no.
7. **CA-019-19a:** no usar la importancia del proceso; la app guarda su estado a la vista.

## Decisiones del propietario que condicionan los resultados

Q-019-2 (el interruptor refleja lo que permite el sistema), Q-019-3 (tocar la notificación lleva siempre a la tarea actual), Q-019-7 (un grupo de fotos sin texto sale con «Tienes una tarea pendiente.») y Q-019-8 (las notificaciones perdidas se notifican igual salvo que se superpongan con la siguiente): ya están en la spec. **Queda Q-019-6** (línea de privacidad bajo las opciones): el hallazgo 8 la hace más necesaria.

## Medición C-1 del plan de la 019 (2026-10-12, Xiaomi 15T Pro, HyperOS 3)

Pedida por CA-019-11 antes de aprobar el plan. Mismo código desechable (`spikes/s7_notifications/`, ya desinstalado del móvil), con el móvil bloqueado y el propietario sin tocarlo. **Resultado: no cumple W = 15 min.**

| Ronda | Llamada | Condición | Retrasos |
|---|---|---|---|
| 1 (13:55) | `setAndAllowWhileIdle` | Pantalla encendida y cargando | 79 s |
| 1 (14:10–14:55) | ídem | Bloqueado | **Cuatro alarmas desaparecieron de la cola sin entregarse** (causa sin determinar) |
| 2 (15:32–16:20) | ídem | App abierta en Recientes, bloqueado con `adb` | **3149–6029 s**; las cinco juntas al coger el móvil |
| 3 (17:35–18:05) | `setWindow`, 10 min | ídem | **2821–4621 s**; juntas al coger el móvil |
| 4 (19:20–20:05) | `setWindow`, 10 min | **App deslizada fuera de Recientes** (condición de S7), bloqueado con el botón | **599–2399 s** (19:20, 19:35 y 19:50 juntas a las 19:59:59, al encender la pantalla; 20:05 a las 20:19:40, también al encender); un encendido breve a las 19:35 no las liberó |

- El móvil estaba cargando (`mCharging=true`) en todo momento: no era reposo profundo de Android. `dumpsys alarm` no mostraba ninguna política que las retuviera (`device_idle`, `battery_saver`, `power_pending` sin retraso): las retiene la gestión de energía de HyperOS.
- Las ventanas de `setAndAllowWhileIdle` con alarmas lejanas quedan en 1 h (`window=+1h`), por encima de W.
- Las medidas de S7 (≤ 600 s) fueron con ventanas de pocos minutos, a menudo con el móvil cargando y en periodos bloqueados más cortos; **no hay que fiarse de ellas para periodos largos de pantalla apagada**.
- Consecuencia: en este móvil, con la pantalla apagada más de ~30 minutos, una alarma inexacta de la app **se entrega al encender la pantalla**, no a su hora. Decisión del propietario pendiente (plan 019, §0, C-1).
