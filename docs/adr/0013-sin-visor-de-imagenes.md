# ADR-0013: Sin visor de imágenes: la imagen se ve y se amplía en la propia tarea

- **Estado:** Aceptado (propietario, 2026-09-27)
- **Fecha:** 2026-09-27
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 007 (CA-007-08 a CA-007-12, CA-007-21 a CA-007-23), D10 (enmendada), DEV-35 y DEV-37 (revocadas), DEV-41 a DEV-43, constitución P6

## Contexto

- **[Hecho]** La spec 007 se aprobó con un visor a pantalla completa (DEV-35, DEV-37): al tocar la imagen se abría otra pantalla con "Cerrar", zoom por pasos hasta ×8 (doble toque), acciones accesibles de zoom y giro.
- **[Hecho]** Al probarlo en el Xiaomi (2026-09-27), el propietario pidió primero que el giro abriera y cerrara el visor, y después retirarlo del todo: "No quiero el visor para nada nunca".
- **[Hecho]** Lo que quiere en su lugar:
  - la imagen siempre al 100 % del ancho, sin perder nada por los lados, con desplazamiento vertical si es alta (DEV-41);
  - pellizcar amplía y al soltar vuelve al 100 % (DEV-43);
  - al girar el móvil, la tarea con imagen gira y solo se ven la imagen y el logotipo (DEV-42);
  - tocar la imagen no hace nada.
- **[Hecho]** El visor era la alternativa accesible al zoom (P6: "Toda acción por gesto tiene una alternativa accesible para lector de pantalla, teclado y switch"). Un zoom que vuelve al soltar no tiene equivalente natural sin gestos.
- **[Hecho]** Android ofrece la ampliación de accesibilidad del sistema (lupa), que funciona en cualquier app y con cualquier contenido. En Android 8–11 solo hay ampliación a pantalla completa, y moverse por lo ampliado exige dos dedos; la ventana de ampliación que se mueve con un dedo existe desde Android 12.
- **[Suposición]** La lupa cubre a quien no puede pellizcar: sin comprobar en el dispositivo, y en particular sin comprobar con teclado ni con conmutadores (auditoría de F5).
- **[Hecho]** Revisión de `a11y-reviewer` (2026-09-27): el pellizco sin alternativa en la app incumple **WCAG 2.5.1** (nivel A), y la vista horizontal sin menú ni botón incumple **WCAG 1.3.4 y 2.1.1** (con teclado no queda nada que enfocar y, con el móvil fijo en horizontal, no se ve el botón de completar).

## Opciones consideradas

1. **Mantener el visor** (spec aprobada): cumple P6 con acciones de zoom propias; el propietario lo rechaza.
2. **Sin visor; zoom de vistazo; la lupa del sistema como alternativa** (excepción a P6 registrada).
3. **Sin visor; zoom de vistazo; acciones "Ampliar" y "Ajustar al ancho" en el nodo de la tarea** para lector, teclado y switch, con un zoom que se queda puesto: cumple P6, pero añade un segundo comportamiento de zoom solo para ellos.

## Decisión

Opción 2: no hay visor de imágenes. La imagen se ve en la propia tarea (al ancho, con desplazamiento vertical), se amplía con un pellizco que vuelve al soltar, y quien no pueda pellizcar usa la lupa del sistema.

Es una **excepción a P6** (WCAG 2.2 AA como mínimo) decidida por el propietario, que cubre dos incumplimientos conocidos:
- **WCAG 2.5.1 (nivel A):** el pellizco es un gesto de dos dedos sin alternativa de un dedo en la app.
- **WCAG 1.3.4 y 2.1.1, solo en horizontal:** el horizontal es un modo para ver la imagen más grande, sin menú, botón de completar ni pie, y solo existe si la tarea tiene imagen (propietario, 2026-09-27). Todas las funciones están en vertical; con el bloqueo de rotación del sistema, la app se queda en vertical; en horizontal, completar y eliminar siguen como acciones del lector.

El desplazamiento de una imagen alta **sí** tiene alternativa: acciones de desplazamiento del lector y de Switch Access, y Av Pág / Re Pág con teclado (WCAG 2.1.1).

**Criterio para revisarla:** si en la beta alguien no puede ampliar una imagen, o necesita usar la app en horizontal (soporte fijo, tablet con teclado), se pasa a la opción 3 o se añaden al horizontal el menú y un botón de completar compactos.

## Motivos

- Es lo que el propietario quiere para el producto: una sola pantalla, nada que abrir ni cerrar.
- Nada esencial depende del zoom: completar y eliminar tienen sus acciones accesibles (también en horizontal), el menú está en vertical, y la parte de abajo de una imagen alta se alcanza desplazándose, también sin gestos.
- **[Suposición]** La lupa del sistema cubre la ampliación sin gestos en toda la app, también en las demás pantallas, mejor que un zoom propio limitado a la imagen (en Android 8–11, con dos dedos; se comprueba en la auditoría de F5).
- La opción 3 duplicaría el comportamiento (vistazo para gestos y zoom persistente para el resto) y la complejidad que el propietario quiere quitar.

## Consecuencias

- **Positivas:**
  - una pantalla y un flujo menos (sin "Cerrar", sin rutas apiladas);
  - desaparecen el código, los tests, los textos y el test de rendimiento del visor;
  - la imagen se ve siempre entera a lo ancho.
- **Negativas y riesgos:**
  - **Excepción a P6 (WCAG 2.5.1):** sin zoom propio sin gestos. Mitigación: la lupa del sistema; se anota en la spec 007 §6 y en la auditoría de accesibilidad de F5 (`docs/PLAN.md`).
  - Una imagen muy detallada solo se amplía mientras se pellizca. Mitigación: hasta ×8 y siguiendo a los dedos; en horizontal se ve más grande.
  - **Excepción a WCAG 1.3.4 y 2.1.1 en horizontal:** la tarea actual con imagen gira (D10 enmendada otra vez) y en horizontal se ocultan el menú, el botón de completar y el pie. Mitigación: todo está en vertical; el bloqueo de rotación mantiene el vertical; completar y eliminar siguen como acciones del lector. Quien usa teclado sin lector no tiene nada que enfocar en horizontal.
- **Pendiente:**
  - **[Hecho 2026-09-27]** revisión de `a11y-reviewer`: se añadieron el desplazamiento sin gestos y los tests de horizontal, y se documentaron las excepciones;
  - comprobar en la auditoría de F5 la lupa (pantalla completa y ventana, Android 8–11 y 12+, teclado y conmutadores) y Switch Access en horizontal;
  - el visor de documentos (spec 008, ADR-0008) es otra decisión y no cambia con este ADR.
