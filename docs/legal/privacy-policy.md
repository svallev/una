# Política de privacidad / Privacy policy

> **Estado: texto sin suposiciones (spec 023, T-023-05, 2026-10-20). No ha tenido revisión jurídica:** la revisión legal de la política y de las licencias (ADR-0026) es un punto bloqueante de `/release-checklist` antes de la primera subida a Play (CA-023-22). Este archivo es la **única fuente** del texto de la web a la que enlaza «Política de privacidad» (`landing/`, CA-023-04): lo que va entre esta cabecera y las notas del final es lo que se publica.
> El nombre de la app se escribe `{appName}` y sale de `app/identity.yaml` (P7). Los únicos huecos que quedan son los de identidad, de una lista cerrada que se rellena en F6 (PD-2, PD-3): `[RESPONSABLE]`/`[CONTROLLER]`, `[CONTACTO]`/`[CONTACT]`, `[FECHA]`/`[DATE]` y `[WEB]`/`[WEBSITE]` (este último hoy no se usa). **Una web publicada con huecos no pasa la puerta de publicación** (CA-012-05, CA-023-01); cualquier otra marca o texto entre corchetes que no sea un enlace falla en los dos modos.
> Fuentes de cada punto: en las notas de revisión del final.

---

# Política de privacidad (ES)

**Última actualización:** [FECHA]

## En pocas palabras

{appName} **no recoge datos tuyos**: no tiene cuentas, ni servidor propio, ni analítica, ni informes de errores propios, ni publicidad. Lo que escribes y lo que adjuntas se guarda en tu móvil. Solo hay tres excepciones, que explicamos abajo: la **tarea web** (la página que decides ver se carga por internet), las **copias de seguridad de Android** (que hace tu sistema, en tu cuenta de Google) y las **notificaciones** (opcionales, desde tu móvil y sin servidor). Aparte de la app, las **webs de la app** (esta política, la ayuda y las licencias) están alojadas en un servicio externo que guarda los registros técnicos de cada visita; lo explicamos en «Esta web».

## Quién es el responsable

[RESPONSABLE]. Contacto para cualquier duda sobre esta política: [CONTACTO].

## Qué guarda la app y dónde

Todo lo que creas se guarda **en tu dispositivo**, en el espacio privado de la app y, si tienes activadas las copias de seguridad de Android, en la copia cifrada de tu cuenta de Google (ver «Copias de seguridad»):

- **Tus tareas:** el texto y el orden. En una tarea con PDF, también el **nombre del archivo**; en una tarea web, la **dirección** de la página.
- **Adjuntos que tú añades:** las imágenes (una o varias), las fotos que haces con la cámara del sistema y los archivos PDF. La app guarda una **copia** en su espacio privado.
  - A las **imágenes** se les quitan los metadatos (ubicación, fecha, modelo de cámara) **en la copia que guarda la app**; tu original en la galería no se toca.
  - Los **PDF** se guardan **tal cual**, con los metadatos que traigan.
  - Si el sistema cierra la app justo mientras importas un archivo, puede quedar una copia de trabajo en la zona temporal de la app; la app la borra sola en el siguiente arranque.
- **La página web:** la app **no guarda una copia de la página**.

El desarrollador no recibe nada de esto: no tenemos servidor.

**Cómo se protegen:** Android aísla el espacio privado de cada app, así que otras apps de tu móvil no pueden leer lo que guarda {appName}. Las páginas de la tarea web se cargan solo con conexión cifrada (`https`): la app no carga nada sin cifrar. La app no escribe en ningún registro el texto de tus tareas ni las direcciones que abres. Y lo que borras se borra de verdad: ver «Cuánto tiempo se guarda y cómo borrarlo».

## Qué permisos usa

