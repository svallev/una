# Plan técnico — Spec 022: Auditoría en dispositivo

- **Spec:** `specs/022-auditoria-en-dispositivo/spec.md` (estado: **Aprobada**, 2026-10-16)
- **ADR aplicables:** ADR-0013, 0019, 0020, 0021, 0022, 0023, 0024 y 0025 (se comprueban, no se cambian). ADR-0019 y ADR-0021 reciben **una nota de estado** cada uno (CA-022-06), sin cambiar la decisión. **Sin ADR nuevo.**
- **Estado del plan:** **Aprobado** por el propietario el 2026-10-16 («acepto el plan con la recomendación de la P-022-1 incluida»). Antes **Borrador** (2026-10-16). Revisado por `a11y-reviewer` (1 alto, 6 medios y 3 bajos, aplicados: el método para leer lo que dice TalkBack en el emulador, TalkBack con Switch Access a X4, el permiso rechazado de verdad, «Todo hecho.» al final de X1, lo esperado en el guion, el estado inicial completo, la tabla de gravedad y tres de preparación) y por `security-reviewer` (1 alto, 5 medios y 2 bajos, aplicados: `-s` en todas las órdenes y el Xiaomi desconectado en el bloque D, más ajustes en el estado inicial y restaurar al valor apuntado, restaurar cada día en X7, capturas y volcados con `exec-out` y nunca con la *release* delante, el lanzamiento de la `.profile` en las medidas, la carpeta de las fotos y el commit antes de `release.yml`).

## 1. Resumen del enfoque

La 022 **no cambia código** (CA-022-05): solo escribe en `specs/`, `docs/` y `CLAUDE.md`. El trabajo es de tres clases:

1. **Registro sin dispositivo** (bloques B, C y el cierre F): anotar lo cerrado por decisión del propietario, lo ya cumplido por la CI y lo que el propietario vio el 2026-10-15. Lo hace un `spec-task`.
2. **Emulador** (bloque D): el emulador `Pixel_6a_api37_root` con la *release* del commit auditado. Lo hace un `spec-task` por tarea, sin el propietario.
3. **Xiaomi** (bloque E): **sesiones guiadas** con el propietario. Las hace **el coordinador** (los `spec-task` no usan el móvil: memoria «Xiaomi desde el coordinador»).

**Commit auditado:** `2e835cf` (la cabeza de `main` hoy, 2026-10-16; es el que el propietario ya tiene instalado en *release* en el Xiaomi). La rama `feat/022-auditoria-en-dispositivo` sale de `docs/022-spec` (que es `main` + la spec) y no toca `app/`, así que compilar desde la rama da el mismo APK que desde `main`. Si se fusiona en `main` algo que toque `app/`, se aplica CL-022-9.

**Dónde se anota cada resultado (CA-022-03):**

- en el `dispositivo.md` de la spec de origen, en una sección nueva al final, **«Auditoría 022»**, con una línea por casilla: `- **<casilla>** — <Pasa|Falla|Aceptada|Cerrada sin verificar> · <fecha> · <entorno> · <evidencia>` (y el motivo con las palabras del propietario si es Aceptada o Cerrada sin verificar);
- en `docs/PLAN.md`, en la sección «Casillas de la 0NN», cambiando cada **[Pendiente]** por el resultado y un enlace a la línea del `dispositivo.md`;
- en `specs/022-auditoria-en-dispositivo/informe.md`: la tabla de inventario (una fila por casilla) y la lista de hallazgos H-022-NN.

