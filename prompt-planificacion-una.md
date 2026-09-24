# Planificación del proyecto "Una" — prompt para Claude Code

## 0. Tu rol y cómo quiero que trabajes

Actúa como un equipo senior formado por: arquitecto/a de software móvil, product manager, ingeniero/a de ciberseguridad (OWASP MASVS) y responsable de QA. Tu tarea en esta sesión es **planificar**, no programar.

Reglas de trabajo:

1. **Trabaja en modo plan.** No escribas código de la aplicación hasta que yo apruebe el plan. Sí puedes crear documentación, plantillas y configuración de proyecto cuando te lo apruebe.
2. **Primero pregunta, luego planifica.** Antes de redactar nada, lee todo este documento y el prototipo, y hazme las preguntas que necesites. Agrúpalas por tema, de 4 en 4 como máximo, cada una con opciones concretas, tu recomendación marcada y el impacto de cada opción. No preguntes lo que puedas decidir tú con un criterio razonable: en ese caso decide, y deja la decisión documentada para que yo la revise.
3. **Prefiero más esfuerzo en planificación que errores después.** Detecta contradicciones, huecos y riesgos en lo que te pido y dímelo claramente, aunque contradiga mis instrucciones.
4. **Todo lo que decidas queda escrito en el repositorio** (ver sección 10). Nada importante vive solo en la conversación.
5. **Distingue siempre** entre lo que es un hecho, lo que es una suposición tuya y lo que está pendiente de decidir.

---

## 1. El producto

**Nombre provisional:** "Una." (puede cambiar; el nombre debe estar centralizado en un único sitio de configuración y no incrustado en el código, rutas, identificadores ni textos).

**Qué es:** una app móvil de gestión de tareas que solo te muestra **una tarea pendiente a la vez**. Parte de la premisa de que las personas solo podemos hacer una cosa a la vez.

**Qué no es:** no es un SaaS. No hay servidor, cuentas ni login. Todo se guarda en el teléfono del usuario y la app funciona al 100 % sin conexión (en modo avión).

### Propuestas de valor (en orden de importancia para la comunicación)

1. **Centrarse en una sola cosa a la vez.**
2. **Acceso instantáneo a un único elemento a pantalla completa.** El usuario hace o sube una foto, un documento o una URL y queda a pantalla completa, visible nada más abrir la app, sin más toques. Casos de uso: horarios de un festival o de un congreso, el mapa de un parque, los pasos de una receta, las instrucciones de una tarea. Hoy la gente lo resuelve haciendo una captura y poniéndola como fondo de pantalla de bloqueo. Esta propuesta **es central**: debe guiar decisiones técnicas (velocidad de arranque, visor de imágenes, funcionamiento offline) y la futura landing.

---

## 2. Reglas de producto (fuente de verdad funcional)

Conviértelas en especificaciones con criterios de aceptación verificables (formato Dado/Cuando/Entonces).

**Primera vez**
- R1. Al abrir por primera vez se muestra una breve animación de bienvenida y la app va directamente a crear la primera tarea.
- R2. Hasta que se crea la primera tarea no se puede hacer nada más.

**Crear tareas**
- R3. Una tarea se puede crear con: texto, foto con la cámara, imagen de la galería, documento (PDF, Word, Excel, TXT…) o URL.
- R4. Al crear una tarea de **texto** cuando ya hay otras, la app pregunta dónde va: **"Arriba del todo"** (pasa a ser la visible; la actual espera) o **"A la cola"** (al final; no se verá hasta completar las anteriores).
- R5. Las tareas creadas con **imagen, foto, documento o URL** van siempre arriba del todo, sin preguntar.

**La pantalla principal**
- R6. Solo se ve una tarea: la primera pendiente.
- R7. Ver el resto de tareas requiere al menos dos interacciones (menú → "Todas mis tareas"). Es intencionado: el foco está en una sola.
- R8. Al cerrar y volver a abrir la app, lo primero que se ve es siempre la tarea pendiente actual, lo más rápido posible.

**Acciones sobre la tarea actual**
- R9. Completar: mantener pulsado. Al completarla, el usuario recibe un refuerzo positivo ("¡Enhorabuena! Tarea completada. Ahora a por la siguiente →") y pasa a la siguiente.
- R10. Eliminar: con confirmación ("desaparecerá sin marcarse como hecha") y animación de papel arrugado.
- R11. Editar, crear otra tarea y acceder al menú.
- R12. Estados vacíos: "Todo hecho." si se completó la última; "Nada pendiente." si se eliminó la última.

