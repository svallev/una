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
- **[Hecho el 2026-10-10]** repetido en el Xiaomi con el permiso del propietario (ver «Bloquear zoom en el Xiaomi», más abajo): sin diferencia.

### Lo que no se midió aquí

- «El bloqueo está activo desde el primer fotograma» (CA-017-11): lo prueba el test de widgets de T-017-04. En el emulador, con el grupo, la foto 1 (2:3 a 1080 px de ancho) **cabe justo en la ventana** (no hay nada que desplazar con el ajuste apagado), así que un arrastre justo tras el arranque da la misma imagen con y sin bloqueo: no sirve como prueba. **[Pendiente]** T-017-10a (con una foto más alta, p. ej. 1:2).

### Ajustes del emulador

Cambiados y restaurados: giro automático (`accelerometer_rotation` 1 → 0 durante las pruebas → 1; el emulador arrancó la app en horizontal por el sensor virtual de un giro anterior: `adb emu rotate` lo dejó en vertical), animaciones, escala de fuente (1,0) y densidad (420) sin tocar. El interruptor «Bloquear zoom» queda **apagado**. La app real queda instalada con el grupo de 10 como tarea actual (T-017-10a la usa); las fotos de prueba se borraron del emulador.

## T-017-09: `integration_test/settings_flow_test.dart` (T-017-08b) en el emulador (2026-10-09)

`flutter test integration_test/settings_flow_test.dart -d emulator-5554` (APK de depuración con base de datos vacía): **3 de 3 pruebas pasan** en el emulador de API 37, incluida la nueva «CA-017-03/11: "Bloquear zoom" se enciende, se guarda sin tocar los demás ajustes y sobrevive a un rearranque» (13 s). **[Hecho]**

## T-017-10a: gestos reales, orientación, tres botones y «Recientes» (2026-10-09)

**Método.** La misma compilación *release* de T-017-09 (sin cambios de código desde entonces) y el mismo emulador, **sin tocar el Xiaomi**. Fotos de prueba generadas con Pillow (no se versionan y se borraron del emulador al acabar): `tallD` y `tallE` de **1000 × 2500 (1:2,5)**, y `shortB` de 1500 × 2000 (3:4), con una regla cada 5 % de su alto y un nombre grande en el centro. Con ellas, una tarea **nueva de 3 fotos** (D, B, E; «Subir imágenes» con el selector del sistema), que queda como tarea actual. **[Desviación del encargo]** Se usó 1:2,5 y no 1:2: en el emulador (1080 × 2400) el área de la foto es la pantalla entera (2400 px) y una foto 1:2 mide 2160 px a todo el ancho, así que **cabe** (probado: una 1:2 sale con franjas arriba y abajo y no hay nada que desplazar); la 1:2,5 mide 2700 px y se puede desplazar 300 px. Sigue siendo una proporción corriente (una captura larga de pantalla), no una foto extrema (Q-017-7). Las capturas se comparan **píxel a píxel** (`python3` con Pillow y numpy; se ignoran la barra de estado y la de gestos): «sin cambio» = 0,00 % de píxeles distintos (> 16 de 255), con el control de que el mismo gesto con el bloqueo **apagado** sí cambia la imagen.

**Los gestos de dos y tres dedos sí se pueden conducir:** `adb emu event send` con el protocolo multitoque (`EV_ABS:ABS_MT_SLOT`, `ABS_MT_TRACKING_ID`, `ABS_MT_POSITION_X/Y` en 0..32767, `EV_KEY:BTN_TOUCH` y `EV_SYN:0:0` para cerrar cada informe; `SYN_REPORT` no vale como alias). Un pellizco son ~8 llamadas (bajar los dos dedos, seis pasos de separación, subir). Los puntos van en la **proporción de la pantalla girada** (en horizontal, x entre 0 y 2400 y y entre 0 y 1080 se escalan a 0..32767 cada uno; probado con el bloqueo apagado: con otra hipótesis no pasaba nada). Un dedo, con `adb shell input swipe` (el lápiz, el ratón, la rueda y el *trackpad* no se pueden simular así).

### Con el bloqueo apagado (control)

