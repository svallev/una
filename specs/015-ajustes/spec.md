# Spec 015: Ajustes

- **Estado:** **Borrador** (2026-10-05). Respondidas por el propietario todas las preguntas de §9 (Q-015-1 a 5). Los ADR-0023 y ADR-0026 están **Aceptados** por el propietario (2026-10-05; constitución 1.7). Falta la revisión y la aprobación de la spec
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Es la segunda de las specs 014–019.
- **Reglas de producto:** R15 (idioma, ahora elegible), R18 (Ajustes: pantalla siempre activa e información)
- **Pantallas del prototipo:** 16 "Ajustes" (`Ajustes.dc.html`) y 2 "Menú" (el enlace pasa a llamarse "Ajustes"). **Sin diseño:** la página de Idioma (se hace con los componentes existentes, P-16 del plan F4b). Ver `docs/design/screen-map.md`.
- **Decisiones y ADR relacionados:**
  - **R-26 y R-27** del plan (voz con el idioma elegido; licencias solo en la web).
  - **D22** (orden y valores por defecto de Ajustes), **D23** (idioma), **D26** (licencias de terceros en una web), **D27** (direcciones marcador) y **D10 enmendada** (pantalla siempre activa, sin límite); **D13 resuelta** (la Configuración completa es esta pantalla).
  - **ADR** (redactados con `/adr-new` y **Aceptados el 2026-10-05**, como el ADR-0021 de la 014): [ADR-0023](../../docs/adr/0023-idioma-elegido-en-la-app.md) *Idioma elegido en la app* (revisa el ADR-0020 y amplía la excepción a P6, constitución 1.7) y [ADR-0026](../../docs/adr/0026-licencias-de-terceros-en-la-web.md) *Licencias de terceros en la web* (sustituye a la parte de licencias de la 012). Esta spec dice **qué** debe cumplirse; el cómo está en los ADR.
  - **DEV-52** (nueva: Ajustes, Idioma y los enlaces a la web; sustituye a DEV-49 y a DEV-05).
  - ADR-0020 (voz del sistema en los anuncios), ADR-0018 (los enlaces no se siguen dentro de la app).
- **Dependencias:** 005 (menú), 007–009 (pantalla encendida con adjuntos), 010 (idioma), 011 (matriz de "Recientes"), 012 (la sustituye), 013, 014 (abrir Ajustes hace definitiva la eliminación pendiente). **Sin esquema de BD nuevo, sin permisos y sin dependencias nuevas** (CA-015-17).
- **Enmiendas a otras specs y documentos:** en el §10, que se aplican al aprobarla.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y en los ADR; las notas técnicas, solo en el anexo (no normativo).

## 1. Objetivo

Dar a la app su **pantalla de Ajustes** definitiva, sustituyendo a la temporal de la 012: elegir el **idioma**, decidir si la **pantalla se queda siempre encendida** con adjuntos, y llegar a la **política de privacidad**, las **licencias de terceros** y la **ayuda**, que viven en una web. Es la pantalla a la que se añadirán Bloquear zoom (017) y Notificaciones (019), y debe poder recibirlas sin rediseñarse.

## 2. Historias de usuario

- **HU-015-1** Como usuario con el móvil en un idioma y la app en otro, quiero elegir el idioma de la app, para usarla en el que prefiero sin cambiar el del móvil.
- **HU-015-2** Como usuario que mira una imagen, un PDF o una web, quiero poder mantener la pantalla encendida sin límite de tiempo, para consultarla sin que se apague. Y quiero que, por defecto, se apague como el resto de mi móvil.
- **HU-015-3** Como usuario, quiero poder leer la política de privacidad, las licencias de terceros y la ayuda, para saber qué hace la app, qué lleva dentro y cómo se usa.
- **HU-015-4** Como usuario de TalkBack, teclado o conmutadores, quiero llegar, leer, cambiar un ajuste y salir sin gestos que no pueda hacer (CA-015-20 a 22).

## 3. Criterios de aceptación

**Niveles y controles.** Hay dos niveles. Los dos se cierran hacia atrás; solo el primero tiene el icono de cerrar.

| Nivel | Qué es | Controles visibles | Atrás del sistema, gesto de atrás y Escape | Foco al llegar | Foco al volver |
|---|---|---|---|---|---|
| 1 | "Ajustes" | Icono **Cerrar ajustes** | Cierra y vuelve a la **tarea actual** (no al menú) | El título | El botón de menú de la tarea **[Suposición]** |
| 2 | "Idioma" (página de selección) | **Volver** | Vuelve al nivel 1 | El título | La fila "Idioma" del nivel 1 |

### La pantalla

- **CA-015-01 Abrir Ajustes**
  - **Dado** el menú abierto (CA-005-01) de cualquier tarea (solo texto, con imagen, con PDF o con web)
  - **Cuando** el usuario toca "Ajustes" (antes "Configuración y perfil")
  - **Entonces** el enlace es un **botón** con un objetivo táctil de **≥ 44 pt** y anillo de foco; el menú se **cierra** y Ajustes **sube desde abajo, a pantalla completa**, en menos de 220 ms; **al cerrarse baja** en menos de 170 ms; con "reducir movimiento", las dos cosas son instantáneas. Cambio respecto de la 012, que dejaba el menú debajo (CA-015-02).
