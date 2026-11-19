# Plan técnico — Spec 028: Una en iOS, igual que en Android (paridad)

- **Spec:** `specs/028-ios-paridad/spec.md` (estado: **Aprobada**, 2026-11-19)
- **Documentos de partida:** `plan-f-ios.md` (fases I0–I9, modelo por fase, decisiones del propietario), `matriz.md` (matriz de paridad) y `docs/ios/channel-contract.md` (contrato de los canales). Este plan **no repite** lo que ya dicen: fija el orden, cómo se reparte el trabajo y cómo se verifica.
- **ADR aplicables:** ADR-0030 (notificaciones en iOS, opción A), ADR-0031 (deshacer sin tiempo del sistema), ADR-0032 (copias en iOS sin adjuntos), ADR-0004 y 0005 (copias y Data Protection), ADR-0013 a 0018 (adjuntos y web), ADR-0019 (selector de apps), ADR-0021 (deshacer), ADR-0025 (notificaciones, parte Android). **Sin ADR nuevo**: `openAppSettings` y `tools/ios-parity.sections` son contrato y herramienta, no arquitectura. Solo si I5 lleva a un **Diverge** de las redirecciones (R-3) habría un CA nuevo en la 028 con la decisión del propietario.
- **Estado del plan:** **Aprobado** por el propietario el 2026-11-19 («sí, aprobados con la recomendación»), con Q-P-1 aceptada. Antes **Borrador** (2026-11-19). Revisado por `spec-reviewer` el 2026-11-19 (2 bloqueantes, 10 importantes y 13 menores, **aplicados**; el B1 deja una pregunta al propietario, Q-P-1 en §7).

## 1. Resumen del enfoque

Traducir el código nativo de Android a Swift **por capa técnica y por riesgo** (`plan-f-ios.md`, «Estrategia»), con el Kotlin como implementación de referencia y una ficha del contrato por canal. Las fases de este plan son las **I2 a I8**; la I0 (Xcode) está hecha ([Hecho] 2026-11-19: `/Applications/Xcode.app`, runtime **iOS 27.2**, simuladores iPhone 18 Pro y 17e) y la I1 es la propia spec.

### 1.1 Cómo se trabaja cada tarea

- **Un `spec-task` por tarea, de una en una** (`/spec-implement 028`), con el **modelo de su fase**: **Sonnet** en I2, I3 e I7 (mecánico); **Opus** en I4, I5 e I6 (imágenes/PDF, WebView, notificaciones). La I8 y las tareas con el iPad las hace la **sesión coordinadora con Opus**, sin `spec-task` salvo para arreglos. El coordinador lanza el subagente con `model` según la columna **Modelo** de `tasks.md`.
- **Qué lee cada subagente:** su fila de `tasks.md`, la ficha de su canal en `channel-contract.md`, el `.kt` de referencia y el `.dart` del canal (mapa del contrato, §1), sus filas de la matriz y los CA que cita. **No** el historial de las specs 001–024.
- **Si el contrato y el Kotlin discrepan**, o una [Suposición] del contrato resulta falsa, el subagente **para y pregunta**; si es solo un detalle, actualiza la ficha y lo dice en la fila de Estado.
- **Cada tarea de canal actualiza los comentarios «iOS aún, D17»** de su lado Dart (contrato §10.6; [Hecho] hoy en `native_image_importer.dart:14`, `accessibility_timeouts.dart:24`, `attachment_rotation.dart:54`, `screen_awake.dart:23`, `notification_gateway.dart:123`, `providers.dart:150,164` y `webview_page_driver.dart:12`).
- **Ramas y PR:** una rama por fase desde `main` (`feat/028-i2-base`, `feat/028-i3-canales-simples`, `feat/028-i4-imagenes`, `feat/028-i5-webview`, `feat/028-i6-notificaciones`, `feat/028-i7-ci`, `feat/028-i8-cierre`), una PR por fase (squash), sin push hasta que lo confirme el propietario. Cada PR deja `main` compilando y con la CI en verde.
- **Tamaño:** el propietario pidió una tarea por bloque; T-028-13 (selección y copia) y T-028-18 (programador de notificaciones) pasan del «≤ medio día» de la plantilla y se aceptan así (una sesión cada una si hace falta).
- **Sesiones** (`docs/claude-code.md` §2.1): una por fase como regla; I4 puede necesitar dos. Se corta antes de una tarea que pide el iPad (T-028-20, T-028-23).

### 1.2 Verificación común: `/ios-check` y `tools/check-ios-parity.sh` (T-028-01)

La **primera tarea** crea las dos herramientas para que ninguna sesión vuelva a derivar comandos.

**`tools/check-ios-parity.sh`** (bash + `python3` de la biblioteca estándar, sin red; lee archivos del repo):

