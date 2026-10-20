# Declaración de Seguridad de los datos (Data safety) de Google Play

- **Spec:** 023, CA-023-05, 06 y 07. **Tarea:** T-023-04.
- **Estado:** **Borrador para la revisión del propietario** (2026-10-20). Fuente desde la que se rellenará Play Console en F6; hasta entonces no se sube nada (proyecto de aprendizaje, sin publicar).
- **Respuesta global:** **«La app no recoge ni comparte datos de los usuarios»** (*No data collected / No data shared*). Es la que ya decían la constitución (P4) y `threat-model.md` §4; esta revisión la **confirma** con la Ayuda vigente de Play (sin ADR nuevo, CL-023-1 no se activa), con **dos dudas de interpretación** que se dejan a la vista (§5, D-1 y D-2) para que el propietario las confirme.
- **Convención:** [Hecho] = leído en la fuente citada o comprobado en el repositorio; [Suposición] = interpretación mía; [Pendiente] = no se pudo leer o depende de F6.
- **Qué recoge la Ayuda de Play como «recoger»:** «"Collect" means transmitting data from your app off a user's device» (F1). Lo que solo se procesa en el móvil no se declara; tampoco lo que sale cifrado de extremo a extremo y solo lo leen emisor y receptor (F1).

## 1. Fuentes consultadas (todas el 2026-10-20, con `curl -sL`, solo lectura)

La Ayuda de Play no muestra la fecha de su última edición; el único registro de cambios es el de F1 (última entrada: **5 de diciembre de 2023**, sobre la insignia de UPI, sin efecto en esta declaración). Las páginas de Android Developers tampoco la muestran.

| ID | Página | Dirección |
|---|---|---|
| F1 | Provide information for Google Play's Data safety section | https://support.google.com/googleplay/android-developer/answer/10787469 |
| F2 | User Data (política de Play) | https://support.google.com/googleplay/android-developer/answer/10144311 |
| F3 | Monitor your app's technical quality with Android vitals | https://support.google.com/googleplay/android-developer/answer/9844486 |
| F4 | Declare your app's data use (Android Developers) | https://developer.android.com/privacy-and-security/declare-data-use |
| F5 | Back up user data with Auto Backup (Android Developers) | https://developer.android.com/identity/data/autobackup |
| F6 | Local network permission (Android Developers) | https://developer.android.com/privacy-and-security/local-network-permission |
| F7 | Manage WebView objects (Android Developers) | https://developer.android.com/guide/webapps/managing-webview |
| F8 | Prepare your app for review (Play Console, página «App content») | https://support.google.com/googleplay/android-developer/answer/9859455 |
| F9 | Declare permissions for your app | https://support.google.com/googleplay/android-developer/answer/9214102 |
| F10 | Advertising ID | https://support.google.com/googleplay/android-developer/answer/6048248 |
| F11 | Understanding Google Play's app account deletion requirements | https://support.google.com/googleplay/android-developer/answer/13327111 |
| F12 | Permissions and APIs that Access Sensitive Information | https://support.google.com/googleplay/android-developer/answer/16558241 |

Las páginas de `play-console.md` (público objetivo, clasificación de contenido, categoría, gráficos, cuenta personal…) llevan sus fuentes allí.

## 2. Las preguntas del formulario, en el orden de Play Console

[Hecho, F1, «Complete and submit your form»] El formulario va por estas pantallas. Con la primera respuesta en **No**, el resto no se pregunta, salvo el bloque de borrado de cuenta (1c), que F11 exige a todos.

