# Spec 017: Bloquear zoom

- **Estado:** **Aprobada** (propietario, 2026-10-07). Sesión 1 del flujo SDD hecha: solo la spec. El propietario respondió a todas las preguntas (Q-017-1 a 9), **enmendó D24** (ver abajo) y confirmó sus dos lecturas (el desplazamiento que se conserva y el subtítulo). Revisada dos veces por `spec-reviewer` y `a11y-reviewer` (2026-10-07), con sus hallazgos aplicados. Con la aprobación quedan hechos la **enmienda al ADR-0022** y el **DEV-54**. Siguiente: el plan (sesión 2); hasta que esté aprobado no hay código.
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Cuarta de las specs 014–019 (después de la 014, la 015 y la 016, fusionadas). Tamaño **S**.
- **Reglas de producto:** R18 (Ajustes: pantalla siempre activa, **bloquear zoom** e información), R17 (varias imágenes con carrusel), R3 (imágenes de la galería), R8 (abrir → tarea actual rápido), **propuesta de valor 2**
- **Pantallas del prototipo:** 16 "Ajustes" (`Ajustes.dc.html`, `Main.dc.html`: la fila «Bloquear zoom», `lockZoom`, `toggleZoom`). **El prototipo solo dibuja el interruptor (icono de lupa con un signo menos, fila de 64 px): no tiene subtítulo y no hace nada con él**, así que el efecto sobre la foto **no tiene diseño** y se decide aquí. Registrado como **DEV-54** (`docs/design/prototype-deviations.md`, 2026-10-07). Ver `docs/design/screen-map.md`
- **Decisiones y ADR relacionados:**
  - **D22** (orden de Ajustes: «… · Pantalla siempre activa · **Bloquear zoom** · …»; **todos los interruptores, apagados por defecto**; interruptor encendido con el token `#FFDC58`).
  - **D24** (propietario, 2026-10-04): «Bloquear zoom: solo en tareas con imagen; impide el pellizco, el desplazamiento y el swipe del carrusel, y la foto se ve entera. Sirve para dibujar encima de la foto. Ocultar también los controles, a decidir con un caso real.» **Enmendada por el propietario el 2026-10-07** (respuestas a Q-017-1 a 7): **la foto no se ajusta ni se muestra «entera»: sigue al 100 % del ancho, como siempre, y se queda con el desplazamiento que tenía al encender el bloqueo; el bloqueo impide el pellizco y el desplazamiento, pero el swipe del carrusel sigue funcionando; los controles no se ocultan.** Los casos extremos (fotos muy altas o muy apaisadas) no se tratan ni se prueban.
  - **[ADR-0022](../../docs/adr/0022-interaccion-con-varias-fotos.md)** *Interacción con varias fotos*: dice que «la 017 añadirá su decisión a este ADR como enmienda (qué bloquea y cómo se ve la foto)». Esa enmienda está **redactada** en el ADR-0022 (2026-10-07; aceptada por el propietario, Q-017-6). **[ADR-0013](../../docs/adr/0013-sin-visor-de-imagenes.md)** (el pellizco de vistazo y la lupa del sistema) y **ADR-0015**.
  - **D10 enmendada** (el horizontal de la tarea con imagen), **DEV-41**, **DEV-42** (el giro), **DEV-43** (pellizco que vuelve al soltar), **DEV-53** (el carrusel) y **DEV-52** (Ajustes).
  - Modelo de amenazas (`docs/security/threat-model.md`): T-2 (lo que se guarda en los ajustes no contiene contenido de tareas) y T-7 (valores guardados no fiables). Sin riesgo nuevo.
- **Dependencias:** **015** (Ajustes: el interruptor, el guardado de ajustes, CA-015-03, 05, 25 y 26), **016** (el carrusel, que esta spec no cambia), 007 (imagen), 008 (el giro), 001 (CA-001-09 y 12: arranque y vuelta), 011 (Recientes). **Sin esquema de BD nuevo, sin permisos y sin dependencias nuevas** (CA-017-16).
- **Nomenclatura:** «zoom» es todo lo que cambia el tamaño o la parte visible de la foto: el **pellizco** y el **desplazamiento vertical**. El cambio de foto del carrusel (swipe) **no** es zoom y no se bloquea. «Bloquear zoom» es el nombre del ajuste (el prototipo y D22). Los ajustes de Android se llaman «Ajustes del sistema».

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Dar a quien quiere **trabajar encima de una foto** (marcarla o dibujar sobre ella con un lápiz, con el dedo o con otra herramienta) una **foto que no se mueve**: un ajuste en Ajustes que, encendido, deja la foto de la tarea actual tal como está (al 100 % del ancho y con el desplazamiento que tenía) y hace que **no se amplíe ni se desplace** con los toques, para que nada cambie bajo el dedo.

## 2. Historias de usuario

- **HU-017-1** Como usuario que dibuja sobre una foto (un plano, un horario, una lista), quiero que la foto no se amplíe ni se desplace al tocarla, para no perder mi sitio ni mi trazo.
- **HU-017-2** Como usuario, quiero colocar la foto donde me conviene (desplazándola antes) y que **se quede ahí** al encender el bloqueo, para trabajar sobre la parte que me interesa.
- **HU-017-3** Como usuario, quiero encender y apagar el bloqueo en Ajustes, que **empiece apagado** y que se conserve al cerrar la app, para activarlo solo cuando lo necesito.
- **HU-017-4** Como usuario con lector de pantalla, teclado o switch, quiero encender y apagar el ajuste y seguir usando la tarea, incluido el cambio de foto, **sin gestos que no pueda hacer**.
- **HU-017-5** Como usuario con poca visión que usa la lupa del sistema, quiero que el bloqueo **no me quite la lupa** de Android.