- **CA-015-01b Estructura de la pantalla**
  - **Dado** Ajustes abierto
  - **Cuando** se mira
  - **Entonces** tiene, de arriba abajo (tablero 16): el título "Ajustes" con el icono de cerrar; **Idioma**; un separador de bloque; **Pantalla siempre activa** (con el subtítulo "Imágenes, documentos y web"); un separador de bloque; el encabezado **Información** (no se puede pulsar) con **Política de privacidad** y **Licencias de terceros** debajo; y **Ayuda**. Cada fila lleva a la izquierda su icono del tablero (decorativo para el lector); las de web, además, el icono de "abre una web" a la derecha. **Separadores:** 4 px a sangre entre bloques y 1 px entre filas de un mismo bloque. Con un ancho de 600 dp o más, la pantalla va centrada a 600 como el resto de la app (CL-001-7).
- **CA-015-01c Lo que aún no está**
  - **Dado** Ajustes en esta versión
  - **Cuando** se mira
  - **Entonces** **no** aparecen **Notificaciones** ni **Bloquear zoom**: llegan con las specs 019 y 017, en el sitio que les da D22 (Notificaciones bajo Idioma; Bloquear zoom bajo Pantalla siempre activa). La estructura de bloques y separadores las admite sin cambiar nada de lo demás.
- **CA-015-02 Cerrar y volver** *(cambio de comportamiento respecto de la 012)*
  - **Dado** cualquiera de los dos niveles
  - **Cuando** el usuario usa el control de la tabla, el atrás del sistema, el gesto de atrás o Escape con teclado
  - **Entonces** se sube **un nivel** y, desde el nivel 1, se **vuelve a la tarea actual** con el menú ya cerrado, como en el prototipo. El foco va donde dice la tabla. No hay otro gesto que cierre la pantalla.
- **CA-015-03 Pantalla siempre activa: el interruptor**
  - **Dado** Ajustes
  - **Cuando** se ve "Pantalla siempre activa"
  - **Entonces** es un **interruptor**, **apagado por defecto** (D22 y P-7), con el nombre y el subtítulo del prototipo, y toda la fila es el objetivo táctil (≥ 44 pt).
  - **Cuando** el usuario toca la fila **Entonces** el estado cambia y se guarda (CA-015-05, CA-015-25).
  - **El estado se distingue sin depender del color** (WCAG 1.4.1 y 1.4.11): cambia la **posición del pomo** y se intercambian los colores de pista y pomo (apagado: pista del papel y pomo amarillo; encendido: pista amarilla y pomo del papel). Contrastes mínimos, validados en `validate-tokens`: borde (3 px) frente al papel ≥ 3:1; pomo frente a su pista ≥ 3:1 en los dos estados; subtítulo ≥ 4,5:1. El amarillo encendido es un token nuevo (CA-015-19). Con "reducir movimiento", el pomo cambia de sitio sin animación (hoy 120–140 ms).
- **CA-015-04a Pantalla siempre activa: encendida** *(D10 enmendada, P-6 del plan F4b; cambia CA-007-12, CA-008-13 y CA-009-16)*
  - **Dado** el interruptor **encendido**
  - **Cuando** se ve la tarea actual con **imagen, PDF o web** (en vertical o en horizontal) con la app en primer plano
  - **Entonces** la pantalla **no se apaga ni se bloquea** por inactividad, **sin límite de tiempo**: ya no hay los 10 minutos sin tocar ni cuentan los toques.
- **CA-015-04b Pantalla siempre activa: apagada**
  - **Dado** el interruptor **apagado** (por defecto)
  - **Cuando** se ve cualquier tarea
  - **Entonces** la pantalla se comporta como la del sistema.
- **CA-015-04c Dónde nunca se mantiene encendida**
  - **Dado** el interruptor encendido
  - **Cuando** se ve una tarea solo de texto, la tarjeta "Adjunto no disponible", el menú, el editor, el listado, Ajustes o la app está en segundo plano
  - **Entonces** la pantalla se comporta como la del sistema. El cambio del interruptor se aprecia al volver a la tarea; no hay que reiniciar la app.
- **CA-015-05 Persistencia y valor por defecto**
  - **Dado** el interruptor cambiado
  - **Cuando** se cierra y se vuelve a abrir la app (también tras morir el proceso)
  - **Entonces** conserva el valor. **Las instalaciones que ya existen** no tienen valor guardado y toman el nuevo valor por defecto, **apagado**: hasta ahora la pantalla se mantenía encendida por defecto con adjuntos, y a partir de esta versión no (P-7).

### Idioma

- **CA-015-06 La fila "Idioma"**
  - **Dado** Ajustes
  - **Cuando** se ve la fila "Idioma"
  - **Entonces** muestra a la derecha el valor actual y un chevron: **"Como el sistema"** (por defecto), **"Español"** o **"English"**, y al tocarla se abre el nivel 2.
- **CA-015-07 La página de Idioma** *(sin diseño: DEV-52)*
  - **Dado** el nivel 2
  - **Cuando** se muestra
  - **Entonces** tiene el título "Idioma", **Volver** y **tres opciones** en este orden, cada una una fila a todo el ancho con su marca de selección (una marca visible, no solo un color):
    - **Como el sistema**, con debajo el idioma que resulta ahora ("Español" o "English");
    - **Español**;
    - **English**.
  - Los nombres de los idiomas van **siempre en su propio idioma**, sea cual sea el de la app, y cada uno se marca con su idioma para el lector (CA-015-20). Está marcada la opción vigente.