**Listado de tareas**
- R13. Permite reordenar (arrastrar; la primera es la actual y arrastrar otra encima la sustituye), editar (doble toque) y eliminar.

**Tareas completadas**
- R14. Las completadas se guardan en un histórico con su fecha, aunque en esta versión no se muestre. Más adelante se podrá ver y borrar.

**Idiomas**
- R15. Español si el idioma del dispositivo es español (cualquier variante `es-*`); inglés en cualquier otro caso. Se puede cambiar en Configuración. Como la app no tiene conexión, la detección se basa en el **idioma del dispositivo**, no en el país. Todos los textos se externalizan desde el primer día (sin textos incrustados en el código), incluidas fechas y plurales.

> Nota: en mi lista original aparecían "Eliminarla" y "Borrarla" como acciones distintas; considero que son la misma (eliminar sin completar). Si detectas que el prototipo sugiere otra cosa, pregúntame.

---

## 3. El prototipo de diseño

El diseño se ha hecho en Claude Design: https://claude.ai/artifact/CGzh6J5tbnhQgM3J9wPX7q
Si no puedes acceder a esa URL, usa la copia exportada en `design/prototype/` del repositorio. Si tampoco está, pídemela antes de seguir.

El prototipo es la **fuente de verdad visual y de interacción**. Resumen de lo que contiene (verifícalo contra el prototipo):

- **Pantallas (formato 390×844):** Prototipo completo (empieza vacío) · 1 La tarea · 2 Menú · 3 Nueva tarea · 4 ¿Dónde va? · 5 Todas las tareas (con acciones) · 6 Eliminar · 7 Completar (mantener pulsado) · 8 Eliminar (se arruga) · 9 Añadir (+): foto, imagen, archivo o URL · 10 Tarea con documento (abierto) · 11 Tarea web (URL).
- **Estilo:** tareas como notas adhesivas de colores (amarillo `#FFE55C`, rosa `#FF9EC4`, verde `#A6E88F`, azul `#8FD3F4`, naranja `#FFB870`), tinta `#111111`, fondo papel `#F4F1EA`, líneas `#D8D4CA`, error `#B3241A`. Tipografías **Archivo** (500–900) y **Space Mono**. Estética de papel con bordes marcados y hojas inferiores (bottom sheets).
- **Interacciones clave:** animación de bienvenida con el logo "una."; completar manteniendo pulsado con progreso ("Mantén pulsado" → "Sigue pulsando…"); eliminar con efecto de papel arrugado; arrastrar para reordenar; doble toque para editar; hoja "¿Dónde la pones?"; menú con "Nueva tarea / Esta tarea: Editar, Eliminar / Todas mis tareas / Configuración y perfil".
- **Tareas con adjunto:** la tarea web muestra la página "dentro de la tarea"; los documentos se abren "con el visor del teléfono".

**Sistema de diseño:** la identidad visual del prototipo manda. Material 3 (si el stack es Flutter) o shadcn/ui (si es web/React) se usan **solo como base de componentes y accesibilidad**, adaptados con *design tokens* extraídos del prototipo. Crea un fichero de tokens (color, tipografía, espaciado, radios, sombras, movimiento) como única fuente y prepáralo para el futuro *theming*.

**Accesibilidad (obligatoria):** toda acción por gesto (mantener pulsado, arrastrar, doble toque) necesita una alternativa accesible para lectores de pantalla y control por teclado/switch. Respetar "reducir movimiento", tamaños de texto dinámicos, contraste WCAG AA y objetivos táctiles ≥ 44 px.

---

## 4. Metodología: Spec-Driven Development (SDD)

Quiero que el proyecto siga **Spec-Driven Development**: la especificación es el artefacto principal y el código se deriva de ella.

1. Evalúa si conviene usar **GitHub Spec Kit** o una estructura propia más ligera, y justifica tu elección en un ADR.
2. En cualquier caso, el flujo por funcionalidad es: **especificación** (qué y por qué, sin tecnología) → **plan técnico** (cómo) → **tareas** (pequeñas, ordenadas y verificables) → implementación → verificación contra los criterios de aceptación.
3. Crea una **constitución del proyecto** (`specs/constitution.md` o equivalente): principios que no se negocian (una tarea a la vez, local y offline, privacidad por defecto, accesibilidad, tests antes de dar algo por hecho, i18n desde el principio, seguridad).
4. Estructura sugerida: `specs/NNN-nombre/{spec.md, plan.md, tasks.md}`, `docs/adr/`, `docs/`.
5. Cada especificación incluye: historias de usuario, criterios de aceptación Dado/Cuando/Entonces, casos límite, estados de error y vacíos, requisitos de accesibilidad, textos en ambos idiomas y la pantalla del prototipo a la que corresponde.
6. Define la **Definition of Done** común: spec cumplida, tests pasando, revisión de seguridad y accesibilidad, textos traducidos, documentación actualizada.

