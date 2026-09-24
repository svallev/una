# ADR-0001: Flutter como stack de la app

- **Estado:** Provisional, pendiente del resultado de los spikes S1–S6 (fase F1 de `docs/PLAN.md`)
- **Fecha:** 2026-09-24
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** ADR-0002, 0007, 0008, 0010; riesgos R-02, R-03, R-04, R-09

## Contexto

- **[Hecho]** App móvil iOS + Android, local y sin conexión, con animaciones propias (nota rota en dos, papel arrugado, mantener pulsado), un visor a pantalla completa, PDF sin conexión, URL "dentro de la tarea" y un objetivo de **< 1 s** desde el arranque en frío hasta ver la tarea actual.
- **[Hecho]** La versión web solo sirve para pruebas (D4), en Vercel con *preview* por PR.
- **[Hecho]** El propietario no domina ni TypeScript ni Dart (D1): el mantenimiento lo hace una persona con ayuda de Claude Code. Criterio: legibilidad, tipado fuerte y buenas herramientas.
- **[Hecho]** Tiene un Mac Apple Silicon (macOS 26.6), sin Xcode instalado todavía.
- **[Hecho, docs 2026-09]** Flutter admite iOS 15–26 y Android API 24–37. `expo-widgets` está en **alfa y solo cubre iOS**. `flutter_inappwebview` permite desactivar el puente JS y el acceso a archivos.
- **[Suposición]** Un Android de gama media de referencia (tipo Pixel 6a / Galaxy A54) es representativo del objetivo de arranque.

## Opciones consideradas

- **A. Flutter** (iOS + Android + build web para pruebas)
- **B. Web (React + shadcn/ui) empaquetada con Capacitor**
- **C. React Native con Expo** (con salida web)
- **D. PWA pura**

## Matriz ponderada (1 = malo, 5 = excelente)

| Criterio | Peso | A Flutter | B Capacitor | C Expo | D PWA |
|---|---:|---:|---:|---:|---:|
| Arranque en frío hasta ver la tarea (< 1 s) | 20 | **5** — AOT, sin puente, Impeller | 2 — arranque de la WebView + JS | 3 — Hermes + bundle JS | 2 — depende del navegador y la caché |
| Animaciones a medida (arrugar, romper, mantener) | 15 | **5** — `CustomPainter` + *fragment shaders* | 3 — filtros SVG del prototipo, lentos en WebView Android | 4 — Reanimated + Skia | 3 |
| Visor de imagen con zoom | 5 | 5 | 4 | 4 | 4 |
| PDF sin conexión + visor del sistema | 10 | **5** — pdfrx (PDFium); QuickLook/intent por plugin | 3 — pdf.js | 4 — react-native-pdf | 2 |
| URL en WebView + captura de página completa | 10 | 4 — flutter_inappwebview (captura, PDF, endurecido) | 3 | 4 — react-native-webview | **0** — `X-Frame-Options`/CSP bloquean el iframe |
| Almacenamiento fiable y archivos grandes | 10 | **5** — drift/SQLite + sistema de archivos | 3 — plugin de SQLite; el web es frágil | 4 — expo-sqlite + expo-file-system | 1 — Safari borra datos, cuotas |
| Widgets de pantalla de inicio/bloqueo (futuro) | 10 | 4 — home_widget (iOS + Android; la UI del widget es nativa) | 2 | 2 — expo-widgets alfa y solo iOS | 0 |
| Notificaciones locales (futuro) | 5 | 5 | 4 | 5 | 2 |
| Mantenimiento por una persona con Claude Code | 15 | 4 — Dart es sencillo y tipado; menos ejemplos que TS | 4 | **5** — el ecosistema TS más amplio | 5 |
| Web de pruebas en Vercel con *preview* por PR | 5 | 3 — build web OK; fidelidad y accesibilidad menores | **5** | 4 | 5 |
| Entorno y compilación (Mac, nube) | 5 | 4 — Mac local; Codemagic opcional | 4 | 5 — EAS Build | 5 |
| Madurez, riesgo de abandono y coste de actualizar | 5 | 4 — una actualización estable al trimestre, sin rupturas grandes | 4 | 3 — SDK tres veces al año, con migraciones | 4 |
| **Total ponderado (máx. 575)** | | **520** | **360** | **440** | **290** |

Cálculo: Σ(peso × nota). Donde la nota es parecida entre opciones, la diferencia la marcan el arranque en frío, las animaciones y el almacenamiento, que son los tres criterios ligados a las propuestas de valor.

## Decisión

**Flutter (canal estable, versión fijada con FVM en `.fvmrc`)**, condicionado a que los spikes S1–S5 cumplan sus criterios de salida. Si S1 (arranque) o S2 (animación) fallan de forma no resoluble, **la alternativa es Expo (C)**. No se escribe código de producto hasta cerrar F1.

## Motivos

