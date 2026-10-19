# Spec 018: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37.2, arm64, `emulator-5554`, 1080 × 2400 a 420 dpi, idioma del sistema en inglés, lanzador de Pixel)**. **No se usó ni se tocó el Xiaomi** (es T-018-07, lo hace el coordinador). Capturas en el directorio temporal de la sesión (no se suben). Compilaciones: depuración `app-debug.apk` (T-018-03 a 05, paquete `invalid.pending.app.debug`) y *release* `--split-per-abi` (arm64, 29,0 MB, paquete `invalid.pending.app`); la de «antes» sale de un `git worktree` de `main` (`c1867a0`, icono de Flutter), construida con el mismo comando.

## T-018-06 (2026-10-11)

### C-018-1: las cuatro máscaras (CA-018-01, CA-018-02)

**[Desviación de método]** esta imagen del emulador **no trae «Forma de los iconos»** en las opciones de desarrollador (se activaron y se buscó «shape»: sin resultados; `cmd overlay list` no tiene ningún `com.android.theme.icon.*`). El equivalente real está en **Fondo de pantalla y estilo → Iconos → Forma**, del lanzador de Pixel, que ofrece **cinco** formas: círculo, cuadrado redondeado, trébol (cuatro lóbulos), galleta (ondulada) y arco (arriba redondeado, abajo casi recto). Se aplicó cada una de verdad (*Apply*) y se capturó el icono de la app en la pantalla de inicio, a tamaño real (1080 × 2400).

| Forma | Resultado |
|---|---|
| Círculo | **[Hecho]** «u.» entera, centrada; amarillo hasta el borde |
| Cuadrado redondeado (*squircle*) | **[Hecho]** igual |
| Arco (la más cercana a la «gota», con las esquinas de abajo casi rectas) | **[Hecho]** igual |
| Trébol y galleta (bordes cóncavos, las más agresivas) | **[Hecho]** «u.» entera, sin tocar el borde; el amarillo llena toda la figura |

- **[Hecho]** En ninguna hay borde blanco, transparente ni de otro color, ni se recorta la «u.» ni su punto. La «u.» queda centrada en todas.
- **[Pendiente]** El «cuadrado de esquinas casi rectas» de la spec no existe en este selector (lo más parecido es el arco por abajo): se mira en el Xiaomi (T-018-07, HyperOS tiene su propia máscara) y en la 022.
- Nota: en el *hotseat* (la fila de abajo) este lanzador dibuja un **aro más claro** alrededor de todos los iconos (el de Chrome sale rosa, el de Play dorado): es del lanzador («estilo» por defecto), no del icono. En la pantalla de inicio y en la lista de aplicaciones no sale.

### C-018-2: lanzador, «Ajustes del sistema» y lista de aplicaciones (CA-018-01)

- **[Hecho]** Pantalla de inicio (acceso en el escritorio y en el *hotseat*), **lista de aplicaciones** y **«Información de la aplicación»** (Ajustes → Aplicaciones → Una.; abierta desde el menú de pulsación larga): el icono es el amarillo con la «u.» negra, entero y centrado, con el nombre «Una.» debajo; ningún rastro del logotipo de Flutter.
- **[Hecho]** El icono pequeño del selector de «Recientes» (≈ 22–24 dp, junto a «Una.») se sigue leyendo como «u.».
- **[Pendiente]** HyperOS (Xiaomi) con el lanzador real: T-018-07.

### C-018-3: con tema encendido y apagado, y Android 8–12 (CA-018-04, CA-018-05)

- **[Hecho]** **Sin tema** (por defecto): el icono amarillo con la «u.» negra (casilla C-018-2 y capturas anteriores).
- **[Hecho]** **Con tema** (en este lanzador: Fondo de pantalla y estilo → Iconos → Estilo → **Minimal**, que pinta los iconos con la capa monocroma; *Default* es el normal): la «u.» **con su punto, completa y de un solo color** (azul oscuro del sistema) sobre el fondo claro del sistema, **sin manchas** (capa maciza). Se ve así en la pantalla de inicio; la lista de aplicaciones de este lanzador no aplica el tema a ningún icono (también pasa con Chrome, Gmail…). Vuelto a *Default* al terminar.
- **[Pendiente]** **Android 8–12 no se pudo comprobar**: el SDK solo tiene la imagen `android-37.2` y el único AVD es `Pixel_6a` (no hay AVD de API 26 ni 32); **no se descargó nada**. Cae en la 022 (con la casilla de Android 8 y 12L de otras specs), o antes si el propietario instala una imagen. Lo que cubre el riesgo mientras tanto: el recurso adaptable está en `mipmap-anydpi` (válido desde API 26; AGP lo renombra a `-v21`, `aapt2 dump badging` lo muestra como icono en todas las densidades) y la capa monocroma la ignoran las versiones anteriores a 13.
- **CL-018-3 (fondo de pantalla de muy poco contraste)**: sin cambio. El color y el fondo los decide el sistema; la capa es maciza y de un solo dibujo, así que el contraste lo da la combinación del sistema. Con el fondo de pantalla de este emulador (azul y negro) la silueta se ve nítida.

