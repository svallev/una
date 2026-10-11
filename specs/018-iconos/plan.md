# Plan técnico — Spec 018: Iconos

- **Spec:** `specs/018-iconos/spec.md` (estado: Aprobada, 2026-10-10)
- **ADR aplicables:** ninguno nuevo y sin tocar la constitución (sigue la 1.9). Decisiones de producto: D29 («hechos a mano y sin dependencias»), D12 (mínimo Android 8: todos los móviles admitidos pintan iconos adaptables), D17 (sin iOS), D4 (web de pruebas), DEV-55.
- **Estado del plan:** **Aprobado** por el propietario el 2026-10-10 (acepta P-018-1 a 5: generador en Dart, monocromo = primer plano, carpeta `store/google-play/`)

## 1. Resumen del enfoque

**Es un cambio de recursos, no de código de la app.** La fuente única (CA-018-10) son los PNG del tablero 17 que ya están en `design/prototype/assets/icon/`: el original de 1024 (RGB, 268 colores por el suavizado, `#FFE55C` y `#111111`) y el primer plano de 432 (RGBA, solo tinta `#111111` y alfa). Medidos el 2026-10-10 (Node, solo para este plan): la «u.» del original ocupa x 225–798 → **56,05 % del lado**, con la esquina más lejana a **33,3 %** del lado (cabe en la zona segura de un «maskable», 40 %); en el primer plano de 432 ocupa x 135–296, y 164–267 → **162 px = 40,5 dp = 56,25 % del círculo de 72 dp**, centrada en (216, 216), con la esquina más lejana a **≈ 24,1 dp** del centro (≤ 33 dp).

1. **Android (CA-018-01 a 07, 11, 14).** Icono adaptable declarativo, **sin generador de recursos**:
   - `res/mipmap-anydpi/ic_launcher.xml` (`<adaptive-icon>`; sin sufijo `-v26` porque `minSdk = 26`): fondo `@color/ic_launcher_background`, primer plano `@drawable/ic_launcher_foreground` y **`<monochrome>`**.
   - `res/drawable-nodpi/ic_launcher_foreground.png`: **copia exacta** del `adaptive-foreground-432.png` (432 px = 108 dp × 4; `nodpi` porque el sistema lo estira a los límites de la capa, no lo escala por densidad).
   - `res/values/ic_launcher_background.xml`: `<color name="ic_launcher_background">#FFE55C</color>`, **generado desde el token `palette.classic.0`** (no se copian valores a ciegas, CA-018-03), con la cabecera «GENERADO» como `strings.xml`.
   - Se **borran** los 5 `mipmap-*/ic_launcher.png` de la plantilla (con `minSdk = 26` no hacen falta, D12). `AndroidManifest.xml` no cambia: `android:icon="@mipmap/ic_launcher"` ya apunta al nombre y pasa a resolver al XML adaptable (y el nombre sigue siendo `@string/app_name`, CA-018-11). Sin `android:roundIcon` (el adaptable ya se recorta).
   - **Capa monocroma = el mismo drawable del primer plano.** Medido: el `adaptive-monochrome-432.png` del tablero difiere del primer plano en **22 píxeles de borde por 1/255 de alfa**; CA-018-04 pide alfa **idéntica píxel a píxel**. Como el sistema tiñe solo con el alfa y el primer plano es tinta maciza, `<monochrome android:drawable="@drawable/ic_launcher_foreground"/>` cumple CA-018-04 **por construcción**, sin segundo recurso (ver P-018-2 en §7). El PNG del tablero queda en `design/` como referencia.
