# Plan técnico — Spec 009: Tareas con una página web (URL)

- **Spec:** `specs/009-adjunto-url/spec.md` (estado: Aprobada, 2026-09-28)
- **ADR aplicables:** ADR-0016 (sin copia local; excepción a P3), **ADR-0018 (sin navegación: solo la dirección guardada; sin PSL)**, ADR-0007 (validación y WebView endurecida; enmendado por el 0016 y el 0018), ADR-0017 (envoltorio del `WebViewClient` para el fallo del proceso de la página), ADR-0002 (repositorio y esquema), ADR-0004 (copias), ADR-0010 (web de pruebas), ADR-0012 (completar borra), ADR-0013/0014/0015 (horizontal), resultados del spike S4 (`docs/spikes/F1-S3-S4-S5-resultados.md`)
- **Estado del plan:** Aprobado (propietario, 2026-09-28). Actualizado el 2026-09-29 con el ADR-0018 (sin navegación)
- **Rama:** `feat/009-adjunto-url`, desde `main` (la 008 ya está fusionada)

## 1. Resumen del enfoque

- **La tarea web es un adjunto sin archivos.** Se reutiliza el modelo de la 007/008 (`Attachment`, `CreateTask`, `EditTask`, `taskLabel`, insignia, giro, pantalla encendida) con `AttachmentKind.web`, `AttachmentOrigin.url` y la dirección en `Attachment.url`. No hay preparación, versión de pantalla ni archivos que comprobar, respaldar o borrar: `commit` no mueve nada, `check` da siempre `ok` y `delete` no encuentra nada. Así "Adjunto no disponible" no aplica, y completar o eliminar ya borran la tarea del todo (ADR-0012).
- **Sin cambio de esquema.** La v2 ya tiene `kind = web`, `origin = url` y `sourceUrl` (previstos en el ADR-0002). `relPath` es obligatorio: para la web se guarda vacío. `mime` = `text/html`, `byteSize` = 0, sin medidas. `sourceHost`, `snapshotRelPath` y `snapshotAt` se quedan nulos: el dominio se calcula de la dirección y no hay captura (ADR-0016).
- **Una dependencia nueva: `webview_flutter`** (oficial; con `webview_flutter_android`), la que eligió el ADR-0007 tras el spike S4 (4.14.1 entonces; se fija la última 4.x estable al empezar). Ver §4.
- **Endurecimiento en dos niveles** (T-4):
  - desde Dart (API del paquete):
    - JavaScript activado, **sin ningún canal JS**;
    - `NavigationDelegate` con la política de navegación (`onNavigationRequest`: solo la carga inicial y las anclas de la misma página, ADR-0018), `onWebResourceError` (solo el marco principal) y el rechazo de los errores de certificado;
    - permisos de la página denegados (`setOnPlatformPermissionRequest`, geolocalización);
    - diálogos JS descartados (`setOnJavaScriptAlertDialog`/`Confirm`/`TextInput` sin mostrar nada);
    - sin selector de archivos (`setOnShowFileSelector` devuelve vacío);
    - sin pantalla completa (`setCustomWidgetCallbacks` no la muestra);
  - desde **Kotlin**, con la instancia nativa que da `WebViewFlutterAndroidExternalApi.getWebView` (canal nuevo `una/webview`):
    - `allowFileAccess`/`allowContentAccess` a `false`, `saveFormData` a `false`;
    - `mixedContentMode = NEVER_ALLOW`, Safe Browsing activado y `supportMultipleWindows` a `false`;
    - un **`DownloadListener`** que no descarga y avisa a Dart (→ "no es una página", CL-009-4; sin él, un PDF dejaba la página en blanco);
    - `setWebContentsDebuggingEnabled(false)` en *release*;
    - un **envoltorio del `WebViewClient` del paquete** que le reenvía todos los callbacks y solo añade `onRenderProcessGone` (devuelve `true` y avisa a Dart para recrear la WebView), aplicado después de `setNavigationDelegate` y comprobado (ADR-0017).
