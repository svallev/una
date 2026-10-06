# Spec 016: Tareas con varias imágenes (carrusel)

- **Estado:** **Aprobada** (propietario, 2026-10-06). Revisada ese día por `spec-reviewer`, `a11y-reviewer` y `security-reviewer` (sin hallazgos altos; todo aplicado). Q-016-1 a 3 resueltas por el propietario. Con la aprobación quedan **Aceptados el ADR-0022 y el ADR-0024** y en vigor la **constitución 1.9**. El propietario descartó que la hoja "Añadir a la tarea" avise de que lo nuevo sustituye al grupo. **[Pendiente]** comprobar en el dispositivo si el control por voz expone "Foto siguiente" por su nombre (§6)
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Tercera de las specs 014–019 (después de la 014 y la 015, fusionadas)
- **Reglas de producto:** R17 (varias imágenes con carrusel), R3 (imágenes de la galería), R5 (los adjuntos van arriba del todo), R8 (abrir → tarea actual rápido), **propuesta de valor 2**
- **Pantallas del prototipo:** 9 "Añadir (+)" (fila "Subir imágenes"), 14 "Varias imágenes: preselección" (`FotosSel.dc.html`), 15 "Tarea con varias fotos: carrusel" (`Fotos.dc.html`); 3 "Nueva tarea", 1 "Tarea actual" y 5 "Todas las tareas" (miniatura). El prototipo recorta las fotos altas, no tiene pellizco, admite 30 y no tiene los errores ni el giro: eso se decide aquí (P-17, P-18 y D21) y se registra en `docs/design/prototype-deviations.md` como **DEV-53, al aprobar la spec** (como hicieron la 014 y la 015). Ver `docs/design/screen-map.md`
- **Decisiones y ADR relacionados:**
  - **D21** (propietario, 2026-10-04): varias imágenes solo desde "Subir imágenes" (galería), no con la cámara ni con documentos; **10 como máximo**; en el orden en que las devuelva Android; preselección apilada con la primera arriba; carrusel infinito con swipe, con desplazamiento vertical y pellizco como la imagen única, y gira igual; no se quitan de una en una y unas nuevas **reemplazan** a las anteriores (nunca se suman); si una falla al importarla, se omite y se avisa.
  - **P-8** (10 fotos), **P-17** (el carrusel conserva el desplazamiento vertical y el pellizco y gira igual) y **P-18** (se omite la que falla y se avisa; si fallan todas, el aviso actual) del plan F4b. **S8 descartado**: el orden de las fotos da igual y se usa el que devuelva Android.
  - **R-24** (disco y memoria con varias fotos por tarea).
  - **[ADR-0022](../../docs/adr/0022-interaccion-con-varias-fotos.md)** *Interacción con varias fotos* (enmienda del ADR-0013; la 017 le añade lo de Bloquear zoom) y **[ADR-0024](../../docs/adr/0024-adjuntos-uno-a-n-con-orden.md)** *Adjuntos 1→N con orden* (enmienda del ADR-0002 y del ADR-0012; esquema v3): **Aceptados** por el propietario el 2026-10-06, con la aprobación de la spec, como en la 014 y la 015. Con ellos, **constitución 1.9** (nota en P1 y excepción en P6).
  - ADR-0013 (sin visor, pellizco de vistazo), ADR-0015 (sin "Volver a vertical"), ADR-0019 (Recientes), ADR-0021 (deshacer), ADR-0011 (ningún archivo huérfano). DEV-39 a DEV-43.
  - Modelo de amenazas (`docs/security/threat-model.md`): T-2, T-3, T-7, T-8, T-13, T-15 y el riesgo nuevo de denegación de servicio por un N grande (tope de 10 y tiempos, CA-016-04).
- **Dependencias:** 001 a 009 (el "+" reemplaza cualquier otro adjunto), 011, 013, 014 (card de deshacer) y 015 (Ajustes: pantalla siempre activa y voz). La **017** (Bloquear zoom) depende de esta.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que un horario, un mapa o unos pasos fotografiados en **varias fotos** (hasta 10) queden **a la vista nada más abrir la app**, en una sola tarea: se elige el grupo de una vez y se pasa de una foto a otra con un gesto, sin perder lo que ya daba la imagen única (verla entera al ancho, desplazarla y ampliarla de vistazo).

## 2. Historias de usuario

- **HU-016-1** Como asistente a un festival, quiero subir de una vez las fotos de los tres escenarios y verlas al abrir la app, para no tener tres tareas ni buscar entre ellas.
- **HU-016-2** Como usuario, quiero pasar de una foto a otra con un gesto, y volver a la primera sin tocar nada más, para consultar el grupo con una mano.
- **HU-016-3** Como usuario, quiero que cada foto se vea igual que una imagen suelta (entera, al ancho, con desplazamiento y pellizco), para leer los detalles.
- **HU-016-4** Como usuario con lector de pantalla o con teclado, quiero cambiar de foto sin gestos de deslizamiento, para usar la tarea igual que los demás.
- **HU-016-5** Como usuario, quiero que una foto defectuosa del grupo no estropee las demás, para no tener que repetir la selección.
- **HU-016-6** Como usuario, quiero que ninguna foto del grupo guarde mi ubicación ni otros datos ocultos, como con una imagen sola.

## 3. Criterios de aceptación

**Añadir varias imágenes**

- **CA-016-01 Fila "Subir imágenes" (enmienda CA-007-01)**
  - **Dado** la hoja "Añadir a la tarea" (el editor de una tarea nueva, de la primera tarea, desde "Todo hecho." o al editar una que no es web)
  - **Cuando** se muestra
  - **Entonces**, como en el prototipo (tablero 9), la segunda fila pasa a decir "**Subir imágenes** — Una o varias · van arriba del todo". Las demás filas (Hacer foto, Subir archivo, Cargar URL) no cambian. **Solo esta fila admite varias**: la cámara y el selector de documentos siguen siendo de una en una (D21).
- **CA-016-02 Selector del sistema, sin permisos y con tope de 10 (enmienda CA-007-03)**
  - **Dado** la hoja
  - **Cuando** elige "Subir imágenes"
  - **Entonces** se abre el selector de fotos del sistema con **selección múltiple** (en Android 8–12 sin selector de fotos, el selector de documentos, también múltiple), **sin pedir acceso a la galería**; la app de *release* sigue sin declarar permisos de cámara, de fotos ni de almacenamiento (se comprueba en CI).
  - Se pueden elegir **como máximo 10**. Si el selector del sistema permite limitarlo a 10, no deja pasar de 10. Si devuelve más (p. ej., el selector de documentos, o uno de un fabricante que ignore el límite), se usan las **10 primeras en el orden en que las devolvió Android** y se avisa "Solo se usarán las 10 primeras." (P-8). **El tope se aplica antes de abrir, consultar o copiar ninguna de las elegidas**, aunque lleguen miles o repetidas; un fallo al abrir el selector no cierra la app.
  - El orden del grupo es **el que devuelve Android** (D21; S8 descartado): la primera que llega es la primera del grupo.
