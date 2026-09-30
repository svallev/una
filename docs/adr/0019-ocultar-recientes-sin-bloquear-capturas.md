# ADR-0019: Ocultar "Recientes" sin bloquear las capturas

- **Estado:** Aceptado (propietario, 2026-09-30). **Provisional** en la parte de Android 8–12 (mecanismo B) hasta PD-10
- **Fecha:** 2026-09-30
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 011 (CA-011-01, 03, 04, 08; CL-011-3, 6, 13, 14, 15; plan §1, §7 y §8), CL-007-11, CL-008-13 y CL-009-10 (que cierra), modelo de amenazas T-2, P2, P4 y P5, PD-10 y riesgos R-1 a R-6 del plan de la 011

## Contexto

- **[Hecho]** Hasta la spec 011, "Recientes" (la lista de aplicaciones recientes del sistema, ver `docs/glossary.md`) enseñaba la última pantalla de la app tal cual: el texto de la tarea, la imagen, el PDF o la página web (`dispositivo.md` §1). Quien viera el móvil de pasada podía leer las tareas de otra persona (amenaza T-2).
- **[Hecho]** Decisión del propietario (2026-09-30): **ocultar siempre**, no solo con adjunto, y **sin bloquear las capturas de pantalla ni las grabaciones** de la propia app cuando se está usando (CA-011-04). Si en Android 8–12 no se pueden tener las dos cosas, **gana la captura** (regla de desempate de la spec, opción b: se acepta la miniatura visible solo en 8–12 durante la beta y se revisa antes de la v1.0).
- **[Hecho]** `FLAG_SECURE` en la ventana oculta el contenido en "Recientes" pero también hace que las capturas y grabaciones salgan en negro (documentación de Android, "Set FLAG_SECURE Window Flag"). Por eso no vale puesto siempre.
- **[Hecho, API 37]** Medido en T-011-01 y T-011-03 (`specs/011-ocultar-recientes/dispositivo.md` §2 y §3): `Activity.setRecentsScreenshotEnabled(false)` (Android 13+) y `FLAG_SECURE` puesto en `onPause` ocultan la instantánea cuando la app se va de verdad a segundo plano; ninguno de los dos deja `FLAG_SECURE` con la app delante ni estropea las capturas.
- **[Suposición]** En Android 8–12 (API 26–32) la instantánea de "Recientes" se toma **después** de `onPause`, por lo que `FLAG_SECURE` puesto ahí llega a tiempo. Es lo que usan varios plugins, pero depende de la versión y del fabricante. **No se ha verificado** (no hay emulador de esas versiones hasta PD-10).
- **[Pendiente]** HyperOS (Xiaomi) usa su propio lanzador y puede tratar la señal a su manera (CL-011-9, T-011-07; solo con permiso del propietario).

## Opciones consideradas

1. **Mecanismo por versión:** A (`setRecentsScreenshotEnabled(false)`) en Android 13+ y B (`FLAG_SECURE` solo mientras la actividad está en pausa) en Android 8–12.
2. **`FLAG_SECURE` fija en todas las versiones** (plan §7, Alt. 1).
3. **Pantalla de bloqueo propia:** tapar el contenido con Flutter al pasar a segundo plano (Alt. 2).
4. **`excludeFromRecents`:** quitar la tarjeta entera (Alt. 3).
5. **B también en Android 13+** (alternativa preparada en R-2 por si A dejaba ver la pantalla de arranque; no hizo falta).

## Decisión

**Opción 1** (propietario, 2026-09-30), toda en código nativo (`RecentsPrivacy.kt`, llamado desde `MainActivity` en `onCreate`, `onPause` y `onResume`), sin Dart, canal, ajuste, esquema, permisos ni dependencias:

- **Android 13+ (`SDK_INT >= 33`), mecanismo A:** `setRecentsScreenshotEnabled(false)` una sola vez, al crear la actividad. No toca la ventana.
- **Android 8–12 (`SDK_INT < 33`), mecanismo B:** `FLAG_SECURE` puesto en `onPause` y quitado en `onResume`. **[Suposición]** sin verificar hasta PD-10; si no oculta la miniatura, se aplica la regla de desempate (miniatura visible en 8–12 durante la beta) y este ADR se revisa.
- **Nunca `FLAG_SECURE` fija**: con la app delante la ventana no lleva la marca y las capturas y grabaciones salen con contenido.
- **Verificación con `adb` (`tools/check-recents.sh`) y no con CI** (plan §8, decisión del propietario): el efecto es lo que dibuja el sistema fuera de la app, que no se ve desde `flutter test`, y probar Kotlin exigiría JUnit y Robolectric (dependencias de prueba, P11) que solo comprobarían las llamadas. Se compensa con la comprobación obligatoria antes de cada versión entregada a testers (CL-011-13, R-3).

