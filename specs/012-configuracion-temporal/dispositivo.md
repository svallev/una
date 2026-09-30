# Spec 012: pruebas en el dispositivo (T-012-09)

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, `emulator-5554`)**, 2026-09-30, sobre `2913c01` (APK *release* arm64 de la rama, `flutter build apk --release --split-per-abi --target-platform android-arm64`). **No se usó ni se tocó el Xiaomi** (todos los `adb` llevan `-s emulator-5554`). La voz real de CA-012-07 **no se repitió**: ya la comprobó el propietario en el Xiaomi (`tasks.md`, "[Hecho, propietario 2026-09-30]").

El emulador tiene el idioma del sistema en inglés; el español y el 200 % se pusieron con `cmd locale set-app-locales invalid.pending.app --locales es-ES`, `settings put system font_scale 2.0` y `wm density 480` (360 dp de ancho). Todo se dejó como estaba (`font_scale` 1,0, densidad 420, sin idioma de la app, TalkBack y Switch Access apagados, Chrome activado, `.profile` desinstalada). Las capturas y grabaciones, en el directorio temporal de la sesión (no están en el repo).

## 1. Resultado por casilla

| Casilla | Resultado | Estado |
|---|---|---|
| CA-012-08 `check-android-permissions.sh release` | Pasa: solo `INTERNET` (2 permisos revisados). Sin cambios en `schemaVersion` (2), sin `drift_schemas/` ni `pubspec.lock` en `git diff main...HEAD`; `pubspec.yaml` solo añade los 3 assets de licencias | [Hecho] |
| CA-012-08 `check-licenses.sh` sobre el APK *release* | Pasa: 84 paquetes de Dart en `NOTICES`, 46 artefactos de Android en `android.txt`, 5 bibliotecas nativas, 2 carpetas de fuentes con su OFL | [Hecho] |
| CA-012-09 "Recientes" (4 filas nuevas) | Pasa (§2) | [Hecho] |
| CA-012-01/02 tabla de niveles (Escape, atrás, menú "tal como estaba") | Pasa (§3) | [Hecho] |
| CA-012-04 confirmación, navegador y aviso | Con Chrome: confirmación "¿Abrir example.com…?", **Abrir** lanza Chrome, **Cancelar** vuelve. Con Chrome desactivado (`pm disable-user`): aviso "There's no app to open this link." bajo las opciones, sin mover el foco; se anuncia en cada intento (§4) | [Hecho] |
| CA-012-06 volver del navegador (< 10 min) | Con Chrome delante, Atrás deja el nivel 1 abierto | [Hecho] |
| CL-012-11 el sistema mata la app con la pantalla abierta | `am kill` con el nivel 1 abierto: proceso muerto; al abrir, la tarea actual (no se restaura) | [Hecho] |
| CA-012-14 (enmendado) web y CL-012-1 | Sobre la tarea web (wikipedia.org), desplazada hacia abajo: abrir el nivel 1 y volver recarga la página desde arriba | [Hecho] |
| CL-012-3 giro | Con una tarea con imagen (que sí gira), `adb emu rotate` con el nivel 1, el nivel 2 y la confirmación abiertos: la pantalla se queda en vertical (1080×2400); la tarea sin pantalla abierta sí giró (2400×1080) | [Hecho] |
| CA-012-07 idioma en caliente | ES → EN con el nivel 1 abierto (y el aviso visible): cambia sin cerrarse. La voz: del propietario (Xiaomi) | [Hecho] (voz: propietario) |
| CA-012-13 200 %, 360 dp, ES y EN | Niveles 1, 2 y 3 y aviso: sin solapes ni desbordes; título en 2 líneas. **Observación:** `_fe_analyzer_shared` (paquete de desarrollo, 19 letras sin hueco) se parte en mitad de la palabra ("_fe_analyzer_share / d") en ES y EN (§5) | [Hecho] con observación |
| CA-012-13 reducir movimiento | Fundido con animaciones normales: el brillo de la pantalla sube en ~9 fotogramas (≈ 145-160 ms). Con `transition_animation_scale` 0: un solo fotograma | [Hecho] |
| CA-012-11 TalkBack: primer nodo = título | Nivel 1 (desde el menú), nivel 2 y nivel 3: el recuadro de TalkBack sale sobre el título y dice su texto | [Hecho] |
| CA-012-11 cada fila "nombre, N licencias"; pista; singular y plural | En el árbol de accesibilidad: "_fe_analyzer_shared, 1 license", "abseil-cpp, 2 licenses", "accessibility, 16 licenses"; "Privacy policy, Opens a web page in the browser" | [Hecho] (leído del árbol, no oído) |
| CA-012-11 aviso por intento | Con TalkBack: el panel de voz dice "There's no app to open this link." en cada intento (también tras salir y volver) y el foco sigue en el título | [Hecho] |
| CA-012-11 foco al volver en los tres saltos, tras Cancelar y del navegador | **No verificable con `adb`**: los toques inyectados activan sin mover el foco de TalkBack (conocido desde T-006-16). Con el foco de TalkBack en el título, al volver se queda en el título (nivel 3 → 2 → 1 → menú: "This task"); con el foco del teclado, al volver queda en la opción (§3) | **[Pendiente]** a mano (Xiaomi o emulador con ratón) |
| CA-012-15 estados | Nivel 2 **48 ms** hasta ver la lista (*profile*, test). Error: con el registro vacío (binding de pruebas) sale "Couldn't load the licenses." con "Try again" bien maquetado. "Cargando licencias…" no se llega a ver (la lista tarda < 50 ms); el anuncio de carga y el foco en Reintentar con TalkBack **no se pudieron comprobar** | **[Pendiente]** anuncio de carga y foco en Reintentar |
| CA-012-15 p90 de fotogramas al desplazar (*profile*) | §6: construcción p90 1,5 ms; rasterizado p90 17,1 ms en el emulador (sin GPU), igual que el listado de la 006 en el mismo emulador (17,7 ms) | [Hecho] con salvedad (§6) |
| CA-012-12 teclado | Escape sube un nivel en los tres (y cierra la confirmación); Escape después de tocar; Tab recorre Cerrar → título → opciones, Intro activa, el nivel 3 se desplaza con Tab + AvPág / flechas / Fin hasta la licencia 57 de 57 (§3). **El anillo de foco no se ve** en el emulador (solo el borde verde de ventana, como en T-010-10 e) | Orden y acciones [Hecho]; anillo **[Pendiente]** |
| CA-012-12 Switch Access | El servicio se activó y el asistente asignó dos teclas (Siguiente = flecha derecha, Seleccionar = centro), pero al pulsarlas **no apareció ningún resaltado** en la app ni avanzó el foco | **[Pendiente]** a mano (el propietario ya lo dio por bueno en 006/010; no se repite aquí) |
| CA-012-16 arranque en frío alternado | p50 +14 ms de mediana (+3,7 % de media) con la nueva; dentro del ruido del emulador pero sin poder afirmar que no empeora (§7) | [Hecho] con salvedad |