- **CA-015-08 Elegir un idioma** *(P-19 del plan F4b)*
  - **Dado** el nivel 2
  - **Cuando** el usuario elige una opción
  - **Entonces**:
    - se guarda y la app cambia de idioma **al momento, sin reiniciarse**;
    - se **vuelve a Ajustes, ya en el idioma nuevo**, con el foco en la fila "Idioma" (y el lector dice su valor nuevo);
    - elegir la opción que ya estaba marcada solo vuelve a Ajustes.
  - Lo que había debajo se conserva como en CA-010-06: la tarea actual con su adjunto (imagen igual; PDF con su página y su zoom; la web se recarga al volver, CA-015-15) (Ajustes solo se abre desde el menú de la tarea, así que nunca hay un editor debajo). **Esta spec enmienda CA-010-06 en un punto:** la web no conserva su carga, se recarga al volver.
- **CA-015-09 "Como el sistema" y el idioma elegido** *(desarrolla la 010)*
  - **Dado** "Como el sistema"
  - **Cuando** se abre la app o el usuario cambia el idioma del sistema con la app abierta
  - **Entonces** se aplican **sin cambios** las reglas de la 010: se usa el primer idioma preferido que la app admita (cualquier `es-*` y `ca-*` → español; `en-*` → inglés), y si ninguno, inglés (CA-010-01, 02 y 06; CL-010-2 y CL-010-4).
  - **Dado** "Español" o "English" elegidos
  - **Cuando** se abre la app o cambia el idioma del sistema
  - **Entonces** la app **no mira el sistema**: se queda en el idioma elegido.
- **CA-015-10 El idioma desde el primer fotograma (P2)**
  - **Dado** un idioma elegido y la app cerrada
  - **Cuando** se abre
  - **Entonces** la primera pintura de la tarea actual ya está **en ese idioma**, sin un instante en el otro, y la tarea sigue visible en < 1 s (CA-015-23). Si el ajuste no se puede leer, se usa "Como el sistema" (CL-015-16).
- **CA-015-11 Lo que oye el lector con el idioma elegido** *(ADR-0023; revisa el ADR-0020)*
  - **Dado** TalkBack activo y un idioma de la app **distinto** del primer idioma del sistema, comparando solo el código de idioma (`es` y `es-MX` son el mismo; `ca`, `fr` o `gl` son distintos de `es` y `en`), p. ej. sistema en inglés y app en español
  - **Cuando** el lector recorre la app
  - **Entonces** todo lo que se recorre (interfaz y contenido del usuario) lleva el idioma de la app, y **los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz del sistema**, como ya acepta el ADR-0020 para idiomas del sistema que no son español ni inglés. Lo que cambia es que ahora ocurre también con español e inglés, **en quien elige un idioma distinto del del sistema**. Se hace constar en el ADR-0023 y en la excepción a P6 (§9, Q-015-1).
  - **Verificable:** un test con el sistema en inglés y la app en español comprueba que todos los nodos recorridos llevan `es` y ninguno `en` (y al revés); la voz se comprueba a mano (casilla de la 022).
### Información y ayuda

- **CA-015-12 Abrir una web** *(patrón de CA-012-04; ahora con tres enlaces)*
  - **Dado** Ajustes
  - **Cuando** el usuario elige **Política de privacidad**, **Licencias de terceros** o **Ayuda**
  - **Entonces**, **antes** de preguntar, se comprueba que hay una app que pueda abrir la dirección:
    - si la hay, aparece la **confirmación de enlace** de la spec 008 (CA-008-12), "¿Abrir {host} en el navegador?", con el dominio real; solo si el usuario confirma se abre la página en el **navegador del sistema**; si cancela, no pasa nada y el foco vuelve a esa fila;
    - si no la hay, se ve **bajo el bloque de Información y Ayuda** "No hay ninguna app para abrir este enlace.", que se anuncia **una vez por intento**, no mueve el foco y queda a la vista (la pantalla se desplaza si hace falta) **[Suposición]**; si ya estaba visible, un nuevo intento no lo duplica, y se quita al abrir una confirmación o cualquier otra fila con éxito.
  - **La app no se conecta a nada por sí misma** (P4): quien lo hace es el navegador. Ninguna de las tres páginas se ve dentro de la app ni pasa por la vista web de la tarea (ADR-0018 no aplica).
  - Cada enlace tiene **una sola dirección**, la misma en español y en inglés (como P-012-2); la web elegirá el idioma.
  - **Solo se abren direcciones `https`.** Si una configurada no lo es, no se abre nada y se ve el mismo aviso.
  - Cada fila muestra el icono de "abre una web" (tablero 16) y el lector avisa de que **abre una página web en el navegador**.
- **CA-015-13 Direcciones marcador y puerta de publicación** *(amplía CA-012-05; D27)*
  - **Dado** que las tres webs **aún no existen**
  - **Cuando** el usuario las elige en esta versión
  - **Entonces** la confirmación y el navegador usan **direcciones marcador** (dominio reservado, como la política de hoy), una por enlace, junto a la identidad de la app (P7).
  - **Puerta de publicación:** la comprobación automática de la 012 **falla** si **cualquiera de las tres** direcciones: no es `https`; lleva usuario o contraseña; tiene un dominio reservado (RFC 2606 y 6761: `example.com`, `.org`, `.net`, `.example`, `.test`, `.invalid`, `localhost`, y los que añada el plan, 012-S5); o es **idéntica a otra de las tres**; o si la política publicada sigue con huecos. Con una compilación de desarrollo o local no falla. **[Suposición]** Hasta que exista el trabajo de CI de la publicación (F6/020), se aplica a mano en `/release-checklist`, que ahora incluye las tres direcciones, que coinciden con las de la ficha de la tienda.
