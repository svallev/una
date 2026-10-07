# PR: spec 016, tareas con varias imágenes (carrusel)

**Título:** `feat(016): tasks with up to 10 photos and an infinite carousel`

## Qué y por qué

Hasta ahora una tarea llevaba como mucho un adjunto. Con esta PR una tarea puede llevar **de 2 a 10 fotos de la galería** y se ven a pantalla completa, de una en una, con un carrusel infinito (swipe horizontal, desplazamiento vertical y pellizco de vistazo por foto) y unos puntos informativos bajo el pie. La pantalla principal sigue mostrando **una sola tarea**: el grupo es una tarea (P1). Todo es local y sin permisos ni dependencias nuevas.

- **Spec:** `specs/016-varias-imagenes-carrusel/spec.md` (estado: **Implementada parcialmente**)
- **Tareas:** T-016-01 a T-016-24a (tabla CA → prueba en `spec.md` §13)
- **Criterios de aceptación cubiertos:** CA-016-01 a CA-016-25 y los casos límite CL-016-*; los de dispositivo, en `dispositivo.md` y en las casillas de la 022
- **ADR nuevos o afectados:** **ADR-0022** (interacción con varias fotos; enmienda del ADR-0013) y **ADR-0024** (adjuntos de 1 a N con orden; enmienda del ADR-0002 y del ADR-0012), ambos Aceptados; constitución **1.9** (excepción a P6 del swipe sin alternativa visible de un toque, mitigada con las acciones «Foto siguiente/anterior», las de desplazamiento, las flechas y un anuncio único)
- **Enmiendas a otras specs:** 001, 002, 003, 004, 005, 006, 007, 008, 011 y 014; DEV-53 (nueva) y notas en DEV-39, 41 y 43

## Qué cambia

- **Datos (esquema v3):** una fila de `attachments` por foto con `position`; migración v2 → v3 en una transacción (las tareas con varias filas se numeran de 0 a N-1), captura `drift_schema_v3.json` y tests de migración desde v1 y v2. `Task.attachments` es una lista inmutable con las invariantes en el dominio (ninguno, uno de cualquier tipo o de 2 a 10 imágenes); `Task.attachment` es la primera. Lectura tolerante con una BD restaurada: como mucho 10 filas, posiciones repetidas o con huecos, id inválido → «Adjunto no disponible».
- **Importar un grupo:** selector múltiple del sistema (`ACTION_PICK_IMAGES` o `ACTION_OPEN_DOCUMENT`, sin permisos) con tope de 10 también en el código nativo; las fotos se preparan **una a una** con la misma validación de la 007 (`ImportGroup`), con 20 s por foto y 2 min en total (`ImportBudget`), espacio libre comprobado antes, fallo parcial (se omite la que falla y se avisa) y guardado todo o nada (`commitGroup`).
- **Editor:** pila de fotos con la primera arriba, «Preparando foto {i} de {n}…» con «Cancelar», aviso compuesto, «Quitar adjunto» y reemplazo.
- **Tarea actual:** `PhotoCarousel` (infinito, solo la foto actual y la vecina), `ZoomablePhoto` extraída de `TaskImage`, `PhotoDots` bajo el pie, abre siempre en la primera, giro a horizontal conservando la foto y su desplazamiento, «Foto no disponible» por foto y la tarjeta si faltan todas. Pantalla encendida y Recientes (ADR-0019) con el grupo.
- **Accesibilidad:** un nodo único con «Foto {i} de {n}», acciones «Foto siguiente/anterior» antes de Completar y Eliminar, `onScrollLeft/Right`, flechas del teclado, un único anuncio por cambio (región viva, 300 ms de antirrebote), reducir movimiento y texto al 200 %.
- **Listado, deshacer y anuncios:** miniatura de la primera foto sin contador; «{n} fotos» en la lectura, la card de deshacer y «Siguiente: …»; la rotura y el arrugado usan una captura en memoria de la foto que se veía (`PhotoFaceCapture`).
- **Nativo:** solo `ImageImport.kt` (`pickMany`, `freeSpace`, limpieza en un solo hilo). Sin permisos, componentes ni consultas de paquetes nuevos.
- **Textos:** 12 claves nuevas y 2 que cambian en ES y EN (spec §7), con plurales ICU.
- **Documentación:** `architecture`, `testing`, `glossary`, `threat-model` (T-2, T-3, T-7 y T-16 nuevo, DoS por N), `checklist`, DEV-53, `PLAN.md`, `CLAUDE.md`.

