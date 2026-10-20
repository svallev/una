# Spec 023: Privacidad y ficha de tienda

- **Estado:** **Aprobada** (propietario, 2026-10-19, al responder Q-023-1 a 3: «1a, 2a, 3a»). Antes **Borrador** (2026-10-19; revisión 1 del `spec-reviewer` aplicada el mismo día: 2 bloqueantes y 18 importantes).
- **Contexto del propietario (2026-10-19):** es un proyecto personal de aprendizaje del ciclo completo hasta la publicación; **de momento no se sube a Play ni se da a testers**. La 023 deja todo listo y comprobado; F6 se hará cuando el propietario lo decida.
- **Fase:** F5 Endurecimiento (troceado de F5, D30). Última de las specs 020–023, después de la auditoría 022 (Implementada el 2026-10-19). Antes de la spec de corrección 024 y de F6. Tamaño **L** (política, Data Safety, ficha, cuatro páginas, CI, H-2, tamaño y capturas).
- **Reglas de producto:** ninguna R nueva. Sirve a **P3** (local; las webs necesitan conexión, nota del ADR-0026), **P4** (privacidad por defecto: objetivo «Data Not Collected»), **P5**, **P7** (el nombre sale de la identidad), **P11** y **P12** (identidad visual también en las webs).
- **Pantallas del prototipo:** **sin diseño**. El prototipo no tiene las webs de Política de privacidad, Licencias de terceros y Ayuda (`docs/design/screen-map.md`, «Elementos sin pantalla»), ni el gráfico de funciones ni las capturas de la tienda. Se hacen con los tokens y las fuentes de la app y se registran como **DEV-58** (`docs/design/prototype-deviations.md`).
- **Decisiones y ADR relacionados:**
  - **Troceado de F5** (propietario, 2026-10-01; D30): «023 privacidad y ficha de tienda (PD-2, PD-3, PD-9; más notificaciones y ajustes en la política y en Data Safety)».
  - **Alcance del propietario (2026-10-19, respuestas a esta spec):**
    - **1b** — **PD-2 sigue abierta:** la 023 deja todo listo con las direcciones marcador; fijar el dominio y el *package name* es un paso de **F6**, antes de la primera subida. La 023 no toca `applicationId` ni las direcciones de `app/identity.yaml`.
    - **2b** — **PD-3:** cuenta **personal** de Google Play, **por crear**. El nombre del responsable y el correo de contacto quedan como huecos **[Pendiente, F6, propietario]**.
    - **3a** — Las tres webs viven en **`landing/`** del repositorio, como web **estática** en un proyecto de Vercel aparte (ADR-0009), sin scripts de terceros ni analítica. La 023 escribe el contenido de las tres, la Ayuda incluida.
    - **4a** — Además de la política, Data Safety y la ficha, entran: el **referente** `android-app://` (015 §10), **`ACCESS_LOCAL_NETWORK`** (H-8 de los spikes), **H-2** de la 020 (ruta de compilación en `libapp.so`), el **presupuesto de tamaño** y **la política sin crear antes una tarea** (CL-015-4). **C-4** y **`actionlint`** se quedan en F6 (configuración del repositorio). **C-5** de la 020 (el paso del *wrapper* de Gradle en el trabajo de publicación, «cuando se toque el trabajo») entra, porque la 023 toca el trabajo (CA-023-24). La **revisión legal** (licencias en la web, ADR-0026, y la política) la hace el propietario: la 023 solo la registra como punto bloqueante.
  - **PD-9** (Safe Browsing frente a Data Safety) y **H-1** de la 020 (consulta de autorrelleno de la WebView, aceptada, `threat-model.md` §4 y §7): esta spec las **cierra** con una decisión y su fuente.
  - **ADR-0004** (copias de seguridad), **ADR-0009** (monorepo y `landing/`), **ADR-0010** (Vercel), **ADR-0016/0018** (tarea web), **ADR-0025** (notificaciones locales), **ADR-0026** (licencias en la web), **P-012-2** (una sola dirección por web para ES y EN), **CA-012-05** y **CA-020-09 a 12** (puerta de publicación).
  - **Decisión del propietario (2026-10-19, `docs/PLAN.md`, notificaciones):** la Ayuda **no** explica «Restringir» de HyperOS, la parada forzada, el retraso con la pantalla apagada ni los arranques automáticos (CL-019-10 y CL-019-25; H-022-06 y 07, «No hace falta indicarlo en la ayuda»).
  - **[Suposición]** Sin ADR nuevo ni cambio de la constitución (sigue la 1.10): la 023 confirma «Data Not Collected». **Si la revisión de PD-9 concluye que hay algo que declarar**, se para y se pregunta (CL-023-1): sería una excepción a P4 con su ADR.
- **Dependencias:** 012, 015 (las tres filas de web de Ajustes y sus direcciones), 018 (icono de Play 512), 019 (notificaciones en la política), 020 (trabajo de publicación y puerta), 022 (auditoría cerrada). **Sin esquema de BD ni permisos nuevos.** **[Suposición]** Sin dependencias nuevas en la app; la web no usa paquetes de terceros en el navegador (CA-023-14) y se construye sin dependencias de terceros (CA-023-13).
- **Nomenclatura** (se añade al glosario):
  - **Ficha de tienda** (*store listing*): lo que Google Play enseña de la app: nombre, descripción breve y completa, icono, gráfico de funciones, capturas, categoría y contacto.
  - **Gráfico de funciones** (*feature graphic*): la imagen de 1024 × 500 que Play pone en la cabecera de la ficha.
  - **Seguridad de los datos** (*Data safety*): el formulario de Play Console en el que el desarrollador declara qué datos recoge y comparte la app; Play lo enseña en la ficha.
  - **Declaración de Data Safety:** el documento del repositorio con cada pregunta del formulario, su respuesta y por qué (`store/google-play/data-safety.md`). Es la fuente desde la que se rellena Play Console.
  - **Clasificación de contenido** (*content rating*): el cuestionario de IARC en Play Console que da la edad recomendada por país.
  - **Público objetivo** (*target audience*): los grupos de edad para los que está pensada la app, que se declaran en Play Console.
  - **Webs de la app:** las tres páginas que abren las filas de Ajustes: **Política de privacidad**, **Licencias de terceros** y **Ayuda**. Una dirección cada una, con el español y el inglés en la misma página.
  - **Huecos de identidad:** los datos que solo existen en F6 (nombre del responsable, correo de contacto, dominio, fecha de publicación): se escriben entre corchetes y la puerta impide publicar con ellos.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que todo lo que la app y su ficha dicen sobre los datos sea **verdad, coherente y comprobable**: una política de privacidad sin suposiciones, una declaración de Data Safety que diga «no se recogen ni se comparten datos» con la razón de cada respuesta, una ficha de tienda en español y en inglés lista para Play y las tres webs de la app publicables, con la identidad de la app y sin terceros. Al terminar, para la primera subida (F6) solo faltan los datos que dependen del dominio y de la cuenta de Play.

