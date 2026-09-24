---
name: spec-implement
description: Implementa una spec aprobada paso a paso (plan → tareas → código con tests → verificación de los criterios de aceptación → Definition of Done). Úsala cuando el usuario pida implementar la spec NNN o una tarea T-NNN-XX.
argument-hint: "<NNN> [T-NNN-XX]"
---

# Implementar una spec

## 0. Comprobaciones previas (si alguna falla, para y avisa)

- `specs/NNN-*/spec.md` tiene el estado **Aprobada**.
- Existen `plan.md` (Aprobado) y `tasks.md`. Si no, prepáralos desde `specs/_templates/`, preséntalos y **espera la aprobación** antes de escribir código.
- La fase de `docs/PLAN.md` lo permite (p. ej. no hay código de producto antes de cerrar F1).
- Rama de trabajo `feat/NNN-<descripción>` creada desde `main` actualizado.

## 1. Por cada tarea de `tasks.md`, en orden

1. Relee los CA que cubre la tarea.
2. **Tests primero:** delega en el subagente `test-writer` (o escríbelos tú siguiendo `docs/testing.md`). Deben fallar por la razón esperada.
3. Implementa lo mínimo para que pasen, respetando las capas (`docs/architecture.md`), los tokens, la l10n (`/strings-add`) y el glosario.
4. `fvm dart format .` · `fvm flutter analyze --fatal-infos` · `fvm flutter test` → todo en verde.
5. Marca la tarea en `tasks.md` y haz commit con Conventional Commits (`feat(NNN): …`).

## 2. Al terminar la spec

- Verifica **cada** CA contra su test (lista CA → test).
- Ejecuta `/i18n-check`, `/tokens-validate` y `/security-check`, y los subagentes `a11y-reviewer` y `security-reviewer`; resuelve o registra los hallazgos.
- Si hay UI: *goldens* frente al prototipo, y desviaciones registradas en `docs/design/prototype-deviations.md`.
- Actualiza la documentación afectada (arquitectura, glosario, ADR).
- Recorre la Definition of Done de `specs/constitution.md`.
- Marca la spec como **Implementada** y prepara la descripción de la PR con la plantilla. **No hagas push ni abras la PR sin confirmación del usuario.**

## Reglas

- Si la spec es ambigua o el código la contradice: **para y pregunta**. No reinterpretes la spec.
- Dependencias nuevas: solo con la justificación de `threat-model.md §5` y avisando al usuario.
- Informa del resultado real de los tests; si algo falla o se ha omitido, dilo.
