# Spec 028: Una en iOS, igual que en Android (paridad)

- **Estado:** **Implementada** (2026-11-23, T-028-25: matriz de paridad con todas las filas con resultado, pasada en el iPad y revisores sin altos; lo no probado, **[Pendiente]** en `matriz.md`; distribuir, **[Pendiente I9]**). Antes **Aprobada** (propietario, 2026-11-19: «sí, aprobada»). Antes **Borrador** (2026-11-19, fase I1 del plan F-iOS). Revisada por `spec-reviewer` el 2026-11-19 (2 bloqueantes, 6 importantes y menores, **aplicados**; los bloqueantes quedan como preguntas al propietario, Q-028-1 a 6). **Preguntas Q-028-1 a 4 y 6 respondidas por el propietario el 2026-11-19** (§9) y aplicadas (ADR-0030 aceptado; ADR-0031 y ADR-0032 nuevos; constitución 1.11). 
- **Reglas de producto:** las de las specs 001–024, sin cambios salvo lo que diga esta spec.
- **Pantallas del prototipo:** las mismas (`design/prototype/`); ninguna nueva.
- **Decisiones y ADR relacionados:** D17 y PD-7 (= sí, propietario, 2026-11-19); **ADR-0030** (notificaciones en iOS, opción A), **ADR-0031** (deshacer sin tiempo del sistema) y **ADR-0032** (copias en iOS sin adjuntos), los tres **Aceptados** el 2026-11-19; constitución **1.11**; ADR-0004 (copias de seguridad, parte iOS), ADR-0005 (Data Protection), ADR-0013 a 0018 (adjuntos y web), ADR-0019 (selector de apps), ADR-0021 (deshacer), ADR-0025 (notificaciones, parte Android).
- **Dependencias:** specs 001–024 **Implementadas** en Android. Xcode instalado (fase I0, propietario).
- **Documentos de esta spec:**
  - `matriz.md`: la **matriz de paridad** (cada CA de 001–024 que depende de la plataforma → mecanismo Android → mecanismo iOS → cómo se verifica).
  - `docs/ios/channel-contract.md`: el **contrato de los canales** (una ficha por canal, sacada del Kotlin y del Dart).
  - `plan-f-ios.md`: copia del plan F-iOS aprobado el 2026-11-19 (fases I0–I9, modelo por tarea, decisiones del propietario). El `plan.md` y el `tasks.md` de esta spec se escriben **después** de aprobarla (P8).

> Esta spec describe **qué** y **por qué**. El comportamiento de la app ya está fijado por las specs 001–024 y por ~4.500 tests de Dart; el Kotlin es la **implementación de referencia**. Esta spec **no reabre funcionalidades**: dice qué tiene que cumplirse igual en iOS y dónde iOS obliga a divergir.

## 1. Objetivo

Que la app funcione en iPhone **con la misma funcionalidad y el mismo aspecto** que en Android, con el menor trabajo posible: se traduce el código nativo de Android (6 canales y el ocultado del selector de apps, ~3.900 líneas de Kotlin) a Swift y se ajusta la plataforma, sin rediseñar nada.

## 2. Historias de usuario

- **HU-028-1** Como usuario de iPhone, quiero que Una haga lo mismo que en Android (una tarea a la vez, foto, varias fotos, PDF, web, deshacer, Ajustes, idioma, notificaciones) para no tener una versión peor.
- **HU-028-2** Como usuario de iPhone, quiero que la app se comporte como una app de iOS donde el sistema lo espera (permiso de la cámara, gesto atrás, selector de apps, pantalla de bloqueo) sin que cambie su aspecto.
- **HU-028-3** Como propietario, quiero que cada comportamiento de Android tenga su comprobación en iOS, escrita en una sola matriz, para saber qué está verificado y qué no.

## 3. Criterios de aceptación

Los CA son de dos tipos: **por referencia** (CA-028-01 y 02: los de 001–024 se cumplen en iOS según la matriz) y **propios de iOS** (CA-028-03 en adelante: donde iOS obliga a divergir o añade algo que Android no tiene).

### 3.1 Paridad por referencia

