# Checklist de seguridad (Definition of Done y revisión de PR)

Se marcan los puntos que apliquen a la PR; los que no apliquen se dejan como "N/A". La plantilla de PR enlaza a este archivo. Referencias entre paréntesis: amenazas de `threat-model.md`.

## Siempre

- [ ] Sin secretos, claves, tokens ni archivos de firma en el diff (secret scanning de GitHub sin alertas; el hook de Claude Code bloquea rutas sensibles).
- [ ] Sin logs de contenido del usuario (texto, rutas, URL) en *release* (T-2).
- [ ] Sin llamadas de red nuevas. Si las hay, justificadas y alineadas con P4 (T-13).
- [ ] Sin permisos nuevos en `AndroidManifest`/`Info.plist`. Si los hay, pedidos en el momento de uso y con texto de propósito traducido (T-13). Los permitidos hoy en Android son solo `INTERNET`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` (spec 019); cualquier otro (alarmas exactas, almacenamiento, etc.) pide ADR y se añade a `tools/check-android-permissions.sh` en la misma PR.
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

**Si importa varios archivos a la vez (un grupo de fotos, spec 016, CA-016-24; T-3, T-7, T-16):**

- [ ] **El tope va en el origen y antes de todo:** como máximo 10 (`ImageLimits.maxGroup`); ningún elemento más se abre, consulta ni copia, aunque el selector devuelva miles (test con 5000: se tocan 10) ni en la web de pruebas (`takeFirst`).
- [ ] **Cada archivo pasa por toda la cadena de una foto suelta**, en el mismo orden (rechazo de origen propio o autoridad ajena → copia acotada → tipo por contenido → dimensiones por cabecera → recodificación → borrado del original); ninguna comprobación se salta por ir en grupo; si uno falla, los demás siguen.
- [ ] **Uno a uno:** nunca más de un original en disco ni dos limpiezas a la vez, y no se empieza el siguiente hasta que el anterior termina o vence su tiempo; tiempo por archivo (20 s) y **total** (2 min) con tiempo activo, y un proceso congelado no los gasta.
- [ ] **Cancelar y vencer son un estado del grupo:** tras cualquiera, ninguna foto más en ningún momento; nada en la zona temporal; todas las preparaciones protegidas del barrido como una unidad hasta guardar o descartar (también con el editor abierto y con el deshacer).
- [ ] **Sin texto de excepción ni datos del archivo** (URI, ruta, nombre, número) en ningún registro, aviso ni mensaje de error: los errores de varios archivos viajan **solo como un código** (`debugPrint`, `print` y `FlutterError` comprobados en los tests).
- [ ] Espacio libre comprobado **antes** de empezar (con lo que ya ocupa el grupo que se reemplaza) y, si se agota a mitad, se descarta todo.
- [ ] Lo que se lee de la BD al mostrar el grupo está **acotado en SQL** y tolera datos raros (posiciones repetidas o con huecos, más de 10 filas, tipo desconocido, medidas fuera de rango) sin lanzar ni cargar sin tope (CA-016-25); editar solo el texto no borra filas.
- [ ] Sin dependencias, permisos ni componentes nuevos: `pubspec.lock`, manifiesto y `res/xml` (incluidos `backup_rules.xml` y `data_extraction_rules.xml`) sin cambios **salvo lo que añade la spec 019** (T-019-06: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, el `WakeReceiver` y las exclusiones `device_*`); `tools/check-android-permissions.sh release` da solo `INTERNET`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` (sin alarmas exactas) y comprueba la lista blanca de componentes.

## Si toca URL o WebView (T-4, T-5, T-6)

