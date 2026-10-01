# Plan técnico — Spec 013: Deuda de accesibilidad del código

- **Spec:** `specs/013-deuda-accesibilidad/spec.md` (estado: Aprobada)
- **ADR aplicables:** ADR-0020 (voz del sistema en anuncios: no se toca); sin ADR nuevo (no se elige entre alternativas de arquitectura)
- **Estado del plan:** **Aprobado** por el propietario (2026-10-01). `a11y-reviewer` ya lo revisó (§9, aplicado). P-013-7 sigue abierta y solo bloquea T-013-06

## 1. Resumen del enfoque

Cuatro correcciones pequeñas, sin dependencias, permisos, esquema ni textos más que uno:

- **Nombre traducido (CA-013-01, 02):** la entrada de las bibliotecas de Android se registra con una **clave interna** y se muestra con el texto de la app. La lista se ordena con el nombre que se ve y sus filas se identifican por clave, no por posición; el foco y el nodo de cada fila los guarda la **lista**, no la fila, para que el cambio de idioma los conserve aunque la fila se mueva lejos.
- **"Reducir movimiento" (CA-013-03):** una función única decide la duración del hundido (`0` o `UnaMotion.press`) y los **cuatro** controles que se hunden la usan.
- **Paradas sin nombre (CA-013-04):** se quitan dos nodos enfocables sin etiqueta (uno de ellos no estaba en el hallazgo) y un test recorre el árbol entero.
- **Orden del lector (CA-013-05):** el aviso pasa después de las opciones, cambiando una constante.

### Hechos comprobados al preparar el plan (2026-10-01, `main` + rama de la 013)

Con una prueba de widgets desechable que volcaba el árbol de accesibilidad (no se conserva), y con `grep`:

- **[Hecho] Paradas sin nombre hoy:**
  - **Nivel 3:** el `Focus` que envuelve el texto (`license_detail_screen.dart`) crea un nodo **enfocable, sin etiqueta**, con la acción `focus`. Es el B3 del hallazgo.
  - **Nivel 2, error:** el `FocusableActionDetector` de `BrutalButton` crea otro nodo enfocable **sin etiqueta** encima de "Reintentar", porque el nodo del botón es `container: true` y no se funde con él. **No estaba en el hallazgo.** Pasa en **todos** los `BrutalButton` de la app; `SquareIconButton` ("Cerrar", "Volver") no lo tiene.
  - **Contenedores de desplazamiento:** el nivel 2 (lista) y el nivel 3 (texto largo) tienen un nodo sin etiqueta con las acciones `scrollUp` y `scrollToOffset` y **sin** indicador de enfocable. Es lo que CA-013-04 quiere conservar.
  - Nivel 1 y los demás estados: sin paradas sin nombre.
