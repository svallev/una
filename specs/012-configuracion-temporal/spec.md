# Spec 012: Pantalla temporal de "Configuración y perfil" (licencias y privacidad)

- **Estado:** **Aprobada** (propietario, 2026-09-30). Revisada por `spec-reviewer` el 2026-09-30 con los hallazgos aplicados
- **Alcance (propietario, 2026-09-30):** pantalla **temporal**, "para que esté en algún sitio". Solo dos opciones: las licencias de código abierto y la política de privacidad. La Configuración completa llegará en una fase posterior, con diseño del propietario y alguna funcionalidad nueva. **Esto cambia el alcance de la beta** ("sin pantalla de Configuración", 2026-09-29): solo en lo que aquí se dice
- **Reglas de producto:** R15 solo en CA-012-07 (idioma). Cubre parte de D13 (aplazada) y el requisito de publicación de las licencias (`docs/PLAN.md`, F5). Desarrolla P4 (privacidad), P6 y P7
- **Pantallas del prototipo:** **ninguna: sin diseño** (`docs/design/screen-map.md`). Se hace con los tokens y componentes existentes y se registra como DEV-49 (temporal)
- **Decisiones y ADR relacionados:** D13 (aplazada), D17; DEV-18
- **Dependencias:** 005 (menú), 008 (confirmación de enlaces, CA-008-12), 009 (CA-009-07 y CA-009-13), 010 (idioma), 011 (**aprobada**; esta spec le añade filas a la matriz de CA-011-02)
- **Enmiendas a otras specs (al aprobar esta):** 005 CA-005-09 y 010 CL-010-7 (ya no es solo texto), 010 CA-010-07 y CA-010-12 (las pantallas que se recorren incluyen estas), 010 §6 ("no es un botón"), 011 CA-011-02 (filas nuevas, ya aplicadas), DEV-18, CLAUDE.md y la memoria del proyecto ("sin pantalla de Configuración en la beta")

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y las notas técnicas, solo en el anexo (no normativo).

## 1. Objetivo

Que la app tenga, mientras no exista la Configuración completa, **un sitio donde ver las licencias de lo que usa y la política de privacidad**, alcanzable desde el menú. Es lo mínimo para poder enseñar la app con esos dos requisitos cubiertos; no es la pantalla definitiva.

## 2. Historias de usuario

- **HU-012-1** Como usuario, quiero poder leer con qué software de código abierto está hecha la app, para conocer sus licencias.
- **HU-012-2** Como usuario, quiero poder leer la política de privacidad, para saber qué hace la app con mis datos.
- **HU-012-3** Como usuario de TalkBack, teclado o conmutadores, quiero llegar, leer y salir de esta pantalla sin gestos que no pueda hacer (CA-012-11 a 13).

## 3. Criterios de aceptación

**Niveles y controles.** Hay tres niveles. Todos se cierran hacia atrás de uno en uno; solo el primero tiene el icono de cerrar.

| Nivel | Qué es | Controles visibles | Atrás del sistema, gesto de atrás y Escape | Foco al llegar | Foco al volver |
|---|---|---|---|---|---|
| 1 | "Configuración y perfil" (dos opciones) | Icono **Cerrar** | Cierra y vuelve al **menú tal como estaba** | El título | "Configuración y perfil", en el menú |
| 2 | Lista de licencias | **Volver** | Vuelve al nivel 1 | El título | La opción "Licencias de código abierto" |
| 3 | Texto de una licencia | **Volver** | Vuelve al nivel 2 | El título de esa licencia | La fila tocada |

- **CA-012-01 Abrir la pantalla**
  - **Dado** el menú abierto (CA-005-01)
  - **Cuando** el usuario toca "Configuración y perfil"
  - **Entonces** se abre el nivel 1, **a pantalla completa**, con, arriba, el título "Configuración y perfil" y el icono de cerrar, y debajo **dos opciones**: "Licencias de código abierto" y "Política de privacidad". "Configuración y perfil" **pasa a ser un botón** (rol de botón para el lector; enmienda de CA-005-09 y CL-010-7), con un objetivo táctil de **≥ 44 pt** como las demás filas del menú. Se abre desde el menú de cualquier tarea: solo texto, con imagen, con PDF y con web.