| # | Pantalla / pregunta | Respuesta | Por qué |
|---|---|---|---|
| 0 | **Requisito previo:** enlace a la política de privacidad en la ficha (Play Console → Contenido de la app → Política de privacidad) | La dirección de `privacyPolicyUrl` (hoy un marcador; **[Pendiente, F6]** la definitiva) | F1: «Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy». |
| 1 | *Data collection and security.* «Does your app collect or share any of the required user data types?» | **No** | Ninguno de los flujos de §4 es «recoger» ni «compartir» en el sentido de F1. La app no tiene servidor, cuentas, analítica ni SDK que envíen información (`threat-model.md` §4 y T-13; lo vigilan la CI y la puerta de publicación). |
| 1a | (Solo si la 1 fuera Sí) «Is all of the user data collected by your app encrypted in transit?» | **No se pregunta** | F1: solo se pregunta si se contesta Sí a la 1. |
| 1b | (Solo si la 1 fuera Sí) «Do you provide a way for users to request that their data is deleted?» | **No se pregunta** | F1: solo se pregunta si se contesta Sí a la 1. Si alguna vez se preguntara: borrar la app o completar/eliminar una tarea borra todo (política, «Cuánto tiempo se guarda»). |
| 1c | *Data deletion* (cuenta y borrado): F11 dice que **todos** los desarrolladores deben contestar este bloque, aunque la app no recoja nada. Pregunta de fondo: si la app deja **crear una cuenta** | **No: la app no tiene cuentas** | F11: las obligaciones de borrado de cuenta (en la app y con un enlace web) solo valen para apps que dejan crear una cuenta, y «accounts that are created and operated offline are not app accounts». La app no tiene cuenta ni inicio de sesión. **[Pendiente, F6]** El texto exacto de las preguntas y su posición en el formulario no están en la Ayuda: se leen en Play Console y se anotan aquí (CL-023-3). |
| 2 | *Data types.* Marcar los tipos recogidos o compartidos | **Ninguno** (auditoría tipo por tipo en §3) | Ídem. |
| 3 | *Data usage and handling.* Por cada tipo: recogido/compartido, efímero, obligatorio u opcional, finalidades | **No aplica** | Ningún tipo marcado. |
| 4 | *Security practices.* Insignia «Committed to follow the Play Families Policy» (F1) | **No aplica** | La app no se dirige a niños (público objetivo 16 y más, `play-console.md`). |
| 5 | *Store listing preview* | Debe enseñar «No data collected» y «No data shared with third parties» | Es lo que F1 enseña para una app que no recoge ni comparte. |
| 6 | **Enviar** | — | Antes de enviar en F6: exportar el CSV del formulario (F1, «Export to a CSV file») y comprobar que no hay ningún `TRUE` en las filas `PSL_DATA_TYPES_*`. |

**CL-023-3 (el formulario cambia):** antes de rellenarlo en F6 se lee de nuevo F1 y esta tabla se pone al día; `/release-checklist` lo pide (CA-023-23).

## 3. Auditoría por tipos de datos (los 38 tipos de F1, «Data types»)

