# Una.

> Nombre provisional. Se centraliza en un único sitio (`app/identity.yaml`); no se escribe en el código.

**Una app de tareas que solo te enseña una: la que toca ahora.**

- **Una cosa a la vez.** La pantalla principal muestra únicamente la primera tarea pendiente. Ver el resto requiere, a propósito, dos pasos.
- **Lo que necesitas, a pantalla completa al abrir.** Haz una foto del horario del festival, sube el PDF del congreso o guarda la web de la receta: al abrir la app está ahí, sin más toques y sin conexión.
- **Tuya y de nadie más.** Sin cuentas, sin servidor, sin analítica. Todo se queda en tu teléfono y funciona en modo avión.

## Estado

🛠️ **F5 Endurecimiento** (fase actual). La app Flutter está implementada en `app/` con las specs **001 a 026** hechas: primer uso, crear, completar, eliminar con deshacer, editar, listado y reordenar, adjuntos (varias fotos en carrusel, PDF y web), Ajustes, notificaciones, ocultar «Recientes», idioma ES/EN, modo siempre claro, iconos, y la web (landing y páginas de contenido). Las specs 020 a 024 cubren la puerta de publicación, la auditoría en dispositivo y sus correcciones; la 025 y la 026 son la landing y las páginas de contenido (Privacidad, Licencias, Ayuda y error).

- **Android primero.** iOS se decidirá al final (no hay Xcode por ahora).
- **Sin publicar.** Es un proyecto personal de aprendizaje del ciclo completo: de momento no se sube a Google Play ni hay testers. Lo que falta para la primera subida es la lista cerrada de **F6** en [docs/PLAN.md](docs/PLAN.md).
- Fases, riesgos y decisiones: [docs/PLAN.md](docs/PLAN.md).

## Probar en línea

| Qué | Enlace |
|---|---|
| **App web de pruebas** (Flutter web, solo para probar; la app real es móvil) | [una-rho.vercel.app](https://una-rho.vercel.app) |
| **Landing** (vista previa; huecos de identidad aún sin rellenar, contacto provisional) | [una-landing-git-web-preview-salvadorvalle-8227s-projects.vercel.app](https://una-landing-git-web-preview-salvadorvalle-8227s-projects.vercel.app) |

Son entornos de prueba, no la publicación: ver [docs/PLAN.md](docs/PLAN.md) (F6) para lo que falta antes de publicar.

## Documentación

| Documento | Para qué |
|---|---|
| [specs/constitution.md](specs/constitution.md) | Principios que no se negocian y Definition of Done |
| [docs/PLAN.md](docs/PLAN.md) | Fases, hitos, riesgos, trazabilidad y decisiones pendientes |
| [specs/](specs/) | Especificaciones (001–026) y plantillas; cada una con su `plan.md` y `tasks.md` |
| [docs/adr/](docs/adr/) | Decisiones de arquitectura |
| [docs/architecture.md](docs/architecture.md) | Capas, arranque, modelo de datos (Mermaid) |
| [docs/security/](docs/security/) | Modelo de amenazas y checklist de seguridad |
| [docs/design/](docs/design/) | Tokens, mapa de pantallas del prototipo y desviaciones |
| [docs/glossary.md](docs/glossary.md) | Términos de dominio ES ⇄ EN |
| [docs/testing.md](docs/testing.md) · [docs/environments.md](docs/environments.md) | Estrategia de tests y entornos |
| [CLAUDE.md](CLAUDE.md) · [docs/claude-code.md](docs/claude-code.md) | Cómo trabaja Claude Code en este repo (skills, subagentes, permisos y hooks) |
| [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) | Cómo se trabaja y cómo avisar de un problema de seguridad |

## Estructura

```
app/        App Flutter (identidad en app/identity.yaml)
landing/    Web estática: landing de producto, Privacidad, Licencias, Ayuda y error
store/      Ficha de Google Play (textos, Data Safety, capturas)
design/     tokens.json (fuente única) y copia del prototipo
docs/       Plan, ADR, arquitectura, seguridad, diseño, textos legales
specs/      Constitución, specs NNN-nombre/{spec,plan,tasks}.md y plantillas
tools/      Comprobaciones de publicación, limpieza y validación de tokens
spikes/     Pruebas técnicas de las primeras fases
.claude/    Skills, subagentes, hooks y permisos del proyecto
.github/    CI, plantillas y Dependabot
```

## Stack (provisional)

Flutter (versión en `app/.fvmrc`), Dart, SQLite con drift, Riverpod; Android 8+ (API 26) e iOS 16+ (al final). La web (`landing/`) es Node sin dependencias para las páginas de contenido y Vite, GSAP y Lenis para la landing; se aloja en Vercel. Justificación en [ADR-0001](docs/adr/0001-stack-tecnologico.md), [ADR-0009](docs/adr/0009-monorepo-y-landing.md) y [ADR-0027](docs/adr/0027-landing-con-vite-gsap-y-lenis.md).

### Comandos

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift
flutter gen-l10n
flutter analyze --fatal-infos
flutter test

node tools/validate-tokens.mjs                 # tokens (desde la raíz)
node landing/build.mjs && node landing/check.mjs && node --test landing/test/*.test.mjs   # web
```

Con FVM, antepón `fvm` a `flutter` y `dart`. El detalle y las convenciones están en [CLAUDE.md](CLAUDE.md).

## Licencia

© 2026 Salvador Valle Vargas. **Todos los derechos reservados.** El código es visible, pero no se concede ninguna licencia de uso, copia, modificación ni distribución. Ver [LICENSE](LICENSE).
