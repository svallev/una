# Spec 011: pruebas en el dispositivo

Guía y resultados de la verificación con `adb` (plan §5). Todo en el **emulador de Android 16 (API 37)**; nunca en el Xiaomi sin permiso del propietario. Las capturas están en `capturas/` (reducidas; solo las tareas de prueba "uno" y "dos", sin datos privados).

## 0. Cómo se usa el script

```bash
# El serial es obligatorio. Un serial que no sea "emulator-*" exige ALLOW_PHYSICAL=1
# (solo con permiso explícito del propietario).
S=emulator-5554
tools/check-recents.sh $S capture uno /tmp/x      # con la tarea A ("uno") en pantalla
# (cambiar a la tarea B, "dos", y repetir)
tools/check-recents.sh $S capture dos /tmp/x
tools/check-recents.sh $S compare uno dos /tmp/x  # CA-011-01: falla si enseña contenido o A y B difieren
tools/check-recents.sh $S secure                  # CA-011-04: sin FLAG_SECURE con la app delante
tools/check-recents.sh $S loop 10 /tmp/x          # CA-011-08 (sin cámara ni selector)
tools/check-recents.sh $S record 10 /tmp/x        # parpadeo (CA-011-03), con tiras de fotogramas
```

- Necesita `adb` (variable `ADB`, `PATH` o el SDK en `~/Library/Android/sdk`) y `python3` con Pillow y numpy (solo herramienta local; no es una dependencia del proyecto).
- **Dos rutas para abrir "Recientes"** (hallazgo de T-011-01, §2): por defecto el script pasa antes por el escritorio (`KEYCODE_HOME` y luego `KEYCODE_APP_SWITCH`), que es la ruta de CA-011-01; con `VIA=direct` lo abre desde la propia app y **solo informa** (CL-011-14: fuera del criterio).
- "Parecido" es la correlación entre la pantalla y la tarjeta de "Recientes" (0,96 con el contenido visible; ≈ 0 sin él). Umbral: 0,5. Las tarjetas de A y B se comparan píxel a píxel dentro de la tarjeta (tolerancia 0,1 % de píxeles).
- Limitación conocida del script: `record` usa `screenrecord --output-format=raw-frames`, que no da tiempos y solo emite fotogramas cuando la pantalla cambia; detecta que hay un fotograma liso, pero no cuánto dura. El liso **blanco** es la excepción aceptada de CA-011-03 (sale como `blancos_aceptados` y no falla); cualquier otro liso (negro…) o que la app desaparezca tras verse es fallo. Los tiempos de §3 salen de un `screenrecord` a mp4 leído con `AVAssetReader` (script de un solo uso, no incluido).

## 1. Estado de partida (T-011-01 a)

Compilación *release* de `main` (sin `RecentsPrivacy`), tareas "uno" y "dos", emulador API 37.

- [x] **Hoy "Recientes" enseña el contenido.** `capturas/partida-escritorio-uno.png` y `partida-escritorio-dos.png` (por el escritorio) y `partida-directo-uno.png` (directo): se ve el logotipo, el menú, "uno" y el botón.
- [x] **El script falla en este estado** (código de salida 1):

```
[uno] la tarjeta ... FALLO CA-011-01: la tarjeta de 'uno' enseña el contenido (parecido 0.959 con la pantalla)
FALLO CA-011-01: la tarjeta de 'dos' enseña el contenido (parecido 0.960 con la pantalla)
FALLO CA-011-01: las tarjetas de uno y dos difieren (píxeles distintos: 0.00325)
```

- [x] Con la app delante: sin `FLAG_SECURE` y captura con contenido (CA-011-04 hoy se cumple).
- [x] Sin parpadeo hoy: 4 vueltas de `record`, ningún fotograma liso (`capturas/partida-vuelta-tira.png`) y ningún fotograma liso en 5 vueltas grabadas a mp4.

