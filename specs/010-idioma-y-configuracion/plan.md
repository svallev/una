# Plan técnico — Spec 010: Idioma automático

- **Spec:** `specs/010-idioma-y-configuracion/spec.md` (estado: Aprobada, 2026-09-29)
- **ADR aplicables:** ninguno nuevo. Se respetan D10, D13 (aplazada), D17; ADR-0010 (web de pruebas: sin cambios)
- **Estado del plan:** Aprobado (propietario, 2026-09-29)

## 1. Resumen del enfoque

La detección de idioma ya existe: `resolveAppLocale` (`app/lib/app/locale_resolution.dart`) está conectada con `localeListResolutionCallback` en los dos `MaterialApp` de `una_app.dart` (la app y la pantalla de error de almacenamiento). El manifiesto de Android declara `locale|layoutDirection` en `configChanges`, así que un cambio de idioma del sistema no recrea la actividad. **[Hecho]**

La spec es casi toda **verificación**. El plan tiene tres partes:

1. **Limpiar** los restos del ajuste manual (CA-010-03, retirado): el parámetro `setting`, la constante `supportedAppLocales` (no se usa) y el test `'CA-010-03: …'`.
2. **Tests que faltan**, por CA: formatos (04), nombre (05), cambio en caliente (06), fugas de idioma en la semántica (07), marca de idioma del contenido (10), orden de las acciones tras el cambio (11) y texto al 200 % en inglés (12).
3. **Verificación manual en el emulador** de lo que un test de widget no puede ver: la voz de TalkBack, su foco, Switch Access, el teclado y la lista real de idiomas de Android (la suposición de CA-010-02).

Si algún test destapa un fallo, se corrige en la misma tarea con el cambio mínimo. Si la corrección no es obvia o toca otra spec, **se para y se pregunta**.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Ninguno |
| Datos | — | Ninguno. La clave `keepScreenOn` se queda como está (la usa 007/009 y en la beta siempre vale `true`). No hay clave `locale` en la BD |
| Estado | — | Ninguno |
| Presentación | `lib/app/locale_resolution.dart` | Se quita `setting` y `supportedAppLocales`; el comentario pasa a citar CA-010-01/02 sin ajuste manual |
| Presentación | `lib/app/una_app.dart`, `lib/ui/semantics_action_order.dart`, `lib/features/attachments/task_pdf.dart` | Solo si fallan CA-010-06/11: cambio mínimo |
| Nativo | — | Ninguno. **No** se añade `localeConfig` (CL-010-6) |
| l10n | — | Sin claves nuevas |
| Tests | `test/app/locale_resolution_test.dart`, `test/support/l10n_leaks.dart` (nuevo), `test/l10n/`, `test/app/`, `test/features/**` | Ver §5 |

## 3. Modelo de datos y migraciones

No cambia el esquema.

## 4. Dependencias nuevas

Ninguna.

## 5. Estrategia de tests

Reglas de la casa: cada test cita su CA; sin red; relojes inyectables; los que miden empiezan con `setUpAll(loadAppFonts)`.

