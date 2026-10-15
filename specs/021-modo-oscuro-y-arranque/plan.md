# Plan técnico — Spec 021: Modo oscuro y arranque

- **Spec:** `specs/021-modo-oscuro-y-arranque/spec.md` (estado: **Aprobada**, 2026-10-15)
- **ADR aplicables:** ADR-0019 (vuelta sin instantánea; enmienda de CA-011-03 ya anotada), ADR-0017 (endurecimiento de la WebView), ADR-0026 (licencias: sin cambios). **Sin ADR nuevo**: no hay dependencia ni excepción a ningún principio.
- **Estado del plan:** **Aprobado** por el propietario el 2026-10-15 («aplica los cambios que he comentado»), con P-021-1 y P-021-2 resueltas (§7). Antes Borrador (2026-10-15). Revisado por `security-reviewer` (sin altos; 2 medios y 2 bajos, aplicados: `noDarkening` en `state()`, página de prueba `https` sin relajar protecciones, `stash` desechable, «Recientes» en el cierre) y `a11y-reviewer` (1 alto, 3 medios y 2 bajos, aplicados: barra de navegación por versión en API 26, velo de las hojas, la regla de P-021-1 también para la WebView, divisor y C-021-12 concreta).

## 1. Resumen del enfoque

[Hecho, leído en el código el 2026-10-15] Hoy la parte de Flutter **ya es siempre clara**: `MaterialApp` solo tiene `theme: UnaTheme.light()` (sin `darkTheme`) y nadie lee `platformBrightness`. Lo que cambia con el sistema en oscuro es **todo lo nativo**:

- `res/values-night/styles.xml` hereda de `Theme.Black.NoTitleBar` (arranque y ventana **negros**, `isLightTheme = false`);
- `drawable(-v21)/launch_background.xml` pinta `?android:colorBackground` o blanco, nunca `paper`;
- el *splash* de Android 12+ no tiene atributos propios: usa el icono adaptable entero (de ahí el círculo amarillo en oscuro) sobre el fondo del tema;
- nadie fija el color de los iconos de las barras ni el velo de la barra de navegación de tres botones (con `targetSdk` 36, Android 15+ dibuja *edge-to-edge* y pone el velo por defecto);
- la WebView recibe `prefers-color-scheme` según `isLightTheme` del tema de la actividad (Android 13+), que hoy es oscuro en oscuro.

Por eso la 021 es casi toda de **recursos de Android** más dos piezas pequeñas (Dart y Kotlin):

1. **Un solo tema claro para claro y oscuro.** Se borra `values-night/` y los dos `launch_background.xml`. `values/styles.xml` define una base `UnaWindow` sobre `Theme.Light.NoTitleBar` con `android:windowBackground = @color/paper` (un color liso: es el arranque de Android 8–11, CA-021-03, y el fondo de la ventana, CA-021-05) y una capa `UnaBars` encima; `LaunchTheme` y `NormalTheme` heredan de `UnaBars`. Los atributos que el sistema ignora sin daño si no los conoce van en el **mismo archivo** con `tools:targetApi`. La barra de navegación **no**: en API 26 no existe `windowLightNavigationBar`, y una barra transparente sobre `paper` dejaría los iconos blancos sobre papel (≈ 1,1:1). Por eso:
   - `values/styles.xml` → `UnaBars` en API 26: barra de estado transparente con iconos oscuros (`windowLightStatusBar`, API 23) y **la barra de navegación por defecto del sistema** (oscura con iconos claros: la excepción de CA-021-09);
   - `values-v27/styles.xml` → solo redefine `UnaBars` (mismo padre `UnaWindow`): además, `navigationBarColor` transparente y `windowLightNavigationBar = true`. Así lo único duplicado por versión son las barras.

   Lo demás, en `UnaWindow` con `tools:targetApi`:
   - *splash* de Android 12+ (`tools:targetApi="31"`): `windowSplashScreenBackground = @color/paper` y `windowSplashScreenAnimatedIcon = @drawable/ic_launcher_foreground` (el **mismo** PNG del primer plano de la 018, sin copiarlo: CA-021-11). **Sin** `windowSplashScreenIconBackgroundColor`: un icono sin fondo de icono se dibuja a 288 dp dentro de un círculo de 192 dp, que es exactamente la geometría 108/72 dp del primer plano adaptable (×8/3), y no lleva círculo (CA-021-01/02). [Suposición, C-021-1/2] el sistema no añade el círculo amarillo cuando el icono no es el adaptable.
   - sin velo en las barras (CA-021-09, Q-021-5): `enforceStatusBarContrast` y `enforceNavigationBarContrast = false` (`tools:targetApi="29"`).
   - `forceDarkAllowed = false` (`tools:targetApi="29"`): la app no se deja oscurecer, ni por el fabricante ni por el ajuste de accesibilidad (P-021-1, §7).