## 2. Mecanismos probados en API 37 (T-011-01 c)

Mismo `RecentsPrivacy.kt` provisional con una constante (`A`: `setRecentsScreenshotEnabled(false)` en `onCreate`; `B`: `FLAG_SECURE` en `onPause` y fuera en `onResume`; `none`: nada). Compilación *release*.

| Comprobación | Partida (`none`) | A (Android 13+) | B (`FLAG_SECURE` al pausar) |
|---|---|---|---|
| **Escritorio → "Recientes"**: tarjeta con contenido | Sí (0,96) | **No (≈ 0)**; fondo blanco con franja negra arriba (`A-escritorio-*.png`) | **No (≈ 0)**; igual que A (`B-escritorio-*.png`) |
| Tarjetas de A y B idénticas | No | **Sí** (0,05 % de píxeles) | **Sí** (0 %) |
| **Desde la propia app → "Recientes"** (`VIA=direct`) | Contenido | **Contenido (0,96)** (`A-directo-uno.png`) | **Contenido (0,96)** (`B-directo-uno.png`) |
| `FLAG_SECURE` con la app delante | No | No | No |
| Captura (`screencap`) con la app delante y tras volver | Con contenido | Con contenido | Con contenido |
| **Fotograma blanco liso al volver desde "Recientes"** (CA-011-03) | **No** (0 de 9 vueltas) | **Sí**: 2 de 4 vueltas con `raw-frames` y 2 de 5 con mp4 | **Sí**: 3 de 5 vueltas con `raw-frames` y 2 de 5 con mp4 |
| `screenrecord` de la app en segundo plano | Contenido | Blanco | Negro (la ventana es segura mientras dura la pausa) |

Lecturas:

1. **Los dos mecanismos ocultan la instantánea** cuando la app se ha ido al segundo plano de verdad (por el escritorio). Se ve lo mismo con A y con B: la tarjeta en blanco que pinta el sistema.
2. **Ninguno de los dos oculta la tarjeta cuando "Recientes" se abre desde la propia app** (deslizar hacia arriba con la app delante). Ahí el lanzador enseña la ventana **en vivo** de la app y la actividad **no llega a pausarse** (no hay `wm_pause_activity` de la app; el lanzador es el único en `ResumedActivity` del sistema pero la app conserva el `topResumedActivity` de su tarea). `setRecentsScreenshotEnabled` solo actúa sobre la instantánea y `FLAG_SECURE` en `onPause` llega tarde. **[Hecho]** para API 37; **[Suposición]** que en Android 13–16 es igual (transición "transitoria" de "Recientes"). Es lo que hace hoy "Recientes" con cualquier app; la instantánea queda oculta en cuanto se cambia de app.
3. **Al volver desde "Recientes" se ve un fotograma blanco a pantalla completa** con la instantánea vacía, antes de que la app se dibuje (`A-vuelta-tira.png`, `B-vuelta-tira.png`: el fotograma liso, entre "Recientes" y la app). Con la app sin ocultar no ocurre. Con mp4 el fotograma blanco dura ≈ 1,0–1,1 s en las dos vueltas en que se ve (13,504 → 14,610 s y 30,191 → 31,181 s en A); **[Suposición]** el valor está inflado por la carga de la grabación en el emulador. El blanco coincide con el `windowBackground` del `LaunchTheme` (`launch_background.xml`: blanco): **[Suposición]** es lo que el sistema pinta cuando no hay instantánea.
4. Con B, `dumpsys window` marca `SECURE` solo con la app detrás (por el escritorio) y nunca delante.

### Decisión (propietario, 2026-09-30) [Hecho]

- **Mecanismo definitivo:** A en Android 13+ y B en Android 8-12 (plan §1), implementado en T-011-02.
- **Se acepta el fotograma blanco** al volver desde "Recientes" (CA-011-03 enmendado); no se cambia el `LaunchTheme`.
- **La ruta directa** (`VIA=direct`) queda fuera de CA-011-01 (CL-011-14): solo informativa.