## 2. Historias de usuario

- **HU-023-1** Como persona que va a instalar la app, quiero que la ficha de Play me diga en pocas palabras qué hace y que **no recoge datos**, para decidir si confío en ella.
- **HU-023-2** Como usuario, quiero leer una **política de privacidad clara**, en mi idioma, que diga exactamente lo que pasa con lo que guardo (también con la tarea web, las notificaciones y las copias de seguridad), sin letra pequeña.
- **HU-023-3** Como usuario, quiero una **Ayuda** que me explique cómo se usa la app (completar, eliminar y deshacer, reordenar, adjuntos, notificaciones, idioma) sin tener que adivinar los gestos.
- **HU-023-4** Como usuario, quiero poder **leer la política de privacidad aunque todavía no tenga ninguna tarea**.
- **HU-023-5** Como usuario, quiero que las **webs de la app no me rastreen**: sin cookies, sin analítica, sin servicios de terceros.
- **HU-023-6** Como usuario con lector de pantalla o con el texto grande, quiero que las webs se lean bien.
- **HU-023-7** Como propietario, quiero que lo que declaro en Play **no contradiga** la política ni el manifiesto de la app, y que una comprobación me avise si algún día dejan de coincidir.
- **HU-023-8** Como propietario, quiero que lo que se publica **no lleve rutas de mi Mac** y que la app **no crezca** sin que lo vea.
- **HU-023-9** Como propietario, quiero que las webs de la app y lo que falta para la primera subida estén **listos y comprobados en el repositorio**, para que en F6 solo tenga que poner el dominio, la cuenta y mis datos.

## 3. Criterios de aceptación

**Trazabilidad HU → CA:** HU-023-1 → CA-023-09 a 12; HU-023-2 → CA-023-01 a 04; HU-023-3 → CA-023-17; HU-023-4 → CA-023-21; HU-023-5 → CA-023-14; HU-023-6 → CA-023-15; HU-023-7 → CA-023-05 a 08; HU-023-8 → CA-023-19, 20 y 24; HU-023-9 → CA-023-13, 16, 18, 22 y 23.

Cada CA dice cómo se verifica: con un **test o una comprobación** que corre en la CI sin dispositivo, con una **casilla** de dispositivo o de navegador (tabla C-023-n del §10) o con una **revisión** del propietario anotada en el documento.

### 3.1 Política de privacidad

- **CA-023-01** · Sin suposiciones
  - **Dado** `docs/legal/privacy-policy.md`, en español y en inglés
  - **Cuando** se pasa la comprobación de la política
  - **Entonces** no queda **ninguna** marca `[Suposición]`/`[Assumption]` ni `[Pendiente]`/`[Pending]` en la parte que se publica: cada una se ha resuelto (verificada en la app, en el código o en la guía de Play vigente, con su fuente en las notas de revisión) o se ha quitado la frase. Los **únicos** huecos que quedan son los de identidad, de una lista cerrada: `[RESPONSABLE]`/`[CONTROLLER]`, `[CONTACTO]`/`[CONTACT]`, `[FECHA]`/`[DATE]` y `[WEB]`/`[WEBSITE]` (la dirección de la web, si la política la nombra). El nombre de la app **deja de ser un hueco**: sale de `app/identity.yaml` (P7), así que `[NOMBRE DE LA APP]`/`[APP NAME]` desaparece de la lista que admite la puerta.
    - Los huecos de la lista son **avisos de identidad**: en el modo testers el trabajo de publicación los lista y sigue en verde; en el modo estricto falla (como hoy, CA-020-09 a 12).
    - Cualquier **otro texto entre corchetes** (salvo el texto de un enlace, `[texto](dirección)`) y cualquier marca **fallan en los dos modos**.
    - **Enmienda de la 020** (se anota en su spec al cerrar): CA-020-03 b) y CA-020-11 cambian la lista de huecos admitidos.
  - **Verificable:** test de la comprobación (casos con una marca, con un hueco fuera de la lista, con un enlace, con `[NOMBRE DE LA APP]` y sin nada). El modo estricto **sigue fallando** por los huecos de identidad hasta F6: es lo esperado.