2. **Color `paper` en un recurso nuevo** `values/colors.xml` (`<color name="paper">#F4F1EA</color>`), escrito a mano con un comentario que apunta al token. Un test (CA-021-04) lee `design/tokens.json` y falla si no coincide: es justo lo que pide el CA («si `paper` cambia en los tokens, la comprobación falla hasta que el arranque se actualice»). No se toca `gen_icons.dart` ni `ic_launcher_background.xml` (CA-021-11: iconos idénticos).
3. **Barras con la app abierta (Dart).** `appFrame` (`lib/app/una_app.dart`) envuelve la app en un `AnnotatedRegion<SystemUiOverlayStyle>` con barras transparentes, `systemNavigationBarDividerColor` transparente, iconos oscuros y los dos `…ContrastEnforced: false`. Un único estilo global: [Hecho, leído] ninguna pantalla pinta un fondo oscuro a sangre detrás de una barra (fotos y PDF quedan fuera del criterio). **Excepción a medir:** el velo de las hojas (`UnaColors.scrim`, `ink` al 55 %, `lib/ui/una_sheet.dart`) cubre la barra de estado; [Suposición] los iconos oscuros podrían quedar en ≈ 3:1 o menos sobre él. C-021-7 lo mide con una hoja abierta (y con la card de deshacer); si no llega a 3:1, la hoja lleva su propio `AnnotatedRegion` con iconos claros mientras está abierta (lo hace T-021-03 si se ve antes, o se corrige tras C-021-7). Además, `themeMode: ThemeMode.light` explícito en los dos `MaterialApp` (documenta la decisión; sin efecto visible hoy).
4. **WebView sin oscurecer (Kotlin).** En `WebViewHardening.harden`, dentro del mismo `settings.apply`: `settings.isAlgorithmicDarkeningAllowed = false` en API 33+ y `settings.forceDark = WebSettings.FORCE_DARK_OFF` en API 29–32 (API de la plataforma, sin `androidx.webkit`: P11). Con el tema claro, la página ya recibe `prefers-color-scheme: light` en Android 13+; esto cubre además el oscurecimiento algorítmico y la WebView de versiones anteriores (CA-021-08). **Se añade a `state()`** una clave `noDarkening` (API 33+: `!isAlgorithmicDarkeningAllowed`; API 29–32: `forceDark == FORCE_DARK_OFF`; API < 29: `true`, no hay oscurecimiento que apagar), así `harden` comprueba al releer los ajustes que quedó apagado y devuelve `false` si no (ADR-0017: no se carga la página). Se actualiza el mapa exacto de `integration_test/webview_hardening_test.dart` (CA-009, se corre en el emulador en T-021-06). El orden respecto a `setNavigationDelegate` y el envoltorio no cambian.
5. **Nada más cambia.** `configChanges` ya incluye `uiMode` (la actividad no se recrea al cambiar el modo: CA-021-07); un test lo fija para que no se pierda.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Ninguno |
| Datos | `android/…/WebViewHardening.kt` | Oscurecimiento de la WebView desactivado (§1.4) |
| Estado | — | Ninguno |
| Presentación | `lib/app/una_app.dart` | `AnnotatedRegion<SystemUiOverlayStyle>` en `appFrame`; `themeMode: ThemeMode.light` |
| Nativo | `res/values/styles.xml`, `res/values-v27/styles.xml` (nuevo, solo `UnaBars`), `res/values/colors.xml` (nuevo); se borran `res/values-night/styles.xml`, `res/drawable/launch_background.xml`, `res/drawable-v21/launch_background.xml` | Tema único claro, `paper`, *splash* de 12+, barras (§1.1–2) |
| l10n | — | Ninguno (CA-021-11) |
| Documentación | `docs/design/prototype-deviations.md` (DEV-57), `docs/glossary.md` (4 términos de la spec), `docs/architecture.md` §2 «Splash nativo», `docs/PLAN.md` («Casillas de la 021» para la 022) | |

## 3. Modelo de datos y migraciones

No cambia el esquema (sigue el v3).

## 4. Dependencias nuevas

