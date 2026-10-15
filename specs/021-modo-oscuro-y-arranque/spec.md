# Spec 021: Modo oscuro y arranque

- **Estado:** **Implementada parcialmente** el 2026-10-15 (T-021-01 a 09 en la rama `feat/021-modo-oscuro-y-arranque`; las casillas de dispositivo que faltan van a la 022, en `docs/PLAN.md` «Casillas de la 021»). Antes **Aprobada** por el propietario el 2026-10-15 («sí, aprobado»). Antes Borrador (2026-10-15). Alcance decidido por el propietario el 2026-10-15 (Q-021-1 a 4, §9). Revisada por `spec-reviewer` (2026-10-15: 3 bloqueantes y 6 medios, aplicados; Q-021-5 a 7 resueltas por el propietario el mismo día). **Enmendada al aprobar el plan** (propietario, 2026-10-15): Q-021-7 revocada (CL-021-8: la app tampoco se deja oscurecer por el ajuste de accesibilidad) y precisión de la excepción de Android 8.0 en CA-021-09 (P-021-1 y P-021-2 de `plan.md`).
- **Fase:** F5 Endurecimiento (troceado de F5, D30). Segunda de las specs 020–023, después de la 020 (Implementada el 2026-10-14). Tamaño **S**.
- **Reglas de producto:** R8 (abrir → tarea actual rápido: el arranque es lo primero que se ve), R20 (icono, D29: la «u.» del arranque es la del icono), **propuesta de valor 2** (instantáneo al abrir).
- **Pantallas del prototipo:** **sin diseño**. El prototipo no define ni el arranque ni un modo oscuro: todos sus tableros son claros, sobre `paper`. La «u.» sale del tablero 17 (`Icono.dc.html`), ya hecha en la 018. Lo que se decide aquí se registra como **DEV-57** (`docs/design/prototype-deviations.md`).
- **Decisiones y ADR relacionados:**
  - **Troceado de F5** (propietario, 2026-10-01; renumerado el 2026-10-04, D30): «021 modo oscuro y arranque (más el fondo de arranque coherente con el icono de la 018)».
  - **Arranque en negro aplazado a F5** (propietario, 2026-09-30, auditoría de la 011): con el sistema en modo oscuro, el arranque en frío es **negro ≈ 0,5 s**. Mitigación prevista: usar `paper` en el fondo del arranque (`docs/architecture.md` §2, «Splash nativo»).
  - **Nota de la 018 para la 021** (`docs/PLAN.md`, «Casillas de la 018»; `specs/018-iconos/spec.md` §9): el *splash* de Android 12+ pinta hoy el primer plano del icono (la «u.» negra) sobre el fondo del sistema: blanco en claro y, en oscuro, una ventana negra con un círculo amarillo que añade el sistema. Si se quiere otro fondo, lo fija esta spec.
  - **ADR-0019** (spec 011): el **fotograma blanco al volver a la app** sin instantánea lo pinta el sistema, es igual en claro y en oscuro y está aceptado. Esta spec no lo quita (Q-021-4), pero, al cambiar el fondo del arranque y de la ventana, exige que no empeore (CA-021-12): blanco o `paper`, nunca negro. Que pase a `paper` está aceptado y anotado como enmienda de CA-011-03 y del ADR-0019 (Q-021-6).
  - **D12** (Android 8 / API 26 como mínimo), **D17** (Android primero; iOS en F-iOS), **D28** (solo móvil).
  - **P2** (instantáneo al abrir), **P6** (contraste AA), **P11** (sin dependencias), **P12** (el prototipo y sus tokens mandan: la identidad de papel no tiene versión oscura).
  - Sin ADR nuevo y sin subir la constitución (sigue la 1.10): no hay excepción a ningún principio. ~~CL-021-8 respeta el ajuste de accesibilidad, Q-021-7~~ (enmienda del 2026-10-15: la app no se deja oscurecer por él; ningún criterio de WCAG 2.2 AA exige seguir el modo oscuro del sistema, así que no es una excepción a P6). **[Suposición]** Si el plan necesitara una dependencia (por ejemplo, para el *splash*), haría falta un ADR; no se espera.
  - Modelo de amenazas (`docs/security/threat-model.md`): sin riesgo nuevo. No hay datos, permisos ni red nuevos. Lo único que cambia en la tarea web es el esquema de color que se le pide a la página (CA-021-08).
