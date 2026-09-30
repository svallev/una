# PR: spec 012, pantalla temporal de "Configuración y perfil"

**Título:** `feat(012): add temporary settings screen with open-source licenses and privacy policy`

## Qué y por qué

Hasta ahora "Configuración y perfil" era solo texto en el menú. La app necesita, para poder enseñarse, **un sitio con las licencias de lo que usa y la política de privacidad**. Esta PR añade una pantalla **temporal** (decisión del propietario, 2026-09-30) con solo esas dos opciones; la Configuración completa llegará en una spec futura con diseño del propietario y sustituirá a esta. Cierra DEV-18 y se registra como DEV-49 (temporal).

- **Spec:** `specs/012-configuracion-temporal/spec.md` (estado: **Implementada parcialmente**)
- **Tareas:** T-012-01 a T-012-11
- **Criterios de aceptación cubiertos:** CA-012-01 a CA-012-16 y CL-012-1 a 12 (tabla CA → prueba en `spec.md` §10)
- **ADR nuevos o afectados:** ninguno nuevo (aplican ADR-0016/0018, ADR-0019)
- **Enmiendas a otras specs:** 005 (CA-005-09) y 010 (CL-010-7, CA-010-07, CA-010-12, §§1, 6, 8, 9); matriz de CA-011-02 con cuatro filas nuevas

## Qué cambia

- **Tres niveles a pantalla completa, sobre el menú sin cerrarlo:** 1 "Configuración y perfil" (título, Cerrar, dos opciones), 2 lista de licencias ("nombre, N licencias") y 3 texto de una licencia (en inglés, sin enlaces activos, en párrafos). Fundido de 160 ms (ninguno con "reducir movimiento"), en vertical siempre, con foco y Escape según la tabla de niveles de la spec. "Configuración y perfil" pasa a ser un botón.
- **Política de privacidad:** `privacyLink()` (solo `https`, sin usuario) → `LinkOpener.canOpen` (método nuevo del canal `una/links`, solo `resolveActivity`) → confirmación de la 008 → navegador. Sin app: aviso en línea. La dirección sale de `identity.yaml` (`privacyPolicyUrl`, hoy el marcador `https://example.com/privacy`).
- **Licencias:** `FlutterLicenseSource` agrupa el `LicenseRegistry` por paquete, y `registerBundledLicenses()` añade PDFium, SQLite y "Bibliotecas de Android (AndroidX, Kotlin)" (`assets/licenses/*.txt`), todo perezoso: no se lee nada antes del primer fotograma (P2).
- **Herramientas:** `tools/check-licenses.sh` (completitud sobre el APK *release*: paquetes Dart, cada `.so`, artefactos de Android y OFL de las fuentes; **ya en `ci.yml`**) y `tools/check-release-config.sh` (puerta de publicación: dirección `https` propia y política sin huecos; **no está en CI**, hasta F6).
- **Sin** permisos nuevos (solo `INTERNET`), sin cambios de esquema (v2), sin dependencias nuevas (`pubspec.yaml` solo añade 3 assets), sin analítica ni conexiones hechas por la app.
- **Documentación:** DEV-18 y DEV-49, `screen-map`, `architecture`, `security/checklist` (sección nueva), `glossary`, `testing`, `PLAN.md` (D13, fila 012, F5 y F6), `CLAUDE.md`, `/release-checklist`.

## Cómo se ha verificado

