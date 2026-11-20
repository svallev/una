# Matriz de paridad Android → iOS (spec 028)

- **Estado:** Aprobada con la spec 028 (2026-11-19). Se rellena la columna **Resultado** en cada fase y se cierra en I8 (CA-028-01).
- **Cómo se lee:** una fila por CA (o grupo de CA) de 001–024 que **depende de la plataforma**. Lo que no aparece es **Dart compartido** y se cubre con CA-028-02 (suite de Dart sin cambios + tests de integración en el simulador).
- **Verificación:** **D** = tests de Dart que ya existen · **IT** = test de integración en el simulador de iOS · **XCT** = XCTest del Swift · **Script** = `tools/check-ios-parity.sh` · **Disp** = pasada en el iPad de 6.ª gen. (I8) · **VO** = con VoiceOver en esa pasada.
- **Resultado:** vacío hasta su fase; luego **Hecho** (con la prueba), **Diverge → CA-028-NN**, **No aplica** (motivo) o **[Pendiente]** (motivo y cuándo).
- **Fase:** la del plan F-iOS (`plan-f-ios.md`) que lo hace posible.

## 1. Lo que no depende de la plataforma (CA-028-02)

| Specs | CA | Por qué es Dart compartido | Verificación | Resultado |
|---|---|---|---|---|
| 001–006 | Todos salvo CA-001-09 (arranque) y CA-001-12 (vuelta) | Dominio, estado, UI, BD drift y animaciones son Dart | D + IT (`first_run`, `complete`, `delete`, `task_list`) | |
| 010 | CA-010-01 a 12 salvo 05 y 10 | Resolución de idioma y textos en Dart (ARB) | D + IT | |
| 012 | — | Sustituida por la 015 | No aplica | |
| 013 | CA-013-03 a 06 (CA-013-02 obsoleta: su entrada la retiró el ADR-0026) | Semántica de Flutter | D + VO | |
| 014 | Todos salvo CA-014-06, 13, 17, 18 y 20 | Card, cola y deshacer en Dart | D + IT (`delete_flow`) | |
| 015 | Todos salvo los de la §2 (incluida CA-015-11) | Ajustes, persistencia y textos en Dart | D + IT (`settings_flow`) | |
| 016 | CA-016-05 a 11, 15, 19 a 22, 25 | Carrusel, grupo y BD en Dart | D + IT (`photo_group_flow`) | |
| 017 | Todos salvo CA-017-10 y 13 | Bloqueo de zoom en Dart | D | |
| 007–009 | Los de editor, listado, lectura, foco, textos y estados (no listados en la §2) | UI y dominio en Dart | D + IT | |

## 2. Lo que depende de la plataforma

