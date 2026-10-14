# Plan técnico — Spec 020: Seguridad y puerta de publicación

- **Spec:** `specs/020-seguridad-y-puerta-de-publicacion/spec.md` (estado: **Aprobada**, 2026-10-14)
- **ADR aplicables:** ADR-0004 (copias de seguridad), ADR-0005 (almacenamiento), ADR-0016/0017/0018 (tarea web), ADR-0019 («Recientes»), ADR-0024 (grupos de fotos), ADR-0025 (notificaciones), ADR-0026 (licencias). Ninguno cambia. **Sin ADR nuevo:** el trabajo de publicación es el que describe la spec (CA-020-01 a 08), sin firma ni secretos; si en la implementación cambiara cómo se firma o se publica, se para y se abre su ADR. Constitución 1.10 sin cambios.
- **Estado del plan:** **Aprobado** por el propietario el 2026-10-14 («sí a las cuatro recomendaciones, aprobado»: P-020-1 a, P-020-2 a, P-020-3 a y P-020-4, §8). Revisado por `security-reviewer` el 2026-10-14: 3 altos, 8 medios y 6 bajos, **aplicados** (§3.2, §3.3, §3.4 y §2); de acuerdo con las cuatro recomendaciones. `a11y-reviewer` no aplica: no cambia ninguna pantalla (CA-020-25).

## 1. Resumen del enfoque

La spec tiene tres bloques que casi no se tocan entre sí. El plan los ordena de dentro afuera: primero las **herramientas que comprueban** (con sus casos negativos), después el **trabajo de publicación** que las encadena, luego los **arreglos de la app** y al final la **pasada MASTG** en el emulador, que ya mira la app arreglada.

1. **Herramientas (CA-020-09 a 15, 22).** Se endurece la puerta de la identidad (`app/tool/check_release_config.dart`), que además pasa a dar **errores con clase** (aviso de identidad o fallo). Se amplían `check-android-permissions.sh` y se añaden dos comprobaciones nuevas: el *wrapper* de Gradle y la **estática MASTG** del paquete (`app/tool/check_package.dart`), que corre ya en la CI de las PR. Todo con `aapt2`, `apksigner`, `unzip` y `perl`, que ya están en el SDK de Android y en los *runners*: **sin dependencias nuevas** (salvo lo que decida P-020-1).
2. **Trabajo de publicación (CA-020-01 a 08).** Un workflow nuevo, `.github/workflows/release.yml`, separado de `ci.yml`. Cada comprobación corre a través de un envoltorio (`tools/release/run-check.sh`) que **anota su resultado** en un archivo de resultados, sin cortar el trabajo. Un último paso, `app/tool/release_summary.dart`, lee esos resultados, aplica la **lista cerrada de avisos de identidad** (CA-020-05) y el modo, escribe el resumen y decide si el trabajo acaba en verde, en verde con avisos o en rojo. Falla cerrado: una comprobación de la lista que no aparece, o que aparece con un código inesperado, es un fallo.
3. **Arreglos de la app (CA-020-16 a 21, 27, 28).** Cambios pequeños y localizados: la lectura de `settings` acotada en SQL, el arranque tolerante, el dominio con escapes mal formados, el barrido y la migración por lotes, y pruebas JVM del tope de 10 fotos y de los `PendingIntent`. **Sin esquema nuevo, sin textos, sin permisos ni componentes nuevos.**
4. **Pasada MASTG (CA-020-23, 24)** en el emulador de API 37, con su informe en `mastg.md`, y la medida del arranque en frío (CA-020-25).

**Valores que fija el plan:**

