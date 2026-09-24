---
name: i18n-check
description: Comprueba la internacionalización (textos incrustados, claves ES/EN, plurales, fechas, nombre de la app, coherencia con el glosario). Úsala tras tocar UI y antes de cada PR.
---

# Comprobación de i18n

Fuente de verdad: `app/lib/l10n/app_es.arb` (plantilla) y `app_en.arb`; términos en `docs/glossary.md`; textos de cada spec en su tabla "Textos (ES / EN)".

1. **Claves:** las dos ARB tienen exactamente las mismas claves; ningún valor vacío; los placeholders (`{count}`, `{text}`…) coinciden y tienen su `@clave` con `placeholders` y `description`.
2. **Plurales y selectores:** los recuentos usan ICU `plural`; nada de concatenaciones ("1 " + "tareas").
3. **Fechas y números:** se formatean con `intl` en el idioma activo; ninguna fecha construida a mano.
4. **Textos incrustados:** busca literales visibles en `app/lib/` fuera de `l10n/` (p. ej. `grep -rnE "Text\(\s*'[^']+'|semanticsLabel:\s*'|tooltip:\s*'|label:\s*'" app/lib`) y cualquier aparición del nombre de la app (`grep -rn "Una" app/lib`), que debe salir de `AppIdentity`/`appName`.
5. **Specs ↔ ARB:** cada clave de las tablas de textos de las specs implementadas existe en las ARB con el mismo texto (salvo cambio aprobado).
6. **Glosario:** los textos usan los términos del glosario ("tarea", no "nota"; "eliminar", no "borrar").
7. **Resolución del idioma:** existe un test que prueba `es-ES`, `es-MX`, `es-419` → es; `en-US`, `fr-FR`, `ca-ES`, `pt-BR` → en; y la preferencia manual.

Resultado: lista de problemas con archivo:línea y la corrección propuesta (usa `/strings-add` para añadir textos).
