# Estrategia de testing

Principio P9: nada está hecho sin tests que prueben sus criterios de aceptación. Cada test referencia el ID del criterio en su descripción (`'CA-003-02: soltar antes de tiempo cancela'`).

## Pirámide

| Nivel | Qué cubre | Herramienta | Dónde corre |
|---|---|---|---|
| **Unitarios (dominio)** | Cola, `Rank` (orden fraccional), colores, validación de URL, detección de tipos, reglas R4/R5, deshacer y purga | `package:test` (Dart puro) | CI (Linux) |
| **Propiedades** | `Rank`: N inserciones y movimientos aleatorios mantienen un orden total y estable | `glados` o generador propio | CI |
| **Contrato del repositorio** | La misma batería contra `DriftTaskRepository` (SQLite en memoria) e `InMemoryTaskRepository` | `flutter_test` | CI |
| **Migraciones** | Cada `schemaVersion` migra desde todas las anteriores sin perder datos | `drift_dev` (tests generados) | CI |
| **Widgets** | Pantallas y componentes, estados, textos ES/EN, gestos (mantener, arrastrar, doble toque) con reloj falso | `flutter_test` | CI |
| **Visuales (*goldens*)** | Pantallas frente al prototipo (390 × 844), ES/EN, escala de texto 1,0 y 2,0; con fuentes empaquetadas | `matchesGoldenFile` (+ `alchemist` si hace falta) | CI Linux (referencias generadas en CI) |
| **Accesibilidad automática** | Contraste, objetivos táctiles, etiquetas | `meetsGuideline(...)` en los tests de widgets | CI |
| **Integración/E2E** | Flujos: primer uso; crear y colocar; completar; eliminar y deshacer; reordenar; importar imagen, PDF y URL; persistencia; **sin red** | `integration_test` | Simulador/emulador en CI (macOS y Android) y en local |
| **Rendimiento** | Arranque en frío → tarea visible; fps de las animaciones | `integration_test` + `FrameTiming`/timeline, en modo *profile* | Dispositivo real (manual en cada release; automatizable con un laboratorio de dispositivos más adelante) |
| **Seguridad** | *Fixtures* maliciosas (EXIF con GPS, PDF con JS, `.pdf` que es HTML, SVG, *zip bomb*, URL `javascript:`/IDN) | Unitarios + integración | CI |
| **Manual de accesibilidad** | VoiceOver, TalkBack, Switch Control/Access, teclado, texto al 200 %, reducir movimiento | Checklist en la PR | Antes de cerrar cada spec y en F5 |

## Reglas

- **Relojes y tiempos:** todo lo temporal (mantener 1,2 s, deshacer 6 s, máquina de escribir) usa un `Clock` inyectable; en los tests, `fakeAsync`.
- **Sin red en los tests:** `HttpOverrides` que falla ante cualquier conexión (salvo los tests de URL, que usan un servidor local).
- **Datos de prueba:** *fixtures* en `app/test/fixtures/` (imágenes con EXIF, PDF variados, documentos, BD de versiones anteriores).
- **Cobertura:** objetivo ≥ 90 % en `domain/`, ≥ 70 % global. La cobertura es un indicador, no un fin; los criterios de aceptación cubiertos son lo que cuenta.
- **Goldens:** solo se regeneran de forma explícita (`--update-goldens`) y la PR muestra el antes y el después.
- **Tests inestables:** se ponen en cuarentena con un issue enlazado; nunca se ignoran en silencio.

## En CI (ver `.github/workflows/ci.yml`)

`format` → `analyze` → `unit+widget+golden` → `migrations` → `l10n/tokens` → `build web` / `build apk (debug)` / `build ios (no-codesign)` → `integration (android emulator)` (en `main` y de forma nocturna para no alargar las PR).
