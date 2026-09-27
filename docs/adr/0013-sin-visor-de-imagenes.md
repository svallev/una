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
- **[Hecho]** Android ofrece la ampliación de accesibilidad del sistema (lupa), que funciona en cualquier app y con cualquier contenido.

## Opciones consideradas

1. **Mantener el visor** (spec aprobada): cumple P6 con acciones de zoom propias; el propietario lo rechaza.
2. **Sin visor; zoom de vistazo; la lupa del sistema como alternativa** (excepción a P6 registrada).
3. **Sin visor; zoom de vistazo; acciones "Ampliar" y "Ajustar al ancho" en el nodo de la tarea** para lector, teclado y switch, con un zoom que se queda puesto: cumple P6, pero añade un segundo comportamiento de zoom solo para ellos.

## Decisión

Opción 2: no hay visor de imágenes. La imagen se ve en la propia tarea (al ancho, con desplazamiento vertical), se amplía con un pellizco que vuelve al soltar, y quien no pueda pellizcar usa la lupa del sistema. Es una **excepción a P6** decidida por el propietario. Se revisará si la beta o una revisión de accesibilidad muestran que hace falta un zoom propio sin gestos (entonces, opción 3).

## Motivos

- Es lo que el propietario quiere para el producto: una sola pantalla, nada que abrir ni cerrar.
- Nada esencial depende del zoom: completar, eliminar y el menú tienen sus acciones accesibles, y el desplazamiento vertical de una imagen alta es visible sin ampliar.
- La lupa del sistema cubre la ampliación sin gestos en toda la app, también en las demás pantallas, mejor que un zoom propio limitado a la imagen.
- La opción 3 duplicaría el comportamiento (vistazo para gestos y zoom persistente para el resto) y la complejidad que el propietario quiere quitar.

## Consecuencias

- **Positivas:**
  - una pantalla y un flujo menos (sin "Cerrar", sin rutas apiladas);
  - desaparecen el código, los tests, los textos y el test de rendimiento del visor;
  - la imagen se ve siempre entera a lo ancho.
- **Negativas y riesgos:**
  - **Excepción a P6:** sin zoom propio sin gestos. Mitigación: la lupa del sistema; se anota en la spec 007 §6 y en la revisión de accesibilidad de la beta.
  - Una imagen muy detallada solo se amplía mientras se pellizca. Mitigación: hasta ×8 y siguiendo a los dedos; en horizontal se ve más grande.
  - La tarea actual gira (D10 enmendada otra vez): en horizontal se ocultan el menú y el botón de completar; completar y eliminar siguen disponibles como acciones del lector.
- **Pendiente:**
  - revisar con a11y-reviewer la excepción antes de cerrar la spec 007;
  - el visor de documentos (spec 008, ADR-0008) es otra decisión y no cambia con este ADR.
