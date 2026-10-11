# Spec 018: Iconos

- **Estado:** **Implementada parcialmente** (2026-10-11; tabla CA → prueba en el §13; las casillas de dispositivo pendientes pasan a la 022, `docs/PLAN.md`, «Casillas de la 018»). Antes **Aprobada** por el propietario el 2026-10-10 («Aprobada con los últimos comentarios»: amarillo del icono para la web y descripción de plantilla quitada), revisada por `spec-reviewer` (3 bloqueantes y 10 medios, corregidos); Q-018-1 a 5 respondidas (§9). Plan y tareas **Aprobados** el 2026-10-10.
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Quinta de las specs 014–019 (después de la 014, 015, 016 y 017, fusionadas). Tamaño **S**.
- **Reglas de producto:** R20 (icono de la app, D29), R8 (abrir → tarea actual rápido: el icono es lo primero que se toca para abrirla), **propuesta de valor 2**
- **Pantallas del prototipo:** 17 «Icono de la app» (`Icono.dc.html`): «u.» en Archivo 900 sobre `#FFE55C`; iOS (1024), Android adaptable (círculo, squircle, gota), con tema (Android 13+) y Google Play 512. Las imágenes están copiadas en `design/prototype/assets/icon/` (ver `docs/design/screen-map.md`, «Imágenes del icono»). **Lo que el prototipo no define** (la web de pruebas: sus iconos y su manifiesto; el icono de las compilaciones de desarrollo) se decide aquí y se registra como **DEV-55** (`docs/design/prototype-deviations.md`).
- **Decisiones y ADR relacionados:**
  - **D29** (propietario, 2026-10-04): «Iconos (prototipo, tablero 17): icono adaptable de Android con versión monocroma ("con tema") y Play 512 × 512, **hechos a mano y sin dependencias**; iOS 1024 cuando toque (D17).»
  - **D17** (Android primero; sin Xcode por ahora), **D12** (Android 8 / API 26 como mínimo: **todo Android admitido tiene iconos adaptables**), **D28** (solo móvil), **D4** (la web de Vercel es solo de pruebas).
  - **D30** (la beta espera a la 018) y el troceado de F5: la **021** ya prevé «el fondo de arranque coherente con el icono de la 018»; esta spec **no** toca el arranque.
  - **P11** (dependencias con criterio): sin `flutter_launcher_icons` ni ningún generador ni paquete; **«a mano» (D29) significa eso: sin generador ni paquete**, no que se redibuje la «u.» (CA-018-10). Vale un script de conversión en `tools/` (shell, no se empaqueta) o comandos documentados, nunca código en `lib/` (CA-018-15). **P12** (el prototipo es la referencia visual).
  - Sin ADR nuevo y sin subir la constitución (sigue la 1.9): ninguna excepción a ningún principio.
  - Modelo de amenazas (`docs/security/threat-model.md`): sin riesgo nuevo (ni permisos, ni red, ni código, ni datos).
- **Dependencias:** ninguna funcional (solo recursos de plataforma). Va después de la 017 por el orden del plan F4b y antes de la beta (D30). **Sin esquema de BD, sin permisos, sin dependencias (ni de desarrollo) y sin cambios en el código de la app, Dart o nativo** (CA-018-12; los tests nuevos sí se escriben).
- **Nomenclatura:**
  - **Icono de la app:** el dibujo que se ve en el lanzador, en «Ajustes del sistema» y en la lista de aplicaciones. **No** es el logotipo «una.» de la primera pantalla (`wordmark`, `identity.yaml`), que no cambia.
  - **Icono adaptable:** el de Android: un lienzo de **108 dp** con un fondo y un primer plano; el lanzador lo recorta con la máscara de su fabricante (círculo, cuadrado redondeado, gota…), por lo que **solo se ve un círculo central de 72 dp** y el dibujo debe caber en la **zona segura**, un círculo de **66 dp**.
  - **Icono con tema:** variante de Android 13+ en la que el sistema pinta la silueta de **una capa monocroma** con los colores del fondo de pantalla del usuario.
  - **Icono de Play:** el PNG de 512 × 512 que pide la ficha de Google Play.
  - **Dimensión visible:** el lado sobre el que se mide el tamaño de la «u.». En el icono adaptable es el **círculo de 72 dp**; en el icono de Play, en el original de 1024 y en la web es **el lado entero**. En todos, el ancho de la «u.» con el punto es el **56 %** de esa dimensión (CA-018-10).
  - **«u.» (la figura):** la letra y el punto juntos. **Esquina más lejana:** el vértice de la caja de la figura más alejado del centro (para no confundirlo con el punto «.» de la «u.»).

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que la app tenga **su propio icono** en lugar del de Flutter que lleva desde el esqueleto **en Android y en la web de pruebas** (el de iOS se queda como está hasta F-iOS, Q-018-1), y que esa web ya no lleve los colores ni los textos de la plantilla de Flutter: la «u.» negra sobre amarillo del tablero 17, **nítida y completa con cualquier máscara de lanzador**, con su versión **con tema** en Android 13+ y el PNG de **Google Play 512**, antes de entregar la beta a los testers (D30).

## 2. Historias de usuario

