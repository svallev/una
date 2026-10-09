# Spec 017: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, arm64, sin GPU, `emulator-5554`, idioma del sistema en inglés)**. **No se usó ni se tocó el Xiaomi.** Capturas en el directorio temporal de la sesión (no se suben).

## T-017-09: arranque y memoria (2026-10-09)

**Método.** Compilación *release* (`flutter build apk --release --split-per-abi --target-platform android-arm64`, 29,0 MB) instalada con `adb install -r`; app real `invalid.pending.app`. Las fotos de prueba se generaron con Pillow: 10 JPEG de 4000 × 6000 (24 MP) de ~6,6 MB (degradado con ruido y círculos, con el número grande en el centro); no se versionan y se borraron del emulador al acabar. Primero se creó una tarea con **una foto** y, después, otra con el **grupo de 10** (selector de fotos del sistema, miniaturas y **Done**; el grupo se importó en menos de 10 s). El ajuste se enciende y apaga **con la propia pantalla de Ajustes** (`input tap` a «Bloquear zoom»; antes de cada pasada se lee el estado del interruptor con `uiautomator dump`, `checked`), no con la base de datos. Antes de cada pasada: un arranque de calentamiento y 5 s de espera. **Pasadas alternadas** (apagado, encendido, apagado, encendido…) de `tools/measure-cold-start.sh emulator-5554 20`. Memoria: `adb shell dumpsys meminfo invalid.pending.app` (TOTAL PSS), 5 lecturas en reposo y lectura continua (~1 000-2 900 muestras) mientras un guion da gestos reales con `input swipe`: con una foto, arrastres verticales y diagonales (25 rondas); con el grupo, 9 swipes hacia delante y 9 hacia atrás (13 rondas = 26 pasadas por las 10 fotos).

### Arranque en frío (CA-017-11, CA-001-09, CA-016-08)

| Pasada | Contenido | Bloqueo | mín | **p50** | p90 | máx |
|---|---|---|---|---|---|---|
| 1 | 1 foto de 24 MP | apagado | 408 | **440** | 468 | 484 |
| 2 | 1 foto de 24 MP | encendido | 408 | **430** | 472 | 582 |
| 3 | 1 foto de 24 MP | apagado | 411 | **436** | 499 | 618 |
| 4 | 1 foto de 24 MP | encendido | 412 | **443** | 489 | 618 |
| 5 | grupo de 10 | apagado | 407 | **426** | 465 | 518 |
| 6 | grupo de 10 | encendido | 408 | **441** | 484 | 844 |
| 7 | grupo de 10 | apagado | 413 | **438** | 525 | 762 |
| 8 | grupo de 10 | encendido | 409 | **444** | 503 | 716 |
| 9 | grupo de 10 | apagado | 404 | **432** | 441 | 474 |
| 10 | grupo de 10 | encendido | 408 | **442** | 532 | 828 |

- **[Hecho]** Una foto: p50 apagado 440 y 436 (media 438; deriva entre las dos pasadas **4 ms**); encendido 430 y 443 (media 436,5). Diferencia **−1,5 ms**: no es más lenta (criterio: aumento ≤ la deriva).
- **[Hecho]** Grupo de 10: p50 apagado 426, 438 y 432 (media 432; **deriva entre pasadas hasta 12 ms**); encendido 441, 444 y 442 (media 442,3). Diferencia **+10 ms (+2 %)**, dentro de la deriva del propio apagado (12 ms): el criterio se cumple por poco. Los mínimos son iguales (404-413 ms con el ajuste apagado y 408-412 con él encendido) y con una foto no hay diferencia, así que **no se ve un efecto atribuible a la lectura extra de `readBootState`**; si se quisiera afinar, repetir en el Xiaomi (la reserva del plan §4, consulta única, **no hace falta**).
- **[Hecho]** CA-001-09 y CA-017-11: p50 < 1 s en todas (≈ 43 % del presupuesto en el emulador, que es más lento que el móvil). CA-016-08: grupo de 10 frente a 1 foto, p50 medio 432 frente a 438 (apagado) y 442 frente a 437 (encendido): **≤ +100 ms** con mucho margen.
- Las medias de «una foto» concuerdan con las de la 016 en el mismo emulador (425 ms con una foto, 429 con el grupo).

### Memoria (TOTAL PSS, MB)

| Contenido | Bloqueo | Reposo (mediana de 5) | Recorriendo (mediana) | Pico |
|---|---|---|---|---|
| 1 foto | apagado | 83,3 · 83,5 | 86,0 · 86,3 | 87,7 · 87,6 |
| 1 foto | encendido | 83,3 · 83,7 | 86,1 · 86,3 | 87,9 · 88,3 |
| grupo de 10 | apagado | 78,3 · 79,4 | 80,3 · 80,2 | 104,3 · 100,4 |
| grupo de 10 | encendido | 77,8 · 78,3 | 80,5 · 80,3 | 106,3 · 104,7 |

(Dos pasadas por celda; cada par es una pasada y la siguiente del mismo estado. Hubo una pasada de grupo apagado más, con el interruptor sin comprobar por un fallo del guion y el estado dudoso: reposo 79,5, mediana 80,1 y pico 115,3 MB; se descartó y se repitió con el estado leído.)

- **[Hecho]** Sin diferencia entre encendido y apagado: ≤ 0,4 MB en reposo y en la mediana, dentro de la deriva entre dos pasadas del mismo estado (0,2-1,1 MB; el pico del grupo varía hasta 4 MB entre pasadas apagadas). **[Suposición] de CA-017-11 («el bloqueo no cambia lo que se pinta ni su memoria») → [Hecho]** en el emulador de API 37.
- **[Hecho]** CA-016-23: el pico del grupo es **+13 a +18 MB** sobre el de una foto (100-106 frente a 88 MB; límite +50 MB), con el bloqueo apagado o encendido.
- **[Pendiente]** repetir en el Xiaomi con el permiso del propietario (como en la 016); no hace falta para dar por buena la tarea.

### Lo que no se midió aquí

- «El bloqueo está activo desde el primer fotograma» (CA-017-11): lo prueba el test de widgets de T-017-04. En el emulador, con el grupo, la foto 1 (2:3 a 1080 px de ancho) **cabe justo en la ventana** (no hay nada que desplazar con el ajuste apagado), así que un arrastre justo tras el arranque da la misma imagen con y sin bloqueo: no sirve como prueba. **[Pendiente]** T-017-10a (con una foto más alta, p. ej. 1:2).

### Ajustes del emulador

Cambiados y restaurados: giro automático (`accelerometer_rotation` 1 → 0 durante las pruebas → 1; el emulador arrancó la app en horizontal por el sensor virtual de un giro anterior: `adb emu rotate` lo dejó en vertical), animaciones, escala de fuente (1,0) y densidad (420) sin tocar. El interruptor «Bloquear zoom» queda **apagado**. La app real queda instalada con el grupo de 10 como tarea actual (T-017-10a la usa); las fotos de prueba se borraron del emulador.

## T-017-09: `integration_test/settings_flow_test.dart` (T-017-08b) en el emulador (2026-10-09)

`flutter test integration_test/settings_flow_test.dart -d emulator-5554` (APK de depuración con base de datos vacía): **3 de 3 pruebas pasan** en el emulador de API 37, incluida la nueva «CA-017-03/11: "Bloquear zoom" se enciende, se guarda sin tocar los demás ajustes y sobrevive a un rearranque» (13 s). **[Hecho]**