### C-018-4: nitidez a 48 y 24 dp y con «Tamaño de visualización» al máximo (CA-018-07, CL-018-4, CL-018-10)

- **[Hecho]** **48 dp** (la rejilla normal, 420 dpi = 126 px): bordes de la «u.» y del círculo limpios, sin escalones ni borrosidad (recorte ampliado ×2 con vecino más cercano).
- **[Hecho]** **≈ 24 dp**: el icono de la «chip» de «Recientes» (≈ 58 px): la «u.» y su punto se distinguen; trazo grueso sin detalles finos.
- **[Hecho]** **Tamaño de visualización al máximo** (Ajustes → Pantalla → Tamaño de pantalla y texto: 420 → 540 dpi, 4 pasos con «+»): la «u.» sigue nítida y entera; la rejilla del lanzador se reajusta. Devuelto con `wm density reset` (sin *override*).

### C-018-5: arranque en frío antes/después y el *splash* (CA-018-13)

**Método.** Las dos compilaciones *release* arm64 (la de «antes» desde `main`), mismo emulador, tarea «Llamar a Marta» creada una vez (la app abre en la tarea actual; los datos se conservan con `install -r`), `tools/measure-cold-start.sh emulator-5554 20`, **pasadas alternadas** (antes, después, antes, después; arranque de calentamiento y 5 s antes de cada una).

| Pasada | Compilación | mín | **p50** | p90 | máx |
|---|---|---|---|---|---|
| 1 | antes (icono de Flutter) | 353 | **382** | 417 | 467 |
| 2 | después (icono nuevo) | 348 | **370** | 392 | 427 |
| 3 | antes | 348 | **368** | 378 | 383 |
| 4 | después | 343 | **365** | 380 | 404 |

- **[Hecho]** p50 medio **antes 375 ms** y **después 367,5 ms** (−2 %); dentro del ±5 % y sin ser peor (la deriva entre las dos pasadas del mismo estado es de 14 ms). **El arranque no empeora (CA-018-13).** Todas muy por debajo del segundo de CA-001-09.
- **[Hecho]** **Splash de Android 12+** (grabación de pantalla en un arranque en frío, fotogramas cada 0,1 s): primero el sistema pinta el **fondo blanco de siempre** (`launch_background`, sin tocar) con la **«u.» negra centrada y entera** (≈ 26 % del ancho, sin recortes), y después la app. **No sale el círculo amarillo**: el sistema pinta solo el primer plano del adaptable sobre la ventana blanca. Se cumple la **[Suposición]** de CA-018-13 («solo el icono nuevo sobre el fondo de siempre»); **[Pendiente]** para la 021 si se quiere que el *splash* sea amarillo (es decisión de esa spec: aquí no se toca el fondo).

### C-018-6: el APK de *release* sin icono de plantilla (CA-018-06)

- **[Hecho]** `flutter build apk --release --split-per-abi --target-platform android-arm64` (29,0 MB; 2,4 KB **menos** que el de `main`). `aapt2 dump badging`: `application: label='Una.' icon='res/E4.xml'` (el *release* acorta los nombres de los recursos) y densidades 160, 240, 320, 65534 y 65535 apuntan **todas** al icono adaptable; en el de `main` salían los 5 PNG de la plantilla (`res/9w.png`, `yn.png`, `FS.png`, `RJ.png`, `o-.png`).
- **[Hecho]** `aapt2 dump xmltree res/E4.xml`: `<adaptive-icon>` con `background`, `foreground` y **`monochrome`**, esta última con el **mismo** recurso que el primer plano.
- **[Hecho]** `unzip -l`: **un solo PNG** en `res/` (`res/Wn.png`, 432 × 432, el primer plano; visto a ojo: la «u.» negra sobre transparente) y **ningún `ic_launcher*`**; los MD5 de los cinco PNG del APK de `main` y de los 10 de `test/fixtures/flutter_template_icons/` **no aparecen** en el APK nuevo. En el APK de depuración, los nombres originales: `res/mipmap-anydpi-v21/ic_launcher.xml` y `res/drawable-nodpi-v4/ic_launcher_foreground.png`.
- **CL-018-6 (actualizar sobre una versión con el icono de Flutter)**: `adb install -r` de la compilación de `main` y luego de la nueva, sin reiniciar el lanzador: el icono del *hotseat* pasa **al instante** de Flutter a la «u.» (en API 37). **[Suposición]** cualquier lanzador que guarde el icono viejo en caché hasta reiniciarse o reinstalar es cosa del lanzador; los testers instalan desde cero. No se trata.

