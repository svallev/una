# Spec 011: pruebas en el dispositivo

Guía y resultados de la verificación con `adb` (plan §5). Todo en el **emulador de Android 16 (API 37)**; nunca en el Xiaomi sin permiso del propietario. Las capturas están en `capturas/` (reducidas; solo las tareas de prueba "uno" y "dos", sin datos privados).

## 0. Cómo se usa el script

```bash
# El serial es obligatorio. Un serial que no sea "emulator-*" es un dispositivo físico:
# solo con permiso explícito del propietario. `secure` exige ALLOW_PHYSICAL=1; capture,
# compare, loop y record exigen además ALLOW_PHYSICAL_SCREENSHOTS=1 (capturan "Recientes"
# entera, con las demás apps del propietario a la vista).
S=emulator-5554
D=$(mktemp -d)                                    # opcional: sin directorio el script crea uno y lo imprime
tools/check-recents.sh $S capture uno $D          # con la tarea A ("uno") en pantalla
# (cambiar a la tarea B, "dos", y repetir)
tools/check-recents.sh $S capture dos $D
tools/check-recents.sh $S compare uno dos $D      # CA-011-01: falla si enseña contenido, no es lisa o A y B difieren
tools/check-recents.sh $S secure                  # CA-011-04: sin FLAG_SECURE con la app delante ("unknown" también falla)
tools/check-recents.sh $S loop 10                 # CA-011-08 (sin cámara ni selector)
tools/check-recents.sh $S record 10               # parpadeo (CA-011-03), con tiras de fotogramas
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
3. **Al volver desde "Recientes" se ve un fotograma blanco a pantalla completa** con la instantánea vacía, antes de que la app se dibuje (`A-vuelta-tira.png`, `B-vuelta-tira.png`: el fotograma liso, entre "Recientes" y la app). Con la app sin ocultar no ocurre. Con mp4 el fotograma blanco dura ≈ 1,0–1,1 s en las dos vueltas en que se ve (13,504 → 14,610 s y 30,191 → 31,181 s en A); **[Suposición]** el valor está inflado por la carga de la grabación en el emulador. **[Corregido 2026-09-30, §6]** Aquí se suponía que el blanco coincidía con el `windowBackground` del `LaunchTheme` (`launch_background.xml`). Medido después (§6, 40 vueltas), el blanco es **igual en modo claro y en modo oscuro** (con `Theme.Black` sería negro), así que **no sale de `launch_background`**: es lo que el sistema pinta cuando no hay instantánea (mecanismo A). **[Suposición]** (no se puede mirar el código del sistema desde aquí; es lo que cuadra con las medidas).
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

- **Negro: 0 fotogramas; otro color: 0** (el único liso es el blanco que pinta el sistema cuando no hay instantánea; **no** es el `windowBackground` del `LaunchTheme`, ver §6). **El blanco no dura claramente más de lo medido en T-011-01 (≈ 1 s)**: 0,44-1,25 s.
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

## 5. T-011-07: Xiaomi / HyperOS (CL-011-9, R-5)

**Estado: hecha en parte (2026-09-30, con el permiso del propietario, desde la sesión coordinadora).** Resultados en §5.11. Los pasos de abajo se escribieron antes y se siguen con estas salvedades: no se hizo la parte de cámara y selector (CL-011-3, CL-011-15), no se midió la duración del blanco al volver ni se probó la captura del propio Xiaomi (volumen + encendido), y se sustituyó "a mano" por `adb` + medición numérica para no guardar capturas de "Recientes".

**Qué se comprueba.** Que el lanzador de HyperOS respeta la señal que le da la app y no enseña el contenido en "Recientes" (CA-011-01, CL-011-9), que las capturas con la app delante siguen saliendo con contenido (CA-011-04) y que la vuelta no es peor que la medida en el emulador (CA-011-03). El Xiaomi 15T Pro lleva Android 16 (API 36): usa el **mecanismo A** (`setRecentsScreenshotEnabled`); el B (Android 8-12) no se puede probar aquí (PD-10). **[Suposición]** HyperOS puede tratar la señal a su manera; si la ignora, ver "Criterio de parada".

### 5.1 Reglas antes de empezar (privacidad)

- **Solo con el permiso explícito del propietario y con el móvil libre** (él no lo está usando). Avisar antes de cada instalación y de cada bucle de arranques: le sacan de lo que esté haciendo.
- **"Recientes" enseña las tarjetas de sus otras apps** (WhatsApp, banco...). Por eso:
  - **No se captura "Recientes" con el lanzador mostrando otras apps sin avisar.** Antes de mirar, el propietario deja en "Recientes" **solo la tarjeta de esta app** (cierra las demás él mismo, con el botón de cerrar todo o deslizándolas) o, si no quiere cerrarlas, la captura se **recorta a la tarjeta de la app**.
  - La captura de "Recientes" solo se toma con la tarjeta de la app **como única visible** o **recortada a ella**. **No se guarda en el repo** ni se copia al ordenador si se ve algo más; basta con **describir** lo que se ve (§5.8).
  - Con `adb`: nada de `screencap` sin comprobar antes `adb shell dumpsys window | grep mCurrentFocus` y sin el "sí" del propietario; el archivo se borra al terminar. `tools/check-recents.sh` **no** se usa en el Xiaomi para `capture`, `compare`, `loop` ni `record` (capturan "Recientes" entera y roban el foco; el script los rechaza sin `ALLOW_PHYSICAL_SCREENSHOTS=1`, que no se pone aquí); solo `secure` (lee `dumpsys`, no captura nada) y solo con `ALLOW_PHYSICAL=1`.
- Las capturas de la app con datos de prueba ("uno", "dos") no son privadas, pero **tampoco van al repo**: los resultados se anotan como texto en esta sección.

### 5.2 Instalar (sin `flutter drive`)

`flutter drive` **desinstala el paquete base** (`invalid.pending.app`, la app real del propietario) al terminar y le borraría sus tareas: **no se usa**. Se instala un APK ya compilado con `adb install`.

Opción recomendada, **sin tocar la app real**: la compilación *profile*, que es otro paquete (`invalid.pending.app.profile`, datos aparte) y lleva el mismo Kotlin de `RecentsPrivacy`:

```bash
cd app && flutter build apk --profile --target-platform android-arm64
S=<serial-xiaomi>                       # solo con permiso del propietario (adb devices)
adb -s $S install -r build/app/outputs/flutter-apk/app-profile.apk
```

- Si `.profile` ya estaba instalada como APK partido por ABI (`versionCode` 2001), el `install -r` falla con `INSTALL_FAILED_VERSION_DOWNGRADE`: `adb -s $S uninstall invalid.pending.app.profile` (**solo ese paquete**) y repetir.
- HyperOS: hace falta "Instalar vía USB" activado y **aceptar el aviso en el móvil**; si no, `INSTALL_FAILED_USER_RESTRICTED`. Si el USB se corta, reconectar y reintentar.
- Alternativa (la *release* que pide la spec): `flutter build apk --release --target-platform android-arm64` e `install -r` del APK, que **actualiza la app real** (mismo paquete, sus datos se conservan). Solo si el propietario lo pide; las tareas "uno" y "dos" quedan entonces en su lista y hay que borrarlas al terminar. **Nunca `adb uninstall invalid.pending.app`.**

- [ ] Instalada (paquete: `______`), abre y muestra la tarea actual o la bienvenida.

### 5.3 Preparar las tareas A y B

- [ ] Crear la tarea **A** con el texto `uno` y la tarea **B** con el texto `dos`. Se alterna entre ellas con "Todas mis tareas" o completando la actual, dejando delante la que toque.
- Opcional (mismo procedimiento, solo si hay tiempo; la vista web se dibuja por separado): A y B **con imagen** y **con web** (`https://www.wikipedia.org` y `https://www.google.com`), como en §3.2.

