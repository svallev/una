# Plan técnico — Spec 024: Correcciones de la auditoría

- **Spec:** `specs/024-correcciones-de-la-auditoria/spec.md` (estado: **Aprobada**, 2026-10-21)
- **ADR aplicables:** ADR-0021 (deshacer: cuándo se va la card), ADR-0023 (idioma «Como el sistema»), ADR-0025 (criterio de revisión de la voz: solo una nota, CA-024-05). **Sin ADR nuevo**: no hay dependencia, ni excepción a un principio, ni alternativa técnica de peso (Q-024-1 cerrada sin ADR).
- **Estado del plan:** **Aprobado** por el propietario el 2026-10-21 («aprobado»), con R-2 aceptado. Antes Borrador (2026-10-21). Revisado por `security-reviewer` (sin altos; 1 medio y 2 bajos, aplicados: capturas del Xiaomi, efecto nativo de `values-ca`, prueba de integración solo en el emulador) y `a11y-reviewer` (1 alto, 2 medios y 4 bajos, aplicados salvo el opcional de M-2, descartado en R-2: hoja con velo más estrecho que la pantalla, la card al girar y más estrecha que la pantalla, tránsito, efecto en la WebView, `#ffffff` como suposición)

## 1. Resumen del enfoque

Tres arreglos pequeños de código (H-022-04, 05 y 10) y el resto, documentación (H-022-02, 03, 06 y 07).

### 1.1 Cómo decide Flutter el estilo de las barras ([Hecho], ya usado en la 021)

`RenderView` busca un `AnnotatedRegion<SystemUiOverlayStyle>` en **dos puntos**: arriba en el centro (de ahí salen los campos `statusBar…`) y, en Android, abajo en el centro (de ahí salen los `systemNavigationBar…`). Gana la región **más alta** en el árbol de capas que contenga el punto, y el estilo se vuelve a pedir en cada fotograma en que cambia. Hoy hay dos: `systemBarsStyle` en `appFrame` (toda la app) y `systemBarsOnDarkStyle` en la enhorabuena. La 024 añade dos regiones más, sin tocar las existentes:

### 1.2 Card de deshacer → iconos claros en la barra de navegación (CA-024-01, 03)

- `UndoCard` (`lib/features/delete/undo_card.dart`) envuelve lo que pinta en un `AnnotatedRegion` **con tamaño** (el de la card) cuyo estilo pide iconos claros **solo** en la barra de navegación. Como Flutter solo lee de la región de abajo los campos de la barra de navegación, la barra de estado sigue saliendo de `appFrame` (CA-021-09, sin cambio).
- Va en la card y no en `UndoCardHost` porque la card la montan dos sitios (el host de la tarea actual y «Todo hecho.», y el propio listado, `task_list_screen.dart:984`): un solo cambio cubre las tres pantallas.
- Como la búsqueda es **por posición**, el estilo solo cambia cuando la card ocupa de verdad el punto de abajo (lo que pide el CA: «mientras la card ocupa la franja»). Al irse la card de cualquier forma (tiempo, «Deshacer», salir, reordenar, segundo plano: ADR-0021, CL-024-3) sale del árbol y el siguiente fotograma ya pide el estilo de debajo (CA-024-03). Con una card que sustituye a otra (CL-024-2) la región no sale del árbol: sin parpadeo.
- **Barra de navegación a un lado** (tres botones en horizontal, CL-024-4): la card abajo no la cubre, pero el punto de abajo sí cae en ella. Para no pedir iconos claros sobre `paper`, la región solo se pone si la barra de navegación está abajo: `MediaQuery.viewPaddingOf(context).bottom > 0` (con la barra a un lado vale 0). Con `MediaQuery` y no `View.of`, para que la card se reconstruya al girar (`a11y-reviewer`, M-1); vale porque la card lleva su propio `SafeArea` (`undo_card.dart`) y nada por encima le quita el margen de abajo.
- **Card más estrecha que la pantalla** (tableta, plegable o horizontal: `appFrame` limita el contenido a `contentMaxWidth`, B-2): los botones de los lados quedarían sobre `paper` con iconos claros. La región exige además que la card ocupe **todo el ancho** de la pantalla (ancho de la card ≥ `MediaQuery.sizeOf(context).width`).
- La región envuelve el `Material` de la card (con el margen del sistema dentro), no solo su contenido (B-1).
- Estilo nuevo en `lib/app/system_bars.dart`: `systemBarsOnDarkNavStyle` (los cuatro campos de navegación como `systemBarsOnDarkStyle`; los de estado, como `systemBarsStyle`, aunque no se lean, para que el valor sea completo).
- Contraste (calculado; [Suposición] los iconos claros del sistema son `#ffffff`, lo miden C-024-1 y 2): iconos blancos sobre la card (`ink` `#111111`) ≈ 18,9:1; el Xiaomi pinta `#121212` (18,7:1). La píldora de gestos queda fuera del criterio; C-024-1 anota si HyperOS la aclara.

