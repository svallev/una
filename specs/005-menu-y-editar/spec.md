# Spec 005: Menú de la tarea y editar

- **Estado:** Aprobada provisionalmente (2026-09-25: revisada tras `spec-reviewer` con las decisiones del propietario; se implementa junto con la 002)
- **Reglas de producto:** R7 (primer paso), R11
- **Pantallas del prototipo:** 2 "Menú", 3 "Nueva tarea" (modo editar)
- **Decisiones y ADR:** D13, DEV-05, DEV-11, DEV-17, DEV-18, DEV-21
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
  - **Entonces**, como en el prototipo, el fondo se oscurece (`ink` al 55 %, fundido de 0,16 s) y sube en 0,2 s una hoja de color papel con borde superior de 3 px, sin esquinas redondeadas ni asa, con dos bloques: **"Esta tarea"** (etiqueta en monoespaciada, X para cerrar, **Editar** y **Eliminar** en rojo, separados por una línea) y, tras un separador de 4 px, el bloque general (**Todas mis tareas**, **+ Nueva tarea** como botón principal y el enlace subrayado **Configuración**).
- **CA-005-02 Cerrar el menú**
  - **Dado** el menú abierto
  - **Cuando** toca la X, toca fuera, desliza hacia abajo (DEV-21) o usa el gesto atrás
  - **Entonces** la hoja baja (0,16 s) y se vuelve a la tarea.
- **CA-005-03 "Todas mis tareas" con una sola tarea**
  - **Dado** que solo hay una tarea pendiente
  - **Cuando** se abre el menú
  - **Entonces** "Todas mis tareas" aparece deshabilitado, con la descripción accesible "Solo tienes esta tarea" (DEV-11; excepción a DEV-17 decidida por el propietario). *[Abrir el listado con varias tareas: diferido a 006]*
- **CA-005-04 Editar una tarea de texto**
  - **Dado** el menú de una tarea de texto
  - **Cuando** elige "Editar"
  - **Entonces** se abre el editor (como CA-002-01) con el texto actual (cursor al final), el color de la tarea, "Cancelar" y "Guardar cambios"; la etiqueta "Editar tarea" no se ve (nombre accesible del campo).
- **CA-005-05 Guardar cambios**
  - **Dado** el editor en modo editar con un texto no vacío
  - **Cuando** pulsa "Guardar cambios"
  - **Entonces** se actualiza el texto (`updatedAt`), la tarea conserva **su posición y su color**, no se pregunta dónde va y se vuelve al origen (principal o listado).
- **CA-005-06 No dejar una tarea vacía**
  - **Dado** una tarea sin adjunto en modo editar
  - **Cuando** borra todo el texto y pulsa "Guardar cambios"
  - **Entonces** no se guarda y el foco vuelve al campo; el botón **no** se ve desactivado (DEV-17). Para quitar la tarea existe Eliminar.
- **CA-005-07 Editar una tarea con adjunto** — *[Diferido a 007–009]*
  - **Dado** una tarea con imagen o documento
  - **Cuando** elige "Editar"
  - **Entonces** el editor muestra el adjunto, el botón "Quitar adjunto" y el texto opcional; se puede cambiar el texto, quitar el adjunto (si queda texto) o sustituirlo con (+). Sustituirlo **no** mueve la tarea.
- **CA-005-08 Editar una tarea web** — *[Diferido a 009]*
  - **Dado** una tarea con URL
  - **Cuando** elige "Editar"
  - **Entonces** se abre la hoja "Cargar URL" con la dirección actual; al confirmar se actualiza la URL y se genera una nueva captura (spec 009).
- **CA-005-09 Nueva tarea y Configuración**
  - **Dado** el menú
  - **Cuando** elige "Nueva tarea" o "Configuración"
  - **Entonces** "Nueva tarea" abre el editor (spec 002). "Configuración" cierra el menú (como el prototipo) hasta que exista la spec 010.
- **CA-005-11 Acciones aún no disponibles**
  - **Dado** el menú antes de las specs 004 y 006
  - **Cuando** elige "Eliminar" o "Todas mis tareas" (con varias tareas)
  - **Entonces** no pasa nada y se ven activos (DEV-18, decisión del propietario); llegan con las specs 004 y 006.
- **CA-005-10 Menú bloqueado durante las animaciones**
  - **Dado** que se está completando o eliminando la tarea
  - **Cuando** toca el botón de menú
  - **Entonces** el botón no responde y se ve igual (DEV-17; ya implementado en la spec 003).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-005-1 | Cancelar la edición con cambios (o gesto atrás) | Se descartan sin preguntar (P-3) |
| CL-005-2 | Guardar sin cambios | Se vuelve sin modificar `updatedAt` |
| CL-005-3 | Quitar el adjunto de una tarea sin texto | *[Diferido a 007–009]* "Guardar cambios" no guarda hasta que haya texto u otro adjunto (sin verse desactivado) |

## 5. Errores

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Error al guardar la edición | Fallo de escritura | Aviso `editorSaveError` (o el de falta de espacio) con "Reintentar"; el editor conserva el texto |

## 5b. Accesibilidad

- El menú es un diálogo modal con el título "Menú de la tarea"; foco inicial en "Editar"; el bloque "Esta tarea" es un grupo con encabezado.
- Todas las filas miden ≥ 44 pt de alto; los iconos son decorativos y los textos, visibles.
- Reducir movimiento: la hoja aparece sin desplazarse; solo el fondo se funde.
- Tras guardar la edición, el foco vuelve a la tarea actual.

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

Con los adjuntos (007–009): `editorAttachmentPlaceholder` (Añade un texto (opcional) / Add some text (optional)) y `editorRemoveAttachment` (Quitar adjunto / Remove attachment). "+" reutiliza `attachButton`.

## 7. Fuera de alcance

"Perfil" (no existe sin cuentas, D13).
