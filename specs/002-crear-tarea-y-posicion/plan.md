# Plan técnico — Specs 002 (crear y posición) y 005 (menú y editar)

- **Specs:** `specs/002-crear-tarea-y-posicion/spec.md` y `specs/005-menu-y-editar/spec.md` (aprobadas provisionalmente, 2026-09-25). Se implementan juntas: el menú (005) es la entrada de "Nueva tarea" (002) y el editor de la 002 es el de "Editar" (005).
- **ADR aplicables:** ADR-0002 (orden fraccional, repositorio)
- **Estado del plan:** Aprobado con las specs

## 1. Enfoque

- **Editor único** `TaskEditorScreen` con tres modos: primera tarea (ya existe), nueva y editar. Nueva y editar se abren como ruta con un fundido de 0,8 s (`.fadein` del prototipo), con "Cancelar" arriba a la derecha y el gesto atrás equivalente.
- **Hojas** sobre `showModalBottomSheet` ajustado al prototipo: fondo `scrim`, subida de 0,2 s con la curva `sheet`, bajada de 0,16 s con `sheetOut`, color papel, borde superior de 3 px, sin esquinas ni asa, cierre deslizando (DEV-21). La ruta modal aporta el foco atrapado y el gesto atrás.
- **Menú** (`MenuSheet`) y **"¿Dónde la pones?"** (`PlacementSheet`) con las medidas del prototipo; iconos de `UnaIcons`.
- **Dominio:** `CreateTask` ya admite posición y color. Nuevo `UpdateTaskText` y `TaskRepository.updateText` (conserva posición y color; sin cambios, no toca `updatedAt`).
- **Foco:** la señal de foco de la spec 003 pasa a ser general (`screenFocusProvider`): tras colocar, editar o completar, el foco va a la tarea actual.

## 2. Cambios por capa

| Capa | Cambio |
|---|---|
| Dominio | `UpdateTaskText`; puerto `updateText` |
| Datos | `updateText` en drift y memoria + contrato |
| Estado | `createTaskProvider` ya existe; `updateTaskTextProvider`; señal de foco general |
| Presentación | `TaskEditorScreen` (modos), `UnaSheet`, `MenuSheet`, `PlacementSheet`; menú desde `CurrentTaskScreen` |
| l10n | Claves de §7 de ambas specs |
| Tokens | Tamaños y tiempos de las hojas que falten |

## 3. Modelo de datos

Sin cambios de esquema.

## 4. Dependencias nuevas

Ninguna.

## 5. Tests

| CA | Tipo |
|---|---|
| CA-002-01/02/03/04/05/07/10, CL-002-1/3/4 | Widget (flujo con repositorio en memoria) + unitario de orden |
| CA-005-01/02/03/04/05/06/09/11, CL-005-1/2 | Widget |
| Aspecto | *Goldens* del menú, de "¿Dónde la pones?" y del editor nuevo y en edición |
| Contrato | `updateText` en memoria y drift |
