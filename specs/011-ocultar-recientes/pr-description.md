# PR: spec 011, ocultar el contenido en "Recientes"

**Título:** `feat(011): hide app content in Recents without blocking screenshots`

## Resumen

La lista de aplicaciones recientes del sistema ("Recientes") enseñaba la última pantalla de la app tal cual: el texto de una tarea, una imagen, un PDF o una página web. Esta PR hace que la tarjeta **no enseñe nada del contenido** y que las **capturas y grabaciones con la app delante sigan saliendo con contenido** (decisión del propietario, 2026-09-30). Cierra la amenaza T-2 del modelo de amenazas en Android 13+ y las CL-007-11, CL-008-13 y CL-009-10.

- **Estado de la spec:** **Implementada parcialmente.** Falta **PD-10 / T-011-09**: verificar el mecanismo de Android 8-12 en emuladores de Android 8 (API 26) y 12L (API 32), antes de dar la beta a testers.
- Spec, plan y tareas: `specs/011-ocultar-recientes/`. Decisión: `docs/adr/0019-ocultar-recientes-sin-bloquear-capturas.md`.

## Qué cambia

- **Nativo (Kotlin), nada de Dart:** `RecentsPrivacy.kt` (nuevo, 38 líneas) y tres llamadas en `MainActivity.kt` (`onCreate`, `onPause`, `onResume`).
  - **Android 13+ (mecanismo A):** `setRecentsScreenshotEnabled(false)` una vez, al crear la actividad. No toca la ventana.
  - **Android 8-12 (mecanismo B):** `FLAG_SECURE` solo mientras la actividad está en pausa; se quita al volver. **[Suposición]** sin verificar hasta PD-10.
  - Nunca `FLAG_SECURE` fija.
- **Sin** canal, ajuste, pantalla, textos (ARB intactos), esquema de BD, permisos, red, archivos ni dependencias (CA-011-06). Sin pantalla de Configuración en la beta, así que no hay interruptor.
- **Herramientas:** `tools/check-recents.sh` (verificación con `adb` en el emulador: `capture`, `compare`, `secure`, `loop`, `record`); patrones de capturas sueltas en `.gitignore`.
- **Test:** `test/app/home_router_test.dart`, `'CA-011-03: …'` (reloj inyectado a 9:59 y 10:00).
- **Documentación:** ADR-0019, `threat-model.md` T-2, `security/checklist.md` (sección "Recientes"), `architecture.md`, `testing.md`, `perf/baseline.md`, `PLAN.md`, `CLAUDE.md`, la skill `/release-checklist`, CL de las specs 007, 008 y 009 y §8 de la 010.
- **Nota para quien revise:** la rama contiene también el commit `9e215b3` (spec 012 y borrador de la política de privacidad, solo documentación), que no es de la 011; el propietario decidió (2026-09-30) que va dentro de esta PR.

## Verificación

Detalle, cifras y capturas: `specs/011-ocultar-recientes/dispositivo.md` (§7.4 tiene la tabla CA → prueba completa).

| Criterio | Resultado | Entorno |
|---|---|---|
| CA-011-01 y CA-011-02 | Tarjeta en blanco e idéntica con dos tareas distintas, en las 14 filas de la matriz (incluida la web) | Emulador Android 16 (API 37), `tools/check-recents.sh`; **Xiaomi 15T Pro (HyperOS)**: el lanzador respeta la señal, tarjeta en blanco |
| CA-011-03 | 0 fotogramas negros o de otro color; un blanco liso al volver (0,4-1,25 s con el emulador cargado; 0,01-0,12 s en reposo y en modo oscuro). Test con el reloj a 9:59 y 10:00 | Emulador API 37 (`screenrecord` a mp4) y `flutter test` |
| CA-011-04 | Capturas y grabaciones con contenido (arranque en frío, tras "Recientes", icono, cámara y selector; captura del sistema) | Emulador API 37; Xiaomi con `screencap` de `adb` |
| CA-011-05 | p50 de arranque 385 ms (línea base) frente a 386 ms; dentro de la diferencia entre las líneas base | Emulador API 37, n = 20, cuatro pasadas alternadas (solo compara) |
| CA-011-06 | Permisos idénticos a `main`; sin cambios en `pubspec*`, `drift_schemas/` ni `schemaVersion`; sin archivos nuevos | `check-android-permissions.sh`, `aapt2`, `git diff`, `run-as` |
| CA-011-07 | `flutter test` +1207 ~49 en verde, `flutter build web` correcto | Local |
| CA-011-08 | 10 de 10 (básico y cámara); selector de fotos: captura con contenido y tarjeta como antes de la 011 (excepción aceptada) | Emulador API 37; Xiaomi: básico 10 de 10 |

