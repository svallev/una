# Spec 003: Completar la tarea actual

- **Estado:** Implementada (2026-09-25) · Aprobada por el propietario el 2026-09-25 tras probarla en el móvil
- **Reglas de producto:** R9, R12 ("Todo hecho."), R14
- **Pantallas del prototipo:** 1 "La tarea", 7 "Completar (mantener pulsado)", estado vacío dentro de `Main`
- **Decisiones y ADR:** D8, DEV-06 (revocada), DEV-13, DEV-17, DEV-18, DEV-19; tokens `motion.duration.holdToComplete`, `holdRelease`, `tear`, `successHold`, `successFade`, `reducedMotionFade`
- **Dependencias:** 001 (no necesita 002: con 0 tareas se usa el editor de la primera tarea)

## 1. Objetivo

Que completar sea un gesto deliberado y satisfactorio que refuerza el hábito y lleva directamente a la siguiente tarea.

## 2. Historias de usuario

- **HU-003-1** Como usuario, quiero completar la tarea manteniendo pulsado para no marcarla por error.
- **HU-003-2** Como usuario, quiero una recompensa visible al terminar y pasar a la siguiente sin más pasos.
- **HU-003-3** Como usuario de lector de pantalla o de acceso por switch, quiero completar sin tener que mantener pulsado.

## 3. Criterios de aceptación

**Mantener pulsado**

- **CA-003-01 Progreso al mantener**
  - **Dado** la tarea actual en la pantalla principal
  - **Cuando** el usuario mantiene pulsado el botón "Pulsa para completar"
  - **Entonces** el botón se desplaza 4 px y su sombra baja a 1 px, y un relleno `ink` avanza de izquierda a derecha durante `holdToComplete` (1,2 s); sobre el relleno, el mismo texto e icono se ven en blanco (como el prototipo: el texto **no** cambia).
- **CA-003-02 Soltar antes de tiempo**
  - **Dado** que el relleno está avanzando
  - **Cuando** el usuario suelta, arrastra el dedo fuera del botón o la app pasa a segundo plano antes de 1,2 s
  - **Entonces** el relleno retrocede en `holdRelease` (0,28 s) y la tarea **no** se completa.

**Completar**

- **CA-003-03a Datos**
  - **Dado** que se ha mantenido 1,2 s
  - **Cuando** se cumple el tiempo
  - **Entonces** la tarea se guarda como `completed` con `completedAt` = ahora **antes** de empezar la animación y sale de la cola; el móvil vibra ligeramente si los ajustes del sistema lo permiten (DEV-19).
- **CA-003-03b Animación (prototipo)**
  - **Dado** que la tarea se ha guardado como completada
  - **Cuando** empieza la animación
  - **Entonces**, tras `holdDonePause` (140 ms), la nota se rompe en dos mitades con borde irregular y filo de papel que caen durante `tear` (1,25 s) **por encima** de la pantalla de enhorabuena, que aparece a la vez sobre fondo `ink`: sello ✓ del color de la tarea, "¡Enhorabuena!" (blanco) y "Tarea completada." (en el color de la tarea), 18 piezas de confeti y, si quedan tareas, "Ahora a por la siguiente →".
- **CA-003-04 Pasar a la siguiente**
  - **Dado** la pantalla de enhorabuena y que quedan tareas pendientes
  - **Cuando** pasa `successHold` (2,1 s) desde el inicio de la rotura
  - **Entonces** la pantalla se desvanece en `successFade` (0,7 s) y aparece la nueva tarea actual. **No** se puede saltar con un toque (como el prototipo; decisión del propietario).
- **CA-003-05 Todo hecho (R12)**
  - **Dado** que se ha completado la última tarea pendiente
  - **Cuando** termina la enhorabuena
  - **Entonces** se muestra el estado vacío: "Todo" / "hecho." en dos líneas, "No queda nada pendiente. Disfrútalo, o apunta lo siguiente." y el botón "+ Crear una tarea".
- **CA-003-06 Histórico (R14, D8)**
  - **Dado** una tarea completada
  - **Cuando** se consulta la BD
  - **Entonces** la tarea se conserva con su texto, su adjunto (archivos intactos) y la fecha de finalización; no aparece en ninguna pantalla de la v1.

**Después de "Todo hecho."**

- **CA-003-10 Crear desde "Todo hecho."**
  - **Dado** "Todo hecho."
  - **Cuando** el usuario pulsa "Crear una tarea"
  - **Entonces** se abre el editor de CA-001-02 (sin "Cancelar", sin preguntar la posición) con un color al azar de la paleta; al guardar, la tarea pasa a ser la actual. El gesto atrás de Android **vuelve a "Todo hecho."** sin guardar (decisión del propietario).
- **CA-003-11 Reabrir sin pendientes**
  - **Dado** que no quedan tareas pendientes y hay al menos una completada
  - **Cuando** se abre la app en frío (o vuelve de segundo plano tras 10 min, CA-001-12)
  - **Entonces** se ve "Todo hecho." (no el editor). Enmienda CA-001-05, que queda para cuando no hay ninguna tarea, ni pendiente ni completada.
  - *Enmienda (spec 004, CA-004-08):* también con tareas eliminadas y ninguna completada.

**Errores**

- **CA-003-12 Fallo al guardar**
  - **Dado** un fallo al escribir en la BD
  - **Cuando** se cumple 1,2 s
  - **Entonces** no hay rotura ni enhorabuena, el relleno retrocede (`holdRelease`) y se muestra y anuncia "No hemos podido completar la tarea" con "Reintentar" (como en la spec 001; si es falta de espacio, el mensaje de espacio).

**Accesibilidad y teclado**