- **[Hecho]** Quitar `container: true` del nodo de `BrutalButton` funde los dos nodos en uno ("Reintentar", con `tap` y `focus`) y **toda la suite sigue en verde** (probado y revertido; el cambio real va en T-013-06).
- **[Hecho]** `UnaMotion.press` solo lo usan los cuatro controles de la spec (`brutal_button.dart`, `square_icon_button.dart`, `hold_to_complete_button.dart`, `placement_sheet.dart`); `grep` de `buttonPressed`, `UnaShadows.button`, `iconButton` y `translationValues` no encuentra ningún otro control que se hunda (`celebration_overlay.dart` mueve confeti, no un control). Ninguno mira `MediaQuery.disableAnimationsOf`.
- **[Hecho]** `SettingsOrder` hoy es título 0, aviso 1, contenido 2, botón 3 (`settings_page.dart`). El aviso es el único uso de `status` (`settings_screen.dart:179`).
- **[Hecho]** Hoy `CL-013-6` y el ejemplo de "Guardar" deshabilitado no se dan en la app: ningún `BrutalButton` de `lib` se construye con `onPressed: null` (`task_editor_screen.dart:729` lo pasa siempre). El paso deshabilitado↔habilitado solo se prueba con un widget suelto (`brutal_button_test.dart`); se cubre igual, porque el componente lo admite.
- **[Hecho]** `_LicenseList` usa `ValueKey(i)` (por posición) y el orden alfabético se hace en `FlutterLicenseSource.load()`, con el nombre bruto.
- **[Hecho]** Los *goldens* de Configuración (`settings_golden_test.dart:56`) escriben el nombre en español a mano: con la clave interna seguirán pintando el mismo texto, así que **no se regeneran**.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `domain/entities/license_package.dart` | `androidLibrariesLicenseKey = 'una:android-libraries'` (los nombres de paquete de pub no llevan `:`, así que no choca) y `compareLicenseNames(a, b)` (sin distinguir mayúsculas y, si empatan, sensible a ellas: la regla de hoy). Dart puro |
| Datos | `data/licenses/flutter_license_source.dart`; `app/bundled_licenses.dart` | La fuente usa `compareLicenseNames` (salida determinista, como hoy). `registerBundledLicenses` registra la entrada con `androidLibrariesLicenseKey` en lugar de `androidLibrariesLicenseName` (se borra) |
| Estado | — | Sin cambios. `licensesProvider` no depende del idioma: el nombre se traduce al pintar |
| Presentación | `features/settings/license_names.dart` (nuevo): `licenseDisplayName(l10n, package)` y `sortedForDisplay(l10n, packages)`; `licenses_screen.dart`; `license_detail_screen.dart`; `settings_page.dart`; `settings_screen.dart` | Lista y título del nivel 3 con el nombre que se ve, y orden calculado solo cuando cambian la lista o el idioma; `_LicenseList` pasa a *stateful*: guarda el `FocusNode` y la `GlobalKey` de cada fila **por nombre**, abre el nivel 3 (`_open` sale de la fila) y recoloca el foco; filas con `ValueKey(package.name)` y `findChildIndexCallback` (mapa nombre→índice); `Focus` del nivel 3 con `includeSemantics: false`; `SettingsOrder` renumerado (§3) y sus comentarios al día |
| Presentación (compartida) | `ui/press_motion.dart` (nuevo): `pressDuration(context)`; `ui/brutal_button.dart`; `ui/square_icon_button.dart`; `features/complete/hold_to_complete_button.dart`; `features/editor/placement_sheet.dart` | `pressDuration` da `Duration.zero` con `MediaQuery.disableAnimationsOf` y `UnaMotion.press` si no; los cuatro `AnimatedContainer` la usan. `BrutalButton` pierde `container: true` en su `Semantics` (plan B en P-013-4) |
| Nativo | — | Sin cambios |
| l10n | `app_es.arb`, `app_en.arb` | Clave `licensesAndroidLibraries` de la spec §7 (con `/strings-add`) |
| Tokens | — | Sin cambios: `UnaMotion.press` sigue en 80 ms; la excepción es de comportamiento, no de valor (DEV-50) |

## 3. Decisiones de diseño

- **P-013-1 Clave interna, sin campo nuevo.** `LicensePackage` no gana ningún campo: su `name` ya es único (la fuente agrupa por nombre) y hace de clave; solo la entrada de Android lleva una clave que nunca se muestra tal cual. Alternativa descartada: un `id` aparte, que obligaría a tocar todos los constructores de los tests.
- **P-013-2 El orden se hace dos veces, con la misma regla.** La fuente ordena por clave (resultado estable) y la lista **vuelve a ordenar** con el nombre que se ve, con `compareLicenseNames`. Un solo comparador, en el dominio. Con ~100 elementos no hace falta memorizar el resultado más allá de lo que ya haga `build`.
- **P-013-3 El nodo y el foco sobreviven al cambio de idioma (CA-013-02).**
  - Filas con `ValueKey(package.name)` y `findChildIndexCallback`: mientras la fila siga dentro de la ventana de la lista, Flutter reutiliza su elemento y su nodo accesible (mismo `SemanticsNode.id`).
  - La lista es **perezosa** y, con el nivel 3 abierto, el nivel 2 está *offstage* (sin *layout*): una fila que se mueve lejos se destruye y no tiene nodo accesible hasta que se vuelve a construir. Por eso **el `FocusNode` y la `GlobalKey` de cada fila viven en el estado de la lista, por nombre**, no en la fila: la fila los recibe y, al reconstruirse, los vuelve a adoptar. (Alternativa descartada tras la revisión: `AutomaticKeepAliveClientMixin`, que no ayuda con la ruta *offstage* y deja un foco fuera de la vista.)
  - El disparador es un cambio real del **idioma** (`Localizations.localeOf`) detectado en `didChangeDependencies` de la lista, no cualquier cambio de `MediaQuery` (un giro de pantalla no mueve el desplazamiento).
  - Con el nivel 2 **visible**: si el cambio de idioma deja la fila con el foco (o la abierta) fuera de la ventana, la lista salta al desplazamiento estimado de su posición nueva y, ya construida, `Scrollable.ensureVisible` sin animación; después se vuelve a pedir el foco y se envía el evento de foco accesible.
  - Con el nivel 3 **abierto**: no se hace nada hasta volver. La continuación de `_open` (que pasa a la lista) coloca la fila a la vista y entonces llama a `requestFocusAfter`, como hoy.
  - **Qué se comprueba:** si la fila sigue dentro de la ventana, el **mismo `SemanticsNode.id`** y el foco de teclado en ella; si se mueve más de una ventana (lista de 60 elementos), el nodo se vuelve a crear y el test afirma **foco de teclado en esa fila, fila a la vista y evento de foco accesible enviado a su nodo** (como en los tests de foco que ya hay), no el mismo `id`. El foco real de TalkBack, en la 016.
  - **Riesgo:** si no sale con poco código, T-013-03 **se para y se pregunta** (salida acordable: conservar el foco de teclado y registrar que la fila puede quedar fuera de la vista).