- **Dependencias:** 018 (icono: la «u.» del arranque), 009 (tarea web), 011 (vuelta a la app: CA-021-12 no debe empeorarla). **Sin esquema de BD, sin permisos, sin dependencias y sin textos nuevos.**
- **Nomenclatura** (se añade al glosario):
  - **Modo oscuro (del sistema):** el ajuste del móvil que pone las apps y el sistema en colores oscuros, puesto a mano, a una hora programada o por el ahorro de batería. **La app no tiene modo oscuro**: se ve siempre en claro.
  - **Arranque** (*launch screen*): lo que se ve desde que se toca el icono (o la notificación) hasta el **primer fotograma** de la app. En Android 12+ lo pinta el sistema (su *splash*, con un icono). En Android 8–11 es un fondo liso.
  - **Fondo de la ventana:** el color que el sistema pinta detrás de la app cuando todavía no hay nada dibujado encima: durante el arranque y en los instantes en que la app se vuelve a dibujar (al girar, al aparecer el teclado o al cambiar el tamaño de la ventana).
  - **Barras del sistema:** la barra de estado (hora, batería, notificaciones) y la de navegación (gestos o botones), que el sistema dibuja encima o al lado de la app.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que la app **se vea igual con el sistema en claro y en oscuro**: siempre clara, con su identidad de papel. Que **el arranque ya sea la app**: fondo `paper` y la «u.» negra del icono, en lugar del blanco o el negro del sistema. Y que nada de lo que el sistema pinta alrededor de la app (barras, fondo de la ventana, páginas web) cambie de aspecto o deje de leerse cuando el sistema está en oscuro.

## 2. Historias de usuario

- **HU-021-1** Como usuario con el móvil en modo oscuro, quiero que al abrir la app no me salte a la cara medio segundo de **negro** y después el papel claro, para que abrir la tarea sea un paso tranquilo y reconocible.
- **HU-021-2** Como usuario, quiero que el arranque **ya tenga el aspecto de la app** (el papel y la «u.» del icono), para saber que estoy abriendo la app correcta antes de ver la tarea.
- **HU-021-3** Como usuario con el modo oscuro programado o puesto por el ahorro de batería, quiero que la app **no cambie de aspecto** a mitad de uso ni pierda lo que estoy haciendo.
- **HU-021-4** Como usuario, quiero **leer la hora, la batería y los iconos de las barras del sistema** con la app abierta, también con el sistema en oscuro.
- **HU-021-5** Como usuario con una tarea web, quiero que la página se vea **como en el resto de la app**, en claro, y no a medias oscura.
- **HU-021-6** Como propietario, quiero que el arranque **no tarde más** y que esto no añada dependencias, permisos ni textos (P2, P11).

## 3. Criterios de aceptación

**Trazabilidad HU → CA:** HU-021-1 → CA-021-02, 03, 05, 12; HU-021-2 → CA-021-01, 03, 04; HU-021-3 → CA-021-06, 07; HU-021-4 → CA-021-09; HU-021-5 → CA-021-08; HU-021-6 → CA-021-10, 11.

Cada CA dice cómo se verifica: con un **test** (corre en la CI, sin dispositivo) o con una **casilla** de dispositivo (tabla C-021-n del §10, con su entorno). Muchos son de las dos clases: el test comprueba lo que la app pide al sistema y la casilla, lo que el sistema pinta de verdad.

**Arranque**

- **CA-021-01** · Arranque en Android 12 o posterior, sistema en claro
  - **Dado** un móvil con Android 12 o posterior y el sistema en modo claro
  - **Cuando** se abre la app desde el lanzador con el proceso cerrado
  - **Entonces** hasta el primer fotograma de la app **solo se ve el color `paper`**: con la **«u.» negra del icono** (el primer plano del icono adaptable de la 018) en el centro, directamente sobre el papel, sin círculo ni recuadro de otro color detrás, mientras el sistema muestra su *splash*; y, si el sistema lo quita antes del primer fotograma, `paper` liso. **Ningún fotograma blanco ni negro.**
  - **Verificable:** test de recursos (CA-021-04: fondo del *splash* y color detrás del icono, si existe, = `paper`) y casilla C-021-1.