- [ ] Solo `http(s)`; tests con `javascript:`, `data:`, `file:`, `intent:`, `user:pass@`, IDN mixto.
- [ ] WebView endurecida (canal `una/webview`, spec 009): sin acceso a archivos ni contenido, sin guardar formularios, contenido mixto `NEVER_ALLOW`, sin permisos, diálogos, selector de archivos, pantalla completa ni descargas; depuración remota solo en *debug*; el envoltorio del `WebViewClient` puesto y comprobado (ADR-0017). Nada de la página se queda: cookies, almacenamiento web y caché se borran al salir y en el arranque siguiente, y quedan fuera de la copia (ADR-0016).
- [ ] Sin navegación (ADR-0018): solo la dirección guardada (con las redirecciones del servidor de la carga inicial) y las anclas de la misma página; ventanas nuevas bloqueadas; nada sale al navegador ni a otra app desde la página. ~~Navegación fuera del dominio → navegador del sistema~~.
- [ ] Sin excepciones de ATS ni de *cleartext*.
- [ ] Certificado inválido → cancelar siempre (`onReceivedSslError`), con test (servidor local con certificado autofirmado, sin red externa). ~~HTTP ≥ 400 del marco principal → captura fallida (I-5)~~: sin captura (ADR-0016).
- [ ] Ningún canal JS (`addJavaScriptChannel`) ni `addJavascriptInterface`.

## Si toca el almacenamiento o el esquema (T-1, T-7)

- [ ] Nueva `schemaVersion` + captura + test de migración.
- [ ] Datos solo en el sandbox; clase de protección de archivos correcta; nada en almacenamiento externo.
- [ ] Reglas de backup revisadas si hay rutas nuevas.
- [ ] Las migraciones que borran datos van en una **transacción explícita** (drift no la abre), son idempotentes, `secure_delete` está activo antes de migrar y hay un test de que las pendientes no se tocan y de que un fallo a mitad no deja nada cambiado.

## Si toca integración nativa (T-8)

- [ ] Ningún componente exportado nuevo (el `WakeReceiver` de la 019 es `exported="false"`, `directBootAware="true"`, solo con difusiones protegidas del sistema y la acción de su alarma en ningún `<intent-filter>`; lo vigila `check-android-permissions.sh`); FileProvider con permisos puntuales y solo de lectura (única excepción: la salida de la cámara, escritura sobre un solo archivo de `cache/import/` y revocada al volver, spec 007).
- [ ] Sin esquemas de URL ni *deep links* nuevos sin su ADR. `check-android-permissions.sh` falla si la `MainActivity` tiene más de un `<intent-filter>` o el suyo no es exactamente `MAIN` + `LAUNCHER` (sin `<data>`, `BROWSABLE`, `DEFAULT` ni otras acciones), y cuenta `<uses-permission-sdk-23>` y `<uses-permission-sdk-m>` (spec 020, CA-020-13); un caso nuevo, con su manifiesto negativo en `tools/fixtures/manifests/`.
- [ ] Todo `PendingIntent` nuevo se describe en `IntentSpecs.kt` (explícito, `FLAG_IMMUTABLE`, nunca `FLAG_MUTABLE`) y se crea solo en los adaptadores (`native_pending_intents_test.dart`, spec 020, CA-020-28).

## Si toca notificaciones, alarmas o la copia derivada (T-17, T-1, T-2, T-7, T-8; spec 019, ADR-0025)

Aplica si la PR toca `android/app/src/main/kotlin/invalid/pending/app/notifications/`, `MainActivity.kt` (permiso, `onNewIntent`, `onStop`), `lib/features/settings/notifications_*`, `lib/data/platform/notification_gateway.dart`, `res/xml/*backup*`/`data_extraction_rules.xml` o el `<receiver>` del manifiesto.

