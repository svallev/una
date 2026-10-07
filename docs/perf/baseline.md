# Rendimiento: línea base

Presupuestos (docs/PLAN.md, CA-001-09): tarea actual visible en **< 1 s (p50)** desde el icono, en *release*; descarga **< 25 MB** por ABI en Android.

## Arranque en frío (T-001-17)

- **Fecha:** 2026-09-24 · **Commit:** rama `feat/001-primer-uso-y-tarea-actual` (spec 001 completa, con fuentes empaquetadas)
- **Dispositivo:** Xiaomi 15T Pro (MediaTek Dimensity MT6991, Android 16 / HyperOS OS3.0.304.0), **gama alta**
- **Compilación:** `flutter build apk --release --split-per-abi --target-platform android-arm64` (19,7 MB)
- **Estado:** una tarea de texto pendiente; la app abre directamente en la tarea actual
- **Método:** `tools/measure-cold-start.sh <serial> 20` → `am start -W -S` (TotalTime: del lanzamiento al primer fotograma, que ya muestra la tarea porque se lee antes de `runApp`)

| n | mín | **p50** | p90 | máx |
|---|---|---|---|---|
| 20 | 187 ms | **198 ms** | 211 ms | 279 ms |

- **[Hecho]** CA-001-09 se cumple con amplio margen en el dispositivo de referencia: p50 = 20 % del presupuesto. El primer arranque tras instalar tardó 515 ms (optimización inicial del sistema); no cuenta como arranque en frío habitual.
- **[Hecho]** Tras matar el proceso, la app reabre en la tarea actual (lectura del árbol de accesibilidad: "Tarea actual: …", "Menú de la tarea", "Pulsa para completar").
- **[Pendiente, riesgo R-02]** Falta un Android de gama media. El spike S1 midió la misma arquitectura en el emulador (tiempo propio de la app ≈ 80 ms); se confirmará en la beta o con un dispositivo prestado.

## Completar: rotura y enhorabuena (spec 003, T-003-09)