- **Interfaz:** `check-ios-parity.sh [--root DIR] [--section NOMBRE]…`. Sin `--section` corre las activas de `tools/ios-parity.sections` y lista las demás como `PENDIENTE`; con `--section` corre esa aunque esté inactiva (así el test prueba todas desde el primer día). `--root` (por defecto, el repo) permite pasarle un árbol de prueba. Los plist se leen con `python3` y `plistlib` (funciona en Ubuntu y macOS; nada de `plutil`), así que el test corre en el trabajo `flutter` de la CI.
- **Secciones:**

  | Sección | Qué comprueba | La activa |
  |---|---|---|
  | `project` | `IPHONEOS_DEPLOYMENT_TARGET = 16.0` y `TARGETED_DEVICE_FAMILY = 1` en todas las configuraciones (CA-028-04) | T-028-03 |
  | `plist` | `UIUserInterfaceStyle = Light`; la **única** clave `NS*UsageDescription` es `NSCameraUsageDescription`; `CFBundleLocalizations` = `en`, `es`, `ca`; orientaciones vertical + horizontales (CA-028-05, 08, 10, 13) | T-028-03 |
  | `l10n` | Cada `*.lproj/InfoPlist.strings` (`en`, `es`, `ca`) trae las mismas claves; `ca` = `es` (CA-028-08) | T-028-02 |
  | `launch` | El color de la pantalla de arranque = `paper` de `design/tokens.json`; sin imagen en el storyboard (CA-028-06) | T-028-04 |
  | `icon` | Ningún PNG de `AppIcon.appiconset` coincide en bytes con los de la plantilla de Flutter (sumas en `tools/fixtures/`); ninguno con canal alfa (cabecera IHDR) (CA-028-07) | T-028-04 |
  | `privacy` | `PrivacyInfo.xcprivacy` es un plist válido, `NSPrivacyTracking = false`, sin dominios ni tipos de datos recogidos; y una **tabla en el script** de API de motivo obligatorio → categoría (`volumeAvailableCapacity*`/`systemFreeSize` → `DiskSpace`; `creationDate`/`modificationDate`/`contentModificationDate` → `FileTimestamp`; `systemUptime`/`mach_absolute_time` → `SystemBootTime`; `UserDefaults` → `UserDefaults`): si un `.swift` usa una, su categoría debe estar declarada (CA-028-17) | T-028-07 |
  | `network` | Ningún `URLSession`, `NWConnection`, `CFNetwork` ni `print`/`NSLog`/`os_log`/`Logger` en `app/ios/Runner/*.swift` (CA-028-17, contrato §0.1) | T-028-01 |
  | `channel:<nombre>` | **De Kotlin a Swift:** cada método del `when` del `.kt` del canal tiene su `case "<método>"` en el `.swift` espejo (CA-028-20). Sin excepciones: un método que iOS no implementa (`debugPickManyDocuments`) tiene su `case` explícito que responde `FlutterMethodNotImplemented`; `configure` existe en los dos aunque cambie de forma; los métodos solo de iOS (`openAppSettings`) no afectan porque la comprobación va en un sentido | La tarea de cada canal |

- **Activación:** `tools/ios-parity.sections` lista las secciones activas (una por línea). **Cada tarea que hace verde una sección la añade.** En I7 (T-028-21) todas están activas y el test del script exige que la lista esté completa.
- **Test del propio script** en Dart (`app/test/tool/check_ios_parity_test.dart`, como `check_apk_locales_test.dart`), con un árbol de prueba en un directorio temporal y `--root`/`--section`: quitar un `case` del Swift, una clave de `InfoPlist.strings`, poner `UIUserInterfaceStyle = Dark`, añadir una segunda descripción de uso, un `URLSession`, un icono de la plantilla o una API de motivo obligatorio sin declarar → **falla**; el árbol bueno → pasa (CA-028-20).

**Skill `/ios-check`** (`.claude/skills/ios-check/SKILL.md`, de proyecto, escrita aquí; no se instala nada de fuera). Receta fija, desde `app/`:

1. `flutter build ios --simulator --debug`;
2. `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,id=<id>'` (XCTest; [Hecho] `RunnerTests` ya está en el esquema, `Runner.xcscheme:59-69`, con el `testExample` de la plantilla);
3. `flutter test integration_test/<archivos> -d <id>`: solo los que se le pasen; sin argumentos, ninguno; `todos` = los 19 (los de rendimiento, con su `skip:` en el simulador, §1.3);
4. `bash ../tools/check-ios-parity.sh`;
5. `flutter analyze --fatal-infos` y `flutter test`.

El simulador es el primer iPhone disponible de `xcrun simctl list devices available` (hoy iPhone 18 Pro, iOS 27.2); se puede pasar otro. **Preparación una vez por simulador:** confiar en el certificado de pruebas de `integration_test/fixtures/` con `xcrun simctl keychain <id> add-root-cert <pem>` (tests web con TLS local, T-028-17). La skill resume el resultado en una tabla (paso, verde/rojo, tiempo) y nunca hace `git push` ni toca la firma.

