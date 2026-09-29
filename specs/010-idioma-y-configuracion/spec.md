# Spec 010: Idioma automático

- **Estado:** Aprobada (propietario, 2026-09-29)
- **Alcance reducido (propietario, 2026-09-29):** la v1 es una beta de pruebas y **no tiene pantalla de Configuración**. La entrada "Configuración y perfil" del menú se queda como está (DEV-18: cierra el menú) hasta una spec futura que diseñará el propietario. Solo dos idiomas, español e inglés, **sin selector**: lo decide el sistema. Solo Android (D17). La carpeta conserva el nombre `010-idioma-y-configuracion` para no romper enlaces ni la rama.
- **Reglas de producto:** R15. D13 y D14 están aplazadas junto con la pantalla de Configuración (§8)
- **Pantallas del prototipo:** ninguna nueva. La entrada "Configuración y perfil" ya existe (DEV-05 revocada; DEV-18, abierta)
- **Decisiones y ADR relacionados:** D13 (aplazada), D17; constitución P6, P7, P10
- **Dependencias:** 001, 005 (y 003, 004, 006–009 para las verificaciones de CA-010-06, 07, 10 y 11)

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que la app hable el idioma del usuario sin preguntar nada: español si el teléfono está en español y, si no, inglés. Eso incluye lo que lee el lector de pantalla.

## 2. Historias de usuario

- **HU-010-1** Como usuario con el móvil en español (de cualquier país), quiero la app en español sin configurar nada, para usarla desde el primer momento.
- **HU-010-2** Como usuario con el móvil en otro idioma, quiero la app en inglés sin configurar nada, para entenderla aunque mi idioma no esté.
- **HU-010-3** Como usuario de TalkBack, quiero que lo que se lee esté en el idioma de la app, para no oír frases mezcladas.

## 3. Criterios de aceptación

**Estado de partida [Hecho]:** la detección automática ya existe y tiene tests de CA-010-01 y 02. Pero conserva restos del cambio manual de idioma (CA-010-03, ahora retirado) y un test que lo cita. Esta spec **verifica** el comportamiento y **retira esos restos** (P10: no construir el futuro). No añade pantallas.

- **CA-010-01 Detección automática**
  - **Dado** que el idioma preferido del dispositivo es cualquier variante `es-*` (es-ES, es-MX, es-419…)
  - **Cuando** se abre la app
  - **Entonces** la app está en español; con cualquier otro idioma (incluidos ca, gl, eu y pt), en inglés.
- **CA-010-02 Lista de idiomas del sistema**
  - **Dado** que el dispositivo tiene varios idiomas preferidos (p. ej. `fr-FR`, `es-ES`)
  - **Cuando** se abre la app
  - **Entonces** se usa el **primero** de la lista que la app admite (en el ejemplo, español); si no admite ninguno, inglés.
  - **[Suposición]** Android entrega a la app la lista completa de idiomas preferidos, no solo el primero. Se confirma una vez en el emulador.
- **CA-010-03** *(Retirado el 2026-09-29: cambio manual de idioma. Pasa a la spec futura de Configuración y perfil. Se quitan de la app sus restos y su test)*
- **CA-010-04 Formatos**
  - **Dado** la app en español y en inglés
  - **Cuando** se muestran números o plurales
  - **Entonces** siguen las reglas de cada idioma. Pares que se comprueban:
    - tamaño de un PDF: "2,4 MB" / "2.4 MB"; por debajo de 1 MB, "3 KB" en los dos;
    - "Todas mis tareas": "1 tarea" / "1 task" y "3 tareas" / "3 tasks";
    - caracteres restantes del editor: "Queda 1 carácter" / "Quedan 5 caracteres" y sus equivalentes en inglés;
    - anuncio de eliminar desde el listado: "Tarea eliminada. Queda 1" / "… Quedan 3" y sus equivalentes en inglés.
  - La app no muestra fechas en la v1.
- **CA-010-05 Nombre de la app** *[Hecho en F2: aquí solo se verifica]*
  - **Dado** un cambio del nombre de la app en su única fuente de configuración
  - **Cuando** se genera una nueva compilación
  - **Entonces** el nombre cambia en los tres sitios donde aparece (bajo el icono, como título de la app en "Recientes" y en el logotipo) sin tocar código. El nombre no está escrito tal cual en ningún otro archivo de la app ni en los textos traducidos.
