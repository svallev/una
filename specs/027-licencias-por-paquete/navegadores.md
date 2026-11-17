# Casillas de navegador de la 027 (T-027-05)

Web construida con `node landing/build.mjs` (check en verde) y servida con `node landing/serve.mjs --port 4175` (CSP de `/(.+)` con `script-src 'self'` y Trusted Types, como `vercel.json`). Rama `feat/027-licencias-por-paquete` sobre `1db7a79`. Fecha: 2026-11-17.

Medios: Chrome 157 sin interfaz por CDP (`Emulation.setDeviceMetricsOverride`, móvil por debajo de 900 px; zoom = ventana dividida y `deviceScaleFactor`; teclas con `Input.dispatchKeyEvent`), con scripts en el *scratchpad* de la sesión, sin dependencias; Chrome 149 del emulador de API 37 (Pixel 6a, 411 × 784 a 2,625, `adb reverse`), con DevTools remoto y toques con `Input.dispatchTouchEvent`. Página: `/licenses`, en ES y EN (`una-lang`). Firefox no está instalado: sin verificar.

Qué mide el barrido en cada caso, con los grupos plegados y después con **los 164 abiertos** (159 cabeceras y 5 secciones): *scroll* lateral; elementos del bloque de avisos fuera de la ventana o con *scroll* interno; `summary` < 44 × 44; `display` del `summary` (`list-item`, marcador nativo); el recuento visible (un idioma con JavaScript, los dos sin él); la cabecera fija o no.

## Resumen

| Casilla | Navegador | Resultado |
|---|---|---|
| Cinco tamaños × ES/EN (CA-027-04, 06) | Chrome (CDP): 320×568, 390×844, 844×390, 768×1024, 1280×720 | **[Hecho] Pasa.** 10 casos, plegados y con todo abierto: sin *scroll* lateral ni nada fuera ni *scroll* interno; 164 `summary`, ninguno < 44 × 44, todos `list-item`; recuento en el idioma elegido («(1 aviso)» / «(1 notice)»); cabecera fija salvo a 844×390 (alto < 540) |
| Zoom 200 % y 400 % a 320 px | Chrome (CDP): 640×360 a 2×, 320×180 y 320×256 a 4× | **[Hecho] Pasa.** 6 casos, plegados y abiertos: sin *scroll* lateral ni nada fuera; los nombres largos y el recuento se parten en dos líneas sin salirse |
| Espaciado de texto (1.4.12) | Chrome (CDP), 320×568 y 1280×720 (hoja inyectada por DevTools) | **[Hecho] Pasa.** 4 casos, plegados y abiertos: nada fuera ni *scroll* lateral; el `summary` crece (sin alto fijo) |
| Colores forzados | Chrome (CDP, `forced-colors: active`), 390×844 y 1280×720 | **[Hecho] Pasa.** 4 casos sin fallos de diseño; capturas: el marcador (triángulo, cambia de forma al abrir), las líneas entre grupos y entre avisos y el anillo de foco (color del sistema) se ven |
| Sin JavaScript (CA-027-06) | Chrome (CDP, scripts desactivados), 320×568 y 1280×720 | **[Hecho] Pasa.** Los dos recuentos («(1 aviso / 1 notice)») y los enlaces bilingües, sin nada fuera, plegados y abiertos |
| Teclado: enlace de saltar (CA-027-06) | Chrome (CDP), 1280×720 y 390×844 | **[Hecho] Pasa.** Tab desde el preámbulo llega a «Saltar la lista de avisos» (anillo de 3 px); Intro lleva el foco a «Ver el archivo de avisos como texto» (`#notices-end`), visible bajo la cabecera (527 px con la cabecera en 67); el siguiente Tab va al pie («Ayuda»); Mayúsculas+Tab vuelve al destino y después al último grupo (`assets/licenses/sqlite.txt`) |
| Teclado: abrir y cerrar | Chrome (CDP), 1280×720 y 390×844 | **[Hecho] Pasa.** Tab desde el enlace de saltar llega al primer grupo; Intro lo abre y Espacio lo cierra; el foco se queda en el `summary`, visible y con anillo |
| Teclado: grupo grande abierto | Chrome (CDP), 1280×720 y 390×844 | **[Hecho] Pasa, con H-027-01.** Con `icu` abierto, Mayúsculas+Tab desde el grupo siguiente («icu, include, json») salta los 552 avisos y deja el foco en «icu (552 avisos)», visible bajo la cabecera. Cerrar `icu` con Intro con la página desplazada muy abajo: ver H-027-01 |
| Abrir `icu` en < 1 s (CA-027-08) | Emulador de API 37, Chrome 149, toque real | **[Hecho] Pasa.** Del `pointerdown` a dos fotogramas después del `toggle`: 345 ms (recarga sin caché), 79 y 151 ms. El grupo abierto mide 172 582 px. En escritorio, 74–99 ms incluida la ida y vuelta de CDP |
| Chrome de Android | Emulador de API 37 | **[Hecho] Pasa.** Captura con `icu` abierto: marcador, nombre, recuento en Space Mono y líneas entre avisos; texto partido sin salirse |
| Safari (marcador y estado) con VoiceOver | Safari de macOS | **[Hecho] Pasa, visto por el propietario** (2026-11-17: «todo ok») |
| TalkBack (destino del salto, nombre, un recuento, estado; con un grupo abierto se llega a su texto) | Propietario | **[Hecho] Pasa, visto por el propietario** (2026-11-17: «todo ok»; por `adb` no se mueve el foco de TalkBack dentro de la página, como en la 025 y la 026) |

## Hallazgos

- **H-027-01 (bajo). Al cerrar un grupo grande con la página desplazada muy abajo, el `summary` enfocado no queda a la vista.** Con el foco en «icu (552 avisos)» y la página bajada a mano (rueda, flechas o Av Pág) dentro de sus avisos, Intro cierra el grupo, pero el navegador no lleva el foco a la vista: la página se queda al final (el `summary` arriba, fuera de la ventana) o, si el grupo siguiente estaba arriba de la ventana, el anclaje de *scroll* de Chrome deja el `summary` justo **debajo de la cabecera fija** (22–66 px con la cabecera hasta 67). El foco no se mueve y el siguiente Tab o Mayúsculas+Tab lo trae de vuelta a la vista (con `scroll-padding-top`). Es el comportamiento nativo de `<details>`; corregirlo pide programa (llevar el `summary` a la vista en `toggle`), que el ADR-0028 no permite en esta página. 2.4.11 se refiere al foco que llega a un elemento, no a la página que el usuario ha movido él mismo. **Aceptado sin cambio** por el propietario (2026-11-17), sin excepción de P6.

## Casillas sin verificar (cierre, 2026-11-17)

Del `a11y-reviewer`; **[Pendiente]**, no bloquean y se repiten en la web que se publique (F6): VoiceOver y TalkBack en ES **y** EN y con JavaScript desactivado (los dos recuentos); cambiar de idioma con `icu` abierto en un navegador real (hoy solo `lang.test.mjs`); modo oscuro del sistema con un grupo abierto (CL-027-10; en el código, `color-scheme: light`); Safari con Option+Tab; colores forzados en Windows real con Edge o Firefox (aquí solo emulados por CDP); Firefox. Mitigación de H-027-01 con `position: sticky` en `.group[open] > summary`: **descartada** (con zoom 400 % y un nombre de 18 paquetes ocuparía media pantalla, 1.4.10).