Ninguna (ni de desarrollo). No se usa `androidx.core-splashscreen` (los atributos de la plataforma bastan: en Android 8–11 no hay icono, Q-021-3) ni `androidx.webkit` (las llamadas de §1.4 son de la plataforma).

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-021-01, 02, 03, 04, 05 | Recursos: se parsea `res/` (todas las carpetas `values*` y `drawable*`): no existe ninguna variante `-night`; `LaunchTheme` y `NormalTheme` heredan de un tema claro; `windowBackground` y `windowSplashScreenBackground` resuelven a `@color/paper` = `color.paper` de `tokens.json`; `windowSplashScreenAnimatedIcon` = `@drawable/ic_launcher_foreground`; si aparece `windowSplashScreenIconBackgroundColor`, también `paper`; ningún `launch_background` ni `<bitmap>` en el arranque; ningún otro color literal en los estilos salvo `@android:color/transparent` de las barras; **barras por versión**: en `values/` (API 26) `UnaBars` no hace transparente la barra de navegación ni pide iconos oscuros en ella, y en `values-v27/` sí (y hereda de la misma base) | `test/app/launch_theme_test.dart` |
| CA-021-06 | Widgets (*goldens*): las suites de *goldens* existentes se vuelven a ejecutar con `platformBrightnessTestValue = Brightness.dark` contra **los mismos PNG** de claro (si un píxel cambia, falla). Se cubren las pantallas de la lista del CA que ya tienen *golden*; las que falten (p. ej. aviso de error al guardar, «Cargar URL», marco de la web) se comparan claro contra oscuro con `captureImage` en el mismo test | `test/goldens/dark_mode_golden_test.dart` (+ ayuda en `test/support/`) |
| CA-021-07 | Widgets: con texto sin guardar en el editor, una hoja abierta, la card de deshacer a mitad de su tiempo y el carrusel desplazado, se cambia `platformBrightness` y se comprueba que el estado se conserva, que no se navega y que la card sigue con el tiempo que le quedaba. Más un test de fuente: `configChanges` del manifiesto contiene `uiMode` | `test/app/dark_mode_state_test.dart` |
| CA-021-08 | Fuente (como `native_no_logging_test`): `harden` desactiva el oscurecimiento algorítmico (API 33+) y `forceDark` (API 29–32) y `state()` lo comprueba (`noDarkening`). Integración en el emulador: `webview_hardening_test.dart` con la clave nueva. El resultado real, casilla C-021-6 | `test/app/webview_dark_test.dart`, `integration_test/webview_hardening_test.dart` |
| CA-021-09 | Widgets: con la app en cada pantalla y el brillo en claro y en oscuro, `SystemChrome.latestStyle` = barras transparentes, iconos oscuros, sin contraste forzado. Recursos: los atributos de barras del `LaunchTheme` (en `launch_theme_test.dart`). El contraste medido, casilla C-021-7 | `test/app/system_bars_test.dart` |
| CA-021-10 | Medida (casilla C-021-9, `tools/measure-cold-start.sh`, n ≥ 20 alternando con `main`, claro y oscuro) | `specs/021-modo-oscuro-y-arranque/dispositivo.md` |
| CA-021-11 | Test: SHA-256 de `ic_launcher_foreground.png`, `ic_launcher_background.xml`, `mipmap-anydpi/ic_launcher.xml`, los 5 `ic_stat_una.png` y `store/google-play/icon-512.png` igual a los de `main` (valores fijados en el test); `gen_icons --check` sigue sin diferencias. Los permisos y las dependencias ya los vigilan `check_android_permissions_test` y `check_licenses`; los textos, `/i18n-check`. Trabajo de publicación en modo testers en la PR | `test/icon/icon_checksums_test.dart` |
| CA-021-12 | Casilla C-021-8 (`tools/check-recents.sh` y `screenrecord`) | `dispositivo.md` |
| CL-021-4, 7, 8, 10; §6 | Casillas C-021-10 a 12, la medida de T-021-01 y, en T-021-06, la app con «Tema oscuro ampliado» y con «Anular forzar modo oscuro» encendidos (debe seguir igual; si el sistema lo ignora, límite del sistema). C-021-12 concreta: «Quitar animaciones» de Accesibilidad **y** las tres escalas de animación a 0 en las opciones de desarrollo; TalkBack encendido no anuncia nada durante el arranque | `dispositivo.md` |