- **CA-028-01 Cada fila de la matriz se cumple en iOS**
  - **Dado** la matriz de paridad (`matriz.md`), en la que cada CA de 001–024 que depende de la plataforma tiene su mecanismo iOS y su forma de verificarlo
  - **Cuando** se cierra la spec (fase I8)
  - **Entonces** cada fila tiene un resultado: **Hecho** (con la prueba que lo demuestra: XCTest, test de integración en el simulador, `check-ios-parity.sh` o la pasada en dispositivo), **Diverge** (remite a un CA propio de esta spec que lo sustituye), **No aplica en iOS** (con el motivo) o **[Pendiente]** (con el motivo y cuándo se hará; solo los de §4 «sin iPhone» y los de la tienda, I9). Ninguna fila queda sin resultado.
  - **Verificable:** la matriz al cierre, revisada por `spec-reviewer`.

- **CA-028-02 Lo que es Dart compartido no cambia y se sigue probando igual**
  - **Dado** los CA de 001–024 que **no** dependen de la plataforma (dominio, estado, UI, BD, textos, tokens y fuentes: son Dart compartido)
  - **Cuando** se ejecuta la app en iOS
  - **Entonces** se comportan como en Android sin código propio de iOS, y la suite de Dart (`flutter test`) sigue en verde **sin cambiar lo que comprueba ningún test existente**; solo se **añaden** tests para los cambios de Dart que pide iOS (CA-028-09, 10, 14, 15 y 16; `channel-contract.md` §10). Los **19 tests de integración** (`app/integration_test/`; **20** desde T-028-17, con `web_redirect`) se ejecutan en el simulador de iOS: pasan todos salvo los casos que dependen de un gancho sin equivalente en iOS, que se saltan **con el motivo escrito** en el test y su comprobación sustituta (hoy uno: el recorte con el selector de documentos de `photo_group_import_test`, sustituido por XCTest; `channel-contract.md` §9); **enmienda del plan, propietario, 2026-11-19 (Q-P-1):** además, los **5 tests de rendimiento** (`*_perf_test`, necesitan el modo *profile*) se saltan **solo en el simulador** y sus medidas se toman en el iPad (T-028-23): seis saltados en total. **Excepción también aprobada con el plan:** los cuatro tests que fijaban «iOS sin notificaciones» (CA-019-28) pasan a comprobar lo de CA-028-15 (`plan.md` §5).
  - **Verificable:** CI (`flutter test`) y `flutter test integration_test -d <simulador>` en la fase I8.

- **CA-028-03 Android no cambia**
  - **Dado** todo el trabajo de esta spec
  - **Cuando** se compara la app Android con la de `main` anterior a la 028
  - **Entonces** no cambia nada de lo que se ve ni de lo que hace en Android: los trabajos de Android de la CI siguen en verde, el APK no gana permisos ni dependencias, y el arranque en frío no empeora (P2). Los cambios en Dart que pide iOS (`channel-contract.md` §10) se limitan a ramas de plataforma o a mover a Dart lógica que ya existía, con sus tests.
  - **Verificable:** CI de Android en verde; `tools/check-android-permissions.sh` sin cambios en su lista; el diff de Dart revisado contra §10 del contrato.

### 3.2 Plataforma y aspecto

- **CA-028-04 Solo iPhone, y en un iPad en modo compatibilidad**
  - **Dado** la app de iOS
  - **Cuando** se instala
  - **Entonces** es una app **solo de iPhone** (D17 + decisión 6 del propietario, 2026-11-19): en un iPad se abre en el modo de compatibilidad de iPhone, sin diseño propio de iPad. La versión mínima es **iOS 16**.
  - **Verificable:** `check-ios-parity.sh` lee la familia de dispositivos y la versión mínima del proyecto; en el iPad de 6.ª generación (iPadOS 17.7.1) se abre en compatibilidad; los tests de integración pasan también en un simulador con **iOS 16** (si el runtime está disponible; si no, **[Pendiente]** y se anota en `dispositivo.md`).

