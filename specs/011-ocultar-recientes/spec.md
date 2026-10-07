# Spec 011: Ocultar el contenido en "Recientes"

- **Estado:** **Implementada parcialmente** (2026-09-30: falta PD-10 / T-011-09, la verificación en Android 8 y 12L; ver `tasks.md`). Aprobada por el propietario el 2026-09-30. Revisada por `spec-reviewer` el 2026-09-30 con los cambios aplicados; P-011-1 resuelta y P-011-2 aplazada (PD-10)
- **Reglas de producto:** R8 (abrir → tarea actual rápido; CA-011-03 y CA-011-05). Desarrolla P4 (privacidad por defecto) y P5 (seguridad desde el diseño) y cierra la amenaza T-2 de `docs/security/threat-model.md` ("instantánea del selector de apps")
- **Pantallas del prototipo:** ninguna. No hay interfaz nueva; lo que cambia es lo que el sistema enseña de la app cuando está en segundo plano
- **Decisiones y ADR relacionados:** D17 (solo Android en la beta); P2 (arranque). Decisión del propietario, 2026-09-30: **ocultar siempre**, no solo con adjunto. El plan valorará un ADR corto para esta decisión (impacto de seguridad)
- **Dependencias:** 001 (CA-001-09 y CA-001-12); 007, 008 y 009 (CL-007-11, CL-008-13 y CL-009-10, que esta spec cierra)

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y las notas técnicas, solo en el anexo (no normativo).

## 1. Objetivo

Que la lista de aplicaciones recientes del sistema ("Recientes") **no enseñe nada de lo que hay en la app**: ni el texto de una tarea, ni una imagen, ni un PDF, ni una página web. Quien vea el móvil de pasada no debe poder leer las tareas de otra persona. Sin coste para el usuario: la app se sigue usando, capturando y reabriendo igual que antes.

## 2. Historias de usuario

- **HU-011-1** Como usuario que deja el móvil sobre la mesa o lo enseña a alguien, quiero que "Recientes" no muestre mis tareas, para que nadie las lea de pasada.
- **HU-011-2** Como usuario, quiero poder seguir haciendo capturas y grabaciones de mi propia app cuando la estoy usando, para guardar o compartir lo que yo decida.
- **HU-011-3** Como usuario, quiero que al volver a la app la encuentre tal como la dejé y sin parpadeos, para no perder el hilo (CA-001-12).

## 3. Criterios de aceptación

Formato: ID · Dado / Cuando / Entonces. **Estado de partida [Hecho]:** hoy "Recientes" muestra la última pantalla de la app tal cual (CL-007-11, CL-008-13, CL-009-10). No hay ningún ajuste que lo cambie y esta spec no añade ninguno.

**Entornos de verificación** (para CA-011-01, 03, 04 y 08):
- **Ahora:** emulador con **Android 16 (API 37)**, el único instalado. Es lo que se verifica al implementar.
- **Aplazado (propietario, 2026-09-30):** emulador con **Android 8 (API 26)** y **Android 12L (API 32)**, que se instalarán más adelante, cuando la app esté más avanzada y **antes de dar la beta a ningún tester** (PD-10 en `docs/PLAN.md`). Hasta entonces, lo que dependa de Android 8–12 es **[Suposición]** y no se da por verificado.
- **Solo con permiso explícito del propietario:** el Xiaomi (HyperOS, su lanzador propio; las capturas del móvil son privadas).

**Regla de desempate [propietario, 2026-09-30]:** las capturas mandan sobre el ocultado. Si CA-011-01 no se puede cumplir en Android 8–12 (API 26–32) sin incumplir CA-011-04, **se acepta la miniatura visible solo en Android 8–12** durante la beta (opción b); se anota en las notas de la beta y se **revisa antes de la v1.0**. Las otras opciones descartadas eran (a) bloquear las capturas en Android 8–12 y (c) subir el mínimo (D12). Si CA-011-03 no se cumple en Android 13+, o CA-011-01 falla en Android 13+, **se para y se pregunta**.

