# Modelo de amenazas

- **Alcance:** app móvil iOS/Android v1 sin backend, más la web de pruebas en Vercel y la cadena de desarrollo (repo, CI, dependencias y firma).
- **Referencias:** OWASP MASVS v2 (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY) y MASTG para las pruebas.
- **Método:** STRIDE simplificado por superficie. Revisión en cada spec que toque una superficie y antes de cada versión.
- **Fecha:** 2026-09-24 · Versión 1.0

## 1. Activos

| ID | Activo | Sensibilidad | Dónde vive |
|---|---|---|---|
| A-1 | Tareas (texto) e histórico | Media: puede contener datos personales | SQLite en el sandbox |
| A-2 | Adjuntos: fotos, PDF, documentos, capturas web | **Alta**: DNI, entradas, recetas, documentos privados | `attachments/` en el sandbox |
| A-3 | Metadatos de las fotos (EXIF/GPS) | **Alta**: ubicación del usuario | Se eliminan al importar (no deben persistir) |
| A-4 | URL visitadas | Media | BD + WebView (sesión no persistente) |
| A-5 | Ajustes | Baja | BD |
| A-6 | Claves de firma (iOS distribution, Android upload key) | **Crítica**: suplantación de la app | Fuera del repo (ver §6) |
| A-7 | Integridad del código y del pipeline | **Crítica** | GitHub, CI, dependencias |
| A-8 | Reputación "Data Not Collected" | Alta | Declaraciones en las tiendas |

## 2. Actores

| Actor | Capacidad | Motivación |
|---|---|---|
| Web maliciosa o comprometida cargada como tarea URL | Ejecutar JS en la WebView, redirigir, phishing | Robar datos, escapar de la WebView |
| Archivo malicioso importado (PDF, imagen, docx) | Explotar parsers, contenido activo | Ejecutar código, fugas |
| Otra app del dispositivo | Intents, esquemas de URL, portapapeles, almacenamiento compartido | Leer datos de la app |
| Persona con acceso físico breve al teléfono **desbloqueado** | Ver la app abierta | Curiosidad o intrusión |
| Ladrón con el dispositivo **bloqueado** | Extracción física | Datos |
| Atacante de la cadena de suministro | Paquete pub/npm/acción de GitHub comprometidos | Insertar código |
| Contribuidor o *fork* malicioso (repo público) | PR con cambios en workflows | Robar secretos de CI |
| Visitante de la web de pruebas | Navegador | XSS, *clickjacking* |

## 3. Superficies de ataque y amenazas

| ID | Superficie | Amenaza (STRIDE) | Mitigación | MASVS |
|---|---|---|---|---|
| T-1 | Almacenamiento en reposo | Divulgación por extracción del dispositivo | Sandbox; Data Protection `CompleteUntilFirstUserAuthentication`; almacenamiento interno en Android; nada en almacenamiento externo (ADR-0005) | STORAGE-1 |
| T-2 | Fugas laterales | Divulgación por logs, portapapeles, instantánea del selector de apps, notificaciones | Sin logs de contenido en *release*; nunca se copia al portapapeles sin acción del usuario; notificaciones futuras sin contenido por defecto; **[Pendiente]** decidir si se oculta la instantánea del selector (choca con P2; se decide en la spec 010 como ajuste futuro) | STORAGE-2, PRIVACY |
| T-3 | Importación de archivos | Manipulación o ejecución por archivos malformados | Tipo por **bytes mágicos** + extensión coherente; límites de tamaño y píxeles; **recodificar las imágenes** (elimina EXIF/GPS/XMP y payloads); SVG, HTML, XML y ejecutables rechazados; PDF con pdfrx sin JS ni formularios; documentos solo con el visor del sistema; nombres de archivo saneados (sin rutas, sin `..`, longitud máxima); todo en un *isolate* con *timeouts* | PLATFORM-2, CODE-4 |
| T-4 | WebView de tareas URL | Ejecución o escalada: puente JS, `file://`, cookies persistentes | `javaScriptBridgeEnabled:false`; sin acceso a archivos ni contenido; almacén no persistente; sin permisos; sin descargas; `isInspectable` solo en debug (ADR-0007) | PLATFORM-2 |
| T-5 | URL introducida | Suplantación: esquemas peligrosos, homógrafos IDN, credenciales en la URL | Solo `http(s)`; bloqueo de `javascript:`, `data:`, `file:`, `content:`, `intent:`…; se rechaza `user:pass@`; se muestra el dominio real (punycode si mezcla alfabetos); navegación fuera del dominio → navegador del sistema tras avisar | NETWORK-1, PLATFORM-2 |
| T-6 | Red | Manipulación (MITM) | ATS y `cleartextTrafficPermitted=false`; sin excepciones; sin *pinning* (no hay backend propio) | NETWORK-1 |
| T-7 | Copias de seguridad | Divulgación vía iCloud/Google | Incluidas por decisión (ADR-0004); explicado en "Acerca de"; los temporales y cachés se excluyen | STORAGE-2 |
| T-8 | Componentes exportados (Android) / esquemas de URL | Suplantación por intents de otras apps | Solo la `MainActivity` exportada; FileProvider no exportado con `grantUriPermissions` puntual y solo de lectura; sin *deep links* en la v1 | PLATFORM-1 |
| T-9 | Web de pruebas (Vercel) | XSS o *clickjacking* | CSP estricta, `frame-ancestors 'none'`, HSTS, nosniff, `Referrer-Policy: no-referrer`, `Permissions-Policy`; sin scripts de terceros; previews protegidas; `noindex` (ADR-0010) | — |
| T-10 | Dependencias | Manipulación en la cadena de suministro | `pubspec.lock` versionado; versiones fijadas; Dependabot; OSV-Scanner en CI; dependency-review en las PR; acciones fijadas por SHA; criterios de aceptación de dependencias (§5) | CODE-3 |
| T-11 | CI y repositorio público | Robo de secretos o manipulación del pipeline | `permissions:` mínimos por workflow; sin `pull_request_target` con checkout del código de la PR; sin secretos de firma en CI de PR; aprobación obligatoria de workflows de contribuidores externos; reglas de rama en `main`; secret scanning + push protection | — |
| T-12 | Claves de firma | Suplantación de la app | Fuera del repo; `.gitignore` + hooks de Claude Code; Play App Signing (Google guarda la clave de firma, en el repo solo se usa la de subida); certificados de Apple en el llavero local; copia cifrada fuera de línea (gestor de contraseñas) | — |
| T-13 | Código de terceros en el cliente | Divulgación: SDK con telemetría | Prohibidos la analítica y el crash reporting; revisión de `AndroidManifest` combinado y de `PrivacyInfo.xcprivacy` de las dependencias; test de CI que falla si aparecen permisos no esperados | PRIVACY-1 |
| T-14 | Importadores futuros (Todoist, Keep…) | Denegación de servicio o manipulación con archivos malformados | Parsers en *isolate* con límites (tamaño, profundidad y número de elementos), sin `eval`, *fuzzing* con casos malformados antes de activar el flag `imports` | CODE-4 |
| T-15 | Acceso físico con el teléfono desbloqueado | Divulgación | Aceptado en la v1 (sin biometría, D11); se reevalúa con el flag `biometricLock` | AUTH (N/A v1) |

