# Spec 024: pruebas en el dispositivo

Verificación en el **emulador `Pixel_6a_api37_root` (API 37, arm64, `emulator-5554`)** con la compilación **release** (`flutter build apk --release --split-per-abi`, `app-arm64-v8a-release.apk`, app real `invalid.pending.app`) sobre la rama `feat/024-correcciones-de-la-auditoria`. **Sin tocar el Xiaomi.** Capturas en el directorio temporal de la sesión (no se suben). El idioma del sistema se cambió con `adb root` + `settings put system system_locales "<lista>"` + `stop; start` y se **restauró a `en-US`** al acabar; `pm clear` de la app de prueba.

## C-024-3: catalán con inglés detrás (T-024-03, 2026-10-21)

Los resultados dependen de la release: la APK de **debug** trae recursos `ca` de librerías y no reproduce el fallo (por eso se sustituyó la prueba de integración por `tools/check-apk-locales.sh`, plan §1.4).

| Paso | Resultado |
|---|---|
| `aapt2 dump configurations` de la release **antes** del arreglo | Solo `es` (más `v27`…`nodpi`): sin `ca`. `tools/check-apk-locales.sh` **falla** («no trae recursos en 'ca'») |
| Release **antes** del arreglo, sistema en `ca-ES, en-US` (medido por el coordinador en un intento anterior) | Bienvenida en **inglés** (H-022-10 reproducido) |
| Tras el arreglo: `aapt2 dump resources` | `string/notification_title`: `()` «Current task», `(ca)` «Tarea actual», `(es)` «Tarea actual»; `values-ca` **sobrevive** al recorte de la release. `check-apk-locales.sh` en verde sobre `app-release.apk` y los tres `app-<abi>-release.apk` |
| Sistema en **`ca-ES, en-US`**, app con datos borrados | Bienvenida **en español** («¿Qué es eso que tienes que hacer y no has hecho?», «Guardar»); teclado «EN • CA» (el cambio de idioma se aplicó) |
| Mismo idioma, con una tarea guardada: menú y Ajustes | «Esta tarea», «Editar», «Eliminar», «Todas mis tareas», «Nueva tarea», «Ajustes»; **Ajustes** en español y la fila **Idioma** con «**Como el sistema**» |
| Sistema en **`en-US, ca-ES`** (misma app y datos), Ajustes | **Inglés**: «Settings», «Language» con «**Same as system**» (la regla de la 010: gana el primero) |

- **[Hecho]** CA-024-04 cumplido en el emulador: con `ca` primero, español; con el inglés primero, inglés.
- **[Suposición] sin comprobar:** el nombre del canal de la notificación sigue en el idioma de la app (CL-024-13): no se activó el interruptor de Notificaciones en esta pasada; lo dicen los tests de la 019 (sin cambios) y la lectura de `AndroidAdapters.kt`.
- **[Suposición] sin comprobar:** `Accept-Language` de la WebView con `ca-ES, en-US` (plan §1.4, B-3).