- **CA-023-02** · Cubre todo lo que hace la app
  - **Dado** la política
  - **Cuando** se revisa contra la app de `main`
  - **Entonces** dice, en ES y en EN, con hechos y sin suposiciones:
    - las **notificaciones** (ya están; se comprueba que siguen siendo verdad);
    - **qué ajustes viajan en la copia de seguridad** de Android: idioma, pantalla siempre activa, bloquear zoom y los dos de las notificaciones (encendidas y cuántas al día; CA-019-05, CL-019-9); **no** viaja la copia aparte que la app guarda para reprogramar los avisos tras reiniciar (ADR-0004, ADR-0025);
    - que, **al abrir las webs de la app** desde Ajustes, el navegador del sistema se conecta a ellas y puede enviarles que vienen de la app (el **referente** `android-app://<paquete>`), y que **la app no envía nada** (015 §10);
    - la **tarea web**: Safe Browsing (la hace la WebView del sistema con Google), la **consulta de autorrelleno** de la WebView a Google en páginas con formularios (H-1: la firma del formulario, no lo escrito; la app no la puede cortar) y el **residuo** del nombre del sitio en el espacio privado (CA-009-13), con esta redacción **[Suposición, se confirma al aprobar]**: «El sistema puede guardar en el espacio privado de la app el nombre de los sitios que has abierto como tarea web; no entra en las copias de seguridad y se borra al desinstalar la app»;
    - los **flujos que inicia el usuario hacia otras apps**: «Abrir en el navegador» de la tarea web (009) y los enlaces `https`, `mailto:` y `tel:` de un PDF, tras confirmarlos (008): lo que se envía lo decide la otra app;
    - que la app **no se conecta a la red local** por sí misma aunque Android 17 se lo permita a toda app con internet, y que una página web sí puede hacerlo como en un navegador (H-8; CA-023-07);
    - los **PDF** se guardan con sus metadatos;
    - que **no está dirigida a menores de 16 años** (Q-023-2 a) y la parte de **«Cambios en esta política»** sin el ejemplo de las notificaciones (ya existen);
    - una sección **«Esta web»**: qué ve el alojamiento de las webs de la app (la dirección IP y los datos técnicos de la visita, en sus registros), cuánto tiempo los guarda, que las webs no usan cookies ni analítica (CA-023-14) y que **de esos registros el responsable es el desarrollador**; «En pocas palabras» y «Tus derechos» lo matizan (la app no recoge datos; las webs, solo los registros del alojamiento).
  - **Verificable:** revisión con la lista de arriba anotada en las notas de revisión de la política (cada punto con su fuente), y `spec-reviewer` y `security-reviewer` al cerrar.
- **CA-023-03** · Español e inglés dicen lo mismo
  - **Dado** las dos versiones de la política
  - **Cuando** se pasa la comprobación
  - **Entonces** tienen **las mismas secciones, en el mismo orden**, y el mismo número de puntos en cada una; y una revisión confirma que cada punto dice lo mismo.
  - **Verificable:** test de estructura (encabezados y viñetas por sección) y revisión.
- **CA-023-04** · Una sola fuente para la política
  - **Dado** `docs/legal/privacy-policy.md` y la web de la política en `landing/`
  - **Cuando** se pasa la comprobación en la CI
  - **Entonces** el texto publicado es **el de `docs/legal/privacy-policy.md`** (sin el aviso de borrador ni las notas de revisión), con el nombre de la app de `app/identity.yaml`; si alguien cambia uno sin el otro, la comprobación **falla**. La «última actualización» es el hueco `[FECHA]` hasta F6 (CA-023-01), y después la fecha que ponga el propietario al publicar cada versión del texto.
  - **Verificable:** test que compara las dos (caso igual y caso con una frase cambiada).

### 3.2 Seguridad de los datos (Data Safety) y coherencia

- **CA-023-05** · Declaración de Data Safety completa
  - **Dado** `store/google-play/data-safety.md`
  - **Cuando** se revisa
  - **Entonces** recoge **cada pregunta** del formulario de Data Safety vigente con su respuesta, en el orden de Play Console, y la respuesta global es **«La app no recoge ni comparte datos de los usuarios»**. Para **cada flujo** que sale del móvil o podría parecerlo hay una fila con la decisión (se declara / no se declara), el porqué y la **fuente** (página de la Ayuda de Play Console con su fecha de consulta): la página de la **tarea web** (la carga el usuario), **Safe Browsing**, la **consulta de autorrelleno** (H-1), las **notificaciones locales** (sin red), la **copia de seguridad** de Android (en la cuenta del usuario), las **estadísticas de fallos** de Android vitals (si el usuario comparte diagnósticos), el **referente** al abrir las webs, **«Abrir en el navegador»** de la tarea web, los **enlaces de un PDF** (`https`, `mailto:`, `tel:`), **`ACCESS_LOCAL_NETWORK`** y los permisos del manifiesto (`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`). Incluye una **tabla de permisos**: cada permiso, cómo lo nombra la política en ES y en EN y si está en la lista blanca del manifiesto (para CA-023-08).
  - **Verificable:** revisión del propietario anotada en el documento; el test de CA-023-08 comprueba la tabla de permisos.
- **CA-023-06** · PD-9 cerrada
  - **Dado** la declaración de CA-023-05
  - **Cuando** termina la 023
  - **Entonces** **PD-9** consta como **resuelta** en `docs/PLAN.md` con la decisión y su fuente, y `threat-model.md` §4 y §7 y la nota de PD-9 de la política dicen lo mismo. Si la decisión es «hay que declarar algo», se aplica CL-023-1 antes de seguir.
  - **Verificable:** revisión (`spec-reviewer` al cerrar).
- **CA-023-07** · Red local
  - **Dado** que Android 17 concede `ACCESS_LOCAL_NETWORK` a las apps con `INTERNET` sin que lo declaren (H-8)
  - **Cuando** se revisa la app
  - **Entonces** la app **no lo declara** (el trabajo de publicación ya falla si aparece en el manifiesto) y **no se conecta a la red local** por sí misma: al crear una tarea web rechaza las direcciones privadas o locales (009) y bloquea la redirección del servidor hacia ellas (CL-009-1). Lo único que puede llegar a la red local es lo que hace la página, como en un navegador: sus **marcos internos** y los **nombres de dominio que resuelven a una IP privada** (`threat-model.md` §7). La declaración de Data Safety, la política y `threat-model.md` lo dicen así.
  - **Verificable:** la comprobación de permisos que ya existe (`permissions` del trabajo de publicación) y revisión de los tres documentos.