La misma tarea añade a `docs/testing.md` los comandos de iOS y a las **Trampas** de `.claude/agents/spec-task.md` una entrada «iOS: verificar con `/ios-check`; sin firma; el iPad lo usa solo el coordinador».

### 1.3 I2 — Base de plataforma (Sonnet; T-028-02 a 08)

- **Textos (T-028-02, primero):** `/strings-add` de `errCameraDenied`, `errCameraDeniedOpenSettings` y `settingsNotificationsPrivacyIos` (spec §7, ES/EN). `tool/gen_identity.dart` (que ya escribe `Identity.xcconfig` e `Info.plist`) genera además `ios/Runner/{en,es,ca}.lproj/InfoPlist.strings` con `CFBundleDisplayName` (de `identity.yaml`, P7) y `NSCameraUsageDescription`, y `CFBundleLocalizations`; `ca` es copia de `es` (como `values-ca` en la 024, CA-028-08). Su `--check` ya corre en la CI. [Suposición] Flutter en iOS recibe `NSLocale.preferredLanguages` sin reordenar; se comprueba con `ca-ES, en-US` en T-028-22.
- **Proyecto e `Info.plist` (T-028-03):** `TARGETED_DEVICE_FAMILY = 1` (fuera las claves `~ipad`), `UIUserInterfaceStyle = Light`, la apariencia de la barra de estado que necesite el `SystemUiOverlayStyle` de Dart (CA-028-05). **Orientaciones:** [Hecho] hoy `UISupportedInterfaceOrientations` solo trae vertical y Dart solo llama a `setPreferredOrientations` al girar (`attachment_rotation.dart:40`). Se declaran **vertical y las dos horizontales** (si no, iOS nunca deja girar) y la app **arranca y se queda en vertical**: Dart fija `[portraitUp]` antes del primer fotograma y `una/screen` abre las horizontales solo con el adjunto (T-028-10). Test de Dart: tras arrancar, solo vertical; en Android no cambia nada de lo que hoy hace el manifiesto.
- **Arranque e icono (T-028-04):** `tool/gen_tokens.dart` escribe un `LaunchBackground.colorset` con `paper` (sin variante oscura) y el `LaunchScreen.storyboard` queda como una vista de ese color, **sin imagen** (CA-028-06). `tool/gen_icons.dart` genera `AppIcon.appiconset` desde `design/prototype/assets/icon/icon-1024.png` (sin alfa) y borra los de la plantilla (CA-028-07).
- **Esqueleto de canales (T-028-05):** `UnaChannels.swift` registra los seis canales desde `didInitializeImplicitFlutterEngine` (`AppDelegate.swift`), cada uno con `FlutterMethodNotImplemented` hasta su fase; un XCTest real (el registro) sustituye a `testExample`.
- **Tests de integración en iOS (T-028-06, B1 de la revisión):** [Hecho] 14 de los 19 tests (`*_flow_test` y los 5 `*_perf_test`) lanzan `StateError` si la ruta de Documents no contiene `.debug` o `.profile` (p. ej. `complete_flow_test.dart:22`): es el `applicationIdSuffix` de Android y en iOS la ruta es un UUID. La guarda se lleva a `integration_test/support/test_app_guard.dart` con la regla de siempre en Android y, en iOS, **solo en el simulador** (`SIMULATOR_UDID` en el entorno) y fuera de *release*: nunca borra las tareas de un aparato real. No cambia lo que comprueba ningún test (CA-028-02). **Los 5 de rendimiento** se ejecutan con `flutter drive --profile` y [Suposición] el modo *profile* no existe en el simulador: llevan `skip:` en el simulador de iOS con el motivo, y lo que miden se mide en el iPad en T-028-23. La spec dice «hoy uno» saltado: esto añade cinco → **Q-P-1** (§7).
- **Datos en reposo y privacidad (T-028-07):** al arrancar el motor, el Swift crea `Application Support/attachments/` si falta y le pone `isExcludedFromBackup = true` (ADR-0032 dice «al crearla y al arrancar»: basta al arrancar porque [Hecho] Dart solo crea esa carpeta y nunca la borra, `file_attachment_store.dart:69`; si Dart la crea antes en el primer uso, el siguiente arranque la marca). `Caches/` ya queda fuera de la copia por iOS. **Protección de datos:** la clase por defecto («hasta el primer desbloqueo», ADR-0005), sin cambiarla; [Suposición] el simulador no la aplica, así que el XCTest comprueba que **no se baja** (ningún `.none` en el Swift, ningún entitlement de protección por defecto) y la clase real se lee en el iPad (T-028-23). `PrivacyInfo.xcprivacy` con lo de CA-028-17 (al menos `DiskSpace`, razón `E174.1`, para `freeSpace`); la sección `privacy` lo mantiene al día cuando I4–I6 añadan Swift.
- **Dependencias, binarios y licencias (T-028-08):** fijar `webview_flutter_wkwebview` en `pubspec.yaml` a la versión exacta del lock (P11; en el lock pasa de `transitive` a `direct main` sin cambiar versión, justificado en la PR según `threat-model.md` §5). Comprobar la [Suposición] de `path_provider_foundation` (temporal = `Caches`) y anotarla en el contrato §0.5. **Binarios nativos de iOS:** inventariar lo que entra en la compilación de iOS sin verificar (PDFium de `pdfium_dart`, sqlite3 si se descarga, cualquier otro *xcframework*), fijar sus huellas (`tools/pdfium.lock` u otro análogo) y ampliar `tools/check-pdfium.sh` para iOS. Licencias de lo que solo entra en iOS en `assets/licenses/`; `tools/check-licenses.sh` en verde. El APK de Android **no cambia** (CA-028-03).