## 3. Criterios de aceptación

**Trazabilidad HU → CA**

| HU | Criterios |
|---|---|
| HU-017-1 | CA-017-08 y 09 |
| HU-017-2 | CA-017-05, 07 y 12 |
| HU-017-3 | CA-017-01 a 05 y 12 |
| HU-017-4 | CA-017-02, 09 y 14 |
| HU-017-5 | CA-017-13 |
| Transversales | CA-017-06, 10, 11, 15, 16 y 17 |

**El ajuste**

- **CA-017-01 La fila en Ajustes (tablero 16)**
  - **Dado** Ajustes (nivel 1, CA-015-01b)
  - **Cuando** se muestra
  - **Entonces** debajo de **Pantalla siempre activa**, en el mismo bloque y con el separador de 1 px de las filas de un bloque, hay una fila **«Bloquear zoom»** con el icono del tablero 16 (una lupa con un signo menos) a la izquierda y el interruptor a la derecha. Queda, de arriba abajo: Idioma · separador de bloque · Pantalla siempre activa · **Bloquear zoom** · separador de bloque · Información (Política de privacidad, Licencias de terceros) · Ayuda. El icono es decorativo para el lector. La fila lleva un subtítulo que dice el alcance y el efecto, «Solo imágenes: sin zoom ni scroll» (el prototipo no lo tiene; DEV-54). Toda la fila es el objetivo táctil (≥ 44 pt visibles y zona de ≥ 48 dp, CA-015-01a). **Notificaciones** sigue sin aparecer hasta la spec 019.
  - **Verificable:** un test de widgets recorre Ajustes y comprueba el orden de las filas y de los separadores, con la fila nueva donde dice D22.
- **CA-017-02 El interruptor (como CA-015-03)**
  - **Dado** la fila
  - **Entonces** es un **interruptor apagado por defecto** (D22) que sigue **exactamente** las reglas de CA-015-03: se guarda primero y solo cuando el guardado se confirma cambia de estado (sin cambio optimista); el estado lo da **la posición del pomo**, no el color (WCAG 1.4.1); el borde de tinta cumple 3:1 (WCAG 1.4.11) en los dos estados; con «reducir movimiento» el pomo cambia de sitio sin animación; no cambia mientras hay un guardado en curso. **Dos guardados de filas distintas que se solapan** (p. ej. dos toques casi seguidos en «Pantalla siempre activa» y en «Bloquear zoom») se aplican **uno tras otro** y **los dos valores quedan guardados**, sin que ninguno pise al otro; un segundo toque en la **misma** fila mientras se guarda se ignora (CL-017-7). Es el mismo control que «Pantalla siempre activa» (CA-015-19): sin colores ni medidas sueltos.
  - **Verificable:** los mismos tests que CA-015-03 (posición del pomo distinta entre estados, `toggled` coherente, no cambia hasta confirmarse el guardado), un test de dos toques casi simultáneos en filas distintas (los dos valores quedan guardados) y un *golden* de los dos estados en ES y EN.
- **CA-017-03 Persistencia, valor por defecto y valores no válidos (como CA-015-05 y 26)**
  - **Dado** el interruptor cambiado
  - **Cuando** se cierra y se vuelve a abrir la app (también tras morir el proceso)
  - **Entonces** conserva el valor. Las **instalaciones que ya existen** no tienen valor guardado y toman el valor por defecto, **apagado**: el comportamiento de ahora no cambia para nadie hasta que lo encienda.
  - El ajuste vale «encendido» **solo** si el valor guardado es exactamente el de «encendido»; cualquier otra cosa, y **cualquier fallo al leerlo o decodificarlo**, es «apagado», no impide el arranque y no muestra ningún error.
  - El valor viaja con la copia de seguridad igual que los demás ajustes, donde el sistema la hace (ADR-0004; CL-015-18).
  - **Verificable:** tests de lectura con ausente, `true`, `false`, texto, número y valor ilegible (también el que llega de una copia restaurada, CL-017-8); test de persistencia entre dos arranques.
- **CA-017-04 Error al guardar (como CA-015-25)**
  - **Dado** que no se puede guardar el ajuste
  - **Cuando** el usuario toca la fila
  - **Entonces** el interruptor **se queda en su valor anterior**, la app sigue funcionando y bajo **esa** fila se ve «No se pudo guardar el ajuste.» (el aviso y la clave de la 015) como aviso que el lector anuncia solo, sin mover el foco y sin mostrar ni registrar el error. **Hay un aviso por fila**: cada uno se anuncia solo cuando falla su fila, se quita cuando esa fila se guarda bien o al salir de Ajustes, y si están los dos a la vez se leen cada uno justo después de su fila, sin eco ni anuncio doble.
  - **Verificable:** el test de no-registro de CA-015-25 (`Exception('texto-secreto')` no aparece en pantalla ni en `debugPrint`/`print`, y `FlutterError.onError` no recibe nada) con la fila nueva, y el caso de los dos avisos a la vez (CA-015-20g).
