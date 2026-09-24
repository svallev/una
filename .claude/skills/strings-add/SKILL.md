---
name: strings-add
description: Añade o modifica textos traducidos (ES y EN) en las ARB de la app, con descripción, placeholders y plurales ICU, y los sincroniza con la spec y el glosario. Úsala siempre que aparezca un texto visible o anunciado nuevo.
argument-hint: "<clave> \"<texto ES>\" \"<texto EN>\""
---

# Añadir textos traducidos

1. **Clave:** camelCase, en inglés y con prefijo por área (`editor…`, `placement…`, `complete…`, `delete…`, `list…`, `attach…`, `url…`, `settings…`, `a11y…`, `err…`). Comprueba que no existe ya una equivalente.
2. **Texto:** si viene de una spec, cópialo **exacto** de su tabla "Textos (ES / EN)". Si es nuevo, redáctalo en ES con el tono del prototipo (directo, cercano, sin tecnicismos) y tradúcelo a EN natural (no literal). Usa los términos de `docs/glossary.md`.
3. Añádelo a `app/lib/l10n/app_es.arb` **y** `app_en.arb`:
   ```json
   "deleteBody": "«{label}» desaparecerá sin marcarse como hecha.",
   "@deleteBody": {
     "description": "Cuerpo de la confirmación de eliminar (spec 004, CA-004-01)",
     "placeholders": { "label": { "type": "String", "example": "Comprar pan" } }
   }
   ```
   Plurales con ICU: `"{count, plural, =1{…} other{…}}"`.
4. Etiquetas de accesibilidad: también son textos (clave con el prefijo `a11y`).
5. Si el texto no estaba en la spec, añádelo a su tabla de textos (y avisa de que la spec cambia).
6. `fvm flutter gen-l10n` y ejecuta `/i18n-check`.
