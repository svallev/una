# CLAUDE.md

App móvil **local y sin conexión** que muestra **una sola tarea a la vez** y deja su elemento (una foto o varias en carrusel, un PDF o una web) a pantalla completa nada más abrirla. Sin servidor, sin cuentas y sin analítica. Nombre provisional: "Una." (nunca literal en el código: sale de `app/identity.yaml` → `AppIdentity`).

**Fase actual:** **F5 Endurecimiento** (F4b terminada el 2026-10-13 con la 019; decisiones D20–D30 en `docs/PLAN.md`; diseño en el prototipo, tableros 12–17, copiado en `design/prototype/`). Una spec cada vez, en este orden:

- **Fusionadas en `main`:** 014 eliminar con deshacer (ADR-0021), 015 Ajustes (ADR-0023 y 0026; sustituye a la pantalla temporal de la 012), 016 varias imágenes con carrusel (esquema v3, ADR-0022 y 0024), 017 bloquear zoom, 018 iconos, 019 notificaciones (ADR-0025, PR #50), además de las 001–013. Las posteriores a la 011 quedan **Implementada parcialmente**: sus casillas de dispositivo van a la 022 y están en `docs/PLAN.md` («Casillas de la 014» … «Casillas de la 019»).
- **F5:** **020 seguridad y puerta de publicación** (`specs/020-seguridad-y-puerta-de-publicacion/`, CA-020-01 a 28): **Implementada** el 2026-10-14 (PR #53 y el arreglo #54; los dos modos del trabajo de publicación en GitHub sobre `4eafec4`, en `mastg.md`). **Siguiente: 021 modo oscuro y arranque** (spec **Aprobada** el 2026-10-15, `specs/021-modo-oscuro-y-arranque/`, CA-021-01 a 12: la app siempre en claro y el arranque en `paper`; falta el plan), después 022 auditoría en dispositivo (con las casillas de 011–019) y 023 privacidad y ficha de tienda.

**Lo que ya está en `main`, en una línea:** sin histórico (ADR-0012, esquema v3); la 007 sin visor de imágenes (ADR-0013); la 008 solo PDF (ADR-0014/0015); la 009 URL sin copia local ni navegación (ADR-0016/0017/0018); la 010 solo ES/EN (`ca-*` abre en español, `gl`/`eu` en inglés); la 011 oculta «Recientes» (ADR-0019; **falta PD-10**: Android 8 y 12L); la 013 deuda de accesibilidad (ADR-0020). **Android primero** (D17: sin Xcode por ahora; iOS al final si se decide). El código está en `app/`.

**Avisos que no se deben perder** (el detalle está en `docs/PLAN.md` y en cada spec): antes de entregar a testers se pasa `tools/check-recents.sh` (`docs/testing.md`); la revisión legal de las licencias de terceros (ADR-0026) bloquea `/release-checklist` antes de F6; **nada se publica ni se entrega a testers sin el trabajo de publicación en verde sobre ese commit** (`.github/workflows/release.yml`: modo testers a mano desde `main`, modo estricto con una etiqueta `vX.Y.Z`, que hoy falla siempre por los marcadores; spec 020); la consulta de autorrelleno de la WebView a Google (H-1 de la 020) está aceptada como riesgo (`threat-model.md` §7) y va a Data Safety (PD-9, 023); el pico de memoria del grupo de 10 fotos en el Xiaomi (+166 MB sobre una foto) está aceptado (ADR-0024); pendientes anotados: H-5 y H-6 (`specs/adr-0012-sin-historico/plan.md` §9), TD-1 y los hallazgos de la 012 y la 013 para la auditoría (`docs/PLAN.md`, «Hallazgos de la 012 para la auditoría de F5»). **No hagas spikes sin aprobación explícita** (ver `docs/PLAN.md`).

## Lee primero

- `specs/constitution.md`: principios P1–P12 y Definition of Done. **Mandan sobre todo lo demás.**
- `docs/PLAN.md`: fases, riesgos, decisiones D1–D30 y pendientes.
- `docs/glossary.md`: términos ES ⇄ EN. Úsalos tal cual en el código y en los textos.
- La spec que estés implementando: `specs/NNN-*/spec.md` (+ `plan.md`, `tasks.md`).

## Flujo SDD (obligatorio)

spec (**Aprobada**) → plan → tareas → implementación con tests → verificación de los CA → DoD.
Skills: `/spec-new`, `/spec-implement NNN`, `/adr-new`, `/security-check`, `/i18n-check`, `/strings-add`, `/tokens-validate`, `/release-checklist`, `/post-merge` (**tras cada PR fusionada**: ramas al día y espacio liberado con `tools/clean-workspace.sh`).
Subagentes: `spec-reviewer`, `security-reviewer`, `a11y-reviewer`, `test-writer` y `spec-task` (ejecuta una tarea T-NNN-XX de principio a fin; la sesión coordinadora lanza uno por tarea).
Si el código y la spec discrepan, **se para y se pregunta**; no se "arregla" la spec en silencio.
**Sesiones cortas:** una sesión para la spec, otra para el plan, las de implementación (coordinador + un `spec-task` por tarea, de una en una) y la de cierre. Cada una empieza desde los archivos; `tasks.md` (línea **Siguiente** y tabla **Estado**) es el traspaso. Ver `docs/claude-code.md §2.1`.

## Stack y comandos (a partir de F2; provisional según ADR-0001)

Flutter (versión en `.fvmrc`, con FVM) · Dart · drift/SQLite · Riverpod · iOS 16+ / Android 8+ (API 26).
Todo dentro de `app/`. Sin FVM en la máquina (como en este Mac), quita el prefijo `fvm`: es la misma versión que fija `.fvmrc`.

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
