# ADR-0009: Monorepo: app en `app/` y la landing futura en `landing/`

- **Estado:** Aceptado
- **Fecha:** 2026-09-24

## Contexto

- **[Hecho]** Habrá una landing centrada en las dos propuestas de valor, con la misma identidad visual.
- **[Hecho]** Repositorio público (D3) con CI y Vercel.

## Decisión

Un único repositorio:

```
/app          App Flutter (se crea en F2)
/landing      Landing estática (futuro; Astro o HTML), otro proyecto de Vercel con "Root Directory: landing"
/design       tokens.json y la copia del prototipo
/docs, /specs Documentación y specs
```

- Los tokens de `design/tokens.json` generan Dart para la app y variables CSS para la landing.
- CI con filtros por ruta: los jobs de la app solo se ejecutan si cambian `app/**`, `design/**` o los workflows.
- La landing tendrá su propia política de cabeceras y **ningún script de terceros** (sin analítica por defecto; si algún día la hay, con consentimiento y sin cookies).

## Motivos

Tokens, marca, textos legales y documentación compartidos; una sola PR puede tocar las dos cosas; menos repos que mantener para una persona.

## Consecuencias

- Los comandos de Flutter se ejecutan dentro de `app/` (documentado en CLAUDE.md).
- Dos proyectos de Vercel conectados al mismo repo.
