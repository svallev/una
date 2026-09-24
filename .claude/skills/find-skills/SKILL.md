---
name: find-skills
description: Busca skills existentes que podrían ayudar con una tarea ("¿hay una skill para X?", "busca una skill de…") y las presenta para revisión. Nunca instala nada sin revisión y sin el "sí" explícito del usuario, y solo a nivel de proyecto.
---

<!--
Procedencia: adaptación de `find-skills` de vercel-labs/skills (skills/find-skills/SKILL.md,
hash registrado en skills-lock.json: b146008599c31057cef1c145774cea5d5afb30e8f43fa802e47a4b461419aaaf).
Cambios del proyecto (2026-09-24): se eliminan la instalación global (-g) y sin confirmación (-y),
y se añade un paso obligatorio de revisión del contenido. Constitución P11.
La copia original sigue en .agents/skills/find-skills (ver el resumen de la planificación).
-->

# Buscar skills (solo proyecto y con revisión)

## Cuándo usarla

Cuando el usuario pregunta si existe una skill para algo o quiere ampliar las capacidades de Claude Code en este proyecto. **Antes, comprueba si ya la cubre una skill del proyecto** (`.claude/skills/`).

## Pasos

1. **Entender la necesidad:** dominio, tarea concreta y si es frecuente como para justificar una skill.
2. **Buscar** en fuentes con buena reputación: skills oficiales de Anthropic, de los mantenedores del stack (p. ej. Flutter/Dart) y el directorio skills.sh. Comando de búsqueda (no instala nada): `npx skills find <consulta>`.
3. **Evaluar la calidad antes de proponer:** publicador (oficial o de reputación alta), mantenimiento reciente, estrellas e instalaciones (con cautela por debajo de 1 000 instalaciones o de 100 estrellas) y licencia.
4. **Revisar el contenido (obligatorio):** lee el `SKILL.md` **y todos los scripts o archivos** que incluya, directamente del repositorio de origen. Busca: comandos de red, instalación de paquetes, lectura de secretos o de archivos fuera del proyecto, modificación de configuración o permisos, instrucciones que pidan saltarse confirmaciones, y ofuscación.
5. **Presentar al usuario:** qué hace, quién la publica, qué ejecuta y qué riesgos has visto, con enlace al código. **Recomienda o desaconseja.**
6. **Instalar solo con un "sí" explícito**, a nivel de proyecto y con confirmación interactiva:
   ```bash
   npx skills add <owner/repo@skill>
   ```
   - **Prohibido:** `-g`/`--global` y `-y`/`--yes` (el hook del proyecto lo bloquea).
   - Tras instalar: verifica que ha quedado en `.claude/skills/` (o en el directorio del proyecto que use la CLI), que `skills-lock.json` registra su procedencia y su hash, y que el contenido instalado coincide con el revisado.
7. Si no hay ninguna adecuada: dilo y ofrece hacer la tarea directamente o crear una skill propia del proyecto (revisable en una PR).
