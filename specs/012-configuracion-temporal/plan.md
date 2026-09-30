# Plan técnico — Spec 012: Pantalla temporal de "Configuración y perfil"

- **Spec:** `specs/012-configuracion-temporal/spec.md` (estado: Aprobada, enmendada el 2026-09-30 con las decisiones de este plan)
- **ADR aplicables:** ADR-0001 (stack), ADR-0016/0018 (la política no pasa por la vista web), ADR-0019 ("Recientes"); sin ADR nuevo (no se elige entre alternativas de arquitectura)
- **Estado del plan:** **Aprobado** (propietario, 2026-09-30)

## 1. Resumen del enfoque

Tres pantallas propias (P12: sin `LicensePage` de Material) en `lib/features/settings/`, abiertas como **rutas opacas a pantalla completa** desde el menú, **sin cerrarlo**: la ruta se empuja desde el contexto de la hoja, así que al cerrar el nivel 1 el menú sigue ahí tal como estaba (P-012-1). Transición: fundido de `UnaMotion.sheetOut` (160 ms) o `Duration.zero` con "reducir movimiento" (CA-012-13), como el listado.

- **Licencias:** se leen de `LicenseRegistry` **solo al abrir el nivel 2** (CA-012-16) y se agrupan por paquete. Lo que no pasa por el registro se añade en `registerBundledLicenses()` (ya lo hace con las OFL): **PDFium**, **SQLite** y una entrada **"Bibliotecas de Android (AndroidX, Kotlin)"** con el texto Apache-2.0 y la lista de artefactos (P-012-3, propietario). La completitud la comprueba un script sobre el APK *release* (§5).
- **Política de privacidad:** la dirección vive en `app/identity.yaml` (`privacyPolicyUrl`, marcador `https://example.com/privacy`) → `AppIdentity.privacyPolicyUrl` (P7). Flujo: si no es `https` → aviso; si no, `classifyLink` → `WebLink` → **`canOpen`** (nuevo método del canal `una/links`, solo `resolveActivity`) → sin app: aviso en línea; con app: `showLinkConfirmSheet` (spec 008) → "Abrir" → `open`. Sin canal nuevo.
- **Puerta de publicación** (CA-012-05): `tools/check-release-config.sh`, en `/release-checklist`; no se ejecuta en compilaciones locales.

### Hechos comprobados al preparar el plan (2026-09-30, APK *release* arm64 de `main`)