- **CA-017-05 Se aplica sin reiniciar y la foto no se mueve al ir a Ajustes**
  - **Dado** el ajuste cambiado en Ajustes
  - **Cuando** el usuario cierra Ajustes y vuelve a la tarea actual
  - **Entonces** la tarea ya se comporta con el nuevo valor, **sin reiniciar la app y sin volver a cargar la tarea**: se ve la misma pantalla, **la misma foto** del carrusel y **el mismo desplazamiento** que tenía al salir (CA-015-15: la imagen no cambia al abrir y cerrar Ajustes; se aclara en CA-016-10 que «Ajustes encima» cuenta como a la vista). Si la app estuvo **10 minutos o más en segundo plano** estando en Ajustes (p. ej. una web abierta desde Ajustes en el navegador), se aplica CA-001-12 / CA-015-16: la tarea actual desde su primera foto y arriba, ya con el nuevo valor.
  - **Verificable:** un test de widgets desplaza una foto, cambia el ajuste, vuelve a la tarea y comprueba el comportamiento, la foto a la vista, el desplazamiento, que la tarea no se vuelve a cargar y que las acciones del nodo de la tarea ya son las del nuevo valor; con el reloj inyectado simulando 10 minutos en segundo plano, la primera foto arriba.

**Qué hace al ver la tarea**

- **CA-017-06 Alcance: solo la tarea actual con imagen (D24)**
  - **Dado** el interruptor encendido
  - **Cuando** se ve la tarea actual
  - **Entonces**:
    - si tiene **una imagen o un grupo de fotos**, se aplica lo de CA-017-07 a 11;
    - si es **solo texto, un PDF o una web**, o muestra la tarjeta «Adjunto no disponible», **no cambia nada** (el zoom propio del PDF, CA-008-10, y la vista de la web siguen como están); el interruptor puede estar encendido y así se ve en Ajustes;
    - el **editor**, la **pila de preselección**, el **listado** y su miniatura, el menú y la card de deshacer **no cambian**;
    - «Pantalla siempre activa» (CA-015-04a a 04d), «Recientes» (spec 011), la rotura y el arrugado al completar o eliminar y la copia de seguridad **no cambian**.
  - **Verificable:** un test de widgets con el ajuste encendido y una tarea de cada tipo (texto, imagen, grupo, PDF, web, «Adjunto no disponible») comprueba que solo la imagen y el grupo cambian; y que el editor y el listado son idénticos con y sin el ajuste.
- **CA-017-07 La foto sigue como siempre y se queda donde está (D24 enmendada)**
  - **Dado** el interruptor encendido y la tarea actual con una imagen o con una foto de un grupo a la vista
  - **Entonces** la foto se ve **exactamente como sin el bloqueo**: al **100 % del ancho**, sin perder nada por los lados, con el logotipo, el menú, el pie (si hay texto), los puntos (si hay grupo) y el botón de completar encima (CA-007-08 y 09, CA-016-10 y 11). Los controles **no se ocultan** (Q-017-3). La foto **se queda con el desplazamiento vertical que tenía** cuando se encendió el bloqueo (el que el usuario le dio antes): no vuelve arriba ni salta (salvo que se mueva a propósito con las acciones del lector o del teclado de CA-017-09). Cada foto de un grupo conserva el suyo; una foto que no se ha visto empieza arriba (CA-016-10); al abrir la app en frío, la primera foto arriba (CA-016-08).
  - **Verificable:** con una foto más alta que la pantalla (p. ej. 1:2) y otra más baja, desplazadas antes de encender el bloqueo, el tamaño y el desplazamiento no cambian al encenderlo ni al volver de Ajustes (CA-017-05); en un grupo, cada foto conserva el suyo.
- **CA-017-08 Sin pellizco ni desplazamiento por contacto (D24; enmienda CA-007-09 y 10 y CA-016-10)**
  - **Dado** el interruptor encendido y la foto a la vista
  - **Cuando** el usuario **pellizca**, **arrastra hacia arriba o abajo** o en diagonal (con el reparto por dirección de CA-016-10: tras 16 dp, horizontal solo si el desplazamiento horizontal supera 1,5 veces el vertical), **con cualquier número de dedos, con lápiz, con ratón, con la rueda o con el *trackpad***, o toca la foto
  - **Entonces** **la foto no se mueve, no se amplía y no se desplaza**, ni siquiera un instante y sin ninguna animación de vuelta; tocarla no hace nada (como siempre, CA-007-09). Esto vale con el móvil en vertical y en horizontal (CA-017-10) y con cualquier foto de un grupo. El reparto del gesto por su dirección es el de CA-016-10: un gesto que se decide **vertical** (o diagonal) no hace nada, y uno que se decide **horizontal** cambia de foto con un grupo (CA-017-09); con dos dedos nunca se cambia de foto. El bloqueo impide mover o ampliar la foto **por contacto**; no quita las órdenes deliberadas (CA-017-09).
  - Los toques sobre el logotipo, el menú y el botón de completar (incluido «Mantener pulsado») **siguen funcionando** como siempre.
  - **Verificable:** un test de widgets simula pellizco, arrastre vertical y diagonal, con uno, dos y tres dedos, lápiz (`stylus`), ratón y rueda, y comprueba que la posición, el desplazamiento y el tamaño de la foto no cambian (con un caso diagonal por debajo del umbral de 1,5 y otro por encima); y que, con el ajuste apagado, los mismos gestos siguen haciendo lo de la 007 y la 016 (sin regresión).
