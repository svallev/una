---
name: release-checklist
description: Checklist para preparar una versión (beta o tiendas). Solo cuando el usuario lo pida explícitamente.
disable-model-invocation: true
argument-hint: "<versión X.Y.Z>"
---

# Checklist de release

Recorre cada punto y presenta el estado (✅ / ❌ / N/A con evidencia). **No subas nada a las tiendas, no crees etiquetas ni hagas push sin la confirmación explícita del usuario.**

## Código y calidad
- [ ] `main` en verde (CI y Security); sin alertas abiertas de secret scanning, CodeQL, Dependabot ni OSV de severidad ≥ media.
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
- [ ] Bundle ID y package name **definitivos** (PD-2 resuelto); nombre de la app en su fuente única.
- [ ] Android: AAB firmado con la *upload key* (fuera del repo); Play App Signing activo.
- [ ] iOS: archivo firmado con la cuenta de Apple Developer (firma automática).

## Privacidad y tiendas
- [ ] `PrivacyInfo.xcprivacy` sin datos recogidos y con las *required reason APIs*; App Store: "Data Not Collected".
- [ ] Play Data Safety: "No data collected / shared"; el manifiesto combinado solo con los permisos permitidos (`tools/check-android-permissions.sh`). Revisar PD-9 (Safe Browsing de la WebView, spec 009) con la guía de Play vigente.
- [ ] Política de privacidad publicada y enlazada (Bloque 5; necesaria para publicar).
- [ ] **Puerta de publicación** (spec 012, CA-012-05, ampliada por la 015, CA-015-13): `tools/check-release-config.sh` en verde sobre el commit que se entrega (también `gen_identity.dart --check`): las **tres** direcciones de `app/identity.yaml` (`privacyPolicyUrl`, `thirdPartyLicensesUrl` y `helpUrl`) son `https` de un dominio propio, **distintas entre sí**, sin consulta ni fragmento y no el marcador `example.com` ni otro reservado; `docs/legal/privacy-policy.md` sin huecos ES/EN. Revisar a mano las frases **[Suposición]**/**[Assumption]** de la política (el script no las detecta). **Las tres coinciden con las de la ficha de la tienda** (Play Console) y las tres webs responden. **También antes de cada entrega a testers, no solo antes de publicar:** con marcadores se anota qué falla; antes de publicar tiene que pasar.
- [ ] **Licencias de terceros (spec 015, ADR-0026):** la app no las muestra; las enlaza a una web. Con el APK de *release* que se entrega: `tools/check-licenses.sh` en verde (emite y verifica `app/build/third-party-notices.txt`); el **archivo de avisos** de **este** paquete se regenera y se **adjunta a la release** (el artefacto de CI caduca a los 90 días); **la web de licencias publica el archivo de esta versión** (no el de otra; la comprobación no puede saberlo: se hace a mano) y su contenido coincide con el adjunto. **Revisión legal** de ADR-0026 (que una web enlazada cuente como acompañar la distribución: MIT, BSD, Apache y OFL) hecha y anotada: **punto bloqueante antes de publicar** (F6/023). Si concluye que no basta, se restituye la pantalla en una spec nueva.
- [ ] Fichas en ES y EN, capturas (con datos ficticios), icono, clasificación de contenido.
- [ ] Play: la prueba cerrada con ≥ 12 testers durante 14 días está cumplida (cuenta personal nueva).

## Después
- [ ] Etiqueta `vX.Y.Z` (tras confirmación), TestFlight/Internal → producción escalonada.
- [ ] Copia de seguridad cifrada de la *upload key* verificada.