- **P-013-4 `BrutalButton` se arregla en el componente compartido, con verificación propia.** La parada sin nombre es de todos los `BrutalButton`, no solo del de "Reintentar". Se prueba quitar `container: true`: el nodo del botón se funde con el del `FocusableActionDetector`, igual que ya hace `SquareIconButton` ("Cerrar", "Volver"). Es un cambio de semántica en toda la app y "la suite pasa" **no basta**:
  - **Sitios sensibles** (foco inicial con `autofocus` y `FocusSemanticEvent`, y `Semantics(container, sortKey)` alrededor del botón): las confirmaciones de borrar (`delete_confirm_sheet.dart`, CA-004-10) y de enlace (`link_confirm_sheet.dart`), "+" del editor, "Reintentar" y "Volver a la tarea" / "Nueva tarea" del listado (`task_list_screen.dart`).
  - **Test por cada uso:** un solo nodo con etiqueta, `tap` y `focus`, y el nodo al que llega el `FocusSemanticEvent` es ese.
  - **Emulador con TalkBack en T-013-08** (no en la 016, que va después de cerrar la 013): foco inicial en "Cancelar" al borrar, confirmación del enlace, "+", "Reintentar" y "Nueva tarea".
  - **Plan B**, si algún sitio falla: dejar `container: true` y poner `includeFocusSemantics: false` al `FocusableActionDetector`, con `focusable` y `focused` en el `Semantics` interior.
  - Alternativa descartada: arreglarlo solo en el nivel 2 (deja la misma parada en el resto de la app).
- **P-013-5 Una sola función para el hundido.** `pressDuration(context)` en `ui/press_motion.dart`. Con duración cero, `AnimatedContainer` aplica el cambio de posición **y de sombra** en el mismo fotograma, también al pasar de deshabilitado a habilitado (CL-013-6). Los controles leen `MediaQuery` en `build`, así que un cambio del ajuste con la app abierta vale desde la siguiente pulsación (CL-013-4).
- **P-013-6 Orden del lector.** `SettingsOrder`: título 0, contenido 1, aviso 2, botón 3. El aviso y las dos opciones son hermanos dentro de la misma columna (`SingleChildScrollView` del nivel 1), y `sortKey` solo compara hermanos: el aviso queda tras las opciones, y el envoltorio de `SettingsPage` (clave 1) sigue antes de Cerrar o Volver (3). El `sortKey` del aviso se mantiene explícito. Se corrigen los comentarios que dejan de ser ciertos (`settings_page.dart:13-15`, `settings_screen.dart:175`). El **orden del teclado** no se toca (CA-012-12).
- **P-013-7 Qué cuenta como "parada sin nombre" (pregunta al propietario, §8).** El texto de CA-013-04 pide que ningún nodo con acciones tenga etiqueta y exceptúa **el contenedor de desplazamiento del nivel 3**. Pero la lista del **nivel 2** tiene el mismo tipo de nodo (acciones de desplazar, sin etiqueta, sin indicador de enfocable) y no está en la excepción. También los tienen el `SingleChildScrollView` del nivel 1 y el de "Reintentar" con texto grande. Se propone leer la excepción como "cualquier contenedor de desplazamiento: un nodo cuyas **únicas** acciones son `scrollUp`, `scrollDown`, `scrollLeft`, `scrollRight` o `scrollToOffset`, sin indicador de enfocable ni de botón" (el espíritu de la spec: el lector no se para ahí; limitarlo así evita esconder fallos reales), y ajustar el texto de CA-013-04 en consecuencia **solo con el sí del propietario**. **T-013-06 no empieza hasta ese sí.**

