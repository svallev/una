# Spec 015: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, `emulator-5554`, idioma del sistema en inglés)**. **No se usó ni se tocó el Xiaomi.** Capturas en el directorio temporal de la sesión (no se suben).

## T-015-09: Ajustes (nivel 1) con TalkBack (2026-10-05)

Método (como en la 014): TalkBack activado con `settings put secure enabled_accessibility_services …`, un `integration_test` **temporal** (no se sube) que lleva la app real (APK de depuración, base de datos vacía) por los pasos y se queda quieto 5-6 s en cada uno, y un guion que hace `screencap` al ver cada marca `UNA-STEP` (recuadro verde de TalkBack + panel de voz). Los toques los da el test, no `adb`.

| Casilla | Resultado | Estado |
|---|---|---|
| Foco del lector al abrir Ajustes (CA-015-02, tabla de niveles) | El recuadro verde está en el título "Settings" y **Cerrar no lo roba** (en modo táctil/TalkBack no se le pide el foco de teclado) | [Hecho] |
| Foco a "Idioma" al volver de la página de Idioma (CA-015-08 paso 4, CA-015-20h), tras Volver y tras elegir "Español" | **Fallo en la primera pasada:** el foco se quedaba en el título. **Causa:** el nodo de `SettingsRow` no reflejaba el foco de entrada (como en el listado de la 014). **Arreglo:** `SettingsRow` y `UnaSwitchRow` llevan `focusable`/`focused` de su `InkWell`. Tras el arreglo el recuadro está en la fila "Language"/"Idioma" (ya con el valor "Español") | [Hecho] tras el arreglo |
| Foco a la fila al cancelar la confirmación de enlace (CA-015-12a) **[obsoleta: la confirmación se retiró en T-015-07b; esta fila es historial]** | **Fallo en la segunda pasada:** el foco acababa en "Idioma" (el sistema de foco devuelve el foco al último control justo cuando la confirmación termina de irse, y la petición llegaba antes). **Arreglo:** margen de 120 ms tras `sheetOut` en `openExternalPage`. Tras el arreglo: recuadro en "Ayuda" y el panel dice "Ayuda, Abre una página web en el navegador" (el aviso "abre una página web" va **en el nombre**) | [Hecho] tras el arreglo |
| Interruptor con su estado | Con el foco en la fila, el panel dice "Pantalla siempre activa, Imágenes, documentos y web"; al activarlo, el pomo cambia de lado y el recuadro se queda en la fila. **No se vio en el panel la palabra del rol/estado** ("Switch, On/Off"); el panel solo enseña el último fragmento | [Pendiente] 022 / T-015-14 |
| Marca de idioma de "Español"/"English" (CA-015-11) | Camino A: `attributedLabel` con `LocaleStringAttribute` por tramo, comprobado en el árbol de `flutter test` (`semantics_language_test`, `settings_screen_test`). El visor de TalkBack no enseña la voz ni los `LocaleSpan`; **no se puede decidir A/B/C en el emulador** | [Pendiente] 022 (con el móvil y el permiso del propietario) |
| Aviso de guardado / de enlace (anuncio único y repetición) | No probado aquí (T-015-14) | [Pendiente] T-015-14 |

Al terminar: TalkBack apagado (`settings delete` + `accessibility_enabled 0`), `integration_test` temporal borrado y datos de la app borrados.

## T-015-10: vuelta a la tarea con TalkBack (2026-10-05)

Mismo método que en T-015-09 (emulador `Pixel_6a`, API 37, inglés, `emulator-5554`; `integration_test` **temporal** que lleva la app real por los pasos, TalkBack activado con `settings`, `screencap` al ver cada marca). **No se usó el Xiaomi.**

| Casilla | Resultado | Estado |
|---|---|---|
| Menú → «Settings» (CA-015-01a, P-015-1) | El menú se cierra y Ajustes sube; recuadro verde en el título «Settings» (Cerrar no lo roba) | [Hecho] |
| Cerrar ajustes → foco al botón de menú (CA-015-02) | La tarea con el menú cerrado y el recuadro verde en el botón de menú («Double-tap to activate»), sin tocar nada más. A la primera, sin arreglos | [Hecho] |
| Volver del navegador tras ≥ 10 minutos (CA-015-16): Ajustes → Política → «Open» → Chrome, 11 min 20 s fuera | La tarea actual, sin Ajustes ni menú, con el recuadro verde en el botón de menú | [Hecho] |
| Voz de TalkBack al llegar al botón, panel de voz | Solo se ve el texto del panel («Double-tap to activate»); la voz y el anuncio completo no se comprueban en el emulador | [Pendiente] 022 |

Notas: el *bucle* del test temporal (`tester.pump` con la app en segundo plano) no avanzó mientras Chrome estaba delante, así que el guion trajo la app al frente por tiempo (`monkey -p invalid.pending.app.debug -c android.intent.category.LAUNCHER 1`). Ajustes restaurados: TalkBack apagado (`settings delete` + `accessibility_enabled 0`), Chrome y la app detenidos, datos de la app borrados, `integration_test` temporal borrado.


