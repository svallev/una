# PR: spec 019, Notificaciones

**Título:** `feat(019): local notifications with the current task, 1 to 3 times a day`

## Qué y por qué

Un ajuste nuevo en Ajustes, **«Notificaciones»** (apagado por defecto, bajo «Idioma»; solo en Android): encendido, el sistema recibe una **notificación local con la tarea actual** a las 08:55, 13:55 y 18:55 (1, 2 o 3 al día; 1 por defecto). Sin tareas no se notifica. Con el móvil bloqueado se muestra una versión genérica salvo que el usuario permita el contenido sensible en el sistema (D25). Tocar la notificación abre siempre la tarea actual. Todo es local: sin servidor, sin push, sin red.

- **Spec:** `specs/019-notificaciones/spec.md` (estado: **Implementada parcialmente**; tabla CA → prueba en el §13)
- **Tareas:** T-019-01 a T-019-17
- **Criterios de aceptación cubiertos:** CA-019-01 a 30 (con 08b, 19a y 19b); los de dispositivo, en `dispositivo.md` y en «Casillas de la 019» de `docs/PLAN.md`
- **ADR nuevos o afectados:** **ADR-0025** (notificaciones locales con la tarea actual; enmienda el ADR-0005); constitución **1.10** (nota de P4). Sin excepción nueva a P6
- **Enmiendas a otras specs (en vigor):** 015, 017, 001 y 014; DEV-56 (nueva) y nota en DEV-52; `threat-model.md` v1.7 (T-17), `checklist.md`, política de privacidad (ES y EN)

## Qué cambia

- **Ajustes:** claves `notificationsOn` y `notificationsPerDay` (decodificadores exactos; **sin esquema nuevo**, `schemaVersion` sigue en 3). Fila con campana, línea de privacidad siempre visible, acordeón 1·2·3 (tres botones propios, marca no solo de color, sin animación con «reducir movimiento»), ayuda con las horas en 24 h y aviso «bloqueadas» con botón a los ajustes del sistema. Encender pide el permiso en ese momento (P5); todo o nada con el guardado y `configure`.
- **Nativo (Kotlin):** núcleo puro probado con JUnit en la JVM (horas, recuperación tras reinicio y cambios de hora, etiqueta por tipo de tarea, idioma); alarmas **inexactas** (`setAndAllowWhileIdle`, sin permiso de alarma exacta); un `WakeReceiver` **no exportado** y `directBootAware` con las seis difusiones protegidas; lectura de **solo lectura** de la BD al llegar la hora (versión genérica si no se puede leer); copia derivada de cinco claves en almacenamiento protegido del dispositivo y **fuera de la copia de seguridad**; `PendingIntent` explícitos e inmutables y orden de abrir con `nonce` de un solo uso.
- **Dart:** `NotificationGateway` (puerto, canal `una/notifications`), flujos del `SettingsController` dentro de la cola de la 017, ciclo de vida (a la vista, quitar la notificación, reconciliar una vez, todo después del primer fotograma, P2).
- **Permisos:** `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED` (`tools/check-android-permissions.sh` los vigila con lista blanca de componentes). **Dependencias:** solo `junit:junit:4.13.2` de pruebas, que no llega al APK (`tools/check-apk-no-test-classes.sh` en CI).
- **Indicador `notifications`** (P10): encendido por defecto desde T-019-17; el *harness* de Ajustes de la 015 y la 017 lo fija apagado para seguir describiendo Ajustes sin la fila.
- **Textos:** 17 claves en ES y EN y 7 en recursos nativos (`gen_android_strings.dart`, con `--check` en CI). **Iconos:** icono pequeño de la notificación (`gen_icons.dart notification`).
- **Documentación:** `architecture`, `testing`, `threat-model`, `checklist`, glosario, `screen-map`, ADR-0025, DEV-56, privacidad, `PLAN.md`, `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/019-notificaciones/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; todos los tests en verde (los *goldens* se omiten en el Mac) | Local (Mac) |
| JUnit (`./gradlew :app:testDebugUnitTest`) | En verde (224 pruebas) | Local |
| `node tools/validate-tokens.mjs` | Bien (35 combinaciones de texto y 25 no textuales) | Local |
| `/i18n-check` | ARB ES/EN con las mismas claves, descripciones presentes, sin literales incrustados; `gen_android_strings --check` al día | Local |
| `/security-check` | Sin secretos (las coincidencias son *fixtures* «texto-secreto»), sin archivos de firma, sin dependencias nuevas salvo JUnit de pruebas; manifiesto con solo los tres permisos | `git diff main...HEAD` |
| `security-reviewer` | 0 altos ni medios; 2 bajos corregidos (`onNewIntent` con extras ilegibles, `cancel()` sin crear el `PendingIntent`); 1 bajo a la 022 (script de permisos) | Rama |
| `a11y-reviewer` | 0 altos; 1 medio (anunciador bajo el pliegue con 200 %) y 4 bajos, a «Casillas de la 019» | Rama |
| `spec-reviewer` | 0 altos ni bloqueantes; test de voz de CA-019-27 añadido y notas menores corregidas | Rama |
| Entrega real, reinicio con PIN, pantalla de bloqueo, permiso, difusiones, `nonce`, estrés de BD, logcat, arranque | Resultados en `dispositivo.md` (arranque p50 ≈ 370 ms con y sin avisos, ≈ 406 ms desde la notificación) | Emulador API 37 |
| Entrega con el móvil bloqueado (+21 s), reprogramación tras reiniciar, arranque en frío | 378,8 ms frente a 371,3 ms (deriva) | Xiaomi 15T Pro, HyperOS 3 (app `.profile`) |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [ ] **CI en verde:** los PNG `settings_notifications_*` se generan en CI con la etiqueta `actualizar-goldens` y se revisan a ojo antes de subirlos
- [x] `format` y `analyze` limpios en local
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens)
- [x] Accesibilidad: semántica, alternativas a gestos, contraste, texto grande, reducir movimiento. **Parcial:** TalkBack real, teclado físico, Switch Access y Voice Access, para la 022
- [x] Documentación actualizada
- [x] **Rendimiento del arranque:** medido en el emulador y en el Xiaomi, sin diferencia fuera de la deriva (CA-019-24)
- [x] Título de la PR en formato Conventional Commits

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] «Siempre»: sin secretos, sin registros del contenido de las tareas (comprobado con logcat y `native_no_logging_test`), sin red
- [x] Permisos: solo `INTERNET`, `POST_NOTIFICATIONS` (al encender) y `RECEIVE_BOOT_COMPLETED`; ninguno de alarmas exactas
- [x] Componentes: `WakeReceiver` no exportado, acciones en lista blanca; `PendingIntent` explícitos e inmutables; `nonce` de 128 bits en memoria
- [x] Almacenamiento: sin esquema nuevo; copia derivada de cinco claves fuera de la copia de seguridad; valores leídos como no fiables
- [x] La notificación con el móvil bloqueado es genérica salvo permiso del usuario en el sistema; riesgos residuales aceptados en el ADR-0025 y T-17

## Pendiente antes o después de fusionar

- **[Pendiente, CI]** *Goldens* `settings_notifications_*`: etiqueta `actualizar-goldens`, revisarlos frente al tablero 16 y subirlos.
- **[Pendiente, 022]** Muestra de las 18:55 del 2026-10-13 en el Xiaomi y el resto de casillas de dispositivo (`docs/PLAN.md`, «Casillas de la 019»), incluidos los hallazgos de los revisores de cierre.
- **[Pendiente]** Revisión legal y política de privacidad antes de llegar a testers (020/023).