- **CA-028-05 Siempre en claro (paridad con la 021)**
  - **Dado** el sistema en modo oscuro
  - **Cuando** se usa cualquier pantalla de la app, se cambia de modo con la app abierta o se carga una tarea web con versión oscura
  - **Entonces** se cumple lo mismo que CA-021-06, 07 y 08: la app se ve **igual que en claro**, no se reinicia ni pierde estado, y la página de la tarea web se ve en su versión clara. Las barras del sistema (hora, batería, indicador de inicio) son **legibles** sobre `paper` y sobre las hojas y la card de deshacer (como CA-021-09 y CA-024-01 a 03).
  - **Verificable:** `check-ios-parity.sh` (estilo fijo en claro en `Info.plist`); test de integración en el simulador con el sistema en oscuro; pasada en dispositivo.

- **CA-028-06 Arranque en `paper`**
  - **Dado** la app cerrada, con el sistema en claro o en oscuro
  - **Cuando** se abre desde el icono
  - **Entonces** hasta el primer fotograma de la app solo se ve un **fondo liso `paper`, sin icono** (como CA-021-03, la variante de Android 8–11), nunca negro ni blanco; el color es exactamente el de `paper` en `design/tokens.json` (como CA-021-04). El arranque en frío hasta ver la tarea actual es **< 1 s** en el iPad de 6.ª generación con una compilación *release* o *profile* (P2), medido como en `docs/perf/baseline.md`.
  - **Verificable:** `check-ios-parity.sh` compara el color de la pantalla de arranque con `paper`; medición en el iPad (n ≥ 20) en I8.

- **CA-028-07 El icono es el de la 018**
  - **Dado** la app instalada
  - **Cuando** se ve en la pantalla de inicio, en Ajustes y en Spotlight
  - **Entonces** el icono es el de la 018 (`design/prototype/assets/icon/icon-1024.png` y sus tamaños derivados), **sin ningún icono de la plantilla de Flutter** en el proyecto de iOS (cierra la nota de iOS de CA-018-06). Sin transparencia (iOS la rechaza en el icono).
  - **Verificable:** un test o `check-ios-parity.sh` compara los bytes de los iconos con los de la plantilla de Flutter (ninguno igual) y comprueba que salen del dibujo de la 018.

- **CA-028-08 Idioma: lo de la app y lo del sistema**
  - **Dado** el sistema en cualquier idioma, o el idioma elegido en Ajustes (015)
  - **Cuando** se usa la app
  - **Entonces** la app sigue las mismas reglas que en Android (CA-010-01 a 12, CA-015-06 a 11): español o inglés, `ca-*` abre en español y `gl`/`eu` en inglés. Lo que **muestra iOS por su cuenta** (el nombre de la app bajo el icono, el texto del permiso de la cámara y el de notificaciones si lo hay) está en **español e inglés** y sigue la **misma regla**: con `ca-ES, en-US` sale en español (como CA-024-04). El nombre de la app sale de `app/identity.yaml` (P7), nunca literal.
  - **Verificable:** `check-ios-parity.sh` comprueba que el proyecto declara `es` y `en` (y la correspondencia de `ca`) y que cada texto del sistema existe en los dos; en el simulador, con `ca-ES, en-US`.

- **CA-028-09 El gesto atrás de iOS, con el mismo aspecto**
  - **Dado** cualquier pantalla a la que en Android se vuelve con el gesto o el botón atrás (Ajustes y sus páginas, el listado, el editor)
  - **Cuando** el usuario desliza desde el borde izquierdo
  - **Entonces** vuelve atrás **igual que con el atrás de Android**, con las mismas reglas (el editor con cambios sin guardar pide lo mismo que en Android, CA-002-07 y CA-005-05; la tarea actual no tiene «atrás»). Lo **visual es idéntico** a Android: mismas transiciones, tokens y fuentes, sin la transición propia de iOS (decisión 5 del propietario). **Durante el arrastre** se ve la transición de Android avanzando con el dedo; si se suelta antes de la mitad, vuelve sin cambiar de pantalla. Se registra como desviación del prototipo en `docs/design/prototype-deviations.md` (el gesto no está en el prototipo).
  - **Verificable:** test de widgets con la plataforma iOS (gesto desde el borde → misma ruta que el atrás de Android); entrada nueva en `prototype-deviations.md`.

### 3.3 Adjuntos

