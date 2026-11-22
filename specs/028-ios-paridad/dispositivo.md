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