- **CA-012-02 Cerrar y volver** *(propietario, 2026-09-30, P-012-1)*
  - **Dado** cualquiera de los tres niveles
  - **Cuando** el usuario usa el control de la tabla o el atrás del sistema, el gesto de atrás o Escape con teclado
  - **Entonces** se sube **un nivel** y, desde el nivel 1, se **vuelve al menú tal como estaba**. El foco va donde dice la tabla. No hay otro gesto que cierre la pantalla.
- **CA-012-03 Licencias de código abierto**
  - **Dado** el nivel 1
  - **Cuando** el usuario elige "Licencias de código abierto"
  - **Entonces** se abre el nivel 2 con **la lista de todo lo de terceros que va dentro de la app**, con el nombre de cada uno y cuántos textos de licencia distintos tiene. Al tocar uno se abre el nivel 3, con el **texto completo de su licencia**, con desplazamiento vertical. Si un elemento tiene varias licencias, se ven todas seguidas, cada una con su título.
  - **Completa (verificable):**
    - cada **paquete Dart de la compilación *release*** (sin los de desarrollo);
    - cada **fuente empaquetada**;
    - y cada **biblioteca nativa de terceros** que va en el paquete de la app (`.so` de cada arquitectura, p. ej. PDFium y SQLite)
    tiene su licencia en la lista. Un test enumera cada una de esas tres clases y falla si alguna no aparece.
  - **El motor de Flutter y las bibliotecas de Android** *(propietario, 2026-09-30, P-012-3)*: el motor ya viene en la lista de Flutter; las bibliotecas de Android (AndroidX, Kotlin) no, y **entran** como una entrada propia, "Bibliotecas de Android (AndroidX, Kotlin)", con su licencia y la lista de bibliotecas. El test también la comprueba.
  - **Paquetes de desarrollo** *(propietario, 2026-09-30)*: la lista de Flutter trae también algunos que no van en la app; **se muestran tal cual** (sobra algo, no falta nada). El test solo exige los de *release*.
  - Los textos de las licencias son **contenido de terceros, en inglés** (como el texto del usuario y las páginas web en CA-010-07: fuera de P7); el resto de la pantalla, en el idioma de la app.
  - **Los textos de licencia no llevan enlaces activos**: las direcciones que contienen son texto plano (P4, ADR-0018).
- **CA-012-04 Política de privacidad**
  - **Dado** el nivel 1
  - **Cuando** el usuario elige "Política de privacidad"
  - **Entonces**, **antes** de preguntar, se comprueba que hay una app que pueda abrir la dirección:
    - si la hay, aparece la **confirmación de enlace** de la spec 008 (CA-008-12), "¿Abrir {host} en el navegador?", con el dominio real; solo si el usuario confirma, se abre la página en el **navegador del sistema**; si cancela, no pasa nada y el foco vuelve a "Política de privacidad";
    - si no la hay, se ve, **bajo las opciones**, "No hay ninguna app para abrir este enlace." (CA-008-12), que se anuncia una vez y no mueve el foco.
  - **La app no se conecta a nada por sí misma** (P4): quien lo hace es el navegador. La política no se ve dentro de la app ni pasa por la vista web de la tarea (ADR-0018 no aplica).
  - La dirección es **una sola**, la misma en español y en inglés (propietario, 2026-09-30, P-012-2); la web elegirá el idioma.
  - **Solo se abren direcciones `https`.** Si la configurada no lo es, no se abre nada y se ve el mismo aviso de "No hay ninguna app…".
- **CA-012-05 Enlace falso de momento y puerta de publicación (propietario, 2026-09-30)**
  - **Dado** que la web de la política **aún no existe**
  - **Cuando** el usuario elige "Política de privacidad" en esta versión
  - **Entonces** la confirmación y el navegador usan una **dirección marcador** (**[Suposición]** `https://example.com/…`, un dominio reservado para ejemplos). Se cambia por la definitiva cuando exista la web (PD-2).
  - **Puerta de publicación:** una comprobación **automática** (un script que se ejecuta en la lista de publicación y en el trabajo de CI que genere el artefacto de publicación, cuando exista en F6) **falla** si la dirección no es `https`, si su dominio es el marcador o cualquier dominio reservado, o si la política publicada sigue con huecos (`[NOMBRE DE LA APP]`, `[FECHA]`, `[RESPONSABLE]`, `[CONTACTO]`). Con una compilación de desarrollo o local no falla: el marcador es normal mientras se desarrolla. **[Suposición]** Hasta que exista ese trabajo de CI, la puerta se aplica a mano en la lista de publicación.
  - `/release-checklist` incluye ese punto (se añade al implementar) y que la dirección coincide con la de la ficha de la tienda.