- **CA-028-10 Hacer foto: iOS pide permiso para la cámara** *(diverge de CA-007-02)*
  - **Dado** la hoja «Añadir a la tarea»
  - **Cuando** el usuario elige «Hacer foto» por primera vez
  - **Entonces** iOS pregunta si la app puede usar la cámara (en iOS no hay forma de abrir la cámara sin ese permiso), con el texto de §7 en el idioma del sistema según CA-028-08: «Para hacer la foto de una tarea.» **Concedido:** sigue igual que CA-007-02 (la foto pasa la misma validación y no queda ninguna otra copia de lo que escribió la cámara). **Denegado ahora o antes:** la hoja se cierra y se ve el aviso `errCameraDenied` con el botón `errCameraDeniedOpenSettings`, que abre los Ajustes de la app en el sistema (Q-028-1); nada más cambia. **Sin cámara** (el simulador): el mismo aviso que hoy (`errNoCamera`, CL-007-1). La app **no pide ningún otro permiso** para las fotos ni para los PDF. El aviso nuevo es **accesible como los demás avisos de error** (CA-007-22): se anuncia al aparecer, el foco va a él y su botón mide ≥ 44 pt, con texto grande al 200 % sin cortarse.
  - **Verificable:** XCTest del manejo de los estados del permiso; test de widgets del aviso (anuncio, foco, tamaño, 200 %); `check-ios-parity.sh` (la **única** descripción de uso que declara el proyecto es la de la cámara: iOS no pide descripción para las notificaciones); en el iPad: conceder, denegar, volver a intentar, con VoiceOver.

- **CA-028-11 Galería y PDF sin permisos, con los mismos límites**
  - **Dado** «Subir imagen», «Subir imágenes» o «Subir PDF»
  - **Cuando** el usuario elige
  - **Entonces** se cumplen CA-007-03, CA-016-02 y CA-008-01 **sin pedir ningún permiso** (selector de fotos y de documentos del sistema): como mucho **10 fotos**, en el orden elegido, recortado **antes de abrir ninguna** (CA-016-24); HEIC se admite; la copia, la limpieza (sin metadatos, orientación aplicada, sin la parte de vídeo de una Live Photo), los límites de bytes y píxeles y los errores son los de Android (`channel-contract.md` §2).
  - **Verificable:** XCTest con los casos JUnit portados (tope, copia acotada, cancelar, limpieza); tests de integración de imagen, grupo y PDF en el simulador; en el iPad, una Live Photo y una foto HEIC.

### 3.4 Selector de apps, pantalla y enlaces

- **CA-028-12 Selector de apps sin contenido (paridad con la 011)** *(diverge de CA-011-07, que dejaba iOS como antes)*
  - **Dado** la app con cualquier pantalla abierta
  - **Cuando** el usuario abre el selector de apps o la app pasa a segundo plano
  - **Entonces** la miniatura de la app **no enseña contenido**: solo `paper` (CA-011-01 y 02). Las capturas y grabaciones con la app delante **siguen permitidas** (CA-011-04). Al volver no hay parpadeo de otro color (CA-011-03, CA-021-12) y se aplica CA-001-12 (10 minutos).
  - **Verificable:** test de integración o XCTest de la vista que tapa (aparece al pasar a inactiva, se quita al volver); en el iPad, el selector de apps.

- **CA-028-13 Pantalla encendida, giro y enlaces**
  - **Dado** las mismas situaciones que CA-007-12, CA-008-11, CA-008-13, CA-009-15, CA-009-16, CA-015-03 a 04d, CA-016-12, CA-017-10, CA-008-12 y CA-015-12a/b
  - **Cuando** se usan en iOS
  - **Entonces** se cumplen igual: la pantalla no se apaga mientras se ve un adjunto o con «Pantalla siempre activa», y se suelta al salir; **solo** la tarea actual con imagen, varias fotos, PDF o web gira, y el bloqueo de orientación del sistema la deja en vertical; los enlaces (`https`, `mailto:`, `tel:`) se abren con la app del sistema y, si no hay app que los abra, se dice como en Android.
  - **Verificable:** XCTest de `una/screen` y `una/links`; tests de integración en el simulador; giro **[Pendiente sin iPhone]** (§4).

### 3.5 Deshacer

