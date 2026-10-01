# Spec 013: pruebas en el dispositivo (T-013-08)

Verificación en el **emulador `Pixel_6a` (Android 16 / API 37, `emulator-5554`)**, 2026-10-01, sobre `4ace47f` (APK *release* arm64 de la rama, `flutter build apk --release --split-per-abi --target-platform android-arm64`). **No se usó ni se tocó el Xiaomi** (todos los `adb` llevan `-s emulator-5554`). Al terminar: idioma de la app sin fijar, `transition_animation_scale` 1,0, TalkBack apagado, Chrome activado. Las capturas y grabaciones, en el directorio temporal de la sesión.

**Resultado: 2 fallos (F-1 y F-2), registrados abajo. T-013-08 NO se da por hecha; se para y se devuelve la pregunta.**

## 1. Comprobaciones de "nada más cambia" (CA-013-06)

| Casilla | Resultado | Estado |
|---|---|---|
| `check-android-permissions.sh release` | Pasa: solo `INTERNET` (2 permisos revisados) | [Hecho] |
| `check-licenses.sh` sobre el APK *release* | Pasa: 84 paquetes de Dart en `NOTICES`, 46 artefactos de Android en `android.txt`, 5 bibliotecas nativas, 2 carpetas de fuentes con su OFL | [Hecho] |
| Test de migración (`test/drift`) y `startup_licenses_test.dart` | En verde (la suite entera: 1526 tests, `format` y `analyze` limpios) | [Hecho] |
| `git diff main...HEAD` | Sin `pubspec.yaml`, `pubspec.lock`, `drift_schemas/`, manifiestos ni `build.gradle` | [Hecho] |
| `node tools/validate-tokens.mjs` | Válido (28 combinaciones de contraste AA) | [Hecho] |
| *Goldens* | Solo en CI (etiqueta `actualizar-goldens` si hiciera falta); no se tocan aquí | [Pendiente] CI |

## 2. "Reducir movimiento" (CA-013-03)

Método: `screenrecord` a 540x1200 + lectura de fotogramas con marca de tiempo (AVFoundation, ~16 ms por fotograma) y, por fotograma, la esquina superior izquierda de la cara blanca del control y los píxeles oscuros (sombra). Pulsación con `input swipe x y x y 1200` (o `input motionevent` para cancelar: el dedo sale del control).

| Control | Con movimiento normal | Con `transition_animation_scale 0` | Estado |
|---|---|---|---|
| `SquareIconButton` (menú de la tarea) | 5 fotogramas (≈ 65 ms): cara (21,18) → (25,22), sombra 1233 → 860 px | **1 fotograma**: (21,18) → (25,22), sombra 1208 → 840 | [Hecho] |
| `BrutalButton` "+" del editor (`.icon`) | 5 fotogramas (≈ 70 ms) al pulsar: (16,16) → (21,21) | **1 fotograma** al pulsar | [Hecho] |
| `BrutalButton` "Continuar" / "Nueva tarea" | — | 1 fotograma al pulsar y 1 al soltar (vuelve a su sitio) | [Hecho] |
| Opción "En el último lugar" de "¿Dónde la pones?" | 6 fotogramas al pulsar y 6 al cancelar (el dedo sale) | **1 fotograma** al pulsar y al cancelar | [Hecho] |
| Botón de completar: hundido (desplazamiento y sombra) | gradual (varios fotogramas; se mezcla con el relleno) | 1 fotograma: (16,16) → (22,21) | [Hecho] |
| **Botón de completar: relleno de "mantener pulsado"** | ≈ 0,9 s hasta soltar (1,2 s para completar) | **≈ 60 ms y completa la tarea** | **FALLO F-1** |

### F-1 (alto): con "reducir movimiento" el botón de completar se completa casi al instante