El **inventario** de casillas (todas las de los bloques B a E, con su ID estable `K-022-NNN`, su spec de origen, su CA-022 y su entorno) se construye en T-022-01, leyendo `docs/PLAN.md` y los `dispositivo.md` de 011–021. Desde entonces **la tabla del informe es la lista de trabajo**: cada sesión toma sus filas y las rellena. La spec ya agrupa las casillas por CA; el inventario solo las parte en filas.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio, datos, estado, presentación, nativo, l10n | — | **Ninguno** (CA-022-05) |
| Documentación de la 022 | `specs/022-auditoria-en-dispositivo/informe.md` (nuevo) | Cabecera (commit, versiones de HyperOS y TalkBack, entornos, restauración de cada sesión), inventario, hallazgos |
| Specs de origen | `specs/011…021/*/dispositivo.md`, cabeceras de `spec.md` de 011, 013–019 y 021 | Sección «Auditoría 022»; estado al cierre (CA-022-31) |
| ADR | `docs/adr/0019-*.md`, `docs/adr/0021-*.md` | Nota de estado (CA-022-06) |
| Seguridad | `docs/security/threat-model.md` | Mecanismo B de «Recientes» sigue **[Suposición]** (CA-022-06) |
| Plan y fase | `docs/PLAN.md`, `CLAUDE.md` | Casillas, PD-10, PD-11, R-24 a 26, trazabilidad, §9 (CA-022-32) |
| Medidas | `docs/perf/baseline.md` | Sección «Auditoría 022 en el Xiaomi» (CA-022-29) |
| Glosario | `docs/glossary.md` | Los 6 términos de la nomenclatura de la spec |

## 3. Modelo de datos y migraciones

Sin cambios.

## 4. Dependencias nuevas

Ninguna. Herramientas que ya existen: `tools/check-recents.sh`, `tools/measure-cold-start.sh`, `integration_test/task_list_perf_test.dart` (`UNA_PERF_PHOTOS`), `adb`, `gh`.

## 5. Estrategia de verificación

No hay tests nuevos: cada CA se verifica **leyendo el registro** (spec §3). Las sondas de integración temporales que haga falta escribir en el emulador (por ejemplo, para llegar a un estado con TalkBack) **no se suben** (CA-022-05): se escriben en el *scratchpad* o se borran antes del commit, y cada tarea comprueba `git diff --stat main...HEAD -- app tools design .github` vacío.

| Criterio | Cómo se verifica | Tarea |
|---|---|---|
| CA-022-01, 01a, 02 | Cabecera del informe y su apartado «Restauración» por sesión | T-022-01 y cada sesión |
| CA-022-03 | Inventario sin filas vacías; `grep -n '\[Pendiente\]'` en las secciones «Casillas de la 0NN» de `PLAN.md` sin resultado | T-022-15 |
| CA-022-04 | Cada fila «Falla» enlaza un H-022-NN con sus 5 campos | Cada sesión; T-022-14 |
| CA-022-05 | `git diff --stat main...HEAD` solo en `specs/`, `docs/`, `CLAUDE.md` (y las skills de proyecto `caveman` y `ponytail`, enmienda del 2026-10-19) | Cada tarea; T-022-15 |
| CA-022-06 a 08, 10 | Notas en specs, ADR, `threat-model.md` y `PLAN.md` | T-022-02 |
| CA-022-09 | Ejecución 38761348413 (ver §5.1) | T-022-02 |
| CA-022-09a | Ejecución de `release.yml` en modo testers en verde | T-022-03 |
| CA-022-11 a 16b | Resultado en el `dispositivo.md` de origen | T-022-04 a 06 |
| CA-022-17 a 30a | Resultado en el `dispositivo.md` de origen; medidas en `baseline.md` | T-022-07 a 13 |
| CA-022-25 | Aceptada con el resultado del emulador (Q-022-3) | T-022-02 |
| CA-022-31 a 33 | Cabeceras de las specs, `PLAN.md`, `CLAUDE.md`, informe | T-022-14 |

### 5.1 La ejecución de la CI de `main` (CA-022-09) **[Hecho, 2026-10-16]**

`gh run view 38761348413`: CI sobre `2e835cf9`, **success**. Corrieron (sin saltarse) el paso **«Tests (unitarios, widgets, goldens, migraciones, l10n, tokens)»** del trabajo de Flutter en Linux (incluye los *goldens* de la 013, 015, 017 y 019 y las suites en oscuro de la 021) y **«Licencias completas y archivo de avisos (spec 015, CA-015-14b)»** del trabajo de Android. No hace falta relanzar la CI. T-022-02 comprueba además que los PNG `settings_lockzoom_*` y `settings_notifications_*` están en el repositorio.

## 6. Cómo se hace

### 6.1 Reglas comunes de todas las sesiones en el Xiaomi (CA-022-01a, 02)