## 3. Verificación completa en API 37 (T-011-03, 2026-09-30)

**Entorno.** Emulador `Pixel_6a` (`sdk_gphone16k_arm64`, Android 16 / API 37), `emulator-5554`; el Xiaomi no estaba conectado ni se tocó. Compilación *release* de `4e30a1b` reconstruida con `--target-platform android-arm64` (el emulador es arm64: una x86_64 no arranca) y **línea base** = *release* de `9e215b3` (sin `RecentsPrivacy`), sacada con `git archive` a un directorio temporal, para comparar lo que "no debía empeorar". La captura de la tarjeta usa `tools/check-recents.sh` (escritorio → "Recientes"); las tareas de prueba son "uno"/"dos" y variantes con imagen ("IMG UNO"/"IMG DOS"), PDF ("PDF UNO"/"PDF DOS", generados con Pillow) y dos páginas web públicas (`google.com` como A y `wikipedia.org` como B). Sin datos privados en las capturas.

**Incidente del entorno:** `adb shell input keyevent --longpress KEYCODE_POWER` **apagó el emulador** (no sacó el menú de apagado); se relanzó con arranque en frío y los datos de la app siguieron. No se repite: la prueba del menú de apagado queda sin hacer (CL-011-4).

**Resolución de los hallazgos (2026-09-30) [Hecho].** El propietario aceptó H-1, H-2 y H-3 el 2026-09-30 y la spec se enmendó en `594f5d1` (CL-011-15 nuevo, CL-011-6 corregido, excepción del blanco ampliada y CA-011-08): los "FALLA" y "falla" de esta sección describen lo medido, no un estado abierto. H-4 (pantalla en negro tras un WebView, §3.7) quedó como TD-2 en `docs/PLAN.md`.

### 3.1 Resultado por criterio y caso

| Criterio / caso | Resultado | Notas |
|---|---|---|
| CA-011-01 (sin contenido en "Recientes", por el escritorio) | **Pasa** | Las 14 filas (§3.2): la tarjeta es blanca con la franja negra de arriba, sin ningún rastro del contenido (§3.2) |
| CA-011-02 (matriz) | **Pasa** en las 14 filas aplicables | "Configuración y perfil", licencias y confirmación de enlace de la spec 012: **no aplica todavía, spec 012 sin implementar** |
| CA-011-03 (vuelta sin parpadeo) | **Pasa con una precisión** (§3.3) | 0 fotogramas negros y ninguno de otro color; el blanco dura 0,4-1,25 s (en el emulador, inflado) al volver **con `am start` o con el icono**; al volver **tocando la tarjeta** casi no hay fotograma liso. Reloj 9:59 y 10:00: test añadido |
| CA-011-04 (capturas y grabaciones) | **Pasa** | §3.4 |
| CA-011-08 (ciclo completo) | **Pasa** el ciclo básico (10) y el de la **cámara** (10); **falla** el del **selector de fotos** en "la tarjeta no muestra contenido" (10 de 10; la captura sí sale con contenido). Ver H-1 |
| CL-011-1 (actualizar desde la anterior) | **Confirmado** | Al actualizar de la línea base a la nueva la tarjeta antigua (con "SECRETO-UNO") sigue en "Recientes" hasta la próxima vez que la app pase a segundo plano. Aceptado en la spec |
| CL-011-2 (el sistema mata la app) | **Pasa** | `am kill`: la tarjeta sigue en blanco; al abrirla arranca y muestra la tarea actual |
| CL-011-3 (cámara y selectores) | **Cámara: pasa. Selector de archivos: pasa. Selector de fotos: FALLA** (H-1) | La cámara y el selector de archivos son pantallas completas de otra app: la tarjeta enseña **lo suyo** (escena de la cámara, lista de archivos), no la app. El selector de fotos es una hoja parcial encima de la app y la tarjeta enseña la parte de la app que queda a la vista |
| CL-011-4 (selector parcial, bandeja, menú de apagado) | Selector parcial: **igual que la línea base** (no peor). Bandeja: sin comparación posible. Apagado: **no verificado** | La bandeja de notificaciones de este emulador es opaca (cubre toda la pantalla y no deja ver la app); el menú de apagado, ver el incidente de arriba |
| CL-011-5 y CL-011-9 | No verificables aquí | API 26/32 (PD-10) y Xiaomi (T-011-07) |
| CL-011-6 (gesto de cambio entre apps) | **FALLA la [Suposición]** (H-2) | Durante el gesto se ve la ventana **en vivo** de la app deslizándose, con contenido; misma causa que CL-011-14 |
| CL-011-10 (bloqueo y desbloqueo) | **Pasa** | 5 ciclos: al desbloquear, la misma pantalla; tarjeta en blanco después |
| CL-011-11 (teclado y texto) | **Pasa** | Tarjeta en blanco; al volver, el texto y el cursor siguen. El teclado **no reaparece**, igual que en la línea base (`mInputShown=false` en las dos) |
| CL-011-12 (girar en segundo plano con PDF) | **Pasa** | Con el PDF en horizontal (`emu rotate`): la tarjeta sigue en blanco y al volver la app se dibuja en horizontal con el PDF, en dos giros distintos |
| CL-011-14 (ruta directa) | Sin cambios | Ya medido en T-011-01 |
| (e) TalkBack en la tarjeta | **Pasa** | Lee "Una.. 4 of 4": solo el nombre de la app; el árbol de accesibilidad de la tarjeta no lleva el texto de la tarea |
| (e) Lupa del sistema | **No verificado** | No se pudo activar por `adb` de forma razonable (H-5) |