### 1.3 Hoja con velo → iconos claros en la barra de estado (CA-024-02, 03)

- `showUnaSheet` (`lib/ui/una_sheet.dart`) es la **única** forma de abrir una hoja con velo en la app ([Hecho]: ni `showDialog` ni otro `showModalBottomSheet` en `lib/`), así que el cambio va solo ahí: el `builder` envuelve la hoja en un `AnnotatedRegion` **sin tamaño** (`sized: false`), que vale en cualquier punto mientras la ruta de la hoja esté en el árbol. Como la ruta está por encima de la pantalla, gana en los dos puntos: arriba pide iconos **claros** (sobre el velo) y abajo **oscuros** (sobre la hoja `paper`, CA-024-02).
- Estilo nuevo: `systemBarsUnderScrimStyle` (estado claro con `statusBarBrightness: dark` para iOS; navegación como `systemBarsStyle`).
- **Solo si el velo llega a la barra de estado** (`a11y-reviewer`, A-1): `appFrame` limita el `Navigator` a `contentMaxWidth`, así que en horizontal o en una pantalla ancha el velo solo cubre el centro y la hora y la batería quedan sobre `paper`. La región pide `systemBarsUnderScrimStyle` solo si la ruta ocupa todo el ancho (`LayoutBuilder`: `maxWidth >= MediaQuery.sizeOf(context).width`); si no, `systemBarsStyle` (lo de hoy, que se lee).
- **Hoja que abre otra** (CL-024-6): la segunda se abre cuando la primera devuelve su resultado (al `pop`, no al acabar la animación), así que las dos rutas conviven unos milisegundos y no hay fotograma sin región. **Card y hoja a la vez:** la ruta de la hoja está encima y manda (iconos oscuros sobre la hoja abajo, correcto).
- **Cuándo vuelve el estilo** (CA-024-03): al quitarse la ruta, es decir, al **acabar** la animación de salida (`sheetOut`, o en el acto con reducir movimiento): es el fotograma en que la hoja deja de estar a la vista. Mientras baja, los iconos siguen **claros** sobre un velo que se aclara; al abrir, se aclaran en el primer fotograma con el velo aún entrando. El blanco baja de 3:1 con el velo por debajo de ≈ 0,43 de opacidad (primer y último 20–25 % de cada animación). Se acepta ese tránsito (§7, R-2).
- [Suposición, se comprueba en el primer test de T-024-02] ninguna capa de recorte del `BottomSheet` deja fuera el punto de arriba. Si lo dejara, la alternativa es un contador de hojas abiertas que lea `appFrame`, como ya hace con `fullWidthRequests`.
- **Contraste** (calculado, revisado por `a11y-reviewer`; [Suposición] iconos claros `#ffffff`, lo mide C-024-2; con el velo `scrim` = `ink` al 55 % sobre cada fondo; resuelve la [Suposición, plan] de CA-024-02): iconos blancos ≥ **4,48:1** en todos (peor caso, el amarillo neón `#F4FF3A` → `#777c23`; `paper` → 4,54:1; naranja clásico → 6,08:1, el del Xiaomi). Los iconos oscuros de hoy bajan de 3:1 en 6 de los 10 colores (p. ej. rosa neón 2,21:1). Ninguno falla con claros: no hay que parar ni preguntar. El test de T-024-02 lo recalcula desde los tokens (no con números fijados).

### 1.4 Catalán con inglés detrás (CA-024-04, H-022-10)