- **[Hecho]** `NOTICES` de Flutter ya incluye el **motor** (Skia, ICU, BoringSSL, HarfBuzz, libpng, zlib…) y todos los paquetes Dart, **también los de desarrollo** (`build_runner`, `analyzer`, `drift_dev`…). Decisión del propietario: **se muestra tal cual**; sobra algo, no falta nada. El test exige solo los de *release*.
- **[Hecho]** El APK lleva `libapp.so` (propio), `libflutter.so` (motor), `libpdfium.so`, `libsqlite3.so` y **`libdartjni.so`** (paquete `jni`, que ya está en `NOTICES`).
- **[Hecho]** El APK lleva ~30 bibliotecas AndroidX, `kotlinx-coroutines` y Kotlin (Apache-2.0), **no** incluidas en `NOTICES` → entrada propia (P-012-3).
- **[Hecho]** `LinkOpener.kt` solo comprueba `resolveActivity` **dentro** de `open`: la spec pide comprobarlo **antes** de la confirmación → método `canOpen`. `<queries>` ya declara `VIEW` + `BROWSABLE` + `https`: no cambia el manifiesto.
- **[Hecho]** Una ruta opaca sobre la tarea web la **quita y la recarga al volver** (`TaskWeb`, `TickerMode`, CA-009-13). **Decisión del propietario (2026-09-30):** se acepta, como tras el editor o el listado; **CA-012-14 enmendado** (la web se recarga; PDF e imagen no cambian).
- **[Hecho]** `UnaApp` hace `popUntil(isFirst)` tras ≥ 10 min (CA-001-12): cubre también estas rutas (CA-012-06).

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `domain/entities/license_package.dart` (nuevo); `domain/ports/license_source.dart` (nuevo); `domain/ports/link_opener.dart`; `domain/services/privacy_link.dart` (nuevo) | `LicensePackage(name, texts: List<LicenseText(paragraphs: List<(String, int indent)>)>)`, Dart puro. `LicenseSource.load()`. `LinkOpener.canOpen(LinkTarget)`. `privacyLink(String) → WebLink?` (null si no es `https` o `classifyLink` la bloquea) |
| Datos | `data/licenses/flutter_license_source.dart` (nuevo); `data/links/native_link_opener.dart`; `app/bundled_licenses.dart`; `assets/licenses/{pdfium,sqlite,android}.txt` (nuevos, declarados en `pubspec.yaml`) | Lee `LicenseRegistry.licenses`, agrupa por paquete (un texto por `LicenseEntry`, sin duplicados), orden alfabético sin distinguir mayúsculas. `canOpen` por el canal. Tres entradas nuevas, perezosas como las OFL |
| Estado | `app/providers.dart` | `licenseSourceProvider`; `licensesProvider` (`FutureProvider.autoDispose`, se invalida con "Reintentar"). Lista vacía = error (spec §5) |
| Presentación | `features/settings/settings_screen.dart`, `licenses_screen.dart`, `license_detail_screen.dart`, `settings_route.dart` (nuevos); `features/menu/menu_sheet.dart` | Nivel 1 (icono Cerrar + título + dos `SheetRow`, aviso en línea con `liveRegion`), nivel 2 (cargando / error + Reintentar / lista con "N licencias"), nivel 3 (`ListView.builder` de párrafos, título de cada licencia como encabezado, `Semantics(localeForSubtree: en)`). Foco al llegar en el título y al volver en el origen (tabla de la spec) con `focus_on_signal.dart`. `CallbackShortcuts` con Escape. `_SettingsText` → botón con `FocusRing`, ≥ 44, y guarda de doble toque (CL-012-2) |
| Nativo | `android/.../LinkOpener.kt` | Método `canOpen` (mismos intents y comprobación de esquema que `open`, sin `startActivity`). Nada más |
| Identidad | `app/identity.yaml`, `tool/gen_identity.dart`, `lib/app/app_identity.g.dart` | Clave `privacyPolicyUrl` (una sola para ES y EN, P-012-2) |
| l10n | `app_es.arb`, `app_en.arb` | Claves de la spec §7. `settingsClose` **propia** (no se unifica con `attachSheetClose`: cada clave lleva su contexto para traducir, como ya pasa con `menuClose`). Se reutilizan `menuSettings`, `openInBrowserConfirm`, `linkConfirmOpen`, `linkConfirmCancel`, `errNoAppForLink` y `retry` |
| Herramientas | `tools/check-licenses.sh`, `tools/check-release-config.sh` (nuevos); `.github/workflows/ci.yml`; `.claude/skills/release-checklist/SKILL.md` | §5 y §6 |

## 3. Modelo de datos y migraciones

Sin cambios: `schemaVersion` sigue en 2, nada se guarda (CA-012-08).

## 4. Dependencias nuevas

Ninguna. Los textos nuevos son **assets** (no código):

- `pdfium.txt`: el `LICENSE` del `.tgz` de `bblanchon/pdfium-binaries` **chromium/7811** (BSD-3 + avisos de terceros), sacado del `.tgz` cuyo sha256 coincide con `tools/pdfium.lock`.
- `sqlite.txt`: la declaración de dominio público de SQLite.
- `android.txt`: Apache-2.0 + la lista `grupo:artefacto` del `releaseRuntimeClasspath`. **[Suposición]** todos Apache-2.0; la tarea lo comprueba grupo por grupo en sus POM y, si alguno no lo es, se añade su texto (y se para si no está en la lista permitida de `threat-model.md §5`).

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-012-01, 02 (tabla de niveles, foco, Escape, atrás), CL-012-2, CL-012-9 | Widget | `test/features/settings/settings_screen_test.dart`, `test/features/menu/menu_sheet_test.dart` (CA-005-09 enmendado: ahora botón) |
| CA-012-03 (lista, recuento, varias licencias, texto plano sin enlaces), CL-012-4, 10, 12 | Widget + unitario | `licenses_screen_test.dart`, `test/data/flutter_license_source_test.dart` |
| CA-012-03 completitud (paquetes Dart de *release*, fuentes, cada `.so`, AndroidX/Kotlin) | Script sobre el APK *release*, en CI tras `check-pdfium.sh` | `tools/check-licenses.sh`: descomprime `NOTICES.Z`; paquetes de `dart pub deps --no-dev --style=list`; cada `lib/*/*.so` con su entrada conocida (`libapp` excluido; uno desconocido falla); artefactos de `:app:dependencies --configuration releaseRuntimeClasspath` ⊆ `android.txt`. Se prueba que **falla** quitando una entrada |
| CA-012-04, 05 (marcador), CL-012-7, 8 | Widget con `LinkOpener` falso + unitario | `settings_screen_test.dart`, `test/domain/privacy_link_test.dart` |
| CA-012-05 puerta | Script con casos | `tools/check-release-config.sh` (falla con el marcador, `http`, dominios reservados y huecos ES/EN de `docs/legal/privacy-policy.md`; pasa con valores de prueba en un directorio temporal) |
| CA-012-06, CL-012-11 | Widget con reloj inyectable | `test/app/home_router_test.dart` (9:59 y 10:00, como CA-011-03) |
| CA-012-07 | Widget | `test/app/locale_change_test.dart` (tres niveles; textos de licencia intactos; nodo con `en`). Voz: a oído, **[Pendiente]** propietario |
| CA-012-08 | Script + diff | `check-android-permissions.sh release`; `git diff main` sin `pubspec.lock` ni `drift_schemas/` |
| CA-012-09 | `tools/check-recents.sh` en API 37 | Cuatro filas nuevas en la matriz de CA-011-02 (`dispositivo.md`) |
| CA-012-10 | `validate-tokens` + goldens (ES, 360 dp) | `test/goldens/settings_*` |
| CA-012-11, 12 | Widget (semántica, orden de foco, Intro/Escape) + TalkBack y teclado en el emulador | `settings_screen_test.dart`, `licenses_screen_test.dart`; `dispositivo.md` |
| CA-012-13 | Widget con `loadAppFonts`, 200 %, 360 dp, ES y EN; duración del fundido | idem |
| CA-012-14 (enmendado), CL-012-1 | Widget con el `WebPageDriver` falso: la web se recarga; el PDF conserva página y zoom | `test/features/settings/settings_over_task_test.dart` |
| CA-012-15, CL-012-5, 6 | Widget (`LicenseSource` lento / que falla / vacío; Reintentar con foco) + p90 de fotogramas en *profile* como CA-006-20 | `licenses_screen_test.dart`; `dispositivo.md` |
| CA-012-16 | Widget (el `LicenseSource` no se llama hasta abrir el nivel 2) + `tools/measure-cold-start.sh` alternado | `test/app/startup_licenses_test.dart`; `docs/perf/baseline.md` |
| CL-012-3 | Widget (la ruta no pide girar) + emulador | `settings_over_task_test.dart` |

