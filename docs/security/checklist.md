# Checklist de seguridad (Definition of Done y revisión de PR)

Se marcan los puntos que apliquen a la PR; los que no apliquen se dejan como "N/A". La plantilla de PR enlaza a este archivo. Referencias entre paréntesis: amenazas de `threat-model.md`.

## Siempre

- [ ] Sin secretos, claves, tokens ni archivos de firma en el diff (secret scanning de GitHub sin alertas; el hook de Claude Code bloquea rutas sensibles).
- [ ] Sin logs de contenido del usuario (texto, rutas, URL) en *release* (T-2).
- [ ] Sin llamadas de red nuevas. Si las hay, justificadas y alineadas con P4 (T-13).
- [ ] Sin permisos nuevos en `AndroidManifest`/`Info.plist`. Si los hay, pedidos en el momento de uso y con texto de propósito traducido (T-13).
- [ ] Entradas del usuario validadas en el dominio (longitud máxima del texto: 10 000 caracteres).

## Si añade o actualiza dependencias (T-10)

- [ ] Cumple los criterios de `threat-model.md §5` (mantenimiento, licencia, sin telemetría).
- [ ] `pubspec.lock` actualizado; OSV-Scanner y dependency-review en verde.
- [ ] Revisados los permisos y el manifiesto de privacidad que añade el paquete.

## Si toca la importación de archivos (T-3)

- [ ] Tipo validado por bytes mágicos, no solo por la extensión o el MIME declarado.
- [ ] Límite de tamaño (y de píxeles en imágenes) aplicado **antes** de procesar.
- [ ] Imágenes recodificadas sin EXIF/GPS/XMP (test con fixture que contiene GPS).
- [ ] Nombre de archivo saneado; rutas construidas solo desde UUID.
- [ ] Procesado fuera del hilo de UI y con *timeout*; los temporales se limpian si hay error.

## Si toca URL o WebView (T-4, T-5, T-6)

- [ ] Solo `http(s)`; tests con `javascript:`, `data:`, `file:`, `intent:`, `user:pass@`, IDN mixto.
- [ ] `javaScriptBridgeEnabled:false`, sin acceso a archivos ni contenido, almacén no persistente, sin permisos ni descargas.
- [ ] Navegación fuera del dominio → navegador del sistema; ventanas nuevas bloqueadas.
- [ ] Sin excepciones de ATS ni de *cleartext*.

## Si toca el almacenamiento o el esquema (T-1, T-7)

- [ ] Nueva `schemaVersion` + captura + test de migración.
- [ ] Datos solo en el sandbox; clase de protección de archivos correcta; nada en almacenamiento externo.
- [ ] Reglas de backup revisadas si hay rutas nuevas.

## Si toca integración nativa (T-8)

- [ ] Ningún componente exportado nuevo; FileProvider con permisos puntuales y solo de lectura.
- [ ] Sin esquemas de URL ni *deep links* nuevos sin su ADR.

## Si toca CI, workflows o la web (T-9, T-11)

- [ ] `permissions:` mínimos; acciones fijadas por SHA; sin `pull_request_target` con código de la PR.
- [ ] Secretos solo en *environments* protegidos; nunca en jobs de PR.
- [ ] Cabeceras de `vercel.json` intactas o reforzadas; sin scripts de terceros.

## Skills, plugins y MCP (P11)

- [ ] Nada instalado a nivel global ni con confirmación automática.
- [ ] Toda skill o plugin de terceros nuevo: contenido revisado y explicado en la PR, registrado en `skills-lock.json`.