- **CA-012-06 Volver desde el navegador**
  - **Dado** que el usuario abrió la política en el navegador
  - **Cuando** vuelve a la app **y la app sigue viva**
  - **Entonces** aplica CA-001-12: con menos de 10 minutos ve la misma pantalla (el nivel 1 abierto); con 10 minutos o más, la tarea actual. Si el sistema cerró la app entretanto, se ve la tarea actual (CL-012-11).
- **CA-012-07 Idioma**
  - **Dado** cualquiera de los tres niveles abierto
  - **Cuando** el usuario cambia el idioma del sistema y vuelve (CA-010-06)
  - **Entonces** los textos de la app cambian de idioma sin cerrar la pantalla, y el lector los dice en el idioma nuevo. El texto de las licencias no cambia. Los nodos del texto de una licencia se marcan como **inglés** para el lector, de modo que no se lean con la voz española (CA-010-10; **[Suposición]** se comprueba a oído).
- **CA-012-08 Sin datos, permisos ni ajustes nuevos**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior
  - **Entonces** no hay permisos nuevos (INTERNET ya lo usa la tarea web), `schemaVersion` no cambia, no se guarda nada de esta pantalla, no hay analítica ni conexiones nuevas hechas por la app y las dependencias no cambian, salvo lo que haga falta para CA-012-03 (con su justificación en la PR).
- **CA-012-09 "Recientes" (spec 011)**
  - **Dado** cada pantalla nueva: nivel 1, nivel 2, nivel 3 y la confirmación de enlace
  - **Cuando** se aplica la prueba de CA-011-01 (con la matriz de CA-011-02, ampliada con estas cuatro filas)
  - **Entonces** "Recientes" no muestra nada de ellas.
- **CA-012-10 Diseño con lo que hay**
  - **Dado** que no hay prototipo
  - **Cuando** se implementa
  - **Entonces** solo usa tokens y componentes existentes (`validate-tokens` sin hallazgos nuevos), sin valores visuales nuevos, y se registra como DEV-49 (temporal).
- **CA-012-11 Lector de pantalla**
  - **Dado** TalkBack activo
  - **Cuando** se recorre cada nivel
  - **Entonces**:
    - el título es un **encabezado** y es lo primero que se lee (foco al llegar, tabla);
    - el icono se anuncia "Cerrar" y "Volver" en los otros niveles;
    - cada opción es un botón, y "Política de privacidad" añade que **abre una página web en el navegador** (`settingsPrivacyHint`);
    - cada fila de la lista dice el nombre del elemento y cuántas licencias tiene (p. ej., "pdfrx, 1 licencia");
    - el texto de una licencia se divide en **párrafos** navegables, con el título de la licencia como encabezado;
    - el foco al volver es el de la tabla;
    - el aviso de "No hay ninguna app…" se anuncia una vez.
- **CA-012-12 Teclado y conmutadores**
  - **Dado** teclado físico o Switch Access
  - **Cuando** se recorre y se activa
  - **Entonces** el orden de foco es cerrar (o Volver) → título → opciones o filas; se ve el anillo de foco; Intro activa; Escape sube un nivel; todo se puede hacer sin arrastrar ni pellizcar.
- **CA-012-13 Texto grande y movimiento**
  - **Dado** el texto del sistema al 200 %, en móviles de 360 dp de ancho, **en español y en inglés** (CA-010-12), y "reducir movimiento" activo o no
  - **Cuando** se muestran los tres niveles y el aviso de error
  - **Entonces** no hay cortes, solapes ni desbordamientos; los objetivos son ≥ 44 pt; y la apertura es un fundido de **≤ 160 ms**, o ninguna animación con "reducir movimiento".
- **CA-012-14 La tarea de debajo no cambia (CA-009-07, CA-009-13)**
  - **Dado** una tarea con web, con PDF o con imagen, con el menú abierto
  - **Cuando** se abre esta pantalla y se vuelve (o se abre la política en el navegador y se vuelve en menos de 10 minutos)
  - **Entonces** el PDF conserva su página y su zoom, y la imagen no cambia. La página web **se vuelve a cargar al volver**, como tras el editor o el listado (CA-009-07, CA-009-13): esta pantalla tapa la tarea y eso cuenta como salir de la página. *(Enmienda del propietario, 2026-09-30: el plan comprobó que la ruta a pantalla completa cuenta como "salir de la página"; se acepta la recarga en lugar de mantener la vista web viva debajo.)*
