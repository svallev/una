# Spec 003: Completar la tarea actual

- **Estado:** En revisión
- **Reglas de producto:** R9, R12 ("Todo hecho."), R14
- **Pantallas del prototipo:** 1 "La tarea", 7 "Completar (mantener pulsado)", estado vacío dentro de `Main`
- **Decisiones y ADR:** D8, DEV-06, DEV-13; tokens `motion.duration.holdToComplete`, `tear`, `successHold`
- **Dependencias:** 001

## 1. Objetivo

Que completar sea un gesto deliberado y satisfactorio que refuerza el hábito y lleva directamente a la siguiente tarea.

## 2. Historias de usuario

- **HU-003-1** Como usuario, quiero completar la tarea manteniendo pulsado para no marcarla por error.
- **HU-003-2** Como usuario, quiero una recompensa visible al terminar y pasar a la siguiente sin más pasos.
- **HU-003-3** Como usuario de lector de pantalla o de acceso por switch, quiero completar sin tener que mantener pulsado.

## 3. Criterios de aceptación

- **CA-003-01 Progreso al mantener**
  - **Dado** la tarea actual en la pantalla principal
  - **Cuando** el usuario mantiene pulsado el botón "Pulsa para completar"
  - **Entonces** el botón se hunde y un relleno negro avanza de izquierda a derecha durante **1,2 s**, y el texto cambia a "Sigue pulsando…".
- **CA-003-02 Soltar antes de tiempo**
  - **Dado** que el relleno está avanzando
  - **Cuando** el usuario suelta, arrastra el dedo fuera del botón o la app pasa a segundo plano antes de 1,2 s
  - **Entonces** el relleno retrocede (0,28 s), el texto vuelve a "Pulsa para completar" y la tarea **no** se completa.
- **CA-003-03 Completar**
  - **Dado** que se ha mantenido 1,2 s
  - **Cuando** se completa el tiempo
  - **Entonces** el botón muestra "¡Hecho!" (con una vibración ligera si el sistema la permite); la tarea queda `completed` con `completedAt` = ahora y sale de la cola; la nota se rompe en dos mitades que caen (1,25 s) y aparece la pantalla "¡Enhorabuena! Tarea completada." con el texto "Ahora a por la siguiente →" si quedan tareas.
- **CA-003-04 Pasar a la siguiente**
  - **Dado** la pantalla de enhorabuena y que quedan tareas pendientes
  - **Cuando** pasan ~2,1 s (o el usuario toca la pantalla)
  - **Entonces** la pantalla se desvanece (0,7 s) y aparece la nueva tarea actual.
- **CA-003-05 Todo hecho (R12)**
  - **Dado** que se ha completado la última tarea pendiente
  - **Cuando** termina la enhorabuena
  - **Entonces** se muestra el estado vacío: "Todo hecho." / "No queda nada pendiente. Disfrútalo, o apunta lo siguiente." y el botón "Crear una tarea".
- **CA-003-06 Histórico (R14, D8)**
  - **Dado** una tarea completada
  - **Cuando** se consulta la BD
  - **Entonces** la tarea se conserva con su texto, su adjunto (archivos intactos) y la fecha de finalización; no aparece en ninguna pantalla de la v1.
- **CA-003-07 Alternativa accesible**
  - **Dado** un lector de pantalla (VoiceOver/TalkBack) o acceso por switch activo
  - **Cuando** el usuario invoca la acción personalizada "Completar tarea" sobre la tarea actual o sobre el botón
  - **Entonces** la tarea se completa sin mantener pulsado, se anuncia "Tarea completada. Siguiente: {texto}" (o "Todo hecho.") y el foco pasa a la nueva tarea actual.
- **CA-003-08 Teclado**
  - **Dado** un teclado físico con el foco en el botón
  - **Cuando** mantiene Espacio o Intro durante 1,2 s
  - **Entonces** se comporta como el gesto táctil (las repeticiones de tecla no reinician el progreso).
- **CA-003-09 Sin interacciones durante la animación**
  - **Dado** que la animación de completar está en curso
  - **Cuando** el usuario toca el menú o el botón
  - **Entonces** no ocurre nada (están deshabilitados hasta mostrarse la siguiente tarea).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-003-1 | La app se mata durante la animación, después de 1,2 s | La tarea ya consta como completada (se guarda antes de animar); al reabrir se ve la siguiente |
| CL-003-2 | Llamada entrante o notificación a pantalla completa mientras se mantiene pulsado | Se cancela (CA-003-02) |
| CL-003-3 | Multitoque: dos dedos | Solo cuenta el primer puntero |
| CL-003-4 | Tarea con adjunto (imagen, PDF, web) | Misma animación; en la nota rota se ve la miniatura |
| CL-003-5 | Reducir movimiento activado | Sin rotura ni confeti: fundido (0,4 s) y enhorabuena estática |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Todo hecho." | Tras completar la última | Ver CA-003-05 |
| Error al guardar | Fallo de escritura al completar | La tarea no se rompe; aviso "No se ha podido completar. Inténtalo de nuevo." |

## 6. Accesibilidad

- Botón con etiqueta "Pulsa para completar" y pista (hint) "Mantén pulsado o usa las acciones para completar".
- Acción personalizada "Completar tarea" (CA-003-07). Sin confirmación extra: la acción es deliberada.
- La enhorabuena se anuncia como región en vivo (educada); con lector de pantalla, la pantalla dura hasta que se toca o 4 s como mínimo.
- Vibración respetando los ajustes del sistema. Contraste: blanco sobre `ink` 18,9:1.

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `completeButton` | Pulsa para completar (una sola línea) | Press to complete |
| `completeHolding` | Sigue pulsando… | Keep holding… |
| `completeDone` | ¡Hecho! | Done! |
| `completeA11yAction` | Completar tarea | Complete task |
| `completeA11yHint` | Mantén pulsado o usa las acciones para completar | Press and hold, or use actions, to complete |
| `successTitle1` | ¡Enhorabuena! | Well done! |
| `successTitle2` | Tarea completada. | Task completed. |
| `successNext` | Ahora a por la siguiente → | Now on to the next one → |
| `a11yCompletedNext` | Tarea completada. Siguiente: {text} | Task completed. Next: {text} |
| `emptyDoneTitle1` / `emptyDoneTitle2` | Todo / hecho. | All / done. |
| `emptyDoneBody` | No queda nada pendiente. Disfrútalo, o apunta lo siguiente. | Nothing left to do. Enjoy it, or jot down what's next. |
| `emptyCreate` | Crear una tarea | Create a task |
| `completeError` | No se ha podido completar. Inténtalo de nuevo. | Couldn't complete it. Please try again. |

## 8. Fuera de alcance

Ver el histórico o borrarlo (Bloque 4). Deshacer una tarea completada.

## 9. Preguntas abiertas

- **[Pendiente P-4]** ¿Ofrecer "Deshacer" tras completar? Recomendación: no en la v1 (mantener pulsado 1,2 s ya evita los accidentes); se puede recuperar desde el futuro histórico. Decide: producto.