## 2. CA-012-09: "Recientes" (las 4 filas)

`tools/check-recents.sh emulator-5554 capture|compare|secure|loop`, con A = tarea "SECRETO-UNO" y B = la misma tarea editada ("SECRETO-UNSECRETO-DOS"); se pasa por el escritorio, como CA-011-01. Las cuatro filas nuevas de la matriz de CA-011-02 (ya anotadas en `specs/011-ocultar-recientes/dispositivo.md` §3.2):

| Fila | Parecido A / B | Tarjetas A y B (px distintos) |
|---|---|---|
| Nivel 1 "Configuración y perfil" | 0,003 / 0,003 | idénticas (0 %), lisas (desv. 0,00) |
| Nivel 2 lista de licencias | -0,003 / -0,003 | idénticas (0 %), lisas |
| Nivel 3 texto de una licencia | -0,010 / -0,010 | idénticas (0 %), lisas |
| Confirmación de enlace (sobre el nivel 1) | 0,024 / 0,024 | idénticas (0 %), lisas |

- `secure` con la confirmación abierta: "not-secure" (sin `FLAG_SECURE` con la app delante, como en la 011). `loop 3` con la confirmación abierta: parecido 0,024 las 3 vueltas.
- No se repitió con imagen ni con web debajo: la 011 ya cubre esas filas y la pantalla es la misma.

## 3. Niveles, teclado y foco

