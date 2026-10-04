# Spec 014: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, `emulator-5554`, idioma del sistema en inglés)**. **No se usó ni se tocó el Xiaomi** (todos los `adb` llevan `-s emulator-5554`). Las capturas, en el directorio temporal de la sesión.

## T-014-06: foco de TalkBack en la card (2026-10-04)

Método: TalkBack activado con `settings put secure enabled_accessibility_services …` (con el panel de voz visible), un `integration_test` **temporal** (no se sube) que lleva la app real (APK de depuración, base de datos vacía) por cada camino y se queda quieto 20 s en cada paso, y un guion que captura la pantalla al ver cada marca `UNA-STEP` en la salida de `flutter test`. TalkBack no hace caso de los toques de `adb`, así que las pulsaciones son de Flutter (`tester.tap`) y la acción del lector, la del árbol semántico. Se mira el recuadro verde de TalkBack y lo que dice el panel de voz. Tareas: "Primera", "Segunda", una foto sin archivos y sin texto ("Adjunto no disponible"), "Cuarta" y dos páginas web (`example.org`, `example.com`).

| Camino | Resultado | Estado |
|---|---|---|
| Menú → "Eliminar" (CA-014-01, CA-014-16) | El recuadro verde rodea la card (franja negra de abajo) y el panel dice "Undo. Task deleted: Primera … Double-tap to activate". Se lee una vez. La barra queda detenida mientras el foco está en la card (22 s después sigue `visible`; barra llena a los 2 y 5 s en 6 menús, ver la observación de la primera pasada) | [Hecho] |
| Acción del lector "Eliminar tarea" sobre la tarea, **con la card de la anterior a la vista** (CA-014-08) | Foco en la card nueva, "Undo. Task deleted: Segunda"; la barra llena y del color de la nota eliminada | [Hecho] |
| "Adjunto no disponible" → "Eliminar tarea" (CA-014-01, CA-007-19) | Foco en la card, etiqueta "Photo", barra del color de la foto eliminada | [Hecho] |
| Horizontal (página web a pantalla completa, girada con `adb emu rotate`) → acción del lector | La card sale abajo, sobre la web siguiente, y el recuadro verde está en ella; TalkBack anuncia la orientación al girar, pero el foco sigue en la card | [Hecho] |
| Giro forzado a vertical (la siguiente tarea es de texto, CA-008-11) | La app vuelve a vertical y la card sigue en pantalla con el foco: "Undo. Task deleted: example.com" | [Hecho] |

Resultado: **el foco del lector llega a la card en los cinco caminos** (evento de foco + foco de entrada, P-014-3). No hizo falta cambiar el plan.

### Observaciones

- **[Pendiente, no reproducido]** En la primera pasada, en el primer camino (menú), la barra estaba al 70 % a los 5 s, con el foco ya en la card; es decir, la cuenta corrió ≈ 1,2 s antes del primer foco, contra CA-014-17 ("con el lector, el tiempo no empieza hasta el primer foco"). En 7 pasadas más (3 menús seguidos dos veces, la acción, el botón, horizontal y vertical) la barra estaba siempre llena a los 2 y a los 5 s. Era la primera tarjeta tras instalar la app y encender TalkBack un minuto antes. **[Suposición]** `MediaQuery.accessibleNavigation` aún era falso al dibujarse esa primera card. Se vuelve a mirar en la pasada completa (T-014-10).
- El foco en la card se comprueba por el recuadro y la voz; no se midió el tiempo exacto hasta el foco ni se probó con el texto al 200 % (T-014-10).
- Girar con `adb emu rotate` (sensor virtual): `settings put system user_rotation` y `wm user-rotation lock` no hacen girar la app, que gira por `OrientationEventListener`.
- Al terminar: TalkBack apagado, `accelerometer_rotation` 1, rotación en 0, el `integration_test` temporal borrado.

## T-014-08: listado con TalkBack (2026-10-04)

Mismo método que en T-014-06 (emulador `Pixel_6a`, API 37, inglés; `integration_test` **temporal**, no se sube; TalkBack activado con `settings`; capturas a 1 y 3 s de cada paso; acciones del árbol semántico, no toques de `adb`). Cinco tareas ("Primera" a "Quinta"). **No se usó el Xiaomi.**