- **HU-018-1** Como usuario, quiero reconocer la app entre las demás por un icono propio, sencillo y de buen contraste, para abrirla de un vistazo.
- **HU-018-2** Como usuario de cualquier móvil Android (Pixel, Samsung, Xiaomi…), quiero que el icono se vea **entero y bien centrado** con la forma que use mi lanzador, para que no parezca roto ni recortado.
- **HU-018-3** Como usuario con iconos con tema (Android 13+), quiero que el icono se **tiña con los colores de mi pantalla** y se siga reconociendo, para que no desentone.
- **HU-018-4** Como propietario, quiero tener el icono de Play de 512 × 512 listo para la ficha de la tienda y que **todas las versiones salgan del mismo dibujo**, para no rehacerlo en la publicación.
- **HU-018-5** Como propietario, quiero que el icono **no añada dependencias, permisos ni código** y no retrase el arranque, para mantener la app tan pequeña y privada como hasta ahora (P2, P4, P11).

## 3. Criterios de aceptación

**Trazabilidad HU → CA**

| HU | Criterios |
|---|---|
| HU-018-1 | CA-018-01, 03, 06 y 11 |
| HU-018-2 | CA-018-01, 02 y 07 |
| HU-018-3 | CA-018-04 y 05 |
| HU-018-4 | CA-018-08, 09, 10 y 15 |
| HU-018-5 | CA-018-12 y 13 |
| Transversales | CA-018-14 |

**El icono de la app (Android)**

- **CA-018-01 El icono en el lanzador (tablero 17)**
  - **Dado** la app instalada en un Android de 8 en adelante, sin iconos con tema
  - **Cuando** se mira su icono en el lanzador, en «Ajustes del sistema» o en la lista de aplicaciones
  - **Entonces** se ve la **«u.» (la letra y el punto) en `#111111` sobre un fondo liso `#FFE55C`**, centrada, como el original del tablero 17: el **ancho de la «u.» con el punto es el 56 % del círculo visible de 72 dp** (≈ 40,3 dp; tolerancia ± 1 punto de porcentaje) y su caja queda **centrada en el lienzo** (tolerancia ± 1 dp). Debajo, el nombre de la app, sin cambios (CA-018-11). No queda ningún rastro del logotipo de Flutter.
  - **Verificable:** un test lee el recurso del primer plano, mide la caja de sus píxeles no transparentes y comprueba el ancho relativo y el centrado; la forma, a ojo en el emulador (C-018-1 y C-018-2).
- **CA-018-02 Entero con cualquier máscara (zona segura)**
  - **Dado** el icono adaptable
  - **Cuando** el lanzador lo recorta con un círculo, un cuadrado redondeado (*squircle*), una gota o un cuadrado de esquinas casi rectas
  - **Entonces** la «u.» se ve **completa, sin recortar y sin tocar el borde**: **todo píxel no transparente del primer plano cae dentro de la zona segura** (círculo de 66 dp de diámetro centrado, es decir, a ≤ 33 dp del centro; hoy, la esquina más lejana de la «u.» está a ≈ 24 dp), y **el amarillo llena toda la máscara** (sin bordes blancos, transparentes ni de otro color), también en los 18 dp de cada lado que el lanzador puede esconder.
  - **Verificable:** un test mide la distancia máxima de un píxel no transparente al centro (≤ 33 dp) y que el fondo cubre los 108 dp enteros; las cuatro máscaras, a ojo en el emulador (C-018-1).
- **CA-018-03 Los colores salen de los tokens** *(Hecho: los PNG fuente usan exactamente `#FFE55C` y `#111111`; comprobado el 2026-10-10)*
  - **Dado** el icono
  - **Entonces** el fondo es **exactamente el color del token `palette.classic.0` (`#FFE55C`, «Amarillo»)** —**fijo aunque cambie la paleta activa**: el icono no es una nota— y la «u.» es exactamente el token `ink` (`#111111`); no hay ningún otro color ni degradado, sombra o borde en el primer plano. Los píxeles de alfa parcial (el suavizado del borde de la «u.») son de tinta: su RGB difiere de `#111111` en **±10 por canal como máximo**. Si el color de un token cambia, la comprobación falla hasta que se rehaga el icono (no se copian valores a ciegas).
  - **Verificable:** un test compara el color del fondo y el del primer plano con `palette.classic.0` e `ink` de `design/tokens.json` y recorre los píxeles del primer plano comprobando que solo hay tinta, transparencia y suavizado de tinta (±10).
- **CA-018-04 Icono con tema (Android 13+)**
  - **Dado** un Android de 13 en adelante con los iconos con tema activados (*Fondo de pantalla y estilo → Iconos con tema*)
  - **Cuando** se mira el icono de la app
  - **Entonces** el sistema lo pinta como **una silueta de un solo color** (la «u.» con su punto, completos) con los colores del usuario, sobre el fondo que da el sistema, **como en la vista previa del tablero 17** (la azul es solo un ejemplo del tablero: el color lo decide el sistema, no la app). La capa monocroma tiene **el mismo dibujo, el mismo tamaño y la misma posición que el primer plano** (CA-018-01 y 02) y es **maciza**: alfa 255 dentro de la figura (también el punto) y alfa 0 fuera, salvo el suavizado del borde, para que el sistema la tiña sin manchas.
  - **Verificable:** un test comprueba que el icono declara la capa monocroma y que su **alfa es idéntica píxel a píxel** a la del primer plano; la apariencia, a ojo en un emulador de Android 13+ con iconos con tema (C-018-3).