- **CA-023-08** · Permisos coherentes
  - **Dado** la tabla de permisos de la declaración de Data Safety (CA-023-05), la política y la lista blanca de permisos del manifiesto de *release*
  - **Cuando** se pasa la comprobación en la CI
  - **Entonces** cada permiso de la lista blanca está en la tabla, y el nombre que la tabla le da en ES y en EN aparece en la política; la tabla no tiene permisos de la app que no estén en la lista blanca, salvo los marcados como **del sistema, no declarados** (`ACCESS_LOCAL_NETWORK`). El permiso interno que Android añade a toda app para sus receptores no exportados no cuenta. Si se añade un permiso a la lista blanca sin la tabla y la política (o al revés), la comprobación **falla**.
  - **Verificable:** test (caso igual, caso con un permiso de más en cada lado y caso con `ACCESS_LOCAL_NETWORK` marcado). Al cerrar se quita `CAMERA` de `threat-model.md` §4 (la app no la pide).

### 3.3 Ficha de tienda

- **CA-023-09** · Textos de la ficha en ES y EN
  - **Dado** los textos de la ficha (`store/google-play/listing/es-ES/` y `en-US/`)
  - **Cuando** se pasa la comprobación
  - **Entonces** cada idioma tiene **nombre** (≤ 30 caracteres, igual a `displayName` de `app/identity.yaml`), **descripción breve** (≤ 80) y **descripción completa** (≤ 4000); sin huecos ni marcas, con el nombre siempre tomado de la identidad (ningún texto lleva el nombre escrito a mano), sin emojis en el nombre ni en la breve y sin superlativos ni comparaciones con otras apps (política de metadatos de Play). La descripción completa dice: una tarea a la vez a pantalla completa; foto, varias fotos, PDF o web; sin cuentas, sin servidor y sin analítica; **la tarea web necesita conexión**; las notificaciones son **opcionales**; español e inglés. **No promete** nada que la app no haga (sincronización, iOS, otros idiomas).
  - **Verificable:** test de longitudes, nombre y marcas; revisión del propietario de los textos (§7).
- **CA-023-10** · Gráficos de la ficha
  - **Dado** la carpeta `store/google-play/`
  - **Cuando** se pasa la comprobación
  - **Entonces** están el **icono** de 512 × 512 de la 018 (sin cambios), un **gráfico de funciones** de 1024 × 500, PNG o JPEG, sin transparencia, y **4 capturas de móvil por idioma** (ES y EN), PNG o JPEG, verticales, de **1080 × 1920** (9:16: el emulador de API 37 da 1080 × 2400, que pasa del 2:1 que admite Play), con los lados entre 320 y 3840 px y el largo como mucho el doble del corto. El gráfico de funciones lleva el nombre de la identidad. Las capturas (y el gráfico) son PNG de 24 bits **sin canal alfa** (P5; enmienda del 2026-10-20) y son, en este orden: la **tarea actual** con texto, una **tarea con foto**, **Todas mis tareas** y **Ajustes** con las notificaciones encendidas **[Suposición]**.
  - **Verificable:** test de tamaños, formato y número; casilla C-023-1 del contenido.
- **CA-023-11** · Capturas con datos ficticios
  - **Dado** las capturas de CA-023-10
  - **Cuando** se revisan
  - **Entonces** se hicieron en el **emulador** a **1080 × 1920** (nunca en el Xiaomi del propietario: puede salir su WhatsApp), con una compilación *release* de `main` en el idioma de cada juego, con **datos ficticios** (textos de ejemplo y fotos propias del repositorio o generadas, sin personas reconocibles ni marcas de terceros), con la **barra de estado limpia** (hora fija, batería llena, sin notificaciones) y el sistema en claro. Ninguna enseña una página web de un tercero.
  - **Verificable:** casilla C-023-1 (revisión del propietario de las 8 capturas).
- **CA-023-12** · Respuestas de Play Console
  - **Dado** `store/google-play/play-console.md`
  - **Cuando** se revisa
  - **Entonces** recoge, con su porqué, las respuestas que pide Play Console fuera de la ficha: **idioma por defecto** de la ficha: español (es-ES) **[Suposición]**; **categoría** Productividad; **contiene anuncios:** no; **ID de publicidad:** no se usa; **acceso a la app:** todo sin iniciar sesión, con una nota para los revisores de dónde está la política (CA-023-21); **público objetivo:** 16–17 y 18 o más (Q-023-2 a); **cuestionario de clasificación de contenido** (IARC) pregunta a pregunta, incluida la de acceso a internet sin restricciones por la tarea web; **app de noticias, de salud, financiera, gubernamental:** no; **dispositivos:** solo móvil (D28, R-25, PD-11 aplazada) **[Suposición]**; **países:** todos **[Suposición]**; **política de privacidad:** la dirección de `privacyPolicyUrl`. Los datos de F6 (correo de contacto, web y dirección postal si Play la exige a una cuenta personal) quedan como huecos de identidad.
  - **Verificable:** revisión del propietario anotada en el documento.

### 3.4 Webs de la app

- **CA-023-13** · Tres páginas estáticas
  - **Dado** `landing/`
  - **Cuando** se construye la web
  - **Entonces** salen **tres páginas**, una por web de la app, en las rutas `/privacy`, `/licenses` y `/help` (las mismas que ya tienen las direcciones marcador de `app/identity.yaml`, así que en F6 solo cambia el dominio), **más** una página de inicio mínima con el nombre de la app y los enlaces a las tres. Cada página tiene **el español y el inglés en la misma dirección** (P-012-2), **siempre en ese orden**: primero el español y después el inglés, con un enlace al principio de la página que salta a la otra mitad **[Suposición]** (sin negociar el idioma: no hace falta servidor ni JavaScript). Funcionan **sin JavaScript**. El nombre de la app sale **siempre** de `app/identity.yaml` y una comprobación falla si aparece escrito a mano en `landing/`. La construcción **no usa dependencias de terceros** ni descarga nada; si alguna hiciera falta, cumple P11 y `threat-model.md` §5 (fijada con su *lockfile* y **sin telemetría**).
  - **Verificable:** test de la construcción (existen las cuatro páginas, cada una con sus dos idiomas y el enlace al otro; ningún nombre de la app escrito a mano) y casilla C-023-2.
