# PR: spec 018, Iconos

**Título:** `feat(018): app icon for Android, Play and the test web`

## Qué y por qué

La app deja de llevar el icono de Flutter y estrena **el suyo**: la «u.» negra (`#111111`) sobre amarillo (`#FFE55C`) del tablero 17, **entera con cualquier máscara de lanzador**, con su versión **con tema** (Android 13+), el PNG de **Google Play 512** y los iconos y colores de la web de pruebas. Es un **cambio de recursos**: sin dependencias (ni de desarrollo), sin permisos, sin esquema y **sin tocar `lib/`, los `.kt` ni el manifiesto** (D29: «a mano y sin dependencias»).

- **Spec:** `specs/018-iconos/spec.md` (estado: **Implementada parcialmente**; tabla CA → prueba en el §13)
- **Tareas:** T-018-01 a T-018-08
- **Criterios de aceptación cubiertos:** CA-018-01 a CA-018-15 y los casos límite CL-018-*; los de dispositivo, en `dispositivo.md` y en las casillas de la 022
- **ADR nuevos o afectados:** ninguno; constitución **1.9**, sin cambios
- **Enmiendas a otras specs:** ninguna; **DEV-55** (la web de pruebas lleva el icono nuevo, el amarillo en `theme_color` y `background_color` y sin la descripción de plantilla)

## Qué cambia

