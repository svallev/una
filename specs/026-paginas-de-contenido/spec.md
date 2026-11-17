# Spec 026: Páginas de contenido

- **Estado:** **Borrador** (2026-11-17; revisión del `spec-reviewer` aplicada el mismo día: 2 bloqueantes, 8 importantes y 11 menores)
- **Reglas de producto:** R15 (idioma): las páginas la **siguen**, no la cambian. Ninguna regla de la app cambia.
- **Pantallas del prototipo:** **sin diseño en el prototipo ni en la maqueta.** El prototipo no tiene páginas web (DEV-58) y la maqueta de la landing (`UnaWeb/www`, versión A) solo tiene la página de inicio. El diseño sale de: la pauta de la maqueta para estas páginas (`UnaWeb/design.md` §8: «la misma maqueta en columna de 600 px, titulares con regla gruesa superior, sin adornos»); las piezas de la landing (logotipo, botón «Descargar», pie); y la **estructura** de las páginas legales de superplay.co (`/terms`, vista por última vez el 2026-11-17), que el propietario dio como referencia. Se registra como desviación **DEV-60** al implementar; el propietario lo revisa en el navegador (C-026-1).
- **Decisiones y ADR relacionados:** P-012-2 (una sola dirección para ES y EN), ADR-0009 (`landing/`) y ADR-0027 (herramientas de la landing): los dos dicen que estas cuatro páginas van **sin JavaScript**, así que **[Pendiente, plan] un ADR nuevo los enmienda** (un programa propio, sin dependencias, solo para el idioma, en las cuatro páginas; la constitución pide un ADR para cambiar uno aceptado). ADR-0010 (Vercel), ADR-0026 (licencias de terceros), D17, D26.
- **Dependencias:** 023 (las cuatro páginas en `landing/`, **Implementada**; **se enmienda en el §10**) y 025 (landing, **Implementada**; **se enmienda en el §10**). Sin cambios en la app: ni esquema de BD, ni permisos, ni dependencias, ni direcciones de `app/identity.yaml`.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 0. Alcance (decidido por el propietario)

- **[Hecho, 2026-11-17]** **Páginas de contenido** son las cuatro páginas de la web que no son la landing: **Política de privacidad** (`/privacy`), **Licencias de terceros** (`/licenses`), **Ayuda** (`/help`) y la **página de error** (cualquier ruta que no existe). La 025 dejó fuera «darles el aspecto de la landing» (025 §8); esta spec lo hace (Q-026-1 a).
- **[Hecho, 2026-11-17]** Cambia el **aspecto**, no el **contenido**: lo que dicen la política (salvo CA-026-14), las licencias, la Ayuda y la página de error sigue igual (Q-026-1 a).
- **[Hecho, 2026-11-17]** **Un idioma cada vez; nunca los dos a la vez con JavaScript.** Se elige con el selector ES / EN y la elección se recuerda. Si hace falta JavaScript, se usa (Q-026-2, Q-026-3 y Q-026-5: a). Sin JavaScript se ven los dos idiomas, uno debajo del otro, como hoy. La app sigue enlazando a las mismas direcciones.
- **[Hecho, 2026-11-17]** El programa es **pequeño, propio y del propio origen**: sin GSAP, sin Lenis, sin dependencias, sin animación y **sin estilos en línea** (Q-026-3 a).
- **[Hecho, 2026-11-17]** **Cabecera fija**, al estilo de la de superplay.co/terms: el logotipo a la izquierda y, a la derecha, un solo botón («Descargar»). El **selector de idioma no va en la cabecera**: va debajo, encima del título, y **se va con el scroll** («eso se elige al principio»).
- **[Hecho, 2026-11-14, `docs/PLAN.md`]** Siguen en vigor: logotipo que vuelve a la portada y «Descargar» como en la landing; enlace visible **«← Volver al inicio»**; **pie de la landing**; **índice al principio** de la Privacidad y de la Ayuda; **fecha de «última actualización» bajo el título** de la política. Lo que decía aquel día de «sin JavaScript y con la CSP de hoy» lo sustituye la decisión del 2026-11-17 (Q-026-5 a).
- **[Hecho, 2026-11-17]** No hay maqueta de estas páginas: la spec propone el diseño y el propietario lo revisa en el navegador al implementar (Q-026-4 a).

## 1. Objetivo

Que quien pasa de la landing a la Ayuda, la política o las licencias (o llega a ellas desde Ajustes de la app) sienta que sigue en la misma web: el mismo logotipo, el mismo botón de descarga, el mismo pie y el mismo lenguaje de papel y tinta, leyendo **solo su idioma**, sin perder lo que hoy tienen esas páginas (funcionar sin JavaScript, sin rastreo y accesibles).

## 2. Historias de usuario

