# ADR-0005: Sin cifrado propio de la base de datos en la v1; protección del sistema

- **Estado:** Aceptado. Se revisará si se añade el bloqueo con biometría (D11) o sincronización.
- **Fecha:** 2026-09-24
- **Relacionado:** modelo de amenazas (T-1, T-2), ADR-0004, MASVS-STORAGE-1/2

## Contexto

- **[Hecho]** Los datos son personales pero no especialmente sensibles por diseño (tareas y adjuntos que el usuario decide guardar). Aun así, pueden contener datos sensibles (una foto de un DNI o de una receta médica).
- **[Hecho]** Ambos sistemas cifran el almacenamiento del dispositivo y aíslan el sandbox de cada app.
- **[Hecho]** Los futuros widgets de pantalla de bloqueo necesitan leer la tarea actual con el dispositivo bloqueado (después del primer desbloqueo).
- **[Hecho]** SQLCipher añade tamaño (~7 MB), coste al arrancar (derivación de clave) y gestión de claves en Keychain/Keystore, y complica el backup (una clave no restaurable deja la BD ilegible).

## Opciones consideradas

1. Protección del sistema (sandbox + cifrado del dispositivo + clase de Data Protection)
2. SQLCipher con clave en Keychain/Keystore
3. Cifrado por archivo de los adjuntos

## Decisión

**Opción 1.**
- iOS: clase `NSFileProtectionCompleteUntilFirstUserAuthentication` (la de por defecto), para la BD y los adjuntos. `Complete` impediría que los widgets de bloqueo lean los datos.
- Android: almacenamiento interno privado (`filesDir`/`databases`), nunca almacenamiento externo compartido. `android:allowBackup` según ADR-0004.
- Nada de datos de tareas en logs, portapapeles automático, notificaciones con contenido ni capturas del selector de apps (ver la nota de privacidad en el modelo de amenazas).

## Motivos

La amenaza que cubriría SQLCipher (extracción forense de un dispositivo desbloqueado o con *jailbreak*) queda fuera del alcance razonable de una app de tareas. El SO ya mitiga el robo de un dispositivo bloqueado. El coste en arranque (P2) y el riesgo de perder datos por gestión de claves superan el beneficio.

## Consecuencias

- Se documenta en "Acerca de": "Tus datos se guardan cifrados por el sistema de tu teléfono y no salen de él".
- Si llega la biometría (bloqueo de app), se reevalúa: cifrar con una clave ligada a la biometría encaja con ese caso de uso.
