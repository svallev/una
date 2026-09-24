# ADR-0003: SDD con estructura propia ligera, compatible con Spec Kit

- **Estado:** Aceptado
- **Fecha:** 2026-09-24

## Contexto

- **[Hecho]** El proyecto sigue Spec-Driven Development: spec → plan → tareas → implementación → verificación.
- **[Hecho]** Lo desarrolla una persona con Claude Code. La documentación va en español (D16).
- **[Hecho]** Política: nada de skills, plugins ni scripts de terceros sin revisión, y solo a nivel de proyecto.
- **[Hecho]** GitHub Spec Kit ofrece una CLI (`specify`, Python/uv), plantillas, scripts de shell y comandos `/speckit.*` para varios agentes, con la estructura `specs/NNN-feature/{spec,plan,tasks}.md` y una constitución.

## Opciones consideradas

1. **Spec Kit completo** (CLI + scripts + comandos)
2. **Estructura propia ligera** con los mismos nombres de archivo y el mismo flujo, implementada con skills del proyecto
3. Sin estructura formal (issues de GitHub)

## Decisión

**Opción 2.** Se adoptan las convenciones de Spec Kit (constitución, `specs/NNN-nombre/{spec,plan,tasks}.md`, flujo especificar → planificar → dividir en tareas → implementar), pero **sin instalar su CLI ni sus scripts**. El flujo se implementa con skills propias y versionadas en `.claude/skills/` (`spec-new`, `spec-implement`, `adr-new`), con plantillas en español en `specs/_templates/`.

## Motivos

- **Superficie de ataque y dependencias:** la CLI trae Python/uv y scripts que habría que auditar y mantener. Las skills propias son Markdown legible y revisable en cada PR.
- **Idioma y ajuste:** plantillas en español con lo que este proyecto exige (textos ES/EN, accesibilidad, pantalla del prototipo, seguridad), que Spec Kit no trae.
- **Reversible:** al usar los mismos nombres y la misma estructura, migrar a Spec Kit más adelante es trivial.
- Los issues de GitHub no son versionables junto al código ni revisables en la misma PR.

## Consecuencias

- Mantener las plantillas y las skills es responsabilidad del proyecto.
- Numeración: `NNN` de tres dígitos y consecutivo; una spec no cambia de número.
- Estados de una spec: `Borrador → En revisión → Aprobada → Implementada`. Solo se implementa una spec **Aprobada**.