- **HU-026-1** Como persona que viene de la landing, quiero que la Ayuda, la política y las licencias se vean como la landing, para saber que sigo en la web de la app.
- **HU-026-2** Como persona que ha elegido inglés en la landing, quiero que las otras páginas salgan en inglés sin tener que volver a elegirlo, y leer solo mi idioma.
- **HU-026-3** Como persona que abre la política o la Ayuda desde Ajustes de la app, quiero leerla en mi idioma, poder cambiarlo con un toque y saltar a la sección que busco.
- **HU-026-4** Como persona con JavaScript desactivado, lector de pantalla, teclado o texto grande, quiero leer las mismas páginas enteras, como hoy.
- **HU-026-5** Como propietario, quiero que las páginas sigan sin rastreo, con la política de contenido estricta y sin dependencias nuevas, para que la web no prometa menos que la app.

**Trazabilidad HU → CA:** HU-026-1 → CA-026-01 a 05; HU-026-2 → CA-026-06 a 08; HU-026-3 → CA-026-04, 06 y 07; HU-026-4 → CA-026-09 a 11; HU-026-5 → CA-026-12 a 15.

## 3. Criterios de aceptación

### El aspecto

- **CA-026-01** · Estructura de las cuatro páginas
  - **Dado** la web construida
  - **Cuando** se abre `/privacy`, `/licenses`, `/help` o una ruta que no existe
  - **Entonces** cada página tiene, de arriba abajo:
    1. la **cabecera fija** (CA-026-02);
    2. el **selector de idioma** ES / EN, centrado, que se va con el scroll (CA-026-07);
    3. el enlace **«← Volver al inicio»** (salvo en la página de error, que ya lo tiene en su texto, CA-026-05: **uno solo** por página);
    4. el **título** de la página (el único encabezado principal);
    5. en la política, la **fecha de «última actualización»**; en la política y la Ayuda, el **índice** (CA-026-04);
    6. el **contenido**, en una sola **columna de 600 px como máximo**, centrada, sobre el fondo de papel;
    7. el **pie** de la landing: el aviso legal y los enlaces Ayuda, Privacidad y Licencias, en ese orden, más el contacto que ya lleva hoy (`webContact`). El enlace a la página en la que se está se marca como **página actual** (para el lector y a la vista, sin depender del color).
  - **Verificable:** test sobre el HTML construido de las cuatro páginas (orden de las piezas, un solo «Volver al inicio», pie con los tres enlaces en orden y el actual marcado) y casilla C-026-1.

- **CA-026-02** · Cabecera fija
  - **Dado** una página de contenido
  - **Cuando** se baja por ella
  - **Entonces** la cabecera **se queda arriba**, a lo ancho de la ventana, con el **logotipo** a la izquierda (enlace a la landing, «/») y **«Descargar»** a la derecha, con el aspecto del botón de la landing. Va sobre **fondo de papel opaco** **[Suposición]** (en la referencia es transparente; aquí el texto que pasa por debajo no se ve a través de ella), sin sombra decorativa. **Nada que reciba el foco queda tapado** por ella (WCAG 2.4.11): al llegar a un elemento con el teclado o desde el índice, queda por debajo de la cabecera. En ventanas **bajas** (por ejemplo, un móvil en horizontal o con el zoom alto: menos de **540 px** de alto, el mismo umbral que la landing) la cabecera **deja de ser fija** y se va con el scroll **[Suposición]**, para no quitar sitio a la lectura (WCAG 1.4.10).
  - **Verificable:** test (cabecera presente con el logotipo y «Descargar»; la regla de «fija» y la excepción por altura existen) y casilla C-026-1 (bajar por las cuatro páginas; el foco nunca queda debajo; 844 × 390 y zoom al 400 %).

- **CA-026-03** · Tinta sobre papel, sin adornos
  - **Dado** las cuatro páginas
  - **Cuando** se revisan
  - **Entonces** siguen la pauta de la maqueta (`design.md` §8): el título en Archivo del peso más fuerte de los tokens; cada **titular de sección con una regla de tinta de 4 px encima** (si no hay token de ese grosor, se añade); el texto en `ink` sobre `paper`; los textos de apoyo (fechas, versión, aviso de última compilación) en Space Mono; esquinas rectas; y **sin** ilustraciones, notas de color, sombras decorativas ni animaciones. El logotipo, «Descargar» y el pie se ven **igual que en la landing** cuando está sobre fondo claro. Los colores, las fuentes y las medidas salen de `design/tokens.json` (CA-023-15), con contraste AA.
  - **Verificable:** test (ningún valor visual suelto, con la comprobación de tokens de la 023) y casilla C-026-1 (revisión del propietario frente a la landing).

