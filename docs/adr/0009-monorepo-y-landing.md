# ADR-0009: Monorepo: app en `app/` y la landing futura en `landing/`

- **Estado:** **Sustituido por ADR-0029** (2026-11-18: la web sale a su propio repositorio, `svallev/una-web`). Antes: Aceptado. **Enmendado por el ADR-0027** (2026-11-13, spec 025): «ningún script de terceros» se lee «ningún programa servido desde otro origen ni que envíe datos; el código de terceros que vaya al navegador se decide en un ADR». La página de inicio de `landing/` lleva GSAP y Lenis, del propio origen; las otras cuatro páginas siguen sin JavaScript ni dependencias. **Enmendado por el ADR-0028** (2026-11-17, spec 026): las cuatro páginas de contenido (política, licencias, Ayuda y error) llevan **solo el programa propio de idioma** (`/lang.js`, escrito a mano, sin dependencias), con `script-src 'self'` y Trusted Types en su CSP; ningún programa de otro origen ni que envíe datos, y sin JavaScript se leen enteras
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
- La landing tendrá su propia política de cabeceras y **ningún script de terceros** (sin analítica por defecto; si algún día la hay, con consentimiento y sin cookies). **[Enmienda, ADR-0027]** Ver el estado: ningún programa de otro origen ni que envíe datos. **[Enmienda, ADR-0028]** Las cuatro páginas de contenido, solo el programa propio de idioma.

## Motivos

Tokens, marca, textos legales y documentación compartidos; una sola PR puede tocar las dos cosas; menos repos que mantener para una persona.

## Consecuencias

- Los comandos de Flutter se ejecutan dentro de `app/` (documentado en CLAUDE.md).
- Dos proyectos de Vercel conectados al mismo repo.
