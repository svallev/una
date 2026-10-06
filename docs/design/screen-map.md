# Pantallas del prototipo → specs

Prototipo: https://claude.ai/artifact/CGzh6J5tbnhQgM3J9wPX7q (copia local en `design/prototype/`, con fecha 2026-09-24; **actualizada el 2026-10-04** con la versión `1791043617-5b3d` del artefacto: tableros 12–17 y tablero 6 nuevo, plan F4b en `docs/PLAN.md`).
Los tableros cargan sus scripts y fotos de prueba de `/_blob/…` del artefacto, que no se copian; las imágenes del icono (tablero 17) sí están en `design/prototype/assets/icon/` (ver al final).
Todos los artboards son `Main.dc.html` arrancado en un estado (`start=…`). Formato de referencia: 390 × 844.

| # | Artboard (archivo) | Estado `start` | Qué muestra | Specs | Reglas |
|---|---|---|---|---|---|
| 0 | Prototipo (empieza vacío) · `Main.dc.html` | `vacio` | Logo "una.", máquina de escribir "Ya puedes crear tu primera tarea" → editor | 001 | R1, R2 |
| 1 | La tarea · `Nota.dc.html` | `nota` | Tarea actual como nota adhesiva a pantalla completa, botón de menú y botón de completar | 001, 003 | R6, R8, R9 |
| 2 | Menú · `Menu.dc.html` | `menu` | Hoja: "Esta tarea" (Editar, Eliminar) · Todas mis tareas · Nueva tarea · **Ajustes** (desde 2026-10-04; antes "Configuración y perfil"). El archivo incrusta `Main` dos veces (dos `dc-import` seguidos), ya en la copia de 2026-09-24 | 005, 006, 012 → **015** (Ajustes sustituye a la pantalla temporal, DEV-49) | R7, R11 |
| 3 | Nueva tarea · `Nueva.dc.html` | `nueva` | Editor de texto con placeholder, botón de adjuntar (+) y "Continuar" | 002, 001 | R3 |
| 4 | ¿Dónde va? · `Posicion.dc.html` | `posicion` | Hoja "¿Dónde la pones?": Arriba del todo / A la cola / Seguir editando | 002 | R4 |
| 5 | Todas las tareas · `Lista.dc.html` | `lista` | Listado; la primera es la tarea actual (sin asa; la etiqueta "Lo siguiente" está oculta); arrastrar, "Mover", doble toque, editar y eliminar | 006 | R7, R13 |
| 6 | Eliminar · `Eliminar.dc.html` | `deshacer` | **Desde 2026-10-04:** "Eliminar: sin confirmación, con deshacer". El archivo es idéntico a `Deshacer.dc.html` (tablero 12). La hoja "¿Eliminar esta tarea?" sigue en `Main` pero ya no se usa (`undoMode = true`) | 004 → **014** | R10 |
| 7 | Completar · `Hecho.dc.html` | `hecho` | Mantener pulsado (el relleno avanza 1,2 s) → la nota se rompe en dos → "¡Enhorabuena! Tarea completada." → siguiente | 003 | R9 |
| 8 | Eliminar (se arruga) · `Borrado.dc.html` | `borrado` | Arrugado con facetas → bola → papelera animada | 004 | R10 |
| 9 | Añadir (+) · `Adjuntar.dc.html` | `adjuntar` | Hoja "Añadir a la tarea": Hacer foto · **Subir imágenes** ("Una o varias · van arriba del todo", desde 2026-10-04) · Subir archivo · Cargar URL | 007, 008, 009, **016** | R3, R5 |
| 10 | Tarea con documento · `Documento.dc.html` | `documento` | Tarea con PDF abierto dentro de la tarea y texto opcional | 008 | R5 |
| 11 | Tarea web · `Web.dc.html` | `web` | Tarea con URL: candado + dominio + "WEB"; página dentro de la tarea | 009 | R5 |
| 12 | Eliminar con deshacer: la tarea · `Deshacer.dc.html` | `deshacer` | Se cierra el menú, la tarea se arruga y aparece la card negra "Tarea eliminada" + texto + "Deshacer", con barra de tiempo del color de la nota; mientras se ve, se oculta "Pulsa para completar". **Duración: manda 4 s** (propietario, 2026-10-04); el prototipo dice 3 s (CSS, `setTimeout` y título del tablero 6) y "5 s" en un comentario | 014 | R10 |
| 13 | Eliminar con deshacer: desde la lista · `DeshacerLista.dc.html` | `deshacerlista` | La fila desaparece sin arrugarse y aparece la card; se oculta "Nueva tarea"; deshacer resalta la fila restaurada; un borrado nuevo sustituye a la card anterior | 014 | R10, R13 |
| 14 | Varias imágenes: preselección · `FotosSel.dc.html` | `fotossel` | Editor con las fotos apiladas (como mucho 3 a la vista, giradas, la primera arriba) y la etiqueta "N fotos". El prototipo admite 30; **la app, 10** (propietario, 2026-10-04) | 016 | R3, R5 |
| 15 | Tarea con varias fotos: carrusel · `Fotos.dc.html` | `fotos` | Carrusel infinito con swipe (anterior, actual y siguiente), puntos indicadores (decorativos, como mucho 12), pie de la tarea encima. El prototipo recorta las fotos altas y no tiene pellizco; **la app conserva el desplazamiento vertical y el pellizco** (P-17 del plan F4b) | 016, 017 | R5 |
| 16 | Ajustes · `Ajustes.dc.html` | `ajustes` | Pantalla completa que sube desde abajo y cierra el menú: Idioma · Notificaciones (switch + acordeón 1/2/3 con ayuda) · — · Pantalla siempre activa · Bloquear zoom · — · Información (Política de privacidad, Licencias de terceros) · Ayuda (las tres abren la web). Switch encendido `#FFDC58` (token nuevo). Sin diseñar: la página de Idioma y las webs. **La spec 015 (implementada, rama `feat/015-ajustes`) hace todo salvo Notificaciones (019) y Bloquear zoom (017), que se añaden en su sitio.** Las tres filas de web abren el navegador directamente (sin confirmación) y el menú se cierra y Ajustes sube a la vez (DEV-52) | 015, 017, 019 | R15, R18 |
| 17 | Icono de la app · `Icono.dc.html` | — | "u." en Archivo 900 sobre `#FFE55C`: iOS (1024), Android adaptable (círculo, squircle, gota) y con tema (13+), Google Play 512 | 018 | — |
| — | Estados vacíos (dentro de `Main`) | — | "Todo hecho." + "Crear una tarea" (el "Nada pendiente." del prototipo no se usa, DEV-24) | 003, 004 | R12 |
| — | Página de Idioma (spec 015) | — | **Sin diseño** (DEV-52): título "Idioma", Volver y tres filas con marca de selección (Como el sistema, Español, English), hechas con `SheetRow`; elegir una vuelve a Ajustes con el foco en "Idioma" | 015 | R15 |
| — | Hoja "Cargar URL" (dentro de `Main`) | — | Campo `https://`, errores, "Se abre como tarea, arriba del todo." | 009 | R5 |
| — | Configuración y perfil (temporal) · 3 niveles | — | **No existe en el prototipo** (DEV-49). **Sustituida por Ajustes (tablero 16, spec 015, implementada; DEV-52): ya no existe, se retiraron los niveles 2 y 3 (licencias, ADR-0026). Lo que sigue describe la pantalla temporal de la 012, solo como historia.** Nivel 1: pantalla completa con título, icono de cerrar y dos opciones (licencias de código abierto; política de privacidad, que tras confirmarlo abre una web en el navegador). Nivel 2: lista de licencias ("nombre, N licencias"). Nivel 3: texto de una licencia, en inglés. Rutas sobre el menú, con fundido de 160 ms; cierra hacia atrás de uno en uno | 012 (temporal, propietario 2026-09-30) | — |
| — | ~~Configuración completa~~ | — | **Diseñada el 2026-10-03: es el tablero 16 (Ajustes)** | 015 | R15 |