**Causa** ([Suposición fuerte, por el código de AOSP]; T-024-03 la confirma **antes** de corregir con `tools/check-apk-locales.sh` sobre la APK de **release**, que falla sin `values-ca`; el emulador la reproduce en C-024-3: con `ca-ES, en-US` la bienvenida sale en inglés): al crear los recursos de la actividad, `ResourcesImpl.updateConfiguration` busca en la lista del sistema el primer idioma que la app tiene como recurso (`getFirstMatchWithEnglishSupported`, que cuenta el inglés como admitido siempre) y, si no es el primero, lo **pone delante**. La app solo tiene `values/` (inglés) y `values-es/` (los textos de la notificación, 019), sin `values-ca/`: con `ca-ES, en-US` el sistema entrega a la configuración `en-US, ca-ES, …`, el motor de Flutter la pasa tal cual a `PlatformDispatcher.locales` y `resolveAppLocale` ve primero el inglés. Con `ca-ES` solo no hay nada que reordenar y sale español (K-022-056). La regla de Dart está bien (sus tests pasan).

**Arreglo:** que la app **tenga** recursos en catalán, con el texto en español (que es como la app trata el catalán, CA-010-01). `tool/gen_android_strings.dart` añade un destino `(lang: 'es', dir: 'values-ca')`: genera `values-ca/notification_strings.xml` idéntico al de `values-es` y el `--check` de la CI lo vigila. Con eso, en `ca-ES, en-US` el primer idioma con recurso es ya `ca-ES` y el sistema no reordena; `fr-FR, ca-ES, en-US` pasa a `ca-ES, fr-FR, …` (español, como pide la tabla); `gl-ES, en-US` y `fr-FR, de-DE` siguen en inglés; `ca-AD` y `ca-ES-valencia` casan con `values-ca` (CL-024-9).

- **Por qué no un `integration_test`** (cambio del plan en T-024-03, aprobado por el propietario): `flutter test integration_test` instala la APK de **debug**, que trae recursos `ca` de librerías, así que el test con `ca-ES, en-US` PASA sobre el código sin arreglar (R-4 se dio); la APK de **release** solo trae `es` y el inglés por defecto (el recorte quita los `ca` de terceros) y en ella H-022-10 sí se reproduce. Lo que sí es verificable sin dispositivo es que la release **traiga** recursos `ca`: `tools/check-apk-locales.sh` (`aapt2 dump configurations`; sin red), en la CI tras `check-apk-no-test-classes.sh`. `values-ca` sobrevive al recorte de R8 (los `notification_*` los usa Kotlin; comprobado en la release: `string/notification_title` con `()`, `(ca)` y `(es)`).
- **Efectos secundarios** ([Hecho], leído en `notifications/AndroidAdapters.kt`; `security-reviewer`): `ResourceStrings` fuerza el idioma de la app con `createConfigurationContext` en todos los textos nativos, también el nombre del canal, y `AndroidSystemLocale` lee `Resources.getSystem()`, que el sistema no reordena. `values-ca` **no cambia nada nativo**; la notificación sigue en el idioma de la app (CL-024-13). [Suposición] se comprueba de paso en C-024-3. Sí cambia el orden de idiomas de toda la actividad: con `ca-ES, en-US`, la WebView de la tarea web probablemente pedirá las páginas en catalán antes que en inglés (`Accept-Language`), que es lo que eligió la persona (coherente con WCAG 3.1.2; B-3).
- **«Idiomas de la app» (CL-024-12):** la app sigue fuera de esa lista porque no declara `localeConfig` ni activa `generateLocaleConfig` ([Hecho], ni en el manifiesto ni en Gradle). Un test lo fija.
- **Alternativa descartada:** pasar a Flutter desde `MainActivity` la lista sin reordenar (`Resources.getSystem().configuration.locales`) en `onCreate` y en cada `onConfigurationChanged`. Más código nativo y depende del orden en que el motor envía la suya; el recurso es una línea del generador.

### 1.5 Documentación (CA-024-05 a 08)

