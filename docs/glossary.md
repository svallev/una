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
| Completar | Complete | `complete()` | Marcar la tarea actual como hecha manteniendo pulsado. La tarea y sus archivos se borran (sin histórico, ADR-0012). |
| Mantener pulsado | Press and hold | `HoldToComplete` | Gesto de 1,2 s que completa la tarea. |
| Eliminar | Delete | `delete()` | Quitar una tarea **sin** completarla. Es definitivo: no hay deshacer (ADR-0011). |
| Marca de borrado | Tombstone | `deletedAt` | Registro mínimo de que una tarea se eliminó. Sirve para una futura sincronización. |
| Histórico | History | `history` | Tareas completadas con su fecha. En la v1 se guarda pero no se muestra. **Retirado por el ADR-0012 (2026-09-26): no se guarda lo hecho.** |
| Adjunto | Attachment | `Attachment` | Archivo copiado dentro de la app y asociado a una tarea: imagen, PDF o documento. La tarea web es un adjunto **sin archivos**: solo guarda la dirección (ADR-0016). |
| Tipo de adjunto | Attachment kind | `AttachmentKind` | `image`, `pdf`, `web`; `document` (otros formatos) no se usa en la v1 (ADR-0014). |
| Foto | Photo | `AttachmentKind.image` (origen `camera`) | Imagen hecha con la cámara desde la app. |
| Imagen | Image | `AttachmentKind.image` (origen `gallery`) | Imagen elegida de la galería. |
| Documento | Document | `AttachmentKind.pdf` (v1); `AttachmentKind.document` (futuro) | Archivo adjunto que no es una imagen ni una URL. **En la v1 solo PDF** (ADR-0014): se ve en la propia tarea, al ancho, con desplazamiento y zoom. |
| Tarea web / URL | Web task / URL | `AttachmentKind.web` (origen `url`), `TaskWeb` | Tarea que muestra **una** página web, en vivo, a partir de la dirección guardada. Sin navegación: solo se siguen las redirecciones del servidor de la carga inicial y las anclas de la misma página; los enlaces, formularios, `mailto:` y `tel:` no hacen nada (ADR-0018). Necesita conexión: no se guarda nada de la página (ADR-0016). |
| Dirección guardada | Saved address | `Attachment.url` (columna `sourceUrl`) | La URL de la tarea web, validada y normalizada al crearla o editarla (con `https://` si no lo llevaba). Es lo único que se guarda de la página y lo que se carga cada vez; "Reintentar" y "Abrir en el navegador" usan siempre esta dirección (spec 009). |
| Barra del dominio | Domain bar | `WebBar` | Franja negra sobre la página de una tarea web: candado (sin él si la página no usa conexión segura), el dominio de la página que se ve (sin `www.`, recortado por el principio con "…" si no cabe) y "WEB". Es el nodo de la tarea para el lector; en horizontal no se ve (spec 009). |
| Instantánea / captura | Snapshot | `snapshot` | ~~Imagen de página completa de una URL, guardada al crearla, para verla sin conexión.~~ **Retirado por el ADR-0016 (2026-09-28): la tarea web no guarda copia.** Las columnas `snapshotRelPath`/`snapshotAt` quedan nulas. |
| Miniatura | Thumbnail | `thumbnail`, `thumb.jpg` | Versión pequeña de un adjunto para el listado: cuadrada y recortada, de 176 px (se ve a 44). |
| Configuración y perfil (temporal) | Settings and profile | `menuSettings`, `SettingsScreen` | Pantalla completa provisional, en tres niveles (opciones, lista de licencias y texto de una licencia), con dos opciones (licencias de código abierto y política de privacidad). Solo el primer nivel tiene el icono de cerrar; cierra hacia atrás de uno en uno y vuelve al menú tal como estaba. Sustituida más adelante por la Configuración completa (spec 012, DEV-49). |
| Licencias de código abierto | Open-source licenses | `licenses`, `LicensesScreen`, `LicenseDetailScreen` | Lista de lo de terceros que lleva la app (paquetes de Dart, fuentes, bibliotecas nativas y las de Android), con el texto de cada licencia en inglés y sin enlaces activos (spec 012). Se leen solo al abrir la lista. |
| Política de privacidad | Privacy policy | `privacyPolicyUrl` | Texto legal alojado en una web; la app solo abre su dirección en el navegador tras confirmarlo (spec 012). |
| Dirección marcador | Placeholder URL | — | Dirección falsa (dominio reservado para ejemplos) que se usa mientras la web de la política no existe. Una compilación de publicación no puede llevarla (CA-012-05). |
| Puerta de publicación | Release gate | `tools/check-release-config.sh` | Comprobación automática que impide publicar con la dirección marcador, una dirección que no sea `https` o una política con huecos. Se pasa en la lista de publicación, no en las compilaciones locales (spec 012). |
| Recientes | Recents (app switcher) | `recents` | Lista de aplicaciones recientes del sistema, que enseña una tarjeta con la última pantalla de cada app. La app no muestra su contenido ahí (spec 011). |
| Insignia | Badge | `TaskThumbnail` (`attachmentKindLabel`) | Recuadro negro de 44 px con el tipo ("PDF", "WEB") en la fila del listado de una tarea con PDF o web, en lugar de la miniatura; decorativa para el lector (specs 008 y 009). |
| Versión completa | Full version | `relPath` (prefijo de las teselas) | Copia de la imagen que guarda la app: recodificada, sin metadatos y como mucho de 24 MP, sin límite de lado. |
| Tesela | Tile | `ImageTiles`, `full-<fila>-<columna>.jpg` | Trozo de 4096 px como máximo de la versión completa. |
| Versión de pantalla | Display version | `displayRelPath`, `screen.jpg` | Recorte al tamaño de la pantalla para pintar la tarea actual rápido al abrir (CA-001-09). Con PDF, lo que se ve desde la última posición (spec 008). |
| Preparación | Staging | `cache/import/<id>`, `StagedImage`, `StagedPdf` | Zona temporal donde se copia y prepara un adjunto (imagen o PDF) antes de guardarlo con la tarea. |
| Adjunto no disponible | Missing attachment | `AttachmentFiles.missing`, `MissingAttachmentCard` | El archivo principal del adjunto (la versión completa de la imagen o el PDF) falta o no se puede leer: se muestra la tarjeta con una sola acción. |
| Barrido | Sweep | `AttachmentJanitor` | Limpieza, tras el primer fotograma, de adjuntos sin tarea y preparaciones abandonadas. |
| Pie | Caption | `caption` | Texto de la tarea sobre su imagen (recuadro negro, texto blanco). |
| Franja | Strip | `PdfStrip` | Barra negra fija sobre el PDF con "PDF", el nombre y el tamaño (spec 008). |
| Banda del texto | Caption band | `PdfCaptionBand` | Texto de la tarea sobre la primera página del PDF, del color de la nota; se desplaza y se amplía con las páginas (spec 008). |
| Última posición | Last position | `PdfPosition`, `position.json` | Página que ocupaba la parte de arriba y fracción desplazada dentro de ella donde se dejó de ver un PDF; al volver, se ve ahí (spec 008). |
| Enlace del PDF | PDF link | `LinkTarget`, `classifyLink` | Enlace dentro de un PDF: a otra página, a una web, a un correo o a un teléfono (siempre con confirmación, salvo a otra página); el resto no hace nada (spec 008). |
| Visor del sistema | System viewer | `SystemViewer` | QuickLook (iOS) o la app que registre el tipo (Android). **No se usa en la v1** (ADR-0014). |
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
| Configuración | Settings | `Settings` | Idioma, pantalla encendida, Acerca de. La completa no existe en la beta: spec futura de Configuración y perfil (2026-09-29); hasta entonces, la pantalla temporal de la spec 012 (licencias y política de privacidad). |
| Pantalla encendida | Keep screen on | `keepScreenOn` | Impide el bloqueo mientras se ve una tarea con adjunto. |
| Indicador de función | Feature flag | `FeatureFlag` | Interruptor local para funcionalidades a medio hacer. |
| Fecha límite *(futuro)* | Due date | `dueDate` | Bloque 1 de la hoja de ruta. |
| Subtarea *(futuro)* | Subtask | `parentId` | Bloque 2. |
| Origen de importación *(futuro)* | Import source | `source`, `externalId` | Bloque 3 (Todoist, Keep…). |

## Convenciones

- Nunca se usa "borrar" y "eliminar" como acciones distintas: la acción es **eliminar** (R10). "Borrar" solo se usa para el histórico en el futuro ("borrar histórico").
- En la interfaz se dice "tarea", nunca "nota". "Nota adhesiva" es un término visual interno.
- Nombre de la app: nunca aparece literal en el código. Se usa `AppIdentity.name` / la clave de traducción `appName`.
