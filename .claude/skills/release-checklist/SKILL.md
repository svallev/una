---
name: release-checklist
description: Checklist para preparar una versión (beta o tiendas). Solo cuando el usuario lo pida explícitamente.
disable-model-invocation: true
argument-hint: "<versión X.Y.Z>"
---

# Checklist de release

Recorre cada punto y presenta el estado (✅ / ❌ / N/A con evidencia). **No subas nada a las tiendas, no crees ni borres etiquetas, no lances el trabajo de publicación ni hagas push sin la confirmación explícita del usuario.**

## El trabajo de publicación manda (spec 020)

Las comprobaciones automáticas (la puerta de la identidad y de la política, textos nativos, permisos y componentes, clases de pruebas, PDFium, licencias y archivo de avisos, tamaño, estática MASTG, *package name*, firma, etiqueta y la CI del commit) **no se pasan a mano**: las corre `.github/workflows/release.yml` sobre el commit que se entrega, y aquí solo se mira su resultado (el resumen del trabajo o su artefacto `release-summary`). Guía: `docs/security/checklist.md`, «Trabajo de publicación».

- **Entrega a testers:** lanzar el trabajo **a mano desde `main`** (modo testers, con confirmación). Tiene que terminar en verde (los avisos de identidad salen listados, con «Esta versión no se puede publicar.»; cualquier otro fallo es rojo). La entrega se compila **del mismo commit** que pasó el trabajo (no sube APK) y se anota en ella el enlace a la ejecución y la lista de avisos. **Ruta del Mac (spec 023, H-2, Q-023-3 a):** esa compilación se hace en el Mac del propietario y lleva **su ruta** (`/Users/<usuario>/…/.dart_tool/…`, una por APK en `libapp.so`), así que la regla `build-paths` falla en ese APK local; se **acepta para testers** (personas que conoce) y se dice en las notas de la beta. **Lo que se publica en Play no se compila nunca en el Mac**: sale del trabajo de publicación (`/home/runner/…` se admite como residual de Flutter, `threat-model.md` §5).
- **Publicar, en este orden:**
  1. La etiqueta `vX.Y.Z` (igual a `version:` de `pubspec.yaml`, sobre un commit de `main`, con el `+build` mayor que el de la etiqueta anterior), creada y subida **solo tras la confirmación del usuario**. Eso lanza el modo estricto.
  2. El trabajo en **modo estricto en verde** sobre ese commit. **Sin una ejecución en verde del trabajo sobre ese commit, la versión no es publicable**, también si la etiqueta es de un commit anterior a la spec 020 (no se lanza nada, CL-020-16). Si el trabajo falla, la etiqueta **se borra** (con permiso del usuario), se corrige y se crea otra.
  3. El **archivo de avisos** de esa ejecución (artefacto `third-party-notices`, caduca a los 90 días) adjunto a la versión, y la web de licencias con ese mismo archivo.
  4. Publicar el **AAB que compiló ese trabajo** (firmado, F6), nunca una compilación local.

