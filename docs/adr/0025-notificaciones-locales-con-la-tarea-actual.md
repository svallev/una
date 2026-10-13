# ADR-0025: Notificaciones locales con la tarea actual: código nativo propio, alarmas inexactas, tarea leída de la BD al llegar la hora y versión genérica de respaldo

- **Estado:** **Aceptado** (propietario, 2026-10-12, con la spec 019). Incluye una **excepción a P4/T-2** (el texto de la tarea sale a la bandeja de notificaciones) y **enmienda el ADR-0005** (su última viñeta).
- **Fecha:** 2026-10-12
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 019 (CA-019-10 a 25 y 30) y spike **S7** (`docs/spikes/S7-notificaciones-resultados.md`); constitución P2, P3, P4, P5, P6 y P11; D25 y R-23 en `docs/PLAN.md`; ADR-0005 (enmendado), ADR-0004 (copias de seguridad), ADR-0012 y ADR-0021 (completar y eliminar borran del todo), ADR-0020 y ADR-0023 (voz del sistema); `docs/security/threat-model.md` (T-2, T-7, T-8).

## Contexto

- **[Hecho]** El propietario quiere que la app envíe 1, 2 o 3 notificaciones al día (08:55, 13:55, 18:55) con la **tarea actual**, sin servidor y sin conexión (D25). Hoy el ADR-0005 dice «nada de … notificaciones con contenido» y T-2 prometía «notificaciones futuras sin contenido por defecto».
- **[Hecho]** La spec 019 exige: la tarea **al llegar la hora**, no la de cuando se programó (CA-019-16); **ninguna copia del texto fuera de la BD** (CA-019-23); funcionar con la app cerrada y tras reiniciar, cambiar la hora o actualizar la app (CA-019-13); arranque sin degradar (CA-019-24); sin alarmas exactas (CA-019-11); sin dependencias con red (CA-019-25).
- **[Hecho, S7, 2026-10-11 y 12; emulador de API 37 y Xiaomi 15T Pro con HyperOS 3]**
  - Una alarma inexacta con ventana llega con la **app cerrada** y el receptor puede abrir la BD y leer la tarea (SQLite de Android, sin Flutter). El sistema fija una **ventana mínima de 10 min**; retrasos medidos de 16 s a 600 s en el Xiaomi; en el emulador con reposo profundo forzado, **`setAndAllowWhileIdle`** llegó en 17 s y 77 s. `setWindow` **no** se midió con reposo profundo.
  - Las alarmas **no sobreviven a un reinicio**. `LOCKED_BOOT_COMPLETED` llega **antes del primer desbloqueo** a un receptor marcado `directBootAware`, que reprograma desde el almacenamiento «device protected»; `BOOT_COMPLETED` llega al desbloquear. También llegan `TIME_SET`, `TIMEZONE_CHANGED` y `MY_PACKAGE_REPLACED`.
  - Antes del primer desbloqueo la alarma **dispara** y la notificación **se puede mostrar**, pero **la BD no se puede abrir** (`SQLITE_CANTOPEN`).
  - Con bloqueo seguro y la preferencia de contenido sensible por defecto, la pantalla de bloqueo **enseña la notificación completa** (emulador y Xiaomi); solo con el contenido sensible oculto se ve la versión pública. La app no puede forzarlo.
  - `LocaleSpan` funciona con TalkBack: con el sistema en español, texto marcado como inglés se lee con voz inglesa.
  - El ahorro de batería «Restringir» de HyperOS **retiene todas las alarmas** hasta que se levanta. El «Inicio automático» de HyperOS (denegado por defecto a las apps instaladas por USB) no impidió nada.
  - El estado de importancia del proceso que ve el receptor no distingue «app a la vista».
