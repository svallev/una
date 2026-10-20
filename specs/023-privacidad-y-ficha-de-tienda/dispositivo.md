# Casillas de dispositivo — Spec 023

## C-023-1 · Capturas y gráfico de funciones (T-023-10, 2026-10-20)

**Estado:** hechas; **a la espera de la revisión del propietario** (8 capturas y el gráfico).

**Cómo se hicieron** [Hecho]:

- AVD `Una_store_1080x1920` (API 37.2, `google_apis_ps16k`, arm64, pantalla de 1080 × 1920 a 420 dpi; no se versiona), sin cuenta de Google ni datos del propietario.
- Compilación *release* arm64 (`flutter build apk --release --target-platform android-arm64`) del commit `113f96e` de la rama (sin cambios de `app/` respecto a `main`; la spec no toca la app), firmada con la clave de depuración. Nunca en el Xiaomi.
- Barra de estado en modo demo (`sysui_demo_allowed`): 10:00, batería al 100 %, Wi-Fi completo, sin móvil ni notificaciones. La hora de la captura 4 («La notificación será a las 08:55») es la franja de la app, no la hora real.
- Datos ficticios: textos inventados (sin tildes ni «ñ» porque `adb shell input text` no las teclea) y una **foto generada** (paisaje dibujado con Pillow, sin terceros). El permiso de notificaciones se concedió con `pm grant` y se encendió el interruptor en Ajustes.
- Idiomas: inglés con el del sistema; español con el selector de Idioma de la app (datos nuevos tras `pm clear`).
- Salida: `adb exec-out screencap -p` → PNG de 24 bits sin alfa, 1080 × 1920 (`store/google-play/screenshots/{es-ES,en-US}/1…4-*.png`).
- Gráfico: *golden* `app/test/store/feature_graphic_test.dart` (escribe y compara `store/google-play/feature-graphic.png`, 1024 × 500, sin alfa; se omite fuera de Linux salvo `GOLDENS_ANY_OS=1`; el archivo lo escribió el Mac, el comparador admite una diferencia pequeña por el suavizado del texto).

**Resultado:** `node store/google-play/check.mjs` sin errores con `GRAPHICS_REQUIRED = true` (CA-023-10); 137 tests de Node en verde.

| # | Pieza | Qué enseña |
|---|---|---|
| 1 | Tarea actual con texto | «Llamar a Marta para confirmar la cita del jueves» / «Call Marta to confirm the appointment on Thursday» |
| 2 | Tarea con foto | Paisaje generado y «Paseo del domingo por el campo» / «Sunday walk in the hills» |
| 3 | Todas mis tareas | Cinco tareas (en ES la quinta sale cortada por el borde, como se vería al desplazar) |
| 4 | Ajustes | Notificaciones encendidas, 1 al día |

**[Pendiente, propietario]** Revisar las 8 capturas y el gráfico: datos ficticios, barra limpia, idioma correcto, nada de terceros (CA-023-11). Si algo no vale, se repite en el emulador.
