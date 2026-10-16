# Spec 022: Auditoría en dispositivo

- **Estado:** **Borrador** (2026-10-16). Revisada por `spec-reviewer` el 2026-10-16: 2 bloqueantes (la gravedad de la voz de la notificación y la app del propietario frente a la `.profile`), 8 importantes y 11 menores, **aplicados**. Quedan Q-022-1 a 5 para el propietario.
- **Alcance decidido por el propietario** el 2026-10-16, en la ronda de preguntas de `/spec-new 022`:
  - **1a:** la 022 **solo verifica**. Lo que falle se registra como hallazgo y va a una spec de corrección aparte. La 022 no cambia código.
  - **2:** las pruebas en otros emuladores y en otros dispositivos se **cierran sin hacerlas**. Esto incluye Android 8 y 12L (PD-10), otros lanzadores y otros lectores de pantalla. «Vamos a pasar esto como si lo hubiéramos hecho […] nos lo saltamos, no nos importa.»
  - **3:** las comprobaciones que piden al propietario en el Xiaomi se hacen «cuando haya que hacerlo».
  - **4:** sin tablets: «Ahora no nos preocupamos de tablet. Solo móvil» (PD-11, R-25).
- **Fase:** F5 Endurecimiento. Es la tercera de las specs 020–023 (D30). Empieza tras la 021, fusionada el 2026-10-15 (PR #63, `2e835cf`). Tamaño **M**: casi todo es tiempo del propietario en el móvil.
- **Reglas de producto:** ninguna regla R nueva. Verifica en el dispositivo **P2** (arranque), **P3** (sin conexión, CA-022-30a), **P4** (notificación local), **P6** (accesibilidad, con sus excepciones) y **P7** (idioma). Cierra lo que `docs/PLAN.md` deja «para la 022».
- **Pantallas del prototipo:** **sin diseño**. La spec no cambia ninguna pantalla, texto ni interacción.
- **Decisiones y ADR relacionados:**
  - Sin tablets: **D28**. Android primero y sin iOS: **D17**.
  - Excepciones de P6 que se comprueban y no se cambian:
    - **ADR-0013**: lupa del sistema y horizontal sin menú.
    - **ADR-0020** y **ADR-0023**: voz del sistema.
    - **ADR-0021**: deshacer.
    - **ADR-0022**: carrusel.
  - **ADR-0025** (notificación local): no es una excepción de P6, sino una nota de P4. Su criterio de revisión (CA-019-21) dice qué pasa si un lector no respeta el idioma de la notificación (CA-022-19).
  - **ADR-0019** («Recientes»): su mecanismo B (Android 8–12) se queda sin verificar (CA-022-06).
  - **[Suposición]** No hace falta un ADR nuevo ni subir la constitución, que sigue en la 1.10. Hay una salvedad: si la auditoría muestra que TalkBack no respeta el idioma de la app donde las excepciones dicen que sí (CA-022-19), lo que se decida irá en un ADR de la spec de corrección.
- **De dónde salen las comprobaciones:** de `docs/PLAN.md` §3 y del `dispositivo.md` de cada spec.
  - «Casillas de la 014» a «Casillas de la 021».
  - «Hallazgos de la 012 para la auditoría de F5», con las casillas de `012/dispositivo.md` §8 que pasaron a Ajustes con la 015.
  - Las casillas de `013/dispositivo.md` §6.
  - La fila de F5: la limitación de foco de CA-007-22, la lupa con la app delante y TalkBack, Switch Access y teclado al volver de «Recientes».
  - Lo de la 011 en el Xiaomi que quedó sin hacer.
  - **O-1** de la 020.
  - **R-24** (lo que falta medir) y **R-26** (la voz con el idioma elegido).
- **Dependencias:** 001–021 en `main`. Sin esquema de BD, permisos, dependencias ni textos nuevos.
- **Nomenclatura** (se añade al glosario):
  - **Casilla de dispositivo:** una comprobación que no se puede hacer con `flutter test` ni en la CI, y que una spec anterior dejó registrada para la 022.
  - **Sesión guiada:** un rato acordado con el propietario, con el Xiaomi en la mano y una lista de pasos que se le lee uno a uno. El propietario hace los gestos y dice lo que oye o ve. Claude Code lo anota.
  - **Resultado de una casilla:** uno de cuatro valores.
    - **Pasa.**
    - **Falla:** se abre un hallazgo.
    - **Aceptada:** el propietario acepta lo que se ve, o que no se pueda probar del todo, con el motivo escrito.
    - **Cerrada sin verificar:** el propietario decide no hacerla.
  - **Hallazgo de la auditoría (H-022-NN):** una casilla que falla, con su gravedad y su destino (CA-022-04).
  - **Commit auditado:** el commit de `main` cuya versión *release* se audita (CA-022-01).

> Esta spec describe **qué** se comprueba y **qué cuenta como pasar**. Nombra pantallas, ajustes del sistema y herramientas que ya existen para que cada casilla se pueda verificar. El **cómo** va en `plan.md`: el orden de las sesiones, los guiones paso a paso, las órdenes de `adb` y las medidas.

## 1. Objetivo

Dar **un resultado escrito a cada comprobación en dispositivo** que las specs 011–021 dejaron pendiente, en el emulador de API 37 y en el Xiaomi, para que esas specs puedan pasar a **Implementada** y la beta (F6) empiece sabiendo qué funciona en un móvil real y qué no. La auditoría no arregla nada: lo que falle queda como hallazgo, con su gravedad, para una spec de corrección.

## 2. Historias de usuario

- **HU-022-1** Como propietario, quiero que **todo lo que quedó por mirar en un móvil real** esté mirado y anotado antes de dar la app a testers, para no entregar algo que solo se ha probado en el emulador.
- **HU-022-2** Como usuario de TalkBack, Switch Access o Voice Access, quiero que lo que las specs prometen a quien usa un lector (foco, anuncios, voz en el idioma de la app, acciones con nombre) **se haya comprobado de oído y con los gestos reales**, porque los tests y el panel del emulador no lo garantizan.
- **HU-022-3** Como propietario, quiero que **mis decisiones de no probar algo** consten por escrito como decisiones, y no como pruebas hechas, para saber qué riesgo asumo.
- **HU-022-4** Como propietario, quiero que **la auditoría no me desordene el móvil**: mis tareas, mis ajustes y mis otras apps deben quedar como estaban.

## 3. Criterios de aceptación

**Trazabilidad HU → CA:** HU-022-1 → CA-022-03, 09 a 16a, 17 a 30a y 31 a 33; HU-022-2 → CA-022-17 a 22 y 25; HU-022-3 → CA-022-03, 06 a 08 y 10; HU-022-4 → CA-022-01a y 02.

Todos los criterios se verifican **leyendo el registro**: el `dispositivo.md` de la spec de origen, el informe de la 022 y `docs/PLAN.md`. Cada casilla de los bloques B a E necesita un resultado (CA-022-03). «Pasa» significa que se cumple lo que dice la spec de origen, en el criterio que se cita.

### A. Reglas de la auditoría

- **CA-022-01 Dónde y sobre qué se audita**
  - **Dado** que empieza la auditoría
  - **Cuando** se elige el entorno de cada casilla
  - **Entonces**:
    - Solo hay dos entornos:
      - el emulador `Pixel_6a_api37_root` (API 37);
      - el **Xiaomi 15T Pro** del propietario (HyperOS 3).
    - No se instala ningún otro emulador ni se usa ningún otro dispositivo.
    - Lo que se audita es la *release* del **commit auditado**. Su hash, la versión de HyperOS y la de TalkBack constan en el informe.
    - Si durante la auditoría se fusiona en `main` algo que toca `app/`, se anota en el informe qué casillas se hicieron con cada commit.
- **CA-022-01a Qué app se usa en el Xiaomi**
  - **Dado** que en el Xiaomi están la *release* del propietario, con sus tareas reales, y la app `.profile` aparte, con sus propios datos
  - **Cuando** se elige la app de cada casilla
  - **Entonces**:
    - **Solo la *release*** del propietario, sin crear, tocar ni reordenar tareas y sin cambiar sus ajustes: lo que depende del tipo de compilación o del lanzador. Son «Recientes» (CA-022-27), el arranque y los iconos (CA-022-28) y TalkBack sobre el icono (CA-022-17).
    - **La `.profile`** para todo lo demás: lo que crea tareas o necesita una cola concreta, las notificaciones (CA-022-30), el modo avión (CA-022-30a) y las medidas (CA-022-29). Su comportamiento es el mismo que el de la *release* en todo lo que no sea el tipo de compilación.
    - Las notificaciones de la *release* se quedan como las tenga el propietario: la auditoría no las enciende ni las apaga, para que no salga su tarea real en la bandeja ni en la pantalla de bloqueo (P4).
    - Si una casilla necesita la *release* con datos de prueba, se pregunta antes al propietario.
- **CA-022-02 El móvil del propietario se respeta**
  - **Dado** que una casilla necesita el Xiaomi
  - **Cuando** se usa
  - **Entonces**:
    - Se usa solo en una sesión guiada, con el permiso del propietario dado en esa sesión.
    - No se hace ninguna captura de pantalla salvo que el propietario diga que no está usando el móvil y que la app está delante. Las capturas se borran del Mac en cuanto se ha medido lo que hacía falta.
    - Antes de cualquier serie de arranques que quite el móvil de lo que estaba haciendo, se avisa.
    - No se hace nada que desinstale o borre los datos de la *release* del propietario (el plan dice cómo; ver la memoria de `flutter drive`).
    - Las tareas de prueba se crean solo en la `.profile`, con el prefijo «Prueba 022», y se eliminan al acabar. Ninguna tarea del propietario se completa, se elimina, se edita ni se reordena.
    - Al terminar cada sesión, el móvil queda como estaba: TalkBack, Switch Access y Voice Access apagados, el idioma del sistema, el tamaño del texto, el modo de navegación, el modo oscuro, los ajustes de la app y la app `.profile` desinstalada. Así se deja escrito en el informe.
- **CA-022-03 Cada casilla tiene un resultado escrito**
  - **Dado** una casilla de los bloques B a E
  - **Cuando** se da por hecha
  - **Entonces**:
    - Su `dispositivo.md` de origen anota el resultado (Pasa, Falla, Aceptada o Cerrada sin verificar), la fecha, el entorno y la evidencia: lo que se oyó o se vio, la medida o la captura, si la hay.
    - «Aceptada» y «Cerrada sin verificar» llevan el motivo y las palabras del propietario.
    - La sección de esa spec en `docs/PLAN.md` («Casillas de la 0NN») queda sin ninguna marca **[Pendiente]** sin resultado.
    - El **informe de la 022** (`specs/022-auditoria-en-dispositivo/informe.md`) lleva una tabla con una fila por casilla: spec de origen, casilla, resultado y enlace a su detalle.
- **CA-022-04 Lo que falla es un hallazgo, y no se arregla aquí**
  - **Dado** una casilla con resultado «Falla»
  - **Cuando** se registra
  - **Entonces** el informe abre un hallazgo **H-022-NN** con:
    - el criterio de origen (CA, CL o hallazgo anterior);
    - el entorno;
    - cómo se reproduce;
    - la gravedad;
    - el destino.
  - La gravedad es una de tres:
    - **Alta:** alguien no puede hacer una acción principal de la app, se pierden o se exponen datos, o se incumple un principio de la constitución sin excepción aprobada. Ejemplos: una acción sin camino con lector o con Switch Access, o la notificación que enseña la tarea cuando la versión genérica debería salir.
    - **Media:** se puede hacer, pero con un estorbo serio. Por ejemplo, un anuncio que no se oye pero tiene otro camino, o algo tapado al 200 % que se alcanza desplazando.
    - **Baja:** el resto.
  - **Regla de excepción prevista** (Q-022-5): si lo que falla ya tiene su salida escrita en el criterio de revisión de un ADR aceptado (por ejemplo, ampliar una excepción de P6 o descartar una función), el hallazgo es **Medio**, aunque incumpla un principio, y lo decide la spec de corrección. Sin esa regla, sería **Alto**.
  - El destino es la **spec de corrección** (Q-022-1). Ningún hallazgo se corrige en la 022 (alcance 1a).
  - Si el propietario lo acepta tal cual, el resultado pasa a «Aceptada» y el hallazgo se cierra con sus palabras.
- **CA-022-05 La auditoría no cambia la app**
  - **Dado** la rama de la 022
  - **Cuando** se compara con `main`
  - **Entonces** solo cambian archivos de `specs/`, `docs/` y `CLAUDE.md`. No cambian `app/`, `tools/`, `design/` ni `.github/`.
  - Las pruebas provisionales (sondas de integración, *fixtures*) no se suben, o se borran antes del cierre.

### B. Cerradas sin verificar, por decisión del propietario

- **CA-022-06 Android 8 y 12L (PD-10)**
  - **Dado** que el propietario decidió no probar en otros emuladores (alcance 2)
  - **Cuando** se cierra la 022
  - **Entonces** queda como **Cerrada sin verificar (propietario, 2026-10-16)** todo lo que pedía API 26 o API 32:
    - T-011-09: T-011-03 a–d, CL-011-4 y 5, y CA-011-01, 03, 04 y 08 en API 26–32, también con la card de deshacer y con el grupo de fotos.
    - De la 014: la card de 10 s en Android 8 y 9 (CA-014-06).
    - De la 016: el escenario del grupo con `tools/check-recents.sh`.
    - De la 017: Ajustes con la fila nueva.
    - De la 018: C-018-3 y CA-018-05.
    - De la 019: el canal, el permiso, `java.time`, SQLite 3.18, ICU, `LocaleSpan`, el acento amarillo de la bandeja y el (d) de su cierre.
    - De la 021: C-021-3 y la barra de Android 8.0 de CA-021-09.
  - **PD-10 queda cerrada** con esa decisión.
  - En la spec 011 y en `threat-model.md` se anota, y en el ADR-0019 se añade como **nota de estado, sin cambiar la decisión**, que el **mecanismo B** de «Recientes» (Android 8–12) sigue siendo **[Suposición]**: en esas versiones la miniatura podría verse, y el propietario acepta ese riesgo. La regla de desempate del ADR-0019 no se aplica porque no hay medida.
  - En el ADR-0021 se añade una nota de estado, sin cambiar la decisión: los 10 s de Android 8 y 9 no se han visto en un dispositivo.
- **CA-022-07 Otras marcas, otros lectores y Android 8–11**
  - **Dado** el mismo alcance 2
  - **Cuando** se cierra la 022
  - **Entonces** quedan como **Cerradas sin verificar** las comprobaciones que piden otro fabricante, otro lanzador, otro lector de pantalla u otra versión de Android:
    - el cuadrado de esquinas casi rectas con otro lanzador (CA-018-02);
    - la voz de la notificación con Samsung Voice Assistant o con TalkBack de Android 8–12 (CA-019-21);
    - la lupa del sistema en Android 8–11 (CA-017-13 y ADR-0013);
    - el *splash* de otros fabricantes.
  - Si un tester de la beta informa de un fallo en alguna de ellas, se trata como un hallazgo nuevo.
- **CA-022-08 Sin tablets (PD-11, R-25)**
  - **Dado** que el propietario dijo «solo móvil» (alcance 4; D28)
  - **Cuando** se cierra la 022
  - **Entonces**:
    - No se instala ningún emulador de tablet ni se comprueba la app en pantallas grandes.
    - **PD-11** pasa a **aplazada**: se retoma si se decide admitir tablets o si Play lo exige.
    - **R-25** queda aceptado con esa nota.
    - Si se excluyen las tablets en la consola de Play se decide en F6, al crear la ficha.

### C. Ya cumplidas, se cierran con su evidencia

- **CA-022-09 Lo que ya demostró la CI de `main`**
  - **Dado** que la CI de `main` sobre `2e835cf` está en verde: ejecución 38761348413 del 2026-10-15. **[Hecho]**, visto con `gh run list --branch main` al redactar esta spec; el plan comprueba qué pasos corrió
  - **Cuando** se revisan las casillas que solo esperaban a la CI
  - **Entonces** se marcan **Pasa**, citando esa ejecución:
    - los *goldens* de Ajustes de la 015, la fila de la 017 (`settings_lockzoom_*`) y el bloque de la 019 (`settings_notifications_*`), con sus PNG en el repositorio;
    - las suites en oscuro de la 021 en Linux;
    - los *goldens* de la 013 (`013/dispositivo.md` §6);
    - el paso de avisos de licencias de la 015 (`check-licenses.sh`).
  - Si en la ejecución falta alguno de esos pasos, se lanza la CI sobre `main`, o la casilla queda **[Pendiente]** hasta la siguiente ejecución.
- **CA-022-09a El trabajo de publicación en modo testers**
  - **Dado** el commit auditado
  - **Cuando** se lanza a mano `release.yml` en modo testers desde `main`, con el permiso del propietario
  - **Entonces** termina en verde, con los avisos de identidad esperados (CA-020-04). Así se cierra CA-021-11 y se cumple el aviso de `CLAUDE.md` antes de entregar a testers.
- **CA-022-10 Lo que el propietario ya vio en el Xiaomi el 2026-10-15**
  - **Dado** que el propietario confirmó a ojo, con la *release* de `2e835cf` instalada:
    - el arranque en frío en `paper` con la «u.», en claro y en oscuro;
    - los iconos de las barras sobre la enhorabuena y sobre la card de deshacer;
    - la app y la web en claro con el modo oscuro de HyperOS.
  - **Cuando** se anotan en `specs/021-modo-oscuro-y-arranque/dispositivo.md`, con la fecha y lo que dijo el propietario («van bien», a ojo; hoy no consta en el repositorio)
  - **Entonces**:
    - C-021-1 y C-021-2 en el Xiaomi quedan **Pasa (a ojo, propietario, 2026-10-15)**.
    - El *splash* oscuro de la 018 (casilla de CA-018-13) queda **Pasa** por lo mismo; esa parte quedó superada por el `paper` de la 021.
    - Que la app y la web se vean en claro con el modo oscuro del sistema cuenta para C-021-5 y C-021-6 en el Xiaomi. **CL-021-7** (el modo oscuro **forzado** por app) no se da por visto: está en CA-022-28.
    - C-021-7 y la barra sobre la card (cierre de T-021-09) quedan **Pasa a ojo, sin medir**. Su medida de contraste sigue en CA-022-29.
    - La medida de arranque (C-021-9) sigue en CA-022-29.

### D. En el emulador (Claude Code, sin el propietario)

- **CA-022-11 «Recientes» antes de entregar a testers**
  - **Dado** la *release* del commit auditado en el emulador
  - **Cuando** se pasa `tools/check-recents.sh` en vertical sobre:
    - una tarea de texto, una con imagen, una con un grupo de 3 fotos, una con PDF y una web;
    - la card de deshacer a la vista;
    - «Todo hecho.»;
    - el listado;
    - Ajustes.
  - **Entonces** la tarjeta sale lisa en todos los casos y `loop` y `record` no fallan (CA-011-01, 03, 04 y 08).
  - En horizontal se mira a ojo y recortando, porque el script no está calibrado para el horizontal (casilla de la 016). Calibrarlo es trabajo de herramienta, fuera de alcance.
- **CA-022-12 Pantalla pequeña y texto al 200 % (bajo (a) de la 016)**
  - **Dado** el emulador a 360 × 640 dp con el texto al 200 %
  - **Cuando** se abren:
    - el carrusel con «Foto no disponible»;
    - el editor con el aviso compuesto de CA-016-21 mientras se preparan las fotos;
  - **Entonces**:
    - el aviso «Foto no disponible» se ve entero, sin quedar bajo la cabecera ni el pie;
    - la vista previa del editor se ve con al menos su mínimo de 56 dp;
    - nada queda tapado sin poder alcanzarlo desplazando.
- **CA-022-13 Una foto dañada en el carrusel (bajo (b) de la 016)**
  - **Dado** un grupo con una de sus versiones completas corrompida (no ausente)
  - **Cuando** se llega a ella con TalkBack en el emulador
  - **Entonces** la foto se anuncia como «Foto no disponible» (CA-016-20, Q-016-2), y no solo como «Foto {i} de {n}».
- **CA-022-14 El corte del texto de la notificación (bajo (f) de la 019)**
  - **Dado** una tarea de más de 120 letras con emoji compuestos (ZWJ) y letras acentuadas
  - **Cuando** sale su notificación en el emulador
  - **Entonces** el corte cae entre dos letras completas, sin partir ningún emoji ni acento (CA-019-16).
- **CA-022-15 Catalán, gallego y euskera (CL-015-7)**
  - **Dado** el emulador con el sistema en `ca`, en `gl` y en `eu`
  - **Cuando** se abre la app con el idioma «Como el sistema»
  - **Entonces** la app sale en español con `ca` y en inglés con `gl` y `eu` (reglas de la 010), también Ajustes y la notificación.
- **CA-022-16 Notificación con la app en segundo plano y con la pantalla apagada (bajo (g) de la 019)**
  - **Dado** el emulador
  - **Cuando** se comprueban por separado:
    - tocar la notificación con la app 11 minutos en segundo plano: vuelve a la tarea actual (CA-019-20);
    - la notificación con la pantalla apagada (CA-019-19a);
  - **Entonces** cada una se comporta como dice su criterio.

- **CA-022-16a Sin navegador: el aviso de Ajustes (M2 de la 012 y 013 §6)**
  - **Dado** el emulador con el navegador desactivado y TalkBack encendido
  - **Cuando** se toca Ayuda en Ajustes y sale «No hay ninguna app…»
  - **Entonces**:
    - el aviso se oye **una sola vez**, después de las opciones (CA-013-05);
    - no queda un aviso obsoleto al volver a tocar otra fila (M2 de la 012).
  - «Reintentar» ya no existe: era de las pantallas de licencias que retiró la 015, así que esa parte se cierra sin probarla.
  - Al acabar se reactiva el navegador.
- **CA-022-16b Los anuncios con catalán, gallego y euskera (012 §8)**
  - **Dado** el emulador con el sistema en `ca` y luego en `gl`
  - **Cuando** TalkBack dice un anuncio de la app
  - **Entonces** se anota qué voz lo dice. Con la voz del sistema es lo aceptado por el ADR-0020 y el ADR-0023, y queda **Aceptada**.

### E. En el Xiaomi, con el propietario (sesiones guiadas)

Cada casilla cita lo que se comprueba. El plan las agrupa en sesiones. **TalkBack** se oye en el móvil: el panel de voz del emulador no basta (hallazgo 1 de la 014).

- **CA-022-17 TalkBack: foco y anuncios**
  - **Dado** TalkBack encendido en el Xiaomi, con la app y el sistema en español
  - **Cuando** se recorre cada caso con los gestos reales
  - **Entonces** se oye y se enfoca lo que dice su criterio:
    - **Tarea actual y adjuntos:**
      - La limitación de foco de CA-007-22.
      - Los anuncios del editor de la 016: «{n} fotos añadidas», el compuesto de CA-016-21 sin que lo pise «Vista previa: …», «Adjunto quitado» y «Preparando…».
      - El gesto real de «siguiente elemento» sin una segunda parada en el nodo vivo.
      - Cinco cambios seguidos de foto con el gesto real, con un único «Foto {i} de {n}» cada vez.
      - Con el bloqueo de zoom: el gesto real de «desplazar adelante» y «desplazar atrás» (recorre la foto alta y luego pasa a la siguiente) y dos dobles toques seguidos en las dos filas, con cada estado dicho una vez (017).
    - **Eliminar con deshacer (014):**
      - Mover el foco fuera de la card en el listado con un gesto real (la cuenta se reanuda).
      - «Todo hecho.» con la voz.
      - El tiempo hasta el primer foco en «Deshacer»: se anota, sin umbral.
      - TalkBack y Switch Access encendidos a la vez.
    - **Ajustes y notificaciones (015, 019):**
      - El interruptor de notificaciones como un solo nodo.
      - El acordeón se despliega sin anuncio y hay un solo anuncio al cambiar de opción.
      - «Notificaciones al día» sin parada propia. Si la tiene, es un hallazgo contra CA-019-26.
      - La línea de privacidad como parada tras la fila.
      - Dónde cae el foco tras el diálogo del permiso.
      - Se oyen «Notificaciones activadas.», el aviso de bloqueo con su botón, «Notificaciones permitidas.» al volver del sistema y el aviso de error.
    - **Hojas (013 §6):** el foco al cerrar cada hoja vuelve a donde dice su spec.
    - **Fuera de la app:**
      - TalkBack lee «Una.», sin nada más como «imagen», en el lanzador, en la lista de aplicaciones y en Ajustes → Aplicaciones, con iconos con tema y sin ellos (C-018-7).
      - Con el móvil bloqueado, cuando la pantalla se enciende sola con una notificación (019): con el contenido sensible **oculto**, que TalkBack lea cualquier parte de la tarea es un hallazgo **alto** (P4, CA-019-17); con la preferencia por defecto, lo decide el sistema y se anota como **Aceptada**.
    - **Al volver de «Recientes»:** el blanco intermedio y dónde cae el foco (fila de F5, 2026-09-30).
    - **Arranque y giro (021):** lo que se dice al arrancar y al girar es lo que dicen las specs de cada pantalla, sin frases nuevas. En el emulador solo se contó el número de frases. No se instala `8787643` para comparar de oído.
- **CA-022-18 TalkBack con el texto al 200 % (N-1 de la 019 y M2 de la 015)**
  - **Dado** TalkBack y el texto al 200 % en el Xiaomi
  - **Cuando**:
    - se enciende Notificaciones con el permiso rechazado;
    - se provoca «No hay ninguna app…» desde Ayuda, si se puede provocar en el móvil;
  - **Entonces**:
    - el aviso de bloqueo **se oye** aunque el bloque quede bajo el pliegue (N-1);
    - la fila que tenía el foco sigue a la vista o se recupera (M2).
  - Si no se puede provocar «No hay ninguna app…» sin desinstalar ni desactivar el navegador del propietario, la casilla de M2 pasa a «Aceptada» con el resultado del emulador.
- **CA-022-19 La voz con el idioma de la app (R-26; ADR-0020, 0023 y 0025)**
  - **Dado** el Xiaomi con el sistema en inglés y la app en español, después al revés, y por último con el sistema y la app en inglés (012 §8) (Q-022-4)
  - **Cuando** TalkBack lee:
    - «Idioma, Español» y «Como el sistema» en Ajustes (CA-015-11);
    - un aviso de error de Ajustes (CA-015-12);
    - la fila «Bloquear zoom» y sus avisos (CA-017-17);
    - «Foto {i} de {n}», incluida la frase `eng-USA` suelta junto a la primera acción, vista en la 016;
    - la notificación, completa y en su versión genérica, cada una con su marca de idioma (`LocaleSpan`, CA-019-21), también con la voz del otro idioma **sin instalar**;
  - **Entonces**:
    - lo que se recorre se oye con la voz del idioma de la app;
    - los anuncios, las acciones y los títulos de las hojas pueden oírse con la voz del sistema: es la excepción aprobada.
  - Además, al **cambiar el idioma del sistema**, el canal de la notificación toma el nombre nuevo (CA-019-21, `LOCALE_CHANGED`).
  - Si algo de la app que se recorre se oye con la voz del sistema, es un hallazgo contra el ADR-0023. Su criterio de revisión ya prevé replantear la excepción, así que es **Medio** por la regla de CA-022-04 (Q-022-5).
  - Si la notificación no se oye con la voz de su idioma, se aplica el criterio de revisión de CA-019-21: la notificación pasa a ser una cuarta excepción de P6, con una versión nueva de la constitución, o se descarta su cambio de idioma. Lo decide la spec de corrección. Es **Medio** por la misma regla.
- **CA-022-20 Switch Access con las teclas de volumen**
  - **Dado** Switch Access en el Xiaomi, con las teclas de volumen como conmutadores
  - **Cuando** se recorre por barrido
  - **Entonces** se alcanza y se activa cada elemento, en el orden del lector:
    - la card de deshacer (014);
    - Ajustes: título, opciones, aviso y Volver (CA-015-21, 012 §8 y 013 §6);
    - «Foto siguiente» y «Foto anterior» y las acciones de desplazar, también en horizontal (016);
    - la fila «Bloquear zoom» y las acciones de la tarea con el bloqueo (017);
    - dos opciones seguidas del bloque de notificaciones (019);
    - y lo mismo al volver de «Recientes» (fila de F5).
  - Si cambiar de foto falla con Switch Access, el hallazgo cita el ADR-0022, cuyo criterio de revisión nombra esta auditoría.
- **CA-022-21 Voice Access**
  - **Dado** Voice Access en el Xiaomi, en el idioma que admita
  - **Cuando** se dan las órdenes por su nombre
  - **Entonces** funcionan:
    - «tocar Bloquear zoom» (el nombre va primero, WCAG 2.5.3);
    - «desplazar a la izquierda» y «a la derecha» (cambia de foto);
    - «desplazar hacia abajo» y «hacia arriba» con una foto alta y el bloqueo encendido;
    - «Foto siguiente» y «Foto anterior»;
    - «toca 2» con los números superpuestos y «toca notificaciones» (se anota la ambigüedad con las opciones) (019);
    - las acciones de la card de deshacer (014);
    - abrir y descartar la notificación por voz (019).
  - Si cambiar de foto falla por voz, el hallazgo cita el ADR-0022.
  - Si Voice Access no está disponible en el Xiaomi o no admite español ni inglés, la casilla pasa a «Aceptada» con el motivo.
- **CA-022-22 Lupa del sistema (ADR-0013, CA-017-13)**
  - **Dado** la ampliación de accesibilidad de HyperOS
  - **Cuando** se usa a pantalla completa y en ventana:
    - sobre la tarea con imagen y con grupo, con el bloqueo encendido y apagado;
    - con la app delante y tras volver de «Recientes»;
  - **Entonces**:
    - amplía y se mueve por la pantalla como en cualquier otra app;
    - un swipe horizontal sobre un grupo sigue cambiando de foto (ADR-0022).
- **CA-022-23 Texto al 200 % con la barra de tres botones**
  - **Dado** el Xiaomi con el texto al máximo y la navegación de tres botones
  - **Cuando** se abren:
    - la card de deshacer, en vertical y en horizontal, y su aviso de error de recuperación (B4 de la 014);
    - el editor con un texto largo, con fotos y sin ellas (hallazgo previo a la 016);
    - Ajustes;
    - el bloque de notificaciones desplegado con la opción 3, la línea de privacidad y el aviso, en ES y en EN (019);
  - **Entonces** nada queda tapado por la barra ni cortado sin poder alcanzarlo.
  - El editor con «+» y «Guardar» medio bajo la barra ya está visto en el emulador. Si se repite, es un hallazgo **medio** contra la 003.
- **CA-022-24 Reducir movimiento**
  - **Dado** «Quitar animaciones» en el Xiaomi
  - **Cuando** se abren:
    - Ajustes y el interruptor (015);
    - el pulsado de los botones (013);
    - el acordeón de notificaciones (019);
    - el arrugado y la enhorabuena;
  - **Entonces** se ven sin animación o en un solo paso, como dice cada spec.
- **CA-022-25 Teclado físico, ratón, *trackpad* y lápiz (Q-022-3)**
  - **Dado** los accesorios que tenga el propietario
  - **Cuando** se usan en el Xiaomi
  - **Entonces** se cumple lo ya comprobado en el emulador:
    - el orden de Tab y el anillo de foco en Ajustes, con el acordeón plegado y desplegado (015, 017, 019);
    - Intro, Espacio y Escape; en el acordeón, las flechas solo mueven el foco y la opción enfocada se desplaza a la vista (019);
    - las flechas del carrusel y Av Pág / Re Pág, también en horizontal y con una foto clara y otra oscura (016, 017);
    - con el bloqueo de zoom, la foto no se mueve ni se amplía con el lápiz, el ratón, la rueda ni el pellizco del *trackpad*, y el swipe horizontal con lápiz y ratón sí cambia de foto (017, Q-017-9);
    - el anillo de foco con teclado tras volver de «Recientes» (fila de F5).
  - Se anota, sin criterio, si tras un clic de ratón dentro de la foto las flechas arriba y abajo dejan de mover con el bloqueo (observación de la 017; no es una alternativa documentada).
  - Con lo que no tenga, la casilla pasa a «Aceptada» con el resultado del emulador.
- **CA-022-26 Gestos del sistema y giro**
  - **Dado** el Xiaomi
  - **Cuando** se comprueban:
    - el gesto de volver desde el borde, con gestos y con tres botones, con el bloqueo y sin él (CL-017-6);
    - el giro con el bloqueo de zoom y con el **bloqueo de rotación del sistema** (017);
    - el giro de una tarea con 3 fotos, sin banda negra ni blanca, a ojo (021);
    - la entrada en pantalla dividida (CA-021-05);
  - **Entonces** cada caso cumple su criterio.
  - En la pantalla dividida, un fotograma negro suelto sigue aceptado (2026-10-15). Se anota cuántas entradas lo muestran.
- **CA-022-27 «Recientes» en HyperOS (spec 011)**
  - **Dado** la *release* del commit auditado en el Xiaomi
  - **Cuando** se comprueban:
    - la duración del blanco al volver;
    - la captura del sistema con la app delante;
    - la cámara y el selector abiertos desde la app;
    - «Recientes» abierto desde la propia app (CL-011-14, solo informativo);
  - **Entonces**:
    - la captura del sistema sale con la app, sin blanco (CA-011-04);
    - el blanco solo aparece en la tarjeta de «Recientes»;
    - se anota lo que hace HyperOS en cada caso.
- **CA-022-28 Arranque, iconos con tema y oscurecimiento del sistema (018, 021)**
  - **Dado** el Xiaomi
  - **Cuando** se comprueban:
    - los iconos con tema encendidos: el arranque sigue siendo la «u.» negra sobre `paper` (C-021-11);
    - el «modo oscuro para apps» de HyperOS aplicado a la app y, si el móvil las tiene, las opciones de desarrollo que fuerzan el modo oscuro (CL-021-7);
    - el ajuste de accesibilidad de HyperOS que oscurece las apps, si existe (CL-021-8);
    - el arranque al **tocar una notificación** de la `.profile` con el proceso cerrado (C-021-10, CL-021-4);
  - **Entonces**:
    - el arranque no cambia con los iconos con tema;
    - la app sigue en claro con el modo oscuro forzado y con el ajuste que oscurece las apps. Si el sistema la oscurece igualmente, es un límite del sistema y se anota como **Aceptada**, sin hallazgo;
    - desde la notificación se ve `paper`, con la «u.» o sin ella, nunca blanco ni negro.
  - «Tamaño de visualización» al máximo y los iconos con tema sobre un fondo de poco contraste son **opcionales**: si no se hacen, quedan «Aceptada (opcional)».
- **CA-022-29 Medidas en el Xiaomi**
  - **Dado** la app `.profile` aparte y el propietario sin usar el móvil
  - **Cuando** se mide
  - **Entonces** cada medida queda en `docs/perf/baseline.md` y en su `dispositivo.md`:
    - **Arranque en frío** del commit auditado frente a `8787643`, el último de `main` antes del código de la 021: n ≥ 20 cada uno, alternando, con el sistema en claro y en oscuro (C-021-9, CA-021-10). Pasa si:
      - el p50 no empeora más que la **deriva**, que es la diferencia entre dos pasadas de `8787643` el mismo día en el Xiaomi (referencia anterior: 6–8 ms);
      - el p50 en oscuro no supera al de claro en más de esa deriva;
      - y todo queda por debajo de 1 s (P2).
    - **Grupo de fotos (016, R-24):**
      - el hueco al cambiar de foto;
      - el espacio en disco de una tarea de 10 fotos de 24 MP;
      - el p90 de raster del carrusel y del arrugado con la foto.
      - Se anotan; no hay umbral nuevo. El pico de memoria ya está aceptado (ADR-0024).
    - **Contraste de los iconos de las barras** con la navegación de tres botones sobre la hoja, la card de deshacer y la enhorabuena (C-021-7 y cierre de T-021-09). Pasa con 3:1 o más.
    - Las capturas de esta medida siguen CA-022-02.
- **CA-022-30 Notificaciones en situaciones reales (019)**
  - **Dado** el Xiaomi con la *release* del commit auditado y las notificaciones encendidas
  - **Cuando** se comprueban:
    - una entrega con el móvil **bloqueado y la app cerrada**, con la preferencia de contenido sensible en «oculto»: sale la versión genérica (CA-019-17);
    - **tocar la notificación** con la app cerrada: abre la tarea actual. Se vigila **O-1** de la 020: que la app no se quede sin pintar;
    - la **app a la vista** a la hora del aviso (CA-019-19a);
    - el ahorro de batería, «No molestar», una **actualización de la app** y un **cambio de huso**;
    - la pantalla apagada mucho rato;
  - **Entonces** cada caso se comporta como dice la 019.
  - El retraso se anota. Ventana de 15 minutos no es criterio de paso: CA-019-11 es un objetivo, no una garantía.
  - «Restringir» de HyperOS y la parada forzada no se repiten: su comportamiento ya está medido (S7) y va a la ayuda web.
  - Si O-1 se reproduce, es un hallazgo **alto**.

- **CA-022-30a Modo avión (P3)**
  - **Dado** el Xiaomi en modo avión, con la `.profile`
  - **Cuando** se abre la app en frío, se crea una tarea de texto, otra con foto y otra web, se completa una, se elimina otra y se abre la tarea web
  - **Entonces** todo funciona sin conexión, y la tarea web dice que necesita conexión, como dice la 009 (ADR-0016).
  - Se añaden a CA-022-30 los modos de concentración de HyperOS, si existen, junto a «No molestar».

### F. Cierre

- **CA-022-31 El estado de cada spec**
  - **Dado** que todas las casillas de una spec tienen resultado
  - **Cuando** se cierra la 022
  - **Entonces** esa spec (011, 013, 014, 015, 016, 017, 018, 019 y 021) pasa a **Implementada** si no le queda ningún hallazgo alto ni medio abierto (Q-022-2). Si le queda alguno, sigue en **Implementada parcialmente** y cita el hallazgo y la spec de corrección.
  - La 011 pasa a **Implementada, con casillas cerradas sin verificar (CA-022-06)**, y así lo dice la cabecera de su spec: el mecanismo B no se ha visto en un dispositivo.
  - La 012 sigue **Sustituida** por la 015: sus casillas se cierran en Ajustes. La de CA-012-06 a los 10 minutos con el reloj real se cierra por la 015 (CA-015-16 y 20h, aceptadas por el propietario).
- **CA-022-32 Los documentos quedan al día**
  - **Dado** el cierre
  - **Cuando** se revisa la documentación
  - **Entonces**:
    - en `docs/PLAN.md`:
      - las secciones «Casillas de la 014» a «Casillas de la 021», la de la 012, la fila de la 011 (§3) y el párrafo de las casillas de la 013 en «Troceado de F5» llevan el resultado de cada casilla;
      - PD-10 está cerrada y PD-11 aplazada;
      - R-24, R-25 y R-26 están actualizados;
      - la fila de F5 y el §9 dicen que la siguiente es la 023;
      - la tabla de trazabilidad tiene la fila de la 022;
    - `CLAUDE.md` refleja la fase;
    - el informe lista los hallazgos H-022-NN abiertos con su gravedad y su destino.
- **CA-022-33 La salida de F5**
  - **Dado** el criterio de salida de F5 («0 hallazgos altos»)
  - **Cuando** la 022 deja algún hallazgo **alto** abierto
  - **Entonces** el informe y `docs/PLAN.md` dicen que **la beta (F6) no empieza** hasta que la spec de corrección lo cierre.
  - Los medios y los bajos no bloquean F6 salvo que el propietario lo diga.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-022-1 | El propietario no puede seguir a mitad de una sesión | Se para. Lo hecho queda anotado y el móvil se restaura (CA-022-02). Lo que falta se retoma en otra sesión. Ninguna casilla se da por hecha a medias |
| CL-022-2 | Una casilla no se puede provocar en el Xiaomi sin tocar algo del propietario (desinstalar el navegador, borrar sus datos, cambiar su cuenta) | No se hace. El propietario elige «Aceptada» (con el resultado del emulador, si lo hay) o «Cerrada sin verificar» |
| CL-022-3 | Una casilla pasa en el Xiaomi pero falló antes en el emulador (como el hallazgo 1 de la 014) | Para lo que se oye o se ve en un móvil real, manda el Xiaomi. Se anota la diferencia. El emulador manda en las medidas que deben repetirse igual |
| CL-022-4 | HyperOS, TalkBack o una app del sistema se actualizan durante la auditoría | Se anota la versión nueva y desde qué casilla se usa. No se repite lo ya hecho salvo que un resultado dependa claramente de esa versión |
| CL-022-5 | La entrega de una notificación no llega a probarse el día previsto (el móvil desbloqueado, la app abierta…) | Se repite otro día. Tras tres intentos sin poder darse el caso, el propietario decide «Aceptada» o «Cerrada sin verificar» |
| CL-022-6 | Una medida sale fuera de la deriva una vez | Se repite la serie entera. Solo cuenta como «Falla» si se repite fuera de la deriva |
| CL-022-7 | Durante la auditoría aparece un fallo que ninguna casilla preveía | Se registra igual, como H-022-NN con su gravedad. No se amplía la 022 para comprobarlo a fondo |
| CL-022-8 | Una casilla falla, pero la spec de origen ya acepta ese comportamiento (por ejemplo, el fotograma negro de la pantalla dividida) | Resultado «Aceptada», citando la aceptación anterior. No se abre hallazgo |
| CL-022-9 | El commit auditado cambia a mitad (una PR de Dependabot o una corrección se fusiona) | Se sigue con el commit anterior salvo que la PR toque `app/`. Si la toca, el propietario decide si se repiten las casillas afectadas (CA-022-01) |
| CL-022-10 | La app del propietario tiene muchas tareas reales | Las pruebas no cambian su orden ni su contenido. Para lo que exige una cola concreta («Todo hecho.», la card en el listado, un grupo dañado), se usa la app `.profile` aparte, que tiene sus propios datos |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| — | La 022 no cambia la app | Nada nuevo. Los estados vacíos y de error que se comprueban son los de cada spec de origen |

## 6. Accesibilidad

La spec **no añade ni cambia** ninguna interacción. Su contenido es justamente la verificación de accesibilidad en un móvil real (bloque E):

- TalkBack de oído, también en el idioma de la app;
- Switch Access;
- Voice Access;
- la lupa del sistema;
- teclado y otros accesorios;
- texto al 200 %;
- reducir movimiento.

Las excepciones de P6 se comprueban tal como están aprobadas. Lo que no cumpla se registra como hallazgo y no se arregla aquí.

## 7. Textos (ES / EN)

Sin textos nuevos.

| Clave | ES | EN | Notas |
|---|---|---|---|
| — | — | — | — |

## 8. Fuera de alcance

- **Corregir cualquier cosa** (alcance 1a). Esto incluye los hallazgos de código ya conocidos, que pasan tal cual a la spec de corrección sin verificarse aquí:
  - 013-A-M1: las opciones de «¿Dónde la pones?» no funcionan con teclado.
  - B1 de la 015: el anillo de foco recortado.
  - M4, M5 y M7 de la 015.
  - (d) de la 016: `SendAnnouncementAnnouncer` es código muerto.
  - (e) de la 016: CL-016-3 sin test propio.
  - (3) de la 018: «Una.» literal en la web de pruebas.
  - (b) y (c) de los hallazgos bajos de la implementación de la 019.
  - M9 de la 015 (si TalkBack al volver del navegador es una excepción de P6 con ADR): lo decide el propietario en la spec de corrección.
  - (d) de la 017: los `grep` de CA-017-13 sin automatizar.
  - N-2 y N-3 de la 019.
  - C-5 de la 020: el paso `gradle-wrapper` en el trabajo de publicación.
  - La observación de `accessibleNavigation` con Switch Access en el listado, la enhorabuena y la bienvenida (014).
  - Calibrar `tools/check-recents.sh` en horizontal.
  - Correr en la CI el test de Chrome del selector múltiple.
  - TD-1, TD-2, H-5 y H-6.
- **Android 8 y 12L, otras marcas, otros lectores y tablets:** cerradas o aplazadas por decisión del propietario (CA-022-06 a 08).
- **iOS y VoiceOver** (D17). B6 de la 014 sigue anotado para F-iOS.
- **La web de pruebas** (D4; R-15): sus casillas se quedan como están. Son el pellizco y Ctrl + rueda en Chrome con la 017, el `lang` que no declara y la falta de favicon de 16 px (018).
- **La política de privacidad, Data Safety, la ficha de tienda, el presupuesto de tamaño, H-2 de la 020, la revisión legal de las licencias y la ayuda web** (entre otras cosas, «Restringir» de HyperOS): son de la 023 y de F6.
- **C-4 y `actionlint` de la 020:** van a F6.
- **Cambiar las excepciones de P6.** Si la auditoría lo justifica (por ejemplo, los puntos del carrusel, ADR-0022), lo propone la spec de corrección con su ADR.

## 9. Preguntas abiertas

- **Q-022-1 [Pendiente, propietario] ¿Adónde van los hallazgos?** Opciones:
  - **a)** Una spec de corrección nueva, **024**, entre la 023 y F6.
  - **b)** Dentro de la 023.
  - **c)** Una spec por hallazgo alto.
  - **Recomendación:** a), una sola spec 024 con todo lo de la auditoría y los hallazgos de código de §8. La 023 es de privacidad y tienda, y conviene no mezclarlas.
