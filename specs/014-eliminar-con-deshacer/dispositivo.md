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