### 5.4 CA-011-01 y CL-011-9: la tarjeta de "Recientes"

Ruta de la spec: **ir antes al escritorio y luego abrir "Recientes"** (botón/gesto de inicio y luego el gesto o botón de "Recientes" del propietario). Abrir "Recientes" directamente desde la app queda fuera del criterio (§5.6).

1. Con la tarea **A ("uno")** delante: inicio (escritorio), esperar 2 s, abrir "Recientes". Mirar **solo la tarjeta de la app** (§5.1).
2. Volver a la app con el icono, poner delante la tarea **B ("dos")** y repetir.

| Comprobación | A ("uno") | B ("dos") |
|---|---|---|
| La tarjeta **no enseña nada del contenido** (ni texto, ni logotipo, ni botones) | [ ] sí [ ] no | [ ] sí [ ] no |
| Qué se ve en su lugar (fondo liso, icono, en blanco, la tarea...) | | |
| Se ve el icono y el nombre de la app (CA-010-05) | [ ] sí [ ] no | [ ] sí [ ] no |
| La tarjeta de A es **igual** a la de B | [ ] sí [ ] no (una sola casilla) | |

- [ ] **CL-011-9:** el lanzador de HyperOS **respeta la señal** (tarjeta sin contenido). Si el lanzador **no muestra miniaturas por sí mismo** (solo icono y nombre), también vale: "si no hay miniatura, no hay nada que ocultar" (anotarlo).
- Si el lanzador enseña "uno" o "dos", o A y B difieren: **criterio de parada** (§5.9).

### 5.5 CA-011-04, CA-011-03 y CA-011-08: capturas, vuelta y ciclo (10 vueltas)

Repetir **10 veces**, con una tarea de texto delante (la spec pide 10; si el propietario prefiere menos, se anota cuántas):

1. Inicio (escritorio) → abrir "Recientes" (§5.4) → **tocar la tarjeta** de la app para volver.
2. Fijarse en la vuelta (**CA-011-03**): ¿se ve un instante en **blanco liso** antes de la app? ¿Es **negro** o de otro color en algún momento? Calcular a ojo cuánto dura (referencia medida en el emulador, inflada: 0,4-1,25 s con el icono o `am start`; casi nada al tocar la tarjeta).
3. Con la app ya delante, hacer una **captura de pantalla del sistema** (la del propio Xiaomi, p. ej. volumen abajo + encendido) y comprobar en la galería que **sale con "uno" o "dos" visible**, no en negro y sin aviso de que la app lo impide (**CA-011-04**). Repetir además una vez con la **grabación de pantalla del sistema** (unos segundos, moviendo el menú): sale con contenido.