### 3.2 Matriz CA-011-02 (a)

Cada fila, con A ("uno" o su variante) y B ("dos"), captura de "Recientes" por el escritorio con `check-recents.sh capture` y `compare` (tarjetas idénticas píxel a píxel y parecido con la pantalla < 0,5; con esta versión de `compare` también se exige que se vea la tarjeta, ver §3.6). Tiras completas: `capturas/matriz-A.png` y `capturas/matriz-B.png` (arriba la pantalla, debajo la tarjeta).

| Fila | Parecido A / B | Tarjetas A y B (px distintos) |
|---|---|---|
| Bienvenida (con teclado; no hay A/B: dos capturas) | 0,000 / -0,009 | idénticas (0 %) |
| Tarea actual solo con texto | -0,005 / -0,001 | idénticas (0 %) |
| Con imagen | -0,066 / -0,055 | idénticas (0 %) |
| Con PDF | -0,082 / -0,085 | idénticas (0 %) |
| **Con web (fila propia; páginas reales cargadas)** | -0,024 / -0,018 | idénticas (0 %) |
| Menú | 0,039 / 0,040 | idénticas (0 %) |
| Listado | -0,010 / -0,010 | idénticas (0 %) |
| Hoja "Mover" | 0,010 / 0,010 | idénticas (0 %) |
| Editor con teclado y texto | 0,005 / 0,017 | idénticas (0 %) |
| Hoja de adjuntar | 0,028 / 0,028 | idénticas (0 %) |
| "Cargar URL" (con la dirección escrita) | 0,067 / 0,064 | idénticas (0 %) |
| Eliminar (hoja de confirmación) | 0,023 / 0,025 | idénticas (0 %) |
| "Todo hecho." | -0,009 / -0,009 | idénticas (0 %) |
| Error de almacenamiento | -0,008 / -0,008 | idénticas (0 %) |
| "Configuración y perfil", licencias, texto de una licencia, confirmación de enlace (spec 012) | no aplica todavía, spec 012 sin implementar | |