- **CA-017-09 El swipe y las alternativas siguen, y las órdenes deliberadas también (D24 enmendada; Q-017-2, 8 y 9)**
  - **Dado** el interruptor encendido
  - **Cuando** el usuario desliza **horizontalmente** sobre un grupo de 2 a 10 fotos con **cualquier puntero** (dedo, lápiz o ratón; Q-017-9), o usa un lector de pantalla, Switch Access, el control por voz o el teclado
  - **Entonces** **todo funciona como en la 007 y la 016**: el swipe cambia de foto (infinito, 18 % del ancho o gesto rápido, 0,28 s o instantáneo con «reducir movimiento»), los puntos informan, y siguen las acciones **«Foto siguiente» y «Foto anterior»**, las de desplazamiento horizontal estándar y las flechas izquierda y derecha, con el mismo anuncio único «Foto {i} de {n}» (CA-016-09, 10, 20 y 21). **[Resuelto, Q-017-8]** También siguen las acciones de **desplazamiento vertical** del lector y del switch (solo las que se pueden hacer, CA-007, §6), «desplazar adelante / atrás» (que hoy recorren la foto alta y luego pasan a la siguiente, ADR-0022) y Av Pág / Re Pág: son **órdenes deliberadas** que nunca se hacen sin querer, y sin ellas quien no puede tocar la pantalla no podría colocar la foto sin apagar el bloqueo. El bloqueo impide mover la foto **por contacto**, no por orden. La excepción a P6 del ADR-0022 queda **igual**.
  - **Verificable:** un test de semántica comprueba que el nodo de la tarea expone **las mismas acciones y en el mismo orden con y sin el bloqueo** (Foto siguiente, Foto anterior, Completar tarea, Eliminar tarea, más las de desplazamiento de la 007); que «desplazar adelante» y las teclas hacen lo de la 016 con el bloqueo encendido; que el swipe (con dedo y con lápiz) sigue cambiando de foto; y que cambiar de foto por acción, tecla y gesto anuncia una sola vez «Foto {i} de {n}».
- **CA-017-10 Giro con el bloqueo (D10 enmendada; Q-017-5)**
  - **Dado** el interruptor encendido y la tarea con imagen o con grupo a la vista (sin el menú, el editor ni el listado encima)
  - **Cuando** gira el móvil a horizontal
  - **Entonces** la tarea **sigue girando** como hoy (CA-007-11, CA-008-11, CA-016-12): en horizontal se ven solo **la foto, al 100 % del ancho, y el logotipo**, sin menú, botón de completar, pie ni puntos; **sin pellizco ni desplazamiento por contacto** (CA-017-08); el swipe y las acciones de foto, de desplazamiento y las flechas siguen (CA-017-09), con el foco de teclado visible como en CA-016-12; se mantiene la foto que se veía; completar y eliminar siguen como acciones del lector. Al volver a vertical se ve todo. Respeta el bloqueo de rotación del sistema.
  - **Girar y volver puede dejar la foto en otro desplazamiento y el usuario tendrá que recolocarla: no es un problema** (propietario, 2026-10-07). No se exige que la ida y vuelta conserve el desplazamiento exacto.
  - **Consecuencia conocida (aceptada por el propietario, 2026-10-07):** en horizontal la foto ocupa todo el ancho de la pantalla horizontal y, como no se puede desplazar por contacto, **solo se ve un tramo de ella** (a 800 × 360 dp, una foto 3:4 muestra aproximadamente un tercio de su alto). Para ver otra parte: poner el móvil en vertical (se ve más alto), apagar el bloqueo o usar las acciones de desplazamiento (CA-017-09). Con el móvil fijo en horizontal no hay menú (ADR-0013): se llega a Ajustes volviendo a vertical.
  - **Verificable:** un test de widgets en 800 × 360 dp comprueba que solo se ven la foto y el logotipo, que no hay desplazamiento ni pellizco por contacto, que el swipe cambia de foto y que se mantiene la foto a la vista al girar y volver.
- **CA-017-11 Al abrir y rendimiento (P2, R8)**
  - **Dado** el interruptor encendido y la tarea actual con una imagen o un grupo
  - **Cuando** se abre la app en frío
  - **Entonces** el bloqueo **ya está activo desde el primer fotograma** (no hay un momento en que la foto se pueda ampliar o desplazar antes de leerse el ajuste), la foto aparece en el tiempo de CA-001-09 (< 1 s p50, dispositivo de referencia, *release*) y **el arranque no empeora** (como CA-015-23): el ajuste no añade tiempo y el aumento del p50 no supera la diferencia entre dos pasadas de la línea base el mismo día. Con un grupo de 10 fotos se cumplen también CA-016-08 y CA-016-23. El bloqueo no cambia lo que se pinta ni su memoria **[Suposición, se confirma en el plan]**.
  - **Verificable:** un test de widgets arranca con el ajuste encendido y comprueba que los gestos de CA-017-08 ya no hacen nada en el primer fotograma en que la foto es tocable; el p50 y la memoria, medidos en el dispositivo como en CA-011-05 y CA-016-23.
