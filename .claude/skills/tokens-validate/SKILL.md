---
name: tokens-validate
description: Valida los design tokens (design/tokens.json), su contraste AA, la sincronización con el código generado y la ausencia de valores visuales sueltos en la app. Úsala tras tocar tokens, tema o UI.
---

# Validar los design tokens

1. `node tools/validate-tokens.mjs` → estructura, formato de colores, paletas de 5 colores y contraste AA de las combinaciones de texto. Debe terminar con ✅.
2. Si existe la app: regenera `app/lib/app/theme/tokens.g.dart` con su generador y comprueba que `git diff` queda vacío (el código generado debe estar sincronizado).
3. **Valores sueltos** en `app/lib/` (excepto `tokens.g.dart`):
   - Colores: `grep -rnE "Color\(0x|Colors\.[a-z]|#[0-9A-Fa-f]{6}" app/lib --include=*.dart | grep -v tokens.g.dart`
   - Duraciones de animación: `grep -rnE "Duration\(milliseconds: *[0-9]+" app/lib | grep -v tokens.g.dart`
   - Tamaños de fuente o espaciados literales en widgets de UI: revísalos y propón el token equivalente.
4. Si un valor del prototipo no tiene token, **añádelo a `tokens.json`** (con `$description`), actualiza `docs/design/tokens.md` y regenera; nunca lo metas a mano en el código.
5. Si cambias un color, revisa la tabla de contraste de `docs/design/tokens.md` y las desviaciones de `docs/design/prototype-deviations.md`.

Resultado: ✅ o la lista de problemas con archivo:línea y el token propuesto.