- **CA-011-01 Sin contenido en "Recientes"**
  - **Dado** la app en primer plano en cada pantalla de la matriz (más abajo) y, en dos pasadas distintas, con la tarea A ("uno") y con la tarea B ("dos", con otra imagen si procede)
  - **Cuando** el usuario deja la app en segundo plano **de verdad** (con el botón de inicio, con el cambio a otra app o con el gesto de vuelta) y abre "Recientes", y se captura esa pantalla. *(Reformulado 2026-09-30, propietario, tras T-011-01: abrir "Recientes" **directamente desde la app**, sin pasar antes por el escritorio ni por otra app, queda fuera del criterio; ver CL-011-14.)*
  - **Entonces** la tarjeta de la app **no contiene ninguna región de lo que había en pantalla**: ni texto, ni imagen, ni PDF, ni página web, ni el logotipo, ni los botones. **Prueba:** las capturas de la tarjeta con A y con B son idénticas entre sí y no contienen ningún píxel reconocible del contenido (comparación con la captura de la pantalla en primer plano). En los lanzadores que muestran el nombre, la tarjeta sigue con su icono y su nombre (CA-010-05). Qué se ve en su lugar (fondo liso, icono…) **[Suposición]** lo decide el sistema y siempre es algo aceptable.
- **CA-011-02 Matriz de pantallas (sin excepciones)**
  - **Dado** la lista siguiente, **cada fila** se prueba en **cada** entorno de verificación
  - **Cuando** se aplica CA-011-01
  - **Entonces** se cumple en todas: bienvenida · tarea actual solo con texto · con imagen · con PDF · **con web (fila propia: la vista web se dibuja por separado)** · menú · listado · hoja "Mover" · editor con el teclado abierto y texto escrito · hojas de adjuntar, "Cargar URL" y eliminar · "Todo hecho." · error de almacenamiento · **"Configuración y perfil", lista de licencias, texto de una licencia y la confirmación de enlace de la política (enmienda 2026-09-30 por la spec 012; **Enmienda 2026-10-05 (spec 015, implementada; en vigor)**: **Ajustes y la página de Idioma** (sin confirmación de enlace en Ajustes desde la enmienda del propietario de 2026-10-05; la hoja de la 008 se queda para el PDF) sustituyen a las tres pantallas de la 012 y no hay pantallas de licencias, CA-015-18)** · **la card de deshacer a la vista, en la tarea, en "Todo hecho.", en el listado y con el aviso de error de la recuperación (enmienda 2026-10-04 por la spec 014: la miniatura se toma en `onPause`, antes de que pasar a segundo plano la haga definitiva)**. No hay pantallas "seguras" y "no seguras".
  - *Enmienda (spec 016, implementada; en vigor):* la matriz gana dos filas, el editor con la preselección y la tarea con el carrusel, y se añaden el carrusel en horizontal, la tarea con "Foto no disponible" y "Preparando foto {i} de {n}…" (CA-016-13; `docs/testing.md`).
- **CA-011-03 Vuelta a la app sin parpadeo**
  - **Dado** la app en segundo plano
  - **Cuando** el usuario vuelve (desde "Recientes", desde el icono, desde otra app o tras desbloquear la pantalla)
  - **Entonces** se aplica CA-001-12 sin cambios: **si pasaron menos de 10 minutos se ve la misma pantalla; si pasaron 10 minutos o más, la tarea actual (o el editor si no hay ninguna)**. Se prueba con el reloj inyectado en 9:59 y en 10:00.
  - Además **la vuelta no enseña nada distinto de la app**, salvo lo que se acepta a continuación. **Prueba:** grabación con `screenrecord`, 10 vueltas por entorno; ningún fotograma con el área de contenido negra, ni con un fondo distinto del contenido esperado, **excepto el fotograma en blanco de "volver desde Recientes"**.
  - **Excepción aceptada [propietario, 2026-09-30, tras T-011-01 en API 37]:** al volver a la app **tras haberse ido de verdad, por cualquier vía** (tocando la tarjeta de "Recientes", con el icono o desde otra app; enmienda 2026-09-30 tras T-011-03, donde el blanco largo salió con el icono y con `am start`) puede verse un instante un fotograma **liso en blanco** (lo que el sistema pinta cuando no hay instantánea; el mismo blanco en modo claro y en modo oscuro) antes de que se dibuje la app. *(Frase corregida el 2026-09-30 con el visto bueno explícito del propietario: antes decía "el fondo de arranque del sistema", lo que la medición en modo oscuro refutó, `dispositivo.md` §6. Sin más cambios de fondo.)* **[Hecho]** en API 37 con los dos mecanismos; **[Suposición]** la duración medida (≈ 1 s en `screenrecord` a mp4) está inflada por la carga de la grabación en el emulador. No se cambia el fondo de arranque en esta spec. Medido en T-011-03: 0,4–1,25 s en el emulador, 0 fotogramas negros o de otro color. Si el blanco fuera **negro**, otro color o durara claramente más de lo medido, **se para y se pregunta**. Se revisa antes de la v1.0.
