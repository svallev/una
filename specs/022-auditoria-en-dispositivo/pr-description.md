# PR: spec 022, Auditoría en dispositivo

**Título:** `docs(022): on-device audit of F5 specs, 178 checks, 7 findings, none high`

## Qué y por qué

Tercera spec de F5. **Solo verifica**: pasa por el emulador (API 37) y por el Xiaomi 15T Pro (HyperOS 3) las casillas de dispositivo que dejaron las specs 011 y 013–021, y anota el resultado de cada una. **No cambia código** (CA-022-05): lo que falla es un hallazgo y va a la spec de corrección **024**.

- **Spec:** `specs/022-auditoria-en-dispositivo/spec.md`. Estado: **Implementada**.
- **Tareas:** T-022-01 a T-022-15. **CA cubiertos:** CA-022-01 a 33 (tabla CA → evidencia en `informe.md`).
- **Commit auditado:** `2e835cf` (cabeza de `main`, spec 021). Ningún cambio de `app/` entró en `main` durante la auditoría.
- Sin ADR nuevo, sin esquema de BD, permisos, dependencias ni textos.

## Resultado

- **178 casillas** con resultado en `specs/022-auditoria-en-dispositivo/informe.md`: **110 Pasa**, **7 Pasa con límite**, **29 Aceptada** (por el propietario o con el resultado del emulador), **26 Cerrada sin verificar** (Android 8 y 12L, otras marcas y lectores, tablets: decisión del propietario) y **6 Falla**.
- **10 hallazgos (H-022-01 a 10), ninguno alto**: la beta (F6) no queda bloqueada (CA-022-33).
  - **Cerrados (Aceptados por el propietario):** **H-022-01** (013, media), **H-022-08** (021, baja: el *splash* toma el color del tema con iconos con tema) y **H-022-09** (021, baja: destello blanco al arrancar desde la notificación).
  - **Abiertos, a la 024:** **H-022-02** (019, media: con TalkBack, 200 % y tres botones el aviso de bloqueo no se anuncia) y **H-022-03** (019, media: TalkBack lee la notificación con la voz del sistema, sin respetar el `LocaleSpan`); bajos **H-022-04 y 05** (021: iconos oscuros de las barras sobre la hoja y la card de deshacer) **H-022-06 y 07** (019: arranque automático con la app cerrada en HyperOS y retención de la notificación de las 18:55) y **H-022-10** (015: con `ca-ES, en-US` la app sale en inglés).
- **Estado de las specs (CA-022-31):** 011 (con casillas cerradas sin verificar), 013–018 y 021 pasan a **Implementada**; la **019 sigue Implementada parcialmente** (H-022-02 y 03); la 012 sigue Sustituida por la 015.
- Trabajo de publicación en modo testers en verde sobre `2e835cf` (ejecución 38874734623).

## Qué cambia

- `specs/022-auditoria-en-dispositivo/`: spec, plan, tareas, informe e inventario.
- La sección «Auditoría 022» al final del `dispositivo.md` de 007, 011–019 y 021, y las cabeceras de estado de esas specs.
- `docs/PLAN.md` (casillas con resultado, PD-10 cerrada, PD-11 aplazada, R-24 a 26, fila de F5 y §9 → 023, trazabilidad), `docs/glossary.md` (términos de la auditoría), `docs/perf/baseline.md`, `docs/security/threat-model.md`, `checklist.md`, `docs/testing.md`, ADR-0019 y 0021 (notas, sin cambiar la decisión), `020/mastg.md` (O-1) y `CLAUDE.md`.
- **Enmiendas de la spec (propietario, 2026-10-19):** CA-022-05 permite las skills de proyecto `caveman` y `ponytail`; CA-022-15 deja `eu` sin auditar; CL-021-10 de la 021 recoge H-022-08.
- **Nota sobre CA-022-05:** el diff también incluye el commit `f8626f0` (`chore: add caveman and ponytail skills`: `.agents/skills/`, enlaces en `.claude/skills/` y `skills-lock.json`), instalados a nivel de proyecto por el propietario tras leer su contenido (solo texto, sin scripts ni red; anotado en `docs/claude-code.md` §3). No toca `app/`, `tools/`, `design/` ni `.github/`.

## Verificación

- `git diff --stat main...HEAD -- app tools design .github` vacío; sin capturas, volcados ni archivos de firma del Xiaomi en el repositorio.
- Inventario sin filas vacías; `docs/PLAN.md` sin **[Pendiente]** sin resultado en «Casillas de la 0NN».
- Xiaomi restaurado (la `.profile` desinstalada y `Prueba022` borrada, comprobado por el propietario). Pendiente suyo, sin bloquear: borrar a mano los dos interruptores de Switch Access.

## Aceptado y pendiente

- **Aceptado (propietario):** H-022-01; la voz de los anuncios con `ca`/`gl` (voz del sistema, ADR-0020/0023); Voice Access no instalado; CA-022-25 con lo hecho en el emulador; iconos con tema (el *splash* toma el color del tema).
- **Pendiente:** spec de corrección **024** (H-022-02 a 07 y los hallazgos de código conocidos de `informe.md` §5); después **023** privacidad y ficha de tienda.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
