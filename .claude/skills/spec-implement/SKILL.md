---
name: spec-implement
description: Implementa una spec aprobada paso a paso (plan → tareas → código con tests → verificación de los criterios de aceptación → Definition of Done), en sesiones cortas y con un subagente spec-task por tarea. Úsala cuando el usuario pida implementar la spec NNN o una tarea T-NNN-XX.
argument-hint: "<NNN> [T-NNN-XX]"
---

# Implementar una spec

## Sesiones cortas (para ahorrar contexto)

Cada spec pasa por varias sesiones; cada una empieza **solo con archivos** (nada de la conversación anterior) y termina con un commit:

| Sesión | Qué hace | Termina cuando |
|---|---|---|
| 1. Spec | `spec-reviewer`, decisiones del propietario, spec **Aprobada** | Commit de la spec |
| 2. Plan | `plan.md` y `tasks.md` desde `specs/_templates/`; `security-reviewer` y `a11y-reviewer` sobre el plan si toca sus superficies | Plan **Aprobado** y commit |
| 3…n. Implementación | Esta sesión coordina: lanza **un `spec-task` nuevo por tarea** y no programa ella misma | Punto natural: antes de una tarea que necesita el móvil del propietario, tras ~6 tareas o si el contexto pasa de ~150k |
| Final. Cierre | Revisiones, DoD, PR (§3) | PR lista |

Al cortar una sesión: la línea **Siguiente** de `tasks.md` dice qué tarea va después, y la sesión nueva empieza con "`/spec-implement NNN`".

## 0. Comprobaciones previas (si alguna falla, para y avisa)

- `specs/NNN-*/spec.md` tiene el estado **Aprobada**.
- Existen `plan.md` (Aprobado) y `tasks.md`. Si no, estás en la sesión 2: prepáralos, preséntalos y **espera la aprobación** antes de escribir código.
- La fase de `docs/PLAN.md` lo permite.
- Rama de trabajo `feat/NNN-<descripción>` creada desde `main` actualizado.

## 1. Coordinar (sesiones 3…n)

Lee **solo** `tasks.md` (tabla de tareas, línea **Siguiente** y la tabla **Estado**). No leas la spec ni el código salvo para resolver una pregunta de un subagente.

Las tareas van **de una en una, en orden** (decisión del propietario, 2026-09-28: nada en paralelo; no compensa el riesgo ni el disco para lo poco que se gana).

1. Elige la siguiente tarea cuyas dependencias están hechas.
2. Lanza `spec-task` en primer plano con "spec NNN, T-NNN-XX" en la rama de trabajo. Lee su resumen y sigue con la siguiente.
3. Si un subagente devuelve una pregunta: pásala al propietario con su recomendación. Para seguir, lanza un `spec-task` **nuevo** con un encargo corto; no reanudes el anterior (reanudar recarga todo su historial).
4. Tareas con el móvil del propietario: las hace el coordinador (los subagentes no lo usan), con su permiso y `--keep-app-running`.
5. Actualiza la línea **Siguiente** de `tasks.md` antes de cortar la sesión.

Si se pide una sola tarea (`/spec-implement NNN T-NNN-XX`), lanza solo esa.

## 2. Qué hace cada `spec-task` (resumen; detalle en `.claude/agents/spec-task.md`)

Relee los CA de su tarea → tests primero (fallan por la razón esperada) → implementa lo mínimo respetando capas, tokens, l10n (`/strings-add`) y glosario → `dart format`, `flutter analyze --fatal-infos`, `flutter test` en verde → fila de Estado (≤ 3 líneas) → un commit `feat(NNN): …`.

## 3. Al terminar la spec (sesión de cierre)

- Verifica **cada** CA contra su test (lista CA → test).
- Ejecuta `/i18n-check`, `/tokens-validate` y `/security-check`, y los subagentes `a11y-reviewer` y `security-reviewer` sobre `git diff main...HEAD`; resuelve o registra los hallazgos.
- Si hay UI: *goldens* frente al prototipo, y desviaciones registradas en `docs/design/prototype-deviations.md`.
- Actualiza la documentación afectada (arquitectura, glosario, ADR) y lo que la spec pida en su §10.
- Recorre la Definition of Done de `specs/constitution.md`.
- Marca la spec como **Implementada** y prepara la descripción de la PR con la plantilla. **No hagas push ni abras la PR sin confirmación del usuario.**

## Reglas

- Si la spec es ambigua o el código la contradice: **para y pregunta**. No reinterpretes la spec.
- Dependencias nuevas: solo con la justificación de `threat-model.md §5` y avisando al usuario.
- Informa del resultado real de los tests; si algo falla o se ha omitido, dilo.
- Lo aprendido que sirve para otras tareas (trampas de una librería, del emulador…) va a la sección **Trampas** de `.claude/agents/spec-task.md`, no a la tabla Estado.