- **CA-017-12 Apagar el bloqueo**
  - **Dado** el interruptor apagado de nuevo
  - **Cuando** el usuario vuelve a la tarea
  - **Entonces** la foto se comporta **exactamente como antes de esta spec**: desplazamiento vertical, pellizco que vuelve al soltar y, con grupo, swipe (CA-007-09 y 10, CA-016-09 y 10), **desde donde estaba**: no vuelve arriba (el zoom nunca se conserva, siempre al 100 %).
  - **Verificable:** un test de widgets enciende y apaga el ajuste y repite los gestos de la 007 y la 016 (sin regresión), con el desplazamiento de partida conservado.

**Accesibilidad y transversales**

- **CA-017-13 La lupa del sistema sigue funcionando (P6, ADR-0013; HU-017-5)**
  - **Dado** el interruptor encendido o apagado
  - **Cuando** el usuario usa la ampliación de accesibilidad de Android (lupa, en cualquiera de sus modos)
  - **Entonces** funciona **igual que en cualquier otra app**: la app no la impide, no la anula ni la desactiva en la tarea con el bloqueo. «Bloquear zoom» es del contenido de la app, no del sistema. **Verificable solo a mano** en el dispositivo (casilla de la 022, en Android 8–11, que solo tiene pantalla completa, y en 12+); no hay test automático; el plan revisa que nada en la app la desactive ni absorba los eventos de la ampliación en ventana de Android 12+.
- **CA-017-14 Lectura, foco y teclado del ajuste y de la tarea (WCAG 4.1.2, 2.4.3, 2.1.1)**
  - **Dado** un lector de pantalla o un teclado
  - **Entonces**:
    - **la fila de Ajustes** se lee como un interruptor, **con el nombre «Bloquear zoom» primero** (para que el control por voz «tocar Bloquear zoom» la encuentre, WCAG 2.5.3), luego su subtítulo y su estado («activado» o «desactivado») que da el sistema; **un solo elemento**, que se activa con un toque o con Enter / Espacio; entra en el orden del teclado entre «Pantalla siempre activa» e «Información», con anillo de foco visible, y se desplaza a la vista con el texto al 200 % (CA-015-21); el orden de lectura de Ajustes es el de CA-015-20 con la fila nueva y los avisos de CA-017-04;
    - **la tarea con el bloqueo** se lee **igual que sin él** (CA-007-21, CA-016-20): no se anuncia que el zoom esté bloqueado ni se añade ningún anuncio al abrirla; el foco, los anuncios y las acciones de CA-016-21 no cambian en nada (CA-017-09);
    - al cambiar el interruptor **no hay anuncio propio**: el lector dice el nuevo estado del interruptor (CA-015-03), sin eco.
  - **Verificable:** un test de semántica de la fila (un nodo, `toggled`, el nombre primero, el subtítulo) y del orden de lectura y de Tab de Ajustes con la fila nueva y los dos avisos; un test de que la lectura de la tarea es idéntica con y sin el ajuste, y `androidTapTargetGuideline` y `labeledTapTargetGuideline` sobre la tarea con grupo y el bloqueo (logotipo, menú y botón de completar). Foco al volver de Ajustes: el aceptado en CA-015-20h, sin casilla nueva.
- **CA-017-15 Reducir movimiento y texto grande**
  - **Dado** «reducir movimiento» o el texto al 200 % en un móvil de 360 dp, en español y en inglés
  - **Entonces**: el pomo se mueve sin animación (CA-015-01d); el nombre y el subtítulo de la fila pasan a más líneas **sin cortarse** y la fila crece en alto (CA-015-22); el subtítulo cumple ≥ 4,5:1 (`textMuted` sobre papel); la tarea no cambia con el texto grande por el bloqueo (CA-016-22). Nada se corta ni se solapa con el interruptor.
  - **Verificable:** *goldens* y desbordamientos al 200 % de Ajustes con la fila nueva, en ES y EN, con `setUpAll(loadAppFonts)` (`test/support/fonts.dart`), más `androidTapTargetGuideline` y `labeledTapTargetGuideline`.
- **CA-017-16 Sin esquema, permisos, dependencias ni red nuevos (P4, P5, P11; como CA-015-17)**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior
  - **Entonces** el esquema de datos **no cambia** (el ajuste se guarda con los demás ajustes de la app, sin migración), no hay permisos nuevos (solo `INTERNET`), no hay dependencias nuevas, no hay conexiones nuevas ni analítica y **no se guarda nada del contenido de las tareas** (T-2).
  - **Verificable por diff:** `pubspec.yaml`, `pubspec.lock`, `AndroidManifest.xml` y `res/xml/*` sin cambios; `tools/check-android-permissions.sh release` da solo `INTERNET`; `schemaVersion` y la captura de `drift_schemas` sin cambios; un test de que los ajustes guardados son solo `locale`, `keepScreenOn` y el nuevo.
- **CA-017-17 Textos en español e inglés (P7)**
  - **Dado** los textos de §7
  - **Entonces** cada clave existe en los dos ARB con su descripción, ninguno visible o anunciado está incrustado y todo lo que se recorre lleva el idioma de la app (el test de voz de CA-015-11 incluye las claves nuevas). Verificable con el test de claves ES/EN y `/i18n-check`.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-017-1 | Ajuste encendido y la tarea actual es de solo texto, PDF o web | Sin efecto. Al llegar una tarea con imagen (p. ej. tras completar), ya se ve con el bloqueo, arriba (CA-017-06) |
