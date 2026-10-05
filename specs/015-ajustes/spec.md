# Spec 015: Ajustes

- **Estado:** **Aprobada** (propietario, 2026-10-05), tras ser **corregida según la revisión 1** (`revision-1.md`, 2026-10-05; bloqueantes B1 y B2, importantes I-A a I-J y menores) **y la revisión 2** (`spec-reviewer`, `a11y-reviewer` y `security-reviewer`, 2026-10-05: sin bloqueantes; hallazgos aplicados salvo menores que se dejan al plan). Respondidas por el propietario todas las preguntas de §9 (Q-015-1 a 5) y las tres decisiones de la revisión (§9). Los ADR-0023 y ADR-0026 están **Aceptados** por el propietario (2026-10-05; constitución 1.7). El plan (`plan.md`) y las tareas (`tasks.md`) están **Aprobados** (2026-10-05); el siguiente paso es la implementación, en una sesión nueva (`/spec-implement 015`).
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Es la segunda de las specs 014–019.
- **Reglas de producto:** R15 (idioma, ahora elegible), R18 (Ajustes: pantalla siempre activa e información)
- **Pantallas del prototipo:** 16 "Ajustes" (`Ajustes.dc.html`) y 2 "Menú" (el enlace pasa a llamarse "Ajustes"). **Sin diseño:** la página de Idioma (se hace con los componentes existentes, P-16 del plan F4b). Ver `docs/design/screen-map.md`.
- **Decisiones y ADR relacionados:**
  - **R-26 y R-27** del plan (voz con el idioma elegido; licencias solo en la web).
  - **D22** (orden y valores por defecto de Ajustes), **D23** (idioma), **D26** (licencias de terceros en una web), **D27** (direcciones marcador) y **D10 enmendada** (pantalla siempre activa, sin límite); **D13 resuelta** (la Configuración completa es esta pantalla).
  - **ADR** (redactados con `/adr-new` y **Aceptados el 2026-10-05**, como el ADR-0021 de la 014): [ADR-0023](../../docs/adr/0023-idioma-elegido-en-la-app.md) *Idioma elegido en la app* (revisa el ADR-0020 y amplía la excepción a P6, constitución 1.7) y [ADR-0026](../../docs/adr/0026-licencias-de-terceros-en-la-web.md) *Licencias de terceros en la web* (sustituye a la parte de licencias de la 012). Esta spec dice **qué** debe cumplirse; el cómo está en los ADR.
  - **DEV-52** (nueva: Ajustes, Idioma y los enlaces a la web; sustituye a DEV-49 y a DEV-05).
  - ADR-0020 (voz del sistema en los anuncios), ADR-0018 (los enlaces no se siguen dentro de la app), ADR-0016 (la tarea web no guarda copia: se vuelve a pedir al volver).
- **Dependencias:** 005 (menú), 007–009 (pantalla encendida con adjuntos), 010 (idioma), 011 (matriz de "Recientes"), 012 (la sustituye), 013, 014 (abrir Ajustes hace definitiva la eliminación pendiente). **Sin esquema de BD nuevo, sin permisos y sin dependencias nuevas** (CA-015-17).
- **Enmiendas a otras specs y documentos:** en el §10, con lo que ya está hecho, lo que se aplica al aprobar y lo que se deja al plan.
- **Nomenclatura:** "Ajustes" es esta pantalla de la app; los de Android se llaman siempre "Ajustes del sistema".

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y en los ADR; las notas técnicas, solo en el anexo (no normativo).

## 1. Objetivo

Dar a la app su **pantalla de Ajustes** definitiva, sustituyendo a la temporal de la 012: elegir el **idioma**, decidir si la **pantalla se queda siempre encendida** con adjuntos, y llegar a la **política de privacidad**, las **licencias de terceros** y la **ayuda**, que viven en una web. Es la pantalla a la que se añadirán Bloquear zoom (017) y Notificaciones (019), y debe poder recibirlas sin rediseñarse.

## 2. Historias de usuario

- **HU-015-1** Como usuario con el móvil en un idioma y la app en otro, quiero elegir el idioma de la app, para usarla en el que prefiero sin cambiar el del móvil.
- **HU-015-2** Como usuario que mira una imagen, un PDF o una web, quiero poder mantener la pantalla encendida sin límite de tiempo, para consultarla sin que se apague. Y quiero que, por defecto, se apague como el resto de mi móvil.
- **HU-015-3** Como usuario, quiero poder leer la política de privacidad, las licencias de terceros y la ayuda, para saber qué hace la app, qué lleva dentro y cómo se usa.
- **HU-015-4** Como usuario de TalkBack, teclado o conmutadores, quiero llegar, leer, cambiar un ajuste y salir sin gestos que no pueda hacer (CA-015-20 a 22).

**Trazabilidad HU → CA**

| HU | Criterios |
|---|---|
| HU-015-1 | CA-015-06 a 11, 25, 26 (y 23, el arranque) |
| HU-015-2 | CA-015-03, 04a a 04d, 05, 25, 26 |
| HU-015-3 | CA-015-12a a 12c, 13a, 13b, 14a, 14b, 15, 16 |
| HU-015-4 | CA-015-01a, 01d, 02, 20, 21, 22 |
| Estructura y alcance de la pantalla | CA-015-01b, 01c (sirven a las cuatro historias) |
| Transversales | CA-015-17, 18, 19, 23, 24, 27 |

## 3. Criterios de aceptación

**Niveles y controles.** Hay dos niveles. Los dos se cierran hacia atrás; solo el primero tiene el icono de cerrar.

| Nivel | Qué es | Controles visibles | Atrás del sistema, gesto de atrás y Escape | Foco del lector al llegar | Foco del teclado al llegar | Foco al volver |
|---|---|---|---|---|---|---|
| 1 | "Ajustes" | Icono **Cerrar ajustes** | Cierra y vuelve a la **tarea actual** (no al menú) | El título | **Cerrar ajustes** | El botón de menú de la tarea **[Suposición]** |
| 2 | "Idioma" (página de selección) | **Volver** | Vuelve al nivel 1 | El título | **Volver** | La fila "Idioma" del nivel 1 |

El **título** es solo el foco inicial del lector: no se activa y no entra en el orden del teclado (CA-015-21).

### La pantalla

- **CA-015-01a Abrir Ajustes**
  - **Dado** el menú abierto (CA-005-01) de cualquier tarea (solo texto, con imagen, con PDF o con web)
  - **Cuando** el usuario toca "Ajustes" (antes "Configuración y perfil")
  - **Entonces** el enlace es un **botón** con anillo de foco y un objetivo táctil de **≥ 44 pt visibles y una zona táctil de ≥ 48 dp en Android** (`docs/design/tokens.md`, «size»); el menú se **cierra** y Ajustes **sube desde abajo, a pantalla completa**. *Cambio respecto de la 012, que dejaba el menú debajo:* aquí el menú se cierra al abrir (este criterio) y no vuelve al cerrar Ajustes (CA-015-02).
- **CA-015-01b Estructura de la pantalla**
  - **Dado** Ajustes abierto
  - **Cuando** se mira
  - **Entonces** tiene, de arriba abajo (tablero 16): el título "Ajustes" con el icono de cerrar; **Idioma**; un separador de bloque; **Pantalla siempre activa** (con el subtítulo "Imágenes, documentos y web"); un separador de bloque; el encabezado **Información** (no se puede pulsar) con **Política de privacidad** y **Licencias de terceros** debajo; y **Ayuda**. Cada fila lleva a la izquierda su icono del tablero; las de web, además, el icono de "abre una web" a la derecha, y la de Idioma el chevron. **Todos los iconos de las filas son decorativos para el lector** (su significado ya va en el nombre). **Separadores:** 4 px a sangre entre bloques y 1 px entre filas de un mismo bloque (el color del de 1 px está en DEV-52). Los objetivos táctiles cumplen CA-015-01a, incluido **Cerrar ajustes** (en el prototipo mide 46 × 46 y se amplía hasta la zona de 48 dp). Con un ancho de 600 dp o más, la pantalla va centrada a 600 como el resto de la app (CL-001-7).
- **CA-015-01c Lo que aún no está**
  - **Dado** Ajustes en esta versión
  - **Cuando** se mira
  - **Entonces** **no** aparecen **Notificaciones** ni **Bloquear zoom**: llegan con las specs 019 y 017, en el sitio que les da D22 (Notificaciones bajo Idioma; Bloquear zoom bajo Pantalla siempre activa). La estructura de bloques y separadores las admite sin cambiar nada de lo demás.
- **CA-015-01d Transiciones y reducir movimiento** *(decisión del propietario, 2026-10-05)*
  - **Dado** Ajustes y su página de Idioma
  - **Cuando** se abren, se cierran o se pasa de un nivel a otro
  - **Entonces**:
    - Ajustes **sube** desde abajo en **200 ms** (`sheetIn`) y **baja** en **160 ms** (`sheetOut`); los 220 ms y 170 ms del prototipo son temporizadores con los que limpia el estado, no la duración de la animación, y es esa duración la que se comprueba;
    - entre el nivel 1 y el 2 (en los dos sentidos) hay un **fundido de 160 ms** (`sheetOut`), como en la 012;
    - con "reducir movimiento", **todas** las transiciones son instantáneas (0 ms).
  - **Verificable:** un test de widgets lee la duración de la transición y el movimiento del pomo con y sin `disableAnimations`. **Nota:** 0 ms con reducir movimiento es una desviación consciente del fundido de 400 ms de `docs/design/tokens.md` (DEV-52).