- **CA-012-15 Estados de carga y error de las licencias**
  - **Dado** el nivel 1
  - **Cuando** se abre el nivel 2
  - **Entonces** el nivel aparece en **< 300 ms** con "Cargando licencias…" (anunciado); la lista completa aparece en cuanto se lee; y al desplazar, el p90 de los fotogramas es ≤ 16,7 ms (como CA-006-20). Si falla la lectura: "No se pudieron cargar las licencias." con "Reintentar", que recibe el foco.
- **CA-012-16 El arranque no empeora (P2)**
  - **Dado** la compilación *release*
  - **Cuando** se mide el arranque en frío como en CA-011-05
  - **Entonces** no empeora: no se lee ninguna licencia antes del primer fotograma; solo al abrir el nivel 2.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-012-1 | Se abre desde una tarea con web o PDF | Igual (CA-012-14) |
| CL-012-2 | Doble toque rápido en "Configuración y perfil" o en una opción | Se abre una sola vez |
| CL-012-3 | Se gira el móvil con esta pantalla abierta | Se queda en vertical: solo gira la tarea actual con imagen o PDF (D10). Si se vuelve del navegador con el móvil en horizontal, vale lo que ya hace la app (sin menú en horizontal): se aplica CA-012-06 al volver |
| CL-012-4 | Una licencia con un texto muy largo | Se lee entero con desplazamiento; sin cortes |
| CL-012-5 | Muchos paquetes (varias decenas) | Se cumple CA-012-15 |
| CL-012-6 | No se pueden leer las licencias | Ver CA-012-15. El resto de la pantalla sigue funcionando; no se cierra la app |
| CL-012-7 | Sin conexión al abrir la política | La app no lo nota: el navegador enseña su propio error |
| CL-012-8 | La dirección configurada no es `https` | Ver CA-012-04 (no se abre nada, aviso). La puerta de CA-012-05 impide publicarlo |
| CL-012-9 | Se completa o elimina la tarea con esta pantalla abierta | No se puede: la pantalla tapa el menú. Nada cambia al volver |
| CL-012-10 | Un paquete sin texto de licencia legible | Aparece en la lista con "1 licencia" y un texto de error en su nivel 3; el test de CA-012-03 falla si falta de verdad |
| CL-012-11 | El sistema cierra la app con la pantalla abierta (p. ej., mientras se ve el navegador) | Arranque normal a la tarea actual: **esta pantalla no se restaura** (tampoco el menú), como CL-007-7 y CL-011-3 |
| CL-012-12 | Un texto de licencia trae direcciones web | Son texto plano, no se pueden activar (CA-012-03) |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin app para abrir el enlace | No hay navegador, o la dirección no es `https` | "No hay ninguna app para abrir este enlace." bajo las opciones |
| Cargando | Se abre el nivel 2 | "Cargando licencias…" |
| Error al leer las licencias | CL-012-6 | "No se pudieron cargar las licencias." y "Reintentar" |
| Vacío de licencias | No debe ocurrir | Se trata como el error anterior (con test) |

## 6. Accesibilidad

Los criterios están en CA-012-11 a 13. Además:

- Sin gestos: todo son toques; el atrás del sistema equivale a Volver o Cerrar.
- Contraste: solo con colores de los tokens (`validate-tokens`).
- Se revisa con el subagente `a11y-reviewer` antes de aprobar el plan, y con TalkBack en el emulador al implementar. Entra en la auditoría de accesibilidad de F5 (spec 016 futura).

## 7. Textos (ES / EN)

Claves nuevas (camelCase; se añaden con `/strings-add`). Se reutilizan `menuSettings` ("Configuración y perfil" / "Settings and profile"), `linkConfirmOpen`, `linkConfirmCancel`, la confirmación "¿Abrir {host} en el navegador?" y el aviso "No hay ninguna app para abrir este enlace." de la spec 008 (el plan indica sus claves reales), y `retry`.

