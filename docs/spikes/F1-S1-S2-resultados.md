# F1 · Resultados de los spikes S1 (arranque) y S2 (animaciones), Android

- **Fecha:** 2026-09-24 · **Estado:** ✅ **validado en dispositivo físico** (Xiaomi 15T Pro); pendiente solo un móvil de gama media (R-02)
- **Código:** rama `spike/f1-android`, carpeta `spikes/una_spikes/` (desechable, no se fusiona)
- **Entorno:** Flutter 3.47.5 (stable), Dart 3.13.4, *release* arm64, JDK 25 de Android Studio (Gradle sin problemas). Emulador `Pixel_6a` Android 17 (API 37), 4 núcleos, 3 GB, páginas de 16 KB, en un Mac Apple Silicon.
- **Relacionado:** ADR-0001 (criterios S1/S2), D17, riesgos R-02, R-03, R-18

## Resumen

| Spike | Criterio (ADR-0001) | Resultado en el emulador | Veredicto |
|---|---|---|---|
| S1 arranque | p50 < 1 s en Android de gama media | Tiempo propio de la app (de `main()` a la tarea visible): **~80 ms (texto)** y **~1,3 s (imagen de 12 MP)**. El total del emulador (~2–3 s) lo domina el propio emulador: la app nativa de Ajustes tarda 2,3–3,0 s y una app Flutter vacía, 3,0–3,8 s | **Provisional ✅ para texto; ⚠️ imagen por optimizar.** Falta medir en un dispositivo físico |
| S2 animaciones | 60 fps sostenidos, sin tirones en el primer uso | Con GPU por hardware: p50 **9 ms** (60 fps) en la mitad de las ejecuciones y **23 ms** (~43 fps) en la otra; primer fotograma de cada animación **40–105 ms** | **Provisional ✅ viable; ⚠️ primer fotograma por optimizar.** Falta medir en un dispositivo con Vulkan |

**Conclusión provisional:** nada de lo medido invalida Flutter (ADR-0001). Salen tres decisiones de implementación (abajo) y la necesidad de medir en un móvil físico.

## S1: arranque en frío

Método: `am start -W -S` (TotalTime) + `reportFullyDrawn()` (Fully drawn) + marcas internas; 15 arranques por variante tras forzar la detención del proceso; 200 tareas de texto y 1 tarea con imagen de 12 MP en la BD.

| Variante | `task_visible_ms` (desde `main()`) | TotalTime (proceso completo) |
|---|---|---|
| A. drift en un isolate aparte (`driftDatabase()`), tarea de texto | 765–1 631 ms (mediana ≈ 900) | 2,7–5,1 s |
| **B. drift en el isolate principal (`NativeDatabase`)**, tarea de texto | **22–150 ms (mediana ≈ 80)** | 1,9–4,7 s |
| B + imagen, versión de pantalla **PNG 1440 px** | 955–3 163 ms (mediana ≈ 1 600) | 2,3–5,3 s |
| **B + imagen, versión de pantalla JPEG 1080 px (q85)** | **1 157–1 691 ms (mediana ≈ 1 300)** | 2,6–3,3 s |
| Referencia: app nativa Ajustes | — | 2,3–3,0 s |
| Referencia: app Flutter vacía | — | 3,0–3,8 s |

Hallazgos:
1. **Abrir SQLite en un isolate aparte cuesta ~0,8 s en el emulador** (crear el isolate + cargar la librería). Abrirlo en el isolate principal para la consulta de arranque lo reduce ~10 veces. → **Decisión de implementación I-1.**
2. **Decodificar la imagen domina el arranque con adjunto.** JPEG al ancho exacto de la pantalla mejora ~20 % frente a PNG. El resto (~1,2 s en el emulador) es decodificación por CPU virtual; en un móvil real se espera bastante menos, pero hay que confirmarlo. → **I-2**, y se prueban alternativas en el dispositivo (miniatura instantánea + sustitución; decodificar en paralelo al arranque del motor).
3. El emulador **no sirve para el valor absoluto** del objetivo de < 1 s (hasta una app nativa tarda más de 2 s). Solo sirve para comparar variantes.

## S2: animaciones

Método: `SchedulerBinding.addTimingsCallback` durante cada animación; gestos reales con `adb input` (mantener pulsado 1,5 s, tocar eliminar); 3 repeticiones.

| Animación | GPU por software (lavapipe/SwANGLE) | **GPU del Mac (host)** |
|---|---|---|
| Completar (romper en dos + enhorabuena) | 12–13 fot., raster p90 300–390 ms ❌ | 78–79 fot.; p50 9–23 ms; p90 11–25 ms; raster p90 7–19 ms |
| Eliminar (shader de arrugado + papelera) | 5–6 fot., raster p90 430–490 ms ❌ | 118–124 fot.; p50 8–23 ms; p90 11–25 ms; raster p90 5–18 ms |
| Completar (reducir movimiento: fundido) | — | 28 fot.; p50 9,7 ms; p90 11,6 ms |