| Comprobación | Resultado |
|---|---|
| Vueltas hechas (de 10) | ___ |
| Tarjeta sin contenido en las 10 (CA-011-08) | [ ] sí [ ] no (cuántas fallan: ___) |
| Captura con contenido en las 10 (CA-011-04) | [ ] sí [ ] no (cuántas salen en negro: ___) |
| Grabación con contenido (CA-011-04) | [ ] sí [ ] no |
| Fotograma **negro** o de otro color al volver (CA-011-03) | [ ] ninguno [ ] sí: ______ |
| Blanco liso al volver tocando la tarjeta | [ ] no [ ] a veces [ ] siempre; duración a ojo: ___ s |
| Blanco liso al volver con el **icono** de la app (5 veces) | [ ] no [ ] a veces [ ] siempre; duración a ojo: ___ s |
| Se conserva la pantalla si pasaron < 10 min (CA-001-12) | [ ] sí [ ] no |

- CA-011-04 también **en el primer arranque en frío** (cerrar la app del todo desde "Recientes" y abrirla): captura con contenido. [ ] sí [ ] no

### 5.6 CL-011-14: "Recientes" abierto desde la propia app (solo informativo)

- [ ] Con la app delante, abrir "Recientes" **sin pasar por el escritorio**: anotar si la tarjeta enseña la app en vivo (como en el emulador, aceptado) o no. **No es criterio**; solo se anota: ______

### 5.7 CL-011-3: cámara y selector

Con el editor de una tarea abierto y "uno" escrito:

1. (+) → **"Hacer foto"** (cámara del Xiaomi): con la cámara abierta, ir al escritorio y abrir "Recientes" (§5.1). Anotar qué enseña la tarjeta (**esperado:** la escena de la cámara, nada de la app). Volver por la tarjeta, hacer la foto o cancelar: el editor sigue igual y una captura con la app delante sale con contenido (CA-011-04).
2. (+) → **"Subir imagen"** (selector de fotos): con el selector abierto, ir al escritorio y abrir "Recientes". Anotar qué enseña la tarjeta. **Si es una hoja parcial sobre la app, puede verse lo que queda de la app a la vista (CL-011-15, aceptado, igual que antes de la 011)**; si el selector es a pantalla completa, no debería verse nada de la app. Volver y comprobar la captura con la app delante.

| Comprobación | Cámara | Selector |
|---|---|---|
| La tarjeta enseña | | |
| Contenido de la app visible en la tarjeta | [ ] no [ ] sí: ______ | [ ] no [ ] sí: ______ |
| Tras volver, el editor sigue igual y la captura sale con contenido | [ ] sí [ ] no | [ ] sí [ ] no |
| Ciclos hechos (la spec pide 10 por cada uno) | ___ | ___ |

**[Suposición]** el selector de fotos de HyperOS puede ser el de Google o el de la galería de Xiaomi; anotar cuál es. Si enseña más de lo que enseña hoy la app sin la 011, no se puede saber sin la línea base en el Xiaomi: anotarlo y **preguntar** en vez de dar por bueno.

### 5.8 Qué anotar y qué NO guardar

**Anotar** (texto, en esta sección o en la fila de `tasks.md`): fecha, paquete instalado (`.profile` o base), versión de HyperOS (`adb shell getprop ro.mi.os.version.name` o Ajustes), cómo se abre "Recientes" (botones o gestos), qué muestra el lanzador en lugar del contenido, las casillas de arriba, y cualquier fallo.

**NO guardar** (ni en el repo ni en `capturas/`):
- Capturas o grabaciones de "Recientes" con otras apps visibles, ni recortes en los que asome algo que no sea la tarjeta de esta app.
- Capturas de la galería, del selector de fotos o del selector de archivos (pueden traer fotos y nombres de archivo del propietario).
- Cualquier `adb pull` de `Pictures/Screenshots`, `DCIM` o `Movies` del móvil. Si hace falta enseñar algo, el propietario lo **recorta a la tarjeta** y decide él si lo comparte; por defecto se **describe con palabras**.
- Si se hizo una captura por `adb` sin querer y sale algo privado: se **borra al momento** y se le avisa.

### 5.9 Criterio de parada

**Parar y preguntar al propietario** (no reinterpretar la spec ni seguir con el resto) si:

- El lanzador **ignora la señal**: la tarjeta de "Recientes" enseña "uno" o "dos", cualquier parte del contenido, o A y B se ven distintas (CA-011-01 falla en Android 13+; regla de desempate de la spec). Recomendación a proponer: probar el mecanismo B (`FLAG_SECURE` en `onPause`) también en 13+ (alternativa preparada, riesgo R-2/R-5) antes de decidir; requiere una tarea nueva y otra pasada por el Xiaomi.
- La captura o la grabación con la app delante salen **en negro** o con un aviso de que la app lo impide (CA-011-04).
- El fotograma al volver es **negro**, de otro color o dura **claramente más** de lo medido (más de ~1,5 s a ojo) (CA-011-03).
- La tarjeta se queda con la app "congelada" o aparece el contenido tras volver a "Recientes" varias veces (CL-011-13).