- **CA-021-02** · Arranque en Android 12 o posterior, sistema en oscuro
  - **Dado** lo mismo que en CA-021-01, pero con el sistema en **modo oscuro**
  - **Cuando** se abre la app desde el lanzador con el proceso cerrado
  - **Entonces** el arranque es **idéntico** al de CA-021-01 (`paper`, la misma «u.» negra, sin el círculo amarillo de hoy); ningún fotograma negro.
  - **Verificable:** test de recursos (CA-021-04, en la variante oscura) y casilla C-021-2.
- **CA-021-03** · Arranque en Android 8 a 11
  - **Dado** un móvil con Android 8 a 11 (API 26 a 30), con el sistema en claro o, donde existe (Android 10 y 11), en oscuro
  - **Cuando** se abre la app con el proceso cerrado
  - **Entonces** hasta el primer fotograma se ve un **fondo liso `paper`, sin icono** ni ningún otro elemento, igual en claro y en oscuro.
  - **Verificable:** test de recursos (la variante anterior a Android 12, clara y oscura, pide un fondo liso `paper` y ninguna imagen) y casilla C-021-3. **[Pendiente, PD-10/022]** la casilla: no hay AVD de esas versiones en este Mac (`docs/PLAN.md`); se hace con un dispositivo o un AVD cuando haya espacio, junto a PD-10.
- **CA-021-04** · Un solo color, desde los tokens
  - **Dado** todos los colores que la app pide al sistema para el arranque y para el fondo de la ventana (CA-021-05), **en todas sus variantes**: claro y oscuro, Android 8–11 y Android 12+, incluido el color detrás del icono del *splash* si el sistema lo usa
  - **Cuando** se comparan con `design/tokens.json`
  - **Entonces** todos son **exactamente el valor de `paper`** (hoy `#F4F1EA`), sin otro valor suelto. Si `paper` cambia en los tokens, la comprobación falla hasta que el arranque se actualice.
  - **Verificable:** test (CI).
- **CA-021-05** · Fondo de la ventana
  - **Dado** la app abierta, con el sistema en claro o en oscuro
  - **Cuando** el sistema enseña el fondo de la ventana antes de que la app vuelva a dibujar: al aparecer o desaparecer el teclado en el editor, al entrar o salir de pantalla dividida, o al girar con una tarea con imagen o PDF
  - **Entonces** ese fondo es `paper`, nunca negro ni blanco. **Excepción aceptada (propietario, 2026-10-15; hallazgo de T-021-06):** al **entrar** en pantalla dividida puede verse **un solo fotograma** negro en la mitad de la app, porque la superficie de Flutter aún no tiene imagen. No es el fondo de la ventana ni depende del modo, y ocurre igual en `main`: es un límite del motor, no una regresión. Salir de la división y el resto de acciones no tienen excepción.
  - **Verificable:** test de recursos (CA-021-04) y casilla C-021-4 (`screenrecord`, 10 repeticiones de cada acción en claro y 10 en oscuro: ningún fotograma con el área de contenido negra o blanca). **[Suposición]** al girar, el sistema suele animar con una captura de la app y el fondo no llega a verse; el teclado y la pantalla dividida son lo que de verdad lo pone a prueba.

**La app, siempre en claro**

- **CA-021-06** · Igual en claro y en oscuro
  - **Dado** cualquier pantalla o estado de la app: bienvenida; tarea actual de texto, imagen, varias fotos (también «Foto no disponible» y «Preparando foto {i} de {n}…»), PDF y web (**el marco de la app**: barra del dominio, línea de carga y el estado sin conexión; la página es CA-021-08); «Todo hecho.»; menú; editor; «¿Dónde la pones?»; «Añadir a la tarea»; «Cargar URL»; listado; card de deshacer; aviso de error al guardar; Ajustes y página de Idioma; y el primer y el último fotograma de arrugar y de romper la nota
  - **Cuando** se dibuja con el sistema en modo oscuro
  - **Entonces** se ve **píxel a píxel igual** que con el sistema en modo claro: mismos colores, contrastes y sombras. El menú de selección de texto y los asas del editor, que dibuja la app, también son los claros.
  - **Verificable:** test (comparación de capturas de cada pantalla con el brillo de la plataforma en claro y en oscuro; deben coincidir).