## 4. Modelo de datos y migraciones

Sin cambios: `schemaVersion` sigue en 2, nada se guarda.

## 5. Dependencias nuevas

Ninguna.

## 6. Estrategia de tests

Todos citan su CA; los que miden (200 %, desbordamientos, posiciones) empiezan con `setUpAll(loadAppFonts)`. Sin red.

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-013-01 (nombre en ES y EN en fila y título del nivel 3, "nombre, N licencias", texto de la licencia intacto, el nodo lleva el idioma de la app y **no** la marca `en`), CL-013-1 (orden con el nombre que se ve), CL-013-2 (`ca`→ES, `gl`/`eu`→EN) | Widget | `test/features/settings/licenses_screen_test.dart`, `test/app/locale_resolution_test.dart` |
| CA-013-01 (clave interna, completitud) | Unitario | `test/app/bundled_licenses_test.dart` (usa `androidLibrariesLicenseKey`), `test/data/flutter_license_source_test.dart` (orden con `compareLicenseNames`) |
| CA-013-02: lista pequeña (la entrada sigue en la ventana): mismo `SemanticsNode.id`, foco de teclado en ella, orden nuevo. Lista de 60 (se mueve más de una ventana): foco de teclado en la fila, fila a la vista y evento de foco accesible a su nodo. Nivel 3 abierto: título nuevo y desplazamiento conservado; al volver, foco en la fila en su sitio nuevo. Un giro de pantalla no mueve el desplazamiento | Widget con la app entera | `test/app/locale_change_test.dart` (junto al grupo CA-012-07) |
| CA-013-03 (instantáneo al pulsar, soltar, cancelar y al pasar de deshabilitado a habilitado; sombra incluida; con movimiento normal sigue tardando 80 ms; el relleno de completar no cambia), CL-013-4 a 7; también `BrutalButton.icon` y `ghost` (hundido de 1 px) | Widget. Se afirma **justo tras el único `pump()`** que construye el estado nuevo, **nunca tras `pumpAndSettle`**, y se mira la posición, la `boxShadow` del `DecoratedBox` y que `AnimatedContainer.duration` sea cero. Con `startGesture`, el `onTapDown` llega tras `kPressTimeout` (100 ms): se afirma tras ese `pump`, no tras otro. El control con movimiento normal sigue en el estado de origen tras ese `pump` y a medio camino tras `pump(40 ms)` | `test/ui/press_motion_test.dart` (nuevo; los cuatro controles); `test/ui/brutal_button_test.dart`; `test/features/complete/*`; `test/features/editor/*` |
| CA-013-04 (ningún nodo enfocable, con `tap` o con `focus` sin etiqueta ni valor; excepción de P-013-7) | Widget con auxiliar que **recorre el árbol entero** (no `_readingOrder`, que se salta los nodos sin etiqueta), ignora los nodos ocultos y los de rutas *offstage*, y se acompaña de `meetsGuideline(labeledTapTargetGuideline)` (no lo sustituye: esa guía no ve un nodo que solo tiene `focus`) | `test/support/semantics_stops.dart` (nuevo) y `test/features/settings/*_test.dart`: nivel 1 con y sin aviso; nivel 2 cargando, con error y con lista; nivel 3 corto, largo, con varias licencias y sin texto legible; ES y EN |
| CA-013-04 (el teclado sigue enfocando el área del nivel 3, con su anillo y sus teclas) | Widget | `licenses_screen_test.dart` (los tests de CA-012-12 siguen en verde) |
| CA-013-05 (título → opciones, filas o texto → aviso → Cerrar o Volver, en ES y EN), CL-013-8 (el aviso se anuncia una vez y no mueve el foco) | Widget | `licenses_screen_test.dart:391-429` y `settings_screen_test.dart:554-611` (se actualizan: el aviso va tras las opciones) |
| CA-013-05 (Switch Access, foco real de TalkBack) | **[Pendiente]** dispositivo | Spec 016 (casillas de `012/dispositivo.md` §8) |
| CA-013-06 | Scripts y diff, sobre el APK *release* | `check-android-permissions.sh release`, `check-licenses.sh`, test de migración, `git diff main` sin `pubspec.lock`, `validate-tokens`, *goldens* (en CI), `startup_licenses_test.dart` |