- **CA-016-03 Una sola imagen elegida = como la 007**
  - **Dado** que elige **una** sola imagen con "Subir imágenes"
  - **Entonces** todo es como en la spec 007: sin carrusel, sin puntos y sin la etiqueta "1 foto" (editor con la vista previa y "Quitar adjunto", tarea con la imagen suelta). **Una tarea con una imagen y una tarea con un grupo de fotos solo se distinguen por tener una o más fotos.**
- **CA-016-04 Importar el grupo (amplía CA-007-13, 14 y 15)**
  - **Dado** varias imágenes elegidas
  - **Cuando** se importan
  - **Entonces**:
    - **cada imagen** pasa por la misma validación y limpieza que una suelta (CA-007-07, 13 y 14): tipo por contenido, 30 MB, 64 MP, sin metadatos, orientación corregida, sRGB, recodificada a partir de los píxeles y sin guardar el nombre original; ninguna se salta una comprobación por ir en grupo;
    - **antes de tocar cada una** se rechaza si es de la propia app o lleva una autoridad que no es del selector (T-8, como en la 007: esa falla y las demás siguen);
    - se importan **una tras otra** (no a la vez), sin bloquear la interfaz: en cada foto se copia, se limpia y **se borra el original antes de empezar la siguiente** (nunca hay más de un original en disco), y la limpieza nunca corre a la vez para dos fotos;
    - hay un tiempo máximo de **20 s por imagen** (CA-007-14) y, **[Suposición]**, de **2 minutos en total**; pasado el total, la foto en curso se cancela y las que no llegaron se tratan como **fallidas** (CA-016-05: se conservan las ya preparadas y se avisa), no como una cancelación; los tiempos usan un reloj que no avanza con el proceso congelado, y si el proceso estuvo congelado se reinicia el de la foto en curso;
    - la importación **continúa** si la app pasa a segundo plano o se gira el móvil, mientras el proceso siga vivo (si muere, CL-016-7);
    - antes de empezar se comprueba el **espacio libre**: se exige, **[Suposición, se fija al medir, R-24]**, el de un original (30 MB) más 10 veces el tamaño máximo estimado de una foto guardada, **sumando el grupo anterior si se está reemplazando** (los dos conviven hasta guardar); si no hay, se aplica CL-016-6 sin escribir nada; **quedarse sin espacio a mitad de la importación se trata igual**: se descarta todo el grupo, también lo ya preparado;
    - si tarda más de 400 ms, el editor muestra "**Preparando foto {i} de {n}…**" con "Cancelar" (≥ 48 dp), dentro del recuadro de la vista previa y con una barra de progreso fina (DEV-39), y mientras tanto "+" y "Continuar" **no hacen nada y se anuncian como no disponibles** para el lector; el texto de avance se puede leer al enfocarlo pero **no se anuncia solo** (la barra de progreso queda fuera de la lectura);
    - **"Cancelar", pulsado por el usuario, descarta todo el grupo** (también lo ya preparado) y deja el editor como estaba. Cancelar y el vencimiento del total son **un estado del grupo**: tras cualquiera de los dos no se empieza ninguna foto más, en ningún momento (antes de la primera, entre fotos, a mitad de la copia o de la limpieza), y no queda nada en la zona temporal.
- **CA-016-05 Si una falla, se omite y se avisa (P-18)**
  - **Dado** que una o más de las imágenes elegidas fallan (tipo no admitido, demasiado grande o con demasiada resolución, ilegible, tiempo agotado)
  - **Cuando** termina la importación
  - **Entonces**:
    - se **omiten** las que fallan y se usan las demás, **en su orden**;
    - se avisa sobre el editor (se anuncia solo): "No se pudo añadir 1 foto." o "No se pudieron añadir {n} fotos.";
    - **no se rellenan** los huecos con las siguientes elegidas **[Suposición]**;
    - si queda **una**, el editor y la tarea son los de CA-016-03 (con el aviso), y se anuncia "1 foto añadida" (vocabulario del grupo, §7);
    - si **fallan todas**, el editor queda como estaba y se muestra el error de CA-007-13/14 de la **primera** que falló (el aviso actual, P-18);
    - la falta de **espacio libre** no es un fallo de una foto: detiene la importación y se descarta todo (CL-016-6).
- **CA-016-06 Editor con varias fotos (tablero 14)**
  - **Dado** un grupo de 2 a 10 fotos elegido
  - **Cuando** se muestra el editor
  - **Entonces**, como en el prototipo:
    - la vista previa es una **pila de como mucho 3 fotos** a la vista, giradas como en el prototipo (de arriba abajo, -1°, 4° y -5°) y con la **primera arriba**, con la etiqueta "**{n} fotos**" abajo a la izquierda, **sobre un fondo opaco con contraste ≥ 4,5:1** (se sirva la foto que se sirva);
    - el botón "Quitar adjunto" (≥ 48 dp, DEV-36) **quita el grupo entero**: no se quitan fotos de una en una (D21);
    - el campo de texto (opcional), "Continuar", "Guardar" o "Guardar cambios", como en CA-007-04;
    - pulsar (+) con un grupo ya elegido abre la hoja y **lo nuevo reemplaza al grupo entero** (con "Subir imágenes", con "Hacer foto" o con cualquier otro adjunto): **nunca se suman** (D21). El grupo anterior solo se descarta cuando lo nuevo se ha preparado bien; si se cancela o falla todo, se conserva **[Suposición]**.
    - "Quitar adjunto" quita el grupo **del editor**: al editar una tarea, "Cancelar" lo recupera; no se guarda nada hasta "Guardar cambios".
- **CA-016-07 Siempre arriba y editar (amplía CA-007-05 y 06)**
  - **Dado** el editor con un grupo de fotos
  - **Cuando** pulsa "Continuar" (tarea nueva)
  - **Entonces** la tarea se crea como **tarea actual**, sin preguntar la posición, y se vuelve al origen (CA-007-05).
  - **Cuando** edita una tarea y añade, sustituye o quita el grupo y pulsa "Guardar cambios"
  - **Entonces** conserva su **posición y su color** (CA-007-06). Si solo cambia el texto, los archivos no se tocan. "Cancelar" deja la tarea como estaba y descarta lo que se hubiera preparado.

**Ver el grupo**

