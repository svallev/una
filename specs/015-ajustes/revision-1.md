# Revisión 1 de la spec 015 (Ajustes)

**Fecha:** 2026-10-05 · **Spec revisada:** `spec.md` (Borrador) · **Revisores:** `spec-reviewer`, `a11y-reviewer`, `security-reviewer` (informes consolidados; sin duplicados).

**Veredicto: no se puede aprobar todavía.** Dos bloqueantes, ambos de redacción, sin decisión nueva del propietario. Seguridad no ve bloqueantes. Ningún revisor ha editado la spec.

## Traspaso para la sesión siguiente

1. Sesión nueva, desde los archivos: leer `specs/015-ajustes/spec.md` y este informe.
2. Corregir la spec según las secciones de abajo (B1–B2, después I-A…I-J; los menores, a criterio).
3. Resolver las tres decisiones del propietario (sección «Decisiones») preguntándolas **numeradas en el chat**, no en el diálogo.
4. Volver a pasar `spec-reviewer`, `a11y-reviewer` y `security-reviewer`. Con los bloqueantes resueltos, no hace falta otra ronda de preguntas de fondo.
5. Cuando estén resueltos, marcar la spec **Aprobada**; después, plan y tareas, cada paso en una sesión nueva.

Los cálculos de contraste y de desbordamiento citados son de los revisores, no mediciones.

## Bloqueantes

**B1. CA-015-03: contraste del interruptor imposible** (a11y B1 y spec B1).
- Amarillo `#FFDC58` frente a papel `#F4F1EA` ≈ 1,2:1 en los dos estados (`Main.dc.html:1277`). «Pomo frente a pista ≥ 3:1» no se puede cumplir.
- Lo que contrasta es el borde de tinta: 2 px en el pomo y 3 px en la pista (> 16:1).
- Corrección:
  - (a) borde de la pista frente al papel ≥ 3:1 (WCAG 1.4.11);
  - (b) borde del pomo frente al relleno de la pista ≥ 3:1 en los dos estados;
  - (c) el estado lo da la **posición del pomo** (WCAG 1.4.1), no el color;
  - (d) declarar esos pares en `validate-tokens` y ajustar lo que dice CA-015-19.

**B2. CA-015-11 choca con CA-015-07 y CA-015-20(c, f)** (a11y B2).
- El test «todos los nodos llevan `es` y ninguno `en`» falla por diseño: «English» y «Español» llevan su propio idioma.
- Corrección:
  - exceptuar esos nodos en el test;
  - añadir un test aparte que compruebe su `locale`;
  - aclarar que «Como el sistema» va en el idioma de la app y su línea inferior («Español»/«English») en el suyo;
  - fijar cómo se comprueba el nodo fusionado «Idioma, Español» con dos marcas distintas; si Flutter/TalkBack no lo respetan, el valor va como nodo separado.

## Importantes

**I-A. Valores guardados y `keepScreenOn`** (seguridad I-1, spec I6; CA-015-05, CL-015-14/16/18, anexo; `drift_task_repository.dart:267-272`, `providers.dart:316-335`).
- `keepScreenOn()` hace `jsonDecode` sin `try/catch`: un valor ilegible puede impedir el arranque.
- La lectura actual `row == null || value != false` deja la pantalla encendida ante cualquier valor raro (fail-open).
- Corrección (nuevo CL/CA):
  - cualquier fallo al leer o decodificar un ajuste usa el valor por defecto y no impide el arranque;
  - `keepScreenOn` vale «encendido» solo si el valor es exactamente `true`; cambiar también el defecto `BootState.keepScreenOn = true`;
  - el idioma se valida contra `system|es|en`; nunca se construye un `Locale` desde el valor guardado;
  - tests: `fr`, cadena vacía, `es-MX`, cadena muy larga, JSON no válido, número, `null`, lista, en `locale` y en `keepScreenOn`;
  - anotar como [Hecho] que la clave nunca se ha escrito (`setKeepScreenOn` sin llamantes) y que cambiar el defecto de una clave existente **no** es un cambio de esquema (o pedir al plan que lo confirme; ver `docs/architecture.md`, «las claves se versionan con el esquema»).

**I-B. Pantalla siempre activa «sin límite»** (seguridad I-2, spec I4; CA-015-04, §10).
- Formalizar en `threat-model.md` (T-15 y §7) el riesgo residual aceptado: sin límite, apagado por defecto, solo con adjunto en primer plano, el sistema retira el flag al pasar a segundo plano.
- Criterio verificable: ante `paused`/`hidden` se limpia el flag (`keepOn(false)`), con el canal falso `una/screen`.
- Decir si el estado de error de la web («Necesitas conexión para ver esta página.») mantiene la pantalla encendida (recomendación: sí). CA-015-04c solo nombra «Adjunto no disponible»; CA-009-16 remitía a CA-007-12, que la 015 enmienda.
- Criterio de test acotado: «tras 60 min simulados sin toques sigue encendida y sin ningún `touched()`».