- **CA-026-04** · Índice y fecha (Privacidad y Ayuda)
  - **Dado** la Política de privacidad o la Ayuda
  - **Cuando** se abre
  - **Entonces** bajo el título hay un **índice**: una navegación con el nombre visible «En esta página» (`webOnThisPage`; **no** es un encabezado **[Suposición]**) y un enlace a cada **sección del nivel inmediatamente inferior al título** de la página, en el idioma que se ve y en el orden de la página. Cada enlace lleva a su sección y el foco va a ella. En la política, la **fecha de «última actualización»** (`webLastUpdated`) va **justo bajo el título**, antes del índice. El índice sale de las secciones al construir (no se escribe a mano). Las anclas de las secciones son **estables** (no cambian si no cambia el titular) y **distintas en cada idioma**. Licencias y la página de error no llevan índice **[Suposición]**.
  - **Verificable:** test sobre el HTML construido (un enlace por sección, en orden, a un ancla que existe y es única, en cada idioma; la fecha antes del índice en la política).

- **CA-026-05** · Página de error
  - **Dado** una ruta que no existe
  - **Cuando** se abre
  - **Entonces** sale con la cabecera, el selector y el pie, y el texto de hoy (`webNotFoundTitle`, `webNotFoundBody`, `webBackHome`) en el idioma elegido; el logotipo y «Volver al inicio» llevan a la landing.
  - **Verificable:** test sobre `404.html` y casilla C-026-1 (una ruta inventada en el servidor local).

### El idioma

- **CA-026-06** · Qué idioma sale
  - **Dado** una visita con JavaScript
  - **Cuando** se abre una página de contenido
  - **Entonces** se ve **solo un idioma**, decidido así:
    1. si la dirección acaba en el ancla de una sección o de una mitad (`#es`, `#en` o el ancla de una sección de un idioma), **ese idioma**, sin guardarlo (CL-026-2);
    2. si no, la **elección guardada** en ese navegador, si es `es` o `en` (es la misma que guarda la landing: quien eligió inglés allí ve estas páginas en inglés, y al revés);
    3. si no hay elección válida, el **primer idioma del navegador**: español o catalán → español; cualquier otro → inglés; sin idioma → español. Es la regla que usa hoy la landing (CL-026-11).

    | Guardado | Navegador | Sale |
    |---|---|---|
    | `en` | `es-ES` | EN |
    | `es` | `en-US` | ES |
    | — | `es-MX` | ES |
    | — | `ca-ES` | ES |
    | — | `fr-FR` | EN |
    | — | `en-GB` | EN |
    | — | `gl-ES` | EN |
    | `xx`, `es-MX` o vacío (no válido) | `fr-FR` | EN (se ignora lo guardado) |
    | `xx` (no válido) | `es-ES` | ES |
    | — | vacío | ES |

    `?lang=` en la dirección **no** cambia nada en estas páginas **[Suposición]**. La página declara el idioma que enseña (para el lector y el buscador), el título de la pestaña está en ese idioma (`webPageTitle`) y la otra mitad **no se ve ni la lee el lector**. La dirección es la misma para los dos idiomas (P-012-2).
  - **Verificable:** test con la tabla de casos, más las anclas; idioma declarado, título y la otra mitad oculta para el lector.

- **CA-026-07** · El selector
  - **Dado** una página de contenido
  - **Cuando** se mira el selector, debajo de la cabecera
  - **Entonces** es una fila centrada con **ES** y **EN**, separados como en la referencia, con el elegido marcado (para el lector y a la vista, sin depender solo del color). Es un **grupo con nombre** («Idioma» / «Language») y cada opción se anuncia con el nombre de su idioma, marcado con ese idioma («Español», «English»), sin dejar de contener el texto visible (WCAG 2.5.3). **No es fijo**: se va con el scroll. Con JavaScript, pulsar el otro idioma pasa la página **entera** a ese idioma (título de la pestaña, cabecera, contenido, pie e idioma declarado) **sin recargarla**; el foco se queda en la opción pulsada; la elección **se guarda** para las demás páginas y para la landing. Pulsar el idioma que ya está no hace nada. Si el navegador no deja guardar, el cambio vale igual para esa página (CL-026-4).
  - **Verificable:** test (grupo y nombres, marca del elegido, cambio completo sin recarga, foco, lo guardado, sin almacenamiento).

- **CA-026-08** · Sin salto al cargar
  - **Dado** una página de contenido con JavaScript y una elección guardada
  - **Cuando** se abre o se recarga
  - **Entonces** **no llega a verse** la página en los dos idiomas ni en el idioma equivocado antes de quedarse en el bueno, ni salta el contenido de sitio.
  - **Verificable:** casilla C-026-2: carga en frío y recarga en Chrome de escritorio con la limitación de red «Slow 4G» y la caché desactivada, guardando la **tira de imágenes** del panel de rendimiento (ningún fotograma con los dos idiomas ni con el equivocado). El plan dice si además se puede probar con un test.