- **CA-015-02 Cerrar y volver** *(cambio de comportamiento respecto de la 012)*
  - **Dado** cualquiera de los dos niveles
  - **Cuando** el usuario usa el control de la tabla, el atrás del sistema, el gesto de atrás o Escape con teclado
  - **Entonces** se sube **un nivel** y, desde el nivel 1, se **vuelve a la tarea actual** con el menú ya cerrado, como en el prototipo. El foco va donde dice la tabla. No hay otro gesto que cierre la pantalla.
- **CA-015-03 Pantalla siempre activa: el interruptor**
  - **Dado** Ajustes
  - **Cuando** se ve "Pantalla siempre activa"
  - **Entonces** es un **interruptor**, **apagado por defecto** (D22 y P-7), con el nombre y el subtítulo del prototipo, y toda la fila es el objetivo táctil (CA-015-01a).
  - **Cuando** el usuario toca la fila **Entonces** se guarda y, **solo cuando el guardado se ha confirmado**, el interruptor cambia de estado (sin cambio optimista, como CA-015-08: guardar primero; CA-015-05, CA-015-25). Así, si el guardado falla, TalkBack no dice "activado" y luego "desactivado".
  - **El estado lo da la posición del pomo, no el color** (WCAG 1.4.1): el pomo cambia de lado y, como en el prototipo, se intercambian los colores de pista y pomo (apagado: pista del papel y pomo amarillo; encendido: pista amarilla y pomo del papel). El amarillo `#FFDC58` frente al papel `#F4F1EA` mide ≈ 1,2:1, así que **ese par no se usa para distinguir nada ni se le exige contraste**. Lo que contrasta es el **borde de tinta** (WCAG 1.4.11), con estos pares mínimos de **3:1**, en los dos estados, que `validate-tokens` declara y comprueba (CA-015-19):
    - **(a)** el borde de la pista (3 px, tinta) frente al papel de la pantalla;
    - **(b)** el borde del pomo (2 px, tinta) frente al relleno de la pista: papel apagado y amarillo encendido.
  - El subtítulo cumple ≥ 4,5:1 (`textMuted` sobre papel). El amarillo encendido es un token nuevo (CA-015-19). Con "reducir movimiento", el pomo cambia de sitio sin animación (hoy 120–140 ms; CA-015-01d).
  - **Verificable:** un test comprueba que la posición del pomo **difiere** entre los dos estados y que `toggled` coincide con ella (más un *golden* de los dos estados en ES y EN), que el interruptor no cambia hasta confirmarse el guardado, y los pares de contraste en `validate-tokens` (CA-015-19). Los objetivos táctiles de CA-015-01a y 01b se comprueban con `androidTapTargetGuideline` (CA-015-22).
- **CA-015-04a Pantalla siempre activa: encendida** *(D10 enmendada, P-6 del plan F4b; cambia CA-007-12, CA-008-13 y CA-009-16)*
  - **Dado** el interruptor **encendido**
  - **Cuando** se ve la tarea actual con **imagen, PDF o web** (en vertical o en horizontal) con la app en primer plano, **incluida la web con su aviso** "Necesitas conexión para ver esta página." (el usuario sigue mirando la tarea) **[Suposición]**
  - **Entonces** la pantalla **no se apaga ni se bloquea** por inactividad, **sin límite de tiempo**: ya no hay los 10 minutos sin tocar ni cuentan los toques.
  - **Verificable:** con el canal falso `una/screen`, tras 60 minutos simulados sin ningún toque la petición de pantalla encendida sigue activa, y no existe ningún temporizador ni contador de toques (`touched()` se retira). Con el mismo canal falso: **la web en estado de error** ("Necesitas conexión…") pide `keepOn(true)`; la tarjeta "Adjunto no disponible" y la tarea de solo texto **no**; y abrir Ajustes, el menú o la confirmación de enlace deja `keepOn(false)`.
- **CA-015-04b Pantalla siempre activa: apagada**
  - **Dado** el interruptor **apagado** (por defecto)
  - **Cuando** se ve cualquier tarea
  - **Entonces** la pantalla se comporta como la del sistema.
- **CA-015-04c Dónde nunca se mantiene encendida**
  - **Dado** el interruptor encendido
  - **Cuando** se ve una tarea **solo de texto** (aunque el interruptor siga encendido y así se vea en Ajustes), la tarjeta "Adjunto no disponible", el menú, el editor, el listado, Ajustes o la app está en segundo plano
  - **Entonces** la pantalla se comporta como la del sistema. El cambio del interruptor se aprecia al volver a la tarea; no hay que reiniciar la app.
- **CA-015-04d Se suelta al salir** *(riesgo residual aceptado: `threat-model.md`, T-15 y §7)*
  - **Dado** el interruptor encendido y la pantalla encendida por una tarea con imagen, PDF o web
  - **Cuando** la app deja de estar en primer plano (cualquier estado distinto de `resumed`: `inactive`, `paused` u `hidden`), o se sale de esa tarea a otra pantalla
  - **Entonces** la app **retira la petición** de pantalla encendida; el sistema no la retiene.
  - **Verificable:** con el canal falso `una/screen`, tras `inactive`, `paused` y `hidden` el último valor recibido es `keepOn(false)`. (El flag de ventana además no tiene efecto con la ventana oculta, pero no se depende de ello.)
- **CA-015-05 Persistencia y valor por defecto**
  - **Dado** el interruptor cambiado
  - **Cuando** se cierra y se vuelve a abrir la app (también tras morir el proceso)
  - **Entonces** conserva el valor. **Las instalaciones que ya existen** no tienen valor guardado y toman el nuevo valor por defecto, **apagado**: hasta ahora la pantalla se mantenía encendida por defecto con adjuntos, y a partir de esta versión no (P-7). **[Hecho]** la clave `keepScreenOn` **nunca se ha escrito** (`setKeepScreenOn` no tiene llamantes), así que ninguna instalación tiene un valor propio que cambiar. Cambiar el valor por defecto de una clave que ya existe **no** es un cambio de esquema; el plan lo confirma (`docs/architecture.md` dice que las claves se versionan con el esquema).
- **CA-015-26 Valores guardados ilegibles o no válidos** *(seguridad, revisión 1: I-A)*
  - **Dado** un ajuste guardado (`locale` o `keepScreenOn`) que **no se puede leer ni decodificar**, o que no es un valor válido
  - **Cuando** la app arranca o lo lee
  - **Entonces**:
    - **cualquier fallo** al leer o decodificar un ajuste usa el **valor por defecto** (idioma "Como el sistema", pantalla siempre activa **apagada**) y **no impide el arranque** ni se ve un error por ello;
    - la pantalla siempre activa vale "encendida" **solo** si el valor guardado es **exactamente** `true`; cualquier otra cosa es apagada. También el valor por defecto que se usa al arrancar pasa a ser apagado (`BootState.keepScreenOn`, anexo);
    - el idioma se **valida contra `system`, `es` y `en`** exactamente; cualquier otro valor es "Como el sistema". **Nunca se construye un `Locale` a partir del valor guardado.**
  - **Verificable:** tests, para `locale` y para `keepScreenOn`, con `fr`, cadena vacía, `es-MX`, una cadena muy larga, JSON no válido, un número (incluidos `1` y `0`), `"true"` como cadena, `false`, `null` y una lista: ninguno falla y todos dan el valor por defecto (salvo, en `locale`, `system`, `es` y `en`, y, en `keepScreenOn`, `true`). **Los mismos tests** pasan con el repositorio de Drift **y** con el **repositorio en memoria** (`InMemoryTaskRepository`, cuyo valor inicial `_keepScreenOn = true` pasa a apagado), que comparten el test de contrato.
  - "No impide el arranque" se refiere **solo a estos dos ajustes**: cada lectura va en su propio `try/catch`, separado de la de la tarea actual (CL-015-16 sigue admitiendo la pantalla de error de almacenamiento por otras causas).

### Idioma

- **CA-015-06 La fila "Idioma"**
  - **Dado** Ajustes
  - **Cuando** se ve la fila "Idioma"
  - **Entonces** muestra a la derecha el valor actual y un chevron: **"Como el sistema"** (por defecto), **"Español"** o **"English"**, y al tocarla se abre el nivel 2. Con el texto al 200 % el valor **pasa a una segunda línea** (o la fila pasa a ser una columna) **sin recortarse** (CA-015-22).
- **CA-015-07 La página de Idioma** *(sin diseño: DEV-52)*
  - **Dado** el nivel 2
  - **Cuando** se muestra
  - **Entonces** tiene el título "Idioma", **Volver** y **tres opciones** en este orden, cada una una fila a todo el ancho con su marca de selección (una marca visible de ≥ 3:1 frente al papel, no solo un color; decorativa para el lector, que dice "seleccionada" por la semántica):
    - **Como el sistema**, con debajo el idioma que resulta ahora ("Español" o "English"); su nombre va **en el idioma de la app** y la línea inferior, en el suyo;
    - **Español**;
    - **English**.
  - Las tres opciones forman un **grupo de selección única** con nombre "Idioma" (con el rol de grupo de botones de radio o con el propio título, **sin añadir una parada de foco** ni repetir "Idioma" tras el título). Está marcada la opción vigente. Los nombres "Español" y "English" van **siempre en su propio idioma**, sea cual sea el de la app, y cada uno se marca con su idioma para el lector (CA-015-11). Con el texto al 200 %, las opciones y la línea de "Como el sistema" no se recortan (CA-015-22).
  - **Verificable:** `tester.getSemantics` muestra las tres opciones dentro de un grupo de selección única (`inMutuallyExclusiveGroup`, rol de botón de radio con `checked`, no `selected`) con el nombre del grupo y **sin ninguna parada de foco extra**.
