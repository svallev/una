# Spec 025: Landing de producto

- **Estado:** **Aprobada** (propietario, 2026-11-12: «aprobada», tras responder Q-025-1, 2, 5, 6 y 8 a 13 con la opción recomendada y aprobar los textos nuevos del §7; quedan Q-025-3, antes de F6, y Q-025-4 y 7, del plan). Antes **Borrador** (2026-11-12; revisión del `spec-reviewer` aplicada el mismo día: 4 bloqueantes, 19 importantes y 12 menores; sin aplicar, por menores, la renumeración de los CA y seis términos del glosario)
- **Reglas de producto:** R1 (una tarea a la vez), R8 (abrir y ver la tarea actual con su adjunto), R15 (idioma) y R18 (Ajustes: pantalla siempre activa y bloquear zoom): la landing las **cuenta**, no las cambia.
- **Pantallas del prototipo:** **sin diseño en el prototipo.** El diseño es el de la maqueta hecha con el propietario entre el 2026-11-11 y el 2026-11-12 (carpeta `UnaWeb/www`, versión A), que esta spec describe; se registra como desviación **DEV-59** en `docs/design/prototype-deviations.md` al implementar. Las pantallas de la app que la landing enseña sí son las del prototipo (tableros de la tarea actual, el listado y Ajustes).
- **Decisiones y ADR relacionados:** ADR-0009 (monorepo y `landing/`; **enmendado por el ADR-0027**), **ADR-0027** (herramientas y bibliotecas de la landing, **Propuesto**), ADR-0010 (Vercel), ADR-0026 (licencias de terceros; **la página de licencias publica además los avisos del código de la web**, §10), D17 (Android primero), P-012-2 (una sola dirección para ES y EN), spec 023 (webs de la app; **enmendada en el §10**).
- **Dependencias:** 023 (las webs de la app en `landing/`, **Implementada**). Sin cambios en el **comportamiento** de la app: ni esquema de BD, ni permisos, ni dependencias de `app/`. El plan dice si los colores nuevos de los tokens y las direcciones de las tiendas en la identidad tocan archivos generados de `app/`.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y en el ADR-0027.

## 0. Alcance (decidido por el propietario, 2026-11-11 y 2026-11-12)

- **[Hecho]** La landing vive **en este repositorio**, en `landing/`, y no en uno aparte («Integrar en Una»).
- **[Hecho]** La página de inicio mínima de la 023 (CA-023-13) **se sustituye** por la landing. Las otras cuatro páginas (política, licencias, Ayuda y error) **no cambian de reglas**. De contenido solo cambian la política (CA-025-13) y la página de licencias (CA-025-18).
- **[Hecho]** La landing **lleva animación y el JavaScript que necesite**; las normas del repositorio que lo impedían se cambian (ADR-0027 y §10), no al revés.
- **[Hecho]** El texto de la política de privacidad que dice que las webs funcionan sin JavaScript **se cambia** (CA-025-13).
- **[Hecho]** El idioma se elige con un botón ES / EN y **la elección se recuerda** en ese navegador.
- **[Hecho]** Las dos tiendas aparecen con «Muy pronto» hasta que haya ficha publicada.
- **[Hecho]** De las dos maquetas, se queda la **A**. La B, el selector entre las dos y las propuestas descartadas **no entran** en el repositorio.
- **[Hecho]** El diseño del 2026-11-12 es la **línea base** (Q-025-1 a, propietario, 2026-11-12): el diseño final no está cerrado («de momento vamos a dejarlo así»), y los retoques posteriores que no cambien un criterio no tocan la spec.
- **[Hecho]** «Línea base» no significa «ya cumple». Lo que la maqueta **no cumple todavía** y el plan corrige: las escenas no activas quedan fuera del lector y del teclado (CA-025-15); la regla de idioma mira solo el primer idioma del navegador (CA-025-09); sin JavaScript solo dice «Activa JavaScript» (CA-025-11); admite `?lang=` y `?motion=reduce` en la dirección (Q-025-9); algunos textos de la app no son los de la app (Q-025-5); un enlace al cierre no abre en el cierre (CL-025-2); la demostración automática se repite (CA-025-07); el nombre y los colores están escritos a mano (CA-025-14); las insignias de Google están recortadas (CA-025-21); hay archivos sin usar (CA-025-21); lleva una dependencia que la versión A no usa y versiones sin fijar (CA-025-18); y la palabra destacada sobre el fondo naranja no llega al contraste (CA-025-15).

## 1. Objetivo

Que quien llega a la web de la app entienda en menos de un minuto qué hace (una sola tarea a la vez, con lo que necesitas ver siempre a mano) y quiera descargarla, con una página que se sienta tan cuidada como la app y que respete lo mismo que ella: sin rastreo, accesible y en español e inglés.

## 2. Historias de usuario

- **HU-025-1** Como persona que no conoce la app, quiero entender de un vistazo qué la hace distinta, para decidir si me interesa.
- **HU-025-2** Como persona interesada, quiero ver la app funcionando (sus pantallas reales, no dibujos genéricos) y probar su gesto principal, para saber qué me voy a encontrar.
- **HU-025-3** Como persona convencida, quiero un camino claro a mi tienda, para descargarla (o saber que llega pronto).
- **HU-025-4** Como persona que lee en inglés, quiero la página en mi idioma sin buscarlo y que se acuerde de mi elección.
- **HU-025-5** Como persona que usa lector de pantalla, teclado, texto grande o «reducir movimiento», quiero recibir el mismo contenido sin el recorrido animado.
- **HU-025-6** Como visitante, quiero que la página no me rastree ni cargue nada de otros sitios, igual que promete la app.
- **HU-025-7** Como propietario, quiero que la landing salga del mismo repositorio, con el mismo nombre, colores, textos y comprobaciones que la app, para mantener una sola cosa.

**Trazabilidad HU → CA:** HU-025-1 → CA-025-01 a 05; HU-025-2 → CA-025-06 y 07; HU-025-3 → CA-025-08 y 20; HU-025-4 → CA-025-09; HU-025-5 → CA-025-10, 11, 15 y 16; HU-025-6 → CA-025-12 y 13; HU-025-7 → CA-025-14, 17 a 19, 21 y 22.

## 3. Criterios de aceptación

### El contenido y el recorrido

- **CA-025-01** · La página de inicio es la landing
  - **Dado** la web de la app
  - **Cuando** se abre su dirección raíz
  - **Entonces** se ve la landing de producto, y siguen existiendo, en las mismas direcciones y con el mismo contenido, `/privacy`, `/licenses`, `/help` y la página de error (CA-023-13, enmendado en el §10): **cinco páginas en total**, como antes.
  - **Verificable:** test de la web construida (las cinco páginas existen; `/help` y la página de error son idénticas byte a byte a las de antes; `/privacy` y `/licenses` solo difieren en lo que piden CA-025-13 y CA-025-18).