| CA | Tipo de test | Archivo | Cómo |
|---|---|---|---|
| CA-010-01 | Unitario | `test/app/locale_resolution_test.dart` | Ya existe. Se añaden `es-419` explícito y más casos de "resto". Enmienda 2026-09-30: `ca-*` → español (test `'CA-010-01: el catalán (ca-*) abre en español'`) |
| CA-010-02 | Unitario + manual | ídem + T-010-10 | Ya existe (`fr-FR, es-ES` → es; `de, en-GB, es` → en; `null` → en). Se añade una lista sin ningún admitido. La suposición (Android entrega la lista completa) se comprueba en el emulador |
| CA-010-03 | — | ídem | Se **borra** el test del ajuste manual |
| CA-010-04 | Widget | `test/l10n/formats_test.dart` (nuevo) | Por idioma: el tamaño de un PDF con la función de `pdf_labels.dart` ("2,4 MB" / "2.4 MB"; "3 KB"), `menuAllTasksCount` (1 y 3), `editorCharsLeft` (1 y 5) y `a11yDeletedFromList` (1 y 3) |
| CA-010-05 | Unitario (lee archivos) | `test/app/app_identity_test.dart` (nuevo) | (a) Ni `displayName` ni `wordmark` aparecen escritos tal cual en `lib/` (salvo `app_identity.g.dart`) ni en los ARB; (b) el título de `UnaApp` (`onGenerateTitle`) es `AppIdentity.displayName`; (c) `strings.xml` contiene `displayName`. El paso de CI `gen_identity --check` ya existe **[Hecho]** |
| CA-010-06 | Widget (app completa) | `test/app/locale_change_test.dart` (nuevo) | `pumpUnaApp` en `es`; se prepara el estado; se cambia `platformDispatcher.localesTestValue` a `[en]` (simula volver de Ajustes: `hidden` → `resumed` con reloj falso < 10 min) y se comprueba el idioma y que no se ha perdido nada: editor con su texto, menú abierto, hoja de eliminar abierta, listado, imagen, PDF con su página y su zoom (`FakePdfView`), web sin recargar (contador de cargas de `FakeWebPageDriver`). Caso ≥ 10 min: CA-001-12 en inglés. CL-010-4: `ar` → inglés y `TextDirection.ltr` |
| CA-010-07 | Widget + helper | `test/support/l10n_leaks.dart` (nuevo), `test/l10n/semantics_language_test.dart` (nuevo) | El helper lee los dos ARB y construye, para cada idioma, los **fragmentos literales del otro** (separados por placeholders y por la sintaxis ICU): ≥ 4 caracteres y que no aparezcan en ningún texto del idioma propio (así se descartan "PDF", "URL", "MB" y los textos iguales). Recorre el árbol semántico (`label`, `hint`, `value`, `increasedValue`, `decreasedValue`, `tooltip`, nombres de `customSemanticsActions`) y los anuncios (`tester.takeAnnouncements()`) y falla si alguno contiene un fragmento del otro idioma. Se ejecuta en ES y en EN sobre la lista de pantallas de la spec; cada pantalla usa textos de tarea neutros para no provocar falsos positivos |
| CA-010-10 | Widget | ídem | En ES y EN, con una tarea escrita en catalán: ningún `SemanticsData.locale` es distinto de null o del idioma de la app, y ningún `attributedLabel`/`attributedValue`/`attributedHint` lleva `LocaleStringAttribute`. La voz se comprueba a mano (T-010-10) |
| CA-010-11 | Widget (app completa) | `test/app/locale_change_test.dart` | Se leen los nombres de `customSemanticsActions` en ES; se cambia a EN; se comprueba que el orden es el mismo (traducido) en la tarea solo texto, con imagen, con PDF, con web y en una fila del listado. También arrancando en EN y cambiando a ES |
| CA-010-12 | Widget | `test/l10n/large_text_en_test.dart` (nuevo) | `setUpAll(loadAppFonts)`; `textScale: 2` en EN y 360 × 640; sin excepciones de desbordamiento en las pantallas y hojas de CA-010-07. Se reutilizan los *pumps* de los tests al 200 % que ya existen en ES |
| CL-010-5, CL-010-7 | Manual | T-010-10 | Arranque normal tras cierre; "Configuración y perfil" es solo texto: sin acción (test `menu_create_edit_test.dart`) |

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad:** sin superficie nueva: no hay permisos, red, almacenamiento ni dependencias. `/security-check` al cerrar.
- **Accesibilidad:** es el foco de la spec (CA-010-06, 07, 10, 11 y 12). Verificación en el emulador con TalkBack (fr-FR, ca-ES, es-MX, en-GB), Switch Access, teclado físico y texto al máximo en inglés. Se recuerda que TalkBack enfoca el primer nodo de una ruta, y que un test de eventos de foco no basta.
- **Rendimiento:** sin impacto en el arranque (se simplifica una función).

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| **Orden de las acciones tras el cambio (CA-010-11).** Flutter asigna el identificador de cada acción la primera vez que la ve, y las etiquetas en el idioma nuevo son nuevas | `appFrame` vuelve a llamar a `registerSemanticsActionOrder` con el `l10n` nuevo antes que las pantallas, y `task_pdf.dart` las registra en `didChangeDependencies`. **[Suposición]** Basta con eso; el test lo confirma. Si falla, se registran las etiquetas de los dos idiomas al arrancar (cambio pequeño en `semantics_action_order.dart`) |
| Falsos positivos del helper de fugas (CA-010-07) | Umbral de 4 caracteres, se excluyen los fragmentos presentes en el idioma propio y hay una lista blanca explícita y comentada para los casos que queden |
| El test no puede ver la voz ni el foco de TalkBack | Tarea manual en el emulador (T-010-10) con resultados anotados en `tasks.md`; el propietario la confirma |
| `takeAnnouncements` no captura algún anuncio (p. ej. desde un `Timer`) | Se avanza el reloj con `pump(duration)` antes de leer. Si aun así no aparece, se comprueba ese anuncio a mano |
| El emulador no tiene voz catalana ni variantes regionales | Se instalan las voces de Google TTS; si no hay, se anota como no verificado |