- **CA-028-14 Duración de la card de deshacer en iOS** *(CA-014-06; ADR-0021)*
  - **Dado** la card de deshacer
  - **Cuando** aparece en iOS
  - **Entonces** dura **4 s** sin tecnología de apoyo y **10 s** con VoiceOver o Control por botón activos (iOS no tiene «Tiempo para actuar»; es la misma regla que Android 8 y 9; ADR-0031, Q-028-2). Con VoiceOver, la card no caduca mientras tiene el foco (CA-014-17), como ya hace hoy la rama de iOS de la card.
  - **Verificable:** test de `UndoDuration` con los hechos de iOS (sin recomendado, servicio activo → 10 s); XCTest de `una/a11y`; en el iPad con VoiceOver.

### 3.6 Notificaciones (ADR-0030)

- **CA-028-15 Notificaciones en iOS: lo que es igual** *(diverge de CA-019-28: la fila se muestra en iOS)*
  - **Dado** la fila de Notificaciones de Ajustes (019)
  - **Cuando** se usa en iOS
  - **Entonces** la fila **se muestra** (enmienda CA-019-28 para iOS) y se cumplen igual CA-019-01 a 10, 12, 15, 19a, 19b, 20, 21 (texto en el idioma de la app), 24 a 27 y 29: permiso pedido solo al encender (P5), aviso y botón si están bloqueadas, interruptor que refleja al sistema, 1, 2 o 3 al día a las 08:55, 13:55 y 18:55, sin tareas no se notifica, una sola a la vez, con la app a la vista no se notifica, al abrir se quita, tocarla abre la tarea actual, sin red ni esquema nuevo, arranque sin degradar.
  - **Verificable:** tests de Dart del programador (CA-028-16); XCTest del canal; en el iPad: encender, denegar, bloquear desde el sistema, recibir con la app cerrada, a la vista, tocar.

- **CA-028-16 Notificaciones en iOS: lo que cambia** *(diverge de CA-019-11, 13, 14, 16, 17, 22, 23 y 30; ADR-0030)*
  - **Dado** el interruptor encendido
  - **Cuando** la app programa los avisos
  - **Entonces**:
    - **Texto calculado en Dart y programado por adelantado:** la etiqueta (texto de la tarea recortado, «Foto», «Imagen», «PDF» o el dominio, con las reglas de CA-019-16) y el título los calcula **Dart**, con los textos de los ARB, y se programan con la hora del día. Se **reprograman** cada vez que cambia la tarea actual (crear, editar, completar, eliminar, deshacer, reordenar), el idioma, el interruptor o la cantidad, y al arrancar la app. Así el aviso enseña la tarea actual en el momento de la última reprogramación, que es la misma que al llegar la hora salvo que algo cambie la BD sin pasar por la app (p. ej. una restauración: se corrige al abrirla).
    - **Excepción a CA-019-23 (y a la nota de P4 y a T-2):** el texto de la tarea actual **sale de la BD** a la programación del sistema (los avisos pendientes de iOS) mientras el interruptor está encendido. Nada más: ni ajustes, ni caché, ni registros. Al completar o eliminar la tarea, o al apagar, ese texto se borra de la programación **en ese momento**.
    - **Hora exacta** (sin la ventana de CA-019-11); **iOS los conserva** al reiniciar, cambiar la hora o el huso y actualizar la app, sin código propio (CA-019-13); un aviso perdido con el móvil apagado **no se recupera** (CA-019-14 no aplica).
    - **Sin canal** de notificaciones (CA-019-22): no hay nada que nombrar en Ajustes del sistema; sin sonido propio ni insignia.
    - **Pantalla de bloqueo** (CA-019-17): con la opción por defecto de iOS («Mostrar previsualizaciones: si está desbloqueado») la pantalla de bloqueo **no** enseña la tarea; en su lugar va el texto genérico («Tienes una tarea pendiente.»). La línea de privacidad de Ajustes (CA-019-29) usa en iOS su propia versión, `settingsNotificationsPrivacyIos` (§7, Q-028-3).
    - **Antes del primer desbloqueo** (CA-019-30): no aplica; iOS ya tiene el texto programado.
    - **Una sola a la vez** (CA-019-18): al reprogramar y al abrir la app se quitan las entregadas. En el iPad se comprueba si, sin abrir la app, llegan a juntarse varias en el centro de notificaciones. Resultado **«una»** → CA-019-18 se cumple; resultado **«hasta 3»** → el propietario decide en I6 entre aceptarlo (se anota aquí como divergencia) o programar con un único identificador (Q-028-5). **[Hecho, 2026-11-22]** Resultado: **«una»** (Q-028-5).
  - **Verificable:** tests de Dart del programador con un reloj y un canal falsos (qué se programa, cuándo se reprograma, que se cancela todo al apagar o sin tareas, que la etiqueta cumple CA-019-16 y 21); XCTest del canal (solo programa lo que recibe, sin guardar nada más); en el iPad: cambiar la tarea y ver el aviso siguiente con la nueva, reiniciar y recibirlo, pantalla de bloqueo con la opción por defecto.

