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