Comprobaciones locales: `dart format` (277 archivos, 0 cambios), `flutter analyze --fatal-infos` sin incidencias, `flutter test` +1207 ~49, `node tools/validate-tokens.mjs` en verde. `/security-check` sin hallazgos que fallen y `/i18n-check` confirma que no hay textos nuevos. Revisiones de `security-reviewer` y `a11y-reviewer`: 0 hallazgos altos.

**Sin test de CI** para el efecto en "Recientes" (decisión del propietario, plan §8): lo dibuja el sistema fuera de la app. Se compensa con la comprobación de `tools/check-recents.sh` antes de cada entrega a testers (`docs/security/checklist.md`, `/release-checklist`).

## Límites aceptados por el propietario (2026-09-30)

Se anotarán en las notas de la beta y se revisan antes de la v1.0.

- **Fotograma blanco al volver a la app** tras haberse ido de verdad (tarjeta, icono u otra app): lo pinta el sistema al no haber instantánea. Igual en modo claro y oscuro. (CA-011-03)
- **"Recientes" abierto directamente desde la app** y **gesto de cambio rápido entre apps**: el sistema enseña la ventana en vivo y la actividad no llega a pausarse. (CL-011-14, CL-011-6)
- **Hoja parcial del selector de fotos**: la tarjeta enseña lo que queda a la vista de la app, igual que antes de la 011. (CL-011-15)
- **Arranque en frío en modo oscuro**: negro ≈ 0,5 s, igual que antes de la 011; no cuenta para CA-011-03 y se aplaza a F5 junto a `paper` en `launch_background`.
- Tras actualizar desde una versión anterior, la miniatura antigua puede seguir hasta la próxima vez que la app pase a segundo plano (CL-011-1).

## Pendiente

- **PD-10 / T-011-09 (antes de la beta a testers):** emuladores de Android 8 y 12L; repetir la matriz, CL-011-4 y CL-011-5. Si el mecanismo B no oculta la miniatura, se aplica la regla de desempate (miniatura visible en 8-12 en la beta) y **se retira B** (ADR-0019). Entonces la spec pasa a **Implementada**.
- **Xiaomi, sin hacer:** duración del blanco al volver, captura y grabación del propio sistema, cámara y selector (CL-011-3, CL-011-15) y CL-011-14; cifra real de P2.
- **F5 (auditoría):** lupa del sistema (no activable por `adb`), TalkBack al volver a la app y en español y en HyperOS, Switch Access y teclado, arranque en negro en modo oscuro, TD-2 (pantalla en negro tras un WebView en el emulador; se reproduce sin la 011).
- Menú de apagado (CL-011-4): no verificado.
- Fila de la spec 012 en la matriz de CA-011-02: cuando la 012 esté implementada.

## Cómo probar

Solo en el **emulador** (nunca en un móvil sin permiso del propietario). Desde la raíz del repo:

```bash
cd app && flutter build apk --release --target-platform android-arm64 && cd ..
adb -s emulator-5554 install -r app/build/app/outputs/flutter-apk/app-release.apk
S=emulator-5554; D=$(mktemp -d)
# Con la tarea "uno" delante:
tools/check-recents.sh $S capture uno $D
# Cambiar a la tarea "dos" y repetir:
tools/check-recents.sh $S capture dos $D
tools/check-recents.sh $S compare uno dos $D   # CA-011-01
tools/check-recents.sh $S secure               # CA-011-04: sin FLAG_SECURE con la app delante
tools/check-recents.sh $S loop 10              # CA-011-08
tools/check-recents.sh $S record 10            # CA-011-03
```

A mano: abrir la app con una tarea con texto, ir al escritorio y abrir "Recientes": la tarjeta debe verse en blanco, sin contenido; tocarla y volver; hacer una captura de pantalla: debe salir con contenido. Guía completa en `specs/011-ocultar-recientes/dispositivo.md` y `docs/testing.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
