# Plan F-iOS: Una en iOS, igual que en Android

## Contexto

Una está terminada en Android (specs 001–024, F5 cerrada). La decisión PD-7/D17 dejó iOS para el final. El propietario quiere la **misma funcionalidad y el mismo estilo** en iOS, sin reabrir funcionalidades, con el menor gasto de tiempo y tokens. El orden de Android (una spec por funcionalidad, con descubrimiento, spikes y auditoría) fue necesario porque el producto se estaba definiendo; ahora el comportamiento está fijado por 24 specs, ~4.500 tests de Dart y el Kotlin, que sirve de **implementación de referencia**. Por eso el orden cambia: **por capa técnica y por riesgo, no por funcionalidad**.

## Lo que hay hoy [Hecho]

- Todo el producto (dominio, estado, UI, BD drift, l10n, tokens, fuentes empaquetadas) es Dart compartido. `app/ios/` existe (iOS 16, `invalid.pending.app`, `AppDelegate` con `FlutterImplicitEngineDelegate`) y **el trabajo «iOS · build sin firmar» de la CI está en verde en `main`**.
- Lo que falta en iOS es el **código nativo**: 8 canales en Kotlin (~3.900 líneas, la mitad son notificaciones):
  | Canal | Métodos | Spec | Peso iOS |
  |---|---|---|---|
  | `una/images` | capabilities, pick (cámara/galería/PDF), pickMany, copy, sanitize, encodeJpeg, regenerate, cancel, freeSpace, debug* | 007, 008, 016 | Alto |
  | `una/webview` | harden, state, destroy, clearData + avisos mainFrameRequest, renderProcessGone, downloadBlocked | 009 | Alto |
  | `una/notifications` | canNotify, requestPermission, configure, cancelDelivered, setForeground, openSystemSettings | 019 | Medio (según decisión) |
  | `una/screen` | keepOn, rotateWithAttachment | 007, 008 | Bajo |
  | `una/links` | open, canOpen (web, mail, tel) | 008 | Bajo |
  | `una/a11y` | timeouts | 014 | Trivial (iOS no tiene equivalente → valor por defecto) |
  | Recientes (sin canal) | ocultar la miniatura del selector de apps | 011 | Bajo |
- `notificationsPlatformProvider` solo enciende notificaciones en Android (`app/lib/app/providers.dart:151`).
- Los tests de integración (`app/integration_test/`, 19) usan ganchos de depuración nativos (`debugPickManyDocuments`, `debugCopyFile`): hacen falta sus equivalentes en Swift.
- Sin Xcode (solo Command Line Tools); **82 GB libres**. Repo **público** → los ejecutores macOS de GitHub Actions son gratis.

## Estrategia: qué cambia respecto a Android

1. **Una sola spec paraguas, `028-ios-paridad`**, en lugar de repetir 24 specs. Sus CA son por referencia: *«cada CA de 001–024 marcado como dependiente de plataforma se cumple en iOS»*, con una **matriz de paridad** (CA → mecanismo Android → mecanismo iOS → cómo se verifica). Solo hay CA nuevos donde iOS obliga a divergir (notificaciones, selector de apps, gesto atrás, textos de permisos, manifiesto de privacidad, icono y arranque).
2. **Contrato de canales** (`docs/ios/channel-contract.md`): una ficha por canal sacada del Kotlin y de Dart (métodos, argumentos, respuestas, errores, límites, hilos). Cada tarea lee **solo su ficha y su archivo Kotlin**, no el historial de specs: es el mayor ahorro de tokens.
3. **Traducir, no rediseñar.** El Kotlin es la referencia; los casos de sus tests JUnit se portan a XCTest. Donde la lógica pura pueda vivir en Dart (p. ej. la etiqueta de la notificación si se programa desde Dart), se mueve a Dart en vez de duplicarla en Swift.
4. **Orden por riesgo:** primero la base (que ya hace funcionar 001–006, 010, 014, 015, 017 y 021 sin nativo), luego canales simples, y los tres grandes (imágenes/PDF, WebView, notificaciones) con el modelo más capaz.
5. **Verificación en dos tiempos:** automática en simulador en cada tarea; dispositivo + VoiceOver **una sola vez** al final (como la 022), no casilla a casilla.
6. **Scripts antes que agentes** para lo mecánico: `tools/check-ios-parity.sh` (cada método Kotlin tiene su `case` en Swift; claves de Info.plist; manifiesto de privacidad; idiomas) corre en la CI sin gastar tokens.
7. **Modelo por tarea:** `spec-task` con Sonnet en las tareas mecánicas (base, canales simples, CI); Opus en imágenes/PDF, WebView y notificaciones.
8. **Herramientas Claude:** ningún agente nuevo. Una skill nueva, **`/ios-check`** (receta fija: `flutter build ios --simulator`, `xcodebuild test`, `flutter test integration_test -d <simulador>`, `check-ios-parity.sh`), para no re-derivar comandos en cada sesión. Ajustar `spec-task` y `docs/testing.md` con los comandos de iOS.

