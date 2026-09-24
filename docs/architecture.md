# Arquitectura

> Estado: diseño para la v1, pendiente de validación en los spikes (ADR-0001). Etiquetas: **[Hecho]**, **[Suposición]** y **[Pendiente]**.

## 1. Capas

```mermaid
flowchart TB
  subgraph UI["Presentación (Flutter widgets)"]
    S1[CurrentTaskScreen]:::ui
    S2[TaskEditorScreen]:::ui
    S3[TaskListScreen]:::ui
    S4[SettingsScreen]:::ui
    SH[Sheets: Menú · ¿Dónde? · Añadir · URL · Eliminar]:::ui
    V[AttachmentViewer: imagen · PDF · web · tarjeta doc]:::ui
    FX[Animaciones: HoldToComplete · Tear · Crumple · Intro]:::ui
  end
  subgraph STATE["Estado (Riverpod)"]
    P1[currentTaskProvider]
    P2[queueProvider]
    P3[settingsProvider]
    P4[undoController]
  end
  subgraph DOMAIN["Dominio (Dart puro, sin Flutter)"]
    UC[Casos de uso: CreateTask · PlaceTask · CompleteTask · DeleteTask · UndoDelete · ReorderTask · EditTask · ImportAttachment · CaptureWebSnapshot]
    E[Entidades: Task · Attachment · Rank · QueuePosition · Settings]
    RP[[TaskRepository]]
    AS[[AttachmentStore]]
    PF[[Platform ports: SystemViewer · WebSnapshotter · ImageSanitizer · Clock · IdGenerator]]
  end
  subgraph DATA["Datos e infraestructura"]
    DR[DriftTaskRepository → SQLite]
    FS[FileAttachmentStore → sandbox]
    IMP[ImportPipeline: bytes mágicos · límites · eliminar EXIF · miniaturas]
    WV[HardenedWebView + Snapshotter]
    PDF[pdfrx]
    NV[Canal nativo: QuickLook · FileProvider/ACTION_VIEW]
  end
  UI --> STATE --> UC
  UC --> E
  UC --> RP & AS & PF
  RP -.implementa.- DR
  AS -.implementa.- FS
  PF -.implementa.- IMP & WV & NV
  V --> PDF
  classDef ui fill:#FFE55C,stroke:#111,color:#111
```

**Reglas de dependencia:** `presentation → state → domain ← data`. El dominio **no importa** Flutter, drift ni plugins, y se prueba con tests de Dart puro. Toda la persistencia pasa por `TaskRepository` y `AttachmentStore` (así se puede añadir sincronización sin reescribir los casos de uso).

**Estructura prevista de `app/lib/`** (por funcionalidad y capas):

```
lib/
  app/            arranque, router, AppIdentity, FeatureFlags, tema (tokens.g.dart)
  l10n/           app_es.arb, app_en.arb (textos, fechas, plurales)
  domain/         entities/, usecases/, ports/ (interfaces)
  data/           db/ (drift: tablas, migraciones), attachments/, import/, web/, platform/
  features/
    current_task/ first_run/ editor/ placement/ complete/ delete/ task_list/ attachments/ settings/
  ui/             componentes base con tokens (StickyNote, BrutalButton, Sheet, Toast…)
```

**[Suposición]** Riverpod (sin generación de código) como gestor de estado, porque permite probar sin widgets y sobrescribir dependencias en los tests. Se confirma en el `plan.md` de la spec 001.

## 2. Arranque rápido (P2: < 1 s hasta ver la tarea actual)

```mermaid
sequenceDiagram
  autonumber
  participant OS as Sistema
  participant N as Splash nativo (color paper + logo)
  participant M as main()
  participant DB as SQLite
  participant UI as CurrentTaskScreen
  OS->>N: lanza la app (splash mostrado por el SO)
  N->>M: runApp (sin await de plugins no críticos)
  M->>DB: abrir BD + SELECT tarea actual (índice status,deletedAt,rank) LIMIT 1
  DB-->>M: Task + Attachment (rutas)
  M->>UI: primer fotograma: nota o miniatura en caché
  UI-->>OS: tarea visible (medida: TTFD)
  Note over UI: después del primer fotograma: imagen/PDF a resolución completa,<br/>migraciones pesadas diferidas, purga de eliminadas, recuento de la cola
```