Detalle y cifras: `specs/012-configuracion-temporal/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **1423 tests en verde**; `gen-l10n` sin avisos | Local (Mac) |
| `node tools/validate-tokens.mjs` | 28 combinaciones AA, sin hallazgos | Local |
| `/i18n-check` | Mismas claves ES/EN, sin textos incrustados, sin discrepancias de glosario | Local |
| `/security-check` | Sin secretos, sin archivos de firma, sin cambios de manifiesto, lockfile ni dependencias | Local |
| `security-reviewer` | 0 altos, 0 medios, 5 bajos (registrados en `PLAN.md`) | `git diff main...HEAD` |
| `a11y-reviewer` | 0 críticos, 0 altos; M1, M2 y B1 corregidos en `7448f4e`; el resto, registrado | `git diff main...HEAD` |
| CA-012-08 | `check-android-permissions.sh release` (solo `INTERNET`) y `check-licenses.sh` (84 paquetes, 46 artefactos, 5 `.so`) | Emulador API 37, APK *release* |
| CA-012-09 | `check-recents.sh`: las 4 filas nuevas (3 niveles y la confirmación) pasan | Emulador API 37 |
| CA-012-01, 02, 04, 06, 12, 13 y CL-012-3, 11 | Niveles, Escape, Tab/Intro/AvPág, confirmación con Chrome y aviso sin Chrome, 200 % ES/EN a 360 dp, fundido ≈ 160 ms y 0, giro, `am kill` | Emulador API 37 |
| CA-012-07 (voz) | El texto de las licencias con voz inglesa y el resto con la española | **Propietario, a oído, Xiaomi** (TalkBack, APK *release*) |
| CA-012-15 | Nivel 2 en 48 ms; construcción p90 1,5 ms; rasterizado p90 17,1 ms (igual que el listado de la 006 en el mismo emulador) | Emulador API 37, *profile* (`integration_test/licenses_perf_test.dart`); **Xiaomi, *profile*: rasterizado p90 2,2 ms (lista) y 2,5 ms (texto), 0 fotogramas fuera de presupuesto, nivel 2 en 56 ms** |
| CA-012-16 | p50 de arranque +14 ms de mediana (+3,7 % de media), dentro del ruido del emulador; ninguna licencia se lee antes del primer fotograma (test) | Emulador API 37, 8 pasadas alternadas; **Xiaomi, *release*, 8 pasadas alternadas: p50 216 ms (`main`) frente a 215 ms (rama)** |

## Definition of Done (`specs/constitution.md`)

- [ ] Criterios de aceptación cumplidos y con tests en verde: **en parte** (todos con test o casilla; faltan las casillas de dispositivo, ver Pendiente)
- [ ] CI en verde (format, analyze, test, migraciones, l10n, tokens, builds): en local, sí; los 3 *goldens* ya están subidos (`f805c31`), generados con `actualizar-goldens`
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens; salvedad: 4 `height: 1.5` a mano, suman a TD-1)
- [x] Accesibilidad: semántica, alternativas a gestos, contraste, texto grande, reducir movimiento (con hallazgos sin corregir registrados y casillas de dispositivo pendientes)
- [x] Documentación actualizada (spec, glosario, arquitectura, `PLAN.md`)
- [x] Rendimiento del arranque sin degradar: en el Xiaomi, p50 de 216 ms (`main`) frente a 215 ms (rama); en el emulador, dentro del ruido

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados los apartados que aplican: "enlaces externos y licencias" (T-4, T-13) y "Recientes" (nuevas pantallas en la matriz de CA-011-02); sin tocar el esquema, los permisos ni la WebView. Solo `https`, siempre tras la confirmación con el dominio real; `canOpen` no lanza nada ni guarda la dirección; los textos de licencia son texto plano.
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas. **El enlace de la política apunta a un marcador** (`example.com`): la puerta `tools/check-release-config.sh` impide publicarlo así, pero **no está en CI** (F6; hoy, a mano en `/release-checklist`).

## Nueva dependencia

Ninguna. `pubspec.yaml` solo añade los assets `assets/licenses/{pdfium,sqlite,android}.txt` (licencias de los `.tgz` de PDFium verificados con `tools/pdfium.lock`, de SQLite y de los 46 artefactos de Android, todos Apache-2.0 según su POM).

## Riesgos

- **La política de privacidad enlaza a un marcador** y `docs/legal/privacy-policy.md` tiene huecos y ~12 marcas `[Suposición]`. No se puede publicar así (F6, PD-2); la puerta existe, pero **no detecta esas marcas** (012-S4) ni la deriva de `app_identity.g.dart` (012-S2).
- **Nombre "Bibliotecas de Android (AndroidX, Kotlin)" fijo en español** con la app en inglés y sin marca de idioma (WCAG 3.1.2, P7): lo pide la spec tal cual; registrado como 012-A-M3.
- **`LinkOpener.kt` no repite la garantía "https sin usuario"** (solo está en Dart; hoy no explotable, 012-S1).
- **Rasterizado de ~17 ms al desplazar** en el emulador (sin GPU): igual que el listado de la 006, que en el Xiaomi tiene 0 fotogramas fuera de presupuesto. **[Hecho]** en el Xiaomi, el rasterizado p90 es de 2,2-2,5 ms.
- **Al volver de la política** la web de una tarea se recarga (CA-012-14 enmendado por el propietario): esta pantalla tapa la tarea y eso cuenta como salir de la página.

## Pendiente

- **[Pendiente] Casillas de dispositivo** (`dispositivo.md` §8 y "Casillas del cierre"): foco real de TalkBack al volver (tres saltos, Cancelar y navegador), anuncio de "Cargando licencias…" y foco en "Reintentar", nivel 3 de "Bibliotecas de Android", sistema en inglés y `ca`/`gl`/`eu`, 200 % con navegación de 3 botones, anillo con teclado real, Switch Access real, reducir movimiento y el flujo del aviso obsoleto (M2) con Chrome desactivado.
- **[Hecho] Xiaomi (2026-09-30):** rasterizado p90 de 2,2 ms (lista) y 2,5 ms (texto) y 0 fotogramas fuera de presupuesto; nivel 2 en 56 ms; arranque en frío sin diferencia con `main` (p50 215 frente a 216 ms).
- **[Hecho] Goldens:** los 3 *goldens* de `test/goldens/settings_golden_test.dart` se generaron en Linux con la etiqueta `actualizar-goldens`, se revisaron a ojo y se subieron (`f805c31`); las otras 49 imágenes salieron idénticas.
- **[Pendiente] CL-012-7** (sin conexión al abrir la política): sin test ni casilla, porque la app no interviene (la abre el navegador); se da por cubierto por diseño, a confirmar por el propietario.
- **[Pendiente, F6]** Añadir `tools/check-release-config.sh` a `ci.yml` con el trabajo del AAB de publicación; dirección y texto definitivos de la política (PD-2, P-012-4).
- La spec pasa a **Implementada** cuando se cierren las casillas manuales.

## Deuda registrada (`docs/PLAN.md`, "Hallazgos de la 012 para la auditoría de F5")

- **Seguridad:** 012-S1 a S5 (bajos) y S6 (`gradle-wrapper` sin `distributionSha256Sum`, previo a la 012; antes de F6).
- **Accesibilidad:** 012-A-M3 (medio), B2 (anuncios sin `locale`), B3 (orden de lector de "Volver" y `Focus` sin etiqueta), B4 (animación de pulsación ignora reducir movimiento; previa), B5 (`UnaLinkButton` mide 44, Android pide 48) y B6 (faltan las guías `androidTapTarget` y `textContrast` en los tests).
- **TD-1:** 4 `height: 1.5` a mano más (23 en total).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