- **Nada de la página se queda en el móvil** (CA-009-13, ADR-0016):
  - **al salir de la tarea** (otra pantalla, otra tarea, completar, eliminar): se borran las cookies (`WebViewCookieManager.clearCookies`), el almacenamiento web (`clearLocalStorage`, que en Android es `WebStorage.deleteAllData`: localStorage, IndexedDB y el resto) y la caché (`clearCache`);
  - **al usar la web por primera vez** se escribe una marca (`files/web_used`). Si la app se cerró sin borrar, **después del primer fotograma** del arranque siguiente se borra lo mismo desde Kotlin: `CookieManager.removeAllCookies`, `WebStorage.deleteAllData` y la caché de la WebView. Solo se hace si existe la marca, así que no cuesta nada a quien no usa la web;
  - los directorios de la WebView (`app_webview/`, `cache/`) ya quedan **fuera** de la copia en la nube y de la transferencia: las reglas solo incluyen `app_flutter/`, `shared_prefs/` y `files/`. Se añade un test que lo fija, y la marca va en `files/`, sin contenido.
- **Sin navegación (CA-009-11, ADR-0018).** `decideWebNavigation` recibe la página que se ve (la del primer `onPageStarted`; null durante la carga inicial):
  - durante la **carga inicial** se siguen las redirecciones del servidor (`http://` como `https://`), también a otro dominio (CL-009-1);
  - después, en el marco principal solo se admite un **ancla de la misma página** (misma dirección sin contar `#…`); cualquier otra petición (enlace, formulario, `target=_blank` con `supportMultipleWindows = false`, redirección de la página, `mailto:`, `tel:`, otros esquemas) devuelve `prevent` y no hace nada, **sin confirmaciones**;
  - los marcos internos se cargan si son web (son parte de la página);
  - **sin *Public Suffix List***: se quitó con T-009-03 revertida. El aviso de redirección compara el dominio como se ve en la barra (sin `www.`).
- **Estado de la página** (`WebPageController`, capa de estado), sobre una interfaz `WebPageDriver` que en los tests se sustituye por un falso, como el visor del PDF:
  - estados: `loading`, `shown`, `offline`, `insecure`, `certificate`, `notAPage`;
  - **se carga cada vez** que la tarea aparece (CA-009-07). Segundo plano de menos de 10 minutos: se conserva (CA-001-12). Si el sistema mató el proceso de la página, se recarga;
  - `http://` → se carga como `https://` (CA-009-09). Si falla con un error de conexión o de TLS, `insecure`; con cualquier otro error de red del marco principal, `offline`. Un error de certificado siempre es `certificate` y la carga se cancela;
  - **20 s** sin `onPageStarted` → `offline` (CA-009-08, CL-009-7);
  - "Reintentar", y la vuelta a la app o a la tarea en un estado de error, recargan la dirección guardada;
  - las redirecciones de la **carga inicial** se siguen (CL-009-1). Al primer `onPageStarted`, esa dirección pasa a ser **la página que se ve** (la única, ADR-0018), y si su dominio difiere del de la dirección guardada se muestra una vez `urlRedirected`.
- **Atrás (CA-009-12):** sin nada propio: como no hay navegación, no hay historial; atrás es el de cualquier tarea (ADR-0018).
- **Presentación:**
  - la **barra** reutiliza la franja del PDF (negra, mono 11, candado + dominio + "WEB"), y el dominio se recorta por el principio con un `TextPainter` propio: "…" + el final que quepa (CA-009-14);
  - debajo, la WebView (composición híbrida de Android);
  - los avisos de error y el indicador de carga ocupan la zona de la página;
  - en horizontal, la WebView a sangre con el logotipo, **sin recrearla** (clave estable, como el visor del PDF, CA-009-15).
