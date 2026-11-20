# Contrato de los canales nativos (Android → iOS)

- **Estado:** Borrador (2026-11-19, spec 028, fase I1). Lo actualiza cada tarea que implementa un canal si descubre algo distinto (y lo dice en su `tasks.md`).
- **Para qué:** cada tarea de iOS lee **solo su ficha** y su archivo Kotlin de referencia, no el historial de specs. El Kotlin manda: si esta ficha y el Kotlin discrepan, **se para y se pregunta** (CLAUDE.md).
- **Fuentes:** Kotlin en `app/android/app/src/main/kotlin/invalid/pending/app/` y el lado Dart de cada canal (rutas en cada ficha). Leído el 2026-11-19 sobre `b04345f`.
- **Etiquetas:** **[Hecho]** = leído en el código; **[Suposición]** = propuesta para iOS sin comprobar; **[Pendiente]** = se decide en la fase indicada.

## 0. Reglas comunes a todos los canales

1. **Errores solo como código**: `FlutterError(code:, message: nil, details: nil)` [Hecho en los errores previstos; **excepción [Hecho]**: en `una/images`, un `id` inválido o un argumento que falta lanza fuera de cualquier `try` (`ImageImport.kt:98,105,115-124`) y la embebida de Flutter responde `"error"` con mensaje y traza]. **En Swift no se copia esa excepción:** un argumento inválido responde `unreadable` en `una/images` e `invalid_argument` en `una/notifications`, siempre sin texto (Dart ya traduce cualquier código desconocido a `unreadable`). Nunca un mensaje, una URI, una ruta, un nombre de archivo ni texto de tareas (CL-007-10, CL-009-9, CL-016-16, CA-019-23). Nada de `print`/`NSLog`/`os_log` con datos.
2. **Método desconocido** → `FlutterMethodNotImplemented` [Hecho: `notImplemented()` en todos].
3. **Argumentos:** se validan como en Kotlin. En `una/images` el `id` es un texto que cumple `^[A-Za-z0-9_-]{1,64}$`; en `una/webview` el `id` es un **entero** (`webViewIdentifier`) y no se le aplica esa expresión.
4. **Hilos:** el trabajo de disco e imagen fuera del hilo principal; la respuesta (`result`) **siempre** en el principal [Hecho: `main.post`]. En Swift: `DispatchQueue` propias y `DispatchQueue.main.async { result(...) }`.
5. **Rutas** [Hecho]: deben ser **las mismas que usa Dart** con `path_provider`:
   - preparación: `getTemporaryDirectory()/import/<id>/` → en iOS `NSCachesDirectory/import/<id>/` [Hecho, T-028-08: leído en `path_provider_foundation` 2.6.0 (`path_provider_foundation_real.dart`): `getTemporaryPath` devuelve `NSCachesDirectory` del dominio de usuario];
   - guardados: `getApplicationSupportDirectory()/attachments/<id>/` → `NSApplicationSupportDirectory/attachments/<id>/` [Hecho, T-028-08: `getApplicationSupportPath` devuelve `NSApplicationSupportDirectory` y la crea; el sufijo con el identificador del bundle solo se añade en macOS, no en iOS]. Si se actualiza `path_provider_foundation`, `app/test/tool/ios_dependencies_test.dart` lo vuelve a comprobar.
6. **Sin dependencias nuevas** en Swift (P11): solo frameworks del sistema (UIKit, PhotosUI, UniformTypeIdentifiers, ImageIO, CoreGraphics, WebKit, UserNotifications).
7. **Registro:** un archivo Swift por canal en `app/ios/Runner/`, espejo del `.kt`, registrado desde `didInitializeImplicitFlutterEngine` (`AppDelegate.swift`) con el `binaryMessenger` del registrador del plugin `Runner` (patrón de `FlutterImplicitEngineDelegate`). Hay `SceneDelegate.swift`: los avisos de ciclo de vida (inactiva / activa) salen de la escena.
8. **Pruebas:** los casos de los tests JUnit de Android (`app/android/app/src/test/`) se portan a **XCTest** (`app/ios/RunnerTests/`). La lógica pura va en tipos sin UIKit para probarla sin simulador de UI.