- **CA-003-07 Alternativa accesible**
  - **Dado** un lector de pantalla (TalkBack/VoiceOver) o acceso por switch activo
  - **Cuando** el usuario invoca la acción personalizada "Completar tarea" sobre la tarea actual o sobre el botón
  - **Entonces** la tarea se completa sin mantener pulsado, se hace **un único anuncio** "Tarea completada. Siguiente: {texto}" (o "Tarea completada. Todo hecho.") y, al terminar, el foco pasa a la nueva tarea actual (o al título "Todo hecho.", leído como un solo texto). El doble toque de TalkBack sobre el botón **no** completa (evita accidentes; la acción está en el menú de acciones).
- **CA-003-08 Teclado**
  - **Dado** un teclado físico con el foco en el botón
  - **Cuando** mantiene Espacio o Intro durante 1,2 s
  - **Entonces** se comporta como el gesto táctil (las repeticiones de tecla no reinician el progreso).
- **CA-003-09 Sin interacciones durante la animación**
  - **Dado** que la animación de completar está en curso
  - **Cuando** el usuario toca el menú o el botón, usa una acción del lector o el gesto atrás
  - **Entonces** no ocurre nada hasta que se muestra la siguiente tarea (o "Todo hecho."), **sin cambiar de aspecto** (DEV-17).
- **CA-003-13 Enhorabuena con lector de pantalla**
  - **Dado** un lector de pantalla activo
  - **Cuando** se completa una tarea
  - **Entonces** la enhorabuena dura al menos 4 s (en lugar de 2,1 s) para que se oiga el anuncio.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-003-1 | La app se mata durante la animación, después de 1,2 s | La tarea ya consta como completada (CA-003-03a); al reabrir se ve la siguiente o "Todo hecho." |
| CL-003-2 | Llamada entrante o notificación a pantalla completa mientras se mantiene pulsado | Se cancela (CA-003-02) |
| CL-003-3 | Multitoque: dos dedos | Solo cuenta el primer puntero |
| CL-003-4 | Tarea con adjunto (imagen, PDF, web) | Misma animación; las mitades muestran el mismo contenido que la tarea |
| CL-003-5 | Reducir movimiento activado | El relleno se mantiene; sin rotura ni confeti: fundido `reducedMotionFade` (0,4 s) a una enhorabuena estática que dura lo mismo (CA-003-04) |
| CL-003-6 | Toque breve (menos de 1,2 s) | Como soltar antes de tiempo (CA-003-02). **Sin pista visual ni texto adicional** (decisión del propietario, 2026-09-24) |
| CL-003-7 | La app pasa a segundo plano durante la rotura o la enhorabuena | Al volver se ve la siguiente tarea o "Todo hecho.", sin repetir la animación |
| CL-003-8 | Tarea solo con adjunto (sin texto), en el anuncio de CA-003-07 | `{texto}` = nombre del adjunto (llega con 007–009) |

Solo vertical en la v1 (CL-001-7): no hay rotación durante la animación.

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Todo hecho." | Tras completar la última, o al reabrir sin pendientes | CA-003-05, CA-003-11 |
| Error al completar | Fallo de escritura | CA-003-12 |

## 6. Accesibilidad

- Botón con etiqueta "Pulsa para completar" y pista (hint) "Mantén pulsado o usa las acciones para completar".
- Acción personalizada "Completar tarea" (CA-003-07). Sin confirmación extra: la acción es deliberada (DEV-13).
- Un solo anuncio al completar (CA-003-07); la enhorabuena no se anuncia aparte. Con lector de pantalla dura al menos 4 s (CA-003-13).
- Vibración respetando los ajustes del sistema. Contraste: blanco sobre `ink` 18,9:1.
- Texto al 200 %: como CL-001-9 (el botón sigue en una línea; la enhorabuena y "Todo hecho." se desplazan si no caben).

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `completeButton` | Pulsa para completar | Press to complete | Ya existe; una sola línea |
| `completeA11yAction` | Completar tarea | Complete task | |
| `completeA11yHint` | Mantén pulsado o usa las acciones para completar | Press and hold, or use actions, to complete | |
| `successTitle1` | ¡Enhorabuena! | Well done! | |
| `successTitle2` | Tarea completada. | Task completed. | En el color de la tarea |
| `successNext` | Ahora a por la siguiente → | Now on to the next one → | Solo si quedan tareas |
| `a11yCompletedNext` | Tarea completada. Siguiente: {text} | Task completed. Next: {text} | |
| `a11yCompletedAllDone` | Tarea completada. Todo hecho. | Task completed. All done. | |
| `emptyDoneTitle1` / `emptyDoneTitle2` | Todo / hecho. | All / done. | Dos líneas |
| `emptyDoneBody` | No queda nada pendiente. Disfrútalo, o apunta lo siguiente. | Nothing left to do. Enjoy it, or jot down what's next. | |
| `emptyCreate` | Crear una tarea | Create a task | Con icono "+" |
| `completeError` | No hemos podido completar la tarea | We couldn't complete the task | Con `retry` |

## 8. Fuera de alcance

Ver el histórico o borrarlo (Bloque 4). **Deshacer una tarea completada** (P-4: no en la v1).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-24, revisable] P-5:** toque breve sin pista visual (CL-003-6). La pista del lector de pantalla (§6) se mantiene porque no es visible.
- **[Resuelto 2026-09-25] P-4:** **no** hay "Deshacer" tras completar: mantener pulsado 1,2 s ya evita los accidentes (decisión del propietario).
- **[Resuelto 2026-09-25]** Gesto atrás desde el editor abierto en "Todo hecho.": vuelve a "Todo hecho." (CA-003-10). Reabrir sin pendientes: "Todo hecho." (CA-003-11). La enhorabuena no se salta con un toque (CA-003-04). Vibración ligera al completar (CA-003-03a, DEV-19).