Cómo se provocó lo difícil, sin tocar el código de la app: el **error de almacenamiento** con la compilación *debug* (`invalid.pending.app.debug`, el mismo Kotlin) escribiendo basura en `app_flutter/una.sqlite` con `run-as` (sale "We couldn't open your tasks"; después se desinstaló el paquete de depuración); la **web** con las páginas públicas `https://www.google.com` y `https://www.wikipedia.org` (el emulador tiene salida a internet; `example.com` fallaba); "Todo hecho." completando todas las tareas (dos veces). La "hoja de colocación" ("¿Dónde va?") no está en la matriz de la spec y no se midió.

### 3.3 Vueltas y parpadeo (b): CA-011-03 y CA-011-08

Medición: `screenrecord` a mp4 (540 × 1200) durante la vuelta y lectura con `AVAssetReader` (fotogramas lisos: desviación < 3; blanco: media ≥ 235; negro: media < 60). **El emulador infla los tiempos** (carga del anfitrión y de la grabación): úsense solo para comparar con la línea base. Todas las vueltas parten de "Recientes" o del escritorio con una tarea de texto delante.

| Ruta de vuelta | 011 (final) | Línea base (sin la 011) |
|---|---|---|
| **Tocar la tarjeta en "Recientes"** (10 vueltas) | 9 sin fotograma liso; 1 con un único fotograma blanco liso de 0,04 s. Lo que se ve: la tarjeta blanca crece a pantalla completa (≈ 0,2-0,3 s) y la app aparece con un fundido (`capturas/vuelta-recientes-tira.png`) | 0 de 10 (la tarjeta enseña la instantánea) |
| `am start` desde el escritorio (10) | **10 de 10 con blanco liso, 0,44-0,95 s** (mediana 0,78 s) | 0 de 5 |
| Icono del lanzador (`monkey`, 5) | **4 de 5 con blanco liso, 0,79-1,25 s** (`capturas/vuelta-icono-tira.png`) | 0 de 5 |
| Desbloqueo (5 ciclos) | 2 grabaciones válidas, sin liso; las otras 3 salieron vacías (`screenrecord` no da fotogramas con el teclado de bloqueo) | — |
| `tools/check-recents.sh record 10` (proceso limpio, tarea de texto) | **PASA**: sin lisos que no sean blancos, sin pérdida de la app | — |

- **Negro: 0 fotogramas; otro color: 0** (el único liso es el blanco del fondo de arranque, `windowBackground` del `LaunchTheme`). **El blanco no dura claramente más de lo medido en T-011-01 (≈ 1 s)**: 0,44-1,25 s.
- **Precisión sobre la excepción (H-3):** la spec acepta el blanco "al volver desde Recientes". Medido, el blanco largo (0,4-1,25 s) sale **al volver con `am start` o con el icono**, es decir, cuando el sistema arranca la app sin instantánea; al **tocar la tarjeta** casi no hay fotograma liso porque el lanzador anima su propia tarjeta blanca. Es el mismo mecanismo, pero conviene que el propietario confirme que la excepción cubre también el icono y "otra app".
- **Reloj de 9:59 y 10:00 (CA-011-03):** `test/app/home_router_test.dart` ya probaba 9:00 (se conserva) y `UnaApp.resetAfter` = 10:00 (se descarta) en el test de CA-001-12, **pero no 9:59**. Se ha **añadido** el test `'CA-011-03: con el reloj inyectado a 9:59 …'` en ese archivo (9:59 conserva el borrador; 10:00 lo descarta y vuelve al editor). Pasa; no se ha cambiado ningún test existente.
- **Cámara y selector (CA-011-08):** 10 ciclos por cada uno (editor → (+) → "Hacer foto" / "Subir imagen" → escritorio → "Recientes" → tarjeta → atrás → editor): tras volver, la captura sale con contenido y sin `FLAG_SECURE` (10 de 10 en los dos). La tarjeta: con la **cámara**, la escena de la cámara (parecido -0,07 a -0,09 con el editor, ningún dibujo de la app); con el **selector de fotos**, la tarjeta enseña la app tras la hoja (H-1).