- **CA-018-05 Sin tema, o antes de Android 13**
  - **Dado** un Android 8–12, o uno de 13+ con los iconos con tema apagados, o un lanzador que no los admite
  - **Entonces** se ve el icono **amarillo con la «u.» negra** de CA-018-01, sin cambios. La capa monocroma no se usa.
  - **Verificable:** a ojo en el emulador (C-018-3, con los iconos con tema apagados y en un Android 8–12); la capa monocroma no afecta al primer plano (test de CA-018-04).
- **CA-018-06 Nada del icono de Flutter (Android y web de pruebas)**
  - **Dado** el repositorio y el APK de *release*
  - **Entonces** **la app Android no declara ni lleva ningún icono de la plantilla de Flutter**: el icono declarado es el nuevo y no queda ningún icono de baja densidad de la plantilla (con el mínimo en Android 8 no se necesitan, D12). Los iconos de **iOS siguen siendo los de la plantilla** hasta la fase F-iOS (Q-018-1, §8); este criterio no los cubre.
  - **Verificable:** un test comprueba que el manifiesto declara el icono adaptable, que en `res/` no queda ningún `ic_launcher.png` de la plantilla (se comparan **los bytes** con los de la plantilla, guardados como fixture del test) y que no hay recursos de icono huérfanos; la casilla C-018-6 abre el APK de *release* y comprueba lo mismo. Los de la web, en CA-018-09.
- **CA-018-07 Nítido a cualquier densidad**
  - **Dado** una pantalla de cualquier densidad, de 160 a 640 dpi
  - **Cuando** se ve el icono a su tamaño (48 dp) o ampliado (la ficha del sistema, el selector de apps)
  - **Entonces** los bordes de la «u.» son **nítidos, sin escalones ni borrosidad**. «Nítido» se mide con un proxy: el primer plano y la capa monocroma son **imágenes de al menos 432 px por lado** (4 × 108 dp, a 640 dpi) y **del mismo tamaño** (las fuentes del tablero ya lo son).
  - **Verificable:** un test lee las dimensiones de los dos recursos; la nitidez, a ojo en C-018-4.

**Google Play y la web de pruebas**

- **CA-018-08 Icono de Google Play (512 × 512)**
  - **Dado** la publicación futura en Google Play (F6)
  - **Entonces** existe en el repositorio un **PNG de 512 × 512 px, RGBA (32 bits, con canal alfa presente y a 255 en todos los píxeles: sin transparencia) y de menos de 1024 KB**, **cuadrado y a sangre** (Google aplica su propio redondeo y su sombra: **sin esquinas redondeadas, sin sombra y sin borde**), que es **el original de 1024 reducido a 512, sin cambios de color ni de proporción** (el 56 % del lado para la «u.» con el punto, centrada, `#111111` sobre `#FFE55C`). Está en una carpeta de la tienda (la fija el plan) y **no se empaqueta en la app**.
  - **Verificable:** un test comprueba formato RGBA, dimensiones, peso, alfa 255 en todos los píxeles y que el color de las cuatro esquinas es `#FFE55C`, y compara la imagen con el original reducido (**diferencia media ≤ 2/255 por canal**); otro test comprueba que el archivo no aparece entre los *assets* declarados de la app.
- **CA-018-09 La web de pruebas: iconos y color (Q-018-2 y Q-018-5, respondidas)**
  - **Dado** la web de pruebas (Vercel, D4)
  - **Entonces** (1) el **favicon** y los iconos de la web (**192 y 512**, y los «maskable» **192 y 512**) **son el icono nuevo**, hechos del mismo original (la «u.» a sangre, que cabe en la zona segura de los «maskable», un círculo de radio el 40 % del lado: la esquina más lejana de la «u.» está a ≈ 33 % del lado); (2) **el color de la web es el de la app, no el azul de Flutter**: `theme_color` y `background_color` del manifiesto son el token **`palette.classic.0` (`#FFE55C`, el amarillo del icono; fijo aunque cambie la paleta activa)** *(propietario, 2026-10-10: «prefiero el amarillo del icono»)*; (3) **ya no queda el texto «A new Flutter project.»**: se quita la descripción del manifiesto y la de la página (son campos opcionales: **no se escribe ningún texto nuevo**, así no hay que traducirlo; `Una.` sale de la identidad). Nada más de la web cambia (nombre, orientación, modo de pantalla).
  - **Verificable:** un test comprueba los tamaños (el favicon, de al menos 32 px; el tamaño exacto lo fija el plan), que ningún icono coincide byte a byte con la plantilla, el color de las esquinas, que en los «maskable» la esquina más lejana de la «u.» queda a ≤ 40 % del lado, que `theme_color` y `background_color` son iguales al token `palette.classic.0` de `design/tokens.json`, que no queda `0175C2` ni «A new Flutter project» en `app/web/` y que el nombre del manifiesto sigue siendo el de la identidad.
- **CA-018-10 Un solo dibujo (coherencia)**
  - **Dado** todas las versiones del icono (Android adaptable, con tema, Play 512 y web)
  - **Entonces** salen **del mismo dibujo** (el original del tablero 17): la «u.» tiene en todas **las mismas proporciones** (ancho de la «u.» con el punto = 56 % de la dimensión visible, caja centrada, mismos colores), y ninguna lleva texto, nombre ni elementos añadidos. No se redibuja una versión distinta (D29: «a mano» es sin generador ni paquete): si el dibujo cambiara, cambian todas.
  - **Verificable:** un test mide, en cada versión, el ancho relativo y el centrado de la «u.» (la tolerancia de CA-018-01).