## 1. Mapa

| Canal | Kotlin | Dart | Spec | Ficha | Fase |
|---|---|---|---|---|---|
| `una/images` | `ImageImport.kt`, `ImageSanitizer.kt`, `PickedItems.kt` | `lib/data/import/native_image_importer.dart`, `native_pdf_importer.dart` | 007, 008, 016 | §2 | I4 |
| `una/webview` | `WebViewHardening.kt` | `lib/data/web/webview_hardening.dart`, `web_data_janitor.dart`; `lib/features/web/webview_page_driver.dart` | 009, 021 | §3 | I5 |
| `una/notifications` | `notifications/*.kt` (`NotificationsChannel.kt`) | `lib/data/platform/notification_gateway.dart` | 019 | §4 | I6 |
| `una/screen` | `MainActivity.kt`, `AttachmentRotation.kt` | `lib/data/platform/screen_awake.dart`, `attachment_rotation.dart` | 007, 008, 015 | §5 | I3 |
| `una/links` | `LinkOpener.kt` | `lib/data/links/native_link_opener.dart` | 008, 015 | §6 | I3 |
| `una/a11y` | `AccessibilityTimeouts.kt` | `lib/data/platform/accessibility_timeouts.dart` | 014 | §7 | I3 |
| (sin canal) selector de apps | `RecentsPrivacy.kt` | — | 011 | §8 | I3 |

## 2. `una/images` (I4)

Todo lo que escribe va a la preparación (`import/<id>/`) o, para `encodeJpeg`/`regenerate` con destino guardado, a `attachments/<id>/`. **Nunca** a la fototeca ni a archivos compartidos. Errores [Hecho]: `busy`, `noCamera`, `unreadable`, `tooLarge`, `tooManyPixels`, `noSpace`, `cancelled` (Dart traduce cualquier otro a `unreadable`). **Nuevo en iOS [Pendiente, Q-028-1]:** `cameraDenied` (CA-028-10); hasta que Dart lo conozca, Dart lo trata como `unreadable`.

