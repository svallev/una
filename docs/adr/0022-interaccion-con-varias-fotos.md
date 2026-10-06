# ADR-0022: Interacción con varias fotos: swipe para cambiar, desplazamiento vertical y pellizco como la imagen única, y puntos solo informativos

- **Estado:** Aceptado (propietario, 2026-10-06, con la spec 016). Incluye una **excepción a P6** (constitución 1.9)
- **Fecha:** 2026-10-06
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 016 (CA-016-09 a 12, 20 a 22; Q-016-3), D21, P-17 del plan F4b; **enmienda** al ADR-0013 (sin visor, pellizco de vistazo y horizontal) y al ADR-0015; constitución P6; DEV-41, DEV-42, DEV-43 y DEV-53; spec 017 (Bloquear zoom)

## Contexto

- **[Hecho]** El prototipo (tablero 15) muestra el carrusel con swipe horizontal, **foto recortada** (`overflow: hidden`, sin desplazamiento vertical ni pellizco) y **puntos** indicadores decorativos (`aria-hidden`, sin interacción, como mucho 12).
- **[Hecho]** El propietario decidió (D21, P-17, 2026-10-04): el carrusel conserva el desplazamiento vertical y el pellizco como la imagen única (ADR-0013, DEV-41 y DEV-43) y gira igual (DEV-42).
- **[Hecho]** El swipe horizontal con un dedo es un **gesto de trayecto y de arrastre**: WCAG 2.5.1 (nivel A) pide poder hacer lo mismo con un solo puntero sin trayecto y WCAG 2.5.7 (AA), una alternativa al arrastre. P6 pide además una alternativa para lector, teclado y switch para toda acción por gesto.
- **[Hecho]** El propietario, al decidir la Q-016-3 (2026-10-06), prefiere **mantener los puntos del prototipo** como indicador visual («un buen indicador visual de cuántas fotos hay y de que has vuelto al principio») y **no añadir botones ni zonas táctiles** para cambiar de foto.
- **[Hecho]** Ya hay una excepción parecida: el pellizco de la imagen única no tiene alternativa en la app (ADR-0013; lupa del sistema).
- **[Suposición]** Los puntos no se vuelven interactivos ni se les añaden botones de "anterior" y "siguiente"; la lupa del sistema no ayuda a cambiar de foto, así que la alternativa para quien no puede deslizar depende del lector, del teclado o del switch.

## Opciones consideradas

1. **Como el prototipo:** foto recortada, sin desplazamiento ni pellizco. Rechazada por el propietario (P-17): se pierde información de las fotos altas.
2. **Foto entera, "contain", sin desplazamiento ni pellizco** (la forma que tomará Bloquear zoom, spec 017). Descartada para el uso normal: no deja leer el detalle.
3. **Swipe horizontal + desplazamiento vertical + pellizco, con las fotos al ancho** (como la imagen única) y alternativas para lector, teclado y switch, **sin botones visibles**. Con los puntos solo informativos.
4. Lo mismo que la 3, **con los puntos tocables** (o con botones pequeños de anterior y siguiente): cumple WCAG 2.5.1 sin excepción, pero añade una desviación del prototipo y un elemento táctil que el propietario no quiere.

## Decisión

Opción 3.

- **Swipe horizontal con un dedo** cambia de foto (infinito, umbral del 18 % del ancho o gesto rápido, 0,28 s; sin animación con "reducir movimiento"). El **desplazamiento vertical** y el **pellizco** (×8, vuelve al soltar) son los de la imagen única, en cada foto. El gesto se reparte por su dirección; con dos dedos nunca se cambia de foto; un swipe que empieza en el borde es del gesto de volver del sistema.
- **Horizontal:** el carrusel gira igual que la imagen única (DEV-42, ADR-0013, ADR-0015); en horizontal se mantienen el swipe, el pellizco y las alternativas de abajo, y se ocultan el menú, el botón de completar, el pie y los puntos.
- **Alternativas sin gesto de trayecto:** acciones "Foto siguiente" y "Foto anterior" en el elemento de la tarea (lector y Switch Access) **y las acciones estándar de desplazamiento horizontal** (para el control por voz y el desplazamiento del lector y de Switch Access), también en horizontal; flechas izquierda y derecha con teclado, con el elemento como punto de foco también en horizontal; un único anuncio "Foto {i} de {n}" por cualquier vía.
- **Los puntos son informativos:** un punto por foto, lleno el de la actual, decorativos para el lector y **sin interacción**.
- **Bloquear zoom** (spec 017) no se decide aquí: la 017 añadirá su decisión a este ADR como enmienda (qué bloquea y cómo se ve la foto).

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
- **Qué dispararía revisarlo:** los criterios de arriba, una versión de Flutter que permita indicar el idioma por anuncio (R-22) o la spec 017.
