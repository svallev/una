# Spec 028 — Pruebas en dispositivo

Resultados en aparatos reales (iPad del propietario). Las filas «Disp» y «VO» de `matriz.md` remiten aquí. Solo tareas ficticias.

## Aparato y forma de instalar

- **iPad de 6.ª generación** (iPad7,5, iPadOS 17.7.1), app «solo iPhone» en modo compatibilidad (`plan-f-ios.md`).
- **Firma gratuita** (equipo personal del propietario). El equipo y un bundle ID de desarrollo se pasan **solo en la línea de `xcodebuild`** (`DEVELOPMENT_TEAM=…`, `PRODUCT_BUNDLE_IDENTIFIER=…`, `-allowProvisioningUpdates`); `project.pbxproj` sigue con `invalid.pending.app` y sin equipo (PD-2). Receta, desde `app/`: `flutter build ios --config-only --release --no-codesign`, luego `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination id=<UDID> … build` y `xcrun devicectl device install app --device <UDID> <Runner.app>`. La firma caduca a los 7 días.
- [Hecho] Para leer el identificador del equipo, el propietario lo elige en Xcode (Signing & Capabilities) y se deshace el cambio de `project.pbxproj` con `git checkout`.

## T-028-20 · Q-028-5 «Una sola a la vez» (CA-019-18, CA-028-16) — 2026-11-22

- **Pasos:** *release* instalada; una tarea ficticia; notificaciones activadas con permiso y **3 al día**; app cerrada desde el selector. Sin abrir la app, la hora del iPad se adelantó a mano a 08:54, 13:54 y 18:54, esperando cada aviso.
- **Resultado [Hecho]:** llegaron los tres avisos, cada uno a su hora, y al final el centro de notificaciones solo tenía **la última**.
- **Conclusión:** Q-028-5 = **«una»**. CA-019-18 se cumple en iOS sin el identificador único; el código de T-028-19 no cambia.
- **[Suposición]** Se probó cambiando la hora a mano, no esperando al día real; no se ve motivo para que iOS se comporte distinto.

## T-028-22 · Simulador completo (CA-028-01, 02, 04, 05, 08) — 2026-11-22

Simulador iPhone 18 Pro, iOS 27.2 (Xcode 27.2), con `/ios-check todos`.

- **Pasada 1, claro y `es-ES` [Hecho]:** build y XCTest (178) en verde; paridad con las 13 secciones activas y ninguna `PENDIENTE`; IT 19 de 20 en verde con sus `skip:` motivados (los 5 `*_perf_test` y los casos del contrato). `image_flow` falló una vez: el test esperaba solo 10 s a que terminara la preparación de la captura de 1080 × 20 000 y guardaba a medias; la espera sube a 30 s y falla de forma explícita si se agota (no cambia lo que comprueba). Repetido: 3 de 3 en verde.
- **Pasada 2, oscuro y `ca-ES, en-US` [Hecho]:** IT 19 de 20 en verde. Bajo el icono sale «Una»; la app abre **en español** y **en claro** (`paper`, barra de estado oscura) con el sistema en oscuro y en catalán (capturas del simulador, no guardadas). Falló `settings_flow`: al volver de «English» a «Como el sistema» la app se quedaba en inglés. **Hallazgo de la I8, arreglado en esta rama** (propietario, 2026-11-22): es Dart de la 015 y pasa igual en Android; Flutter no recalcula el idioma del sistema al cambiar `localeListResolutionCallback`, que solo se pasaba con «Como el sistema»; ahora se pasa siempre (`una_app.dart`, test `locale_change_test.dart`). `settings_flow` 3/3 después.
- **iOS 16: no se prueba** (decisión del propietario, 2026-11-22: «con el que hay basta»). Solo está el runtime de iOS 27.2; la versión antigua la cubre el iPad (iPadOS 17.7.1). El mínimo iOS 16 lo comprueba la sección `project` del script.
- **Modo avión real: no se prueba** (decisión del propietario, 2026-11-22). El simulador no tiene modo avión propio y comparte la red del Mac. Ningún IT usa red externa y la sección `network` del script comprueba que el Swift no la usa.
- **Trampa:** tras `xcodebuild test` el simulador quedó apagado y los IT no encontraban el dispositivo; anotado en `/ios-check`.