**Nombre, accesibilidad y compilaciones**

- **CA-018-11 Nombre y accesibilidad (sin cambios)**
  - **Dado** el icono nuevo
  - **Entonces** el **nombre bajo el icono sigue saliendo de `identity.yaml`** (`displayName`, «Una.»; nada literal, P7) y es lo que lee el lector de pantalla en el lanzador. El icono no tiene texto traducible ni etiqueta propia; **la «u.» es un dibujo, no un texto de la app**. El contraste de la «u.» sobre el amarillo es **≈ 14,9 : 1** (≥ 3 : 1 que pediría WCAG 1.4.11 a un gráfico) y el significado **no depende solo del color**.
  - **Verificable:** un test comprueba que el manifiesto sigue tomando el nombre de la identidad generada (`strings.xml`, `app_identity.g.dart`: nada literal) y calcula el contraste de los dos tokens.
- **CA-018-12 Sin dependencias, permisos, datos ni cambios de código**
  - **Dado** el cambio completo
  - **Entonces** **no se añade ninguna dependencia, ni siquiera de desarrollo** (D29: «a mano»), **ningún permiso**, **ningún cambio de esquema ni de datos**, **ningún cambio en el código de la app, Dart o nativo**, y ninguna llamada de red. Solo cambian recursos (imágenes y definiciones de icono), la referencia al icono en el manifiesto de Android, **los archivos de la web de pruebas (`app/web`: iconos, manifiesto y página)**, los tests nuevos y la documentación. **Los tests nuevos son Dart y leen los PNG sin paquetes nuevos** (con lo que ya trae `flutter test`; el plan lo concreta).
  - **Verificable:** `pubspec.yaml` y `pubspec.lock` sin cambios y las dependencias de Gradle sin cambios; `tools/check-android-permissions.sh` en verde (permisos sin cambios); el diff de `lib/` y de los `.kt` vacío.
- **CA-018-13 El arranque no empeora (P2)**
  - **Dado** el arranque en frío
  - **Entonces** la mediana (p50) con el icono nuevo **no es peor** que con el de Flutter (mismo emulador y mismo método, `tools/measure-cold-start.sh`; margen de ruido ± 5 %). **[Suposición, se comprueba en el emulador]** el *splash* del sistema (Android 12+) muestra solo el icono nuevo sobre el fondo de siempre: **no se cambia su fondo** (es de la 021).
  - **Verificable:** una medición antes/después en el emulador de API 37 (C-018-5).
- **CA-018-14 Todas las compilaciones llevan el mismo icono (Q-018-4, respondida: sí)**
  - **Dado** las compilaciones de desarrollo (`debug` y `profile`) y la de publicación (`release`)
  - **Entonces** las tres llevan **el mismo icono y el mismo nombre** (no hay icono de «desarrollo»). Quien tenga la app de pruebas y la real a la vez en el móvil las distinguirá por otros medios (su ficha del sistema), como hoy. *(Propietario, 2026-10-10: «Sí».)*
  - **Verificable:** un test comprueba que no hay recursos de icono propios de una compilación (carpetas `android/app/src/debug` y `src/profile`).
- **CA-018-15 El dibujo queda documentado y reproducible**
  - **Dado** la implementación terminada
  - **Entonces** `docs/design/` (o `docs/architecture.md`, lo fija el plan) **documenta el icono**: el original y sus capas de origen (`design/prototype/assets/icon/`), la geometría (lienzo de 108 dp, zona segura de 66, la «u.» al 56 % del círculo visible de 72), los colores (tokens) y **cómo se hizo cada versión sin dependencias**, con **comandos documentados o un script en `tools/` (shell, no se empaqueta; nunca código en `lib/`)**, de modo que se pueda rehacer (p. ej. si cambia el nombre de la app) sin adivinar.
  - **Verificable:** revisión de la documentación (DoD) y de que la geometría citada coincide con la medida por los tests de CA-018-01, 02 y 10.

**Casillas de dispositivo** (a mano; se anotan en `specs/018-iconos/dispositivo.md` al implementar; **C-018-2 se hace en el Xiaomi al implementar** y las demás de teléfono real, en la 022)