- **CA-015-14a Licencias de terceros: fuera de la app** *(D26, P-5; ADR-0026)*
  - **Dado** la compilación *release*
  - **Cuando** se recorren todas las pantallas
  - **Entonces** **no existe ninguna pantalla de licencias dentro de la app** (se retiran la lista y el texto de una licencia de la 012 y el código que las leía). **Los textos de licencia siguen dentro del paquete sin mostrarse** (`assets/licenses/*.txt`, los `OFL.txt` de las fuentes y el `NOTICES` de Flutter): la OFL de las fuentes pide que cada copia lleve su licencia y Apache y BSD piden acompañar lo que se redistribuye (ADR-0026; **enmienda a la redacción anterior**, que decía que el paquete no los incluía). Las licencias se ven **solo** en la web de "Licencias de terceros".
- **CA-015-14b El archivo de avisos está completo**
  - **Dado** el repositorio
  - **Cuando** corre CI
  - **Entonces** **falla** si el **archivo de avisos de terceros** (el que se publica en la web) no cubre cada paquete de Dart de *release*, cada fuente empaquetada, cada biblioteca nativa de terceros y el motor de Flutter y las bibliotecas de Android (heredera de `tools/check-licenses.sh`, que hoy comprueba la lista de dentro del APK). Según el ADR-0026, el archivo de avisos se **emite del APK de *release* que ha pasado esa comprobación** (cabecera con versión y fecha; el `NOTICES` descomprimido, los tres `.txt` y los `OFL`) y se verifica **sobre el archivo emitido**: una entrada por cada paquete, `.so`, artefacto y fuente; nombre, formato y dónde lo deja CI, los decide el plan. La comprobación no puede saber qué se ha publicado: `/release-checklist` añade el paso "la web de licencias publica este archivo, el de esta versión".
  - **Consecuencias aceptadas por el propietario (P-5)**, que se registran en el ADR-0026: sin conexión las licencias **no se ven** (P3), y hay un riesgo de cumplimiento (MIT, BSD y Apache piden acompañar la distribución con sus avisos): mientras la web sea un marcador, la app no se puede publicar (CA-015-13).
- **CA-015-15 La tarea de debajo no cambia** *(CA-012-14 y CA-014-07, ahora con Ajustes)*
  - **Dado** una tarea con web, con PDF o con imagen, con el menú abierto
  - **Cuando** se abre Ajustes y se cierra (o se abre una web en el navegador y se vuelve en menos de 10 minutos)
  - **Entonces** el PDF conserva su página y su zoom y la imagen no cambia. La página web **se vuelve a cargar al volver**, como tras el editor o el listado (CA-009-07, CA-009-13): Ajustes tapa la tarea y eso cuenta como salir de la página.
- **CA-015-16 Volver desde el navegador** *(CA-012-06)*
  - **Dado** que el usuario abrió una web desde Ajustes
  - **Cuando** vuelve a la app **y la app sigue viva**
  - **Entonces** aplica CA-001-12: con menos de 10 minutos ve la misma pantalla (Ajustes abierto); con 10 minutos o más, la tarea actual. Si el sistema cerró la app entretanto, se ve la tarea actual (CL-015-5).

### Resto de criterios

- **CA-015-17 Sin esquema, permisos ni dependencias nuevos**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior
  - **Entonces** el esquema de datos no cambia, no hay permisos nuevos, no hay dependencias nuevas, no hay analítica ni conexiones nuevas hechas por la app, y lo único que se guarda de esta pantalla son los dos ajustes de CA-015-05 y CA-015-08 (idioma y pantalla siempre activa). Los ajustes no contienen contenido de tareas (T-2).
- **CA-015-18 "Recientes" (spec 011)**
  - **Dado** cada pantalla nueva: Ajustes, la página de Idioma y la confirmación de enlace
  - **Cuando** se aplica la prueba de CA-011-01 (con la matriz de CA-011-02: sustituyen a las filas de la 012)
  - **Entonces** "Recientes" no muestra nada de ellas.
- **CA-015-19 Diseño: tokens y componentes**
  - **Dado** el tablero 16
  - **Cuando** se implementa
  - **Entonces** sale de los tokens y de los componentes existentes; **el color del interruptor encendido (`#FFDC58`) es un token nuevo** (D22, P-13) con su contraste validado (`validate-tokens`); y se registra DEV-52. Nada de valores sueltos.
- **CA-015-20 Lector de pantalla**
  - **Dado** TalkBack activo
  - **Cuando** se recorre cada nivel
  - **Entonces**:
    - **(a)** el título es un **encabezado** y lo primero que se lee (foco al llegar, tabla);
    - **(b)** el icono se anuncia "Cerrar ajustes" y, en el nivel 2, "Volver";
    - **(c)** **Idioma** se lee como botón con su valor ("Idioma, Español"); el valor lleva su propio idioma;
    - **(d)** **Pantalla siempre activa** se lee como **interruptor** con su estado (activado o desactivado) y el subtítulo; el cambio de estado lo anuncia el propio sistema, sin anuncios extra de la app;
    - **(e)** "Información" es un encabezado; las tres filas de web son botones y añaden que **abren una página web en el navegador**;
    - **(f)** en la página de Idioma, cada opción dice su nombre, su idioma y si está **seleccionada**; "Como el sistema" dice también el idioma que resulta;
    - **(g)** el orden de lectura es **título → filas → aviso (si lo hay) → Cerrar o Volver**, lo último (como CA-013-05); ningún nodo enfocable queda sin nombre;
    - **(h)** al elegir un idioma, el foco vuelve a "Idioma" y se lee su valor nuevo; el foco al volver del navegador y de la confirmación es la fila que se tocó;
    - **(i)** Ajustes es **modal**: con él abierto, **ningún nodo de la tarea de debajo es alcanzable** (ni con el nivel 2 abierto, el nivel 1).