| Método | Argumentos | Respuesta | Comportamiento [Hecho, Android] | iOS |
|---|---|---|---|---|
| `capabilities` | — | `{heic: bool}` | `true` desde API 28 | `{heic: true}` (ImageIO lee HEIC en iOS 16). |
| `pick` | `{origin: "camera"\|"gallery"\|"file", id}` | `null` (cancelado) o `{token, name}` (`name` siempre presente; `null` salvo con `file`, `ImageImport.kt:285`) | Una sola llamada pendiente (si no, `busy`). Cámara: escribe en `import/<id>.camera`, token `camera:<id>`; sin app de cámara → `noCamera`. Galería: selector de fotos. `file`: documentos, solo `application/pdf`; `name` = nombre visible (≤ 1024, Dart recorta a 120). | Cámara: `UIImagePickerController(.camera)`; sin cámara (`isSourceTypeAvailable` falso) → `noCamera`; permiso `AVCaptureDevice.authorizationStatus` denegado/restringido → `cameraDenied`; la imagen se escribe en `import/<id>.camera` (JPEG desde `UIImage` **sin metadatos**; la limpieza recodifica igual). Galería: `PHPickerViewController` (`selectionLimit = 1`, filtro `.images`), token opaco propio (p. ej. `picker:<uuid>` que apunta a un `NSItemProvider` guardado en memoria; **nunca** una ruta de Dart). `file`: `UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)`; `name` = `lastPathComponent`. |
| `pickMany` | `{max}` (1…10, se acota) | `null` o `{tokens: [String], total: int}` | Tope **antes** de abrir ninguna (`PickedItems.firstItems`): solo se miran los `min(count, max)` primeros; `total` = lo que devolvió el sistema. Errores solo como código. | `PHPickerConfiguration.selectionLimit = max`, `selection = .ordered`; recorte con un `firstItems` portado (XCTest del contador de accesos, CA-020-21). |
| `freeSpace` | — | `int?` (bytes) | `filesDir.usableSpace`; 0 o fallo → `null`. | `volumeAvailableCapacityForImportantUsage` de Application Support; fallo → `null`. **API de motivo obligatorio** → manifiesto (CA-028-17). |
| `copy` | `{token, id, maxBytes, headBytes?}` (`headBytes` 1…1024, por defecto 64; lo envía solo el importador de PDF) | `{byteSize: int, head: Uint8List}` | Copia por bloques de 64 KB a `import/<id>/source` contando bytes; pasa de `maxBytes` → `tooLarge`; 0 bytes → `unreadable`; sin espacio → `noSpace`; cancelada → `cancelled`; cualquier fallo borra `import/<id>/`. Token `camera:` borra el `.camera` al terminar. Solo contenido de otras apps (nunca archivos propios). | Token `camera:` igual. Token de galería: `NSItemProvider.loadFileRepresentation` (tipo imagen; para una **Live Photo** solo la imagen fija) y copia acotada desde ese archivo temporal. Token de PDF: la URL de la copia del selector (dentro de `tmp/` de la app; se borra al terminar). **Ninguna otra ruta** se acepta como token (equivale a `isForeignContent`). Copia en una cola; cancelable entre bloques. |
| `sanitize` | `{id, type: "jpeg"\|…, maxPixels, storedMaxPixels}` | `{width, height, byteSize}` | **Un solo hilo** propio; si se canceló mientras esperaba turno, `cancelled` sin hacer nada. Decodifica leyendo la cabecera antes de reservar: `w*h > maxPixels` → `tooManyPixels`; reduce a ≤ `storedMaxPixels`; sRGB; orientación EXIF aplicada; quita la *gainmap* HDR; transparencia sobre blanco. Escribe `full-<fila>-<col>.jpg` (teselas ≤ 4096, calidad 90), `screen.jpg` (ancho de pantalla en vertical, solo la parte de arriba si es más alta; calidad 85) y `thumb.jpg` (176 × 176 recortada, calidad 80). Borra `source` siempre. | ImageIO: `CGImageSourceCopyPropertiesAtIndex` para el tamaño antes de decodificar; `CGImageSourceCreateThumbnailAtIndex` con `kCGImageSourceCreateThumbnailWithTransform` y `MaxPixelSize` para reducir y orientar; dibujar en un `CGContext` sRGB opaco **blanco** y escribir con `CGImageDestination` **sin propiedades** (sin EXIF/GPS/XMP/miniatura). Mismos nombres, tamaños y calidades (0,90 / 0,85 / 0,80). Cola serie propia. Tamaño de pantalla: `UIScreen.main.nativeBounds` en vertical. |
| `regenerate` | `{id, width, height}` | `null` | Rehace `screen.jpg` y `thumb.jpg` de `attachments/<id>/` desde las teselas, decodificando solo la zona recortada. Falta el directorio → `unreadable`. | Igual con `CGImageSourceCreateThumbnailAtIndex`/recorte por tesela. |
| `encodeJpeg` | `{id, target: "staging"\|"stored", width (1…8192), height (1…16384), bgra: bool, pixels: Uint8List}` | `null` | Tamaño fuera de rango o `pixels.size != w*h*4` → `unreadable` (`ImageImport.kt:534-535, 572-573`); BGRA→RGBA si `bgra`; escribe `screen.tmp` y renombra a `screen.jpg` (calidad 85). Si el directorio de destino no existe (**cualquiera de los dos**, `:536-538`) → éxito sin hacer nada. | `CGContext` con `byteOrder32Little` + `premultipliedFirst` para BGRA (sin copiar); escritura atómica (`.atomic`). |
| `cancel` | `{id}` | `null` | Marca la cancelación, cierra el flujo abierto (desbloquea una lectura parada) y borra `import/<id>/` e `import/<id>.camera` en otro hilo. | Igual; cancela además la `Progress` de `loadFileRepresentation` si está en curso. |
| `debugPickManyDocuments` | `{max}` | como `pickMany` | Solo en depuración; fuerza el selector de documentos de Android 8–12. | `FlutterMethodNotImplemented` (no hay equivalente; el test de integración que lo usa se salta en iOS). |
| `debugCopyFile` | `{path, id, maxBytes, headBytes?}` | como `copy` | Solo en depuración (`FLAG_DEBUGGABLE`); `path` dentro de `cache/fixtures/` o `/dev/zero`, `/dev/urandom`. | Solo con `#if DEBUG`; `path` dentro de `Caches/fixtures/` (comparando rutas canónicas) o `/dev/zero`, `/dev/urandom`. |