- **[Hecho, consulta a Context7 el 2026-10-12 sobre `developer.android.com`]** `android:directBootAware` en un `<receiver>` permite que se ejecute antes del desbloqueo y, en Direct Boot, **solo puede acceder al almacenamiento «device protected»**. Las consultas sobre `AlarmManager` y Doze no devolvieron la referencia útil; esas partes se apoyan en las medidas de S7.
- **[Hecho]** La app ya tiene un canal nativo (`una/a11y`) y código Kotlin propio sin dependencias (`RecentsPrivacy.kt`). La BD de la app es SQLite (drift) **sin cifrado propio** (ADR-0005), con la tarea actual como la primera fila por `rank` y sus adjuntos en otra tabla (esquema v3).
- **[Suposición]** Los datos que necesita el receptor para decidir la etiqueta (texto, tipo del adjunto, dirección guardada) se pueden leer con una consulta de solo lectura sin abrir el motor de Flutter.
- **[Hecho, medición C-1 del plan, 2026-10-12, Xiaomi 15T Pro con HyperOS 3]** `setAndAllowWhileIdle` **y** `setWindow` se entregan igual de mal con la pantalla apagada más de ~30 min: las alarmas esperan a que se encienda la pantalla (retrasos de 10 a 100 min, con el móvil cargando y la app fuera de Recientes). La gestión de energía de HyperOS las retiene; `dumpsys alarm` no muestra ninguna política de Android que lo explique. **El propietario lo acepta (opción A, 2026-10-12)**; se descartaron las alarmas exactas y `setAlarmClock`. Se mantiene `setAndAllowWhileIdle` (en Android sin gestión propia del fabricante entrega con reposo profundo; con alarmas lejanas el sistema limita su ventana a 1 h).

## Opciones consideradas

1. **Código nativo propio (Kotlin), sin dependencias:** un programador con `AlarmManager` inexacto, receptores nativos, lectura de solo lectura de la BD al llegar la hora, notificación construida allí, y un canal para que Dart encienda, apague y pida el permiso.
2. **`flutter_local_notifications` (con zonas horarias):** las notificaciones se programan desde Dart con su título y texto ya calculados.
3. **WorkManager o un aislado de Dart en segundo plano** que calcule y muestre la notificación al llegar la hora.
4. **Alarmas exactas** (`SCHEDULE_EXACT_ALARM` o `USE_EXACT_ALARM`) con la opción 1 o la 2.

## Decisión

**Opción 1.** El programador y los receptores son **código nativo propio**; las alarmas son **inexactas** (`setAndAllowWhileIdle`, o `setWindow` si el plan demuestra en dispositivo que también se entrega con reposo profundo); al llegar la hora el receptor lee la tarea actual de la BD **en solo lectura**, construye la etiqueta de CA-019-16 y muestra **una sola notificación** (identificador fijo, un único canal de importancia por defecto, sin acciones ni insignia) con la **versión completa** y la **genérica** como versión pública. Si la BD no se puede leer (antes del primer desbloqueo) se muestra **solo la genérica** (CA-019-30). La configuración que el receptor necesita (interruptor, cantidad, última hora atendida, indicador de «a la vista») vive en el almacenamiento **«device protected»** y **nunca incluye texto de tareas**; los receptores de arranque, de reloj y de actualización son `directBootAware` y no están exportados (son difusiones protegidas del sistema). Esa configuración es una **copia derivada** de los ajustes de la BD (la BD manda; se reescribe en cada cambio y arranque, es entrada no fiable, queda fuera de la copia de seguridad) e incluye también el **idioma elegido**, para poder mostrar la versión genérica en el idioma correcto antes del primer desbloqueo. La «última hora atendida» avanza al mostrar, al saltar a propósito y al encender, apagar o cambiar la cantidad; solo se recupera tras un reinicio del móvil o una parada del proceso, nunca por un cambio de hora o de huso (CA-019-14). El indicador «a la vista» caduca (CA-019-19a). El nombre y la descripción del canal van en el idioma del sistema. Se revisa si S7 o la 022 muestran que la lectura nativa de la BD es frágil (p. ej. un esquema que cambie a menudo) o si Google Play o Android endurecen las alarmas inexactas.

## Motivos

Criterios (peso): privacidad —ninguna copia del texto fuera de la BD— (3), fiabilidad medida en S7 (3), permisos y dependencias (3), simplicidad (1). Puntuación de 1 a 5.