- **CA-015-21 Teclado y conmutadores**
  - **Dado** teclado físico o Switch Access
  - **Cuando** se recorre y se activa
  - **Entonces**:
    - **(a)** el orden de foco del teclado es Cerrar (o Volver) → título → filas; Switch Access sigue el orden del lector (CA-015-20g);
    - **(b)** se ve el anillo de foco; Intro y la barra espaciadora activan (también el interruptor);
    - **(c)** Escape sube un nivel;
    - **(d)** todo se puede hacer sin arrastrar ni pellizcar;
    - **(e)** con Ajustes abierto, el foco no puede salir a la tarea de debajo.
- **CA-015-22 Texto grande y movimiento**
  - **Dado** el texto del sistema al 200 %, en móviles de 360 dp de ancho, **en español y en inglés** (CA-010-12), y "reducir movimiento" activo o no
  - **Cuando** se muestran Ajustes (con todas sus filas y el aviso de error), la página de Idioma y la confirmación de enlace
  - **Entonces** no hay cortes, solapes ni desbordamientos (la pantalla se desplaza); los objetivos son ≥ 44 pt; y la subida de Ajustes y el movimiento del pomo son instantáneos con "reducir movimiento".
- **CA-015-23 El arranque no empeora (P2)**
  - **Dado** la compilación *release*
  - **Cuando** se mide el arranque en frío como en CA-011-05
  - **Entonces** no empeora, con el criterio de CA-011-05: la tarea actual sigue visible en < 1 s (p50, CA-001-09) y el aumento del p50 no supera la diferencia entre dos pasadas de la línea base el mismo día.
- **CA-015-24 Abrir Ajustes confirma una eliminación pendiente** *(D20; CA-014-11 y CL-014-13, ahora con Ajustes)*
  - **Dado** la card de deshacer visible (spec 014)
  - **Cuando** el usuario abre el menú (que no la confirma) y toca "Ajustes"
  - **Entonces** la eliminación es **definitiva** y la card desaparece (también su aviso de error "No hemos podido recuperar la tarea", si lo había, CA-014-11 y DEV-51); no se puede deshacer desde Ajustes ni al volver.
- **CA-015-25 Error al guardar un ajuste** *(§5)*
  - **Dado** que no se puede guardar un ajuste (idioma o interruptor)
  - **Cuando** el usuario lo cambia
  - **Entonces** **el cambio no se aplica**: la app no cambia de idioma y la pantalla no queda fija; el control **vuelve a su valor anterior**, la app sigue funcionando y se ve "No se pudo guardar el ajuste." bajo la fila (en la página de Idioma, bajo las tres opciones), anunciado una vez, sin mover el foco; en el idioma, la página se queda abierta con la opción anterior marcada **[Suposición]**.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-015-1 | Doble toque rápido en "Ajustes", en una fila o en una opción de idioma | Se abre o se aplica una sola vez |
| CL-015-2 | Se gira el móvil con Ajustes abierto | Se queda en vertical: solo gira la tarea actual con imagen, PDF o web (D10, CL-012-3). Al volver a la tarea, vale lo que ya hace la app |
| CL-015-3 | Se completa o elimina la tarea con Ajustes abierto | No se puede: Ajustes tapa el menú y la tarea. Nada cambia al volver |
| CL-015-4 | Sin ninguna tarea ("Todo hecho.") o en la bienvenida | **No hay forma de abrir Ajustes**: el menú solo existe sobre una tarea, igual que la pantalla de la 012. Se llega a Ajustes al crear una tarea. **Aceptado por el propietario (Q-015-5, 2026-10-05):** "Todo hecho." se queda como está, sin menú |
| CL-015-5 | El sistema cierra la app con Ajustes abierto (p. ej. mientras se ve el navegador) | Arranque normal a la tarea actual: **Ajustes no se restaura** (tampoco el menú), como CL-012-11. Los ajustes ya guardados se conservan |
| CL-015-6 | Idioma elegido y el sistema en un idioma que la app no admite (`fr`, `ca`…) | El elegido manda (CA-015-09) |
| CL-015-7 | "Como el sistema" y el primer idioma del sistema no es el que se oye mejor (`fr-FR, es-ES`) | Regla de la 010 (español); la voz de los anuncios es la del sistema (ADR-0020, CA-015-11) |
| CL-015-8 | Se apaga "Pantalla siempre activa" estando una imagen, PDF o web debajo | Al volver, la pantalla se apaga como la del sistema; sin reiniciar la app |
| CL-015-9 | Con el interruptor encendido, se gira el móvil en una tarea con imagen, PDF o web | Sigue encendida en horizontal (CA-015-04) |
| CL-015-10 | Ajustes › Idiomas de la app (Android 13+) | La app **no aparece** en esa lista: el idioma se elige solo en Ajustes (CL-010-6; fuera de alcance, §8) |
| CL-015-11 | Sin conexión al abrir una web | La app no lo nota: el navegador enseña su propio error (CL-012-7). Las licencias no se ven (CA-015-14) |
| CL-015-12 | La dirección configurada de una web no es `https` | No se abre nada y se ve "No hay ninguna app…" (CA-015-12). La puerta lo impide al publicar |
| CL-015-13 | Se cambia el idioma del sistema con Ajustes abierto y "Como el sistema" | Los textos cambian sin cerrar la pantalla (CA-010-06); con un idioma elegido, no cambia nada |
| CL-015-14 | El idioma guardado no es ninguno de los tres (dato corrupto) | Se toma "Como el sistema" y la app no falla |
| CL-015-16 | No se puede **leer** el ajuste de idioma al arrancar | Se usa "Como el sistema"; si sale la pantalla de error de almacenamiento, va en el idioma del sistema |
| CL-015-17 | Con un idioma elegido distinto del del sistema | Los selectores y diálogos del sistema (fotos, archivos, permisos) siguen en el idioma del sistema, como CL-010-2 |
| CL-015-18 | Se restaura una copia de seguridad en otro móvil (D14) | Los dos ajustes (idioma y pantalla siempre activa) viajan con la copia; si el valor de idioma no es válido, CL-015-14 **[Suposición]** |
| CL-015-15 | Una instalación anterior con la pantalla encendida "por defecto" | Pasa a apagada (CA-015-05); no se avisa **[Suposición]**: la beta aún no se ha repartido |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin app para abrir el enlace | No hay navegador, o la dirección no es `https` | "No hay ninguna app para abrir este enlace." bajo el bloque de Información y Ayuda |
| No se pudo guardar | Falla la escritura de un ajuste (CA-015-25) | "No se pudo guardar el ajuste." bajo la fila, y el control vuelve a su valor |
| Vacío | No aplica: Ajustes siempre tiene sus filas | — |

