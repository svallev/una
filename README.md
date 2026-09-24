# Una.

> Nombre provisional. Se centraliza en un único sitio (`app/identity.yaml` cuando exista la app); no se escribe en el código.

**Una app de tareas que solo te enseña una: la que toca ahora.**

- **Una cosa a la vez.** La pantalla principal muestra únicamente la primera tarea pendiente. Ver el resto requiere, a propósito, dos pasos.
- **Lo que necesitas, a pantalla completa al abrir.** Haz una foto del horario del festival, sube el PDF del congreso o guarda la web de la receta: al abrir la app está ahí, sin más toques y sin conexión.
- **Tuya y de nadie más.** Sin cuentas, sin servidor, sin analítica. Todo se queda en tu teléfono y funciona en modo avión.

## Estado

🧭 **Planificación cerrada** (2026-09-24). Aún no hay código de la app. Siguiente fase: **F0 Preparación** → **F1 Spikes**. Ver [docs/PLAN.md](docs/PLAN.md).

## Documentación

| Documento | Para qué |
|---|---|
| [specs/constitution.md](specs/constitution.md) | Principios que no se negocian y Definition of Done |
| [docs/PLAN.md](docs/PLAN.md) | Fases, hitos, riesgos, trazabilidad y decisiones pendientes |
| [specs/](specs/) | Especificaciones del MVP (001–010) y plantillas |
| [docs/adr/](docs/adr/) | Decisiones de arquitectura |
| [docs/architecture.md](docs/architecture.md) | Capas, arranque, modelo de datos (Mermaid) |
| [docs/security/](docs/security/) | Modelo de amenazas y checklist de seguridad |
| [docs/design/](docs/design/) | Tokens, mapa de pantallas del prototipo y desviaciones |
| [docs/glossary.md](docs/glossary.md) | Términos de dominio ES ⇄ EN |
| [docs/testing.md](docs/testing.md) · [docs/environments.md](docs/environments.md) | Estrategia de tests y entornos |
| [CLAUDE.md](CLAUDE.md) · [docs/claude-code.md](docs/claude-code.md) | Cómo trabaja Claude Code en este repo (skills, subagentes, permisos y hooks) |

## Estructura

```
app/        App Flutter (se crea en F2)
design/     tokens.json (fuente única) y copia del prototipo
docs/       Plan, ADR, arquitectura, seguridad, diseño
specs/      Constitución, specs NNN-nombre/{spec,plan,tasks}.md y plantillas
.claude/    Skills, subagentes, hooks y permisos del proyecto
.github/    CI, plantillas y Dependabot
```

## Stack (provisional)

Flutter (iOS 16+ / Android 8+), SQLite con drift, web de pruebas en Vercel. Justificación en [ADR-0001](docs/adr/0001-stack-tecnologico.md).

## Licencia

© 2026 Salvador Valle Vargas. **Todos los derechos reservados.** El código es visible, pero no se concede ninguna licencia de uso, copia, modificación ni distribución. Ver [LICENSE](LICENSE).