| Gesto | Resultado |
|---|---|
| Arrastre vertical de 400 px | La foto se desplaza (24 % de píxeles distintos) |
| Pellizco (de 200 a 700 px, dedos puestos) | La foto se amplía (25 %); al soltar vuelve a lo de antes (0,00 %, DEV-43) |
| Swipe horizontal / diagonal 400 × 150 | Cambia de foto (90 %) |
| Horizontal: arrastre vertical y pellizco | Desplaza (26 %) y amplía (31 %) |
| Arranque en frío + arrastre a 0,5, 0,7 y 0,9 s | La foto ya se desplaza (31 %) y el pellizco a 0,7 s también amplía (34 %) |

### Con el bloqueo encendido (CA-017-05, 07, 08, 09, 10, 11, 12)

Encendido con la propia pantalla de Ajustes (CA-017-02), estando la foto 1 **desplazada a mitad** (offset intermedio, colocado antes con un arrastre lento).

- **[Hecho] CA-017-05 y 07:** al encender el bloqueo y volver de Ajustes la foto queda **exactamente igual** (0,00 %): ni tamaño ni desplazamiento cambian. Tras ir a la foto 2 y volver a la 1 por swipe conserva su desplazamiento (0,00 %); la foto 3, que no se había visto, empieza arriba (0 %) y el arrastre vertical no la mueve.
- **[Hecho] CA-017-08 (un dedo y varios):** arrastre vertical rápido (300 ms) y lento (1,5 s), hacia arriba y hacia abajo; diagonal 200 × 300 y 180 × 130 (relación 1,38 < 1,5); toque sobre la foto; pellizco abriendo y cerrando con los dedos puestos; tres dedos hacia arriba; dos dedos hacia la izquierda: **0,00 % de cambio** en todos, durante el gesto y tras soltar. Dos dedos nunca cambian de foto.
- **[Hecho] CA-017-09 (swipe):** swipe horizontal de 700 px (200 ms) y diagonal 400 × 150 (relación 2,67): cambian de foto (89 %), los puntos avanzan y el swipe de vuelta restaura la foto 1 sin diferencia. **[Pendiente]** swipe con lápiz y ratón (no se pueden simular con `adb`; casilla de la 022).
- **[Hecho] CA-017-11 (primer fotograma):** arranque en frío + arrastre vertical a 0,5, 0,7 y 0,9 s: **0,00 %** de cambio y pellizco a 0,7 s: 0,00 % (con el bloqueo apagado, 31 % y 34 %). **Matiz:** el primer fotograma tocable llega a ~0,4 s en este emulador (p50 de T-017-09), así que el gesto más temprano probado (0,5 s) cae justo después; el «ya activo desde el primer fotograma» en sí lo prueba el test de widgets de T-017-04.
- **[Hecho] CA-017-10 (giro):** en horizontal (`adb emu rotate`; las dos orientaciones horizontales) se ven solo la foto, al 100 % del ancho, y el logotipo (sin menú, botón, pie ni puntos); arrastre vertical, diagonal y pellizco (mapeo correcto) **0,00 %**, apagado sí desplazan y amplían; el swipe cambia de foto (99 %) y vuelve a la 1 sin diferencia; al volver a vertical se ve todo y la foto 1 está arriba como en el arranque (0,00 % frente al arranque en frío). La conservación exacta del desplazamiento al girar no se exige (CA-017-10).
- **[Hecho] CL-017-6 (gesto de volver desde el borde):** con el bloqueo encendido y apagado el resultado es **el mismo**: un swipe que arranca a 3, 14 y 25 dp del borde (10, 40 y 70 px) lo recoge el sistema (sale al escritorio, la app no lo impide) y uno que arranca a **30 dp o más** (84, 100 y 140 px) **no** es el gesto de volver: es un swipe del carrusel (cambia de foto). Sin cambio con el bloqueo; el borde de 30 dp de CL-017-6 queda dentro del carrusel en este emulador (la zona del sistema mide ~25 dp).
- **[Hecho] Tres botones** (`cmd overlay enable …navbar.threebutton`; la barra translúcida va sobre la foto): arrastre vertical, pellizco 0,00 %, swipe cambia de foto (90 %) y el botón Atrás sale al escritorio. Restaurado a gestos.
- **[Hecho] CA-017-12:** al apagar el bloqueo (Ajustes) la foto vuelve a desplazarse y ampliarse (los controles de arriba) y el swipe sigue.

