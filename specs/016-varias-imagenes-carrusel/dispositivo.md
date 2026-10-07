# Spec 016: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, `emulator-5554`, 1080 × 2400, densidad 420, inglés, navegación por gestos)**. **No se usó ni se tocó el Xiaomi** (todos los `adb` llevan `-s emulator-5554`). APK de depuración (`flutter build apk --debug --target-platform android-arm64`), base de datos vacía. Las capturas, en el directorio temporal de la sesión.

## T-016-20 (1/2): importación, gestos y medidas (2026-10-07)

### Importación con el selector real del sistema

| Casilla | Resultado | Estado |
|---|---|---|
| "Subir imágenes" → selector de fotos del sistema con selección múltiple; 3 fotos (1, 2, 3) → "Done" | El editor muestra la pila de 3 (la 1 arriba, giros del prototipo) con la etiqueta "3 photos" (blanco sobre tinta) y la hoja dice "Upload images / One or more · go on top" | [Hecho] |
| Guardar y abrir la tarea | Carrusel a pantalla completa con la foto 1, puntos (3) bajo el pie y "Press to complete" | [Hecho] |

### Gestos (navegación por gestos; fotos de 1200 × 1600)

Con `adb shell input swipe`; `touchSlop` real del emulador (sin sustituir).

| Casilla | Resultado | Estado |
|---|---|---|
| Swipe horizontal a izquierda y derecha; carrusel infinito (1→2→3→1→3) | Correcto | [Hecho] |
| Diagonal (CA-016-10, relación 1,5): dx 500 / dy 200 (2,5) y dy 300 (1,67) | Cambia de foto | [Hecho] |
| Diagonal: dx 500 / dy 400 (1,25) y dx 300 / dy 500 (0,6) | No cambia | [Hecho] |
| Vertical puro con la foto entera en pantalla | No cambia | [Hecho] |
| 60 px lento (< 18 %) | No cambia | [Hecho] |
| 150 px en 60 ms (≥ 700 dp/s) | Cambia | [Hecho] |
| **Gesto de volver del sistema**, margen medido: `systemGestures` = **78 px (≈ 30 dp)** a izquierda y derecha, también en horizontal (2322–2400 px) | Desde x ≤ 76 y x ≥ 1004 (y 1050/1020 a la derecha) toma el gesto el sistema (la app va a segundo plano; el carrusel no se mueve). Desde x = 80, 100, 980 y 1000 lo toma la app y cambia de foto | [Hecho] `systemGestureInsets` medido |
| **Tres botones** (`navbar.threebutton`): `systemGestures` = 0 | El swipe desde x = 20 y x = 1060 cambia de foto | [Hecho] |
| **Horizontal** (`adb emu rotate`): la foto llena el ancho, solo foto y logotipo | Swipe izq., diagonal 3,7 cambia; 1,2 no; el desplazamiento vertical de la foto funciona; margen del sistema 78 px a ambos lados (desde x = 40 y 2360 toma el sistema; desde 100 y 2300, la app) | [Hecho] |
| **Pellizco** (sin multitoque en `adb input`: eventos `adb emu event send 3:47:… 3:57:… 3:53:… 3:54:…` al panel táctil virtual, dos dedos) | Con los dedos puestos, el zoom aumenta y el pie y los puntos no se mueven ni cambia la foto; al soltar vuelve a 100 % | [Hecho] |
| **CL-016-10: el segundo dedo llega durante un swipe** (mismos eventos) | El swipe se cancela y la foto no cambia; un swipe normal de control, sí | [Hecho] |

### Importación (selector del sistema, emulador)