- **CA-016-08 Visible al abrir (propuesta 2, R8, P2)**
  - **Dado** que la tarea actual tiene un grupo de fotos
  - **Cuando** se abre la app en frío
  - **Entonces** se ve **la primera foto** a todo el ancho, igual que una imagen suelta (CA-007-08), sin ningún toque y en el tiempo de CA-001-09 (< 1 s p50, dispositivo de referencia, *release*).
  - **El arranque no depende de cuántas fotos haya:** el primer fotograma no espera a ninguna otra foto. Se mide con una tarea de 1 foto y con otra de 10: **p50 de 10 fotos ≤ p50 de 1 foto + 100 ms (Suposición, se confirma en el plan), y ambos < 1 s**.
  - **[Resuelto, propietario, 2026-10-06, Q-016-1]** Se abre siempre en la primera. Al volver de segundo plano con el proceso vivo, CA-001-12 manda como siempre: con menos de 10 minutos se ve la misma pantalla y **la misma foto**; con 10 minutos o más, la tarea actual desde su primera foto. Si el sistema mató el proceso, vuelve a la primera (la foto vista no se guarda).
- **CA-016-09 Carrusel infinito con swipe (tablero 15)**
  - **Dado** la tarea actual con 2 a 10 fotos
  - **Cuando** el usuario desliza **horizontalmente con un dedo**
  - **Entonces**:
    - cambia a la foto siguiente o anterior si el gesto pasa del **18 % del ancho** o es un gesto rápido (**[Suposición]** ≥ 700 dp/s), con una transición de **0,28 s** (los dos valores salen del prototipo salvo la velocidad); si no, la foto vuelve a su sitio;
    - es **infinito**: tras la última viene la primera, y antes de la primera, la última (también con 2 fotos);
    - con "reducir movimiento", la foto cambia al instante, sin transición;
    - hay **un punto indicador por foto** (cuadrado, con borde, **lleno la actual** y vacío las demás), decorativo para el lector y **transparente a los toques** (un swipe o un pellizco que empiece sobre ellos funciona), encima del pie de la tarea; no se muestra con una sola foto. **Se distinguen sobre cualquier foto (WCAG 1.4.11, ≥ 3:1 el punto y su estado)**: si el dibujo del prototipo (borde y relleno sin fondo) no lo consigue sobre fotos muy blancas o muy negras, el plan le da un fondo propio y se registra en DEV-53;
    - cambiar de foto por cualquier vía (swipe, acción del lector, teclado o control por voz, CA-016-20) da el mismo resultado visible y el mismo anuncio único; **a la izquierda es la siguiente** (swipe hacia la izquierda, flecha derecha, "desplazar a la izquierda") y a la derecha la anterior.
- **CA-016-10 Cada foto, como la imagen única (P-17; amplía CA-007-09 y 10)**
  - **Dado** la tarea actual con un grupo
  - **Entonces**, en cada foto:
    - ocupa **el 100 % del ancho**, entera, sin perder nada por los lados, y si es más alta que la pantalla se desplaza **solo en vertical** (CA-007-09);
    - el **pellizco** la amplía ahí mismo hasta ×8, sin desplazarse mientras hay dos dedos, y **al soltar vuelve al 100 %** (CA-007-10);
    - tocarla no hace nada;
    - el gesto se reparte por su **dirección**: tras 16 dp de recorrido, si el desplazamiento horizontal es mayor que 1,5 veces el vertical cambia de foto y si no, desplaza (**[Suposición]**, el plan fija los números); el **eje decidido se mantiene hasta que se levantan todos los dedos** (un trazo en diagonal no pasa de desplazar a cambiar de foto); con **dos dedos nunca se cambia de foto** (y si un segundo dedo llega durante un swipe, este se cancela y la foto vuelve a su sitio); **tras un pellizco, el dedo que queda no inicia nada** hasta que no haya ninguno;
    - un swipe que **empieza en la zona de borde que reserva el sistema para el gesto de volver** (Android 10 o posterior, navegación por gestos; se mide con los márgenes de gestos del sistema y también en horizontal) es del sistema: **no cambia de foto**, ni siquiera si el sistema lo cancela; la app no pide exclusión de ese gesto.
  - Cada foto **conserva su desplazamiento mientras la tarea siga a la vista**; una foto que no se ha visto empieza **arriba** y al 100 % (el zoom nunca se conserva). **[Suposición]** Fotos de distinta proporción: cada una se ve a su ancho, con su propia altura (CL-016-5).
- **CA-016-11 Controles y pie (amplía CA-007-08)**
  - **Dado** la tarea actual con un grupo
  - **Entonces** el logotipo, el menú, el botón de completar y el pie de la tarea (recuadro negro con texto blanco) son los de CA-007-08, **encima de las fotos y fijos al cambiar de foto**; los puntos van encima del pie, y **el desplazamiento vertical deja un margen inferior igual al alto del pie más los puntos** para que el final de una foto alta pueda verse (también con el texto al 200 %). Completar con "Mantener pulsado" y el menú funcionan igual con cualquier foto a la vista.
- **CA-016-12 Giro (P-17; amplía CA-007-11)**
  - **Dado** la tarea actual con un grupo a la vista (sin el menú, el editor ni el listado encima)
  - **Cuando** gira el móvil a horizontal
  - **Entonces** gira igual que la imagen única: se ven **solo la foto actual, a todo el ancho y con desplazamiento vertical, y el logotipo** (sin menú, sin botón de completar, sin pie y sin puntos). **El swipe y el pellizco siguen funcionando**, y se mantiene la foto que se veía (el desplazamiento de cada foto sí y el zoom no, **[Suposición]**). **En horizontal siguen también "Foto siguiente", "Foto anterior" y las flechas del teclado**, con el mismo anuncio "Foto {i} de {n}", y el elemento de la tarea se lee "Tarea actual: {texto}. Foto {i} de {n}" (sin pie ni puntos a la vista), **con foco de teclado visible** y las flechas que lo consumen, también aquí (la 007 §6 decía que en horizontal no quedaba nada que enfocar: se enmienda). Respeta el bloqueo de rotación del sistema. Completar y eliminar siguen como acciones del lector (CA-003-07, CA-014-01). Al volver a vertical (o al pasar a una tarea sin adjunto, CA-008-11) se ve la tarea completa.
- **CA-016-13 Pantalla encendida y "Recientes"**
  - **Dado** la tarea actual con un grupo
  - **Entonces** "Pantalla siempre activa" (CA-015-04a) actúa como con una imagen suelta, y la matriz de CA-011-02 incluye, **en cada entorno de verificación**, dos filas nuevas: el editor con la **preselección** y la tarea con el **carrusel** (las fotos no se ven en la tarjeta de "Recientes"; la hoja parcial del selector de CL-011-15 queda como está). Se añaden a esa matriz el carrusel **en horizontal**, la tarea con "Foto no disponible" y la preparación en curso; `tools/check-recents.sh` gana el escenario "grupo de 3 fotos distinguibles" con archivos de prueba solo de depuración, y se pasa antes de cada entrega a testers.

**Guardar, borrar y recuperar**