Lo demás (CL-011-14, hoja parcial del selector, blanco corto al volver) son límites ya aceptados por el propietario (2026-09-30): se anotan y no paran.

### 5.10 Al terminar

- [ ] `adb -s $S uninstall invalid.pending.app.profile` (**solo** `.profile`; si se instaló la *release* sobre la real, borrar a mano las tareas "uno" y "dos").
- [ ] Borrar de la galería y de `/sdcard` las capturas y grabaciones de prueba, y de `/tmp` o del directorio de la sesión cualquier archivo que se haya copiado.
- [ ] Anotar el resultado en la fila T-011-07 de `tasks.md` y cerrar CL-011-9 (respeta / no muestra miniaturas / falla y se paró).

### 5.11 Resultados en el Xiaomi (2026-09-30) [Hecho, salvo lo indicado]

**Entorno.** Xiaomi 15T Pro (`2506BPN68G`), Android 16 (API 36), HyperOS `OS3.0`, navegación por gestos. Paquete `invalid.pending.app.profile` (compilación *profile* de `891825a`, arm64; datos aparte de la app real, que **no se tocó**); mecanismo **A**. El propietario dejó el móvil libre y sin más tarjetas en "Recientes". Se creó "uno" y "dos" (la de "dos" pasó a ser la actual). Al terminar: `adb uninstall invalid.pending.app.profile` (solo ese paquete), sin restos míos en `/sdcard`, sin capturas ni grabaciones en el repo.

| Comprobación | Resultado |
|---|---|
| **CA-011-01, CL-011-9** (escritorio → "Recientes" con `KEYCODE_HOME` y `KEYCODE_APP_SWITCH`) | **El lanzador de HyperOS respeta la señal.** Tarjeta "Una." sin contenido: fondo **blanco** liso con la franja negra de arriba, **igual que en el emulador**. Con "uno" delante se miró a ojo; con "dos", las 10 veces, se midió (zona interior de la tarjeta 100 % blanca, 0 % amarillo u oscuro). |
| **CA-011-08** (ciclo: escritorio → "Recientes" → tocar la tarjeta) | **10 de 10**: tarjeta en blanco y la app vuelve a delante con la tarea "dos" (comprobado por foco y por el árbol de accesibilidad). |
| **CA-011-04** (captura con la app delante) | **Pasa** con `screencap` de `adb` (que respeta `FLAG_SECURE`): sale con el contenido ("uno", "dos", el menú y el editor) en el uso normal y tras un **arranque en frío**; `dumpsys window` sin ventana segura de la app. **No se probó** la captura ni la grabación del propio sistema del Xiaomi (botones). |
| **CA-011-03** (vuelta sin parpadeo negro) | **Sin medir bien.** En los ciclos no se vio ningún fotograma negro en las capturas de la app; **la duración del blanco no se pudo medir**: el USB del Xiaomi se corta al grabar con `screenrecord` (la grabación de 2,8 s acabó antes de que apareciera la app). **[Suposición]** parecido al emulador. Queda a ojo del propietario. |
| **CL-011-3, CL-011-15** (cámara y selector) | **No hecho** en el Xiaomi (no se abrió la galería ni la cámara del propietario). Se mantiene lo del emulador. |
| **CL-011-14** (Recientes abierto desde la app) | No probado (informativo). |

**Incidencias de la sesión (no son de la app).** (1) El USB se cayó una decena de veces (HyperOS): hubo que reconectar y reintentar. (2) Muchos toques de `adb input tap` no llegaron en el primer intento; se repitieron comprobando el árbol de accesibilidad (`uiautomator dump`). (3) Un `screencap` a medio dibujar mostró el escritorio del propietario (iconos de aplicaciones): se borró en el acto. (4) `tools/check-recents.sh` no se usó (rechaza el móvil sin `ALLOW_PHYSICAL_SCREENSHOTS`, que no se puso).

## 6. T-011-08 previa: modo oscuro (2026-09-30)

**Por qué.** El `a11y-reviewer` señaló que el fondo de arranque usa `?android:colorBackground` (`res/drawable-v21/launch_background.xml`) y que `values-night/styles.xml` usa `Theme.Black`: con el sistema en modo oscuro el fotograma sin instantánea al volver podría ser **negro** (CA-011-03 manda parar y preguntar si lo es). Se mide antes de T-011-08.

**Entorno.** `emulator-5554` (API 37, arm64), compilación *release* de `4e30a1b` (la instalada tras T-011-04; `git diff main...HEAD -- app/android` solo toca `MainActivity.kt` y `RecentsPrivacy.kt`: **ningún recurso de arranque cambia**), tarea de texto delante ("SECRETO-UNO", datos de prueba). Estado original: `cmd uimode night` = `no` (`settings get secure ui_night_mode` = 1). Se cambió con `cmd uimode night yes` (`am get-config` con `night`) y **se restauró a `no` al terminar** (comprobado). El Xiaomi no estaba conectado ni se tocó.