### 1.4 I3 — Canales simples, selector de apps y gesto atrás (Sonnet; T-028-09 a 12)

- **`una/links` y `una/a11y` (T-028-09):** fichas §6 y §7. `LSApplicationQueriesSchemes` solo si `canOpenURL` lo exige para `mailto`/`tel`. Test de Dart de `UndoDuration` con los hechos de iOS (`recommendedMs: null`, servicio activo → 10 s; CA-028-14).
- **`una/screen` (T-028-10):** ficha §5 y §1.3. Primero se prueba si `SystemChrome.setPreferredOrientations` basta; solo si no, el Swift guarda las orientaciones y llama a `setNeedsUpdateOfSupportedInterfaceOrientations()`. El giro con un adjunto real necesita `una/images`: aquí, XCTest y test de Dart; el adjunto real, en T-028-15; en un iPhone, **[Pendiente sin iPhone]**.
- **Selector de apps (T-028-11):** ficha §8, en `SceneDelegate` con el color `paper` del `colorset` de T-028-04. Se prueba la [Pendiente I3] del contrato (diálogo de permisos).
- **Gesto atrás (T-028-12, Dart):** en `pageTransitionsTheme`, iOS usa **el mismo** constructor de transiciones que Android y, encima, un detector de arrastre desde el borde izquierdo que mueve la animación con el dedo; **al soltar, vuelve solo si pasó de la mitad** (CA-028-09; sin regla de velocidad), respetando `PopScope` (CA-002-07 y CA-005-05) y sin efecto en la tarea actual. Con reducir movimiento, la vuelta es inmediata. El escape de VoiceOver llega a Flutter como `handlePopRoute`, que ya respeta `PopScope`: test que lo fija. [Suposición] el detector de `CupertinoPageRoute` es privado: uno propio pequeño en `lib/ui/` (R-5). Entrada en `docs/design/prototype-deviations.md`.

### 1.5 I4 — Imágenes y PDF (Opus; T-028-13 a 15)

Ficha §2 entera.

- **Selección y copia (T-028-13):** `capabilities`, `pick` (cámara con los estados del permiso → `cameraDenied`; galería con `PHPickerViewController`; PDF con `UIDocumentPickerViewController(asCopy:)`), `pickMany` (`firstItems` portado con los casos de `PickedItemsTest.kt`, incluido el contador de accesos), `copy`, `cancel` (también la `Progress` de `loadFileRepresentation`), `freeSpace`, `debugCopyFile` (`#if DEBUG`, `Caches/fixtures/`) y `debugPickManyDocuments` (`case` explícito → no implementado). Método **solo de iOS** `openAppSettings` (abre `UIApplication.openSettingsURLString`; botón de CA-028-10). `openAppSettings` y `cameraDenied` se añaden al contrato §2 y §10.4.
- **Limpieza y codificación (T-028-14):** `sanitize`, `regenerate` y `encodeJpeg` con ImageIO/Core Graphics, en **una cola serie**, mismos nombres, tamaños y calidades. XCTest con imágenes generadas en el test (EXIF y GPS, orientación 6, HEIC, PNG con alfa, más píxeles que `maxPixels`, BGRA).
- **Dart y flujos (T-028-15):** los importadores conocen `cameraDenied` → aviso `errCameraDenied` con el botón (accesible como CA-007-22); test de widgets. IT `image_import`, `image_flow`, `photo_group_import`, `photo_group_flow`, `pdf_import` y `pdf_flow` en el simulador (aquí, porque necesitan `debugCopyFile` y `encodeJpeg`); el caso de `debugPickManyDocuments` se salta en iOS **con el motivo** y su sustituto (XCTest de T-028-13). Giro con adjunto real en el simulador.

### 1.6 I5 — WebView (Opus; T-028-16 y 17)

