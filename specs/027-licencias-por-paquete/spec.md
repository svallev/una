# Spec 027: Licencias agrupadas por paquete

- **Estado:** **Aprobada** por el propietario el 2026-11-17 (Q-027-1 resuelta: cabecera exacta; grupos plegados; **plan Aprobado** el 2026-11-17, con la enmienda de CA-027-04 de Q-P-1; antes Borrador; revisión 1 del `spec-reviewer` aplicada el mismo día: 4 bloqueantes, 7 importantes y 6 menores; revisión 2: 5 importantes y 6 menores, aplicados)
- **Reglas de producto:** ninguna de la app. Sirve a **P6** (accesible) y **P4** (la web sigue sin rastreo ni recursos de otro origen); los avisos legales se publican completos y sin alterar por ADR-0026.
- **Pantallas del prototipo:** **sin diseño en el prototipo ni en la maqueta** (DEV-60 cubre las páginas de contenido; esta spec solo cambia cómo se ordena el bloque de avisos de la página de licencias). El propietario lo revisa en el navegador (C-027-1).
- **Decisiones y ADR relacionados:** decisión del propietario del 2026-11-17 («opción 1, agrúpalo por paquete»; la opción de consolidar copyrights queda fuera, §8). ADR-0026 (licencias en la web; la revisión legal sigue siendo punto bloqueante de F6), ADR-0028 (las páginas de contenido, sin más programa que el del idioma).
- **Dependencias:** 023 (CA-023-16 y 19, el archivo de avisos), 025 (CA-025-18, los avisos del código de la web) y 026 (CA-026-10, 12, 13 y 15, la página de licencias), las tres **Implementadas**; **se enmiendan en el §10**. Sin cambios en la app: ni esquema de BD, ni permisos, ni dependencias, ni direcciones de `app/identity.yaml`.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 0. Alcance (decidido por el propietario)

- **[Hecho, 2026-11-17]** La página de licencias (`/licenses`) enseña hoy **todo el archivo de avisos de terceros de seguido**, en un solo bloque: 1,5 MB (la página pesa 1 570 484 bytes). Se **agrupa por paquete**: un grupo plegado por cada cabecera, con su nombre y el número de avisos.
- **[Hecho, 2026-11-17, medido sobre `landing/third-party-notices.txt` con un recuento aparte del analizador]** La parte de avisos (entre `===== BEGIN NOTICES =====` y `===== END NOTICES =====`) tiene **1638 avisos** separados por líneas de exactamente 80 guiones; cada aviso empieza con su **cabecera** (uno o varios nombres de paquete, **uno por línea**), una línea en blanco y el texto. Hay **159 cabeceras distintas**: **89 avisos** (en **69 cabeceras distintas**) la comparten varios paquetes (hasta 18 nombres) y **98 cabeceras tienen un solo aviso**. Los grupos mayores: `icu` 552, `harfbuzz` 142, `vulkan-validation-layers` 102, `libjpeg-turbo` 92, `glslang` 89, `skia` 83, `spirv-tools` 69, `angle` 48, `expat` 47, `glfw` 25, `dart` 23, `freetype2` 17, `swiftshader` 16… Hoy cada cabecera ocupa **un único tramo seguido** del archivo, y los avisos idénticos entre sí son solo el 1 %. Tras `END NOTICES` van **cinco secciones** delimitadas por marcadores (`assets/fonts/archivo/OFL.txt`, `assets/fonts/space_mono/OFL.txt`, `assets/licenses/android.txt`, `assets/licenses/pdfium.txt` y `assets/licenses/sqlite.txt`). Antes de la parte de avisos va un **preámbulo**, que es **todo lo anterior a `===== BEGIN NOTICES =====`** (la cabecera de la compilación, las sumas de comprobación y la lista de 142 componentes entre `BEGIN ENTRIES` y `END ENTRIES`).
- **[Hecho, 2026-11-17]** **El texto legal no cambia ni un carácter.** Se reordena la presentación; no se quita, se resume ni se fusiona nada. Consolidar copyrights repetidos (ahorraría un tercio del peso) **no entra**: queda para la revisión legal de F6 (ADR-0026, `docs/PLAN.md`, fila de F6, punto 6).
- **[Hecho, 2026-11-17]** Los grupos son **desplegables nativos** del navegador: funcionan sin JavaScript y no añaden ningún programa (ADR-0028 sigue como está).
- **[Hecho, 2026-11-17]** El enlace «Ver el archivo de avisos como texto» sigue dando el archivo completo y sin alterar.