2. **Google Play (CA-018-08).** `store/google-play/icon-512.png` en la **raíz del repo** (fuera de `app/`, no se empaqueta ni está en `pubspec.yaml`): el original de 1024 reducido a 512 (promedio de áreas 2 × 2, exacto en un factor entero) y guardado como **RGBA con alfa 255** (el original es RGB; Play pide 32 bits).
3. **Web de pruebas (CA-018-09).** `web/favicon.png` (**32 × 32**), `web/icons/Icon-192.png`, `Icon-512.png` y los dos `Icon-maskable-*` (iguales a los anteriores: el original a sangre, ya cabe en la zona segura de los «maskable»). `web/manifest.json`: `background_color` y `theme_color` → `#FFE55C` (del token), se **quita** `description`; `web/index.html`: se **quita** `<meta name="description">`. Nada más.
4. **Un generador sin dependencias** (CA-018-10 y 15): `app/tool/gen_icons.dart` + `app/tool/png_lite.dart`, en el estilo de `gen_identity.dart` y `gen_tokens.dart` (se lanza con `dart run tool/gen_icons.dart [android|play|web]` desde `app/`; solo `dart:io`, `dart:convert` y `ZLibCodec`; **ni va en `lib/` ni se empaqueta**). `png_lite` decodifica PNG de 8 bits RGB/RGBA sin entrelazar, reduce por promedio de áreas y codifica RGBA. Es lo que hay que lanzar si cambia el dibujo o el nombre (CL-018-7). Los tests **no lo reutilizan** para medir (decodifican con `dart:ui`), de modo que un fallo del generador no se esconde a sí mismo.
5. **Tests (todo Dart, sin paquetes nuevos, CA-018-12).** Leen los PNG con `dart:ui` y la cabecera IHDR a mano; los colores, de `design/tokens.json`. Las plantillas de Flutter que se retiran se guardan antes como fixtures (CA-018-06).

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio / Datos / Estado / Presentación | — | **Ninguno** (CA-018-12: el diff de `lib/` queda vacío) |
| Nativo (recursos, no código) | `android/app/src/main/res/mipmap-anydpi/ic_launcher.xml` (nuevo), `drawable-nodpi/ic_launcher_foreground.png` (nuevo), `values/ic_launcher_background.xml` (nuevo, generado); **borrados** `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` | Icono adaptable con tema. Ni `.kt`, ni `AndroidManifest.xml` (ni permisos), ni Gradle |
| Tienda | `store/google-play/icon-512.png` (nuevo, raíz del repo) | PNG de Play; no empaquetado |
| Web de pruebas | `app/web/favicon.png`, `app/web/icons/Icon-*.png` (4), `app/web/manifest.json`, `app/web/index.html` | Iconos nuevos, `theme_color` y `background_color` = `#FFE55C`, sin descripción de plantilla |
| Herramientas | `app/tool/gen_icons.dart`, `app/tool/png_lite.dart` (nuevos) | Generador (no es `lib/`) |
| Tests | `app/test/icon/*` (nuevos), `app/test/support/icon_image.dart`, `app/test/tool/gen_icons_test.dart`, `app/test/fixtures/flutter_template_icons/` | Ver §5 |
| Documentación | `docs/design/app-icon.md` (nuevo: CA-018-15), `docs/architecture.md`, `docs/testing.md`, `docs/design/screen-map.md` (nota del monocromo), `specs/018-iconos/dispositivo.md` | Ver T-018-05, 06 y 07 |
| l10n | — | **Ninguno** (sin textos; CA-018-11) |

## 3. Modelo de datos y migraciones

**No cambia el esquema** (sigue v3). Sin migración, sin captura y sin datos.

## 4. Dependencias nuevas

**Ninguna, ni de desarrollo** (CA-018-12, D29, P11). `pubspec.yaml`, `pubspec.lock` y Gradle sin cambios. El paquete `image` está en el `pubspec.lock` solo como transitivo: **no se importa** (el analizador lo marcaría `depend_on_referenced_packages` y sería, de hecho, una dependencia). Para el generador y los tests alcanzan `dart:io`, `dart:ui` y `ZLibCodec`. Sin red.

## 5. Estrategia de tests