Ficha §3. **No se sustituye el delegado de navegación del paquete.**

- **Endurecimiento y borrado (T-028-16):** `harden`, `state` (lista final en la ficha), `destroy` y `clearData` en Swift sobre la `WKWebView` de `FWFWebViewFlutterWKWebViewExternalAPI`. En Dart (`webview_page_driver.dart`): `nativeId` también con `WebKitWebViewController.webViewIdentifier`; `webContentProcessTerminated` → `onProcessGone(crashed: true)` (ADR-0017). IT `webview_hardening`, `web_page_controller` y `web_flow`; la página en claro con el simulador en oscuro (CA-021-08).
- **Redirecciones y descargas (T-028-17):** con el certificado de pruebas de confianza en el simulador (§1.2), primero el IT contra `fixtures/selfsigned_tls.dart` (redirección del servidor, `http`→`https`, red local bloqueada, CL-009-1) y una respuesta que no es una página. `mainFrameRequest` por la opción (a) del contrato; `downloadBlocked` desde el error de WebKit de «cambio de política» en Dart. **Si (a) no se consigue, se para y se pregunta** (R-3).

### 1.7 I6 — Notificaciones (Opus; T-028-18 a 20)

ADR-0030 y ficha §4.

- **Programador en Dart (T-028-18):** etiqueta y texto portados de `TaskLabel.kt` y `NotificationText.kt` **con sus casos JUnit** (`TaskLabelTest`, `NotificationTextTest`, `SlotsTest` en lo que aplica); `slots` (0…3 de 08:55, 13:55, 18:55); `IosNotificationGateway` con `configure {on, slots}`; reprogramación al cambiar la tarea actual (crear, editar, completar, eliminar, deshacer, reordenar), el idioma, el interruptor o la cantidad, y al arrancar **tras el primer fotograma** (P2); **los cambios seguidos se agrupan en una sola llamada** (ADR-0030; con reloj inyectable). `notificationsPlatformProvider` `true` también en iOS; la fila usa `settingsNotificationsPrivacyIos` en iOS. Android **sin cambios** (CA-028-03).
  - **Tests existentes que cambian (B2 de la revisión):** [Hecho] cuatro tests fijan hoy que iOS queda fuera (CA-019-28): `test/app/feature_flags_test.dart:19`, `test/data/notification_gateway_test.dart:294`, `test/features/settings/notifications_row_test.dart:169` y `test/app/notifications_lifecycle_test.dart:168`. Como CA-028-15 **enmienda** CA-019-28 para iOS, esos casos pasan a comprobar lo nuevo; es la excepción explícita a CA-028-02 (§5). Los casos de la web no cambian.
- **Canal en Swift (T-028-19):** `UNUserNotificationCenter` (`canNotify`, `requestPermission`, `configure`, `cancelDelivered`, `setForeground`, `openSystemSettings`), delegado en `didFinishLaunching`, `willPresent` sin presentación con la app a la vista, `didReceive` de una notificación propia → `openCurrentTask`, categoría con `hiddenPreviewsBodyPlaceholder = publicBody`, sin insignia. **`configure` con `on: true` también quita las entregadas** (CA-028-16). **Sonido:** el `.default` del sistema, como el canal de Android con su sonido por defecto (cierra la [Pendiente] del contrato §4). **No guarda nada.** La llegada se prueba con XCTest programando una hora cercana directamente en el canal; la real, en el iPad.
- **Q-028-5 en el iPad (T-028-20, coordinador):** ¿se juntan varias notificaciones sin abrir la app? **«Una»** → CA-019-18 se cumple. **«Hasta 3»** → se para y el propietario decide entre (1) aceptarlo como divergencia o (2) un único identificador; con (2) [Suposición] solo queda **un** aviso pendiente, así que se programaría solo el siguiente y, sin abrir la app, los demás **no llegarían**. Se le explica antes de decidir.

### 1.8 I7 — CI (Sonnet; T-028-21)

El trabajo `ios` pasa a «iOS · build, XCTest y paridad»: además del build sin firmar, `xcodebuild test` en un simulador del ejecutor y `check-ios-parity.sh` con **todas** las secciones. ([Hecho] `gen_identity --check` y `gen_tokens --check` ya corren en el trabajo `flutter`, `ci.yml:85-86`: no se repiten; si `gen_icons` no tiene `--check` en la CI, se añade allí.) IT en el simulador: se mide el tiempo; si caben en ~15 min van al trabajo, si no, un trabajo aparte a mano (`workflow_dispatch`). Acciones fijadas por SHA. Se ajusta `app/test/tool/ci_detect_test.dart` (`needs` e `if` del trabajo `ios`). Los trabajos de Android **no cambian**. T-028-21 depende de T-028-19 (no del iPad).