- **CA-025-02** · Siete escenas, en este orden
  - **Dado** la landing
  - **Cuando** se recorre de principio a fin
  - **Entonces** cuenta la historia en **siete escenas**, cada una con un titular, una entradilla y lo que se ve:

    | # | Escena | Qué dice | Qué se ve |
    |---|---|---|---|
    | 1 | Portada | Una tarea a la vez | El nombre, las insignias de las tiendas, y dos móviles: el listado y la tarea actual |
    | 2 | Demasiadas | Tienes demasiadas cosas pendientes | Filas del listado sueltas, por todas partes |
    | 3 | Solo una | Solo una. Hasta que la termines | Un móvil con la tarea actual y su botón de completar, que se puede usar (el móvil de prueba, CA-025-07) |
    | 4 | Siempre a mano | Tu foto, tu PDF, tu web. Siempre a mano | Cuatro móviles en abanico: una tarea con foto, una con varias fotos, una con PDF y una con web |
    | 5 | Pantalla activa | La pantalla no se apaga | Un móvil apoyado con un adjunto a la vista, el reloj que avanza y la fila «Pantalla siempre activa» encendida |
    | 6 | Mesa de luz | Tu pantalla, mesa de luz | Un móvil tumbado con una foto, un papel encima en el que se calca la figura y la fila «Bloquear zoom» encendida |
    | 7 | Cierre | Empieza por una. | El icono de la app, las insignias de las tiendas, dos móviles (una tarea con foto y una de texto) y el pie con Ayuda, Privacidad y Licencias |

  - Hay **un** encabezado principal (el de la portada) y uno de segundo nivel por cada una de las otras seis escenas.
  - **Verificable:** test (siete escenas, su orden, sus encabezados y sus textos en ES y EN, §7).
- **CA-025-03** · Se entra en la página
  - **Dado** un navegador sin «reducir movimiento» (CA-025-10) y con JavaScript (CA-025-11)
  - **Cuando** se avanza con el scroll, la rueda, el dedo o el teclado
  - **Entonces** la sensación es de **avanzar hacia dentro**: los elementos de cada escena **aparecen pequeños y lejanos, vienen de frente, crecen y nos sobrepasan**. En concreto:
    - **no** se mueven hacia los lados ni suben desde abajo para entrar o salir;
    - al acercarse **no se funden a transparente**: salen por delante. Solo pueden venir de transparente cuando aparecen, lejos y pequeños (y, al volver hacia arriba, hacer el camino inverso);
    - dentro de una escena entran **escalonados**, uno tras otro y solapándose, no en bloque;
    - **no hay zonas muertas**: antes de que se hayan ido los elementos de una escena ya están apareciendo los de la siguiente;
    - el **color de fondo** cambia de una escena a la siguiente de forma gradual, sin saltos;
    - **única excepción:** el papel de calco de la mesa de luz **baja desde delante** y se posa sobre el móvil (llega grande y se encoge), porque es lo que cuenta la escena.
  - **Verificable:** test del guion del recorrido (en cualquier punto entre dos escenas hay al menos un elemento visible de una de las dos; ninguna pieza cambia de posición lateral ni vertical al entrar o salir; ninguna pierde opacidad mientras crece) y casilla C-025-1.
- **CA-025-04** · Cada escena, en su sitio
  - **Dado** el recorrido de CA-025-03
  - **Cuando** se deja de mover el scroll en cualquier punto
  - **Entonces** la página **se asienta sola** en la escena más cercana en **1,5 s o menos desde el último movimiento del scroll**, con sus elementos completos y el **texto pequeño nítido** (a su tamaño real, sin quedar ampliado, reducido ni a medio camino). Mientras el dedo sigue sobre la pantalla, no se mueve sola.
  - **Verificable:** test (desde una muestra de puntos intermedios, la posición final es la de reposo de una escena) y casilla C-025-1.
- **CA-025-05** · Igual de bien hacia atrás
  - **Dado** cualquier escena
  - **Cuando** se llega a ella avanzando o **volviendo hacia arriba**
  - **Entonces** en reposo se ve **completa** (todos sus textos e imágenes), sin trozos sin pintar.
  - **Verificable:** casilla C-025-2 (las siete escenas, en los dos sentidos, en cada navegador de CA-025-17).
- **CA-025-06** · Las pantallas son las de la app
  - **Dado** los móviles que enseña la landing
  - **Cuando** se comparan con la app
  - **Entonces**:
    - son **pantallas de la app** (la tarea actual con texto, con foto, con PDF y con web; el listado; la fila de Ajustes de «Pantalla siempre activa» y la de «Bloquear zoom»), con su logotipo, su menú y su botón de completar donde los tiene la app;
    - los textos que la app ya tiene son **los mismos que los de la app** en cada idioma, sin recortar (Q-025-5 a): el botón de completar, el nombre del menú, el título y la ayuda del listado, «Nueva tarea», los dos títulos de «hecho», y los nombres y subtítulos de los dos ajustes. Es una lista cerrada; el plan la fija con sus claves; si la app los cambia, la landing cambia con ella;
    - el adjunto **ocupa todo el alto** de la pantalla del móvil, sin franjas de color liso, igual que en la app;
    - el contenido de ejemplo (tareas, nombres, mapa de un campo de golf, programa de una conferencia, cartel de un festival, portada de un libro, receta, ruta) es **ficticio**: ninguna persona, marca, obra ni lugar real, y ningún dato del propietario (como CA-023-11).
  - **Verificable:** test (los textos compartidos coinciden con los de la app; los dominios que aparecen son reservados para ejemplos) y revisión del propietario anotada (C-025-3).
- **CA-025-07** · Se puede probar «mantener pulsado»
  - **Dado** la escena «Solo una»
  - **Cuando** se mantiene pulsado el botón de completar del **móvil de prueba** (con el dedo, el ratón o, con el foco en él, Intro o espacio) **1,2 s**, lo mismo que en la app (glosario, «Mantener pulsado»)
  - **Entonces** la tarea se completa como en la app (sello, la nota se rasga) y aparece la siguiente tarea de ejemplo; soltar antes lo cancela. Una **activación sin pulsación mantenida** (la del lector de pantalla, el control por voz o un conmutador) la completa también, y se anuncia que está hecha. Junto al botón, la palabra «Pruébalo» y una flecha invitan a hacerlo. Si nadie lo ha tocado, la primera vez que se llega a la escena **se completa sola una vez** (la **demostración automática**), sin anunciarse al lector; con «reducir movimiento», no hay demostración automática y completar cambia de tarea sin animación.
  - **Verificable:** test (pulsación larga, cancelación, teclado, activación del lector, una sola demostración, sin demostración con «reducir movimiento»).

