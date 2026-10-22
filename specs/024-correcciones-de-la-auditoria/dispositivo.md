# Spec 024: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a_api37_root` (API 37, arm64, `emulator-5554`)** con la compilación **release** (`flutter build apk --release --split-per-abi`, `app-arm64-v8a-release.apk`, app real `invalid.pending.app`) sobre la rama `feat/024-correcciones-de-la-auditoria`. **Sin tocar el Xiaomi.** Capturas en el directorio temporal de la sesión (no se suben). El idioma del sistema se cambió con `adb root` + `settings put system system_locales "<lista>"` + `stop; start` y se **restauró a `en-US`** al acabar; `pm clear` de la app de prueba.

## C-024-3: catalán con inglés detrás (T-024-03, 2026-10-21)

Los resultados dependen de la release: la APK de **debug** trae recursos `ca` de librerías y no reproduce el fallo (por eso se sustituyó la prueba de integración por `tools/check-apk-locales.sh`, plan §1.4).

| Paso | Resultado |
|---|---|
| `aapt2 dump configurations` de la release **antes** del arreglo | Solo `es` (más `v27`…`nodpi`): sin `ca`. `tools/check-apk-locales.sh` **falla** («no trae recursos en 'ca'») |
| Release **antes** del arreglo, sistema en `ca-ES, en-US` (medido por el coordinador en un intento anterior) | Bienvenida en **inglés** (H-022-10 reproducido) |
| Tras el arreglo: `aapt2 dump resources` | `string/notification_title`: `()` «Current task», `(ca)` «Tarea actual», `(es)` «Tarea actual»; `values-ca` **sobrevive** al recorte de la release. `check-apk-locales.sh` en verde sobre `app-release.apk` y los tres `app-<abi>-release.apk` |
| Sistema en **`ca-ES, en-US`**, app con datos borrados | Bienvenida **en español** («¿Qué es eso que tienes que hacer y no has hecho?», «Guardar»); teclado «EN • CA» (el cambio de idioma se aplicó) |
| Mismo idioma, con una tarea guardada: menú y Ajustes | «Esta tarea», «Editar», «Eliminar», «Todas mis tareas», «Nueva tarea», «Ajustes»; **Ajustes** en español y la fila **Idioma** con «**Como el sistema**» |
| Sistema en **`en-US, ca-ES`** (misma app y datos), Ajustes | **Inglés**: «Settings», «Language» con «**Same as system**» (la regla de la 010: gana el primero) |

- **[Hecho]** CA-024-04 cumplido en el emulador: con `ca` primero, español; con el inglés primero, inglés.
- **[Suposición] sin comprobar:** el nombre del canal de la notificación sigue en el idioma de la app (CL-024-13): no se activó el interruptor de Notificaciones en esta pasada; lo dicen los tests de la 019 (sin cambios) y la lectura de `AndroidAdapters.kt`.
- **[Suposición] sin comprobar:** `Accept-Language` de la WebView con `ca-ES, en-US` (plan §1.4, B-3).

## C-024-1 y C-024-2: barras con la card y con las hojas (T-024-04, 2026-10-22)

Emulador `Pixel_6a_api37_root` (API 37, `emulator-5554`, 1080×2400, **sin tocar el Xiaomi**), compilación **release** (`app-arm64-v8a-release.apk`, app real) con el código de esta tarea. Navegación **de gestos** y **de tres botones** (`cmd overlay enable …gestural|threebutton`, restaurada a gestos al acabar). Los iconos del sistema se leen en capturas (`screencap`, en el Mac, borradas al acabar: no se suben): fondo = el color más frecuente de la franja, icono = el píxel de mayor contraste con él (WCAG 2.x). El estilo pedido a la plataforma se comprobó además con `dumpsys window | grep mLastAppearance` (`LIGHT_STATUS_BARS` = iconos oscuros arriba; sin ella, claros).

### Hallazgo de la tarea (H-024-A, corregido en esta misma tarea)

**Con la compilación de T-024-02, la barra de estado NO se aclaraba con la hoja abierta** (iconos negros sobre el velo): `mLastAppearance=LIGHT_STATUS_BARS` con «Esta tarea» abierta. Causa: Flutter lee el estilo de arriba en el **centro de la barra de estado** (`padding.top / 2`) y `showModalBottomSheet(useSafeArea: true)` recorta la ruta con un `ClipRect` que empieza **bajo** esa barra (`Rect.fromLTRB(0, 28, …)` en la dump de capas); el `AnnotatedRegion(sized: false)` de dentro de la ruta no se encuentra. Los tests de T-024-02 no lo vieron porque el arnés usaba margen superior 0 (el punto de arriba caía en y = 0). **Arreglo:** `scrimSheetsOpen` (contador en `system_bars.dart`) que `showUnaSheet` sube antes de abrir y baja en el fotograma en que la ruta termina de irse (`AnimationStatus.dismissed`, el mismo en que el navegador la quita), y `appFrame` pide `systemBarsUnderScrimStyle` con él (misma condición de ancho que antes, `scrimSpansScreen`); la región de la ruta se mantiene para la barra de navegación (hoja sobre la card). Tests: el arnés de las hojas tiene ahora margen superior de 28 (fallaban 10 tests antes del arreglo) y uno nuevo comprueba que la cuenta vuelve a 0. **Desvío del plan §1.3** (R-3 lo preveía como alternativa: contador leído por `appFrame`).