### 3.4 CA-011-04: capturas y grabaciones reales (c)

Con la app delante, en cada momento: **captura** (`screencap`) con contenido y **grabación** (`screenrecord`, 10-23 fotogramas con la interfaz moviéndose: menú u hoja de adjuntar abriéndose; primer y último fotograma con contenido, y en la de la cámara y la del selector, además, 0 fotogramas negros o blancos lisos); y `dumpsys window` sin `SECURE`:

- primer arranque en frío (`force-stop` + arranque): pasa;
- tras volver de "Recientes" (tocando la tarjeta): pasa;
- tras volver por el icono: pasa;
- tras la cámara y tras el selector de fotos (en el editor): pasa;
- **captura del propio sistema** (`KEYCODE_POWER` + `KEYCODE_VOLUME_DOWN`, que guarda en `Pictures/Screenshots`), hecha en el editor tras volver del selector: 1080 × 2400, con el editor completo (`capturas/captura-sistema.png`).

### 3.5 Casos límite (d): detalle

- **H-1, selector de fotos.** La hoja parcial del *Photo Picker* (`com.google.android.photopicker`) corre **dentro de la misma tarea** que la app, y la tarjeta de "Recientes" es la instantánea de la actividad de arriba (el selector, que no llama a `setRecentsScreenshotEnabled`), que incluye lo que hay debajo de la hoja: el logotipo, "Cancelar" y el color de fondo; con un **PDF adjunto en el editor se ve la parte alta de la vista previa con su nombre de archivo** (`pdf_uno.pdf`). Con un texto en el campo no se vio (el campo queda tapado por la hoja o, sobre el fondo oscuro, ilegible). **La línea base enseña exactamente lo mismo** (`capturas/selector-parcial.png`, a la izquierda con la 011 y a la derecha sin ella), así que **no es peor que hoy** (CL-011-4), pero **CL-011-3 esperaba "Recientes no muestra su contenido"** y aquí lo muestra en parte.
- **CL-011-3, cámara y archivos:** la cámara (`camera2`) y el selector de archivos (`documentsui`) son pantallas completas: la tarjeta enseña la escena de la cámara y la lista de `Descargas` (`capturas/camara-archivos-giro.png`). No es contenido de la app, pero el selector de archivos muestra nombres de archivos del usuario (fuera de alcance, CL-011-8).
- **H-2, gesto de cambio rápido (CL-011-6):** deslizando por el borde inferior con otra app en la lista, la app **sigue viva y visible** mientras se desliza hacia un lado, con "seis" y el botón (`capturas/gesto-cambio-tira.png`). La [Suposición] de la spec ("la tarjeta durante el gesto tampoco muestra contenido") **no se cumple**; es el mismo comportamiento que CL-011-14 (ventana en vivo, sin instantánea) y dura lo que dura el gesto.
- **CL-011-12:** con el PDF en la tarea, al girar el emulador (`adb emu rotate`) con la app en segundo plano y volver, la tarjeta sigue en blanco (con la franja negra en el lado del giro) y la app vuelve en horizontal con el PDF (`capturas/camara-archivos-giro.png`, tercera).

### 3.6 TalkBack y lupa (e)