- **CA-010-06 Cambio de idioma con la app abierta**
  - **Dado** la app abierta en cualquier pantalla
  - **Cuando** el usuario cambia el idioma del sistema y **vuelve antes de 10 minutos** (CA-001-12)
  - **Entonces** la app está en el idioma nuevo, sin reiniciarse, y conserva lo que había:
    - la tarea actual con su adjunto: la imagen, el PDF con su página y su zoom, y la web sin recargarse;
    - el editor con el texto que se estaba escribiendo;
    - la hoja o el listado que estuvieran abiertos.
  - Con TalkBack, el foco sigue en el mismo elemento (o, si ya no existe, en el primero de la pantalla) y se lee en el idioma nuevo, sin anuncios extra. Si había una hoja abierta, el foco sigue dentro.
  - Si vuelve pasados 10 minutos, se aplica CA-001-12 ya en el idioma nuevo.
- **CA-010-07 Textos de accesibilidad en el idioma de la app**
  - **Dado** la app en español o en inglés
  - **Cuando** se recorre lo que expone al lector de pantalla
  - **Entonces** todo lo que sale de los textos de la app está en ese idioma: etiquetas, pistas, valores, nombres de las acciones personalizadas, títulos de las hojas y anuncios. Ninguno está en el otro idioma, tampoco después de CA-010-06.
  - Pantallas que se recorren: bienvenida, editor, tarea actual (solo texto, con imagen, con PDF y con web), menú, hojas (adjuntar, URL, eliminar), listado, "Todo hecho." y el error de almacenamiento.
  - Quedan fuera: el texto que escribe el usuario, el contenido de las páginas web, los selectores del sistema (fotos, archivos) y el teclado.
- **CA-010-08** *(Retirado el 2026-09-29: "sin perfil". Se decide con la pantalla de Configuración)*
- **CA-010-09** *(Retirado el 2026-09-29: licencias de código abierto. Pasan a la spec futura de Configuración y perfil; mostrarlas en la app es un requisito de publicación que se revisa en F5)*
- **CA-010-10 Voz del lector de pantalla** *(decisión del propietario, 2026-09-29)*
  - **Dado** TalkBack activo con un motor de voz que tenga español e inglés
  - **Cuando** lee la interfaz **y el contenido del usuario** (el texto de la tarea, las filas del listado, el campo del editor y el nombre del PDF)
  - **Entonces** lo lee con la voz del idioma de la app: español si el sistema está en `es-*` y, si no, inglés.
  - **Verificación:** un test comprueba que ningún nodo del contenido del usuario lleva un idioma distinto del de la app; la voz se comprueba a mano en el emulador (§6).
  - Excepción aceptada en la beta: los anuncios, los nombres de las acciones y los títulos de las hojas se oyen con la voz del sistema. Se revisa en la auditoría de accesibilidad de F5.
- **CA-010-11 Orden de las acciones tras el cambio**
  - **Dado** CA-010-06
  - **Cuando** se abren las acciones de TalkBack en la tarea actual (solo texto, con imagen, con PDF y con web) y en una fila del listado
  - **Entonces** mantienen el mismo orden que antes del cambio (CA-007-21, CA-008-20, CA-006-16 y CA-009-18).