| Casilla | Resultado | Estado |
|---|---|---|
| Fallo parcial: 5 elegidas, una malformada (`truncated.jpg`/`html_as.jpg` en la galería) | Pila de 4 con "4 photos" y el aviso "4 photos added. 1 photo couldn't be added." (recuadro fijo, no caduca) | [Hecho] |
| Cancelar el editor tras importar | `cache/import` queda vacío (0 archivos) y no se crea nada en `files/attachments` | [Hecho] |
| **Sin espacio** (relleno de 3990 MB; quedan 110 MB, el grupo pide ~190 MB) | "Your phone is out of storage", sin temporales (`cache/import` vacío); el relleno se borró al acabar (4220 MB libres) | [Hecho] |
| Selector de fotos con 3 y con 1 foto, cancelar; selector de documentos con 11 → 10 (`limited`); tiempo agotado forzado en la copia o en 64 MP (nunca dos `source` a la vez, la foto siguiente no agota sus 20 s) | Verificados en T-016-08 con `photo_group_import_test` (ver su fila de Estado); se repite al final de esta sesión | [Hecho en T-016-08] |
| Importar **10 fotos de 24 MP** (4000 × 6000, ~6,3 MB cada una) | Pila de 10 con "10 photos" en menos de 6 s en el emulador (no se cronometró con precisión) | [Hecho] |

### Medidas (R-24; emulador, *release* arm64 sin firma de producción salvo indicación)

| Medida | Resultado | Objetivo | Estado |
|---|---|---|---|
| Arranque en frío (`measure-cold-start.sh`, n = 20) con **una** foto de 24 MP | p50 **425 ms**, p90 457, máx 568 | — | [Hecho] |
| Arranque en frío con un grupo de **10** fotos de 24 MP | p50 **429 ms**, p90 446, máx 532 (**+4 ms**) | p50(10) ≤ p50(1) + 100 ms y < 1 s | [Hecho] |
| Memoria (PSS, `dumpsys meminfo`, muestreo continuo durante 25 swipes seguidos por las 10 fotos, 1017 muestras) | grupo de 10: reposo 76 MB, mediana 78 MB, **pico 102 MB**. Una sola foto de 24 MP (mismo muestreo, 25 gestos): reposo 74 MB, mediana 81 MB, **pico 81 MB**; con pellizco, 77 MB | pico ≤ +50 MB sobre una foto | [Hecho] **+21 MB** |
| Hueco al cambiar de foto (`screenrecord --output-format=raw-frames`, 360 × 800, 12 swipes, 214 fotogramas a ~15 fps; zona de la foto sin el color de la página) | **0** fotogramas con fondo en 181 con movimiento (hueco p90 < 1 fotograma ≈ 66 ms; el emulador no graba a más) | p90 ≤ 200 ms | [Hecho] |
| **Espacio por tarea** de 10 fotos de 24 MP (`du` de `files/attachments` en la app de depuración) | **62 MB** (63 624 KB): por foto, `full` 4,1 + 2,0 MB (dos teselas) + `screen` 0,3 MB + miniatura 9 KB; el *staging* en `cache/import` ocupa lo mismo y queda en 16 KB al guardar | ≤ 150 MB | [Hecho] |
| Espacio con una foto **de 19 MB** (24 MP, ruido casi incompresible) | queda en **14,5 MB** (`full` 9,3 + 4,3 MB, `screen` 0,9 MB): 10 así serían ~145 MB, justo bajo el límite | — | [Hecho] |
| `ImageLimits.storedPhotoEstimate` | **Se mantiene en 16 MB** (cota superior: ninguna foto medida guardó más de 14,5 MB); no hace falta la regla de ≥ 12 MP del ADR-0024 | decisión | [Hecho] |
| **Contraste de los puntos** con fotos lisas blanca, negra y gris medio (1200 × 2400, los puntos caen sobre la foto) | Se distinguen los tres estados en los tres fondos: sobre blanco, borde de tinta; sobre negro, halo blanco; sobre gris, ambos | CA-016-09 | [Hecho] |

### "Recientes" (`check-recents.sh`, app de depuración, `RECENTS_WAIT=4`)

Escenario "grupo de 3 fotos distinguibles" (`fixtures push`; roja, verde y azul).