- **CA-026-09** · Sin JavaScript, los dos idiomas como hoy
  - **Dado** un navegador con JavaScript desactivado (o el programa bloqueado o roto)
  - **Cuando** se abre una página de contenido
  - **Entonces** se lee **todo** el contenido en los dos idiomas, **primero el español y después el inglés**, cada mitad marcada con su idioma y con su propio índice y su fecha, como hoy (CA-023-13). Las piezas comunes (el título de la pestaña, el título de la página, «Descargar», el nombre del selector, «← Volver al inicio» y el pie) salen **en los dos idiomas**, como hoy el título («Privacidad · Privacy»), con cada parte marcada con su idioma. ES y EN del selector **llevan a su mitad** (sustituyen a «Read in English» y «Leer en español», que desaparecen). No queda ninguna página en blanco ni a medias.
  - **Verificable:** test sobre el HTML construido sin ejecutar nada (las dos mitades en orden y con su idioma; piezas comunes en los dos idiomas; ES y EN llevan a su mitad) y test con el programa forzado a fallar (CL-026-5).

### Para todos

- **CA-026-10** · Accesibles
  - **Dado** las cuatro páginas, con y sin JavaScript
  - **Cuando** se revisan
  - **Entonces** se mantiene **todo** CA-023-15 (idioma marcado; 200 % y 320 px sin desplazamiento horizontal de la página; espaciado de texto aumentado, 1.4.12; foco visible; enlaces que se distinguen sin color) y además:
    - **un solo encabezado principal** y ningún salto de nivel, **en los dos modos** (un idioma o los dos);
    - zonas de cabecera, navegación, contenido principal y pie; **sin enlace para saltar al contenido** **[Suposición]**: la cabecera solo tiene dos elementos y el selector tres (WCAG 2.4.1 se cumple con las zonas);
    - orden del teclado: logotipo, «Descargar», ES, EN, «← Volver al inicio», índice, contenido y pie;
    - **objetivos de 44 × 44 o más** **[Suposición]** para el logotipo, «Descargar», ES, EN, «← Volver al inicio», los enlaces del índice y los del pie (en la landing quedaron por debajo, H-025-05);
    - las marcas de «elegido» y de «página actual» tienen contraste de 3:1 o más (1.4.11), no dependen solo del color y se ven con los **colores forzados** del sistema;
    - **nada se mueve**.
  - **Verificable:** test (encabezados por modo, zonas, nombres, estados, orden, tamaños) y casilla C-026-3; `a11y-reviewer` al cerrar.

- **CA-026-11** · En móvil y en escritorio
  - **Dado** las cuatro páginas en los dos idiomas
  - **Cuando** se ven a 320 × 568, 390 × 844, 844 × 390, 768 × 1024 y 1280 × 720, al 400 % de zoom y con el espaciado de texto aumentado
  - **Entonces** nada se corta ni se sale por la derecha y no hay desplazamiento horizontal de la página; la cabecera mantiene el logotipo y «Descargar» en una línea: si no cabe la palabra, «Descargar» se queda en su icono **sin perder su nombre** para el lector (como la landing a 520 px o menos); el selector cabe en una línea; la columna no pasa de 600 px.
  - **Verificable:** casilla C-026-1 (cinco tamaños × cuatro páginas × dos idiomas, en Chrome; el plan dice si una parte se automatiza).

- **CA-026-12** · Licencias: los avisos, legibles a cualquier ancho
  - **Dado** la página de licencias
  - **Cuando** se ve en cualquiera de los dos idiomas
  - **Entonces** la explicación, la versión (o el aviso de última compilación, CL-023-11), el enlace al archivo de texto y el **título** del bloque del código de la web (`licensesWebTitle`) salen en el idioma elegido (sin JavaScript, el título en los dos, como hoy). Los **textos** de los avisos (los de la app y los del código de la web, CA-025-18) salen **una sola vez**, en inglés y marcados como inglés, en los dos idiomas. Las **líneas largas se parten** dentro de la columna: no hay desplazamiento horizontal, ni de la página ni dentro de un bloque **[Suposición]**.
  - **Verificable:** test sobre el HTML construido (avisos una sola vez, marcados en inglés; título en los dos idiomas sin JavaScript) y casilla C-026-1 (320 px y 400 %).

### Privacidad y seguridad