| CL-017-2 | Se enciende o se apaga el ajuste con un grupo y se estaba viendo la foto 3 | Al volver de Ajustes se ve **la foto 3, en el mismo desplazamiento**; solo si la app estuvo 10 minutos o más en segundo plano, la primera arriba (CA-017-05) |
| CL-017-3 | Se abre Ajustes con la card de deshacer visible | Como siempre: la eliminación pasa a ser definitiva (CA-015-24); nada cambia por este ajuste |
| CL-017-4 | Se cambia el idioma (Ajustes) | La fila cambia de idioma; el valor del interruptor se conserva |
| CL-017-5 | La foto a la vista de un grupo es «Foto no disponible» | Se ve el recuadro como siempre (CA-016-18a); el swipe sigue y no hay pellizco ni desplazamiento |
| CL-017-6 | Swipe desde el borde de la pantalla (gesto de volver del sistema, Android 10 o posterior) | Es del sistema, como hoy (CA-016-10): la app no pide excluir el gesto, con o sin bloqueo |
| CL-017-7 | Doble toque rápido en la fila o dos toques mientras se guarda | Se aplica una sola vez / el segundo se ignora (CA-017-02, como CL-015-1) |
| CL-017-8 | Copia de seguridad restaurada con el ajuste ilegible o con un valor extraño | Apagado y la app arranca (CA-017-03) |
| CL-017-9 | Web de pruebas (ADR-0010) | El mismo ajuste y el mismo efecto; el pellizco del ratón o del *trackpad* y la rueda tampoco amplían ni desplazan la foto con el bloqueo encendido |
| CL-017-10 | Un trazo hasta el botón de completar o el menú | Los controles siguen encima de la foto (Q-017-3) y funcionan como siempre; completar exige mantener pulsado 1,2 s y no tiene deshacer (P-4). **Riesgo aceptado por el propietario** al no ocultar los controles |
| CL-017-11 | Una foto más alta que la pantalla con el bloqueo encendido | Se queda donde estaba; la parte que no se ve no se puede alcanzar con el bloqueo: se apaga, se desplaza y se vuelve a encender. Es lo esperado (D24 enmendada) |
| CL-017-12 | Mantener pulsado el botón de completar con el bloqueo | Igual que siempre (1,2 s); el bloqueo no afecta a ese gesto |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| No se pudo guardar el ajuste | Falla el guardado al tocar la fila | El interruptor no cambia y bajo esa fila, «No se pudo guardar el ajuste.» (CA-017-04) |
| Valor guardado ilegible | Al arrancar o leerlo | Nada: se usa «apagado» (CA-017-03) |
| Sin imagen en la tarea actual | El ajuste está encendido pero la tarea no es de imagen | Nada distinto: sin efecto (CA-017-06) |
| Foto no disponible o adjunto no disponible | Falta un archivo | Como antes (CA-016-18a y 18b), sin cambios por el ajuste |

## 6. Accesibilidad

- **Pellizco de vistazo (ADR-0013):** la excepción a P6 del pellizco sin alternativa en la app **no se amplía**. Con el bloqueo **no hay pellizco**, porque el usuario lo enciende a propósito (apagado por defecto); la vía para ampliar sigue siendo la **lupa del sistema**, que el bloqueo no toca (CA-017-13). **[Pendiente de comprobar en el dispositivo]** que la lupa sigue funcionando con el bloqueo encendido, en pantalla completa y en ventana, en Android 8–11 y 12+ (casilla de la 022).
- **Swipe del carrusel (ADR-0022):** **no cambia**. Sigue funcionando con el bloqueo, con las mismas alternativas (acciones, desplazamiento horizontal estándar y flechas) y la misma excepción de P6 que ya aceptó el propietario; esta spec no la amplía ni la estrecha (CA-017-09).
- **Desplazamiento vertical:** el bloqueo lo impide **por contacto**; las acciones del lector y del switch y Av Pág / Re Pág **se mantienen** (propietario, 2026-10-07, Q-017-8), de modo que la frase del ADR-0013 («el desplazamiento de una imagen alta sí tiene alternativa», WCAG 2.1.1) sigue siendo cierta. La foto es contenido del usuario, no texto de la app (WCAG 1.4.4 y 1.4.10 no aplican); el subtítulo dice el efecto (CA-017-01).
- **El interruptor en Ajustes (WCAG 4.1.2, 1.4.1, 1.4.11, 2.5.3, 2.5.8, 3.2.2):** un interruptor para el lector, estado por la posición del pomo, borde ≥ 3:1, objetivo ≥ 44 pt (zona de 48 dp), teclado y switch como CA-015-20 a 22; sin gestos; el subtítulo dice el efecto para que nadie se sorprenda.
- **Otros punteros:** el bloqueo de pellizco y desplazamiento vale para el dedo, el lápiz, el ratón, la rueda y el *trackpad* (CA-017-08), que es el caso de uso de dibujar; el swipe del carrusel sigue con cualquier puntero, también el lápiz y el ratón (propietario, Q-017-9).
- **Orientación (WCAG 1.3.4):** el giro de la tarea con imagen sigue siendo la excepción del ADR-0013 (CA-017-10); con el bloqueo, en horizontal solo se ve un tramo de la foto (CA-017-10); la mitigación son las acciones de desplazamiento y el bloqueo de rotación del sistema.
- **Icono:** una lupa con un signo menos puede leerse como «alejar» en otras apps; es decorativo y el nombre lo aclara (se anota en DEV-54).
- **Reducir movimiento y texto grande:** CA-017-15.
- **Voz del sistema (ADR-0020 y ADR-0023):** esta spec no añade anuncios propios; la fila lleva el idioma de la app como el resto de lo que se recorre (CA-017-17).