- Fuentes empaquetadas (ya en el primer fotograma) y *shaders* precompilados.
- Imagen: se muestra primero la **versión de pantalla** pregenerada al importar (≤ 2 × la resolución de pantalla); el original se carga al hacer zoom.
- PDF: miniatura de la primera página pregenerada; pdfrx se inicializa tras el primer fotograma.
- Web: captura mostrada al instante; la WebView en vivo se inicializa detrás.
- Bienvenida (R1) **solo** en el primer uso; nunca retrasa R8.
- Migraciones: las de esquema se ejecutan al abrir la BD (rápidas); las de datos pesadas se trocean en segundo plano.

## 3. Modelo de datos (esquema v1)

```mermaid
erDiagram
  TASKS ||--o{ ATTACHMENTS : "tiene (v1: 0..1)"
  TASKS ||--o{ TASKS : "parentId (futuro)"
  TASKS {
    text id PK "UUIDv7"
    text text "nullable; null si solo hay adjunto o si está purgada"
    text status "pending | completed"
    text rank "fractional index, único entre pendientes"
    int colorKey "0..4"
    int createdAt "epoch ms UTC"
    int updatedAt "epoch ms UTC"
    int completedAt "nullable"
    int deletedAt "nullable = tombstone"
    int dueDate "nullable (Bloque 1)"
    text parentId "nullable FK tasks.id (Bloque 2)"
    text source "local | todoist | keep | gtasks | mstodo | anydo (Bloque 3)"
    text externalId "nullable (Bloque 3)"
  }
  ATTACHMENTS {
    text id PK "UUIDv7"
    text taskId FK
    text kind "image | pdf | document | web"
    text origin "camera | gallery | file | url"
    text mime "detectado por contenido"
    int byteSize
    text relPath "relativa al contenedor de adjuntos"
    text displayRelPath "imagen optimizada para pantalla (nullable)"
    text thumbRelPath "nullable"
    text originalName "nullable, saneado"
    text sourceUrl "solo web; normalizada"
    text sourceHost "solo web; punycode si hace falta"
    text snapshotRelPath "solo web; nullable"
    int snapshotAt "nullable"
    int width "nullable"
    int height "nullable"
    int pageCount "nullable (PDF)"
    text sha256 "integridad y duplicados"
    int createdAt
  }
  SETTINGS {
    text key PK
    text value "JSON"
    int updatedAt
  }
```

- **Índices:** `tasks(status, deletedAt, rank)`; `attachments(taskId)`; `tasks(parentId)` y `tasks(source, externalId)` único parcial (futuro).
- **Invariantes (se prueban en el dominio):** una tarea tiene `text` no vacío **o** un adjunto (o ambos); una tarea web no lleva texto en la v1 (como el prototipo); `rank` es único entre las pendientes no borradas; `completedAt` no es nulo ⇔ `status = completed`; una tarea eliminada no aparece en ninguna consulta de UI.
- **Ajustes v1:** `locale` (`system | es | en`), `keepScreenOn` (bool, true), `palette` (`classic`), `firstRunDone` (bool), `notifications` (reservado). Las claves se versionan con el esquema.
- **Versionado:** `schemaVersion = 1` desde el primer build. Cada cambio → nueva versión, captura en `app/drift_schemas/`, paso de migración y **test de migración** generado (ADR-0002).

### Casos de uso ↔ reglas

| Caso de uso | Efecto en los datos | Regla |
|---|---|---|
| `CreateTask(text, position)` | inserta con `rank` antes de la primera (`top`) o después de la última (`end`); `colorKey` ≠ el de la actual | R3, R4 |
| `CreateTask(attachment)` | importa el archivo → inserta **top** siempre | R5 |
| `CompleteTask(current)` | `status = completed`, `completedAt = now`; conserva el adjunto | R9, R14, D8 |
| `DeleteTask(id)` | `deletedAt = now`; deshacer 6 s; purga del contenido | R10, ADR-0006 |
| `ReorderTask(id, newIndex)` | nuevo `rank` entre los vecinos; el índice 0 ⇒ pasa a ser la actual | R13 |
| `EditTask(id, text, attachment?)` | actualiza y conserva `rank` y `colorKey` | R11, R13 |

## 4. Adjuntos: canal de importación