## 6. Accesibilidad

Los criterios están en CA-015-20 a 22. Además:

- Sin gestos: todo son toques; el atrás del sistema equivale a Volver o Cerrar. La subida de la pantalla no es un gesto.
- Contraste: solo con colores de los tokens (`validate-tokens`); el color nuevo del interruptor se valida con el borde y con el fondo.
- **Voz con el idioma elegido (CA-015-11):** el caso nuevo y habitual es sistema en un idioma y app en otro. El contenido y la interfaz se leen bien (llevan su idioma); los anuncios, las acciones y los títulos de las hojas, no. **Excepción a P6** (WCAG 3.1.2) que ya existe en la constitución 1.5 y que el ADR-0023 amplía de "idiomas del sistema que no son ES ni EN" a "cuando el idioma de la app no es el primer idioma del sistema" (constitución 1.7, con la aprobación del propietario). Se comprueba a oído con TalkBack en el móvil, con el sistema en inglés y la app en español y al revés.
- Se revisa con `a11y-reviewer` antes de aprobar el plan, con TalkBack en el emulador al implementar, y entra en la auditoría en dispositivo (spec 022).

## 7. Textos (ES / EN)

Claves nuevas (camelCase; se añaden con `/strings-add`). Los nombres de los idiomas son iguales en los dos ARB y llevan su `locale`.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `menuSettings` | Ajustes | Settings | **Cambia** ("Configuración y perfil" / "Settings and profile"): enlace del menú (CA-015-01) |
| `settingsTitle` | Ajustes | Settings | Encabezado de la pantalla |
| `settingsClose` | Cerrar ajustes | Close settings | **Cambia** ("Cerrar" / "Close"): icono del nivel 1, como el prototipo |
| `settingsLanguage` | Idioma | Language | Fila y título del nivel 2 |
| `settingsLanguageSystem` | Como el sistema | Same as system | Valor por defecto y primera opción (CA-015-06/07) |
| `languageSpanish` | Español | Español | Opción y valor; marcado `es` |
| `languageEnglish` | English | English | Opción y valor; marcado `en` |
| `settingsKeepAwake` | Pantalla siempre activa | Keep screen on | Interruptor (CA-015-03) |
| `settingsKeepAwakeHint` | Imágenes, documentos y web | Images, documents and web | Subtítulo del interruptor |
| `settingsInfo` | Información | Information | Encabezado del bloque 3 (no pulsable) |
| `settingsPrivacy` | Política de privacidad | Privacy policy | Ya existe |
| `settingsThirdPartyLicenses` | Licencias de terceros | Third-party licenses | Sustituye a `settingsLicenses` |
| `settingsHelp` | Ayuda | Help | Fila |
| `settingsOpensWebHint` | Abre una página web en el navegador | Opens a web page in the browser | Pista de las tres filas de web; sustituye a `settingsPrivacyHint` (renombrada) |
| `settingsSaveError` | No se pudo guardar el ajuste. | Couldn't save the setting. | CA-015-25 |

Se reutilizan `openInBrowserConfirm`, `linkConfirmOpen`, `linkConfirmCancel` y `errNoAppForLink`; bajo "Como el sistema" se reutilizan `languageSpanish` y `languageEnglish`, con su marca de idioma. **"Volver" del nivel 2** es "Volver" / "Back" (la clave la decide el plan: la `licensesBack` renombrada o una propia). Se **retiran**, si nada más los usa (lo comprueba el plan): `settingsLicenses`, `settingsPrivacyHint` (la sustituye `settingsOpensWebHint`), `licensesTitle`, `licensesLoading`, `licensesCount`, `licensesError`, `licensesTextOf` y `licensesAndroidLibraries`.

## 8. Fuera de alcance

