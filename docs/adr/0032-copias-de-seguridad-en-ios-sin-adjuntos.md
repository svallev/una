# ADR-0032: Copias de seguridad en iOS: la BD sí, los adjuntos no (como en Android)

- **Estado:** **Aceptado** (propietario, 2026-11-19, Q-028-6 de la spec 028: «que se comporte igual que Android»). **Enmienda la parte iOS del ADR-0004.**
- **Fecha:** 2026-11-19
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 028 (CA-028-18), specs 007, 008 y 016 (CA-007-18, CA-008-17, CA-016-17, CA-007-19), ADR-0004, ADR-0005; modelo de amenazas (A-1, T-7).

## Contexto

- **[Hecho]** El ADR-0004 decía para iOS «se incluye todo (BD + adjuntos)». En Android, la BD y los ajustes entran en la copia en la nube y los adjuntos **no** (van solo en la transferencia directa entre dispositivos en Android 12+); una tarea restaurada sin su archivo muestra «Adjunto no disponible» (CA-007-19).
- **[Hecho, ADR-0004]** La copia de iCloud solo está cifrada de extremo a extremo con la Protección Avanzada de Datos.
- **[Suposición, conocimiento previo de la API de Apple]** Un archivo marcado con `isExcludedFromBackup` no entra ni en la copia de iCloud ni en la del ordenador; tampoco se sabe si viaja en la migración directa entre iPhones.

## Opciones consideradas

1. **Igual que Android:** la BD en la copia; los adjuntos (`attachments/`) excluidos.
2. **Todo en la copia** (el ADR-0004 original).

## Decisión

**Opción 1**, por decisión del propietario: en iOS se marca **`attachments/` como excluido de la copia** (la carpeta entera, al crearla y al arrancar) y la BD queda incluida. Lo temporal (la preparación de una importación) ya va fuera por estar en `Caches`. Al restaurar en otro iPhone, las tareas con adjunto muestran «Adjunto no disponible» y se pueden eliminar o sustituir, como en Android. Se revisa con el pendiente del ADR-0004 (copia de los adjuntos solo cifrada de extremo a extremo) o si la beta lo señala.

## Motivos

La misma conducta en las dos plataformas, y ninguna foto ni PDF de las tareas sale del dispositivo a una nube sin cifrado de extremo a extremo.

## Consecuencias

- **Positivas:** coherencia con Android; menos datos en iCloud.
- **Negativas:** al cambiar de iPhone se pierden los adjuntos (también, probablemente, en la migración directa [Suposición], a diferencia de Android 12+). Mitigación: «Adjunto no disponible» nunca cierra la app (CA-007-19, CA-016-18a/b).
- **Cambios en otros documentos:** nota en el ADR-0004 (parte iOS) y fila en el README de los ADR.