### Estado en que queda el emulador

- Forma de los iconos **Círculo**, estilo **Default** (sin tema), tamaño de visualización **sin *override*** (420), opciones de desarrollador **desactivadas otra vez** (`development_settings_enabled` borrado; estaban sin tocar al empezar).
- Instalada la compilación *release* nueva (`invalid.pending.app`) con la tarea «Llamar a Marta»; la `.debug` se desinstaló. **Efecto lateral:** al empezar ya había una `invalid.pending.app` instalada (de otra sesión) y se **desinstaló** para instalar la depuración (con sus datos).
- **Aviso:** un paso del guion del selector del lanzador acabó por error en «Notificaciones en la pantalla de bloqueo» y pudo tocar uno de sus interruptores sin que se notara; los valores actuales (`lock_screen_show_notifications=1`, `…_allow_private_notifications=1`, `…_show_silent_notifications=0`, `…_show_only_unseen_notifications=2`) parecen los de fábrica (el 2 no lo escribe un interruptor), pero no hay forma de comprobarlo contra el original. Sin relación con el icono.

## T-018-07: Xiaomi (2026-10-11)

Xiaomi 2506BPN68G (HyperOS), por USB. Se instaló solo `invalid.pending.app.profile` (`flutter build apk --profile --target-platform android-arm64`); la app real `invalid.pending.app` no se tocó. **Sin capturas y sin lanzar la app** (privacidad del móvil). El propietario miró a ojo y confirmó que está **«ok»** en los cuatro puntos: icono en el lanzador, en «Ajustes del sistema → Aplicaciones», en la lista de aplicaciones y con iconos con tema (CA-018-01, 02; CL-018-1). Terminado, se desinstaló la `.profile` (queda solo la real).

- **[Pendiente, 022]** TalkBack en el lanzador (C-018-7) y Android 8–12 (C-018-3); no se midieron aquí el «Tamaño de visualización» máximo ni el cuadrado de esquinas casi rectas con otro lanzador.

## T-018-08: cierre (2026-10-11)

### C-018-5 con el modo oscuro del sistema (hallazgo M1 del `a11y-reviewer`)

El revisor temía que en modo oscuro el *splash* de Android 12+ dejara la «u.» negra (`#111111`) sobre fondo negro. **Comprobado en el emulador de API 37** (`cmd uimode night yes`, arranque en frío con `screenrecord`, fotogramas cada 0,1 s; la compilación *release* instalada; el modo se devolvió a «no»):

- **[Hecho] Modo oscuro:** el sistema pinta la «u.» **sobre un círculo amarillo** (el color del icono) en una ventana negra: se ve entera y con buen contraste. No hay «u.» invisible. Después entra la app.
- **[Hecho] Modo claro (repetido):** «u.» negra sobre blanco, sin círculo, entera.
- **[Suposición]** Android 12+ elige el fondo del icono del *splash* según el contraste con la ventana; en otros fabricantes (HyperOS, One UI) puede variar. **[Pendiente, 022]** mirarlo en el Xiaomi con el modo oscuro del sistema. Para la 021 (modo oscuro y arranque): hoy el *splash* depende del sistema y no de la app; si se quiere un aspecto fijo, se fija `windowSplashScreenBackground` / `windowSplashScreenIconBackgroundColor` allí (no se toca aquí).

### Aclaración sobre el resumen de casillas

El Xiaomi se miró solo a ojo (el propietario, sin capturas): icono en el lanzador, en «Ajustes del sistema → Aplicaciones», en la lista de aplicaciones y con iconos con tema. El «Tamaño de visualización» máximo **sí** se hizo (en el emulador, 540 dpi); en el Xiaomi no. Lo que pasa a la 022 está en `docs/PLAN.md`, «Casillas de la 018».

## Resumen de casillas