- **Fecha:** 2026-09-25 · **Dispositivo:** Xiaomi 15T Pro (pantalla de 120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/complete_perf_test.dart -d <serial>` (fotogramas reales, `fullyLive`); se completa con el controlador (como la acción accesible) y se mide toda la secuencia (pausa, rotura, enhorabuena y fundido, ~2,9 s). App de pruebas `invalid.pending.app.profile`, que se desinstala a mano después (ver `docs/testing.md`).

| Ejecución | Fotogramas | Build medio / p90 / peor | Raster medio / p90 / p99 / peor |
|---|---|---|---|
| 1 | 243 | 1,4 / 2,1 / 11,9 ms | 2,6 / 3,4 / 10,6 / 12,5 ms |
| 2 | 232 | 1,5 / 2,3 / 20,0 ms | 2,5 / 3,4 / 10,6 / 14,1 ms |
| 3 | 231 | 1,5 / 2,1 / 22,9 ms | 2,4 / 3,4 / 8,9 / 13,7 ms |

- **[Hecho]** Fluida: el 90 % de los fotogramas cuesta ~6 ms en total, muy por debajo del presupuesto de 120 Hz. El recorte con `ClipPath` (sin capturar la nota como imagen) evita el tirón del spike S2.
- **[Hecho]** El único fotograma lento (12–23 ms) es el primero de la enhorabuena, al montar la capa. **[Pendiente]** Si se nota en gama media, precargar la capa (I-3).

## Eliminar: arrugado y papelera (spec 004, T-004-11)

- **Fecha:** 2026-09-26 · **Dispositivo:** Xiaomi 15T Pro (120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/delete_perf_test.dart -d <serial>`; se elimina con el controlador (como tras confirmar) y se mide todo el arrugado (2,2 s). Después, `adb uninstall invalid.pending.app.profile`.

| Ejecución | Fotogramas | Build medio / p90 / peor | Raster medio / p90 / p99 / peor | Fuera de presupuesto (raster) |
|---|---|---|---|---|
| 1 | 259 | 0,6 / 0,8 / 7,9 ms | 4,0 / 5,6 / 15,3 / 23,5 ms | 2 |
| 2 | 258 | 0,7 / 1,0 / 8,3 ms | 4,5 / 5,7 / 14,2 / 22,9 ms | 2 |
| 3 | 264 | 0,8 / 1,0 / 6,5 ms | 4,4 / 5,5 / 16,4 / 27,5 ms | 4 |

- **[Hecho]** Fluido: el 90 % de los fotogramas cuesta ~6,5 ms en total. Hay de 2 a 4 fotogramas lentos (15–28 ms de raster) por cada ~260.
- **[Suposición]** Esos fotogramas lentos son los primeros de la capa (sombra, facetas y degradados que se crean por primera vez), como pasaba en la 003. **[Pendiente]** Si se nota en el móvil o en gama media, precargar los *shaders* o la capa (I-3).

## Listado con 500 tareas (spec 006, T-006-15, CA-006-20)

- **Fecha:** 2026-09-26 · **Dispositivo:** Xiaomi 15T Pro (120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/task_list_perf_test.dart -d <serial>`, con 500 tareas (una de cada 7 con texto largo). Abrir: desde que se toca "Todas mis tareas" hasta ver las filas. Desplazar: 6 lanzamientos abajo y 6 arriba. Arrastrar: una fila 480 px abajo y vuelta. Después, `adb uninstall invalid.pending.app.profile`.

| Medida | Resultado | Objetivo (CA-006-20) |
|---|---|---|
| Abrir el listado | 40 ms | < 300 ms |
| Desplazar (2 167 fotogramas) | Build medio / p90 / peor: 0,6 / 1,5 / 3,6 ms · Raster medio / p90 / p99: 1,9 / 2,5 / 3,1 ms · 0 fuera de presupuesto | p90 ≤ 16,7 ms |
| Arrastrar (172 fotogramas) | Build medio / p90 / peor: 1,3 / 3,5 / 5,5 ms · Raster medio / p90 / p99: 2,3 / 2,9 / 4,0 ms · 0 fuera de presupuesto | p90 ≤ 16,7 ms |

- **[Hecho]** Muy por debajo del objetivo, incluso para 120 Hz. Mover solo la fila levantada (sin reconstruir la lista en cada movimiento) redujo a la mitad el coste del arrastre en el emulador.

## Tarea actual con imagen (spec 007, T-007-23)

- **Fecha:** 2026-09-27 (sin visor, ADR-0013). **Presupuesto** (`docs/architecture.md` §7): la imagen de 24 MP añade < 200 MB sobre la misma tarea con texto. **Método:** `dumpsys meminfo` en un proceso nuevo.

| Dónde | Tarea | PSS total | RSS total | Nota |
|---|---|---|---|---|
| Xiaomi (app real, *release*) | Foto de la cámara, en horizontal | 213 MB | 335 MB | Con la GPU |
| Emulador (Pixel 6a, *profile*) | Solo texto | 113 MB | 226 MB | Sin GPU (`Graphics: 0`) |
| Emulador (Pixel 6a, *profile*) | La misma, con 24 MP (5999 × 4000): vertical, desplazada y en horizontal | 107–112 MB | 226–233 MB | Sin GPU |

- **[Hecho]** Dentro del presupuesto, con margen: en el Xiaomi la app entera con la foto ocupa 213 MB de PSS, así que la imagen añade como mucho ~100 MB sobre una tarea con texto (~113 MB en el emulador sin GPU). Es lo esperado: las teselas se decodifican al ancho de la pantalla (~4 MB por capa), no a ×8 como el visor retirado.
- **[Pendiente, opcional]** La diferencia exacta en el Xiaomi (texto frente a 24 MP en la app `.profile`); el emulador no cuenta la memoria de la GPU.
- **[Pendiente]** En gama media (R-02), y sobre todo en Android 8 con 2–3 GB, el pico de la importación de 50 MP (~620 MB de RSS, medido el 2026-09-27) es el riesgo principal.

## Arranque en frío con imagen (spec 007, CA-007-08)

- **Fecha:** 2026-09-27 · **Dispositivo:** Xiaomi 15T Pro · **Compilación:** `flutter build apk --release --split-per-abi --target-platform android-arm64` (20,7 MB)
- **Estado:** app real, con una foto de la cámara como tarea actual (creada a mano por el propietario); mismo método que el arranque con texto.

| n | mín | **p50** | p90 | máx |
|---|---|---|---|---|
| 20 | 202 ms | **226 ms** | 255 ms | 464 ms |

- **[Hecho]** CA-007-08 se cumple: p50 = 23 % del presupuesto; +28 ms sobre el arranque con texto (198 ms).
- **[Hecho]** La foto se ve en el primer fotograma (captura justo al volver `am start -W`), sin fondo vacío previo.
- **Repetido sin visor** (2026-09-27, imagen al ancho con teselas encima de la versión de pantalla): n = 20, mín 212, **p50 245 ms**, p90 262, máx 278 ms. Sigue en el 25 % del presupuesto.

## Tarea actual con PDF (spec 008, T-008-22)

- **Fecha:** 2026-09-28 · **Rama:** `feat/008-pdf`
- **Fichero:** `tools/fixtures/out/scanned_20p.pdf` (20 páginas escaneadas, JPEG de ruido, 8,5 MB: el caso más pesado admitido, CL-008-5), generado con `tools/fixtures/gen_pdf_fixtures.py`.
- **Método:** `integration_test/pdf_perf_test.dart` en modo *profile* crea en la app `.profile` una tarea con texto (referencia) y la misma tarea con el PDF; mide la memoria del proceso (`/proc/self/smaps_rollup`, sin la GPU) con la tarea de texto, con el PDF en la página 1, el pico mientras se desplaza de la 1 a la 20 con el dedo y al final; guarda la posición en una página intermedia. Después se instala la app normal `.profile` (misma BD) y se mide el arranque en frío (`am start -W -S`) y `dumpsys meminfo` en un proceso nuevo. Con `--dart-define=PDF_PERF_TEXT_ONLY=true` deja solo la tarea con texto (la referencia del arranque y de `dumpsys`).

### Tamaño del APK

| Compilación | En disco | Comprimido (`gzip -9`, como CI) | Nota |
|---|---|---|---|
| `flutter build apk --release --split-per-abi --target-platform android-arm64` | 28,2 MB | 12,6 MB | 20,7 MB en disco en la 007: +7,5 MB, casi todo `libpdfium.so` (6,4 MB); pdfrx y sus paquetes Dart, ~0,4 MB |

- **[Hecho]** Dentro del presupuesto (< 25 MB por ABI, comprimido). `--analyze-size`: `lib/arm64-v8a` 26 MB (libflutter 11,7, libapp 7,4, libpdfium 6,4, libsqlite3 1,7 MB).

### Emulador (Pixel 6a, *profile*, sin GPU)

| Medida | Solo texto | Con el PDF escaneado | Diferencia |
|---|---|---|---|
| PSS del proceso en el test (smaps) | 115 MB | página 1: 136 MB · pico al desplazar de la 1 a la 20: 181 MB · en la 20: 137 MB | pico +66 MB |
| `dumpsys meminfo`, proceso nuevo (PSS total) | 113 MB | 130 MB (en la página 7 guardada) | +17 MB |
| Desplazar de la 1 a la 20 (703 fotogramas) | — | build medio / p90: 3,3 / 7,5 ms; raster medio 177 ms | sin GPU: el raster del emulador no cuenta |

- **[Hecho]** CL-008-5 en el emulador: se desplaza de la 1 a la 20 sin cerrarse y la tarea añade como mucho ~66 MB (pico) sobre la misma tarea con texto, muy por debajo de 200 MB.
- **[Hecho]** El arranque en frío vuelve a la página guardada (la 7) sin ningún toque.
- **[Hecho, emulador, antes del arreglo]** Justo al volver `am start -W` (primer fotograma), la zona de las páginas se veía **en blanco**; unos segundos después, la página. En este emulador el arranque en frío tarda 4,5–6 s también con solo texto (5–8 s), así que el tiempo no dice nada del móvil.
- **[Hecho, emulador, tras el arreglo de CA-008-08 (abajo)]** 4 arranques en frío (`am start -S`, capturas seguidas, *profile*, página 7 a 0,95 guardada): la primera captura con la app ya muestra las páginas (0 filas en blanco en la zona del PDF) y ninguna posterior las muestra en blanco. Trazas temporales (quitadas): leer `position.json` y decodificar `screen.jpg` (1080 × 2400) antes de `runApp` cuesta ~230 ms; el visor está listo 0,25–0,8 s después del primer fotograma y pdfrx avisa de que ha dibujado las páginas visibles 1,8–2,8 s después de estar listo.

### Xiaomi 15T Pro

Medido el 2026-09-28 (Xiaomi 15T Pro, 120 Hz, app `.profile` aparte; la app real no se tocó).

| Medida | Solo texto | Con el PDF escaneado | Diferencia |
|---|---|---|---|
| PSS del proceso en el test (smaps, sin GPU) | 157 MB | página 1: 174 MB · pico al desplazar de la 1 a la 20: 198 MB · en la 20: 197 MB | pico +41 MB |
| `dumpsys meminfo`, proceso nuevo (PSS total / Graphics) | 245 / 87 MB | 329 / 157 MB (en la página 7 guardada) | +84 MB (+70 MB de GPU) |
| Arranque en frío (`am start -W -S`, 20 veces; primer fotograma) | p50 399 ms · p90 443 ms | p50 410 ms · p90 461 ms (máx. 672) | +11 ms |
| Desplazar de la 1 a la 20 (3211 fotogramas) | — | build medio / p99 / peor: 0,7 / 1,7 / 2,7 ms; raster medio / p99 / peor: 1,3 / 2,1 / 4,5 ms; 0 fotogramas perdidos | — |

- **[Hecho]** CL-008-5 en el móvil: pico +41 MB sin GPU y +84 MB con ella en un proceso nuevo; muy por debajo de 200 MB. Desplazamiento sin ningún fotograma perdido a 120 Hz.
- **[Hecho]** El primer fotograma con el PDF llega en p50 410 ms (< 1 s).
- **[Hecho, antes del arreglo] La página no se veía en < 1 s.** En una captura a ~0,84 s del lanzamiento (arranque en frío, página 7 guardada) ya estaban la cabecera, la franja ("PDF scanned_20p.pdf 8,5 MB"), el botón y los bordes de las páginas, pero **el contenido de la página en blanco** (las páginas del fichero son ruido gris), como en el emulador.
- **[Hecho] Causa y arreglo (2026-09-28).** Tres causas: (1) `screen.jpg` no estaba decodificada en el primer fotograma; (2) la cara se quitaba en cuanto el visor pdfrx estaba listo, antes de que dibujara las páginas, y el visor la tapaba en blanco; (3) la cara era solo la página guardada, desplazada, con blanco debajo. Ahora: `position.json` y `screen.jpg` se leen y se decodifican antes de `runApp` (solo con un PDF en la tarea actual, tope 1 s: el arranque sin PDF no cambia); `screen.jpg` es lo que se ve desde la posición (la página desde su fracción y las de debajo, con el borde, hasta el alto de la pantalla); la cara se queda encima hasta que pdfrx avisa de que ha dibujado la última página visible (o el primer toque, o 10 s). Coste: una decodificación de JPEG de pantalla completa antes del primer fotograma, solo con PDF (~230 ms en el emulador sin GPU).
- **Xiaomi tras el arreglo (2026-09-28, app `.profile` aparte, quitada después):** arranque en frío con el PDF en la página 7 guardada p50 481 ms · p90 531 ms (antes del arreglo 410 ms: +71 ms por decodificar `screen.jpg` antes de `runApp`). Capturas seguidas tras `am start -n` (cada `screencap` tarda ~0,47 s): a ~0,72 s aún la ventana de arranque del sistema (sin el primer fotograma); la siguiente, a ≤ 1,2 s, ya con las páginas (3,45 MB, el mismo tamaño que la de ~2,1 s, que se ve con las páginas; una página en blanco comprime a una fracción; no se pudo copiar por el USB); a ~2,1 s, las páginas. **[Hecho]** ya no hay blanco: la primera captura con la app muestra la página. **[Suposición]** que se vea en < 1 s exactos: la captura cae entre 0,72 y 1,2 s. Para instalar en HyperOS hace falta "Instalar vía USB" activado y aceptar el aviso en el móvil.
- **[Pendiente]** Giro en HyperOS: necesita la mano del propietario (pasos en la fila de T-008-22 de `tasks.md`).

Pasos (con el permiso del propietario; nunca sin `--keep-app-running`, y siempre con el binario ya compilado para que flutter no deduzca el paquete base, que es la app real). **Ojo:** el APK partido por ABI tiene `versionCode` 2001 y el del test 1: si la app `.profile` del paso 1 sigue instalada, `flutter drive` del paso 2 no puede instalar (`INSTALL_FAILED_VERSION_DOWNGRADE`) y corre la app vieja. Antes del paso 2: `adb uninstall invalid.pending.app.profile`, `adb install /tmp/perf-pdf.apk`, `adb shell mkdir -p` de la carpeta y después el `push`.

```bash
cd app
S=<serial>
flutter build apk --profile --target=integration_test/pdf_perf_test.dart && cp build/app/outputs/flutter-apk/app-profile.apk /tmp/perf-pdf.apk
flutter build apk --profile --target=integration_test/pdf_perf_test.dart --dart-define=PDF_PERF_TEXT_ONLY=true && cp build/app/outputs/flutter-apk/app-profile.apk /tmp/perf-text.apk
flutter build apk --profile --split-per-abi --target-platform android-arm64 && cp build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk /tmp/app-profile.apk
# 1) Referencia con texto
flutter drive --profile --no-dds --keep-app-running --use-application-binary=/tmp/perf-text.apk \
  --driver=test_driver/perf_driver.dart --target=integration_test/pdf_perf_test.dart -d $S
adb -s $S install -r /tmp/app-profile.apk
../tools/measure-cold-start.sh $S 20 invalid.pending.app.profile   # ver la nota del nombre de la actividad
adb -s $S shell dumpsys meminfo invalid.pending.app.profile | grep -E "TOTAL PSS|Graphics"
# 2) Con el PDF escaneado
adb -s $S push ../tools/fixtures/out/scanned_20p.pdf /sdcard/Android/data/invalid.pending.app.profile/files/scanned_20p.pdf
flutter drive --profile --no-dds --keep-app-running --use-application-binary=/tmp/perf-pdf.apk \
  --driver=test_driver/perf_driver.dart --target=integration_test/pdf_perf_test.dart -d $S
cat build/pdf_memory.json build/pdf_scroll_frames.json
adb -s $S install -r /tmp/app-profile.apk
# (arranque y dumpsys como en 1)
```

- `measure-cold-start.sh` lanza `$PKG/.MainActivity`; con `.profile` la actividad es `invalid.pending.app.MainActivity`: `am start -W -S -n invalid.pending.app.profile/invalid.pending.app.MainActivity`.
- La app `.profile` queda instalada al terminar; se quita a mano (`adb uninstall invalid.pending.app.profile`, **solo** ese paquete).

## Tarea actual con página web (spec 009, T-009-18)

- **Fecha:** 2026-09-29 · **Rama:** `feat/009-adjunto-url` · **Dispositivo:** Xiaomi 15T Pro (WebView del sistema, LTE), app `.profile` aparte (la app real no se tocó).
- **Estado:** `integration_test/web_perf_test.dart` deja una tarea con texto y, encima (actual), la tarea web `https://example.org/`. El propietario usaba el móvil a la vez (las mediciones lo interrumpieron).

| Compilación | En disco | Comprimido (`gzip -9`) | Nota |
|---|---|---|---|
| `flutter build apk --release --split-per-abi --target-platform android-arm64` | 28,7 MB (28 697 621 B) | 13,4 MB | 28,2 MB en la 008: +0,5 MB (`webview_flutter`, `WebViewHardening.kt` y la web) |

| Medida (Xiaomi, `.profile`) | Solo texto | Con la web a la vista | Diferencia |
|---|---|---|---|
| PSS del proceso en el test (smaps, sin GPU ni la WebView, que es otro proceso) | 143 MB | 208 MB (10 s después de crearla, ya cargada) | +65 MB |
| `dumpsys meminfo`, proceso nuevo (PSS total / Graphics) | — | 440 / 252 MB | los procesos de la WebView del sistema (`sandboxed_process`) no cuentan aquí |
| Arranque en frío (`am start -W -S`, 20 veces; primer fotograma) | p50 399 ms · p90 443 ms (008, 2026-09-28) | p50 478 ms · p90 547 ms (mín. 436, máx. 694) | +79 ms |

- **[Hecho]** CA-009-07/CA-001-09: el primer fotograma con la tarea web llega en p50 478 ms (< 1 s). La WebView se crea después del primer fotograma (T-009-11), así que ese tiempo es el de la barra del dominio y la línea de carga, no el de la página.
- **[Suposición]** El +79 ms frente al arranque con texto se debe al camino de la tarea web (lectura de la tarea, barra, plugin `una/webview`); la referencia de texto es de otro día y de otra compilación.
- **[Pendiente]** No se midió el tiempo hasta ver la página (depende de la red) ni la memoria de los procesos de la WebView; no se capturó pantalla del móvil (el propietario lo usaba).
- **[Hecho]** El APK sigue por debajo de 25 MB por ABI (comprimido).

## Arranque en frío con la 011 (Recientes ocultos, T-011-04)

- **Fecha:** 2026-09-30 · **Rama:** `feat/011-ocultar-recientes` (HEAD `594f5d1`) · **Línea base:** `main` (`725e97c`, sin `RecentsPrivacy`), sacada con `git archive` a un directorio temporal (el árbol de trabajo no se toca).
- **Xiaomi (2026-09-30, con permiso del propietario; HEAD `7448f4e`):** *profile* de `licenses_perf_test.dart` con `--keep-app-running` (app `.profile` desinstalada después, la base intacta): lista de licencias, 2037 fotogramas, construcción p90 1,6 ms, rasterizado p90 **2,2 ms** (p99 2,7), 0 fotogramas > 16,7 ms; texto de `angle`, 2168 fotogramas, construcción p90 1,0 ms, rasterizado p90 **2,5 ms** (p99 3,5), 0 > 16,7 ms; abrir el nivel 2: **56 ms**. Arranque en frío, *release* arm64 de `main` frente a la rama, 8 pasadas alternadas de 20 sobre la app real: p50 219, 215, 216, 214 ms (base, media 216) y 209, 210, 221, 221 ms (rama, media 215); p90 227-246 ms; **sin diferencia**.
- **Dispositivo (emulador):** emulador `Pixel_6a` (API 37, arm64, sin GPU), `emulator-5554`. **El emulador solo compara** las dos compilaciones entre sí; **no es la medida real de P2** (esa es la del móvil, con permiso del propietario). Tiempos de otro orden que los del Xiaomi (p50 ~200-480 ms allí).
- **Compilación:** `flutter build apk --release --split-per-abi --target-platform android-arm64` (28,7 MB las dos; la nueva lleva `setRecentsScreenshotEnabled` en el `classes.dex`, la base no). Misma tarea (texto, "SECRETO-UNO"), mismos datos.
- **Método:** cuatro pasadas **alternadas** (base, nueva, base, nueva) con `tools/measure-cold-start.sh emulator-5554 20`; antes de cada una, `adb install -r` y un arranque de calentamiento (no cuenta) más 5 s de espera, para no medir la optimización posterior a la instalación.

| Pasada | Compilación | mín | **p50** | p90 | p95 | máx |
|---|---|---|---|---|---|---|
| 1 | base (sin 011) | 362 | **384** | 418 | 437 | 530 |
| 2 | nueva (011) | 374 | **387** | 453 | 517 | 571 |
| 3 | base (sin 011) | 364 | **385** | 397 | 425 | 693 |
| 4 | nueva (011) | 365 | **385** | 425 | 436 | 474 |

- Todo en ms, n = 20 por pasada. Las dos de la base juntas (n = 40): p50 **385**; las dos de la nueva: p50 **386**.
- **[Hecho]** p50 < 1 s: 384-387 ms (39 % del presupuesto, en el emulador).
- **[Hecho]** Aumento del p50: **+1 ms** con las pasadas juntas (386 frente a 385); por parejas, +3 ms (1.ª) y 0 ms (2.ª). La diferencia entre las dos pasadas de la base es de **1 ms** (384 y 385), así que el aumento cabe en ella, pero **el margen es de la resolución de la medida**: el ruido entre pasadas (hasta 3 ms) es mayor que el efecto que se busca. Las p90 y p95 varían más entre pasadas iguales (397-418 y 425-437 en la base) que entre base y nueva.
- **[Hecho]** Lectura: `RecentsPrivacy` (una llamada a `setRecentsScreenshotEnabled` en `onCreate`, `onPause` y `onResume`) no añade un coste medible al arranque en frío; el criterio de T-011-04 se cumple. **[Pendiente]** El Xiaomi no se midió (no se toca sin permiso); si el propietario quiere la cifra real de P2, `tools/measure-cold-start.sh` con la release de la rama.

## Licencias de la Configuración (spec 012, T-012-09)

- **Fecha:** 2026-09-30 · **Rama:** `feat/012-configuracion-temporal` (HEAD `2913c01`) · **Línea base:** `main` (`c576d3f`), sacada con `git archive` a un directorio temporal.
- **Dispositivo:** emulador `Pixel_6a` (API 37, arm64, sin GPU), `emulator-5554`. **El emulador solo compara**; no es la medida real de P2 ni de los fotogramas (esa es la del móvil, con permiso del propietario). El Xiaomi no se tocó.
- **Arranque en frío (CA-012-16).** *Release* arm64 (28,7 MB la base, 28,8 MB la nueva), ocho pasadas alternadas de 20 arranques con `tools/measure-cold-start.sh`, tarea actual con imagen; antes de cada pasada, `adb install -r` y un arranque de calentamiento.

| Pasada | 1 base | 2 nueva | 3 base | 4 nueva | 6 nueva | 5 base | 8 nueva | 7 base |
|---|---|---|---|---|---|---|---|---|
| p50 (ms) | 437 | 451 | 438 | 476 | 478 | 477 | 476 | 462 |
| p90 (ms) | 465 | 506 | 477 | 629 | 569 | 530 | 538 | 535 |

- **[Hecho]** p50 < 500 ms. Media de la base 453,5 ms, de la nueva 470,3 ms: **+17 ms (+3,7 %)**; por parejas +14, +38, +1, +14. **[Suposición]** ruido del emulador (la misma compilación varía 40 ms entre pasadas y hay deriva); la nueva no mejoró en ninguna pareja. El mecanismo (no se lee ninguna licencia antes del primer fotograma) lo prueba `startup_licenses_test.dart`. **[Pendiente]** repetirlo en el Xiaomi con permiso del propietario.
- **Desplazar la lista de licencias y el texto de `angle` (CA-012-15).** `integration_test/licenses_perf_test.dart`, *profile*, 196 elementos reales (el test registra `NOTICES.Z` como el motor, porque el binding de pruebas no lo carga); control: el listado de 500 tareas de la 006 en el mismo emulador.

| Medida | Lista de licencias | Texto de `angle` (57 licencias) | Listado 006 (control) |
|---|---|---|---|
| Abrir el nivel 2 hasta ver la lista | **48 ms** | — | 59 ms |
| Construcción p50 / p90 | 0,6 / 1,5 ms | 0,5 / 1,2 ms | 0,5 / 1,5 ms |
| Rasterizado p50 / p90 / p99 | 15,2 / 17,1 / 20,9 ms | 16,3 / 17,5 / 18,9 ms | 16,2 / 17,7 / 18,8 ms |

- **[Hecho]** nivel 2 en 48 ms (< 300 ms); construcción muy por debajo de 16,7 ms. **[Suposición]** el rasterizado de ~16-17 ms es del emulador (sin GPU, 60 Hz): el control da lo mismo y el listado ya está aprobado en el Xiaomi. **[Pendiente]** p90 real en el Xiaomi.

## Arranque en frío con Ajustes (spec 015, T-015-13, CA-015-23)

- **Fecha:** 2026-10-05 · **Rama:** `feat/015-ajustes` (con T-015-01 a 11 y 07b) · **Línea base:** `main` (`f055afd`, sin Ajustes), en un `git worktree` temporal. Las dos, `flutter build apk --release --split-per-abi --target-platform android-arm64` (base 28 928 372 B; nueva 28 862 836 B: **−66 KB** al salir las pantallas de licencias).
- **Dispositivo:** emulador `Pixel_6a` (API 37, arm64, sin GPU), `emulator-5554`; **solo compara** las dos compilaciones entre sí (no es la medida real de P2; el Xiaomi no se ha usado). App real `invalid.pending.app` con una tarea de texto creada a mano; ajustes por defecto (el arranque lee `locale` y `keepScreenOn` antes del primer fotograma).
- **Método:** cuatro pasadas **alternadas** (base, nueva, base, nueva) con `tools/measure-cold-start.sh emulator-5554 20`; antes de cada una, `adb install -r` y un arranque de calentamiento más 5 s de espera.

| Pasada | Compilación | mín | **p50** | p90 | máx |
|---|---|---|---|---|---|
| 1 | base (sin 015) | 403 | **425** | 448 | 544 |
| 2 | nueva (015) | 401 | **418** | 429 | 450 |
| 3 | base (sin 015) | 403 | **422** | 439 | 466 |
| 4 | nueva (015) | 403 | **421** | 447 | 459 |

- **[Hecho]** CA-015-23: p50 de 418-421 ms (< 1 s) y la nueva no es más lenta que la base (media 423,5 ms la base y 419,5 ms la nueva: −4 ms; la diferencia entre las dos pasadas de la base es 3 ms). **[Pendiente]** ~~repetirlo en el Xiaomi~~ hecho el 2026-10-05, abajo.
- **Xiaomi 15T Pro (2026-10-05, con permiso del propietario; app real, `adb install -r`, datos intactos):** las mismas dos compilaciones, ocho pasadas alternadas (base, nueva, …) de 20 arranques con `tools/measure-cold-start.sh`, calentamiento y 5 s de espera antes de cada una. p50 base **210, 213, 224, 222** ms (media 217) y nueva **208, 236, 228, 220** ms (media 223); p90 219-307 ms. **[Hecho]** CA-015-23: p50 < 1 s con un margen enorme (≈ 22 % del presupuesto) y **sin diferencia** entre las dos (+6 ms, dentro de la deriva: la base varía 14 ms entre pasadas; la pasada 4 de la nueva tuvo un p90 de 307 ms y un arranque sin dato). Queda instalada la compilación de la rama.

## Cómo repetir la medición

```bash
cd app && flutter build apk --release --split-per-abi --target-platform android-arm64
adb -s <serial> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Abre la app y crea una tarea; después:
cd .. && tools/measure-cold-start.sh <serial> 20
```

Se repite al cerrar cada spec que toque el arranque (003, 007–009, 011, 012) y antes de cada release.

## Grupo de 10 fotos de 24 MP (spec 016, T-016-20)

- **Fecha:** 2026-10-07 · **Dispositivo:** emulador `Pixel_6a` (API 37, arm64, sin GPU: más lento que el Xiaomi; no hay medida en el móvil). **[Pendiente]** repetir en el Xiaomi con el permiso del propietario.
- **Fotos de prueba:** 10 JPEG de 4000 × 6000 (24 MP) de ~6,3 MB (color con textura, número grande), generadas con Pillow; más una de 19 MB de ruido casi incompresible para el peor caso. No se versionan (se regeneran).
- **Arranque en frío** (`tools/measure-cold-start.sh emulator-5554 20`, *release*): 1 foto de 24 MP → p50 **425 ms** (p90 457); grupo de 10 → p50 **429 ms** (p90 446). **+4 ms** (objetivo ≤ +100 ms y < 1 s). `readBootState` lee ≤ 10 filas y el primer fotograma pinta una sola foto.
- **Memoria** (`adb shell dumpsys meminfo <paquete>`, TOTAL PSS, muestreo continuo mientras se pasa por las 10 fotos 25 veces): grupo → reposo 76 MB, mediana 78 MB, pico **102 MB**; una foto → reposo 74 MB, mediana 81 MB, pico **81 MB**. **+21 MB** (objetivo ≤ +50 MB).
- **Hueco al cambiar de foto:** `adb exec-out screenrecord --output-format=raw-frames --size 360x800 --time-limit 14` (se corta con `pkill -INT screenrecord`) durante 12 swipes; se cuentan los fotogramas en que la zona de la foto enseña el color de la página. 214 fotogramas (~15 fps en el emulador), 181 con movimiento, **0** con fondo → hueco p90 < 1 fotograma (≈ 66 ms; objetivo ≤ 200 ms).
- **Espacio por tarea** (`adb shell run-as <debug> du -sk files/attachments`): 10 fotos de 6,3 MB → **62 MB**; una foto de 19 MB → 14,5 MB (`full` en dos teselas + `screen`). `storedPhotoEstimate` = 16 MB se mantiene como cota; la regla de ≥ 12 MP del ADR-0024 **no** hace falta.
- **Importar** 9 fotos de 19 MB: ~0,4 s por foto (la barra "Preparando foto i de n…" se ve a partir del tercer fotograma); 10 de 6 MB, menos de 6 s.