- **Q-022-2 [Pendiente, propietario] ¿Qué impide pasar a Implementada?**
  - **Recomendación:** que no quede ningún hallazgo alto ni medio abierto de esa spec. Los bajos se anotan y no lo impiden (CA-022-31).
- **Q-022-3 [Pendiente, propietario] ¿Qué accesorios tienes?** Teclado físico (Bluetooth o USB-C), ratón, *trackpad* o lápiz.
  - **[Suposición]** Si no hay ninguno, CA-022-25 entera pasa a «Aceptada» con lo hecho en el emulador.
- **Q-022-4 [Pendiente, propietario] ¿Se puede cambiar el idioma del sistema del Xiaomi durante una sesión?** Hace falta para CA-022-19: la voz con el otro idioma y el canal de la notificación.
  - **Recomendación:** sí, a inglés durante esa sesión, y se restaura al acabar.
  - Si no, CA-022-19 se hace solo con la app en inglés sobre el sistema en español, y el otro sentido queda «Cerrada sin verificar».
- **Q-022-5 [Pendiente, propietario] ¿Qué gravedad tiene un fallo que ya tiene su salida prevista en un ADR?** Por ejemplo, la voz de TalkBack en otro idioma (ADR-0023) o la de la notificación (CA-019-21).
  - **a)** **Medio:** lo decide la spec de corrección y no bloquea la beta (regla de CA-022-04).
  - **b)** **Alto:** bloquea F6 hasta resolverlo (CA-022-33).
  - **Recomendación:** a). Los ADR ya dicen qué hacer en ese caso, y el propietario oyó la voz bien en el Xiaomi el 2026-10-05.
