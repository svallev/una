# Spec 013: Deuda de accesibilidad del código (hallazgos de la 012)

- **Estado:** **Implementada parcialmente** (2026-10-01: T-013-01 a T-013-10 hechas, 1530 tests en verde y verificada en el emulador de API 37; faltan las casillas de dispositivo de `dispositivo.md` §6, que pasan a la auditoría de la spec 016; ver §10). Aprobada por el propietario el 2026-10-01 (con el ADR-0020 aceptado y las enmiendas de abajo ya aplicadas). Revisada por `spec-reviewer` el 2026-10-01, con los hallazgos aplicados (§11)
- **Fase:** F5 (endurecimiento). Es la primera spec del troceado acordado con el propietario el 2026-10-01 (`docs/PLAN.md`, "Troceado de F5"):
  - 013 deuda de accesibilidad del código;
  - 014 seguridad y puerta de publicación;
  - 015 modo oscuro y arranque;
  - 016 auditoría en dispositivo (cierra la 011 y la 012);
  - 017 privacidad y ficha de tienda.

  TD-1 va en una PR `chore` aparte, fuera de esta spec.
- **Reglas de producto:** R15 en CA-013-01 y CA-013-02 (idioma). Desarrolla P6 y P7.
- **Pantallas del prototipo:** ninguna nueva. Hay **dos cambios visuales**, y nada más:
  - el nombre traducido (CA-013-01);
  - con "reducir movimiento", el hundido instantáneo (CA-013-03, DEV-50).

  La pantalla temporal de la 012 sigue siendo DEV-49.
- **Decisiones y ADR relacionados:** decisiones del propietario del 2026-10-01 (§9); **ADR-0020** (Aceptado: voz del sistema en anuncios, acciones y títulos de hojas, excepción a P6); CA-010-10; DEV-49 y DEV-50 (nueva).
- **Dependencias:**
  - 012 (Implementada parcialmente; esta spec corrige parte de sus hallazgos) y 010;
  - por los botones que se hunden (CA-013-03): 001, 002 (hoja "¿Dónde la pones?"), 003 (botón de completar) y 005;
  - 006 (orden del lector del listado).
