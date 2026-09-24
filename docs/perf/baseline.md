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
- **[Hecho]** Tras matar el proceso, la app reabre en la tarea actual (lectura del árbol de accesibilidad: "Tarea actual: …", "Menú de la tarea", "Mantén pulsado para completar").
- **[Pendiente, riesgo R-02]** Falta un Android de gama media. El spike S1 midió la misma arquitectura en el emulador (tiempo propio de la app ≈ 80 ms); se confirmará en la beta o con un dispositivo prestado.

## Cómo repetir la medición

```bash
cd app && flutter build apk --release --split-per-abi --target-platform android-arm64
adb -s <serial> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Abre la app y crea una tarea; después:
cd .. && tools/measure-cold-start.sh <serial> 20
```

Se repite al cerrar cada spec que toque el arranque (003, 007–009) y antes de cada release.
