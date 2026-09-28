# ADR-0015: Sin "Volver a vertical": la tarea con adjunto vuelve a vertical solo al girar el móvil

- **Estado:** Aceptado (propietario, 2026-09-28)
- **Fecha:** 2026-09-28
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 008 (CA-008-11, CA-008-20 a CA-008-22), spec 007 (CA-007-11), ADR-0013, ADR-0014 (enmendado), D10, DEV-42, constitución P6 (nota de excepciones, versión 1.3)

## Contexto

- **[Hecho]** El ADR-0014 decidió que la tarea con PDF gira igual que la de imagen y añadió, para las dos, un botón "Volver a vertical" en horizontal, que ponía la app en vertical aunque el móvil siguiera en horizontal. Era la mitigación de la excepción del horizontal a P6 (WCAG 1.3.4 y 2.1.1): con teclado sin lector quedaba algo que enfocar y se podía volver a la vista completa sin girar el móvil.
- **[Hecho]** El botón se implementó en T-008-17 (commit `bef386d`, 2026-09-28) y se vio en el emulador.
- **[Hecho]** El propietario decidió el 2026-09-28 quitarlo entero, con imagen y con PDF: la app vuelve a vertical solo cuando el móvil se pone en vertical. Se quitó en el commit `afeede8`.
- **[Hecho]** Sin el botón, el horizontal vuelve a la situación aceptada en el ADR-0013 para la imagen: con la imagen, en horizontal no queda nada que enfocar con teclado sin lector; con el PDF, lo único que se puede enfocar es el propio PDF, que lleva Completar, Eliminar, página, zoom y desplazamiento (CA-008-20). En horizontal, completar y eliminar siguen como acciones del lector con los dos tipos.
- **[Hecho]** Con el bloqueo de rotación del sistema, la app se queda en vertical (CA-008-11): quien no pueda o no quiera girar el móvil nunca llega al horizontal.

## Opciones consideradas

1. **Mantener "Volver a vertical"** (ADR-0014): mitiga la excepción a P6, pero el propietario no lo quiere.
2. **Quitar el botón**: se vuelve a vertical girando el móvil; la excepción del horizontal queda como en el ADR-0013, ampliada al PDF.

## Decisión

Opción 2 (propietario, 2026-09-28): **no hay botón "Volver a vertical"**, ni con imagen ni con PDF. La tarea con imagen o con PDF gira con el móvil y vuelve a vertical solo cuando el móvil se pone en vertical. El resto del ADR-0014 no cambia (la tarea con PDF gira igual que la de imagen; en horizontal, el adjunto al ancho y el logotipo).

La excepción del horizontal a P6 (WCAG 1.3.4 y 2.1.1) sigue ampliada al PDF, **sin** el botón como mitigación: la mitigan el bloqueo de rotación del sistema (la app se queda en vertical) y, en horizontal, las acciones del lector sobre el adjunto (completar y eliminar; con PDF, además, página, zoom y desplazamiento).

**Criterio para revisarla:** el mismo del ADR-0013: si en la beta alguien necesita usar la app en horizontal (soporte fijo, tablet con teclado) o no puede volver a la vista completa, se añaden al horizontal el menú y un botón de completar compactos, o se recupera "Volver a vertical".

## Motivos

- Decisión de producto del propietario: el horizontal es un modo para ver el adjunto más grande, y se entra y se sale de él girando el móvil, sin controles que tapen el adjunto.
- Menos estado en la parte nativa: sin el vertical "retenido" hasta que el móvil pase por vertical, el sensor y el botón no pueden pisarse (riesgo del plan de la 008, sin objeto).

## Consecuencias

- **Positivas:** el horizontal se ve más limpio (solo el adjunto y el logotipo); menos código nativo, un texto y un token menos.
- **Negativas:** con teclado sin lector, en horizontal con imagen no queda nada que enfocar (con PDF, solo el PDF), y para volver a la vista completa hay que girar el móvil. Mitigación: el bloqueo de rotación del sistema mantiene la app en vertical, y todas las funciones están en vertical.
- **Enmiendas:** ADR-0014 (el botón y su papel de mitigación), la nota de excepciones de P6 en la constitución (versión 1.3), CA-008-11 (y la enmienda que hacía a CA-007-11, que vuelve a ser como en la 007), CA-008-20 a CA-008-22, D10 y DEV-42. Hechas el 2026-09-28.
- **Pendiente:** comprobar en el Xiaomi (HyperOS) que la tarea gira y vuelve con el sensor (T-008-22), y la revisión de accesibilidad del horizontal con TalkBack y teclado (T-008-23).