- **CA-026-13** · Sin terceros ni rastreo, y la política de contenido sigue estricta
  - **Dado** las cuatro páginas construidas y la configuración de Vercel del repositorio
  - **Cuando** se pasa la comprobación en la CI
  - **Entonces** sigue en vigor **todo** CA-023-14 (ningún recurso de otro origen, ninguna cookie, ninguna analítica, ningún envío de datos, las fuentes dentro de la web) con un **único cambio** en las cabeceras de estas páginas: se admiten programas **del propio origen**. **No** se admiten programas escritos dentro de la página **ni estilos en línea** (a diferencia de «/», CA-025-12). El programa no usa **ninguna dependencia** de terceros, **no** hace peticiones, **no** escribe en la página nada leído del almacenamiento o de la dirección (solo compara con `es` y `en`, P5), y lo único que guarda es el idioma, con la misma clave que la landing (`una-lang`; lleva el nombre de la app escrito a mano, aceptado en el plan de la 025 y fuera del alcance de esta spec).
  - **Verificable:** test sobre las páginas construidas y la configuración (cada regla con un caso que falla: un programa en la página, un estilo en línea, un programa de otro origen, una dependencia en el programa) y casilla C-026-2 (peticiones y almacenamiento en el navegador, como C-025-7).

- **CA-026-14** · La política dice la verdad
  - **Dado** `docs/legal/privacy-policy.md` (sección «Esta web»)
  - **Cuando** se implementa esta spec
  - **Entonces** dice, en ES y EN y con la misma estructura en las dos mitades (CA-023-03), que **las cuatro páginas** usan también un programa pequeño, del propio origen y sin bibliotecas de terceros, **solo para el idioma**; que lo único que guarda **la web** (no solo la página de inicio) es el idioma elegido, en el propio navegador y sin enviarlo; y que **sin JavaScript** la política, la Ayuda y las licencias se leen enteras, en los dos idiomas. Desaparece «Esta política, la ayuda y las licencias funcionan sin JavaScript» en su forma actual. La «última actualización» **sigue siendo el hueco `[FECHA]` hasta F6** (CA-023-04); las notas de revisión anotan el cambio y su fuente (CA-023-02).
  - **Verificable:** test sobre la política construida (las frases nuevas en ES y EN; la antigua ya no está) y revisión del propietario del texto antes de cerrar.

- **CA-026-15** · Ligeras
  - **Dado** el programa de las páginas de contenido
  - **Cuando** se construye la web
  - **Entonces** pesa **10 KB o menos sin comprimir** **[Suposición]**, y cada página no carga más archivos que hoy salvo ese programa: **ningún archivo de fuente nuevo** (el logotipo usa las fuentes que ya están) y ninguna imagen nueva salvo el icono de «Descargar» si el plan lo necesita como archivo.
  - **Verificable:** test de la construcción (tamaño del programa; lista de recursos de cada página).

### La landing y la documentación

- **CA-026-16** · «Descargar» lleva a las tiendas
  - **Dado** una página de contenido
  - **Cuando** se pulsa «Descargar»
  - **Entonces** se abre la landing **en su escena de cierre** (la de las tiendas), con y sin recorrido y sin JavaScript. Es lo que ya pedía CL-025-2 y la landing aún no hace al abrirse con el ancla del cierre: **entra en el alcance** el cambio mínimo de la landing para que lo haga.
  - **Verificable:** test (el enlace apunta al cierre) y casilla C-026-1 (desde cada página, con recorrido, con «reducir movimiento» y sin JavaScript).

- **CA-026-17** · Documentación al día y la CI
  - **Dado** la spec implementada
  - **Cuando** se cierra
  - **Entonces** están al día: el **ADR nuevo** que enmienda los ADR-0009 y 0027 y `docs/adr/README.md`; la 023 y la 025 (enmiendas del §10); `docs/legal/privacy-policy.md` (CA-026-14); `docs/security/threat-model.md` (T-9 y T-18); `docs/security/checklist.md` (apartado de la web); `docs/design/screen-map.md`; `docs/design/prototype-deviations.md` (DEV-60 y nota en DEV-58); `docs/glossary.md`; `docs/PLAN.md` y `CLAUDE.md`. La web se sigue construyendo y comprobando en la CI sin publicarse sola (CA-023-18 y CA-025-19). Los tests de la 023 y la 025 que esta spec cambia se actualizan citando el CA nuevo, sin borrar lo que siguen protegiendo.
  - **Verificable:** `spec-reviewer` al cerrar; la CI en verde.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-026-1 | La app está en un idioma y el navegador del móvil en otro (la app en inglés elegido en Ajustes y el sistema en español), sin elección guardada en la web | Sale según la regla de la web (CA-026-06), no según la app: la dirección no lleva el idioma (P-012-2). El selector está arriba y la elección se recuerda. **[Suposición]** Se acepta; la app no cambia. |