- **CA-016-14 Copia propia, sin datos ocultos y con orden**
  - **Dado** un grupo importado
  - **Cuando** se guarda
  - **Entonces**:
    - cada foto cumple CA-007-07 por separado (copia propia recodificada, sin metadatos de ningún tipo, orientación corregida, sRGB, sin nombre original, versión completa de hasta 24 MP sin límite de lado, la app no escribe en la galería);
    - se guarda **su orden** y vuelve a verse en ese orden tras cerrar y abrir la app, incluso en modo avión (CA-001-10);
    - si se borran los originales de la galería, la tarea sigue mostrando todas;
    - **regla de decisión (R-24, ADR-0024):** la versión completa conserva hasta 24 MP, como la imagen suelta. Si al medir con 10 fotos de 24 MP el espacio supera **150 MB por tarea [Suposición]** o no se cumple CA-016-08 o CA-016-23, el ADR-0024 puede fijar para los grupos un tope menor, **no inferior a 12 MP**; eso no reabre esta spec.
- **CA-016-15 Lo que ya existe no cambia**
  - **Dado** una instalación con tareas de imagen, PDF, web o solo texto
  - **Cuando** se actualiza a la versión con esta spec
  - **Entonces** **ninguna tarea cambia** (texto, orden, color, adjunto), la app abre y sigue funcionando; una imagen existente se ve y se comporta como antes (CA-016-03). Se comprueba con un test de migración (P9).
- **CA-016-16 Ningún archivo huérfano, con el grupo entero (amplía CA-007-16 y CA-014-15)**
  - **Dado** cualquier camino que deje fotos sin uso: eliminar la tarea (cuando es definitiva, CA-014-15), completarla (ADR-0012), quitar o sustituir el grupo al editar, "Quitar adjunto" en "Adjunto no disponible", cancelar el editor o la importación (también a medias), error o falta de espacio al importar, fallo al guardar, o la app muere con el selector abierto o importando
  - **Cuando** termina la operación
  - **Entonces** **no queda ningún archivo de ninguna foto del grupo** (versiones completa, de pantalla y miniatura) **ni ningún temporal**. **Todos los caminos usan el mismo borrado** (CA-007-16).
  - **Todas las fotos del grupo están protegidas del barrido como una unidad**: desde que se prepara la primera hasta que se guarda o se descarta (**también mientras el editor espera abierto**) y durante el deshacer (CA-014-15); un barrido durante la importación o con un grupo en deshacer no borra ninguna.
  - **Deshacer** (spec 014) devuelve la tarea con **todo el grupo y en su orden**, en la primera foto.
  - El barrido tras el primer fotograma (sin retrasar CA-001-09) quita las fotos que no pertenecen a ninguna tarea; una importación en curso nunca se barre.
- **CA-016-17 Copia de seguridad (sin cambio, ADR-0004)**
  - **Dado** tareas con fotos
  - **Cuando** Android hace la copia de seguridad en la nube
  - **Entonces** las imágenes siguen **fuera** de la copia en la nube y, en Android 12 o posterior, van en la transferencia directa entre dispositivos (CA-007-18). Tras una restauración sin fotos se aplica CA-016-18.
- **CA-016-18a Falta una foto del grupo, no todas (amplía CA-007-19) [Resuelto, propietario, 2026-10-06, Q-016-2]**
  - **Dado** que falta, está vacío o está corrupto el archivo de **una o varias** fotos del grupo, pero no de todas
  - **Cuando** se muestra la tarea
  - **Entonces** no se cierra ni se bloquea y **en el sitio de esa foto** se ve el recuadro "**Foto no disponible**" (diseño propio, sin acción: recuadro blanco con borde y sombra, aviso en rojo con el icono de imagen; DEV-53), mientras las demás se ven con normalidad; el recorrido, los puntos y la lectura incluyen a todas.
  - **En el editor** de esa tarea, la pila muestra las que se ven y el recuadro en las que faltan; "Quitar adjunto" quita **todo** el grupo (no se quita solo la rota, D21); para reponer, se elige un grupo nuevo con (+), que lo reemplaza.
  - Si solo falta la miniatura o la versión de pantalla de una foto, se regenera en segundo plano sin avisar (CA-007-19).
- **CA-016-18b Faltan todas las fotos (amplía CA-007-19)**
  - **Dado** que faltan, están vacías o corruptas todas las fotos del grupo
  - **Cuando** se muestra la tarea
  - **Entonces** se ve la tarjeta "Adjunto no disponible" de CA-007-19, con su acción única ("Quitar adjunto" o "Eliminar tarea"); quitarlo quita todo el grupo.
- **CA-016-23 Memoria y disco con 10 fotos (R-24, P2, P5)**
  - **Dado** una tarea con 10 fotos de 24 MP
  - **Cuando** se recorren todas varias veces, en vertical y en horizontal, con pellizco y desplazamiento
  - **Entonces** la app **no se cierra** y el pico de memoria no supera en más de **50 MB [Suposición, se confirma al medir]** al de una tarea con una sola foto; cambiar de foto no deja ver un hueco más de **200 ms** (p90). El espacio que ocupa se mide y se registra (CA-016-14). Regenerar miniaturas o versiones de pantalla que falten se hace **de una en una**, solo para la foto a la vista y las contiguas, y un fallo de decodificación nunca cierra la app.

- **CA-016-24 Seguridad de la importación en grupo y sin sorpresas (P5, T-3, T-7, T-8, T-13)**
  - **Dado** la importación de un grupo
  - **Entonces**:
    - **orden por foto:** tope de 10 en el origen → rechazo de origen propio (T-8) → copia acotada a 30 MB contada al copiar → tipo por contenido → dimensiones ≤ 64 MP por la cabecera → recodificación → borrado del original (CA-007-13 y 14);
    - **no se pide el nombre del archivo** de ninguna foto y `originalName` queda vacío en todas;
    - **sin dependencias nuevas** (`pubspec.lock` sin cambios), **sin permisos** (solo `INTERNET`, comprobado en CI), sin red nueva, sin componentes exportados ni consultas de paquetes nuevas; el único cambio de datos es el esquema v3; el selector múltiple sigue siendo el propio de la app, no un paquete;
    - pruebas: un grupo con una foto propia de la app o con autoridad ajena entre las válidas (esa falla, las demás siguen); un selector que devuelve 5000 elementos (solo se tocan 10); cancelación en cada paso; fallo inyectado al guardar en la foto 1, la 5 y la 10 (CA-016-16); y los errores agregados sin texto de excepción (CL-016-16).
- **CA-016-25 Datos restaurados o raros se leen sin fallar (T-7; análogo a CA-015-26)**
  - **Dado** una base de datos restaurada o con filas de adjuntos inesperadas (posiciones repetidas o con huecos, más de 10 filas, tipo desconocido, PDF o web mezclados con imágenes)
  - **Cuando** se lee la tarea
  - **Entonces** no se cierra ni se cuelga ni carga sin tope: se ordenan por posición (y por identificador si empatan), **se leen como mucho 10**, y una tarea con un tipo desconocido o una mezcla no válida se ve como "Adjunto no disponible" (CA-016-18b). Editar una tarea con grupo **no pierde fotos** y el tope de lectura no borra las que sobran sin que el usuario guarde. La migración deja a cada tarea con posiciones únicas (también si una tarea de la v2 tuviera más de una fila).

