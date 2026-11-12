# ADR-0027: La landing de producto se construye con Vite y lleva GSAP y Lenis al navegador

- **Estado:** Propuesto
- **Fecha:** 2026-11-12
- **Decisores:** propietario del producto; Claude Code (propuesta)
- **Relacionado:** spec 025 (landing de producto), spec 023 (webs de la app), ADR-0009 (monorepo y `landing/`, **enmendado aquí**), ADR-0010 (Vercel), ADR-0026 (licencias de terceros), P4, P11 y P12 de la constitución, amenaza T-18 y §5 de `docs/security/threat-model.md`

## Contexto

- **[Hecho]** El ADR-0009 reservó `landing/` para una landing «estática (Astro o HTML)» con «ningún script de terceros». La spec 023 llenó esa carpeta con cinco páginas (inicio mínimo, política, licencias, Ayuda y error) construidas con **Node sin dependencias** (sin `package.json`) y **sin JavaScript** en el navegador; `landing/check.mjs` falla ante cualquier `<script>`, estilo en línea, animación o color fuera de los tokens, y la CSP es `default-src 'none'`.
- **[Hecho]** El propietario quiere una landing de producto con un recorrido en profundidad ligado al scroll (spec 025, CA-025-03 a 05), al estilo de las webs de juegos, y la ha diseñado con Claude Code en una maqueta (2026-11-11 y 12) hecha con **Vite**, **GSAP** (con su complemento ScrollTrigger) y **Lenis**.
- **[Hecho]** Decisiones del propietario (2026-11-12): la landing entra en este repositorio; se mantienen Vite, GSAP y Lenis; «si hay que cambiar documentación en la aplicación o normas, se hace»; el texto de la política se cambia.
- **[Hecho]** Versiones y licencias de la maqueta, leídas de los paquetes instalados el 2026-11-12: `vite` 8.3.8 (MIT, solo para construir), `gsap` 3.15.1 (licencia propia de GSAP, «Standard "no charge" license», https://gsap.com/standard-license) y `lenis` 1.3.27 (MIT). La maqueta construida lleva al navegador unos 67 KB comprimidos de programa (los dos paquetes más el código propio). El `package.json` de la maqueta declara además `three`, que la versión A no usa, y rangos con `^`: **`three` no entra** y las versiones se fijan exactas.
- **[Hecho]** La licencia de GSAP **no está** en la lista de licencias admitidas de `threat-model.md` §5 (MIT/BSD/Apache/OFL/zlib).
- **[Hecho]** Licencia de GSAP, leída el **2026-11-12** en https://gsap.com/standard-license («Standard "No Charge" GSAP License», de Webflow; vigente desde el 2025-04-30, última modificación el 2025-05-30; sin número de versión):
  - **Permite:** una licencia no exclusiva y mundial para «usar, reproducir, mostrar e implementar» GSAP y sus complementos (ScrollTrigger incluido) en **cualquier sitio web, aplicación web o interfaz digital, de cualquier persona o entidad**; el uso comercial está cubierto y no tiene coste.
  - **Prohíbe:** usarlo en herramientas que dejen construir animaciones visuales sin código y compitan con las de Webflow; hacer ingeniería inversa para crear un producto así; y **quitar o alterar sus avisos de propiedad o su marca**.
  - **Exige en la práctica:** conservar la cabecera de copyright de GSAP en el programa construido (el plan comprueba que la minificación no la quita). No pide atribución visible en la página; aun así su aviso va a la página de licencias (CA-025-18).
  - **Cambios y fin:** Webflow puede modificarla publicando el texto nuevo; quien no lo acepte no puede usar las versiones posteriores al cambio, pero **sigue usando las anteriores con los términos que tenían** (por eso la versión va fijada). Puede revocarla si se incumple; entonces hay que dejar de usarlo y destruir las copias.
  - **Conclusión:** **encaja** con una web pública de un producto gratuito: la landing no es una herramienta de animación. No hay que caer a la opción 3.
  - **Límites de esta lectura:** no es una licencia de código abierto ni una revisión legal. El texto **no habla** de redistribución, modificación ni repositorios públicos: **[Suposición]** servir GSAP dentro del programa de la propia web entra en «reproducir e implementar», y el repositorio no lleva copia de GSAP (se instala desde npm y `landing/dist/` está en `.gitignore`); **no se copia GSAP dentro del repositorio**. **[Pendiente]** La licencia incorpora los Términos de Servicio de Webflow (ley aplicable, garantías), que no se han leído: van a la revisión legal que ya bloquea `/release-checklist` (ADR-0026).
- **[Suposición]** Ninguno de los dos paquetes hace peticiones de red ni guarda nada por su cuenta. El plan lo comprueba en la web construida (CA-025-12) y no se acepta el ADR sin esa comprobación.
- **[Hecho]** La app no cambia: P3 y P4 hablan de la app, que sigue sin red. La web ya necesitaba conexión (nota de P3, ADR-0026).

## Opciones consideradas

1. **Seguir sin JavaScript ni dependencias:** animación solo con CSS ligada al scroll.
2. **JavaScript propio, sin bibliotecas ni empaquetador:** escribir a mano el suavizado del scroll, la línea de tiempo y el «imán».
3. **Vite para construir y Lenis (MIT) en el navegador, con la línea de tiempo propia:** sin GSAP.
4. **Vite, GSAP y Lenis** (la maqueta tal cual).
5. **Repositorio aparte** para la landing, con sus propias normas.

## Decisión

Se elige la **opción 4**, solo para la **página de inicio**: se construye con Vite y lleva al navegador GSAP (núcleo y ScrollTrigger) y Lenis, **servidos desde el propio origen**, con versiones fijadas y sin ningún otro paquete en el navegador. Las otras cuatro páginas siguen como están: construidas sin dependencias y sin JavaScript.

El ADR-0009 queda enmendado en una frase: donde decía «ningún script de terceros» pasa a leerse «**ningún programa servido desde otro origen ni que envíe datos**; el código de terceros que vaya al navegador se decide en un ADR».

Se revisa si: la licencia de GSAP cambia o resulta no encajar; alguno de los dos paquetes pasa un año sin mantenimiento o con un fallo de seguridad abierto; el peso de CA-025-17 no se cumple; o el recorrido se simplifica tanto que deja de hacer falta.

## Motivos

| Criterio (peso) | 1 Solo CSS | 2 Propio | 3 Vite + Lenis | 4 Vite + GSAP + Lenis | 5 Otro repo |
|---|---|---|---|---|---|
| Consigue el recorrido de la spec en los navegadores de CA-025-17 (5) | 1 | 3 | 3 | 5 | 5 |
| Trabajo ya hecho y aprobado a la vista por el propietario (4) | 1 | 1 | 2 | 5 | 5 |
| Cadena de suministro y licencias (3) | 5 | 5 | 4 | 2 | 2 |
| Una sola fuente de nombre, tokens, textos y política (3) | 5 | 5 | 5 | 5 | 1 |
| Mantenimiento por una persona (2) | 4 | 1 | 3 | 4 | 2 |
| **Total (máx. 85)** | **47** | **51** | **56** | **74** | **58** |

*(Sumas: 1 → 5+4+15+15+8 = 47; 2 → 15+4+15+15+2 = 51; 3 → 15+8+12+15+6 = 56; 4 → 25+20+6+15+8 = 74; 5 → 25+20+6+3+4 = 58.)*

- **Contra la 1:** la animación ligada al scroll solo con CSS no está en todos los navegadores de CA-025-17 **[Suposición; se comprueba en el plan con la tabla de compatibilidad vigente]** y no da el «imán» ni la demostración de mantener pulsado.
- **Contra la 2 y la 3:** rehacer a mano lo que GSAP ya resuelve (línea de tiempo ligada al scroll, que es donde se ha ido casi todo el ajuste con el propietario) es el mayor riesgo de regresión visual y de mantenimiento para una sola persona. La 3 queda como **salida** si la licencia de GSAP no encaja.
- **Contra la 5:** duplica identidad, tokens, textos legales y CI, que es justo lo que el ADR-0009 quiso evitar, y el propietario ya eligió integrar.

## Consecuencias

**Positivas**

- La landing aprobada a la vista entra sin reescribirse, y comparte nombre, tokens, textos de la app, política y CI con el resto.
- Las cuatro páginas legales y de ayuda no pierden ninguna de sus garantías.

**Negativas y riesgos (con su mitigación)**

- **`landing/` deja de ser «sin `package.json`»:** aparece una cadena de suministro de npm. Mitigación: versiones exactas y archivo de bloqueo con sumas; instalación reproducible y **sin scripts de instalación**; solo tres dependencias directas (una de construcción, dos de navegador); las actualizaciones automáticas y el análisis de vulnerabilidades del repositorio cubren también `landing/`; el plan decide si el resultado construido se compara con una lista de archivos esperados.
- **Licencia de GSAP fuera de la lista de §5:** excepción de P11 aceptada por el propietario con este ADR, limitada a la web (GSAP **no entra en la app**), anotada en `threat-model.md` §5 y añadida a la revisión legal que ya bloquea `/release-checklist` (ADR-0026). Su aviso se publica en la página de licencias (CA-025-18).
- **La CSP de la página de inicio se abre** a programas del propio origen (y, si el plan no consigue evitarlo, a estilos en línea, que el recorrido usa para colocar cada pieza). Mitigación: la CSP de las otras cuatro páginas no cambia; ningún programa en línea; `landing/check.mjs` pasa a tener dos juegos de reglas, el de siempre y el de la página de inicio, y sigue fallando cerrado; T-18 se reescribe con la superficie nueva.
- **La web guarda algo en el navegador** (el idioma elegido). No es una cookie ni sale del navegador; la política lo dice (CA-025-13).
- **Dos formas de construir en la misma carpeta** (la de la 023 y Vite). El plan decide cómo conviven en un solo resultado y en un solo trabajo de CI; si la convivencia complica más de lo que ahorra, se pregunta antes de mover las cuatro páginas a Vite.
- **Los colores cálidos de la landing** no existen en el prototipo: entran en `design/tokens.json` como colores de la landing y se registran en `docs/design/prototype-deviations.md` (P12).

**Pendiente o que dispararía revisar la decisión**

- La comprobación de que ningún paquete hace peticiones (arriba), **antes de aceptar**. El texto de la licencia de GSAP ya está leído (2026-11-12, arriba): encaja; quedan para la revisión legal los Términos de Servicio de Webflow que incorpora.
- Riesgo nuevo para el registro de `docs/PLAN.md`: «dependencias de npm en la web» (probabilidad baja, impacto medio; mitigaciones de arriba).
- La constitución **no cambia**: P4 y P3 siguen hablando de la app; P11 se cumple con la justificación y la excepción de este ADR; P12, con los tokens nuevos.