| CL-026-2 | La dirección lleva `#es`, `#en` o el ancla de una sección de un idioma (un enlace guardado o compartido), también con otro idioma guardado | Con JavaScript, se ve el idioma del ancla, sin guardarlo, y la página va a esa sección; sin JavaScript, salta a ella como hoy. |
| CL-026-3 | El idioma guardado no es `es` ni `en` (cambiado a mano) | Se ignora y se aplica el paso 3 de CA-026-06. |
| CL-026-4 | El navegador no deja guardar (navegación privada estricta, almacenamiento bloqueado) | El selector cambia el idioma de esa página; al ir a otra, se aplica el paso 3. Sin errores a la vista. |
| CL-026-5 | El programa no llega o falla al arrancar | Se ve la versión sin JavaScript (CA-026-09). |
| CL-026-6 | Se imprime la página o se abre en un lector simplificado | Con JavaScript, el idioma elegido; si el lector simplificado no ejecuta el programa, los dos (CA-026-09). **[Suposición]** Sin hoja de impresión cuidada; la cabecera fija no se repite en cada hoja. |
| CL-026-7 | Se cambia el idioma con otra pestaña de la web abierta | La otra pestaña no cambia hasta que se recarga o se navega **[Suposición]**. |
| CL-026-8 | Se vuelve atrás a una página que el navegador tenía guardada en memoria, tras cambiar el idioma en otra | Se ve en el idioma guardado ahora, no en el de antes **[Suposición]**. |
| CL-026-9 | La página de licencias es muy larga (los avisos pesan cerca de 1,5 MB) | Cambiar el idioma no recarga ni vuelve a descargar la página; los avisos no se duplican (CA-026-12). |
| CL-026-10 | El sistema está en modo oscuro | Las páginas no cambian: siempre en claro, como la app (021) y la landing (CL-025-19). |
| CL-026-11 | La landing y estas páginas | Comparten la elección guardada y el paso 3. **Diferencia conocida:** la landing además admite `?lang=` y, con un valor guardado no válido, sale en inglés; esta spec **no** cambia eso de la landing (§9, nota). |
| CL-026-12 | Cambia el nombre de la app | Logotipo, títulos y pie lo toman de la identidad (CA-023-13); nada escrito a mano. |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin JavaScript o con el programa roto | CL-026-5 | Las dos mitades, ES y después EN, piezas comunes en los dos idiomas, ES / EN como enlaces a cada mitad (CA-026-09) |
| Sin almacenamiento | CL-026-4 | El idioma por la regla; el selector funciona en la página |
| Ruta inexistente | CA-026-05 | La página de error con el aspecto nuevo |
| Licencias sin versión | CL-023-11 | Igual que hoy, en el idioma elegido |

## 6. Accesibilidad

- **Estructura:** un encabezado principal por página; ningún salto de nivel con un idioma ni con los dos; zonas de cabecera, navegación, contenido y pie (CA-026-10).
- **Idioma:** la página declara el idioma que enseña; la mitad oculta no la lee el lector; sin JavaScript, cada mitad y cada parte de las piezas comunes va marcada con su idioma (WCAG 3.1.1 y 3.1.2).
- **Selector:** grupo con nombre; opciones con el nombre de su idioma y estado de elegido; el foco se queda en la opción tras cambiar (CA-026-07). Sin JavaScript, son enlaces a las mitades.
- **Cabecera fija:** nunca tapa el elemento con el foco (2.4.11); deja de ser fija en ventanas bajas (1.4.10) (CA-026-02).
- **Teclado y foco:** orden logotipo → «Descargar» → ES → EN → «← Volver al inicio» → índice → contenido → pie; un enlace del índice lleva el foco a su sección.
- **Tamaño:** objetivos de 44 × 44 o más; 200 % y 400 % de zoom, 320 px, espaciado de texto (1.4.4, 1.4.10, 1.4.12).
- **Estados:** «elegido» y «página actual» con 3:1, sin depender solo del color y visibles con colores forzados (1.4.11).
- **Movimiento:** ninguno.

## 7. Textos (ES / EN)

**En la app:** ninguno.

