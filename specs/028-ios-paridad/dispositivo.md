# Spec 028 — Pruebas en dispositivo

Resultados en aparatos reales (iPad del propietario). Las filas «Disp» y «VO» de `matriz.md` remiten aquí. Solo tareas ficticias.

## Aparato y forma de instalar

- **iPad de 6.ª generación** (iPad7,5, iPadOS 17.7.1), app «solo iPhone» en modo compatibilidad (`plan-f-ios.md`).
- **Firma gratuita** (equipo personal del propietario). El equipo y un bundle ID de desarrollo se pasan **solo en la línea de `xcodebuild`** (`DEVELOPMENT_TEAM=…`, `PRODUCT_BUNDLE_IDENTIFIER=…`, `-allowProvisioningUpdates`); `project.pbxproj` sigue con `invalid.pending.app` y sin equipo (PD-2). Receta, desde `app/`: `flutter build ios --config-only --release --no-codesign`, luego `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination id=<UDID> … build` y `xcrun devicectl device install app --device <UDID> <Runner.app>`. La firma caduca a los 7 días.
- [Hecho] Para leer el identificador del equipo, el propietario lo elige en Xcode (Signing & Capabilities) y se deshace el cambio de `project.pbxproj` con `git checkout`.

## T-028-20 · Q-028-5 «Una sola a la vez» (CA-019-18, CA-028-16) — 2026-11-22

- **Pasos:** *release* instalada; una tarea ficticia; notificaciones activadas con permiso y **3 al día**; app cerrada desde el selector. Sin abrir la app, la hora del iPad se adelantó a mano a 08:54, 13:54 y 18:54, esperando cada aviso.
- **Resultado [Hecho]:** llegaron los tres avisos, cada uno a su hora, y al final el centro de notificaciones solo tenía **la última**.
- **Conclusión:** Q-028-5 = **«una»**. CA-019-18 se cumple en iOS sin el identificador único; el código de T-028-19 no cambia.
- **[Suposición]** Se probó cambiando la hora a mano, no esperando al día real; no se ve motivo para que iOS se comporte distinto.

## T-028-22 · Simulador completo (CA-028-01, 02, 04, 05, 08) — 2026-11-22

Simulador iPhone 18 Pro, iOS 27.2 (Xcode 27.2), con `/ios-check todos`.

- **Pasada 1, claro y `es-ES` [Hecho]:** build y XCTest (178) en verde; paridad con las 13 secciones activas y ninguna `PENDIENTE`; IT 19 de 20 en verde con sus `skip:` motivados (los 5 `*_perf_test` y los casos del contrato). `image_flow` falló una vez: el test esperaba solo 10 s a que terminara la preparación de la captura de 1080 × 20 000 y guardaba a medias; la espera sube a 30 s y falla de forma explícita si se agota (no cambia lo que comprueba). Repetido: 3 de 3 en verde.
- **Pasada 2, oscuro y `ca-ES, en-US` [Hecho]:** IT 19 de 20 en verde. Bajo el icono sale «Una»; la app abre **en español** y **en claro** (`paper`, barra de estado oscura) con el sistema en oscuro y en catalán (capturas del simulador, no guardadas). Falló `settings_flow`: al volver de «English» a «Como el sistema» la app se quedaba en inglés. **Hallazgo de la I8, arreglado en esta rama** (propietario, 2026-11-22): es Dart de la 015 y pasa igual en Android; Flutter no recalcula el idioma del sistema al cambiar `localeListResolutionCallback`, que solo se pasaba con «Como el sistema»; ahora se pasa siempre (`una_app.dart`, test `locale_change_test.dart`). `settings_flow` 3/3 después.
- **iOS 16: no se prueba** (decisión del propietario, 2026-11-22: «con el que hay basta»). Solo está el runtime de iOS 27.2; la versión antigua la cubre el iPad (iPadOS 17.7.1). El mínimo iOS 16 lo comprueba la sección `project` del script.
- **Modo avión real: no se prueba** (decisión del propietario, 2026-11-22). El simulador no tiene modo avión propio y comparte la red del Mac. Ningún IT usa red externa y la sección `network` del script comprueba que el Swift no la usa.
- **Trampa:** tras `xcodebuild test` el simulador quedó apagado y los IT no encontraban el dispositivo; anotado en `/ios-check`.

## T-028-23 · Bloque 1: arranque (CA-001-09, CA-015-23, CA-028-06) — 2026-11-22