Sin código. Notas y enmiendas en: `specs/022-…/informe.md` §4 (estado de los siete hallazgos y la ficha de H-022-07), `specs/019-notificaciones/spec.md` (CA-019-11, 13, 21 y CL-019-4; estado **Implementada**), `specs/019-notificaciones/dispositivo.md` (N-1 a), `docs/adr/0025-*.md` (nota en el criterio de revisión), `specs/021-…/spec.md` (nota en CA-021-09 y estado), `specs/015-ajustes/spec.md` (estado), `specs/010-*/spec.md` (enmienda de la [Suposición] de CA-010-02), `docs/PLAN.md` y `CLAUDE.md`. Los resultados de C-024-1 a 3 van a `specs/024-…/dispositivo.md` (nuevo) y a «Casillas de la 024» en `docs/PLAN.md`.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Ninguno |
| Datos | — | Ninguno |
| Estado | — | Ninguno |
| Presentación | `lib/app/system_bars.dart`, `lib/features/delete/undo_card.dart`, `lib/ui/una_sheet.dart` | Dos estilos nuevos y dos `AnnotatedRegion` (§1.2, §1.3) |
| Nativo | `tool/gen_android_strings.dart`, `android/app/src/main/res/values-ca/notification_strings.xml` (nuevo, generado) | Recursos en catalán con el texto en español (§1.4) |
| l10n | — | Sin claves nuevas (spec §7) |
| Documentación | §1.5 | |

## 3. Modelo de datos y migraciones

No cambia el esquema (sigue el v3).

## 4. Dependencias nuevas

Ninguna.

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-024-01, CL-024-1, 2 | Widgets: con la card visible en la tarea actual, en «Todo hecho.» y en el listado, `SystemChrome.latestStyle` pide iconos **claros** en la navegación y **oscuros** en el estado; con una card que sustituye a otra (listado) no hay ningún fotograma con iconos oscuros; con `viewPadding.bottom = 0` (barra a un lado), al **girar** con la card visible y con la card más estrecha que la pantalla (800×400), la navegación sigue oscura | `test/app/system_bars_test.dart` (grupo nuevo «spec 024») |
| CA-024-02, CL-024-6 | Widgets: con cada hoja de la app abierta (al menos «Esta tarea», Añadir, Cargar URL, ¿Dónde la pones?, Eliminar) sobre una nota y sobre el listado, estado **claro** y navegación **oscura**; «Esta tarea» → Eliminar sin fotograma intermedio con estado oscuro; a 800×400 sin visor (velo más estrecho que la pantalla) el estado sigue oscuro. Unitario: contraste ≥ 3:1 de `#ffffff` contra `scrim` sobre `paper` y cada color de `UnaPalettes` (desde los tokens) y de los iconos oscuros contra `paper` | `test/app/system_bars_test.dart`, `test/ui/sheet_scrim_contrast_test.dart` |
| CA-024-03, CL-024-3, 11 | Widgets: la card se va por tiempo, «Deshacer», salir de la pantalla, reordenar y paso a segundo plano → el fotograma siguiente pide `systemBarsStyle` (o `systemBarsOnDarkStyle` si debajo queda la enhorabuena); la hoja se cierra tocando fuera, con «Atrás» y eligiendo una opción → vuelve al terminar `sheetOut` (y en el acto con reducir movimiento); la app vuelve de segundo plano con la hoja abierta → sigue en claro | `test/app/system_bars_test.dart` |
| CA-024-04, CL-024-9, 12 | Unitario: el generador escribe `values-ca/` igual que `values-es/` y `--check` falla si falta; el manifiesto no tiene `localeConfig` ni Gradle `generateLocaleConfig`/`resConfigs`. **Script sobre la APK de release** (sustituye a la prueba de integración, §1.4): `tools/check-apk-locales.sh` exige `ca` y `es` como idioma propio y el inglés por defecto; **falla antes del arreglo** (es la confirmación de la causa), verde después y en la CI; se prueba con un `aapt2` de mentira. Casilla C-024-3 con la **release** en el emulador | `test/tool/gen_android_strings_test.dart`, `test/app/locale_config_test.dart` (nuevo), `test/tool/check_apk_locales_test.dart` (nuevo), `tools/check-apk-locales.sh` (nuevo), `.github/workflows/ci.yml` |
| CA-024-01, 02, 03 (en dispositivo) | Casillas C-024-1 y 2: capturas en el emulador de API 37 y en el Xiaomi (tres botones y gestos), contraste medido en el Mac y capturas borradas en el acto. Además (`a11y-reviewer`): hoja abierta en horizontal sobre el listado y sobre una nota; girar con la card visible (tres botones a un lado y gestos); abrir y cerrar una hoja con `screenrecord` para ver el tránsito; una hoja que abre otra; TalkBack sin regresión en el foco de la card ni de la hoja | `specs/024-…/dispositivo.md` |
| CA-024-05 | Los tests de la notificación de la 019 siguen en verde **sin cambios** (`git diff` no toca `test/**/notification*`); revisión de documentos | — |
| CA-024-06, 07, 08 | Revisión de documentos; `rg 'H-022-0[2-7]\|H-022-10'` sin ninguno «Abierto»; `landing/src/help.{es,en}.md` sin cambios | — |