| Casilla | Resultado |
|---|---|
| C-018-1 | **Hecha** en el emulador (5 formas del lanzador de Pixel, no «Forma de los iconos»; sin el cuadrado de esquinas casi rectas; la máscara de HyperOS se vio bien en el Xiaomi, T-018-07) |
| C-018-2 | **Hecha** en el emulador y en el Xiaomi (T-018-07) |
| C-018-3 | **Hecha** con tema encendido y apagado en API 37; **[Pendiente]** Android 8–12 (no hay AVD; 022) |
| C-018-4 | **Hecha** |
| C-018-5 | **Hecha**: p50 375 → 367,5 ms; *splash* con la «u.» entera sobre blanco y, en modo oscuro, sobre un círculo amarillo (T-018-08); **[Pendiente]** modo oscuro en el Xiaomi (022) |
| C-018-6 | **Hecha** |
| C-018-7 | [Pendiente] TalkBack en el Xiaomi (022) |

## Auditoría 022 (spec 022, T-022-02, 2026-10-16)

Resultados de la auditoría en dispositivo que **no** necesitan el emulador ni el Xiaomi en esta tarea (casillas cerradas por decisión del propietario, ya cumplidas por la CI o por lo que el propietario vio el 2026-10-15, y aceptadas con el resultado del emulador). El resto de casillas de esta spec se anotan aquí, con el mismo formato, en las tareas T-022-03 a 13. Inventario: `specs/022-auditoria-en-dispositivo/informe.md`.

- **C-018-3 y CA-018-05: icono adaptable amarillo con la «u.» entera y sin recorte en Android 8 y 12L; la capa monocroma no se usa** (K-022-012) — **Cerrada sin verificar** · 2026-10-16 · API 26 y 32 (no se prueba) · propietario, alcance 2 de la 022 (CA-022-06): «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.». Se conserva la comprobación de `aapt2` (el recurso está en `mipmap-anydpi`, válido desde API 26, y se ve para todas las densidades)
- **CA-018-02: el «cuadrado de esquinas casi rectas» con otro lanzador (Samsung One UI u otros)** (K-022-020) — **Cerrada sin verificar** · 2026-10-16 · Otro lanzador (no se prueba) · propietario, alcance 2 de la 022 (CA-022-07): otros fabricantes, lanzadores, lectores y versiones de Android se cierran sin hacerlas; si un tester de la beta informa de un fallo, es un hallazgo nuevo. En el lanzador de Pixel y en HyperOS la máscara se vio bien (`[Hecho]` arriba)
- **CA-018-13: *splash* de otros fabricantes (el de HyperOS en oscuro va en K-022-034)** (K-022-021) — **Cerrada sin verificar** · 2026-10-16 · Otro fabricante (no se prueba) · propietario, alcance 2 de la 022 (CA-022-07): otros fabricantes, lanzadores, lectores y versiones de Android se cierran sin hacerlas; si un tester de la beta informa de un fallo, es un hallazgo nuevo
- **CA-018-13 en el Xiaomi: *splash* con el modo oscuro del sistema** (K-022-034) — **Pasa** (a ojo) · 2026-10-16 · Xiaomi 15T Pro (HyperOS 3), *release* de `2e835cf`, a ojo, el propietario el 2026-10-15 («van bien»; hoy no consta en el repositorio) · Lo confirmó el propietario con el arranque en frío en oscuro; esa parte quedó superada por el arranque en `paper` con la «u.» de la 021 (CA-021-02). Sin captura

- **C-018-7: TalkBack lee «Una.», sin nada más como «imagen», en el lanzador, la lista de aplicaciones y Ajustes → Aplicaciones, con iconos con tema y sin ellos** (K-022-096 a 098) — **Pasa** · 2026-10-18 · Xiaomi 15T Pro (HyperOS 3), *release* de `2e835cf`, TalkBack en español · el propietario: «Lo esperado», «ok. Mismo comportamiento», «ok»

**T-022-11 (2026-10-19): Xiaomi X5, gestos, giro, «Recientes», arranque e iconos** (CA-022-26 a 28; detalle en el [informe](../022-auditoria-en-dispositivo/informe.md), §15).

- **«Tamaño de visualización» al máximo en el Xiaomi (opcional)** (K-022-156) — **Aceptada (opcional)** · 2026-10-19 · no se hizo en X5 (opcional por CA-022-28)
- **CL-018-3: iconos con tema sobre un fondo de pantalla de poco contraste (opcional)** (K-022-157) — **Aceptada (opcional)** · 2026-10-19 · no se hizo en X5 (opcional por CA-022-28)
