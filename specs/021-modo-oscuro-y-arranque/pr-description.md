# PR: spec 021, Modo oscuro y arranque

**Título:** `feat(021): light-only app with paper launch screen, clean system bars and undarkened WebView`

## Qué y por qué

Segunda spec de F5. La app **se ve siempre igual, en claro**, con el sistema en claro o en oscuro (Q-021-1, P12: la identidad de papel no tiene versión oscura), y **el arranque ya es la app**: fondo `paper` y la «u.» negra del icono, en lugar del blanco o el negro del sistema. Nada de lo que pinta el sistema alrededor (barras, fondo de la ventana, páginas web) cambia de aspecto con el modo.

- **Spec:** `specs/021-modo-oscuro-y-arranque/spec.md`. Estado: **Implementada parcialmente** (casillas de Android 8–11 y del Xiaomi a la 022, en `docs/PLAN.md` «Casillas de la 021»).
- **Tareas:** T-021-01 a T-021-09. **CA cubiertos:** CA-021-01 a 12 (los de apariencia, con casilla en `dispositivo.md`).
- **ADR:** ninguno nuevo; enmienda del ADR-0019 y de CA-011-03 (el fotograma de la vuelta sin instantánea puede ser `paper`; nunca negro). Constitución 1.10, sin excepciones. **DEV-57** en `prototype-deviations.md`.
- **Sin** esquema de BD, permisos, dependencias, textos ni cambios en los iconos (sumas comprobadas por test).

## Qué cambia

- **Tema único claro** en `res/` (`colors.xml` con `paper`, `UnaWindow`/`UnaBars`, `values-v27`), *splash* de Android 12+ con la «u.» sin círculo, `forceDarkAllowed=false`; se borran `values-night/` y los dos `launch_background.xml`.
- **Barras del sistema:** `AnnotatedRegion` en `appFrame` (transparentes, iconos oscuros, sin velo) y `themeMode: light`; la enhorabuena, con fondo `ink` a sangre, pide iconos claros (`lib/app/system_bars.dart`).
- **WebView:** oscurecimiento apagado (API 33+: `isAlgorithmicDarkeningAllowed=false`; API 29–32: `forceDark` apagado) y vigilado por `noDarkening` en `state()`; sin `androidx.webkit`, orden de `harden` intacto (ADR-0017).
- **Tests:** `launch_theme`, `icon_checksums`, `system_bars`, `webview_dark`, `dark_mode_state` y `dark_mode_golden` (las 10 suites de *goldens* con el brillo en oscuro contra los mismos PNG).

## Verificación

- `dart format`, `flutter analyze --fatal-infos`, `flutter test` (4289), `validate-tokens` y `gen_icons --check` en verde; `webview_hardening_test` 4/4 en el emulador.
- Emulador API 37: arranque en frío 10/10 por modo sin fotogramas blancos ni negros; cambio de modo con la app delante sin diferencia; contraste de iconos ≥ 3:1; `check-recents.sh` en verde; arranque en frío +1,5 ms (claro) y +5,5 ms (oscuro) frente a `main`, dentro de la deriva.
- `security-reviewer`: 0 altos ni medios. `a11y-reviewer`: 0 altos; el medio de la enhorabuena, corregido; la card de deshacer con tres botones (3,3:1), a la 022.

## Aceptado y pendiente

- **Aceptado (propietario):** un fotograma negro al entrar en pantalla dividida (límite del motor, igual en `main`; CA-021-05).
- **Pendiente, 022:** Android 8–11 (PD-10), Xiaomi (CL-021-7 y 9, arranque, iconos de las barras con la enhorabuena y la card), icono con tema, TalkBack real, *goldens* en oscuro en la CI (Linux) y trabajo de publicación en modo testers.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