1. **Propuesta de valor 2 (instantáneo):** Flutter compila a código nativo AOT y pinta el primer fotograma sin puente JS. Es la opción con más margen para el objetivo de < 1 s.
2. **Identidad visual del prototipo:** las animaciones de papel (arrugar con desplazamiento y sombreado, rotura con borde irregular) se implementan con *fragment shaders* y `CustomPainter` a 60 fps. Con Capacitor habría que portar los filtros SVG, que ya van lentos en la WebView de Android.
3. **Sin conexión de verdad:** SQLite (drift) con migraciones versionadas y comprobadas, archivos en el sandbox y PDF con PDFium, sin red.
4. **No cierra los widgets:** `home_widget` da un canal de datos iOS/Android (App Groups / SharedPreferences) hacia los widgets nativos (SwiftUI/Glance). En Expo solo hay soporte alfa y solo para iOS.
5. **Mantenimiento:** Dart es un lenguaje pequeño, con tipado nulo seguro, formateador y analizador oficiales, lo que facilita revisar lo que escribe Claude Code. La desventaja frente a TypeScript (menos ejemplos) se mitiga con specs, tests y ADRs.

## Opciones descartadas

- **D. PWA:** no puede mostrar la mayoría de URL (iframe bloqueado); Safari puede borrar el almacenamiento de webs y PWA; no hay widgets. Incumple P3 y la propuesta 2.
- **B. Capacitor:** la mejor web de pruebas, pero la peor en arranque en frío y en rendimiento de las animaciones del prototipo; el almacenamiento depende de plugins.
- **C. Expo:** alternativa sólida y la mejor en ecosistema. Queda por detrás en arranque, en widgets Android y en coste de actualización (tres SDK al año). **Es el plan B.**

## Consecuencias

- **Positivas:** una sola base de código; rendimiento y control de píxel; tests de widgets y *goldens* integrados; web de pruebas con el mismo código.
- **Negativas y riesgos:**
  - La web de Flutter es menos fiel (renderizado en canvas, accesibilidad por el árbol semántico) → aceptable porque solo es de pruebas (ADR-0010).
  - CodeQL no analiza Dart → `dart analyze` con reglas estrictas + Semgrep/OSV-Scanner; CodeQL para Swift/Kotlin/Actions.
  - Plugins clave con un solo mantenedor (flutter_inappwebview) → riesgo R-04; el plan B es `webview_flutter` oficial + código de plataforma para la captura.
  - Curva de Dart para el propietario → CLAUDE.md con convenciones, specs en español y revisiones guiadas por subagentes.
- **Entorno:** hace falta Xcode (iOS) y Android Studio (Android). Sin cuentas de tienda solo hay simulador/emulador, instalación directa en Android y la web.

## Spikes que validan esta decisión (código desechable, requieren aprobación)

| ID | Qué se prueba | Criterio de salida |
|---|---|---|
| S1 | Arranque en frío con SQLite + una tarea con imagen de 12 MP | p50 < 1 s y p90 < 1,3 s en Android de gama media (*release*); < 0,6 s en iPhone ≥ 12 |
| S2 | Arrugar (shader de desplazamiento + facetas) y rotura en dos; variante "reducir movimiento" | 60 fps sostenidos en gama media, sin tirones en el primer uso (shaders precompilados) |
| S3 | PDF de 50 MB/300 páginas con pdfrx sin conexión; abrir DOCX/XLSX con QuickLook/intent | Primera página < 500 ms; zoom fluido; sin red |
| S4 | WebView endurecida + captura de página completa (iOS/Android) de 3 webs reales (horario, mapa, receta) | Captura legible de hasta 20 000 px de alto; puente JS y acceso a archivos desactivados y verificados |
| S5 | Importación: bytes mágicos, eliminación de EXIF/GPS, 30/50 MB, copia en el sandbox, inclusión en el backup | EXIF eliminado (comprobado con exiftool); sin bloquear la UI |
| S6 | `flutter build web` + preview en Vercel con cabeceras | Preview por PR funcionando en < 10 min |

## Actualización 2026-09-24: Android primero (D17)

- **[Hecho]** El propietario decide desarrollar y validar primero en **Android** (emulador Pixel 6a, API 37) y en la web de pruebas, sin instalar Xcode por ahora. iOS se abordará al final (fase F-iOS de `docs/PLAN.md`) si decide seguir (PD-7).
- **Efecto en esta decisión:** los spikes de F1 se ejecutan en Android y web. Si se cumplen, este ADR pasa a **Aceptado para Android** y sigue **Provisional para iOS** hasta los spikes iOS de F-iOS.
- **No cambia el stack:** Flutter sigue siendo la mejor opción precisamente porque mantiene iOS abierto con la misma base de código. Si en F-iOS algo fallase, el coste queda acotado a la integración nativa (puertos `SystemViewer`, `WebSnapshotter`, `ImageSanitizer`), no a la app.
- **Mitigación del riesgo R-18:** el job `ios` de CI (macOS, sin firmar) compila iOS en cada PR desde F2, así que las roturas de compilación se detectan aunque no haya Xcode en local.
- **Versión de Flutter fijada:** 3.47.5 (cabeza del canal `stable` el 2026-09-24), en `.fvmrc`.