| Valor | Dónde | Motivo |
|---|---|---|
| **N = 500** identificadores por consulta (CA-020-19) y filas por página (CA-020-20) | `drift_task_repository.dart` (`_idsPerQuery`, ya existe) y `app_database.dart` | El mismo trozo que ya usa `existingAttachmentIds`, muy por debajo del límite de variables de SQLite |
| **`targetSdk` mínimo = 36** (Q-020-3) | Una constante en `app/tool/check_package.dart` (`playMinTargetSdk`) | Requisito vigente de Google Play desde el 31-08-2026 para apps nuevas y actualizaciones (Android 16, API 36). Hoy compila con 36 |
| **16 caracteres** por valor de `settings` (CA-020-16) | `settings_codec.dart` (`_maxRawLength`, ya existe) y la consulta SQL | El mismo límite de la 015 |

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `lib/domain/services/host_display.dart` | `_decodePercent` atrapa `FormatException` y devuelve el texto **sin decodificar** (nunca uno a medio decodificar), que luego pasa por `stripUnsafeChars` como hoy; el Kotlin ya hace lo mismo (hoy solo `ArgumentError`: `Uri.decodeComponent('%C3')` lanza `FormatException`, comprobado en el plan; `https://%C3.es/` rompe hoy `webAddressHost`) (CA-020-27) |
| Dominio | `lib/domain/services/attachment_janitor.dart` | `sweep()` deja de llamar a `attachmentIds()`: recorre los ids del disco en trozos de N y pregunta por cada trozo con `existingAttachmentIds`; la segunda comprobación justo antes de borrar pasa a `existingAttachmentIds([id])` (CA-020-19). El orden protección → BD se mantiene. **Si la consulta de un lote falla, el barrido se corta sin borrar nada más** (nunca «no se pudo leer → no existe → se borra»; hoy `_existing` ya lo trata como «todos con fila»), con su test |
| Dominio | `lib/domain/ports/task_repository.dart` | `attachmentIds()` se queda (lo usan los tests de contrato) pero su doc dice que no es para el barrido |
| Datos | `lib/data/drift_task_repository.dart` | `_raw(key)` con `customSelect` (clave como parámetro `?` y `readsFrom: {settingEntries}`, para que los *streams* sigan enterándose): `SELECT CASE WHEN typeof(value) = 'text' AND length(value) <= 16 THEN value END AS v FROM settings WHERE key = ?`. Así el valor largo, el entero, el BLOB o el `NULL` nunca llegan a Dart (CA-020-16, 17) |
| Datos | `lib/data/in_memory_task_repository.dart` | La misma regla (longitud > 16 → `null`) en su lectura, para que el contrato compartido valga para los dos |
| Datos | `lib/data/db/app_database.dart` | `_numberMultiRowTasks` por páginas con *keyset* (`WHERE (task_id, created_at, id) > (?, ?, ?) ORDER BY … LIMIT 500`), con el contador por tarea llevado de una página a la siguiente y el mismo `ORDER BY task_id, created_at, id` de hoy (`created_at` es `NOT NULL` desde v1 e `id` es clave primaria: el orden es total y no se salta filas); sigue dentro de la transacción de `onUpgrade` (CA-020-20). Mismo resultado, sin `schemaVersion` nueva |
| Estado | `lib/app/providers.dart` | `firstRunDone` y `hasEverHadTasks` pasan por `_orDefault(…, false)` como los demás ajustes (CA-020-17) |
| Presentación | — | Sin cambios |
| Nativo | `LinkOpener.kt` | Solo el comentario, con los dos caminos (CA-020-18) |
| Nativo | `ImageImport.kt` + `PickedItems.kt` (nuevo, Kotlin puro) | `pickedMany` delega en `firstItems(count, max) { i -> … }`, que solo pide los primeros `max` elementos; JUnit con 5000 elementos y un contador de accesos (CA-020-21) |
| Nativo | `notifications/IntentSpecs.kt` (nuevo, puro), `AlarmArm.kt`, `NotificationPoster.kt` | Las órdenes (`PendingIntent`) se describen en un `IntentSpec` puro (clase destino, acción, *flags*) que los adaptadores traducen; JUnit comprueba que son explícitas y llevan `FLAG_IMMUTABLE` y nunca `FLAG_MUTABLE` (CA-020-28), y un test de Dart que lee el código comprueba que `PendingIntent.get*` solo aparece en los adaptadores y siempre con un `IntentSpec`. Lo demás de CA-020-28 ya tiene JUnit de la 019 (`ActivationNonceTest`, `WakeActionsTest`, `NotificationSpecTest`): la tarea lo inventaría, lo cita con `CA-020-28` y añade lo que falte |
| Herramientas | `app/tool/check_release_config.dart`, `tools/check-release-config.sh` | Ver §3.1 |
| Herramientas | `tools/check-android-permissions.sh` | `<uses-permission-sdk-m>` también; `MainActivity` con **exactamente** un `<intent-filter>` (`MAIN` + `LAUNCHER`, sin `<data>`, `BROWSABLE`, `DEFAULT` ni otras acciones); nuevo `--manifest <archivo>` para los casos negativos (CA-020-13) |
| Herramientas | `app/android/gradle/wrapper/gradle-wrapper.properties`, `tools/check-gradle-wrapper.sh` (nuevo), `tools/gradle-wrapper.lock` (nuevo) | `distributionSha256Sum` de `gradle-9.8.0-all.zip` (la que publica Gradle); el script falla si falta y comprueba el `gradle-wrapper.jar` contra las sumas fijadas en el `.lock` (con su fuente). Ver P-020-2 |
| Herramientas | `app/tool/check_package.dart` (nuevo), `tools/check-package.sh` (nuevo), `tools/release/secret-allowlist.txt` (nuevo, vacío al empezar) | Estática MASTG, ver §3.3 |
| Herramientas | `app/tool/png_lite.dart`, `app/tool/gen_icons.dart` | Lado ≤ 2048, un solo `IHDR`, `ZLibDecoder` acotado (se para al pasar de `alto × (1 + ancho × bpp)`); al escribir, `FileSystemEntity.isLinkSync` en la ruta y en sus carpetas → error; los errores de escritura salen con `stderr` + `exit(1)` (CA-020-15) |
| Herramientas | `app/tool/release_summary.dart` (nuevo), `tools/release/run-check.sh` (nuevo), `tools/release/check-tag.sh` (nuevo), `tools/release/check-signature.sh` (nuevo), `tools/release/check-ci-runs.sh` (nuevo) | Ver §3.2 |
| CI | `.github/workflows/release.yml` (nuevo), `.github/workflows/ci.yml` | `release.yml`, ver §3.2. En `ci.yml` (trabajo `android`): la estática MASTG sobre los APK de *release* y sus negativos; los negativos de permisos; el *wrapper* de Gradle. **No** la puerta de la identidad (CA-020-08) |
| l10n | — | Sin cambios (CA-020-25) |