| ID | Qué se comprueba | Dónde |
|---|---|---|
| C-018-1 | Las cuatro máscaras (círculo, cuadrado redondeado, gota, cuadrado) con *Forma de los iconos* de las opciones de desarrollador: la «u.» entera y el amarillo hasta el borde (CA-018-01, 02) | Emulador de API 37 |
| C-018-2 | El icono en el lanzador, en «Ajustes del sistema» y en la lista de aplicaciones (CA-018-01) | Emulador de API 37 **y el Xiaomi (HyperOS) durante la implementación** (el propietario quiere verlo en Android, Q-018-1); el coordinador lo instala con la app `.profile` aparte y avisa antes de cualquier captura (privada) |
| C-018-3 | Icono con tema encendido y apagado, y uno de Android 8–12 (CA-018-04, 05) | Emulador de API 37 y de API 26 o 32 |
| C-018-4 | Nitidez a 48 y 24 dp y con «Tamaño de visualización» al máximo (CA-018-07, CL-018-4 y 10) | Emulador de API 37 |
| C-018-5 | Arranque en frío antes/después y el *splash* de Android 12+ con la «u.» entera (CA-018-13) | Emulador de API 37 |
| C-018-6 | El APK de *release* sin ningún icono de la plantilla (CA-018-06) | Escritorio |
| C-018-7 | TalkBack lee el nombre en el lanzador (CA-018-11) | Xiaomi (022) |

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-018-1 | Lanzadores con máscaras distintas (Pixel: círculo; Samsung: cuadrado redondeado; Xiaomi/HyperOS, OPPO…; con tema del sistema) | La «u.» se ve entera y el amarillo llena la máscara (CA-018-02). Es lo que se mira en el Xiaomi del propietario (casilla de la 022) |
| CL-018-2 | Lanzador sin soporte de iconos con tema, o iconos con tema apagados | Icono amarillo (CA-018-05) |
| CL-018-3 | Iconos con tema con un fondo de pantalla de muy poco contraste | El color lo elige el sistema; la capa monocroma es maciza y de un solo dibujo, así que el contraste lo da la combinación del sistema. Sin cambio; se deja constancia en `dispositivo.md` |
| CL-018-4 | Icono muy pequeño (el del aviso de privacidad del sistema, la lista de «Recientes», la ficha de la tienda a 48 px) | La «u.» sigue reconociéndose: es un trazo grueso y sin detalles finos (el original usa Archivo 900). Se comprueba a ojo a 48 dp y a 24 dp en el emulador |
| CL-018-5 | Modo oscuro del sistema | **El icono no cambia** (amarillo y negro). Solo cambia con tema, por decisión del sistema |
| CL-018-6 | Actualizar la app de una versión anterior (con el icono de Flutter) | Hay lanzadores que guardan el icono viejo en caché hasta reiniciarse o reinstalar. **[Suposición]** no se trata: es del lanzador. Los testers instalan una versión nueva desde cero; se anota en `dispositivo.md` |
| CL-018-7 | Cambia el nombre de la app (`displayName`, `wordmark`; **hoy es provisional**, `CLAUDE.md`) | **El icono no se actualiza solo**: la «u.» es un dibujo, en el icono de Android, el de Play y la web. Hay que rehacerlo siguiendo CA-018-15 (y, antes de F6, tenerlo en cuenta en la ficha de la tienda) |
| CL-018-8 | `debug` y `profile` (con sufijo en el identificador) instaladas junto a la `release` | Mismo icono y mismo nombre (CA-018-14) |
| CL-018-9 | El idioma de la app o el del sistema cambian | El icono y el nombre no cambian: no hay texto traducible (P7) |
| CL-018-10 | Pantalla con relación de aspecto muy alargada o con el icono ampliado por «Tamaño de pantalla» o «Tamaño de fuente» | El icono es del sistema: se escala con él, sin pérdida de nitidez (CA-018-07) |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Recurso del icono ausente o roto | Un fallo de compilación (un recurso borrado o mal formado) | No hay estado de usuario: **la compilación falla** y los tests de CA-018-01 a 08 también. Nunca se publica un APK sin icono |
| Lanzador que no pinta el primer plano | Un lanzador raro o un fallo del sistema | El fondo amarillo sin «u.»; **fuera de control de la app**. Sin tratamiento |
| Imagen de Play fuera de especificación | Un PNG que Play rechaza (peso, tamaño, transparencia) | Lo evita el test de CA-018-08; no llega a la tienda |

No hay estados vacíos ni de error **dentro de la app**: esta spec no toca ninguna pantalla.

## 6. Accesibilidad

**Sin interacción nueva** (ni gestos, ni pantallas, ni controles): no se aplican las alternativas de P6. Lo que sí cuenta:

- **Nombre para el lector:** el lector lee en el lanzador el nombre de `identity.yaml` («Una.»), como hoy; el icono es decorativo (CA-018-11, C-018-7).
- **Contraste:** «u.» `#111111` sobre `#FFE55C` ≈ 14,9 : 1 (WCAG 1.4.11 pide 3 : 1 a un gráfico; es un criterio de calidad, los iconos de lanzador no tienen requisito formal). El significado es una **forma**, no solo un color.
- **Con tema:** la silueta es maciza y de un solo dibujo para que cualquier combinación del sistema conserve su contraste (CL-018-3).
- **Escala y movimiento:** el icono se escala con el sistema sin perder nitidez (CA-018-07); no tiene movimiento (el *splash* animado es del sistema, §8).
- **[Pendiente, 022]** TalkBack, el tamaño de visualización más grande y los iconos con tema en un Android 13+ real (C-018-2 a 4 y 7).

## 7. Textos (ES / EN)

**Esta spec no añade ni cambia ningún texto de la app.** El nombre bajo el icono sale de `displayName` (`identity.yaml`, «Una.») y no se traduce. El icono es un dibujo sin texto traducible (CA-018-11, CL-018-9). No hay claves ARB nuevas (CA-018-12: sin código de Dart).

| Clave | ES | EN | Notas |
|---|---|---|---|
| — | — | — | Sin textos nuevos |

## 8. Fuera de alcance

