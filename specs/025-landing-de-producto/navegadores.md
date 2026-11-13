# Casillas de navegador de la 025 (T-025-13)

Web construida con `node landing/build.mjs` y servida con `node landing/serve.mjs --port 4173` (CSP de `/` del plan §6.1). Rama `feat/025-landing-de-producto` sobre `4a88fc1`. Fecha: 2026-11-13.

Medios: Chrome 1xx de escritorio en el Mac del propietario (ventana de 1565×784, `devicePixelRatio` 0,9), por la extensión de Chrome; los tamaños de C-025-6, en Chrome sin interfaz por CDP (`Emulation.setDeviceMetricsOverride`, móvil por debajo de 900 px), con script en el *scratchpad* de la sesión, sin dependencias. La misma comprobación se pasó sobre la maqueta (`UnaWeb/www/dist/a`, solo lectura) para separar lo heredado de lo nuevo.

## Resumen

| Casilla | Navegador | Resultado |
|---|---|---|
| C-025-1 recorrido | Chrome de escritorio | **[Hecho] Pasa.** De frente, escalonado, sin zonas muertas; tras cada parada se asienta solo en la escena; texto nítido en reposo |
| C-025-1 | Chrome de Android | **[Hecho] Pasa.** Emulador de API 37 (GPU del Mac): las siete escenas al deslizar, se asientan solas. Xiaomi: **pasa, visto por el propietario** a mano (2026-11-14) |
| C-025-2 siete escenas, ida y vuelta | Chrome de escritorio | **[Hecho] Pasa.** Las siete hacia delante y hacia atrás; en el paso 7→6 el pie de la escena 7 se ve en pequeño un instante (igual que la maqueta) |
| C-025-2 | Safari de macOS | **[Hecho] Pasa, visto por el propietario** a mano (2026-11-14) |
| C-025-2 | Chrome de Android | **[Hecho] Pasa** (emulador, siete escenas; Xiaomi, propietario) |
| C-025-2 | Firefox | **Sin verificar y aceptado** (propietario, 2026-11-14: Firefox no está instalado) |
| C-025-3 pantallas frente a la app | Propietario | **[Pendiente]** revisión del propietario (que se parezcan a la app y que todo el contenido sea ficticio) |
| C-025-4 «reducir movimiento» | Chrome de escritorio (`?motion=reduce`, 320 y 1280) | **[Hecho] Pasa, salvo H-025-02**: apilada, siete escenas, interruptores encendidos y calco terminado, sin infracciones de CSP |
| C-025-4 | Chrome de Android | **[Hecho] Pasa** en el emulador (`?motion=reduce`): apilada, siete encabezados, interruptores encendidos, ninguna escena `inert`, sin *scroll* lateral |
| C-025-5 teclado, TalkBack, zoom | Chrome de escritorio; emulador | **[Pendiente]** teclado y zoom. TalkBack: en el emulador no se pudo probar (ni los deslizamientos ni `Alt+→` enviados por adb mueven el foco de TalkBack dentro de la página); **lo prueba el propietario en el Xiaomi** |
| C-025-6 seis tamaños, ES y EN | Chrome (modo móvil, CDP) | **[Hecho] Falla**: H-025-01 (844×390) y H-025-02 (320×568, escena 5). El resto (390×844, 768×1024, 1280×720, 1920×1080, y 320×568 salvo la escena 5) pasa: nada principal fuera, sin *scroll* lateral. 84 casos, 0 infracciones de CSP |
| C-025-6 | Xiaomi | **[Hecho] Pasa, visto por el propietario** a mano (2026-11-14) |
| C-025-6 tras los arreglos | Chrome (CDP) | **[Hecho] Pasa** tras H-025-01 y 02: 844×390 apilada, los otros cinco tamaños en recorrido; 84 casos sin nada fuera ni *scroll* lateral, 0 infracciones de CSP |
| C-025-7 peticiones y almacenamiento | Chrome de escritorio | **[Hecho] Pasa.** Solo el propio origen (7 recursos: HTML, un `.js`, un `.css`, tres `woff2`, icono y favicon); sin cookies, `localStorage` vacío sin pulsar ES/EN, `sessionStorage` vacío; 0 infracciones de CSP (escucha de `securitypolicyviolation` durante todo el recorrido) |
| C-025-8 fluidez | Chrome de escritorio | **[Hecho] Pasa.** Recorrido completo de 8,8 s: 528 fotogramas, **60,0 fps** de media, fotograma más largo **18 ms** (medido con `requestAnimationFrame` en la página, no con el panel de rendimiento) |
| C-025-8 | Safari de macOS, Xiaomi | **[Hecho] Pasa, visto por el propietario** a mano, sin cifras (2026-11-14) |
| C-025-8 | Emulador de API 37 | **Límite del emulador, aceptado** (propietario, 2026-11-14): 14,1 s deslizando por las siete escenas, **43,2 fps** de media y 8 fotogramas de más de 100 ms (máx. 583 ms), con la GPU del Mac traducida; con SwiftShader daba 4 fps. No mide la página |
| C-025-8 | Firefox | **Sin verificar y aceptado** |
| Peso (CA-025-17) | — | **[Hecho]** 341 KB con gzip -9 (HTML 10,6; JS 64,3; CSS 7,1; fuentes 254; imágenes 5,8), por debajo de 450 KB |

## Hallazgos

- **H-025-01 (medio). Móvil en horizontal (844×390): las escenas no caben y no pasa a apilada.** Escena 1: el titular empieza 52 px por encima de la pantalla y el móvil tapa «Muy pronto» y la entradilla; escena 3: el móvil de «Pruébalo» queda entero por debajo (no se puede probar mantener pulsado); escenas 4 a 7: textos y botones de completar por debajo del borde. Incumple CA-025-16 y la regla de CL-025-13 (escena que no cabe en el alto → apilada). **Heredado: la maqueta da exactamente lo mismo.** **Corregido** en el commit `fix(025): fall back to the stacked page when the window is too short` (umbral de 540 px de alto en `shared/mode.js`; al girar y dejar de caber, recarga apilada).
- **H-025-02 (medio). 320 px, escena 5 («La pantalla no se apaga»): el texto se corta por la derecha** (entradilla de 18 a 377 px, nota de 42 a 353), en el recorrido y en la apilada, ES y EN. Causa: con una columna (`.split--rev` en `max-width: 860px`), la fila del ajuste (`.device .setting`, `white-space: nowrap`) ensancha la pista `1fr`, cuyo mínimo es automático; arreglo probable de una línea, `grid-template-columns: minmax(0, 1fr)`. Incumple CA-025-16 y 1.4.10 (reflujo). **Heredado de la maqueta.** **Corregido** en el commit `fix(025): keep one-column scenes inside the screen at 320 px` (`minmax(0, 1fr)` en `shared/base.css` y `a/scene.css`; la escena 5 es un `.split` sin modificador).
- **Observación.** El porte conserva cosas que el plan quitaba: `?motion=reduce` sigue en `journey.js` y `sc.inert` en las escenas no activas (plan §6.2: sin `inert`). Vienen de la maqueta (T-025-07b, «tal cual»); se anotan para el cierre (`a11y-reviewer`).