- **Android:** icono adaptable (`mipmap-anydpi/ic_launcher.xml`) con fondo `@color/ic_launcher_background` (generado desde el token `palette.classic.0`), primer plano `drawable-nodpi/ic_launcher_foreground.png` (432 px, la «u.» al 56 % del círculo visible de 72 dp, esquina más lejana a ≈ 24 dp de los 33 dp de la zona segura) y `<monochrome>` apuntando **al mismo recurso** (P-018-2: la silueta es idéntica por construcción). Se borran los cinco `ic_launcher.png` de la plantilla. `AndroidManifest.xml` no cambia.
- **Google Play:** `store/google-play/icon-512.png` (RGBA, alfa 255, el original de 1024 reducido), fuera de `app/`: no se empaqueta.
- **Web de pruebas:** favicon de 32 y `Icon-192/512` y `Icon-maskable-192/512` con el icono nuevo; `manifest.json` con `theme_color` y `background_color` `#FFE55C` y sin la descripción de plantilla; `index.html` sin `<meta name="description">`. Sin textos nuevos.
- **Generador sin dependencias:** `app/tool/gen_icons.dart` y `png_lite.dart` (solo `dart:`): `dart run tool/gen_icons.dart [android|play|web] [--check]`. Fuera de `lib/`, no se empaquetan.
- **Tests (todo Dart, sin paquetes nuevos):** `test/icon/*` (adaptable, empaquetado, Play, web, coherencia de las cuatro versiones, ayudas), `test/tool/gen_icons_test.dart` y los diez PNG de la plantilla como *fixtures* para comprobar que ya no queda ninguno.
- **Documentación:** `docs/design/app-icon.md` (geometría, colores y cómo rehacerlo, CL-018-7), `architecture`, `testing`, glosario, `screen-map`, `prototype-deviations` (DEV-55), `PLAN.md` y `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/018-iconos/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **2957 tests en verde, 90 omitidos** (dos nuevos tras la revisión: silueta maciza y `--check` sobre el árbol real) | Local (Mac) |
| `node tools/validate-tokens.mjs`, `gen_tokens --check`, `gen_identity --check`, `gen_icons --check` | Bien; todo al día | Local |
| Diff de CA-018-12 | `lib/`, `*.kt`, `AndroidManifest.xml`, `pubspec.*`, Gradle, `drift_schemas/` e `ios/` **sin cambios** (`git diff main...HEAD`); `tools/check-android-permissions.sh` en verde en T-018-03 y 05 | Local |
| `/i18n-check` | Sin textos nuevos, sin claves ARB nuevas | Local |
| `spec-reviewer` | 0 bloqueantes; 5 medios y 8 menores: corregidos los de documentación y de test (nota del *splash* de `architecture.md`, silueta maciza, `--check` en `flutter test`, casillas de la 022, cierre de la spec) y anotados los de texto de la spec en su §13 | `git diff main...HEAD` |
| `security-reviewer` | 0 altos ni medios; 4 bajos (ver «Pendiente») | `git diff main...HEAD` |
| `a11y-reviewer` | 0 altos; 1 medio refutado en el emulador (*splash* oscuro) y otro corregido (casillas de la 022) | `git diff main...HEAD` |
| Máscaras, lanzador, con tema, nitidez 48 y 24 dp, «Tamaño de visualización» al máximo | Bien (cinco formas del lanzador de Pixel; con tema con el estilo *Minimal*) | Emulador API 37 |
| Arranque en frío (CA-018-13) | p50 **375 → 367,5 ms** (alternando 4 × 20); *splash* con la «u.» entera en claro y en oscuro | Emulador API 37 |
| APK de *release* (CA-018-06) | `aapt2`: icono adaptable con `monochrome`; ningún PNG de la plantilla (por MD5); 2,4 KB menos que `main` | Escritorio |
| Icono en el lanzador, «Ajustes del sistema», lista de aplicaciones y con tema | «ok» del propietario, a ojo y sin capturas (app `.profile` aparte, ya retirada) | Xiaomi (HyperOS) |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [ ] **CI en verde:** pendiente de confirmar en la PR (no hay *goldens* nuevos: el icono no es una pantalla)
- [x] `format` y `analyze` limpios en local
- [x] Textos nuevos en ES y EN: **ninguno** (el nombre sale de `identity.yaml`)
- [x] Sin valores visuales sueltos en `lib/` (no hay cambios de código; los colores del icono salen de los tokens y un test los compara)
- [x] Accesibilidad: sin interacción nueva; nombre legible por el lector; contraste ≈ 14,9 : 1; capa con tema maciza. **Parcial:** TalkBack en el lanzador, Android 8–12 y *splash* oscuro en el Xiaomi, en la 022
- [x] Documentación actualizada (spec, plan, glosario, arquitectura, testing, `app-icon.md`, DEV-55)
- [x] **Rendimiento del arranque:** medido en el emulador (p50 no peor)
- [x] Título de la PR en formato Conventional Commits

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] «Siempre»: sin secretos, sin registros, sin red ni permisos nuevos; ninguna entrada de usuario nueva
- [x] Sin dependencias nuevas (ni de desarrollo): `pubspec.yaml` y `pubspec.lock` sin cambios; el generador y los tests solo importan `dart:`
- [x] Sin metadatos en los PNG generados; el de Play no está en `pubspec.yaml` ni en el APK (test)
- [x] Web de pruebas: sin scripts, fuentes ni CDN de terceros; solo cambian iconos, dos colores y se quita la descripción

## Pendiente antes o después de fusionar

- **[Pendiente, 022]** Casillas de dispositivo (`docs/PLAN.md`, «Casillas de la 018»): TalkBack lee «Una.» en el lanzador (C-018-7), Android 8 y 12L, el «cuadrado de esquinas casi rectas» con otro lanzador y el *splash* con el modo oscuro del sistema en el Xiaomi.
- **[Hallazgos bajos del `security-reviewer`, sin corregir]** `png_lite.dart` no limita lo que descomprime zlib (entradas solo del repo; bajar `_maxSide` a 2048); `--out` de `gen_icons.dart` sigue enlaces simbólicos y no captura `FileSystemException` al escribir; el nombre «Una.» literal en la web de pruebas (herencia de la plantilla, CL-018-7).
- **[Nota]** `tools/check-release-config.sh` sigue fallando por los huecos de la política de privacidad (PD-2, F5), como en `main`; no es de esta PR.
- **[Notas para otras specs]** 021 (el *splash* depende hoy del sistema; fijar su fondo si se quiere amarillo), 019 (el icono de notificaciones puede reutilizar la capa monocroma) y F-iOS (el original de 1024 es la fuente): `docs/PLAN.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