Notas [Hecho]: `pending` sin llamada al volver (la app murió con la cámara abierta) se ignora; el barrido de Dart borra lo que quede. Dart vuelve a recortar `tokens` a `max` y rechaza tipos inesperados.

## 3. `una/webview` (I5)

**Diferencia de fondo [Hecho, leído en `webview_flutter_wkwebview` 3.26.1]:** el paquete es dueño del `WKNavigationDelegate` y ya traduce `webViewWebContentProcessDidTerminate` a un error de carga de tipo `webContentProcessTerminated` (no hace falta envolver nada para ADR-0017). La `WKWebView` nativa se obtiene con `FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier:withPluginRegistrar:)` y el identificador de `WebKitWebViewController.webViewIdentifier`. **No se sustituye el delegado del paquete** (romperíamos su navegación).

| Método / aviso | Argumentos | Respuesta | Android [Hecho] | iOS |
|---|---|---|---|---|
| `harden` | `{id}` | `bool` (todo leído de vuelta) | Sin archivos ni contenido, sin datos de formularios, sin contenido mixto, Safe Browsing, sin ventanas nuevas, sin oscurecer (021), descargas → aviso, sin depuración en *release*, envoltorio del cliente. Se llama **después** de `setNavigationDelegate`. | `preferences.javaScriptCanOpenWindowsAutomatically = false`; `isFraudulentWebsiteWarningEnabled = true` (equivalente a Safe Browsing); `isInspectable = false` fuera de depuración (iOS 16.4+); `overrideUserInterfaceStyle = .light` (la página ve `prefers-color-scheme: light`, CA-021-08); contenido mixto: WebKit bloquea el activo por defecto [Suposición: comprobar el pasivo en I5]; sin acceso a archivos: la página es `https` y no hay `loadFileURL` [Suposición]. Devuelve `true` si todo se lee de vuelta. |
| `state` | `{id}` | `{clave: bool}` o `null` | `noFileAccess`, `noContentAccess`, `noFormData`, `noMixedContent`, `safeBrowsing`, `noMultipleWindows`, `noDarkening`, `wrapped`. | Las mismas claves con su equivalente; las que no existen en iOS valen `true` y se anotan aquí al implementar. `wrapped` = `true` (no hay envoltorio; ver arriba). [Pendiente I5: lista final] |
| `destroy` | `{id}` | `null` | `WebView.destroy()` | `stopLoading()` y `loadHTMLString("")`; la vista la libera el paquete al desmontarse. |
| `clearData` | `{id?}` | `bool` | Cookies, almacenamiento web y caché de todas las WebView, con una temporal si no hay viva; `true` al guardarse en disco. | `WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)` y `true` en su *completion*. No hace falta una vista viva. |
| → `renderProcessGone` | `{id, crashed}` | — | Desde el envoltorio. | **No lo envía el Swift**: el error `webContentProcessTerminated` del paquete llega a Dart, que lo trata como `WebRenderProcessGone(crashed: true)` (§10). |
| → `downloadBlocked` | `{id}` | — | `DownloadListener`. | [Pendiente I5] El paquete responde `allow` a toda respuesta; WebKit **no descarga** sin `.download`, y una respuesta que no puede mostrar falla con un error de carga [Suposición]. Opción preferida: Dart trata ese error (código WebKit 102, «interrumpida por cambio de política») como descarga bloqueada. Alternativa: observar en Swift con KVO. |
| → `mainFrameRequest` | `{id, redirect}` | — | Antes de cada petición del marco principal (T-009-12). | [Pendiente I5] WebKit llama a `decidePolicyFor navigationAction` también en las redirecciones del servidor, sin decir que lo son. Opciones: (a) añadir en Swift un observador de `didReceiveServerRedirectForProvisionalNavigation` **sin quitar** el delegado del paquete (proxy que reenvía todo); (b) sin el aviso, `takeServerRedirect` devuelve `false` (`webview_hardening.dart:100-101`) y **las redirecciones del servidor dejarían de seguirse** (rompe CL-009-1 y cualquier dirección que redirija, p. ej. `http`→`https`): solo es aceptable como **Diverge** registrado en la 028 con la decisión del propietario. Se decide en I5 con un test de integración contra el servidor TLS de `fixtures/selfsigned_tls.dart`. |

