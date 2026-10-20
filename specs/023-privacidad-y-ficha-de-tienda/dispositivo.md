# Casillas de dispositivo — Spec 023

## C-023-1 · Capturas y gráfico de funciones (T-023-10, 2026-10-20)

**Estado:** hechas; **revisión del propietario aplazada el 2026-10-20** (8 capturas y el gráfico): no se sube la app a la tienda por ahora, así que se revisarán antes de F6.

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

## C-023-2 y C-023-3 · Navegador (T-023-11, 2026-10-20)

**Estado:** **Aceptada por el propietario (2026-10-20, «lo damos todo como que está bien»)**. Verificado: lo de la tabla marcado «Pasa». **Aceptado sin verificar:** TalkBack, C-023-4 y Vercel. La web de esta spec **no es definitiva** (el propietario hará una web del producto que lo incluirá todo): se repetirán las casillas sobre esa web cuando exista.

**Método** [Hecho]: `node landing/build.mjs` + `node landing/serve.mjs --port 4173` (cabeceras de `vercel.json`); Chrome del Mac por la extensión; reflujo y espaciado con Chrome headless por CDP (viewport de 320 px = 1280 px al 400 %; la ventana de Chrome no baja de 500 px); emulador `Una_store_1080x1920` (API 37) con `adb reverse tcp:4173`.

| Casilla | Resultado |
|---|---|
| C-023-2 · las 5 páginas (inicio, `/privacy`, `/help`, `/licenses`, 404): `lang`, sin JS, sin cookies, cabeceras | **Pasa.** `html lang="es"`, mitades con `lang`; 0 `<script>`, 0 `on…=`, 0 `style=`; 0 `Set-Cookie` y `document.cookie` vacío; CSP y las demás cabeceras en cada respuesta (la CSP bloquea incluso un `fetch` desde la propia página) |
| C-023-3 · teclado (Chrome del Mac), 5 páginas | **Pasa.** Orden lógico (salto de idioma → enlaces → «Leer en español» → enlaces), foco con contorno sólido de 3 px; el salto de idioma deja el foco en `<h2 id="en" tabindex="-1">` (**verifica el arrastre de `tabindex="-1"`**) |
| C-023-3 · espaciado 1.4.12 (line-height 1,5, letras 0,12 em, palabras 0,16 em, párrafos 2 em) a 1920 y 320 px, 5 páginas | **Pasa.** Sin desbordamiento horizontal y sin texto recortado |
| C-023-3 · reflujo a 320 px (= 1280 px al 400 %), licencias incluidas | **Pasa.** `scrollWidth` = 320; el `<pre>` de avisos con `pre-wrap` y `overflow-wrap: anywhere` |
| C-023-3 · escala de fuente del sistema al 200 % (emulador, Chrome) | **Pasa** en inicio, `/privacy` y `/licenses` (capturas): reflujo sin desbordar. El deslizador propio de Chrome no se tocó |
| Chrome Android y el idioma | Ofrece «Translate page? Spanish to English»: reconoce `lang="es"` |
| Árbol de accesibilidad de Chrome con TalkBack activo (`uiautomator dump`) | Contenido web antes que la barra; título «Una», enlaces pulsables, las dos mitades en orden |
| C-023-3 · **TalkBack**: voz EN en la mitad inglesa, encabezados, *landmarks*, foco tras el salto, lectura del bloque de avisos | **[Aceptado sin verificar]** `adb` no mueve el foco de TalkBack (T-006-16; aquí también falló `sendevent`, `adb emu event text` y `input keycombination`). Hay que hacerlo a mano (emulador con la pantalla o el Xiaomi) |
| C-023-4 · tres filas de Ajustes con las direcciones de la vista previa | **[Aceptado sin verificar]** la app solo abre `https` (`privacyLink`); una compilación de pruebas necesita admitir `http://127.0.0.1`, y el clasificador de permisos de la sesión rechazó ese cambio temporal. Requiere el visto bueno del propietario |

**Observación** [Hecho]: el pie enseña `[CONTACTO]` / `[CONTACT]` (hueco de identidad, se rellena en F6; es el aviso esperado de `check.mjs`).
