# Spec 007: pruebas en el dispositivo (T-007-23 y T-007-24)

Guía para la sesión en local. Todo lo que se pudo hacer sin dispositivo está hecho y en verde (plan §8). Aquí queda lo que necesita el emulador o el Xiaomi.

- **Emulador:** tests automáticos y pruebas a mano.
- **Xiaomi:** solo con permiso del propietario, con la app de pruebas (`.debug`/`.profile`) y desinstalándola después (`docs/testing.md`).

## 0. Punto de partida (2026-09-27, al pasar de la nube a local)

- **Rama:** `feat/007-adjunto-imagen-c2zgoo`, sincronizada con `origin`. En local: `git fetch origin && git switch feat/007-adjunto-imagen-c2zgoo && git pull`.
- **Verificado en la nube sobre el último commit** (Linux, Flutter 3.47.5, la versión de `.fvmrc`):
  - formato sin cambios;
  - `flutter analyze --fatal-infos` limpio;
  - **536 tests en verde**, incluidos los 38 goldens;
  - `gen-l10n` sin diferencias;
  - `validate-tokens` ✅.
- **Hecho:** T-007-01 a 22 y T-007-25 (`tasks.md`, estado). Decisiones y cambios, en el plan §8. No queda ninguna decisión pendiente del propietario.
- **Sin probar todavía** (la nube no puede descargar el SDK de Android):
  - el Kotlin de T-007-16 y de las correcciones de T-007-25 **no se ha compilado nunca**; es lo primero (§1);
  - `integration_test/image_flow_test.dart` compila, pero no se ha ejecutado.
- **Recordatorios:**
  - en el Mac, los goldens se omiten (se generan y comparan en Linux, `docs/testing.md`); si alguno cambia, no se suben imágenes del Mac;
  - los tests que miden anchos o texto grande cargan las fuentes reales (`CLAUDE.md`, Convenciones);
  - la PR de esta rama lleva también, solo como documentación, el plan aprobado del ADR-0012 (`specs/adr-0012-sin-historico/`).
- **Después de esta spec:** fusionar en `main` y crear `feat/adr-0012-sin-historico` desde `main` (tareas en `specs/adr-0012-sin-historico/tasks.md`, empezando por el test de migración).

Se marca cada casilla y se anota el resultado. Lo que falle se registra en el plan §8 antes de cerrar la spec.

## 1. Compilar y comprobaciones rápidas (Mac)

```bash
cd app
fvm flutter pub get
fvm flutter build apk --debug          # compila el Kotlin nuevo (T-007-16 y T-007-25)
fvm flutter build apk --release
../tools/check-android-permissions.sh release   # sin permisos; <provider> no exportado
```

- [x] El Kotlin compila sin errores (`ImageImport.kt`, `ImageSanitizer.kt`). **[Hecho 2026-09-27]** `build apk --debug` y `--release` en verde, sin avisos del compilador de Kotlin.
- [x] Declarar `androidx.core` en `android/app/build.gradle.kts` con versión fijada, la misma que llega hoy de forma transitiva (`./gradlew app:dependencies | grep androidx.core`). Justificarlo en la PR (threat-model §5, hallazgo B4).
  **[Hecho 2026-09-27]** Llegaba como `androidx.core:core:1.13.1` (resuelta desde 1.0.0, 1.3.2 y 1.8.0 de los plugins); declarada `implementation("androidx.core:core:1.13.1")`. Sin cambios en el árbol resuelto.
- [x] `check-android-permissions.sh release` en verde. **[Hecho 2026-09-27]**

## 2. Tests de integración en el emulador (T-007-23)

```bash
fvm flutter test integration_test/image_import_test.dart -d emulator-5554
fvm flutter test integration_test/image_flow_test.dart -d emulator-5554
```

- [x] `image_import_test`: sin metadatos, orientación, sRGB, 24 MP, teselas, límites, malformados, cancelar. **[Hecho 2026-09-27]** 13/13 en el Pixel 6a (API 36).
- [x] `image_flow_test`:
  - foto → tarea actual (tocar la imagen no abre nada: sin visor, ADR-0013);
  - restaurada sin archivos → "Adjunto no disponible" → eliminar;
  - captura de 1080 × 20 000 en 5 franjas, con desplazamiento vertical en la tarea actual.

  **[Hecho 2026-09-27]** 2/2 tras dos correcciones (plan §8):
  - **Fallo de la app:** con una foto vertical, "Guardar" quedaba fuera de la pantalla (y = 1070 en una pantalla de 914). Corregido en `AttachmentPreview`, con test de regresión en `editor_image_test.dart`.