- **No pide permiso de cámara, de fotos ni de almacenamiento.** Para hacer una foto o elegir un archivo, la app abre la cámara o el selector del sistema y solo recibe lo que tú eliges.
- **Internet:** la app la usa **únicamente** para mostrar una página web cuando tú añades una tarea web.
- **Notificaciones:** solo si enciendes el ajuste «Notificaciones»; la app te lo pide en ese momento (Android 13 o posterior). También usa el permiso que le permite **reprogramar los avisos al reiniciar el móvil**. No pide alarmas exactas.
- **La app no se conecta a tu red local** y no pide ese permiso, aunque Android 17 puede dejar a las apps con internet usar la red local sin pedirlo: al crear una tarea web rechaza las direcciones privadas o locales y no sigue una redirección del servidor hacia ellas. Solo una página web que cargues como tarea web podría intentarlo, como en un navegador (con marcos incrustados en la página o con un nombre de dominio que apunte a una dirección de tu red local).

## Las notificaciones

Son **opcionales y vienen apagadas**. Si las enciendes, tu móvil te muestra 1, 2 o 3 notificaciones al día con tu **tarea actual** (su texto, o «Foto», «Imagen», «PDF» o el dominio de la página; si es un grupo de fotos, solo «Tienes una tarea pendiente.»). Todo ocurre **en tu móvil**: no hay servidor ni notificaciones remotas.

- **La notificación enseña tu tarea en la bandeja de notificaciones.** Con el móvil bloqueado, **lo que se ve lo decide tu sistema**: con los ajustes por defecto se ve entera; si ocultas el contenido sensible en los ajustes de tu móvil, se ve «Tienes una tarea pendiente.». La app lo avisa en Ajustes antes de encender. Relojes enlazados, otras apps con acceso a notificaciones y el historial de notificaciones del sistema pueden verla; la app no los controla.
- La app **no guarda una copia del texto de tu tarea** para los avisos: lo lee de su base de datos cuando llega la hora. Guarda aparte solo los datos para que los avisos sigan tras reiniciar: si están encendidos, cuántos al día, el idioma y la última hora atendida; esos datos no entran en las copias de seguridad.
- Puedes apagarlos en Ajustes de la app o en los ajustes de notificaciones del sistema.

## La tarea web

Cuando añades una dirección, la app carga esa página en directo, como haría un navegador. Por eso:

- El sitio web puede ver, como en cualquier visita, tu dirección IP y los datos técnicos habituales de tu navegador. Sus condiciones y su política de privacidad son las suyas, no las de {appName}.
- **La página puede ejecutar sus propios scripts**, como en un navegador, aislada de tus tareas: la app no le da acceso a tus datos. La app no te deja navegar desde ella a otros sitios ni a otras apps, y no guarda contraseñas ni formularios.
- **Navegación segura de Google: está activada.** La comprobación de direcciones peligrosas la hace el componente web del sistema (Android System WebView), no la app, con Google, y se rige por las condiciones de Google.
- **Autorrelleno:** en páginas con formularios, el componente web del sistema puede consultar a Google las predicciones de autorrelleno. Esa consulta lleva la firma del formulario (el dominio y los nombres de sus campos), no lo que escribes. Además, el servicio de autorrelleno de tu móvil (por ejemplo, el de Google) puede actuar en los campos de la página. La app no puede impedir ninguna de las dos cosas.
- La app desactiva las métricas y diagnósticos de ese componente web.
- La página **no se guarda**: sin conexión no se ve. Al salir de ella se borran las cookies y el almacenamiento web. El sistema puede guardar en el espacio privado de la app el nombre de los sitios que has abierto como tarea web; no entra en las copias de seguridad y se borra al desinstalar la app.

## Enlaces y otras apps

Estas acciones las inicias tú. La app solo entrega una dirección a otra app de tu móvil; lo que esa app envíe después lo decide ella.

- **Abrir en el navegador** (tarea web): la app pasa a tu navegador la dirección guardada de la página.
- **Los enlaces de un PDF** (`https`, `mailto:` y `tel:`): antes de abrirlos la app te enseña el destino y te pide confirmar. Un `mailto:` solo lleva destinatarios y asunto; un `tel:` solo marca el número, no llama.
- **Las webs de la app** (en Ajustes: Política de privacidad, Licencias de terceros y Ayuda): se abren en tu navegador. El navegador se conecta a ellas y puede enviarles que vienes de esta app (el «referente», `android-app://` seguido del identificador de la app). **La app no envía nada.**

## Copias de seguridad