- **Notificaciones** (spec 019, con el spike S7 antes) y **Bloquear zoom** (spec 017): sus filas no se ven hasta entonces.
- **Las propias webs** de Política de privacidad, Licencias de terceros y Ayuda, el dominio y su alojamiento (PD-2): aquí solo hay direcciones marcador. El texto de la política (borrador en `docs/legal/privacy-policy.md`).
- **Idioma por app de Android 13+** (`localeConfig`): el idioma se elige solo en Ajustes (ADR-0023).
- Más idiomas que español e inglés (D23); ver el ADR-0020 si se añade uno.
- Versión de la app ("Acerca de"), copias de seguridad, tema y paletas, exportar e importar.
- Acceso a Ajustes sin ninguna tarea, en "Todo hecho." o en la bienvenida (CL-015-4, Q-015-5): no se añade ningún menú ahí.
- iOS (D17) y tablets (D28).

## 9. Decisiones y preguntas

**Decisiones del propietario ya tomadas (plan F4b, 2026-10-04):** orden y contenido de Ajustes (D22); idioma por defecto "Como el sistema" y elegible entre español e inglés (D23, P-3); licencias de terceros en una web (D26, P-5, contra la recomendación); pantalla siempre activa, apagada por defecto y sin límite (D10 enmendada, P-6 y P-7); direcciones marcador y puerta de publicación (D27, P-15); token nuevo `#FFDC58` (P-13); página de Idioma con los componentes existentes (P-16); al elegir idioma se vuelve a Ajustes con el foco en "Idioma" (P-19).

**[Pendiente] Preguntas abiertas para el propietario (antes de aprobar):**

- ~~**Q-015-1** Voz de TalkBack con el idioma elegido~~ **[Resuelta, propietario, 2026-10-05]:** se acepta la limitación ampliada (opción 1, recomendación). Va al ADR-0023 y a la constitución 1.7; la opción de regiones vivas se retoma con la migración de R-22 o si lo señala la beta.
- ~~**Q-015-2** Página de Idioma sin diseño~~ **[Resuelta, propietario, 2026-10-05]:** como se propone (CA-015-06 y 07).
- ~~**Q-015-3** Cerrar Ajustes vuelve a la tarea~~ **[Resuelta, propietario, 2026-10-05]:** «como en el prototipo» (CA-015-02).
- ~~**Q-015-4** El aviso de "No hay ninguna app…" (CA-015-12)~~ **[Resuelta, propietario, 2026-10-05]:** se acepta la recomendación. El aviso sale cuando se toca Política de privacidad, Licencias de terceros o Ayuda y el móvil no tiene ninguna app (navegador) que abra la dirección. Es un texto corto de error. Propuesta: que salga **una sola vez, debajo de las tres filas de web** (no debajo de la fila tocada). 
- ~~**Q-015-5** Sin tareas no se llega a Ajustes~~ **[Resuelta, propietario, 2026-10-05]:** se acepta (recomendación): "Todo hecho." y la bienvenida **se quedan como están, sin menú**. Quien deje la app sin tareas no puede cambiar el idioma ni leer la política hasta crear una (CL-015-4).

**[Suposición] sin pregunta** (se corrigen en la revisión si no gustan): dónde queda el foco al cerrar Ajustes (el botón de menú de la tarea); el comportamiento del error al guardar (CA-015-25); que no se avisa del cambio de valor por defecto de la pantalla (CL-015-15); y que la web de "Ayuda" tiene también una sola dirección para los dos idiomas.

## 10. Enmiendas a otras specs y documentos (se aplican al aprobar esta spec)

- **005:** CA-005-09 (el enlace pasa a llamarse "Ajustes" y abre la pantalla de la 015, **cerrando el menú**; antes, sin cerrarlo, la de la 012), CA-005-01 (el enlace subrayado), CA-005-12 ("como Configuración y perfil" como referencia de estilo) y la tabla de textos (`menuSettings`).
- **001:** su mención de "Configuración (spec futura de Configuración y perfil)" pasa a Ajustes (spec 015).
- **007, 008 y 009:** CA-007-12, CA-008-13 y CA-009-16 (y el nombre del ajuste de la 007, "Mantener la pantalla encendida con adjuntos", "por defecto sí"): la pantalla encendida pasa a ser el ajuste "Pantalla siempre activa", **apagado por defecto** y, encendido, **sin límite de tiempo** (ya no los 10 minutos sin tocar ni el conteo de toques).
- **010:**
  - CA-010-01, 02 y 06 y CL-010-2 y 4: valen para "Como el sistema"; con un idioma elegido, la app no mira el sistema.
  - CL-010-6 y CL-010-7 y §8: el selector manual **existe** (esta spec); CL-010-7 ya no habla de "Configuración y perfil".
  - CA-010-07 y CA-010-12: las pantallas que se recorren son Ajustes y la página de Idioma (ya no los tres niveles de la 012).
  - CA-010-03 ("pasa a la spec futura": la implementa la 015), la cabecera ("sin selector") y §9 ("elegidos por el sistema").
  - CA-010-06: en un punto, la web se recarga (CA-015-08).
  - CA-010-10: la excepción de voz pasa a recoger el idioma elegido (ADR-0023).
