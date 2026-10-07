# ADR-0022: Interacción con varias fotos: swipe para cambiar, desplazamiento vertical y pellizco como la imagen única, y puntos solo informativos

- **Estado:** Aceptado (propietario, 2026-10-06, con la spec 016). Incluye una **excepción a P6** (constitución 1.9). **Enmendado por la spec 017** (Bloquear zoom, propietario, 2026-10-07; ver «Enmienda 1» al final): la excepción a P6 no cambia de alcance
- **Fecha:** 2026-10-06
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 016 (CA-016-09 a 12, 20 a 22; Q-016-3), D21, P-17 del plan F4b; **enmienda** al ADR-0013 (sin visor, pellizco de vistazo y horizontal) y al ADR-0015; constitución P6; DEV-41, DEV-42, DEV-43 y DEV-53; spec 017 (Bloquear zoom, enmienda 1)

## Contexto

- **[Hecho]** El prototipo (tablero 15) muestra el carrusel con swipe horizontal, **foto recortada** (`overflow: hidden`, sin desplazamiento vertical ni pellizco) y **puntos** indicadores decorativos (`aria-hidden`, sin interacción, como mucho 12).
- **[Hecho]** El propietario decidió (D21, P-17, 2026-10-04): el carrusel conserva el desplazamiento vertical y el pellizco como la imagen única (ADR-0013, DEV-41 y DEV-43) y gira igual (DEV-42).
- **[Hecho]** El swipe horizontal con un dedo es un **gesto de trayecto y de arrastre**: WCAG 2.5.1 (nivel A) pide poder hacer lo mismo con un solo puntero sin trayecto y WCAG 2.5.7 (AA), una alternativa al arrastre. P6 pide además una alternativa para lector, teclado y switch para toda acción por gesto.
- **[Hecho]** El propietario, al decidir la Q-016-3 (2026-10-06), prefiere **mantener los puntos del prototipo** como indicador visual («un buen indicador visual de cuántas fotos hay y de que has vuelto al principio») y **no añadir botones ni zonas táctiles** para cambiar de foto.
- **[Hecho]** Ya hay una excepción parecida: el pellizco de la imagen única no tiene alternativa en la app (ADR-0013; lupa del sistema).
- **[Suposición]** Los puntos no se vuelven interactivos ni se les añaden botones de "anterior" y "siguiente"; la lupa del sistema no ayuda a cambiar de foto, así que la alternativa para quien no puede deslizar depende del lector, del teclado o del switch.

## Opciones consideradas

1. **Como el prototipo:** foto recortada, sin desplazamiento ni pellizco. Rechazada por el propietario (P-17): se pierde información de las fotos altas.
2. **Foto entera, "contain", sin desplazamiento ni pellizco.** Descartada para el uso normal: no deja leer el detalle. *(Enmienda 1: tampoco es la forma de Bloquear zoom; la 017 la descartó, ver abajo.)*
3. **Swipe horizontal + desplazamiento vertical + pellizco, con las fotos al ancho** (como la imagen única) y alternativas para lector, teclado y switch, **sin botones visibles**. Con los puntos solo informativos.
4. Lo mismo que la 3, **con los puntos tocables** (o con botones pequeños de anterior y siguiente): cumple WCAG 2.5.1 sin excepción, pero añade una desviación del prototipo y un elemento táctil que el propietario no quiere.

## Decisión

Opción 3.