### 1.9 I8 — Auditoría y cierre (Opus coordinador; T-028-22 a 25)

- **Simulador (T-028-22):** los 19 IT (`/ios-check todos`, con los `skip:` motivados), además con el sistema en oscuro, con `ca-ES, en-US` y en modo avión (CA-001-11). **iOS 16:** se intenta bajar el runtime; si no está, **[Pendiente]** en `dispositivo.md`.
- **iPad (T-028-23, coordinador con el propietario):** filas «Disp» y «VO» de la matriz; arranque en frío n ≥ 20 en *profile*/*release* (< 1 s) y lo que miden los `*_perf_test`; memoria con 10 fotos (ADR-0024); clase de protección real (CA-028-18); cámara (conceder, denegar, volver); Live Photo y HEIC; selector de apps; app y barras en claro con el sistema en oscuro; web en oscuro y una descarga; notificaciones (cerrada, a la vista, bloqueo); VoiceOver en los flujos de CA-028-21, incluido el **escape** con dos dedos. Resultados en `dispositivo.md`. Solo tareas ficticias.
- **Revisores (T-028-24):** `security-reviewer` (Swift y Dart), `a11y-reviewer` (aviso de cámara, gesto atrás, fila de notificaciones; parte de CA-028-21), `/security-check`, `/i18n-check`, `/tokens-validate`. Los altos, con un `spec-task` antes de cerrar.
- **Cierre (T-028-25):** matriz completa (CA-028-01), `spec-reviewer`, `docs/PLAN.md`, `CLAUDE.md`, nota iOS en ADR-0025, `docs/environments.md` (CA-028-18), **[Pendiente I9]** actualizar la política de privacidad antes de distribuir cualquier compilación de iOS (ADR-0030), y pregunta por el «Muy pronto en App Store» de la web. Spec **Implementada**.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Ninguno |
| Datos | `lib/data/import/native_{image,pdf}_importer.dart`, `lib/data/platform/notification_gateway.dart` (+ programador de iOS) | `cameraDenied` y `openAppSettings` (I4); `IosNotificationGateway`, etiqueta y texto en Dart (I6) |
| Estado | `lib/app/providers.dart` | Rama iOS de `notificationsPlatformProvider` y `notificationGatewayProvider` (I6) |
| Presentación | `lib/features/web/webview_page_driver.dart`, aviso de cámara, fila de Notificaciones, vertical al arrancar, `pageTransitionsTheme` y detector del gesto atrás (`lib/ui/`) | I2–I6 |
| Nativo | `app/ios/Runner/*.swift` (un archivo por canal + `DataAtRest`, `RecentsPrivacy`), `Info.plist`, `{en,es,ca}.lproj/InfoPlist.strings`, `PrivacyInfo.xcprivacy`, `Assets.xcassets`, `LaunchScreen.storyboard`, `Runner.xcodeproj`, `app/ios/RunnerTests/*Tests.swift` | I2–I6 |
| l10n | `lib/l10n/app_{es,en}.arb` | Tres claves nuevas (T-028-02) |
| Tests de integración | `integration_test/support/test_app_guard.dart` (nuevo), los 14 que usan la guarda, `skip:` en los 5 de rendimiento y en el caso de `debugPickManyDocuments` | T-028-06, 15 |
| Herramientas | `tools/check-ios-parity.sh`, `tools/ios-parity.sections`, `tools/{pdfium.lock,check-pdfium.sh}`, `.claude/skills/ios-check/SKILL.md`, `tool/gen_{identity,icons,tokens}.dart`, `.github/workflows/ci.yml`, `docs/testing.md`, `.claude/agents/spec-task.md` | T-028-01 a 04, 08 y 21 |
| Documentación | `matriz.md`, `channel-contract.md`, `dispositivo.md` (nuevo), `docs/design/prototype-deviations.md`, `docs/PLAN.md`, `CLAUDE.md`, ADR-0025, `docs/environments.md` | Cada tarea sus filas de la matriz; el resto en I8 |

## 3. Modelo de datos y migraciones

No cambia el esquema (sigue el **v3**). Las notificaciones de iOS no guardan nada (ADR-0030).

## 4. Dependencias nuevas

**Ningún paquete nuevo.** El Swift usa solo frameworks del sistema (contrato §0.6). `webview_flutter_wkwebview` ya está en el lock; T-028-08 la **fija** como directa (P11) sin cambiar la versión, justificada en la PR según `threat-model.md` §5. **Binarios nativos** que entran solo en iOS (PDFium y, si aplica, sqlite3): se inventarían, se fijan sus huellas y se verifican como el `.so` de Android (`tools/check-pdfium.sh`), con sus licencias (T-028-08).

## 5. Estrategia de tests

**CA-028-02 en este plan:** ningún test existente cambia lo que comprueba, con **dos excepciones explícitas**: (1) los cuatro tests que fijan que iOS no tiene notificaciones (§1.7), porque CA-028-15 enmienda CA-019-28; (2) la guarda de los IT y los `skip:` motivados de iOS (§1.3), que no cambian lo que se comprueba en Android. `git diff test/ integration_test/` se revisa contra esta lista en cada PR.

| Criterio de aceptación | Tipo de test | Archivo / lugar | Tareas |
|---|---|---|---|
| CA-028-01 | Matriz con todas las filas con resultado; `spec-reviewer` | `matriz.md` | Todas (sus filas), T-028-22, 25 |
| CA-028-02 | `flutter test` con las dos excepciones; 19 IT en el simulador con `skip:` motivados | `app/test/`, `app/integration_test/` | T-028-06, 15, 18, 21, 22 (y `/ios-check` en todas) |
| CA-028-03 | CI de Android en verde; `check-android-permissions.sh` sin cambios; diff de Dart contra el contrato §10 | CI | T-028-03, 08, 18, 21, 24 |
| CA-028-04 | Script `project`; simulador iOS 16 si hay runtime | `check-ios-parity.sh` | T-028-03, 22 |
| CA-028-05 | Script `plist`; IT con el simulador en oscuro; web en claro; iPad | `check-ios-parity.sh`, `integration_test` | T-028-03, 16, 22, 23 |
| CA-028-06 | Script `launch`; arranque en frío n ≥ 20 en el iPad | `check-ios-parity.sh`, `dispositivo.md` | T-028-04, 23 |
| CA-028-07 | Script `icon` + test de `gen_icons` | `check-ios-parity.sh`, test del generador | T-028-04 |
| CA-028-08 | Scripts `plist` y `l10n`; test de `gen_identity`; simulador con `ca-ES, en-US` | `check-ios-parity.sh`, test del generador | T-028-02, 03, 22 |
| CA-028-09 | Widgets con `TargetPlatform.iOS` (arrastre, mitad, `PopScope`, tarea actual, reducir movimiento, `handlePopRoute`, carrusel y listado); escape de VoiceOver en el iPad | `test/ui/ios_back_gesture_test.dart` | T-028-12, 23 |
| CA-028-10 | Script `plist` (única descripción de uso); XCTest de los estados del permiso y sin cámara; widgets del aviso (anuncio, foco, ≥ 44, 200 %); iPad con VoiceOver | `check-ios-parity.sh`, `RunnerTests/ImagesTests.swift`, test de widgets | T-028-02, 03, 13, 15, 23 |
| CA-028-11 | XCTest (tope y contador, copia acotada, cancelar, tokens ajenos, limpieza, orientación, HEIC, alfa); IT de imagen, grupo y PDF; Live Photo y HEIC en el iPad | `RunnerTests/{PickedItems,Images,Sanitizer}Tests.swift`, `integration_test` | T-028-13, 14, 15, 23 |
| CA-028-12 | XCTest de la vista que tapa; iPad | `RunnerTests/RecentsPrivacyTests.swift` | T-028-11, 23 |
| CA-028-13 | Script `plist` (orientaciones); test de Dart (vertical al arrancar); XCTest de `una/screen` y `una/links`; giro con adjunto en el simulador; iPhone **[Pendiente]** | `RunnerTests/{Screen,Links}Tests.swift`, tests de Dart | T-028-03, 09, 10, 15 |
| CA-028-14 | Unitario de `UndoDuration`; XCTest de `una/a11y`; iPad con VoiceOver | test de `UndoDuration`, `RunnerTests/A11yTests.swift` | T-028-09, 23 |
| CA-028-15 | Dart (programador, fila en iOS); XCTest del canal; iPad | tests de Dart, `RunnerTests/NotificationsTests.swift` | T-028-18, 19, 23 |
| CA-028-16 | Dart (qué y cuándo se programa, agrupación, cancelar, etiqueta con los casos JUnit portados, texto de privacidad iOS); XCTest (programa lo recibido, quita las entregadas, no guarda nada, `willPresent`, `didReceive`, hora cercana); iPad (Q-028-5 y la pasada) | tests de Dart, `RunnerTests/NotificationsTests.swift` | T-028-02, 18, 19, 20, 23 |
| CA-028-17 | Scripts `privacy` y `network`; binarios verificados; `security-reviewer`; `/security-check` | `check-ios-parity.sh` | T-028-01, 07, 08, 24 |
| CA-028-18 | XCTest (`isExcludedFromBackup`, protección no bajada); clase real en el iPad; nota en `docs/environments.md` | `RunnerTests/DataAtRestTests.swift` | T-028-07, 23, 25 |
| CA-028-19 | XCTest de `una/webview`; IT de la web, del endurecimiento y de redirecciones y descargas; iPad | `RunnerTests/WebViewHardeningTests.swift`, `integration_test` | T-028-16, 17, 23 |
| CA-028-20 | Test del script; XCTest real; CI con XCTest y script | `test/tool/check_ios_parity_test.dart`, `ci.yml` | T-028-01, 05, 21 |
| CA-028-21 | `dispositivo.md` con todas las filas «Disp» y «VO»; `a11y-reviewer` | `dispositivo.md` | T-028-23, 24 |

Todos los tests citan su CA (`'CA-028-NN: …'`; en XCTest, en el nombre de la función o un comentario). Tests que miden texto, con `setUpAll(loadAppFonts)`. Sin red en los tests (el servidor TLS de los fixtures es local).

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad:** errores solo como código, sin registrar URI, rutas, nombres ni texto (sección `network`); tokens de selección opacos y validados; `debugCopyFile` solo con `#if DEBUG` y rutas canónicas en `Caches/fixtures/`; la guarda de los IT en iOS solo actúa en el simulador; WebView sin inspección en *release*, sin ventanas nuevas, datos borrados; binarios nativos verificados (T-028-08); la excepción de ADR-0030 ya está en `threat-model.md` T-2. Sin entitlements ni capacidades nuevas (sin notificaciones remotas). El certificado de pruebas solo va al llavero del **simulador**. `security-reviewer` en I8.
- **Firma:** firma gratuita solo en el Mac del propietario; ningún perfil, certificado ni `DEVELOPMENT_TEAM` en el repositorio (revisión del diff de `project.pbxproj` en cada PR). Bundle ID del repo: `invalid.pending.app` (PD-2); el de desarrollo vive fuera del repo [Suposición: se comprueba en T-028-20].
- **Accesibilidad:** aviso de cámara (CA-007-22), gesto atrás con su alternativa (botón visible y escape de VoiceOver), card con VoiceOver (CA-028-14), fila de notificaciones; pasada única con VoiceOver en I8.
- **Rendimiento:** antes del primer fotograma solo se registran canales, se fija la vertical y se crea/excluye `attachments/`; la reprogramación de notificaciones va **después**. T-028-04 y T-028-07 tocan el arranque de iOS y la DoD pide medirlo en esas PR: **se acepta medirlo una sola vez en el iPad (T-028-23)**; la cifra del simulador no sirve. Arranque < 1 s (CA-028-06).

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| R-1 · Los ejecutores macOS no traen el simulador o tardan demasiado con los IT | XCTest y script siempre; IT a mano si pasan de ~15 min (T-028-21) |
| R-2 · `PHPicker` con fotos solo en iCloud o Live Photos distinto del contrato | CL-028-5 → `unreadable`; XCTest con un proveedor falso; iPad (T-028-23) |
| R-3 · Sin aviso de redirección del servidor sin sustituir el delegado del paquete | T-028-17 empieza por el test; si falla (a), **se para y se pregunta** |
| R-4 · El texto de la notificación en Dart diverge del de Kotlin | Casos JUnit portados tal cual; mismos textos ARB |
| R-5 · El detector de arrastre propio interfiere con carrusel, listado o zoom | Franja del borde (20 pt), solo en rutas con atrás; tests (T-028-12) |
| R-6 · El modo de compatibilidad del iPad no reproduce el iPhone | Aceptado: **[Pendiente sin iPhone]** (CL-028-10) |
| R-7 · No hay runtime de iOS 16 | **[Pendiente]** en `dispositivo.md` (CA-028-04) |
| R-8 · La firma gratuita caduca a los 7 días | Se reinstala antes de T-028-20 y T-028-23 |
| R-9 · Q-028-5 sale «hasta 3» | El propietario decide en T-028-20 sabiendo que el «único identificador» deja **un solo** aviso pendiente (§1.7) |
| R-10 · El simulador no aplica la protección de datos | XCTest de que no se baja; la real en el iPad |
| R-11 · El modo *profile* no existe en el simulador | `skip:` motivado en los 5 `*_perf_test`; medidas en el iPad (Q-P-1) |

**Alternativas descartadas:** `flutter_local_notifications` (ADR-0030, opción C); una spec por funcionalidad como en Android; comprobar la paridad con un agente en cada tarea; regla de velocidad en el gesto atrás (CA-028-09 no la pide).

**Preguntas para el propietario:**

- **Q-P-1 [Resuelta: aceptada, propietario, 2026-11-19; anotada en CA-028-02]** CA-028-02 dice que hoy solo se salta **un** caso en iOS. Con el plan se saltan además, **solo en el simulador**, los **5 tests de rendimiento** (`*_perf_test`, que necesitan el modo *profile*), y sus medidas se toman en el iPad (T-028-23). Recomendación: **aceptarlo** y anotar en la spec que son seis los saltados, con su sustituto.
- Quedan las ya previstas: Q-028-5 (en T-028-20) y, solo si se da R-3, la de las redirecciones (T-028-17).