Cada test cita su CA. Los que miden píxeles no necesitan fuentes (`loadAppFonts` no hace falta: no hay texto). Todos leen recursos del repo con rutas relativas a `app/` (el directorio de `flutter test`), como `check_release_config_test.dart`.

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| Ayudas: leer IHDR, decodificar a RGBA con `dart:ui`, medir la figura (caja de píxeles con alfa > 0, ancho relativo, centro, distancia máxima al centro) y leer `palette.classic.0` e `ink` de `design/tokens.json` | Soporte (con un test de sí mismo sobre las fuentes del tablero: x 135–296, y 164–267) | `test/support/icon_image.dart`, `test/icon/icon_image_support_test.dart` |
| CA-018-01 (ancho 56 % ± 1 pp del círculo de 72 dp y caja centrada ± 1 dp), CA-018-02 (todo píxel opaco a ≤ 33 dp; fondo = `<color>` que llena los 108 dp), CA-018-03 (fondo = `palette.classic.0`; primer plano solo tinta, transparencia y suavizado de tinta ±10), CA-018-04 (el XML declara `<monochrome>`, su alfa es idéntica a la del primer plano, el punto es macizo), CA-018-05 (el primer plano no depende del monocromo: mismo recurso, sin capa propia), CA-018-07 (≥ 432 px y mismo tamaño) | Unitario de recursos | `test/icon/android_adaptive_icon_test.dart` |
| CA-018-06 (el manifiesto declara `@mipmap/ic_launcher`, que resuelve a un `<adaptive-icon>`; sin `ic_launcher.png` en `res/`, comparando **bytes** con los fixtures de la plantilla; sin recursos `ic_launcher*` huérfanos), CA-018-11 (nombre = `@string/app_name` generado de `identity.yaml`; contraste de los dos tokens ≈ 14,9 : 1 ≥ 3 : 1), CA-018-14 (sin recursos de icono en `src/debug` ni `src/profile`) | Unitario de recursos | `test/icon/android_icon_packaging_test.dart` |
| CA-018-08 (RGBA, 512 × 512, < 1024 KB, alfa 255 en todo píxel, cuatro esquinas `#FFE55C`, diferencia media ≤ 2/255 frente al original reducido; no declarado en los *assets* de `pubspec.yaml`) | Unitario de recursos | `test/icon/play_icon_test.dart` |
| CA-018-09 (tamaños 32/192/512 y «maskable» 192/512; ningún icono igual **byte a byte** a la plantilla; esquinas `#FFE55C`; en los «maskable» la esquina más lejana de la «u.» a ≤ 40 % del lado; `theme_color` y `background_color` = `palette.classic.0`; ni `0175C2` ni «A new Flutter project» en `app/web/`; el nombre del manifiesto sigue siendo `Una.`) | Unitario de recursos | `test/icon/web_icons_test.dart` |
| CA-018-10 (en Android, Play y web: ancho relativo 56 % ± 1 pp, caja centrada, mismos colores, nada más) | Unitario de recursos, tabla de las cuatro versiones | `test/icon/icon_coherence_test.dart` |
| El generador: ida y vuelta de `png_lite` (codificar → decodificar), reducción por promedio de áreas (2 × 2 exacta; color liso se conserva) y `--check`: el generador, lanzado sobre un directorio temporal, produce los bytes que hay en el árbol | Unitario de herramienta | `test/tool/gen_icons_test.dart` |
| CA-018-12 | Comprobaciones, no test: `git diff main...HEAD -- app/lib '*.kt' app/pubspec.yaml app/pubspec.lock app/android/**/build.gradle*` vacío; `tools/check-android-permissions.sh` en verde | T-018-05 y cierre |
| CA-018-13 | Medición: `tools/measure-cold-start.sh` antes/después (mismo emulador de API 37) | T-018-06 |
| CA-018-15 | Revisión de `docs/design/app-icon.md` frente a las medidas de los tests | T-018-05 y cierre |
| C-018-1 a 7 (apariencia) | Casillas a mano en `dispositivo.md` | T-018-06 (emulador), T-018-07 (Xiaomi), 022 |

