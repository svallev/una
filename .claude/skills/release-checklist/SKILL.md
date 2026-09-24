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
- [ ] Play Data Safety: "No data collected / shared"; el manifiesto combinado solo con los permisos permitidos (`tools/check-android-permissions.sh`).
- [ ] Política de privacidad publicada y enlazada (Bloque 5; necesaria para publicar).
- [ ] Fichas en ES y EN, capturas (con datos ficticios), icono, clasificación de contenido.
- [ ] Play: la prueba cerrada con ≥ 12 testers durante 14 días está cumplida (cuenta personal nueva).

## Después
- [ ] Etiqueta `vX.Y.Z` (tras confirmación), TestFlight/Internal → producción escalonada.
- [ ] Copia de seguridad cifrada de la *upload key* verificada.