## Código y calidad
- [ ] `main` en verde (CI y Security); sin alertas abiertas de secret scanning, CodeQL, Dependabot ni OSV de severidad ≥ media. Mirar también la **última ejecución semanal de Security**: el trabajo de publicación solo comprueba la del commit, y una vulnerabilidad publicada después no lo para (residual de `threat-model.md` §5).
- [ ] Todas las specs incluidas están **Implementadas** y sus CA tienen test.
- [ ] Tests de integración pasados en simulador y emulador (iOS 16 y el último; Android API 26 y la última).
- [ ] Rendimiento: arranque en frío medido en dispositivo real (p50 < 1 s en el Android de referencia); tamaño dentro del presupuesto: **< 20 MB comprimidos por ABI** (spec 023, CA-023-20; lo comprueba el trabajo de publicación, `size`; medido el 2026-10-20: 13 MB en arm64) y `--analyze-size` si crece.
- [ ] Accesibilidad a mano: VoiceOver, TalkBack, Switch, texto al 200 %, reducir movimiento.
- [ ] "Recientes" (spec 011, ADR-0019; no tiene test de CI, CL-011-13): `tools/check-recents.sh <serial>` en el **emulador** (un dispositivo físico solo con permiso del propietario y sus variables `ALLOW_PHYSICAL*`) sobre la compilación *release* que se entrega: `capture` y `compare` con dos tareas distintas (A y B), `secure`, `loop 10` y `record 10`; todos en verde y el resultado anotado en la entrega. Antes de la beta a testers, repetirlo también en Android 8 (API 26) y 12L (API 32) (PD-10 / T-011-09). Las notas de la beta recogen los límites aceptados (fotograma blanco al volver, "Recientes" abierto desde la propia app, hoja parcial del selector de fotos). Guía en `docs/testing.md` y `docs/security/checklist.md` (sección "Recientes").
- [ ] Migraciones: la actualización desde la versión anterior publicada conserva los datos (test con una BD real anonimizada).

## Versión y changelog
- [ ] `version: X.Y.Z+build` en `pubspec.yaml` (build creciente); release-please ha generado `CHANGELOG.md`.
- [ ] Notas de la versión en ES y EN.

## Identidad y firma
- [ ] Bundle ID y package name **definitivos** (PD-2 resuelto); nombre de la app en su fuente única. El trabajo de publicación lo comprueba (`package-name`): en modo estricto, en verde.
- [ ] Android: AAB firmado con la *upload key* (fuera del repo); Play App Signing activo. `tools/release/upload-cert.sha256` con la huella SHA-256 **pública** del certificado de subida (**[Pendiente, F6]**) y `signature` en verde en el modo estricto.
- [ ] La ejecución del trabajo de publicación que se mira es la del commit que se entrega y viene de **`main`** (testers) o de **la etiqueta `v*`** (estricto): en GitHub, la rama o etiqueta de la ejecución y su commit (`head_branch`/`head_sha`). Una lanzada desde otra rama no vale: llevaría su propio `release.yml` (C-4 de la 020).
- [ ] Configuración del repositorio antes de la primera subida (T-11, spec 020 §8): reglas de las etiquetas `v*` (quién puede lanzar el modo estricto) y protección de `main`, aprobación de workflows de *forks* y *secret scanning*.
- [ ] iOS: archivo firmado con la cuenta de Apple Developer (firma automática).