- **CA-023-14** · Sin terceros ni rastreo
  - **Dado** las páginas construidas y la configuración del proyecto de Vercel en el repositorio
  - **Cuando** se pasa la comprobación en la CI
  - **Entonces** no hay **ningún recurso de otro origen** (scripts, hojas de estilo, fuentes, imágenes, iframes), **ninguna cookie**, **ninguna analítica** (ni la de Vercel) y **ningún script en línea**; las fuentes Archivo y Space Mono van **dentro** de la web, con su licencia OFL; y las respuestas llevan cabeceras de seguridad: política de contenido que solo admite el propio origen, sin incrustarse en otras webs, sin enviar el referente, HTTPS estricto y sin adivinar tipos.
  - **Verificable:** test sobre las páginas construidas y la configuración (cada regla con un caso que falla) y casilla C-023-2 (las cabeceras de una vista previa de Vercel, cuando el propietario la autorice; la cookie que pone la protección de las vistas previas de Vercel no es de la web y no cuenta).
- **CA-023-15** · Accesibles e idénticas a la app
  - **Dado** las páginas
  - **Cuando** se revisan
  - **Entonces** usan los **colores, fuentes y medidas de `design/tokens.json`** (sin valores sueltos, comprobado igual que en la app), con contraste AA; cada idioma está marcado con su idioma (para el lector); hay un encabezado principal por página y la estructura de encabezados no salta niveles; se leen al **200 %** de zoom y a **320 px** de ancho sin desplazamiento horizontal; los enlaces se distinguen sin depender del color y tienen foco visible; el texto sigue legible si el usuario aumenta el interlineado y el espaciado (WCAG 1.4.12); nada tapa el elemento con el foco (2.4.11); los enlaces tienen un objetivo de 24 × 24 o más o el espacio equivalente (2.5.8); y respetan «reducir movimiento» (no hay animaciones).
  - **Verificable:** test (tokens, idioma marcado, encabezados) y casilla C-023-3 (TalkBack con Chrome en el emulador y zoom al 200 %); `a11y-reviewer` al cerrar.
- **CA-023-16** · Licencias de terceros
  - **Dado** la web de licencias
  - **Cuando** se construye
  - **Entonces** publica el **archivo de avisos** de una versión (el `third-party-notices.txt` que emite `tools/check-licenses.sh` en el trabajo de publicación, que es un artefacto que caduca) y dice **de qué versión** es. El archivo **se copia a `landing/` en una PR** (no se descarga al construir) con la versión en su cabecera; mientras no haya ninguna versión publicada, es el de una ejecución en modo testers sobre `main`, con esa aclaración. Explica, en ES y EN, que los textos de las licencias van también **dentro de la app** (ADR-0026).
  - **Verificable:** test de la construcción (con un archivo de avisos de prueba: con versión, sin versión y sin archivo, que falla). Que la web publique el de la versión que se entrega sigue siendo un punto a mano de `/release-checklist` (no cambia).
- **CA-023-17** · Ayuda
  - **Dado** la web de Ayuda
  - **Cuando** se revisa
  - **Entonces** explica, en ES y EN, con los textos y los nombres de la app (glosario) y una sección por tema: **qué es la tarea actual** y cómo se completa (mantener pulsado); **crear** una tarea y elegir dónde va; **editar**; **eliminar y deshacer**; **Todas mis tareas** y **reordenar**; los **adjuntos** (foto, varias fotos, PDF, web, y que la web necesita conexión); **Ajustes** (idioma, notificaciones con su aviso de privacidad, pantalla siempre activa, bloquear zoom); que la app **oculta su contenido en «Recientes»**; las **copias de seguridad** (qué se recupera y qué no); cómo **ampliar** (pellizco y la lupa del sistema) y cómo se usa **con TalkBack** (las acciones que sustituyen a cada gesto); y **cómo contactar** (hueco de identidad). **No** explica «Restringir» de HyperOS, la parada forzada, el retraso con la pantalla apagada ni los arranques automáticos (propietario, 2026-10-19).
  - **Verificable:** revisión contra las specs implementadas (cada sección se puede rastrear hasta su spec) y del propietario. El texto se redacta en la implementación y lo aprueba el propietario, como la descripción de la ficha.
- **CA-023-18** · La web en la CI, sin publicar sola
  - **Dado** un cambio en `landing/` **o en algo de lo que depende la web** (`docs/legal/privacy-policy.md`, `app/identity.yaml`, `design/tokens.json`, las ARB de la app o `store/google-play/data-safety.md`)
  - **Cuando** corre la CI
  - **Entonces** se construye y se comprueba la web (CA-023-04, 08, 13 a 16) **sin** correr los trabajos de la app; y un cambio en otras partes de `app/` no construye la web (ADR-0009). **Nada se despliega** desde la CI ni desde una sesión de Claude Code sin la confirmación del propietario; el proyecto de Vercel y el dominio se crean en F6.
  - **Verificable:** test del workflow como el de la 020 (cada ruta de la lista dispara la web; otra de `app/` no).

### 3.5 Lo que se publica

- **CA-023-19** · Sin rutas de la máquina de compilación (H-2)
  - **Dado** un APK o AAB que comprueba el trabajo de publicación
  - **Cuando** **cualquier archivo** de dentro (bibliotecas nativas, código, recursos) contiene una **ruta absoluta de una carpeta personal**: `/Users/<usuario>/…` o `/home/<usuario>/…` con un usuario distinto de `runner`
  - **Entonces** el trabajo **falla** en los dos modos con el archivo y la ruta. Todo lo que cuelga de `/home/runner/` (el *runner* de GitHub: el repositorio, la caché de paquetes y el SDK) se admite y queda anotado como **residual aceptado** de Flutter en `threat-model.md` §5.
  - **Y** en una entrega a testers, que se compila en el Mac del propietario (CA-020-06), **se acepta** la ruta de la carpeta del proyecto (Q-023-3 a): se anota en `/release-checklist` y en las notas de la beta; lo que se publique en Play sale siempre del trabajo.
  - **Verificable:** test de la comprobación (archivo con `/Users/x/…`, con `/home/alguien/…`, con `/home/runner/work/…`, con `/home/runner/.pub-cache/…` y sin rutas).