**Método.** Distinto del de §3.3 en dos detalles (script de un solo uso, no incluido): `screenrecord` a mp4 (540 × 1200) leído con `AVAssetReader`, y "fotograma liso" = desviación < 3 en la **zona central** (15-85 % de alto y ancho) en vez de todo el cuerpo: con la zona completa un fotograma blanco no salía liso, porque la animación de vuelta enseña la barra negra de arriba, la píldora de gestos y bordes del lanzador (`tools/check-recents.sh record` tenía el mismo defecto y se corrigió, §6.2). Color = media RGB del fotograma liso; **duración = del primer fotograma liso al siguiente fotograma distinto** (el mp4 solo tiene fotogramas cuando la pantalla cambia). 5 vueltas por ruta y modo; cada vuelta parte del escritorio o de "Recientes".

### 6.1 Resultado

| Ruta de vuelta (proceso vivo, sin instantánea) | Modo claro: color y duración | Modo oscuro: color y duración |
|---|---|---|
| "Recientes" → `am start` | blanco liso **(255,255,255)**, 0,03-0,08 s (2-5 fotogramas) | blanco **(255,255,255)**, 0,03-0,10 s; 1 vuelta de 5 sin liso |
| Escritorio → `am start` | blanco **(255,255,255)**, 0,02-0,07 s (1-4) | blanco **(255,255,255)**, 0,01-0,08 s (1-5) |
| Escritorio → icono (`monkey`) | blanco **(255,255,255)**, 0,02-0,03 s (1-2) | blanco **(255,255,255)**, 0,03-0,10 s (2-6; uno de ellos (252,252,236)) |
| "Recientes" → tocar la tarjeta | blanco **(255,255,255)**, 0,10-0,12 s (6-7) | blanco **(255,255,255)**, 0,10-0,12 s (6-8) |
| `tools/check-recents.sh record 3` (ya corregido) | `blancos_aceptados` en las 3 vueltas, 0 lisos que fallen, 0 perdidos | no se repitió en oscuro |

- **Negro: 0 fotogramas. Otro color: 0** (en las 40 vueltas). **El fotograma liso al volver es BLANCO también en modo oscuro**, con el mismo color y duraciones parecidas: **no sale de `launch_background`** (con `Theme.Black` sería negro), sino de lo que el sistema pinta cuando no hay instantánea (la de "Recientes" desactivada por el mecanismo A). Esto **refuta la [Suposición]** de §2.3, del ADR-0019 y de la spec ("coincide con el `windowBackground` del `LaunchTheme`"). **[Hecho, decisión del propietario 2026-09-30]** se corrige en los tres sitios (§2.3, ADR-0019 y la frase de la excepción de CA-011-03 de la spec, con su visto bueno explícito para tocar solo esa frase) y en las frases que la repetían (`plan.md` §1, `architecture.md` (subsección "Recientes"), §3.3 de este archivo).
- **Duración:** 0,01-0,12 s, **muy por debajo** de los 0,4-1,25 s de §3.3. **[Suposición]** los de §3.3 estaban inflados por la carga del emulador en ese momento (se medía con compilaciones y grabaciones en marcha); ahora el emulador estaba en reposo. No se ha podido separar de un cambio de método (§ Método), aunque la zona central detecta al menos lo que detectaba el cuerpo entero.
- **Cuadro (no es la vuelta de la 011): arranque en frío (proceso muerto, `force-stop`), 3 veces por modo.** El sistema pinta su *splash* con el fondo de `launch_background.xml` y el icono de la app: en **modo claro, blanco** (≈ 0,3-0,4 s hasta el primer fotograma de Flutter); en **modo oscuro, NEGRO** (media ≈ 20 con el icono, 6 en el punto más oscuro; ≈ 0,5 s). Es **el mismo comportamiento que antes de la 011** (los recursos de arranque no se han tocado en la rama) y afecta a "volver a la app" solo cuando el sistema ha matado antes el proceso (CL-011-2). **[Hecho, decisión del propietario 2026-09-30]** el arranque en frío (proceso muerto) en modo oscuro es **negro ≈ 0,5 s**, igual que antes de la 011: **no cuenta** para el "negro" de CA-011-03 y **se aplaza a F5**, anotado en la auditoría de `docs/PLAN.md` junto a la mitigación de usar `paper` en `launch_background` (`docs/architecture.md` §2).
- **Veredicto de la medición previa:** en las rutas que introduce la 011 (proceso vivo, sin instantánea) el fotograma es **blanco en claro y en oscuro**; no hay que parar por eso. La salvedad es el arranque en frío en oscuro, anterior a la 011 y aplazado a F5 (decisión del propietario, arriba).

### 6.2 Endurecimiento de `tools/check-recents.sh` (mismo día)

Hallazgos bajos del `security-reviewer` sobre el script (T-011-08 sigue pendiente; ni la app ni la spec cambian):