- **Antes de empezar:** el propietario da permiso **en esa sesión**. Se apunta en el informe: fecha, `getprop ro.mi.os.version.name` (HyperOS), `getprop ro.build.version.release`, versión de TalkBack (`dumpsys package com.google.android.marvin.talkback | grep versionName`) y de Switch Access y Voice Access si se usan. Se guarda el **estado inicial** de lo que la sesión pueda tocar: `settings get secure enabled_accessibility_services`, `accessibility_enabled`, `settings get system font_scale`, el modo de navegación (`settings get secure navigation_mode` y, en HyperOS, `settings get global force_fsg_nav_bar`; T-022-07 confirma la clave en el móvil antes de cambiar nada y la apunta en el informe), las tres escalas de animación (`settings get global animator_duration_scale`, `transition_animation_scale`, `window_animation_scale`), la ampliación y los atajos (`accessibility_display_magnification_enabled`, `accessibility_button_targets`, `accessibility_shortcut_target_service`), el giro (`settings get system accelerometer_rotation` y `user_rotation`), la densidad (`settings get secure display_density_forced`), los iconos con tema, las teclas asignadas en Switch Access, la voz de TTS (`settings get secure tts_default_synth` y `tts_default_locale`), `cmd uimode night`, `settings get system system_locales` (o `cmd locale get-system-locales`), `settings get secure lock_screen_allow_private_notifications`, `settings get global zen_mode`, `settings get global low_power`, `settings get global auto_time` y `auto_time_zone`, el huso (`getprop persist.sys.timezone`), `settings get global stay_on_while_plugged_in` y `settings get global airplane_mode_on`. Lo que no se pueda leer por `adb` (iconos con tema, modos de HyperOS) lo dice el propietario y se apunta.
- **Servicios de accesibilidad:** al encender uno, se **añade** a la lista de `enabled_accessibility_services` (separada por `:`), nunca se sustituye; al acabar se vuelve a poner la lista apuntada tal cual.
- **Restaurar es volver al valor apuntado**, nunca un `reset` ni el valor de fábrica.
- **Qué app:** la *release* del propietario (`invalid.pending.app`) **solo** para «Recientes» (CA-022-27), el arranque y los iconos (CA-022-28) y TalkBack sobre el icono (CA-022-17, fuera de la app), y siempre sin tocar sus tareas ni sus ajustes. Todo lo demás, en la **`.profile`** (`invalid.pending.app.profile`), compilada del commit auditado con `flutter build apk --profile --split-per-abi --target-platform android-arm64` e instalada con `adb install` (HyperOS pide confirmar en el móvil; «Instalar vía USB» encendido).
- **Nunca** `flutter drive` sin `--keep-app-running`; nunca `adb uninstall invalid.pending.app` ni `pm clear invalid.pending.app`. Al acabar, `adb uninstall invalid.pending.app.profile`.
- **Tareas de prueba** solo en la `.profile`, con el texto empezando por «Prueba 022». Se eliminan al acabar (se desinstala la `.profile`).
- **Capturas:** solo si el propietario dice que no está usando el móvil, y justo antes `dumpsys window | grep mCurrentFocus` muestra la app delante. Se leen o miden en el Mac y **se borran en el momento**. Para leer la interfaz, mejor `uiautomator dump` que una captura. Capturas y volcados se sacan con `adb exec-out` directamente al *scratchpad* (`exec-out screencap -p`, `exec-out uiautomator dump /dev/tty`), sin dejar archivos en el móvil; si alguno queda (`/sdcard/window_dump.xml`), se borra con su ruta literal. **Nada de volcados ni capturas con la *release* delante** (sale el texto de sus tareas reales). Un `screenrecord` sigue la misma regla que las capturas.
- **Arranques en bucle** (`am start -S`): se avisa antes.
- **Al acabar cada sesión:** se restaura todo el estado inicial apuntado, se desinstala la `.profile` y el informe lleva una línea «Restauración» con lo que se dejó como estaba. Si la sesión se corta (CL-022-1), se restaura igual y las casillas a medias quedan sin resultado.
- **Lo que se oye** lo dice el propietario; Claude Code lo anota tal cual (con comillas) como evidencia.

### 6.2 Orden de las sesiones en el Xiaomi

Las sesiones agrupan las casillas por **lo que hay que encender**, para cambiar los ajustes del móvil lo menos posible. El orden pone primero lo que más riesgo tiene de dar un hallazgo alto (para que la 024 se pueda planear pronto) y deja las medidas, que piden el móvil quieto, para un rato aparte.