- **CA-011-04 Capturas y grabaciones con la app en primer plano** *(propietario, 2026-09-30, P-011-1)*
  - **Dado** la app en primer plano en cualquier pantalla de la matriz, **incluso después de volver de segundo plano, de la cámara o del selector** (CL-011-3), y en el primer arranque en frío
  - **Cuando** el usuario hace una captura de pantalla o graba la pantalla con las herramientas del sistema
  - **Entonces** la captura o la grabación **salen con el contenido**, no en negro y sin aviso de que la app lo impide.
- **CA-011-05 El arranque no empeora (P2, R8)**
  - **Dado** la compilación *release*
  - **Cuando** se mide el arranque en frío, con n ≥ 20, alternando la línea base (antes de la spec) y la compilación nueva en el mismo entorno
  - **Entonces**, **criterio principal**, la tarea actual sigue visible en < 1 s (p50) (CA-001-09); **criterio secundario**, el aumento del p50 no supera la diferencia medida entre dos pasadas de la línea base el mismo día **[Suposición]** (`docs/perf/baseline.md` no fija un margen). El emulador solo vale para comparar; el Xiaomi solo con permiso del propietario.
- **CA-011-06 Sin datos, permisos ni dependencias nuevos**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior
  - **Entonces** la lista de permisos no cambia, no hay conexiones de red nuevas, `schemaVersion` no cambia, las dependencias no cambian, no hay ningún ajuste nuevo y tras el arranque no aparece ningún archivo nuevo en el almacenamiento.
- **CA-011-07 Plataformas sin "Recientes" de Android**
  - **Dado** la web de pruebas o cualquier plataforma que no sea Android
  - **Cuando** se usa la app
  - **Entonces** se comporta exactamente como antes, sin errores ni avisos (D17: iOS queda fuera de la beta).
- **CA-011-08 Ciclo completo (regresión)**
  - **Dado** la app en primer plano
  - **Cuando** se repite 10 veces: ir a segundo plano → abrir "Recientes" (CA-011-01) → volver → hacer una captura (CA-011-04); y lo mismo tras ir a la cámara y al selector
  - **Entonces** en las 10 vueltas la tarjeta no muestra contenido y la captura sale con contenido. Vale para el fallo típico de dejar la protección puesta o no ponerla. **Excepción aceptada (propietario, 2026-09-30, tras T-011-03):** en el ciclo del **selector de fotos** la tarjeta puede enseñar lo que queda a la vista de la app junto a su hoja parcial (CL-011-15); ahí solo se exige que la captura salga con contenido y que la tarjeta no sea peor que antes de esta spec.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-011-1 | Se actualiza la app desde una versión anterior y la tarjeta antigua sigue en "Recientes" | **[Suposición]** La miniatura de la versión anterior puede seguir visible hasta la próxima vez que la app pase a segundo plano; lo guarda el sistema. **Procedimiento:** instalar la versión anterior, abrir con una tarea, salir, actualizar y mirar "Recientes". Se acepta y se anota en las notas del primer envío |