**Web** (no son ARB; viven en `landing/`). La cabecera y el pie usan los textos de la landing; el plan decide si se juntan en un solo archivo de textos o se comprueba que coinciden.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `webOnThisPage` | En esta página | On this page | **Nuevo.** Nombre visible de la navegación del índice (CA-026-04) |
| `webBackHome` (023) | Volver al inicio | Back to home | Sin cambios de texto. Encima del título (CA-026-01) y en la página de error; la flecha «←» va **fuera** del texto, es decorativa y el lector no la lee |
| `webLanguageName` (023) | Español | English | Pasa a ser el nombre que anuncia cada opción del selector, marcado con su idioma (CA-026-07); el plan dice si sigue además como titular de cada mitad sin JavaScript (sin saltar niveles, CA-026-10) |
| `nav.home` (landing) | `{app}, inicio` | `{app}, home` | Nombre del logotipo |
| `nav.download` (landing) | Descargar | Download | Cabecera (CA-026-02) |
| `nav.lang` (landing) | Idioma | Language | Nombre del grupo del selector |
| `footer.help`, `footer.privacy`, `footer.licenses` (landing) | Ayuda · Privacidad · Licencias | Help · Privacy · Licenses | Pie |
| `footer.legal` (landing) | © 2026 `{app}` | © 2026 `{app}` | Pie |
| `footer.nav` (landing) | Ayuda, privacidad y licencias | Help, privacy and licenses | Nombre de la navegación del pie |
| `licensesWebTitle` (025) | Código de esta web | Code of this website | Sin cambios de texto; con JavaScript, solo en el idioma elegido (CA-026-12) |
| `webContact`, `webPageTitle`, `webNotFoundTitle`, `webNotFoundBody`, `webLastUpdated`, `webLicensesVersion`, `webLicensesLatestBuild`, `webLicensesInApp`, `webLicensesFile`, `webNoticesTitle` (023) | Sin cambios | Sin cambios | Siguen igual; `webBackHome` y `webLastUpdated` cambian de sitio (§10) |
| `webSwitchToEnglish`, `webSwitchToSpanish` (023) | — | — | **Se retiran** (CA-026-09): los sustituye el selector |
| Frases de «Esta web» de la política | Se redactan en la implementación (CA-026-14) | Igual | Revisión del propietario |

## 8. Fuera de alcance

- Cambiar el **contenido** de la Ayuda, de las licencias o de la página de error, o el de la política más allá de CA-026-14.
- Páginas nuevas (preguntas frecuentes, prensa, etc.), más idiomas o direcciones por idioma.
- Cambiar la landing, salvo lo de CA-026-16: su regla de idioma (`?lang=`, valor guardado no válido), su cabecera, su pie o lo pendiente de la 025 (H-025-03, H-025-05).
- Renombrar la clave guardada `una-lang` (CA-026-13).
- Un menú (como el de la referencia): la cabecera solo lleva el logotipo y «Descargar».
- Cualquier cambio en la app (incluido pasar el idioma de la app a la web).
- Publicar la web, el proyecto de Vercel y el dominio (F6).
- Animaciones, ilustraciones o notas de color en estas páginas.

## 9. Preguntas abiertas

- **Q-026-1 [Resuelta, propietario, 2026-11-17: a)] · Alcance.** El aspecto de la landing en las cuatro páginas; el contenido no cambia.
- **Q-026-2 [Resuelta, propietario, 2026-11-17: a)] · Idiomas.** Un idioma cada vez con el selector y la elección recordada; sin JavaScript, los dos; la app no cambia.
- **Q-026-3 [Resuelta, propietario, 2026-11-17: a)] · JavaScript.** Un programa pequeño y propio, solo para el idioma; sin estilos en línea.
- **Q-026-4 [Resuelta, propietario, 2026-11-17: a)] · Diseño.** Lo propone la spec; DEV-60; revisión en el navegador.
- **Q-026-5 [Resuelta, propietario, 2026-11-17: a)] · Programa frente al «sin JavaScript» del 2026-11-14.** «Quiero que el idioma se pueda elegir y no se vean las 2 a la vez. Si hace falta usar JavaScript lo cambiamos para que se use.» Mismo mensaje: **cabecera fija** al estilo de superplay.co/terms; el selector de idioma se puede ir con el scroll.
- **[Suposición]** Se confirman al aprobar (si no se dice nada, se quedan así):
  - la cabecera, con fondo de papel opaco y sin ser fija por debajo de 540 px de alto (CA-026-02);
  - el índice no es un encabezado y no va en Licencias ni en la página de error (CA-026-04);
  - `?lang=` no cambia nada en estas páginas (CA-026-06);
  - sin enlace para saltar al contenido, y objetivos de 44 × 44 (CA-026-10);
  - las líneas de los avisos se parten (CA-026-12);
  - 10 KB para el programa (CA-026-15);
  - se aceptan CL-026-1, 7 y 8, y la diferencia conocida de CL-026-11.
- **Nota [Hecho, leído en el código el 2026-11-17]:** la landing, copiada tal cual de la maqueta (enmienda del propietario del 2026-11-13), decide el idioma con el **primer idioma del navegador**, admite `?lang=` y, con un valor guardado que no es válido, sale en inglés (`landing/home/src/shared/locale.js` e `i18n.js`). En cambio, CA-025-09 pide recorrer toda la lista de idiomas, sin parámetros, y CL-025-16 pide ignorar un valor no válido. Esta spec adopta el **paso 3 tal como lo hace hoy la landing**, para que las dos coincidan en el caso normal, e ignora los valores no válidos como pide CL-025-16. Alinear la landing con CA-025-09 y CL-025-16 es una corrección de la 025, fuera de esta spec.