```mermaid
flowchart LR
  A[Selector del sistema / cámara / URL] --> B{Tipo por bytes mágicos}
  B -- no admitido --> X[Error: tipo no admitido]
  B -- admitido --> C{¿Tamaño ≤ límite?}
  C -- no --> Y[Error: demasiado grande]
  C -- sí --> D[Copiar a tmp del sandbox]
  D --> E{kind}
  E -- image --> F[Decodificar → normalizar orientación → recodificar sin EXIF/GPS/XMP → versión de pantalla + miniatura]
  E -- pdf --> G[Abrir con pdfrx en modo solo lectura → miniatura p.1 → pageCount]
  E -- document --> H[Guardar tal cual → icono por tipo]
  E -- web --> I[HardenedWebView → captura de página completa → miniatura]
  F & G & H & I --> J[Mover de forma atómica a attachments/uuid/ + sha256]
  J --> K[Insertar Task + Attachment en una transacción]
```

Límites: imagen 30 MB (y 50 MP), **PDF 10 MB** (D18), documento 25 MB, captura web 20 000 px de alto. La importación va en un *isolate* (no bloquea la UI) y cancelar limpia los temporales. Detalle de seguridad en `docs/security/threat-model.md`.

## 5. Plataforma e integración nativa

| Necesidad | iOS | Android |
|---|---|---|
| Fotos y archivos sin permisos amplios | PHPicker, UIDocumentPicker | Photo Picker, SAF (`ACTION_OPEN_DOCUMENT`) |
| Cámara | Permiso de cámara **al pulsar "Hacer foto"** | Ídem (o intent de cámara del sistema, que no necesita permiso) |
| Visor del sistema | QLPreviewController | `ACTION_VIEW` + FileProvider |
| Pantalla encendida | `isIdleTimerDisabled` mientras hay un adjunto visible | `FLAG_KEEP_SCREEN_ON` |
| Red | ATS por defecto (sin excepciones) | `network_security_config`: `cleartextTrafficPermitted=false` |
| Backup | Application Support incluido, Caches excluido | `dataExtractionRules` / `fullBackupContent` (ADR-0004) |
| Widgets (futuro) | WidgetKit (SwiftUI) + App Group | Glance/AppWidget + datos compartidos; puente `home_widget` |

## 6. Feature flags

`FeatureFlags` (constantes en compilación con `--dart-define`, sobrescribibles en desarrollo desde un menú oculto de debug):
`paletteThemes` (off), `historyScreen` (off), `dueDates` (off), `bulkCreate` (off), `imports` (off), `notifications` (off), `biometricLock` (off), `homeWidget` (off).
Regla: nada detrás de un flag llega a producción sin su spec aprobada.

## 7. Presupuestos de rendimiento y tamaño

| Métrica | Objetivo | Medición |
|---|---|---|
| Arranque en frío → tarea actual visible | p50 < 1,0 s, p90 < 1,3 s (Android de gama media); < 0,6 s (iPhone ≥ 12) | `integration_test` + marcas de tiempo; `flutter run --profile --trace-startup` |
| Arranque en caliente | < 300 ms | ídem |
| Animaciones | 60 fps, 0 fotogramas > 32 ms en el primer uso | DevTools / `FrameTiming` en un test de rendimiento |
| Abrir PDF (primera página) | < 500 ms | spike S3 |
| Tamaño de descarga | Android < 25 MB (por ABI, AAB); iOS < 40 MB | `flutter build --analyze-size` en CI (aviso si crece > 5 %) |
| Memoria | < 250 MB con una imagen de 50 MP visible | DevTools |

## 8. Internacionalización

- `flutter gen-l10n` con ARB (`app_es.arb` como plantilla, `app_en.arb`); ICU para plurales y selectores; fechas con `intl` en el idioma activo.
- Resolución: ajuste `locale` ≠ `system` → ese idioma. Si no: cualquier `es-*` del dispositivo → `es`; el resto → `en` (R15).
- El nombre de la app es la clave `appName` + `AppIdentity`. El nombre nativo va en InfoPlist.strings (es/en) y `strings.xml` (values, values-es), generados desde una única fuente (`app/identity.yaml`).
- CI: test que compara las claves de ES y EN (sin huecos) y lint que prohíbe literales de texto en los widgets (`custom_lint` o un script).