| Escena | Resultado | Estado |
|---|---|---|
| Carrusel: `capture` con la foto 1 y con la foto 3, y `compare` | Tarjeta visible y lisa (desviación 0,00 en las dos); no se parece a la pantalla (-0,065 y -0,063); **idénticas** (0 píxeles distintos) | [Hecho] |
| `secure` con el carrusel delante | `not-secure` (sin `FLAG_SECURE`) | [Hecho] |
| `loop 5` y `record 5` con el carrusel | Sin fallos: tarjeta lisa en las 5 vueltas, `lisos_fallo=[]`, `perdidos=[]`, solo el fotograma blanco aceptado (CA-011-03) | [Hecho] |
| "Foto no disponible" (se borró el directorio de la foto 3 con `run-as`; la 1 y la 2 se ven bien, sin cierre) | `capture` y `loop 3`: tarjeta lisa (0,00) | [Hecho] |
| Editor con la pila de 3 | Tarjeta lisa (0,00) | [Hecho] |
| "Preparando foto 3 de 9…" (9 fotos de 19 MB, ~0,4 s por foto) | Tarjeta lisa (0,00). **[Suposición]** la captura se tomó unos segundos después de aceptar y la preparación pudo haber acabado: la tarjeta no depende del contenido (la decide el nativo, ADR-0019) | [Hecho con salvedad] |
| Selector de fotos del sistema delante (preselección) | El script no encuentra la tarjeta lisa: la tarjeta enseña la **hoja del propio selector** (las fotos de la galería del sistema) sobre el fondo de la app, sin ningún contenido de Una. Es el límite ya aceptado de la 011 ("hoja parcial del selector de fotos") | [Hecho: límite aceptado] |
| Horizontal (`adb emu rotate`) | `capture` falla con desviación 14: el script está calibrado para vertical y en horizontal la tarjeta lleva una franja negra a la izquierda (el borde del sistema girado). El interior sin la franja es blanco liso (desviación 0,00, media 255) y las tarjetas con la foto 3 y la 2 son idénticas. **Hallazgo:** el script no sirve tal cual en horizontal; no se cambia aquí (a `docs/testing.md` en T-016-23) | [Hecho a ojo y por recorte; script sin calibrar] |
| Android 8 (API 26) y 12L (API 32) | No hay emuladores (PD-10) | [Pendiente PD-10, antes de la beta] |

### Completar, eliminar y rotación

| Casilla | Resultado | Estado |
|---|---|---|
| **Eliminar** con la foto 1 a la vista (`screenrecord` en bruto, 113 fotogramas): la cara del arrugado | El rojo de la foto 1 baja de forma continua (0,51 → 0,01) mientras se arruga; el blanco no pasa del 7 % y nunca hay un fotograma liso hasta que sale la card. **No sale en blanco** | [Hecho] |
| Card "Task deleted · Tres · Undo" con el grupo | La card sale con el nombre de la tarea. **No se comprobó el deshacer a mano:** mi pulsación llegó después de los 4 s y caducó (el deshacer con grupo, la foto 1 al volver, lo cubren `photo_face_test` y `photo_group_list_test`) | [Hecho la card; deshacer no repetido aquí] |
| **Completar** (mantener 2,6 s; 127 fotogramas) | La cara muestra la foto 1 durante la pausa y el rasgado (rojo 0,54 → 0,00); blanco ≤ 9 %, desviación ≥ 28 en todos los fotogramas. **No sale en blanco** | [Hecho] |
| Rotación: las dos orientaciones apaisadas (`ROTATION_90` y `ROTATION_270`, recorte de cámara a un lado u otro) y 180° | Igual en las tres: margen del sistema de 78 px; desde x = 40 toma el sistema y desde x = 100 cambia de foto | [Hecho] |
| **CL-016-5**: grupo con una captura de 1080 × 20 000 y dos fotos 3:4 | Cada foto a todo el ancho y con su altura; la alta se desplaza; al cambiar a otra y volver, **conserva su posición**; las otras empiezan arriba | [Hecho] |

### Resumen y pendientes de la T-016-20