- **CA-021-07** · Cambiar el modo sin salir de la app
  - **Dado** la app abierta en cualquier pantalla, con texto sin guardar en el editor, una hoja abierta, la card de deshacer visible o una foto del carrusel desplazada
  - **Cuando** el sistema pasa de claro a oscuro o al revés **sin que el usuario salga de la app**: desde el panel de ajustes rápidos, a su hora programada o al encenderse el ahorro de batería
  - **Entonces** no cambia nada de lo que se ve, la app no se reinicia ni vuelve a la tarea actual y **se conserva** lo que había: el texto, la hoja, la card con el tiempo que le quedaba y la posición de la foto. Si el usuario sale de la app para cambiarlo (por ejemplo, a los Ajustes del sistema), se aplican sin cambios la 014 (la card se confirma, ADR-0021) y CA-001-12.
  - **Verificable:** test de widgets (cambiar el brillo de la plataforma conserva el estado) y casilla C-021-5 (cambio del modo del sistema con la app delante).

**Lo que el sistema dibuja con la app**

- **CA-021-08** · La página de la tarea web, en claro
  - **Dado** una tarea web cuya página tiene versión clara y oscura (respeta la preferencia de color del navegador), con el sistema en **modo oscuro**
  - **Cuando** se carga la página en la tarea
  - **Entonces** la página se ve en su **versión clara**, la misma que con el sistema en claro, y el sistema **no la oscurece por su cuenta**. Tampoco cambia si el sistema cambia de modo con la página abierta.
  - **Verificable:** casilla C-021-6, con una página **local** de prueba que cambia de color según la preferencia (sin red). **[Suposición, a medir en el plan]** hoy podría verse oscura: desde Android 13 la página recibe la preferencia según el tema de la ventana de la app, que es oscuro con el sistema en oscuro; el resultado depende también de la versión de la WebView.
- **CA-021-09** · Barras del sistema legibles
  - **Dado** cualquier pantalla de la app en vertical **y el arranque**, con el sistema en claro o en oscuro
  - **Cuando** se ven la barra de estado y la de navegación (con gestos o con tres botones)
  - **Entonces**:
    - detrás de las barras se ve **el fondo de la app** (`paper` o el de la pantalla), sin velo oscuro ni franja de otro color (Q-021-5);
    - sus iconos son **oscuros**, con un contraste de **3:1 o más** (WCAG 1.4.11) contra ese fondo, igual en claro y en oscuro;
    - si alguna pantalla tiene un fondo oscuro detrás de una barra, allí los iconos son claros, con el mismo contraste (hoy solo la enhorabuena, sobre `ink`: `systemBarsOnDarkStyle`, test en `system_bars_test.dart`; **[Pendiente, 022]** medirlo en el dispositivo);
    - **excepción de Android 8.0 (API 26):** el sistema no permite pedir iconos oscuros en la barra de navegación desde el tema; allí la barra de navegación lleva un fondo oscuro con iconos claros (3:1 o más), como hoy. *Precisión (2026-10-15, P-021-2):* con la app abierta se acepta también la barra como en el resto (fondo de la app e iconos oscuros) si el sistema lo permite, siempre con 3:1 o más;
    - **fuera del criterio:** la parte de una foto o de un PDF que quede detrás de una barra (su contraste depende de la imagen) y la píldora de gestos, cuyo color adapta el sistema.
  - **Verificable:** casilla C-021-7 (contraste medido en capturas del dispositivo, en claro y en oscuro, con gestos y con tres botones). **[Suposición, a medir en el plan]** hoy, con el sistema en oscuro, los iconos podrían salir claros sobre el papel (nadie fija su color).

**Volver a la app**

- **CA-021-12** · El fotograma al volver no empeora (no regresión de CA-011-03)
  - **Dado** la app en segundo plano sin instantánea (spec 011), con el sistema en claro o en oscuro
  - **Cuando** el usuario vuelve a la app desde «Recientes», desde el icono o desde otra app
  - **Entonces** el fotograma que pinta el sistema antes de la app es **blanco (como hoy) o `paper`**, o el arranque de CA-021-01 a 03; **nunca negro ni de otro color**. El paso de blanco a `paper` se acepta (Q-021-6) y está anotado como enmienda en CA-011-03 y en el ADR-0019 (2026-10-15).
  - **Verificable:** casilla C-021-8 (`tools/check-recents.sh` y `screenrecord`, 10 vueltas por modo).