## 3. Detalle

### 3.1 La puerta de la identidad (CA-020-09 a 12)

- **Errores con clase.** `checkAddress`, `checkPolicyText` y compañía devuelven `GateIssue(kind, subject, message)` en lugar de `String`. `kind` ∈ `placeholderAddress` (marcador o dominio reservado), `policyGap`, `policyMark` y `fault` (todo lo demás). Si una misma clave tiene a la vez un `placeholderAddress` y un `fault`, **todos** sus errores pasan a `fault` (CA-020-05, CL-020-20). La salida de hoy (`::error::…`) se conserva; con `--json <archivo>` además escribe la lista para el resumen.
- **Ruta (CA-020-09):** tras el dominio, `^(/[A-Za-z0-9._~\-/]*)?$` sobre el texto tal cual (no sobre `Uri`, que decodifica), y luego, por separado, el mensaje concreto: invisible o de dirección (la lista de la spec), `%`, segmento `.` o `..`, `//`. El test que compara con `privacyLink` sigue.
- **Dominios (CA-020-10):** se añaden `alt`, `home`, `corp`, `mail`, `intranet`, `private` y `arpa` a `_reservedTlds`. La lista IDN se contrasta con la de IANA (la tabla «Test IDN TLDs» de `https://www.iana.org/domains/reserved`), se anota la fuente y la fecha en el código y se quita la **[Suposición]**. La tarea la descarga una vez; si el sandbox no deja, la pide al propietario (no se inventa).
- **Marcas (CA-020-11):** `RegExp(r'\[\s*(suposición|suposicion|assumption|pendiente|pending)\b[^\]]*\]', caseSensitive: false, unicode: true)` en las mismas partes que los huecos, una entrada por marca con su línea. `[Hecho]` no casa. Incluye bloques de código y comentarios HTML (CL-020-9).
- **Falla cerrada (CA-020-12):** archivo ausente, vacío, YAML no válido, raíz que no es mapa o error de lectura → `fault` que nombra el archivo, en los dos modos. `gen_identity.dart --check` desfasado → `fault`.

### 3.2 El trabajo de publicación (CA-020-01 a 08)

**Disparadores y permisos.** `on: push: tags: ['v*']` y `on: workflow_dispatch` (sin entradas). Nada más. `permissions: { contents: read, actions: read }` (la segunda, solo por la comprobación 0, P-020-3). `actions/checkout` fijado por SHA con `persist-credentials: false` y `fetch-depth: 0` (para la historia de `main` y las etiquetas anteriores). Sin `secrets.*`. Un solo trabajo `ubuntu-latest` con Java 17 (las mismas acciones y SHA que `ci.yml`). `concurrency` por `github.sha` + modo, sin cancelar (CL-020-4).

**Modo.** `strict` si `github.event_name == 'push'` y la referencia es una etiqueta; `testers` si es `workflow_dispatch`. Primer paso, **antes de compilar** («rojo al empezar»): en `testers`, la referencia tiene que ser `refs/heads/main` (CL-020-3); en `strict`, la etiqueta debe casar `^v[0-9]+\.[0-9]+\.[0-9]+$` (CL-020-1).

**Pasos.** Cada comprobación se lanza con `tools/release/run-check.sh <id> -- <orden>`, que la ejecuta, guarda su salida y añade una línea a `$RUNNER_TEMP/release/results.tsv` (fuera del *workspace*, para que ni Gradle ni los *hooks* de pub lo toquen): `id`, código de salida y, si la comprobación sabe dar clase (la puerta de la identidad, la etiqueta, la firma y el *package name*), la ruta de su JSON de errores. **La compilación (`build`) no va por el envoltorio:** es un paso normal con su código real, y los pasos que dependen de ella llevan `if: ${{ !cancelled() && steps.build.outcome == 'success' }}`; los demás, `if: ${{ !cancelled() }}`. Si la compilación falla, sus dependientes no corren y el resumen los marca como «no ejecutada» → fallo. Revisión de `security-reviewer` (2026-10-14), aplicada aquí:

- **Entradas exactas:** cada comprobación sobre paquetes recibe la lista explícita (los 3 APK por ABI y el AAB), comprueba que existen todos y **falla con 0 entradas** (nada de *globs* que puedan quedar vacíos).
- **El JSON de clase** se escribe al final, de forma atómica (archivo temporal + `mv`), con `complete: true` y la lista de subcomprobaciones hechas. Solo cuenta como aviso un **código 1 con JSON completo** cuyos errores sean todos de un `kind` de la tabla; código ≠ 0/1, JSON ausente, vacío, ilegible, incompleto o con un `kind` desconocido → fallo. Código 0 con errores en el JSON → fallo.
- **Contra la falsificación de `results.tsv`:** un id repetido → fallo; y el resumen recibe `toJSON(steps)` por `env:` y cruza cada id con el `outcome` que pone GitHub de su paso (con `id:` igual al de la comprobación). Si no coinciden, fallo.
- **Sin inyección de expresiones:** ningún `${{ }}` dentro de un `run:` (lo comprueba el lint); `github.ref_name`, `github.sha` y `github.ref` llegan por `env:`; en `git`, `refs/tags/$TAG` y `--end-of-options`. `GH_TOKEN: ${{ github.token }}` solo en el `env:` del paso `ci-runs`.

| id | Comprobación | Sobre | Clase de sus errores |
|---|---|---|---|
| `ci-runs` | (0) CI y Security del commit en verde, P-020-3: por la **ruta** del workflow (`.github/workflows/ci.yml` y `security.yml`), `event=push`, `branch=main`, `head_sha` exacto, la última ejecución con `status=completed` y `conclusion=success` (cancelada, `skipped` o ausente → fallo) | API de GitHub con `gh` | fallo |
| `lockfile` | `flutter pub get --enforce-lockfile` y Flutter contra `tools/flutter-sdk.lock` (ya lo hace `install-flutter.sh`) | — | fallo |
| `build` | `flutter build apk --release --split-per-abi` y `flutter build appbundle --release` | — | fallo |
| `identity` | `tools/check-release-config.sh --json …` (CA-020-09 a 12) | repo | por error (§3.1) |
| `native-strings` | `gen_android_strings.dart --check` | repo | fallo |
| `permissions` | `check-android-permissions.sh release` (CA-020-13); en el AAB, sobre su manifiesto (P-020-1) | APK y AAB | fallo |
| `test-classes` | `check-apk-no-test-classes.sh` (ampliado para aceptar un `.aab`: mismas entradas y `base/dex/*.dex`) | APK y AAB | fallo |
| `pdfium` | `check-pdfium.sh` (ampliado: `base/lib/<abi>/libpdfium.so` del AAB) | APK y AAB | fallo |
| `licenses` | `check-licenses.sh` y `--negative` | APK | fallo |
| `size` | < 25 MB comprimido por ABI (el mismo bucle de `ci.yml`, movido a `tools/check-size.sh` para no duplicarlo) | APK | fallo |
| `mastg-static` | `tools/check-package.sh` (§3.3) | APK y AAB | fallo |
| `package-name` | `applicationId` del manifiesto compilado: ni `invalid.pending.*` ni un dominio reservado (reutiliza la lista de la puerta) | APK y AAB | aviso (b) |
| `signature` | `tools/release/check-signature.sh`: `apksigner verify --print-certs` (APK) y `jarsigner -verify -strict` + `keytool -printcert -jarfile` (AAB). **Sin firma** o con el sujeto `CN=Android Debug` → aviso; una firma **que no verifica** (corrupta, alterada) → fallo. En `strict`, si no existe el archivo con la huella SHA-256 pública del certificado de subida (`tools/release/upload-cert.sha256`, **[Pendiente, F6]**) → aviso (d) también, para que ningún otro certificado pase hasta F6 | APK y AAB | aviso (d) o fallo |
| `tag` | `tools/release/check-tag.sh`: en `strict`, forma, igual a `version:` de `pubspec.yaml` (sin el `+build`), commit antecesor de `origin/main` (`git merge-base --is-ancestor`), y `+build` mayor que el de la etiqueta anterior más alta, **solo entre las que casan `^v\d+\.\d+\.\d+$` y excluyendo la propia** (`git show refs/tags/<tag>:app/pubspec.yaml`; CL-020-17, CL-020-19). En `testers`, «sin etiqueta» | repo | forma, versión, `main` y `versionCode`: fallo; en `testers`, «sin etiqueta»: aviso (e) |