## Fases y tareas

| Fase | Qué | Quién / modelo | Sesión |
|---|---|---|---|
| **I0 Preparación** | Instalar Xcode (App Store) + runtime de iOS (`docs/environments.md` §1 pasos 2–3); `flutter doctor`; firma gratuita con un bundle ID de desarrollo en el iPhone | Propietario (~1 h) | — |
| **I1 Spec 028 + matriz + contrato** | Spec paraguas, matriz de paridad, `channel-contract.md`, ADR de notificaciones iOS (y de convenciones de plataforma si aplica). Revisión con `spec-reviewer` | Opus | 1 |
| **I2 Base de plataforma** | `Info.plist` (modo claro fijo `UIUserInterfaceStyle=Light`, `CFBundleLocalizations` es/en, `NSCameraUsageDescription` + `InfoPlist.strings` ES/EN, orientaciones, iPhone solo si se decide); LaunchScreen en `paper`; icono desde `design/prototype/assets/icon/icon-1024.png`; `PrivacyInfo.xcprivacy`; Data Protection (ADR-0005) y exclusión de copia de `Caches` (ADR-0004); fijar `webview_flutter_wkwebview` (P11); licencias de iOS en `assets/licenses/`; esqueleto `UnaChannels.swift` registrado desde `didInitializeImplicitFlutterEngine`; destino XCTest operativo | Sonnet | 2 |
| **I3 Canales simples** | `una/links` (`UIApplication.open`), `una/a11y` (por defecto), `una/screen` (`isIdleTimerDisabled`; giro con `supportedInterfaceOrientations` + `requestGeometryUpdate`), selector de apps (vista `paper` encima al pasar a inactiva) | Sonnet | 2 |
| **I4 Imágenes y PDF** | `una/images` completo: cámara (`UIImagePickerController`), galería (`PHPickerViewController`, sin permiso, tope de 10), PDF (`UIDocumentPickerViewController`), copia acotada a `cache/import/`, limpieza con ImageIO (metadatos fuera, orientación, HEIC→JPEG), `encodeJpeg`, `regenerate`, `cancel`, `freeSpace`; ganchos de depuración para los tests de integración. 2 tareas | Opus | 3 |
| **I5 WebView** | `una/webview` sobre `WKWebView` (API externa de `webview_flutter_wkwebview`): almacén de datos no persistente, bloqueo de navegación del marco principal (ADR-0018), `webContentProcessDidTerminate` → renderProcessGone (ADR-0017), descargas bloqueadas, `clearData` | Opus | 3 |
| **I6 Notificaciones** | Opción A: programador en Dart (etiqueta y texto ES/EN) + `una/notifications` en Swift con `UNUserNotificationCenter`; reprogramar al cambiar la tarea actual, el idioma o el ajuste; activar `notificationsPlatformProvider` en iOS | Opus | 4 |
| **I7 CI** | Ampliar el trabajo `ios`: `xcodebuild test`, `check-ios-parity.sh`, tests de integración en simulador (gratis, repo público) | Sonnet | 4 |
| **I8 Auditoría y cierre** | Los 19 tests de integración en simulador; arranque en frío; pasada en el iPhone con la matriz; VoiceOver (`a11y-reviewer` + lista manual); `security-reviewer` sobre el Swift; `/security-check`; actualizar `docs/PLAN.md`, `CLAUDE.md`, ADR-0025 (iOS), landing «Muy pronto en App Store» si cambia | Opus coordinador | 5 |
| **I9 (opcional) Tienda** | Cuenta de Apple Developer, bundle ID definitivo (PD-2), App Store Connect, etiquetas de privacidad, capturas, TestFlight, modo iOS en `release.yml` | — | 6 |

