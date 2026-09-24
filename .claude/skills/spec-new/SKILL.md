---
name: spec-new
description: Crea una nueva spec SDD (specs/NNN-nombre/spec.md) desde la plantilla del proyecto. Úsala cuando el usuario quiera especificar una funcionalidad nueva o una de la hoja de ruta.
argument-hint: "<nombre-corto-en-kebab-case> [descripción]"
---

# Crear una spec nueva

1. **Número:** busca el mayor `NNN` en `specs/` y usa el siguiente (3 dígitos). Carpeta: `specs/NNN-<nombre-en-español-kebab>/`.
2. **Contexto obligatorio antes de escribir:** `specs/constitution.md`, `docs/glossary.md`, `docs/PLAN.md` (reglas, hoja de ruta y pendientes), `docs/design/screen-map.md` y las specs relacionadas.
3. **Preguntas:** si faltan datos de producto, pregunta al usuario (máx. 4 preguntas por ronda, con opciones y tu recomendación). Lo que puedas decidir con criterio razonable, decídelo y márcalo como **[Suposición]**.
4. Copia `specs/_templates/spec.md` a `spec.md` y rellena **todas** las secciones:
   - Solo el **qué** y el **por qué**: nada de tecnología.
   - Criterios `CA-NNN-XX` en Dado/Cuando/Entonces, verificables por un test.
   - Casos límite `CL-NNN-X`, estados vacíos y de error, accesibilidad (alternativa a cada gesto), tabla de textos ES/EN con claves en camelCase.
   - Pantalla del prototipo o "sin diseño".
   - Estado: **Borrador**.
5. Si introduce términos nuevos, añádelos a `docs/glossary.md`.
6. Actualiza `docs/design/screen-map.md` y la tabla de trazabilidad de `docs/PLAN.md` si aplica.
7. Lanza el subagente `spec-reviewer` sobre la spec y aplica o presenta sus hallazgos.
8. Informa al usuario: ruta, resumen, preguntas pendientes y que la spec necesita su **aprobación** (estado "Aprobada") antes de planificar.