---

## 5. Decisión de stack tecnológico

Necesito una recomendación razonada, no una preferencia. Compara al menos:

- **A. Flutter** (iOS + Android + build web para pruebas).
- **B. Web (HTML/CSS/JS, p. ej. React + shadcn/ui) empaquetada en app nativa con Capacitor.**
- **C. React Native con Expo** (con salida web).
- **D. PWA pura, sin tienda de apps** (como referencia, aunque sospecho que no llega).

**Criterios** (pondéralos y muestra una matriz):

- Facilidad de desarrollo, mantenimiento y actualización por una persona con ayuda de Claude Code.
- Calidad de las animaciones personalizadas del prototipo (papel arrugado, notas adhesivas, mantener pulsado).
- **Arranque en frío hasta ver la tarea actual** (objetivo orientativo: < 1 s en un móvil de gama media). Es clave para la propuesta de valor 2.
- Visor de imagen a pantalla completa con zoom y desplazamiento (mapas, horarios).
- Visualización de documentos **sin conexión** (PDF como mínimo; Word/Excel: qué es viable).
- Mostrar una URL "dentro de la tarea": en web/PWA la mayoría de sitios bloquean `iframe` (X-Frame-Options/CSP); en nativo se usa WebView. Y **sin conexión una URL no carga**: propón cómo resolverlo (guardar una instantánea, captura o PDF de la página al crearla).
- Almacenamiento local fiable a largo plazo (en iOS, Safari puede borrar datos de webs y PWA), incluidos archivos grandes.
- Posibilidad futura de **widgets de pantalla de inicio o de bloqueo** (iOS/Android): probablemente sea la mejor forma de cumplir la propuesta de valor 2, así que el stack no debe cerrarla.
- Notificaciones locales (futuro "gestión de alertas").
- Poder probar en local y desplegar una versión web de pruebas en **Vercel**, con despliegues de previsualización por pull request.
- Requisitos de mi entorno: ¿hace falta un Mac para compilar iOS? ¿Hay compilación en la nube (p. ej. EAS Build, Codemagic)?
- Madurez del ecosistema, riesgo de abandono de dependencias y coste de actualizar versiones mayores.

**Entregable:** un ADR con la recomendación, alternativas descartadas y motivos, y una lista de **pruebas técnicas (spikes)** para los riesgos principales (visor de documentos offline, URL offline, arranque en frío, animación de arrugado, almacenamiento de archivos) que conviene hacer antes de comprometerse. Las pruebas técnicas son código desechable y no se hacen sin mi aprobación.

---

## 6. Arquitectura preparada para el futuro

La versión 1 es pequeña, pero la arquitectura y el **modelo de datos** deben aceptar sin migraciones dolorosas todo lo de la sección 9. Concretamente:

- **Modelo de datos versionado con migraciones probadas** desde la versión 1.
- **Tarea:** id (UUID, no autoincremental), texto, adjunto opcional, estado (pendiente/completada), orden (un orden que sirva para sincronizar más adelante, p. ej. *fractional indexing*), `createdAt`, `updatedAt`, `completedAt`, y campos futuros previstos: `dueDate` (nulo), `parentId` para subtareas (nulo), origen de importación (`source` + `externalId`).
- **Adjuntos** como entidad propia: tipo, MIME, tamaño, ruta dentro de la app, miniatura e instantánea (para URL). Los archivos se **copian dentro de la app**; nunca se guardan solo referencias a la galería o a archivos externos que pueden desaparecer.
- **Eliminaciones:** decide (y pregúntame si dudas) entre borrado definitivo, papelera o "deshacer" temporal. Ten en cuenta que para sincronizar en el futuro se suelen necesitar marcas de borrado (*tombstones*).
- **Capa de persistencia detrás de una interfaz (repositorio)** para poder añadir sincronización en la nube más adelante sin reescribir la lógica.
- **Ajustes:** idioma, tema, notificaciones.
- **Feature flags** sencillos para funcionalidades a medio hacer.
- **Identificador de la app (bundle ID / package name):** es permanente una vez publicada. Propón uno neutro que no dependa del nombre "Una".
- Presupuesto de rendimiento y de tamaño de la app.

