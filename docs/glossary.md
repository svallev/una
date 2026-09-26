# Glosario de dominio (ES ⇄ EN)

Fuente única de términos. El **código usa la columna "Código"**, los textos de la interfaz usan las columnas ES/EN y la documentación usa el término en español. Si falta un término, se añade aquí antes de usarlo.

| Español (docs/UI) | English (UI) | Código | Definición |
|---|---|---|---|
| Tarea | Task | `Task` | Unidad de trabajo pendiente o completada. Tiene texto, un adjunto o ambos. |
| Tarea actual | Current task | `currentTask` | La primera tarea pendiente de la cola. Es la única que se ve en la pantalla principal. En el listado es la primera fila (sin asa y sin etiqueta visible). |
| Cola | Queue | `TaskQueue` | Secuencia ordenada de tareas pendientes. El orden lo da `rank`. |
| Arriba del todo | On top | `QueuePosition.top` | Insertar antes de la tarea actual: la nueva pasa a ser la actual. |
| A la cola | At the end | `QueuePosition.end` | Insertar después de la última tarea pendiente. |
| Posición (rango) | Rank | `rank` | Clave de orden fraccional (*fractional indexing*) en texto. Permite insertar entre dos tareas sin renumerar. |
| Completar | Complete | `complete()` | Marcar la tarea actual como hecha manteniendo pulsado. Pasa al histórico. |
| Mantener pulsado | Press and hold | `HoldToComplete` | Gesto de 1,2 s que completa la tarea. |
| Eliminar | Delete | `delete()` | Quitar una tarea **sin** completarla. Es definitivo: no hay deshacer (ADR-0011). |
| Marca de borrado | Tombstone | `deletedAt` | Registro mínimo de que una tarea se eliminó. Sirve para una futura sincronización. |
| Histórico | History | `history` | Tareas completadas con su fecha. En la v1 se guarda pero no se muestra. **Retirado por el ADR-0012 (2026-09-26): no se guarda lo hecho.** |
| Adjunto | Attachment | `Attachment` | Archivo copiado dentro de la app y asociado a una tarea: imagen, PDF, documento o captura de URL. |
| Tipo de adjunto | Attachment kind | `AttachmentKind` | `image`, `pdf`, `document`, `web`. |
| Foto | Photo | `AttachmentKind.image` (origen `camera`) | Imagen hecha con la cámara desde la app. |
| Imagen | Image | `AttachmentKind.image` (origen `gallery`) | Imagen elegida de la galería. |
| Documento | Document | `AttachmentKind.document` | Archivo no PDF (Word, Excel, TXT…) que se abre con el visor del sistema. |
| Tarea web / URL | Web task / URL | `AttachmentKind.web` | Tarea que muestra una página web. |
| Instantánea / captura | Snapshot | `snapshot` | Imagen de página completa de una URL, guardada al crearla, para verla sin conexión. |
| Miniatura | Thumbnail | `thumbnail`, `thumb.jpg` | Versión pequeña de un adjunto para el listado: cuadrada y recortada, de 176 px (se ve a 44). |
| Visor | Viewer | `ImageViewerScreen` | Pantalla completa que se abre al tocar la imagen: al ancho, con desplazamiento vertical y zoom opcional (spec 007). |
| Versión completa | Full version | `relPath` (prefijo de las teselas) | Copia de la imagen que guarda la app: recodificada, sin metadatos y como mucho de 24 MP, sin límite de lado. |
| Tesela | Tile | `ImageTiles`, `full-<fila>-<columna>.jpg` | Trozo de 4096 px como máximo de la versión completa. |
| Versión de pantalla | Display version | `displayRelPath`, `screen.jpg` | Recorte al tamaño de la pantalla para pintar la tarea actual rápido al abrir (CA-001-09). |
| Preparación | Staging | `cache/import/<id>`, `StagedImage` | Zona temporal donde se copia y limpia una imagen antes de guardarla con la tarea. |
| Adjunto no disponible | Missing attachment | `AttachmentFiles.missing`, `MissingAttachmentCard` | La versión completa falta o no se puede leer: se muestra la tarjeta con una sola acción. |
| Barrido | Sweep | `AttachmentJanitor` | Limpieza, tras el primer fotograma, de adjuntos sin tarea y preparaciones abandonadas. |
| Pie | Caption | `caption` | Texto de la tarea sobre su imagen (recuadro negro, texto blanco). |
| Visor del sistema | System viewer | `SystemViewer` | QuickLook (iOS) o la app que registre el tipo (Android). |
| Nota adhesiva | Sticky note | `StickyNote` | Representación visual de una tarea (color de la paleta). |
| Color de la nota | Note color | `colorKey` | Índice 0–4 de la paleta. Se guarda con la tarea. |
| Listado | Task list | `TaskListScreen` | Pantalla "Todas las tareas" (se abre con "Todas mis tareas" del menú). |
| Reordenar | Reorder | `ReorderTask` | Cambiar la posición de una tarea pendiente en la cola. Solo cambia su `rank`. |
| Hacer actual | Make current | `makeCurrent` | Llevar una tarea del listado a la posición 1: pasa a ser la tarea actual. |
| Mover arriba / abajo | Move up / down | `moveUp`, `moveDown` | Cambiar una tarea una posición en la cola. |
| Asa (de arrastre) | Drag handle | `DragHandle` | Botón "Mover tarea" de cada fila del listado salvo la primera: se arrastra para reordenar o se toca para abrir "Mover". |
| Menú | Menu | `TaskMenuSheet` | Hoja inferior con las acciones de la tarea y las generales. |
| Hoja inferior | Bottom sheet | `*Sheet` | Panel que sube desde abajo. |
| Primera vez / bienvenida | First run / welcome | `FirstRun`, `WelcomeIntro` | Animación inicial y creación obligatoria de la primera tarea. |
| Estado vacío | Empty state | `EmptyState` | "Todo hecho.": no queda ninguna tarea pendiente (tras completar o eliminar la última). No existe "Nada pendiente." |
| Configuración | Settings | `Settings` | Idioma, pantalla encendida, Acerca de, licencias. |
| Pantalla encendida | Keep screen on | `keepScreenOn` | Impide el bloqueo mientras se ve una tarea con adjunto. |
| Indicador de función | Feature flag | `FeatureFlag` | Interruptor local para funcionalidades a medio hacer. |
| Fecha límite *(futuro)* | Due date | `dueDate` | Bloque 1 de la hoja de ruta. |
| Subtarea *(futuro)* | Subtask | `parentId` | Bloque 2. |
| Origen de importación *(futuro)* | Import source | `source`, `externalId` | Bloque 3 (Todoist, Keep…). |

## Convenciones

- Nunca se usa "borrar" y "eliminar" como acciones distintas: la acción es **eliminar** (R10). "Borrar" solo se usa para el histórico en el futuro ("borrar histórico").
- En la interfaz se dice "tarea", nunca "nota". "Nota adhesiva" es un término visual interno.
- Nombre de la app: nunca aparece literal en el código. Se usa `AppIdentity.name` / la clave de traducción `appName`.