### 3.7 Privacidad, seguridad y datos

- **CA-028-17 Manifiesto de privacidad y nada nuevo que salga**
  - **Dado** la app de iOS
  - **Cuando** se revisa el proyecto y la compilación
  - **Entonces** lleva un **manifiesto de privacidad** que declara: sin rastreo, sin dominios de rastreo, **ningún dato recogido**, y la razón de cada API de «motivo obligatorio» que use el código propio (p. ej. espacio libre en disco para `freeSpace`); los paquetes de Flutter que lo necesiten traen el suyo. Sin red salvo la página que pide el usuario y las webs de Ajustes (P4, ADR-0016, ADR-0026); sin analítica ni informes de errores; sin registrar URI, rutas, nombres, metadatos ni texto de tareas (CL-007-10, CL-009-9, CA-019-23 salvo su excepción).
  - **Verificable:** `check-ios-parity.sh` (el manifiesto existe y es válido); `security-reviewer` sobre el Swift en I8; `/security-check`.

- **CA-028-18 Datos en reposo y copias de seguridad (ADR-0004, ADR-0005)** *(enmienda la parte iOS del ADR-0004: ADR-0032)*
  - **Dado** la BD, los adjuntos y los archivos de preparación
  - **Cuando** el iPhone está bloqueado o hace su copia de seguridad
  - **Entonces** la BD y los adjuntos usan la protección de datos por defecto de iOS («hasta el primer desbloqueo», ADR-0005); la BD **entra** en la copia de iCloud o del ordenador; los adjuntos y lo temporal (la preparación de una importación) **no**. **Como en Android** (Q-028-6, ADR-0032): los adjuntos **no** entran en la copia (la carpeta de adjuntos se marca como excluida); al restaurar en otro iPhone, sus tareas muestran «Adjunto no disponible» (CA-007-19, CA-016-18a/b). Ningún archivo propio se guarda fuera de las carpetas de la app.
  - **Verificable:** XCTest o test de integración que lee la clase de protección y la exclusión de copia de los archivos que crea el Swift; nota en `docs/environments.md`.

- **CA-028-19 La web en iOS: mismo aislamiento**
  - **Dado** una tarea web (009)
  - **Cuando** se carga en iOS
  - **Entonces** se cumplen CA-009-06 a 16 y la parte web de CA-021-08 con el motor de iOS: solo la dirección guardada, sin navegación (ADR-0018), sin descargas (se dice «no es una página»), sin ventanas nuevas, sin depuración en *release*, nada de la página se queda en el móvil al salir ni tras cerrar la app (CA-009-13), y si muere el proceso de la página la app no se cierra y la tarea se recupera (ADR-0017).
  - **Verificable:** XCTest de `una/webview`; `web_flow_test`, `web_page_controller_test` y `webview_hardening_test` en el simulador; en el iPad, una página con modo oscuro y una descarga.

### 3.8 Verificación y herramientas

- **CA-028-20 Comprobaciones automáticas de paridad**
  - **Dado** el repositorio
  - **Cuando** corre la CI
  - **Entonces** el trabajo de iOS, además de compilar sin firmar como hoy, ejecuta **XCTest** del código Swift, `tools/check-ios-parity.sh` (cada método de cada canal Kotlin tiene su caso en Swift; claves de `Info.plist`; manifiesto de privacidad; idiomas; familia de dispositivos; color de arranque) y, si cabe en el tiempo de la CI, los tests de integración en el simulador. Un método nuevo en Kotlin sin su caso en Swift **falla** la CI.
  - **Verificable:** un cambio de prueba que quita un caso de Swift hace fallar el script (test del propio script).