**El resumen** (`dart run tool/release_summary.dart --mode strict|testers --results build/release/results.tsv`) tiene la **lista de ids esperados** escrita en el código. Para cada uno: ausente → «no ejecutada» → fallo; código 0 → «ok»; código ≠ 0 con JSON → sus errores con su clase; código ≠ 0 sin JSON → fallo. En `strict` todo aviso cuenta como fallo; en `testers` los avisos se listan («aviso · comprobación · clave o archivo · motivo») y se cierra con «Esta versión no se puede publicar.». Escribe `$GITHUB_STEP_SUMMARY` y `build/release/summary.md`. Sale con 1 si hay algún fallo. Cada línea dice «aviso» o «fallo» en texto (§6 de la spec). La clasificación es **una tabla cerrada en el código** (`identity.placeholderAddress`, `identity.policyGap`, `identity.policyMark`, `package-name.provisional`, `signature.debug`, `signature.unsigned`, `tag.missing` en `testers`); cualquier otra combinación es fallo (CA-020-05).

**Artefactos (CA-020-06):** `third-party-notices.txt` (90 días) y `release-summary` (el `summary.md`, 90 días). **Ni APK ni AAB** (Q-020-5).

**Se prueba (CA-020-07):** `test/tool/release_summary_test.dart` (cada clase, cada id ausente, código inesperado, los dos modos, la dirección con aviso y fallo); `test/tool/check_release_config_test.dart` (ampliado); `test/tool/check_tag_test.dart` (un repo `git` temporal con etiquetas y ramas); `test/tool/release_workflow_test.dart`, que lee `release.yml` con `package:yaml` y comprueba los disparadores, los permisos, que cada `uses:` va fijado por un SHA de 40 caracteres, que no aparece `secrets.` ni `pull_request_target`, que el *checkout* lleva `persist-credentials: false`, que cada id esperado por el resumen tiene su paso y que ningún paso sube un `.apk` o `.aab`. Los mismos tests de `ci.yml` que apliquen.

### 3.3 Estática MASTG (CA-020-22)

`app/tool/check_package.dart <apk|aab>…` usa `aapt2 dump xmltree` y `aapt2 dump resources` (`$ANDROID_HOME/build-tools/<última>/aapt2`) y `unzip`. Los recursos van con la ruta acortada en *release* (`res/Qq.xml`, comprobado en el plan), así que se resuelven por nombre con `dump resources` (`xml/backup_rules` → archivo, incluida la variante `v28`). Las reglas:

| Regla | Qué mira |
|---|---|
| (a) | `debuggable` y `testOnly` ausentes o `false` en `<application>` |
| (b) | `usesCleartextTraffic="false"`; la configuración de red resuelta: solo `<base-config cleartextTrafficPermitted="false">` con, si las hay, `trust-anchors` **solo** `system`; ningún `<domain-config>`, ningún `<certificates src="user">` ni `<debug-overrides>` |
| (c) | `fullBackupContent` y `dataExtractionRules` presentes y resueltos; ningún `backupAgent`; `allowBackup` igual al esperado; el conjunto normalizado de reglas (sección, `include`/`exclude`, `domain`, `path`, `requiredFlags`, `disableIfNoEncryptionCapabilities`) de cada archivo igual a uno **esperado escrito en la herramienta** (el mismo que hoy fija `test/app/backup_rules_test.dart` sobre el código fuente; un test comprueba que los dos coinciden). Las variantes de recurso (`()` y `v28`) también son una lista exacta: una variante que no se espera (`v31`…) → fallo |
| (d) | Ningún `<provider>` sin `exported="false"`; **todos** los `android.support.FILE_PROVIDER_PATHS` (también de *plugins*) resueltos, y su unión = exactamente `<cache-path name="import" path="import/">` |
| (e) | `minSdkVersion` = 26 y `targetSdkVersion` ≥ `playMinTargetSdk` (36) |
| (f) | Cada entrada del paquete (en el AAB, el archivo entero, `BUNDLE-METADATA/` incluido), y las de los zip y jar anidados, leída con `unzip -p` y buscada en ASCII y en **UTF-16LE** (`resources.arsc`): `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `AIza[0-9A-Za-z_\-]{35}`, `AKIA[0-9A-Z]{16}`, `gh[pousr]_[0-9A-Za-z]{36}`, `github_pat_[0-9A-Za-z_]{22,}`, y nombres `*.jks`, `*.keystore`, `*.p12`, `*.pk8`, `*.pem`, `*.bks`, `key.properties` y `google-services.json`. Informa «regla · entrada» y como mucho los 4 primeros caracteres del hallazgo. Excepciones en `tools/release/secret-allowlist.txt` (`entrada<TAB>regla<TAB>sha256 del texto encontrado`, sin comodines: un secreto nuevo en la misma entrada no queda oculto; CL-020-12) |
| (g) | `<meta-data android.webkit.WebView.MetricsOptOut = true>` y `MainActivity` con `taskAffinity=""` |

Todo atributo que sea una referencia (`@bool/…`, `@xml/…`) se resuelve con `dump resources`; si no se puede, la regla falla. `tools/check-package.sh` la llama sobre los APK de *release* (y, en el trabajo de publicación, sobre el AAB). Para el AAB, P-020-1. Los negativos son **volcados de `aapt2` de prueba** (texto) y paquetes `zip` pequeños creados por el test en una carpeta temporal: `test/tool/check_package_test.dart`, uno por regla, cada uno nombra la regla y el archivo. Corre también en la CI de las PR sobre el APK real (CA-020-08).

### 3.4 Pasada MASTG (CA-020-23)

En el emulador de API 37 (imagen *Google APIs*, que admite `adb root`), con la compilación de *release* (`flutter build apk --release`, firmada con la clave de depuración, como la que se mide). Métodos que fija el plan:

- **(1), (2), (4), (16):** `adb root` + `find /data/data/<pkg> /data/user_de/0/<pkg> /sdcard -newer …` y `grep -rl <cadena>` excluyendo `databases/`; además `content query --uri content://media/external/file --projection owner_package_name` filtrado por el paquete (nada en MediaStore).
- **(3):** `exiftool` en el Mac sobre las fotos copiadas con `adb pull` (o el lector EXIF propio de los tests si no está; no se instala nada sin permiso).
- **(5) y (5b):** `bmgr` con el transporte local (`com.android.localtransport/.LocalTransport`), una vez con `backup_local_transport_parameters` = `is_encrypted=true` (copia en la nube, que es cifrada) y otra con `is_device_transfer=true` (transferencia); se lista lo que queda en `/data/cache/backup/…`. Si el transporte local del emulador no da la transferencia, **[Pendiente, 022]** con el motivo (CL-020-15).
- **(6):** `adb logcat -G 16M` (para que el búfer no recicle lo primero) y `adb logcat -c`, ciclo completo, `adb logcat -d -b all` y `grep -c` de la cadena, la dirección y los nombres originales; lo del sistema, aparte con su etiqueta.
- **(7) a (10), (12b):** **antes, `adb unroot`** (con *root*, `am broadcast` y `content query` llegan a componentes no exportados y la prueba no probaría nada; se anota). `am start -n …/.MainActivity` con `-d`, `--es`, `-a`; `am broadcast -n …/.notifications.WakeReceiver` (rechazado al no estar exportado); `content query` sobre la autoridad del FileProvider; (10) `am start` con la acción de abrir y un `nonce` falso, vacío y uno ya usado (la app abre normal, sin ir a la tarea por la orden); (12b) `dumpsys activity intents` para los `PendingIntent`.
- **(11):** `tools/check-recents.sh` con sus cinco órdenes.
- **(12):** `dumpsys clipboard` antes y después del ciclo, sin tocar «copiar».
- **(13):** `settings put global private_dns_mode off` (sin DNS cifrado, puerto 853) y QUIC de la WebView desactivado o analizado con `tshark` si está (UDP 443 no se ve con `tcpdump -A`); si no se puede, la limitación va escrita en `mastg.md`. Emulador lanzado con `-tcpdump <archivo>.pcap`; `tcpdump -r … -n port 53` y los SNI de los `ClientHello` dan los dominios; lista esperada: el de la web pedida y los de Safe Browsing (`safebrowsing.googleapis.com` y afines). Lo del sistema (Play Services) se separa por destino conocido y, como apoyo, `dumpsys netstats detail` (bytes por UID, no destinos).
- **(14), (15):** tareas web con `http://…`, `https://expired.badssl.com/` y un `file://`/`content://`/`javascript:` escritos a mano.
- **(17):** `strings` sobre `libapp.so` y los `dex` buscando `/Users/` y `/home/runner/`; `--split-debug-info` no se usa hoy: se anota si `libapp.so` lleva símbolos (`nm -D`/`readelf -S`).

`mastg.md` usa una fila por prueba (id, resultado **[Hecho]/[Pendiente]/hallazgo**, orden o evidencia) y una tabla de hallazgos con severidad y destino (CA-020-24). Sin capturas con datos personales (todo es de prueba en el emulador).

## 4. Modelo de datos y migraciones

**Sin cambios de esquema** (`schemaVersion` sigue en 3). Cambia cómo migra v2→v3 (CA-020-20): el test nuevo genera una BD v2 con 50 000 filas en una tarea y repartidas en 500, migra con la página de 500 y compara posición por posición con la implementación de hoy (copiada en el test como referencia); y otro, con un fallo provocado en la segunda página (un `TRIGGER` temporal que lanza `RAISE(ABORT)` al pasar de cierto id), comprueba que `user_version` sigue en 2 y que las filas no han cambiado, como el de v1→v2.

