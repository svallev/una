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

- **Entrega a testers:** lanzar el trabajo **a mano desde `main`** (modo testers, con confirmación). Tiene que terminar en verde (los avisos de identidad salen listados, con «Esta versión no se puede publicar.»; cualquier otro fallo es rojo). La entrega se compila **del mismo commit** que pasó el trabajo (no sube APK) y se anota en ella el enlace a la ejecución y la lista de avisos.
- **Publicar, en este orden:**
  1. La etiqueta `vX.Y.Z` (igual a `version:` de `pubspec.yaml`, sobre un commit de `main`, con el `+build` mayor que el de la etiqueta anterior), creada y subida **solo tras la confirmación del usuario**. Eso lanza el modo estricto.
  2. El trabajo en **modo estricto en verde** sobre ese commit. **Sin una ejecución en verde del trabajo sobre ese commit, la versión no es publicable**, también si la etiqueta es de un commit anterior a la spec 020 (no se lanza nada, CL-020-16). Si el trabajo falla, la etiqueta **se borra** (con permiso del usuario), se corrige y se crea otra.
  3. El **archivo de avisos** de esa ejecución (artefacto `third-party-notices`, caduca a los 90 días) adjunto a la versión, y la web de licencias con ese mismo archivo.
  4. Publicar el **AAB que compiló ese trabajo** (firmado, F6), nunca una compilación local.

## Código y calidad
- [ ] `main` en verde (CI y Security); sin alertas abiertas de secret scanning, CodeQL, Dependabot ni OSV de severidad ≥ media. Mirar también la **última ejecución semanal de Security**: el trabajo de publicación solo comprueba la del commit, y una vulnerabilidad publicada después no lo para (residual de `threat-model.md` §5).
- [ ] Todas las specs incluidas están **Implementadas** y sus CA tienen test.
- [ ] Tests de integración pasados en simulador y emulador (iOS 16 y el último; Android API 26 y la última).
- [ ] Rendimiento: arranque en frío medido en dispositivo real (p50 < 1 s en el Android de referencia); tamaño dentro del presupuesto (`--analyze-size`).
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
- [ ] Play Data Safety: "No data collected / shared"; el manifiesto combinado solo con los permisos permitidos (el trabajo de publicación lo comprueba, `permissions`). Revisar PD-9 con la guía de Play vigente: Safe Browsing de la WebView (spec 009), la **consulta de autorrelleno** de la WebView a `content-autofill.googleapis.com` (H-1 de la 020, aceptado, `threat-model.md` §4 y §7) y `ACCESS_LOCAL_NETWORK`, que Android 17 concede con `INTERNET` (H-8).
- [ ] Política de privacidad publicada y enlazada (Bloque 5; necesaria para publicar), y que diga lo mismo que Data Safety (también lo del punto anterior).
- [ ] **Puerta de publicación** (spec 012, CA-012-05; 015, CA-015-13b; 020, CA-020-09 a 12): la comprueba el trabajo de publicación (`identity`), en verde en el modo estricto: las **tres** direcciones de `app/identity.yaml` (`privacyPolicyUrl`, `thirdPartyLicensesUrl` y `helpUrl`) son `https` de un dominio propio, distintas, con la ruta restringida y sin dominios reservados, lo generado al día y `docs/legal/privacy-policy.md` sin huecos ni marcas `[Suposición]`/`[Assumption]`/`[Pendiente]`/`[Pending]` en ES y EN. **A mano:** las tres coinciden con las de la ficha de la tienda (Play Console) y las tres webs responden.
- [ ] **Licencias de terceros (spec 015, ADR-0026):** la app no las muestra; las enlaza a una web. El trabajo de publicación corre `tools/check-licenses.sh` (y `--negative`) sobre los APK que compila y deja el **archivo de avisos** de **esa** compilación (artefacto `third-party-notices`, caduca a los 90 días): ese archivo se **adjunta a la release**; **la web de licencias publica el archivo de esta versión** (no el de otra; la comprobación no puede saberlo: se hace a mano) y su contenido coincide con el adjunto. **Revisión legal** de ADR-0026 (que una web enlazada cuente como acompañar la distribución: MIT, BSD, Apache y OFL) hecha y anotada: **punto bloqueante antes de publicar** (F6/023). Si concluye que no basta, se restituye la pantalla en una spec nueva.
- [ ] Fichas en ES y EN, capturas (con datos ficticios), icono, clasificación de contenido.
- [ ] Play: la prueba cerrada con ≥ 12 testers durante 14 días está cumplida (cuenta personal nueva).

## Después
- [ ] Con la etiqueta `vX.Y.Z` ya en verde (orden de arriba): TestFlight/Internal → producción escalonada.
- [ ] Copia de seguridad cifrada de la *upload key* verificada.