- **CA-015-08 Elegir un idioma** *(P-19 del plan F4b)*
  - **Dado** el nivel 2
  - **Cuando** el usuario elige una opción
  - **Entonces**, en este **orden**: **(1)** se guarda; **(2)** solo si se ha guardado, se vuelve a Ajustes; **(3)** se aplica el idioma; **(4)** una vez reconstruida la pantalla en el idioma nuevo, el foco va a la fila "Idioma" **una sola vez** y el lector dice su valor nuevo. La app cambia de idioma **sin reiniciarse**.
  - **Sin parpadeo de idioma:** mientras la página de Idioma se cierra (fundido de 160 ms, CA-015-01d) **no se repinta en el idioma nuevo**, y Ajustes **no se ve en el idioma anterior** una vez que aparece: el idioma se aplica cuando la ruta ya se ha retirado o de forma que el usuario no vea ningún fotograma mezclado (cómo, lo decide el plan, p. ej. congelando la página que sale). Con "reducir movimiento", todo ocurre en el mismo fotograma.
  - **Los cuatro casos siguen el mismo orden** (guardar primero, aplicar después): **otra opción** (vuelve a Ajustes con el foco en "Idioma"); **la misma opción** (solo vuelve a Ajustes, con el foco en "Idioma", **sin guardar de nuevo**); **error de guardado** (no se aplica nada: la página se queda abierta con la opción anterior y el aviso de CA-015-25, sin mover el foco); y **cambio del idioma del sistema con "Como el sistema"** (los textos cambian en su sitio, CL-015-13, sin mover el foco).
  - Lo que había debajo se conserva como en CA-010-06: la tarea actual con su adjunto (imagen igual; PDF con su página y su zoom; la web se recarga al volver, CA-015-15) (Ajustes solo se abre desde el menú de la tarea, así que nunca hay un editor debajo). **Esta spec enmienda CA-010-06 en un punto:** la web no conserva su carga, se recarga al volver.
  - **Verificable**, con un repositorio de ajustes de prueba controlable: mientras el guardado no termina, **no se vuelve a Ajustes ni cambia el idioma**; si el guardado falla, la página sigue abierta con la opción anterior, sin cambio de idioma y con el aviso; la petición de foco a "Idioma" se hace **exactamente una vez**; y elegir la misma opción vuelve sin escribir. El foco real de TalkBack (que en una ruta que se destapa enfoca primero el primer nodo, y la petición debe llegar después) se comprueba a mano (casilla de la 022).
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
  - **Entonces** la primera pintura de la tarea actual ya está **en ese idioma**, sin un instante en el otro, y la tarea sigue visible en < 1 s (CA-015-23). Si el ajuste no se puede leer, se usa "Como el sistema" (CA-015-26, CL-015-16).
- **CA-015-11 Lo que oye el lector con el idioma elegido** *(ADR-0023; revisa el ADR-0020)*
  - **Dado** TalkBack activo y un idioma de la app **distinto** del primer idioma del sistema, comparando solo el código de idioma (`es` y `es-MX` son el mismo; `ca`, `fr` o `gl` son distintos de `es` y `en`), p. ej. sistema en inglés y app en español
  - **Cuando** el lector recorre la app
  - **Entonces** todo lo que se recorre (interfaz y contenido del usuario) lleva el **idioma de la app**, con **una única excepción**: los nombres **"Español" y "English"** (opciones y valor de la fila "Idioma"), que llevan **su propio idioma**. "Como el sistema" va en el idioma de la app y su línea inferior ("Español" o "English"), en el suyo. En cambio, **los anuncios del sistema y las palabras de rol y estado** ("botón", "interruptor", "activado", "desactivado", "seleccionada", "encabezado"), **los nombres de las acciones del lector y los títulos de las hojas se oyen con la voz y el idioma del sistema**, como ya acepta el ADR-0020 para idiomas del sistema que no son español ni inglés. Lo que cambia es que ahora ocurre también con español e inglés, **en quien elige un idioma distinto del del sistema**. Se hace constar en el ADR-0023 y en la excepción a P6 (§6, Q-015-1).
  - **Verificable:**
    - un test con el sistema en inglés y la app en español comprueba que todos los nodos recorridos llevan `es` y ninguno `en` (y al revés), **salvo** los nodos que **contienen** "Español" o "English" como nombre o valor: "Español", "English", el valor de la fila "Idioma" ("Idioma, Español") y la línea inferior de "Como el sistema" ("Como el sistema, Español"), que llevan **dos marcas** (la del texto de la app y la del nombre del idioma) o la suya propia;
    - **otro test aparte** comprueba que esos nombres llevan su propio `locale` (`es` o `en`), **también en la fila "Idioma" y en la opción "Como el sistema"**;
    - si Flutter o TalkBack no respetan dos marcas en un nodo fusionado, el valor puede ir como **nodo separado** con la suya, **sin romper** que la fila siga siendo **un solo objetivo táctil con su nombre completo** y que el valor se oiga con su idioma y se lea al recibir el foco (CA-015-20c y 20h). Dos caminos, a decidir en el plan: marcas de idioma **por tramo** dentro del texto de la etiqueta, o dos nodos con foco agrupado **[Suposición]**; se comprueba con `tester.getSemantics`;
    - la voz se comprueba a mano (casilla de la 022), incluido "Idioma, Español" y "Como el sistema" con su línea inferior.

### Información y ayuda

- **CA-015-12a Abrir una web: la confirmación** *(patrón de CA-012-04; ahora con tres enlaces)*
  - **Dado** Ajustes
  - **Cuando** el usuario elige **Política de privacidad**, **Licencias de terceros** o **Ayuda**
  - **Entonces**, **antes** de preguntar, se comprueba que hay una app que pueda abrir la dirección; si la hay, aparece la **confirmación de enlace** de la spec 008 (CA-008-12), "¿Abrir {host} en el navegador?", con el dominio real. El foco entra en **"Cancelar"** **[Suposición]**. Solo si el usuario confirma se abre la página en el **navegador del sistema**; si cancela, no pasa nada y el foco vuelve a esa fila. Con el texto al 200 %, el dominio puede partirse (un dominio largo o en *punycode*) o el diálogo se desplaza: no se recorta.
  - **La app no se conecta a nada por sí misma** (P4): quien lo hace es el navegador, que se conecta con la conexión del usuario y puede mostrar al destino el referente de la app (anexo; `privacy-policy.md`, §10). Ninguna de las tres páginas se ve dentro de la app ni pasa por la vista web de la tarea (ADR-0018 no aplica).
  - Cada enlace tiene **una sola dirección**, la misma en español y en inglés (como P-012-2); la web elegirá el idioma. Las tres filas **usan la misma función**.
  - **Verificable**, con el canal falso `una/links`: `open` **no** se llama sin confirmar ni al cancelar; `canOpen` se llama **en cada toque** y no registra la dirección; una dirección que no sea `https` **no** llama ni a `canOpen` ni a `open`; las tres filas producen la **misma secuencia** `canOpen` → confirmación → `open`, cada una con su dirección; el host de la confirmación es **exactamente** el de la dirección que recibe `open`; y para comprobar que no se registra la dirección, el test captura `debugPrint`, `print` y `FlutterError` y verifica que no aparece.
- **CA-015-12b Abrir una web: sin app que lo abra** *(avisos de error, decisión del propietario 2026-10-05)*
  - **Dado** Ajustes y que no hay ninguna app que abra la dirección
  - **Cuando** el usuario toca una de las tres filas
  - **Entonces** se ve **bajo el bloque de Información y Ayuda** "No hay ninguna app para abrir este enlace.", que **no mueve el foco** y queda a la vista (la pantalla se desplaza si hace falta) **[Suposición]**. Es una **región viva** (ver "Los avisos" abajo).
- **CA-015-12c Solo `https`**
  - **Dado** una dirección configurada que no es `https`
  - **Cuando** se toca su fila
  - **Entonces** no se abre nada y se ve el mismo aviso de CA-015-12b.
- **Los avisos (CA-015-12b y CA-015-25): regiones vivas con la marca de idioma de la app**
  - Los dos avisos de error ("No hay ninguna app para abrir este enlace." y "No se pudo guardar el ajuste.") son **regiones vivas** (`Semantics(liveRegion: true)`) **con la marca de idioma de la app**, dentro del árbol y alcanzables en el orden de lectura. **No** se usan los anuncios del sistema (`sendAnnouncement`): así su texto se lee con la voz del idioma de la app y **no se amplía la excepción a P6** con texto nuevo (decisión del propietario, 2026-10-05).
  - **Ciclo de vida, una sola regla:** cada aviso se **quita con la siguiente acción con éxito sobre cualquier control** (abrir una confirmación, o cambiar un ajuste que se guarda) **o al salir del nivel en que se ve**. **Pueden verse a la vez** (uno de cada tipo, como máximo): se leen en el orden de la pantalla, el de guardado bajo su fila y el de enlace bajo Información y Ayuda (tras Ayuda). Un **nuevo intento fallido** vuelve a anunciar el aviso (**una vez por intento**) sin duplicarlo: como una región viva con el mismo texto no se vuelve a anunciar, el aviso se **retira y se vuelve a insertar** en cada intento fallido (o lleva una clave nueva por intento; cómo, lo decide el plan). Cada aviso queda **a la vista** (la pantalla se desplaza hasta él, `ensureVisible`) porque el árbol semántico no incluye lo que está fuera del área visible; no depende solo del color (es texto).
  - **[Suposición]** que TalkBack respete la marca de idioma en una región viva y la lea con la voz del idioma de la app: se comprueba a oído (casilla de la 022); si no fuera así, vuelve a plantearse la excepción de P6.
  - **Verificable:** el nodo existe, es `liveRegion` y lleva `es` o `en` (el idioma de la app); no hay llamadas a `sendAnnouncement`; **dos fallos seguidos producen dos anuncios sin duplicar el nodo**; y el aviso queda dentro del área visible tras `ensureVisible`, también al 200 %.