## 7. Textos (ES / EN)

Claves en camelCase, con el prefijo de Ajustes (`settings…`, como `settingsKeepAwake`). Se reutiliza `settingsSaveError`. Los textos nuevos pasan por `/strings-add` y se registran en `docs/glossary.md`.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `settingsLockZoom` | Bloquear zoom | Lock zoom | Nombre del interruptor (prototipo, tablero 16) |
| `settingsLockZoomHint` | Solo imágenes: sin zoom ni scroll | Images only: no zoom or scroll | Subtítulo. Texto elegido por el propietario (2026-10-07, Q-017-4): lo que se bloquea es el zoom y el scroll. El prototipo no lo tiene (DEV-54) |
| `settingsSaveError` | No se pudo guardar el ajuste. | Couldn't save the setting. | **Ya existe** (CA-015-25); sin cambios |

No hay textos nuevos en la pantalla de la tarea (CA-017-14): el bloqueo no tiene anuncios ni etiquetas.

## 8. Fuera de alcance

- **Dibujar dentro de la app:** no hay herramientas de dibujo, lápiz ni anotaciones; el ajuste solo deja la foto quieta para quien dibuja con otra herramienta (D24).
- **Ocultar los controles** (logotipo, menú, pie, puntos, botón de completar): decidido que **no** (propietario, 2026-10-07, Q-017-3). Si algún día hay un caso real, será otro ajuste o una spec propia.
- **Bloquear el cambio de foto** (el swipe sigue funcionando, Q-017-2) y **ajustar la foto a la pantalla** o mostrarla «entera»: la foto sigue al 100 % del ancho (propietario, 2026-10-07).
- **Indicar en la tarea que el bloqueo está activo:** la tarea no muestra texto ni anuncio del bloqueo; es **deliberado** (CA-017-14).
- **Casos extremos** (fotos muy altas o muy apaisadas): no se tratan ni se prueban (propietario, 2026-10-07, Q-017-7).
- **Bloqueo en PDF o web**, o por tarea, o un atajo en el menú de la tarea o en la propia tarea: el ajuste es global y solo vive en Ajustes (D22, D24).
- **Cambiar o bloquear la lupa del sistema** (CA-017-13), el zoom del PDF (CA-008-10) o la vista de la web.
- Notificaciones (spec 019), iconos (018) y cualquier otro cambio de Ajustes.

## 9. Preguntas abiertas

**Respondidas por el propietario el 2026-10-07** (dejan D24 enmendada, arriba):

- **[Resuelto] Q-017-1 · ¿Qué es «entera»?** «La foto se queda normal. Ajustada al 100 % de ancho. Si he activado bloquear zoom no puedo hacer ni zoom ni scroll. La foto se queda con el scroll que tiene cuando se ha activado bloquear zoom.» → CA-017-07 y 08. *(Confirmado por el propietario el 2026-10-07: la foto se queda donde estaba al encender el bloqueo, también al ir a Ajustes y volver y al apagarlo; una foto no vista empieza arriba.)*
- **[Resuelto] Q-017-2 · ¿Swipe?** «Con el zoom bloqueado el swipe funciona.» → CA-017-09; el swipe y sus alternativas no cambian.
- **[Resuelto] Q-017-3 · ¿Ocultar controles?** «No se ocultan los controles.» → §8, CL-017-10.
- **[Resuelto] Q-017-4 · Subtítulo.** Subtítulo con alcance y efecto; el propietario fija el texto el 2026-10-07: «**Solo imágenes: sin zoom ni scroll**» / «Images only: no zoom or scroll» (CA-017-01, §7).
- **[Resuelto] Q-017-5 · ¿Gira?** «Sí, sigue girando.» → CA-017-10.
- **[Resuelto] Q-017-6 · ¿Cómo se registra?** «Acepto recomendación»: **enmienda al ADR-0022** (qué bloquea: pellizco y desplazamiento vertical; el swipe y sus alternativas no cambian; ninguna excepción nueva a P6), **sin ADR propio y sin subir la constitución** (sigue en 1.9). Se redacta al aprobar la spec.
- **[Resuelto] Q-017-7 · Casos extremos.** «Las fotos siempre ocupan el 100 % de ancho. Los casos extremos no me preocupan. No hay ni que probarlos.» → §8; se han quitado de la spec los casos y las pruebas de fotos muy altas o apaisadas.

- **[Resuelto] Q-017-8 · ¿Se bloquea también el desplazamiento vertical por orden (lector, switch, Av Pág / Re Pág)?** «Acepto recomendación»: **no**; esas órdenes siguen (CA-017-09).
- **[Resuelto] Q-017-9 · ¿Swipe con cualquier puntero?** «Cambia de foto con cualquier puntero.» → CA-017-09.
- **[Resuelto] Giro (revisión de accesibilidad).** «Si se gira y necesitan volver a ajustar, de momento no es problema.» → CA-017-10: no se exige conservar el desplazamiento exacto al girar y volver.
- **[Resuelto] Trazo horizontal sobre un grupo.** «Esta funcionalidad se espera que se haga en fotos únicas. No pasa nada si hace swipe por error. Se considera un caso extremo y no nos preocupamos por él.» → no se trata ni se prueba; se retiró el caso de la spec.

**Suposiciones y pendientes de dispositivo:**