- `capture`, `compare`, `loop` y `record` comprueban con `cardlight` que la tarjeta se ve y fallan si no; además, con `flat`, que su **interior es liso** (desviación típica <= 2 en la tarjeta sin el 12 % de arriba ni el 6 % de abajo y de los lados). Calibrado con las capturas guardadas en `capturas/` y las de la sesión (1080 × 2400): tarjeta vacía **0,00**; línea base (con contenido) 32-33; ruta directa 32; selector de fotos 76; cámara 91; giro 14. Con el 12 % de arriba incluido salía 5,2 en la tarjeta vacía (la barra negra del sistema); con el 6 % de márgenes anterior, también. Comprobado: A-escritorio y B-escritorio (guardadas) pasan; la línea base y la tarjeta directa fallan **aunque A y B sean idénticas** (antes salían "idénticas: bien"); en el emulador con la implementación actual pasan `capture`, `compare`, `loop 2` y `record 3`; con `CARD` mal puesto `loop` falla ("no se ve la tarjeta"). El umbral se cambia con `FLAT_MAX_STD`. Con `VIA=direct` solo informa (CL-011-14).
- `secure` imprime `unknown` y **falla** si no encuentra la ventana de la app en `dumpsys` (probado con `force-stop`); `capture` y `loop` también fallan si la ventana no aparece.
- Dispositivo físico: `secure` con `ALLOW_PHYSICAL=1`; el resto exige además `ALLOW_PHYSICAL_SCREENSHOTS=1` (mensaje sobre que capturan "Recientes" entera). Probado solo el rechazo con un serial ficticio (`FAKE123`); no se conectó nada al Xiaomi.
- Salida por defecto en un directorio de `mktemp -d`, impreso al terminar (`Capturas en: ...`); `compare` exige el directorio. Patrones de capturas sueltas en `.gitignore` sin excluir `capturas/` (`git check-ignore`: ninguna de las 21 versionadas queda ignorada).
- **Corrección de `record`:** el cálculo de fotogramas lisos usaba todo el cuerpo (10-100 %) y no contaba como liso un fotograma blanco con la píldora de gestos; ahora usa la zona central (15-85 %). Antes `record` daba a veces `blancos_aceptados=[]` con blancos visibles en la tira; ahora los cuenta (`[8]` en las 3 vueltas).

## 7. T-011-08: cierre (2026-09-30)

Hecho desde la rama `feat/011-ocultar-recientes` (HEAD antes de esta tarea: `8f0dfe0`). No se ha tocado la app (`app/lib`, Kotlin), ni dependencias, ni ningún dispositivo físico; el emulador no se ha usado en esta tarea. Los revisores `security-reviewer` y `a11y-reviewer` ya pasaron antes (0 altos; sus correcciones son §6); aquí se anotan `/security-check`, `/i18n-check`, la tabla CA → prueba y las comprobaciones de código.

### 7.1 `/security-check` (a mano, siguiendo `.claude/skills/security-check/SKILL.md`)

**Alcance.** `git diff main...HEAD`: Kotlin (`MainActivity.kt` +8, `RecentsPrivacy.kt` nuevo), un test de Dart, `tools/check-recents.sh`, `.gitignore`, documentación y las capturas de `capturas/` (21 PNG reducidos con las tareas "uno" y "dos"). La rama arrastra además el commit `9e215b3` de la spec 012 (spec y borrador de la política de privacidad, solo documentación); no es de la 011. Sin cambios en `app/lib`, ARB, `pubspec.yaml`, `pubspec.lock`, `drift_schemas/`, manifiestos, `.github/`, `.mcp.json` ni `skills-lock.json`. Superficie: **nativo (T-8)** y **fugas laterales (T-2)**, que cierra. No hay T-3 a T-6 ni T-10 a T-13: no hacía falta lanzar de nuevo `security-reviewer` (ya revisó el diff y el ADR, 0 altos).

| Punto | Resultado | Evidencia |
|---|---|---|
| Sin secretos, claves ni archivos de firma | ✅ | `git diff main...HEAD \| grep -nE '(api[_-]?key\|secret\|token\|password\|BEGIN ... PRIVATE KEY)'` (sin las capturas): solo coincidencias de prosa en docs (specs 011/012, política de privacidad: "token" de diseño, "passwords" de la WebView); ninguna en código. `git ls-files \| grep -E '\.(jks\|keystore\|p8\|p12\|pem\|mobileprovision)$\|key\.properties\|\.env$'`: vacío |
| Sin logs de contenido | ✅ | `RecentsPrivacy.kt` (38 líneas) no registra nada y no lee contenido |
| Sin red nueva | ✅ | Ningún cambio en `app/lib` ni en el manifiesto; `tools/check-recents.sh` solo usa `adb` local (`grep -nE 'curl\|wget\|nc \|ssh\|rm -rf\|eval \|sudo'` sin resultados) |
| Sin permisos nuevos | ✅ | Sin diff de manifiestos; `check-android-permissions.sh release` en verde y `aapt2 dump permissions` idéntico al de `main` (§3c) |
| Entradas validadas (10 000 caracteres) | N/A | Sin entradas de usuario nuevas |
| Dependencias (T-10) | N/A | Sin diff de `pubspec.yaml` ni `pubspec.lock`; sin dependencias de Gradle |
| Importación, URL y WebView, almacenamiento y esquema | N/A | No se toca. Riesgo R-4 (`FLAG_SECURE` en B y WebView): solo puesta en pausa; la fila "web" de la matriz pasa con A en API 37; B sin verificar (PD-10). Sin archivos nuevos (`run-as`, §3c) |
| Integración nativa (T-8) | ✅ | Ningún componente exportado ni esquema de URL nuevos; `MainActivity` sigue igual salvo tres llamadas |
| "Recientes" (checklist, sección propia) | ✅ en API 37; **[Pendiente]** lo demás | Punto 1 ✅ (A en 13+; sin `FLAG_SECURE` fija; matriz de 14 filas). Punto 2 (pasar `tools/check-recents.sh` antes de cada entrega a testers) **[Pendiente]**: se hace al entregar; ya está en `/release-checklist`. Punto 3 (Android 8 y 12L) **[Pendiente, PD-10]**. Punto 4: los límites están documentados; **[Pendiente]** copiarlos a las notas de la beta |
| CI, workflows, web | N/A | Sin cambios; solo `.gitignore` (patrones de capturas sueltas, sin excluir `capturas/`) |
| Skills, plugins y MCP | ✅ | Ninguno nuevo. Solo cambia el texto de una skill propia, `.claude/skills/release-checklist/SKILL.md` (un paso más), sin contenido de terceros ni instalación |