*Release* reinstalada desde `feat/028-i8-cierre` (firma gratuita, bundle ID de desarrollo `dev.svallev.una.local` solo en la línea de `xcodebuild`; `project.pbxproj` sin cambios). Tarea actual: una de texto ficticia (fondo amarillo).

- **Hasta el primer fotograma del sistema [Hecho]:** Instruments (`xctrace record --template 'App Launch' --launch`), 20 arranques en frío seguidos, desde que el proceso empieza hasta el fin de «Initial Frame Rendering»: **p50 353 ms · p90 464 ms** (mín. 283, máx. 785, el primero tras instalar). Ese fotograma es la pantalla de arranque `paper`; Flutter pinta la tarea después y en *release* Instruments no lo marca: en un arranque con Time Profiler el hilo `io.flutter.1.raster` dibuja hacia los ~1,2 s **con el muestreo de Instruments encima** (no vale como cifra).
- **Del toque a ver la tarea [Hecho]:** grabación de la pantalla del iPad con QuickTime (60 fps) de ~16 aperturas desde el icono y análisis fotograma a fotograma (AVFoundation: del primer fotograma en que el icono se oscurece al primero con el fondo de la tarea): **583–617 ms, p50 600 ms** en las 10 aperturas en que el inicio se detecta sin ambigüedad. La cifra coincide con la animación de apertura del sistema: la tarea aparece justo al terminarla, así que la app está lista antes. **CA-028-06 / CA-001-09: se cumple (< 1 s).**
- **[Suposición]** No todas las aperturas del vídeo son en frío (algunas cierran solo con el gesto a inicio, sin el selector); como todas duran lo mismo, el límite es la animación del sistema, no la app. El arranque en frío está medido con Instruments.
- **Sin destello [Hecho]:** en el vídeo, durante la animación solo se ve el fondo liso `paper` (con las franjas negras del modo compatibilidad del iPad, que son del sistema) y después la tarea; ningún fotograma negro ni blanco dentro de la app.
- **Medidas de los `*_perf_test`:** no se ejecutan en el iPad (decisión del propietario, 2026-11-22, opción b: la guarda de los IT solo deja el simulador y `flutter drive` necesita firma en el proyecto). **[Pendiente sin *profile* en aparato]**; se miran a ojo en los bloques siguientes.

### Bloque 1: aspecto, «Recientes» y vuelta (CA-028-05, 07, 12; 011, 021, 024) — 2026-11-22

Observado por el propietario en el iPad, *release*:

- **Sistema en oscuro [Hecho]:** la app se ve en claro (`paper`), y la barra de estado, con iconos oscuros legibles (CA-021-06/07, CA-024-01 a 03, CA-028-05).
- **Arranque con el sistema en oscuro [Hecho]:** solo `paper` y luego la tarea, sin destello (CA-021-01 a 05, CA-028-06).
- **Selector de apps [Hecho]:** la miniatura de Una es un fondo liso `paper`, sin la tarea (CA-011-01/02, CA-015-18, CA-028-12).
- **Vuelta desde el selector [Hecho]:** sin parpadeo ni destello (CA-011-03).
- **Captura de pantalla [Hecho]:** se hace y sale la tarea (CA-011-04).
- **Icono [Hecho]:** bien en la pantalla de inicio, con la máscara del sistema (CA-018, CA-028-07).
- **Vuelta desde segundo plano [Hecho]:** tras ~30 s en otra app vuelve a la misma tarea sin pasos raros (CA-001-12, CA-011-08).

## T-028-23 · Bloque 2: imágenes, cámara y PDF (CA-028-10, 11, 18; 007, 008, 016, 017) — 2026-11-22

Observado por el propietario en el iPad, *release*, con fotos y PDF sin datos personales (no se pasan capturas):