## 7. Seguridad, accesibilidad y rendimiento

- **Seguridad:** no toca ninguna de las superficies de `security-reviewer` (importación, URL/WebView, almacenamiento, permisos, nativo, dependencias, CI): no se le pasa el plan. Sí `/security-check` al cerrar, por la política.
- **Accesibilidad:** `a11y-reviewer` sobre este plan (hecho, §9) y sobre `git diff main...HEAD` al cerrar. En el emulador (T-013-08): TalkBack en los sitios de P-013-4, orden título → opciones → aviso → Volver, aviso anunciado una vez sin mover el foco, foco al volver tras cambiar el idioma, "Reintentar" con su pista, teclado (Tab, anillo y teclas del nivel 3, Escape) y "quitar animaciones". Lo que solo se ve en el dispositivo real va a la 016: foco real de TalkBack al volver, Switch Access y "reducir movimiento" a ojo.
- **Nota (B3 de la revisión):** con `includeSemantics: false`, el área de texto del nivel 3 deja de tener un nodo propio para quien use TalkBack con un teclado físico; sigue enfocable con el teclado, con su anillo y sus teclas. Es aceptable (sin texto nuevo, CA-013-06) y se anota en `dispositivo.md`.
- **Rendimiento (P2):** nada nuevo antes del primer fotograma. La lista sigue siendo perezosa; el reordenado es una ordenación de ~100 cadenas al pintar. Con "reducir movimiento" hay menos fotogramas, no más.
- **Tokens:** sin valores visuales nuevos; `validate-tokens` debe seguir igual.

## 8. Riesgos, preguntas y alternativas

| Riesgo o pregunta | Mitigación |
|---|---|
| **Pregunta al propietario (P-013-7):** ¿se amplía la excepción de CA-013-04 a cualquier contenedor de desplazamiento? | Recomendación: sí; es lo que la spec quiere decir y sin ello el criterio no se puede cumplir en el nivel 2. **T-013-06 espera ese sí** (las demás tareas no dependen de él) |
| Recolocar el foco tras el cambio de idioma con una lista perezosa y el nivel 2 *offstage* (P-013-3) | Test primero con 60 elementos; si no sale con poco código, se para y se pregunta (límite aceptable: el foco de teclado se conserva, la fila puede quedar fuera de la vista) |
| Quitar `container: true` de `BrutalButton` cambia el árbol de toda la app | Test por cada uso sensible, TalkBack en el emulador en T-013-08 y plan B (P-013-4) |
| Los *goldens* cambian sin querer | No debería: nada visual cambia con movimiento normal. Si cambian, se mira por qué antes de regenerarlos (`actualizar-goldens` en CI solo si el cambio es el esperado) |
| El test de "instantáneo" pasa también con 80 ms | Cada test lleva su control con movimiento normal, que **sí** debe estar a medio camino tras una `pump()` de 0 ms |

**Alternativas descartadas:** un `id` aparte en `LicensePackage` (P-013-1); arreglar solo el `BrutalButton` del nivel 2 (P-013-4); un `MediaQuery` por control en lugar de una función compartida (P-013-5); mover "Volver" y "Cerrar" al principio del orden (D-013-1); ordenar la lista una sola vez en la capa de datos (no puede conocer el idioma).

## 9. Revisión del plan (2026-10-01)

`a11y-reviewer`: 2 altos, 3 medios y 5 bajos. Todo aplicado:

- **A1** (fila viva con el nivel 2 *offstage*): P-013-3 reescrito: foco y clave en el estado de la lista, `_open` en la lista, disparador por idioma y test en dos casos.
- **A2** (`BrutalButton` sin `container: true`): P-013-4 con sitios sensibles, test por uso, TalkBack en el emulador en T-013-08 y plan B.
- **M1** (T-013-06 espera a P-013-7; helper acotado a los nodos de solo desplazar), **M2** (reglas de los tests de "instantáneo", `ghost` e icono), **M3** (comentarios de `SettingsOrder`).
- **B1** (CL-013-6 no se da hoy en la app, anotado en los hechos), **B2** (guías de tamaño y nodos ocultos), **B3** (nota del área de texto), **B4** (orden y mapa de índices calculados solo cuando cambian), **B5** (trampa de `getSemantics` en T-013-06).