- **No se creó `integration_test/photo_group_perf_test.dart`:** las medidas (arranque, memoria, hueco, espacio) se tomaron con `adb` sobre la *release* y la de depuración; el método queda en `docs/perf/baseline.md`. Un test de rendimiento propio no aportaría más que el método de `adb`, que mide el arranque real.
- **[Hecho]** `systemGestureInsets` = 78 px (≈ 30 dp) con gestos y 0 con tres botones, en vertical y horizontal: el supuesto del plan §5 queda confirmado.
- **[Hecho]** `storedPhotoEstimate` = 16 MB se mantiene y no hace falta tocar la regla de ≥ 12 MP del ADR-0024 (62 MB por tarea con fotos de 6 MB; 14,5 MB con una de 19 MB).
- **[Pendiente]** Android 8 y 12L (`check-recents.sh`, PD-10). **[Pendiente]** las medidas en el Xiaomi (gama alta): no se hicieron (sin permiso del propietario para tocarlo); todo se midió en el emulador, que es más lento (arranque con una foto: 425 ms frente a los 198 ms de la línea base del Xiaomi).
- **[Hallazgo, sin corregir]** `check-recents.sh` no está calibrado para la tarjeta apaisada (ver arriba).
- Método: pellizco y segundo dedo con `adb emu event send` (el panel táctil virtual acepta eventos multitoque); `sendevent` no funciona (sin root).
- Ajustes restaurados: gestos de navegación, rotación automática y a 0, fuente 1,0, sin TalkBack; galería, relleno de disco y *release* borrados; la app de depuración se reinstaló con la compilación normal (`flutter test integration_test` deja instalado el APK de la prueba, que no arranca solo).

## T-016-21 (2/2): TalkBack, teclado y Switch Access (2026-10-07)

Mismo emulador (`emulator-5554`, API 37, inglés; el Xiaomi no se tocó). Método de `docs/testing.md` §3: `integration_test` temporal (no subido) con un grupo de 5 fotos (la 1, la `tall_1080x20000.png`), acciones del árbol semántico, `adb` para capturas en ráfaga (~8 por segundo, recorte del panel de voz), teclas y giros, y recuento de frases (`GoogleTTSServiceImpl: Synthesis request`) entre marcas escritas en logcat. Para que el teclado del sistema no ensucie el panel se puso `show_ime_with_hard_keyboard 0` (valor de partida, ya restaurado).

### TalkBack

| Casilla | Resultado | Estado |
|---|---|---|
| Foco al abrir | TalkBack enfoca el **nodo único** de la tarea (recuadro verde en toda la pantalla) y lo lee: «Current task: Probe. 5 photos. Photo 1 of 5». Sin segunda parada (el nodo vivo del anuncio no se enfoca) | [Hecho] |
| **5 cambios seguidos por acción** (`scrollLeft`) y **5 por gesto** (`fling` en el carrusel) | **Una frase por cambio** en dos pasadas limpias: 1-1-1-1-1 y 1-1-1-1-1 (el panel lee «Photo 2 of 5» … «Photo 5 of 5», sin eco de la etiqueta del nodo enfocado). Se descartaron dos pasadas con 2–3 frases en algunos pasos: eran ruido del propio guion (un `uiautomator dump` hace que TalkBack vuelva a leer el nodo y dice «Actions available…»; y el teclado del sistema decía «Showing English (US)»). **Se queda B (región viva)**; A y el plan C quedan sin usar | [Hecho] |
| Foco en el mismo elemento al cambiar | El recuadro sigue en el nodo tras cada cambio, en la foto que falta y en horizontal; el nodo no se recrea | [Hecho] |
| Llegada a «Foto no disponible» (borrada la carpeta de la 3) | Por acción: «Photo 3 of 5. Photo unavailable» (una frase); volver: «Photo 2 of 5»; en horizontal, la misma frase y el foco donde estaba | [Hecho] |
| Horizontal (`adb emu rotate`) | Foto a pantalla completa, cambio por acción con una frase, foco en el nodo | [Hecho] |
| **«Desplazar hacia delante» con una foto alta** (plan §6) | `javap` del `AccessibilityBridge` del *embedding* (Flutter 3.47.5): `ACTION_SCROLL_FORWARD` → `SCROLL_UP` si el nodo lo tiene, si no `SCROLL_LEFT`; `ACTION_SCROLL_BACKWARD` → `SCROLL_DOWN`, si no `SCROLL_RIGHT`. Con la foto 1 (alta) arriba, el nodo ofrece `up`, `left` y `right` (no `down`); tras 10 `scrollUp` llega al final y `up` desaparece y sale `down`. **Resultado:** «adelante» recorre la foto hasta el final y **luego** pasa a la siguiente; «atrás», lo contrario; con una foto que cabe, «adelante» = siguiente. Orden lineal, nada queda inalcanzable y «Foto siguiente/anterior» es siempre directa: **se deja como está** (no se fuerza vertical/horizontal; **aceptado por el propietario, 2026-10-07**) | [Hecho] la decisión; **[Pendiente 022]** el gesto real de TalkBack (no se puede conducir con `adb`) |
| Editor: foco tras importar | Recuadro verde en la **pila** al volver; con «Preparando foto 3 de 4…» el árbol lleva ese texto y «Cancel» con el foco de entrada; tras «Quitar adjunto» el foco va a **(+)** («Add a photo, image or file») | [Hecho] |
| Editor: **anuncios** («{n} fotos añadidas», el compuesto, «Attachment removed», «Preparando…») | `sendAnnouncement` **no sale en el panel de voz del emulador** (igual que el hallazgo 1 de la 014: se oye en el móvil); el recuento de frases no basta para distinguirlas | **[Pendiente 022]** con el móvil y el oído del propietario: que el compuesto no lo pise «Vista previa: …» ni el «Preparando…» |