- Con `transition_animation_scale 0`, mantener pulsado "Completar" 1 s (o menos) **completa la tarea**: el relleno pasa de 0 a 100 % en ≈ 60 ms (4 fotogramas) y la tarea "dos" desapareció (la actual pasó a ser "uno"). La spec dice que el relleno **no cambia** (CA-013-03, CL-003-5); aquí cambia, y de forma peligrosa: se pierde la protección contra el toque accidental (P1, spec 003) justo para quien tiene el ajuste puesto.
- **Causa [Hecho, leído en el SDK]:** `AnimationController(vsync, duration)` tiene `animationBehavior: AnimationBehavior.normal`, que **acorta la duración (×0,05) cuando `SemanticsBinding.disableAnimations` es verdadero** (el ajuste del sistema). `HoldToCompleteButtonState._fill` (`hold_to_complete_button.dart:42`) lo usa por defecto. No es de la 013 (el controlador es de la 003), pero la 013 prometió y declaró verificado "el relleno sigue igual".
- **Por qué los tests no lo vieron:** `press_motion_test.dart` activa `MediaQueryData(disableAnimations: true)`, que no es lo que lee `AnimationController` (lee `SemanticsBinding.instance.disableAnimations`, es decir `platformDispatcher.accessibilityFeatures`). Un test que lo reproduzca debe fijar `tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true)`.
- **Recomendación:** nueva tarea (p. ej. T-013-08b) que ponga `animationBehavior: AnimationBehavior.preserve` en `_fill` (también cubre `animateBack`), con el test de arriba (el relleno tarda 1,2 s con el ajuste del sistema activo y la tarea no se completa a los 200 ms); revisar de paso los otros cinco `AnimationController` de `lib` (`task_list_screen.dart:1053` destello, `crumple_overlay.dart:61`, `celebration_overlay.dart:71`, `all_done_screen.dart:36`, `task_image.dart:46`) para decidir cuáles deben acortarse (decorativos: sí) y cuáles no (los que informan de un progreso).

## 3. Cambio de idioma con el nivel 2 o el 3 abiertos (CA-013-02)

`adb shell cmd locale set-app-locales invalid.pending.app --locales es-ES | en-US`; lista real de 196 elementos; teclado: Intro sobre la fila con el foco abre su nivel 3 (así se sabe que el foco de teclado sigue en ella).

| Caso | Resultado | Estado |
|---|---|---|
| Nivel 2 visible, EN ↔ ES | La pantalla cambia de idioma sin cerrarse; las filas dicen "N licencia(s)" / "N license(s)"; la entrada propia está en su sitio alfabético: EN tras `analyzer` y antes de `angle` ("Android libraries (AndroidX, Kotlin), 2 licenses"); ES tras `benchmark` y antes de `boolean_selector` ("Bibliotecas de Android (AndroidX, Kotlin), 2 licencias") | [Hecho] |
| Nivel 3 abierto (ES, desplazado), cambio a EN | El título pasa a "Android libraries (AndroidX, Kotlin)" sin cerrar y el desplazamiento se conserva | [Hecho] |
| Nivel 2 visible, la fila con el foco **baja** en la lista (EN → ES) | La fila queda a la vista | [Hecho] |
| Volver del nivel 3 tras el cambio, la fila **baja** (EN → ES) | La fila queda a la vista | [Hecho] |
| Nivel 2 visible, la fila con el foco **sube** (ES → EN) | **La fila no queda a la vista** (la lista conserva su desplazamiento; el foco de teclado sí está en ella: Intro abre su nivel 3) | **FALLO F-2** |
| Volver del nivel 3 tras el cambio, la fila **sube** (ES → EN) | **Igual: la fila no queda a la vista** (reproducido dos veces) | **FALLO F-2** |

### F-2 (medio): la fila con el foco no se lleva a la vista cuando sube de posición al cambiar el idioma

- CA-013-02 pide que, al volver, "el foco va a esa fila, en su posición nueva" y el plan (P-013-3) que quede a la vista. En el emulador solo funciona cuando la fila **baja**. Cuando sube (la entrada pasa de la B a la A y queda por encima del borde superior), `_reveal` (`licenses_screen.dart:308`) no desplaza la lista: el foco de teclado está en la fila, pero fuera de la pantalla; con teclado se ve el foco "perdido", con TalkBack el evento de foco apunta a un nodo que no está en pantalla.
- **[Suposición]** La fila vieja aún está en `_rows` (con la lista *offstage* o sin recalcular su posición) y `Scrollable.ensureVisible` usa una geometría que no se ha vuelto a medir, o la fila ya construida cae fuera de la ventana y la estimación no basta. Los 9 tests de la 013 (60 elementos) no lo reproducen: hace falta una lista larga con el desplazamiento a media altura y la fila subiendo más de una pantalla.
- **Recomendación:** tarea de arreglo con un test que lo reproduzca (lista de ~200, desplazada a la altura de la B, cambio a EN, comprobar que `_rows[name]` queda dentro del `viewport`); si no sale con poco código, aceptar el límite (el foco de teclado se conserva) y anotarlo, como dejó dicho el plan.

## 4. TalkBack (recuadro verde + panel de voz, capturas)

