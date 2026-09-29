# CLAUDE.md

App móvil **local y sin conexión** que muestra **una sola tarea a la vez** y deja un único elemento (foto, PDF, web) a pantalla completa nada más abrirla. Sin servidor, sin cuentas y sin analítica. Nombre provisional: "Una." (nunca literal en el código: `AppIdentity` / clave l10n `appName`).

**Fase actual:** F4 (adjuntos), **Android primero** (D17: sin Xcode por ahora; iOS al final si se decide). El código de la app está en `app/`: en `main` están las specs 001–008 y el ADR-0012 (sin histórico; esquema v2). La 007 no tiene visor de imágenes (ADR-0013); la 008 es **solo PDF** en la v1 (ADR-0014/0015), fusionada el 2026-09-28 (PR svallev/una#14). **Siguiente:** implementar la spec 009 (URL), aprobada con su plan el 2026-09-28 (ADR-0016: sin copia local; excepción a P3; ADR-0017: envoltorio del `WebViewClient` ante el fallo del proceso de la página; **ADR-0018, 2026-09-29: sin navegación, solo la dirección guardada; sin PSL**), en la rama `feat/009-adjunto-url` (sin push): T-009-01..10 hechas; seguir por T-009-11 (tarea actual web: barra, WebView con `WebPageController`, indicador y avisos; ver los pendientes de la fila de T-009-10). Pendientes anotados: H-5 y H-6 (`specs/adr-0012-sin-historico/plan.md` §9) y los puntos de la auditoría de F5 (`docs/PLAN.md`). No hagas spikes sin aprobación explícita (ver `docs/PLAN.md`).

## Lee primero

- `specs/constitution.md`: principios P1–P12 y Definition of Done. **Mandan sobre todo lo demás.**
- `docs/PLAN.md`: fases, riesgos, decisiones D1–D16 y pendientes.
- `docs/glossary.md`: términos ES ⇄ EN. Úsalos tal cual en el código y en los textos.
- La spec que estés implementando: `specs/NNN-*/spec.md` (+ `plan.md`, `tasks.md`).

## Flujo SDD (obligatorio)

spec (**Aprobada**) → plan → tareas → implementación con tests → verificación de los CA → DoD.
Skills: `/spec-new`, `/spec-implement NNN`, `/adr-new`, `/security-check`, `/i18n-check`, `/strings-add`, `/tokens-validate`, `/release-checklist`.
Subagentes: `spec-reviewer`, `security-reviewer`, `a11y-reviewer`, `test-writer` y `spec-task` (ejecuta una tarea T-NNN-XX de principio a fin; la sesión coordinadora lanza uno por tarea).
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
- **Tests que miden (anchos, desbordamientos, texto al 200 %, contraste, goldens):** empiezan con `setUpAll(loadAppFonts)` (`test/support/fonts.dart`). Sin ella, Flutter usa su fuente de pruebas, en la que cada letra mide 1 em: salen desbordamientos que no existen. Un desbordamiento visto sin las fuentes reales no es un fallo. Al revés, `textContrastGuideline` puede fallar en falso con las fuentes reales en texto pequeño (trazos finos): el contraste lo garantiza `validate-tokens`.
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
