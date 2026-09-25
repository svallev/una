# Rendimiento: línea base

Presupuestos (docs/PLAN.md, CA-001-09): tarea actual visible en **< 1 s (p50)** desde el icono, en *release*; descarga **< 25 MB** por ABI en Android.

## Arranque en frío (T-001-17)

- **Fecha:** 2026-09-24 · **Commit:** rama `feat/001-primer-uso-y-tarea-actual` (spec 001 completa, con fuentes empaquetadas)
- **Dispositivo:** Xiaomi 15T Pro (MediaTek Dimensity MT6991, Android 16 / HyperOS OS3.0.304.0), **gama alta**
- **Compilación:** `flutter build apk --release --split-per-abi --target-platform android-arm64` (19,7 MB)
- **Estado:** una tarea de texto pendiente; la app abre directamente en la tarea actual
- **Método:** `tools/measure-cold-start.sh <serial> 20` → `am start -W -S` (TotalTime: del lanzamiento al primer fotograma, que ya muestra la tarea porque se lee antes de `runApp`)

| n | mín | **p50** | p90 | máx |
|---|---|---|---|---|
| 20 | 187 ms | **198 ms** | 211 ms | 279 ms |

- **[Hecho]** CA-001-09 se cumple con amplio margen en el dispositivo de referencia: p50 = 20 % del presupuesto. El primer arranque tras instalar tardó 515 ms (optimización inicial del sistema); no cuenta como arranque en frío habitual.
- **[Hecho]** Tras matar el proceso, la app reabre en la tarea actual (lectura del árbol de accesibilidad: "Tarea actual: …", "Menú de la tarea", "Pulsa para completar").
- **[Pendiente, riesgo R-02]** Falta un Android de gama media. El spike S1 midió la misma arquitectura en el emulador (tiempo propio de la app ≈ 80 ms); se confirmará en la beta o con un dispositivo prestado.

## Completar: rotura y enhorabuena (spec 003, T-003-09)

- **Fecha:** 2026-09-25 · **Dispositivo:** Xiaomi 15T Pro (pantalla de 120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/complete_perf_test.dart -d <serial>` (fotogramas reales, `fullyLive`); se completa con el controlador (como la acción accesible) y se mide toda la secuencia (pausa, rotura, enhorabuena y fundido, ~2,9 s). App de pruebas `invalid.pending.app.profile`, que se desinstala a mano después (ver `docs/testing.md`).

| Ejecución | Fotogramas | Build medio / p90 / peor | Raster medio / p90 / p99 / peor |
|---|---|---|---|
| 1 | 243 | 1,4 / 2,1 / 11,9 ms | 2,6 / 3,4 / 10,6 / 12,5 ms |
| 2 | 232 | 1,5 / 2,3 / 20,0 ms | 2,5 / 3,4 / 10,6 / 14,1 ms |
| 3 | 231 | 1,5 / 2,1 / 22,9 ms | 2,4 / 3,4 / 8,9 / 13,7 ms |

- **[Hecho]** Fluida: el 90 % de los fotogramas cuesta ~6 ms en total, muy por debajo del presupuesto de 120 Hz. El recorte con `ClipPath` (sin capturar la nota como imagen) evita el tirón del spike S2.
- **[Hecho]** El único fotograma lento (12–23 ms) es el primero de la enhorabuena, al montar la capa. **[Pendiente]** Si se nota en gama media, precargar la capa (I-3).

## Cómo repetir la medición

```bash
cd app && flutter build apk --release --split-per-abi --target-platform android-arm64
adb -s <serial> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Abre la app y crea una tarea; después:
cd .. && tools/measure-cold-start.sh <serial> 20
```

Se repite al cerrar cada spec que toque el arranque (003, 007–009) y antes de cada release.