- **Swipe horizontal con un dedo** cambia de foto (infinito, umbral del 18 % del ancho o gesto rápido, 0,28 s; sin animación con "reducir movimiento"). El **desplazamiento vertical** y el **pellizco** (×8, vuelve al soltar) son los de la imagen única, en cada foto. El gesto se reparte por su dirección; con dos dedos nunca se cambia de foto; un swipe que empieza en el borde es del gesto de volver del sistema.
- **Horizontal:** el carrusel gira igual que la imagen única (DEV-42, ADR-0013, ADR-0015); en horizontal se mantienen el swipe, el pellizco y las alternativas de abajo, y se ocultan el menú, el botón de completar, el pie y los puntos.
- **Alternativas sin gesto de trayecto:** acciones "Foto siguiente" y "Foto anterior" en el elemento de la tarea (lector y Switch Access) **y las acciones estándar de desplazamiento horizontal** (para el control por voz y el desplazamiento del lector y de Switch Access), también en horizontal; flechas izquierda y derecha con teclado, con el elemento como punto de foco también en horizontal; un único anuncio "Foto {i} de {n}" por cualquier vía.
- **Los puntos son informativos:** un punto por foto, lleno el de la actual, decorativos para el lector y **sin interacción**.
- **Bloquear zoom** (spec 017) no se decidió aquí: su decisión se añade en la **Enmienda 1** (al final).

Es una **excepción a P6 (WCAG 2.5.1, nivel A, y 2.5.7, AA) decidida por el propietario:** quien no puede deslizar con un dedo y no usa lector, teclado ni switch no tiene una alternativa visible de un solo toque para cambiar de foto. La excepción se ve en la constitución 1.9.

**Criterio para revisarla:** si en la beta alguien no puede cambiar de foto, o con la auditoría de la 022 (TalkBack, Switch Access, teclado, control por voz) la alternativa no basta, se pasa a la opción 4 (puntos tocables con zona de ≥ 44 pt, o botones de anterior y siguiente) y se registra un DEV.

## Motivos

- Es lo que el propietario quiere: el indicador del prototipo, sin controles añadidos.
- Mantiene lo que ya funciona con la imagen única (leer en detalle) y no obliga a aprender un gesto nuevo.
- Para quien usa lector, teclado o switch, el cambio de foto es completo y está anunciado.
- La excepción es del mismo tipo y de menor alcance que la del pellizco (ADR-0013), que ya aceptó el propietario.

## Consecuencias

- **Positivas:** una sola forma de ver cada foto (la de la imagen única); sin controles nuevos en pantalla; el horizontal sigue igual que con una imagen.
- **Negativas y riesgos:**
  - **Excepción a P6 (WCAG 2.5.1)** para quien no puede el swipe y no usa tecnología de apoyo. Mitigación: acciones y teclas; los puntos informan; se revisa en la beta y en la auditoría.
  - **Conflicto de gestos** (swipe frente a desplazamiento y pellizco, y frente al gesto de volver del sistema). Mitigación: reparto por dirección con umbral, dos dedos sin swipe, borde para el sistema; se prueba en el dispositivo.
  - **Los puntos parecen controles de paginación:** quien los toque esperará un efecto y no lo habrá. Es un riesgo de percepción que se revisa en la beta; no se añade nada.
  - **Control por voz:** las acciones estándar de desplazamiento cubren "desplazar a la izquierda o a la derecha"; que también exponga "Foto siguiente" por nombre no está garantizado y se comprueba en el dispositivo.
  - La **lectura** por TalkBack al cambiar de foto: un único anuncio, sin releer el elemento (R-22, regiones vivas, sigue pendiente de migración).
- **Qué hay que hacer al aceptarlo:**
  - constitución **1.9**: nota en P6 con esta excepción y ampliación de la del ADR-0013 de "imagen" a "grupo de imágenes";
  - registrar **DEV-53** en `docs/design/prototype-deviations.md` y notas en DEV-41 y DEV-43;
  - ADR-0013: nota "ampliado al grupo de imágenes por el ADR-0022" (como la de ADR-0014 y 0015) y la misma en `docs/adr/README.md`;
  - a11y: casillas de dispositivo de la 016 en la 022 (TalkBack, Switch Access, teclado, Voice Access, horizontal).
- **[Hecho] Implementado (spec 016, 2026-10-07):** el anuncio único lo da una región viva con el idioma de la app (una frase por cambio en 5 por acción y 5 por gesto con TalkBack, emulador de API 37); con una foto alta, «desplazar adelante» del lector la recorre y luego pasa a la siguiente (propietario, 2026-10-07; «Foto siguiente/anterior» siempre es directa). **[Pendiente 022]** el gesto real de TalkBack, Switch Access, la voz y el control por voz (`specs/016-varias-imagenes-carrusel/dispositivo.md`); el criterio de revisión de arriba sigue en pie.
- **Qué dispararía revisarlo:** los criterios de arriba, una versión de Flutter que permita indicar el idioma por anuncio (R-22) o la spec 017.

