# Respuestas de Play Console fuera de la ficha

- **Spec:** 023, CA-023-12 y CA-023-21. **Tarea:** T-023-04. La declaración de Data Safety, aparte, está en `data-safety.md` (de él salen los identificadores F1 a F12 de las fuentes).
- **Estado:** **Borrador para la revisión del propietario** (2026-10-20). Nada de esto se rellena en Play Console hasta F6 (proyecto de aprendizaje, sin publicar).
- **Convención:** [Hecho] = leído en la fuente citada; [Suposición] = decisión o interpretación mía (las de la spec se marcan como tales); [Pendiente] = depende de F6 o no se pudo leer. Las páginas se consultaron el **2026-10-20** con `curl -sL` (solo lectura); la Ayuda de Play no muestra su fecha de edición.
- **Los datos de identidad** (correo de contacto, web, dirección…) son **huecos de identidad**, de la lista cerrada de CA-023-01: `[CONTACTO]`, `[WEB]`, `[RESPONSABLE]`. Hasta F6 no se rellenan.

## 1. Fuentes (además de F1 a F12 de `data-safety.md`)

| ID | Página | Dirección |
|---|---|---|
| P1 | Create and set up your app | https://support.google.com/googleplay/android-developer/answer/9859152 |
| P2 | Manage target audience and app content settings | https://support.google.com/googleplay/android-developer/answer/9867159 |
| P3 | Content rating requirements for apps, games, and the ads served on both | https://support.google.com/googleplay/android-developer/answer/9859655 |
| P4 | Choose a category and tags for your app or game | https://support.google.com/googleplay/android-developer/answer/9859673 |
| P5 | Add preview assets to showcase your app | https://support.google.com/googleplay/android-developer/answer/9866151 |
| P6 | Metadata (política de Play) | https://support.google.com/googleplay/android-developer/answer/9898842 |
| P7 | App testing requirements for new personal developer accounts | https://support.google.com/googleplay/android-developer/answer/14151465 |
| P8 | How to support your app's users | https://support.google.com/googleplay/android-developer/answer/9859041 |
| P9 | Required information to create a Play Console developer account | https://support.google.com/googleplay/android-developer/answer/13628312 |
| P10 | Google Play Families Policies | https://support.google.com/googleplay/android-developer/answer/9893335 |
| P11 | Health Content and Services | https://support.google.com/googleplay/android-developer/answer/12261419 |
| P12 | Financial Services | https://support.google.com/googleplay/android-developer/answer/9876821 |

**No se pudo leer [Pendiente, F6]:** (a) las **preguntas exactas del cuestionario de clasificación de contenido** (IARC): P3 explica el proceso y las calificaciones, pero las preguntas solo salen dentro de Play Console; (b) la **declaración de apps gubernamentales** (no se encontró una página pública de la Ayuda dentro de los dominios autorizados); (c) el **orden y el texto exactos** de las pantallas de Play Console, que cambian. Todo se vuelve a mirar al rellenarlo (CL-023-3).

## 2. Respuestas

