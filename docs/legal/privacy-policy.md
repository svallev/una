# Política de privacidad / Privacy policy — BORRADOR

> **Estado: borrador de trabajo (2026-09-30, revisado tras el `spec-reviewer`). No es la versión final ni ha tenido revisión jurídica.** Se revisa y se adapta antes de publicarla (spec 012, P-012-4; PD-2 y PD-3). Es la base del texto que irá en la web a la que enlaza "Política de privacidad".
> Los huecos entre corchetes son **[Pendiente]**: `[NOMBRE DE LA APP]`, `[RESPONSABLE]`, `[CONTACTO]`, `[FECHA]`. Las frases marcadas **[Suposición]** hay que comprobarlas con la versión final de la app y con la guía vigente de Google Play antes de publicar. **Una web publicada con huecos no pasa la puerta de publicación** (CA-012-05).
> Fuentes: `specs/constitution.md` (P3, P4), `docs/security/threat-model.md` (§5, §7), ADR-0004, ADR-0012, ADR-0016, ADR-0018, specs 007, 008 y 009 (CA-009-13), PD-9.

---

# Política de privacidad (ES)

**Última actualización:** [FECHA]

## En pocas palabras

[NOMBRE DE LA APP] **no recoge datos tuyos**: no tiene cuentas, ni servidor propio, ni analítica, ni informes de errores propios, ni publicidad. Lo que escribes y lo que adjuntas se guarda en tu móvil. Solo hay dos excepciones, que explicamos abajo: la **tarea web** (la página que decides ver se carga por internet) y las **copias de seguridad de Android** (que hace tu sistema, en tu cuenta de Google).

## Quién es el responsable

[RESPONSABLE]. Contacto para cualquier duda sobre esta política: [CONTACTO].

## Qué guarda la app y dónde

Todo lo que creas se guarda **en tu dispositivo**, en el espacio privado de la app y, si tienes activadas las copias de seguridad de Android, en la copia cifrada de tu cuenta de Google (ver "Copias de seguridad"):

- **Tus tareas:** el texto y el orden. En una tarea con PDF, también el **nombre del archivo**; en una tarea web, la **dirección** de la página.
- **Adjuntos que tú añades:** las imágenes, las fotos que haces con la cámara del sistema y los archivos PDF. La app guarda una **copia** en su espacio privado.
  - A las **imágenes** se les quitan los metadatos (ubicación, fecha, modelo de cámara) **en la copia que guarda la app**; tu original en la galería no se toca.
  - Los **PDF** se guardan **tal cual**, con los metadatos que traigan.
  - **[Suposición]** Si el sistema cierra la app justo mientras importas un archivo, una copia de trabajo puede quedar en la zona temporal de la app hasta que la app la limpie en el siguiente arranque.
- **La página web:** la app **no guarda una copia de la página**.

El desarrollador no recibe nada de esto: no tenemos servidor.

## Qué permisos usa

- **No pide permiso de cámara, de fotos ni de almacenamiento.** Para hacer una foto o elegir un archivo, la app abre la cámara o el selector del sistema y solo recibe lo que tú eliges.
- **Internet:** la app la usa **únicamente** para mostrar una página web cuando tú añades una tarea web.

## La tarea web

Cuando añades una dirección, la app carga esa página en directo, como haría un navegador. Por eso:

- El sitio web puede ver, como en cualquier visita, tu dirección IP y los datos técnicos habituales de tu navegador. Sus condiciones y su política de privacidad son las suyas, no las de [NOMBRE DE LA APP].
- **La página puede ejecutar sus propios scripts**, como en un navegador, aislada de tus tareas: la app no le da acceso a tus datos. La app no te deja navegar desde ella a otros sitios ni a otras apps, y no guarda contraseñas ni formularios.
- **Navegación segura de Google: está activada.** La comprobación la hace el componente web del sistema (Android System WebView), no la app, con Google, y se rige por las condiciones de Google. **[Suposición]** No cambia lo que declaramos en las fichas de tienda (PD-9).
- La app desactiva las métricas y diagnósticos de ese componente web.
- La página **no se guarda**: sin conexión no se ve. Al salir de ella se borran las cookies y el almacenamiento web. **[Suposición]** El sistema puede conservar en el espacio privado de la app el nombre del sitio visitado; no se incluye en las copias. Se decide cómo redactarlo antes de publicar (ver notas).

## Copias de seguridad

Android puede copiar los datos de las apps a tu cuenta de Google (copia de seguridad del sistema) y pasarlos a un móvil nuevo. En [NOMBRE DE LA APP]:

- **En la nube (Google Drive):** se copian **las tareas** (su texto y orden y, en las de adjunto, el nombre del PDF o la dirección de la página web) y los ajustes, y **solo si la copia va cifrada de extremo a extremo**, lo que requiere un bloqueo de pantalla (Android 9 o superior). En Android 8 no se copia nada. **Los archivos de imagen y de PDF no se suben a la nube**: al restaurar, esas tareas dicen "Adjunto no disponible". **[Suposición]** Esto puede cambiar en versiones futuras; se avisará aquí antes.
- **Al pasar los datos de un móvil a otro con cable o Wi-Fi directo:** en Android 12 o superior se transfiere todo, adjuntos incluidos. En Android 9 a 11 los archivos de imagen y de PDF tampoco se transfieren.
- Esas copias las gestiona Google en tu cuenta; no las vemos nosotros. Puedes desactivarlas en los ajustes de Android.
- **Reinstalar:** si reinstalas la app con la copia de seguridad activada, puede que recuperes las tareas guardadas en la copia.

## Compartir con terceros

**No compartimos datos con nadie.** La app no incluye SDK de terceros que envíen información. Tampoco recibimos informes de fallos de la app: **[Suposición]** Google Play puede mostrar al desarrollador estadísticas de cierres si tú has activado compartir diagnósticos con Google; eso lo decide tu ajuste de Android, no la app (comprobar con la guía de Play antes de declarar "Data not collected").

## Cuánto tiempo se guarda y cómo borrarlo

- **Eliminar o completar una tarea la borra del todo**, con su texto y sus adjuntos. No queda histórico ni papelera.
- **Desinstalar la app borra todo** lo que guardó en tu móvil. Las copias de seguridad que ya hubiera hecho el sistema las gestionas tú en tu cuenta de Google.

## Menores

La app no está dirigida a menores de 14 años. **[Suposición]** Comprobar la edad mínima que fijen las fichas de tienda y la normativa aplicable.

## Tus derechos

Como el desarrollador no recoge ni conserva datos personales tuyos, no tiene datos que acceder, corregir o borrar. Si tienes cualquier duda, escribe a [CONTACTO]. Si vives en el Espacio Económico Europeo, también puedes reclamar ante tu autoridad de protección de datos.

## Cambios en esta política

Si algún día la app cambia lo que hace con los datos (por ejemplo, con sincronización o notificaciones), esta política se actualizará **antes** y la nueva función será opcional y pedirá tu consentimiento. La fecha de arriba indica la última revisión.

---

# Privacy policy (EN)

**Last updated:** [DATE]

## In short

[APP NAME] **doesn't collect data about you**: it has no accounts, no server of its own, no analytics, no crash reporting of its own and no ads. What you write and attach is stored on your phone. There are only two exceptions, explained below: the **web task** (the page you choose to view is loaded over the internet) and **Android backups** (made by your system, into your Google account).

## Who is responsible

[CONTROLLER]. Contact for any question about this policy: [CONTACT].

## What the app stores and where

Everything you create is stored **on your device**, in the app's private space and, if Android backup is on, in the encrypted backup in your Google account (see "Backups"):

- **Your tasks:** the text and their order. For a task with a PDF, also the **file name**; for a web task, the **address** of the page.
- **Attachments you add:** images, photos you take with the system camera, and PDF files. The app keeps a **copy** in its private space.
  - **Images** have their metadata (location, date, camera model) removed **from the copy the app keeps**; your original in the gallery isn't touched.
  - **PDFs** are stored **as they are**, with whatever metadata they carry.
  - **[Assumption]** If the system closes the app in the middle of an import, a working copy may stay in the app's temporary area until the app cleans it at the next start.
- **The web page:** the app **doesn't keep a copy of the page**.

The developer receives none of this: we have no server.

## What permissions it uses

- **It doesn't ask for camera, photos or storage permission.** To take a photo or pick a file, the app opens the system camera or picker and only receives what you choose.
- **Internet:** the app uses it **only** to show a web page when you add a web task.

## The web task

When you add an address, the app loads that page live, as a browser would. Therefore:

- The website can see, as on any visit, your IP address and the usual technical details of your browser. Its terms and privacy policy are its own, not [APP NAME]'s.
- **The page can run its own scripts**, as in a browser, isolated from your tasks: the app gives it no access to your data. The app doesn't let you navigate from it to other sites or apps, and doesn't save passwords or forms.
- **Google Safe Browsing is on.** The check is done by the system's web component (Android System WebView), not by the app, with Google, under Google's terms. **[Assumption]** It doesn't change what we declare in the store listings (PD-9).
- The app turns off that web component's metrics and diagnostics.
- The page is **not saved**: without a connection it isn't shown. Cookies and web storage are cleared when you leave it. **[Assumption]** The system may keep the visited site's name in the app's private space; it isn't included in backups. How to word this will be decided before publishing (see notes).