- **CA-010-12 Texto grande en inglés**
  - **Dado** la app en inglés con el texto del sistema al 200 %
  - **Cuando** se muestran las mismas pantallas y hojas que en CA-010-07
  - **Entonces** no hay cortes, solapes ni desbordamientos (igual que ya se exige en español).

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-010-1 | Se cambia el idioma del sistema con la app abierta | Ver CA-010-06 |
| CL-010-2 | Sistema en un idioma que la app no admite (p. ej. `ca` o `fr`) y **sin español ni inglés en su lista** | App en inglés, también la voz de la interfaz y del contenido del usuario (CA-010-10). Los selectores del sistema (fotos, archivos) siguen en el idioma del sistema, y los anuncios se oyen con su voz: aceptado en la beta |
| CL-010-3 | Variantes regionales (`es-MX`, `en-GB`) | Textos y formatos de español o inglés sin variante. TalkBack puede usar la voz por defecto del idioma (p. ej. la de España) en vez de la regional: aceptado en la beta. Se comprueba una vez en el emulador |
| CL-010-4 | Sistema en un idioma de derecha a izquierda (árabe, hebreo) | App en inglés, de izquierda a derecha; al cambiarlo con la app abierta, se comporta como en CA-010-06 |
| CL-010-5 | El sistema cierra la app mientras el usuario está en Ajustes | Arranque normal, ya en el idioma nuevo |
| CL-010-6 | Ajustes › Idiomas de la app (Android 13+) | La app no aparece en esa lista: el idioma solo lo decide el sistema (§8) |
| CL-010-7 | Pulsar "Configuración y perfil" en el menú | Sin cambios: cierra el menú (DEV-18, abierta hasta la spec futura). Con TalkBack o Switch Access se cierra sin anunciar nada. **Limitación conocida de la beta.** El foco vuelve al botón del menú, no al primer nodo |

## 5. Estados vacíos y de error

No aplica: no hay UI nueva.

## 6. Accesibilidad

- CA-010-06, 07, 10, 11 y 12 recogen lo verificable. Se prueba con tests y además a mano en el emulador:
  - TalkBack con el sistema en fr-FR, ca-ES, es-MX y en-GB;
  - un cambio de idioma con el menú abierto y con el editor a medio escribir;
  - Switch Access y teclado físico tras el cambio (el recorrido y el foco no se pierden);
  - texto del sistema al máximo en inglés.
- Limitación conocida hasta la spec futura: CL-010-7 ("Configuración y perfil" no hace nada).

## 7. Textos (ES / EN)

Ninguno nuevo. Se reutilizan los que ya existen, incluido "Configuración y perfil" / "Settings and profile".

## 8. Fuera de alcance

- **Pantalla de Configuración y perfil** (spec futura, diseño del propietario; cierra DEV-18 y retoma D13 y D14). Incluirá:
  - el selector manual de idioma;
  - el interruptor "Mantener la pantalla encendida" (hasta entonces está siempre activa con imagen, PDF y web: D10, CA-007-12, CA-009-16);
  - los textos de Privacidad y de Copias de seguridad;
  - las licencias de código abierto y la versión.
  Los borradores de esos textos están en el historial de git de este archivo.
- **Ocultar el contenido en la miniatura de "Recientes"**: pasa a F5 (antes "[Pendiente, spec 010]" en CL-007-11, CL-008-13 y CL-009-10).
- Anuncios con la marca de idioma de la app (CA-010-10, excepción): se revisan en F5.
- Idioma por app de Android 13+.
- iOS (D17, fase F-iOS).
- Tema y paletas, notificaciones (Bloque 4); páginas legales y ayuda, exportar e importar (Bloque 5); biometría (D11).

## 9. Preguntas abiertas

Ninguna. Decisiones del propietario del 2026-09-29:

- sin pantalla de Configuración en la beta;
- solo español e inglés, elegidos por el sistema;
- el texto del usuario se lee con la voz del idioma de la app (CA-010-10);
- los anuncios con la voz del sistema se aceptan y se revisan en F5;
- "Recientes" pasa a F5 y el ajuste de pantalla encendida, a la spec futura.

## Anexo: notas para `plan.md` (no normativas)

- La resolución está en `app/lib/app/locale_resolution.dart` (`resolveAppLocale`), conectada en `una_app.dart` con `localeListResolutionCallback`. Hay que quitar el parámetro `setting`, la constante `supportedAppLocales` (no se usa) y el test `'CA-010-03: …'` de `test/app/locale_resolution_test.dart`.
- El manifiesto declara `locale|layoutDirection` en `configChanges`: la actividad no se recrea (CA-010-06).
- El nombre sale de `app/identity.yaml` → `tool/gen_identity.dart` → `AppIdentity` (CA-010-05); CI ya comprueba lo generado.
- Flutter marca los nodos semánticos con el idioma de la app a través de `setApplicationLocale`; no marca los anuncios, las acciones personalizadas ni los títulos de hoja (a11y-reviewer, 2026-09-29).
