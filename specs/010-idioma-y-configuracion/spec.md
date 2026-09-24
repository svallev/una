# Spec 010: Idioma y Configuración mínima

- **Estado:** En revisión (**sin diseño en el prototipo**: hay que diseñarla antes de implementarla)
- **Reglas de producto:** R15; D13 ("Configuración" sin perfil), D10 (pantalla encendida), D14 (backups)
- **Pantallas del prototipo:** ninguna (el menú enlaza "Configuración y perfil" sin acción; DEV-05)
- **Decisiones y ADR:** ADR-0004, ADR-0005; constitución P4, P7
- **Dependencias:** 001, 005

## 1. Objetivo

Que la app hable el idioma del usuario sin preguntar, que se pueda cambiar, y que explique con claridad que los datos no salen del teléfono.

## 2. Historias de usuario

- **HU-010-1** Como usuario con el móvil en español (de cualquier país), quiero la app en español sin configurar nada.
- **HU-010-2** Como usuario bilingüe, quiero forzar el idioma de la app.
- **HU-010-3** Como usuario preocupado por la privacidad, quiero saber qué pasa con mis datos.

## 3. Criterios de aceptación

**Idioma (R15)**

- **CA-010-01 Detección automática**
  - **Dado** que el ajuste de idioma es "Automático" (valor por defecto)
  - **Cuando** el idioma preferido del dispositivo es cualquier variante `es-*` (es-ES, es-MX, es-419…)
  - **Entonces** la app está en español; con cualquier otro idioma (incluidos ca, gl, eu y pt), en inglés.
- **CA-010-02 Lista de idiomas del sistema**
  - **Dado** que el dispositivo tiene varios idiomas preferidos (p. ej. `fr-FR`, `es-ES`)
  - **Cuando** está en "Automático"
  - **Entonces** se usa el **primero** de la lista que la app admite (en el ejemplo, español). **[Suposición]** Es el comportamiento estándar de iOS y Android; se confirma en revisión.
- **CA-010-03 Cambio manual**
  - **Dado** la pantalla Configuración
  - **Cuando** elige "Español" o "English"
  - **Entonces** toda la app cambia al instante (sin reiniciar) y la elección se mantiene al reabrir; "Automático" vuelve a seguir al sistema.
- **CA-010-04 Formatos**
  - **Dado** cualquier idioma activo
  - **Cuando** se muestran fechas (p. ej. "Copia del …"), números o plurales
  - **Entonces** siguen las reglas de ese idioma.
- **CA-010-05 Nombre de la app**
  - **Dado** un cambio del nombre de la app en su única fuente de configuración
  - **Cuando** se genera una nueva compilación
  - **Entonces** el nombre cambia en el icono, en todos los textos y en el logotipo, sin tocar código.

**Configuración (D13)**

- **CA-010-06 Acceso**
  - **Dado** el menú
  - **Cuando** elige "Configuración"
  - **Entonces** se abre la pantalla Configuración con un botón para volver.
- **CA-010-07 Contenido**
  - **Dado** la pantalla Configuración
  - **Cuando** se muestra
  - **Entonces** contiene: **Idioma** (Automático · Español · English), **"Mantener la pantalla encendida con adjuntos"** (interruptor, activado por defecto), **Privacidad** (texto fijo, ver §7), **Copias de seguridad** (texto explicativo según la plataforma), **Licencias de código abierto** y **Versión** ({versión} ({build})).
- **CA-010-08 Sin perfil**
  - **Dado** la v1
  - **Cuando** se revisa el menú y la Configuración
  - **Entonces** no aparece "perfil" en ningún lugar.
- **CA-010-09 Licencias**
  - **Dado** Configuración
  - **Cuando** elige "Licencias de código abierto"
  - **Entonces** se listan todas las dependencias con su licencia (incluidas las fuentes OFL).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-010-1 | Se cambia el idioma del sistema con la app en "Automático" y abierta | Se aplica al volver a la app |
| CL-010-2 | Idioma forzado distinto del sistema | Los selectores del sistema (fotos, archivos) siguen en el idioma del sistema; es aceptable |
| CL-010-3 | Nombre de la app en el icono con idioma forzado | El nombre del icono lo decide el SO según el idioma del sistema (limitación aceptada) |

## 5. Accesibilidad

- El selector de idioma es un grupo de opciones con el estado anunciado; cada opción se anuncia en su propio idioma ("English", no "Inglés").
- El interruptor anuncia su estado; todo el texto de Privacidad y Backups es legible con texto grande.

## 6. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `settingsTitle` | Configuración | Settings |
| `settingsLanguage` | Idioma | Language |
| `settingsLanguageSystem` | Automático (idioma del teléfono) | Automatic (phone language) |
| `settingsLanguageEs` | Español | Español |
| `settingsLanguageEn` | English | English |
| `settingsKeepScreenOn` | Mantener la pantalla encendida con adjuntos | Keep the screen on for attachments |
| `settingsPrivacyTitle` | Privacidad | Privacy |
| `settingsPrivacyBody` | Tus tareas y archivos se guardan solo en este teléfono. No hay cuentas, analítica ni publicidad, y no enviamos tus datos a ningún servidor. La app solo se conecta a internet para cargar las páginas web que tú añades. | Your tasks and files are stored only on this phone. There are no accounts, analytics or ads, and we don't send your data to any server. The app only goes online to load the web pages you add. |
| `settingsBackupTitle` | Copias de seguridad | Backups |
| `settingsBackupBodyIos` | Si tienes activada la copia en iCloud, tus tareas se incluyen en ella. Apple la cifra; con la Protección Avanzada de Datos, solo tú puedes leerla. | If iCloud Backup is on, your tasks are included in it. Apple encrypts it; with Advanced Data Protection, only you can read it. |
| `settingsBackupBodyAndroid` | Si tienes activada la copia de Google, tus tareas se incluyen en ella, cifradas con el bloqueo de pantalla de tu teléfono. Los archivos grandes pueden quedar fuera de la copia. | If Google backup is on, your tasks are included, encrypted with your phone's screen lock. Large files may be left out of the backup. |
| `settingsLicenses` | Licencias de código abierto | Open-source licences |
| `settingsVersion` | Versión {version} ({build}) | Version {version} ({build}) |
| `settingsBack` | Volver | Back |

## 7. Fuera de alcance

Tema y paletas (Bloque 4), notificaciones (Bloque 4), páginas legales y ayuda (Bloque 5), exportar e importar (Bloque 5), biometría (D11).