### «Recientes» con Ajustes (CA-015-18, spec 011; `tools/check-recents.sh`, `RECENTS_WAIT=4`)

Con el bloqueo **encendido**: `capture` con **Ajustes arriba** (la fila nueva a la vista) y con **la tarea con imagen y grupo**: tarjeta visible y **lisa, desviación 0,00** (máx. 2), parecido tarjeta/pantalla −0,003 y 0,007; `compare ajustes_on tarea_on`: tarjetas **idénticas** (0,00000 de píxeles distintos); `secure`: `not-secure`; `loop 5` y `record 5`: sin fallos (0 lisos que no sean blanco ni fotogramas perdidos; 1 a 3 blancos aceptados por vuelta). Con el bloqueo **apagado**: `capture ajustes_off` lisa (0,00) e **idéntica** a `ajustes_on`. **[Hecho]**. **[Pendiente]** «Recientes» en horizontal: el script no está calibrado (casilla ya abierta de la 016, T-016-20).

### Casillas que quedan

- **[Pendiente]** (022) Swipe con lápiz y ratón, rueda y *trackpad* reales (no se pueden simular con `adb`; los cubren los tests de widgets de T-017-04).
- **[Hecho]** (T-017-10b) TalkBack, teclado, 200 % con tres botones, reducir movimiento y la web de pruebas: ver la sección siguiente.
- **[Hallazgo bajo]** La proporción 1:2 de CA-017-07 no es desplazable en una pantalla 1:2,22 (1080 × 2400) a todo el ancho: **cabe**. No es un fallo (el criterio es «una foto más alta que la pantalla»); T-017-10b usa las mismas fotos 1:2,5.

### Ajustes del emulador

Cambiados y **restaurados**: navegación de tres botones (`threebutton` activado y desactivado; modo de navegación 2 = gestos, como al empezar), giro automático (`accelerometer_rotation` 1, `user_rotation` 0, el sensor virtual de vuelta en vertical), densidad 420, escala de fuente 1,0 y animaciones 1. El interruptor «Bloquear zoom» queda **apagado**. La app real queda con la **tarea nueva de 3 fotos (D 1:2,5, B 3:4, E 1:2,5) como actual** (el grupo de 10 está debajo; «Todas mis tareas» = 2); las fotos de prueba se borraron del emulador.

## T-017-10b: TalkBack, teclado, 200 %, reducir movimiento y la web (2026-10-09)

**Método.** Emulador `Pixel_6a` (API 37, `emulator-5554`, inglés). **No se usó el Xiaomi.** Sin cambios de código ni de la app desde T-017-10a. Capturas, vídeos y volcados, en el directorio temporal de la sesión (no se suben); el `integration_test` temporal y sus fotos de prueba (1:2,5, 3:4 y 1:2,5, generadas con Pillow) se borraron. Ajustes tocados y **restaurados** (comprobado al final): TalkBack (`settings delete` + `accessibility_enabled 0`), densidad 420, `font_scale` 1,0, escalas de animación 1, navegación por gestos, giro automático 1 y rotación 0; «Bloquear zoom» queda **apagado** y la app real, con su tarea de 3 fotos como actual.

### TalkBack (CA-017-04, 14; HU-017-4)

Un `integration_test` **temporal** (APK de depuración, base de datos vacía, repositorio de ajustes que falla a demanda con `Exception('texto-secreto')`, tarea de 3 fotos con texto) lleva la app real por los pasos con **acciones del árbol semántico** (no toques; TalkBack no hace caso de los de `adb`); un guion hace `screencap` al ver cada marca `UNA-STEP` (recuadro verde + panel de voz) y **cuenta las frases** con `GoogleTTSServiceImpl: Synthesis request` de logcat entre marcas (`adb shell log -t UNA-STEP`). Sin volcados de `uiautomator` dentro de las ventanas contadas (cada volcado hace que TalkBack vuelva a leer el foco: 3-5 frases de ruido).