| Sesión | Tarea | Qué se enciende | Casillas | App |
|---|---|---|---|---|
| X1 | T-022-07 | TalkBack (ES) | CA-022-17 | `.profile`; la *release* solo para el icono |
| X2 | T-022-08 | TalkBack + texto al 200 %, tres botones, «Quitar animaciones» | CA-022-18, 23, 24 | `.profile` |
| X3 | T-022-09 | TalkBack + idioma del sistema en inglés (Q-022-4) | CA-022-19 | `.profile` |
| X4 | T-022-10 | Switch Access (volumen), Voice Access, ampliación | CA-022-20, 21, 22 | `.profile` |
| X5 | T-022-11 | Nada de accesibilidad: gestos, giro, «Recientes», iconos con tema, modo oscuro | CA-022-26, 27, 28 | *release* para 27 y 28 (arranque e iconos); `.profile` para 26 y la notificación de 28 |
| X6 | T-022-12 | El móvil quieto (el propietario no lo usa) | CA-022-29 | `.profile` |
| X7 | T-022-13 | Notificaciones, modo avión; puede ocupar varios días (CL-022-5) | CA-022-30, 30a | `.profile` |

Cada sesión dura lo que el propietario pueda (CL-022-1). Si en X1 a X4 sale algo **alto**, se avisa al propietario en el momento.

### 6.3 Guiones de las sesiones

Los guiones son la lista de casillas del inventario de esa sesión, en el orden de abajo. Al empezar, el coordinador lee al propietario **un paso cada vez**: qué abrir, qué gesto hacer y qué debería oír o ver, y anota lo que el propietario dice.

**Órdenes `adb`:** todas con `-s <serial>` explícito (`-s emulator-5554` en el emulador; el serial del Xiaomi solo en sus sesiones). Durante el bloque D (T-022-04 a 06) el Xiaomi está **desconectado**.

**Preparación común de la `.profile`** (antes de X1–X4 y X7): instalar; crear con la app, en este orden, «Prueba 022 · texto», «Prueba 022 · foto» (una foto), «Prueba 022 · grupo» (3 fotos, y un grupo de 10 con una foto alta para el bloqueo de zoom), «Prueba 022 · PDF» y «Prueba 022 · web» (`https://example.com`). Las fotos y el PDF se copian antes al móvil con `adb push` a `/sdcard/Download/Prueba022/` (antes, el propietario confirma que esa carpeta no se sincroniza con su nube ni su galería en la nube) y se borran al acabar con la ruta literal completa (`adb -s <serial> shell rm -r /sdcard/Download/Prueba022`), sin variables ni comodines. Los archivos salen de `tools/fixtures/` o, para los de 24 MP, de los usados en la 017 (`017/dispositivo.md`).

- **X1 — TalkBack en español (CA-022-17).** Encender TalkBack (`settings put secure enabled_accessibility_services …TalkBackService` y `accessibility_enabled 1`, o desde el atajo del propietario). Recorrer:
  1. tarea con imagen: límite de foco de CA-007-22;
  2. editor con fotos: «{n} fotos añadidas», el aviso compuesto de CA-016-21 sin que lo pise «Vista previa: …», «Adjunto quitado», «Preparando…»; «siguiente elemento» sin segunda parada en el nodo vivo;
  3. grupo: cinco cambios de foto seguidos, un único «Foto {i} de {n}» cada vez; con el bloqueo de zoom, «desplazar adelante/atrás» sobre la foto alta y dos dobles toques seguidos en cada una de las dos filas;
  4. eliminar: en el listado, sacar el foco de la card con un gesto real (la cuenta sigue) y el tiempo hasta el primer foco en «Deshacer» (cronómetro del propietario). «Todo hecho.» va al **final** de X1 (punto 11), porque vacía la cola; TalkBack y Switch Access a la vez van a X4, con los conmutadores ya asignados;
  5. Ajustes: interruptor de notificaciones como un solo nodo, acordeón sin anuncio al desplegar y uno solo al cambiar de opción, «Notificaciones al día» sin parada propia, línea de privacidad tras la fila, el diálogo del permiso (rechazar → aviso de bloqueo con su botón; ir al sistema y permitir → «Notificaciones permitidas.»), «Notificaciones activadas.», el aviso de error (si se puede provocar sin tocar nada del propietario; si no, CL-022-2);
  6. hojas (013 §6): cerrar cada hoja y comparar dónde cae el foco con lo esperado para esa hoja (sale en el guion: T-022-01 lo copia de 013 §6 y de la spec de cada hoja);
  7. «Recientes»: volver a la app desde «Recientes» (en la `.profile`: se anota en el informe como desviación de CA-022-01a, porque lo que se mira es el foco y no la tarjeta), el blanco intermedio y dónde cae el foco;
  8. arranque y giro: lo que se dice al arrancar y al girar, frente a lo que dicen las specs de cada pantalla (también en el guion, de T-022-01); se apunta además el **orden de lectura** de TalkBack en Ajustes, en la card de deshacer y en la tarea con grupo, como referencia para Switch Access en X4;
  9. fuera de la app, con la **release**: el icono en el lanzador, la lista de aplicaciones y Ajustes → Aplicaciones, con iconos con tema y sin ellos (cambiarlo y volver a dejarlo como estaba);
  10. con el móvil bloqueado y la `.profile` con notificaciones: `lock_screen_allow_private_notifications 0`, programar la notificación a unos minutos (hora de aviso en Ajustes de la app), bloquear y esperar a que la pantalla se encienda sola; anotar si TalkBack lee algo de la tarea (**alto** si lo hace). Después con el valor **inicial del propietario** (el apuntado): **Aceptada** con lo que diga el sistema;
  11. «Todo hecho.» con la voz: eliminar la última tarea de prueba.