## 4. Privacidad: objetivo "Data Not Collected"

- **Ni analítica, ni crash reporting, ni publicidad, ni identificadores de dispositivo.** Ninguna llamada de red salvo la WebView de URL que el usuario pide.
- **iOS:** `PrivacyInfo.xcprivacy` sin tipos de datos recogidos, con las *required reason APIs* declaradas (p. ej. `UserDefaults` CA92.1, *file timestamp* C617.1) y revisión de los manifiestos de los plugins. App Store: "Data Not Collected".
- **Android:** formulario de Data Safety "No data collected / No data shared"; permisos únicamente `INTERNET` (WebView) y `CAMERA` (solo si se usa el permiso en vez del intent del sistema); se eliminan los permisos añadidos por los plugins (`tools:node="remove"`) y CI verifica el manifiesto combinado.
- Política de privacidad breve (Bloque 5; se necesita antes de publicar) que refleje exactamente esto.

## 5. Criterios para aceptar una dependencia

Mantenida (release en los últimos 12 meses o estable y sin issues de seguridad abiertas), licencia compatible (MIT/BSD/Apache/OFL/zlib; nada de GPL en la app), **sin telemetría**, con publicador verificado en pub.dev si es posible, tamaño justificado, sin alternativa razonable en el SDK. Se registra en la PR con la sección "Nueva dependencia" de la plantilla.

## 6. Gestión de las claves de firma

- Android: **Play App Signing** activado desde la primera subida; la *upload key* en un `.jks` fuera del repo (`~/.config/<app>/upload.jks`) con `key.properties` en `.gitignore`; copia cifrada en el gestor de contraseñas.
- iOS: firma automática de Xcode con la cuenta de Apple Developer; los certificados, en el llavero de macOS. Ningún `.p12`, `.p8`, `.mobileprovision` ni `.cer` en el repo.
- CI de publicación (futuro): secretos en *environments* protegidos de GitHub con aprobación manual; nunca disponibles en workflows de PR.

## 7. Riesgos residuales aceptados

- Acceso físico con el teléfono desbloqueado (T-15).
- JS de terceros ejecutándose en la WebView en vivo (mitigado por el aislamiento; es inherente a mostrar webs).
- En Android, los documentos no PDF se abren con apps de terceros elegidas por el usuario (reciben el archivo en solo lectura).

## 8. Verificación

Checklist por PR (`checklist.md`), revisión del subagente `security-reviewer` en las PR que tocan superficies T-3 a T-6 y T-10 a T-13, pruebas MASTG seleccionadas antes de la v1.0 (almacenamiento, WebView, intents, manifiesto de red) y un test automático de permisos y manifiestos.