## Elementos sin pantalla en el prototipo (pendientes de diseño)

- ~~Configuración completa~~: diseñada (tablero 16, spec 015). Sigue sin diseño la **página de Idioma** (hecha en la 015 con componentes existentes: `UnaRadioRow` con marca de selección, P-16 del plan F4b) y el aviso de **permiso de notificaciones denegado** (con `UnaLinkButton`, spec 019).
- Páginas web de Política de privacidad, Licencias de terceros y Ayuda: no existen todavía; la app usa direcciones marcador (P-15 del plan F4b).
- Visor a pantalla completa con zoom (captura): spec 009. El PDF no tiene visor aparte: se ve, se amplía y gira en la propia tarea (spec 008, ADR-0014). La imagen no tiene visor: se ve y se amplía en la tarea actual (spec 007, ADR-0013).
- ~~Tarjeta de documento no PDF con "Abrir": spec 008.~~ No en la v1: solo PDF (ADR-0014).
- Aviso de captura sin conexión "Copia del dd/mm" y "Actualizar": spec 009.
- Errores de importación (tipo no admitido, demasiado grande, sin espacio): specs 007, 008.

Hasta que haya diseño, se implementan con los tokens y los componentes existentes, y se marcan con *feature flag* si no están terminados.

## Imágenes del icono (tablero 17)

Copiadas del almacén del artefacto el 2026-10-04 a `design/prototype/assets/icon/` (fuente para la spec 018):

| Archivo | Recurso del artefacto | Qué es |
|---|---|---|
| `icon-1024.png` | `/_blob/22eba85446f52b2291880172985f3567` | Original 1024 × 1024, sin transparencia ("u." negra sobre `#FFE55C`); iOS, App Store y base de Play 512 |
| `adaptive-foreground-432.png` | `/_blob/a67f79f0863b4add0c1517f9012b8898` | Primer plano del icono adaptable de Android (432 × 432 = 108 dp a ×4, con transparencia) |
| `adaptive-monochrome-432.png` | `/_blob/79181d8889794ed9d3f99036dc082e9a` | Capa monocroma (icono "con tema", Android 13+); no la usa el tablero, pero es la fuente del monocromo |
| `themed-preview-432.png` | `/_blob/639256cebcacd4f5c372a3ec8a5f8c5d` | Vista previa del icono con tema (azul) que muestra el tablero |
