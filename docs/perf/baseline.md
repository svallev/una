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

## Eliminar: arrugado y papelera (spec 004, T-004-11)

- **Fecha:** 2026-09-26 · **Dispositivo:** Xiaomi 15T Pro (120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/delete_perf_test.dart -d <serial>`; se elimina con el controlador (como tras confirmar) y se mide todo el arrugado (2,2 s). Después, `adb uninstall invalid.pending.app.profile`.

| Ejecución | Fotogramas | Build medio / p90 / peor | Raster medio / p90 / p99 / peor | Fuera de presupuesto (raster) |
|---|---|---|---|---|
| 1 | 259 | 0,6 / 0,8 / 7,9 ms | 4,0 / 5,6 / 15,3 / 23,5 ms | 2 |
| 2 | 258 | 0,7 / 1,0 / 8,3 ms | 4,5 / 5,7 / 14,2 / 22,9 ms | 2 |
| 3 | 264 | 0,8 / 1,0 / 6,5 ms | 4,4 / 5,5 / 16,4 / 27,5 ms | 4 |

- **[Hecho]** Fluido: el 90 % de los fotogramas cuesta ~6,5 ms en total. Hay de 2 a 4 fotogramas lentos (15–28 ms de raster) por cada ~260.
- **[Suposición]** Esos fotogramas lentos son los primeros de la capa (sombra, facetas y degradados que se crean por primera vez), como pasaba en la 003. **[Pendiente]** Si se nota en el móvil o en gama media, precargar los *shaders* o la capa (I-3).

## Listado con 500 tareas (spec 006, T-006-15, CA-006-20)

- **Fecha:** 2026-09-26 · **Dispositivo:** Xiaomi 15T Pro (120 Hz, presupuesto de 8,3 ms por fotograma)
- **Método:** `flutter drive --profile --no-dds --keep-app-running --driver=test_driver/perf_driver.dart --target=integration_test/task_list_perf_test.dart -d <serial>`, con 500 tareas (una de cada 7 con texto largo). Abrir: desde que se toca "Todas mis tareas" hasta ver las filas. Desplazar: 6 lanzamientos abajo y 6 arriba. Arrastrar: una fila 480 px abajo y vuelta. Después, `adb uninstall invalid.pending.app.profile`.

| Medida | Resultado | Objetivo (CA-006-20) |
|---|---|---|
| Abrir el listado | 40 ms | < 300 ms |
| Desplazar (2 167 fotogramas) | Build medio / p90 / peor: 0,6 / 1,5 / 3,6 ms · Raster medio / p90 / p99: 1,9 / 2,5 / 3,1 ms · 0 fuera de presupuesto | p90 ≤ 16,7 ms |
| Arrastrar (172 fotogramas) | Build medio / p90 / peor: 1,3 / 3,5 / 5,5 ms · Raster medio / p90 / p99: 2,3 / 2,9 / 4,0 ms · 0 fuera de presupuesto | p90 ≤ 16,7 ms |

- **[Hecho]** Muy por debajo del objetivo, incluso para 120 Hz. Mover solo la fila levantada (sin reconstruir la lista en cada movimiento) redujo a la mitad el coste del arrastre en el emulador.

## Visor de imágenes (spec 007, T-007-23)

- **Fecha:** 2026-09-27 · **Dispositivo:** Xiaomi 15T Pro (120 Hz, 1280 × 2772)
- **Imagen:** PNG de 50 MP (`px50.png`), guardada reducida a 24 MP con teselas de 4096 px.
- **Presupuesto** (`docs/architecture.md` §7, redefinido por el propietario el 2026-09-27): ampliar a ×8 añade < 200 MB sobre la tarea actual. El anterior, < 250 MB en total, era inalcanzable: la app ya ocupa ~350 MB de RSS en la pantalla principal.

**Memoria (la medida que manda).** App *profile* normal (`flutter build apk --profile` + `adb install -r`), proceso nuevo, con la tarea de 24 MP ya guardada; `adb shell dumpsys meminfo invalid.pending.app.profile` en cada paso (doble toque con `adb shell input tap`).

| Momento | PSS total | RSS total | Texturas GPU (GL mtrack) |
|---|---|---|---|
| Tarea actual con imagen | 235 MB | 350 MB | 41 MB |
| Visor ×1 | 241 MB | 359 MB | 61 MB |
| Visor ×2,5 | 273 MB | 392 MB | 94 MB |
| Visor ×8 | 385 MB | 503 MB | 206 MB |
| Visor ×8 tras desplazar | 358 MB | 476 MB | 178 MB |

- **[Hecho]** El visor a ×8 añade **+150 MB de PSS** (+153 MB de RSS): dentro del presupuesto. Casi todo son texturas: a ×8 cada tesela visible se decodifica entera (4096² × 4 B ≈ 64 MB).
- **[Hecho]** `viewer_perf_test` (aviso automático, RSS del proceso): +89 MB, pico de 625 MB de toda la ejecución. Ese pico es la **importación** de 50 MP, que se decodifica en el mismo proceso. La RSS del proceso no cuenta toda la memoria de la GPU, por eso da menos que `dumpsys`.
- **[Pendiente]** En gama media (R-02), y sobre todo en Android 8 con 2–3 GB, el pico de la importación (~620 MB) es el riesgo, más que el visor. Si hace falta, teselas más pequeñas reducirían el visor a unos 4–16 MB de texturas.

**Fluidez del zoom** (`flutter drive --profile … --target=integration_test/viewer_perf_test.dart`: doble toque a ×2,5 y ×8, con desplazamientos).

| Ejecución | Fotogramas | Build medio / p90 / peor | Raster medio / p90 / p99 / peor | Fuera de presupuesto |
|---|---|---|---|---|
| 1 | 115 | 0,5 / 0,9 / 2,6 ms | 1,1 / 1,7 / 2,1 / 2,2 ms | 0 |
| 2 | 117 | 0,6 / 0,9 / 2,4 ms | 1,0 / 1,6 / 2,0 / 2,4 ms | 0 |

- **[Hecho]** Muy por debajo del presupuesto de 120 Hz (8,3 ms).

## Cómo repetir la medición

```bash
cd app && flutter build apk --release --split-per-abi --target-platform android-arm64
adb -s <serial> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Abre la app y crea una tarea; después:
cd .. && tools/measure-cold-start.sh <serial> 20
```

Se repite al cerrar cada spec que toque el arranque (003, 007–009) y antes de cada release.