- **Cámara, primera vez [Hecho]:** sale el permiso; con *Permitir* la foto se hace y se ve a pantalla completa (CA-007-02, CA-028-10). **No visto:** qué hay detrás del diálogo de permiso (la [Suposición] de T-028-11 sobre la vista `paper` sigue abierta; no molesta al propietario).
- **Cámara denegada [Hecho]:** con la cámara apagada en Ajustes sale el aviso con «Abrir Ajustes» y lleva a los ajustes de Una (CA-007-02, CA-028-10).
- **Live Photo y HEIC [Hecho]:** una Live Photo y fotos del iPad (HEIC) se guardan y se ven bien, quietas y con su orientación (CA-007-03, CA-007-07).
- **Grupo de 10 [Hecho]:** el selector no deja marcar una 11.ª; el carrusel va fluido (CA-016-01/02, CA-028-11).
- **Giro [Hecho]:** con foto, la tarea gira; con texto, se queda en vertical; con el bloqueo de rotación, la foto se queda en vertical (CA-007-11, CA-008-11 por el mismo canal, CA-016-12, CA-017-10).
- **PDF [Hecho]:** se elige desde Archivos, se ve a pantalla completa y se desplaza bien (CA-008-01). Los enlaces `mailto:`/`tel:` no se probaron (el PDF no los tenía).
- **Memoria (CA-016-23) [Hecho]:** Instruments (*Activity Monitor*, huella física del proceso `Runner`, que incluye la memoria gráfica **[Suposición]**), muestras cada ~1 s. Con **10 fotos**, recorriendo el carrusel: pico **111 MiB** (la grabación cubrió ~25 s de recorrido). Con **una foto**, pellizcando, desplazando y girando 60 s: pico **138 MiB**. El grupo no supera a la foto suelta (la diferencia está dentro de lo que cambia con el giro y el zoom); la app no se cerró. En el Xiaomi el grupo sumaba ≈ +166 MB (ADR-0024); en iOS no se ve ese coste.
- **Copia de seguridad (CA-028-18) [Pendiente, no concluyente]:** en Ajustes → iCloud → Copias, Una no aparece: la app se reinstaló hoy y probablemente aún no hay copia con ella. La exclusión de `attachments/` la cubren los XCTest (`DataAtRestTests`).
- **Clase de protección real:** no se puede leer en una *release* sin depurador; se queda con el XCTest de que no se baja (ADR-0005). **[Pendiente sin herramienta]**.

## T-028-23 · Bloque 3: web (CA-028-05, 13, 19; 009, 015, 021) — 2026-11-23

Sistema en oscuro; observado por el propietario en el iPad, *release*:

- **Web en claro [Hecho]:** con el sistema en oscuro, Wikipedia móvil (que sigue el modo del sistema) se ve con fondo blanco dentro de Una (CA-021-08, CA-028-05/19).
- **Fluidez [Hecho]:** Wikipedia móvil se desplaza con fluidez.
- **Sin navegación [Hecho]:** tocar un enlace de la página no navega (CA-009-11).
- **Descarga bloqueada [Hecho]:** una URL que sirve un PDF muestra el aviso de que no se puede abrir porque no es una página web, no el PDF (`downloadBlocked`, T-028-17).
- **Campo de archivo [Hecho]:** tocar «Elegir archivo» no abre ningún selector ni avisa (script de usuario de T-028-17; cierra su [Pendiente]).
- **Webs desde Ajustes [Hecho]:** política, licencias y ayuda se abren en Safari y se vuelve a Una sin problemas (CA-015-12a/b, 16; CA-028-13).

## T-028-23 · Bloque 4: pantalla, notificaciones y gestos (CA-028-09, 14, 15, 16) — 2026-11-23

Observado por el propietario en el iPad, *release*:

- **Pantalla siempre activa [Hecho]:** con bloqueo automático de 2 min y el ajuste encendido, el iPad no se apaga; con el ajuste apagado, sí se apaga (CA-007-12, CA-015-03 a 04d, `isIdleTimerDisabled`).
- **Aviso con Una delante [Hecho]:** al llegar la hora del aviso con la app abierta, no se muestra (CA-019-19a, `willPresent` sin presentación).
- **Aviso con el iPad bloqueado [Hecho]:** en la pantalla bloqueada se lee «Tarea actual, imagen» (la etiqueta del tipo, sin el texto de la tarea) (CA-019-17, CA-028-16).
- **Tocar el aviso con la app cerrada [Hecho]:** abre Una en la tarea actual (CA-019-20).
- **Matar la app con la card de deshacer [Hecho]:** al cerrar Una desde el selector con la card visible y volver a abrirla, la tarea queda eliminada, sin card (CA-014-13).
- **Gestos [Hecho]:** mantener para completar, arrastrar en «Todas mis tareas» y deslizar desde el borde izquierdo en Ajustes y en el editor funcionan (CA-003-01, CA-006-04/05, CA-002-07, CA-028-09). Sin háptica: el iPad no tiene motor háptico.
- **Zoom de accesibilidad [Hecho]:** con Zoom activado, tocar dos veces con tres dedos amplía bien dentro de Una (CA-017-13).