- **CA-028-21 Pasada en dispositivo y con VoiceOver, una sola vez**
  - **Dado** las fases I2 a I7 hechas
  - **Cuando** se cierra la spec (I8)
  - **Entonces** hay **una** pasada en el iPad de 6.ª generación con la matriz (las filas marcadas «Disp») y con **VoiceOver** en los flujos principales (primer uso, crear, completar, eliminar y deshacer, listado y reordenar, foto, varias fotos, PDF, web, Ajustes, notificaciones), con `a11y-reviewer` sobre lo que cambie en Dart. Los resultados quedan en `specs/028-ios-paridad/dispositivo.md`, con el mismo formato que la 022.
  - **Verificable:** `dispositivo.md` con todas las filas «Disp» con resultado.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-028-1 | La app se abre en un iPad en compatibilidad | Funciona como en un iPhone; sin diseño propio de iPad (CA-028-04). |
| CL-028-2 | Permiso de cámara denegado y el usuario vuelve a tocar «Hacer foto» | El aviso de CA-028-10, sin volver a preguntar (iOS no deja). |
| CL-028-3 | Permiso de cámara restringido (control parental) | Igual que denegado. |
| CL-028-4 | Se eligen más de 10 fotos con un selector que no respeta el tope | Se recortan a 10 antes de abrir ninguna (CA-016-24). |
| CL-028-5 | Una foto de la galería está solo en iCloud y no hay red | La copia falla como `unreadable` (igual que un proveedor en la nube en Android), sin bloquear; cancelar la corta. |
| CL-028-6 | Notificaciones encendidas y el usuario las bloquea en Ajustes del sistema | El interruptor lo refleja al volver (CA-019-09); los avisos programados no salen. |
| CL-028-7 | Se restaura una copia de seguridad en otro iPhone | Los avisos programados no viajan: se programan al abrir la app; hasta entonces no hay avisos. |
| CL-028-8 | «Como el sistema» y el usuario cambia el idioma del iPhone con la app cerrada | Los avisos ya programados siguen en el idioma anterior hasta abrir la app (residual del ADR-0030). |
| CL-028-9 | El proceso de la página web muere (memoria) | La app sigue viva; la tarea web se recupera como en ADR-0017. |
| CL-028-10 | Sin iPhone para probar | Lo que solo se ve en un iPhone (giro, CA-008-11; tacto en pantalla pequeña; pantalla de bloqueo de iPhone) queda **[Pendiente]** hasta antes de publicar (decisión 2 del propietario). |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Cámara sin permiso | CA-028-10 | `errCameraDenied` con el botón «Abrir Ajustes». |
| Cámara no disponible | Simulador o dispositivo sin cámara | `errNoCamera`, como hoy. |
| Notificaciones bloqueadas | CA-019-08 | Lo mismo que en Android (`settingsNotificationsBlocked` y el botón a los Ajustes del sistema). |
| Resto de errores | Importación, web, guardar | Los de 007–019, con los mismos códigos de canal (`channel-contract.md`). |

## 6. Accesibilidad