Android puede copiar los datos de las apps a tu cuenta de Google (copia de seguridad del sistema) y pasarlos a un móvil nuevo. En {appName}:

- **En la nube (Google Drive):** se copian **las tareas** (su texto y orden y, en las de adjunto, el nombre del PDF o la dirección de la página web) y los ajustes (idioma, pantalla siempre activa, bloquear zoom y los dos de las notificaciones: si están encendidas y cuántas al día), y **solo si la copia va cifrada de extremo a extremo**, lo que requiere un bloqueo de pantalla (Android 9 o superior). En Android 8 no se copia nada. **Los archivos de imagen y de PDF no se suben a la nube**: al restaurar, esas tareas dicen «Adjunto no disponible».
- **No se copia** la copia aparte que la app guarda para reprogramar los avisos tras reiniciar el móvil, ni nada de la tarea web (ver más arriba): en un móvil nuevo, la app lo rehace al abrirse.
- **Al pasar los datos de un móvil a otro con cable o Wi-Fi directo:** en Android 12 o superior se transfiere todo, adjuntos incluidos. En Android 9 a 11 los archivos de imagen y de PDF tampoco se transfieren.
- Esas copias las gestiona Google en tu cuenta; no las vemos nosotros. Puedes desactivarlas en los ajustes de Android.
- **Reinstalar:** si reinstalas la app con la copia de seguridad activada, puede que recuperes las tareas guardadas en la copia.

## Compartir con terceros

**No compartimos datos con nadie.** La app no incluye SDK de terceros que envíen información. La app tampoco envía informes de fallos: si tienes activado en Android el uso compartido de datos de uso y diagnóstico con Google, es tu sistema, no la app, quien puede enviarle datos de los cierres de la app, y Google Play puede enseñar al desarrollador estadísticas de ellos. Lo decide ese ajuste de tu móvil.

## Esta web

