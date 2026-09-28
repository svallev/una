# Modelo de amenazas

- **Alcance:** app móvil iOS/Android v1 sin backend, más la web de pruebas en Vercel y la cadena de desarrollo (repo, CI, dependencias y firma).
- **Referencias:** OWASP MASVS v2 (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY) y MASTG para las pruebas.
- **Método:** STRIDE simplificado por superficie. Revisión en cada spec que toque una superficie y antes de cada versión.
- **Fecha:** 2026-09-27 · Versión 1.1 (ADR-0012: sin histórico). Versión 1.0: 2026-09-24

## 1. Activos

| ID | Activo | Sensibilidad | Dónde vive |
|---|---|---|---|
| A-1 | Tareas pendientes (texto; completar y eliminar las borran, ADR-0012) | Media: puede contener datos personales | SQLite en el sandbox |
| A-2 | Adjuntos: fotos, PDF, documentos, capturas web | **Alta**: DNI, entradas, recetas, documentos privados | `attachments/` en el sandbox |
| A-3 | Metadatos de las fotos (EXIF/GPS) | **Alta**: ubicación del usuario | Se eliminan al importar (no deben persistir) |
| A-4 | URL visitadas | Media | BD + WebView (sesión no persistente) |
| A-5 | Ajustes | Baja | BD |
| A-6 | Claves de firma (iOS distribution, Android upload key) | **Crítica**: suplantación de la app | Fuera del repo (ver §6) |
| A-7 | Integridad del código y del pipeline | **Crítica** | GitHub, CI, dependencias |
| A-8 | Reputación "Data Not Collected" | Alta | Declaraciones en las tiendas |

## 2. Actores

| Actor | Capacidad | Motivación |
|---|---|---|
| Web maliciosa o comprometida cargada como tarea URL | Ejecutar JS en la WebView, redirigir, phishing | Robar datos, escapar de la WebView |
| Archivo malicioso importado (PDF, imagen, docx) | Explotar parsers, contenido activo | Ejecutar código, fugas |
| Otra app del dispositivo | Intents, esquemas de URL, portapapeles, almacenamiento compartido | Leer datos de la app |
| Persona con acceso físico breve al teléfono **desbloqueado** | Ver la app abierta | Curiosidad o intrusión |
| Ladrón con el dispositivo **bloqueado** | Extracción física | Datos |
| Atacante de la cadena de suministro | Paquete pub/npm/acción de GitHub comprometidos | Insertar código |
| Contribuidor o *fork* malicioso (repo público) | PR con cambios en workflows | Robar secretos de CI |
| Visitante de la web de pruebas | Navegador | XSS, *clickjacking* |

## 3. Superficies de ataque y amenazas

