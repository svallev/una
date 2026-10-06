# PR: spec 015, Ajustes

**Título:** `feat(015): Settings screen with language choice, keep-screen-on and links to the web`

> **No abrir la PR hasta que lo confirme el propietario.** Rama `feat/015-ajustes`.

## Qué y por qué

La pantalla temporal de «Configuración y perfil» (spec 012) se sustituye por **Ajustes**, la pantalla definitiva del tablero 16. Trae tres cosas: el **idioma se elige en la app** (Como el sistema, Español o English, en una página propia), la **pantalla siempre activa** pasa a ser un ajuste (apagado por defecto y sin límite de tiempo, en lugar del temporizador de 60 s de la 007) y, bajo «Información», **tres enlaces a una web** (política de privacidad, licencias de terceros y ayuda) que abren el navegador del sistema **directamente, sin confirmación** (enmienda del propietario, 2026-10-05). Las licencias dejan de mostrarse dentro de la app (ADR-0026): los textos siguen empaquetados y un archivo de avisos se emite y se verifica en CI.

- **Spec:** `specs/015-ajustes/spec.md` (estado: **Implementada parcialmente**; tabla CA → prueba en §11)
- **Tareas:** T-015-01 a T-015-16 (con T-015-07b)
- **Criterios de aceptación cubiertos:** CA-015-01 a CA-015-27 y CL-015-1 a 18
- **ADR nuevos o afectados:** **ADR-0023** (idioma elegido; amplía la excepción a P6 de ADR-0020) y **ADR-0026** (licencias de terceros solo en una web; sustituye a la parte de licencias de la 012); constitución 1.7
- **Enmiendas a otras specs:** 005, 007–011, 013; la **012 queda Sustituida**; DEV-52 (nueva, sustituye a DEV-49 y DEV-05)

## Qué cambia

