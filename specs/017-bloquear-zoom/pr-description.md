# PR: spec 017, Bloquear zoom

**Título:** `feat(017): lock zoom setting that keeps the task photo still`

## Qué y por qué

Un ajuste nuevo en Ajustes, **«Bloquear zoom»** (apagado por defecto), para quien trabaja encima de la foto de la tarea (la marca o dibuja sobre ella con otra herramienta). Encendido, la foto de la tarea actual con imagen (suelta o de un grupo) **no se amplía ni se desplaza por contacto** y se queda con el desplazamiento que tenía; el swipe del carrusel, las acciones del lector, el teclado y la lupa del sistema siguen igual (D24 enmendada por el propietario el 2026-10-07). No afecta al PDF, a la web ni a la tarea de solo texto. Todo es local, sin esquema, permisos ni dependencias nuevas.

- **Spec:** `specs/017-bloquear-zoom/spec.md` (estado: **Implementada parcialmente**; tabla CA → prueba en el §13)
- **Tareas:** T-017-01 a T-017-12
- **Criterios de aceptación cubiertos:** CA-017-01 a CA-017-17 y los casos límite CL-017-*; los de dispositivo, en `dispositivo.md` y en las casillas de la 022
- **ADR nuevos o afectados:** ninguno nuevo; **enmienda 1 del ADR-0022** (qué bloquea el ajuste, sin excepción nueva a P6) y nota en el ADR-0013 (con el bloqueo no hay pellizco; la lupa del sistema sigue). Constitución **1.9**, sin cambios
- **Enmiendas a otras specs (en vigor):** 007, 008, 015 y 016; DEV-54 (nueva) y notas en DEV-41, 43, 52 y 53

## Qué cambia