**Resultado: sin hallazgos que fallen.**

### 7.2 `/i18n-check` (a mano, siguiendo `.claude/skills/i18n-check/SKILL.md`)

| Paso | Resultado |
|---|---|
| Claves ES y EN | ✅ 152 y 152 claves, `set()` de diferencias, ningún valor vacío. **La 011 no toca las ARB** (`git diff main...HEAD --name-only -- '*.arb' app/lib` da 0 archivos) |
| Plurales, fechas y números | N/A (sin textos ni fechas nuevos) |
| Textos incrustados | ✅ Sin cambios en `app/lib`. La búsqueda de la skill da un único resultado, `placement_sheet.dart:139` (`label: '${widget.title}. ${widget.hint}'`), que interpola dos textos ya traducidos y **no viene de esta rama**. El nombre de la app solo sale de `app_identity.g.dart` (generado desde `identity.yaml`); la otra coincidencia de "Una" es el artículo español de `attachUrlHint` |
| Specs ↔ ARB | ✅ La spec 011 §7 dice "Ninguno nuevo" y no hay claves nuevas |
| Glosario | ✅ El término **Recientes / Recents (app switcher)** ya está en `docs/glossary.md` (`recents`); la spec y los documentos lo usan tal cual |
| Resolución de idioma | ✅ Existen `test/app/locale_resolution_test.dart`, `locale_change_test.dart` y `test/l10n/semantics_language_test.dart` (spec 010); pasan dentro del `flutter test` completo |

**Resultado: confirmado que la 011 no añade ni cambia ningún texto.** (La lectura de la tarjeta de "Recientes" por TalkBack usa el nombre de la app de `identity.yaml`, sin texto propio.)

### 7.3 Comprobaciones de código (desde `app/`, sistema, sin `fvm`)

- `dart format lib test integration_test`: 277 archivos, **0 cambios**.
- `flutter analyze --fatal-infos`: **No issues found!**
- `flutter test` (completo): **+1207 ~49: All tests passed!** (49 omitidos, los de siempre).
- `node tools/validate-tokens.mjs`: `tokens.json válido (28 combinaciones de contraste AA comprobadas)`.

### 7.4 Tabla CA → prueba

Entornos: **Emu** = emulador `Pixel_6a`, Android 16 (API 37), `emulator-5554`; **Xiaomi** = Xiaomi 15T Pro, Android 16 (API 36), HyperOS OS3.0, paquete `.profile` (T-011-07, en parte); **test** = `flutter test`; **adb** = `tools/check-recents.sh` y comandos de `adb`/`dumpsys`. **API 26 y 32 no se han probado nunca (PD-10, T-011-09)**, así que todo lo que dependa del mecanismo B (Android 8-12) sigue siendo **[Suposición]**.