- **Accesibilidad:** la barra es el nodo de la tarea ("Tarea actual: Página web de {host}") con las acciones Completar y Eliminar. En horizontal no hay barra: el nodo pasa al logotipo, con la misma lectura y las mismas acciones. La WebView no admite acciones propias de Flutter, y en la 008 TalkBack no enfocaba un contenedor sin etiqueta. Se comprueba con TalkBack en el emulador.
- **Cara de completar y eliminar (CA-009-17):** la barra y la zona de la página **en blanco**. Una vista nativa no se puede capturar de forma fiable con `toImageSync`.
- **Web de pruebas (CL-009-5):** sin WebView. Tarjeta del prototipo con el dominio, la dirección y "Abrir página ↗", que abre la dirección en una pestaña nueva con `window.open(url, '_blank', 'noopener,noreferrer')` (`package:web`, ya presente). `webview_flutter` se importa solo en la variante nativa (importación condicional, como `repository_factory`). La CSP no cambia: no hay `connect-src` ni `frame-src` nuevos.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `entities/attachment.dart`, `entities/staged_attachment.dart` (`StagedWeb`), `ports/attachment_store.dart` (`attachmentFrom`), `services/web_address.dart` (nuevo), `services/host_display.dart` (nuevo, sale de `link_policy.dart`), `services/web_navigation.dart` (nuevo), `entities/web_load_failure.dart` (nuevo) | Tipo `web`, origen `url` y `url`; validación y normalización de la dirección (CA-009-02, CL-009-8, IP privadas y locales); dominio visible (`www.`, saneado, punycode si mezcla alfabetos), compartido con los enlaces del PDF; política de navegación (carga inicial con redirecciones, anclas de la misma página; el resto no hace nada, ADR-0018); tipos de fallo |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart`, `attachments/file_attachment_store.dart`, `attachments/memory_attachment_store.dart`, `web/web_data_janitor.dart` (nuevo) | Leer y escribir `kind = web` / `origin = url` / `sourceUrl`; `commit`/`check`/`delete` sin archivos para la web; borrar los datos de la WebView (canal `una/webview`) al salir y en el arranque con la marca |
| Estado | `features/web/web_page_controller.dart` (nuevo), `features/web/web_page_driver.dart` (interfaz + implementación con `webview_flutter`), `providers.dart` | Estados de la página, 20 s, reintento, http → https, redirección inicial, página que se ve (sin navegación), limpieza al salir, cancelar al completar o eliminar (CL-009-11) |
| Presentación | `features/web/url_sheet.dart` (nuevo), `features/web/task_web.dart` (nuevo), `features/web/web_bar.dart` (nuevo), `features/web/web_task_card_web.dart` (web de pruebas), `attach_sheet.dart`, `task_editor_screen.dart`, `current_task_screen.dart`, `task_list_screen.dart` y el menú (Editar), `task_labels.dart`, `task_thumbnail.dart`, controladores de completar y eliminar | Hoja "Cargar URL", fila activa solo en tareas nuevas, crear directamente; Editar abre la hoja; tarea web con barra, página, carga y avisos; giro, pantalla encendida; insignia "WEB" y dominio como etiqueta; cara con la barra |
| Nativo | `WebViewHardening.kt` (nuevo, canal `una/webview`), `MainActivity.kt`, `AndroidManifest.xml` (`INTERNET`), `tools/check-android-permissions.sh` | Ajustes nativos, `DownloadListener`, depuración solo en *debug*, borrado de datos; **primer permiso de la app en *release*: `INTERNET`** (P4 lo admite: "la carga de una URL que el usuario ha pedido ver") |
| l10n | `app_es.arb`, `app_en.arb` | Las claves de la §7 de la spec |
| Tokens | `design/tokens.json` → `tokens.g.dart` | Indicador de carga (alto, duración) y, si hace falta, la separación de la barra; la barra reutiliza los de la franja del PDF |

## 3. Modelo de datos y migraciones

**Sin cambios de esquema** (sigue la v2). La tabla `attachments` ya tiene lo necesario (`kind`, `origin`, `sourceUrl`). Fila de una tarea web:

| Columna | Valor |
|---|---|
| `kind` / `origin` | `web` / `url` |
| `sourceUrl` | la dirección validada (CA-009-04) |
| `mime` | `text/html` |
| `byteSize` | 0 |
| `relPath` | `''` |
| resto | nulo |

La dirección viaja en la copia de seguridad con la tarea (va en la BD, como el texto). Nada más de la página.

## 4. Dependencias nuevas

- **`webview_flutter`** (4.x) + **`webview_flutter_android`** (dependencia directa: hace falta para los ajustes de Android y para `WebViewFlutterAndroidExternalApi`). Licencia BSD-3, del equipo de Flutter (`flutter.dev`, publicador verificado), en mantenimiento activo. Ya se probó en S4. Usa la WebView del sistema (Chromium, que se actualiza con Play): no añade motor al APK. Motivo: no hay WebView en el SDK de Flutter, y el ADR-0007 la eligió frente a `flutter_inappwebview`, sin mantenimiento. Solo se registra la implementación de Android: `webview_flutter_wkwebview` llega como transitiva, pero no se usa hasta F-iOS.
  - **Comprobaciones [Hecho, T-009-01, 2026-09-28]**, en el emulador (Pixel_6a, API 37, WebView 149) con 4.14.1 y servidores locales:
    1. **OK.** Un certificado inválido llega a `onSslAuthError`, se cancela y no llega ninguna petición al servidor. Ojo: después llega `onPageFinished` **sin** `onPageStarted`.
    2. **OK.** Diálogos JS, selector de archivos, permisos (cámara, geolocalización) y pantalla completa se descartan desde Dart. Si no se pasa el callback de pantalla completa, el paquete pone el suyo: hay que pasarlo siempre.
    3. **OK.** `getWebView` da la instancia desde Kotlin; los ajustes se leen de vuelta; un `DownloadListener` propio recibe `application/pdf`. Safe Browsing viene activado de serie.
    4. **Falla con el paquete solo**: `chrome://crash` cierra la app (su cliente no implementa `onRenderProcessGone`). **Resuelto con el envoltorio del ADR-0017** (decisión del propietario, opción (a)): con él, la app sigue viva, la WebView se recrea (probado dos veces seguidas) y el `NavigationDelegate` de la nueva recibe `onNavigationRequest`, `onPageStarted`, `onPageFinished`, `onWebResourceError` y `onSslAuthError`. Un `setNavigationDelegate` posterior quita el envoltorio.
    5. **`onPageStarted` sí llega** sin red (DNS), seguido del `onWebResourceError` del marco principal. Por eso **se clasifica por el error**, no por el temporizador. El de 20 s sigue haciendo falta: con una conexión colgada no llegó nada en 30 s.
  - **[Hecho]** Licencias (`check_licenses.dart`), `check-android-permissions.sh release` (solo `INTERNET`), `flutter build web` sin la WebView y APK arm64 de 28.238.092 a 28.304.161 bytes (+66 KB).
  - Licencias en `check_licenses.dart`; tamaño del APK con `--analyze-size` (se espera poco: solo código Java/Kotlin del paquete); `threat-model.md §5`.