## 4. `una/notifications` (I6, ADR-0030)

En iOS el canal es **mucho más pequeño**: no lee la BD ni calcula texto. Dart calcula título y cuerpo y los manda ya hechos.

| Método | Argumentos | Respuesta | Android [Hecho] | iOS |
|---|---|---|---|---|
| `canNotify` | — | `bool` | Permiso + notificaciones y canal activos. | `getNotificationSettings`: `authorizationStatus == .authorized` (o `.provisional`/`.ephemeral`) **y** `alertSetting == .enabled`. |
| `requestPermission` | — | `{granted, dialogShown}` | Diálogo solo si hace falta; con otra petición en curso, `{false, false}` (`NotificationsChannel.kt:113-115`). | `.notDetermined` → `requestAuthorization(options: [.alert, .sound])`, `dialogShown: true`; otro estado → sin diálogo, `granted` = `canNotify`. |
| `configure` | Android: `{on, perDay (1…3), lang ("es"\|"en"\|…)}` | `null` o error | Guarda la copia derivada y programa alarmas. | **Cambia de forma:** `{on, slots: [{hour, minute, title, body, publicBody}]}` (0…3 elementos). Cancela lo pendiente y programa un `UNNotificationRequest` por elemento con `UNCalendarNotificationTrigger(dateMatching: {hour, minute}, repeats: true)`, sin sonido propio salvo `.default` [Pendiente Q-028-5/I6], sin insignia, `threadIdentifier` fijo y una categoría con `hiddenPreviewsBodyPlaceholder = publicBody`. `on: false` o lista vacía → cancela todo y quita lo entregado. **No guarda nada** más (ni `UserDefaults` ni archivos). Argumentos inválidos → `invalid_argument`. |
| `cancelDelivered` | — | `null` | Quita la notificación mostrada. | `removeAllDeliveredNotifications()`. |
| `setForeground` | `bool` | `null` | Indicador «a la vista» con latido. | Guarda el valor en memoria; `willPresent` devuelve `[]` si es `true` (CA-019-19a). Sin latido. |
| `openSystemSettings` | — | `bool` | Ajustes de notificaciones de la app. | `UIApplication.openNotificationSettingsURLString` (iOS 16+). |
| ← `openCurrentTask` | — | — | Intent con acción y `nonce` vigente. | `userNotificationCenter(_:didReceive:)` de una notificación **propia** (identificador con el prefijo de la app) → `invokeMethod("openCurrentTask", nil)`. Sin `nonce`: iOS solo entrega a la app sus propias notificaciones. [Suposición, no existe en Android, que solo atiende `onNewIntent` (`MainActivity.kt:82-85`)] si llega antes de que Dart escuche (app abierta en frío desde la notificación), se guarda **un** aviso pendiente y se envía al primer `setForeground(true)`; en frío, abrir la app ya enseña la tarea actual, así que se puede descartar si complica. |