### Las tiendas y el idioma

- **CA-025-08** · Insignias de las tiendas
  - **Dado** la portada y el cierre
  - **Cuando** se miran
  - **Entonces** enseñan las **insignias oficiales** de Google Play y de App Store, sin alterar y en el idioma de la página cuando la tienda la ofrece en ese idioma. Mientras una tienda **no tenga dirección** de ficha: su insignia **no es un enlace** y su texto alternativo dice «muy pronto»; mientras falte alguna de las dos, en la portada se lee **un** rótulo «Muy pronto» sobre las insignias y en el cierre lo dice la entradilla (como en la maqueta). Cuando la dirección existe, la insignia enlaza a la ficha y su texto alternativo deja de decirlo; con las dos, el rótulo desaparece. Las direcciones salen de la identidad de la app, no están escritas en la página. **[Pendiente Q-025-3]** Hasta conseguir la insignia española de App Store se admite la inglesa en la página en español, con el texto alternativo de la imagen que se ve, marcado como inglés. **[Pendiente Q-025-7]** Todo este criterio depende de que las normas de las insignias admitan enseñarlas sin ficha.
  - **Verificable:** test con dirección y sin ella (enlace, texto alternativo, «Muy pronto»).
- **CA-025-09** · Español e inglés
  - **Dado** una primera visita
  - **Cuando** se abre la landing
  - **Entonces** sale en **español o en inglés según los idiomas del navegador, con la misma regla que la app** (CA-010-02): se recorre la lista de idiomas preferidos; el primero que sea español o catalán abre en español, el primero que sea inglés abre en inglés; si no hay ninguno, inglés. Casos: `es-MX` → ES; `ca-ES, en-US` → ES; `fr-FR, es-ES` → ES; `en-GB, es-ES` → EN; `gl-ES` → EN; `eu` → EN; `de` → EN; lista vacía → EN. La elección guardada manda sobre el navegador. Un control **ES / EN** en la cabecera cambia el idioma de toda la página y **la elección se recuerda** en ese navegador para las siguientes visitas. La página declara su idioma (para el lector de pantalla y el buscador), la dirección es **una sola** para los dos idiomas (P-012-2), **sin parámetros para el idioma ni para el movimiento** (Q-025-9 a) y los dos idiomas dicen lo mismo.
  - **Verificable:** test (regla de idioma con una lista de casos, cambio, recuerdo, idioma declarado, mismas claves en ES y EN).

### Para todos

- **CA-025-10** · Reducir movimiento
  - **Dado** un sistema con «reducir movimiento» activado
  - **Cuando** se abre la landing
  - **Entonces** **no hay recorrido en profundidad** ni nada que se mueva solo: las siete escenas se leen una debajo de otra, con **todo** su contenido (textos, móviles, insignias, el móvil de prueba de CA-025-07) y con su color de fondo, con el scroll normal del navegador. Lo que en el recorrido se anima se ve en su estado final **[Suposición]**: los dos interruptores encendidos, el reloj parado y el calco terminado.
  - **Verificable:** test (con la preferencia, la página no monta el recorrido y están los siete encabezados y las insignias) y casilla C-025-4.
- **CA-025-11** · Sin JavaScript
  - **Dado** un navegador con JavaScript desactivado o en el que el programa de la página no llega a cargar
  - **Cuando** se abre la landing
  - **Entonces** se lee, **en español y en inglés** (español primero, como el resto de las webs), el nombre de la app, qué hace, sus cuatro propuestas (una tarea a la vez; foto, PDF o web siempre a mano; pantalla siempre activa; mesa de luz) dónde estará disponible (el texto del cierre) y los enlaces a Ayuda, Privacidad y Licencias; cada mitad va marcada con su idioma, como en las otras webs (CA-023-13). No hay recorrido ni móvil de prueba, y no queda una página en blanco. Con el programa en marcha, ese contenido no se ve ni se lee dos veces (CA-025-15).
  - **Verificable:** test sobre el HTML construido, sin ejecutar nada (están los textos y los enlaces), y test con el programa bloqueado y con un error forzado al arrancar (el contenido sigue a la vista, CL-025-12).
- **CA-025-15** · Accesible
  - **Dado** la landing, con el recorrido o sin él
  - **Cuando** se revisa contra WCAG 2.2 AA
  - **Entonces**:
    - con cada escena en reposo, el texto tiene contraste **4,5:1** o más con su fondo y los titulares grandes **3:1** o más, en **cada** color de fondo de las siete escenas; cuentan también la cabecera, «Muy pronto», las notas pequeñas y la palabra destacada de cada titular;
    - todo se alcanza con **teclado**, en el orden en que se lee; el foco se ve siempre, **la cabecera fija nunca lo tapa** (WCAG 2.4.11), y cuando llega a un elemento de otra escena, **esa escena se pone a la vista**;
    - el texto visible del botón de completar forma parte de su nombre para el lector (WCAG 2.5.3);
    - los móviles y las ilustraciones tienen una descripción breve de lo que enseñan, o se ocultan al lector si solo decoran; el lector recorre las siete escenas en orden sin encontrarse cosas ocultas ni repetidas;
    - se lee al **200 %** de zoom y a **320 px** de ancho sin desplazamiento horizontal;
    - la cabecera (inicio, idioma, descargar), el botón de completar y los enlaces del pie tienen un objetivo de **44 × 44** o más.
  - **Verificable:** test (contraste calculado de cada par texto/fondo, encabezados, descripciones, orden) y casilla C-025-5 (teclado, TalkBack con Chrome, zoom); `a11y-reviewer` al cerrar.
- **CA-025-16** · En móvil y en escritorio
  - **Dado** un ancho de **320 a 1920 px**, en vertical y en horizontal
  - **Cuando** se ve cada escena en reposo
  - **Entonces** su titular, su entradilla y su elemento principal (el móvil, el abanico, las insignias) se ven **enteros**, sin cortarse ni taparse entre sí ni con la cabecera, y sin desplazamiento horizontal. En pantallas estrechas pueden ocultarse elementos **secundarios** (por ejemplo, el segundo móvil de la portada), nunca el titular ni las insignias.
  - **Verificable:** casilla C-025-6 (las siete escenas a 320, 390, 768, 1280 y 1920 px, ES y EN) y test de que ningún elemento marcado como principal queda fuera de la pantalla a esos anchos.

### Privacidad, identidad y mantenimiento