**Rendimiento y límites**

- **CA-021-10** · El arranque no se degrada
  - **Dado** la compilación *release* en el emulador de API 37 (y en el Xiaomi en la 022), con una tarea de texto como tarea actual
  - **Cuando** se mide el arranque en frío hasta el primer fotograma (como en `docs/perf/baseline.md`, n ≥ 20, alternando con `main`), con el sistema en claro y en oscuro
  - **Entonces** el p50 no empeora frente a `main` más allá de la deriva medida entre dos pasadas de `main` el mismo día (≈ 12 ms en el emulador), en ninguno de los dos modos, y el p50 en oscuro no supera al de claro en más de esa deriva.
  - **Verificable:** casilla C-021-9 (medida).
- **CA-021-11** · Sin nada nuevo que pese ni que se publique
  - **Dado** el cambio de esta spec
  - **Cuando** se revisa el *diff* y el APK de *release*
  - **Entonces** no hay dependencias nuevas (ni de desarrollo), permisos, textos ni cambios de esquema; los iconos existentes (lanzador, Play, monocromo y el pequeño de la notificación) quedan **idénticos byte a byte** a los de la 018 y la 019; si el arranque necesita una imagen propia, sale del mismo original del tablero 17 (fuente única, CA-018-10). La puerta de publicación de la 020 sigue en verde.
  - **Verificable:** test (CI: dependencias, permisos y sumas de los iconos) y el trabajo de publicación en modo testers.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-021-1 | Arranque templado (proceso vivo, pantalla de la app destruida) o vuelta sin instantánea | En Android 12+ el sistema puede enseñar el arranque de CA-021-01 y 02; es aceptable. La vuelta, CA-021-12 |
| CL-021-2 | Volver desde «Recientes» con el proceso muerto | Es un arranque en frío: CA-021-01 a 03 |
| CL-021-3 | Primer uso (sin tareas, bienvenida) | El mismo arranque de CA-021-01 a 03; luego, la bienvenida sobre `paper` |
| CL-021-4 | Abrir desde la notificación (spec 019), desde otra app o desde un acceso directo | En Android 13+ el sistema puede usar un *splash* **sin icono** cuando no se abre desde el lanzador. Se acepta `paper` liso (sin la «u.»); lo que no se acepta es blanco o negro. Casilla C-021-10 |
| CL-021-5 | El sistema cambia de modo con la app en segundo plano | Al volver, la app sigue en claro; si el proceso murió, arranque normal en `paper` |
| CL-021-6 | Modo oscuro por el ahorro de batería | Igual que el modo oscuro puesto a mano (CA-021-02 y 07) |
| CL-021-7 | Fabricante o desarrollador que **fuerza** el modo oscuro en las apps (el «modo oscuro para apps» de HyperOS, «Anular forzar modo oscuro» de las opciones de desarrollo) | La app pide al sistema que **no** la oscurezca y sigue en claro. **[Pendiente, 022]** comprobarlo en el Xiaomi; si un fabricante o el sistema lo ignora, se anota como límite del sistema y no bloquea |
| CL-021-8 | **Ajuste de accesibilidad** del sistema que oscurece las apps claras (el tema oscuro ampliado de Android 16; **[Suposición]** nombre y comportamiento por confirmar en el plan) | ~~Manda el ajuste de accesibilidad: la app no se niega a él (Q-021-7).~~ **Enmienda (propietario, 2026-10-15):** la app **se queda siempre igual**, como en CL-021-7: pide al sistema que no la oscurezca. Si el sistema lo ignora, límite del sistema; no bloquea |
| CL-021-9 | Fabricante que dibuja su propio *splash* o ignora el fondo pedido | Se acepta lo que pinte el sistema; **[Pendiente, 022]** verlo en el Xiaomi (casilla de la 018, CA-018-13) |
| CL-021-10 | Icono con tema puesto (Android 13+) | **[Suposición]** el *splash* sigue con la «u.» negra sobre `paper`: el icono con tema solo cambia el lanzador. Casilla C-021-11 |
| CL-021-11 | Tarea con imagen o PDF en horizontal | Las barras se comportan como hoy en horizontal; si alguna se ve, cumple CA-021-09 salvo la parte de la foto o del PDF que quede detrás |
| CL-021-12 | Hojas y diálogos **del sistema** (permiso de notificaciones, selector de fotos, cámara, navegador de Ajustes, teclado) | Siguen el modo del sistema: no son de la app y no se tocan |
| CL-021-13 | Página web sin versión clara (solo oscura, o con fondo oscuro fijo) | Se ve como la diseñó su autor; la app solo pide la versión clara, no la cambia |
| CL-021-14 | Pantalla dividida o ventana flotante | Fondo de la ventana `paper` (CA-021-05); D28 (solo móvil) |
| CL-021-15 | Contraste alto de texto o inversión de colores del sistema | Lo aplica el sistema por encima de la app; fuera de esta spec |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Arranque lento | El primer fotograma tarda más de lo normal (móvil cargado) | `paper` (con la «u.» o liso) el tiempo que haga falta, sin texto ni indicador; no hay estado de error nuevo |
| Sin tareas | Primer uso o «Todo hecho.» | Como hoy, sobre `paper` (CL-021-3) |