*Goldens:* **no** se añaden (no hay pantalla de la app; el icono es un recurso del sistema y lo cubren los tests de píxeles). Sin pruebas de integración nuevas.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (`docs/security/checklist.md`):** sin permisos, red, datos, código nativo ni dependencias nuevas; el generador solo lee y escribe archivos del repositorio (rutas fijas, sin entrada del usuario ni red) y no se empaqueta. Se pasa `/security-check` al cerrar; no se prevé revisión de `security-reviewer` del plan (ninguna superficie suya: no hay importación, URL, almacenamiento, permisos ni CI). Lo único «externo» que cambia en la web de pruebas es el manifiesto (`start_url`, `display`, `orientation`… quedan como están).
- **Accesibilidad (P6):** sin interacción nueva; no se prevé `a11y-reviewer` del plan. El nombre bajo el icono sale de `identity.yaml`; contraste ≈ 14,9 : 1; la capa con tema es maciza. TalkBack en el lanzador (C-018-7) va a la 022.
- **Rendimiento (P2, CA-018-13):** un PNG de 432 px (unos pocos KB) y un XML; el arranque no depende de él. Se mide antes/después. **Riesgo a comprobar:** el *splash* de Android 12+ pinta el icono adaptable sobre el fondo del tema (no se toca, es de la 021); se mira en el emulador (C-018-5).
- **Tamaño del APK:** baja (se quitan 5 PNG de la plantilla; entra uno).
- **Build:** `<monochrome>` exige `compileSdk` ≥ 33 (Flutter fija el suyo, mayor); `flutter build apk --debug` en T-018-03 lo comprueba y el job Android de CI lo repite.

## 7. Riesgos, alternativas y decisiones para el propietario

**Decisiones del plan que se apartan de la letra de la spec o la interpretan** (la aprobación del plan las cubre; ninguna cambia un CA):

- **P-018-1 · El generador es Dart (`app/tool/gen_icons.dart`), no un script de shell.** La spec admite «comandos documentados o un script en `tools/` (shell, no se empaqueta)». Los generadores del proyecto ya son Dart en `app/tool/` (`gen_identity.dart`, `gen_tokens.dart`) y la mayoría de herramientas de `tools/` son shell o Node. Un shell no puede **añadir canal alfa** a un PNG ni reducir sin depender de `sips` (solo macOS; además `sips` deja el PNG de Play en RGB y Play lo quiere RGBA). Un Dart propio de ~150 líneas con `ZLibCodec` es portable, **testeable** y no es código de `lib/`. *Alternativa descartada:* `sips` + un `python3 -I` para el alfa (dos herramientas, solo macOS, no probable en CI). *Alternativa:* comandos manuales documentados (más fáciles de equivocar). **Recomendación: Dart.**
- **P-018-2 · La capa monocroma es el mismo drawable del primer plano, no el `adaptive-monochrome-432.png` del tablero.** Ese PNG difiere del primer plano en 22 píxeles de borde por 1/255 de alfa (medido); CA-018-04 exige igualdad exacta y el sistema tiñe solo con el alfa. Compartir el recurso la garantiza y quita un PNG. *Alternativa:* copiar el del tablero y relajar CA-018-04 a «± 1/255» (cambia la spec). **Recomendación: compartir.** El monocromo del tablero queda en `design/` como referencia (nota en `screen-map.md`).
- **P-018-3 · Carpeta de la tienda: `store/google-play/` en la raíz del repo.** Fuera de `app/` por construcción (no hay forma de que acabe en el APK ni en los *assets*); la 023 (ficha) puede colgar de ahí el resto. *Alternativa:* `design/store/` (mezcla fuentes con entregables). **Recomendación: `store/google-play/`.**
- **P-018-4 · Favicon de 32 × 32** (la spec exige ≥ 32). Los «maskable» 192/512 son el mismo dibujo que los normales (el original ya cabe en la zona segura de 40 %, CA-018-09).
- **P-018-5 · Un solo PNG para las tres densidades:** `drawable-nodpi` con el de 432 px (nitidez hasta 640 dpi, CA-018-07), en lugar de cinco PNG por densidad.

**Riesgos**

| Riesgo | Mitigación |
|---|---|
| El lanzador del Xiaomi (HyperOS) recorta o encuadra distinto | C-018-2 en el Xiaomi al implementar (T-018-07); la zona segura mide 24 dp de 33 |
| Lanzadores que guardan el icono viejo en caché (CL-018-6) | Se anota en `dispositivo.md`; los testers instalan una versión nueva desde cero |
| `dart:ui` no decodifica en `test()` fuera de un binding | `TestWidgetsFlutterBinding.ensureInitialized()` y, si hiciera falta, `tester.runAsync`; ya se hace en los tests de imágenes del proyecto |
| El nombre de la app (provisional) cambia | CL-018-7: hay que rehacer el icono; `docs/design/app-icon.md` dice cómo (CA-018-15) |