Todos los tests citan su CA (`'CA-021-04: …'`). Los de *goldens* empiezan con `setUpAll(loadAppFonts)`.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (checklist):** sin red, permisos, datos ni dependencias. El único cambio en la WebView **restringe** (desactiva el oscurecimiento, verificado por `state()`); no toca `harden` en lo demás ni su orden (ADR-0017). Sin nuevas superficies de ataque. `threat-model.md`: sin cambios. Como cambia `LaunchTheme`, el `/security-check` del cierre repasa la sección «Recientes» de la checklist (C-021-8 y `tools/check-recents.sh`).
- **Medidas en el emulador (T-021-01):** la página de prueba de CA-021-08 **no** se sirve por `http://` ni `file:` (los bloquean `network_security_config.xml`, la validación de URL y `allowFileAccess = false`, y **no se relajan** ni siquiera en local): se usa una página `https` pública que respete `prefers-color-scheme`, solo en el emulador, o se compara en el Chrome del emulador.
- **Accesibilidad:** sin interacción, textos ni anuncios nuevos. Contraste: «u.» `ink` sobre `paper` ≈ 17:1; iconos oscuros del sistema sobre `paper`, medidos en C-021-7 (≥ 3:1). El arranque deja de pasar de negro a claro (menos destello, §6 de la spec). El ajuste de accesibilidad que oscurece las apps **no** se aplica a la app (P-021-1, decisión del propietario; revoca Q-021-7).
- **Rendimiento:** el arranque pasa de un `layer-list` a un color liso (no más caro) y el *splash* de 12+ dibuja un PNG que ya está en el APK. Sin trabajo nuevo antes del primer fotograma en Dart (un `AnnotatedRegion` es un nodo más del árbol). Se mide igualmente (CA-021-10).

## 7. Riesgos, alternativas y preguntas

**Decisiones del propietario (2026-10-15, al aprobar el plan):**

- **P-021-1 · El oscurecimiento forzado, también el de accesibilidad → la app se queda siempre igual.** Propietario: «Me da igual el modo oscuro. La aplicación se queda siempre igual». Se pone `android:forceDarkAllowed="false"` en `UnaWindow` (`tools:targetApi="29"`) y la WebView apaga siempre su oscurecimiento (§1.4), **sin distinguir** el forzado del fabricante o de las opciones de desarrollo (CL-021-7) del «Tema oscuro ampliado» de Android 16 (CL-021-8). **Revoca Q-021-7**; la spec queda enmendada (CL-021-8, §6 y §9). No es una excepción a P6: ningún criterio de WCAG 2.2 AA exige seguir el modo oscuro del sistema; sin ADR. [Hecho, por cómo funciona Android] el forzado de oscuro del sistema no llega a lo que dibuja Flutter (su propia superficie): el atributo cubre el fondo de la ventana y la WebView. [Suposición, sin documentación oficial] si un sistema o un fabricante ignora el atributo, se anota como límite del sistema y no bloquea (T-021-06 lo comprueba en el emulador; HyperOS, en la 022).
- **P-021-2 · Barra de navegación en Android 8.0 con la app abierta → aceptada.** En el arranque se cumple la excepción de CA-021-09 tal cual (§1.1: barra del sistema, oscura). Con la app abierta, [Suposición, por leer en el motor en T-021-03] Flutter podría pedir iconos oscuros ya desde API 26 (`SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR` es de API 26) y la barra saldría `paper` con iconos oscuros. Se acepta cualquiera de las dos (oscura con iconos claros, o como en el resto) con 3:1 o más; precisión anotada en la excepción de CA-021-09. Si la barra quedara transparente con iconos claros, T-021-03 fija un color de barra oscuro para API 26. Se comprueba en PD-10 (022).

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| El sistema sigue dibujando un círculo detrás del icono del *splash* o lo recorta | C-021-1/2. Alternativa: `windowSplashScreenIconBackgroundColor = @color/paper` (círculo invisible, icono a 240 dp: la «u.» se vería algo más pequeña; se anotaría en DEV-57) |
| Flutter en Android < 15 no dibuja *edge-to-edge* y la barra transparente deja ver otra cosa | El fondo de la ventana ya es `paper`; C-021-7 lo comprueba. Si hiciera falta, `navigationBarColor = @color/paper` en vez de transparente |
| El *splash* desde la notificación (CL-021-4) sale sin icono | Aceptado por la spec (`paper` liso); C-021-10 |
| Al volver sin instantánea el sistema pinta otro color que no sea blanco ni `paper` | C-021-8; si pasa, se para y se pregunta (no regresión de CA-011-03) |
| Los *goldens* en oscuro fallan por algo que ya era distinto (p. ej. el menú de selección de texto) | Es justo lo que busca CA-021-06: se corrige en Dart (tema), no en el test |

**Alternativas descartadas:** `values-night` con los mismos valores que `values` (dos copias que se desincronizan); `androidx.core-splashscreen` (dependencia, P11, y no aporta nada sin icono en 8–11); generar `colors.xml` con `gen_icons.dart` (mezcla el arranque con los iconos, que la 021 no debe tocar; el test de CA-021-04 ya obliga a mantenerlo al día).