- Las **webs de la app** (esta política, la ayuda y las licencias de terceros) están alojadas en Vercel. Al abrirlas, el alojamiento ve, como cualquier sitio web, tu **dirección IP** y los datos técnicos de la visita (la página pedida, la hora, tu navegador y tu sistema), y los guarda en sus registros el tiempo mínimo necesario, según [su política de privacidad](https://vercel.com/legal/privacy-policy).
- Las webs funcionan sin cookies, sin analítica, sin JavaScript y sin recursos de otros sitios (las fuentes van incluidas en la propia web).
- El desarrollador **no guarda ni consulta esos registros** y no te pide ninguna información: los guarda el alojamiento, que puede tratarlos fuera de tu país, EE. UU. incluido, con las garantías que explica en su política.
- La app no tiene nada que ver con esos registros: no envía datos a las webs; las abre tu navegador cuando tú lo pides (ver «Enlaces y otras apps»).

## Cuánto tiempo se guarda y cómo borrarlo

- **Completar una tarea la borra del todo**, con su texto y sus adjuntos. No queda histórico ni papelera.
- **Eliminar una tarea se puede deshacer unos segundos** (por defecto 4; más si tu móvil tiene ajustes de accesibilidad que piden más tiempo). Durante ese tiempo la app guarda en memoria el texto de la tarea y no borra sus archivos. **Después se borra del todo**, con su texto y sus adjuntos, y no queda papelera. Si cierras la app o la dejas en segundo plano, se borra en ese momento.
- **Desinstalar la app borra todo** lo que guardó en tu móvil. Las copias de seguridad que ya hubiera hecho el sistema las gestionas tú en tu cuenta de Google.

## Menores

La app no está dirigida a menores de 16 años.

## Tus derechos

Como la app no recoge ni conserva datos personales tuyos, no hay nada que acceder, corregir o borrar en ella. Si tienes cualquier duda, escribe a [CONTACTO]. Si vives en el Espacio Económico Europeo, también puedes reclamar ante tu autoridad de protección de datos.

## Cambios en esta política

Si algún día la app cambia lo que hace con los datos (por ejemplo, con sincronización o si las copias de seguridad incluyeran también tus imágenes y PDF), esta política se actualizará **antes** y la nueva función será opcional y pedirá tu consentimiento. La fecha de arriba indica la última revisión.

---

# Privacy policy (EN)

**Last updated:** [DATE]

## In short

{appName} **doesn't collect data about you**: it has no accounts, no server of its own, no analytics, no crash reporting of its own and no ads. What you write and attach is stored on your phone. There are only three exceptions, explained below: the **web task** (the page you choose to view is loaded over the internet), **Android backups** (made by your system, into your Google account) and **notifications** (optional, from your phone and with no server). Apart from the app, the **app's websites** (this policy, the help and the licenses) are hosted by an outside service that keeps the technical logs of each visit; we explain it in "This website".

## Who is responsible

[CONTROLLER]. Contact for any question about this policy: [CONTACT].

## What the app stores and where

Everything you create is stored **on your device**, in the app's private space and, if Android backup is on, in the encrypted backup in your Google account (see "Backups"):

- **Your tasks:** the text and their order. For a task with a PDF, also the **file name**; for a web task, the **address** of the page.
- **Attachments you add:** images (one or several), photos you take with the system camera, and PDF files. The app keeps a **copy** in its private space.
  - **Images** have their metadata (location, date, camera model) removed **from the copy the app keeps**; your original in the gallery isn't touched.
  - **PDFs** are stored **as they are**, with whatever metadata they carry.
  - If the system closes the app in the middle of an import, a working copy may stay in the app's temporary area; the app deletes it on its own at the next start.
- **The web page:** the app **doesn't keep a copy of the page**.

The developer receives none of this: we have no server.

**How the data is protected:** Android isolates each app's private space, so other apps on your phone can't read what {appName} stores. Web task pages are loaded only over an encrypted connection (`https`): the app loads nothing unencrypted. The app writes neither the text of your tasks nor the addresses you open to any log. And what you delete is really deleted: see "How long data is kept and how to delete it".

## What permissions it uses

- **It doesn't ask for camera, photos or storage permission.** To take a photo or pick a file, the app opens the system camera or picker and only receives what you choose.
- **Internet:** the app uses it **only** to show a web page when you add a web task.
- **Notifications:** only if you turn on the "Notifications" setting; the app asks for it at that moment (Android 13 or later). It also uses the permission that lets it **reschedule the reminders after a restart**. It doesn't ask for exact alarms.
- **The app doesn't connect to your local network** and doesn't ask for that permission, even though Android 17 may let apps with internet use the local network without asking: when you create a web task it rejects private or local addresses and doesn't follow a server redirect to them. Only a web page that you load as a web task could try, as in a browser (with frames embedded in the page or with a domain name that points to an address on your local network).

## Notifications

They are **optional and off by default**. If you turn them on, your phone shows 1, 2 or 3 notifications a day with your **current task** (its text, or "Photo", "Image", "PDF" or the page's domain; for a photo group, only "You have a task waiting."). Everything happens **on your phone**: there is no server and no remote notifications.

- **The notification shows your task in the notification shade.** With the phone locked, **what you see is decided by your system**: with the default settings it shows in full; if you hide sensitive content in your phone's settings, it shows "You have a task waiting.". The app tells you in Settings before you turn it on. Linked watches, other apps with notification access and the system's notification history may see it; the app doesn't control them.
- The app **doesn't keep a copy of your task text** for the reminders: it reads it from its database when the time comes. It keeps separately only what it needs to keep the reminders going after a restart: whether they are on, how many a day, the language and the last time handled; that data isn't included in backups.
- You can turn them off in the app's Settings or in the system's notification settings.

## The web task

When you add an address, the app loads that page live, as a browser would. Therefore:

- The website can see, as on any visit, your IP address and the usual technical details of your browser. Its terms and privacy policy are its own, not {appName}'s.
- **The page can run its own scripts**, as in a browser, isolated from your tasks: the app gives it no access to your data. The app doesn't let you navigate from it to other sites or apps, and doesn't save passwords or forms.
- **Google Safe Browsing is on.** The check for dangerous addresses is done by the system's web component (Android System WebView), not by the app, with Google, under Google's terms.
- **Autofill:** on pages with forms, the system's web component may query Google for autofill predictions. That query carries the form's signature (the domain and the names of its fields), not what you type. In addition, your phone's autofill service (for example, Google's) may act on the page's fields. The app can't prevent either of them.
- The app turns off that web component's metrics and diagnostics.
- The page is **not saved**: without a connection it isn't shown. Cookies and web storage are cleared when you leave it. The system may store in the app's private space the names of the sites you have opened as a web task; it isn't included in backups and is erased when you uninstall the app.

## Links and other apps

You start these actions. The app only hands an address to another app on your phone; what that app sends afterwards is up to it.

- **Open in browser** (web task): the app passes the page's saved address to your browser.
- **The links in a PDF** (`https`, `mailto:` and `tel:`): before opening them the app shows you the destination and asks you to confirm. A `mailto:` carries only recipients and subject; a `tel:` only dials the number, it doesn't call.
- **The app's websites** (in Settings: Privacy policy, Third-party licenses and Help): they open in your browser. The browser connects to them and may tell them you come from this app (the "referrer", `android-app://` followed by the app's identifier). **The app sends nothing.**

