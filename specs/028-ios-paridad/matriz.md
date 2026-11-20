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
| CA-002-07, CA-005-05, CA-006-03 (volver / cancelar) | Botón y gesto atrás del sistema | Gesto desde el borde → CA-028-09 | D (plataforma iOS) | I3 | |
| CA-003-01, CA-006-04/05 (mantener, arrastrar) | Gestos de Flutter | Igual; háptica de iOS si la hay | D + Disp | I8 | |
| CA-003-07, 004-10, 006-16/17 (acciones del lector) | TalkBack | VoiceOver (acciones personalizadas del rotor) | VO | I8 | |

### 007 Imagen

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-007-02 Hacer foto sin permisos | Intent de cámara, sin permiso | **Diverge → CA-028-10** (`UIImagePickerController`, permiso de cámara) | XCT + Disp | I4 | |
| CA-007-03 Subir imagen sin permisos | Selector de fotos / documentos | `PHPickerViewController`, sin permiso | XCT + IT + Disp | I4 | |
| CA-007-07 Copia propia sin datos ocultos | `ImageSanitizer.kt` (recodifica desde píxeles) | ImageIO/Core Graphics: recodificar desde píxeles, sin EXIF/GPS/XMP ni vídeo de Live Photo, orientación aplicada | XCT (casos JUnit portados) + IT (`image_import`) | I4 | |
| CA-007-11 Solo gira la tarea con imagen | `AttachmentRotation.kt` (acelerómetro) | `supportedInterfaceOrientations` + `requestGeometryUpdate` | XCT + **[Pendiente sin iPhone]** | I3 | |
| CA-007-12 Pantalla encendida | `FLAG_KEEP_SCREEN_ON` | `isIdleTimerDisabled` | XCT + Disp | I3 | |
| CA-007-13/14 Tipos, límites, importación acotada | `copy` acotado, `cache/import/` | Igual, en `Caches/import/` (mismo `getTemporaryDirectory`) | XCT + IT | I4 | |
| CA-007-15 Preparando | `sanitize` en un solo hilo | Igual, una cola serie | XCT + IT | I4 | |
| CA-007-16 Ningún archivo huérfano | `cancel` + barrido de Dart | Igual | XCT + IT | I4 | |
| CA-007-18 Copia de seguridad | Reglas de Android (adjuntos fuera de la nube) | ADR-0004 parte iOS → CA-028-18 | XCT/IT | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-007-19 Adjunto no disponible | `regenerate` | Igual | XCT + IT | I4 | |
| CA-007-18 Copia de seguridad (iOS) | — | Igual que Android: adjuntos fuera de la copia (ADR-0032) → CA-028-18 | — | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |

### 008 PDF

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-008-01 Subir PDF sin permisos | `ACTION_OPEN_DOCUMENT` | `UIDocumentPickerViewController` (`.pdf`, copia) | XCT + Disp | I4 | |
| CA-008-02/03/14 Solo PDF, límites, acotada | `copy` con `headBytes` | Igual | XCT + IT (`pdf_import`) | I4 | |
| CA-008-07 Nombre del archivo | `DISPLAY_NAME` | `URL.lastPathComponent` del documento elegido | XCT | I4 | |
| CA-008-08/09 Página y última posición | `encodeJpeg` (pdfrx dibuja en Dart) | `encodeJpeg` en Swift; pdfrx igual | XCT + IT (`pdf_flow`) | I4 | |
| CA-008-11 Girar | `AttachmentRotation.kt` | Como CA-007-11 | **[Pendiente sin iPhone]** | I3 | |
| CA-008-12 Enlaces del PDF | `LinkOpener.kt` | `UIApplication.open` → CA-028-13 | XCT + Disp | I3 | |
| CA-008-13 Pantalla encendida | Como CA-007-12 | Como CA-007-12 | XCT | I3 | |
| CA-008-15/16 Preparando, ningún huérfano | `copy`, `encodeJpeg`, `cancel` | Igual | XCT + IT (`pdf_import`) | I4 | |
| CA-008-17 Copia de seguridad | Como CA-007-18 | Igual (ADR-0032) → CA-028-18 | XCT/IT | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-008-18 Adjunto no disponible | `encodeJpeg` sobre el guardado | Igual | XCT + IT | I4 | |

### 009 Web

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-009-06/07 Tarea web, se carga cada vez | `webview_flutter_android` | `webview_flutter_wkwebview` (fijado, P11) | IT (`web_flow`) | I5 | |
| CA-009-08/09/10 Sin conexión, solo segura, certificado | Delegado del paquete | Igual (errores de WebKit → mismos tipos) | IT | I5 | |
| CA-009-11 y CL-009-1 Sin navegación; redirecciones del servidor (incluida la red local bloqueada) | `RenderGoneClient` avisa `mainFrameRequest` | Ver `channel-contract.md` §3 (sin sustituir el delegado del paquete); si no se consigue, **Diverge** con su CA en la 028 | IT + XCT | I5 | |
| CA-009-12 Atrás | Atrás del sistema | Gesto desde el borde (CA-028-09); la página no navega atrás | D | I3 | |
| CA-009-13 Aislamiento y borrado | `harden` + `clearData` | Ajustes de `WKWebView` + `WKWebsiteDataStore.removeData` → CA-028-19 | XCT + IT (`webview_hardening`) | I5 | |
| CA-009-15/16 Girar, pantalla encendida | `una/screen` | Como 007 | XCT / **[Pendiente sin iPhone]** | I3 | |
| ADR-0017 Fallo del proceso de la página | `onRenderProcessGone` | El paquete lo da como error `webContentProcessTerminated` | IT + XCT | I5 | |