- ~~**La PSL** es un dato (MPL-2.0)…~~ **Quitada (ADR-0018, 2026-09-29):** sin navegación no hace falta decidir el "mismo sitio".
- **Sin más dependencias:** para detectar la red no se usa `connectivity_plus` (propietario: "Reintentar"); para abrir en el navegador, `LinkOpener` de la 008 (`ACTION_VIEW` + `BROWSABLE`, ya con `<queries>`), no `url_launcher`.

## 5. Estrategia de tests

La WebView no funciona en `flutter test`. Los tests de widget usan un `WebPageDriver` falso, que emite los eventos del paquete: inicio, fin, errores por tipo, peticiones de navegación, descarga. La WebView real se prueba en el emulador **sin red externa**: servidores locales en el propio dispositivo (`127.0.0.1`) y modo avión. La dirección local se inserta directamente en el repositorio, porque la hoja la rechazaría con razón (CA-009-02).

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-009-01 | Widget (fila activa solo en tareas nuevas, sin "Cargar URL" en modo editar; hoja, teclado de URL y sin autocorrección) | `test/features/web/url_sheet_test.dart`, `test/features/attachments/attach_sheet_test.dart` (ampliado) |
| CA-009-02; CL-009-8 | Unitarios exhaustivos (vacío, esquemas, IDN, IP privadas v4/v6, `user:pass@`, 2048, espacios) + widget del error como alerta | `test/domain/web_address_test.dart`, `url_sheet_test.dart` |
| CA-009-03, 04, 05 | Casos de uso y widget (arriba, sin texto, descarta texto y adjunto preparado sin archivos, doble toque, editar conserva posición y color, misma dirección sin cambios) + contrato de repositorios | `test/domain/create_task_web_test.dart`, `test/features/editor/editor_url_test.dart`, `test/data/task_repository_contract_test.dart` (ampliado) |
| CA-009-06, 07, 08 | Widget con el falso (barra, carga, se carga cada vez, 10 minutos, menú no recarga, 20 s, "Reintentar", reintento al volver) + integración en modo avión | `test/features/web/task_web_test.dart`, `integration_test/web_flow_test.dart` |
| CA-009-09, 10; CL-009-4 | Unitario de la clasificación de fallos + integración con servidores locales (`http://127.0.0.1`: bloqueado en claro; `https` autofirmado: certificado; respuesta `application/pdf`: no es una página) | `test/features/web/web_page_controller_test.dart`, `integration_test/web_flow_test.dart` |
| CA-009-11; CL-009-1, 12, 13 | Unitarios de `web_navigation` (anclas de la misma página; otra página del mismo sitio, otro sitio, `mailto:`, `tel:`, esquemas y `usuario@` no hacen nada; marcos internos; carga inicial con redirecciones; aviso por dominio) + widget (un enlace no carga nada ni abre confirmaciones) + integración con un servidor local (tocar un enlace no cambia la página) | `test/domain/web_navigation_test.dart`, `task_web_test.dart`, `integration_test/web_flow_test.dart` |
| CA-009-12 | Widget (atrás hace lo de cualquier tarea) | `task_web_test.dart` |
| CA-009-13 | Widget (limpieza al salir por cada camino) + unitario del janitor (marca) + reglas de copia + integración (tras salir, `document.cookie` y `localStorage` vacíos al volver) + revisión de los ajustes nativos | `test/features/web/web_isolation_test.dart`, `test/app/backup_rules_test.dart`, `integration_test/web_flow_test.dart` |
| CA-009-14 | Unitario (`www.`, bidi, punycode) + widget (recorte por el principio al 200 %, lectura entera) | `test/domain/host_display_test.dart`, `test/features/web/web_bar_test.dart` |
| CA-009-15 | Widget (horizontal: página y logotipo; no gira con avisos; no se recrea) + prueba a mano en el emulador con el sensor simulado | `test/features/current_task/landscape_test.dart` (ampliado) |
| CA-009-16 | Widget | `test/features/attachments/keep_screen_on_test.dart` (ampliado) |
| CA-009-17; CL-009-11 | Widget (insignia, dominio como etiqueta en el listado, eliminar y anuncios; cara con la barra; carga cancelada) | `test/features/web/web_elsewhere_test.dart` |
| CA-009-18, 19, 20 | Widget con `SemanticsTester`, `meetsGuideline`, texto al 200 % en 360 dp (`loadAppFonts`) + TalkBack en el emulador | `test/features/web/web_a11y_test.dart` |
| CL-009-5 | Build web y prueba a mano | — |
| CL-009-9 | Revisión del código + `security-reviewer` | — |
| Aspecto | *Goldens* (hoja con error, tarea web cargando, sin conexión, sin https, fila con insignia "WEB") | `test/goldens/web_golden_test.dart` |

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (T-4, T-5, T-6):**
  - la página nunca tiene puente con la app: sin canales JS ni `addJavascriptInterface`, que se revisa con un test que busca `addJavaScriptChannel` en `lib/`;
  - sin acceso a archivos ni contenido; sin permisos, descargas, diálogos, autorrellenado ni pantalla completa;
  - solo https: `cleartextTrafficPermitted=false`, ya fijado, y contenido mixto `NEVER_ALLOW`; certificados inválidos siempre cancelados;
  - **sin navegación** (ADR-0018): `web_navigation` solo deja la carga inicial y las anclas de la misma página; nada sale al navegador ni a otra app desde la página;
  - el dominio, saneado y en punycode si mezcla alfabetos;
  - nada de la página se guarda; ningún registro con direcciones (CL-009-9);
  - `INTERNET` es el único permiso nuevo: `check-android-permissions.sh` lo pasa a permitido en *release*, y cualquier otro sigue fallando;
  - se pasan `security-reviewer` y `/security-check`.