- **Origen:** hallazgos de `a11y-reviewer` en el cierre de la 012 (`docs/PLAN.md`, "Hallazgos de la 012 para la auditoría de F5"): 012-A-M3, B2, B3, B4, B5 y B6.
- **Enmiendas a otras specs y documentos (aplicadas al aprobarla, 2026-10-01):**
  - **012:**
    - CA-012-03: el nombre de "Bibliotecas de Android" ya no va "tal cual".
    - CA-012-11: el orden del lector queda explícito, con el aviso después de las opciones.
    - CA-012-12: el orden "Cerrar o Volver → título → opciones" es solo el del **teclado**; Switch Access sigue el orden del lector.
  - **010:** CA-010-10, CL-010-2, §8 y §9. La excepción de la voz deja de ser "de la beta, se revisa en F5" y pasa a ADR-0020.
  - **003:** CA-003-01. Con "reducir movimiento", el desplazamiento de 4 px del botón y el cambio de su sombra son instantáneos; el relleno no cambia (CL-003-5).
  - **Constitución:** una línea de ADR-0020 en las excepciones de P6, al aceptar el ADR.
  - **`docs/design/prototype-deviations.md`:** DEV-50.
  - **`docs/PLAN.md`:**
    - en la fila F5, los "anuncios con la voz del sistema" pasan a "aceptados, ADR-0020";
    - en los hallazgos de la 012: M3, B3 y B4 corregidos; B2, B5 y B6 aceptados.
  - **`specs/012-configuracion-temporal/dispositivo.md` §8:** las casillas "TalkBack con el foco real al volver" (orden de "Volver" y el `Focus` sin etiqueta), "Nivel 3 de Bibliotecas de Android", "Switch Access real" (con el orden "Volver al final") y "Reducir movimiento" se rehacen en la 016 con el comportamiento nuevo.

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`; las notas técnicas van solo en el anexo, que no es normativo.

## 1. Objetivo

Corregir, antes de la auditoría en dispositivo (016), la deuda de accesibilidad que se puede arreglar en el código sin el móvil del propietario. Son cuatro cosas:

- un nombre que no se traduce;
- una animación que ignora "reducir movimiento";
- una parada del lector sin nombre;
- un aviso que se lee en otro orden del que se ve.

El resto de lo que señaló la revisión de la 012 queda **aceptado** por decisión del propietario. Se registra aquí para que no vuelva a salir como pendiente.

## 2. Historias de usuario

- **HU-013-1** Como usuario con el móvil en inglés, quiero ver la lista de licencias entera en inglés (salvo los textos de las licencias, que son de terceros), para no encontrarme una entrada en otro idioma.
- **HU-013-2** Como usuario con "reducir movimiento" activado (en Android, "Quitar animaciones"), quiero que los botones no se deslicen al pulsarlos, para que la app respete lo que he pedido al sistema.
- **HU-013-3** Como usuario de TalkBack, quiero que en "Configuración y perfil" cada sitio donde se para el lector tenga un nombre, y que el orden de lectura siga al de la pantalla, para no oír elementos vacíos ni avisos fuera de sitio.

## 3. Criterios de aceptación

- **CA-013-01 Nombre de las bibliotecas de Android traducido (012-A-M3, propietario, 2026-10-01)** *(**Enmienda 2026-10-05 (spec 015, aprobada; se aplica al implementarla)**: **obsoleto** al retirarse las pantallas de licencias, ADR-0026)*
  - **Dado** la lista de licencias (nivel 2 de la 012)
  - **Cuando** la app está en español o en inglés
  - **Entonces** la entrada propia de las bibliotecas de Android se llama así, en la fila y como título de su nivel 3:
    - en español, "Bibliotecas de Android (AndroidX, Kotlin)";
    - en inglés, "Android libraries (AndroidX, Kotlin)".
  - El nombre es **texto de la app**, no de terceros:
    - su nodo lleva el idioma de la app (español o inglés), como el resto de la pantalla (CA-010-10), y no la marca fija de inglés de los párrafos de licencia (CA-012-07);
    - el texto de la licencia no cambia.
  - La fila sigue diciendo "nombre, N licencias" (CA-012-11). Ocupa en la lista el lugar que le toca por orden alfabético **del nombre que se ve** (CL-013-1).
  - La comprobación de completitud de CA-012-03 sigue encontrando esta entrada en los dos idiomas.
- **CA-013-02 Cambio de idioma con la entrada abierta** *(**Enmienda 2026-10-05 (spec 015, aprobada; se aplica al implementarla)**: **obsoleto** con las pantallas de licencias)*
  - **Dado** el nivel 2 o el nivel 3 de esta entrada, abiertos
  - **Cuando** el usuario cambia el idioma del sistema y vuelve antes de 10 minutos (CA-010-06, CA-012-07)
  - **Entonces**:
    - el nombre cambia al idioma nuevo sin cerrar la pantalla;
    - el nivel 2 se reordena con el nombre nuevo, y el foco (de teclado y del lector) sigue en la misma entrada aunque cambie de posición;
    - el nivel 3 sigue mostrando la misma entrada y conserva el desplazamiento;
    - al volver del nivel 3, el foco va a esa fila, en su posición nueva.
  - **Verificación:** un test comprueba que el nodo de la entrada es el mismo antes y después del cambio, y que el foco de teclado sigue en ella. El foco real de TalkBack se comprueba en la 016.
- **CA-013-03 Pulsación sin movimiento con "reducir movimiento" (012-A-B4, propietario, 2026-10-01)**
  - **Definición:** un control "se hunde" cuando, al pulsarlo, se desplaza y su sombra cambia. Son los botones principales, los botones cuadrados de icono, las opciones de "¿Dónde la pones?" y el botón de completar. El plan cierra la lista con este criterio: son **todos** los que se hunden, no solo los de la 012.
  - **Dado** "reducir movimiento" activo en el sistema
  - **Cuando** un control de esos se pulsa, se suelta, se cancela, o pasa de deshabilitado a habilitado o al revés (p. ej. "Guardar" en el editor; los deshabilitados se ven hundidos)
  - **Entonces** la posición **y la sombra** pasan al estado nuevo **al instante**, sin fotogramas intermedios. Se mantiene el hundido como señal de que se ha pulsado: es un cambio de estado, no movimiento.
  - Sin "reducir movimiento", todo es como hoy (`motion.duration.press`, 80 ms).
  - El **relleno** de "mantener pulsado" del botón de completar no cambia y sigue lo que dice la spec 003 (CL-003-5): indica el progreso, no es una animación decorativa.
- **CA-013-04 Ninguna parada del lector sin nombre (012-A-B3, parte de código)** *(**Enmienda 2026-10-05 (spec 015, aprobada; se aplica al implementarla)**: se aplica a **Ajustes** y a la página de Idioma, CA-015-20g)*
  - **Dado** el árbol de accesibilidad de los tres niveles de la pantalla temporal de la 012
  - **Cuando** se inspecciona cada nivel (con y sin el aviso, y con la lista cargada, cargando y con error)
  - **Entonces** ningún nodo enfocable o con acciones (tocar, desplazar…) se queda sin etiqueta ni valor. La única excepción son los contenedores de desplazamiento (el texto del nivel 3, la lista del nivel 2 y los desplazables de los niveles 1 y de "Reintentar"; ampliada por el propietario el 2026-10-01, P-013-7), es decir, los nodos cuyas **únicas** acciones son de desplazar (`scrollUp`, `scrollDown`, `scrollLeft`, `scrollRight`, `scrollToOffset`):
    - conservan sus acciones de desplazar, para TalkBack y Switch Access (CA-012-12);
    - no llevan el indicador de enfocable ni de botón, así que el lector no se para en ellos con un nombre vacío.
  - Con teclado, el área de texto del nivel 3 se sigue pudiendo enfocar, con su anillo y sus teclas de desplazamiento (CA-012-12).
- **CA-013-05 Orden del lector y de Switch Access (012-A-B3, propietario, 2026-10-01)** *(**Enmienda 2026-10-05 (spec 015, aprobada; se aplica al implementarla)**: se aplica a **Ajustes** y a la página de Idioma: título → filas, con cada aviso donde se ve → Cerrar o Volver, CA-015-20g)*
  - **Dado** TalkBack activo en cualquiera de los tres niveles
  - **Cuando** se recorre la pantalla de principio a fin
  - **Entonces** el orden es el que se ve, con el botón al final: título → opciones, filas o texto → aviso "No hay ninguna app…" (si lo hay; se ve **debajo** de las opciones, CA-012-04) → "Cerrar" (nivel 1) o "Volver" (niveles 2 y 3), **lo último**, como "Volver a la tarea" en el listado (spec 006).
    - El foco al llegar sigue en el título (tabla de la 012).
    - El aviso se sigue anunciando una vez al aparecer, sin mover el foco (CA-012-04).
    - El atrás del sistema sigue cerrando o subiendo un nivel desde cualquier punto (CA-012-02).
  - **Switch Access** recorre la pantalla en el mismo orden que el lector (con "Cerrar" o "Volver" al final). **[Suposición]** Se comprueba en la 016.
  - El orden del **teclado** no cambia: Cerrar o Volver → título → opciones o filas (CA-012-12).
- **CA-013-06 Nada más cambia**
  - **Dado** la compilación *release*
  - **Cuando** se compara con la anterior, con las mismas comprobaciones de la 012 §10:
    - `tools/check-android-permissions.sh` y `tools/check-licenses.sh` (pasos de CI);
    - el test de migración;
    - el diff de `pubspec.lock`;
    - `node tools/validate-tokens.mjs`;
    - los *goldens*;
    - el test de arranque sin licencias.
  - **Entonces**:
    - no hay permisos, dependencias, conexiones ni datos nuevos, y `schemaVersion` no cambia;
    - el único texto nuevo es el de CA-013-01, en español y en inglés;
    - los únicos cambios visuales son los dos de la cabecera; tokens y *goldens* son iguales en el resto;
    - no se hace nada nuevo antes del primer fotograma (P2: el arranque no cambia).

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-013-1 | Orden alfabético con el nombre traducido | En español va con la B ("Bibliotecas…"); en inglés, con la A ("Android libraries…"). La lista se ordena por el nombre que se ve, igual que el resto |
| CL-013-2 | Sistema en `ca` (app en español) o en `gl`, `eu`, `fr`… (app en inglés) | El nombre sale en el idioma de la app (spec 010), no en el del sistema |
| CL-013-3 | Texto al 200 % en un móvil de 360 dp | El nombre en inglés y el español caben o pasan a otra línea sin cortes, en la fila y en el título del nivel 3 (CA-012-13) |
| CL-013-4 | Se activa o desactiva "reducir movimiento" con la app abierta | La siguiente pulsación ya usa el ajuste nuevo; ningún control se queda hundido |
| CL-013-5 | Se suelta o se cancela la pulsación (el dedo sale del control) con "reducir movimiento" | El control vuelve a su sitio al instante, sin transición |
| CL-013-6 | Un botón pasa de deshabilitado a habilitado o al revés (p. ej. "Guardar" al escribir en el editor vacío) con "reducir movimiento" | Cambia de posición y de sombra al instante |
| CL-013-7 | Activación con teclado, Switch Access o la acción del lector | Igual que hoy: la acción se ejecuta y, si el control muestra el hundido, cumple CA-013-03 |
| CL-013-8 | El aviso "No hay ninguna app…" aparece con el foco del lector en una opción | Se anuncia una vez y el foco se queda donde estaba; al seguir recorriendo, el aviso se lee después de las opciones (CA-013-05) |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin estados nuevos | — | El error de lectura de una licencia (CL-012-10), el de la lista (CA-012-15) y el aviso "No hay ninguna app…" (CA-012-04) no cambian. Solo cambia el lugar del aviso en el orden del lector (CA-013-05) |

## 6. Accesibilidad

Los criterios de esta spec son de accesibilidad (CA-013-01 a 05). Además:

- **Gestos:** no cambia ninguno, ni sus alternativas.
- **Anuncios:** no hay anuncios nuevos; los que hay siguen con la voz del sistema (ADR-0020).
- **Texto grande:** CL-013-3.
- **Objetivos táctiles:** no cambian (D-013-3).
- **Contraste:** sin colores nuevos (`validate-tokens`).
- **Revisión:** se revisa con `a11y-reviewer` antes de aprobar el plan y al cerrar. La comprobación a oído y con TalkBack, teclado y Switch Access reales va en la auditoría en dispositivo (016), con las casillas de `specs/012-configuracion-temporal/dispositivo.md` §8 afectadas (ver la cabecera).

## 7. Textos (ES / EN)

Clave nueva (camelCase; se añade con `/strings-add`):

| Clave | ES | EN | Notas |
|---|---|---|---|
| `licensesAndroidLibraries` | Bibliotecas de Android (AndroidX, Kotlin) | Android libraries (AndroidX, Kotlin) | Nombre de la entrada propia de la lista de licencias (CA-013-01). "AndroidX" y "Kotlin" son nombres propios: no se traducen |

## 8. Fuera de alcance

- **Que los anuncios, los nombres de las acciones del lector y los títulos de las hojas se oigan con la voz del idioma de la app** (012-A-B2 y la excepción de CA-010-10): se **acepta** la voz del sistema (D-013-2, ADR-0020). No se toca.
- **Zona táctil de 48 dp (012-A-B5) y guías de Android en los tests (012-A-B6):** se **acepta** quedarse en 44 (D-013-3).
- **Poner "Volver" o "Cerrar" antes del título en el orden del lector:** descartado (D-013-1).
- **TD-1** (token de interlineado): PR `chore` aparte.
- **Comprobaciones en dispositivo** (TalkBack a oído, teclado y Switch Access reales, `ca`/`gl`/`eu`): spec 016.
- **Hallazgos de seguridad de la 012** (012-S1 a S6): spec 014.
- **iOS** (D17).

## 9. Decisiones y preguntas

**Decisiones del propietario (2026-10-01):**

- **D-013-1 (012-A-B3, botón):** "Volver" y "Cerrar" se quedan **los últimos** para el lector, como en el listado (spec 006), por coherencia en toda la app; además, el atrás del sistema llega siempre. Solo se corrige la parada sin nombre (CA-013-04).
- **D-013-2 (012-A-B2 y CA-010-10):** los anuncios, los nombres de las acciones del lector y los títulos de las hojas **se quedan con la voz del sistema** cuando el sistema está en un idioma que la app no tiene (`ca`, `gl`, `eu`, `fr`…).
  - Es una excepción a P6 (WCAG 3.1.2). Se formaliza en el **ADR-0020** (Aceptado, 2026-10-01), con su mitigación y su criterio de revisión; su línea está en las excepciones de P6 (constitución 1.5).
  - Con el **primer** idioma del sistema en español o en inglés no hay diferencia: la voz del sistema es la de la app. Con una lista como `fr-FR, es-ES`, la app sale en español y la voz es la francesa (CA-010-02): también entra en la excepción.
- **D-013-3 (012-A-B5 y B6):** el mínimo de P6 sigue siendo **44** (dp en Android, pt en iOS; WCAG 2.5.8 pide 24). Donde una spec pide 48, se mantiene: el listado, CL-006-10.
  - No se adopta la guía de 48 dp de Android en los tests. Los tests siguen comprobando ≥ 44, y el contraste lo sigue garantizando `validate-tokens`.
  - **[Suposición]** El informe previo al lanzamiento de Google Play puede dar avisos por los objetivos de menos de 48 dp; no bloquean la publicación. Queda anotado en el párrafo "Troceado de F5" de `docs/PLAN.md`, para la 017.
- **D-013-4 (012-A-B4):** con "reducir movimiento", el hundido es **instantáneo**: se conserva la señal de que se ha pulsado, sin transición. El prototipo mantiene la transición también con "reducir movimiento", así que se registra como **DEV-50**.
- **D-013-5 (orden del aviso, hallazgo de `spec-reviewer`):** el aviso "No hay ninguna app…" se lee **donde se ve**, después de las opciones (WCAG 1.3.2). Hoy se lee antes que ellas.

**Preguntas abiertas:** ninguna.

## 10. Verificación: CA → prueba

Cierre de T-013-10 (2026-10-01). Rutas relativas a `app/` salvo las de `tools/`. Entorno: `flutter test` en local, **1530 en verde**, `dart format` y `flutter analyze --fatal-infos` limpios. **Dispositivo** = `specs/013-deuda-accesibilidad/dispositivo.md` (emulador `Pixel_6a`, API 37, APK *release* de `1c4d3ae`; nunca el Xiaomi). Lo que no se puede ver en el emulador pasa a la 016 (`docs/PLAN.md`, "Troceado de F5").

| CA | Prueba automática | Dispositivo / otra | Estado |
|---|---|---|---|
| 01 Nombre traducido | `test/l10n/spec_013_strings_test.dart`; `test/domain/license_package_test.dart` (clave y comparador); `test/features/settings/license_names_test.dart`; `test/app/bundled_licenses_test.dart` (la entrada sigue registrada con sus dos textos); `test/data/flutter_license_source_test.dart`; `licenses_screen_test.dart` (fila, etiqueta "nombre, N licencias", título del nivel 3, orden alfabético, locale del nodo, `ca`→ES y `gl`/`eu`→EN, 200 % a 360 dp) | Dispositivo §3 (la entrada en su sitio alfabético en ES y EN); `tools/check-licenses.sh` sobre el APK *release* | Hecho |
| 02 Cambio de idioma | `test/app/locale_change_test.dart` (lista de 60, ES↔EN: mismo `SemanticsNode.id`, foco de teclado, fila a la vista —incluida la que **sube** por encima de la ventana—, nivel 3 abierto con el desplazamiento conservado, foco al volver, giro de pantalla); `licenses_screen_test.dart` | Dispositivo §3 (lista real de 196: la fila baja y sube, en el nivel 2 y al volver del 3) | Hecho; foco real de TalkBack **[Pendiente]** 016 |
| 03 Sin movimiento | `test/ui/press_motion_test.dart` (pulsar, soltar, cancelar, teclado, deshabilitado↔habilitado, cambio del ajuste en caliente, 80 ms normales, `BrutalButton.icon` y `ghost`, `_Option`, completar; relleno a 1,2 s con `accessibilityFeaturesTestValue`); `test/features/complete/completion_flow_test.dart` (enhorabuena a su duración) | Dispositivo §2 (fotograma a fotograma: 1 fotograma en los cuatro controles; relleno intacto con las tres escalas a 0) | Hecho; a ojo en el móvil **[Pendiente]** 016 |
| 04 Sin paradas sin nombre | `test/features/settings/semantics_stops_test.dart` y `test/support/semantics_stops.dart` (niveles 1-3, con y sin aviso, cargando, error y lista; ES y EN; guía de objetivos; teclado); `test/ui/brutal_button_sites_test.dart` (un solo nodo en borrar, enlace, "+", "Nueva tarea", "Reintentar") | Dispositivo §4 y §5 (`uiautomator dump` sin nodos enfocables sin etiqueta; foco inicial en "Cancelar") | Hecho; "Reintentar" y el área de texto del nivel 3 con teclado físico **[Pendiente]** 016 |
| 05 Orden | `settings_screen_test.dart` y `licenses_screen_test.dart` (título → contenido → aviso → Cerrar/Volver en ES y EN; aviso único y sin mover el foco; teclado igual, CA-012-12) | Dispositivo §5 (orden del árbol de los tres niveles) | Hecho; Switch Access y anuncio único a oído **[Pendiente]** 016 |
| 06 Nada más cambia | `test/drift/app/migration_test.dart`; `test/app/startup_licenses_test.dart`; *goldens* (`test/goldens/settings_golden_test.dart`, solo CI) | Dispositivo §1: `tools/check-android-permissions.sh release` (solo `INTERNET`), `tools/check-licenses.sh`, `node tools/validate-tokens.mjs` (28 combinaciones AA), `git diff main...HEAD` sin `pubspec.*`, `drift_schemas/`, manifiestos ni `build.gradle` | Hecho; *goldens* en CI **[Pendiente]** |

**Revisiones de cierre (2026-10-01):** `security-reviewer`: sin hallazgos. `a11y-reviewer`: ver §11. `/i18n-check`: las dos ARB con las mismas claves, `licensesAndroidLibraries` con descripción y sin literales nuevos en `lib/`. `/tokens-validate`: ✅ y ningún valor suelto en el diff (las duraciones literales de `celebration_overlay.dart` y `licenses_screen.dart` y la etiqueta de `placement_sheet.dart` ya existían antes de la 013).

## 11. Revisión

`spec-reviewer` (2026-10-01): **requiere cambios** (3 altos, 6 medios y 9 bajos). Todo aplicado:

- **Altos:**
  - A1: Switch Access frente a CA-012-12, en CA-013-05 y en la enmienda.
  - A2: CA-013-04 redactado sobre el árbol de accesibilidad, conservando el desplazamiento.
  - A3: ADR-0020 y la línea en P6.
- **Medios:**
  - M1 y M5: D-013-4 y DEV-50.
  - M2: definición de "se hunde"; sombra y paso entre habilitado y deshabilitado; CL-013-6.
  - M3: foco y posición en CA-013-02.
  - M4: lista de enmiendas completa.
  - M6: D-013-5 y CA-013-05.
- **Bajos:** B1 a B9. El glosario amplía la fila de "Licencias de código abierto".

Segunda pasada (2026-10-01): **lista para aprobar**, sin altos ni medios. Los 8 bajos están aplicados:
- en el ADR-0020: API obsoleta bien atribuida, número exacto de anuncios, "primer idioma del sistema", riesgo R-22 y la línea de P6 redactada;
- en la spec: la sombra en la enmienda de la 003, la casilla de foco de `dispositivo.md` y cómo se verifican CA-013-02 y CA-013-04.


Cierre (2026-10-01): `security-reviewer` sin hallazgos. `a11y-reviewer`: **0 altos**; el único alto de la rama, F-1 (el relleno de completar con "reducir movimiento"), ya estaba corregido (T-013-08b), igual que F-2 (T-013-08c). Quedan sin corregir, registrados en `docs/PLAN.md` ("Hallazgos de la 012 para la auditoría de F5", 013-A-M1, B1, B2 y B3): 1 medio previo a la 013 (las opciones de "¿Dónde la pones?" no se alcanzan con teclado físico) y 3 bajos (foco de TalkBack en la lista al cambiar el idioma, texto repetido en "Reintentar", área de texto del nivel 3 con TalkBack y teclado físico).

## Anexo: notas para `plan.md` (no normativas)

- **M3:**
  - El nombre está hoy en una constante de `lib/app/bundled_licenses.dart` (`androidLibrariesLicenseName`). Se registra junto a las demás licencias propias y se usa como clave en `test/app/bundled_licenses_test.dart` (l. 51, 71 y 102).
  - Al traducirlo, conviene separar la clave interna del nombre que se ve. La lista se ordena por nombre en `lib/data/licenses/flutter_license_source.dart` (l. 34-38), y ese orden tiene que hacerse con el nombre ya traducido.
  - **[Hecho]** `tools/check-licenses.sh` no depende del nombre en español: solo mira `assets/licenses/android.txt`.
- **B4:**
  - **[Hecho]** `UnaMotion.press` solo aparece en `lib/ui/brutal_button.dart`, `lib/ui/square_icon_button.dart`, `lib/features/complete/hold_to_complete_button.dart` (solo el desplazamiento, no el relleno) y `lib/features/editor/placement_sheet.dart`. Ninguno mira `MediaQuery.disableAnimationsOf`.
  - `boxed_icon_button.dart` y `sheet_row.dart` no se hunden.
  - `BrutalButton` pinta como hundido el estado deshabilitado (`pressed = _down || !enabled`).
  - Hay que cubrir también la interpolación de la sombra.
- **B3:**
  - El `Focus` que envuelve el texto del nivel 3 (`lib/features/settings/license_detail_screen.dart`, l. 148-152) incluye semántica por defecto. Hay que comprobar en el árbol si crea un nodo enfocable sin nombre y, si es así, quitarlo sin perder el foco de teclado ni las acciones de desplazar.
  - El test de CA-013-04 **no puede** usar `_readingOrder` (`licenses_screen_test.dart:77-92`, `settings_screen_test.dart:45`), que se salta los nodos sin etiqueta: tiene que recorrer el árbol completo.
- **Orden:**
  - Sale de `SettingsOrder` en `settings_page.dart` (título 0, aviso 1, contenido 2, botón 3). D-013-5 cambia el aviso para que vaya después del contenido.
  - **[Hecho]** Ya hay tests del orden con "Volver" al final (`licenses_screen_test.dart:391-429`, en ES y EN, y `settings_screen_test.dart:554-611`). Se citan también como CA-013-05 y se actualizan con el aviso en su sitio nuevo.
- **Tests:**
  - Cada test cita su CA (`'CA-013-0X: …'`).
  - Los que miden (200 %, desbordamientos) empiezan con `setUpAll(loadAppFonts)`.
  - Si los *goldens* del nivel 2 muestran la entrada de Android, cambian solo en ese nombre; se regeneran en CI con la etiqueta `actualizar-goldens`.
- **Documentos que se actualizan al implementar:** los de la lista de enmiendas de la cabecera y `CLAUDE.md`.