- **CA-023-20** · Presupuesto de tamaño
  - **Dado** los APK de *release* por arquitectura que compila el trabajo de publicación
  - **Cuando** se comprueban
  - **Entonces** el presupuesto es de **20 MB comprimidos** por arquitectura **[Suposición]**: el trabajo **falla** si alguno mide **20 MB o más** (la misma regla que hoy con 25) y su resumen enseña el tamaño de cada uno. **[Suposición]** Lo último medido es 13,4 MB en arm64, antes de las specs 016 a 019; el plan lo vuelve a medir antes de fijar el límite y, si pasa de 17 MB, se pregunta al propietario. **Enmienda de la 020:** CA-020-02, punto 7 (< 25 MB) pasa a < 20 MB; se anota en su spec y en `docs/architecture.md` al cerrar. El presupuesto queda en `docs/PLAN.md` (riesgos).
  - **Verificable:** test de la comprobación de tamaño con el nuevo límite (casos por debajo, en 20 MB exactos, que falla, y por encima).

### 3.6 La política sin tareas

- **CA-023-21** · Llegar a la política sin crear una tarea
  - **Dado** la app **sin ninguna tarea** («Todo hecho.» o la bienvenida)
  - **Cuando** un usuario o un revisor de Play busca la política de privacidad
  - **Entonces** la app **no cambia** (Q-023-1 a; se mantiene lo aceptado en la 015, CL-015-4): la política está **dentro de la app** (Ajustes → Política de privacidad, tras crear una tarea) y **en la ficha**; `play-console.md` (acceso a la app) dice a los revisores cómo llegar: crear una tarea → menú → Ajustes → Política de privacidad.
  - **Verificable:** revisión de `play-console.md`.

### 3.7 Cierre y puerta

- **CA-023-22** · Revisión legal registrada
  - **Dado** `/release-checklist` y `docs/PLAN.md`
  - **Cuando** termina la 023
  - **Entonces** la **revisión legal** (de la política **y** de las licencias en la web, ADR-0026) es un **punto bloqueante** de `/release-checklist` antes de la primera subida a Play, con dónde se anota el resultado; la 023 **no** la hace ni la da por hecha.
  - **Verificable:** revisión del diff de la skill y de `docs/PLAN.md`.
- **CA-023-23** · Lista de lo que falta para la primera subida (F6)
  - **Dado** lo que la 023 deja pendiente por PD-2 y PD-3
  - **Cuando** termina la 023
  - **Entonces** la fila de F6 de `docs/PLAN.md` y `/release-checklist` tienen la **lista cerrada** de lo que falta para la primera subida y de dónde se rellena cada cosa: dominio y *package name* (PD-2); las tres direcciones en `app/identity.yaml` y en la ficha; los huecos de identidad de la política, la Ayuda y `play-console.md`; crear la cuenta personal de Play (PD-3) y el proyecto de Vercel con el dominio; copiar la declaración de Data Safety y las respuestas a Play Console y comprobar que coinciden; la revisión legal (CA-023-22); C-4 y `actionlint`; y lo que la fila de F6 ya tenía (la huella pública del certificado de subida y la firma del AAB en el trabajo). Ninguna otra marca `[Pendiente]` de la 023 queda fuera de esa lista.
  - **Verificable:** revisión (`spec-reviewer` al cerrar).

- **CA-023-24** · El *wrapper* de Gradle en el trabajo de publicación (C-5 de la 020)
  - **Dado** el trabajo de publicación
  - **Cuando** corre, en cualquiera de los dos modos
  - **Entonces** comprueba el *wrapper* de Gradle igual que la CI de las PR (CA-020-14) y falla si no pasa.
  - **Verificable:** test del workflow (el paso existe y su fallo para el trabajo).

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-023-1 | La guía vigente de Play dice que algo (por ejemplo, la consulta de autorrelleno o Safe Browsing desde el UID de la app) **sí** se declara | **Se para y se pregunta** al propietario antes de cambiar la declaración: declarar algo rompe el objetivo de P4 y necesita un ADR. No se cambia en silencio ni la declaración ni la política. |
| CL-023-2 | La guía de Play es ambigua o no habla del caso | Se decide la respuesta más **conservadora que siga siendo verdad**, se anota la duda con su fuente en la declaración y se pregunta al propietario al revisar. |
| CL-023-3 | Play Console pide una pregunta que no está en la declaración (el formulario cambió) | La declaración se pone al día **antes** de rellenarlo; `/release-checklist` lo pide (CA-023-23). |
| CL-023-4 | El navegador está en inglés u otro idioma (también con la app en español: la dirección es la misma, sin `?` ni `#`) | La página sale igual, primero en español; el enlace del principio lleva al inglés en un toque, y cada mitad está marcada con su idioma para el lector. |
| CL-023-5 | El navegador tiene el JavaScript desactivado | Todo se lee y el enlace funciona: la web no usa JavaScript. |
| CL-023-6 | Alguien abre una ruta que no existe en la web | Página de error propia, en los dos idiomas, con el enlace a la de inicio; sin terceros. |
| CL-023-7 | El texto de la política cambia después de publicar | Cambia `docs/legal/privacy-policy.md` y la fecha de «última actualización»; la web se reconstruye desde él (CA-023-04). Si cambia lo que la app hace con los datos, la política cambia **antes** que la app (lo dice la propia política). |
| CL-023-8 | Una dependencia nueva de la app añade un permiso o un flujo de red | Falla CA-023-08 (permisos) o la puerta de la 020; la declaración y la política se actualizan en la misma PR. |
| CL-023-9 | Cambia el nombre de la app (`displayName`) | La ficha, la política y las webs lo toman de la identidad (no hay nombre escrito a mano que buscar, CA-023-09 y 13). Se rehacen el **gráfico de funciones** y las capturas en las que se vea. |
| CL-023-10 | Una captura enseña una notificación, la hora real o datos del propietario | No vale: se repite en el emulador (CA-023-11). |
| CL-023-11 | Aún no hay versión publicada al construir la web de licencias | CA-023-16: el archivo de la última compilación de `main`, diciendo que lo es. |
| CL-023-12 | Un archivo de un tercero (por ejemplo, PDFium) lleva una ruta de una carpeta personal de quien lo compiló | CA-023-19 falla igual (la regla no distingue de quién es). Se anota el caso y **se pregunta al propietario** antes de admitir esa ruta concreta; nunca se amplía la regla en general. |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Web sin conexión | El usuario toca una fila de web de Ajustes en modo avión | Lo que ya hace la app y el navegador (015): la app no cambia; el navegador enseña su propio error. |
| Sin navegador | No hay ninguna app que abra la web | El aviso de CA-015-12b, sin cambios. |
| Ruta inexistente | CL-023-6 | Página de error de la web, en ES y EN. |
| Licencias sin versión | CL-023-11 | La web de licencias con la aclaración de que es la última compilación. |