- **CA-025-12** · Sin terceros ni rastreo
  - **Dado** la landing publicada
  - **Cuando** se inspeccionan sus peticiones y lo que guarda
  - **Entonces** no hay **ningún recurso de otro origen** (programas, hojas de estilo, fuentes, imágenes, vídeos, marcos), **ninguna cookie**, **ninguna analítica** (ni la del alojamiento) y **ningún envío de datos**: la página no hace ninguna petición más que las de sus propios archivos. Lo **único** que guarda es el idioma elegido (CA-025-09), en el propio navegador, sin enviarlo a ningún sitio. Los programas se cargan **solo del propio origen** y no hay ninguno escrito dentro de la página. La web publicada no lleva mapas de código ni ayudas de depuración, y nada de la dirección ni de lo guardado llega al contenido de la página sin validar (P5). **No hay estilos en línea escritos en la página**; los que el programa aplique al mover las piezas se admiten solo si el plan demuestra que no hay alternativa, y se anotan en T-18 (Q-025-10 a). Las cabeceras de seguridad siguen siendo las de CA-023-14, con el mínimo cambio para que la landing funcione; las de las otras cuatro páginas **no se relajan**.
  - **Verificable:** test de la web construida (orígenes, programas en línea, cookies, analítica, lo que se guarda) y de las cabeceras de cada página; casilla C-025-7 (panel de red del navegador).
- **CA-025-13** · La política dice la verdad
  - **Dado** `docs/legal/privacy-policy.md`, sección «Esta web»
  - **Cuando** la landing entra en `main`
  - **Entonces**, **en la misma PR**, la política deja de decir que las webs funcionan sin JavaScript y dice, en español y en inglés (CA-023-03): que la página de inicio usa un programa propio para la animación y para el idioma; que guarda **solo** el idioma elegido, en tu navegador; que no usa cookies ni analítica ni carga nada de otros sitios; y que la política, las licencias y la ayuda siguen funcionando sin JavaScript. La lista de webs de esa sección incluye la página de inicio, y las dos mitades conservan la misma estructura. La fecha de última actualización **sigue siendo el hueco `[FECHA]`** hasta F6 (CA-023-04); las notas de revisión de la política anotan el cambio y su fuente (CA-023-02).
  - **Verificable:** test de la política (las dos mitades dicen lo mismo; no queda «sin JavaScript» referido a todas las webs) y revisión del propietario.
- **CA-025-14** · Un solo nombre, unos solos colores
  - **Dado** la landing
  - **Cuando** se construye
  - **Entonces** el nombre y el logotipo salen de la **identidad de la app** (ninguno escrito a mano, P7), y los colores de fondo, de texto y de las notas, las fuentes y las medidas de la página salen de **`design/tokens.json`** (P12); los colores cálidos de fondo de la landing (magenta, naranja, amarillo), que la app no tiene, **se añaden a los tokens** como colores de la landing. Los titulares que juegan con el nombre (`heroTitle`, `oneTitle`, `endTitle` y la segunda mitad de `metaTitle`) usan la **palabra** «una», no el nombre: la comprobación los admite por lista cerrada. Quedan fuera de esta regla, porque son imágenes y no interfaz, las **ilustraciones que simulan el contenido del usuario** (la foto, el PDF, la web, el papel de calco) y las insignias de las tiendas.
  - **Verificable:** test (ningún nombre a mano; ningún color ni fuente fuera de los tokens, salvo en las ilustraciones e insignias señaladas) y `validate-tokens`.
- **CA-025-17** · Ligera y fluida
  - **Dado** una primera visita sin nada en caché
  - **Cuando** se carga la landing
  - **Entonces** todo lo que descarga pesa **600 KB o menos** comprimido **[Suposición: la maqueta ronda los 350 KB; el plan lo mide y ajusta el número antes de aprobar el plan]**, y el recorrido va **sin tirones a la vista** en Chrome de escritorio, en Chrome de Android (emulador y el Xiaomi), en Safari de macOS y en Firefox. Safari de iOS queda **sin verificar y aceptado** hasta que haya un iPhone (Q-025-11 a). Si en un navegador el recorrido no puede ir bien, ese navegador recibe la versión de CA-025-10 antes que una página rota **[Pendiente, plan: cómo se decide y qué se anota como «sin tirones» en C-025-8, por ejemplo los fotogramas por segundo de una grabación de 10 s]**.
  - **Verificable:** test del peso de la web construida y casilla C-025-8 (un navegador por fila, con lo medido).
- **CA-025-18** · Código de terceros, con criterio
  - **Dado** el código de terceros que la landing lleva al navegador o usa para construirse
  - **Cuando** se añade o se actualiza
  - **Entonces** cada pieza cumple los criterios de `docs/security/threat-model.md` §5 o tiene su excepción escrita en el ADR-0027, su versión está **fijada**, **no envía nada** a nadie, y su aviso de licencia **se publica** en la página de licencias de terceros junto a los de la app (ADR-0026), diciendo que es código de la web.
  - **Verificable:** test (versiones fijadas; cada pieza que va al navegador tiene su aviso en la página de licencias) y `security-reviewer` al cerrar.
- **CA-025-19** · En la CI, sin publicarse sola
  - **Dado** un cambio en `landing/` (incluidos sus archivos de dependencias) o en algo de lo que depende (identidad, tokens, textos de la app, política)
  - **Cuando** se abre una PR
  - **Entonces** el trabajo «Web y ficha» (CA-023-18) construye y comprueba también la landing (todos los criterios que tienen test: CA-025-01 a 04, 06 a 18, 20 y 21) sin correr los trabajos de la app, y **nada se despliega** sin el «sí» del propietario.
  - **Verificable:** test de la detección de cambios y el propio trabajo en verde.
- **CA-025-20** · Enlaces
  - **Dado** la cabecera y el pie
  - **Cuando** se usan
  - **Entonces** el logotipo vuelve a la portada; «Descargar» lleva al cierre; «Ayuda», «Privacidad» y «Licencias» abren `/help`, `/privacy` y `/licenses` de la misma web (Q-025-12 a). No hay ningún enlace a otro sitio salvo, cuando existan, las fichas de las tiendas (CA-025-08).
  - **Verificable:** test.
- **CA-025-21** · Imágenes con origen conocido
  - **Dado** cada imagen, ilustración, fuente e insignia de la landing
  - **Cuando** se revisa
  - **Entonces** es **propia** (hecha para este proyecto) o tiene su **origen y su licencia anotados** en el repositorio; las insignias son las oficiales y se usan según las normas de cada tienda (tamaño mínimo, margen, sin modificar), con la fuente y la fecha de consulta anotadas. No entra ningún archivo que la página no use.
  - **Verificable:** test (cada archivo publicado está en la lista de orígenes y se usa) y revisión del propietario.
- **CA-025-22** · Documentación al día
  - **Dado** los documentos del §11
  - **Cuando** se cierra la spec
  - **Entonces** dicen lo que hay: las enmiendas a la 023 del §10, el ADR-0027 **Aceptado**, la amenaza T-18 con la landing, la arquitectura, la checklist de seguridad, el glosario y la desviación del prototipo.
  - **Verificable:** `spec-reviewer` al cerrar.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-025-1 | Se cambia el tamaño de la ventana o se gira el móvil a mitad del recorrido | La página se recoloca en la escena en la que estaba, completa (CA-025-04 y 16). |