- **011:** CA-011-02 y la matriz:  Ajustes y la página de Idioma sustituyen a las filas de "Configuración y perfil", la lista de licencias y el texto de una licencia.
- **012:** **sustituida** por esta spec (CA-012-01 a 03, 06, 07 y 09 a 16 y las pantallas de licencias). Siguen, ampliadas, el patrón de la política en el navegador (CA-012-04 → CA-015-12) y la puerta de publicación (CA-012-05 → CA-015-13). Pasa a **Sustituida por la spec 015** cuando se implemente.
- **013:** CA-013-01 y CA-013-02 (nombre de las bibliotecas de Android y cambio de idioma con licencias abiertas) quedan obsoletas con las pantallas de licencias; CA-013-04 y 05 (nodos sin nombre y orden del lector, hoy sobre "los tres niveles de la 012") se aplican ahora a Ajustes (CA-015-20).
- **014:** "Configuración y perfil" pasa a "Ajustes" en la cabecera, la línea de dependencias, CA-014-11 y CL-014-13.
- **Constitución:** ✅ **1.7 aplicada el 2026-10-05** (la excepción de P6 del ADR-0020 se amplía al idioma elegido, ADR-0023; P3: nota de que la política de privacidad, las licencias de terceros y la ayuda necesitan conexión, ADR-0026). **ADR-0020:** marcado "sustituido en parte por ADR-0023". **Spec 010:** CA-010-10 y CL-010-2, enmendados.
- **`docs/design/prototype-deviations.md`:** **DEV-52** (nueva); DEV-49 **sustituida**; DEV-05 y DEV-18, anotadas.
- **`docs/PLAN.md`:** D10, D13 y D22–D27 ya reflejados; trazabilidad R15 y R18; fila de la 015 en F4b; §9 siguiente paso.
- **`docs/glossary.md`:** "Ajustes", "Pantalla siempre activa", "Idioma de la app", "Licencias de terceros", "Ayuda" e "Interruptor"; "Configuración y perfil (temporal)" y "Licencias de código abierto", marcadas como sustituidas.
- **`docs/design/screen-map.md`:** tablero 16 y la entrada del menú → 015.
- **`.claude/skills/release-checklist/SKILL.md`:** las tres direcciones, que coincidan con la ficha de la tienda, y "la web de licencias publica el archivo de esta versión".
- **`docs/security/threat-model.md`:** además, anotar que "Pantalla siempre activa" no bloquea la pantalla mientras se ve contenido (D10, P-6).
- **`docs/architecture.md`, `docs/security/threat-model.md`, `docs/security/checklist.md`, `docs/testing.md`, `docs/legal/privacy-policy.md` (ajustes que viajan en la copia de seguridad), `identity.yaml`, `tools/check-release-config.sh` y `tools/check-licenses.sh`:** los cambios que diga el plan.
- **Memoria `una-project-context`:** al cerrar la 015.

## Anexo: notas para `plan.md` (no normativas)

- **Términos técnicos fuera de los criterios:** el ajuste de idioma es la clave `locale` y el marcado de idioma del lector es `localeForSubtree` (CA-015-11); el esquema de datos no cambia porque los ajustes ya son clave y valor (CA-015-17); el idioma elegido y el interruptor se leen junto con el resto de ajustes que ya se leen al arrancar (CA-015-10, 23).

- **Ajustes ya existentes [Hecho]:** la tabla `settings` (clave y valor) ya tiene reservadas `locale` (`system | es | en`) y `keepScreenOn` (`docs/architecture.md`); el repositorio ya lee `keepScreenOn` al arrancar (`bootStateProvider`). **No hace falta migración**: hay que **escribir** los dos valores y **leer** `locale` en el mismo arranque (CA-015-10), y cambiar el valor por defecto de `keepScreenOn` a `false`.
- **Pantalla encendida:** `KeepScreenOnController` (`features/attachments/keep_screen_on_controller.dart`) tiene `idleLimit` de 10 minutos, `touched()` y un `Listener` de toques en `una_app.dart`: se quitan (CA-015-04). `setEnabled` ya existe y hay que conectarlo al ajuste.
- **Idioma:** `resolveAppLocale` (`app/locale_resolution.dart`) es la regla de la 010 y pasa a usarse solo con "Como el sistema". La app declara `localeListResolutionCallback`; con `es` o `en` elegidos se fija el idioma. `appFrame` ya marca `localeForSubtree` con el idioma de la app (CA-010-10). El manifiesto ya tiene `locale|layoutDirection` en `configChanges`, así que cambiar el idioma no recrea la actividad.
- **Navegación:** Ajustes y la página de Idioma son rutas a pantalla completa como las de la 012 (`features/settings/`), pero **la ruta se abre cerrando la hoja del menú** (tablero 16: `sheet: null` a los 220 ms), no sobre ella. Se retiran `LicensesScreen`, `LicenseDetailScreen`, `licensesProvider`, `FlutterLicenseSource` y lo que solo usaban (**[Hecho, ADR-0026]** los assets de `bundled_licenses` **siguen declarados** en `pubspec.yaml` y dentro del APK; solo se retira el código que los leía (`registerBundledLicenses`); `check-licenses.sh` conserva sus comprobaciones y además emite el archivo de avisos). Los *goldens* de la 012 se sustituyen por los de Ajustes.
- **Interruptor:** componente propio con tokens (P12; el `Switch` de Material no sirve). Una fila `SheetRow`-like con rol de interruptor y `toggled`, anillo de foco y un solo nodo semántico. Token nuevo para el amarillo encendido.
- **Enlaces:** el canal `una/links` y `NativeLinkOpener` ya comprueban "hay app que lo abra" y abren; solo hay que repetir el patrón de CA-012-04 con tres direcciones. `identity.yaml` gana `thirdPartyLicensesUrl` y `helpUrl` junto a `privacyPolicyUrl`; `tool/check_release_config.dart` valida las tres (012-S5 se puede arreglar aquí: ampliar los dominios reservados).
- **Recientes:** ya hay `tools/check-recents.sh`; hay que añadir las filas nuevas a su matriz y a la de CA-011-02.
- **Una sola sesión de spec, otra de plan:** los ADR-0023 y ADR-0026 ya están aceptados (2026-10-05); el plan los desarrolla (como el ADR-0021 en la 014).