| CL-011-2 | El sistema cierra la app en segundo plano y luego el usuario abre "Recientes" | **[Suposición]** La tarjeta no muestra contenido: lo que se guardó al irse ya estaba oculto |
| CL-011-3 | Se abre la cámara o un selector del sistema (fotos, archivos) desde la app | La app queda en segundo plano y "Recientes" no muestra su contenido (**salvo la hoja parcial del selector de fotos: CL-011-15**). Al volver se conserva la pantalla (CA-011-03), con o sin adjunto elegido (specs 007 y 008). También si el sistema cerró la app mientras tanto (CL-007-7): se aplica CA-001-12 |
| CL-011-4 | Algo del sistema se superpone a la app y deja ver parte de ella: un selector parcial de fotos, la bandeja de notificaciones o el menú de apagado | Lo que se ve de la app **detrás no cambia respecto de hoy**. Se comprueba en cada entorno; si se ve peor, se **para y se pregunta** (regla de desempate). La app no pide permisos (CA-007-02), así que no hay diálogo de permisos |
| CL-011-5 | Pantalla dividida o ventana flotante | **Android 8–9:** la app sin foco queda en pausa y puede verse oculta. **Android 10 y superior:** sigue activa y **no** debe ocultarse. **[Suposición]** En Android 8–9 se acepta porque la beta es de una tarea a pantalla completa; se comprueba en API 26 y API 32 |
| CL-011-6 | Gesto de vuelta o cambio rápido entre apps (deslizar en el borde) | **[Hecho, API 37; corrige la suposición anterior]** Durante el gesto se ve la ventana **en vivo** de la app deslizándose, con contenido: es el mismo mecanismo que CL-011-14 y queda fuera de CA-011-01. **Aceptado (propietario, 2026-09-30).** Una vez que la app se ha ido, su tarjeta no muestra contenido |
| CL-011-7 | Captura hecha **desde "Recientes"** (algunos móviles la ofrecen en cada tarjeta) | Sale sin contenido: es lo mismo que ve el usuario. No hay que corregirlo |
| CL-011-8 | Otras superficies del sistema que leen la pantalla (asistente, "buscar lo que hay en pantalla", casting) | **Fuera de alcance** (§8) |
| CL-011-9 | El dispositivo no muestra miniaturas en "Recientes" por sí mismo, o su lanzador ignora la señal estándar (HyperOS) | Si no hay miniatura, no hay nada que ocultar. Si el lanzador ignora la señal, **se comprueba en el Xiaomi** (con permiso) y, si falla, se para y se pregunta |
| CL-011-10 | Bloqueo de pantalla con la app abierta y desbloqueo | La app pasa a segundo plano sin que se abra "Recientes"; al desbloquear se aplica CA-011-03 |
| CL-011-11 | Teclado abierto con texto escrito en el editor al pasar a segundo plano | La tarjeta no muestra ni el texto ni el teclado (CA-011-02) y al volver el texto y el foco siguen (CA-001-12) |
| CL-011-12 | Se gira el móvil con la app en segundo plano y una imagen o un PDF en la tarea | Al volver se aplica CA-011-03 y la tarjeta sigue sin contenido |
| CL-011-13 | El ocultado falla sin que nadie lo note | No hay aviso en la app (§5), pero los criterios lo detectan: CA-011-01 y CA-011-08 se comprueban en los entornos de verificación **antes de cada versión** que se entregue a testers |
| CL-011-14 | "Recientes" se abre **directamente desde la app** (deslizar hacia arriba con la app delante), sin pasar antes por el escritorio | **[Hecho, API 37]** La tarjeta enseña la ventana **en vivo** de la app, con contenido, y la actividad no llega a pausarse: ni `setRecentsScreenshotEnabled` ni `FLAG_SECURE` al pausar pueden actuar. Es el comportamiento de "Recientes" con cualquier app; la instantánea queda oculta en cuanto se cambia de app. **Límite conocido, aceptado (propietario, 2026-09-30):** queda fuera de CA-011-01. Se anota en las notas de la beta y se puede revisar antes de la v1.0. **[Suposición]** en Android 13–16 se comporta igual; en 8–12 se mira en PD-10 |
| CL-011-15 | Hoja parcial del **selector de fotos** del sistema abierta sobre la app | **[Hecho, API 37]** El selector corre en la misma tarea y no oculta su instantánea, así que la tarjeta de "Recientes" enseña lo que queda a la vista de la app junto a la hoja (logotipo, fondo y, con un PDF en el editor, la parte alta de su vista previa y su nombre de archivo). Es **idéntico a la versión anterior a esta spec**, no peor. **Límite conocido, aceptado (propietario, 2026-09-30):** queda fuera de CA-011-01 en este caso. Se anota en las notas de la beta y se puede revisar antes de la v1.0. En 8–12, PD-10 |

## 5. Estados vacíos y de error

No aplica: no hay pantalla nueva ni estado de error propio. Si el sistema no permite ocultar el contenido, la app se comporta como hoy y no muestra ningún aviso (CL-011-9). La detección del fallo es del proceso de pruebas (CL-011-13), no de la interfaz.

## 6. Accesibilidad