| Qué pide Play Console | Respuesta | Por qué y fuente |
|---|---|---|
| **Idioma por defecto** de la ficha | **Español (es-ES)** **[Suposición, spec]** y traducción a inglés (en-US) | P1: «Select a default language and add the name of your app». Los dos idiomas de la app son ES y EN (spec 010). |
| **Nombre de la app** | `{appName}` (hoy «Una.»; sale de `app/identity.yaml`), ≤ 30 caracteres, sin emojis | P6: «Your app title must be 30 characters or less. Don't use emojis, emoticons, or repeated special characters». El punto final forma parte del nombre de marca. |
| **App o juego** | App | P1. |
| **Gratis o de pago** | Gratis **[Hecho]** (confirmado por el propietario, 2026-10-20; la ficha no menciona compras) | P1 pide elegirlo al crear la app. Confirmado; al crear la app (P1 no dice que se pueda cambiar después). |
| **Correo de contacto** para usuarios | `[CONTACTO]` (hueco de identidad; F6) | P8: «A contact email address is required»; web y teléfono, opcionales; el correo es público en la ficha. |
| **Categoría** | **Productividad** (*Productivity*) | P4: «Productivity: Notepad, to-do list, keyboard, printing, calendar…». |
| **Etiquetas** (hasta 5) | **[Pendiente, propietario, F6]** se escogen de la lista de Play Console; P4 menciona etiquetas de accesibilidad (p. ej. *Screen reader-friendly*): proponer solo las que la auditoría 022 respalde | P4: «You should choose tags that are most obviously relevant to your app». |
| **Política de privacidad** | La dirección de `privacyPolicyUrl` (marcador `https://example.com/privacy` hasta PD-2; **[Pendiente, F6]** la definitiva) | F2 y F8 (ver §3 para lo que debe decir el texto). |
| **Anuncios** («Contains ads») | **No** | F8: se declara si hay anuncios de SDK de publicidad, nativos o de banner; la app no tiene ninguno ni SDK de publicidad (`threat-model.md` §4 y T-13). |
| **ID de publicidad** | **No se usa** | F10: hay que declarar `com.google.android.gms.permission.AD_ID` para usarlo; el manifiesto de *release* solo admite tres permisos (`tools/check-android-permissions.sh`) y esa no está. |
| **Acceso a la app** (*App access*) | **«All functionality is available without special access»** (sin credenciales de prueba) | F9, paso 5 de «Permissions Declaration Form», y F8, «Sign-in details»: solo hay que dar credenciales si algo está restringido por inicio de sesión, suscripción o ubicación. Aquí no hay cuentas. Con esta respuesta se añaden las notas de §4 para los revisores. |
| **Público objetivo** (*Target audience*) | **16–17 y 18 o más** (Q-023-2 a). No se marcan los grupos de 13–15 ni de menores | P2: «You should only select more than one age group … if you have designed your app for and ensured that your app is appropriate for users within each». Con ningún grupo de menores de 13, la política de Familias no es de aplicación (P2: «Your app is not designed for children»); **[Hecho, P2]** el grupo 16–17 «may be considered to include children in some locales» y, «if your app targets any users who are under the age of 21, you must consider if they would be considered children under their local laws»: es información para el propietario, no cambia la respuesta. |
| **Anuncios dirigidos a niños** | No aplica | P2: sección solo «If your app is serving ads to children». |
| **Clasificación de contenido** (IARC) | Cuestionario en §5 | P3. |
| **App de noticias** | **No** | F8, «News and Magazine apps». |
| **Rastreo de contactos COVID-19** | **No** | F8. |
| **Funciones financieras** | **No** (la opción de que la app no tiene ninguna; **[Pendiente, F6]** el literal) | P12: «Any app that contains any financial features must complete the Financial features declaration form»; sin compras, pagos ni préstamos. |
| **Apps de salud** | **No** (la opción de que la app no tiene funciones de salud; **[Pendiente, F6]** el literal) | P11: «All developers must complete the Health apps declaration form on the App content page». |
| **Apps gubernamentales** | **No** | **[Pendiente, F6]** (b) del apartado anterior. |
| **Seguridad de los datos** | «La app no recoge ni comparte datos» | `data-safety.md`. |
| **Declaración de permisos** (formulario de permisos delicados) | **No hace falta** | F9: solo para permisos de alto riesgo (SMS, registro de llamadas…). **[Suposición]** `INTERNET`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` no están en F12; Play Console avisa al subir el primer AAB si me equivoco. |
| **Dispositivos** | **Solo móvil** **[Suposición, spec; D28, R-25, PD-11 aplazada]** | La app sigue en vertical y no se ha auditado en tabletas ni plegables. No se restringe nada en el catálogo de dispositivos. |
| **Países y regiones** | **Todos** **[Suposición, spec]** | Los idiomas de la ficha (ES, EN) no limitan la distribución. |

## 3. Lo que Play exige a la política de privacidad (entrada para T-023-05)

[Hecho, F2, «Privacy Policy», 2026-10-20] Es lo que la política tiene que cumplir, contrastado con `docs/legal/privacy-policy.md` de hoy:

| Exigencia de F2 | Estado en la política actual | Para T-023-05 |
|---|---|---|
| Enlace en el campo de Play Console **y** enlace o texto **dentro de la app** | Dentro de la app: Ajustes → «Política de privacidad» (abre el navegador; F2 admite «a privacy policy link or text within the app itself») | Sin cambios en la app (Q-023-1 a). |
| «Developer information and a privacy point of contact or a mechanism to submit inquiries» | `[RESPONSABLE]` y `[CONTACTO]` (huecos de identidad) | Se mantienen como huecos hasta F6. |
| Tipos de datos personales y sensibles que accede, recoge, usa y comparte, y con quién | Cubierto (secciones «Qué guarda la app y dónde», «La tarea web», «Compartir con terceros») | Ajustar a `data-safety.md` §4. |
| «Secure data handling procedures for personal and sensitive user data» | **No hay una frase explícita** (hay `https`, espacio privado y borrado, pero repartidos) | **[Hecho, T-023-05]** Párrafo «Cómo se protegen» / «How the data is protected» en «Qué guarda la app y dónde» (ES y EN): espacio privado de la app aislado por Android, páginas solo por `https`, sin registros de contenido y borrado completo. |
| «The developer's data retention and deletion policy» | Cubierto («Cuánto tiempo se guarda y cómo borrarlo») | Sin cambios. |
| «Clear labeling as a privacy policy» | El título lo dice | Sin cambios. |
| «The entity named in the store listing must appear in the privacy policy or the app must be named in the privacy policy» | La app sale con `{appName}`; la entidad, con `[RESPONSABLE]` | Sin cambios. |
| URL pública, sin restricción geográfica, **no PDF** y **no editable** | La web de `landing/` (HTML estático, sin PDF) | Sin cambios. |
| Coherencia con Data Safety (F2, «Data safety section»: «the section must be consistent with the disclosures made in the app's privacy policy») | — | Las secciones de la política y las filas W-1 a W-13 se leen juntas (CA-023-02, 05 y 08). |

## 4. Acceso a la app: notas para los revisores (CA-023-21)

[Hecho, F2/F8] Play pide la política **dentro de la app** y la revisión puede mirar si se llega a ella. Hoy solo se llega **tras crear una tarea** (Ajustes está en el menú de la tarea); la app no cambia (Q-023-1 a, CL-015-4). Texto del campo «Any other instructions» de «Sign-in details»/«App access» **[Suposición]** (ES e EN, con los nombres de la interfaz de las ARB):

> **ES:** La app no tiene cuentas ni inicio de sesión: todo está disponible sin acceso especial. Para ver la política de privacidad dentro de la app: en la pantalla de bienvenida, toca para escribir una tarea y pulsa «Guardar»; después toca «Menú de la tarea», «Ajustes» y «Política de privacidad» (se abre en el navegador). La política también está enlazada en la ficha de Play.
>
> **EN:** The app has no accounts or sign-in: everything is available without special access. To reach the privacy policy inside the app: on the welcome screen, tap to type a task and press "Save"; then tap "Task menu", "Settings" and "Privacy policy" (it opens in the browser). The policy is also linked on the Play listing.

(Los nombres «Guardar», «Menú de la tarea», «Ajustes» y «Política de privacidad» son los de `app_es.arb` y `app_en.arb`: `editorSaveFirst`, `menuButton`, `menuSettings`, `settingsPrivacy`.) Se comprueban otra vez en F6 por si la interfaz ha cambiado.

## 5. Cuestionario de clasificación de contenido (IARC)

[Hecho, P3] El cuestionario lo contesta el desarrollador en Play Console («Policy → App content → Start»), con un correo para IARC, una **categoría** y las preguntas; las calificaciones se calculan solas y se pueden repetir. Debe rehacerse si cambia el contenido de la app. **[Pendiente, F6]** Las preguntas literales no son públicas; este es el **plan de respuestas por tema**, que se contrasta pregunta a pregunta al rellenarlo:

| Tema | Respuesta preparada | Por qué |
|---|---|---|
| Categoría del cuestionario | La de «utilidades / productividad / otros» (no juego, no red social, no contenido de referencia ni noticias) | La app es una lista de tareas (categoría de la tienda: Productividad). |
| Violencia, sexualidad, lenguaje soez, drogas, apuestas, miedo | **No** en todos | La app no trae contenido propio: solo muestra lo que el usuario guarda. |
| Interacción entre usuarios / contenido generado por usuarios compartido | **No** | Sin cuentas, sin red social ni mensajes: el contenido nunca sale del móvil. |
| Comparte la ubicación del usuario | **No** | Sin permisos de ubicación. |
| Compras digitales / dinero real | **No** | Sin compras. |
| **Acceso a internet sin restricciones** (el navegador o la WebView) | **Sí, con matiz** **[Suposición]**: la tarea web carga una página elegida por el usuario, sin navegación posterior ni enlaces | Es la pregunta delicada (la spec, CA-023-12, la da por hecha): la tarea web enseña contenido de terceros que la app no controla. Se responde con la verdad y se acepta la calificación que resulte. |
| Contenido creado por el usuario visible a otros | **No** | Nada se comparte. |

**[Suposición]** Resultado esperado: calificación baja (3+ / PEGI 3 / «Everyone»), posiblemente con el aviso «contenido generado por usuarios / acceso a internet» por la tarea web. El propietario ve el resultado al rellenarlo en F6.

## 6. Texto alternativo de los gráficos (CA-023-10) — [Hecho] decidido: se usa (propietario, 2026-10-20)

[Hecho, P5, 2026-10-20] La Ayuda vigente dice, en «Highly recommended», para el gráfico de funciones y para cada captura: «Include alt text with each graphic asset. Alt text is important for screen-reader users» (≤ 140 caracteres, sin «foto de» ni «imagen de»). La spec 023 §6 decía lo contrario; **enmendada el 2026-10-20** por decisión del propietario. Propuesta de textos, para ajustar a las capturas reales en T-023-10 **[Suposición]** (`{appName}` es el nombre de la identidad; en el cuadro de Play Console va ya sustituido):

| Pieza | ES | EN |
|---|---|---|
| Gráfico de funciones | `{appName}`: una sola tarea a la vez, a pantalla completa. | `{appName}`: one task at a time, full screen. |
| Captura 1: la tarea actual con texto | La tarea actual con su texto a pantalla completa y el botón para completarla. | The current task with its text full screen and the button to complete it. |
| Captura 2: tarea con foto | Una tarea con una foto a pantalla completa y su texto encima. | A task with a full-screen photo and its text on top. |
| Captura 3: Todas mis tareas | El listado «Todas mis tareas», con las tareas en orden y la primera destacada. | The "All my tasks" list, with the tasks in order and the first one highlighted. |
| Captura 4: Ajustes con las notificaciones encendidas | Ajustes con el interruptor de notificaciones encendido y el aviso de privacidad. | Settings with the notifications switch on and the privacy notice. |

## 7. Requisitos de los gráficos que la Ayuda vigente añade a la spec (para T-023-08 y T-023-10)

[Hecho, P5, 2026-10-20] Coinciden con CA-023-10 (icono 512 × 512; gráfico de funciones 1024 × 500 sin transparencia; capturas con lados entre 320 y 3840 y largo ≤ el doble del corto; apps con ≥ 4 capturas de ≥ 1080 en 9:16 para ser elegibles a las secciones destacadas) **salvo estos puntos**:

1. **Las capturas también van «sin alfa»:** P5 pide «JPEG or 24-bit PNG (no alpha)» para las capturas, no solo para el gráfico de funciones. CA-023-10 solo lo dice del gráfico (T-023-08: `check.mjs` debería comprobarlo en las capturas y T-023-10 exportarlas sin canal alfa). **[Duda D-4b]**
2. **El icono de Play:** «32-bit PNG (with alpha)», 512 × 512, ≤ **1024 KB**. Comprobar el tamaño del `icon-512.png` de la 018 (T-023-08).
3. **Gráfico de funciones:** P5 recomienda no repetir el icono como marca principal, evitar el blanco, el negro y el gris oscuro puros como fondo (se confunden con el fondo de Play) y mantener lo importante hacia el centro, lejos de las zonas recortables. El `paper` de los tokens puede acabar cercano a «blanco puro»: T-023-10 lo revisa al ver el gráfico (**[Suposición]** no es un requisito, es una recomendación).
4. **Capturas:** «Edit excess elements in the notification bar … The battery, WiFi, and cell service logos should be full» (coincide con CA-023-11); sin marcos de dispositivo; texto superpuesto (si lo hay) ≤ 20 % de la imagen; nada de «Best», «#1», «Top», «New», «Free», «Discount» ni llamadas a la acción («Download now»).
5. **Descripción breve:** ≤ 80 caracteres, sin saltos de línea, sin emojis, «Only use periods at the end of sentences if your short description contains multiple sentences», sin mayúsculas de énfasis (P5 y P6). El borrador de la spec («Una sola tarea a la vez, a pantalla completa. Sin cuentas ni analítica.») cumple.
6. **Metadatos:** P6 prohíbe en el título, el icono y el nombre del desarrollador «emojis, emoticons, or repeated special characters» y «ALL CAPS unless part of your brand name», comparaciones de datos entre apps y testimonios anónimos.

## 8. Para la primera subida (F6): lo que la Ayuda vigente añade (para T-023-12)

[Hecho, 2026-10-20] Para `docs/PLAN.md` (fila de F6) y `/release-checklist`, **además** de la lista cerrada de CA-023-23:

1. **Prueba cerrada obligatoria con una cuenta personal** (P7): «Developers with personal accounts created after November 13, 2023, must run a closed test for their app with a minimum of **12 testers** who have been opted in continuously for at least **14 days**» antes de poder pedir el acceso a producción. **[Suposición]** Se aplica si la cuenta de Play se crea (PD-3) después de esa fecha, lo que es seguro hoy. **Esto choca con la decisión del propietario («de momento no hay testers»):** la primera subida a producción no podrá hacerse sin ellos.
2. **Datos que Google muestra de la cuenta personal** (P9): nombre legal, país y correo del desarrollador; la dirección completa si se monetiza y, «in certain regions», información adicional como el teléfono o la dirección completa. Relacionado con la nota 7 de la política (cuenta personal puede exigir mostrar dirección y teléfono).
3. **Datos de contacto de la ficha** (P8): el correo es obligatorio y público; la web y el teléfono, opcionales.
4. **Declaraciones de «App content»** que se contestan en F6: privacidad, anuncios, acceso a la app, público objetivo, clasificación de contenido, noticias, COVID-19, Data safety (con el bloque de borrado), funciones financieras, salud, gubernamentales y, al subir el AAB, permisos (§2).
5. **Si cambia algo del contenido de la app,** rehacer el cuestionario de clasificación (P3).

## 9. Decisiones del propietario (2026-10-20)

1. **D-1 y D-2:** [Hecho] **no se declara** (confirmado).
2. **D-4:** [Hecho] se enmienda la spec y se usan los textos de §6.
3. **§8, punto 1:** [Hecho] aceptada la prueba cerrada de 12 testers durante 14 días antes de producción; va a la lista de F6 (CA-023-23, T-023-12).
4. **Gratis:** [Hecho] confirmada.