- **CA-015-13a Direcciones: constantes de compilación y marcadores** *(amplía CA-012-05; D27; P7)*
  - **Dado** que las tres webs **aún no existen**
  - **Cuando** el usuario las elige en esta versión
  - **Entonces** la confirmación y el navegador usan **direcciones marcador** (dominio reservado, como la política de hoy), una por enlace y **las tres distintas entre sí** (CA-015-13b).
  - Las tres direcciones son **constantes de compilación** que vienen **solo** de `identity.yaml` → `AppIdentity`, junto a la identidad de la app (P7): **no** salen de los ajustes, de la base de datos, de una configuración remota ni del idioma elegido. **No llevan consulta (`?`), fragmento (`#`), ni versión, idioma o identificador** de ninguna clase.
  - **Verificable:** cada dirección configurada pasa `privacyLink` y no tiene parámetros; y la **misma dirección** sale con la app en `es` y en `en`.
- **CA-015-13b Puerta de publicación** *(amplía CA-012-05)*
  - **Dado** la comprobación automática de la 012
  - **Cuando** se ejecuta
  - **Entonces** **falla** si **cualquiera de las tres direcciones** no cumple **todo** lo de CA-012-05 y de su implementación actual: es `https` y no lleva usuario ni contraseña; no lleva puerto, ni IP (tampoco en forma hexadecimal o numérica), ni dominio sin punto; no tiene un dominio reservado ni un subdominio de uno (RFC 2606 y 6761: `example.com`, `example.org`, `example.net` y sus subdominios, `.example`, `.test`, `.invalid`, `localhost`, `.local`, `.internal`, `.lan`, `.localdomain`, `.onion`, `home.arpa`, `yourdomain.com` y los `xn--` de prueba: la lista de 012-S5 se **fija aquí**, no se deja al plan); no tiene espacios ni caracteres de control, ni `?`, `#` o `\`; **una clave ausente, vacía o que no es texto es un error**; el host es **solo ASCII** (un nombre internacional va en *punycode*, nunca con caracteres no ASCII); y **ninguna es idéntica a otra** de las tres **[Suposición]**: se normaliza (host en minúsculas y sin punto final; ruta sin la barra final, de modo que `/privacy` y `/privacy/` coinciden) y se compara el par host + ruta.
  - **La política** publicada, aparte, también hace fallar la puerta si sigue con huecos (`[NOMBRE DE LA APP]`, `[FECHA]`, `[RESPONSABLE]`, `[CONTACTO]`, como CA-012-05).
  - Con una compilación de desarrollo o local no falla. **[Suposición]** Hasta que exista el trabajo de CI de la publicación (F6/020), se aplica a mano en `/release-checklist`, que incluye las tres direcciones y que coinciden con las de la ficha de la tienda, y que **ejecuta `tools/check-release-config.sh` antes de cada entrega a testers, no solo antes de publicar** (en una entrega a testers con marcadores se anota qué falla; antes de publicar tiene que pasar).
  - **Verificable:** un test con **un caso por cada fallo de la lista y por cada una de las tres claves**, cuyo mensaje dice qué clave falla; y el test de que ninguna puerta es "más permisiva que `privacyLink`" cubre las tres.
- **CA-015-14a Licencias de terceros: fuera de la app** *(D26, P-5; ADR-0026)*
  - **Dado** la compilación *release*
  - **Cuando** se recorren todas las pantallas
  - **Entonces** **no existe ninguna pantalla de licencias dentro de la app**: se retiran la lista y el texto de una licencia de la 012. Las licencias se ven **solo** en la web de "Licencias de terceros". Los textos que las licencias de lo redistribuido exigen acompañar **siguen yendo en el paquete, sin mostrarse** (comprobado en CI por `tools/check-licenses.sh`; ADR-0026; **enmienda a la redacción anterior**, que decía que el paquete no los incluía; qué ficheros son, en el anexo).
- **CA-015-14b El archivo de avisos está completo**
  - **Dado** el repositorio
  - **Cuando** corre CI
  - **Entonces** **falla** si el **archivo de avisos de terceros** (el que se publica en la web) no cubre cada paquete de Dart de *release*, cada fuente empaquetada, cada biblioteca nativa de terceros, el motor de Flutter y las bibliotecas de Android. Se verifica **sobre el archivo emitido**, no sobre la lista de dentro del APK. La comprobación no puede saber qué se ha publicado: `/release-checklist` añade el paso "la web de licencias publica este archivo, el de esta versión". Cómo se emite, nombre y dónde lo deja CI, en el anexo y en el plan.
  - **Consecuencias aceptadas por el propietario (P-5)**, que se registran en el ADR-0026: sin conexión las licencias **no se ven** (P3), y hay un riesgo de cumplimiento (MIT, BSD y Apache piden acompañar la distribución con sus avisos): mientras la web sea un marcador, la app no se puede publicar (CA-015-13b).
- **CA-015-15 La tarea de debajo no cambia** *(CA-012-14 y CA-014-07, ahora con Ajustes)*
  - **Dado** una tarea con web, con PDF o con imagen, con el menú abierto
  - **Cuando** se abre Ajustes y se cierra (o se abre una web en el navegador y se vuelve en menos de 10 minutos)
  - **Entonces** el PDF conserva su página y su zoom y la imagen no cambia. La página web **vuelve a hacer la petición** (se recarga y **se borra su sesión**, ADR-0016) **al volver**, como tras el editor o el listado (CA-009-07, CA-009-13): Ajustes tapa la tarea y eso cuenta como salir de la página.
- **CA-015-16 Volver desde el navegador** *(CA-012-06)*
  - **Dado** que el usuario abrió una web desde Ajustes
  - **Cuando** vuelve a la app **y la app sigue viva**
  - **Entonces** aplica CA-001-12: con menos de 10 minutos ve la misma pantalla (Ajustes abierto); con 10 minutos o más, la tarea actual, con el foco del lector en el **botón de menú** **[Suposición]**. Si el sistema cerró la app entretanto, se ve la tarea actual (CL-015-5).

### Resto de criterios

- **CA-015-17 Sin esquema, permisos ni dependencias nuevos**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior
  - **Entonces** el esquema de datos no cambia, no hay permisos nuevos, no hay dependencias nuevas, no hay analítica ni conexiones nuevas hechas por la app, y lo único que se guarda de esta pantalla son los dos ajustes de CA-015-05 y CA-015-08 (idioma y pantalla siempre activa), **solo en la tabla `settings`**. Los ajustes no contienen contenido de tareas (T-2). Esto **sustituye a CA-012-08** ("no se guarda nada de esta pantalla").
  - **Verificable por diff** contra la versión anterior:
    - `pubspec.yaml`, `pubspec.lock`, `AndroidManifest.xml` y `res/xml/*` **sin cambios**;
    - `tools/check-android-permissions.sh release` da **solo `INTERNET`**;
    - `schemaVersion` y la captura de `drift_schemas` **sin cambios**, y un test de que en `settings` solo existen las claves `locale` y `keepScreenOn` de esta pantalla;
    - **ningún código nativo nuevo**, tampoco en `LinkOpener.kt` (lista exacta: ninguno; la pantalla encendida y los enlaces usan los canales `una/screen` y `una/links`, que ya existen);
    - **prohibido** `shared_preferences`, `wakelock_plus` y declarar `url_launcher` como dependencia directa (hoy es transitiva de `pdfrx`).
- **CA-015-18 "Recientes" (spec 011)**
  - **Dado** cada pantalla nueva: Ajustes, la página de Idioma y la confirmación de enlace
  - **Cuando** se aplica la prueba de CA-011-01 (con la matriz de CA-011-02: sustituyen a las filas de la 012)
  - **Entonces** "Recientes" no muestra nada de ellas. El **plan** dice **cómo** se visita cada una con `tools/check-recents.sh` y `docs/testing.md`. La eliminación pendiente se confirma (`commit()`, CA-015-24) **antes** de empujar la ruta de Ajustes.
- **CA-015-19 Diseño: tokens y componentes**
  - **Dado** el tablero 16
  - **Cuando** se implementa
  - **Entonces** sale de los tokens y de los componentes existentes; **el color del interruptor encendido (`#FFDC58`) es un token nuevo** (D22, P-13); **`validate-tokens` declara y comprueba los pares de CA-015-03** (borde de la pista / papel y borde del pomo / relleno de la pista, ≥ 3:1, como contraste no textual, WCAG 1.4.11) además de `textMuted` / papel para el subtítulo (≥ 4,5:1), el color de los **avisos de error** sobre el papel (≥ 4,5:1, texto), la línea inferior de "Como el sistema" (`textMuted` sobre papel, ≥ 4,5:1) y la **marca de selección** de CA-015-07 (≥ 3:1); y se registra DEV-52. Nada de valores sueltos.
- **CA-015-20 Lector de pantalla**
  - **Dado** TalkBack activo
  - **Cuando** se recorre cada nivel
  - **Entonces**:
    - **(a)** el título es un **encabezado** y lo primero que se lee (foco al llegar, tabla);
    - **(b)** el icono se anuncia "Cerrar ajustes" y, en el nivel 2, "Volver";
    - **(c)** **Idioma** se lee como botón con su valor ("Idioma, Español"); el valor lleva su propio idioma (CA-015-11);
    - **(d)** **Pantalla siempre activa** se lee como **interruptor** con su estado (activado o desactivado) y el subtítulo; el cambio de estado lo anuncia el propio sistema, sin anuncios extra de la app. **[Suposición]**: que TalkBack lo anuncie así con un único nodo y `toggled` se comprueba en el dispositivo (casilla de la 022);
    - **(e)** "Información" es un encabezado; las tres filas de web son botones cuyo nombre **incluye** que **abren una página web en el navegador** (no solo una pista, que TalkBack puede omitir);
    - **(f)** en la página de Idioma, cada opción dice su nombre y si está **seleccionada**, y "Como el sistema" dice también el idioma que resulta; el nodo de cada opción **lleva su marca de idioma** (CA-015-11). **[Suposición]** que TalkBack lo lea con la voz de ese idioma se comprueba en el dispositivo (casilla de la 022);
    - **(g)** el orden de lectura es **título → filas en su orden visual, con cada aviso donde se ve** (el de guardado bajo su fila; el de enlace tras Ayuda) **→ Cerrar o Volver**, lo último (como CA-013-05); ningún nodo enfocable queda sin nombre. La prueba de semántica fija este orden con **los dos avisos a la vez**;
    - **(h)** al elegir un idioma, el foco vuelve a "Idioma" y se lee su valor nuevo (CA-015-08); el foco al volver del navegador y de la confirmación es la fila que se tocó;
    - **(i)** Ajustes es **modal**: con él abierto, **ningún nodo de la tarea de debajo es alcanzable**, ni el nivel 2 deja alcanzable el nivel 1.
  - **Verificable:** `tester.getSemantics` y las guías `meetsGuideline` (`textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`) en Ajustes, la página de Idioma y la confirmación de enlace. `androidTapTargetGuideline` mide 48 dp: los **≥ 44 pt visibles** se comprueban además con un test de tamaño o con un *golden*. `textContrastGuideline` puede fallar en falso con las fuentes reales en texto pequeño (`CLAUDE.md`): el contraste lo garantiza `validate-tokens`. `iOSTapTargetGuideline` no se pide (iOS fuera de alcance, D17; casilla para cuando se retome). **Solo a mano** (casillas de la 015 y la 022): el foco real de TalkBack, el orden de lectura a oído, la voz del idioma elegido, el anuncio único de los avisos y su repetición en el segundo fallo, que al fallar el guardado del interruptor TalkBack no diga "activado" y luego "desactivado", el foco al volver del navegador y de la confirmación.
- **CA-015-21 Teclado y conmutadores**
  - **Dado** teclado físico o Switch Access
  - **Cuando** se recorre y se activa
  - **Entonces**:
    - **(a)** el foco del teclado empieza en **Cerrar ajustes** (o **Volver**) y sigue por las filas; el título no entra en ese orden (solo es foco del lector, tabla); Switch Access sigue el orden del lector (CA-015-20g);
    - **(b)** se ve el anillo de foco; Intro y la barra espaciadora activan (también el interruptor);
    - **(c)** Escape sube un nivel;
    - **(d)** todo se puede hacer sin arrastrar ni pellizcar;
    - **(e)** con Ajustes abierto, el foco no puede salir a la tarea de debajo;
    - **(f)** cuando el foco llega a una fila, la pantalla **la desplaza a la vista** (`ensureVisible`; WCAG 2.4.11), también con el texto al 200 %, **y el aviso que aparece** (CA-015-12b y 25);
    - **(g)** Tab y Mayús+Tab **circulan dentro de Ajustes** (desde la primera fila, Mayús+Tab va a Cerrar o Volver; desde este, a la última fila): el foco no sale (21e). El orden de Tab (Cerrar arriba) y el del lector (Cerrar al final) **difieren a propósito**: el primero sigue el orden visual y el segundo la decisión de la 013; Switch Access sigue el del lector. **Escape con la confirmación de enlace abierta la cierra** (como "Cancelar") en lugar de subir un nivel.
  - **Verificable:** un test de widgets recorre con Tab y comprueba el orden, `ensureVisible` y que Escape sube un nivel. **Solo a mano:** el anillo de foco con un teclado real y Switch Access.
- **CA-015-22 Texto grande y movimiento**
  - **Dado** el texto del sistema al 200 %, en móviles de 360 dp de ancho, **en español y en inglés** (CA-010-12), y "reducir movimiento" activo o no
  - **Cuando** se muestran Ajustes (con todas sus filas y los avisos de error), la página de Idioma (con "Como el sistema" y su línea inferior) y la confirmación de enlace
  - **Entonces** no hay cortes, solapes ni desbordamientos (la pantalla se desplaza); la fila "Idioma" y la página de Idioma pasan el valor o la línea inferior a una segunda línea sin recortar (CA-015-06 y 07); los objetivos cumplen CA-015-01a; y la subida de Ajustes, los fundidos entre niveles y el movimiento del pomo son instantáneos con "reducir movimiento" (CA-015-01d).
  - **Verificable:** *goldens* y desbordamientos al 200 % en ES y EN con `setUpAll(loadAppFonts)` (`test/support/fonts.dart`), más `androidTapTargetGuideline`. **Solo a mano:** 200 % en el móvil con la navegación de tres botones.
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
  - **Entonces** **el cambio no se aplica**: la app no cambia de idioma y la pantalla no queda fija; el control **se queda en su valor anterior** (no llega a cambiar: CA-015-03), la app sigue funcionando y se ve "No se pudo guardar el ajuste." bajo la fila (en la página de Idioma, bajo las tres opciones) como región viva (CA-015-12, "Los avisos"), sin mover el foco; en el idioma, la página se queda abierta con la opción anterior marcada **[Suposición]**.
  - **El error se captura sin registrarlo**: no se deja en `FlutterError`, no se escribe en ningún registro y **no se muestra su texto** (como `UndoController`, spec 014). **Verificable:** un test que lanza `Exception('texto-secreto')` en el guardado instala un `runZonedGuarded` (o sustituye `PlatformDispatcher.onError`), captura `debugPrint` y `print`, y comprueba que el texto no aparece en la pantalla ni en ninguno de esos canales y que `FlutterError.onError` no recibe nada. **Dos guardados del interruptor que se solapan se serializan** (o el segundo toque se ignora mientras uno está en curso): lo último que se ve es lo último que se guardó.

- **CA-015-27 Textos en español e inglés** *(P7)*
  - **Dado** los textos nuevos de §7
  - **Cuando** corre CI
  - **Entonces** cada clave existe en los dos ARB (ES y EN) con su descripción, ninguna visible o anunciada está incrustada en el código, y las claves retiradas de §7 ya no están en ninguno (si nada más las usa). **Verificable:** el test de claves de ES y EN sin huecos y el lint de literales (`docs/architecture.md`), más `/i18n-check`.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-015-1 | Doble toque rápido en "Ajustes", en una fila o en una opción de idioma | Se abre o se aplica una sola vez |
| CL-015-2 | Se gira el móvil con Ajustes abierto | Se queda en vertical: solo gira la tarea actual con imagen, PDF o web (D10, CL-012-3). Al volver a la tarea, vale lo que ya hace la app. **[Pendiente]** WCAG 1.3.4: valorar una excepción general a la orientación en un ADR; no es de esta spec |
| CL-015-3 | Se completa o elimina la tarea con Ajustes abierto | No se puede: Ajustes tapa la tarea (el menú ya se cerró al abrirlo, CA-015-01a). Nada cambia al volver |
| CL-015-4 | Sin ninguna tarea ("Todo hecho.") o en la bienvenida | **No hay forma de abrir Ajustes**: el menú solo existe sobre una tarea, igual que la pantalla de la 012. Se llega a Ajustes al crear una tarea. **Aceptado por el propietario (Q-015-5, 2026-10-05):** "Todo hecho." se queda como está, sin menú. **Límite conocido para la beta:** quien usa TalkBack con un idioma que no entiende no puede cambiarlo hasta crear una tarea; y las tiendas pueden exigir la política accesible sin crear antes una tarea (**[Pendiente]** F6/023) |
| CL-015-5 | El sistema cierra la app con Ajustes abierto (p. ej. mientras se ve el navegador) | Arranque normal a la tarea actual: **Ajustes no se restaura** (tampoco el menú), como CL-012-11. Los ajustes ya guardados se conservan |
| CL-015-6 | Idioma elegido y el sistema en un idioma que la app no admite (`fr`, `ca`…) | El elegido manda (CA-015-09) |
| CL-015-7 | "Como el sistema" y el primer idioma del sistema no es el que se oye mejor (`fr-FR, es-ES`) | Regla de la 010 (español); la voz de los anuncios es la del sistema (ADR-0020, CA-015-11) |
| CL-015-8 | Se apaga "Pantalla siempre activa" estando una imagen, PDF o web debajo | Al volver, la pantalla se apaga como la del sistema; sin reiniciar la app |
| CL-015-9 | Con el interruptor encendido, se gira el móvil en una tarea con imagen, PDF o web | Sigue encendida en horizontal (CA-015-04a) |
| CL-015-10 | Ajustes del sistema › Idiomas de la app (Android 13+) | La app **no aparece** en esa lista: el idioma se elige solo en Ajustes (CL-010-6; fuera de alcance, §8) |
| CL-015-11 | Sin conexión al abrir una web | La app no lo nota: el navegador enseña su propio error (CL-012-7). Las licencias no se ven (CA-015-14b) |
| CL-015-12 | La dirección configurada de una web no es `https` | No se abre nada y se ve "No hay ninguna app…" (CA-015-12c). La puerta lo impide al publicar |
| CL-015-13 | Se cambia el idioma del sistema con Ajustes abierto y "Como el sistema" | Los textos cambian sin cerrar la pantalla (CA-010-06), **también en la página de Idioma, si está abierta**: la línea inferior de "Como el sistema" muestra el idioma nuevo que resulta. El valor de la fila "Idioma" sigue siendo "Como el sistema". Con un idioma elegido, no cambia nada |
| CL-015-14 | El idioma guardado no es ninguno de los tres (dato corrupto) | Se toma "Como el sistema" y la app no falla (CA-015-26) |
| CL-015-15 | Una instalación anterior con la pantalla encendida "por defecto" | Pasa a apagada (CA-015-05); no se avisa **[Suposición]**: la beta aún no se ha repartido |
| CL-015-16 | No se puede **leer** el ajuste de idioma al arrancar | Una fila ilegible o no válida: se usa "Como el sistema" (CA-015-26) y no se ve ningún error. Una **base de datos inaccesible** (otra causa, no este ajuste): sale la pantalla de error de almacenamiento, en el idioma del sistema |
| CL-015-17 | Con un idioma elegido distinto del del sistema | Los selectores y diálogos del sistema (fotos, archivos, permisos) siguen en el idioma del sistema, como CL-010-2 |
| CL-015-18 | Se restaura una copia de seguridad en otro móvil (D14) | Los dos ajustes (idioma y pantalla siempre activa) viajan con la copia; si el valor de idioma no es válido, CA-015-26 **[Suposición]** |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin app para abrir el enlace | No hay navegador, o la dirección no es `https` | "No hay ninguna app para abrir este enlace." bajo el bloque de Información y Ayuda, como región viva (CA-015-12b) |
| No se pudo guardar | Falla la escritura de un ajuste (CA-015-25) | "No se pudo guardar el ajuste." bajo la fila, como región viva, y el control se queda en su valor |
| Vacío | No aplica: Ajustes siempre tiene sus filas | — |

## 6. Accesibilidad

Los criterios están en CA-015-20 a 22. Además:

- Sin gestos: todo son toques; el atrás del sistema equivale a Volver o Cerrar. La subida de la pantalla no es un gesto.
- Contraste: solo con colores de los tokens (`validate-tokens`); los pares del interruptor, en CA-015-03 y 19.
- **Voz con el idioma elegido (CA-015-11):** el caso nuevo y habitual es sistema en un idioma y app en otro. El contenido y la interfaz se leen bien (llevan su idioma); los anuncios del sistema, las palabras de rol y estado, las acciones y los títulos de las hojas, no. Los avisos de error propios no entran en la excepción: son regiones vivas con la marca de idioma de la app (CA-015-12). **Excepción a P6** (WCAG 3.1.2) que ya existe en la constitución 1.5 y que el ADR-0023 amplía de "idiomas del sistema que no son ES ni EN" a "cuando el idioma de la app no es el primer idioma del sistema" (constitución 1.7, con la aprobación del propietario). Se comprueba a oído con TalkBack en el móvil, con el sistema en inglés y la app en español y al revés (casilla de la 022).
- Se revisa con `a11y-reviewer` antes de aprobar el plan, con TalkBack en el emulador al implementar, y entra en la auditoría en dispositivo (spec 022). **VoiceOver** queda fuera de alcance (D17): se anota la casilla para cuando se retome iOS.

**Trazabilidad de los principios de la constitución**

| Principio | Criterios |
|---|---|
| P1 Una tarea a la vez | CA-015-01a, 02, 24, CL-015-3 (Ajustes solo se abre desde el menú de la tarea y vuelve a ella) |
| P2 Instantáneo al abrir | CA-015-10, 23 |
| P3 Local y sin conexión | CA-015-14a, 14b (y la nota de la constitución 1.7) |
| P4 Privacidad por defecto | CA-015-12a, 13a, 17 |
| P5 Seguridad desde el diseño | CA-015-12a, 13a, 13b, 17, 25, 26 |
| P6 Accesible siempre | CA-015-01d, 03, 11, 12, 20, 21, 22, 25 |
| P7 i18n desde el primer día | CA-015-07, 09, 11, 27 y §7 |
| P8 La especificación manda | esta spec, su revisión y §10 |
| P9 Nada está hecho sin tests | las líneas "Verificable" de los criterios |
| P10 Preparado para crecer | CA-015-01c (estructura de bloques que admite 017 y 019), CA-015-26 |
| P11 Dependencias con criterio | CA-015-17 |
| P12 El prototipo es la referencia | CA-015-01b, 03, 19 y DEV-52 |

## 7. Textos (ES / EN)

Claves nuevas (camelCase; se añaden con `/strings-add`). Los nombres de los idiomas son iguales en los dos ARB y llevan su `locale`.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `menuSettings` | Ajustes | Settings | **Cambia** ("Configuración y perfil" / "Settings and profile"): enlace del menú (CA-015-01a) |
| `settingsTitle` | Ajustes | Settings | Encabezado de la pantalla |
| `settingsClose` | Cerrar ajustes | Close settings | **Cambia** ("Cerrar" / "Close"): icono del nivel 1, como el prototipo |
| `settingsLanguage` | Idioma | Language | Fila y título del nivel 2 |
| `settingsLanguageSystem` | Como el sistema | Same as system | Valor por defecto y primera opción (CA-015-06/07) |
| `languageSpanish` | Español | Español | Opción y valor; marcado `es` |
| `languageEnglish` | English | English | Opción y valor; marcado `en` |
| `settingsKeepAwake` | Pantalla siempre activa | Keep screen on | Interruptor (CA-015-03) |
| `settingsKeepAwakeHint` | Imágenes, documentos y web | Images, documents and web | Subtítulo del interruptor (sin aviso añadido: decisión del propietario, 2026-10-05) |
| `settingsInfo` | Información | Information | Encabezado del bloque 3 (no pulsable) |
| `settingsPrivacy` | Política de privacidad | Privacy policy | Ya existe |
| `settingsThirdPartyLicenses` | Licencias de terceros | Third-party licenses | Sustituye a `settingsLicenses` |
| `settingsHelp` | Ayuda | Help | Fila |
| `settingsOpensWebHint` | Abre una página web en el navegador | Opens a web page in the browser | Se **incluye en el nombre** de las tres filas de web (CA-015-20e); es `settingsPrivacyHint` **renombrada** |
| `settingsSaveError` | No se pudo guardar el ajuste. | Couldn't save the setting. | CA-015-25 |

Se reutilizan `openInBrowserConfirm`, `linkConfirmOpen`, `linkConfirmCancel` y `errNoAppForLink`; bajo "Como el sistema" se reutilizan `languageSpanish` y `languageEnglish`, con su marca de idioma. **"Volver" del nivel 2** es "Volver" / "Back" (la clave la decide el plan: la `licensesBack` renombrada o una propia). Se **retiran**, si nada más los usa (lo comprueba el plan): `settingsLicenses`, `licensesTitle`, `licensesLoading`, `licensesCount`, `licensesError`, `licensesTextOf` y `licensesAndroidLibraries`.

## 8. Fuera de alcance

- **Notificaciones** (spec 019, con el spike S7 antes) y **Bloquear zoom** (spec 017): sus filas no se ven hasta entonces.
- **Las propias webs** de Política de privacidad, Licencias de terceros y Ayuda, el dominio y su alojamiento (PD-2): aquí solo hay direcciones marcador. El texto de la política (borrador en `docs/legal/privacy-policy.md`).
- **Idioma por app de Android 13+** (`localeConfig`): el idioma se elige solo en Ajustes (ADR-0023).
- Más idiomas que español e inglés (D23); ver el ADR-0020 si se añade uno.
- Versión de la app ("Acerca de"), copias de seguridad, tema y paletas, exportar e importar.
- Acceso a Ajustes sin ninguna tarea, en "Todo hecho." o en la bienvenida (CL-015-4, Q-015-5): no se añade ningún menú ahí.
- Un aviso en el subtítulo de "Pantalla siempre activa" sobre que no bloquea la pantalla (decisión del propietario, 2026-10-05: no hace falta; con una tarea solo de texto no se mantiene encendida aunque el interruptor lo esté, CA-015-04c).
- iOS (D17) y tablets (D28).

## 9. Decisiones y preguntas

**Decisiones del propietario ya tomadas (plan F4b, 2026-10-04):** orden y contenido de Ajustes (D22); idioma por defecto "Como el sistema" y elegible entre español e inglés (D23, P-3); licencias de terceros en una web (D26, P-5, contra la recomendación); pantalla siempre activa, apagada por defecto y sin límite (D10 enmendada, P-6 y P-7); direcciones marcador y puerta de publicación (D27, P-15); token nuevo `#FFDC58` (P-13); página de Idioma con los componentes existentes (P-16); al elegir idioma se vuelve a Ajustes con el foco en "Idioma" (P-19).

**Decisiones del propietario en la revisión 1 (2026-10-05):**

1. **Transición del nivel 2:** fundido de 160 ms (`sheetOut`, como la 012); con "reducir movimiento", instantáneo (CA-015-01d).
2. **Avisos de error:** regiones vivas con la marca de idioma de la app; no se usa `sendAnnouncement` y no se amplía la excepción a P6 (CA-015-12, "Los avisos").
3. **Subtítulo de "Pantalla siempre activa":** sin aviso nuevo. Con una tarea solo de texto no se mantiene la pantalla encendida aunque el interruptor lo esté (CA-015-04c).

**Preguntas resueltas** (Q-015-1 a 5, propietario, 2026-10-05):

- **Q-015-1** Voz de TalkBack con el idioma elegido: se acepta la limitación ampliada (opción 1, recomendación). Va al ADR-0023 y a la constitución 1.7; la opción de regiones vivas se retoma con la migración de R-22 o si lo señala la beta. *(Los avisos de error propios ya son regiones vivas, decisión 2 de arriba.)*
- **Q-015-2** Página de Idioma sin diseño: como se propone (CA-015-06 y 07).
- **Q-015-3** Cerrar Ajustes vuelve a la tarea: «como en el prototipo» (CA-015-02).
- **Q-015-4** El aviso de "No hay ninguna app…" (CA-015-12b): se acepta la recomendación. Sale cuando se toca Política de privacidad, Licencias de terceros o Ayuda y el móvil no tiene ninguna app (navegador) que abra la dirección; **una sola vez, debajo de las tres filas de web** (no debajo de la fila tocada).
- **Q-015-5** Sin tareas no se llega a Ajustes: se acepta (recomendación): "Todo hecho." y la bienvenida **se quedan como están, sin menú**. Quien deje la app sin tareas no puede cambiar el idioma ni leer la política hasta crear una (CL-015-4).

**[Suposición] sin pregunta** (se corrigen en la revisión si no gustan): dónde queda el foco al cerrar Ajustes (el botón de menú de la tarea) y al volver del navegador tras ≥ 10 minutos; que el foco entra en "Cancelar" al abrirse la confirmación de enlace; el comportamiento del error al guardar (CA-015-25); que no se avisa del cambio de valor por defecto de la pantalla (CL-015-15); que la web de "Ayuda" tiene también una sola dirección para los dos idiomas; que la pantalla sigue encendida con el aviso "Necesitas conexión…" de la web (CA-015-04a); que la puerta de publicación se ejecuta antes de cada entrega a testers y solo bloquea la publicación (CA-015-13b); y la comparación normalizada de direcciones idénticas. **Añadidas en la revisión 2** (recomendación en cada una; ninguna necesita pregunta nueva): que el nodo "Idioma, Español" lleve dos marcas o se separe el valor (**lo decide el plan**, CA-015-11); que el aviso "no mueve el foco y queda a la vista" (**se queda como está**, CA-015-12b); lo que TalkBack hace con `toggled` y con la marca de idioma de las opciones (**casilla de la 022**, CA-015-20d y 20f); que los ajustes de una copia de seguridad con un idioma no válido se traten como CA-015-26 (**se queda como está**, CL-015-18); que el `NOTICES` de Flutter vaya siempre en el paquete (ADR-0026, **lo confirma el plan**); que la 012-S1 no se endurezca en Kotlin (**se queda como está**, anexo y T-5).

**[Pendiente]:**

- **Revisión legal** de las licencias de terceros solo en una web (ADR-0026), **antes de F6/023**. Debe ser un **punto bloqueante** de `/release-checklist`.
- **Voz a oído** del idioma elegido (ADR-0023): casilla de la auditoría en dispositivo (022).
- **Excepción general a la orientación** (WCAG 1.3.4, CL-015-2): valorarla en un ADR; no es de esta spec.
- **Política accesible sin tareas** (CL-015-4): las tiendas pueden exigirla; F6/023.
- Antes de F6/023: el **referente** que el navegador puede mostrar al abrir las webs (`android-app://<paquete>`) y que se conecta con la IP del usuario, en `docs/legal/privacy-policy.md` y en Data Safety (§10).

**Casillas y hallazgos de la 012 que afectan a las pantallas retiradas** (se aplican al aprobar, §10):

- **Se anulan** (la pantalla ya no existe): las casillas de `specs/012-configuracion-temporal/dispositivo.md` sobre el nivel 3 y "Bibliotecas de Android", y las de "Cargando licencias…" y "Reintentar"; los hallazgos 012-A-M3 y 012-A-B3 (ya corregidos en la 013; el nodo y la lista desaparecen) y 012-T-TD1 (los cuatro `height: 1.5` de `licenses_screen.dart` y `license_detail_screen.dart` desaparecen con los archivos).
- **Pasan a la 022**, sobre Ajustes: foco de TalkBack al volver, anillo de foco con teclado real, Switch Access, reducir movimiento, 200 % con navegación de tres botones, sistema en inglés, los idiomas `ca`, `gl` y `eu`, y el aviso obsoleto (M2 de la 012).

## 10. Enmiendas a otras specs y documentos

Cada punto lleva su estado: **✅ hecho**, **✅ hecho en la PR de la corrección de la spec** (#33) o **en la de las enmiendas** (`docs/015-amendments`, solo documentación), **📋 en la PR de implementación** (se anota en el plan y en las tareas) o **🕒 más adelante**, sin PR propia.

**Ya hecho**

- ✅ **Constitución 1.7** (2026-10-05): la excepción de P6 del ADR-0020 se amplía al idioma elegido (ADR-0023); P3: nota de que la política, las licencias de terceros y la ayuda necesitan conexión (ADR-0026).
- ✅ **ADR-0020:** marcado "sustituido en parte por ADR-0023".
- ✅ **Spec 010:** CA-010-10 y CL-010-2 enmendados.
- ✅ **`docs/design/prototype-deviations.md`:** DEV-52 creada; DEV-49 marcada **sustituida**; DEV-05 y DEV-18 anotadas.
- ✅ **`docs/glossary.md`:** "Ajustes", "Pantalla siempre activa", "Idioma de la app", "Licencias de terceros", "Ayuda" e "Interruptor"; "Configuración y perfil (temporal)" y "Licencias de código abierto", marcadas como sustituidas.
- ✅ **`docs/design/screen-map.md`:** tablero 16 y la entrada del menú → 015.
- ✅ **Spec 014:** la mención de CA-014-11 («Configuración y perfil (Ajustes desde la spec 015)») ya remite a esta spec.

**✅ Hecho en la PR de la corrección de la spec (#33)**

- **`docs/security/threat-model.md`:** T-15 y §7 recogen el riesgo residual aceptado de "Pantalla siempre activa" **sin límite**: apagada por defecto, solo con imagen, PDF o web a la vista y en primer plano; el sistema retira la petición al pasar a segundo plano (CA-015-04d). Anotar también que **no bloquea la pantalla** mientras se ve contenido (D10, P-6).
- **`docs/glossary.md`:** el identificador `Settings` estaba en dos filas ("Configuración" y "Ajustes"); queda solo en "Ajustes". Se añade **"Confirmación de enlace"**.
- **`docs/design/prototype-deviations.md`, DEV-52:** el separador de 1 px (`rgba(17,17,17,.18)`, que no es un token; la DEV-38 usó el token `disabled`); **reducir movimiento** (el prototipo no lo contempla); el **orden de lectura** con Cerrar al final (decisión de la 013 frente al prototipo); el fundido entre niveles.
- **Esta spec:** §10 con su estado, §9 y los criterios.

**✅ Aplicadas tras aprobar la spec** (PR `docs/015-amendments`, 2026-10-05). Cada enmienda lleva la etiqueta «Enmienda 2026-10-05 (spec 015, aprobada; se aplica al implementarla)»: hasta entonces, la app sigue haciendo lo que dice la spec original.

- **005:** CA-005-09 (el enlace pasa a llamarse "Ajustes" y abre la pantalla de la 015, **cerrando el menú**; antes, sin cerrarlo, la de la 012), CA-005-01 (el enlace subrayado), CA-005-12 ("como Configuración y perfil" como referencia de estilo) y la tabla de textos (`menuSettings`).
- **001:** su mención de "Configuración (spec futura de Configuración y perfil)" pasa a Ajustes (spec 015).
- **007, 008 y 009:** CA-007-12, CA-008-13 y CA-009-16 (y el nombre del ajuste de la 007, "Mantener la pantalla encendida con adjuntos", "por defecto sí"): la pantalla encendida pasa a ser el ajuste "Pantalla siempre activa", **apagado por defecto** y, encendido, **sin límite de tiempo** (ya no los 10 minutos sin tocar ni el conteo de toques).
- **010:**
  - CA-010-01, 02 y 06 y CL-010-2 y 4: valen para "Como el sistema"; con un idioma elegido, la app no mira el sistema.
  - CL-010-5, 6 y 7 y §8: el selector manual **existe** (esta spec); CL-010-7 ya no habla de "Configuración y perfil"; y **"Ajustes" pasa a "Ajustes del sistema"** donde se hable de los de Android (CL-010-5 y 6).
  - CA-010-07 y CA-010-12: las pantallas que se recorren son Ajustes y la página de Idioma (ya no los tres niveles de la 012).
  - CA-010-03 ("pasa a la spec futura": la implementa la 015), la cabecera ("sin selector") y §9 ("elegidos por el sistema").
  - CA-010-06: en un punto, la web se recarga (CA-015-08).
- **011:** CA-011-02 y la matriz: Ajustes y la página de Idioma sustituyen a las filas de "Configuración y perfil", la lista de licencias y el texto de una licencia.
- **012:** **sustituida** por esta spec (CA-012-01 a 03, 06, 07 y 09 a 16 y las pantallas de licencias; **CA-012-08 → CA-015-17**). Siguen, ampliadas, el patrón de la política en el navegador (CA-012-04 → CA-015-12) y la puerta de publicación (CA-012-05 → CA-015-13). Pasa a **Sustituida por la spec 015** cuando se implemente. Tabla de correspondencia 012 → 015:

  | 012 | 015 |
  |---|---|
  | CA-012-01 | CA-015-01a y 01b |
  | CA-012-02 | CA-015-02 |
  | CA-012-03 | CA-015-14a (retirado: textos de licencia dentro de la app) |
  | CA-012-04 | CA-015-12a a 12c |
  | CA-012-05 | CA-015-13a, 13b |
  | CA-012-06 | CA-015-16 |
  | CA-012-07 | CA-015-09 y 11 |
  | CA-012-08 | CA-015-17 |
  | CA-012-09 | CA-015-18 |
  | CA-012-10 | CA-015-19 |
  | CA-012-11 | CA-015-20 |
  | CA-012-12 | CA-015-21 |
  | CA-012-13 | CA-015-22 |
  | CA-012-14 | CA-015-15 |
  | CA-012-16 | CA-015-23 |
  | CA-012-15 | retirado (estados de carga y error de las licencias) |

- **013:** CA-013-01 y CA-013-02 (nombre de las bibliotecas de Android y cambio de idioma con licencias abiertas) quedan obsoletas con las pantallas de licencias; CA-013-04 y 05 (nodos sin nombre y orden del lector, hoy sobre "los tres niveles de la 012") se aplican ahora a Ajustes (CA-015-20).
- **014:** "Configuración y perfil" pasa a "Ajustes" en la cabecera, la línea de dependencias y CL-014-13 (CA-014-11 ya remite a la 015).
- **Casillas y hallazgos de la 012** (§9): se anulan o pasan a la 022 en `specs/012-configuracion-temporal/dispositivo.md` y en `docs/PLAN.md` («Hallazgos de la 012 para la auditoría de F5»).
- **`docs/PLAN.md`:** D10, D13 y D22–D27 ya reflejados; trazabilidad R15 y R18; fila de la 015 en F4b; §9 siguiente paso.

**📋 En la PR de implementación** (se anota en el `plan.md` y en las tareas correspondientes)

- **`docs/security/checklist.md`:** la sección «Si abre enlaces externos o muestra licencias y política» se **reduce a solo el enlace** (ADR-0026): se retira «Los textos de licencia son `Text` plano» y se añaden los puntos de CA-015-12 y 13 (direcciones constantes de compilación, sin consulta ni fragmento, puerta con las tres) y de CA-015-26 (valores ilegibles).
- **`tools/check-licenses.sh`:** actualizar los comentarios de las líneas 2-3 y 168, que aún dicen «pantalla de licencias»; ver también el anexo.
- **`.claude/skills/release-checklist/SKILL.md`:** las tres direcciones, que coincidan con la ficha de la tienda, `tools/check-release-config.sh` antes de cada entrega a testers, y "la web de licencias publica el archivo de esta versión".
- **`docs/architecture.md`, `docs/testing.md` (cómo se visita Ajustes con `tools/check-recents.sh`, CA-015-18), `identity.yaml`, `tools/check-release-config.sh`** y `tool/check_release_config.dart`: los cambios que diga el plan.
- **`docs/design/screen-map.md`:** cualquier ajuste que pida el plan.

**🕒 Más adelante, sin PR propia**

- **`docs/legal/privacy-policy.md` y Data Safety (F6/023):** nota del referente: "al abrir la web, el navegador se conecta; la app no envía nada"; y los ajustes que viajan en la copia de seguridad.
- **`/release-checklist`:** la **revisión legal** de ADR-0026 como punto bloqueante, antes de publicar.
- **Memoria `una-project-context`:** al cerrar la 015.

## Anexo: notas para `plan.md` (no normativas)

- **Términos técnicos fuera de los criterios:** el ajuste de idioma es la clave `locale` y el marcado de idioma del lector es `localeForSubtree` (CA-015-11); el esquema de datos no cambia porque los ajustes ya son clave y valor (CA-015-17); el idioma elegido y el interruptor se leen junto con el resto de ajustes que ya se leen al arrancar (CA-015-10, 23).
- **Ajustes ya existentes [Hecho]:** la tabla `settings` (clave y valor) ya tiene reservadas `locale` (`system | es | en`) y `keepScreenOn` (`docs/architecture.md`); el repositorio ya lee `keepScreenOn` al arrancar (`bootStateProvider`). **No hace falta migración**: hay que **escribir** los dos valores y **leer** `locale` en el mismo arranque (CA-015-10), y cambiar el valor por defecto de `keepScreenOn` a `false`.
- **Lectura de ajustes (CA-015-26):** hoy `keepScreenOn()` (`data/drift_task_repository.dart`) hace `jsonDecode` sin `try/catch` y devuelve `row == null || valor != false` (se queda encendida ante cualquier valor raro); `BootState.keepScreenOn` (`app/providers.dart`) vale `true` por defecto. Los dos cambian: `try/catch` que da el defecto, y "encendida" solo si el valor es exactamente `true`. El idioma se valida contra `system|es|en` antes de construir nada.
- **Pantalla encendida:** `KeepScreenOnController` (`features/attachments/keep_screen_on_controller.dart`) tiene `idleLimit` de 10 minutos, `touched()` y un `Listener` de toques en `una_app.dart`: se quitan (CA-015-04a). `setEnabled` ya existe y hay que conectarlo al ajuste. La petición es el flag de ventana del canal `una/screen` (`data/platform/screen_awake.dart`), **sin `WAKE_LOCK`**; ante `paused` y `hidden` se limpia (`keepOn(false)`; CA-015-04d). El nombre de la clave del canal falso, en el plan.
- **Idioma:** `resolveAppLocale` (`app/locale_resolution.dart`) es la regla de la 010 y pasa a usarse solo con "Como el sistema". La app declara `localeListResolutionCallback`; con `es` o `en` elegidos se fija el idioma. `appFrame` ya marca `localeForSubtree` con el idioma de la app (CA-010-10). El manifiesto ya tiene `locale|layoutDirection` en `configChanges`, así que cambiar el idioma no recrea la actividad. Orden de CA-015-08: guardar → `pop` de la página de Idioma → aplicar el idioma → pedir el foco.
- **Navegación y transiciones:** Ajustes y la página de Idioma son rutas a pantalla completa como las de la 012 (`features/settings/`), pero **la ruta se abre cerrando la hoja del menú** (tablero 16: `sheet: null` a los 220 ms), no sobre ella. El fundido entre niveles es `UnaMotion.sheetOut` (160 ms) como en la 012. Se retiran `LicensesScreen`, `LicenseDetailScreen`, `licensesProvider`, `FlutterLicenseSource` y lo que solo usaban. Los *goldens* de la 012 se sustituyen por los de Ajustes.
- **Archivo de avisos y textos de licencia (CA-015-14a y 14b):** **[Hecho, ADR-0026]** los assets de `bundled_licenses` (`assets/licenses/*.txt`), los `OFL.txt` de las fuentes y el `NOTICES` de Flutter **siguen declarados** en `pubspec.yaml` y dentro del APK; solo se retira el código que los leía (`registerBundledLicenses`). La OFL de las fuentes pide que cada copia lleve su licencia, y Apache y BSD piden acompañar lo que se redistribuye. **[Suposición, ADR-0026]** que el `NOTICES` va siempre en el paquete. `tools/check-licenses.sh` conserva sus comprobaciones (también que los `.txt` y los `OFL.txt` siguen en `pubspec.yaml` y en el APK) y además **emite el archivo de avisos del APK de *release* que ha pasado esa comprobación**: cabecera con **versión, fecha y sha256 del APK**; el `NOTICES` descomprimido, los tres `.txt` y los `OFL`; una entrada por paquete, `.so`, artefacto y fuente. Se **adjunta a la release** (el artefacto de CI caduca). Nombre y lugar, los decide el plan. Actualizar los comentarios del script (líneas 2-3 y 168).
- **Interruptor:** componente propio con tokens (P12; el `Switch` de Material no sirve). Una fila `SheetRow`-like con rol de interruptor y `toggled`, anillo de foco y un solo nodo semántico. Token nuevo para el amarillo encendido; los pares de CA-015-03 en `validate-tokens` (que ya tiene contraste no textual de 3:1).
- **Enlaces:** el canal `una/links` y `NativeLinkOpener` ya comprueban "hay app que lo abra" y abren; solo hay que repetir el patrón de CA-012-04 con tres direcciones, con una única función. `identity.yaml` gana `thirdPartyLicensesUrl` y `helpUrl` junto a `privacyPolicyUrl`; `tool/check_release_config.dart` valida las tres (012-S5 se puede arreglar aquí: ampliar los dominios reservados). **012-S1** (`LinkOpener.kt` no mira `userInfo` ni `host` en la rama web): **no se endurece en esta spec** (CA-015-17: ningún código nativo nuevo); con tres enlaces que son constantes de compilación validadas en Dart (`privacyLink`, CA-015-13) sigue sin ser explotable, y queda anotado como **riesgo residual aceptado** en `threat-model.md` (T-5). Si se quisiera endurecer, hay que relajar CA-015-17 con una excepción nominal a `LinkOpener.kt`, verificable por diff. **[Suposición]**
- **Referente:** el navegador puede mostrar al destino el referente `android-app://<paquete>`; se refleja en la política y en Data Safety (§10).
- **Recientes:** ya hay `tools/check-recents.sh`; hay que añadir las filas nuevas a su matriz y a la de CA-011-02, y el plan dice cómo se visita cada pantalla (CA-015-18).
- **Una sola sesión de spec, otra de plan:** los ADR-0023 y ADR-0026 ya están aceptados (2026-10-05); el plan los desarrolla (como el ADR-0021 en la 014).