## Backups

Android can copy apps' data to your Google account (system backup) and move it to a new phone. In [APP NAME]:

- **In the cloud (Google Drive):** **tasks** (their text and order and, for those with an attachment, the PDF name or the web address) and settings are copied, and **only if the backup is end-to-end encrypted**, which requires a screen lock (Android 9 or later). On Android 8, nothing is copied. **Image and PDF files aren't uploaded to the cloud**: after a restore, those tasks say "Attachment unavailable". **[Assumption]** This may change in future versions; we'll announce it here beforehand.
- **When moving data from one phone to another by cable or direct Wi-Fi:** on Android 12 or later everything is transferred, attachments included. On Android 9 to 11, image and PDF files aren't transferred either.
- Google manages those copies in your account; we can't see them. You can turn them off in Android settings.
- **Reinstalling:** if you reinstall the app with backup on, you may get back the tasks saved in the backup.

## Sharing with third parties

**We share no data with anyone.** The app includes no third-party SDKs that send information. We don't receive crash reports from the app either: **[Assumption]** Google Play may show the developer crash statistics if you have turned on sharing diagnostics with Google; that is set by your Android settings, not by the app (check Play's guidance before declaring "Data not collected").

## How long data is kept and how to delete it

- **Deleting or completing a task erases it completely**, text and attachments included. There is no history or trash.
- **Uninstalling the app erases everything** it stored on your phone. Backups the system already made are managed by you in your Google account.

## Children

The app isn't aimed at children under 14. **[Assumption]** Check the minimum age set by the store listings and applicable law.

## Your rights

Since the developer neither collects nor keeps personal data about you, there is nothing to access, correct or delete. If you have any question, write to [CONTACT]. If you live in the European Economic Area, you can also complain to your data protection authority.

## Changes to this policy

If the app ever changes what it does with data (for example, with sync or notifications), this policy will be updated **beforehand** and the new feature will be optional and ask for your consent. The date above shows the latest revision.

---

## Notas para la revisión (no forman parte del texto publicado)

1. **Coherencia con Data Safety / manifiesto de privacidad:** el texto dice "no recoge datos". Debe coincidir con la declaración de Play ("Data not collected"). Depende de PD-9 (Safe Browsing) y de los diagnósticos de Play (Android vitals).
2. **La copia en la nube** describe el estado actual (ADR-0004): BD y ajustes, imágenes y PDF fuera. La BD incluye el nombre del PDF y la dirección de la web (`originalName`, `sourceUrl`, `sourceHost`). Si más adelante se hace el `BackupAgent` con presupuesto (aplazado el 2026-09-30), hay que actualizar "Copias de seguridad" **antes** de publicar esa versión.
3. **Residuo de la WebView (CA-009-13):** `app_webview/Default/Preferences` y `AwOriginVisitLoggerPrefs.xml` conservan el origen visitado y hashes de orígenes, fuera de las copias. Decidir cómo redactarlo (o si se puede evitar) antes de publicar.
4. **PDF y metadatos:** los PDF se guardan sin modificar (la spec 008 no tiene equivalente al saneado de EXIF de la 007). Si se decide sanearlos, cambia el texto.
5. **Edad mínima y menores:** decidir con la clasificación de contenido de las tiendas y la normativa (14 años en España para consentir; el texto es una suposición).
6. **Responsable y contacto:** dependen de la cuenta de Play (personal u organización, PD-3) y del dominio (PD-2). Una cuenta personal puede exigir mostrar dirección y teléfono.
7. **Dónde se aloja la web de la política** (ADR-0009 y ADR-0010 usan Vercel): que sea pública, estable, en ES y EN, y que el proveedor no ponga analítica ni registros que contradigan "sin terceros". Una sola dirección para los dos idiomas (P-012-2).
8. **Afirmaciones sin fuente aún:** "sin publicidad" (cierto por ausencia de SDK, sin cita), el compromiso de consentimiento futuro (apoya P4) y "puedes desactivar las copias en los ajustes de Android". Confirmarlas al revisar.
9. **No es asesoramiento jurídico:** conviene que la revise una persona con conocimiento de RGPD/LOPDGDD antes de publicarla.