- **iOS** (Q-018-1, **[Suposición]**): el icono de 1024 de App Store y el `AppIcon.appiconset` de iOS **no se tocan** aquí. D29 dice «iOS 1024 cuando toque (D17)»: sin Xcode no se puede comprobar el resultado. El original de 1024 (`design/prototype/assets/icon/icon-1024.png`) queda como fuente para la fase F-iOS.
- **El fondo del arranque y el *splash*** (`launch_background`, modo oscuro): son de la **021**. Esta spec solo deja el icono, que el sistema pinta solo en el *splash* de Android 12+.
- **El icono pequeño de las notificaciones** (barra de estado): es de la **019**, que decidirá si reutiliza la capa monocroma de esta spec.
- **El icono interno de «Bloquear zoom»** (la lupa con el signo menos, DEV-54; hallazgo (a) de las revisiones de cierre de la 017, `docs/PLAN.md`: «revisarlo al elegir los iconos en la 018» → **aplazado por Q-018-3**): **es un icono de la interfaz de Ajustes, no el de la app**, y cambiarlo es desviarse del prototipo (Q-018-3). Si el propietario quiere cambiarlo, será otra tarea con su DEV.
- **Un icono distinto por compilación** (marca de «debug» o «profile»; **[Suposición, Q-018-4]**), un **icono alternativo elegible por el usuario**, un **icono animado**, y variantes para **modo oscuro**: no.
- **La ficha de la tienda** (capturas, texto, imagen de funciones): es de la **023**. Aquí solo se entrega el icono de 512.
- **El logotipo «una.»** de la primera pantalla y de la bienvenida: no cambia.
- **El resto de la web de pruebas** (nombre, orientación, modo de pantalla y su aspecto): no se toca. Solo cambian los iconos, los dos colores del manifiesto y se quita la descripción de plantilla (CA-018-09).

## 9. Preguntas abiertas

Marcadas con **[Pendiente]** y con quién decide. Cada una lleva mi recomendación y, hasta que el propietario responda, la spec parte de ella como **[Suposición]**.

- **[Resuelto] Q-018-1 · ¿Se tocan los iconos de iOS ahora?** Respuesta del propietario (2026-10-10): «Sí quiero ver los iconos en Android.» **Lectura de esta spec:** el de **Android** se hace y se **ve en el emulador y en el Xiaomi** durante la implementación (C-018-2); **iOS queda fuera** (§8, D17, sin Xcode). **[Suposición]** que no pedía los de iOS; si lo pedía, se avisa antes de aprobar.
- **[Resuelto] Q-018-2 · ¿La web de pruebas lleva el icono nuevo?** «Sí, como recomiendas» (2026-10-10): favicon, 192, 512 y los «maskable» (CA-018-09); se registra como **DEV-55**.
- **[Resuelto] Q-018-3 · La lupa con signo menos de «Bloquear zoom».** «Acepto recomendación» (2026-10-10): **no** se revisa dentro de la 018 (§8).
- **[Resuelto] Q-018-4 · ¿Las compilaciones `debug` y `profile` llevan el mismo icono?** «Sí» (2026-10-10): el mismo icono y el mismo nombre (CA-018-14). Aviso: en el móvil de pruebas seguirán viéndose dos «Una.» iguales.
- **[Resuelto] Q-018-5 · ¿Se toca el manifiesto de la web de pruebas?** «Quiero tocarlo. Que ya se lleve el color de la app y no la de Flutter» (2026-10-10) → CA-018-09: `theme_color` y `background_color` pasan del azul de Flutter a **`palette.classic.0` (`#FFE55C`)**. Pregunté si «el color de la app» era el papel (`#F4F1EA`) o el amarillo del icono: el propietario eligió **el amarillo del icono** (2026-10-10). La descripción de plantilla («A new Flutter project.») **se quita en lugar de escribir otra**, para no crear un texto sin traducir (P7); **confirmado por el propietario el 2026-10-10 («ok»)**.
- **[Hecho]** El original del tablero 17 (PNG) es la **fuente única** (CA-018-10): usa exactamente `#FFE55C` y `#111111`, y su primer plano (432 px) y su capa monocroma (432 px, punto macizo) tienen la misma caja (x 135–297, y 164–268). **[Suposición]** Se convierten a recursos de Android sin dependencias; el plan decide cómo (CA-018-07 fija solo ≥ 432 px).
- **[Suposición]** Que el nombre «Una.» es provisional (`CLAUDE.md`) y, si cambia, el icono se rehace (CA-018-15, CL-018-7).
- **[Suposición]** Que no hace falta icono de baja densidad para Android 7 y anteriores porque el mínimo es Android 8 (D12): **todos** los móviles admitidos pintan iconos adaptables.
- **[Pendiente, 022]** Lo que queda de las casillas del §3 (C-018-7 TalkBack, Android 8–12, otra máscara de esquinas casi rectas y el *splash* oscuro en el Xiaomi): `docs/PLAN.md`, «Casillas de la 018». C-018-2 (Xiaomi, a ojo) y C-018-4 (emulador) ya están hechas.

## 10. Enmiendas a otras specs y documentos (se aplican con la implementación; las marcadas «ahora» se hacen con esta spec)