## Privacidad y tiendas
- [ ] `PrivacyInfo.xcprivacy` sin datos recogidos y con las *required reason APIs*; App Store: "Data Not Collected".
- [ ] Play Data Safety: "No data collected / shared"; el manifiesto combinado solo con los permisos permitidos (el trabajo de publicación lo comprueba, `permissions`). **PD-9 está resuelta (spec 023, propietario 2026-10-20): no se declara nada** (Safe Browsing y la consulta de autorrelleno de la WebView, W-2 y W-3; `ACCESS_LOCAL_NETWORK`, W-10; `store/google-play/data-safety.md`). Antes de rellenar el formulario, **comprobar que sus preguntas siguen siendo las de `data-safety.md` §2** (si Play las cambió, se pone al día la declaración primero, CL-023-3) y repasar las dudas D-1 y D-2 con la Ayuda de Play vigente; si ahora exigiera declarar algo, **se para y se pregunta** (CL-023-1). Si se sube el `targetSdk` a 37, revisar W-10 (`ACCESS_LOCAL_NETWORK` deja de concederse implícito).
- [ ] Política de privacidad **publicada en la web** (`landing/`, proyecto de Vercel con su dominio) y enlazada desde Play Console y desde la app (`privacyPolicyUrl`), y que diga lo mismo que Data Safety (`check.mjs` compara los permisos; lo demás, a ojo). Rellenados los huecos `[RESPONSABLE]`, `[CONTACTO]`, `[FECHA]` y `[WEB]`, y puesto en «Esta web» el **plazo de los registros de Vercel** si su panel lo muestra (hoy la política dice «el tiempo mínimo necesario»: Vercel no publica un plazo para sitios estáticos).
- [ ] **Puerta de publicación** (spec 012, CA-012-05; 015, CA-015-13b; 020, CA-020-09 a 12): la comprueba el trabajo de publicación (`identity`), en verde en el modo estricto: las **tres** direcciones de `app/identity.yaml` (`privacyPolicyUrl`, `thirdPartyLicensesUrl` y `helpUrl`) son `https` de un dominio propio, distintas, con la ruta restringida y sin dominios reservados, lo generado al día y `docs/legal/privacy-policy.md` sin huecos ni marcas `[Suposición]`/`[Assumption]`/`[Pendiente]`/`[Pending]` en ES y EN. **A mano:** las tres coinciden con las de la ficha de la tienda (Play Console) y las tres webs responden.
- [ ] **Licencias de terceros (spec 015, ADR-0026):** la app no las muestra; las enlaza a una web. El trabajo de publicación corre `tools/check-licenses.sh` (y `--negative`) sobre los APK que compila y deja el **archivo de avisos** de **esa** compilación (artefacto `third-party-notices`, caduca a los 90 días): ese archivo se **adjunta a la release**; **la web de licencias publica el archivo de esta versión** (no el de otra; la comprobación no puede saberlo: se hace a mano) y su contenido coincide con el adjunto. **Revisión legal** de ADR-0026 (que una web enlazada cuente como acompañar la distribución: MIT, BSD, Apache y OFL): ver el punto bloqueante siguiente. Si concluye que no basta, se restituye la pantalla en una spec nueva.
- [ ] **Revisión legal (spec 023, CA-023-22) — PUNTO BLOQUEANTE antes de la primera subida a Play.** La hace el propietario (o quien él designe) sobre **la política de privacidad** (`docs/legal/privacy-policy.md`) **y las licencias de terceros en la web** (ADR-0026). La 023 no la hace ni la da por hecha. **Dónde se anota** **[Suposición]**: en las «Notas para la revisión» de `docs/legal/privacy-policy.md` (fecha, quién y resultado) y en la fila de F6 de `docs/PLAN.md`; sin esa anotación, la versión no es publicable. Se repite si cambia la política o el archivo de avisos.
- [ ] **`landing/third-party-notices.txt` es el de la versión que se entrega:** copiarlo en una PR desde la ejecución del trabajo de publicación (en modo estricto) de esa versión (`gh run download <id>`, elegida por flujo, evento, rama y resultado, nunca por el nombre del artefacto), con su cabecera `Versión: X.Y.Z+N`. Hoy es el de la ejecución 38874734623 (modo testers, `main`, `2e835cf`) y la web lo dice ("avisos de la última compilación"); **hay que refrescarlo desde la ejecución de la versión que se entregue**, porque el artefacto caduca a los 90 días.
- [ ] **Ficha en Play Console (spec 023; `store/google-play/`):** textos de `listing/{es-ES,en-US}/` copiados tal cual (se comprueban con `node store/google-play/check.mjs`), icono 512, gráfico de funciones y 4 capturas por idioma, **con su texto alternativo** (≤ 140 caracteres, `play-console.md` §6), y las respuestas de `play-console.md` (idioma por defecto, categoría, anuncios, ID de publicidad, acceso a la app con la nota para revisores, **público 16+**, cuestionario IARC, tipo de app, dispositivos y países). Las capturas se rehacen si cambia el nombre o la pantalla (CL-023-9).
- [ ] **Dirección de la política y de la web en Play:** las tres direcciones de `identity.yaml` coinciden con las de la ficha y las tres webs responden (a mano; la puerta no puede saberlo).
- [ ] Play: la **prueba cerrada con ≥ 12 testers durante 14 días seguidos** está cumplida (cuenta personal nueva; Ayuda de Play, consultada el 2026-10-20, `play-console.md`) **antes de pedir producción**. Hay que reunir a esos 12 testers: hoy no hay ninguno.