- **Privacidad (P4):** la única red es la página que el usuario pidió ver ("Data Not Collected" no cambia).
  - **Safe Browsing activado** (propietario, 2026-09-28): la WebView del sistema consulta a Google la reputación de las direcciones (con prefijos de hash). **[Suposición, PD-9]** No cambia la ficha de Data Safety; se revisa antes de publicar (checklist de publicación).
  - **`android.webkit.WebView.MetricsOptOut` = `true`** en el manifiesto: la WebView no envía métricas ni diagnósticos (T-009-01).
- **Accesibilidad:**
  - la barra y el logotipo en horizontal llevan la tarea y sus acciones;
  - la página, con la accesibilidad de la WebView;
  - el horizontal usa la excepción ya aprobada (constitución P6), ampliada a la web;
  - se pasan `a11y-reviewer` y TalkBack en el emulador (memoria: verificar TalkBack en el emulador, no solo con tests de eventos de foco).
- **Rendimiento:**
  - el primer fotograma no espera a la WebView: la barra se pinta con Flutter y la WebView se crea después del primer fotograma;
  - se mide el arranque en frío con una tarea web actual en el Xiaomi (CA-001-09 con la barra; objetivo p50 < 1 s), con tu permiso y `--keep-app-running`;
  - el borrado de datos en el arranque va después del primer fotograma y solo con la marca;
  - tamaño del APK con `--analyze-size`.