**Qué es «el texto publicado».** En esta spec: el preámbulo y la lista de componentes (tal cual), el **texto** de cada aviso (lo que hay entre la línea en blanco que sigue a su cabecera y el salto de línea que precede al siguiente separador o a `END NOTICES`, **con sus espacios y con sus líneas en blanco, también las del principio y las del final**) y el texto de cada sección `assets/…`. **No son texto publicado en la página** (sí siguen en el archivo `.txt`): las líneas de 80 guiones que separan avisos, los marcadores `BEGIN`/`END` de las partes y las líneas de cabecera de cada aviso, que pasan a ser el **nombre del grupo**. Los finales de línea se normalizan a `\n`, como hoy.

## 1. Objetivo

Que quien abre la página de licencias vea qué paquetes de terceros lleva la app y pueda leer los avisos de uno solo, en vez de recorrer más de mil quinientos bloques casi iguales; sin perder ni alterar ningún aviso legal.

## 2. Historias de usuario

- **HU-027-1** Como persona que quiere saber qué paquetes de terceros usa la app, quiero ver una lista corta de grupos (164, de ellos 159 de paquetes y 5 de secciones, en lugar de 1638 avisos seguidos más las secciones), para no recorrer 1,5 MB de texto.
- **HU-027-2** Como persona que busca los avisos de un paquete, quiero abrir su grupo y encontrar juntos todos los avisos que comparten su cabecera, para leerlos sin ruido.
- **HU-027-3** Como persona con lector de pantalla, teclado, texto grande o sin JavaScript, quiero la misma lista y los mismos avisos, y poder saltarme la lista, para no depender de ningún programa ni de un gesto.
- **HU-027-4** Como propietario, quiero que lo publicado sea idéntico al archivo de la compilación y que la web no se rompa en silencio si cambia, para que la revisión legal lea lo mismo que se entrega.

**Trazabilidad HU → CA:** HU-027-1 → CA-027-01, 03 y 08; HU-027-2 → CA-027-01 y 02; HU-027-3 → CA-027-04 y 06; HU-027-4 → CA-027-02, 05, 07 y 09.

## 3. Criterios de aceptación

- **CA-027-01** · Un grupo por cabecera
  - **Dado** la página de licencias construida con un archivo de avisos
  - **Cuando** se abre
  - **Entonces** los avisos de la parte de avisos salen **agrupados**: un grupo por cada cabecera distinta (la lista de nombres de paquete **tal cual la lleva el aviso**; el nombre del grupo los muestra seguidos y separados por «, »). Cada grupo **empieza plegado** y muestra su nombre y **cuántos avisos tiene** («1 aviso» / «N avisos» en español, «1 notice» / «N notices» en inglés). Al abrirlo se ven **todos** sus avisos, **separados visualmente entre sí** (una línea fina del sistema de diseño) para que no se fundan unos con otros, y **en el orden en que están en el archivo**. Los grupos van **en el orden de la primera aparición** de su cabecera. Dos cabeceras no idénticas (por ejemplo `dart` y `dart, perfetto`, o los mismos nombres en otro orden) son **dos grupos**. Los avisos de una misma cabecera están **seguidos** en el archivo (si no, falla la construcción, CA-027-05), así que los grupos siguen el orden del archivo. Cada sección `assets/…` es **un grupo propio**, tras los de paquetes, con su **ruta como nombre** (que hace de cabecera) y con su recuento («1 aviso» / «1 notice»).
  - **Verificable:** test de la construcción con un archivo de prueba (cabeceras repetidas, una compartida por varios paquetes, una con un solo aviso, otro orden de nombres, una sección `assets/…`) y, con el archivo real, que el número de grupos y la suma de sus avisos coinciden con un recuento **independiente del analizador** (partir el cuerpo por las líneas de 80 guiones), sin cifras escritas a mano.