## 3. Rendimiento en el Xiaomi (T-007-23, con permiso)

**Memoria de la tarea con imagen.** Presupuesto: la imagen de 24 MP añade < 200 MB sobre la misma tarea con texto (`docs/architecture.md` §7). Se mide con `dumpsys meminfo` con la app *profile* normal (`flutter build apk --profile` + `adb install -r`), en un proceso nuevo y con la tarea ya guardada: en vertical, desplazándose, pellizcando y en horizontal.

- [x] Memoria dentro del presupuesto. **[Hecho 2026-09-27]** Xiaomi: 213 MB de PSS con la foto; la imagen añade como mucho ~100 MB (detalle en `docs/perf/baseline.md`).

**Arranque en frío con imagen** (CA-007-08: p50 < 1 s, con la imagen ya visible).

1. Instalar la *release*.
2. Crear a mano una tarea con una foto de la cámara.
3. Medir:

```bash
tools/measure-cold-start.sh <serial> 20
```

- [x] p50 < 1 s. Anotarlo en `docs/perf/baseline.md` junto al arranque con texto (198 ms). **[Hecho 2026-09-27]** p50 = 226 ms, p90 = 255 ms (n = 20); sin visor, p50 = 245 ms.
- [x] Se ve la imagen en el primer fotograma, no un fondo vacío. **[Hecho 2026-09-27]**

## 4. A mano: cámara, selector y ciclo de vida

- [x] **"Hacer foto"** abre la cámara del sistema sin pedir ningún permiso (CA-007-02). La foto vuelve a la vista previa con el foco en ella.
  **[Hecho 2026-09-27, Xiaomi, propietario]** Sin permisos; la foto vuelve a la vista previa con "Guardar" visible. El foco se comprueba en el §5.
- [x] **"Subir imagen"** abre el selector de fotos del sistema, sin permisos (CA-007-03). **[Hecho 2026-09-27, Xiaomi, propietario]**
  **[Hecho 2026-09-27]** El propietario llegó a ver que el selector se quedaba en la galería, pero después confirma que funciona bien; se descarta.
- [ ] **Cancelar la cámara o el selector:** el editor queda como estaba y el foco vuelve a (+).
  **[Hecho 2026-09-27, emulador]** Con el gesto atrás en la cámara (`camera2`) y en el selector del sistema (`photopicker`), el editor queda igual. **[Pendiente]** El foco en (+) se comprueba con TalkBack (§5): `uiautomator` no ve el foco de Flutter.
- [x] **CL-007-1:** sin app de cámara (emulador sin cámara), se ve el aviso "No hay ninguna app de cámara disponible."
  **[Hecho 2026-09-27, emulador]** Con `pm disable-user com.android.camera2` sale "There's no camera app available." encima de los botones, sin tapar el (+). Cámara reactivada después.
- [ ] **CL-007-6:** **[No probado: el propietario decide no probarlo, 2026-09-27; cubierto por los tests de M1]** una imagen de Google Fotos que solo está en la nube, sin conexión, da "No hemos podido leer esta imagen." en 20 s como mucho. "Cancelar" responde en 2 s aunque el proveedor esté colgado (hallazgo M1).
- [x] **CL-007-7:** con la cámara abierta, `adb shell am kill invalid.pending.app.debug`. Al volver se ve el editor sin imagen (o la tarea actual si pasaron 10 min) y no queda nada en `cache/import/` tras el barrido.
  **[Hecho 2026-09-27, emulador]** Proceso muerto, foto hecha y "Done": la app se reabre en el editor sin imagen; `cache/import/` vacía y sin `attachments/`.
- [x] **CA-007-11:** en la tarea actual con imagen, girar el móvil gira la pantalla **sin tocar nada**; en horizontal solo se ven la imagen (a todo el ancho, con desplazamiento vertical) y el logotipo; al volver a vertical, vuelven el menú, el botón y el pie. Con el menú abierto, o en otra pantalla, no gira; con el bloqueo de rotación, tampoco.
  **[Hecho 2026-09-27]** Emulador (acelerómetro simulado): vertical, horizontal (solo imagen y logotipo), vertical otra vez; con el menú abierto no gira. Xiaomi: el propietario confirma que gira sin tocar.
  **Lección:** en HyperOS, con `SCREEN_ORIENTATION_USER`, no giraba hasta el siguiente toque; ahora lo decide el acelerómetro (`ImageRotation.kt`).