## Backups

Android can copy apps' data to your Google account (system backup) and move it to a new phone. In {appName}:

- **In the cloud (Google Drive):** **tasks** (their text and order and, for those with an attachment, the PDF name or the web address) and settings (language, keep screen on, lock zoom and the two notification settings: whether they are on and how many a day) are copied, and **only if the backup is end-to-end encrypted**, which requires a screen lock (Android 9 or later). On Android 8, nothing is copied. **Image and PDF files aren't uploaded to the cloud**: after a restore, those tasks say "Attachment unavailable".
- **Not copied:** the separate copy the app keeps to reschedule the reminders after a restart, and nothing from the web task (see above): on a new phone, the app rebuilds it when it opens.
- **When moving data from one phone to another by cable or direct Wi-Fi:** on Android 12 or later everything is transferred, attachments included. On Android 9 to 11, image and PDF files aren't transferred either.
- Google manages those copies in your account; we can't see them. You can turn them off in Android settings.
- **Reinstalling:** if you reinstall the app with backup on, you may get back the tasks saved in the backup.

## Sharing with third parties

**We share no data with anyone.** The app includes no third-party SDKs that send information. The app doesn't send crash reports either: if you have turned on sharing usage and diagnostics data with Google in Android, it is your system, not the app, that may send Google data about the app's crashes, and Google Play may show the developer statistics about them. That setting on your phone decides it.

## This website

- The **app's websites** (this policy, the help and the third-party licenses) are hosted on Vercel. When you open them, the host sees, like any website, your **IP address** and the technical details of the visit (the page requested, the time, your browser and your system), and keeps them in its logs for the minimum time necessary, according to [its privacy policy](https://vercel.com/legal/privacy-policy).
- The websites work with no cookies, no analytics, no JavaScript and no resources from other sites (the fonts are included in the website itself).
- The developer **neither keeps nor looks at those logs** and asks you for no information: the host keeps them, and may process them outside your country, the US included, with the safeguards it explains in its policy.
- The app has nothing to do with those logs: it sends no data to the websites; your browser opens them when you ask it to (see "Links and other apps").

## How long data is kept and how to delete it

- **Completing a task erases it completely**, text and attachments included. There is no history or trash.
- **Deleting a task can be undone for a few seconds** (4 by default; longer if your phone has accessibility settings that ask for more time). During that time the app keeps the task's text in memory and does not erase its files. **After that it is erased completely**, text and attachments included, with no trash. If you close the app or leave it in the background, it is erased at that moment.
- **Uninstalling the app erases everything** it stored on your phone. Backups the system already made are managed by you in your Google account.

## Children

The app isn't aimed at children under 16.

## Your rights

Since the app neither collects nor keeps personal data about you, there is nothing in it to access, correct or delete. If you have any question, write to [CONTACT]. If you live in the European Economic Area, you can also complain to your data protection authority.

## Changes to this policy

If the app ever changes what it does with data (for example, with sync or if backups also included your images and PDFs), this policy will be updated **beforehand** and the new feature will be optional and ask for your consent. The date above shows the latest revision.

---