Con `adb shell input keyevent` (la app recibe Escape, Tab, Intro, AvPág, flechas y Fin) y el árbol de `uiautomator` (`focused` = foco de entrada):

- **Escape:** nivel 3 → nivel 2 → nivel 1 → menú (con el menú "tal como estaba") → tarea. También después de haber llegado tocando. Con la confirmación abierta, Escape la cierra.
- **Orden de Tab** desde el nivel 1 recién abierto (foco en el título): 1.ª opción → 2.ª opción → Cerrar → título → (vuelve a empezar, pasando un momento por la ventana). Intro sobre la 1.ª opción abre el nivel 2; sobre la 2.ª, la confirmación; sobre Cerrar, vuelve al menú. Tras Escape desde el nivel 2, Tab + Tab + Intro cerró la pantalla: el primer Tab fue a "Política de privacidad" y el segundo a Cerrar, luego el foco de entrada había vuelto a "Licencias de código abierto" (tabla de niveles; inferido del orden).
- **Nivel 3** (`angle`, 57 licencias): Tab lleva a la lista; AvPág, AvPág, flecha abajo y Fin la desplazan; al final se ve "License 57 of 57". Cada licencia lleva su encabezado "License n of 57".
- **[Hecho, limitación]** Con Tab no se ve ningún anillo en las capturas (ni en el menú ya existente): Flutter no pasa a "resaltado tradicional" con teclas inyectadas, igual que se anotó en T-010-10 (e). El anillo lo cubren los tests (`FocusHighlightMode.traditional`).

## 4. TalkBack (recuadro verde + panel de voz, capturas)

- El foco de TalkBack se lee en capturas (recuadro verde) y el panel "TalkBack" dice el último texto. `uiautomator dump` **borra** ese recuadro un momento: no lanzarlo justo antes de mirar.
- **No se puede mover el foco de TalkBack con `adb`:** `input swipe`, `input keycombination` (Alt + flecha), los eventos de teclado y de toque de la consola (`adb emu event send`) o no llegan a TalkBack o no cambian el foco; `input tap` activa el control sin mover el foco. Es el límite ya anotado en T-006-16; de ahí los [Pendiente].
- Observado (foco en el título, que es donde llega): L1 "Settings and profile"; L2 "Open-source licenses"; L3 "abseil-cpp" / "_fe_analyzer_shared" / "angle"; al volver del nivel 3 al 2 y al 1, y del nivel 1 al menú, el foco queda en el título o en el primer nodo ("THIS TASK"): coherente con que TalkBack no mueve el foco por una petición de la app (memoria "Verificar TalkBack en el emulador"). Lo que pasa cuando el foco de TalkBack estaba en la fila al activarla **no se pudo comprobar**.

## 5. Observaciones

1. **Aviso "No hay ninguna app…" al volver del nivel 2:** si se ve el aviso, se entra en el nivel 2 y se vuelve, **sigue visible** (el `State` del nivel 1 no se destruye). El plan dice "se oculta al abrir con éxito y al salir del nivel 1". No contradice la spec (que no dice nada), pero conviene saberlo.
2. **Palabra partida al 200 %:** `_fe_analyzer_shared` (ver la tabla). Es un paquete de desarrollo que la spec acepta mostrar "tal cual"; ninguna licencia de *release* tiene un nombre tan largo. Si se quiere evitar, habría que ocultar los paquetes de desarrollo (decisión del propietario: no).
3. **Nombre en español en inglés:** "Bibliotecas de Android (AndroidX, Kotlin)" sale así con la app en inglés (la [Suposición] de T-012-02, según la spec).
4. **Arranque** (§7): la diferencia es pequeña y dentro del ruido, pero la nueva salió igual o peor en las cuatro parejas.

## 6. Fotogramas al desplazar (CA-012-15)

`integration_test/licenses_perf_test.dart` (nuevo; `flutter build apk --profile` + `flutter drive --profile --no-dds --keep-app-running --use-application-binary`, app `.profile` aparte, desinstalada después): abre el menú, la Configuración y el nivel 2 con **196 elementos reales** (el binding de pruebas no carga `NOTICES.Z`: el test lo registra igual que el motor), y hace 6 lanzamientos abajo y 6 arriba en la lista y lo mismo en el texto de `angle` (57 licencias). Control: `task_list_perf_test.dart` (500 tareas, spec 006) en el mismo emulador.