| Clave | ES | EN | Notas |
|---|---|---|---|
| `settingsClose` | Cerrar | Close | Icono del nivel 1. **[Plan]** ya existe `attachSheetClose` con el mismo texto: unificar o justificar |
| `settingsLicenses` | Licencias de código abierto | Open-source licenses | Opción |
| `settingsPrivacy` | Política de privacidad | Privacy policy | Opción |
| `settingsPrivacyHint` | Abre una página web en el navegador | Opens a web page in the browser | Pista del lector |
| `licensesTitle` | Licencias de código abierto | Open-source licenses | Encabezado del nivel 2 |
| `licensesLoading` | Cargando licencias… | Loading licenses… | Se anuncia |
| `licensesCount` | {count, plural, one{1 licencia} other{{count} licencias}} | {count, plural, one{1 license} other{{count} licenses}} | Bajo el nombre del elemento (CA-010-04) |
| `licensesBack` | Volver | Back | Niveles 2 y 3 |
| `licensesError` | No se pudieron cargar las licencias. | Couldn't load the licenses. | CA-012-15 |

## 8. Fuera de alcance

- La **Configuración completa** (fase posterior, diseño del propietario): selector de idioma, "Mantener la pantalla encendida", textos de copias de seguridad, versión ("Acerca de"), ayuda. Sustituirá a esta pantalla.
- **Alojar la web de la política** y el dominio (PD-2). Aquí solo hay un enlace marcador.
- El **texto definitivo de la política**: hay un borrador en `docs/legal/privacy-policy.md`, que se revisa y adapta más adelante.
- Ver la política dentro de la app, sin conexión: decidido que **abre una web** (2026-09-30).
- Buscar o filtrar en la lista de licencias; enlaces activos en los textos.
- iOS (D17).

## 9. Preguntas abiertas

- **P-012-1 [Resuelta, propietario, 2026-09-30]:** al cerrar se vuelve al menú tal como estaba (CA-012-02).
- **P-012-2 [Resuelta, propietario, 2026-09-30]:** una sola dirección para los dos idiomas (por ahora, el marcador).
- **P-012-3 [Resuelta, propietario, 2026-09-30]:** el motor ya está en la lista de Flutter; las bibliotecas de Android entran como una entrada propia (CA-012-03).
- **P-012-4 [Pendiente, propietario, más adelante]:** los huecos del borrador de la política (responsable, contacto y fecha, y dónde se aloja la web), que dependen de PD-2 y PD-3.

## Anexo: notas para `plan.md` (no normativas)

- El menú es la hoja de la spec 005; "Configuración y perfil" es hoy un texto sin acción (`menuSettings`, CA-005-09, CL-010-7): pasa a botón y abre una ruta a pantalla completa, no una hoja.
- La lista de licencias puede apoyarse en el registro de licencias de Flutter (`LicenseRegistry`): `bundled_licenses.dart` ya añade las OFL de Archivo y Space Mono. La pantalla de Flutter (`LicensePage`) es de Material y no usa los tokens; se hace propia (P12). PDFium (`libpdfium.so`, en tres arquitecturas, `tools/pdfium.lock`; BSD-3 más los avisos de sus terceros) y SQLite (binario que descarga el paquete `sqlite3`) **no** pasan por `LicenseRegistry`: hay que añadirlos como las fuentes. `pubspec.lock` mezcla dependencias de desarrollo; el test las filtra. Los `.so` se enumeran del APK *release*.
- La confirmación y la apertura del navegador ya existen (spec 008: canal `una/links`, `NativeLinkOpener`, hoja de confirmación): se reutilizan, sin canal nuevo. La comprobación de "hay app que lo abra" está en ese canal (`resolveActivity`), pero solo dentro de `open`: el plan añade al mismo canal un método para comprobarlo antes de la confirmación.
- La dirección de la política debería ir junto a la identidad (`app/identity.yaml` → `AppIdentity`, P7) o en un archivo de configuración propio. La puerta de CA-012-05 es un script tipo `tools/check-android-permissions.sh` (p. ej. `tools/check-release-config.sh`), que también busca los huecos en el texto de la política.
- **Puerta de publicación y compilaciones locales:** el script **no** se ejecuta en las compilaciones *release* locales (medir el arranque, probar en el Xiaomi); solo en la lista de publicación y en el trabajo de CI que genere el artefacto de publicación.
- Documentos a actualizar al implementar: `docs/design/prototype-deviations.md` (DEV-18 y DEV-49), `screen-map.md`, `architecture.md`, `security/checklist.md`, `glossary.md`, specs 005, 010 y 011, `.claude/skills/release-checklist/SKILL.md` (punto de la puerta), CLAUDE.md y la memoria "beta congelada".