## Notas para la revisión (no forman parte del texto publicado)

Todas las fuentes se leyeron el 2026-10-20. **[Hecho]** = comprobado en el código, en la spec o en la fuente citada; **[Suposición]** = interpretación; **[Pendiente]** = depende de F6.

1. **Coherencia con Data Safety:** el texto dice «no recoge datos» y coincide con la declaración «la app no recoge ni comparte datos» de `store/google-play/data-safety.md` (flujos W-1 a W-13; decisión del propietario de no declarar la tarea web, Safe Browsing ni el autorrelleno, D-1 y D-2). PD-9 queda cerrada con esa decisión (T-023-12). Los nombres de los permisos son los de la tabla de `data-safety.md` §6 (CA-023-08).
2. **Copia en la nube** (ADR-0004): **[Hecho]** `app/android/app/src/main/res/xml/backup_rules.xml` (Android 8: nada), `xml-v28/backup_rules.xml` (9 a 11: BD y preferencias, con cifrado de extremo a extremo, sin adjuntos) y `xml/data_extraction_rules.xml` (12+: nube con `disableIfNoEncryptionCapabilities`, transferencia con adjuntos). Los ajustes viajan porque están en la BD (`app_flutter/`): idioma, pantalla siempre activa, bloquear zoom, notificaciones encendidas y cuántas al día (`SettingsRepository`; CA-019-05). La copia derivada de los avisos vive en los dominios `device_*`, que ninguna regla incluye (CA-019-23). El BackupAgent con presupuesto sigue aplazado: si se hace, «Copias de seguridad» se actualiza **antes** de publicar esa versión. «Puedes desactivarlas en los ajustes de Android»: Auto Backup solo corre si «the user has enabled backup on the device» (Android Developers, «Back up user data with Auto Backup», última edición 2026-02-26 UTC).
3. **Residuo de la WebView (CA-009-13):** **[Hecho]** la redacción es la de CA-023-02, aprobada con la spec 023 (propietario, 2026-10-19; §9: «se quedan así» si no se dice nada); `data_extraction_rules.xml` incluye de la nube solo `app_flutter/` y las preferencias, y excluye `AwOriginVisitLoggerPrefs.xml` y `WebViewChromiumPrefs.xml`; el perfil `app_webview/` no se incluye (`docs/security/threat-model.md` §7).
4. **Autorrelleno (H-1 de la 020):** **[Hecho]** `threat-model.md` §4 y §7 y `specs/020-seguridad-y-puerta-de-publicacion/mastg.md` (prueba 13): la WebView consulta `content-autofill.googleapis.com` con la firma del formulario, no lo escrito; el servicio de autorrelleno del sistema puede actuar en los campos (enmienda de CA-009-13). **Safe Browsing:** `AndroidManifest.xml` (activado por decisión del propietario, 2026-09-28; `MetricsOptOut = true`). Para Data Safety, W-2 y W-3.
5. **PDF y metadatos:** **[Hecho]** se guardan sin modificar (spec 008). Si algún día se sanean, cambia el texto.
6. **Edad:** **[Hecho]** Q-023-2 a (propietario, 2026-10-19): 16 y más; coincide con el público objetivo de `store/google-play/play-console.md`.
7. **Responsable y contacto:** **[Pendiente, F6]** dependen de la cuenta de Play (PD-3) y del dominio (PD-2). Una cuenta personal puede obligar a mostrar dirección y teléfono (`play-console.md`).
8. **Esta web:** **[Hecho]** alojamiento en Vercel (ADR-0009 y 0010; el proyecto se crea en F6). Fuentes: Aviso de privacidad de Vercel (última actualización 1 de junio de 2026, https://vercel.com/legal/privacy-policy): recoge de las webs de sus clientes «End User IP address, location information derived from IP address, and system configuration information»; cuando trata datos «at the direction of our Customer» actúa como encargado y el cliente es el responsable; conserva la información «for the minimum necessary period»; puede tratarla fuera del país de residencia (EE. UU. incluido) con cláusulas contractuales tipo y el Data Privacy Framework. Los registros de ejecución del panel de Vercel duran 1 hora (Hobby), 1 día (Pro) o 3 días (Enterprise), 30 con Observability Plus («Runtime Logs», actualizada 2026-08-28), pero esa página trata de las funciones, no de las visitas a archivos estáticos. **[Pendiente, F6]** Vercel no publica un plazo para los registros de visitas de un sitio estático: la política dice «el tiempo mínimo necesario» (lo que Vercel dice); al crear el proyecto se mira el plan elegido y, si el panel enseña un plazo, se concreta aquí. Sin cookies, analítica ni JavaScript: CA-023-13 y 14. **Decisión del propietario (2026-10-20):** no guarda ni consulta ningún registro ni pide información a quien visita las webs; por eso la política no se declara responsable de los registros ni ofrece pedir su borrado (los guarda el alojamiento). **[Suposición]** La revisión legal (CA-023-22) debe confirmar que esa redacción basta, porque Vercel dice que el cliente es el responsable de los datos que trata por encargo.
9. **Eliminar se puede deshacer (spec 014, ADR-0021):** **[Hecho]** 4 s por defecto (`design/tokens.json`, `undoWindow`), más con el «Tiempo para actuar» del sistema, y pasar a segundo plano la hace definitiva (`undo_controller.dart`). No cambia «no recoge datos»; los archivos siguen en disco mientras se puede deshacer (`threat-model.md`, T-7).
10. **Afirmaciones con fuente:** «sin publicidad»: **[Hecho]** sin SDK de publicidad ni `AD_ID` en el manifiesto (la puerta de permisos solo admite tres; `threat-model.md` §4 y T-13). «Sin informes de errores propios»: sin SDK de fallos; las estadísticas de Android vitals las envía el sistema si el usuario lo ha activado (Ayuda de Play, «Android vitals»; `data-safety.md` W-6). El compromiso de consentimiento futuro es de P4.
11. **Importación interrumpida:** **[Hecho]** `AttachmentJanitor.sweep()` (spec 007, CA-007-16) borra 2 s después de arrancar (`UnaApp.sweepDelay`) todas las preparaciones de la zona temporal (`getTemporaryDirectory()/import`) que no sean de una importación en curso.
12. **Notificaciones:** **[Hecho]** CA-019-05 (valores y copia), 16 y 17 (etiquetas: texto, «Foto», «Imagen», «PDF» o dominio; un grupo de fotos no lleva etiqueta y dice lo mismo que la versión genérica), 23 (única información fuera de la BD) y `AndroidManifest.xml` (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, sin alarmas exactas).
13. **Enlaces y otras apps:** **[Hecho]** specs 008 (CA-008-12: `https`, `mailto:` y `tel:` con confirmación, sin enviar ni llamar, del `mailto:` solo destinatarios y asunto) y 009 («Abrir en el navegador»); referente `android-app://<paquete>` en 015 §10 (la app no pone `EXTRA_REFERRER`); `data-safety.md` W-7 a W-9.
14. **Red local (CA-023-07):** **[Hecho]** la app no declara `ACCESS_LOCAL_NETWORK` (la puerta de permisos falla si aparece) y la 009 rechaza las direcciones privadas y las redirecciones hacia ellas (CL-009-1). Android 17 concede el permiso implícito a las apps con `INTERNET` solo mientras `targetSdk` < 37, hoy 36 (Android Developers, «Local network permission»): por eso el texto dice «puede dejar». `threat-model.md` §7 y `data-safety.md` W-10.
15. **«Cómo se protegen»** (Ayuda de Play, «User Data»: la política debe incluir «secure data handling procedures for personal and sensitive user data»): **[Hecho]** espacio privado de la app (sandbox de Android), `networkSecurityConfig` sin tráfico en claro y CA-009-09, sin registros de contenido (CL-009-9; pasada MASTG de la 020) y borrado completo (ADR-0012).
16. **Sin suposiciones restantes:** la lista cerrada de huecos es la de CA-023-01; los huecos de F6 están en la lista de CA-023-23.
17. **No es asesoramiento jurídico:** conviene que la revise una persona con conocimiento de RGPD/LOPDGDD antes de publicarla (revisión legal bloqueante, CA-023-22).