## T-028-23 · Bloque 5: VoiceOver, permiso de avisos, reinicio y enlaces del PDF (013, 014, CA-028-14; 003, 004, 006, 007, 008, 010, 015, 019) — 2026-11-23

Observado por el propietario en el iPad, *release*, con VoiceOver; tareas ficticias (texto, un grupo de fotos y `tools/fixtures/out/links.pdf` pasado por AirDrop).

- **Acciones del rotor [Hecho]:** «Completar tarea» completa con un solo anuncio y deja el foco en la nueva tarea; el doble toque sobre el botón no completa (CA-003-07). Con un grupo están «Foto siguiente» y «Foto anterior», y se lee la posición de la foto («foto N de N») (CA-016-19/20). «Eliminar tarea» elimina sin hoja y saca la card (CA-004-10, CA-014-19); la card no caduca con el foco, dura unos 10 s con VoiceOver y «Deshacer» lee «Tarea recuperada» con el foco en la tarea (CA-014-06/17/18, CA-028-14). En «Todas mis tareas», las acciones de la fila salen en orden (mover, «Editar tarea», «Eliminar tarea») con un único anuncio al mover (CA-006-16/17).
- **Recorrido [Hecho]:** Ajustes e Idioma sin paradas mudas, en orden título → filas → «Volver» al final (CA-013-04/05).
- **Reducir movimiento [Hecho]:** los botones se hunden al instante, sin animación (CA-013-03).
- **Voz [Hecho]:** con «Como el sistema», texto de la tarea y filas con voz española (CA-010-10); con English en Ajustes, todo en inglés salvo «Español» y «English», cada uno en su idioma (CA-015-11); el aviso en la pantalla bloqueada se lee en inglés con English elegido (CA-019-21).
- **Aviso de cámara [Hecho]:** con el permiso denegado, VoiceOver lee el aviso una vez con el foco en él y «Abrir Ajustes» abre los Ajustes de Una (CA-007-02, CA-028-10).
- **Avisos bloqueados [Hecho]:** con «Permitir notificaciones» apagado en Ajustes de iPadOS, el interruptor de Una se queda apagado, sale «Las notificaciones están bloqueadas…» y el enlace abre los ajustes del sistema (CA-019-08).
- **Tras reiniciar [Hecho]:** con los avisos encendidos, reiniciado el iPad sin abrir Una, el aviso llega a su hora (CA-019-13, CA-028-16).
- **Enlaces del PDF [Hecho]:** `mailto:` pregunta y abre Mail; `tel:` pregunta y no llama; `javascript:`, `file:` e `intent:` no hacen nada (CA-008-12, CA-028-13). Con Mail instalado no hizo falta `LSApplicationQueriesSchemes` (T-028-09).
- **Escape de VoiceOver [Hecho]:** frotar con dos dedos vuelve atrás en Ajustes, Idioma, el editor y «Todas mis tareas» (CA-002-07, CA-028-09).
- **Rechazar el diálogo de permiso (CA-019-07/08) [Pendiente, aceptado]:** no se prueba (propietario, 2026-11-23): para que iPadOS vuelva a preguntar hay que borrar Una y recompilar; el bloqueo ya se comprobó desde los Ajustes del sistema y el caso «rechazo» lo cubren los tests de widgets con el canal falso.
- **Arranque con los avisos encendidos (CA-019-24) [Hecho, aceptado por el propietario]:** Instruments como en el bloque 1, por cable, tras el reinicio de CA-019-13. Encendidos (n = 10): **p50 649 ms** (349–787); apagados justo después (n = 8, cortada por el propietario): **p50 359 ms** (301–545), igual que la línea base del bloque 1 (353 ms). Todos < 1 s. El código no explica la diferencia: antes del primer fotograma el Swift solo pone el delegado de avisos (con el ajuste encendido o apagado) y Dart solo abre la base y lee la tarea; reprogramar va después del primer fotograma. **[Suposición]** es el orden: la serie encendida fue la primera tras el reinicio (y tras una serie por wifi descartada, `xctrace` lanzado sin cable porque el iPad seguía emparejado por la red). No se repitió con los avisos encendidos (propietario, 2026-11-23: «con estas cifras estamos contentos»).
- **Trampa de la medida:** con el iPad bloqueado, `xctrace … --launch` da «Timed out waiting for device to boot»; con conexión por wifi va lento y a veces la traza sale sin datos («run data is missing»). Por cable, desbloqueado, con `--time-limit 15s` y un `devicectl device info lockState` antes de cada grabación, funciona (≈ 2 min por arranque).