- [ ] **Permisos y componentes:** el manifiesto de release pide solo `INTERNET`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` (ninguno de alarmas exactas: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) y `tools/check-android-permissions.sh release` (desde `app/`, tras compilar) comprueba la lista blanca: el `WakeReceiver` es **`exported="false"`** y **`directBootAware="true"`**, solo con difusiones protegidas del sistema, y la acción de la alarma propia no está en ningún `<intent-filter>`. `POST_NOTIFICATIONS` se pide **al encender el interruptor**, nunca al arrancar ni al abrir Ajustes (P5).
- [ ] **Ninguna copia del texto de las tareas fuera de la BD (CA-019-23):** la copia derivada (`una_notifications`, almacenamiento «device protected») tiene **solo cinco claves** (`on`, `perDay`, `lang`, `lastAttended`, `foregroundAt`), ni texto, ni etiqueta, ni dominio, ni el `nonce` (`DerivedStoreTest`); se lee como entrada **no fiable** (un tipo o valor raro = apagado; una hora futura o ilegible se ignora); queda **fuera de la copia de seguridad** y de la transferencia (`device_root`, `device_file`, `device_database` y `device_sharedpref` excluidos en `backup_rules.xml`, `xml-v28/backup_rules.xml` y las **dos** secciones de `data_extraction_rules.xml`; `backup_rules_test.dart`; un `<exclude>` de un dominio que ningún `<include>` cubre lo rechaza el *lint* de release).
- [ ] **Sin registros (T-2):** ni el nativo ni Dart escriben texto de tareas, etiquetas, direcciones ni texto de excepciones en ningún registro, pantalla ni `debugPrint` (`test/app/native_no_logging_test.dart` busca `Log.`, `println`, `printStackTrace`, `Timber` y `.message` en un `catch`); los errores del canal viajan sin texto. En un cambio de esta zona se repite en el emulador un ciclo completo con una tarea de texto secreto y `adb logcat -d | grep` da 0 coincidencias (`specs/019-notificaciones/dispositivo.md`).
- [ ] **Lectura de la tarea (T-17):** `TaskQuery.kt` es un SQL **fijo**, de solo lectura (`OPEN_READONLY`, `PRAGMA query_only`, `user_version` comprobado), **acotado en SQL** (`substr`, `LIMIT 2`) y compatible con SQLite 3.18; cualquier fallo es «ilegible» y da la versión genérica, sin registrar nada; el contrato con las migraciones de la app lo vigila `test/data/native_task_query_contract_test.dart` (`EXPLAIN QUERY PLAN` sin `SCAN`). Un cambio de esquema que toque esa consulta rompe la CI.
- [ ] **La notificación:** versión **completa privada** y **genérica pública** (sin ninguna parte de la tarea), `setLocalOnly(true)`, id fijo (una sola a la vez), sin acciones ni insignia, canal único de importancia por defecto sin sonido, vibración ni luz propios; la orden de abrir lleva acción fija **y un `nonce`** de un solo uso solo en memoria (otra app no puede forzar la vuelta a la tarea actual) y `PendingIntent` explícitos con `FLAG_IMMUTABLE`.
- [ ] **JUnit solo en pruebas:** `junit:junit:4.13.2` como `testImplementation` y nada más; `tools/check-apk-no-test-classes.sh` sobre el APK de release (CI) sin `org/junit` ni `org/hamcrest`. Ninguna otra dependencia con red ni de notificaciones (nada de `flutter_local_notifications`, ADR-0025).
- [ ] **Privacidad ante el usuario:** el interruptor sigue **apagado por defecto** y la línea de privacidad (CA-019-29) se ve siempre bajo la fila; la política de privacidad (`docs/legal/privacy-policy.md`) y, en F6, Data Safety y la ficha dicen lo mismo (notificaciones locales con el contenido de la tarea y el permiso).

## Si abre enlaces externos (T-4, T-13, specs 012 y 015, ADR-0026)

Aplica si la PR toca `LinkOpener.kt`, `privacyLink`, `identity.yaml` (las tres direcciones), `check_release_config.dart`, `external_page.dart`, `features/settings/` o `assets/licenses/`. La app **ya no muestra** licencias ni política: solo abre tres webs en el navegador (ADR-0026). `link_confirm_sheet.dart` (hoja de confirmación) es de la tarea con PDF (spec 008) y no se usa en Ajustes.

- [ ] Solo se abren direcciones `https` (`privacyLink`: sin `usuario@`, espacios ni controles), **sin confirmación previa**: las tres direcciones (`privacyPolicyUrl`, `thirdPartyLicensesUrl` y `helpUrl`) son constantes de compilación (`AppIdentity`, generada de `identity.yaml`), no las escribe el usuario ni salen de ningún dato guardado (CA-015-12a, enmienda del 2026-10-05, y CA-015-13a). Nada de esto pasa por la vista web de la tarea (ADR-0018 no aplica). La app no abre conexiones: lo hace el navegador (P4).
- [ ] `LinkOpener.canOpen` solo comprueba (`resolveActivity`): sin `startActivity`, sin registrar ni guardar la dirección ni el error, y se pregunta en cada toque; `<queries>` y permisos sin cambios (`tools/check-android-permissions.sh release`: solo `INTERNET`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` desde la 019). Sin app que abra el enlace (o `open` falso, o dirección no `https`): aviso «No hay ninguna app…», sin mover el foco.
- [ ] Las direcciones no llevan consulta ni fragmento (`?`, `#`) y ninguna lleva datos de la app: la puerta (`check_release_config.dart`) valida **las tres** con las mismas reglas que `privacyLink` (ninguna más permisiva), exige que sean **distintas entre sí** (comparación normalizada, también `/x` y `/x/`) y falla con claves ausentes, vacías o que no son texto (CA-015-13b). El `.g.dart` desfasado respecto a `identity.yaml` también falla (`gen_identity.dart --check`).
- [ ] **Valores guardados ilegibles (CA-015-26, T-2, T-7):** `locale`, `keepScreenOn` y `lockZoom` se leen con decodificadores que nunca lanzan y fallan cerrado al defecto (`system`, apagada y apagada); nunca se construye un `Locale` del texto guardado; el error no se registra ni se muestra. Desde la spec 020 (CA-020-16, 17), la lectura se **acota en SQL** (solo texto de 16 caracteres o menos llega a Dart) y `firstRunDone` y `hasEverHadTasks` también caen a su defecto: una clave nueva de `settings` se lee por el mismo camino (`_raw` + decodificador que no lanza), con su test en el contrato compartido.
- [ ] `tools/check-licenses.sh` pasa sobre el APK *release* de cada ABI (paquetes Dart, cada `.so`, artefactos de Android, OFL de las fuentes) y **emite el archivo de avisos** (`app/build/third-party-notices.txt`), verificado sobre el archivo emitido (CA-015-14b). Los textos de `assets/licenses/*.txt` y los `OFL.txt` **siguen dentro del paquete** aunque no se muestren (ADR-0026). Un artefacto nuevo en `android.txt` tiene su licencia comprobada en el POM contra `threat-model.md §5` y anotada en la PR; al actualizar PDFium se regenera `pdfium.txt` (su línea de origen debe coincidir con `pdfium.lock`).
- [ ] **Antes de cada versión entregada a testers y antes de publicar** (F6): la puerta de la identidad (`tools/check-release-config.sh`: las tres direcciones, `https` propias, con la ruta restringida de CA-020-09, sin dominios reservados, `gen_identity.dart --check` y la política sin huecos ni marcas `[Suposición]`/`[Pendiente]` en ES y EN) **ya no se pasa a mano**: la corre el **trabajo de publicación** (sección siguiente), que en modo testers lista lo que falla y en modo estricto tiene que pasar. Las tres coinciden con las de la ficha de la tienda (eso sigue siendo a mano, `/release-checklist`). **[Pendiente, PD-2]** las direcciones reales: hoy son marcadores `example.com`.
- [ ] **Antes de publicar** (F6): la web de licencias publica el archivo de avisos de **esta** versión (adjunto a la release) y se hizo la **revisión legal** de ADR-0026 (punto bloqueante, `/release-checklist`).
- [ ] Toda pantalla o hoja nueva entra en la matriz de "Recientes" (CA-011-02; la 012 añadió los tres niveles; la 015 los sustituye por Ajustes y la página de Idioma).

