# Revisores de la 028 (T-028-24, 2026-11-23)

Alcance: `git diff b04345f...HEAD` (toda la 028; I2–I7 ya en `main`). Estado de cada hallazgo: **[Abierto]** hasta que se arregle.

## Comprobaciones automáticas

- `/tokens-validate`: ✅ (35 + 25 contrastes; `gen_tokens --check` al día; sin colores sueltos nuevos; los `Colors.transparent` son anteriores; `defaultSettleDelay` 300 ms de `ios_notification_gateway.dart` es un *debounce* de datos, no animación).
- `/i18n-check`: ✅ (mismas claves ES/EN, sin vacíos, los 3 textos nuevos iguales a la tabla de §7, sin literales nuevos, `InfoPlist.strings` generados por `gen_identity`).
- `/security-check`: ✅ automáticas (sin secretos ni archivos de firma, sin `DEVELOPMENT_TEAM` ni entitlements, único permiso nuevo la cámara con texto ES/EN/CA, `webview_flutter_wkwebview` justificada en T-028-08, hooks solo de proyecto). **[Pendiente]** `threat-model.md` §5 (l. 85: «no se usa hasta F-iOS») y l. 62 (`UserDefaults CA92.1`/`C617.1` no están declarados en `PrivacyInfo.xcprivacy`).

## `security-reviewer` (0 altos, 2 medios, 2 bajos, 7 informativos)

- **S-M1 [Abierto]** La WebView usa `WKWebsiteDataStore.default()` (`WebViewHardening.swift:46`), no `nonPersistent()` como piden ADR-0007 y ADR-0016; sin desviación registrada. Cookies y almacenamiento web pueden quedar en `Library/WebKit`/`Library/Cookies` (dentro de la copia de iCloud) entre salir y el siguiente arranque. El paquete 3.26.1 tiene `setWebsiteDataStore` en su API interna (pigeon), no en la pública. Arreglo: (a) almacén no persistente, o (b) excluir esas carpetas de la copia.
- **S-M2 [Abierto]** El script que corta `<input type=file>` escucha `click` en `window`: un `input` creado por JS y no insertado (`i.click()`) o uno en un `iframe about:blank` podrían saltárselo [Suposición, sin IT]. Arreglo: en iOS 18.4+ `runOpenPanelWith` → `nil` (envolviendo el `WKUIDelegate`); antes, ampliar el script (`HTMLElement.prototype.click`) e IT con los dos casos.
- **S-B1 [Abierto]** La regla (a') depende de que WebKit cancele la provisional antes de decidir una navegación de la página; verificado solo en iOS 27.2 y mismo origen. Arreglo: vaciar la vista antes de una carga propia, cola en `OwnLoadGate`, IT en iOS 16/17; anotar como R-21.
- **S-B2 [Abierto]** Copias de PDF elegidos quedan en `tmp/*-Inbox` si no se usa el token (cerrar el editor, app muerta). Arreglo: borrar `*-Inbox` al arrancar y en `cancel`.
- Informativos: I-1 CI no comprueba que `debugCopyFile`/`debugKillContentProcess` no estén en *release* (sí lo están solo en Debug); I-2 `NavigationWatcher` no cubre la variante `decidePolicyFor:preferences:`; I-3 `destroy` no vacía la página (sin impacto; el contrato dice otra cosa); I-4 `regenerate` no acota `width`/`height` (BD manipulada → cierre); I-5 `Links.swift` residual 012-S1 igual que Kotlin; I-6 manifiesto de privacidad correcto, texto de `threat-model.md` l. 62 mal; I-7 CI correcta (`macos-latest` móvil).

## `a11y-reviewer` (1 alta, 4 medias, 4 bajas)

- **A-A1 [Abierto]** En iOS VoiceOver no dice cuál está elegida en los grupos de radio (1·2·3 de Notificaciones, Idioma): el motor de iOS no da valor a `inMutuallyExclusiveGroup` y solo `selected` da el rasgo. `RawRadio` de Flutter pone `selected` solo en iOS. Choca con CA-015-07 y `radio_row_test.dart:82-83` (`isSelected == none`, pensado para TalkBack). Arreglo: `selected` (+ pista «no seleccionado») solo en iOS; separar el test por plataforma; verificar en el iPad.
- **A-M1 [Abierto]** Con el aviso de la cámara fijo (lector/teclado), otro aviso queda en cola detrás y no se ve ni se anuncia (`task_editor_screen.dart:330-371`). Arreglo: quitar el aviso actual antes de mostrar otro; test con `screenReader: true`.
- **A-M2 [Abierto]** Con teclado no se puede cerrar el aviso fijo (Escape no hace nada) y puede tapar el campo al 200 %. Arreglo: Escape (`DismissIntent`) lo cierra.
- **A-M3 [Abierto]** Con reducir movimiento, el gesto atrás en Ajustes (nivel 1) mueve la pantalla en vertical (`settings_route.dart:35-52`). Arreglo: fundido con `disableAnimations`.
- **A-M4 [Abierto]** «Todo hecho.» → «Nueva tarea» (`una_app.dart:254-260`, `UnaMaterialPageRoute`) no respeta reducir movimiento (anterior a la 028; también Android). Arreglo: usar `TaskEditorScreen.route`.
- Bajas: B-1 Control por voz / Acceso total con teclado no alargan el aviso; B-2 «Abrir Ajustes» al final del nombre del nodo; B-3 sin prueba por encima de ×2 (AX1–AX5); B-4 los textos dicen «iPhone» y en el iPad se lee «iPhone» (coherente: app solo iPhone).

## Decisiones del propietario (2026-11-23: «sí a todo»)

Arreglos, un `spec-task` por grupo y en este orden:

1. **R1** A-A1: `selected` (+ pista «no seleccionado») **solo en iOS** en `UnaRadioRow` y `_Option`; CA-015-07 y su test separados por plataforma; nota en la matriz. **[Pendiente]** VoiceOver en el iPad.
2. **R2** S-M1: almacén **no persistente** en la WebView de iOS (API interna del paquete); si sale frágil, excluir `Library/WebKit` y `Library/Cookies` de la copia. Desviación y residual en el contrato §3 y `threat-model.md`.
3. **R3** S-M2: primero IT en el simulador con el `input` suelto y el `iframe about:blank`; si se salta, `runOpenPanelWith` → `nil` en iOS 18.4+ y script ampliado antes.
4. **R4** A-M1, A-M2, A-M3, A-M4: quitar el aviso anterior antes de mostrar otro; Escape cierra el aviso de la cámara; fundido con reducir movimiento en el gesto atrás de Ajustes y en «Todo hecho.» → «Nueva tarea».
5. **R5** S-B2 e I-4: borrar `tmp/*-Inbox` al arrancar y en `cancel`; acotar `width`/`height` en `regenerate`. S-B1 se anota como R-21 (sin código).

**Aceptados sin cambio:** A-B1 a B-4 (a probar a mano cuando toque), S-I1 a I-7 (I-6: se corrige el texto de `threat-model.md` en T-028-25 junto con §5 l. 85).