| Paso | Resultado | Estado |
|---|---|---|
| Eliminar "Segunda" con la acción "Eliminar tarea" de la fila (CA-014-02, CA-014-19) | La fila desaparece, la card ocupa el sitio de "Nueva tarea" y el recuadro verde de TalkBack está en ella ("Button, Task deleted, Segunda, Undo"); barra del color de la nota | [Hecho] |
| Segunda eliminación con la card a la vista (CA-014-08) | La misma card cambia a "Tercera" (barra de su color, llena) y el foco vuelve a ella | [Hecho] |
| Deshacer desde el listado (CA-014-10, CA-014-18) | La fila vuelve a su sitio ("2 of 4. In list. 4 items") **con el foco de TalkBack en la fila**. **Fallo en la primera pasada:** el foco se quedaba en el título "All tasks" | [Hecho] tras el arreglo |
| Eliminar las demás hasta la última pendiente (CA-014-02) | "All done." con la card ("Double-tap to activate", etiqueta "Primera", sin "Crear una tarea") y el foco en la card | [Hecho] |
| Deshacer desde "Todo hecho." (CA-014-10, CA-014-18) | Se abre otra vez el listado y, tras la transición, el foco está en la fila ("1 of 1. Current task: Primera"). **Fallo en la primera pasada:** el foco se quedaba en el texto de ayuda (primer nodo de la ruta nueva) | [Hecho] tras el arreglo |

**Fallo y arreglo.** El aviso de foco (`FocusSemanticEvent`) a la fila **sí se enviaba** (comprobado con trazas) pero TalkBack lo ignoraba, aun esperando 500 ms o 1,2 s: el foco se quedaba en el título o en la ayuda. TalkBack sigue el **foco de entrada**, y el nodo de la fila (`excludeSemantics`) no lo reflejaba (su control está dentro de lo excluido). **Arreglo:** el nodo de la fila lleva `focusable` y `focused` según el `FocusNode` de su control (`TaskListRow`, `ListenableBuilder`); con eso TalkBack lleva su foco a la fila. Esperas: 160 ms tras quitarse la card y 600 ms si el listado es una ruta nueva (con 160 y 600 ya funciona en los dos caminos; no se probaron valores menores).

### Observaciones

- El panel de voz de TalkBack tapa "Nueva tarea" en las capturas (no es de la app).
- No se midió con el lector el tiempo hasta el primer foco ni el texto al 200 % (T-014-10).
- Ajustes restaurados: TalkBack apagado, `integration_test` temporal borrado.

## T-014-10: pasada completa en el emulador (2026-10-04)

Emulador `Pixel_6a` (API 37, `emulator-5554`, inglés), **sin tocar el Xiaomi**. Tres métodos: (a) la APK de depuración normal con `adb` (sin TalkBack) y medición de la barra con capturas cada 0,5–1 s; (b) para TalkBack, un `integration_test` **temporal** (no se sube) con un repositorio que puede fallar, que escribe la fracción de la barra y la fase del controlador cada 250 ms y marcas `UNA-STEP`, con `screenrecord` y capturas del recuadro verde y del panel de voz de TalkBack al ver cada marca (fotogramas con un script de Swift); (c) para el teclado, **teclas de un dispositivo real** del emulador (ver la trampa en `spec-task.md`: las de `adb shell input keyevent` no cambian el modo de foco de Flutter). Ajustes tocados y **restaurados** (comprobado al final): TalkBack y Switch Access, `accessibility_interactive_ui_timeout_ms`, escalas de animación, `font_scale`, densidad, rotación, navegación de 3 botones.