Entrega un diagrama de arquitectura (Mermaid) y el esquema de datos.

---

## 7. Seguridad y privacidad

Actúa como experto/a en ciberseguridad. Usa **OWASP MASVS/MASTG** como referencia y entrega un **modelo de amenazas** (activos, actores, superficies de ataque, mitigaciones) adaptado a una app local sin backend. Como mínimo:

- **Cero red por defecto:** sin analítica, sin informes de errores y sin SDK de terceros que envíen datos. Si alguna vez se añade algo, será opcional y con consentimiento explícito. Objetivo: poder declarar "Data Not Collected" en las tiendas.
- **Datos en reposo:** sandbox del sistema y protección de archivos (iOS Data Protection, almacenamiento privado en Android). Valora en un ADR si merece la pena cifrar la base de datos, y decide la política de **copias de seguridad** (iCloud/Google) con sus implicaciones de privacidad.
- **Permisos mínimos y solo en el momento de usarlos.** Prioriza los selectores del sistema (fotos y archivos), que no necesitan permisos amplios.
- **Archivos importados como no confiables:** validar el tipo por contenido (no solo por la extensión), limitar el tamaño, **eliminar metadatos EXIF/GPS** de las fotos, no ejecutar nunca contenido y tratar SVG y documentos con cuidado.
- **URL:** solo `http`/`https`; bloquear `javascript:`, `data:`, `file:` y similares; normalizar y mostrar el dominio real (atención a homógrafos IDN). WebView endurecida: sin acceso a archivos, sin puentes JS, sesión y cookies aisladas, y enlaces externos abiertos en el navegador del sistema.
- **Cadena de suministro:** lockfiles, versiones fijadas, Dependabot o Renovate, auditoría de dependencias en CI, revisión de licencias y criterio para aceptar dependencias nuevas.
- **Repositorio:** secret scanning con push protection, análisis estático (CodeQL donde el lenguaje lo soporte, o alternativa), ramas protegidas, ningún secreto ni clave de firma en el repo (añádelos a `.gitignore`) y gestión segura de las claves de firma.
- **Versión web en Vercel:** cabeceras de seguridad (CSP estricta, HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors`) y ningún script de terceros.
- **Futuras importaciones (Todoist, Keep, etc.):** parsers robustos ante archivos malformados o maliciosos.
- Una **checklist de seguridad** que forme parte de la Definition of Done y de la revisión de cada PR.

---

## 8. Repositorio, entornos y configuración de Claude Code

### GitHub
Prepara (y crea con `gh` cuando lo apruebe) el repositorio con: README, licencia (pregúntame cuál), `.gitignore`, `.editorconfig`, plantillas de issues y PR, `CONTRIBUTING`, `SECURITY.md`, CODEOWNERS, convención de commits (Conventional Commits), estrategia de ramas, versionado semántico y changelog. Añade **CI con GitHub Actions** (lint, formateo, tests, build, auditoría de dependencias y de seguridad) y protección de la rama principal.

### Entornos de desarrollo y pruebas
- Instrucciones para ejecutar en local: simulador/emulador, dispositivo físico y navegador.
- **Vercel:** despliegue de la versión web, con *preview* por PR y producción desde la rama principal.
- Pruebas en dispositivos reales: TestFlight e Internal Testing de Google Play. Indica qué cuentas y coste implican.
- Estrategia de testing: unitarios (lógica de la cola y el orden), de widgets/componentes, de integración/E2E de los flujos principales, de migraciones de datos, de accesibilidad y pruebas visuales frente al prototipo.

### Configuración de Claude Code para el proyecto
Diseña la configuración para que el desarrollo con Claude Code sea consistente y seguro:
- **`CLAUDE.md`** breve: qué es el proyecto, comandos, convenciones, flujo SDD y qué no hacer.
- **Skills del proyecto** (`.claude/skills/`): propón cuáles crear y para qué. Por ejemplo, crear una spec desde plantilla, implementar una spec paso a paso, escribir un ADR, checklist de seguridad, comprobar i18n, añadir textos traducidos, checklist de release y validación de design tokens. Busca también skills y plugins existentes (oficiales de Anthropic, del stack elegido, de Spec Kit) y evalúalos. **No instales skills, plugins ni servidores MCP de terceros sin revisar antes su contenido y explicarme qué hacen**: también son una superficie de ataque.
- **Subagentes** con un papel claro: revisor de specs, revisor de seguridad, revisor de accesibilidad y escritor de tests.
- **Hooks:** formateo/lint al editar, bloqueo de lectura o escritura de archivos sensibles (claves, `.env`, keystores) y tests antes de commit.
- **Permisos** (`settings.json`) con lo mínimo necesario.
- **MCP:** solo los imprescindibles (GitHub, quizá Vercel), justificados.

---

## 9. Alcance y hoja de ruta

**MVP (versión 1):** todo lo de la sección 2.

**Siguientes versiones (no se desarrollan ahora, pero la arquitectura debe estar preparada):**
- Bloque 1: tareas con fecha límite · vista de "hoy" en la pantalla principal si hay más de una · agrupación por fecha (hoy, mañana, siguientes) en el listado.
- Bloque 2: creación en bloque (varias tareas a la vez) · subtareas.
- Bloque 3: importar desde Todoist, Google Keep, Google Tasks, Microsoft To Do y Any.do (investiga qué formatos de exportación ofrece cada uno sin usar sus APIs en la nube).
- Bloque 4: listado de tareas realizadas · theming · gestión de alertas (notificaciones locales).
- Bloque 5: configuración completa · páginas legales (condiciones, privacidad, cookies) · ayuda.
- **Landing page del producto**, centrada en las dos propuestas de valor. Decide si va en el mismo repositorio (monorepo) o en otro.
- Posibles widgets de pantalla de inicio o bloqueo (ver sección 5).

**Mucho más adelante (si pasa a ser un servicio en la nube):** login, perfil, sincronización automática, asignación de tareas y compartir. No diseñes nada de esto ahora; solo asegúrate de que el modelo de datos y la capa de persistencia no lo impiden.

> Nota: el menú del prototipo dice "Configuración y perfil", pero no hay perfil sin login. Propón cómo tratarlo en la versión 1.

---

## 10. Entregables de esta fase

Cuando hayamos cerrado las preguntas, genera en el repositorio:

1. `docs/PLAN.md`: el plan maestro con fases, hitos, dependencias, orden de implementación, tamaño relativo de cada bloque, criterios para pasar de fase y **registro de riesgos** (probabilidad, impacto y mitigación).
2. `specs/constitution.md` y las specs del MVP (`spec.md` como mínimo; `plan.md` y `tasks.md` para la primera funcionalidad, como ejemplo del flujo).
3. `docs/adr/`: ADRs de stack, almacenamiento, estructura SDD, cifrado/copias de seguridad, eliminación de tareas, URL offline y visor de documentos.
4. `docs/architecture.md` (diagramas Mermaid y modelo de datos).
5. `docs/security/threat-model.md` y la checklist de seguridad.
6. `docs/design/tokens` y la correspondencia entre pantallas del prototipo y specs.
7. `docs/glossary.md` con términos de dominio en español e inglés (tarea actual, cola, completar, eliminar, adjunto…) para que código y textos sean coherentes.
8. Propuesta de `CLAUDE.md`, skills, subagentes, hooks y configuración de CI.
9. Un resumen final para mí: decisiones tomadas, decisiones pendientes y siguiente paso concreto.

---

## 11. Preguntas que debes resolver conmigo (como punto de partida)

Añade las que detectes tú. Algunas que ya veo:

- Mi equipo: ¿tengo Mac con Xcode? ¿Cuentas de Apple Developer y Google Play?
- Repositorio público o privado, y licencia.
- ¿Una tarea puede tener texto **y** adjunto a la vez?
- Eliminar: ¿deshacer, papelera o borrado definitivo?
- Las tareas completadas ¿conservan sus adjuntos (espacio en el teléfono)?
- URL sin conexión: ¿guardamos una instantánea al crearla?
- ¿Qué formatos de documento deben verse dentro de la app y cuáles se abren con el visor del sistema?
- Imagen a pantalla completa: ¿zoom? ¿mantener la pantalla encendida? ¿brillo al máximo (útil para códigos QR)?
- ¿Bloqueo de la app con biometría?
- Versiones mínimas de iOS y Android.
- La versión web ¿es solo para pruebas o también un producto?

---

## Datos que ya te doy (completa o borra antes de enviar)

- Usuario/organización de GitHub: [SVALLEV]
- Sistema operativo de mi ordenador: [macOS 26.6.2 (25G83)]
- ¿Cuenta de Apple Developer / Google Play?: ["Sin cuenta"]
- Dominio previsto para la landing: ["aún no"]
