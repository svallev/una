# Tareas — Spec NNN: Nombre

**Siguiente:** T-NNN-01 <!-- el coordinador la actualiza al cortar cada sesión: ola o tarea que va después -->

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse a la vez que otras de su ola: sus dependencias están hechas, su columna **Toca** no comparte archivos ni zonas con ellas y no usa el emulador ni el móvil, ni cambia el esquema de BD, los ARB, `tokens.json`, `pubspec.yaml` ni código nativo compartido (ver `/spec-implement` §1). Los textos y los tokens van juntos en una tarea al principio. Una PR puede agrupar varias tareas consecutivas.

| ID | Tarea | Depende de | Toca | Verificación | CA |
|---|---|---|---|---|---|
| T-NNN-01 | | — | | | |

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.

## Estado

Una fila por tarea, **≤ 3 líneas**: qué se hizo, dónde se verificó (tests, emulador), fallos encontrados y lo pendiente con **[Suposición]**/**[Pendiente]**. El detalle va en el mensaje del commit; lo que sirve para otras tareas, a las **Trampas** de `.claude/agents/spec-task.md`.

| Tareas | Estado | Commit |
|---|---|---|