| CL-025-2 | Se llega con una dirección que señala el cierre (un enlace guardado o compartido) | Se abre en el cierre, con las insignias a la vista; también con «reducir movimiento» y sin JavaScript. |
| CL-025-3 | El navegador no deja guardar nada (modo privado estricto, almacenamiento bloqueado) | La página funciona igual; solo no recuerda el idioma en la siguiente visita. Sin errores a la vista. |
| CL-025-4 | El idioma del navegador no es español ni inglés | La regla de la app (CA-025-09). |
| CL-025-5 | Se cambia de idioma en mitad del recorrido | La página pasa al otro idioma y sigue en la misma escena **[Suposición; hoy vuelve a la portada: el plan lo mide y, si cuesta, se pregunta]**. |
| CL-025-6 | Se usa el teclado (flechas, espacio, AvPág, Inicio, Fin) | Avanza y retrocede por las escenas como el scroll (CA-025-04). |
| CL-025-7 | Se activa «reducir movimiento» con la página abierta | Al recargar, la versión de CA-025-10. **[Suposición]** No hace falta que cambie en caliente. |
| CL-025-8 | Solo una tienda tiene ya ficha | Esa insignia enlaza; la otra sigue sin enlace y con «muy pronto» en su texto alternativo, y el rótulo y la entradilla del cierre dicen cuál falta (CA-025-08; texto en Q-025-6). |
| CL-025-9 | La app cambia el texto del botón de completar o el nombre de un ajuste | La landing cambia con ella o el test de CA-025-06 falla. |
| CL-025-10 | Cambia el nombre de la app | La landing lo toma de la identidad (CA-025-14); se revisan las imágenes en las que se vea y los titulares que juegan con él («Una tarea a la vez», «Solo una», «Empieza por una»). |
| CL-025-11 | Se imprime la página o se abre en un lector simplificado | Se lee el contenido de CA-025-11 o el de CA-025-10; no una portada suelta. **[Suposición]** Sin hoja de impresión cuidada. |
| CL-025-12 | El programa de la página falla al arrancar | Queda a la vista el contenido de CA-025-11, no una página en blanco ni a medias. |
| CL-025-13 | El contenido de una escena no cabe entero en el alto de la ventana (pantalla baja, móvil en horizontal, zoom, texto grande, espaciado aumentado) | Se recibe la versión de CA-025-10: nada queda sin poder alcanzarse (WCAG 1.4.4, 1.4.10 y 1.4.12). |
| CL-025-14 | Se mantiene pulsado el botón de completar y se arrastra fuera, o salta el menú contextual del móvil | Se cancela sin completar y sin menú del navegador. |
| CL-025-15 | Se recarga la página o se vuelve atrás a mitad del recorrido | Se ve una escena completa, nunca a medias. |
| CL-025-16 | El idioma guardado no es un valor válido | Se ignora y se aplica la regla de CA-025-09 (dato no confiable, P5). |
| CL-025-17 | Ancho mayor de 1920 px | Las escenas se ven enteras y centradas, como a 1920 px. |
| CL-025-18 | Se amplía con el pellizco en el móvil | La página no lo impide. |
| CL-025-19 | El sistema está en modo oscuro | La página no cambia: tiene sus propios colores, como la app (spec 021). |
| CL-025-20 | La pestaña pasa a segundo plano durante la demostración automática | Al volver, la escena está en un estado completo (antes o después de completar), no a medias. |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin fichas en las tiendas | Hasta F6 | Las dos insignias con «Muy pronto» (CA-025-08) |
| Sin JavaScript o con el programa roto | CL-025-12 | El contenido de CA-025-11 |
| Antes de que arranque el programa | Un instante, en cualquier navegador | Como mucho, el contenido de CA-025-11 (español primero); el idioma declarado es correcto en cada momento **[Pendiente, plan: que no se llegue a ver un salto]** |
| Mientras cargan las fuentes o las imágenes | Conexión lenta | El titular de la portada se lee desde el primer momento, sin saltos de tamaño llamativos al llegar la fuente; las imágenes reservan su sitio |
| Dirección que no existe | — | La página de error de la 023, sin cambios |

## 6. Accesibilidad

- **Reducir movimiento:** CA-025-10. El recorrido en profundidad mueve toda la pantalla; quien lo desactiva recibe el mismo contenido sin él (WCAG 2.3.3).
- **Gestos:** el único gesto es mantener pulsado (CA-025-07), con alternativa de teclado y de activación simple (WCAG 2.5.1). El recorrido se maneja con el scroll normal: no hay gestos propios.
- **Foco y teclado:** CA-025-15 y CL-025-6. Nada se mueve solo más de 5 s salvo las oscilaciones suaves de los elementos en reposo, que con «reducir movimiento» no están (WCAG 2.2.2); la demostración automática ocurre una sola vez.
- **Lector de pantalla:** un encabezado principal y seis de segundo nivel; los titulares se leen como una frase, no letra a letra ni por líneas sueltas; los móviles llevan una descripción de la pantalla que enseñan; el aviso «Muy pronto» forma parte del nombre de cada insignia; el cambio de idioma dice cuál está elegido.
- **Texto grande y pantallas pequeñas:** CA-025-15 y 16.
- **Contraste:** se calcula con cada color de fondo (CA-025-15); si un par no llega, cambia el color del texto, no se acepta.
- **Sin excepción a P6.** Si al implementar alguna parte no puede cumplir, se para y se pregunta.

## 7. Textos (ES / EN)

Los textos son los de la maqueta del 2026-11-12, en dos archivos (español e inglés) con las mismas claves; se copian tal cual al implementar. Titulares y entradillas:

| Clave | ES | EN | Notas |
|---|---|---|---|
| `metaTitle` | {appName} — Una tarea a la vez | {appName} — One task at a time | Título de la página |
| `metaDescription` | {appName} es una app de tareas que solo te enseña la que toca ahora. Con tu foto, tu PDF o tu web siempre a mano. | {appName} is a to-do app that only shows you the task that matters now. With your photo, PDF or web page always at hand. | Para buscadores |
| `navDownload` | Descargar | Download | Cabecera |
| `navLanguage` | Idioma | Language | Nombre del control ES / EN |
| `navHint` | Baja | Scroll | Pista en la portada |
| `storeSoon` | Muy pronto | Coming soon | CA-025-08 |
| `storeGooglePlayAlt` | Disponible en Google Play | Get it on Google Play | Texto alternativo |
| `storeAppStoreAlt` | Descárgalo en el App Store | Download on the App Store | Texto alternativo |
| `heroTitle` | Una tarea a la vez | One task at a time | |
| `heroLead` | La app de tareas que solo te enseña la que toca ahora. Cuando la terminas, aparece la siguiente. | The to-do app that only shows you the task that matters now. Finish it and the next one appears. | |
| `manyTitle` | Tienes demasiadas cosas pendientes | You have too many things to do | |
| `manyLead` | Y solo puedes hacer una cosa a la vez. | And you can only do one thing at a time. | |
| `oneTitle` | Solo una. Hasta que la termines | Just one. Until it's done | |
| `oneLead` | La tarea de ahora ocupa toda la pantalla, como una nota adhesiva. Hasta que no la completas no pasas a la siguiente. | The current task fills the whole screen, like a sticky note. You don't move on to the next one until you complete it. | |
| `oneTry` | Pruébalo | Try it | Junto al botón (CA-025-07) |
| `handyTitle` | Tu foto, tu PDF, tu web. Siempre a mano | Your photo, PDF, web page. Always at hand | |
| `handyLead` | Adjunta a la tarea lo que necesitas ver: el horario, la receta, el mapa. Al abrir la app está ahí, a pantalla completa, sin buscarlo en la galería ni volver a cargarlo. | Attach what you need to see: the timetable, the recipe, the map. Open the app and it's there, full screen, with no digging through your gallery and no reloading. | |
| `handyNote` | La web necesita conexión. | Web pages need a connection. | Nota de la escena 4, como las de las escenas 5 y 6 (Q-025-8 a; ADR-0016) |
| `handyChips` | Fotos · PDF · Web | Photos · PDF · Web | |
| `awakeTitle` | La pantalla no se apaga | The screen stays on | |
| `awakeLead` | Si quieres. Activa «Pantalla siempre activa» y lo que has adjuntado sigue ahí, de un vistazo, sin tocar el móvil. | If you want. Turn on “Keep screen on” and what you attached stays in view, at a glance, without touching your phone. | El nombre del ajuste, el de la app |
| `awakeNote` | Viene apagada. Actúa con una foto, un PDF o una web a la vista. | Off by default. Works while a photo, PDF or web page is on screen. | |
| `lightTitle` | Tu pantalla, mesa de luz | Your screen, a light table | |
| `lightLead` | Activa «Bloquear zoom» y la foto se queda quieta: ni se amplía ni se desplaza. Pon un papel encima y calca. | Turn on “Lock zoom” and the photo stays put: no zooming, no scrolling. Lay a sheet of paper on top and trace. | El nombre del ajuste, el de la app |
| `lightNote` | Solo para imágenes. | Images only. | |
| `endTitle` | Empieza por una. | Start with one. | |
| `endLead` | Muy pronto en Google Play y App Store. | Coming soon to Google Play and the App Store. | **El texto de hoy:** ninguna de las dos tiendas tiene ficha (2026-11-12). Cambia a una de las tres variantes de abajo cuando haya fichas |
| `footerHelp` / `footerPrivacy` / `footerLicenses` | Ayuda / Privacidad / Licencias | Help / Privacy / Licenses | Pie (`footerLicenses`, nuevo: Q-025-12 a) |
| `footerNav` | Ayuda y privacidad | Help and privacy | Nombre del pie para el lector **[Suposición: se queda así aunque el pie lleve también Licencias]** |
| `navHome` | {appName}, inicio | {appName}, home | Nombre del logotipo para el lector |
| `navLanguageEs` / `navLanguageEn` | Español / English | Español / English | Nombre de cada botón del control de idioma, cada uno en su idioma (Q-025-6) |
| `storeSoonAlt` | (muy pronto) | (coming soon) | Se añade al texto alternativo de la insignia sin ficha |
| `taskDone` | Tarea completada | Task completed | Anuncio al completar en el móvil de prueba (CA-025-07) |
| `endLeadPlayOnly` | Ya en Google Play. Muy pronto en App Store. | Now on Google Play. Coming soon to the App Store. | **[Aprobado, propietario, 2026-11-12]** Solo cuando esa tienda tenga ficha (CL-025-8); hoy no se usa |
| `endLeadAppStoreOnly` | Ya en App Store. Muy pronto en Google Play. | Now on the App Store. Coming soon to Google Play. | **[Aprobado, propietario, 2026-11-12]** Solo cuando esa tienda tenga ficha (CL-025-8); hoy no se usa |
| `endLeadBoth` | Disponible en Google Play y App Store. | Available on Google Play and the App Store. | **[Aprobado, propietario, 2026-11-12]** Solo cuando las dos tengan ficha; hoy no se usa |
| `licensesWebTitle` | Código de esta web | Code of this website | **[Aprobado, propietario, 2026-11-12]** Título del bloque de avisos en `/licenses` (CA-025-18) |
| `footerLegal` | © 2026 {appName} | © 2026 {appName} | |

- **Descripciones para el lector** de los móviles y del icono (nueve claves): las de la maqueta, tal cual (Q-025-6).
- **Textos de las pantallas simuladas** (ocho tareas de ejemplo; campo de golf, cartel, libro, programa, receta, ruta; descripciones para el lector): los de la maqueta, ficticios (CA-025-06). **[Suposición]** No se listan uno a uno aquí porque son contenido de ejemplo, no interfaz; el plan los copia y `i18n-check` comprueba que ES y EN tienen las mismas claves.
- **Textos que no se escriben aquí porque son de la app:** la lista cerrada de CA-025-06 (Q-025-5 a).
- **Contenido sin JavaScript** (CA-025-11): se compone con los titulares y entradillas de esta tabla, sin textos nuevos.

## 8. Fuera de alcance

- La **maqueta B**, el selector entre maquetas y las propuestas descartadas.
- **Publicar** la web, crear el proyecto de Vercel, el dominio y las direcciones definitivas (F6, PD-2).
- Las **fichas** de las tiendas y la versión de **iOS** (D17): la landing solo enseña la insignia (Q-025-2).
- Cambiar el contenido de la política (salvo CA-025-13), de las licencias o de la Ayuda, o darles el aspecto de la landing.
- Analítica, formulario de contacto o de aviso de lanzamiento, vídeo, blog, más idiomas.
- Cualquier cambio en la app.

## 9. Preguntas abiertas

- **Q-025-1 [Resuelta, propietario, 2026-11-12: a)] · ¿Se aprueba la spec con el diseño de hoy como línea base?**
  - **a) (Recomendado)** Sí: la spec fija el recorrido, las siete escenas y los textos del 2026-11-12. Los retoques de diseño que vengan después (colores, tamaños, una imagen) que no cambien un criterio no tocan la spec; los que sí (otra escena, otro titular), como enmienda breve.
  - **b)** No: se espera a cerrar el diseño en la maqueta y luego se aprueba.