| Casilla | Resultado | |
|---|---|---|
| La fila (CA-017-14) | Foco del lector en la fila: el panel dice «Lock zoom, Images only: no zoom or scroll» (nombre primero, luego el subtítulo); en el volcado, un solo nodo `checkable` (un interruptor), sin icono suelto; el orden de Ajustes es título → Idioma → Pantalla siempre activa → **Bloquear zoom** → Información → tres webs → Cerrar | [Hecho] |
| Estado una vez, sin eco (CA-017-14, CA-015-03) | Encender: «checked» (2 frases: el estado y la pista de la primera vez); apagar: «not checked» (1); volver a encender (con la pista ya dicha): 1. **Ningún anuncio propio de la app** | [Hecho] |
| Fallo de guardado (CA-017-04) | Con el repositorio que falla el interruptor **no se mueve** y TalkBack dice **solo** «Couldn't save the setting.»: 1 frase al primer fallo y 1 al segundo igual (una por intento); **nunca «checked» y luego «not checked»**. El texto secreto no sale en pantalla | [Hecho] |
| Un aviso por fila (CA-017-04, P-017-1) | Fallando también «Pantalla siempre activa»: dos avisos, cada uno bajo **su** fila, **1 frase** al aparecer el segundo; al guardar bien «Bloquear zoom» se quita **su** aviso y queda el de la otra fila; al guardar bien la otra se quita; el foco del lector se queda en la fila que se tocó | [Hecho] |
| La tarea con el bloqueo se lee igual (CA-017-14) | Arranque en frío con TalkBack, la **misma app y la misma tarea** con el ajuste apagado y encendido (repetido 3 veces cada uno, cambiándolo en Ajustes con TalkBack apagado): volcado idéntico (`Current task: 3 photos. Photo 1 of 3`, `scrollable`, menú y botón de completar), **captura idéntica píxel a píxel** (0,00 %, también el panel de voz «Actions available, use Tap with 3 fingers to view») y 4-5 frases al abrir en los dos casos (la lectura inicial de TalkBack; la primera pasada con el bloqueo dio 3 y las demás 4-5). Sin anuncio nuevo al volver de Ajustes (0 frases) | [Hecho] |
| «Desplazar adelante / atrás» con el bloqueo (CA-017-09) | Con el bloqueo encendido, la acción `scrollUp` («adelante») del nodo de la tarea **mueve la foto** (29,9 % de píxeles distintos) y `scrollDown` la deja como estaba (0,00 %); las acciones `scrollLeft`/`scrollRight` cambian de foto con **1 frase** cada una («Photo 2 of 3», «Photo 1 of 3»). Son las acciones del árbol semántico que enviaría TalkBack, **no su gesto real** | [Hecho] la acción; **[Pendiente]** 022 el gesto real de TalkBack |
| Foco al cerrar Ajustes | Como en la 015 (aceptado): el recuadro va a «Task menu» y no queda foco perdido; el foco no se pierde al cambiar el ajuste | [Hecho] |

### Teclado real (CA-017-09, 10, 14)

Teclas de un dispositivo del emulador (`adb emu event text`: Tab y Intro) y, ya en modo teclado, `input keyevent` (Espacio, Escape, Av Pág, flechas); lectura con `uiautomator dump` y capturas.

- **[Hecho] Ajustes:** el orden de Tab es Idioma → Pantalla siempre activa → **Bloquear zoom** → Política de privacidad (el encabezado «Información» no es una parada, como antes de la fila) → Licencias → Ayuda → Cerrar → Idioma…; **anillo de foco visible** (recuadro de tinta de 3 px sobre la fila entera, fondo gris); **Intro** enciende (`checked=true`, pomo a la derecha, el foco se queda en la fila) y **Espacio** apaga. **Escape** cierra Ajustes y el foco va al botón del menú.
- **[Hecho] La tarea con el bloqueo encendido (vertical):** con el foco en la tarea, **Av Pág** desplaza la foto (30,8 %), **Re Pág** la deja como estaba (0,00 %), las **flechas derecha e izquierda** cambian de foto («Photo 2 of 3» y «Photo 1 of 3») y la foto 1 conserva su desplazamiento al volver (0,00 %). Con el foco en el botón del menú, la flecha mueve el foco, no la foto (como siempre).
- **[Hecho] En horizontal** (`adb emu rotate`): dos Av Pág desplazan (26,8 % y 24,6 %), dos Re Pág la devuelven (24,6 % y 0,00 % frente al principio), las flechas cambian de foto (94,8 %) y vuelven (0,00 %), con el anillo de foco sobre la foto. Vuelto a vertical con tres giros más.