### Teclado real (sin TalkBack; Tab con `adb emu event text`, flechas y Av Pág con `input keyevent` ya en modo teclado)

| Casilla | Resultado | Estado |
|---|---|---|
| Foco al abrir | La tarea tiene el foco desde el principio: la primera flecha derecha, **sin Tab**, cambia de foto (también en horizontal); el primer Tab lo lleva a «Menú» | [Hecho] |
| Anillo | Visible alrededor de la foto al volver a ella (negro y blanco, dentro del margen), en el menú y en Completar; en horizontal, dentro de la foto | [Hecho] |
| Flechas | Derecha = siguiente, izquierda = anterior; **con el foco en el menú, la flecha no cambia de foto**; una tecla **mantenida 1,8 s cambia una sola vez** (repetición ignorada) | [Hecho] |
| Av Pág / Re Pág | Con la foto alta, **desplazan la foto** sin cambiar de foto; con una foto que cabe, no hacen nada | [Hecho] |
| Orden de Tab | foto → Menú → Completar | [Hecho] |

### Otros

| Casilla | Resultado | Estado |
|---|---|---|
| 200 % de texto, 360 dp (`wm density 480`), tres botones | El pie sale con 3 líneas y «…», los puntos debajo sin tapar el texto ni Completar, la etiqueta «5 photos» y el aviso enteros; en horizontal, solo la foto. **Aparte:** con un texto largo el editor deja (+) y Guardar medio bajo la barra de tres botones, **igual sin fotos** (comprobado): es del editor de la 003, no de la 016 | [Hecho]; hallazgo previo a la 016 a la **022** |
| Reducir movimiento (`transition/animator/window_animation_scale 0`) | Sin él, la foto nueva entra deslizando (fotogramas intermedios); con él, ningún fotograma intermedio | [Hecho] |
| **Switch Access** con el teclado como interruptor | Las teclas DPAD de `input keyevent` no llegan a su barrido (límite ya anotado en la 015): no se puede conducir. Las acciones «Foto siguiente/anterior» y las de desplazamiento horizontal están en el nodo (probadas por acción) | **[Pendiente 022]** (móvil del propietario) |
| **La voz** (idioma de la app frente al del sistema) y el **control por voz** («Foto siguiente» por su nombre) | No se deciden aquí (spec) | **[Pendiente 022]** |

Ajustes restaurados: sin TalkBack, densidad 420, fuente 1,0, navegación por gestos, animaciones a 1, `show_ime_with_hard_keyboard` como estaba, rotación vertical.