`adb` no puede mover el foco de TalkBack (límite conocido, T-006-16): se mira dónde llega y qué dice, y se activa con el teclado (Tab + Intro) o con `input tap`. El panel de voz tapa los botones de abajo; hay que usar Tab.

| Sitio (P-013-4) | Resultado | Estado |
|---|---|---|
| Confirmación de enlace (nivel 1 → "Política de privacidad") | Foco inicial en **"Cancelar"** (recuadro verde) y se lee la pregunta "Open example.com in the browser?" | [Hecho] |
| Confirmación de borrar la tarea | Foco inicial en **"Cancelar"**; el panel dice "Cancel" | [Hecho] |
| "Nueva tarea" (menú, `BrutalButton`) | Con Tab llega y Intro abre el editor; el foco de TalkBack va al campo ("New task, What's that thing…") | [Hecho] |
| "+" del editor (`BrutalButton.icon`) | Con Tab llega ("Add a photo, image or file") y Intro abre la hoja; el foco de TalkBack va a "Cerrar" (primer nodo de la hoja). Al cerrar la hoja el foco de TalkBack va a "Cancelar", **no al "+"** (TalkBack ignora el aviso de foco de Flutter en un cambio de ventana, ver Memoria y Trampas; igual que antes de la 013, no se ha comparado con `main`) | [Hecho] con salvedad; foco real a "+" **[Pendiente]** 016 |
| "Reintentar" (nivel 2 con error) | No se puede provocar en una compilación *release* con el registro de licencias lleno; lo cubren los 7 tests de `brutal_button_sites_test` (un solo nodo con etiqueta, `tap` y `focus`) | **[Pendiente]** 016 |
| Nivel 1: foco inicial | En el título "Settings and profile" | [Hecho] |
| Nivel 1 con el aviso "No hay ninguna app…" (Chrome desactivado) | El panel de voz dice "There's no app to open this link." en cada intento y el foco se queda en el título; en el árbol el orden es título → "Open-source licenses" → "Privacy policy" → aviso → "Close" | [Hecho] (que se anuncie **una sola vez** por intento no se puede contar con el panel: [Pendiente] 016; lo cubre CL-013-8 en tests) |

## 5. Orden del lector (CA-013-05) y paradas sin nombre (CA-013-04)

`uiautomator dump` (que sigue el orden de recorrido que Flutter manda a Android):

- **Nivel 1:** título → "Open-source licenses" → "Privacy policy, Opens a web page in the browser" → (aviso) → "Close". **Con el aviso va después de las opciones.** [Hecho]
- **Nivel 2:** título → filas ("nombre, N licencias") → "Back". [Hecho]
- **Nivel 3:** título → "License 1 of 57" → texto → … → "Back". [Hecho]
- En los tres niveles, ningún nodo enfocable o con `clickable` sin etiqueta (salvo el `FrameLayout` raíz de Android). [Hecho]
- **Nivel 3 con teclado** (`Focus` sin semántica): Tab llega a "Back", al título y al área de texto; AvPág ×2 y Fin la desplazan hasta "License 57 of 57"; Escape sube un nivel y vuelve a la fila de `angle` (Intro la reabre). [Hecho]
- **Nota (plan §7, B3):** con `includeSemantics: false` el área de texto del nivel 3 no tiene nodo propio para quien use TalkBack con teclado físico; con el teclado se desplaza igual. El anillo de foco **no se ve** en el emulador (teclas inyectadas, igual que en la 012): [Pendiente] 016 con un teclado real.
- **Observación:** con la app en español, la primera línea de la licencia de las bibliotecas de Android sigue en inglés ("Android libraries (AndroidX, Kotlin)" dentro del texto del archivo `android.txt`); es texto de la licencia (de terceros), no el título. Si se quiere traducir, es decisión del propietario.

## 6. Pendiente (para la 016 o para decidir)

- [ ] **F-1** y **F-2** (arriba): decidir si se arreglan en la 013 (recomendado F-1; F-2 también, o aceptar el límite).
- [ ] Foco real de TalkBack al volver del nivel 3 y al cerrar las hojas (a mano, con el dedo).
- [ ] Anillo de foco con teclado físico; Switch Access real (orden título → opciones → aviso → Volver).
- [ ] Anuncio único del aviso (contar los anuncios a oído); "Reintentar" con TalkBack.
- [ ] "Reducir movimiento" a ojo en el móvil (el hundido está medido en el emulador; ver F-1 para el relleno).
- [ ] *Goldens* en CI.
