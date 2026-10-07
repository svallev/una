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

**Si importa varios archivos a la vez (un grupo de fotos, spec 016, CA-016-24; T-3, T-7, T-16):**

- [ ] **El tope va en el origen y antes de todo:** como máximo 10 (`ImageLimits.maxGroup`); ningún elemento más se abre, consulta ni copia, aunque el selector devuelva miles (test con 5000: se tocan 10) ni en la web de pruebas (`takeFirst`).
- [ ] **Cada archivo pasa por toda la cadena de una foto suelta**, en el mismo orden (rechazo de origen propio o autoridad ajena → copia acotada → tipo por contenido → dimensiones por cabecera → recodificación → borrado del original); ninguna comprobación se salta por ir en grupo; si uno falla, los demás siguen.
- [ ] **Uno a uno:** nunca más de un original en disco ni dos limpiezas a la vez, y no se empieza el siguiente hasta que el anterior termina o vence su tiempo; tiempo por archivo (20 s) y **total** (2 min) con tiempo activo, y un proceso congelado no los gasta.
- [ ] **Cancelar y vencer son un estado del grupo:** tras cualquiera, ninguna foto más en ningún momento; nada en la zona temporal; todas las preparaciones protegidas del barrido como una unidad hasta guardar o descartar (también con el editor abierto y con el deshacer).
- [ ] **Sin texto de excepción ni datos del archivo** (URI, ruta, nombre, número) en ningún registro, aviso ni mensaje de error: los errores de varios archivos viajan **solo como un código** (`debugPrint`, `print` y `FlutterError` comprobados en los tests).
- [ ] Espacio libre comprobado **antes** de empezar (con lo que ya ocupa el grupo que se reemplaza) y, si se agota a mitad, se descarta todo.
- [ ] Lo que se lee de la BD al mostrar el grupo está **acotado en SQL** y tolera datos raros (posiciones repetidas o con huecos, más de 10 filas, tipo desconocido, medidas fuera de rango) sin lanzar ni cargar sin tope (CA-016-25); editar solo el texto no borra filas.
- [ ] Sin dependencias, permisos ni componentes nuevos: `pubspec.lock`, manifiesto y `res/xml` (incluidos `backup_rules.xml` y `data_extraction_rules.xml`) sin cambios; `tools/check-android-permissions.sh release` da solo `INTERNET`.

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

- [ ] Ningún componente exportado nuevo; FileProvider con permisos puntuales y solo de lectura (única excepción: la salida de la cámara, escritura sobre un solo archivo de `cache/import/` y revocada al volver, spec 007).
- [ ] Sin esquemas de URL ni *deep links* nuevos sin su ADR.

## Si abre enlaces externos (T-4, T-13, specs 012 y 015, ADR-0026)

Aplica si la PR toca `LinkOpener.kt`, `privacyLink`, `identity.yaml` (las tres direcciones), `check_release_config.dart`, `external_page.dart`, `features/settings/` o `assets/licenses/`. La app **ya no muestra** licencias ni política: solo abre tres webs en el navegador (ADR-0026). `link_confirm_sheet.dart` (hoja de confirmación) es de la tarea con PDF (spec 008) y no se usa en Ajustes.

