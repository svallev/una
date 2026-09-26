# Pantallas del prototipo → specs

Prototipo: https://claude.ai/artifact/CGzh6J5tbnhQgM3J9wPX7q (copia local en `design/prototype/`, con fecha 2026-09-24).
Todos los artboards son `Main.dc.html` arrancado en un estado (`start=…`). Formato de referencia: 390 × 844.

| # | Artboard (archivo) | Estado `start` | Qué muestra | Specs | Reglas |
|---|---|---|---|---|---|
| 0 | Prototipo (empieza vacío) · `Main.dc.html` | `vacio` | Logo "una.", máquina de escribir "Ya puedes crear tu primera tarea" → editor | 001 | R1, R2 |
| 1 | La tarea · `Nota.dc.html` | `nota` | Tarea actual como nota adhesiva a pantalla completa, botón de menú y botón de completar | 001, 003 | R6, R8, R9 |
| 2 | Menú · `Menu.dc.html` | `menu` | Hoja: "Esta tarea" (Editar, Eliminar) · Todas mis tareas · Nueva tarea · Configuración | 005, 006, 010 | R7, R11 |
| 3 | Nueva tarea · `Nueva.dc.html` | `nueva` | Editor de texto con placeholder, botón de adjuntar (+) y "Continuar" | 002, 001 | R3 |
| 4 | ¿Dónde va? · `Posicion.dc.html` | `posicion` | Hoja "¿Dónde la pones?": Arriba del todo / A la cola / Seguir editando | 002 | R4 |
| 5 | Todas las tareas · `Lista.dc.html` | `lista` | Listado; la primera es la tarea actual (sin asa; la etiqueta "Lo siguiente" está oculta); arrastrar, "Mover", doble toque, editar y eliminar | 006 | R7, R13 |
| 6 | Eliminar · `Eliminar.dc.html` | `eliminar` | Hoja "¿Eliminar esta tarea?" «…» desaparecerá sin marcarse como hecha | 004 | R10 |
| 7 | Completar · `Hecho.dc.html` | `hecho` | Mantener pulsado (el relleno avanza 1,2 s) → la nota se rompe en dos → "¡Enhorabuena! Tarea completada." → siguiente | 003 | R9 |
| 8 | Eliminar (se arruga) · `Borrado.dc.html` | `borrado` | Arrugado con facetas → bola → papelera animada | 004 | R10 |
| 9 | Añadir (+) · `Adjuntar.dc.html` | `adjuntar` | Hoja "Añadir a la tarea": Hacer foto · Subir imagen · Subir archivo · Cargar URL | 007, 008, 009 | R3, R5 |
| 10 | Tarea con documento · `Documento.dc.html` | `documento` | Tarea con PDF abierto dentro de la tarea y texto opcional | 008 | R5 |
| 11 | Tarea web · `Web.dc.html` | `web` | Tarea con URL: candado + dominio + "WEB"; página dentro de la tarea | 009 | R5 |
| — | Estados vacíos (dentro de `Main`) | — | "Todo hecho." + "Crear una tarea" (el "Nada pendiente." del prototipo no se usa, DEV-24) | 003, 004 | R12 |
| — | Hoja "Cargar URL" (dentro de `Main`) | — | Campo `https://`, errores, "Se abre como tarea, arriba del todo." | 009 | R5 |
| — | Configuración | — | **No existe en el prototipo** → hay que diseñarla (pendiente de diseño) | 010 | R15 |

## Elementos sin pantalla en el prototipo (pendientes de diseño)

- Configuración (idioma, pantalla encendida, Acerca de, licencias): spec 010.
- Visor a pantalla completa con zoom (imagen, PDF, captura): specs 007, 008, 009.
- Tarjeta de documento no PDF con "Abrir": spec 008.
- Aviso de captura sin conexión "Copia del dd/mm" y "Actualizar": spec 009.
- Errores de importación (tipo no admitido, demasiado grande, sin espacio): specs 007, 008.

Hasta que haya diseño, se implementan con los tokens y los componentes existentes, y se marcan con *feature flag* si no están terminados.