- **[Suposición, se confirma en el plan]** Que el bloqueo no cambia lo que se pinta ni su memoria (CA-017-11).
- **[Pendiente, 022]** La lupa del sistema con el bloqueo encendido (Android 8–11 y 12+), el interruptor con TalkBack, Switch Access, teclado y control por voz, «desplazar adelante / atrás» con el gesto real de TalkBack, el lápiz y el *trackpad*, el giro con el bloqueo y el gesto de volver desde el borde. Las casillas se añaden a «Casillas de la 017» en `docs/PLAN.md` al cerrar la spec.

## 10. Enmiendas a otras specs y documentos (se aplican con la implementación; las marcadas «al aprobar» se hacen al aprobar la spec)

- **PLAN, D24 (esta sesión):** se anota la enmienda del propietario del 2026-10-07.
- **015:** CA-015-01b y CA-015-01c (la fila **Bloquear zoom** aparece en su sitio; Notificaciones sigue pendiente de la 019), CA-015-17 (los ajustes guardados son `locale`, `keepScreenOn` y el nuevo), CA-015-18 (la matriz de «Recientes»), CA-015-20g, 21 y 22 (orden de lectura, teclado y texto grande con la fila nueva y dos avisos posibles) y CA-015-26 (lectura de valores no válidos).
- **007:** CA-007-09 y 10 (con el bloqueo, la imagen no se desplaza ni se amplía) y §6 (la excepción del pellizco no se amplía; con el bloqueo, el desplazamiento por contacto se impide y su alternativa por orden sigue). **016:** CA-016-10 y 12 (con el bloqueo, sin pellizco ni desplazamiento por contacto; el swipe, las acciones de foto y las de desplazamiento por orden siguen; **se aclara que «Ajustes encima» cuenta como a la vista** para conservar el desplazamiento, apoyado en CA-015-15). CA-016-20 y 21 no cambian. **008:** CA-008-11 (la mención del pellizco de la imagen en horizontal: con el bloqueo no hay).
- **ADR-0022:** **enmienda** con la decisión de la 017 (hecho al aprobar, Q-017-6): el bloqueo quita el pellizco y el desplazamiento vertical, no el swipe; corrige la opción 2 («la forma que tomará Bloquear zoom»), que ya no es cierta; la excepción a P6 no cambia de alcance; y que quitar el pellizco y el desplazamiento por contacto es una opción elegida por el usuario, apagada por defecto, no una excepción nueva. Nota en el ADR-0013 («con Bloquear zoom no hay pellizco; la lupa del sistema sigue»). **Constitución:** sin cambios.
- **DEV-54** (hecho al aprobar, 2026-10-07): la fila «Bloquear zoom» con subtítulo (Q-017-4), el icono de lupa con signo menos (puede leerse como «alejar») y el efecto (foto quieta, sin zoom ni scroll, swipe vivo), que el prototipo no define; **nota en DEV-41, DEV-43, DEV-52 (punto 1: ya no faltan «Bloquear zoom») y DEV-53**.
- **`docs/glossary.md`:** término «Bloquear zoom» (esta sesión); al implementar, la fila «Carrusel» recoge la salvedad del bloqueo. **`docs/design/screen-map.md`**, **`docs/PLAN.md`** (trazabilidad R18 → CA-017) y **`CLAUDE.md`** (esta sesión).
- **`docs/architecture.md`** (el ajuste nuevo y cómo decide el comportamiento de la foto) y **`docs/testing.md`** (al implementar). **Modelo de amenazas y checklist de seguridad:** sin cambios previstos (T-2 y T-7 ya cubren los ajustes).

## 11. Trazabilidad con la constitución

| Principio | Cómo se cumple |
|---|---|
| P1 Una tarea a la vez | No cambia: sigue la tarea actual; el bloqueo solo cambia cómo responde su foto (CA-017-06 a 09) |
| P2 Instantáneo al abrir | El bloqueo está activo desde el primer fotograma y el arranque no empeora (CA-017-11) |
| P3 Local y sin conexión | Todo local; el ajuste se guarda en el dispositivo (CA-017-03, 16) |
| P4 Privacidad por defecto | Sin red, permisos ni dependencias nuevos (CA-017-16) |
| P5 Seguridad desde el diseño | Valor guardado validado (solo `true` exacto), sin texto de error ni registros (CA-017-03, 04) |
| P6 Accesible siempre | Interruptor accesible; swipe y alternativas sin cambios; lupa del sistema intacta; ninguna excepción nueva ni ampliada (CA-017-09, 13 a 15, §6; Q-017-6 y 8) |
| P7 i18n | Tabla del §7 en ES y EN (CA-017-17) |
| P9 Tests | Cada CA lleva su línea «Verificable» (el de CA-017-13 y las casillas de dispositivo, a mano en la 022); gestos con dedo, lápiz, ratón y rueda, semántica, *goldens* y desbordamientos al 200 % con fuentes reales; migración: sin cambio de esquema (CA-017-16) |
| P10 Crecer sin construir el futuro | Sin ocultar controles, sin bloqueo por tarea, sin dibujo (§8) |
| P11 Dependencias con criterio | Ninguna dependencia nueva (CA-017-16) |
| P12 Prototipo como referencia | Tablero 16; lo que el prototipo no define se registra en DEV-54 |

## 12. Historias de usuario y criterios

Ver la tabla «Trazabilidad HU → CA» del §3.