- **X2 — Texto al 200 %, tres botones y reducir movimiento (CA-022-18, 23, 24).** `font_scale` al máximo que ofrezca HyperOS (se anota el valor; si no llega a 2,0, se anota también), navegación de tres botones. `font_scale` se pone a 2,0 por `adb` si los ajustes de HyperOS no llegan (y se restaura). Con TalkBack (CA-022-18): encender Notificaciones con el permiso **rechazado de forma permanente** (rechazar dos veces en el diálogo del sistema, o `pm revoke` seguido de `pm set-permission-flags invalid.pending.app.profile android.permission.POST_NOTIFICATIONS user-fixed`; `pm revoke` solo no basta, porque el diálogo vuelve a salir) y oír el aviso aunque quede bajo el pliegue; «No hay ninguna app…» desde Ayuda solo si se puede provocar sin desactivar el navegador del propietario (si no, **Aceptada** con T-022-06). Sin TalkBack (CA-022-23): la card de deshacer en vertical y en horizontal y su aviso de error de recuperación (B4; si no se puede provocar el error en el móvil, Aceptada con el emulador), el editor con texto largo con y sin fotos, Ajustes, el bloque de notificaciones desplegado con la opción 3, la línea de privacidad y el aviso, en ES y en EN (idioma de la **app**, en Ajustes). Con «Quitar animaciones» (CA-022-24; comprobar antes que deja `animator_duration_scale` a 0, que es lo que lee Flutter; si no, se anota y se mira igual): Ajustes y su interruptor, pulsar botones, el acordeón, el arrugado y la enhorabuena.
- **X3 — La voz y el idioma (CA-022-19).** Tres rondas: sistema EN + app ES; sistema ES + app EN; sistema EN + app EN. En cada una, con TalkBack: «Idioma, Español» y «Como el sistema», un aviso de error de Ajustes, «Bloquear zoom» y sus avisos, «Foto {i} de {n}» (y la frase `eng-USA` junto a la primera acción), la notificación completa y la genérica (desbloqueado y bloqueado con contenido oculto). Antes de la primera ronda se anota qué voces de TTS tiene instaladas el móvil; la ronda «con la voz del otro idioma sin instalar» se hace **solo si** ya falta alguna voz: no se desinstala ninguna voz del propietario (CL-022-2). Si están las dos, ese caso queda «Aceptada» o «Cerrada sin verificar», lo que diga el propietario, con sus palabras. Al cambiar el idioma del sistema, mirar el nombre del canal en Ajustes del sistema → Notificaciones de la app (o `dumpsys notification | grep -A3 invalid.pending.app.profile`).
- **X4 — Switch Access, Voice Access y la lupa (CA-022-20, 21, 22, y lo que queda de 17).** Switch Access con volumen + y − como «siguiente» y «seleccionar», comparando el orden de barrido con el de TalkBack apuntado en X1: la card de deshacer (y, con TalkBack encendido a la vez, recorrerla otra vez: la casilla de la 014 de CA-022-17), Ajustes (título, opciones, aviso, Volver), «Foto siguiente/anterior» y desplazar, también en horizontal, «Bloquear zoom» y las acciones de la tarea con el bloqueo, dos opciones seguidas del bloque de notificaciones, y lo mismo al volver de «Recientes». Voice Access: comprobar primero si está instalado y en qué idioma (si no, **Aceptada**); las órdenes de CA-022-21. Para «abrir y descartar la notificación por voz», programar antes una notificación de la `.profile` para que esté en la bandeja. La lupa: ampliación de pantalla completa y en ventana sobre la foto y el grupo, con el bloqueo encendido y apagado, con la app delante y tras volver de «Recientes»; el swipe horizontal sobre el grupo cambia de foto.
- **X5 — Gestos, giro, «Recientes», arranque e iconos (CA-022-26, 27, 28).** En la `.profile`: volver desde el borde con gestos y con tres botones, con el bloqueo y sin él; girar con el bloqueo de zoom y con el bloqueo de rotación del sistema; girar la tarea con 3 fotos (banda negra o blanca, a ojo); entrar en pantalla dividida 5 veces y contar cuántas muestran el fotograma negro. En la **release** (sin tocar sus tareas): la duración del blanco al volver de «Recientes» (a ojo; un `screenrecord` solo con la `.profile` delante y la regla de capturas de §6.1), la captura del sistema con la app delante (la hace el propietario con sus botones; dice si sale con la app; no se copia al Mac), la cámara y el selector abiertos desde la app (en la `.profile`, porque crean adjuntos; se anota en el informe como desviación de CA-022-01a, sin efecto: la protección de «Recientes» no depende del tipo de compilación para esto), «Recientes» desde la propia app (CL-011-14, informativo); los iconos con tema encendidos y un arranque en frío (la «u.» negra sobre `paper`); el «modo oscuro para apps» de HyperOS aplicado a la app, las opciones de desarrollo que fuerzan el oscuro si existen (se anota si el propietario las tiene encendidas; no se activan si no lo están, CL-022-2) y el ajuste de accesibilidad que oscurece las apps si existe. Con la `.profile`: tocar una notificación con el proceso cerrado (`am force-stop` **solo** de la `.profile`) y ver que sale `paper`. Opcionales: «Tamaño de visualización» al máximo e iconos con tema sobre fondo de poco contraste.
- **X6 — Medidas (CA-022-29).** El propietario no usa el móvil durante la sesión.
  - **Arranque en frío:** dos `.profile` arm64: la del commit auditado (`2e835cf`) y la de `8787643`, compiladas cada una en un `git worktree add --detach` aparte. Con una tarea «Prueba 022 · texto» creada en la `.profile`, se alterna `adb install -r` de una y otra (conserva los datos) y una copia del script en el *scratchpad* que lance `am start -W -S -n invalid.pending.app.profile/invalid.pending.app.MainActivity` (el script de `tools/` lanza `$PKG/.MainActivity`, que no existe en la `.profile`, `docs/perf/baseline.md`; `tools/` no se toca, CA-022-05), en orden **A B B A A B B A** (A = `8787643`, B = `2e835cf`), descartando el arranque de calentamiento. Primero con el sistema en claro y luego en oscuro (`cmd uimode night yes|no`, restaurado al acabar). **Deriva** = la diferencia de p50 entre las dos primeras pasadas A del mismo modo. Pasa si p50(B) − p50(A) ≤ deriva en los dos modos, p50 oscuro(B) − p50 claro(B) ≤ deriva y todo < 1 s. Si sale fuera una vez, se repite la serie entera (CL-022-6).
  - **Grupo de fotos (R-24):** el hueco al cambiar de foto y el p90 de raster del carrusel y del arrugado con la foto, con `integration_test/task_list_perf_test.dart` (`--dart-define=UNA_PERF_PHOTOS=10`, `flutter drive --profile --no-dds --keep-app-running`, desinstalando antes la `.profile` *split* por el `versionCode`; método de `docs/perf/baseline.md` §«Grupo de 10 fotos») y, después, `adb uninstall invalid.pending.app.profile`. El espacio en disco de una tarea de 10 fotos de 24 MP: `run-as` no funciona en la `.profile` (no es depurable): se lee en Ajustes → Aplicaciones → la `.profile` → Almacenamiento (datos del usuario), con la tarea y sin ella, y se anota la resta. Sin umbral.
  - **Contraste de los iconos de las barras:** navegación de tres botones; capturas de la hoja abierta, la card de deshacer y la enhorabuena en la `.profile`, con la regla de capturas de §6.1; contraste medido en el Mac entre el icono y el fondo de la barra (≥ 3:1); capturas borradas al acabar.
