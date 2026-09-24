# Spec 005: Menú de la tarea y editar

- **Estado:** En revisión
- **Reglas de producto:** R7 (primer paso), R11
- **Pantallas del prototipo:** 2 "Menú", 3 "Nueva tarea" (modo editar)
- **Decisiones y ADR:** D13, DEV-05, DEV-11
- **Dependencias:** 001, 002

## 1. Objetivo

Reunir en un único menú las acciones sobre la tarea actual (editar, eliminar) y las generales (ver todas, crear, configuración), manteniendo la pantalla principal limpia.

## 2. Historias de usuario

- **HU-005-1** Como usuario, quiero corregir el texto de la tarea actual sin cambiar su posición.
- **HU-005-2** Como usuario, quiero llegar desde un sitio a crear, ver todas o configurar.

## 3. Criterios de aceptación

- **CA-005-01 Abrir el menú**
  - **Dado** la pantalla principal con una tarea actual
  - **Cuando** pulsa el botón de menú
  - **Entonces** sube una hoja con dos bloques: **"Esta tarea"** (Editar, Eliminar, y una X para cerrar) y el bloque general (**Todas mis tareas**, **Nueva tarea** como botón principal y **Configuración**).
- **CA-005-02 Cerrar el menú**
  - **Dado** el menú abierto
  - **Cuando** toca la X, toca fuera, desliza hacia abajo o usa el gesto atrás
  - **Entonces** la hoja baja (0,16 s) y se vuelve a la tarea.
- **CA-005-03 "Todas mis tareas" con una sola tarea**
  - **Dado** que solo hay una tarea pendiente
  - **Cuando** se abre el menú
  - **Entonces** "Todas mis tareas" aparece deshabilitado, con la descripción accesible "Solo tienes esta tarea".
- **CA-005-04 Editar una tarea de texto**
  - **Dado** el menú de una tarea de texto
  - **Cuando** elige "Editar"
  - **Entonces** se abre el editor con la etiqueta "Editar tarea", el texto actual (cursor al final), "Cancelar" y "Guardar cambios".
- **CA-005-05 Guardar cambios**
  - **Dado** el editor en modo editar con un texto no vacío
  - **Cuando** pulsa "Guardar cambios"
  - **Entonces** se actualiza el texto (`updatedAt`), la tarea conserva **su posición y su color**, no se pregunta dónde va y se vuelve al origen (principal o listado).
- **CA-005-06 No dejar una tarea vacía**
  - **Dado** una tarea sin adjunto en modo editar
  - **Cuando** borra todo el texto
  - **Entonces** "Guardar cambios" queda deshabilitado (para eso existe Eliminar).
- **CA-005-07 Editar una tarea con adjunto**
  - **Dado** una tarea con imagen o documento
  - **Cuando** elige "Editar"
  - **Entonces** el editor muestra el adjunto, el botón "Quitar adjunto" y el texto opcional; se puede cambiar el texto, quitar el adjunto (si queda texto) o sustituirlo con (+). Sustituirlo **no** mueve la tarea.
- **CA-005-08 Editar una tarea web**
  - **Dado** una tarea con URL
  - **Cuando** elige "Editar"
  - **Entonces** se abre la hoja "Cargar URL" con la dirección actual; al confirmar se actualiza la URL y se genera una nueva captura (spec 009).
- **CA-005-09 Nueva tarea y Configuración**
  - **Dado** el menú
  - **Cuando** elige "Nueva tarea" o "Configuración"
  - **Entonces** se abre el editor (spec 002) o la pantalla de Configuración (spec 010).
- **CA-005-10 Menú bloqueado durante las animaciones**
  - **Dado** que se está completando o eliminando la tarea
  - **Cuando** toca el botón de menú
  - **Entonces** no se abre.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-005-1 | Cancelar la edición con cambios | Se descartan sin preguntar (coherente con P-3) |
| CL-005-2 | Guardar sin cambios | Se vuelve sin modificar `updatedAt` |
| CL-005-3 | Quitar el adjunto de una tarea sin texto | "Guardar cambios" deshabilitado hasta escribir texto o añadir otro adjunto |

## 5. Accesibilidad

- El menú es un diálogo modal con el título "Menú de la tarea"; foco inicial en "Editar"; el bloque "Esta tarea" es un grupo con encabezado.
- Todas las filas miden ≥ 44 pt de alto; los iconos son decorativos y los textos, visibles.
- Reducir movimiento: la hoja aparece con fundido.

## 6. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `menuSectionThisTask` | Esta tarea | This task |
| `menuEdit` | Editar | Edit |
| `menuDelete` | Eliminar | Delete |
| `menuAllTasks` | Todas mis tareas | All my tasks |
| `menuAllTasksOnlyOne` | Solo tienes esta tarea | This is your only task |
| `menuNewTask` | Nueva tarea | New task |
| `menuSettings` | Configuración | Settings |
| `menuClose` | Cerrar menú | Close menu |
| `editorTagEdit` | Editar tarea | Edit task |
| `editorSaveChanges` | Guardar cambios | Save changes |
| `editorAttachmentPlaceholder` | Añade un texto (opcional) | Add some text (optional) |
| `editorRemoveAttachment` | Quitar adjunto | Remove attachment |
| `editorAddAttachment` | Añadir foto, imagen o archivo | Add photo, image or file |

## 7. Fuera de alcance

"Perfil" (no existe sin cuentas, D13).