## Enmienda 1 (spec 017, Bloquear zoom; propietario, 2026-10-07)

Este ADR anunciaba que la spec 017 añadiría su decisión como enmienda (qué bloquea y cómo se ve la foto). No es un ADR nuevo ni una excepción nueva (Q-017-6, aceptado por el propietario): la constitución sigue en la **1.9**.

- **Contexto.** D24 (2026-10-04) pedía un ajuste «Bloquear zoom» que impidiera el pellizco, el desplazamiento y el swipe del carrusel y dejara la foto entera, para poder **dibujar encima de la foto**. Al revisar la spec 017, el propietario la enmendó (2026-10-07): la foto sigue al 100 % del ancho, el swipe sigue funcionando y los controles no se ocultan.
- **Decisión.** Con el ajuste **Bloquear zoom** encendido en Ajustes (apagado por defecto, global y solo para tareas con una imagen o un grupo de fotos):
  - la foto se ve **como siempre, al 100 % del ancho, y se queda con el desplazamiento vertical que tenía** al encender el bloqueo (también al ir a Ajustes y volver y al apagarlo);
  - se **impiden el pellizco y el desplazamiento vertical por contacto**, con cualquier número de dedos, lápiz, ratón, rueda o *trackpad*;
  - **siguen** el swipe horizontal con cualquier puntero, las acciones «Foto siguiente» y «Foto anterior», las de desplazamiento horizontal estándar, las flechas, **y las órdenes deliberadas de desplazamiento vertical** (acciones del lector y del switch, «desplazar adelante / atrás», Av Pág y Re Pág); los puntos, el pie y los controles no cambian ni se ocultan;
  - la tarea **sigue girando**; en horizontal solo se ve un tramo de la foto, y girar y volver puede dejarla en otro desplazamiento (se acepta);
  - la **lupa del sistema** no se toca.
- **No cambia de alcance la excepción a P6** de este ADR (sin alternativa visible de un toque para el swipe, WCAG 2.5.1 y 2.5.7), ni se amplía la del pellizco (ADR-0013). Quitar el pellizco y el desplazamiento por contacto es **una opción que elige el usuario, apagada por defecto**; las órdenes por lector, switch, voz o teclado se mantienen, así que la frase del ADR-0013 («el desplazamiento de una imagen alta sí tiene alternativa») sigue siendo cierta.
- **Opciones que el propietario descartó:** ajustar la foto entera a la pantalla o al hueco libre; bloquear el swipe; ocultar los controles (D24, «a decidir con un caso real»); bloquear también el desplazamiento por orden; que el swipe solo funcione con el dedo (habría ampliado la excepción a P6).
- **Consecuencias y riesgos aceptados:**
  - un trazo horizontal sobre un grupo, al dibujar, puede cambiar de foto; se considera un caso extremo (la función se espera en fotos únicas);
  - las fotos muy altas o apaisadas no se tratan; la parte de una foto que no se ve no se alcanza **por contacto** (se apaga el bloqueo, se coloca y se vuelve a encender, o se usan las órdenes);
  - un trazo que llegue al menú o al botón de completar los acciona (completar exige 1,2 s y no tiene deshacer);
  - el ajuste no avisa en la propia tarea de que está activo (deliberado).
- **Criterio para revisarlo:** el de este ADR (la beta o la auditoría de la 022) y, además, si alguien necesita dibujar sobre un grupo (el swipe pasaría a ser solo con el dedo, o se bloquearía con el ajuste, ampliando la excepción) o si se decide ocultar los controles.
- **Qué hay que hacer:** nota en el ADR-0013 y en `docs/adr/README.md`; DEV-54 y notas en DEV-41, 43, 52 y 53; el glosario («Bloquear zoom»); la fila «Carrusel» del glosario recoge la salvedad al implementar.