**I-C. Direcciones web** (seguridad I-3; CA-015-12/13, `tool/check_release_config.dart`).
- Las tres direcciones son constantes de compilación (P7) que vienen solo de `identity.yaml` → `AppIdentity`: ni ajustes, ni BD, ni configuración remota, ni idioma elegido.
- Sin consulta ni fragmento, ni versión, idioma o identificador. La puerta falla con `?`, `#` o `\`.
- Test: cada dirección configurada pasa `privacyLink`, sin parámetros.

**I-D. Puerta de publicación (CA-015-13)** (seguridad I-4, spec M3).
- Redactar «cada una de las tres cumple **todo** lo de CA-012-05 y su implementación actual»: puerto, IP (incluidas hex y numérica), dominio sin punto, subdominios de reservados, espacios y caracteres de control, valor vacío, clave ausente = error.
- Decir `example.org`, `example.net` y sus subdominios, no «`.org`, `.net`».
- «Idéntica a otra»: normalizar (host en minúsculas, sin punto final, par host + ruta) y marcar la regla como [Suposición]. Separar direcciones y política en la frase.
- Test con tres direcciones, una por fallo; el test de «nunca más permisiva que `privacyLink`» cubre las tres.
- `/release-checklist` ejecuta `tools/check-release-config.sh` antes de **cada entrega a testers**, no solo antes de publicar.

**I-E. CA-015-17 no es comprobable** (seguridad I-5).
- Mecanismo: pantalla encendida = flag de ventana del canal `una/screen`, sin `WAKE_LOCK`; enlaces por `una/links` con `<queries>` sin cambios.
- Verificación por diff: `pubspec.yaml`, `pubspec.lock`, `AndroidManifest.xml` y `res/xml/*` sin cambios; `tools/check-android-permissions.sh release` solo con `INTERNET`; sin código nativo nuevo (o lista exacta).
- Ajustes solo en la tabla `settings`; prohibido `shared_preferences`, `wakelock_plus` y declarar `url_launcher` como dependencia directa (hoy es transitivo de `pdfrx`).

**I-F. Maquetación y accesibilidad de controles** (a11y I1, I2, I5, I7).
- Objetivos táctiles: «≥ 44 pt visibles y zona táctil ≥ 48 dp en Android» (`docs/design/tokens.md:30`). En el prototipo, «Cerrar ajustes» mide 46×46 y el enlace del menú 44 de alto: fallarían `androidTapTargetGuideline` (CA-015-01, 03, 22).
- Fila «Idioma» a 200 % (CA-015-06, 22): con «Como el sistema» el valor no cabe en una línea; exigir que pase a una segunda línea o que la fila sea una columna, sin recortar. Igual en la página de Idioma. Añadirlas al test al 200 % con `setUpAll(loadAppFonts)`.
- Opciones de idioma (CA-015-07, 20f): grupo de selección única (`inMutuallyExclusiveGroup`, rol radio con `checked`, no `selected`), con nombre de grupo «Idioma»; el check visible ≥ 3:1 y decorativo para el lector; verificable con `tester.getSemantics`.
- Teclado (CA-015-21): el foco desplaza la fila a la vista (`ensureVisible`, WCAG 2.4.11); aclarar que el título solo es foco del lector y qué control recibe el foco de teclado al entrar (Cerrar o Volver).

**I-G. Avisos de error** (a11y I3, spec I3, seguridad M-1; CA-015-12, 25, §5, 20g).
- Hacerlos **regiones vivas** (`Semantics(liveRegion: true)`) con la marca de idioma de la app, dentro del árbol y alcanzables en el orden de lectura. Así no se amplía la excepción de P6 con texto nuevo. Verificable: el nodo existe, es `liveRegion` y lleva `es`/`en`.
- Una sola regla de ciclo de vida: cada aviso se quita con la siguiente acción con éxito sobre cualquier control, o al salir de la pantalla. Definir si pueden coexistir (orden de lectura) y si «una vez por intento» repite el anuncio. CA-015-20g habla de «aviso (si lo hay)» en singular.
- Error de guardado: capturado sin registrarlo, sin dejarlo en `FlutterError`, sin mostrar su texto (como `UndoController`). Test con `Exception('texto-secreto')`.

**I-H. Idioma en caliente y TalkBack** (a11y I4, I6; spec I5; seguridad M-2).
- Fijar la secuencia: guardar → `pop` → aplicar idioma → pedir foco en «Idioma» una vez reconstruida; la página de Idioma no se repinta en el idioma nuevo antes de cerrarse. Orden de persistencia: primero se guarda, después se aplica (o reversión atómica). Los cuatro casos son idénticos: otra opción, la misma, error de guardado, cambio del idioma del sistema con «Como el sistema».
- Marcar CA-015-20 (d) y (f) como [Suposición] con casilla de dispositivo en la 022; reformular (f) como «el nodo lleva su marca de idioma».
- Las palabras de rol y estado («interruptor», «activado», «seleccionada») las dice TalkBack en el idioma del sistema: citarlas en la excepción de CA-015-11 y §6.
- Añadir a CA-015-20, 21 y 22 una línea «Verificable:» con `meetsGuideline` (`textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`), semántica y golden al 200 % ES/EN; y separar lo manual (foco de TalkBack, Switch Access, anillo de foco con teclado real, voz del idioma elegido).

**I-I. Transición del nivel 2** (spec I2, a11y M1).
- Definir la transición nivel 1 ↔ 2 y su valor con «reducir movimiento» (CA-015-01 o CA-015-22). La 012 usaba un fundido de 160 ms. Ver decisión 1.

**I-J. Trazabilidad y alcance** (spec I1, I7, I8).
- §10 omite **CA-012-08** («no se guarda nada de esta pantalla»; contradice la 015): añadir «CA-012-08 → CA-015-17». Añadir tabla 012 → 015: 04→12, 05→13, 06→16, 07→09 y 11, 09→18, 10→19, 11→20, 12→21, 13→22, 14→15, 16→23, 15 retirado.
- Decir qué pasa con las casillas de dispositivo pendientes de la 012 y los hallazgos de la 012 en `docs/PLAN.md` que afectan a las pantallas de licencias retiradas (anuladas o trasladadas a la 022).
- Añadir tablas HU → CA y P → CA (P5, P10, P11 solo aparecen implícitos). Dividir CA-015-01 (apertura/objetivo táctil frente a tiempos/reducir movimiento), CA-015-12 (confirmación, aviso, solo `https`) y CA-015-14a/b.
- §9: cambiar «Preguntas abiertas» por «Resueltas» y añadir dos [Pendiente]: revisión legal (ADR-0026, antes de F6/023; convertirla en punto bloqueante de `/release-checklist`) y voz a oído (ADR-0023, casilla de la 022).

## Menores

**Spec**
- M1: CA-015-01, «Cambio respecto de la 012… (CA-015-02)» remite mal; debe ser CA-015-01 (el menú se cierra) y CA-015-02 (regreso).
- M2: «<220 ms / <170 ms» son temporizadores de limpieza del prototipo, no duraciones de animación (0,2 s y 0,16 s). Precisar qué se mide.
- M4: «Ajustes» colisiona con los del sistema en CL-015-10 y CL-010-5/6: decir «Ajustes del sistema».
- M6: §10 mezcla «hecho» (constitución, glosario, screen-map, DEV-52) con «por hacer». CL-014-13 aún dice «Configuración y perfil».
- M7: CA-015-14a/b mencionan `assets/licenses/*.txt`, `NOTICES`, `.so`, el APK y `check-licenses.sh`: dejar el observable en el CA y mover lo técnico al anexo. «`NOTICES` siempre en el paquete» es [Suposición] en el ADR-0026.
- M8: redacción de CA-015-20(i) («con el nivel 2 abierto, tampoco es alcanzable el nivel 1») y «al momento» en CA-015-08 (poner cifra o «en el mismo fotograma»).
- M9: CL-015-15 aparece tras el 18.
- M10: CL-015-13 debe decir si el idioma resultante de «Como el sistema» en la página de Idioma se actualiza en caliente.
- M11: anexo, citar el hallazgo 012-S1 (Kotlin no revisa `userInfo`/`host`), [Pendiente] y ahora con tres enlaces.

**Documentos y diseño**
- M5: DEV-52 no registra el color del separador de 1 px (`rgba(17,17,17,.18)`, no es token; DEV-38 usó el token `disabled`). Registrar también «reducir movimiento» y el orden de lectura (Cerrar al final, decisión de la 013 frente al prototipo `:603`).
- M12: glosario, dos filas comparten el identificador `Settings` («Configuración» y «Ajustes»); falta «Confirmación de enlace».

**Accesibilidad**
- M13: la pista «Abre una página web en el navegador» va como `hint`, que TalkBack puede omitir; valorar incluirla en la etiqueta o `Semantics(link: true)` (el prototipo la incluía en el nombre, `:647`).
- M14: foco al volver tras ≥ 10 min (se ve la tarea): va al botón de menú. Fijar qué botón recibe el foco al abrirse la confirmación de enlace (prudente: «Cancelar»).
- M15: confirmación de enlace a 200 %: el host debe poder partirse (dominio largo o punycode) o el diálogo desplazarse.
- M16: error al guardar el interruptor: TalkBack dice «activado» y luego «desactivado»; aceptable si el aviso es región viva inmediata tras la fila; comprobar a mano.
- M17: Ajustes solo en vertical (CL-015-2, WCAG 1.3.4): valorar una excepción general en un ADR; no es de esta spec.
- M18: sin tareas (CL-015-4), quien usa TalkBack con otro idioma no puede cambiarlo hasta crear una: límite conocido para la beta.

**Seguridad y publicación**
- M19: referente y datos que ve el destino. El navegador se conecta con la IP del usuario y puede mostrar el referente `android-app://<paquete>`. Reflejarlo en `docs/legal/privacy-policy.md` y en Data Safety: «al abrir la web, el navegador se conecta; la app no envía nada».
- M20: verificabilidad de la confirmación previa (CA-015-12), con el canal `una/links` falso:
  - `open` no se llama sin confirmar ni al cancelar;
  - `canOpen` se llama en cada toque y no registra la dirección;
  - una dirección no `https` no llama ni a `canOpen` ni a `open`;
  - las tres filas usan la misma función.
- M21: archivo de avisos (ADR-0026):
  - actualizar los comentarios de `tools/check-licenses.sh` (líneas 2-3 y 168), que aún dicen «pantalla de licencias»;
  - adjuntar el archivo a la release (el artefacto de CI caduca);
  - cabecera con versión y sha256 del APK;
  - conservar la comprobación de que `assets/licenses/*.txt` y los `OFL.txt` siguen en `pubspec.yaml` y en el APK.
- M22: política sin tareas (CL-015-4, aceptado en Q-015-5): anotar para F6/023 que las tiendas pueden exigirla accesible sin crear antes una tarea.
- M23: Recientes (ADR-0019, CA-015-18):
  - el plan debe decir **cómo** se visita Ajustes, el nivel 2 y la confirmación con `tools/check-recents.sh` y `docs/testing.md`;
  - el `commit()` de la eliminación pendiente (CA-015-24) debe ocurrir antes de empujar la ruta.
- M24: Ajustes sobre una tarea web vuelve a hacer la petición y a borrar la sesión (ADR-0016): decirlo en CA-015-15.
- M25: la sección «Si abre enlaces externos o muestra licencias y política» de `docs/security/checklist.md` debe reducirse al enlace (ADR-0026), añadir los puntos de I-A a I-D y retirar «Los textos de licencia son `Text` plano».

## Decisiones del propietario (preguntar numeradas en el chat)

1. **Transición del nivel 2:** fundido de 160 ms (token `sheetOut`, como la 012) o cambio instantáneo. Con «reducir movimiento», instantáneo en ambos casos.
2. **Avisos de error:** regiones vivas con marca de idioma (recomendado, no amplía la excepción de P6) o `sendAnnouncement` (habría que anotarlo en el ADR-0023).
3. **Opcional:** si el subtítulo de «Pantalla siempre activa» debe avisar de que no bloquea la pantalla.

## Lo que ya está bien (verificado por los revisores)

- Constitución 1.7: la excepción de P6 (ADR-0023) y la nota de P3 (ADR-0026) están aplicadas; el ADR-0020 consta como «sustituido en parte».
- Prototipo (tablero 16): orden de bloques, textos, `aria-modal` y cierre hacia la tarea coinciden.
- Esquema v2 sin cambios: ajustes en la tabla `settings` (clave/valor JSON); sin migración.
- Sin permisos, superficie nativa ni dependencias nuevas (`canOpen` y `una/links` ya existen desde la 012); el flag de ventana no necesita permiso.
- `LinkOpener.kt` valida el esquema y no registra el enlace; con constantes de compilación y confirmación previa, el riesgo de inyección de intents es nulo.
- Enmiendas CA-010-10, CL-010-2 y CA-014-11 aplicadas; glosario con los términos nuevos (salvo M12).

## Lo que solo se puede comprobar a mano (casillas para `dispositivo.md` de la 015 y la 022)

- TalkBack: foco inicial en el título; orden título → filas → aviso → «Cerrar ajustes»; lectura del interruptor y de las opciones de idioma; foco que vuelve a «Idioma» tras cambiar de idioma; voz del idioma elegido a oído (sistema en inglés y app en español, y al revés; también con la voz no instalada); la tarea de debajo no es alcanzable; foco al volver del navegador y tras cancelar la confirmación; anuncio único de los avisos.
- Switch Access, teclado físico (Tab, Intro, barra espaciadora, Escape; anillo de foco; `ensureVisible` a 200 %), 200 % en ES y EN con 360 dp, «reducir movimiento».
- Arranque con idioma elegido: primera pintura ya en el idioma elegido (CA-015-10, CA-015-23; criterio de CA-011-05).
- VoiceOver: fuera de alcance (D17). Anotar la casilla para cuando se retome iOS.
- El Xiaomi solo con permiso del propietario y sin capturas de pantalla sin avisar.
