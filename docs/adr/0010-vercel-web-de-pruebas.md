# ADR-0010: Web de pruebas en Vercel con integración Git, Flutter fijado y cabeceras estrictas

- **Estado:** Provisional, pendiente del spike S6
- **Fecha:** 2026-09-24
- **Relacionado:** D4, ADR-0001, `docs/environments.md`, modelo de amenazas (T-9)

## Contexto

- **[Hecho]** La web solo sirve para pruebas (D4): revisar flujos y diseño en cada PR.
- **[Hecho]** La imagen de build de Vercel no incluye Flutter.
- **[Hecho]** El repositorio es público: las PR de forks no reciben secretos.

## Opciones consideradas

1. **Integración Git de Vercel** + script que instala la versión de Flutter fijada en `.fvmrc`
2. Build en GitHub Actions + `vercel deploy --prebuilt` con un token en los secretos de GitHub

## Decisión

**Opción 1** como punto de partida:
- Proyecto de Vercel con Root Directory `app/`; *install command* `bash ../tools/install-flutter.sh` (clona el SDK con la etiqueta de `.fvmrc` y registra en el log el commit instalado). *Build command*: `flutter build web --release --wasm --no-web-resources-cdn --dart-define=APP_ENV=preview`. Salida: `build/web`.
- *Preview* por PR y producción desde `main`. **Deployment Protection** (Vercel Authentication) activada en las previews.
- `vercel.json` con cabeceras:
  - `Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; font-src 'self'; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'; object-src 'none'` (se ajusta en S6 a lo que exija el runtime de Flutter).
  - `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff` · `Referrer-Policy: no-referrer` · `Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()` · `Cross-Origin-Opener-Policy: same-origin`
  - `X-Robots-Tag: noindex` (no es un producto).
- `--no-web-resources-cdn`: CanvasKit y las fuentes se sirven desde el propio dominio, sin CDN de Google.
- Banner fijo "Versión de pruebas · los datos pueden borrarse" y almacenamiento en OPFS/IndexedDB.
- **Sin** Vercel Analytics, Speed Insights ni scripts de terceros.

## Motivos

La opción 1 no guarda tokens de Vercel en GitHub (menos superficie) y usa las previews nativas. Si el tiempo de build (instalar Flutter) supera ~10 min, se pasa a la opción 2 con un token restringido a un proyecto y guardado en un *environment* protegido de GitHub.

## Consecuencias

- `tools/install-flutter.sh` se mantiene junto a `.fvmrc`.
- La web no es representativa del rendimiento ni de la accesibilidad nativos: los criterios de aceptación de rendimiento y accesibilidad se verifican en el dispositivo.