## 5. Dependencias nuevas

**Ninguna de ejecución** (CA-020-25): `pubspec.lock` sin paquetes nuevos. **Acciones de GitHub:** solo las que ya usa `ci.yml` (`checkout`, `setup-java`, `upload-artifact`, mismos SHA). Herramientas: `aapt2`, `apksigner` (*build-tools* del SDK de Android, ya instalado en los *runners* y en el Mac), `keytool` (JDK), `gh` (preinstalado en `ubuntu-latest`), `unzip`, `perl`, `git`. **Excepción posible:** `bundletool` si P-020-1 sale «b» (dependencia de herramienta, con `threat-model.md §5` y el «sí» del propietario).

## 6. Estrategia de tests

| Criterio | Tipo de test | Archivo |
|---|---|---|
| CA-020-01 | Lint del workflow | `test/tool/release_workflow_test.dart`; ejecución real tras fusionar (cierre) |
| CA-020-02 | Lint (cada id con su paso) + resumen | `test/tool/release_workflow_test.dart`, `test/tool/release_summary_test.dart` |
| CA-020-03 | Unidad (puerta, etiqueta, *package name*, firma) | `check_release_config_test.dart`, `check_tag_test.dart`, `check_signature_test.dart`; etiqueta real (CL-020-1) en el cierre, con permiso |
| CA-020-04, 05 | Unidad del resumen | `release_summary_test.dart` (verde con avisos, rojo con un permiso de más, `http://ejemplo-propio.es` y `https://example.com/%2e` rojos en `testers`) |
| CA-020-06 | Lint (artefactos permitidos) + ejecución real | `release_workflow_test.dart`; cierre |
| CA-020-07 | Los negativos de cada fila de su tabla | Los archivos de esta tabla + `ci.yml` |
| CA-020-08 | Compilación local y CI | `flutter build apk --release` local con marcadores; CI de la PR |
| CA-020-09 a 12 | Unidad | `test/tool/check_release_config_test.dart` |
| CA-020-13 | Script con manifiestos de prueba | `test/tool/check_android_permissions_test.dart` + `tools/fixtures/manifests/` |
| CA-020-14 | Script + CI | `test/tool/check_gradle_wrapper_test.dart`; paso de `ci.yml` |
| CA-020-15 | Unidad | `test/tool/png_lite_test.dart` (nuevo), `test/tool/gen_icons_test.dart` |
| CA-020-16, 17 | Datos (Drift en memoria, `customStatement` para meter valores raros) y arranque | `test/data/repository_contract_test.dart`, `test/data/settings_bounds_test.dart`, `test/app/boot_state_test.dart` |
| CA-020-18 | Revisión del diff | — |
| CA-020-19 | Barrido con 50 000 filas y un repositorio espía que cuenta ids por consulta | `test/domain/attachment_janitor_batches_test.dart`; los de 014/016 siguen |
| CA-020-20 | Migración | `test/drift/app/migration_test.dart` |
| CA-020-21 | JUnit | `PickedItemsTest.kt`; diff de `threat-model.md` |
| CA-020-22 | Unidad con volcados y zips de prueba + APK real en CI | `test/tool/check_package_test.dart`; `ci.yml` |
| CA-020-23, 24 | Manual | `mastg.md` |
| CA-020-25 | Medida y diff | `docs/perf/baseline.md`; `git diff main -- …` |
| CA-020-26 | Revisión | — |
| CA-020-27 | Unidad | `test/domain/host_display_test.dart` (`%C3`, `%`, `%ZZ`, `%E2%82`, en ruta y en dominio) y su par JUnit `HostDisplayTest.kt` |
| CA-020-28 | JUnit | `IntentSpecsTest.kt` + las de la 019 renombradas con su CA |

## 7. Seguridad, accesibilidad y rendimiento

- **Checklist (`docs/security/checklist.md`), CI:** permisos mínimos, SHA, sin `pull_request_target`, credenciales no persistidas, sin secretos; el resumen no imprime secretos (la regla f trunca) ni contenido de usuario (no lo hay).
- **Cadena de suministro:** el *wrapper* de Gradle pasa a verificarse (012-S6); `check_package` no añade dependencias.
- **Superficie de la app:** ningún permiso, componente ni texto nuevo; el manifiesto no cambia (CA-020-25). Las reglas (b), (c), (d) y (g) blindan lo que ya hay.
- **Accesibilidad:** no aplica (sin UI).
- **Rendimiento:** `_raw` con `customSelect` y `CASE` cuesta lo mismo que hoy; el arranque se mide igual (CA-020-25, 20 + 20 arranques en el emulador de API 37 con `tools/measure-cold-start.sh`, frente a dos series de `main` para la deriva). El barrido y la migración, lineales y con memoria acotada.