Todos los tests citan su CA; los que miden, con `setUpAll(loadAppFonts)`. Sin red.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (P4, T-5):** la app no abre conexiones: el navegador sí. Solo `https`, `classifyLink` rechaza `usuario@host`. `canOpen` no registra la dirección (CL-008-11). Textos de licencia como `Text` plano: sin enlaces (CL-012-12). Sin permisos ni dependencias. `security-reviewer` sobre el plan y al cierre.
- **Accesibilidad:** `a11y-reviewer` sobre el plan. Encabezados, botones con rol, pista `settingsPrivacyHint`, aviso con `liveRegion` una sola vez, párrafos navegables, idioma `en` en los textos de licencia, foco de la tabla, Escape, anillo de foco, ≥ 44, 200 % sin desbordes, sin animación con reducir movimiento.
- **Rendimiento (P2):** nada nuevo antes del primer fotograma (las entradas del registro son perezosas). Lista con `ListView.builder`; párrafos largos troceados.
- **Checklist de seguridad:** sección de enlaces externos (reutiliza 008) y "Recientes".

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| `NOTICES` no está en los tests de widgets | Los tests usan un `LicenseSource` falso; la completitud la da el script del APK |
| `releaseRuntimeClasspath` cambia al actualizar Flutter o un plugin | `check-licenses.sh` en CI falla y obliga a actualizar `android.txt` |
| El `.tgz` de PDFium no está en caché | Se descarga una vez en la tarea (con red, fuera de los tests) y se verifica con `pdfium.lock`; el texto queda en el repositorio |
| El foco no vuelve a la fila del menú bajo la ruta | Test de widget + TalkBack en el emulador (memoria: TalkBack enfoca el primer nodo de la ruta) |
| El aviso en línea se anuncia dos veces o ninguna | Anuncio explícito por intento (§8) + TalkBack |

**Alternativas descartadas:** `LicensePage` de Material (no usa los tokens, P12); ruta no opaca para no recargar la web (propietario: se acepta la recarga); filtrar los paquetes de desarrollo (propietario: se muestran tal cual); ver la política dentro de la app (spec §8).

## 8. Cambios tras la revisión del plan (2026-09-30)

`a11y-reviewer` (4 altos, 7 medios, 4 bajos) y `security-reviewer` (0 altos, 2 medios, 4 bajos). Todos se aplican así:

**Accesibilidad**

