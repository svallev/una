# ADR-0029: La web en su propio repositorio (svallev/una-web), con copias de lo que toma de la app

- **Estado:** Aceptado (propietario, 2026-11-18). **Sustituye al ADR-0009** (monorepo `app/` + `landing/`). Enmienda la spec 023 (CA-023-13 a 18 y la parte web de CA-023-04 y 23: se trasladan) y el ADR-0026 (la web de licencias vive en el repositorio nuevo; la decisión no cambia).
- **Fecha:** 2026-11-18
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** ADR-0009, ADR-0010 (web de pruebas de Flutter, sin cambios), ADR-0026; ADR-0027 y ADR-0028 (trasladados); specs 023, 025, 026 y 027 (las tres últimas, trasladadas); fila de F6 en `docs/PLAN.md`

## Contexto

- **[Hecho]** Desde la 023, la web (`landing/`: página de inicio con Vite, GSAP y Lenis; Privacidad, Licencias, Ayuda y 404) vivía en este repositorio, como decidió el ADR-0009 («una sola fuente de nombre, tokens, textos y política»). El ADR-0027 descartó el repositorio aparte por ese mismo criterio.
- **[Hecho]** El propietario (2026-11-18): cambiar la web era lento y engorroso. Cada PR de la web arrastraba la CI de la app y tardaba mucho. Para tener una URL pública, el proyecto de Vercel `una-landing` necesitaba una rama de despliegue que no se fusiona (`web-preview`, con el contacto rellenado) y una rama de relleno como producción (`vercel-no-production`), porque la construcción de producción falla con huecos de identidad.
- **[Hecho]** La web lee de la app, al construir: el nombre (`app/identity.yaml`), los tokens (`design/tokens.json`), los títulos de las ARB, la política (`docs/legal/privacy-policy.md`, única fuente) y las fuentes. Y la app leía de la web: `store/google-play/check.mjs` importaba funciones de `landing/`, y la puerta de publicación miraba `landing/src/strings.json` y la Ayuda.
- **[Hecho]** La política no puede irse de aquí: la usan `privacy_policy_test.dart`, la puerta (CA-020-09 a 12) y la comprobación de la ficha (permisos frente a Data Safety).

## Opciones consideradas

1. **Seguir en el monorepo** (ADR-0009) y acelerar la CI con filtros de rutas.
2. **Repositorio aparte con copias:** `svallev/una-web` guarda en `shared/` copias de la política, los tokens, los títulos y las fuentes, que trae `node scripts/sync-from-app.mjs`; la construcción solo lee el repositorio de la web.
3. **Repositorio aparte que lee la app al construir** (submódulo de git o descarga del repositorio público en Vercel).

## Decisión

Opción 2. La web vive en `svallev/una-web` (local: `../UnaWeb`), con su CI y su proyecto de Vercel, que publica `main`. La app sigue siendo la fuente de la política, el nombre, los tokens comunes, los títulos y las fuentes; la web guarda copias y las refresca con su script. Los tokens solo de la web (grupo `landing`, `webContentMaxWidth`), las direcciones de las tiendas y el contacto publicado pasan a la web. Se revisa si las copias se desfasan en la práctica o si la web vuelve a necesitar código de la app.

## Motivos

| Criterio (peso) | 1. Monorepo | 2. Aparte, con copias | 3. Aparte, leyendo la app |
|---|---|---|---|
| Rapidez de un cambio de la web: PR, CI y despliegue (5) | 1 → 5 | 5 → 25 | 4 → 20 |
| Vercel sin ramas de relleno (4) | 1 → 4 | 5 → 20 | 5 → 20 |
| Una sola fuente de política y nombre (4) | 5 → 20 | 3 → 12 | 5 → 20 |
| Construcción sin red ni credenciales (3) | 5 → 15 | 5 → 15 | 2 → 6 |
| Simplicidad (3) | 3 → 9 | 4 → 12 | 2 → 6 |
| **Total** | **53** | **84** | **72** |

- **Opción 1:** los filtros de rutas ya existían (`tools/ci-detect.sh`) y el problema seguía: la PR de la web pasaba por la CI y las reglas de la app, y Vercel necesitaba las dos ramas.
- **Opción 3:** mantiene la fuente única sin copias, pero la construcción depende de la red o de un submódulo, más difícil de manejar y de probar sin conexión.
- **Opción 2:** la fuente sigue siendo una (las copias no se editan; `shared/SOURCE.txt` dice de qué commit vienen, y el script falla si el nombre de la web no es el de la app). Lo que se pierde es que un cambio de la política llegue solo a la web: hay que refrescar la copia.

## Consecuencias

- **Positivas:** la PR de la web no toca la CI de la app; Vercel publica `main` sin ramas especiales; la app pierde `landing/`, el trabajo «Web y ficha» (queda «Ficha»), la lectura de los textos de la web en la puerta (`--web-text`) y el contraste de la página de inicio en `tools/validate-tokens.mjs` (ahora `test/web-tokens.test.mjs` de la web).
- **La protección de huecos cambia** (decisión del propietario, 2026-11-18): en la web, un hueco de identidad solo hace fallar la construcción con `UNA_RELEASE=1`, que se define en Vercel al publicar de verdad (F6). Hasta entonces la producción de Vercel es una web de pruebas. Enmienda lo que la 023 decía de `VERCEL_ENV=production`.
- **Negativa: copias que se desfasan.** Mitigación: `node scripts/sync-from-app.mjs` antes de publicar (lista de publicación de la web, `docs/release-checklist.md` de `una-web`, y punto de F6 aquí); `check.mjs` de la web falla si lo publicado no coincide con su copia. **Riesgo nuevo para el registro de `docs/PLAN.md`:** que la web publique una política más vieja que la de la app.
- **Negativa: dos repositorios que mantener** (Dependabot, CI y reglas de cada uno). Mitigación: la web hereda los principios de la constitución de la app (su `CLAUDE.md` lo dice).
- **Se mantiene:** la política, el nombre y la ficha de tienda siguen aquí; `store/google-play/lib.mjs` tiene las cinco funciones que antes importaba de `landing/` (copiadas tal cual). El archivo de avisos de terceros sigue saliendo del trabajo de publicación de la app y se copia a mano a la web, como antes.
- **Pendiente:** retirar el proyecto de Vercel `una-landing` y las ramas `web-preview` y `vercel-no-production` cuando la web nueva esté publicada.