## Cómo se ha verificado

Detalle: `specs/016-varias-imagenes-carrusel/dispositivo.md`.

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **2564 tests en verde** (86 omitidos); `test/tool/check_release_config_test.dart` falló una vez en la suite completa y pasa sola (intermitente, sin relación con la 016) | Local (Mac) |
| `node tools/validate-tokens.mjs` | Bien (30 combinaciones de contraste de texto y 23 no textuales) | Local |
| `/i18n-check` | ARB ES/EN con las mismas claves, sin vacíos, placeholders iguales, sin literales incrustados | Local |
| `flutter build apk --release` + `tools/check-android-permissions.sh release` | Solo `INTERNET` (de la 009); `pubspec.yaml`, `pubspec.lock`, manifiesto, `res/xml`, `backup_rules.xml` y `data_extraction_rules.xml` **sin cambios** | Local |
| `security-reviewer` | 0 altos, 0 medios, 6 bajos; 2 corregidos en T-016-24a (id inválido de una BD restaurada, excepción no tipada en la importación); el resto, en `PLAN.md` | `git diff main...HEAD` |
| `a11y-reviewer` | 0 altos, 1 medio (barra de progreso como nodo suelto; corregido en T-016-24a), 4 bajos en `PLAN.md` | `git diff main...HEAD` |
| `spec-reviewer` | 0 bloqueantes; CA-016-19 enmendado con la decisión del propietario, plan y comentarios al día | `git diff main...HEAD` |
| `integration_test` (`photo_group_flow_test`, `photo_group_import_test`, `task_list_perf_test`) | En verde, también en modo avión | Emulador API 37 |
| Selector real, gestos, pellizco, gesto de volver, Recientes, medidas, TalkBack (una frase por cambio), teclado, 200 %, reducir movimiento | Resultados en `dispositivo.md`: arranque en frío 425 → 429 ms con 1 y 10 fotos de 24 MP, +21 MB de pico, 62 MB por tarea con fotos de 6 MB | Emulador API 37 (sin Xiaomi) |

## Definition of Done (`specs/constitution.md`)

- [x] Criterios de aceptación cumplidos y con tests en verde (los de dispositivo, en la 022)
- [x] CI en verde (*goldens* de la 016 generados en CI con `actualizar-goldens` y subidos)
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos (todo sale de los tokens)
- [x] Accesibilidad: semántica, alternativas a gestos (con la excepción del ADR-0022), contraste, texto grande, reducir movimiento
- [x] Documentación actualizada (spec, ADR, glosario, arquitectura, seguridad)
- [x] Rendimiento del arranque sin degradar (medido en el emulador; el Xiaomi, en la 022)

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados: «Si toca la importación» (cada foto, como no confiable; DoS por N acotado), almacenamiento (T-1, T-7), nativo (T-8), permisos y privacidad (T-13)
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas

## Pendiente antes o después de fusionar

- **[Hecho]** *Goldens* de la 016 (19 PNG) generados en CI con `actualizar-goldens`, revisados a ojo y subidos.
- **[Hecho, propietario 2026-10-07]** Listado con 500 tareas de 10 fotos: se abre en ~130 ms (< 300 ms de CA-006-20); no se repite en el Xiaomi.
- **[Pendiente, 022]** Casillas de dispositivo (`docs/PLAN.md`, «Casillas de la 016»): Android 8 y 12L con `check-recents.sh` (PD-10) y su calibración en horizontal, medidas en el Xiaomi, TalkBack a oído (anuncios del editor), Switch Access y control por voz, teclado físico, test de Chrome del selector múltiple.
- **[Pendiente, 020/022]** Hallazgos bajos de las revisiones de cierre (mismo apartado de `PLAN.md`): «Foto no disponible» y el pie al ×2,0 en 360 × 640, foto corrupta anunciada sin «no disponible», barrido y migración con millones de filas, código muerto `SendAnnouncementAnnouncer`.

## Nueva dependencia

Ninguna.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
