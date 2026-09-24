# ADR-0004: Incluir los datos en las copias de seguridad del sistema

- **Estado:** Aceptado (D14), **revisado el 2026-09-24 tras el spike S5**
- **Fecha:** 2026-09-24
- **Relacionado:** ADR-0005, modelo de amenazas (A-1, T-7)

## Contexto

- **[Hecho]** Sin cuentas ni servidor, la copia de seguridad del sistema es la única forma de no perder las tareas al cambiar de móvil.
- **[Hecho]** iOS: iCloud Backup copia `Documents` y `Library/Application Support` salvo lo marcado como excluido. Los backups de iCloud están cifrados, pero Apple tiene las claves salvo que el usuario active la Protección Avanzada de Datos (entonces el cifrado es de extremo a extremo).
- **[Hecho]** Android: la copia automática (Auto Backup) sube a Google Drive **hasta 25 MB por app**. Desde Android 9 va cifrada de extremo a extremo con el bloqueo de pantalla del dispositivo. Con reglas `dataExtractionRules` (Android 12+) y `fullBackupContent` (≤ 11) se decide qué entra.

## Decisión

- **iOS:** se incluye todo (BD + adjuntos). Las miniaturas y los archivos temporales regenerables se guardan en `Caches` o se marcan con `isExcludedFromBackup`.
- **Android:** se incluyen la BD y los ajustes, y los adjuntos **hasta** el límite. Reglas: `database/`, `shared_prefs/` y `files/attachments/`. Si se supera el límite, Android omite la copia de la app entera, así que **se excluyen los adjuntos** cuando su total supera ~20 MB (el tamaño se controla y los adjuntos van en un subdirectorio excluible). La tarea restaurada sin archivo muestra "Adjunto no disponible" y permite eliminarlo o sustituirlo.
- **Transferencia de dispositivo a dispositivo** (Android 12+ `device-transfer`): se incluye todo (no tiene límite de 25 MB).
- Texto en "Acerca de" (ES/EN) que explique qué se copia, dónde y con qué cifrado.
- Futuro (Bloque 5): exportación e importación manual a un archivo `.zip`, como alternativa independiente del sistema.

## Consecuencias

- La app debe tolerar la falta de archivos de adjuntos tras una restauración (estado de error diseñado en las specs 007–009).
- Test de integración que simula una restauración (BD sin archivos).
- El manifiesto de privacidad y el "Data safety" de Play siguen declarando "no se recogen datos": la copia la hace el sistema operativo y va a la cuenta del usuario.

## Revisión tras el spike S5 (2026-09-24)

- **[Hecho]** Con reglas estáticas que incluyen `attachments/`, en cuanto los adjuntos superan la cuota (25 MB), Android responde *"Size quota exceeded"* y **descarta la copia entera de la app, base de datos incluida**. Sin adjuntos, la BD se copia (57 KB) y se restaura correctamente.
- **[Hecho]** Tras restaurar sin adjuntos, una app que suponga que el archivo existe **se cuelga al arrancar** (lo hizo el spike).

**Decisión revisada (Android):**
1. Un `BackupAgent` propio (copia completa con `onFullBackup`) que incluye **siempre** la BD y los ajustes y añade adjuntos **por prioridad** (primero el de la tarea actual; después, las pendientes por orden de la cola; nunca las completadas) **hasta un presupuesto de 20 MB**. Las reglas XML quedan como respaldo para Android 11 o anterior, sin adjuntos.
2. La transferencia entre dispositivos (`device-transfer`) incluye **todo** (no tiene cuota).
3. La app **nunca** depende de que exista el archivo de un adjunto para arrancar ni para mostrar la tarea: estado "Adjunto no disponible" (CL-007-4) con test de integración de restauración.
4. iOS (F-iOS): iCloud no tiene esta cuota por app; se mantiene "incluir todo".
