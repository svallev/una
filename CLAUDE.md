# CLAUDE.md

App móvil **local y sin conexión** que muestra **una sola tarea a la vez** y deja un único elemento (foto, PDF, web) a pantalla completa nada más abrirla. Sin servidor, sin cuentas y sin analítica. Nombre provisional: "Una." (nunca literal en el código: sale de `app/identity.yaml` → `AppIdentity`).

**Fase actual:** F5 (endurecimiento), troceada el 2026-10-01 en las specs 013–017 (`docs/PLAN.md`, tras "Hallazgos de la 012"); la **013 (deuda de accesibilidad del código)** está en **Borrador**. **Android primero** (D17: sin Xcode por ahora; iOS al final si se decide). El código de la app está en `app/`: en `main` están las specs 001–010 y el ADR-0012 (sin histórico; esquema v2). La 007 no tiene visor de imágenes (ADR-0013); la 008 es **solo PDF** en la v1 (ADR-0014/0015). La **009 (URL)** está fusionada (2026-09-29, PR svallev/una#17): sin copia local (ADR-0016, excepción a P3), envoltorio del `WebViewClient` (ADR-0017) y sin navegación, solo la dirección guardada, sin PSL (ADR-0018); limitaciones de a11y de T-009-21 aceptadas. La **010 (idioma automático)** está fusionada (2026-09-29, PR svallev/una#18): solo ES/EN, lo decide el sistema, sin selector; el catalán (`ca-*`) abre en español (propietario, 2026-09-30) y gl/eu en inglés; `appFrame` marca el contenido con `localeForSubtree` para que TalkBack use la voz del idioma de la app; "Configuración y perfil" era solo texto (desde la 012 es un botón, ver abajo). Verificación manual en el emulador en `specs/010-idioma-y-configuracion/tasks.md`; la voz real se comprobó a oído en el móvil (propietario). La **011 (ocultar el contenido en "Recientes")** está **Implementada parcialmente** (2026-09-30, fusionada en `main`, PR svallev/una#20; ADR-0019): nativo (`RecentsPrivacy.kt`), sin Dart, ajustes ni dependencias; A en Android 13+ y B en 8-12; verificada en el emulador de API 37 y, para la tarjeta, en el Xiaomi (HyperOS la respeta); **falta PD-10 / T-011-09** (emuladores de Android 8 y 12L, antes de la beta). Límites aceptados: fotograma blanco al volver, "Recientes" abierto desde la propia app y hoja parcial del selector de fotos; antes de entregar a testers se pasa `tools/check-recents.sh` (`docs/testing.md`). La **012 (pantalla temporal de "Configuración y perfil")** está fusionada en `main` (**Implementada parcialmente**, 2026-09-30, PR [svallev/una#22](https://github.com/svallev/una/pull/22); descripción en `specs/012-configuracion-temporal/pr-description.md`): tres niveles a pantalla completa sobre el menú (opciones, lista de licencias de código abierto y texto de una licencia, en inglés y sin enlaces) y la política de privacidad, que tras confirmarlo abre **una dirección `https` en el navegador** (hoy el marcador `https://example.com/privacy`; la puerta `tools/check-release-config.sh` impide publicarla así, PD-2). Sin permisos, esquema ni dependencias nuevas; `tools/check-licenses.sh` (en CI) comprueba que no falta ninguna licencia; DEV-18 cerrada y DEV-49 (temporal). Verificada en el emulador de API 37 (`specs/012-configuracion-temporal/dispositivo.md`) y la voz de CA-012-07 a oído por el propietario; **[Pendiente]** foco de TalkBack al volver, anuncio de carga/Reintentar, anillo de foco con teclado real, Switch Access (los *goldens* ya están subidos; p90 de raster y arranque, medidos en el Xiaomi: sin problema). **Siguiente:** que el propietario apruebe la spec 013 (`specs/013-deuda-accesibilidad/spec.md`) y, en otra sesión, su plan; TD-1 va en una PR `chore` aparte; las casillas manuales de la 011 y la 012 se cierran en la auditoría en dispositivo (spec 016); los hallazgos sin corregir de la 012 están en `docs/PLAN.md` ("Hallazgos de la 012 para la auditoría de F5"). **Sigue sin haber Configuración completa en la beta** (propietario, 2026-09-29): el idioma, la pantalla encendida y el resto esperan a una spec futura con diseño del propietario, que sustituirá a la pantalla temporal. Pendientes anotados: H-5 y H-6 (`specs/adr-0012-sin-historico/plan.md` §9), TD-1 y los puntos de la auditoría de F5 (`docs/PLAN.md`). No hagas spikes sin aprobación explícita (ver `docs/PLAN.md`).

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
**Sesiones cortas:** una sesión para la spec, otra para el plan, las de implementación (coordinador + un `spec-task` por tarea, de una en una) y la de cierre. Cada una empieza desde los archivos; `tasks.md` (línea **Siguiente** y tabla **Estado**) es el traspaso. Ver `docs/claude-code.md §2.1`.

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
