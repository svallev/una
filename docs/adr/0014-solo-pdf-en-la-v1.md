# ADR-0014: En la v1 solo se adjuntan PDF, que se ven, giran y se amplían en la propia tarea

- **Estado:** Aceptado. **Enmendado por el [ADR-0015](0015-sin-volver-a-vertical.md) (2026-09-28):** no hay botón "Volver a vertical" (ni con imagen ni con PDF) y deja de ser la mitigación de la excepción del horizontal; el resto de este ADR sigue
- **Fecha:** 2026-09-27
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 008, ADR-0008 (enmendado), ADR-0013, D6, D10, D18, D19, DEV-02, DEV-03, DEV-42, R-11, modelo de amenazas T-3 y T-8

## Contexto

- **[Hecho]** El ADR-0008 y D6 decidieron: el PDF, dentro de la tarea; Word, Excel, PowerPoint, ODF, RTF e iWork, en una tarjeta con "Abrir" que los pasa a otra app del teléfono (en Android, con `ACTION_VIEW` y un FileProvider de solo lectura). D19 añadió TXT, CSV y MD dentro, como texto plano.
- **[Hecho]** La revisión de la spec 008 (2026-09-27) mostró el coste de esa amplitud: reconocer una docena de formatos por el contenido (varios comparten contenedor con ZIP o con instaladores), depender de las apps instaladas (R-11), un FileProvider más con acceso a los adjuntos (T-8), textos y lecturas por tipo, y casos límite de codificación de texto.
- **[Hecho]** La propuesta de valor 2 (tener a la vista entradas, programas, horarios e instrucciones) se cubre con PDF.
- **[Hecho]** El ADR-0013 dejó la imagen sin visor, con un zoom de vistazo que vuelve al soltar (excepción a P6). Para leer un PDF hace falta un zoom que se quede puesto.

## Opciones consideradas

1. Mantener el ADR-0008 y D19: PDF y texto dentro; el resto, con otra app.
2. **Solo PDF en la v1**, dentro de la tarea; el resto de formatos, fuera de alcance.
3. Solo PDF y texto plano (TXT, CSV, MD).

## Decisión

En la v1 **solo se adjuntan PDF** (propietario, 2026-09-27):

- "Subir archivo" admite solo PDF, decidido por el contenido; hasta 10 MB (D18) y **20 páginas** (consulta rápida, no lectura de documentos largos). Los PDF que piden contraseña para abrirse se rechazan.
- El PDF se ve **en la propia tarea**, al 100 % del ancho, con desplazamiento vertical, **sin indicador de página**, y vuelve a la **última posición vista**.
- El **zoom se queda puesto** (a diferencia de la imagen) y tiene alternativas accesibles (acciones del lector, Switch Access y teclado): **no hay excepción a P6** para el PDF.
- La tarea con PDF **gira exactamente igual** que la de imagen (enmienda D10): en horizontal se ven el adjunto al ancho, el logotipo y el botón "Volver a vertical", que se añade también a la imagen (enmienda CA-007-11). La excepción de accesibilidad del horizontal de la imagen (WCAG 1.3.4 y 2.1.1, ADR-0013) se amplía al PDF, con "Volver a vertical" como mitigación en los dos casos.
- Los enlaces del PDF siguen siendo enlaces salvo los peligrosos: `http(s)`, `mailto:` y `tel:` con confirmación; el resto no hace nada.
- **No hay "Abrir con otra app"** ni visor del sistema en la v1.

Se revisará si los usuarios piden otros formatos (primero, probablemente, texto plano) o si llega F-iOS, donde QuickLook abre muchos formatos sin depender de otras apps.

## Motivos

- Menos superficie de ataque (T-3): un solo formato que reconocer y un solo motor (pdfrx, ya validado en S3) sobre archivos no confiables.
- Sin depender de las apps que tenga cada Android (R-11 desaparece en la v1) y sin un FileProvider nuevo sobre los adjuntos (T-8 no cambia).
- Menos textos, lecturas y casos límite: la spec 008 se puede cerrar antes y con más calidad.
- Cubre los casos de la propuesta 2.

## Consecuencias

- **Positivas:** spec, plan y pruebas más pequeños; sin permisos ni componentes nuevos; el giro y el zoom hacen legible un PDF de letra pequeña.
- **Negativas:** quien quiera adjuntar un Word o un Excel tiene que exportarlo a PDF. El texto de la hoja "Añadir" cambia a "PDF · va arriba del todo" (DEV-02). Se pierde D19 (TXT, CSV y MD dentro) hasta que se retome.
- **Enmiendas:** la nota de excepciones de P6 en la constitución (el horizontal también con PDF), CA-007-11, D6 y D19 (`docs/PLAN.md`), D10 (también gira el PDF), el ADR-0008 (su parte de "el resto, con el visor del sistema" y los tipos admitidos no aplican en la v1; lo del PDF sigue), DEV-02, DEV-03, DEV-18, DEV-40 y DEV-42.
- **[Suposición]** Recordar la última posición de cada PDF exige guardarla; si va en la base de datos, con una `schemaVersion` nueva y su test de migración (lo decide el plan de la 008).
- **Pendiente:** retomar otros formatos en una spec posterior, que partirá de la versión de la spec 008 del 2026-09-27 (revisión con `spec-reviewer`) y del ADR-0008.