## "Recientes": lo que el sistema enseña de la app (T-2, spec 011, ADR-0019)

Aplica si la PR toca `MainActivity.kt`, `RecentsPrivacy.kt`, el tema de arranque (`LaunchTheme`, `launch_background.xml`), la ventana o `FLAG_SECURE`, o si actualiza Flutter o el SDK de Android.

- [ ] La tarjeta de "Recientes" no enseña contenido de la app (A en Android 13+, B en 8–12): sin `FLAG_SECURE` fija ni bloqueo de las capturas con la app delante (CA-011-04). Cualquier pantalla nueva entra en la matriz de CA-011-02 (sin pantallas "seguras" y "no seguras").
- [ ] **Antes de cada versión entregada a testers** (CL-011-13, R-3; la 011 no tiene test de CI): ejecutar `tools/check-recents.sh` en el emulador y anotar el resultado en la entrega (ya recogido en la skill `/release-checklist`): `capture` y `compare` con dos tareas (A y B), `secure`, `loop 10` y `record 10`. Con `PKG` y `serial` del emulador; un dispositivo físico solo con permiso del propietario (`ALLOW_PHYSICAL=1`). Guía y límites conocidos en `docs/testing.md` y `specs/011-ocultar-recientes/dispositivo.md`.
- [ ] **Varias fotos (spec 016, CA-016-13):** `tools/check-recents.sh $S fixtures push` deja tres fotos distinguibles; con una tarea de las tres a la vista se repite el flujo (`capture` con la foto 1 y con la 3, `compare`, `loop` y `record`) y también con la preselección del editor, "Foto no disponible" y "Preparando foto {i} de {n}…"; después `fixtures clean`. **En horizontal el script no está calibrado** (`docs/testing.md`): hasta que lo esté, se comprueba recortando la franja del borde del sistema.
- [x] **[Cerrada sin verificar, PD-10]** Repetirlo en emuladores de Android 8 (API 26) y 12L (API 32): el propietario cerró PD-10 el 2026-10-16 (spec 022, CA-022-06) sin hacerlo y acepta el riesgo; el mecanismo B no está verificado (**[Suposición]**) y la regla de desempate no se aplica sin medida. En las notas de la beta (F6) se anota que en Android 8–12 la miniatura de «Recientes» podría verse.
- [ ] Los límites aceptados siguen anotados en las notas de la beta: "Recientes" abierto desde la propia app y gesto de cambio entre apps (ventana en vivo), hoja parcial del selector de fotos y fotograma blanco al volver (CL-011-14, CL-011-6, CL-011-15, CA-011-03).