## 6. Accesibilidad

- **Webs:** estructura con encabezados (uno principal por página), idioma marcado en cada mitad, enlace para saltar al otro idioma al principio, foco visible, contraste AA desde los tokens, sin animaciones, legible al 200 % y a 320 px (CA-023-15; WCAG 2.2 AA, 1.4.4, 1.4.10, 1.4.12, 2.4.7, 2.4.11, 2.5.8, 3.1.1 y 3.1.2). Se comprueban con TalkBack y Chrome en el emulador (C-023-3).
- **Ayuda:** explica la **alternativa a cada gesto** (mantener pulsado, swipe del carrusel, pellizco, arrastrar en el listado) con las acciones del lector y la lupa del sistema (CA-023-17).
- **Capturas y gráfico de funciones:** son imágenes de la tienda. La Ayuda vigente de Play (P5, consultada el 2026-10-20) recomienda un **texto alternativo** (≤ 140 caracteres, sin «foto de» ni «imagen de») para el gráfico y cada captura: se escribe en `store/google-play/play-console.md` §6 y se pega en Play Console en F6. La descripción completa dice lo mismo en texto (CA-023-09). *Enmienda del 2026-10-20 (propietario, al revisar T-023-04): antes decía que Play no admite texto alternativo.*
- **App:** sin cambios (Q-023-1 a).

## 7. Textos (ES / EN)

**En la app:** ninguno (Q-023-1 a).

**Ficha de tienda** (no son ARB; viven en `store/google-play/listing/<idioma>/`). Borradores para la revisión del propietario; el nombre sale de la identidad:

| Clave | ES | EN | Notas |
|---|---|---|---|
| `storeTitle` | `{appName}` | `{appName}` | ≤ 30; hoy «Una» (sin punto; el logotipo «una.» no es el nombre) |
| `storeShortDescription` | Una sola tarea a la vez, a pantalla completa. Sin cuentas ni analítica. | One task at a time, full screen. No accounts, no tracking. | ≤ 80; no dice «sin conexión» porque la tarea web la necesita |
| `storeFullDescription` | Se redacta en la implementación con los puntos de CA-023-09 | Igual | ≤ 4000; revisión del propietario |

**Webs** (no son ARB; viven en `landing/`): los títulos de las páginas son los de las filas de Ajustes (`settingsPrivacy`, `settingsThirdPartyLicenses`, `settingsHelp`) y se comprueba que coinciden con las ARB. El contenido de la Ayuda se redacta en la implementación (CA-023-17). Nuevos:

| Clave | ES | EN | Notas |
|---|---|---|---|
| `webSwitchToEnglish` | — | Read in English | Al principio de la mitad en español; escrito en inglés y marcado como inglés |
| `webSwitchToSpanish` | Leer en español | — | Al principio de la mitad en inglés; escrito en español y marcado como español |
| `webHomeTitle` | `{appName}` | `{appName}` | Página de inicio |
| `webHomeIntro` | Una sola tarea a la vez. Aquí están la política de privacidad, las licencias de terceros y la ayuda de la app. | One task at a time. Here are the app's privacy policy, third-party licences and help. | Página de inicio |
| `webPageTitle` | {página} · {appName} | {page} · {appName} | Título de cada página en el navegador |
| `webNotFoundBody` | Puede que la dirección esté mal escrita. | The address may be mistyped. | CL-023-6 |
| `webContact` | Contacto: [CONTACTO] | Contact: [CONTACT] | Pie de todas las páginas; hueco de identidad hasta F6 |
| `webLastUpdated` | Última actualización: {fecha} | Last updated: {date} | Fecha en formato largo de cada idioma |
| `webNotFoundTitle` | Esta página no existe. | This page doesn't exist. | CL-023-6 |
| `webBackHome` | Volver al inicio | Back to home | |
| `webLicensesVersion` | Avisos de la versión {versión} | Notices for version {version} | CA-023-16 |
| `webLicensesLatestBuild` | Aún no hay ninguna versión publicada: estos son los avisos de la última compilación. | No version has been published yet: these are the notices of the latest build. | CL-023-11 |
| `webLicensesInApp` | Los textos completos de las licencias también van dentro de la app. | The full licence texts are also included in the app. | ADR-0026 |

## 8. Fuera de alcance