| ID | Superficie | Amenaza (STRIDE) | Mitigación | MASVS |
|---|---|---|---|---|
| T-1 | Almacenamiento en reposo | Divulgación por extracción del dispositivo | Sandbox; Data Protection `CompleteUntilFirstUserAuthentication`; almacenamiento interno en Android; nada en almacenamiento externo (ADR-0005) | STORAGE-1 |
| T-2 | Fugas laterales | Divulgación por logs, portapapeles, instantánea del selector de apps, notificaciones | Sin logs de contenido en *release*; nunca se copia al portapapeles sin acción del usuario; notificaciones futuras sin contenido por defecto; **[Pendiente]** decidir si se oculta la instantánea del selector (choca con P2; se decide en la spec 010 como ajuste futuro) | STORAGE-2, PRIVACY |
| T-3 | Importación de archivos | Manipulación o ejecución por archivos malformados | Tipo por **bytes mágicos** + extensión coherente; límites de tamaño y píxeles; **recodificar las imágenes** (elimina EXIF/GPS/XMP y payloads); SVG, HTML, XML y ejecutables rechazados; PDF con pdfrx sin JS ni formularios; documentos solo con el visor del sistema (**en la v1 solo se admite PDF**, ADR-0014: sin visor del sistema ni otros formatos; como en las imágenes, el tipo solo por el contenido y la extensión no cuenta; enlaces del PDF según T-5); nombres de archivo saneados (sin rutas, sin `..`, longitud máxima); todo en un *isolate* con *timeouts*. **Imágenes (spec 007):** el tipo solo por el contenido (la extensión y el tipo declarado no cuentan); tamaño contado al copiar (30 MB) y dimensiones leídas de la cabecera antes de decodificar (64 MP); limpieza en un hilo nativo con 20 s como máximo | PLATFORM-2, CODE-4 |
| T-4 | WebView de tareas URL | Ejecución o escalada: puente JS, `file://`, cookies persistentes | `javaScriptBridgeEnabled:false`; sin acceso a archivos ni contenido; almacén no persistente; sin permisos; sin descargas; `isInspectable` solo en debug; **certificado inválido siempre cancelado**; ~~HTTP ≥ 400 = captura fallida (I-5)~~; **sin copia local (ADR-0016): no se guarda nada de la página; cookies, almacenamiento web y caché se borran al salir de la tarea y en el arranque siguiente, y quedan fuera de la copia de seguridad**; sin diálogos JS, autorrellenado ni pantalla completa (spec 009); `webview_flutter` oficial en lugar de un plugin sin mantenimiento (ADR-0007). Verificado en S4 | PLATFORM-2 |
| T-5 | URL introducida | Suplantación: esquemas peligrosos, homógrafos IDN, credenciales en la URL | Solo `http(s)`; bloqueo de `javascript:`, `data:`, `file:`, `content:`, `intent:`…; se rechaza `user:pass@`; se muestra el dominio real (punycode si mezcla alfabetos); navegación fuera del dominio → navegador del sistema tras avisar. **Enlaces del PDF (spec 008):** `http(s)` al navegador y `mailto:`/`tel:` a su app, siempre tras confirmar con el destino saneado; del `mailto:` solo destinatarios y asunto; `tel:` solo marca, no llama; el resto de esquemas no hace nada | NETWORK-1, PLATFORM-2 |
| T-6 | Red | Manipulación (MITM) | ATS y `cleartextTrafficPermitted=false`; sin excepciones; sin *pinning* (no hay backend propio) | NETWORK-1 |
| T-7 | Copias de seguridad | Divulgación vía iCloud/Google | Incluidas por decisión (ADR-0004); explicado en "Acerca de"; los temporales y cachés se excluyen. **Residual (specs 003 y 004, ADR-0012):** una copia anterior a completar o eliminar una tarea la conserva y, al restaurarla, vuelve como pendiente; una copia v1 con completadas o marcas se limpia al abrirla (migración a v2). **Residual (ADR-0012):** el borrado es lógico fuera del archivo de la BD: `secure_delete` sobrescribe sus páginas libres, pero no el diario ya desvinculado ni los bloques de la memoria flash (recuperable solo con extracción física en Android 8–9 sin cifrado por archivo). Las imágenes de una tarea completada o eliminada viven hasta el barrido si la app muere antes de borrarlas, o tras la migración a v2; no entran en la copia en la nube, pero sí en la transferencia entre móviles (y el barrido del móvil nuevo las borra). **Residual (spec 007):** si el proceso muere a mitad de una importación, el original (con sus metadatos) queda en `cache/import/` hasta el barrido del siguiente arranque; la caché nunca entra en las copias | STORAGE-2 |
| T-8 | Componentes exportados (Android) / esquemas de URL | Suplantación por intents de otras apps | Solo la `MainActivity` exportada; FileProvider no exportado con `grantUriPermissions` puntual y solo de lectura, salvo la salida de la cámara (spec 007): escritura sobre **un único archivo** de `cache/import/`, que se revoca al volver; las URIs elegidas se rechazan si su proveedor es de la propia app o su autoridad lleva usuario (`0@…`); sin *deep links* en la v1 | PLATFORM-1 |
| T-9 | Web de pruebas (Vercel) | XSS o *clickjacking* | CSP estricta, `frame-ancestors 'none'`, HSTS, nosniff, `Referrer-Policy: no-referrer`, `Permissions-Policy`; sin scripts de terceros; previews protegidas; `noindex` (ADR-0010) | — |
| T-10 | Dependencias | Manipulación en la cadena de suministro | `pubspec.lock` versionado; versiones fijadas; Dependabot; OSV-Scanner en CI; dependency-review en las PR; acciones fijadas por SHA; criterios de aceptación de dependencias (§5) | CODE-3 |
| T-11 | CI y repositorio público | Robo de secretos o manipulación del pipeline | `permissions:` mínimos por workflow; sin `pull_request_target` con checkout del código de la PR; sin secretos de firma en CI de PR; aprobación obligatoria de workflows de contribuidores externos; reglas de rama en `main`; secret scanning + push protection | — |
| T-12 | Claves de firma | Suplantación de la app | Fuera del repo; `.gitignore` + hooks de Claude Code; Play App Signing (Google guarda la clave de firma, en el repo solo se usa la de subida); certificados de Apple en el llavero local; copia cifrada fuera de línea (gestor de contraseñas) | — |
| T-13 | Código de terceros en el cliente | Divulgación: SDK con telemetría | Prohibidos la analítica y el crash reporting; revisión de `AndroidManifest` combinado y de `PrivacyInfo.xcprivacy` de las dependencias; test de CI que falla si aparecen permisos no esperados | PRIVACY-1 |
| T-14 | Importadores futuros (Todoist, Keep…) | Denegación de servicio o manipulación con archivos malformados | Parsers en *isolate* con límites (tamaño, profundidad y número de elementos), sin `eval`, *fuzzing* con casos malformados antes de activar el flag `imports` | CODE-4 |
| T-15 | Acceso físico con el teléfono desbloqueado | Divulgación | Aceptado en la v1 (sin biometría, D11); se reevalúa con el flag `biometricLock` | AUTH (N/A v1) |