| Casilla | Resultado | Estado |
|---|---|---|
| TalkBack: se lee una vez y empieza por "Deshacer" (CA-014-16) | Pantalla principal y listado: el panel dice "Undo. Task deleted: X" → "Button" → "Double-tap to activate", una sola lectura; recuadro verde en la card | [Hecho] |
| Tiempo hasta el primer foco (CA-014-17) | Con TalkBack el recuadro ya está en la card en la primera captura (≈ 0,3 s en el listado, ≈ 0,5 s en la principal); la barra se queda en 1,000 durante 9 s (principal) y 6 s (listado) | [Hecho] |
| El tiempo se detiene con el foco y sigue al salir (principal) | Foco fuera 3 s → 0,697; vuelve → se detiene en 0,684 (13 ms de deriva) 3 s; sale otra vez → sigue desde 0,684 hasta 0 en ≈ 7 s | [Hecho] |
| Lo mismo en el listado | **No se pudo simular**: `previousFocus()` / `FocusSemanticEvent` mueven el foco de entrada pero TalkBack se queda en la card del listado (el mismo código sí lo siguió en la principal). Hace falta un gesto real de TalkBack | [Pendiente] 022 |
| También al girar (CL-014-8) | Card con foco sobre la web, giro a horizontal con `adb emu rotate`: la card sigue, el foco se conserva ("Landscape"), barra 1,000 durante 10 s | [Hecho] |
| Duración con TalkBack | Con TalkBack activo y sin "Tiempo para actuar" definido la card dura **10 s** (la barra baja 0,1/s al salir el foco): es el valor que da `getRecommendedTimeoutMillis`, no 4 s | [Hecho] (**observación**) |
| Deshacer desde la tarea, el listado y "Todo hecho." con un anuncio (CA-014-18) | **Foco bien**: tarea ("Current task: X"), fila ("3 of 3: Quinta … In list"); en "Todo hecho." ya se verificó en T-014-08 (no repetido). **Fallo: "Task restored" no se ve en el panel de voz** en ninguna de las 5 pruebas (principal ×3, listado, "Reintentar"), muestreadas cada 0,15–0,2 s. **Control:** un anuncio suelto con el mismo método (`SemanticsService.sendAnnouncement`, "Control announcement", sin nada más) tampoco aparece | **[Fallo / Pendiente]** ver hallazgo 1 |
| Aviso de error al recuperar (CA-014-23) | Repositorio que falla en `insert`: "We couldn't restore the task" **se lee una vez**, el recuadro va a "Try again" (lee "Try again → Button → Double-tap…"), el aviso queda por encima de "Pulsa para completar"; con el fallo resuelto, "Try again" recupera la tarea y el foco va a ella | [Hecho] |
| Aviso de error al eliminar (CA-014-22) | "We couldn't delete the task" se lee una vez y el foco pasa a la tarea actual (la spec no pide foco en "Reintentar" aquí) | [Hecho] |
| `accessibility_interactive_ui_timeout_ms` 10000 y 120000 | 10000: la barra baja 0,1/s (10 s); 120000: 0,83 a los 20 s y 0,49 a los 62 s | [Hecho] |
| `animator_duration_scale` 0 (con las otras dos) | La card dura 4 s igual (0,25/s); sin arrugado (la card sale a ≈ 1 s); entra solo con fundido (3 fotogramas) en su sitio, sin desplazamiento | [Hecho] |
| Cortina y diálogo del sistema (no cuentan) | `cmd statusbar expand-notifications` 4 s: la card y la cuenta siguen. Diálogo del sistema: el Asistente de Google (pulsación larga de encendido) tapa la parte de abajo y al cerrarlo la card sigue con la cuenta corriendo | [Hecho] |
| Inicio, "Recientes" y pantalla bloqueada (definitiva) | Tras cada una (`KEYCODE_HOME`, `KEYCODE_APP_SWITCH`, `KEYCODE_SLEEP` + `WAKEUP`) la card ya no está al volver y la tarea no vuelve | [Hecho] |
| Teclado: Tab, anillo, Intro, Espacio, Escape | Con Tab real: el foco va al botón del menú y al siguiente Tab a "Deshacer", con **anillo blanco visible sobre el negro** y la barra **detenida** (0,97 fija); Escape (`input keyevent`) no hace nada (la card y la app siguen, la barra sigue parada); Tab fuera → la barra sigue; **doble Intro real → una sola recuperación**, foco en la tarea; **Intro mantenido** 1,8 s (`--duration`) → una recuperación, 5 tareas (no completó nada) | [Hecho] |
| Switch Access con el teclado como interruptor | Se activó con `settings` (Siguiente = DPAD_RIGHT, Seleccionar = DPAD_CENTER, valores por defecto). El primer elemento del barrido es la card: **DPAD_CENTER la activó y recuperó la tarea**. **Pero** con Switch Access activo `accessibleNavigation` es `true` y **la barra no se movió en ningún momento** (1,000 durante 7 s sin tocar nada y 6 s con el barrido) | **[Fallo]** ver hallazgo 2 (resuelto en T-014-10b) |
| `tools/check-recents.sh` con la card visible | Tarea (sobre una web), listado, "Todo hecho." y con el aviso de error: **bien** (tarjeta visible y lisa, desv. 0,00; el aviso de error se vio en la captura de delante y no en la tarjeta). En **horizontal**, el script da "FALLO … desv. 14,03" **igual sin la card** (0 → 14,03): es la forma de la miniatura (franja negra del sistema + blanco, sin contenido); límite del script, no de la card | [Hecho] (con la nota) |
| 200 % en vertical y en horizontal con navegación de 3 botones (capturas para el propietario) | Vertical: la card crece, el texto al 200 %, "Deshacer" entero al lado; con una etiqueta larga, **2 líneas con "…"** y "Deshacer" al lado; la web acaba encima de la card. Horizontal: la card respeta la barra de navegación lateral, "Deshacer" entero y la web acaba encima. Listado al 200 %: las filas y la card caben, el listado acaba encima de la card. Capturas: `CAPTURA_200_*.png` en el directorio temporal de la sesión | [Hecho] |
| Card a 600 dp o más (`appFrame`) | Con una pantalla de 720 dp en vertical y una tarea de texto, la card mide **600 dp, centrada, como el resto de la pantalla** (no a todo el ancho; con un visor en horizontal sí lo es). Coherente con CL-001-7, pero la spec dice "a todo el ancho" | [Pendiente de decisión] ver hallazgo 3 |
| Barra al 70 % de T-014-06 | No se reprodujo: en 5 pasadas con TalkBack la primera card tras instalar y encender el lector tuvo la barra en 1,000 desde el primer fotograma | [Hecho] (no reproducible) |

