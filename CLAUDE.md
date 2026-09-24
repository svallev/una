# CLAUDE.md

App móvil **local y sin conexión** que muestra **una sola tarea a la vez** y deja un único elemento (foto, PDF, web) a pantalla completa nada más abrirla. Sin servidor, sin cuentas y sin analítica. Nombre provisional: "Una." (nunca literal en el código: `AppIdentity` / clave l10n `appName`).

**Fase actual:** F0 (preparación), **Android primero** (D17: sin Xcode por ahora; iOS al final si se decide). **No hay código de la app.** No crees `app/` ni hagas spikes sin aprobación explícita (ver `docs/PLAN.md`).

## Lee primero

- `specs/constitution.md`: principios P1–P12 y Definition of Done. **Mandan sobre todo lo demás.**
- `docs/PLAN.md`: fases, riesgos, decisiones D1–D16 y pendientes.
- `docs/glossary.md`: términos ES ⇄ EN. Úsalos tal cual en el código y en los textos.
- La spec que estés implementando: `specs/NNN-*/spec.md` (+ `plan.md`, `tasks.md`).

## Flujo SDD (obligatorio)

spec (**Aprobada**) → plan → tareas → implementación con tests → verificación de los CA → DoD.
Skills: `/spec-new`, `/spec-implement NNN`, `/adr-new`, `/security-check`, `/i18n-check`, `/strings-add`, `/tokens-validate`, `/release-checklist`.
Subagentes: `spec-reviewer`, `security-reviewer`, `a11y-reviewer`, `test-writer`.
Si el código y la spec discrepan, **se para y se pregunta**; no se "arregla" la spec en silencio.

## Stack y comandos (a partir de F2; provisional según ADR-0001)

Flutter (versión en `.fvmrc`, con FVM) · Dart · drift/SQLite · Riverpod · iOS 16+ / Android 8+ (API 26).
Todo dentro de `app/`:

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # drift
fvm flutter gen-l10n
fvm dart format .
fvm flutter analyze --fatal-infos
fvm flutter test
fvm flutter test integration_test   # simulador/emulador
node ../tools/validate-tokens.mjs    # tokens (desde la raíz: node tools/validate-tokens.mjs)
```

## Convenciones

- **Idioma:** código, identificadores y commits en inglés; specs, ADR y documentación en español.
- **Commits y PR:** Conventional Commits (`feat(003): …`). Rama por tarea (`feat/NNN-…`). Squash a `main`.
- **Capas:** `presentation → state → domain ← data`. El dominio es Dart puro. Toda persistencia pasa por `TaskRepository` / `AttachmentStore`.
- **UI:** valores solo desde `design/tokens.json` → `tokens.g.dart`. Nada de `Color(0x…)` sueltos. Material 3 solo como base.
- **Textos:** todos en ARB ES + EN (incluidas las etiquetas de accesibilidad). Ninguno incrustado.
- **Accesibilidad:** cada gesto tiene su acción semántica; respeta reducir movimiento y el texto grande; objetivos táctiles ≥ 44.
- **Tests:** cada test cita su CA (`'CA-003-02: …'`). Relojes inyectables. Sin red en los tests.
- **Esquema de BD:** cualquier cambio = nueva `schemaVersion` + captura + test de migración.
- Distingue en los documentos **[Hecho] / [Suposición] / [Pendiente]**.

## Qué NO hacer

- No añadir analítica, crash reporting, SDK con red ni fuentes remotas (P4).
- No leer, crear ni mostrar secretos ni archivos de firma (`.env`, `*.jks`, `key.properties`, `*.p8`, `*.p12`, `*.mobileprovision`…). Los hooks propuestos en `docs/claude-code.md` lo bloquean (una vez instalados); no los esquives.
- No instalar skills, plugins ni servidores MCP **a nivel global** ni con confirmación automática (`-g`, `-y`). Solo a nivel de proyecto, **tras leer su contenido y explicárselo al propietario**, y con su "sí" explícito.
- No añadir dependencias sin cumplir `docs/security/threat-model.md §5` ni sin justificarlas en la PR.
- No hacer `git push`, crear repos, releases ni despliegues sin confirmación.
- No usar un bundle ID ni un package name definitivos: el dominio está **[Pendiente PD-2]**.
- No desviarse del prototipo (`design/prototype/`) sin registrarlo en `docs/design/prototype-deviations.md`.
