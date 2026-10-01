# PR: spec 013, deuda de accesibilidad del código

**Título:** `feat(013): fix accessibility debt from spec 012 (translated name, reduced motion, unnamed stops, reader order)`

## Qué y por qué

Corrige la parte de código de los hallazgos de `a11y-reviewer` en el cierre de la 012 (012-A-M3, B3 y B4) y acepta por escrito B2, B5 y B6 (propietario, 2026-10-01). Además, el emulador encontró dos fallos propios (F-1, F-2), ya corregidos aquí.

- **Spec:** `specs/013-deuda-accesibilidad/spec.md` (estado: **Implementada parcialmente**)
- **Tareas:** T-013-01 a T-013-10 (con 08b, 08c y 08d)
- **Criterios de aceptación cubiertos:** CA-013-01 a 06 y CL-013-1 a 8 (tabla CA → prueba en `spec.md` §10)
- **ADR nuevos o afectados:** **ADR-0020** (Aceptado: voz del sistema en anuncios, excepción a P6; constitución 1.5)
- **Enmiendas a otras specs:** 012 (CA-012-03, 11, 12), 010 (CA-010-10, CL-010-2, §8, §9), 003 (CA-003-01); DEV-50 en `prototype-deviations.md`

## Qué cambia

- **CA-013-01/02:** "Bibliotecas de Android (AndroidX, Kotlin)" / "Android libraries (AndroidX, Kotlin)" es texto de la app (clave interna `una:android-libraries`, nombre traducido, orden alfabético del nombre que se ve, locale de la app). Con la lista abierta, el cambio de idioma reordena y conserva el foco y el desplazamiento; `_reveal` lleva la fila a la vista tanto si baja como si sube (F-2).
- **CA-013-03:** con "reducir movimiento" el hundido (posición y sombra) de `BrutalButton`, `SquareIconButton`, las opciones de "¿Dónde la pones?" y el botón de completar es instantáneo (`pressDuration`). El relleno de "mantener pulsado" y la enhorabuena **no** se acortan: `AnimationBehavior.preserve` (F-1: con el ajuste el relleno completaba la tarea en ≈ 60 ms).
- **CA-013-04/05:** ninguna parada del lector sin nombre (`test/support/semantics_stops.dart`, `BrutalButton` sin `container: true`, `Focus` del nivel 3 sin semántica); orden título → contenido → aviso → Cerrar/Volver.
- **Sin** permisos, dependencias, esquema (v2), datos ni conexiones nuevos. Único texto nuevo: `licensesAndroidLibraries` (ES/EN).

## Cómo se ha verificado

| Qué | Resultado | Entorno |
|---|---|---|
| `dart format`, `flutter analyze --fatal-infos`, `flutter test` | Limpios; **1530 tests en verde** | Local (Mac) |
| `node tools/validate-tokens.mjs` | 28 combinaciones AA | Local |
| `/i18n-check`, `/tokens-validate`, `/security-check` | Mismas claves ES/EN; sin literales ni valores sueltos nuevos; sin secretos, manifiestos, lockfile ni esquema en el diff | Local |
| `security-reviewer` | Sin hallazgos | Lectura de la rama |
| `a11y-reviewer` | 0 altos; F-1 y F-2 corregidos; 1 medio previo (opciones de "¿Dónde la pones?" sin teclado físico) y 3 bajos, registrados en `PLAN.md` (013-A-M1, B1 a B3) | Lectura de la rama |
| CA-013-06 | `check-android-permissions.sh release` (solo `INTERNET`), `check-licenses.sh` (84 paquetes, 46 artefactos, 5 `.so`) | Emulador API 37, APK *release* |
| CA-013-02/03/04/05 | Hundido a 1 fotograma; relleno intacto con las tres escalas a 0; ES↔EN con la fila subiendo y bajando; `uiautomator dump` de los tres niveles; TalkBack en borrar, enlace, "Nueva tarea" y "+" | Emulador API 37 (`dispositivo.md`); **nunca el Xiaomi** |

## Definition of Done (`specs/constitution.md`)

- [ ] Criterios de aceptación cumplidos y con tests en verde: **en parte** (todos con test; las casillas de dispositivo pasan a la 016)
- [ ] CI en verde: en local, sí; los *goldens* de Configuración (nombre traducido) se regeneran en CI con la etiqueta `actualizar-goldens` si hace falta
- [x] Textos nuevos en ES y EN; ninguno incrustado en el código
- [x] Sin valores visuales sueltos
- [x] Accesibilidad: revisada; hallazgos sin corregir registrados
- [x] Documentación actualizada (spec, ADR-0020, arquitectura, testing, glosario, `PLAN.md`, `CLAUDE.md`)
- [x] Rendimiento del arranque sin degradar (no se hace nada nuevo antes del primer fotograma)

## Seguridad ([checklist](../../docs/security/checklist.md))

- [x] Revisados los apartados que aplican: permisos y privacidad (T-13) y dependencias (T-10); nada tocado.
- [x] Sin secretos, permisos nuevos ni llamadas de red nuevas.

## Nueva dependencia

Ninguna.

## Pendiente (spec 016)

Foco real de TalkBack al volver del nivel 3 y al cerrar hojas; anillo con teclado físico y Switch Access; anuncio único del aviso y "Reintentar"; "reducir movimiento" a ojo en el móvil; *goldens* en CI; las casillas de `012/dispositivo.md` §8 se rehacen con el comportamiento nuevo.