- **PD-2** (dominio y *package name*), crear la **cuenta de Play** (PD-3), el **proyecto de Vercel** y el **dominio**, rellenar los **huecos de identidad**, subir la ficha a Play Console y cualquier despliegue: **F6** (CA-023-23).
- La **revisión legal** misma (CA-023-22): la hace el propietario.
- **C-4** y **`actionlint`** (configuración del repositorio, F6). **C-5** sí entra (CA-023-24).
- **iOS:** `PrivacyInfo.xcprivacy` y la ficha de App Store (F-iOS, PD-7).
- La **landing** de producto (ADR-0009): la página de inicio de CA-023-13 es mínima; una landing con las propuestas de valor es otra spec.
- Los hallazgos de la 022 (**024**) y lo que ya estaba asignado a la 024.
- Más idiomas en las webs o en la ficha (solo ES y EN, spec 010).
- Limitar la distribución en Play a móviles más allá de declararlo (PD-11, aplazada).

## 9. Preguntas abiertas

**Q-023-1 a 3 resueltas por el propietario el 2026-10-19 («1a, 2a, 3a»); CA-023-02, 12, 19 y 21 ya las aplican.**

- **Q-023-1 [Resuelta, propietario, 2026-10-19: a)] ¿Hace falta llegar a la política sin crear antes una tarea?** (CL-015-4, Q-015-5). La política de Datos de usuario de Google Play pide la política de privacidad **en la ficha y dentro de la app** **[Suposición: el plan lo comprueba en la página vigente de la Ayuda de Play y cita la fuente]**; hoy está en Ajustes, al que solo se llega con una tarea.
  - **a) (Recomendado)** No se cambia la app: la política está dentro de la app (Ajustes) y en la ficha, y `play-console.md` explica a los revisores cómo llegar. Mantiene lo que se aceptó en la 015 y no toca el prototipo.
  - **b)** Un enlace discreto «Política de privacidad» en la bienvenida y en «Todo hecho.» (desviación del prototipo, textos y tests).
- **Q-023-2 [Resuelta, propietario, 2026-10-19: a)] ¿Para qué edades es la app (público objetivo)?** La política dice hoy «no está dirigida a menores de 14 años», pero Play agrupa las edades en 13–15, 16–17 y 18+; declarar menores de 13 aplica la política de Familias, y 13–15 añade requisitos para adolescentes.
  - **a) (Recomendado)** **16 y más** (16–17 y 18+): la política dice «no está dirigida a menores de 16 años» y se evitan los requisitos de Familias y los de 13–15.
  - **b)** **18 y más:** lo más sencillo para Play; la política dice «menores de 18».
  - **c)** **13 y más:** llega a más gente, con más requisitos que revisar.
- **Q-023-3 [Resuelta, propietario, 2026-10-19: a); de momento no hay testers] ¿Qué se hace con la ruta de tu Mac en el APK de los testers?** (H-2). La entrega a testers se compila en tu Mac (CA-020-06) y Flutter mete en ella la ruta de la carpeta del proyecto, con tu usuario de macOS. El trabajo de publicación compila en GitHub y no tiene ese problema.
  - **a) (Recomendado)** Se acepta para los testers (son personas que conoces) y se anota en las notas de la beta y en `/release-checklist`; lo que se publica en Play sale siempre del trabajo (CA-023-19).
  - **b)** La entrega a testers pasa a ser el APK que compila el trabajo en modo testers (cambia CA-020-06: el trabajo sube el APK como artefacto).
  - **c)** Se compila en el Mac desde una carpeta sin el usuario (por ejemplo, `/tmp/una`), con una comprobación en `/release-checklist`.
- **[Suposición]** El gráfico de funciones lo hace Claude Code con los tokens y el icono (papel `paper`, la «u.» y el nombre), y lo aprueba el propietario en C-023-1; si prefiere diseñarlo en Claude Design, se sustituye el archivo.
- **[Suposición]** Se confirman al aprobar (si no se dice nada, se quedan así): presupuesto de 20 MB (CA-023-20); las 4 capturas elegidas (CA-023-10); idioma por defecto de la ficha español, «todos los países» y «solo móvil» (CA-023-12); español primero en las webs (CA-023-13); la redacción del residuo de la WebView (CA-023-02).

## 10. Casillas de dispositivo y de navegador

| ID | Qué | Entorno | CA |
|---|---|---|---|
| C-023-1 | Revisar las 8 capturas (1080 × 1920) y el gráfico de funciones: datos ficticios, barra limpia, idioma correcto, nada de terceros | Emulador de API 37 (capturas) y el propietario (revisión) | 10, 11 |
| C-023-2 | Las cuatro páginas y la de error en una vista previa local (y en Vercel solo con el «sí» del propietario): enlace al otro idioma, sin JavaScript, sin cookies propias, cabeceras | Chrome del Mac y del emulador | 13, 14 |
| C-023-3 | TalkBack con Chrome en el emulador: idioma de cada mitad, encabezados, enlaces; zoom al 200 % y 320 px | Emulador de API 37 | 15 |
| C-023-4 | Abrir las tres filas de Ajustes con las direcciones marcador sustituidas por las de la vista previa (solo en una compilación de pruebas, sin commit) y comprobar que llega a la página correcta | Emulador de API 37 | 13 |

## 11. Documentos que cambian al cerrar

`docs/legal/privacy-policy.md` (sin suposiciones, CA-023-01 a 03), `docs/PLAN.md` (PD-9 resuelta, PD-2/PD-3 con lo que falta, fila de F5 y de F6, riesgos con el presupuesto, trazabilidad), `docs/security/threat-model.md` (§4, §5 y §7: PD-9, H-2, `ACCESS_LOCAL_NETWORK`), `docs/security/checklist.md`, `.claude/skills/release-checklist/SKILL.md` (CA-023-22 y 23), `docs/glossary.md`, `docs/design/screen-map.md`, `docs/design/prototype-deviations.md` (DEV-58), `docs/architecture.md` (la web en `landing/` y el presupuesto de 20 MB), `specs/020-seguridad-y-puerta-de-publicacion/spec.md` (enmiendas de CA-020-02, 03 b) y 11) y `CLAUDE.md` (fase).
