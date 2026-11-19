# ADR-0030: Notificaciones en iOS: el texto se calcula en Dart y se programa por adelantado

- **Estado:** **Aceptado** (propietario, 2026-11-19: opción A en el plan F-iOS, decisión 4, y Q-028-4 de la spec 028, «ok», con la versión 1.11 de la constitución).
- **Fecha:** 2026-11-19
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 028 (CA-028-15 y 16, Q-028-3 a 5), spec 019 (CA-019-11, 13, 14, 16, 17, 18, 22, 23, 28, 29 y 30); **enmienda la parte iOS del ADR-0025** (su viñeta «iOS (D17) no está cubierto»); ADR-0005 (ya enmendado por el ADR-0025); constitución **P4** (nota de la spec 019); `docs/security/threat-model.md` (T-2, T-17); `docs/ios/channel-contract.md` §4.

## Contexto

- **[Hecho]** En Android, el ADR-0025 eligió que el código nativo lea la tarea actual **de la BD al llegar la hora** para que su texto no se copie fuera de la BD (CA-019-23) y siempre sea la tarea del momento (CA-019-16).
- **[Suposición fuerte, conocimiento previo de la API de Apple]** iOS **no deja ejecutar código de la app cuando llega la hora** de una notificación local: el sistema muestra el contenido que se le dio al programarla. La *Notification Service Extension* solo existe para notificaciones **remotas** (necesitaría servidor, en contra de P3 y P4). `BGAppRefreshTask` no garantiza hora ni que se ejecute.
- **[Suposición, conocimiento previo de la API de Apple; se comprueba en el iPad en I6]** iOS guarda las notificaciones programadas y las mantiene tras reiniciar, cambiar la hora o el huso y actualizar la app; `UNCalendarNotificationTrigger` dispara a la hora local exacta. Con la opción por defecto «Mostrar previsualizaciones: si está desbloqueado», la pantalla de bloqueo no enseña el cuerpo; la app puede dar el texto que se ve en su lugar (`hiddenPreviewsBodyPlaceholder`).
- **[Hecho]** Los textos de la notificación (`notificationTitle`, `notificationPublic`, «Foto», «Imagen», «PDF») ya están en los ARB; la lógica de la etiqueta está en Kotlin (`TaskLabel.kt`, `NotificationText.kt`) con sus pruebas JUnit.
- **[Hecho]** La nota de P4 (constitución 1.10) dice «sin copias del texto fuera de la base de datos».
- **[Suposición]** iOS guarda las notificaciones pendientes en un almacén del sistema protegido por Data Protection y fuera de las copias de seguridad de la app; no lo podemos comprobar desde la app.

## Opciones consideradas

1. **A. Texto calculado en Dart y programado por adelantado**, reprogramado cada vez que cambia la tarea actual, el idioma, el interruptor o la cantidad, y al arrancar la app. El Swift solo programa, cancela, pide permiso, abre ajustes y gestiona «a la vista».
2. **B. Solo el texto genérico** («Tarea actual» / «Tienes una tarea pendiente.») en iOS: sin texto de tareas fuera de la BD, pero sin la tarea (contradice CA-019-16, el motivo de la función, D25).
3. **C. `flutter_local_notifications`**: lo mismo que A con una dependencia grande y su paquete de zonas horarias (P11).
4. **D. Refresco en segundo plano** (`BGAppRefreshTask`) para rehacer el texto: no garantiza nada; sigue necesitando A como base.
5. **E. Notificaciones remotas** con *Service Extension*: necesita servidor (P3, P4). Descartada de entrada.

## Decisión

**Opción A.** Dart calcula título, cuerpo y versión genérica con las reglas de CA-019-16 y 21 (la lógica de `TaskLabel.kt` se porta a Dart con sus casos de prueba) y manda al canal `una/notifications` de iOS una lista de 0 a 3 avisos (hora, minuto y textos). El Swift los programa con `UNCalendarNotificationTrigger` diarios, con la versión genérica como texto oculto de la pantalla de bloqueo, sin insignia, y **no guarda nada más**. Se reprograma al cambiar la tarea actual (crear, editar, completar, eliminar, deshacer, reordenar), el idioma, el interruptor o la cantidad, y al arrancar la app (tras el primer fotograma, P2). Con el interruptor apagado o sin tareas se cancela todo y se quita lo entregado.

Es una **excepción nueva a CA-019-23** (y a la nota de P4 y a T-2): mientras el interruptor está encendido, **el texto de la tarea actual vive también en la programación del sistema**. Se revisa si Apple permite ejecutar código local al llegar la hora, si el propietario prefiere la opción B o si la pasada en dispositivo (CA-028-21) muestra textos viejos en situaciones normales.

## Motivos

Criterios (peso): cumplir lo que el usuario quiere ver, la tarea (3); privacidad (3); dependencias y permisos (2); fiabilidad (2); simplicidad (1). Puntuación de 1 a 5.