## 4. Privacidad: objetivo "Data Not Collected"

- **Ni analítica, ni crash reporting, ni publicidad, ni identificadores de dispositivo.** Ninguna llamada de red salvo la WebView de URL que el usuario pide.
- **[Hecho]** WebView (spec 009): `android.webkit.WebView.MetricsOptOut` = `true` en el manifiesto (sin métricas ni diagnósticos de la WebView a Google). **Safe Browsing activado** (decisión del propietario, 2026-09-28): la WebView del sistema consulta la reputación de las direcciones con prefijos de hash. **[Suposición, PD-9]** No cambia la ficha Data Safety; se revisa antes de publicar.
- **iOS:** `PrivacyInfo.xcprivacy` sin tipos de datos recogidos, con las *required reason APIs* declaradas (p. ej. `UserDefaults` CA92.1, *file timestamp* C617.1) y revisión de los manifiestos de los plugins. App Store: "Data Not Collected".
- **Android:** formulario de Data Safety "No data collected / No data shared"; permisos únicamente `INTERNET` (WebView) y `CAMERA` (solo si se usa el permiso en vez del intent del sistema); se eliminan los permisos añadidos por los plugins (`tools:node="remove"`) y CI verifica el manifiesto combinado.
- Política de privacidad breve (Bloque 5; se necesita antes de publicar) que refleje exactamente esto.

## 5. Criterios para aceptar una dependencia

Mantenida (release en los últimos 12 meses o estable y sin issues de seguridad abiertas), licencia compatible (MIT/BSD/Apache/OFL/zlib; nada de GPL en la app), **sin telemetría**, con publicador verificado en pub.dev si es posible, tamaño justificado, sin alternativa razonable en el SDK. Se registra en la PR con la sección "Nueva dependencia" de la plantilla.