- **CA-027-02** · Sin pérdida
  - **Dado** el archivo de avisos
  - **Cuando** se construye la página
  - **Entonces**, comparando el **texto del DOM** de la página ya construida con el archivo (finales de línea normalizados a `\n`): (a) el conjunto de pares (cabecera, texto) publicados es **igual**, uno a uno, al del archivo: **ningún aviso falta, se repite de más ni cambia un carácter** (los avisos idénticos entre sí se conservan todos); (b) el texto de un aviso se publica **entero, con sus espacios y líneas en blanco**; y (c) **recorriendo los grupos en orden** y reinsertando las cabeceras, los separadores y los marcadores, se **reconstruye el archivo** (desde la parte de avisos) y sale **igual** al original (normalizado). El preámbulo, la lista de componentes y las secciones `assets/…` también salen íntegros.
  - **Verificable:** test con el archivo real y con uno de prueba que hace (a), (b) y (c); falla si un aviso se pierde, se duplica o cambia un carácter. Un texto con `<`, `&` o comillas sale escapado y el DOM da el mismo texto.

- **CA-027-03** · El preámbulo, a la vista y tal cual
  - **Dado** el preámbulo del archivo (la cabecera de la compilación, las sumas de comprobación y la lista de componentes que lleva la app)
  - **Cuando** se abre la página
  - **Entonces** sale **antes de los grupos, tal cual y sin plegar**, como hoy.
  - **Verificable:** test de la construcción (con el archivo real y con el de prueba).