- **TalkBack** (servicio `com.google.android.marvin.talkback` activado con `settings put secure`; el panel de subtítulos de TalkBack sale en las capturas): en "Recientes", con la tarea "SECRETO-UNO" delante, el foco llega a la tarjeta de la app y **dice "Una.. 4 of 4"** (`capturas/talkback-recientes.png`). En el árbol de accesibilidad (`uiautomator dump`) la tarjeta solo lleva `content-desc="Una."`; **no hay ni rastro de "SECRETO-UNO"**. Después se desactivó TalkBack y se restauraron los ajustes.
- **Lupa del sistema (H-5):** no se pudo activar la ampliación (triple toque con `input tap` y con `emu event send`, y el atajo de dos teclas de volumen) por `adb`; `dumpsys accessibility` seguía en `activated: false`. **[Pendiente]** comprobarla a mano (en el emulador con ratón/teclado, o en el móvil con permiso). **[Suposición]**, no verificada: sigue funcionando porque con la app delante la ventana no lleva `FLAG_SECURE` (`dumpsys window` en cada captura de §3.2 y §3.4).

### 3.7 Hallazgos fuera de la 011

- **H-4, pantalla en negro tras un WebView (emulador; ya está en la línea base).** Si en el proceso se ha **mostrado una tarea web** y luego se muestra otra pantalla (p. ej. se crea o se elige una tarea de texto), el siguiente paso a segundo plano y vuelta deja la app **en negro para siempre** (el árbol de accesibilidad sigue bien, la captura sale negra) hasta que el proceso muere. `logcat`: `EGL_BAD_ACCESS: context ... current to another thread` y `Could not make the context current to acquire the frame` (Impeller sobre `gfxstream`). **Se reproduce igual con la línea base** (sin la 011), así que **no la causa la 011**. **[Suposición]** es un fallo de esta combinación emulador + WebView + Impeller/GLES; no se ha visto en el móvil. Conviene mirarlo aparte (¿TD nuevo?) y, si se puede, comprobarlo en el Xiaomi con permiso. Las mediciones de arriba se hicieron en procesos limpios (`force-stop` tras usar la web).

### 3.8 Cambios en `tools/check-recents.sh` durante esta tarea

- `RECENTS_WAIT=<segundos>` (por defecto 2,5): con una imagen o un PDF el lanzador tarda más en pintar la tarjeta y la captura salía **sin tarjeta** (solo el fondo del lanzador).
- `compare` falla si en una captura no se ve una tarjeta clara (`cardlight`: media > 200 en su interior): antes dos capturas sin tarjeta salían "idénticas" y daban un falso "pasa".

## 3b. Comprobación de T-011-02 (versión definitiva, API 37)

Compilación *release* con el `RecentsPrivacy.kt` definitivo (A en `SDK_INT >= 33`), emulador `emulator-5554`. La verificación completa es T-011-03.

- [x] `capture uno`, `capture dos`, `compare uno dos` (por el escritorio): PASA (parecido -0,002 y -0,005; tarjetas idénticas).
- [x] `secure`: sin `FLAG_SECURE` con la app delante; la captura sale con contenido.
- [x] `loop 3`: PASA. `record 4`: PASA (blanco aceptado en 2 de 4 vueltas; ningún negro ni pérdida).
- [x] `VIA=direct loop 1`: parecido 0,966, informativo (CL-011-14), sin fallo.

## 3c. T-011-05: sin datos, permisos ni dependencias; otras plataformas (2026-09-30)

**Entorno.** `HEAD` = `d57c10a` (rama `feat/011-ocultar-recientes`, árbol limpio); línea base = `main` (`725e97c`), sacada con `git archive` a un directorio temporal (el árbol no se toca). `fvm` no está instalado: se usa el `flutter` del sistema, que **coincide** con `.fvmrc`: `flutter --version` = 3.47.5 (stable, Dart 3.13.4) y `git -C ~/development/flutter rev-parse HEAD` = `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`, igual que la línea de 3.47.5 en `tools/flutter-sdk.lock`. Emulador `emulator-5554` (API 37); el Xiaomi no estaba conectado ni se tocó.

### CA-011-06: permisos, red, esquema, dependencias, archivos