[Hecho, F1 y F4] Ninguno se transmite fuera del móvil **por la app**. Se anotan los que la app sí toca **en el móvil** (no se declaran: F1, «On-device access/processing: User data accessed by your app that is only processed locally on the user's device and not sent off device does not need to be disclosed»).

| Categoría de F1 | Tipos | ¿Sale del móvil? | Lo que la app toca en el móvil |
|---|---|---|---|
| Location | Approximate location, Precise location | No | Nada. Sin `ACCESS_*_LOCATION` ni `ACCESS_MEDIA_LOCATION`; a las fotos se les quita el EXIF/GPS al importarlas. |
| Personal info | Name, Email address, User IDs, Address, Phone number, Race and ethnicity, Political or religious beliefs, Sexual orientation, Other info | No | Nada propio. Sin cuentas. El texto de una tarea es libre y puede contener de todo: es contenido del usuario que no sale del móvil (fila «Other user-generated content»). |
| Financial info | User payment info, Purchase history, Credit score, Other financial info | No | Nada. Sin compras ni pagos. |
| Health and fitness | Health info, Fitness info | No | Nada. |
| Messages | Emails, SMS or MMS, Other in-app messages | No | Nada. |
| Photos and videos | Photos, Videos | No | **Fotos** que el usuario elige o hace con la cámara del sistema: se guarda una copia sin metadatos en el espacio privado de la app. No sale (salvo en la copia de seguridad del sistema, W-5). Sin vídeos. |
| Audio files | Voice or sound recordings, Music files, Other audio files | No | Nada. |
| Files and docs | Files and docs | No | **PDF** que el usuario elige: copia en el espacio privado (con el nombre del archivo y sus metadatos). No sale (salvo en W-5). |
| Calendar | Calendar events | No | Nada. |
| Contacts | Contacts | No | Nada. |
| App activity | App interactions, In-app search history, Installed apps, Other user-generated content, Other actions | No | **Other user-generated content:** el texto de las tareas, en la base de datos del móvil. **Installed apps:** el manifiesto declara `<queries>` solo para saber si hay navegador, correo o marcador antes de abrir un enlace (008); no se lee ni envía la lista de apps. Sin búsqueda ni analítica de uso. |
| Web browsing | Web browsing history | No | La **dirección** de la tarea web, que el usuario escribe y la app guarda en su base de datos. Cookies, almacenamiento web y caché de la página se borran al salir de la tarea. No se envía a nadie desde la app. |
| App info and performance | Crash logs, Diagnostics, Other app performance data | No | Sin registros de contenido ni de errores propios (CA-020, pasada MASTG: 0 líneas en un ciclo completo). `WebView.MetricsOptOut` = `true`. Las estadísticas de Android vitals no las envía la app (W-6). |
| Device or other IDs | Device or other IDs | No | Nada. Sin ID de publicidad (`AD_ID` no está en el manifiesto de *release*: la puerta de permisos solo admite tres), ni IMEI, ni ID de instalación. |

## 4. Tabla de flujos (CA-023-05)

Cada fila: la decisión, el porqué y la fuente (con la fecha de consulta, 2026-10-20). «No se declara» = no se marca ningún tipo de dato. Las filas con duda llevan la marca **[Duda D-n]** y se explican en §5.

| ID | Flujo | Qué sale del móvil y quién lo manda | Decisión | Por qué | Fuente |
|---|---|---|---|---|---|
| W-1 | **Tarea web:** la página que el usuario pide ver | La WebView del sistema pide la página al sitio que el usuario ha puesto (su IP y los datos técnicos habituales de un navegador, como en cualquier visita). La app no añade nada de sí misma: sin puente de JavaScript, sin cookies guardadas, sin formularios | **No se declara** **[Duda D-1]** | F1: la recogida desde una WebView solo cuenta «if your app is in control of the code/behavior delivered through that webview» y «You do not need to declare data collection from a webview in which users are navigating the open web». El contenido es de un tercero que el usuario ha elegido; el desarrollador no recibe nada. Lo que ve el sitio web es del sitio web. | F1 (2026-10-20); F4 («Maintains a browsing cache or cookies»: la app los borra al salir) |
| W-2 | **Safe Browsing** de la WebView (activado por decisión del propietario, 2026-09-28) | El componente web del sistema comprueba la dirección con Google (prefijos de hash). En la pasada MASTG no se vio desde el UID de la app: va por Google Play Services | **No se declara** **[Duda D-2]** | No lo manda código de la app ni de un SDK incluido en ella: es una función de la WebView del sistema, activa **por defecto** («WebView objects verify URLs using Google Safe Browsing», F7, que recomienda dejarla activada). F1 define recoger como transmitir «from your app». | F1, F7 (2026-10-20) |
| W-3 | **Consulta de autorrelleno** de la WebView a `content-autofill.googleapis.com` (H-1 de la 020, aceptada) | En páginas con formularios, la WebView envía a Google la firma (*hash*) del formulario (dominio y nombres de campos, no lo escrito), desde el proceso y el UID de la app. La app no la puede cortar | **No se declara** **[Duda D-2]** | Mismo razonamiento que W-2: la hace la WebView del sistema, no el código de la app, y el contenido de la página no es del desarrollador (F1, WebView). **Ninguna página de la Ayuda de Play trata este caso**: se resuelve por CL-023-2 (§5). La política de privacidad lo cuenta igual (CA-023-02). | F1, F4 («Code that controls the behavior of a WebView element in your app» es un indicador a revisar: se ha revisado) (2026-10-20) |
| W-4 | **Notificaciones locales** (spec 019) | Nada: el sistema las muestra desde el propio móvil; sin *push*, sin servidor, sin red | **No se declara** | No hay transmisión fuera del móvil. «Developer communications» (F1) es para notificaciones o noticias enviadas por el desarrollador, no es el caso. El texto de la tarea sale a la bandeja del sistema (T-17 de `threat-model.md`): es un procesamiento en el móvil. | F1 (2026-10-20) |
| W-5 | **Copia de seguridad** de Android (Auto Backup y transferencia entre móviles) | El sistema sube la base de datos y los ajustes (no las imágenes ni los PDF) a la cuenta de Google del usuario; cifrada de extremo a extremo con bloqueo de pantalla en Android 9 o más; en Android 8 no se copia nada (ADR-0004). La app no ejecuta código de copia | **No se declara** | F1 (preguntas frecuentes): si el usuario sube sus datos a su propio almacenamiento en la nube «governed by the external drive or cloud storage provider's terms … and your app never collects or accesses the data», la app no declara la recogida; y lo cifrado de extremo a extremo que solo leen emisor y receptor queda fuera. F5: la copia va a «the user's Google Drive» y «is end-to-end encrypted on devices running Android 9 or higher». | F1, F5 (2026-10-20) |
| W-6 | **Android vitals** (cierres y ANR en Play Console) | Si el usuario ha activado compartir uso y diagnósticos con Google en Android, **el sistema** manda los datos de fallos a Google; la app no incluye ningún informe de errores | **No se declara** | F3: los datos de Android vitals se recogen «from users who have opted in to automatically share usage and diagnostics data from a subset of Android devices»: lo decide el ajuste del sistema del usuario y lo envía Android, no la app. «Crash logs» (F1) se declara cuando la app transmite sus fallos; esta no. | F1, F3 (2026-10-20) |
| W-7 | **Referente** al abrir las webs de la app desde Ajustes (015 §10) | El navegador del sistema (no la app) pide la página de la app al alojamiento y puede mandar `android-app://<paquete>` como referente. El código de la app no pone `EXTRA_REFERRER` | **No se declara** | La app solo entrega la dirección al navegador por el sistema; la petición es del navegador. La web es del propio desarrollador (primera parte). Aun así la política lo cuenta (CA-023-02). | F1, `threat-model.md` T-5 (2026-10-20) |
| W-8 | **«Abrir en el navegador»** de la tarea web (009) | La app pasa al navegador la dirección guardada | **No se declara** | Es una acción que inicia el usuario y cuyo resultado espera: F1, «Sharing», excluye «User-initiated action … where the user reasonably expects the data to be shared». Lo que se envía después lo decide el navegador y el sitio. | F1 (2026-10-20) |
| W-9 | **Enlaces de un PDF** (`https`, `mailto:`, `tel:`; 008) | Tras confirmar con el destino saneado, la app entrega la dirección al navegador, al correo o al marcador; del `mailto:` solo destinatarios y asunto; `tel:` solo marca, no llama | **No se declara** | Igual que W-8: acción del usuario, con confirmación expresa. F1 cuenta como «sharing» la transferencia a otra app en el móvil, pero exceptúa la que parte de una acción del usuario que espera ese resultado. | F1 (2026-10-20) |
| W-10 | **`ACCESS_LOCAL_NETWORK`** (Android 17; H-8 de los spikes) | La app no se conecta a la red local: al crear una tarea web rechaza las direcciones privadas o locales (009) y bloquea la redirección del servidor hacia ellas (CL-009-1). Solo la página, como en un navegador, podría hacerlo con sus marcos internos o con un dominio que resuelva a una IP privada (`threat-model.md` §7) | **No se declara el permiso ni datos** | F6: con `targetSdk` < 37 (hoy 36) «Apps with INTERNET permission receive an implicit permission grant for ACCESS_LOCAL_NETWORK … Don't request ACCESS_LOCAL_NETWORK at runtime prior to targeting SDK 37»; con 37 o más pasa a «blocked by default» y «Traffic originating from Android Webviews that require local network access will inherit permission state from the host app». La app no declara el permiso ni pide acceso a la red local; no se transmite nada de ella. **Si algún día se sube el `targetSdk` a 37, la red local queda bloqueada también para la WebView** (sin tocar esta declaración). | F6 (2026-10-20); `app/android/app/build.gradle.kts` |
| W-11 | **Permisos del manifiesto** (`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`) | Ninguno envía datos por sí mismo | **No se declara** | F1 («Do I need to declare data if my app includes a permission but does not actually collect or share the data?»): «You do not need to declare collection or sharing unless data is actually collected and/or shared». Ninguno es de los que exigen el formulario de declaración de permisos (F9 solo cita SMS y registro de llamadas; F12 no los lista; `USE_EXACT_ALARM` no se usa). **[Suposición]** No hay formulario de permisos en F6; se confirma con el aviso de Play Console al subir el primer AAB. | F1, F9, F12 (2026-10-20) |
| W-12 | **Cámara del sistema y selectores** de fotos o archivos | Nada sale: la app recibe solo lo que el usuario elige (007, 008) | **No se declara** | Datos que **entran** en la app y se guardan en el móvil (§3). Sin permiso de cámara, fotos ni almacenamiento. | F1, F4 (2026-10-20) |
| W-13 | **Webs de la app** (política, licencias y ayuda, alojadas en Vercel; spec 023) | El alojamiento ve la IP y los datos técnicos de quien las abre, en sus registros; sin cookies ni analítica | **No es de Data safety** **[Suposición]** | El formulario describe lo que recoge **la app**; las webs son un sitio aparte (F1: «transmitting data from your app»). La política de privacidad tiene una sección «Esta web» que lo cuenta y dice de quién es el responsable (CA-023-02). | F1 (2026-10-20) |

## 5. Dudas de interpretación (CL-023-2) para la revisión del propietario

Ninguna página de la Ayuda de Play dice que haya que declarar algo en estos casos; ninguna dice tampoco que no. Se ha escogido la respuesta **que sigue el texto de F1 al pie de la letra**. Si el propietario prefiere declarar, se aplica CL-023-1 (excepción a P4, con ADR) **antes** de seguir con T-023-05.

| ID | Duda | Texto de la Ayuda que se ha aplicado | Respuesta adoptada | Qué pasaría si Play opina otra cosa |
|---|---|---|---|---|
| D-1 | La tarea web **no es navegar la web abierta** en sentido estricto: el usuario no navega (ADR-0018, sin enlaces ni formularios) sino que pide **una** página. ¿Cuenta como «webview in which users are navigating the open web» (no se declara) o como «webview … if your app is in control of the code/behavior delivered» (se declara)? | F1: la recogida desde una WebView cuenta si la app «is in control of the code/behavior delivered through that webview». La app controla el contenedor (ajustes de la WebView), no lo que la página entrega: el contenido es de un tercero que el usuario elige. | **No se declara.** | Habría que marcar, como mucho, «Web browsing history» (la dirección de la página que el usuario carga) con la finalidad «App functionality»: el objetivo «Data Not Collected» (A-8) cambia. Se pararía y se haría un ADR. |
| D-2 | La WebView del sistema hace por su cuenta **dos consultas a Google** (Safe Browsing y autorrelleno, esta última desde el UID de la app) que la app no puede cortar. ¿Son «user data transmitted off device from your app» (F1)? | F1 define recoger como transmitir desde **tu app** y menciona las bibliotecas y SDK **que usa tu app** (código incluido en ella). La WebView es un componente del sistema que se actualiza por separado (Android System WebView), no un SDK incluido. F7 presenta Safe Browsing como función por defecto de la WebView. | **No se declara.** La política de privacidad lo cuenta con transparencia (CA-023-02). | Igual que D-1: «Web browsing history» o «Other app activity» compartido con Google, para «Fraud prevention, security, and compliance». |

Recomendación: **no declarar** (D-1 y D-2). [Suposición] La lectura es la natural del texto de F1, la que haría cualquier navegador que use la WebView del sistema sin cambiar su comportamiento, y es coherente con lo que dice la política. El riesgo residual es que la revisión de Play no coincida; la propia Ayuda dice que «Google's review process is not designed to verify the accuracy» y que la responsabilidad de la declaración es del desarrollador (F1).

## 6. Tabla de permisos (CA-023-05 y 08)

Formato fijo que lee la comprobación de `store/google-play/check.mjs` (T-023-08): la primera columna es el permiso completo; **ES** y **EN** son los textos con los que la política de privacidad nombra el permiso (tienen que aparecer **tal cual** en `docs/legal/privacy-policy.md`; T-023-05 los respeta); la última dice si está en la lista blanca del manifiesto de *release* (`ALLOWED=(…)` de `tools/check-android-permissions.sh`) o si es del sistema y no está declarado.

| permiso | ES | EN | lista blanca |
|---|---|---|---|
| android.permission.INTERNET | Internet | Internet | sí |
| android.permission.POST_NOTIFICATIONS | Notificaciones | Notifications | sí |
| android.permission.RECEIVE_BOOT_COMPLETED | reprogramar los avisos al reiniciar el móvil | reschedule the reminders after a restart | sí |
| android.permission.ACCESS_LOCAL_NETWORK | red local | local network | sistema, no declarado |

[Hecho] El permiso interno `<paquete>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` que Android añade a toda app no se lista (no cuenta). `CAMERA` no se pide (la cámara es la del sistema, 007): se quita de `threat-model.md` §4 al cerrar la 023.

## 7. Qué se cierra con esta declaración (para T-023-12)

- **PD-9:** [Hecho] queda resuelta con la decisión «no se declara» (§4, W-2 y W-3; dudas D-1 y D-2 si el propietario lo confirma) y sus fuentes (F1, F4, F7, 2026-10-20).
- **H-1:** [Hecho] sigue aceptada (`threat-model.md` §7); su nota para Data Safety es W-3.
- **H-8 / CA-023-07:** [Hecho] W-10. Ojo: `threat-model.md` §4, la spec y los spikes dicen que Android 17 concede el permiso «a las apps con INTERNET»; F6 precisa que es **solo mientras el `targetSdk` sea menor de 37** (hoy 36). Con 37 queda bloqueado por defecto. T-023-12 lo escribe con ese matiz.