- **X7 — Notificaciones y modo avión (CA-022-30, 30a).** Con la `.profile` y las notificaciones de la app encendidas, hora de aviso a unos minutos: (1) móvil bloqueado, app cerrada y `lock_screen_allow_private_notifications 0` → versión genérica en la pantalla de bloqueo (lo dice el propietario); (2) tocar la notificación con la app cerrada → la tarea actual, vigilando **O-1** (app sin pintar: **alto**); (3) la app a la vista a la hora del aviso; (4) ahorro de batería encendido, «No molestar» y los modos de concentración de HyperOS si existen, una actualización de la app (`adb install -r` de la misma `.profile`) y un cambio de huso (`Ajustes → Fecha y hora`, lo hace el propietario y lo deja como estaba); (5) la pantalla apagada mucho rato (por la noche: la `.profile` se queda instalada hasta el día siguiente con el permiso del propietario, y se desinstala después). **Al acabar cada día** se restauran `lock_screen_allow_private_notifications`, «No molestar», el ahorro de batería y el huso: solo la `.profile` se queda de una noche a otra. Se anota el retraso de cada entrega; la ventana de 15 minutos no es criterio de paso. Lo que no llegue a darse se repite otro día; a los tres intentos decide el propietario (CL-022-5). **Modo avión:** con la `.profile`, arranque en frío, tarea de texto, con foto y web, completar una, eliminar otra y abrir la web (dice que necesita conexión, ADR-0016).