- Todo lo de 001–024 (P6, WCAG 2.2 AA, excepciones de la constitución) se cumple con **VoiceOver** y **Control por botón** como con TalkBack y Switch Access. La pasada única con VoiceOver es CA-028-21.
- El gesto atrás (CA-028-09) tiene la alternativa de siempre: el botón «atrás» visible de cada pantalla y el gesto de escape de VoiceOver (frotar con dos dedos).
- La duración de la card de deshacer con VoiceOver o Control por botón: CA-028-14.
- Las excepciones de P6 que dependen de la plataforma (voz del sistema, ADR-0020 y 0023) se comprueban igual en VoiceOver; si VoiceOver se comporta distinto, se anota en `dispositivo.md` y se decide en I8.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| (texto del permiso de cámara de iOS) | «Para hacer la foto de una tarea.» | «To take the photo for a task.» | No es un ARB: va en los textos del sistema del proyecto iOS (CA-028-08). |
| `errCameraDenied` (nueva) | «La cámara no tiene permiso. Puedes darlo en los Ajustes del iPhone.» | «The camera has no permission. You can allow it in iPhone Settings.» | Aviso de CA-028-10. |
| `errCameraDeniedOpenSettings` (nueva) | «Abrir Ajustes» | «Open Settings» | Botón del aviso. |
| `settingsNotificationsPrivacyIos` (nueva) | «La notificación muestra tu tarea actual. Con el iPhone bloqueado, iOS solo la enseña si permites las previsualizaciones siempre.» | «The notification shows your current task. When your iPhone is locked, iOS only shows it if you always allow previews.» | Versión iOS de `settingsNotificationsPrivacy` (CA-028-16). |

Los textos de la notificación (`notificationTitle`, `notificationPublic`, `attachmentPhoto`…) ya están en los ARB; en iOS los usa Dart directamente.

## 8. Fuera de alcance

- **Publicar en App Store** (I9): cuenta de Apple Developer, bundle ID definitivo (PD-2), App Store Connect, etiquetas de privacidad, capturas, TestFlight y un modo iOS en `release.yml`.
- **Diseño propio de iPad**, widgets, Siri, atajos, Live Activities, Apple Watch.
- **Funcionalidades nuevas** o cambios de producto en Android.
- La **web** (`svallev/una-web`): solo cambiará el «Muy pronto en App Store» si el propietario lo decide al cerrar (I8).

## 9. Preguntas abiertas

Respondidas por el propietario el 2026-11-19 («1. ok, 2. ok, 3. ok, 4. ok, 5. Que se comporte igual que Android»):

- **Q-028-1 [Resuelta: ok]** Textos del permiso de cámara y del aviso con botón «Abrir Ajustes», como se proponían (§7).
- **Q-028-2 [Resuelta: ok]** 10 s con VoiceOver o Control por botón en iOS (CA-028-14): **ADR-0031**, que enmienda el ADR-0021.
- **Q-028-3 [Resuelta: ok]** Línea de privacidad de iOS como se proponía (§7).
- **Q-028-4 [Resuelta: ok]** **Constitución 1.11**: notas de P4 (ADR-0030) y P6 (ADR-0031).
- **Q-028-6 [Resuelta: igual que Android]** Los adjuntos **no** entran en la copia de seguridad de iOS (CA-028-18): **ADR-0032**, que enmienda la parte iOS del ADR-0004.
- **Decisión del propietario (2026-11-20), sobre el aviso de CA-028-10** (sin cambiar el texto del CA): «el foco va a él» es al **propio aviso** (texto y botón «Abrir Ajustes» como un solo nodo), no a (+) como en los demás avisos de CA-007-22; y el aviso es del editor: **al salir de él** (atrás, gesto atrás, guardar) se cierra y no queda en la pantalla de debajo, también cuando no caduca (lector o teclado).
- **Enmienda de CA-028-01 (propietario, 2026-11-23, al cerrar en T-028-25):** además de los casos «sin iPhone» y los de la tienda (I9), quedan como **[Pendiente]** con su motivo estas pruebas en el iPad, sin bloquear el cierre: VoiceOver con «Seleccionado» en los grupos de radio (CA-015-07, R1), el aviso de la cámara con teclado y VoiceOver tras R4 (CA-007-02), un PDF real del selector tras R5 (CA-008-01), Control por botón y teclado externo en la card (CA-014-17/18/20), una restauración real de iCloud (CA-028-18) y rechazar el diálogo de permiso de avisos (CA-019-07/08, ya aceptado en T-028-23). Están en `matriz.md` y en `dispositivo.md` («Pendiente al cerrar»).
- **Q-028-5 [Resuelta: «una», 2026-11-22]** «Una sola a la vez» (CA-019-18): en el iPad (T-028-20, `dispositivo.md`), con 3 avisos al día y sin abrir la app, llegaron los tres a su hora y al final el centro de notificaciones solo tenía **la última**. CA-019-18 se cumple; no hace falta el identificador único.