Errores [Hecho]: `invalid_argument` (argumentos inválidos) y `failed` (cualquier otro fallo), sin texto (`NotificationsChannel.kt:55-56,97,132`); en iOS, los mismos.

`UNUserNotificationCenter.current().delegate` se pone en `didFinishLaunching` (antes de que iOS entregue la respuesta del toque). Límite de iOS: 64 avisos pendientes; usamos ≤ 3.

## 5. `una/screen` (I3)

| Método | Argumentos | Respuesta | Android [Hecho] | iOS |
|---|---|---|---|---|
| `keepOn` | `bool` | `null` | `FLAG_KEEP_SCREEN_ON` en la ventana. | `UIApplication.shared.isIdleTimerDisabled = on` (en el principal; la respuesta va después del cambio). **[Hecho, T-028-10]** Solo un `true` exacto la enciende (un número 1 no: con el códec estándar un booleano y un número son ambos `NSNumber`, se mira el tipo), igual que `call.arguments == true`. Al pasar a segundo plano iOS lo ignora; al volver, Dart lo pide de nuevo [Hecho: lo hace al reanudar, `KeepScreenOnController`, CA-015-04d]. **[Pendiente]** que de verdad no se apague / se apague al soltarlo, en el iPad (T-028-23). |
| `rotateWithAttachment` | `bool` | `null` | Lee el acelerómetro y fija la orientación (HyperOS); con el bloqueo de rotación, vertical. Dart además llama a `SystemChrome.setPreferredOrientations`. | **[Hecho, T-028-10] `SystemChrome` basta:** `Screen.swift` responde `null` sin hacer nada. Comprobado en el simulador con un integration test temporal (no subido): tras `lockPortraitAtStart` el `supportedInterfaceOrientations` del `FlutterViewController` es vertical (2); tras pedir el giro, vertical + las dos horizontales (26); tras soltarlo, vertical (2). **[Pendiente sin iPhone]** el giro real (T-028-23). Si en el iPad no gira, el plan B: el Swift guarda las orientaciones permitidas, las devuelve en `supportedInterfaceOrientations` y llama a `setNeedsUpdateOfSupportedInterfaceOrientations()`; al pasar a `false`, `requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))`. El bloqueo de orientación de iOS ya deja la app en vertical. |

## 6. `una/links` (I3)

| Método | Argumentos | Respuesta | Android [Hecho] | iOS |
|---|---|---|---|---|
| `open` | `{kind: "web"\|"mail"\|"tel", uri}` | `bool` | Solo `http(s)` (web), `mailto` (mail) y `tel` (tel), y solo si hay app; nunca registra el enlace. | Misma validación de esquema por `kind`; `UIApplication.shared.open(url)` y responde con su *completion* (`false` si no se abrió). **[Hecho, T-028-09]** Sin tipo, con otro tipo, sin dirección o con argumentos que no son texto: `false`, sin tocar el sistema. Un `kind` o `uri` ausente no es un error (como en Kotlin). |
| `canOpen` | igual | `bool` | Mismo intent sin abrir. | `canOpenURL` tras la misma validación de esquema. **[Hecho, T-028-09]** No se declara `LSApplicationQueriesSchemes`: en el simulador `https` y `sms` dan `true` sin declarar nada y `mailto`/`tel` dan `false` **con y sin** declararlos (sin Mail ni teléfono), así que la declaración no cambia nada. **[Suposición]** en un aparato `mailto`/`tel` responden sin declarar (son esquemas del sistema); si en el iPad (T-028-23) `mailto` da `false` con Mail instalado, se declaran `mailto` y `tel` y `LinksTests.testTheQuerySchemesDeclaredInTheAppMatchTheDecision` se actualiza. En el simulador `tel:` da `false`. |