## Motivos

- **P4 y P5 sin coste para el usuario:** nadie lee las tareas de pasada y la app se sigue usando, capturando y reabriendo igual (HU-011-1 a 3).
- **Las capturas mandan** (propietario): la opción 2 bloquearía las capturas y grabaciones del propio usuario en todas las versiones (rechazada, CA-011-04).
- **La opción 3 llega tarde:** la miniatura se hace antes de que Flutter pueda repintar y añade estado a la interfaz (rechazada).
- **La opción 4 cambia cómo se vuelve a la app:** quita la tarjeta entera y rompe CA-001-12 y P2 (rechazada).
- **A es la petición explícita al sistema** de que no haga la miniatura y no toca la ventana; B es el único medio disponible por debajo de Android 13.
- **P2:** una llamada en `onCreate` (A) o un `addFlags`/`clearFlags` en `onPause`/`onResume` (B); sin trabajo antes del primer fotograma. **[Hecho, API 37, emulador]** p50 385 ms frente a 386 ms de la línea base (`docs/perf/baseline.md`); **[Pendiente]** la cifra real en el Xiaomi.

## Consecuencias

- **Positivas:** T-2 se cierra en Android 13+ (verificado en API 37): la tarjeta es blanca, idéntica con dos tareas distintas, y la lee TalkBack solo con el nombre de la app. Sin permisos, red, datos, archivos ni dependencias nuevos (CA-011-06).
- **Aceptadas por el propietario (2026-09-30), con la spec enmendada:**
  - **Fotograma blanco al volver a la app** tras haberse ido de verdad, por cualquier vía (tarjeta de "Recientes", icono u otra app), porque no hay instantánea y el sistema pinta el `windowBackground` del `LaunchTheme` (CA-011-03). **[Hecho, API 37]** 0,4–1,25 s en el emulador (inflado por la grabación), 0 fotogramas negros o de otro color. No se cambia el fondo de arranque. Si fuera negro, de otro color o durara claramente más, se para y se pregunta; se revisa antes de la v1.0.
  - **Abrir "Recientes" directamente desde la app** (CL-011-14) y el **gesto de cambio rápido entre apps** (CL-011-6): el sistema enseña la ventana en vivo de la app y la actividad no llega a pausarse, así que ningún mecanismo puede actuar. Fuera de CA-011-01. **[Hecho, API 37]**; **[Suposición]** igual en Android 13–16.
  - **Hoja parcial del selector de fotos** (CL-011-15): corre en la misma tarea y no oculta su instantánea; la tarjeta enseña lo que queda a la vista de la app junto a la hoja. **[Hecho, API 37]** idéntico a antes de la 011, no peor. Fuera de CA-011-01 en ese caso.
  - Los tres límites se anotan en las notas de la beta y se pueden revisar antes de la v1.0.
- **Negativas y riesgos:**
  - **R-1 / PD-10:** en Android 8–12 (mecanismo B) puede no ocultar la miniatura o parpadear; hasta PD-10 no se da por verificado y la spec no pasa a "Implementada" del todo. Mitigación: regla de desempate (miniatura visible en 8–12 en la beta).
  - **R-3:** sin test de CI, una actualización de Flutter o de Android podría quitar el efecto sin que salte nada. Mitigación: `tools/check-recents.sh` antes de cada entrega a testers (`docs/security/checklist.md`, `docs/testing.md`).
  - **R-5:** HyperOS puede ignorar ambos mecanismos (CL-011-9). Se comprueba en el Xiaomi solo con permiso del propietario; si falla, se para y se pregunta.
  - Otras superficies que leen la pantalla (asistente, "buscar lo que hay en pantalla", casting, terceros) quedan fuera de alcance (CL-011-8).
  - CL-011-1: tras actualizar desde una versión anterior, la miniatura antigua puede seguir hasta la próxima vez que la app pase a segundo plano. **[Hecho, API 37]** confirmado; se anota en las notas del primer envío.
- **Qué dispararía revisar este ADR:** que B falle en API 26–32 (PD-10); que un cambio de Android o de Flutter quite el efecto de A; que HyperOS lo ignore; una futura pantalla de Configuración con un interruptor de ocultado (fuera de alcance hoy); iOS (D17), que necesitaría otro mecanismo.