## Xiaomi del propietario: TalkBack y voz a oído (2026-10-05)

Versión de depuración (`invalid.pending.app.debug`, paquete aparte, sin tocar la app real ni sus datos) instalada desde `HEAD` tras T-015-10 (sistema en español, Android 16); TalkBack activado con `settings` y el propietario recorrió el guion a oído. Sin capturas. Al terminar: TalkBack apagado, paquete de depuración desinstalado.

| Casilla | Resultado | Estado |
|---|---|---|
| Foco al título «Ajustes» al abrir (Cerrar no lo roba) | Correcto (propietario) | [Hecho] |
| «Idioma, Como el sistema» y la voz de «Español»/«English» (CA-015-11, camino A) con la app en español y en inglés sobre un sistema en español | Correcto (propietario): cada nombre suena con su voz | [Hecho] |
| Interruptor «Pantalla siempre activa»: estado dicho una sola vez por toque | Correcto (propietario) | [Hecho] |
| Filas de web: «abre una página web» en el nombre; foco al cancelar la confirmación | Correcto (propietario), **con la confirmación de entonces**; la confirmación se retira después por decisión del propietario (CA-015-12a enmendada, T-015-07b) | [Hecho] (obsoleto: sin confirmación) |
| Foco de vuelta a «Language» tras elegir English | Correcto (propietario) | [Hecho] |

**Tras la enmienda (T-015-07b):** las filas de web se abren sin confirmación y la fila conserva el foco; que TalkBack lo mantenga al volver del navegador está **[Pendiente]** para T-015-14 (emulador).

Quedan sin probar en el móvil los avisos de error (guardado y «No hay ninguna app…», hacen falta fallos provocados): T-015-14 con el emulador.

## T-015-14: pasada completa en el emulador (2026-10-05)

Emulador `Pixel_6a` (API 37, `emulator-5554`, inglés), APK de depuración instalada y **desinstalada** al acabar. **No se tocó el Xiaomi.** Método: TalkBack activado con `settings`; un `integration_test` **temporal** (no se sube; borrado) con un repositorio de ajustes que falla a demanda y un abridor de enlaces que dice «no hay app» a demanda, que lleva la app real por los pasos con acciones del árbol semántico (`SemanticsAction.tap`, aviso de foco), con `screenrecord` (fotogramas con Swift) y, para **contar** las frases, las líneas `GoogleTTSServiceImpl: Synthesis request` de logcat entre marcas `adb shell log -t UNA-STEP`. Teclado con teclas del dispositivo `qwerty2` (`adb emu event text`) y `input keyevent` ya en modo teclado. Ajustes tocados y **restaurados** (comprobado al final): TalkBack, Switch Access, `font_scale` 1,0, densidad 420, escalas de animación 1, navegación por gestos, Chrome (deshabilitado un rato para el aviso real y vuelto a habilitar). Las capturas y vídeos quedan fuera del repo.