- [ ] Solo se abren direcciones `https` (`privacyLink`: sin `usuario@`, espacios ni controles), **sin confirmación previa**: las tres direcciones (`privacyPolicyUrl`, `thirdPartyLicensesUrl` y `helpUrl`) son constantes de compilación (`AppIdentity`, generada de `identity.yaml`), no las escribe el usuario ni salen de ningún dato guardado (CA-015-12a, enmienda del 2026-10-05, y CA-015-13a). Nada de esto pasa por la vista web de la tarea (ADR-0018 no aplica). La app no abre conexiones: lo hace el navegador (P4).
- [ ] `LinkOpener.canOpen` solo comprueba (`resolveActivity`): sin `startActivity`, sin registrar ni guardar la dirección ni el error, y se pregunta en cada toque; `<queries>` y permisos sin cambios (`tools/check-android-permissions.sh release`: solo `INTERNET`). Sin app que abra el enlace (o `open` falso, o dirección no `https`): aviso «No hay ninguna app…», sin mover el foco.
- [ ] Las direcciones no llevan consulta ni fragmento (`?`, `#`) y ninguna lleva datos de la app: la puerta (`check_release_config.dart`) valida **las tres** con las mismas reglas que `privacyLink` (ninguna más permisiva), exige que sean **distintas entre sí** (comparación normalizada, también `/x` y `/x/`) y falla con claves ausentes, vacías o que no son texto (CA-015-13b). El `.g.dart` desfasado respecto a `identity.yaml` también falla (`gen_identity.dart --check`).
- [ ] **Valores guardados ilegibles (CA-015-26, T-2, T-7):** `locale` y `keepScreenOn` se leen con decodificadores que nunca lanzan y fallan cerrado al defecto (`system` y apagada); nunca se construye un `Locale` del texto guardado; el error no se registra ni se muestra.
- [ ] `tools/check-licenses.sh` pasa sobre el APK *release* de cada ABI (paquetes Dart, cada `.so`, artefactos de Android, OFL de las fuentes) y **emite el archivo de avisos** (`app/build/third-party-notices.txt`), verificado sobre el archivo emitido (CA-015-14b). Los textos de `assets/licenses/*.txt` y los `OFL.txt` **siguen dentro del paquete** aunque no se muestren (ADR-0026). Un artefacto nuevo en `android.txt` tiene su licencia comprobada en el POM contra `threat-model.md §5` y anotada en la PR; al actualizar PDFium se regenera `pdfium.txt` (su línea de origen debe coincidir con `pdfium.lock`).
- [ ] **Antes de cada versión entregada a testers y antes de publicar** (F6): `tools/check-release-config.sh` (las tres direcciones, `https` propias, sin dominios reservados, y `gen_identity.dart --check`); en una entrega a testers con marcadores se anota qué falla, antes de publicar tiene que pasar. Las tres coinciden con las de la ficha de la tienda y sin huecos ES/EN en `docs/legal/privacy-policy.md`. **[Pendiente, PD-2]** las direcciones reales: hoy son marcadores `example.com`.
- [ ] **Antes de publicar** (F6): la web de licencias publica el archivo de avisos de **esta** versión (adjunto a la release) y se hizo la **revisión legal** de ADR-0026 (punto bloqueante, `/release-checklist`).
- [ ] Toda pantalla o hoja nueva entra en la matriz de "Recientes" (CA-011-02; la 012 añadió los tres niveles; la 015 los sustituye por Ajustes y la página de Idioma).

## "Recientes": lo que el sistema enseña de la app (T-2, spec 011, ADR-0019)

Aplica si la PR toca `MainActivity.kt`, `RecentsPrivacy.kt`, el tema de arranque (`LaunchTheme`, `launch_background.xml`), la ventana o `FLAG_SECURE`, o si actualiza Flutter o el SDK de Android.

- [ ] La tarjeta de "Recientes" no enseña contenido de la app (A en Android 13+, B en 8–12): sin `FLAG_SECURE` fija ni bloqueo de las capturas con la app delante (CA-011-04). Cualquier pantalla nueva entra en la matriz de CA-011-02 (sin pantallas "seguras" y "no seguras").
- [ ] **Antes de cada versión entregada a testers** (CL-011-13, R-3; la 011 no tiene test de CI): ejecutar `tools/check-recents.sh` en el emulador y anotar el resultado en la entrega (ya recogido en la skill `/release-checklist`): `capture` y `compare` con dos tareas (A y B), `secure`, `loop 10` y `record 10`. Con `PKG` y `serial` del emulador; un dispositivo físico solo con permiso del propietario (`ALLOW_PHYSICAL=1`). Guía y límites conocidos en `docs/testing.md` y `specs/011-ocultar-recientes/dispositivo.md`.
- [ ] **Varias fotos (spec 016, CA-016-13):** `tools/check-recents.sh $S fixtures push` deja tres fotos distinguibles; con una tarea de las tres a la vista se repite el flujo (`capture` con la foto 1 y con la 3, `compare`, `loop` y `record`) y también con la preselección del editor, "Foto no disponible" y "Preparando foto {i} de {n}…"; después `fixtures clean`. **En horizontal el script no está calibrado** (`docs/testing.md`): hasta que lo esté, se comprueba recortando la franja del borde del sistema.
- [ ] **[Pendiente, PD-10]** Antes de dar la beta a testers, repetirlo en emuladores de Android 8 (API 26) y 12L (API 32): el mecanismo B no está verificado. Si no oculta la miniatura, se aplica la regla de desempate (la miniatura visible en 8–12 en la beta) y se anota en las notas de la beta.
- [ ] Los límites aceptados siguen anotados en las notas de la beta: "Recientes" abierto desde la propia app y gesto de cambio entre apps (ventana en vivo), hoja parcial del selector de fotos y fotograma blanco al volver (CL-011-14, CL-011-6, CL-011-15, CA-011-03).

## Si toca CI, workflows o la web (T-9, T-11)

- [ ] `permissions:` mínimos; acciones fijadas por SHA; sin `pull_request_target` con código de la PR.
- [ ] Secretos solo en *environments* protegidos; nunca en jobs de PR.
- [ ] Cabeceras de `vercel.json` intactas o reforzadas; sin scripts de terceros.

## Skills, plugins y MCP (P11)

- [ ] Nada instalado a nivel global ni con confirmación automática.
- [ ] Toda skill o plugin de terceros nuevo: contenido revisado y explicado en la PR, registrado en `skills-lock.json`.
