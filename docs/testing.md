# Estrategia de testing

Principio P9: nada está hecho sin tests que prueben sus criterios de aceptación. Cada test referencia el ID del criterio en su descripción (`'CA-003-02: soltar antes de tiempo cancela'`).

## Pirámide

| Nivel | Qué cubre | Herramienta | Dónde corre |
|---|---|---|---|
| **Unitarios (dominio)** | Cola, `Rank` (orden fraccional), colores, validación de URL, detección de tipos, reglas R4/R5, eliminar sin dejar contenido | `package:test` (Dart puro) | CI (Linux) |
| **Propiedades** | `Rank`: N inserciones y movimientos aleatorios mantienen un orden total y estable | `glados` o generador propio | CI |
| **Contrato del repositorio** | La misma batería contra `DriftTaskRepository` (SQLite en memoria) e `InMemoryTaskRepository` | `flutter_test` | CI |
| **Migraciones** | Cada `schemaVersion` migra desde todas las anteriores sin perder datos | `drift_dev` (tests generados) | CI |
| **Widgets** | Pantallas y componentes, estados, textos ES/EN, gestos (mantener, arrastrar, doble toque) con reloj falso | `flutter_test` | CI |
| **Visuales (*goldens*)** | Pantallas frente al prototipo (390 × 844), ES/EN, escala de texto 1,0 y 2,0; con fuentes empaquetadas | `matchesGoldenFile` (+ `alchemist` si hace falta) | CI Linux (referencias generadas en CI) |
| **Accesibilidad automática** | Contraste, objetivos táctiles, etiquetas | `meetsGuideline(...)` en los tests de widgets | CI |
| **Integración/E2E** | Flujos: primer uso; crear y colocar; completar; eliminar; reordenar; importar imagen, PDF y URL; persistencia; **sin red** | `integration_test` | Simulador/emulador en CI (macOS y Android) y en local |
| **Rendimiento** | Arranque en frío → tarea visible; fps de las animaciones | `integration_test` + `FrameTiming`/timeline, en modo *profile* | Dispositivo real (manual en cada release; automatizable con un laboratorio de dispositivos más adelante) |
| **Seguridad** | *Fixtures* maliciosas (EXIF con GPS, PDF con JS, `.pdf` que es HTML, SVG, *zip bomb*, URL `javascript:`/IDN) | Unitarios + integración | CI |
| **Manual de accesibilidad** | VoiceOver, TalkBack, Switch Control/Access, teclado, texto al 200 %, reducir movimiento | Checklist en la PR | Antes de cerrar cada spec y en F5 |

## Reglas

- **Relojes y tiempos:** todo lo temporal (mantener 1,2 s, máquina de escribir) usa un `Clock` inyectable; en los tests, `fakeAsync`.
- **Sin red en los tests:** `HttpOverrides` que falla ante cualquier conexión (salvo los tests de URL, que usan un servidor local).
- **Datos de prueba:** *fixtures* en `app/test/fixtures/` (imágenes con EXIF, PDF variados, documentos, BD de versiones anteriores).
- **Cobertura:** objetivo ≥ 90 % en `domain/`, ≥ 70 % global. La cobertura es un indicador, no un fin; los criterios de aceptación cubiertos son lo que cuenta.
- **Goldens:** solo se regeneran de forma explícita y la PR muestra el antes y el después. **[Hecho]** El texto se dibuja distinto en macOS y en Linux, así que los goldens (`app/test/goldens/`, etiqueta `golden`) **se generan y se comparan solo en Linux**:
  1. En local se omiten. Para revisarlos sin subirlos: `GOLDENS_ANY_OS=1 flutter test --update-goldens test/goldens` (las imágenes del Mac **no** se suben).
  2. Para actualizarlos: poner la etiqueta `actualizar-goldens` en la PR → el workflow `Goldens` los genera en Linux y los deja como artefacto → se descargan (`gh run download <id> -n goldens -D app/test/goldens/goldens`), se revisan y se suben en un commit.
  3. Si un golden falla en CI, el artefacto `goldens-diferencias` contiene las imágenes con la diferencia.
  4. Los tests de pantalla cargan las fuentes reales (`test/support/fonts.dart`) y usan un color de nota con semilla fija.
- **Tests inestables:** se ponen en cuarentena con un issue enlazado; nunca se ignoran en silencio.

## En CI (ver `.github/workflows/ci.yml`)

`format` → `analyze` → `unit+widget+golden` → `migrations` → `l10n/tokens` → `build web` / `build apk (debug)` / `build ios (no-codesign)` → `integration (android emulator)` (en `main` y de forma nocturna para no alargar las PR).

## Pruebas en el móvil del propietario (lecciones aprendidas)

- Las pruebas de integración se instalan como apps aparte: `invalid.pending.app.debug` (debug) e `invalid.pending.app.profile` (profile). Solo esas pueden borrar su base de datos (las pruebas lo comprueban).
- **`flutter drive` desinstala al terminar el paquete *base* (`invalid.pending.app`), no el que ha instalado**: el 2026-09-25 borró así la app real del propietario y sus tareas de prueba. En el móvil del propietario se usa **siempre** `--keep-app-running` y después se desinstala a mano solo `invalid.pending.app.profile`.
- No se maneja el móvil por `adb` mientras el propietario lo está usando.