## 10. Enmiendas

Se anotan al aprobar esta spec como «Enmienda (spec 026, Aprobada; en vigor cuando la 026 se implemente)».

### 10 a. Spec 023

| Dónde | Hoy dice | Pasa a decir |
|---|---|---|
| Dependencias / CA-023-13 | Las otras cuatro: los dos idiomas en la misma dirección, ES y después EN, con un enlace que salta a la otra mitad; sin JavaScript; la web no usa paquetes de terceros en el navegador | Con JavaScript, **un idioma cada vez** con el selector (CA-026-06 y 07); sin JavaScript, igual que hoy, con ES / EN como enlaces a las mitades (CA-026-09). Sigue **sin paquetes de terceros** |
| CA-023-14 | Ningún script en línea; sin programas (salvo «/», 025) | Las cuatro admiten programas **del propio origen**; siguen sin programas en la página y **sin estilos en línea** (CA-026-13) |
| CA-023-15 | Sin animaciones; tokens; AA; 200 % y 320 px | Igual, más la cabecera fija, el selector, la página actual y los 44 × 44 (CA-026-02 y 10) |
| CL-023-4 | «La página sale igual, primero en español» | Con JavaScript, el idioma de CA-026-06; sin JavaScript, igual que hoy |
| CL-023-5 | Las otras cuatro no usan JavaScript | Lo usan solo para el idioma; sin él, todo se lee (CA-026-09) |
| §5 | Estados de las webs sin JavaScript | Los de la 026 §5 |
| §6 (Webs) | Enlace para saltar al otro idioma; sin animaciones | El selector bajo la cabecera; sin animaciones |
| §7 | `webSwitchToEnglish` y `webSwitchToSpanish`; `webBackHome` y `webLastUpdated` en el pie | Las dos primeras se retiran; `webBackHome` va encima del título y `webLastUpdated` bajo el título de la política (CA-026-01 y 04) |
| C-023-2 y C-023-3 | Comprobaciones «sin JavaScript» | Con y sin JavaScript (C-026-1 a 3) |
| DEV-58 | Webs sin diseño, con los tokens | El aspecto pasa a DEV-60 |

### 10 b. Spec 025

| Dónde | Hoy dice | Pasa a decir |
|---|---|---|
| §0 | «Las otras cuatro páginas […] no cambian de reglas» | Cambian en la 026 |
| CA-025-01 (Verificable) | `/help` y la página de error, idénticas byte a byte a las de antes | Las comprueba la 026 |
| CA-025-12 | Las cabeceras de las otras cuatro páginas **no se relajan** | Se relajan solo en programas del propio origen (CA-026-13) |
| CA-025-13 | La política, las licencias y la ayuda funcionan sin JavaScript | Usan un programa solo para el idioma y se leen enteras sin él (CA-026-14) |
| §10 de la 025 | `webLanguageName`, solo en la página de error | Nombre de las opciones del selector (026 §7) |
| CL-025-2 | Un enlace al cierre abre en el cierre (pendiente) | Lo cumple la 026 (CA-026-16) |

### 10 c. ADR-0009 y ADR-0027

Un ADR nuevo, en el plan: las cuatro páginas llevan un programa **propio**, sin dependencias, solo para el idioma; ninguna biblioteca de terceros en ellas. Los dos ADR reciben la marca de enmienda.

## 11. Casillas (verificación a mano)

| Casilla | Qué | Dónde | CA |
|---|---|---|---|
| C-026-1 | Las cuatro páginas, ES y EN, en los tamaños de CA-026-11, frente a la landing; cabecera fija al bajar (y no fija en 844 × 390); licencias a 320 px y 400 %; una ruta inventada; «Descargar» desde cada página | Chrome de escritorio y de Android (emulador); revisión del propietario | 01 a 05, 11, 12, 16 |
| C-026-2 | Sin salto al cargar (Slow 4G, sin caché, tira de imágenes); peticiones y almacenamiento: solo el propio origen, sin cookies, solo el idioma guardado | Chrome de escritorio; Safari de macOS si el propietario lo mira | 08, 13 |
| C-026-3 | Teclado (foco nunca bajo la cabecera), zoom 200 % y 400 %, 320 px, espaciado de texto, colores forzados, con y sin JavaScript; TalkBack con Chrome en el emulador. Si TalkBack no se puede probar (como en la 025), se anota «sin verificar» con el motivo y el propietario lo acepta o no al cerrar | Chrome (escritorio y emulador) | 09, 10 |