## 7. Riesgos y alternativas

| Riesgo | Mitigación / alternativa |
|---|---|
| `webview_flutter` no deja cancelar un certificado inválido de forma distinguible, o un fallo del proceso de la página cierra la app | **[Hecho, T-009-01]** El certificado se cancela y se distingue. El fallo del proceso **sí cerraba la app**: se resuelve envolviendo el `WebViewClient` del paquete desde Kotlin (ADR-0017, opción (a) del propietario). **Riesgo que queda (R-21):** depende de detalles internos del paquete; se comprueba que el envoltorio está puesto cada vez que se aplica, la app no llama a `setNavigationDelegate` después, y se revalida (`chrome://crash` y callbacks) en cada actualización. Alternativa si se rompe: WebView propia en Kotlin, sin el paquete (enmendaría el ADR-0007: se consulta) |
| Una página cambia de contenido sin cambiar de dirección (`history.pushState`, JavaScript) | No se puede impedir y no es navegar: sigue siendo la misma página y el mismo dominio (CL-009-12, ADR-0018) |
| Sin red y "el servidor no admite https" dan errores parecidos (CA-009-08 frente a CA-009-09) | Solo se clasifica como `insecure` si la dirección era `http://` y falla la conexión o el TLS del intento https; un fallo de DNS es siempre `offline`. Tests con servidores locales |
| TalkBack no enfoca el logotipo como nodo de la tarea en horizontal, o la WebView se queda el foco | Se prueba en el emulador (T-009-19). Alternativa: un nodo propio encima de la página, sin toques, con la lectura y las acciones |
| La WebView tarda en crearse (~100–300 ms) y el primer contenido depende de la red | Fuera del presupuesto de CA-001-09 (ADR-0016): la barra y el indicador están en el primer fotograma |
| Safe Browsing envía datos a Google (P4) | **[Hecho]** Se mantiene activado (propietario, 2026-09-28), con `MetricsOptOut`; la ficha Data Safety queda en PD-9. Se puede desactivar (`WebSettings.safeBrowsingEnabled`) si Play lo exigiera |