**Donde aparece el grupo**

- **CA-016-19 Listado, card de deshacer, completar y eliminar (amplía CA-007-20)**
  - **Dado** una tarea con un grupo
  - **Cuando** aparece fuera de la pantalla principal
  - **Entonces**:
    - **listado:** la miniatura de 44 px es la de **la primera foto**, **sin contador ni número** (propietario, 2026-10-06; como en el prototipo); el número de fotos lo dice la fila al lector (CA-016-20);
    - **sin texto:** en el listado, en la card de deshacer (CA-014-04) y en los anuncios se usa "**{n} fotos**" (una sola, "Foto" o "Imagen", como la 007);
    - **completar y eliminar:** la rotura y el arrugado muestran **la foto que se ve** en ese momento, recortada como la tarea (la captura vive **solo en memoria**, nunca en disco ni en la caché); con reducir movimiento, sus alternativas.
  - Con 500 tareas de 10 fotos cada una, el listado cumple CA-006-20 (no es más lento que con imágenes sueltas).

**Accesibilidad**

- **CA-016-20 Lectura**
  - **Dado** un lector de pantalla
  - **Cuando** lee una tarea con un grupo
  - **Entonces** las fotos y el pie son **un único elemento**:
    - pantalla principal: "Tarea actual: {texto}. {n} fotos. **Foto {i} de {n}**" (o "Tarea actual: {n} fotos. Foto {i} de {n}" sin texto);
    - **acciones**, en este orden: **Foto siguiente**, **Foto anterior**, Completar tarea, Eliminar tarea, más las de desplazamiento de CA-007 (solo las que se pueden hacer); **además, las acciones estándar de desplazamiento horizontal** (a la izquierda = siguiente, a la derecha = anterior) para que sirvan el control por voz y el desplazamiento del lector y de Switch Access sin abrir el menú de acciones; con una sola foto no existe ninguna de ellas;
    - al cambiar de foto **por cualquier vía** (acción, desplazamiento, tecla, swipe real o paso de gestos del lector) se hace **un único anuncio** "Foto {i} de {n}", sin eco ni silencio, y si hay varios cambios seguidos el último sustituye a los anteriores; el foco se queda en el mismo elemento, que **no se recrea** al cambiar de foto, y su etiqueta queda siempre al día ("Foto 2 de 5") por si se vuelve a leer; el mecanismo del anuncio lo fija el plan (se evaluará una región viva en un nodo propio con el idioma de la app, R-22) y se verifica en el dispositivo con 5 cambios seguidos por acción y por gesto;
    - **con teclado**, el elemento de la tarea es un punto de foco (con anillo visible, también en horizontal) y **recibe el foco al abrir**; las flechas izquierda y derecha las consume ese elemento y cambian de foto (y Av Pág y Re Pág siguen desplazando en vertical); con Switch Access y con control por voz se usan las acciones;
    - los puntos no se leen (decorativos); las fotos no llevan papel de imagen cuando ya se dice "fotos" (CA-007-21: nunca se dice "imagen" dos veces);
    - fila del listado (CA-006-18): "{posición} de {total}: {texto}. {n} fotos" (o "{posición} de {total}: {n} fotos" sin texto); la primera, "1 de {total}. Tarea actual: …", con la pista de siempre;
    - **la pila del editor** se lee "Vista previa: {n} fotos" (clave `a11yPhotoStack`);
    - con una foto que falta (CA-016-18): "Foto {i} de {n}. Foto no disponible".
  - **También en horizontal** (CA-016-12). **Se sustituye el texto del prototipo** "Foto i de N. Desliza para ver más" por el de arriba: con un lector, "deslizar" mueve el foco, no el carrusel (DEV-53).
- **CA-016-21 Foco y anuncios (amplía CA-007-22)**
  - **Dado** un lector de pantalla activo
  - **Entonces** se hace **un único anuncio** y el foco queda donde dice la tabla:

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Vuelve del selector con un grupo (también si queda una) | La vista previa (la pila) | "{n} fotos añadidas" (o "1 foto añadida") |
    | Con avisos (más de 10, fotos omitidas) | La vista previa | **Un solo anuncio** que une, en este orden, lo que haya: "Solo se usarán las 10 primeras." · "{n} fotos añadidas." · "No se pudo añadir 1 foto." Los avisos visibles son **uno solo con ese mismo texto** y no se anuncian además por su cuenta (sin eco); si el anuncio y la lectura de la pila ("Vista previa: …") compiten, manda el anuncio (se comprueba en el dispositivo; limitación de TalkBack como la de abajo) |
    | Todas fallan, sin espacio, cancela "Preparando" o cancela el selector | Como CA-007-22 (el botón (+)) | Como CA-007-22 (el error, o ninguno) |
    | "Preparando foto {i} de {n}…" | "Cancelar" | "Preparando foto {i} de {n}…" (una vez al empezar; no en cada foto) |
    | Quitar adjunto | El botón (+) | "Adjunto quitado" |
    | Foto siguiente o anterior, por cualquier vía (CA-016-20) | El mismo elemento | "Foto {i} de {n}" |

  - Los avisos de más de 10 y de fotos omitidas **no caducan solos** (WCAG 2.2.1); se quitan al cambiar o quitar el grupo, al guardar o al salir del editor, y al 200 % de texto se ven enteros. **[Suposición]**
  - **Limitación de TalkBack ya aceptada** (CA-007-22, propietario, 2026-09-27): al volver del selector el foco puede caer en el primer elemento del editor, no en la vista previa.