- **Q-025-2 [Resuelta, propietario, 2026-11-12: a)] · La insignia de App Store.** D17 dice «Android primero; iOS al final **si se decide**», y la landing dice «Muy pronto en Google Play y App Store».
  - **a) (Recomendado)** Se mantiene (decisión del 2026-11-11), y se anota en `docs/PLAN.md` que la landing promete iOS; si se descarta iOS antes de publicar la web, se quita la insignia.
  - **b)** Solo Google Play hasta que iOS esté decidido.
- **Q-025-3 [Pendiente, propietario, antes de F6] · Insignia de App Store en español.** La maqueta usa la inglesa en los dos idiomas porque no se pudo descargar la española. Se consigue la oficial antes de publicar; mientras, CA-025-08 admite la inglesa.
- **Q-025-4 [Pendiente, plan] · El peso** de CA-025-17 (600 KB) y si el cambio de idioma conserva la escena (CL-025-5).
- **Q-025-5 [Resuelta, propietario, 2026-11-12: a)] · Los textos de la app que enseña la landing.** En la maqueta algunos no coinciden con los de la app: el botón de completar en inglés dice «Tap to complete» (la app, «Press to complete»), el menú se llama «Menú» (la app, «Menú de la tarea») y la ayuda del listado tiene dos frases (la app, tres).
  - **a) (Recomendado)** Lista cerrada de textos que la landing toma de la app tal cual (botón de completar, menú, título y ayuda del listado, «Nueva tarea», los dos títulos de «hecho», y los nombres y subtítulos de los dos ajustes); el plan la fija con sus claves.
  - **b)** La landing puede recortar textos de la app (por ejemplo, la ayuda del listado) y se anota cuáles.
- **Q-025-6 [Resuelta, propietario, 2026-11-12: entran los de la maqueta y «Español» / «English»; los textos nuevos del §7, aprobados] · Textos que faltan en el §7** (P7). Los que ya están en la maqueta entran en la tabla tal cual al aprobar: el nombre del logotipo («{appName}, inicio» / «{appName}, home»), el del pie («Ayuda y privacidad» / «Help and privacy»), el anuncio «Tarea completada» / «Task completed», las nueve descripciones de los móviles y del icono, y «(muy pronto)» / «(coming soon)» en el texto alternativo. **Faltan por redactar y aprobar:** los nombres de los botones ES / EN para el lector (propuesta: «Español» y «English», cada uno en su idioma), el título del bloque de avisos del código de la web en `/licenses`, y la entradilla del cierre con una o con las dos fichas publicadas. Dos claves de la maqueta no se usan («Capítulos» y «Zoom bloqueado»): no entran salvo que se diga.
- **Q-025-7 [Pendiente, plan, antes de implementar; el propietario acepta el 2026-11-12 que lo lea el plan] · Las normas de las insignias.** CA-025-21 exige usarlas según las normas de cada tienda; la maqueta recorta el margen de las de Google y las enseña sin enlace para una app sin publicar. **[Suposición sin comprobar]** Las normas podrían pedir que la insignia enlace a una ficha, y una línea de atribución de marcas en el pie. El plan lee las normas vigentes de las dos, con fuente y fecha; si no admiten el uso sin ficha, **se para y se pregunta** (salidas: el texto «Muy pronto en Google Play y App Store» sin insignias, o insignias solo con ficha).
- **Q-025-8 [Resuelta, propietario, 2026-11-12: a)] · «Siempre a mano» y la tarea web.** La escena 4 dice «sin […] volver a cargarlo», pero la tarea web necesita conexión y se carga cada vez (ADR-0016; la ficha ya tuvo que decirlo, CA-023-09).
  - **a) (Recomendado)** Una nota en la escena 4, como las de las escenas 5 y 6: «La web necesita conexión.» / «Web pages need a connection.»
  - **b)** Quitar «ni volver a cargarlo» / «and no reloading».
  - **c)** Dejarlo como está.
- **Q-025-9 [Resuelta, propietario, 2026-11-12: a)] · `?lang=` y `?motion=reduce`.** La maqueta los admite en la dirección; la spec dice «una sola dirección» (P-012-2).
  - **a) (Recomendado)** Se quitan: no hay parámetros de dirección para el idioma ni para el movimiento.
  - **b)** Se admite `?lang=` para compartir un enlace en un idioma, con su criterio y su test.
- **Q-025-10 [Resuelta, propietario, 2026-11-12: a)] · Estilos en línea.** El recorrido coloca cada pieza con estilos que el programa escribe en la página; CA-025-12 solo abre las cabeceras a programas del propio origen y el ADR-0027 lo deja al plan.
  - **a) (Recomendado)** Ninguno escrito en la página; los que el programa aplique al mover las piezas se admiten solo si el plan demuestra que no hay alternativa, y se anotan en T-18.
  - **b)** Prohibidos sin excepción (puede obligar a rehacer parte del recorrido).
- **Q-025-11 [Resuelta, propietario, 2026-11-12: a)] · Safari de iOS.** La landing promete App Store, pero sin iPhone ni Xcode (D17) solo se puede probar Safari de macOS.
  - **a) (Recomendado)** C-025-2 y C-025-8 se pasan en Safari de macOS; Safari de iOS queda **sin verificar y aceptado** hasta que haya un iPhone.
  - **b)** Se consigue un iPhone para las casillas.
- **Q-025-12 [Resuelta, propietario, 2026-11-12: a)] · Enlace a Licencias.** La página de inicio de la 023 enlazaba a las tres webs; el pie de la landing solo lleva Ayuda y Privacidad, y los avisos de licencia del código de la web quedarían sin ningún enlace desde ella.
  - **a) (Recomendado)** Se añade «Licencias» / «Licenses» al pie (un texto nuevo y un retoque de diseño).
  - **b)** No se añade: a las licencias se llega desde la app.
- **Q-025-13 [Resuelta, propietario, 2026-11-12: a)] · Nota bajo P11 en la constitución.** La excepción de licencia de GSAP queda en el ADR-0027 y en `threat-model.md` §5.
  - **a) (Recomendado)** Basta con eso: GSAP no entra en la app.
  - **b)** Además, una nota bajo P11 (constitución 1.11), como las de P3 y P6.
- **[Hecho, para que el propietario lo sepa]** La línea base cambiará en un punto por el §6: la palabra destacada de los titulares de las escenas 2 y 5, crema sobre naranja, da un contraste de unos 2,4:1 **[Suposición: cálculo aproximado del revisor]** y CA-025-15 pide 3:1; cambia el color del texto o el del fondo.
- **[Suposición]** Se confirman al aprobar (si no se dice nada, se quedan así): la regla de idioma de la app para la primera visita (CA-025-09); español primero en el contenido sin JavaScript (CA-025-11); los colores cálidos entran en los tokens (CA-025-14); las ilustraciones que simulan contenido del usuario quedan fuera de los tokens, colores y fuentes incluidos, y se anota en DEV-59 (CA-025-14, lectura de P12); los avisos de licencia del código de la web van en la página de licencias (CA-025-18); el estado fijo con «reducir movimiento» (CA-025-10); la demostración automática no se anuncia al lector (CA-025-07).