- **`SheetRow` se amplía** (`lib/ui/sheet_row.dart`, también mejora el menú): `minHeight` en lugar de alto fijo (200 %, A1); `FocusRing` en la fila (A2); parámetro `hint` activo aunque la fila esté activada (`settingsPrivacyHint`, A3). Se vuelven a pasar los tests y *goldens* del menú.
- **Cabecera propia** con `SquareIconButton` (`close` en el nivel 1, `arrowLeft` en 2 y 3) y el título como encabezado; no `SheetHeader` (título en mayúsculas pequeñas). **Orden del lector:** título → aviso o estado → opciones o filas → Cerrar/Volver (convención de CA-006-18). **Orden del teclado** (CA-012-12): Cerrar/Volver → título (foco al llegar) → opciones o filas. Sin `label` en `namesRoute` para que el nombre no se lea dos veces (B4).
- **Foco al volver** (M1): el botón del menú y las filas tienen `FocusNode` y clave semántica; el foco se pide al terminar la transición de vuelta (160 ms, o 0) más un *post-frame*, como `_requestFocus` del listado; tras "Cancelar" en la confirmación, después de `UnaMotion.sheetOut`. **El criterio es TalkBack en el emulador**; un test de `FocusSemanticEvent` no basta.
- **Escape** (B1): un `Focus` de la ruta por encima del contenido, activo aunque se haya tocado con el dedo, y guarda contra el doble cierre.
- **Nivel 2** (M3, M4, B2): "Cargando licencias…" justo tras el título en el orden de lectura; se anuncia con `SemanticsService` solo si la carga sigue pasado un umbral corto (si la lista ya está, no). Error: el foco va a "Reintentar" con `licensesError` como pista; tras pulsarlo, el foco vuelve al título. Filas: botón con etiqueta fusionada "nombre, N licencias", `FocusRing`, alto mínimo que crece.
- **Nivel 3** (A4, B3): la lista es enfocable con su anillo y se desplaza con flechas, AvPág y RePág; Switch Access con la acción de desplazar. `localeForSubtree: en` solo en títulos y párrafos de licencia. Sangría limitada para que quepa al 200 % a 360 dp.
- **Aviso "No hay ninguna app…"** (M5): se anuncia con `SemanticsService` **en cada intento fallido** (una vez por intento; sin `liveRegion`) y no mueve el foco; se oculta al abrir con éxito y al salir del nivel 1.
- **Objetivos táctiles** (M6): el mínimo del proyecto es 44 (`UnaSizes.minTouchTarget`); los tests usan `labeledTapTargetGuideline` y una comprobación propia de ≥ 44, no `androidTapTargetGuideline` (48). `textContrastGuideline` con la salvedad de CLAUDE.md.
- **Giro** (M7): `showLinkConfirmSheet` recibe un parámetro para no activar `linkConfirmOpen` cuando se abre desde la Configuración (si no, la tarea de debajo giraría); test en T-012-07.

**Seguridad**

- **Puerta de publicación** (M1): `tools/check-release-config.sh` llama a `tool/check_release_config.dart`, que usa `Uri.parse` y **`privacyLink`** (debe dar un `WebLink`); normaliza el host (minúsculas, sin punto final) y rechaza usuario, puerto, IP literal, `localhost`, y los dominios reservados **y sus subdominios** (`example.com|net|org`, `*.example`, `*.test`, `*.invalid`, `*.localhost`). Casos de prueba: `EXAMPLE.com`, `example.com.`, `www.example.com`, `user@`, IP, `http`.
- **`open` devuelve `false` tras `canOpen` = `true`** (M2): mismo aviso en línea. `canOpen` se consulta en cada toque, sin guardar el resultado.
- **`canOpen` en Kotlin** (B3): la construcción del intent sale a una función común con `open`, así que no acepta más; nunca llama a `startActivity` ni registra la dirección. `NativeLinkOpener.canOpen` captura `MissingPluginException` y `PlatformException` → `false`.
- **Licencia de PDFium** (B4): `pdfium.txt` empieza con una línea de origen (`chromium/7811` y sha256 del `.tgz`); `check-licenses.sh` comprueba que coincide con `pdfium.lock`, que añade el aviso "al actualizar, regenerar `pdfium.txt`". Descarga con `curl --proto '=https' --tlsv1.2`, sha256 comprobado **antes** de descomprimir.
- **CI** (B5): `check-licenses.sh` va tras la compilación, con `gradle --offline` y `dart pub deps` tras el `pub get --enforce-lockfile`; `NOTICES.Z` con `python3` (`zlib`/`gzip`); sin instalar herramientas ni tocar `permissions:` ni disparadores. **Fuera de la 012:** `distributionSha256Sum` en el *wrapper* de Gradle (se propone aparte).
- **Artefacto de Android nuevo** (B6): `docs/testing.md` dice que, al añadirlo a `android.txt`, se comprueba la licencia de su POM contra `threat-model.md §5` y se anota en la PR. El riesgo de olvidar la puerta en F6 se anota en `docs/PLAN.md` (fila F6).