## Lista cerrada de lo que falta para la primera subida (F6; spec 023, CA-023-23)

Todo lo que la 023 deja pendiente está aquí (ninguna otra marca `[Pendiente]` de la 023 queda fuera de esta lista) y en la fila de F6 de `docs/PLAN.md`:

1. **PD-2:** dominio y *package name* definitivos (hoy `invalid.pending.app`); `applicationId` y `namespace` en `app/android/app/build.gradle.kts`, las **tres direcciones** de `app/identity.yaml` (`privacyPolicyUrl`, `thirdPartyLicensesUrl`, `helpUrl`; rutas `/privacy`, `/licenses`, `/help`) y las de la ficha; regenerar con `dart run tool/gen_identity.dart`.
2. **Huecos de identidad:** `[RESPONSABLE]`, `[CONTACTO]`, `[FECHA]` y `[WEB]` en `docs/legal/privacy-policy.md`; `[CONTACTO]` en el pie de la web (`landing/src/strings.json`) y en la Ayuda (`landing/src/help.{es,en}.md`); contacto, web y, si Play la exige a una cuenta personal, dirección postal en `play-console.md` (§8: Google muestra de una cuenta personal el nombre legal, el país y el correo, y en algunas regiones el teléfono o la dirección).
3. **PD-3:** crear la **cuenta personal de Google Play** y reunir los **12 testers × 14 días** de la prueba cerrada.
4. **Vercel:** crear el proyecto aparte (Root Directory `landing`, `landing/vercel.json`) con el dominio; comprobar que la construcción ve los archivos de fuera de `landing/` (si no, falla cerrada) y las cabeceras reales (C-023-2); anotar el plazo de los registros si el panel lo da. Nada se despliega sin confirmación del propietario.
5. **Play Console:** copiar la declaración de Data Safety (`data-safety.md`) y las respuestas (`play-console.md`) y comprobar que coinciden; completar lo que no está en páginas públicas (preguntas literales del cuestionario IARC, declaración de apps gubernamentales, literales de funciones financieras y de salud, etiquetas, etiquetas, bloque de borrado del formulario; `play-console.md` §1 y §8) y la **revisión del propietario de las 8 capturas y del gráfico** (C-023-1, aplazada el 2026-10-20 sin verificar; `specs/023-…/dispositivo.md`); si cambia algo del contenido de la app, rehacer el cuestionario de clasificación.
6. **Revisión legal** (punto bloqueante de arriba), incluida la frase «No compartimos datos con nadie» de «Compartir con terceros» frente a Safe Browsing y autorrelleno de la WebView (M-1 del `security-reviewer`) y los hallazgos B-1 a B-8 de `specs/023-…/tasks.md`.
7. **`landing/third-party-notices.txt`** de la versión que se entrega (punto de arriba).
8. **Firma:** `tools/release/upload-cert.sha256` (huella pública del certificado de subida) y la firma del AAB en el trabajo de publicación.
9. **Repositorio:** C-4 (reglas de las etiquetas `v*` y protección de `main`), aprobación de workflows de *forks*, *secret scanning* y `actionlint`.
10. **Web que se publique** (`landing/` o la del producto): repetir sobre ella las casillas aceptadas sin verificar en la 023 (TalkBack con Chrome y la compilación de pruebas con las direcciones locales, C-023-3 y C-023-4).
11. **«Recientes» en la Ayuda:** la Ayuda afirma que no se ve nada en «Recientes» (spec 011), pero PD-10 (Android 8 y 12L) se cerró sin verificar y el mecanismo B es **[Suposición]**: pasar `tools/check-recents.sh` y repasar esa frase antes de entregar.

## Después
- [ ] Con la etiqueta `vX.Y.Z` ya en verde (orden de arriba): TestFlight/Internal → producción escalonada.
- [ ] Copia de seguridad cifrada de la *upload key* verificada.