## 6. Accesibilidad

- **Sin interacción nueva:** no hay gestos, botones, textos ni anuncios nuevos. El arranque no es interactivo ni lo recorre el lector (lo pinta el sistema antes que la app).
- **Contraste:** la «u.» negra (`ink`, `#111111`) sobre `paper` (`#F4F1EA`) supera de sobra 3:1 (gráfico, WCAG 1.4.11). Los iconos de las barras del sistema, 3:1 o más (CA-021-09).
- **Reducir movimiento:** el arranque no lleva animación propia (ni icono animado). **[Suposición]** la salida del *splash* es la del sistema y respeta su ajuste de animaciones; casilla C-021-12 con las animaciones desactivadas.
- **Modo oscuro como preferencia de accesibilidad:** quien usa el modo oscuro del sistema por fotosensibilidad verá la app en claro, como hasta hoy; es una decisión de producto (Q-021-1: la identidad de papel no tiene versión oscura). Ahora el arranque no pasa de negro a claro, y eso **reduce** el destello frente a hoy. El ajuste de accesibilidad que oscurece las apps ~~se respeta~~ **no** se aplica a la app (CL-021-8, enmienda del 2026-10-15). **[Pendiente, 022]** si la beta lo señala, se revisa con una spec propia de tema oscuro.
- **Texto grande:** sin cambios (no hay texto nuevo).

## 7. Textos (ES / EN)

Ninguno. No hay textos visibles ni anunciados nuevos (CA-021-11).

| Clave | ES | EN | Notas |
|---|---|---|---|
| — | — | — | — |

## 8. Fuera de alcance

- **Tema oscuro de la app**, siga al sistema o se elija en Ajustes (Q-021-1, opciones b y c descartadas). Necesitaría diseño del propietario, tokens nuevos y una spec propia.
- **Quitar el fotograma de la vuelta sin instantánea** (ADR-0019, CA-011-03): lo pinta el sistema y sigue aceptado (Q-021-4). Esta spec solo exige que no empeore (CA-021-12).
- **TD-2** (pantalla en negro tras usar una WebView en el emulador) y **O-1** de la 020: tareas aparte y la 022.
- **El arranque de iOS** (*launch screen*): F-iOS (D17). **[Pendiente, F-iOS]** aplicar allí el mismo criterio (`paper` y la «u.»).
- **La web de pruebas:** ya lleva el color de la app (018, DEV-55); su modo oscuro no se toca.
- **Lo que dibuja el sistema por su cuenta:** hojas y diálogos del sistema, teclado, notificaciones, navegador (CL-021-12).
- Un icono animado o una marca en el *splash*, y cambiar la duración del arranque.

## 9. Preguntas abiertas

Resueltas por el propietario el 2026-10-15:

- **Q-021-1** ¿Qué es «modo oscuro» en la 021? → **a)** La app sigue siempre en claro (identidad de papel, P12). La 021 hace que el arranque y lo que pinta el sistema se vean bien con el sistema en oscuro. Descartados el tema oscuro completo (b) y el ajuste Sistema/Claro/Oscuro (c).
- **Q-021-2** Color del arranque → **a)** `paper` con la «u.» negra, igual en claro y en oscuro. Descartados el amarillo del icono (b) y dejarlo como hoy (c).
- **Q-021-3** Android 8–11 → **a)** Fondo liso `paper`, sin icono.
- **Q-021-4** ¿Algo más? → **Recomendación aceptada:** quitar el fotograma de la vuelta (ADR-0019) queda fuera.