- **Ajustes (nivel 1) y página de Idioma (nivel 2):** `SettingsScreen`, `LanguagePage` y `SettingsPage` sobre `settingsSheetRoute` (sube 200 ms, baja 160 ms, fundido de 160 ms entre niveles; 0 con reducir movimiento). Se abre desde el menú, que se cierra a la vez (P-015-1). Componentes nuevos con tokens: `UnaSwitchRow`, `UnaRadioRow`, `SettingsRow`, `LiveNotice` (región viva, una frase por intento).
- **Ajustes guardados:** `locale` (`system|es|en`) y `keepScreenOn` con un decodificador que nunca lanza (`settings_codec.dart`, tope de 16 caracteres; también `firstRunDone` y `hasEverHadTasks`). Mismo decodificador en Drift y en memoria; un valor ilegible da el defecto y no impide arrancar. **Sin esquema nuevo** (`schemaVersion` sigue en 2).
- **Idioma:** `MaterialApp.locale` desde `settingsProvider` (`null` con «Como el sistema», que sigue la regla de la 010, `ca-*` → español). Primer fotograma ya en el idioma elegido (`BootState.locale`). Al guardar, la página se congela en el idioma anterior y se aplica en el mismo fotograma.
- **Pantalla siempre activa:** `KeepScreenOnController` lee el ajuste; se borran el temporizador de 60 s, `touched()` y el `Listener` de toques.
- **Enlaces:** `openExternalPage` (`privacyLink` → `canOpen` → `open`); sin app o `open` falso, aviso «No hay ninguna app…» sin mover el foco. Tres direcciones constantes de compilación en `identity.yaml` (marcadores `https://example.com/…`), vigiladas por `tools/check-release-config.sh` (CA-015-13b: solo `https`, sin `?` ni `#`, sin IP ni dominios reservados, distintas entre sí).
- **Licencias:** fuera `licenses_screen`, `license_detail_screen`, `licensesProvider`, `data/licenses/` y 9 claves ARB. `tools/check-licenses.sh` emite `third-party-notices.txt` y lo verifica sobre el archivo emitido (con `--negative`: 14 mutaciones); paso nuevo en CI que lo sube como artefacto.
- **Retoques de accesibilidad hallados al cerrar:** la fila de radio y el enlace «Ajustes» del menú reflejan el foco de teclado en su nodo semántico; en la pasada del emulador, la hoja del menú y el aviso quedaban bajo la barra de tres botones (corregido).
- **Documentación:** `architecture`, `testing`, `glossary`, `checklist.md`, `threat-model` 1.5, `release-checklist`, ADR README, DEV-52, `screen-map`, `PLAN.md`, `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/015-ajustes/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **2001 tests en verde** (69 omitidos como antes); `gen-l10n`, `gen_tokens --check` y `gen_identity --check` al día | Local (Mac) |
| `node tools/validate-tokens.mjs` | 29 combinaciones de texto y 19 no textuales (interruptor y radios) | Local |
| `flutter build apk --release --split-per-abi` + `check-android-permissions.sh release` | Compila; solo `INTERNET`; manifiesto, `res/xml`, `pubspec.*` y Kotlin sin cambios | Local |
| `tools/check-licenses.sh` y `--negative` | 84 paquetes de Dart, 46 artefactos de Android, 3 ABI; archivo de avisos verificado; 14 mutaciones detectadas | Local (JDK de Android Studio) |
| `tools/check-release-config.sh` | **Falla a propósito** con los marcadores (PD-2); es la puerta de publicación, no un fallo de la PR | Local |
| `security-reviewer` | 0 altos, 1 medio (M-1: la puerta no corre en CI, **va a la 020**), 6 bajos; B-1 corregido en `ef0ab0d`, el resto en `PLAN.md` | `git diff main...HEAD` |
| `a11y-reviewer` | 0 altos, 2 medios (M1 corregido en `ef0ab0d`, M2 en `PLAN.md`), 2 bajos | `git diff main...HEAD` |
| `spec-reviewer` | 0 bloqueantes; I2 a I5 corregidos o registrados; **I1 pendiente del propietario** (ver abajo) | `git diff main...HEAD` |
| TalkBack, teclado real, 200 % con tres botones, reducir movimiento, `check-recents.sh` (Ajustes, aviso, Idioma) | Resultados en `dispositivo.md`; dos fallos corregidos con test | Emulador API 37 |
| TalkBack a oído (voz de «Idioma, Español», orden, interruptor) | «Todo ok» | **Xiaomi** (propietario) |
| Arranque en frío | p50 418-421 ms en el emulador; 217 ms la base y 223 ms la nueva en el Xiaomi (CA-015-23) | `docs/perf/baseline.md` |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [ ] CI en verde: **primera ejecución en GitHub** (incluye los 12 *goldens* ya subidos y el paso nuevo de `check-licenses.sh`)
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens)
- [x] Accesibilidad: semántica, alternativas a gestos, contraste, texto grande, reducir movimiento
- [x] Documentación actualizada (spec, ADR, glosario, arquitectura)
- [x] Rendimiento del arranque medido, sin degradar

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados: ajustes leídos de SQLite como no confiables (T-7), enlaces (T-4, T-5), permisos (T-13), CI
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas (la app abre el navegador; no se conecta por sí misma)

## Pendiente antes o después de fusionar

- **[Pendiente, propietario] I1:** la nota de P3 de la constitución 1.7 dice «tras confirmarlo» y contradice CA-015-12a (sin confirmación). Propuesta: constitución 1.8 con la frase corregida.
- **[Pendiente, 022]** Switch Access, repetir a oído la voz de «Idioma, Español» y de «Como el sistema» y la de los avisos con la versión final, anillo con teclado real, Android 8 y 12L (PD-10), aviso con texto al 200 % (M2).
- **[Pendiente, 020]** Que la puerta `check-release-config.sh` corra en CI al publicar (M-1) y endurecerla (ruta, dominios reservados).
- **[Pendiente, antes de F6]** Revisión legal de ADR-0026 y el referente `android-app://<paquete>` en la política y en Data Safety.
- **[Aceptado, propietario 2026-10-05]** TalkBack, al volver del navegador, lleva su recuadro al título «Ajustes»; no hay código para ello.

## Nueva dependencia

Ninguna.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
