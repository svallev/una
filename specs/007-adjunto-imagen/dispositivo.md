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
  - `integration_test/image_flow_test.dart` y `viewer_perf_test.dart` compilan, pero no se han ejecutado.
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
  - foto → tarea actual → visor (doble toque) → cerrar;
  - restaurada sin archivos → "Adjunto no disponible" → eliminar;
  - captura de 1080 × 20 000 en 5 franjas, con desplazamiento vertical.

  **[Hecho 2026-09-27]** 2/2 tras dos correcciones (plan §8):
  - **Fallo de la app:** con una foto vertical, "Guardar" quedaba fuera de la pantalla (y = 1070 en una pantalla de 914). Corregido en `AttachmentPreview`, con test de regresión en `editor_image_test.dart`.
  - **Fallo del test:** la captura larga terminaba con el visor abierto y `_shutdown` no encontraba la pantalla principal.

## 3. Rendimiento en el Xiaomi (T-007-23, con permiso)

**Memoria y fluidez del visor.** Presupuesto: ampliar a ×8 añade < 200 MB sobre la tarea actual (redefinido el 2026-09-27, `docs/architecture.md` §7).

```bash
fvm flutter drive --profile --no-dds --keep-app-running \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/viewer_perf_test.dart -d <serial>
```

Resultados en `build/viewer_zoom_frames.json` y `build/viewer_memory_mb.json`. Se copian a `docs/perf/baseline.md`.

La medida que manda es `dumpsys meminfo` con la app *profile* normal (`flutter build apk --profile` + `adb install -r`), en un proceso nuevo y con la tarea ya guardada. El test es solo un aviso: arrastra la importación y no ve toda la memoria de la GPU.

- [x] Memoria: el visor a ×8 añade +150 MB de PSS (`dumpsys`) y +89 MB de RSS en el test. **[Hecho 2026-09-27]** Detalle en `docs/perf/baseline.md`. El presupuesto anterior (< 250 MB en total) no se podía cumplir: la app ya ocupa ~350 MB de RSS en la pantalla principal.
- [x] Fotogramas del zoom dentro del presupuesto de 120 Hz. **[Hecho 2026-09-27]** Peor fotograma: 2,6 ms; ninguno fuera de presupuesto.

**Arranque en frío con imagen** (CA-007-08: p50 < 1 s, con la imagen ya visible).

1. Instalar la *release*.
2. Crear a mano una tarea con una foto de la cámara.
3. Medir:

```bash
tools/measure-cold-start.sh <serial> 20
```

- [x] p50 < 1 s. Anotarlo en `docs/perf/baseline.md` junto al arranque con texto (198 ms). **[Hecho 2026-09-27]** p50 = 226 ms, p90 = 255 ms (n = 20).
- [x] Se ve la imagen en el primer fotograma, no un fondo vacío. **[Hecho 2026-09-27]**

## 4. A mano: cámara, selector y ciclo de vida

- [x] **"Hacer foto"** abre la cámara del sistema sin pedir ningún permiso (CA-007-02). La foto vuelve a la vista previa con el foco en ella.
  **[Hecho 2026-09-27, Xiaomi, propietario]** Sin permisos; la foto vuelve a la vista previa con "Guardar" visible. El foco se comprueba en el §5.
- [x] **"Subir imagen"** abre el selector de fotos del sistema, sin permisos (CA-007-03). **[Hecho 2026-09-27, Xiaomi, propietario]**
  **[Pendiente, fallo]** El propietario informa de que, tras elegir una foto, a veces se queda en la galería y deja cambiar de foto en lugar de volver a la app. Sin reproducir todavía (hace falta la app `.debug` en el Xiaomi).
- [ ] **Cancelar la cámara o el selector:** el editor queda como estaba y el foco vuelve a (+).
  **[Hecho 2026-09-27, emulador]** Con el gesto atrás en la cámara (`camera2`) y en el selector del sistema (`photopicker`), el editor queda igual. **[Pendiente]** El foco en (+) se comprueba con TalkBack (§5): `uiautomator` no ve el foco de Flutter.
- [x] **CL-007-1:** sin app de cámara (emulador sin cámara), se ve el aviso "No hay ninguna app de cámara disponible."
  **[Hecho 2026-09-27, emulador]** Con `pm disable-user com.android.camera2` sale "There's no camera app available." encima de los botones, sin tapar el (+). Cámara reactivada después.