## Trabajo de publicación (spec 020; T-10 a T-13)

**Qué es.** `.github/workflows/release.yml`, aparte de `ci.yml`: compila desde el commit los APK por ABI y el **AAB** de *release* (lockfile obligatorio, Flutter de `tools/flutter-sdk.lock`) y les pasa todas las comprobaciones. Cada una va por `tools/release/run-check.sh`, que anota su código sin cortar el trabajo, y `app/tool/release_summary.dart` decide al final, con el resumen en el trabajo (`$GITHUB_STEP_SUMMARY`) y como artefacto (`release-summary`, 90 días), junto al archivo de avisos (`third-party-notices`, 90 días). **No sube APK ni AAB** (Q-020-5): una entrega a testers se compila del mismo commit que pasó el modo testers.

**Modos.**

- **Estricto:** al subir una etiqueta `vX.Y.Z` (con confirmación del propietario). Cualquier fallo y cualquier aviso de identidad lo ponen en rojo. **Hoy falla siempre** (direcciones marcador, marcas de la política, *package name* `invalid.pending.*` y firma de depuración): es lo esperado hasta PD-2 y F6. En F6, lo que se sube a Play es el AAB de este modo, firmado entonces, nunca una compilación local.
- **Testers:** a mano desde GitHub (*Run workflow*), **solo desde `main`** (desde otra rama, rojo antes de compilar). Los avisos de identidad no lo paran: salen en el resumen, uno por línea («aviso · comprobación · clave o archivo · motivo»), con la frase final «Esta versión no se puede publicar.». Cualquier otro fallo lo pone en rojo.

**Avisos de identidad (lista cerrada, CA-020-05):** una dirección de `identity.yaml` marcador o con dominio reservado; el *package name* provisional; un hueco o una marca de la política; la firma de depuración o un paquete sin firmar (y, en estricto, la falta de `tools/release/upload-cert.sha256`, **[Pendiente, F6]**); en modo testers, la falta de etiqueta. **Todo lo demás es un fallo en los dos modos**, también una dirección con un aviso y un fallo a la vez (`https://example.com/%2e`), y una comprobación nueva lo es por defecto.

**Comprobaciones (ids del resumen):** `ci-runs` (CI y Security de ese commit del *push* a `main`, terminadas en verde), `lockfile`, `build`, `identity` (puerta de la identidad), `native-strings`, `permissions` (APK y AAB), `test-classes`, `pdfium`, `licenses` (y `--negative`), `size` (< 25 MB comprimido por ABI), `mastg-static` (APK y AAB), `package-name`, `signature` y `tag` (forma `vX.Y.Z`, igual a `pubspec.yaml`, commit en `main` y `versionCode` mayor que el de la etiqueta anterior). **Falla cerrada:** una comprobación que no corre, falta, se repite, termina con un código inesperado o no casa con el resultado que da GitHub de su paso es un fallo.