- **[Hecho]** CI comprueba la licencia de todos los paquetes de pub.dev de `pubspec.lock` con `app/tool/check_licenses.dart` (lee el `LICENSE` de cada paquete; falla ante GPL/LGPL/AGPL/SSPL o una licencia no reconocida). La revisión de dependencias de GitHub no reconoce las licencias que publica pub.dev.
- **[Hecho]** `sqlite3` (vía drift) **descarga al compilar** un binario precompilado de SQLite desde las *releases* de GitHub de su autor (`simolus3/sqlite3.dart`) y lo verifica con un sha256 fijado dentro del paquete; el paquete, a su vez, está fijado por sha256 en `pubspec.lock`. Cadena de confianza aceptada. Alternativa si hiciera falta: compilar SQLite desde el código fuente con `hooks: user_defines: sqlite3: source: source`.
- **[Hecho]** `pdfium_dart` (vía `pdfrx`, spec 008) **descarga al compilar** PDFium desde las *releases* de GitHub de `bblanchon/pdfium-binaries` (`chromium/7811`, compilación **sin V8**: sin motor de JavaScript) **sin verificarlo**. Mitigación propia: `tools/pdfium.lock` fija el sha256 del `libpdfium.so` de cada ABI (comprobado contra el *digest* que publica GitHub y extrayéndolo a mano) y CI falla si el de algún APK de release no coincide (`tools/check-pdfium.sh`). Al actualizar pdfrx, se repite la comprobación en la PR. `pdfrx` trae de forma transitiva `url_launcher` (solo lo usa su pantalla de error, que la app sustituye; añade una actividad **no exportada** y ningún permiso). En web, PDFium va como WASM dentro de los assets del paquete (sin CDN).
- **[Hecho]** El SDK de Flutter se instala en CI por etiqueta y se verifica contra el commit de `tools/flutter-sdk.lock`.
- **[Hecho]** CI exige que el manifiesto de **release** solo pida `INTERNET` (`tools/check-android-permissions.sh release`), desde la spec 009 (WebView de la tarea web); cualquier otro permiso falla.
- **[Hecho]** `webview_flutter` 4.14.1 + `webview_flutter_android` 4.14.1 (spec 009, ADR-0007), fijadas; transitivas `webview_flutter_platform_interface` 2.15.1 y `webview_flutter_wkwebview` 3.26.1 (esta no se usa hasta F-iOS). Todas BSD-3, del equipo de Flutter (`flutter.dev`, publicador verificado), sin telemetría. Usan la WebView del sistema (no añaden motor): el APK arm64 pasa de 28.238.092 a 28.304.161 bytes (+66 KB; 13,23 → 13,28 MB comprimido). No hay WebView en el SDK de Flutter y `flutter_inappwebview` está sin mantenimiento. El paquete no gestiona el fallo del proceso de la página: se envuelve su `WebViewClient` desde Kotlin (ADR-0017), lo que depende de detalles internos suyos → **al actualizarlo se repiten las comprobaciones del plan de la 009 §4** (riesgo R-21). La web de pruebas no incluye la WebView.

## 6. Gestión de las claves de firma

- Android: **Play App Signing** activado desde la primera subida; la *upload key* en un `.jks` fuera del repo (`~/.config/<app>/upload.jks`) con `key.properties` en `.gitignore`; copia cifrada en el gestor de contraseñas.
- iOS: firma automática de Xcode con la cuenta de Apple Developer; los certificados, en el llavero de macOS. Ningún `.p12`, `.p8`, `.mobileprovision` ni `.cer` en el repo.
- CI de publicación (futuro): secretos en *environments* protegidos de GitHub con aprobación manual; nunca disponibles en workflows de PR.

## 7. Riesgos residuales aceptados

- Acceso físico con el teléfono desbloqueado (T-15).
- JS de terceros ejecutándose en la WebView en vivo (mitigado por el aislamiento; es inherente a mostrar webs).
- En Android, los documentos no PDF se abren con apps de terceros elegidas por el usuario (reciben el archivo en solo lectura).

## 8. Verificación

Checklist por PR (`checklist.md`), revisión del subagente `security-reviewer` en las PR que tocan superficies T-3 a T-6 y T-10 a T-13, pruebas MASTG seleccionadas antes de la v1.0 (almacenamiento, WebView, intents, manifiesto de red) y un test automático de permisos y manifiestos.