**Total estimado: 5 sesiones (+1 si tienda)**, frente a las ~24 specs × 3–4 sesiones del camino de Android.

## Archivos clave

- Nuevos: `specs/028-ios-paridad/{spec,plan,tasks}.md`, `docs/ios/channel-contract.md`, `docs/adr/0030-notificaciones-en-ios.md`, `app/ios/Runner/*.swift` (un archivo por canal, espejo de los `.kt`), `app/ios/Runner/PrivacyInfo.xcprivacy`, `app/ios/Runner/{es,en}.lproj/InfoPlist.strings`, `app/ios/RunnerTests/*Tests.swift`, `tools/check-ios-parity.sh`, `.claude/skills/ios-check/SKILL.md`.
- Modificados: `app/ios/Runner/{AppDelegate.swift,Info.plist}`, `app/ios/Runner/Assets.xcassets`, `app/ios/Runner/Base.lproj/LaunchScreen.storyboard`, `app/pubspec.yaml` (fijar wkwebview), `app/lib/app/providers.dart:151`, `.github/workflows/ci.yml` (trabajo `ios`), `docs/testing.md`, `docs/environments.md`, `.claude/agents/spec-task.md`.
- Referencia (no se tocan): `app/android/app/src/main/kotlin/invalid/pending/app/**`, `app/lib/data/{platform,import,web,links}/*.dart` (lado Dart de cada canal).

## Verificación

- Por tarea: `/ios-check` en verde (build de simulador, XCTest, tests de integración del canal, script de paridad) + `flutter analyze --fatal-infos` y `flutter test` sin cambios.
- Al cierre: matriz de paridad con todas las filas verificadas en simulador y las de dispositivo en el iPhone; VoiceOver en los flujos principales; CI verde con el trabajo `ios` ampliado.

## Decisiones del propietario (2026-11-19)

1. **Alcance:** simulador + iPhone propio con firma gratuita (caduca a los 7 días). I9 (tienda) queda opcional y fuera de este plan.
2. **Dispositivos (2026-11-19):** sin iPhone. La app «solo iPhone» se prueba en iPad en modo compatibilidad, con la firma gratuita:
   - **iPad de 6.ª generación (iPadOS 17.7.1, A10, 2 GB): único dispositivo físico** (propietario, 2026-11-19). Cámara, VoiceOver, notificaciones, WebView, flujos, y rendimiento y memoria de un aparato modesto (arranque en frío, grupo de 10 fotos, ADR-0024).
   - **El simulador con el último iOS** cubre el sistema más reciente. El iPad Pro M4 (último iPadOS) solo se usa si algo falla en el simulador y hay que confirmarlo en un aparato real.
   - **[Pendiente] sin iPhone:** el giro con el adjunto (CA-008-11, en compatibilidad no es igual), el tacto en pantalla pequeña y la pantalla de bloqueo de un iPhone. Antes de cualquier publicación habrá que hacer una pasada en un iPhone.
3. **Xcode en local:** sí (I0, lo instala el propietario).
4. **Notificaciones: opción A.** Texto programado por adelantado con `UNCalendarNotificationTrigger` (08:55, 13:55, 18:55), reprogramado desde Dart cada vez que cambia la tarea actual o el idioma, y al arrancar la app. La etiqueta se calcula en Dart (sin duplicar `TaskLabel`/`NotificationText` en Swift). Es una **excepción nueva a CA-019-23**, que se registra en el ADR-0030 (enmienda la parte iOS del ADR-0025 y `threat-model.md` T-2). Swift: solo programar, cancelar, permiso, ajustes del sistema y «a la vista» (`willPresent`).
5. **Gesto atrás de iOS:** activo; lo visual es idéntico a Android (mismas transiciones, tokens y fuentes). Se registra como CA de la 028 y en `docs/design/prototype-deviations.md`.
6. **Solo iPhone** (`TARGETED_DEVICE_FAMILY = 1`).