| Medida (emulador *profile*, sin GPU) | Lista de licencias | Texto de `angle` | Listado 500 tareas (006, control) |
|---|---|---|---|
| Abrir el nivel 2 hasta ver la lista | **48 ms** (< 300) | — | 59 ms |
| Fotogramas | 1149 | 1237 | 1238 |
| Construcción p50 / p90 / p99 | 0,6 / 1,5 / 2,7 ms | 0,5 / 1,2 / 2,2 ms | 0,5 / 1,5 ms |
| Rasterizado p50 / p90 / p99 | 15,2 / 17,1 / 20,9 ms | 16,3 / 17,5 / 18,9 ms | 16,2 / 17,7 / 18,8 ms |

- **[Hecho]** La construcción (hilo de la interfaz) está muy por debajo de 16,7 ms.
- **[Suposición]** El rasterizado de ~16-17 ms es del emulador (sin GPU, ritmo de 60 Hz): el listado de la 006, ya aprobado con 0 fotogramas fuera de presupuesto **en el Xiaomi**, da lo mismo aquí (17,7 ms). **[Pendiente]** la cifra real (Xiaomi, con permiso del propietario): `flutter drive --profile … --target=integration_test/licenses_perf_test.dart`.

## 7. Arranque en frío alternado (CA-012-16)

Base = `main` (`c576d3f`), sacada con `git archive` a un directorio temporal; nueva = la rama. Las dos, `--release --split-per-abi --target-platform android-arm64` (28,7 y 28,8 MB). Ocho pasadas alternadas de 20 arranques con `tools/measure-cold-start.sh emulator-5554 20` (antes de cada una, `adb install -r` y un arranque de calentamiento con 6 s de espera). Tarea actual: imagen ("dos"), la misma en todas.

| Pasada | Compilación | mín | **p50** | p90 | máx |
|---|---|---|---|---|---|
| 1 | base | 417 | **437** | 465 | 935 |
| 2 | nueva | 410 | **451** | 506 | 588 |
| 3 | base | 409 | **438** | 477 | 484 |
| 4 | nueva | 431 | **476** | 629 | 1326 |
| 6 | nueva | 425 | **478** | 569 | 586 |
| 5 | base | 412 | **477** | 530 | 599 |
| 8 | nueva | 439 | **476** | 538 | 688 |
| 7 | base | 417 | **462** | 535 | 665 |

- Por parejas (base → nueva): +14, +38, +1, +14 ms de p50; media de la base 453,5 ms frente a 470,3 ms de la nueva (**+17 ms, +3,7 %**). Hay deriva entre pasadas (la base sube de 437 a 477 en el tiempo), así que las parejas están ordenadas alternando.
- **[Hecho]** p50 < 500 ms (P2: < 1 s). **[Hecho]** el mecanismo: ninguna licencia se lee antes del primer fotograma (`startup_licenses_test.dart`, CA-012-16).
- **[Suposición]** la diferencia es ruido del emulador (el mismo binario varía 40 ms entre pasadas), pero la nueva no fue mejor en ninguna pareja. **[Pendiente]** la cifra real en el Xiaomi (con permiso): `tools/measure-cold-start.sh` con la release de la rama frente a la de `main`.

## 8. Pendiente (a mano o con permiso)

- [ ] Foco de TalkBack al volver en los tres saltos, tras Cancelar y tras el navegador (hace falta mover el foco de TalkBack a la fila antes de activarla; `adb` no puede).
- [ ] TalkBack: anuncio de "Cargando licencias…" y foco en "Reintentar" (error) y su pista; recuento leído en voz (se comprobó en el árbol, no a oído).
- [ ] Anillo de foco visible con un teclado real (Xiaomi con teclado, o emulador con el teclado del ordenador).
- [ ] Switch Access: recorrer, activar y desplazar (el servicio se activó y se asignaron teclas, pero no apareció resaltado).
- [ ] p90 de fotogramas (rasterizado) y arranque en frío en el Xiaomi (permiso del propietario).
- [ ] CA-012-06 a los 10 minutos con el reloj real (lo cubre `home_router_test.dart`, 9:59 y 10:00).
- [ ] Los 3 *goldens* de T-012-06 por generar en CI (`actualizar-goldens`).