| Opción | Privacidad ×3 | Fiabilidad ×3 | Permisos y dependencias ×3 | Simplicidad ×1 | Total |
|---|---|---|---|---|---|
| 1. Nativo propio, inexactas | 5 → 15 | 4 → 12 | 5 → 15 | 3 → 3 | **45** |
| 2. `flutter_local_notifications` | 1 → 3 | 4 → 12 | 2 → 6 | 4 → 4 | **25** |
| 3. WorkManager / aislado de Dart | 4 → 12 | 2 → 6 | 3 → 9 | 2 → 2 | **29** |
| 4. Alarmas exactas | 5 → 15 | 5 → 15 | 1 → 3 | 4 → 4 | **37** |

- **Opción 1:** es la única que lee la tarea **al llegar la hora** sin copiarla en ningún sitio y que cumple a la vez sin dependencias ni permisos nuevos más que el de notificaciones y el de reprogramar al arrancar. S7 la midió entera con un código desechable de este tamaño (alarma, receptor, lectura, notificación, reprogramación).
- **Opción 2:** programa título y texto **al programar**; eso guarda el texto de la tarea en la programación del sistema (en contra de CA-019-23) y deja una tarea vieja si cambia el orden (CA-019-16). Añade una dependencia grande y una de zonas horarias.
- **Opción 3:** un aislado de Dart antes del primer desbloqueo y con el proceso muerto es lo menos fiable; WorkManager no garantiza la hora y añade una dependencia.
- **Opción 4:** la V1 no necesita la precisión, y el permiso de alarmas exactas lo restringe Google Play y lo ve el usuario (CA-019-11).

## Consecuencias

- **Criterio de revisión de la voz:** la marca de idioma se probó con un lector y un dispositivo (S7). Si la 022 u otro lector (Samsung Voice Assistant, TalkBack de Android 8 a 12, voz del otro idioma sin instalar) no la respeta, la notificación pasa a ser una excepción nueva de P6 (una versión nueva de la constitución) o se descarta el cambio de idioma de la notificación.
- **Positivas:**
  - Sin dependencias nuevas, sin red, sin esquema nuevo (dos claves de ajustes, CA-019-05).
  - El texto de la tarea solo está en la BD y, mientras dure, en la bandeja (CA-019-23).
  - Funciona con la app cerrada, tras reiniciar y antes del primer desbloqueo.
  - La voz del idioma de la notificación se resuelve con `LocaleSpan` (S7): **no hace falta ampliar la excepción de voz ni subir la constitución** (CA-019-21).