## 10. Enmiendas a la spec 023 (anotadas en ella el 2026-11-12, al aprobar esta)

| Criterio de la 023 | Decía | Pasa a decir |
|---|---|---|
| CA-023-13 | «una página de inicio mínima con el nombre de la app y los enlaces a las tres»; «Funcionan sin JavaScript» | La página de inicio es la landing de la 025. **Las otras cuatro** funcionan sin JavaScript; la de inicio, con el contenido de CA-025-11 |
| CA-023-14 | «ningún script en línea» y cabeceras que solo admiten estilos, fuentes e imágenes del propio origen | Igual para las otras cuatro. La de inicio admite además programas **del propio origen** (CA-025-12) |
| CA-023-15 | «respetan "reducir movimiento" (no hay animaciones)» | Igual para las otras cuatro. La de inicio tiene animación y la quita con «reducir movimiento» (CA-025-10) |
| CL-023-5 | «la web no usa JavaScript» | Las otras cuatro no lo usan; la de inicio enseña el contenido de CA-025-11 |
| §8 de la 023 | «una landing con las propuestas de valor es otra spec» | Es la 025 |
| CA-023-13 (idiomas y construcción) | «Cada página tiene el español y el inglés en la misma dirección, siempre en ese orden», con un enlace al principio; «la construcción no usa dependencias de terceros» | Igual para las otras cuatro y para el contenido sin JavaScript de la de inicio (CA-025-11). La de inicio enseña un idioma cada vez (CA-025-09) y se construye con las dependencias del ADR-0027 |
| CA-023-14 (qué admite la página) | sin imágenes fuera de las previstas, sin botones | La de inicio lleva imágenes, botones e iconos; los estilos en línea, según Q-025-10 |
| CA-023-15 (tokens y foco) | «colores, fuentes y medidas de tokens (sin valores sueltos)»; «nada tapa el elemento con el foco» | La de inicio, con la salvedad de las ilustraciones (CA-025-14) y con su propio criterio de foco (CA-025-15) |
| CA-023-16 (y ADR-0026) | La página de licencias publica los avisos del paquete de la app | Publica además, en un bloque aparte, los avisos del código de la web (CA-025-18) |
| CA-023-18 | Qué dispara y qué comprueba «Web y ficha» | Además, lo de CA-025-19 |
| CL-023-4 | «la página sale igual, primero en español» | Igual para las otras cuatro; la de inicio, según CA-025-09 |
| 023 §5, §6, C-023-2 y C-023-3 | «sin animaciones», «sin JavaScript», «las cuatro páginas y la de error» | Se leen sin la página de inicio, que tiene sus casillas en esta spec (§11) |
| 023 §7 | `webHomeTitle` y `webHomeIntro`; `webContact` «pie de todas las páginas»; `webLanguageName` «inicio y 404» | Las dos primeras se retiran; el pie de la de inicio no lleva el contacto; `webLanguageName`, solo en la página de error |
| 023, «Dependencias» | «[Suposición] la web no usa paquetes de terceros en el navegador» | Salvo la de inicio (ADR-0027) |
| DEV-58 (1) | «inicio mínimo […] sin animaciones y sin JavaScript» | La página de inicio es la de la DEV-59 |

**Lo que sigue valiendo también para la página de inicio:** idioma declarado en la página, zoom sin bloquear, un solo encabezado principal sin saltos de nivel, sin marcos ni formularios, sin manejadores en línea, sin enlaces `javascript:`, sin rastros de analítica y sin `noindex`.

**Cuándo entra cada cosa en vigor:** las enmiendas se anotan en la 023 al aprobar esta spec como «Enmienda (spec 025, Aprobada; en vigor cuando la 025 se implemente)»: hasta entonces el código de la 023 sigue exigiendo lo de antes. El ADR-0027 se **acepta al aprobar el plan**, tras comprobar que ningún paquete hace peticiones; si falla, se vuelve a su opción 3 antes de implementar.

## 11. Casillas y documentos

**Casillas de navegador** (se rellenan al implementar, en `specs/025-landing-de-producto/navegadores.md`):

| Casilla | Qué se mira | Dónde | CA |
|---|---|---|---|
| C-025-1 | El recorrido: de frente, escalonado, sin zonas muertas, se asienta solo, texto nítido | Chrome de escritorio y de Android | 03, 04 |
| C-025-2 | Las siete escenas completas avanzando y volviendo | Chrome, Safari de macOS, Firefox; Chrome de Android | 05 |
| C-025-3 | Las pantallas simuladas frente a la app; contenido ficticio | Revisión del propietario | 06 |
| C-025-4 | «Reducir movimiento» | Chrome de escritorio y de Android | 10 |
| C-025-5 | Teclado, TalkBack, zoom al 200 %, 320 px | Chrome de escritorio; emulador | 15 |
| C-025-6 | Las siete escenas a 320×568, 390×844, 844×390, 768×1024, 1280×720 y 1920×1080, ES y EN | Chrome de escritorio (modo móvil) y el Xiaomi | 16 |
| C-025-7 | Peticiones y almacenamiento | Panel de red | 12 |
| C-025-8 | Fluidez, un navegador por fila | Los de CA-025-17 | 17 |

**Documentos que cambian:** `docs/adr/0027-…` (Aceptado) y `docs/adr/README.md`; `docs/adr/0009-…` y `docs/adr/0026-…` (solo la marca de enmienda); `specs/023-…/spec.md` (§10); `docs/legal/privacy-policy.md` (CA-025-13); `docs/security/threat-model.md` (T-9, T-18 y §5) y `docs/security/checklist.md` (apartado de la web); `docs/architecture.md` (`landing/`); `docs/testing.md` (qué dispara «Web y ficha»); `docs/glossary.md`; `docs/design/screen-map.md`, `docs/design/prototype-deviations.md` (DEV-59 y la nota en DEV-58) y `docs/design/tokens.md` (contraste de los pares nuevos); `design/tokens.json` (colores de la landing); `.claude/skills/release-checklist/SKILL.md` (la revisión legal incluye GSAP y los Términos de Webflow; las direcciones de las tiendas y la insignia española); `docs/PLAN.md` (hoja de ruta, trazabilidad, el riesgo «dependencias de npm en la web», la fila de F6 y la nota de que la landing promete iOS, Q-025-2) y `CLAUDE.md` (fase).