- **Ajuste:** clave `lockZoom` junto a `locale` y `keepScreenOn` (decodificador estricto: solo el texto `true` exacto es «encendido»; cualquier otra cosa o fallo de lectura, «apagado» sin lanzar ni registrar). Se lee en el arranque (`BootState.lockZoom`), así que el bloqueo está activo desde el primer fotograma. **Sin esquema**: `schemaVersion` sigue en 3.
- **Cola de guardados:** el indicador único de «guardando» de la 015 pasa a un conjunto de ajustes en curso y una cola FIFO (el idioma entra en ella): dos toques casi seguidos en filas distintas guardan **los dos** valores; el segundo toque en la misma fila se ignora; el fallo del primero no bloquea al segundo.
- **Ajustes:** fila «Bloquear zoom» bajo «Pantalla siempre activa» (icono de lupa con signo menos, subtítulo «Solo imágenes: sin zoom ni scroll»; DEV-54) y **un aviso de guardado por fila**, cada uno bajo la suya y con un contador de intentos compartido; `ExternalPageSession.clearLinkNotice` quita solo el aviso de enlace.
- **La foto:** `ZoomablePhoto` lee el ajuste; con él, física `NeverScrollableScrollPhysics` y el `Listener` sin `onPointerDown`, y al cambiar suelta lo que hubiera en curso. El árbol de widgets no depende del ajuste (misma foto, mismo `State` y mismo `ScrollController` al encender, apagar o volver de Ajustes). No se tocan `ImageScroll`, `PhotoCarousel`, `PhotoSwipeRecognizer` ni `CurrentTaskScreen`.
- **Qué sigue funcionando:** swipe con cualquier puntero, acciones «Foto siguiente/anterior», «desplazar» del lector y del switch, Av Pág / Re Pág y flechas, logotipo, menú y «Mantener pulsado» de completar. La tarea se lee igual con y sin el ajuste, sin anuncios nuevos.
- **Nativo:** nada. `android/` sin cambios.
- **Textos:** 2 claves nuevas en ES y EN con descripción (`settingsLockZoom`, `settingsLockZoomHint`); `settingsSaveError` se reutiliza.
- **Documentación:** `architecture`, `testing` (punteros en los tests, medición, «Recientes» con Ajustes), glosario, `screen-map`, `threat-model` (T-7) y `checklist` (una frase con `lockZoom`), DEV-54, `PLAN.md`, `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/017-bloquear-zoom/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **2861 tests en verde, 90 omitidos** (los 4 *goldens* `settings_lockzoom_*` se omiten en el Mac y, en Linux, fallan hasta generarlos, ver Pendiente) | Local (Mac) |
| `node tools/validate-tokens.mjs`, `dart run tool/gen_tokens.dart --check` | Bien (30 combinaciones de contraste de texto y 23 no textuales); tokens al día; sin valores visuales sueltos nuevos | Local |
| `/i18n-check` | ARB ES/EN con las mismas 180 claves, sin vacíos, descripciones presentes, sin literales incrustados en `lib/` ni el nombre de la app fuera de `AppIdentity` | Local |
| `/security-check` | Sin secretos en el diff; sin archivos de firma en el índice; sin `print`/`debugPrint`/red/canales nuevos en `lib/`; ver la sección de seguridad | `git diff origin/main...HEAD` |
| Diff de CA-017-16 | `pubspec.yaml`, `pubspec.lock`, `android/` (manifiestos, `res/xml`, Kotlin), `drift_schemas/` e `ios/` **sin cambios**; `schemaVersion` 3; `tools/check-android-permissions.sh release` solo `INTERNET`; los manifiestos de `debug` y `profile` solo `INTERNET`; `check-licenses.sh` en verde (84 paquetes Dart, 46 artefactos de Android, 3 APK) | Local |
| `grep` de CA-017-13 sobre `app/android` | `FLAG_SECURE` **solo** en `RecentsPrivacy.kt` (mecanismo B, Android 8-12); sin `setSystemGestureExclusionRects`, `AccessibilityDelegate`, `dispatchTouchEvent`, `onGenericMotionEvent`, `onTouchEvent`, `onInterceptTouchEvent`, `setOnTouchListener`, `Magnif`, `FLAG_NOT_TOUCHABLE`, `TYPE_APPLICATION_OVERLAY`, `importantForAccessibility`, `<accessibility-service`, `accessibilityFlags`, `filterTouchesWhenObscured` ni `setSystemUiVisibility` | Local |
| `security-reviewer` | 0 hallazgos | `git diff origin/main...HEAD` |
| `a11y-reviewer` | 0 altos, 0 medios, 4 bajos (1 corregido en T-017-12; el resto, en `PLAN.md`) | `git diff origin/main...HEAD` |
| `spec-reviewer` | 0 bloqueantes; 5 menores corregidos en T-017-12 (rueda y *trackpad* sobre la tarea entera y el grupo, CL-017-1, etiquetas de la cola, CL-017-5, plan) | `git diff origin/main...HEAD` |
| `integration_test/settings_flow_test.dart` | 3 de 3 en verde (el bloqueo se guarda, no toca los otros ajustes y sobrevive a matar el proceso) | Emulador API 37 |
| Gestos reales, multitoque, giro, tres botones, borde, «Recientes», medidas, TalkBack (una frase por cambio), teclado, 200 %, reducir movimiento, web en Chrome | Resultados en `dispositivo.md`: arranque en frío p50 430-444 ms con y sin bloqueo (una foto de 24 MP y grupo de 10), PSS sin diferencia (≤ 0,4 MB), todo gesto con el bloqueo **0,00 %** de cambio y con el bloqueo apagado sí cambia | Emulador API 37 (sin Xiaomi) |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [ ] **CI en verde:** todavía no se ha ejecutado; en Linux **4 pruebas fallan** hasta que se suban los PNG de `settings_lockzoom_{es,en}_x{1.0,2.0}` (hay que poner la etiqueta `actualizar-goldens` en la PR, revisarlos a ojo y subirlos)
- [x] `format` y `analyze` limpios en local
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens; sin tokens nuevos)
- [x] Accesibilidad: semántica, alternativas a gestos (sin excepción nueva a P6), contraste, texto grande, reducir movimiento. **Parcial:** el gesto real de TalkBack, Switch Access y control por voz quedan para la 022
- [x] Documentación actualizada (spec, plan, glosario, arquitectura, seguridad, DEV-54)
- [ ] **Rendimiento del arranque:** medido en el emulador (sin degradación); **el Xiaomi sin medir** (con permiso del propietario, en la 022)
- [x] Título de la PR en formato Conventional Commits

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] «Siempre»: sin secretos, sin registros de contenido, sin red ni permisos nuevos; ninguna entrada de usuario nueva
- [x] «Si toca el almacenamiento»: **N/A el esquema** (una clave más en `settings`, sin migración); el valor se valida con un decodificador que nunca lanza y falla cerrado a «apagado» (T-7); solo se guardan `locale`, `keepScreenOn` y `lockZoom` (más los dos indicadores internos de siempre), nada del contenido de las tareas (T-2)
- [x] «Si abre enlaces externos» (se toca `features/settings/`): sin cambios en `LinkOpener.kt`, `identity.yaml` ni la puerta de publicación; `external_page.dart` solo gana `clearLinkNotice`
- [x] «Recientes»: la fila nueva entra en la matriz y se comprobó con `check-recents.sh` en API 37
- [x] Sin secretos, permisos ni llamadas de red nuevas
- Observación del `security-reviewer`: los `grep` de CA-017-13 no están automatizados en `tools/` (no lo pide la spec)

## Pendiente antes o después de fusionar

- **[Pendiente, CI]** *Goldens* nuevos `settings_lockzoom_{es,en}_x{1.0,2.0}` (4 PNG): etiqueta `actualizar-goldens`, revisarlos a ojo frente al tablero 16 y subirlos. Los 4 PNG de Ajustes nivel 1 regenerados en T-017-05 siguen pasando.
- **[Decidido por el propietario, 2026-10-10]** La rama lleva el commit `81c15aa` (`chore`: hook `SessionStart` de `.claude/` que instala el Flutter fijado en sesiones en la nube; solo corre con `CLAUDE_CODE_REMOTE=true`, comprueba el SHA-256 contra el manifiesto oficial y no toca la app). **Se queda en esta PR.**
- **[Pendiente, 022]** Casillas de dispositivo (`docs/PLAN.md`, «Casillas de la 017»): lupa del sistema con el bloqueo (Android 8-11 y 12+, CA-017-13), gesto real de TalkBack para «desplazar adelante/atrás» y voz del idioma de la app, Switch Access y control por voz, lápiz, ratón, rueda y *trackpad* reales, giro con el bloqueo de rotación del sistema y en el móvil, gesto de volver en Android 10+, **arranque y memoria en el Xiaomi**, Android 8 y 12L con `check-recents.sh` (PD-10) y teclado físico en el móvil.
- **[Pendiente, 018/022]** Hallazgos bajos (mismo apartado de `PLAN.md`): la lupa con signo menos puede leerse como «alejar» (DEV-54, revisar con los iconos de la 018); las pruebas de dispositivo usan fotos 1:2,5 porque una 1:2 cabe en 1080 × 2400.
- **[Aceptado por el propietario, sin código]** Tras girar, las acciones de lector «desplazar arriba/abajo» no se recalculan hasta que algo desplaza (igual con y sin el bloqueo; Av Pág / Re Pág sí funcionan); un trazo horizontal sobre un grupo puede cambiar de foto; los controles no se ocultan (CL-017-10); girar y volver puede mover la foto.

## Nueva dependencia

Ninguna.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