Surgidas en la revisión de `spec-reviewer` y resueltas por el propietario el 2026-10-15 («ok a las tres recomendaciones»):

- **Q-021-5** ¿Qué se ve detrás de las barras del sistema? → **El fondo de la app, limpio, sin velo** (como en el prototipo), con iconos oscuros (CA-021-09). Descartado dejarlo como hoy (velo oscuro translúcido con iconos claros).
- **Q-021-6** Al volver a la app sin instantánea, ¿se acepta que el fotograma pase de blanco a `paper` (o al arranque con la «u.»)? → **Sí** (CA-021-12): es más coherente y no enseña nada de la tarea. Enmienda anotada en CA-011-03 y en el ADR-0019 al aprobar (2026-10-15).
- **Q-021-7** Si el sistema oscurece las apps por un **ajuste de accesibilidad** (Android 16), ¿la app se deja? → ~~**Sí** (CL-021-8): un ajuste de accesibilidad manda sobre la identidad visual (P6). Solo se evita el oscurecimiento forzado por el fabricante o por las opciones de desarrollo (CL-021-7).~~ **Revocada por el propietario el 2026-10-15** al aprobar el plan (P-021-1): «Me da igual el modo oscuro. La aplicación se queda siempre igual». La app no se deja oscurecer, ni por el fabricante ni por el ajuste de accesibilidad (CL-021-8).

Pendientes de medida:

- **[Pendiente, plan]** Medir en el emulador de API 37 si hoy, con el sistema en oscuro, la página web sale oscura (CA-021-08) y los iconos de la barra de estado salen claros (CA-021-09), y cómo se comporta el *splash* al abrir desde la notificación (CL-021-4). El resultado esperado no cambia.
- **[Pendiente, 022]** CL-021-7 y CL-021-9 en el Xiaomi (HyperOS), y CA-021-03 en un Android 8–11 (PD-10).

## 10. Casillas de dispositivo

| ID | CA / CL | Qué se comprueba | Entorno |
|---|---|---|---|
| C-021-1 | CA-021-01 | Arranque en frío desde el lanzador, claro: `paper` con la «u.», sin círculo; ningún fotograma blanco ni negro (`screenrecord`, 10 arranques) | Emulador API 37; Xiaomi en la 022 |
| C-021-2 | CA-021-02 | Lo mismo con el sistema en oscuro | Emulador API 37; Xiaomi en la 022 |
| C-021-3 | CA-021-03 | Arranque en Android 8–11, claro y oscuro (10 y 11): `paper` liso | **[Pendiente, PD-10/022]** dispositivo o AVD de API 26–30 |
| C-021-4 | CA-021-05 | Teclado, pantalla dividida y giro: 10 veces cada uno en claro y en oscuro, sin fotogramas negros o blancos | Emulador API 37 |
| C-021-5 | CA-021-07 | Cambio del modo del sistema con la app delante (editor con texto, hoja abierta, card de deshacer, carrusel desplazado) | Emulador API 37 |
| C-021-6 | CA-021-08 | Página local con versión clara y oscura, sistema en oscuro y cambio de modo con la página abierta | Emulador API 37 |
| C-021-7 | CA-021-09 | Contraste de los iconos de las barras en capturas, claro y oscuro, gestos y tres botones; arranque incluido | Emulador API 37; API 26 en PD-10 |
| C-021-8 | CA-021-12 | Vuelta sin instantánea con `tools/check-recents.sh` y `screenrecord`, 10 vueltas por modo | Emulador API 37 |
| C-021-9 | CA-021-10 | Arranque en frío p50, claro y oscuro, frente a `main` | Emulador API 37; Xiaomi en la 022 |
| C-021-10 | CL-021-4 | Arranque desde la notificación de la 019: `paper` con o sin la «u.», nunca blanco ni negro | Emulador API 37; Xiaomi en la 022 |
| C-021-11 | CL-021-10 | *Splash* con iconos con tema activados | Emulador API 37 |
| C-021-12 | §6 | *Splash* con las animaciones del sistema desactivadas | Emulador API 37 |
