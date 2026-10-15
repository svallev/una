# Spec 021: pruebas en el dispositivo

Emulador `Pixel_6a_api37_root` (Android 16 / API 37, arm64, `emulator-5554`, navegación por gestos), compilación *release* de `main` (`8787643`), `flutter build apk --release --split-per-abi --target-platform android-arm64`.

## T-021-01: medida previa (2026-10-15, **terminada**)

Sistema en oscuro con `cmd uimode night yes`; «Tema oscuro ampliado» (Ajustes › Pantalla › Tema oscuro › *Expanded*) fija `accessibility_force_invert_color_enabled=1` (se borra para apagarlo). Capturas en el directorio temporal de la sesión (no se suben). Todo restaurado: claro, gestos, ampliado apagado.

| Punto | Estado | Resultado |
|---|---|---|
| (a) iconos de las barras y velo, sistema en oscuro | **[Hecho]** | Gestos: barra de estado con iconos oscuros sobre fondo claro y píldora oscura; con la hoja abierta, iconos oscuros sobre el velo gris (~5:1 a ojo; **sin medir en píxeles**, va a T-021-06). Tres botones: el sistema pinta la barra de navegación gris oscura con iconos claros (~10:1 a ojo), también con la hoja y con la card de deshacer (barra negra); la barra de estado sigue con iconos oscuros. La app entera sigue en claro |
| (b) página `https` con `prefers-color-scheme` | **[Hecho]** | `https://www.google.com` sale **oscura** en la WebView (la página ve `prefers-color-scheme: dark`): T-021-04 es necesaria. `developer.android.com` sale mixta (cabecera clara, *hero* oscuro por diseño) y no sirve de prueba. `https://example.com` no carga en el emulador (pantalla de error de la app) |
| (c) *splash* desde la notificación de la 019 | **[Pendiente]** | No medido: exige la alarma y el reloj movido de `docs/testing.md`. Va a C-021-10 de T-021-06. **[Suposición]**: el tema de lanzamiento es el mismo que desde el icono; Android 12+ omite el icono del *splash* al lanzar desde una notificación (aceptado por la spec) |
| (d) «Tema oscuro ampliado» y «Anular forzar modo oscuro» | **Parcial** | Con *Expanded* encendido y `main`: la app (Flutter) y la página Wikipedia (solo claro) siguen **en claro**; no se oscurece nada. **[Pendiente]** «Anular forzar modo oscuro» (opción de desarrollador): se hace en T-021-06 junto con la repetición |
| (e) arranque en frío, 5 por modo (`measure-cold-start.sh`) | **[Hecho]** | oscuro: p50 448 ms (min 427, max 459); claro: p50 469 ms (min 449, max 479). Referencia de `main`, n=5: no sirve para CA-021-10 (n ≥ 20 en T-021-07) |