- **CA-016-22 Reducir movimiento, texto grande y contraste**
  - **Dado** "reducir movimiento" o el texto al 200 % en un móvil de 360 dp
  - **Entonces**:
    - sin animación al cambiar de foto, al soltar el pellizco ni en la pila del editor (las giradas se ven fijas), y la barra de progreso de "Preparando foto {i} de {n}…" no se anima (DEV-39);
    - la etiqueta "{n} fotos", el pie (hasta 3 líneas, con los puntos encima sin tapar el texto), los avisos y "Foto no disponible" se ven **enteros**; nada se corta; **todo lo que no es la nota escala hasta ×2,0 sin límite** (el límite de ×1,6 es solo del pie); todos los botones miden ≥ 48 dp;
    - la foto actual **no se distingue solo por el color**: los puntos cambian de **relleno** (lleno / vacío), con borde de 2 px, y el anillo de foco del teclado lleva borde blanco y negro para verse sobre cualquier foto (CA-007, §6).

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-016-1 | Elige una sola imagen con "Subir imágenes" | Como la 007 (CA-016-03) |
| CL-016-2 | Elige más de 10 (selector de documentos de Android 8–12) | Se usan las 10 primeras, en el orden de Android, y se avisa (CA-016-02) |
| CL-016-3 | La misma foto elegida dos veces | Se añade cada una que devuelve el selector; la app no busca duplicados |
| CL-016-4 | Grupo de 2 fotos | El carrusel infinito sigue funcionando: la siguiente y la anterior son la otra (CA-016-09) |
| CL-016-5 | Fotos de proporciones muy distintas (una captura de 1080 × 20 000 y una panorámica) | Cada una a todo el ancho y con su altura; al cambiar de foto, la nueva empieza arriba (CA-016-10) |
| CL-016-6 | Sin espacio libre **al importar** el grupo | `storageErrorNoSpace`; se detiene y **se descarta todo el grupo**, sin temporales |
| CL-016-6b | Sin espacio libre o fallo **al guardar** la tarea | `storageErrorNoSpace` o `editorSaveError` con "Reintentar" (como CL-007-3): no se crea la tarea, el editor **conserva el grupo preparado** y no quedan temporales si se cancela |
| CL-016-7 | Android mata la app con el selector abierto o importando | Al volver, el editor sin imágenes (o la tarea actual si pasaron 10 min, CA-001-12); no queda ningún temporal (CA-016-16) |
| CL-016-8 | Doble toque rápido en "Continuar" con un grupo | Se crea **una sola** tarea (CL-007-8) |
| CL-016-9 | Cancelar mientras se prepara la imagen 4 de 10 | Se descarta todo el grupo; el editor queda como estaba (CA-016-04) |
| CL-016-10 | El segundo dedo llega durante un swipe | El swipe se cancela, la foto vuelve a su sitio y empieza el pellizco |
| CL-016-11 | Se gira el móvil mientras se ve la foto 3 | La foto 3 sigue a la vista, en horizontal (CA-016-12) |
| CL-016-12 | Se completa o se elimina viendo la foto 3 | La rotura o el arrugado muestran la foto 3; **deshacer** devuelve la tarea en la foto 1 (CA-016-16) |
| CL-016-13 | Se edita solo el texto de una tarea con grupo | No se reimporta ni se toca ningún archivo (CA-016-07) |
| CL-016-14 | Una foto del grupo es una imagen con transparencia | Se ve sobre blanco (CL-007-4) |
| CL-016-15 | Web de pruebas (ADR-0010) | "Subir imágenes" usa el selector múltiple del navegador con las mismas reglas que el móvil: tope de 10 antes de leer ningún archivo, tipo por contenido, 30 MB, 64 MP y de una en una liberando lo anterior; las fotos viven solo en memoria, como las tareas |
| CL-016-16 | Registros (logs) en *release* | No se registra ninguna dirección, nombre, ruta, número ni metadato de las fotos; los errores de varias fotos se guardan solo como un código (ilegible, grande, tipo, espacio, tiempo), nunca como texto de excepción, y un test lo comprueba |
| CL-016-17 | Imagen de Google Fotos solo en la nube y sin conexión, dentro de un grupo | Se trata como una que falla (CA-016-05): se omite y se avisa |
| CL-016-18 | Texto grande (200 %) con la etiqueta "{n} fotos" y el aviso de fotos omitidas | Todo se ve entero; la pila y los avisos crecen en alto (CA-016-22) |
| CL-016-20 | La app pasa a segundo plano o se gira el móvil durante "Preparando" | La importación continúa (CA-016-04); al volver se ve el avance |
| CL-016-21 | Se cambia el idioma (Ajustes) con la preselección o el carrusel visibles | Los textos pasan al idioma nuevo; la foto y el grupo se mantienen |
| CL-016-22 | Gira el móvil con la card de deshacer y un grupo | Como CL-014-7: además de la foto y el logotipo se ve la card |
| CL-016-19 | Archivos de prueba malformados dentro de un grupo (cabecera truncada, dimensiones falsas, bomba de descompresión, GIF de miles de fotogramas, HEIC corrupto, flujo sin fin) | Con los archivos de prueba, la app **nunca se cierra**; la foto se trata como una que falla y no se escribe nada fuera de la zona temporal (CA-007-14). Un fallo nativo del decodificador que no se pueda capturar perdería el grupo (CL-016-7) |

## 5. Estados vacíos y de error

Los errores y avisos de la importación aparecen sobre el editor (se anuncian solos), el editor conserva lo elegido o queda como estaba (según el caso) y el foco vuelve a (+).

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Más de 10 elegidas | El selector devuelve más de 10 | Aviso "Solo se usarán las 10 primeras." y el editor con las 10 |
| Algunas no se pudieron añadir | Una o más fallan y otras no | Aviso "No se pudo añadir 1 foto." / "No se pudieron añadir {n} fotos." y el editor con las demás |
| Todas fallan | Ninguna se puede importar | El error de CA-007-13/14 de la primera que falló; el editor como estaba |
| Sin espacio | Falta espacio al importar o al guardar | `storageErrorNoSpace`; se descarta todo el grupo (CL-016-6) |
| Una foto no disponible | Falta o está corrupto un archivo (CA-016-18) | "Foto no disponible" en su sitio del carrusel |
| Todo el adjunto no disponible | Faltan todas las fotos | Tarjeta "Adjunto no disponible" (CA-007-19) |
| Cancelada la preparación | "Cancelar" mientras se importa | El editor como estaba; ningún archivo nuevo |

## 6. Accesibilidad

- **Cambiar de foto sin gestos de deslizamiento (P6, WCAG 2.1.1):** acciones "Foto siguiente" y "Foto anterior" en el elemento de la tarea (lector y Switch Access) y flechas izquierda y derecha con teclado (CA-016-20), **también en horizontal** (CA-016-12). Foto actual: "Foto {i} de {n}" tras cada cambio (CA-016-21). Los puntos son decorativos. **Control por voz:** las acciones estándar de desplazamiento horizontal sirven a quien usa solo la voz (**[Pendiente de comprobar en el dispositivo]** si el control por voz expone también "Foto siguiente").
- **Gestos de dos dedos y de trayecto:** el pellizco mantiene la excepción del ADR-0013 (sin alternativa en la app; la lupa del sistema) y el desplazamiento vertical mantiene sus acciones de desplazamiento (CA-007, §6). **El swipe horizontal es un gesto de trayecto y de arrastre (WCAG 2.5.1 y 2.5.7):** tiene alternativa para lector, teclado, switch y control por voz, pero **no hay botones visibles de un solo toque** (el prototipo no los tiene). **[Resuelto, Q-016-3, propietario, 2026-10-06]** se acepta como excepción, sin alternativa visible: **constitución 1.9** con una entrada nueva en las excepciones de P6 (como las de los ADR-0013 a 0023), y el ADR-0013 se amplía de "imagen" a "grupo de imágenes" (pellizco y horizontal).
- **Orientación (WCAG 1.3.4):** el grupo gira como la imagen única (excepción del ADR-0013, sin menú, botón de completar, pie ni puntos); completar y eliminar siguen como acciones del lector.
- **Contraste y movimiento:** el estado de los puntos no depende solo del color (CA-016-22); con reducir movimiento no hay transición; el pie y el logotipo, como en la 007.
- **Texto grande:** nada se corta al 200 % en 360 dp (CA-016-22, CL-016-18). Objetivos táctiles ≥ 48 dp en "Quitar adjunto", "Cancelar" y "Reintentar".
- **Voz del sistema (ADR-0020 y ADR-0023):** los anuncios nuevos entran en la excepción ya aprobada, sin ampliarla; todo lo que se recorre lleva el idioma de la app (se comprueba con un test, como CA-015-11).