### 001 Primer uso y tarea actual

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-001-09 Arranque en frío < 1 s | Medido en el emulador y el Xiaomi | Medido en el iPad 6.ª gen. (*release*/*profile*) → CA-028-06 | Disp | I8 | |
| CA-001-11 Sin conexión | Nada nativo | Igual (sin red en el Swift) | IT en modo avión del simulador + Script (sin red en el Swift) | I8 | |
| CA-001-12 Vuelta desde segundo plano | Ciclo de vida de Flutter | Igual; con la vista que tapa de CA-028-12 | IT + Disp | I3 | |

### 002–006

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-002-07, CA-005-05, CA-006-03 (volver / cancelar) | Botón y gesto atrás del sistema | Gesto desde el borde → CA-028-09 | D (plataforma iOS) | I3 | **Hecho** (T-028-12): `ios_back_gesture.dart` + `ios_back_gesture_test.dart` (el editor descarta sin preguntar con el gesto, Ajustes, Idioma y listado vuelven; la tarea actual no tiene atrás). **[Pendiente]** el escape de VoiceOver y el gesto con el dedo, en el iPad: T-028-23 |
| CA-003-01, CA-006-04/05 (mantener, arrastrar) | Gestos de Flutter | Igual; háptica de iOS si la hay | D + Disp | I8 | |
| CA-003-07, 004-10, 006-16/17 (acciones del lector) | TalkBack | VoiceOver (acciones personalizadas del rotor) | VO | I8 | |

### 007 Imagen

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-007-02 Hacer foto sin permisos | Intent de cámara, sin permiso | **Diverge → CA-028-10** (`UIImagePickerController`, permiso de cámara) | XCT + Disp | I4 || **Parcial** (T-028-13): `Images.swift` abre `UIImagePickerController` con los estados del permiso (sin cámara → `noCamera`; denegado o restringido → `cameraDenied` sin volver a preguntar; sin decidir → diálogo) y escribe la foto sin metadatos más que la orientación; XCTest (`ImagesTests`). [Hecho, T-028-15] el aviso en Dart: `cameraDenied` → `errCameraDenied` con «Abrir Ajustes» (`openAppSettings`), región viva, foco al aviso (un solo nodo; decidido por el propietario el 2026-11-20, no a (+)), ≥ 44 y 200 %, y se cierra al salir del editor (`camera_denied_notice_test`). **[Pendiente]** conceder/denegar con la cámara real y VoiceOver, en el iPad (T-028-23) |
| CA-007-03 Subir imagen sin permisos | Selector de fotos / documentos | `PHPickerViewController`, sin permiso | XCT + IT + Disp | I4 || **Parcial** (T-028-13): `PHPickerViewController` (`.images`, sin permiso) con token opaco `picker:` y copia con `loadFileRepresentation`; XCTest. IT `image_import` en el simulador (T-028-15): 7 de 13 en verde; los 6 rojos son de la limpieza nativa (`ImageSanitizer.swift`): cada JPEG lleva un bloque APP1 «Exif» que escribe ImageIO (también desde un PNG sin EXIF) y la bomba de 64 MP se guarda en 24 000 192 px (> 24 MP). **[Pendiente]** su arreglo (pregunta al coordinador); el selector real en el iPad (T-028-23) |
| CA-007-07 Copia propia sin datos ocultos | `ImageSanitizer.kt` (recodifica desde píxeles) | ImageIO/Core Graphics: recodificar desde píxeles, sin EXIF/GPS/XMP ni vídeo de Live Photo, orientación aplicada | XCT (casos JUnit portados) + IT (`image_import`) | I4 | **Parcial** (T-028-14): `ImageSanitizer.swift` recodifica desde los píxeles (lienzo sRGB opaco, JPEG con la calidad como única propiedad): sin EXIF/GPS/fabricante en ningún byte, las 8 orientaciones aplicadas, HEIC leído, alfa sobre blanco; XCTest (`SanitizerTests`) con imágenes generadas. Diferencia: una imagen **cortada** no se detecta (ImageIO la da por completa). IT `image_import` en el simulador (T-028-15): 7 de 13 en verde; los 6 rojos son de la limpieza nativa (`ImageSanitizer.swift`): cada JPEG lleva un bloque APP1 «Exif» que escribe ImageIO (también desde un PNG sin EXIF) y la bomba de 64 MP se guarda en 24 000 192 px (> 24 MP). **[Pendiente]** su arreglo (pregunta al coordinador); Live Photo y HEIC reales en el iPad (T-028-23) |
| CA-007-11 Solo gira la tarea con imagen | `AttachmentRotation.kt` (acelerómetro) | `supportedInterfaceOrientations` + `requestGeometryUpdate` | XCT + **[Pendiente sin iPhone]** | I3 | **Hecho en lo comprobable** (T-028-10): igual que CA-008-11 (`SystemChrome` abre y cierra las horizontales; sin `requestGeometryUpdate` nativo, el motor lo hace). **[Pendiente sin iPhone]** el giro real: T-028-23 |
| CA-007-12 Pantalla encendida | `FLAG_KEEP_SCREEN_ON` | `isIdleTimerDisabled` | XCT + Disp | I3 | **Hecho** (T-028-10): `Screen.swift` `keepOn` = `isIdleTimerDisabled` (solo un `true` exacto la enciende; en el principal), 9 XCTest (`ScreenTests`) y 4 tests de Dart del canal. **[Pendiente]** que se apague de verdad al bloquear/volver, en el iPad: T-028-23 (el simulador no lo enseña) |
| CA-007-13/14 Tipos, límites, importación acotada | `copy` acotado, `cache/import/` | Igual, en `Caches/import/` (mismo `getTemporaryDirectory`) | XCT + IT | I4 || **Parcial** (T-028-13): copia por bloques de 64 KB a `Caches/import/<id>/source` con `tooLarge`, 0 bytes → `unreadable`, `noSpace` (simulado) y tokens ajenos rechazados; XCTest. IT `image_import` (T-028-15): tipos por el contenido, malformados, tamaño contado al copiar y rutas con `../` en verde; **rojo** la bomba de 64 MP (se acepta, pero se guarda en 24 000 192 px > 24 MP, `ImageSanitizer.swift`). **[Pendiente]** ese arreglo |
| CA-007-15 Preparando | `sanitize` en un solo hilo | Igual, una cola serie | XCT + IT | I4 | **Hecho** (T-028-14): `sanitize` en una cola serie propia (nunca dos a la vez) y cancelada mientras espera turno → `cancelled` sin hacer nada; XCTest. Con IT (T-028-15): `image_import` «cancelar borra la preparación» y `photo_group_import` (cancelar a mitad, tiempo agotado) en el simulador |
| CA-007-16 Ningún archivo huérfano | `cancel` + barrido de Dart | Igual | XCT + IT | I4 || **Hecho** (T-028-13): `cancel` corta la copia (y la carga de la foto) y borra `import/<id>/` e `import/<id>.camera`; un fallo no deja nada; XCTest. Con IT (T-028-15): `image_import` (malformados y cancelar sin restos), `photo_group_import` y `image_flow` (sin temporales tras guardar) en el simulador |
| CA-007-18 Copia de seguridad | Reglas de Android (adjuntos fuera de la nube) | ADR-0004 parte iOS → CA-028-18 | XCT/IT | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-007-19 Adjunto no disponible | `regenerate` | Igual | XCT + IT | I4 | **Hecho** (T-028-14): `regenerate` rehace `screen.jpg` y `thumb.jpg` desde las teselas (cada una decodificada ya reducida), sin tocarlas; sin carpeta o sin tesela → `unreadable`; XCTest. IT `image_flow` (T-028-15): restaurada sin archivos → «Adjunto no disponible» y eliminar, en verde; ningún IT llama a `regenerate` (queda el XCTest) |
| CA-007-18 Copia de seguridad (iOS) | — | Igual que Android: adjuntos fuera de la copia (ADR-0032) → CA-028-18 | — | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |

### 008 PDF

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-008-01 Subir PDF sin permisos | `ACTION_OPEN_DOCUMENT` | `UIDocumentPickerViewController` (`.pdf`, copia) | XCT + Disp | I4 || **Parcial** (T-028-13): `UIDocumentPickerViewController([.pdf], asCopy: true)`, token `document:` y la copia del selector borrada tras copiar; XCTest. **[Pendiente]** el selector real en el iPad (T-028-23) |
| CA-008-02/03/14 Solo PDF, límites, acotada | `copy` con `headBytes` | Igual | XCT + IT (`pdf_import`) | I4 || **Hecho** (T-028-13): `copy` con `headBytes` (1…1024) y los mismos límites; XCTest. Con IT `pdf_import` y `pdf_flow` en el simulador (T-028-15) |
| CA-008-07 Nombre del archivo | `DISPLAY_NAME` | `URL.lastPathComponent` del documento elegido | XCT | I4 || **Hecho** (T-028-13): `name` = `lastPathComponent` de la copia elegida (≤ 1024; Dart lo recorta a 120); XCTest |
| CA-008-08/09 Página y última posición | `encodeJpeg` (pdfrx dibuja en Dart) | `encodeJpeg` en Swift; pdfrx igual | XCT + IT (`pdf_flow`) | I4 | **Hecho** (T-028-14): `encodeJpeg` (BGRA/RGBA sin copiar, calidad 0,85, escritura atómica, en la preparación o en lo guardado; sin carpeta → nada); XCTest. Con IT `pdf_flow` en el simulador (posición guardada, arranque en frío en ella, T-028-15) |
| CA-008-11 Girar | `AttachmentRotation.kt` | Como CA-007-11 | **[Pendiente sin iPhone]** | I3 | **Hecho en lo comprobable** (T-028-10): `rotateWithAttachment` responde sin hacer nada; `SystemChrome` basta: en el simulador, tras `request(on: true)` el `FlutterViewController` permite vertical + las dos horizontales (máscara 26) y tras soltar, solo vertical (2); test de Dart del par abrir/soltar. **[Pendiente sin iPhone]** el giro real con el aparato girado y con el bloqueo de rotación (el simulador no gira por línea de comandos): T-028-23 |
| CA-008-12 Enlaces del PDF | `LinkOpener.kt` | `UIApplication.open` → CA-028-13 | XCT + Disp | I3 | **Hecho** (T-028-09): `Links.swift` abre `web` (`http(s)`), `mail` (`mailto`) y `tel` solo con su esquema; `open` responde con el resultado del sistema y `canOpen` con `canOpenURL`; 13 XCTest (`LinksTests`) y la llamada real desde Dart en el simulador (`https` → `true`). **[Pendiente]** `mailto:`/`tel:` con una app real y el aviso «No hay ninguna app»: T-028-23 (el simulador no tiene Mail ni teléfono: `false` con y sin `LSApplicationQueriesSchemes`) |
| CA-008-13 Pantalla encendida | Como CA-007-12 | Como CA-007-12 | XCT | I3 | Como CA-007-12 (mismo canal) |
| CA-008-15/16 Preparando, ningún huérfano | `copy`, `encodeJpeg`, `cancel` | Igual | XCT + IT (`pdf_import`) | I4 || **Hecho** (T-028-13): `copy` y `cancel` como CA-007-16; `encodeJpeg` en T-028-14 (como CA-008-08, una carpeta cancelada → nada). Con IT `pdf_import` («los errores no dejan nada») y `pdf_flow` en el simulador (T-028-15) |
| CA-008-17 Copia de seguridad | Como CA-007-18 | Igual (ADR-0032) → CA-028-18 | XCT/IT | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-008-18 Adjunto no disponible | `encodeJpeg` sobre el guardado | Igual | XCT + IT | I4 | **Parcial** (T-028-14): `encodeJpeg` sobre el guardado, como CA-008-08; XCTest. IT `pdf_flow` en verde (T-028-15); ningún IT borra el PDF guardado para regenerar (queda el XCTest) |

### 009 Web

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-009-06/07 Tarea web, se carga cada vez | `webview_flutter_android` | `webview_flutter_wkwebview` (fijado, P11) | IT (`web_flow`) | I5 | |
| CA-009-08/09/10 Sin conexión, solo segura, certificado | Delegado del paquete | Igual (errores de WebKit → mismos tipos) | IT | I5 | |
| CA-009-11 y CL-009-1 Sin navegación; redirecciones del servidor (incluida la red local bloqueada) | `RenderGoneClient` avisa `mainFrameRequest` | Ver `channel-contract.md` §3 (sin sustituir el delegado del paquete); si no se consigue, **Diverge** con su CA en la 028 | IT + XCT | I5 | |
| CA-009-12 Atrás | Atrás del sistema | Gesto desde el borde (CA-028-09); la página no navega atrás | D | I3 | **Hecho** (T-028-12): el gesto es de la ruta de la pantalla (`UnaPageRoute`), no de la página, que no navega atrás; la web en el simulador, en T-028-16 |
| CA-009-13 Aislamiento y borrado | `harden` + `clearData` | Ajustes de `WKWebView` + `WKWebsiteDataStore.removeData` → CA-028-19 | XCT + IT (`webview_hardening`) | I5 || **Hecho** (T-028-16): `WebViewHardening.swift` (`harden`/`state` leídos de la vista, `clearData` con `WKWebsiteDataStore`); 14 XCTest (`WebViewHardeningTests`) e IT `webview_hardening` 5/5 + la descarga saltada hasta T-028-17; contenido mixto: una página `https` no pide nada por `http` a la red (IT nuevo) |
| CA-009-15/16 Girar, pantalla encendida | `una/screen` | Como 007 | XCT / **[Pendiente sin iPhone]** | I3 | Como CA-007-12 y CA-008-11 (mismo canal) |
| ADR-0017 Fallo del proceso de la página | `onRenderProcessGone` | El paquete lo da como error `webContentProcessTerminated` | IT + XCT | I5 || **Hecho** (T-028-16): `webContentProcessTerminated` → `onProcessGone(crashed: true)` (test de Dart); IT `webview_hardening` mata el proceso con `debugKillContentProcess` (solo Debug), la app sigue y otra WebView carga. El mismo caso de `web_page_controller`, **[Pendiente]** por la carga inicial en iOS (ver `tasks.md`, T-028-16) |

### 010 Idioma

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-010-05 Nombre de la app | `values`/`values-es` desde `identity.yaml` | Nombre del paquete por idioma desde `identity.yaml` → CA-028-08 | Script | I2 | **Hecho** (T-028-02: `{en,es,ca}.lproj/InfoPlist.strings` generadas, sección `l10n`, `gen_identity_test.dart`) |
| CA-010-10 Voz del lector | TalkBack | VoiceOver | VO | I8 | |
| (CA-024-04) `ca-ES, en-US` en español | `values-ca` | Correspondencia `ca` → español en lo del sistema → CA-028-08 | Script + simulador | I2 | Script **hecho** (T-028-02); **[Pendiente]** simulador con `ca-ES, en-US` en T-028-22 |

### 011 Recientes

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-011-01/02 Sin contenido | `RecentsPrivacy.kt` | Vista `paper` al pasar a inactiva → CA-028-12 | XCT/IT + Disp | I3 | **Hecho** (T-028-11): `RecentsPrivacy.swift` + `SceneDelegate.swift`; 12 XCTest (`RecentsPrivacyTests`), incluida la escena real (la ventana de Flutter dibujada con la vista puesta es solo `paper`). **[Pendiente]** la miniatura del selector real, en el iPad: T-028-23 |
| CA-011-03 Vuelta sin parpadeo | — | Quitar la vista al volver, sin destello | Disp | I3 | **Parcial** (T-028-11): se quita en el acto y sin animación (XCTest, también dentro de un bloque animado); el destello a ojo, en el iPad: T-028-23 |
| CA-011-04 Capturas permitidas | Sin `FLAG_SECURE` en primer plano | Sin bloqueo de capturas | Disp | I3 | **Parcial** (T-028-11): XCTest que lee el Swift (sin `isSecureTextEntry`, `isCaptured` ni escuchar capturas) y la vista solo existe con la escena inactiva; una captura real, en el iPad: T-028-23 |
| CA-011-05/06 Arranque, sin permisos | — | Igual | Disp + Script | I3 | **Hecho** (T-028-11): la vista no pide permiso ni entitlement ni toca `Info.plist`; el arranque no cambia (la vista solo se pone al pasar a inactiva); `check-ios-parity.sh` verde |
| CA-011-08 Ciclo completo | Regresión de Android | Igual en iOS con CA-028-12 | IT + Disp | I3 | **Parcial** (T-028-11): ciclo inactiva/activa repetido en XCTest; el ciclo con la app entera, en el iPad: T-028-23 |
| CA-011-07 Otras plataformas | iOS «como antes» | **Diverge → CA-028-12** (iOS sí oculta) | — | I3 | **Hecho** (T-028-11) |

### 013–015

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-013-01 Nombre de las bibliotecas de Android | Android | No aplica (ADR-0026 retiró la pantalla) | — | — | |
| CA-014-06 Duración de la card | `una/a11y` («Tiempo para actuar») | **Diverge → CA-028-14** | D + XCT + VO | I3 | **Hecho** (T-028-09): `A11y.swift` da `recommendedMs: null`, servicio = VoiceOver o Control por botón y lector = VoiceOver; Dart sin cambios de lógica (`UndoDuration`: 10 s con servicio, 4 s sin él), 6 tests de Dart nuevos y 9 XCTest (`A11yTests`). **[Pendiente]** con VoiceOver real: T-028-23 |
| CA-014-17/18/20 Foco, lector, teclado y switch | TalkBack, Switch Access | VoiceOver, Control por botón, teclado externo | VO + Disp | I8 | |
| CA-014-13 La app muere | Proceso de Android | Igual (iOS mata la app en segundo plano) | IT | I8 | |
| CA-015-03 a 04d Pantalla siempre activa | `keepOn` | `isIdleTimerDisabled` | XCT + Disp | I3 | **Hecho** (T-028-10): `Screen.swift` `keepOn` = `isIdleTimerDisabled` (solo un `true` exacto la enciende; en el principal), 9 XCTest (`ScreenTests`) y 4 tests de Dart del canal. **[Pendiente]** que se apague de verdad al bloquear/volver, en el iPad: T-028-23 (el simulador no lo enseña) |
| CA-015-12a/b, 16 Abrir una web | `una/links` | `UIApplication.open` | XCT + Disp | I3 | **Hecho** (T-028-09): igual que CA-008-12 (mismo canal y mismo `Links.swift`); en el iPad (política, licencias y ayuda abiertas en Safari): T-028-23 |
| CA-015-11 Voz con el idioma elegido (ADR-0023) | TalkBack | VoiceOver | VO | I8 | |
| CA-015-18 «Recientes» | 011 | CA-028-12 | Disp | I3 | **Parcial** (T-028-11): como CA-011-01/02; la miniatura real, en el iPad: T-028-23 |
| CA-015-23 Arranque | Medido | CA-028-06 | Disp | I8 | |

### 016–018

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-016-01/02 Selector con tope de 10 | `pickMany` + `PickedItems.kt` | `PHPickerConfiguration.selectionLimit = 10` + recorte → CA-028-11 | XCT + IT (`photo_group_import`) | I4 || **Parcial** (T-028-13): `selectionLimit` = `max` acotado a 1…10, `.ordered`, recorte con `PickedItems` (orden y `total`); XCTest. IT `photo_group_import` en verde en el simulador (T-028-15; el caso del selector de documentos se salta en iOS con su motivo, CA-028-02). **[Pendiente]** el selector real en el iPad |
| CA-016-03/04 Importar el grupo | Canal `una/images` | Igual | IT | I4 | **Hecho** (T-028-15): IT `photo_group_import` (tres fotos una a una y en su orden, fallos y tiempo agotado) y `photo_group_flow` (grupo de 3 → carrusel → reinicio con el mismo orden) en verde en el simulador |
| CA-016-12/13 Giro, pantalla, recientes | `una/screen`, 011 | Como 007 y CA-028-12 | XCT / **[Pendiente sin iPhone]** | I3 | **Parcial** (T-028-10): giro y pantalla como CA-007-12 y CA-008-11; los recientes, **hechos** en T-028-11 (CA-028-12; la miniatura real, en el iPad: T-028-23) |
| CA-016-23 Memoria con 10 fotos | Medido en el Xiaomi (ADR-0024) | Medido en el iPad (2 GB) | Disp | I8 | |
| CA-016-24 Seguridad del grupo | Tope antes de abrir | Igual | XCT | I4 || **Hecho** (T-028-13): `PickedItems.swift` con los 7 casos de `PickedItemsTest.kt` y el contador de accesos también a través del canal (5000 devueltas → solo se miran 10); XCTest |
| CA-016-14/16 Copia limpia y con orden, sin huérfanos | `sanitize`, `cancel` | Igual | XCT + IT | I4 | **Parcial** (T-028-14): `sanitize` como CA-007-07 y CA-007-15; un fallo, `noSpace` o una cancelación no dejan nada; XCTest. IT `photo_group_import` y `photo_group_flow` en verde (T-028-15); el bloque APP1 «Exif» de CA-007-07 también sale aquí (esos IT no lo miran). **[Pendiente]** ese arreglo |
| CA-016-17 Copia de seguridad | Adjuntos fuera de la nube | Igual (ADR-0032) → CA-028-18 | — | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-016-18a/b Faltan fotos | `regenerate` | Igual | XCT + IT | I4 | **Parcial** (T-028-14): `regenerate` como CA-007-19; XCTest. Ningún IT llama a `regenerate` (queda el XCTest; T-028-15) |
| CA-017-10 Giro con el bloqueo | `una/screen` | Como 007 | **[Pendiente sin iPhone]** | I3 | Como CA-008-11: en iOS el bloqueo de orientación del sistema ya deja la app en vertical. **[Pendiente sin iPhone]** T-028-23 |
| CA-017-13 Lupa del sistema | Ampliación de Android | Zoom de accesibilidad de iOS | Disp | I8 | |
| CA-018-01 a 08, 14, 15 Icono | Adaptable + Play | Icono de iOS desde el de 1024 → CA-028-07 | Script | I2 | **Hecho** (T-028-04): `gen_icons.dart ios` + sección `icon`; en el simulador el icono sale en la pantalla de inicio; máscara y tamaños en el iPad: T-028-23 |
| CA-018-06 Nada de Flutter | Android | Ahora también iOS → CA-028-07 | Script | I2 | **Hecho** (T-028-04): sección `icon` (ningún PNG igual a la plantilla, sin alfa) y `LaunchImage.imageset` retirado |

### 019 Notificaciones (ADR-0030)

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-019-01 a 06 Fila, interruptor, opciones, persistencia | Dart | Igual | D | I6 | |
| CA-019-07/08/08b/09 Permiso | `POST_NOTIFICATIONS` | `UNUserNotificationCenter.requestAuthorization` | XCT + Disp | I6 | |
| CA-019-10/12 Horas y cambios al momento | Kotlin programa | Dart programa por adelantado | D + XCT | I6 | |
| CA-019-11 Ventana inexacta | Alarmas inexactas | **Diverge → CA-028-16** (hora exacta) | Disp | I6 | |
| CA-019-13 Siguen solos | Receptores de arranque y reloj | **Diverge → CA-028-16** (los conserva iOS) | Disp | I6 | |
| CA-019-14 Las perdidas | «Última hora atendida» | **Diverge → CA-028-16** (no aplica) | — | I6 | |
| CA-019-15 Sin tareas, nada | Lee la BD al llegar | Cancelar todo al quedarse sin tareas | D | I6 | |
| CA-019-16 La tarea al llegar y su etiqueta | `TaskLabel.kt` al llegar | **Diverge → CA-028-16** (Dart al reprogramar) | D | I6 | |
| CA-019-17 Bloqueado | Versión pública | **Diverge → CA-028-16** (previsualizaciones de iOS) | Disp | I6 | |
| CA-019-18 Una a la vez | Identificador fijo | CA-028-16 (dos resultados posibles, Q-028-5) | Disp | I6 | |
| CA-019-19a A la vista | `ForegroundTracker` | `willPresent` sin presentación | XCT + Disp | I6 | |
| CA-019-19b Al abrir se quita | `cancelDelivered` | `removeAllDeliveredNotifications` | XCT | I6 | |
| CA-019-20 Tocar | Intent con `nonce` | `didReceive` → `openCurrentTask` | XCT + Disp | I6 | |
| CA-019-21 Idioma y voz | Recursos + `LocaleSpan` | Texto de Dart en el idioma de la app; voz de VoiceOver | D + VO | I6 | |
| CA-019-22 Canal | Un canal | **Diverge → CA-028-16** (sin canal) | — | I6 | |
| CA-019-23 Sin copias del texto | Ninguna | **Diverge → CA-028-16** (excepción, ADR-0030) | D + XCT | I6 | |
| CA-019-24/25 Arranque, sin red | — | Igual | Disp + Script | I6 | |
| CA-019-28 Plataformas | Sin fila en iOS | **Diverge → CA-028-15** (fila en iOS) | D | I6 | |
| CA-019-29 Línea de privacidad | Texto Android | **Diverge → CA-028-16** (texto iOS) | D | I6 | |
| CA-019-30 Antes del primer desbloqueo | Versión genérica | **No aplica** (CA-028-16) | — | I6 | |

### 020–024 (proceso y Android)

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-020-01 a 08 Trabajo de publicación | `release.yml` (APK/AAB) | Fuera de alcance (I9) | — | I9 | |
| CA-020-22 a 26 MASTG, hallazgos, documentación | Pasada MASTG de Android | No aplica (el Swift lo revisa `security-reviewer` en I8; MASTG de iOS, en I9) | — | I9 | |
| CA-020-09 a 21, 27, 28 | Código de Android y Dart | Lo de Dart vale igual; el Swift lo revisa `security-reviewer` | D + I8 | I8 | |
| CA-021-01 a 05, 09, 10, 12 Arranque y barras | Temas de Android | CA-028-05 y 06 | Script + Disp | I2 | Script **Hecho** (T-028-03 y 04: secciones `plist`, `project` y `launch`; `LaunchBackground` = `paper`, sin oscuro ni imagen; visto en el simulador sin destello); **[Pendiente]** Disp en el iPad (T-028-23) |
| CA-021-06/07 Igual en oscuro | Tema fijo | `UIUserInterfaceStyle = Light` → CA-028-05 | IT + Disp | I2 | |
| CA-021-08 Web en claro | `noDarkening` | Estilo claro en la `WKWebView` → CA-028-05/19 | IT + Disp | I5 || **Hecho** (T-028-16) en el simulador en oscuro: la página ve `prefers-color-scheme: light` (IT `webview_hardening`, `overrideUserInterfaceStyle = .light` leído de vuelta en XCTest); **[Pendiente]** Disp en el iPad (T-028-23) |
| CA-021-11 Sin nada nuevo | — | Solo lo de esta spec | Script | I2 | |
| 022 Auditoría | Xiaomi + emulador | La pasada de CA-028-21 | Disp | I8 | |
| 023 Ficha y privacidad | Play | Fuera de alcance (I9); la política no cambia salvo ADR-0030 | — | I9 | |
| CA-024-01 a 03 Iconos de las barras | Android | CA-028-05 | Disp | I2 | |
| CA-024-04 `ca` en español | `values-ca` | CA-028-08 | Script | I2 | **Hecho** (T-028-02, como CA-010-05) |