Hallazgos:
1. El **shader de arrugado (desplazamiento fractal + luz) y la rotura en dos con borde irregular** reproducen el prototipo y se renderizan a 60 fps cuando la GPU va bien. Impeller en el emulador usa **OpenGLES** (en dispositivos modernos, Vulkan). El modo bimodal de 9 ms frente a 23 ms parece ruido de la traducción GLES del emulador; **hay que confirmarlo en un dispositivo**.
2. **Primer fotograma de 40–105 ms:** la captura de la nota como imagen (`RenderRepaintBoundary.toImage`) al empezar la animación. → **I-3.**
3. Con renderizado por software, cualquier animación es inviable; no afecta a los dispositivos reales, pero **el emulador debe arrancar con `-gpu host`** (documentado en `docs/environments.md`).
4. Error de medición corregido: `FrameTiming` se entrega por lotes (~1 s en *release*); el registrador ahora espera 1,2 s antes de cerrar.

## Decisiones de implementación que salen de aquí (para el plan de la spec 001/003/004)

| ID | Decisión | Motivo |
|---|---|---|
| I-1 | La **consulta de arranque** (tarea actual) usa una conexión SQLite en el **isolate principal**. Las escrituras pesadas (importaciones, purgas) pueden ir a un isolate en segundo plano después del primer fotograma | −~850 ms en el emulador |
| I-2 | Al importar una imagen se genera una **versión de pantalla en JPEG (o WebP) al ancho físico exacto** de la pantalla, además de una miniatura pequeña; nunca se decodifica el original para arrancar | −20 % respecto a PNG; se ajusta en el dispositivo |
| I-3 | **Precapturar** la nota actual como imagen tras el primer fotograma (o usar `ImageFilter.shader` sobre el widget, sin captura) para que el primer fotograma de completar/eliminar no dé tirones | Primer fotograma de 40–105 ms |

## Pendiente para cerrar S1 y S2

1. **Medir en tu móvil Android físico** (gama alta): mismas variantes, 15 arranques cada una. Es el dato que manda sobre el emulador.
2. En el móvil: comprobar que Impeller usa **Vulkan** y repetir S2 (60 fps sin modo bimodal; primer fotograma < 32 ms con I-3).
3. **Riesgo abierto (R-02):** sin un dispositivo de gama media, el objetivo de < 1 s en gama media queda **sin verificar**. Opciones: un móvil prestado, un laboratorio de dispositivos gratuito (p. ej. Firebase Test Lab en su capa gratuita; habría que valorar su privacidad antes) o aceptar el riesgo hasta la beta.

## Dispositivo físico: Xiaomi 15T Pro (2026-09-24)

**Dispositivo:** Xiaomi 15T Pro (MediaTek Dimensity MT6991, 8 núcleos, 11 GB, Android 16 / HyperOS 3, pantalla de 120 Hz, páginas de 4 KB). **Gama alta.** Impeller sobre **Vulkan**. Compilación *release* arm64.

### S1: arranque en frío (am start -W + reportFullyDrawn)

| Caso | Desde el icono (TotalTime) | Dentro de la app (`main()` → tarea visible) |
|---|---|---|
| Tarea de texto, SQLite en el isolate principal (I-1) | **219–316 ms**, mediana ≈ 250 ms (19 medidas) | 6–121 ms, mediana ≈ 45 ms |
| **Imagen de 12 MP**, versión de pantalla JPEG (I-2) | **242–347 ms**, mediana ≈ 257 ms (15/15) | 67–154 ms, mediana ≈ 89 ms |
| Tarea de texto, SQLite en un isolate aparte | 288–319 ms (4 válidas; reconexión del cable) | 71–141 ms, mediana ≈ 100 ms |
| Referencia: app Flutter vacía | 204–344 ms, mediana ≈ 245 ms | — |
| Referencia: Ajustes (nativa) | 258–385 ms, mediana ≈ 265 ms | — |

**Conclusión S1:** la app abre y muestra la tarea actual, incluso con una foto de 12 MP, **igual de rápido que una app Flutter vacía y que una app nativa del sistema**: ~0,25 s, un 25 % del presupuesto de 1 s. En el dispositivo real, I-1 ahorra ~50 ms (no 850 ms como en el emulador), pero se mantiene: no cuesta nada.

### S2: animaciones (FrameTiming; 120 Hz → 8,3 ms por fotograma)

| Animación | Fotogramas | p50 | p90 | p99 | > 16,7 ms | > 32 ms |
|---|---|---|---|---|---|---|
| Completar (romper en dos) ×3 | 237–239 | 2,9–3,6 | 4,2–4,7 | 6,9–10,6 | 2 (solo en la 1.ª) · 0 · 0 | 0 |
| Eliminar (shader + papelera) ×3 | 267 | 3,5–3,6 | 4,4–4,6 | 6,5–6,7 | 0 | 0 |
| Reducir movimiento: completar / eliminar | 137 / 50 | 3,3 / 3,0 | 4,2 / 3,9 | 7,2 / 6,2 | 0 | 0 |

**Conclusión S2:** el shader de arrugado y la rotura en dos van **a 120 fps con mucho margen** (p90 ≈ 4,5 ms). El único tirón (2 fotogramas, la primera vez) es la captura de la nota: I-3 sigue siendo necesaria. El modo bimodal de 9/23 ms del emulador era ruido del emulador.

### Riesgo que queda abierto

**R-02 (gama media):** el dispositivo de prueba es de gama alta. Con un margen de ×4 sobre el presupuesto el riesgo baja a **bajo**, pero el criterio de ADR-0001 habla de gama media y no está medido. Opciones: un móvil prestado (Android de 200–300 €) o medir en la beta cerrada de Play (F6).