| Casilla | Resultado | Estado |
|---|---|---|
| Orden y foco, nivel 1 (CA-015-20a, 20g) | `uiautomator dump` con TalkBack: título (foco al abrir, recuadro en «Settings», Cerrar no lo roba) → «Language, Same as system» (botón) → «Keep screen on, Images, documents and web» (`Switch`, `checkable`) → «Information» → «Privacy policy / Third-party licenses / Help, Opens a web page in the browser» (botones) → «Close settings», último | [Hecho] |
| Orden y foco, nivel 2 (CA-015-20f, 20h) | Al abrir «Language»: recuadro en el título «Language». Volver: foco a «Language, Same as system». Elegir «Español»: Ajustes en español con el foco en «Idioma, Español» | [Hecho] |
| Interruptor dice su estado (CA-015-20d) | Al encender, TalkBack dice «checked» (y la pista «Double-tap to toggle»); al apagar, «not checked»: 2 y 1 frases en logcat, ninguna de la app | [Hecho] |
| Fallo de guardado: ni «activado» ni «desactivado» (CA-015-25) | Con el repositorio que falla, el interruptor no se mueve y TalkBack dice **solo** «Couldn't save the setting.»: 1 frase por intento | [Hecho] |
| Aviso de guardado, una vez por intento y el segundo fallo igual (CA-015-12, «Los avisos») | Dos fallos seguidos: 1 + 1 frases (el nodo no se duplica); el siguiente guardado con éxito retira el aviso (dice «checked»). En la página de Idioma, con el idioma en español, «No se pudo guardar el ajuste.» con voz y texto en español | [Hecho] |
| Aviso de enlace, una vez por intento (CA-015-12b) | Dos toques sin app (abridor falso): 1 + 1 frases, «There's no app to open this link.». **Con el opener real** (Chrome deshabilitado con `pm disable-user`): el mismo aviso | [Hecho] |
| Foco al volver del navegador (CA-015-20h) | **Hallazgo, sin arreglo posible desde la app.** Al volver (Ajustes → «Privacy policy» → Chrome → atrás) el foco de **entrada** de Flutter vuelve a la fila (`uiautomator`: `focused=true` en «Privacy policy») pero TalkBack lleva su recuadro al **título «Settings»** y **ignora** el aviso de foco a la fila, probado con la petición a los 0,4 s, 0,6 s y 1,5 s y desenfocando y enfocando antes. Se dejó el intento (`SettingsScreen` escucha el ciclo de vida y pide el foco a la fila al volver; 2 tests) por si otro TalkBack lo respeta. **Pregunta al propietario:** aceptar el comportamiento del sistema (TalkBack empieza por el título) y enmendar CA-015-20h, o probarlo en el móvil | **[Pendiente]** 022 / decisión |
| Los 10 minutos con el navegador (CA-015-16) | Ajustes → «Privacy policy» → Chrome → 10 min 47 s fuera → al volver: la tarea actual, **sin Ajustes ni menú**; el foco de entrada está en el botón de menú (`focused=true`), pero el recuadro de TalkBack queda en el **texto de la tarea** («Current task: Llamar a Marta»), no en el botón. En T-015-10 (con el test en marcha) sí quedó en el botón: no se reprodujo | **[Pendiente]** hallazgo: misma causa que la fila anterior; **Suposición** de CA-015-16 (foco en el botón de menú) a enmendar o a probar en el móvil |
| Teclado real: Tab, anillo, Intro, Espacio, Escape (CA-015-21) | Desde el menú con teclado: «Ajustes» (Intro) abre con el anillo en Cerrar; Tab recorre Idioma → interruptor → Privacidad → Licencias → Ayuda → Cerrar → Idioma (circula; el foco no sale a la tarea); anillo visible en cada una; Intro y Espacio (`KEYCODE_SPACE`) encienden y apagan el interruptor; Intro en «Idioma» abre la página (foco en Volver, Tab por las tres opciones); Escape sube un nivel con el foco en «Idioma» y desde el nivel 1 vuelve a la tarea con el anillo en el botón de menú. **Observación:** con Ajustes abierto con el dedo, el **primer** Tab va a «Idioma» (el título, que no entra en el orden, tiene el foco) y Cerrar llega al final de la vuelta; con el menú abierto con teclado, Cerrar tiene el foco desde el principio | [Hecho] (observación menor) |
| Switch Access con el teclado como interruptor (CA-015-21) | Servicio activo (Siguiente DPAD_RIGHT, Seleccionar DPAD_CENTER). Las teclas DPAD de `input keyevent` **no llegaron** al barrido (el foco de Flutter se movió con ellas y DPAD_CENTER activó la fila enfocada), así que no se pudo conducir. El orden que seguiría (el del lector) está comprobado por `dump` | **[Pendiente]** 022 (móvil o `adb` con otro método) |
| 200 % con tres botones, 360 dp (CA-015-22) | `font_scale 2.0`, `wm density 480`, navegación de tres botones. Ajustes, página de Idioma: sin cortes (el valor de «Idioma» y «Third-party licenses» pasan a segunda línea, el interruptor ocupa cuatro líneas). **Dos fallos, corregidos:** (1) el menú: «Settings» quedaba **a medias bajo la barra** (`showUnaSheet` no reservaba `padding.bottom`); (2) el aviso «There's no app…» quedaba tapado por la barra tras desplazarse a la vista (`ensureVisible` mide hasta el borde de la pantalla): `SettingsPage` ahora termina la zona desplazable sobre la barra. Tras corregirlos, con Chrome deshabilitado: el aviso completo por encima de la barra | [Hecho] tras el arreglo |
| Reducir movimiento (CA-015-01d) | Escalas de animación a 0, `screenrecord` a 30 fps: menú, subida de Ajustes, Idioma, vuelta y cierre cambian en **1 fotograma** cada uno; con las escalas a 1, 4-6 fotogramas | [Hecho] |
| `tools/check-recents.sh` (CA-015-18) | `capture` con Ajustes arriba, con el aviso «no hay app» y con la página de Idioma: tarjeta visible y **lisa** (desv. 0,00), sin parecido a la pantalla; `compare ajustes aviso` y `compare ajustes idioma`: tarjetas idénticas; `secure`: `not-secure` | [Hecho] |
| Voz de «Idioma, Español» y de «Como el sistema» | El emulador no dice la voz. El propietario la oyó en el Xiaomi (más arriba) | [Pendiente] 022 (si se quiere repetir con la versión final) |

**Hallazgos corregidos en esta tarea:** hoja con la barra de tres botones (`una_sheet.dart`, `menu_bottom_inset_test.dart`) y aviso bajo la barra (`settings_page.dart`, `language_page.dart`, `settings_screen.dart`, 2 tests nuevos en `settings_screen_test.dart`). **Sin corregir:** el foco de TalkBack al volver del navegador (arriba).
