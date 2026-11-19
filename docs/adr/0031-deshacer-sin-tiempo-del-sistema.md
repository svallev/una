# ADR-0031: Deshacer en iOS: 10 s con VoiceOver o Control por botón, como en Android 8 y 9

- **Estado:** **Aceptado** (propietario, 2026-11-19, Q-028-2 de la spec 028: «ok»). **Enmienda el ADR-0021** (su excepción a P6) y la constitución (**versión 1.11**).
- **Fecha:** 2026-11-19
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 028 (CA-028-14), spec 014 (CA-014-06 y 17), ADR-0021, constitución P6; `docs/ios/channel-contract.md` §7.

## Contexto

- **[Hecho]** La card de deshacer dura 4 s (D20). En Android 10 o posterior manda el «Tiempo para actuar» del sistema; en Android 8 y 9, que no lo tienen, dura 10 s con un servicio de accesibilidad activo (excepción a P6 del ADR-0021, WCAG 2.2.1). La regla vive en Dart (`UndoDuration`); el canal `una/a11y` solo da los hechos.
- **[Suposición, conocimiento previo de la API de Apple]** iOS no tiene un ajuste equivalente al «Tiempo para actuar» que una app pueda leer; sí puede saber si VoiceOver o Control por botón están activos.

## Opciones consideradas

1. **Misma regla que Android 8 y 9:** 10 s con VoiceOver o Control por botón; 4 s sin ellos.
2. **4 s siempre en iOS** (sin canal): peor que Android para quien usa tecnología de apoyo.
3. **Sin límite con tecnología de apoyo:** la eliminación no se haría definitiva hasta salir de la pantalla; cambia la spec 014.

## Decisión

**Opción 1.** En iOS, `una/a11y` devuelve `recommendedMs: null`, `serviceEnabled` = VoiceOver o Control por botón activos y `touchExploration` = VoiceOver activo; la regla de Dart no cambia. La excepción a P6 del ADR-0021 pasa de «Android 8 y 9» a «**plataformas sin ajuste de tiempo del sistema** (Android 8 y 9, iOS)». Se revisa si iOS ofrece un ajuste de tiempo legible o si la pasada con VoiceOver (CA-028-21) lo señala.

## Motivos

Es la opción que trata igual a quien usa tecnología de apoyo en las dos plataformas, sin código nuevo en Dart; con VoiceOver, además, la card no caduca mientras tiene el foco (CA-014-17), que es la mitigación principal.

## Consecuencias

- **Positivas:** sin cambios en Dart; un canal de tres valores en Swift.
- **Negativas:** con Control por botón, 10 s no llega a diez veces el tiempo por defecto (igual que en Android 8 y 9). Mitigación: con VoiceOver y con teclado el tiempo se detiene con el foco.
- **Cambios en otros documentos:** constitución 1.11 (P6, la viñeta del ADR-0021); nota en el ADR-0021; README de los ADR.