- **`docs/glossary.md` (ahora):** «Icono de la app», «Icono adaptable», «Icono con tema», «Zona segura» e «Icono de Play».
- **`docs/design/screen-map.md` (ahora):** el tablero 17 pasa a «spec 018 (Aprobada)» (hecho).
- **`docs/PLAN.md` (ahora):** R20 → CA-018-01 a 15 (Aprobada); la fila F4b de la 018; y la fila F5, donde «iconos» queda cubierto por la 018. **`CLAUDE.md` (ahora):** la fase actual indica que la spec de la 018 está en Borrador.
- **`docs/design/prototype-deviations.md`:** **DEV-55** (la web de pruebas lleva el icono nuevo, el color de la app en `theme_color` y `background_color` y sin la descripción de plantilla; el prototipo no la define): **hecho al aprobar la spec (2026-10-10)**.
- **`docs/architecture.md`** (el icono: dónde viven sus recursos y qué mide cada capa; la nota del *splash* de la §2 sobre el icono) y **`docs/testing.md`** (los tests de recursos y su método): al implementar. **Modelo de amenazas y checklist de seguridad:** sin cambios previstos (CA-018-12).
- **021 (nota):** «el fondo de arranque coherente con el icono de la 018» parte de que el icono es amarillo (`#FFE55C`) con la «u.» negra. **Medido (T-018-06 y 08):** el *splash* de Android 12+ pinta solo el primer plano sobre el fondo de siempre (blanco en claro; en oscuro el sistema añade un círculo amarillo); no es amarillo. Si la 021 lo quiere amarillo, lo fija ella.

## 11. Trazabilidad con la constitución

| Principio | Cómo se cumple |
|---|---|
| P1 Una tarea a la vez | No cambia: no se toca ninguna pantalla |
| P2 Instantáneo al abrir | El arranque no empeora (CA-018-13); el icono es un recurso, no código |
| P3 Local y sin conexión | Todo es local y estático; sin red (CA-018-12) |
| P4 Privacidad por defecto | Sin permisos, red, datos ni dependencias nuevos (CA-018-12) |
| P5 Seguridad desde el diseño | Sin código nuevo ni entrada de datos; recursos propios y revisados (CA-018-12) |
| P6 Accesible siempre | Sin interacción nueva; nombre legible por el lector; contraste ≈ 14,9 : 1; la silueta con tema es opaca (CA-018-04, 11; §6) |
| P7 i18n | Sin texto nuevo; el nombre sale de `identity.yaml` (CA-018-11, CL-018-7 y 9) |
| P8 Spec manda | Esta spec; el plan decide el cómo (imagen o vector, carpeta de la tienda) |
| P9 Tests | Cada CA lleva su línea «Verificable»; los de apariencia, casillas de `dispositivo.md` |
| P10 Crecer sin construir el futuro | Sin icono por compilación, alternativo ni animado (§8) |
| P11 Dependencias con criterio | Ninguna (CA-018-12; D29: «a mano») |
| P12 Prototipo como referencia | Tablero 17; lo que no define se decide aquí (DEV-55) |

## 12. Historias de usuario y criterios

Ver la tabla «Trazabilidad HU → CA» del §3.

## 13. Tabla CA → prueba (cierre, 2026-10-11)

**Estado:** **Implementada parcialmente.** Rutas relativas a `app/test/`. «Dispositivo» = `specs/018-iconos/dispositivo.md` (emulador `Pixel_6a` de API 37 y, para el icono a ojo, el Xiaomi de HyperOS el 2026-10-11); lo que sigue sin comprobar en el móvil está en `docs/PLAN.md`, «Casillas de la 018». Abreviaturas: `ic/` = `icon/`. Los tests de recursos leen los PNG con `dart:ui` y no usan el generador (`tool/gen_icons.dart`), de modo que un fallo suyo no se esconde a sí mismo.