## 7. `una/a11y` (I3)

| Método | Respuesta | Android [Hecho] | iOS |
|---|---|---|---|
| `timeouts` | `{recommendedMs: int?, serviceEnabled: bool, touchExploration: bool}` | «Tiempo para actuar» (API 29+), servicio activo, exploración táctil. Fallo → `{null, false, false}`. Nada se guarda ni se registra. | `recommendedMs: nil` (iOS no tiene ese ajuste); `serviceEnabled: UIAccessibility.isVoiceOverRunning \|\| isSwitchControlRunning`; `touchExploration: isVoiceOverRunning`. Con la regla de Dart (`UndoDuration`) da 10 s con VoiceOver o Control por botón (CA-028-14, Q-028-2). |

## 8. Selector de apps (sin canal, I3)

[Hecho, Android] `RecentsPrivacy.kt`: oculta la miniatura sin bloquear capturas. **iOS:** en `SceneDelegate`, `sceneWillResignActive` añade sobre la ventana una vista a pantalla completa de color `paper` (del token, generado) y `sceneDidBecomeActive` la quita **sin animación**. No se usa `isSecureTextEntry` ni nada que bloquee capturas (CA-011-04). [Pendiente I3] comprobar que el diálogo del permiso de cámara o de notificaciones (que también vuelve la escena inactiva) no deja la vista puesta de forma visible; si molesta, se usa `sceneDidEnterBackground`.

## 9. Ganchos de depuración para los tests de integración

| Test | Gancho | iOS |
|---|---|---|
| `image_import_test`, `image_flow_test`, `photo_group_*`, `pdf_import_test` | `debugCopyFile` (copia desde `cache/fixtures/`) | `#if DEBUG`; los tests escriben los fixtures en `getTemporaryDirectory()/fixtures/` desde Dart [Hecho: `fixture_importer.dart`], que en iOS es `Caches/fixtures/`. |
| `photo_group_import_test` (recorte con el selector de documentos) | `debugPickManyDocuments` | No aplica en iOS: el test se salta con `skip:` en iOS y el tope se prueba con XCTest. |
| `web_page_controller_test`, `webview_hardening_test` | `nativeId` + `una/webview` | Funcionan con `WebKitWebViewController.webViewIdentifier` (§10). |

## 10. Cambios en Dart que pide iOS

Todos con su test y sin cambiar Android (CA-028-03):

1. `lib/app/providers.dart`: `notificationsPlatformProvider` también `true` en iOS (I6); `notificationGatewayProvider` usa en iOS el programador de Dart (I6).
2. **Programador de notificaciones en Dart** (I6): etiqueta y textos de CA-019-16 y 21 portados de `TaskLabel.kt`/`NotificationText.kt` (con sus casos de prueba JUnit pasados a Dart), cálculo de los `slots` y reprogramación al cambiar la tarea actual, el idioma, el interruptor o la cantidad, y al arrancar (después del primer fotograma, P2).
3. `lib/features/web/webview_page_driver.dart` (I5): `nativeId` también con `WebKitWebViewController.webViewIdentifier`; el error `webContentProcessTerminated` → `onProcessGone(crashed: true)`; la rama de descargas de §3.
4. `NativeImageImporter`/`NativePdfImporter` (I4): el código `cameraDenied` cuando se decida Q-028-1.
5. `settingsNotificationsPrivacy` con su versión iOS (I6, Q-028-3).
6. Los comentarios que dicen «iOS aún, D17» se actualizan donde el canal ya exista.