### Texto al 200 % con tres botones (CA-017-15)

`wm density 480` (360 dp), `font_scale 2.0` y `navbar.threebutton`, app reiniciada: con el bloqueo **encendido** la tarea se ve igual que antes (logotipo, menú, puntos y «Press to complete» sobre la foto; la barra translúcida va sobre la foto); el menú con «Settings» sobre la barra; Ajustes: «Keep screen on» y «Lock zoom» pasan a varias líneas **sin cortarse**, la fila crece, el interruptor y el pomo quedan dentro, y al desplazar hasta el final «Help» queda **sobre la barra**; con Tab el foco llega a «Lock zoom» y a las filas de abajo a la vista. **[Hecho]**

### Reducir movimiento (CA-017-15, CA-017-09)

Con `transition_animation_scale`, `animator_duration_scale` y `window_animation_scale` a 0 y la app reiniciada, vídeo de `screenrecord` a 540 × 1200 y recorte por fotograma: el pomo de «Bloquear zoom» **cambia en un fotograma** (2 fotogramas en total: el de antes y el de después; con las animaciones normales, ~10 fotogramas en ~150 ms); un swipe de 700 px sobre el grupo (con el bloqueo) cambia de foto en **un solo salto** tras soltar (fotogramas de arrastre, un salto y nada más; sin la transición de 0,28 s). **[Hecho]**

### Web de pruebas en Chrome (CL-017-9)

`flutter build web --release --no-web-resources-cdn` servido con `python3 -m http.server` y Chrome headless con CDP (script de Node propio, sin dependencias nuevas): se crea una tarea con las 3 fotos por «Subir imágenes» (selector interceptado con `DOM.setFileInputFiles`), se enciende «Bloquear zoom» **con la propia pantalla de Ajustes** (el DOM trae el `switch` con `aria-checked`) y se comparan capturas (500 × 828; se ignora la franja de arriba).

| Gesto | Bloqueo apagado (control) | Bloqueo encendido |
|---|---|---|
| Rueda del ratón (±300) | La foto se desplaza (26 %) | **0,00 %** (y la vuelta) |
| Arrastre táctil vertical y diagonal | Se desplaza (27 %) | **0,00 %** |
| Arrastre con el ratón vertical | 0,00 % (el ratón no desplaza, como en Flutter) | 0,00 % |
| Ctrl + rueda (pellizco de *trackpad* en Chrome) | 0,00 % (no se ve efecto) | 0,00 % |
| Pellizco sintético (táctil y de ratón) | no se puede ver (suelta y vuelve, DEV-43) | 0,00 % |
| Swipe horizontal con ratón y con dedo | Cambia de foto (90 %) | **Cambia de foto (90 %)** y vuelve |

**[Hecho]** la rueda, el arrastre y el swipe; **[Suposición]** el pellizco y Ctrl + rueda: sin efecto visible incluso con el bloqueo apagado en este Chrome, así que esas dos filas no prueban nada por sí solas (las cubren los tests de widgets de T-017-04a: *trackpad*, rueda, ratón y lápiz).

### Casillas que quedan para la 022

- **[Pendiente]** (022) El gesto real de TalkBack para «desplazar adelante / atrás» y la voz (el panel de voz no enseña el idioma ni la voz); Switch Access (el barrido no se conduce con `adb`); control por voz; lupa del sistema; lápiz, ratón, rueda y *trackpad* reales.

## Bloquear zoom en el Xiaomi (spec 017, CA-017-11, CA-016-08, CA-016-23)

