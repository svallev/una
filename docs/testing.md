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
| **Sistema fuera de la app ("Recientes")** | Que la tarjeta de "Recientes" no enseñe contenido y que las capturas con la app delante salgan con él (spec 011). No se ve desde `flutter test` | `tools/check-recents.sh` con `adb` (ver más abajo) | Emulador, en local, antes de cada entrega a testers; **no está en CI** (plan de la 011 §8) |
| **Manual de accesibilidad** | VoiceOver, TalkBack, Switch Control/Access, teclado, texto al 200 %, reducir movimiento | Checklist en la PR | Antes de cerrar cada spec y en F5 |

## Reglas

- **Relojes y tiempos:** todo lo temporal (mantener 1,2 s, máquina de escribir) usa un `Clock` inyectable; en los tests, `fakeAsync`.
- **Sin red en los tests:** `HttpOverrides` que falla ante cualquier conexión (salvo los tests de URL, que usan un servidor local).
- **Datos de prueba:** *fixtures* en `app/test/fixtures/` (imágenes con EXIF, PDF variados, documentos, BD de versiones anteriores).
- **Cobertura:** objetivo ≥ 90 % en `domain/`, ≥ 70 % global. La cobertura es un indicador, no un fin; los criterios de aceptación cubiertos son lo que cuenta.
- **Goldens:** solo se regeneran de forma explícita y la PR muestra el antes y el después. **[Hecho]** El texto se dibuja distinto en macOS y en Linux, así que los goldens (`app/test/goldens/`, etiqueta `golden`) **se generan y se comparan solo en Linux**:
  1. En local se omiten. Para revisarlos sin subirlos: `GOLDENS_ANY_OS=1 flutter test --update-goldens test/goldens` (las imágenes del Mac **no** se suben).
  2. Para actualizarlos: poner la etiqueta `actualizar-goldens` en la PR → el workflow `Goldens` los genera en Linux y los deja como artefacto → se descargan (`gh run download <id> -n goldens -D app/test/goldens/goldens`), se revisan y se suben en un commit.
  2b. **[Hecho]** El contenedor Linux de Claude Code en la nube, con la versión de Flutter de `.fvmrc`, dibuja igual que CI (los 28 goldens de las specs 001–006 pasan ahí píxel a píxel, 2026-09-27). Ahí se pueden generar directamente con `flutter test --update-goldens --tags golden`, tras comprobar que los existentes pasan sin cambios.
  3. Si un golden falla en CI, el artefacto `goldens-diferencias` contiene las imágenes con la diferencia.
  4. Los tests de pantalla cargan las fuentes reales (`test/support/fonts.dart`) y usan un color de nota con semilla fija.
- **Tests inestables:** se ponen en cuarentena con un issue enlazado; nunca se ignoran en silencio.

## En CI (ver `.github/workflows/ci.yml`)

`format` → `analyze` → `unit+widget+golden` → `migrations` → `l10n/tokens` → `build web` / `build apk (debug)` / `build ios (no-codesign)` → `integration (android emulator)` (en `main` y de forma nocturna para no alargar las PR).

## Verificación con `adb`: "Recientes" (spec 011, ADR-0019)

Lo que dibuja el sistema fuera de la app (la tarjeta de "Recientes") no se ve desde `flutter test` y probar el Kotlin exigiría dependencias de prueba (P11), así que la spec 011 se verifica con `tools/check-recents.sh` sobre un emulador. **Se ejecuta a mano antes de cada versión entregada a testers** (CL-011-13; `docs/security/checklist.md`). Guía, resultados y capturas: `specs/011-ocultar-recientes/dispositivo.md`.

```bash
S=emulator-5554   # el serial es OBLIGATORIO; sin él el script no hace nada
tools/check-recents.sh $S capture uno /tmp/x      # con la tarea A ("uno") delante
tools/check-recents.sh $S capture dos /tmp/x      # con la tarea B ("dos")
tools/check-recents.sh $S compare uno dos /tmp/x  # CA-011-01: sin contenido y A = B
tools/check-recents.sh $S secure                  # CA-011-04: sin FLAG_SECURE con la app delante
tools/check-recents.sh $S loop 10 /tmp/x          # CA-011-08: 10 vueltas
tools/check-recents.sh $S record 10 /tmp/x        # CA-011-03: parpadeo
```

- **Serial obligatorio y sin dispositivos físicos por defecto:** con dos dispositivos conectados `adb` falla y nunca se debe tocar el móvil del propietario. Un serial que no empieza por `emulator-` exige `ALLOW_PHYSICAL=1`, que **solo se pone con permiso explícito del propietario** (y las capturas de un móvil real son privadas). `PKG` cambia el paquete (por defecto `invalid.pending.app`; la compilación debug es `invalid.pending.app.debug`).
- **`RECENTS_WAIT=<segundos>`** (por defecto 2,5): espera tras abrir "Recientes". Con una imagen o un PDF el lanzador tarda más en pintar la tarjeta y la captura puede salir sin ella; el script lo detecta y falla en vez de dar un falso "pasa". En el emulador bastan 4 s.
- **Ruta por defecto:** el script pasa antes por el escritorio (`KEYCODE_HOME` y luego `KEYCODE_APP_SWITCH`), que es la ruta de CA-011-01. **`VIA=direct`** abre "Recientes" desde la propia app: esa ruta queda fuera del criterio (CL-011-14, la tarjeta enseña la ventana en vivo), así que el script **solo informa** y no falla.
- **Blanco al volver:** `record` cuenta el fotograma liso **blanco** al volver como excepción aceptada (`blancos_aceptados`, CA-011-03); cualquier otro fotograma liso (negro…) o que la app desaparezca tras verse es fallo. No mide duraciones (`screenrecord` en bruto no da tiempos): las de `dispositivo.md` §3 salen de un mp4.
- **Salida:** 0 todo bien; 1 un criterio falla; 2 uso incorrecto. Requiere `adb` (variable `ADB`, `PATH` o el SDK en `~/Library/Android/sdk`) y `python3` con Pillow y numpy (solo herramienta local, no una dependencia del proyecto).
- **Emuladores:** ahora solo hay Android 16 (API 37). Android 8 (API 26) y 12L (API 32) están aplazados a PD-10 (antes de dar la beta a testers): hasta entonces, lo que dependa del mecanismo B (Android 8–12) **no está verificado**. El ciclo de vida de `RecentsPrivacy` no tiene test de Dart (no hay Dart).
- Las capturas son de la app con datos de prueba ("uno" y "dos"): no se guardan con datos reales ni en el repositorio.

## Pruebas en el móvil del propietario (lecciones aprendidas)

- Las pruebas de integración se instalan como apps aparte: `invalid.pending.app.debug` (debug) e `invalid.pending.app.profile` (profile). Solo esas pueden borrar su base de datos (las pruebas lo comprueban).
- **`flutter drive` desinstala al terminar el paquete *base* (`invalid.pending.app`), no el que ha instalado**: el 2026-09-25 borró así la app real del propietario y sus tareas de prueba. En el móvil del propietario se usa **siempre** `--keep-app-running` y después se desinstala a mano solo `invalid.pending.app.profile`.
- No se maneja el móvil por `adb` mientras el propietario lo está usando.