Todos los tests citan su CA (`'CA-024-01: …'`). Los de barras siguen con `setUpAll(loadAppFonts)` y el `forgetStyle` del archivo. Los existentes de CA-021-09 no cambian: sin card ni hoja la app pide lo mismo que hoy.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad:** sin red, permisos, datos ni dependencias. El único cambio nativo es un archivo de recursos generado con textos que ya están en la app. C-024-3 se hace solo en el **emulador** con la **release** (nunca en el Xiaomi: cambiaría su idioma), cambia los idiomas con `adb` y los **deja como estaban** (`en-US`) al acabar, con `pm clear` de la app de prueba. El script `check-apk-locales.sh` solo lee la APK (`aapt2`), sin red. `threat-model.md`: sin cambios.
- **Capturas del Xiaomi (T-024-05, privadas):** solo con tareas **ficticias** creadas para la prueba; notificaciones ocultas antes de capturar (modo demo de SystemUI si HyperOS lo admite; si no, «No molestar»); aviso al propietario antes de cada una; se guardan en el *scratchpad* (fuera del repo), se recortan en el acto a la franja de la barra, se mide el recorte y se borran del Mac y del móvil (`adb shell rm`). En `dispositivo.md`, solo números, sin imágenes.
- **Accesibilidad:** solo cambia lo que la app pide a las barras del sistema; ni la card ni las hojas cambian de semántica, foco, anuncios ni aspecto. Contraste: §1.2 y §1.3 (≥ 4,48:1 calculado; medido en C-024-1 y 2). WCAG 3.1.1: con el arreglo de §1.4, la voz de TalkBack y el idioma de la app vuelven a coincidir con la regla de la 010 también con `ca` primero.
- **Rendimiento:** dos nodos más en el árbol cuando hay card u hoja; nada en el arranque.

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| R-1 · HyperOS ignora el estilo pedido o lo aplica con retraso (ya pasó con la píldora en la 021) | C-024-1 y 2 en el Xiaomi; si la píldora no se aclara, límite del sistema sin bloquear (CA-024-01). Si los iconos no cambian, se para y se pregunta |
| R-2 · Tránsito con iconos claros sobre un velo a medias: al abrir y al cerrar la hoja (primer y último 20–25 % de `sheetIn` / `sheetOut`) y al entrar la card (fundido de `undoEnter`, 220 ms) | Se acepta: el CA habla de la hoja abierta y cerrada y de la card a la vista, y el tránsito dura una fracción de la animación (cero con reducir movimiento). **Descartado** elegir el estilo por el valor de la animación de la ruta (`a11y-reviewer`, M-2, opcional): con una hoja que abre otra, la segunda empieza en 0 y saldría un parpadeo a oscuros, contra CL-024-6 |
| R-3 · Una capa de recorte del `BottomSheet` deja fuera el punto de arriba | El primer test de T-024-02 lo detecta; alternativa del contador en `appFrame` (§1.3) |
| R-4 · La prueba no reproduce la reordenación (o la causa es otra) | **Se dio con el `integration_test`** (la APK de debug trae `ca`) y se cambió por `check-apk-locales.sh` sobre la release (§1.4); en la release y el emulador, H-022-10 se reproduce antes del arreglo (inglés con `ca-ES, en-US`) y desaparece después (C-024-3) |
| R-5 · Una dependencia futura trae `values-ca` propio o una regla de `resConfigs` lo quita | El test del generador y C-024-3; `resConfigs` no se usa hoy ([Hecho]) |

**Alternativas descartadas:** cambiar el velo o la card (fuera de alcance, spec §8); poner las regiones en cada pantalla en vez de en la card y en `showUnaSheet` (más sitios y fácil de olvidar en una hoja nueva); para §1.4, la de `MainActivity` (§1.4).

**Preguntas para el propietario:** ninguna. R-2 **aceptado** por el propietario (2026-10-21, al aprobar el plan).