## 7. Textos (ES / EN)

Claves en camelCase. Las de la 007 que cambian se marcan; las demás se reutilizan (`storageErrorNoSpace`, `retry`, `editorCancel`, `deleteA11yAction`, `imagePreparingCancel`, `errImage*`, `attachmentMissing`, `a11yAttachmentRemoved`, `a11yImageAdded`). Plurales con ICU (`one` y `other`). **Vocabulario (propietario, tablero 14 y 15):** en el grupo, todo es "foto" (también las de la galería); "imagen" queda para la suelta de la 007. Los textos nuevos no mezclan los dos en una frase.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `attachPickImage` / `attachPickImageHint` | Subir imágenes / Una o varias · van arriba del todo | Upload images / One or more · go on top | **Cambian** (antes "Subir imagen" / "Desde tu galería · va arriba del todo", CA-007-01) |
| `imagePreparingOf` | Preparando foto {current} de {total}… | Preparing photo {current} of {total}… | Con una sola foto sigue `imagePreparing` (DEV-39) |
| `photoCount` | {count, plural, one{# foto} other{# fotos}} | {count, plural, one{# photo} other{# photos}} | Etiqueta de la pila (CA-016-06) y tarea sin texto (listado, card de deshacer, anuncios); con una sola foto, `attachmentPhoto`/`attachmentImage` |
| `a11yWithPhotos` | {text}. {count, plural, one{# foto} other{# fotos}} | {text}. {count, plural, one{# photo} other{# photos}} | Lectura con texto (CA-016-20) |
| `a11yPhotoStack` | Vista previa: {count, plural, one{# foto} other{# fotos}} | Preview: {count, plural, one{# photo} other{# photos}} | Pila del editor |
| `a11yPhotoOf` | Foto {index} de {total} | Photo {index} of {total} | Tras cambiar de foto y en la lectura de la tarea |
| `a11yPhotoNext` | Foto siguiente | Next photo | Acción del lector |
| `a11yPhotoPrevious` | Foto anterior | Previous photo | Acción del lector |
| `a11yPhotosAdded` | {count, plural, one{# foto añadida} other{# fotos añadidas}} | {count, plural, one{# photo added} other{# photos added}} | Anuncio al volver del selector (CA-016-21) |
| `imagesLimitNotice` | Solo se usarán las {max} primeras. | Only the first {max} will be used. | Aviso (CA-016-02) |
| `imagesSomeFailed` | {count, plural, one{No se pudo añadir # foto.} other{No se pudieron añadir # fotos.}} | {count, plural, one{# photo couldn't be added.} other{# photos couldn't be added.}} | Aviso (CA-016-05); el anuncio compuesto de CA-016-21 une `imagesLimitNotice`, `a11yPhotosAdded` e `imagesSomeFailed` con un espacio, sin clave propia |
| `photoMissing` | Foto no disponible | Photo unavailable | Recuadro en el sitio de la foto (CA-016-18) |
| `a11yPhotoMissing` | Foto {index} de {total}. Foto no disponible | Photo {index} of {total}. Photo unavailable | Lectura de la foto que falta |

El texto de `a11yPhotoOf` sustituye al del prototipo ("Foto i de N. Desliza para ver más"). Los textos nuevos pasan por `/strings-add` y se registran en `docs/glossary.md` (la fila "Foto" se amplía: en el grupo, "foto" también vale para las de la galería).

## 8. Fuera de alcance

- Quitar, reordenar o añadir fotos **de una en una**; sumar fotos a un grupo (siempre se reemplaza, D21).
- Varias fotos con la cámara o con documentos; más de 10; **un grupo en el PDF o la web**.
- **Bloquear zoom** (spec 017): su ajuste y su efecto sobre el pellizco, el desplazamiento y el swipe.
- Visor a pantalla completa, edición o recorte de las fotos, descripción escrita por el usuario (P-5, v1.1).
- Recuerdo de la última foto vista cuando el sistema mata el proceso o pasan 10 minutos o más.
- Copia de las imágenes en la nube (tarea propia antes de la v1.0).
- Notificaciones (spec 019) y cualquier otro cambio de Ajustes.

## 9. Preguntas abiertas

Marcadas con **[Pendiente]** y con quién decide. Cada una lleva mi recomendación (la spec se escribe con ella como **[Suposición]**).

- **[Resuelto 2026-10-06, propietario, Q-016-1] ¿En qué foto se abre?** Aceptada la recomendación: **siempre en la primera** al abrir en frío y tras 10 minutos o más; con menos de 10 minutos en segundo plano, **la misma foto** (CA-001-12). Alternativa: recordar la última vista hasta que se complete la tarea.
- **[Resuelto 2026-10-06, propietario, Q-016-2] ¿Qué se ve si falta una foto del grupo?** Aceptada la recomendación: el recuadro "Foto no disponible" **en su sitio** y las demás se ven (CA-016-18). Alternativa: omitir la que falta sin avisar, o la tarjeta "Adjunto no disponible" entera.
- **[Resuelto 2026-10-06, propietario, Q-016-3] ¿Alternativa visible al swipe (WCAG 2.5.1)?** Opción (a), con las palabras del propietario: «dejamos los botones pequeños del prototipo. Son un buen indicador visual de cuántas fotos hay y de que has vuelto al principio»; los puntos se quedan **solo como indicador** y no se añaden botones ni zonas táctiles. Recomendación: **sin botones visibles** (como el prototipo), con acciones del lector, del switch y flechas del teclado, y la excepción registrada en el **ADR-0022** y en la nota de P6 de la **constitución 1.9** (junto a la del pellizco, ADR-0013, que se amplía a "grupo de imágenes"). Alternativa: zonas táctiles o botones pequeños de "anterior" y "siguiente", que añaden un DEV al prototipo.
- **[Pendiente, plan y ADR-0024] Tamaño de cada foto con varias (R-24).** La versión completa con 24 MP puede dar 100–300 MB con 10 fotos grandes. Por defecto, sin cambios; se mide en la implementación y, si hace falta, se propone una versión completa menor cuando hay varias.
- **[Resuelto 2026-10-06, propietario] Nota aclaratoria bajo P1** de la constitución (va en la 1.9): «una tarea puede tener un grupo de fotos; sigue siendo una tarea a la vez». P1 no lo prohíbe; `docs/PLAN.md` §1 y `CLAUDE.md` ya lo dicen. **La constitución 1.9 hace falta de todas formas si se acepta la Q-016-3 recomendada** (excepción de P6); la nota de P1 iría en la misma versión.
- **[Suposición, a validar en la beta]** El 18 % del ancho (unos 65 dp) y los 700 dp/s pueden ser difíciles con poco rango de movimiento; se prueban con alguien con movilidad reducida. Los puntos pueden parecer controles: si en la beta alguien los toca esperando un efecto, se revisa (ADR-0022).
- **[Resuelto 2026-10-06, propietario] Sin contador de fotos** en la miniatura del listado (CA-016-19): la miniatura sola, como en el prototipo.
- **[Resuelto 2026-10-06, propietario] Reglas numéricas** (velocidad del gesto, reparto de la dirección, 2 minutos en total, memoria, espacio): se aceptan como suposiciones y se confirman en el plan.
- **[Suposición] Tiempo total de importación de 2 minutos** (CA-016-04) y **el total que cabe en el disco**: se confirman en el plan con las mediciones.

## 10. Enmiendas a otras specs (se implementan con esta)

- **007:** CA-007-01 (fila "Subir imágenes"), 03 (selección múltiple), 04 y 06 (vista previa y quitar con varias), 05 (siempre arriba), 07, 13 y 14 (cada foto, por la misma validación y limpieza), 08 a 11 (el carrusel conserva al ancho, desplazamiento, pellizco y giro; **el texto vigente del giro es CA-008-11**), 12 (pantalla activa), 15 (preparando "i de n"), 16 y 17 (el grupo entero, y completar lo borra), 19 (foto que falta), 20 y 21 (miniatura, "{n} fotos" y lectura), 22 (foco y anuncios), los CL-007-3, 7 y 8 repetidos en CL-016, §8 ("varias imágenes por tarea", fuera de alcance) y §9 ("un solo adjunto por tarea": ahora, **una imagen, un grupo de imágenes**, un PDF o una web). DEV-41 y DEV-43 (valen para cada foto del grupo).
- **008:** CA-008-11 (horizontal de imagen y PDF: el grupo gira igual, con las acciones de foto). **009:** sin cambios (la tarea web no lleva grupo).
- **001:** CA-001-09 (el primer fotograma no espera a ninguna otra foto).
- **003 y 004:** CA-003-07, CL-003-4 y CL-003-8 (la rotura y el anuncio "Siguiente: {n} fotos"), y el arrugado de la 004 con la foto que se ve.
- **005 y 002:** el editor con la pila y el "+" que reemplaza (CA-005-07, CL-005-3, CA-002-09).
- **006:** CA-006-02 y CA-006-18 (miniatura de la primera, sin contador; lectura "{n} fotos", también en la primera fila).
- **011:** CA-011-02 (dos filas nuevas en la matriz: preselección y carrusel).
- **014:** CA-014-04 (etiqueta de la card sin texto), CA-014-09 (se recupera todo el grupo), CA-014-15 (archivos de todo el grupo) y CA-014-16/18 (lectura al deshacer con un grupo).
- **015:** sin cambios (se usan CA-015-04a y CA-015-11).
- **007 §6** ("con teclado sin lector no queda nada que enfocar en horizontal"): con un grupo sí hay un punto de foco (CA-016-12).
- **`docs/security/threat-model.md` y `docs/security/checklist.md`** (al implementar): T-3 (N archivos, tope antes de copiar, un original a la vez, tiempos por foto y total), T-7 (residuales de las fotos retenidas en el deshacer y del original en la zona temporal, ahora N; contenido de la transferencia entre dispositivos hasta 10 fotos por tarea; BD restaurada con filas no fiables), T-2 (errores agregados sin texto), el riesgo nuevo de denegación de servicio por N y una nota en "Si toca la importación".
- **`docs/architecture.md` §3:** el ER (0..N), las invariantes, el versionado v3 y "Imágenes" (CA-016-14, 24, 25).
- **ADR-0002, ADR-0012 y ADR-0013:** enmendados por el ADR-0024 y el ADR-0022 (no se sustituyen). **Constitución 1.9** (nota en P1 y excepción en P6).
- **DEV-53** (se registra al aprobar la spec): fotos que se ven enteras y con pellizco (frente al recorte del prototipo), "Foto no disponible", "Preparando foto {i} de {n}…" y la lectura sin "Desliza para ver más"; y notas en DEV-39, DEV-41 y DEV-43.

## 11. Trazabilidad con la constitución

| Principio | Cómo se cumple |
|---|---|
| P1 Una tarea a la vez | Un grupo de fotos es **una** tarea; la pantalla principal sigue mostrando solo la actual (CA-016-08 a 11). Nota aclaratoria opcional (§9) |
| P2 Instantáneo al abrir | El arranque no depende de N (CA-016-08, R-24) |
| P3 Local y sin conexión | Todo se copia dentro de la app; sin red (CA-016-14, 17) |
| P4 Privacidad por defecto | Sin red ni permisos nuevos; sin metadatos (CA-016-02, 14, CL-016-16) |
| P5 Seguridad desde el diseño | Cada foto, por la misma validación; DoS por N acotado: tope de 10 y tiempos (CA-016-04, CL-016-19) |
| P6 Accesible siempre | Acciones, teclado y anuncios; excepción del swipe (ADR-0022, constitución 1.9; CA-016-20 a 22, §6) |
| P7 i18n | Tabla del §7 en ES y EN, con plurales |
| P9 Tests | Cada CA tiene su test; migración (CA-016-15, 25) y arranque con 1 y 10 fotos (CA-016-08); **accesibilidad automática:** `androidTapTargetGuideline`, `iOSTapTargetGuideline` y `labeledTapTargetGuideline` en el editor con grupo, en "Preparando" y en "Foto no disponible"; semántica del nodo del carrusel (acciones, orden, etiqueta que cambia, nodo estable); `disableAnimations`; los dos idiomas y los plurales; el test de voz de CA-015-11 con las claves nuevas; textos al 200 % con las fuentes reales (`loadAppFonts`) |
| P10 Crecer sin construir el futuro | Sin reordenar, sin quitar de una en una, sin grupos en PDF o web (§8) |
| P12 Prototipo como referencia | Tableros 9, 14 y 15; las desviaciones, en DEV-53 |

## 12. Historias de usuario y criterios

| Historia | Criterios |
|---|---|
| HU-016-1 | CA-016-01 a 07 |
| HU-016-2 | CA-016-08 (abre en la primera), 09 y 11 |
| HU-016-3 | CA-016-10 y 12 |
| HU-016-4 | CA-016-20 y 21 (y CA-016-12 en horizontal) |
| HU-016-5 | CA-016-05, 18a y 18b |
| HU-016-6 | CA-016-04 y 14 |
