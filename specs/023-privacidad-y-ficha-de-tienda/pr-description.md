# PR: spec 023, Privacidad y ficha de tienda

**Título:** `feat(023): privacy policy, Data Safety, store listing and static website, all ready for F6`

## Qué y por qué

Última spec de F5 antes de la corrección 024. Deja **todo listo y comprobado** para publicar en Google Play sin publicar nada (proyecto de aprendizaje: ni tienda ni testers por ahora). **Sin cambios en la app** salvo el nombre derivado de la identidad («Una» sin punto, T-023-07b): no hay `lib/` nuevo, ni ARB, ni esquema de BD, ni permisos, ni dependencias.

- **Spec:** `specs/023-privacidad-y-ficha-de-tienda/spec.md`. Estado: **Implementada**.
- **Tareas:** T-023-01 a T-023-13 (con la 07b). **CA cubiertos:** CA-023-01 a 24.
- **ADR nuevos o afectados:** ninguno nuevo (ADR-0009, 0010 y 0026 aplicados).

## Qué cambia

- **Puerta de publicación (020):** lista cerrada de huecos de identidad (`[RESPONSABLE]`, `[CONTACTO]`, `[FECHA]`, `[WEB]`) y cualquier otro texto entre corchetes → fallo (CA-023-01); regla `build-paths` contra rutas personales del equipo de compilación (H-2 de la 020); presupuesto de **20 MB** y paso `gradle-wrapper` en `release.yml` (C-5 de la 020).
- **`docs/legal/privacy-policy.md`:** sin suposiciones ni marcas, con las notas de revisión y su fuente; secciones nuevas «Esta web» y «Enlaces y otras apps»; 16 años; autorrelleno, red local, referente y copias.
- **`store/google-play/`:** `data-safety.md` (**«no recoge ni comparte datos»**, 13 flujos) y `play-console.md`; ficha ES/EN, gráfico de funciones (*golden*) y 4 capturas por idioma; `check.mjs` (permisos ↔ política ↔ lista blanca, textos e imágenes).
- **`landing/`:** web estática sin JavaScript, cookies ni terceros: inicio, `/privacy`, `/licenses`, `/help` y 404, en ES + EN; `serve.mjs` local; cabeceras en `vercel.json`. **Provisional**: la web del producto la sustituirá.
- **CI:** `tools/ci-detect.sh` (falla cerrada) y trabajo «Web y ficha» en `ci.yml`. **Nada se despliega.**
- **Documentación:** `docs/PLAN.md` (PD-9 resuelta; lista cerrada de F6, 11 puntos), `threat-model.md` v1.9 (T-18), `checklist.md`, `/release-checklist`, glosario, `screen-map`, DEV-58, `architecture.md`, enmiendas de las specs 020 y 023.

## Cómo se ha verificado

- `flutter analyze --fatal-infos` limpio; `dart format` sin cambios; `flutter test` **4484 verdes** (222 omitidos).
- `node --test landing/test/*.test.mjs store/google-play/test/*.test.mjs`: **508 verdes**; mutaciones en cada tarea (sin supervivientes salvo equivalentes anotados).
- `node landing/build.mjs && node landing/check.mjs` y `node store/google-play/check.mjs` en verde; `node tools/validate-tokens.mjs` en verde.
- `tools/check-release-config.sh` sobre el repositorio: solo los **huecos de identidad** esperados (se rellenan en F6).
- Emulador de API 37: capturas de la tienda; navegador: teclado, espaciado 1.4.12, reflujo y texto al 200 % (`dispositivo.md`).
- Revisores del cierre (`spec-reviewer`, `a11y-reviewer`, `security-reviewer`): **sin hallazgos altos**; los medios y bajos están en `tasks.md` y `dispositivo.md`.

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (salvo lo sin verificar de abajo)
- [ ] CI en verde (format, analyze, test, migraciones, l10n, tokens, builds): **se comprueba al abrir la PR**; el trabajo «Web y ficha» y `ci-detect.sh` no han corrido todavía en un *runner* real (no hay `actionlint`)
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código (sin ARB nuevos; los textos de la web son `landing/src/strings.json` y `help.{es,en}.md`)
- [x] Sin valores visuales sueltos (la web sale de los tokens; `validate-tokens` en verde)
- [x] Accesibilidad revisada (`a11y-reviewer`: sin fallos AA; opcionales en `dispositivo.md`)
- [x] Documentación actualizada
- [x] Rendimiento del arranque sin degradar (no toca el arranque)

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados T-9, T-11, T-13 y T-18 y los apartados de CI, importación y privacidad; `security-reviewer` sin hallazgos altos.
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas en la app.

## Aceptado, sin verificar y pendiente

- **Sin verificar, aceptado por el propietario (2026-10-20):** C-023-1 (revisión de las 8 capturas y el gráfico), TalkBack con la web y C-023-4 (la app solo abre `https`).
- **Pendiente del propietario:** visto bueno final de la política (T-023-05); decidir qué hallazgos de los revisores (M-1 de seguridad, B-1 a B-8) van a la 024 y cuáles a F6; confirmar las enmiendas de CA-023-18 (los archivos que leen tests de `app/` disparan también la app) y CA-023-20 (el tamaño por APK lo escribe `check-size.sh`).
- **F6:** lista cerrada de 11 puntos en `docs/PLAN.md` y `/release-checklist` (dominio y *package name*, huecos, cuenta de Play y 12 testers × 14 días, Vercel, Data Safety y Play Console, **revisión legal bloqueante**, avisos de la versión, firma, repositorio, web que se publique, «Recientes»).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
