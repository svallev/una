# Cómo se trabaja en este repositorio

> Proyecto personal con **todos los derechos reservados** (ver `LICENSE`). **No se aceptan contribuciones externas** (PR de terceros) sin un acuerdo previo por escrito. Los avisos de seguridad sí son bienvenidos: ver `SECURITY.md`.

## Flujo SDD

1. **Spec** (`specs/NNN-nombre/spec.md`, con la skill `/spec-new`): qué y por qué, con criterios Dado/Cuando/Entonces. Se revisa con el subagente `spec-reviewer` y el propietario la **aprueba**.
2. **Plan** (`plan.md`): cómo; ADR si hay una decisión de arquitectura (`/adr-new`).
3. **Tareas** (`tasks.md`): pequeñas, ordenadas y verificables.
4. **Implementación** (`/spec-implement NNN`): una rama y una PR por tarea o grupo coherente de tareas.
5. **Verificación**: tests que prueban cada criterio de aceptación + Definition of Done (`specs/constitution.md`).

## Ramas

- `main` está protegida: solo se entra por PR con CI en verde, historial lineal (*squash merge*) y sin *force push*.
- Nombres de rama: `feat/NNN-descripcion`, `fix/…`, `docs/…`, `chore/…`, `ci/…`, `spike/…` (estas nunca se fusionan).
- Vida corta (días). Se rebasa sobre `main` antes de fusionar.

## Commits y PR

- **Conventional Commits** en el título de la PR (se usa en el commit de *squash*): `feat(003): completar manteniendo pulsado`, `fix(url): bloquear esquema intent:`, `docs(adr): 0011 …`.
  Tipos: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`, `ci`, `build`, `revert`. Ámbito: número de spec o área.
- Cada PR rellena la plantilla, enlaza la spec y los criterios que cubre, y marca la checklist de seguridad y accesibilidad.

## Versionado y changelog

- **SemVer** `MAJOR.MINOR.PATCH`; en Flutter, `version: X.Y.Z+build` en `pubspec.yaml` (el número de build crece siempre).
- `CHANGELOG.md` y las etiquetas `vX.Y.Z` los genera **release-please** a partir de los commits (se activa en F2).
- Pre-1.0: `0.y.z`; la v1.0.0 es la primera versión pública en tiendas.

## Dependencias, skills y herramientas

- Toda dependencia nueva cumple `docs/security/threat-model.md §5` y se justifica en la PR.
- Skills, plugins y servidores MCP: **solo a nivel de proyecto**, revisados antes de instalar, sin `-g` ni `-y` (`specs/constitution.md` P11).

## Idioma

Código, identificadores y commits en **inglés**; specs, ADR y documentación en **español**; términos según `docs/glossary.md`.