| CA | Qué se verificó | Dónde / cómo | Sin verificar |
|---|---|---|---|
| **CA-011-01** sin contenido en "Recientes" | Tarjeta en blanco e idéntica con A y con B, sin rastro del contenido | **Emu, adb:** `capture` + `compare` en las 14 filas (§3.2), 0 % de píxeles distintos, parecido < 0,1. **Xiaomi:** el lanzador respeta la señal (CL-011-9): tarjeta blanca con la franja negra, igual que el emulador; 10 de 10 medidas con "dos" (zona interior 100 % blanca), "uno" a ojo (§5.11) | API 26-32 (B); Android 13-35; ruta directa (CL-011-14, fuera del criterio) |
| **CA-011-02** matriz | 14 filas de la spec, cada una con A y B | **Emu, adb** (§3.2); web con páginas reales; error de almacenamiento con BD corrupta (`run-as`) | Fila de la spec 012 ("Configuración y perfil", licencias, texto de una licencia, confirmación de enlace): **no aplica todavía, la 012 no está implementada** |
| **CA-011-03** vuelta sin parpadeo | 0 fotogramas negros y 0 de otro color; blanco liso al volver con `am start` o icono (0,4-1,25 s con el emulador cargado, §3.3; 0,01-0,12 s en reposo y en modo oscuro, §6), casi nada al tocar la tarjeta | **Emu, adb:** mp4 con `AVAssetReader` (10 vueltas por tarjeta, 10 `am start`, 5 icono) y `record 10`; **test:** `home_router_test.dart` `'CA-011-03: …'` con el reloj en 9:59 y 10:00 | **Xiaomi:** duración del blanco sin medir (el USB se corta al grabar; ningún negro visto en las capturas). Arranque en frío en modo oscuro (negro ≈ 0,5 s): anterior a la 011, fuera de este criterio, **aplazado a F5** (decisión del propietario) |
| **CA-011-04** capturas y grabaciones | Con la app delante sale con contenido, sin `SECURE`: arranque en frío, tras "Recientes", tras el icono, tras la cámara y tras el selector | **Emu, adb:** `screencap`, `screenrecord`, `dumpsys window`; captura del sistema (encendido + volumen, `capturas/captura-sistema.png`) (§3.4). **Xiaomi:** `screencap` de `adb` con contenido, también tras arranque en frío (§5.11) | **Xiaomi:** captura y grabación del propio sistema; API 26-32 |
| **CA-011-05** arranque | p50 < 1 s y aumento dentro de la diferencia entre líneas base: base 384/385 ms, nueva 387/385 ms (p50; alternadas, n = 20) | **Emu, `measure-cold-start.sh`** (T-011-04, `docs/perf/baseline.md`); el margen es la resolución de la medida (±3 ms) | **Xiaomi:** cifra real de P2 (con permiso del propietario) |
| **CA-011-06** sin datos, permisos ni dependencias | Permisos idénticos a `main`, `pubspec*`/`drift_schemas/`/`schemaVersion` sin cambios, `files/` sin archivos nuevos (17 entradas idénticas) | **adb** y `git diff` (§3c), `aapt2`, `run-as` | Almacenamiento externo (la app no lo usa) |
| **CA-011-07** otras plataformas | Nada de Dart de la app cambia; `flutter test` completo y `flutter build web` correctos | **test** (T-011-05 y de nuevo en T-011-08: +1207 ~49), `flutter build web` | iOS no se compila (D17) |
| **CA-011-08** ciclo completo | Tarjeta en blanco y captura con contenido: 10 de 10 el básico y 10 de 10 con la cámara; con el selector de fotos 10 de 10 la captura sale con contenido y la tarjeta enseña la app (excepción aceptada, CL-011-15) | **Emu, adb** (§3.3); **Xiaomi:** ciclo básico 10 de 10 (tarjeta en blanco, app de vuelta) (§5.11) | **Xiaomi:** cámara y selector; API 26-32 |

Casos límite relevantes:

| CL | Estado | Dónde |
|---|---|---|
| CL-011-1 (actualizar) | **Hecho, confirmado** (la tarjeta antigua sigue hasta la próxima vez que se va a segundo plano); aceptado | Emu, §3.1 |
| CL-011-2 (el sistema cierra la app) | **Hecho, pasa** | Emu, `am kill` |
| CL-011-3 (cámara y selectores) | Cámara y archivos: pasa. Selector de fotos: la tarjeta enseña lo que queda a la vista (**aceptado**, CL-011-15) | Emu; Xiaomi **sin hacer** |
| CL-011-4 (superposiciones) | Selector parcial: igual que la línea base. Bandeja: sin comparación posible (opaca). Menú de apagado: **no verificado** (apagó el emulador) | Emu, §3.5 |
| CL-011-5 (pantalla dividida) | **[Pendiente, PD-10]** (8-9 frente a 10+) | — |
| CL-011-6 (gesto de cambio) | Ventana en vivo con contenido; **aceptado** (propietario) | Emu, §3.5 |
| CL-011-7 (captura desde "Recientes") | No probado aparte; coincide con lo que ve el usuario | — |
| CL-011-8 | Fuera de alcance | — |
| CL-011-9 (HyperOS) | **Hecho, el lanzador respeta la señal** | Xiaomi, §5.11 |
| CL-011-10, 11, 12 | **Hecho, pasan** (bloqueo y desbloqueo; teclado y texto, que no reaparece igual que en la línea base; giro con PDF) | Emu, §3.1 |
| CL-011-13 (fallo silencioso) | Mitigado: `check-recents.sh` antes de cada entrega (checklist, testing.md y `/release-checklist`); sin test de CI, por decisión del propietario | — |
| CL-011-14 (ruta directa) | Ventana en vivo, fuera de CA-011-01; **aceptado**. Xiaomi: no probado | Emu, §2 |
| CL-011-15 (hoja del selector de fotos) | Igual que antes de la 011; **aceptado** | Emu, §3.5 |

Accesibilidad de la spec §6: TalkBack lee la tarjeta con solo el nombre de la app ("Una.. 4 of 4") **[Hecho, emulador, en inglés]**. Lupa del sistema, TalkBack al volver, TalkBack en español y en HyperOS, Switch Access y teclado: **no verificados**, en la auditoría de F5 (`docs/PLAN.md`).