- **Negativas y mitigación:**
  - **En HyperOS, con la pantalla apagada mucho rato, las notificaciones llegan al encender la pantalla** (medido en C-1; aceptado). Mitigaciones: se entrega siempre (nunca se pierde por esto), solo se muestra la hora más reciente (CA-019-14) y se explica en la ayuda web. Si Google Play o los fabricantes cambian la política, o si los testers lo viven como un fallo, se reabre con la opción de las alarmas exactas.
  - **La pantalla de bloqueo enseña la tarea con los ajustes por defecto.** Es la excepción a T-2 que se acepta: el usuario la elige al encender (apagado por defecto), la app le avisa **antes de decidir** con una línea siempre a la vista bajo la fila (CA-019-29, aceptada por el propietario en Q-019-6, 2026-10-12) y pide al sistema la versión genérica, que se ve si oculta el contenido sensible. Residuales: relojes enlazados, apps con acceso a notificaciones, historial de notificaciones.
  - **Conocimiento duplicado en Kotlin** (qué es «la tarea actual» y su etiqueta) respecto al dominio en Dart. Mitigación: la consulta es mínima (primera fila por `rank` y el tipo de su adjunto); el plan añade una **prueba de contrato** que lee con el código nativo una BD generada por las migraciones de la app, y cualquier cambio de esquema que toque esa consulta la rompe en CI.
  - **Alarmas inexactas con ventana mínima de 10 min:** hay retraso (hasta 15 min, W de CA-019-11). Aceptado; la hora «fija» es la de la ayuda.
  - **Reinicio:** las alarmas se pierden. Mitigación: reprogramar al arrancar el sistema (antes del desbloqueo), al cambiar la hora o el huso, al actualizar y al arrancar la app, más una «última hora atendida» para recuperar la perdida (CA-019-14).
  - **«Restringir» de HyperOS y la parada forzada** impiden las notificaciones: no se pueden evitar ni detectar con seguridad. Se explican en la ayuda web (D26), no en la app.
  - **Antes del primer desbloqueo** no se puede saber si hay tareas: se avisa de más con la versión genérica (CA-019-30).
  - **Permisos nuevos en el manifiesto:** `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED`; ninguno para alarmas exactas. Hay que actualizar `tools/check-android-permissions.sh` y la puerta de la 020.
  - **Con el permiso de notificaciones revocado después, el ajuste guardado se queda encendido** y vuelve a verse encendido al permitirlas, sin que el usuario lo toque (Q-019-2): se acepta, y el anuncio lo dice (CA-019-09).
  - **Tocar la notificación pierde un borrador sin guardar** (Q-019-3) y la orden de abrir puede lanzarla otra app: residual de T-8 aceptado, acotable en el plan (CA-019-20).
  - **iOS** (D17) no está cubierto: el programador será otro código cuando se haga.
  - **Dos copias de SQLite en el mismo proceso** (residual de P-019-12, **decidido por el propietario el 2026-10-12, opción (b)**): el receptor lee la BD con el SQLite del sistema (`android.database.sqlite`) y Drift usa su propia copia (`sqlite3`, descargada al compilar). SQLite advierte de que dos copias en un proceso pueden soltarse los bloqueos entre sí; con un solo proceso, un solo escritor y una lectura de solo lectura (`OPEN_READONLY`, `PRAGMA query_only`, plazo de 3 s) el daño es improbable pero no está descartado (una lectura inconsistente). Mitigación: cualquier fallo de lectura se trata como «ilegible» y sale la versión genérica; la consulta está acotada en SQL. **[Hecho, T-019-14]** prueba de estrés en el emulador de API 37 (10 ráfagas de 5 escrituras con la alarma saltando a 0-6 s, compilación de depuración con el mismo código): ninguna lectura fallida y `PRAGMA integrity_check` = `ok` (`specs/019-notificaciones/dispositivo.md`). **Límite:** no se ejercitó el caso de la misma décima de segundo. **Marcha atrás si volviera a aparecer:** la opción (a) del plan, un indicador «motor de Flutter vivo» que haga que el receptor no abra la BD y muestre la versión genérica (degrada CA-019-16 con la app en segundo plano y el motor vivo). Se anota en `threat-model.md` T-17 y §7.
  - **JUnit 4.13.2 solo en pruebas** (C-2, propietario, 2026-10-12): `testImplementation`, EPL-1.0 (no está en la lista de licencias de `threat-model.md` §5: excepción porque no se distribuye), vigilado en CI por `tools/check-apk-no-test-classes.sh`. Es lo que permite probar el Kotlin real y no una réplica (CA-019-14, 16, 21 y 30).
  - **Medido al implementar (T-019-14 y 15):** arranque en frío sin diferencia fuera de la deriva con el ajuste encendido (emulador: p50 370 frente a 366,5 ms; Xiaomi: 378,8 frente a 371,3 ms) y ≈ 406 ms abriendo desde la notificación; entrega real con la app cerrada (+44 s en el emulador, +21 s en el Xiaomi con el móvil bloqueado); versión genérica de respaldo antes del primer desbloqueo; la pantalla de bloqueo con PIN enseña la completa por defecto y la genérica con el contenido sensible oculto; receptor no exportado inalcanzable desde `adb`. **[Pendiente, 022]** la voz de `LocaleSpan` con otros lectores y Android 8 y 12L.
- **Cambios en otros documentos** (al aceptarlo): ADR-0005 («Enmendado por ADR-0025» en el README y en la última viñeta); `docs/security/threat-model.md` (T-2, T-7, T-8 y la matriz); `docs/security/checklist.md`; constitución P4 (nota de la excepción optativa, **versión 1.10**, hecha al aceptarlo) **sin excepción de P6**; `docs/architecture.md` y `docs/testing.md` al implementar; política de privacidad y Data Safety (`docs/legal/privacy-policy.md`, F6).
- **Riesgos nuevos para `docs/PLAN.md`:** ninguno separado; R-23 pasa a «medido en S7» y se añade a sus mitigaciones la versión genérica de respaldo y la «última hora atendida».