- [x] **Pellizco (CA-007-10):** en vertical y en horizontal, pellizcar amplía la imagen ahí mismo y al soltar vuelve al 100 %; sin visor ni "Cerrar". **[Hecho 2026-09-27, Xiaomi, propietario]** También el desplazamiento vertical de una captura larga.
- [x] **Imagen al ancho (CA-007-09, DEV-41):** una foto nueva se ve entera a lo ancho en vertical. **[Hecho 2026-09-27, Xiaomi, propietario]** Las fotos añadidas antes del cambio siguen recortadas.
- [ ] **CA-007-12:** **[No probado: el propietario decide no probarlo, 2026-09-27; cubierto por `keep_screen_on_test.dart`]** con la imagen visible, la pantalla no se apaga mientras se toca; tras 10 minutos sin tocarla, sí. Para probarlo rápido, se puede acortar el tiempo en una compilación de depuración.

## 5. TalkBack (T-007-24)

- [ ] **Hoja "Añadir":** se anuncia su nombre y el foco empieza en el título. Cerrarla con la X, con el gesto atrás o tocando fuera devuelve el foco a (+).
  **[Fallo, 2026-09-27, emulador con TalkBack]** Al abrirla, el foco de TalkBack va a la X de cerrar, no al título. Al cerrarla con atrás, va a "Cancelar" (primer elemento del editor), no a (+). Los tests de widgets pasan porque comprueban el evento de foco, que TalkBack ignora.
  **[Intentado 2026-09-27, sin éxito]** (1) título enfocable; (2) repetir el aviso de foco a (+) cuando la ventana se ha asentado (600 ms tras cerrar); (3) poner el foco de entrada en los nodos con nombre (título al abrir, (+) al cerrar; comprobado con `uiautomator`: `focused="true"` en el nodo correcto). TalkBack no sigue ni el aviso de foco ni el foco de entrada: al cambiar de ventana enfoca el **primer elemento que se puede pulsar** (la X; "Cancelar" o el campo). Cambios deshechos. **Decidido por el propietario (2026-09-27):** se acepta como limitación de TalkBack (CA-007-22).
- [ ] **Vuelta de la cámara:** se oye entero "Foto añadida", sin que lo corte la lectura del nuevo foco. Igual con "Imagen añadida", "Preparando imagen…", "Adjunto quitado" y los errores.
- [x] **Tarea actual con imagen:** **[Hecho 2026-09-27, emulador]** el foco inicial está en la tarea entera (un solo nodo) y el doble toque no abre nada. Se lee "Tarea actual: {texto}. Con foto" o "Tarea actual: Foto". Doble toque no abre nada. Las acciones son Completar tarea y Eliminar tarea, también en horizontal (sin botón visible).
- [ ] **Lupa del sistema** (excepción a P6, ADR-0013): con la ampliación de accesibilidad de Android activada, se puede ampliar la imagen de la tarea.
- [ ] **Pantalla encendida:** usando solo gestos del lector (explorar tocando y acciones) durante más de 10 minutos, la pantalla no se apaga.
- [ ] **Listado:** "{n} de {total}: {texto}. Con foto". La miniatura no se lee.

## 6. Switch Access y teclado físico (T-007-24)

- [ ] **Switch Access:** en la tarea con imagen, llegar a Completar tarea y al menú. **[Pasado a la auditoría de F5]** junto con Switch Access en horizontal y la lupa (ADR-0013, `docs/PLAN.md`).
- [x] **Teclado en el editor:** Tab llega a "Quitar adjunto" y se ve su anillo. **[Hecho 2026-09-27]** En el emulador, Tab recorre el editor con imagen (el foco llega al campo). El anillo no se ve con las teclas que inyecta `adb`, porque Flutter las trata como teclado virtual (flutter/flutter#180746); lo cubre `image_a11y_test` ("Quitar adjunto recibe el foco con Tab y muestra el anillo"). Con un teclado físico real, en la auditoría de F5.
- [x] **Texto al 200 %:** con un error de importación, el aviso queda encima de los botones y no tapa el (+). **[Hecho]** `image_a11y_test` ("WCAG 2.4.11: al 200 %, el aviso de error no tapa el (+)").

## 7. Cierre

- [x] Resultados anotados en el plan §8 y en `docs/perf/baseline.md`.
- [x] `tasks.md`: T-007-23 y T-007-24 hechas; lista de cierre (todos los CA con test en verde, DoD) y spec marcada como **Implementada**.
- [x] PR de la rama `feat/007-adjunto-imagen-c2zgoo` con el antes y el después de los goldens: svallev/una#11.