### Hallazgos

1. **"Tarea recuperada" no se oye en API 37.** Ni el anuncio de `a11yUndone` ni uno de control (`SemanticsService.sendAnnouncement` suelto) salen en el panel de voz de TalkBack; sí salen la lectura del foco, "Portrait", "Landscape" y los avisos de error (región en vivo). Puede ser TalkBack de API 37 (los anuncios de `announceForAccessibility`, obsoleto desde la 36, riesgo ya anotado en el plan §9) o el panel, y afectaría a **todos** los anuncios de la app (specs 002–013), no solo a esta. Recomendación: no tocar el código ahora; comprobar con la voz real en el móvil (022) y, si tampoco suena, abrir una spec o un ADR aparte (no depender de anuncios: foco + `liveRegion`).
2. **[Resuelto en T-014-10b, ver abajo]** **Switch Access cuenta como lector.** El plan §1 dice que `accessibleNavigation` solo refleja TalkBack: **no es cierto en API 37** (con Switch Access activo vale `true`, `features=[accessibleNavigation, …]`). Resultado: la cuenta atrás "espera al primer foco" y, si el usuario no llega con el barrido a la card, **no caduca nunca** (la card se queda hasta que algo la haga definitiva); el §6 de la spec y la excepción de 10 s de la constitución dan por hecho que con Switch Access el tiempo corre. Recomendación (decisión del propietario): leer `isTouchExplorationEnabled` por el canal `una/a11y` (un campo más) y usar eso, no `accessibleNavigation`, para "lector"; o aceptar el comportamiento y enmendar la spec (CA-014-17 y §6).
3. **600 dp.** En una pantalla ancha con una tarea de texto, la card (y su fondo negro) mide 600 dp centrada, como "Pulsa para completar". Recomendación: aceptarlo, que es lo que hace el resto de la app, y registrarlo en DEV-51 (la spec dice "pegada abajo a todo el ancho", que vale en móvil y con visores a pantalla completa).
4. **Observaciones menores:** con TalkBack la card dura 10 s (valor del sistema); el panel de voz de TalkBack tapa la card en las capturas (no es de la app); `settings put system font_scale` no llega a la app abierta (hay que `am force-stop` y volver a abrirla).

### Lo que no se hizo

Mover el foco de TalkBack fuera de la card en el listado (hace falta un gesto real), "Todo hecho." con la voz (ya en T-014-08), Voice Access, API 26 y 28, Xiaomi, el p90 de raster del arrugado (T-014-09; en el móvil, **[Pendiente]** con permiso).

## T-014-10b: Switch Access no cuenta como lector (2026-10-04)

Arreglo del hallazgo 2: `una/a11y` devuelve también `touchExploration` (`AccessibilityManager.isTouchExplorationEnabled`) y la espera al primer foco y el foco de entrada de la card usan eso, no `MediaQuery.accessibleNavigation`. Emulador `Pixel_6a` (API 37), **sin tocar el Xiaomi**; `integration_test` **temporal** (no se sube) con la app real que elimina la tarea desde el menú y escribe cada 250 ms la fase y la fracción de la barra. Ajustes restaurados al acabar (`enabled_accessibility_services` nulo, `accessibility_enabled` 0).

| Ajustes | Resultado | Estado |
|---|---|---|
| Sin servicios (referencia) | `accessibleNavigation=false`, `reader=false`; la barra baja 1/4 por segundo y la card caduca a los 4,03 s | [Hecho] |
| TalkBack | `accessibleNavigation=true`, `reader=true`; la barra queda en 1,000 durante los 14 s (espera el primer foco y se detiene con él); captura a los 3,5 s: recuadro verde de TalkBack en la card y la barra llena | [Hecho] |
| Switch Access, TalkBack apagado | `accessibleNavigation=true` pero `reader=false`; la barra baja desde el primer fotograma (0,93 a 0,3 s, 0,06 a 3,8 s) y la card caduca a los ≈ 4,0 s; no se pide foco de entrada | [Hecho] |

Con Switch Access en API 37 no hay "Tiempo para actuar" definido (`interactiveUiTimeout=0`), así que dura 4 s; con el ajuste puesto duraría lo que diga el sistema (CA-014-06). **[Suposición]** TalkBack y Switch Access a la vez: `accessibleNavigation` ya es `true` y no cambia al encender el segundo, así que ese cambio con la app abierta no hace releer el canal (poco probable; la siguiente eliminación lo lee de nuevo).