- **CA-027-04** · Sin programa nuevo y con las mismas guardias
  - **Dado** la página de licencias con o sin JavaScript
  - **Cuando** se abre y se pulsa un grupo
  - **Entonces** el grupo se despliega y se pliega **sin ningún programa nuevo**: la página sigue cargando solo el programa de idioma (CA-026-13), sin estilos en línea, con la misma política de contenido (CSP) y sin archivos más que hoy. **Cambiar de idioma no cambia qué grupos están abiertos.** Las guardias que hoy miran el texto de los avisos (CA-023-19: sin rutas de la máquina de compilación; y los huecos de identidad al publicar) **siguen mirando todo el texto de los grupos**.
  - **Verificable:** test de la construcción (recursos y CSP iguales que hoy; ningún `<script>` ni `style=` nuevo; **enmienda del plan, Q-P-1, 2026-11-17:** un `[DATE]` en el **texto** de un aviso sigue sin contar como hueco de identidad, como en la 023, y en el **nombre** de un grupo sí cuenta; una ruta de una carpeta personal (`/Users/`, `/home/` salvo `/home/runner/`, `C:\Users\`) o un carácter de control o de dirección en **cualquier parte** del archivo hace fallar la construcción) y test de `lang.js` (el estado abierto no cambia al cambiar de idioma).

- **CA-027-05** · Falla cerrado
  - **Dado** un archivo de avisos con una estructura que no se reconoce
  - **Cuando** se construye la web
  - **Entonces** la construcción **falla con un mensaje que dice qué y dónde**, y **no** publica una página agrupada a medias ni vuelve al bloque único sin avisar. Son estructura no reconocida: `BEGIN` sin `END`, `END` sin `BEGIN`, partes anidadas, o una ruta de sección repetida; ningún aviso; una **cabecera** no válida (vacía, o con un nombre que lleva espacios); un aviso sin texto; una **cabecera que reaparece lejos de su primer tramo** (los avisos de una cabecera deben estar seguidos); y **cualquier texto que no sea espacio en blanco fuera de una parte reconocida** (entre `BEGIN NOTICES` y el primer aviso, entre `END NOTICES` y la primera sección, entre secciones o tras la última). El separador es **una línea de exactamente 80 guiones, y solo dentro de la parte de avisos**; las demás líneas de guiones son texto. El resto de comprobaciones de la página (CA-023-16 y 19: versión o compilación en la cabecera, sin rutas de la máquina de compilación) siguen igual.
  - **Verificable:** test de la construcción, un caso por cada estructura de esa lista.

- **CA-027-06** · Accesibles
  - **Dado** la página de licencias, en los dos idiomas, con y sin JavaScript
  - **Cuando** se recorre con teclado, con lector de pantalla, con el texto al 200 % y 400 %, con el espaciado de texto aumentado y con los colores forzados del sistema
  - **Entonces** se mantiene **todo** CA-026-10 y CA-026-12, y además: la lista de grupos va en **una región con nombre** (el título «Third-party notices (full text)») y delante hay un **enlace nativo «Saltar la lista de avisos» / «Skip the notices list»** que lleva a un punto **justo después de la lista, dentro del mismo bloque** (no al pie de la página), para no pasar por 164 paradas del teclado; cada grupo se alcanza con el teclado y se abre con **Intro o Espacio**; el lector dice el nombre del grupo, **un solo recuento** (el del idioma elegido; sin JavaScript, los dos, como el resto de textos bilingües de las páginas): los dos recuentos llevan su `lang` y se ocultan con el mismo mecanismo que el resto de textos bilingües (CA-026-09), lo que prueba el test y si está abierto o cerrado; la cabecera de cada grupo mide **44 × 44 o más**; el foco se ve y no queda tapado por la cabecera fija (también al saltar con el enlace); el estado abierto o cerrado no depende solo del color ni de un icono sin nombre y se ve con los colores forzados; **nada se mueve**; los nombres y los avisos salen marcados como inglés (`lang="en"`) y cada recuento, con su idioma; las líneas largas se parten dentro de la columna (no hay desplazamiento horizontal de la página ni de un grupo). **Salvedad aceptada [Suposición]:** los 164 grupos no son encabezados, así que no se navega por ellos con las teclas de encabezados del lector; se llega por la región, la lista y el enlace de saltar.
  - **Verificable:** test de la construcción (región, enlace y su destino, zonas, nombres, `lang` de los dos recuentos, tamaños y reglas de estilo con las excepciones de la 026) y casilla C-027-1 (lo que dice el lector, solo a oído) (Chrome de escritorio y del emulador, teclado, zoom, colores forzados y el marcador de los desplegables en Safari; TalkBack como en la 026).

- **CA-027-07** · El archivo de texto no cambia, y las demás partes de la página tampoco
  - **Dado** la página de licencias y el archivo de avisos publicado
  - **Cuando** se construye la web
  - **Entonces** el enlace «Ver el archivo de avisos como texto» da el archivo **completo y sin alterar, con sus finales de línea originales** (el mismo `third-party-notices.txt` de `landing/`); la explicación, la versión (o el aviso de última compilación), el enlace al archivo y el bloque del **código de la web** (`licensesWebTitle`, CA-025-18) quedan **como están**; y el texto de los avisos sale **una sola vez** (no se repite por idioma, CA-026-12). `/licenses#notices` sigue llevando a los avisos.
  - **Verificable:** test de la construcción (el archivo de `dist/` es el de `landing/`, byte a byte; el HTML fuera del bloque de avisos es igual que el de la construcción anterior a esta spec, con un fragmento de referencia en el test; el destino del enlace de saltar está **dentro** del bloque, así que no cuenta).

- **CA-027-08** · Ligeras
  - **Dado** la página de licencias construida con el archivo actual
  - **Cuando** se mide
  - **Entonces** el HTML pesa **como mucho el texto publicado más 250 KB** sin comprimir (el texto publicado medido sin escapar y en bytes UTF-8) (lo que añaden los grupos, hoy unos 100 KB) **[Suposición]**, y la página no carga ningún archivo más que hoy (CA-026-15).
  - **Verificable:** test de la construcción (tamaño y lista de recursos) con el archivo real; casilla C-027-1 (abrir el grupo mayor, `icu`, en el emulador de Android en menos de 1 s **[Suposición]**).

- **CA-027-09** · Documentación y tests al día
  - **Dado** la spec implementada
  - **Cuando** se cierra
  - **Entonces** están al día: CA-023-16, CA-025-18 y CA-026-12 y las tablas de textos de la 023 y la 026 con su enmienda (§10), el glosario, `docs/design/screen-map.md`, la nota de DEV-60, `docs/security/checklist.md` si el apartado de la web lo nombra, `docs/PLAN.md` y `CLAUDE.md`; la revisión legal (F6) sigue diciendo que consolidar copyrights es decisión suya. Los tests de la 023, la 025 y la 026 que usan un archivo de avisos mínimo (sin marcadores) **se actualizan** a la estructura que ahora se exige, **citando el CA nuevo**, sin borrar lo que siguen protegiendo.
  - **Verificable:** test de la web (las tres claves de §7 están en ES y EN, y los textos coinciden con la tabla de esta spec; cada test nuevo o cambiado cita su CA-027-NN), `spec-reviewer` al cerrar y la CI en verde.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-027-1 | Un paquete aparece en varias cabeceras (`dart`, `dart, perfetto`, `dart, double-conversion`…) | Un grupo por cabecera distinta (CA-027-01). No se juntan los grupos para no inventar una agrupación (Q-027-1). |
| CL-027-2 | Dos avisos son idénticos | Se publican los dos (CA-027-02): no se deduplica nada. |
| CL-027-3 | El texto de un aviso lleva líneas de guiones que **no** son de exactamente 80 (de 70, 75, 81…), o líneas de signos iguales | Se queda dentro de su aviso, entero. Una línea de **exactamente 80 guiones** dentro de la parte de avisos **es** un separador (así lo hace Flutter y `check-licenses.sh`); hoy no hay ninguna dentro de un texto. |
| CL-027-4 | La cabecera nombra muchos paquetes (hoy hasta 18) | El nombre del grupo se ve entero, partido en varias líneas si hace falta; no se recorta con puntos suspensivos. |
| CL-027-5 | Un aviso no tiene cabecera válida (nada antes de la línea en blanco, o un nombre con espacios) | Falla la construcción (CA-027-05); no existe un grupo «sin paquete». Hoy no hay ninguno. |
| CL-027-6 | El archivo de otra compilación cambia de tamaño o de paquetes | Se agrupa igual; no hay una lista de paquetes escrita a mano en la web. |
| CL-027-7 | Se usa «Buscar en la página» del navegador | Con los grupos plegados, el navegador abre el grupo donde está la coincidencia **[Suposición, depende del navegador]**; el archivo de texto completo sigue disponible. |
| CL-027-8 | El navegador no admite desplegables nativos | Todos los grupos se ven abiertos y el contenido se lee entero **[Suposición]**. |
| CL-027-9 | Se imprime la página | Sin hoja de impresión cuidada **[Suposición]**; el archivo de texto es la vía para imprimirlo entero. |
| CL-027-10 | El sistema está en modo oscuro | La página no cambia: siempre en claro (CL-026-10). |
| CL-027-11 | Un grupo con un solo aviso (hoy 98 de 159) | Se muestra como los demás, con «1 aviso» / «1 notice». |
| CL-027-12 | El texto lleva `\r`, `<`, `&` o caracteres especiales | Los finales de línea se normalizan a `\n` (como hoy); el resto sale escapado y el texto del DOM es el original (CA-027-02). |
| CL-027-13 | Una sección `assets/…` se repite o su marcador no cierra | Falla la construcción (CA-027-05). Que falte una sección no se puede detectar sin una lista escrita a mano (CL-027-6): no es un error. |
| CL-027-14 | Se abre un grupo con 552 avisos en un móvil modesto | Se abre en menos de 1 s en el emulador **[Suposición]**; se comprueba en C-027-1 (CA-027-08). |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| El archivo no se reconoce | Al construir | Nada publicado: falla la construcción con el motivo (CA-027-05). |

## 6. Accesibilidad

Ver CA-027-06. Cada grupo es un control nativo (teclado: Intro o Espacio; lector: nombre, recuento y estado), sin alternativa a ningún gesto porque no hay gestos; el enlace de saltar evita 164 paradas del teclado; sin animación; el texto al 200 % y el espaciado aumentado no cortan nada; los colores forzados mantienen el estado visible.

## 7. Textos (ES / EN)

Los textos de los avisos y los nombres de paquete **no se traducen** (inglés, `lang="en"`). Tres claves nuevas en `landing/src/strings.json` (sin sintaxis ICU: la web no la usa; el plural son dos textos y `{n}` es el marcador):

| Clave | ES | EN | Notas |
|---|---|---|---|
| `webNoticesCountOne` | 1 aviso | 1 notice | Recuento de un grupo con un aviso. |
| `webNoticesCountMany` | {n} avisos | {n} notices | Recuento de un grupo con varios; `{n}` es el número. |
| `webNoticesSkip` | Saltar la lista de avisos | Skip the notices list | Enlace nativo al pie (CA-027-06). |

## 8. Fuera de alcance

- **Consolidar** los copyrights repetidos bajo un solo texto de licencia, o quitar texto: lo decide la revisión legal de F6 (ADR-0026). Esta spec no cambia el contenido legal.
- **Cambiar** el archivo de avisos, su cabecera, el trabajo de publicación o `tools/check-licenses.sh`.
- Botones de **«Abrir todos» / «Cerrar todos»** o buscador propio (necesitarían un programa; el archivo de texto sirve para leerlo entero).
- **Anclas por paquete** y enlaces que abran un grupo concreto (solo `/licenses#notices`, que ya existe).
- Convertir los grupos en **encabezados** o en un índice de letras.
- La página de licencias **dentro de la app** (no existe desde la 015, ADR-0026).
- La landing, la política, la Ayuda y la página de error.

## 9. Preguntas abiertas

- **[Hecho, Q-027-1 resuelta por el propietario el 2026-11-17: «por cabecera exacta»; los grupos empiezan todos plegados]** El agrupado es por **cabecera exacta**, no por paquete suelto: 69 cabeceras comparten varios paquetes (por ejemplo `async, cli_util, collection, mime, stream_channel, typed_data`), y el mismo paquete (`dart`, `icu`…) aparece en varias cabeceras. Agrupar «por paquete» de verdad obligaría a **repetir** un aviso bajo cada uno de sus paquetes (duplica texto legal, contra CA-027-02). **Recomendación: cabecera exacta** (lo supuesto aquí). ¿Es lo que querías al decir «por paquete»? (Los grupos empiezan todos plegados, CA-027-01 **[Suposición]**: con 164 grupos, abrir uno solo no ahorra nada.)
- **[Pendiente, plan]** Cómo se reconoce la estructura del archivo (partes, cabeceras y secciones `assets/…`) sin listas escritas a mano y cómo se carga el marcador `{n}` de las claves nuevas; cómo se garantiza CA-027-02; cómo se separan visualmente los avisos de un grupo y cómo entra el recuento bilingüe sin que el programa de idioma escriba texto.

## 10. Enmiendas

Se anotan al aprobar esta spec como «Enmienda (spec 027, Aprobada; en vigor cuando la 027 se implemente)».

| Spec | Criterio | Qué cambia |
|---|---|---|
| 023 | CA-023-16 | La página publica el archivo de avisos **agrupado por cabecera** (CA-027-01 a 03); el archivo de texto sigue entero (CA-027-07). |
| 023 | §7 (textos) | Claves nuevas `webNoticesCountOne`, `webNoticesCountMany` y `webNoticesSkip` (§7 de esta spec). |
| 025 | CA-025-18 | Sin cambios de contenido; el bloque del código de la web queda como está (CA-027-07). |
| 026 | CA-026-12 | Los avisos salen una sola vez, en inglés, **en grupos plegados** por cabecera; las líneas largas se siguen partiendo (CA-027-06). |
| 026 | §7 (textos) | Las tres claves de arriba, que la página de licencias usa. |
| 026 | DEV-60 | Nota: la página de licencias agrupa los avisos en desplegables (CA-027-01). |