**Estática MASTG (CA-020-22; `app/tool/check_package.dart` vía `tools/check-package.sh`, también en la CI de cada PR sobre los APK):** falla si el paquete es (a) depurable o `testOnly`; (b) admite tráfico en claro, lleva `<domain-config>`, certificados del usuario o anclas de depuración; (c) las reglas de copia y de transferencia no son **exactamente** las esperadas (las mismas que `test/app/backup_rules_test.dart`), hay un `backupAgent` o una variante de recurso inesperada; (d) hay un proveedor exportado o las rutas del FileProvider van más allá de `cache/import/`; (e) `minSdk` ≠ 26 o `targetSdk` < 36 (`playMinTargetSdk`); (f) algo con forma de secreto (claves privadas, de Google, de AWS, *tokens* de GitHub, archivos de firma), también en UTF-16LE y dentro de zips y jars anidados, sin imprimirlo (excepciones solo en `tools/release/secret-allowlist.txt`, una por entrada, regla y sha256, revisadas en la PR; hoy vacía); (g) `MetricsOptOut` no es `true` o la `MainActivity` pierde `taskAffinity=""`.

**Al cambiar algo de esta zona** (`release.yml`, `tools/release/`, `app/tool/check_*.dart`, `release_summary.dart`, `tools/check-*.sh`):

- [ ] Cada comprobación sigue teniendo su **caso negativo** que falla nombrando lo que falla (tabla de CA-020-07; `test/tool/`), y una nueva entra en la lista de ids esperados de `release_summary.dart` y en `release_workflow_test.dart`.
- [ ] Ningún aviso nuevo sin que una spec lo añada a la lista cerrada; la tabla de clases está en `release_summary.dart`.
- [ ] El workflow sigue con disparadores `v*` y `workflow_dispatch` y nada más, `contents: read` y `actions: read`, acciones fijadas por SHA, `persist-credentials: false`, sin `secrets.`, sin `pull_request_target`, sin `${{ }}` dentro de un `run:`, `GH_TOKEN` solo en `ci-runs` y sin subir `.apk` ni `.aab` (lo comprueba `release_workflow_test.dart`).
- [ ] Bajo `set -o pipefail`, nada de `… | grep -q` (falsos negativos por SIGPIPE): `grep … >/dev/null`.
- [ ] Al mirar un resultado del trabajo: la ejecución viene de `main` (modo testers) o de la etiqueta `v*` (estricto), con el `release.yml` de ese commit; una lanzada desde otra rama no cuenta (C-4 de la 020: hasta el *ruleset* de F6, cualquiera con escritura puede lanzar un YAML cambiado).
- [ ] Una excepción de secretos nueva, con su motivo en la PR (nunca un patrón que desactive la regla).
- [ ] Al subir Gradle o Flutter: `distributionSha256Sum` y `tools/gradle-wrapper.lock` actualizados en la misma PR, con las sumas de gradle.org y services.gradle.org (`tools/check-gradle-wrapper.sh`, CL-020-18).
- [ ] Al subir el `targetSdk` mínimo de Play: el valor en su único sitio (`playMinTargetSdk`, CL-020-13).

## Si toca CI, workflows o la web (T-9, T-11)

- [ ] `permissions:` mínimos; acciones fijadas por SHA; sin `pull_request_target` con código de la PR.
- [ ] Secretos solo en *environments* protegidos; nunca en jobs de PR. El trabajo de publicación no usa ninguno hasta F6 (sección anterior).
- [ ] Lo que venga de una referencia, una etiqueta o un evento llega a los `run:` por `env:` (nunca `${{ }}` dentro del guion) y se sanea antes de imprimirlo o meterlo en un JSON.
- [ ] Cabeceras de `vercel.json` intactas o reforzadas; sin scripts de terceros.

## Skills, plugins y MCP (P11)

- [ ] Nada instalado a nivel global ni con confirmación automática.
- [ ] Toda skill o plugin de terceros nuevo: contenido revisado y explicado en la PR, registrado en `skills-lock.json`.
