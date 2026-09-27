# Spec 007: pruebas en el dispositivo (T-007-23 y T-007-24)

Guía para la sesión en local. Todo lo que se pudo hacer sin dispositivo está hecho y en verde (plan §8). Aquí queda lo que necesita el emulador o el Xiaomi.

- **Emulador:** tests automáticos y pruebas a mano.
- **Xiaomi:** solo con permiso del propietario, con la app de pruebas (`.debug`/`.profile`) y desinstalándola después (`docs/testing.md`).

Se marca cada casilla y se anota el resultado. Lo que falle se registra en el plan §8 antes de cerrar la spec.

## 1. Compilar y comprobaciones rápidas (Mac)

```bash
cd app
fvm flutter pub get
fvm flutter build apk --debug          # compila el Kotlin nuevo (T-007-16 y T-007-25)
fvm flutter build apk --release
../tools/check-android-permissions.sh release   # sin permisos; <provider> no exportado
```

- [ ] El Kotlin compila sin errores (`ImageImport.kt`, `ImageSanitizer.kt`).
- [ ] Declarar `androidx.core` en `android/app/build.gradle.kts` con versión fijada, la misma que llega hoy de forma transitiva (`./gradlew app:dependencies | grep androidx.core`). Justificarlo en la PR (threat-model §5, hallazgo B4).
- [ ] `check-android-permissions.sh release` en verde.

## 2. Tests de integración en el emulador (T-007-23)

```bash
fvm flutter test integration_test/image_import_test.dart -d emulator-5554
fvm flutter test integration_test/image_flow_test.dart -d emulator-5554
```

- [ ] `image_import_test`: sin metadatos, orientación, sRGB, 24 MP, teselas, límites, malformados, cancelar.
- [ ] `image_flow_test`:
  - foto → tarea actual → visor (doble toque) → cerrar;
  - restaurada sin archivos → "Adjunto no disponible" → eliminar;
  - captura de 1080 × 20 000 en 5 franjas, con desplazamiento vertical.

## 3. Rendimiento en el Xiaomi (T-007-23, con permiso)

**Memoria y fluidez del visor.** Presupuesto: < 250 MB.

```bash
fvm flutter drive --profile --no-dds --keep-app-running \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/viewer_perf_test.dart -d <serial>
```

Resultados en `build/viewer_zoom_frames.json` y `build/viewer_memory_mb.json`. Se copian a `docs/perf/baseline.md`.

- [ ] RSS máxima < 250 MB.
- [ ] Fotogramas del zoom dentro del presupuesto de 120 Hz.

**Arranque en frío con imagen** (CA-007-08: p50 < 1 s, con la imagen ya visible).

1. Instalar la *release*.
2. Crear a mano una tarea con una foto de la cámara.
3. Medir:

```bash
tools/measure-cold-start.sh <serial> 20
```

- [ ] p50 < 1 s. Anotarlo en `docs/perf/baseline.md` junto al arranque con texto (198 ms).
- [ ] Se ve la imagen en el primer fotograma, no un fondo vacío.

## 4. A mano: cámara, selector y ciclo de vida

- [ ] **"Hacer foto"** abre la cámara del sistema sin pedir ningún permiso (CA-007-02). La foto vuelve a la vista previa con el foco en ella.
- [ ] **"Subir imagen"** abre el selector de fotos del sistema, sin permisos (CA-007-03).
- [ ] **Cancelar la cámara o el selector:** el editor queda como estaba y el foco vuelve a (+).
- [ ] **CL-007-1:** sin app de cámara (emulador sin cámara), se ve el aviso "No hay ninguna app de cámara disponible."
- [ ] **CL-007-6:** una imagen de Google Fotos que solo está en la nube, sin conexión, da "No hemos podido leer esta imagen." en 20 s como mucho. "Cancelar" responde en 2 s aunque el proveedor esté colgado (hallazgo M1).
- [ ] **CL-007-7:** con la cámara abierta, `adb shell am kill invalid.pending.app.debug`. Al volver se ve el editor sin imagen (o la tarea actual si pasaron 10 min) y no queda nada en `cache/import/` tras el barrido.
- [ ] **CA-007-11:** el visor gira; al volver a la tarea, la pantalla está en vertical; el resto de la app no gira.
- [ ] **Pellizco** hasta ×8; al soltar cerca de ×1, vuelve al ancho completo.
- [ ] **CA-007-12:** con la imagen visible, la pantalla no se apaga mientras se toca; tras 10 minutos sin tocarla, sí. Para probarlo rápido, se puede acortar el tiempo en una compilación de depuración.

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