- **Fecha:** 2026-10-10 · **Dispositivo:** Xiaomi 15T Pro (Android 16 / HyperOS, 120 Hz), con permiso del propietario · **Compilación:** `flutter build apk --profile --split-per-abi --target-platform android-arm64` (39,7 MB), instalada como app **`.profile` aparte** (la app real no se tocó) y desinstalada al acabar; fotos de prueba (10 JPEG de 4000 × 6000, ~4,9 MB) en `/sdcard/Pictures/una017`, borradas después. Sin capturas de pantalla (el árbol de accesibilidad bastó).
- **Método:** como en el emulador: pasadas **alternadas** de 20 arranques en frío (`am start -W -S`, `TotalTime`; copia del script con el nombre completo de la actividad `invalid.pending.app.MainActivity`, porque con el sufijo `.profile` la ruta relativa no resuelve) y calentamiento de 5 s; el ajuste se cambia en la propia pantalla de Ajustes y su estado se lee (`checked`) antes de cada pasada. Memoria: `dumpsys meminfo` (TOTAL PSS, **incluye la GPU**), 5 lecturas en reposo y lectura continua mientras un guion da gestos reales con `input swipe` (una foto: arrastres verticales y diagonales, 25 rondas; grupo: 9 swipes hacia delante y 9 hacia atrás, 13 rondas).

| Contenido | Bloqueo | p50 de las pasadas (ms) | Media |
|---|---|---|---|
| 1 foto de 24 MP | apagado | 376, 370 | 373 |
| 1 foto de 24 MP | encendido | 375, 377 | 376 |
| grupo de 10 | apagado | 368, 370, 375, 367 | 370 |
| grupo de 10 | encendido | 372, 377, 377, 371 | 374,25 |

- **[Hecho]** CA-017-11: p50 < 1 s (≈ 370 ms) con el ajuste encendido y sin empeorar de forma apreciable: con una foto **+3 ms** (deriva entre las dos pasadas apagadas, 6 ms); con el grupo **+4 ms (+1,1 %)**, dentro de la deriva entre pasadas apagadas (8 ms). Con el grupo, el signo del emulador (+10 ms) se repite pero aquí es la mitad y cabe en el ruido; la reserva del plan §4 (consulta única) **no hace falta**. **[Hecho]** CA-016-08: grupo frente a una foto −3 ms (apagado) y −2 ms (encendido), muy por debajo de +100 ms. Nota: es una compilación de perfil, no *release* (la línea base del Xiaomi de 198 ms es de una tarea con texto).
- **[Hecho]** Memoria (TOTAL PSS, MB; reposo · mediana recorriendo · pico), pasadas en orden:
  - **1 foto** encendido: 237,9 · 238,6 · 240,0 / 226,3 · 232,1 · 233,3 / 215,6 · 221,0 · 222,7 / 212,2 · 218,1 · 219,4; apagado: 215,8 · 221,8 · 223,1 / 218,4 · 223,8 · 225,0 / 216,9 · 222,7 · 223,9 / 213,7 · 218,9 · 221,1. Las primeras pasadas (justo tras los bucles de arranque) salen más altas y todas bajan con el tiempo; **no hay diferencia sistemática** entre encendido y apagado (un par sale +9 MB a favor del apagado y los dos siguientes, −1,3 y −1,5 MB), pero el ruido entre pasadas del mismo estado llega a ~25 MB: con esta deriva no se detectaría una diferencia menor de ~10 MB. **[Suposición]** que no la hay (la causa física no existe: el ajuste solo quita el desplazamiento).
  - **Grupo de 10** encendido: 250,4 · 370,7 · 399,5 / 240,3 · 369,4 · 392,2; apagado: 239,3 · 370,8 · 391,9 / 242,5 · 369,2 · 390,7. **Sin diferencia** (medianas 369-371 MB, picos 390,7-392,2 MB; la primera pasada, de calentamiento, 399,5).
- **[Hallazgo, no es de la 017]** CA-016-23 en el Xiaomi: el pico del grupo (**≈ 391 MB**) supera en **≈ +166 MB** al de una sola foto (≈ 222-225 MB), muy por encima del +50 MB de la spec 016 (que se midió en el emulador sin GPU y estaba marcado **[Suposición, se confirma al medir]**). Aquí el PSS incluye la GPU (Graphics ≈ 87 MB constantes en una foto) y solo se recorrió el grupo con swipes (sin pellizco, que con el bloqueo no existe). Es del carrusel de la 016, igual con el bloqueo encendido y apagado; **lo decide el propietario** (ADR-0024: tope menor de megapíxeles en los grupos, no inferior a 12 MP, o aceptar el valor). La app no se cerró y los 4 *goldens* de Ajustes no cambian.
- **No medido:** hueco al cambiar de foto y espacio por tarea en el Xiaomi (casillas de la 016, siguen **[Pendiente]**), Android 8 y 12L (PD-10).
