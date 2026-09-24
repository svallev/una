# Política de seguridad

## Cómo informar de una vulnerabilidad

Usa **[Report a vulnerability](../../security/advisories/new)** (informes privados de GitHub) en este repositorio. **No abras un issue público.**

Incluye: versión o commit, plataforma (iOS/Android/web), pasos para reproducirlo e impacto. Respondemos en un plazo de 7 días y coordinamos la divulgación una vez publicada la corrección.

## Alcance

- La app móvil (iOS/Android) y su tratamiento de archivos, URL y datos locales.
- La web de pruebas desplegada en Vercel.
- El pipeline de CI de este repositorio.

Fuera de alcance: ataques que requieren un dispositivo con *jailbreak*/*root* o desbloqueado en manos del atacante, e ingeniería social.

## Principios

La app no tiene servidor ni cuentas y no envía datos a terceros. Modelo de amenazas: [docs/security/threat-model.md](docs/security/threat-model.md).

## Versiones con soporte

Hasta la v1.0 solo recibe correcciones la última versión publicada.
