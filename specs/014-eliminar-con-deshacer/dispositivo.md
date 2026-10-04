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