| Opción | Tarea ×3 | Privacidad ×3 | Dependencias ×2 | Fiabilidad ×2 | Simplicidad ×1 | Total |
|---|---|---|---|---|---|---|
| A. Dart + programación por adelantado | 4 → 12 | 3 → 9 | 5 → 10 | 5 → 10 | 4 → 4 | **45** |
| B. Solo genérica | 1 → 3 | 5 → 15 | 5 → 10 | 5 → 10 | 5 → 5 | **43** |
| C. `flutter_local_notifications` | 4 → 12 | 3 → 9 | 1 → 2 | 5 → 10 | 4 → 4 | **37** |
| D. Refresco en segundo plano | 4 → 12 | 3 → 9 | 5 → 10 | 1 → 2 | 2 → 2 | **35** |

- **A** es la única que enseña la tarea sin servidor ni dependencias. La tarea solo cambia dentro de la app, así que reprogramar en cada cambio deja el aviso al día en el uso normal.
- **B** respeta CA-019-23 al pie de la letra, pero vacía la función (el propietario la descartó en el plan).
- **C** hace lo mismo que A con una dependencia grande; A son ~100 líneas de Swift.
- **D** no es fiable y no evita la copia.

## Consecuencias

- **Positivas:**
  - Sin dependencias, sin red, sin esquema nuevo; un canal pequeño (`channel-contract.md` §4).
  - Hora exacta (sin la ventana de CA-019-11); iOS conserva los avisos al reiniciar, cambiar la hora o el huso y actualizar (CA-019-13 sin código propio); no hace falta la versión de respaldo antes del primer desbloqueo (CA-019-30).
  - La etiqueta y los textos se calculan una vez, en Dart, con los ARB: **ningún conocimiento duplicado en Swift** (frente a la duplicación aceptada en el ADR-0025 para Kotlin).
  - Con la opción por defecto de iOS, la pantalla de bloqueo **no** enseña la tarea (mejor que Android por defecto, CA-019-17).
- **Negativas y mitigación:**
  - **El texto de la tarea actual sale de la BD** a la programación del sistema (excepción a CA-019-23, T-2 y la nota de P4). Mitigación: solo con el interruptor encendido (apagado por defecto) y tras la línea de privacidad (CA-019-29, versión iOS); solo la tarea actual, como mucho 3 copias; se borra en el momento en que la tarea deja de ser la actual o se apaga. Residual: el almacén del sistema [Suposición] y lo ya entregado en el centro de notificaciones.
  - **Texto viejo si la BD cambia sin pasar por la app** (restauración de una copia) o si cambia el idioma del sistema con «Como el sistema» y la app cerrada (CL-028-7 y 8): se corrige al abrir la app. Aceptado.
  - **El texto sigue en el centro de notificaciones** después de completar o eliminar la tarea si ya se había entregado y la app no estaba abierta: se quita al reprogramar (al completar dentro de la app) o al abrirla. Residual aceptado.
  - **Registro del sistema** («ni en registros», CA-019-23): el Swift no registra nada; lo que iOS registre por su cuenta del contenido de una notificación queda fuera del control de la app [Suposición: iOS no registra el cuerpo en el registro unificado accesible a otras apps].
  - **Data Protection (ADR-0005):** el almacén de notificaciones del sistema tiene la clase de protección que decida iOS, no la de la app [Suposición]; se anota en `threat-model.md`.
  - **T-17 (dos copias de SQLite) no aplica en iOS:** el Swift no abre la BD.
  - **Un aviso perdido con el iPhone apagado no se recupera** (CA-019-14 no aplica). Aceptado: el siguiente llega a su hora.
  - **«Una sola a la vez»** (CA-019-18) no está garantizado con avisos de identificadores distintos: se quitan los entregados al reprogramar y al abrir; se comprueba en el iPad (Q-028-5).
  - **Sin canal** que el usuario pueda ajustar en el sistema (CA-019-22): en iOS los ajustes son de la app entera. Sin efecto práctico.
  - **Reprogramar en cada cambio** cuesta una llamada al canal por cambio de la tarea actual: barata, fuera del primer fotograma (P2), y se agrupan los cambios seguidos en una sola (sin bloquear la UI).
- **Cambios en otros documentos (al aceptarlo):**
  - **Constitución 1.11:** la nota de P4 añade «salvo en iOS, donde el texto de la tarea actual se programa por adelantado en el sistema (ADR-0030)».
  - **ADR-0025:** su viñeta de iOS pasa a «Enmendado por el ADR-0030»; **README de los ADR**: fila del 0030.
  - **Spec 019:** nota en CA-019-23 y CA-019-28 que remite a la 028.
  - **`docs/security/threat-model.md`:** T-2 (la excepción en iOS) y la matriz.
  - **Política de privacidad** (`docs/legal/privacy-policy.md`, fuente de la web): se actualiza **antes de distribuir cualquier compilación de iOS** a alguien que no sea el propietario (testers o tienda). **«Data Not Collected» se mantiene**: el texto no sale del dispositivo ni lo recoge el desarrollador.
- **Qué dispararía revisarlo:** Apple añade un mecanismo local para rehacer el contenido al llegar la hora; un fallo de privacidad del almacén de notificaciones; el propietario prefiere B tras usarla.