- No hay interfaz nueva, gestos nuevos ni textos. TalkBack, Switch Access, el teclado y el texto grande no cambian.
- La tarjeta de "Recientes" no requiere ningún texto traducible nuevo: el sistema la describe con el nombre de la app (CA-010-05). Se comprueba una vez con TalkBack que la lee así, sin contenido de tareas.
- **[Suposición]** Como la protección no se aplica con la app en primer plano (CA-011-04), la lupa del sistema y las herramientas de captura de los servicios de accesibilidad siguen funcionando. Se comprueba una vez en el emulador y se anota para la auditoría de F5.
- Reducir movimiento: no hay animaciones nuevas.

## 7. Textos (ES / EN)

Ninguno nuevo.

## 8. Fuera de alcance

- Un **interruptor** para el ocultado: no hay pantalla de Configuración en la beta (propietario, 2026-09-29). Si la futura Configuración lo quiere, se añade allí.
- **Bloquear las capturas de pantalla** con la app en primer plano: rechazado (CA-011-04), salvo lo que decida la regla de desempate en Android 8–12.
- Otras superficies que pueden leer la pantalla: asistentes, "buscar lo que hay en pantalla", grabaciones de terceros, casting (CL-011-8).
- Notificaciones (no hay; Bloque 4), bloqueo con biometría o PIN (D11) e iOS (D17, F-iOS).

## 9. Preguntas abiertas

- **P-011-1 [Resuelta, propietario, 2026-09-30]:** las capturas y grabaciones con la app abierta **siguen funcionando** (CA-011-04) y, si en Android 8–12 no se pueden tener las dos cosas, gana la captura (regla de desempate, opción b).
- **P-011-2 [Aplazada, propietario, 2026-09-30]:** las imágenes de emulador de Android 8 (API 26) y Android 12L (API 32) no se instalan ahora. Se instalan más adelante, antes de dar la beta a testers (PD-10). **Consecuencia:** la spec se implementa y se verifica ahora solo en API 37; el código de Android 8–12 se escribe con sus tests de ciclo de vida (canal simulado) pero queda **sin verificar en dispositivo** hasta PD-10, y la spec no puede pasar a "Implementada" del todo hasta entonces. El plan y las tareas separan lo verificable ahora de lo diferido.
- **Medir en el emulador no es un spike**, sino la verificación de estos CA dentro de la implementación.

## Anexo: notas para `plan.md` (no normativas)

- **Enfoque a validar en el emulador, sin cerrar antes de medir:** Android 13+ (API 33) permite excluir la actividad de la instantánea del selector de apps (`Activity.setRecentsScreenshotEnabled(false)`); en Android 8–12 se puede marcar la ventana como segura (`FLAG_SECURE`) **solo al pasar a segundo plano** y quitarla al volver.
- **Riesgos que el plan debe medir:**
  - En API 26–32 la instantánea podría tomarse **antes** de que la actividad reciba la pausa; entonces no se logra ocultar sin dejar la marca puesta siempre, y chocan CA-011-01 y CA-011-04 (regla de desempate).
  - Un fotograma negro o el fondo del sistema al volver (CA-011-03). En Android 13+, sin la instantánea, la vuelta desde "Recientes" puede enseñar la pantalla de arranque del sistema.
  - Un selector parcial o pantalla dividida en 8–12 (CL-011-4, CL-011-5).
  - HyperOS puede tratar la señal a su manera (CL-011-9).
- **Dónde:** `MainActivity.kt` (ya hay canales `una/links` y `una/webview`); decidir si basta con la actividad o hace falta un canal con Dart. No debe tocar `main()` ni el arranque (P2, I-1).
- **Verificación:** "Recientes" con `adb shell input keyevent KEYCODE_APP_SWITCH` y captura con `adb exec-out screencap -p`; CA-011-04 con `screencap`, `screenrecord` y la captura del sistema. Con dos tareas (A y B) para la comparación de CA-011-01.
- **Tests automáticos:** el ciclo de vida se prueba con un canal simulado; el efecto real solo se ve en el emulador o el dispositivo.
- **Documentos a actualizar al implementar:** `docs/security/threat-model.md` T-2, `docs/security/checklist.md`, `docs/architecture.md`, CLAUDE.md, `specs/010-idioma-y-configuracion/spec.md` §8 y CL-007-11, CL-008-13 y CL-009-10 (ya apuntan aquí).