- [x] **Permisos.** `flutter build apk --release --target-platform android-arm64` y `tools/check-android-permissions.sh release` (desde `app/`): `Permisos de release correctos (2 revisados ...)`, salida 0. `aapt2 dump permissions` de la *release* de HEAD y de la de `main`: **idéntico** (`INTERNET`, y el permiso interno `invalid.pending.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` de androidx). Sin red nueva: el diff no toca manifiesto ni Dart de `lib/`.
- [x] **Diff.** `git diff --name-only main...HEAD | grep -E 'pubspec|drift_schemas|schemaVersion'` no da nada (`pubspec.yaml`, `pubspec.lock` y `drift_schemas/` sin cambios). `git diff main HEAD --name-only -- app/` solo lista `MainActivity.kt`, `RecentsPrivacy.kt` y `test/app/home_router_test.dart` (test de CA-011-03); `AppDatabase.schemaVersion` sigue en 2. Tras `flutter test` y `flutter build web`, `git status` sigue limpio (`pubspec.lock` no se toca).
- [x] **Sin archivos nuevos (`run-as`).** La *release* no es depurable, así que se usa la compilación **debug** (`invalid.pending.app.debug`, el mismo Kotlin), de HEAD y de `main`, instalada desde cero (`uninstall` + `install -r`) en el emulador: se lista el almacenamiento de la app (`run-as ... find .`) **antes** del primer arranque y **después** de arrancar, ir al escritorio (`KEYCODE_HOME`: pasa por `onPause` con el mecanismo A) y esperar 2 s. Antes: `.`, `cache`, `code_cache` (idéntico en las dos). Después, **17 entradas en las dos compilaciones y listas idénticas** (`diff` sin diferencias, salvo el sufijo de fecha de `res_timestamp-*`): `app_flutter/{flutter_assets/{isolate_snapshot_data,kernel_blob.bin,vm_snapshot_data},res_timestamp-*,una.sqlite}`, `code_cache/flutter_engine/.../skia/.../sksl`, `files/profileInstalled`. `files/` contiene solo `profileInstalled` (24 bytes, lo crea androidx, también en la línea base). Es decir, la 011 **no crea ningún archivo** respecto de la línea base. Después se desinstaló el paquete `.debug`.
- **Alcance de la comparación.** `run-as` solo ve el almacenamiento interno; no se comparó el almacenamiento externo (la app no lo usa) ni el contenido de `una.sqlite` (sin cambios de esquema; `schemaVersion` = 2). **[Suposición]** suficiente para "ningún archivo nuevo en el almacenamiento".

### CA-011-07: otras plataformas

- [x] `dart format lib test integration_test`: 277 archivos, 0 cambios. `flutter analyze --fatal-infos`: `No issues found!`.
- [x] `flutter test` (completo): `+1207 ~49: All tests passed!` (49 omitidos, los de siempre).
- [x] `flutter build web`: `Built build/web`, sin errores. Solo el aviso ya conocido de la herramienta sobre las fuentes de iconos (`Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)...`), que no viene de esta rama (no hay cambios en `lib/` ni en `pubspec.yaml`).
- **Nada de Dart de la app cambia** en la rama (solo un test), y el código nativo Kotlin no se compila en la web ni en iOS. **[Suposición]** iOS no se compila (D17: sin Xcode); no aplica en la beta.

## 4. Estado en que queda el árbol

- `app/android/app/src/main/kotlin/invalid/pending/app/RecentsPrivacy.kt` es **definitivo** (T-011-02): A si `SDK_INT >= 33`, B si `< 33`; sin `MODE`.
- `MainActivity.kt` llama a `RecentsPrivacy` en `onCreate`, `onPause` y `onResume`.
- T-011-03 no toca el código de la app: solo `tools/check-recents.sh` (§3.8), un test en `app/test/app/home_router_test.dart` (§3.3) y este archivo con sus capturas.
- El emulador queda con la compilación *release* de `4e30a1b` instalada (arm64) y tareas de prueba (datos de desarrollo); el paquete `.debug` se desinstaló y TalkBack y la lupa, desactivados.