- [ ] **CL-007-6:** **[No probado: el propietario decide no probarlo, 2026-09-27; cubierto por los tests de M1]** una imagen de Google Fotos que solo está en la nube, sin conexión, da "No hemos podido leer esta imagen." en 20 s como mucho. "Cancelar" responde en 2 s aunque el proveedor esté colgado (hallazgo M1).
- [x] **CL-007-7:** con la cámara abierta, `adb shell am kill invalid.pending.app.debug`. Al volver se ve el editor sin imagen (o la tarea actual si pasaron 10 min) y no queda nada en `cache/import/` tras el barrido.
  **[Hecho 2026-09-27, emulador]** Proceso muerto, foto hecha y "Done": la app se reabre en el editor sin imagen; `cache/import/` vacía y sin `attachments/`.
- [x] **CA-007-11:** el visor gira; al volver a la tarea, la pantalla está en vertical; el resto de la app no gira.
  **[Hecho 2026-09-27]** Xiaomi: el sistema gira a `ROTATION_90` con el visor (`SCREEN_ORIENTATION_USER`); la tarea actual pide `PORTRAIT`. Emulador: en horizontal, la foto al ancho con desplazamiento vertical y solo "Cerrar"; al volver a vertical sigue el visor; "Cerrar" vuelve a la tarea en vertical.
  **Decidido por el propietario (2026-09-27):** a ×1 la imagen va **siempre al ancho, con desplazamiento vertical**, también en horizontal (sin cambios: CA-007-09). Girar no cierra el visor.
- [ ] **Pellizco** hasta ×8; al soltar cerca de ×1, vuelve al ancho completo.
  **[Pendiente]** El propietario informa de que no funciona. Los tests de widgets pellizcan bien (dos dedos a la vez y con el segundo 120 ms después; fotos horizontales y verticales). Falta confirmar que la prueba se hizo en el visor y no en la tarea actual, que no amplía.
- [ ] **CA-007-12:** **[No probado: el propietario decide no probarlo, 2026-09-27; cubierto por `keep_screen_on_test.dart`]** con la imagen visible, la pantalla no se apaga mientras se toca; tras 10 minutos sin tocarla, sí. Para probarlo rápido, se puede acortar el tiempo en una compilación de depuración.

## 5. TalkBack (T-007-24)

- [ ] **Hoja "Añadir":** se anuncia su nombre y el foco empieza en el título. Cerrarla con la X, con el gesto atrás o tocando fuera devuelve el foco a (+).
- [ ] **Vuelta de la cámara:** se oye entero "Foto añadida", sin que lo corte la lectura del nuevo foco. Igual con "Imagen añadida", "Preparando imagen…", "Adjunto quitado" y los errores.
- [ ] **Tarea actual con imagen:** se lee "Tarea actual: {texto}. Con foto" o "Tarea actual: Foto". Doble toque abre el visor. Las acciones son Completar tarea y Eliminar tarea.
- [ ] **Visor:**
  - se lee "Imagen de la tarea" y el foco está en la imagen;
  - el valor se lee "Ampliación por 2,5";
  - las acciones son Ampliar, Reducir y Ajustar al ancho;
  - la imagen se lee antes que "Cerrar".
- [ ] **Visor ampliado:** el desplazamiento con dos dedos funciona también en horizontal. Si solo va en vertical hasta agotarse, se anota: es una limitación de Flutter en Android.
- [ ] **Pantalla encendida:** usando solo gestos del lector (explorar tocando y acciones) durante más de 10 minutos, la pantalla no se apaga.
- [ ] **Listado:** "{n} de {total}: {texto}. Con foto". La miniatura no se lee.

## 6. Switch Access y teclado físico (T-007-24)

- [ ] **Switch Access:** abrir el visor desde la tarea; Ampliar, Reducir, Ajustar al ancho y Cerrar.
- [ ] **Teclado: Tab en la tarea actual** llega a la imagen. El anillo blanco y negro se ve sobre una foto oscura y sobre una clara. Intro abre el visor.
- [ ] **Teclado en el visor:**
  - + / − / 0 y las flechas funcionan, también después de pasar a "Cerrar" con Tab;
  - Esc cierra;
  - el anillo de "Cerrar" se ve.
- [ ] **Teclado en el editor:** Tab llega a "Quitar adjunto" y se ve su anillo.
- [ ] **Texto al 200 %:** con un error de importación, el aviso queda encima de los botones y no tapa el (+).

## 7. Cierre

- [ ] Resultados anotados en el plan §8 y en `docs/perf/baseline.md`.
- [ ] `tasks.md`: T-007-23 y T-007-24 hechas; lista de cierre (todos los CA con test en verde, DoD) y spec marcada como **Implementada**.
- [ ] PR de la rama `feat/007-adjunto-imagen-c2zgoo` con el antes y el después de los goldens.
