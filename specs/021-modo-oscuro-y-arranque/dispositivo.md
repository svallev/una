# Spec 021: pruebas en el dispositivo

Emulador `Pixel_6a_api37_root` (Android 16 / API 37, arm64, `emulator-5554`, navegación por gestos), compilación *release* de `main` (`8787643`), `flutter build apk --release --split-per-abi --target-platform android-arm64`.

## T-021-01: medida previa (2026-10-15, **en curso**)

| Punto | Estado | Resultado |
|---|---|---|
| (a) iconos de las barras y velo, sistema en oscuro | **Parcial** | **[Hecho]** con `main` y `cmd uimode night yes`, la app (tarea web) sigue entera en claro; la barra de estado dibuja iconos oscuros sobre fondo claro y la píldora de gestos es oscura. **[Pendiente]** tres botones y velo de hojas |
| (b) página `https` con `prefers-color-scheme` | **[Pendiente]** | Wikipedia (la tarea de prueba) no es válida: solo oscurece si el usuario lo activa |
| (c) *splash* desde la notificación de la 019 | **[Pendiente]** | |
| (d) «Tema oscuro ampliado» y «Anular forzar modo oscuro» | **[Pendiente]** | Requiere activarlos desde Ajustes del emulador |
| (e) arranque en frío, 5 por modo (`measure-cold-start.sh`) | **[Hecho]** | oscuro: p50 448 ms (min 427, max 459); claro: p50 469 ms (min 449, max 479). Referencia de `main`, n=5: no sirve para CA-021-10 (n ≥ 20 en T-021-07) |

Capturas en el directorio temporal de la sesión (no se suben). Modo del sistema restaurado a claro.