### 6.4 Emulador (T-022-04 a 06)

- APK de *release* del commit auditado (`flutter build apk --release`) en `Pixel_6a_api37_root`. Para los estados con TalkBack se puede usar una sonda de integración temporal o los gestos por `adb`, con las capturas del recuadro verde (memoria «Verificar TalkBack en el emulador»); la sonda no se sube.
- **Qué dice TalkBack en el emulador:** el panel de voz de API 37 no muestra los anuncios (hallazgo 1 de la 014) y `uiautomator dump` solo da etiquetas. Para CA-022-13, 16a y 16b se activan en los ajustes de desarrollador de TalkBack el registro detallado y «Mostrar salida de voz», y se lee `adb logcat` filtrado por TalkBack y por el motor de voz: el texto, cuántas veces se dice y en qué idioma. **[Suposición]** la versión de TalkBack del emulador lo ofrece; si no, esas casillas pasan al Xiaomi (CA-022-13 y 16a a X1; 16b, con el sistema en `ca` y `gl`, a X3, con el permiso del propietario) y se anota.
- **CA-022-11:** `tools/check-recents.sh emulator-5554 fixtures push` y, para cada pantalla de la lista, `capture`/`compare`, más `loop 10` y `record 5`; en horizontal, a ojo sobre las capturas. `fixtures clean` al acabar.
- **CA-022-12:** `adb shell wm size 1080x1920` y `wm density 480` (360 × 640 dp), `settings put system font_scale 2.0`; el carrusel con una foto cuyo archivo no está (borrado con `adb root` en el directorio de adjuntos de la app) y el editor mientras se preparan las fotos (un grupo de 10 de 24 MP para que dure). Restaurar con `wm size reset`, `wm density reset`, `font_scale 1.0`.
- **CA-022-13:** con `adb root`, sobrescribir con bytes al azar (`dd if=/dev/urandom`) la versión completa de una foto de un grupo (no borrarla); llegar a ella con TalkBack y leer el anuncio en el panel o en `uiautomator dump`.
- **CA-022-14:** tarea de más de 120 letras con emoji ZWJ (👩‍👩‍👧‍👦, 🏳️‍🌈) y acentos alrededor del corte; notificación provocada moviendo el reloj (`cmd alarm set-time`, con `auto_time` apagado y restaurado); el texto con `dumpsys notification --noredact`, y a ojo en la bandeja.
- **CA-022-15 y 16b:** `cmd locale set-system-locales ca-ES`, después `gl-ES` y `eu-ES` (o desde Ajustes si la orden no existe en API 37), restaurando `en-US`; la app con «Como el sistema», Ajustes y la notificación. Con TalkBack, en `ca` y en `gl`: un anuncio de la app y qué voz lo dice (si el emulador no tiene esa voz, se anota).
- **CA-022-16:** la app 11 minutos en segundo plano (reloj real o movido) y tocar la notificación → la tarea actual; la notificación con la pantalla apagada (`input keyevent KEYCODE_SLEEP`).
- **CA-022-16a:** `pm disable-user --user 0` del navegador (Chrome) del **emulador**, TalkBack encendido, Ayuda → «No hay ninguna app…» se oye una vez después de las opciones; tocar otra fila → no queda el aviso viejo; `pm enable` al acabar.