## 8. Riesgos, alternativas y decisiones pendientes

**Para el propietario (antes de aprobar el plan):**

- **P-020-1 · Leer el manifiesto del AAB.** El AAB guarda el manifiesto en formato *protobuf* (`base/manifest/AndroidManifest.xml`), no en el binario del APK.
  - **(a) Recomendada:** reempaquetar el módulo `base/` del AAB como un APK *proto* temporal (`manifest/AndroidManifest.xml` → `AndroidManifest.xml`, `resources.pb` y `res/` a la raíz) y leerlo con el mismo `aapt2 dump`, que admite el formato *proto*. Sin dependencias. La primera tarea que lo usa lo comprueba con un AAB real; si `aapt2` no lo lee, se para y se vuelve aquí. Un AAB con algún módulo distinto de `base/` → fallo.
  - (b) `bundletool dump manifest`: es la herramienta oficial, pero es una dependencia nueva (un `.jar` descargado y fijado por suma, P11).
- **P-020-2 · El `gradle-wrapper.jar` no está en el repositorio (discrepancia con CA-020-14).** `app/android/.gitignore` lo excluye, igual que `gradlew`: lo genera la herramienta de Flutter al compilar, desde el SDK fijado en `tools/flutter-sdk.lock`. La spec dice «el `gradle-wrapper.jar` del repositorio».
  - **(a) Recomendada:** leerlo como «el `gradle-wrapper.jar` que se ejecuta»: la comprobación corre **después** de que Flutter lo genere (en CI y en el trabajo de publicación) y lo compara con las sumas que publica Gradle (fijadas en `tools/gradle-wrapper.lock` con su fuente). Se enmienda la frase de CA-020-14 en el cierre, anotando el límite: la comprobación **detecta** un jar alterado después de que se haya ejecutado; no impide que se ejecute (residual en `threat-model.md` §5).
  - (b) Subir el `gradle-wrapper.jar` y `gradlew` al repositorio (quitar la línea del `.gitignore`). Más clásico, pero un binario más en el repo y Flutter lo puede reescribir en una migración.
- **P-020-3 · La comprobación 0 (CI y Security del commit).**
  - **(a) Recomendada:** leer las ejecuciones con `gh run list --commit <sha>` (permiso `actions: read`): la última ejecución de `CI` y de `Security` del evento `push` a `main` sobre ese commit debe haber terminado en `success`. Si alguna no ha terminado o no existe, **falla** con «espera a que termine la CI de este commit y vuelve a lanzar» (nunca espera ni da por buena). No repite el trabajo de `flutter`, que tarda y ya ha corrido. **Residual:** el OSV-Scanner de `Security` es del momento de fusionar; una vulnerabilidad publicada después no para el modo estricto hasta la ejecución semanal. Se anota en `threat-model.md` §5 y `/release-checklist` pide mirar la última ejecución semanal de `Security` antes de publicar.
  - (b) Repetir sus comprobaciones dentro del trabajo (formato, *analyze*, generado, tests, JVM, licencias, OSV). Independiente de otras ejecuciones, pero duplica unos 15–20 min y OSV-Scanner es un *workflow* reutilizable que pide `security-events: write`.
- **P-020-4 · Quién hace la pasada MASTG.** Recomendado: el **coordinador**, con el emulador (no el Xiaomi), igual que T-019-14. Es interactiva, larga y necesita `adb root`; un `spec-task` la haría a ciegas.

**Riesgos:**

- **`aapt2` cambia el formato de su volcado** en otra versión de *build-tools*: el parser se apoya en las líneas `E:` / `A:` estables y el test usa volcados reales guardados como *fixtures*; un formato que no se entiende es un fallo (falla cerrada), nunca un verde.
- **El modo estricto falla siempre hoy** (a, b, e, f): es lo esperado (CA-020-03). La prueba real con una etiqueta `vX.Y.Z` = `0.1.0` necesita el permiso del propietario y se borra después (CL-020-1); va en la sesión de cierre, tras fusionar.
- **El lanzamiento a mano exige el workflow en `main`:** la ejecución real de los dos modos va después de fusionar; la spec queda **Implementada parcialmente** hasta entonces (CA-020-01).
- **Falsos positivos de secretos (CL-020-12):** se revisan uno a uno y van a la lista de excepciones con su motivo en la PR.
- **La migración por páginas** podría numerar distinto si dos filas comparten `(task_id, created_at, id)`: no pasa (`id` es clave primaria), y el test compara con la implementación de hoy.
- **Alternativa descartada para la migración:** un único `UPDATE … FROM (SELECT ROW_NUMBER() OVER …)` en SQL. Sin memoria en Dart y más corto, pero la spec pide «por páginas» y depende de la versión de SQLite (3.33+ para `UPDATE … FROM`); se queda el *keyset*.
