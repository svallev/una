## Qué y por qué

<!-- Resumen breve. Título de la PR en formato Conventional Commits: feat(003): … -->

- **Spec:** `specs/NNN-…/spec.md`
- **Tareas:** T-NNN-…
- **Criterios de aceptación cubiertos:** CA-NNN-…
- **ADR nuevos o afectados:** —

## Cómo se ha verificado

<!-- Tests añadidos (con los ID de CA), dispositivos y plataformas probados, capturas o goldens antes/después si hay UI. -->

## Definition of Done (`specs/constitution.md`)

- [ ] Criterios de aceptación cumplidos y con tests en verde
- [ ] CI en verde (format, analyze, test, migraciones, l10n, tokens, builds)
- [ ] Textos nuevos en ES y EN; ninguno incrustado en el código
- [ ] Sin valores visuales sueltos (todo sale de los tokens)
- [ ] Accesibilidad: semántica, alternativas a gestos, contraste, texto grande, reducir movimiento
- [ ] Documentación actualizada (spec, ADR, glosario, arquitectura)
- [ ] Rendimiento del arranque sin degradar (si toca el arranque: medición adjunta)

## Seguridad ([checklist](../docs/security/checklist.md))

- [ ] Revisados los apartados que aplican (indica cuáles): …
- [ ] Sin secretos, permisos nuevos ni llamadas de red nuevas (o justificados abajo)

## Nueva dependencia (si aplica)

| Paquete | Versión | Motivo | Licencia | Mantenimiento | Telemetría | Alternativa descartada |
|---|---|---|---|---|---|---|