### 010 Idioma

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-010-05 Nombre de la app | `values`/`values-es` desde `identity.yaml` | Nombre del paquete por idioma desde `identity.yaml` → CA-028-08 | Script | I2 | **Hecho** (T-028-02: `{en,es,ca}.lproj/InfoPlist.strings` generadas, sección `l10n`, `gen_identity_test.dart`) |
| CA-010-10 Voz del lector | TalkBack | VoiceOver | VO | I8 | |
| (CA-024-04) `ca-ES, en-US` en español | `values-ca` | Correspondencia `ca` → español en lo del sistema → CA-028-08 | Script + simulador | I2 | Script **hecho** (T-028-02); **[Pendiente]** simulador con `ca-ES, en-US` en T-028-22 |

### 011 Recientes

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-011-01/02 Sin contenido | `RecentsPrivacy.kt` | Vista `paper` al pasar a inactiva → CA-028-12 | XCT/IT + Disp | I3 | |
| CA-011-03 Vuelta sin parpadeo | — | Quitar la vista al volver, sin destello | Disp | I3 | |
| CA-011-04 Capturas permitidas | Sin `FLAG_SECURE` en primer plano | Sin bloqueo de capturas | Disp | I3 | |
| CA-011-05/06 Arranque, sin permisos | — | Igual | Disp + Script | I3 | |
| CA-011-08 Ciclo completo | Regresión de Android | Igual en iOS con CA-028-12 | IT + Disp | I3 | |
| CA-011-07 Otras plataformas | iOS «como antes» | **Diverge → CA-028-12** (iOS sí oculta) | — | I3 | |

### 013–015

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-013-01 Nombre de las bibliotecas de Android | Android | No aplica (ADR-0026 retiró la pantalla) | — | — | |
| CA-014-06 Duración de la card | `una/a11y` («Tiempo para actuar») | **Diverge → CA-028-14** | D + XCT + VO | I3 | |
| CA-014-17/18/20 Foco, lector, teclado y switch | TalkBack, Switch Access | VoiceOver, Control por botón, teclado externo | VO + Disp | I8 | |
| CA-014-13 La app muere | Proceso de Android | Igual (iOS mata la app en segundo plano) | IT | I8 | |
| CA-015-03 a 04d Pantalla siempre activa | `keepOn` | `isIdleTimerDisabled` | XCT + Disp | I3 | |
| CA-015-12a/b, 16 Abrir una web | `una/links` | `UIApplication.open` | XCT + Disp | I3 | |
| CA-015-11 Voz con el idioma elegido (ADR-0023) | TalkBack | VoiceOver | VO | I8 | |
| CA-015-18 «Recientes» | 011 | CA-028-12 | Disp | I3 | |
| CA-015-23 Arranque | Medido | CA-028-06 | Disp | I8 | |

### 016–018

| CA | Android | iOS | Verificación | Fase | Resultado |
|---|---|---|---|---|---|
| CA-016-01/02 Selector con tope de 10 | `pickMany` + `PickedItems.kt` | `PHPickerConfiguration.selectionLimit = 10` + recorte → CA-028-11 | XCT + IT (`photo_group_import`) | I4 | |
| CA-016-03/04 Importar el grupo | Canal `una/images` | Igual | IT | I4 | |
| CA-016-12/13 Giro, pantalla, recientes | `una/screen`, 011 | Como 007 y CA-028-12 | XCT / **[Pendiente sin iPhone]** | I3 | |
| CA-016-23 Memoria con 10 fotos | Medido en el Xiaomi (ADR-0024) | Medido en el iPad (2 GB) | Disp | I8 | |
| CA-016-24 Seguridad del grupo | Tope antes de abrir | Igual | XCT | I4 | |
| CA-016-14/16 Copia limpia y con orden, sin huérfanos | `sanitize`, `cancel` | Igual | XCT + IT | I4 | |
| CA-016-17 Copia de seguridad | Adjuntos fuera de la nube | Igual (ADR-0032) → CA-028-18 | — | I2 | **Hecho** (T-028-07): `DataAtRest.swift` crea `Application Support/attachments/` al arrancar el motor y la excluye de la copia (`isExcludedFromBackup`), BD en `Documents/` incluida; XCTest en el simulador (`DataAtRestTests`). **[Pendiente]** ver la exclusión en una copia real: T-028-23 |
| CA-016-18a/b Faltan fotos | `regenerate` | Igual | XCT + IT | I4 | |
| CA-017-10 Giro con el bloqueo | `una/screen` | Como 007 | **[Pendiente sin iPhone]** | I3 | |
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
| CA-021-08 Web en claro | `noDarkening` | Estilo claro en la `WKWebView` → CA-028-05/19 | IT + Disp | I5 | |
| CA-021-11 Sin nada nuevo | — | Solo lo de esta spec | Script | I2 | |
| 022 Auditoría | Xiaomi + emulador | La pasada de CA-028-21 | Disp | I8 | |
| 023 Ficha y privacidad | Play | Fuera de alcance (I9); la política no cambia salvo ADR-0030 | — | I9 | |
| CA-024-01 a 03 Iconos de las barras | Android | CA-028-05 | Disp | I2 | |
| CA-024-04 `ca` en español | `values-ca` | CA-028-08 | Script | I2 | **Hecho** (T-028-02, como CA-010-05) |
