# ADR-0010: Web de pruebas en Vercel con integración Git, Flutter fijado y cabeceras estrictas

- **Estado:** Aceptado (S6 validado en local el 2026-09-24); falta el primer despliegue real en Vercel
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
  - `Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; font-src 'self'; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; form-action 'none'; object-src 'none'` (**validada en S6**: `base-uri 'self'` porque el `index.html` de Flutter usa `<base href="/">`; `worker-src blob:` porque PDFium WASM corre en un *worker* `blob:`).
  - `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff` · `Referrer-Policy: no-referrer` · `Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()` · `Cross-Origin-Opener-Policy: same-origin` · **`Cross-Origin-Embedder-Policy: require-corp`** (aislamiento entre orígenes → skwasm en varios hilos; verificado `crossOriginIsolated: true`)
  - `X-Robots-Tag: noindex` (no es un producto).
- `--no-web-resources-cdn`: CanvasKit y las fuentes se sirven desde el propio dominio, sin CDN de Google.
- Banner fijo "Versión de pruebas · los datos pueden borrarse" y almacenamiento en OPFS/IndexedDB.
- **Sin** Vercel Analytics, Speed Insights ni scripts de terceros.

## Motivos

La opción 1 no guarda tokens de Vercel en GitHub (menos superficie) y usa las previews nativas. Si el tiempo de build (instalar Flutter) supera ~10 min, se pasa a la opción 2 con un token restringido a un proyecto y guardado en un *environment* protegido de GitHub.

## Consecuencias

- `tools/install-flutter.sh` se mantiene junto a `.fvmrc`.
- La web no es representativa del rendimiento ni de la accesibilidad nativos: los criterios de aceptación de rendimiento y accesibilidad se verifican en el dispositivo.

## Resultado de S6 en local (2026-09-24)

`flutter build web --release --wasm --no-web-resources-cdn` (47 MB en disco) servido con estas cabeceras:
- Carga correcta con skwasm; shader de arrugado y visor PDF (PDFium WASM en *worker* `blob:`) funcionando.
- **Todas las peticiones al propio dominio** (ni CDN ni Google Fonts: la fuente de respaldo se sirve en local).
- La CSP inicial con `base-uri 'none'` generaba un error de consola (corregido a `'self'`).
- Falta: conectar el repo en Vercel (lo hace el propietario) y comprobar el tiempo de build con la instalación de Flutter.