## 7. Seguridad, accesibilidad y rendimiento

- **Seguridad y privacidad (P4):** la superficie es el **móvil del propietario**: sus datos, su bandeja de notificaciones y sus otras apps. Lo cubren §6.1 (solo la `.profile` con notificaciones, nada de capturas sin permiso, nada que desinstale la *release*) y CA-022-02. Ninguna captura ni volcado de `uiautomator` del Xiaomi se sube al repositorio. `gh workflow run release.yml --ref main` (CA-022-09a; el modo testers es el `workflow_dispatch`, sin *inputs*) es una acción hacia fuera: solo con el «sí» del propietario en esa tarea, y antes `git rev-parse origin/main` debe dar el commit auditado (si no, CL-022-9).
- **Accesibilidad:** es el contenido de la spec. La gravedad de cada fallo sigue CA-022-04, clasificada de antemano así:

| Si falla… | Gravedad |
|---|---|
| Una acción principal sin camino con lector, con Switch Access o por voz; TalkBack lee la tarea en la pantalla de bloqueo con el contenido oculto; la versión genérica no sale; O-1 | **Alta** |
| La voz de CA-022-19 (ADR-0023 y CA-019-21) y cambiar de foto con Switch Access o por voz (ADR-0022): regla de excepción prevista | **Media** |
| Un anuncio que no se oye pero tiene otro camino; texto tapado al 200 % que se alcanza desplazando; el editor con «+» y «Guardar» bajo la barra (003) | **Media** |
| El resto (un anuncio de más, una parada de más que no impide nada, un detalle visual) | **Baja** |
- **Rendimiento:** CA-022-29 (arranque frente a `8787643`, R-24, contraste).

## 8. Riesgos, alternativas y preguntas

- **R-1 La sesión X7 depende del azar** (que el móvil esté bloqueado a la hora del aviso, la pantalla apagada mucho rato): CL-022-5 (tres intentos y decide el propietario). Se planea dejar la `.profile` instalada una noche, con permiso.
- **R-2 Cambiar el idioma del sistema del Xiaomi (X3)** puede reordenar o cambiar cosas del propietario (teclado, voz). Se apunta el estado antes y se restaura; si algo no vuelve solo, se le dice.
- **R-3 TalkBack y Switch Access a la vez** pueden dejar el móvil difícil de manejar: se enciende por `adb` y se apaga por `adb` (no depende del propietario).
- **R-4 Versiones que cambian** (HyperOS, TalkBack): CL-022-4.
- **Alternativa descartada:** medir el arranque en la *release* del propietario con `adb install -r` (como en la 015 y la 017). La spec pide la `.profile` (CA-022-01a, 29), que no toca sus datos.

**Pregunta resuelta:**

- **P-022-1 [Resuelta, propietario, 2026-10-16: la recomendación] ¿Qué app se usa en CA-022-30?** Todo CA-022-30 se hace en la `.profile`. CA-022-30 dice «con la *release* del commit auditado y las notificaciones encendidas», pero CA-022-01a dice que las notificaciones se prueban **en la `.profile`** y que las de la *release* no se tocan. **Recomendación:** leer «la *release* del commit auditado» como «el commit auditado» y hacerlo todo en la `.profile`, que se comporta igual y no saca su tarea real en la bandeja. Si el propietario prefiere la *release*, lo dice él (CA-022-01a: «se pregunta antes»).