| CA / CL | Pruebas | Estado |
|---|---|---|
| 01 El icono en el lanzador | `ic/android_adaptive_icon_test.dart` (ancho 56 % ± 1 pp del círculo de 72 dp, caja centrada ± 1 dp), `ic/icon_image_support_test.dart` (las ayudas, sobre las fuentes del tablero); dispositivo (C-018-1 y 2 en el emulador y en el Xiaomi) | Completo |
| 02 Entero con cualquier máscara | `ic/android_adaptive_icon_test.dart` (todo píxel opaco a ≤ 33 dp; la esquina más lejana a ≈ 24,1 dp; el fondo es un color liso que llena los 108 dp); dispositivo (cinco formas del lanzador de Pixel y la máscara de HyperOS) | Completo; el «cuadrado de esquinas casi rectas» con otro lanzador: 022 |
| 03 Colores = tokens | `ic/android_adaptive_icon_test.dart` (fondo = `palette.classic.0`; primer plano solo tinta, transparencia y suavizado ±10), `ic/icon_image_support_test.dart`, `ic/icon_coherence_test.dart` | Completo |
| 04 Icono con tema | `ic/android_adaptive_icon_test.dart` (`<monochrome>` = el mismo drawable que el primer plano, alfa idéntica por construcción, silueta maciza con el punto); dispositivo (C-018-3, estilo Minimal del lanzador de Pixel y Xiaomi) | Completo; Android 13+ real con el fondo de pantalla del usuario: 022 |
| 05 Sin tema o antes de Android 13 | `ic/android_adaptive_icon_test.dart` (la capa no es un recurso propio); dispositivo (con tema apagado) | Parcial: Android 8–12 sin probar (no hay AVD): 022 |
| 06 Nada del icono de Flutter | `ic/android_icon_packaging_test.dart` (manifiesto → adaptable, sin `ic_launcher.png` ni con los bytes de la plantilla, sin recursos huérfanos), `test/fixtures/flutter_template_icons/`; dispositivo (C-018-6, APK de *release* con `aapt2` y `unzip -l`) | Completo |
| 07 Nítido a cualquier densidad | `ic/android_adaptive_icon_test.dart` (≥ 432 px, cuadrado); dispositivo (C-018-4: 48 y 24 dp, tamaño de visualización máximo) | Completo |
| 08 Icono de Google Play | `ic/play_icon_test.dart` (RGBA de 8 bits, 512 × 512, < 1024 KB, alfa 255, esquinas amarillas, diferencia ≤ 2/255 frente al original reducido, no declarado en `pubspec.yaml` ni en el APK) | Completo |
| 09 La web de pruebas | `ic/web_icons_test.dart` (32/192/512 y maskable, ninguno de la plantilla, esquinas, esquina más lejana ≤ 40 %, `theme_color` y `background_color` = token, sin `0175C2` ni «A new Flutter», nombre, `start_url`, `display` y `orientation` intactos) | Completo |
| 10 Un solo dibujo | `ic/icon_coherence_test.dart` (tabla Android, con tema, Play y web: ancho, centrado, altura, colores, dos piezas y silueta igual al original), `tool/gen_icons_test.dart` | Completo |
| 11 Nombre y accesibilidad | `ic/android_icon_packaging_test.dart` (`@string/app_name` generado de `identity.yaml`; contraste ≈ 14,9 : 1); dispositivo (el nombre bajo el icono) | Completo; TalkBack en el lanzador: 022 |
| 12 Sin dependencias, permisos ni código | `tool/gen_icons_test.dart` (las herramientas solo importan `dart:` y su vecina); diff `main...HEAD` de `lib/`, `.kt`, manifiesto, `pubspec.*`, Gradle, `drift_schemas/` e `ios/` vacío (T-018-05 y cierre); `tools/check-android-permissions.sh` en verde (T-018-03 y 05) | Completo |
| 13 El arranque no empeora | Dispositivo (C-018-5: p50 375 → 367,5 ms alternando 4 × 20 con `tools/measure-cold-start.sh`; *splash* con la «u.» entera) | Completo en el emulador |
| 14 Mismo icono en todas las compilaciones | `ic/android_icon_packaging_test.dart` (`src/debug` y `src/profile` sin recursos de icono); dispositivo (la `.profile` en el Xiaomi lleva el mismo) | Completo |
| 15 Documentado y reproducible | `ic/icon_coherence_test.dart` (la geometría medida), `tool/gen_icons_test.dart` (`--check` y los comandos), `docs/design/app-icon.md` (revisado frente a las medidas) | Completo |
| CL-018-1, 2 | Dispositivo (varias máscaras; con tema apagado) | Completo en el emulador y en el Xiaomi |
| CL-018-3 | Dispositivo (fondo de pantalla del emulador; sin cambio) | Aceptado |
| CL-018-4, 10 | Dispositivo (24 y 48 dp; «Tamaño de visualización» al máximo) | Completo |
| CL-018-5, 9 | Sin test: el icono no depende del modo oscuro ni del idioma (ningún recurso de icono tiene variante `-night`; `values-night` solo tiene el tema; ni textos) | Completo |
| CL-018-6 | Dispositivo (`install -r` desde el de `main`); es del lanzador | Aceptado, sin código |
| CL-018-7 | `docs/design/app-icon.md` («Qué rehacer si cambia el nombre»); sin test | Documentado |
| CL-018-8 | `ic/android_icon_packaging_test.dart` (CA-014); dispositivo | Completo |

**Notas de cierre (revisión de `spec-reviewer`, 2026-10-11)**

- **CA-018-01 (cifra):** el 56 % de 72 dp son 40,3 dp; lo medido es **40,5 dp = 56,25 %** (162 px de 432), dentro de la tolerancia de ± 1 punto. `docs/design/app-icon.md` y los tests usan 56,25 %.
- **CA-018-09 y 10 (favicon):** el favicon de 32 px se mide con ± 3,5 puntos (1 px = 3 puntos); el resto, con ± 1.
- **CA-018-15 (generador):** el script es **Dart** en `app/tool/` (P-018-1, aprobado con el plan), no shell en `tools/`; lo vigila `tool/gen_icons_test.dart` (`--check` sobre el árbol real).
- **CA-018-04 y 07 (capa con tema):** la capa monocroma **es el mismo recurso** que el primer plano (P-018-2), así que su alfa es idéntica y su tamaño el mismo por construcción. La maciza se comprueba con el punto y con que solo el borde (a ≤ 3 px de un píxel vacío) es semitransparente.
- **CA-018-03 (suavizado):** `dart:ui` decodifica premultiplicado, por lo que el RGB de los píxeles con alfa < 128 no es comparable: se comparan los demás; el suavizado de tinta de alfa baja queda cubierto por la igualdad del recurso con el original del tablero (`icon_image_support_test.dart`).
- **CA-018-12:** además del `git diff main...HEAD` manual del cierre, `--check` sobre el árbol real corre ahora en `flutter test`.