### Resultados (contraste medido, mínimo exigido 3:1)

| Caso | Barra | Gestos | Tres botones |
|---|---|---|---|
| Referencia sin hoja ni card, nota amarilla (CA-021-09) | estado (iconos negros sobre `#ffe55c`) | 16,61:1 | 16,61:1 |
| Referencia: navegación sobre la nota | píldora / botones | 5,32:1 (píldora, fuera del criterio) | 3,98:1 (nota verde) |
| **«Esta tarea» sobre la nota amarilla** | estado (blanco sobre `#7c7133`) | **4,92:1** | **4,92:1** |
| «Esta tarea» sobre la nota **naranja** | estado (blanco sobre `#7c5c3c`) | **6,08:1** | **6,08:1** |
| «Esta tarea» sobre la nota verde | estado | — | 5,41:1 |
| «¿Dónde la pones?» sobre la nota (azul-gris `#4a6877` / verde `#547248`) | estado | 5,94:1 | 5,41:1 |
| «Añadir» y «Cargar URL» (editor, nota rosa) | estado | 6,54:1 (las dos; sin parpadeo: 14 capturas seguidas de la hoja que abre otra, todas claras) | 6,54:1 |
| Las hojas anteriores | navegación sobre la hoja `paper` | 5,55:1 (píldora) | 5,09:1 (botones) |
| **Card sobre el listado** | navegación | **15,98:1** (píldora `#ececec` sobre `#111111`); estado sigue oscuro (18,62:1) | no medido |
| **Card sobre la tarea actual** (nota verde) | navegación | **15,98:1**; estado oscuro (14,56:1) | no medido |
| **Card sobre «Todo hecho.»** (CL-024-1) | navegación | no medido | **18,88:1** (botones blancos sobre `#111111`) |
| Card, **horizontal** (tarea con imagen, gestos) | píldora | **15,98:1** | — |
| Card, **horizontal con tres botones** (barra a la izquierda, CL-024-4) | botones | — | la barra sigue **oscura** (`mLastAppearance` sin cambio): «Recientes» sobre la card, 3,29:1 (≥ 3); «Atrás» e «Inicio» sobre la foto (1,6:1: fuera del criterio, detrás de una foto) |

Vuelta (CA-024-03): con la hoja cerrada (tocando fuera, con «Atrás» y eligiendo una opción), con la card caducada y al abrir otra tarea, `mLastAppearance` vuelve a `LIGHT_STATUS_BARS LIGHT_NAVIGATION_BARS` (iconos oscuros) y el contraste de estado vuelve a 10,9–16,6:1.

### Tránsito (R-2, medido con series de capturas cada ~100 ms; no hay `ffmpeg`)

- **Abrir la hoja:** 1.ª captura iconos oscuros (velo al ~0 %), 2.ª ya claros con el velo a medias (4,97:1), 3.ª en adelante 6,5:1.
- **Cerrar la hoja:** 4,81:1 → **1,92:1 en una captura** (iconos claros con el velo casi ido) → oscuros. Es el tránsito aceptado en R-2 (último 20–25 % de `sheetOut`).
- **Irse la card:** una captura (~100 ms) con la píldora clara sobre el fondo ya sin card (1,40:1 al medir) antes de volver a oscura: la app pide el estilo en el mismo fotograma (lo dicen los tests); el resto es el retraso de la plataforma al aplicarlo. Igual con tres botones y «Todo hecho.» (una captura a 2,08:1).

### Lo que no se pudo comprobar en el emulador

- **[Pendiente] TalkBack** sin regresión de foco en la card y en la hoja: se activó TalkBack, pero `input tap` solo enfoca y el doble toque no abrió el menú; no se obtuvo resultado (la tarea no cambia semántica ni foco: solo envolturas sin semántica y el estilo de las barras). Queda para T-024-05 / la revisión de accesibilidad del cierre.
- **[Pendiente] Hoja abierta en horizontal** y **girar con la hoja abierta**: con la tarea con imagen en horizontal no hay botón de menú, y con la hoja abierta el giro no se aplica hasta cerrarla. La regla de ancho (`scrimSpansScreen`) la cubren los tests (800×400 con y sin visor).
- **Card en el listado con tres botones** y **«Todo hecho.» con gestos**: no medidos (misma lógica que los casos medidos; los tests de widgets los cubren).
- **[Suposición]** los iconos claros del sistema son `#ffffff` (medido: 255,255,255 en todos los casos con hoja; `#ececec`/`#ffffff` en la píldora).
- El Xiaomi (HyperOS) queda para T-024-05.

Emulador restaurado: navegación de gestos, giro libre y sensor a vertical, TalkBack desactivado, idioma `en-US`, fotos de prueba borradas, `pm clear` de la app. Capturas solo en el directorio temporal de la sesión.
