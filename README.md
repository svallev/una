# Una.

> Nombre provisional. Se centraliza en un único sitio (`app/identity.yaml`); no se escribe en el código.

**Una app de tareas que solo te enseña una: la que toca ahora.**

- **Una cosa a la vez.** La pantalla principal muestra únicamente la primera tarea pendiente. Ver el resto requiere, a propósito, dos pasos.
- **Lo que necesitas, a pantalla completa al abrir.** Haz una foto del horario del festival, sube el PDF del congreso o guarda la web de la receta: al abrir la app está ahí, sin más toques y sin conexión.
- **Tuya y de nadie más.** Sin cuentas, sin servidor, sin analítica. Todo se queda en tu teléfono y funciona en modo avión.

## Estado

🛠️ **F5 Endurecimiento** (fase actual). La app Flutter está implementada en `app/` con las specs **001 a 024** hechas: primer uso, crear, completar, eliminar con deshacer, editar, listado y reordenar, adjuntos (varias fotos en carrusel, PDF y web), Ajustes, notificaciones, ocultar «Recientes», idioma ES/EN, modo siempre claro e iconos. Las specs 020 a 024 cubren la puerta de publicación, la auditoría en dispositivo y sus correcciones, la política de privacidad y la ficha de tienda. La web (landing y páginas de Privacidad, Licencias, Ayuda y error; specs 025 a 027) vive en su propio repositorio, [svallev/una-web](https://github.com/svallev/una-web) ([ADR-0029](docs/adr/0029-la-web-en-su-propio-repositorio.md)).

- **Android primero.** iOS se decidirá al final (no hay Xcode por ahora).
- **Sin publicar.** Es un proyecto personal de aprendizaje del ciclo completo: de momento no se sube a Google Play ni hay testers. Lo que falta para la primera subida es la lista cerrada de **F6** en [docs/PLAN.md](docs/PLAN.md).
- Fases, riesgos y decisiones: [docs/PLAN.md](docs/PLAN.md).

## Probar en línea

| Qué | Enlace |
|---|---|
| **App web de pruebas** (Flutter web, solo para probar; la app real es móvil) | [una-rho.vercel.app](https://una-rho.vercel.app) |
| **Web** (landing y páginas de contenido; repositorio [svallev/una-web](https://github.com/svallev/una-web)) | [una-web.vercel.app](https://una-web.vercel.app) |

Son entornos de prueba, no la publicación: ver [docs/PLAN.md](docs/PLAN.md) (F6) para lo que falta antes de publicar.

## Documentación

| Documento | Para qué |
|---|---|
| [specs/constitution.md](specs/constitution.md) | Principios que no se negocian y Definition of Done |
| [docs/PLAN.md](docs/PLAN.md) | Fases, hitos, riesgos, trazabilidad y decisiones pendientes |
| [specs/](specs/) | Especificaciones (001–024; las de la web, 025–027, en `svallev/una-web`) y plantillas; cada una con su `plan.md` y `tasks.md` |
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

Flutter (versión en `.fvmrc`), Dart, SQLite con drift, Riverpod; Android 8+ (API 26) e iOS 16+ (al final). La web vive en otro repositorio ([svallev/una-web](https://github.com/svallev/una-web)) y se aloja en Vercel. Justificación en [ADR-0001](docs/adr/0001-stack-tecnologico.md) y [ADR-0029](docs/adr/0029-la-web-en-su-propio-repositorio.md).

### Comandos

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift
flutter gen-l10n
flutter analyze --fatal-infos
flutter test

node tools/validate-tokens.mjs                 # tokens (desde la raíz)
node --test store/google-play/test/*.test.mjs && node store/google-play/check.mjs   # ficha de tienda
```

Con FVM, antepón `fvm` a `flutter` y `dart`. El detalle y las convenciones están en [CLAUDE.md](CLAUDE.md).

## Licencia

© 2026 Salvador Valle Vargas. **Todos los derechos reservados.** El código es visible, pero no se concede ninguna licencia de uso, copia, modificación ni distribución. Ver [LICENSE](LICENSE).
